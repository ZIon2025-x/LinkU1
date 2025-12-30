# iOS Stripe 嵌入式支付集成指南

## 当前状态

### ✅ 前端（Web）- 已实现嵌入式支付

前端已经使用 **Stripe Elements** 实现嵌入式支付：

- ✅ 使用 `@stripe/react-stripe-js` 的 `CardElement`
- ✅ 支付表单嵌入在页面中，无需跳转
- ✅ 使用 Payment Intent API
- ✅ 完全符合 PCI DSS 合规要求

**代码位置**：`frontend/src/components/payment/StripePaymentForm.tsx`

### ⚠️ iOS - 目前使用 WebView

iOS 应用目前：
- ✅ 可以使用 `InAppWebView` 加载 Web 支付页面
- ❌ **未集成 Stripe iOS SDK**
- ❌ 无法原生嵌入式支付

---

## iOS 嵌入式支付集成方案

### 方案一：使用 Stripe iOS SDK（推荐，原生体验）

#### 优点
- ✅ 原生 UI，用户体验更好
- ✅ 支持 Apple Pay
- ✅ 更快的支付流程
- ✅ 完全嵌入在应用中

#### 实现步骤

### 1. 添加 Stripe iOS SDK

**使用 Swift Package Manager**：

1. 在 Xcode 中打开项目
2. 选择项目 → **Package Dependencies**
3. 点击 **"+"** 添加包
4. 输入 URL：`https://github.com/stripe/stripe-ios`
5. 选择版本：`25.3.1` 或更高（推荐使用最新版本）
6. 添加到 target

**或使用 CocoaPods**：

在 `Podfile` 中添加：
```ruby
pod 'StripePaymentSheet', '~> 25.3'
```

然后运行：
```bash
pod install
```

### 2. 创建支付视图

创建新文件：`ios/link2ur/link2ur/Views/Payment/StripePaymentView.swift`

```swift
import SwiftUI
import Stripe
import StripePaymentSheet

struct StripePaymentView: View {
    @StateObject private var viewModel: PaymentViewModel
    @Environment(\.dismiss) var dismiss
    
    let taskId: Int
    let amount: Double
    
    init(taskId: Int, amount: Double) {
        self.taskId = taskId
        self.amount = amount
        _viewModel = StateObject(wrappedValue: PaymentViewModel(taskId: taskId, amount: amount))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("正在加载支付表单...")
                } else if let paymentSheet = viewModel.paymentSheet {
                    PaymentSheetView(paymentSheet: paymentSheet, onSuccess: {
                        viewModel.handlePaymentSuccess()
                        dismiss()
                    })
                } else if let error = viewModel.error {
                    VStack {
                        Text("支付错误")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.red)
                        Button("重试") {
                            viewModel.createPaymentIntent()
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("支付")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.createPaymentIntent()
            }
        }
    }
}

// Payment Sheet 包装器
struct PaymentSheetView: UIViewControllerRepresentable {
    let paymentSheet: PaymentSheet
    let onSuccess: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            paymentSheet.present(from: vc) { result in
                switch result {
                case .completed:
                    onSuccess()
                case .failed(let error):
                    print("Payment failed: \(error)")
                case .canceled:
                    print("Payment canceled")
                }
            }
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
```

### 3. 创建支付 ViewModel

创建新文件：`ios/link2ur/link2ur/ViewModels/PaymentViewModel.swift`

