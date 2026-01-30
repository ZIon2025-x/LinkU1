import SwiftUI
import Combine

struct CouponPointsView: View {
    @StateObject private var viewModel = CouponPointsViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var showLogin = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if !appState.isAuthenticated {
                // 未登录状态
                VStack(spacing: AppSpacing.xl) {
                    Spacer()
                    
                    Image(systemName: "star.circle")
                        .font(.system(size: 80))
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text(LocalizationKey.loginRequired.localized)
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(LocalizationKey.loginRequiredForPoints.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showLogin = true
                    }) {
                        Text(LocalizationKey.loginLoginNow.localized)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.primary)
                            .cornerRadius(AppCornerRadius.large)
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.xl)
            } else {
                VStack(spacing: 0) {
                    // Custom Tab Selector (Modern Design)
                    HStack(spacing: 0) {
                        TabSelectorButton(
                            title: LocalizationKey.pointsPoints.localized,
                            isSelected: selectedTab == 0,
                            icon: "star.fill"
                        ) {
                            switchTab(to: 0)
                        }
                        
                        TabSelectorButton(
                            title: LocalizationKey.couponCoupons.localized,
                            isSelected: selectedTab == 1,
                            icon: "ticket.fill"
                        ) {
                            switchTab(to: 1)
                        }
                        
                        TabSelectorButton(
                            title: LocalizationKey.couponCheckIn.localized,
                            isSelected: selectedTab == 2,
                            icon: "calendar.badge.plus"
                        ) {
                            switchTab(to: 2)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        PointsView(viewModel: viewModel)
                            .tag(0)
                        
                        CouponsView(viewModel: viewModel)
                            .tag(1)
                        
                        CheckInView(viewModel: viewModel)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            } // end else (已登录)
        }
        .navigationTitle(LocalizationKey.pointsAndCoupons.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if appState.isAuthenticated {
                viewModel.loadPointsAccount()
                viewModel.loadAvailableCoupons()
                viewModel.loadMyCoupons()
                viewModel.loadCheckInStatus()
                viewModel.loadCheckInRewards()
                viewModel.loadTransactions()
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
    
    private func switchTab(to index: Int) {
        if selectedTab != index {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }
    }
}

struct TabSelectorButton: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    IconStyle.icon(icon, size: 14)
                    Text(title)
                        .font(AppTypography.subheadline)
                        .fontWeight(isSelected ? .bold : .medium)
                }
                .foregroundColor(isSelected ? AppColors.primary : AppColors.textTertiary)
                
                // Indicator
                ZStack {
                    Capsule()
                        .fill(isSelected ? AppColors.primary : Color.clear)
                        .frame(width: 40, height: 3)
                        .shadow(color: isSelected ? AppColors.primary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}

// MARK: - Points View

struct PointsView: View {
    @ObservedObject var viewModel: CouponPointsViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xl) {
                // Account Card (Modern Gradient Card)
                if let account = viewModel.pointsAccount {
                    PointsBalanceCard(account: account)
                        .padding(.top, AppSpacing.md)
                    
                    // Usage Instructions
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: LocalizationKey.couponUsageInstructions.localized, icon: "info.circle.fill")
                        
                        VStack(spacing: AppSpacing.md) {
                            // Allowed
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label(LocalizationKey.couponAllowed.localized, systemImage: "checkmark.circle.fill")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.success)
                                
                                CouponFlowLayout(spacing: 8) {
                                    ForEach(account.usageRestrictions.allowed, id: \.self) { item in
                                        Text(item)
                                            .font(AppTypography.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(AppColors.success.opacity(0.08))
                                            .foregroundColor(AppColors.success)
                                            .cornerRadius(AppCornerRadius.small)
                                    }
                                }
                            }
                            
                            Divider().background(AppColors.divider.opacity(0.5))
                            
                            // Forbidden
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label(LocalizationKey.couponForbidden.localized, systemImage: "xmark.circle.fill")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.error)
                                
                                CouponFlowLayout(spacing: 8) {
                                    ForEach(account.usageRestrictions.forbidden, id: \.self) { item in
                                        Text(item)
                                            .font(AppTypography.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(AppColors.error.opacity(0.08))
                                            .foregroundColor(AppColors.error)
                                            .cornerRadius(AppCornerRadius.small)
                                    }
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                
                // Transactions
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        SectionHeader(title: LocalizationKey.couponTransactionHistory.localized, icon: "clock.arrow.2.circlepath")
                        Spacer()
                        if !viewModel.transactions.isEmpty {
                            Text(LocalizationKey.pointsShowRecentOnly.localized)
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textQuaternary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    if viewModel.transactions.isEmpty {
                        EmptyStateView(
                            icon: "tray.fill",
                            title: LocalizationKey.pointsNoTransactionHistory.localized,
                            message: LocalizationKey.pointsTransactionHistory.localized
                        )
                        .padding(.top, AppSpacing.xl)
                    } else {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(viewModel.transactions) { transaction in
                                TransactionRowView(transaction: transaction)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable {
            HapticFeedback.light()
            viewModel.loadPointsAccount()
            viewModel.loadTransactions()
        }
    }
}

struct PointsBalanceCard: View {
    let account: PointsAccount
    
    // 格式化货币显示（将便士转换为英镑）
    private func formatCurrency(_ pence: Int, currency: String) -> String {
        let pounds = Double(pence) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: pounds)) ?? "£\(String(format: "%.2f", pounds))"
    }
    
    var body: some View {
        ZStack {
            // Gradient Background
            RoundedRectangle(cornerRadius: AppCornerRadius.xlarge)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: AppColors.gradientPrimary),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: AppColors.primary.opacity(0.3), radius: 15, x: 0, y: 10)
            
            // Decorative Circles
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 150, height: 150)
                .offset(x: 120, y: -60)
            
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 20)
                .frame(width: 200, height: 200)
                .offset(x: -100, y: 80)
            
            VStack(spacing: AppSpacing.lg) {
                // Balance
                VStack(spacing: 4) {
                    Text(LocalizationKey.pointsBalance.localized)
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(account.balance)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(LocalizationKey.pointsUnit.localized)
                            .font(AppTypography.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Stats
                HStack {
                    BalanceStatItem(
                        label: LocalizationKey.pointsTotalEarned.localized,
                        value: formatCurrency(account.totalEarned, currency: account.currency),
                        icon: "arrow.down.circle.fill"
                    )
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 30)
                    
                    Spacer()
                    
                    BalanceStatItem(
                        label: LocalizationKey.pointsTotalSpent.localized,
                        value: formatCurrency(account.totalSpent, currency: account.currency),
                        icon: "arrow.up.circle.fill"
                    )
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .padding(AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.md)
    }
}

struct BalanceStatItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(AppTypography.caption2)
            }
            .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

struct TransactionRowView: View {
    let transaction: PointsTransaction
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Status Icon
            ZStack {
                Circle()
                    .fill((transaction.amount > 0 ? AppColors.success : AppColors.error).opacity(0.1))
                    .frame(width: 40, height: 40)
                
                IconStyle.icon(
                    transaction.amount > 0 ? "plus.circle.fill" : "minus.circle.fill",
                    size: 18
                )
                .foregroundColor(transaction.amount > 0 ? AppColors.success : AppColors.error)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description ?? transaction.type)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(DateFormatterHelper.shared.formatTime(transaction.createdAt))
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textQuaternary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.amount > 0 ? "+" : "")\(transaction.amount) \(LocalizationKey.pointsUnit.localized)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.amount > 0 ? AppColors.success : AppColors.textPrimary)
                
                Text("\(LocalizationKey.pointsBalanceAfter.localized): \(transaction.balanceAfter) \(LocalizationKey.pointsUnit.localized)")
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
}

// 辅助布局组件
struct CouponFlowLayout: View {
    var spacing: CGFloat
    var content: [AnyView]
    
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.content = data.map { AnyView(content($0)) }
    }
    
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> some View) {
        self.spacing = spacing
        self.content = [AnyView(content())] 
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(0..<content.count, id: \.self) { index in
                    content[index]
                }
            }
        }
    }
}

