# 基于 Webhook 的支付审计和安全机制

## 概述

本文档描述了基于 Stripe Webhook 的支付和转账审计机制，确保所有操作都通过 webhook 确认并记录，防止重复支付和重复转账。

## 核心原则

1. **严格遵守 Webhook**：所有支付和转账操作都以 webhook 事件为准
2. **完整审计记录**：所有操作都记录到 `PaymentHistory` 和 `PaymentTransfer` 表
3. **防重复机制**：使用 `WebhookEvent` 表实现 idempotency，防止重复处理
4. **状态管理**：转账创建后状态为 `pending`，等待 webhook 确认后才更新为 `succeeded`

## 数据库表结构

### 1. WebhookEvent 表

用于记录所有 webhook 事件，实现 idempotency 检查：

```sql
CREATE TABLE webhook_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(255) NOT NULL UNIQUE,  -- Stripe 事件 ID（唯一索引防止重复处理）
    event_type VARCHAR(100) NOT NULL,
    livemode BOOLEAN DEFAULT FALSE,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP WITH TIME ZONE NULL,
    processing_error TEXT NULL,
    event_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. PaymentHistory 表

记录所有支付操作（成功和失败）：

- `status`: `pending`, `succeeded`, `failed`, `canceled`
- `extra_metadata`: 包含 webhook 事件ID、批准时间等审计信息

### 3. PaymentTransfer 表

记录所有转账操作（成功和失败）：

- `status`: `pending`, `succeeded`, `failed`, `retrying`
- `transfer_id`: Stripe Transfer ID
- `metadata`: 包含转账相关信息

## 支付流程

### 1. 支付成功流程

1. **创建 PaymentIntent**：在 `accept_application` 中创建
2. **用户支付**：前端完成支付
3. **Webhook 确认**：收到 `payment_intent.succeeded` 事件
4. **Idempotency 检查**：检查 `WebhookEvent` 表，防止重复处理
5. **更新状态**：
   - 更新任务 `is_paid = 1`
   - 更新申请状态为 `approved`
   - 创建/更新 `PaymentHistory` 记录
   - 标记 webhook 事件为已处理

### 2. 支付失败流程

1. **Webhook 确认**：收到 `payment_intent.payment_failed` 事件
2. **记录失败**：
   - 创建/更新 `PaymentHistory` 记录，状态为 `failed`
   - 记录失败原因到 `extra_metadata`
3. **恢复状态**：
   - 撤销申请批准
   - 恢复任务状态

## 转账流程

### 1. 转账创建

在 `confirm_task_completion` 中：

1. **创建转账记录**：状态为 `pending`
2. **创建 Stripe Transfer**：调用 `stripe.Transfer.create()`
3. **更新转账记录**：
   - 保存 `transfer_id`
   - 状态保持为 `pending`（**不立即设为 succeeded**）
   - 等待 webhook 确认

### 2. 转账成功确认

1. **Webhook 确认**：收到 `transfer.paid` 事件
2. **Idempotency 检查**：检查转账记录状态，防止重复处理
3. **更新状态**：
   - 更新 `PaymentTransfer` 状态为 `succeeded`
   - 更新任务 `is_confirmed = 1`
   - 清空 `escrow_amount`

### 3. 转账失败处理

1. **Webhook 确认**：收到 `transfer.failed` 事件
2. **记录失败**：
   - 更新 `PaymentTransfer` 状态为 `failed`
   - 记录失败原因
3. **重试机制**：定时任务会重试失败的转账

## Idempotency 机制

### Webhook 事件 Idempotency

每个 webhook 事件处理前：

1. 检查 `WebhookEvent` 表中是否存在该 `event_id`
2. 如果存在且已处理，直接返回，跳过处理
3. 如果存在但未处理，重新处理（可能是之前处理失败）
4. 如果不存在，创建新记录并处理

### 支付 Idempotency

- 检查任务 `is_paid` 状态
- 检查 `PaymentHistory` 中是否已有成功记录
- 防止重复支付

### 转账 Idempotency

- 检查 `PaymentTransfer` 状态
- 如果已为 `succeeded`，跳过处理
- 防止重复转账

## Webhook 事件处理

### 主账户 Webhook 事件

**端点**: `/api/stripe/webhook`

**处理的事件**：

1. **`payment_intent.succeeded`**
   - 更新任务支付状态
   - 批准申请（如果 `pending_approval = true`）
   - 创建/更新 `PaymentHistory` 记录

2. **`payment_intent.payment_failed`**
   - 记录支付失败到 `PaymentHistory`
   - 撤销申请批准
   - 恢复任务状态

3. **`transfer.paid`**
   - 更新 `PaymentTransfer` 状态为 `succeeded`
   - 更新任务 `is_confirmed = 1`
   - 清空 `escrow_amount`

4. **`transfer.failed`**
   - 更新 `PaymentTransfer` 状态为 `failed`
   - 记录失败原因

## 审计信息

### PaymentHistory 审计字段

```json
{
  "application_id": "40",
  "taker_id": "14786828",
  "taker_name": "接受人姓名",
  "pending_approval": "true",
  "approved_via_webhook": true,
  "webhook_event_id": "evt_xxx",
  "approved_at": "2026-01-03T15:53:35Z",
  "failure_reason": "card_declined",  // 如果失败
  "failed_via_webhook": true,  // 如果失败
  "failed_at": "2026-01-03T15:53:35Z"  // 如果失败
}
```

### PaymentTransfer 审计字段

- `transfer_id`: Stripe Transfer ID
- `status`: 转账状态
- `retry_count`: 重试次数
- `last_error`: 最后一次错误信息
- `succeeded_at`: 成功时间
- `metadata`: 额外元数据

## 安全措施

1. **Webhook 签名验证**：所有 webhook 请求都验证 Stripe 签名
2. **Idempotency 检查**：防止重复处理同一个事件
3. **状态检查**：防止重复支付和重复转账
4. **完整审计**：所有操作都有完整记录

## 故障排查

### 支付成功但状态未更新

1. 检查 `WebhookEvent` 表，查看事件是否已处理
2. 检查 `PaymentHistory` 表，查看支付记录
3. 检查 webhook 日志，查看是否有错误
4. 在 Stripe Dashboard 中手动重放 webhook 事件

### 转账成功但状态未更新

1. 检查 `PaymentTransfer` 表，查看转账记录状态
2. 检查是否收到 `transfer.paid` webhook 事件
3. 检查 `WebhookEvent` 表，查看事件是否已处理
4. 在 Stripe Dashboard 中手动重放 webhook 事件

## 相关文件

- `backend/app/models.py`：模型定义
- `backend/app/routers.py`：Webhook 处理逻辑
- `backend/app/payment_transfer_service.py`：转账服务
- `backend/migrations/041_add_payment_transfer_table.sql`：转账表迁移
- `backend/migrations/042_add_webhook_events_table.sql`：Webhook 事件表迁移

