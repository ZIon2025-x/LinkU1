// NPC 中间织物 · 轻互动事件。
//
// 主线 storylines.js 每 NPC 只有 3-5 章 milestone，平均 11 周 1 章 — 太稀。
// 这些事件填充章节之间的"日常 ping"，不推进剧情、不解锁新 flag，只让玩家
// 觉得这个朋友每周都在他生活里。
//
// 设计原则:
//   1. 一段对话 / 一个递茶动作 / 一句吐槽——不是 deep moment。
//   2. 不要 hard choice — 大多 1-2 选项，避免"中间织物"变成又一个 milestone。
//   3. 部分允许 repeatable (e.g. Sarah 在厨房八卦男朋友) — 真实友谊就是
//      同样的吐槽听 5 遍。
//   4. rel gating 决定什么时候出现什么 ping：rel 1-3 是客气、rel 4-6 是
//      朋友、rel 7+ 是 deep。

export const NPC_LIGHT_INTERACTIONS = {
  // ─────────────────────────────────────────────────────────────
  // flat · Sarah 室友互动 + 林楠（恋爱期）夜间访问
  // ─────────────────────────────────────────────────────────────
  flat: [
    {
      id: 'sarah_kitchen_complaint', minWeek: 4, maxWeek: 50, repeatable: true,
      title: 'Sarah · 厨房吐槽',
      condition: ({ npcRel }) => (npcRel.sarah || 0) >= 2,
      body: '你下楼煮泡面。Sarah 已经在那里——一边洗碗一边自言自语："James didn\'t reply to my text for SIX HOURS. Six. I sent him a meme. A funny one."\n\n她抬头看你："Oh hey. Sorry. Boy drama. Want to weigh in?"',
      choices: [
        { label: '"Six hours? Honestly that\'s nothing. Don\'t spiral."', effect: { energy: 1, belonging: 4, npc: { sarah: 1 } },
          feedback: 'Sarah 笑："Cheers. Voice of reason." 她端着洗好的杯子回房间。\n\n你想：朋友最重要的不是给 deep advice，是给 5 秒 sanity check。' },
        { label: '"What did the meme say"', effect: { energy: 2, belonging: 6 },
          feedback: '她给你看——是一只猫举牌写"YOU UP?"。你笑出声："That\'s why he hasn\'t replied. He\'s recovering from how unfunny it is."\n\n她假装愤怒："EXCUSE ME"——然后开始笑。\n\n你这一晚没真的解决她什么，但你 2 个人在共用厨房笑了 10 分钟。' },
      ],
    },
    {
      id: 'sarah_shortbread_box', minWeek: 16, maxWeek: 50,
      title: 'Sarah · 一盒她妈寄来的 shortbread',
      condition: ({ npcRel }) => (npcRel.sarah || 0) >= 4,
      body: 'Sarah 敲你 ensuite 门。手里拿着一个铁盒。\n\n"Mum sent these. Cotswolds shortbread. There\'s like 40 in here. I literally cannot eat them all. Help."\n\n她递盒子给你。',
      choices: [
        { label: '"Tell your mum thanks. These are amazing."', effect: { energy: 5, belonging: 8, npc: { sarah: 1 }, wallet: -2 },
          feedback: '你尝了一块——奶油 + 海盐 + 实在的好黄油。第二天你给 Sarah 一封手写卡："For your mum, when she next writes." Sarah 把它收进她钱包。\n\n3 周后 Sarah 妈妈给你写来一张回卡——上面只有一句话："Glad my biscuits made it across the world."' },
      ],
    },
    {
      id: 'sarah_pancake_morning', minWeek: 20, maxWeek: 50, repeatable: true,
      title: 'Sarah · "I made too many pancakes again"',
      condition: ({ npcRel }) => (npcRel.sarah || 0) >= 3,
      body: '周日早上 10 点。你睡眼惺忪走到厨房——Sarah 在炉前。台子上摆了 9 张 pancake。\n\n"I miscalculated. As usual. Want some?"',
      choices: [
        { label: '"Always."', effect: { energy: 6, belonging: 5, wallet: 0 },
          feedback: '你们 2 个站在厨房分掉了 9 张 pancake。她聊她在 Cotswolds 妈妈做的版本（"actually worse, mum overcooks them"）。\n\n你们没坐下，就站着吃。这种 unceremonious belonging 在伦敦留学一年最难得。' },
      ],
    },
    {
      id: 'sarah_help_chinese_song', minWeek: 24, maxWeek: 50,
      title: 'Sarah · "Translate this song for me?"',
      condition: ({ npcRel }) => (npcRel.sarah || 0) >= 6,
      body: 'Sarah 在沙发上翻 TikTok。"Wait. This song. I\'ve heard it 20 times this week. What does it MEAN?"\n\n她给你看屏幕——你认出来了，是周深《大鱼》。',
      choices: [
        { label: '逐句给她翻 + 解释意境', effect: { energy: -3, belonging: 12, npc: { sarah: 2 } },
          feedback: '你 30 分钟逐句给她翻 + 讲电影《大鱼海棠》的 setup。Sarah 听完安静了 5 秒——然后说"That\'s much sadder than I thought it was."\n\n她加进 Spotify playlist。1 周后她在 IG story 用了这首歌做背景音。\n\n你那一刻想——你给一个英国人讲中文歌的诗意，她真的听进去了。这是 cultural exchange 不是 lecture。' },
      ],
    },
    {
      id: 'linnan_dating_tiramisu', minWeek: 22, maxWeek: 50, repeatable: true,
      title: '林可儿 / 林楠 · 给你做了个 tiramisu',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 9,
      body: 'ta 端着一个塑料盒进你 ensuite。\n\n"我做的 tiramisu。第一次。可能很烂。你要不要试。"\n\n你打开——上面 cocoa 撒得不均，但奶油看起来是真的奶油。',
      choices: [
        { label: '认真吃 + 真心评', effect: { energy: 5, belonging: 12, npc: { linnan: 2 } },
          feedback: '你尝了一口——咖啡 layer 偏苦但奶油 perfect。"咖啡多 layer 之后 reduce 一半。" ta 严肃："好。" 然后 ta 自己尝一口："靠 真的太苦了。"\n\n你们 2 个站在 ensuite 笑了 5 分钟——一个失败的 tiramisu 从此变成你们 2 人之间的 inside joke。' },
      ],
    },
    // ─── 林楠 dating texture ───
    {
      id: 'linnan_tomato_egg', minWeek: 18, maxWeek: 50, repeatable: true,
      title: '林可儿 / 林楠 · 共用厨房做番茄炒蛋',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 6,
      body: '周日下午。共用厨房只有你们俩。林可儿 / 林楠站在炉前打鸡蛋。"我妈说番茄炒蛋先炒蛋还是先炒番茄是检验留学生有没有妈妈电话的标准。"\n\n你拿起锅铲："给我吧 我妈逼我学过。"',
      choices: [
        { label: '抢过锅铲 + 边做边讲妈妈版本', effect: { energy: 4, belonging: 10, wallet: -3, npc: { linnan: 1 } },
          feedback: '你做完一盘——加了一点点糖（北京做法）。林可儿 / 林楠尝一口眼睛弯了："你妈是北京的吧。我妈苏州的不放糖。"\n\n你们坐在共用桌子上吃这一盘番茄炒蛋——没拍照、没发朋友圈、没说"今天 vibe 真好"那种话。\n\n但你们都知道——这一刻 ensuite 这间合租宿舍突然像一个家了。' },
      ],
    },
    {
      id: 'linnan_mom_video_caught', minWeek: 22, maxWeek: 50,
      title: '你妈视频电话来 · ta 还在你 ensuite',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 7,
      body: '周二下午 6 点。你和林可儿 / 林楠刚在床上躺着看一部电影。\n\n你妈视频电话弹出来——你已经接起一半才反应过来。妈在屏幕里："吃饭了..."\n\n她看到背景里的人。停顿 1.5 秒。"啊 ... 你 ... 同学？"',
      choices: [
        { label: '"妈这是我 partner"（直接 out）', effect: { energy: -3, belonging: 8, npc: { linnan: 3 }, flag: 'linnan_mom_knows' },
          feedback: '你妈愣了 3 秒。然后她说"哎呀 你 ... 你 hi 啊。" 林可儿 / 林楠对镜头比了个手"Auntie 好"。\n\n你妈："好好。妈先挂了。" 立刻挂了。\n\n3 秒后她微信发你一句："傻孩子先告诉妈一声啊 妈头发都没梳。"\n\n林可儿 / 林楠笑了 5 分钟："你这种 dive-in 我服。我妈我还没敢。"\n\n你回："早晚要 out 的。先 out 我妈是因为我妈最容易接住。"' },
        { label: '"妈是我同学 我们一起赶 essay"（藏）', effect: { energy: -3, belonging: -3, npc: { linnan: -2 } },
          feedback: '你妈嗯了一声："那妈不打扰。" 立刻挂了。\n\n林可儿 / 林楠没说话。等了 30 秒。然后："你跟你妈藏到什么时候。"\n\n你说"等我毕业"。ta 笑了一下没说话——但那个笑你看出 ta 心里有根刺。\n\n你这一刻欠 ta 一个对话——你不知道什么时候还。' },
      ],
    },
    {
      id: 'linnan_xiang_gua_bing', minWeek: 26, maxWeek: 50,
      title: '林可儿 / 林楠 · 给你做手抓饼',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 8,
      body: '周六早上 9 点。ta 已经在共用厨房——面粉、葱花、Tesco 火腿肠。\n\n"我妈给我教过。但你比我会做番茄炒蛋——所以我今天必须 contribute。"\n\nta 把第一张抓饼翻面——金黄色，整个厨房都香了。',
      choices: [
        { label: '坐在台子边等 + 拍 5 张照', effect: { energy: 6, belonging: 12, npc: { linnan: 1 } },
          feedback: '你拍了 5 张照——ta 翻饼的手 / 葱花特写 / 第一张完成的 / 你们俩对碰餐盘 / 厨房窗户外的伦敦树。\n\n你发了一条朋友圈，配文"伦敦周六"。15 个赞。其中 1 个是你妈——她评论"哎呀这个手抓饼像我做的"。林可儿 / 林楠在你旁边看到笑了："你妈给我点了赞。"\n\n你想：你这一刻拥有的——你 22 年人生里第一次。' },
      ],
    },
    {
      id: 'linnan_ikea_pot', minWeek: 26, maxWeek: 50,
      title: 'IKEA Wembley · 你们买了一口锅',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 8,
      body: '周日。Wembley IKEA 你们俩坐 25 分钟地铁过去——只为了一口 £25 的炒锅（学校 ensuite 那口是 1995 年的 nonstick 已经掉皮）。\n\n回程 tube 上 ta 抱着锅。你抱着 IKEA 食堂买的 1L 软冰淇淋。',
      choices: [
        { label: '在 tube 上分一口冰淇淋', effect: { energy: 4, belonging: 10, wallet: -30 },
          feedback: '你递 ta 一勺。ta 吃了一口。\n\n旁边一个英国奶奶看着你们笑了："Young love, eh?"\n\n你跟林可儿 / 林楠都红脸——但也没否认。\n\n回 ensuite 那口锅放在共用厨房——你们用了 30 周。最后一次用是 ta 走之前给你做的最后一道辣椒炒肉。' },
      ],
    },
    {
      id: 'linnan_mom_screenshot', minWeek: 30, maxWeek: 50,
      title: '林可儿 / 林楠 · 给你看 ta 妈相亲群截图',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 7,
      body: '深夜 11 点。ta 把手机递给你看——一个微信群"杭州相亲交流"。35 个家长。\n\n"我妈昨天发的：\'我女儿 / 儿子 在英国读 MSc 1996 出生 175 想找一个上海或杭州本地的。\' 她不知道我看得到这个群。"',
      choices: [
        { label: '"那我们 1996 年的也算 candidate"（开玩笑 deflect）', effect: { energy: 3, belonging: 8, npc: { linnan: 1 } },
          feedback: 'ta 笑出声："靠 你这个对策。" 然后认真："但你不是 candidate 啊。你已经是了。"\n\n你愣了 5 秒。然后说"嗯"。\n\nta 把手机收起来："等我毕业回去 我跟我妈说。" 你点头——你们俩这一刻没承诺什么大，但 1 个微信群截图把以后 5 年的方向悄悄对齐了 1°。' },
        { label: '"那你回去他们逼你 你怎么办"', effect: { energy: -3, belonging: 4 },
          feedback: 'ta 沉默 5 秒："我也不知道。但我至少 buy 1 年——PSW 期间我可以 say I\'m establishing career here。"\n\n你想——这是你来英国第一次跟一个人讨论 5 年后的事 不是 5 周后。\n\n这种焦虑也是 belonging。' },
      ],
    },
    {
      id: 'linnan_ex_sighting', minWeek: 28, maxWeek: 48,
      title: '咖啡厅 · ta 的 ex 走进来',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 7,
      body: 'Bloomsbury 一家小咖啡厅。你们坐 corner 桌。\n\n林可儿 / 林楠突然身体僵了一下。压低声音："那个 短发的 进来的女生 / 男生——是我前 partner。"\n\nta 已经低头盯着杯子。',
      choices: [
        { label: '"要换桌吗 还是 just 装作没事"', effect: { energy: 1, belonging: 6, npc: { linnan: 1 } },
          feedback: 'ta 想了 3 秒："just 装作没事吧。我不躲。"\n\n那个人点完单转身——目光扫过你们这桌——停了 0.3 秒——然后离开。\n\n林可儿 / 林楠呼了一口气："Ok. 那 closure 就是这样。"\n\n你伸手握了 ta 一下手指。ta 没说话——但 ta 5 秒后回握。' },
        { label: '"我去打个招呼"（傻乎乎 试图友好）', effect: { energy: -3, belonging: -5, npc: { linnan: -2 } },
          feedback: 'ta 立刻："不要不要不要。" 但你已经站起来了。\n\n你去那个 ex 那桌说了 "Hi I\'m [林楠 partner]" 5 秒——对方一脸 confused 然后冷淡："Oh. OK."\n\n你回桌。林可儿 / 林楠看你 10 秒："你这种 alpha-male 戏码 求你别再演。"\n\n你们这天 vibe 没了。回去路上 ta 没怎么说话。' },
      ],
    },
    // ─── 林楠 mini argument arc · 2 events chained ───
    {
      id: 'linnan_argument_dissertation_phase', minWeek: 40, maxWeek: 49,
      title: '"你最近怎么这么忙"',
      condition: ({ flags, npcRel }) =>
        !!flags.linnan_dating && (npcRel.linnan || 0) >= 7 && !flags.linnan_argument_resolved,
      body: '周三晚 11 点。你们俩在你 ensuite——你坐桌前敲 dissertation，ta 坐床上 1 小时没说话。\n\n突然 ta："你这周第 4 次说\'今晚我要写到 2 点\'。我们上次约会是 11 天前。"\n\nta 不是吵——是 stating a fact。但这 fact 像针。',
      choices: [
        { label: '道歉 + 协商一个 weekly date 时间', effect: { energy: -3, belonging: 8, npc: { linnan: 2 }, flag: 'linnan_argument_resolved' },
          feedback: '你停下打字转过去："对不起。我知道。这个月我状态太烂。我们周日下午 4 点 默认就是 we time 你 lock 在我日历上 我不能 reschedule。"\n\nta 看你 5 秒。然后说"好。"\n\n你们没拥抱、没流泪——但你这一刻知道——成熟的关系不是没冲突，是冲突 5 分钟内能落地一个 protocol。' },
        { label: '"我 deadline 4 周后你不能体谅一下吗"（炸毛）', effect: { energy: -8, belonging: -10, npc: { linnan: -5 }, flag: 'linnan_cold_war' },
          feedback: 'ta 沉默 5 秒。然后站起来："好。我这就给你 deadline 体谅一下。"\n\nta 收背包走了。门关上的声音不大但你听了 30 分钟。\n\n你回去敲 dissertation 写不进去——你看着那个空着的床那一面 想：靠 我刚才在为我 1500 字 essay 摧毁 11 个月的信任。' },
        { label: '沉默继续打字', effect: { energy: -3, belonging: -8, npc: { linnan: -3 }, flag: 'linnan_cold_war' },
          feedback: 'ta 等了你 30 秒——你没回头。\n\nta 抱起包走了。没说"晚安"。\n\n你这一刻知道——沉默有时候比炸毛更伤人。' },
      ],
    },
    {
      id: 'linnan_cold_war_makeup', minWeek: 41, maxWeek: 50,
      title: 'ta 端着 Pret 出现在门口',
      condition: ({ flags }) => !!flags.linnan_cold_war && !flags.linnan_argument_resolved,
      body: '冷战 48 小时。你 ensuite 没人来，你也没主动 reach out。\n\n周五晚 9 点。门被敲。\n\nta 站在门口——头发湿的（外面在下雨）——左手 Pret 袋，右手 2 杯 oat latte。\n\n"我们都成年人了 我先来。但你这次欠我一个对话。"',
      choices: [
        { label: '让 ta 进来 + 真说出对不起', effect: { energy: 5, belonging: 18, npc: { linnan: 4 }, flag: 'linnan_argument_resolved' },
          feedback: '你让 ta 进。把 Pret 接过来。\n\n你坐 ta 对面说："我那天炸毛 / 沉默——是因为我那一刻把我焦虑 displace 到你身上。但你那个 fact 是对的。我们最近少。我不应该让你来 chase 我。这次我先 set 周日 4 点。"\n\nta 听完点头："好。但你下次不要让我等 48 小时。我等不起。"\n\n你说"嗯。" 然后你们 2 个吃 Pret meal deal——这是你们俩在 dissertation 期间最好的一顿饭。' },
        { label: '"我 dissertation 没写完 我们改天"', effect: { energy: 0, belonging: -15, npc: { linnan: -8 }, flag: 'linnan_breakup' },
          feedback: 'ta 看你 10 秒——眼眶红的。"好。"\n\nta 把 Pret 袋放门口。转身走。\n\n你 1 周后给 ta 发 message——unread。3 周后 ta 朋友圈 stop showing 给你看。\n\n你不知道你那一刻为什么选了 dissertation 而不是这扇门。也许你以后会知道。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // mei · Mei 姐温情线
  // ─────────────────────────────────────────────────────────────
  mei: [
    {
      id: 'mei_asks_hometown', minWeek: 2, maxWeek: 6,
      title: 'Mei 姐 · "你哪儿口音"',
      condition: ({ npcRel, flags }) => (npcRel.mei || 0) >= 1 && !flags.mei_hometown_asked,
      body: '你第二次或第三次来 Mei\'s。她端来一碗你点的牛肉面——但她没立刻走。\n\n她在你对面坐下,擦着柜台:"你哪儿口音?听着不是北京的。"',
      choices: [
        { label: '老实说家乡',
          effect: { rel: 2, energy: 2, belonging: 8, flag: 'mei_hometown_asked' },
          feedback: '你说了你家乡——杭州 / 长沙 / 沈阳 / 成都……\n\nMei 姐眼睛亮了:"哎呀!我有个堂弟当年也在那边读书。" 她跟你扯了 5 分钟那条线——她堂弟、堂弟的同学、她小时候的事。\n\n你听完已经吃完了面。她结账时多给你装了一盒泡菜:"你那边人爱吃这个吧?"\n\n这是 Mei 姐第一次把你当"自己人"。' },
        { label: '"南方的 您应该没听过"',
          effect: { rel: 1, belonging: 3 },
          feedback: 'Mei 姐笑了:"南方哪都听过。我以前 1995-2000 在曼城那条 China Town 干过 5 年——南北的孩子都见过。"\n\n你这才想起来:她在英国 30 年了。\n\n她没追问。但你出门时她说:"下次想吃啥提前跟姐说一声。"' },
        { label: '"不重要 您随便"',
          effect: { rel: 0, belonging: -1 },
          feedback: 'Mei 姐 nod 一下回厨房。\n\n你结账时她没说话。你出门时她也没说"下次来"。\n\n你这一刻没意识到——你刚错过一次 Mei 把你当"自己人"的窗口。下次再触发要等。' },
      ],
    },
    {
      id: 'mei_extra_scoop', minWeek: 3, maxWeek: 50, repeatable: true,
      title: 'Mei 姐 · 多打一勺',
      condition: ({ npcRel }) => (npcRel.mei || 0) >= 2,
      body: '你来吃饭。Mei 姐看你一眼——没说话，给你的 takeaway 盒子里多打了一勺红烧肉。',
      choices: [
        { label: '"姐 谢谢"', effect: { energy: 4, belonging: 6, wallet: -8 },
          feedback: 'Mei 姐："吃肉。" 她转身回厨房。\n\n你结账时她按住你 2 块钱。"今天的不要这两块。"\n\n你回 ensuite 吃饭——你想：原来妈妈不在身边的时候，多一勺肉是 belonging 最朴素的形式。' },
      ],
    },
    {
      id: 'mei_takeaway_delivery', minWeek: 8, maxWeek: 50,
      title: 'Mei 姐 · "帮我送一份"',
      condition: ({ npcRel }) => (npcRel.mei || 0) >= 3,
      body: 'Mei 姐打你电话："你在哪？" 你说在图书馆。"图书馆 4 楼有个老顾客 PhD 学生 张博士 我给他打包了一份 你下楼路过给他递一下 我多给你一份。"',
      choices: [
        { label: '"行 姐 我去找他"', effect: { energy: -2, belonging: 5, wallet: 0, npc: { mei: 1 } },
          feedback: '你下楼到 4 楼。张博士 30 多岁，戴眼镜，正在写论文——他抬头看到你拿着 Mei\'s 的袋子，笑了："Mei 姐又叫你跑腿了？"\n\n你笑："互助。"\n\n他递你一袋瓜子："你帮我谢 Mei 姐。" 你回去 Mei\'s——她把那袋瓜子推给你："你自己拿着 学生熬夜需要。"\n\n你这一刻 belong 到伦敦中餐馆这个小生态——一个 Mei 姐 + 一个写论文的博士 + 你。' },
      ],
    },
    {
      id: 'mei_asks_exam', minWeek: 30, maxWeek: 40,
      title: 'Mei 姐 · "考完试了吗"',
      condition: ({ npcRel }) => (npcRel.mei || 0) >= 4,
      body: '你来吃晚饭。Mei 姐坐你对面——这次她端了一杯桂花茶给你。\n\n"考完试了吗。最近脸色不好。"',
      choices: [
        { label: '"考完了 还有论文"', effect: { energy: 3, belonging: 8, npc: { mei: 1 } },
          feedback: 'Mei 姐："论文好好写。写完来吃饭 姐做你爱吃的。"\n\n她抬手给你点了一份"留学生餐"（半份饭 + 一道菜 + 例汤）—— 她从你来 9 个月发现你这个胃口。\n\n你吃饭的时候她坐你旁边没说话。但她坐着——她知道你需要这种 quiet company。' },
      ],
    },
    {
      id: 'mei_mom_called', minWeek: 35, maxWeek: 50,
      title: 'Mei 姐 · "你妈又给我打电话了"',
      condition: ({ npcRel }) => (npcRel.mei || 0) >= 6,
      body: '打烊后 Mei 姐让你坐下——她从围裙拿出手机给你看 call log："你妈昨晚 11 点（伦敦时间 4 点）给我打了电话。问你吃饭怎么样。"',
      choices: [
        { label: '"啊 我妈又麻烦你了 不好意思"', effect: { energy: -3, belonging: 18, npc: { mei: 2 } },
          feedback: 'Mei 姐："不麻烦。我跟她说你瘦了一点 但精神好。"\n\n你愣了——你妈从来没告诉你她联系 Mei 姐。\n\nMei 姐："你妈跟我加了微信。她跟我说\'我女儿 / 儿子在伦敦你帮我多看一眼\'。我就 你妈也是。"\n\n你回 ensuite 路上给妈打电话："妈你给 Mei 姐打电话呢？" 她："谁说的。"\n\n你笑了。原来 mothers 互相 cover 你 — 这是你来伦敦才看到的女性世代地下网。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // soho · 王凯创业线
  // ─────────────────────────────────────────────────────────────
  soho: [
    {
      id: 'wangkai_voucher_brief', minWeek: 6, maxWeek: 50, repeatable: true,
      title: '王凯 · "兄弟 帮我个忙"',
      condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 2,
      body: '王凯发你微信："哥们 周六去 Westfield 帮我代购 2 个 Pandora 手链 我表妹要的 给你 £30。"',
      choices: [
        { label: '"行 哥 周六见"', effect: { wallet: 30, energy: -3, belonging: 3, npc: { wangkai: 1 } },
          feedback: '你周六去 Westfield 排队 30 分钟买了 2 个 Pandora。回去他给你转 £30 + 1 杯免费奶茶。\n\n王凯："哥们 你这种 reliable 的我以后都找你。" 你笑：跑腿费这种东西在伦敦能算半个收入来源——这一年你 grateful 王凯把你拉进了这个 micro-economy。' },
        { label: '"我学业紧 改天"', effect: { energy: 1, belonging: 0 },
          feedback: '王凯："理解 学业要紧。" 他没追问。\n\n但你也知道——他下次会先找别人。这种平台的 reliability 是攒出来的。' },
      ],
    },
    {
      id: 'wangkai_soho_milk_tea', minWeek: 12, maxWeek: 50,
      title: '王凯 · 一杯免费奶茶',
      condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 3,
      body: '你 walk 进 Soho 那家奶茶店——王凯在后厨。看到你他出来："哥们 试试新口味——海盐芝士乌龙。我自己开发的。免费。"\n\n他递给你一杯没拍照过的杯子。',
      choices: [
        { label: '认真品 + 给反馈', effect: { energy: 2, belonging: 6, wallet: 0, npc: { wangkai: 1 } },
          feedback: '你尝了 3 口。"芝士太重了 茶味盖不住。" 王凯："靠 你跟我表姐一个意见。" 他转身回后厨改配方。\n\n2 周后这个口味上架——"海盐乌龙·轻芝士版"——他在小红书 caption 标了"一个朋友的真心反馈"。\n\n你想：你这一杯免费奶茶值 4,500 元——他刷到你 IG 一定会 ping 你的程度。' },
      ],
    },
    {
      id: 'wangkai_customer_rant', minWeek: 18, maxWeek: 50, repeatable: true,
      title: '王凯 · 吐槽客户',
      condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 4,
      body: '王凯坐你对面：奶茶店里他自己的桌。"哥们 今天有个客户 一杯奶茶买 5 次差评 还退款 4 次。这种我能 ban 吗？"',
      choices: [
        { label: '"能 你是老板 别让她毁你 review"', effect: { energy: 1, belonging: 4 },
          feedback: '王凯："对。我等下 ban。" 他立刻打开 Deliveroo backend。"哥们 你这种 cold 我服了。" \n\n你笑："Deliveroo customer 不是 Mei 姐——你不需要 nice."' },
        { label: '"再给一次机会 写 polite reply"', effect: { energy: 2, belonging: 4 },
          feedback: '王凯："你太软了 哥们。" 但他还是 polite reply 了——客户那次没再差评。\n\n你说："see? 你的奶茶店现在是 4.6 不是 4.5."' },
      ],
    },
    {
      id: 'wangkai_intro_referral', minWeek: 38, maxWeek: 50,
      title: '王凯 · "我表哥那边在招"',
      condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 5,
      body: '王凯发你："哥们 我表哥在国内一家咨询公司做合伙人。他们在 London 设新 branch 找留学生。我跟他提了你。你愿意聊一下吗？"',
      choices: [
        { label: '"愿意 谢哥"', effect: { energy: -3, academic: 5, belonging: 8, npc: { wangkai: 2 }, flag: 'wangkai_referral' },
          feedback: '你跟他表哥 zoom 30 分钟。对方说："王凯说你 reliable。这一句对我来说比 LinkedIn 简历重。下个月有个 part-time analyst 的位置 月 £1,200 你要吗？"\n\n你接了。这是你来英国第一次 referral——不是 LinkedIn cold apply 进来的——是因为你帮一个朋友扛了 4 次 Bicester 包。' },
        { label: '"我学业忙 谢哥"', effect: { belonging: 0 },
          feedback: '王凯："理解。" 他没再 push。\n\n你想：refer 的窗口很短——你这次没接，下次他不会再 offer 了。' },
      ],
    },
    // ─── 王凯 Soho 创业日常 (奶茶店 business 期间) ───
    {
      id: 'wangkai_1000_label', minWeek: 18, maxWeek: 40,
      title: '王凯 · "今晚帮我贴第 1000 张标签"',
      condition: ({ flags, npcRel }) => !!flags.wangkai_business && (npcRel.wangkai || 0) >= 5,
      body: '凌晨 12 点。王凯朋友圈："今晚冲量到 1000 单。差最后 80。" 半小时后他微信你："哥们 在哪？店里贴标签真贴不动了 你来一下我请你 3 杯。"',
      choices: [
        { label: '骑共享单车过去 + 贴 80 张', effect: { energy: -10, wallet: 0, belonging: 12, npc: { wangkai: 2 }, flag: 'wangkai_1000_helped' },
          feedback: '你凌晨 1 点到。他和那个广州女生（他兼职店员）已经累到趴台子。\n\n你贴标签——80 张走完时是凌晨 2:47。王凯坐你旁边："1000 单。3 个月。"\n\n他没说"谢谢"——他递给你一杯没卖完的 hot chocolate。"明天店里给你留一个 free drink 的 entry 在 POS。"\n\n你回 ensuite 路上——伦敦凌晨 3 点的街——你想：原来"创业"不是 vibes，是 80 张标签的肌肉记忆。' },
        { label: '"哥我 dissertation 明早 supervision"', effect: { belonging: -3 },
          feedback: '他："理解 我自己贴。" 然后没再发。\n\n3 周后你去店里他跟你 vibe 还在但少了一层——你拒绝过一个 dawn-hour SOS。这种 micro-debt 在朋友圈里是会记账的。' },
      ],
    },
    {
      id: 'wangkai_burnt_pearls', minWeek: 20, maxWeek: 40, repeatable: true,
      title: '王凯 · 凌晨 2 点煮坏了一锅珍珠',
      condition: ({ flags, npcRel }) => !!flags.wangkai_business && (npcRel.wangkai || 0) >= 4,
      body: '王凯微信："靠 一锅珍珠煮糊了 整店都是焦味。今晚还有 40 单要发。" 一个流泪表情。\n\n你打开 Google Maps——他店里走路 8 分钟。',
      choices: [
        { label: '过去帮收拾 + 一起煮新一锅', effect: { energy: -8, belonging: 8, wallet: 0, npc: { wangkai: 2 } },
          feedback: '你到的时候厨房通风扇全开，王凯端着一锅黑色珍珠走出来扔进 commercial 垃圾桶。\n\n你帮他煮新一锅——50 分钟才煮好。期间他给你讲了他爹去年开始问"你这么大了什么时候回国结婚"的事。\n\n3 点订单全部发完。他坐你对面："哥们 一个真正的朋友是什么——是凌晨 2 点你打他他来 8 分钟。今天你来了。" 他给你转 £30 红包。你拒。他："拿着。这不是费用——这是\'你来了\'的证。"' },
        { label: '"哥我帮不上 你看我能做啥远程的"', effect: { belonging: 1 },
          feedback: '你给他发了 3 个煮珍珠的 YouTube 链接。\n\n他："谢哥 我自己来。" 他自己煮到 3 点。\n\n第二天你刷朋友圈看到他发"昨晚一个人撑下来 没事 老子再战" + 3 张厨房照片。你点了赞。\n\n但你也知道——你那一刻其实是不想出门。' },
      ],
    },
    {
      id: 'wangkai_first_staff_meeting', minWeek: 24, maxWeek: 38,
      title: '王凯 · 第一次开员工会议',
      condition: ({ flags, npcRel }) => !!flags.wangkai_business && (npcRel.wangkai || 0) >= 5,
      body: '周日下午店里。王凯邀请你 sit in——他要给他 4 个 part-time 员工开第一次正式员工会议。\n\n他穿了一件衬衫（你 1 年来第一次见他穿衬衫不是 hoodie）。手抖得拿 PPT 的 remote 都按错。',
      choices: [
        { label: '坐角落安静观察 + 完事给他 feedback', effect: { energy: -3, academic: 3, belonging: 6, npc: { wangkai: 2 } },
          feedback: '他讲了 25 分钟——SOP / KPI / 上班守时 / 顾客投诉处理流程。讲到一半 1 个员工玩手机——他没敢说。讲完没有 Q&A 节奏散乱。\n\n散会你拉他到角落："哥 PPT 那 3 处你慢下来 + 中间停 5 秒看大家。员工玩手机你直接 \'put your phones down please\' 别 silent。下次试。"\n\n他点头很认真："我没开过会。我妈是工厂工人 我爸是 driver。我爹娘没见过会议。"\n\n你那一刻知道——他给你的 £80 Bicester 跑腿费 ROI 不止——他在让你旁观一个一代移民的"第一次"。' },
        { label: '没去（说有事）', effect: { belonging: 0 },
          feedback: '你后来听说会议开得一团糟——一个员工那周辞职。\n\n你想——如果你坐角落 5 分钟你能 fix 那个细节。但你没去。' },
      ],
    },
    {
      id: 'wangkai_supplier_burned', minWeek: 26, maxWeek: 40,
      title: '王凯 · "广州供应商坑了我 £2000"',
      condition: ({ flags, npcRel }) => !!flags.wangkai_business && (npcRel.wangkai || 0) >= 5,
      body: '王凯发来 voice msg 5 分钟——大致内容：他广州的茶叶供应商上批货掺了陈茶，整批 £2,000 货。他打过去对方拉黑他微信。\n\n"哥们 我现在去广州一趟去那个仓库当面问。机票 £680。值不值。"',
      choices: [
        { label: '"值 但你不能一个人 去 + 录像"', effect: { energy: -3, belonging: 8, npc: { wangkai: 2 }, flag: 'wangkai_supplier_advice' },
          feedback: '你给他列了 5 条："录像 / 录音 / 不要在仓库里 escalate 找他公司注册地 / 和当地工商部门提前通气 / 准备好 chargeback bank evidence"。\n\n他："靠 你这个比我律师还细。" 他飞了。3 天后他从广州回："£1,800 拿回来。剩 £200 当 lesson。"\n\n他给你转 £100："这是 consulting fee。你别拒——你这种 reliable 的我以后都付。" 你 accept 了——这是你来英国第一次有人付你脑子 不是付你跑腿。' },
        { label: '"哥太冒险了 你 dispute 银行就好"', effect: { belonging: 1 },
          feedback: '王凯："dispute 拿不回来——transferwise 只能拿回 £400。算了。" 他没去广州 自己吃了 £1,600 损失。\n\n3 个月后他换了供应商。但他这次没找你 consult——他默认你不愿意 wade in 这种 messy 的事。' },
      ],
    },
    {
      id: 'wangkai_landlord_yells', minWeek: 22, maxWeek: 36,
      title: '王凯 · 英国房东打电话骂"油烟太重"',
      condition: ({ flags, npcRel }) => !!flags.wangkai_business && (npcRel.wangkai || 0) >= 4,
      body: '你在店里。王凯接到一个电话——你听到对面喊："YOUR EXTRACTOR FAN IS FAULTY YOU\'RE STINKING UP MY ENTIRE BUILDING."\n\n王凯对着话筒磕磕巴巴："Yes sir I... I will fix... yes I... " 5 分钟挂电话。整个人垮在台子上。',
      choices: [
        { label: '"换我 我跟他写邮件"（接手 escalation）', effect: { energy: -3, belonging: 10, npc: { wangkai: 2 } },
          feedback: '你拿过他手机。打开邮件 30 分钟用你 academic 写 essay 那一套：\n· acknowledge concern\n· propose mitigation timeline\n· offer good-faith £200 contribution to extractor service\n· request 14-day grace period\n\n邮件发出。第二天房东回："Reasonable. Thank you for the professional response."\n\n王凯看着 reply 5 秒。然后："哥们 我英文骂回去都比你这个 effective。我以后 escalation 全 outsource 你。"\n\n你笑——这一刻你的 cultural studies 学位有了第一个真实的 ROI。' },
        { label: '"哥这是你 business 你自己处理"', effect: { belonging: 2 },
          feedback: '你没接手。王凯第二天自己写了一封中式英文回复——房东第三天又打来骂了 20 分钟。\n\n王凯第二周花了 £400 装了新 extractor。\n\n你那一刻意识到——朋友圈不是只 transact 同质技能——是 cover 对方的 weakness。这次你没 cover。' },
      ],
    },
    {
      id: 'wangkai_mom_arrives_heathrow', minWeek: 30, maxWeek: 44,
      title: '王凯 · "我妈来伦敦了 你陪我去 Heathrow 接"',
      condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 6,
      body: '王凯微信："哥们 我妈第一次出国 周六 14:30 国航 CA855 到 Terminal 2。我自己开车去 路上有人陪好点。陪我？"\n\n你看了一眼——王凯连他妈来都要陪。',
      choices: [
        { label: '陪他去 Heathrow', effect: { energy: -8, belonging: 16, wallet: -3, npc: { wangkai: 3 }, flag: 'wangkai_mom_met' },
          feedback: '王凯开他刚买的 2014 二手 BMW。从 Soho 到 LHR 1 小时——他全程紧张到换错挡 2 次。\n\n他妈出关——一个 55 岁的福建女人，拖一个跟她差不多大的行李箱。看到王凯她没说话，但眼眶红了。她看了你一眼，王凯说"这是我朋友"，她点了点头，没寒暄。\n\n回 Soho 的车上她坐后座一直看窗外。王凯看后视镜——3 次。\n\n你那一刻知道——这个为 £6 一杯奶茶 grind 5 个月的男人 27 年人生里第一次给他妈展示自己挣的城市。\n\n3 周后王凯递给你一袋他妈带过来的麻花。"我妈让给你的。她说谢谢。"' },
        { label: '"哥 我学业紧"', effect: { belonging: -3 },
          feedback: '王凯："理解。" 他自己开车去了。\n\n后来你听说——他妈下飞机后王凯紧张到给一辆奔驰刮了车——赔 £600。\n\n你想：你那天没去。但你也知道——你那天有空。' },
      ],
    },
    {
      id: 'wangkai_first_payslip', minWeek: 36, maxWeek: 48,
      title: '王凯 · 第一次给员工发工资条',
      condition: ({ flags, npcRel }) => !!flags.wangkai_business && (npcRel.wangkai || 0) >= 6,
      body: '月底。王凯坐你对面——拿着 4 张打印好的 payslip。他自己注册的 PAYE 系统第一次跑通。\n\n"哥们 我今天给 4 个员工每人发了第一份 payslip 是我打印的。我手抖了。"\n\n他递给你一张——是给你的。Subcontractor consulting fee £200.',
      choices: [
        { label: '认真接 + "哥 你今天创了 4 个 paid jobs"', effect: { energy: 3, belonging: 18, wallet: 200, npc: { wangkai: 2 }, flag: 'wangkai_employer' },
          feedback: '王凯："靠 你这一句话给我顶住一年。"\n\n他从抽屉拿出来一张照片 — 他自己 14 岁在福建工厂打工的照片。"我爹那时候是 £1.5 一小时。我今天给员工 £14 一小时。我们家 father-son 两代差了 10 倍工时单价。"\n\n你这一刻知道——奶茶店不是奶茶店——是一个人用 20 年从 £1.5 干到 £14 的证明。\n\n你回 ensuite 把那张 £200 payslip 拍照存了——你这辈子第一份 consulting 收入。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // library · Aditi 互助 + 林楠 essay 互看
  // ─────────────────────────────────────────────────────────────
  library: [
    {
      id: 'aditi_share_notes', minWeek: 4, maxWeek: 35, repeatable: true,
      title: 'Aditi · 把笔记推过来',
      condition: ({ npcRel }) => (npcRel.aditi || 0) >= 2,
      body: 'Aditi 不说话，把她的 notebook 推到你面前——指着一段她整理得很整齐的 tutorial 笔记。\n\n"You missed Tuesday\'s. I figured." 她又戴回耳机。',
      choices: [
        { label: '认真抄 + 给她递 Pret latte', effect: { wallet: -4, energy: 2, belonging: 6, npc: { aditi: 1 } },
          feedback: '你抄完笔记。买了一杯 oat latte 放她桌上——她抬头愣了 1 秒——然后微笑："Thanks. Same time tomorrow." 这就是你们的 ritual 开始的样子。' },
      ],
    },
    {
      id: 'aditi_dad_mumbai_mention', minWeek: 5, maxWeek: 12,
      title: 'Aditi · 第一次提到她爸',
      condition: ({ npcRel }) => (npcRel.aditi || 0) >= 2,
      body: '深夜 11 点。Senate House 4 楼。\n\nAditi 在你旁边的位置——视频通话，声音压得很低。你能听到她说 "papa, please eat the rice, just one bite"。\n\n5 分钟后她挂电话——眼睛红红的，但她没说什么，继续打字。\n\n10 分钟后她推一颗 chai biscuit 到你桌上。',
      choices: [
        { label: '"Everything OK?" 轻声问',
          effect: { energy: -2, belonging: 8, npc: { aditi: 2 }, flag: 'aditi_dad_mentioned' },
          feedback: 'Aditi 抬头——沉默了 3 秒。然后:\n\n"My dad. He\'s in Mumbai. Liver disease — they\'ve been saying \'manageable\' for two years but mum just told me he stopped eating last week."\n\n她抹眼睛:"Sorry. I shouldn\'t dump this. We barely know each other."\n\n你说 "It\'s fine. I\'m here."\n\n她笑了一下:"Thanks. Keep this between us for now though." 你点头。\n\n（你不知道——这是 W30 dad_worsening 5 个月前的伏笔。）' },
        { label: '装没注意 + 继续打字',
          effect: { energy: 0 },
          feedback: '你假装没看见。\n\nAditi 继续打字。15 分钟后她收拾东西回宿舍。\n\n下次见她还会跟你礼貌点头——但她不会再视频时坐你旁边了。' },
      ],
    },
    {
      id: 'linnan_first_chinese', minWeek: 4, maxWeek: 8,
      title: '林可儿 / 林楠 · 第一次用中文说话',
      condition: ({ npcRel }) => (npcRel.linnan || 0) >= 1,
      body: 'Senate House 4 楼。你跟 ta 在图书馆第三次见。\n\n你们一直用英文聊 Foucault——客气、学术、有点累。\n\nta 突然小声:"诶——你是不是从国内来的?"\n\n这是 ta 跟你说的第一句中文。',
      choices: [
        { label: '"是啊 老乡!" 切中文',
          effect: { energy: 3, belonging: 12, npc: { linnan: 2 }, flag: 'linnan_chinese_switch' },
          feedback: 'ta 整个人肉眼可见地松下来——肩膀都低了一截。"靠，憋了 3 周英文了。我老家南京，你呢？"\n\n你们用中文聊了 40 分钟——从家乡话题到 Whitmore 的口音到 Tesco 的 pak choi。\n\nta 临走说:"哥们 / 姐们 终于。这一年估计要靠你 sanity check 了。"\n\n你回家路上——你不孤独。这是你这一年第一次跟同班同学说真心话。' },
        { label: '"Yeah, I am. But let\'s keep practising English"',
          effect: { energy: -2, belonging: 2, academic: 2 },
          feedback: 'ta 愣了 1 秒——然后:"Oh, sure. Yeah, you\'re right, we\'re here for that."\n\n你们继续用英文聊。20 分钟后 ta 走了。\n\n你之后跟 ta 永远是客客气气的英文。你英语进步了——但你错过了一扇友谊的门。\n\n半年后你看 ta 的 IG story 在跟另一个同学说中文——那个人不是你。' },
      ],
    },
    {
      id: 'aditi_chai_thermos', minWeek: 18, maxWeek: 50,
      title: 'Aditi · 一杯 chai 从保温杯倒出来',
      condition: ({ npcRel }) => (npcRel.aditi || 0) >= 4,
      body: 'Aditi 从背包掏出来一个保温杯——她没问你直接给你倒了一杯。\n\n"My grandma\'s recipe. Cardamom-heavy. You\'ll either love or hate it."',
      choices: [
        { label: '"Love it" 一口干', effect: { energy: 6, belonging: 8, npc: { aditi: 1 } },
          feedback: '你一口干完——确实 cardamom 重得能让你眼前一震。\n\nAditi："Mum sent her recipe last week. Said \'you must teach your friends.\' I think she meant you specifically."\n\n你愣了——你不知道你已经被 Aditi 妈妈在远程 acknowledge 了。这种 belonging 跨越 8000 公里。' },
      ],
    },
    {
      id: 'aditi_mock_interview', minWeek: 38, maxWeek: 50,
      title: 'Aditi · "Practice interview with me"',
      condition: ({ npcRel }) => (npcRel.aditi || 0) >= 5,
      body: 'Aditi 翻一页她的笔记本："I have an interview with HSBC tomorrow. Help me practice? I\'ll do yours after."',
      choices: [
        { label: '认真做 mock interviewer 30 分钟', effect: { energy: -3, academic: 4, belonging: 10, npc: { aditi: 2 } },
          feedback: '你给她出了 5 个 hard 问题——包括"Why HSBC and not Citi"。她最后一个答得磕巴 — 你给了 feedback："Don\'t list, structure: bank-strategy fit, your role-fit, your why-now."\n\n第二天她出来 message："Got the offer. The HSBC strategy answer—exact same I rehearsed with you."\n\n你那一刻知道——朋友不是给你 emotional support——是给你 dress rehearsal。' },
      ],
    },
    {
      id: 'aditi_mom_complaint', minWeek: 30, maxWeek: 50,
      title: 'Aditi · 抱怨她妈',
      condition: ({ npcRel }) => (npcRel.aditi || 0) >= 6,
      body: 'Aditi 把她的手机给你看——她妈妈给她发的 voice note 列表 17 条 in 2 hours。\n\n"Mum is on a CRUSADE about my hair length. I cut it short last week. She is — I quote — \'inconsolable\'."',
      choices: [
        { label: '"My mum did the same about my tattoo"', effect: { energy: 2, belonging: 8, npc: { aditi: 1 } },
          feedback: '你给她讲了你妈对你左手腕那个小 tattoo 的反应——她哭了 3 天的故事。\n\nAditi 笑得趴在桌上："Asian mums are a global phenomenon."\n\n你们吐槽到 1 小时——library 旁边一个 PhD 学生戴上了降噪耳机。\n\n这种 friendship 不是被建立的——是被妈妈们建立的。' },
      ],
    },
    {
      id: 'linnan_after_lecture', minWeek: 4, maxWeek: 35,
      title: '林可儿 / 林楠 · lecture 后聊 5 分钟',
      condition: ({ npcRel }) => (npcRel.linnan || 0) >= 2,
      body: 'Tutorial 散场。林可儿 / 林楠在 library 门口等你——你不知道 ta 在等。\n\n"哎 你今天那个 Foucault 的 push back 我超赞 但我有个反例 想跟你聊 5 分钟 行吗？"',
      choices: [
        { label: '聊 5 分钟', effect: { energy: -2, academic: 4, belonging: 5, npc: { linnan: 1 } },
          feedback: '你们站在 library 门口聊了 12 分钟（不是 5）——ta 拿 Habermas 给你打反例。你之前没读过——你说"那我去读"。ta 笑："你这种 honest 的 same-cohort 不多。"\n\n你回 ensuite 抓紧补 Habermas。' },
      ],
    },
    {
      id: 'linnan_essay_review', minWeek: 14, maxWeek: 40,
      title: '林可儿 / 林楠 · "看一段 essay 行吗"',
      condition: ({ npcRel }) => (npcRel.linnan || 0) >= 3,
      body: '微信："你今天有空吗？我 essay 第 3 段写 stuck 了 你眼睛 fresh 帮我看一下 我请你 oat latte。"',
      choices: [
        { label: '"行 Pret 见"', effect: { energy: -2, wallet: 4, academic: 3, belonging: 6, npc: { linnan: 1 } },
          feedback: '你看了 ta 那段——你直接说："这段你 over-引 Foucault 了 你自己的 voice 被淹了。" ta 沉默 5 秒。"靠 你说对了。"\n\nta 重写。一周后那段拿了 essay tutor 的"strong original argument"评价。\n\nta 给你 IG dm 一杯 oat latte 表情 + "你这种 fresh 眼睛 我以后都找你 review"。' },
      ],
    },
    {
      id: 'linnan_dating_allnighter', minWeek: 22, maxWeek: 50, repeatable: true,
      title: '林可儿 / 林楠 · 一起通宵赶 ddl',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 7,
      body: '凌晨 1 点。SOAS 24h library。你们俩面对面坐——你写 dissertation，ta 改 essay。\n\nta 把保温杯往中间一推："共享。还有 4 小时太阳出来。"',
      choices: [
        { label: '低头继续写 + 喝 ta 的咖啡', effect: { energy: -8, academic: 6, belonging: 8, npc: { linnan: 1 } },
          feedback: '凌晨 4 点你抬头——ta 趴在键盘上睡着了 5 分钟。你拍了一张照（不发）。\n\n6 点天蒙蒙亮。你们 2 个站在 SOAS 门口外面看 Russell Square 的雾——什么都没说。\n\n回 ensuite 路上 ta 说："以后我们老了 我会想起这一晚。" 你说"嗯。"\n\n这一刻你知道——5 年后 ta 不一定还在你身边。但这一晚 ta 一定会记得。' },
      ],
    },
    {
      id: 'linnan_dating_chai_thermos', minWeek: 24, maxWeek: 50, repeatable: true,
      title: '林可儿 / 林楠 · 一杯热的从保温杯倒出来',
      condition: ({ flags, npcRel }) => !!flags.linnan_dating && (npcRel.linnan || 0) >= 6,
      body: '你在 library 4 楼写论文。林可儿 / 林楠走过来坐下——没说话。掏出保温杯倒一杯热的递给你。\n\n红枣枸杞茶。',
      choices: [
        { label: '小口喝 + 继续写', effect: { energy: 4, belonging: 6, wallet: 0 },
          feedback: '你喝完 ta 给你续上一杯。\n\n你打字。ta 看 ta 的 paper。你们 1 小时没说话——但每隔 15 分钟 ta 续一次水。\n\n这种 silent care 比"我爱你"重得多——这是结婚 5 年的人才有的 vibe。你们 24 岁就有了。' },
      ],
    },
  ],

  // ─────────────────────────────────────────────────────────────
  // uni · Whitmore 学术线 + 走廊偶遇
  // ─────────────────────────────────────────────────────────────
  uni: [
    {
      id: 'whitmore_stops_you_tutorial', minWeek: 3, maxWeek: 6,
      title: 'Whitmore · "actually, one moment—"',
      condition: ({ flags }) => !flags.whitmore_stopped_first,
      body: 'Tutorial 散场。你收拾东西准备走——Whitmore 收 handout 的时候叫住你:\n\n"Actually, one moment. The point you made about \'internalised surveillance\'—it caught my ear. You\'ve read more Foucault than the syllabus, haven\'t you?"',
      choices: [
        { label: '老实说是大学 thesis 写过',
          effect: { rel: 3, energy: -2, academic: 6, belonging: 4, flag: 'whitmore_stopped_first' },
          feedback: '你说你 undergrad thesis 写的是 surveillance economy + 王阳明。\n\nWhitmore 眉毛挑了一下:"Ah—a cross-traditions move. We don\'t get that here often. Office hours Wednesday 4 pm, my door\'s always open."\n\n他把 handout 抱稳点头走了。\n\n你跟 Whitmore 之间从这一刻起不只是"教授 - 学生"。你下次 office hour 进他门时,他会从你的 thesis 那一行说起。' },
        { label: '"刚好读到 sir" + 谦虚带过',
          effect: { rel: 1, belonging: 2, flag: 'whitmore_stopped_first' },
          feedback: 'Whitmore 点头:"Modesty is fine, but accuracy is better. Come to office hours when you want to talk about it properly."\n\n他抱着 handout 走了。\n\n你这次没踩坑——但也没接 ta 递过来的那条线。下次想接,要主动去 office hours。' },
      ],
    },
    {
      id: 'whitmore_corridor_nod', minWeek: 6, maxWeek: 50, repeatable: true,
      title: 'Whitmore · 走廊偶遇',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 1,
      body: '你在 SOAS 走廊匆匆赶 tutorial。Whitmore 从对面走过来——抱着一摞 essay 红笔批好的。\n\n他点头："Good morning."',
      choices: [
        { label: '"Good morning, sir"', effect: { energy: 1, belonging: 2 },
          feedback: '他擦肩而过。你继续走。\n\n这种 5 秒的 acknowledgment 让你这一周 academic confidence 高 5%。' },
      ],
    },
    {
      id: 'whitmore_book_recommendation', minWeek: 14, maxWeek: 40,
      title: 'Whitmore · 推荐课外阅读',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 4,
      body: 'Office hour 临结束。Whitmore 从书架抽一本厚书递给你。\n\n"Off-syllabus. But you\'ll find it useful. Return it whenever."\n\n你看封皮——*Imagined Communities* by Benedict Anderson。',
      choices: [
        { label: '"Thank you, I\'ll read carefully"', effect: { academic: 6, energy: -2, belonging: 4, npc: { whitmore: 1 } },
          feedback: '你 2 周读完。第 3 章某段你在 margin 写了 3 行评注。\n\n你还书的时候 Whitmore 翻看了一下你的笔迹："Your engagement is not rare. But your engagement at this level *is*. Keep this. I have another copy."\n\n他签了名递回。你回家手抖了 5 秒才把书放进书架。' },
      ],
    },
    {
      id: 'whitmore_cafe_hello', minWeek: 10, maxWeek: 45,
      title: 'Whitmore · 校园 cafe 打招呼',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 3,
      body: '你在 SOAS Brunei Suite 排队等 latte。回头——Whitmore 排在你后面 2 个人。\n\n他朝你点头："The flat white here is acceptable. The latte is not. Sage advice."',
      choices: [
        { label: '"Got it, sir. Switching to flat white."', effect: { energy: 1, belonging: 3, npc: { whitmore: 1 } },
          feedback: '你改点了 flat white——确实比 latte 好。Whitmore 排到你后面 1 个人时跟收银员说："One Americano, black, please."（他让收银员 charge 到 his account）。\n\n你点完转身——他对你 raise 一下杯子："Cheers."' },
      ],
    },
    {
      id: 'whitmore_dissertation_panel_invite', minWeek: 38, maxWeek: 48,
      title: 'Whitmore · "Sit in on a panel?"',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 6,
      body: 'Whitmore 把一张纸放你面前——一个 PhD 学术 panel 的 invite。\n\n"This is a junior researcher panel I\'m chairing next Friday. Closed audience but I can invite a guest. Would you like to sit in?"',
      choices: [
        { label: '"I\'d be honored"', effect: { energy: -3, academic: 8, belonging: 8, npc: { whitmore: 2 }, flag: 'whitmore_panel_guest' },
          feedback: '你穿了你最正式的衬衫去。panel 上 4 个 PhD 学生 present，全程 1 小时——有 2 段你听不懂，但其他 3 段你跟得上。\n\n散会 Whitmore 走过来：" first time?" 你点头。"Most undergrads don\'t even know these exist. Now you do." \n\n他没说更多。但那一刻你知道——他在给你 access 做学术圈 starter kit。' },
      ],
    },
    // ─── Whitmore 学术礼仪 / 日常擦肩 ───
    {
      id: 'whitmore_invigilating_exam', minWeek: 34, maxWeek: 36,
      title: 'Whitmore · 期末监考',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 3,
      body: '期末考试 Hall。3 小时闭卷。\n\n你坐到位置上——抬头看监考——是 Whitmore。他在前排桌子那看着 100 个学生发卷。\n\n他和你目光对了 0.5 秒——他点了一下头。然后看别人。',
      choices: [
        { label: '深呼吸 + 答题', effect: { energy: -3, academic: 5, belonging: 4 },
          feedback: '考试中段你卡在第 3 道题——理论应用题。你抬头——Whitmore 在某个学生那回答问题。他扫过你这片区域时——又点了一下头。\n\n那一秒你像被加了 buff。你回答第 3 题的思路突然清楚了——你写了 800 字的回答。\n\n出考场你看到他在门口收卷子——他看你递卷子时说一句很轻的 "Good." 你一周后查 grade——这门 78 分。' },
      ],
    },
    {
      id: 'whitmore_signs_form', minWeek: 37, maxWeek: 50,
      title: 'Whitmore · 签 dissertation form',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 3,
      body: 'Office hour。你拿着 supervisor signature 表（dissertation 注册需要他签字）。他扫了一眼："I sign these once a year. Tell me about your topic in one sentence before I sign."',
      choices: [
        { label: '简洁 30 秒讲完 topic', effect: { energy: 1, academic: 4, belonging: 3, npc: { whitmore: 1 } },
          feedback: '你 30 秒讲完。他听完——签了字。然后说一句让你愣的话："That was clearer than 80% of the dissertations I\'ve seen this decade. Whatever you write next will be readable. The hard part now is making it ambitious."\n\n你拿着签好的 form 走出 office——你这一刻知道 — clarity 是地基， ambition 是顶。你已经有地基了。' },
        { label: '紧张讲了 1 分钟绕了 3 个圈子', effect: { energy: -2, academic: 1 },
          feedback: '他听完——签了字。"Right." 这就是他的反应。\n\n你回去发现——你这一年还需要练 elevator pitch。有些 academic skill 不是 essay 写出来的——是 30 秒说出来的。' },
      ],
    },
    {
      id: 'whitmore_bookshop_collision', minWeek: 14, maxWeek: 45,
      title: 'Skoob 二手书店 · 偶遇',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 4,
      body: '周六。你在 Brunswick Centre 的 Skoob 二手书店翻 cultural studies 那一架。\n\nWhitmore 从拐角出现——抱着 4 本厚书。两个人都愣了 0.5 秒——这是你在校外第一次见他。\n\n他笑了："Even at the weekend."',
      choices: [
        { label: '看他选了什么书 + 推荐你正在读的', effect: { energy: 1, academic: 5, belonging: 6, npc: { whitmore: 2 } },
          feedback: '他抱的 4 本——一本是他自己学生年代的 Stuart Hall 旧版。"Just realized I gave away my copy in 1992."\n\n你说你正在读 Said。他："Reading or quoting? Different things."\n\n你笑："Quoting—working towards reading."\n\n他："Honest answer." 然后他给你指了 corner 那架："There\'s a 1978 first edition there. £8. Better than the reissued one." 你买了。\n\n你这一刻和他不是 supervisor-student 了——是同一个二手书店里的 2 个 readers。' },
        { label: '客气打招呼 + 走开', effect: { energy: 0, belonging: 1 },
          feedback: '"Hello sir, have a good weekend." 你转身去另一架。\n\n但你出门时——你发现你手里的书没有刚才他指那本好。下次再有这种 informal 时刻你不会再客气避开。' },
      ],
    },
    {
      id: 'whitmore_senate_house_paper', minWeek: 24, maxWeek: 45,
      title: 'Senate House · 楼梯口递给你一篇 paper',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 5,
      body: 'Senate House 5 楼。你在 Periodicals reading room 出来——Whitmore 正好从对面走过。\n\n他停下："I have something for you." 从公文包里抽出来一份 stapled offprint。\n\n"This was published last month. Author is a former student of mine. You\'ll find chapter 3 directly relevant to your topic. Don\'t cite without reading the whole thing."',
      choices: [
        { label: '"Thank you sir, I\'ll read tonight"', effect: { energy: -2, academic: 8, belonging: 6, npc: { whitmore: 2 } },
          feedback: '你那晚就读完了。第 3 章确实命中你 dissertation 第 2 章 — 你之前那一段的反方论证完全被这篇 paper 覆盖了。\n\n你重写了那 800 字。Whitmore 第二天上 office hour 你说"Sir 你给的 paper 改了我整个 chapter 2。" 他点头："That\'s why I gave it to you. You weren\'t going to find it on Google Scholar — wrong keywords."\n\n你那一刻知道——supervisor 真正的 value 不是 grade 你的 essay——是知道你 *不知道* 该读什么。' },
      ],
    },
    {
      id: 'whitmore_common_room_invite', minWeek: 28, maxWeek: 42,
      title: 'Whitmore · "Tea in the common room?"',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 6,
      body: 'Office hour 结束。Whitmore 站起来收拾书："I\'m going up to Senior Common Room for tea. You\'re welcome to join — students don\'t come here often but it\'s not forbidden."\n\n他打开门等你。',
      choices: [
        { label: '跟他上去喝 30 分钟茶', effect: { energy: -3, academic: 4, belonging: 8, npc: { whitmore: 2 }, flag: 'whitmore_common_room' },
          feedback: 'Senior Common Room——3 张沙发、4 位教授、墙上挂的画 17-19 世纪都有。Whitmore 给你和他自己各倒一杯 Earl Grey。\n\n他指着对面一位戴眼镜的老太太："That\'s Prof. Hartley. Sociology. Don\'t introduce yourself unless she asks first—it\'s the convention here."\n\n你 30 分钟没怎么说话——主要听他和 Hartley 聊 1989 年柏林墙倒下时他们各自在哪里教书。\n\n你出门时知道——你刚 access 了你这一年学费的 ROI 里最隐形那部分：英国学术圈的 informal layer。' },
        { label: '"我下午有 tutorial 抱歉"', effect: { energy: 0 },
          feedback: '"Of course." 他点头。"Some other time."\n\n但 some other time 没再来——他这种 invite 一年最多 1 次。你没接住的——这一年就过了。' },
      ],
    },
  ],
};
