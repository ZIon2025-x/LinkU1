import SwiftUI

struct FAQView: View {
    @State private var expandedItems: Set<Int> = []
    
    let faqs: [FAQItem] = [
        FAQItem(
            question: "如何发布任务？",
            answer: "登录后，点击首页的「发布任务」按钮，填写任务详情（标题、描述、奖励、截止日期等），然后提交即可。"
        ),
        FAQItem(
            question: "如何接取任务？",
            answer: "在任务大厅浏览任务，找到感兴趣的任务后点击「申请」按钮，等待发布者确认即可。"
        ),
        FAQItem(
            question: "任务完成后如何获得奖励？",
            answer: "任务完成后，发布者会确认完成，奖励会自动发放到您的账户。您可以在「我的钱包」中查看余额。"
        ),
        FAQItem(
            question: "如何成为任务达人？",
            answer: "在「任务达人」页面点击「申请成为达人」，填写相关信息并提交申请，审核通过后即可成为任务达人。"
        ),
        FAQItem(
            question: "如何联系客服？",
            answer: "您可以在「设置」页面找到「客服」选项，或直接发送邮件至 support@link2ur.com。"
        ),
        FAQItem(
            question: "如何获得积分？",
            answer: "完成任务、签到、参与活动等都可以获得积分。积分可以在「积分与优惠券」页面查看和使用。"
        ),
        FAQItem(
            question: "如何验证学生身份？",
            answer: "在「个人中心」找到「学生认证」，按照提示上传学生证照片，审核通过后即可享受学生优惠。"
        ),
        FAQItem(
            question: "如何修改个人信息？",
            answer: "在「个人中心」点击头像或「设置」，可以修改昵称、头像、邮箱等个人信息。"
        )
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                    FAQItemView(
                        faq: faq,
                        isExpanded: expandedItems.contains(index),
                        onToggle: {
                            // 直接更新状态，动画在 FAQItemView 中处理
                            if expandedItems.contains(index) {
                                expandedItems.remove(index)
                            } else {
                                expandedItems.insert(index)
                            }
                        }
                    )
                    .padding(.horizontal, AppSpacing.md)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle("常见问题")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct FAQItem {
    let question: String
    let answer: String
}

struct FAQItemView: View {
    let faq: FAQItem
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                // 使用更快的动画优化点击响应
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggle()
                }
            }) {
                HStack {
                    Text(faq.question)
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(AppSpacing.md)
                .contentShape(Rectangle()) // 确保整个区域可点击
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                    .padding(.horizontal, AppSpacing.md)
                
                Text(faq.answer)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                    .padding(AppSpacing.md)
                    .padding(.top, AppSpacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
    }
}

#Preview {
    NavigationView {
        FAQView()
    }
}

