import SwiftUI
import WebKit

/// CAPTCHA WebView 组件
/// 支持 Google reCAPTCHA v2 和 hCaptcha
struct CaptchaWebView: UIViewRepresentable {
    let siteKey: String
    let captchaType: String  // "recaptcha" 或 "hcaptcha"
    let onVerify: (String) -> Void  // 验证成功回调，返回 token
    let onError: ((String) -> Void)?  // 错误回调
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let coordinator = context.coordinator
        
        // 配置 WebView 以允许加载外部资源
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 使用共享的进程池，避免创建过多进程
        if configuration.processPool == nil {
            configuration.processPool = WKProcessPool()
        }
        
        // 添加消息处理器
        let messageHandler = CaptchaMessageHandler(
            onVerify: coordinator.onVerify,
            onError: coordinator.onError ?? { _ in }
        )
        configuration.userContentController.add(messageHandler, name: "captchaCallback")
        
        // 允许加载外部脚本和资源
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        
        // 配置 WebView
        webView.backgroundColor = .white
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .white
        
        // 保存 messageHandler 引用
        coordinator.messageHandler = messageHandler
        
        // 获取后端 API 的 baseURL 作为 baseURL（用于域名验证）
        // reCAPTCHA 需要验证域名，所以必须使用与 site key 配置匹配的域名
        // 通常应该是前端域名（www.link2ur.com）而不是 API 域名
        let baseURL = URL(string: Constants.Frontend.baseURL) ?? URL(string: "https://www.link2ur.com")!
        
