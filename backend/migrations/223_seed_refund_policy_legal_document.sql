-- 迁移 223：新增退款政策法律文档（refund_policy）
-- 依赖：076（legal_documents 表）
-- 在支付页脚 + 设置页"法律条款"提供独立的"退款政策"入口
-- 幂等：使用 ON CONFLICT (type, lang) DO UPDATE
-- 注意：legal_documents 表的唯一约束应为 (type, lang)；如约束名不同请按实际调整。

-- ========== 中文 (zh) ==========
INSERT INTO legal_documents (type, lang, content_json, version, effective_at)
VALUES ('refund_policy', 'zh', $REFUND_ZH$
{
  "title": "退款政策",
  "lastUpdated": "最后更新：2026-05-03",
  "version": "版本：v1.0",
  "effectiveDate": "生效日期：2026-05-03",
  "intro": "本政策适用于 Link²Ur 平台所有付费场景，包括但不限于：任务委托、套餐购买、活动报名、跳蚤市场租赁。VIP 订阅通过 Apple App Store / Google Play 购买，退款须按对应商店规则办理（详见第 12 节）。",
  "eligibility": "退款申请须满足以下条件之一：任务尚未确认完成（状态为「待确认」之前）；双方协商一致取消；服务方违反平台规则被处理；平台原因导致服务无法继续。一旦任务双方确认完成，原则上不可申请退款。",
  "fullRefund": "以下情形可申请全额退款：（1）服务方未开始履约；（2）双方协商一致取消任务；（3）服务方逾期未响应或单方放弃；（4）服务方违反平台规则被处理（如封号、禁言）；（5）平台原因（系统故障、不可抗力、运营调整）导致服务无法继续。",
  "partialRefund": "以下情形可申请按比例退款：（1）服务方已部分交付，任务部分完成；（2）双方就部分履约达成协议；（3）因发布方原因中止但服务方已投入工作。退款比例（0%–100%）由双方协商或平台审核裁定，通常按已完成工作量、已发生成本、约定服务标准等因素综合判定。",
  "nonRefundable": "以下情形不予退款：（1）任务已确认完成且双方均已评价；（2）服务方按约履约后，因发布方个人原因取消；（3）提供虚假证据或恶意申请退款；（4）申请超出本政策规定的有效期或任务状态窗口。",
  "refundProcess": "退款流程：（1）任务发布方在任务详情页选择「申请退款」；（2）选择退款类型（全额/按比例）、退款原因、退款金额；（3）服务方在 48 小时内回应（同意/异议）；（4）双方达成一致后退款进入处理；（5）双方未达成一致时申请平台介入，客服在 3-5 个工作日内裁定；（6）审核通过后按原支付路径退款。",
  "refundTime": "退款到账时效（以渠道实际为准）：钱包/平台余额——即时；银行卡 / Apple Pay——5-10 个工作日；微信支付——3-7 个工作日；支付宝——3-7 个工作日。退款失败的（如卡片已注销），平台将联系您协商替代方案。",
  "walletAndCoupon": "钱包与优惠券处理：（1）使用钱包余额抵扣的部分，退款时退回钱包；Stripe 渠道支付的部分，退回原卡。（2）全额退款时，使用过的优惠券将返还到您的账户（可在有效期内重复使用）；按比例退款时，优惠券视为已使用，不予返还。（3）积分抵扣的处理同优惠券规则。",
  "disputeResolution": "争议处理：双方协商不成时，任意一方可申请平台介入。客服将在 3-5 个工作日内基于聊天记录、任务进度证据、双方陈述等综合裁定。平台裁定为最终结果，双方应予执行。涉及金额较大或复杂争议的，平台可延长审核期并要求补充证据。",
  "vipSubscription": "VIP 订阅退款：Link²Ur VIP 通过 Apple App Store / Google Play 的应用内购买进行，退款须直接联系 Apple 支持或 Google Play 客服办理。平台无法直接处理通过应用商店购买的 VIP 订阅退款。已取消的订阅在当前付费周期结束前仍可享受 VIP 权益。",
  "specialCases": "特殊场景：（1）不可抗力（自然灾害、政府管制、突发公共事件）导致任务无法继续的，按平台公告处理；（2）平台原因（系统故障、运营调整）导致的损失，平台将主动全额退款并视情况提供补偿；（3）账号违规处置：被处置账号涉及的待结算资金按平台规则与法律要求处理。",
  "contactUs": "如有疑问或需要协助，请通过应用内「我的 → 帮助中心 → 联系客服」联系我们，客服工作时间为周一至周五 09:00-18:00（英国时间）。也可发送邮件至 info@link2ur.com。",
  "importantNotice": "本政策的最终解释权归 Link²Ur 平台所有。本政策可能因业务调整或法律法规变化而更新，更新后将在应用内公示并以最新版本为准。继续使用本平台付费功能视为接受最新版本的退款政策。"
}
$REFUND_ZH$, 'v1.0', '2026-05-03'::date)
ON CONFLICT (type, lang) DO UPDATE
SET content_json = EXCLUDED.content_json,
    version = EXCLUDED.version,
    effective_at = EXCLUDED.effective_at,
    updated_at = NOW();

