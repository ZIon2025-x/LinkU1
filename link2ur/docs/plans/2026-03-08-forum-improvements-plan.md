# Forum Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix forum category permission caching, add nested reply quote preview, and implement local draft saving for post creation.

**Architecture:** Three independent changes: (1) cache invalidation in AuthBloc + StudentVerificationBloc, (2) a new `_ReplyQuoteBlock` widget inserted into the existing `_ReplyCard`, (3) draft state management inside `CreatePostView` using SharedPreferences.

**Tech Stack:** Flutter/Dart, BLoC, SharedPreferences, existing `CacheManager.shared`

**Design doc:** `docs/plans/2026-03-08-forum-improvements-design.md`

---

## Task 1: Clear forum category cache on login/logout

**Files:**
- Modify: `lib/features/auth/bloc/auth_bloc.dart` (lines 82–112, 115–145, 148–180, 217–228)

**Context:**
`getVisibleCategories()` uses cache key `forum_cat_visible` — a global key not tied to any user. After user A logs out and user B logs in, user B briefly sees user A's cached categories. Fix: call `CacheManager.shared.invalidateForumCache()` on logout and on each login success.

`CacheManager.shared` is a singleton accessible anywhere. `invalidateForumCache()` already exists (see `lib/core/utils/cache_manager.dart:355`).

**Step 1: Add import at top of auth_bloc.dart**

Open `lib/features/auth/bloc/auth_bloc.dart`. After the existing imports, add:

```dart
import '../../../core/utils/cache_manager.dart';
```

**Step 2: Clear cache in `_onLogoutRequested`**

Find `_onLogoutRequested` (around line 217). Insert one line before `emit(const AuthState(...))`:

```dart
Future<void> _onLogoutRequested(
  AuthLogoutRequested event,
  Emitter<AuthState> emit,
) async {
  try {
    await _authRepository.logout();
  } catch (e) {
    AppLogger.error('Logout API failed, clearing local state', e);
  }
  CacheManager.shared.invalidateForumCache();   // ← add this line
  emit(const AuthState(status: AuthStatus.unauthenticated));
}
```

**Step 3: Clear cache in `_onLoginRequested` (email/password login)**

Find the `try` block in `_onLoginRequested` (around line 90). Add the invalidation call right after obtaining the user and before emitting:

```dart
try {
  final user = await _authRepository.login(
    email: event.email,
    password: event.password,
  );
  CacheManager.shared.invalidateForumCache();   // ← add this line
  emit(AuthState(
    status: AuthStatus.authenticated,
    user: user,
  ));
}
```

**Step 4: Do the same in `_onLoginWithCodeRequested`**

Same pattern — add `CacheManager.shared.invalidateForumCache();` after the `loginWithCode` call returns, before `emit(AuthState(...))`.

**Step 5: Do the same in `_onLoginWithPhoneRequested`**

Same pattern — add `CacheManager.shared.invalidateForumCache();` after the phone login call returns, before `emit(AuthState(...))`.

**Step 6: Run tests**

```
cd link2ur
flutter test test/features/auth/bloc/auth_bloc_test.dart
```

Expected: all existing auth tests still pass (cache invalidation is a side effect, not tested separately here).

**Step 7: Commit**

```bash
git add lib/features/auth/bloc/auth_bloc.dart
git commit -m "fix(forum): invalidate category cache on login/logout"
```

---

## Task 2: Refresh forum categories after student verification

**Files:**
- Modify: `lib/features/student_verification/bloc/student_verification_bloc.dart` (around line 164–168)

**Context:**
When `StudentVerificationVerifyEmail` succeeds, the user gains access to `root` and `university` forum boards. We need the forum to refresh so they appear immediately. The `_onVerifyEmail` handler emits `actionMessage: 'verification_success'` — the view's `BlocListener` in `student_verification_view.dart` already listens for this. We add a cache invalidation here so the next `ForumLoadCategories` fetches fresh data.

**Step 1: Add import**

In `lib/features/student_verification/bloc/student_verification_bloc.dart`, add:

```dart
import '../../../core/utils/cache_manager.dart';
```

**Step 2: Add invalidation in `_onVerifyEmail` success branch**

Find `_onVerifyEmail` (around line 157). In the `try` block, after `await _repository.verifyStudentEmail(token: event.code)`, add one line:

```dart
try {
  await _repository.verifyStudentEmail(token: event.code);
  CacheManager.shared.invalidateForumCache();  // ← add this line
  emit(state.copyWith(
    isSubmitting: false,
    actionMessage: 'verification_success',
  ));
  add(const StudentVerificationLoadRequested());
}
```

**Step 3: Run tests**

```
flutter test test/features/student_verification/bloc/student_verification_bloc_test.dart
```

Expected: all pass.

**Step 4: Commit**

```bash
git add lib/features/student_verification/bloc/student_verification_bloc.dart
git commit -m "fix(forum): refresh categories after student verification succeeds"
```

---

## Task 3: Add quote preview to nested replies

**Files:**
- Modify: `lib/features/forum/views/forum_post_detail_view.dart`

**Context:**
`_ReplyCard` (class defined around line 965) already has `reply.isSubReply` which is `true` when `reply.parentReplyId != null`. Currently, sub-replies only get `left: 32` indentation. We will:
1. Add a new `_ReplyQuoteBlock` widget
2. Pass the parent `ForumReply?` into `_ReplyCard`
3. Pass a `Map<int, GlobalKey>` and `ScrollController` for tap-to-scroll
4. Insert `_ReplyQuoteBlock` at the top of the reply's content column when `parentReply != null`

**Step 1: Add `ScrollController` and `_replyKeys` to the state class**

Find the stateful widget that contains `forum_post_detail_view.dart`. Locate the State class fields (around line 50–100). Add:

```dart
final ScrollController _scrollController = ScrollController();
final Map<int, GlobalKey> _replyKeys = {};
```

In `dispose()`, add:

```dart
_scrollController.dispose();
```

**Step 2: Pass `ScrollController` to `CustomScrollView`**

Find the `CustomScrollView` in the build method. Add the controller:

```dart
CustomScrollView(
  controller: _scrollController,
  // existing slivers...
)
```

**Step 3: Update `itemBuilder` to look up parent and assign keys**

Find the `itemBuilder` inside the `SliverList.separated` (around line 473). Replace:

```dart
itemBuilder: (context, index) {
  return _ReplyCard(
    reply: state.replies[index],
    isDark: isDark,
    postId: widget.postId,
    onReplyTo: _setReplyTo,
  );
},
```

With:

```dart
itemBuilder: (context, index) {
  final reply = state.replies[index];
  final key = _replyKeys.putIfAbsent(reply.id, () => GlobalKey());
  ForumReply? parentReply;
  if (reply.parentReplyId != null) {
    try {
      parentReply = state.replies
          .firstWhere((r) => r.id == reply.parentReplyId);
    } catch (_) {
      parentReply = null;
    }
  }
  return _ReplyCard(
    key: key,
    reply: reply,
    parentReply: parentReply,
    isDark: isDark,
    postId: widget.postId,
    onReplyTo: _setReplyTo,
    scrollController: _scrollController,
    replyKeys: _replyKeys,
  );
},
```

**Step 4: Update `_ReplyCard` constructor to accept new parameters**

Find `class _ReplyCard extends StatelessWidget` (around line 965). Update:

```dart
const _ReplyCard({
  super.key,
  required this.reply,
  required this.isDark,
  required this.postId,
  required this.onReplyTo,
  this.parentReply,
  this.scrollController,
  this.replyKeys,
});

final ForumReply reply;
final bool isDark;
final int postId;
final void Function(int replyId, String authorName) onReplyTo;
final ForumReply? parentReply;
final ScrollController? scrollController;
final Map<int, GlobalKey>? replyKeys;
```

**Step 5: Remove the sub-reply left-indent (replaced by quote block)**

