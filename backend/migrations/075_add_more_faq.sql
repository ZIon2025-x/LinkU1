-- ===========================================
-- 迁移文件075：补充更多 FAQ（跳蚤市场、论坛、任务申请、支付、评价、学生认证、任务达人、活动、通知等）
-- 适配本项目功能，解决用户常见问题
-- ===========================================

DO $body$
BEGIN
    -- 1. 新增 FAQ 分类（若已存在则跳过）
    INSERT INTO faq_sections (key, title_zh, title_en, sort_order)
    VALUES
        ('flea_market', '跳蚤市场', 'Flea Market', 12),
        ('forum', '论坛与社区', 'Forum & Community', 13),
        ('task_application', '任务申请与议价', 'Task Application & Negotiation', 14),
        ('payment_methods', '支付方式与到账', 'Payment Methods & Payouts', 15),
        ('reviews_reputation', '评价与信用', 'Reviews & Reputation', 16),
        ('student_verification', '学生认证', 'Student Verification', 17),
        ('task_experts', '任务达人', 'Task Experts', 18),
        ('activities', '活动与多人任务', 'Activities & Multi-participant', 19),
        ('notifications', '通知与消息', 'Notifications & Messages', 20)
    ON CONFLICT (key) DO NOTHING;

    -- 2. 新增 FAQ 条目（依赖上面 section 的 key）
    INSERT INTO faq_items (section_id, question_zh, question_en, answer_zh, answer_en, sort_order)
    SELECT s.id, v.q_zh, v.q_en, v.a_zh, v.a_en, v.ord
    FROM (VALUES
        -- 跳蚤市场
        ('flea_market', '跳蚤市场如何交易？', 'How does the flea market work?',
         '买家可直接按标价购买或发起议价；卖家同意后，买家需在平台内完成支付，款项由平台托管，双方确认完成后再释放给卖家。请勿私下转账，以保障双方权益。',
         'Buyers can purchase at list price or make an offer. Once the seller agrees, the buyer pays through the platform; funds are held until both parties confirm completion, then released to the seller. Do not pay privately.', 1),
        ('flea_market', '如何议价购买？', 'How to make an offer?',
         '在商品页点击「申请购买」或「议价」，填写出价和留言；卖家可接受、还价或拒绝。若接受，您需在约定时间内完成平台支付，否则订单会关闭。',
         'On the item page, tap "Apply to buy" or "Make an offer", enter your price and message. The seller can accept, counter, or reject. If accepted, complete payment on the platform within the time limit, or the order will close.', 2),
        ('flea_market', '卖家需要绑定收款账户吗？', 'Does the seller need a payout account?',
         '是的。卖家需先完成 Stripe Connect 收款账户的注册与验证，才能接收货款；否则买家无法完成支付流程。可在「钱包」或「设置」中查找收款账户入口。',
         'Yes. Sellers must complete Stripe Connect payout account setup and verification before they can receive payment; otherwise the buyer cannot complete payment. Find the payout option under Wallet or Settings.', 3),
        ('flea_market', '商品已下单但未支付会怎样？', 'What if I don''t pay after ordering?',
         '订单会有支付截止时间（通常约 30 分钟）；超时未支付则订单自动关闭，商品会重新可售。若仍需购买，请重新下单并按时支付。',
         'Orders have a payment deadline (usually around 30 minutes). If unpaid by then, the order closes and the item becomes available again. To buy later, place a new order and pay on time.', 4),
        -- 论坛与社区
        ('forum', '论坛发帖有什么规则？', 'What are the forum rules?',
         '请遵守社区规范：禁止广告刷屏、人身攻击与违法内容；按板块主题发帖。违规内容可能被删除或导致账户受限。具体请查看论坛置顶或《服务条款》。',
         'Follow community guidelines: no spam, personal attacks, or illegal content; post according to category topics. Violations may lead to removal or account restrictions. See forum sticky posts or Terms of Use.', 1),
        ('forum', '如何找到自己学校或地区的板块？', 'How to find my school or region?',
         '在论坛首页可浏览或搜索板块；部分板块需完成学生认证或学校邮箱验证后才能访问。若找不到您的学校，可通过「申请新板块」或联系 support@link2ur.com。',
         'Browse or search categories on the forum home page. Some categories require student verification or school email to access. If your school is missing, use "Request category" or contact support@link2ur.com.', 2),
        ('forum', '帖子被删除或账号受限怎么办？', 'What if my post is removed or account restricted?',
         '若认为误删或误判，可邮件 support@link2ur.com 说明情况请求复核；恶意违规将按平台规则处理。请避免重复发布违规内容。',
         'If you believe it was a mistake, email support@link2ur.com with details for review. Repeated or serious violations are handled under platform rules.', 3),
        -- 任务申请与议价
        ('task_application', '如何申请任务？', 'How do I apply for a task?',
         '在任务详情页点击「申请」，填写申请说明；若任务支持议价可填写期望价格。发布者会在消息或通知中收到申请，并选择接受或拒绝。',
         'On the task detail page, tap "Apply" and add your message; if the task allows negotiation, you can suggest a price. The poster will see your application in Messages or Notifications and accept or reject.', 1),
        ('task_application', '议价后发布者接受了我该怎么办？', 'What if the poster accepts my offer?',
         '您会收到通知；需在约定时间内完成支付（若任务需预付）。支付完成后任务进入进行中，请按任务说明与对方沟通并完成交付。',
         'You will get a notification; complete payment within the given time if the task requires prepayment. Once paid, the task is in progress — follow the task description and communicate with the other party.', 2),
        ('task_application', '申请被拒绝会通知我吗？', 'Will I be notified if my application is rejected?',
         '会。您会在站内通知和/或消息中收到结果；可继续申请其他任务。',
         'Yes. You will see the result in notifications and/or Messages; you can apply for other tasks.', 3),
        ('task_application', '可以同时申请多个任务吗？', 'Can I apply for multiple tasks at once?',
         '可以。但若您同时被多个任务接受，请根据自身时间合理安排；频繁接受后取消可能影响信用与评价。',
         'Yes. If multiple applications are accepted, manage your time accordingly; frequent accept-then-cancel may affect your reputation.', 4),
        -- 支付方式与到账
        ('payment_methods', '支持哪些支付方式？', 'What payment methods are supported?',
         '目前支持银行卡（Stripe）、Apple Pay 等；具体以支付页显示为准。所有支付均在平台内完成，请勿私下转账。',
         'We support card (Stripe), Apple Pay, etc.; see the payment page for current options. All payments are made on the platform — do not pay privately.', 1),
        ('payment_methods', '钱什么时候到接单方/卖家？', 'When does the taker/seller get paid?',
         '任务或交易经双方确认完成后，款项会从平台托管释放至接单方或卖家的收款账户；到账时间取决于银行或 Stripe 处理，通常为数个工作日。',
         'After both parties confirm completion, funds are released from the platform to the taker/seller payout account; arrival time depends on the bank or Stripe, usually within a few business days.', 2),
        ('payment_methods', '为什么提示需要绑定收款账户？', 'Why do I need to link a payout account?',
         '若您接单或卖货，需先绑定 Stripe Connect 收款账户才能接收款项；这是平台与支付机构的要求，用于安全打款与合规。',
         'If you take tasks or sell items, you must link a Stripe Connect payout account to receive funds; this is required by the platform and payment provider for secure payouts.', 3),
        ('payment_methods', '支付失败或重复扣款怎么办？', 'What if payment fails or I was charged twice?',
         '支付失败不会扣款；若出现重复扣款或异常，请保留截图并邮件 support@link2ur.com，我们会协助核查并与支付方处理。',
         'Failed payments are not charged. If you see a duplicate charge or error, keep a screenshot and email support@link2ur.com; we will help investigate with the payment provider.', 4),
        ('payment_methods', '任务/订单支付超时了怎么办？', 'What if my task/order payment expired?',
         '订单支付有截止时间（通常约 30 分钟）；超时未支付则订单自动关闭，任务或商品会重新可接/可售。若仍需继续，请重新申请或下单并按时支付。',
         'Order payment has a deadline (usually around 30 minutes); if unpaid by then, the order closes and the task/item becomes available again. To proceed, re-apply or place a new order and pay on time.', 5),
        -- 评价与信用
        ('reviews_reputation', '评价何时可以写？', 'When can I leave a review?',
         '任务或交易经双方确认完成后，您可以在任务/订单页或「我的任务」中提交评价；逾期未评价可能无法补写，请及时完成。',
         'After both parties confirm completion, you can submit a review on the task/order page or under "My Tasks". Late reviews may not be available, so submit in time.', 1),
        ('reviews_reputation', '评价可以修改或删除吗？', 'Can I edit or delete my review?',
         '一般情况下评价提交后不可修改或删除，请客观填写。若涉及违规内容或误评，可联系 support@link2ur.com 申请处理。',
         'Reviews generally cannot be edited or deleted after submission; please be fair. For policy violations or genuine errors, contact support@link2ur.com.', 2),
        ('reviews_reputation', '差评会怎样？', 'What happens with negative reviews?',
         '差评会展示在对方主页与任务历史中，供其他用户参考；恶意差评或虚假评价可能被平台处理并影响您自己的信用。',
         'Negative reviews are shown on the user''s profile and task history for others to see; fake or abusive reviews may be handled by the platform and affect your own reputation.', 3),
        -- 学生认证
        ('student_verification', '什么是学生认证？', 'What is student verification?',
         '用于验证您为在读学生，以访问部分仅限学生的板块、活动或权益。可选，但部分功能需认证后使用。',
         'It verifies you are a current student to access student-only categories, activities, or benefits. Optional, but some features require it.', 1),
        ('student_verification', '如何完成学生认证？', 'How to complete student verification?',
         '在「设置」或「个人资料」中找到学生认证入口，按提示提交学校邮箱或所需材料；审核通过后即可使用相关功能。',
         'Find the student verification option under Settings or Profile, then submit your school email or required documents; once approved, you can use the related features.', 2),
        ('student_verification', '认证失败或未通过怎么办？', 'What if verification fails?',
         '请检查提交的信息是否与学校记录一致；若认为误判可邮件 support@link2ur.com 并附上说明，我们会人工复核。',
         'Check that your details match school records. If you believe it was wrong, email support@link2ur.com with an explanation for manual review.', 3),
        -- 任务达人
        ('task_experts', '什么是任务达人？', 'What are task experts?',
         '任务达人是经平台审核、提供特定技能服务的用户（如辅导、设计等）。您可在「任务达人」页浏览达人与服务并预约。',
         'Task experts are platform-verified users offering specific services (e.g. tutoring, design). You can browse and book them on the Task Experts page.', 1),
        ('task_experts', '如何预约任务达人的服务？', 'How to book a task expert?',
         '在达人主页选择服务、填写时间与需求后提交申请；若需预付，请在约定时间内完成支付，支付成功后服务成立。',
         'On the expert''s page, choose a service, enter time and requirements, then submit. If prepayment is required, complete payment within the given time; the booking is confirmed after payment.', 2),
        ('task_experts', '如何成为任务达人？', 'How to become a task expert?',
         '在「任务达人」或页脚「合作与伙伴」入口提交申请，填写技能与经验；审核通过后即可创建服务并接收预约。接单前需完成收款账户绑定。',
         'Submit an application via Task Experts or the footer "Partners" link, with your skills and experience. After approval you can create services and receive bookings. You must link a payout account before taking orders.', 3),
        -- 活动与多人任务
        ('activities', '活动和普通任务有什么区别？', 'What is the difference between activities and tasks?',
         '活动通常为多人参与、可能有固定时间档或名额限制；普通任务多为单人接单。在活动页可查看参与方式与截止时间。',
         'Activities are often multi-participant with set time slots or capacity; regular tasks are usually single-person. Check the activity page for how to join and deadlines.', 1),
        ('activities', '如何报名活动？', 'How do I join an activity?',
         '在活动详情页点击报名，按提示选择时间档（如有）或填写意向；组织者接受后您会收到通知，按活动说明参与即可。',
         'On the activity detail page, tap to join and select a time slot (if any) or state your preference; once accepted you will get a notification — follow the activity instructions.', 2),
        -- 通知与消息
        ('notifications', '为什么收不到通知？', 'Why am I not receiving notifications?',
         '请检查：1）系统/浏览器是否允许通知权限；2）是否在设置中关闭了推送；3）登录状态是否有效。iOS 用户请在系统设置中允许 Link²Ur 通知。',
         'Check: 1) Notification permission in system/browser; 2) Push disabled in app settings; 3) You are logged in. iOS users: enable Link²Ur notifications in system settings.', 1),
        ('notifications', '消息和通知有什么区别？', 'What is the difference between messages and notifications?',
         '消息是您与对方（如任务方、买家/卖家）的对话；通知是系统对申请结果、任务状态、系统公告等的提醒。两者均可在「消息」或「通知」中查看。',
         'Messages are your conversations with others (e.g. task party, buyer/seller); notifications are system alerts for application results, task status, announcements. Both are in Messages or Notifications.', 2),
        -- 补充：账户与登录（已有 section）
        ('account_login', '如何修改邮箱或手机号？', 'How to change email or phone?',
         '请在「设置」或「账户与安全」中查找修改入口；部分修改需验证原邮箱/手机或重新验证。若找不到入口可邮件 support@link2ur.com。',
         'Find the change option under Settings or Account & Security; some changes require verifying your current email/phone. If you can''t find it, email support@link2ur.com.', 3),
        ('account_login', '如何注销账户？', 'How do I delete my account?',
         '请在「设置」中查找「注销账户」或「删除账户」并按提示操作。注销后数据将按《隐私政策》处理，且通常不可恢复。',
         'Look for "Delete account" or "Close account" under Settings and follow the steps. After deletion, data is handled per the Privacy Policy and usually cannot be restored.', 4),
        -- 补充：其他（已有 section）
        ('others', '优惠券/积分如何使用？', 'How to use coupons or points?',
         '在适用任务或场景的支付/结算页可选择可用优惠券或使用积分抵扣；具体规则以页面说明为准。积分可在「钱包」或「优惠券」页查看。',
         'On the payment/checkout page for eligible tasks or items, select a coupon or use points; see the page for rules. View balance under Wallet or Coupons.', 3),
        ('others', '排行榜是什么？', 'What is the leaderboard?',
         '排行榜用于展示用户或内容的人气与参与度（如投票、点赞等），具体规则以活动或板块说明为准。',
         'Leaderboards show popularity and engagement (e.g. votes, likes) for users or content; see the activity or category for rules.', 4)
    ) AS v(section_key, q_zh, q_en, a_zh, a_en, ord)
    JOIN faq_sections s ON s.key = v.section_key;

    RAISE NOTICE '✅ 更多 FAQ 分类与条目已添加（075）';
END;
$body$;
