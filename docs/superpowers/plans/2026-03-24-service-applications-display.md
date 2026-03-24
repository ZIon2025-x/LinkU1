# 服务详情页申请留言展示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在服务详情页展示公开申请留言（含服务所有者回复功能），复用现有 `service_detail_view.dart`，参照任务详情页的 `PublicApplicationsSection` 模式。

**Architecture:** 后端新增 `ServiceApplication.owner_reply`/`owner_reply_at` 字段 + 获取服务申请列表 API + 所有者回复 API。前端在 `TaskExpertBloc` 中添加加载/回复事件，在 `service_detail_view.dart` 中新增申请留言区域。

**Tech Stack:** FastAPI + SQLAlchemy (backend), Flutter BLoC + Equatable (frontend)

---

### Task 1: 后端 — ServiceApplication 模型添加回复字段 + 迁移

**Files:**
- Modify: `backend/app/models.py:1730` (ServiceApplication class)
- Create: `backend/migrations/XXX_add_service_application_reply.sql`

- [ ] **Step 1: 添加字段到 ServiceApplication 模型**

在 `backend/app/models.py` 的 `ServiceApplication` class 中，在 `price_agreed_at` 后面添加：

```python
    owner_reply = Column(Text, nullable=True)  # 服务所有者公开回复
    owner_reply_at = Column(DateTime(timezone=True), nullable=True)  # 回复时间
```

- [ ] **Step 2: 创建数据库迁移文件**

创建 `backend/migrations/XXX_add_service_application_reply.sql`：

```sql
-- 服务申请添加所有者回复字段
ALTER TABLE service_applications ADD COLUMN IF NOT EXISTS owner_reply TEXT;
ALTER TABLE service_applications ADD COLUMN IF NOT EXISTS owner_reply_at TIMESTAMPTZ;
```

- [ ] **Step 3: 在 Railway 上执行迁移**

确认迁移编号（查看 `backend/migrations/` 目录中最新的编号 +1），重命名文件。

---

### Task 2: 后端 — 获取服务公开申请列表 API

**Files:**
- Modify: `backend/app/task_expert_routes.py` (在 `get_service_detail` 端点后添加)

- [ ] **Step 1: 添加获取服务申请列表端点**

在 `backend/app/task_expert_routes.py` 中，`get_service_detail` 函数（约行2372）之后添加：

```python
@task_expert_router.get("/services/{service_id}/applications")
async def get_service_applications(
    service_id: int,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    """获取服务的申请列表（公开留言）

    三种调用者：
    1. 服务所有者 → 完整数据（含 applicant_id）
    2. 已登录非所有者 → 公开列表 + 自己的完整申请
    3. 未登录 → 公开列表
    """
    # 验证服务存在
    service_result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id
        )
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    user_id = str(current_user.id) if current_user else None
    # 判断是否是服务所有者
    is_owner = False
    if user_id:
        if service.service_type == "personal" and service.user_id == user_id:
            is_owner = True
        elif service.service_type == "expert" and service.expert_id == user_id:
            is_owner = True

    # 查询申请列表（只显示有留言或有回复的，排除空申请）
    query = (
        select(models.ServiceApplication)
        .where(models.ServiceApplication.service_id == service_id)
        .where(models.ServiceApplication.status.in_(
            ["pending", "negotiating", "price_agreed", "approved"]
        ))
        .order_by(models.ServiceApplication.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(query)
    applications = result.scalars().all()

    # 批量加载申请者信息
    applicant_ids = list({app.applicant_id for app in applications})
    applicants_map = {}
    if applicant_ids:
        from app import async_crud
        applicants_result = await db.execute(
            select(models.User).where(models.User.id.in_(applicant_ids))
        )
        for u in applicants_result.scalars().all():
            applicants_map[u.id] = u

    items = []
    for app in applications:
        applicant = applicants_map.get(app.applicant_id)
        item = {
            "id": app.id,
            "applicant_name": applicant.name if applicant else "Unknown",
            "applicant_avatar": applicant.avatar if applicant else None,
            "applicant_user_level": applicant.user_level if applicant and hasattr(applicant, "user_level") else None,
            "application_message": app.application_message,
            "negotiated_price": float(app.negotiated_price) if app.negotiated_price else None,
            "currency": app.currency or "GBP",
            "status": app.status,
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "owner_reply": app.owner_reply,
            "owner_reply_at": app.owner_reply_at.isoformat() if app.owner_reply_at else None,
        }
        # 服务所有者可以看到 applicant_id
        if is_owner:
            item["applicant_id"] = app.applicant_id
        # 已登录用户可以看到自己的 applicant_id
        elif user_id and app.applicant_id == user_id:
            item["applicant_id"] = app.applicant_id

        items.append(item)

    return items
```

