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
                    title: "关于我们",
                    content: "Link²Ur 是一个创新的任务发布与接取平台，致力于连接需要帮助的人和愿意提供帮助的人。我们相信每个人都有自己的技能和时间，通过平台可以让这些资源得到更好的利用。"
                )
                
                // 我们的使命
                InfoSection(
                    icon: "target",
                    title: "我们的使命",
                    content: "让任务发布和接取变得简单、高效、安全。我们致力于打造一个值得信赖的社区平台，让每个人都能找到合适的任务，也能为他人提供帮助。"
                )
                
                // 我们的愿景
                InfoSection(
                    icon: "eye.fill",
                    title: "我们的愿景",
                    content: "成为英国最受欢迎的任务平台，连接成千上万的用户，创造更多价值，让社区更加紧密。"
                )
                
                // 联系方式
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("联系我们")
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
        .navigationTitle("关于我们")
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

