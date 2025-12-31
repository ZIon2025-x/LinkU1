import SwiftUI
import WebKit
import Foundation
import Combine

struct StripeConnectOnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = StripeConnectOnboardingViewModel()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else if viewModel.isCompleted {
                    completedView
                } else if let secret = viewModel.clientSecret {
                    StripeConnectWebView(
                        clientSecret: secret,
                        onComplete: {
                            viewModel.checkAccountStatus()
                        },
                        onError: { error in
                            viewModel.error = error
                        }
                    )
                }
            }
        }
        .navigationTitle("设置收款账户")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadOnboardingSession()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.loadOnboardingSession()
            }) {
                Text("重试")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("收款账户已设置完成")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text("您可以开始接收任务奖励了")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            Button(action: {
                dismiss()
            }) {
                Text("完成")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StripeConnectWebView: UIViewRepresentable {
    let clientSecret: String
    let onComplete: () -> Void
    let onError: (String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 使用新的 API 替代已弃用的 javaScriptEnabled
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // 构建包含 Stripe Connect Embedded 的 HTML
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin: 0;
                    padding: 20px;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background-color: #f5f5f5;
                }
                #connect-embedded {
                    width: 100%;
                    min-height: 600px;
                }
            </style>
            <script src="https://js.stripe.com/v3/"></script>
        </head>
        <body>
            <div id="connect-embedded"></div>
            <script>
                const stripe = Stripe('\(getStripePublishableKey())');
                
                // 动态加载 Connect Embedded
                const script = document.createElement('script');
                script.src = 'https://js.stripe.com/connect-embedded/v1/';
                script.async = true;
                script.onload = function() {
                    if (window.Stripe && window.Stripe.ConnectEmbedded) {
                        const connectEmbedded = new window.Stripe.ConnectEmbedded({
                            clientSecret: '\(clientSecret)',
                            onReady: function() {
                                console.log('Onboarding ready');
                            },
                            onComplete: function() {
                                console.log('Onboarding completed');
                                window.webkit.messageHandlers.onboardingComplete.postMessage('completed');
                            },
                            onExit: function(event) {
                                console.log('User exited onboarding', event);
                            },
                            onError: function(event) {
                                console.error('Onboarding error:', event);
                                const errorMsg = event.error ? event.error.message : '设置过程中发生错误';
                                window.webkit.messageHandlers.onboardingError.postMessage(errorMsg);
                            }
                        });
                        connectEmbedded.mount('#connect-embedded');
                    }
                };
                document.head.appendChild(script);
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onError: onError)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onComplete: () -> Void
        let onError: (String) -> Void
        
        init(onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
            self.onComplete = onComplete
            self.onError = onError
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 添加消息处理器
            let contentController = webView.configuration.userContentController
            contentController.add(self, name: "onboardingComplete")
            contentController.add(self, name: "onboardingError")
        }
    }
    
    private func getStripePublishableKey() -> String {
        // 使用 Constants 中配置的 Stripe Publishable Key
        return Constants.Stripe.publishableKey
    }
}

extension StripeConnectWebView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "onboardingComplete" {
            DispatchQueue.main.async {
                self.onComplete()
            }
        } else if message.name == "onboardingError" {
            if let error = message.body as? String {
                DispatchQueue.main.async {
                    self.onError(error)
                }
            }
        }
    }
}

class StripeConnectOnboardingViewModel: ObservableObject {
    @Published var clientSecret: String?
    @Published var isLoading = true
    @Published var error: String?
    @Published var isCompleted = false
    
    private let apiService = APIService.shared
    
    func loadOnboardingSession() {
        isLoading = true
        error = nil
        
        // 使用 APIService 的 request 方法
        struct OnboardingResponse: Codable {
            let account_id: String
            let client_secret: String?
            let account_status: Bool
            let charges_enabled: Bool
            let message: String
        }
        
        apiService.request(OnboardingResponse.self, "/api/stripe/connect/account/create-embedded", method: "POST", body: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let apiError) = completion {
                        self?.error = apiError.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.isLoading = false
                    if let clientSecret = response.client_secret, !clientSecret.isEmpty {
                        self?.clientSecret = clientSecret
                    } else if response.account_status && response.charges_enabled {
                        self?.isCompleted = true
                    } else {
                        self?.error = "无法创建 onboarding session"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func checkAccountStatus() {
        struct StatusResponse: Codable {
            let account_id: String
            let details_submitted: Bool
            let charges_enabled: Bool
            let payouts_enabled: Bool
            let needs_onboarding: Bool
        }
        
        apiService.request(StatusResponse.self, "/api/stripe/connect/account/status", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] response in
                    if response.charges_enabled {
                        self?.isCompleted = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}

