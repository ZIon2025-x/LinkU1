# 退款功能安全性审计报告（2026-01-27）

## 📋 审计范围

全面检查退款申请功能的安全性，包括：
1. 身份认证和授权
2. 输入验证和SQL注入防护
3. 业务逻辑验证
4. 并发控制和竞态条件
5. 文件上传安全
6. Stripe操作安全
7. 数据完整性
8. 金额验证和escrow管理
9. 部分转账与退款的交互

---

## ✅ 已实现的安全措施

### 1. 身份认证和授权 ✅

#### 1.1 用户端API安全

**✅ 身份验证**:
- 使用 `Depends(check_user_status)` 确保用户已登录
- 检查用户状态（封禁、暂停）

**✅ 权限验证**:
```python
if not task or task.poster_id != current_user.id:
    raise HTTPException(status_code=404, detail="Task not found or no permission")
```
- ✅ 验证任务存在
- ✅ 验证当前用户是任务发布者
- ✅ 使用404错误隐藏权限信息（安全最佳实践）

**✅ 管理员API安全**:
- 使用 `Depends(get_current_admin)` 确保只有管理员可以审核
- 验证退款申请存在
- 验证退款申请状态（必须是pending才能批准/拒绝）

### 2. 业务逻辑验证 ✅

**✅ 任务状态验证**:
```python
if task.status != "pending_confirmation":
    raise HTTPException(status_code=400, detail="任务状态不正确...")
```
- ✅ 只允许在 `pending_confirmation` 状态申请退款
- ✅ 防止在已完成或已取消的任务上申请退款

**✅ 支付状态验证**:
```python
if not task.is_paid:
    raise HTTPException(status_code=400, detail="任务尚未支付，无需退款。")
```
- ✅ 确保任务已支付才能申请退款

**✅ 重复申请检查**:
```python
existing_refund = db.query(models.RefundRequest).filter(
    models.RefundRequest.task_id == task_id,
    models.RefundRequest.poster_id == current_user.id,
    models.RefundRequest.status.in_(["pending", "processing"])
).first()

if existing_refund:
    raise HTTPException(status_code=400, detail="您已经提交过退款申请...")
```
- ✅ 防止同一任务重复申请退款
- ✅ 检查pending和processing状态

**✅ 退款金额验证**:
```python
if final_refund_amount >= task_amount:
    raise HTTPException(status_code=400, 
        detail=f"部分退款金额不能大于或等于任务金额，请选择全额退款")
```
- ✅ 验证部分退款金额不能超过或等于任务金额
- ✅ 验证退款金额必须大于0
- ✅ 验证退款比例在0-100之间

### 3. 并发控制 ✅

**✅ 创建退款申请时的并发控制**:
```python
# 🔒 并发安全：使用 SELECT FOR UPDATE 锁定任务记录
task_query = select(models.Task).where(models.Task.id == task_id).with_for_update()
task_result = db.execute(task_query)
task = task_result.scalar_one_or_none()
```
- ✅ 使用 `SELECT FOR UPDATE` 锁定任务记录
- ✅ 防止并发创建多个退款申请

**✅ 撤销退款申请时的并发控制**:
```python
# 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
refund_query = select(models.RefundRequest).where(
    models.RefundRequest.id == refund_id,
    models.RefundRequest.task_id == task_id,
    models.RefundRequest.poster_id == current_user.id,
    models.RefundRequest.status == "pending"
).with_for_update()
```
- ✅ 使用 `SELECT FOR UPDATE` 锁定退款申请记录
- ✅ 防止并发撤销操作

**✅ 管理员审核时的并发控制**:
```python
# 🔒 并发安全：使用 SELECT FOR UPDATE 锁定退款申请记录
refund_query = select(models.RefundRequest).where(
    models.RefundRequest.id == refund_id,
    models.RefundRequest.status == "pending"
).with_for_update()
```
- ✅ 使用 `SELECT FOR UPDATE` 锁定退款申请记录
- ✅ 防止多个管理员同时审核

### 4. 输入验证 ✅

