-- Add comprehensive missing sensitive words to the production database
-- Each INSERT uses NOT EXISTS to prevent duplicates

-- ── 广告/推广 (ad) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '日入千元', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '日入千元');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '躺赚', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '躺赚');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '零投资', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '零投资');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '不需要本金', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '不需要本金');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '在家赚钱', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '在家赚钱');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '轻松月入', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '轻松月入');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '招聘打字员', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '招聘打字员');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '手机兼职', 'ad', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '手机兼职');

-- ── 中介 (agent) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '代做作业', 'agent', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '代做作业');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '包通过', 'agent', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '包通过');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '代挂', 'agent', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '代挂');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '买卖账号', 'agent', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '买卖账号');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '代刷', 'agent', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '代刷');

-- ── 诈骗 (scam) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '日化收益', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '日化收益');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '保证收益', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '保证收益');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '零风险', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '零风险');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '资金盘', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '资金盘');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '传销', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '传销');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '庞氏骗局', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '庞氏骗局');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '拉人头', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '拉人头');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '发展下线', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '发展下线');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '虚拟货币投资', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '虚拟货币投资');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '外汇操盘', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '外汇操盘');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '跑分', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '跑分');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '刷流水', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '刷流水');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '洗白', 'scam', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '洗白');

-- ── 色情 (porn) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '嫖娼', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '嫖娼');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '卖淫', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '卖淫');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '招嫖', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '招嫖');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '包夜', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '包夜');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '小姐服务', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '小姐服务');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '上门服务', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '上门服务');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '特殊服务', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '特殊服务');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '全套服务', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '全套服务');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '陪睡', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '陪睡');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '色诱', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '色诱');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT 'AV', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = 'AV');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '成人网站', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '成人网站');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '裸照', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '裸照');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '自慰', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '自慰');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '性交易', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '性交易');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '约会交友', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '约会交友');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '同城约', 'porn', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '同城约');

-- ── 毒品 (drugs) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '毒品', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '毒品');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '制毒', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '制毒');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '禁药', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '禁药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '麻醉品', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '麻醉品');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '可卡因', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '可卡因');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '鸦片', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '鸦片');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '安非他命', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '安非他命');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '致幻剂', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '致幻剂');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '迷幻药', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '迷幻药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '迷药', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '迷药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '迷魂药', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '迷魂药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '听话水', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '听话水');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '春药', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '春药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '催情药', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '催情药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '麻古', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '麻古');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '神仙水', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '神仙水');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '笑气', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '笑气');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '芬太尼', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '芬太尼');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT 'LSD', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = 'LSD');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '冰壶', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '冰壶');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '溜冰', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '溜冰');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '打飞机针', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '打飞机针');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '嗑药', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '嗑药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '飞叶子', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '飞叶子');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '上头', 'drugs', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '上头');

-- ── 赌博 (gambling) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '赌球', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '赌球');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '赌马', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '赌马');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '地下赌场', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '地下赌场');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '赌注', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '赌注');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '下注', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '下注');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '彩票预测', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '彩票预测');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '时时彩', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '时时彩');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '北京赛车', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '北京赛车');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '幸运飞艇', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '幸运飞艇');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '竞猜', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '竞猜');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '押注', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '押注');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '赔率', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '赔率');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '庄家', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '庄家');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '外围', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '外围');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '赌资', 'gambling', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '赌资');

-- ── 暴力 (violence) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '杀人', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '杀人');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '砍人', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '砍人');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '买枪', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '买枪');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '卖枪', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '卖枪');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '炸药', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '炸药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '雷管', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '雷管');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '弹药', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '弹药');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '管制刀具', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '管制刀具');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '自杀', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '自杀');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '跳楼', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '跳楼');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '割腕', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '割腕');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '雇凶', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '雇凶');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '报仇', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '报仇');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '寻仇', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '寻仇');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '恐怖袭击', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '恐怖袭击');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '人肉搜索', 'violence', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '人肉搜索');

-- ── 违法 (illegal) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '逃税', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '逃税');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '行贿', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '行贿');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '受贿', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '受贿');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '贪污', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '贪污');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '诈骗', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '诈骗');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '盗窃', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '盗窃');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '抢劫', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '抢劫');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '绑架', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '绑架');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '勒索', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '勒索');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '敲诈', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '敲诈');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '偷渡', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '偷渡');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '黑户', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '黑户');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '假护照', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '假护照');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '假签证', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '假签证');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '买卖器官', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '买卖器官');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '非法集资', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '非法集资');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '高利贷', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '高利贷');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '套路贷', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '套路贷');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '裸贷', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '裸贷');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '黑客', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '黑客');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '破解软件', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '破解软件');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '盗号', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '盗号');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '钓鱼网站', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '钓鱼网站');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '信用卡套现', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '信用卡套现');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '代开发票', 'illegal', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '代开发票');

-- ── 脏话 (profanity) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '草泥马', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '草泥马');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '妈逼', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '妈逼');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '贱人', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '贱人');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '婊子', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '婊子');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '狗日的', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '狗日的');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '王八蛋', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '王八蛋');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '滚蛋', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '滚蛋');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '废物', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '废物');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '死全家', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '死全家');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '你妈死了', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '你妈死了');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '智障', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '智障');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '弱智', 'profanity', 'review', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '弱智');

-- ── 联系方式 (contact) ──
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '加好友', 'contact', 'mask', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '加好友');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT 'WhatsApp', 'contact', 'mask', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = 'WhatsApp');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT 'Telegram', 'contact', 'mask', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = 'Telegram');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '飞机群', 'contact', 'mask', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '飞机群');
INSERT INTO sensitive_words (word, category, level, is_active, created_at) SELECT '电报群', 'contact', 'mask', true, NOW() WHERE NOT EXISTS (SELECT 1 FROM sensitive_words WHERE word = '电报群');

-- ── 新增谐音映射 ──
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'weixin', '微信', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'weixin');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'wechat', '微信', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'wechat');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'qq', 'QQ', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'qq');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'du品', '毒品', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'du品');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '独品', '毒品', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '独品');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '毐品', '毒品', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '毐品');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'da麻', '大麻', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'da麻');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '大ma', '大麻', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '大ma');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '冰du', '冰毒', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '冰du');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '兵毒', '冰毒', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '兵毒');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '串销', '传销', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '串销');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'chuanxiao', '传销', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'chuanxiao');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '电报', 'Telegram', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '电报');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'TG群', 'Telegram', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'TG群');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT 'tg群', 'Telegram', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = 'tg群');
INSERT INTO homophone_mappings (variant, standard, is_active) SELECT '飞机', 'Telegram', true WHERE NOT EXISTS (SELECT 1 FROM homophone_mappings WHERE variant = '飞机');