In `_ReplyCard.build()`, find the `Padding` with `left: isSubReply ? 32 : 0` (around line 988). Change to:

```dart
return Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  // remove the isSubReply left indent — quote block replaces it
  child: Row(
```

**Step 6: Insert `_ReplyQuoteBlock` above the reply text**

In `_ReplyCard.build()`, find the `Column` that contains the author row and reply content. Insert `_ReplyQuoteBlock` as the **first child** of that column, before the author row:

```dart
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Quote block for nested replies
    if (parentReply != null) ...[
      _ReplyQuoteBlock(
        parentReply: parentReply!,
        isDark: isDark,
        onTap: () {
          final key = replyKeys?[parentReply!.id];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.2,
            );
          }
        },
      ),
      const SizedBox(height: 6),
    ] else if (reply.isSubReply) ...[
      // Parent not in current page — show text-only indicator
      Text(
        '↩ 回复了一条评论',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
        ),
      ),
      const SizedBox(height: 6),
    ],
    // existing author row...
  ],
),
```

**Step 7: Add `_ReplyQuoteBlock` widget**

Add this new private widget class at the bottom of the file, after `_ReplyCard`:

```dart
class _ReplyQuoteBlock extends StatelessWidget {
  const _ReplyQuoteBlock({
    required this.parentReply,
    required this.isDark,
    required this.onTap,
  });

  final ForumReply parentReply;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final authorName = parentReply.author?.name ?? parentReply.authorId;
    final content = parentReply.content;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? AppColors.textTertiaryDark.withValues(alpha: 0.4)
        : AppColors.textTertiaryLight.withValues(alpha: 0.4);
    final textColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: borderColor, width: 2.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '↩ $authorName',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 8: Run the app and verify manually**

```
flutter run
```

Navigate to a post with replies that have sub-replies. Verify:
- Sub-replies show a grey quote block with the parent author name and content preview
- Tapping the quote block scrolls to the parent reply
- Sub-replies without a loaded parent show "↩ 回复了一条评论"
- Top-level replies show no quote block

**Step 9: Run tests**

```
flutter test test/features/forum/bloc/forum_bloc_test.dart
flutter test test/features/forum/bloc/forum_create_edit_test.dart
```

Expected: all pass (no BLoC logic changed).

**Step 10: Commit**

```bash
git add lib/features/forum/views/forum_post_detail_view.dart
git commit -m "feat(forum): add quote preview for nested replies"
```

---

## Task 4: Save/restore post draft locally

**Files:**
- Modify: `lib/features/forum/views/create_post_view.dart`

**Context:**
`CreatePostView` is a `StatefulWidget` with `_titleController`, `_contentController`, and `_selectedCategoryId`. The `PopScope` already intercepts the back gesture when `_hasUnsavedChanges == true` and shows a confirm dialog (lines 244–258). We extend this to offer a "Save draft" option.

Draft is stored in `SharedPreferences` under key `'forum_create_post_draft'` as a JSON string:
```json
{"title": "...", "content": "...", "categoryId": 5, "savedAt": "2026-03-08T..."}
```

`shared_preferences` is already a dependency in this project.

**Step 1: Add import for `shared_preferences` and `dart:convert`**

At the top of `create_post_view.dart`, add:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
```

**Step 2: Add draft constants and state flag to `_CreatePostViewState`**

In the state class body (after `bool _isUploading = false;`), add:

```dart
static const String _kDraftKey = 'forum_create_post_draft';
static const Duration _kDraftMaxAge = Duration(days: 7);
bool _hasDraft = false;
```

**Step 3: Add draft helper methods**

Add these two methods to `_CreatePostViewState` (before `dispose()`):

