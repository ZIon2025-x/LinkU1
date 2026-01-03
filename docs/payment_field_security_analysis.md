# 支付字段安全性分析

## 敏感字段

以下字段涉及支付安全，不应被用户或管理员直接修改：

1. **`is_paid`** - 任务是否已支付（只能通过 webhook 更新）
2. **`escrow_amount`** - 托管金额（只能通过 webhook 或系统逻辑更新）
3. **`payment_intent_id`** - Stripe Payment Intent ID（只能通过 webhook 更新）
4. **`is_confirmed`** - 任务是否已确认完成（只能通过系统逻辑更新）
5. **`paid_to_user_id`** - 已支付给的用户ID（只能通过转账逻辑更新）

## 当前安全状况

### ✅ 已保护的地方

1. **AdminTaskUpdate Schema**
   - 不包含 `is_paid`、`escrow_amount` 等敏感字段
   - 位置：`backend/app/schemas.py` 第 681-692 行

2. **TaskUpdate Schema（用户更新）**
   - 只包含 `reward` 字段
   - 位置：`backend/app/schemas.py` 第 533-535 行

3. **Webhook 处理**
   - `is_paid` 和 `escrow_amount` 只能通过 webhook 更新
   - 位置：`backend/app/routers.py` 第 3056-3270 行

### ⚠️ 潜在风险

1. **`update_task_by_admin` 函数**
   - 使用 `setattr(task, field, value)` 动态设置字段
   - 如果传入的字典包含敏感字段，可能会被设置
   - 位置：`backend/app/crud.py` 第 3334-3383 行

2. **直接数据库操作**
   - 如果有直接 SQL 更新，可能绕过保护

## 建议的安全措施

### 1. 添加字段白名单保护

在 `update_task_by_admin` 函数中添加敏感字段黑名单：

```python
# 敏感字段黑名单（不允许通过 API 直接修改）
SENSITIVE_FIELDS = {
    'is_paid',
    'escrow_amount',
    'payment_intent_id',
    'is_confirmed',
    'paid_to_user_id',
    'taker_id',  # 任务接受人（只能通过申请批准流程设置）
    'agreed_reward',  # 最终成交价（只能通过议价流程设置）
}

def update_task_by_admin(db: Session, task_id: int, task_update: dict):
    """管理员更新任务信息"""
    # 过滤掉敏感字段
    filtered_update = {k: v for k, v in task_update.items() if k not in SENSITIVE_FIELDS}
    
    if filtered_update != task_update:
        logger.warning(f"尝试修改敏感字段，已过滤: {set(task_update.keys()) - set(filtered_update.keys())}")
    
    # 使用过滤后的更新数据
    # ...
```

### 2. 添加审计日志

所有对敏感字段的修改都应该记录审计日志：

```python
# 如果尝试修改敏感字段，记录审计日志
if any(field in task_update for field in SENSITIVE_FIELDS):
    crud.create_audit_log(
        db=db,
        action_type="attempted_sensitive_field_update",
        entity_type="task",
        entity_id=str(task_id),
        admin_id=current_user.id,
        old_value=None,
        new_value={k: v for k, v in task_update.items() if k in SENSITIVE_FIELDS},
        reason="尝试修改敏感支付字段（已被阻止）",
    )
```

### 3. 数据库约束

考虑在数据库层面添加约束或触发器，防止直接修改这些字段。

### 4. 只读字段标记

在模型中标记这些字段为只读，并在更新逻辑中检查。

## 当前修改这些字段的唯一合法途径

### `is_paid` 字段

1. **Webhook 处理** (`payment_intent.succeeded`)
   - 位置：`backend/app/routers.py` 第 3066 行
   - 条件：通过 Stripe webhook 验证

2. **支付失败处理** (`payment_intent.payment_failed`)
   - 位置：`backend/app/routers.py` 第 3362 行
   - 条件：通过 Stripe webhook 验证

3. **退款处理** (`charge.refunded`)
   - 位置：`backend/app/routers.py` 第 3418 行
   - 条件：通过 Stripe webhook 验证

4. **系统清理任务** (`revert_unpaid_application_approvals`)
   - 位置：`backend/app/crud.py` 第 2059、2096 行
   - 条件：支付超时（24小时）

### `escrow_amount` 字段

1. **Webhook 处理** (`payment_intent.succeeded`)
   - 位置：`backend/app/routers.py` 第 3084 行
   - 计算：`任务金额 - 平台服务费`

2. **转账完成** (`transfer.paid`)
   - 位置：`backend/app/routers.py` 第 3585 行
   - 设置为：`0.0`（转账后清空）

3. **任务完成确认**
   - 位置：`backend/app/routers.py` 第 3786 行
   - 设置为：`0.0`（转账后清空）

## 建议的改进

1. ✅ 在 `update_task_by_admin` 中添加敏感字段过滤
2. ✅ 添加审计日志记录所有敏感字段修改尝试
3. ✅ 在文档中明确说明这些字段的修改规则
4. ⚠️ 考虑添加数据库触发器或约束（可选）

