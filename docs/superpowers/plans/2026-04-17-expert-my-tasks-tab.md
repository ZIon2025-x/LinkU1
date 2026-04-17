# Expert My Tasks Tab + Admin Auto-Join Chat — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every expert team member an entry point to see their tasks and enter task chat, and fix the broken invite flow for team-service tasks.

**Architecture:** Three backend changes (bug fix in invite route, admin auto-join on approval, new my-tasks endpoint) plus one new Flutter tab. All data flows through existing `ExpertDashboardBloc` pattern.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/BLoC (frontend)

---

### Task 1: Fix invite endpoint team ID resolution

The invite endpoint (`chat_participant_routes.py`) uses `task.expert_creator_id` to find the team, but team-service tasks only set `task.taker_expert_id`. This breaks the entire invite flow for these tasks.

**Files:**
- Modify: `backend/app/chat_participant_routes.py:85-87` and `130`

- [ ] **Step 1: Fix team ID resolution at line 85-87**

Replace the team ID lookup to prefer `taker_expert_id` (team ID, always correct) with fallback to `expert_creator_id` (legacy path):

```python
# Line 85-87: replace
    expert_id_for_check = getattr(task, 'expert_creator_id', None)
    if not expert_id_for_check:
        raise HTTPException(status_code=400, detail="该任务未关联达人团队，无法邀请成员")
    if expert_id_for_check:
# With:
    expert_id_for_check = getattr(task, 'taker_expert_id', None) or getattr(task, 'expert_creator_id', None)
    if not expert_id_for_check:
        raise HTTPException(status_code=400, detail="该任务未关联达人团队，无法邀请成员")
    if expert_id_for_check:
```

- [ ] **Step 2: Fix team ID resolution at line 130**

Same fix for the "ensure owner is in chat" block:

```python
# Line 130: replace
    expert_creator_id = getattr(task, 'expert_creator_id', None)
# With:
    expert_creator_id = getattr(task, 'taker_expert_id', None) or getattr(task, 'expert_creator_id', None)
```

- [ ] **Step 3: Verify syntax**

Run: `python -c "import ast; ast.parse(open('backend/app/chat_participant_routes.py', encoding='utf-8').read()); print('OK')"`

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add backend/app/chat_participant_routes.py
git commit -m "fix: invite endpoint uses taker_expert_id for team resolution

Team-service tasks only set taker_expert_id (not expert_creator_id),
so invite was broken for all tasks created via service application approval."
```

---

### Task 2: Admin auto-join chat on approval

When an admin (not owner) approves a service application, automatically create ChatParticipant records for poster, owner, and admin.

**Files:**
- Modify: `backend/app/expert_consultation_routes.py:974` (after commit in `_approve_team_service_application`)

- [ ] **Step 1: Add auto-join logic after commit (line 974)**

Insert after `await db.commit()` and before the notification try/except block (line 976):

```python
    await db.commit()

    # 14. Admin 审批时自动加入任务聊天 (best-effort)
    try:
        from app.models_expert import ChatParticipant
        # 始终创建 poster + owner 的 ChatParticipant，保持与 invite 端点的"首次升级"一致
        for uid, role in [
            (application.applicant_id, "client"),
            (taker_id_value, "expert_owner"),
        ]:
            existing = await db.execute(
                select(ChatParticipant).where(
                    and_(ChatParticipant.task_id == new_task.id, ChatParticipant.user_id == uid)
                )
            )
            if not existing.scalar_one_or_none():
                db.add(ChatParticipant(task_id=new_task.id, user_id=uid, role=role))
        # 如果审批人不是 owner，也加入聊天
        if current_user.id != taker_id_value and current_user.id != application.applicant_id:
            existing_admin = await db.execute(
                select(ChatParticipant).where(
                    and_(ChatParticipant.task_id == new_task.id, ChatParticipant.user_id == current_user.id)
                )
            )
            if not existing_admin.scalar_one_or_none():
                db.add(ChatParticipant(
                    task_id=new_task.id,
                    user_id=current_user.id,
                    role="expert_admin",
                ))
        await db.commit()
    except Exception as e:
        logger.warning(f"审批后自动加入聊天失败: {e}")

    # 13. 通知申请人（best-effort，失败不阻塞主流程）
```

- [ ] **Step 2: Verify syntax**

Run: `python -c "import ast; ast.parse(open('backend/app/expert_consultation_routes.py', encoding='utf-8').read()); print('OK')"`

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add backend/app/expert_consultation_routes.py
git commit -m "feat: admin auto-joins task chat on application approval

When an admin (not owner) approves a team service application,
ChatParticipant records are created for poster, owner, and the
approving admin so the admin can immediately access the task chat."
```

---

### Task 3: Backend my-tasks endpoint

