import SwiftUI
import WebKit

/// 应用内 WebView 组件
/// 用于在应用内显示网页内容，而不是跳转到外部浏览器
struct InAppWebView: UIViewRepresentable {
    let urlString: String
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // 配置 WebView 以优化性能和减少警告
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 注意：processPool 在 iOS 15+ 已弃用，不再需要手动设置
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // 保存 URL 字符串到 coordinator，用于避免重复加载
        context.coordinator.currentURL = urlString
        
        // 初始加载
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 只有当 URL 改变时才重新加载
        if context.coordinator.currentURL != urlString {
            context.coordinator.currentURL = urlString
            if let url = URL(string: urlString) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var currentURL: String?
        
        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}

/// 用户协议 WebView 视图
struct TermsWebView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) var locale
    @State private var isLoading = true
    
    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                InAppWebView(urlString: "https://www.link2ur.com/terms", isLoading: $isLoading)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .navigationTitle(isChinese ? "用户协议" : "Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

/// 隐私政策 WebView 视图
struct PrivacyWebView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) var locale
    @State private var isLoading = true
    
    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                InAppWebView(urlString: "https://www.link2ur.com/privacy", isLoading: $isLoading)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .navigationTitle(isChinese ? "隐私政策" : "Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