// MARK: - Coupons View

struct CouponsView: View {
    @ObservedObject var viewModel: CouponPointsViewModel
    @State private var showingAvailable = true
    @State private var redemptionCode = ""
    @State private var isRedeeming = false
    @State private var showRedeemSuccess = false
    @State private var redeemSuccessMessage = ""
    @State private var showRedeemError = false
    @State private var redeemErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Toggle
            HStack(spacing: 0) {
                CouponTabButton(title: LocalizationKey.couponAvailable.localized, isSelected: showingAvailable) {
                    withAnimation(.spring(response: 0.3)) {
                        showingAvailable = true
                        HapticFeedback.light()
                    }
                }
                
                CouponTabButton(title: LocalizationKey.couponMyCoupons.localized, isSelected: !showingAvailable) {
                    withAnimation(.spring(response: 0.3)) {
                        showingAvailable = false
                        HapticFeedback.light()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            
            // List
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.lg) {
                    if showingAvailable {
                        // 兑换码输入区域
                        RedemptionCodeInputView(
                            code: $redemptionCode,
                            isRedeeming: $isRedeeming,
                            onRedeem: redeemWithCode
                        )
                        .padding(.bottom, AppSpacing.sm)
                        
                        if viewModel.availableCoupons.isEmpty {
                            EmptyStateView(
                                icon: "ticket",
                                title: LocalizationKey.couponNoAvailableCoupons.localized,
                                message: LocalizationKey.couponNoAvailableCouponsMessage.localized
                            )
                            .padding(.top, 40)
                        } else {
                            // 可领取优惠券标题
                            HStack {
                                Text(LocalizationKey.couponAvailableCoupons.localized)
                                    .font(AppTypography.bodyBold)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                            }
                            .padding(.top, AppSpacing.sm)
                            
                            ForEach(viewModel.availableCoupons) { coupon in
                                CouponCardView(coupon: coupon, isAvailable: true, viewModel: viewModel)
                            }
                        }
                    } else {
                        if viewModel.myCoupons.isEmpty {
                            EmptyStateView(
                                icon: "ticket.fill",
                                title: LocalizationKey.couponNoMyCoupons.localized,
                                message: LocalizationKey.couponNoMyCouponsMessage.localized
                            )
                            .padding(.top, 60)
                        } else {
                            ForEach(viewModel.myCoupons) { userCoupon in
                                CouponCardView(
                                    coupon: userCoupon.coupon,
                                    isAvailable: false,
                                    viewModel: viewModel,
                                    status: userCoupon.status
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .alert(LocalizationKey.couponRedeemSuccess.localized, isPresented: $showRedeemSuccess) {
            Button(LocalizationKey.commonOk.localized) {
                viewModel.loadAvailableCoupons()
                viewModel.loadMyCoupons()
            }
        } message: {
            Text(redeemSuccessMessage)
        }
        .alert(LocalizationKey.couponRedeemFailed.localized, isPresented: $showRedeemError) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) {}
        } message: {
            Text(redeemErrorMessage)
        }
    }
    
    private func redeemWithCode() {
        guard !redemptionCode.isEmpty else { return }
        
        isRedeeming = true
        viewModel.redeemWithCode(redemptionCode) { result in
            isRedeeming = false
            switch result {
            case .success(let response):
                redemptionCode = ""
                redeemSuccessMessage = response.message
                showRedeemSuccess = true
                HapticFeedback.success()
            case .failure(let error):
                redeemErrorMessage = (error as? APIError)?.userFriendlyMessage ?? error.localizedDescription
                showRedeemError = true
                HapticFeedback.error()
            }
        }
    }
}

// MARK: - 兑换码输入视图
struct RedemptionCodeInputView: View {
    @Binding var code: String
    @Binding var isRedeeming: Bool
    let onRedeem: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(AppColors.primary)
                Text(LocalizationKey.couponEnterRedemptionCode.localized)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            HStack(spacing: AppSpacing.sm) {
                TextField(LocalizationKey.couponEnterRedemptionCodePlaceholder.localized, text: $code)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.surface)
                    .cornerRadius(AppCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                    )
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                
                Button(action: onRedeem) {
                    if isRedeeming {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 24, height: 24)
                    } else {
                        Text(LocalizationKey.couponRedeem.localized)
                            .font(AppTypography.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(code.isEmpty || isRedeeming ? AppColors.textSecondary : AppColors.primary)
                .cornerRadius(AppCornerRadius.medium)
                .disabled(code.isEmpty || isRedeeming)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CouponTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? AppColors.primary : AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .stroke(isSelected ? Color.clear : AppColors.separator.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct CouponCardView: View {
    let coupon: Coupon
    let isAvailable: Bool
    @ObservedObject var viewModel: CouponPointsViewModel
    var status: String? = nil
    
    @State private var isClaiming = false
    @State private var isRedeemingWithPoints = false
    @State private var showPointsRedeemConfirm = false
    @State private var showRedeemSuccess = false
    @State private var redeemMessage = ""
    @State private var showRedeemError = false
    @State private var redeemErrorMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Section (Value)
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("£")
                        .font(.system(size: 14, weight: .bold))
                    Text(formatDiscount(coupon.discountValue))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                
                Text(coupon.minAmount > 0 ? String(format: LocalizationKey.couponMinAmountAvailable.localized, "£\(coupon.minAmount/100)") : LocalizationKey.couponNoThreshold.localized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
            }
            .frame(width: 100, height: 100)
            .background(
                ZStack {
                    if isAvailable {
                        LinearGradient(
                            gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        status == "unused" ? AppColors.warning : AppColors.textQuaternary
                    }
                }
            )
            
            // Divider (Perforated Line)
            ZStack {
                Rectangle()
                    .fill(AppColors.cardBackground)
                    .frame(width: 1)
                
                VStack(spacing: 4) {
                    ForEach(0..<10) { _ in
                        Circle()
                            .fill(AppColors.background)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: 1, height: 100)
            
            // Right Section (Info)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(coupon.name)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isAvailable {
                        HStack(spacing: 8) {
                            // 免费领取按钮
                            Button(action: claimCoupon) {
                                if isClaiming {
                                    ProgressView().tint(AppColors.primary)
                                } else {
                                    Text(LocalizationKey.couponClaimNow.localized)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppColors.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppColors.primaryLight)
                                        .cornerRadius(12)
                                }
                            }
                            .disabled(isClaiming)
                            
                            // 积分兑换按钮（如果支持）
                            if coupon.canRedeemWithPoints, let points = coupon.pointsRequired {
                                Button(action: { showPointsRedeemConfirm = true }) {
                                    if isRedeemingWithPoints {
                                        ProgressView().tint(AppColors.warning)
                                    } else {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 8))
                                            Text("\(points)")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(AppColors.warning)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(AppColors.warning.opacity(0.15))
                                        .cornerRadius(12)
                                    }
                                }
                                .disabled(isRedeemingWithPoints)
                            }
                        }
                    } else {
                        CouponStatusBadge(status: status ?? "unused")
                    }
                }
                
                Spacer()
                
                HStack {
                    Text(coupon.code)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textQuaternary)
                    
                    Spacer()
                    
                    Text(String(format: LocalizationKey.couponValidUntil.localized, formatDate(coupon.validUntil)))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: 100, alignment: .leading)
            .background(AppColors.cardBackground)
        }
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        // Side Cutouts (HIG Ticket Look)
        .overlay(
            ZStack {
                Circle()
                    .fill(AppColors.background)
                    .frame(width: 12, height: 12)
                    .offset(x: -UIScreen.main.bounds.width/2 + 100 + 16 + 6, y: -50)
                
                Circle()
                    .fill(AppColors.background)
                    .frame(width: 12, height: 12)
                    .offset(x: -UIScreen.main.bounds.width/2 + 100 + 16 + 6, y: 50)
            }
        )
        .alert(LocalizationKey.couponConfirmRedeem.localized, isPresented: $showPointsRedeemConfirm) {
            Button(LocalizationKey.commonCancel.localized, role: .cancel) {}
            Button(LocalizationKey.couponConfirmRedeem.localized) {
                redeemWithPoints()
            }
        } message: {
            Text(String(format: LocalizationKey.couponConfirmRedeemWithPoints.localized, coupon.pointsRequired ?? 0))
        }
        .alert(LocalizationKey.couponRedeemSuccess.localized, isPresented: $showRedeemSuccess) {
            Button(LocalizationKey.commonOk.localized) {}
        } message: {
            Text(redeemMessage)
        }
        .alert(LocalizationKey.couponRedeemFailed.localized, isPresented: $showRedeemError) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) {}
        } message: {
            Text(redeemErrorMessage)
        }
    }
    
    private func formatDiscount(_ value: Int) -> String {
        return "\(value / 100)"
    }
    
    private func formatDate(_ dateStr: String) -> String {
        return dateStr.prefix(10).description
    }
    
    private func claimCoupon() {
        HapticFeedback.success()
        isClaiming = true
        viewModel.claimCoupon(couponId: coupon.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isClaiming = false
                    if case .failure(let error) = completion {
                        redeemErrorMessage = (error as? APIError)?.userFriendlyMessage ?? error.localizedDescription
                        showRedeemError = true
                        HapticFeedback.error()
                    } else {
                        viewModel.loadAvailableCoupons()
                        viewModel.loadMyCoupons()
                        HapticFeedback.success()
                    }
                },
                receiveValue: { response in
                    redeemMessage = response.message
                    showRedeemSuccess = true
                }
            )
            .store(in: &cancellables)
    }
    
