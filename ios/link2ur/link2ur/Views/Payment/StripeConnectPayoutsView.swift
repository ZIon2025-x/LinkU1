import SwiftUI
import Combine

/// 自定义的提现记录视图（不使用嵌入式组件）
struct StripeConnectPayoutsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = StripeConnectPayoutsViewModel()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPayoutSheet = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoadingBalance && viewModel.balance == nil {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else {
                contentView
            }
        }
        .navigationTitle(LocalizationKey.paymentPayoutManagement.localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 先尝试从缓存加载（立即显示）
            viewModel.loadBalanceFromCache()
            viewModel.loadTransactionsFromCache()
            // 后台刷新数据（不强制刷新，使用缓存优先策略）
            viewModel.loadBalance(forceRefresh: false)
            viewModel.loadTransactions(forceRefresh: false)
        }
        .refreshable {
            // 下拉刷新时强制刷新
            viewModel.loadBalance(forceRefresh: true)
            viewModel.loadTransactions(forceRefresh: true)
        }
        .alert(LocalizationKey.errorError.localized, isPresented: $showError) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPayoutSheet) {
            PayoutSheet(viewModel: viewModel, isPresented: $showPayoutSheet)
        }
        .sheet(isPresented: $viewModel.showAccountDetails) {
            AccountDetailsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showTransactionDetail) {
            if let transaction = viewModel.selectedTransaction {
                TransactionDetailSheet(transaction: transaction)
            }
        }
        .onChange(of: viewModel.error) { newError in
            if let error = newError {
                DispatchQueue.main.async {
                    errorMessage = error
                    showError = true
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            LoadingView(message: LocalizationKey.commonLoading.localized)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(LocalizationKey.errorNetworkError.localized)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.loadBalance()
                viewModel.loadTransactions()
            }) {
                Text(LocalizationKey.errorRetry.localized)
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
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                // 余额卡片
                if let balance = viewModel.balance {
                    BalanceCard(balance: balance)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.md)
                    
                    // 按钮组
                    HStack(spacing: AppSpacing.md) {
                        // 查看详情按钮
                        Button(action: {
                            viewModel.loadAccountDetails()
                            viewModel.showAccountDetails = true
                        }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                Text(LocalizationKey.paymentViewDetails.localized)
                                    .font(AppTypography.body)
                            }
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
                        
                        // 提现按钮
                        if balance.available > 0 {
                            Button(action: {
                                showPayoutSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 18))
                                    Text(LocalizationKey.paymentPayout.localized)
                                        .font(AppTypography.body)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.primary)
                                .cornerRadius(AppCornerRadius.large)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    if balance.available == 0 {
                        Text(LocalizationKey.paymentNoAvailableBalance.localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.large)
                            .padding(.horizontal, AppSpacing.md)
                    }
                }
                
                // 提现记录标题
                if !viewModel.transactions.isEmpty {
                    HStack {
                        Text(LocalizationKey.paymentPayoutRecords.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                }
                
                // 提现记录列表
                if viewModel.transactions.isEmpty {
                    EmptyStateView(
                        icon: "banknote.fill",
                        title: LocalizationKey.paymentNoPayoutRecords.localized,
                        message: LocalizationKey.paymentNoPayoutRecordsMessage.localized
                    )
                    .padding(.top, 60)
                } else {
                    // 只显示支出类型的交易（提现记录）
                    let payoutTransactions = viewModel.transactions.filter { $0.type == "expense" }
                    
                    if payoutTransactions.isEmpty {
                        EmptyStateView(
                            icon: "banknote.fill",
                            title: LocalizationKey.paymentNoPayoutRecords.localized,
                            message: LocalizationKey.paymentNoPayoutRecordsMessage.localized
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(payoutTransactions) { transaction in
                            PayoutTransactionRowView(transaction: transaction)
                                .padding(.horizontal, AppSpacing.md)
                                .onTapGesture {
                                    viewModel.selectedTransaction = transaction
                                    viewModel.showTransactionDetail = true
                                }
                        }
                    }
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }
}

/// 余额卡片
struct BalanceCard: View {
    let balance: StripeConnectBalance
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // 总余额
            VStack(spacing: 4) {
                Text(LocalizationKey.paymentTotalBalance.localized)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(formatAmount(balance.total, currency: balance.currency))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Divider()
            
            // 可用余额和待处理余额
            HStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationKey.paymentAvailableBalance.localized)
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(formatAmount(balance.available, currency: balance.currency))
                        .font(AppTypography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.success)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizationKey.paymentPending.localized)
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(formatAmount(balance.pending, currency: balance.currency))
                        .font(AppTypography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return formatted
        }
        return "\(currency) \(String(format: "%.2f", amount))"
    }
}

/// 提现弹窗
struct PayoutSheet: View {
    @ObservedObject var viewModel: StripeConnectPayoutsViewModel
    @Binding var isPresented: Bool
    @State private var amount: String = ""
    @State private var description: String = ""
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.lg) {
                        // 可用余额提示
                        if let balance = viewModel.balance {
                            VStack(spacing: 8) {
                                Text(LocalizationKey.paymentAvailableBalance.localized)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text(formatAmount(balance.available, currency: balance.currency))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.primary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        // 提现金额输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizationKey.paymentPayoutAmount.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            HStack {
                                Text(viewModel.balance?.currency ?? "GBP")
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.trailing, 8)
                                
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(AppTypography.title2)
                                    .focused($isAmountFocused)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        // 描述（可选）
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizationKey.paymentNoteOptional.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            TextField(LocalizationKey.paymentPayoutNote.localized, text: $description)
                                .padding()
                                .background(AppColors.cardBackground)
                                .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // 提现按钮
                        Button(action: {
                            createPayout()
                        }) {
                            HStack {
                                if viewModel.isCreatingPayout {
                                    CompactLoadingView()
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 20))
                                    Text(LocalizationKey.paymentConfirmPayout.localized)
                                        .font(AppTypography.title3)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canCreatePayout ? AppColors.primary : AppColors.textTertiary)
                            .cornerRadius(AppCornerRadius.large)
                        }
                        .disabled(!canCreatePayout || viewModel.isCreatingPayout)
                        .padding(.bottom, AppSpacing.md)
                    }
                    .padding(AppSpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(LocalizationKey.paymentPayout.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            isAmountFocused = true
        }
    }
    
    private var canCreatePayout: Bool {
        guard let balance = viewModel.balance,
              let amountValue = Double(amount) else {
            return false
        }
        return amountValue > 0 && amountValue <= balance.available
    }
    
    private func createPayout() {
        guard let amountValue = Double(amount),
              amountValue > 0,
              let balance = viewModel.balance,
              amountValue <= balance.available else {
            return
        }
        
        viewModel.createPayout(
            amount: amountValue,
            currency: balance.currency,
            description: description.isEmpty ? nil : description
        ) { success in
            if success {
                isPresented = false
                // 刷新余额和交易记录
                viewModel.loadBalance()
                viewModel.loadTransactions()
            }
        }
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return formatted
        }
        return "\(currency) \(String(format: "%.2f", amount))"
    }
}

