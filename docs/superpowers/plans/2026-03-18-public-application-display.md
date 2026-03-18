# Public Application Display Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public "application messages" section to the task detail page showing all applicants' messages, quotes, and the poster's one-time reply.

**Architecture:** Backend adds `poster_reply` / `poster_reply_at` columns to `task_applications` table; GET applications endpoint switches to optional auth with three-context response formatting; new POST endpoint for poster public reply. Flutter adds fields to TaskApplication model, new BLoC event/handler, and a new `PublicApplicationsSection` widget in task_detail_components.dart.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/BLoC (frontend)

**Spec:** `docs/superpowers/specs/2026-03-17-public-application-display-design.md`

---

## Chunk 1: Backend Changes

### Task 1: Add poster_reply columns to TaskApplication model

**Files:**
- Modify: `backend/app/models.py:748-771`

- [ ] **Step 1: Add poster_reply and poster_reply_at columns**

In `backend/app/models.py`, add two columns to the `TaskApplication` class after `currency`:

```python
    poster_reply = Column(Text, nullable=True)  # 发布者公开回复
    poster_reply_at = Column(DateTime(timezone=True), nullable=True)  # 回复时间
```

- [ ] **Step 2: Create Alembic migration**

```bash
cd backend
alembic revision --autogenerate -m "add poster_reply fields to task_applications"
```

- [ ] **Step 3: Apply migration**

```bash
alembic upgrade head
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/models.py backend/alembic/versions/
git commit -m "feat: add poster_reply columns to task_applications table"
```

---

### Task 2: Update `_format_application_item` and add public formatter

**Files:**
- Modify: `backend/app/async_routers.py:1125-1141`

- [ ] **Step 1: Add poster_reply fields to existing `_format_application_item`**

**IMPORTANT:** Preserve the existing Decimal error handling for `negotiated_price` (lines 1117-1128). Only add two new fields to the return dict at line ~1139. Add these two lines inside the existing return dict, after `"unread_count": unread_count,`:

```python
        "poster_reply": app.poster_reply,
        "poster_reply_at": format_iso_utc(app.poster_reply_at) if app.poster_reply_at else None,
```

Do NOT replace the existing function — only append the two fields.

- [ ] **Step 2: Add `_format_public_application_item` helper**

Add a new helper right after `_format_application_item`:

```python
def _format_public_application_item(app, user):
    """Format application for public (unauthenticated/unrelated) viewers — excludes applicant_id and unread_count."""
    # Reuse same Decimal-safe negotiated_price handling as _format_application_item
    negotiated_price_value = None
    if app.negotiated_price is not None:
        try:
            from decimal import Decimal
            if isinstance(app.negotiated_price, Decimal):
                negotiated_price_value = float(app.negotiated_price)
            elif isinstance(app.negotiated_price, (int, float)):
                negotiated_price_value = float(app.negotiated_price)
            else:
                negotiated_price_value = float(str(app.negotiated_price))
        except (ValueError, TypeError, AttributeError):
            negotiated_price_value = None
    return {
        "id": app.id,
        "task_id": app.task_id,
        "applicant_name": user.name if user else None,
        "applicant_avatar": user.avatar if user and hasattr(user, 'avatar') else None,
        "applicant_user_level": getattr(user, 'user_level', None) if user else None,
        "message": app.message,
        "negotiated_price": negotiated_price_value,
        "currency": app.currency or "GBP",
        "created_at": format_iso_utc(app.created_at) if app.created_at else None,
        "status": app.status,
        "poster_reply": app.poster_reply,
        "poster_reply_at": format_iso_utc(app.poster_reply_at) if app.poster_reply_at else None,
    }
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/async_routers.py
git commit -m "feat: add poster_reply to application formatters"
```

---

### Task 3: Modify GET `/api/tasks/{task_id}/applications` to support public access

**Files:**
- Modify: `backend/app/async_routers.py:1144-1222`

- [ ] **Step 1: Change auth dependency to optional**

Replace line 1147:
```python
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
```
with:
```python
    current_user: Optional[models.User] = Depends(get_current_user_optional),
```

- [ ] **Step 2: Rewrite the handler logic for three caller contexts**

Replace the body of `get_task_applications` (lines 1152-1222) with:

```python
    """获取任务的申请者列表。
    三种调用者：
    1. 发布者/达人 → 完整数据（含 applicant_id, unread_count）
    2. 已登录非发布者 → 公开列表 + 自己的完整申请（如果有）
    3. 未登录 → 公开列表
    """
    try:
        from sqlalchemy.orm import selectinload

        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()

        if not task:
            raise HTTPException(status_code=404, detail="Task not found")

        user_id_str = str(current_user.id) if current_user else None
        is_poster = (
            user_id_str is not None
            and task.poster_id is not None
            and str(task.poster_id) == user_id_str
        )
        is_expert_creator = (
            user_id_str is not None
            and getattr(task, "is_multi_participant", False)
            and getattr(task, "expert_creator_id", None) is not None
            and str(task.expert_creator_id) == user_id_str
        )

        # ── Poster / expert creator: full data ──
        if is_poster or is_expert_creator:
            applications_query = (
                select(models.TaskApplication)
                .options(selectinload(models.TaskApplication.applicant))
                .where(models.TaskApplication.task_id == task_id)
                .where(models.TaskApplication.status.in_(["pending", "chatting", "approved"]))
                .order_by(models.TaskApplication.created_at.desc())
                .offset(skip)
                .limit(limit)
            )
            applications_result = await db.execute(applications_query)
            applications = applications_result.scalars().all()

            chatting_app_ids = [app.id for app in applications if app.status == "chatting"]
            unread_map: dict[int, int] = {}
            if chatting_app_ids:
                unread_map = await _get_unread_counts_batch(db, task_id, user_id_str, chatting_app_ids)

            result = []
            for app in applications:
                unread = unread_map.get(app.id, 0) if app.status == "chatting" else 0
                result.append(_format_application_item(app, app.applicant, unread))
            return result

        # ── Public list (for logged-in non-poster AND unauthenticated) ──
        public_query = (
            select(models.TaskApplication)
            .options(selectinload(models.TaskApplication.applicant))
            .where(models.TaskApplication.task_id == task_id)
            .where(models.TaskApplication.status.in_(["pending", "chatting", "approved"]))
            .order_by(models.TaskApplication.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        public_result = await db.execute(public_query)
        public_apps = public_result.scalars().all()

        result = []
        for app in public_apps:
            # If the current user is this applicant, return full data
            if user_id_str and str(app.applicant_id) == user_id_str:
                own_unread = 0
                if app.status == "chatting":
                    own_unread = await _get_unread_count(db, task_id, user_id_str, app.id)
                result.append(_format_application_item(app, app.applicant, own_unread))
            else:
                result.append(_format_public_application_item(app, app.applicant))

        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting task applications for {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get applications: {str(e)}")
```

- [ ] **Step 3: Verify the import for Optional at the top of async_routers.py**

Ensure `from typing import Optional` is present (it should already be there since `get_current_user_optional` uses it).

- [ ] **Step 4: Commit**

```bash
git add backend/app/async_routers.py
git commit -m "feat: make GET applications endpoint publicly accessible"
```

---

### Task 4: Add POST public-reply endpoint

**Files:**
- Modify: `backend/app/task_chat_routes.py` (add new endpoint at the end)

- [ ] **Step 1: Add the public-reply endpoint**

