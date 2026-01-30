import SwiftUI
import Combine

/// 自定义的支付记录视图（不使用嵌入式组件）
struct StripeConnectPaymentsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = StripeConnectPaymentsViewModel()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else {
                transactionsListView
            }
        }
        .navigationTitle(LocalizationKey.paymentRecordsPaymentRecords.localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 先尝试从缓存加载（立即显示）
            viewModel.loadTransactionsFromCache()
            // 后台刷新数据（不强制刷新，使用缓存优先策略）
            viewModel.loadTransactions(forceRefresh: false)
        }
        .refreshable {
            // 下拉刷新时强制刷新
            viewModel.loadTransactions(forceRefresh: true)
        }
        .alert(LocalizationKey.errorError.localized, isPresented: $showError) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) { }
        } message: {
            Text(errorMessage)
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
            LoadingView(message: LocalizationKey.paymentRecordsLoading.localized)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(LocalizationKey.paymentRecordsLoadFailed.localized)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.loadTransactions()
            }) {
                Text(LocalizationKey.commonRetry.localized)
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
    
    private var transactionsListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                if viewModel.allPaymentRecords.isEmpty {
                    EmptyStateView(
                        icon: "creditcard.fill",
                        title: LocalizationKey.emptyNoPaymentRecords.localized,
                        message: LocalizationKey.emptyNoPaymentRecordsMessage.localized
                    )
                    .padding(.top, 60)
                } else {
                    // 显示所有类型的支付记录（包括 Stripe Connect 交易和任务付款）
                    ForEach(viewModel.allPaymentRecords) { record in
                        switch record {
                        case .stripeConnect(let transaction):
                            StripeTransactionRowView(transaction: transaction)
                        case .taskPayment(let payment):
                            TaskPaymentRowView(payment: payment)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
    }
}

/// Stripe Connect 交易记录行视图
struct StripeTransactionRowView: View {
    let transaction: StripeConnectTransaction
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 状态图标
            ZStack {
                Circle()
                    .fill((transaction.type == "income" ? AppColors.success : AppColors.error).opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: transaction.type == "income" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(transaction.type == "income" ? AppColors.success : AppColors.error)
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
                    .foregroundColor(transaction.type == "income" ? AppColors.success : AppColors.textPrimary)
                
                Text(transaction.source.capitalized)
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
        case "succeeded", "paid":
            return LocalizationKey.paymentStatusSuccess.localized
        case "pending":
            return LocalizationKey.paymentStatusProcessing.localized
        case "failed", "canceled":
            return LocalizationKey.paymentStatusFailed.localized
        case "reversed":
            return LocalizationKey.paymentStatusCanceled.localized
        default:
            return transaction.status.capitalized
        }
    }
    
    private var statusColor: Color {
        switch transaction.status.lowercased() {
        case "succeeded", "paid":
            return AppColors.success
        case "pending":
            return .orange
        case "failed", "canceled", "reversed":
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
        
        let sign = transaction.type == "income" ? "+" : "-"
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return "\(sign)\(formatted)"
        }
        return "\(sign)\(currency) \(String(format: "%.2f", amount))"
    }
    
    private func formatDate(_ dateString: String) -> String {
        // 使用 DateFormatterHelper 来确保正确解析 UTC 时间并转换为用户时区
        return DateFormatterHelper.shared.formatShortDateTime(dateString)
    }
}

/// ViewModel 用于管理支付记录
class StripeConnectPaymentsViewModel: ObservableObject {
    @Published var transactions: [StripeConnectTransaction] = [] {
        willSet {
            // 数据更新时清除缓存，触发重新计算
            _allPaymentRecords = []
        }
    }
    @Published var taskPayments: [TaskPaymentRecord] = [] {
        willSet {
            // 数据更新时清除缓存，触发重新计算
            _allPaymentRecords = []
        }
    }
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiService = APIService.shared
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 缓存键
    private let stripeTransactionsCacheKey = "my_payment_stripe_transactions"
    private let taskPaymentsCacheKey = "my_payment_task_payments"
    
    // 合并后的所有支付记录（包括 Stripe Connect 交易和任务付款）
    // 使用缓存避免重复计算
    private var _allPaymentRecords: [PaymentRecord] = []
    
    var allPaymentRecords: [PaymentRecord] {
        // 如果缓存为空或数据已变化，重新计算
        if _allPaymentRecords.isEmpty || 
           _allPaymentRecords.count != transactions.count + taskPayments.count {
            // 重新计算并缓存
            var records: [PaymentRecord] = []
            
            // 添加 Stripe Connect 交易记录
            for transaction in transactions {
                records.append(.stripeConnect(transaction))
            }
            
            // 添加任务付款记录
            for payment in taskPayments {
                records.append(.taskPayment(payment))
            }
            
            // 按时间倒序排列（最新的在前）
            _allPaymentRecords = records.sorted { record1, record2 in
                let time1 = record1.createdAt
                let time2 = record2.createdAt
                return time1 > time2
            }
        }
        
        return _allPaymentRecords
    }
    
    /// 从缓存加载支付记录（供 View 调用，优先内存缓存，快速响应）
    func loadTransactionsFromCache() {
        // 异步加载缓存，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var stripeTransactions: [StripeConnectTransaction] = []
            var taskPayments: [TaskPaymentRecord] = []
            
            if let cached: [StripeConnectTransaction] = self.cacheManager.load([StripeConnectTransaction].self, forKey: self.stripeTransactionsCacheKey) {
                if !cached.isEmpty {
                    stripeTransactions = cached
                    Logger.debug("✅ 从内存缓存加载了 \(cached.count) 条 Stripe Connect 交易记录", category: .cache)
                }
            }
            
            if let cached: [TaskPaymentRecord] = self.cacheManager.load([TaskPaymentRecord].self, forKey: self.taskPaymentsCacheKey) {
                if !cached.isEmpty {
                    taskPayments = cached
                    Logger.debug("✅ 从内存缓存加载了 \(cached.count) 条任务付款记录", category: .cache)
                }
            }
            
            // 更新 UI 在主线程
            DispatchQueue.main.async {
                self.transactions = stripeTransactions
                self.taskPayments = taskPayments
            }
        }
    }
    
    func loadTransactions(forceRefresh: Bool = false) {
        // 如果不是强制刷新，先尝试从缓存加载
        if !forceRefresh {
            loadTransactionsFromCache()
        }
        
        isLoading = true
        error = nil
        
        // 并行加载 Stripe Connect 交易记录和任务付款记录
        let group = DispatchGroup()
        var stripeError: String?
        var taskPaymentError: String?
        
        // 加载 Stripe Connect 交易记录
        group.enter()
        loadStripeConnectTransactions { error in
            stripeError = error
            group.leave()
        }
        
        // 加载任务付款记录
        group.enter()
        loadTaskPayments { error in
            taskPaymentError = error
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            
            // 如果有错误，显示第一个错误
            if let error = stripeError ?? taskPaymentError {
                self.error = error
            }
        }
    }
    
    private func loadStripeConnectTransactions(completion: @escaping (String?) -> Void) {
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
            receiveCompletion: { result in
                if case .failure(let apiError) = result {
                    var errorMessage: String? = apiError.localizedDescription
                    if case .httpError(let code) = apiError {
                        if code == 404 {
                            // 404 不算错误，只是没有 Stripe Connect 账户
                            errorMessage = nil
                        } else {
                            errorMessage = "请求失败 (HTTP \(code))"
                        }
                    }
                    completion(errorMessage)
                } else {
                    // 成功完成，completion 已在 receiveValue 中调用
                    completion(nil)
                }
            },
            receiveValue: { [weak self] response in
                guard let self = self else { return }
                self.transactions = response.transactions
                // 异步保存到缓存，避免阻塞主线程
                DispatchQueue.global(qos: .utility).async {
                    self.cacheManager.save(response.transactions, forKey: self.stripeTransactionsCacheKey)
                    Logger.debug("✅ 已缓存 \(response.transactions.count) 条 Stripe Connect 交易记录", category: .cache)
                }
                
                // 注意：不在 receiveValue 中调用 completion，避免重复调用
                // completion 会在 receiveCompletion 中调用
            }
        )
        .store(in: &cancellables)
    }
    
    private func loadTaskPayments(completion: @escaping (String?) -> Void) {
        struct PaymentHistoryResponse: Codable {
            let payments: [TaskPaymentRecord]
            let total: Int
            let skip: Int
            let limit: Int
        }
        
        apiService.request(
            PaymentHistoryResponse.self,
            "\(APIEndpoints.Payment.paymentHistory)?limit=100&skip=0",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { result in
                if case .failure(let apiError) = result {
                    let errorMessage = apiError.localizedDescription
                    completion(errorMessage)
                } else {
                    // 成功完成，completion 已在 receiveValue 中调用
                    completion(nil)
                }
            },
            receiveValue: { [weak self] response in
                guard let self = self else { return }
                self.taskPayments = response.payments
                // 异步保存到缓存，避免阻塞主线程
                DispatchQueue.global(qos: .utility).async {
                    self.cacheManager.save(response.payments, forKey: self.taskPaymentsCacheKey)
                    Logger.debug("✅ 已缓存 \(response.payments.count) 条任务付款记录", category: .cache)
                }
                
                // 注意：不在 receiveValue 中调用 completion，避免重复调用
                // completion 会在 receiveCompletion 中调用
            }
        )
        .store(in: &cancellables)
    }
}

