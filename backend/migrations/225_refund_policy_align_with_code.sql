-- 迁移 225：refund_policy 内容对齐实际代码行为
-- 依赖：223（创建行）、224（加 section titles）
--
-- 背景：人工审计发现 224 的政策草稿在以下 5 处与代码实际行为不一致或不可执行：
--   #1 eligibility 说"待确认状态之前"——代码 (refund_routes.py:202) 严格要求
--      task.status == 'pending_confirmation'。改为"时"。
--   #2 (新增) eligibility 没提 3 天自动确认窗口——
--      celery_tasks.py:auto_confirm_expired_tasks_task 每 15min 跑，
--      confirmation_deadline = slot_end + 3 days，过期自动确认完成→无法退款。
--   #3 refundProcess 承诺"服务方在 48 小时内回应"——代码无 48h 计时器，
--      只有 rebuttal_submitted_at 字段，无截止。删除 48h 承诺。
--   #4 refundProcess 承诺"客服在 3-5 个工作日内裁定"——无 SLA 监控，
--      软化为"客服将尽快裁定"。
--   #6 walletAndCoupon 说"积分抵扣同优惠券规则"——代码 refund_service.py:366
--      明确"积分支付已禁用，不需要退还积分"。删除积分相关条款。
--
-- #5 (优惠券按 full/partial 区分返还) 通过同批 commit 修改 refund_service.py
--    实现了代码侧逻辑，walletAndCoupon 的"全额返还,按比例不返还"承诺现在有效。
--    这一段无需改动。
--
-- 幂等：UPDATE。

-- ========== 中文 (zh) ==========
UPDATE legal_documents SET content_json = $REFUND_ZH_V3$
{
  "title": "退款政策",
  "lastUpdated": "最后更新：2026-05-03",
  "version": "版本：v1.1",
  "effectiveDate": "生效日期：2026-05-03",
  "intro": {
    "title": "适用范围",
    "content": "本政策适用于 Link²Ur 平台所有付费场景，包括但不限于：任务委托、套餐购买、活动报名、跳蚤市场租赁。VIP 订阅通过 Apple App Store / Google Play 购买，退款须按对应商店规则办理（详见「VIP 订阅退款」一节）。"
  },
  "eligibility": {
    "title": "申请退款的条件",
    "content": "退款申请须满足以下条件：（1）任务状态为「待确认」时方可申请退款；（2）任务进入「待确认」状态后 3 天内未由任一方确认或申请退款的，系统将自动确认完成并放款，此后不再受理退款；（3）任务一经确认完成，原则上不再受理退款；（4）双方协商一致取消、服务方违反平台规则被处理、平台原因导致服务无法继续等情形可申请退款。"
  },
  "fullRefund": {
    "title": "可全额退款的情形",
    "content": "以下情形可申请全额退款：（1）服务方未开始履约；（2）双方协商一致取消任务；（3）服务方逾期未响应或单方放弃；（4）服务方违反平台规则被处理（如封号、禁言）；（5）平台原因（系统故障、不可抗力、运营调整）导致服务无法继续。"
  },
  "partialRefund": {
    "title": "按比例退款的情形",
    "content": "以下情形可申请按比例退款：（1）服务方已部分交付，任务部分完成；（2）双方就部分履约达成协议；（3）因发布方原因中止但服务方已投入工作。退款比例（0%–100%）由双方协商或平台审核裁定，通常按已完成工作量、已发生成本、约定服务标准等因素综合判定。部分退款金额不得等于或大于任务总金额（应改用全额退款）。"
  },
  "nonRefundable": {
    "title": "不予退款的情形",
    "content": "以下情形不予退款：（1）任务已确认完成（无论是双方手动确认还是 3 天后系统自动确认）；（2）服务方按约履约后，因发布方个人原因取消；（3）提供虚假证据或恶意申请退款；（4）申请超出本政策规定的有效窗口或任务状态条件。"
  },
  "refundProcess": {
    "title": "退款流程",
    "content": "退款流程：（1）任务发布方在任务详情页选择「申请退款」，并选择退款类型（全额/按比例）、退款原因、退款金额（部分退款时）；（2）系统在任务聊天框发送系统消息通知服务方，服务方可提交反驳证据；（3）双方达成一致后退款进入处理；（4）双方未达成一致时可申请平台介入，客服将基于聊天记录、任务进度证据、双方陈述等综合裁定；（5）裁定通过后按原支付路径退款。每个任务在同一时间仅可有一笔进行中的退款申请。"
  },
  "refundTime": {
    "title": "到账时效",
    "content": "退款到账时效（以渠道实际为准）：钱包/平台余额——即时；银行卡 / Apple Pay——5-10 个工作日；微信支付——3-7 个工作日；支付宝——3-7 个工作日。退款失败的（如卡片已注销），平台将联系您协商替代方案。"
  },
  "walletAndCoupon": {
    "title": "钱包与优惠券处理",
    "content": "钱包与优惠券处理：（1）使用钱包余额抵扣的部分，退款时退回钱包；Stripe 渠道支付的部分，退回原卡。部分退款时钱包抵扣按退款比例同步退还。（2）全额退款时，使用过的优惠券将返还到您的账户（可在有效期内重复使用）；部分退款时，优惠券视为已使用，不予返还。"
  },
  "disputeResolution": {
    "title": "争议处理",
    "content": "争议处理：双方协商不成时，任意一方可申请平台介入。客服将基于聊天记录、任务进度证据、双方陈述等综合裁定，并尽快给出结果。平台裁定为最终结果，双方应予执行。涉及金额较大或复杂争议的，平台可延长审核期并要求补充证据。"
  },
  "vipSubscription": {
    "title": "VIP 订阅退款",
    "content": "VIP 订阅退款：Link²Ur VIP 通过 Apple App Store / Google Play 的应用内购买进行，退款须直接联系 Apple 支持或 Google Play 客服办理。平台无法直接处理通过应用商店购买的 VIP 订阅退款。已取消的订阅在当前付费周期结束前仍可享受 VIP 权益。"
  },
  "specialCases": {
    "title": "特殊场景",
    "content": "特殊场景：（1）不可抗力（自然灾害、政府管制、突发公共事件）导致任务无法继续的，按平台公告处理；（2）平台原因（系统故障、运营调整）导致的损失，平台将主动全额退款并视情况提供补偿；（3）账号违规处置：被处置账号涉及的待结算资金按平台规则与法律要求处理。"
  },
  "contactUs": {
    "title": "联系我们",
    "content": "如有疑问或需要协助，请通过应用内「我的 → 帮助中心 → 联系客服」联系我们，客服工作时间为周一至周五 09:00-18:00（英国时间）。也可发送邮件至 info@link2ur.com。"
  },
  "importantNotice": {
    "title": "重要提示",
    "content": "本政策的最终解释权归 Link²Ur 平台所有。本政策可能因业务调整或法律法规变化而更新，更新后将在应用内公示并以最新版本为准。继续使用本平台付费功能视为接受最新版本的退款政策。"
  }
}
$REFUND_ZH_V3$::jsonb,
    version = 'v1.1',
    updated_at = NOW()
