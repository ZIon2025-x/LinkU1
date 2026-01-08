# Stripe iOS SDK 包配置指南

## ⚠️ 重要：必须使用 `stripe-ios-spm` 包源

根据 Stripe 官方文档，iOS 端必须使用 `stripe-ios-spm` 包源，而不是 `stripe-ios`。

## 正确的配置步骤

### 1. 移除错误的包源

在 Xcode 中：

1. 选择项目（最顶部的蓝色图标）
2. 选择 **Target** → **Package Dependencies**
3. 找到 `stripe-ios`（来自 `https://github.com/stripe/stripe-ios`）
4. 点击它，然后点击 **"-"** 按钮移除

### 2. 添加正确的包源

1. 在 **Package Dependencies** 中，点击 **"+"** 按钮
2. 输入包源 URL：`https://github.com/stripe/stripe-ios-spm`
3. 选择版本规则：**Up to Next Major Version**
4. 最低版本：`25.3.1`（或最新版本）
5. 点击 **Add Package**

### 3. 添加所需的产品

在 **Package Dependencies** 中，展开 `stripe-ios-spm`，确保以下产品已添加到 Target：

- ✅ **StripeConnect**（必需）
- ✅ **StripePaymentSheet**（如果需要支付功能）
- ✅ **StripePayments**（如果需要支付功能）
- ✅ 其他需要的 Stripe 产品

### 4. 清理并重新构建

1. **Product** → **Clean Build Folder** (⇧⌘K)
2. **File** → **Packages** → **Reset Package Caches**
3. **File** → **Packages** → **Resolve Package Versions**
4. 重新构建项目

## 为什么需要 `stripe-ios-spm`？

根据 Stripe 官方文档：

> 在 Xcode 中，选择**文件** > **添加工具包依赖…**并输入 `https://github.com/stripe/stripe-ios-spm` 作为仓库 URL。

`stripe-ios-spm` 是专门为 Swift Package Manager 优化的版本，包含：
- ✅ 公开的 `createPaymentsViewController()` API
- ✅ 公开的 `createPayoutsViewController()` API
- ✅ 完整的 Stripe Connect 嵌入式组件支持

## 验证配置

配置完成后，代码应该能够正常编译，并且可以使用：

```swift
let paymentsViewController = embeddedComponentManager.createPaymentsViewController()
let payoutsViewController = embeddedComponentManager.createPayoutsViewController()
```

## 常见问题

### Q: 为什么会有两个包源？

A: `stripe-ios` 是主仓库，但 `stripe-ios-spm` 是专门为 SPM 优化的版本，包含公开的 API。

### Q: 如果仍然遇到 `@_spi` 保护错误？

A: 
1. 确认使用的是 `stripe-ios-spm` 而不是 `stripe-ios`
2. 更新到最新版本的 SDK
3. 清理构建缓存并重新构建

### Q: CocoaPods 用户怎么办？

A: CocoaPods 用户应该使用：
```ruby
pod 'StripeConnect'
```
这会自动使用正确的包源。