    private func redeemWithPoints() {
        isRedeemingWithPoints = true
        viewModel.redeemCouponWithPoints(couponId: coupon.id) { result in
            isRedeemingWithPoints = false
            switch result {
            case .success(let response):
                redeemMessage = response.message
                showRedeemSuccess = true
                viewModel.loadAvailableCoupons()
                viewModel.loadMyCoupons()
                viewModel.loadPointsAccount()
                HapticFeedback.success()
            case .failure(let error):
                redeemErrorMessage = (error as? APIError)?.userFriendlyMessage ?? error.localizedDescription
                showRedeemError = true
                HapticFeedback.error()
            }
        }
    }
}

// 优惠券状态标签组件（与 TasksView 中的 StatusBadge 不同，这里使用 String 类型）
struct CouponStatusBadge: View {
    let status: String
    
    var body: some View {
        Text(statusText)
            .font(AppTypography.caption2)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(statusColor.opacity(0.15))
            .cornerRadius(AppCornerRadius.small)
    }
    
    private var statusText: String {
        switch status {
        case "unused": return LocalizationKey.couponStatusUnused.localized
        case "used": return LocalizationKey.couponStatusUsed.localized
        case "expired": return LocalizationKey.couponStatusExpired.localized
        default: return status
        }
    }
    
