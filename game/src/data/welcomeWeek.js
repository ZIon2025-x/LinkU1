// "攻略级" Welcome Week / new-student events.
//
// These are timed location events: they fire when the player enters a specific
// location during a target window (usually W1-W2 for setup, W4+ for daigou).
//
// `auto: true` events fire deterministically (no 50% roll) and are intended
// as mandatory orientation beats — BRP collection, enrollment, etc.
//
// `maxWeek` is a new field; the engine filters events past their max week so
// e.g. "freshers fair" doesn't fire in March. This is added in App.jsx's event
// pipeline alongside the existing minWeek check.
//
// Numbers (prices, fees, durations) are calibrated to actual UK student
// experience as of mid-2020s — meant to be useful as an actual primer.

export const WELCOME_WEEK_EVENTS = {
  // ─────────────────────────────────────────────────────────────
  // FLAT — personal admin you do from your bedroom
  // ─────────────────────────────────────────────────────────────
  flat: [
    {
      id: 'survival_brief', auto: true, minWeek: 1, maxWeek: 1,
      title: '室友 Day 1 · "活下来手册"',
      body: '搬进来第二天早上。你在共用厨房遇到一个已经熬过一年的 housemate——King\'s 二年级的女生，正用一个掉漆的摩卡壶煮咖啡。\n\n她递给你一杯："新来的吧？告诉你几件事——一年前没人提醒过我。"\n\n· 你**一天能做的事就那么几件**——上课、跑腿、吃饭、社交,够呛超过 5 件。压力一上来,只剩 3 件、甚至 1 件，别问我怎么知道的。\n· **一天至少吃 2 顿**。漏一顿，半夜饿得受不了就点 Deliveroo，一份 £15。漏两顿压力直接涨 8 点——比挨饿本身更狠的是那 8 点压力。\n· 卡里 £1,200 + 妈每月 £500。**钱包真见底就回不去了**——别问我那个学姐去年回国前的事。\n· 压力涨到 75 你一天只能做 3 件,85 只剩 1 件,95……我没见过有人撑过来。\n\n"app 里 Link2Ur 那个蓝色图标点开看看。跑腿赚钱、发 post 让别人帮你都靠它。第一个月撑过去就活了。"',
      choices: [
        { label: '"记下来。谢了。"',
          effect: { energy: 0, belonging: 3, flag: 'survival_briefed' },
          feedback: '她耸耸肩："不客气。我去年没人跟我说，12 月那会儿差点崩了。"\n\n她拎着咖啡杯回房间。门关上前补了一句："app 里那个会发消息的小 U——别忽略它。它说话的时候通常是真的有事。"' },
      ],
    },
    {
      id: 'first_night_insomnia', minWeek: 1, maxWeek: 2,
      title: '第一晚 · 凌晨 4 点',
      body: '凌晨 4:12。你醒在自己的房间里。\n\n8 小时时差——国内现在是中午 12 点。你妈在做饭，你爸在午睡。\n\n你听见走廊有声音——大概是 Mark 从厨房回房间。墙是纸糊的，你能听见他袜子在地板上拖的声音。\n\n你盯着天花板。脑子转个不停——BRP 还没取，GP 还没注册，reading list 一页没碰。',
      choices: [
        { label: '硬闭眼数羊 + 等天亮',
          effect: { energy: -3, stress: 2 },
          feedback: '你闭上眼。脑子里反复在播 "下周一第一节课是什么"。\n\n7 点闹钟响时你还醒着。早上 lecture 你全程在打瞌睡。' },
        { label: '下楼煮一碗白象方便面',
          effect: { wallet: -1, energy: 3, belonging: 2 },
          feedback: '你蹑手蹑脚下楼。厨房是空的——Mark 已经回房了。\n\n你煮了一碗老坛酸菜。第一口热汤下去——时差缓和了 30%。\n\n你坐在凌晨 4 点的厨房里看着窗外的伦敦夜——很安静，但你不孤独。' },
        { label: '不睡了 + 翻开 reading list 第一页',
          effect: { energy: -5, academic: 3, stress: -2 },
          feedback: '你翻开 Foucault。读到第 4 页发现自己大概只懂 30%。\n\n但你也读完了 reading list 第一周的 1/3——比 cohort 里 80% 的人都早。\n\n早上 9 点的 lecture 你坐第一排——眼睛红红的，Whitmore 注意到了。' },
      ],
    },
    {
      id: 'first_video_call_mom', auto: true, minWeek: 1, maxWeek: 1,
      title: '第一次给妈视频',
      body: '伦敦下午 6 点 = 国内凌晨 1 点。你之前跟妈说"到了就报平安"，但忘了时差。\n\n你按下视频键——3 秒后妈接了。她在客厅，头发乱乱的，显然刚被吵醒。但她笑得像没事一样。\n\n"到了啊？公寓什么样？让妈看看。"',
      choices: [
        { label: '镜头扫一圈房间 + 跟她聊几句',
          effect: { energy: -2, belonging: 12, flag: 'first_mom_call' },
          feedback: '你把镜头转过去——11 平米的单人间、独立卫浴、Tesco 黄色塑料袋还堆在角落。\n\n你妈："哎呀挺小的，不过独立卫浴好，你那点东西够用了。" 然后她突然问："晚饭吃了吗？"\n\n你说还没。她沉默了 3 秒——你能从屏幕里看出来，她在想这一刻能不能给你做点什么——然后她说："那你下楼买点。妈在国内，管不到你。"\n\n挂电话之后你坐在床边 5 分钟没动。' },
        { label: '简短报平安 + "你睡吧"',
          effect: { energy: 0, belonging: 5, flag: 'first_mom_call' },
          feedback: '你说："到了，安全。你睡。"\n\n她说："行，我睡了。" 30 秒挂电话。\n\n挂完她又给你发了 5 条微信:\n· "记得多穿"\n· "wifi 怎么样"\n· "邻居怎么样"\n· "晚饭别忘"\n· "妈睡了，你忙"\n\n你每条回了一个"嗯"。' },
      ],
    },
    {
      id: 'brp_reminder', auto: true, minWeek: 1, maxWeek: 1,
      title: 'BRP · 10 天内必须取',
      body: '你刚醒。手机里一封 UKVI 的邮件——\n\n"Collect your Biometric Residence Permit at Acton Lane Post Office, within 10 days of arrival."\n\n你 google 了一下：BRP 是英国身份证 +居留卡，粉色塑料卡。开银行、续租房、回国回签都要它。错过 10 天罚 £125，还可能影响以后续签。',
      choices: [
        { label: '今天就去（去 King\'s Cross 站搭公交）', effect: { energy: -2, flag: 'brp_pending' },
          feedback: '你穿外套出门——具体取卡需要去到那个邮局排队，今天先把这事记上日程。\n\n（下次去车站时会有"BRP 取证"的事件）' },
        { label: '记下来 周内去', effect: { energy: 0, flag: 'brp_pending' },
          feedback: '你在便签上写："Acton Post Office · BRP · 周五前"。贴在镜子边。' },
      ],
    },
    {
      id: 'gp_register', minWeek: 1, maxWeek: 8,
      title: '注册 GP · 免费看病',
      body: '宿舍楼下贴了张海报："Register with your local GP — free for international students with BRP."\n\n你 google 了一下：GP（家庭医生）是 NHS 的入口，看病全免费但要预约。注册要填一张 GMS1 表，10 分钟搞定。问题是预约一般等 1-2 周——别等到生病才注册。',
      choices: [
        { label: '走 10 分钟去 Surgery 填表', effect: { energy: -3, belonging: 4, flag: 'gp_registered' },
          feedback: 'Bloomsbury Surgery。前台递给你一张 GMS1 表：地址、护照号、BRP 号、过敏史。\n\n两周后你收到 NHS number 信。塞进抽屉。这是你之后任何时候生病的底牌。' },
        { label: '"我没病 不办了"', effect: { energy: 0 },
          feedback: '三个月后你重感冒咳得睡不着，临时挂号要等到下下周——那个周末你是在床上熬过去的。' },
      ],
    },
    {
      id: 'open_monzo', minWeek: 1, maxWeek: 4,
      title: '开 UK 银行卡',
      body: 'App Store 第一名是 Monzo——下载 + 上传 BRP 自拍 + 5 分钟卡寄出。\n\nHSBC / Barclays 要 enrolment letter + 排队 1 周，但提供大学推荐的 student account。',
      choices: [
        { label: 'Monzo · 5 分钟搞定', effect: { energy: -1, flag: 'monzo_open' },
          feedback: '黄色实体卡 3 天到。手机 App 实时记账，最受留学生欢迎。\n\n你妈下次给你转钱直接 sort code 6 位 + account number 8 位，比国内的 IBAN 简单多了。' },
        { label: 'HSBC · 排 1 小时换 student bonus', effect: { energy: -8, flag: 'hsbc_open' },
          feedback: '排了 1 小时给你开了张 student account。送一张 Amazon £80 voucher。但 App 慢得要命，转账还要二次密码。\n\n能用，但你之后所有日常消费还是用 Monzo。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // UNI — student services and Welcome Week setup
  // ─────────────────────────────────────────────────────────────
  uni: [
    {
      id: 'enrolment', auto: true, minWeek: 1, maxWeek: 1,
      title: 'Enrolment · 学生注册',
      body: 'Welcome Week。Student Services 排了一长队。\n\n你出示 CAS letter、护照、BRP 收据（暂时还没真卡）。工作人员核对后给你打印了一张学生卡——这张卡是图书馆门禁、打印费、学生折扣的全部。',
      choices: [
        { label: '完成注册 拿学生卡', effect: { academic: 4, energy: -5, flag: 'enrolled' },
          feedback: '你拿到学生卡，别在外套口袋。\n\n工作人员还递给你两份纸：\n· "Council Tax Exemption Certificate"——拿着这张联系区政府，能省 £100-150/月\n· "Enrolment Letter"——TFL Student Oyster 申请用，30% 通勤折扣\n\n两张纸都是钱。' },
      ],
    },
    {
      id: 'student_oyster', minWeek: 1, maxWeek: 6,
      title: '18+ Student Oyster 申请',
      body: '同学群里有人 @所有人："你 student oyster 办了吗？没办的话每天通勤多花 30%。"\n\n你 google 了一下：申请要 £20 admin fee + 一张照片 + 学校开的 enrolment letter。在 TFL 网站在线提交。卡 5 个工作日寄到。',
      choices: [
        { label: '今晚在线申请', effect: { wallet: -20, energy: -3, flag: 'student_oyster' },
          feedback: '£20 一次性。卡 5 天寄到。\n\n你算了一下：12 个月通勤本来 £1200，30% 折扣省 £360。这 £20 投资回报率史上最高。' },
        { label: '"算了 我地铁少坐"', effect: { energy: 1 },
          feedback: '一周后你看 Tube 账单：£18 一周。年化 £900+。你心里咯噔了一下。' },
      ],
    },
    {
      id: 'council_tax_exempt', minWeek: 1, maxWeek: 8,
      title: 'Council Tax 豁免',
      body: '室友提醒："你 council tax exemption letter 发了吗？没发的话每月扣 £100-150。"\n\n你拿 enrolment 那天发的 Exemption Certificate，扫描+发邮件给区政府就行。5 分钟。',
      choices: [
        { label: '今晚发掉 5 分钟', effect: { energy: -1, flag: 'council_tax_exempt' },
          feedback: '5 分钟。第二天 council 回邮件确认豁免——你这一年节省了 £1500-1800。\n\n这是英国留学生最容易忘的事，也是最容易省钱的事。' },
      ],
    },
    {
      id: 'freshers_fair', minWeek: 1, maxWeek: 3,
      title: 'Freshers Fair · 社团摊位',
      body: '主楼大厅摆了 100 多个社团摊位。攀岩、戏剧、辩论、Anime、麻将、Christian Union、CSSA、太极……\n\n你拿了一沓 freebies：荧光笔、免费 Domino\'s slice、健身房 7 天免费 trial。',
      choices: [
        { label: '加入 CSSA（华人学生会）', effect: { energy: -3, belonging: 8, flag: 'cssa' },
          feedback: '微信群 200 人。第二天就有人发"找室友"、"代购"、"求 Mei\'s 优惠码"、"周末火锅局"。\n\n这是你这一年最不该退的群。' },
        { label: '加入辩论社（全英文）', effect: { energy: -5, belonging: 6, flag: 'debate_society' },
          feedback: '第一次例会全是英国本地人。你听不懂他们的笑话，但你笑了。回家路上你想：我至少坐在那里了。' },
        { label: '只拿 freebies 不加', effect: { energy: 1, wallet: 0 },
          feedback: '你拎着一袋免费东西回家。冰箱空，但抽屉满了。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // STATION — BRP collection (one-shot) + Bicester day-trip (W4+)
  // ─────────────────────────────────────────────────────────────
  station: [
    {
      id: 'brp_help_stranger', minWeek: 1, maxWeek: 4,
      title: 'Acton Lane · 替一个韩国大叔翻译',
      body: '你在 Acton Lane Post Office 取 BRP。\n\n前面一个 50 岁的韩国大叔——英语磕磕巴巴，工作人员皱眉了："Sir, do you have a printed copy of your decision letter or not?"\n\n大叔慌:"Letter... letter... I have phone..."\n\n他不知道 "decision letter" 是什么。',
      condition: ({ flags }) => flags.brp_pending && !flags.brp_collected,
      choices: [
        { label: '上前帮忙翻译',
          effect: { energy: -3, belonging: 10, flag: 'helped_brp_stranger' },
          feedback: '你走上前："Hi, my Korean is zero but he\'s asking about the BRP collection letter. Can he show it on his phone?"\n\n工作人员表情松了下来："Yes — email is fine."\n\n大叔翻出邮箱，工作人员核对完，5 分钟搞定。\n\n大叔出门前转身找到你——拿出一袋韩国蜜瓜糖塞你手里。"Thank you. Thank you." 他鞠了两次躬就走了。\n\n那袋糖你装进兜里——这是你这一年第一次"以一个外人的身份，帮另一个外人"。' },
        { label: '装没听见继续排队',
          effect: { energy: 0, belonging: -2 },
          feedback: '你低头玩手机。工作人员重复了 3 次。\n\n10 分钟后大叔被退回——"Come back with the letter printed."\n\n他出门时从你身边挤过去——你低头没看他。\n\n那天回家路上你一直在想：我下次会上前吗？' },
      ],
    },
    {
      id: 'brp_collect', minWeek: 1, maxWeek: 4,
      title: 'BRP 取证 · Acton Lane Post Office',
      body: '你按指示从 Marylebone 站坐 Bakerloo 到 Stonebridge Park，再走 8 分钟到 Acton Lane Post Office。\n\n门口排了 12 个亚洲面孔——都是新生。',
      condition: ({ flags }) => flags.brp_pending && !flags.brp_collected,
      choices: [
        { label: '排队 40 分钟取卡', effect: { energy: -8, belonging: 2, flag: 'brp_collected' },
          feedback: '工作人员把那张粉色塑料卡推给你："Don\'t lose it." 你点头。\n\n背面写着你的居留期限。塞进护照里。\n\n之后开银行、签新房合同、回国回签都要拿出来。是你这一年最重要的塑料片。' },
      ],
    },
    {
      id: 'bicester_trip', minWeek: 4, maxWeek: 40,
      title: 'Bicester Village · 代购日',
      body: 'Marylebone 站 9 点发车，47 分钟到 Bicester Village outlet。Burberry、Coach、Tory Burch 全场 30-70% off。\n\n群里有人发："带我代 4 个 Burberry 围巾，运费给你 £30/件。"\n\n往返车票 £35。',
      choices: [
        { label: '帮代购 全天扛 4 个包', effect: { wallet: 85, energy: -22, skipDays: 1, stress: 6, flag: 'bicester_daigou' },
          feedback: '你坐 9 点的车去，下午 6 点回。中间排 Burberry 1 小时，付款 30 分钟。回家时肩膀酸得抬不起来。\n\n£120 代购费 - £35 车票 = £85 净入账。但你想：这钱赚得真累。\n\n群里以后会一直有人找你。' },
        { label: '只给自己买一件 Burberry 围巾', effect: { wallet: -215, energy: -8, belonging: 4, skipDays: 1 },
          feedback: '你买了一条经典格纹围巾。£180 + £35 车票 = £215。\n\n比国内便宜 60%，但还是英镑。回伦敦的火车上你抱着购物袋睡着了。这是你来英国第一次"奖励自己"。' },
        { label: '只去逛 不买', effect: { wallet: -45, energy: -10, skipDays: 1 },
          feedback: '£35 车票 + £10 一杯 Pret。你逛了 4 小时，被代购阿姨挤来挤去，一件没买。\n\n但你看清了——下次要么早 8 点到、要么别来。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // SOHO / Chinatown — 华人超市 + diaspora touchpoints
  // ─────────────────────────────────────────────────────────────
  soho: [
    {
      id: 'loon_fung', minWeek: 1, repeatable: true,
      title: 'Loon Fung · 华人超市',
      body: 'Chinatown 拐角的 Loon Fung 是伦敦最大的华人超市之一。\n\n你推车进去：老干妈、康师傅、王守义、清北腐乳、白象方便面、卫龙、青菜（真的青菜，不是 Tesco 那种 spring greens）……应有尽有。但价格是国内的 3 倍。',
      choices: [
        { label: '采购一周 (£35)', effect: { wallet: -35, energy: -3, belonging: 12 },
          feedback: '3 包白象、2 瓶老干妈、1 罐腐乳、1 把青菜、1 包卫龙、1 袋花椒。\n\n回家煮了一碗有老干妈的方便面。这是你来英国第一次觉得"这就是家的味道"。' },
        { label: '只买老干妈和泡面 (£15)', effect: { wallet: -15, energy: 2, belonging: 6 },
          feedback: '£8 一瓶老干妈——国内 ¥18。你心里骂了一句。但你还是买了。\n\n这是你的精神安慰。' },
      ],
    },
    {
      id: 'chinatown_dimsum', minWeek: 5, maxWeek: 50,
      title: 'Chinatown · 周末早茶',
      body: 'Leicester Square 后面的 Chinatown。Royal China / 旺记 周末早茶 11 点开门。\n\n肠粉、虾饺、烧麦、凤爪、叉烧包……人均 £20-25。',
      choices: [
        { label: '一个人去吃一顿', effect: { wallet: -22, energy: 8, belonging: 8 },
          feedback: '你点了 4 笼。一个人吃完所有的。\n\n阿姨看你 looking lonely 多送了一份蛋挞："Eat more, dear." 你想哭。' },
        { label: '约 CSSA 群里的同学一起', effect: { wallet: -25, energy: 3, belonging: 18, flag: 'cssa_dimsum' },
          condition: ({ flags }) => flags.cssa,
          feedback: '6 个人挤一桌。你认识了 4 个新人。其中一个住你楼下。\n\n买单时大家一起抢——这是国内出来的人才有的本能。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // TESCO — daily reality
  // ─────────────────────────────────────────────────────────────
  tesco: [
    {
      id: 'tesco_5p_bag_shame', minWeek: 1, maxWeek: 3,
      title: '5p 塑料袋之耻',
      body: 'Tesco Express Bloomsbury。你结完账——一周菜 £18。\n\n收银员："Need a bag, love?" 你第一反应"yes 当然要，我手里这么多东西"。\n\n她从下面拿出一个塑料袋递过来——"5p, please."\n\n你愣了 1 秒。后面排了 4 个英国人。',
      choices: [
        { label: '掏出 5p 付了',
          effect: { wallet: -1, energy: -1, belonging: 1, flag: 'plastic_bag_learned' },
          feedback: '你付了。出门把袋子塞进 Uniqlo 包里。\n\n回房间 google "5p bag charge UK"——2015 年开始的环保政策，所有 supermarket 一袋 5p，Tesco / Sainsbury 强制收。\n\n你学到一条最基本的英国常识:**自己带袋子来**。下次你专门买了一个 £2 的 reusable Tesco tote——用到回国。' },
        { label: '"No, no, I have my arm"',
          effect: { energy: -2 },
          feedback: '你硬抱着 6 件东西出门。在 Bedford Square 半路一个 Coke 罐掉地滚走。\n\n你弯腰捡——其他 4 件趁机从怀里滑下来。你蹲在路边 1 分钟才全部捡起来。\n\n两个英国本科生路过没笑出声——但你心里清楚，你刚才省下 5p 丢了 £5 的脸。' },
      ],
    },
    {
      id: 'you_alright_misread', minWeek: 1, maxWeek: 4,
      title: '"You alright, mate?" · 文化误读',
      body: 'Tesco 收银台。一个 19 岁的英国本科收银员看你过来："You alright, mate?"\n\n你脑子转了 2 秒——他在关心你的精神状态？还是觉得你看起来累？\n\n你认真答："Honestly, a bit tired. Jet lag is killing me, and I haven\'t found a GP yet..."\n\n他脸僵了 1 秒。',
      choices: [
        { label: '看出对方表情 + 快速纠正 "Just kidding! Good thanks, you?"',
          effect: { energy: -1, belonging: 4, flag: 'you_alright_learned' },
          feedback: '他笑了："Mate, you had me worried for a sec. \'You alright\' is just hello here, you don\'t actually answer it. Or you answer \'You alright, yeah?\' and we both pretend that\'s a conversation."\n\n你笑了。你才知道这是英国最容易让人迷糊的一句招呼:**"You alright" = "hi"**。**正确答法:回一句 "You alright?"**\n\n他扫完你的购物袋说 "have a good one mate"——你也回 "you too mate"——你们都装作刚才那 2 秒尴尬没发生。' },
        { label: '继续认真 + 讲完 jet lag + GP',
          effect: { energy: -3, belonging: -2 },
          feedback: '他点头听完。然后尴尬地说："Yeah... well... GP just register on the NHS website mate. £4.50 please."\n\n你扫了卡走。他对下一个客人又问了一遍 "you alright"——那个白人男生秒回 "you alright?"\n\n你回房间 5 分钟才意识到，刚才那句话根本不是在问你。\n\n你这一年还会再撞一次。' },
        { label: '不知道怎么答 + 沉默微笑',
          effect: { energy: -1 },
          feedback: '你笑了一下没说话。他也点头把购物扫完。\n\n出门那一刻你想:他在问什么？是 friendly 还是 query？我应不应该回点什么？\n\n这种小困惑你这一年会撞 50 次。每次都在心里积一点。' },
      ],
    },
    {
      id: 'meal_deal', minWeek: 1, repeatable: true,
      title: 'Meal Deal · £3.40',
      body: '中午。Tesco 冷柜区贴着大字 Meal Deal £3.40：一个三明治 + 一份零食 + 一瓶饮料。\n\n你在 chicken & bacon 三明治和 Caesar wrap 之间犹豫。',
      effect: { wallet: -4, energy: 8, belonging: 1 },
      feedback: '你拿了 chicken & bacon sandwich + 一袋 Quavers + 一瓶 Innocent。结账 £3.40。\n\n吃着走在路上。你想：这是你这一年的午餐 default。\n\n（注：必须三件一起买才是 £3.40，单买 £4.50+）',
    },
    {
      id: 'clubcard_signup', minWeek: 1, maxWeek: 4,
      title: 'Tesco Clubcard · 会员卡',
      body: '收银员问 "Got a Clubcard?" 你摇头。她递给你一张表："Free, 5 minutes."\n\n你 google 了一下：Clubcard 价格通常比标价便宜 30-50%。一年下来能省几百镑。',
      choices: [
        { label: '当场填表 拿临时卡', effect: { energy: -1, flag: 'clubcard' },
          feedback: '收银员 5 分钟给你印了张临时卡。实体卡 1 周寄到家。\n\n这一年你买的每瓶牛奶都比别人便宜 £0.5。' },
        { label: '"算了 不办了"', effect: { energy: 1 },
          feedback: '一年下来你估算多花了 £200+。' },
      ],
    },
  ],
};
