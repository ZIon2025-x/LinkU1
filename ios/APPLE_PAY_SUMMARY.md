# Apple Pay 集成总结

根据 Stripe Apple Pay 文档，我已经为项目创建了完整的 Apple Pay 实现支持。

## 📦 创建的文件

### 1. `ApplePayHelper.swift`
**位置**：`ios/link2ur/link2ur/Utils/ApplePayHelper.swift`

**功能**：
- ✅ 检查设备是否支持 Apple Pay
- ✅ 创建 Apple Pay 支付请求
- ✅ 创建支付摘要项
- ✅ 金额转换工具（从最小货币单位转换为 Decimal）

**主要方法**：
- `isApplePaySupported()` - 检查设备支持
- `createPaymentRequest()` - 创建支付请求
- `createSummaryItems()` - 创建支付摘要项
- `decimalAmount()` - 金额转换

### 2. `ApplePayNativeView.swift`
**位置**：`ios/link2ur/link2ur/Views/Payment/ApplePayNativeView.swift`

**功能**：
- ✅ 使用原生 `STPApplePayContext` 实现 Apple Pay
- ✅ 完整的支付流程（创建 PaymentIntent → 展示支付表单 → 处理结果）
- ✅ 错误处理和用户反馈
- ✅ 支付成功/失败状态管理

**特点**：
- 使用 `STPApplePayContext` 和 `STPApplePayContextDelegate`
- 支持 async/await API（根据 Stripe iOS SDK 版本）
- 完整的错误处理

### 3. `APPLE_PAY_IMPLEMENTATION_GUIDE.md`
**位置**：`ios/APPLE_PAY_IMPLEMENTATION_GUIDE.md`

**内容**：
- ✅ 两种实现方式对比（PaymentSheet vs 原生实现）
- ✅ 快速开始指南
- ✅ 配置步骤详解
- ✅ 测试方法
- ✅ 故障排除
- ✅ 最佳实践
- ✅ 代码示例

## 🔄 当前项目状态

### 已实现的支付方式

1. **PaymentSheet 方式**（当前使用，推荐）
   - 位置：`PaymentViewModel.swift` 和 `StripePaymentView.swift`
   - 特点：简单、统一、支持多种支付方式
   - Apple Pay 已集成：✅

2. **原生实现方式**（新增，可选）
   - 位置：`ApplePayNativeView.swift`
   - 特点：完全自定义、更精细的控制
   - 状态：✅ 已创建，可根据需要启用

## 🚀 如何使用

### 方式一：继续使用 PaymentSheet（推荐）

当前项目已经通过 PaymentSheet 集成了 Apple Pay，只需确保：

1. **配置 Merchant ID**：
   ```swift
   // 在 Constants.swift 中或通过环境变量
   APPLE_PAY_MERCHANT_ID = merchant.com.link2ur
   ```

2. **在 Xcode 中启用 Apple Pay**：
   - 项目设置 → Signing & Capabilities → 添加 Apple Pay
   - 选择你的 Merchant ID

3. **在 Stripe Dashboard 中配置**：
   - 上传 Apple Pay 证书

### 方式二：使用原生实现

如果你想使用原生实现（更多自定义控制）：

```swift
ApplePayNativeView(
    taskId: taskId,
    amount: amount,
    clientSecret: clientSecret,
    taskTitle: "任务标题",
    applicantName: "申请者名称",
    onPaymentSuccess: {
        // 支付成功回调
    }
)
```

## 📋 配置检查清单

### iOS 配置
- [x] Apple Merchant ID 已注册 (`merchant.com.link2ur`)
- [x] Apple Pay 证书已创建并上传到 Stripe（有效期至 2028/2/13）
- [ ] Xcode 中已启用 Apple Pay Capability
- [ ] Merchant ID 已在代码中配置（环境变量或 Constants.swift）
- [ ] Stripe Publishable Key 已配置
- [ ] 已在真机上测试（模拟器需要特殊配置）

### Web 配置（可选，仅网页版需要）
- [ ] 支付方式域名已配置（`link2ur.com` 和 `www.link2ur.com`）
- [ ] 域名验证文件已上传
- [ ] 域名验证已完成

**详细配置状态请查看**: [APPLE_PAY_CONFIG_STATUS.md](./APPLE_PAY_CONFIG_STATUS.md)

## 🔍 关键配置

### Merchant ID 配置

**推荐方式**：使用环境变量
```
APPLE_PAY_MERCHANT_ID = merchant.com.link2ur
```

**备选方式**：直接修改 `Constants.swift`
```swift
static let applePayMerchantIdentifier: String? = "merchant.com.link2ur"
```

### 国家代码配置

根据你的业务所在国家，修改 `merchantCountryCode`：

```swift
// 在 PaymentViewModel.swift 中
configuration.applePay = .init(
    merchantId: merchantId,
    merchantCountryCode: "GB" // 修改为你的国家代码
)
```

## 📚 相关文档

- [Stripe Apple Pay 文档](https://docs.stripe.com/apple-pay)
- [Apple Pay 实现指南](./APPLE_PAY_IMPLEMENTATION_GUIDE.md)
- [Apple Pay 设置指南](./stripe-sample-code/ios/APPLE_PAY_SETUP.md)

## 💡 下一步

1. **测试 Apple Pay**：
   - 在真机上测试支付流程
   - 验证错误处理
   - 测试不同场景（成功、失败、取消）

2. **优化用户体验**：
   - 根据实际需求调整支付摘要项
   - 添加订单跟踪功能（iOS 16+）
   - 实现经常性付款（iOS 16+）

3. **生产环境准备**：
   - 使用生产环境的 Stripe 密钥
   - 使用生产环境的 Merchant ID
   - 完成 Apple Pay 证书验证

## ⚠️ 注意事项

1. **测试限制**：
   - 不能使用 Stripe 测试卡或 Apple Pay 测试卡
   - 必须使用真实卡号（Stripe 会识别测试模式）

2. **证书管理**：
   - 必须使用 Stripe 提供的 CSR 创建证书
   - 不要使用自己生成的 CSR

3. **设备支持**：
   - 始终检查设备是否支持 Apple Pay
   - 提供其他支付方式作为备选

## 🐛 常见问题

### Q: Apple Pay 按钮不显示？
A: 检查设备支持、Merchant ID 配置、Apple Pay Capability 是否启用

### Q: 支付时出现证书错误？
A: 确保使用 Stripe 提供的 CSR 创建证书，并正确上传到 Stripe

### Q: 如何测试 Apple Pay？
A: 在真机上使用真实卡号测试，Stripe 会自动识别测试模式

---

**创建时间**：2025-01-27
**Stripe iOS SDK 版本**：25.3.1
