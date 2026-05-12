// Cross-line ripple events.
//
// 一条剧情线发生的事，通过另一个 NPC 反射回来。让世界感觉 alive。
//
// 核心 pattern: 玩家在某条线 take damage（被骗 / freelance 起飞 / 反诈帖子病毒）
//               → 几周后另一个 NPC 在 location 事件里 notice 到 → 给玩家一个反应窗口。
//
// 设计原则:
//   1. 不强制说出来 — 玩家可以选择继续藏。但藏的代价是 belonging 流失。
//   2. NPC 不审判 — Sarah/Aditi/Mei/林楠 都是先 notice 再让玩家自己决定讲不讲。
//   3. 反诈帖那条不是"被关心"，是"被认出"——你之前的善行回到你身上。
//
// 触发栈使用 location-based event pool，和 NPC_DEEPENING_EVENTS 共用引擎。

// 玩家被坑过任何一种钱（醒过来的）。包括失血较小的（£200 - £500）和大额（£1500+）。
const wasScammed = (flags) =>
  flags.scammed_pig_full || flags.scammed_pig_partial ||
  flags.scammed_trading_full || flags.scammed_trading_partial ||
  flags.scammed_cosmetic || flags.scammed_mlm ||
  flags.scammed_consul || flags.scammed_courier || flags.scammed_recruiter ||
  flags.scammed_deposit || flags.scammed_psw_agent || flags.scammed_sponsor_full;

// 玩家被骗了较大数（≥ £1500）—— 用于触发"重型情感反应"的 ripple。
const wasMajorScam = (flags) =>
  flags.scammed_pig_full || flags.scammed_pig_partial ||
  flags.scammed_trading_full || flags.scammed_trading_partial ||
  flags.scammed_sponsor_full;

