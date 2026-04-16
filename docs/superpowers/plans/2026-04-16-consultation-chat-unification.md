# Consultation Chat Unification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every consultation appear as an independent, visible conversation in the messages list for both parties, fix all message sending/receiving/notification bugs, and migrate historical data.

**Architecture:** Align all consultation types to the "flea market" pattern: each consultation creates its own placeholder task with `poster_id` and `taker_id` set. For team consultations, additionally query `ExpertMember` so all team members see the chat. Fix `send_task_message` permissions to support taker + team members without `application_id`. Fix WebSocket broadcasts and global unread counts. On task acceptance, batch-close related consultations. The existing `ApplicationChatView` stays as the UI for all consultations.

**Tech Stack:** FastAPI (backend), Flutter/BLoC (frontend), SQLAlchemy async

---

## Bug Inventory

| # | Bug | Impact | Task |
|---|-----|--------|------|
| 1 | Service/team consultation `taker_id = NULL` → receiver can't see chat | High | Task 1 |
| 2 | Task consultation uses original task, not independent conversation | High | Task 2 |
| 3 | Team admin (non-owner) can't see consultation in messages list | Medium | Task 3 |
| 4 | Messages list preview/unread includes consultation sub-channel messages | Medium | Task 4 |
| 5 | `send_task_message`: taker & team members can't send without `application_id` | High | Task 5 |
| 6 | WebSocket broadcast misses taker & team members for consultation chats | High | Task 6 |
| 7 | Global unread count (`get_unread_messages`) misses consultation tasks for taker/team | Medium | Task 7 |
| 8 | `_reject_other_applications` doesn't close consulting/negotiating states | Medium | Task 8 |
| 9 | `isConsultation` getter doesn't recognize `task_consultation` source | Low | Task 9 |
| 10 | Historical data: service consultations with `taker_id = NULL` | High | Task 10 |
| 11 | Historical data: task consultations on original task (no placeholder) | Low | Task 10 |
| ~~12~~ | ~~Expert dashboard has no consultation entry point~~ | ~~N/A~~ | ~~Already exists~~ — `applications_tab.dart` 已支持 consulting/negotiating/price_agreed 状态的显示、沟通和报价 |

---

## File Map

### Backend
- **Modify:** `backend/app/expert_consultation_routes.py` — set `taker_id` (Task 1)
- **Modify:** `backend/app/task_chat_routes.py` — create_task_consultation placeholder (Task 2), ExpertMember query (Task 3), preview/unread fix (Task 4), send_task_message permissions (Task 5), WebSocket broadcast (Task 6)
- **Modify:** `backend/app/crud/message.py` — global unread count (Task 7)
- **Modify:** `backend/app/task_chat_business_logic.py` — close consultations (Task 8)
- **Create:** `backend/migrations/NNN_fix_consultation_taker_id.sql` — historical data (Task 10)

### Frontend
- **Modify:** `link2ur/lib/data/models/message.dart` — extend isConsultation (Task 9)
- **Modify:** `link2ur/lib/features/tasks/views/task_detail_view.dart` — task consultation navigation (Task 2)
- **Modify:** `link2ur/lib/data/repositories/task_repository.dart` — return type (Task 2)
- `link2ur/lib/features/expert_dashboard/views/tabs/applications_tab.dart` — 已支持 consulting 状态，无需改动

---

## Task 1: Fix service/team consultation visibility (set taker_id)

**Files:**
- Modify: `backend/app/expert_consultation_routes.py:236-252, 340-358`

- [ ] **Step 1: Service consultation — resolve and set taker_id**

In `create_consultation()`, before creating `consulting_task`, resolve the service owner's user_id:

```python
    # Resolve taker_id so service provider sees the chat
    taker_user_id = None
    if service.owner_type == "user" and service.owner_id:
        taker_user_id = service.owner_id
    elif service.owner_type == "expert" and service.owner_id:
        from app.models_expert import ExpertMember
        owner_result = await db.execute(
            select(ExpertMember.user_id).where(
                ExpertMember.expert_id == service.owner_id,
                ExpertMember.role == "owner",
                ExpertMember.status == "active",
            )
        )
        owner_row = owner_result.first()
        if owner_row:
            taker_user_id = owner_row[0]
```

Add `taker_id=taker_user_id` to `models.Task(...)`.

- [ ] **Step 2: Team consultation — resolve and set taker_id**

In `create_team_consultation()`, `expert_id` is already a function parameter:

```python
    from app.models_expert import ExpertMember
    owner_result = await db.execute(
        select(ExpertMember.user_id).where(
            ExpertMember.expert_id == expert_id,
            ExpertMember.role == "owner",
            ExpertMember.status == "active",
        )
    )
    owner_row = owner_result.first()
    taker_user_id = owner_row[0] if owner_row else None
```

Add `taker_id=taker_user_id` to `models.Task(...)`.

- [ ] **Step 3: Commit**

```bash
git add backend/app/expert_consultation_routes.py
git commit -m "fix: set taker_id on service/team consultation tasks for messages list visibility"
```

---

## Task 2: Task consultation — create placeholder task

**Files:**
- Modify: `backend/app/task_chat_routes.py:4674-4793`
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:1345-1360`
- Modify: `link2ur/lib/data/repositories/task_repository.dart`

Change `create_task_consultation()` to create an independent placeholder task with `task_source="task_consultation"`, `poster_id=applicant`, `taker_id=task.poster_id`, `description=f"original_task_id:{task_id}"`.

`TaskApplication.task_id` points to the placeholder task. The 6 consultation sub-endpoints (consult-negotiate, etc.) validate `WHERE application.task_id == {task_id}` — since frontend passes the placeholder task_id and application also points to it, these endpoints continue to work.

- [ ] **Step 1: Rewrite create_task_consultation backend**

Replace function body (see full code in previous plan version — key changes):
- Create `models.Task(task_source="task_consultation", poster_id=current_user.id, taker_id=task.poster_id, description=f"original_task_id:{task_id}")`
- `TaskApplication(task_id=consulting_task.id)` — points to placeholder
- Duplicate detection: query `Task` by `task_source`, `poster_id`, `taker_id`, exact `description` match
- Response includes `task_id` (placeholder), `application_id`, `original_task_id`

- [ ] **Step 2: Update frontend navigation**

In `task_detail_view.dart`, `_openDesignatedConsultChat`:

```dart
Future<void> _openDesignatedConsultChat(int originalTaskId) async {
  try {
    final repo = context.read<TaskRepository>();
    final result = await repo.createTaskConsultation(originalTaskId);
    final consultTaskId = result['task_id'] as int;
    final appId = result['application_id'] as int;
    if (!mounted) return;
    context.push('/tasks/$consultTaskId/applications/$appId/chat?consultation=true&type=task');
  } catch (e) {
    if (mounted) AppFeedback.showError(context, context.localizeError(e.toString()));
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py link2ur/lib/features/tasks/views/task_detail_view.dart link2ur/lib/data/repositories/task_repository.dart
git commit -m "feat: task consultation creates placeholder task for independent messages list entry"
```

---

## Task 3: Messages list — ExpertMember query for team consultations

**Files:**
- Modify: `backend/app/task_chat_routes.py:300` (inside `get_task_chat_list`)

Team owner sees the chat via `taker_id`. Other team admins don't. Add query through `ServiceApplication.new_expert_id → ExpertMember`.

- [ ] **Step 1: Add query after multi-participant block (before `if not task_ids_set:`)**

```python
        # 3. 作为团队成员的 consultation 任务
        from app.models_expert import ExpertMember
        sa_team_query = (
            select(models.ServiceApplication.task_id)
            .join(
                ExpertMember,
                and_(
                    ExpertMember.expert_id == models.ServiceApplication.new_expert_id,
                    ExpertMember.user_id == current_user.id,
                    ExpertMember.status == "active",
                ),
            )
            .where(
                and_(
                    models.ServiceApplication.new_expert_id.isnot(None),
                    models.ServiceApplication.task_id.isnot(None),
                )
            )
        )
        sa_team_result = await db.execute(sa_team_query)
        task_ids_set.update([row[0] for row in sa_team_result.all()])
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: team members see consultation chats in messages list via ExpertMember join"
```

---

## Task 4: Fix messages list preview and unread count

**Files:**
- Modify: `backend/app/task_chat_routes.py:308-320, 360-378, 490-519`

Add `models.Message.application_id.is_(None)` to all four queries (last_message_time, last_messages, two unread counts).

Safe because: service/flea market consultations don't use `application_id` on messages. Task consultation messages (which do use `application_id`) now live on the **placeholder** task, not the original — so this filter only prevents the original task from picking up stray consultation messages.

- [ ] **Step 1: Add filter to all four query locations**

Add `models.Message.application_id.is_(None)` to the `and_()` clause in:
1. `last_message_time_subquery` (line ~314)
2. `last_messages_subquery` (line ~374)
3. Cursor-based unread query (line ~497)
4. MessageRead fallback unread query (line ~509)

- [ ] **Step 2: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "fix: messages list preview and unread count exclude consultation sub-channel messages"
```

---

## Task 5: Fix send_task_message permissions for consultation chats

**Files:**
- Modify: `backend/app/task_chat_routes.py:1107-1172` (send_task_message)

**Current bug:** When `application_id` is NOT provided (service consultation), permission check only allows `is_poster || is_taker || is_participant || is_expert_creator`. The service provider is `taker` (after Task 1 fix), but **team members who are neither poster nor taker cannot send messages**.

**Fix:** When no `application_id` is provided, add a fallback check: if the task has `task_source IN ('consultation', 'task_consultation')`, look up `ServiceApplication`/`TaskApplication` by `task_id` and check team membership.

- [ ] **Step 1: Add consultation team member check to send_task_message**

After the existing `is_poster/is_taker/is_participant/is_expert_creator` check (line 1168), before raising 403:

```python
        # Consultation tasks: allow team members even without application_id
        is_consultation_team_member = False
        if not (is_poster or is_taker or is_participant or is_expert_creator):
            task_source = getattr(task, 'task_source', None)
            if task_source in ('consultation', 'task_consultation'):
                # Look up ServiceApplication for this consultation task
                sa_query = select(models.ServiceApplication).where(
                    models.ServiceApplication.task_id == task_id
                )
                sa_result = await db.execute(sa_query)
                sa = sa_result.scalar_one_or_none()
                if sa:
                    is_consultation_team_member = await _is_team_member_of_application(db, sa, current_user.id)

        if not (is_poster or is_taker or is_participant or is_expert_creator or is_consultation_team_member):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限发送消息"
            )
```

- [ ] **Step 2: Fix receiver determination for consultation without application_id**

After the permission check, add receiver logic for consultation chats when `application_id` is not provided:

```python
        # For consultation tasks without application_id, determine receiver
        if not request.application_id and getattr(task, 'task_source', None) in ('consultation', 'task_consultation'):
            if current_user.id == task.poster_id:
                application_receiver_id = task.taker_id
            else:
                application_receiver_id = task.poster_id
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "fix: send_task_message allows taker and team members for consultation chats"
```

---

## Task 6: Fix WebSocket broadcast for consultation chats

**Files:**
- Modify: `backend/app/task_chat_routes.py:1303-1412` (WebSocket broadcast section in send_task_message)

**Current bug:** For general task chat (no `application_id`), WebSocket only sends to `poster_id` + `taker_id`. Team members of consultation tasks don't receive real-time messages.

- [ ] **Step 1: Add team members to participant_ids for consultation tasks**

In the WebSocket broadcast section, after building `participant_ids` for general task chat:

```python
        # For consultation tasks: also broadcast to team members
        task_source = getattr(task, 'task_source', None)
        if task_source in ('consultation', 'task_consultation') and not request.application_id:
            sa_query = select(models.ServiceApplication).where(
                models.ServiceApplication.task_id == task_id
            )
            sa_result = await db.execute(sa_query)
            sa = sa_result.scalar_one_or_none()
            if sa and sa.new_expert_id:
                from app.models_expert import ExpertMember
                members_result = await db.execute(
                    select(ExpertMember.user_id).where(
                        ExpertMember.expert_id == sa.new_expert_id,
                        ExpertMember.status == "active",
                    )
                )
                for row in members_result.all():
                    participant_ids.add(row[0])
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "fix: WebSocket broadcast includes team members for consultation chats"
```

---

## Task 7: Fix global unread count for consultation tasks

**Files:**
- Modify: `backend/app/crud/message.py:142-269` (`get_unread_messages`)

**Current bug:** Global unread count only queries tasks where user is `poster_id`, `taker_id`, or `TaskParticipant`. For consultation tasks, the service provider/team member may not be in any of these roles (before Task 1 fix, `taker_id` was NULL).

Even after Task 1 (setting `taker_id`), team members (non-owner) still aren't covered.

- [ ] **Step 1: Add ServiceApplication-based task query to get_unread_messages**

After the existing three task ID collection blocks (poster/taker, participant, expert_creator), add:

```python
    # 4. 作为团队成员的 consultation 任务 (ServiceApplication → ExpertMember)
    from app.models_expert import ExpertMember
    sa_team_query = (
        db.query(models.ServiceApplication.task_id)
        .join(
            ExpertMember,
            and_(
                ExpertMember.expert_id == models.ServiceApplication.new_expert_id,
                ExpertMember.user_id == user_id,
                ExpertMember.status == "active",
            ),
        )
        .filter(
            models.ServiceApplication.new_expert_id.isnot(None),
            models.ServiceApplication.task_id.isnot(None),
        )
    )
    consultation_task_ids = [row[0] for row in sa_team_query.all()]
    all_task_ids.extend(consultation_task_ids)
```

Note: `get_unread_messages` uses **sync** SQLAlchemy (Session, not AsyncSession), so use `db.query()` pattern, not `select()`.

- [ ] **Step 2: Commit**

```bash
git add backend/app/crud/message.py
git commit -m "fix: global unread count includes consultation tasks for team members"
```

---

## Task 8: Close consultations on task acceptance

**Files:**
- Modify: `backend/app/task_chat_business_logic.py:219-223`

- [ ] **Step 1: Expand _reject_other_applications status filter**

```python
# Line 223, change:
models.TaskApplication.status == "pending"
# To:
models.TaskApplication.status.in_(["pending", "consulting", "negotiating", "price_agreed"])
```

- [ ] **Step 2: Close task_consultation placeholder tasks**

Add after the rejection loop:

```python
        # Close task_consultation placeholder tasks that reference this task
        consult_tasks_query = select(models.Task).where(
            and_(
                models.Task.task_source == "task_consultation",
                models.Task.description == f"original_task_id:{task_id}",
                models.Task.status.in_(["consulting", "negotiating"]),
            )
        )
        consult_tasks_result = await db.execute(consult_tasks_query)
        for consult_task in consult_tasks_result.scalars().all():
            consult_task.status = "closed"
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_business_logic.py
git commit -m "feat: close consulting/negotiating applications and placeholder tasks on acceptance"
```

---

## Task 9: Frontend — extend isConsultation for task_consultation

**Files:**
- Modify: `link2ur/lib/data/models/message.dart:325-336`

- [ ] **Step 1: Update isConsultation getter**

```dart
bool get isConsultation =>
    taskSource == 'consultation' ||
    taskSource == 'flea_market_consultation' ||
    taskSource == 'task_consultation' ||  // ← NEW
    serviceApplicationId != null;
```

- [ ] **Step 2: Update consultationTypeParam getter**

```dart
String get consultationTypeParam {
  if (taskSource == 'consultation') return 'service';
  if (taskSource == 'flea_market_consultation') return 'flea_market';
  if (taskSource == 'task_consultation') return 'task';  // ← NEW
  return 'task';
}
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/message.dart
git commit -m "feat: extend isConsultation to recognize task_consultation source"
```

---

## Task 10: Historical data migration

**Files:**
- Create: `backend/migrations/NNN_fix_consultation_taker_id.sql`

Find the next migration number by checking existing files in `backend/migrations/`.

- [ ] **Step 1: Write migration SQL**

```sql
-- Migration: Fix consultation tasks missing taker_id
-- Sets taker_id for historical service/team consultation tasks

-- 1. Service consultations: set taker_id to service owner's user_id
-- For personal services (owner_type='user'), owner_id IS the user_id
UPDATE tasks
SET taker_id = sa.service_owner_id
FROM service_applications sa
WHERE tasks.id = sa.task_id
  AND tasks.task_source = 'consultation'
  AND tasks.taker_id IS NULL
  AND sa.service_owner_id IS NOT NULL;

-- For team services, set taker_id to team owner's user_id
UPDATE tasks
SET taker_id = em.user_id
FROM service_applications sa
JOIN expert_members em ON em.expert_id = sa.new_expert_id
  AND em.role = 'owner'
  AND em.status = 'active'
WHERE tasks.id = sa.task_id
  AND tasks.task_source = 'consultation'
  AND tasks.taker_id IS NULL
  AND sa.new_expert_id IS NOT NULL;
```

- [ ] **Step 2: Note on task consultation historical data**

Existing task consultations (TaskApplication with `status='consulting'` on original tasks) will continue to work as-is — the old `application_id` based messages stay on the original task. Only **new** task consultations will create placeholder tasks. No migration needed for these; they'll coexist with the new pattern.

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/
git commit -m "chore(db): migration to set taker_id on historical consultation tasks"
```

---

## Task 11: Cleanup and verify

- [ ] **Step 1: Search for remaining issues**

```bash
cd link2ur && grep -rn "task_consultation\|original_task_id" lib/ --include="*.dart"
cd ../backend && grep -rn "task_consultation" app/
```

- [ ] **Step 2: Verify designated_task_routes.py fix**

```bash
cd backend && python -c "from app.routes.designated_task_routes import designated_task_router; print('OK')"
```

- [ ] **Step 3: Run Flutter analyze**

```bash
cd link2ur && flutter analyze
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: cleanup and verify consultation chat unification"
```