    private var statusColor: Color {
        switch status {
        case "unused": return AppColors.success
        case "used": return AppColors.textSecondary
        case "expired": return AppColors.error
        default: return AppColors.textSecondary
        }
    }
}

// MARK: - Check In View

struct CheckInView: View {
    @ObservedObject var viewModel: CouponPointsViewModel
    @State private var checkInResult: CheckInResponse?
    @State private var showingResult = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.xl) {
                // Status Card (Hero Section)
                if let status = viewModel.checkInStatus {
                    CheckInStatusCard(status: status, onCheckIn: performCheckIn)
                        .padding(.top, AppSpacing.md)
                }
                
                // Rewards List
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    SectionHeader(title: LocalizationKey.couponCheckInReward.localized, icon: "gift.fill")
                        .padding(.horizontal, AppSpacing.md)
                    
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.checkInRewards, id: \.consecutiveDays) { reward in
                            RewardRowView(
                                reward: reward,
                                currentDays: viewModel.checkInStatus?.consecutiveDays ?? 0
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                
                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Label(LocalizationKey.couponCheckInRules.localized, systemImage: "lightbulb.fill")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(LocalizationKey.pointsCheckInDescription.localized)
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textQuaternary)
                        .lineSpacing(4)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground.opacity(0.5))
                .cornerRadius(AppCornerRadius.medium)
                .padding(.horizontal, AppSpacing.md)
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable {
            HapticFeedback.light()
            viewModel.loadCheckInStatus()
            viewModel.loadCheckInRewards()
        }
        .alert(LocalizationKey.couponCheckInSuccess.localized, isPresented: $showingResult) {
            Button(LocalizationKey.couponAwesome.localized, role: .cancel) {
                checkInResult = nil
                viewModel.loadCheckInStatus()
            }
        } message: {
            if let result = checkInResult {
                Text("\(result.message)\n\(result.reward?.description ?? "")")
            }
        }
    }
    
    private func performCheckIn() {
        HapticFeedback.success()
        viewModel.performCheckIn()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { response in
                    checkInResult = response
                    showingResult = true
                }
            )
            .store(in: &cancellables)
    }
}

