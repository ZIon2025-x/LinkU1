// Random recurring events that capture the daily texture of UK student life
// in an ensuite hall — the kitchen drama, the maintenance attrition, the
// weird little money + bureaucracy tripwires.
//
// All events here are non-auto (random pool) and most are repeatable, since
// kitchen incidents recur. Some are one-shot revelations (Apple Pay, BRP
// typo, contactless £100 ceiling).

export const DAILY_LIFE_EVENTS = {
  // ─────────────────────────────────────────────────────────────
  // FLAT — ensuite kitchen drama, heating, leaks, the cleaner
  // ─────────────────────────────────────────────────────────────
  flat: [
    {
      id: 'fridge_yoghurt_stolen', minWeek: 2, repeatable: true,
      title: '酸奶被吃了',
      body: '早上你打开冰箱想拿那盒希腊酸奶——没了。\n\n架子上贴着张便签："Whoever took my yoghurt: it had MY NAME on it. Please don\'t. 😡"——是楼上 Lucy 的字。\n\n你那盒也写了名字。',
      choices: [
        { label: '算了 学聪明 名字写大点', effect: { wallet: -3, energy: -2, belonging: 1 },
          feedback: '你买了一沓 £3 的 sticker labels 贴在每件食物上："NAME · DATE · 拿了我会哭"。\n\n之后你的酸奶再没丢过。但其他人的还是会丢——这就是 ensuite 的代价。' },
        { label: '群里匿名 @所有人', effect: { energy: -3, belonging: -2 },
          feedback: '你打了一段："冰箱里别拿别人东西，谢谢。" 群里没人回。\n\n第二天你又丢了一根香蕉。' },
        { label: '给 reception 投诉', effect: { energy: -5, belonging: -3 },
          feedback: '前台小姐姐听完看了你 3 秒："Yeah... we can\'t really do anything about that, sorry. Maybe try a lockbox?"\n\n你回去搜 Amazon。冰箱用迷你密码锁 £18。你买了。' },
      ],
    },
    {
      id: 'milk_drunk', minWeek: 2, repeatable: true,
      title: '4-pint 牛奶剩 1/3',
      body: '你昨天才在 Tesco 买的 4-pint 全脂牛奶，今天剩 1/3。\n\n冰箱里 6 个 housemate。可能是任何人。\n\n你站在厨房盯着那瓶牛奶 30 秒。',
      choices: [
        { label: '从此只买 1-pint 小瓶', effect: { wallet: -2, energy: 1 },
          feedback: '从此你买 1-pint。每升贵 30%，但喝得完不会被偷。\n\n这就是 ensuite housemate 经济学。' },
        { label: '在瓶身写大字"DO NOT DRINK"', effect: { energy: 0 },
          feedback: '你拿黑色 Sharpie 写："DO NOT DRINK · 真的别喝 · seriously"。\n\n那晚没人动。第二天还是被喝了 1/4。\n\n你想：算了。' },
      ],
    },
    {
      id: 'kitchen_party_2am', minWeek: 2, repeatable: true,
      title: '凌晨 2 点厨房唱 Sweet Caroline',
      body: '凌晨 2:14。\n\n你被 5 个人在厨房齐声唱 *Sweet Caroline* 吵醒。"BAH BAH BAH—"\n\n隔壁的厨房，墙是纸。',
      choices: [
        { label: '出去说 "guys can you keep it down?"', effect: { energy: -3, belonging: 3 },
          feedback: '你穿睡衣走出去。他们看见你愣了 1 秒，一个金发男生说"Oh god sorry mate, we\'ll move it inside!"\n\n他们真的小声了。还递你一杯 wine——你拒绝了，但你笑了笑回去睡。' },
        { label: '戴耳塞硬扛', effect: { energy: -8 },
          feedback: '你戴上 Muji 耳塞 + 枕头闷头。还是听见 BAH BAH BAH。\n\n第二天你跟人吐槽，他们说"那就是 freshers"。' },
        { label: '打 wardens 投诉电话', effect: { energy: -2, belonging: -5 },
          feedback: '15 分钟后保安来敲门。party 散了。\n\n第二天厨房气氛冷了——你怀疑有人知道是你打的。但你睡着了。' },
      ],
    },
    {
      id: 'kitchen_messy_friday', minWeek: 2, repeatable: true,
      title: '周五早上的厨房',
      body: '周五 9 点。你想煮一包白象。\n\n4 个炉子有 3 个堆着没洗的锅。水池堆了昨晚 party 的玻璃杯。垃圾桶满了 2 天。\n\n空气里有股发酸的奶味。',
      choices: [
        { label: '默默洗一个炉子用', effect: { energy: -5, belonging: 1 },
          feedback: '你戴手套洗了 1 个不锈钢锅。煮白象时听见隔壁有人在打 zoom。\n\n这是 ensuite 真实——别人的 mess 也是你的 mess。' },
        { label: '群里 @所有人 求洗碗', effect: { energy: -2, belonging: -2 },
          feedback: '群里安静 1 小时。然后 Tom 回："yeah sorry that was me last night, will sort it later 😅"。\n\n他没 sort。' },
        { label: '出去 Pret £4', effect: { wallet: -4, energy: 5 },
          feedback: '你说 fuck it 出门。Pret 早餐 £4：croissant + flat white。\n\n比白象贵 5 倍，但今早值得。' },
      ],
    },
    {
      id: 'fire_alarm_3am', minWeek: 3, repeatable: true,
      title: '凌晨 3 点烟雾警报',
      body: '凌晨 2:47。整栋楼一齐响起来。\n\n"FIRE ALARM. PLEASE EVACUATE THE BUILDING IMMEDIATELY."\n\n你穿睡衣抓拖鞋下楼。门口已经站了 60 个 housemate——每人睡眼惺忪，有的裹着被子。',
      choices: [
        { label: '默默站雨里 20 分钟', effect: { energy: -10, belonging: 4, flag: 'fire_alarm_witnessed' },
          feedback: '伦敦 11 月的雨。20 分钟后保安宣布——4 楼有人烤面包烤糊了。\n\n大家骂骂咧咧回房。但走廊里 Tom（住你隔壁的英国男生）跟你交换了一个"无奈一笑"——这是你们认识的开始。' },
      ],
    },
    {
      id: 'heating_broken', minWeek: 8, maxWeek: 16,
      title: '暖气坏了',
      body: '周日早晨你冷醒。\n\n摸暖气片——凉的。窗外 4 度，房间里 12 度。手指打字都僵。',
      choices: [
        { label: '报修 Estates 邮件', effect: { energy: -3, flag: 'maintenance_filed' },
          feedback: '你写邮件："Heating not working in room 4B. Last functioned Friday."\n\nAuto-reply: "We aim to respond within 5 working days for non-emergency issues."\n\n5 working days = 一周。这一周你穿羽绒服睡觉。' },
        { label: '搬到图书馆', effect: { academic: 5, energy: -5 },
          feedback: '你打包 laptop + 充电器去 24 小时图书馆。比公寓暖。\n\n那一周你的论文 outline 比谁都齐。冷的时候，伦敦图书馆是最便宜的暖气。' },
        { label: '多盖被子撑', effect: { energy: -8, belonging: -3 },
          feedback: '你穿羽绒服 + 三层被子。半夜醒来，鼻子是凉的。\n\n这就是新留学生公寓——一切都贵，但热水永远晚来。' },
      ],
    },
    {
      id: 'leak_ceiling', minWeek: 4,
      title: '天花板渗水',
      body: '你下课推门——\n\n床头柜上一摊水。抬头看：天花板正中央有一片黄色水印，正在缓慢滴。\n\n楼上 5C 那位看来今早洗澡又忘关水。',
      choices: [
        { label: '紧急报修 + 拍照', effect: { energy: -3, flag: 'leak_filed' },
          feedback: '你给 Estates 发紧急邮件 + 6 张照片。\n\n2 小时后维修小哥来了——"楼上确实漏。换房间一周可以吗？" 你点头。\n\n这是这栋楼这一年最快的一次报修响应。' },
        { label: '自己拿盆接 + 凉床单', effect: { energy: -5 },
          feedback: '你拿浴室垃圾桶接水。一晚上接半桶。\n\n第二天床单又湿了。你才决定报修。' },
      ],
    },
    {
      id: 'cleaner_wednesday', minWeek: 2, repeatable: true,
      title: '周三早上 9 点的 Cleaner',
      body: '"Hello! Cleaning!" 一个 50 岁的波兰阿姨敲你的房门。\n\n按合同每周三 9 点 cleaner 来扫 communal area。你被叫醒帮她挪椅子。',
      choices: [
        { label: '帮她搬一下 + 聊两句', effect: { energy: -2, belonging: 5 },
          feedback: '阿姨叫 Magda，从波兰来 12 年。她给你看孙子的照片——一个 5 岁穿汉服的小孩（"my daughter married a Chinese guy"）。\n\n你说 "He looks lovely"。她笑得整个走廊都亮了。\n\n这是你这周最人间的对话。' },
        { label: '"Sorry I\'m sleeping" 关门', effect: { energy: 1, belonging: -2 },
          feedback: '她说 "Oh sorry love"，你关门继续睡。\n\n之后每周三你都会想起她——但她再没敲过你的门。' },
      ],
    },
    {
      id: 'package_at_reception', minWeek: 3, repeatable: true,
      title: 'Reception 一个包裹',
      body: '回楼时前台叫住你："Got a parcel for you, mate."\n\n是你妈寄的。EMS 国际快递。盒子上贴着 "FOOD" 申报 — 真实内容：6 包老干妈、2 件保暖内衣、1 包毛衣、1 张手写字条。',
      effect: { energy: 3, belonging: 12 },
      feedback: '字条："冷了多穿。少喝凉水。妈想你。"\n\n你坐在房间里看了 2 分钟。然后给妈打 video call——她在做晚饭，背景是你家厨房的味道。',
    },
    {
      id: 'fire_alarm_aftermath', minWeek: 3,
      title: '走廊偶遇 Tom',
      condition: ({ flags }) => flags.fire_alarm_witnessed,
      body: '上次 fire alarm 之后第三天。你倒垃圾时撞见 Tom——隔壁房间的英国男生，金发、穿牛津大学卫衣（"我没读过，是 charity shop 买的，£3"）。\n\n他笑了："Mate, the toast guy from 4B did it AGAIN last night. Did you sleep through?"',
      choices: [
        { label: '"Honestly I was wearing earplugs by then"', effect: { energy: 1, belonging: 8, flag: 'tom_friend' },
          feedback: '他大笑："Smart man. We should\'ve all done that." 然后他递给你一张纸条："This is the kitchen group WhatsApp—I added you. We complain about Mark a lot."\n\n你扫码加了。群里 7 个人。第一条置顶："Mark, please buy your own butter." 你忍不住笑出来。\n\n这是你在伦敦第一次被一个英国本地人主动拉进群。' },
        { label: '"Yeah I had to go to library at 4am"', effect: { energy: 0, belonging: 4 },
          feedback: 'Tom 说 "Bloody hell, that\'s rough." 然后他点点头继续走。\n\n但你之后在厨房见到他他都会点头打招呼。这一点对独自留学的人，已经够了。' },
      ],
    },
    {
      id: 'parcel_held_hostage', minWeek: 4, repeatable: true,
      title: '包裹被签了 找不到',
      body: '你 5 天前下的 Argos 单号 google tracking 显示 "Delivered – signed by housemate"。\n\n但你没收到。\n\n你去 reception 问，前台一脸茫然："Sorry, we didn\'t take it. Maybe one of your housemates?"\n\n你回楼想了想——可能是 Tom 或 Mark，他们俩都顺手。',
      choices: [
        { label: '在厨房群发"@all 谁帮我签了一个 Argos 包裹？"', effect: { energy: -2, belonging: 2 },
          feedback: '20 分钟后 Tom 回："Oh shit yeah, sorry mate, I forgot to tell you. It\'s in my room, hold on." 他出来递给你一个被压扁的纸箱——"It\'s been here 4 days, I\'m so sorry."\n\n包裹完好。但你发现以后所有送到的东西都得追到具体房间。这就是 ensuite。' },
        { label: '挨家挨户敲门找', effect: { energy: -8, belonging: 1 },
          feedback: '你敲了 5 个房门。第 4 个是 Tom——他说 "Oh god, sorry, I signed for a thing—was that yours?" 然后他从书桌底下翻出来。\n\n你拿到了。但 Tom 的房间味道你这辈子都忘不了。' },
      ],
    },

    // ─── housemate relationship beats ───
    {
      id: 'mark_confrontation', minWeek: 6,
      title: 'Mark · 厨房乱源',
      body: '周三晚上 11 点。你想煮一包白象。\n\n厨房又是地狱：3 个炉子全是脏的、垃圾桶满、有一个只穿四角裤的金发男生在用最后一个炉子煎培根。\n\n他抬头："Oh hey, you new? I\'m Mark. 4B."\n\n4B = the toast guy. 培根脏锅之父。',
      choices: [
        { label: '直接说 "Mate, can you wash your stuff after?"', effect: { energy: -3, belonging: 4, flag: 'mark_called_out' },
          feedback: 'Mark 愣了 3 秒，然后说 "Oh shit yeah, sorry, I\'ll clean up after I eat. My bad."\n\n他真洗了。但下周又脏了。\n\n这就是 Mark：不是恶意，是没意识到。直接说出来比群里 passive-aggressive 一万倍管用。' },
        { label: '装作没看见 默默洗一个炉子', effect: { energy: -5, belonging: -2 },
          feedback: 'Mark 边吃边问你 "So where you from?" 你说 "China"。他说 "Cool cool, never been but yeah"。\n\n你煮完面回房间。第二天早上厨房还是脏的。' },
        { label: '群里发 passive-aggressive 投诉', effect: { energy: -2, belonging: -4 },
          feedback: '你打："Hey guys, please can we keep the kitchen clean? Some of us cook late."\n\n群里安静了。Tom 私聊你："I think you mean Mark lol. Just tell him directly, he\'s not bad."\n\n你想：所以我刚才在被动什么。' },
      ],
    },
    {
      id: 'tom_sunday_roast', minWeek: 7,
      title: 'Tom 邀请 Sunday Roast',
      condition: ({ flags }) => flags.tom_friend,
      body: 'Tom 在厨房群 @你："Mate, doing Sunday roast at mine this Sunday. You in? Bring nothing, it\'s on me."\n\nSunday roast 是英国家常——烤鸡 + Yorkshire pudding + 烤土豆 + 蔬菜 + gravy。一顿吃 4 小时。',
      choices: [
        { label: '"Yes! What can I bring?"', effect: { wallet: -8, energy: 5, belonging: 18, flag: 'tom_roast' },
          feedback: '你买了一瓶 £8 的红酒（Aldi 装出 M&S 的范）。\n\nTom 做了整只烤鸡。Yorkshire pudding 像云朵。Gravy 是从 roasting tin 现做的。\n\n吃完他 put on Premier League — Arsenal vs Liverpool。你看不懂规则但跟着喊。\n\n回房间已经晚上 10 点。你想：原来这个不是表演，是真的家。' },
        { label: '"Sorry I have an essay"', effect: { energy: -2, belonging: -3 },
          feedback: 'Tom 回 "No worries mate, next time"。\n\n但你心里知道——next time 可能没有。Sunday roast 是英国人主动邀请你的最大信号。' },
      ],
    },
    {
      id: 'paper_thin_walls', minWeek: 4, repeatable: true,
      title: '隔壁有动静',
      body: '凌晨 12:30。\n\n隔壁房间——你猜是 Mark——传来明显的女声笑、然后明显的喘息、然后明显的床架撞墙的有节奏的"砰，砰，砰"。\n\n你戴上 Muji 耳塞。还是听得见。',
      choices: [
        { label: '戴双层耳塞 装作什么都没听见', effect: { energy: -5 },
          feedback: '20 分钟后他们停了。你睡着了。\n\n第二天厨房见到 Mark，他打招呼："Morning!" 你说 "Morning"。两个人都装作昨晚什么都没发生。\n\n这是 ensuite 的暗规则。' },
        { label: '拍墙 暗示"我能听见"', effect: { energy: -3, belonging: -2 },
          feedback: '隔壁声音变小了。但完全没停。\n\n第二天 Mark 在厨房见你眼神有点躲。但你们之后再没说过这个事。' },
      ],
    },
    {
      id: 'housemate_moves_out', minWeek: 12,
      title: '5C 走了',
      body: '5C 那个法国姑娘（你叫不出名字，因为只点过头）昨晚 4 点搬出去——你被她滚轮箱声音吵醒。\n\n第二天厨房群里 reception 发了一条："5C is now vacant. New tenant arriving Friday."\n\n你想：原来真的有人撑不住。',
      choices: [
        { label: '在厨房问一句 "what happened"', effect: { energy: -2, belonging: 4 },
          feedback: 'Tom（或者是 Pablo、是 Mark，反正是你这层楼的人）说："She wasn\'t happy here. Said it was too cold and too loud and Mark wouldn\'t leave the kitchen."\n\n你笑了一下。然后突然没那么想笑——她抱怨的 3 件事，你也都遇过。但你没走。\n\n那人看你："You okay?" 你点头。' },
        { label: '继续过自己的 看新人来', effect: { energy: 1, belonging: 1 },
          feedback: '周五新人搬进来——一个西班牙男生 Pablo。你听见 reception 跟他说 "Welcome, the kitchen group chat is..."\n\n这就是 ensuite——人来人往。' },
      ],
    },

    // ─── NHS / health admin ───
    {
      id: 'nhs_screening_letter', minWeek: 3,
      title: 'NHS · 入境体检通知',
      body: '邮箱里塞了一封 NHS 信。\n\n"Health Assessment for new entrants from countries with high TB incidence. Please attend your local clinic for a chest X-ray within 30 days. Free of charge."\n\n你 google 了一下：英国对来自结核高风险地区（含中国部分省）的留学生 mandatory health screening。免费，但不去会被跟进。',
      choices: [
        { label: '预约 + 当周去做 X-ray', effect: { energy: -5, flag: 'nhs_screened' },
          feedback: 'Hospital 的 X-ray 部门。技师让你脱上衣站在机器前。3 分钟。\n\n两周后你收到一封信："No abnormalities detected. Welcome to the UK."\n\n你松了口气——这是 NHS 第一次给你写"welcome"。' },
        { label: '"我没病 不去"', effect: { energy: 1 },
          feedback: '一个月后又来一封信，措辞更严厉：missed appointments will be reported。\n\n你最后还是去了。这种事在英国别拖——他们不会忘。' },
      ],
    },
    {
      id: 'nhs_vaccinations', minWeek: 4,
      title: 'NHS 免费疫苗 · MenACWY + HPV',
      condition: ({ flags }) => flags.gp_registered,
      body: 'GP 给你发了一封 follow-up：\n\n"As a new student under 25, you\'re eligible for free MenACWY (meningitis vaccine, strongly recommended for hall residents) and HPV (Human Papillomavirus, free for all under 25 regardless of gender). Both can be done in one appointment."\n\n你 google：\n· MenACWY 四联脑膜炎，公寓共用厨房感染风险高，UK 学生 standard\n· HPV 9 价，国内自费 ¥4500+，英国 25 岁前免费\n\n约 nurse 一次性打完两针。',
      choices: [
        { label: '预约 当周去打', effect: { energy: -5, belonging: 4, flag: 'nhs_vaccinated' },
          feedback: '你坐在 GP 的 nurse 房间。她先打左臂——MenACWY，"a wee scratch, dear"。再换右臂——HPV，"this one might sting a bit more"。\n\n两针完。她递给你一张接种记录。\n\n你想：这一针在国内 ¥4500 我妈舍不得给我打。在英国，一个 18-25 留学生，免费。\n\n这是国家医疗对外国学生最显眼的善意——不是对自己国民才管。' },
        { label: '"我没事 以后再说"', effect: { energy: 1 },
          feedback: '你想"反正以后回国"。\n\n回国后你 google 才知道——HPV 9 价 26 岁就打不了；MenACWY 在国内自费 ¥600+/针，4 联要打 4 次。\n\n你错过了。' },
      ],
    },
    {
      id: 'gp_appointment', minWeek: 5,
      title: '约 GP · 等 2 周',
      condition: ({ flags }) => flags.gp_registered,
      body: '你这两天咳嗽不停，喉咙痛，可能 chest infection。\n\n你给 GP surgery 打电话——"Sorry, the next available appointment is in 2 weeks, on the 14th. We can offer a phone call with a nurse tomorrow if it\'s urgent."\n\n你 google 了一下：英国 GP 系统就是这样，非紧急只能等。',
      choices: [
        { label: '订 2 周后预约 + 自己买 Lemsip 撑', effect: { wallet: -6, energy: -8 },
          feedback: '你订了。到那天你已经基本好了——但 GP 还是给你听了肺，开了一盒 amoxicillin "just in case"。\n\nNHS 处方 £9.65。这是你这一年第一次用 NHS。' },
        { label: '打 NHS 111 求紧急 advice', effect: { energy: -3, belonging: 1 },
          feedback: 'NHS 111 是免费医疗咨询热线。一个护士问了你 12 个问题，最后说 "Sounds like a viral infection. Rest, fluids, paracetamol. If you cough up blood, call us back."\n\n你松了口气。原来不严重。' },
        { label: '直接去 A&E 急诊', effect: { energy: -10, belonging: -2 },
          feedback: 'A&E (Accident & Emergency) 门口一排叫号椅。你等了 5 小时——前面 30 个人，从骨折到酒精中毒。\n\n医生看了你 4 分钟："This is non-emergency. You should\'ve called your GP." 你点头。\n\n出来时你想：这就是 NHS。能用，但别滥用。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // STATION — Apple Pay realization, Argos pickup, BRP typo
  // ─────────────────────────────────────────────────────────────
  station: [
    {
      id: 'apple_pay_tap', minWeek: 2, maxWeek: 12,
      title: 'Apple Pay 也能刷地铁',
      body: '闸机口。你没带钱包，掏手机——\n\n你把手机往刷卡口一贴。"beep"。闸门开了。\n\n回家 google：Contactless / Apple Pay / Google Pay 在 TFL 网络上和 Oyster 完全等价——自动算 daily cap，不需要预充值。\n\n（但没有 Student Oyster 的 30% 折扣。）',
      choices: [
        { label: '"那我以后就 Apple Pay"', effect: { energy: 1, flag: 'apple_pay_default' },
          feedback: '从此你每天 tap 手机进站。你算了一下——年化 30% 差距 = £360。\n\n你妈来电话："你那个 oyster 办了没？" 你说"还没。" 她叹气。' },
        { label: '应急用 Apple Pay 还是去办 Student Oyster', effect: { energy: 0 },
          feedback: '你把这事记下——临时用 Apple Pay，但 Oyster 还是要办。30% 不能让。' },
      ],
    },
    {
      id: 'argos_pickup', minWeek: 2, maxWeek: 8,
      title: 'Argos · 自取大件',
      body: '你刚到伦敦买了一些必需品：折叠椅 £20、台灯 £15、被子 £25、水壶 £12——总 £72，Argos 网上下单。\n\n他们说"Available for collection at Tottenham Court Road from 14:00."',
      choices: [
        { label: '一次性扛回家', effect: { wallet: -72, energy: -15, belonging: 3 },
          feedback: '4 件东西塞 2 个袋子。地铁里你被被子捆挤到 corner。\n\n回房间组装椅子用了 40 分钟——Argos 说明书永远缺一颗螺丝。\n\n但这就是你的房间了。' },
        { label: '只取台灯 + 水壶', effect: { wallet: -27, energy: -5 },
          feedback: '你只拿能塞背包的东西。被子和椅子 30 天后过期 — 你之后又下了一单。' },
      ],
    },
    {
      id: 'night_bus_n29', minWeek: 5, repeatable: true,
      title: '凌晨 1:30 的 Night Bus',
      body: 'Soho party 到深夜。地铁早停了（最后一班 0:30）。\n\nN29 night bus 半小时一班。你在站台等了 12 分钟，伦敦的雨刚开始下。\n\n车来了——双层。下层 5 个醉鬼对司机吼。上层有个流浪汉在睡觉。',
      choices: [
        { label: '上车 戴耳塞坐上层', effect: { wallet: -2, energy: -8, belonging: 4 },
          feedback: '£1.75。45 分钟到家。\n\n你旁边坐下一个 19 岁金发女生——她哭着对她朋友说 "He\'s an arsehole, I\'m never seeing him again"。她朋友说 "We say that every Saturday, babe"。\n\n你装作没听见。但这是你这一年偷听到的最 british 的对话。' },
        { label: '打 Uber 回家 (£22)', effect: { wallet: -22, energy: -2 },
          feedback: '司机是巴基斯坦大哥。一路放着 Bollywood 老歌。15 分钟到家。\n\n你想：£22。明天午饭得吃 Tesco £3.40。' },
      ],
    },
    {
      id: 'royal_mail_missed', minWeek: 4,
      title: '"Sorry we missed you" 红卡',
      body: '早上你出门——门口塞着一张红色卡片：\n\n"Sorry we missed you. Royal Mail tried to deliver your parcel but no one was in. Collect from Mount Pleasant Sorting Office, Mon-Sat 8am-1pm. Bring this card + photo ID."\n\nMount Pleasant 在 Farringdon。你查了下：要 30 分钟地铁。而且只能上午去——这就是 Royal Mail 的恶意。',
      choices: [
        { label: '明早 8 点起床去取', effect: { energy: -10, flag: 'royal_mail_collected' },
          feedback: '你 7:30 起。8:30 到 sorting office。门口排了 30 个人——快递、亚马逊退货、医保信、外国留学生证件全在这。\n\n40 分钟后你拿到一个不起眼的小盒子——是国内寄来的茶叶。\n\n你站在 Mount Pleasant 门口想：这一上午的代价就为了一袋茶。但你也知道——Royal Mail 的"漏投"就是收件人没在，没办法。' },
        { label: '在线申请 redeliver (£3 fee)', effect: { wallet: -3, energy: -1 },
          feedback: 'Royal Mail 网站让你输入红卡上的 reference，付 £3 安排重投。一周后到。\n\n你想：£3 买一上午时间，值。' },
      ],
    },
    {
      id: 'tube_fare_hike', minWeek: 16, maxWeek: 18,
      title: 'TFL 1 月调价',
      body: '闸机口有红色横幅："From 5 January, fares are increasing across the network."\n\nPay-as-you-go 单程从 £2.80 涨到 £3.00。Daily cap 从 £8.50 涨到 £8.90。Annual Travelcard 涨 5.9%。\n\nMayor Sadiq Khan 说"reluctantly"。',
      effect: { energy: -1, belonging: -2 },
      feedback: '你算了一下：每天 2 趟 × 5 天 × 4 周 = 40 次/月。每次多 £0.20 = 多 £8/月。年化 +£96。\n\n你 google "TFL 涨价"——这是连续 3 年涨 5%+。\n\n你想：还好 Student Oyster 30% off 还在。这一刻你觉得 £20 那张卡是这一年最值的。',
    },
    {
      id: 'rail_strike', minWeek: 3, repeatable: true,
      title: '全国铁路罢工',
      body: 'BBC News 推送："National rail strike: most train operators not running for 48 hours over pay dispute."\n\n你今天本来计划去 Bicester / Oxford / Cambridge / Edinburgh——所有 long-distance 火车停摆。Tube 大部分还在跑（不同工会）。\n\n你 google 了一下：英国铁路罢工已经 2 年了，每隔几周一次。',
      choices: [
        { label: '取消行程 待在家', effect: { energy: 3, belonging: -1 },
          feedback: '你退了车票 (£35 全额退)。在家躺了一天看 Netflix。\n\n下次你订票之前会先 google "rail strike"。' },
        { label: '改打 National Express 大巴 (£18 + 4 小时)', effect: { wallet: -18, energy: -10 },
          feedback: '大巴比火车慢一倍。但你到了。\n\n你想：英国铁路系统这一年罢了 12 次。这就是 cost-of-living crisis 的底色——服务业不涨工资就罢工。' },
      ],
    },
    {
      id: 'brp_typo', minWeek: 2, maxWeek: 12,
      title: 'BRP 上的姓打错了',
      condition: ({ flags }) => flags.brp_collected,
      body: '你回家仔细看 BRP 卡。\n\nGiven names: XIAO MING\nSurname: WNAG\n\n"Wnag"。\n\n你 google 了一下：reissue 要 £56 + 2 周等 + 网上重新提交照片。',
      choices: [
        { label: '认真去 reissue', effect: { wallet: -56, energy: -8, flag: 'brp_reissued' },
          feedback: '你在线 submit a correction，£56 fee。两周后新卡寄到——旧卡上被打了个孔，"VOID"。\n\n14 天 + £56 折腾。但你之后回签 visa、找 part-time、续 contract——都是新卡说了算。' },
        { label: '"算了 反正读音差不多"', effect: { energy: 1, flag: 'brp_typo_kept' },
          feedback: '一年后你回国回签——海关问 "Is this you?" 因为名字对不上护照。你解释了 30 分钟。\n\n下次签证表你还是要 reissue。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // TESCO — contactless limit + self-checkout dread
  // ─────────────────────────────────────────────────────────────
  tesco: [
    {
      id: 'self_checkout_unexpected', minWeek: 2, repeatable: true,
      title: 'Unexpected item in bagging area',
      body: '自助结账。你扫了三明治、酸奶、苹果——\n\n机器红灯一闪："Unexpected item in bagging area. Please wait for assistance."\n\n你回头看——你的水瓶是从背包拿出来的，没扫码。你按 "Item is mine"，机器还是不放过你。\n\n排在你后面的英国大爷叹了口气。',
      choices: [
        { label: '挥手叫店员来 override', effect: { wallet: -8, energy: -2 },
          feedback: '一个穿红马甲的小姐姐 30 秒就过来了——她盲操作连按 7 个键，机器一声 "Approved"。\n\n"Have a lovely day, love." 你说 "You too!"——但你已经怕了自助结账。下次你还是去人工。' },
        { label: '装作什么都没发生 假扫一下', effect: { wallet: -8, energy: -1 },
          feedback: '你假装重新扫一遍，机器突然不闹了。\n\n你溜走时，那个大爷在身后说 "Bloody machines, mate"。你笑了——这是你这周第一次被英国人当 "mate"。' },
      ],
    },
    {
      id: 'contactless_limit', minWeek: 3,
      title: 'Tap 不出去 · £100 上限',
      body: '收银台。你买了一周食物 + 洗衣液 + 几瓶酒 = £103.50。\n\n你 tap card——"Sorry, you\'ll need to insert your card."\n\n后面排了 4 个人。你的脸有点红。',
      effect: { wallet: -103, energy: -2 },
      feedback: '你插卡输 4 位 PIN。"Approved." 收银员笑笑 "First time over £100, eh?"\n\n回家 google 才知道：英国 contactless 单笔上限 £100，超过必须 chip & pin。这是央行规定。\n\n你想：原来这是疫情时从 £30 加到 £100 的——下次知道分两次结。',
    },

    // ─── cost-of-living crisis ───
    {
      id: 'meal_deal_hike', minWeek: 18,
      title: 'Meal Deal £3.40 → £5',
      body: '你像往常一样拿三明治 + Quavers + Innocent。\n\n收银台机器蹦出 £6.30。你看了 3 秒——"Wait, isn\'t this a meal deal?"\n\n收银员："Sorry love, the meal deal is now £5 for Clubcard members, £5.50 without. Plus that drink isn\'t in the deal anymore."\n\n你的国民午餐 default 涨了 £1.60。',
      choices: [
        { label: '认了 拿 Clubcard 价 £5', effect: { wallet: -5, energy: 6, belonging: -2 },
          feedback: '从此你的午餐预算每周多 £8，每月多 £32。\n\n你 google "UK food inflation 2024"——年化 12%。Clubcard 反而成了"被涨价之前你的价格"。' },
        { label: '换三明治到 deal 内', effect: { wallet: -5, energy: 4 },
          feedback: '你换了一瓶水（meal deal 内），放弃 Innocent。Innocent 现在 £3.50 单卖。\n\n小事。但你心里一笔账已经记下：在英国，每个东西都在悄悄涨。' },
      ],
    },
    {
      id: 'inflation_milk', minWeek: 12, repeatable: true,
      title: '一瓶牛奶涨了 £0.30',
      body: '你拿了一瓶 4-pint 全脂牛奶。\n\n以前 £1.55。今天 £1.85。\n\n你回头看——价签下面有一行小字 "New price"。',
      effect: { wallet: -2, energy: 0, belonging: -1 },
      feedback: '你买了。但你给妈微信发了一段："这边什么都在涨。一年前牛奶 £1.55，现在 £1.85。"\n\n你妈："那你工资涨了吗？"\n\n你笑了一下。你没工资。',
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // SOHO / Chinatown — first Boots visit (cold/flu season) + shopping events
  // ─────────────────────────────────────────────────────────────
  soho: [
    {
      id: 'boots_first_visit', minWeek: 4,
      title: 'Boots · 找药',
      body: '你重感冒，鼻塞咳嗽。\n\n你走进 Boots。三层楼。化妆品在一楼，OTC 药在二楼。你想找"维 C 泡腾片"。\n\n货架上：Berocca / Vit C 1000mg / Echinacea / Beechams Hot Lemon / Lemsip / Sudafed...\n\n你站着不知道选哪个。',
      choices: [
        { label: '问店员', effect: { wallet: -8, energy: 3, belonging: 3 },
          feedback: '一个店员小姐姐说 "What are you looking for, love?" 你说 "Cold medicine, vitamin C"。\n\n她带你过去："Beechams Hot Lemon for the cold, plus Berocca for the vitamin. Anything else?"\n\n你买了两样 £8。回家泡热水喝。\n\n这是你第一次觉得 Boots / 英国普通人对外国人，还是好的。' },
        { label: '自己挑 Berocca', effect: { wallet: -7, energy: 1 },
          feedback: '你挑了管装 Berocca £7。回家发现这是橙味起泡片——和国内的维 C 片本质一样。\n\n你给妈拍照："这就是英国人的金嗓子。"' },
      ],
    },
    {
      id: 'boots_photo_passport', minWeek: 3,
      title: 'Boots Photo · 申诉照片',
      condition: ({ flags }) => flags.brp_reissued,
      body: 'BRP reissue 系统要求你重新提交一张白底护照尺寸照。\n\nBoots 店里有一个 photo booth——投币 + 站到帘子里 + 拍 4 张。£8。',
      effect: { wallet: -8, energy: -2 },
      feedback: '你站到帘子里，机器倒数 5 秒。一道闪光后机器吐出一张包含 4 张证件照的纸条。\n\n你看了一眼——你睁眼睁得跟被吓到一样。但官方接受。\n\n回家把照片扫描成 PDF 上传到 BRP reissue 系统。一周后新卡到。',
    },

    // ─── shopping / consumer culture ───
    {
      id: 'black_friday', minWeek: 11, maxWeek: 13,
      title: 'Black Friday · 全城打折',
      body: 'CSSA 群里满屏："Apple 官网 EarPods Pro £179 历史最低！" "Selfridges 全店 30% off！" "Currys 笔记本砍半！"\n\n你 google 了一下：英国 Black Friday 这几年远不如美国凶猛——Apple 真打折的产品很少。但 Selfridges、John Lewis、Currys 是真的。',
      choices: [
        { label: '去 Selfridges 凑热闹', effect: { wallet: -85, energy: -10, belonging: 4, flag: 'black_friday_selfridges' },
          feedback: '你早上 9 点到——已经排了 200 个人。化妆品柜台 30% off，你买了一管 La Mer 给妈妈（£85，国内 ¥1500）。\n\n回家路上你发现自己反而省了——这就是 Black Friday 的洗脑陷阱。但你妈生日快到了，这次值得。' },
        { label: '只在线抢 Apple', effect: { wallet: -179, energy: -2, flag: 'black_friday_apple' },
          feedback: '你 9:00 整在 apple.com/uk 抢 EarPods Pro £179。3 分钟卖光。\n\n但你抢到了。一周后到。这是你这一年第一次"通过 sale 省到钱"——其实是把没必要的消费包装成了"机会"。' },
        { label: '群里看大家买 自己不动', effect: { energy: 1, belonging: -1 },
          feedback: '你看着 CSSA 群里晒单 200 条。你心里有点酸。\n\n但你回去算了一下：这一周你省了 £200。这才是真的 win。' },
      ],
    },
    {
      id: 'boxing_day_selfridges', minWeek: 14, maxWeek: 16,
      title: 'Boxing Day · Selfridges 5am 排队',
      body: '12 月 26 日。Boxing Day——英国最大的全年特卖日。\n\nSelfridges Oxford Street 5:00 am 开门。CSSA 群凌晨 4 点已经在喊："门口已经 500 人了！"\n\n外面 -1°C。',
      choices: [
        { label: '凌晨 4 点起 排队 5 小时', effect: { wallet: -250, energy: -25, belonging: 12, flag: 'boxing_day_queue' },
          feedback: '你 4 点起床，5:30 到门口——前面 800 人。雪在下。\n\n开门那一刻像马拉松起跑。你冲进去抢了一只 Burberry 围巾 (£180 → £90)、一对 AirPods (£249 → £179)、Tom Ford 香水 (£90 → £55)。\n\n你又冷又饿，心率 110。但你给妈妈、爸爸、自己买齐了圣诞礼物（迟到的）。\n\n这就是英国的"双十一"。但比国内更原始——是肉身排队的耐力赛。' },
        { label: '中午去 凑剩下的便宜', effect: { wallet: -80, energy: -8, belonging: 4 },
          feedback: '你中午 12 点到。好货已经空。你买了一双 Clarks 鞋 (£60 → £40) 和一袋无人问津的 Lush 礼盒 £40。\n\n好处：你睡了懒觉。坏处：朋友圈看别人晒"我抢到了"。' },
        { label: '在家网上购物', effect: { wallet: -50, energy: 3 },
          feedback: '你在床上打开 ASOS、John Lewis、Selfridges.com。\n\n网上和店里同价。你抢了一件 Zara 大衣 £40。\n\n这是温柔版的 Boxing Day。但你也错过了亲身经历英国零售战场的体验。' },
      ],
    },
    {
      id: 'wagamama_first', minWeek: 2, maxWeek: 30,
      title: '第一次 Wagamama',
      body: '同学拉你去 Wagamama——伦敦最熟的"Asian fusion"连锁。\n\n菜单：chicken katsu curry £14、ramen £13、bao buns £8、green tea 免费续杯。\n\n服务员手腕上有 PDA，下单方式是"按完成度上菜——食物按 ready 顺序送，不一起来"。',
      choices: [
        { label: '点 chicken katsu curry · 经典', effect: { wallet: -14, energy: 5, belonging: 4 },
          feedback: '你点了 katsu curry——黄色咖喱酱浇在 panko 炸鸡和米饭上。同学已经在吃 ramen 了（yours arriving 5 min later）。\n\n味道：和国内的日式咖喱差不多。但你来英国第一次吃到能吃饱的亚洲菜。\n\n吃完你给国内朋友拍照："这就是英国的旺角店。"' },
        { label: '尝 ramen "更地道吧"', effect: { wallet: -13, energy: 3 },
          feedback: 'Wagamama 的 ramen——汤是甜咸的，偏 westernized。你吃了一半。\n\n回家路上你想：以后不点 ramen 了。katsu curry 才是 Wagamama 的命。' },
      ],
    },
    {
      id: 'nandos_first', minWeek: 3, maxWeek: 30,
      title: 'Cheeky Nando\'s',
      body: 'CSSA 群里："这周五 cheeky Nando\'s 走起？"\n\n你 google "cheeky Nando\'s"——这是英国 meme，意思是"和朋友突然但很合理地"去 Nando\'s 吃葡萄牙烤鸡。\n\nNando\'s 有 5 个辣度：lemon & herb / mild / medium / hot / extra hot。新生劝退 medium 起。',
      choices: [
        { label: 'half chicken + medium', effect: { wallet: -13, energy: 5, belonging: 6 },
          feedback: '半只鸡 + 玉米 + chips + peri-peri sauce 一抹。Medium 已经辣到你抽气。\n\n同学笑你 "You\'re definitely not extra hot then"。你说 "I\'m a foreigner, give me a break"。整桌笑。\n\n这是你第一次在英国感受到 banter 的善意。Nando\'s 文化的核心。' },
        { label: 'extra hot 装勇敢', effect: { wallet: -13, energy: -3, belonging: 8 },
          feedback: '你点了 extra hot。第一口你脸就红了——但你没吐。同学拍手 "F\\*\\*king legend mate!"\n\n吃完你回家拉了 3 次。但 CSSA 群里你那张照片被收藏成了招牌。' },
        { label: 'lemon & herb · 怕辣', effect: { wallet: -13, energy: 3, belonging: 1 },
          feedback: '同学："That\'s the kid menu mate." 你说 "I value my colon"。\n\n你吃得很快乐。' },
      ],
    },
    {
      id: 'westfield_first', minWeek: 4, maxWeek: 50,
      title: 'Westfield · 伦敦最大购物中心',
      body: 'Stratford 的 Westfield——欧洲最大购物中心之一。300 多家店、Apple、Zara、UNIQLO、Primark 全在一栋楼。\n\n你出 Stratford 站口被人潮卷进去，意识到这是英国版"中关村+王府井"二合一。',
      choices: [
        { label: 'Primark 暴扫一波 (£45)', effect: { wallet: -45, energy: -8, belonging: 3 },
          feedback: 'Primark 是欧洲最便宜的快时尚——T 恤 £4、内裤 £2、袜子 £1.5。\n\n你拎了两大袋出来。同学说 "First Primark haul, classic"。' },
        { label: '只逛不买 体验一下', effect: { energy: -5, wallet: -8 },
          feedback: '你只买了一杯 £8 的 Dishoom 玛萨拉茶。逛了 3 小时脚酸。\n\n但你看清了——伦敦留学生的"shopping 天堂"，长这样。' },
      ],
    },

  ],

  // ─────────────────────────────────────────────────────────────
  // PARK — Hyde Park as the city's seasonal venue
  // ─────────────────────────────────────────────────────────────
  park: [
    {
      id: 'bonfire_night', minWeek: 10, maxWeek: 11,
      title: 'Bonfire Night · 11 月 5 日',
      body: '英国人纪念 1605 年 Guy Fawkes 火药阴谋未遂的那一晚——把那个 cosplay 假人烧掉，然后看烟花。\n\nHyde Park 今晚 8 点 grand fireworks display。门票 £15 或免费站外面看。CSSA 群里有人组队。',
      choices: [
        { label: '买 Hyde Park 门票去 (£15)', effect: { wallet: -15, energy: 8, belonging: 8 },
          feedback: '入场 7:30。冷得手都僵。8 点准时——音乐响起，烟花从泰晤士河一线打上去。20 分钟。\n\n你旁边一对英国老夫妇看你冻得发抖，给你递了一杯热可可。"First time at Bonfire?" 你点头。"Welcome to England, dear."' },
        { label: '不进园 站桥上免费看', effect: { energy: -3, belonging: 5 },
          feedback: '你在 Vauxhall Bridge 上和 200 个其他没买票的人一起看。视野好得不要钱。\n\n手指冻僵但你也笑了。' },
        { label: '"我不爱凑热闹" 回家', effect: { energy: 0, belonging: -2 },
          feedback: '你窗外断断续续传来 boom 声 2 小时。你在 BBC iPlayer 看 fireworks 直播——连英国老百姓都觉得别人家的烟花比自己家拍得好看。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // PUB — drinking holidays
  // ─────────────────────────────────────────────────────────────
  pub: [
    {
      id: 'st_patricks', minWeek: 26, maxWeek: 27,
      title: '3 月 17 日 · St Patrick\'s · 全城绿',
      body: 'Tube 里至少 3 个穿绿色 leprechaun 帽的人。Pub 玻璃门贴 "Guinness day! £4 a pint!"\n\n这是爱尔兰人的节，但伦敦人用任何借口喝酒。',
      choices: [
        { label: '点一杯 £4 Guinness 加入', effect: { wallet: -4, energy: -3, belonging: 10 },
          feedback: '你坐在 pub 角落。Guinness 是黑啤——苦中带甜，第一口你皱眉，第二口习惯了。\n\n旁边桌一个穿绿色头箍的胖子大叔笑着对你举杯 "Sláinte!" 你也举杯——后来 google 才知道这是爱尔兰语 "cheers"。\n\n这是你第一次喝 Guinness。你不会忘。' },
        { label: '"我不爱酒" 离开', effect: { energy: 1, belonging: -2 },
          feedback: '你出 pub 时门口已经排队了。你想：好像我没去也没错。但你也想：好像我没去就是没去。' },
      ],
    },
  ],
};

// ──────────────────────────────────────────────────────────────
// Cultural / seasonal events at FLAT, PUB, PARK extending DAILY_LIFE_EVENTS
// (added separately so the file stays scannable by section)
// ──────────────────────────────────────────────────────────────

DAILY_LIFE_EVENTS.flat.push(
  {
    id: 'ucu_strike', minWeek: 4, maxWeek: 22,
    title: 'UCU 教师罢工 · 停课 2 周',
    body: '你刚收到 course leader 的邮件：\n\n"Dear all, due to ongoing UCU industrial action over pay and working conditions, all lectures and tutorials this week and next week are cancelled. Essay deadlines are not affected. We apologise for the disruption."\n\nUCU 是英国大学教师工会。每年都罢工——议题：pay erosion、casualisation、pension cuts。\n\n你这一年 £24,000 学费的一部分，正在被替换成"自学"。',
    choices: [
      { label: '在 r/UniUK 看大家吐槽 + 自学', effect: { energy: -3, academic: 2, flag: 'ucu_strike_solo' },
        feedback: 'Reddit 一片骂声："I\'m paying £30k for online lectures and now strikes." 但教师那边帖子是："I make £35k after a PhD, I deserve more."\n\n你看了 1 小时。你心情很复杂——你支持 underpaid 的教师，但你的学费被吃掉了。\n\n你回头自学。你也开始读 union 的诉求 PDF——这是你这一年第一次认真理解什么叫 "industrial action"。' },
      { label: '签 student union 联名要求 partial refund', effect: { energy: -2, belonging: 4 },
        feedback: 'Student union 推一个 petition："Demand fair compensation for lost teaching time." 已签 8,000 人。\n\n你也签了。一年后学校发了一封 "we acknowledge the disruption" 的官方邮件——但没退钱。\n\n这是英国大学的标准结局。你学到的不是课内的，是这件事本身。' },
      { label: '"反正不影响 deadline" 不管', effect: { energy: 1 },
        feedback: '你照常写 essay。两周后罢工结束，复课。\n\n但你那两周本来该有的 supervision 没补回来——你交 essay 时一个 unanswered question 没人帮你答。' },
    ],
  },
  {
    id: 'royal_mail_strike', minWeek: 12, maxWeek: 16,
    title: 'Royal Mail 圣诞罢工',
    body: '12 月。BBC 推送："Royal Mail workers stage 48-hour strike. Christmas deliveries delayed."\n\n你给妈微信："那个国内寄的羽绒服可能赶不上圣诞了。"\n\n你妈："已经寄了三周了！怎么还没到？"\n\n你 google tracking——卡在 Heathrow 海关 + 罢工延误，预计再等 2 周。',
    choices: [
      { label: '安抚妈妈 + 等', effect: { energy: -2, belonging: 4 },
        feedback: '你说："妈没事，我有 Tom 借我的暖气片（合法的小型电暖器）。等就等。"\n\n圣诞那天你穿着 Tesco 买的羽绒外套出门。羽绒服一月初到。但你妈那两周睡不踏实——这个你后来才知道。' },
      { label: '抱怨 Royal Mail (online review)', effect: { energy: 1, belonging: -1 },
        feedback: 'Trustpilot 上 Royal Mail 1 星评价 50,000 条。你贡献了一条。\n\n你想：罢工是工人的权利。但羽绒服真的赶不上是件糟事。两个事实可以并存。' },
    ],
  },
  {
    id: 'eurovision_with_tom', minWeek: 34, maxWeek: 36,
    title: 'Eurovision · 全欧最 camp 一晚',
    condition: ({ flags }) => flags.tom_friend,
    body: 'Eurovision Song Contest 今晚直播——欧洲最大、最 dramatic、最不严肃的歌唱比赛。每个国家送一首歌，全欧洲打分。\n\nTom 敲你门："Mate, Eurovision\'s on. My room. Bring snacks."',
    effect: { wallet: -3, energy: 3, belonging: 14, flag: 'eurovision_party' },
    feedback: '5 个人挤 Tom 床上。荷兰那首被 Tom 大喊 "this is shit"，乌克兰那首他们站起来鼓掌。英国每年最后一名——大家自嘲了 30 分钟。\n\n你不知道 Eurovision 该怎么 appreciate，但你跟着笑、跟着喊。结束时 Tom 说 "this is the most british you\'ll ever see us"。\n\n你想：是的。这是 british 真正的样子——既不爱国又自嘲又疯狂。',
  },
  {
    id: 'eurovision_alone', minWeek: 34, maxWeek: 36,
    title: 'Eurovision · 一个人看 BBC One',
    condition: ({ flags }) => !flags.tom_friend,
    body: 'Eurovision Song Contest 今晚直播——欧洲最大、最 dramatic、最不严肃的歌唱比赛。\n\n群里大家在 own 公寓 own party。你没被叫——你也没主动开。',
    effect: { energy: 1, belonging: 2 },
    feedback: '你看了 4 小时 BBC One。每首歌都比上一首更 camp。法国那首唱了一只跳舞的洋葱。意大利那首是死亡金属乐队。\n\n你笑了一下午。这是你来英国最不正经但最快乐的一晚。\n\n虽然是一个人。',
  },
  {
    id: 'freshers_flu', minWeek: 3, maxWeek: 4,
    title: 'Freshers\' Flu',
    body: '你早上醒来——喉咙痛、头痛、低烧 37.8。\n\n你 google "Freshers Flu"——这是开学后第二三周整个英国大学集体爆发的"新生流感"。3000 个新生从全国各地汇集，免疫系统对所有新菌还没适应。\n\n群里 80% 的人都在吐槽。',
    choices: [
      { label: '床上躺 3 天 + Lemsip', effect: { wallet: -6, energy: -3 },
        feedback: '你躺了 3 天。Lemsip Hot Lemon 喝了 8 杯。第三天你能起床煮一碗白象。\n\n这就是 Freshers Flu——所有人都得，所有人都会过。' },
      { label: '硬撑去上课', effect: { wallet: -3, academic: 2, energy: -10, belonging: -3 },
        feedback: '你戴口罩去上 tutorial。Sarah 看你脸色绿："You should go home, mate." 你点头但你坚持。\n\n两天后 Sarah 也病了。你心里有点过意不去。' },
    ],
  },
  {
    id: 'house_meeting', minWeek: 6,
    title: 'House Meeting · Cleaning Rota',
    body: 'Reception 在厨房群发一条 "Tenants of Block A: house meeting Thursday 7pm to discuss the kitchen situation."\n\nHouse meeting = 6 个 housemate 围着厨房桌子讨论 cleaning rota（轮值表）。这是英国住宿生活最 awkward 也最典型的"民主"。',
    choices: [
      { label: '去开会 提议每周 rota', effect: { energy: -8, belonging: 6, flag: 'house_meeting_attended' },
        feedback: '会开了 90 分钟。Mark 一开始说 "I always clean!"（明显不是）但被 Tom 笑着回："Mark, mate, come on."\n\n最后大家同意：每人值班一周——周一倒垃圾、周三擦炉灶、周日扫地。粘在冰箱上。\n\n第一周大家都做了。第三周开始，Mark 又开始忘记。但 rota 至少给了你"指出他没做"的合法依据。\n\n这就是英国式 democracy——很慢、很 awkward、但比东亚的"算了"管用。' },
      { label: '装作没看见会议消息', effect: { energy: 1, belonging: -3 },
        feedback: '你没去。结果 rota 出来了你还是在表上——周二倒垃圾。\n\n你想：原来"我没去"等于"你给我安排了"。这就是英国的 silent enrolment。' },
    ],
  },
);

// ─────────────────────────────────────────────────────────────
// UNI — academic life details (Turnitin, reading list, group projects, tutors)
// ─────────────────────────────────────────────────────────────
DAILY_LIFE_EVENTS.uni = [
  {
    id: 'reading_list_overwhelm', minWeek: 2, maxWeek: 4,
    title: 'Reading List · 30 本',
    body: 'Course handbook：required reading 12 本，recommended 18 本。3 周后第一篇 essay。\n\n你算了一下：每本 300 页，30 本 = 9000 页。3 周 = 21 天。每天读 430 页。\n\n这不可能。',
    choices: [
      { label: '问 Sarah / 同学怎么办', effect: { energy: 2, academic: 4, belonging: 4 },
        feedback: 'Sarah 大笑："Mate, NOBODY reads all of them. Pick 5 you actually want to engage with, skim 5 more for citations, ignore the rest."\n\n你愣了 5 秒。原来这是 unspoken rule。\n\n这是你这一年学到的第一个英国学术 hack——没人会告诉你，但所有人都在做。' },
      { label: '死磕全读', effect: { energy: -25, academic: 8, belonging: -3 },
        feedback: '你 3 周里读了 18 本。瘦了 3 公斤。Essay 写得很好——distinction 边缘。\n\n但你学到："你完全可以做到"，和"这不是健康节奏"是两件事。' },
      { label: '直接看 SparkNotes', effect: { academic: -3, energy: 2 },
        feedback: '你 google 每本书 1 句话总结。Essay 写得空洞。\n\nTutor 留言："Your engagement with the texts feels surface-level." 你脸红。' },
    ],
  },
  {
    id: 'turnitin_crashes', minWeek: 10, maxWeek: 12,
    title: 'Turnitin · 11:59 系统崩',
    body: '23:54。第一篇 essay 的 deadline 是 12:00。\n\n你点 "Submit"——Turnitin 转圈圈。30 秒。1 分钟。2 分钟。\n\n23:57。屏幕显示："Service unavailable. Please try again later."\n\n你心率 120。',
    choices: [
      { label: '截图 + 邮件 tutor 求 extension', effect: { energy: -8, academic: 3, flag: 'turnitin_extension' },
        feedback: '你 23:58 给 tutor 发 email："Turnitin is down, screenshot attached. I have the file ready."\n\n第二天 tutor 回："No worries, this happens every year. Your timestamp counts. Marked normally."\n\n你后来才知道——12 月 essay deadline 那天 Turnitin 必崩。这是英国研究生圈无人不晓的 unspoken rule。' },
      { label: 'panic 重启电脑 + 一直刷', effect: { energy: -15, academic: -2 },
        feedback: '你刷了 47 分钟。00:43 终于上传。\n\n但 deadline 已经过了。Tutor 收到的版本带个红色 "LATE" 标签。\n\n两周后成绩出来：50% Pass（ unmarked late penalty -10%）。本来能拿 65。' },
    ],
  },
  {
    id: 'tutor_silent_email', minWeek: 6, maxWeek: 22,
    title: 'Tutor 不回邮件',
    body: '你 essay 焦虑了 5 天。给 supervisor 发 email 求 office hour。3 天没回。\n\n你 refresh 邮箱 12 次。没新邮件。\n\n其他同学群里说："oh yeah, Dr. Chen takes 5-7 working days. Don\'t panic."',
    choices: [
      { label: '再发一次软提醒', effect: { energy: -2, academic: 3 },
        feedback: '你打："Dear Dr Chen, just following up on my previous email. Happy to wait if you\'re busy." 24 小时后他回："Apologies, this got buried. Friday 2pm OK?"\n\n你松了口气——原来 tutor 不是不理你，是真的忙到 inbox 1000+。' },
      { label: '直接去他 office hour 蹲', effect: { energy: -5, academic: 5, belonging: 2 },
        feedback: '你 Wednesday 2-4pm 是他 standing office hour。你提前到。门口已经排了 3 个学生。\n\n轮到你 15 分钟。你拿到了所有问题的答案。\n\n你以后都不发 email 了——直接蹲。' },
      { label: '算了 自己写', effect: { academic: -2, energy: -3 },
        feedback: '你 essay 拿了 58。不是因为没努力——是因为没问。\n\nTutor feedback："This argument is strong but lacks engagement with [book X], which I\'d have flagged in supervision." 你想：我应该再发一次 email 的。' },
    ],
  },
  {
    id: 'group_project_freeloader', minWeek: 20, maxWeek: 22,
    title: '小组项目 · 队友消失',
    body: 'Spring term 5 人 group project 还有 1 周交。\n\n一个澳洲同学 Jack 三周不出现。group chat @他 3 次没回。WhatsApp last seen 3 天前。但他答应过的 methodology section 完全没动。\n\n剩下 4 个人开紧急会议。',
    choices: [
      { label: '组员 cover 他的部分 + 报告 fairness', effect: { energy: -15, academic: 4, belonging: 6, flag: 'group_carry' },
        feedback: '你和另外 3 人通宵。Methodology 你重写。提交时附了一封 fairness report 给 tutor，列出 Jack 没贡献。\n\nTutor 回："I\'ll mark each contribution individually. Your section is excellent."\n\nJack 拿了 40，你们 4 个拿了 70+。这就是 fairness——不是抱怨，是 documentation。' },
      { label: '群里 @他 撕破脸', effect: { energy: -3, belonging: -4 },
        feedback: '你打："Jack, this is absolutely unacceptable, you\'re screwing all of us." Jack 第二天回："chill mate, I had personal stuff."\n\n他交了一段 WikiHow 抄的 methodology。你们的 essay 因为他被拖到 60。\n\n你想：撕破脸不解决问题。' },
      { label: '不管他 5 个人交一份', effect: { energy: -8, academic: -3 },
        feedback: '你们交了 4 个人的工作 + Jack 没动的 methodology。Tutor 显然知道。\n\n整组 60。Jack 也 60。但你心里知道——你们 4 个被他拖了 10 分。\n\n下次 group project 你会先发邮件给 tutor 确认 fairness mechanism。' },
    ],
  },
];

// ─────────────────────────────────────────────────────────────
// LIBRARY — 24h reality + silent zone politics
// ─────────────────────────────────────────────────────────────
DAILY_LIFE_EVENTS.library = [
  {
    id: 'library_group_room', minWeek: 10, maxWeek: 26,
    title: 'Group Room 抢预约',
    body: 'Group project 会议——你 5 个人需要一个 group study room。Online booking 系统 7 天前 9am 开放。\n\n你 9:01 点开发现：所有 group room 都被抢光。第一可用时间是 10 天后。',
    choices: [
      { label: '7am 起来抢下一周', effect: { energy: -3, academic: 4 },
        feedback: '你 6:55 set 闹钟。9am 整点连刷 3 次。抢到了。\n\n这就是英国 G5 大学图书馆——300 个 group rooms 不够 5000 个研究生用。你以后每周日 6:55 都会刷。' },
      { label: '在 cafe 集体开会', effect: { wallet: -25, energy: -3, belonging: 4 },
        feedback: '你们 5 人挤 Pret 角落。每人买一杯 £5 的咖啡 = £25 总。喝着开了 3 小时。\n\nPret 服务员看你们好几眼。但没赶你们。' },
      { label: '去 flat 厨房开', effect: { energy: -5, belonging: 1 },
        feedback: '5 个人挤你们 ensuite 厨房。Mark 在煎培根。讨论被打断 4 次。\n\n效率不高。但免费。' },
    ],
  },
  {
    id: 'library_2am', minWeek: 11, repeatable: true,
    title: '凌晨 2 点找位置',
    body: '24 小时图书馆。你 deadline 还有 36 小时。\n\n3 楼满。4 楼满。5 楼满。每一张桌子都有 laptop + 冷掉的咖啡 + 盖在椅背的外套（占座）。\n\n6 楼最角落最后一个空位。',
    effect: { energy: -10, academic: 4 },
    feedback: '你坐下来。隔壁是个戴眼镜的中国女生（不是 Aditi），她一直在敲键盘没抬头。\n\n你们一直没说话——但凌晨 4 点你倒咖啡时，她也起身去倒。两个人在咖啡机前对视一秒，互相点头。\n\n这是图书馆的隐性同盟。',
  },
  {
    id: 'library_phone_glare', minWeek: 2, repeatable: true,
    title: 'Silent Zone · 接电话',
    body: '3 楼 silent zone。你妈打来视频。你压低声音说"妈我在图书馆"。\n\n隔壁桌一个 50 岁英国大叔抬头瞪你 5 秒。然后他举起手指比了一个 "shhh"。',
    choices: [
      { label: '尴尬地走出去接', effect: { energy: -3, belonging: 1 },
        feedback: '你抓着手机走出 silent zone 到楼梯间接。妈："你那边怎么这么吵？"\n\n你说"图书馆走廊"。她哦一声继续讲。\n\n回去座位时大叔已经走了——你以为他在生气，但他桌上留了一张便签："Sorry mate, didn\'t mean to be rude. Just needed quiet for my dissertation."\n\n你笑了。这是英国 passive politeness 的精髓。' },
      { label: '挂掉 + 改发微信', effect: { energy: -2 },
        feedback: '你立刻挂电话，发"妈我在 silent area，下午回家说"。\n\n大叔点头。你松口气。' },
    ],
  },
  {
    id: 'library_cleaner_pass', minWeek: 4, repeatable: true,
    title: '早 8 点 · Cleaner 推车',
    body: '你昨晚通宵到 7am。眼睛快闭上时——\n\n"BEEEEEP"——一个推车声从你身后经过。Cleaner 大叔笑着说 "Long night?"\n\n他推着车继续过。',
    effect: { energy: -3, belonging: 3 },
    feedback: '你点点头。他没停。但 5 分钟后他回来递给你一杯免费咖啡——cleaner 茶水间留的剩咖啡。\n\n他说 "On the house." 然后走了。\n\n你想：在凌晨 7 点的图书馆，递咖啡的人比 supervisor 还像导师。',
  },
];

