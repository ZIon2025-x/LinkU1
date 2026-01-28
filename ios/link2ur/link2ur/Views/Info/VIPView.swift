import SwiftUI

struct VIPView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var iapService = IAPService.shared
    @State private var subscriptionStatus: VIPSubscriptionStatus?
    @State private var isLoadingStatus = false
    @State private var localSubscriptionInfo: SubscriptionStatusInfo?
    
    var isVIP: Bool {
        appState.currentUser?.userLevel == "vip" || appState.currentUser?.userLevel == "super"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // VIP 卡片
                VIPCardView(userLevel: appState.currentUser?.userLevel)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                
                // 购买按钮（如果不是VIP）
                if !isVIP {
                    NavigationLink(destination: VIPPurchaseView()) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20))
                            
                            Text("升级VIP会员")
                                .font(AppTypography.bodyBold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.yellow.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, AppSpacing.md)
                } else {
                    // VIP用户显示状态
                    VStack(spacing: AppSpacing.sm) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("您已是VIP会员")
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Text("感谢您的支持，享受所有VIP权益")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        // 显示订阅到期时间和自动续费状态
                        if let subscription = subscriptionStatus, let expiresDate = subscription.expiresDate {
                            VStack(spacing: AppSpacing.xs) {
                                Text("到期时间：\(formatSubscriptionExpiry(expiresDate))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                if let localInfo = localSubscriptionInfo {
                                    if localInfo.willAutoRenew {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 10))
                                            Text("将自动续费")
                                                .font(AppTypography.caption)
                                        }
                                        .foregroundColor(.green)
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.circle")
                                                .font(.system(size: 10))
                                            Text("已取消自动续费")
                                                .font(AppTypography.caption)
                                        }
                                        .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding(.top, AppSpacing.xs)
                        } else if isLoadingStatus {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.top, AppSpacing.xs)
                        }
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                    .padding(.horizontal, AppSpacing.md)
                }
                
                // 会员权益
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(LocalizationKey.infoMemberBenefits.localized)
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    VIPBenefitRow(
                        icon: "star.fill",
                        title: LocalizationKey.vipPriorityRecommendation.localized,
                        description: LocalizationKey.vipPriorityRecommendationDesc.localized,
                        color: .yellow
                    )
                    
                    VIPBenefitRow(
                        icon: "percent",
                        title: LocalizationKey.vipFeeDiscount.localized,
                        description: LocalizationKey.vipFeeDiscountDesc.localized,
                        color: .green
                    )
                    
                    VIPBenefitRow(
                        icon: "crown.fill",
                        title: LocalizationKey.vipExclusiveBadge.localized,
                        description: LocalizationKey.vipExclusiveBadgeDesc.localized,
                        color: .purple
                    )
                    
                    VIPBenefitRow(
                        icon: "gift.fill",
                        title: LocalizationKey.vipExclusiveActivity.localized,
                        description: LocalizationKey.vipExclusiveActivityDesc.localized,
                        color: .orange
                    )
                }
                .padding(.top, AppSpacing.md)
                
                // 常见问题
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(LocalizationKey.infoFaq.localized)
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    FAQRow(
                        question: LocalizationKey.vipFaqHowToUpgrade.localized,
                        answer: "您可以在VIP会员页面点击\"升级VIP会员\"按钮，选择适合的套餐进行购买。"
                    )
                    
                    FAQRow(
                        question: LocalizationKey.vipFaqWhenEffective.localized,
                        answer: LocalizationKey.vipFaqWhenEffectiveAnswer.localized
                    )
                    
                    FAQRow(
                        question: LocalizationKey.vipFaqCanCancel.localized,
                        answer: LocalizationKey.vipFaqCanCancelAnswer.localized
                    )
                }
                .padding(.top, AppSpacing.md)
                
                // 联系管理员
                VStack(spacing: AppSpacing.md) {
                    Text(LocalizationKey.infoNeedHelp.localized)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(LocalizationKey.infoContactAdmin.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    NavigationLink(destination: CustomerServiceView()) {
                        Text(LocalizationKey.infoContactService.localized)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.primary)
                            .cornerRadius(AppCornerRadius.large)
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .padding(AppSpacing.lg)
                .cardStyle()
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .navigationTitle(LocalizationKey.vipMember.localized)
        .navigationBarTitleDisplayMode(.large)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            if isVIP {
                await loadVIPStatus()
                await loadLocalSubscriptionInfo()
            }
        }
        .onChange(of: isVIP) { newValue in
            if newValue {
                _Concurrency.Task {
                    await loadVIPStatus()
                    await loadLocalSubscriptionInfo()
                }
            } else {
                subscriptionStatus = nil
                localSubscriptionInfo = nil
            }
        }
    }
    
    private func loadVIPStatus() async {
        isLoadingStatus = true
        defer { isLoadingStatus = false }
        
        do {
            let response = try await APIService.shared.getVIPStatus()
            subscriptionStatus = response.subscription
        } catch {
            print("获取VIP状态失败: \(error)")
        }
    }
    
    private func loadLocalSubscriptionInfo() async {
        // 从IAPService获取本地订阅状态信息
        if let activeSubscription = await iapService.getCurrentActiveSubscription() {
            localSubscriptionInfo = activeSubscription
        } else {
            // 尝试从subscriptionStatuses中获取
            await iapService.updateSubscriptionStatuses()
            for (_, info) in iapService.subscriptionStatuses {
                if info.isActive {
                    localSubscriptionInfo = info
                    break
                }
            }
        }
    }
    
    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }

    private func formatSubscriptionExpiry(_ dateString: String) -> String {
        guard let date = parseISO8601Date(dateString) else { return dateString }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

struct VIPCardView: View {
    let userLevel: String?
    
    var isVIP: Bool {
        userLevel == "vip" || userLevel == "super"
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isVIP ? Color.yellow : AppColors.primary,
                                isVIP ? Color.orange : AppColors.primary.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(
                        color: (isVIP ? Color.yellow : AppColors.primary).opacity(0.3),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                Image(systemName: isVIP ? "crown.fill" : "star.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // 状态文本
            VStack(spacing: AppSpacing.sm) {
                Text(isVIP ? LocalizationKey.vipMember.localized : LocalizationKey.vipBecomeVip.localized)
                    .font(AppTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(isVIP ? LocalizationKey.vipEnjoyBenefits.localized : LocalizationKey.vipUnlockPrivileges.localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(
            ZStack {
                // 先设置纯色背景
                AppColors.cardBackground
                // 再叠加渐变（使用 ZStack 确保渐变在背景之上）
                LinearGradient(
                    gradient: Gradient(colors: [
                        (isVIP ? Color.yellow : AppColors.primary).opacity(0.1),
                        (isVIP ? Color.orange : AppColors.primary).opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
        // 使用双层阴影，减少容器边界感（借鉴钱包余额视图的做法）
        .shadow(color: AppColors.primary.opacity(0.08), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}

struct VIPBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(question)
                .font(AppTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(answer)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

#Preview {
    NavigationView {
        VIPView()
            .environmentObject(AppState())
    }
}