export const CROSS_LINE_RIPPLE_EVENTS = {
  flat: [
    {
      id: 'sarah_notices_scam_aftermath',
      // 之前 minWeek 18 太晚——scam_1 W4 已能 set 任何 scammed_* flag，玩家会等 14 周
      // Sarah 才"察觉"，叙事僵。改成 6 给最早的 W4 scam 留 2 周缓冲，body 文案"你这两周
      // 不是你"也对得上。后期 scam 触发时 minWeek 早过了，wasScammed 自然 gate 住。
      minWeek: 6, maxWeek: 50,
      title: 'Sarah · 厨房里的一杯茶',
      condition: ({ flags, npcRel }) =>
        (npcRel.sarah || 0) >= 4 && wasScammed(flags) && !flags.sarah_knows_scam,
      body: '凌晨 12 点。你下楼煮泡面——Sarah 已经在那里，戴着耳机做 essay。看到你她摘了一只耳机。\n\n"You\'ve been weird this week. And the week before that. I\'m not gonna pretend I haven\'t noticed. Want a tea? I\'ll listen if you wanna talk. No pressure."\n\n她已经把水壶按上了。',
      choices: [
        { label: '坐下来全说出来', effect: { energy: -8, belonging: 18, npc: { sarah: 4 }, flag: 'sarah_knows_scam' },
          feedback: '你跟她讲了 1 小时——Hinge 上那个 Daniel/Diana / Eric 哥 / Lyn 姐 / Emma 学姐 / 假大使馆电话——你最重的那一段。\n\nSarah 全程没插嘴。最后她说："That\'s not naive. That\'s grief that didn\'t know what shape to take. I\'m glad you\'re telling me."\n\n她抱了你一下。第二天她在 Tesco 给你买了 Cadbury 一大块巧克力放在你 ensuite 门口——没卡片，但你知道是她。\n\n这一刻起 Sarah 不是 flatmate 了——是知道你一年最重那段的那个朋友。' },
        { label: '只讲一部分（钱的事不细说）', effect: { energy: -3, belonging: 8, npc: { sarah: 2 } },
          feedback: '你说"被一个网恋骗了点钱 算了 没事"。Sarah 看了你 5 秒："Babe. Not sure I believe the \'no big deal\' part. But OK. When you\'re ready."\n\n她递给你一杯茶。你们没再说，但她下楼遇到你时眼神不一样了。\n\n部分坦白也是坦白。' },
        { label: '"I\'m fine just essay stress"', effect: { energy: 0, belonging: -5, npc: { sarah: -1 } },
          feedback: 'Sarah 笑了一下："Right. OK." 她戴回耳机。\n\n你回 ensuite 抱着泡面坐了半小时。你知道她不信。但你也没勇气再下楼说一遍。\n\n这一晚之后 Sarah 还是 Sarah——但你们的对话再没有过那一夜可能的深度。' },
      ],
    },
    {
      id: 'linnan_confronts_partner_off',
      minWeek: 22, maxWeek: 50,
      title: '林楠 · "你这两周不是你"',
      condition: ({ flags, npcRel }) =>
        !!flags.linnan_dating && wasScammed(flags) &&
        !flags.linnan_knows_scam && (npcRel.linnan || 0) >= 7,
      body: '周三晚 10 点。林可儿 / 林楠在你 ensuite——两个人本来要一起看一部电影。\n\nta 注意到你手机屏幕上空了 30 秒——你盯着一个已经没人回的对话框。\n\nta 把电脑合上："你这两周不像你。视频里我也看出来了。我不催你——但你不说我陪不了你。"',
      choices: [
        { label: '全说出来 + 给 ta 看截图', effect: { energy: -10, belonging: 18, npc: { linnan: 5 }, flag: 'linnan_knows_scam' },
          feedback: '你打开手机翻给 ta 看——5 周聊天记录、转账记录、Action Fraud 报案号。\n\nta 看了 10 分钟没说话。然后说："这不是你蠢。这是 4 个月的精装表演。我看了都信。"\n\nta 抱住你哭——不是替你，是 ta 自己也想起 ta 妈妈表妹去年被同样模板骗了 ¥50k。\n\n那一晚你们没看电影。你们手牵手到天亮——这一晚之后 ta 没再问你"你最近怎么了"，因为 ta 已经知道了。' },
        { label: '撒谎"是 dissertation 焦虑"', effect: { energy: -5, belonging: -10, npc: { linnan: -8 }, flag: 'linnan_betrayed' },
          feedback: 'ta 看了你 5 秒："好。"\n\n两周后某次你们吵架——ta 说："你那次说是 dissertation 焦虑——我后来在你浏览器历史看到 Action Fraud。你为什么对我撒谎。"\n\n你没法解释。\n\n这道伤口比骗子那 £5000 更深——因为 £5000 是陌生人，但这一刀是你自己捅的。' },
        { label: '"我自己处理 你别管"', effect: { energy: -3, belonging: -5, npc: { linnan: -3 } },
          feedback: 'ta 看着你 5 秒："好。我不管。"\n\nta 收东西走了。第二天给你发"今晚有事 不过来"。\n\n这一周你们之间多了一种沉默——不是冷战，是 ta 在等你 reach out。但你说不出来"对不起"。\n\n感情里最累的不是吵架，是没说出来的那部分变成习惯。' },
      ],
    },
  ],

  uni: [
    {
      id: 'whitmore_essay_concern',
      // 同 sarah ripple：早期 scam 玩家不必等 14+ 周才见 supervisor 关心 essay。
      // essay grade 通常 2-3 周一次，让 ripple 在 W10 之后即可触发。
      minWeek: 10, maxWeek: 50,
      title: 'Whitmore · 红笔下的关心',
      condition: ({ flags, npcRel }) =>
        (npcRel.whitmore || 0) >= 5 && wasScammed(flags) && !flags.whitmore_knows_scam,
      body: 'Office hour。Whitmore 把你这次的 essay 推过来——封皮 62。\n\n他平时给你 70+。你前 3 篇有一篇 78。\n\n他说："This is well below what you\'ve produced before. You\'re distracted. I don\'t need to know why—but I do need to know if there\'s something I should be aware of."\n\n他没追问 — 但他也没让你 brush off。',
      choices: [
        { label: '坦白讲出来（包括钱被骗了）', effect: { energy: -5, academic: 5, belonging: 14, npc: { whitmore: 3 }, flag: 'whitmore_knows_scam' },
          feedback: '你讲了 20 分钟。Whitmore 听完没说"how could you fall for that"——他只是点头。\n\n然后他说："Romance scams use the same techniques as cult recruitment. Intelligent people fall for them — that\'s the design. You\'re not exempt because you\'re here."\n\n他把 essay 推回你面前。"Resubmit by next Friday. I\'ll regrade. And — if you haven\'t already, do consider speaking to NHS Talking Therapies. SOAS Wellbeing can refer."\n\n你重交了，拿了 73。但更重要的是——这是你来英国第一次有教授把你当人，不是当 international student fee。' },
        { label: '"I\'ve been distracted, won\'t happen again"', effect: { energy: -3, academic: 3, npc: { whitmore: 1 } },
          feedback: '他点头："Right. Resubmit by Friday."\n\n你重写了，拿了 68——比 62 好，但不到他对你的预期。\n\n之后他对你客气但不再深入。这不是惩罚——这是你自己关上的一扇门。' },
        { label: '撒谎"flu / 家里有点事"', effect: { energy: -3, academic: 0, belonging: -5, npc: { whitmore: -1 } },
          feedback: '"Family. Right." 他说。然后转话题。\n\n你重交 essay 拿了 65。\n\n3 周后 Whitmore 在 tutorial 上点别人发言不点你。你坐在那里想——他不是不再 care，是他给过你一次台阶你没下。' },
      ],
    },
  ],

  mei: [
    {
      id: 'mei_notices_off',
      // 同上：Mei 姐看到玩家"脸色不好"不必等 12 周。8 之后任何 scam 后她都能注意到。
      minWeek: 8, maxWeek: 50,
      title: 'Mei 姐 · "傻孩子最近脸色不好"',
      condition: ({ flags, npcRel }) =>
        (npcRel.mei || 0) >= 5 && wasScammed(flags) && !flags.mei_knows_scam,
      body: '你又来吃饭。Mei 姐看了你一眼，没说话。给你的盘子里多打了一勺红烧肉，又多盛了一碗米饭。\n\n你结账时她按住你的钱包："今天我请。"\n\n然后她坐下来——她这个动作 1 年来你只见过 2 次。她说："傻孩子，最近脸色不好。是不是出事了？"',
      choices: [
        { label: '点头 + 哭着全说出来', effect: { energy: 5, wallet: 50, belonging: 22, npc: { mei: 3 }, flag: 'mei_knows_scam' },
          feedback: '你哭了。她让你哭完。\n\n然后她说一句让你 bewildered 的话："我刚来英国第二年，被一个新加坡来的男的骗了 £3,000——那时候是 1996 年，£3,000 我半年工资。我跟你一样没敢跟家里说。"\n\n你看着她——你从来没想过 Mei 姐也年轻过、也犯过这种错。\n\n她从围裙里掏出 £50："拿着。这不是借——是奶奶给孙女的。" 你想拒绝她按住你的手："傻孩子。"\n\n你这一刻 belonging 不是来自任何 NPC——是来自一个 1996 年也犯过同样错的女人，30 年后还活得很好。\n\n你想：原来"丢人"是可以过去的。' },
        { label: '"没事 Mei 姐 学业有点紧"', effect: { energy: 0, belonging: 6, npc: { mei: 0 } },
          feedback: '她没追问。给你打包了一份红烧肉："带回去吃。"\n\n你回 ensuite 把红烧肉热了——吃到一半哭了。\n\n你想：她其实知道。但她也尊重你不说的权利。\n\n这种 belonging 你不知道叫什么名字——但你这一刻很想给妈打电话。' },
      ],
    },
    {
      id: 'cssa_freshman_recognizes_you',
      minWeek: 35, maxWeek: 52,
      title: '"学姐 / 学长 你就是写那个反诈贴的吧"',
      condition: ({ flags }) => !!flags.scam_educator && !flags.recognized_by_freshman,
      body: '中餐馆。一个 19 岁左右的新生（你认得脸，是上个月才入学的那批）端着饭走过来。\n\n"打扰了——学姐 / 学长 你是不是 [你的名字]？我前段时间看到 CSSA 群置顶那个反诈贴——救了我妈一笔钱。我表姐想冒充国内警察打给我妈让她转 ¥80,000——我把你那贴转给她她当场识破了。"\n\nta 鞠了一躬。你愣了。',
      choices: [
        { label: '让 ta 坐下 + 给 ta 讲一遍这一年', effect: { energy: -8, belonging: 22, academic: 3, flag: 'recognized_by_freshman' },
          feedback: '你跟新生聊了 90 分钟。讲了你这一年——什么时候差点被骗、什么时候真的被骗、什么时候站出来发那个贴。\n\nta 听得很认真。临走时 ta 说："学姐 / 学长 我也想做点什么。我们能不能搞一个新生反诈 onboarding？"\n\n你愣了 5 秒——然后说"行 你 lead 我帮"。\n\n3 周后 CSSA 真的搞了一个"新生反诈 30 分钟 onboarding"——上百个人参加。你第一次站在台前讲了 15 分钟。Mei 姐在后面站着听完，没说话，只是点了一下头。\n\n你这一年最重的那段经历——变成了别人的护身符。' },
        { label: '"嗯 是我"（点头微笑）', effect: { energy: 1, belonging: 12, flag: 'recognized_by_freshman' },
          feedback: 'ta 笑得很灿烂："谢谢学姐 / 学长。" 然后端着饭走了。\n\n你坐在那里看 ta 走的背影——眼眶有点热。\n\n你这辈子第一次被人当作"做了点对的事的人"。\n\n回去路上你给 CSSA 群发了一句："新生群有什么问题随时 at 我。" 5 个新生立刻 at 了你。' },
        { label: '"不是我 你认错了"', effect: { energy: 0, belonging: -3 },
          feedback: 'ta 愣了一下："哦 不好意思。" 然后端着饭走了。\n\n你低头吃饭。你不知道你为什么要否认——但你那一刻就是不想承认。\n\n半小时后你在朋友圈刷到 ta 发的"今天差点见到反诈学姐 / 学长 但我搞错人了"。\n\n你抓住了否认的安全。但你也错过了一段本可以发生的连接。' },
      ],
    },
  ],

  pub: [
    {
      id: 'aditi_notices_pub',
      // Aditi 收到 Sarah 转告"她最近 off 3 周"——Sarah ripple 已经早触发，所以 Aditi
      // 也跟着早一点。10 之后任何 scam 后 W11+ 可见。
      minWeek: 10, maxWeek: 50,
      title: 'Aditi · 在 pub 角落坐下',
      condition: ({ flags, npcRel }) =>
        (npcRel.aditi || 0) >= 4 && wasScammed(flags) && !flags.aditi_knows_scam,
      body: '你在 pub 角落坐着发呆。半瓶 cider 没喝完。\n\nAditi 突然出现——你没约她。她在你对面坐下，点了一杯 lime soda（她不喝酒）。\n\n"I texted Sarah. She said you\'ve been off for like 3 weeks. So I thought I\'d find you. You don\'t have to talk. But I\'m here for at least an hour."',
      choices: [
        { label: '哭出来 + 全说', effect: { energy: -5, belonging: 18, npc: { aditi: 4 }, flag: 'aditi_knows_scam' },
          feedback: '你说着说着就哭了。Aditi 没递纸巾——她让你用她的袖子。\n\n你讲完她说："My cousin lost £18,000 to one of these scams in 2023. She still hasn\'t told her parents. You\'re doing better than her — you\'re telling me."\n\n然后她非常严肃："Two things. One: NHS Talking Therapies, GP referral, they have CBT specifically for fraud trauma. Two: you don\'t owe yourself getting over this in any timeline. Take a year if you need."\n\n你回家路上 tube 上抱着 Aditi 的围巾（她忘记拿了）发呆。第二天你给 GP 写了 referral。' },
        { label: '"我没事 真的"', effect: { energy: -3, belonging: 4, npc: { aditi: 1 } },
          feedback: 'Aditi 看了你 5 秒："OK. But text me at 3am if you need to. I keep my phone on."\n\n你们聊了 30 分钟其他事。\n\n回家路上你想——她其实知道。她只是给你保留了一个台阶。' },
      ],
    },
  ],

  soho: [
    {
      id: 'wangkai_pings_freelance_success',
      minWeek: 30, maxWeek: 50,
      title: '王凯 · "兄弟 LinkedIn 看到你了"',
      condition: ({ flags, npcRel }) =>
        (npcRel.wangkai || 0) >= 4 &&
        (!!flags.freelance_premium || !!flags.freelance_career || !!flags.freelance_to_corporate) &&
        !flags.wangkai_pinged_success,
      body: 'Soho 那家奶茶店。你刚下单他就从后厨出来——还是那个戴黑框眼镜的样子，但身上多了一个 Apple Watch。\n\n"哥们 你 LinkedIn 我刷到了。\'Freelance designer, working with [startup names] on brand identity\'。靠 你不端盘子也不扛包了？"\n\n他坐下来，给自己也倒了杯奶茶。',
      choices: [
        { label: '"你那时候 Bicester 给我的 £80 是我入伙费"', effect: { energy: 3, belonging: 18, npc: { wangkai: 3 }, flag: 'wangkai_pinged_success' },
          feedback: '王凯笑了——这次是真笑，不是商人笑。"靠 这话说的。" 他低头搅奶茶。\n\n然后他说："其实我那时候也想过当 designer。我大学画过半年漫画。家里说不挣钱。" 你愣了——你 1 年来不知道这件事。\n\n你说："你现在的店养你 designer 也行。" 他笑着摇头："我已经在我的轨道上了。但你这条对——你比我会做这个。"\n\n他不收你这杯奶茶钱。出门他在你后面喊一句："哥们 别忘了我啊。" 你回头："你这话 4 个月前我跟你说过。"\n\n你们俩在 Soho 街头大笑了 30 秒。' },
        { label: '"哥 你也带带我啊 我还菜"', effect: { energy: 1, belonging: 8, npc: { wangkai: 1 } },
          feedback: '"少来 你 LinkedIn 我看了 retainer 都 £14k 了。" 王凯笑。\n\n你们聊了奶茶店上半年的故事——他要扩两家分店。你跟他分享你 quote rate 的逻辑。两个人都在自己的轨道上跑。\n\n他打包了一杯免费奶茶给你："送你一个开张奶茶。" 你接过来——这是你来英国 30 周前他递给你的第一杯，30 周后他还在送你。' },
        { label: '客气一下', effect: { energy: 0, belonging: 4 },
          feedback: '"嗯 一切都还好。"\n\n王凯点头："那就好。"\n\n你们没再深入。出门时他递你奶茶——就是普通的客户关系。\n\n你不知道你为什么没接住这一刻。但 5 周前你们还会一起熬夜煮珍珠的——现在这个距离是你自己拉开的。' },
      ],
    },
  ],
};