Append this endpoint to `task_chat_routes.py`:

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/public-reply")
async def public_reply_to_application(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    """发布者对申请的公开回复（每个申请只能回复一次）"""
    try:
        body = await request.json()
        message = body.get("message", "").strip()
        if not message:
            raise HTTPException(status_code=400, detail="Reply message is required")
        if len(message) > 500:
            raise HTTPException(status_code=400, detail="Reply message must be 500 characters or less")

        # Verify task exists and caller is poster
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        if str(task.poster_id) != str(current_user.id):
            raise HTTPException(status_code=403, detail="Only the task poster can reply")

        # Verify application exists and belongs to this task
        app_result = await db.execute(
            select(models.TaskApplication).where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        # Check if already replied
        if application.poster_reply is not None:
            raise HTTPException(status_code=409, detail="Already replied to this application")

        # Set reply
        application.poster_reply = message
        application.poster_reply_at = get_utc_time()
        await db.commit()

        # Send notification to applicant
        # Note: Notification model has NO sender_id column. Store sender info in content as JSON.
        try:
            import json as _json
            notification_content = _json.dumps({
                "task_id": task_id,
                "task_title": task.title if hasattr(task, 'title') else None,
                "reply_message": message[:200],
                "poster_name": current_user.name if hasattr(current_user, 'name') else None,
            })
            notification = models.Notification(
                user_id=str(application.applicant_id),
                type="public_reply",
                title="发布者回复了你的申请",
                title_en="The poster replied to your application",
                content=notification_content,
                related_id=task_id,
                related_type="task_id",
            )
            db.add(notification)
            await db.commit()
        except Exception as e:
            logger.warning(f"Failed to create notification for public reply: {e}")

        return {
            "id": application.id,
            "poster_reply": application.poster_reply,
            "poster_reply_at": format_iso_utc(application.poster_reply_at) if application.poster_reply_at else None,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in public reply for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to submit reply: {str(e)}")
```

- [ ] **Step 2: Verify necessary imports in task_chat_routes.py**

Ensure these are imported at the top (most should already be present):
- `get_current_user_secure_async_csrf`
- `get_utc_time`, `format_iso_utc`
- `models`, `select`
- `HTTPException`, `Request`, `BackgroundTasks`

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: add POST public-reply endpoint for poster replies"
```

---

## Chunk 2: Flutter Model + Repository + BLoC Changes

### Task 5: Update TaskApplication model

**Files:**
- Modify: `link2ur/lib/data/models/task_application.dart`

- [ ] **Step 1: Add posterReply and posterReplyAt fields**

Add the two fields to the constructor and class body. Full updated file:

```dart
import 'package:equatable/equatable.dart';

/// 任务申请模型
class TaskApplication extends Equatable {
  const TaskApplication({
    required this.id,
    required this.taskId,
    this.applicantId,
    this.applicantName,
    this.applicantAvatar,
    this.applicantUserLevel,
    required this.status,
    this.message,
    this.proposedPrice,
    this.currency,
    this.createdAt,
    this.unreadCount = 0,
    this.posterReply,
    this.posterReplyAt,
  });

  final int id;
  final int taskId;
  final String? applicantId;
  final String? applicantName;
  final String? applicantAvatar;
  final String? applicantUserLevel;
  final String status; // pending, approved, rejected, chatting
  final String? message;
  final double? proposedPrice;
  final String? currency;
  final String? createdAt;
  final int unreadCount;
  final String? posterReply;
  final String? posterReplyAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isChatting => status == 'chatting';

  factory TaskApplication.fromJson(Map<String, dynamic> json) {
    return TaskApplication(
      id: json['id'] as int,
      taskId: json['task_id'] as int? ?? 0,
      applicantId: json['applicant_id']?.toString(),
      applicantName: json['applicant_name'] as String?,
      applicantAvatar: json['applicant_avatar'] as String?,
      applicantUserLevel: json['applicant_user_level'] as String?,
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String?,
      proposedPrice: (json['negotiated_price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      createdAt: json['created_at'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      posterReply: json['poster_reply'] as String?,
      posterReplyAt: json['poster_reply_at'] as String?,
    );
  }

  TaskApplication copyWith({
    int? id,
    int? taskId,
    String? applicantId,
    String? applicantName,
    String? applicantAvatar,
    String? applicantUserLevel,
    String? status,
    String? message,
    double? proposedPrice,
    String? currency,
    String? createdAt,
    int? unreadCount,
    String? posterReply,
    String? posterReplyAt,
  }) {
    return TaskApplication(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      applicantAvatar: applicantAvatar ?? this.applicantAvatar,
      applicantUserLevel: applicantUserLevel ?? this.applicantUserLevel,
      status: status ?? this.status,
      message: message ?? this.message,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
      posterReply: posterReply ?? this.posterReply,
      posterReplyAt: posterReplyAt ?? this.posterReplyAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        taskId,
        applicantId,
        applicantName,
        applicantAvatar,
        applicantUserLevel,
        status,
        message,
        proposedPrice,
        currency,
        createdAt,
        unreadCount,
        posterReply,
        posterReplyAt,
      ];
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/models/task_application.dart
git commit -m "feat: add posterReply fields and copyWith to TaskApplication model"
```

---

### Task 6: Add API endpoint constant and repository method

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/repositories/task_repository.dart`

- [ ] **Step 1: Add endpoint constant**

In `api_endpoints.dart`, find the task applications section (around line 99-100) and add after the existing application endpoints:

```dart
  static String publicReplyApplication(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/public-reply';
```

- [ ] **Step 2: Add repository method**

In `task_repository.dart`, add the method after `replyApplicationMessage` (around line 1060):

```dart
  /// 发布者公开回复申请
  Future<Map<String, dynamic>> publicReplyApplication(
      int taskId, int applicationId, String message) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.publicReplyApplication(taskId, applicationId),
      data: {'message': message},
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '回复失败');
    }

    return response.data!;
  }
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/task_repository.dart
git commit -m "feat: add publicReplyApplication endpoint and repository method"
```

---

### Task 7: Add BLoC event and handler

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

- [ ] **Step 1: Add new event class**

After the existing event classes (around line 315, before the State section), add:

```dart
/// 发布者公开回复申请
class TaskDetailPublicReply extends TaskDetailEvent {
  const TaskDetailPublicReply({
    required this.applicationId,
    required this.message,
  });

  final int applicationId;
  final String message;

  @override
  List<Object> get props => [applicationId, message];
}
```

- [ ] **Step 2: Register event handler in constructor**

In the `TaskDetailBloc` constructor (around line 480), add:

```dart
    on<TaskDetailPublicReply>(_onPublicReply, transformer: droppable());
```

- [ ] **Step 3: Add handler method**

Add the handler method after `_onLoadApplications` (around line 547):

```dart
  Future<void> _onPublicReply(
    TaskDetailPublicReply event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final result = await _taskRepository.publicReplyApplication(
        _taskId!,
        event.applicationId,
        event.message,
      );

      // Update the application in the list with the reply data
      final updatedApps = state.applications.map((app) {
        if (app.id == event.applicationId) {
          return app.copyWith(
            posterReply: result['poster_reply'] as String?,
            posterReplyAt: result['poster_reply_at'] as String?,
          );
        }
        return app;
      }).toList();

      emit(state.copyWith(
        isSubmitting: false,
        applications: updatedApps,
        actionMessage: 'public_reply_submitted',
      ));
    } on TaskException catch (e) {
      final errorCode = e.message.contains('409') || e.message.contains('Already replied')
          ? 'public_reply_already_replied'
          : 'public_reply_failed';
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'public_reply_failed',
        errorMessage: errorCode,
      ));
    } catch (e) {
      AppLogger.error('Failed to submit public reply', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'public_reply_failed',
        errorMessage: 'public_reply_failed',
      ));
    }
  }
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "feat: add TaskDetailPublicReply event and handler"
```

---

### Task 8: Update application loading guard for unauthenticated users

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:245-257`