-- ========== English (en) ==========
INSERT INTO legal_documents (type, lang, content_json, version, effective_at)
VALUES ('refund_policy', 'en', $REFUND_EN$
{
  "title": "Refund Policy",
  "lastUpdated": "Last updated: 2026-05-03",
  "version": "Version: v1.0",
  "effectiveDate": "Effective date: 2026-05-03",
  "intro": "This policy applies to all paid transactions on the Link²Ur platform, including but not limited to: task commissioning, service package purchases, paid activity sign-ups, and flea-market rentals. VIP subscriptions are purchased via Apple App Store / Google Play; refunds must be requested through the relevant store (see Section 12).",
  "eligibility": "A refund request must meet at least one of the following conditions: the task has not yet been confirmed as completed (i.e. is still before the 'pending confirmation' stage); both parties agree to cancel; the service provider has been sanctioned by the platform for breaching the rules; or platform-side reasons make the service impossible to continue. Once both parties confirm the task is completed, refunds are generally not available.",
  "fullRefund": "A full refund may be requested in the following situations: (1) the service provider has not started performance; (2) both parties have agreed to cancel the task; (3) the service provider has not responded within the agreed time or has unilaterally abandoned the task; (4) the service provider has been sanctioned by the platform for rule violations (e.g. account suspension, mute); (5) platform-side reasons (system fault, force majeure, operational changes) make the service impossible to continue.",
  "partialRefund": "A pro-rata refund may be requested in the following situations: (1) the service provider has partially delivered and the task is partially completed; (2) both parties have reached agreement on partial performance; (3) the task was suspended due to the poster's reasons after the service provider had already invested work. The refund proportion (0%–100%) is determined either by agreement between the parties or by platform review, typically based on the work already completed, costs already incurred, and the agreed service standard.",
  "nonRefundable": "Refunds are not available in the following situations: (1) the task has been confirmed as completed and both parties have left reviews; (2) the service provider has performed as agreed and the poster cancels for personal reasons; (3) false evidence is provided or the refund request is made in bad faith; (4) the request falls outside the valid window or task-status window defined by this policy.",
  "refundProcess": "Refund process: (1) the task poster selects 'Request refund' on the task detail page; (2) chooses the refund type (full / pro-rata), reason and amount; (3) the service provider responds within 48 hours (accept / dispute); (4) once both parties agree, the refund proceeds to processing; (5) where the parties cannot agree, either side may request platform intervention, and our support team will issue a decision within 3-5 working days; (6) once approved, the refund is returned via the original payment route.",
  "refundTime": "Refund arrival time (subject to the actual channel): wallet / platform balance — instant; bank card / Apple Pay — 5-10 working days; WeChat Pay — 3-7 working days; Alipay — 3-7 working days. If a refund fails (for example, the card has been cancelled), the platform will contact you to arrange an alternative.",
  "walletAndCoupon": "Wallet and coupon handling: (1) the portion paid by wallet balance is refunded to the wallet; the portion paid via Stripe is refunded to the original card. (2) On a full refund, any coupon used will be returned to your account and may be re-used within its validity; on a pro-rata refund, the coupon is treated as used and will not be returned. (3) Points used for deduction follow the same rules as coupons.",
  "disputeResolution": "Dispute resolution: if the parties cannot agree, either side may request platform intervention. Our support team will reach a decision within 3-5 working days based on chat records, task-progress evidence and both parties' statements. The platform's decision is final and binding. For larger amounts or complex disputes, the platform may extend the review period and request additional evidence.",
  "vipSubscription": "VIP subscription refunds: Link²Ur VIP is purchased via Apple App Store / Google Play in-app purchase. Refunds must be requested directly through Apple Support or Google Play support — the platform cannot process refunds for VIP subscriptions bought through the app stores. A cancelled subscription continues to receive VIP benefits until the end of the current paid period.",
  "specialCases": "Special situations: (1) where force majeure (natural disasters, government measures, public-health emergencies) makes a task impossible to continue, the platform will handle it according to public notices; (2) for losses caused by platform-side reasons (system fault, operational changes), the platform will proactively issue a full refund and may provide additional compensation as appropriate; (3) for accounts subject to violation handling, any unsettled funds will be handled in accordance with platform rules and applicable law.",
  "contactUs": "If you have questions or need help, please contact us via 'Profile → Help Centre → Contact Support' in the app. Support hours are Monday to Friday, 09:00-18:00 (UK time). You can also email info@link2ur.com.",
  "importantNotice": "The final right of interpretation of this policy rests with the Link²Ur platform. This policy may be updated due to business changes or changes in law, and the latest version will be published in the app and prevail. Continuing to use the paid features of the platform constitutes acceptance of the latest version of this Refund Policy."
}
$REFUND_EN$, 'v1.0', '2026-05-03'::date)
ON CONFLICT (type, lang) DO UPDATE
SET content_json = EXCLUDED.content_json,
    version = EXCLUDED.version,
    effective_at = EXCLUDED.effective_at,
    updated_at = NOW();

-- 验证
-- SELECT type, lang, version, effective_at FROM legal_documents WHERE type = 'refund_policy';
-- 期望：2 行 (zh + en)，version='v1.0'，effective_at='2026-05-03'
