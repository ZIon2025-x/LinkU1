# Publish Module Bug Fixes

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 10 bugs across the publish module (unified PublishView + standalone create views)

**Architecture:** All changes are in the Flutter frontend. Most fixes are in `publish_view.dart` (unified publish entry point). One fix touches `forum_bloc.dart` error handling, one extracts a shared widget, and one cleans up a standalone view's listener.

**Tech Stack:** Flutter/Dart, BLoC pattern, ARB localization

---

### Task 1: Fix flea market image upload (Critical Bug #1)

`_submitFleaMarket()` hardcodes `images: []`, discarding all user-selected images. Must upload images before creating the request, matching the pattern used by `_submitTask()` and `_submitPost()`.

**Files:**
- Modify: `link2ur/lib/features/publish/views/publish_view.dart`

**Step 1: Make `_submitFleaMarket` async and add image upload logic**

Change `_submitFleaMarket()` from sync to async, upload images via `FleaMarketRepository.uploadImage()` before building the request:

```dart
Future<void> _submitFleaMarket() async {
  if (!_fleaFormKey.currentState!.validate()) return;
  final price = double.tryParse(_fleaPriceCtrl.text.trim());
  if (price == null || price < 0) {
    AppFeedback.showError(context, context.l10n.fleaMarketInvalidPrice);
    return;
  }

  final List<String> imageUrls = [];
  if (_fleaImages.isNotEmpty) {
    setState(() => _isUploading = true);
    try {
      final repo = context.read<FleaMarketRepository>();
      for (final file in _fleaImages) {
        final url = await repo.uploadImage(await file.readAsBytes(), file.name);
        if (url.isNotEmpty) imageUrls.add(url);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        AppFeedback.showError(context, context.l10n.commonImageUploadFailed(e.toString()));
      }
      return;
    }
    if (mounted) setState(() => _isUploading = false);
  }

  if (!mounted) return;
  final request = CreateFleaMarketRequest(
    title: _fleaTitleCtrl.text.trim(),
    description: _fleaDescCtrl.text.trim().isEmpty ? null : _fleaDescCtrl.text.trim(),
    price: price,
    category: _fleaCategory,
    location: _fleaLocation,
    latitude: _fleaLatitude,
    longitude: _fleaLongitude,
    images: imageUrls,
  );
  context.read<FleaMarketBloc>().add(FleaMarketCreateItem(request));
}
```

**Step 2: Update `_submit()` call** — `_submitFleaMarket()` is now a Future, but `_submit()` already calls it without await (fire-and-forget pattern, same as `_submitTask()` and `_submitPost()`). No change needed for the call site since `_submitTask()` is also `Future<void>` and called without await in `_submit()`.

**Step 3: Verify** — run `flutter analyze`

---

### Task 2: Rename `_postUploading` to `_isUploading` (Bug #2)

The variable `_postUploading` is used for task image uploads AND post file uploads, which is misleading.

**Files:**
- Modify: `link2ur/lib/features/publish/views/publish_view.dart`

**Step 1: Rename all occurrences**

Replace all `_postUploading` with `_isUploading` in the file:
- Line 298: declaration `bool _postUploading = false;` → `bool _isUploading = false;`
- Line 433: `setState(() => _postUploading = true);` → `setState(() => _isUploading = true);`
- Line 442: `setState(() => _postUploading = false);` → `setState(() => _isUploading = false);`
- Line 447: `setState(() => _postUploading = false);` → `setState(() => _isUploading = false);`
- Line 519: `setState(() => _postUploading = true);` → `setState(() => _isUploading = true);`
- Line 531: `setState(() => _postUploading = false);` → `setState(() => _isUploading = false);`
- Line 536: `setState(() => _postUploading = false);` → `setState(() => _isUploading = false);`
- Line 709: `... || _postUploading;` → `... || _isUploading;`
- Line 1639: `if (_postUploading)` → `if (_isUploading)`

Use `replace_all` to rename all occurrences at once.

---

### Task 3: Add past-deadline validation to unified task submit (Bug #3)

`_submitTask()` in `publish_view.dart` is missing the past-deadline check that exists in standalone `create_task_view.dart:190-198`.