/// 统一的支付记录类型（可以是 Stripe Connect 交易或任务付款）
enum PaymentRecord: Identifiable {
    case stripeConnect(StripeConnectTransaction)
    case taskPayment(TaskPaymentRecord)
    
    var id: String {
        switch self {
        case .stripeConnect(let transaction):
            return "stripe_\(transaction.id)"
        case .taskPayment(let payment):
            return "task_\(payment.id)"
        }
    }
    
    // 缓存日期解析结果，避免重复解析
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    var createdAt: Date {
        switch self {
        case .stripeConnect(let transaction):
            return PaymentRecord.dateFormatter.date(from: transaction.createdAt) ?? Date.distantPast
        case .taskPayment(let payment):
            return PaymentRecord.dateFormatter.date(from: payment.createdAt ?? "") ?? Date.distantPast
        }
    }
}

/// 任务付款记录模型
struct TaskPaymentRecord: Identifiable, Codable {
    let id: Int
    let taskId: Int
    let paymentIntentId: String?
    let paymentMethod: String
    let totalAmount: Int // 总金额（便士）
    let totalAmountDisplay: String
    let pointsUsed: Int? // 使用的积分（便士）
    let pointsUsedDisplay: String?
    let couponDiscount: Int? // 优惠券折扣（便士）
    let couponDiscountDisplay: String?
    let stripeAmount: Int? // Stripe 支付金额（便士）
    let stripeAmountDisplay: String?
    let finalAmount: Int // 最终支付金额（便士）
    let finalAmountDisplay: String
    let currency: String
    let status: String
    let applicationFee: Int? // 平台服务费（便士）
    let applicationFeeDisplay: String?
    let escrowAmount: Double? // 托管金额
    let createdAt: String?
    let updatedAt: String?
    let task: TaskPaymentInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case paymentIntentId = "payment_intent_id"
        case paymentMethod = "payment_method"
        case totalAmount = "total_amount"
        case totalAmountDisplay = "total_amount_display"
        case pointsUsed = "points_used"
        case pointsUsedDisplay = "points_used_display"
        case couponDiscount = "coupon_discount"
        case couponDiscountDisplay = "coupon_discount_display"
        case stripeAmount = "stripe_amount"
        case stripeAmountDisplay = "stripe_amount_display"
        case finalAmount = "final_amount"
        case finalAmountDisplay = "final_amount_display"
        case currency
        case status
        case applicationFee = "application_fee"
        case applicationFeeDisplay = "application_fee_display"
        case escrowAmount = "escrow_amount"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case task
    }
}

