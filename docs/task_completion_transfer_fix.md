# 任务完成转账修复

## 问题

任务完成后，任务金额没有转给任务接受人。

## 原因

前端调用的 API 端点 `/api/tasks/{task_id}/confirm_completion` 只更新了任务状态，**没有执行转账逻辑**。

转账逻辑在另一个端点 `/api/tasks/{task_id}/confirm_complete` 中，但前端没有调用它。

## 解决方案

在 `confirm_task_completion` 函数中添加了自动转账逻辑。

### 转账条件

转账会在以下条件**全部满足**时自动执行：

1. ✅ 任务已支付：`task.is_paid == 1`
2. ✅ 任务未确认：`task.is_confirmed == 0`（防止重复转账）
3. ✅ 任务有接受人：`task.taker_id` 不为空
4. ✅ 托管金额大于0：`task.escrow_amount > 0`

### 转账流程

1. **检查任务接受人**：
   - 验证接受人是否存在
   - 验证是否有 Stripe Connect 账户

2. **验证 Stripe Connect 账户**：
   - 检查账户是否已完成 onboarding（`details_submitted`）
   - 检查账户是否已启用收款（`charges_enabled`）

3. **重新计算托管金额**（如果需要）：
   - 如果 `escrow_amount <= 0`，重新计算
   - `escrow_amount = 任务金额 - 平台服务费`

4. **执行 Stripe Transfer**：
   - 创建 Transfer 到接受人的 Stripe Connect 账户
   - 金额：`escrow_amount`（已扣除平台服务费）
   - 包含完整的 metadata（task_id, taker_id, poster_id 等）

5. **更新任务状态**：
   - `is_confirmed = 1`（标记为已确认）
   - `paid_to_user_id = taker_id`（记录已支付给谁）
   - `escrow_amount = 0.0`（清空托管金额）

### 错误处理

- ✅ 转账失败不影响任务完成确认
- ✅ 详细的错误日志记录
- ✅ 警告日志记录（账户未设置等）

## 代码位置

**文件**: `backend/app/routers.py`  
**函数**: `confirm_task_completion`  
**位置**: 第 1637-1704 行

## 转账信息

### Transfer Metadata

```python
{
    "task_id": str(task_id),
    "taker_id": str(taker.id),
    "poster_id": str(current_user.id),
    "transfer_type": "task_reward"
}
```

### Transfer Description

```
任务 #{task_id} 奖励 - {task.title}
```

## 测试建议

### 1. 测试正常转账流程

```bash
# 1. 创建任务并支付
# 2. 服务者标记任务完成
POST /api/tasks/{task_id}/complete

# 3. 发布者确认完成（应该自动转账）
POST /api/tasks/{task_id}/confirm_completion

# 4. 检查：
# - 任务 is_confirmed = 1
# - 任务 escrow_amount = 0.0
# - Stripe Dashboard 中有 Transfer 记录
```

### 2. 测试防重复转账

```bash
# 1. 确认完成（第一次）
POST /api/tasks/{task_id}/confirm_completion
# 应该转账

# 2. 再次确认完成（应该跳过转账）
POST /api/tasks/{task_id}/confirm_completion
# 应该返回错误或跳过转账（因为 is_confirmed = 1）
```

### 3. 测试账户未设置的情况

```bash
# 如果任务接受人没有 Stripe Connect 账户
# 转账应该跳过，但任务仍然可以确认完成
# 日志中应该有警告信息
```

## 日志检查

转账成功时，应该看到以下日志：

```
准备转账: 金额=XXX 便士 (£X.XX), 目标账户=acct_xxx
✅ Transfer 创建成功: transfer_id=tr_xxx, amount=£X.XX
✅ 任务 XXX 转账完成，金额已转给接受人 XXX
```

转账失败时，应该看到：

```
Stripe transfer error for task XXX: [错误信息]
或
任务接受人尚未创建 Stripe Connect 账户: taker_id=XXX
```

## 相关端点

- `/api/tasks/{task_id}/confirm_completion` - 前端调用的端点（已添加转账逻辑）✅
- `/api/tasks/{task_id}/confirm_complete` - 另一个端点（也有转账逻辑，但前端未调用）

## 注意事项

1. **幂等性**：通过 `is_confirmed` 检查防止重复转账
2. **错误处理**：转账失败不影响任务完成确认
3. **账户验证**：转账前验证 Stripe Connect 账户状态
4. **金额计算**：自动重新计算 `escrow_amount`（如果需要）

## 总结

✅ **问题已修复**：任务完成确认时自动转账给任务接受人  
✅ **防重复转账**：通过 `is_confirmed` 检查  
✅ **错误处理完善**：转账失败不影响任务完成流程  
✅ **详细日志**：方便调试和追踪