/// 提现交易记录行视图
struct PayoutTransactionRowView: View {
    let transaction: StripeConnectTransaction
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                HStack(spacing: 8) {
                    // 状态标签
                    Text(statusText)
                        .font(AppTypography.caption2)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    // 时间
                    Text(formatDate(transaction.createdAt))
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textQuaternary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(transaction.amount, currency: transaction.currency))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(LocalizationKey.paymentPayout.localized)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 14)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.01), radius: 5, x: 0, y: 2)
    }
    
    private var statusText: String {
        switch transaction.status.lowercased() {
        case "paid", "succeeded":
            return "已到账"
        case "pending":
            return "处理中"
        case "in_transit":
            return "转账中"
        case "canceled":
            return "已取消"
        case "failed":
            return "失败"
        default:
            return transaction.status.capitalized
        }
    }
    
    private var statusColor: Color {
        switch transaction.status.lowercased() {
        case "paid", "succeeded":
            return AppColors.success
        case "pending", "in_transit":
            return .orange
        case "canceled", "failed":
            return AppColors.error
        default:
            return AppColors.textSecondary
        }
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return formatted
        }
        return "\(currency) \(String(format: "%.2f", amount))"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current // 使用用户系统 locale
            displayFormatter.timeZone = TimeZone.current // 使用用户本地时区
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

