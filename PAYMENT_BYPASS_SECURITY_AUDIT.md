# 支付绕过安全审计报告

## 🔴 严重漏洞

### 1. `/tasks/{task_id}/approve` 端点缺少支付验证

**位置**: `backend/app/routers.py:1574-1615`

**问题描述**:
```python
@router.post("/tasks/{task_id}/approve")
def approve_task_taker(...):
    # 检查权限：只有任务发布者可以同意
    if db_task.poster_id != current_user.id:
        raise HTTPException(...)
    
    # 检查任务状态：必须是taken状态
    if db_task.status != "taken":
        raise HTTPException(...)
    
    # ⚠️ 漏洞：直接更新状态为 in_progress，没有检查支付！
    db_task.status = "in_progress"
    db.commit()
```

**风险等级**: 🔴 **严重**

**攻击场景**:
1. 发布者批准申请后，系统创建 PaymentIntent，任务状态变为 `pending_payment`
2. 攻击者可以通过调用 `/tasks/{task_id}/approve` 端点，直接将任务状态改为 `in_progress`
3. 绕过支付验证，任务可以继续进行而无需支付

**修复建议**:
```python
@router.post("/tasks/{task_id}/approve")
def approve_task_taker(...):
    # ... 现有检查 ...
    
    # ✅ 添加支付验证
    if not db_task.is_paid:
        raise HTTPException(
            status_code=400, 
            detail="任务尚未支付，无法批准。请先完成支付。"
        )
    
    # ✅ 检查任务状态：必须是 pending_payment 或已支付状态
    if db_task.status not in ["pending_payment", "in_progress"]:
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法批准。当前状态: {db_task.status}"
        )
    
    # 更新任务状态为进行中
    if db_task.status == "pending_payment":
        db_task.status = "in_progress"
        db.commit()
```

**或者**: 考虑废弃此端点，因为新的流程使用 `accept_application`，已经包含了支付验证。

---

## 🟡 中等风险

### 2. `confirm_task_completion` 端点状态检查过于宽松

**位置**: `backend/app/routers.py:2219-2240`

**问题描述**:
```python
@router.post("/tasks/{task_id}/confirm_completion")
def confirm_task_completion(...):
    # 检查任务状态：允许 pending_confirmation 状态，也允许已支付但状态异常的情况
    if task.status != "pending_confirmation":
        # ⚠️ 如果任务已支付且有接受者，但状态不是 pending_confirmation，记录日志并允许确认
        if task.is_paid == 1 and task.taker_id and task.status in ["in_progress", "pending_payment"]:
            logger.warning(f"任务 {task_id} 状态为 {task.status}，但已支付且有接受者，允许确认完成")
            # 将状态更新为 pending_confirmation 以便后续处理
            task.status = "pending_confirmation"
            db.commit()
```

**风险等级**: 🟡 **中等**

**问题**:
- 允许 `pending_payment` 状态的任务确认完成，虽然检查了 `is_paid == 1`，但这可能允许某些边缘情况绕过正常流程
- 如果 `is_paid` 被错误设置（例如通过数据库直接修改），可以绕过支付

**修复建议**:
```python
# ✅ 更严格的状态检查
if task.status != "pending_confirmation":
    # 只允许 in_progress 状态的任务（已支付且正常进行中）
    if task.is_paid == 1 and task.taker_id and task.status == "in_progress":
        logger.warning(f"任务 {task_id} 状态为 {task.status}，但已支付且有接受者，允许确认完成")
        task.status = "pending_confirmation"
        db.commit()
    else:
        raise HTTPException(
            status_code=400, 
            detail=f"任务状态不正确，无法确认完成。当前状态: {task.status}, is_paid: {task.is_paid}"
        )
```

**或者**: 添加额外的支付验证，检查 `payment_intent_id` 和 Stripe 支付状态。

---

## 🟢 低风险（已保护）

### 3. `confirm_task_complete` 端点有支付验证 ✅

**位置**: `backend/app/routers.py:4594-4600`

