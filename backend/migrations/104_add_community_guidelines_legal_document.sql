-- 迁移 104：添加法律文档新章节（达人条款、AI条款、VIP条款、注销政策、学生认证）+ 社区准则
-- 依赖：076（legal_documents 表）、077/078（terms/privacy 已有 content_json）
-- 通过 jsonb 合并追加新章节到现有文档，幂等；社区准则为新插入

-- zh 用户协议：追加达人条款、AI条款、VIP条款、注销政策、学生认证条款
UPDATE legal_documents
SET content_json = content_json || $TERMS_ZH$
{
  "expertTerms": {
    "title": "任务达人服务条款",
    "intro": "任务达人是经 Link²Ur 平台认证的优秀用户，在特定领域具备专业技能和丰富经验，能够为任务发布者提供高质量、可靠的服务。本条款适用于所有已获得或正在申请任务达人资格的用户，应与《用户协议》其他条款一并阅读。",
    "certificationRequirements": "认证要求与流程：（1）申请资格：用户须满足平台公示的基本条件（如完成一定数量的任务、获得良好评价等），方可申请任务达人认证。（2）申请材料：用户须在个人资料页面提交申请，并提供相关证明材料，包括但不限于：技能证书、作品集、工作经历证明、学历证明等。（3）平台审核：平台将对申请材料进行审核，审核周期通常为 5-10 个工作日。平台有权要求补充材料或进行面试。（4）认证结果：审核通过后，用户将获得任务达人认证徽章，并享受达人专属特权。平台有权拒绝不符合条件的申请，且无需说明具体理由。",
    "expertLevels": "达人等级：平台设有多个达人等级（如普通达人、VIP 达人、超级达人等），具体等级划分标准与权益以平台公示为准。等级可能根据用户的服务表现、评价、任务完成量等因素动态调整。",
    "obligations": "达人义务：（1）服务质量保证：达人应确保提供的服务达到平台公示的质量标准，按时、按质完成所接受的任务。（2）信息真实性：达人须确保认证材料和个人资料真实、准确、完整，不得伪造或夸大资质。（3）专业行为：达人在服务过程中应保持专业态度，遵守行业规范和职业道德，不得从事欺诈、误导或损害用户利益的行为。（4）响应时效：达人应在平台规定的时间内响应任务发布者的咨询和沟通，及时更新任务进展。（5）合规运营：达人须遵守所有适用的法律法规，确保其提供的服务合法合规。（6）保密义务：达人对在服务过程中获知的用户信息和商业秘密负有保密义务，不得泄露或用于其他目的。",
    "serviceStandards": "服务标准：（1）达人应按照任务描述和双方约定的标准完成任务，如有偏差应及时与任务发布者沟通协商。（2）达人不得在服务过程中向用户推销与任务无关的产品或服务。（3）达人不得利用达人身份引导用户进行站外交易或线下自行协商。（4）达人应积极配合平台的争议处理和退款审核流程。",
    "feesAndCommission": "费用与佣金：达人适用的服务费率可能与普通用户不同，具体费率以平台公示为准。平台可能根据达人等级、任务类型等因素设定差异化的服务费率。达人通过平台获取的收入须自行承担相关税费责任（详见本协议第 8 条「用户责任与义务」中的「税务责任」）。",
    "multiPersonTasks": "多人任务规则：（1）达人可通过平台发布多人任务（活动），招募多名参与者共同完成。（2）达人作为多人任务的发布者，对任务的组织、协调和质量负主要责任。（3）多人任务的支付、退款和争议处理适用本协议第 5 条「支付与退款」的相关规定。（4）达人应在多人任务发布时明确任务要求、时间、地点、人数限制、费用分摊等关键信息。（5）参与者因故退出多人任务的，按平台公示的退出规则处理。",
    "revocation": "资格撤销与降级：有以下情形之一的，平台有权撤销或降低达人资格：（1）提供虚假认证材料或信息。（2）服务质量持续不达标，多次收到差评或投诉。（3）违反本协议或平台规则。（4）收到严重的用户投诉或涉及欺诈、违法行为。（5）长期不活跃（具体标准以平台公示为准）。资格撤销后，达人的认证徽章和专属特权将被取消，已进行中的任务不受影响，但不得接受新任务。达人可在符合条件后重新申请认证。",
    "disclaimer": "达人免责声明：平台对达人的认证仅表示该用户在申请时满足平台设定的基本条件，不构成对达人服务质量、专业能力或可靠性的担保或背书。用户在选择达人服务时应自行评估风险。平台不对达人提供的服务结果、质量或因达人服务导致的任何损失承担责任。"
  },
  "aiServiceTerms": {
    "title": "AI 助手服务条款",
    "intro": "Link²Ur 平台提供 AI 智能助手「Linker」服务（以下简称「AI 助手」），帮助用户查询任务状态、搜索任务、了解平台规则、查看积分和优惠券、辅助发布任务等。使用 AI 助手即表示您同意本条款。",
    "natureOfService": "服务性质：AI 助手基于人工智能大语言模型技术，提供自动化的信息查询与辅助服务。AI 助手仅为辅助工具，不替代人工客服或专业建议。AI 助手的回答基于其训练数据和平台现有信息，可能存在不准确、不完整或过时的情况。",
    "accuracyDisclaimer": "准确性免责：AI 助手生成的内容仅供参考，不构成法律、金融、医疗或其他专业建议。平台不保证 AI 助手回答的准确性、完整性或时效性。用户不应仅依赖 AI 助手的回答做出重要决策。如 AI 助手提供的信息与平台官方公示或本协议条款不一致，以平台官方公示和本协议条款为准。",
    "recommendationDisclaimer": "推荐免责：AI 助手可能根据用户查询提供任务推荐或建议。此类推荐不构成平台对特定任务、用户或交易的背书或担保。用户应自行评估推荐内容的适用性和风险。",
    "taskAssistance": "任务辅助发布：AI 助手可辅助用户草拟任务发布内容。用户有责任在发布前审核和确认 AI 生成的任务内容，确保其真实、准确、合法。平台不对因用户未审核 AI 生成内容而产生的问题承担责任。",
    "dataHandling": "数据处理：AI 助手处理的用户对话数据用于提供和改进服务。平台不会将 AI 对话中的个人信息用于与服务无关的目的。AI 对话数据的存储与保护适用本平台《隐私通知》的相关规定。详见下方《隐私通知》中的「AI 助手数据」部分。",
    "limitations": "使用限制：用户不得利用 AI 助手生成违法、有害、欺诈性或违反平台规则的内容。用户不得尝试通过特殊提示或技巧绕过 AI 助手的安全限制。平台有权在不事先通知的情况下调整、暂停或终止 AI 助手服务。",
    "liability": "责任限制：平台不对因使用或无法使用 AI 助手服务造成的任何直接或间接损失承担责任，包括但不限于：因 AI 回答不准确导致的决策失误、因 AI 服务中断导致的不便、因 AI 推荐导致的交易纠纷。"
  },
  "vipSubscriptionTerms": {
    "title": "VIP 会员订阅条款",
    "intro": "Link²Ur 提供 VIP 会员订阅服务（以下简称「VIP 订阅」），为订阅用户提供专属权益和增值服务。本条款适用于所有购买或使用 VIP 订阅的用户。",
    "subscriptionMethod": "订阅方式：VIP 订阅通过 Apple App Store 的应用内购买（In-App Purchase）进行。订阅交易由 Apple 处理，适用 Apple 的付款条款和条件。平台不直接处理 VIP 订阅的支付。",
    "autoRenewal": "自动续期：VIP 订阅为自动续期订阅。订阅期满后将自动续期并收费，除非您在当前订阅期结束前至少 24 小时取消。自动续期的费用将按您订阅时的价格收取，除非平台提前通知价格变更。",
    "cancellation": "取消订阅：您可以随时通过以下方式取消 VIP 订阅：（1）在 iPhone/iPad 上：设置 → Apple ID → 订阅 → 找到 Link²Ur VIP → 取消订阅。（2）取消后，您的 VIP 权益将持续至当前已付费订阅期结束。（3）取消订阅不会对已付费的当前订阅期进行退款。",
    "priceChanges": "价格变更：平台保留调整 VIP 订阅价格的权利。价格变更将提前通知用户（通过应用内通知或邮件）。价格变更仅在您续费时生效；如果您不接受新价格，可在续费前取消订阅。",
    "benefits": "VIP 权益：VIP 会员可享受的权益包括但不限于：任务展示优先、专属客服通道、特定功能解锁等。具体权益内容以平台在应用内公示为准，平台有权根据运营需要调整 VIP 权益内容，调整后将通过公示或通知方式告知用户。",
    "limitations": "权益限制：VIP 权益仅限订阅用户本人使用，不可转让、赠送或共享。VIP 身份不影响用户遵守本协议其他条款的义务。VIP 权益不包括对平台上任何任务或交易结果的担保。平台可能对不同 VIP 等级设定不同权益，具体以平台公示为准。",
    "refund": "退款政策：VIP 订阅的退款适用 Apple App Store 的退款政策。如需申请退款，请联系 Apple 支持或通过 Apple 官方渠道办理。平台无法直接处理通过 App Store 购买的 VIP 订阅退款。",
    "trialPeriod": "免费试用（如适用）：平台可能不时提供 VIP 免费试用。试用期结束后，如未取消订阅，将自动转为付费订阅并按公示价格收费。每位用户仅可享受一次免费试用。",
    "termination": "终止：如用户违反本协议或平台规则，平台有权终止其 VIP 订阅，且不予退款。VIP 订阅终止后，用户的 VIP 权益将立即失效。"
  },
  "accountDeletion": {
    "title": "账户注销政策",
    "intro": "根据 UK GDPR 及相关法规，您有权请求删除您的账户和个人数据。本条款说明账户注销的流程、条件和后果。",
    "process": "注销流程：（1）您可通过应用内「设置 → 删除账户」功能或发送邮件至 info@link2ur.com 申请注销账户。（2）提交注销申请后，平台将在 30 天内处理您的请求（如需验证身份，可能需要额外时间）。（3）在此期间，您可以随时撤回注销申请。（4）注销处理完成后，您将收到确认通知。",
    "conditions": "注销条件：在以下情况下，账户注销可能被暂时推迟或部分限制：（1）您有正在进行中的任务（已支付但未完成）。（2）您有未结清的退款申请或争议。（3）您的账户有未结清的应收/应付款项。（4）您的账户正在接受平台调查或涉及法律程序。上述事项处理完毕后，即可继续注销流程。",
    "consequences": "注销后果：账户注销后：（1）您将无法登录或访问该账户。（2）您发布的任务、评价、论坛帖子等公开内容可能被匿名化处理或删除。（3）您的积分、优惠券、VIP 权益等将永久失效且不可恢复。（4）您的个人数据将按《隐私通知》的数据保留政策处理（详见下方「数据保留」说明）。（5）已完成的交易记录将根据法律要求保留必要期限后删除。",
    "dataRetention": "数据保留：即使账户注销后，以下数据可能根据法律要求继续保留：（1）交易和支付记录：根据英国税务和会计法规，最长保留 6 年。（2）争议处理记录：保留至争议完全解决后的合理期限。（3）安全日志：按风险等级保留最短必要期限。（4）匿名化的统计数据：可能永久保留用于平台运营分析，但无法关联到您个人。其他个人数据将在注销处理完成后 30 天内删除或匿名化。",
    "reRegistration": "重新注册：账户注销后，您可以使用同一邮箱重新注册新账户，但原账户的数据、积分、评价记录等不可恢复。"
  },
  "studentVerificationTerms": {
    "title": "学生认证条款",
    "intro": "Link²Ur 提供学生身份认证功能，验证用户的学生身份以获取学生专属标识和相关权益。使用学生认证功能即表示您同意本条款。",
    "verificationProcess": "认证流程：（1）用户须提供有效的学校/大学教育邮箱（.ac.uk 或其他受认可的教育域名邮箱）进行验证。（2）平台将向该邮箱发送验证链接或验证码，用户完成验证即获得学生认证身份。（3）平台可能要求补充其他证明材料（如学生证照片等）以确认学生身份的真实性。",
    "dataCollection": "数据收集与使用：为完成学生认证，平台将收集以下信息：（1）学校/大学教育邮箱地址。（2）关联的学校/大学名称。（3）验证时间和状态。上述信息仅用于验证学生身份、提供学生专属功能（如按学校分类的论坛）以及平台运营分析。详见《隐私通知》中的相关条款。",
    "obligations": "用户义务：（1）用户须确保提交的学生身份信息真实、准确。（2）用户不得使用他人的教育邮箱或伪造学生身份进行认证。（3）如用户的学生身份发生变化（如毕业、退学），应及时更新认证状态。",
    "falseVerification": "虚假认证后果：如发现用户提供虚假的学生身份信息：（1）平台将立即撤销学生认证标识。（2）平台可能限制或终止用户账户。（3）用户通过虚假学生身份获得的任何优惠或权益将被追回。（4）平台保留追究法律责任的权利。",
    "dataRetention": "数据保留：学生认证相关数据将在认证有效期内保留。认证过期或被撤销后，相关验证记录将根据平台数据保留政策处理。用户删除账户时，学生认证数据将一并删除（法律要求保留的除外）。",
    "validity": "认证有效期：学生认证可能设有有效期（具体以平台公示为准）。到期后用户可能需要重新验证以维持学生认证状态。"
  }
}
$TERMS_ZH$::jsonb,
    updated_at = NOW()