**Files:**
- Modify: `link2ur/lib/features/publish/views/publish_view.dart`

**Step 1: Add deadline validation after form validation**

Insert after `if (_taskCategoryNotifier.value == null)` block (line 430), before the image upload:

```dart
if (_taskDeadline != null && _taskDeadline!.isBefore(DateTime.now())) {
  AppFeedback.showWarning(context, context.l10n.createTaskSelectDeadline);
  return;
}
```

---

### Task 4: Fix flea market image limit from 9 to 5 (Bug #4)

Backend limits flea market to 5 images. Standalone `create_flea_market_item_view.dart` correctly uses 5. Unified `publish_view.dart` allows 9.

**Files:**
- Modify: `link2ur/lib/features/publish/views/publish_view.dart`

**Step 1: Add constant and update 3 locations**

Add a constant near other constants (after line 274 `_kTaskMaxImages`):
```dart
static const int _kFleaMaxImages = 5;
```

Update `_pickImages()` (line 608):
```dart
if (_fleaImages.length < _kFleaMaxImages) _fleaImages.add(f);
```

Update `_buildFleaImagePicker()` (line 1846):
```dart
if (_fleaImages.length < _kFleaMaxImages)
```

Update counter text (line 1871):
```dart
'${_fleaImages.length}/$_kFleaMaxImages',
```

---

### Task 5: Fix forum create post error handling (Bug #5)

`_onCreatePost` in `forum_bloc.dart` uses raw `e.toString()` instead of an error code. Should use a structured code that maps to l10n.

**Files:**
- Modify: `link2ur/lib/features/forum/bloc/forum_bloc.dart:814-818`
- Modify: `link2ur/lib/core/utils/error_localizer.dart`
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

**Step 1: Change error code in forum_bloc.dart**

```dart
// line 817, change:
errorMessage: e.toString(),
// to:
errorMessage: 'forum_create_post_failed',
```

**Step 2: Add l10n keys to all 3 ARB files**

- `app_en.arb`: `"errorForumCreatePostFailed": "Failed to publish post, please try again"`
- `app_zh.arb`: `"errorForumCreatePostFailed": "发帖失败，请重试"`
- `app_zh_Hant.arb`: `"errorForumCreatePostFailed": "發帖失敗，請重試"`

**Step 3: Add case to error_localizer.dart**

Add before the `default:` case:
```dart
case 'forum_create_post_failed':
  return context.l10n.errorForumCreatePostFailed;
```

**Step 4: Run `flutter gen-l10n` then `flutter analyze`**

---

### Task 6: Extract shared link search dialog (Bug #6)

`_PostLinkSearchDialogContent` in `publish_view.dart` and `_LinkSearchDialog` in `create_post_view.dart` are near-identical duplicates (~180 lines each).

**Files:**
- Create: `link2ur/lib/core/widgets/link_search_dialog.dart`
- Modify: `link2ur/lib/features/publish/views/publish_view.dart`
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

**Step 1: Create shared widget**

