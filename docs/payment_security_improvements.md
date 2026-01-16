# 支付安全改进：防重复支付和订单信息增强

## 改进内容

### 1. 防重复支付机制 ✅

#### 1.1 接受申请时检查

在 `accept_application` 函数中添加了任务已支付检查：

```python
# 检查任务是否已支付（防止重复支付）
if locked_task.is_paid == 1:
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="任务已支付，无法重复支付。如果支付未完成，请联系客服。"
    )
```

**位置**: `backend/app/task_chat_routes.py` 第 1336-1341 行

#### 1.2 幂等性检查增强

在幂等性检查中也添加了已支付检查：

```python
# 如果任务已支付，直接返回已接受的消息
if locked_task.is_paid == 1:
    logger.info(f"✅ 申请 {application_id} 已批准，任务已支付")
    return {
        "message": "申请已被接受，任务已支付",
        "application_id": application_id,
        "task_id": task_id,
        "is_paid": True
    }
```

**位置**: `backend/app/task_chat_routes.py` 第 1308-1316 行

#### 1.3 Webhook 幂等性检查

Webhook 处理中已有幂等性检查：

```python
if task and not task.is_paid:  # 幂等性检查
    task.is_paid = 1
    # ... 处理支付逻辑
```

**位置**: `backend/app/routers.py` 第 2943 行

**说明**: 即使 webhook 重复触发，也不会重复处理已支付的订单。

### 2. 支付订单信息增强 ✅

#### 2.1 PaymentIntent Description

添加了支付描述，方便在 Stripe Dashboard 中查看：

```python
task_title_short = locked_task.title[:50] if locked_task.title else f"Task #{task_id}"
payment_description = f"任务 #{task_id}: {task_title_short} - 批准申请 #{application_id}"

payment_intent = stripe.PaymentIntent.create(
    description=payment_description,  # 支付描述
    # ...
)
```

**位置**: `backend/app/task_chat_routes.py` 第 1421-1422 行

#### 2.2 增强的 Metadata

PaymentIntent 的 metadata 现在包含完整信息：

```python
metadata={
    # 基础信息
    "task_id": str(task_id),
    "task_title": locked_task.title[:200],  # 任务标题
    "application_id": str(application_id),
    
    # 用户信息
    "poster_id": str(current_user.id),
    "poster_name": current_user.name or f"User {current_user.id}",  # 发布者名称
    "taker_id": str(application.applicant_id),
    "taker_name": applicant.name or f"User {application.applicant_id}",  # 接受者名称
    
    # 支付信息
    "taker_stripe_account_id": taker_stripe_account_id,  # 接受人的 Stripe 账户ID
    "application_fee": str(application_fee_pence),  # 平台服务费
    "task_amount": str(task_amount_pence),  # 任务金额（便士）
    "task_amount_display": f"{task_amount:.2f}",  # 任务金额（显示格式）
    "negotiated_price": str(application.negotiated_price) if application.negotiated_price else "",  # 议价金额
    
    # 业务标识
    "pending_approval": "true",  # 标记这是待确认的批准
    "platform": "Link²Ur",  # 平台标识
    "payment_type": "application_approval"  # 支付类型：申请批准
}
```

**位置**: `backend/app/task_chat_routes.py` 第 1436-1457 行

### 3. 支付状态检查增强 ✅

在幂等性检查中，增加了 PaymentIntent 状态检查：

```python
# 检查 PaymentIntent 状态
if payment_intent.status == "succeeded":
    logger.info(f"✅ PaymentIntent 已成功，但任务状态未更新，可能是 webhook 延迟")
    # 返回已支付信息
    return {
        "message": "申请已被接受，支付已完成",
        "application_id": application_id,
        "task_id": task_id,
        "payment_intent_id": payment_intent.id,
        "payment_status": "succeeded",
        "is_paid": True
    }
```

**位置**: `backend/app/task_chat_routes.py` 第 1320-1331 行

## 安全特性

### 1. 多层防护

- ✅ **接受申请时检查**: 防止在创建 PaymentIntent 前重复支付
- ✅ **幂等性检查**: 防止重复调用 accept_application API
- ✅ **Webhook 幂等性**: 防止 webhook 重复处理
- ✅ **PaymentIntent 状态检查**: 检查 Stripe 端的支付状态

### 2. 数据完整性

- ✅ **完整的 Metadata**: 包含所有必要信息，方便核对和调试
- ✅ **支付描述**: 在 Stripe Dashboard 中清晰显示
- ✅ **用户信息**: 包含发布者和接受者的 ID 和名称

### 3. 错误处理

- ✅ **明确的错误消息**: 告诉用户为什么不能重复支付
- ✅ **状态检查**: 检查 PaymentIntent 状态，处理 webhook 延迟情况
- ✅ **日志记录**: 详细记录所有检查和操作

## 使用场景

### 场景 1: 正常支付流程

1. 发布者接受申请 → 创建 PaymentIntent
2. 用户完成支付 → Webhook 处理
3. 任务状态更新为 `in_progress`

### 场景 2: 防止重复支付

1. 发布者尝试再次接受申请
2. 系统检查 `is_paid == 1`
3. 返回错误："任务已支付，无法重复支付"

### 场景 3: Webhook 延迟

1. 支付成功，但 webhook 延迟
2. 用户刷新页面，再次调用 accept_application
3. 系统检查 PaymentIntent 状态
4. 返回已支付信息，不创建新的 PaymentIntent

### 场景 4: 订单核对

在 Stripe Dashboard 中查看 PaymentIntent：
- **Description**: "任务 #128: 任务标题 - 批准申请 #40"
- **Metadata**: 包含所有相关信息
  - task_id, application_id
  - poster_id, poster_name
  - taker_id, taker_name
  - task_amount, application_fee
  - 等等

## 测试建议

### 1. 测试防重复支付

```bash
# 1. 接受申请并完成支付
POST /api/tasks/{task_id}/applications/{application_id}/accept
# 完成支付

# 2. 再次尝试接受申请（应该失败）
POST /api/tasks/{task_id}/applications/{application_id}/accept
# 预期: 400 错误 "任务已支付，无法重复支付"
```

### 2. 测试 Metadata

```bash
# 1. 接受申请
POST /api/tasks/{task_id}/applications/{application_id}/accept

# 2. 在 Stripe Dashboard 中查看 PaymentIntent
# 检查 metadata 是否包含所有字段
```

### 3. 测试幂等性

```bash
# 1. 接受申请（第一次）
POST /api/tasks/{task_id}/applications/{application_id}/accept
# 返回: payment_intent_id, client_secret

# 2. 立即再次调用（幂等性）
POST /api/tasks/{task_id}/applications/{application_id}/accept
# 预期: 返回相同的 payment_intent_id 和 client_secret
```

## 相关文件

- `backend/app/task_chat_routes.py` - 接受申请和创建 PaymentIntent
- `backend/app/routers.py` - Webhook 处理
- `docs/payment_security_improvements.md` - 本文档

## 总结

✅ **防重复支付**: 多层检查，确保已支付的任务不能重复支付  
✅ **订单信息完整**: Metadata 包含所有必要信息，方便核对和调试  
✅ **支付描述清晰**: 在 Stripe Dashboard 中一目了然  
✅ **错误处理完善**: 明确的错误消息和状态检查