/// Stripe Connect 余额模型
struct StripeConnectBalance: Codable {
    let available: Double
    let pending: Double
    let total: Double
    let currency: String
    let availableBreakdown: [BalanceBreakdown]
    let pendingBreakdown: [BalanceBreakdown]
    
    enum CodingKeys: String, CodingKey {
        case available
        case pending
        case total
        case currency
        case availableBreakdown = "available_breakdown"
        case pendingBreakdown = "pending_breakdown"
    }
}

struct BalanceBreakdown: Codable {
    let amount: Double
    let currency: String
    let sourceTypes: [String: Int]?
    
    enum CodingKeys: String, CodingKey {
        case amount
        case currency
        case sourceTypes = "source_types"
    }
}

/// ViewModel 用于管理提现记录和余额
class StripeConnectPayoutsViewModel: ObservableObject {
    @Published var balance: StripeConnectBalance?
    @Published var transactions: [StripeConnectTransaction] = []
    @Published var isLoadingBalance = false
    @Published var isLoadingTransactions = false
    @Published var isCreatingPayout = false
    @Published var error: String?
    @Published var showAccountDetails = false
    @Published var accountDetails: StripeConnectAccountDetails?
    @Published var externalAccounts: [ExternalAccount] = []
    @Published var isLoadingAccountDetails = false
    @Published var selectedTransaction: StripeConnectTransaction?
    @Published var showTransactionDetail = false
    
    private let apiService = APIService.shared
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 缓存键
    private let balanceCacheKey = "my_payout_balance"
    private let transactionsCacheKey = "my_payout_transactions"
    
