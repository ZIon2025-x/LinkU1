# Stripe Connect 高级配置指南

本指南说明如何配置 Stripe Connect Account Onboarding 的高级功能，包括 collection options、requirement restrictions 和自定义 Terms/Privacy URL。

## 📋 当前实现状态

### ✅ 已实现

- ✅ 基本的 Account Onboarding 功能
- ✅ 使用原生 `AccountOnboardingController`
- ✅ 错误处理和状态管理
- ✅ `disable_stripe_user_authentication` 支持（后端已配置）

### ⚠️ 高级功能配置

以下高级功能需要通过**后端 Account Session 配置**，而不是在 iOS 客户端配置：

1. **Collection Options**（收集选项）
2. **Requirement Restrictions**（需求限制）
3. **Terms of Service 和 Privacy Policy URL**（自定义协议链接）

## 🔧 后端配置

### 1. Collection Options（收集选项）

控制收集 `currently_due` 还是 `eventually_due` 需求。

#### 当前配置

后端默认收集 `currently_due` 需求。如果需要收集 `eventually_due`，需要修改后端代码：

```python
# 在 create_account_session_safe 函数中
if enable_account_onboarding:
    components_config["account_onboarding"] = {
        "enabled": bool(True),
        "features": {
            # 可以通过 collection_options 配置
            # 注意：这需要在 Account Session API 中配置，而不是在 components 中
        }
    }
```

**注意**：根据 Stripe 文档，`collectionOptions` 是在创建 Account Session 时通过 `collection_options` 参数配置的，不是在 `components` 中。

### 2. Requirement Restrictions（需求限制）

使用 `only` 或 `exclude` 来限制收集的需求。

#### 示例：只收集特定需求

```python
# 在后端创建 Account Session 时
account_session = stripe.AccountSession.create(
    account=account_id,
    components={
        "account_onboarding": {
            "enabled": True,
        }
    },
    collection_options={
        "fields": "eventually_due",  # 或 "currently_due"
        "future_requirements": "include",  # 或 "omit"
        "requirements": {
            "only": ["business_details.*", "representative_details.*"]
            # 或 "exclude": ["owners.*", "directors.*"]
        }
    }
)
```

### 3. 自定义 Terms of Service 和 Privacy Policy URL

#### 后端配置

在创建 Account Session 时，可以通过 `collection_options` 配置：

```python
# 注意：根据 Stripe 文档，Terms URL 是在客户端组件中配置的
# 但也可以通过后端 Account Session 的某些参数配置
```

#### iOS 客户端配置（如果 SDK 支持）

如果 Stripe iOS SDK 支持，可以在创建 `AccountOnboardingController` 时配置：

```swift
// 如果 SDK 支持这些参数
let controller = embeddedComponentManager.createAccountOnboardingController(
    fullTermsOfServiceUrl: URL(string: "https://your-domain.com/terms")!,
    recipientTermsOfServiceUrl: URL(string: "https://your-domain.com/recipient-terms")!,
    privacyPolicyUrl: URL(string: "https://your-domain.com/privacy")!
)
```

**当前状态**：需要检查 Stripe iOS SDK 是否支持这些参数。如果不支持，这些配置需要在后端处理。

### 4. External Account Collection（外部账户收集）

控制是否收集银行账户信息。

#### 后端配置

```python
components_config["account_onboarding"] = {
    "enabled": bool(True),
    "features": {
        "external_account_collection": bool(True),  # 默认启用
        # 如果禁用，设置为 False
    }
}
```

### 5. Disable Stripe User Authentication（禁用 Stripe 用户认证）

#### 后端配置（已实现）

```python
components_config["account_onboarding"] = {
    "enabled": bool(True),
    "features": {
        "disable_stripe_user_authentication": bool(True),  # 已配置
    }
}
```

**注意**：这仅适用于 Custom 账户且平台负责收集信息的情况。

## 📝 配置示例

### 完整配置示例（后端）