- [ ] **Step 2: 确认路由不与 `get_service_detail` 冲突**

`/services/{service_id}/applications` 在 `/services/{service_id}` 之后注册，FastAPI 按注册顺序匹配，`/applications` 后缀不会匹配 `{service_id}`，无冲突。

---

### Task 3: 后端 — 服务所有者回复申请 API

**Files:**
- Modify: `backend/app/task_expert_routes.py` (在 Task 2 端点后添加)

- [ ] **Step 1: 添加所有者回复端点**

在 Task 2 的端点之后添加：

```python
@task_expert_router.post("/services/{service_id}/applications/{application_id}/reply")
async def reply_to_service_application(
    service_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """服务所有者对申请的公开回复（每个申请只能回复一次）"""
    body = await request.json()
    message = body.get("message", "").strip()
    if not message:
        raise HTTPException(status_code=400, detail="回复内容不能为空")
    if len(message) > 500:
        raise HTTPException(status_code=400, detail="回复内容不能超过500字")

    # 验证服务存在并且当前用户是所有者
    service_result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id
        )
    )
    service = service_result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")

    user_id = str(current_user.id)
    is_owner = (
        (service.service_type == "personal" and service.user_id == user_id) or
        (service.service_type == "expert" and service.expert_id == user_id)
    )
    if not is_owner:
        raise HTTPException(status_code=403, detail="只有服务所有者可以回复")

    # 验证申请存在且属于该服务
    app_result = await db.execute(
        select(models.ServiceApplication).where(
            models.ServiceApplication.id == application_id,
            models.ServiceApplication.service_id == service_id,
        )
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # 幂等检查：已回复
    if application.owner_reply is not None:
        raise HTTPException(status_code=409, detail="已回复过该申请")

    # 写入回复
    from app.utils.time_utils import get_utc_time
    application.owner_reply = message
    application.owner_reply_at = get_utc_time()
    await db.commit()

    # 发送通知给申请者
    try:
        import json as json_lib
        notification_content = json_lib.dumps({
            "service_id": service_id,
            "service_name": service.service_name,
            "reply_message": message[:200],
            "owner_name": current_user.name if current_user.name else None,
        })
        notification = models.Notification(
            user_id=str(application.applicant_id),
            type="service_owner_reply",
            title="服务所有者回复了你的申请",
            title_en="The service owner replied to your application",
            content=notification_content,
            related_id=service_id,
            related_type="service_id",
        )
        db.add(notification)
        await db.commit()
    except Exception as e:
        logger.warning(f"Failed to create notification for service reply: {e}")

    return {
        "id": application.id,
        "owner_reply": application.owner_reply,
        "owner_reply_at": application.owner_reply_at.isoformat() if application.owner_reply_at else None,
    }
```

---

### Task 4: 前端 — API 端点 + Repository 方法

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart:220` (个人服务端点区域)
- Modify: `link2ur/lib/data/repositories/task_expert_repository.dart` (文件末尾)

- [ ] **Step 1: 添加 API 端点常量**

在 `api_endpoints.dart` 的 task_expert 区域（约行220）添加：

```dart
  static String serviceApplications(int serviceId) =>
      '/api/task-experts/services/$serviceId/applications';
  static String replyServiceApplication(int serviceId, int applicationId) =>
      '/api/task-experts/services/$serviceId/applications/$applicationId/reply';
