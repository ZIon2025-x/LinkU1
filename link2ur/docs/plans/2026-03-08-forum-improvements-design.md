# Forum Improvements Design

**Date:** 2026-03-08
**Scope:** Category permissions cache fix, nested reply quote preview, post draft saving

---

## 1. Category Permission Cache Fix

### Problem
`getVisibleCategories()` caches under a global key `forum_cat_visible` (not user-scoped).
After logout and re-login as a different user, the new user may see stale categories from the previous user for up to 1 hour (staticTTL).

### Solution

**Three trigger points for cache invalidation:**

1. **Logout** — `AuthBloc._onLogoutRequested()` calls `CacheManager.shared.invalidateForumCache()` before emitting unauthenticated state.
2. **Login success** — All three login handlers (`_onLogin`, `_onLoginWithCode`, `_onLoginWithPhone`) call `CacheManager.shared.invalidateForumCache()` so the next `ForumLoadCategories` always fetches fresh data for the new user.
3. **Student verification success** — After successful verification, dispatch `ForumLoadCategories` to immediately reveal newly-accessible boards.

### Affected Files
- `lib/features/auth/bloc/auth_bloc.dart`
- `lib/features/student_verification/bloc/student_verification_bloc.dart`

---

## 2. Nested Reply Quote Preview

### Current State
Backend returns reply tree; repository flattens to a list preserving `parentReplyId`. UI renders a flat list with no visual indication of which comment a reply is responding to.

### Solution
When a reply has `parentReplyId != null`, display a quote block above the reply content.

**Visual design:**
```
┌─────────────────────────────────────┐
│  ↩ 张三                             │  ← author name, small grey text
│  "被回复内容截断不超过两行..."        │  ← max 2 lines, ellipsis
└─────────────────────────────────────┘
当前回复的正文内容...
```

- Quote block: light grey background (`Colors.grey.shade100` / dark mode variant), left accent border (2px), rounded corners
- Tap quote block: scrolls to parent reply using `ScrollController` + per-reply `GlobalKey`
- Parent not in current page (pagination): show "↩ 回复了 [author]" text only, no tap action

### Implementation Notes
- Look up parent reply in `state.replies` list by `parentReplyId`
- Extract quote widget as `_ReplyQuoteBlock` widget
- Pass `ScrollController` and a `Map<int, GlobalKey>` (replyId → key) down to each reply item
- No model or BLoC changes required

### Affected Files
- `lib/features/forum/views/forum_post_detail_view.dart`

---

## 3. Post Draft Saving

### Storage
`SharedPreferences` key: `forum_create_post_draft`
Value: JSON string with fields:
```json
{
  "title": "...",
  "content": "...",
  "categoryId": 5,
  "savedAt": "2026-03-08T10:30:00.000Z"
}
```

Images and file attachments are **not saved** (file paths become invalid; bytes are too large for SharedPreferences).

### Save Flow
`PopScope.onPopInvokedWithResult` already exists with an "unsaved changes" check.
Modify it: when `_hasUnsavedChanges == true`, show a three-option dialog instead of the current yes/no:

```
你有未完成的内容
[保存草稿]   [不保存]   [取消]
```

- **保存草稿**: write draft to SharedPreferences, then pop
- **不保存**: clear any existing draft, then pop
- **取消**: dismiss dialog, stay on page

### Restore Flow
In `CreatePostView.initState()`:
1. Read draft from SharedPreferences
2. If draft exists and `savedAt` is within 7 days → set a `_hasDraft = true` flag
3. In `build()`, if `_hasDraft == true`, show a restore banner at the top of the form:

```
┌──────────────────────────────────────────┐
│ 📝 你有一个未发送的草稿     [恢复] [放弃] │
└──────────────────────────────────────────┘
```

- **恢复**: populate controllers from draft, hide banner, mark `_hasDraft = false`
- **放弃**: delete draft from SharedPreferences, hide banner

### Auto-clear
- After `ForumCreatePost` succeeds (BLoC listener fires `createPostSuccess`): delete draft
- Drafts older than 7 days are silently ignored on restore check

### Affected Files
- `lib/features/forum/views/create_post_view.dart`

---

## Out of Scope
- **Edit conflict detection**: not needed — only the post author can edit their own posts
- **Multi-draft support**: one global draft is sufficient (YAGNI)
- **Image draft**: too large for SharedPreferences, paths become invalid
