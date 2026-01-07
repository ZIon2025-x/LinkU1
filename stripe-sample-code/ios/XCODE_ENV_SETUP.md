# Xcode 环境变量配置指南

本指南说明如何在 Xcode 中配置环境变量，避免将敏感信息（如 Stripe 密钥）硬编码在代码中。

## 📋 需要配置的环境变量

- `STRIPE_PUBLISHABLE_KEY` - Stripe 公钥
- `STRIPE_BACKEND_URL` - 后端服务器 URL（可选）
- `APPLE_PAY_MERCHANT_ID` - Apple Pay 商户 ID（可选，如果使用 Apple Pay）

## 🚀 配置步骤

### 方法一：在 Xcode Scheme 中配置（推荐）

这是最常用的方法，可以为不同的构建配置（Debug/Release）设置不同的环境变量。

#### 1. 打开 Scheme 编辑器

1. 在 Xcode 顶部工具栏，点击项目名称旁边的 **Scheme** 下拉菜单
2. 选择 **Edit Scheme...**

或者使用快捷键：
- **⌘ + <** (Command + 小于号)

#### 2. 配置环境变量

1. 在左侧选择 **Run**（用于开发调试）
2. 切换到 **Arguments** 标签
3. 在 **Environment Variables** 部分，点击 **+** 按钮添加环境变量

添加以下环境变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `STRIPE_PUBLISHABLE_KEY` | `pk_test_...` | 你的 Stripe 测试公钥 |
| `STRIPE_BACKEND_URL` | `http://127.0.0.1:4242` | 后端服务器地址（可选） |
| `APPLE_PAY_MERCHANT_ID` | `merchant.com.yourcompany` | Apple Pay 商户 ID（可选） |

**示例**：
```
STRIPE_PUBLISHABLE_KEY = pk_test_51SePW98JTHo8ClgaUWRjX9HHabiw09tJQLJlQdJXYCNMVDFr9B9ZeWNwkH9D8NRxreIew4AfQ7hByO6l37KdEkAa00yqY1lz0P
STRIPE_BACKEND_URL = http://127.0.0.1:4242
```

#### 3. 为 Release 配置配置环境变量

1. 在 Scheme 编辑器左侧选择 **Archive**（用于生产构建）
2. 同样在 **Arguments** → **Environment Variables** 中添加环境变量
3. 使用生产环境的密钥（`pk_live_...`）

#### 4. 保存配置

点击 **Close** 保存配置。

### 方法二：使用 xcconfig 文件（适合团队协作）

如果你需要版本控制环境变量配置（不推荐直接提交密钥），可以使用 `.xcconfig` 文件。

#### 1. 创建 xcconfig 文件

1. 在 Xcode 中，右键点击项目
2. 选择 **New File...**
3. 选择 **Configuration Settings File**
4. 命名为 `Config.xcconfig`
5. 添加到项目

#### 2. 配置环境变量

在 `Config.xcconfig` 文件中添加：

```xcconfig
// Stripe 配置
STRIPE_PUBLISHABLE_KEY = pk_test_你的密钥
STRIPE_BACKEND_URL = http://127.0.0.1:4242
APPLE_PAY_MERCHANT_ID = merchant.com.yourcompany
```

#### 3. 在项目设置中关联

1. 选择项目 → **Info** 标签
2. 在 **Configurations** 部分，为 Debug 和 Release 选择 `Config.xcconfig`

#### 4. 添加到 .gitignore

**重要**：将包含密钥的 xcconfig 文件添加到 `.gitignore`：

```gitignore
# 环境变量配置（包含敏感信息）
Config.xcconfig
Config.local.xcconfig
```

### 方法三：在 Info.plist 中配置（不推荐用于密钥）

虽然可以在 `Info.plist` 中配置，但不推荐用于存储密钥，因为 `Info.plist` 通常会被提交到版本控制。

如果必须使用，可以这样配置：

```xml
<key>StripePublishableKey</key>
<string>pk_test_...</string>
<key>ApplePayMerchantID</key>
<string>merchant.com.yourcompany</string>
```

代码会自动从 `Info.plist` 读取这些值。

## 🔒 安全建议

### ✅ 推荐做法

1. **使用环境变量**：在 Xcode Scheme 中配置，不提交到 Git
2. **区分环境**：Debug 使用测试密钥，Release 使用生产密钥
3. **使用 .gitignore**：确保包含密钥的文件不会被提交

### ❌ 避免的做法

1. **硬编码密钥**：不要直接在代码中写密钥
2. **提交密钥到 Git**：不要将包含密钥的配置文件提交到版本控制
3. **使用生产密钥测试**：测试时使用测试密钥

## 📝 验证配置

运行应用后，在控制台查看日志：

```
✅ Stripe Publishable Key 已配置
✅ Backend URL: http://127.0.0.1:4242
```

如果看到错误信息，说明环境变量未正确配置。

## 🔄 不同环境的配置

### 开发环境（Debug）

```
STRIPE_PUBLISHABLE_KEY = pk_test_...
STRIPE_BACKEND_URL = http://127.0.0.1:4242
```

### 生产环境（Release）

```
STRIPE_PUBLISHABLE_KEY = pk_live_...
STRIPE_BACKEND_URL = https://api.yourcompany.com
APPLE_PAY_MERCHANT_ID = merchant.com.yourcompany
```

## 🐛 常见问题

### 问题：环境变量读取不到

**解决方案**：
1. 确保在正确的 Scheme（Run/Archive）中配置
2. 重启 Xcode
3. 清理构建文件夹（⌘ + Shift + K）
4. 检查变量名拼写是否正确

### 问题：真机调试时无法连接后端

**解决方案**：
- 将 `STRIPE_BACKEND_URL` 从 `127.0.0.1` 改为你的电脑 IP 地址
- 例如：`http://192.168.1.100:4242`
- 确保手机和电脑在同一网络

### 问题：如何为不同开发者配置不同密钥？

**解决方案**：
- 每个开发者在自己的 Xcode Scheme 中配置
- 或者使用 `Config.local.xcconfig`（添加到 .gitignore）
- 在项目中引用 `Config.local.xcconfig`（如果存在）

## 📚 相关文档

- [Xcode Scheme 文档](https://developer.apple.com/documentation/xcode/managing-schemes)
- [Stripe iOS SDK 文档](https://stripe.dev/stripe-ios/)

