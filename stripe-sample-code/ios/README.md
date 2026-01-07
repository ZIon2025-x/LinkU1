# iOS Stripe 支付集成示例

这是一个完整的 iOS Stripe 支付集成示例，使用 Stripe Payment Sheet 实现原生支付体验。

## 📋 功能特性

- ✅ 使用 Stripe Payment Sheet 实现原生支付界面
- ✅ 支持多种支付方式（信用卡、借记卡等）
- ✅ 支持 Apple Pay（需要配置 Merchant ID）
- ✅ 完整的错误处理和用户反馈
- ✅ 加载状态指示
- ✅ 美观的 UI 界面

## 🚀 快速开始

### 1. 安装依赖

iOS 项目需要安装 Stripe iOS SDK。有两种方法：

> 📖 **详细安装指南**：请参考 [INSTALL_DEPENDENCIES.md](./INSTALL_DEPENDENCIES.md)

#### 方法一：使用 CocoaPods（推荐）

**步骤 1：安装 CocoaPods（如果还没有安装）**

在终端中运行：

```bash
# 使用 gem 安装（需要 Ruby）
sudo gem install cocoapods

# 或者使用 Homebrew 安装
brew install cocoapods
```

验证安装：
```bash
pod --version
```

**步骤 2：安装项目依赖**

1. 打开终端，进入项目目录：
   ```bash
   cd /Users/dyf/Downloads/LinkU1/stripe-sample-code/ios
   ```

2. 安装依赖：
   ```bash
   pod install
   ```

   这会：
   - 读取 `Podfile` 中的依赖配置
   - 下载 Stripe iOS SDK
   - 创建 `.xcworkspace` 文件

**步骤 3：在 Xcode 中打开项目**

⚠️ **重要**：必须使用 `.xcworkspace` 文件打开项目，**不要**使用 `.xcodeproj`！

1. 在 Finder 中找到 `ios` 目录
2. 双击 `StripePaymentSample.xcworkspace`（不是 `.xcodeproj`）
3. 或者在终端中运行：
   ```bash
   open StripePaymentSample.xcworkspace
   ```

**如果遇到问题**：

- 如果 `pod install` 失败，尝试：
  ```bash
  pod repo update
  pod install --repo-update
  ```

- 如果提示找不到 `Podfile`，确保在 `ios` 目录下运行命令

#### 方法二：使用 Swift Package Manager（SPM）

如果你不想使用 CocoaPods，可以使用 Xcode 内置的 Swift Package Manager：

**步骤 1：在 Xcode 中打开项目**

1. 打开 Xcode
2. 选择 **File** → **Open...**
3. 选择 `StripePaymentSample.xcodeproj` 文件

**步骤 2：添加 Stripe 包依赖**

1. 在 Xcode 左侧项目导航器中，选择项目（最顶部的蓝色图标）
2. 选择 **Target** → **StripePaymentSample**
3. 切换到 **Package Dependencies** 标签
4. 点击左下角的 **"+"** 按钮
5. 在搜索框中输入：`https://github.com/stripe/stripe-ios`
6. 点击 **Add Package**
7. 选择版本：
   - **Up to Next Major Version**：`25.0.0`
   - 或者 **Exact Version**：`25.3.1`
8. 点击 **Add Package**
9. 在 **Add to Target** 中，勾选：
   - ✅ **StripePaymentSheet**
   - ✅ **StripeCore**
10. 点击 **Add Package**

**步骤 3：等待下载完成**

Xcode 会自动下载并集成 Stripe SDK，这可能需要几分钟。

**验证安装**：

在代码中输入 `import StripePaymentSheet`，如果没有错误提示，说明安装成功。

#### 两种方法对比

| 特性 | CocoaPods | Swift Package Manager |
|------|-----------|----------------------|
| 安装方式 | 需要安装 CocoaPods | Xcode 内置，无需额外安装 |
| 项目文件 | 使用 `.xcworkspace` | 使用 `.xcodeproj` |
| 依赖管理 | `Podfile` | Xcode 项目设置 |
| 更新依赖 | `pod update` | Xcode 自动更新 |
| 推荐度 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**推荐**：如果项目已经使用 CocoaPods，继续使用 CocoaPods；如果是新项目，推荐使用 Swift Package Manager。

### 2. 配置环境变量（推荐）

**不要将密钥硬编码在代码中！** 使用环境变量配置。

#### 在 Xcode Scheme 中配置：

