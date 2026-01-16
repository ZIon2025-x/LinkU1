# Apple Pay 实现指南

本指南说明项目中 Apple Pay 的两种实现方式及其使用场景。

## 📋 两种实现方式对比

### 方式一：使用 PaymentSheet（当前实现，推荐）

**位置**：`PaymentViewModel.swift` 和 `StripePaymentView.swift`

**特点**：
- ✅ 实现简单，代码量少
- ✅ Stripe 自动处理所有支付方式（包括 Apple Pay）
- ✅ 统一的支付界面，用户体验一致
- ✅ 自动支持多种支付方式切换
- ✅ 维护成本低

**实现代码**：
```swift
// 在 PaymentViewModel.swift 中
if let merchantId = Constants.Stripe.applePayMerchantIdentifier {
    configuration.applePay = .init(
        merchantId: merchantId,
        merchantCountryCode: "GB"
    )
}
```

**使用场景**：
- 需要支持多种支付方式（信用卡、Apple Pay、Google Pay 等）
- 希望使用 Stripe 的统一支付界面
- 快速集成，减少开发时间

---

### 方式二：使用 STPApplePayContext（原生实现）

**位置**：`ApplePayNativeView.swift` 和 `ApplePayNativeViewModel.swift`

**特点**：
- ✅ 完全自定义的 Apple Pay 体验
- ✅ 可以自定义支付摘要项
- ✅ 更精细的控制支付流程
- ✅ 可以添加订单跟踪等功能
- ⚠️ 实现更复杂
- ⚠️ 需要单独处理 Apple Pay 逻辑

**使用场景**：
- 只需要 Apple Pay 一种支付方式
- 需要自定义支付摘要项（如显示商品明细、税费等）
- 需要实现订单跟踪功能
- 需要更精细的控制支付流程

---

## 🚀 快速开始

### 使用 PaymentSheet（推荐）

当前项目已经实现了这种方式，只需确保：

1. **配置 Merchant ID**：
   - 在 `Constants.swift` 中配置 `applePayMerchantIdentifier`
   - 或通过环境变量 `APPLE_PAY_MERCHANT_ID` 配置

2. **在 Xcode 中启用 Apple Pay**：
   - 项目设置 → Signing & Capabilities → 添加 Apple Pay
   - 选择你的 Merchant ID

3. **在 Stripe Dashboard 中配置**：
   - 上传 Apple Pay 证书（从 Stripe Dashboard 下载 CSR）

### 使用原生实现

如果你想使用原生实现：

1. **导入必要的框架**：
   ```swift
   import StripeApplePay
   import PassKit
   ```

2. **使用 ApplePayNativeView**：
   ```swift
   ApplePayNativeView(
       taskId: taskId,
       amount: amount,
       clientSecret: clientSecret,
       onPaymentSuccess: {
           // 支付成功回调
       }
   )
   ```

3. **检查设备支持**：
   ```swift
   if ApplePayHelper.isApplePaySupported() {
       // 显示 Apple Pay 按钮
   }
   ```

---

## 🔧 配置步骤

### 1. 注册 Apple Merchant ID

