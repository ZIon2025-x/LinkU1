import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("隐私政策")
                    .font(AppTypography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                
                PrivacySection(
                    title: "1. 信息收集",
                    content: "我们收集的信息包括：注册信息（邮箱、手机号等）、个人资料（昵称、头像等）、任务相关信息、设备信息、使用日志等。这些信息用于提供和改进服务。"
                )
                
                PrivacySection(
                    title: "2. 信息使用",
                    content: "我们使用收集的信息用于：提供平台服务、处理任务交易、发送通知、改进用户体验、防止欺诈行为、遵守法律法规等。"
                )
                
                PrivacySection(
                    title: "3. 信息共享",
                    content: "我们不会向第三方出售、交易或转让您的个人信息。仅在以下情况下可能共享信息：获得您明确同意、法律法规要求、保护平台和用户权益等。"
                )
                
                PrivacySection(
                    title: "4. 信息安全",
                    content: "我们采用行业标准的安全措施保护您的信息安全，包括数据加密、访问控制、安全审计等。但请注意，互联网传输无法保证100%安全。"
                )
                
                PrivacySection(
                    title: "5. Cookie 使用",
                    content: "我们使用 Cookie 和类似技术来改善用户体验、分析使用情况、提供个性化内容。您可以通过浏览器设置管理 Cookie。"
                )
                
                PrivacySection(
                    title: "6. 您的权利",
                    content: "您有权访问、更正、删除您的个人信息，有权撤回同意、注销账号。您可以通过「设置」页面或联系客服行使这些权利。"
                )
                
                PrivacySection(
                    title: "7. 儿童隐私",
                    content: "我们的服务面向18岁以上用户。如发现未满18岁用户使用服务，我们将采取措施限制或终止服务。"
                )
                
                PrivacySection(
                    title: "8. 政策更新",
                    content: "我们可能会不定期更新隐私政策。重大变更将通过平台通知或邮件告知。继续使用服务即视为接受更新后的政策。"
                )
                
                Text("最后更新：2024年1月1日")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
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

#Preview {
    NavigationView {
        PrivacyView()
    }
}

