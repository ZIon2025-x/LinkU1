# 微信支付（Stripe WeChat Pay）接入说明

## 概述

项目已通过 Stripe API 支持微信支付。微信支付为数字钱包支付方式，面向中国消费者、海外华人及中国游客；用户需在微信 App 内完成确认，不支持争议流程。

## 已实现内容

### 后端
- 在所有创建 PaymentIntent 的接口中已包含 `wechat_pay`（与 card、alipay 并列）：
  - `coupon_points_routes.py`（任务支付/优惠券）
  - `task_chat_routes.py`
  - `task_expert_routes.py`
  - `flea_market_routes.py`
  - `multi_participant_routes.py`

### iOS
- `PaymentMethodType` 枚举已包含 `wechatPay`，图标使用 Asset `WeChatLogo`。
- 支付方式选择卡片中已显示「微信支付」选项。
- 「使用微信支付」绿色按钮及 PaymentSheet 流程已接入。
- 本地化：简体/繁体/英文已配置「使用微信支付」文案。
- URL 处理：`link2ur://stripe-redirect` 用于支付完成后返回 App。

### 前端 Web
- 使用 Stripe PaymentElement / Checkout 时，若后端 PaymentIntent 包含 `wechat_pay`，Stripe 会自动展示微信支付选项；`return_url` 已在前端传入，支持重定向返回。

## Stripe 微信支付要求

### 支付方式属性
- **客户所在地**：中国消费者、海外华人、中国游客
- **出示货币**：CNY, AUD, CAD, EUR, GBP, HKD, JPY, SGD, USD, DKK, NOK, SEK, CHF（依业务所在地）
- **支付确认**：客户在微信内发起
- **经常性付款**：否
- **争议支持**：否（用户在微信内确认，无 chargeback 流程）
- **手动捕获**：否
- **退款/部分退款**：支持，原始付款后 **180 天内**可提交退款；退款为异步，需监听 `refund.updated` / `refund.failed` webhook

### 支持的国家/地区（Stripe 账户）
AT, AU, BE, CA, CH, DE, DK, ES, FI, FR, GB, HK, IE, IT, JP, LU, NL, NO, PT, SE, SG, US

### 支持的货币（按国家/地区）
| 货币 | 国家/地区 |
|------|-----------|
| cny | 所有国家 |
| aud | 澳大利亚 |
| cad | 加拿大 |
| eur | 奥地利、比利时、丹麦、芬兰、法国、德国、爱尔兰、意大利、卢森堡、荷兰、挪威、葡萄牙、西班牙、瑞典、瑞士 |
| gbp | 英国 |
| hkd | 香港 |
| jpy | 日本 |
| sgd | 新加坡 |
| usd | 美国 |
| dkk, nok, sek, chf | 丹麦、挪威、瑞典、瑞士 |

### 产品支持
- PaymentSheet（iOS 使用）
- Checkout（不支持订阅模式/设置模式）
- Payment Links、Elements、Invoicing
- Express Checkout Element 与 Mobile Payment Element **不支持** 微信支付

### Connect
- 标准 Dashboard 的 Connect 子账户可在 Dashboard 内自行启用 WeChat Pay。
- 无标准 Dashboard 的 Connect 子账户需平台向 Stripe 申请 `wechat_pay_payments` capability（私密预览）。

## 使用前检查

1. **Stripe Dashboard**：Settings → Payment methods → 启用 **WeChat Pay**，状态为 Active。
2. **账户地区**：确认 Stripe 账户所在国家在上表支持列表中（如英国 GB）。
3. **货币**：当前项目使用 GBP 等，均在微信支付支持范围内。

## 测试建议

- **iOS**：选择「微信支付」→ 点击「使用微信支付」→ PaymentSheet 弹出后可选微信支付，跳转微信完成支付，通过 `link2ur://stripe-redirect` 返回 App。
- **Web**：支付页由 Stripe 自动展示微信支付（若后端包含 `wechat_pay`），完成跳转与 return_url 返回后确认支付结果。

## 参考

- [Stripe 微信支付文档](https://docs.stripe.com/payments/wechat-pay)
- [Stripe 接受微信支付付款](https://docs.stripe.com/payments/wechat-pay/accept-a-payment)
- [价格详情（本地支付方式）](https://stripe.com/pricing/local-payment-methods)
