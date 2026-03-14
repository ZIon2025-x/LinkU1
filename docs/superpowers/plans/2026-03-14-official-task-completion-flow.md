# Official Task Completion Flow — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to complete official tasks by posting in the forum, with automatic submit+claim and reward feedback.

**Architecture:** Backend adds `official_task_id` to forum post creation; after post commits (async), a sync transaction handles submission+claim+points atomically. Flutter adds a bottom sheet for task details, passes officialTaskId to CreatePostView, and shows reward SnackBar on success.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/BLoC/GoRouter (mobile), React (admin)

**Spec:** `docs/superpowers/specs/2026-03-14-official-task-completion-flow-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `admin/src/pages/admin/official-tasks/OfficialTaskManagement.tsx` | Modify | Fix task_type dropdown + default |
| `backend/app/schemas.py` | Modify | Add OfficialTaskRewardInfo, official_task_id to ForumPostCreate, official_task_reward to ForumPostOut |
| `backend/app/forum_routes.py` | Modify | Handle official_task_id after post commit |
| `link2ur/lib/data/models/forum.dart` | Modify | Add officialTaskId to CreatePostRequest, officialTaskReward to ForumPost |
| `link2ur/lib/features/forum/bloc/forum_bloc.dart` | Modify | Add lastOfficialTaskReward to ForumState |
| `link2ur/lib/core/router/routes/forum_routes.dart` | Modify | Pass query params to CreatePostView |
| `link2ur/lib/features/forum/views/create_post_view.dart` | Modify | Accept officialTaskId, show banner, skip drafts, show reward SnackBar |
| `link2ur/lib/features/newbie_tasks/views/widgets/official_task_bottom_sheet.dart` | Create | Bottom sheet with task details + "Go Post" button |
| `link2ur/lib/features/newbie_tasks/views/newbie_tasks_center_view.dart` | Modify | Wire OfficialTaskCard.onTap |
| `link2ur/lib/l10n/app_en.arb` | Modify | Add 4 l10n keys |
| `link2ur/lib/l10n/app_zh.arb` | Modify | Add 4 l10n keys |
| `link2ur/lib/l10n/app_zh_Hant.arb` | Modify | Add 4 l10n keys |

---

## Task 1: Admin Frontend — Fix task_type

**Files:**
- Modify: `admin/src/pages/admin/official-tasks/OfficialTaskManagement.tsx:53,326-329`

- [ ] **Step 1: Change default and dropdown options**

In `OfficialTaskManagement.tsx`, change the `initialForm.task_type` default from `'one_time'` to `'forum_post'` (line 53), and replace the dropdown options (lines 326-329):

```tsx
// Line 53: change default
task_type: 'forum_post',

// Lines 326-329: replace options
<option value="forum_post">Forum Post</option>
```

- [ ] **Step 2: Commit**

```bash
git add admin/src/pages/admin/official-tasks/OfficialTaskManagement.tsx
git commit -m "fix(admin): change official task task_type options to forum_post"
```

---

## Task 2: Backend — Schema Changes

**Files:**
- Modify: `backend/app/schemas.py:3315-3319,3389-3419`

- [ ] **Step 1: Add OfficialTaskRewardInfo schema**

Add **before** `ForumPostCreate` (around line 3314, before line 3315) — it must be defined before `ForumPostOut` which references it:

```python
class OfficialTaskRewardInfo(BaseModel):
    """Reward info returned when an official task is completed via forum post."""
    reward_type: str
    reward_amount: int
```

- [ ] **Step 2: Add official_task_id to ForumPostCreate**

In `ForumPostCreate` (line 3315), add after line 3319 (`linked_item_id`):

```python
    official_task_id: Optional[int] = Field(None, description="关联的官方任务ID，发帖时自动提交+领取奖励")
```

- [ ] **Step 3: Add official_task_reward to ForumPostOut**

In `ForumPostOut` (line 3389), add before `class Config:` (line 3418):

```python
    official_task_reward: Optional[OfficialTaskRewardInfo] = None
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat(backend): add official_task_id to ForumPostCreate and reward info to ForumPostOut"
```

---

## Task 3: Backend — Handle official_task_id in create_post

**Files:**
- Modify: `backend/app/forum_routes.py:3089-3134`

- [ ] **Step 1: Add imports at top of forum_routes.py**

Add these imports near the existing imports (around line 18-24):

```python
from app.database import get_db  # sync session for points transaction
from app.coupon_points_crud import add_points_transaction
```

- [ ] **Step 2: Add official task handling after db.commit()**

After line 3095 (`invalidate_discovery_cache()`), before the `# 加载关联数据` comment (line 3097), insert the official task handling block:

