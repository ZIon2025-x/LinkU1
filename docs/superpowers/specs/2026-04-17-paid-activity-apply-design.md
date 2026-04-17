# 付费活动报名支付设计方案

> Date: 2026-04-17

## 概述

为付费的 lottery/first_come 活动增加 Stripe 支付流程。用户报名时创建 PaymentIntent，支付成功后 webhook 自动完成报名，平台抽成后转账给达人。

## 收费模式

- **参与费模式**：报名即收费，无论中不中奖都不退款
- **平台抽���**：复用现有 `fee_calculator` 按 task_type 计算手续费
- **转账**：复用现有 `PaymentTransfer` + `payment_transfer_service.execute_transfer()`

## 支付流程

```
用户报名付费活动
  → POST /api/official-activities/{id}/apply
    → price > 0 → 创建 Stripe PaymentIntent
    → 返回 {requires_payment, client_secret, payment_intent_id, amount, ...}
      → Flutter 展示 Stripe Payment Sheet
        → 用户付款
          → Stripe Webhook payment_intent.succeeded
            → 创建 OfficialActivityApplication
            → ��建 PaymentHistory (status=succeeded)
            → 创建 PaymentTransfer (status=pending)
            → by_count 自动开奖检查
              → Celery 异步转账给达人（扣平台手续费）
```

免费活动流程不变（直接创建 application，无支付环节）。

## 后端变更

### 1. DB Migration — OfficialActivityApplication 表扩展

新增 2 列：

```sql
ALTER TABLE official_activity_applications
    ADD COLUMN IF NOT EXISTS payment_intent_id VARCHAR(255) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS amount_paid INTEGER DEFAULT NULL;
```

- `payment_intent_id`：Stripe PaymentIntent ID，用于防重复 + 关联查询
- `amount_paid`：实际支付金额（pence），记录用

同步更新 `models.py` 中 `OfficialActivityApplication` 模型。

### 2. 修改报名端点 `POST /api/official-activities/{id}/apply`

当 `original_price_per_participant > 0` 时：

1. 检查是否已报名（现有逻辑）
2. 检查是否已有未完��的 PaymentIntent（防重复创建）
   - 查 `OfficialActivityApplication` 表中是否有 `payment_intent_id` 不为空 + `status='payment_pending'` 的记录
   - 有 → 返回已有的 `client_secret`（幂等）
3. 计算费用：
   - `amount` = `original_price_per_participant`（已是 pence，DECIMAL → int）
   - `application_fee` = `fee_calculator.calculate_fee(amount, task_type=activity.task_type)`
4. 获取用户的 Stripe Customer + EphemeralKey（复用现有逻辑）
5. 创建 `stripe.PaymentIntent.create()`：
   ```python
   payment_intent = stripe.PaymentIntent.create(
       amount=amount,
       currency=(activity.currency or "GBP").lower(),
       payment_method_types=["card"],
       metadata={
           "activity_id": str(activity.id),
           "user_id": str(current_user.id),
           "activity_apply": "true",
           "application_fee": str(application_fee),
           "expert_id": str(activity.owner_id),  # expert team id
       },
   )
   ```
6. 创建 `OfficialActivityApplication`（status=`payment_pending`）记录 payment_intent_id
7. 返回：
   ```json
   {
     "success": true,
     "requires_payment": true,
     "client_secret": "pi_xxx_secret_xxx",
     "payment_intent_id": "pi_xxx",
     "amount": 1000,
     "currency": "GBP",
     "customer_id": "cus_xxx",
     "ephemeral_key_secret": "ek_xxx"
   }
   ```

`OfficialActivityApplication.status` 新增值 `payment_pending`（需更新 CHECK 约束）。

### 3. 扩展 Webhook handler

在 `routers.py` 的 `payment_intent.succeeded` 处理中，检查 `metadata.get('activity_apply') == 'true'`：

1. 根据 `activity_id` + `user_id` 查找 `payment_pending` 的 application
2. 如果 `activity_type == 'first_come'`：
   - 检查当前 `attending` 数量 < `prize_count`
   - 满了 → 立即退款 `stripe.Refund.create(payment_intent=pi_id)`，更新 application status=`refunded`
   - 未满 → status=`attending`
3. 如果 `activity_type == 'lottery'`：
   - status=`pending`（等待开奖）
4. 更新 `amount_paid`
5. 创建 `PaymentHistory` 记录
6. 创建 `PaymentTransfer` 记录（taker_id=活动创建者 user_id，taker_expert_id=owner_id）
7. 触发 by_count 自动开奖检查

### 4. first_come 满员退款

first_come 活动在 webhook 中发现名额已满时，自动退款：

```python
stripe.Refund.create(payment_intent=payment_intent_id)
```

更��� application status=`refunded`。这个竞态窗口很小（webhook 处理是串行的），但用 SELECT FOR UPDATE 锁 activity 行确保安全。

### 5. OfficialActivityApplication status 值

扩展后：`payment_pending` / `pending` / `won` / `lost` / `attending` / `refunded`

更新 CHECK 约束：
```sql
ALTER TABLE official_activity_applications
    DROP CONSTRAINT IF EXISTS ck_official_app_status;
ALTER TABLE official_activity_applications
    ADD CONSTRAINT ck_official_app_status
    CHECK (status IN ('payment_pending', 'pending', 'won', 'lost', 'attending', 'refunded'));
```

## Flutter 变更

### 1. 修改 `ActivityBloc` 的 `_onApplyOfficial` 处理

当 apply 返回 `requires_payment: true` + `client_secret` 时：

```dart
if (response['requires_payment'] == true) {
  final clientSecret = response['client_secret'] as String;
  final customerId = response['customer_id'] as String?;
  final ephemeralKey = response['ephemeral_key_secret'] as String?;

  // 展示 Stripe Payment Sheet
  final paid = await _paymentService.presentPaymentSheet(
    clientSecret: clientSecret,
    customerId: customerId,
    ephemeralKeySecret: ephemeralKey,
  );

  if (paid) {
    // 支付成功，webhook 已在后端完成报名
    // 重新加载活动详情
    emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applied));
    add(ActivityLoadDetail(event.activityId));
  } else {
    emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.idle));
  }
  return;
}
```

### 2. 注入 PaymentService 到 ActivityBloc

ActivityBloc 目前没有 `PaymentService`，需要在构造函数中新增。

### 3. 报名按钮 UI

无需改动 — 现有的 `_buildOfficialActionBar` 已展示报名按钮，BLoC 层处理支付逻辑对 UI 透明。

## 不改动的部分

- 免费活动报名流程完全不变
- 现有任务支付流程不变
- `fee_calculator.py` 不变
- `payment_transfer_service.py` 不变
- `PaymentService` (Flutter) 不变
- Stripe webhook 签名验证逻辑不变
