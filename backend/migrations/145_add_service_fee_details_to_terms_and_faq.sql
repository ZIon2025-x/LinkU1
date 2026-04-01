-- ===========================================
-- 迁移文件145：服务费率明细 — 更新法律文档 + 新增 FAQ
-- 在 terms 法律文档中补充服务费率明细表，
-- 在 FAQ 中新增「费用与支付」分区及服务费相关问答
-- ===========================================

DO $body$
BEGIN

    -- ========== 1. 更新 legal_documents: terms (zh) ==========
    UPDATE legal_documents
    SET content_json = jsonb_set(
        jsonb_set(
            jsonb_set(
                content_json,
                '{feesAndRules,serviceFeeSchedule}',
                '"服务费率明细：不同业务类型适用不同的服务费率，具体如下：\n• 普通任务：10%，最低 £1.00\n• 指定用户任务：8%，最低 £0.50\n• 达人服务 / 个人服务：8%，最低 £0.50\n• 达人活动：5%，最低 £0.50\n• 跳蚤市场（出售与租赁）：8%，最低 £0.50\n服务费 = max(最低服务费, 任务金额 × 费率)，且不超过任务金额本身。VIP 会员可享受服务费减免，具体优惠以会员中心页面公示为准。平台保留根据运营需要调整上述费率的权利，调整后将通过公告或通知方式告知用户。"'::jsonb,
                true
            ),
            '{feesAndRules,serviceFeePayerNote}',
            '"服务费由任务发布者承担，在支付任务金额时一并收取。任务接受者（服务提供者）收到的金额为任务金额全额，不额外扣除服务费。"'::jsonb,
            true
        ),
        '{feesAndRules,applicationFee}',
        '"平台服务费：平台会从任务金额中扣除服务费。服务费计算规则如下：\n• 微型任务（任务金额 < 10镑）：固定收取 1 镑作为微型任务服务费\n• 普通任务（任务金额 ≥ 10镑）：按任务金额的 10% 收取服务费\n服务费包括但不限于：支付转账手续费、平台运营成本（服务器、带宽、系统维护等）、人力成本（客服支持、技术开发、运营管理等）、风险保障金以及其他平台运营所需的合理费用。服务费用于维护平台运营、提供技术支持和服务保障。具体费率以平台公示为准。"'::jsonb,
        true
    ),
        updated_at = NOW()
    WHERE type = 'terms' AND lang = 'zh';

    -- ========== 2. 更新 legal_documents: terms (en) ==========
    UPDATE legal_documents
    SET content_json = jsonb_set(
        jsonb_set(
            jsonb_set(
                content_json,
                '{feesAndRules,serviceFeeSchedule}',
                '"Service Fee Schedule: Different service types are subject to different fee rates as follows:\n• Regular Tasks: 10%, minimum £1.00\n• Assigned User Tasks: 8%, minimum £0.50\n• Expert Services / Personal Services: 8%, minimum £0.50\n• Expert Activities: 5%, minimum £0.50\n• Flea Market (Sales & Rentals): 8%, minimum £0.50\nService Fee = max(Minimum Fee, Task Amount × Rate), and shall not exceed the task amount itself. VIP members may enjoy reduced service fees; specific discounts are shown in the Membership Centre. The platform reserves the right to adjust the above rates as needed; changes will be communicated via announcements or notifications."'::jsonb,
                true
            ),
            '{feesAndRules,serviceFeePayerNote}',
            '"The service fee is borne by the task poster and collected together with the task payment. The task taker (service provider) receives the full task amount with no additional service fee deducted."'::jsonb,
            true
        ),
        '{feesAndRules,applicationFee}',
        '"Platform Service Fee: The platform deducts a service fee from the task amount. The service fee calculation rules are as follows:\n• Micro Tasks (Task Amount < £10): A fixed fee of £1 is charged as the Micro Task Service Fee\n• Regular Tasks (Task Amount ≥ £10): A service fee of 10% of the task amount is charged\nThe service fee includes but is not limited to: payment transfer fees, platform operating costs (servers, bandwidth, system maintenance, etc.), human resource costs (customer support, technical development, operations management, etc.), risk guarantee funds, and other reasonable costs required for platform operations. The service fee is used to maintain platform operations, provide technical support and service guarantees. Specific rates are displayed on the platform."'::jsonb,
        true
    ),
        updated_at = NOW()
    WHERE type = 'terms' AND lang = 'en';

    RAISE NOTICE '✅ 法律文档 terms 已补充服务费率明细（145）';

    -- ========== 3. 新增 FAQ 分区：费用与支付 ==========
    INSERT INTO faq_sections (key, title_zh, title_en, sort_order)
    VALUES ('fees_payment', '费用与支付', 'Fees & Payment', 15)
    ON CONFLICT (key) DO NOTHING;

    -- ========== 4. 新增 FAQ 条目 ==========
    INSERT INTO faq_items (section_id, question_zh, question_en, answer_zh, answer_en, sort_order)
    SELECT s.id, v.q_zh, v.q_en, v.a_zh, v.a_en, v.ord
    FROM (VALUES
        ('fees_payment',
         '平台服务费是多少？',
         'How much is the platform service fee?',
         '服务费根据业务类型有所不同：\n• 普通任务：任务金额的 10%，最低 £1.00\n• 指定用户任务：8%，最低 £0.50\n• 达人服务 / 个人服务：8%，最低 £0.50\n• 达人活动：5%，最低 £0.50\n• 跳蚤市场（出售与租赁）：8%，最低 £0.50\n如果按比例计算的费用低于最低金额，则按最低金额收取。您可以在任务详情页查看具体的服务费比例和金额。',
         'The service fee varies by service type:\n• Regular Tasks: 10% of the task amount, minimum £1.00\n• Assigned User Tasks: 8%, minimum £0.50\n• Expert Services / Personal Services: 8%, minimum £0.50\n• Expert Activities: 5%, minimum £0.50\n• Flea Market (Sales & Rentals): 8%, minimum £0.50\nIf the calculated fee is below the minimum, the minimum fee applies. You can view the exact fee rate and amount on the task detail page.',
         1),
        ('fees_payment',
         '服务费由谁承担？',
         'Who pays the service fee?',
         '服务费由任务发布者承担，在支付任务金额时一并收取。任务接受者（服务提供者）收到的是任务金额全额，不会被额外扣除服务费。例如：发布一个 £50 的普通任务，发布者需支付 £50（任务金额）+ £5（10% 服务费）= £55，接受者完成任务后将收到 £50。',
         'The service fee is paid by the task poster and collected at the time of payment. The task taker (service provider) receives the full task amount without any additional deduction. For example: posting a £50 regular task, the poster pays £50 (task amount) + £5 (10% service fee) = £55, and the taker receives £50 upon completion.',
         2),
        ('fees_payment',
         'VIP 会员有服务费优惠吗？',
         'Do VIP members get a discount on service fees?',
         '是的，VIP 会员可享受服务费减免优惠。具体折扣比例以「设置」→「会员中心」页面公示为准。升级 VIP 后，发布任务时系统会自动按优惠费率计算服务费。',
         'Yes, VIP members enjoy reduced service fees. The specific discount is shown in Settings → Membership Centre. After upgrading to VIP, the system will automatically apply the discounted rate when you post tasks.',
         3),
        ('fees_payment',
         '服务费包含哪些内容？',
         'What does the service fee cover?',
         '服务费包括但不限于：支付与转账手续费（Stripe 处理费用）、平台运营成本（服务器、带宽、系统维护等）、人力成本（客服支持、技术开发、运营管理等）、风险保障金以及其他平台运营所需的合理费用。服务费用于维持平台的稳定运行，为用户提供安全可靠的交易环境。',
         'The service fee covers: payment and transfer processing fees (Stripe charges), platform operating costs (servers, bandwidth, system maintenance, etc.), human resource costs (customer support, technical development, operations management, etc.), risk guarantee funds, and other reasonable operating expenses. It helps maintain stable platform operations and a safe, reliable transaction environment for users.',
         4),
        ('fees_payment',
         '为什么不同类型的任务费率不同？',
         'Why are fee rates different for different task types?',
         '不同业务类型的运营成本和服务复杂度有所差异。例如，达人活动因平台提供额外的活动管理和推广支持，费率相对较低（5%）以鼓励更多活动发布；而普通任务涉及完整的任务匹配、托管和纠纷处理流程，费率为 10%。平台会持续优化费率结构，为各类用户提供合理的定价。',
         'Different service types have varying operational costs and service complexity. For example, expert activities benefit from a lower rate (5%) as an incentive for more activity creation, while regular tasks involve full task matching, escrow, and dispute resolution, hence the 10% rate. The platform continuously optimises its fee structure to provide fair pricing for all users.',
         5),
        ('fees_payment',
         '在哪里可以看到服务费？',
         'Where can I see the service fee?',
         '您可以在以下位置查看服务费：\n1. 任务详情页 — 显示该任务的服务费比例和金额\n2. 支付确认页 — 在支付前会显示任务金额、服务费和应付总额的明细\n3. 用户服务条款 — 在「设置」→「用户服务条款」的「费用与平台规则」章节可查看完整的费率说明',
         'You can view service fees in the following places:\n1. Task Detail Page — shows the service fee rate and amount for that task\n2. Payment Confirmation Page — displays a breakdown of the task amount, service fee and total due before payment\n3. Terms of Service — the full fee schedule is in the "Fees and Platform Rules" section under Settings → Terms of Service',
         6)
    ) AS v(section_key, q_zh, q_en, a_zh, a_en, ord)
    JOIN faq_sections s ON s.key = v.section_key
    WHERE NOT EXISTS (
        SELECT 1 FROM faq_items fi
        WHERE fi.section_id = s.id AND fi.question_zh = v.q_zh
    );

    RAISE NOTICE '✅ 费用与支付 FAQ 已添加（145）';

END;
$body$;