```python
    # === Official Task: submit + claim reward ===
    official_task_reward = None
    if post.official_task_id is not None and db_post.author_id:
        try:
            # Use sync session for add_points_transaction compatibility
            sync_db = next(get_db())
            try:
                # Validate official task
                task = sync_db.query(models.OfficialTask).filter(
                    models.OfficialTask.id == post.official_task_id,
                    models.OfficialTask.is_active == True,
                    models.OfficialTask.task_type == "forum_post",
                ).first()

                if task is None:
                    logger.warning(f"Official task {post.official_task_id} not found or inactive")
                elif task.valid_until and task.valid_until < get_utc_time():
                    logger.warning(f"Official task {post.official_task_id} has expired")
                elif task.valid_from and task.valid_from > get_utc_time():
                    logger.warning(f"Official task {post.official_task_id} not yet started")
                else:
                    # Check max_per_user with FOR UPDATE lock
                    submission_count = sync_db.query(
                        func.count(models.OfficialTaskSubmission.id)
                    ).filter(
                        models.OfficialTaskSubmission.user_id == db_post.author_id,
                        models.OfficialTaskSubmission.official_task_id == task.id,
                    ).with_for_update().scalar() or 0

                    if submission_count >= task.max_per_user:
                        logger.warning(f"User {db_post.author_id} reached max submissions for task {task.id}")
                    else:
                        # Create submission with status=claimed
                        now = get_utc_time()
                        submission = models.OfficialTaskSubmission(
                            user_id=db_post.author_id,
                            official_task_id=task.id,
                            forum_post_id=db_post.id,
                            status="claimed",
                            submitted_at=now,
                            claimed_at=now,
                            reward_amount=task.reward_amount,
                        )
                        sync_db.add(submission)

                        # Award points
                        if task.reward_type == "points" and task.reward_amount > 0:
                            add_points_transaction(
                                db=sync_db,
                                user_id=db_post.author_id,
                                type="earn",
                                amount=task.reward_amount,
                                source="official_task",
                                related_id=task.id,
                                related_type="official_task",
                                description=f"Official task reward: {task.title_zh or task.title_en}",
                                idempotency_key=f"official_task_{task.id}_user_{db_post.author_id}_post_{db_post.id}",
                            )

                        sync_db.commit()
                        official_task_reward = schemas.OfficialTaskRewardInfo(
                            reward_type=task.reward_type,
                            reward_amount=task.reward_amount,
                        )
                        logger.info(f"Official task {task.id} completed by user {db_post.author_id}, reward: {task.reward_amount} {task.reward_type}")
            except Exception as e:
                logger.error(f"Failed to process official task {post.official_task_id}: {e}")
                try:
                    sync_db.rollback()
                except Exception:
                    pass
            finally:
                try:
                    sync_db.close()
                except Exception:
                    pass
        except Exception as e:
            logger.error(f"Failed to get sync db session for official task: {e}")
```

- [ ] **Step 3: Pass official_task_reward to response**

In the `return schemas.ForumPostOut(...)` block (line 3107), add `official_task_reward=official_task_reward` as the last argument before the closing paren:

```python
        linked_item_name=await _resolve_linked_item_name(db, db_post.linked_item_type, db_post.linked_item_id),
        created_at=db_post.created_at,
        updated_at=db_post.updated_at,
        last_reply_at=db_post.last_reply_at,
        official_task_reward=official_task_reward,
    )
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/forum_routes.py
git commit -m "feat(backend): handle official_task_id in create_post - auto submit+claim"
```

---

## Task 4: Flutter — Data Models (CreatePostRequest + ForumPost)

**Files:**
- Modify: `link2ur/lib/data/models/forum.dart:262-294,347-406,600-636`

- [ ] **Step 1: Add officialTaskReward to ForumPost**

In the `ForumPost` constructor (line 262), add after `this.lastReplyAt` (line 293):

```dart
    this.officialTaskReward,
```

Add the field declaration after `final DateTime? lastReplyAt;` (line 326):

```dart
  final Map<String, dynamic>? officialTaskReward;
```

In `ForumPost.fromJson()` (line 347), add after the `lastReplyAt` parse (line 404):

```dart
      officialTaskReward: json['official_task_reward'] as Map<String, dynamic>?,
```

In `ForumPost.props` (the Equatable props list), add `officialTaskReward`.

In `ForumPost.copyWith()`, add the parameter and pass it through. Add parameter:

```dart
    Map<String, dynamic>? officialTaskReward,
```

And in the return, add:

```dart
      officialTaskReward: officialTaskReward ?? this.officialTaskReward,
```

- [ ] **Step 2: Add officialTaskId to CreatePostRequest**

In `CreatePostRequest` constructor (line 601), add after `this.linkedItemId` (line 608):

```dart
    this.officialTaskId,
```

Add the field after `final String? linkedItemId;` (line 617):

```dart
  final int? officialTaskId;
```

In `toJson()` (line 619), add after the linkedItem block (line 634):

```dart
      if (officialTaskId != null) 'official_task_id': officialTaskId,
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/forum.dart
git commit -m "feat(flutter): add officialTaskId to CreatePostRequest and officialTaskReward to ForumPost"
```

---

## Task 5: Flutter — ForumState + ForumBloc

**Files:**
- Modify: `link2ur/lib/features/forum/bloc/forum_bloc.dart:208-356,838-860`

- [ ] **Step 1: Add lastOfficialTaskReward to ForumState**

In the `ForumState` constructor (line 208), add after `this.isLoadingMoreReplies = false` (line 234):

```dart
    this.lastOfficialTaskReward,
```

Add the field declaration after `final bool isLoadingMoreReplies;` (line 266):

```dart
  final Map<String, dynamic>? lastOfficialTaskReward;
```

In `copyWith()` (line 270), add parameter:

```dart
    Map<String, dynamic>? lastOfficialTaskReward,
    bool clearOfficialTaskReward = false,
```

In the `copyWith` return (line 298), add:

```dart
      lastOfficialTaskReward: clearOfficialTaskReward ? null : (lastOfficialTaskReward ?? this.lastOfficialTaskReward),
```

In `props` (line 330), add after `isLoadingMoreReplies` (line 355):

```dart
        lastOfficialTaskReward,
```

- [ ] **Step 2: Update _onCreatePost to store reward info**

Replace the success emit in `_onCreatePost` (lines 847-851):

```dart
        emit(state.copyWith(
          isCreatingPost: false,
          createPostSuccess: true,
          lastOfficialTaskReward: post.officialTaskReward,
          posts: [post, ...state.posts],
        ));
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/forum/bloc/forum_bloc.dart
git commit -m "feat(flutter): add lastOfficialTaskReward to ForumState for reward SnackBar"
```

---

## Task 6: Flutter — Localization Keys

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`, `link2ur/lib/l10n/app_zh.arb`, `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add keys to app_en.arb**

Add after the existing `officialTaskSubmissions` block (after line 4564):

```json
  "officialTaskGoPost": "Go Post",
  "officialTaskExpired": "Expired",
  "officialTaskRewardEarned": "Official task completed! Earned {amount} points",
  "@officialTaskRewardEarned": {
    "description": "SnackBar message when user completes an official task",
    "placeholders": {
      "amount": {
        "type": "String"
      }
    }
  },
  "officialTaskLinked": "Official Task: {title}",
  "@officialTaskLinked": {
    "description": "Banner shown in create post view when linked to an official task",
    "placeholders": {
      "title": {
        "type": "String"
      }
    }
  },
```

- [ ] **Step 2: Add keys to app_zh.arb**

Add after the existing `officialTaskSubmissions` block:

```json
  "officialTaskGoPost": "去发帖",
  "officialTaskExpired": "已过期",
  "officialTaskRewardEarned": "官方任务完成！获得 {amount} 积分",
  "@officialTaskRewardEarned": {
    "description": "SnackBar message when user completes an official task",
    "placeholders": {
      "amount": {
        "type": "String"
      }
    }
  },
  "officialTaskLinked": "官方任务：{title}",
  "@officialTaskLinked": {
    "description": "Banner shown in create post view when linked to an official task",
    "placeholders": {
      "title": {
        "type": "String"
      }
    }
  },
```

- [ ] **Step 3: Add keys to app_zh_Hant.arb**

Same structure, with Traditional Chinese values:

```json
  "officialTaskGoPost": "去發帖",
  "officialTaskExpired": "已過期",
  "officialTaskRewardEarned": "官方任務完成！獲得 {amount} 積分",
  "@officialTaskRewardEarned": {
    "description": "SnackBar message when user completes an official task",
    "placeholders": {
      "amount": {
        "type": "String"
      }
    }
  },
  "officialTaskLinked": "官方任務：{title}",
  "@officialTaskLinked": {
    "description": "Banner shown in create post view when linked to an official task",
    "placeholders": {
      "title": {
        "type": "String"
      }
    }
  },
```

