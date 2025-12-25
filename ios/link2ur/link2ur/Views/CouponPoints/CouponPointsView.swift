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
                    
                    Text("login.required")
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("login.required_for_points")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showLogin = true
                    }) {
                        Text("login.login_now")
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
                            title: "积分",
                            isSelected: selectedTab == 0,
                            icon: "star.fill"
                        ) {
                            switchTab(to: 0)
                        }
                        
                        TabSelectorButton(
                            title: "优惠券",
                            isSelected: selectedTab == 1,
                            icon: "ticket.fill"
                        ) {
                            switchTab(to: 1)
                        }
                        
                        TabSelectorButton(
                            title: "签到",
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
        .navigationTitle("积分与优惠券")
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
                        SectionHeader(title: "使用说明", icon: "info.circle.fill")
                        
                        VStack(spacing: AppSpacing.md) {
                            // Allowed
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Label("可用于", systemImage: "checkmark.circle.fill")
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
                                Label("不可用于", systemImage: "xmark.circle.fill")
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
                        SectionHeader(title: "交易记录", icon: "clock.arrow.2.circlepath")
                        Spacer()
                        if !viewModel.transactions.isEmpty {
                            Text("仅显示最近记录")
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textQuaternary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    if viewModel.transactions.isEmpty {
                        EmptyStateView(
                            icon: "tray.fill",
                            title: "暂无交易记录",
                            message: "您的积分变动记录将显示在这里"
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
                    Text("points.balance")
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(account.balance)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("points.unit")
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
                        label: String(localized: "points.total_earned"),
                        value: "\(account.totalEarned)",
                        icon: "arrow.down.circle.fill"
                    )
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 30)
                    
                    Spacer()
                    
                    BalanceStatItem(
                        label: String(localized: "points.total_spent"),
                        value: "\(account.totalSpent)",
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
                Text("\(transaction.amount > 0 ? "+" : "")\(transaction.amount) \(String(localized: "points.unit"))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.amount > 0 ? AppColors.success : AppColors.textPrimary)
                
                Text("\(String(localized: "points.balance_after")): \(transaction.balanceAfter) \(String(localized: "points.unit"))")
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Toggle
            HStack(spacing: 0) {
                CouponTabButton(title: "可领取的", isSelected: showingAvailable) {
                    withAnimation(.spring(response: 0.3)) {
                        showingAvailable = true
                        HapticFeedback.light()
                    }
                }
                
                CouponTabButton(title: "我的卡券", isSelected: !showingAvailable) {
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
                        if viewModel.availableCoupons.isEmpty {
                            EmptyStateView(
                                icon: "ticket",
                                title: "暂无可用优惠券",
                                message: "目前没有可领取的优惠券，关注活动哦"
                            )
                            .padding(.top, 60)
                        } else {
                            ForEach(viewModel.availableCoupons) { coupon in
                                CouponCardView(coupon: coupon, isAvailable: true, viewModel: viewModel)
                            }
                        }
                    } else {
                        if viewModel.myCoupons.isEmpty {
                            EmptyStateView(
                                icon: "ticket.fill",
                                title: "您还没有优惠券",
                                message: "领取的优惠券将出现在这里"
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
                
                Text(coupon.minAmount > 0 ? "满£\(coupon.minAmount/100)可用" : "无门槛")
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
                        Button(action: claimCoupon) {
                            if isClaiming {
                                ProgressView().tint(AppColors.primary)
                            } else {
                                Text("立即领取")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppColors.primaryLight)
                                    .cornerRadius(12)
                            }
                        }
                        .disabled(isClaiming)
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
                    
                    Text("有效期至: \(formatDate(coupon.validUntil))")
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
                        print("Claim coupon error: \(error)")
                    } else {
                        viewModel.loadAvailableCoupons()
                        viewModel.loadMyCoupons()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
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
        case "unused": return "未使用"
        case "used": return "已使用"
        case "expired": return "已过期"
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
                    SectionHeader(title: "签到奖励", icon: "gift.fill")
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
                    Label("签到规则", systemImage: "lightbulb.fill")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("• 每日签到可获得积分奖励\n• 连续签到天数越多，奖励越丰厚\n• 签到中断后，连续天数将重新计算")
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
        .alert("签到成功", isPresented: $showingResult) {
            Button("太棒了", role: .cancel) {
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
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Check in error: \(error)")
                    }
                },
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
                        Text("\(status.consecutiveDays)天")
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
                Text(status.todayChecked ? "今日已签到" : "签到领积分")
                    .font(AppTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(status.todayChecked ? "明天也要记得来哦" : "连续签到奖励更丰富")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            if !status.todayChecked {
                Button(action: onCheckIn) {
                    Text("立即签到")
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
                    Text("已连续签到 \(status.consecutiveDays) 天")
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
                Text("\(reward.consecutiveDays)天连续签到")
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
                    Text("\(points) \(String(localized: "points.unit"))")
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

