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
                        Text(LocalizationKey.walletQuickActions.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.md)
                        
                        NavigationLink(destination: CouponPointsView()) {
                            QuickActionCard(
                                icon: "star.fill",
                                title: LocalizationKey.pointsAndCoupons.localized,
                                subtitle: LocalizationKey.profilePointsCouponsSubtitle.localized,
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
                                Text(LocalizationKey.walletRecentTransactions.localized)
                                    .font(AppTypography.title3)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Spacer()
                                
                                NavigationLink(destination: CouponPointsView()) {
                                    Text(LocalizationKey.commonViewAll.localized)
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
                    
                    // 钱包余额和提现功能
                    VStack(spacing: AppSpacing.md) {
                        HStack {
                            Text(LocalizationKey.walletBalance.localized)
                                .font(AppTypography.title3)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        NavigationLink(destination: StripeConnectPayoutsView()) {
                            QuickActionCard(
                                icon: "arrow.up.right.circle.fill",
                                title: "提现管理",
                                subtitle: "查看余额、提现记录和管理提现设置",
                                color: AppColors.primary
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, AppSpacing.md)
                        
                        NavigationLink(destination: StripeConnectPaymentsView()) {
                            QuickActionCard(
                                icon: "list.bullet.rectangle.fill",
                                title: "支付记录",
                                subtitle: "查看所有支付、退款和争议记录",
                                color: Color.blue
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.top, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .navigationTitle(LocalizationKey.walletMyWallet.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
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
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载积分账户")
                        // 错误处理：error 已经是 APIError 类型，直接使用
                        self?.errorMessage = error.userFriendlyMessage
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
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载交易记录")
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
                Text("points.balance")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(account.balance)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.primary)
                    
                    Text("points.unit")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Divider()
                .padding(.vertical, AppSpacing.sm)
            
            // 统计信息
            HStack(spacing: AppSpacing.xl) {
                StatItem(
                    label: String(localized: "points.total_earned"),
                    value: "\(account.totalEarned)",
                    color: AppColors.success
                )
                
                StatItem(
                    label: String(localized: "points.total_spent"),
                    value: "\(account.totalSpent)",
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