- [ ] **Step 1: Remove currentUserId != null guard for loading applications**

In `_loadAssociatedData` (line 255), change:

```dart
    if (currentUserId != null && !state.isLoadingApplications && state.applications.isEmpty) {
```

to:

```dart
    if (!state.isLoadingApplications && state.applications.isEmpty) {
```

This allows applications to be loaded for all visitors, including unauthenticated users.

- [ ] **Step 2: Add actionMessage handler for public reply**

In the `listener` switch block (around line 157), add a case for the new action message:

```dart
            'public_reply_submitted' => l10n.replySubmitted,
            'public_reply_failed' => l10n.actionOperationFailed,
```

Add these two lines before the `_ => state.actionMessage ?? '',` default case.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat: allow unauthenticated application loading and public reply feedback"
```

---

## Chunk 3: Flutter UI + Localization

### Task 9: Add PublicApplicationsSection widget

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_components.dart`

- [ ] **Step 1: Add PublicApplicationsSection widget**

First, ensure these imports are present at the top of `task_detail_components.dart`:
```dart
import '../../../core/widgets/user_identity_badges.dart';
```

Then add the following widgets after the existing `ApplicationsListView` class (around line 648, before `_ApplicationItem`):

```dart
// ============================================================
// 公开申请留言区 (所有用户可见)
// ============================================================

class PublicApplicationsSection extends StatelessWidget {
  const PublicApplicationsSection({
    super.key,
    required this.applications,
    required this.isLoading,
    required this.isDark,
    required this.isPoster,
  });

  final List<TaskApplication> applications;
  final bool isLoading;
  final bool isDark;
  final bool isPoster;

  @override
  Widget build(BuildContext context) {
    // Don't show if loading and no applications yet
    if (isLoading && applications.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: const Center(child: LoadingView()),
      );
    }

    if (applications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.applicationMessages(applications.length),
                style: AppTypography.title3.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...applications.map((app) => _PublicApplicationCard(
                key: ValueKey('public_app_${app.id}'),
                application: app,
                isDark: isDark,
                isPoster: isPoster,
              )),
        ],
      ),
    );
  }
}

class _PublicApplicationCard extends StatelessWidget {
  const _PublicApplicationCard({
    super.key,
    required this.application,
    required this.isDark,
    required this.isPoster,
  });

  final TaskApplication application;
  final bool isDark;
  final bool isPoster;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Applicant info row
            Row(
              children: [
                AvatarView(
                  imageUrl: application.applicantAvatar,
                  name: application.applicantName,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              application.applicantName ??
                                  context.l10n.taskDetailUnknownUser,
                              style: AppTypography.bodyBold.copyWith(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (application.applicantUserLevel != null) ...[
                            const SizedBox(width: 4),
                            UserIdentityBadges(
                              userLevel: application.applicantUserLevel,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                      if (application.createdAt != null)
                        Text(
                          DateFormatter.relative(application.createdAt!),
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Application message
            if (application.message != null &&
                application.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                application.message!,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ],

            // Proposed price
            if (application.proposedPrice != null &&
                application.proposedPrice! > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allSmall,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.price_change_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${context.l10n.taskApplicationExpectedAmount}: ${Helpers.formatPrice(application.proposedPrice!)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Poster reply (if exists)
            if (application.posterReply != null &&
                application.posterReply!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.allSmall,
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.reply, size: 14,
                            color: AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.posterReply,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        if (application.posterReplyAt != null)
                          Text(
                            DateFormatter.relative(application.posterReplyAt!),
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.posterReply!,
                      style: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Reply button (poster only, no reply yet)
            if (isPoster &&
                application.posterReply == null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showReplyDialog(context),
                  icon: const Icon(Icons.reply, size: 16),
                  label: Text(context.l10n.replyToApplication),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    textStyle: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReplyDialog(BuildContext context) {
    final controller = TextEditingController();
    final bloc = context.read<TaskDetailBloc>();

    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: context.l10n.replyToApplication,
      barrierDismissible: false,
      contentWidget: TextField(
        controller: controller,
        maxLength: 500,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: context.l10n.publicReplyPlaceholder,
          border: const OutlineInputBorder(),
        ),
      ),
      confirmText: context.l10n.commonSubmit,
      cancelText: context.l10n.commonCancel,
      onConfirm: () {
        final text = controller.text.trim();
        if (text.isNotEmpty) {
          bloc.add(TaskDetailPublicReply(
            applicationId: application.id,
            message: text,
          ));
        }
        controller.dispose();
      },
      onCancel: () {
        controller.dispose();
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_components.dart
git commit -m "feat: add PublicApplicationsSection and PublicApplicationCard widgets"
```

