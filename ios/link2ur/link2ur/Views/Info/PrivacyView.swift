import SwiftUI

struct PrivacyView: View {
    @Environment(\.locale) var locale
    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // 标题和版本信息
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(isChinese ? "隐私通知" : "Privacy Notice")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(isChinese ? "版本：v0.9-beta" : "Version: v0.9-beta")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(isChinese ? "生效日期：2025年10月10日" : "Effective Date: October 10, 2025")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                
                // 控制者信息
                InfoBox(
                    title: isChinese ? "控制者（Controller）" : "Controller",
                    content: [
                        isChinese ? "LINK2UR LTD" : "LINK2UR LTD",
                        isChinese ? "联系邮箱：info@link2ur.com" : "Contact Email: info@link2ur.com",
                        isChinese ? "通讯地址：A3, B16 9NB, UK" : "Mailing Address: A3, B16 9NB, UK",
                        isChinese ? "（如需数据保护联系人/DPO，可使用以上邮箱）" : "(For data protection contact/DPO, please use the above email)"
                    ]
                )
                
                // 数据收集
                PrivacySection(
                    title: isChinese ? "我们收集哪些数据 & 处理目的（法律依据）" : "What Data We Collect & Processing Purposes (Legal Basis)",
                    items: [
                        (isChinese ? "账户数据：邮箱、姓名（如提供）、登录记录等 —— 用于创建与管理账户、与您沟通（合同履行/合法利益）。" : "Account Data: Email, name (if provided), login records, etc. — For account creation and management, communication with you (contract performance/legitimate interests).", nil),
                        (isChinese ? "任务与沟通数据：任务内容、时间、交流记录（站内消息/电子邮件中由我们接收的部分）—— 为撮合、风控与支持（合同履行/合法利益）。" : "Task and Communication Data: Task content, timestamps, communication records (in-platform messages/emails received by us) — For matching, risk control and support (contract performance/legitimate interests).", nil),
                        (isChinese ? "位置信息：当您使用地图选点功能时，我们会收集位置坐标（经纬度）。我们仅显示模糊位置（如城市或区域），不显示精确坐标。位置信息用于帮助您选择任务/商品位置、计算距离和匹配。您可以选择手动输入位置，不强制使用定位功能（合同履行/合法利益）。" : "Location Information: When you use the map location picker feature, we collect location coordinates (latitude/longitude). We only display obfuscated locations (such as city or area), not precise coordinates. Location information is used to help you select task/item locations, calculate distances, and matching. You can choose to manually enter locations instead; location services are not mandatory (contract performance/legitimate interests).", nil),
                        (isChinese ? "技术与日志数据：IP、设备信息、错误日志、必要 Cookies —— 用于安全、调试与防滥用（合法利益）。" : "Technical and Log Data: IP, device information, error logs, necessary Cookies — For security, debugging and abuse prevention (legitimate interests).", nil),
                        (isChinese ? "可选分析 Cookies（如启用）：用于了解使用情况与改进体验（同意）。" : "Optional Analytics Cookies (if enabled): For understanding usage and improving experience (consent).", nil),
                        (isChinese ? "支付相关：我们不在平台内处理支付；如您进行站外支付，支付数据由相关第三方或交易对方处理，我们仅在对账或支持需要时获得最小必要信息（合同履行/合法利益）。" : "Payment Related: We do not process payments within the platform; if you make off-platform payments, payment data is handled by relevant third parties or transaction counterparts, and we only obtain minimal necessary information for reconciliation or support needs (contract performance/legitimate interests).", nil)
                    ]
                )
                
                // 数据共享
                PrivacySection(
                    title: isChinese ? "与谁共享" : "Who We Share With",
                    items: [
                        (isChinese ? "云服务/托管与安全供应商：仅在提供服务所必需的范围内共享，并签署数据处理条款。" : "Cloud Services/Hosting and Security Vendors: Only shared to the extent necessary for service provision, with data processing agreements in place.", nil),
                        (isChinese ? "执法/监管与纠纷处理：在法律要求或为保护合法权利时披露必要信息。" : "Law Enforcement/Regulatory and Dispute Resolution: Disclose necessary information when legally required or to protect legitimate rights.", nil)
                    ]
                )
                