```

- [ ] **Step 2: 添加 Repository 方法**

在 `task_expert_repository.dart` 文件末尾（最后一个方法之后，class 的 `}` 之前）添加：

```dart
  /// 获取服务的公开申请列表
  Future<List<Map<String, dynamic>>> getServiceApplications(
    int serviceId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiService.get(
      ApiEndpoints.serviceApplications(serviceId),
      queryParameters: {'limit': limit, 'offset': offset},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'load_service_applications_failed');
    }
    final data = response.data;
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  /// 服务所有者回复申请
  Future<Map<String, dynamic>> replyServiceApplication(
    int serviceId,
    int applicationId,
    String message,
  ) async {
    final response = await _apiService.post(
      ApiEndpoints.replyServiceApplication(serviceId, applicationId),
      data: {'message': message},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'reply_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }
```

---

### Task 5: 前端 — TaskExpertBloc 添加事件和处理

**Files:**
- Modify: `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart`

- [ ] **Step 1: 添加新事件类**

在现有事件定义区域（约行187，`TaskExpertApplyToBeExpert` 之后）添加：

```dart
class TaskExpertLoadServiceApplications extends TaskExpertEvent {
  const TaskExpertLoadServiceApplications(this.serviceId);
  final int serviceId;
  @override
  List<Object?> get props => [serviceId];
}

class TaskExpertReplyServiceApplication extends TaskExpertEvent {
  const TaskExpertReplyServiceApplication(
    this.serviceId,
    this.applicationId,
    this.message,
  );
  final int serviceId;
  final int applicationId;
  final String message;
  @override
  List<Object?> get props => [serviceId, applicationId, message];
}
```

- [ ] **Step 2: 添加 state 字段**

在 `TaskExpertState` 的字段列表中添加：

```dart
    this.serviceApplications = const [],
    this.isLoadingServiceApplications = false,
```

对应的字段声明：

```dart
  final List<Map<String, dynamic>> serviceApplications;
  final bool isLoadingServiceApplications;
```

同时更新 `copyWith` 方法和 `props`（添加这两个字段）。

- [ ] **Step 3: 注册事件处理器**

在构造函数的事件注册列表末尾添加：

```dart
    on<TaskExpertLoadServiceApplications>(_onLoadServiceApplications);
    on<TaskExpertReplyServiceApplication>(_onReplyServiceApplication);
```

- [ ] **Step 4: 实现处理函数**

在 BLoC 末尾添加：

```dart
  Future<void> _onLoadServiceApplications(
    TaskExpertLoadServiceApplications event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isLoadingServiceApplications: true));
    try {
      final apps = await _taskExpertRepository.getServiceApplications(event.serviceId);
      emit(state.copyWith(
        isLoadingServiceApplications: false,
        serviceApplications: apps,
      ));
    } catch (e) {
      AppLogger.error('Failed to load service applications', e);
      emit(state.copyWith(isLoadingServiceApplications: false));
    }
  }

  Future<void> _onReplyServiceApplication(
    TaskExpertReplyServiceApplication event,
    Emitter<TaskExpertState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.replyServiceApplication(
        event.serviceId,
        event.applicationId,
        event.message,
      );
      // 更新本地列表中对应的申请记录
      final updated = state.serviceApplications.map((app) {
        if (app['id'] == event.applicationId) {
          return {
            ...app,
            'owner_reply': result['owner_reply'],
            'owner_reply_at': result['owner_reply_at'],
          };
        }
        return app;
      }).toList();
      emit(state.copyWith(
        isSubmitting: false,
        serviceApplications: updated,
        actionMessage: 'service_reply_submitted',
      ));
    } catch (e) {
      AppLogger.error('Failed to reply service application', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }
```

---

### Task 6: 前端 — service_detail_view.dart 添加申请留言展示

**Files:**
- Modify: `link2ur/lib/features/task_expert/views/service_detail_view.dart`

- [ ] **Step 1: 在 ServiceDetailView.build 中触发加载申请列表事件**

在 `ServiceDetailView.build()` 中（约行44），现有的 3 个 `..add()` 之后添加：

```dart
        ..add(TaskExpertLoadServiceApplications(serviceId)),
```

- [ ] **Step 2: 在 body 的 section 列表中添加申请留言区域**

在 `_ServiceDetailContent.build()` 的 Column children 中，`_ReviewsCard` 之后（约行144之后）添加申请区域。需要从 state 中读取 `serviceApplications` 和 `isLoadingServiceApplications`：

```dart
                    // 申请留言区域
                    if (state.serviceApplications.isNotEmpty ||
                        state.isLoadingServiceApplications)
                      _ServiceApplicationsSection(
                        applications: state.serviceApplications,
                        isLoading: state.isLoadingServiceApplications,
                        isDark: isDark,
                        isOwner: _isServiceOwner(state.selectedService),
                        serviceId: serviceId,
                      ),
```

添加 `_isServiceOwner` 辅助方法（在 `_ServiceDetailContent` class 中）：

```dart
  bool _isServiceOwner(TaskExpertService? service) {
    if (service == null) return false;
    final userId = StorageService.instance.getUserId();
    if (userId == null) return false;
    if (service.isPersonalService) {
      return service.userId == userId;
    }
    return service.expertId == userId;
  }
```

- [ ] **Step 3: 实现 _ServiceApplicationsSection widget**

在 `service_detail_view.dart` 文件末尾（最后一个 widget class 之前或之后）添加：

```dart
// =============================================================================
// 服务申请留言区域
// =============================================================================

class _ServiceApplicationsSection extends StatelessWidget {
  const _ServiceApplicationsSection({
    required this.applications,
    required this.isLoading,
    required this.isDark,
    required this.isOwner,
    required this.serviceId,
  });

  final List<Map<String, dynamic>> applications;
  final bool isLoading;
  final bool isDark;
  final bool isOwner;
  final int serviceId;

  @override
  Widget build(BuildContext context) {
    if (isLoading && applications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (applications.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.l10n.applicationMessages(applications.length),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...applications.map((app) => _ServiceApplicationCard(
                application: app,
                isDark: isDark,
                isOwner: isOwner,
                serviceId: serviceId,
              )),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 实现 _ServiceApplicationCard widget**

紧接着添加，参照 `_PublicApplicationCard` 的设计：

```dart
class _ServiceApplicationCard extends StatelessWidget {
  const _ServiceApplicationCard({
    required this.application,
    required this.isDark,
    required this.isOwner,
    required this.serviceId,
  });

  final Map<String, dynamic> application;
  final bool isDark;
  final bool isOwner;
  final int serviceId;

  @override
  Widget build(BuildContext context) {
    final name = (application['applicant_name'] as String?) ?? 'Unknown';
    final avatar = application['applicant_avatar'] as String?;
    final message = application['application_message'] as String?;
    final price = application['negotiated_price'] as num?;
    final createdAt = application['created_at'] as String?;
    final ownerReply = application['owner_reply'] as String?;
    final ownerReplyAt = application['owner_reply_at'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 申请者信息
          Row(
            children: [
              AsyncImageView(
                imageUrl: avatar,
                width: 36,
                height: 36,
                borderRadius: 18,
                placeholderIcon: Icons.person,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null)
                      Text(
                        Helpers.timeAgo(createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // 申请留言
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],

          // 议价价格
          if (price != null && price > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
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
                    '${context.l10n.expertApplicationPrice}: £${Helpers.formatAmountNumber(price)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],

          // 所有者回复
          if (ownerReply != null && ownerReply.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      if (ownerReplyAt != null)
                        Text(
                          Helpers.timeAgo(ownerReplyAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                                fontSize: 10,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(ownerReply,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ]
          // 所有者回复按钮（未回复时显示）
          else if (isOwner) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showReplyDialog(context),
                icon: const Icon(Icons.reply, size: 16),
                label: Text(context.l10n.replyToApplication),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          // 分隔线
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(BuildContext context) {
    final controller = TextEditingController();
    final bloc = context.read<TaskExpertBloc>();
    final appId = application['id'] as int;

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
          bloc.add(TaskExpertReplyServiceApplication(
            serviceId,
            appId,
            text,
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

- [ ] **Step 5: 处理回复成功的 SnackBar 反馈**

在 `_ServiceDetailContent.build()` 的 `BlocConsumer.listener` 中（约行76-100），现有的 `actionMessage` switch 里添加：

```dart
'service_reply_submitted' => context.l10n.commonSubmitSuccess,
```

---

### Task 7: 前端 — 通知跳转支持 service_owner_reply 类型

**Files:**
- Modify: `link2ur/lib/features/notification/views/notification_list_view.dart`

- [ ] **Step 1: 添加通知类型处理**

在 `notification_list_view.dart` 中已有的 `service_application` 相关通知类型 block（约行256-273）中，添加 `service_owner_reply`：

在现有的 `type == 'counter_offer_rejected'` 判断后面添加 `|| type == 'service_owner_reply'`，使其也跳转到 `/service/$relatedId`。

---

### Task 8: 验证和提交

- [ ] **Step 1: 运行 Flutter analyze**

```bash
cd link2ur && flutter analyze lib/features/task_expert/ lib/core/constants/api_endpoints.dart lib/data/repositories/task_expert_repository.dart
```

Expected: No issues found

- [ ] **Step 2: 检查后端语法**

```bash
cd backend && python -c "from app.task_expert_routes import task_expert_router; print('OK')"
```

- [ ] **Step 3: 提交代码**

```bash
git add -A
git commit -m "feat: add public applications display and owner reply on service detail page

- Backend: add owner_reply/owner_reply_at to ServiceApplication model
- Backend: GET /services/{id}/applications for public application list
- Backend: POST /services/{id}/applications/{appId}/reply for owner reply
- Frontend: TaskExpertBloc events for loading/replying service applications
- Frontend: _ServiceApplicationsSection on service_detail_view.dart
- Frontend: notification support for service_owner_reply type"
```