- [ ] **Step 4: Run gen-l10n**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

Expected: `app_localizations.dart` regenerated with new getters.

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat(l10n): add official task completion flow localization keys"
```

---

## Task 7: Flutter — Route Update

**Files:**
- Modify: `link2ur/lib/core/router/routes/forum_routes.dart:36-43`
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart:28-29`

- [ ] **Step 1: Update CreatePostView constructor**

In `create_post_view.dart`, change the constructor (line 28-29):

```dart
class CreatePostView extends StatefulWidget {
  const CreatePostView({
    super.key,
    this.officialTaskId,
    this.officialTaskTitle,
  });

  final int? officialTaskId;
  final String? officialTaskTitle;

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}
```

- [ ] **Step 2: Update GoRouter route to pass query params**

In `forum_routes.dart`, replace lines 36-43 (the createPost route):

```dart
    GoRoute(
      path: AppRoutes.createPost,
      name: 'createPost',
      pageBuilder: (context, state) {
        final officialTaskId = int.tryParse(
          state.uri.queryParameters['officialTaskId'] ?? '',
        );
        final officialTaskTitle =
            state.uri.queryParameters['officialTaskTitle'];
        return SlideUpTransitionPage(
          key: state.pageKey,
          child: CreatePostView(
            officialTaskId: officialTaskId,
            officialTaskTitle: officialTaskTitle,
          ),
        );
      },
    ),
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/router/routes/forum_routes.dart link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(flutter): route passes officialTaskId query param to CreatePostView"
```

---

## Task 8: Flutter — CreatePostView Changes

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart`

- [ ] **Step 1: Skip draft save/restore for official task flow**

In `_CreatePostViewState`, add a helper getter:

```dart
  bool get _isOfficialTaskFlow => widget.officialTaskId != null;
```

In `initState()`, wrap the `_checkForDraft()` call:

```dart
    if (!_isOfficialTaskFlow) {
      _checkForDraft();
    }
```

In `_saveDraft()`, add at the top:

```dart
    if (_isOfficialTaskFlow) return;
```

- [ ] **Step 2: Pass officialTaskId in _submit()**

In `_submit()` (line 282-294), update the `ForumCreatePost` dispatch to include `officialTaskId`:

```dart
    bloc.add(
      ForumCreatePost(
        CreatePostRequest(
          title: title,
          content: content,
          categoryId: _selectedCategoryId!,
          images: imageUrls,
          attachments: uploadedAttachments,
          linkedItemType: _linkedItemType,
          linkedItemId: _linkedItemId,
          officialTaskId: widget.officialTaskId,
        ),
      ),
    );
```

- [ ] **Step 3: Show reward SnackBar on success**

In the BlocListener (line 308-322), update the success handler. Replace the current success block (lines 311-321):

```dart
          } else if (state.createPostSuccess) {
              unawaited(_clearDraft());
              _titleController.clear();
              _contentController.clear();
              _selectedImages.clear();
              _selectedFiles.clear();

              // Show official task reward SnackBar if applicable
              if (state.lastOfficialTaskReward != null) {
                final amount = state.lastOfficialTaskReward!['reward_amount']?.toString() ?? '0';
                AppFeedback.showSuccess(
                  context,
                  context.l10n.officialTaskRewardEarned(amount),
                );
              } else {
                AppFeedback.showSuccess(
                    context, context.l10n.feedbackPostPublishSuccess);
              }
              context.pop();
            }
