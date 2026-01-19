# iOS 微信支付支持实现指南

## 概述

根据 Stripe 文档，WeChat Pay（微信支付）可以在 iOS 应用中通过 Stripe PaymentSheet 支持。本指南说明如何配置和实现。

## ✅ 当前状态

### 已支持的功能
- ✅ 后端已使用 `automatic_payment_methods={"enabled": True}`，会自动启用所有可用的支付方式
- ✅ iOS 使用 PaymentSheet，会自动显示后端支持的支付方式
- ✅ 支付方式选择机制已实现

### 需要配置的部分
- ⚠️ 需要在 Stripe Dashboard 中启用 WeChat Pay
- ⚠️ 需要确保账户所在国家/地区支持 WeChat Pay
- ⚠️ 需要确保货币支持（WeChat Pay 支持 CNY 和多种其他货币）

## 📋 Stripe WeChat Pay 支持情况

### 支持的国家/地区
根据 Stripe 文档，以下国家的 Stripe 账户可以接受 WeChat Pay：
- AT, AU, BE, CA, CH, DE, DK, ES, FI, FR, GB, HK, IE, IT, JP, LU, NL, NO, PT, SE, SG, US

### 支持的货币
- **CNY**（默认，所有国家）
- **AUD, CAD, EUR, GBP, HKD, JPY, SGD, USD, DKK, NOK, SEK, CHF**（根据业务位置）

### 产品支持
- ✅ **PaymentSheet**（iOS 使用）
- ✅ **Checkout**
- ✅ **Elements**（但 Express Checkout Element 和 Mobile Payment Element 不支持）
- ✅ **Payment Links**
- ✅ **Invoicing**

### 限制
- ❌ 不支持 Express Checkout Element 和 Mobile Payment Element
- ❌ 不支持经常性付款
- ❌ 不支持争议处理（因为需要用户在微信中确认）
- ❌ 不支持手动捕获
- ✅ 支持退款/部分退款（180天内）

## 🚀 实现步骤

### 1. 在 Stripe Dashboard 中启用 WeChat Pay