1. **Product** → **Scheme** → **Edit Scheme...**
2. 选择 **Run** → **Arguments** → **Environment Variables**
3. 添加以下环境变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `STRIPE_PUBLISHABLE_KEY` | `pk_test_...` | 你的 Stripe 测试公钥 |
| `STRIPE_BACKEND_URL` | `http://127.0.0.1:4242` | 后端服务器地址（可选） |
| `APPLE_PAY_MERCHANT_ID` | `merchant.com.yourcompany` | Apple Pay 商户 ID（可选） |

**详细说明**：请参考 [XCODE_ENV_SETUP.md](./XCODE_ENV_SETUP.md)

### 3. 配置后端服务器 URL

如果未配置 `STRIPE_BACKEND_URL` 环境变量，代码会使用默认值 `http://127.0.0.1:4242`。

**真机调试时**：将 `127.0.0.1` 改为你的电脑 IP 地址（例如：`http://192.168.1.100:4242`）

确保后端服务器正在运行（参考 `../server.js`）。

### 4. 运行项目

1. 确保后端服务器已启动：
   ```bash
   cd ..
   npm install
   npm start
   ```

2. 在 Xcode 中运行 iOS 项目

## 📱 使用说明

### 基本流程

1. 应用启动后会自动从服务器获取 Payment Intent
2. 点击"立即支付"按钮
3. Stripe Payment Sheet 会弹出，用户输入支付信息
4. 支付完成后显示结果

### 自定义配置

#### 修改商户名称

在 `CheckoutViewController.swift` 的 `pay()` 方法中：

```swift
configuration.merchantDisplayName = "你的公司名称"
```

#### 启用 Apple Pay

1. 在 Apple Developer 中创建 Merchant ID
2. 在 Xcode 中配置 Capabilities → Apple Pay
3. 在 `Info.plist` 中取消注释 Merchant ID 配置
4. 在 `CheckoutViewController.swift` 中配置：

```swift
configuration.applePay = .init(
    merchantId: "merchant.com.yourcompany",
    merchantCountryCode: "GB" // 或你的国家代码
)
```

#### 修改购物车内容

在 `fetchPaymentIntent()` 方法中修改：

```swift
let shoppingCartContent: [String: Any] = [
    "items": [
        ["id": "product-1", "amount": 2000], // amount 以分为单位
        ["id": "product-2", "amount": 3000]
    ]
]
```

## 🔧 项目结构

```
ios/
├── CheckoutViewController.swift  # 主支付视图控制器
├── AppDelegate.swift              # 应用委托
├── Info.plist                     # 应用配置文件
├── Podfile                        # CocoaPods 依赖配置
└── README.md                      # 本文件
```

## 📝 代码说明

### CheckoutViewController

主要的支付视图控制器，包含：

- **UI 组件**：标题、描述、支付按钮、加载指示器
- **支付流程**：获取 Payment Intent、显示支付界面、处理支付结果
- **错误处理**：网络错误、服务器错误、支付失败等

### AppDelegate

应用委托，负责：

- 初始化应用
- 创建窗口和根视图控制器
- 处理 URL Scheme 回调（如需要）

## ⚠️ 注意事项

1. **开发环境**：`Info.plist` 中配置了允许 HTTP 连接，仅用于开发。生产环境应使用 HTTPS。

2. **密钥安全**：
   - 不要将 Secret Key 放在客户端代码中
   - Publishable Key 可以放在客户端
   - 生产环境建议使用环境变量或配置文件

3. **网络请求**：
   - 确保后端服务器正在运行
   - 如果使用模拟器，`127.0.0.1` 可以正常工作
   - 如果使用真机，需要将 `127.0.0.1` 改为你的电脑 IP 地址

4. **测试卡号**：
   - 使用 Stripe 测试卡号进行测试
   - 测试卡号：`4242 4242 4242 4242`
   - 任意未来日期和 CVC

## 🐛 常见问题

### 问题：无法连接到服务器

**解决方案**：
- 确保后端服务器正在运行
- 检查 `backendURL` 是否正确
- 如果使用真机，确保手机和电脑在同一网络

### 问题：支付界面不显示

**解决方案**：
- 检查 Stripe Publishable Key 是否正确
- 检查 Payment Intent 是否成功创建
- 查看控制台日志

### 问题：CocoaPods 安装失败

**解决方案**：
```bash
pod repo update
pod install --repo-update
```

## 📚 相关文档

- [Stripe iOS SDK 文档](https://stripe.dev/stripe-ios/)
- [Stripe Payment Sheet 指南](https://stripe.com/docs/payments/accept-a-payment?platform=ios)
- [Stripe API 文档](https://stripe.com/docs/api)

## 📄 许可证

ISC