```swift
import Foundation
import Stripe
import StripePaymentSheet

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var paymentSheet: PaymentSheet?
    @Published var error: String?
    
    private let taskId: Int
    private let amount: Double
    private let publishableKey = "pk_test_..." // 从环境变量或配置读取
    
    init(taskId: Int, amount: Double) {
        self.taskId = taskId
        self.amount = amount
        
        // 配置 Stripe
        StripeAPI.defaultPublishableKey = publishableKey
    }
    
    func createPaymentIntent() {
        isLoading = true
        error = nil
        
        // 调用后端 API 创建 Payment Intent
        let url = URL(string: "https://api.link2ur.com/api/coupon-points/tasks/\(taskId)/payment")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证 token
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "payment_method": "stripe"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let clientSecret = json["client_secret"] as? String else {
                    self.error = "无法创建支付"
                    return
                }
                
                // 创建 Payment Sheet
                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "LinkU"
                configuration.allowsDelayedPaymentMethods = true
                
                self.paymentSheet = PaymentSheet(
                    paymentIntentClientSecret: clientSecret,
                    configuration: configuration
                )
            }
        }.resume()
    }
    
    func handlePaymentSuccess() {
        // 处理支付成功
        // 可以发送通知或更新 UI
    }
}
```

### 4. 配置 Publishable Key

在 `ios/link2ur/link2ur/Utils/Constants.swift` 中添加：

```swift
struct Constants {
    // ... 其他常量
    
    struct Stripe {
        static let publishableKey = "pk_test_..." // 测试环境
        // 生产环境：pk_live_...
    }
}
```

**或从环境变量读取**（推荐）：

```swift
struct Constants {
    struct Stripe {
        static let publishableKey: String = {
            #if DEBUG
            return ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"] ?? "pk_test_..."
            #else
            return ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"] ?? "pk_live_..."
            #endif
        }()
    }
}
```

### 5. 在任务详情中使用

在任务详情视图中添加支付按钮：

```swift
// 在 TaskDetailView.swift 中
Button("支付") {
    // 显示支付视图
    showingPayment = true
}
.sheet(isPresented: $showingPayment) {
    StripePaymentView(taskId: task.id, amount: task.amount)
}
```

### 6. 处理支付回调

在 `AppDelegate` 或主 App 文件中处理支付结果：

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Stripe 支付回调
    if url.scheme == "your-app-scheme" {
        // 处理支付结果
        return true
    }
    return false
}
```

---

## 方案二：继续使用 WebView（简单，但体验稍差）

如果暂时不想集成原生 SDK，可以继续使用 WebView：

```swift
struct PaymentWebView: View {
    let taskId: Int
    let paymentURL: URL
    
    var body: some View {
        InAppWebView(url: paymentURL)
    }
}

// 使用
let paymentURL = URL(string: "https://www.link2ur.com/en/tasks/\(taskId)/payment")!
PaymentWebView(taskId: taskId, paymentURL: paymentURL)
```

**优点**：
- ✅ 无需额外开发
- ✅ 使用现有的 Web 支付页面
- ✅ 维护简单

**缺点**：
- ❌ 体验不如原生
- ❌ 无法使用 Apple Pay
- ❌ 需要加载网页

---

## 推荐方案

### 短期（快速上线）
- ✅ **使用 WebView**：快速实现，无需额外开发

### 长期（优化体验）
- ✅ **集成 Stripe iOS SDK**：提供更好的用户体验

---

## 环境变量配置

### 开发环境
在 Xcode Scheme 中配置环境变量：
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. 添加：`STRIPE_PUBLISHABLE_KEY=pk_test_...`

### 生产环境
在 Xcode Build Settings 或 Info.plist 中配置

---

## 测试

### 测试卡号
- `4242 4242 4242 4242` - 成功支付
- `4000 0025 0000 3155` - 需要 3D Secure
- `4000 0000 0000 0002` - 支付失败

### 测试步骤
1. 在 iOS 应用中打开任务详情
2. 点击支付按钮
3. 使用测试卡号完成支付
4. 验证支付成功

---

## 总结

- ✅ **前端（Web）**：已实现嵌入式支付（Stripe Elements）
- ⚠️ **iOS**：目前使用 WebView，可以集成 Stripe iOS SDK 实现原生嵌入式支付

**建议**：
1. 先使用 WebView 方案快速上线
2. 后续集成 Stripe iOS SDK 优化体验

---

**最后更新**：2024年

