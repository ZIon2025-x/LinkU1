import SwiftUI

struct FAQView: View {
    @Environment(\.locale) var locale
    @State private var expandedSections: Set<String> = []
    @State private var expandedItems: Set<String> = []
    
    private var isChinese: Bool {
        locale.languageCode == "zh"
    }
    
    private var faqSections: [FAQSection] {
        [
            FAQSection(
                id: "task_flow",
                title: isChinese ? "任务流程" : "Task Flow",
                items: [
                    FAQItem(
                        id: "task_flow_1",
                        question: isChinese ? "平台上的任务基本流程是什么？" : "What is the basic task flow?",
                        answer: isChinese ? "1) 发布方创建任务（填写标题、预算、时间/地点等）→ 2) 服务方浏览并沟通 → 3) 双方确认细节并开始执行 → 4) 完成后进行评价与结算。" : "1) Poster creates a task (title, budget, time/location, etc.) → 2) Taker browses and contacts → 3) Confirm details and start → 4) Complete, review and settle.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "task_flow_2",
                        question: isChinese ? "如何提高匹配与成交率？" : "How to improve matching and success rate?",
                        answer: isChinese ? "尽量提供清晰需求、合理预算与可行时间窗口；及时回复消息并保持礼貌沟通；必要时补充图片或示例。" : "Provide clear requirements, reasonable budget and feasible time windows; reply promptly and communicate politely; add images/examples if helpful."
                    )
                ]
            ),
            FAQSection(
                id: "cancel_task",
                title: isChinese ? "取消任务" : "Cancel Task",
                items: [
                    FAQItem(
                        id: "cancel_task_1",
                        question: isChinese ? "可以取消已发布/已接的任务吗？" : "Can I cancel a posted/accepted task?",
                        answer: isChinese ? "在任务未执行或双方尚未产生实际成本前，通常可经沟通取消。请在\"我的任务\"中操作或与对方协商一致后取消。" : "Before execution or actual costs incurred, cancellation is generally allowed upon mutual agreement. Use \"My Tasks\" or communicate with the counterparty to cancel.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "cancel_task_2",
                        question: isChinese ? "进行中的任务如何取消？是否需要客服审核？" : "How to cancel an in‑progress task? Is support review required?",
                        answer: isChinese ? "当任务状态为\"已被接受/进行中\"时（taken/in_progress），取消将进入\"客服审核\"。系统会为该任务创建一条\"取消请求\"（pending），客服审核后会\"通过/驳回\"。通过后任务状态将变为\"已取消\"。如已存在待审请求，将无法重复提交。\n\n如何跟进：在消息中与对方沟通，并留意平台通知（取消请求结果会以通知形式发送）。\n\n结果处理：若\"通过\"，双方都会收到任务取消通知；若\"驳回\"，可补充理由再次申请或联系邮箱 support@link2ur.com。" : "When a task is taken or in_progress, cancellation requires support review. The system creates a pending cancel request which will be approved/rejected by support. Upon approval, the task becomes cancelled. If a pending request already exists, duplicate submissions are blocked.\n\nFollow‑up: communicate in Messages and watch platform notifications for the review result.\n\nOutcomes: if approved, both parties receive cancellation notifications; if rejected, add more context and resubmit, or email support@link2ur.com."
                    ),
                    FAQItem(
                        id: "cancel_task_3",
                        question: isChinese ? "取消是否会影响信用或评价？" : "Will cancellation affect my reputation?",
                        answer: isChinese ? "频繁或临近执行才取消可能影响评价。建议尽早沟通与说明理由，减少对方损失。" : "Frequent or last‑minute cancellations may affect reviews. Communicate early with reasons to minimize impact."
                    )
                ]
            ),
            FAQSection(
                id: "confirmation_disputes",
                title: isChinese ? "任务确认与争议" : "Confirmation & Disputes",
                items: [
                    FAQItem(
                        id: "confirmation_1",
                        question: isChinese ? "对方一直未标记\"同意/确认完成\"怎么办？" : "What if the other party never confirms completion?",
                        answer: isChinese ? "当接受方标记\"完成\"后，任务进入\"待确认\"状态（pending_confirmation），由发布方确认。若长时间未确认，请先在消息中沟通，必要时提供完成证据（图片/聊天记录等）。若仍无结果，可联系 support@link2ur.com 由客服介入。" : "After the taker marks completion, the task enters pending_confirmation for the poster to confirm. If confirmation is delayed, communicate via Messages and provide evidence (photos/chat logs). If unresolved, email support@link2ur.com for assistance.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "confirmation_2",
                        question: isChinese ? "发布方/接受方拒绝确认怎么办？" : "What if poster/taker refuses to confirm?",
                        answer: isChinese ? "请在平台内保持沟通并尽可能收集证据；如涉及质量争议、逾期或费用变更，请详细说明。客服会基于双方信息进行裁定。" : "Keep communication on the platform and collect evidence. Clearly describe quality issues, delays, or pricing changes. Support will adjudicate based on both sides' information."
                    )
                ]
            ),
            FAQSection(
                id: "report_safety",
                title: isChinese ? "举报与安全" : "Report & Safety",
                items: [
                    FAQItem(
                        id: "report_1",
                        question: isChinese ? "有人发布不实/违法信息怎么办？" : "What if someone posts false/illegal content?",
                        answer: isChinese ? "请截图保留证据，并通过任务页或消息界面中的反馈入口进行举报；也可发送详情至 support@link2ur.com。我们会尽快核查并处理。" : "Please take screenshots as evidence and report via the task page or messaging feedback entry; or email details to support@link2ur.com. We will investigate promptly.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "report_2",
                        question: isChinese ? "遇到疑似诈骗如何处理？" : "How to handle suspected fraud?",
                        answer: isChinese ? "切勿私下转账，务必在平台内沟通与记录；发现异常立即停止交互并举报。必要时向警方报案，并向我们提供证据协助处置。" : "Do not transfer money privately; keep communication on‑platform. Stop interactions and report immediately if suspicious. If needed, file a police report and share evidence with us."
                    ),
                    FAQItem(
                        id: "report_3",
                        question: isChinese ? "如何更好地保护自身安全？" : "How to better protect yourself?",
                        answer: isChinese ? "避免分享敏感隐私与账户信息；线下见面请选择公共场所并告知熟人；对非正常价格与要求提高警惕。" : "Avoid sharing sensitive personal/account info; choose public places for offline meetings and inform someone you trust; be cautious of abnormal prices and requests."
                    )
                ]
            ),
            FAQSection(
                id: "account_login",
                title: isChinese ? "账户与登录" : "Account & Login",
                items: [
                    FAQItem(
                        id: "account_1",
                        question: isChinese ? "无法登录/忘记密码怎么办？" : "Can't log in / forgot password?",
                        answer: isChinese ? "请在登录弹窗选择\"忘记密码\"，或联系邮箱 support@link2ur.com。若浏览器禁用第三方 Cookie，可能影响登录状态，请开启或改用同一域名访问。" : "Use \"Forgot password\" in the login dialog, or email support@link2ur.com. If third‑party cookies are blocked, login may fail; enable cookies or access via the same site domain.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "account_2",
                        question: isChinese ? "为什么登录后偶尔会掉线？" : "Why do I sometimes get signed out?",
                        answer: isChinese ? "为提升安全性，我们使用短期会话与刷新机制。若频繁失效，请检查浏览器的 Cookie/隐私设置，或清理缓存后重试。" : "For security, we use short‑lived sessions with refresh. If this happens often, check your browser's cookie/privacy settings or clear cache and try again."
                    )
                ]
            ),
            FAQSection(
                id: "posting_taking",
                title: isChinese ? "任务发布与接单" : "Task Posting & Taking",
                items: [
                    FAQItem(
                        id: "posting_1",
                        question: isChinese ? "如何高效发布任务？" : "How to post a task effectively?",
                        answer: isChinese ? "请完善任务标题、预算、时间范围与地点，尽量提供清晰描述；必要时添加照片或补充说明，能显著提升接单率。" : "Provide clear title, budget, time window, and location. Add photos or extra details when necessary to significantly increase responses.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "posting_2",
                        question: isChinese ? "为何任务未获得响应？" : "Why am I not getting responses?",
                        answer: isChinese ? "尝试：适度提高预算、放宽时间窗口、完善描述与图片；同时确保联系方式可用。也可在\"消息\"与潜在服务者沟通。" : "Try increasing budget, widening the time window, improving description/photos, and make sure your contact works. You can also reach out via Messages."
                    )
                ]
            ),
            FAQSection(
                id: "messaging_support",
                title: isChinese ? "消息与客服" : "Messaging & Support",
                items: [
                    FAQItem(
                        id: "support_1",
                        question: isChinese ? "客服在线时间与响应规则？" : "Support availability and response?",
                        answer: isChinese ? "测试阶段客服在线时段不固定。若遇紧急问题，请先在 FAQ 中查找，或发送邮件至 support@link2ur.com。" : "During testing, support hours are irregular. For urgent issues, check this FAQ first or email support@link2ur.com.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "support_2",
                        question: isChinese ? "消息未送达/通知不显示怎么办？" : "Messages not delivered / no notifications?",
                        answer: isChinese ? "请确认已登录且网络稳定；若浏览器屏蔽通知或 Cookie，可能导致未读数异常。刷新页面或重新登录通常可恢复。" : "Ensure you are logged in and the network is stable. Blocking notifications or cookies can affect unread counts. Refresh or re-login usually resolves it."
                    )
                ]
            ),
            FAQSection(
                id: "privacy_security",
                title: isChinese ? "隐私与安全" : "Privacy & Security",
                items: [
                    FAQItem(
                        id: "privacy_1",
                        question: isChinese ? "平台如何保护账户安全？" : "How do you protect account security?",
                        answer: isChinese ? "我们采用服务端会话与刷新令牌机制，并提供多重风控校验。敏感操作会进行登录状态检查与权限限制。" : "We use server sessions with refresh tokens and multi-layer risk controls. Sensitive operations require session checks and permissions.",
                        isOpen: true
                    ),
                    FAQItem(
                        id: "privacy_2",
                        question: isChinese ? "我的数据如何被使用？" : "How is my data used?",
                        answer: isChinese ? "详见《隐私政策》。我们遵循最小化收集原则，仅为提供与改进服务所必需的场景使用。" : "See the Privacy Policy. We follow data minimization and use data only to provide and improve the service."
                    ),
                    FAQItem(
                        id: "privacy_3",
                        question: isChinese ? "为什么我的账户被封禁或暂停？如何申诉？" : "Why is my account banned or suspended? How to appeal?",
                        answer: isChinese ? "管理员可因违规、涉嫌诈骗、滥用平台等原因对账户执行\"暂停（可设恢复时间）\"或\"封禁\"。被暂停/封禁的账户将无法登录或受限使用。若认为处理有误，请邮件至 support@link2ur.com，附上账户信息与相关说明以便人工复核。" : "Admins may suspend (with optional resume time) or ban accounts for violations, suspected fraud, or abuse. Suspended/banned accounts cannot log in or are restricted. If you believe this is a mistake, email support@link2ur.com with your account info and details for manual review."
                    )
                ]
            ),
            FAQSection(
                id: "others",
                title: isChinese ? "其他" : "Others",
                items: [
                    FAQItem(
                        id: "others_1",
                        question: isChinese ? "是否支持移动端？" : "Is mobile supported?",
                        answer: isChinese ? "已对移动端进行适配，建议使用现代浏览器获得更佳体验。" : "Yes. The site is mobile‑friendly; use a modern browser for best experience."
                    ),
                    FAQItem(
                        id: "others_2",
                        question: isChinese ? "如何成为平台专家/合作方？" : "How to become an expert/partner?",
                        answer: isChinese ? "可通过页脚的\"合作与伙伴\"相关入口提交信息，或邮件联系我们。" : "Use the links in the footer (Partners / Task Experts) to submit info, or email us."
                    )
                ]
            )
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(isChinese ? "我们根据近期用户反馈整理了常见问题与答案，帮助你更快上手平台。" : "We compiled common questions and answers to help you get started quickly.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                
                ForEach(faqSections) { section in
                    FAQSectionView(
                        section: section,
                        isExpanded: expandedSections.contains(section.id),
                        expandedItems: expandedItems,
                        onToggleSection: {
                            if expandedSections.contains(section.id) {
                                expandedSections.remove(section.id)
                            } else {
                                expandedSections.insert(section.id)
                            }
                        },
                        onToggleItem: { itemId in
                            if expandedItems.contains(itemId) {
                                expandedItems.remove(itemId)
                            } else {
                                expandedItems.insert(itemId)
                            }
                        }
                    )
                    .padding(.horizontal, AppSpacing.md)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle(isChinese ? "常见问题" : "FAQ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct FAQSection: Identifiable {
    let id: String
    let title: String
    let items: [FAQItem]
}

struct FAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
    var isOpen: Bool = false
}

struct FAQSectionView: View {
    let section: FAQSection
    let isExpanded: Bool
    let expandedItems: Set<String>
    let onToggleSection: () -> Void
    let onToggleItem: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleSection()
                }
            }) {
                HStack {
                    Text(section.title)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(section.items) { item in
                        Divider()
                            .padding(.horizontal, AppSpacing.md)
                        
                        FAQItemView(
                            item: item,
                            isExpanded: expandedItems.contains(item.id) || item.isOpen,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    onToggleItem(item.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct FAQItemView: View {
    let item: FAQItem
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(item.question)
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                    .padding(.horizontal, AppSpacing.md)
                
                Text(item.answer)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                    .padding(AppSpacing.md)
                    .padding(.top, AppSpacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationView {
        FAQView()
    }
}