**状态**: ✅ **已保护**

```python
if not task.is_paid or task.status != "completed" or task.is_confirmed:
    raise HTTPException(
        status_code=400, detail="Task not eligible for confirmation."
    )
```

这个端点正确检查了 `is_paid`，是安全的。

---

### 4. `accept_application` 端点有支付验证 ✅

**位置**: `backend/app/task_chat_routes.py:1258-1570`

**状态**: ✅ **已保护**

- 创建 PaymentIntent，不立即批准申请
- 申请状态保持为 `pending`，等待支付成功后才批准
- 不设置 `taker_id`，等待支付成功后再设置（由 webhook 处理）

这个流程是安全的。

---

### 5. 管理员 API 有敏感字段保护 ✅

**位置**: `backend/app/routers.py:4808-4846`

**状态**: ✅ **已保护**

```python
SENSITIVE_FIELDS = {
    'is_paid', 'escrow_amount', 'payment_intent_id', 
    'is_confirmed', 'paid_to_user_id', 'taker_id', 'agreed_reward'
}
```

管理员无法直接修改支付相关字段，有审计日志记录。

---

## 📋 修复状态

### ✅ 已修复（P0）
1. ✅ **修复 `/tasks/{task_id}/approve` 端点** - 已添加支付验证
2. ✅ **加强 `confirm_task_completion` 状态检查** - 已移除对 `pending_payment` 状态的支持
3. ✅ **修复 `/tasks/{task_id}/complete` 端点** - 已添加支付验证

### 长期优化（P2）
3. ⚠️ **添加支付状态双重验证** - 不仅检查 `is_paid`，还验证 Stripe PaymentIntent 状态
4. ⚠️ **添加支付审计日志** - 记录所有支付状态变更，便于追踪

---

## 🔍 其他检查项

### 已检查的端点
- ✅ `/tasks/{task_id}/confirm_complete` - 有支付验证
- ✅ `/tasks/{task_id}/applications/{application_id}/accept` - 有支付验证
- ✅ `/admin/tasks/{task_id}` - 有敏感字段保护
- ✅ `/tasks/{task_id}/payment` - 创建支付，安全
- ⚠️ `/tasks/{task_id}/approve` - **缺少支付验证**
- ⚠️ `/tasks/{task_id}/confirm_completion` - **状态检查过于宽松**

### 建议的额外检查
1. 检查是否有其他直接修改任务状态的端点
2. 检查数据库迁移脚本是否可能修改支付状态
3. 检查定时任务是否可能绕过支付验证
4. 检查是否有批量操作可能绕过支付

---

## 🛡️ 防御建议

### 1. 添加支付状态验证中间件
```python
def verify_task_payment(task: models.Task, required_status: str = "in_progress"):
    """验证任务支付状态"""
    if required_status == "in_progress" and task.status == "in_progress":
        if not task.is_paid:
            raise HTTPException(
                status_code=400,
                detail="任务尚未支付，无法进行此操作"
            )
        # 可选：验证 Stripe PaymentIntent 状态
        if task.payment_intent_id:
            import stripe
            stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
            try:
                pi = stripe.PaymentIntent.retrieve(task.payment_intent_id)
                if pi.status != "succeeded":
                    raise HTTPException(
                        status_code=400,
                        detail=f"支付未完成，当前状态: {pi.status}"
                    )
            except Exception as e:
                logger.error(f"验证支付状态失败: {e}")
```

### 2. 添加状态转换验证
```python
ALLOWED_STATUS_TRANSITIONS = {
    "open": ["pending_payment", "cancelled"],
    "pending_payment": ["in_progress", "cancelled"],
    "in_progress": ["pending_confirmation", "cancelled"],
    "pending_confirmation": ["completed"],
    "completed": [],  # 最终状态
    "cancelled": [],  # 最终状态
}

def validate_status_transition(current_status: str, new_status: str):
    """验证状态转换是否合法"""
    allowed = ALLOWED_STATUS_TRANSITIONS.get(current_status, [])
    if new_status not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"不允许从 {current_status} 转换到 {new_status}"
        )
```

