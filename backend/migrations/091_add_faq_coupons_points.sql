-- ===========================================
-- 迁移文件091：FAQ 扩展（优惠券与积分、VIP、Linker、关于-加入/合作）
-- 与平台真实功能一致：优惠券/积分、VIP 权益与购买、Linker 能力与使用、加入与合作
-- 修复 AI 客服问「如何获得优惠券」时答非所问（原映射到 others 首条）
-- ===========================================

DO $body$
BEGIN
    -- 1. 新增 FAQ 分类：优惠券与积分、VIP 会员、Linker 智能助手
    INSERT INTO faq_sections (key, title_zh, title_en, sort_order)
    VALUES
        ('coupons_points', '优惠券与积分', 'Coupons & Points', 21),
        ('vip', 'VIP 会员', 'VIP Membership', 22),
        ('linker_ai', 'Linker 智能助手', 'Linker AI Assistant', 23)
    ON CONFLICT (key) DO NOTHING;

    -- 2. 新增该分类下的 FAQ 条目（仅当该分类下尚无条目时插入，避免重复执行重复数据）
    IF NOT EXISTS (SELECT 1 FROM faq_items fi JOIN faq_sections fs ON fi.section_id = fs.id WHERE fs.key = 'coupons_points' LIMIT 1) THEN
        INSERT INTO faq_items (section_id, question_zh, question_en, answer_zh, answer_en, sort_order)
        SELECT s.id, v.q_zh, v.q_en, v.a_zh, v.a_en, v.ord
        FROM (VALUES
            ('coupons_points', '如何获得优惠券？', 'How can I get coupons?',
             '您可以通过以下方式获得优惠券：1) 注册时填写有效邀请码，可能获得积分或优惠券；2) 在「优惠券与积分」页的「签到」栏每日签到，连续签到达到一定天数可领取积分或优惠券；3) 在「可领取优惠券」列表中领取限时/限量的优惠券（部分需会员或消耗积分）；4) 参与部分活动完成任务后可能获得活动奖励优惠券。具体以当时活动与页面说明为准。',
             'You can get coupons by: 1) Entering a valid invitation code when registering — you may receive points or a coupon; 2) Daily check-in under "Coupons & Points" — consecutive days can reward points or coupons; 3) Claiming from the "Available coupons" list (some may require membership or points); 4) Completing certain activities for reward coupons. See in-app offers and activity rules for details.', 1),
            ('coupons_points', '如何使用优惠券？', 'How to use coupons?',
             '在适用场景的支付/结算页面（如任务支付、跳蚤市场订单），系统会展示您可用的优惠券；选择要使用的优惠券后，订单金额会按券规则抵扣。每张券通常有最低消费金额和有效期，请在「我的优惠券」中查看。',
             'On the payment or checkout page for eligible tasks or flea market orders, your available coupons are shown; select one to apply and the order total will be discounted. Each coupon usually has a minimum spend and expiry — check "My coupons" for details.', 2),
            ('coupons_points', '积分从哪里看？怎么获得？', 'Where do I see points? How do I earn points?',
             '积分可在「钱包」或「优惠券与积分」页查看余额与明细。获得方式包括：完成任务后获得任务设置的积分奖励、每日签到奖励、使用邀请码注册奖励、参与活动并完成活动任务获得的积分奖励等。积分可用于兑换部分优惠券或抵扣，具体以页面规则为准。',
             'View your points balance and history under Wallet or "Coupons & Points". You earn points by: completing tasks (task reward), daily check-in, invitation code on sign-up, and completing activity tasks. Points can be used to redeem certain coupons or discounts — see in-app rules.', 3),
            ('coupons_points', '可以用积分兑换优惠券吗？', 'Can I redeem points for coupons?',
             '部分优惠券支持用积分兑换。在「优惠券与积分」的「优惠券」或「可领取」列表中，若某张券标注了所需积分，您可用当前积分余额兑换领取；兑换后积分会扣除，优惠券会进入「我的优惠券」。若积分不足或券已领完，则无法兑换。',
             'Some coupons can be redeemed with points. In "Coupons & Points", if a coupon shows a points cost, you can redeem it with your current balance; points will be deducted and the coupon added to "My coupons". If you don''t have enough points or the coupon is out of stock, redemption will fail.', 4),
            ('coupons_points', '签到有什么奖励？', 'What do I get for check-in?',
             '每日在「优惠券与积分」页的「签到」栏可签到一次。连续签到达到配置的天数（如 3 天、7 天等）可领取当日奖励，可能是积分或优惠券，具体以平台当前签到规则为准。断签会从 1 天重新累计。',
             'You can check in once per day under the "Check-in" tab in "Coupons & Points". Consecutive days (e.g. 3, 7 days) may unlock rewards such as points or coupons — see the current check-in rules. If you miss a day, the streak resets to 1.', 5),
            ('coupons_points', '邀请码在哪里填？有什么奖励？', 'Where do I enter an invitation code? What is the reward?',
             '邀请码可在注册时填写；部分入口也可能提供「兑换码」或「邀请码」输入处。有效邀请码可能奖励积分或优惠券，具体以该邀请码的配置为准。每个邀请码通常仅限使用一次，且有时效与使用次数限制。',
             'You can enter an invitation code during registration; some screens may also have a "Redeem code" or "Invitation code" field. A valid code may grant points or a coupon, depending on the code. Each code is usually one-time use and may have validity and usage limits.', 6),
            ('coupons_points', '优惠券过期了怎么办？', 'What if my coupon expired?',
             '过期优惠券无法使用或兑换。您可在「我的优惠券」中查看每张券的有效期，在有效期内使用；过期后无法恢复。建议在领取后尽快在适用订单中使用。',
             'Expired coupons cannot be used or exchanged. Check each coupon''s validity in "My coupons" and use it before expiry; we cannot restore expired coupons. We recommend using them soon after claiming.', 7),
            ('coupons_points', '为什么支付时看不到/用不了优惠券？', 'Why can''t I see or use a coupon at checkout?',
             '可能原因：1) 该订单不满足券的使用条件（如适用场景、最低消费金额）；2) 券已过期或已使用；3) 该任务/商品不在该券的适用范围内。请到「我的优惠券」查看券的说明与有效期，或换一张符合条件的券。',
             'Possible reasons: 1) The order doesn''t meet the coupon''s conditions (e.g. scenario, minimum spend); 2) The coupon has expired or been used; 3) The task/item is not in the coupon''s scope. Check "My coupons" for details and validity, or try another coupon that applies.', 8),
            ('coupons_points', '优惠券与积分在哪里查看？入口在哪？', 'Where do I view coupons and points? Where is the entry?',
             '在 App 或网页中进入「个人中心」或「我的」→「钱包」或「优惠券与积分」即可查看积分余额、交易记录、我的优惠券和可领取优惠券；签到入口也在「优惠券与积分」页的签到栏。',
             'In the app or website go to Profile / Me → Wallet or "Coupons & Points" to see your points balance, transaction history, my coupons and available coupons. The check-in entry is in the Check-in tab under "Coupons & Points".', 9),
            ('coupons_points', '积分和优惠券有什么区别？', 'What is the difference between points and coupons?',
             '积分是一种可累计的余额，可通过完成任务、签到、邀请码、活动等获得，用于兑换部分优惠券或抵扣；优惠券是单张可用的折扣凭证，有面额/折扣比例、最低消费和有效期，在支付时选择使用。两者都在「优惠券与积分」页管理。',
             'Points are a balance you earn from tasks, check-in, invitation codes, activities, etc., and can be used to redeem some coupons or discounts. Coupons are single-use vouchers with a value/discount, minimum spend and expiry, selected at payment. Both are managed under "Coupons & Points".', 10),
            ('coupons_points', '领取优惠券失败 / 无法领取怎么办？', 'What if I fail to claim a coupon or cannot claim?',
             '常见原因：已达该券的领取上限（每人/每时段限制）、积分不足（需积分兑换的券）、仅限会员领取、或券已领完/已下架。请查看页面的错误提示；若为积分不足请先赚取积分再兑换，若为限领请等待下次或关注其他券。',
             'Common reasons: you have reached the claim limit (per user or per period), insufficient points (for points-redeem coupons), members-only, or the coupon is out of stock. Check the on-screen message; if it''s insufficient points, earn more first; if limit reached, try again later or other coupons.', 11),
            ('coupons_points', '兑换码、优惠码在哪里输入？', 'Where do I enter a redemption code or promo code?',
             '注册时可在邀请码/兑换码栏填写；若已注册，部分活动或页面会提供「兑换码」「邀请码」输入框，一般在「优惠券与积分」或活动详情页。输入有效码后即可获得对应积分或优惠券。',
             'You can enter one when registering. If already registered, some activities or pages have a "Redeem code" or "Invitation code" field — usually under "Coupons & Points" or the activity page. Enter a valid code to receive the associated points or coupon.', 12),
            ('coupons_points', '积分会过期吗？', 'Do points expire?',
             '积分是否有有效期以平台当前规则为准，可在「优惠券与积分」或「钱包」页查看积分说明。若规则中有过期，建议在有效期内使用或兑换优惠券。',
             'Whether points expire depends on current platform rules; check the points terms under "Coupons & Points" or Wallet. If they do expire, use or redeem them for coupons before the expiry date.', 13),
            ('coupons_points', '积分可以提现吗？', 'Can I withdraw or cash out points?',
             '积分不能直接提现为现金。积分仅用于在平台内兑换优惠券或按规定抵扣消费。若需提现余额，请使用「钱包」中的收款/提现功能，该功能针对任务或卖货所得款项。',
             'Points cannot be withdrawn as cash. They can only be used in-app to redeem coupons or offset spending per the rules. To withdraw money, use the payout/withdraw option in Wallet, which applies to earnings from tasks or sales.', 14),
            ('coupons_points', '满减券和折扣券有什么区别？', 'What is the difference between fixed amount and percentage coupons?',
             '满减券（固定面额）达到最低消费后可直接减免一定金额（如满 10 减 2）；折扣券按订单金额的百分比减免（如 9 折）。支付时系统会列出可用券及抵扣金额，您可按需选择。',
             'Fixed-amount coupons reduce the order by a set amount once you meet the minimum spend (e.g. £2 off when you spend £10). Percentage coupons reduce the price by a percentage (e.g. 10% off). At checkout you will see which coupons apply and the discount amount.', 15),
            ('coupons_points', '签到断了怎么办？忘记签到了会清零吗？', 'What if I miss a check-in day? Does my streak reset?',
             '断签后连续天数会从 1 重新累计，之前的连续记录不会保留。次日可重新开始签到，达到新的连续天数后仍可领取对应奖励。建议每天打开「优惠券与积分」页完成签到。',
             'If you miss a day, your consecutive-day count resets to 1; the previous streak is not kept. You can start again the next day and still earn rewards when you reach the required consecutive days. We recommend checking in daily in "Coupons & Points".', 16)
        ) AS v(section_key, q_zh, q_en, a_zh, a_en, ord)
        JOIN faq_sections s ON s.key = v.section_key;

        RAISE NOTICE '✅ 优惠券与积分 FAQ 条目已添加（091）';
    END IF;

    -- 3. 补充条目：若之前已执行过本迁移（仅有前 6 条），则追加以下条目，避免重复
    INSERT INTO faq_items (section_id, question_zh, question_en, answer_zh, answer_en, sort_order)
    SELECT s.id, v.q_zh, v.q_en, v.a_zh, v.a_en, v.ord
    FROM (VALUES
        ('coupons_points', '优惠券过期了怎么办？', 'What if my coupon expired?',
         '过期优惠券无法使用或兑换。您可在「我的优惠券」中查看每张券的有效期，在有效期内使用；过期后无法恢复。建议在领取后尽快在适用订单中使用。',
         'Expired coupons cannot be used or exchanged. Check each coupon''s validity in "My coupons" and use it before expiry; we cannot restore expired coupons. We recommend using them soon after claiming.', 7),
        ('coupons_points', '为什么支付时看不到/用不了优惠券？', 'Why can''t I see or use a coupon at checkout?',
         '可能原因：1) 该订单不满足券的使用条件（如适用场景、最低消费金额）；2) 券已过期或已使用；3) 该任务/商品不在该券的适用范围内。请到「我的优惠券」查看券的说明与有效期，或换一张符合条件的券。',
         'Possible reasons: 1) The order doesn''t meet the coupon''s conditions (e.g. scenario, minimum spend); 2) The coupon has expired or been used; 3) The task/item is not in the coupon''s scope. Check "My coupons" for details and validity, or try another coupon that applies.', 8),
        ('coupons_points', '优惠券与积分在哪里查看？入口在哪？', 'Where do I view coupons and points? Where is the entry?',
         '在 App 或网页中进入「个人中心」或「我的」→「钱包」或「优惠券与积分」即可查看积分余额、交易记录、我的优惠券和可领取优惠券；签到入口也在「优惠券与积分」页的签到栏。',
         'In the app or website go to Profile / Me → Wallet or "Coupons & Points" to see your points balance, transaction history, my coupons and available coupons. The check-in entry is in the Check-in tab under "Coupons & Points".', 9),
        ('coupons_points', '积分和优惠券有什么区别？', 'What is the difference between points and coupons?',
         '积分是一种可累计的余额，可通过完成任务、签到、邀请码、活动等获得，用于兑换部分优惠券或抵扣；优惠券是单张可用的折扣凭证，有面额/折扣比例、最低消费和有效期，在支付时选择使用。两者都在「优惠券与积分」页管理。',
         'Points are a balance you earn from tasks, check-in, invitation codes, activities, etc., and can be used to redeem some coupons or discounts. Coupons are single-use vouchers with a value/discount, minimum spend and expiry, selected at payment. Both are managed under "Coupons & Points".', 10),
        ('coupons_points', '领取优惠券失败 / 无法领取怎么办？', 'What if I fail to claim a coupon or cannot claim?',
         '常见原因：已达该券的领取上限（每人/每时段限制）、积分不足（需积分兑换的券）、仅限会员领取、或券已领完/已下架。请查看页面的错误提示；若为积分不足请先赚取积分再兑换，若为限领请等待下次或关注其他券。',
         'Common reasons: you have reached the claim limit (per user or per period), insufficient points (for points-redeem coupons), members-only, or the coupon is out of stock. Check the on-screen message; if it''s insufficient points, earn more first; if limit reached, try again later or other coupons.', 11),
        ('coupons_points', '兑换码、优惠码在哪里输入？', 'Where do I enter a redemption code or promo code?',
         '注册时可在邀请码/兑换码栏填写；若已注册，部分活动或页面会提供「兑换码」「邀请码」输入框，一般在「优惠券与积分」或活动详情页。输入有效码后即可获得对应积分或优惠券。',
         'You can enter one when registering. If already registered, some activities or pages have a "Redeem code" or "Invitation code" field — usually under "Coupons & Points" or the activity page. Enter a valid code to receive the associated points or coupon.', 12),
        ('coupons_points', '积分会过期吗？', 'Do points expire?',
         '积分是否有有效期以平台当前规则为准，可在「优惠券与积分」或「钱包」页查看积分说明。若规则中有过期，建议在有效期内使用或兑换优惠券。',
         'Whether points expire depends on current platform rules; check the points terms under "Coupons & Points" or Wallet. If they do expire, use or redeem them for coupons before the expiry date.', 13),
        ('coupons_points', '积分可以提现吗？', 'Can I withdraw or cash out points?',
         '积分不能直接提现为现金。积分仅用于在平台内兑换优惠券或按规定抵扣消费。若需提现余额，请使用「钱包」中的收款/提现功能，该功能针对任务或卖货所得款项。',
         'Points cannot be withdrawn as cash. They can only be used in-app to redeem coupons or offset spending per the rules. To withdraw money, use the payout/withdraw option in Wallet, which applies to earnings from tasks or sales.', 14),
        ('coupons_points', '满减券和折扣券有什么区别？', 'What is the difference between fixed amount and percentage coupons?',
         '满减券（固定面额）达到最低消费后可直接减免一定金额（如满 10 减 2）；折扣券按订单金额的百分比减免（如 9 折）。支付时系统会列出可用券及抵扣金额，您可按需选择。',
         'Fixed-amount coupons reduce the order by a set amount once you meet the minimum spend (e.g. £2 off when you spend £10). Percentage coupons reduce the price by a percentage (e.g. 10% off). At checkout you will see which coupons apply and the discount amount.', 15),
        ('coupons_points', '签到断了怎么办？忘记签到了会清零吗？', 'What if I miss a check-in day? Does my streak reset?',
         '断签后连续天数会从 1 重新累计，之前的连续记录不会保留。次日可重新开始签到，达到新的连续天数后仍可领取对应奖励。建议每天打开「优惠券与积分」页完成签到。',
         'If you miss a day, your consecutive-day count resets to 1; the previous streak is not kept. You can start again the next day and still earn rewards when you reach the required consecutive days. We recommend checking in daily in "Coupons & Points".', 16)
    ) AS v(section_key, q_zh, q_en, a_zh, a_en, ord)
    JOIN faq_sections s ON s.key = v.section_key
    WHERE NOT EXISTS (
        SELECT 1 FROM faq_items fi
        WHERE fi.section_id = s.id AND fi.question_zh = v.q_zh
    );

    IF (SELECT COUNT(*) FROM faq_items fi JOIN faq_sections fs ON fi.section_id = fs.id WHERE fs.key = 'coupons_points') >= 10 THEN
        RAISE NOTICE '✅ 优惠券与积分 FAQ 已包含扩展条目（091）';
    END IF;

    -- 4. VIP 会员 FAQ 条目
    INSERT INTO faq_items (section_id, question_zh, question_en, answer_zh, answer_en, sort_order)
    SELECT s.id, v.q_zh, v.q_en, v.a_zh, v.a_en, v.ord
    FROM (VALUES
        ('vip', '什么是 VIP 会员？权益有哪些？', 'What is VIP membership? What are the benefits?',
         'VIP 会员是平台的付费会员服务，开通后可享受：任务优先推荐、专属 VIP 徽章、服务费减免、专属客服支持、积分加倍与专属活动、数据分析面板等。超级 VIP 还可享有无限任务发布、任务优先展示、专属高级客服等。具体权益以「设置」→「会员中心」页面为准。',
         'VIP is a paid membership that gives you: priority task recommendation, exclusive VIP badge, reduced service fees, dedicated customer support, points boost and exclusive activities, and a data analytics dashboard. Super VIP adds unlimited task posting, priority listing, and premium support. See Settings → Membership for current benefits.', 1),
        ('vip', '如何购买 / 开通 VIP？', 'How do I buy or activate VIP?',
         '在 App 或网页中进入「设置」→「会员中心」或「VIP 会员」，点击「立即开通」或「升级 VIP 会员」，选择月付或年付套餐后按提示完成支付（目前通过应用内购买 IAP）。支付成功后系统会自动激活会员，权益立即生效。',
         'Go to Settings → Membership or VIP in the app or website, tap "Upgrade" or "Get VIP", choose monthly or yearly plan and complete payment (currently via in-app purchase). After payment, membership is activated automatically and benefits take effect immediately.', 2),
        ('vip', '会员权益何时生效？', 'When do membership benefits take effect?',
         '会员权益在购买并支付成功后立即生效，您可以马上享受任务优先推荐、徽章、服务费减免等权益，无需等待。',
         'Benefits take effect immediately after payment. You can use priority recommendation, badge, fee discounts and other benefits right away.', 3),
        ('vip', '可以随时取消会员吗？', 'Can I cancel membership at any time?',
         '可以。您可随时联系客服或按平台指引取消会员；取消后将在当前计费周期结束后生效，到期后不再续费。已开通期内的权益可继续使用至周期结束。',
         'Yes. You can cancel anytime via support or in-app instructions. Cancellation takes effect at the end of the current billing period; you keep benefits until then.', 4),
        ('vip', '如何升级会员？月付和年付有什么区别？', 'How to upgrade membership? What is the difference between monthly and yearly?',
         '在「会员中心」页面可选择月付或年付套餐重新购买/续费。月付灵活、按月计费；年付通常价格更优惠且一次支付一年。升级或切换套餐以当时页面价格与说明为准。若需从普通用户升级为超级 VIP，平台可能根据完成任务数、评分等条件自动或手动升级，具体见会员页或联系 support@link2ur.com。',
         'In Membership you can choose monthly or yearly plans. Monthly is flexible; yearly is usually better value. Upgrade or switch as shown on the page. Super VIP may be granted automatically or by request based on task count and rating; see the membership page or email support@link2ur.com.', 5),
        ('vip', 'VIP 专属优惠券怎么领？', 'How do I get VIP exclusive coupons?',
         '部分优惠券仅限 VIP 会员领取。在「优惠券与积分」页的「可领取优惠券」列表中，标注为「仅会员」或「VIP 专属」的券，开通 VIP 后即可领取。具体以当时活动与券规则为准。',
         'Some coupons are VIP-only. In "Coupons & Points" → "Available coupons", those marked "Members only" or "VIP exclusive" can be claimed once you have an active VIP membership. See the coupon and activity rules for details.', 6)
    ) AS v(section_key, q_zh, q_en, a_zh, a_en, ord)
    JOIN faq_sections s ON s.key = v.section_key
    WHERE NOT EXISTS (SELECT 1 FROM faq_items fi WHERE fi.section_id = s.id AND fi.question_zh = v.q_zh);

    -- 5. Linker 智能助手 FAQ 条目
    INSERT INTO faq_items (section_id, question_zh, question_en, answer_zh, answer_en, sort_order)
    SELECT s.id, v.q_zh, v.q_en, v.a_zh, v.a_en, v.ord
    FROM (VALUES
        ('linker_ai', 'Linker 是什么？', 'What is Linker?',
         'Linker 是 Link2Ur 平台内的 AI 智能助手，用于解答平台使用问题、查询任务与个人数据等。您可以在「消息」或首页入口进入与 Linker 对话，用自然语言提问，无需记忆菜单。',
         'Linker is Link2Ur''s in-app AI assistant. It answers questions about the platform, your tasks, and your account. Open it from Messages or the home entry and ask in plain language.', 1),
        ('linker_ai', 'Linker 能做什么？能查什么？', 'What can Linker do? What can I ask?',
         'Linker 可以：回答平台常见问题（发布任务、支付、退款、优惠券、论坛等）；查询您的任务列表与任务详情；搜索公开任务；查询您的积分与优惠券、通知摘要、个人资料与统计；浏览活动列表等。复杂或需人工处理的问题可请求转人工客服。',
         'Linker can: answer platform FAQs (posting tasks, payments, refunds, coupons, forum, etc.); show your task list and task details; search public tasks; tell you your points and coupons, notification summary, profile and stats; list activities. For complex issues you can ask to be transferred to a human agent.', 2),
        ('linker_ai', '能查我的任务 / 积分 / 通知吗？', 'Can Linker check my tasks, points, or notifications?',
         '可以。您可以直接问「我的任务」「进行中的任务」「我有多少积分」「我有几张优惠券」「未读通知」等，Linker 会通过安全接口查询您账号下的数据并回复，仅限您本人可见。',
         'Yes. You can ask "my tasks", "tasks in progress", "how many points do I have", "my coupons", "unread notifications", etc. Linker will query your account data and reply; only you can see your data.', 3),
        ('linker_ai', 'Linker 和人工客服有什么区别？', 'What is the difference between Linker and human support?',
         'Linker 是 7×24 在线的 AI，适合快速查任务、查积分、查平台规则和常见问题；回复即时且不占人工排队。人工客服适合复杂纠纷、退款审核、账号异常等需要真人判断的情况。对话中您可以随时说「转人工」请求接入真人客服（若当时在线）。',
         'Linker is a 24/7 AI for quick answers about tasks, points, and platform rules. Human support is for disputes, refund reviews, account issues, etc. You can say "transfer to human" to reach a live agent when available.', 4),
        ('linker_ai', '什么时候会转人工？', 'When does it transfer to a human?',
         '当您明确说「转人工」「找真人客服」「联系客服」等时，系统会尝试为您接入人工客服；若当前有人工在线则会转接，否则可能提示稍后再试或通过邮件 support@link2ur.com 联系。Linker 不会自动转人工，需您主动提出。',
         'When you say "transfer to human", "talk to a real person", or "contact support", the system will try to connect you to a live agent. If one is available you will be transferred; otherwise you may be asked to try later or email support@link2ur.com. Linker does not transfer automatically.', 5),
        ('linker_ai', 'Linker 回复不准或答非所问怎么办？', 'What if Linker''s answer is wrong or irrelevant?',
         '请尽量用简短、具体的问题提问（例如「如何获得优惠券」而非笼统一句）。若仍答非所问，可换一种说法再问一次，或说「转人工」由客服协助。您也可以直接发邮件至 support@link2ur.com 描述问题，我们会持续优化 Linker 的回复质量。',
         'Try asking in a clear, specific way (e.g. "How can I get coupons?"). If the answer is still wrong, rephrase or ask to "transfer to human". You can also email support@link2ur.com with feedback so we can improve Linker.', 6)
    ) AS v(section_key, q_zh, q_en, a_zh, a_en, ord)
    JOIN faq_sections s ON s.key = v.section_key
    WHERE NOT EXISTS (SELECT 1 FROM faq_items fi WHERE fi.section_id = s.id AND fi.question_zh = v.q_zh);

    -- 6. 关于 Link²Ur：补充「加入」「合作」相关问答
    INSERT INTO faq_items (section_id, question_zh, question_en, answer_zh, answer_en, sort_order)
    SELECT s.id, v.q_zh, v.q_en, v.a_zh, v.a_en, v.ord
    FROM (VALUES
        ('about', '如何加入 Link2Ur？', 'How can I join Link2Ur?',
         '欢迎加入！您可下载 Link2Ur App（App Store / 官网）或访问官网注册账号，按提示完成注册与身份验证（如学校邮箱等）后即可使用任务市场、跳蚤市场、论坛等功能。注册与基础使用均免费。',
         'Welcome! Download the Link2Ur app (App Store or our website) or sign up on the website. Complete registration and any identity verification (e.g. school email), then you can use the task marketplace, flea market, forum and more. Registration and basic use are free.', 3),
        ('about', '可以和你们合作吗？', 'Can I partner with you?',
         '欢迎合作。若您有品牌、机构、校园或社区合作意向，请通过官网页脚的「合作与伙伴」入口提交信息，或发送邮件至 support@link2ur.com 说明合作类型与需求，我们会尽快与您联系。',
         'We are open to partnerships. For brand, institution, campus or community collaboration, use the "Partners" or "Collaboration" link in the website footer to submit your details, or email support@link2ur.com with your type of partnership and requirements. We will get back to you soon.', 4),
        ('about', '想成为合作伙伴 / 任务达人怎么申请？', 'How do I apply to become a partner or task expert?',
         '合作伙伴：请通过官网页脚「合作与伙伴」入口或邮件 support@link2ur.com 提交申请。任务达人（平台认证的技能服务提供者）：可在 App 内「任务达人」页或页脚「合作与伙伴」相关入口提交申请，填写技能与经验，审核通过后即可创建服务并接收预约。',
         'Partners: submit via the "Partners" link in the website footer or email support@link2ur.com. Task experts (verified skill providers): apply in the app under "Task Experts" or the footer "Partners" link with your skills and experience; once approved you can create services and receive bookings.', 5)
    ) AS v(section_key, q_zh, q_en, a_zh, a_en, ord)
    JOIN faq_sections s ON s.key = v.section_key
    WHERE NOT EXISTS (SELECT 1 FROM faq_items fi WHERE fi.section_id = s.id AND fi.question_zh = v.q_zh);

    RAISE NOTICE '✅ 优惠券与积分、VIP、Linker、关于(加入/合作) FAQ 已添加（091）';
END;
$body$;
