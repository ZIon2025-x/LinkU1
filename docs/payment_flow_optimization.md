# 支付流程优化方案

## 概述

本文档描述了支付流程的优化方案，包括容错机制、定时任务重试和审计信息增强。

## 优化内容

### 1. 转账容错和重试机制

#### 1.1 PaymentTransfer 模型

新增 `payment_transfers` 表，用于记录所有转账操作：

- **状态管理**：`pending`（待处理）、`succeeded`（成功）、`failed`（失败）、`retrying`（重试中）
- **重试机制**：支持指数退避重试，最多重试 6 次
- **审计信息**：记录转账时间、错误信息、重试次数等

#### 1.2 重试策略

采用指数退避策略，重试间隔如下：

1. 1 分钟后重试
2. 5 分钟后重试
3. 15 分钟后重试
4. 1 小时后重试
5. 4 小时后重试
6. 24 小时后重试（最后一次）

#### 1.3 容错处理

- **实时转账失败**：如果实时转账失败，系统会创建转账记录，由定时任务自动重试
- **账户未设置**：如果任务接受人尚未设置 Stripe Connect 账户，系统会创建转账记录，等待账户设置完成后由定时任务处理
- **网络错误**：临时网络错误会自动重试，不会导致转账丢失

### 2. 定时任务处理

#### 2.1 定时任务配置

在 `celery_app.py` 中配置了定时任务：

```python
'process-pending-payment-transfers': {
    'task': 'app.celery_tasks.process_pending_payment_transfers_task',
    'schedule': 300.0,  # 每5分钟执行一次
}
```

#### 2.2 任务处理逻辑

定时任务会处理以下情况：

1. **状态为 `pending` 的记录**：首次尝试转账
2. **状态为 `retrying` 且到了重试时间的记录**：重试失败的转账

每次执行最多处理 100 条记录，避免一次性处理过多数据。

### 3. 支付审计信息增强

#### 3.1 PaymentHistory 增强

在 `payment_history` 表中增强了 `extra_metadata` 字段，记录以下信息：

- `application_id`：关联的申请ID
- `taker_id`：任务接受人ID
- `taker_name`：任务接受人姓名
- `pending_approval`：是否为待确认的批准支付
- `approved_via_webhook`：是否通过 webhook 批准
- `webhook_event_id`：Stripe webhook 事件ID
- `approved_at`：批准时间

#### 3.2 PaymentTransfer 审计信息

`payment_transfers` 表记录完整的转账审计信息：

- `transfer_id`：Stripe Transfer ID
- `amount`：转账金额
- `status`：转账状态
- `retry_count`：重试次数
- `last_error`：最后一次错误信息
- `next_retry_at`：下次重试时间
- `succeeded_at`：成功时间
- `metadata`：额外元数据（JSON格式）

### 4. 流程优化

#### 4.1 任务完成确认流程

当任务完成确认时：

1. **创建转账记录**：无论转账是否成功，都会创建转账记录用于审计
2. **尝试实时转账**：如果任务接受人已设置 Stripe Connect 账户，立即尝试转账
3. **失败处理**：如果实时转账失败，转账记录状态设为 `retrying`，等待定时任务重试

#### 4.2 Webhook 处理流程

在 Stripe webhook 处理中：

1. **增强支付历史记录**：记录完整的支付审计信息
2. **关联申请信息**：将支付与申请关联，便于追溯
3. **记录 webhook 事件**：保存 webhook 事件ID，便于问题排查

## 数据库迁移

运行以下迁移文件创建新表：

```bash
psql -d your_database -f backend/migrations/041_add_payment_transfer_table.sql
```

## 使用示例

### 创建转账记录

```python
from app.payment_transfer_service import create_transfer_record
from decimal import Decimal

transfer_record = create_transfer_record(
    db,
    task_id=128,
    taker_id="14786828",
    poster_id="27167013",
    amount=Decimal("0.90"),
    currency="GBP",
    metadata={
        "task_title": "任务标题",
        "transfer_source": "confirm_completion"
    }
)
```

### 执行转账

```python
from app.payment_transfer_service import execute_transfer

success, transfer_id, error_msg = execute_transfer(
    db,
    transfer_record,
    taker_stripe_account_id="acct_1SkrgKGEYyVzN5DC"
)
```

### 处理待处理的转账（定时任务）

```python
from app.payment_transfer_service import process_pending_transfers

stats = process_pending_transfers(db)
# stats = {
#     "processed": 10,
#     "succeeded": 8,
#     "failed": 1,
#     "retrying": 1,
#     "skipped": 0
# }
```

## 监控和告警

### 关键指标

1. **待处理转账数量**：监控 `status IN ('pending', 'retrying')` 的记录数量
2. **失败转账数量**：监控 `status = 'failed'` 的记录数量
3. **重试次数**：监控 `retry_count` 较高的记录
4. **转账成功率**：计算 `succeeded / (succeeded + failed)` 的比例

### 告警建议

- 如果待处理转账数量超过 100，发送告警
- 如果失败转账数量超过 10，发送告警
- 如果转账成功率低于 95%，发送告警

## 故障排查

### 转账失败常见原因

1. **Stripe Connect 账户未设置**：任务接受人尚未完成 Stripe Connect 账户设置
2. **账户未启用收款**：账户已创建但未启用收款功能
3. **网络错误**：临时网络问题，会自动重试
4. **金额错误**：转账金额为 0 或负数

### 排查步骤

1. 查看 `payment_transfers` 表中的 `last_error` 字段
2. 检查 `retry_count` 和 `next_retry_at` 字段
3. 查看 Stripe Dashboard 中的 Transfer 记录
4. 检查任务接受人的 Stripe Connect 账户状态

## 最佳实践

1. **定期检查**：定期检查待处理和失败的转账记录
2. **及时处理**：对于长期失败的转账，需要人工介入处理
3. **审计日志**：保留完整的审计日志，便于问题追溯
4. **监控告警**：设置合理的监控告警，及时发现问题

## 相关文件

- `backend/app/models.py`：PaymentTransfer 模型定义
- `backend/app/payment_transfer_service.py`：转账服务实现
- `backend/app/celery_tasks.py`：定时任务定义
- `backend/app/celery_app.py`：定时任务配置
- `backend/app/routers.py`：任务完成确认和 webhook 处理
- `backend/migrations/041_add_payment_transfer_table.sql`：数据库迁移文件

