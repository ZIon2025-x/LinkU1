# Taker Counter-Offer for Designated Tasks Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let the designated task taker propose a counter-offer price; poster can accept (task proceeds to in_progress) or reject (task stays pending_acceptance). Also extend existing negotiate token TTL from 5 min to 24 h.

**Architecture:** New fields on the `Task` model store the pending counter-offer (price + status + taker ID). Two new backend endpoints handle submit/respond. Flutter task detail view shows new buttons for both sides; BLoC handles the events. Notification types prefixed with `task_` so they route automatically to task detail.

**Tech Stack:** FastAPI/SQLAlchemy (backend), Flutter/BLoC (frontend), PostgreSQL (DB via Alembic or `create_all`)

---

## Task 1: Backend — Extend Negotiation Token TTL

**Files:**
- Modify: `backend/app/task_chat_routes.py` (two occurrences of `300` for accept/reject tokens in the `negotiate_application` function, around line 2103)

**Step 1: Find both `setex` calls in `negotiate_application`**

Search for `ex=300` or `setex(..., 300,` in `task_chat_routes.py` inside the `negotiate_application` function. There are two: one for `token_accept`, one for `token_reject`.

**Step 2: Change TTL from 300 to 86400**

```python
# Before (both occurrences):
redis_client.setex(
    f"negotiation_token:{token_accept}",
    300,  # 5分钟
    json.dumps(token_data_accept)
)
# ...
redis_client.setex(
    f"negotiation_token:{token_reject}",
    300,  # 5分钟
    json.dumps(token_data_reject)
)

# After:
redis_client.setex(
    f"negotiation_token:{token_accept}",
    86400,  # 24小时
    json.dumps(token_data_accept)
)
# ...
redis_client.setex(
    f"negotiation_token:{token_reject}",
    86400,  # 24小时
    json.dumps(token_data_reject)
)
```

**Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "fix(negotiate): extend negotiation token TTL from 5 min to 24 h"
```

---

## Task 2: Backend — Add Counter-Offer Fields to Task Model

**Files:**
- Modify: `backend/app/models.py` — add 3 columns to `class Task(Base)`
- Modify: `backend/app/schemas.py` — add fields to `TaskResponse` (or equivalent response schema)

**Step 1: Add columns to the Task model**

In `backend/app/models.py`, inside `class Task(Base)`, add after existing fields (e.g., after `stripDisputeFrozen`):

```python
# 被指定方反报价
counter_offer_price = Column(DECIMAL(12, 2), nullable=True)        # 被指定方提出的价格
counter_offer_status = Column(String(20), nullable=True)            # None / 'pending' / 'accepted' / 'rejected'
counter_offer_user_id = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
```

Make sure `DECIMAL` is imported at the top of models.py (it should already be, since `negotiated_price` uses it in `TaskApplication`).

**Step 2: Run DB migration**

If the project uses Alembic:
```bash
cd backend
alembic revision --autogenerate -m "add counter offer fields to task"
alembic upgrade head
```

If the project uses `Base.metadata.create_all` (check `main.py`): just restart the server and it will add columns automatically on SQLite; for PostgreSQL, run the Alembic commands above. If neither works, add columns directly:
```sql
ALTER TABLE tasks ADD COLUMN counter_offer_price DECIMAL(12,2);
ALTER TABLE tasks ADD COLUMN counter_offer_status VARCHAR(20);
ALTER TABLE tasks ADD COLUMN counter_offer_user_id VARCHAR(8);
```

**Step 3: Add fields to TaskResponse schema**

Find `TaskResponse` (or `TaskOut` or similar) in `backend/app/schemas.py`. Add:

```python
counter_offer_price: Optional[float] = None
counter_offer_status: Optional[str] = None
counter_offer_user_id: Optional[str] = None
```

**Step 4: Commit**

```bash
git add backend/app/models.py backend/app/schemas.py
git commit -m "feat(task): add counter_offer fields to Task model and schema"
```

---

## Task 3: Backend — POST /tasks/{id}/taker-counter-offer

**Files:**
- Modify: `backend/app/task_chat_routes.py` — add new endpoint after existing application endpoints

**Step 1: Add request schema** (add near other request schemas in `task_chat_routes.py` or `schemas.py`):

```python
class TakerCounterOfferRequest(BaseModel):
    price: float = Field(..., ge=0.01, le=50000.0, description="反报价金额（英镑）")
