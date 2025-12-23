import SwiftUI

struct TermsView: View {
    @Environment(\.locale) var locale
    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // 标题和版本信息
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(isChinese ? "用户协议" : "Terms of Service")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(isChinese ? "版本：v0.9-beta" : "Version: v0.9-beta")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(isChinese ? "生效日期：2025年10月10日" : "Effective Date: October 10, 2025")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(isChinese ? "适用法域：英格兰与威尔士" : "Applicable Jurisdiction: England & Wales")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                
                // 主体信息
                InfoBox(
                    title: isChinese ? "主体信息" : "Entity Information",
                    content: [
                        isChinese ? "运营方（\"我们\"\"Link²Ur\"）：Zixiong Zhang，以\"Link²Ur\"名义开展测试（trading as）。" : "Operator (\"We\" \"Link²Ur\"): Zixiong Zhang, trading as \"Link²Ur\".",
                        isChinese ? "联系：info@link2ur.com" : "Contact: info@link2ur.com"
                    ]
                )
                
                // 1. 服务性质
                TermsSection(
                    title: isChinese ? "1. 服务性质" : "1. Nature of Service",
                    content: [
                        isChinese ? "本服务为早期测试版（Beta/MVP），旨在撮合与沟通，不在平台内提供收付款或资金托管。我们可随时变更、暂停或终止访问。" : "This service is an early beta version (Beta/MVP) designed for matching and communication, and does not provide payment or fund custody within the platform. We may change, suspend or terminate access at any time.",
                        isChinese ? "测试阶段声明：当前平台处于测试阶段，功能可能不完善，服务可能不稳定。用户使用本平台即表示理解并接受测试阶段可能存在的风险。" : "Testing Phase Statement: The platform is currently in testing phase, features may be incomplete and services may be unstable. Users using this platform acknowledge and accept the risks that may exist during the testing phase.",
                        isChinese ? "支付限制：目前平台无线上支付渠道，不支持在线支付功能。所有交易均需用户线下自行完成，平台不参与任何资金流转。" : "Payment Limitations: The platform currently has no online payment channels and does not support online payment functions. All transactions must be completed offline by users themselves, and the platform does not participate in any fund flows."
                    ],
                    warnings: [
                        isChinese ? "测试阶段声明：当前平台处于测试阶段，功能可能不完善，服务可能不稳定。用户使用本平台即表示理解并接受测试阶段可能存在的风险。" : "Testing Phase Statement: The platform is currently in testing phase, features may be incomplete and services may be unstable. Users using this platform acknowledge and accept the risks that may exist during the testing phase.",
                        isChinese ? "支付限制：目前平台无线上支付渠道，不支持在线支付功能。所有交易均需用户线下自行完成，平台不参与任何资金流转。" : "Payment Limitations: The platform currently has no online payment channels and does not support online payment functions. All transactions must be completed offline by users themselves, and the platform does not participate in any fund flows."
                    ]
                )
                
                // 2. 用户类型与资格
                TermsSection(
                    title: isChinese ? "2. 用户类型与资格" : "2. User Types and Eligibility",
                    content: [
                        isChinese ? "仅限年满18岁的用户注册与使用。" : "Only users aged 18 and above may register and use the service.",
                        isChinese ? "用户可能为企业用户（B2B）或个人/消费者（B2C）。如属消费者，适用文末《消费者条款附录》。" : "Users may be business users (B2B) or individual/consumer users (B2C). If you are a consumer, the Consumer Terms Appendix at the end applies.",
                        isChinese ? "工作资格要求：用户在接受任务前，必须确保自己拥有合法的工作资格。这包括但不限于：持有有效的工作签证、拥有相关行业所需的许可证或资质证书、符合当地法律法规对从事相关工作的要求。用户有责任自行确认并遵守所有适用的法律法规。平台不对用户的工作资格进行验证，但保留要求用户提供相关证明的权利。" : "Work Eligibility Requirements: Before accepting tasks, users must ensure they have legal work eligibility. This includes but is not limited to: holding a valid work visa, possessing licenses or qualifications required for the relevant industry, and complying with local laws and regulations regarding the performance of related work. Users are responsible for confirming and complying with all applicable laws and regulations. The platform does not verify users' work eligibility, but reserves the right to require users to provide relevant proof."
                    ],
                    warnings: [
                        isChinese ? "工作资格要求：用户在接受任务前，必须确保自己拥有合法的工作资格。这包括但不限于：持有有效的工作签证、拥有相关行业所需的许可证或资质证书、符合当地法律法规对从事相关工作的要求。用户有责任自行确认并遵守所有适用的法律法规。平台不对用户的工作资格进行验证，但保留要求用户提供相关证明的权利。" : "Work Eligibility Requirements: Before accepting tasks, users must ensure they have legal work eligibility. This includes but is not limited to: holding a valid work visa, possessing licenses or qualifications required for the relevant industry, and complying with local laws and regulations regarding the performance of related work. Users are responsible for confirming and complying with all applicable laws and regulations. The platform does not verify users' work eligibility, but reserves the right to require users to provide relevant proof."
                    ]
                )
                