```dart
Future<void> _saveDraft() async {
  final prefs = await SharedPreferences.getInstance();
  final draft = jsonEncode({
    'title': _titleController.text,
    'content': _contentController.text,
    'categoryId': _selectedCategoryId,
    'savedAt': DateTime.now().toIso8601String(),
  });
  await prefs.setString(_kDraftKey, draft);
}

Future<void> _clearDraft() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kDraftKey);
}

Future<void> _checkForDraft() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kDraftKey);
  if (raw == null) return;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '');
    if (savedAt == null || DateTime.now().difference(savedAt) > _kDraftMaxAge) {
      await _clearDraft();
      return;
    }
    if (!mounted) return;
    setState(() => _hasDraft = true);
  } catch (_) {
    await _clearDraft();
  }
}

Future<void> _restoreDraft() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kDraftKey);
  if (raw == null) return;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _titleController.text = map['title'] as String? ?? '';
    _contentController.text = map['content'] as String? ?? '';
    if (map['categoryId'] != null) {
      setState(() {
        _selectedCategoryId = map['categoryId'] as int?;
        _hasDraft = false;
      });
    } else {
      setState(() => _hasDraft = false);
    }
  } catch (_) {
    setState(() => _hasDraft = false);
  }
}
```

**Step 4: Call `_checkForDraft` in `initState`**

Find `initState` (or add it if not present). Add:

```dart
@override
void initState() {
  super.initState();
  _checkForDraft();
}
```

**Step 5: Clear draft on successful post creation**

Find the `BlocListener` that handles `createPostSuccess` (around line 228–236). Add `_clearDraft()` before `context.pop()`:

```dart
} else if (state.createPostSuccess) {
  _clearDraft();  // ← add this line
  AppFeedback.showSuccess(context, context.l10n.forumPostCreated);
  context.pop();
}
```

**Step 6: Replace the `PopScope` confirm dialog with a three-option draft dialog**

Find the `onPopInvokedWithResult` handler (around line 246–258). Replace the entire `.then(...)` block with a three-option dialog:

```dart
onPopInvokedWithResult: (didPop, _) {
  if (!didPop) {
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('你有未完成的内容'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('保存草稿'),
          ),
        ],
      ),
    ).then((result) {
      if (!context.mounted) return;
      if (result == 'save') {
        _saveDraft().then((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      } else if (result == 'discard') {
        _clearDraft().then((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      }
      // 'cancel' or null: do nothing, stay on page
    });
  }
},
```

**Step 7: Add the draft restore banner to the form body**

Find the `ListView` body (around line 278). The `ListView` has padding and children. Insert the draft banner as the **first child** of the `ListView`:

```dart
body: ListView(
  padding: AppSpacing.allMd,
  children: [
    // Draft restore banner
    if (_hasDraft)
      Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.accentBlue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note, size: 18, color: AppColors.accentBlue),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                '你有一个未发送的草稿',
                style: TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => _clearDraft().then((_) {
                if (mounted) setState(() => _hasDraft = false);
              }),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('放弃', style: TextStyle(fontSize: 13)),
            ),
            FilledButton(
              onPressed: _restoreDraft,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('恢复'),
            ),
          ],
        ),
      ),
    // existing form fields follow...
```

**Step 8: Run tests**

```
flutter test test/features/forum/bloc/forum_bloc_test.dart
flutter test test/features/forum/bloc/forum_create_edit_test.dart
```

Expected: all pass.

**Step 9: Manual verification**

```
flutter run
```

Test flow:
1. Open create post → type a title and some content → press back → choose "保存草稿" → verify pop
2. Re-open create post → verify blue restore banner appears → tap "恢复" → verify title/content restored
3. Open create post again → tap "放弃" → verify banner disappears, fields empty
4. Open create post → type content → publish successfully → re-open → verify NO draft banner appears

**Step 10: Commit**

```bash
git add lib/features/forum/views/create_post_view.dart
git commit -m "feat(forum): save and restore post draft locally"
```

---

## Final Verification

Run the full test suite to confirm nothing is broken:

```bash
flutter test
```

Expected: all 572+ tests pass.

```bash
git log --oneline -5
```

Expected output (4 new commits on top):
```
feat(forum): save and restore post draft locally
feat(forum): add quote preview for nested replies
fix(forum): refresh categories after student verification succeeds
fix(forum): invalidate category cache on login/logout
```
