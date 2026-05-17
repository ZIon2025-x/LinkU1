// Pret / 类似店点餐听力 minigame —— 5 句对话/套,有 4 套不同 setting 避免重复。
//
// **马赛克机制**:每句 staff 文本里有 maskable[] 标记的关键词。渲染时按 maskRate
// 随机决定哪些被打码。
//   maskRate = clamp(60 - week × 3 - playCount × 8, 0, 60)
//   · W1 / 0 plays → 60%
//   · W6 / 1 play → 34%
//   · W12 / 2 plays → 8%
//   · W20+ or 3+ plays → 0%
//
// 抽题:按 plays 顺序(1st play → pret_basic,2nd → costa_morning,...),循环。

// ── 4 套对话场景 ──
export const PRET_SETS = [
  {
    id: 'pret_basic',
    setting: 'Pret a Manger · 中午 12:30',
    intro: '中午 12:30 的 Pret。后面排了 6 个英国人，他们都很赶时间。\n\n店员看着你："What can I get you, love?"',
    questions: [
      {
        staff: '"What can I get you, love?"',
        maskable: ['get you', 'love'],
        options: [
          { text: 'A flat white please', correct: true, feedback: '"Lovely, anything else?"' },
          { text: 'Yes', correct: false, feedback: '店员愣了一下："...yes what?"' },
          { text: "I don't know", correct: false, feedback: '店员忍住没翻白眼。' },
        ],
      },
      {
        staff: '"For here or takeaway?"',
        maskable: ['For here', 'takeaway'],
        options: [
          { text: 'Takeaway please', correct: true, feedback: '"Cool."' },
          { text: '"For here please" 但你其实想外带', correct: false, feedback: '你不敢改口。最后捧着杯子站着喝完了。' },
          { text: '"Both?"', correct: false, feedback: '店员笑了："Choose one, love."' },
        ],
      },
      {
        staff: '"That\'ll be 4.85, please. Cash or card?"',
        maskable: ['4.85', 'Cash or card'],
        options: [
          { text: '递卡', correct: true, feedback: '"Tap or insert?"' },
          { text: '"Card... I think?"', correct: false, feedback: '店员等了 5 秒。后面的人开始翻白眼。' },
          { text: '掏出现金', correct: false, feedback: '店员说"Sorry love, we\'re cashless." 你拿着 £20 现金愣住。' },
        ],
      },
      {
        staff: '"Would you like a paper bag? It\'s 10p."',
        maskable: ['paper bag', '10p'],
        options: [
          { text: '"No thanks"', correct: true, feedback: '"Cheers."' },
          { text: '点头但没说话', correct: false, feedback: '店员看着你："...is that a yes or a no?"' },
          { text: '"What does that mean?"', correct: false, feedback: '店员耐心解释了 30 秒。后面排队的人脸都黑了。' },
        ],
      },
      {
        staff: '"Have a lovely day!"',
        maskable: ['lovely day'],
        options: [
          { text: '"You too!"', correct: true, feedback: '你接住了。这是你今天最自然的英语对话。' },
          { text: '"Thanks"', correct: false, feedback: '没错但缺了点温度。' },
          { text: '"Same to you!"', correct: false, feedback: '"Same to you" 也行，但有点僵。' },
        ],
      },
    ],
  },
  {
    id: 'costa_morning',
    setting: 'Costa Coffee · 早 9 点',
    intro: '周二早 9:15 Costa Liverpool St。你之前 6 个月只点 Pret——这是你第一次进 Costa。\n\n柜员是个 50 岁波兰大姐:"Morning love. What you having?"',
    questions: [
      {
        staff: '"Morning love. What you having?"',
        maskable: ['Morning', 'having'],
        options: [
          { text: 'A latte please, medium', correct: true, feedback: '"Sit down or take it with you?"' },
          { text: 'Coffee', correct: false, feedback: '她笑:"Be more specific darling, we got 30 types."' },
          { text: 'I want something hot', correct: false, feedback: '她眨眼:"Tea, coffee, hot choc — narrow it down love."' },
        ],
      },
      {
        staff: '"Any syrups? Vanilla, caramel, hazelnut?"',
        maskable: ['syrups', 'Vanilla', 'caramel', 'hazelnut'],
        options: [
          { text: 'No syrups, just plain', correct: true, feedback: '"Sorted."' },
          { text: '"What does syrups mean?"', correct: false, feedback: '她耐心解释。但 Costa 跟你这一刻起就有了点 awkward。' },
          { text: 'Yes all three', correct: false, feedback: '你拿到一杯液体糖。喝一口就扔了。£4.20 没了。' },
        ],
      },
      {
        staff: '"That\'s 3.95. Got a Costa Club card?"',
        maskable: ['3.95', 'Costa Club card'],
        options: [
          { text: 'No, but I can sign up?', correct: true, feedback: '"Quick QR scan. You get a free coffee every 9 purchases."' },
          { text: '"Coast Club?"', correct: false, feedback: '她重复了 3 次。你最后给了卡走人。' },
          { text: '把 Tesco Clubcard 递过去', correct: false, feedback: '她翻白眼:"That\'s Tesco love. Different shop."' },
        ],
      },
      {
        staff: '"Want oat or whole?"',
        maskable: ['oat', 'whole'],
        options: [
          { text: 'Oat please', correct: true, feedback: '+30p 但你做出了 cosmopolitan 中国人样。' },
          { text: '"...哪个免费?"', correct: false, feedback: '她笑:"Whole is free love, oat\'s 30p extra."' },
          { text: '"Both?"', correct: false, feedback: '她端着两杯奶犹豫:"...you sure?"' },
        ],
      },
      {
        staff: '"Cheers darling. Take care."',
        maskable: ['darling', 'Take care'],
        options: [
          { text: '"Thanks, you too!"', correct: true, feedback: '你笑着出门。这种 micro warmth 是英国 50+ working class 才能给的温度。' },
          { text: '"Bye"', correct: false, feedback: '中规中矩,但她下次不会记得你。' },
          { text: '什么都没说', correct: false, feedback: '门关上时她还在等你回话。你已经走出 3 米。' },
        ],
      },
    ],
  },
  {
    id: 'pub_order',
    setting: 'The Crown · 周五晚',
    intro: '周五晚 9 点。The Crown 吧台。你已经站在那 3 分钟,bartender 终于看到你:"What can I get ya?"\n\n旁边一个英国大叔在等你下决心。',
    questions: [
      {
        staff: '"What can I get ya, mate?"',
        maskable: ['can I get'],
        options: [
          { text: 'A pint of lager please', correct: true, feedback: '"Carling or Heineken?"' },
          { text: 'Beer', correct: false, feedback: '他笑:"Yeah... which one mate? We got 14 taps."' },
          { text: 'Whatever\'s cheapest', correct: false, feedback: '他给你一杯 Carling 最便宜的。"You\'ll learn." 旁边大叔笑了。' },
        ],
      },
      {
        staff: '"That\'ll be 5.80. Want to start a tab?"',
        maskable: ['5.80', 'tab'],
        options: [
          { text: 'No, just this one thanks', correct: true, feedback: '"Card it is."' },
          { text: '"What\'s a tab?"', correct: false, feedback: '他耐心解释 1 分钟。后面排队的人开始 sigh。' },
          { text: 'Yes please', correct: false, feedback: '他留你的卡。你忘了 2 小时——账单 £42 + 一个朋友帮你结清。' },
        ],
      },
      {
        staff: '"Cheers. Crisps? Pork scratchings?"',
        maskable: ['Crisps', 'Pork scratchings'],
        options: [
          { text: 'Just crisps thanks, salt & vinegar', correct: true, feedback: '"Top one."' },
          { text: '"What\'s scratchings?"', correct: false, feedback: '他笑:"Fried pig skin mate. Trust me, try once." 你勉强吃了一口。' },
          { text: 'No thanks', correct: false, feedback: '中规中矩。但你错过了 UK pub default 配套。' },
        ],
      },
      {
        staff: '"You here for the match? England vs Wales, kick-off 8."',
        maskable: ['match', 'kick-off'],
        options: [
          { text: 'Just for a drink, but I\'ll watch a bit', correct: true, feedback: '"Sit by the screen mate, we\'ll all be there."' },
          { text: '"What match?"', correct: false, feedback: '他眨眼:"Mate. Wales. Tonight. England. You\'re in England."' },
          { text: '"I don\'t like football"', correct: false, feedback: '他 nod 但表情冷了 0.5 秒。Pub 周五晚是 collective sport,你 opt out 等于 opt out 整个 vibe。' },
        ],
      },
      {
        staff: '"Last orders in 10 minutes, mate."',
        maskable: ['Last orders', '10 minutes'],
        options: [
          { text: '"All good thanks, I\'m heading off"', correct: true, feedback: '他 nod:"Stay safe out there." 你笑着出门。' },
          { text: '"What\'s last orders mean?"', correct: false, feedback: '他笑:"Bar closes in 10 mate. UK rules."' },
          { text: '"Can I have another?"', correct: false, feedback: '+1 pint £5.80。但他给你 Carling 而不是你点的 Heineken。' },
        ],
      },
    ],
  },
  {
    id: 'wagamama_first',
    setting: 'Wagamama · 周六晚',
    intro: '周六晚 7 点。Wagamama Tottenham Court Road。服务员小哥放下 menu:"Have you been here before?"\n\n这是你第一次。',
    questions: [
      {
        staff: '"Have you been here before?"',
        maskable: ['been here before'],
        options: [
          { text: '"No, first time"', correct: true, feedback: '"Cool. So we serve everything as it\'s ready, not all together. Cool?"' },
          { text: '"Yes" (装老练)', correct: false, feedback: '他 nod 不解释。你结果 5 分钟后菜先来再上汤——你以为是错的,其实正常。' },
          { text: '"Where is here?"', correct: false, feedback: '他笑:"...Wagamama, mate. The restaurant."' },
        ],
      },
      {
        staff: '"Any allergies or dietary requirements?"',
        maskable: ['allergies', 'dietary requirements'],
        options: [
          { text: '"No, all good"', correct: true, feedback: '"Brilliant, what can I get you started with?"' },
          { text: '"What\'s requirements?"', correct: false, feedback: '他耐心解释。你勉强答 "no"。' },
          { text: '"I\'m allergic to MSG"', correct: false, feedback: '他眨眼:"Mate, MSG is in basically everything here. You sure?" 你尴尬改 "no actually I\'m fine"。' },
        ],
      },
      {
        staff: '"Chicken katsu curry or yaki udon — both popular tonight."',
        maskable: ['katsu curry', 'yaki udon'],
        options: [
          { text: 'Chicken katsu please', correct: true, feedback: '"Solid choice. Rice or with the side salad?"' },
          { text: '"What\'s yaki udon?"', correct: false, feedback: '他详细解释 30 秒。后面有人在等。' },
          { text: '"Both"', correct: false, feedback: '他笑:"You hungry mate? OK, £24."' },
        ],
      },
      {
        staff: '"To drink? Tap water\'s free."',
        maskable: ['Tap water'],
        options: [
          { text: 'Tap water please', correct: true, feedback: '"Sorted. Lemon or no lemon?"' },
          { text: '"Bottle water"', correct: false, feedback: '他笑:"That\'s 3 quid. Tap is free and same thing." 你改 tap。' },
          { text: '"What does tap mean?"', correct: false, feedback: '他指水龙头:"That. From the wall. Free."' },
        ],
      },
      {
        staff: '"Service is discretionary — 12.5% added if you\'re happy with us."',
        maskable: ['discretionary', '12.5%'],
        options: [
          { text: '"Yeah keep the service charge"', correct: true, feedback: '"Cheers, that\'s appreciated."' },
          { text: '"What does discretionary mean?"', correct: false, feedback: '他解释:"You can take it off if you want — it\'s not mandatory." 你保留了。' },
          { text: '让他拿掉 service charge', correct: false, feedback: '他 nod:"No worries." 但你心里有点不安——UK 餐厅小费默认 12.5% 你拿掉 = 你嫌服务差,这个 signal 强烈。' },
        ],
      },
    ],
  },
];

