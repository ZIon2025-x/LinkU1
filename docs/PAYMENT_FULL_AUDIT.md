# 支付功能完整检查报告

> 检查时间：2025-02
> 范围：跳蚤市场 + 任务支付、支付宝 / 微信 / 银行卡 / 优惠券、Webhook、Flutter / 后端

## 一、支付流程概览

### 1. 支付入口

| 入口 | 页面/组件 | 支付数据来源 |
|------|----------|-------------|
| 跳蚤市场直接购买 | `ApprovalPaymentPage` | `FleaMarketBloc._parseDirectPurchasePaymentData`，含 taskSource、fleaMarketItemId |
| 跳蚤市场继续支付 | `ApprovalPaymentPage` | 商品详情的 pendingPayment* 字段，含 taskSource、fleaMarketItemId |
| 任务批准支付 | `ApprovalPaymentPage` | `TaskDetailBloc` AcceptPaymentData，普通任务无 taskSource |
| 活动/专家服务 | `ApprovalPaymentPage` | 类似任务支付 |

### 2. 支付方式与后端路径

| 支付方式 | 后端创建方式 | Metadata 来源 | 商品状态更新 |
|----------|-------------|--------------|-------------|
| 银行卡 / Apple Pay | flea_market_routes direct-purchase 或 coupon_points createTaskPayment | PI 创建时写入 | ✅ payment_intent.succeeded |
| 支付宝 | coupon_points createTaskPayment (preferred_payment_method=alipay) | 请求中 task_source/flea_market_item_id 或后端推导 | ✅ payment_intent.succeeded |
| 优惠券（全额/部分） | coupon_points createTaskPayment | 同上 | ✅ payment_intent.succeeded |
| 微信支付 | coupon_points wechat-checkout | 请求中 task_source/flea_market_item_id 或后端推导 | ✅ checkout.session.completed |

## 二、已完成的修复（跳蚤市场商品状态）

### 问题

跳蚤市场支付成功后，任务状态已更新，但商品状态未更新为 sold。原因是：

- flea_market_routes 的 direct-purchase/accept-purchase 创建的 PI 已有正确 metadata
- coupon_points 路径（支付宝、优惠券、微信）创建的 PI/Checkout Session 原先缺少 `payment_type`、`flea_market_item_id`

### 修复内容

1. **后端 coupon_points_routes**
   - `TaskPaymentRequest` 增加可选字段 `task_source`、`flea_market_item_id`
   - 创建新 PaymentIntent 时：优先使用请求中的值，否则根据 `task.task_source` / `task.task_type` 推导并补齐 metadata
   - `create_wechat_checkout_session` 增加 `task_source`、`flea_market_item_id`，`_build_wechat_checkout_metadata` 中补充跳蚤市场 metadata

2. **后端 routers.py Webhook**
   - `payment_intent.succeeded`：已有 `payment_type` + `flea_market_item_id` 时更新商品为 sold、清除缓存、发送通知
   - `checkout.session.completed`：已有 `flea_market_item_id` 时同样更新商品为 sold

3. **Flutter**
   - `AcceptPaymentData` 增加 `taskSource`、`fleaMarketItemId`
   - 跳蚤市场入口构造 paymentData 时传入
   - `createTaskPayment`、`createWeChatCheckoutSession` 增加可选参数并传给后端
   - `ApprovalPaymentPage` 中支付宝、优惠券、微信支付调用时均传递上述参数

## 三、本次检查发现并修复的问题

### 1. 微信支付优惠券参数

- **问题**：Flutter 发送 `coupon_id`，后端期望 `user_coupon_id`；后端 `user_coupon_id`、`coupon_code` 未使用 `Body()`，无法从 JSON body 正确读取
- **修复**：
  - Flutter `PaymentRepository.createWeChatCheckoutSession`：请求体改为发送 `user_coupon_id`（与 createTaskPayment 一致）
  - 后端 `create_wechat_checkout_session`：为 `user_coupon_id`、`coupon_code` 增加 `Body(None)`，以便从 JSON 读取

## 四、支付全链路核对

### 1. PaymentIntent 路径（银行卡 / 支付宝 / 优惠券）

```
Flutter ApprovalPaymentPage
  → createTaskPayment(taskId, userCouponId?, preferredPaymentMethod?, taskSource?, fleaMarketItemId?)
  → POST /api/coupon-points/tasks/{id}/payment
  → coupon_points_routes.create_task_payment
  → 新建/复用 PI，metadata 含 task_id, payment_type?, flea_market_item_id?
  → Stripe payment_intent.succeeded Webhook
  → 若有 flea_market_item_id：更新 FleaMarketItem.status=sold
```

### 2. Checkout Session 路径（微信支付）

```
Flutter ApprovalPaymentPage
  → createWeChatCheckoutSession(taskId, couponId?, taskSource?, fleaMarketItemId?)
  → POST /api/coupon-points/tasks/{id}/wechat-checkout
  → coupon_points_routes.create_wechat_checkout_session
  → _build_wechat_checkout_metadata 含 flea_market_item_id
  → Stripe checkout.session.completed Webhook
  → 若有 flea_market_item_id：更新 FleaMarketItem.status=sold
```

### 3. 直接购买（银行卡 / Apple Pay，跳蚤市场）

```
Flutter FleaMarketBloc.directPurchase
  → POST /api/flea-market/items/{id}/direct-purchase
  → flea_market_routes.direct_purchase_item
  → 创建 PI，metadata 含 payment_type=flea_market_direct_purchase, flea_market_item_id
  → 返回 client_secret → ApprovalPaymentPage 使用 PaymentSheet
  → Stripe payment_intent.succeeded Webhook
  → 更新 FleaMarketItem.status=sold
```

## 五、兼容性与回退逻辑

- 所有新增字段均为可选
- 后端在未传 `task_source` / `flea_market_item_id` 时，根据任务类型和 `sold_task_id` 查询 FleaMarketItem 并推导
- 与 iOS 行为对齐：iOS 使用 `user_coupon_id`，Flutter 现改为相同字段名

## 六、注意事项

1. **PaymentView**：项目中存在 `PaymentView`（独立于 ApprovalPaymentPage），当前路由中似乎未直接使用；实际支付统一走 `ApprovalPaymentPage`。
2. **任务来源**：跳蚤市场使用 `task_source = "flea_market"`，与 `task_type`（如 `Second-hand & Rental`）区分。
3. **优惠券**：创建支付时使用 `user_coupon_id`（UserCoupon.id），与 createTaskPayment 和 iOS 保持一致。