Extract to `link2ur/lib/core/widgets/link_search_dialog.dart`. Use the `publish_view.dart` version as the base (it's newer). The class should be public (not `_` prefixed):

```dart
import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../utils/l10n_extension.dart';
import '../utils/logger.dart';
import '../widgets/app_feedback.dart';
import '../../data/repositories/discovery_repository.dart';

/// Shared dialog for searching and linking related content (tasks, flea market items, etc.)
/// Used by both PublishView and CreatePostView.
class LinkSearchDialog extends StatefulWidget {
  const LinkSearchDialog({
    super.key,
    required this.discoveryRepo,
    required this.isDark,
  });

  final DiscoveryRepository discoveryRepo;
  final bool isDark;

  @override
  State<LinkSearchDialog> createState() => _LinkSearchDialogState();
}

class _LinkSearchDialogState extends State<LinkSearchDialog> {
  // ... (copy from _PostLinkSearchDialogContentState, keeping exact same logic)
}
```

**Step 2: Update publish_view.dart**

- Remove `_PostLinkSearchDialogContent` class (lines 66-243)
- Add import: `import '../../../core/widgets/link_search_dialog.dart';`
- Update `_showPostLinkSearchDialog` to use `LinkSearchDialog` instead of `_PostLinkSearchDialogContent`

**Step 3: Update create_post_view.dart**

- Remove `_LinkSearchDialog` class (lines 629-815)
- Add import: `import '../../../core/widgets/link_search_dialog.dart';`
- Update `_showLinkSearchDialog` to use `LinkSearchDialog` instead of `_LinkSearchDialog`

**Step 4: Run `flutter analyze`**

---

### Task 7: Consistent l10n key for task images section (Bug #7)

`publish_view.dart:1328` uses `createTaskImages` ("Images"), while standalone `create_task_view.dart:423` uses `createTaskAddImages` ("Add Images").

**Files:**
- Modify: `link2ur/lib/features/publish/views/publish_view.dart:1328`

**Step 1: Change to match standalone view**

```dart
// Change:
_sectionTitle(context.l10n.createTaskImages),
// To:
_sectionTitle(context.l10n.createTaskAddImages),
```

---

### Task 8: Pass isDark to `_sectionTitle()` (Bug #8)

`_sectionTitle()` calls `Theme.of(context)` on every invocation (~15+ times per build) when `isDark` is already computed and available.

**Files:**
- Modify: `link2ur/lib/features/publish/views/publish_view.dart`

**Step 1: Add isDark parameter to `_sectionTitle`**

```dart
Widget _sectionTitle(String title, {required bool isDark}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    ),
  );
}
```

**Step 2: Update all call sites**

All callers are inside methods that already receive `isDark` (`_buildTaskForm(isDark)`, `_buildFleaMarketForm(isDark)`, `_buildPostForm(isDark, ...)`):

- `_buildTaskForm`: 7 calls → add `isDark: isDark`
- `_buildFleaMarketForm`: 5 calls → add `isDark: isDark`
- `_buildPostForm`: 5 calls → add `isDark: isDark`

---

### Task 9: Clean up flea market create view listener (Bug #9)

`create_flea_market_item_view.dart:207-215` listener handles `purchase_success`, `purchase_failed`, `refresh_success`, `refresh_failed` which can never occur on a create-only page.

**Files:**
- Modify: `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart:204-217`

**Step 1: Remove unreachable cases from listener**

Keep only `item_published` and `publish_failed` (the only actionMessages that can fire from `FleaMarketCreateItem`):

```dart
listener: (context, state) {
  if (state.actionMessage != null) {
    final l10n = context.l10n;
    final isSuccess = state.actionMessage == 'item_published';
    final message = switch (state.actionMessage) {
      'item_published' => l10n.actionItemPublished,
      'publish_failed' => l10n.actionPublishFailed,
      _ => state.actionMessage ?? '',
    };
    final displayMessage = state.errorMessage != null
        ? '$message: ${state.errorMessage}'
        : message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMessage),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
      ),
    );
    if (isSuccess) {
      context.pop();
    }
  }
},
```

---

### Task 10: Final verification

**Step 1: Run `flutter gen-l10n`**

```bash
cd link2ur && flutter gen-l10n
```

**Step 2: Run `flutter analyze`**

```bash
cd link2ur && flutter analyze
```

Expected: No issues found.

---

## File Change Summary

| # | File | Changes |
|---|---|---|
| 1 | `publish_view.dart` | Fix flea image upload, rename `_postUploading`, add deadline check, fix image limit, `_sectionTitle` isDark, l10n key, remove `_PostLinkSearchDialogContent` |
| 2 | `forum_bloc.dart:817` | Error code `'forum_create_post_failed'` |
| 3 | `error_localizer.dart` | Add `forum_create_post_failed` case |
| 4 | `app_en.arb` | Add `errorForumCreatePostFailed` |
| 5 | `app_zh.arb` | Add `errorForumCreatePostFailed` |
| 6 | `app_zh_Hant.arb` | Add `errorForumCreatePostFailed` |
| 7 | `link_search_dialog.dart` (new) | Extracted shared widget |
| 8 | `create_post_view.dart` | Remove `_LinkSearchDialog`, use shared widget |
| 9 | `create_flea_market_item_view.dart` | Clean up listener |
