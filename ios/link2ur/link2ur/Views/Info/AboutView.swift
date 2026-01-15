import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Header
                VStack(spacing: AppSpacing.md) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .padding(.top, AppSpacing.xl)
                    
                    Text("Link²Ur")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(LocalizationKey.infoConnectPlatform.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, AppSpacing.lg)
                
                // 关于我们
                InfoSection(
                    icon: "info.circle.fill",
                    title: LocalizationKey.infoAboutUs.localized,
                    content: LocalizationKey.infoAboutUsContent.localized
                )
                
                // 我们的使命
                InfoSection(
                    icon: "target",
                    title: LocalizationKey.infoOurMission.localized,
                    content: LocalizationKey.infoOurMissionContent.localized
                )
                
                // 我们的愿景
                InfoSection(
                    icon: "eye.fill",
                    title: LocalizationKey.infoOurVision.localized,
                    content: LocalizationKey.infoOurVisionContent.localized
                )
                
                // 联系方式
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(LocalizationKey.infoContactUs.localized)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    ContactRow(icon: "envelope.fill", text: "support@link2ur.com")
                    ContactRow(icon: "globe", text: "www.link2ur.com")
                }
                .padding(AppSpacing.md)
                .cardStyle()
                .padding(.horizontal, AppSpacing.md)
                
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle(LocalizationKey.infoAboutUs.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct InfoSection: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 40)
                
                Text(title)
                    .font(AppTypography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(content)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

struct ContactRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}