/// 任务付款信息
struct TaskPaymentInfo: Codable {
    let id: Int?
    let title: String?
}

/// 任务付款记录行视图
struct TaskPaymentRowView: View {
    let payment: TaskPaymentRecord
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(AppColors.error.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.error)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 任务标题或描述
                Text(payment.task?.title ?? String(format: LocalizationKey.paymentTaskNumber.localized, payment.taskId))
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
                    
                    // 支付方式（不再显示积分支付）
                    Text(paymentMethodText)
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                    
                    // 时间
                    if let createdAt = payment.createdAt {
                        Text(formatDate(createdAt))
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.textQuaternary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(Double(payment.finalAmount) / 100.0, currency: payment.currency))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.error)
                
                Text(LocalizationKey.paymentStatusTaskPayment.localized)
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
        switch payment.status.lowercased() {
        case "succeeded", "paid":
            return LocalizationKey.paymentStatusSuccess.localized
        case "pending":
            return LocalizationKey.paymentStatusProcessing.localized
        case "failed", "canceled":
            return LocalizationKey.paymentStatusFailed.localized
        default:
            return payment.status.capitalized
        }
    }
    
    private var statusColor: Color {
        switch payment.status.lowercased() {
        case "succeeded", "paid":
            return AppColors.success
        case "pending":
            return .orange
        case "failed", "canceled":
            return AppColors.error
        default:
            return AppColors.textSecondary
        }
    }
    
    private var paymentMethodText: String {
        switch payment.paymentMethod.lowercased() {
        case "stripe":
            return "Stripe"
        case "points":
            return LocalizationKey.pointsPoints.localized
        case "mixed":
            return LocalizationKey.paymentMixed.localized
        default:
            return payment.paymentMethod.capitalized
        }
    }
    
    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return "-\(formatted)"
        }
        return "-\(currency) \(String(format: "%.2f", amount))"
    }
    
    private func formatDate(_ dateString: String) -> String {
        // 使用 DateFormatterHelper 来确保正确解析 UTC 时间并转换为用户时区
        return DateFormatterHelper.shared.formatShortDateTime(dateString)
    }
}

/// Stripe Connect 交易记录模型
struct StripeConnectTransaction: Identifiable, Codable {
    let id: String
    let type: String // "income" 或 "expense"
    let amount: Double
    let currency: String
    let description: String
    let status: String
    let created: Int // Unix 时间戳
    let createdAt: String // ISO 格式时间
    let source: String // "charge", "transfer", "payout", "payment_intent"
    let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case amount
        case currency
        case description
        case status
        case created
        case createdAt = "created_at"
        case source
        case metadata
    }
}
