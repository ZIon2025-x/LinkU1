// Cultural friction events — the harder side of being a Chinese international
// student in the UK. Microaggressions, "where are you really from", silent
// rejections, and the slow accumulation of being "the foreign one in the room".
//
// These are deliberately written without resolution — most of these events
// don't have a "correct" choice that erases the friction. The point is to let
// the player feel the weight, document it, and decide how to carry it.

export const CULTURE_FRICTION_EVENTS = {
  uni: [
    {
      id: 'where_really_from', minWeek: 4,
      title: '"Where are you really from?"',
      body: 'Tutorial 后茶水间。一个 50 岁英国女教授（不是你的 supervisor）跟你寒暄："Lovely accent! Where are you from?"\n\n你说 "China"。\n\n她："Oh how wonderful, but where are you really from? Like, originally?"\n\n你愣了 2 秒。',
      choices: [
        { label: '"China. I just said." 直接', effect: { energy: -3, belonging: 4, stress: 3, flag: 'pushed_back' },
          feedback: '她笑了 3 秒后改口："Right, of course. Sorry, daft question."\n\n气氛尴尬。但你想：我没有错。她问的是我"真的"从哪——好像 China 不算真的。\n\n这是你这一年第一次顶回去。' },
        { label: '解释一遍 我从北京 / 上海来的', effect: { energy: -1, stress: 2 },
          feedback: '你解释了 30 秒。她点头："Beijing! Wonderful! I went there for a conference in 1998..."\n\n你听她讲了 5 分钟。然后离开。回家路上你回放对话——她意思是好的，但她没意识到这个问题问出来对你的感受。' },
        { label: '装作没听懂 笑笑过去', effect: { energy: 1, belonging: -3, stress: 4 },
          feedback: '你说 "Oh haha, China!" 然后把话题岔开了。她也没追。\n\n但回家路上你想：我又一次假装没听懂。' },
      ],
    },
    {
      id: 'classroom_microaggression', minWeek: 8,
      title: 'Tutorial · 被 "代表中国"',
      body: 'Cultural Theory tutorial。讨论 Said 的 *Orientalism*。\n\nSarah（你的英国同学）说完一段。Tutor 转头看你："Could you give us the Chinese perspective on this?"\n\n全班 8 个人都在等你说。你是唯一的中国人。',
      choices: [
        { label: '"我不能代表 14 亿人"', effect: { energy: -5, academic: 3, belonging: 6, stress: 4, flag: 'refused_proxy' },
          feedback: '你说："I can\'t speak for all of China. I can give my own perspective—but framing it as \'the Chinese perspective\' is exactly what Said critiqued."\n\nTutor 愣了 3 秒，然后笑了："That\'s an excellent point. Let me rephrase."\n\nSarah 课后 DM 你："That was sick." 你这一刻知道——你不只是 cohort 里的中国人。你是 cohort 里说话的那个人。' },
          { label: '硬着头皮讲', effect: { energy: -8, academic: 1, belonging: -3, stress: 8 },
          feedback: '你讲了 3 分钟"中国视角"。其实是你个人的看法，但你被预设成"代表"。\n\n回家路上你想：我下次应该顶回去。但下次还会发生。' },
      ],
    },
  ],

  pub: [
    {
      id: 'pub_overheard_hostile', minWeek: 6,
      title: 'Pub 角落听到的话',
      body: '周五晚 The Crown。你点了一杯 cider，坐角落。\n\n隔壁 4 个 30 岁男人在喝啤酒。其中一个声音特别响："...all these Chinese kids buying up our universities, half of them can\'t even speak English, paid for by daddy obviously..."\n\n他没看你。但你听得清清楚楚。',
      choices: [
        { label: '装作没听见 喝完酒走', effect: { energy: -8, belonging: -8, wallet: -5, stress: 10 },
          feedback: '你 10 分钟内喝完一杯 cider，付钱走了。\n\n回家路上你大脑一直在播放那句话。你不知道你应该不应该说什么。但你也知道——4 个英国醉汉对一个外国学生，你说什么都没用。\n\n这是英国留学生不告诉父母的那种夜晚。' },
        { label: '直接问 "Sorry, are you talking about me?"', effect: { energy: -10, belonging: 5, wallet: -5, stress: 6, flag: 'confronted' },
          feedback: '4 个人转头看你 3 秒。最响那个红了脸："No no, just talking about general stuff."\n\n气氛冻住。你站起来付了钱走了——没等回应。\n\n你不知道你赢了还是输了。但你说出口了。' },
        { label: '在 CSSA 群里发吐槽', effect: { energy: -3, belonging: 2, wallet: -5, stress: 3 },
          feedback: '你打了 200 字。CSSA 群里 5 个人秒回："常事"、"我也遇到过"、"在伦敦戴耳机比较好"。\n\n你不是一个人遇到这种。但你也不知道这是该 normalize 还是该愤怒。' },
      ],
    },
  ],

  soho: [
    {
      id: 'shop_followed', minWeek: 5,
      title: 'Selfridges 化妆品柜被跟着',
      body: 'Selfridges 一楼 Tom Ford 香水柜。你拿起一瓶试了试。\n\n你余光发现一个 30 岁的店员——白人女性——一直站在你 5 米外。你换了一瓶看，她也换位置。\n\n你扭头跟她对视。她立刻笑："Just here if you need help, love!" 但她没移开位置。',
      choices: [
        { label: '直接问 "Are you actually following me?"', effect: { energy: -5, belonging: -2, stress: 5, flag: 'shop_callout' },
          feedback: '她脸僵了 1 秒："Of course not, I help all our customers."\n\n你说 "OK" 然后放下香水走了。\n\n你不能证明她在跟踪你——但你也不能不知道你的感觉。这种"plausible deniability" 是最累人的。' },
        { label: '不买了 走出 Selfridges', effect: { energy: -8, belonging: -5, wallet: -4, stress: 8 },
          feedback: '你放下香水走了。一边走你一边想：我刚才拿在手里 10 秒。她跟了我整层楼。\n\n如果我是 50 岁英国白人，她不会跟。\n\n你出门买了一杯 £4 的 Pret 站在街上喝。这种愤怒没地方放。' },
        { label: '故意试更多瓶看她反应', effect: { energy: -3, belonging: -1, stress: 6 },
          feedback: '你试了 6 瓶，每瓶都喷在试纸上闻 30 秒。她全程站着。\n\n10 分钟后你走了。一根都没买。\n\n你想：她以为我会偷。我让她站满了 10 分钟。但我没爽——我只是更累。' },
      ],
    },
  ],

  flat: [
    {
      id: 'landlord_silent_reject', minWeek: 30, maxWeek: 38,
      title: '看房 · 中介突然不回了',
      body: '你下学年想搬出 ensuite，找 private flat。\n\nRightmove 上一套 Zone 2 二居 £1,500/月，你和朋友合租正合适。你给 agent 发邮件 + 看房——agent 看你时全程笑。\n\n第二天你 reference check 提交：护照、CAS、雇主 letter（你没工作所以是 student）、保人（你妈，国内）。\n\n3 天后没回信。你 follow up——agent 说 "Sorry, the landlord went with another applicant."\n\n你查 Rightmove——房子还在 listing。',
      choices: [
        { label: '问 agent "Was it because I\'m a foreign student?"', effect: { energy: -5, belonging: -3, stress: 8, flag: 'asked_landlord' },
          feedback: 'Agent 慌："Oh no no, the landlord just preferred someone with UK guarantor. Nothing to do with you."\n\n你想：UK guarantor 是合法理由——但你妈不是。你为合法理由失去了那套房。\n\n你和合租人继续找。下一家也要 UK guarantor。再下一家也要。这是 silent rejection 的英国版本——他们不说"不要中国人"，他们说"我们要 UK guarantor"。' },
        { label: '换下一家继续找', effect: { energy: -3, stress: 5 },
          feedback: '你看了 4 套之后 google 了一个"UK guarantor service"——付 £200 fee，他们替你做担保。\n\n这是 working class 学生才用的服务。但你现在也是。' },
      ],
    },
    {
      id: 'package_misdelivered', minWeek: 6,
      title: 'Royal Mail 把名字念成 "Ching Chong"',
      body: '你下楼取一个 EMS 国际包裹。Reception 小哥拿着一个粉色单子："Hello mate, package for... uhh... Ching... Chong..."\n\n他完全在猜。你姓陈 / 王 / 林，护照拼音 Chen / Wang / Lin。\n\n他笑了笑：" Sorry mate, these names." 然后递给你。\n\n你接过包裹。',
      choices: [
        { label: '小声纠正他："It\'s Chen / Wang / Lin actually"', effect: { energy: -2, belonging: 2, stress: 2 },
          feedback: '他："Oh sorry mate. Chen. Got it." 然后他真的记住了——下次他直接说 "Mate, package for Chen!"\n\n你这一瞬间觉得——纠正一次比生气一次值。' },
        { label: '"It\'s fine" 拿了走', effect: { energy: -3, belonging: -2, stress: 4 },
          feedback: '你点头走了。回房间你想：他不是恶意。但他下次还会念错。\n\n如果我永远不纠正，我永远是 "Ching Chong"。' },
      ],
    },
  ],

  station: [
    {
      id: 'tube_seat_avoided', minWeek: 4, repeatable: true,
      title: '地铁 · 旁边的座位空着',
      body: 'Northern Line 早高峰。整车厢挤得像沙丁鱼罐头。\n\n你坐下后注意到一件事：你两边的座位——空着。其他位置都有人挤。\n\n两个人在你旁边的人看起来像是在等下一站站起来——他们没看你。',
      choices: [
        { label: '装作没注意 戴耳机', effect: { energy: -3, stress: 3 },
          feedback: '你戴耳机听音乐。一直到下车那两个座位都没人坐。\n\n你想：可能他们快下车。可能我口罩没戴好。可能是别的。\n\n但这种"可能"你这一年攒了很多。它们慢慢变成一种 ambient 的疲惫——你说不出但能感受到。' },
        { label: '把背包从旁边挪到腿上 拍空座位', effect: { energy: -2, belonging: -1, stress: 1 },
          feedback: '你拍了拍旁边的位置——意思"这是空的"。一个 50 岁印度大叔走过来坐下了。"Cheers, mate." 你点头。\n\n这是一个小小的反抗——不是对那两个英国人，是对你自己脑子里"也许是我多想"的那个声音。' },
      ],
    },
  ],
};