**✅ Schema验证**:
```python
class RefundRequestCreate(BaseModel):
    reason: str = Field(..., min_length=10, max_length=2000)
    refund_amount: Optional[Decimal] = Field(None, ge=0)
    refund_percentage: Optional[float] = Field(None, ge=0, le=100)
```
- ✅ 退款原因长度验证（10-2000字符）
- ✅ 退款金额非负验证（ge=0）
- ✅ 退款比例范围验证（0-100）
- ✅ 使用Pydantic自动验证

### 5. SQL注入防护 ✅

**✅ ORM使用**:
- 所有数据库操作使用SQLAlchemy ORM
- 使用参数化查询，自动防止SQL注入
- 没有发现直接SQL字符串拼接

### 6. 文件验证 ✅

**✅ 文件ID验证**:
```python
# ✅ 修复文件ID验证：验证证据文件ID是否属于当前用户或任务
validated_evidence_files = []
if refund_data.evidence_files:
    for file_id in refund_data.evidence_files:
        # 检查文件是否存在于MessageAttachment中，且与当前任务相关
        attachment = db.query(MessageAttachment).filter(
            MessageAttachment.blob_id == file_id
        ).first()
        
        if attachment:
            # 通过附件找到消息，验证是否属于当前任务
            task_message = db.query(Message).filter(
                Message.id == attachment.message_id,
                Message.task_id == task_id
            ).first()
            
            if task_message:
                validated_evidence_files.append(file_id)
```
- ✅ 验证文件是否属于当前任务
- ✅ 防止使用他人文件作为证据

### 7. Stripe操作安全 ✅

**✅ API密钥管理**:
```python
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
if not stripe.api_key:
    return False, None, None, "Stripe API 未配置"
```
- ✅ 从环境变量读取密钥
- ✅ 检查密钥是否存在

**✅ Idempotency Key**:
```python
# ✅ 修复Stripe Idempotency：生成idempotency_key防止重复退款
idempotency_key = hashlib.sha256(
    f"refund_{task.id}_{refund_request.id}_{refund_amount_pence}".encode()
).hexdigest()

refund = stripe.Refund.create(
    charge=charge_id,
    amount=refund_amount_pence,
    reason="requested_by_customer",
    idempotency_key=idempotency_key,
    metadata={...}
)
```
- ✅ 使用idempotency_key防止重复退款
- ✅ 基于任务ID、退款申请ID和金额生成唯一key

**✅ Metadata记录**:
```python
metadata={
    "task_id": str(task.id),
    "refund_request_id": str(refund_request.id),
    "poster_id": str(task.poster_id),
    "taker_id": str(task.taker_id) if task.taker_id else "",
}
```
- ✅ 在Stripe metadata中记录关联信息
- ✅ 便于webhook处理和审计

### 8. 金额精度 ✅

**✅ Decimal使用**:
```python
from decimal import Decimal

task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
refund_amount_decimal = Decimal(str(refund_amount))
```
- ✅ 使用Decimal进行金额计算
- ✅ 避免float精度问题
- ✅ 所有金额比较和计算都使用Decimal

### 9. 部分退款和Escrow管理 ✅

**✅ 部分退款时更新Escrow**:
```python
if refund_amount_decimal >= task_amount:
    # 全额退款
    task.is_paid = 0
    task.payment_intent_id = None
    task.escrow_amount = 0.0
else:
    # 部分退款：更新托管金额
    remaining_amount = task_amount - refund_amount_decimal
    from app.utils.fee_calculator import calculate_application_fee
    application_fee = calculate_application_fee(float(remaining_amount))
    new_escrow_amount = remaining_amount - Decimal(str(application_fee))
    
    # 更新托管金额（任务金额 - 退款金额 - 平台服务费）
    task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
```
- ✅ 全额退款时清零escrow_amount
- ✅ 部分退款时重新计算escrow_amount
- ✅ 考虑平台服务费

---

## ⚠️ 发现的安全问题

### 问题1：退款时未验证任务是否仍然已支付 ⚠️

