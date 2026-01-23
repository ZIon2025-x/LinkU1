# 跳蚤市场购买功能 - 后端API适配检查报告

生成时间：2025年1月

## 📋 检查概览

本次检查针对跳蚤市场购买功能的前后端适配情况，重点关注：
- API端点是否正确
- 请求参数是否匹配
- 响应数据结构是否完整
- 状态更新逻辑是否合理
- 是否需要优化

---

## ✅ 前端API调用分析

### 1. 直接购买 API

**端点**：`POST /api/flea-market/items/{itemId}/direct-purchase`

**请求参数**：
```swift
// 前端发送空body
body: [:]
```

**响应数据结构**（前端期望）：
```swift
struct DirectPurchaseResponse: Decodable {
    let success: Bool
    let data: DirectPurchaseData
    let message: String?
    
    struct DirectPurchaseData: Decodable {
        let taskId: String              // 任务ID（字符串格式）
        let itemStatus: String          // 商品状态
        let taskStatus: String          // 任务状态（期望 "pending_payment"）
        let paymentIntentId: String?    // Stripe支付意图ID
        let clientSecret: String?       // Stripe client_secret（必需，用于支付）
        let amount: Int?                // 支付金额（便士）
        let amountDisplay: String?      // 支付金额显示
        let currency: String?           // 货币
        let customerId: String?         // Stripe客户ID
        let ephemeralKeySecret: String? // Stripe临时密钥
    }
}
```

**前端使用逻辑**：
- 检查 `taskStatus == "pending_payment"`
- 检查 `taskId` 和 `clientSecret` 是否存在
- 如果存在，显示支付页面
- 如果不存在，只关闭购买弹窗

**后端需要确保**：
- ✅ 返回正确的响应结构
- ✅ `taskStatus` 必须为 `"pending_payment"`（如果需要支付）
- ✅ `clientSecret` 必须存在（如果需要支付）
- ✅ `taskId` 必须存在且为字符串格式

---

### 2. 议价购买请求 API

**端点**：`POST /api/flea-market/items/{itemId}/purchase-request`

**请求参数**：
```swift
{
    "proposed_price": Double?,  // 议价金额（可选）
    "message": String?          // 留言（可选）
}
```

**响应数据结构**（前端期望）：
```swift
struct PurchaseRequest: Codable {
    let id: Int
    let itemId: String
    let buyerId: String
    let proposedPrice: Double?
    let message: String?
    let status: String
    let createdAt: String
}
```

**前端使用逻辑**：
- 发送议价请求后，只检查请求是否成功
- 不处理响应数据（只检查是否有错误）
- 显示成功提示

**后端需要确保**：
- ✅ 返回正确的响应结构
- ✅ 创建购买请求记录
- ✅ 发送推送通知给卖家（建议）

---

### 3. 商品详情 API

**端点**：`GET /api/flea-market/items/{itemId}`

**响应数据结构**（前端期望）：
```swift
struct FleaMarketItem: Codable {
    let id: String
    let title: String
    let description: String?
    let price: Double
    let currency: String
    let category: String
    let images: [String]?
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let sellerId: String
    let seller: User?
    let status: String              // 必需：active, sold, delisted
    let viewCount: Int
    let favoriteCount: Int
    let refreshedAt: String?
    let createdAt: String
    let updatedAt: String?
    let daysUntilAutoDelist: Int?
    
    // 未付款购买信息（仅当当前用户有未付款的购买时返回）
    let pendingPaymentTaskId: Int?
    let pendingPaymentClientSecret: String?
    let pendingPaymentAmount: Int?
    let pendingPaymentAmountDisplay: String?
    let pendingPaymentCurrency: String?
    let pendingPaymentCustomerId: String?
    let pendingPaymentEphemeralKeySecret: String?
}
```