                // 3. 平台定位与站外交易
                TermsSection(
                    title: isChinese ? "3. 平台定位与站外交易" : "3. Platform Position and Off-Platform Transactions",
                    content: [
                        isChinese ? "我们是撮合型在线平台，不是任何任务/项目的雇主、承包商或代理。平台仅提供信息撮合服务，不参与实际交易执行。" : "We are a matching online platform, not an employer, contractor or agent for any tasks/projects. The platform only provides information matching services and does not participate in actual transaction execution.",
                        isChinese ? "站外交易（Off-Platform Transactions）：双方可线下或通过其他渠道自行支付/结算。与站外交易相关的合同、质量、交付、退款、税费与纠纷，均由交易双方自行承担与处理；除非因我们自身过错，我们对站外交易不承担责任或担保。建议双方保留书面约定与凭证并自行进行尽职调查。" : "Off-Platform Transactions: Parties may pay/settle offline or through other channels. We are not responsible for or guarantee off-platform transactions related to contracts, quality, delivery, refunds, taxes and disputes, unless due to our own fault. We recommend parties maintain written agreements and records and conduct their own due diligence.",
                        isChinese ? "雇佣关系声明：平台与用户之间不存在雇佣关系。用户以自雇/个体户形式提供服务，用户对其提供的服务承担全部责任，包括但不限于服务质量、税务申报、保险等。平台不对用户的服务质量、安全或任何损失承担责任。" : "Employment Relationship Statement: There is no employment relationship between the platform and users. Users provide services as self-employed/independent contractors and bear full responsibility for their services, including but not limited to service quality, tax reporting, insurance, etc. The platform is not responsible for users' service quality, safety or any losses.",
                        isChinese ? "线下交易免责：对于用户之间进行的线下交易，平台不承担任何责任。用户应自行评估交易风险，平台不对交易结果、服务质量、资金安全等承担任何责任。" : "Offline Transaction Disclaimer: For offline transactions between users, the platform assumes no responsibility. Users should assess transaction risks themselves, and the platform bears no responsibility for transaction outcomes, service quality, fund safety, etc."
                    ],
                    warnings: [
                        isChinese ? "雇佣关系声明：平台与用户之间不存在雇佣关系。用户以自雇/个体户形式提供服务，用户对其提供的服务承担全部责任，包括但不限于服务质量、税务申报、保险等。平台不对用户的服务质量、安全或任何损失承担责任。" : "Employment Relationship Statement: There is no employment relationship between the platform and users. Users provide services as self-employed/independent contractors and bear full responsibility for their services, including but not limited to service quality, tax reporting, insurance, etc. The platform is not responsible for users' service quality, safety or any losses.",
                        isChinese ? "线下交易免责：对于用户之间进行的线下交易，平台不承担任何责任。用户应自行评估交易风险，平台不对交易结果、服务质量、资金安全等承担任何责任。" : "Offline Transaction Disclaimer: For offline transactions between users, the platform assumes no responsibility. Users should assess transaction risks themselves, and the platform bears no responsibility for transaction outcomes, service quality, fund safety, etc."
                    ]
                )
                
                // 4. 费用与平台规则
                TermsSection(
                    title: isChinese ? "4. 费用与平台规则" : "4. Fees and Platform Rules",
                    content: [
                        isChinese ? "测试阶段我们不向用户收取平台服务费；如未来收费，将在页面显著公示并更新本条款。" : "During the testing phase, we do not charge platform service fees to users; if we charge fees in the future, we will prominently display them on the page and update these terms.",
                        isChinese ? "评价与内容：禁止虚假/有误导性的评价、刷评或组织\"好评任务\"。我们可删除相关内容并限制或终止账号。" : "Reviews and Content: Prohibited are false/misleading reviews, review manipulation or organizing \"positive review tasks\". We may delete related content and restrict or terminate accounts."
                    ]
                )
                