WHERE type = 'terms' AND lang = 'zh';

-- en 用户协议：追加达人条款、AI条款、VIP条款、注销政策、学生认证条款
UPDATE legal_documents
SET content_json = content_json || $TERMS_EN$
{
  "expertTerms": {
    "title": "Task Expert Service Terms",
    "intro": "Task Experts are outstanding users certified by the Link²Ur platform who possess professional skills and extensive experience in specific fields, capable of providing high-quality and reliable services to task posters. These terms apply to all users who have obtained or are applying for Task Expert qualification and should be read alongside other terms of this Agreement.",
    "certificationRequirements": "Certification Requirements and Process: (1) Eligibility: Users must meet the basic conditions published by the platform (such as completing a certain number of tasks, receiving good reviews, etc.) before they can apply for Task Expert certification. (2) Application Materials: Users must submit an application on their profile page and provide relevant supporting materials, including but not limited to: skill certificates, portfolios, work experience proof, educational credentials, etc. (3) Platform Review: The platform will review application materials, with a review period typically of 5-10 working days. The platform may request additional materials or conduct interviews. (4) Certification Result: After passing the review, users will receive the Task Expert certification badge and enjoy expert-exclusive privileges. The platform reserves the right to reject applications that do not meet the criteria without providing specific reasons.",
    "expertLevels": "Expert Levels: The platform offers multiple expert levels (such as Regular Expert, VIP Expert, Super Expert, etc.). Specific level classification criteria and benefits are subject to platform announcements. Levels may be dynamically adjusted based on factors such as service performance, reviews, and task completion volume.",
    "obligations": "Expert Obligations: (1) Service Quality Assurance: Experts shall ensure that their services meet the quality standards published by the platform, completing accepted tasks on time and to standard. (2) Information Accuracy: Experts must ensure that their certification materials and profile information are true, accurate, and complete; they must not forge or exaggerate qualifications. (3) Professional Conduct: Experts shall maintain a professional attitude during service, comply with industry standards and professional ethics, and must not engage in fraud, misleading or detrimental conduct. (4) Response Timeliness: Experts shall respond to task posters' enquiries and communications within the timeframes specified by the platform, and provide timely task progress updates. (5) Compliance: Experts must comply with all applicable laws and regulations to ensure their services are lawful and compliant. (6) Confidentiality: Experts have a duty of confidentiality regarding user information and business secrets obtained during the course of service, and must not disclose or use such information for other purposes.",
    "serviceStandards": "Service Standards: (1) Experts shall complete tasks according to the task description and standards agreed by both parties; any deviations should be promptly communicated and negotiated with the task poster. (2) Experts must not promote products or services unrelated to the task during the service process. (3) Experts must not use their expert status to guide users towards off-platform transactions or offline self-negotiation. (4) Experts shall actively cooperate with the platform's dispute resolution and refund review processes.",
    "feesAndCommission": "Fees and Commission: The service fee rates applicable to experts may differ from those for regular users; specific rates are subject to platform announcements. The platform may set differentiated service fee rates based on factors such as expert level and task type. Income obtained by experts through the platform is subject to their own tax responsibilities (see Section 8 'User Responsibilities and Obligations' — 'Tax Responsibility' of this Agreement).",
    "multiPersonTasks": "Multi-Person Task Rules: (1) Experts may publish multi-person tasks (activities) through the platform, recruiting multiple participants to complete together. (2) As the publisher of multi-person tasks, experts bear primary responsibility for task organisation, coordination, and quality. (3) Payment, refund, and dispute resolution for multi-person tasks are subject to Section 5 'Payment and Refund' of this Agreement. (4) Experts shall clearly specify key information when publishing multi-person tasks, including task requirements, time, location, participant limits, cost allocation, etc. (5) Participants who withdraw from multi-person tasks for any reason shall be handled according to the platform's published withdrawal rules.",
    "revocation": "Qualification Revocation and Demotion: The platform reserves the right to revoke or downgrade expert qualification in any of the following circumstances: (1) Providing false certification materials or information. (2) Persistently substandard service quality, with multiple negative reviews or complaints. (3) Violating this Agreement or platform rules. (4) Receiving serious user complaints or involvement in fraud or illegal activities. (5) Prolonged inactivity (specific criteria subject to platform announcements). After revocation, the expert's certification badge and exclusive privileges will be cancelled; tasks in progress will not be affected, but no new tasks may be accepted. Experts may reapply for certification after meeting the conditions.",
    "disclaimer": "Expert Disclaimer: Platform certification of experts only indicates that the user met the basic conditions set by the platform at the time of application, and does not constitute a guarantee or endorsement of the expert's service quality, professional capability, or reliability. Users should assess risks independently when choosing expert services. The platform is not liable for service outcomes, quality, or any losses caused by expert services."
  },
  "aiServiceTerms": {
    "title": "AI Assistant Service Terms",
    "intro": "The Link²Ur platform provides the AI assistant 'Linker' service (hereinafter 'AI Assistant'), which helps users check task status, search tasks, learn about platform rules, view points and coupons, and assist with task posting. By using the AI Assistant, you agree to these terms.",
    "natureOfService": "Nature of Service: The AI Assistant is based on large language model artificial intelligence technology, providing automated information enquiry and assistance services. The AI Assistant is an auxiliary tool only and does not replace human customer service or professional advice. The AI Assistant's responses are based on its training data and current platform information, and may be inaccurate, incomplete, or outdated.",
    "accuracyDisclaimer": "Accuracy Disclaimer: Content generated by the AI Assistant is for reference only and does not constitute legal, financial, medical, or other professional advice. The platform does not guarantee the accuracy, completeness, or timeliness of AI Assistant responses. Users should not rely solely on AI Assistant responses for important decisions. If information provided by the AI Assistant conflicts with official platform announcements or these terms, the official platform announcements and these terms shall prevail.",
    "recommendationDisclaimer": "Recommendation Disclaimer: The AI Assistant may provide task recommendations or suggestions based on user queries. Such recommendations do not constitute platform endorsement or guarantee of specific tasks, users, or transactions. Users should independently assess the suitability and risks of recommended content.",
    "taskAssistance": "Task Posting Assistance: The AI Assistant may help users draft task posting content. Users are responsible for reviewing and confirming AI-generated task content before posting, ensuring it is true, accurate, and lawful. The platform is not liable for issues arising from users failing to review AI-generated content.",
    "dataHandling": "Data Handling: User conversation data processed by the AI Assistant is used to provide and improve services. The platform will not use personal information from AI conversations for purposes unrelated to the service. Storage and protection of AI conversation data is subject to the relevant provisions of this platform's Privacy Notice. See the 'AI Assistant Data' section in the Privacy Notice below.",
    "limitations": "Usage Limitations: Users must not use the AI Assistant to generate illegal, harmful, fraudulent, or content that violates platform rules. Users must not attempt to bypass the AI Assistant's safety restrictions through special prompts or techniques. The platform reserves the right to adjust, suspend, or terminate the AI Assistant service without prior notice.",
    "liability": "Limitation of Liability: The platform is not liable for any direct or indirect losses arising from use of or inability to use the AI Assistant service, including but not limited to: decision errors caused by inaccurate AI responses, inconvenience caused by AI service interruptions, or transaction disputes caused by AI recommendations."
  },
  "vipSubscriptionTerms": {
    "title": "VIP Membership Subscription Terms",
    "intro": "Link²Ur offers a VIP membership subscription service (hereinafter 'VIP Subscription'), providing exclusive benefits and value-added services to subscribing users. These terms apply to all users who purchase or use VIP Subscription.",
    "subscriptionMethod": "Subscription Method: VIP Subscription is purchased through Apple App Store In-App Purchase. The subscription transaction is processed by Apple and is subject to Apple's payment terms and conditions. The platform does not directly process VIP Subscription payments.",
    "autoRenewal": "Auto-Renewal: VIP Subscription is an auto-renewable subscription. The subscription will automatically renew and charge at the end of each subscription period, unless you cancel at least 24 hours before the end of the current subscription period. Auto-renewal fees will be charged at the price at which you subscribed, unless the platform provides advance notice of a price change.",
    "cancellation": "Cancellation: You may cancel your VIP Subscription at any time via the following methods: (1) On iPhone/iPad: Settings → Apple ID → Subscriptions → Find Link²Ur VIP → Cancel Subscription. (2) After cancellation, your VIP benefits will continue until the end of the current paid subscription period. (3) Cancelling the subscription will not result in a refund for the current paid subscription period.",
    "priceChanges": "Price Changes: The platform reserves the right to adjust VIP Subscription pricing. Price changes will be notified to users in advance (via in-app notification or email). Price changes will only take effect upon renewal; if you do not accept the new price, you may cancel the subscription before renewal.",
    "benefits": "VIP Benefits: Benefits available to VIP members include but are not limited to: priority task listing, exclusive customer service channels, unlocking specific features, etc. Specific benefit content is subject to platform announcements within the app; the platform reserves the right to adjust VIP benefit content based on operational needs, and changes will be communicated to users via announcements or notifications.",
    "limitations": "Benefit Limitations: VIP benefits are for the personal use of the subscribing user only and may not be transferred, gifted, or shared. VIP status does not affect the user's obligation to comply with other terms of this Agreement. VIP benefits do not include any guarantee regarding the outcome of any task or transaction on the platform. The platform may set different benefits for different VIP tiers; specifics are subject to platform announcements.",
    "refund": "Refund Policy: Refunds for VIP Subscription are subject to the Apple App Store refund policy. To request a refund, please contact Apple Support or apply through Apple's official channels. The platform cannot directly process refunds for VIP Subscriptions purchased through the App Store.",
    "trialPeriod": "Free Trial (if applicable): The platform may from time to time offer free VIP trials. After the trial period ends, if the subscription is not cancelled, it will automatically convert to a paid subscription and be charged at the published price. Each user may only enjoy one free trial.",
    "termination": "Termination: If a user violates this Agreement or platform rules, the platform reserves the right to terminate their VIP Subscription without refund. After VIP Subscription termination, the user's VIP benefits will cease immediately."
  },
  "accountDeletion": {
    "title": "Account Deletion Policy",
    "intro": "Under UK GDPR and related regulations, you have the right to request deletion of your account and personal data. These terms explain the process, conditions, and consequences of account deletion.",
    "process": "Deletion Process: (1) You may request account deletion through the in-app 'Settings → Delete Account' function or by sending an email to info@link2ur.com. (2) After submitting a deletion request, the platform will process your request within 30 days (additional time may be needed for identity verification). (3) During this period, you may withdraw your deletion request at any time. (4) Once deletion processing is complete, you will receive a confirmation notification.",
    "conditions": "Deletion Conditions: Account deletion may be temporarily delayed or partially restricted in the following circumstances: (1) You have tasks in progress (paid but not completed). (2) You have outstanding refund requests or disputes. (3) Your account has unsettled receivable/payable amounts. (4) Your account is under platform investigation or involved in legal proceedings. Once these matters are resolved, the deletion process may continue.",
    "consequences": "Consequences of Deletion: After account deletion: (1) You will be unable to log in or access the account. (2) Tasks, reviews, forum posts, and other public content you posted may be anonymised or deleted. (3) Your points, coupons, VIP benefits, etc. will be permanently invalidated and cannot be recovered. (4) Your personal data will be handled in accordance with the Privacy Notice's data retention policy (see 'Data Retention' below). (5) Completed transaction records will be retained for the legally required period before deletion.",
    "dataRetention": "Data Retention: Even after account deletion, the following data may continue to be retained as required by law: (1) Transaction and payment records: Up to 6 years under UK tax and accounting regulations. (2) Dispute resolution records: Retained for a reasonable period after the dispute is fully resolved. (3) Security logs: Retained for the minimum necessary period based on risk level. (4) Anonymised statistical data: May be permanently retained for platform operational analysis, but cannot be linked to you personally. Other personal data will be deleted or anonymised within 30 days after deletion processing is complete.",
    "reRegistration": "Re-registration: After account deletion, you may register a new account using the same email, but data, points, review records, etc. from the original account cannot be recovered."
  },
  "studentVerificationTerms": {
    "title": "Student Verification Terms",
    "intro": "Link²Ur provides a student identity verification feature to verify users' student status and grant student-specific badges and related benefits. By using the student verification feature, you agree to these terms.",
    "verificationProcess": "Verification Process: (1) Users must provide a valid school/university educational email (.ac.uk or other recognised educational domain email) for verification. (2) The platform will send a verification link or code to that email; completing verification grants student-verified status. (3) The platform may request additional supporting materials (such as student ID photos) to confirm the authenticity of student identity.",
    "dataCollection": "Data Collection and Use: To complete student verification, the platform collects the following information: (1) School/university educational email address. (2) Associated school/university name. (3) Verification time and status. This information is used solely for verifying student identity, providing student-specific features (such as school-based forum categories), and platform operational analysis. See the relevant provisions in the Privacy Notice.",
    "obligations": "User Obligations: (1) Users must ensure that submitted student identity information is true and accurate. (2) Users must not use another person's educational email or forge student identity for verification. (3) If a user's student status changes (e.g. graduation, withdrawal), they should promptly update their verification status.",
    "falseVerification": "Consequences of False Verification: If a user is found to have provided false student identity information: (1) The platform will immediately revoke the student verification badge. (2) The platform may restrict or terminate the user's account. (3) Any benefits or privileges obtained through false student identity will be reclaimed. (4) The platform reserves the right to pursue legal action.",
    "dataRetention": "Data Retention: Student verification data is retained for the duration of verification validity. After verification expires or is revoked, related verification records will be handled according to the platform's data retention policy. When a user deletes their account, student verification data will be deleted accordingly (except where retention is legally required).",
    "validity": "Verification Validity: Student verification may have an expiry period (specific terms subject to platform announcements). After expiry, users may need to re-verify to maintain student-verified status."
  }
}
$TERMS_EN$::jsonb,
    updated_at = NOW()
