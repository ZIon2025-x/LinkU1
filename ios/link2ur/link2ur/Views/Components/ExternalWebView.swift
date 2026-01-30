import SwiftUI
import WebKit

/// 通用的外部网站 WebView 组件
/// 用于在应用内显示外部网站，支持验证、登录等操作
struct ExternalWebView: View {
    let url: URL
    let title: String?
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var currentURL: URL?
    @State private var webView: WKWebView?
    
    init(url: URL, title: String? = nil) {
        self.url = url
        self.title = title
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                InAppWebViewWrapper(
                    url: url,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    currentURL: $currentURL,
                    webView: $webView
                )
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("加载中...")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background.opacity(0.8))
                }
            }
            .navigationTitle(title ?? "网页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: {
                            webView?.goBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(canGoBack ? AppColors.primary : AppColors.textTertiary)
                        }
                        .disabled(!canGoBack)
                        
                        Button(action: {
                            webView?.goForward()
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(canGoForward ? AppColors.primary : AppColors.textTertiary)
                        }
                        .disabled(!canGoForward)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}

/// WebView 包装器，用于管理导航状态
struct InAppWebViewWrapper: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: URL?
    @Binding var webView: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // 配置 WebView 以优化性能和减少警告
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 允许 JavaScript（某些验证网站需要）
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // 保存 WebView 引用到 coordinator
        context.coordinator.webView = webView
        
        // 保存 WebView 引用到 binding
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        // 初始加载
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 更新导航按钮状态
        DispatchQueue.main.async {
            canGoBack = webView.canGoBack
            canGoForward = webView.canGoForward
            currentURL = webView.url
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            isLoading: $isLoading,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            currentURL: $currentURL
        )
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var canGoBack: Bool
        @Binding var canGoForward: Bool
        @Binding var currentURL: URL?
        var webView: WKWebView?
        
        init(
            isLoading: Binding<Bool>,
            canGoBack: Binding<Bool>,
            canGoForward: Binding<Bool>,
            currentURL: Binding<URL?>
        ) {
            _isLoading = isLoading
            _canGoBack = canGoBack
            _canGoForward = canGoForward
            _currentURL = currentURL
        }
        
        func goBack() {
            webView?.goBack()
        }
        
        func goForward() {
            webView?.goForward()
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                self.canGoBack = webView.canGoBack
                self.canGoForward = webView.canGoForward
                self.currentURL = webView.url
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                self.canGoBack = webView.canGoBack
                self.canGoForward = webView.canGoForward
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }
        
        // 允许导航到外部链接
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 允许所有导航，包括外部链接
            decisionHandler(.allow)
        }
    }
}

/// 用于显示外部网站的 Sheet 视图
struct ExternalWebViewSheet: ViewModifier {
    @Binding var isPresented: Bool
    let url: URL
    let title: String?
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ExternalWebView(url: url, title: title)
            }
    }
}

extension View {
    /// 添加外部 WebView Sheet 的便捷方法
    func externalWebView(isPresented: Binding<Bool>, url: URL, title: String? = nil) -> some View {
        modifier(ExternalWebViewSheet(isPresented: isPresented, url: url, title: title))
    }
}