```

**Step 2: Add endpoint**

Add this function in `task_chat_routes.py` (after the `negotiate_application` function is a good place):

```python
@task_chat_router.post("/tasks/{task_id}/taker-counter-offer")
async def taker_counter_offer(
    task_id: int,
    request: TakerCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    被指定方提出反报价。
    任务必须处于 pending_acceptance 状态，current_user 必须是被指定的接单方。
    """
    # 1. 获取任务
    result = await db.execute(
        select(models.Task).where(models.Task.id == task_id)
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    # 2. 验证任务状态
    if task.status != "pending_acceptance":
        raise HTTPException(status_code=400, detail="任务不在待接受状态")

    # 3. 验证当前用户是被指定方（不是发布方）
    if task.poster_id == current_user.id:
        raise HTTPException(status_code=403, detail="发布方不能提交反报价")

    # 4. 防止重复提交（若已有 pending 反报价）
    if task.counter_offer_status == "pending":
        raise HTTPException(status_code=400, detail="已有待处理的反报价，请等待对方回应")

    # 5. 存储反报价
    task.counter_offer_price = Decimal(str(request.price))
    task.counter_offer_status = "pending"
    task.counter_offer_user_id = current_user.id

    await db.commit()

    # 6. 通知发布方
    try:
        from app.utils.notification_utils import create_notification_async
        await create_notification_async(
            db=db,
            recipient_id=task.poster_id,
            notification_type="task_counter_offer",
            related_id=task_id,
            related_type="task_id",
            task_id=task_id,
            sender_id=current_user.id,
        )
    except Exception as e:
        logging.warning(f"反报价通知发送失败: {e}")

    return {
        "message": "反报价已提交",
        "task_id": task_id,
        "counter_offer_price": float(task.counter_offer_price),
        "counter_offer_status": task.counter_offer_status,
    }
```

> **Note:** Check the exact import path for `create_notification_async`. In the existing codebase, notifications are likely created via a utility function already used in this file. Search for `create_notification` or `send_notification` calls in `task_chat_routes.py` and use the same pattern. Also import `Decimal` from `decimal` at the top if not already imported.

**Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat(task): add POST /tasks/{id}/taker-counter-offer endpoint"
```

---

## Task 4: Backend — POST /tasks/{id}/respond-taker-counter-offer

**Files:**
- Modify: `backend/app/task_chat_routes.py` — add after the endpoint from Task 3

**Step 1: Add request schema:**

```python
class RespondTakerCounterOfferRequest(BaseModel):
    action: str = Field(..., description="'accept' 或 'reject'")
```

**Step 2: Add endpoint:**

```python
@task_chat_router.post("/tasks/{task_id}/respond-taker-counter-offer")
async def respond_taker_counter_offer(
    task_id: int,
    request: RespondTakerCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    发布方响应被指定方的反报价（接受或拒绝）。
    接受：更新任务价格，创建申请记录，将任务推进到 in_progress。
    拒绝：清除反报价，任务保持 pending_acceptance。
    """
    if request.action not in ("accept", "reject"):
        raise HTTPException(status_code=400, detail="action 必须为 accept 或 reject")

    # 1. 获取任务（加锁防并发）
    result = await db.execute(
        select(models.Task)
        .where(models.Task.id == task_id)
        .with_for_update()
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    # 2. 验证发布方
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="只有发布方可以响应反报价")

    # 3. 验证有待处理的反报价
    if task.counter_offer_status != "pending" or task.counter_offer_price is None:
        raise HTTPException(status_code=400, detail="没有待处理的反报价")

    taker_id = task.counter_offer_user_id
    counter_price = task.counter_offer_price

    if request.action == "accept":
        # 更新任务价格和状态
        task.base_reward = counter_price
        task.agreed_reward = counter_price
        task.taker_id = taker_id
        task.status = "in_progress"
        task.accepted_at = get_utc_time()
        task.counter_offer_status = "accepted"

        # 创建申请记录（已批准）
        application = models.TaskApplication(
            task_id=task_id,
            applicant_id=taker_id,
            status="approved",
            negotiated_price=counter_price,
            currency=task.currency or "GBP",
        )
        db.add(application)

        await db.commit()

        # 通知接单方
        try:
            from app.utils.notification_utils import create_notification_async
            await create_notification_async(
                db=db,
                recipient_id=taker_id,
                notification_type="task_counter_offer_accepted",
                related_id=task_id,
                related_type="task_id",
                task_id=task_id,
                sender_id=current_user.id,
            )
        except Exception as e:
            logging.warning(f"反报价接受通知发送失败: {e}")

        return {
            "message": "已接受反报价，任务进入进行中",
            "task_status": task.status,
            "agreed_price": float(task.agreed_reward),
        }

    else:  # reject
        task.counter_offer_status = "rejected"
        # 清除反报价数据（让接单方可以重新提交）
        task.counter_offer_price = None
        task.counter_offer_user_id = None

        await db.commit()

        # 通知接单方
        try:
            from app.utils.notification_utils import create_notification_async
            await create_notification_async(
                db=db,
                recipient_id=taker_id,
                notification_type="task_counter_offer_rejected",
                related_id=task_id,
                related_type="task_id",
                task_id=task_id,
                sender_id=current_user.id,
            )
        except Exception as e:
            logging.warning(f"反报价拒绝通知发送失败: {e}")

        return {
            "message": "已拒绝反报价，任务保持待接受状态",
            "task_status": task.status,
        }
```

> **Note on `create_notification_async` signature:** Find an existing call to this function in `task_chat_routes.py` and match the exact parameter names. Common differences: `sender_id` might be `actor_id`, or it may not exist. Drop any unsupported parameters.

**Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat(task): add POST /tasks/{id}/respond-taker-counter-offer endpoint"
```

---

## Task 5: Flutter — Update Task Model + API Endpoints + Repository

**Files:**
- Modify: `link2ur/lib/data/models/task.dart`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/repositories/task_repository.dart`

### 5a: Task model

In `link2ur/lib/data/models/task.dart`, add 3 fields to the `Task` class:

**Constructor — add to named parameters:**
```dart
this.counterOfferPrice,
this.counterOfferStatus,
this.counterOfferUserId,
```

**Field declarations — add after existing fields:**
```dart
final double? counterOfferPrice;    // 被指定方提出的反报价
final String? counterOfferStatus;   // null / 'pending' / 'accepted' / 'rejected'
final String? counterOfferUserId;   // 提出反报价的用户ID
```

**Getter — add a convenience getter:**
```dart
bool get hasCounterOfferPending => counterOfferStatus == 'pending';
```

**fromJson — add inside `Task.fromJson`:**
```dart
counterOfferPrice: (json['counter_offer_price'] as num?)?.toDouble(),
counterOfferStatus: json['counter_offer_status'] as String?,
counterOfferUserId: json['counter_offer_user_id'] as String?,
```

**copyWith — add to `copyWith` method:**
```dart
double? counterOfferPrice,
String? counterOfferStatus,
String? counterOfferUserId,
// inside return Task(...):
counterOfferPrice: counterOfferPrice ?? this.counterOfferPrice,
counterOfferStatus: counterOfferStatus ?? this.counterOfferStatus,
counterOfferUserId: counterOfferUserId ?? this.counterOfferUserId,
```

**props — add to `List<Object?> get props`:**
```dart
counterOfferPrice, counterOfferStatus, counterOfferUserId,
```

### 5b: API endpoints

In `link2ur/lib/core/constants/api_endpoints.dart`, add after `respondNegotiation`:

```dart
static String takerCounterOffer(int taskId) =>
    '/api/tasks/$taskId/taker-counter-offer';
static String respondTakerCounterOffer(int taskId) =>
    '/api/tasks/$taskId/respond-taker-counter-offer';
```

### 5c: Repository methods

In `link2ur/lib/data/repositories/task_repository.dart`, add after `respondNegotiation`:

```dart
/// 被指定方提交反报价
Future<void> submitTakerCounterOffer(int taskId, {required double price}) async {
  final response = await _apiService.post(
    ApiEndpoints.takerCounterOffer(taskId),
    data: {'price': price},
  );
  if (!response.isSuccess) {
    throw TaskException(response.message ?? 'counter_offer_submit_failed');
  }
}

/// 发布方响应被指定方的反报价
Future<void> respondTakerCounterOffer(
  int taskId, {
  required String action, // 'accept' or 'reject'
}) async {
  final response = await _apiService.post(
    ApiEndpoints.respondTakerCounterOffer(taskId),
    data: {'action': action},
  );
  if (!response.isSuccess) {
    throw TaskException(response.message ?? 'counter_offer_respond_failed');
  }
}
```

**Step: Commit**

```bash
git add link2ur/lib/data/models/task.dart \
        link2ur/lib/core/constants/api_endpoints.dart \
        link2ur/lib/data/repositories/task_repository.dart
git commit -m "feat(task): add counter-offer fields, endpoints, and repo methods"
```

---

## Task 6: Flutter — Add L10n Strings

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

**Step 1: Add to `app_en.arb`** (insert near other `taskDetail*` keys):

```json
"taskDetailCounterOffer": "Counter-Offer",
"taskDetailCounterOfferHint": "Enter your proposed price (GBP)",
"taskDetailCounterOfferSent": "Counter-offer sent, waiting for response",
"taskDetailCounterOfferPending": "Counter-offer pending",
"taskDetailPosterCounterOfferTitle": "Taker proposed a counter-offer",
"taskDetailPosterCounterOfferPrice": "Proposed price",
"taskDetailAcceptCounterOffer": "Accept Price",
"taskDetailRejectCounterOffer": "Reject"
```

**Step 2: Add to `app_zh.arb`:**

```json
"taskDetailCounterOffer": "议价",
"taskDetailCounterOfferHint": "输入您的报价（GBP）",
"taskDetailCounterOfferSent": "反报价已发送，等待对方回应",
"taskDetailCounterOfferPending": "议价等待回应",
"taskDetailPosterCounterOfferTitle": "对方提出了反报价",
"taskDetailPosterCounterOfferPrice": "对方报价",
"taskDetailAcceptCounterOffer": "同意报价",
"taskDetailRejectCounterOffer": "拒绝"
```

**Step 3: Add to `app_zh_Hant.arb`:**

```json
"taskDetailCounterOffer": "議價",
"taskDetailCounterOfferHint": "輸入您的報價（GBP）",
"taskDetailCounterOfferSent": "反報價已發送，等待對方回應",
"taskDetailCounterOfferPending": "議價等待回應",
"taskDetailPosterCounterOfferTitle": "對方提出了反報價",
"taskDetailPosterCounterOfferPrice": "對方報價",
"taskDetailAcceptCounterOffer": "同意報價",
"taskDetailRejectCounterOffer": "拒絕"
```

**Step 4: Regenerate l10n**

```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter gen-l10n
```

Expected: no errors, updated files in `.dart_tool/flutter_gen/gen_l10n/`.

**Step 5: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat(l10n): add counter-offer strings in en/zh/zh_Hant"
```

---

## Task 7: Flutter — BLoC Events and Handlers

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

### 7a: Add Events

Find the events section (search for `class TaskDetailEvent`) and add:

```dart
/// 被指定方提交反报价
class TaskDetailSubmitCounterOfferRequested extends TaskDetailEvent {
  const TaskDetailSubmitCounterOfferRequested({required this.price});
  final double price;
  @override
  List<Object?> get props => [price];
}

/// 发布方响应被指定方的反报价
class TaskDetailRespondCounterOfferRequested extends TaskDetailEvent {
  const TaskDetailRespondCounterOfferRequested({required this.action});
  final String action; // 'accept' or 'reject'
  @override
  List<Object?> get props => [action];
}
```

### 7b: Register handlers in constructor

Find the `TaskDetailBloc` constructor where `on<...>()` calls are registered. Add:

```dart
on<TaskDetailSubmitCounterOfferRequested>(_onSubmitCounterOffer);
on<TaskDetailRespondCounterOfferRequested>(_onRespondCounterOffer);
```

### 7c: Add handler methods

Add these methods in the BLoC class body (after `_onQuoteDesignatedPrice`):

```dart
Future<void> _onSubmitCounterOffer(
  TaskDetailSubmitCounterOfferRequested event,
  Emitter<TaskDetailState> emit,
) async {
  if (_taskId == null || state.isSubmitting) return;
  emit(state.copyWith(isSubmitting: true, errorMessage: null));
  try {
    await _taskRepository.submitTakerCounterOffer(_taskId!, price: event.price);
    final task = await _refreshTask();
    emit(state.copyWith(
      task: task,
      isSubmitting: false,
      actionMessage: 'counter_offer_submitted',
    ));
  } catch (e) {
    AppLogger.error('Failed to submit counter offer', e);
    emit(state.copyWith(
      isSubmitting: false,
      actionMessage: 'counter_offer_submit_failed',
      errorMessage: e.toString(),
    ));
  }
}

Future<void> _onRespondCounterOffer(
  TaskDetailRespondCounterOfferRequested event,
  Emitter<TaskDetailState> emit,
) async {
  if (_taskId == null || state.isSubmitting) return;
  emit(state.copyWith(isSubmitting: true, errorMessage: null));
  try {
    await _taskRepository.respondTakerCounterOffer(_taskId!, action: event.action);
    final task = await _refreshTask();
    emit(state.copyWith(
      task: task,
      isSubmitting: false,
      actionMessage: event.action == 'accept'
          ? 'counter_offer_accepted'
          : 'counter_offer_rejected',
    ));
  } catch (e) {
    AppLogger.error('Failed to respond to counter offer', e);
    emit(state.copyWith(
      isSubmitting: false,
      actionMessage: 'counter_offer_respond_failed',
      errorMessage: e.toString(),
    ));
  }
}
```

**Step: Commit**

```bash
git add link2ur/lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "feat(task-bloc): add counter-offer submit and respond events/handlers"
```

---

## Task 8: Flutter — Task Detail View UI

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart`

This task has two UI additions:

### 8a: Taker side — add "议价" button

Find the section (search for `isTaker && task.status == AppConstants.taskStatusPendingAcceptance`), specifically the `else` branch (when `!task.rewardToBeQuoted`) that shows `[拒绝]` and `[接受]`:

**Before:**
```dart
return Row(
  children: [
    Expanded(
      child: OutlinedButton(
        onPressed: () => _showDeclineDesignatedTaskConfirm(context),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
        child: Text(context.l10n.taskDetailDeclineDesignated),
      ),
    ),
    AppSpacing.hMd,
    Expanded(
      child: PrimaryButton(
        text: context.l10n.taskDetailAcceptDesignated,
        onPressed: () {
          context.read<TaskDetailBloc>().add(
            TaskDetailQuoteDesignatedPriceRequested(
              price: task.baseReward ?? task.reward,
            ),
          );
        },
      ),
    ),
  ],
);
```

**After — wrap in conditional and add 议价 button:**

```dart
// 若有 pending 反报价，显示等待状态
if (task.hasCounterOfferPending) {
  return Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.medium),
    ),
    child: Row(
      children: [
        const Icon(Icons.hourglass_top, color: AppColors.primary, size: 18),
        AppSpacing.hSm,
        Text(
          context.l10n.taskDetailCounterOfferSent,
          style: const TextStyle(color: AppColors.primary, fontSize: 13),
        ),
      ],
    ),
  );
}
// 正常三按钮布局
return Row(
  children: [
    Expanded(
      child: OutlinedButton(
        onPressed: () => _showDeclineDesignatedTaskConfirm(context),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
        child: Text(context.l10n.taskDetailDeclineDesignated),
      ),
    ),
    AppSpacing.hSm,
    Expanded(
      child: OutlinedButton(
        onPressed: () => _showCounterOfferSheet(context, task),
        child: Text(context.l10n.taskDetailCounterOffer),
      ),
    ),
    AppSpacing.hSm,
    Expanded(
      child: PrimaryButton(
        text: context.l10n.taskDetailAcceptDesignated,
        onPressed: () {
          context.read<TaskDetailBloc>().add(
            TaskDetailQuoteDesignatedPriceRequested(
              price: task.baseReward ?? task.reward,
            ),
          );
        },
      ),
    ),
  ],
);
```

### 8b: Add `_showCounterOfferSheet` method

Add this method to the view's State class (near `_showQuoteDesignatedPriceSheet`):

```dart
void _showCounterOfferSheet(BuildContext context, Task task) {
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.taskDetailCounterOffer),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: context.l10n.taskDetailCounterOfferHint,
          prefixText: '£ ',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            final price = double.tryParse(controller.text.trim());
            if (price == null || price <= 0) return;
            Navigator.of(dialogContext).pop();
            context.read<TaskDetailBloc>().add(
              TaskDetailSubmitCounterOfferRequested(price: price),
            );
          },
          child: Text(context.l10n.confirm),
        ),
      ],
    ),
  ).whenComplete(() => controller.dispose());
}
```

> **Note:** Check that `context.l10n.cancel` and `context.l10n.confirm` exist. If not, use the actual key names from the ARB files (search for "取消" or "确认" in the ARB files to find the key names).

### 8c: Poster side — show counter-offer card

Find the section where poster sees actions for `pending_acceptance` status. This is likely in a separate `if (isPoster && ...)` block. Add a counter-offer response card.

Find where the poster's task detail action buttons are built for `pending_acceptance` status. Insert the counter-offer response UI as a new block **before** the existing poster buttons (or wrap to check for counter offer first):

```dart
// 发布方 + 反报价 pending
if (isPoster &&
    task.status == AppConstants.taskStatusPendingAcceptance &&
    task.hasCounterOfferPending &&
    task.counterOfferPrice != null) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.taskDetailPosterCounterOfferTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${context.l10n.taskDetailPosterCounterOfferPrice}: '
              '£${task.counterOfferPrice!.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: state.isSubmitting
                  ? null
                  : () => context.read<TaskDetailBloc>().add(
                        const TaskDetailRespondCounterOfferRequested(action: 'reject'),
                      ),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(context.l10n.taskDetailRejectCounterOffer),
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: PrimaryButton(
              text: context.l10n.taskDetailAcceptCounterOffer,
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting
                  ? null
                  : () => context.read<TaskDetailBloc>().add(
                        const TaskDetailRespondCounterOfferRequested(action: 'accept'),
                      ),
            ),
          ),
        ],
      ),
    ],
  );
}
```

> **Note:** `const TaskDetailRespondCounterOfferRequested(action: 'reject')` requires the event to have a `const` constructor. Verify that the event class has `const` constructor (should work since it uses `required this.action` with no non-const fields).

**Step: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat(task-ui): add counter-offer button for taker and response card for poster"
```