WHERE type = 'terms' AND lang = 'en';

-- zh 隐私通知 dataCollection.aiChatData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{dataCollection,aiChatData}', '"AI 助手数据：当您使用平台 AI 助手「Linker」时，我们收集您的对话内容、查询记录和交互数据。这些数据用于：（1）提供和改进 AI 助手服务；（2）优化回答质量；（3）保障服务安全。AI 对话数据通常保留不超过 12 个月，或直到您删除对话记录。我们不会将 AI 对话中的个人信息单独提取用于营销或与第三方共享（合同履行/合法利益）。"'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'zh';

-- zh 隐私通知 dataCollection.studentVerificationData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{dataCollection,studentVerificationData}', '"学生认证数据：当您使用学生认证功能时，我们收集您的教育邮箱地址和关联学校/大学名称。这些数据仅用于验证学生身份、提供按学校分类的社区论坛功能以及平台运营分析。学生认证数据在认证有效期内保留，账户注销时一并删除（合同履行/合法利益）。"'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'zh';

-- zh 隐私通知 retentionPeriod.aiChatData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{retentionPeriod,aiChatData}', '"AI 助手对话数据：通常保留不超过 12 个月，或直到用户主动删除对话记录。"'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'zh';

-- zh 隐私通知 retentionPeriod.studentVerificationData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{retentionPeriod,studentVerificationData}', '"学生认证数据：认证有效期内保留，认证过期或账户注销后按平台数据保留政策处理。"'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'zh';