New endpoint for the expert dashboard to list tasks by team membership.

**Files:**
- Modify: `backend/app/expert_service_routes.py` (add new route at end of file)

- [ ] **Step 1: Read current end of file to find insertion point**

Read the last 5 lines of `expert_service_routes.py` to confirm where to append.

- [ ] **Step 2: Add the my-tasks endpoint**

Append to `backend/app/expert_service_routes.py`:

```python


# ==================== 团队任务列表 ====================

@expert_service_router.get("/my-tasks")
async def get_expert_my_tasks(
    expert_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """团队成员查看自己参与的任务列表。

    - Owner: 看到该团队所有任务 (taker_expert_id = expert_id)
    - Admin/Member: 只看到自己在 chat_participants 里的任务
    """
    from app.models_expert import ExpertMember, ChatParticipant

    # 权限: 活跃成员
    member_result = await db.execute(
        select(ExpertMember).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
            )
        )
    )
    member = member_result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="不是该团队的活跃成员")

    excluded_statuses = ("deleted", "cancelled")

    if member.role == "owner":
        # Owner 看所有团队任务
        count_q = select(func.count(models.Task.id)).where(
            and_(
                models.Task.taker_expert_id == expert_id,
                models.Task.status.notin_(excluded_statuses),
            )
        )
        total = (await db.execute(count_q)).scalar() or 0

        tasks_q = (
            select(models.Task, models.User)
            .outerjoin(models.User, models.Task.poster_id == models.User.id)
            .where(
                and_(
                    models.Task.taker_expert_id == expert_id,
                    models.Task.status.notin_(excluded_statuses),
                )
            )
            .order_by(models.Task.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await db.execute(tasks_q)).all()

        items = []
        for task, poster in rows:
            items.append(_task_to_dict(task, poster, joined_at=task.accepted_at or task.created_at))
    else:
        # Admin/Member 只看 chat_participants 里有自己的
        count_q = (
            select(func.count(models.Task.id))
            .join(ChatParticipant, ChatParticipant.task_id == models.Task.id)
            .where(
                and_(
                    ChatParticipant.user_id == current_user.id,
                    models.Task.taker_expert_id == expert_id,
                    models.Task.status.notin_(excluded_statuses),
                )
            )
        )
        total = (await db.execute(count_q)).scalar() or 0

        tasks_q = (
            select(models.Task, models.User, ChatParticipant.joined_at)
            .join(ChatParticipant, ChatParticipant.task_id == models.Task.id)
            .outerjoin(models.User, models.Task.poster_id == models.User.id)
            .where(
                and_(
                    ChatParticipant.user_id == current_user.id,
                    models.Task.taker_expert_id == expert_id,
                    models.Task.status.notin_(excluded_statuses),
                )
            )
            .order_by(ChatParticipant.joined_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await db.execute(tasks_q)).all()

        items = []
        for task, poster, joined_at in rows:
            items.append(_task_to_dict(task, poster, joined_at=joined_at))

    return {"items": items, "total": total, "page": page, "page_size": page_size}


def _task_to_dict(task, poster, *, joined_at) -> dict:
    return {
        "id": task.id,
        "title": task.title,
        "status": task.status,
        "task_source": task.task_source,
        "poster_id": task.poster_id,
        "poster_name": getattr(poster, "name", None) if poster else None,
        "poster_avatar": getattr(poster, "avatar", None) if poster else None,
        "reward": float(task.reward) if task.reward else None,
        "currency": task.currency,
        "created_at": task.created_at.isoformat() if task.created_at else None,
        "accepted_at": task.accepted_at.isoformat() if task.accepted_at else None,
        "joined_at": joined_at.isoformat() if joined_at else None,
    }
```

- [ ] **Step 3: Add missing imports at top of file**

Add `func` and `Query` imports if not already present:

```python
from sqlalchemy import select, and_, func
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
```

- [ ] **Step 4: Verify syntax**

Run: `python -c "import ast; ast.parse(open('backend/app/expert_service_routes.py', encoding='utf-8').read()); print('OK')"`

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_service_routes.py
git commit -m "feat: add GET /api/experts/{expert_id}/my-tasks endpoint

Owner sees all team tasks, admin/member sees only tasks they've been
invited to via ChatParticipant. Returns paginated task list with
poster info and joined_at timestamp."
```

---

### Task 4: Flutter — l10n keys

Add localization strings for the new tab and empty state.

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add l10n keys to all three ARB files**

In `app_en.arb`, after `expertDashboardTabActivities`:
```json
  "expertDashboardTabMyTasks": "My Tasks",
  "expertMyTasksEmpty": "No tasks yet",
  "expertMyTasksEmptyMessage": "Tasks you participate in will appear here.",
