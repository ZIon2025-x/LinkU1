# Stripe Connect Account Onboarding 增强功能

## 概述

已根据 Stripe 官方文档更新了 Account Onboarding 实现，支持高级配置选项，包括自定义 Terms of Service 和 Privacy Policy URL。

## 新增功能

### 1. 自定义 Terms of Service 和 Privacy Policy URL

现在可以在 Account Onboarding 流程中使用自定义的服务条款和隐私政策链接，而不是默认的 Stripe 链接。

#### 配置位置

在 `Constants.swift` 中已添加默认 URL：

```swift
struct Stripe {
    struct ConnectOnboarding {
        // Full Terms of Service URL（完整服务条款）
        static let fullTermsOfServiceURL = URL(string: "\(Frontend.baseURL)/terms")!
        
        // Recipient Terms of Service URL（收款方服务条款）
        static let recipientTermsOfServiceURL = URL(string: "\(Frontend.baseURL)/terms")!
        
        // Privacy Policy URL（隐私政策）
        static let privacyPolicyURL = URL(string: "\(Frontend.baseURL)/privacy")!
    }
}
```

#### 使用方式

默认情况下，`AccountOnboardingControllerWrapper` 会自动使用 `Constants.Stripe.ConnectOnboarding` 中定义的 URL。

如果需要为特定场景使用不同的 URL，可以在创建视图时传入：

```swift
AccountOnboardingControllerWrapper(
    clientSecret: secret,
    fullTermsOfServiceURL: URL(string: "https://custom-domain.com/terms")!,
    recipientTermsOfServiceURL: URL(string: "https://custom-domain.com/recipient-terms")!,
    privacyPolicyURL: URL(string: "https://custom-domain.com/privacy")!,
    onComplete: { ... },
    onError: { ... }
)
```

### 2. Collection Options 支持（预留）

代码已预留 `collectionOptions` 参数，但目前需要根据实际 Stripe iOS SDK 版本进行调整。

#### 当前状态

- ✅ 代码结构已支持 `collectionOptions` 参数
- ⚠️ 需要根据实际 SDK API 调整实现
- 📝 详细配置请参考 [STRIPE_CONNECT_ADVANCED_CONFIG.md](./STRIPE_CONNECT_ADVANCED_CONFIG.md)

#### 未来实现

如果 SDK 支持，可以通过以下方式配置：

```swift
// 创建 collectionOptions
let collectionOptions = AccountCollectionOptions()
collectionOptions.fields = .eventuallyDue  // 或 .currentlyDue
collectionOptions.futureRequirements = .include  // 或 .omit

// 使用 collectionOptions
AccountOnboardingControllerWrapper(
    clientSecret: secret,
    collectionOptions: collectionOptions,
    onComplete: { ... },
    onError: { ... }
)
```

## 技术实现

### 文件修改

1. **`Constants.swift`**
   - 添加了 `Stripe.ConnectOnboarding` 结构体
   - 定义了默认的 Terms 和 Privacy URL

2. **`StripeConnectOnboardingView.swift`**
   - `AccountOnboardingControllerWrapper` 现在支持可选的自定义 URL
   - 自动使用 Constants 中的默认 URL（如果未提供）

### API 兼容性

代码已考虑不同 SDK 版本的兼容性：

- 如果 SDK 不支持某些参数，可以回退到无参数版本
- 所有自定义 URL 都是可选的，提供默认值

## 后端配置

### Account Session 配置

后端已支持 `disable_stripe_user_authentication` 和 `external_account_collection` 配置。

如果需要支持 `collectionOptions`，需要在后端创建 Account Session 时添加：

```python
account_session = stripe.AccountSession.create(
    account=account_id,
    components={
        "account_onboarding": {
            "enabled": True,
        }
    },
    collection_options={
        "fields": "currently_due",  # 或 "eventually_due"
        "future_requirements": "omit",  # 或 "include"
        "requirements": {
            "only": ["business_details.*", "representative_details.*"]
            # 或 "exclude": ["owners.*", "directors.*"]
        }
    }
)
```

## 使用建议

### 1. 基本使用（推荐）

使用默认配置，自动使用 Constants 中定义的 URL：

```swift
StripeConnectOnboardingView()
```

### 2. 自定义 URL

如果需要使用不同的 URL：

```swift
// 在创建 AccountOnboardingControllerWrapper 时传入自定义 URL
// 注意：这需要修改 StripeConnectOnboardingView 以支持传入参数
```

### 3. 高级配置

如果需要使用 `collectionOptions` 或其他高级功能：

1. 检查 Stripe iOS SDK 文档，确认 API 签名
2. 根据实际 API 调整 `AccountOnboardingControllerWrapper` 的实现
3. 在后端添加相应的 `collection_options` 配置

## 注意事项

1. **URL 要求**
   - 所有 URL 必须是完整的绝对 URL（包含 `https://`）
   - URL 必须可公开访问

2. **Terms of Service 要求**
   - 如果使用自定义 Terms URL，必须将 Stripe 服务协议纳入自己的条款
   - 必须链接到 Stripe Privacy Policy

3. **SDK 版本兼容性**
   - 不同版本的 Stripe iOS SDK 可能支持不同的参数
   - 如果遇到编译错误，请检查 SDK 文档并调整代码

4. **测试建议**
   - 在测试环境中验证自定义 URL 是否正确显示
   - 确保所有链接都可以正常访问
   - 测试不同语言环境下的显示效果

## 相关文档

- [Stripe Account Onboarding 文档](https://docs.stripe.com/connect/supported-embedded-components/account-onboarding)
- [Collection Options](https://docs.stripe.com/connect/embedded-onboarding.md#requirement-restrictions)
- [自定义 Terms URL](https://docs.stripe.com/connect/updating-service-agreements.md#adding-stripes-service-agreement-to-your-terms-of-service)
- [iOS 高级配置指南](./STRIPE_CONNECT_ADVANCED_CONFIG.md)

## 更新日志

- **2025-01-XX**: 添加自定义 Terms 和 Privacy URL 支持
- **2025-01-XX**: 预留 Collection Options 支持（待 SDK 确认）