### 3. 添加数据库约束
```sql
-- 确保 in_progress 状态的任务必须已支付
ALTER TABLE tasks ADD CONSTRAINT check_in_progress_paid 
CHECK (
    (status = 'in_progress' AND is_paid = 1) OR 
    (status != 'in_progress')
);
```

---

## 📝 总结

**发现的安全问题**:
1. 🔴 **严重**: `/tasks/{task_id}/approve` 端点缺少支付验证
2. 🟡 **中等**: `confirm_task_completion` 状态检查过于宽松

**建议**:
1. 立即修复 `/tasks/{task_id}/approve` 端点
2. 加强状态转换验证
3. 考虑废弃旧的 `approve` 端点，统一使用新的 `accept_application` 流程

**总体评估**: 大部分支付流程是安全的，已修复所有发现的安全漏洞。

## ✅ 修复完成

所有发现的安全漏洞已修复：
1. ✅ `/tasks/{task_id}/approve` - 已添加支付验证
2. ✅ `/tasks/{task_id}/confirm_completion` - 已加强状态检查
3. ✅ `/tasks/{task_id}/complete` - 已添加支付验证
4. ✅ `async_crud.approve_application` - 已添加支付验证（可能已废弃，但为安全起见仍修复）
5. ✅ `scheduled_tasks.auto_complete_expired_time_slot_tasks` - 已添加支付验证
6. ✅ `flea_market_routes.direct_purchase_item` - 已修复，创建任务时设置为 `pending_payment` 而不是 `in_progress`
7. ✅ `flea_market_routes.accept_purchase_request` - 已修复，创建任务时设置为 `pending_payment` 并创建 PaymentIntent
8. ✅ `task_chat_routes.respond_negotiation` - 已修复，接受议价时设置为 `pending_payment` 并创建 PaymentIntent
9. ✅ `task_expert_routes.approve_service_application` - 已修复，创建任务时设置为 `pending_payment` 并创建 PaymentIntent

**修复日期**: 2024年

---

## 🔴 第三轮检查发现的问题

### 7. `accept_purchase_request` 端点缺少支付验证 ⚠️

**位置**: `backend/app/flea_market_routes.py:1553-1637`

**问题描述**:
```python
@flea_market_router.post("/items/{item_id}/accept-purchase")
async def accept_purchase_request(...):
    # 创建任务时直接设置为 in_progress，没有支付验证！
    new_task = models.Task(
        ...
        status="in_progress",  # ⚠️ 严重漏洞：直接进入进行中状态，绕过支付
        ...
    )
```

**风险等级**: 🔴 **严重**

**攻击场景**:
1. 买家提交购买申请（议价）
2. 卖家议价
3. 买家接受议价，调用 `/items/{item_id}/accept-purchase`
4. 任务直接进入 `in_progress` 状态，完全绕过支付

**修复状态**: ✅ **已修复**
- 创建任务时设置为 `pending_payment` 状态
- 创建 PaymentIntent
- 返回支付信息（包含 `client_secret`、`payment_intent_id` 等）
- 检查卖家是否有 Stripe Connect 账户
- 在事务提交前创建 PaymentIntent，失败时回滚

**前端处理**：
- ✅ **已修复**：在 `FleaMarketItemDetailModal.tsx` 中添加了接受购买申请的按钮
- ✅ **已修复**：检测返回的 `task_status === 'pending_payment'` 并跳转到支付页面
- 买家可以在购买申请列表中看到卖家议价，并点击"接受购买申请"按钮

---

### 8. `respond_negotiation` 端点缺少支付验证 ⚠️

**位置**: `backend/app/task_chat_routes.py:2129-2511`

**问题描述**:
```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/respond-negotiation")
async def respond_negotiation(...):
    if request.action == "accept":
        # 接受议价：直接设置为 in_progress，没有支付验证！
        locked_task.status = "in_progress"  # ⚠️ 严重漏洞：绕过支付
```