                // 国际传输
                PrivacySection(
                    title: isChinese ? "国际传输" : "International Transfers",
                    items: [
                        (isChinese ? "如需将个人数据传输至英国以外，我们会采用适用的传输保障（如 UK IDTA 或欧盟 SCCs 的英国附加条款等）。" : "If personal data needs to be transferred outside the UK, we will use applicable transfer safeguards (such as UK IDTA or UK addendum to EU SCCs, etc.).", nil)
                    ]
                )
                
                // 保留期限
                PrivacySection(
                    title: isChinese ? "保留期限" : "Retention Periods",
                    items: [
                        (isChinese ? "账户与基础运营数据：账户存续期 + 合理的备份期。" : "Account and Basic Operational Data: Account duration + reasonable backup period.", nil),
                        (isChinese ? "交易/任务与客服相关记录：为会计、税务或合规目的，通常保留最长不超过6年（除非法律要求更长/更短）。" : "Transaction/Task and Customer Service Records: For accounting, tax or compliance purposes, typically retained for no more than 6 years (unless law requires longer/shorter).", nil),
                        (isChinese ? "安全日志：基于风险分级确定，尽量最短必要。" : "Security Logs: Determined based on risk classification, kept for the shortest necessary period.", nil)
                    ]
                )
                
                // 您的权利
                PrivacySection(
                    title: isChinese ? "您的权利" : "Your Rights",
                    items: [
                        (isChinese ? "您有权请求访问、更正、删除、限制处理、数据可携、反对处理，以及在基于同意时撤回同意（撤回不影响撤回前的处理合法性）。" : "You have the right to request access, rectification, erasure, restriction of processing, data portability, objection to processing, and to withdraw consent when based on consent (withdrawal does not affect the legality of processing before withdrawal).", nil),
                        (isChinese ? "如对我们的数据处理有疑问或投诉，请先邮件联系 info@link2ur.com；仍有疑虑，您可向英国信息监管机构 ICO 投诉。" : "If you have questions or complaints about our data processing, please first contact info@link2ur.com by email; if you still have concerns, you may complain to the UK Information Commissioner's Office (ICO).", nil)
                    ]
                )
                
