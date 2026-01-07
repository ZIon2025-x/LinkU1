import SwiftUI
import StripeConnect
import UIKit
import Combine

/// 使用 Stripe Connect 原生 SDK 的 Payments（支付列表）视图
struct StripeConnectPaymentsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = StripeConnectPaymentsViewModel()
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 可选的默认过滤器
    var defaultFilters: EmbeddedComponentManager.PaymentsListDefaultFiltersOptions? = nil
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            stateBasedView
        }
        .navigationTitle("支付记录")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadPaymentsSession()
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
        case .ready(let secret):
            // 使用原生 PaymentsViewController
            PaymentsViewControllerWrapper(
                clientSecret: secret,
                defaultFilters: defaultFilters,
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
                viewModel.loadPaymentsSession()
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
}

/// 将 UIKit 的 PaymentsViewController 包装为 SwiftUI View
struct PaymentsViewControllerWrapper: UIViewControllerRepresentable {
    let clientSecret: String
    let defaultFilters: EmbeddedComponentManager.PaymentsListDefaultFiltersOptions?
    let onError: (String) -> Void
    
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
        
        // 创建 PaymentsViewController，支持可选过滤器
        let paymentsViewController = embeddedComponentManager.createPaymentsViewController(
            defaultFilters: defaultFilters
        )
        
        // 创建容器视图控制器来持有和展示 PaymentsViewController
        let containerVC = ContainerViewController()
        containerVC.paymentsViewController = paymentsViewController
        
        return containerVC
    }
    
    func updateUIViewController(_ uiViewController: ContainerViewController, context: Context) {
        // 不需要更新
    }
    
    /// 容器视图控制器，用于展示 PaymentsViewController
    class ContainerViewController: UIViewController {
        var paymentsViewController: UIViewController?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            // 在视图出现后展示 PaymentsViewController
            if let paymentsVC = paymentsViewController {
                // 将 PaymentsViewController 添加为子视图控制器
                addChild(paymentsVC)
                view.addSubview(paymentsVC.view)
                paymentsVC.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    paymentsVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    paymentsVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    paymentsVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    paymentsVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
                paymentsVC.didMove(toParent: self)
            }
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            
            // 清理子视图控制器
            if let paymentsVC = paymentsViewController {
                paymentsVC.willMove(toParent: nil)
                paymentsVC.view.removeFromSuperview()
                paymentsVC.removeFromParent()
            }
        }
    }
}

/// ViewModel 用于管理 Payments Session
class StripeConnectPaymentsViewModel: ObservableObject {
    @Published var clientSecret: String?
    @Published var isLoading = true
    @Published var error: String?
    
    private let apiService = APIService.shared
    
    var viewState: PaymentsViewState {
        if isLoading {
            return .loading
        } else if let error = error {
            return .error(error)
        } else if let secret = clientSecret {
            return .ready(secret)
        } else {
            return .loading
        }
    }
    
    func loadPaymentsSession() {
        isLoading = true
        error = nil
        
        // 首先获取用户的 Stripe 账户 ID
        struct AccountStatusResponse: Codable {
            let account_id: String
            let details_submitted: Bool
            let charges_enabled: Bool
            let payouts_enabled: Bool
            let needs_onboarding: Bool
        }
        
        // 先获取账户状态
        apiService.request(AccountStatusResponse.self, "/api/stripe/connect/account/status", method: "GET")
            .receive(on: DispatchQueue.main)
            .flatMap { [weak self] statusResponse -> AnyPublisher<AccountSessionResponse, APIError> in
                guard let self = self else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                // 检查账户是否已完成设置
                guard statusResponse.details_submitted && statusResponse.charges_enabled else {
                    return Fail(error: APIError.httpError(400))
                        .eraseToAnyPublisher()
                }
                
                // 创建 payments account session
                struct AccountSessionRequest: Codable {
                    let account: String
                    let enable_payments: Bool
                }
                
                struct AccountSessionResponse: Codable {
                    let client_secret: String
                }
                
                let request = AccountSessionRequest(
                    account: statusResponse.account_id,
                    enable_payments: true
                )
                
                return self.apiService.request(
                    AccountSessionResponse.self,
                    "/api/stripe/connect/account_session",
                    method: "POST",
                    body: request
                )
            }
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let apiError) = completion {
                        var errorMessage = apiError.localizedDescription
                        if case .httpError(let code) = apiError {
                            if code == 400 {
                                errorMessage = "账户尚未完成设置，请先完成账户入驻"
                            } else {
                                errorMessage = "请求失败 (HTTP \(code))"
                            }
                        }
                        self?.error = errorMessage
                        print("❌ Stripe Connect Payments 创建失败: \(errorMessage)")
                    }
                },
                receiveValue: { [weak self] response in
                    self?.isLoading = false
                    self?.clientSecret = response.client_secret
                }
            )
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}

enum PaymentsViewState {
    case loading
    case error(String)
    case ready(String) // clientSecret
}