**前端使用逻辑**：
- 根据 `status` 显示不同的状态标签
- 如果 `status != "active"`，不显示购买按钮
- 如果有 `pendingPaymentTaskId` 和 `pendingPaymentClientSecret`，显示"继续支付"按钮

**后端需要确保**：
- ✅ 返回正确的商品状态（`active`, `sold`, `delisted`）
- ✅ 支付成功后更新商品状态为 `sold` 或 `delisted`
- ✅ 如果有未付款的购买，返回 `pendingPaymentTaskId` 和 `pendingPaymentClientSecret`

---

## ⚠️ 后端需要适配的关键点

### 1. 直接购买响应结构

**问题**：前端期望 `taskId` 为 `String` 类型，但实际可能是 `Int`

**当前代码**：
```swift
let taskId = Int(data.taskId)  // 需要转换
```

**建议**：
- 后端统一返回 `taskId` 为字符串格式，或
- 前端修改为支持两种类型

**优先级**：中

---

### 2. 支付成功后的状态更新

**问题**：前端在支付成功后会重试刷新商品状态（最多5次），但需要后端及时更新状态

**前端逻辑**：
- 支付成功后等待2秒开始第一次刷新
- 使用指数退避策略（1秒、4秒、9秒...最多5秒）
- 最多重试5次
- 检查 `status == "sold"` 或 `status == "delisted"`

**后端需要确保**：
- ✅ 支付成功后（webhook处理完成）立即更新商品状态
- ✅ 状态更新应在5秒内完成（建议2秒内）
- ✅ 状态更新为 `sold` 或 `delisted`

**优先级**：高

---

### 3. 议价购买流程

**问题**：前端发送议价请求后，需要后端处理卖家同意逻辑

**前端流程**：
1. 买家发送议价请求 → `POST /api/flea-market/items/{itemId}/purchase-request`
2. 显示成功提示
3. 等待卖家同意（通过推送通知）

**后端需要实现**：
- ✅ 卖家同意议价的API端点（建议：`POST /api/flea-market/purchase-requests/{requestId}/approve`）
- ✅ 卖家同意后创建支付任务
- ✅ 发送推送通知给买家
- ✅ 返回支付信息（类似直接购买的响应）

**优先级**：高

---

### 4. 推送通知支持

**需要的推送通知类型**：

1. **买家发送议价请求** → 通知卖家
   - 类型：`flea_market_purchase_request`
   - 数据：`{item_id, buyer_id, proposed_price, message}`

2. **卖家同意议价** → 通知买家
   - 类型：`flea_market_purchase_accepted`
   - 数据：`{item_id, task_id, client_secret, amount}`

3. **支付提醒** → 通知买家
   - 类型：`flea_market_pending_payment`
   - 数据：`{item_id, task_id, amount}`

**优先级**：中

---

## 🔍 详细检查项

### API端点检查

| 端点 | 方法 | 状态 | 说明 |
|------|------|------|------|
| `/api/flea-market/items/{itemId}/direct-purchase` | POST | ✅ 已使用 | 直接购买 |
| `/api/flea-market/items/{itemId}/purchase-request` | POST | ✅ 已使用 | 议价请求 |
| `/api/flea-market/items/{itemId}` | GET | ✅ 已使用 | 商品详情 |
| `/api/flea-market/purchase-requests/{requestId}/approve` | POST | ⚠️ 未找到 | 卖家同意议价（需要实现） |
| `/api/flea-market/purchase-requests/{requestId}/reject` | POST | ⚠️ 未找到 | 卖家拒绝议价（可选） |

### 响应数据结构检查

#### DirectPurchaseResponse ✅

**必需字段**：
- ✅ `success: Bool`
- ✅ `data: DirectPurchaseData`
- ✅ `data.taskId: String`
- ✅ `data.taskStatus: String`（应为 `"pending_payment"`）
- ✅ `data.clientSecret: String?`（支付时需要）