    /// 从缓存加载余额（供 View 调用，优先内存缓存，快速响应）
    nonisolated func loadBalanceFromCache() {
        // 异步加载缓存，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // 使用非隔离的缓存管理器方法，避免 main actor 隔离问题
            // 注意：如果 StripeConnectBalance 的 Codable 是 main actor 隔离的，我们需要在主线程解码
            Task { @MainActor in
                if let cachedBalance = self.cacheManager.load(StripeConnectBalance.self, forKey: self.balanceCacheKey) {
                    self.balance = cachedBalance
                    Logger.debug("✅ 从内存缓存加载了余额", category: .cache)
                }
            }
        }
    }
    
    func loadBalance(forceRefresh: Bool = false) {
        // 如果不是强制刷新，先尝试从缓存加载
        if !forceRefresh {
            loadBalanceFromCache()
        }
        
        isLoadingBalance = true
        error = nil
        
        apiService.request(
            StripeConnectBalance.self,
            "/api/stripe/connect/account/balance",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoadingBalance = false
                if case .failure(let apiError) = completion {
                    var errorMessage = apiError.localizedDescription
                    if case .httpError(let code) = apiError {
                        if code == 404 {
                            errorMessage = "未找到 Stripe Connect 账户，请先完成账户入驻"
                        } else {
                            errorMessage = "请求失败 (HTTP \(code))"
                        }
                    }
                    self?.error = errorMessage
                    print("❌ 获取余额失败: \(errorMessage)")
                }
            },
            receiveValue: { [weak self] balance in
                guard let self = self else { return }
                self.isLoadingBalance = false
                self.balance = balance
                print("✅ 成功加载余额: 可用 \(balance.available) \(balance.currency)")
                
                // 异步保存到缓存，避免阻塞主线程
                // 使用非隔离的缓存管理器方法，避免 main actor 隔离问题
                let balanceToSave = balance
                DispatchQueue.global(qos: .utility).async {
                    self.cacheManager.save(balanceToSave, forKey: self.balanceCacheKey)
                    Task { @MainActor in
                        Logger.debug("✅ 已缓存余额", category: .cache)
                    }
                }
            }
        )
        .store(in: &cancellables)
    }
    
    /// 从缓存加载提现记录（供 View 调用，优先内存缓存，快速响应）
    func loadTransactionsFromCache() {
        // 异步加载缓存，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let cachedTransactions: [StripeConnectTransaction] = self.cacheManager.load([StripeConnectTransaction].self, forKey: self.transactionsCacheKey) {
                if !cachedTransactions.isEmpty {
                    DispatchQueue.main.async {
                        self.transactions = cachedTransactions
                        Logger.debug("✅ 从内存缓存加载了 \(cachedTransactions.count) 条提现记录", category: .cache)
                    }
                }
            }
        }
    }
    
    func loadTransactions(forceRefresh: Bool = false) {
        // 如果不是强制刷新，先尝试从缓存加载
        if !forceRefresh {
            loadTransactionsFromCache()
        }
        
        isLoadingTransactions = true
        error = nil
        
        struct TransactionsResponse: Codable {
            let transactions: [StripeConnectTransaction]
            let total: Int
            let has_more: Bool
        }
        
        apiService.request(
            TransactionsResponse.self,
            "/api/stripe/connect/account/transactions?limit=100",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoadingTransactions = false
                if case .failure(let apiError) = completion {
                    var errorMessage = apiError.localizedDescription
                    if case .httpError(let code) = apiError {
                        if code == 404 {
                            errorMessage = "未找到 Stripe Connect 账户，请先完成账户入驻"
                        } else {
                            errorMessage = "请求失败 (HTTP \(code))"
                        }
                    }
                    self?.error = errorMessage
                    print("❌ 获取提现记录失败: \(errorMessage)")
                }
            },
            receiveValue: { [weak self] response in
                guard let self = self else { return }
                self.isLoadingTransactions = false
                self.transactions = response.transactions
                print("✅ 成功加载 \(response.transactions.count) 条交易记录")
                
                // 异步保存到缓存，避免阻塞主线程
                DispatchQueue.global(qos: .utility).async {
                    self.cacheManager.save(response.transactions, forKey: self.transactionsCacheKey)
                    Logger.debug("✅ 已缓存 \(response.transactions.count) 条提现记录", category: .cache)
                }
            }
        )
        .store(in: &cancellables)
    }
    
    func createPayout(
        amount: Double,
        currency: String,
        description: String?,
        completion: @escaping (Bool) -> Void
    ) {
        isCreatingPayout = true
        error = nil
        
        struct PayoutRequest: Codable {
            let amount: Double
            let currency: String
            let description: String?
        }
        
        struct PayoutResponse: Codable {
            let id: String
            let amount: Double
            let currency: String
            let status: String
            let created: Int
            let createdAt: String
            let description: String?
            
            enum CodingKeys: String, CodingKey {
                case id
                case amount
                case currency
                case status
                case created
                case createdAt = "created_at"
                case description
            }
        }
        
        let requestBody: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "description": description as Any
        ]
        
        apiService.request(
            PayoutResponse.self,
            "/api/stripe/connect/account/payout",
            method: "POST",
            body: requestBody
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completionResult in
                self?.isCreatingPayout = false
                if case .failure(let apiError) = completionResult {
                    var errorMessage = apiError.localizedDescription
                    if case .httpError(let code) = apiError {
                        errorMessage = "创建提现失败 (HTTP \(code))"
                    }
                    self?.error = errorMessage
                    print("❌ 创建提现失败: \(errorMessage)")
                    completion(false)
                }
            },
            receiveValue: { [weak self] response in
                guard let self = self else { return }
                self.isCreatingPayout = false
                print("✅ 成功创建提现: \(response.id)")
                // 清除提现缓存，因为有了新的提现记录
                self.cacheManager.invalidatePaymentCache()
                completion(true)
            }
        )
        .store(in: &cancellables)
    }
    
    func loadAccountDetails() {
        isLoadingAccountDetails = true
        error = nil
        
        // 加载账户详情
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
                if case .failure(let apiError) = completion {
                    var errorMessage = apiError.localizedDescription
                    if case .httpError(let code) = apiError {
                        errorMessage = "获取账户详情失败 (HTTP \(code))"
                    }
                    self?.error = errorMessage
                    print("❌ 获取账户详情失败: \(errorMessage)")
                }
            },
            receiveValue: { [weak self] response in
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
                self?.isLoadingAccountDetails = false
                if case .failure(let apiError) = completion {
                    // 如果是 404 错误，可能是账户没有外部账户，设置为空列表而不是显示错误
                    if case .httpError(let code) = apiError {
                        if code == 404 {
                            print("ℹ️ 账户没有外部账户，返回空列表")
                            self?.externalAccounts = []
                            return
                        }
                    }
                    // 其他错误只记录，不阻止显示账户详情
                    print("⚠️ 获取外部账户失败: \(apiError.localizedDescription)，继续显示账户详情")
                    self?.externalAccounts = []
                }
            },
            receiveValue: { [weak self] response in
                self?.isLoadingAccountDetails = false
                self?.externalAccounts = response.external_accounts
                print("✅ 成功加载 \(response.external_accounts.count) 个外部账户")
            }
        )
        .store(in: &cancellables)
    }
}