        // 加载 CAPTCHA HTML
        let html = generateCaptchaHTML(siteKey: siteKey, type: captchaType)
        webView.loadHTMLString(html, baseURL: baseURL)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 如果 siteKey 或 type 改变，重新加载
        // 注意：由于 WebView 是单例，这里不需要重新加载
        // 如果需要重新加载，可以在这里实现
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onVerify: onVerify, onError: onError)
    }
    
    /// 生成 CAPTCHA HTML
    private func generateCaptchaHTML(siteKey: String, type: String) -> String {
        if type == "recaptcha" {
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    * {
                        box-sizing: border-box;
                    }
                    html, body {
                        margin: 0;
                        padding: 0;
                        width: 100%;
                        height: 100%;
                        background-color: #f5f5f5;
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        overflow: hidden;
                    }
                    .captcha-container {
                        background: white;
                        padding: 20px;
                        border-radius: 8px;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                        width: 100%;
                        max-width: 400px;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                    }
                    .loading {
                        text-align: center;
                        color: #666;
                        padding: 20px;
                    }
                </style>
            </head>
            <body>
                <div class="captcha-container">
                    <div id="loading" class="loading">正在加载验证码...</div>
                    <div id="recaptcha" class="g-recaptcha" data-sitekey="\(siteKey)" data-callback="onCaptchaSuccess" data-expired-callback="onCaptchaExpired" style="display: none;"></div>
                </div>
                <script src="https://www.google.com/recaptcha/api.js?onload=onRecaptchaLoad&render=explicit" async defer></script>
                <script>
                    function onRecaptchaLoad() {
                        console.log('reCAPTCHA 脚本加载完成');
                        var loading = document.getElementById('loading');
                        var recaptcha = document.getElementById('recaptcha');
                        if (loading) loading.style.display = 'none';
                        if (recaptcha) recaptcha.style.display = 'block';
                        
                        // 手动渲染 reCAPTCHA
                        if (typeof grecaptcha !== 'undefined') {
                            grecaptcha.render('recaptcha', {
                                'sitekey': '\(siteKey)',
                                'callback': onCaptchaSuccess,
                                'expired-callback': onCaptchaExpired
                            });
                        }
                    }
                    
                    function onCaptchaSuccess(token) {
                        console.log('reCAPTCHA 验证成功');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.captchaCallback) {
                            window.webkit.messageHandlers.captchaCallback.postMessage({type: 'success', token: token});
                        }
                    }
                    
                    function onCaptchaExpired() {
                        console.log('reCAPTCHA 验证已过期');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.captchaCallback) {
                            window.webkit.messageHandlers.captchaCallback.postMessage({type: 'expired'});
                        }
                    }
                    
                    // 错误处理
                    window.addEventListener('error', function(e) {
                        console.error('页面错误:', e.message);
                    });
                </script>
            </body>
            </html>
            """
        } else if type == "hcaptcha" {
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    * {
                        box-sizing: border-box;
                    }
                    html, body {
                        margin: 0;
                        padding: 0;
                        width: 100%;
                        height: 100%;
                        background-color: #f5f5f5;
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        overflow: hidden;
                    }
                    .captcha-container {
                        background: white;
                        padding: 20px;
                        border-radius: 8px;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                        width: 100%;
                        max-width: 400px;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                    }
                    .loading {
                        text-align: center;
                        color: #666;
                        padding: 20px;
                    }
                </style>
                <script src="https://js.hcaptcha.com/1/api.js" async defer onload="onHcaptchaLoad()"></script>
            </head>
            <body>
                <div class="captcha-container">
                    <div id="loading" class="loading">正在加载验证码...</div>
                    <div id="hcaptcha" class="h-captcha" data-sitekey="\(siteKey)" data-callback="onCaptchaSuccess" data-expired-callback="onCaptchaExpired" style="display: none;"></div>
                </div>
                <script>
                    function onHcaptchaLoad() {
                        console.log('hCaptcha 脚本加载完成');
                        var loading = document.getElementById('loading');
                        var hcaptcha = document.getElementById('hcaptcha');
                        if (loading) loading.style.display = 'none';
                        if (hcaptcha) hcaptcha.style.display = 'block';
                    }
                    
                    function onCaptchaSuccess(token) {
                        console.log('hCaptcha 验证成功');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.captchaCallback) {
                            window.webkit.messageHandlers.captchaCallback.postMessage({type: 'success', token: token});
                        }
                    }
                    
                    function onCaptchaExpired() {
                        console.log('hCaptcha 验证已过期');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.captchaCallback) {
                            window.webkit.messageHandlers.captchaCallback.postMessage({type: 'expired'});
                        }
                    }
                    
                    // 错误处理
                    window.addEventListener('error', function(e) {
                        console.error('页面错误:', e.message);
                    });
                </script>
            </body>
            </html>
            """
        } else {
            return """
            <!DOCTYPE html>
            <html>
            <body>
                <p>不支持的 CAPTCHA 类型</p>
            </body>
            </html>
            """
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onVerify: (String) -> Void
        let onError: ((String) -> Void)?
        var messageHandler: CaptchaMessageHandler?
        
        init(onVerify: @escaping (String) -> Void, onError: ((String) -> Void)?) {
            self.onVerify = onVerify
            self.onError = onError
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // WebView 开始加载
            print("🔍 CAPTCHA WebView 开始加载")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // WebView 加载完成
            print("✅ CAPTCHA WebView 加载完成")
            // 消息处理器已经在 makeUIView 中设置
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // WebView 加载失败
            print("❌ CAPTCHA WebView 加载失败: \(error.localizedDescription)")
            onError?("加载失败: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // WebView 初始加载失败
            print("❌ CAPTCHA WebView 初始加载失败: \(error.localizedDescription)")
            onError?("加载失败: \(error.localizedDescription)")
        }
        
        // 允许导航到外部链接（reCAPTCHA 需要加载 Google 的资源）
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 允许所有导航，包括外部资源
            decisionHandler(.allow)
        }
        
        deinit {
            // 清理消息处理器
            messageHandler = nil
        }
    }
}

/// CAPTCHA 消息处理器
class CaptchaMessageHandler: NSObject, WKScriptMessageHandler {
    let onVerify: (String) -> Void
    let onError: (String) -> Void
    
    init(onVerify: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onVerify = onVerify
        self.onError = onError
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            onError("无效的消息格式")
            return
        }
        
        if type == "success", let token = body["token"] as? String {
            onVerify(token)
        } else if type == "expired" {
            onError("验证已过期，请重新验证")
        } else {
            onError("验证失败")
        }
    }
}