---

## Task 9: Handle New Action Messages in UI

**Files:**
- Modify: `link2ur/lib/core/utils/error_localizer.dart` (or wherever `actionMessage` is handled in task_detail_view)

**Step 1: Find where `actionMessage` is displayed**

Search in `task_detail_view.dart` for `actionMessage` or `state.actionMessage`. Typically it shows a SnackBar. Find the listener/builder that handles it.

**Step 2: Add new action message cases**

In whichever method/listener handles action messages, add:

```dart
case 'counter_offer_submitted':
  // Show success snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.taskDetailCounterOfferSent)),
  );
  break;
case 'counter_offer_submit_failed':
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.localizeError(state.errorMessage ?? 'operation_failed')),
      backgroundColor: AppColors.error,
    ),
  );
  break;
case 'counter_offer_accepted':
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.taskDetailAcceptCounterOffer)),
  );
  break;
case 'counter_offer_rejected':
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.taskDetailRejectCounterOffer)),
  );
  break;
case 'counter_offer_respond_failed':
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.localizeError(state.errorMessage ?? 'operation_failed')),
      backgroundColor: AppColors.error,
    ),
  );
  break;
```

**Step: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat(task-ui): handle counter-offer action message display"
```

---

## Final Verification

**Step 1: Analyze Flutter code**
```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze
```
Expected: No new errors or warnings.

**Step 2: Run Flutter tests**
```bash
flutter test
```
Expected: All passing.

**Step 3: Manual test checklist**
- [ ] Poster creates designated task (pending_acceptance)
- [ ] Taker opens task detail → sees [拒绝] [议价] [接受] buttons
- [ ] Taker taps 议价 → dialog opens → enters price → submits
- [ ] Task refreshes → taker sees "反报价已发送，等待对方回应"
- [ ] Poster gets notification → taps → opens task detail → sees counter-offer card
- [ ] Poster taps "同意报价" → task transitions to in_progress
- [ ] OR: Poster taps "拒绝" → task stays pending_acceptance → taker gets notified → taker can retry
- [ ] Poster creates task, sends negotiate offer → taker has 24h to respond (not 5 min)