                // 5. 用户行为与禁止事项
                TermsSection(
                    title: isChinese ? "5. 用户行为与禁止事项" : "5. User Behavior and Prohibited Activities",
                    content: [
                        isChinese ? "不得：（1）发布违法、侵权、欺诈、误导或有害内容；（2）发布需持证却无资质的任务；（3）抓取、攻击、绕过访问控制或试图破坏系统；（4）进行洗钱、制裁规避或其他金融犯罪。" : "You may not: (1) publish illegal, infringing, fraudulent, misleading or harmful content; (2) publish tasks requiring licenses without proper qualifications; (3) scrape, attack, bypass access controls or attempt to damage the system; (4) engage in money laundering, sanctions evasion or other financial crimes.",
                        isChinese ? "如违规，我们可删除内容、限制/终止访问，并在必要时向监管或执法机构报告。" : "If violated, we may delete content, restrict/terminate access, and report to regulatory or law enforcement agencies when necessary.",
                        isChinese ? "账户封禁政策：如果平台发现或留意到用户有任何违法、违规行为，包括但不限于违反本协议条款、从事非法活动、欺诈、骚扰其他用户、发布虚假信息等，平台有权利也有义务立即对用户进行封号处理。封号可能包括但不限于：临时暂停账户、永久封禁账户、限制账户功能、删除违规内容等。平台将根据违规行为的严重程度采取相应的措施，并保留向相关监管或执法机构报告的权利。用户被封号后，将无法继续使用平台服务，已发布的任务可能被删除，正在进行中的交易可能被终止。" : "Account Suspension Policy: If the platform discovers or becomes aware of any illegal or violations by users, including but not limited to violations of these terms, engaging in illegal activities, fraud, harassment of other users, publishing false information, etc., the platform has the right and obligation to immediately suspend the user's account. Account suspension may include but is not limited to: temporary account suspension, permanent account ban, restriction of account functions, deletion of violating content, etc. The platform will take appropriate measures based on the severity of the violations and reserves the right to report to relevant regulatory or law enforcement agencies. After a user's account is suspended, they will not be able to continue using the platform services, published tasks may be deleted, and ongoing transactions may be terminated."
                    ],
                    warnings: [
                        isChinese ? "账户封禁政策：如果平台发现或留意到用户有任何违法、违规行为，包括但不限于违反本协议条款、从事非法活动、欺诈、骚扰其他用户、发布虚假信息等，平台有权利也有义务立即对用户进行封号处理。封号可能包括但不限于：临时暂停账户、永久封禁账户、限制账户功能、删除违规内容等。平台将根据违规行为的严重程度采取相应的措施，并保留向相关监管或执法机构报告的权利。用户被封号后，将无法继续使用平台服务，已发布的任务可能被删除，正在进行中的交易可能被终止。" : "Account Suspension Policy: If the platform discovers or becomes aware of any illegal or violations by users, including but not limited to violations of these terms, engaging in illegal activities, fraud, harassment of other users, publishing false information, etc., the platform has the right and obligation to immediately suspend the user's account. Account suspension may include but is not limited to: temporary account suspension, permanent account ban, restriction of account functions, deletion of violating content, etc. The platform will take appropriate measures based on the severity of the violations and reserves the right to report to relevant regulatory or law enforcement agencies. After a user's account is suspended, they will not be able to continue using the platform services, published tasks may be deleted, and ongoing transactions may be terminated."
                    ]
                )
                
