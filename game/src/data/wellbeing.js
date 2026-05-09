// Body, mental health, and family-conflict events.
//
// The original game softpedaled both directions: family was uniformly warm,
// body went unmentioned, mental support stopped at the 4:38 AM crisis. This
// file fills the gaps:
//
// - Body: Vit D deficiency, weight gain from carb-heavy default eating, hair
//   loss from stress + hard water, period changes (gendered, optional).
// - Mental support infrastructure: SU Wellbeing, Mind/Samaritans helplines,
//   NHS Talking Therapies — the gentle entry points that exist between
//   "I'm fine" and "4:38 AM crisis".
// - Family conflict: career disagreements, marriage/relationship pressure,
//   father's health concern.

export const WELLBEING_EVENTS = {
  flat: [
    // ─── body / health ───
    {
      id: 'vitamin_d_deficiency', minWeek: 12, maxWeek: 22,
      title: '"你最近有点累 是不是缺维 D"',
      body: '你给妈视频。她看你 5 秒："你脸色不对。是不是没好好吃饭。"\n\n你说没事。她："伦敦冬天没太阳吧？" 你点头——12 月每天日照 4 小时不到。\n\n她："我让你姑给你寄维生素 D 片。你也去 Boots 自己买一瓶——一天一颗。" 你 google 一下：英国成人冬季 vit D 缺乏率 30%+，尤其有色人种。Boots 自家品牌 £4 一瓶。',
      choices: [
        { label: '去 Boots 买一瓶', effect: { wallet: -4, energy: 5, flag: 'vit_d_supp' },
          feedback: '你买了 1000 IU 一瓶。每天早上 1 颗。两周后你发现自己没那么常累了——这不是安慰剂，是真的。\n\n伦敦留学生第一个 winter 必学 vitamin D。' },
        { label: '"我不缺 没事"', effect: { energy: -5 },
          feedback: '你撑了 2 个月。3 月你做血检发现 Vit D 严重不足——GP 给开 prescription strength。早 2 个月吃 £4 的 supp 就行。' },
      ],
    },
    {
      id: 'pret_weight_gain', minWeek: 18, maxWeek: 30,
      title: '裤子勒了',
      body: '你早上穿那条来英国时新买的西裤——拉不上拉链。\n\n你站在镜前看 5 秒。Pret meal deal 80% 是 carb——你算了一下：sandwich 400 cal + Quavers 100 cal + Innocent 250 cal = 750 cal/午。一周 5 次 = 一周 3,750 多余 cal。\n\n3 个月 = 整整 1.5 公斤纯脂肪。',
      choices: [
        { label: '改去 Itsu / Pure 这种健康 chain', effect: { wallet: 0, energy: 3, flag: 'switched_food' },
          feedback: 'Itsu sushi box £6, Pure sweetgreen-style salad £8。比 Pret meal deal £5 贵一点。\n\n但你 3 周后发现——你不那么犯困了。腰围回去了。\n\n这是身体给你的反馈：Pret 是 default，不是命运。' },
        { label: '"算了 deadline 要紧 之后再说"', effect: { energy: -2 },
          feedback: '你继续 Pret meal deal。一年后你的西裤永远扣不上了——你回国第一件事是去优衣库买大一码。\n\n这是英国留学生隐性的 cost——身体也在变。' },
      ],
    },
    {
      id: 'hair_falling_out', minWeek: 25, maxWeek: 45,
      title: '梳子上一把头发',
      body: '你早上洗完头梳头——梳子上一把头发。地上、枕头上、bath tub 排水口都是。\n\n你 google "uk hard water hair loss"——伦敦水质硬度 high，长期会导致 hair shaft 损伤。+ 留学生 stress + 维 D 不足 = 大把掉。\n\nCSSA 群里 80% 中国女生 / 男生都吐槽过。',
      choices: [
        { label: '装 Boots £15 滤水头花洒', effect: { wallet: -15, energy: 1, flag: 'water_filter' },
          feedback: '你装上滤水头花洒。3 周后掉发减半。\n\n这是英国留学生最便宜的"养发"投资——£15 比国内任何治疗都管用。' },
        { label: '"反正回国就好" 不管', effect: { energy: -3, belonging: -2 },
          feedback: '你撑到毕业。回国第一年发量比来时少 30%。\n\n伦敦的硬水留下了一个长期的痕迹。' },
      ],
    },

    // ─── mental health support infrastructure ───
    {
      id: 'su_wellbeing_referral', minWeek: 8, maxWeek: 40,
      title: 'SU Wellbeing · 1:1 预约',
      body: '你这两周睡不着，吃不下，没动力。你 google 了一下"我是不是抑郁"——一个 Mind 网站的自评测试给你 18/27（moderate-severe）。\n\n你查到学校 Student Union Wellbeing：免费 1:1 talk session，30 分钟，不需要 GP 转介。online booking 系统，最快下周二。\n\n你点了一下预约。光标停在 "Confirm" 按钮上。',
      choices: [
        { label: '点 confirm 预约', effect: { energy: -3, belonging: 8, flag: 'su_wellbeing_booked' },
          feedback: '你点了。系统秒发 confirmation 邮件。\n\n下周二你坐在 SU Wellbeing 一个安静的小房间。Counsellor 是个 40 岁的英国女性，她说 "Hi, what brings you in today?" \n\n你哭了 5 分钟才说出第一句话。她递了一盒纸巾，没催。\n\n这是你来英国第一次跟人说"我不太好"。' },
        { label: '"我自己能撑过去" 关网页', effect: { energy: -5, belonging: -3 },
          feedback: '你关了网页。"我又没有那么糟"。\n\n但 3 周后你又来到这个网页前。这种来回会持续一段。\n\n你不知道哪天你会真的点 confirm——但每一次的 hesitation 也算 progress。' },
      ],
    },
    {
      id: 'samaritans_late_night', minWeek: 10, maxWeek: 50,
      title: '凌晨 3 点 · Samaritans 116 123',
      body: '凌晨 3 点。你睡不着。脑子里反复："我是不是不该来"。\n\n你 google "uk free helpline depression"——第一条：Samaritans, free 24/7 helpline, 116 123。\n\nSamaritans 是英国最大的非营利心理热线。任何人，任何时候，免费。\n\n你的手机静静放在床头柜上。',
      choices: [
        { label: '拨 116 123', effect: { energy: 3, belonging: 8, flag: 'samaritans_called' },
          feedback: '响了 2 声。一个 50 岁声音的英国女性接："Samaritans, this is Jenny. I\'m here to listen."\n\n你说"I don\'t know why I called"。她说 "That\'s OK. We can sit with that together."\n\n你们说了 40 分钟——你说了一些从没跟妈说过的事。她不评判，不给建议，就听。\n\n挂电话时你哭得一团乱。但你睡着了——这一周第一次。' },
        { label: '把手机翻过去 装睡', effect: { energy: -8, belonging: -3 },
          feedback: '你闭上眼睛。脑子还在转。\n\n你不知道下次你会不会拨。但你记住了那个号码——这就够了。\n\n116 123。下次你需要的时候你会想起来。' },
      ],
    },
    {
      id: 'nhs_talking_therapies', minWeek: 15, maxWeek: 50,
      title: 'NHS Talking Therapies · 自助申请',
      body: '你 google "uk free therapy NHS"——第一条：NHS Talking Therapies (formerly IAPT)。\n\n免费、自助 referral、不需要 GP 介绍信、6-12 周 CBT。问题：等候期 6-12 周。\n\n你点开 self-referral 链接——20 个问题：你最近怎么样？睡眠？食欲？社交？',
      condition: ({ flags }) => flags.gp_registered,
      choices: [
        { label: '认真填完表', effect: { energy: -5, flag: 'nhs_therapy_referred' },
          feedback: '你填了 20 分钟。提交后 1 周收到 phone screening——一个 nurse 跟你 30 分钟，确认你是 mild-moderate depression。\n\n排队 8 周。8 周后你开始每周 1 次 CBT。\n\n免费。这是 NHS 给所有合法居住者（包括 BRP 持有者）的 invisible safety net。' },
        { label: '"我自己看小红书心理博主"', effect: { energy: -3 },
          feedback: '你跟着小红书做了 1 周冥想 app。停了。\n\n小红书心理博主的内容不是 evidence-based therapy。但你也不打算正式去——这种事走的弯路最长。' },
      ],
    },

    // ─── family conflict (extending parents storyline with darker beats) ───
    {
      id: 'mom_career_pressure', minWeek: 15, maxWeek: 30,
      title: '妈说"找份稳定工作"',
      body: '周日晚视频。妈"问问而已"："你毕业准备做什么？"\n\n你说还在想——也许 startup、也许 NGO、也许 PhD。\n\n她："你王阿姨女儿今年中信银行管培生 25 万年薪 + 户口。你那个英国 startup 月薪多少？"\n\n你算了一下——£35k 起 = 月 £2900 = ¥27000。比中信少。但你也不想这么算。',
      choices: [
        { label: '"妈我有自己的节奏"', effect: { energy: -5, belonging: 4, flag: 'pushed_back_career' },
          feedback: '妈妈愣了 3 秒。"行 你自己想清楚。"\n\n她不再问。但你知道这话题没完——明年她还会问王阿姨女儿现在年薪多少。\n\n你也知道——她不是不爱你。她是在用她的指标爱你。' },
        { label: '附和 "我也在考虑回国"', effect: { energy: 2, belonging: 8, flag: 'softened_career' },
          feedback: '妈妈安心了 5 秒。然后说："不勉强 但你考虑下。妈托人帮你看看。"\n\n你挂电话坐在床上想：我刚才答应的是为了让她安心 还是因为我也确实想？我自己都分不清了。' },
      ],
    },
    {
      id: 'dad_hospital_news', minWeek: 25, maxWeek: 45,
      title: '爸住院了',
      body: '凌晨 5 点（伦敦），你妈打来视频。她声音紧张。\n\n"你别担心。你爸今天突然心绞痛 在医院做了支架手术。已经稳定了。我刚才是不想吓你 才没第一时间打。"\n\n你坐起来——心跳很快。\n\n"你别回来。手术做完了 没事。下个月放假回来一趟 你爸想见你。"',
      choices: [
        { label: '订当天的机票回国', effect: { wallet: -1200, energy: -15, belonging: 25, flag: 'flew_home_emergency' },
          feedback: '你订了 18 小时后的机票。£1,200——回程经济舱不退不改。\n\n你爸看到你那一刻在病床上："你怎么回来了？妈不是说让你别回来吗？"\n\n你说"我想见你"。他眼眶红了。然后他说："飞机贵不贵？"\n\n这就是中国父亲——支架做完第一句话还在算飞机钱。' },
        { label: '不回 + 每天视频', effect: { energy: -10, belonging: 12, flag: 'video_called_dad' },
          feedback: '你每天给爸打视频。他出院后说："你好好读书。妈说你最近瘦了——好好吃饭。"\n\n你听话地点头。但你心里那个"我没回去"的疙瘩一直在。\n\n这一年你欠了爸一次见面。下次回家你会还。' },
        { label: '"妈 我不知道怎么办" 哭', effect: { energy: -8, belonging: 4 },
          feedback: '你哭了 5 分钟说不出话。妈妈在那头沉默地等。\n\n最后她说："你哭吧。妈陪你。"\n\n你们 video 静静开了 1 小时。她在国内厨房做饭，你在英国床上发呆。\n\n这是你这一年最长的一次"陪着"。' },
      ],
    },
    {
      id: 'mom_marriage_pressure_with_partner', minWeek: 20, maxWeek: 40,
      title: '妈说"也该考虑这事了" · 你有 partner',
      condition: ({ flags }) => !!flags.linnan_dating,
      body: '春节视频。妈 casual："你今年 23 / 24 / 25 了。你王阿姨女儿订婚了 男方北京户口 + 房 + 车。"\n\n她："妈不催你。但你也该考虑这事了。"\n\n你脑子里在转——林可儿 / 林楠还没让你妈知道。',
      choices: [
        { label: '"妈我有 partner 了 林可儿 / 林楠 同班同学"', effect: { energy: -5, belonging: 8, flag: 'told_mom_partner' },
          feedback: '你说出来了。妈愣 5 秒："噢。" 又 5 秒。"杭州 / 北京人？" "杭州。" "做什么的？" "本科金融转社会学。"\n\n你能听见她在重新校准。最后她说"那 那以后带回来给我看看"。\n\n这是开始。不是终点。' },
        { label: '"妈别催 我自己有数"', effect: { energy: -3, belonging: 2 },
          feedback: '妈："你哪有数。" 然后她沉默了。\n\n你瞒了。但你知道——这种事瞒一年算一年，瞒两年瞒不住。' },
      ],
    },
    {
      id: 'mom_marriage_pressure_solo', minWeek: 20, maxWeek: 40,
      title: '妈说"也该考虑这事了"',
      condition: ({ flags }) => !flags.linnan_dating,
      body: '春节视频。妈 casual："你今年 23 / 24 / 25 了。你王阿姨女儿订婚了 男方北京户口 + 房 + 车。"\n\n她："妈不催你。但你也该考虑这事了。"',
      choices: [
        { label: '"妈别催 我自己有数"', effect: { energy: -3, belonging: 2 },
          feedback: '妈："你哪有数。" 然后她沉默了。\n\n你知道这次没说服她。但你也知道——她不是恶意。她在用她那代人的剧本爱你。' },
        { label: '"我可能不结婚"', effect: { energy: -8, belonging: -3, flag: 'told_mom_not_marrying' },
          feedback: '妈愣了 10 秒："你别瞎说。"\n\n你不解释。她也不追问。但这次视频之后她少打了 2 周。\n\n这种事在中国家庭，第一次说出来都是这样。下一次她会习惯一点点。' },
        { label: '附和 "我会考虑的"', effect: { energy: 1, belonging: 4 },
          feedback: '你说"我会考虑的"。妈安心了 5 秒。\n\n你不知道你说这话是 truth、是 white lie、还是只是想结束这通电话。但她笑了。' },
      ],
    },
  ],
};