WHERE type = 'refund_policy' AND lang = 'zh';

-- ========== English (en) ==========
UPDATE legal_documents SET content_json = $REFUND_EN_V3$
{
  "title": "Refund Policy",
  "lastUpdated": "Last updated: 2026-05-03",
  "version": "Version: v1.1",
  "effectiveDate": "Effective date: 2026-05-03",
  "intro": {
    "title": "Scope",
    "content": "This policy applies to all paid transactions on the Link²Ur platform, including but not limited to: task commissioning, service package purchases, paid activity sign-ups, and flea-market rentals. VIP subscriptions are purchased via Apple App Store / Google Play; refunds must be requested through the relevant store (see 'VIP Subscription Refunds' below)."
  },
  "eligibility": {
    "title": "Eligibility for Refund",
    "content": "Refund requests must satisfy the following: (1) the task must be in the 'pending confirmation' status when the request is filed; (2) if neither party confirms or files a refund request within 3 days of the task entering 'pending confirmation', the system will auto-confirm the task as completed and release payment, after which refunds are no longer accepted; (3) once a task is confirmed completed, refunds are generally not available; (4) refunds may also be requested where both parties agree to cancel, where the service provider has been sanctioned for rule violations, or where platform-side reasons make the service impossible to continue."
  },
  "fullRefund": {
    "title": "Full Refund Cases",
    "content": "A full refund may be requested in the following situations: (1) the service provider has not started performance; (2) both parties have agreed to cancel the task; (3) the service provider has not responded within the agreed time or has unilaterally abandoned the task; (4) the service provider has been sanctioned by the platform for rule violations (e.g. account suspension, mute); (5) platform-side reasons (system fault, force majeure, operational changes) make the service impossible to continue."
  },
  "partialRefund": {
    "title": "Partial Refund Cases",
    "content": "A pro-rata refund may be requested in the following situations: (1) the service provider has partially delivered and the task is partially completed; (2) both parties have reached agreement on partial performance; (3) the task was suspended due to the poster's reasons after the service provider had already invested work. The refund proportion (0%–100%) is determined either by agreement between the parties or by platform review, typically based on the work already completed, costs already incurred, and the agreed service standard. A partial refund amount cannot equal or exceed the full task amount (use a full refund instead)."
  },
  "nonRefundable": {
    "title": "Non-refundable Cases",
    "content": "Refunds are not available in the following situations: (1) the task has been confirmed as completed (whether by manual confirmation from either party or by the system's 3-day auto-confirmation); (2) the service provider has performed as agreed and the poster cancels for personal reasons; (3) false evidence is provided or the refund request is made in bad faith; (4) the request falls outside the valid window or task-status conditions defined by this policy."
  },
  "refundProcess": {
    "title": "Refund Process",
    "content": "Refund process: (1) the task poster selects 'Request refund' on the task detail page, choosing the refund type (full / pro-rata), reason and amount (for partial refunds); (2) the system posts a notice in the task chat to inform the service provider, who may submit rebuttal evidence; (3) once both parties agree, the refund proceeds to processing; (4) where the parties cannot agree, either side may request platform intervention, and our support team will issue a decision based on chat records, task-progress evidence and both parties' statements; (5) once approved, the refund is returned via the original payment route. A task may have only one in-flight refund request at a time."
  },
  "refundTime": {
    "title": "Refund Arrival Time",
    "content": "Refund arrival time (subject to the actual channel): wallet / platform balance — instant; bank card / Apple Pay — 5-10 working days; WeChat Pay — 3-7 working days; Alipay — 3-7 working days. If a refund fails (for example, the card has been cancelled), the platform will contact you to arrange an alternative."
  },
  "walletAndCoupon": {
    "title": "Wallet & Coupon Handling",
    "content": "Wallet and coupon handling: (1) the portion paid by wallet balance is refunded to the wallet; the portion paid via Stripe is refunded to the original card. On a partial refund, the wallet portion is refunded pro rata. (2) On a full refund, any coupon used will be returned to your account and may be re-used within its validity; on a partial refund, the coupon is treated as used and will not be returned."
  },
  "disputeResolution": {
    "title": "Dispute Resolution",
    "content": "Dispute resolution: if the parties cannot agree, either side may request platform intervention. Our support team will issue a decision as promptly as possible, based on chat records, task-progress evidence and both parties' statements. The platform's decision is final and binding. For larger amounts or complex disputes, the platform may extend the review period and request additional evidence."
  },
  "vipSubscription": {
    "title": "VIP Subscription Refunds",
    "content": "VIP subscription refunds: Link²Ur VIP is purchased via Apple App Store / Google Play in-app purchase. Refunds must be requested directly through Apple Support or Google Play support — the platform cannot process refunds for VIP subscriptions bought through the app stores. A cancelled subscription continues to receive VIP benefits until the end of the current paid period."
  },
  "specialCases": {
    "title": "Special Situations",
    "content": "Special situations: (1) where force majeure (natural disasters, government measures, public-health emergencies) makes a task impossible to continue, the platform will handle it according to public notices; (2) for losses caused by platform-side reasons (system fault, operational changes), the platform will proactively issue a full refund and may provide additional compensation as appropriate; (3) for accounts subject to violation handling, any unsettled funds will be handled in accordance with platform rules and applicable law."
  },
  "contactUs": {
    "title": "Contact Us",
    "content": "If you have questions or need help, please contact us via 'Profile → Help Centre → Contact Support' in the app. Support hours are Monday to Friday, 09:00-18:00 (UK time). You can also email info@link2ur.com."
  },
  "importantNotice": {
    "title": "Important Notice",
    "content": "The final right of interpretation of this policy rests with the Link²Ur platform. This policy may be updated due to business changes or changes in law, and the latest version will be published in the app and prevail. Continuing to use the paid features of the platform constitutes acceptance of the latest version of this Refund Policy."
  }
}
$REFUND_EN_V3$::jsonb,
    version = 'v1.1',
    updated_at = NOW()
WHERE type = 'refund_policy' AND lang = 'en';

-- 验证
-- SELECT version, content_json->'eligibility'->>'title' FROM legal_documents WHERE type='refund_policy';
-- 期望：2 行，version='v1.1'，title 为「申请退款的条件」/「Eligibility for Refund」
