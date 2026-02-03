-- 迁移 079：在法律文档「用户协议」中增加积分规则与优惠券规则
-- 依赖：076（legal_documents 表）、077 或 078（terms 已有完整 content_json）
-- 通过 jsonb 合并将 pointsRules、couponRules 追加到现有 terms 内容，幂等

-- 中文用户协议：追加积分规则、优惠券规则
UPDATE legal_documents
SET content_json = content_json || $JSONZH${
  "pointsRules": {
    "title": "4.1 积分规则",
    "intro": "平台积分是平台向用户发放的虚拟权益单位，仅限在平台规则范围内使用。",
    "earn": "获取方式：用户可通过完成任务奖励、邀请新用户、参与活动等方式获得积分，具体规则与数额以平台公示或当时活动说明为准。",
    "use": "使用方式：积分可用于兑换平台指定的优惠券或权益，不可直接抵扣现金或提现。每笔积分兑换以平台当时规则为准。",
    "expire": "有效期与清零：积分可能设有有效期或过期规则；若平台启用积分过期，过期后未使用的积分将自动清零。具体有效期以平台公示为准。",
    "value": "积分非货币：积分不具备货币属性，不可转让、不可兑换为现金或法律意义上的财产，仅限本人账户内使用。",
    "adjust": "规则变更：平台有权根据运营需要调整积分获取比例、使用范围、有效期等规则，调整后将通过公示或通知方式告知用户；重大变更时平台会合理提前通知。"
  },
  "couponRules": {
    "title": "4.2 优惠券规则",
    "intro": "优惠券是平台或合作方发放的折扣凭证，仅在平台指定场景下使用。",
    "claim": "领取与资格：用户可通过兑换码、活动页领取、积分兑换等方式获得优惠券；每张优惠券的领取资格、每人限领数量及使用条件以券面或平台公示为准。",
    "use": "使用条件：优惠券通常设有使用门槛（如满额可用）、适用业务（如仅限任务支付）、有效期；使用时须同时满足券面及平台规则。",
    "type": "类型与面额：优惠券可能为固定金额减免或比例折扣，具体以券面或详情页为准。每笔订单可使用规则以平台当时规则为准（如是否可叠加）。",
    "refund": "退款与失效：使用优惠券的订单若发生退款，按平台退款规则处理；已使用的优惠券可能不予退还或按规则作废。优惠券过期未使用将自动失效。",
    "prohibit": "禁止行为：禁止通过非正当手段批量获取、倒卖、伪造优惠券；违规将导致券作废及账号处理。",
    "adjust": "规则变更：平台有权调整优惠券的发放、使用规则及适用范围，调整后以公示为准。"
  }
}$JSONZH$::jsonb
WHERE type = 'terms' AND lang = 'zh';

-- 英文用户协议：追加积分规则、优惠券规则
UPDATE legal_documents
SET content_json = content_json || $JSONEN${
  "pointsRules": {
    "title": "4.1 Points Rules",
    "intro": "Platform points are virtual benefit units issued by the platform to users and may only be used within the scope of platform rules.",
    "earn": "How to earn: Users may earn points by completing tasks, inviting new users, participating in activities, etc. Specific rules and amounts are as published or stated in the relevant activity.",
    "use": "How to use: Points may be used to redeem designated coupons or benefits; they cannot be used directly as cash or withdrawn. Each redemption is subject to the platform's current rules.",
    "expire": "Validity and expiry: Points may be subject to a validity period or expiry rules; if the platform has enabled point expiry, unused points after expiry will be cleared. Specific validity is as published.",
    "value": "Points are not currency: Points have no monetary value, are non-transferable, cannot be exchanged for cash or legal property, and may only be used within the account holder's account.",
    "adjust": "Rule changes: The platform may adjust point earning rates, use scope, validity and other rules as needed; changes will be communicated by notice or publication; material changes will be notified with reasonable advance notice."
  },
  "couponRules": {
    "title": "4.2 Coupon Rules",
    "intro": "Coupons are discount vouchers issued by the platform or partners and may only be used in designated platform scenarios.",
    "claim": "Claiming and eligibility: Users may obtain coupons via redemption codes, activity pages, or point redemption. Eligibility, per-user limits and conditions are as stated on the coupon or published by the platform.",
    "use": "Conditions of use: Coupons are typically subject to minimum spend, applicable services (e.g. task payment only) and validity; use must comply with both the coupon and platform rules.",
    "type": "Type and value: Coupons may offer a fixed discount or percentage discount as stated on the coupon or detail page. Rules for use per order (e.g. stacking) are as published at the time.",
    "refund": "Refunds and invalidity: If an order paid with a coupon is refunded, platform refund rules apply; used coupons may not be returned or may be voided. Unused coupons expire automatically after the validity period.",
    "prohibit": "Prohibited conduct: Bulk acquisition, resale or counterfeiting of coupons by improper means is prohibited; violations may result in coupon voiding and account action.",
    "adjust": "Rule changes: The platform may adjust coupon issuance, use rules and scope; changes take effect as published."
  }
}$JSONEN$::jsonb
WHERE type = 'terms' AND lang = 'en';