// 兼容旧代码 — 把第一套作为 default PRET_QUESTIONS 导出
export const PRET_QUESTIONS = PRET_SETS[0].questions;

/**
 * 按玩家进度选一套 Pret 对话:plays 0 → set 0,plays 1 → set 1...循环。
 */
export function pickPretSet(playsCount) {
  return PRET_SETS[playsCount % PRET_SETS.length];
}

/**
 * 计算当前听力 mask 率(0-60%)。
 *   maskRate = clamp(60 − week × 3 − plays × 8, 0, 60)
 */
export function pretMaskRate(week, plays) {
  const rate = 60 - (week || 1) * 3 - (plays || 0) * 8;
  return Math.max(0, Math.min(60, rate));
}

// ========================================
// 迷你游戏：写论文（句子选择）
// ========================================

// 写论文段落填空 · 15 puzzles · phase 1-3 难度递增
// phase 1 (W2-15) base 题型,正确答案显眼,distractor 错误模式 obvious
// phase 2 (W16-30) 中等,distractor 包括"看似对但有 small flaw"
// phase 3 (W30+) 高难度,有 2 个 plausible distractor,需细分析

export const ESSAY_PUZZLES = [
  // ════ Phase 1 · W2-15 ════
  { phase: 1, context: '论文段落 · 引言',
    paragraph: 'This dissertation examines the experience of Chinese international students in the UK. ___ Drawing on qualitative interviews, it argues that belonging is not a static state but a continuous negotiation.',
    options: [
      { text: 'Specifically, it focuses on how identity is negotiated in cross-cultural settings.', correct: true,
        feedback: '✓ 精确连接"主题"和"方法"。Whitmore："Excellent transition."' },
      { text: 'I interviewed many people for this paper.', correct: false,
        feedback: '✗ 太口语,"I" 学术写作要慎用。Whitmore："Avoid first person."' },
      { text: 'Chinese students are very interesting to study.', correct: false,
        feedback: '✗ 太宽泛,缺乏论点。Whitmore："What is your argument?"' },
      { text: 'In this essay, I will discuss many things.', correct: false,
        feedback: '✗ "discuss many things" = 没有焦点。大一新生写法。' },
    ],
  },
  { phase: 1, context: '论文段落 · 文献综述',
    paragraph: 'Bourdieu\'s concept of habitus has been widely used in studies of migration. ___ However, recent scholarship has questioned its applicability to digitally connected migrants.',
    options: [
      { text: 'It captures how dispositions are shaped by social structures.', correct: true,
        feedback: '✓ 一句话精准定义概念,再引出反驳。研究生水平。' },
      { text: 'Many people have written about it.', correct: false,
        feedback: '✗ 完全空洞。' },
      { text: 'It\'s a complicated theory.', correct: false,
        feedback: '✗ "complicated" 是描述,不是论证。' },
      { text: 'Bourdieu was a French sociologist.', correct: false,
        feedback: '✗ 这是百科信息,不是文献综述。' },
    ],
  },
  { phase: 1, context: '论文段落 · 引言 · thesis statement',
    paragraph: 'The Covid-19 pandemic accelerated digital migration for many displaced populations. ___ This dissertation interrogates how that acceleration reshaped diasporic intimacy.',
    options: [
      { text: 'Yet the implications for emotional life have received less attention.', correct: true,
        feedback: '✓ 标准 "research gap → contribution" 模板。' },
      { text: 'A lot of papers say this.', correct: false,
        feedback: '✗ "A lot of papers" 0 citation 价值。' },
      { text: 'Covid was bad for everyone.', correct: false,
        feedback: '✗ 太通俗 + 没 specific 论点。' },
      { text: 'I will now discuss this important topic.', correct: false,
        feedback: '✗ "I will discuss" 是大一写法。学术写作直接 state,不预告。' },
    ],
  },
  { phase: 1, context: '论文段落 · 方法',
    paragraph: 'I conducted 18 semi-structured interviews with international students in London. ___ Interviews lasted 60-90 minutes and were transcribed verbatim.',
    options: [
      { text: 'Participants were recruited through purposive sampling from three universities.', correct: true,
        feedback: '✓ 标准 methodology · who + how recruited 全交代。' },
      { text: 'I talked to many people.', correct: false,
        feedback: '✗ 0 method detail · reviewer 直接打回。' },
      { text: 'It was easy to find people to talk to.', correct: false,
        feedback: '✗ 主观评价 + 没 method。' },
      { text: 'Many universities have international students.', correct: false,
        feedback: '✗ 跟 method 无关的 obvious statement。' },
    ],
  },
  { phase: 1, context: '论文段落 · 段间过渡',
    paragraph: 'The previous section examined how language shapes belonging. ___ In contrast, the next section turns to embodied practices.',
    options: [
      { text: 'But linguistic identity is only one register of cross-cultural experience.', correct: true,
        feedback: '✓ 总结上段 + 桥接下段,经典 academic transition。' },
      { text: 'Now I will talk about something else.', correct: false,
        feedback: '✗ 太机械,缺 substance。' },
      { text: 'Language is important.', correct: false,
        feedback: '✗ 重复 + 没桥接。' },
      { text: 'The next section is about bodies.', correct: false,
        feedback: '✗ 直白预告,缺概念连接。' },
    ],
  },
  { phase: 1, context: '论文段落 · 结论',
    paragraph: 'These findings suggest that the experience of "异乡" cannot be reduced to a binary of integration or alienation. ___ Future research might explore how this in-between state is articulated across different generations of migrants.',
    options: [
      { text: 'It is, rather, a continually shifting affective terrain.', correct: true,
        feedback: '✓ 优雅,核心概念升华了。Whitmore："This is the sentence the whole thesis was building toward."' },
      { text: 'It is more complex than that.', correct: false,
        feedback: '✗ "more complex" 太懒——具体怎么 complex?' },
      { text: 'Therefore, I am right.', correct: false,
        feedback: '✗ 学术写作不要这么"赢"。' },
      { text: 'In conclusion, China is far away.', correct: false,
        feedback: '✗ 既不准确也不学术。' },
    ],
  },

  // ════ Phase 2 · W16-30 (5 puzzles, distractor 更狡猾) ════
  { phase: 2, context: '论文段落 · 文献综述 · 关键 nuance',
    paragraph: 'Hall\'s influential model of encoding/decoding has been read as a media-centric framework. ___ A re-reading of Hall in light of diasporic experience reveals the model\'s political ambition.',
    options: [
      { text: 'However, such readings underestimate its commitment to oppositional reading.', correct: true,
        feedback: '✓ 精准:identify problem (under-read) + signal contribution (re-reading)。' },
      { text: 'Hall\'s work is sometimes seen as outdated by modern media scholars.', correct: false,
        feedback: '⚠ "sometimes seen as" 是 unverified hedge,缺 citation 价值。读起来像 plausible 但不是 argument。' },
      { text: 'The encoding/decoding model has 4 stages: production, circulation, distribution and reproduction.', correct: false,
        feedback: '✗ 教科书叙述,不是 critique 或 contribution。' },
      { text: 'Many scholars cite Hall but few read him carefully.', correct: false,
        feedback: '⚠ 听起来 spicy 但 0 substance + 没 sourced。' },
    ],
  },
  { phase: 2, context: '论文段落 · 方法 · ethics',
    paragraph: 'Conducting interviews with participants who share my ethnicity raised methodological questions. ___ This positionality, however, did not grant unmediated access to "authentic" experience.',
    options: [
      { text: 'As an "insider" researcher, I had to negotiate the dual risks of overidentification and projected expectations.', correct: true,
        feedback: '✓ 标准 reflexive methodology section,识别 risk 同时 nuance 它。' },
      { text: 'Being Chinese made it easier to recruit Chinese participants.', correct: false,
        feedback: '⚠ True 但只 captures convenience,没回答 ethical question。Phase 1 答案 不是 Phase 2 标准。' },
      { text: 'My ethnicity gave me a unique advantage in this research.', correct: false,
        feedback: '⚠ 听起来 OK 但 "unique advantage" 是 unreflective claim,正是 methodology section 要 problematise 的。' },
      { text: 'Insider research is generally considered more reliable.', correct: false,
        feedback: '✗ Wrong + 没 citation。Insider research 在 methodology 文献里 highly contested。' },
    ],
  },
  { phase: 2, context: '论文段落 · 发现 · 引用 participant',
    paragraph: 'Lin (24, Year 1 MSc) described her relationship to her hometown as "loose but pulling." ___ She did not narrate her diasporic experience as loss but as a tension she carried.',
    options: [
      { text: 'This metaphor resists the loss/gain binary that dominates much migration literature.', correct: true,
        feedback: '✓ 把 participant 原话连到 theoretical contribution,这是 qualitative analysis 的精华。' },
      { text: 'This shows that Chinese students often feel torn between two worlds.', correct: false,
        feedback: '⚠ 落入 cliché ("torn between two worlds") · participant 明确说不是 loss。' },
      { text: 'Lin\'s quote illustrates the difficulty of cross-cultural adaptation.', correct: false,
        feedback: '⚠ 听起来 generic neutral 但 "difficulty of adaptation" 已经 frame 成 problem · participant 没这么 said。' },
      { text: 'Lin was very articulate in her interview.', correct: false,
        feedback: '✗ Praise of participant ≠ analysis。' },
    ],
  },
  { phase: 2, context: '论文段落 · 讨论 · counter-argument',
    paragraph: 'Critics might object that my sample of 18 cannot speak for "Chinese international students" as a category. ___ Rather, it traces the contours of a particular experiential register.',
    options: [
      { text: 'This objection presumes that representativeness is the goal of qualitative research, which this study explicitly rejects.', correct: true,
        feedback: '✓ Reframe critic\'s premise,这是 mature scholarly move。' },
      { text: 'My sample is actually quite representative because it covers multiple universities.', correct: false,
        feedback: '⚠ Defends ground critic 站的,等于接受了 representativeness 是 goal。' },
      { text: 'I conducted 18 interviews, which is the standard for qualitative research.', correct: false,
        feedback: '⚠ 18 is in range but defensive answer + 没 reframe argument。' },
      { text: 'Future research could include more participants.', correct: false,
        feedback: '✗ Concedes 太多,不是 discussion 该说的。Discussion 应该 stand by your method。' },
    ],
  },
  { phase: 2, context: '论文段落 · 结论 · contribution claim',
    paragraph: 'This study contributes to the literature in three ways. ___ Second, it foregrounds digital practices as integral to diasporic intimacy. Third, it offers "异乡" as a conceptual resource beyond English-language scholarship.',
    options: [
      { text: 'First, it complicates the integration/alienation binary by attending to in-between affective states.', correct: true,
        feedback: '✓ 标准 contribution structure · concrete + builds on lit review identified gap。' },
      { text: 'First, it shows that Chinese students have unique experiences.', correct: false,
        feedback: '⚠ Vague "unique experiences" 是 cliché,不算 contribution。' },
      { text: 'First, it confirms what many scholars have argued.', correct: false,
        feedback: '⚠ "confirms" 不是 contribution · 论文要 add 不是 echo。' },
      { text: 'First, it uses qualitative methods.', correct: false,
        feedback: '✗ Method is not contribution.' },
    ],
  },

  // ════ Phase 3 · W30+ (4 puzzles, 2 plausible distractor) ════
  { phase: 3, context: '论文段落 · 引言 · stake 升级',
    paragraph: 'In the year that Brexit reshaped immigration controls and Covid-19 closed borders, the experience of being "异乡" for Chinese students in London took on new urgency. ___ Yet existing scholarship has been slow to engage with these reconfigurations.',
    options: [
      { text: 'These overlapping ruptures rendered familiar concepts—belonging, mobility, return—unstable in newly visible ways.', correct: true,
        feedback: '✓ 把两个 event "rupture" 起来,识别 conceptual instability · highest tier argument。' },
      { text: 'Brexit and Covid-19 both affected international students significantly.', correct: false,
        feedback: '⚠ True statement,但只是 fact-level,没 frame conceptual stake。Phase 3 reviewer 要 conceptual。' },
      { text: 'The intersection of Brexit and Covid-19 was an unprecedented context for migration research.', correct: false,
        feedback: '⚠ "Unprecedented" 是 overused word + 没 specify what the intersection actually produced。' },
      { text: 'Chinese students faced many challenges during this period.', correct: false,
        feedback: '✗ Reverts to generic. Phase 3 不接受 generic。' },
    ],
  },
  { phase: 3, context: '论文段落 · 文献综述 · 高级 critique',
    paragraph: 'Cultural studies frameworks have long emphasised resistance and oppositional reading (Hall 1980; Fiske 1989). ___ Recent affect-theoretical approaches (Berlant 2011; Stewart 2007) trouble this emphasis.',
    options: [
      { text: 'Yet this framing tends to presuppose a sovereign subject capable of acts of resistance, an assumption that affect theory destabilises.', correct: true,
        feedback: '✓ Identify hidden assumption + name the destabilising move + cite. PhD 级写法。' },
      { text: 'However, these frameworks have been criticised for being too theoretical.', correct: false,
        feedback: '⚠ "too theoretical" 在 cultural studies 是空洞批评 + 没 cite。' },
      { text: 'Affect theory provides an alternative framework focused on bodily feelings.', correct: false,
        feedback: '⚠ Definition-level statement,不是 critique。又错 - affect theory ≠ "bodily feelings"。' },
      { text: 'Hall and Fiske did important work but their approaches have limitations.', correct: false,
        feedback: '✗ Bland concession 不是 critique。' },
    ],
  },
  { phase: 3, context: '论文段落 · 方法 · 高级 reflexivity',
    paragraph: 'Throughout this research, I have resisted the role of the "native informant" that institutional contexts often confer on minority scholars. ___ My account is therefore neither inside nor outside, but constitutively partial.',
    options: [
      { text: 'To do so requires recognising that "insider knowledge" can itself be a form of disciplinary capture.', correct: true,
        feedback: '✓ Foucault + Spivak 移植到 methodology,博士级 nuance。' },
      { text: 'This role can be problematic because it essentialises minority researchers.', correct: false,
        feedback: '⚠ True 但 missing the second-order point about disciplinary capture · 只是 first-level critique。' },
      { text: 'Refusing the native informant role allowed me to maintain critical distance.', correct: false,
        feedback: '⚠ Plausible 但 reverts to "critical distance" cliché · 实际上 author 拒绝的就是这种 inside/outside binary。' },
      { text: 'Many minority scholars face this expectation in academic settings.', correct: false,
        feedback: '✗ Descriptive,不是 reflexive analysis。' },
    ],
  },
  { phase: 3, context: '论文段落 · 结论 · 政治 implications',
    paragraph: 'The "异乡" I have traced is not a private psychological state but a political condition. ___ If this is right, then policy debates about international student integration are looking in the wrong place.',
    options: [
      { text: 'It is shaped by, and produces, infrastructures of visa regimes, language testing, and racialised hospitality.', correct: true,
        feedback: '✓ 标准 political-conceptual move · concrete infrastructures + 把 affect 跟 policy 连起来。' },
      { text: 'It connects to broader social and political forces.', correct: false,
        feedback: '⚠ True 但 vague abstractions,Phase 3 不接受。' },
      { text: 'Government policies have a significant impact on student experiences.', correct: false,
        feedback: '⚠ Obvious + descriptive · 不是 conceptual claim。' },
      { text: 'Students should organise to advocate for their rights.', correct: false,
        feedback: '✗ Activism note 不是 dissertation conclusion 该说的。' },
    ],
  },
];