**可选字段**：
- ✅ `message: String?`
- ✅ `data.paymentIntentId: String?`
- ✅ `data.amount: Int?`
- ✅ `data.amountDisplay: String?`
- ✅ `data.currency: String?`
- ✅ `data.customerId: String?`
- ✅ `data.ephemeralKeySecret: String?`

#### PurchaseRequest ✅

**必需字段**：
- ✅ `id: Int`
- ✅ `itemId: String`
- ✅ `buyerId: String`
- ✅ `status: String`
- ✅ `createdAt: String`

**可选字段**：
- ✅ `proposedPrice: Double?`
- ✅ `message: String?`

#### FleaMarketItem ✅

**必需字段**：
- ✅ `id: String`
- ✅ `title: String`
- ✅ `price: Double`
- ✅ `currency: String`
- ✅ `category: String`
- ✅ `sellerId: String`
- ✅ `status: String`（`active`, `sold`, `delisted`）
- ✅ `viewCount: Int`
- ✅ `createdAt: String`

**可选字段**：
- ✅ `description: String?`
- ✅ `images: [String]?`
- ✅ `location: String?`
- ✅ `latitude: Double?`
- ✅ `longitude: Double?`
- ✅ `seller: User?`
- ✅ `favoriteCount: Int`
- ✅ `refreshedAt: String?`
- ✅ `updatedAt: String?`
- ✅ `daysUntilAutoDelist: Int?`
- ✅ `pendingPaymentTaskId: Int?`
- ✅ `pendingPaymentClientSecret: String?`
- ✅ `pendingPaymentAmount: Int?`
- ✅ `pendingPaymentAmountDisplay: String?`
- ✅ `pendingPaymentCurrency: String?`
- ✅ `pendingPaymentCustomerId: String?`
- ✅ `pendingPaymentEphemeralKeySecret: String?`

---

## 🚨 潜在问题

### 1. taskId 类型不一致 ⚠️

**问题**：
- `DirectPurchaseResponse.DirectPurchaseData.taskId` 是 `String`
- 但前端使用时需要转换为 `Int`：`let taskId = Int(data.taskId)`

**风险**：
- 如果 `taskId` 无法转换为 `Int`，会导致支付页面无法显示

**建议**：
- 后端统一返回 `taskId` 为字符串格式（推荐）
- 或前端修改为支持字符串格式的 `taskId`

**优先级**：中

---

### 2. 支付成功后状态更新延迟 ⚠️

**问题**：
- 前端在支付成功后会重试刷新商品状态（最多5次）
- 如果后端处理延迟超过25秒，状态可能不会更新

**建议**：
- 后端在支付成功后（webhook处理完成）立即更新商品状态
- 建议在2秒内完成状态更新

**优先级**：高

---

### 3. 议价流程不完整 ⚠️

**问题**：
- 前端发送议价请求后，没有找到卖家同意议价的API端点
- 需要后端实现卖家同意逻辑

**建议**：
- 实现 `POST /api/flea-market/purchase-requests/{requestId}/approve` 端点
- 卖家同意后创建支付任务
- 返回支付信息（类似直接购买的响应）
- 发送推送通知给买家

**优先级**：高

---

### 4. 错误处理不完善 ⚠️

**问题**：
- 前端对API错误的处理比较简单
- 没有详细的错误信息显示

**建议**：
- 后端返回详细的错误信息
- 前端优化错误提示

**优先级**：低

---

## 📝 后端需要实现的API

### 1. 卖家同意议价 ⚠️ 需要实现

**端点**：`POST /api/flea-market/purchase-requests/{requestId}/approve`

**请求参数**：
```json
{
    // 可能不需要参数，或需要确认信息
}
```

**响应数据结构**（建议）：
```json
{
    "success": true,
    "data": {
        "task_id": "123",
        "item_status": "pending_payment",
        "task_status": "pending_payment",
        "client_secret": "pi_xxx_secret_xxx",
        "amount": 10000,
        "amount_display": "100.00",
        "currency": "gbp",
        "customer_id": "cus_xxx",
        "ephemeral_key_secret": "ek_xxx"
    },
    "message": "议价已同意，请完成支付"
}
```

