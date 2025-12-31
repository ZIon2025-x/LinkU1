# Stripe Keys 配置指南

## 概述

本文档说明如何在 Web 和 iOS 应用中配置 Stripe Publishable Key。

## 环境变量命名

- **Web 前端**: `REACT_APP_STRIPE_PUBLISHABLE_KEY` 或 `STRIPE_PUBLISHABLE_KEY`
- **iOS 应用**: `STRIPE_PUBLISHABLE_KEY` (通过环境变量或 Constants.swift)
- **后端**: `STRIPE_SECRET_KEY` (服务器端私钥)

## Web 前端配置

### 1. 创建环境变量文件

在 `frontend/` 目录下创建 `.env` 或 `.env.local` 文件：

```bash
# frontend/.env.local
REACT_APP_STRIPE_PUBLISHABLE_KEY=pk_test_51...
```

或者使用 `STRIPE_PUBLISHABLE_KEY`（如果项目配置支持）：

```bash
# frontend/.env.local
STRIPE_PUBLISHABLE_KEY=pk_test_51...
```

### 2. 代码中的使用

在 React 组件中：

```typescript
// 方式1：使用 REACT_APP_ 前缀（推荐）
const STRIPE_PUBLISHABLE_KEY = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || '';

// 方式2：使用 STRIPE_PUBLISHABLE_KEY（如果项目配置支持）
const STRIPE_PUBLISHABLE_KEY = process.env.STRIPE_PUBLISHABLE_KEY || '';
```

### 3. 部署配置

#### Vercel
在 Vercel Dashboard 中：
1. 进入项目设置
2. 选择 "Environment Variables"
3. 添加：
   - Key: `REACT_APP_STRIPE_PUBLISHABLE_KEY`
   - Value: `pk_test_...` (测试) 或 `pk_live_...` (生产)

#### 其他平台
根据平台要求配置环境变量，确保变量名与代码中使用的名称一致。

## iOS 应用配置

### 方式1：使用 Constants.swift（推荐）

iOS 应用已经通过 `Constants.swift` 配置了 Stripe Key：

```swift
// ios/link2ur/link2ur/Utils/Constants.swift
struct Stripe {
    static var publishableKey: String {
        // 优先从环境变量读取
        if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
            return key
        }
        // 生产环境
        #if PRODUCTION
        return ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"] ?? "pk_live_..."
        #else
        // 测试环境
        return ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"] ?? "pk_test_..."
        #endif
    }
}
```

### 方式2：通过 Xcode Scheme 配置环境变量

1. 在 Xcode 中打开项目
2. 选择 Product → Scheme → Edit Scheme...
3. 选择 "Run" → "Arguments"
4. 在 "Environment Variables" 中添加：
   - Name: `STRIPE_PUBLISHABLE_KEY`
   - Value: `pk_test_...`

### 方式3：通过 Info.plist（不推荐，但可用）

如果需要通过 Info.plist 配置：

1. 打开 `Info.plist`
2. 添加新项：
   - Key: `StripePublishableKey`
   - Type: `String`
   - Value: `pk_test_...`

**注意**：这种方式不推荐，因为密钥会暴露在应用包中。

### 方式4：通过 xcconfig 文件（推荐用于团队协作）

1. 创建 `Config.xcconfig` 文件：

```xcconfig
// Config.xcconfig
STRIPE_PUBLISHABLE_KEY = pk_test_...
```

2. 在 Xcode 项目设置中：
   - 选择项目 → Build Settings
   - 搜索 "User-Defined"
   - 添加 `STRIPE_PUBLISHABLE_KEY`

3. 在代码中读取：

```swift
let key = Bundle.main.object(forInfoDictionaryKey: "STRIPE_PUBLISHABLE_KEY") as? String ?? ""
```

## 代码中的使用

### Web 前端

```typescript
// frontend/src/components/stripe/StripeConnectOnboarding.tsx
const STRIPE_PUBLISHABLE_KEY = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || '';

// 使用
loadStripe(STRIPE_PUBLISHABLE_KEY).then((stripeInstance) => {
    setStripe(stripeInstance);
});
```

### iOS 应用

```swift
// ios/link2ur/link2ur/Views/Payment/StripeConnectOnboardingView.swift
private func getStripePublishableKey() -> String {
    return Constants.Stripe.publishableKey
}

// 使用
const stripe = Stripe('\(getStripePublishableKey())');
```

## 获取 Stripe Keys

### 测试环境
1. 登录 [Stripe Dashboard](https://dashboard.stripe.com/)
2. 进入 "Developers" → "API keys"
3. 复制 "Publishable key" (以 `pk_test_` 开头)

### 生产环境
1. 在 Stripe Dashboard 中切换到 "Live mode"
2. 进入 "Developers" → "API keys"
3. 复制 "Publishable key" (以 `pk_live_` 开头)

## 安全注意事项

1. **Publishable Key 是公开的**：
   - 可以安全地放在前端代码中
   - 不会造成安全风险
   - 但建议使用环境变量，便于管理

2. **Secret Key 必须保密**：
   - 只能放在后端服务器
   - 绝对不能提交到 Git
   - 使用环境变量或密钥管理服务

3. **环境变量文件**：
   - `.env` 和 `.env.local` 应该添加到 `.gitignore`
   - 不要提交包含真实密钥的文件

## 验证配置

### Web 前端
```bash
# 检查环境变量是否加载
console.log(process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY);
```

### iOS 应用
```swift
// 在应用启动时检查
print("Stripe Key: \(Constants.Stripe.publishableKey)")
```

## 常见问题

### Q: Web 端环境变量不生效？
A: 
1. 确保变量名以 `REACT_APP_` 开头（React 要求）
2. 重启开发服务器
3. 检查 `.env` 文件位置是否正确

### Q: iOS 端如何区分测试和生产环境？
A: 使用 Xcode 的 Build Configuration：
- Debug: 使用测试 key
- Release: 使用生产 key

### Q: 可以硬编码密钥吗？
A: 不推荐。虽然 Publishable Key 是公开的，但使用环境变量更便于管理不同环境。

## 相关文件

- Web: `frontend/src/components/stripe/StripeConnectOnboarding.tsx`
- iOS: `ios/link2ur/link2ur/Views/Payment/StripeConnectOnboardingView.swift`
- iOS Constants: `ios/link2ur/link2ur/Utils/Constants.swift`
- 后端: `backend/app/stripe_connect_routes.py`

