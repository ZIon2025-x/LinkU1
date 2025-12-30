# iOS Stripe 原生支付集成设置指南

## 📋 完成状态

✅ **代码已实现**：
- PaymentViewModel - 支付逻辑
- StripePaymentView - 支付界面
- API 端点配置
- Constants 配置
- TaskDetailView 集成

⚠️ **需要完成的步骤**：

---

## 第一步：添加 Stripe iOS SDK

### 方法一：使用 Swift Package Manager（推荐）

1. **在 Xcode 中打开项目**
   - 打开 `link2ur.xcodeproj`

2. **添加 Package Dependency**
   - 选择项目 → **Package Dependencies** 标签
   - 点击 **"+"** 按钮
   - 输入 URL：`https://github.com/stripe/stripe-ios`
   - 选择版本：**Exact Version** → `25.3.1`（或 **Up to Next Major Version** → `25.0.0`）
   - 点击 **Add Package**
   - 选择 **StripePaymentSheet** 和 **StripeCore**（必需）
   - 点击 **Add Package**

### 方法二：使用 CocoaPods

如果项目使用 CocoaPods：

1. **编辑 Podfile**：
   ```ruby
   pod 'StripePaymentSheet', '~> 25.3'
   ```

2. **安装依赖**：
   ```bash
   pod install
   ```

3. **使用 `.xcworkspace` 打开项目**（不是 `.xcodeproj`）

---

## 第二步：配置 Stripe Publishable Key

### 在 Constants.swift 中配置

文件位置：`ios/link2ur/link2ur/Utils/Constants.swift`

**已添加配置**：
```swift
struct Stripe {
    static let publishableKey: String = {
        #if DEBUG
        if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
            return key
        }
        return "pk_test_..." // 替换为你的测试密钥
        #else
        if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
            return key
        }
        return "pk_live_..." // 替换为你的生产密钥
        #endif
    }()
}
```

### 配置方式

**方式一：直接在代码中设置**（测试用）
```swift
return "pk_test_51..." // 你的测试密钥
```

**方式二：使用环境变量**（推荐）
1. 在 Xcode 中：**Product → Scheme → Edit Scheme**
2. 选择 **Run** → **Arguments** → **Environment Variables**
3. 添加：`STRIPE_PUBLISHABLE_KEY` = `pk_test_...`

**方式三：使用 Info.plist**（生产环境）
在 `Info.plist` 中添加：
```xml
<key>STRIPE_PUBLISHABLE_KEY</key>
<string>pk_live_...</string>
```

---

## 第三步：在 TaskDetailView 中添加支付按钮

**已添加代码**，但需要根据业务逻辑调整显示条件。

### 当前实现

在 `TaskDetailView.swift` 中：
- ✅ 已添加 `@State private var showPaymentView = false`
- ✅ 已添加支付 Sheet
- ✅ 支付完成后自动刷新任务详情

### 添加支付按钮

在 `TaskActionButtonsView` 中添加支付按钮（当任务未支付时显示）：

```swift
// 在 TaskActionButtonsView 的 body 中添加
if isPoster && task.isPaid == false {
    Button(action: {
        showPaymentView = true
    }) {
        Label("支付平台服务费", systemImage: "creditcard.fill")
    }
    .buttonStyle(PrimaryButtonStyle())
}
```

**注意**：需要检查 Task 模型是否有 `isPaid` 字段，如果没有需要添加。

---

## 第四步：检查 Task 模型

### 检查是否有 isPaid 字段

文件：`ios/link2ur/link2ur/Models/Task.swift`

如果后端返回 `is_paid` 字段，需要在 Task 模型中添加：

```swift
struct Task: Codable, Identifiable {
    // ... 其他字段
    let isPaid: Int?  // 0 = 未支付, 1 = 已支付
    
    enum CodingKeys: String, CodingKey {
        // ... 其他 keys
        case isPaid = "is_paid"
    }
}
```

---

## 第五步：测试

### 1. 构建项目

```bash
# 在 Xcode 中
⌘ + B  # 构建项目
```

### 2. 检查错误

确保：
- ✅ Stripe SDK 已正确导入
- ✅ 没有编译错误
- ✅ Constants.Stripe.publishableKey 已配置

### 3. 测试支付流程

1. **运行应用**
2. **打开任务详情**（作为发布者）
3. **点击支付按钮**
4. **使用测试卡号**：
   - 卡号：`4242 4242 4242 4242`
   - 日期：任意未来日期（如 12/25）
   - CVC：任意 3 位数字（如 123）
5. **完成支付**
6. **验证任务状态更新**

---

## 常见问题

### 问题 1：找不到 StripePaymentSheet

**错误**：`No such module 'StripePaymentSheet'`

**解决**：
1. 确保已添加 Stripe iOS SDK 依赖
2. 在文件顶部添加：`import StripePaymentSheet`
3. 清理构建：**Product → Clean Build Folder** (⌘ + Shift + K)
4. 重新构建：**Product → Build** (⌘ + B)

### 问题 2：Publishable Key 未设置

**错误**：支付表单无法加载

**解决**：
1. 检查 `Constants.Stripe.publishableKey` 是否正确
2. 确保在 `link2urApp.swift` 的 `onAppear` 中初始化 Stripe
3. 检查环境变量是否正确设置

### 问题 3：支付成功但任务状态未更新

**解决**：
1. 检查 Webhook 是否配置正确
2. 检查后端日志
3. 手动刷新任务详情

---

## 文件清单

### 已创建/修改的文件

- ✅ `ios/link2ur/link2ur/ViewModels/PaymentViewModel.swift` - 支付逻辑
- ✅ `ios/link2ur/link2ur/Views/Payment/StripePaymentView.swift` - 支付界面
- ✅ `ios/link2ur/link2ur/Utils/Constants.swift` - Stripe 配置
- ✅ `ios/link2ur/link2ur/Services/APIEndpoints.swift` - 支付端点
- ✅ `ios/link2ur/link2ur/link2urApp.swift` - Stripe 初始化
- ✅ `ios/link2ur/link2ur/Views/Tasks/TaskDetailView.swift` - 支付按钮集成

---

## 下一步

1. ✅ 添加 Stripe iOS SDK 依赖
2. ✅ 配置 Publishable Key
3. ⚠️ 在 TaskDetailView 中添加支付按钮（根据业务逻辑）
4. ⚠️ 检查/添加 Task.isPaid 字段
5. ⚠️ 测试支付流程

---

**最后更新**：2024年

