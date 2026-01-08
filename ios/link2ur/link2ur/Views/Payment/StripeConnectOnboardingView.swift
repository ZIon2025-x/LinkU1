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
    @State private var showWebView = false
    @State private var webViewURL: URL?
    @State private var webViewTitle: String?
    
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
        .sheet(isPresented: $showWebView) {
            if let url = webViewURL {
                ExternalWebView(url: url, title: webViewTitle)
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
        case .accountDetails(let details):
            accountDetailsView(details: details)
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
    
    private func accountDetailsView(details: StripeConnectAccountDetails) -> some View {
        AccountDetailsViewContent(
            details: details,
            externalAccounts: viewModel.externalAccounts,
            onRefresh: {
                viewModel.loadAccountDetails()
            },
            onOpenDashboard: {
                if let dashboardUrl = details.dashboardUrl, let url = URL(string: dashboardUrl) {
                    webViewURL = url
                    webViewTitle = "Stripe 仪表板"
                    showWebView = true
                }
            }
        )
    }
}

/// 账户详情内容视图（可复用）
struct AccountDetailsViewContent: View {
    @Environment(\.dismiss) var dismiss
    let details: StripeConnectAccountDetails
    let externalAccounts: [ExternalAccount]
    let onRefresh: () -> Void
    let onOpenDashboard: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 账户状态提示
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("收款账户已设置")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("您的账户信息如下")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, AppSpacing.xl)
                
                // 账户信息卡片
                AccountInfoSection(details: details, onOpenDashboard: onOpenDashboard)
                    .padding(.horizontal, AppSpacing.md)
                
                // 外部账户（如果有）
                if !externalAccounts.isEmpty {
                    ExternalAccountsSection(accounts: externalAccounts)
                        .padding(.horizontal, AppSpacing.md)
                }
                
                // 操作按钮
                VStack(spacing: AppSpacing.md) {
                    Button(action: {
                        onRefresh()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("刷新账户信息")
                        }
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                                .stroke(AppColors.primary, lineWidth: 1)
                        )
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("完成")
                            .font(AppTypography.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(AppCornerRadius.large)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }
}

/// 将 UIKit 的 AccountOnboardingController 包装为 SwiftUI View
struct AccountOnboardingControllerWrapper: UIViewControllerRepresentable {
    let clientSecret: String
    let onComplete: () -> Void
    let onError: (String) -> Void
    
    // 可选的高级配置
    // 注意：collectionOptions 的类型取决于 Stripe iOS SDK 的实际实现
    // 如果 SDK 不支持，可以注释掉或使用正确的类型
    // var collectionOptions: AccountCollectionOptions? = nil
    var fullTermsOfServiceURL: URL? = nil
    var recipientTermsOfServiceURL: URL? = nil
    var privacyPolicyURL: URL? = nil
    
    func makeUIViewController(context: Context) -> ContainerViewController {
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
        // 根据 Stripe iOS SDK 文档，支持以下可选参数：
        // - fullTermsOfServiceUrl: 完整服务条款 URL
        // - recipientTermsOfServiceUrl: 收款方服务条款 URL
        // - privacyPolicyUrl: 隐私政策 URL
        // - collectionOptions: 收集选项（字段、未来需求、需求限制等）
        //
        // 注意：根据实际 SDK 版本，API 签名可能有所不同
        // 如果编译错误，请检查 SDK 文档并调整参数
        
        // 使用默认的 Terms 和 Privacy URL（如果未提供）
        let fullTermsURL = fullTermsOfServiceURL ?? Constants.Stripe.ConnectOnboarding.fullTermsOfServiceURL
        let recipientTermsURL = recipientTermsOfServiceURL ?? Constants.Stripe.ConnectOnboarding.recipientTermsOfServiceURL
        let privacyURL = privacyPolicyURL ?? Constants.Stripe.ConnectOnboarding.privacyPolicyURL
        
        // 创建 controller
        // 注意：如果 SDK 不支持这些参数，请使用无参数版本：
        // let controller = embeddedComponentManager.createAccountOnboardingController()
        let controller = embeddedComponentManager.createAccountOnboardingController(
            fullTermsOfServiceUrl: fullTermsURL,
            recipientTermsOfServiceUrl: recipientTermsURL,
            privacyPolicyUrl: privacyURL
        )
        
        // 如果提供了 collectionOptions，可以通过 controller 的属性设置
        // 注意：这取决于 SDK 的实际实现
        // if let collectionOptions = collectionOptions {
        //     // 根据 SDK 文档设置 collectionOptions
        // }
        
        controller.delegate = context.coordinator
        controller.title = "设置收款账户"
        
        // 创建容器视图控制器来持有和展示 AccountOnboardingController
        let containerVC = ContainerViewController()
        containerVC.accountOnboardingController = controller
        
        return containerVC
    }
    
    func updateUIViewController(_ uiViewController: ContainerViewController, context: Context) {
        // 不需要更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onError: onError)
    }
    
    /// 容器视图控制器，用于展示 AccountOnboardingController
    class ContainerViewController: UIViewController {
        var accountOnboardingController: AccountOnboardingController?
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            // 在视图出现后展示 AccountOnboardingController
            if let controller = accountOnboardingController {
                controller.present(from: self)
            }
        }
    }
    
    class Coordinator: NSObject, AccountOnboardingControllerDelegate {
        let onComplete: () -> Void
        let onError: (String) -> Void
        
        init(onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
            self.onComplete = onComplete
            self.onError = onError
        }
        
        // MARK: - AccountOnboardingControllerDelegate
        
        func accountOnboarding(_ accountOnboarding: AccountOnboardingController, didCompleteWith account: Any) {
            print("✅ Account onboarding completed")
            DispatchQueue.main.async {
                self.onComplete()
            }
        }
        
        func accountOnboarding(_ accountOnboarding: AccountOnboardingController, didCancelWith account: Any?) {
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
    @Published var accountDetails: StripeConnectAccountDetails?
    @Published var externalAccounts: [ExternalAccount] = []
    
    private let apiService = APIService.shared
    
    var viewState: OnboardingViewState {
        if isLoading {
            return .loading
        } else if let error = error {
            return .error(error)
        } else if isCompleted {
            return .completed
        } else if let details = accountDetails {
            return .accountDetails(details)
        } else if let secret = clientSecret {
            return .ready(secret)
        } else {
            return .loading
        }
    }
    
    func loadOnboardingSession() {
        isLoading = true
        error = nil
        
        // 先检查账户状态
        struct StatusResponse: Codable {
            let account_id: String?
            let details_submitted: Bool
            let charges_enabled: Bool
            let payouts_enabled: Bool
            let needs_onboarding: Bool
        }
        
        apiService.request(StatusResponse.self, "/api/stripe/connect/account/status", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        // 如果获取状态失败，尝试创建账户
                        self?.createOnboardingSession()
                    }
                },
                receiveValue: { [weak self] statusResponse in
                    // 如果账户已存在且已完成设置，加载账户详情
                    if statusResponse.account_id != nil, 
                       statusResponse.details_submitted && statusResponse.charges_enabled {
                        self?.loadAccountDetails()
                    } else {
                        // 否则创建或获取 onboarding session
                        self?.createOnboardingSession()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func createOnboardingSession() {
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
    
    func loadAccountDetails() {
        struct AccountDetailsResponse: Codable {
            let account_id: String
            let display_name: String?
            let email: String?
            let country: String
            let type: String
            let details_submitted: Bool
            let charges_enabled: Bool
            let payouts_enabled: Bool
            let dashboard_url: String?
            let address: StripeConnectAddress?
            let individual: StripeConnectIndividual?
        }
        
        apiService.request(
            AccountDetailsResponse.self,
            "/api/stripe/connect/account/details",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let apiError) = completion {
                    var errorMessage = apiError.localizedDescription
                    if case .httpError(let code) = apiError {
                        if code == 404 {
                            // 账户不存在，继续创建流程
                            return
                        }
                        errorMessage = "获取账户详情失败 (HTTP \(code))"
                    }
                    self?.error = errorMessage
                    print("❌ 获取账户详情失败: \(errorMessage)")
                }
            },
            receiveValue: { [weak self] response in
                self?.isLoading = false
                self?.accountDetails = StripeConnectAccountDetails(
                    accountId: response.account_id,
                    displayName: response.display_name,
                    email: response.email,
                    country: response.country,
                    type: response.type,
                    detailsSubmitted: response.details_submitted,
                    chargesEnabled: response.charges_enabled,
                    payoutsEnabled: response.payouts_enabled,
                    dashboardUrl: response.dashboard_url,
                    address: response.address,
                    individual: response.individual
                )
                self?.loadExternalAccounts()
            }
        )
        .store(in: &cancellables)
    }
    
    func loadExternalAccounts() {
        struct ExternalAccountsResponse: Codable {
            let external_accounts: [ExternalAccount]
            let total: Int
        }
        
        apiService.request(
            ExternalAccountsResponse.self,
            "/api/stripe/connect/account/external-accounts",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let apiError) = completion {
                    // 如果是 404 错误，可能是账户没有外部账户，设置为空列表
                    if case .httpError(let code) = apiError {
                        if code == 404 {
                            print("ℹ️ 账户没有外部账户，返回空列表")
                            self?.externalAccounts = []
                            return
                        }
                    }
                    print("⚠️ 获取外部账户失败: \(apiError.localizedDescription)，继续显示账户详情")
                    self?.externalAccounts = []
                }
            },
            receiveValue: { [weak self] response in
                self?.externalAccounts = response.external_accounts
                print("✅ 成功加载 \(response.external_accounts.count) 个外部账户")
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
    case accountDetails(StripeConnectAccountDetails) // 账户详情
    case ready(String) // clientSecret
}