**功能**：
- 卖家同意议价请求
- 创建支付任务
- 返回支付信息
- 发送推送通知给买家

---

### 2. 卖家拒绝议价（可选）⚠️

**端点**：`POST /api/flea-market/purchase-requests/{requestId}/reject`

**请求参数**：
```json
{
    "reason": "价格太低"  // 可选
}
```

**响应数据结构**：
```json
{
    "success": true,
    "message": "已拒绝议价请求"
}
```

**功能**：
- 卖家拒绝议价请求
- 更新购买请求状态
- 发送推送通知给买家

---

## ✅ 优化建议

### 1. 统一 taskId 类型

**建议**：
- 后端统一返回 `taskId` 为字符串格式
- 前端修改为直接使用字符串格式（不需要转换）

**优先级**：中

---

### 2. 优化状态更新逻辑

**建议**：
- 后端在支付成功后立即更新商品状态
- 使用数据库事务确保状态更新和支付记录的一致性
- 建议在2秒内完成状态更新

**优先级**：高

---

### 3. 添加推送通知

**建议**：
- 实现以下推送通知：
  - 买家发送议价请求 → 通知卖家
  - 卖家同意议价 → 通知买家
  - 卖家拒绝议价 → 通知买家
  - 支付提醒 → 通知买家

**优先级**：中

---

### 4. 优化错误处理

**建议**：
- 后端返回详细的错误信息
- 前端优化错误提示，显示用户友好的错误信息

**优先级**：低

---

## 📊 适配状态总结

### ✅ 已适配

- ✅ 直接购买API端点
- ✅ 议价请求API端点
- ✅ 商品详情API端点
- ✅ 响应数据结构基本完整
- ✅ 支付流程基本完整

### ⚠️ 需要适配

- ⚠️ 卖家同意议价API端点（需要实现）
- ⚠️ 支付成功后状态更新（需要优化）
- ⚠️ 推送通知支持（需要实现）
- ⚠️ taskId类型统一（建议优化）

### 🔴 高优先级

1. **实现卖家同意议价API**
   - 端点：`POST /api/flea-market/purchase-requests/{requestId}/approve`
   - 功能：创建支付任务，返回支付信息

2. **优化支付成功后状态更新**
   - 确保在2秒内完成状态更新
   - 状态更新为 `sold` 或 `delisted`

### 🟡 中优先级

3. **统一taskId类型**
   - 建议统一为字符串格式

4. **添加推送通知**
   - 实现议价相关的推送通知

### 🟢 低优先级

5. **优化错误处理**
   - 返回详细的错误信息

---

## 🔗 相关文件

- `ios/link2ur/link2ur/ViewModels/FleaMarketViewModel.swift` - ViewModel
- `ios/link2ur/link2ur/Models/FleaMarket.swift` - 数据模型
- `ios/link2ur/link2ur/Views/FleaMarket/FleaMarketDetailView.swift` - 商品详情页
- `ios/link2ur/link2ur/Services/APIEndpoints.swift` - API端点定义

---

## 📝 总结

### 适配情况

**基本适配**：✅ 大部分API已适配，基本功能可以正常工作

**需要优化**：⚠️ 部分功能需要后端配合实现或优化

### 关键问题

1. **卖家同意议价API** - 需要实现
2. **支付成功后状态更新** - 需要优化（确保及时更新）
3. **推送通知** - 需要实现（提升用户体验）

### 建议

1. **立即实施**（高优先级）：
   - 实现卖家同意议价API
   - 优化支付成功后状态更新逻辑

2. **近期实施**（中优先级）：
   - 统一taskId类型
   - 添加推送通知支持

3. **长期优化**（低优先级）：
   - 优化错误处理
   - 添加更多功能（如卖家拒绝议价）