**风险等级**: 🔴 **严重**

**攻击场景**:
1. 任务发布者对申请者进行议价
2. 申请者接受议价，调用 `/tasks/{task_id}/applications/{application_id}/respond-negotiation`
3. 任务直接进入 `in_progress` 状态，完全绕过支付

**修复状态**: ✅ **已修复**
- 接受议价时设置为 `pending_payment` 状态
- 创建 PaymentIntent
- 返回支付信息（包含 `client_secret`、`payment_intent_id` 等）
- 检查申请者是否有 Stripe Connect 账户
- 在事务提交前创建 PaymentIntent，失败时回滚

---

### 9. `approve_service_application` 端点缺少支付验证 ⚠️

**位置**: `backend/app/task_expert_routes.py:2578-2731`

**问题描述**:
```python
@task_expert_router.post("/applications/{application_id}/approve")
async def approve_service_application(...):
    # 创建任务时直接设置为 in_progress，没有支付验证！
    new_task = models.Task(
        ...
        status="in_progress",  # ⚠️ 严重漏洞：绕过支付
        ...
    )
```

**风险等级**: 🔴 **严重**

**攻击场景**:
1. 用户申请任务达人服务（可能包含议价）
2. 任务达人批准申请，调用 `/applications/{application_id}/approve`
3. 任务直接进入 `in_progress` 状态，完全绕过支付

**修复状态**: ✅ **已修复**
- 创建任务时设置为 `pending_payment` 状态
- 创建 PaymentIntent
- 返回支付信息（包含 `client_secret`、`payment_intent_id` 等）
- 检查任务达人是否有 Stripe Connect 账户
- 在事务提交前创建 PaymentIntent，失败时回滚

---

## 🔍 第二轮检查发现的问题

### 4. `async_crud.approve_application` 缺少支付验证 ⚠️

**位置**: `backend/app/async_crud.py:1380-1416`

**问题描述**:
```python
async def approve_application(...):
    # 直接更新任务状态为 in_progress，没有检查支付
    result = await db.execute(
        update(models.Task)
        .where(models.Task.id == task_id)
        .values(
            taker_id=applicant_id,
            status="in_progress",  # ⚠️ 没有检查支付
            ...
        )
    )
```

**风险等级**: 🔴 **严重**（虽然可能已废弃，但为安全起见仍需修复）

**修复状态**: ✅ **已修复** - 添加了支付验证

---

### 5. `auto_complete_expired_time_slot_tasks` 缺少支付验证 ⚠️

**位置**: `backend/app/scheduled_tasks.py:140-226`

**问题描述**:
```python
def auto_complete_expired_time_slot_tasks(db: Session):
    # 自动完成已过期时间段的任务
    if max_end_time and max_end_time < current_time:
        task.status = "completed"  # ⚠️ 没有检查支付
```

**风险等级**: 🟡 **中等**（定时任务，但应该检查支付）

**修复状态**: ✅ **已修复** - 添加了支付验证，只有已支付的任务才能自动完成

---

### 6. `direct_purchase_item` 创建任务时缺少支付验证 ⚠️

**位置**: `backend/app/flea_market_routes.py:1132-1250`

**问题描述**:
```python
new_task = models.Task(
    ...
    status="in_progress",  # ⚠️ 直接进入进行中状态，没有支付验证
    # 没有设置 is_paid
)
```

**风险等级**: 🔴 **严重**（跳蚤市场购买应该也需要支付）

**修复状态**: ✅ **已修复** - 创建任务时设置为 `pending_payment` 状态，等待支付完成

**注意**: 跳蚤市场直接购买功能已完整实现支付流程：
- ✅ 后端创建任务时设置为 `pending_payment` 状态
- ✅ 后端创建 PaymentIntent 并返回支付信息
- ✅ 前端检测到 `pending_payment` 状态时自动跳转到支付页面
- ✅ 支付完成后通过 Webhook 更新任务状态为 `in_progress`