```

In `app_zh.arb`, after `expertDashboardTabActivities`:
```json
  "expertDashboardTabMyTasks": "我的任务",
  "expertMyTasksEmpty": "暂无任务",
  "expertMyTasksEmptyMessage": "你参与的任务会显示在这里",
```

In `app_zh_Hant.arb`, after `expertDashboardTabActivities`:
```json
  "expertDashboardTabMyTasks": "我的任務",
  "expertMyTasksEmpty": "暫無任務",
  "expertMyTasksEmptyMessage": "你參與的任務會顯示在這裡",
```

- [ ] **Step 2: Generate l10n**

Run from `link2ur/`:
```bash
PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter gen-l10n
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat: add l10n keys for expert My Tasks tab"
```

---

### Task 5: Flutter — BLoC changes (event, state, handler)

Add `myTasks` to state, new event, and handler.

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/bloc/expert_dashboard_state.dart`
- Modify: `link2ur/lib/features/expert_dashboard/bloc/expert_dashboard_event.dart`
- Modify: `link2ur/lib/features/expert_dashboard/bloc/expert_dashboard_bloc.dart`

- [ ] **Step 1: Add `myTasks` to state**

In `expert_dashboard_state.dart`, add field to the class, constructor, copyWith, and props:

```dart
// In constructor — add after activities:
    this.myTasks = const [],

// Field — add after activities:
  final List<Map<String, dynamic>> myTasks;

// In copyWith — add parameter and usage:
    List<Map<String, dynamic>>? myTasks,
    // ... in return body:
      myTasks: myTasks ?? this.myTasks,

// In props — add after activities:
        myTasks,
```

- [ ] **Step 2: Add event**

In `expert_dashboard_event.dart`, add after `ExpertDashboardLoadActivities`:

```dart
class ExpertDashboardLoadMyTasks extends ExpertDashboardEvent {
  const ExpertDashboardLoadMyTasks();
}
```

- [ ] **Step 3: Add handler in bloc**

In `expert_dashboard_bloc.dart`, register event (after `on<ExpertDashboardLoadActivities>`):

```dart
    on<ExpertDashboardLoadMyTasks>(_onLoadMyTasks);
```

Add handler method (after `_onLoadActivities`):

```dart
  Future<void> _onLoadMyTasks(
    ExpertDashboardLoadMyTasks event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final tasks = await _repository.getMyTasks(expertId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        myTasks: tasks,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_my_tasks_failed',
      ));
    }
  }
```

- [ ] **Step 4: Verify**

Run from `link2ur/`:
```bash
PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/features/expert_dashboard/bloc/
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/expert_dashboard/bloc/
git commit -m "feat: add ExpertDashboardLoadMyTasks event and myTasks state"
```

---

### Task 6: Flutter — Repository method + API endpoint

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/repositories/task_expert_repository.dart`

- [ ] **Step 1: Add API endpoint constant**

In `api_endpoints.dart`, after `expertServiceToggleStatus`:

```dart
  static String expertMyTasks(String expertId) =>
      '/api/experts/$expertId/my-tasks';
