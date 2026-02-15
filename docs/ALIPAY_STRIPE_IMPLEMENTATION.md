# 支付宝 & 微信支付（Stripe）接入说明

## 概述

项目已通过 Stripe API 支持支付宝和微信支付。两者均为单次使用、需用户验证的支付方式：用户会跳转到对应支付平台完成授权后返回应用/网页。

**重要更新（2026-01）**：
- **支付宝**：iOS 端支付宝改为通过 **PaymentSheet** 发起（与微信一致）。后端创建仅含 `alipay` 的 PaymentIntent，由 Sheet 展示支付宝入口并统一处理跳转与回调，避免使用 `STPPaymentHandler.confirmPaymentIntent` 直接跳转时的闪退。
- **微信**：继续使用 PaymentSheet（后端创建仅含 `wechat_pay` 的 PI）。

## 已实现内容

### 后端
- 在所有创建 PaymentIntent 的接口中已加入 `alipay` 和 `wechat_pay` 到 `payment_method_types`：
  - `coupon_points_routes.py`（任务支付/优惠券）
  - `task_chat_routes.py`
  - `task_expert_routes.py`
  - `flea_market_routes.py`
  - `multi_participant_routes.py`
- Checkout Session（`routers.py`）中已加入 `alipay` 和 `wechat_pay`。
- 支持 `preferred_payment_method` 参数：传入 `card`/`alipay`/`wechat_pay` 可创建只包含该支付方式的 PaymentIntent。

### iOS
- `PaymentMethodType` 枚举已增加 `alipayPay` 和 `wechatPay`。
- 支付方式选择卡片中已显示「支付宝」和「微信支付」选项。
- **支付宝**：使用 PaymentSheet（后端创建仅含 `alipay` 的 PI，Sheet 只显示支付宝并由 SDK 处理跳转与回调）。
- **微信**：使用 PaymentSheet（后端创建仅含 `wechat_pay` 的 PI）。
- 银行卡支付使用 PaymentSheet（需要收集卡号信息）。
- 本地化：简体/繁体/英文已添加「使用支付宝支付」和「使用微信支付」文案。
- URL 处理：PaymentSheet 与确认流程使用的 return_url 为 `link2ur://stripe-redirect`。App 内所有通过 `link2ur` scheme 打开的 URL（含 `stripe-redirect`、`safepay` 等）均会传入 `StripeAPI.handleURLCallback(with: url)`（`onOpenURL` 与 `application(_:open:options:)` 均已实现），由 Stripe SDK 判断是否处理，否则跳转支付宝/微信返回后无法完成流程。

### 前端 Web
- PaymentModal、StripePaymentForm 的 `confirmPayment` 已传入 `return_url`，支持支付宝/微信等重定向类支付方式返回当前页。

---

## Stripe 支付宝要求

- **支持货币**：aud, cad, eur, gbp, hkd, jpy, nzd, sgd, usd, myr（展示可含 cny）。
- **支付模式**：仅一次性支付，不支持订阅。
- **退款**：原始付款后 90 天内可退款；不参与争议流程。

---

## Stripe 微信支付要求

- **支持货币**：aud, cad, eur, gbp, hkd, jpy, nzd, sgd, usd, cny, dkk, nok, sek, chf。
- **支付模式**：仅一次性支付，不支持订阅。
- **退款**：原始付款后 180 天内可退款；不参与争议流程。
- **重要限制**：
  - 仅支持手机端使用（桌面端需扫码）
  - 需要用户已安装微信 App
  - 在中国大陆以外地区，微信支付可能不可用或体验受限

---

## 使用前检查（Stripe Dashboard 配置）

### 1. 启用支付宝