                // 6-10. 其他章节
                TermsSection(
                    title: isChinese ? "6. 知识产权与用户内容" : "6. Intellectual Property and User Content",
                    content: [
                        isChinese ? "平台及其内容的所有权利归我们或许可方所有。" : "All rights to the platform and its content belong to us or our licensors.",
                        isChinese ? "您保留上传内容的权利，但为提供、运营与推广服务之目的，您授予我们全球范围、非独占、免版税、可转授权的使用许可（用于展示、备份、审核、索引与推广）。" : "You retain rights to uploaded content, but for the purpose of providing, operating and promoting the service, you grant us a worldwide, non-exclusive, royalty-free, sublicensable license (for display, backup, review, indexing and promotion).",
                        isChinese ? "侵权投诉按我们的通知—删除流程处理（请通过上述邮箱联系我们）。" : "Infringement complaints are handled through our notice-and-takedown process (please contact us via the above email)."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "7. 隐私与数据（UK GDPR）" : "7. Privacy and Data (UK GDPR)",
                    content: [
                        isChinese ? "我们作为**数据控制者（controller）**处理账户、日志与沟通数据，仅在\"提供服务、保障安全、改进体验\"的范围内处理，详见下方《隐私通知（Beta）》；您可行使访问、更正、删除、限制处理、数据可携、反对处理、撤回同意等权利；亦可向 ICO 投诉。" : "We act as a **data controller** processing account, log and communication data, only within the scope of \"providing services, ensuring security, improving experience\", as detailed in the Privacy Notice (Beta) below; you may exercise rights of access, rectification, erasure, restriction of processing, data portability, objection to processing, withdrawal of consent, etc.; you may also complain to the ICO.",
                        isChinese ? "站外支付由相关第三方或交易对方处理；我们不接触完整支付凭证。" : "Off-platform payments are handled by relevant third parties or transaction counterparts; we do not access complete payment credentials."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "8. 免责声明与责任限制" : "8. Disclaimer and Limitation of Liability",
                    content: [
                        isChinese ? "服务按\"现状（as is） / 可用性（as available）\"提供，不保证不间断或无错误。" : "The service is provided \"as is\" / \"as available\" without warranty of uninterrupted or error-free operation.",
                        isChinese ? "我们不对间接、后果性、惩罚性损害或利润/商誉损失承担责任。" : "We are not liable for indirect, consequential, punitive damages or loss of profits/goodwill.",
                        isChinese ? "总责任上限：就任何单一或合并索赔，我们的责任以您在过去12个月向我们实际支付的费用总额或**£100（以较高者为限）**为上限；法律强制责任除外（例如因过失导致的人身伤害或死亡）。" : "Total liability cap: For any single or combined claim, our liability is limited to the total amount you actually paid us in the past 12 months or **£100 (whichever is higher)**; except for legally mandatory liability (such as personal injury or death due to negligence)."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "9. 终止与数据保留" : "9. Termination and Data Retention",
                    content: [
                        isChinese ? "您或我们可随时终止测试访问。为遵守法定义务与正当目的，我们可能在最短必要期限内保留日志及记录（具体见《隐私通知（Beta）》）。" : "You or we may terminate test access at any time. To comply with legal obligations and legitimate purposes, we may retain logs and records for the shortest necessary period (as detailed in the Privacy Notice (Beta)).",
                        isChinese ? "终止不影响既有权利与义务。" : "Termination does not affect existing rights and obligations."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "10. 争议与适用法律" : "10. Disputes and Applicable Law",
                    content: [
                        isChinese ? "双方应先友好协商；协商不成，提交英格兰与威尔士法院专属管辖。" : "Parties should first negotiate amicably; if negotiation fails, submit to the exclusive jurisdiction of courts in England and Wales.",
                        isChinese ? "本条款受英格兰与威尔士法律管辖并据其解释。" : "These terms are governed by and construed in accordance with the laws of England and Wales."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "消费者条款附录（如用户为消费者时适用）" : "Consumer Terms Appendix (Applicable when user is a consumer)",
                    content: [
                        isChinese ? "您作为消费者使用我们的免费撮合服务时，我们会在界面提供关键信息（平台身份、联系方式、主要功能与任何重要限制）。" : "When you use our free matching service as a consumer, we will provide key information on the interface (platform identity, contact information, main functions and any important limitations).",
                        isChinese ? "目前测试期我们不向消费者收费，因此不触发付费数字服务的冷静期/退款机制；一旦未来对消费者收费，我们将遵守相关消费者法规（包括信息披露、取消权与禁止隐藏费用/虚假评论等），并在收费前以显著方式告知。" : "Currently during the testing period we do not charge consumers, so the cooling-off/refund mechanism for paid digital services is not triggered; once we charge consumers in the future, we will comply with relevant consumer regulations (including information disclosure, cancellation rights and prohibition of hidden fees/false reviews, etc.) and notify prominently before charging."
                    ]
                )
                
                // 重要提示
                InfoBox(
                    title: isChinese ? "重要提示" : "Important Notice",
                    content: [
                        isChinese ? "请仔细阅读本协议，特别是免除或限制责任的条款。如果您不同意本协议的任何条款，请停止使用本平台服务。" : "Please read these terms carefully, especially the terms that exclude or limit liability. If you do not agree to any terms, please stop using the platform service."
                    ],
                    isWarning: true
                )
                
                Text(isChinese ? "最后更新：2025年10月10日" : "Last Updated: October 10, 2025")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle(isChinese ? "服务条款" : "Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct TermsSection: View {
    let title: String
    let content: [String]
    var warnings: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            ForEach(content, id: \.self) { paragraph in
                Text(paragraph)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }
            
            ForEach(warnings, id: \.self) { warning in
                Text(warning)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.error)
                    .fontWeight(.semibold)
                    .padding(AppSpacing.sm)
                    .background(AppColors.error.opacity(0.1))
                    .cornerRadius(AppCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

struct InfoBox: View {
    let title: String
    let content: [String]
    var isWarning: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            ForEach(content, id: \.self) { paragraph in
                Text(paragraph)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }
        }
        .padding(AppSpacing.md)
        .background(isWarning ? AppColors.warning.opacity(0.1) : AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .stroke(isWarning ? AppColors.warning.opacity(0.3) : AppColors.separator, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.md)
    }
}

#Preview {
    NavigationView {
        TermsView()
    }
}
