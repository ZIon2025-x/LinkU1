# 支付系统优化总结

## 优化内容

### 1. 完整的支付审计记录 ✅

**问题**：之前只有 `pending_approval` 的支付才记录到 `PaymentHistory`，其他支付没有记录。

**解决方案**：
- 所有支付操作（无论是否为 `pending_approval`）都记录到 `PaymentHistory`
- 记录完整的审计信息，包括 webhook 事件ID、处理时间等

**代码位置**：`backend/app/routers.py` 第 3226-3258 行

### 2. 转账超时检查机制 ✅

**问题**：如果转账长时间处于 `pending` 状态（例如 webhook 未收到），系统无法自动检测和处理。

**解决方案**：
- 添加 `check_transfer_timeout` 函数，检查长时间处于 `pending` 状态的转账
- 通过 Stripe API 查询 Transfer 实际状态
- 如果 Transfer 已被撤销或部分撤销，更新本地记录
- 如果 Transfer 状态正常但未收到 webhook，标记为需要重试

**代码位置**：
- `backend/app/payment_transfer_service.py` 第 30-120 行
- `backend/app/celery_tasks.py` 第 297-325 行
- `backend/app/celery_app.py` 第 78-81 行

**定时任务配置**：
- 每 1 小时执行一次转账超时检查
- 默认超时时间为 24 小时

### 3. 统一的错误处理 ✅

**问题**：Webhook 处理中的错误没有统一记录到 `WebhookEvent.processing_error`。

**解决方案**：
- 添加 `_handle_webhook_error` 函数，统一处理 webhook 错误
- 所有错误都记录到 `WebhookEvent.processing_error` 字段
- 便于后续排查和监控

**代码位置**：`backend/app/routers.py` 第 3620-3640 行

## 数据库表

### WebhookEvent 表

用于记录所有 webhook 事件，实现 idempotency 和错误追踪：

```sql
CREATE TABLE webhook_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(255) NOT NULL UNIQUE,
    event_type VARCHAR(100) NOT NULL,
    livemode BOOLEAN DEFAULT FALSE,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP WITH TIME ZONE NULL,
    processing_error TEXT NULL,  -- 处理错误信息
    event_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### PaymentHistory 表

记录所有支付操作（成功和失败）：

- `status`: `pending`, `succeeded`, `failed`, `canceled`
- `extra_metadata`: 包含完整的审计信息

### PaymentTransfer 表

记录所有转账操作（成功和失败）：

- `status`: `pending`, `succeeded`, `failed`, `retrying`
- `transfer_id`: Stripe Transfer ID
- `last_error`: 最后一次错误信息
- `retry_count`: 重试次数

## 定时任务

### 1. process_pending_payment_transfers_task

**频率**：每 5 分钟执行一次

**功能**：
- 处理状态为 `pending` 的转账（首次尝试）
- 重试状态为 `retrying` 且到了重试时间的转账

### 2. check_transfer_timeout_task

**频率**：每 1 小时执行一次

**功能**：
- 检查长时间处于 `pending` 状态的转账（超过 24 小时）
- 通过 Stripe API 查询 Transfer 实际状态
- 更新本地记录状态

## 安全机制

### 1. Idempotency 检查

- **Webhook 事件级别**：通过 `WebhookEvent` 表防止重复处理
- **支付级别**：检查任务 `is_paid` 状态
- **转账级别**：检查 `PaymentTransfer` 状态

### 2. 错误记录

- 所有处理错误都记录到 `WebhookEvent.processing_error`
- 便于后续排查和监控

### 3. 超时处理

- 自动检测长时间未收到 webhook 的转账
- 通过 Stripe API 验证实际状态
- 自动标记需要人工检查的记录

## 监控建议

### 关键指标

1. **待处理转账数量**：`status IN ('pending', 'retrying')`
2. **超时转账数量**：`status = 'pending' AND created_at < NOW() - INTERVAL '24 hours'`
3. **失败转账数量**：`status = 'failed'`
4. **Webhook 处理错误**：`processed = FALSE AND processing_error IS NOT NULL`

### 告警建议

- 如果待处理转账数量超过 100，发送告警
- 如果超时转账数量超过 10，发送告警
- 如果失败转账数量超过 10，发送告警
- 如果 webhook 处理错误数量超过 5，发送告警

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
4. 运行转账超时检查任务，验证 Stripe Transfer 实际状态
5. 在 Stripe Dashboard 中手动重放 webhook 事件

### 转账长时间处于 pending 状态

1. 运行转账超时检查任务
2. 检查 Stripe Dashboard 中的 Transfer 状态
3. 检查 webhook 配置是否正确
4. 如果 Transfer 状态正常但未收到 webhook，手动触发 webhook 或更新本地记录

## 相关文件

- `backend/app/models.py`：模型定义
- `backend/app/routers.py`：Webhook 处理逻辑
- `backend/app/payment_transfer_service.py`：转账服务
- `backend/app/celery_tasks.py`：定时任务定义
- `backend/app/celery_app.py`：定时任务配置
- `backend/migrations/041_add_payment_transfer_table.sql`：转账表迁移
- `backend/migrations/042_add_webhook_events_table.sql`：Webhook 事件表迁移

## 下一步

1. 运行数据库迁移
2. 重启 Celery Worker 和 Beat
3. 在 Stripe Dashboard 中订阅 Transfer 事件
4. 监控转账处理情况
5. 设置告警规则

