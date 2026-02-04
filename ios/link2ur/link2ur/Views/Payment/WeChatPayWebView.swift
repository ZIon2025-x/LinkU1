import SwiftUI
import WebKit

/// 微信支付 WebView 组件
/// 用于显示 Stripe Checkout 页面，让用户扫描二维码完成微信支付
/// 
/// 原因：Stripe iOS PaymentSheet 不支持微信支付（官方文档确认）
/// 解决方案：通过 WebView 加载 Stripe Checkout Session URL，与 Web 端体验一致
struct WeChatPayWebView: View {
    let checkoutURL: String
    let onPaymentSuccess: () -> Void
    let onPaymentCancel: () -> Void
    let onPaymentError: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showCancelConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // WebView
                WeChatPayWebViewRepresentable(
                    urlString: checkoutURL,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    onPaymentSuccess: {
                        Logger.info("微信支付 WebView 检测到支付成功", category: .api)
                        onPaymentSuccess()
                        dismiss()
                    },
                    onPaymentCancel: {
                        Logger.info("微信支付 WebView 检测到用户取消", category: .api)
                        onPaymentCancel()
                        dismiss()
                    }
                )
                .edgesIgnoringSafeArea(.bottom)
                
                // 加载指示器
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(LocalizationKey.wechatPayLoading.localized)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background.opacity(0.9))
                }
                
                // 加载错误
                if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.error)
                        
                        Text(LocalizationKey.wechatPayLoadFailed.localized)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            loadError = nil
                            isLoading = true
                            // WebView 会自动重新加载
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text(LocalizationKey.commonRetry.localized)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        .padding(.top, 8)
                        
                        Button(action: {
                            onPaymentError(error)
                            dismiss()
                        }) {
                            Text(LocalizationKey.commonBack.localized)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
                }
            }
            .navigationTitle(LocalizationKey.wechatPayTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCancelConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .alert(LocalizationKey.wechatPayCancelConfirmTitle.localized, isPresented: $showCancelConfirmation) {
                Button(LocalizationKey.wechatPayContinuePay.localized, role: .cancel) { }
                Button(LocalizationKey.wechatPayCancelPay.localized, role: .destructive) {
                    onPaymentCancel()
                    dismiss()
                }
            } message: {
                Text(LocalizationKey.wechatPayCancelWarning.localized)
            }
        }
    }
}

/// WKWebView 的 SwiftUI 包装器
struct WeChatPayWebViewRepresentable: UIViewRepresentable {
    let urlString: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    let onPaymentSuccess: () -> Void
    let onPaymentCancel: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        // 配置 JavaScript 消息处理
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "paymentCallback")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = true
        
        // 设置 User-Agent 以支持移动端显示
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        // 加载 Checkout URL
        if let url = URL(string: urlString) {
            Logger.debug("微信支付 WebView 加载 URL: \(urlString.prefix(50))...", category: .api)
            webView.load(URLRequest(url: url))
        } else {
            Logger.error("微信支付 WebView URL 无效: \(urlString)", category: .api)
            DispatchQueue.main.async {
                self.loadError = LocalizationKey.wechatPayInvalidLink.localized
                self.isLoading = false
            }
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 如果需要重新加载（错误后重试）
        if loadError == nil && isLoading && webView.url == nil {
            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WeChatPayWebViewRepresentable
        
        init(_ parent: WeChatPayWebViewRepresentable) {
            self.parent = parent
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Logger.debug("微信支付 WebView 开始加载", category: .api)
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.debug("微信支付 WebView 加载完成", category: .api)
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger.error("微信支付 WebView 加载失败: \(error.localizedDescription)", category: .api)
            DispatchQueue.main.async {
                self.parent.loadError = error.localizedDescription
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Logger.error("微信支付 WebView 预加载失败: \(error.localizedDescription)", category: .api)
            DispatchQueue.main.async {
                self.parent.loadError = error.localizedDescription
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            let urlString = url.absoluteString.lowercased()
            Logger.debug("微信支付 WebView 导航到: \(urlString.prefix(100))...", category: .api)
            
            // 检测支付成功的 URL（Stripe Checkout 成功后会重定向到 success_url）
            if urlString.contains("payment-success") || urlString.contains("payment_success") || urlString.contains("/success") {
                Logger.info("微信支付 WebView 检测到成功 URL: \(urlString.prefix(100))...", category: .api)
                DispatchQueue.main.async {
                    self.parent.onPaymentSuccess()
                }
                decisionHandler(.cancel)
                return
            }
            
            // 检测支付取消的 URL
            if urlString.contains("payment-cancel") || urlString.contains("payment_cancel") || urlString.contains("/cancel") {
                Logger.info("微信支付 WebView 检测到取消 URL: \(urlString.prefix(100))...", category: .api)
                DispatchQueue.main.async {
                    self.parent.onPaymentCancel()
                }
                decisionHandler(.cancel)
                return
            }
            
            // 允许其他导航
            decisionHandler(.allow)
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // 处理来自 JavaScript 的消息（可选，用于更精确的回调）
            Logger.debug("微信支付 WebView 收到 JS 消息: \(message.name) - \(message.body)", category: .api)
            
            if message.name == "paymentCallback" {
                if let body = message.body as? [String: Any],
                   let status = body["status"] as? String {
                    switch status {
                    case "success":
                        DispatchQueue.main.async {
                            self.parent.onPaymentSuccess()
                        }
                    case "cancel":
                        DispatchQueue.main.async {
                            self.parent.onPaymentCancel()
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WeChatPayWebView(
        checkoutURL: "https://checkout.stripe.com/test",
        onPaymentSuccess: { print("Success") },
        onPaymentCancel: { print("Cancel") },
        onPaymentError: { error in print("Error: \(error)") }
    )
}