-- zh 隐私通知 yourRights.accountDeletion
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{yourRights,accountDeletion}', '"账户注销与数据删除：您有权随时请求删除您的账户和个人数据。您可通过应用内「设置 → 删除账户」功能或发送邮件至 info@link2ur.com 提出请求。我们将在 30 天内处理您的请求。注销后，您的个人数据将被删除或匿名化，但依法需要保留的数据除外（如交易记录最长保留 6 年）。详见《用户协议》中的「账户注销政策」。"'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'zh';

-- en 隐私通知 dataCollection.aiChatData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{dataCollection,aiChatData}', '"AI Assistant Data: When you use the platform AI assistant ‘Linker’, we collect your conversation content, query records, and interaction data. This data is used for: (1) Providing and improving the AI assistant service; (2) Optimising response quality; (3) Ensuring service security. AI conversation data is typically retained for no more than 12 months, or until you delete the conversation records. We do not separately extract personal information from AI conversations for marketing or sharing with third parties (contract performance/legitimate interests)."'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'en';

-- en 隐私通知 dataCollection.studentVerificationData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{dataCollection,studentVerificationData}', '"Student Verification Data: When you use the student verification feature, we collect your educational email address and associated school/university name. This data is used solely for verifying student identity, providing school-based community forum features, and platform operational analysis. Student verification data is retained for the duration of verification validity and deleted when the account is deleted (contract performance/legitimate interests)."'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'en';

