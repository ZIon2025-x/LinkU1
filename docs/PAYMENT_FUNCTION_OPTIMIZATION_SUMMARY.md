# 支付功能优化总结

## 概述
本文档总结了活动、服务、跳蚤市场等相关支付功能的优化工作。

## 优化内容

### 1. 活动申请支付 (`multi_participant_routes.py::apply_to_activity`)

#### 优化前的问题
- ❌ 使用了直接转账模式（`transfer_data` + `application_fee_amount`）
- ❌ 支付模式与任务状态矛盾（直接转账应该立即完成，但状态是 `pending_payment`）
- ❌ 没有返回 `client_secret`，前端无法完成支付

#### 优化后的改进
- ✅ 改为托管模式（与其他支付功能一致）
  - 移除 `transfer_data` 和 `application_fee_amount`
  - 资金留在平台账户，任务完成后通过 Transfer 转账
  - 平台服务费在转账时扣除
- ✅ 返回完整的支付信息
  - `payment_intent_id`
  - `client_secret`
  - `amount` 和 `amount_display`
  - `currency`
  - `customer_id` 和 `ephemeral_key_secret`（用于保存卡）
  - `payment_expires_at`（支付过期时间）

### 2. 服务申请支付 (`task_expert_routes.py::apply_for_service`)

#### 优化前的问题
- ❌ 使用了直接转账模式（`transfer_data` + `application_fee_amount`）
- ❌ 支付模式与任务状态矛盾
- ❌ 没有返回 `client_secret`，前端无法完成支付
- ❌ 返回的是 `ServiceApplicationOut`，不包含支付信息

#### 优化后的改进
- ✅ 改为托管模式（与其他支付功能一致）
  - 移除 `transfer_data` 和 `application_fee_amount`
  - 资金留在平台账户，任务完成后通过 Transfer 转账
  - 平台服务费在转账时扣除
- ✅ 扩展 `ServiceApplicationOut` 模型
  - 添加支付相关字段（`payment_intent_id`, `client_secret`, `payment_amount` 等）
  - 所有字段都是可选的，向后兼容
- ✅ 返回完整的支付信息
  - 当任务状态为 `pending_payment` 时，自动添加支付信息到响应

### 3. 服务申请批准支付 (`task_expert_routes.py::approve_service_application`)

#### 状态
✅ **已完善** - 无需优化
- ✅ 使用托管模式
- ✅ 返回完整的支付信息
- ✅ 已设置 `payment_expires_at`

### 4. 跳蚤市场直接购买 (`flea_market_routes.py::direct_purchase_item`)

#### 状态
✅ **已完善** - 无需优化
- ✅ 使用托管模式
- ✅ 返回完整的支付信息
- ✅ 已设置 `payment_expires_at`

### 5. 跳蚤市场接受购买 (`flea_market_routes.py::accept_purchase_request`)

#### 状态
✅ **已完善** - 无需优化
- ✅ 使用托管模式
- ✅ 返回完整的支付信息
- ✅ 已设置 `payment_expires_at`

## 统一支付模式

### 托管模式（Escrow/Marketplace）
所有待支付任务现在都使用托管模式：

1. **支付时**：
   - 资金先到平台账户
   - 不设置 `transfer_data.destination`
   - 不设置 `application_fee_amount`

2. **任务完成后**：
   - 使用 `Transfer.create` 将资金转给任务接受人
   - 平台服务费在转账时扣除

3. **优势**：
   - 统一处理支付过期、退款等场景
   - 更好的资金安全保障
   - 支持任务完成后再转账

## 统一返回格式

所有创建 PaymentIntent 的接口现在都返回：

```json
{
  "payment_intent_id": "pi_xxx",
  "client_secret": "pi_xxx_secret_xxx",
  "amount": 1000,
  "amount_display": "10.00",
  "currency": "GBP",
  "customer_id": "cus_xxx",
  "ephemeral_key_secret": "ek_xxx",
  "payment_required": true,
  "payment_expires_at": "2024-01-01T12:00:00Z"
}
```

## 支付过期处理

所有待支付任务都：
- ✅ 设置 `payment_expires_at`（24小时）
- ✅ 定时任务检查并取消过期任务
- ✅ 发送支付提醒通知（过期前 12、6、1 小时）

## 相关文件

- `backend/app/multi_participant_routes.py`：活动申请支付
- `backend/app/task_expert_routes.py`：服务申请支付
- `backend/app/flea_market_routes.py`：跳蚤市场购买支付
- `backend/app/schemas.py`：`ServiceApplicationOut` 模型扩展

## 测试建议

1. **活动申请支付测试**：
   - 申请需要支付的活动
   - 检查是否返回 `client_secret`
   - 检查支付流程是否正常
   - 检查支付过期是否正常工作

2. **服务申请支付测试**：
   - 申请需要支付的服务
   - 检查是否返回 `client_secret`
   - 检查支付流程是否正常
   - 检查支付过期是否正常工作

3. **支付模式测试**：
   - 验证所有支付都使用托管模式
   - 验证任务完成后资金正确转账
   - 验证平台服务费正确扣除

## 后续优化建议

1. **支付统计**：添加支付成功率、支付过期率等统计
2. **支付监控**：添加支付流程的监控指标
3. **用户体验**：优化支付流程的用户体验
4. **错误处理**：完善支付失败的错误处理和重试机制
