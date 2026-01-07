# iOS 和 Web 付款流程对比

## ✅ 核心流程一致性

iOS 和 Web 的付款流程**基本一致**，都使用相同的后端 API 和 Stripe Payment Intent 模式。

## 📊 流程对比

### 1. API 端点

| 平台 | API 端点 | 方法 |
|------|---------|------|
| iOS | `/api/coupon-points/tasks/{taskId}/payment` | POST |
| Web | `/api/coupon-points/tasks/{taskId}/payment` | POST |

**✅ 完全一致**

### 2. 请求参数

| 参数 | iOS | Web | 说明 |
|------|-----|-----|------|
| `payment_method` | ✅ | ✅ | 支付方式（"stripe"） |
| `points_amount` | ✅ | ✅ | 积分金额（可选） |
| `coupon_code` | ✅ | ✅ | 优惠券代码（可选） |

**✅ 完全一致**

### 3. 响应数据

| 字段 | iOS | Web | 说明 |
|------|-----|-----|------|
| `client_secret` | ✅ | ✅ | Payment Intent 客户端密钥 |
| `payment_intent_id` | ✅ | ✅ | Payment Intent ID |
| `final_amount` | ✅ | ✅ | 最终支付金额 |
| `points_used` | ✅ | ✅ | 使用的积分 |
| `coupon_discount` | ✅ | ✅ | 优惠券折扣 |

**✅ 完全一致**

### 4. 支付确认方式

| 平台 | 使用组件 | 确认方法 |
|------|---------|----------|
| iOS | `PaymentSheet` | `paymentSheet.present()` |
| Web | `PaymentElement` | `stripe.confirmPayment()` |

**⚠️ UI 组件不同，但功能一致**

- iOS 使用 Stripe 原生 `PaymentSheet`（原生 UI）
- Web 使用 Stripe Elements `PaymentElement`（Web UI）
- 两者都支持相同的支付方式（Card、Apple Pay、Google Pay 等）

### 5. 支付结果处理

| 平台 | 成功处理 | 失败处理 | 取消处理 |
|------|---------|---------|---------|
| iOS | `PaymentSheetResult.completed` | `PaymentSheetResult.failed` | `PaymentSheetResult.canceled` |
| Web | `paymentIntent.status === 'succeeded'` | `confirmError` | 用户关闭弹窗 |

**✅ 逻辑一致**

### 6. Webhook 处理

| 平台 | Webhook 事件 | 处理方式 |
|------|-------------|---------|
| iOS | `payment_intent.succeeded` | 后端统一处理 |
| Web | `payment_intent.succeeded` | 后端统一处理 |

**✅ 完全一致**

- 两者都依赖后端 Webhook 更新任务状态
- iOS 和 Web 都不直接更新数据库，只创建 Payment Intent

## 🔄 完整流程对比

### iOS 流程

```
1. 用户点击支付
   ↓
2. PaymentViewModel.createPaymentIntent()
   ↓
3. POST /api/coupon-points/tasks/{taskId}/payment
   ↓
4. 获取 client_secret
   ↓
5. 创建 PaymentSheet(clientSecret)
   ↓
6. 展示 PaymentSheet UI
   ↓
7. 用户完成支付
   ↓
8. PaymentSheetResult.completed
   ↓
9. 等待 Webhook 更新任务状态
   ↓
10. 显示支付成功
```

### Web 流程

```
1. 用户点击支付
   ↓
2. 调用创建支付 API
   ↓
3. POST /api/coupon-points/tasks/{taskId}/payment
   ↓
4. 获取 client_secret
   ↓
5. 创建 Stripe Elements (PaymentElement)
   ↓
6. 展示 PaymentElement UI
   ↓
7. 用户完成支付
   ↓
8. stripe.confirmPayment()
   ↓
9. paymentIntent.status === 'succeeded'
   ↓
10. 等待 Webhook 更新任务状态（或轮询）
   ↓
11. 显示支付成功
```

**✅ 核心流程完全一致，只是 UI 组件不同**

## 🎯 功能特性对比

| 功能 | iOS | Web | 状态 |
|------|-----|-----|------|
| Payment Intent | ✅ | ✅ | 一致 |
| 积分抵扣 | ✅ | ✅ | 一致 |
| 优惠券 | ✅ | ✅ | 一致 |
| Apple Pay | ✅ | ✅ | 一致（iOS 原生支持更好） |
| Google Pay | ✅ | ✅ | 一致 |
| 3D Secure | ✅ | ✅ | 一致（自动处理） |
| Webhook 更新 | ✅ | ✅ | 一致 |
| 错误处理 | ✅ | ✅ | 一致 |

## 📝 代码位置

### iOS

- **ViewModel**: `ios/link2ur/link2ur/ViewModels/PaymentViewModel.swift`
- **View**: `ios/link2ur/link2ur/Views/Payment/StripePaymentView.swift`
- **API 端点**: `ios/link2ur/link2ur/Services/APIEndpoints.swift`

### Web

- **页面**: `frontend/src/pages/TaskPayment.tsx`
- **组件**: `frontend/src/components/payment/StripePaymentForm.tsx`
- **API 调用**: 直接使用 `api.post()`

## 🔍 细微差异

### 1. UI 展示方式

- **iOS**: 使用原生 `PaymentSheet`，全屏模态展示
- **Web**: 使用 `PaymentElement`，嵌入在页面中

### 2. 状态轮询

- **iOS**: 不轮询，直接等待 Webhook（更简洁）
- **Web**: 可选轮询作为备选方案（更保险）

### 3. 错误提示

- **iOS**: 使用 SwiftUI Alert
- **Web**: 使用 Ant Design Message

## ✅ 总结

**iOS 和 Web 的付款流程基本一致**：

1. ✅ 使用相同的后端 API
2. ✅ 使用相同的 Payment Intent 模式
3. ✅ 支持相同的功能（积分、优惠券）
4. ✅ 相同的 Webhook 处理逻辑
5. ✅ 相同的错误处理方式

**主要区别**：
- UI 组件不同（原生 vs Web）
- 状态轮询策略略有不同（Web 有备选轮询）

**结论**：核心业务逻辑完全一致，只是平台特定的 UI 实现不同。这符合跨平台开发的最佳实践。

