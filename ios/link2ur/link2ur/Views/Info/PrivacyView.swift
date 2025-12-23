import SwiftUI

struct PrivacyView: View {
    @Environment(\.locale) var locale
    private var isChinese: Bool {
        if #available(iOS 16, *) {
            return locale.language.languageCode?.identifier == "zh"
        } else {
            return locale.languageCode == "zh"
        }
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
                        isChinese ? "Zixiong Zhang（trading as \"Link²Ur\"）" : "Zixiong Zhang (trading as \"Link²Ur\")",
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
                    title: "Cookies",
                    items: [
                        (isChinese ? "必要 Cookies：为站点运行所必需。" : "Necessary Cookies: Essential for site operation.", nil),
                        (isChinese ? "分析/功能性 Cookies（可选）：仅在您明确同意后启用；您可随时在 Cookie 横幅或设置中更改偏好。" : "Analytics/Functional Cookies (Optional): Only enabled after your explicit consent; you can change preferences at any time in the Cookie banner or settings.", nil)
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