1. 登录 [Stripe Dashboard](https://dashboard.stripe.com/)
2. 进入 **Settings** → **Payment methods**
3. 找到 **Alipay**，点击 **Turn on**
4. 确认状态显示为 **Enabled**

### 2. 启用微信支付（WeChat Pay）

1. 登录 [Stripe Dashboard](https://dashboard.stripe.com/)
2. 进入 **Settings** → **Payment methods**
3. 找到 **WeChat Pay**，点击 **Turn on**
4. 如果看不到 WeChat Pay 选项，可能原因：
   - 你的 Stripe 账户所在国家不支持（目前支持：澳大利亚、奥地利、比利时、加拿大、丹麦、芬兰、法国、德国、爱尔兰、意大利、日本、卢森堡、荷兰、挪威、葡萄牙、新加坡、西班牙、瑞典、瑞士、英国、美国）
   - 需要完成 Stripe 账户验证
5. 确认状态显示为 **Enabled**

### 3. 验证 Payment Method Configuration

可以通过 Stripe API 检查配置状态：

```bash
curl https://api.stripe.com/v1/payment_method_configurations \
  -u sk_test_xxx:
```

返回结果中应包含：
- `alipay.available: true`
- `wechat_pay.available: true`

### 4. 账户地区与结算

- 确认 Stripe 账户所在国家/地区及结算货币在支持范围内
- 当前项目使用 GBP，在支付宝和微信支付支持列表中

---

## 测试建议

### Web 端
1. 在支付页选择支付宝/微信
2. 完成跳转与返回
3. 确认 `return_url` 带回的 `payment_intent` / `payment_intent_client_secret` 能正确展示结果

### iOS 端
1. 选择「支付宝」→ 点击支付按钮 → 弹出 PaymentSheet（仅显示支付宝）→ 在 Sheet 内跳转到支付宝 App/网页完成支付 → 返回 App
2. 选择「微信支付」→ 点击支付按钮 → 弹出 PaymentSheet（仅显示微信）→ 在 Sheet 内跳转到微信 App 完成支付 → 返回 App
3. 返回后应通过 `link2ur://stripe-redirect` 回调，App 自动处理支付结果

### 常见问题

**Q: 微信支付在 PaymentSheet/支付按钮中不显示？**
A: 检查以下几点：
1. Stripe Dashboard 中是否已启用 WeChat Pay
2. 后端创建 PaymentIntent 时是否包含 `wechat_pay`（查看日志）
3. 账户所在地区是否支持 WeChat Pay

**Q: 微信支付是否支持沙盒/测试模式？**
A: Stripe 测试模式下可以创建包含 `wechat_pay` 的 PaymentIntent，但实际跳转微信完成支付在测试环境可能受限（例如仅模拟或部分地区不可用）。生产环境需在 Stripe Dashboard 完成 WeChat Pay 的正式配置。

**Q: 为什么微信支付用 PaymentSheet 而不是直接跳转？**
A: Stripe iOS SDK 的 StripePayments 模块未暴露 `STPPaymentMethodWeChatPayParams` 等微信直接确认 API，因此 App 内对微信支付采用「仅含 wechat_pay 的 PaymentIntent + PaymentSheet」方式，由 Sheet 展示微信支付入口并完成跳转。

**Q: 为什么支付宝也改用 PaymentSheet？**
A: 原先使用 `STPPaymentHandler.confirmPaymentIntent` 直接跳转支付宝时，在部分设备上会出现点击支付后闪退。改为与微信一致的 PaymentSheet 流程后，由 SDK 统一处理跳转与回调，可避免该问题。

**Q: 点击支付后没有跳转到支付宝/微信？**
A: 
1. 确保 `returnURL` 已正确配置为 `link2ur://stripe-redirect`
2. 检查 Info.plist 中是否配置了 URL Scheme
3. 查看 Xcode 控制台日志排查错误

**Q: 为什么 iOS 测试模式一下就能成功，Flutter 支付后还停在支付页？**
A: 
- **原因**：iOS 在收到支付宝/3DS 重定向（`link2ur://stripe-redirect`）时会调用 **StripeAPI.handleURLCallback(with: url)**，把 URL 交给 Stripe SDK，Sheet 才能完成流程并立刻回调 `.completed`，所以测试模式下「一下就能成功」。Flutter 若**没有**把该深度链接交给 Stripe，SDK 收不到重定向，`presentPaymentSheet()` 会一直不返回成功，页面就一直停在支付页。
- **Flutter 修复**：在 `DeepLinkHandler` 里对 `link2ur://stripe-redirect` 先调用 **Stripe.instance.handleURLCallback(uri)**，与 iOS 行为一致；并在 Stripe 初始化时设置 **Stripe.urlScheme = 'link2ur'**。这样从支付宝/3DS 返回后，SDK 能处理重定向，`presentPaymentSheet()` 会尽快返回成功，页面即可关闭。

**Q: 为什么 Stripe 仪表盘里支付宝付款要过几分钟才显示「成功」？iOS 怎么应对这 5 分钟？**
A: 
- **原因**：支付宝是「延迟支付」方式。用户点击支付后，PaymentIntent 先变为 `requires_action`（需在支付宝内完成）；只有支付宝把结果回传给 Stripe 后，Stripe 才会把该 PaymentIntent 更新为 `succeeded`。这几分钟是**支付宝 ↔ Stripe** 的异步确认时间，不是 App 或后端 bug。
- **iOS 现状**：原生在收到重定向后会调用 `StripeAPI.handleURLCallback`，测试模式下 Stripe 常会很快确认，Sheet 很快回调成功。生产环境若支付宝回调慢，仍可能有一段等待。
- **Flutter 已做**：深度链接交给 `Stripe.handleURLCallback`（见上条）后，SDK 能完成流程；同时保留轮询 `payment-status`，在 Stripe 已确认但 SDK 未及时回调时也能尽快展示成功。
- **建议**：若希望 iOS 与 Flutter 一致、在 Stripe 确认后尽快展示成功，可在 iOS 支付宝/银行卡支付发起后同样轮询 `getTaskPaymentStatus`，在检测到 `payment_details.status == "succeeded"` 时主动置 `paymentSuccess = true` 并关闭等待状态。

---

## 参考文档

- [Stripe 支付宝文档](https://docs.stripe.com/payments/alipay)
- [Stripe 接受支付宝付款](https://docs.stripe.com/payments/alipay/accept-a-payment)
- [Stripe 微信支付文档](https://docs.stripe.com/payments/wechat-pay)
- [Stripe 接受微信付款](https://docs.stripe.com/payments/wechat-pay/accept-a-payment)
- [Stripe 支付方式支持地区](https://docs.stripe.com/payments/payment-methods/integration-options#payment-method-availability)
