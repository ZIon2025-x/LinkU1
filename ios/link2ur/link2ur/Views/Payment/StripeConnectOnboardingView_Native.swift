import SwiftUI
import StripeConnect
import UIKit
import Combine

/// 使用 Stripe Connect 原生 SDK 的 Onboarding 视图
struct StripeConnectOnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = StripeConnectOnboardingViewModel()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            stateBasedView
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
        .onChange(of: viewModel.error) { newError in
            if let error = newError {
                errorMessage = error
                showError = true
            }
        }
    }
    
    @ViewBuilder
    private var stateBasedView: some View {
        switch viewModel.viewState {
        case .loading:
            loadingView
        case .error(let message):
            errorView(error: message)
        case .completed:
            completedView
        case .ready(let secret):
            // 使用原生 AccountOnboardingController
            AccountOnboardingControllerWrapper(
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

/// 将 UIKit 的 AccountOnboardingController 包装为 SwiftUI View
struct AccountOnboardingControllerWrapper: UIViewControllerRepresentable {
    let clientSecret: String
    let onComplete: () -> Void
    let onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        // 设置 Stripe Publishable Key
        STPAPIClient.shared.publishableKey = Constants.Stripe.publishableKey
        
        // 创建 fetchClientSecret 闭包
        let fetchClientSecret: () async -> String? = {
            // 直接返回已有的 clientSecret
            return clientSecret
        }
        
        // 创建 EmbeddedComponentManager
        let embeddedComponentManager = EmbeddedComponentManager(
            fetchClientSecret: fetchClientSecret
        )
        
        // 创建 AccountOnboardingController
        let controller = embeddedComponentManager.createAccountOnboardingController()
        controller.delegate = context.coordinator
        controller.title = "设置收款账户"
        
        // 包装在 UINavigationController 中以便显示
        let navController = UINavigationController(rootViewController: controller)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 不需要更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onError: onError)
    }
    
    class Coordinator: NSObject, AccountOnboardingControllerDelegate {
        let onComplete: () -> Void
        let onError: (String) -> Void
        
        init(onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
            self.onComplete = onComplete
            self.onError = onError
        }
        
        // MARK: - AccountOnboardingControllerDelegate
        
        func accountOnboarding(_ accountOnboarding: AccountOnboardingController, didCompleteWith account: STPConnectAccount) {
            print("✅ Account onboarding completed")
            DispatchQueue.main.async {
                self.onComplete()
            }
        }
        
        func accountOnboarding(_ accountOnboarding: AccountOnboardingController, didCancelWith account: STPConnectAccount?) {
            print("ℹ️ Account onboarding canceled")
            // 用户取消，不需要处理
        }
        
        func accountOnboarding(_ accountOnboarding: AccountOnboardingController, didFailWith error: Error) {
            print("❌ Account onboarding failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.onError(error.localizedDescription)
            }
        }
        
        func accountOnboarding(_ accountOnboarding: AccountOnboardingController, didFailLoadWithError error: Error) {
            print("❌ Account onboarding failed to load: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.onError("加载失败: \(error.localizedDescription)")
            }
        }
    }
}

/// ViewModel 保持不变，但可以优化
class StripeConnectOnboardingViewModel: ObservableObject {
    @Published var clientSecret: String?
    @Published var isLoading = true
    @Published var error: String?
    @Published var isCompleted = false
    
    private let apiService = APIService.shared
    
    var viewState: OnboardingViewState {
        if isLoading {
            return .loading
        } else if let error = error {
            return .error(error)
        } else if isCompleted {
            return .completed
        } else if let secret = clientSecret {
            return .ready(secret)
        } else {
            return .loading
        }
    }
    
    func loadOnboardingSession() {
        isLoading = true
        error = nil
        
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
                        var errorMessage = apiError.localizedDescription
                        if case .httpError(let code) = apiError {
                            errorMessage = "请求失败 (HTTP \(code))"
                        }
                        self?.error = errorMessage
                        print("❌ Stripe Connect 创建失败: \(errorMessage)")
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

enum OnboardingViewState {
    case loading
    case error(String)
    case completed
    case ready(String) // clientSecret
}

