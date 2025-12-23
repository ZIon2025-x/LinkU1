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
                
                // 会员权益
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(LocalizationKey.infoMemberBenefits.localized)
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    VIPBenefitRow(
                        icon: "star.fill",
                        title: "优先推荐",
                        description: "您的任务和申请将优先展示，获得更多曝光机会",
                        color: .yellow
                    )
                    
                    VIPBenefitRow(
                        icon: "percent",
                        title: "手续费优惠",
                        description: "享受更低的任务发布手续费，节省更多成本",
                        color: .green
                    )
                    
                    VIPBenefitRow(
                        icon: "crown.fill",
                        title: "专属标识",
                        description: "显示专属 VIP 标识，提升您的信誉度",
                        color: .purple
                    )
                    
                    VIPBenefitRow(
                        icon: "gift.fill",
                        title: "专属活动",
                        description: "参与 VIP 专属活动和优惠，获得更多奖励",
                        color: .orange
                    )
                }
                .padding(.top, AppSpacing.md)
                
                // 常见问题
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("常见问题")
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    FAQRow(
                        question: "如何升级会员？",
                        answer: "目前会员升级功能正在开发中，您可以联系管理员手动升级，或等待自动升级功能上线。"
                    )
                    
                    FAQRow(
                        question: "会员权益何时生效？",
                        answer: "会员权益在升级后立即生效，您可以立即享受相应的特权服务。"
                    )
                    
                    FAQRow(
                        question: "可以随时取消会员吗？",
                        answer: "是的，您可以随时联系管理员取消会员服务，取消后将在下个计费周期生效。"
                    )
                }
                .padding(.top, AppSpacing.md)
                
                // 联系管理员
                VStack(spacing: AppSpacing.md) {
                    Text("需要帮助？")
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
        .navigationTitle("VIP 会员")
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
                Text(isVIP ? "您是 VIP 会员" : "成为 VIP 会员")
                    .font(AppTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(isVIP ? "享受专属权益和特权" : "解锁更多特权和服务")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .cardStyle(cornerRadius: AppCornerRadius.large)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    (isVIP ? Color.yellow : AppColors.primary).opacity(0.1),
                    (isVIP ? Color.orange : AppColors.primary).opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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

