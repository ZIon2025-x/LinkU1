import SwiftUI
import Combine

struct CookiePolicyView: View {
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
                LegalDocumentContentView(contentJson: content, documentType: "cookie")
            } else {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // 标题和版本信息
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(isChinese ? "Cookie 政策" : "Cookie Policy")
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
                
                // 简介
                InfoBox(
                    title: isChinese ? "简介" : "Introduction",
                    content: [
                        isChinese ? "本 Cookie 政策说明了 Link²Ur（\"我们\"、\"我们的\"）如何使用 Cookies 和类似技术，以及您如何管理这些技术。本政策是《隐私通知》的补充，应与《隐私通知》一起阅读。" : "This Cookie Policy explains how Link²Ur (\"we\", \"our\") uses cookies and similar technologies, and how you can manage these technologies. This policy supplements the Privacy Notice and should be read together with the Privacy Notice.",
                        isChinese ? "根据英国《隐私与电子通信条例》（Privacy and Electronic Communications Regulations, PECR）和《通用数据保护条例》（UK GDPR），我们必须在您访问我们的网站时告知您我们使用的 Cookies，并获得您对非必要 Cookies 的同意。" : "Under the UK Privacy and Electronic Communications Regulations (PECR) and the General Data Protection Regulation (UK GDPR), we must inform you about the cookies we use when you visit our website and obtain your consent for non-essential cookies."
                    ]
                )
                
                // 1. 什么是 Cookies
                CookieSection(
                    title: isChinese ? "1. 什么是 Cookies 和类似技术" : "1. What are Cookies and Similar Technologies",
                    content: [
                        isChinese ? "Cookies 是当您访问网站时存储在您设备（计算机、平板电脑或移动设备）上的小型文本文件。Cookies 包含信息，这些信息会在您返回网站或访问其他使用相同 Cookies 的网站时被传输回网站。" : "Cookies are small text files that are stored on your device (computer, tablet, or mobile device) when you visit a website. Cookies contain information that is transmitted back to the website when you return to the website or visit other websites that use the same cookies.",
                        isChinese ? "除了 Cookies，我们还可能使用其他类似技术，包括：" : "In addition to cookies, we may also use other similar technologies, including:",
                        isChinese ? "• 本地存储（Local Storage）：在您的浏览器中存储数据，类似于 Cookies，但可以存储更多信息。" : "• Local Storage: Stores data in your browser, similar to cookies but can store more information.",
                        isChinese ? "• 会话存储（Session Storage）：临时存储数据，仅在浏览器会话期间有效。" : "• Session Storage: Temporarily stores data, only valid during the browser session.",
                        isChinese ? "• 像素标签（Pixel Tags）：用于跟踪网页访问和电子邮件打开情况的小型图像文件。" : "• Pixel Tags: Small image files used to track webpage visits and email opens.",
                        isChinese ? "• 设备标识符：在移动应用中用于识别设备的唯一标识符。" : "• Device Identifiers: Unique identifiers used in mobile applications to identify devices."
                    ]
                )
                
                // 2. 我们使用的 Cookies 类型
                CookieSection(
                    title: isChinese ? "2. 我们使用的 Cookies 类型" : "2. Types of Cookies We Use",
                    content: [
                        isChinese ? "我们根据 Cookies 的用途和必要性将其分为以下几类：" : "We categorize cookies based on their purpose and necessity as follows:",
                        isChinese ? "2.1 严格必要的 Cookies（必需）" : "2.1 Strictly Necessary Cookies (Required)",
                        isChinese ? "这些 Cookies 对网站的基本功能至关重要，没有这些 Cookies，网站将无法正常运行。这些 Cookies 不需要您的同意即可使用。包括：" : "These cookies are essential for the basic functions of the website. Without these cookies, the website cannot function properly. These cookies do not require your consent. Including:",
                        isChinese ? "• 身份验证 Cookies：用于保持您的登录状态，确保您已通过身份验证。" : "• Authentication Cookies: Used to maintain your login status and ensure you are authenticated.",
                        isChinese ? "• 安全 Cookies：用于防止欺诈、滥用和未经授权的访问，保护您的账户安全。" : "• Security Cookies: Used to prevent fraud, abuse, and unauthorized access, protecting your account security.",
                        isChinese ? "• 负载均衡 Cookies：用于在多个服务器之间分配流量，确保网站稳定运行。" : "• Load Balancing Cookies: Used to distribute traffic among multiple servers to ensure stable website operation.",
                        isChinese ? "• 购物车/会话 Cookies：用于记住您在网站上的操作，如添加到购物车或表单填写进度。" : "• Shopping Cart/Session Cookies: Used to remember your actions on the website, such as items added to cart or form filling progress.",
                        isChinese ? "2.2 功能性 Cookies（可选）" : "2.2 Functional Cookies (Optional)",
                        isChinese ? "这些 Cookies 允许网站记住您的选择（如语言偏好、地区设置），以提供增强的个性化功能。这些 Cookies 仅在您明确同意后启用。包括：" : "These cookies allow the website to remember your choices (such as language preferences, regional settings) to provide enhanced personalized features. These cookies are only enabled after your explicit consent. Including:",
                        isChinese ? "• 偏好设置 Cookies：记住您的语言、主题、字体大小等设置。" : "• Preference Cookies: Remember your language, theme, font size, and other settings.",
                        isChinese ? "• 功能性 Cookies：记住您的搜索历史、收藏内容、最近查看的项目等。" : "• Functional Cookies: Remember your search history, favorite content, recently viewed items, etc.",
                        isChinese ? "• 地理位置 Cookies：记住您的位置偏好，用于提供本地化的内容和服务。" : "• Geolocation Cookies: Remember your location preferences for providing localized content and services.",
                        isChinese ? "2.3 分析 Cookies（可选）" : "2.3 Analytics Cookies (Optional)",
                        isChinese ? "这些 Cookies 帮助我们了解用户如何使用网站，以便我们改进网站性能和用户体验。这些 Cookies 仅在您明确同意后启用。包括：" : "These cookies help us understand how users use the website so we can improve website performance and user experience. These cookies are only enabled after your explicit consent. Including:",
                        isChinese ? "• 网站分析 Cookies：用于统计访问量、页面浏览量、用户停留时间、跳出率等指标。" : "• Website Analytics Cookies: Used to statistics on visits, page views, user dwell time, bounce rate, and other metrics.",
                        isChinese ? "• 性能监控 Cookies：用于监控网站性能、错误率、加载时间等，帮助我们优化网站速度。" : "• Performance Monitoring Cookies: Used to monitor website performance, error rates, loading times, etc., helping us optimize website speed.",
                        isChinese ? "• 用户行为分析 Cookies：用于分析用户在网站上的行为模式，了解用户偏好和需求。" : "• User Behavior Analysis Cookies: Used to analyze user behavior patterns on the website to understand user preferences and needs.",
                        isChinese ? "我们可能使用第三方分析服务（如 Google Analytics），这些服务提供商有自己的隐私政策。我们建议您查看这些第三方的隐私政策以了解他们如何使用 Cookies。" : "We may use third-party analytics services (such as Google Analytics), and these service providers have their own privacy policies. We recommend that you review these third parties' privacy policies to understand how they use cookies.",
                        isChinese ? "2.4 广告 Cookies（目前未使用）" : "2.4 Advertising Cookies (Currently Not Used)",
                        isChinese ? "目前我们不在网站上使用广告 Cookies。如果未来我们使用广告 Cookies，我们将在本政策中更新相关信息，并在使用前获得您的明确同意。" : "We currently do not use advertising cookies on our website. If we use advertising cookies in the future, we will update relevant information in this policy and obtain your explicit consent before use."
                    ]
                )
                
                // 3. 第三方 Cookies
                CookieSection(
                    title: isChinese ? "3. 第三方 Cookies" : "3. Third-Party Cookies",
                    content: [
                        isChinese ? "我们可能允许第三方服务提供商在我们的网站上设置 Cookies。这些第三方 Cookies 受第三方隐私政策的约束，我们不对其负责。" : "We may allow third-party service providers to set cookies on our website. These third-party cookies are subject to third-party privacy policies, and we are not responsible for them.",
                        isChinese ? "我们可能使用的第三方服务包括：" : "Third-party services we may use include:",
                        isChinese ? "• 分析服务：如 Google Analytics，用于网站分析和性能监控。" : "• Analytics Services: Such as Google Analytics, for website analytics and performance monitoring.",
                        isChinese ? "• 云服务提供商：用于托管和存储数据。" : "• Cloud Service Providers: For hosting and data storage.",
                        isChinese ? "• 安全服务：用于防止欺诈和滥用。" : "• Security Services: For preventing fraud and abuse.",
                        isChinese ? "我们建议您查看这些第三方的隐私政策和 Cookie 政策，以了解他们如何使用 Cookies 和您的数据。" : "We recommend that you review these third parties' privacy policies and cookie policies to understand how they use cookies and your data."
                    ]
                )
                
                // 4. Cookie 保留期限
                CookieSection(
                    title: isChinese ? "4. Cookie 保留期限" : "4. Cookie Retention Periods",
                    content: [
                        isChinese ? "不同类型的 Cookies 有不同的保留期限：" : "Different types of cookies have different retention periods:",
                        isChinese ? "• 会话 Cookies：这些 Cookies 是临时的，仅在您访问网站期间有效。当您关闭浏览器时，这些 Cookies 会自动删除。" : "• Session Cookies: These cookies are temporary and only valid during your visit to the website. These cookies are automatically deleted when you close your browser.",
                        isChinese ? "• 持久 Cookies：这些 Cookies 会在您的设备上保留一段时间，即使您关闭浏览器也会保留。持久 Cookies 的保留期限通常为 30 天至 2 年，具体取决于 Cookie 的类型和用途。我们会在 Cookie 设置页面提供每种 Cookie 的具体保留期限信息。" : "• Persistent Cookies: These cookies remain on your device for a period of time, even after you close your browser. The retention period for persistent cookies is usually 30 days to 2 years, depending on the type and purpose of the cookie. We will provide specific retention period information for each cookie type on the cookie settings page.",
                        isChinese ? "• 第三方 Cookies：第三方 Cookies 的保留期限由第三方服务提供商决定，我们无法控制。请查看相关第三方的隐私政策了解详细信息。" : "• Third-Party Cookies: The retention period for third-party cookies is determined by third-party service providers, which we cannot control. Please review the relevant third parties' privacy policies for detailed information."
                    ]
                )
                
                // 5. 如何管理 Cookies
                CookieSection(
                    title: isChinese ? "5. 如何管理 Cookies" : "5. How to Manage Cookies",
                    content: [
                        isChinese ? "您可以通过以下方式管理 Cookies：" : "You can manage cookies in the following ways:",
                        isChinese ? "5.1 通过我们的 Cookie 设置" : "5.1 Through Our Cookie Settings",
                        isChinese ? "您可以通过我们网站上的 Cookie 设置页面随时更改您的 Cookie 偏好。您可以启用或禁用功能性 Cookies 和分析 Cookies，但请注意，禁用某些 Cookies 可能会影响网站的功能和您的使用体验。" : "You can change your cookie preferences at any time through the cookie settings page on our website. You can enable or disable functional cookies and analytics cookies, but please note that disabling certain cookies may affect website functionality and your user experience.",
                        isChinese ? "5.2 通过浏览器设置" : "5.2 Through Browser Settings",
                        isChinese ? "大多数浏览器允许您管理 Cookies。您可以通过浏览器设置：" : "Most browsers allow you to manage cookies. You can:",
                        isChinese ? "• 查看您设备上存储的 Cookies" : "• View cookies stored on your device",
                        isChinese ? "• 删除 Cookies（包括所有 Cookies 或特定网站的 Cookies）" : "• Delete cookies (including all cookies or cookies from specific websites)",
                        isChinese ? "• 阻止 Cookies（阻止所有 Cookies 或仅阻止第三方 Cookies）" : "• Block cookies (block all cookies or only third-party cookies)",
                        isChinese ? "• 在设置 Cookies 前收到通知" : "• Receive notifications before cookies are set",
                        isChinese ? "请注意，禁用或删除 Cookies 可能会影响网站的功能。某些功能可能无法正常工作，您可能需要重新输入信息或重新设置偏好。" : "Please note that disabling or deleting cookies may affect website functionality. Some features may not work properly, and you may need to re-enter information or reset preferences.",
                        isChinese ? "5.3 移动应用中的 Cookie 管理" : "5.3 Cookie Management in Mobile Apps",
                        isChinese ? "在移动应用中，您可以通过应用设置管理类似 Cookies 的技术（如应用内标识符、设备 ID 等）。您也可以通过在设备设置中重置广告标识符来管理某些标识符。" : "In mobile applications, you can manage cookie-like technologies (such as in-app identifiers, device IDs, etc.) through app settings. You can also manage certain identifiers by resetting advertising identifiers in device settings."
                    ]
                )
                
                // 6. 移动应用中的类似技术
                CookieSection(
                    title: isChinese ? "6. 移动应用中的类似技术" : "6. Similar Technologies in Mobile Applications",
                    content: [
                        isChinese ? "在移动应用中，我们可能使用类似 Cookies 的技术来实现类似的功能，包括：" : "In mobile applications, we may use cookie-like technologies to achieve similar functions, including:",
                        isChinese ? "• 应用内标识符：用于识别应用安装和用户会话。" : "• In-App Identifiers: Used to identify app installations and user sessions.",
                        isChinese ? "• 设备 ID：用于识别设备，提供个性化服务。" : "• Device IDs: Used to identify devices and provide personalized services.",
                        isChinese ? "• 广告标识符：用于提供相关广告（如果适用）。" : "• Advertising Identifiers: Used to provide relevant advertising (if applicable).",
                        isChinese ? "这些技术的使用遵循我们的《隐私通知》的规定。您可以通过应用设置或设备设置管理这些技术。" : "The use of these technologies follows the provisions of our Privacy Notice. You can manage these technologies through app settings or device settings."
                    ]
                )
                
                // 7. 您的权利
                CookieSection(
                    title: isChinese ? "7. 您的权利" : "7. Your Rights",
                    content: [
                        isChinese ? "根据 UK GDPR 和 PECR，您对 Cookies 享有以下权利：" : "Under UK GDPR and PECR, you have the following rights regarding cookies:",
                        isChinese ? "• 知情权：您有权了解我们使用哪些 Cookies 以及为什么使用它们。" : "• Right to Information: You have the right to know which cookies we use and why we use them.",
                        isChinese ? "• 同意权：对于非必要的 Cookies，您有权选择是否同意使用。" : "• Right to Consent: For non-essential cookies, you have the right to choose whether to consent to their use.",
                        isChinese ? "• 撤回同意权：您可以随时撤回对非必要 Cookies 的同意。" : "• Right to Withdraw Consent: You can withdraw your consent to non-essential cookies at any time.",
                        isChinese ? "• 删除权：您可以随时删除存储在您设备上的 Cookies。" : "• Right to Deletion: You can delete cookies stored on your device at any time.",
                        isChinese ? "• 访问权：您可以请求访问我们通过 Cookies 收集的您的个人数据。" : "• Right of Access: You can request access to your personal data collected through cookies.",
                        isChinese ? "如果您想行使这些权利，请通过 info@link2ur.com 联系我们。" : "If you wish to exercise these rights, please contact us at info@link2ur.com."
                    ]
                )
                
                // 8. 联系我们
                CookieSection(
                    title: isChinese ? "8. 联系我们" : "8. Contact Us",
                    content: [
                        isChinese ? "如果您对本 Cookie 政策有任何疑问或需要帮助管理您的 Cookie 偏好，请通过以下方式联系我们：" : "If you have any questions about this Cookie Policy or need help managing your cookie preferences, please contact us:",
                        isChinese ? "• 电子邮件：info@link2ur.com" : "• Email: info@link2ur.com",
                        isChinese ? "• 通讯地址：A3, B16 9NB, UK" : "• Mailing Address: A3, B16 9NB, UK",
                        isChinese ? "我们会在合理的时间内回复您的询问。" : "We will respond to your inquiries within a reasonable time."
                    ]
                )
                
                // 重要提示
                InfoBox(
                    title: isChinese ? "重要提示" : "Important Notice",
                    content: [
                        isChinese ? "本 Cookie 政策可能会不时更新。我们会在政策更新时通知您，并在本页面上发布更新后的版本。我们建议您定期查看本政策以了解最新信息。" : "This Cookie Policy may be updated from time to time. We will notify you when the policy is updated and publish the updated version on this page. We recommend that you review this policy regularly to stay informed.",
                        isChinese ? "最后更新日期：2025年10月10日" : "Last Updated: October 10, 2025"
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
        }
        .navigationTitle(isChinese ? "Cookie 政策" : "Cookie Policy")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { loadLegal() }
        .onChange(of: legalLang) { _ in loadLegal() }
    }

    private func loadLegal() {
        legalCancellable = APIService.shared.getLegalDocument(type: "cookie", lang: legalLang)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { legalDoc = $0 }
            )
    }
}

struct CookieSection: View {
    let title: String
    let content: [String]
    
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
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

#Preview {
    NavigationView {
        CookiePolicyView()
    }
}
