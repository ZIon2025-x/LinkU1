# Task Profile Visibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow both poster and taker to independently control whether a completed task appears on their public profile page.

**Architecture:** Add `taker_public` column to backend Task model. Modify the existing visibility endpoint to detect caller role and update the corresponding field. On Flutter side, add `isPublic`/`takerPublic` to Task model and a toggle switch on the task detail page for completed tasks.

**Tech Stack:** Python/FastAPI (backend), Flutter/Dart + BLoC (frontend), SQLAlchemy (ORM), Alembic-less migration (direct ALTER TABLE)

---

### Task 1: Backend — Add `taker_public` column and update schema

**Files:**
- Modify: `backend/app/models.py:215-216`
- Modify: `backend/app/schemas.py:402`

**Step 1: Add `taker_public` column to Task model**

In `backend/app/models.py`, after line 215 (`is_public`):

```python
    is_public = Column(Integer, default=1)  # 1=public, 0=private (仅自己可见)
    taker_public = Column(Integer, default=1)  # 1=public, 0=private (接单者主页可见性)
```

**Step 2: Add `taker_public` to TaskOut schema**

In `backend/app/schemas.py`, after line 402 (`is_public`):

```python
    is_public: Optional[int] = 1
    taker_public: Optional[int] = 1
```

**Step 3: Run database migration**

```bash
cd backend
# Connect to Railway DB and run:
# ALTER TABLE tasks ADD COLUMN taker_public INTEGER DEFAULT 1;
```

**Step 4: Commit**

```bash
git add backend/app/models.py backend/app/schemas.py
git commit -m "feat(backend): add taker_public column to Task model"
```

---

### Task 2: Backend — Update visibility endpoint for dual-role support

**Files:**
- Modify: `backend/app/routers.py:2086-2107`

**Step 1: Update the endpoint to handle both poster and taker**

Replace lines 2086-2107 in `backend/app/routers.py`:

```python
@router.patch("/tasks/{task_id}/visibility", response_model=schemas.TaskOut)
def update_task_visibility(
    task_id: int,
    visibility_update: VisibilityUpdate = Body(...),
    current_user=Depends(check_user_status),
    db: Session = Depends(get_db),
):
    """更新任务可见性（发布者更新 is_public，接单者更新 taker_public）"""
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    is_public = visibility_update.is_public

    if task.poster_id == current_user.id:
        task.is_public = is_public
    elif task.taker_id == current_user.id:
        task.taker_public = is_public
    else:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this task"
        )

    db.commit()
    db.refresh(task)
    return task
```

**Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(backend): allow taker to toggle profile visibility"
```

---

### Task 3: Backend — Update public profile query

**Files:**
- Modify: `backend/app/routers.py:4809-4819`

**Step 1: Update recent_tasks query to respect per-role visibility**

Replace lines 4809-4819:

```python
    # 只显示已完成且公开的任务，按时间取最近 3 条
    # 发布者看 is_public，接单者看 taker_public
    recent_tasks_source = (
        db.query(Task)
        .filter(
            Task.status == "completed",
            (
                ((Task.poster_id == user_id) & (Task.is_public == 1))
                | ((Task.taker_id == user_id) & (Task.taker_public == 1))
            ),
        )
        .order_by(Task.created_at.desc())
        .limit(3)
        .all()
    )
```

**Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(backend): filter profile tasks by per-role visibility"
```

---

### Task 4: Flutter — Add `isPublic` and `takerPublic` to Task model

**Files:**
- Modify: `link2ur/lib/data/models/task.dart`

**Step 1: Add fields to constructor (after `counterOfferUserId` at line 64)**

```dart
    this.isPublic = 1,
    this.takerPublic = 1,
```

**Step 2: Add field declarations (after line 124)**

```dart
  final int isPublic;
  final int takerPublic;
```

**Step 3: Add to `fromJson()` (after `counterOfferUserId` parsing at line 415)**

```dart
      isPublic: json['is_public'] as int? ?? 1,
      takerPublic: json['taker_public'] as int? ?? 1,
```

**Step 4: Add to `toJson()` (after `reward_to_be_quoted` at line 464)**

```dart
      'is_public': isPublic,
      'taker_public': takerPublic,
```

**Step 5: Add to `copyWith()` parameters and body**

Add parameters:
```dart
    int? isPublic,
    int? takerPublic,
```

Add to return:
```dart
      isPublic: isPublic ?? this.isPublic,
      takerPublic: takerPublic ?? this.takerPublic,
```

**Step 6: Add to `props` list**

```dart
      isPublic,
      takerPublic,
```

**Step 7: Commit**

```bash
git add link2ur/lib/data/models/task.dart
git commit -m "feat(flutter): add isPublic/takerPublic fields to Task model"
```

---

### Task 5: Flutter — Add BLoC event and handler

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

**Step 1: Add event class (after existing events, before State section)**