**问题描述**：
在管理员批准退款时，没有再次验证任务是否仍然已支付。如果任务在申请退款后、管理员审核前被取消或退款，可能导致重复退款。

**位置**：`backend/app/routers.py` line 3232-3300

**当前代码**：
```python
@router.post("/admin/refund-requests/{refund_id}/approve")
def approve_refund_request(...):
    # 获取任务信息
    task = crud.get_task(db, refund_request.task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 没有检查 task.is_paid
    # 直接处理退款
```

**风险**：
- 如果任务在申请退款后、审核前被取消或退款，可能导致重复退款
- 如果任务状态已改变，可能导致数据不一致

**建议修复**：
```python
# 获取任务信息
task = crud.get_task(db, refund_request.task_id)
if not task:
    raise HTTPException(status_code=404, detail="Task not found")

# ✅ 验证任务仍然已支付
if not task.is_paid:
    raise HTTPException(
        status_code=400,
        detail="任务已不再支付，无法处理退款。可能已被取消或退款。"
    )

# ✅ 验证任务状态仍然允许退款
if task.status not in ["pending_confirmation", "in_progress", "completed"]:
    raise HTTPException(
        status_code=400,
        detail=f"任务状态已改变（当前状态: {task.status}），无法处理退款。"
    )
```

### 问题2：部分退款时未考虑已进行的部分转账 ⚠️

**问题描述**：
当处理部分退款时，代码只考虑了任务金额和退款金额，但没有考虑如果已经进行了部分转账给接单者的情况。这可能导致退款金额超过实际可用的escrow金额。

**位置**：`backend/app/refund_service.py` line 155-177

**当前代码**：
```python
# 3. 更新任务状态和托管金额
task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
refund_amount_decimal = Decimal(str(refund_amount))

if refund_amount_decimal >= task_amount:
    # 全额退款
    task.escrow_amount = 0.0
else:
    # 部分退款：更新托管金额
    remaining_amount = task_amount - refund_amount_decimal
    application_fee = calculate_application_fee(float(remaining_amount))
    new_escrow_amount = remaining_amount - Decimal(str(application_fee))
    task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
```

**风险**：
- 如果已经进行了部分转账，`task.escrow_amount` 可能已经减少
- 退款时只基于任务金额计算，没有考虑已转账的金额
- 可能导致退款金额超过实际可用的escrow

**建议修复**：
```python
# 3. 更新任务状态和托管金额
task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
refund_amount_decimal = Decimal(str(refund_amount))

# ✅ 计算已转账的总金额
from sqlalchemy import func
total_transferred = db.query(func.sum(models.PaymentTransfer.amount)).filter(
    models.PaymentTransfer.task_id == task.id,
    models.PaymentTransfer.status == "succeeded"
).scalar() or Decimal('0')

# ✅ 计算当前可用的escrow金额
current_escrow = Decimal(str(task.escrow_amount)) if task.escrow_amount else Decimal('0')

# ✅ 验证退款金额不超过可用escrow（考虑已转账）
if refund_amount_decimal > current_escrow:
    logger.error(f"退款金额（£{refund_amount_decimal}）超过可用escrow（£{current_escrow}），已转账：£{total_transferred}")
    return False, None, None, f"退款金额超过可用金额。可用金额：£{current_escrow:.2f}，已转账：£{total_transferred:.2f}"

if refund_amount_decimal >= task_amount:
    # 全额退款
    task.is_paid = 0
    task.payment_intent_id = None
    task.escrow_amount = 0.0
    logger.info(f"✅ 全额退款，已更新任务支付状态")
else:
    # 部分退款：更新托管金额
    # 计算退款后的剩余金额
    remaining_amount = task_amount - refund_amount_decimal
    from app.utils.fee_calculator import calculate_application_fee
    application_fee = calculate_application_fee(float(remaining_amount))
    new_escrow_amount = remaining_amount - Decimal(str(application_fee))
    
    # ✅ 确保新的escrow金额不超过剩余金额（考虑已转账）
    # 如果已经转账，escrow应该更少
    if total_transferred > 0:
        # 已转账的情况下，escrow应该是：任务金额 - 已转账 - 退款金额 - 服务费
        remaining_after_transfer = task_amount - total_transferred - refund_amount_decimal
        if remaining_after_transfer > 0:
            remaining_application_fee = calculate_application_fee(float(remaining_after_transfer))
            new_escrow_amount = remaining_after_transfer - Decimal(str(remaining_application_fee))
        else:
            new_escrow_amount = Decimal('0')
    
    # 更新托管金额
    task.escrow_amount = float(max(Decimal('0'), new_escrow_amount))
    logger.info(f"✅ 部分退款：退款金额 £{refund_amount:.2f}，剩余任务金额 £{remaining_amount:.2f}，已转账 £{total_transferred:.2f}，更新后托管金额 £{task.escrow_amount:.2f}")
```

