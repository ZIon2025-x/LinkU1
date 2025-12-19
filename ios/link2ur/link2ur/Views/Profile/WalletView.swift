import SwiftUI
import Combine

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var showingCouponPoints = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 积分账户卡片
                    if let account = viewModel.pointsAccount {
                        PointsAccountCard(account: account)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, AppSpacing.xl)
                    } else {
                        ErrorStateView(
                            message: viewModel.errorMessage ?? "加载失败",
                            retryAction: {
                                viewModel.loadPointsAccount()
                            }
                        )
                        .padding(.top, AppSpacing.xl)
                    }
                    
                    // 快速操作
                    VStack(spacing: AppSpacing.md) {
                        Text("快速操作")
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.md)
                        
                        NavigationLink(destination: CouponPointsView()) {
                            QuickActionCard(
                                icon: "star.fill",
                                title: "积分与优惠券",
                                subtitle: "查看积分详情、优惠券和签到",
                                color: Color.orange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.top, AppSpacing.md)
                    
                    // 最近交易记录
                    if !viewModel.recentTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Text("最近交易")
                                    .font(AppTypography.title3)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Spacer()
                                
                                NavigationLink(destination: CouponPointsView()) {
                                    Text("查看全部")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            
                            ForEach(viewModel.recentTransactions.prefix(5)) { transaction in
                                TransactionRowView(transaction: transaction)
                                    .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        .padding(.top, AppSpacing.md)
                    }
                    
                    // 钱包余额占位（未来功能）
                    VStack(spacing: AppSpacing.md) {
                        HStack {
                            Text("钱包余额")
                                .font(AppTypography.title3)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        ComingSoonCard(
                            icon: "creditcard.fill",
                            title: "钱包余额功能",
                            message: "充值、提现等功能即将上线"
                        )
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.top, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .navigationTitle("我的钱包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            viewModel.loadPointsAccount()
            viewModel.loadRecentTransactions()
        }
        .refreshable {
            viewModel.loadPointsAccount()
            viewModel.loadRecentTransactions()
        }
    }
}

// MARK: - ViewModel

@MainActor
class WalletViewModel: ObservableObject {
    @Published var pointsAccount: PointsAccount?
    @Published var recentTransactions: [PointsTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadPointsAccount() {
        isLoading = true
        errorMessage = nil
        
        apiService.getPointsAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] account in
                    self?.pointsAccount = account
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    func loadRecentTransactions() {
        apiService.getPointsTransactions(page: 1, limit: 5)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("加载交易记录失败: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    self?.recentTransactions = response.data
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Components

struct PointsAccountCard: View {
    let account: PointsAccount
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // 余额显示
            VStack(spacing: AppSpacing.sm) {
                Text("积分余额")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(account.balanceDisplay)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primary)
                
                Text(account.currency)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Divider()
                .padding(.vertical, AppSpacing.sm)
            
            // 统计信息
            HStack(spacing: AppSpacing.xl) {
                StatItem(
                    label: "累计获得",
                    value: "\(account.totalEarned / 100)",
                    color: AppColors.success
                )
                
                StatItem(
                    label: "累计消费",
                    value: "\(account.totalSpent / 100)",
                    color: AppColors.warning
                )
            }
        }
        .padding(AppSpacing.xl)
        .cardStyle(cornerRadius: AppCornerRadius.large)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(0.1),
                    AppColors.primary.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.2), color.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

struct ComingSoonCard: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppColors.textTertiary)
            
            Text(title)
                .font(AppTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(message)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .cardStyle()
        .opacity(0.7)
    }
}

