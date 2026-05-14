// 日常意外 · UK 留学生才懂的小坑。
//
// 这些不是大事——但攒在一起就是"伦敦生活"的纹理：
//   · Tube 突然停 25 分钟 / 错过末班 / 末班路上信号断
//   · 周日 Tesco 5pm 就关门 / Bank Holiday 全城 closed 你忘了
//   · Post Office 5:30 关门 / Self-checkout 全坏排长队
//   · 电梯坏 5 楼爬楼 / wifi 被合租重启 essay 没存
//   · 夏令时调钟震惊 / HMRC 把你 emergency tax 了
//
// 大多 repeatable: false（一年里出一次就够），但部分 ongoing 烦恼
//（lift / self-checkout）保留 repeatable: true。
//
// 每个事件 effect 都轻——这些是 nuisance，不是 milestone。

export const DAILY_ACCIDENT_EVENTS = {
  station: [
    {
      id: 'tube_signal_failure', minWeek: 4, maxWeek: 50, repeatable: true,
      title: 'Northern line · "We apologise for the delay"',
      body: '你正在 Northern line 上。列车突然停在隧道里——灯闪了一下。\n\n司机广播："Ladies and gentlemen, this is your driver speaking. Due to a signal failure at Camden Town, we are being held at a red signal. We apologise for the delay. We will move as soon as we receive permission."\n\n你看了一下手表。距离你 tutorial 开始还有 12 分钟。\n\n5 分钟过去——没动。10 分钟——没动。15 分钟——开始动 30 秒——又停。',
      choices: [
        { label: '掏出 reading 在车厢里看完一段', effect: { energy: -3, academic: 3, belonging: 1 },
          feedback: '车厢里有个英国老头在读 The Times。一个穿西装的女人在用 Excel。一个学生戴耳机闭眼。\n\n你打开 Foucault PDF——读了 4 页。25 分钟后车终于动了。你晚到 tutorial 17 分钟——但 Whitmore 也晚到 14 分钟（同一条线）。\n\n伦敦 commuting：被强行夺走的时间，能用 reading 抢回一点。' },
        { label: '在 group chat 抱怨', effect: { energy: -2, belonging: 2 },
          feedback: '你发 CSSA 群："Northern line 又坏了 我命真衰。"\n\n5 秒不到 8 个人回："+1"\n"我刚才在 Old Street 站台等 22 分钟"\n"今天 Victoria 也坏"\n"哥伦敦 tube 永远是这样"\n"我家 wifi 也坏 别问我为啥相关"\n\n你笑出声。这种集体吐槽是伦敦留学生唯一可控的应对机制。' },
        { label: '焦虑刷 TFL 状态页', effect: { energy: -5 },
          feedback: '你刷了 5 次 TFL Status——红字 "Severe Delays"。看了也不能让车开。\n\n车终于动时你才意识到——焦虑这 25 分钟没改变任何事。' },
      ],
    },
    {
      id: 'last_tube_missed_90s', minWeek: 6, maxWeek: 50, repeatable: true,
      title: '错过末班 tube · 90 秒',
      body: '凌晨 12:08。Tottenham Court Road station 售票闸门——你刚跑过来。\n\n工作人员摇头："Last train was 12:06 mate. 90 seconds."\n\n你看屏幕——这条线下一班 5:24 AM。距离 ensuite 还有 3.2 mile。',
      choices: [
        { label: 'Uber £18', effect: { wallet: -18, energy: -3, belonging: 1 },
          feedback: '司机是个 60 岁巴基斯坦大叔——一路给你讲他 1985 年来伦敦的故事。下车你给他 5 星 + 写"thank you for the conversation"。\n\n你回 ensuite 路上想：90 秒决定 £18——但 Uber 司机的故事 priceless。' },
        { label: 'Night bus N29 (40 分钟)', effect: { wallet: -1.75, energy: -10, belonging: 0 },
          feedback: 'Night bus 上半层全部坐满——醉酒英国人 + 一对在亲嘴的情侣 + 一个抱着一袋 KFC 的男生睡着了。\n\n你 40 分钟到 ensuite。穿过 Camden 时窗外有人在唱 Oasis。\n\n你省了 £16。但你也欠了你身体一晚不太干净的睡眠。' },
        { label: '走回去（45 分钟）', effect: { energy: -15, belonging: 2 },
          feedback: '凌晨 1 点的伦敦出乎意料安静。Bloomsbury 那一段路全是黑的——只有路灯和你脚步声。\n\n你回到 ensuite 已经 1:05。脚酸得不行。但你想：你 22 岁在伦敦凌晨 1 点走过 Bloomsbury。10 年后你不会忘记这一段路。' },
      ],
    },
    {
      id: 'national_rail_engineering_works', minWeek: 14, maxWeek: 50, repeatable: true,
      title: 'National Rail · "Replacement bus service"',
      body: '你买好了 train ticket 去 Cambridge / Oxford / Brighton 一日游。\n\n到了 Liverpool Street 才看到 announcement：周末"engineering works"——Train cancelled。Replacement: bus from Stratford。多 90 分钟。',
      choices: [
        { label: '"靠 但是去了"（坐 bus）', effect: { energy: -10, wallet: 0, belonging: 4 },
          feedback: '你坐 replacement bus——堵车堵了 50 分钟。到目的地比预计晚 2 小时——你只剩 4 小时旅游时间。\n\n但你拍了几张好照片。回程 train 居然准点（也算一种公平）。\n\n你这一刻 internalize 一件事：英国 weekend 出行 = 50% chance 跟你来一次"surprise replacement bus"。' },
        { label: '退票回 ensuite', effect: { energy: 1, wallet: -5, belonging: -3 },
          feedback: '你 refund 了——但有 £5 admin fee。\n\n回 ensuite 路上你看到 Cambridge 的天气是晴朗 18°C 完美旅游日。你心情不太好。' },
      ],
    },
    {
      id: 'oyster_card_zero_balance', minWeek: 4, maxWeek: 30, repeatable: true,
      title: 'Oyster · 余额 £0.20',
      body: '早上 8:50。你赶 9:00 lecture。Russell Square 闸门——红灯。"INSUFFICIENT FUNDS"。\n\n你看手机 TFL — Oyster £0.20。来不及 top-up。后面排了 5 个人。',
      choices: [
        { label: '掏 contactless 银行卡刷过', effect: { wallet: -3, energy: 1 },
          feedback: '你直接 contactless 刷 debit card——绿灯。\n\n你想：好在这 5 年伦敦把所有闸门都接 contactless。Oyster 早就只是一种心理安慰了。\n\n9:08 你坐进 lecture 后排。Whitmore 看了你一眼——但没说什么。' },
        { label: '回 top-up 机充值（迟到）', effect: { energy: -3, wallet: -10, academic: -2 },
          feedback: '你充值花了 1 分钟。但你迟到 9:14——课开始 14 分钟你才进场。\n\nTutor 看你："Late, are we?" 你说"Sorry, signal issues."\n\n你站在后排没座位 — 整堂课没听进去。' },
      ],
    },
    // ─── 天气微暴击 (g) ───
    {
      id: 'rain_no_umbrella_drenched', minWeek: 4, maxWeek: 50, repeatable: true,
      title: '没看天气 · 5 分钟内全身淋透',
      body: '你出门时天阴 — 你想"撑得住吧"。\n\n走到 Russell Square 站台外 5 分钟——cloudburst。\n\n3 秒内 T-shirt 贴皮。30 秒内 jeans 颜色变深。1 分钟内你头发开始滴水——一个英国老头从你旁边走过——他撑着一把折叠伞。他朝你点头："Always check the weather, eh?"',
      choices: [
        { label: '冲进最近的 Pret 躲 + 买一杯热的', effect: { wallet: -4, energy: -3, belonging: 2 },
          feedback: '你冲进 Pret —— 滴水的 hoodie 在 dry-cleaning 几乎不可能。你买了一杯 £3.50 latte 暖手 + 等 20 分钟雨停。\n\n你 google "London rain frequency" — 每 3 天 1 次。\n\n第二天你 Amazon 下单 £12 折叠伞——从此再没出门不带过。' },
        { label: '硬走回 ensuite + 30 分钟', effect: { energy: -10 },
          feedback: '你走回 ensuite——湿到 trainers 里 squelch 声。\n\n回到 ensuite 你脱下湿衣服 — heating 没开 — 你冷得发抖。\n\n第二天你嗓子疼。\n\n你这一刻 internalize "always check Met Office" — 国内手机 default 天气 app 在英国不可信。' },
      ],
    },
    {
      id: 'wind_inverts_umbrella', minWeek: 4, maxWeek: 22, repeatable: true,
      title: '£8 Tesco 伞 · 被风吹翻',
      body: '你走到 Bloomsbury 拐角——一阵 22 mph 横风。\n\n你的 £8 Tesco basic 伞被吹翻——伞骨 metal 全部反向。你站着挣扎 10 秒想扳回——没用。\n\n旁边一个英国大妈撑着她那把厚重的"storm-proof"——她看你笑："That\'s a Tesco one isn\'t it. Get a Fulton, love."',
      choices: [
        { label: '把死伞塞进垃圾桶 + Google Fulton', effect: { wallet: -25, energy: -3, belonging: 3, flag: 'fulton_owned' },
          feedback: '你回 ensuite 下单 £25 Fulton Stormshield——双层 vented canopy 抗 50 mph 风。3 天到货。\n\n2 周后又一阵 25 mph 风——你的 Fulton 没动。Sarah 看你伞："Ah you got a real one. Welcome to UK."\n\n那把死掉的 Tesco 伞是你 belonging 的 entry fee。Fulton 是你 belonging 的 ID card。' },
        { label: '把翻了的伞带回 ensuite 想修', effect: { wallet: 0, energy: -5 },
          feedback: '你回 ensuite 把伞 metal 骨架掰了 30 分钟——一个完美得无 — 它彻底报废了。\n\n你扔了。下次下雨你撑着 Sainsbury 塑料袋盖头。\n\n这种 frugal 在英国不合算 — 你下次淋湿了买药 £8 + 误课 £400 学费比 £25 Fulton 贵。但你那一刻就是不舍得花。' },
      ],
    },
    {
      id: 'first_snow_trainers_slip', minWeek: 12, maxWeek: 16,
      title: '伦敦第一场雪 · trainers 滑倒',
      body: '12 月某天醒来 — 窗外白色一层。雪在伦敦 rare 但今天来了——3cm。\n\n你穿你 default Adidas trainers 出门。走到 Russell Square 第一个斜坡——sole 是平的——你脚底打滑——直接倒地。\n\nTrainers 湿。手肘磕青。一个英国大爷扶你起来："First snow innit. Get some boots love."',
      choices: [
        { label: 'Boots Marks & Spencer 买防滑鞋 (£40)', effect: { wallet: -40, energy: 3, belonging: 2 },
          feedback: '你下午直接去 M&S 买了一双 £40 winter boots——rubber sole + waterproof。\n\n第二天你穿出门——稳。一个 6 个月伦敦 winter 你没再滑过。\n\n你这一刻 unlock：北纬 51° 的鞋柜不能只有 2 双 trainers。' },
        { label: '"反正不天天下雪" 算了', effect: { energy: -5, wallet: 0 },
          feedback: '你穿 trainers 到下午——回 ensuite 时又滑了一次（这次撞到了膝盖）。\n\n3 周后 January 第二场雪你又滑——这次扭了脚踝——A&E 4 小时——X-ray 没骨折但 1 周走路一瘸。\n\nessay deadline 那一周你写不快。\n\n你这一刻知道：£40 是你 1 年 ROI 最高的 £40。' },
      ],
    },
  ],

  tesco: [
    {
      id: 'sunday_early_close_tesco', minWeek: 4, maxWeek: 50, repeatable: true,
      title: '周日 5:15 PM · Tesco Extra 已关门',
      body: '周日下午。你 dissertation 写到崩溃——决定出门去 Tesco Extra 买 meal deal + 几袋垃圾食品给自己 reward。\n\n5:15 PM 你走到门口——门已经关了。玻璃上贴着："Sunday opening hours: 11 AM - 5 PM."\n\n你看了 5 秒——周日大店 6 小时。Sunday Trading Act 1994 你 google 过但每次还是忘。',
      choices: [
        { label: '走去 Tesco Express 小店（24h）', effect: { energy: -5, wallet: -8, belonging: 1 },
          feedback: '你多走 12 分钟到 Express。货架 1/3 空——周日晚上小店都被人扫过。\n\n你买了一份能找到的 meal deal + 一袋 Doritos。回 ensuite 路上 5°C 风吹过你脸——你那一刻想起妈妈。\n\n你给她发了一条"周日伦敦超市都很早关"。她回："那国内多好 24 小时便利店。"\n\n你笑——她还是不太懂英国 daily friction。' },
        { label: '骑 Lime bike 去 Sainsbury\'s Local', effect: { energy: -3, wallet: -10 },
          feedback: '£2 解锁费 + 7 分钟骑——比 Tesco 远。Sainsbury\'s Local 11pm 关——你能赶上。\n\n但货架更空。你买了第一份能凑齐的 meal deal——三明治竟然是 prawn mayo（你不爱）。\n\n你回去吃完想：周日伦敦超市生态学需要再上一年课。' },
        { label: '"算了" 回 ensuite 吃存货', effect: { energy: -1, wallet: 0, belonging: -3 },
          feedback: '你回 ensuite 翻冰箱——上周剩的半盒泡面 + 1 个鸡蛋 + 2 片白面包。你做了一份"鸡蛋面包泡面"。\n\n你边吃边想：明天 9am tutorial 我状态不会好——但这一刻我至少 fed myself。\n\n这种 lowest-effort survival 也是一种 win。' },
      ],
    },
    {
      id: 'bank_holiday_surprise', minWeek: 16, maxWeek: 30, repeatable: true,
      title: 'Bank Holiday Monday · 全城 closed',
      body: '周一上午 10:30。你出门去 Sainsbury\'s 买东西——发现门口贴："Closed today: Bank Holiday Monday."\n\nGoogle 一查——今天是 Spring Bank Holiday。整个 UK 大部分超市/银行/邮局/政府机构都不开。\n\n你这一刻想起来——上周 BBC 推过这天，但你没记住。',
      choices: [
        { label: '去 Tesco Express 凑合（小店还开）', effect: { energy: -3, wallet: -8 },
          feedback: '你多走 15 分钟到 Express。整个店挤满了同样情况的人——一个英国老太太对你笑："Always forget innit."\n\n你笑回："Always."\n\n你买的东西比想买的少 30%——但你回 ensuite 路上想：原来 Bank Holiday 是用来"被全城提醒你 should have planned ahead"的节日。' },
        { label: '回 ensuite + 给国内朋友吐槽', effect: { energy: 1, belonging: 2 },
          feedback: '你给国内表妹发："靠 我刚出门 全 UK 关门 因为今天 bank holiday。"\n\n她："国内多好。"\n\n你笑——她不知道。bank holiday 也是英国人 protect 自己生活的方式。你这一年学会的 micro 文化差。' },
      ],
    },
    {
      id: 'self_checkout_all_broken', minWeek: 6, maxWeek: 50, repeatable: true,
      title: 'Sainsbury\'s · 8 个 self-checkout 7 个 out of order',
      body: '晚 7 点。Sainsbury\'s Bloomsbury。你拿着 meal deal 走向 self-checkout。\n\n8 个机器，7 个屏幕红字"OUT OF ORDER"。剩下那一个排了 12 个人。\n\n收银台只开 1 个。也排了 8 个人。',
      choices: [
        { label: '排 self-checkout', effect: { energy: -5, wallet: -5 },
          feedback: '你排了 18 分钟。前面那个英国大叔结账时机器突然报"unexpected item in bagging area"——大叔骂了 5 秒——一个员工过来 reset 花了 2 分钟。\n\n你最终 7:32 才走出店。\n\n你这一刻明白：UK self-checkout 是英国人发明的"让你 hate 自己"的装置。' },
        { label: '排 cashier', effect: { energy: -3, wallet: -5, belonging: 1 },
          feedback: 'cashier 是一个 50 多岁的西印度奶奶。她 scan 你的东西时跟你聊："First time here love?"\n\n你说"6 months in"。她："Bloomsbury\'s nice. Stay safe yeah?"\n\n这 30 秒小聊比 self-checkout 那 18 分钟值钱。你回 ensuite 想：cashier 也快被全替成 self-checkout 了。这种小温暖快没了。' },
        { label: '"算了"放回货架走人', effect: { energy: 1, wallet: 0, belonging: -3 },
          feedback: '你把 meal deal 放回货架走出店。\n\n回 ensuite 你只能煮泡面。你想：你刚才用 5 分钟 frustration 换 0 食物。Sainsbury\'s 这种 ROI 不太对劲。' },
      ],
    },
    {
      id: 'post_office_closed_530', minWeek: 8, maxWeek: 45,
      title: 'Post Office · 5:35 PM 关门',
      body: '周三 5:35 PM。你抱着一个 prepaid 国际包裹（要寄回国给妈，她生日快到了）冲进 Post Office——店员正在锁门。\n\n"Sorry love, closed at 5:30 sharp."\n\n你看时间——晚了 5 分钟。你要寄的东西必须明天前发出（妈生日 7 天后到中国）。',
      choices: [
        { label: '"明天再来"', effect: { energy: -3 },
          feedback: '你回 ensuite。第二天中午专门翘了一个非必要的 reading group 去 Post Office——这次提前 4:30 到。\n\n你寄出去了。妈生日礼物准时到。但你那一天 reading group 错过的也不会回来。\n\nUK 服务时间是你必须开始尊重的——你下次 9-5 就开始 plan。' },
        { label: '试试 Royal Mail 自助 (parcel locker)', effect: { wallet: -5, energy: -3, belonging: 1 },
          feedback: '你用 Royal Mail Tracked 24 自助下单——£12。然后找最近的 parcel locker——Sainsbury\'s 门口那个。\n\n你 6:12 PM 把包裹塞进 locker。妈生日礼物 7 天后到——刚好。\n\n你这一刻 unlock 了一个 hack：英国 service 9-5 关门 但 self-service infrastructure 24/7 work。这是给国际生准备的 second tier。' },
      ],
    },
    {
      id: 'small_talk_pret_freeze', minWeek: 4, maxWeek: 16,
      title: 'Pret 收银 · "Lovely weather innit"',
      body: '你 Pret 排队结账。前面英国老头 chat 收银员 30 秒——"Lovely weather, innit?" "Mind the puddles out there!" 他们笑。\n\n轮到你。\n\n收银员（一个 50 岁西印度奶奶）扫你 meal deal："Lovely weather, innit?"\n\n你愣了 1.5 秒。',
      choices: [
        { label: '"Yeah—just hope the rain holds!"', effect: { energy: 2, belonging: 8, wallet: -5, flag: 'small_talk_unlocked' },
          feedback: '她笑："That\'s the spirit love. Have a lovely day."\n\n你拿着 meal deal 走出 Pret——那一刻你不再像一个国际生 — 你 just bought a sandwich like a local。\n\n5 个月后你回看——这种 30 秒 small talk 是英国 social fabric 的 invisible weave。会的人 belong，不会的人 forever 觉得自己 outside。\n\n你今天进了 inside。' },
        { label: '尴尬笑 + 沉默', effect: { energy: -3, belonging: -3, wallet: -5 },
          feedback: '你笑了一下没说话。她也笑了一下——但 vibe 没起来。\n\n你拿着 meal deal 出 Pret。\n\n你回 ensuite 排练——下次会说什么。但你下次见她还是没说。\n\n这是英国 social code 你需要 2-3 个月才能 break in 的：tiny weather disclaimers。一旦 unlock 你就 belong — 但 lock 期间你每天都被提醒"我还没 belong。"' },
      ],
    },
    {
      id: 'waitrose_free_coffee_card', minWeek: 8, maxWeek: 50,
      title: 'Waitrose · "Your free coffee\'s on the card today"',
      body: '你拿着 myWaitrose 黄色卡刷进咖啡机——平时 black coffee 是会员免费，但今天屏幕亮起："Member bonus today: any drink, free." 你愣了一下——挑了一杯 oat flat white（平时 £3.20）。\n\n你出店门时一个西装老头看到你的黄卡——他笑："Sneaky perk that one. Took me 20 years in this country to find it." 然后他自己也排队进去。',
      choices: [
        { label: '回他："Yeah someone told me in week 3"', effect: { wallet: 0, energy: 4, belonging: 10, flag: 'waitrose_freebie_seen' },
          feedback: '老头大笑："Right, you\'re in then." 然后挥手走了。\n\n你回 ensuite 想——这种英国 chain 的 informal perk 不是 policy 是 institutional generosity，留学生圈口口相传："Waitrose 黄卡 + Pret subscription + Boots advantage card = 你伦敦下半年的隐藏 -£30/月"。\n\n你今天解锁了第一条。剩下两条 CSSA 群里能找到。' },
        { label: '不好意思笑笑 + 没接话', effect: { wallet: 0, energy: 2, belonging: 2 },
          feedback: '你点头笑了一下没说话——老头点头进店了。\n\n你回 ensuite 喝那杯 flat white——还是好喝。但你想：刚才那一秒接住对话你 belonging 就高一点。下次。' },
      ],
    },
  ],

  flat: [
    {
      id: 'lift_out_of_order', minWeek: 4, maxWeek: 50, repeatable: true,
      title: '电梯坏 · 5 楼爬',
      body: '你刚从 Tesco 回来——拎了 4 袋东西（共 8kg）。\n\n楼下 lift 门贴了 A4："Lift out of service. Engineer attending. Use stairs."\n\n你住 5 楼。',
      choices: [
        { label: '咬牙爬', effect: { energy: -10, belonging: 1 },
          feedback: '5 楼 88 级台阶。你爬到 3 楼时停下来歇 30 秒——一个英国老太太也在歇："Bloody lift breaks every fortnight, it does."\n\n你笑："I\'m starting to recognize the pattern."\n\n爬到 5 楼你瘫在自己 ensuite 床上 5 分钟。这一袋 Tesco 的成本远不是 £15——是这 88 级台阶。' },
        { label: '把袋子放门厅 + 分两次拿', effect: { energy: -8 },
          feedback: '你聪明：先拿 2 袋上去——再下来 5 楼拿剩 2 袋。总爬 10 楼但每次轻很多。\n\n第二趟你遇到一个邻居——他在拎着洗衣机零件下楼（坏了）。\n\n这种 5-flight-walk-up 团结是合租楼独有的氛围。' },
      ],
    },
    {
      id: 'wifi_router_reboot_essay', minWeek: 8, maxWeek: 50,
      title: 'Wifi 重启 · 你 essay 没存',
      body: '你写 essay 写到一半（1,200 字）。突然 Word 转圈不响了 30 秒——你才意识到 wifi 没了（你 word 在用 OneDrive 自动保存）。\n\n你下楼问—— Tom 在客厅举着 router："Sorry mate signal was rubbish thought a reboot would help."\n\n你回 ensuite——Word 已经 crash。Recovery 弹窗——你的 1,200 字只 recover 了 800 字。',
      choices: [
        { label: '"It\'s fine, mate" + 重写 400 字', effect: { energy: -10, academic: 3 },
          feedback: '你深呼吸——重写。你发现重写的那 400 字其实比第一遍更清楚（因为你已经想过一遍）。\n\n你也开始养成习惯——每写 5 分钟 Ctrl+S 强制 local save 一次。这是 Tom 给你上的免费 backup 课。' },
        { label: '"Mate seriously next time check first" 真生气', effect: { energy: -5, belonging: -5 },
          feedback: 'Tom："Sorry sorry sorry." 但他后来 2 周给你一种 walking-on-eggshells 的态度。\n\n你重写了 400 字——但你跟 Tom 之间的 vibe 也少了一点。\n\n你想：那一刻 reboot 你的 essay vs reboot 你和 Tom 的关系——也许我应该选不同的 priority。' },
      ],
    },
    {
      id: 'hmrc_emergency_tax_letter', minWeek: 10, maxWeek: 30,
      title: 'HMRC · "You\'ve been emergency taxed"',
      condition: ({ flags }) => !!flags.mei_job,
      body: '一封棕色信封—— HMRC 寄来的。\n\n"Dear Taxpayer, our records show you have been placed on emergency tax code 1257L W1/M1. You may have overpaid tax on your recent earnings. To resolve, please complete the enclosed starter checklist."\n\n你 google emergency tax——你这 6 个月在 Mei 姐店里赚的 £600 部分被扣了 32%（应该是 0%——你属于 personal allowance 之内）。\n\n大概多扣了 £80。',
      choices: [
        { label: '在 GOV.UK 上 claim refund', effect: { energy: -5, wallet: 80, academic: 3, stress: 4 },
          feedback: '你在 GOV.UK Personal Tax Account 提交 starter checklist。3 周后 HMRC 退给你 £80（直接打到 Monzo）。\n\n你给 Mei 姐看 letter——她："靠 我每年都帮新员工教这个。我居然忘了告诉你。" 她道歉送你一份红烧肉。\n\n你那一刻 unlock 一个 UK migrant tax skill——这是任何 BSc / MSc 课程都不教的。' },
        { label: '"算了 £80 而已"', effect: { energy: 1, stress: 2 },
          feedback: '你把信封塞进抽屉。3 个月后你收拾抽屉再看到——已经过 refund 申请期。\n\n£80 没了。但你也学会了一件事——UK 政府 letter 不能塞抽屉。' },
      ],
    },
    {
      id: 'smart_meter_overcharge', minWeek: 35, maxWeek: 48,
      // Hall ensuite W1-W30 是 bills-included，玩家不会单独收到 British Gas 账单。
      // 这事件只该在玩家搬进 private flat (flags.private_flat) 之后才发生。
      condition: ({ flags }) => !!flags.private_flat,
      title: 'British Gas · "Your bill: £140"',
      body: '邮箱通知：British Gas 这个月账单 £140。\n\n你跟室友一查——上个月才 £62。这个月用电也没增加。\n\n你打 customer service——held music 17 分钟。',
      choices: [
        { label: '认真 dispute + 提供 smart meter readings', effect: { energy: -8, wallet: 60, academic: 2, stress: 5, flag: 'gas_disputed' },
          feedback: '你在电话上跟 agent 据理力争 25 分钟。Agent 调出他们 estimate 数字 vs 你 smart meter 实际读数——差 78 kWh。\n\n他们 refund £60。\n\n你回 ensuite 给 Sarah 看 dispute 笔记——她："You\'re officially British now mate. Disputing the gas bill is a rite of passage." 她给你做了一杯茶。' },
        { label: '"算了 直接 paid"', effect: { wallet: -140, energy: 0, stress: 4 },
          feedback: '你交了 £140。\n\n2 周后 Sarah 才告诉你她也 dispute 过——拿回 £80。\n\n你 £80 没了——因为你假设了 utility 公司不会 estimate 错。它们会。它们经常会。' },
      ],
    },
    {
      id: 'dst_clock_back_shock', minWeek: 6, maxWeek: 7,
      title: 'Clocks Back · 4:15 PM 已经天黑',
      body: '10 月最后一个周日。clocks 调回 1 小时。\n\n你周一下午 4:15 出图书馆——天已经全黑。你愣了 5 秒——你还以为已经 6 点了。\n\nGoogle 显示日落 16:42。你这一刻 internalize 一件事：英国冬天日照 7 小时。',
      choices: [
        { label: '回 ensuite 开台灯 + 吃 vitamin D', effect: { energy: -3, belonging: -3, flag: 'dst_back_aware' },
          feedback: '你按 Boots 买的 vitamin D3 1000IU——一片 / 天。这是你在伦敦 academic 之外学到的第一门 self-maintenance 课：北纬 51° 的冬天必须人工补光照。\n\n你给妈视频——她看你脸色"瘦了"。你说"妈这边天黑得早"。她："那你早点睡。"' },
        { label: '走到 Russell Square 站台看落日', effect: { energy: -2, belonging: 4 },
          feedback: '你走到 Russell Square 公交站。橙色的 last light 透过云——3 分钟内全暗了。\n\n你拍了一张照——发朋友圈。15 个赞。\n\n你这一刻不孤独——你只是注意到了你在的纬度。' },
      ],
    },
    {
      id: 'dst_clock_forward_late_lecture', minWeek: 26, maxWeek: 27,
      title: 'Clocks Forward · 你迟到 1 小时',
      body: '3 月最后一个周日。clocks 调前 1 小时——但你忘了。\n\n周一你 8:55 醒——本来 lecture 9 AM。冲出门 9:10。\n\n你到 SOAS 时大屏幕显示 10:11。你 lecture 已经开了 71 分钟。',
      choices: [
        { label: '滑进去后排坐下', effect: { energy: -8, academic: -3, belonging: -2 },
          feedback: '你坐到最后一排——whitmore 在前面 podium 没回头。但 30 秒后他："I see we have a late arrival who has discovered British Summer Time the hard way. Welcome."\n\n全班笑。你脸红到耳朵。\n\n你这一刻开始 manually 调闹钟——iPhone auto-update DST 那一格不可信。' },
        { label: '"算了 我下午自学" 回 ensuite', effect: { energy: 1, academic: -5, belonging: -3 },
          feedback: '你回 ensuite 没去 lecture。下午自学了 lecture slides——但 missed 30 分钟 in-class discussion 是你后来 essay 直接看出来的——你那一段没 reference 到 lecture 内容。\n\nessay 拿了 65。' },
      ],
    },

    // ─── 健康 (a) ───
    {
      id: 'first_uk_cold_pharmacy', minWeek: 4, maxWeek: 12,
      title: '第一次伦敦感冒 · 不知道怎么挂号',
      body: '你嗓子疼了 3 天。咳嗽。低烧。\n\n你 google "伦敦怎么看医生"——看到 GP 流程：先 register（你已 register） → 打电话预约（最快 next available 是 8 天后）→ 现场看诊。\n\n你这一刻意识到——UK 不是国内 walk-in 三甲。',
      choices: [
        { label: '去 Boots 找药剂师', effect: { wallet: -8, energy: 4, academic: 1, belonging: 2 },
          feedback: 'Boots 后柜的药剂师听你描述 30 秒："Sounds like viral. Take paracetamol, lozenges, sleep. If fever lasts 5+ days or chest pain, then GP."\n\n她给你拿了 Lemsip Max + Strepsils + 2 板 paracetamol。共 £6.45。\n\n你回 ensuite 喝 Lemsip——3 天后好了。\n\n你这一刻 unlock：英国 light illness = pharmacist not GP。这条 hack 比 5 个 lecture 实用。' },
        { label: '硬扛 + 别管', effect: { energy: -10, academic: -5 },
          feedback: '你扛了一周。第 5 天你嗓子化脓了——只能去 GP 等到 next-day emergency slot。开了 antibiotics——晚 3 天才开始好。\n\n这一周你 essay 写不进去——直接交 deadline 那个段落是空的。\n\n你想：£6.45 当时省了 — 但代价是 1 学分 + 1 周。' },
      ],
    },
    {
      id: 'nhs_111_3am', minWeek: 12, maxWeek: 30,
      title: 'NHS 111 · 凌晨 3 点电话',
      body: '凌晨 2:45。你胸口发紧 + 心跳 110。你刚才 essay 写到崩溃。\n\n你想——这是 panic attack 还是真的有事？你打 999 觉得太严重；走去 A&E 30 分钟。\n\n你 google "NHS 111"——24h 免费电话 triage。你拨。',
      choices: [
        { label: '认真描述症状 + 跟流程走', effect: { energy: -3, belonging: 6, stress: 6, skipDays: 1, flag: 'nhs_111_used' },
          feedback: 'agent 是个有北爱口音的女声。她问你 14 个问题——逐条像 decision tree。最后她说："Sounds anxiety-related. But to rule out cardiac, I\'m booking you for an A&E walk-in within 4 hours. They\'ll do an ECG."\n\n你 4:15 走去 UCH A&E——ECG 5 分钟正常。医生："Anxiety. Common in dissertation phase. SOAS Wellbeing has same-day slots."\n\n你 6:30 回 ensuite 睡了。第二天预约了 SOAS Wellbeing。\n\n这一晚 free — 但价值 £400 ER bill 对应的私医院。NHS 是免费的奇迹——也是 wait list 的折磨。' },
        { label: '"算了 我自己睡一下"', effect: { energy: -8, belonging: -3, stress: 12 },
          feedback: '你没打。你睡到 6 点——心跳还在 95。\n\n你第二天 functional 但全天 cloudy。\n\n3 天后你又有一次。这次你认真考虑了 NHS 111——但还是没打。\n\n你这种"自己扛"的习惯——是国内带过来的——但伦敦 ensuite 不是家里 — 这种习惯在这里会变成 chronic anxiety。' },
      ],
    },
    {
      id: 'limescale_kettle_shock', minWeek: 4, maxWeek: 30,
      title: 'Kettle 里 · 一层白色',
      body: '你早上煮水泡茶——把水倒进杯子时发现壶底一层白色 sediment。看起来像 ... 矿物？你茶里也漂着一片。\n\n你 google "white stuff in kettle UK"——\n\nLimescale。伦敦 hard water 区——calcium carbonate 沉淀。无毒但难看 + 影响味道。',
      choices: [
        { label: '买 white vinegar 泡 1 小时清掉', effect: { wallet: -2, energy: 1, academic: 1, flag: 'limescale_aware' },
          feedback: '你 Tesco 买了 £1.50 distilled white vinegar。倒进 kettle 加水——煮开 2 次——倒掉——清水煮 1 次。\n\n壶底干净了。\n\n你给妈视频——她看你在干嘛："那是什么？" 你："limescale。伦敦水太硬。" 她："那你以后不要直接喝——要烧开。"\n\n你笑——她自动 worried。但你这一刻有了一个新的 UK survival 技能。' },
        { label: '"反正是水煮过的" 继续用', effect: { energy: 0, belonging: -1 },
          feedback: '你继续用。茶味永远怪怪的——但你 normalize 了。\n\n2 个月后 Sarah 用你的水壶煮水："Babe your kettle is GROSS." 她当场给你示范 vinegar trick。\n\n你这种"将就"在英国生活会被英国朋友 directly call out。这也是 belonging 的一种 — 但你不是非要被 call out 才学。' },
      ],
    },
    {
      id: 'vitamin_d_brain_fog_january', minWeek: 16, maxWeek: 22,
      title: 'Vitamin D 低 · 1 月 brain fog',
      body: '1 月底某周一。你 alarm 响了 4 次——你最终 9:45 才起床。\n\n你坐在床上 30 分钟动不了。不是 sad。不是 anxious。就是——空。\n\n你 google "winter brain fog UK"——日照不足导致 vitamin D < 25 nmol/L → 慢性疲劳 + 情绪低落。北纬 51° 10 月-3 月日光合成 vitamin D 几乎归零。',
      choices: [
        { label: 'Boots 买 Vit D3 1000IU + 每天吃', effect: { wallet: -5, energy: 8, academic: 2, flag: 'vit_d_started' },
          feedback: '你 Boots 买了一瓶 90 片 vitamin D3 £4.99。每天早上一片。\n\n2 周后你早上能 10:00 之前起床了。3 周后你的 brain fog 减轻 60%。\n\n你给国内朋友发："靠 我之前是缺 vitamin D 不是 lazy。" 她："救命 我也是。我妈一直骂我懒。"\n\n你这一刻 internalize 一件事——北纬 51° 留学生 1 月不是性格问题——是化学问题。' },
        { label: '硬撑 + 多睡', effect: { energy: -10, academic: -5, belonging: -3 },
          feedback: '你睡到 11 点 / 12 点 / 1 点——越睡越累。\n\n2 周后你 essay 写不出来——你以为是 procrastination。其实是 vitamin D。\n\n3 月你才知道。但那 6 周已经没了。' },
      ],
    },

    // ─── 银行/手续 (b) ───
    {
      id: 'monzo_frozen_card', minWeek: 8, maxWeek: 40,
      title: 'Monzo · "Card temporarily blocked due to suspicious activity"',
      body: '周五傍晚。你在 Tesco 自助结账——刷 Monzo。屏幕："Card declined."\n\n你打开 Monzo app——红条 banner："We\'ve temporarily blocked your card due to suspicious activity. Tap to verify."\n\n你今天没干啥。但 Monzo 把你 transaction 标了——大概是 9:30 那笔 Westfield 给王凯代购 £80 的。\n\n你后面排了 3 个人。',
      choices: [
        { label: 'app 内 chat verify + 解封 (15 分钟)', effect: { energy: -3, wallet: -8, belonging: 1, stress: 4, flag: 'monzo_verified' },
          feedback: '你跳出 Tesco 结账队 — agent 在 Monzo chat 里 4 分钟 verify 完。卡解封。\n\n但 Tesco 那个 cashier 很 nice："Take your time, mate. Better safe than sorry." 你最终 7 分钟回到结账机——结账。\n\n你这一刻 internalize：Monzo / challenger banks 比传统银行 paranoid 得多——有时候 protective 有时候 over-trigger。但他们 chat 速度让 traditional banks 完败。' },
        { label: '"靠" 放下东西回 ensuite', effect: { energy: -3, belonging: -3, stress: 6 },
          feedback: '你不想跟 cashier 解释——直接放下购物篮走出店。\n\n你 30 分钟后在 ensuite 才 verify。但你也 missed dinner — 你只能煮泡面。\n\n你给 Monzo 写了一封 angry feedback。他们回了一封 apology。但那一晚的羞耻不会回来。' },
      ],
    },
    {
      id: 'nin_appointment_6_weeks', minWeek: 6, maxWeek: 16,
      condition: ({ flags }) => !!flags.mei_job,
      title: 'National Insurance Number · 预约 6 周后',
      body: 'Mei 姐说："你来打工 我得给你 NIN 入工资系统。" 你 google "apply for National Insurance Number"——\n\n第一步：网上 apply。第二步：打电话 0800 141 2075 预约 in-person interview。第三步：现场拿信。\n\n你打电话——agent："Earliest available is 6 weeks from now."\n\n6 周。Mei 姐想给你 cash-in-hand 但她自己有 PAYE 系统。',
      choices: [
        { label: '等 6 周 + Mei 姐 informal cash 期间', effect: { energy: -3, wallet: 200, belonging: 3, flag: 'nin_pending' },
          feedback: 'Mei 姐："我先 cash-in-hand 给你 4 周——一周 £50。我账面上记你是 trial period。"\n\n6 周后你 NIN 拿到——直接进 PAYE 系统。Mei 姐补给你 trial period 的 £200。\n\n你给妈："妈我有英国社保号了。" 她："那你算英国人了？" 你笑："还差 6 年。"\n\n你这一刻 unlock 一个 official ID — 英国 ecosystem 真正接住你。' },
        { label: '换一份不要 NIN 的活（送外卖）', effect: { energy: -10, wallet: 80, belonging: -3 },
          feedback: '你 Deliveroo Rider 注册——他们那时候 student 不需要 NIN（gig worker rules）。你跑 5 单 / 周 — 每单 £6 — 6 周后总收入 £180 (excluding bike rental + 雨)。\n\n但你也错过了 Mei 姐这层 belonging。\n\n你回 ensuite 路上下大雨——你想：£180 vs Mei 姐桌上的红烧肉，你这一刻不知道哪个更值。' },
      ],
    },
    {
      id: 'council_tax_letter_scare', minWeek: 6, maxWeek: 14,
      title: 'Council Tax · "You owe £1,847"',
      body: 'Royal Mail 送来一封 Camden Council 的棕色信。\n\n"Dear Resident, your Council Tax bill for 2024-25 is £1,847. Payment due in 10 instalments. First instalment £184 due by [next month]."\n\n你愣了——你是 student 应该 exempt。但你没主动 file student exemption certificate。Council 不知道你是学生——直接发了 standard bill。',
      choices: [
        { label: '在 Camden Council 网站 file student exemption', effect: { energy: -3, academic: 2, belonging: 4, stress: 3, flag: 'council_tax_filed' },
          feedback: '你打开 Camden Council 网站 — Student Exemption Form。需要 SOAS issued letter (你预约 SOAS Student Centre 拿——next-day available)。\n\n你 3 天内提交完整。Council 回邮件："Exemption confirmed. £1,847 charge cancelled. New balance: £0."\n\n你这一刻知道：UK bureaucracy 的 default 是 charge you。你必须主动 opt-out。这是国际生很难学的一课。' },
        { label: '"我 student 我不交" 不管', effect: { wallet: -100, energy: -8, belonging: -5, stress: 10 },
          feedback: '你不管。1 个月后 Council 寄来 reminder + late fee £40。3 个月后 escalation 到 debt collector。\n\n你最终交了 £100 处理（partial payment + admin fee）。\n\n你 file 了 exemption 但 retroactively only refund 部分。\n\n你这一刻 learn — 在英国"我有理"不等于"系统知道"。系统需要你 actively prove。' },
      ],
    },
    {
      id: 'bank_app_2fa_lost_sim', minWeek: 4, maxWeek: 12,
      title: 'Lloyds 2FA · 国内 SIM 不能收 SMS',
      body: '你来英国第 4 周。换了 UK O2 SIM。\n\n你想登录 Lloyds 国内分行 app（你来之前在国内开的英镑账户）— 它给你国内手机号 SMS verification。但你国内号停机了。\n\n你被锁在自己 £4,000 学费 buffer 之外 — Lloyds 说必须打国内 customer service 改预留号。',
      choices: [
        { label: '打国内 Lloyds 客服 + WeChat 改', effect: { energy: -8, wallet: -3, academic: 1, stress: 8, flag: 'lloyds_recovered' },
          feedback: '你深夜（北京时间白天）打 Lloyds 国内 hotline。25 分钟客服。她要你提供 5 个 verification questions——其中 1 个你忘了（你妈生日 vs 你爸生日）。\n\n她："请联系您预留的紧急联系人——您妈妈。"\n\n你给妈打电话。她接了。10 分钟 3-way 你 Lloyds 中文客服 + 妈中间转。\n\n最终改号成功。妈："这种事 你以后跟妈说 妈替你管。"\n\n你这一刻——一个 22 岁留学生第一次被 forced 承认：完全 independence 是错觉。妈还在 backup 你 8000 公里之外。' },
        { label: '激活国内号漫游', effect: { wallet: -50, energy: -3, stress: 4 },
          feedback: '你给国内号充话费 £50 开 international roaming。SMS 收到。\n\n你 changed UK 号到 Lloyds。然后停了国内号 roaming。\n\n£50 解决——但你也意识到：这种 cross-border admin 一年还会撞 5 次。' },
      ],
    },

    // ─── 房屋小事故 (c) ───
    {
      id: 'washing_machine_eats_coin', minWeek: 6, maxWeek: 50, repeatable: true,
      title: 'Communal Laundry · 洗衣机吃了 £3',
      body: '宿舍 communal laundry。你塞了 £3 硬币——机器 显示 "PAYMENT ACCEPTED" — 但 cycle 没启动。屏幕回到主菜单。\n\n你拍了机器 2 下。没用。你看了一眼 —— 旁边一个英国男生也在看你："That one\'s been doing it. Use number 4. The notice came down last week but they never fix it."\n\n墙上确实没贴 notice — 但有一个 faded square where notice used to be。',
      choices: [
        { label: '换 4 号机 + 报修', effect: { wallet: -3, energy: -3, belonging: 4 },
          feedback: '你换 4 号——work 了。\n\n回 ensuite 你给 housing 发 email + 附那个英国男生的话。3 周后 housing 退你 £3 + 修了机器。\n\n你这一刻 unlock 英国 housing complaint 流程：发 email + paper trail + escalate to building manager if no response in 14 days。\n\n那 £3 你拿回来了——但价值是 paper trail discipline。' },
        { label: '"算了" + 换机器不报修', effect: { wallet: -3, energy: -3 },
          feedback: '你换机器了。但你没报修。\n\n2 个月后那台机器仍然在吃别人钱——你看到一个新生女生哭着站在那里盯着屏幕。你那一刻后悔——你当时 file 一个 5 分钟 email 能省别人这个 moment。\n\n这是英国留学生最容易 miss 的 belonging 形式：community advocacy。你这一刻没站出来。' },
      ],
    },
    {
      id: 'fridge_freezer_iced', minWeek: 14, maxWeek: 50,
      title: '冰箱冷冻层 · 冻成砖头打不开',
      body: '你想从冷冻层拿一袋 Tesco 速冻 dumpling — 冷冻层门被 4cm 厚的冰挡住。\n\n这是 communal 冰箱 — 没人管。你 Sarah 看了一眼："This thing\'s been here longer than I have. It needs defrosting. Like, fully unplug for 6 hours."',
      choices: [
        { label: '组织一次 defrost · 全合租参与', effect: { energy: -8, belonging: 12, flag: 'fridge_defrosted' },
          feedback: '你在合租 group chat 发 message："Sat 10am defrost the freezer? It\'s 4cm thick. We all have to take stuff out."\n\nSarah + Tom + 2 个其他 housemate confirm。周六上午你们 5 个人把冷冻东西全搬到一个塑料 cooler 里 — 拔电源 — 冰开始化。中间你们一起做了早餐喝咖啡。\n\n6 小时后冰化完。你们重新 plug 回去。housing group chat 30 秒后"thanks for organizing this"。\n\n你这一刻 unlock 一个 leadership skill — communal living 不需要 boss，只需要一个 willing organizer。' },
        { label: '用刀凿冰拿到 dumpling', effect: { energy: -5, belonging: -2 },
          feedback: '你用 Tesco £4 的菜刀凿冰 — 凿出一个能塞手进去的洞 — 拿到 dumpling 包。\n\n但你也凿穿了内壁——freezer plastic 被你刺了一个洞。\n\n2 个月后 housing inspection 发现 — 你们押金扣了 £80。\n\n你不会承认这是你干的——但你心里知道。' },
      ],
    },
    {
      id: 'toast_fire_alarm', minWeek: 4, maxWeek: 50, repeatable: true,
      title: '8 AM · Tom 烤焦 toast · 全楼 fire alarm',
      body: '早 8:14。你刚刷牙——警报突然响。整栋楼在叫。\n\n你出门——走廊里几个 housemate 穿着 hoodie 骂街。Sarah 路过你："Tom. Toast. Again."\n\n你下楼到街上——零下 2 度。100 个 housemate 站在路边 — 一半穿睡衣。Fire engine 5 分钟到。',
      choices: [
        { label: '在街上跟 Sarah 一起骂 Tom', effect: { energy: -3, belonging: 6, wallet: -3, stress: 4 },
          feedback: 'Sarah 把她外套披你身上——她穿了两层。你们站着喷白气吐槽 Tom 15 分钟。\n\n隔壁宿舍楼一个学生过来："This your building? We had this last week too."\n\n你们 3 个站着边骂边笑 — fire engine 那几个 fireman 看着我们摇头。20 分钟后 reset。\n\n你这一刻 belong 到一个 small London 留学楼 fire alarm community 里。这种 belonging 哭笑不得但是真的。' },
        { label: '冷得不行 + 去 Pret 买热咖啡', effect: { wallet: -4, energy: 3, stress: 3 },
          feedback: '你走到 Russell Square Pret 买 £3.50 latte。\n\n回到 building entrance 时刚好 reset。\n\n你回 ensuite — 你那杯 latte 比 Tom 那块 toast 贵 11 倍。但你回床上躺 5 分钟还是暖的。' },
        { label: '"我不下楼"（回床躺）', effect: { energy: -8, belonging: -5, wallet: -40, stress: 8 },
          feedback: '你忽略警报。10 分钟后一个 fireman 打开你 ensuite 门——脸黑："Mate when the alarm goes off you GO. Could be a real fire next time."\n\n你脸红到耳朵。你被 fine £40。\n\n你这一刻 learn — UK fire safety 不是儿戏。下次 alarm 你 30 秒下楼。' },
      ],
    },
    {
      id: 'gas_meter_zero_shower', minWeek: 12, maxWeek: 36,
      title: 'Gas Meter · 洗澡到一半水变冰',
      body: '冬天某天晚 9 点。你在 communal shower 洗到一半——水突然从热变温变冰冷。\n\n你 30 秒后跳出来——还套了一身泡沫。Sarah 在走廊："The gas meter\'s gone to zero. Tom\'s on his way to top up." 她递你一条毛巾。\n\n你裹着毛巾在你 ensuite 等 Tom 回来。',
      choices: [
        { label: '一起去 Co-op top up gas card', effect: { energy: -5, wallet: -20, belonging: 6 },
          feedback: '你 Tom Sarah 三个人 9:30 PM 走 5 分钟去 Co-op。他们卖 PayPoint top-up——£20 = 2 周 gas。\n\n回来路上 Tom："we should set a calendar reminder for top-ups. I\'ll do it." 你说"thanks mate"。\n\n回到 building 你们等 30 分钟 system 恢复。10:15 你 finally 洗完。\n\n你这一刻 internalize — 英国合租楼 communal utility 的 invisible coordination — 谁 top-up / 谁倒垃圾 / 谁清 fridge — 是合租成败的核心。' },
        { label: '"Tom 处理就行" 回 ensuite 等', effect: { energy: -3, belonging: -1 },
          feedback: '你回 ensuite 等。Tom 一个人去了 Co-op。30 分钟后回来 + 充值。\n\n你 10:30 洗完。\n\nTom 没说什么——但你知道下一次 alert 他不会主动叫你。这就是 communal 关系的 micro-economics — 你这次没 contribute — 你下次 default 是 outsider。' },
      ],
    },

    // ─── 食物文化撞击 (f) · 自家厨房 ───
    {
      id: 'first_sunday_roast_attempt', minWeek: 14, maxWeek: 36,
      title: '第一次自己做 Sunday roast · chicken 外焦内生',
      body: '周日。你想给 Sarah + Tom 做 Sunday roast——你 YouTube 看了 3 个 Jamie Oliver 视频。\n\n你买了：whole chicken £6.5 + roast potatoes + 4 carrots + Yorkshire pudding mix £1.2 + 1 罐 gravy granules。\n\n2 小时后——chicken 外面焦黑，切开里面 pink。Yorkshire pudding 没起来——3 个塌的。Carrots 烤过头变糖。\n\nSarah 走进厨房闻到味："Oh god mate it smells *intense*. You alright?"',
      choices: [
        { label: '诚实承认 + 让 Sarah 教你 carryover heat', effect: { wallet: -12, energy: 5, belonging: 12, npc: { sarah: 2 }, flag: 'roast_attempted' },
          feedback: 'Sarah 看了 chicken 笑："First time? Babe, you have to take it out and let it *rest* — internal temp keeps rising. The skin will dark before the inside\'s done if you don\'t cover it with foil halfway."\n\n她跟 Tom 来吃了——他们没嫌弃。Tom 把 Yorkshire pudding 往 gravy 里泡："Looks worse than it tastes mate."\n\n你这一刻 unlock 一个英国 ritual——Sunday roast 是你不是 cook 一道菜，是 cook 一种 belonging。Sarah 第二个周日教你做了一遍正确版本——这成了你们 ensuite 的 ritual。' },
        { label: '"算了"（点 takeaway 救场）', effect: { wallet: -22, energy: -5, belonging: 2 },
          feedback: '你扔掉 chicken 点了 Roast Roost £15 一份 takeaway。Sarah Tom 不知道——他们以为是你做的。\n\n但你以后不再尝试 Sunday roast。你错过了一个 ritual。\n\n5 个月后 Sarah 提起"你那次 roast"——你慌了 0.3 秒。她："不是 takeaway 那个吗。" 你那一刻知道她 5 个月前就发现了——但她保护你的脸。这种 friendship 比 roast 重。' },
      ],
    },

    // ─── 天气微暴击 (g) · 9月→5°C 一夜 ───
    {
      id: 'september_to_5c_overnight', minWeek: 4, maxWeek: 6,
      title: '9 月某天 · 一夜从 18°C 到 5°C',
      body: '昨天你穿 T-shirt + jeans 出门——18°C 阳光。你把 ensuite 暖气关了。\n\n今早醒来——你哆嗦——窗户开 5cm 进风。\n\n你看天气 app——5°C。BBC 新闻头条："Sudden cold snap as Atlantic front sweeps UK."\n\n你的羽绒服还压在行李箱底——你来时妈说"伦敦不冷"。',
      choices: [
        { label: '从行李箱底翻出羽绒服 + 打开 heating', effect: { energy: 3, wallet: -2, belonging: 2 },
          feedback: '你翻箱底花了 15 分钟——羽绒服压扁了 6 周——shake 出形。打开 heating——15 分钟暖。\n\n你 google "London weather september"——平均 12-18°C 但 cold snaps 出乎意料。你这一刻 internalize：英国天气不是温度——是 layers。\n\n你给妈视频："妈伦敦不冷你说错了。" 她："那你穿厚点。"' },
        { label: '"穿 hoodie 凑合一天"', effect: { energy: -8, belonging: -3 },
          feedback: '你穿 hoodie + jeans 出门——风一吹冷到骨头。中午你 google nearest Primark——£25 买了一件 cheap puffer。\n\n你那天什么 productive 都没做——全身在抖。\n\n第二天你嗓子疼。你 14 周里第一个感冒就是从这一天开始。' },
      ],
    },

    // ─── 室友 micro 摩擦 (h) ───
    {
      id: 'oat_milk_barista_stolen', minWeek: 8, maxWeek: 50, repeatable: true,
      title: '你 £2.50 oat milk barista edition · 被喝光',
      body: '周二早上 7:45。你拿出 fridge 那盒 Oatly Barista Edition (£2.50)——上周你专门去 Sainsbury 大店买的——你想给自己 latte + 半盒留 dissertation 期间。\n\n盒子轻得不对劲。你打开——50ml。一半空。\n\n冰箱门贴的 white-tape 上你写的 "[YOUR NAME]" 还在。',
      choices: [
        { label: '在 group chat 直接问', effect: { energy: -3, belonging: 4, flag: 'oat_milk_called_out' },
          feedback: '你拍照发 group chat："Did anyone use my oat milk? It\'s the £2.50 Barista one — I had it labelled."\n\n3 分钟后 Tom 回："Shit mate that was me. Made a coffee at 3 AM. Will replace today, sorry." 5 分钟后他 Venmo 你 £2.50 + 一个流泪表情。\n\n你那一刻 unlock UK flatmate code——直接 call out 不 passive aggressive。Tom 没生气——他 respect 你 directness 比之前更多。' },
        { label: '生闷气 + 默默在 fridge 贴更狠 label', effect: { energy: -5, belonging: -3, stress: 6 },
          feedback: '你贴了一张 A4："THIS OAT MILK IS NOT YOURS. PLEASE STOP." 用红笔。\n\n那张 A4 在冰箱挂了 6 周——后来 Sarah 私下跟你说"hey is everything OK?"——她以为你 mental health 有事。\n\n你 cringe。你下次直接 message。' },
      ],
    },
    {
      id: 'dirty_pot_24h', minWeek: 14, maxWeek: 50, repeatable: true,
      title: '你 £18 nonstick 锅 · 剩饭粘 24 小时',
      body: '周四晚 7 点你做饭——你的 £18 IKEA nonstick 锅。\n\n周五晚回来——锅在 communal 厨房水池——里面是 Tom 周五午做的咖喱剩——红色酱汁 + 鸡块——已经粘 24 小时。\n\n你试着用海绵擦——nonstick 涂层下面已经被酸性咖喱蚀出 2 个白点。',
      choices: [
        { label: '直接找 Tom 谈 + 让他赔', effect: { wallet: 18, energy: -3, belonging: 4, flag: 'pot_replaced' },
          feedback: '你敲 Tom 房门："Mate the nonstick coating got damaged from your curry sitting 24h. I need £18 for a replacement."\n\nTom 愣了 1 秒——你以为他要 push back。但他："Fuck mate I\'m sorry. Honestly I forgot to wash up. Venmo coming."\n\n2 分钟后 £18 到账。\n\n你这一刻 unlock：英国 flatmate 不是 confrontation-shy ——他们 respect "你 directly 提出 + 我 make it right" 这套。被动 aggressive 反而 disrespected。' },
        { label: '"算了" + 自己用海绵擦坏的锅', effect: { wallet: 0, energy: -5, belonging: -2 },
          feedback: '你自己擦了 30 分钟——nonstick 报废。下个月你做饭东西全粘——你只能再花 £18 买新的。\n\n你那时候才意识到——你为了避免 30 秒的 awkward conversation，付了 £18 + 1 个月的 cooking misery。\n\n这种"忍"的国内习惯在 UK 合租生态里 cost 比 confrontation 高得多。' },
      ],
    },
    {
      id: 'midnight_visitor_unannounced', minWeek: 8, maxWeek: 50, repeatable: true,
      title: '凌晨 1 点 · Sarah 男朋友按门铃 8 次',
      body: '凌晨 1:14。门铃响——你刚睡 30 分钟。\n\n响了 5 次。你以为 Sarah 朋友——5 次没人开。\n\n第 6 次。第 7 次。\n\n你穿 hoodie 下楼开门——一个戴 SnapBack 的英国男生："Alright mate, Sarah\'s? She\'s not picking up."\n\n是 Sarah 男朋友 James。Sarah 房间灯暗着——大概戴耳塞睡了。',
      choices: [
        { label: '让他进 + 第二天跟 Sarah 提', effect: { energy: -8, belonging: 2, stress: 5 },
          feedback: '你让 James 进——他直接上楼敲 Sarah 门。\n\n第二天早上 Sarah 在厨房："Soooo sorry about James. He drinks then thinks the world owes him entry. I owe you a big coffee."\n\n你说："It\'s fine but maybe—uhm—communal door rules?" Sarah："One hundred percent. House meeting Sunday. We\'ll fix the spare key situation."\n\n这一刻你 unlock：UK flatmate culture 的 midnight intrusion 不是 expected baseline——你 raise concern 是 normal。你不需要 toleate 不合理。' },
        { label: '让他进 + 心里默默生气', effect: { energy: -10, belonging: -3, stress: 10 },
          feedback: '你让 James 进——回 ensuite 睡——但翻来覆去到 3 点。\n\n第二天早上你跟 Sarah 关系 cool。她 sense 到——但你不说她也不 know how to fix。\n\n3 周后这种事又发生 1 次——这次 4 点凌晨。你 finally 在 group chat 提——但已经积累了 3 周不必要的 resentment。\n\n你这一年学了一课：sit with discomfort and address it ≠ tolerate it forever。' },
        { label: '"Sarah\'s asleep mate" 直接关门', effect: { energy: -3, belonging: -5, stress: 6 },
          feedback: 'James："Mate are you serious—" 你关门。\n\n第二天 Sarah 在厨房有点 awkward："Heard you turned James away last night?" 你说"He was buzzing 8 times at 1 AM。"\n\nSarah 沉默 2 秒。"Fair enough. I\'ll talk to him."\n\n但接下来 1 周 vibe 有点冷——Sarah 和 James 大概吵了。你 stand 你的 boundaries 是对的——但你也学到 boundaries 的 social cost 是 short-term discomfort。' },
      ],
    },
    {
      id: 'mail_opened_by_mistake', minWeek: 10, maxWeek: 30,
      title: 'Sarah 拆了你的 BRP renewal letter',
      body: '你回 ensuite——门厅桌上你的 mail 已经被打开。Home Office 的 BRP renewal reminder——你这一年最 emotionally loaded 的文件之一。\n\nSarah 推门："Babe sooo sorry I thought it was mine — same name format. It\'s your BRP something? I didn\'t read past the first line, promise."\n\n你心里立刻起一层薄汗——不是因为 Sarah，是因为这种文件被任何人碰都让你 trigger。',
      choices: [
        { label: '"It\'s fine but BRP letters please leave sealed"（明确边界）', effect: { energy: 1, belonging: 3, stress: 3 },
          feedback: 'Sarah 立刻："Yeah of course — God, anything Home Office I\'ll literally not even pick up. So sorry." 她 genuinely sorry。\n\n你回 ensuite 看 letter——BRP 6 月到期 reminder。你 mark calendar。\n\n你 raise 了边界——没 escalate 但说清楚了。这种 light touch boundary-setting 是合租 sweet spot。\n\n你这一刻意识到：对你 emotionally loaded 的东西，国内 / 合租文化 weighting 不同。说出来不是过度反应——是 calibration。' },
        { label: '"That\'s a legal immigration document Sarah"（沉下脸）', effect: { energy: -3, belonging: -3, stress: 5 },
          feedback: 'Sarah 脸色一沉："I—I know. I\'m really sorry. I literally read one line. I\'ll never touch anything Home Office again."\n\n她回房间。那一刻 vibe 有点冷——但 24 小时之内她在厨房给你递了一杯茶："Look. I get it. My passport sat in the same envelope format. I would\'ve panicked too if it were the other way."\n\n你那一刻 unlock 一件事：英国 flatmate culture 对 immigration paperwork 没有同样 stakes——但 raising 这个 stakes 是合理的，不是 over-react。Sarah 也 calibrate 了。\n\n这种 cross-cultural 边界协商比"It\'s fine"更难——但你 24 小时之内你们都更明白对方的 ground 在哪。' },
      ],
    },
  ],

  pub: [
    {
      id: 'pub_round_etiquette', minWeek: 6, maxWeek: 30,
      title: 'Pub · 第一次"轮请"礼仪',
      body: '你和 Sarah + 2 个 Sarah 朋友在 pub。\n\nSarah 站起来："Right, my round! What are you all having?" 她带回 4 杯酒 — pints £6 each — 共 £24。\n\n半小时后第二个朋友站起来："My round!" 她也带回 4 杯。\n\n再 30 分钟另一个朋友的轮。\n\n现在 — 该你了。没人说什么但所有人 finished glass 都放在桌上。',
      choices: [
        { label: '站起来 "My round!" + 买 4 杯', effect: { wallet: -24, energy: -3, belonging: 14, flag: 'pub_round_done' },
          feedback: '你站起来："Right, my round." 拿 4 杯回来。\n\nSarah 笑了——非常 subtle 但她笑了——她朋友也："Cheers mate." 一种轻微的 acceptance。\n\n你这一刻 unlock 英国 pub 文化最重要的一条：rounds。3 个朋友各 buy £24 一轮——你不 buy 你的就 forever 是 outsider。这一晚的 £24 不是 4 杯酒——是 acceptance fee。\n\n你回 ensuite 路上 Sarah 说："First round\'s the hardest. You\'re sorted now." 你这一刻知道她在 mentor 你。' },
        { label: '"我下杯不喝了 谢谢"（pre-empt round）', effect: { wallet: 0, energy: 1, belonging: -8 },
          feedback: '你说"我下一杯不要了"。3 秒沉默。Sarah："OK, sure." 她没强求。\n\n但接下来 30 分钟你能感觉到 vibe 不一样了——你把自己 opt-out of group。\n\n回家路上 Sarah："Hey. Brits aren\'t mad if you don\'t drink. But if you\'re *with* a group at a pub — you\'re in the round system. Even if you\'re drinking water you order water on your round. Just so you know for next time." 你点头。\n\n这是你这一年最贵的 £0 — 你保住了那 £24 但损失了那一晚 belonging。' },
        { label: '装作没看到 + 让别人 buy 第 4 round', effect: { wallet: 0, energy: -3, belonging: -15, flag: 'pub_round_failed' },
          feedback: 'Sarah 等了 30 秒。然后她站起来："Alright I\'ll do another." 她去吧台时回头看你 0.3 秒。\n\n这一晚之后 Sarah 没再约你 pub。她还跟你 nice 但不一样。\n\n3 周后你才意识到——pub round 是 invisible loyalty test。你那一晚 fail 了。' },
      ],
    },
    {
      id: 'how_are_you_real_answer', minWeek: 4, maxWeek: 16,
      title: '"How are you?" · 你认真回答了 5 分钟',
      body: 'Tutorial 后。同班的英国女生 Emma 路过："Hi! How are you?"\n\n你停下——开始认真回答："Actually pretty stressed about the dissertation? My supervisor wants me to redo chapter 2 and I haven\'t slept well since—"\n\nEmma 的眼神在 5 秒内从 polite 变成 panicked。你看到她 backpack 上有 lecture notes 她明显赶时间——你 talking 的 60 秒。\n\n你突然意识到。',
      choices: [
        { label: '收尾 "anyway just stressed yeah you?"', effect: { energy: -3, belonging: 3 },
          feedback: 'Emma "Oh same dissertation is killing everyone! Got to run, talk later!" 她跑了。\n\n你站在走廊愣了 5 秒。然后笑了。\n\n你这一刻 unlock 一条英国 social code 国内不教的 — "How are you?" 是 hello — 不是 "how are you?"。Standard reply: "Good, you?" 永远不超过 2 秒。深聊请约 coffee — 不在路过 corridor。\n\n你回 ensuite 想：英国人不是冷漠，是 phatic — 他们 build 友谊靠 ritual frequency 不靠 disclosure depth。' },
        { label: '继续讲完 + 让她迟到', effect: { energy: -3, belonging: -5 },
          feedback: 'Emma 听完 — 但她明显焦虑。"OK best of luck, gotta run!" 她跑。她那次 lecture 迟到 3 分钟。\n\n下周 tutorial 她 small-talk 你时不再问 "How are you?"——直接 "Did you do the reading?"。\n\n你这一刻把一个 social ritual 当成了 disclosure invitation。她的 default 是 phatic — 你的 default 是 sincere。这种 mismatch 在英国会持续打你脸 1 年。' },
      ],
    },
    {
      id: 'thank_you_driver', minWeek: 4, maxWeek: 50, repeatable: true,
      title: 'Bus 下车 · "Thank you, driver"',
      body: '你坐 73 路从 Soho 回 Bloomsbury。下车时——前面那个英国老太太对司机说："Thank you, driver!" 司机回："You\'re welcome love!"\n\n你没说过这句。你来伦敦 6 周——每天坐 bus——从来没说过。\n\n下一站快到了。',
      choices: [
        { label: '今天试一下', effect: { energy: 2, belonging: 8, flag: 'thanked_driver' },
          feedback: '你下车时——憋了一秒——说："Thank you, driver."\n\n司机回头："Cheers love!"\n\n你下车走出 5 步——突然觉得脸暖。这一刻你比刚才上车时更属于伦敦了一点点。\n\n这种 micro-belonging 你第一次注意到。从此以后你每次 bus 都说。3 个月后这成为你 ritual——一个 22 岁中国留学生学到的最英国的小动作。' },
        { label: '今天还是不说', effect: { belonging: -1 },
          feedback: '你下车没说话。\n\n但走在街上你想到——为什么我说不出口。是不知道 phrase 吗？不是。是 fear 自己 accent 怪？也许。\n\n下一次。下一次你试。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // 学术礼仪 (e) · uni location
  // ─────────────────────────────────────────────────────────────
  uni: [
    {
      id: 'email_dr_prof_typo', minWeek: 2, maxWeek: 8,
      title: '第一封 email 给 Whitmore · 称呼踩雷',
      body: '你给 Whitmore 写第一封 email——询问 reading list 的 ambiguity。\n\n你写："Dear Mr Whitmore..."\n\n你 send 之后 5 分钟——回信："Dear [your name], thank you for your message. A small note: in UK academia, \'Mr\' is generally not used for academic staff. \'Dr\' (PhD holders) or \'Professor\' (full chair) is preferred. I am the latter. — Best, R. Whitmore"',
      choices: [
        { label: '立刻道歉 + "Sorry, won\'t happen again"', effect: { energy: -3, academic: 3, belonging: 4, npc: { whitmore: 1 } },
          feedback: '你回："Apologies Professor Whitmore — won\'t happen again. Thank you for the correction."\n\nWhitmore 回："No need to apologise — common slip among new students. Now let\'s answer your reading list question..."\n\n他给了你 4 段 helpful 答复。\n\n你这一刻 unlock：UK academia 里 honorifics 是 invisible test。错一次没事，但 acknowledge 错 比"假装无事"重要。' },
        { label: '装作没看到 + 下次还是 Mr', effect: { energy: -3, belonging: -5, npc: { whitmore: -1 } },
          feedback: '你没回。下周 tutorial Whitmore 看你的眼神有点 distance。\n\n2 个月后你 reference letter 那段时间——你 sense 到 Whitmore 写 letter 时不会用 "outstanding" 那个词。\n\n这是英国 academia 的 quiet penalty——你不会被骂，但你会被记住。' },
      ],
    },
    {
      id: 'lecture_seating_segregation', minWeek: 4, maxWeek: 14,
      title: '前排 / 后排 · 你看到的隐形分化',
      body: '你 lecture 第 4 周——你坐前排第二排——你养成习惯了。\n\n今天你 5 分钟早到——扫一眼整个 lecture hall：\n\n· 前排 3 排：12 个亚洲面孔（10 个中国 + 2 个韩国）\n· 中间：mix\n· 后排：清一色英国本地 + 欧洲学生——他们已经在低声笑\n\n你这一刻意识到——这种 self-segregation 你第一天就 observed 但今天 click。',
      choices: [
        { label: '今天换坐中间 + 跟旁边英国人说 hi', effect: { energy: -3, belonging: 8, academic: 2, flag: 'lecture_mid_row' },
          feedback: '你坐到第 6 排靠中间——旁边是一个英国女生 Beth。你打招呼："Mind if I sit here?" 她："Of course not, go for it."\n\nlecture 中段她 lean over："Did you catch what he said about Bourdieu?" 你 nodded。\n\n散场你们 walked together 到 Russell Square Pret。她："First time seeing you in mid-row." 你："First time trying it."\n\n3 周后你和 Beth 成了 study buddy。\n\n你这一刻 unlock：seating 是 invisible self-fulfilling — 你第一天选择前 2 排，你下一年的 friendship pool 已经 narrowed by 70%。' },
        { label: '"前排习惯了" 继续坐前面', effect: { energy: 1, academic: 3, belonging: -2 },
          feedback: '你坐前排——专注 lecture——成绩好。\n\n但你 1 年下来 cohort 里你只熟 6 个人——全是中国学生。这不是 anti-multicultural — 是 architecture。\n\n你 12 个月后毕业 LinkedIn 上 connections 里 80% Chinese cohort。这是 selection bias 你没注意到 day 1 的代价。' },
      ],
    },
    {
      id: 'office_hour_door_freeze', minWeek: 4, maxWeek: 12,
      title: 'Whitmore 办公室门口 · 你站了 5 分钟',
      body: 'Office hour 周三 4-5 PM。你 4:32 走到 SOAS R401 门口——门半开——你听到 Whitmore 在跟另一个学生收尾。\n\n4:35 那学生出来朝你笑了一下走了。门半开。\n\n你站着——5 分钟没敲。\n\n你不是怕——是不知道：我应该敲门 announce / 还是直接走进去（半开门 = invitation?）/ 还是去 cafe 等下次？',
      choices: [
        { label: '敲两下 + "Sorry to disturb"', effect: { energy: 1, academic: 4, belonging: 4, npc: { whitmore: 1 }, flag: 'office_hour_used' },
          feedback: '你敲两下——Whitmore："Come in." 你进去："Sorry to disturb sir."\n\nWhitmore："Not disturbing — that\'s why office hours exist. What can I help with?"\n\n你问了 reading list 那个问题——他给了你 8 分钟答复 + 推荐了一篇 paper。\n\n你出门时心跳还在 95 但你 unlock 了一个 rite of passage。下次你不会再站门口 5 分钟。' },
        { label: '"算了" 离开 + 邮件问', effect: { energy: -3, academic: 1 },
          feedback: '你回 ensuite 给 Whitmore 写了一封 email——他次日回了——但是 brief paragraph 不像 office hour 8 分钟那种 deep。\n\n你那一刻 internalize：UK office hour 是 underused resource——大多数 international student 站门口 5 分钟然后走。你下次。下次你敲门。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // Reading list 焦虑 · library
  // ─────────────────────────────────────────────────────────────
  library: [
    {
      id: 'reading_list_essential_only', minWeek: 4, maxWeek: 10,
      title: 'Reading list · "essential" vs "recommended"',
      body: '你打开 module reading list — 14 本书 + 22 篇 article。\n\n你 highlight 了一遍——分两栏：\n· **Essential reading** (4 books + 8 articles)\n· **Recommended reading** (10 books + 14 articles)\n\n你 2 周下来——为了 conscientious — 把"Essential"和"Recommended"全读完了。\n\n你 tutorial 上 references 多——但你睡眠 6 小时 / 晚 + dissertation 第 1 章只写了 200 字。\n\nSarah lecture 下来跟你说："Wait you read all the recommended? Mate. Nobody does that. \'Recommended\' = optional. Tutors put them there for show."',
      choices: [
        { label: '调整 + 之后只读 essential', effect: { energy: 5, academic: 3, belonging: 4, flag: 'reading_list_calibrated' },
          feedback: '你 google "UK uni recommended reading actual expectation" — Reddit r/UniUK 几百帖确认: "essential = required, recommended = browse if interested"。\n\n你下学期只读 essential——saved 12 小时 / 周。Dissertation chapter 1 1 周写完。\n\n你这一刻 unlock 一个 cultural translation：UK academia 的 reading list 是 menu 不是 contract。国内 reading list 是 contract — 全读 — UK 不是。这种 over-conscientiousness 是 burnout 主因。' },
        { label: '"我宁愿严格 + 多读" 继续全读', effect: { energy: -10, academic: 3, belonging: -3 },
          feedback: '你坚持全读。第 8 周你病倒——freshers flu late onset + 睡眠不足。\n\n你最后 essay 拿了 78 (高于 cohort)。但你 dissertation 因为 chronic exhaustion 第 3 章 rewrite 3 次——final 拿 65。\n\n你这一刻 learn——over-perfection 在 UK academia ≠ excellence。学会 calibrate 是 30% IQ 70% sociology。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // 食物文化撞击 (f) · soho
  // ─────────────────────────────────────────────────────────────
  soho: [
    {
      id: 'first_chip_shop', minWeek: 4, maxWeek: 16,
      title: 'Fish & Chips 店 · "Salt and vinegar?"',
      body: '你第一次走进一家 fish & chips。Soho 一家叫 Golden Union 的小店。橱窗里炸 cod 油亮——一份 £12.5。\n\n你点 cod & chips。收银员（30 多岁印度小哥）："Salt and vinegar? Mushy peas? Tartare?"\n\n你愣了 1.5 秒。你只懂 salt。"Vinegar" 是醋——配薯条？"Mushy peas" 是 ... 烂豆？\n\n后面排了 3 个英国人。',
      choices: [
        { label: '"Yes everything please"（全要试一遍）', effect: { wallet: -14, energy: 4, belonging: 8, flag: 'first_chippy' },
          feedback: '他给你 + £1 加了 mushy peas + 浇了 malt vinegar + 放了 tartare。\n\n你坐窗边吃——malt vinegar 第一口你"靠这是工业味"——但 5 口后你上瘾了 — chip 沾 vinegar 比 ketchup 香 3 倍。\n\nMushy peas 是 nostalgia — 你想起妈给你做的豆泥。\n\n你这一刻 unlock 英国 working class food canon——chip shop 是英国 culinary 灵魂。你以后每月吃一次。' },
        { label: '"Just salt thanks"（保守）', effect: { wallet: -12, energy: 3 },
          feedback: '你光要盐——一盘炸薯条 + 炸鱼。吃起来正常但缺味。\n\n你下次再来——你看那个老英国大爷在浇 malt vinegar——你想"早知道"。\n\n这是英国食物 culture 你 missed 的——但下次你会试。' },
      ],
    },
    {
      id: 'wagamama_katsu_curry_letdown', minWeek: 6, maxWeek: 24,
      title: 'Wagamama · 你期待日料惊喜',
      body: '你听 CSSA 群里推 Wagamama "London 最 popular Asian chain"。你期待 ramen 神来——专门去 Soho 那家。\n\n你点 chicken katsu curry £14.50——你以为是 Tokyo 那种 panko 炸 cutlet + 浓 curry。\n\n端上来 — 一坨 mild 黄 curry + 半干 panko + 一些泡菜。第一口你愣 — 这不是日料 — 这是英式日餐 fusion。\n\n旁边一个英国情侣在说"Wagamama best ramen ever"。',
      choices: [
        { label: '"算了 我吃完 + 不再来"', effect: { wallet: -18, energy: 1, belonging: 1 },
          feedback: '你吃完 — 没第二次去 Wagamama。\n\n2 周后你找 Bonemu Ramen (real Japanese) — £18 一碗 — 完美。\n\n你这一刻 unlock：UK chain "Asian food" ≠ authentic — 是 British palate adaptation。如果你想 real Japanese / Chinese / Korean — 你必须 google "[area] authentic" + 看 Chinese / Japanese reviewer reviews。' },
        { label: '"反正英国人喜欢"（自我怀疑）', effect: { wallet: -18, energy: -3, belonging: -2 },
          feedback: '你想：是不是我口味问题。你又点了一份不同的——也一般。\n\n你 6 个月后才在 CSSA 群 vent："Wagamama 真不行"——10 个中国学生秒回"+1"。你这一刻 internalize：你的口味没问题——是 chain 的 audience 不是你。' },
      ],
    },
  ],
};