/**
 * 按周抽 essay puzzle。phase 1 / 2 / 3 池子各抽 1-3 个。
 * 玩家每次玩抽 3 个 puzzle (跟原本一致),phase 池按 week 决定。
 */
export function pickEssayPuzzles(week, seenPuzzleIndices = []) {
  let phase;
  if (week <= 15) phase = 1;
  else if (week <= 30) phase = 2;
  else phase = 3;
  // 抽该 phase 内未见过的;若 phase 池都见过,降级回 phase 池 random
  const phasePool = ESSAY_PUZZLES
    .map((p, i) => ({ ...p, _idx: i }))
    .filter(p => p.phase === phase);
  const unseen = phasePool.filter(p => !seenPuzzleIndices.includes(p._idx));
  const pool = unseen.length >= 3 ? unseen : phasePool;
  // 洗牌后取 3
  const shuffled = [...pool].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, 3);
}

// ========================================
// 迷你游戏：理论家概念匹配
// ========================================

// ============================================================
// UK 留学硬核知识 Match —— 取代 THEORIST_MATCH（内容方向 pivot, spec 2026-05-16）
// 数据结构同构 THEORIST_MATCH:
//   { categories: [{ id, name, items: [id...] }], items: { id: { label, desc } } }
// 18 categories × 6-8 items = ~110 items 总池。每 item 唯一归属一个 category。
// ============================================================
export const UK_KNOWLEDGE_MATCH = {
  categories: [
    { id: 'visa',                 name: '签证 / Visa',
      items: ['tier4','brp','nhs_surcharge','psw','right_to_rent','biometrics'] },
    { id: 'nhs',                  name: 'NHS 看病',
      items: ['gp','phone_111','phone_999','ae','walk_in','prescription'] },
    { id: 'council_tax',          name: 'Council Tax 房费',
      items: ['exempt_cert','council_band','single_occupancy','tv_license','billing_period'] },
    { id: 'academic_integrity',   name: '学术诚信',
      items: ['turnitin','paraphrase','similarity_score','harvard_cite','apa_cite','mitigating_circ'] },
    { id: 'banking',              name: '银行 / 财务',
      items: ['sort_code','overdraft','direct_debit','standing_order','isa','contactless'] },
    { id: 'renting',              name: '租房',
      items: ['holding_deposit','break_clause','epc_rating','inventory','deposit_protection','guarantor'] },
    { id: 'tax_wages',            name: '税 / 工资',
      items: ['hmrc','ni_number','paye','p45','p60','min_wage'] },
    { id: 'academic_writing',     name: '学术写作',
      items: ['footnote','bibliography','abstract','in_text_cite','word_count','cover_sheet'] },
    { id: 'transport',            name: '交通 / 出行',
      items: ['oyster','railcard','railcard_1625','coach','tfl','national_rail'] },
    { id: 'campus_systems',       name: '校园系统',
      items: ['moodle','eduroam','library_card','nus_card','reading_week','welcome_week'] },
    { id: 'job_hunt',             name: '求职 / 实习',
      items: ['cv_uk','cover_letter','sandwich_placement','milkround','grad_scheme','assessment_centre'] },
    { id: 'saving_money',         name: '省钱 / 日常',
      items: ['meal_deal','clubcard','yellow_sticker','spoons_app','boots_advantage','nectar_card'] },
    { id: 'degrees',              name: '学位 / 学制',
      items: ['undergrad','pgt','pgr','phd','msc','ma','mba','foundation_year'] },
    { id: 'grading',              name: '成绩 / 评分',
      items: ['first_class','two_one','two_two','third_class','distinction','merit','pass_threshold'] },
    { id: 'class_types',          name: '课程类型',
      items: ['lecture_class','seminar','tutorial','lab','workshop','office_hours'] },
    { id: 'assessment',           name: '评估方式',
      items: ['coursework','dissertation','viva','open_book','take_home','group_project'] },
    { id: 'online_tools',         name: '网课 / 数字工具',
      items: ['zoom','ms_teams','panopto','blackboard','padlet','mentimeter'] },
    { id: 'uni_groupings',        name: '大学集团 / 排名',
      items: ['russell_group','red_brick','plate_glass','ancient_unis','oxbridge','qs_top100'] },
  ],
  items: {
    // visa
    tier4:            { label: 'Tier 4',            desc: '学生签证（现称 Student Route）' },
    brp:              { label: 'BRP',               desc: '生物指纹居留卡' },
    nhs_surcharge:    { label: 'NHS Surcharge',     desc: '签证医疗附加费（学生 £776/年）' },
    psw:              { label: 'PSW Visa',          desc: '毕业生工作签证（2 年）' },
    right_to_rent:    { label: 'Right to Rent',     desc: '房东必须查的身份资格' },
    biometrics:       { label: 'Biometrics',        desc: '签证生物识别采集（指纹+脸）' },
    // nhs
    gp:               { label: 'GP',                desc: '家庭医生（看病第一站）' },
    phone_111:        { label: '111',               desc: '非紧急医疗咨询电话' },
    phone_999:        { label: '999',               desc: '紧急救护车 / 火警 / 警察' },
    ae:               { label: 'A&E',               desc: '急诊（Accident & Emergency）' },
    walk_in:          { label: 'Walk-in Centre',    desc: '无预约门诊' },
    prescription:     { label: 'Prescription',      desc: '处方（学生通常免费或 £9.90）' },
    // council_tax
    exempt_cert:      { label: 'Exempt Certificate',desc: '学生身份豁免证明' },
    council_band:     { label: 'Council Tax Band',  desc: '房产税阶 A-H（按房屋估值）' },
    single_occupancy: { label: 'Single Occupancy',  desc: '单人居住 25% 折扣' },
    tv_license:       { label: 'TV License',        desc: '电视收看许可（£169.50/年）' },
    billing_period:   { label: 'Billing Period',    desc: '账单周期（4 月起，全年 10/12 期）' },
    // academic_integrity
    turnitin:         { label: 'Turnitin',          desc: '论文查重系统' },
    paraphrase:       { label: 'Paraphrase',        desc: '改写他人观点（不抄袭）' },
    similarity_score: { label: 'Similarity Score',  desc: '查重相似率（通常 <20% 安全）' },
    harvard_cite:     { label: 'Harvard Style',     desc: '哈佛引文格式（人文社科常用）' },
    apa_cite:         { label: 'APA Style',         desc: 'APA 引文格式（心理 / 教育常用）' },
    mitigating_circ:  { label: 'Mitigating Circumstances', desc: '情有可原申诉（病假 / 家庭事故）' },
    // banking
    sort_code:        { label: 'Sort Code',         desc: '6 位分行识别码（XX-XX-XX）' },
    overdraft:        { label: 'Overdraft',         desc: '透支额度（学生账户常 £1000 无息）' },
    direct_debit:     { label: 'Direct Debit',      desc: '银行代扣（账单类，金额浮动）' },
    standing_order:   { label: 'Standing Order',    desc: '固定金额定期转账（房租类）' },
    isa:              { label: 'ISA',               desc: '免税储蓄账户（年度额度 £20,000）' },
    contactless:      { label: 'Contactless',       desc: '非接触支付（≤£100/单）' },
    // renting
    holding_deposit:  { label: 'Holding Deposit',   desc: '锁房定金（1 周房租，可退）' },
    break_clause:     { label: 'Break Clause',      desc: '中途解约条款（通常 6 个月固定后）' },
    epc_rating:       { label: 'EPC Rating',        desc: '房屋能效评级（A-G，越前越省电费）' },
    inventory:        { label: 'Inventory',         desc: '入住物品清单 + 拍照记录' },
    deposit_protection:{label: 'Deposit Protection (DPS)', desc: '押金第三方托管' },
    guarantor:        { label: 'Guarantor',         desc: '担保人（国际生常用 Housing Hand）' },
    // tax_wages
    hmrc:             { label: 'HMRC',              desc: '英国税务海关总署' },
    ni_number:        { label: 'NI Number',         desc: '社保号（合法工作必须）' },
    paye:             { label: 'PAYE',              desc: '雇主代扣个税（不用自己报税）' },
    p45:              { label: 'P45',               desc: '离职单（带到下家用）' },
    p60:              { label: 'P60',               desc: '年度纳税总单（4 月发）' },
    min_wage:         { label: 'Minimum Wage',      desc: '国家最低工资（£11.44/h, 21+, 2024）' },
    // academic_writing
    footnote:         { label: 'Footnote',          desc: '脚注（页面底部小字）' },
    bibliography:     { label: 'Bibliography',      desc: '参考文献列表（论文最后）' },
    abstract:         { label: 'Abstract',          desc: '论文摘要（150-300 词）' },
    in_text_cite:     { label: 'In-text Citation',  desc: '正文内引用（如 Smith, 2020）' },
    word_count:       { label: 'Word Count',        desc: '字数限制（通常 ±10% 浮动）' },
    cover_sheet:      { label: 'Cover Sheet',       desc: '论文封面页（题目/学号/字数）' },
    // transport
    oyster:           { label: 'Oyster Card',       desc: '伦敦交通刷卡' },
    railcard:         { label: 'Railcard',          desc: '火车通用 1/3 折扣卡（£30/年）' },
    railcard_1625:    { label: '16-25 Railcard',    desc: '25 岁以下专属火车折扣卡' },
    coach:            { label: 'Coach',             desc: '长途巴士（Megabus / National Express）' },
    tfl:              { label: 'TfL',               desc: '伦敦交通局' },
    national_rail:    { label: 'National Rail',     desc: '全国铁路网' },
    // campus_systems
    moodle:           { label: 'Moodle',            desc: '最主流 LMS' },
    eduroam:          { label: 'Eduroam',           desc: '国际通用校园 WiFi（全球可用）' },
    library_card:     { label: 'Library Card',      desc: '图书馆借书卡' },
    nus_card:         { label: 'TOTUM (NUS)',       desc: '学生折扣卡（餐饮 / 购物）' },
    reading_week:     { label: 'Reading Week',      desc: '期中读书周（通常 W6 没课）' },
    welcome_week:     { label: 'Welcome Week',      desc: '开学迎新周（社团 / 派对）' },
    // job_hunt
    cv_uk:            { label: 'CV',                desc: '英国 1-2 页学历工作摘要（≠ 美式 Resume）' },
    cover_letter:     { label: 'Cover Letter',      desc: '求职信（讲为啥适合）' },
    sandwich_placement:{ label: 'Sandwich Placement', desc: '三明治课程实习年（本科第 3 年）' },
    milkround:        { label: 'Milkround',         desc: '校招季（9-11 月）' },
    grad_scheme:      { label: 'Grad Scheme',       desc: '应届生培养计划（大公司 2-3 年）' },
    assessment_centre:{ label: 'Assessment Centre', desc: '终面（case + group exercise + presentation）' },
    // saving_money
    meal_deal:        { label: 'Meal Deal',         desc: '£3.5-4 三件套（主食+饮料+零食）' },
    clubcard:         { label: 'Clubcard',          desc: 'Tesco 会员卡（黄标价 + 积分）' },
    yellow_sticker:   { label: 'Yellow Sticker',    desc: '临期食品打折' },
    spoons_app:       { label: 'Wetherspoons App',  desc: '酒馆桌号点单 app（便宜啤酒）' },
    boots_advantage:  { label: 'Boots Advantage',   desc: '屈臣氏式会员卡（积分换购）' },
    nectar_card:      { label: 'Nectar Card',       desc: "Sainsbury's 积分卡" },
    // degrees
    undergrad:        { label: 'Undergraduate',     desc: '本科（英格兰 3 年 / 苏格兰 4 年）' },
    pgt:              { label: 'PGT',               desc: '授课型硕士（1 年）' },
    pgr:              { label: 'PGR',               desc: '研究型硕士（M.Phil / M.Res）' },
    phd:              { label: 'PhD',               desc: '博士（3-4 年）' },
    msc:              { label: 'MSc',               desc: 'Master of Science（理工科）' },
    ma:               { label: 'MA',                desc: 'Master of Arts（文科）' },
    mba:              { label: 'MBA',               desc: '商学院硕士' },
    foundation_year:  { label: 'Foundation Year',   desc: '预科年（IELTS 不足时升本）' },
    // grading
    first_class:      { label: 'First (1st)',       desc: '一等学位（≥70%）' },
    two_one:          { label: '2:1',               desc: '上二等（60-69%，雇主基准线）' },
    two_two:          { label: '2:2',               desc: '下二等（50-59%）' },
    third_class:      { label: 'Third',             desc: '三等（40-49%）' },
    distinction:      { label: 'Distinction',       desc: '硕士优秀（≥70%）' },
    merit:            { label: 'Merit',             desc: '硕士良好（60-69%）' },
    pass_threshold:   { label: '40% Pass',          desc: '本科及格分数线（不挂科）' },
    // class_types
    lecture_class:    { label: 'Lecture',           desc: '大课讲座（100+ 人）' },
    seminar:          { label: 'Seminar',           desc: '小组讨论（15-30 人）' },
    tutorial:         { label: 'Tutorial',          desc: '一对一 / 小组答疑' },
    lab:              { label: 'Lab',               desc: '实验课' },
    workshop:         { label: 'Workshop',          desc: '实操工作坊' },
    office_hours:     { label: 'Office Hours',      desc: '教授固定答疑时段' },
    // assessment
    coursework:       { label: 'Coursework',        desc: '平时作业（essay / report）' },
    dissertation:     { label: 'Dissertation',      desc: '学位论文（硕士 ~12k 词）' },
    viva:             { label: 'Viva',              desc: 'PhD 答辩' },
    open_book:        { label: 'Open Book',         desc: '开卷考试（可带书 / 笔记）' },
    take_home:        { label: 'Take-home Exam',    desc: '带回家考试（24h / 48h）' },
    group_project:    { label: 'Group Project',     desc: '小组项目作业' },
    // online_tools
    zoom:             { label: 'Zoom',              desc: '视频会议主流' },
    ms_teams:         { label: 'MS Teams',          desc: '微软视频会议（学校常用）' },
    panopto:          { label: 'Panopto',           desc: '课程录像播放器' },
    blackboard:       { label: 'Blackboard',        desc: '老牌 LMS（Moodle 的竞品）' },
    padlet:           { label: 'Padlet',            desc: '在线协作白板' },
    mentimeter:       { label: 'Mentimeter',        desc: '实时投票 / 词云' },
    // uni_groupings
    russell_group:    { label: 'Russell Group',     desc: '24 所英国研究型大学联盟' },
    red_brick:        { label: 'Red Brick',         desc: '19/20 世纪工业大学（如 Manchester）' },
    plate_glass:      { label: 'Plate Glass',       desc: '1960s 现代化大学（如 York）' },
    ancient_unis:     { label: 'Ancient Universities', desc: '中世纪老校（Oxford / Cambridge / St Andrews 等）' },
    oxbridge:         { label: 'Oxbridge',          desc: '牛剑合称' },
    qs_top100:        { label: 'QS Top 100',        desc: 'QS 全球前 100 排名' },
  },
};

