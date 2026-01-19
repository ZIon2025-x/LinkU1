# 托管模式验证报告

## 概述
本文档验证所有支付功能是否都使用托管模式（Escrow/Marketplace Mode）。

## 托管模式定义

### 托管模式特征
- ❌ **不设置** `transfer_data.destination`
- ❌ **不设置** `application_fee_amount`
- ✅ 资金支付时留在平台账户
- ✅ 任务完成后通过 `Transfer.create` 转账
- ✅ 平台服务费在转账时扣除

### 直接转账模式特征（已废弃）
- ✅ 设置 `transfer_data.destination`
- ✅ 设置 `application_fee_amount`
- ❌ 资金支付时立即转到接收方账户
- ❌ 平台服务费自动扣除

## 验证结果

### ✅ 1. 活动申请支付 (`multi_participant_routes.py::apply_to_activity`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

### ✅ 2. 服务申请支付 (`task_expert_routes.py::apply_for_service`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

### ✅ 3. 服务申请批准支付 (`task_expert_routes.py::approve_service_application`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

### ✅ 4. 跳蚤市场直接购买 (`flea_market_routes.py::direct_purchase_item`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

### ✅ 5. 跳蚤市场接受购买 (`flea_market_routes.py::accept_purchase_request`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

### ✅ 6. 任务申请接受 (`task_chat_routes.py::accept_application`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

### ✅ 7. 任务议价接受 (`task_chat_routes.py::respond_negotiation`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

### ✅ 8. 任务支付 (`coupon_points_routes.py::create_task_payment`)
- ✅ 使用托管模式
- ✅ 不设置 `transfer_data.destination`
- ✅ 不设置 `application_fee_amount`
- ✅ 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`，用于后续转账

## 验证方法

使用以下命令验证所有支付功能都使用托管模式：

```bash
# 检查是否还有使用 transfer_data.destination 的地方
grep -r "transfer_data.*destination" backend/app/

# 检查是否还有使用 application_fee_amount 的地方（在 PaymentIntent.create 中）
grep -r "application_fee_amount" backend/app/ | grep -v "metadata" | grep -v "注释" | grep -v "不设置"
```

## 结论

✅ **所有支付功能都已使用托管模式**

- 所有创建 PaymentIntent 的地方都不设置 `transfer_data.destination`
- 所有创建 PaymentIntent 的地方都不设置 `application_fee_amount`
- 所有支付功能都在 metadata 中保存必要信息，用于后续转账
- 所有支付功能都统一使用托管模式，确保资金安全和一致性

## 转账流程

### 支付时
1. 创建 PaymentIntent（托管模式）
2. 资金留在平台账户
3. 在 metadata 中保存 `taker_stripe_account_id` 和 `application_fee`

### 任务完成时
1. 从 PaymentIntent metadata 获取 `taker_stripe_account_id` 和 `application_fee`
2. 计算转账金额 = 任务金额 - 平台服务费
3. 使用 `Transfer.create` 转账给任务接受人
4. 更新任务状态和转账记录

## 相关文件

- `backend/app/multi_participant_routes.py`：活动申请支付
- `backend/app/task_expert_routes.py`：服务申请支付
- `backend/app/flea_market_routes.py`：跳蚤市场购买支付
- `backend/app/task_chat_routes.py`：任务申请和议价支付
- `backend/app/coupon_points_routes.py`：任务支付
- `backend/app/payment_transfer_service.py`：转账服务