```

- [ ] **Step 4: Add official task banner in the build method**

In the `builder` (line 324), add a banner widget at the top of the form content area (inside the scrollable area, before the title field). Add this after the draft restore banner (if it exists) or as the first form element:

```dart
              // Official task linked banner
              if (_isOfficialTaskFlow) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: AppRadius.allSmall,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.officialTaskLinked(
                            widget.officialTaskTitle ?? '',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart
git commit -m "feat(flutter): CreatePostView handles officialTaskId - banner, skip draft, reward SnackBar"
```

---

## Task 9: Flutter — Official Task Bottom Sheet

**Files:**
- Create: `link2ur/lib/features/newbie_tasks/views/widgets/official_task_bottom_sheet.dart`

- [ ] **Step 1: Create the bottom sheet widget**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/models/official_task.dart';

/// Bottom sheet showing official task details and "Go Post" action.
class OfficialTaskBottomSheet extends StatelessWidget {
  const OfficialTaskBottomSheet({super.key, required this.task});

  final OfficialTask task;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Badge row: "Official" + topic tag
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.gradientIndigo,
                  ),
                  borderRadius: AppRadius.allTiny,
                ),
                child: Text(
                  l10n.officialTask,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (task.topicTag != null && task.topicTag!.isNotEmpty) ...[
                AppSpacing.hSm,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: AppRadius.allTiny,
                  ),
                  child: Text(
                    '#${task.topicTag}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.vMd,

          // Title
          Text(
            task.displayTitle(locale),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vSm,

          // Description (scrollable if long)
          if (task.displayDescription(locale).isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  task.displayDescription(locale),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          AppSpacing.vMd,

          // Info row: reward + deadline + submission count
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              // Reward
              _InfoChip(
                icon: Icons.card_giftcard_rounded,
                iconColor: AppColors.warning,
                bgColor: AppColors.warningLight,
                text: task.rewardType == 'points'
                    ? l10n.newbieTaskPoints('${task.rewardAmount}')
                    : '${task.rewardAmount}',
              ),
              // Deadline
              if (task.validUntil != null)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  iconColor: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  bgColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  text: l10n.officialTaskDeadline(
                    '${task.validUntil!.month}/${task.validUntil!.day}',
                  ),
                ),
              // Submission count
              if (task.maxPerUser > 1)
                _InfoChip(
                  icon: Icons.repeat_rounded,
                  iconColor: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  bgColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  text: l10n.officialTaskSubmissionCount(
                    '${task.userSubmissionCount}',
                    '${task.maxPerUser}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _buildActionButton(context, isDark, l10n, locale),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    bool isDark,
    dynamic l10n,
    Locale locale,
  ) {
    // Completed
    if (task.hasReachedLimit) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(l10n.officialTaskCompleted),
      );
    }

    // Expired
    if (!task.isCurrentlyValid) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(l10n.officialTaskExpired),
      );
    }

    // Active — Go Post
    return ElevatedButton(
      onPressed: () => _goPost(context, locale),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        l10n.officialTaskGoPost,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _goPost(BuildContext context, Locale locale) async {
    // Close bottom sheet, returning true to signal navigation
    Navigator.of(context).pop(true);
  }

  /// Called from the parent after bottom sheet closes with result=true.
  /// Navigates to CreatePostView and waits for it to return.
  static Future<void> navigateToCreatePost(
    BuildContext context,
    OfficialTask task,
    Locale locale,
  ) async {
    final title = Uri.encodeComponent(task.displayTitle(locale));
    await context.push(
      '${AppRoutes.createPost}?officialTaskId=${task.id}&officialTaskTitle=$title',
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.allTiny,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/newbie_tasks/views/widgets/official_task_bottom_sheet.dart
git commit -m "feat(flutter): add OfficialTaskBottomSheet widget"
```

---

## Task 10: Flutter — Wire OfficialTaskCard.onTap + Refresh

**Files:**
- Modify: `link2ur/lib/features/newbie_tasks/views/newbie_tasks_center_view.dart:151-164`

- [ ] **Step 1: Add import for the bottom sheet**

Add at the top of `newbie_tasks_center_view.dart`:

```dart
import 'widgets/official_task_bottom_sheet.dart';
```

- [ ] **Step 2: Wire onTap to show bottom sheet**

Replace the OfficialTaskCard builder (lines 156-161):

```dart
        itemBuilder: (context, index) {
          final task = state.officialTasks[index];
          return OfficialTaskCard(
            key: ValueKey('official_${task.id}'),
            task: task,
            onTap: () async {
              final shouldNavigate = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => OfficialTaskBottomSheet(task: task),
              );
              if (!context.mounted) return;
              // If user tapped "Go Post", navigate and wait for return
              if (shouldNavigate == true) {
                final locale = Localizations.localeOf(context);
                await OfficialTaskBottomSheet.navigateToCreatePost(
                  context, task, locale,
                );
              }
              // Refresh after CreatePostView returns (or sheet dismissed)
              if (context.mounted) {
                context
                    .read<NewbieTasksBloc>()
                    .add(const NewbieTasksLoadRequested());
              }
            },
          );
        },
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/newbie_tasks/views/newbie_tasks_center_view.dart
git commit -m "feat(flutter): wire OfficialTaskCard.onTap to show bottom sheet + refresh on return"
```

---

## Task 11: Verify & Final Commit

- [ ] **Step 1: Run Flutter analyze**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

Expected: No new errors.

- [ ] **Step 2: Fix any analysis issues found**

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: resolve analysis issues from official task completion flow"
```
