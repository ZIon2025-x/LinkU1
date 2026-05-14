// 论文期 W26-48 学术里程碑事件。
//
// 真实 UK MSc 一年制时间线：W26-28 见 supervisor 谈选题 → W30-33 提交 proposal →
// W34-40 文献综述 + IRB/ethics → W41-46 写作 → W48 提交。之前所有事件都堆在
// W37+，让玩家"前 3/4 学期完全不见 dissertation"，与真实节奏不符。已把
// proposal_meeting 拉前到 W28-30，给写作期留出真实节奏。
//
// W37-52 占游戏 1/3 时长，但之前主要被 postGrad（求职）+ flatHunt 占满，
// 真正"在写论文"的体验空。这个文件填充 W26-48 的写作过程：
//   · Lit review 的 87 个 tab 焦虑
//   · IRB / ethics 审批被 block
//   · 第一稿被 supervisor 红笔批注
//   · 凌晨 3 点的"我这个 topic 是不是没意义"
//   · Aditi 提议 parallel writing pact
//   · 字数恐惧 (4500 / 15000)
//   · Turnitin similarity 恐慌
//
// W49-52 已被 endGame.js 覆盖（dissertation_panic / last_pret / packing /
// last_visit_mei / graduation_ceremony），不重复。

export const DISSERTATION_EVENTS = {
  uni: [
    {
      id: 'diss_proposal_meeting',
      // 之前是 W37-39（实际 UK MSc proposal 应在 Easter 之前 W26-30 见 supervisor）。
      // 拉前到 W28-31 让 W32+ 才进入 IRB/写作期，与真实节奏对齐。
      minWeek: 28, maxWeek: 31,
      title: 'Whitmore · 第一次正式 supervision',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 2,
      body: 'Whitmore 把你 5 页的 proposal 推回桌上——第 2 页和第 4 页角落各打了一个红色问号。\n\n"This is a perfectly serviceable proposal. Which is why I\'m worried. You\'re not asking the question you actually want to ask. The question you actually want to ask is somewhere on page 4, in a parenthetical. Find it. Make it the title."\n\n他坐回去喝茶。',
      choices: [
        { label: '回去重写 + 把第 4 页那句变成题目', effect: { energy: -8, academic: 8, belonging: 6, npc: { whitmore: 2 }, flag: 'diss_proposal_rewritten' },
          feedback: '你回 ensuite 看了 1 小时 page 4——第三段中间一句 "(or are we asking how second-generation diaspora claim authenticity through cultural absence?)"。\n\n你把它放大、改成 working title。重新提交。\n\nWhitmore 第二天回邮件：一句话——"That\'s the question. Now answer it."\n\n这是你来英国第一次知道：好的研究不是 brave 的人写的——是被人逼着 brave 的人写的。' },
        { label: '"那一句太大 我把握不住"', effect: { energy: -3, academic: 2 },
          feedback: 'Whitmore 听完点点头："Fair self-assessment. Then write the smaller version. But know that you\'re writing the smaller version on purpose."\n\n你重交了原 proposal 的轻度修改。Whitmore 没再批注。\n\n你完成了——但你知道这本 dissertation 不会进任何人的脚注。' },
        { label: '辩驳 + 解释你的 original choice', effect: { energy: -5, academic: 6, npc: { whitmore: 1 } },
          feedback: '你给他讲了 15 分钟为什么原来的题目是对的。他听完——没反驳——只说："OK. Make me wrong. Show me data. By W42."\n\n你回去开始疯狂找 sources。3 周后他承认你是对的——这是他这辈子第二次跟一个 MSc 学生说"You changed my mind on this."' },
      ],
    },
    {
      id: 'diss_irb_ethics_block',
      minWeek: 41, maxWeek: 43,
      title: 'Ethics Committee · "Resubmission required"',
      // 任何人到这周都会撞 ethics review —— 之前是 `flag || true` 的 dev artifact，
      // 现在显式表达"对所有 dissertation 玩家触发"。
      body: '你拆开邮件——SOAS Ethics Committee。\n\n"Dear [name], thank you for your ethics application. The committee has identified concerns regarding informed consent procedures for online interview participants. Please revise sections 3.2 and 4.1 and resubmit. Standard turnaround is 4 weeks."\n\n你的 deadline 9 周。如果再 reject 一次——你的 fieldwork 就来不及了。',
      choices: [
        { label: '当晚就改 + 第二天约 supervisor 看', effect: { energy: -10, academic: 10, belonging: 6, flag: 'irb_resolved' },
          feedback: '你熬夜重写 consent form——加了 GDPR-compliant data retention 条款 + 额外 withdrawal clause。\n\nWhitmore 第二天看了 30 分钟说："Better. Submit." 你交了。\n\n2 周后过了。比预期快。\n\n你想：原来 ethics committee 不是敌人——他们是教你"做研究的成本"。' },
        { label: '简化 method 改成 secondary research only', effect: { energy: -5, academic: 4, flag: 'diss_scope_reduced' },
          feedback: '你删掉了 interview 那一章——改用 published interviews + content analysis。\n\nethics 不需要再审。但你 dissertation 也少了原计划最 original 的部分。\n\n你交得了。但你知道你为了 timeline 砍掉了你最想做的事。' },
        { label: '拖 1 周再说', effect: { energy: -3, academic: -5, flag: 'diss_irb_delayed' },
          feedback: '你打开 ethics form 又关掉。3 次。\n\n1 周后你终于改——但 ethics committee 这周开会 schedule 满了，你的 resubmission 排到 6 周后。\n\n你的 dissertation timeline 现在 dangerously tight。' },
      ],
    },
    {
      id: 'diss_first_draft_red_pen',
      minWeek: 43, maxWeek: 45,
      title: '第一稿被退回 · 47 个红笔标记',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 3,
      body: '你交了 chapter 1 + chapter 2 给 Whitmore（共 6,000 字）。\n\n两天后你打开 Word with track changes——\n\n47 个 inline comments。其中 12 个是 "REPHRASE"。8 个是 "Source?". 5 个是 "Why?"。3 个是 "This contradicts your earlier point."。\n\n但在 chapter 2 第 5 页——一个简单的 highlight + 一句话："This paragraph is excellent. Keep this voice for the rest."',
      choices: [
        { label: '从那 1 个被表扬的段落 reverse-engineer 整章', effect: { energy: -12, academic: 14, belonging: 8, flag: 'diss_voice_found' },
          feedback: '你 print 出那一段贴墙上。读了 10 遍。然后开始用同样的句法 + 同样的论证密度 + 同样的 voice 重写整章。\n\n5 天后你交第二稿。Whitmore 这次只有 8 个 comments——其中 5 个是 "Yes." 一个是 "Now we\'re talking."\n\n你哭了——不是 sad cry，是 "I figured it out" cry。' },
        { label: '逐条改完 47 个 + 再交', effect: { energy: -15, academic: 8, belonging: 4 },
          feedback: '你 5 天里逐条改完 47 个 comments。Whitmore 第三稿给了 23 个新 comments——你又改。第四稿 11 个——你又改。\n\n最后你的 dissertation 通过了——但你写完那一刻没有"我做到了"的感觉，只有"我没死"的感觉。\n\n这一年你学了 follow instructions。但你 voice 还没找到。' },
        { label: '崩溃哭一场 + 给 Aditi 发消息', effect: { energy: -8, belonging: 12, npc: { aditi: 1 } },
          condition: ({ npcRel }) => (npcRel.aditi || 0) >= 4,
          feedback: '你给 Aditi 发"i\'m drowning". 10 分钟后她出现在你 ensuite——拿了一袋 mango。\n\n她翻了你 47 个 comments：然后她说一句让你 unstuck 的话："These aren\'t criticisms. They\'re a roadmap. Pick the easiest 5 to fix tonight. Quitting because of 47 is dropping a marathon at mile 8."\n\n你 fix 了 5 个。第二天 fix 5 个。一周后 fix 完了。\n\n你想：朋友的作用不是同情你——是把你的恐惧重新 frame 成 todo list。' },
      ],
    },
  ],

  library: [
    {
      id: 'diss_lit_review_87_tabs',
      minWeek: 38, maxWeek: 41,
      title: '87 个 tab · 0 字写作',
      condition: ({ flags }) => !flags.diss_lit_review_started,
      body: '凌晨 1 点。SOAS 4 楼。\n\n你的 Chrome 现在有 87 个 tab：JSTOR / Sage Journals / arXiv / Google Scholar / 4 个 PDF / 一个韩国博士的 blog / Zotero / 还有 3 个不知道从哪里点开的。\n\n你的 Word 文档：标题 + 一行 "Chapter 1 — Introduction"。其他空白。\n\n你已经在这个文档前坐了 3 小时。',
      choices: [
        { label: '关掉 80 个 tab + 强制写 500 字（不管好坏）', effect: { energy: -8, academic: 10, flag: 'diss_lit_review_started' },
          feedback: '你只留 5 个最 relevant 的 tab。给自己设了一个 25 分钟 timer——"500 字 garbage first draft"。\n\nTimer 响时你写了 612 字。烂得像高中生。但有了 612 字 不是 0 字。\n\n第二天你能改写——0 字没法改写。\n\n这是 academic productivity 最重要的一课：first draft 必须写得难看，good draft 是改出来的。' },
        { label: '再读 5 篇 paper 就开始', effect: { energy: -10, academic: 3, flag: 'diss_procrastinated_lit_review' },
          feedback: '你又读了 5 篇 paper——其中 3 篇你之前已经读过 1 次了。\n\n3 小时后你看着 Word 文档还是空白。你又关掉电脑。\n\n你睡前 google "PhD students write or read first" — 9 个 reddit 帖子全是 "write first, read in service of writing"。但你明天还是会先 read。\n\n这就是 procrastination：不是懒，是恐惧装扮成 thoroughness。' },
        { label: '回 ensuite 睡觉 + 明天再说', effect: { energy: 8, academic: -3 },
          feedback: '你 11 点离开图书馆。回家洗了个澡睡了 8 小时。\n\n第二天精神好——但 dissertation 上还是 0 字。\n\nrest 是好的。但 rest 不能代替 facing 那个空白页。明天你还是要面对它。' },
      ],
    },
    {
      id: 'diss_aditi_writing_pact',
      minWeek: 40, maxWeek: 46,
      title: 'Aditi · "我们 90 分钟为一组写"',
      condition: ({ npcRel }) => (npcRel.aditi || 0) >= 5,
      body: 'Aditi 把笔记本砸在你 library 桌上对面。\n\n"OK. New rule. We do 90-minute Pomodoro blocks. Phones face down on the table. Whoever picks up phone first buys the next coffee. We do 4 blocks today. Yes? Yes."\n\n她已经计时 button 按下去了。',
      choices: [
        { label: '加入 + 4 个 block 全跟完', effect: { energy: -12, academic: 14, belonging: 16, npc: { aditi: 3 }, flag: 'diss_writing_pact' },
          feedback: '6 小时 / 4 个 block。中间她 surrender 了一次（你赢了）——她去 Pret 给你买了 oat latte 回来。\n\n下午 5 点你写了 2,400 字（是你最高单日纪录的 3 倍）。Aditi 写了 1,800。\n\n临走时她说："Same time tomorrow?"\n\n你点头。\n\n这之后 11 周你们每天都在 library 同一张桌子。你 dissertation 提交那天她哭了——你以为她哭你，她说"I\'m crying because I\'m not doing this with you tomorrow."' },
        { label: '"今天我状态不好 改天"', effect: { energy: -2, belonging: -3, npc: { aditi: -1 } },
          feedback: 'Aditi 笑了一下："Cool. When you\'re ready."\n\n她带着笔记本回了她自己的座位。她那天写了 2,000 字。你写了 400。\n\n她没再 invite 你第二次。你想：她 invite 是 generosity——你拒绝是放弃了一次 generosity。' },
      ],
    },
    {
      id: 'diss_word_count_dread',
      minWeek: 45, maxWeek: 47,
      title: '字数 4,524 / 15,000',
      condition: ({ flags }) => !!flags.diss_lit_review_started,
      body: 'Word 文档底部 progress bar：4,524 / 15,000 字。\n\n离 deadline 还有 5 周。\n\n你算了一下：每天必须写 300 字才能写完。但你过去一周平均一天 120 字。\n\n你的 supervisor 说 chapter 3 还需要重写。chapter 4 (analysis) 还没动。conclusion 没影。',
      choices: [
        { label: '把 outline 砍成 12,000 字（学校允许 ±10%）', effect: { energy: -3, academic: 8, stress: -5, flag: 'diss_scope_trimmed' },
          feedback: '你重新算 outline——chapter 4 从 5,000 字砍到 3,500，conclusion 从 2,000 砍到 1,500。\n\n12,000 字现在 reachable。每天 250 字就行。\n\n你给 Whitmore 邮件 confirm："tightening scope to 12,000". 他回 "Sensible. Better tight than padded."\n\n你想：原来 deadline 不是 enemy——是逼你 prioritize 的工具。' },
        { label: '"我要写完 15,000 字 死磕到底"', effect: { energy: -10, academic: 10, stress: 12, flag: 'diss_full_count' },
          feedback: '你接下来 5 周每天 300 字。有 4 天写不出来——你就在 ensuite 抄笔记。\n\n最后一周你写了 3,200 字（包括 conclusion）。15,003 字交了。\n\n你 distinction 拿了——Whitmore 说"You ground it out. Respect."\n\n但你也意识到——那 3,000 字里有 800 字是 padding。Whitmore 知道。你也知道。' },
        { label: '崩溃 + WhatsApp Aditi/Sarah', effect: { energy: -3, belonging: 8 },
          condition: ({ npcRel }) => (npcRel.aditi || 0) >= 4 || (npcRel.sarah || 0) >= 4,
          feedback: '你 voice msg 5 分钟：词不成句，主要是"我不行 / 我写不完 / 我是不是不该读这个 program"。\n\n你朋友 30 秒后回："Babe. 4500 words at week 45 is fine. You\'re panicking — write tonight\'s 200 words. Tomorrow we talk."\n\n你写了 200 字。然后睡了 8 小时。\n\n第二天 panic 没了 80%——剩下的 20% 是 "I should have started earlier" 的常态焦虑。' },
      ],
    },
    {
      id: 'diss_turnitin_panic',
      minWeek: 47, maxWeek: 49,
      title: 'Turnitin draft check · 27% similarity',
      condition: ({ flags }) => !!flags.diss_lit_review_started,
      body: '你交了 draft 给 Turnitin pre-check。\n\nSimilarity Index: **27%**.\n\nFlag distribution:\n· Literature review: 18%\n· Methodology: 6%\n· Analysis: 3%\n\n学校规定 < 20% safe，20-30% reviewed case-by-case，> 30% 警告。\n\n你看着这个 27% 心跳到 110。',
      choices: [
        { label: '逐句重新 paraphrase + 检查 quote 都 cite 了', effect: { energy: -12, academic: 8, flag: 'diss_turnitin_cleaned' },
          feedback: '你花了 2 个晚上重写 lit review——70% 直接引用改成你自己的语言 + 加 in-text citation。\n\n第二次 Turnitin: 14%. Safe.\n\n你提交终稿时回看那个第一次 27% 的截图——你想：原来 academic integrity 不是 prevent 抄袭，是 prevent 你 lazy 引用。\n\n你睡了 12 小时。' },
        { label: '提交 + 心存侥幸', effect: { energy: 0, academic: -3, flag: 'diss_turnitin_risked' },
          feedback: '你交了 27%。\n\n3 周后你的 supervisor 在 grade 时找你："Your similarity is high. I had to defend you to the panel. Most of it was unattributed lit review—you got lucky it was paraphrased close enough."\n\n你拿到 distinction——但那一刻你脸是热的。\n\n你这一刻知道：你这次没事不是因为你做对了，是因为有 Whitmore 替你说话。下次你不会再赌。' },
        { label: '给 Whitmore email 求建议', effect: { energy: -3, academic: 4 },
          feedback: 'Whitmore 30 分钟内回："27% with most in lit review is normal at first draft. Standard fix: use ProQuest\'s ChunkRewrite tool or just sit down and rewrite in your own voice. The latter takes longer but you\'ll write better the rest of the way."\n\n你选了第二个路径。改到 16%。\n\n你想：他这种立刻回邮件的细节——是你 1 年来真正学到的导师关系。' },
      ],
    },
  ],

  flat: [
    {
      id: 'diss_existential_crisis_3am',
      minWeek: 43, maxWeek: 47,
      title: '凌晨 3 点 · "这个 topic 是不是不重要"',
      condition: ({ flags }) => !!flags.diss_lit_review_started,
      body: '凌晨 3 点。你已经盯着 abstract 60 分钟。\n\n你 5 分钟前突然有一个想法："如果这个 topic 没人 care 怎么办？我写的所有 1,200 字 chapter 1 都是 nobody will read 的。"\n\n你打开 Google Scholar 搜你的 topic——上次有人 publish 是 2019 年。一篇 paper 引用了 14 次。\n\n你坐在床上抱着 Tesco 热水袋。',
      choices: [
        { label: '哭 5 分钟 + 然后睡觉', effect: { energy: -5, academic: -3, belonging: -2 },
          feedback: '你哭了 5 分钟。然后吹灯睡了。\n\n第二天醒来你想："我昨晚什么都没解决——但我也没 quit。" 你打开 Word 又写了 300 字。\n\n这就是 dissertation：不是你 confident 才写，是你 not-confident 还在写。' },
        { label: '给妈打电话（即使北京时间也很早）', effect: { energy: 3, belonging: 14 },
          feedback: '你妈接了电话——她声音哑哑的（她也刚醒）。你说"妈我觉得我写的东西没意义"。\n\n她安静 5 秒。然后说："你 5 岁画的画，妈到现在还存着。"\n\n你愣了。\n\n她说："你写什么妈不懂——但你写完是给自己看的。妈也不懂你 5 岁画的画。但你画完，妈存到现在 17 年了。"\n\n你哭了。她说："你写。不管它写什么 妈给你存着。"' },
        { label: '给 Aditi/Sarah/林楠 发消息', effect: { energy: -3, belonging: 12 },
          condition: ({ npcRel }) => (npcRel.aditi || 0) >= 4 || (npcRel.sarah || 0) >= 4 || (npcRel.linnan || 0) >= 4,
          feedback: '你发出 voice msg。3 分钟后对方 video call 你。\n\n你哭着说"我写的没人看"。ta 听完说一句让你停下来的话：\n\n"Listen. The dissertation isn\'t for the world. It\'s the most expensive thing your parents bought you—and you\'re writing the receipt. They don\'t need the receipt to be a bestseller. They need the receipt to exist."\n\n你愣了 5 秒。然后笑了。然后说"我去写了"。' },
        { label: '硬撑写到 5 点', effect: { energy: -15, academic: 5, flag: 'diss_pulled_allnighter' },
          feedback: '你写到 5 点。最后一段质量明显下滑——你回看自己写的"the cultural significance of"那段——一脸问号。\n\n你睡了 5 小时。第二天 11 点醒。然后用 30 分钟改昨晚最后那段。\n\n你想：你昨晚没解决任何 doubt——但你也用 600 字证明了 doubt 不能 stop 你。这一刻你比 Whitmore 更骄傲——他至少 65 岁了，他不知道你 22 岁第一次熬通宵的感觉。' },
      ],
    },
  ],
};