---

### Task 10: Add PublicApplicationsSection to task detail page body

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:564-578`

- [ ] **Step 1: Add public applications section for all users**

In `_buildBody`, right **before** the existing poster-only applications list (line 564), add:

```dart
                // 公开申请留言区 (所有用户可见, open/chatting 任务)
                if (task.status == AppConstants.taskStatusOpen ||
                    task.status == AppConstants.taskStatusChatting) ...[
                  AnimatedListItem(
                    index: 3,
                    child: PublicApplicationsSection(
                      applications: state.applications,
                      isLoading: state.isLoadingApplications,
                      isDark: isDark,
                      isPoster: isPoster,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat: add PublicApplicationsSection to task detail page body"
```

---

### Task 11: Add localization keys

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: Add English localization keys**

Add to `app_en.arb`:

```json
  "applicationMessages": "Applications ({count})",
  "@applicationMessages": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "posterReply": "Poster Reply",
  "replyToApplication": "Reply",
  "replySubmitted": "Reply submitted",
  "publicReplyPlaceholder": "Write your reply to this application...",
  "alreadyReplied": "Already replied to this application"
```

- [ ] **Step 2: Add Simplified Chinese localization keys**

Add to `app_zh.arb`:

```json
  "applicationMessages": "申请留言 ({count})",
  "@applicationMessages": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "posterReply": "发布者回复",
  "replyToApplication": "回复",
  "replySubmitted": "回复已提交",
  "publicReplyPlaceholder": "写下你对这条申请的回复...",
  "alreadyReplied": "已经回复过此申请"
```

- [ ] **Step 3: Add Traditional Chinese localization keys**

Add to `app_zh_Hant.arb`:

```json
  "applicationMessages": "申請留言 ({count})",
  "@applicationMessages": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "posterReply": "發佈者回覆",
  "replyToApplication": "回覆",
  "replySubmitted": "回覆已提交",
  "publicReplyPlaceholder": "寫下你對這條申請的回覆...",
  "alreadyReplied": "已經回覆過此申請"
```

- [ ] **Step 4: Add error codes to ErrorLocalizer**

In `error_localizer.dart`, add cases to the switch block (around line 52):

```dart
      case 'public_reply_failed':
        return context.l10n.actionOperationFailed;
      case 'public_reply_already_replied':
        return context.l10n.alreadyReplied;
```

- [ ] **Step 5: Run localization generation**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat: add localization keys for public application display"
```

---

### Task 12: Verify build

- [ ] **Step 1: Run Flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

- [ ] **Step 2: Fix any analysis errors**

- [ ] **Step 3: Final commit (if fixes needed)**

```bash
git add -A
git commit -m "fix: resolve analysis errors for public application display"
```
