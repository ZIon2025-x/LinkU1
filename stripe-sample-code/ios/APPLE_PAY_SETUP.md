# Apple Pay Merchant ID 配置指南

本指南说明如何配置 Apple Pay Merchant ID，以在 iOS 应用中启用 Apple Pay 支付。

## 📋 前置条件

1. Apple Developer 账号（付费账号，$99/年）
2. 在 Stripe Dashboard 中已配置 Apple Pay
3. Xcode 已安装

## 🚀 配置步骤

### 第一步：在 Apple Developer 中创建 Merchant ID

#### 1. 登录 Apple Developer

访问：https://developer.apple.com/account/

#### 2. 创建 Merchant ID

1. 进入 **Certificates, Identifiers & Profiles**
2. 在左侧选择 **Identifiers**
3. 点击右上角 **+** 按钮
4. 选择 **Merchant IDs**，点击 **Continue**
5. 填写信息：
   - **Description**：商户描述（例如：Link2UR Payments）
   - **Identifier**：`merchant.com.yourcompany`（格式：`merchant.` + 你的域名）
6. 点击 **Continue** → **Register**

**重要**：记下这个 Merchant ID，后续步骤会用到。

#### 3. 配置 Merchant ID

1. 点击刚创建的 Merchant ID
2. 点击 **Configure** 按钮
3. 选择你的 **App ID**（如果还没有，需要先创建）
4. 点击 **Save**

### 第二步：在 Xcode 中启用 Apple Pay Capability

#### 1. 打开项目设置

1. 在 Xcode 中选择项目
2. 选择 **Target** → **Signing & Capabilities** 标签

#### 2. 添加 Apple Pay Capability

1. 点击左上角 **+ Capability** 按钮
2. 搜索并添加 **Apple Pay**
3. 在 **Merchant IDs** 部分，点击 **+** 按钮
4. 选择或输入你的 Merchant ID（例如：`merchant.com.yourcompany`）

#### 3. 验证配置

确保 Merchant ID 显示在列表中，并且没有错误提示。

### 第三步：在代码中配置 Merchant ID

#### 方法一：使用环境变量（推荐）

在 Xcode Scheme 中配置环境变量：

1. **Product** → **Scheme** → **Edit Scheme...**
2. 选择 **Run** → **Arguments** → **Environment Variables**
3. 添加：
   ```
   APPLE_PAY_MERCHANT_ID = merchant.com.yourcompany
   ```

#### 方法二：在 Info.plist 中配置

在 `Info.plist` 中添加：

```xml
<key>ApplePayMerchantID</key>
<string>merchant.com.yourcompany</string>
```

#### 方法三：直接在代码中配置（不推荐）

如果必须硬编码，可以在 `CheckoutViewController.swift` 中修改：

```swift
if let merchantId = Self.merchantID {
    configuration.applePay = .init(
        merchantId: merchantId,
        merchantCountryCode: "GB" // 根据你的业务所在国家修改
    )
}
```

### 第四步：在 Stripe Dashboard 中配置 Apple Pay

#### 1. 登录 Stripe Dashboard

访问：https://dashboard.stripe.com/

#### 2. 配置 Apple Pay Domain

1. 进入 **Settings** → **Payment methods**
2. 找到 **Apple Pay** 部分
3. 点击 **Add domain**
4. 输入你的域名（例如：`link2ur.com`）
5. 下载验证文件并上传到你的服务器

#### 3. 验证域名

按照 Stripe 的指示完成域名验证。

## 🔧 代码配置

代码已经自动支持从环境变量读取 Merchant ID。如果配置了环境变量，Apple Pay 会自动启用。

在 `CheckoutViewController.swift` 中：

```swift
// 如果配置了 Merchant ID，启用 Apple Pay
if let merchantId = Self.merchantID {
    configuration.applePay = .init(
        merchantId: merchantId,
        merchantCountryCode: "GB" // 修改为你的国家代码
    )
}
```

## 📱 测试 Apple Pay

### 在模拟器中测试

1. 在模拟器中打开 **Settings** → **Wallet & Apple Pay**
2. 添加测试卡（使用 Stripe 测试卡号）
3. 运行应用，尝试支付
4. 应该能看到 Apple Pay 选项

### 在真机上测试

1. 确保设备已登录 Apple ID
2. 在 **Settings** → **Wallet & Apple Pay** 中添加支付卡
3. 运行应用，尝试支付
4. 使用 Touch ID 或 Face ID 完成支付

## 🌍 国家代码列表

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

## ⚠️ 注意事项

### 1. Merchant ID 格式

- 必须以 `merchant.` 开头
- 通常使用反向域名格式：`merchant.com.yourcompany`
- 必须与 Apple Developer 中注册的完全一致

### 2. 域名验证

- 必须在 Stripe Dashboard 中验证域名
- 验证文件必须可以通过 HTTPS 访问
- 域名必须与你的应用相关

### 3. 测试环境

- 开发时可以使用测试 Merchant ID
- 测试支付不会产生实际费用
- 使用 Stripe 测试卡号进行测试

### 4. 生产环境

- 确保使用生产环境的 Merchant ID
- 确保域名已验证
- 确保 Stripe 账户已激活

## 🐛 常见问题

### 问题：Apple Pay 选项不显示

**可能原因**：
1. Merchant ID 未正确配置
2. 设备不支持 Apple Pay
3. 未添加支付卡到 Wallet
4. Stripe 中未配置 Apple Pay

**解决方案**：
1. 检查 Xcode 中 Apple Pay Capability 是否已添加
2. 检查环境变量是否正确配置
3. 检查设备是否支持 Apple Pay（需要 iPhone 6 或更新）
4. 检查 Stripe Dashboard 中 Apple Pay 是否已启用

### 问题：支付时提示 Merchant ID 无效

**解决方案**：
1. 确认 Merchant ID 与 Apple Developer 中注册的一致
2. 确认在 Xcode 中已正确配置
3. 清理并重新构建项目

### 问题：域名验证失败

**解决方案**：
1. 确认验证文件已正确上传到服务器
2. 确认可以通过 HTTPS 访问验证文件
3. 在 Stripe Dashboard 中重新验证

## 📚 相关文档

- [Apple Pay 开发文档](https://developer.apple.com/apple-pay/)
- [Stripe Apple Pay 集成指南](https://stripe.com/docs/apple-pay)
- [Apple Developer 账号管理](https://developer.apple.com/account/)

## ✅ 检查清单

配置完成后，确认以下项目：

- [ ] 在 Apple Developer 中创建了 Merchant ID
- [ ] 在 Xcode 中添加了 Apple Pay Capability
- [ ] 配置了 Merchant ID（环境变量或 Info.plist）
- [ ] 在 Stripe Dashboard 中配置了 Apple Pay
- [ ] 验证了域名
- [ ] 代码中正确配置了 merchantCountryCode
- [ ] 在测试设备上验证了 Apple Pay 功能

