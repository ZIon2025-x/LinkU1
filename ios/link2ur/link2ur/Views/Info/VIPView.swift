import SwiftUI

struct VIPView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // VIP 卡片
                VIPCardView(userLevel: appState.currentUser?.userLevel)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                
                // VIP功能即将推出提示
                VStack(spacing: AppSpacing.md) {
                    Text(LocalizationKey.vipComingSoon.localized)
                        .font(AppTypography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                }
                .padding(.horizontal, AppSpacing.md)
                
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
                        answer: LocalizationKey.vipComingSoon.localized
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