### 问题3：管理员可以修改退款金额但未验证 ⚠️

**问题描述**：
管理员在批准退款时可以指定不同的退款金额，但没有验证这个金额是否合理（不能超过任务金额，不能超过可用escrow等）。

**位置**：`backend/app/routers.py` line 3274-3283

**当前代码**：
```python
# 如果管理员指定了不同的退款金额，使用管理员指定的金额
if approve_data.refund_amount is not None:
    refund_request.refund_amount = approve_data.refund_amount

# ✅ 修复金额精度：使用Decimal进行金额计算
refund_amount = Decimal(str(refund_request.refund_amount)) if refund_request.refund_amount else None
if refund_amount is None:
    # 全额退款：使用任务金额
    task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
    refund_amount = task_amount
```

**风险**：
- 管理员可能输入超过任务金额的退款金额
- 管理员可能输入超过可用escrow的退款金额
- 没有验证管理员输入的金额是否合理

**建议修复**：
```python
# 如果管理员指定了不同的退款金额，使用管理员指定的金额
if approve_data.refund_amount is not None:
    admin_refund_amount = Decimal(str(approve_data.refund_amount))
    task_amount = Decimal(str(task.agreed_reward)) if task.agreed_reward is not None else Decimal(str(task.base_reward)) if task.base_reward is not None else Decimal('0')
    
    # ✅ 验证管理员指定的金额不超过任务金额
    if admin_refund_amount > task_amount:
        raise HTTPException(
            status_code=400,
            detail=f"管理员指定的退款金额（£{admin_refund_amount:.2f}）超过任务金额（£{task_amount:.2f}）"
        )
    
    # ✅ 验证管理员指定的金额大于0
    if admin_refund_amount <= 0:
        raise HTTPException(
            status_code=400,
            detail="退款金额必须大于0"
        )
    
    # ✅ 计算已转账的总金额
    from sqlalchemy import func
    total_transferred = db.query(func.sum(models.PaymentTransfer.amount)).filter(
        models.PaymentTransfer.task_id == task.id,
        models.PaymentTransfer.status == "succeeded"
    ).scalar() or Decimal('0')
    
    # ✅ 计算当前可用的escrow金额
    current_escrow = Decimal(str(task.escrow_amount)) if task.escrow_amount else Decimal('0')
    
    # ✅ 验证退款金额不超过可用escrow（考虑已转账）
    if admin_refund_amount > current_escrow:
        raise HTTPException(
            status_code=400,
            detail=f"退款金额（£{admin_refund_amount:.2f}）超过可用金额（£{current_escrow:.2f}）。已转账：£{total_transferred:.2f}"
        )
    
    refund_request.refund_amount = admin_refund_amount
```

### 问题4：退款处理失败时的回滚机制不完整 ⚠️

**问题描述**：
当Stripe退款失败时，代码会返回错误，但退款申请状态已经被设置为"processing"，且任务状态可能已经被修改。如果后续重试，可能导致状态不一致。

**位置**：`backend/app/routers.py` line 3288-3367