/// 账户详情模型
struct StripeConnectAccountDetails {
    let accountId: String
    let displayName: String?
    let email: String?
    let country: String
    let type: String
    let detailsSubmitted: Bool
    let chargesEnabled: Bool
    let payoutsEnabled: Bool
    let dashboardUrl: String?
    let address: StripeConnectAddress?
    let individual: StripeConnectIndividual?
}

/// 地址信息模型
struct StripeConnectAddress: Codable {
    let line1: String?
    let line2: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case line1
        case line2
        case city
        case state
        case postalCode = "postal_code"
        case country
    }
    
    var fullAddress: String {
        var components: [String] = []
        if let line1 = line1 {
            components.append(line1)
        }
        if let line2 = line2 {
            components.append(line2)
        }
        if let city = city {
            components.append(city)
        }
        if let state = state {
            components.append(state)
        }
        if let postalCode = postalCode {
            components.append(postalCode)
        }
        if let country = country {
            components.append(country)
        }
        return components.joined(separator: ", ")
    }
}

/// 个人信息模型
struct StripeConnectIndividual: Codable {
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let dob: DateOfBirth?
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case dob
    }
    
    var fullName: String {
        var components: [String] = []
        if let firstName = firstName {
            components.append(firstName)
        }
        if let lastName = lastName {
            components.append(lastName)
        }
        return components.isEmpty ? "未设置" : components.joined(separator: " ")
    }
}

/// 出生日期模型
struct DateOfBirth: Codable {
    let day: Int?
    let month: Int?
    let year: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: Int?].self) {
            day = dict["day"] ?? nil
            month = dict["month"] ?? nil
            year = dict["year"] ?? nil
        } else {
            day = nil
            month = nil
            year = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var dict: [String: Int?] = [:]
        dict["day"] = day
        dict["month"] = month
        dict["year"] = year
        try container.encode(dict)
    }
    
    var displayString: String {
        if let day = day, let month = month, let year = year {
            return String(format: "%02d/%02d/%d", day, month, year)
        }
        return "未设置"
    }
}

/// 外部账户模型
struct ExternalAccount: Codable, Identifiable {
    let id: String
    let object: String // "bank_account" or "card"
    let account: String?
    
    // 银行账户字段
    let bankName: String?
    let last4: String?
    let routingNumber: String?
    let currency: String?
    let country: String?
    let accountHolderName: String?
    let accountHolderType: String?
    let status: String?
    
    // 银行卡字段
    let brand: String?
    let expMonth: Int?
    let expYear: Int?
    let funding: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case account
        case bankName = "bank_name"
        case last4
        case routingNumber = "routing_number"
        case currency
        case country
        case accountHolderName = "account_holder_name"
        case accountHolderType = "account_holder_type"
        case status
        case brand
        case expMonth = "exp_month"
        case expYear = "exp_year"
        case funding
    }
}