```

- [ ] **Step 2: Add repository method**

In `task_expert_repository.dart`, add after `toggleServiceStatus`:

```dart
  /// 获取团队任务列表（我参与的）
  Future<List<Map<String, dynamic>>> getMyTasks(String expertId) async {
    final response = await _apiService.get(
      ApiEndpoints.expertMyTasks(expertId),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }
```

- [ ] **Step 3: Verify**

Run from `link2ur/`:
```bash
PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/core/constants/api_endpoints.dart lib/data/repositories/task_expert_repository.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/task_expert_repository.dart
git commit -m "feat: add getMyTasks repository method and API endpoint"
```

---

### Task 7: Flutter — MyTasksTab widget

**Files:**
- Create: `link2ur/lib/features/expert_dashboard/views/tabs/my_tasks_tab.dart`

- [ ] **Step 1: Create the tab widget**

Create `link2ur/lib/features/expert_dashboard/views/tabs/my_tasks_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/router/go_router_extensions.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../bloc/expert_dashboard_bloc.dart';

/// My Tasks tab — shows tasks the current user participates in.
class MyTasksTab extends StatelessWidget {
  const MyTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) =>
          prev.myTasks != curr.myTasks || prev.status != curr.status,
      builder: (context, state) {
        if ((state.status == ExpertDashboardStatus.initial ||
                state.status == ExpertDashboardStatus.loading) &&
            state.myTasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ExpertDashboardStatus.error &&
            state.myTasks.isEmpty) {
          return ErrorStateView(
            message: context.localizeError(
                state.errorMessage ?? 'expert_dashboard_load_my_tasks_failed'),
            onRetry: () => context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadMyTasks()),
          );
        }

        if (state.myTasks.isEmpty) {
          return _EmptyMyTasksView();
        }

        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadMyTasks());
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.myTasks.length,
            itemBuilder: (context, index) {
              final task = state.myTasks[index];
              return Padding(
                key: ValueKey(task['id']),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TaskCard(
                  task: task,
                  onTap: () {
                    final taskId = task['id'];
                    if (taskId is int) {
                      context.goToTaskChat(taskId);
                    } else {
                      final parsed = int.tryParse(taskId.toString());
                      if (parsed != null) context.goToTaskChat(parsed);
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyMyTasksView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.expertMyTasksEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.expertMyTasksEmptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});

  final Map<String, dynamic> task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = (task['title'] as String?) ?? '';
    final posterName = (task['poster_name'] as String?) ?? '';
    final posterAvatar = task['poster_avatar'] as String?;
    final status = (task['status'] as String?) ?? '';
    final reward = task['reward'];
    final currency = (task['currency'] as String?) ?? 'GBP';
    final joinedAt = task['joined_at'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.allMedium,
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMedium,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                    posterAvatar != null ? NetworkImage(posterAvatar) : null,
                child: posterAvatar == null
                    ? Text(
                        posterName.isNotEmpty
                            ? posterName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          posterName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                        ),
                        if (reward != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '$currency ${(reward as num).toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ],
                    ),
                    if (joinedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        joinedAt.substring(0, 10),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(status: status),
              const SizedBox(width: 4),
              Icon(
                Icons.chat_outlined,
                size: 20,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending_payment' => (Colors.orange, 'Pending'),
      'in_progress' => (AppColors.primary, 'Active'),
      'completed' => (Colors.green, 'Done'),
      'pending' => (Colors.orange, 'Pending'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run from `link2ur/`:
```bash
PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/features/expert_dashboard/views/tabs/my_tasks_tab.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/expert_dashboard/views/tabs/my_tasks_tab.dart
git commit -m "feat: add MyTasksTab widget for expert dashboard"
```

---

### Task 8: Flutter — Wire tab into dashboard shell

Add the My Tasks tab between Services and Applications, and trigger data loading.

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/views/expert_dashboard_shell.dart`

- [ ] **Step 1: Add import**

Add at top of file with other tab imports:

```dart
import '../views/tabs/my_tasks_tab.dart';
```

- [ ] **Step 2: Add tab and view between Services and Applications**

In the tabs list (around line 142-151), insert My Tasks after Services:

```dart
    final tabs = <Widget>[
      Tab(icon: const Icon(Icons.dashboard), text: context.l10n.expertDashboardTabStats),
      Tab(icon: const Icon(Icons.design_services), text: context.l10n.expertDashboardTabServices),
      Tab(icon: const Icon(Icons.task_outlined), text: context.l10n.expertDashboardTabMyTasks),
      if (canManage)
        Tab(icon: const Icon(Icons.assignment), text: context.l10n.expertDashboardTabApplications),
      Tab(icon: const Icon(Icons.schedule), text: context.l10n.expertDashboardTabTimeSlots),
      Tab(icon: const Icon(Icons.calendar_month), text: context.l10n.expertDashboardTabSchedule),
      if (canManage)
        Tab(icon: const Icon(Icons.event_outlined), text: context.l10n.expertDashboardTabActivities),
    ];

    final views = <Widget>[
      const StatsTab(),
      const ServicesTab(),
      const MyTasksTab(),
      if (canManage) const ApplicationsTab(),
      const TimeSlotsTab(),
      const ScheduleTab(),
      if (canManage) const ActivitiesTab(),
    ];
```

- [ ] **Step 3: Add `ExpertDashboardLoadMyTasks` to initial load**

Find where `ExpertDashboardLoadMyServices` is dispatched (in the BlocProvider create callback) and add:

```dart
        ..add(const ExpertDashboardLoadMyTasks())
```

- [ ] **Step 4: Verify**

Run from `link2ur/`:
```bash
PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/features/expert_dashboard/
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/expert_dashboard/
git commit -m "feat: wire My Tasks tab into expert dashboard shell

Visible to all roles (owner/admin/member), positioned between
Services and Applications tabs. Data loads on dashboard init."
```

---

### Task 9: Add error localizer mapping

Map the new error code to l10n.

**Files:**
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: Add mapping**

Find the `expertServiceDeactivated` case and add after it:

```dart
      case 'expert_dashboard_load_my_tasks_failed':
        return context.l10n.expertMyTasksEmpty;
```

(Reuse the "暂无任务" string — a load failure in this context just shows the empty state message, which is acceptable for v1.)

- [ ] **Step 2: Verify**

Run from `link2ur/`:
```bash
PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/core/utils/error_localizer.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat: add error localizer mapping for my-tasks load failure"
```