-- en 隐私通知 retentionPeriod.aiChatData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{retentionPeriod,aiChatData}', '"AI Assistant Conversation Data: Typically retained for no more than 12 months, or until the user actively deletes conversation records."'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'en';

-- en 隐私通知 retentionPeriod.studentVerificationData
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{retentionPeriod,studentVerificationData}', '"Student Verification Data: Retained for the duration of verification validity; handled according to platform data retention policy after verification expires or account is deleted."'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'en';

-- en 隐私通知 yourRights.accountDeletion
UPDATE legal_documents
SET content_json = jsonb_set(content_json, '{yourRights,accountDeletion}', '"Account Deletion and Data Erasure: You have the right to request deletion of your account and personal data at any time. You may submit a request via the in-app ''Settings → Delete Account'' function or by emailing info@link2ur.com. We will process your request within 30 days. After deletion, your personal data will be deleted or anonymised, except for data that must be retained by law (e.g. transaction records retained for up to 6 years). See ''Account Deletion Policy'' in the Terms of Service for details."'::jsonb),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'en';

-- zh 社区准则：完整插入
INSERT INTO legal_documents (type, lang, content_json, version, effective_at)
VALUES ('community_guidelines', 'zh', $CG_ZH$
{
  "title": "社区准则",
  "version": "版本：v1.0",
  "effectiveDate": "生效日期：2026年3月",
  "intro": {
    "title": "概述",
    "p1": "Link²Ur 社区准则旨在为所有用户营造安全、友好、互助的平台环境。本准则适用于平台上所有用户生成内容，包括但不限于：社区论坛帖子与回复、任务描述与评价、跳蚤市场商品信息、用户个人资料、站内消息及所有公开展示的内容。",
    "p2": "使用 Link²Ur 平台即表示您同意遵守本社区准则。违反准则可能导致内容删除、功能限制或账户封禁。"
  },
  "contentStandards": {
    "title": "1. 内容标准",
    "respectful": "1.1 尊重他人：（1）对待所有用户应保持礼貌和尊重。（2）禁止人身攻击、侮辱、嘲讽或贬低他人。（3）禁止基于种族、民族、国籍、性别、性取向、宗教、残疾、年龄或其他受保护特征的歧视性言论。（4）禁止骚扰、跟踪、威胁或恐吓他人。",
    "truthful": "1.2 真实可信：（1）禁止发布虚假、误导或欺诈性信息。（2）任务描述和商品信息须真实、准确、完整。（3）评价须基于真实的交易或服务体验。（4）禁止冒充他人身份或组织。",
    "legal": "1.3 合法合规：（1）禁止发布违反英国法律法规或国际法的内容。（2）禁止发布侵犯他人知识产权（版权、商标、专利等）的内容。（3）禁止发布侵犯他人隐私、肖像权等合法权益的内容。（4）禁止发布色情、暴力、恐怖主义或其他极端内容。",
    "safe": "1.4 安全健康：（1）禁止发布可能危害用户人身安全的内容或信息。（2）禁止发布危险品制造方法、毒品信息或其他有害指导。（3）禁止发布可能导致自残或伤害他人的内容。（4）禁止发布传播疫情谣言或其他危害公共健康的虚假信息。"
  },
  "forumRules": {
    "title": "2. 论坛行为规范",
    "posting": "2.1 发帖规范：（1）帖子应发布在相应的学校/大学分区，不得跨区灌水。（2）帖子标题应清晰反映内容，不得使用误导性标题（标题党）。（3）同一内容不得在多个分区重复发布。（4）帖子内容应有实质性，避免无意义灌水。",
    "replying": "2.2 回复规范：（1）回复应与帖子主题相关。（2）禁止刷屏、灌水或发布无意义回复。（3）对不同意见应理性讨论，不得进行人身攻击。",
    "prohibited": "2.3 论坛禁止行为：（1）发布商业广告或推销信息（除指定板块外）。（2）引导用户添加外部联系方式进行交易。（3）发布考试答案、作业代写等学术不诚信内容。（4）发布涉及个人隐私的信息（如未经同意公开他人照片、联系方式等）。（5）组织或参与恶意刷帖、控评等行为。"
  },
  "taskAndMarketRules": {
    "title": "3. 任务与交易行为规范",
    "taskPosting": "3.1 任务发布：（1）任务描述应清晰、详细，包含必要的要求、时间和报酬信息。（2）任务报酬应合理，不得低于法律最低标准（如适用）。（3）禁止发布违反法律法规的任务（详见《用户协议》第 6 条「禁止的任务类型」）。",
    "taskExecution": "3.2 任务执行：（1）任务接受者应按约定完成任务，保证服务质量。（2）双方应通过平台内消息保持沟通，及时反馈进展。（3）出现问题应及时协商解决，避免单方面放弃。",
    "fleaMarket": "3.3 跳蚤市场：（1）商品信息须真实准确，不得隐瞒重要缺陷。（2）禁止发布假冒伪劣、侵权或违禁商品。（3）须在平台内沟通，不得引导站外交易。",
    "reviews": "3.4 评价规范：（1）评价应基于真实体验，客观公正。（2）禁止虚假好评、恶意差评或组织刷评。（3）评价中不得包含人身攻击或不实指控。（4）禁止以差评威胁对方或以好评进行交易。"
  },
  "moderation": {
    "title": "4. 内容审核机制",
    "methods": "4.1 审核方式：平台采用自动审核与人工审核相结合的方式。自动审核系统会实时检测明显违规内容。人工审核团队会处理用户举报和复杂情况。平台保留对所有用户生成内容进行审核的权利。",
    "timeline": "4.2 审核时效：对用户举报的内容，平台通常在 24-72 小时内完成审核。紧急情况（如涉及人身安全威胁）将优先处理。审核结果将通过站内消息或邮件通知。",
    "transparency": "4.3 审核透明：如内容被删除或限制，平台将告知具体原因和依据的准则条款。用户可对审核决定提出申诉（见下方「申诉流程」）。"
  },
  "reporting": {
    "title": "5. 举报机制",
    "howToReport": "5.1 如何举报：（1）在违规内容旁点击「举报」按钮。（2）选择举报原因类别（如骚扰、虚假信息、违法内容等）。（3）提供补充说明和证据（可选但建议提供）。（4）提交后平台将在 24-72 小时内处理。",
    "reportCategories": "5.2 举报类别：可举报的内容包括：骚扰或人身攻击、虚假或误导信息、违法或有害内容、垃圾信息或广告、侵犯知识产权、侵犯隐私、歧视或仇恨言论、欺诈或诈骗、其他违反社区准则的行为。",
    "protection": "5.3 举报人保护：举报人的身份信息将严格保密，平台不会向被举报人透露举报人身份。禁止对举报人进行报复，如发现报复行为将严肃处理。",
    "falseReporting": "5.4 恶意举报：禁止恶意或虚假举报。多次恶意举报的用户将被限制举报功能或受到其他处罚。"
  },
  "enforcement": {
    "title": "6. 违规处理",
    "levels": "6.1 处罚等级：平台根据违规严重程度和频次采取以下处罚措施：",
    "warning": "• 提醒/警告：首次轻微违规，平台将发送提醒通知，要求用户了解并遵守相关准则。",
    "contentRemoval": "• 内容删除：违规内容将被删除，用户收到通知说明删除原因。",
    "temporaryRestriction": "• 临时限制：重复违规或较严重违规，平台可暂时限制用户的部分功能（如发帖、评论、发布任务等），限制时长视情况而定（通常为 1-30 天）。",
    "accountSuspension": "• 账户暂停：严重违规或多次重复违规，平台可暂停用户账户一段时间（通常为 7-90 天）。",
    "permanentBan": "• 永久封禁：极其严重的违规行为（如涉及违法犯罪、严重欺诈、持续恶意行为等），平台将永久封禁用户账户。",
    "legalAction": "• 法律追究：涉及违法犯罪的，平台保留向相关执法机构报告并配合调查的权利。",
    "factors": "6.2 处罚考量因素：违规的严重程度、违规的频次和历史记录、违规行为对其他用户的影响、用户的配合态度和改正表现。"
  },
  "appeals": {
    "title": "7. 申诉流程",
    "process": "7.1 申诉方式：（1）如果您认为您的内容被错误删除或账户被错误处罚，可在收到通知后 14 天内提出申诉。（2）通过应用内「帮助与反馈」功能提交申诉，或发送邮件至 info@link2ur.com。（3）申诉中请说明您认为处罚不当的理由，并提供相关证据。",
    "review": "7.2 申诉审核：（1）平台将在收到申诉后 7 个工作日内完成审核。（2）申诉将由与原审核人员不同的团队成员进行独立审核。（3）审核结果将通过站内消息或邮件通知申诉人。",
    "outcome": "7.3 申诉结果：（1）如申诉成功，被删除的内容将恢复，相关处罚将撤销。（2）如申诉不成功，原处罚维持不变，平台将说明维持原决定的理由。（3）每项处罚仅可申诉一次。如对最终结果有异议，可通过法律途径解决。"
  },
  "updates": {
    "title": "8. 准则更新",
    "content": "平台可能根据法律法规变化、平台运营需要或用户反馈不时更新本社区准则。重大更新将通过应用内通知或邮件告知用户。继续使用平台即表示接受更新后的准则。"
  },
  "contactUs": {
    "title": "9. 联系我们",
    "content": "如对本社区准则有疑问或需要帮助，请通过以下方式联系我们：\n• 电子邮件：info@link2ur.com\n• 应用内「帮助与反馈」功能"
  }
}
$CG_ZH$::jsonb, 'v1.0', '2026-03-01')
ON CONFLICT (type, lang) DO UPDATE SET
    content_json = EXCLUDED.content_json,
    version = EXCLUDED.version,
    effective_at = EXCLUDED.effective_at,
    updated_at = NOW();

