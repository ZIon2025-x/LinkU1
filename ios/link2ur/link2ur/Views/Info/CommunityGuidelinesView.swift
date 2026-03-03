import SwiftUI
import Combine

struct CommunityGuidelinesView: View {
    @Environment(\.locale) var locale
    @State private var legalDoc: LegalDocumentOut?
    @State private var legalCancellable: AnyCancellable?

    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }

    private var legalLang: String { isChinese ? "zh" : "en" }

    var body: some View {
        ScrollView {
            if let content = legalDoc?.contentJson, !content.isEmpty {
                LegalDocumentContentView(contentJson: content, documentType: "community_guidelines")
            } else {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // 标题和版本信息
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(isChinese ? "社区准则" : "Community Guidelines")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(isChinese ? "版本：v1.0" : "Version: v1.0")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text(isChinese ? "生效日期：2026年3月" : "Effective Date: March 2026")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)

                // 概述
                GuidelinesSection(
                    title: isChinese ? "概述" : "Overview",
                    content: [
                        isChinese ? "Link²Ur 社区准则旨在为所有用户营造安全、友好、互助的平台环境。本准则适用于平台上所有用户生成内容，包括但不限于：社区论坛帖子与回复、任务描述与评价、跳蚤市场商品信息、用户个人资料、站内消息及所有公开展示的内容。" : "The Link²Ur Community Guidelines aim to create a safe, friendly, and collaborative platform environment for all users. These guidelines apply to all user-generated content on the platform.",
                        isChinese ? "使用 Link²Ur 平台即表示您同意遵守本社区准则。违反准则可能导致内容删除、功能限制或账户封禁。" : "By using the Link²Ur platform, you agree to abide by these Community Guidelines. Violations may result in content removal, feature restrictions, or account suspension."
                    ]
                )

                // 1. 内容标准
                GuidelinesSection(
                    title: isChinese ? "1. 内容标准" : "1. Content Standards",
                    content: [
                        isChinese ? "尊重他人：禁止人身攻击、侮辱、歧视性言论、骚扰、跟踪、威胁或恐吓他人。" : "Respectful Communication: Personal attacks, insults, discriminatory speech, harassment, stalking, threats, or intimidation are prohibited.",
                        isChinese ? "真实可信：禁止虚假、误导或欺诈性信息。任务描述和商品信息须真实、准确、完整。" : "Truthfulness: False, misleading, or fraudulent information is prohibited. Task descriptions and product listings must be true, accurate, and complete.",
                        isChinese ? "合法合规：禁止违法内容、侵犯知识产权或隐私的内容、色情、暴力或极端内容。" : "Legal Compliance: Illegal content, intellectual property or privacy infringement, pornographic, violent, or extreme content is prohibited.",
                        isChinese ? "安全健康：禁止危害用户安全或公共健康的内容。" : "Safety: Content endangering user safety or public health is prohibited."
                    ]
                )

                // 2. 论坛行为规范
                GuidelinesSection(
                    title: isChinese ? "2. 论坛行为规范" : "2. Forum Conduct Rules",
                    content: [
                        isChinese ? "帖子应发布在相应的学校/大学分区，不得跨区灌水。" : "Posts should be published in the appropriate school/university section.",
                        isChinese ? "回复应与帖子主题相关。禁止刷屏、灌水或无意义回复。" : "Replies should be relevant to the post topic. Spamming or meaningless replies are prohibited.",
                        isChinese ? "禁止商业广告、引导站外交易、学术不诚信内容、泄露他人隐私。" : "Commercial ads, off-platform transaction guidance, academic dishonesty content, and privacy violations are prohibited."
                    ]
                )

                // 3. 任务与交易规范
                GuidelinesSection(
                    title: isChinese ? "3. 任务与交易规范" : "3. Task and Transaction Rules",
                    content: [
                        isChinese ? "任务描述应清晰、详细，评价应基于真实体验，禁止虚假好评或恶意差评。" : "Task descriptions should be clear and detailed. Reviews must be based on genuine experiences. Fake or malicious reviews are prohibited.",
                        isChinese ? "商品信息须真实准确，禁止假冒伪劣商品，须在平台内沟通。" : "Product information must be accurate. Counterfeit goods are prohibited. Communication must be on-platform."
                    ]
                )

                // 4. 举报机制
                GuidelinesSection(
                    title: isChinese ? "4. 举报与申诉" : "4. Reporting and Appeals",
                    content: [
                        isChinese ? "点击违规内容旁的「举报」按钮，选择原因并提交。平台通常在 24-72 小时内处理。" : "Click the 'Report' button next to violating content, select a reason and submit. The platform typically processes reports within 24-72 hours.",
                        isChinese ? "举报人身份信息严格保密。禁止对举报人进行报复。" : "Reporter identity is kept strictly confidential. Retaliation against reporters is prohibited.",
                        isChinese ? "对处罚有异议，可在收到通知后 14 天内提出申诉。" : "If you disagree with a penalty, you may appeal within 14 days of notification."
                    ]
                )

                // 5. 违规处理
                GuidelinesSection(
                    title: isChinese ? "5. 违规处理" : "5. Enforcement",
                    content: [
                        isChinese ? "处罚等级：提醒/警告 → 内容删除 → 临时限制（1-30天）→ 账户暂停（7-90天）→ 永久封禁。" : "Penalty levels: Reminder/Warning → Content Removal → Temporary Restriction (1-30 days) → Account Suspension (7-90 days) → Permanent Ban.",
                        isChinese ? "涉及违法犯罪的，平台保留向执法机构报告的权利。" : "For violations involving criminal activity, the platform reserves the right to report to law enforcement."
                    ]
                )

                // 联系我们
                GuidelinesSection(
                    title: isChinese ? "联系我们" : "Contact Us",
                    content: [
                        isChinese ? "如对本社区准则有疑问，请联系：info@link2ur.com" : "For questions about these Community Guidelines, contact: info@link2ur.com"
                    ]
                )
            }
            .padding(.vertical, AppSpacing.md)
            }
        }
        .navigationTitle(isChinese ? "社区准则" : "Community Guidelines")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { loadLegal() }
        .onChange(of: legalLang) { _ in loadLegal() }
    }

    private func loadLegal() {
        legalCancellable = APIService.shared.getLegalDocument(type: "community_guidelines", lang: legalLang)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { legalDoc = $0 }
            )
    }
}

struct GuidelinesSection: View {
    let title: String
    let content: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            ForEach(content, id: \.self) { text in
                Text(text)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
}
