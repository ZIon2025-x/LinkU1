# Official Task Completion Flow Design

## Overview

Enable users to complete official tasks by posting in the forum with automatic task association. The flow: user views task details in a bottom sheet → taps "Go Post" → navigates to forum create post page with task association → post success triggers automatic submit + claim → reward granted with SnackBar feedback.

## Decisions

- **Completion method**: Navigate from task detail to forum post creation; post must be created through this flow to count (no retroactive submission of existing posts)
- **Detail UI**: Bottom sheet (not full page) — official tasks are lightweight
- **Submit + Claim**: Merged into one step on the backend; post creation triggers both
- **Reward feedback**: SnackBar after successful post ("Congrats! Earned X points")
- **task_type field fix**: Admin frontend dropdown options changed from frequency types to actual task types (`forum_post` only for now)

## Backend Changes

### 1. Fix admin frontend `task_type` options

**File**: `admin/src/pages/admin/official-tasks/OfficialTaskManagement.tsx`

- Change the `task_type` select options from `one_time/daily/weekly/recurring` to `forum_post`
- Change `initialForm.task_type` default from `'one_time'` to `'forum_post'`

### 2. Merge submit + claim into forum post creation

**File**: `backend/app/forum_routes.py` — `create_post()` endpoint

Add optional `official_task_id` field to `ForumPostCreate` schema. When present in the post creation request:

**Important**: `create_post` uses `AsyncSession` but `add_points_transaction` uses sync `Session`. These cannot share a transaction. The design uses two sequential transactions:

**Transaction 1 (async, existing)**: Create and commit the forum post as normal.

**Transaction 2 (sync, new, after post commit)**: Handle official task reward atomically:
1. Open a sync `Session` via `get_db()`
2. Validate the official task: exists, is_active, not expired, task_type == "forum_post"
3. Validate the user hasn't exceeded max_per_user (use `SELECT ... FOR UPDATE` to prevent race conditions)
4. Create `OfficialTaskSubmission` record with status="claimed", forum_post_id=new_post.id, set claimed_at and reward_amount
5. Award points via `add_points_transaction()` (same sync session)
6. Commit (submission + points are atomic)
7. Set `official_task_reward` on the response

If transaction 2 fails, the forum post (from transaction 1) is already committed and safe. The task reward is just not granted. Log a warning and return `official_task_reward: null`. This matches the design intent: post always succeeds, reward is best-effort.

**Schema changes** (`backend/app/schemas.py`):

```python
# New schema for reward info
class OfficialTaskRewardInfo(BaseModel):
    reward_type: str
    reward_amount: int

# Add to ForumPostCreate:
official_task_id: Optional[int] = None

# Add to ForumPostOut:
official_task_reward: Optional[OfficialTaskRewardInfo] = None
```

### 3. Fix `created_by` column type (already done)

Migration 117 changes `official_tasks.created_by` from Integer to VARCHAR(5).

### 4. Fix list endpoint pagination (already done)

GET `/api/admin/official-tasks` now returns `{ items, total }` format.

## Flutter Frontend Changes

### 1. OfficialTaskCard — wire up onTap

**File**: `link2ur/lib/features/newbie_tasks/views/newbie_tasks_center_view.dart`

Pass `onTap` callback to `OfficialTaskCard` that opens the bottom sheet. Pass the `OfficialTask` object directly to the bottom sheet (no extra API call needed).

### 2. Official Task Detail Bottom Sheet

**New file**: `link2ur/lib/features/newbie_tasks/views/widgets/official_task_bottom_sheet.dart`

Constructor receives `OfficialTask` object directly (data already loaded in state).

Content (top to bottom):
- Drag handle
- "Official" badge + topic tag (if present)
- Task title (locale-aware)
- Task full description (locale-aware, scrollable if long)
- Reward info row: icon + "100 points" style
- Deadline row (if valid_until exists)
- Submission count: uses existing `officialTaskSubmissionCount` l10n key (if max_per_user > 1)
- Bottom button:
  - Active task, not completed: **"Go Post"** (indigo, full-width) → navigates to CreatePostView with officialTaskId
  - Completed (hasReachedLimit): **"Completed"** (grey, disabled) — uses existing `officialTaskCompleted` l10n key
  - Expired: **"Expired"** (grey, disabled)

### 3. CreatePostView — accept officialTaskId parameter

**File**: `link2ur/lib/features/forum/views/create_post_view.dart`

Changes:
- Add optional `int? officialTaskId` and `String? officialTaskTitle` constructor parameters (widget becomes non-const)
- Show a non-dismissible banner/chip at the top when officialTaskId is present: "Official Task: {task title}"
- On submit, include `official_task_id` in the `CreatePostRequest`
- Draft save/restore: when entering via official task flow, skip draft restore and don't save drafts (to avoid orphaned associations)

**File**: `link2ur/lib/data/models/forum.dart` — `CreatePostRequest`

Add `officialTaskId` field. In `toJson()`, include `'official_task_id': officialTaskId` when non-null.

### 4. Route update

**File**: `link2ur/lib/core/router/routes/forum_routes.dart`