-- en 社区准则：完整插入
INSERT INTO legal_documents (type, lang, content_json, version, effective_at)
VALUES ('community_guidelines', 'en', $CG_EN$
{
  "title": "Community Guidelines",
  "version": "Version: v1.0",
  "effectiveDate": "Effective Date: March 2026",
  "intro": {
    "title": "Overview",
    "p1": "The Link²Ur Community Guidelines aim to create a safe, friendly, and collaborative platform environment for all users. These guidelines apply to all user-generated content on the platform, including but not limited to: community forum posts and replies, task descriptions and reviews, flea market item listings, user profiles, in-platform messages, and all publicly displayed content.",
    "p2": "By using the Link²Ur platform, you agree to abide by these Community Guidelines. Violations may result in content removal, feature restrictions, or account suspension."
  },
  "contentStandards": {
    "title": "1. Content Standards",
    "respectful": "1.1 Respectful Communication: (1) Treat all users with courtesy and respect. (2) Personal attacks, insults, mockery, or belittling others are prohibited. (3) Discriminatory speech based on race, ethnicity, nationality, gender, sexual orientation, religion, disability, age, or other protected characteristics is prohibited. (4) Harassment, stalking, threats, or intimidation of others is prohibited.",
    "truthful": "1.2 Truthfulness: (1) Publishing false, misleading, or fraudulent information is prohibited. (2) Task descriptions and product listings must be true, accurate, and complete. (3) Reviews must be based on genuine transaction or service experiences. (4) Impersonating another person or organisation is prohibited.",
    "legal": "1.3 Legal Compliance: (1) Publishing content that violates UK law or international law is prohibited. (2) Publishing content that infringes others' intellectual property rights (copyright, trademarks, patents, etc.) is prohibited. (3) Publishing content that infringes others' privacy, image rights, or other lawful rights is prohibited. (4) Publishing pornographic, violent, terrorist, or other extreme content is prohibited.",
    "safe": "1.4 Safety and Wellbeing: (1) Publishing content or information that may endanger users' personal safety is prohibited. (2) Publishing methods for manufacturing dangerous goods, drug information, or other harmful instructions is prohibited. (3) Publishing content that may lead to self-harm or harm to others is prohibited. (4) Publishing false information that spreads health misinformation or other content harmful to public health is prohibited."
  },
  "forumRules": {
    "title": "2. Forum Conduct Rules",
    "posting": "2.1 Posting Standards: (1) Posts should be published in the appropriate school/university section; cross-posting spam is not allowed. (2) Post titles should clearly reflect the content; misleading clickbait titles are prohibited. (3) The same content must not be repeatedly posted across multiple sections. (4) Post content should be substantive; meaningless spam posts are to be avoided.",
    "replying": "2.2 Reply Standards: (1) Replies should be relevant to the post topic. (2) Spamming, flooding, or posting meaningless replies is prohibited. (3) Disagreements should be discussed rationally; personal attacks are not permitted.",
    "prohibited": "2.3 Prohibited Forum Behaviour: (1) Posting commercial advertisements or promotional content (except in designated sections). (2) Guiding users to add external contact details for transactions. (3) Posting exam answers, assignment ghostwriting, or other academic dishonesty content. (4) Posting personal private information (such as publishing others' photos or contact details without consent). (5) Organising or participating in malicious mass posting or review manipulation."
  },
  "taskAndMarketRules": {
    "title": "3. Task and Transaction Conduct Rules",
    "taskPosting": "3.1 Task Posting: (1) Task descriptions should be clear and detailed, including necessary requirements, timing, and compensation information. (2) Task compensation should be reasonable and must not be below legal minimum standards (where applicable). (3) Posting tasks that violate laws and regulations is prohibited (see Section 6 'Prohibited Task Types' of the Terms of Service).",
    "taskExecution": "3.2 Task Execution: (1) Task takers should complete tasks as agreed, ensuring service quality. (2) Both parties should maintain communication via in-platform messages, providing timely progress updates. (3) Issues should be promptly negotiated and resolved; unilateral abandonment should be avoided.",
    "fleaMarket": "3.3 Flea Market: (1) Product information must be true and accurate; material defects must not be concealed. (2) Posting counterfeit, infringing, or prohibited items is forbidden. (3) Communication must be conducted on the platform; guiding off-platform transactions is prohibited.",
    "reviews": "3.4 Review Standards: (1) Reviews should be based on genuine experiences, objective and fair. (2) Fake positive reviews, malicious negative reviews, or organised review manipulation are prohibited. (3) Reviews must not contain personal attacks or unfounded accusations. (4) Threatening others with negative reviews or trading positive reviews is prohibited."
  },
  "moderation": {
    "title": "4. Content Moderation",
    "methods": "4.1 Moderation Methods: The platform uses a combination of automated and manual moderation. The automated system detects clearly violating content in real time. The manual moderation team handles user reports and complex cases. The platform reserves the right to moderate all user-generated content.",
    "timeline": "4.2 Moderation Timeframes: Reported content is typically reviewed within 24-72 hours. Urgent cases (such as those involving personal safety threats) are prioritised. Moderation results will be communicated via in-platform messages or email.",
    "transparency": "4.3 Moderation Transparency: If content is removed or restricted, the platform will inform you of the specific reason and the guideline provision relied upon. Users may appeal moderation decisions (see 'Appeals Process' below)."
  },
  "reporting": {
    "title": "5. Reporting Mechanism",
    "howToReport": "5.1 How to Report: (1) Click the 'Report' button next to the violating content. (2) Select the report reason category (e.g. harassment, false information, illegal content, etc.). (3) Provide additional explanation and evidence (optional but recommended). (4) After submission, the platform will process the report within 24-72 hours.",
    "reportCategories": "5.2 Report Categories: Reportable content includes: harassment or personal attacks, false or misleading information, illegal or harmful content, spam or advertising, intellectual property infringement, privacy violations, discrimination or hate speech, fraud or scams, and other violations of the Community Guidelines.",
    "protection": "5.3 Reporter Protection: Reporter identity information will be kept strictly confidential; the platform will not disclose the reporter's identity to the reported party. Retaliation against reporters is prohibited and will be dealt with seriously.",
    "falseReporting": "5.4 Malicious Reporting: Malicious or false reporting is prohibited. Users who repeatedly make malicious reports may have their reporting privileges restricted or face other penalties."
  },
  "enforcement": {
    "title": "6. Enforcement Actions",
    "levels": "6.1 Penalty Levels: The platform takes the following enforcement actions based on the severity and frequency of violations:",
    "warning": "• Reminder/Warning: For first-time minor violations, the platform will send a reminder notice, asking the user to understand and comply with the relevant guidelines.",
    "contentRemoval": "• Content Removal: Violating content will be removed, and the user will receive a notice explaining the reason for removal.",
    "temporaryRestriction": "• Temporary Restriction: For repeated or more serious violations, the platform may temporarily restrict some of the user's features (such as posting, commenting, publishing tasks, etc.), with restriction duration depending on circumstances (typically 1-30 days).",
    "accountSuspension": "• Account Suspension: For serious violations or repeated offences, the platform may suspend the user's account for a period (typically 7-90 days).",
    "permanentBan": "• Permanent Ban: For extremely serious violations (such as involving criminal activity, serious fraud, persistent malicious behaviour, etc.), the platform will permanently ban the user's account.",
    "legalAction": "• Legal Action: For violations involving criminal activity, the platform reserves the right to report to relevant law enforcement agencies and cooperate with investigations.",
    "factors": "6.2 Penalty Consideration Factors: The severity of the violation, the frequency and history of violations, the impact of the violation on other users, and the user's cooperation and corrective actions."
  },
  "appeals": {
    "title": "7. Appeals Process",
    "process": "7.1 How to Appeal: (1) If you believe your content was incorrectly removed or your account was incorrectly penalised, you may submit an appeal within 14 days of receiving the notification. (2) Submit an appeal via the in-app 'Help & Feedback' function, or send an email to info@link2ur.com. (3) In your appeal, please explain why you believe the penalty is inappropriate and provide relevant evidence.",
    "review": "7.2 Appeal Review: (1) The platform will complete the review within 7 working days of receiving the appeal. (2) Appeals will be reviewed independently by a team member different from the original moderator. (3) The review result will be communicated to the appellant via in-platform message or email.",
    "outcome": "7.3 Appeal Outcome: (1) If the appeal is successful, removed content will be restored and related penalties will be revoked. (2) If the appeal is unsuccessful, the original penalty will remain; the platform will explain the reasons for maintaining the original decision. (3) Each penalty may only be appealed once. If you disagree with the final outcome, you may pursue legal remedies."
  },
  "updates": {
    "title": "8. Guideline Updates",
    "content": "The platform may update these Community Guidelines from time to time in response to changes in laws and regulations, platform operational needs, or user feedback. Significant updates will be communicated to users via in-app notifications or email. Continued use of the platform constitutes acceptance of the updated guidelines."
  },
  "contactUs": {
    "title": "9. Contact Us",
    "content": "If you have questions about these Community Guidelines or need assistance, please contact us via:\n• Email: info@link2ur.com\n• In-app 'Help & Feedback' function"
  }
}
$CG_EN$::jsonb, 'v1.0', '2026-03-01')
ON CONFLICT (type, lang) DO UPDATE SET
    content_json = EXCLUDED.content_json,
    version = EXCLUDED.version,
    effective_at = EXCLUDED.effective_at,
    updated_at = NOW();