/// 账户详情弹窗
struct AccountDetailsSheet: View {
    @ObservedObject var viewModel: StripeConnectPayoutsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showWebView = false
    @State private var webViewURL: URL?
    @State private var webViewTitle: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoadingAccountDetails {
                    VStack(spacing: 16) {
                        CompactLoadingView()
                        Text(LocalizationKey.commonLoading.localized)
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            // 账户基本信息
                            if let details = viewModel.accountDetails {
                                AccountInfoSection(details: details) {
                                    if let dashboardUrl = details.dashboardUrl, let url = URL(string: dashboardUrl) {
                                        webViewURL = url
                                        webViewTitle = "Stripe 仪表板"
                                        showWebView = true
                                    }
                                }
                            }
                            
                            // 外部账户（银行卡/银行账户）
                            if !viewModel.externalAccounts.isEmpty {
                                ExternalAccountsSection(accounts: viewModel.externalAccounts)
                                    .padding(.top, AppSpacing.md)
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "creditcard")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppColors.textTertiary)
                                    Text(LocalizationKey.paymentNoExternalAccount.localized)
                                        .font(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(AppSpacing.lg)
                    }
                }
            }
            .navigationTitle(LocalizationKey.paymentAccountDetails.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showWebView) {
                if let url = webViewURL {
                    ExternalWebView(url: url, title: webViewTitle)
                }
            }
        }
    }
}

/// 账户信息部分
struct AccountInfoSection: View {
    let details: StripeConnectAccountDetails
    var onOpenDashboard: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(LocalizationKey.paymentAccountInfo.localized)
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                InfoRow(icon: "number", label: LocalizationKey.paymentAccountId.localized, value: details.accountId)
                if let displayName = details.displayName {
                    InfoRow(icon: "person.fill", label: LocalizationKey.paymentDisplayName.localized, value: displayName)
                }
                if let email = details.email {
                    InfoRow(icon: "envelope.fill", label: LocalizationKey.profileEmail.localized, value: email)
                }
                InfoRow(icon: "globe", label: LocalizationKey.paymentCountry.localized, value: details.country)
                InfoRow(icon: "creditcard.fill", label: LocalizationKey.paymentAccountType.localized, value: details.type == "express" ? "Express" : details.type.capitalized)
                InfoRow(icon: "checkmark.circle.fill", label: LocalizationKey.paymentDetailsSubmitted.localized, value: details.detailsSubmitted ? LocalizationKey.paymentYes.localized : LocalizationKey.paymentNo.localized)
                InfoRow(icon: "arrow.down.circle.fill", label: LocalizationKey.paymentChargesEnabled.localized, value: details.chargesEnabled ? LocalizationKey.paymentYes.localized : LocalizationKey.paymentNo.localized)
                InfoRow(icon: "arrow.up.circle.fill", label: LocalizationKey.paymentPayoutsEnabled.localized, value: details.payoutsEnabled ? LocalizationKey.paymentYes.localized : LocalizationKey.paymentNo.localized)
                
                // Stripe Dashboard 链接
                if details.dashboardUrl != nil {
                    Button(action: {
                        onOpenDashboard?()
                    }) {
                        HStack {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 16))
                            Text(LocalizationKey.paymentOpenStripeDashboard.localized)
                                .font(AppTypography.body)
                        }
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppCornerRadius.medium)
                    }
                    .padding(.top, AppSpacing.sm)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
    }
}

/// 外部账户部分
struct ExternalAccountsSection: View {
    let accounts: [ExternalAccount]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(LocalizationKey.paymentExternalAccount.localized)
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            ForEach(accounts) { account in
                ExternalAccountCard(account: account)
            }
        }
    }
}

/// 外部账户卡片
struct ExternalAccountCard: View {
    let account: ExternalAccount
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: account.object == "bank_account" ? "building.columns.fill" : "creditcard.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.primary)
                