struct CheckInStatusCard: View {
    let status: CheckInStatus
    let onCheckIn: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Animated Header
            ZStack {
                Circle()
                    .fill(status.todayChecked ? AppColors.success.opacity(0.1) : AppColors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(status.todayChecked ? AppColors.success.opacity(0.2) : AppColors.primary.opacity(0.2), lineWidth: 2)
                    .frame(width: 140, height: 140)
                
                VStack(spacing: 8) {
                    IconStyle.icon(
                        status.todayChecked ? "checkmark.seal.fill" : "calendar.badge.plus",
                        size: 44
                    )
                    .foregroundColor(status.todayChecked ? AppColors.success : AppColors.primary)
                    
                    if status.consecutiveDays > 0 {
                        Text(String(format: LocalizationKey.couponDays.localized, status.consecutiveDays))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(status.todayChecked ? AppColors.success : AppColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background((status.todayChecked ? AppColors.success : AppColors.primary).opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.top, 10)
            
            VStack(spacing: AppSpacing.xs) {
                Text(status.todayChecked ? LocalizationKey.pointsCheckedInToday.localized : LocalizationKey.pointsCheckInReward.localized)
                    .font(AppTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(status.todayChecked ? LocalizationKey.couponRememberTomorrow.localized : LocalizationKey.couponConsecutiveReward.localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            if !status.todayChecked {
                Button(action: onCheckIn) {
                    Text(LocalizationKey.couponCheckInNow.localized)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, AppSpacing.xl)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(String(format: LocalizationKey.couponConsecutiveDays.localized, status.consecutiveDays))
                }
                .font(AppTypography.caption)
                .fontWeight(.bold)
                .foregroundColor(AppColors.success)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.success.opacity(0.08))
                .cornerRadius(20)
            }
        }
        .padding(.vertical, AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.xlarge)
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, AppSpacing.md)
    }
}

struct RewardRowView: View {
    let reward: CheckInRewardConfig
    let currentDays: Int
    
    var isCompleted: Bool {
        currentDays >= reward.consecutiveDays
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon / Number
            ZStack {
                Circle()
                    .fill(isCompleted ? AppColors.success.opacity(0.1) : AppColors.background)
                    .frame(width: 44, height: 44)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.success)
                } else {
                    Text("\(reward.consecutiveDays)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: LocalizationKey.couponConsecutiveCheckIn.localized, reward.consecutiveDays))
                    .font(AppTypography.bodyBold)
                    .foregroundColor(isCompleted ? AppColors.textPrimary : AppColors.textSecondary)
                
                Text(reward.description)
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textQuaternary)
            }
            
            Spacer()
            
            // Reward Value
            if let points = reward.pointsReward {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("\(points) \(LocalizationKey.pointsUnit.localized)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(isCompleted ? AppColors.success : AppColors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((isCompleted ? AppColors.success : AppColors.primary).opacity(0.08))
                .cornerRadius(12)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .stroke(isCompleted ? AppColors.success.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    CouponPointsView()
}

