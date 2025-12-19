import SwiftUI
import Combine

struct CouponPointsView: View {
    @StateObject private var viewModel = CouponPointsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Tab Selector
                    HStack(spacing: 0) {
                        TabSelectorButton(
                            title: "积分",
                            isSelected: selectedTab == 0,
                            icon: "star.fill"
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = 0
                            }
                        }
                        
                        TabSelectorButton(
                            title: "优惠券",
                            isSelected: selectedTab == 1,
                            icon: "ticket.fill"
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = 1
                            }
                        }
                        
                        TabSelectorButton(
                            title: "签到",
                            isSelected: selectedTab == 2,
                            icon: "calendar.badge.plus"
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = 2
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.cardBackground)
                    
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
            }
            .navigationTitle("积分与优惠券")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadPointsAccount()
                viewModel.loadAvailableCoupons()
                viewModel.loadMyCoupons()
                viewModel.loadCheckInStatus()
                viewModel.loadCheckInRewards()
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
            VStack(spacing: 6) {
                IconStyle.icon(icon, size: IconStyle.medium)
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                
                Text(title)
                    .font(AppTypography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                
                if isSelected {
                    Capsule()
                        .fill(AppColors.primary)
                        .frame(height: 3)
                        .frame(width: 40)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(height: 3)
                        .frame(width: 40)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Points View

struct PointsView: View {
    @ObservedObject var viewModel: CouponPointsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Account Card
                if let account = viewModel.pointsAccount {
                    VStack(spacing: AppSpacing.md) {
                        // Balance Display
                        VStack(spacing: AppSpacing.sm) {
                            Text("积分余额")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(account.balanceDisplay)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.primary)
                            
                            Text(account.currency)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Divider()
                            .padding(.vertical, AppSpacing.sm)
                        
                        // Stats
                        HStack(spacing: AppSpacing.xl) {
                            StatItem(
                                label: "累计获得",
                                value: "\(account.totalEarned / 100)",
                                color: .green
                            )
                            
                            StatItem(
                                label: "累计消费",
                                value: "\(account.totalSpent / 100)",
                                color: .orange
                            )
                        }
                    }
                    .padding(AppSpacing.lg)
                    .cardStyle(cornerRadius: AppCornerRadius.large)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                    
                    // Usage Restrictions
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("使用说明")
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("可用于")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            ForEach(account.usageRestrictions.allowed, id: \.self) { item in
                                HStack(spacing: AppSpacing.sm) {
                                    IconStyle.icon("checkmark.circle.fill", size: IconStyle.small)
                                        .foregroundColor(AppColors.success)
                                    Text(item)
                                        .font(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("不可用于")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            ForEach(account.usageRestrictions.forbidden, id: \.self) { item in
                                HStack(spacing: AppSpacing.sm) {
                                    IconStyle.icon("xmark.circle.fill", size: IconStyle.small)
                                        .foregroundColor(AppColors.error)
                                    Text(item)
                                        .font(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .cardStyle()
                    .padding(.horizontal, AppSpacing.md)
                }
                
                // Transactions
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("交易记录")
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    if viewModel.transactions.isEmpty {
                        EmptyStateView(
                            icon: "list.bullet",
                            title: "暂无交易记录",
                            message: "您的积分交易记录将显示在这里"
                        )
                        .padding(.top, AppSpacing.xl)
                    } else {
                        ForEach(viewModel.transactions) { transaction in
                            TransactionRowView(transaction: transaction)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .refreshable {
            viewModel.loadPointsAccount()
            viewModel.loadTransactions()
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TransactionRowView: View {
    let transaction: PointsTransaction
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        (transaction.amount > 0 ? AppColors.success : AppColors.error).opacity(0.15)
                    )
                    .frame(width: 44, height: 44)
                
                IconStyle.icon(
                    transaction.amount > 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                    size: IconStyle.medium
                )
                .foregroundColor(transaction.amount > 0 ? AppColors.success : AppColors.error)
            }
            
            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(transaction.description ?? transaction.type)
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(transaction.createdAt)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.amountDisplay)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.amount > 0 ? AppColors.success : AppColors.error)
                
                Text("余额: \(transaction.balanceAfterDisplay)")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

// MARK: - Coupons View

struct CouponsView: View {
    @ObservedObject var viewModel: CouponPointsViewModel
    @State private var showingAvailable = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Toggle
            Picker("", selection: $showingAvailable) {
                Text("可用优惠券").tag(true)
                Text("我的优惠券").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            
            // List
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    if showingAvailable {
                        if viewModel.availableCoupons.isEmpty {
                            EmptyStateView(
                                icon: "ticket",
                                title: "暂无可用优惠券",
                                message: "目前没有可领取的优惠券"
                            )
                            .padding(.top, AppSpacing.xl)
                        } else {
                            ForEach(viewModel.availableCoupons) { coupon in
                                CouponCardView(coupon: coupon, isAvailable: true, viewModel: viewModel)
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    } else {
                        if viewModel.myCoupons.isEmpty {
                            EmptyStateView(
                                icon: "ticket.fill",
                                title: "您还没有优惠券",
                                message: "领取的优惠券将显示在这里"
                            )
                            .padding(.top, AppSpacing.xl)
                        } else {
                            ForEach(viewModel.myCoupons) { userCoupon in
                                CouponCardView(
                                    coupon: userCoupon.coupon,
                                    isAvailable: false,
                                    viewModel: viewModel,
                                    status: userCoupon.status
                                )
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(coupon.name)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(coupon.code)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if isAvailable {
                    Button(action: claimCoupon) {
                        if isClaiming {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("领取")
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.primary)
                                .cornerRadius(AppCornerRadius.small)
                        }
                    }
                    .disabled(isClaiming)
                } else {
                    CouponStatusBadge(status: status ?? "unused")
                }
            }
            
            Divider()
            
            // Details
            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("折扣金额")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(coupon.discountValueDisplay)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("最低消费")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(coupon.minAmountDisplay)
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            
            if !isAvailable {
                HStack(spacing: AppSpacing.xs) {
                    IconStyle.icon("calendar", size: IconStyle.small)
                        .foregroundColor(AppColors.textSecondary)
                    Text("有效期至: \(coupon.validUntil)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
    
    private func claimCoupon() {
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
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Status Card
                if let status = viewModel.checkInStatus {
                    VStack(spacing: AppSpacing.lg) {
                        // Icon and Status
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            status.todayChecked ? AppColors.success : AppColors.primary,
                                            (status.todayChecked ? AppColors.success : AppColors.primary).opacity(0.7)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(
                                    color: (status.todayChecked ? AppColors.success : AppColors.primary).opacity(0.3),
                                    radius: 20,
                                    x: 0,
                                    y: 10
                                )
                            
                            IconStyle.icon(
                                status.todayChecked ? "checkmark.shield.fill" : "calendar.badge.plus",
                                size: IconStyle.xlarge
                            )
                            .foregroundColor(.white)
                        }
                        
                        VStack(spacing: AppSpacing.sm) {
                            Text(status.todayChecked ? "今日已签到" : "今日未签到")
                                .font(AppTypography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            if status.consecutiveDays > 0 {
                                Text("连续签到 \(status.consecutiveDays) 天")
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        if !status.todayChecked {
                            Button(action: performCheckIn) {
                                HStack {
                                    IconStyle.icon("checkmark.circle.fill", size: IconStyle.medium)
                                    Text("立即签到")
                                        .font(AppTypography.bodyBold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.primary)
                                .cornerRadius(AppCornerRadius.large)
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large))
                        }
                    }
                    .padding(AppSpacing.xl)
                    .cardStyle(cornerRadius: AppCornerRadius.large)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                }
                
                // Rewards List
                if !viewModel.checkInRewards.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("签到奖励")
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.md)
                        
                        ForEach(viewModel.checkInRewards, id: \.consecutiveDays) { reward in
                            RewardRowView(
                                reward: reward,
                                currentDays: viewModel.checkInStatus?.consecutiveDays ?? 0
                            )
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .refreshable {
            viewModel.loadCheckInStatus()
            viewModel.loadCheckInRewards()
        }
        .alert("签到成功", isPresented: $showingResult) {
            Button("确定", role: .cancel) {
                checkInResult = nil
                viewModel.loadCheckInStatus()
            }
        } message: {
            if let result = checkInResult {
                VStack(alignment: .leading) {
                    Text(result.message)
                    if let reward = result.reward {
                        Text("奖励: \(reward.description ?? "")")
                    }
                }
            }
        }
    }
    
    private func performCheckIn() {
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

struct RewardRowView: View {
    let reward: CheckInRewardConfig
    let currentDays: Int
    
    var isCompleted: Bool {
        currentDays >= reward.consecutiveDays
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Check Icon
            ZStack {
                Circle()
                    .fill(isCompleted ? AppColors.success.opacity(0.15) : AppColors.textTertiary.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                IconStyle.icon(
                    isCompleted ? "checkmark.circle.fill" : "circle",
                    size: IconStyle.medium
                )
                .foregroundColor(isCompleted ? AppColors.success : AppColors.textTertiary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("连续签到 \(reward.consecutiveDays) 天")
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(reward.description)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // Reward
            if let points = reward.pointsReward {
                Text("+\(points / 100)")
                    .font(AppTypography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

#Preview {
    CouponPointsView()
}
