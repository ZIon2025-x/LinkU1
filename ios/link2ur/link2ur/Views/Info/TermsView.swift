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
                    
                    Text(isChinese ? "版本：v1.0" : "Version: v1.0")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(isChinese ? "生效日期：2026年1月" : "Effective Date: January 2026")
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
                        isChinese ? "运营方（\"我们\"\"Link²Ur\"）：LINK2UR LTD" : "Operator (\"We\" \"Link²Ur\"): LINK2UR LTD",
                        isChinese ? "联系：info@link2ur.com" : "Contact: info@link2ur.com"
                    ]
                )
                
                // 1. 服务性质
                TermsSection(
                    title: isChinese ? "1. 服务性质" : "1. Nature of Service",
                    content: [
                        isChinese ? "Link²Ur 是面向英国用户的本地服务平台，包括：（1）任务市场——连接任务发布者与任务接受者；（2）跳蚤市场——二手物品买卖；（3）社区论坛——按大学分类的讨论区；（4）VIP 会员——可选自动续期订阅（通过 Apple App Store 等渠道的应用内购买）。我们提供撮合与发布服务，并通过 Stripe（包括银行卡、Apple Pay、微信支付等）处理平台内支付。我们可随时变更、暂停或终止访问。" : "Link²Ur is a local service platform for users in the UK, comprising: (1) Task Marketplace — connecting task posters with task takers; (2) Flea Market — for buying and selling secondhand items; (3) Community Forum — for discussions by university; (4) VIP Membership — optional auto-renewable subscription (in-app purchase via Apple App Store or other supported channels). We provide matching and listing services and process in-platform payments through Stripe (including card, Apple Pay and WeChat Pay where available). We may change, suspend or terminate access at any time.",
                        isChinese ? "测试阶段声明：当前平台处于测试阶段，功能可能不完善，服务可能不稳定。用户使用本平台即表示理解并接受测试阶段可能存在的风险。" : "Testing Phase Statement: The platform is currently in testing phase, features may be incomplete and services may be unstable. Users using this platform acknowledge and accept the risks that may exist during the testing phase.",
                        isChinese ? "支付系统：平台使用 Stripe 支付系统处理在线支付（包括银行卡、Apple Pay、微信支付等）。所有支付均通过 Stripe 等安全处理，平台作为托管方，在任务/交易完成后将资金转给接受者。VIP 订阅通过 Apple App Store 购买，适用 Apple 的条款与隐私政策。" : "Payment System: The platform uses the Stripe payment system to process online payments (including card, Apple Pay, WeChat Pay). All payments are securely processed; the platform acts as an escrow service. VIP subscriptions are purchased via the Apple App Store and are subject to Apple's terms and privacy policy."
                    ],
                    warnings: [
                        isChinese ? "测试阶段声明：当前平台处于测试阶段，功能可能不完善，服务可能不稳定。用户使用本平台即表示理解并接受测试阶段可能存在的风险。" : "Testing Phase Statement: The platform is currently in testing phase, features may be incomplete and services may be unstable. Users using this platform acknowledge and accept the risks that may exist during the testing phase."
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
                
                // 3. 平台定位与禁止站外/线下交易
                TermsSection(
                    title: isChinese ? "3. 平台定位与禁止站外/线下交易" : "3. Platform Position and Prohibition of Off-Platform / Offline Transactions",
                    content: [
                        isChinese ? "我们是撮合型在线平台，不是任何任务/项目的雇主、承包商或代理。平台提供信息撮合服务和平台内支付处理服务。" : "We are a matching online platform, not an employer, contractor or agent for any tasks/projects. The platform provides information matching services and in-platform payment processing services.",
                        isChinese ? "禁止站外交易与线下自行协商：平台禁止用户进行站外交易及线下自行协商。站外交易与线下自行协商容易产生纠纷、存在资金与履约风险，且平台无法提供担保与争议处理。用户不得引导或促成在平台外支付、线下交易或绕过平台争议解决。违规可能导致内容删除、限制功能或封号。若用户仍进行站外或线下交易，由此产生的合同、质量、交付、退款、税费与纠纷均由交易双方自行承担与处理，平台不承担责任或担保。" : "Prohibition of off-platform and offline transactions: The platform prohibits users from conducting off-platform transactions and offline self-negotiation. Off-platform and offline transactions easily lead to disputes and carry fund and performance risks; the platform cannot provide guarantees or dispute resolution. Users must not induce or facilitate payment outside the platform, offline transactions, or bypassing platform dispute resolution. Violations may result in content removal, restricted features or account suspension. If users nevertheless conduct off-platform or offline transactions, any contract, quality, delivery, refund, tax or dispute arising therefrom is solely between the parties; the platform assumes no responsibility or guarantee.",
                        isChinese ? "雇佣关系声明：平台与用户之间不存在雇佣关系。用户以自雇/个体户形式提供服务，用户对其提供的服务承担全部责任，包括但不限于服务质量、税务申报、保险等。平台不对用户的服务质量、安全或任何损失承担责任。" : "Employment Relationship Statement: There is no employment relationship between the platform and users. Users provide services as self-employed/independent contractors and bear full responsibility for their services, including but not limited to service quality, tax reporting, insurance, etc. The platform is not responsible for users' service quality, safety or any losses.",
                        isChinese ? "各业务适用范围（请务必知悉）：任务市场——须通过本平台完成支付与争议处理；禁止站外交易与线下自行协商。跳蚤市场——平台仅提供信息发布与撮合；禁止站外交易与线下自行协商，用户须在平台内沟通，不得引导对方线下付款或私下交易。社区论坛——按大学/学校分类的讨论区，用户对发帖内容负责；平台不参与用户间纠纷调解（法律要求除外）。VIP 会员——可选自动续期订阅，通过 Apple App Store 等渠道购买，适用各渠道的条款与退款政策。" : "Scope of services (please note): Task Marketplace — payment and dispute resolution must be completed through the platform; off-platform and offline transactions are prohibited. Flea Market — the platform only provides listing and matching; off-platform and offline transactions are prohibited; users must communicate on the platform and must not induce the other party to pay offline or transact privately. Community Forum — discussion by university/school; users are responsible for posts; the platform does not mediate between users (unless required by law). VIP Membership — optional auto-renewable subscription via Apple App Store etc.; each channel’s terms and refund policy apply."
                    ],
                    warnings: [
                        isChinese ? "雇佣关系声明：平台与用户之间不存在雇佣关系。用户以自雇/个体户形式提供服务，用户对其提供的服务承担全部责任，包括但不限于服务质量、税务申报、保险等。平台不对用户的服务质量、安全或任何损失承担责任。" : "Employment Relationship Statement: There is no employment relationship between the platform and users. Users provide services as self-employed/independent contractors and bear full responsibility for their services, including but not limited to service quality, tax reporting, insurance, etc. The platform is not responsible for users' service quality, safety or any losses."
                    ]
                )
                
                // 4. 费用与平台规则
                TermsSection(
                    title: isChinese ? "4. 费用与平台规则" : "4. Fees and Platform Rules",
                    content: [
                        isChinese ? "平台服务费：平台会从每笔任务支付中收取一定比例的服务费（具体费率以平台公示为准）。服务费在支付时自动扣除，剩余金额将作为托管金额，在任务完成后转给任务接受者。" : "Platform Service Fee: The platform charges a percentage service fee from each task payment (specific rates are displayed on the platform). The service fee is automatically deducted at payment, and the remaining amount is held in escrow and transferred to the task taker upon task completion.",
                        isChinese ? "服务费计算规则：微型任务（任务金额 < 10镑）固定收取 1 镑作为微型任务服务费；普通任务（任务金额 ≥ 10镑）按任务金额的 10% 收取服务费。服务费包括但不限于：支付转账手续费、平台运营成本、人力成本、风险保障金以及其他平台运营所需的合理费用。具体费率以平台公示为准。" : "Service Fee Calculation Rules: Micro tasks (task amount < £10) charge a fixed fee of £1 as the micro task service fee; regular tasks (task amount ≥ £10) charge 10% of the task amount as the service fee. The service fee includes but is not limited to: payment transfer fees, platform operating costs, human resource costs, risk guarantee funds, and other reasonable costs required for platform operations. Specific rates are displayed on the platform.",
                        isChinese ? "支付处理：所有支付通过 Stripe 支付系统处理。平台作为托管方，在任务发布者支付后，资金将托管在平台账户中，待任务完成后转给任务接受者。" : "Payment Processing: All payments are processed through the Stripe payment system. The platform acts as an escrow service, holding funds in the platform account after the task poster pays, and transferring them to the task taker upon task completion.",
                        isChinese ? "评价与内容：禁止虚假/有误导性的评价、刷评或组织\"好评任务\"。我们可删除相关内容并限制或终止账号。" : "Reviews and Content: Prohibited are false/misleading reviews, review manipulation or organizing \"positive review tasks\". We may delete related content and restrict or terminate accounts."
                    ]
                )
                
                // 5. 支付与退款
                TermsSection(
                    title: isChinese ? "5. 支付与退款" : "5. Payment and Refund",
                    content: [
                        isChinese ? "支付方式：平台支持通过 Stripe 支付系统进行在线支付，包括信用卡、借记卡等多种支付方式。" : "Payment Methods: The platform supports online payments through the Stripe payment system, including credit cards, debit cards and other payment methods.",
                        isChinese ? "支付流程：任务发布者在接受申请后，需要通过 Stripe 支付系统完成支付。支付成功后，资金将托管在平台账户中。" : "Payment Process: After accepting an application, task posters need to complete payment through the Stripe payment system. Once payment is successful, funds will be held in the platform account.",
                        isChinese ? "资金托管：平台提供资金托管服务，确保任务发布者的资金安全。资金将在任务完成后转给任务接受者。" : "Escrow Service: The platform provides escrow services to ensure the security of task poster funds. Funds will be transferred to the task taker upon task completion.",
                        isChinese ? "担保支付（资金托管）说明：平台对通过本平台完成的任务支付提供担保交易（资金托管）服务：任务发布者支付的款项在任务完成或争议解决前由平台代为保管，不直接支付给任务接受者，以降低交易风险。" : "Guaranteed Payment (Escrow): The platform provides guaranteed payment (escrow) for task payments completed through the platform: funds paid by the task poster are held by the platform until the task is completed or a dispute is resolved, and are not paid directly to the task taker, so as to reduce transaction risk.",
                        isChinese ? "平台担保的范围：资金安全保管（支付成功后至释放前，资金由平台在合规支付渠道下托管）；按规则释放（仅在任务发布者确认任务完成或平台根据争议处理规则作出裁决后释放或退还）；支付信息安全（通过 Stripe 等符合 PCI DSS 标准的支付处理方处理，平台不存储完整支付凭证）。" : "What the platform guarantees: Secure holding of funds until release; release only upon task confirmation or platform dispute decision; payment data security via PCI DSS-compliant processors; the platform does not store full payment credentials.",
                        isChinese ? "平台不担保的范围：任务质量、交付结果或服务效果；站外交易（凡在平台外完成的支付、线下支付或通过其他渠道结算的交易，平台不提供担保也不承担责任）；不可抗力或第三方原因导致的支付/到账延迟（在合理范围内配合处理，但不承担超出本协议责任上限的赔偿责任）。" : "What the platform does not guarantee: Task quality, delivery or outcome; off-platform transactions (no guarantee or responsibility); delays in payment or receipt due to force majeure or third-party causes (assist where reasonable but not liable beyond the liability cap).",
                        isChinese ? "资金释放条件：正常完成时，任务发布者在平台内确认完成后，托管资金（扣除平台服务费后）转给任务接受者；退款/部分退款时，在确认完成前可申请退款，争议经平台调解或裁决后按裁决结果执行；争议裁决后，平台作出的争议处理决定在平台内为最终执行依据，双方应配合执行资金释放或退回。" : "When funds are released: On normal completion, funds are transferred to the task taker after confirmation; before confirmation, refund or partial refund per platform mediation/decision; after a dispute decision, the platform’s decision is final for platform purposes and both parties must comply.",
                        isChinese ? "任务确认完成步骤：任务完成后，任务发布者需要确认任务完成。确认完成后，资金将从托管账户转给任务接受者。确认完成是一个重要的时间节点，将影响退款政策的适用。" : "Task Completion Confirmation: After a task is completed, the task poster needs to confirm task completion. Once confirmed, funds will be transferred from the escrow account to the task taker. The completion confirmation is an important milestone that affects the applicability of the refund policy.",
                        isChinese ? "确认完成前的退款政策：在任务发布者确认任务完成之前，任务发布者可以申请退款。退款申请需要提供双边证据。平台将在收到申请后 3-5 个工作日内进行审核。如果双方无法达成一致，平台将根据任务完成情况、沟通记录、证据材料等因素进行裁决。" : "Refund Policy Before Completion Confirmation: Before the task poster confirms task completion, the task poster may apply for a refund with evidence from both parties. The platform will review within 3-5 business days. If both parties cannot reach an agreement, the platform will decide based on task completion status, communication records, evidence, etc.",
                        isChinese ? "确认完成后的申诉政策：任务发布者确认任务完成后，原则上不再接受退款申请。如认为存在严重问题（如任务接受者存在欺诈、违约等），可向平台提出申诉并提供充分证据。平台将根据申诉内容和证据进行审核，但不保证能够追回款项。" : "Appeal Policy After Completion Confirmation: After the task poster confirms task completion, refund applications will generally not be accepted. If the task poster believes there are serious issues (e.g. fraud or breach by the task taker), they may file an appeal with sufficient evidence. The platform will review but does not guarantee recovery of funds.",
                        isChinese ? "争议处理：如双方对退款有争议，平台将首先尝试促成双方协商解决；协商不成的，平台将根据任务完成情况、沟通记录、证据材料、平台规则和公平原则进行裁决；平台裁决为最终决定，双方应遵守；对平台裁决有异议的，可通过法律途径解决。" : "Dispute Resolution: If there is a dispute regarding refunds, the platform will first attempt to facilitate mutual negotiation; if negotiation fails, the platform will decide based on completion status, communication, evidence, platform rules and fairness; the platform decision is final and both parties must comply; objections may be pursued through legal channels.",
                        isChinese ? "拒付处理：如发生信用卡拒付（chargeback），平台将配合支付处理方（Stripe）进行调查、提供相关交易及沟通记录等证据；根据调查结果采取相应措施；若拒付被判定为恶意拒付，平台保留追究法律责任的权利。" : "Chargeback Handling: If a chargeback occurs, the platform will cooperate with Stripe to investigate and provide evidence; take measures based on results; if the chargeback is determined to be malicious, the platform reserves the right to pursue legal action.",
                        isChinese ? "退款处理：退款将通过原支付方式退回（扣除已产生的平台服务费），处理时间通常为 5-10 个工作日。支付安全：平台使用 Stripe 支付系统，符合 PCI DSS 安全标准，不存储您的完整支付凭证。" : "Refund Processing: Refunds will be made via the original payment method (minus platform fees), typically within 5-10 business days. Payment Security: The platform uses Stripe, complies with PCI DSS, and does not store your complete payment credentials."
                    ],
                    warnings: [
                        isChinese ? "重要提示：任务确认完成是一个不可逆的步骤。一旦确认完成，资金将转给任务接受者，退款将变得非常困难。请在确认完成前仔细检查任务完成情况，确保任务符合您的要求。" : "Important Notice: Task completion confirmation is an irreversible step. Once confirmed, funds will be transferred to the task taker, and refunds will become very difficult. Please carefully check task completion before confirming to ensure the task meets your requirements."
                    ]
                )
                
                // 6. 用户行为与禁止事项
                TermsSection(
                    title: isChinese ? "6. 用户行为与禁止事项" : "6. User Behavior and Prohibited Activities",
                    content: [
                        isChinese ? "不得：（1）发布违法、侵权、欺诈、误导或有害内容；（2）发布需持证却无资质的任务；（3）抓取、攻击、绕过访问控制或试图破坏系统；（4）进行洗钱、制裁规避或其他金融犯罪；（5）引导或促成站外交易、线下自行协商、在平台外支付或绕过平台争议解决。" : "You may not: (1) publish illegal, infringing, fraudulent, misleading or harmful content; (2) publish tasks requiring licenses without proper qualifications; (3) scrape, attack, bypass access controls or attempt to damage the system; (4) engage in money laundering, sanctions evasion or other financial crimes; (5) induce or facilitate off-platform transactions, offline self-negotiation, payment outside the platform or bypassing platform dispute resolution.",
                        isChinese ? "如违规，我们可删除内容、限制/终止访问，并在必要时向监管或执法机构报告。" : "If violated, we may delete content, restrict/terminate access, and report to regulatory or law enforcement agencies when necessary.",
                        isChinese ? "账户封禁政策：如果平台发现或留意到用户有任何违法、违规行为，包括但不限于违反本协议条款、从事非法活动、欺诈、骚扰其他用户、发布虚假信息等，平台有权利也有义务立即对用户进行封号处理。封号可能包括但不限于：临时暂停账户、永久封禁账户、限制账户功能、删除违规内容等。平台将根据违规行为的严重程度采取相应的措施，并保留向相关监管或执法机构报告的权利。用户被封号后，将无法继续使用平台服务，已发布的任务可能被删除，正在进行中的交易可能被终止。" : "Account Suspension Policy: If the platform discovers or becomes aware of any illegal or violations by users, including but not limited to violations of these terms, engaging in illegal activities, fraud, harassment of other users, publishing false information, etc., the platform has the right and obligation to immediately suspend the user's account. Account suspension may include but is not limited to: temporary account suspension, permanent account ban, restriction of account functions, deletion of violating content, etc. The platform will take appropriate measures based on the severity of the violations and reserves the right to report to relevant regulatory or law enforcement agencies. After a user's account is suspended, they will not be able to continue using the platform services, published tasks may be deleted, and ongoing transactions may be terminated."
                    ],
                    warnings: [
                        isChinese ? "账户封禁政策：如果平台发现或留意到用户有任何违法、违规行为，包括但不限于违反本协议条款、从事非法活动、欺诈、骚扰其他用户、发布虚假信息等，平台有权利也有义务立即对用户进行封号处理。封号可能包括但不限于：临时暂停账户、永久封禁账户、限制账户功能、删除违规内容等。平台将根据违规行为的严重程度采取相应的措施，并保留向相关监管或执法机构报告的权利。用户被封号后，将无法继续使用平台服务，已发布的任务可能被删除，正在进行中的交易可能被终止。" : "Account Suspension Policy: If the platform discovers or becomes aware of any illegal or violations by users, including but not limited to violations of these terms, engaging in illegal activities, fraud, harassment of other users, publishing false information, etc., the platform has the right and obligation to immediately suspend the user's account. Account suspension may include but is not limited to: temporary account suspension, permanent account ban, restriction of account functions, deletion of violating content, etc. The platform will take appropriate measures based on the severity of the violations and reserves the right to report to relevant regulatory or law enforcement agencies. After a user's account is suspended, they will not be able to continue using the platform services, published tasks may be deleted, and ongoing transactions may be terminated."
                    ]
                )
                
                // 7-11. 其他章节
                TermsSection(
                    title: isChinese ? "7. 知识产权与用户内容" : "7. Intellectual Property and User Content",
                    content: [
                        isChinese ? "平台及其内容的所有权利归我们或许可方所有。" : "All rights to the platform and its content belong to us or our licensors.",
                        isChinese ? "您保留上传内容的权利，但为提供、运营与推广服务之目的，您授予我们全球范围、非独占、免版税、可转授权的使用许可（用于展示、备份、审核、索引与推广）。" : "You retain rights to uploaded content, but for the purpose of providing, operating and promoting the service, you grant us a worldwide, non-exclusive, royalty-free, sublicensable license (for display, backup, review, indexing and promotion).",
                        isChinese ? "侵权投诉按我们的通知—删除流程处理（请通过上述邮箱联系我们）。" : "Infringement complaints are handled through our notice-and-takedown process (please contact us via the above email)."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "8. 隐私与数据（UK GDPR）" : "8. Privacy and Data (UK GDPR)",
                    content: [
                        isChinese ? "我们作为**数据控制者（controller）**处理账户、日志与沟通数据，仅在\"提供服务、保障安全、改进体验\"的范围内处理，详见下方《隐私通知（Beta）》；您可行使访问、更正、删除、限制处理、数据可携、反对处理、撤回同意等权利；亦可向 ICO 投诉。" : "We act as a **data controller** processing account, log and communication data, only within the scope of \"providing services, ensuring security, improving experience\", as detailed in the Privacy Notice (Beta) below; you may exercise rights of access, rectification, erasure, restriction of processing, data portability, objection to processing, withdrawal of consent, etc.; you may also complain to the ICO.",
                        isChinese ? "支付处理：平台使用 Stripe 支付系统处理支付。Stripe 作为支付处理方，会收集和处理必要的支付信息。我们仅接收支付状态和必要的对账信息，不接触完整的支付凭证（如完整信用卡号）。所有支付数据的安全由 Stripe 负责，符合 PCI DSS 标准。" : "Payment Processing: The platform uses the Stripe payment system to process payments. Stripe, as the payment processor, collects and processes necessary payment information. We only receive payment status and necessary reconciliation information, and do not access complete payment credentials (such as full credit card numbers). All payment data security is handled by Stripe in compliance with PCI DSS standards."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "9. 免责声明与责任限制" : "9. Disclaimer and Limitation of Liability",
                    content: [
                        isChinese ? "服务按\"现状（as is） / 可用性（as available）\"提供，不保证不间断或无错误。" : "The service is provided \"as is\" / \"as available\" without warranty of uninterrupted or error-free operation.",
                        isChinese ? "我们不对间接、后果性、惩罚性损害或利润/商誉损失承担责任。" : "We are not liable for indirect, consequential, punitive damages or loss of profits/goodwill.",
                        isChinese ? "总责任上限：就任何单一或合并索赔，我们的责任以您在过去12个月向我们实际支付的费用总额或**£100（以较高者为限）**为上限；法律强制责任除外（例如因过失导致的人身伤害或死亡）。" : "Total liability cap: For any single or combined claim, our liability is limited to the total amount you actually paid us in the past 12 months or **£100 (whichever is higher)**; except for legally mandatory liability (such as personal injury or death due to negligence)."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "10. 终止与数据保留" : "10. Termination and Data Retention",
                    content: [
                        isChinese ? "您或我们可随时终止测试访问。为遵守法定义务与正当目的，我们可能在最短必要期限内保留日志及记录（具体见《隐私通知（Beta）》）。" : "You or we may terminate test access at any time. To comply with legal obligations and legitimate purposes, we may retain logs and records for the shortest necessary period (as detailed in the Privacy Notice (Beta)).",
                        isChinese ? "终止不影响既有权利与义务。" : "Termination does not affect existing rights and obligations."
                    ]
                )
                
                // 11. 论坛服务条款
                TermsSection(
                    title: isChinese ? "11. 论坛服务条款" : "11. Forum Service Terms",
                    content: [
                        isChinese ? "论坛服务说明：平台提供社区论坛功能，允许用户发布帖子、回复、点赞、收藏等互动。论坛旨在促进用户之间的信息交流与经验分享。" : "Forum Service Description: The platform provides community forum functionality, allowing users to post, reply, like, and favorite content. The forum aims to facilitate information exchange and experience sharing among users.",
                        isChinese ? "内容责任：用户对其在论坛中发布的所有内容（包括但不限于文字、图片、链接）承担全部责任。用户必须确保其发布的内容：（1）不违反任何适用的法律法规；（2）不侵犯他人的知识产权、隐私权或其他合法权益；（3）不包含诽谤、骚扰、威胁、仇恨言论或歧视性内容；（4）不包含虚假、误导性信息；（5）不包含垃圾信息、广告或未经授权的商业推广。" : "Content Responsibility: Users are fully responsible for all content they post in the forum (including but not limited to text, images, links). Users must ensure their posted content: (1) does not violate any applicable laws and regulations; (2) does not infringe others' intellectual property, privacy rights, or other legitimate rights; (3) does not contain defamation, harassment, threats, hate speech, or discriminatory content; (4) does not contain false or misleading information; (5) does not contain spam, advertisements, or unauthorized commercial promotion.",
                        isChinese ? "内容审核与删除：我们保留审核、编辑、删除或拒绝发布任何论坛内容的权利，无需事先通知。我们可能因以下原因删除内容：（1）违反本协议或平台规则；（2）违反法律法规；（3）收到有效的侵权投诉；（4）内容不当、有害或不符合社区标准；（5）其他我们认为必要的情况。" : "Content Moderation and Deletion: We reserve the right to review, edit, delete, or refuse to publish any forum content without prior notice. We may delete content for the following reasons: (1) violation of these terms or platform rules; (2) violation of laws and regulations; (3) receipt of valid infringement complaints; (4) inappropriate, harmful content or content that does not meet community standards; (5) other circumstances we deem necessary.",
                        isChinese ? "用户行为规范：在论坛中，用户不得：（1）发布重复或无关内容（刷屏）；（2）恶意攻击、辱骂或骚扰其他用户；（3）冒充他人身份或发布虚假信息；（4）发布可能危害他人安全的内容；（5）利用论坛进行非法活动或传播恶意软件；（6）干扰论坛的正常运营或破坏系统安全。" : "User Conduct Standards: In the forum, users must not: (1) post duplicate or irrelevant content (spamming); (2) maliciously attack, insult, or harass other users; (3) impersonate others or post false information; (4) post content that may endanger others' safety; (5) use the forum for illegal activities or spread malware; (6) interfere with normal forum operations or compromise system security.",
                        isChinese ? "知识产权：用户在论坛中发布的内容，其知识产权归用户所有。但用户授予平台全球范围内、非独占、免版税、可转授权的许可，允许平台使用、展示、存储、修改、分发这些内容，用于提供、运营、推广和改进论坛服务。" : "Intellectual Property: Content posted by users in the forum remains the intellectual property of the users. However, users grant the platform a worldwide, non-exclusive, royalty-free, sublicensable license to use, display, store, modify, and distribute such content for the purpose of providing, operating, promoting, and improving forum services.",
                        isChinese ? "举报机制：如发现论坛中存在违规内容或不当行为，用户可通过平台提供的举报功能进行举报。我们将及时处理举报，并根据情况采取相应措施。" : "Reporting Mechanism: If users discover violating content or inappropriate behavior in the forum, they may report it through the platform's reporting function. We will promptly handle reports and take appropriate measures as necessary.",
                        isChinese ? "论坛免责：平台不对论坛中的用户生成内容承担责任。用户之间的争议应由相关用户自行解决，平台不参与调解，除非法律要求。平台不对因使用或无法使用论坛服务而造成的任何直接、间接、偶然或后果性损失承担责任。" : "Forum Disclaimer: The platform does not assume responsibility for user-generated content in the forum. Disputes between users should be resolved by the relevant users themselves; the platform does not participate in mediation unless required by law. The platform is not liable for any direct, indirect, incidental, or consequential losses arising from the use or inability to use forum services."
                    ],
                    warnings: [
                        isChinese ? "重要提示：用户在论坛中发布的内容可能被其他用户查看、引用或分享。请谨慎发布包含个人隐私信息的内容。平台不对因用户自行公开个人信息而造成的任何后果承担责任。" : "Important Notice: Content posted by users in the forum may be viewed, quoted, or shared by other users. Please exercise caution when posting content containing personal privacy information. The platform does not assume responsibility for any consequences arising from users' voluntary disclosure of personal information."
                    ]
                )
                
                // 12. 跳蚤市场服务条款
                TermsSection(
                    title: isChinese ? "12. 跳蚤市场服务条款" : "12. Flea Market Service Terms",
                    content: [
                        isChinese ? "跳蚤市场服务说明：平台提供跳蚤市场功能，允许用户发布、浏览、购买和出售二手商品。跳蚤市场旨在促进用户之间的二手商品交易。" : "Flea Market Service Description: The platform provides flea market functionality, allowing users to post, browse, purchase, and sell second-hand items. The flea market aims to facilitate second-hand goods transactions among users.",
                        isChinese ? "平台定位：平台仅提供信息发布和撮合服务，不参与实际交易过程。禁止站外交易与线下自行协商；用户须在平台内沟通，不得引导对方线下付款或私下交易。平台不提供支付、物流或资金托管服务；若用户仍进行站外/线下交易，平台不对交易结果、商品质量、资金安全承担责任。" : "Platform Position: The platform only provides information publishing and matching services and does not participate in actual transaction processes. Off-platform and offline transactions are prohibited; users must communicate on the platform and must not induce the other party to pay offline or transact privately. The platform does not provide payment, logistics or escrow; if users nevertheless conduct off-platform/offline transactions, the platform is not responsible for transaction outcomes, product quality or fund safety.",
                        isChinese ? "商品信息责任：卖家必须确保其发布的商品信息真实、准确、完整，包括但不限于商品描述、价格、状态、图片等。卖家不得发布虚假、误导性信息或隐瞒商品的重要缺陷。如商品信息不实，卖家应承担相应责任。" : "Product Information Responsibility: Sellers must ensure that the product information they publish is true, accurate, and complete, including but not limited to product descriptions, prices, conditions, images, etc. Sellers must not publish false, misleading information or conceal important defects of products. If product information is inaccurate, sellers shall bear corresponding responsibility.",
                        isChinese ? "禁止交易的商品：用户不得在跳蚤市场中发布或交易以下商品：（1）法律法规禁止交易的商品（如武器、毒品、受保护动植物等）；（2）假冒伪劣商品；（3）侵犯他人知识产权的商品；（4）危险品、易燃易爆品；（5）活体动物（除非符合相关法规）；（6）其他违反法律法规或平台规则的商品。" : "Prohibited Items: Users must not publish or trade the following items in the flea market: (1) items prohibited by laws and regulations (such as weapons, drugs, protected animals and plants, etc.); (2) counterfeit or substandard goods; (3) items that infringe others' intellectual property; (4) dangerous goods, flammable or explosive items; (5) live animals (unless in compliance with relevant regulations); (6) other items that violate laws, regulations, or platform rules.",
                        isChinese ? "交易风险提示：所有交易均由买卖双方自行完成，平台不对以下事项承担责任：（1）商品质量、真伪、完整性或适用性；（2）交易双方的履约能力或信用状况；（3）交易过程中的资金安全；（4）商品交付、物流或运输过程中的损失；（5）因交易产生的任何纠纷、损失或损害；（6）因商品缺陷、不符合描述或交易纠纷导致的退货、退款或赔偿。" : "Transaction Risk Notice: All transactions are completed by buyers and sellers themselves; the platform does not assume responsibility for: (1) product quality, authenticity, completeness, or suitability; (2) the performance capability or credit status of transaction parties; (3) fund safety during transactions; (4) losses during product delivery, logistics, or transportation; (5) any disputes, losses, or damages arising from transactions; (6) returns, refunds, or compensation due to product defects, non-conformity with descriptions, or transaction disputes.",
                        isChinese ? "交易建议：为降低交易风险，我们强烈建议买卖双方：（1）在交易前充分沟通，确认商品信息和交易条件；（2）尽可能进行面对面交易，当面验货；（3）保留交易记录、聊天记录、支付凭证等相关证据；（4）对高价值商品，建议使用安全的支付方式或第三方担保；（5）遵守相关法律法规，如消费者权益保护法、合同法等。" : "Transaction Recommendations: To reduce transaction risks, we strongly recommend that buyers and sellers: (1) fully communicate before transactions to confirm product information and transaction conditions; (2) conduct face-to-face transactions when possible and inspect goods in person; (3) retain transaction records, chat records, payment receipts, and other relevant evidence; (4) for high-value items, consider using secure payment methods or third-party guarantees; (5) comply with relevant laws and regulations, such as consumer protection laws, contract laws, etc.",
                        isChinese ? "价格与议价：卖家有权设定商品价格，买家可以通过平台功能提出议价。最终交易价格由买卖双方协商确定，平台不参与定价或议价过程。" : "Pricing and Negotiation: Sellers have the right to set product prices, and buyers may propose negotiations through platform functions. Final transaction prices are determined through negotiation between buyers and sellers; the platform does not participate in pricing or negotiation processes.",
                        isChinese ? "交易完成与评价：交易完成后，买卖双方可以对交易进行评价。评价应真实、客观，不得包含虚假、误导性信息或恶意评价。平台保留删除不当评价的权利。" : "Transaction Completion and Reviews: After transaction completion, both buyers and sellers may review the transaction. Reviews should be truthful and objective and must not contain false, misleading information or malicious reviews. The platform reserves the right to delete inappropriate reviews.",
                        isChinese ? "税务责任：买卖双方应自行承担交易相关的税务责任，包括但不限于增值税、所得税等。平台不提供税务建议，也不对用户的税务申报承担责任。如交易涉及税务问题，用户应咨询专业税务顾问。" : "Tax Responsibility: Buyers and sellers shall bear tax responsibilities related to transactions themselves, including but not limited to VAT, income tax, etc. The platform does not provide tax advice and does not assume responsibility for users' tax reporting. If transactions involve tax issues, users should consult professional tax advisors.",
                        isChinese ? "跳蚤市场免责：平台不对跳蚤市场中的任何交易承担责任。因交易产生的任何纠纷、损失或损害，应由交易双方自行解决。平台不对因使用或无法使用跳蚤市场服务而造成的任何直接、间接、偶然或后果性损失承担责任。平台不对商品质量、真伪、安全性或适用性提供任何保证或担保。" : "Flea Market Disclaimer: The platform does not assume responsibility for any transactions in the flea market. Any disputes, losses, or damages arising from transactions shall be resolved by the transaction parties themselves. The platform is not liable for any direct, indirect, incidental, or consequential losses arising from the use or inability to use flea market services. The platform does not provide any warranties or guarantees regarding product quality, authenticity, safety, or suitability."
                    ],
                    warnings: [
                        isChinese ? "重要风险提示：跳蚤市场交易存在风险，包括但不限于商品质量问题、交易欺诈、资金损失等。用户在参与交易前应充分了解风险，谨慎交易。平台不对任何交易损失承担责任。如遇到欺诈或其他违法行为，请及时向相关执法部门举报。" : "Important Risk Notice: Flea market transactions carry risks, including but not limited to product quality issues, transaction fraud, fund losses, etc. Users should fully understand the risks and trade cautiously before participating in transactions. The platform does not assume responsibility for any transaction losses. If you encounter fraud or other illegal activities, please report to relevant law enforcement authorities promptly."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "13. 争议与适用法律" : "13. Disputes and Applicable Law",
                    content: [
                        isChinese ? "用户之间因任务、支付或服务产生的纠纷，双方应先尽量友好协商；协商不成的，可依下列争议与仲裁规则通过平台处理；仍无法解决的，可提交英格兰与威尔士法院管辖。" : "Disputes between users arising from tasks, payment or services should first be resolved by good-faith negotiation; if that fails, the parties may use the dispute and arbitration rules below via the platform; if still unresolved, they may submit to the courts of England and Wales.",
                        isChinese ? "争议与仲裁规则：" : "Dispute and Arbitration Rules:",
                        isChinese ? "谁可以提起争议：任务或订单的任一方（任务发布者或任务接受者）认为对方未按约定履行、存在违约或对任务完成情况/款项归属有异议时，可在平台内对该任务/订单提起争议。" : "Who may raise a dispute: Either party to a task or order may raise a dispute on the platform if they believe the other party has not performed as agreed, has breached the agreement, or if there is disagreement about completion or who should receive funds.",
                        isChinese ? "提起方式与时限：在对应任务或订单详情页使用「提交争议」功能，填写争议原因并尽量上传证据。建议在任务状态仍为进行中或待确认完成时尽快提交，以便平台及时介入；确认完成后的申诉适用「支付与退款」中的申诉政策。" : "How and when to submit: Use \"Submit Dispute\" on the relevant task or order page, state the reason and upload evidence where possible. It is advisable to submit while the task is in progress or pending confirmation; appeals after confirmation are subject to the appeal policy under Payment and Refund.",
                        isChinese ? "平台调解：平台收到争议后，将先尝试促成双方协商。若双方在平台要求的合理期限内达成一致，按双方一致意见处理资金与订单状态。" : "Platform mediation: After a dispute is submitted, the platform will first try to help the parties reach an agreement. If they agree within a reasonable time, funds and order status will be handled according to that agreement.",
                        isChinese ? "平台裁决：若协商不成或一方未在合理期限内配合，平台将根据现有证据与规则进行裁决，考虑任务描述与约定、双方沟通记录、任务完成情况与证据、本协议及平台公示规则、公平原则。平台有权要求双方补充证据或说明。" : "Platform decision: If the parties do not agree or one party does not cooperate within a reasonable time, the platform will decide based on the evidence and rules, considering task description, communication, completion, these terms and platform rules, and fairness. The platform may ask both parties to provide further evidence or explanation.",
                        isChinese ? "裁决考量因素包括但不限于：任务是否已按约定完成、完成质量是否明显不符合约定、是否存在逾期或擅自变更、双方是否有明确书面约定、证据是否充分可信。平台不保证采纳任一方的主张，以证据与规则为准。" : "Factors considered include whether the task was completed as agreed, whether quality clearly fell short, whether there was delay or unauthorised change, whether there was a clear written agreement, and whether evidence is sufficient and credible. The platform does not guarantee to uphold either party’s position; the decision is based on evidence and rules.",
                        isChinese ? "裁决效力：平台就该项争议作出的处理决定（包括驳回争议、支持全额/部分退款、支持释放全部或部分款项给任务接受者等）在平台内为最终决定，双方应遵守并配合执行。平台将按裁决结果操作资金释放或退款。" : "Effect of the decision: The platform’s decision on that dispute (e.g. dismiss dispute, full or partial refund, release funds to the task taker) is final for platform purposes; both parties must comply and cooperate. The platform will implement the release or refund according to the decision.",
                        isChinese ? "法律救济：若一方对平台裁决不服，仍可依适用法律向有管辖权的法院（英格兰与威尔士）寻求救济；但平台已按裁决执行的资金操作不因后续诉讼而自动逆转，除非法院生效裁判另有要求。" : "Legal remedy: If a party disagrees with the platform’s decision, they may still seek a remedy from a court of competent jurisdiction (England and Wales) under applicable law; however, any release or refund already made by the platform will not be reversed automatically because of later litigation unless required by a final court order.",
                        isChinese ? "本条款受英格兰与威尔士法律管辖并据其解释。如本协议的任何条款被认定为无效或不可执行，不影响其他条款的有效性和可执行性。" : "These terms are governed by and construed in accordance with the laws of England and Wales. If any provision of these terms is found to be invalid or unenforceable, it shall not affect the validity and enforceability of other provisions."
                    ]
                )
                
                TermsSection(
                    title: isChinese ? "14. 消费者条款附录（如用户为消费者时适用）" : "14. Consumer Terms Appendix (Applicable when user is a consumer)",
                    content: [
                        isChinese ? "您作为消费者使用我们的撮合服务时，我们会在界面提供关键信息（平台身份、联系方式、主要功能与任何重要限制）。" : "When you use our matching service as a consumer, we will provide key information on the interface (platform identity, contact information, main functions and any important limitations).",
                        isChinese ? "平台服务费：平台会从任务支付中收取服务费（具体费率见第4条）。平台本身不向消费者直接收费，服务费从任务发布者支付给任务接受者的金额中扣除。我们遵守相关消费者法规（包括信息披露、取消权与禁止隐藏费用/虚假评论等）。" : "Platform Service Fee: The platform charges a service fee from task payments (specific rates are detailed in Section 4). The platform itself does not charge consumers directly; the service fee is deducted from the amount paid by task posters to task takers. We comply with relevant consumer regulations (including information disclosure, cancellation rights and prohibition of hidden fees/false reviews, etc.).",
                        isChinese ? "消费者权利：根据英国《消费者权益法2015》（Consumer Rights Act 2015），作为消费者的用户享有以下权利：（1）获得清晰、准确的服务信息；（2）在服务不符合描述时要求补救或退款；（3）在服务存在缺陷时要求修复或赔偿；（4）在冷静期内取消某些服务合同的权利。平台提供支付处理和资金托管服务，消费者享有相应的退款权利（详见第5条支付与退款）。" : "Consumer Rights: Under the UK Consumer Rights Act 2015, users who are consumers have the following rights: (1) to receive clear and accurate service information; (2) to request remedies or refunds when services do not match descriptions; (3) to request repairs or compensation when services have defects; (4) to cancel certain service contracts during the cooling-off period. The platform provides payment processing and escrow services, and consumers have corresponding refund rights (see Section 5 on Payment and Refund for details).",
                        isChinese ? "消费者投诉：如您作为消费者对我们的服务有投诉，请首先通过 info@link2ur.com 联系我们。如问题未得到解决，您可以向英国消费者服务机构（Citizens Advice）或相关监管机构投诉。" : "Consumer Complaints: If you have complaints about our services as a consumer, please first contact us at info@link2ur.com. If the issue is not resolved, you may complain to UK consumer service organizations (Citizens Advice) or relevant regulatory authorities."
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
                
                Text(isChinese ? "最后更新：2026年1月" : "Last Updated: January 2026")
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
