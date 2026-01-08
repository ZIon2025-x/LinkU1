# Stripe Connect 自定义 UI 实现

## 概述

由于 Stripe iOS SDK 中的 `createPaymentsViewController()` 和 `createPayoutsViewController()` 是 `@_spi` 保护的 API，无法直接使用，我们改为直接请求后端数据并创建自定义 UI 来显示支付记录和提现记录。

## 实现方案

### 1. 后端 API

使用现有的 `/api/stripe/connect/account/transactions` 端点，该端点返回所有交易记录（包括支付和提现）。

**端点**: `GET /api/stripe/connect/account/transactions?limit=100`

**响应格式**:
```json
{
  "transactions": [
    {
      "id": "tr_xxx",
      "type": "income",  // 或 "expense"
      "amount": 100.00,
      "currency": "GBP",
      "description": "任务标题 - 收入",
      "status": "succeeded",
      "created": 1234567890,
      "created_at": "2024-01-01T00:00:00Z",
      "source": "transfer",  // 或 "charge", "payout", "payment_intent"
      "metadata": {}
    }
  ],
  "total": 10,
  "has_more": false
}
```

### 2. iOS 实现

#### 文件结构

- **`StripeConnectPaymentsView.swift`**: 支付记录视图
  - 显示所有 `type == "income"` 的交易记录
  - 自定义的列表 UI，参考了 `CouponPointsView` 的设计

- **`StripeConnectPayoutsView.swift`**: 提现记录视图
  - 显示所有 `type == "expense"` 的交易记录
  - 自定义的列表 UI，专门用于显示提现记录

#### 核心功能

1. **数据获取**
   - 使用 `APIService` 调用后端 API
   - 自动处理加载状态和错误
   - 支持下拉刷新

2. **UI 组件**
   - `TransactionRowView`: 支付记录行视图
   - `PayoutTransactionRowView`: 提现记录行视图
   - 状态标签（成功、处理中、失败等）
   - 金额格式化（支持多币种）
   - 时间格式化（中文本地化）

3. **状态管理**
   - 使用 `@StateObject` 和 `ObservableObject`
   - 自动处理加载、错误和空状态

### 3. 数据模型

```swift
struct StripeConnectTransaction: Identifiable, Codable {
    let id: String
    let type: String // "income" 或 "expense"
    let amount: Double
    let currency: String
    let description: String
    let status: String
    let created: Int // Unix 时间戳
    let createdAt: String // ISO 格式时间
    let source: String // "charge", "transfer", "payout", "payment_intent"
    let metadata: [String: String]?
}
```

## 使用方式

### 支付记录

```swift
NavigationLink(destination: StripeConnectPaymentsView()) {
    Text("支付记录")
}
```

### 提现记录

```swift
NavigationLink(destination: StripeConnectPayoutsView()) {
    Text("提现管理")
}
```

## UI 特性

### 支付记录视图

- ✅ 显示所有收入类型的交易
- ✅ 状态标签：成功、处理中、失败、已撤销
- ✅ 金额显示：带货币符号，收入显示 "+" 前缀
- ✅ 时间显示：中文本地化格式
- ✅ 下拉刷新支持
- ✅ 空状态提示

### 提现记录视图

- ✅ 显示所有支出类型的交易
- ✅ 状态标签：已到账、处理中、转账中、已取消、失败
- ✅ 金额显示：带货币符号
- ✅ 时间显示：中文本地化格式
- ✅ 下拉刷新支持
- ✅ 空状态提示

## 优势

1. **完全控制 UI**：可以自定义所有样式和交互
2. **无需依赖 SDK**：不依赖 Stripe iOS SDK 的 `@_spi` 保护 API
3. **更好的用户体验**：可以添加更多自定义功能（如筛选、搜索等）
4. **易于维护**：代码结构清晰，易于扩展

## 未来扩展

可以添加以下功能：

1. **筛选功能**：按状态、日期、金额筛选
2. **搜索功能**：搜索交易描述
3. **详情页面**：点击查看交易详情
4. **导出功能**：导出交易记录为 CSV
5. **分页加载**：支持加载更多记录

## 注意事项

- 确保后端 API `/api/stripe/connect/account/transactions` 正常工作
- 需要用户已完成 Stripe Connect 账户入驻
- 交易记录按时间倒序排列（最新的在前）

