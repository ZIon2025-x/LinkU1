# Stripe Connect 原生 SDK 配置指南

本指南说明如何配置 iOS 应用以使用 Stripe Connect 原生 SDK 的嵌入式组件。

## ✅ 已完成

- ✅ 已升级到原生 `EmbeddedComponentManager`
- ✅ 使用 `AccountOnboardingController` 替代 WebView
- ✅ 代码已更新

## 📋 需要配置的步骤

### 1. 添加相机权限（必需）

Stripe Connect SDK 需要访问相机来拍摄身份证件照片。

#### 方法一：在 Xcode 中配置（推荐）

1. 在 Xcode 中打开项目
2. 选择项目 → **Target** → **Info** 标签
3. 在 **Custom iOS Target Properties** 中，点击 **"+"** 添加新项
4. 选择或输入：`Privacy - Camera Usage Description`
5. 设置值为：`该应用程序将使用相机拍摄您的身份证件照片。`

#### 方法二：直接编辑 Info.plist

如果项目使用 Info.plist 文件，添加以下内容：

```xml
<key>NSCameraUsageDescription</key>
<string>该应用程序将使用相机拍摄您的身份证件照片。</string>
```

### 2. 验证 StripeConnect SDK 已安装

确保项目中已添加 `StripeConnect` 依赖：

1. 在 Xcode 中选择项目
2. 选择 **Target** → **Package Dependencies**
3. 确认 `stripe-ios` 包已添加
4. 确认 `StripeConnect` 产品已勾选

如果未安装，参考 [INSTALL_DEPENDENCIES.md](./INSTALL_DEPENDENCIES.md)

### 3. 配置 Stripe Publishable Key

确保已配置 Stripe Publishable Key（参考 [XCODE_ENV_SETUP.md](./XCODE_ENV_SETUP.md)）：

- 环境变量：`STRIPE_PUBLISHABLE_KEY`
- 或在 `Constants.swift` 中配置

## 🔄 从 WebView 迁移到原生 SDK

### 主要变化

1. **移除了 WebView 相关代码**：
   - 不再使用 `WKWebView`
   - 不再加载 JavaScript

2. **使用原生组件**：
   - `EmbeddedComponentManager` - 管理嵌入式组件
   - `AccountOnboardingController` - 账户入驻控制器

3. **更好的用户体验**：
   - 原生 UI，更流畅
   - 支持相机权限
   - 更好的错误处理

### 代码对比

**旧版本（WebView）**：
```swift
StripeConnectWebView(
    clientSecret: secret,
    onComplete: { ... },
    onError: { ... }
)
```

**新版本（原生）**：
```swift
AccountOnboardingControllerWrapper(
    clientSecret: secret,
    onComplete: { ... },
    onError: { ... }
)
```

## 🧪 测试

1. **运行应用**
2. **导航到设置收款账户页面**
3. **验证**：
   - ✅ 原生 UI 正常显示
   - ✅ 相机权限请求正常（如果需要上传身份证件）
   - ✅ 完成流程后能正确回调

## ⚠️ 注意事项

### 相机权限

- 首次使用需要用户授权相机权限
- 如果用户拒绝，部分功能可能无法使用
- 可以在设置中引导用户重新授权

### 错误处理

原生 SDK 提供了更详细的错误信息：
- `didFailWithError` - 一般错误
- `didFailLoadWithError` - 加载错误

### 外观自定义

如果需要自定义外观，可以在创建 `EmbeddedComponentManager` 时配置：

```swift
let appearance = EmbeddedComponentManager.Appearance()
appearance.colors.primary = UIColor.red
// ... 更多配置

let embeddedComponentManager = EmbeddedComponentManager(
    appearance: appearance,
    fetchClientSecret: fetchClientSecret
)
```

## 📚 相关文档

- [Stripe Connect iOS SDK 文档](https://docs.stripe.com/connect/get-started-connect-embedded-components?platform=ios)
- [Account Onboarding 组件](https://docs.stripe.com/connect/supported-embedded-components/account-onboarding.md)
- [外观自定义选项](https://docs.stripe.com/connect/embedded-appearance-options.md?platform=ios)

## 🐛 常见问题

### 问题：编译错误 "Cannot find type 'AccountOnboardingController'"

**解决方案**：
1. 确认 `StripeConnect` 产品已添加到 Target
2. 清理构建文件夹（⌘ + Shift + K）
3. 重新构建项目

### 问题：相机权限未请求

**解决方案**：
1. 检查 Info.plist 中是否添加了 `NSCameraUsageDescription`
2. 确认值不为空
3. 重新安装应用（删除后重新安装）

### 问题：控制器不显示

**解决方案**：
1. 检查 `clientSecret` 是否正确获取
2. 检查 `STPAPIClient.shared.publishableKey` 是否已设置
3. 查看控制台日志中的错误信息

## ✅ 检查清单

升级完成后，确认以下项目：

- [ ] 相机权限已添加到 Info.plist
- [ ] StripeConnect SDK 已安装
- [ ] Stripe Publishable Key 已配置
- [ ] 代码编译无错误
- [ ] 应用可以正常运行
- [ ] Onboarding 流程可以正常使用
- [ ] 相机权限请求正常