1. 访问 [Apple Developer](https://developer.apple.com/account/)
2. 进入 **Certificates, Identifiers & Profiles**
3. 选择 **Identifiers** → 点击 **+**
4. 选择 **Merchant IDs** → **Continue**
5. 填写信息：
   - **Description**：Link²Ur Payments
   - **Identifier**：`merchant.com.link2ur`（格式：`merchant.` + 你的域名）
6. 点击 **Register**

### 2. 创建 Apple Pay 证书

1. 访问 [Stripe Dashboard](https://dashboard.stripe.com/settings/ios_certificates)
2. 点击 **添加新应用程序**
3. 下载 CSR 文件
4. 在 Apple Developer 中创建证书：
   - 使用 Stripe 提供的 CSR
   - 下载证书（不需要上传到 Stripe，Stripe 会自动处理）

**✅ 当前状态**：证书已配置完成
- Merchant ID: `merchant.com.link2ur`
- 证书有效期: 2026/1/14 - 2028/2/13
- 详细状态请查看: [APPLE_PAY_CONFIG_STATUS.md](./APPLE_PAY_CONFIG_STATUS.md)

### 3. 在 Xcode 中配置

1. 打开项目设置
2. 选择 **Signing & Capabilities** 标签
3. 点击 **+ Capability** → 添加 **Apple Pay**
4. 在 **Merchant IDs** 中选择你的 Merchant ID

### 4. 在代码中配置

**方式一：环境变量（推荐）**
```
APPLE_PAY_MERCHANT_ID = merchant.com.link2ur
```

**方式二：直接修改 Constants.swift**
```swift
static let applePayMerchantIdentifier: String? = "merchant.com.link2ur"
```

### 5. 配置 Web 域名（可选，仅网页版需要）

如果需要在网页版使用 Apple Pay：

1. 访问 [Stripe Dashboard - 支付方式域名页面](https://dashboard.stripe.com/settings/payment_method_domains)
2. 点击 **添加域名** 或使用 API：
   ```bash
   curl https://api.stripe.com/v1/payment_method_domains \
     -u "<<YOUR_SECRET_KEY>>:" \
     -d domain_name="link2ur.com"
   ```
3. 上传验证文件到服务器并完成验证

**注意**：
- iOS 应用使用 Apple Pay **不需要**配置 Web 域名
- 只有网页版（Safari、Chrome 等）才需要配置 Web 域名
- `www` 是子域名，需要单独注册（例如：`www.link2ur.com`）

---

## 📱 测试 Apple Pay

### 在模拟器中测试

1. 打开 **Settings** → **Wallet & Apple Pay**
2. 添加测试卡（使用真实卡号，Stripe 会识别测试模式）
3. 运行应用，尝试支付
4. 应该能看到 Apple Pay 选项

**注意**：不能使用 Stripe 测试卡或 Apple Pay 测试卡，必须使用真实卡号。

### 在真机上测试

1. 确保设备已登录 Apple ID
2. 在 **Settings** → **Wallet & Apple Pay** 中添加支付卡
3. 运行应用，尝试支付
4. 使用 Touch ID 或 Face ID 完成支付

---

## 🌍 国家代码配置

根据你的业务所在国家，修改 `merchantCountryCode`：

| 国家 | 代码 |
|------|------|
| 英国 | GB |
| 美国 | US |
| 中国 | CN |
| 加拿大 | CA |
| 澳大利亚 | AU |
| 日本 | JP |
| 德国 | DE |
| 法国 | FR |

完整列表：https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2

---

## 🔍 故障排除

### 问题：Apple Pay 按钮不显示

**可能原因**：
1. 设备不支持 Apple Pay
2. 用户未添加支付卡
3. Merchant ID 未配置
4. Apple Pay Capability 未启用

**解决方法**：
1. 检查 `ApplePayHelper.isApplePaySupported()` 返回值
2. 确保在 Xcode 中启用了 Apple Pay Capability
3. 检查 `Constants.Stripe.applePayMerchantIdentifier` 是否正确配置

### 问题：支付时出现错误

**可能原因**：
1. Apple Pay 证书未正确配置
2. Merchant ID 不匹配
3. Stripe 密钥配置错误

**解决方法**：
1. 检查 Stripe Dashboard 中的证书状态
2. 确保使用 Stripe 提供的 CSR 创建证书
3. 验证 Stripe Publishable Key 是否正确

### 问题：收到 "您尚未将您的 Apple 商家账户添加到 Stripe" 错误

**解决方法**：
1. 撤销 Apple Merchant ID 下所有非 Stripe 生成的证书
2. 如果问题仍然存在，删除并重新创建 Merchant ID
3. 使用 Stripe 提供的 CSR 创建新证书
4. 在应用中重新打开和关闭 Apple Pay Credentials

---

## 📚 相关文档

- [Stripe Apple Pay 文档](https://docs.stripe.com/apple-pay)
- [Apple Pay 最佳实践](https://docs.stripe.com/apple-pay/best-practices)
- [Apple PassKit 文档](https://developer.apple.com/documentation/passkit)
- [项目中的 Apple Pay 设置指南](./stripe-sample-code/ios/APPLE_PAY_SETUP.md)

---

## 💡 最佳实践

1. **始终检查设备支持**：在显示 Apple Pay 按钮前，检查设备是否支持
2. **使用环境变量**：不要硬编码 Merchant ID，使用环境变量
3. **错误处理**：提供友好的错误提示
4. **测试**：在真机和模拟器上都进行测试
5. **用户体验**：如果 Apple Pay 不可用，提供其他支付方式

---

## 🔄 迁移指南

### 从 PaymentSheet 迁移到原生实现

如果你需要从 PaymentSheet 迁移到原生实现：

1. 导入 `ApplePayNativeView.swift` 和 `ApplePayNativeViewModel.swift`
2. 替换 `StripePaymentView` 为 `ApplePayNativeView`
3. 确保实现了 `ApplePayContextDelegate` 方法
4. 测试支付流程

### 从原生实现迁移到 PaymentSheet

如果你需要从原生实现迁移到 PaymentSheet：

1. 移除 `STPApplePayContext` 相关代码
2. 使用 `PaymentSheet` 配置 Apple Pay
3. 简化支付流程代码

---

## 📝 代码示例

### 检查 Apple Pay 支持

```swift
if ApplePayHelper.isApplePaySupported() {
    // 显示 Apple Pay 按钮
} else {
    // 显示其他支付方式
}
```

### 创建支付摘要项

```swift
let summaryItems = ApplePayHelper.createSummaryItems(
    items: [
        (label: "商品1", amount: 10.00),
        (label: "商品2", amount: 20.00)
    ],
    tax: 2.40,
    total: 32.40,
    merchantName: "Link²Ur"
)
```

### 使用辅助类创建支付请求

```swift
let paymentRequest = ApplePayHelper.createPaymentRequest(
    merchantIdentifier: "merchant.com.link2ur",
    countryCode: "GB",
    currency: "GBP",
    amount: 32.40,
    summaryItems: summaryItems
)
```