1. 登录 [Stripe Dashboard](https://dashboard.stripe.com)
2. 前往 **Settings** → **Payment methods**
3. 找到 **WeChat Pay** 并启用
4. 确认账户所在国家/地区支持 WeChat Pay

### 2. 验证后端配置 ✅ 已更新

后端代码已经明确指定 `payment_method_types` 包含 `wechat_pay`，确保 WeChat Pay 可用：

```python
# backend/app/coupon_points_routes.py (已更新)
payment_intent = stripe.PaymentIntent.create(
    amount=final_amount,
    currency="gbp",  # GBP 是英国支持的货币，WeChat Pay 会自动换算成 CNY 显示给用户
    # 明确指定支付方式类型，确保 WeChat Pay 可用
    # 注意：不能同时使用 payment_method_types 和 automatic_payment_methods
    payment_method_types=["card", "wechat_pay"],
    # ...
)
```

**重要**：
- ✅ 后端已明确指定 `payment_method_types=["card", "wechat_pay"]`
- ✅ 不能同时使用 `payment_method_types` 和 `automatic_payment_methods`（会报错）
- ✅ 使用 GBP 货币，WeChat Pay 会自动换算成 CNY 显示给用户
- ⚠️ 必须确保 Stripe Dashboard 中已启用 WeChat Pay
- ⚠️ 必须确保账户所在国家/地区支持 WeChat Pay（英国 GB 在支持列表中）

### 3. iOS 端配置（可选优化）

当前 iOS 实现已经通过 PaymentSheet 自动支持 WeChat Pay。如果需要在 UI 中明确显示 WeChat Pay 选项，可以添加：

#### 方案 A：使用 PaymentSheet（推荐，当前实现）

PaymentSheet 会自动显示 WeChat Pay 选项（如果后端支持）。无需额外代码。

**优点**：
- ✅ 无需额外代码
- ✅ Stripe 自动处理
- ✅ 统一的支付界面

#### 方案 B：添加 WeChat Pay 作为独立支付方式选项 ✅ 已实现

已将 WeChat Pay 添加为独立的支付方式选项（类似 Apple Pay）。实现包括：

1. **扩展 `PaymentMethodType` 枚举**：添加了 `wechatPay` 选项
2. **更新 `PaymentViewModel`**：
   - 在 `selectPaymentMethod()` 中添加了 WeChat Pay 的处理逻辑
   - 在 `performPayment()` 中添加了 WeChat Pay 的支付流程
3. **更新 `StripePaymentView`**：
   - 在支付方式选择卡片中添加了 WeChat Pay 选项
   - 添加了专用的微信支付按钮（绿色渐变背景）
4. **添加本地化字符串**：
   - 英文：`"payment.pay_with_wechat_pay" = "Pay with WeChat Pay"`
   - 简体中文：`"payment.pay_with_wechat_pay" = "使用微信支付"`
   - 繁体中文：`"payment.pay_with_wechat_pay" = "使用微信支付"`

**工作原理**：WeChat Pay 通过 PaymentSheet 处理，所以选择 WeChat Pay 时仍然使用 PaymentSheet，PaymentSheet 会自动显示 WeChat Pay 选项（如果后端 PaymentIntent 支持）。

## 🔍 验证步骤

### 1. 检查 Stripe Dashboard
- [ ] 确认 WeChat Pay 已启用
- [ ] 确认账户所在国家/地区支持 WeChat Pay
- [ ] 确认货币设置正确

### 2. 测试支付流程
1. 在 iOS 应用中创建支付
2. 打开 PaymentSheet
3. 检查是否显示 WeChat Pay 选项
4. 选择 WeChat Pay 并完成支付测试

### 3. 检查支付方式可用性

可以在后端添加 API 来检查可用的支付方式：

```python
# 在创建 PaymentIntent 后，检查可用的支付方式
payment_intent = stripe.PaymentIntent.create(...)
available_payment_methods = payment_intent.payment_method_types
# 如果包含 'wechat_pay'，说明 WeChat Pay 可用
```

## 📱 用户体验

### 当前实现（PaymentSheet）
1. 用户选择"信用卡/借记卡"支付方式
2. 点击"确认支付"按钮
3. PaymentSheet 弹出，显示所有可用的支付方式（包括 WeChat Pay）
4. 用户可以选择 WeChat Pay 完成支付

### 如果添加独立选项（当前实现）
1. 用户可以在支付方式选择卡片中选择"微信支付"
2. 点击"使用微信支付"按钮后，PaymentSheet 弹出
3. **重要**：PaymentSheet 会显示所有可用的支付方式（包括 WeChat Pay、Card 等）
4. 用户需要在 PaymentSheet 中**手动选择 WeChat Pay 选项**
5. 选择 WeChat Pay 后，会跳转到微信应用完成支付
6. 支付完成后，通过 returnURL 返回到应用

**注意**：PaymentSheet 不会自动选择 WeChat Pay，用户需要手动选择。这是 Stripe PaymentSheet 的设计，它会显示所有可用的支付方式供用户选择。

## ⚠️ 注意事项

### 1. 货币设置
- 如果主要面向中国用户，建议使用 CNY
- 如果面向国际用户，可以使用其他支持的货币（如 GBP, USD 等）
- WeChat Pay 用户会看到 CNY 金额（即使后端使用其他货币）

### 2. 退款限制
- WeChat Pay 支付只能在 180 天内退款
- 退款是异步的，需要通过 webhook 监听 `refund.updated` 或 `refund.failed` 事件

### 3. 支付确认
- WeChat Pay 需要用户在微信应用中确认支付
- 支付流程可能需要跳转到微信应用

### 4. 地区限制
- WeChat Pay 主要面向中国消费者、海外华人以及中国游客
- 确保目标用户群体适合使用 WeChat Pay

## 🔧 故障排查

### 点击"微信支付"后仍然显示"借记卡付款"窗口 ⚠️ 重要

如果点击"微信支付"后，PaymentSheet 仍然显示卡片支付界面，请按以下步骤排查：

1. **检查 Stripe Dashboard**（最重要）：
   - 登录 [Stripe Dashboard](https://dashboard.stripe.com)
   - 前往 **Settings** → **Payment methods**
   - 确认 **WeChat Pay** 已启用（开关为绿色）
   - 如果未启用，请启用并保存
   - ⚠️ **这是最常见的原因**

2. **检查账户国家/地区**：
   - 确认账户所在国家/地区支持 WeChat Pay
   - 支持的国家/地区：AT, AU, BE, CA, CH, DE, DK, ES, FI, FR, GB, HK, IE, IT, JP, LU, NL, NO, PT, SE, SG, US

3. **检查货币设置**：
   - 确认使用的货币支持 WeChat Pay
   - 支持的货币：CNY（默认）、AUD, CAD, EUR, GBP, HKD, JPY, SGD, USD, DKK, NOK, SEK, CHF
   - 如果主要面向中国用户，建议使用 `currency="cny"`

4. **检查后端 PaymentIntent**：
   - 确认后端创建 PaymentIntent 时包含 `payment_method_types=["card", "wechat_pay"]`
   - ✅ 已更新的文件：
     - `backend/app/coupon_points_routes.py`
     - `backend/app/task_chat_routes.py`
     - `backend/app/flea_market_routes.py`
     - `backend/app/task_expert_routes.py`

5. **验证 PaymentIntent**：
   - 在 Stripe Dashboard 中查看创建的 PaymentIntent
   - 检查 `payment_method_types` 字段是否包含 `wechat_pay`
   - 如果只有 `card`，说明 WeChat Pay 未启用或不被支持

### WeChat Pay 不显示在 PaymentSheet 中
1. **检查 Stripe Dashboard**：确认 WeChat Pay 已启用
2. **检查账户国家/地区**：确认账户所在国家/地区支持 WeChat Pay
3. **检查货币**：确认使用的货币支持 WeChat Pay
4. **检查 PaymentIntent**：确认 PaymentIntent 的 `payment_method_types` 包含 `wechat_pay`

### 支付失败
1. **检查用户是否安装微信**：WeChat Pay 需要微信应用
2. **检查网络连接**：确保可以访问微信服务器
3. **检查 Stripe 日志**：查看 Stripe Dashboard 中的支付日志

## 📚 参考资源

- [Stripe WeChat Pay 文档](https://docs.stripe.com/payments/wechat-pay)
- [Stripe PaymentSheet iOS 文档](https://stripe.dev/stripe-ios/docs/Classes/PaymentSheet.html)
- [Stripe Dashboard - 支付方式设置](https://dashboard.stripe.com/settings/payment_methods)

## ✅ 总结

**当前状态**：iOS 应用已经实现了方案B，将 WeChat Pay 添加为独立的支付方式选项。

**已实现的功能**：
1. ✅ 扩展了 `PaymentMethodType` 枚举，添加 `wechatPay` 选项
2. ✅ 更新了 `PaymentViewModel`，支持 WeChat Pay 支付流程
3. ✅ 更新了 `StripePaymentView`，显示 WeChat Pay 选项和专用按钮
4. ✅ 添加了完整的本地化支持（英文、简体中文、繁体中文）

**使用前提**：
1. ⚠️ 在 Stripe Dashboard 中启用 WeChat Pay
2. ⚠️ 账户所在国家/地区支持 WeChat Pay
3. ⚠️ 使用支持的货币（CNY、GBP、USD 等）

**工作原理**：用户选择"微信支付"后，点击支付按钮会弹出 PaymentSheet，PaymentSheet 会自动显示 WeChat Pay 选项（如果后端 PaymentIntent 支持）。