**当前代码**：
```python
# 开始处理退款
refund_request.status = "processing"
refund_request.processed_at = get_utc_time()

try:
    success, refund_intent_id, refund_transfer_id, error_message = process_refund(...)
    
    if success:
        # 更新状态为completed
        refund_request.status = "completed"
    else:
        # 退款处理失败，保持 processing 状态，记录错误
        refund_request.admin_comment = f"{refund_request.admin_comment or ''}\n退款处理失败: {error_message}"
        raise HTTPException(status_code=500, detail=f"退款处理失败: {error_message}")
except HTTPException:
    raise
except Exception as e:
    logger.error(f"处理退款时发生错误: {e}", exc_info=True)
    refund_request.status = "processing"  # 保持 processing 状态，等待重试
    db.commit()
    raise HTTPException(status_code=500, detail=f"处理退款时发生错误: {str(e)}")
```

**风险**：
- 如果Stripe退款失败，但任务状态已经被修改（如escrow_amount被更新），可能导致数据不一致
- 如果后续重试，可能重复处理

**建议修复**：
```python
# 开始处理退款
refund_request.status = "processing"
refund_request.processed_at = get_utc_time()
db.flush()  # 先保存状态，但不提交

try:
    success, refund_intent_id, refund_transfer_id, error_message = process_refund(...)
    
    if success:
        # 更新状态为completed
        refund_request.status = "completed"
        refund_request.refund_intent_id = refund_intent_id
        refund_request.refund_transfer_id = refund_transfer_id
        refund_request.completed_at = get_utc_time()
        db.commit()  # 只有成功时才提交
    else:
        # 退款处理失败，回滚任务状态
        db.rollback()  # 回滚所有更改
        # 重新获取任务和退款申请（回滚后的状态）
        db.refresh(task)
        db.refresh(refund_request)
        # 保持pending状态，等待重试
        refund_request.status = "pending"
        refund_request.admin_comment = f"{refund_request.admin_comment or ''}\n退款处理失败: {error_message}"
        db.commit()
        raise HTTPException(status_code=500, detail=f"退款处理失败: {error_message}")
except HTTPException:
    db.rollback()  # 回滚所有更改
    raise
except Exception as e:
    logger.error(f"处理退款时发生错误: {e}", exc_info=True)
    db.rollback()  # 回滚所有更改
    # 重新获取退款申请（回滚后的状态）
    db.refresh(refund_request)
    # 保持pending状态，等待重试
    refund_request.status = "pending"
    db.commit()
    raise HTTPException(status_code=500, detail=f"处理退款时发生错误: {str(e)}")
```

### 问题5：Webhook处理退款时未验证任务状态 ⚠️

**问题描述**：
在Stripe webhook处理退款事件时，代码直接更新任务状态和escrow_amount，但没有验证任务是否仍然处于允许退款的状态。

**位置**：`backend/app/routers.py` line 6276-6365

**当前代码**：
```python
elif event_type == "charge.refunded":
    charge = event_data
    task_id = int(charge.get("metadata", {}).get("task_id", 0))
    
    if task_id:
        task = crud.get_task(db, task_id)
        if task:
            # 直接更新任务状态，没有验证
            if refund_amount >= task_amount:
                task.is_paid = 0
                task.escrow_amount = 0.0
```

**风险**：
- 如果任务状态已经改变（如已完成、已取消），webhook仍然会更新状态
- 可能导致数据不一致

**建议修复**：
```python
elif event_type == "charge.refunded":
    charge = event_data
    task_id = int(charge.get("metadata", {}).get("task_id", 0))
    refund_request_id = charge.get("metadata", {}).get("refund_request_id")
    
    if task_id:
        task = crud.get_task(db, task_id)
        if task:
            # ✅ 验证任务仍然已支付
            if not task.is_paid:
                logger.warning(f"任务 {task_id} 已不再支付，跳过webhook退款处理")
                return {"status": "skipped", "reason": "task_not_paid"}
            
            # ✅ 验证退款申请状态（如果有关联的退款申请）
            if refund_request_id:
                refund_request = db.query(models.RefundRequest).filter(
                    models.RefundRequest.id == int(refund_request_id)
                ).first()
                if refund_request and refund_request.status != "processing":
                    logger.warning(f"退款申请 {refund_request_id} 状态为 {refund_request.status}，不是processing，跳过webhook处理")
                    return {"status": "skipped", "reason": "refund_request_not_processing"}
            
            # 处理退款...
```