export const THEORIST_MATCH = {
  theorists: [
    { id: 'foucault',  name: 'Foucault',  concepts: ['discipline','biopower','panopticon','governmentality'] },
    { id: 'bourdieu',  name: 'Bourdieu',  concepts: ['habitus','cultural_capital','field','symbolic_violence'] },
    { id: 'butler',    name: 'Butler',    concepts: ['performativity','gender_trouble','precarity'] },
    { id: 'said',      name: 'Said',      concepts: ['orientalism','imaginative_geography'] },
    { id: 'hall',      name: 'Hall',      concepts: ['encoding_decoding','articulation','new_ethnicities'] },
    { id: 'spivak',    name: 'Spivak',    concepts: ['subaltern','strategic_essentialism'] },
    { id: 'bhabha',    name: 'Bhabha',    concepts: ['hybridity','third_space','mimicry'] },
    { id: 'derrida',   name: 'Derrida',   concepts: ['différance','deconstruction','trace'] },
    { id: 'gramsci',   name: 'Gramsci',   concepts: ['hegemony','organic_intellectual','war_of_position'] },
    { id: 'marx',      name: 'Marx',      concepts: ['alienation','commodity_fetishism','base_superstructure'] },
    { id: 'weber',     name: 'Weber',     concepts: ['iron_cage','protestant_ethic','rationalisation'] },
    { id: 'durkheim',  name: 'Durkheim',  concepts: ['anomie','collective_conscience','solidarity'] },
  ],
  concepts: {
    // Foucault
    discipline:           { label: 'Discipline', desc: '规训' },
    biopower:             { label: 'Biopower', desc: '生命权力' },
    panopticon:           { label: 'Panopticon', desc: '全景监狱' },
    governmentality:      { label: 'Governmentality', desc: '治理术' },
    // Bourdieu
    habitus:              { label: 'Habitus', desc: '惯习' },
    cultural_capital:     { label: 'Cultural Capital', desc: '文化资本' },
    field:                { label: 'Field', desc: '场域' },
    symbolic_violence:    { label: 'Symbolic Violence', desc: '象征暴力' },
    // Butler
    performativity:       { label: 'Performativity', desc: '操演性' },
    gender_trouble:       { label: 'Gender Trouble', desc: '性别麻烦' },
    precarity:            { label: 'Precarity', desc: '不稳定生命' },
    // Said
    orientalism:          { label: 'Orientalism', desc: '东方主义' },
    imaginative_geography:{ label: 'Imaginative Geography', desc: '想象的地理' },
    // Hall
    encoding_decoding:    { label: 'Encoding/Decoding', desc: '编码 / 解码' },
    articulation:         { label: 'Articulation', desc: '接合' },
    new_ethnicities:      { label: 'New Ethnicities', desc: '新族裔性' },
    // Spivak
    subaltern:            { label: 'Subaltern', desc: '从属阶级' },
    strategic_essentialism:{label: 'Strategic Essentialism', desc: '策略本质主义' },
    // Bhabha
    hybridity:            { label: 'Hybridity', desc: '混杂性' },
    third_space:          { label: 'Third Space', desc: '第三空间' },
    mimicry:              { label: 'Mimicry', desc: '模仿' },
    // Derrida
    différance:           { label: 'Différance', desc: '延异' },
    deconstruction:       { label: 'Deconstruction', desc: '解构' },
    trace:                { label: 'Trace', desc: '痕迹' },
    // Gramsci
    hegemony:             { label: 'Hegemony', desc: '霸权' },
    organic_intellectual: { label: 'Organic Intellectual', desc: '有机知识分子' },
    war_of_position:      { label: 'War of Position', desc: '阵地战' },
    // Marx
    alienation:           { label: 'Alienation', desc: '异化' },
    commodity_fetishism:  { label: 'Commodity Fetishism', desc: '商品拜物教' },
    base_superstructure:  { label: 'Base / Superstructure', desc: '经济基础 / 上层建筑' },
    // Weber
    iron_cage:            { label: 'Iron Cage', desc: '铁笼' },
    protestant_ethic:     { label: 'Protestant Ethic', desc: '新教伦理' },
    rationalisation:      { label: 'Rationalisation', desc: '理性化' },
    // Durkheim
    anomie:               { label: 'Anomie', desc: '失范' },
    collective_conscience:{ label: 'Collective Conscience', desc: '集体意识' },
    solidarity:           { label: 'Solidarity', desc: '团结' },
  },
};