The CreatePostView route accepts optional query parameters:
- Navigation: `context.push('/forum/posts/create?officialTaskId=5&officialTaskTitle=...')`
- Route builder reads `state.uri.queryParameters['officialTaskId']` and `['officialTaskTitle']`, passes to CreatePostView

### 5. Reward data carrier — ForumPost model + ForumState

**File**: `link2ur/lib/data/models/forum.dart` — `ForumPost`

Add optional field:
```dart
final Map<String, dynamic>? officialTaskReward; // { reward_type, reward_amount }
```

Parse from JSON in `fromJson()` (backend includes it in response). This field is transient — only present on the response from post creation, not on subsequent fetches.

**File**: `link2ur/lib/features/forum/bloc/forum_bloc.dart` — `ForumState`

Add field:
```dart
final Map<String, dynamic>? lastOfficialTaskReward;
```

In `_onCreatePost`, after successful post creation:
```dart
emit(state.copyWith(
  createPostSuccess: true,
  lastOfficialTaskReward: post.officialTaskReward,
  posts: [post, ...state.posts],
));
```

### 6. Post success — show reward SnackBar

**File**: `link2ur/lib/features/forum/views/create_post_view.dart`

In the BlocListener success handler, check `state.lastOfficialTaskReward`. If non-null, show a SnackBar: "Official task completed! Earned {amount} points" using `officialTaskRewardEarned` l10n key. Then pop.

### 7. State refresh on return

When user pops back from CreatePostView to NewbieTasksCenterView:
- Use `await context.push(...)` on the "Go Post" navigation in the bottom sheet
- After push returns, dispatch `NewbieTasksLoadRequested()` to refresh

## Localization Keys (3 locales)

New keys only (existing keys like `officialTaskCompleted`, `officialTaskSubmissionCount` are reused):

| Key | EN | ZH | ZH-Hant |
|-----|----|----|---------|
| `officialTaskGoPost` | "Go Post" | "去发帖" | "去發帖" |
| `officialTaskExpired` | "Expired" | "已过期" | "已過期" |
| `officialTaskRewardEarned` | "Official task completed! Earned {amount} points" | "官方任务完成！获得 {amount} 积分" | "官方任務完成！獲得 {amount} 積分" |
| `officialTaskLinked` | "Official Task: {title}" | "官方任务：{title}" | "官方任務：{title}" |

## Error Handling

- Official task validation failure during post creation: post still succeeds (same transaction commits without the task records), reward not granted, SnackBar not shown
- Network error during post creation: handled by existing ForumBloc error flow
- Task expired between bottom sheet open and post submit: post succeeds, no reward (edge case, acceptable)
- Rate limit (1 post/min): handled by existing forum error flow, user sees standard rate limit error
- Concurrent duplicate submissions: prevented by `SELECT ... FOR UPDATE` on the submission count check

## Data Flow

```
OfficialTaskCard.onTap
  → showModalBottomSheet(OfficialTaskBottomSheet(task: task))
  → user taps "Go Post"
  → Navigator.pop(bottomSheet)
  → context.push('/forum/posts/create?officialTaskId=5&officialTaskTitle=...')
  → CreatePostView(officialTaskId: 5, officialTaskTitle: "...") shows linked task banner
  → user writes post, taps publish
  → CreatePostRequest.toJson() includes official_task_id: 5
  → POST /api/forum/posts { ..., official_task_id: 5 }
  → Backend: tx1 (async) create post → tx2 (sync) submission + claim + award points
  → Response: { ..., official_task_reward: { reward_type: "points", reward_amount: 100 } }
  → ForumBloc emits createPostSuccess + lastOfficialTaskReward
  → CreatePostView listener shows reward SnackBar, pops
  → Back to NewbieTasksCenterView, dispatches NewbieTasksLoadRequested()
  → Card now shows "Completed" status
```

## Files Changed

| File | Change |
|------|--------|
| `admin/.../OfficialTaskManagement.tsx` | task_type options → `forum_post`, default → `forum_post` |
| `backend/app/schemas.py` | Add `OfficialTaskRewardInfo`, `official_task_id` to ForumPostCreate, `official_task_reward` to ForumPostOut |
| `backend/app/forum_routes.py` | Handle official_task_id in create_post() before commit |
| `link2ur/.../newbie_tasks_center_view.dart` | Wire OfficialTaskCard.onTap → bottom sheet |
| `link2ur/.../official_task_bottom_sheet.dart` | **New** — bottom sheet widget |
| `link2ur/.../create_post_view.dart` | Accept officialTaskId/Title, show banner, skip drafts, pass to request |
| `link2ur/.../forum.dart` (ForumPost) | Add officialTaskReward field |
| `link2ur/.../forum.dart` (CreatePostRequest) | Add officialTaskId field |
| `link2ur/.../forum_bloc.dart` (ForumState) | Add lastOfficialTaskReward field |
| `link2ur/.../forum_bloc.dart` (_onCreatePost) | Store reward info in state |
| `link2ur/.../forum_routes.dart` | Pass officialTaskId/Title query params to CreatePostView |
| `link2ur/l10n/*.arb` | Add 4 new localization keys |