```python
def create_account_session_safe(
    account_id: str,
    enable_account_onboarding: bool = True,
    disable_stripe_user_authentication: bool = True,
    collect_eventually_due: bool = False,  # 是否收集 eventually_due
    external_account_collection: bool = True,  # 是否收集银行账户
):
    components_config = {}
    
    if enable_account_onboarding:
        components_config["account_onboarding"] = {
            "enabled": bool(True),
            "features": {
                "disable_stripe_user_authentication": bool(disable_stripe_user_authentication),
                "external_account_collection": bool(external_account_collection),
            }
        }
    
    # 创建 Account Session
    account_session_params = {
        "account": account_id,
        "components": components_config,
    }
    
    # 如果需要配置 collection_options
    if collect_eventually_due:
        account_session_params["collection_options"] = {
            "fields": "eventually_due",
            "future_requirements": "include",
        }
    
    return stripe.AccountSession.create(**account_session_params)
```

## 🎯 使用场景

### 场景 1：只收集必要信息（快速入驻）

```python
collection_options = {
    "fields": "currently_due",  # 只收集当前必需的信息
    "future_requirements": "omit",
}
```

### 场景 2：收集所有信息（完整入驻）

```python
collection_options = {
    "fields": "eventually_due",  # 收集所有最终需要的信息
    "future_requirements": "include",
}
```

### 场景 3：只收集特定需求（修复流程）

```python
collection_options = {
    "fields": "currently_due",
    "requirements": {
        "only": ["representative_document.*", "business_verification.*"]
    }
}
```

### 场景 4：排除某些需求（预填充信息）

```python
collection_options = {
    "fields": "currently_due",
    "requirements": {
        "exclude": ["business_details.registered_name", "business_details.url"]
    }
}
```

## ⚠️ 重要注意事项

### 1. Requirement Restrictions 的限制

- `exclude` 选项**不会移除**需求，只是隐藏字段
- 账户仍然需要满足所有 KYC 要求才能启用功能
- 这些限制只适用于嵌入式组件，不影响其他类型的 Dashboard

### 2. Collection Options 的限制

- 如果使用 `only` 限制，不会显示标准的最终摘要步骤
- 如果所有指定的需求都已提供，组件会立即退出

### 3. Terms of Service

- 如果平台负责收集信息，可以替换 Terms URL
- 必须将 Stripe 服务协议纳入自己的 Terms of Service
- 必须链接到 Stripe Privacy Policy

## 📚 相关文档

- [Stripe Account Onboarding 文档](https://docs.stripe.com/connect/supported-embedded-components/account-onboarding.md)
- [Collection Options](https://docs.stripe.com/connect/embedded-onboarding.md#requirement-restrictions)
- [Required Verification Information](https://docs.stripe.com/connect/required-verification-information.md)
- [Updating Service Agreements](https://docs.stripe.com/connect/updating-service-agreements.md)

## 🔄 未来改进

如果需要支持这些高级功能，可以：

1. **在后端添加配置参数**：
   - 添加 `collection_options` 参数到 API 请求
   - 支持 `fields`、`future_requirements`、`requirements` 配置

2. **在 iOS 客户端支持**（如果 SDK 支持）：
   - 检查 SDK 是否支持 `collectionOptions` 参数
   - 如果支持，添加配置选项到 `AccountOnboardingControllerWrapper`

3. **添加 Terms URL 配置**：
   - 在 Constants 中添加 Terms 和 Privacy URL
   - 在创建 AccountOnboardingController 时传入

## ✅ 当前推荐配置

对于大多数场景，当前的后端配置已经足够：

- ✅ 收集 `currently_due` 需求（默认）
- ✅ 启用 `external_account_collection`（默认）
- ✅ 支持 `disable_stripe_user_authentication`（已配置）

如果需要更高级的配置，可以：
1. 修改后端 `create_account_session_safe` 函数
2. 添加新的 API 参数
3. 在创建 Account Session 时传入配置