                Text(account.object == "bank_account" ? LocalizationKey.paymentBankAccount.localized : LocalizationKey.paymentCard.localized)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            
            if account.object == "bank_account" {
                if let bankName = account.bankName {
                    InfoRow(icon: "building.columns.fill", label: LocalizationKey.paymentBankName.localized, value: bankName)
                }
                if let last4 = account.last4 {
                    InfoRow(icon: "number", label: LocalizationKey.paymentAccountLast4.localized, value: "****\(last4)")
                }
                if let routingNumber = account.routingNumber {
                    InfoRow(icon: "number", label: LocalizationKey.paymentRoutingNumber.localized, value: routingNumber)
                }
                if let accountHolderName = account.accountHolderName {
                    InfoRow(icon: "person.fill", label: LocalizationKey.paymentAccountHolder.localized, value: accountHolderName)
                }
                if let accountHolderType = account.accountHolderType {
                    InfoRow(icon: "person.2.fill", label: LocalizationKey.paymentHolderType.localized, value: accountHolderType == "individual" ? LocalizationKey.paymentIndividual.localized : LocalizationKey.paymentCompany.localized)
                }
                if let status = account.status {
                    InfoRow(icon: "info.circle.fill", label: LocalizationKey.paymentStatus.localized, value: status)
                }
            } else if account.object == "card" {
                if let brand = account.brand {
                    InfoRow(icon: "creditcard.fill", label: LocalizationKey.paymentCardBrand.localized, value: brand.capitalized)
                }
                if let last4 = account.last4 {
                    InfoRow(icon: "number", label: LocalizationKey.paymentCardLast4.localized, value: "****\(last4)")
                }
                if let expMonth = account.expMonth, let expYear = account.expYear {
                    InfoRow(icon: "calendar", label: LocalizationKey.paymentExpiry.localized, value: String(format: "%02d/%d", expMonth, expYear))
                }
                if let funding = account.funding {
                    InfoRow(icon: "creditcard.fill", label: LocalizationKey.paymentCardType.localized, value: funding == "credit" ? LocalizationKey.paymentCreditCard.localized : LocalizationKey.paymentDebitCard.localized)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
    }
}



/// 交易详情弹窗
struct TransactionDetailSheet: View {
    let transaction: StripeConnectTransaction
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // 金额卡片
                        VStack(spacing: AppSpacing.md) {
                            Text(transaction.type == "expense" ? LocalizationKey.paymentPayoutAmountTitle.localized : LocalizationKey.paymentIncomeAmount.localized)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(formatAmount(transaction.amount, currency: transaction.currency))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(transaction.type == "expense" ? AppColors.textPrimary : AppColors.success)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        
                        // 详细信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(LocalizationKey.paymentDetails.localized)
                                .font(AppTypography.title3)
                                .foregroundColor(AppColors.textPrimary)
                            
                            VStack(spacing: AppSpacing.sm) {
                                InfoRow(icon: "number", label: LocalizationKey.paymentTransactionId.localized, value: transaction.id)
                                InfoRow(icon: "text.alignleft", label: LocalizationKey.paymentDescription.localized, value: transaction.description)
                                InfoRow(icon: "clock.fill", label: LocalizationKey.paymentTime.localized, value: formatDate(transaction.createdAt))
                                InfoRow(icon: "checkmark.circle.fill", label: LocalizationKey.paymentStatus.localized, value: statusText)
                                InfoRow(icon: "creditcard.fill", label: LocalizationKey.paymentType.localized, value: transaction.type == "expense" ? LocalizationKey.paymentPayout.localized : LocalizationKey.paymentIncome.localized)
                                InfoRow(icon: "arrow.right.circle.fill", label: LocalizationKey.paymentSource.localized, value: sourceText)
                            }
                        }
                        .padding(AppSpacing.lg)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                    }
                    .padding(AppSpacing.lg)
                }
            }
            .navigationTitle(LocalizationKey.paymentTransactionDetails.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusText: String {
        switch transaction.status.lowercased() {
        case "paid", "succeeded":
            return "已到账"
        case "pending":
            return "处理中"
        case "in_transit":
            return "转账中"
        case "canceled":
            return "已取消"
        case "failed":
            return "失败"
        default:
            return transaction.status.capitalized
        }
    }
    
    private var sourceText: String {
        switch transaction.source {
        case "payout":
            return "提现"
        case "transfer":
            return "转账"
        case "charge":
            return "收款"
        case "payment_intent":
            return "支付"
        default:
            return transaction.source.capitalized
        }
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return formatted
        }
        return "\(currency) \(String(format: "%.2f", amount))"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current // 使用用户系统 locale
            displayFormatter.timeZone = TimeZone.current // 使用用户本地时区
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