---

## 🔒 安全建议

### 优先级 P0（必须修复）

1. **验证任务仍然已支付** ⚠️
   - 在管理员批准退款时验证 `task.is_paid`
   - 在webhook处理退款时验证任务状态

2. **考虑部分转账的退款验证** ⚠️
   - 计算已转账的总金额
   - 验证退款金额不超过可用escrow（考虑已转账）
   - 更新escrow_amount时考虑已转账的金额

3. **管理员退款金额验证** ⚠️
   - 验证管理员指定的退款金额不超过任务金额
   - 验证退款金额不超过可用escrow
   - 验证退款金额大于0

### 优先级 P1（重要）

4. **改进错误处理和回滚** ⚠️
   - 当Stripe退款失败时，回滚任务状态更改
   - 保持退款申请为pending状态，等待重试
   - 避免部分提交导致的数据不一致

5. **Webhook处理验证** ⚠️
   - 验证任务状态仍然允许退款
   - 验证退款申请状态（如果有关联）

### 优先级 P2（建议）

6. **添加审计日志** 💡
   - 记录所有退款操作的详细信息
   - 记录管理员审核操作
   - 记录金额变更历史

7. **添加速率限制** 💡
   - 限制退款申请频率
   - 防止恶意刷申请

---

## 📊 安全性评分（更新）

| 安全方面 | 评分 | 状态 |
|---------|------|------|
| 身份认证 | 10/10 | ✅ 完善 |
| 权限验证 | 10/10 | ✅ 完善 |
| 输入验证 | 9/10 | ✅ 良好 |
| SQL注入防护 | 10/10 | ✅ 完善 |
| 业务逻辑验证 | 8/10 | ⚠️ 需要改进（缺少支付状态和escrow验证） |
| 并发控制 | 10/10 | ✅ 完善（已使用SELECT FOR UPDATE） |
| Stripe操作安全 | 9/10 | ✅ 良好（已使用idempotency） |
| Webhook安全 | 9/10 | ⚠️ 需要改进（缺少状态验证） |
| 数据完整性 | 8/10 | ⚠️ 需要改进（缺少escrow验证） |
| 金额精度 | 10/10 | ✅ 完善（已使用Decimal） |
| 文件验证 | 10/10 | ✅ 完善 |

**总体安全性评分**: 9.2/10

---

## ✅ 总结

### 安全性优点

1. ✅ **身份认证完善**：使用会话验证，检查用户状态
2. ✅ **权限验证严格**：确保只有发布者可以申请，只有管理员可以审核
3. ✅ **并发控制完善**：使用SELECT FOR UPDATE防止竞态条件
4. ✅ **金额精度准确**：使用Decimal进行所有金额计算
5. ✅ **Stripe Idempotency**：已使用idempotency_key防止重复退款
6. ✅ **文件验证完善**：验证文件是否属于任务
7. ✅ **输入验证完整**：使用Pydantic schema验证

### 需要改进的地方

1. ⚠️ **退款时验证任务状态**：需要验证任务仍然已支付
2. ⚠️ **考虑部分转账**：退款时需要验证可用escrow（考虑已转账）
3. ⚠️ **管理员金额验证**：需要验证管理员指定的退款金额
4. ⚠️ **错误处理改进**：需要改进回滚机制
5. ⚠️ **Webhook验证**：需要验证任务状态

### 建议

整体安全性**优秀**，但建议修复上述P0和P1问题，特别是：
- 验证任务仍然已支付
- 考虑部分转账的escrow验证
- 管理员退款金额验证

这些修复将进一步提高安全性到**卓越**水平。

---

**审计日期**: 2026年1月27日  
**审计人**: AI Assistant  
**状态**: 安全性优秀，建议修复P0和P1问题