```dart
class TaskDetailToggleProfileVisibility extends TaskDetailEvent {
  const TaskDetailToggleProfileVisibility({required this.isPublic});

  final bool isPublic;

  @override
  List<Object?> get props => [isPublic];
}
```

**Step 2: Register handler in bloc constructor (after `_onRespondNegotiation` registration)**

```dart
    on<TaskDetailToggleProfileVisibility>(_onToggleProfileVisibility, transformer: droppable());
```

**Step 3: Add handler method (after `_onRespondNegotiation` handler)**

```dart
  Future<void> _onToggleProfileVisibility(
    TaskDetailToggleProfileVisibility event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.updateTaskVisibility(
        state.task!.id,
        isPublic: event.isPublic,
      );
      // Reload task to get updated is_public/taker_public from server
      final bloc = this;
      bloc.add(TaskDetailLoadRequested(state.task!.id));
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'visibility_updated',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'visibility_update_failed',
        errorMessage: e.toString(),
      ));
    }
  }
```

**Step 4: Commit**

```bash
git add link2ur/lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "feat(flutter): add TaskDetailToggleProfileVisibility event"
```

---

### Task 6: Flutter — Add l10n strings

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

**Step 1: Add strings to all three ARB files**

`app_en.arb`:
```json
  "taskDetailShowOnProfile": "Show on my profile",
  "taskDetailShowOnProfileDesc": "Display this completed task on your public profile",
  "taskDetailVisibilityUpdated": "Profile visibility updated",
  "taskDetailVisibilityUpdateFailed": "Failed to update visibility",
```

`app_zh.arb`:
```json
  "taskDetailShowOnProfile": "展示在我的主页",
  "taskDetailShowOnProfileDesc": "将这个已完成的任务展示在你的公开主页上",
  "taskDetailVisibilityUpdated": "主页展示设置已更新",
  "taskDetailVisibilityUpdateFailed": "更新展示设置失败",
```

`app_zh_Hant.arb`:
```json
  "taskDetailShowOnProfile": "展示在我的主頁",
  "taskDetailShowOnProfileDesc": "將這個已完成的任務展示在你的公開主頁上",
  "taskDetailVisibilityUpdated": "主頁展示設定已更新",
  "taskDetailVisibilityUpdateFailed": "更新展示設定失敗",
```

**Step 2: Regenerate l10n**

```bash
cd link2ur && flutter gen-l10n
```

**Step 3: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat(l10n): add task profile visibility strings"
```

---

### Task 7: Flutter — Add visibility toggle to task detail view

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart`

**Step 1: Add action message handling in listener (after `counter_offer_respond_failed` at line 178)**

```dart
            'visibility_updated' => l10n.taskDetailVisibilityUpdated,
            'visibility_update_failed' => l10n.taskDetailVisibilityUpdateFailed,
```

**Step 2: Add visibility toggle in `_buildBody` (after reviews section at line 569, before counterparty card at line 572)**

```dart
                // 主页展示开关 (已完成 + 当事人)
                if (task.status == AppConstants.taskStatusCompleted &&
                    (isPoster || isTaker)) ...[
                  const SizedBox(height: AppSpacing.md),
                  AnimatedListItem(
                    index: 5,
                    child: _ProfileVisibilityCard(
                      task: task,
                      isPoster: isPoster,
                      isDark: isDark,
                    ),
                  ),
                ],
```

**Step 3: Add the `_ProfileVisibilityCard` widget class (before `_TaskImageCarousel` class)**

```dart
class _ProfileVisibilityCard extends StatelessWidget {
  const _ProfileVisibilityCard({
    required this.task,
    required this.isPoster,
    required this.isDark,
  });

  final Task task;
  final bool isPoster;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isVisible = isPoster ? task.isPublic == 1 : task.takerPublic == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allLarge),
        title: Text(
          context.l10n.taskDetailShowOnProfile,
          style: AppTypography.bodyBold,
        ),
        subtitle: Text(
          context.l10n.taskDetailShowOnProfileDesc,
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        value: isVisible,
        onChanged: (value) {
          context.read<TaskDetailBloc>().add(
                TaskDetailToggleProfileVisibility(isPublic: value),
              );
        },
      ),
    );
  }
}
```

**Step 4: Run analyzer**

```bash
cd link2ur && flutter analyze lib/features/tasks/
```

**Step 5: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat(flutter): add profile visibility toggle on completed task detail"
```

---

### Task 8: Verify end-to-end

**Step 1: Run Flutter analyzer on all modified code**

```bash
cd link2ur && flutter analyze lib/data/models/task.dart lib/features/tasks/ lib/l10n/
```

**Step 2: Test manually**

1. Open a completed task where you are the poster → toggle switch → verify it saves
2. Open a completed task where you are the taker → toggle switch → verify it saves
3. Check the user's public profile → verify hidden tasks no longer appear

**Step 3: Final commit if any fixes needed**
