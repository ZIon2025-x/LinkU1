# Stripe 支付示例

这是一个完整的 Stripe 支付集成示例，包含 Web 和 iOS 两个平台。

## 📁 项目结构

```
stripe-sample-code/
├── server.js              # Node.js 后端服务器
├── package.json           # 后端依赖配置
├── ios/                   # iOS 原生支付示例
│   ├── CheckoutViewController.swift
│   ├── AppDelegate.swift
│   ├── Info.plist
│   ├── Podfile
│   └── README.md
└── README.md              # 本文件
```

## 🚀 快速开始

### 1. 启动后端服务器

```bash
# 安装依赖
npm install

# 启动服务器（默认端口 4242）
npm start
```

服务器会在 `http://127.0.0.1:4242` 启动。

### 2. iOS 应用

详细说明请参考 [ios/README.md](./ios/README.md)

**快速步骤**：

1. **安装依赖**：
   - **方法一（CocoaPods）**：
     ```bash
     cd ios
     pod install
     ```
     然后打开 `StripePaymentSample.xcworkspace`
   
   - **方法二（Swift Package Manager，推荐）**：
     - 在 Xcode 中打开项目
     - 选择项目 → **Package Dependencies** → 点击 **"+"**
     - 添加：`https://github.com/stripe/stripe-ios`
     - 选择 **StripePaymentSheet** 和 **StripeCore**
   
   📖 **详细步骤**：参考 [ios/INSTALL_DEPENDENCIES.md](./ios/INSTALL_DEPENDENCIES.md)

2. **配置环境变量**（推荐，不硬编码密钥）：
   - 参考 [ios/XCODE_ENV_SETUP.md](./ios/XCODE_ENV_SETUP.md)
   - 在 Xcode Scheme 中配置 `STRIPE_PUBLISHABLE_KEY`

3. **运行项目**：按 ⌘ + R 运行

### 3. 前端部署到 Vercel

详细说明请参考 [VERCEL_DEPLOYMENT.md](./VERCEL_DEPLOYMENT.md)

**重要**：Vercel 会自动安装依赖，你只需要：
1. 确保 `package.json` 中包含所有依赖
2. 在 Vercel Dashboard 中配置环境变量
3. 部署即可

## 📝 配置说明

### Stripe 密钥配置

#### 后端（server.js）

在 `server.js` 中配置你的 Stripe Secret Key：
```javascript
const stripe = require("stripe")('sk_test_你的密钥');
```

#### iOS 应用（推荐使用环境变量）

**不要硬编码密钥！** 使用环境变量配置：

1. 在 Xcode Scheme 中配置环境变量（推荐）
   - 参考：[ios/XCODE_ENV_SETUP.md](./ios/XCODE_ENV_SETUP.md)
   - 变量名：`STRIPE_PUBLISHABLE_KEY`

2. 代码会自动从环境变量读取，无需修改代码

#### 前端（Vercel）

在 Vercel Dashboard 中配置环境变量：
- 变量名：`REACT_APP_STRIPE_PUBLISHABLE_KEY`（React 需要 `REACT_APP_` 前缀）
- 参考：[VERCEL_DEPLOYMENT.md](./VERCEL_DEPLOYMENT.md)

## 🔧 API 端点

### POST /create-payment-intent

创建支付意图。

**请求体**：
```json
{
  "items": [
    {"id": "xl-shirt", "amount": 2000}
  ]
}
```

**响应**：
```json
{
  "clientSecret": "pi_xxx_secret_xxx"
}
```

## 📚 相关文档

### 项目文档

- [iOS 集成指南](./ios/README.md) - iOS 应用集成说明
- [iOS 依赖安装指南](./ios/INSTALL_DEPENDENCIES.md) - 如何在 Xcode 中安装 Stripe SDK 依赖
- [Xcode 环境变量配置](./ios/XCODE_ENV_SETUP.md) - 如何在 Xcode 中配置环境变量
- [Apple Pay 配置指南](./ios/APPLE_PAY_SETUP.md) - Apple Pay Merchant ID 配置
- [Vercel 部署指南](./VERCEL_DEPLOYMENT.md) - 前端部署到 Vercel 的完整指南

### Stripe 官方文档

- [Stripe 官方文档](https://stripe.com/docs)
- [iOS SDK 文档](https://stripe.dev/stripe-ios/)
- [Payment Intent API](https://stripe.com/docs/api/payment_intents)
- [Stripe Payment Sheet](https://stripe.com/docs/payments/accept-a-payment?platform=ios)

