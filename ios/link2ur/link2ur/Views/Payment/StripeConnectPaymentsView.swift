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
        .navigationTitle("支付记录")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadTransactions()
        }
        .refreshable {
            viewModel.loadTransactions()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
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
                viewModel.loadTransactions()
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
    
    private var transactionsListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                if viewModel.transactions.isEmpty {
                    EmptyStateView(
                        icon: "creditcard.fill",
                        title: "暂无支付记录",
                        message: "您的支付记录将显示在这里"
                    )
                    .padding(.top, 60)
                } else {
                    // 显示所有类型的交易（包括付款和收入）
                    ForEach(viewModel.transactions) { transaction in
                        StripeTransactionRowView(transaction: transaction)
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
            return "成功"
        case "pending":
            return "处理中"
        case "failed", "canceled":
            return "失败"
        case "reversed":
            return "已撤销"
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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale(identifier: "zh_CN")
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

/// ViewModel 用于管理支付记录
class StripeConnectPaymentsViewModel: ObservableObject {
    @Published var transactions: [StripeConnectTransaction] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadTransactions() {
        isLoading = true
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
                self?.isLoading = false
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
                    print("❌ 获取支付记录失败: \(errorMessage)")
                }
            },
            receiveValue: { [weak self] response in
                self?.isLoading = false
                self?.transactions = response.transactions
                print("✅ 成功加载 \(response.transactions.count) 条交易记录")
            }
        )
        .store(in: &cancellables)
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
