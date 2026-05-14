// Flat-hunt arc — 5-event progression for finding next year's housing.
//
// W30-36 (April-May), the player needs to decide what to do post-ensuite.
// Real Chinese MSc students often do this for the first time IRL — finding
// a private flat in London is its own multi-week adventure of viewings,
// reference rejections, and guarantor-service workarounds.
//
// Flag chain:
//   rightmove_obsession      (W30-32)
//   first_viewing_chaos      (W31-33)
//   reference_silent_reject  (W32-34, after at least one viewing)
//   guarantor_service_paid   (W33-35)
//   moving_day               (W34-36, gated on private_flat flag from endGame.js)

export const FLAT_HUNT_EVENTS = {
  flat: [
    {
      id: 'rightmove_obsession', minWeek: 30, maxWeek: 34,
      title: '凌晨 2 点的 Rightmove',
      body: '凌晨 2 点。你已经刷 Rightmove 一个半小时。\n\n· Hackney 二居 £1,800/月（地铁 30 分钟到 uni）\n· Stratford 二居 £1,500（学生区，可能吵）\n· Bayswater studio £1,400（一个人，离 Mei\'s 近）\n· Camberwell 二居 £1,400（南伦敦，去 uni 1 小时）\n\nFiltering 选项：bills included? furnished? minimum 12 months? close to tube? 你已经 saved 31 个 listing。',
      choices: [
        { label: '锁定 5 套 周末看', effect: { energy: -5, stress: 6, flag: 'flat_shortlist' },
          feedback: '你给 5 个 agent 各发了同样的邮件："Could I view this Saturday?"\n\n2 个回了。1 个说"Sorry, already let"——但你看 Rightmove 还在 listing。这是英国房产的 standard mind-fuck。' },
        { label: '"再看一晚 不急"', effect: { energy: -3, stress: 4 },
          feedback: '你又刷 1 小时。最好的两套都被 "Let agreed" 标记了。\n\nLondon 私房市场是按小时刷新的——你睡了，机会就走了。' },
      ],
    },
    {
      id: 'first_viewing_chaos', minWeek: 31, maxWeek: 35,
      title: '看房 · 12 个人挤一套',
      condition: ({ flags }) => !!flags.flat_shortlist,
      body: '周六 11 点。Hackney 一套 £1,500/月二居。\n\n你提前 5 分钟到。门口已经站了 8 个人。等开始时——12 个人挤进 50 平米的房子。Agent 一边 30 秒一组流水线带看。\n\n你看到：墙上发霉、淋浴龙头掉下来、客厅挂了一张 "DO NOT TOUCH BOILER" 的便签。',
      choices: [
        { label: '当场 hold 这套（押金 £200）', effect: { wallet: -200, energy: -8, stress: 10, skipDays: 1, flag: 'held_first_flat' },
          feedback: 'Agent 说"先到先得 押金 £200 holding fee 不退"。你转账。\n\n两天后 reference check 你被拒（你妈不是 UK guarantor）。£200 holding fee 不退——agent 说"这是 standard"。\n\n这是英国租房第一课：£200 不算"押金"，是 agent 的 admission ticket 收费。' },
        { label: '观察一圈 不抢', effect: { wallet: -5, energy: -5, stress: 5, skipDays: 1 },
          feedback: '你绕了一圈记下问题：发霉、淋浴、boiler。回家给 agent 发邮件问能否修。\n\nAgent 24 小时后回："Already let, sorry."\n\n这就是 London 房市——你要么当场承诺要么没了。' },
      ],
    },
    {
      id: 'reference_silent_reject', minWeek: 32, maxWeek: 36,
      title: 'Reference Check 被拒',
      condition: ({ flags }) => !!flags.flat_shortlist,
      body: '你看上了一套 Stratford £1,500。Agent 让你做 reference check：\n\n1. 收入证明（你是 student，没有）\n2. UK-based guarantor（你妈在国内不算）\n3. 6 months UK address history（你只有 ensuite 9 个月）\n4. Credit score（你没 build credit history）\n\n3 天后 agent 邮件："Unfortunately the landlord has decided to go with another applicant."\n\n你查 Rightmove：listing 还在。',
      choices: [
        { label: '邮件追问 specific reasons', effect: { energy: -5, belonging: -2, stress: 8, flag: 'asked_landlord' },
          feedback: 'Agent 回："The landlord prefers tenants with established UK financial history."\n\n这是合法的拒绝理由——但巧合的是，几乎所有中国留学生都"缺乏 UK financial history"。\n\n这个 silent rejection 你这一年还要遇到 4 次。' },
        { label: '换下一套', effect: { energy: -3, stress: 5 },
          feedback: '你回 Rightmove 继续翻。但你心里那个"是不是因为我"的怀疑没消。\n\n3 套之后你才知道 UK guarantor service 这个东西的存在。' },
      ],
    },
    {
      id: 'guarantor_service', minWeek: 33, maxWeek: 36,
      title: 'UK Guarantor Service · £200 fee',
      condition: ({ flags }) => !!flags.flat_shortlist,
      body: 'CSSA 群里有人发："家人们 找不到担保人就用 Housing Hand / UK Guarantor，付 £200-300 fee 他们替你担保。"\n\n你 google：\n· Housing Hand: £295 一次性 fee + 8% of monthly rent\n· UK Guarantor: £200 + 8% rent\n· Some unis 提供 in-house service for free（你查一下）\n\n你的 uni 没有这种服务。',
      choices: [
        { label: '付 £295 给 Housing Hand', effect: { wallet: -295, energy: 3, flag: 'guarantor_paid' },
          feedback: '你提交了 application + 你妈的国内收入证明（中文 + 翻译）。3 天后通过。\n\n他们发给你一张 "Letter of Guarantee"——这就是你接下来 12 个月看房的 secret weapon。\n\n你想：£295 是 working class 留学生才付的——你之前不知道，但你现在是。' },
        { label: '继续找接受国内 guarantor 的房东', effect: { energy: -8 },
          feedback: '你看了 8 套之后找到一家小私房东（不通过 agent）愿意接受国内担保——但要 6 个月 rent upfront 当押金。\n\n£1,500 × 6 = £9,000 一次性。你妈秒转。\n\n这是另一种 working class 留学生方案——拿父母的现金代替系统的信任。' },
      ],
    },
    {
      id: 'moving_day', minWeek: 34, maxWeek: 36,
      title: '搬家日',
      condition: ({ flags }) => !!flags.private_flat,
      body: 'Saturday 9am。你的 ensuite 楼下停了一辆 Man with a Van（£60/小时）——一个 50 岁的波兰大叔 Janek。\n\n你 4 个箱子 + 2 个 IKEA 袋子 + 一床被子。你扛不动 mattress——uni 那个不能带走，你买了一张新的（£200，IKEA 送货）。\n\nTom（如果是 mark_friend / tom_friend）来帮你搬。他说"This is depressing, mate. You\'re actually leaving."',
      choices: [
        { label: '认真打包 + 跟 housemate 抱别', effect: { wallet: -260, energy: -15, belonging: 18, skipDays: 1 },
          feedback: 'Janek 帮你 90 分钟搬完。新公寓 Hackney——你和 ta 一起开门那一刻，两个人站在客厅都笑出来。\n\n"OK 这是我们的家了。"\n\n你回头看 ensuite 那栋楼最后一眼。Mark（如果是 mark_friend）从二楼窗户挥手——"Cheers mate! Stay in touch!"\n\n你挥回去。这一年的第一阶段，正式结束。' },
        { label: '一个人默默搬', effect: { wallet: -260, energy: -20, belonging: -3, stress: 6, skipDays: 1 },
          feedback: 'Janek 没说话。你们 90 分钟搬完。\n\n你站在新公寓客厅。空的。冷的。\n\n你从背包里掏出一桶白象方便面 + 你妈寄的老干妈。这就是开始。' },
      ],
    },
    // ───── 被 Gumtree deposit 骗子骗过的玩家专属回声 (lateScams 的 scammed_deposit) ─────
    // 跟 moving_day 同一时间窗，独立事件让叙事承接那 £400 的损失。
    {
      id: 'moving_day_scam_echo', minWeek: 34, maxWeek: 36,
      title: '搬家那天 · 想起 Gumtree 那 £400',
      condition: ({ flags }) => !!flags.private_flat && !!flags.scammed_deposit && !flags.scam_echo_moving_seen,
      body: 'Saturday 早上。Man with a Van 已经在楼下了。\n\n你站在新公寓门口——Hackney 二楼，朝南，£780/月 含 council tax。这一刻你想起 4 周前那个 Gumtree "Earl\'s Court £680" 骗局——£400 那时候那么真。\n\n你看着钥匙 1 秒。然后打开了门。',
      choices: [
        { label: '把这件事记进 diary · 不让自己忘', effect: { energy: 1, academic: 2, belonging: 6, flag: 'scam_echo_moving_seen' },
          feedback: '你 Notion 建了一条 "2024 W30 · Gumtree £400 lesson learned"。\n\n3 条 takeaway:\n· 没 in-person viewing 不打款\n· 反查 listing 图片用 Google Image\n· "急转 / 国外 / 不能 viewing" = 三连红旗\n\n你想：£400 是这一年最贵也最便宜的一课。' },
        { label: '"算了 都过去了"——直接搬', effect: { energy: 1, belonging: 2, flag: 'scam_echo_moving_seen' },
          feedback: '你没纠结。直接开门搬东西。\n\nJanek 一边搬一边和你讲他 30 年前来伦敦也踩过一次 housing 骗子——£200，1994 年。"Mate, every immigrant in this city loses something to this city first. You\'re paid up now."\n\n你听完没说话。继续搬箱子。' },
      ],
    },
  ],
};
