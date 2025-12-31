# iOS 配置 Stripe Publishable Key 指南

## 方法1：通过 Xcode Scheme 配置（推荐，最简单）

### 步骤：

1. **打开 Xcode 项目**
   - 打开 `ios/link2ur.xcodeproj`

2. **进入 Scheme 设置**
   - 点击顶部工具栏的 Scheme 选择器（项目名称旁边）
   - 选择 "Edit Scheme..."（或按快捷键 `⌘<`）

3. **添加环境变量**
   - 在左侧选择 "Run"
   - 切换到 "Arguments" 标签
   - 展开 "Environment Variables" 部分
   - 点击左下角的 "+" 按钮
   - 添加：
     - **Name**: `STRIPE_PUBLISHABLE_KEY`
     - **Value**: `pk_test_51...`（你的 Stripe 测试密钥）

4. **保存并运行**
   - 点击 "Close" 保存
   - 运行应用，环境变量会自动加载

### 截图说明：

```
Xcode → Product → Scheme → Edit Scheme...
  └─ Run
     └─ Arguments
        └─ Environment Variables
           └─ [+] 添加新变量
              Name: STRIPE_PUBLISHABLE_KEY
              Value: pk_test_51...
```

## 方法2：直接在 Constants.swift 中配置（快速测试）

如果暂时不想配置环境变量，可以直接修改代码：

1. **打开文件**
   - `ios/link2ur/link2ur/Utils/Constants.swift`

2. **修改默认值**
   ```swift
   struct Stripe {
       static let publishableKey: String = {
           if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
               return key
           }
           return "pk_test_51..." // 👈 在这里直接填入你的密钥
       }()
   }
   ```

⚠️ **注意**：这种方式会将密钥硬编码在代码中，不推荐用于生产环境。

## 方法3：通过 xcconfig 文件（推荐用于团队协作）

### 步骤：

1. **创建 xcconfig 文件**
   - 在 Xcode 中，右键点击项目根目录
   - 选择 "New File..."
   - 选择 "Configuration Settings File"
   - 命名为 `Config.xcconfig`
   - 保存到项目根目录

2. **添加配置**
   在 `Config.xcconfig` 文件中添加：
   ```
   STRIPE_PUBLISHABLE_KEY = pk_test_51...
   ```

3. **在项目设置中关联**
   - 选择项目（蓝色图标）
   - 选择 Target "link2ur"
   - 在 "Info" 标签中找到 "Configurations"
   - 将 Debug 和 Release 的配置文件都设置为 `Config.xcconfig`

4. **在 Build Settings 中使用**
   - 切换到 "Build Settings"
   - 搜索 "User-Defined"
   - 添加新项：
     - Key: `STRIPE_PUBLISHABLE_KEY`
     - Value: `$(STRIPE_PUBLISHABLE_KEY)`（从 xcconfig 读取）

## 方法4：通过 Info.plist（不推荐）

虽然可以，但不推荐，因为密钥会暴露在应用包中。

## 验证配置

### 方法1：在代码中打印

在 `link2urApp.swift` 的 `init()` 方法中添加：

```swift
init() {
    // ... 其他初始化代码
    
    // 验证 Stripe Key
    print("Stripe Publishable Key: \(Constants.Stripe.publishableKey)")
    
    // 初始化 Stripe
    StripeAPI.defaultPublishableKey = Constants.Stripe.publishableKey
}
```

运行应用，在控制台查看输出，确认密钥已正确加载。

### 方法2：在运行时检查

在 `StripeConnectOnboardingView.swift` 中添加调试代码：

```swift
.onAppear {
    print("Stripe Key loaded: \(Constants.Stripe.publishableKey.prefix(20))...")
    viewModel.loadOnboardingSession()
}
```

## 获取 Stripe 密钥

1. 登录 [Stripe Dashboard](https://dashboard.stripe.com/)
2. 进入 "Developers" → "API keys"
3. 复制 "Publishable key"（以 `pk_test_` 开头用于测试，`pk_live_` 开头用于生产）

## 常见问题

### Q: 环境变量配置后还是不生效？
A: 
1. 确保 Scheme 名称正确（通常是 "link2ur"）
2. 重启 Xcode
3. Clean Build Folder（`⌘⇧K`）
4. 重新运行应用

### Q: 如何区分测试和生产环境？
A: 
- 在 Xcode Scheme 中可以为不同的 Configuration（Debug/Release）设置不同的环境变量
- 或者使用 `#if DEBUG` 在代码中区分

### Q: 团队协作时如何共享配置？
A: 
- 使用 xcconfig 文件（方法3）
- 将 `Config.xcconfig` 添加到 `.gitignore`（如果包含敏感信息）
- 或者创建 `Config.example.xcconfig` 作为模板

## 推荐方案

- **个人开发**：使用方法1（Xcode Scheme）
- **团队协作**：使用方法3（xcconfig 文件）
- **快速测试**：使用方法2（直接修改代码）

