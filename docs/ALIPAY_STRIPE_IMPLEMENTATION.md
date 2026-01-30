# 支付宝（Stripe Alipay）接入说明

## 概述

项目已通过 Stripe API 支持支付宝付款。支付宝为单次使用、需用户验证的支付方式：用户会跳转到支付宝页面完成授权后返回应用/网页。

## 已实现内容

### 后端
- 在所有创建 PaymentIntent 的接口中已加入 `alipay` 到 `payment_method_types`：
  - `coupon_points_routes.py`（任务支付/优惠券）
  - `task_chat_routes.py`
  - `task_expert_routes.py`
  - `flea_market_routes.py`
  - `multi_participant_routes.py`
- Checkout Session（`routers.py`）中已加入 `alipay`。

### iOS
- `PaymentMethodType` 枚举已增加 `alipayPay`。
- 支付方式选择卡片中已显示「支付宝」选项。
- 支付宝支付按钮（蓝色样式）及 PaymentSheet 流程已接入。
- 本地化：简体/繁体/英文已添加「使用支付宝支付」文案。
- URL 处理：`link2ur://stripe-redirect` 与 `link2ur://safepay` 均会作为 Stripe 支付回调处理；收到后**必须**调用 `StripeAPI.handleURLCallback(with: url)` 将 URL 转给 Stripe SDK（`onOpenURL` 与 `application(_:open:options:)` 均已实现），否则跳转支付宝返回后 PaymentSheet 无法完成流程。

### 前端 Web
- PaymentModal、StripePaymentForm 的 `confirmPayment` 已传入 `return_url`，支持支付宝等重定向类支付方式返回当前页。

## Stripe 支付宝要求

- **支持货币**：aud, cad, eur, gbp, hkd, jpy, nzd, sgd, usd, myr（展示可含 cny）。
- **支付模式**：仅一次性支付，不支持订阅。
- **退款**：原始付款后 90 天内可退款；不参与争议流程。

## 使用前检查

1. **Stripe Dashboard**：Settings → Payment methods → 启用 **Alipay**。
2. **账户地区与结算**：确认 Stripe 账户所在国家/地区及结算货币在 [Stripe 支付宝文档](https://docs.stripe.com/payments/alipay#supported-currencies) 支持范围内。
3. **当前项目货币**：后端使用 GBP 等，均在 Stripe 支付宝支持列表中。

## 测试建议

- **Web**：在支付页选择支付宝，完成跳转与返回，确认 `return_url` 带回的 `payment_intent` / `payment_intent_client_secret` 能正确展示结果或轮询状态。
- **iOS**：选择「支付宝」→ 使用支付宝支付 → 在 Safari/支付宝 App 完成支付 → 应通过 `link2ur://stripe-redirect` 或 `link2ur://safepay` 返回 App，PaymentSheet 完成流程。

## 参考

- [Stripe 支付宝文档](https://docs.stripe.com/payments/alipay)
- [Stripe 接受支付宝付款（Checkout / PaymentIntent）](https://docs.stripe.com/payments/alipay/accept-a-payment)