                // Cookies
                PrivacySection(
                    title: isChinese ? "Cookies 与类似技术" : "Cookies and Similar Technologies",
                    items: [
                        (isChinese ? "什么是 Cookies：Cookies 是存储在您设备上的小型文本文件，用于帮助网站记住您的偏好、登录状态等信息。我们可能使用 Cookies 和类似技术（如本地存储、像素标签等）来提供和改进我们的服务。" : "What are Cookies: Cookies are small text files stored on your device that help websites remember your preferences, login status, and other information. We may use cookies and similar technologies (such as local storage, pixel tags, etc.) to provide and improve our services.", nil),
                        (isChinese ? "必要 Cookies（必需）：这些 Cookies 对网站的基本功能至关重要，包括身份验证、安全性和网站正常运行。这些 Cookies 不需要您的同意即可使用，因为它们是网站运行所必需的。包括：会话管理 Cookies（用于保持您登录状态）、安全 Cookies（用于防止欺诈和滥用）、负载均衡 Cookies（用于分配服务器负载）。" : "Necessary Cookies (Required): These cookies are essential for the basic functions of the website, including authentication, security, and normal website operation. These cookies do not require your consent as they are necessary for the website to function. Including: session management cookies (to keep you logged in), security cookies (to prevent fraud and abuse), load balancing cookies (to distribute server load).", nil),
                        (isChinese ? "功能性 Cookies（可选）：这些 Cookies 允许网站记住您的选择（如语言偏好、地区设置），以提供增强的个性化功能。这些 Cookies 仅在您明确同意后启用。包括：偏好设置 Cookies（记住您的语言、主题等设置）、功能性 Cookies（记住您的搜索历史、购物车内容等）。" : "Functional Cookies (Optional): These cookies allow the website to remember your choices (such as language preferences, regional settings) to provide enhanced personalized features. These cookies are only enabled after your explicit consent. Including: preference cookies (remembering your language, theme, and other settings), functional cookies (remembering your search history, shopping cart contents, etc.).", nil),
                        (isChinese ? "分析 Cookies（可选）：这些 Cookies 帮助我们了解用户如何使用网站，以便我们改进网站性能和用户体验。这些 Cookies 仅在您明确同意后启用。包括：网站分析 Cookies（用于统计访问量、页面浏览量等）、性能监控 Cookies（用于监控网站性能、错误率等）。我们可能使用第三方分析服务（如 Google Analytics），这些服务提供商有自己的隐私政策。" : "Analytics Cookies (Optional): These cookies help us understand how users use the website so we can improve website performance and user experience. These cookies are only enabled after your explicit consent. Including: website analytics cookies (for statistics on visits, page views, etc.), performance monitoring cookies (for monitoring website performance, error rates, etc.). We may use third-party analytics services (such as Google Analytics), and these service providers have their own privacy policies.", nil),
                        (isChinese ? "Cookie 管理：您可以通过浏览器设置管理或删除 Cookies。大多数浏览器允许您拒绝所有 Cookies 或仅接受第一方 Cookies。请注意，禁用某些 Cookies 可能会影响网站的功能和您的使用体验。您也可以随时通过我们的 Cookie 设置页面更改您的 Cookie 偏好。" : "Cookie Management: You can manage or delete cookies through your browser settings. Most browsers allow you to refuse all cookies or only accept first-party cookies. Please note that disabling certain cookies may affect website functionality and your user experience. You can also change your cookie preferences at any time through our cookie settings page.", nil),
                        (isChinese ? "第三方 Cookies：我们可能允许第三方服务提供商在我们的网站上设置 Cookies，用于提供广告、分析或其他服务。这些第三方 Cookies 受第三方隐私政策的约束，我们不对其负责。我们建议您查看这些第三方的隐私政策以了解他们如何使用 Cookies。" : "Third-Party Cookies: We may allow third-party service providers to set cookies on our website for advertising, analytics, or other services. These third-party cookies are subject to third-party privacy policies, and we are not responsible for them. We recommend that you review these third parties' privacy policies to understand how they use cookies.", nil),
                        (isChinese ? "移动应用中的类似技术：在移动应用中，我们可能使用类似的技术（如应用内标识符、设备 ID 等）来实现类似 Cookies 的功能。这些技术的使用遵循本隐私通知的规定。" : "Similar Technologies in Mobile Apps: In mobile applications, we may use similar technologies (such as in-app identifiers, device IDs, etc.) to achieve cookie-like functionality. The use of these technologies follows the provisions of this privacy notice.", nil),
                        (isChinese ? "Cookie 保留期限：不同类型的 Cookies 有不同的保留期限。会话 Cookies 在您关闭浏览器时自动删除；持久 Cookies 会在您的设备上保留一段时间（通常不超过 2 年），除非您手动删除它们。我们会在 Cookie 设置页面提供每种 Cookie 的具体保留期限信息。" : "Cookie Retention Periods: Different types of cookies have different retention periods. Session cookies are automatically deleted when you close your browser; persistent cookies remain on your device for a period of time (usually no more than 2 years) unless you manually delete them. We will provide specific retention period information for each cookie type on the cookie settings page.", nil)
                    ]
                )
                
                // 联系我们
                PrivacySection(
                    title: isChinese ? "联系我们" : "Contact Us",
                    items: [
                        (isChinese ? "就本隐私通知或个人数据事宜，随时联系：info@link2ur.com" : "For this privacy notice or personal data matters, contact us anytime: info@link2ur.com", nil)
                    ]
                )
                
                // 重要提示
                InfoBox(
                    title: isChinese ? "重要提示" : "Important Notice",
                    content: [
                        isChinese ? "本隐私通知是您与Link²Ur之间关于个人信息处理的协议。我们承诺按照本通知保护您的隐私权益。" : "This privacy notice is an agreement between you and Link²Ur regarding personal information processing. We are committed to protecting your privacy rights in accordance with this notice."
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
        .navigationTitle(isChinese ? "隐私政策" : "Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct PrivacySection: View {
    let title: String
    let items: [(String, String?)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.0)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(4)
                    
                    if let subItem = item.1 {
                        Text(subItem)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.leading, AppSpacing.md)
                    }
                }
            }
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
