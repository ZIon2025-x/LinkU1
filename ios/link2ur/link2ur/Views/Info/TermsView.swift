import SwiftUI

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("服务条款")
                    .font(AppTypography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                
                TermsSection(
                    title: "1. 服务说明",
                    content: "Link²Ur 是一个任务发布与接取平台，为用户提供任务发布、接取、支付等服务。用户在使用本平台服务时，需遵守相关法律法规和平台规则。"
                )
                
                TermsSection(
                    title: "2. 用户责任",
                    content: "用户应确保发布的任务信息真实、准确，不得发布违法、虚假、欺诈性内容。接取任务的用户应按时、按质完成任务，不得恶意接取任务后不完成。"
                )
                
                TermsSection(
                    title: "3. 支付与退款",
                    content: "任务奖励将在任务完成后发放。如发生争议，平台将根据实际情况进行调解。退款政策按照平台相关规定执行。"
                )
                
                TermsSection(
                    title: "4. 隐私保护",
                    content: "平台严格保护用户隐私，不会未经用户同意向第三方泄露用户信息。详细隐私政策请查看「隐私政策」页面。"
                )
                
                TermsSection(
                    title: "5. 违规处理",
                    content: "如用户违反服务条款，平台有权采取警告、限制功能、封禁账号等措施。严重违规行为将依法追究法律责任。"
                )
                
                TermsSection(
                    title: "6. 免责声明",
                    content: "平台不对用户发布的任务内容承担责任，不对任务完成质量承担责任。用户之间的交易纠纷由双方协商解决，平台提供必要的协助。"
                )
                
                TermsSection(
                    title: "7. 条款修改",
                    content: "平台有权根据需要修改服务条款，修改后的条款将在平台上公布。继续使用平台服务即视为接受修改后的条款。"
                )
                
                Text("最后更新：2024年1月1日")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle("服务条款")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct TermsSection: View {
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
        TermsView()
    }
}