/**
 * 按周抽 match round。phase 1 (W2-15) 抽 4 个 theorists + 6 个 concepts。
 * phase 2 (W16-30) 抽 6 + 9 个 concepts。phase 3 (W30+) 抽 8 + 12 个 concepts。
 * 当周关键 theorist 必含(Foucault W2-10,Bourdieu W11-18,Said W19-26 等)。
 */
export function pickMatchRound(week) {
  let phase, theoristCount, conceptCount;
  if (week <= 15) { phase = 1; theoristCount = 4; conceptCount = 6; }
  else if (week <= 30) { phase = 2; theoristCount = 6; conceptCount = 9; }
  else { phase = 3; theoristCount = 8; conceptCount = 12; }

  // 必含当周课程对应 theorist (跟 lecture 主题一致)
  let mustInclude;
  if (week <= 10) mustInclude = 'foucault';
  else if (week <= 18) mustInclude = 'bourdieu';
  else if (week <= 26) mustInclude = 'said';
  else if (week <= 34) mustInclude = 'butler';
  else if (week <= 42) mustInclude = 'hall';
  else mustInclude = 'spivak';

  const allTheorists = THEORIST_MATCH.theorists;
  const mustT = allTheorists.find(t => t.id === mustInclude);
  const others = allTheorists.filter(t => t.id !== mustInclude).sort(() => Math.random() - 0.5);
  const theorists = [mustT, ...others.slice(0, theoristCount - 1)];

  // 概念池:从选出的 theorists 各取 1-2 个 + 填满到 conceptCount
  const conceptIds = [];
  theorists.forEach(t => {
    const tConcepts = [...t.concepts].sort(() => Math.random() - 0.5);
    conceptIds.push(tConcepts[0]);  // 每个 theorist 至少 1
    if (conceptIds.length < conceptCount && tConcepts[1]) {
      conceptIds.push(tConcepts[1]);
    }
  });
  // 不够补到 conceptCount
  if (conceptIds.length < conceptCount) {
    theorists.forEach(t => {
      t.concepts.forEach(cid => {
        if (!conceptIds.includes(cid) && conceptIds.length < conceptCount) {
          conceptIds.push(cid);
        }
      });
    });
  }
  return {
    phase,
    theorists,
    concepts: conceptIds.sort(() => Math.random() - 0.5).slice(0, conceptCount),
  };
}
