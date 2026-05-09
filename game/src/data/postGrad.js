// Post-graduation visa + job hunt — the W37+ existential layer.
//
// Real Chinese MSc students in the UK face two concurrent fires by the time
// dissertation drafts start: (1) Graduate Route visa application = £822 + 2
// years × £776 IHS surcharge, paid before BRP expires; (2) finding a job that
// either sponsors Tier 2 or accepting Graduate Route limits.
//
// All events here are non-auto. Most are at flat (admin/email/phone), some at
// uni (interviews, careers events).

export const POST_GRAD_EVENTS = {
  flat: [
    {
      id: 'psw_visa_apply', minWeek: 37, maxWeek: 50,
      title: 'Graduate Route 工签申请',
      body: '论文季中段。你打开 gov.uk：\n\n"Apply for the Graduate visa — for international students who have completed their UK degree. 2 years post-study work, no sponsor required."\n\n费用拆开：申请费 £822 + 2 年 IHS surcharge 2 × £776 = **£2,374**。一次性付清。3 周审批。\n\n你算了一下卡里的余额。',
      choices: [
        { label: '咬牙交 £2,374', effect: { wallet: -2374, energy: -8, flag: 'psw_applied' },
          feedback: '你提交了。3 周后 BRP 续到了 2026 年。\n\n这是这一年最大单笔支出之一。但你买回来的是"留下来的权利"——值 2 年时间，去试一次"在伦敦工作"是什么感觉。' },
        { label: '想想还是回国', effect: { energy: 1, flag: 'no_psw' },
          feedback: '你关掉网页。卡里还在。\n\n但你心里有一个问号没消——"如果我现在就放弃留下来的可能，我到底是不想留 还是怕留不下来？"' },
      ],
    },
    {
      id: 'linkedin_open_to_work', minWeek: 37, maxWeek: 50,
      title: 'LinkedIn · Open to Work',
      body: 'CSSA 群里："姐妹们 LinkedIn 头像加 Open to Work 那圈绿框了吗？"\n\n你点开自己的——location 还是 "Beijing" / "Shanghai"。Education 还是 "Tsinghua University BSc"。空空荡荡。\n\n你要不要把 location 改成 "London, United Kingdom"？',
      choices: [
        { label: '改成 London + 加 Open to Work 框', effect: { energy: -3, flag: 'linkedin_open' },
          feedback: '你改了。两小时内你的 connection 涨了 18 个——大部分是 Big 4 / Big Tech 的 recruiter。\n\n第一个 InMail 6 小时后到："Hi! Are you available for a quick chat about an Audit role at PwC?"\n\n你心跳了一下。原来"open to work"不是宣告，是开机。' },
        { label: '还是低调 不开', effect: { energy: 1 },
          feedback: '你保留 Beijing。但你也意识到——recruiter 不会主动找你了。Job hunt 完全靠你自己。' },
      ],
    },
    {
      id: 'classmate_big4_offer', minWeek: 40, maxWeek: 48,
      title: 'CSSA 群 · 有人拿 PwC offer',
      body: '群里炸了：\n\n王同学："家人们 我拿到 PwC Audit grad scheme 了！第一年 £35k，2026 年 9 月入职！" 后面跟了 60 个 🎉。\n\n你认识王同学——你们一个 cohort，他这学期挂了一门必修课。但他爸是知名银行 VP，他实习就是 PwC。\n\n你心里那种"羡慕 + 不甘 + 自我怀疑"的复合滋味。',
      choices: [
        { label: '群里发 "恭喜！🎉"', effect: { energy: -2, belonging: 2 },
          feedback: '你点了 emoji，复制了 "恭喜恭喜！太厉害了！"\n\n关掉群你坐了 5 分钟。然后你打开 LinkedIn 投了 5 份简历——"今天必须做点什么"。\n\n不甘心也是一种生产力。' },
        { label: '私聊问他怎么拿的', effect: { energy: -3, belonging: 4 },
          feedback: '王同学回："Spring week 进的 pipeline。如果你早一年来就有戏。今年 grad scheme deadline 已经过了大半。"\n\n你 google "PwC graduate scheme 2026 entry deadline"——大部分确实关了。\n\n这是英国 grad scheme 的真相——你不在它的时间线里，就晚了一年。' },
        { label: '关群 不看', effect: { energy: 1, belonging: -3 },
          feedback: '你关掉群。但晚上你刷小红书又看到 3 条"PwC Audit grad scheme offer 分享"。\n\n你想：你是关不掉这个群的。' },
      ],
    },
    {
      id: 'sponsor_list_search', minWeek: 42, maxWeek: 50,
      title: 'Tier 2 Sponsor List · 1.4 万家',
      body: '你 google "uk sponsor licence list 2024"——下载了一个 Excel 文件。\n\n1.4 万家 UK 公司有资格 sponsor Tier 2 (Skilled Worker) visa。但是：\n· Big 4 / Big Tech 几乎都有，但 grad 名额今年已关\n· 中型公司有 license 但年发 1-2 个 visa\n· Startups 大部分没 license\n· 工资门槛 £38,700/年（2024 新规）——很多 grad 岗够不到',
      choices: [
        { label: '只投有 sponsor + 工资过门槛的', effect: { energy: -10, academic: 2, flag: 'sponsor_focused' },
          feedback: '你过滤出 80 家。开始投。每天 5 份。两周后回复率 4%——3 份发了 OA (online assessment)，1 份过到了 first round 面试。\n\n这是英国 grad job 的真实数字：从投到面试转化率 5%。从面试到 offer 又是 5%。' },
        { label: '广撒网 Graduate Route 反正 2 年免 sponsor', effect: { energy: -5, flag: 'gr_strategy' },
          feedback: '你投了所有 grad 岗，不管 sponsor。2 年用 GR 工签先工作，2 年内升级到能 sponsor 的岗位再说。\n\n这是更聪明的策略——但你的"目标公司"列表里 80% 不会留你超过 2 年。' },
      ],
    },
    {
      id: 'mom_call_come_home', minWeek: 47, maxWeek: 51,
      title: '妈妈电话 · "还是回来吧"',
      body: '周六上午 10 点（北京 6 点）。妈妈打来视频。\n\n她支吾了 5 分钟，最后说：\n\n"你王阿姨女儿今年回来选调上岸了，事业编、房补、户口。你爸刚跟她爸喝了茶，回来跟我说\'我们家的孩子留那边折腾什么\'。\n\n咱家不缺你那点工资。你回来 妈托人帮你看看体制内的位置。"',
      choices: [
        { label: '"妈 我想试一年看看"', effect: { energy: -5, belonging: 3, flag: 'told_mom_stay' },
          feedback: '你说："我交了 PSW 工签 £2,374。我想用这两年给自己一个交代——不试就回 我会一辈子想 if。"\n\n妈妈沉默 8 秒。然后她说："那你试。妈不催你。但你爸那边我得想想怎么说。"\n\n挂电话你看着窗外的小雨。你不知道这是对的决定 但你知道是你自己做的。' },
        { label: '"妈你说得对 我考虑回来"', effect: { energy: 2, belonging: 8, flag: 'told_mom_return' },
          feedback: '妈妈眼睛一下亮了："那 那行 那行。" 她转头跟你爸说："同意了同意了。"\n\n你挂了电话坐在床上。你爸的笑声从背景传出来。\n\n你想：是的，体制内是稳的。妈妈不会害我。但你心里也有那一句"如果我没回呢？"——你以后会知道答案。' },
        { label: '"我们再说" 推', effect: { energy: -3 },
          feedback: '妈妈："好好 妈不催你。" 但她的声音没刚才轻松。\n\n你这一年要做的最重的决定——你又往后推了一周。' },
      ],
    },
    {
      id: 'first_interview_online', minWeek: 41, maxWeek: 49,
      title: '第一次 Online Interview',
      body: '你投的某 Big 4 grad scheme 给你发了一个 first round HireVue 视频面试链接。\n\n规则：5 个 behavioral 问题，每题 2 分钟回答，没人在线，对着 webcam 录。\n\n第一题："Tell me about a time you led a team through a difficult challenge." 30 秒思考时间。',
      choices: [
        { label: '认真讲一个真实经历（STAR 法）', effect: { energy: -8, academic: 3, flag: 'hirevue_done' },
          feedback: '你讲了你 group project 怎么 cover Jack（freeloader）那段——Situation Task Action Result 结构。最后留 10 秒空白。\n\n你录完点 submit。两周后没消息——这就是 HireVue 的常态。但你练了一次面试，下次会更稳。' },
        { label: 'Panic 答得乱七八糟', effect: { energy: -10, belonging: -2 },
          feedback: '你看着 webcam 大脑空白。说了一段没头没尾的话。submit 之后你坐了 30 分钟。\n\n但你也想：第一次嘛，能录就是赢。下次 you\'ll prepare 30 个 STAR 故事 ready to deploy。' },
      ],
    },
    {
      id: 'china_bias_interview', minWeek: 44, maxWeek: 50,
      title: '"You have right to work in the UK?"',
      body: '某中型咨询公司 final round 面试。HR 是个 50 岁英国白人女性。\n\n聊到一半她问："Just to confirm, do you have right to work in the UK long-term, or would we need to sponsor you?"\n\n你说："I have the Graduate visa for 2 years. After that I\'d need sponsorship, which your company is licensed to provide."\n\n她笑笑："Mm, OK. Thank you."\n\n你看出她笔记里写了一个东西。',
      choices: [
        { label: '主动加一句 "我了解你们 graduate sponsor 比例不高"', effect: { energy: -3, academic: 3, flag: 'china_bias_acknowledged' },
          feedback: '你说："I noticed you sponsor about 5 grads per year. I\'d be aiming to be one of them—I\'m happy to discuss what value I\'d bring."\n\nHR 表情松了一点："Refreshingly direct. We\'ll be in touch."\n\n两周后 rejection 邮件到。"We had many strong candidates this year." 你不知道是不是因为 sponsor。但你也想：直球比假装没发生过好。' },
        { label: '装作没注意到 继续答', effect: { energy: -5, belonging: -3 },
          feedback: '你继续答下一题。但你后半场答得比较紧。\n\n两周后 rejection。理由 generic。\n\n你后来 google 才确认——很多 UK 公司在 final round 才"发现"sponsor 问题，然后默默放弃中国候选人。这不违法，但你也证明不了。' },
      ],
    },
    {
      id: 'psw_decision_eve', minWeek: 51, maxWeek: 52,
      title: '论文交了 · 工签决定夜',
      body: '12 月某夜。论文已经在线提交。明天 graduation。\n\n你坐在床上看 LinkedIn——\n· 拿 offer：1 个（小公司 £32k）\n· 还在 pipeline：3 个\n· 拒信：22 个\n· 没回：47 个\n\n回国选调位置：你妈那边的人脉给你预留了一个"区财政局"的考试。报名截止：1 月 15 日。',
      condition: ({ flags }) => flags.psw_applied,
      choices: [
        { label: '接受小公司 offer 留下', effect: { energy: -3, belonging: 8, flag: 'stayed_uk_grad' },
          feedback: '你打了 acceptance email："I am delighted to accept the offer."\n\n这一年的 £52k 学费、£8k 房租、£2,374 工签——总价 £62k——换来一个"先留 2 年看看"的机会。\n\n你知道这个数学不一定划算。但你也知道——你真心想试。' },
        { label: '拒了 offer 回国选调', effect: { energy: 5, belonging: 12, flag: 'returned_civil_service' },
          feedback: '你写了 polite rejection。然后回邮件给妈："订机票了。1 月 15 日报名 我能赶上。"\n\n妈妈秒回："好。回家。"\n\n你看着伦敦窗外的雪。这一年值不值？以后再说。这一刻你只想回家。' },
        { label: '先拖 看 Big 4 还有没机会', effect: { energy: -5 },
          feedback: '你给小公司 offer 发了 "请允许我再考虑 1 周"。一周后 Big 4 没消息。小公司撤了 offer——他们等不及。\n\n你两手都空。你想：原来在英国，"考虑一下"等于"放弃"。' },
      ],
    },
  ],

  uni: [
    {
      id: 'careers_fair', minWeek: 38, maxWeek: 42,
      title: 'Careers Fair · 摆摊招聘',
      body: '主楼大厅。50 个公司摆摊位——Big 4、Magic Circle 律所、Big Tech、咨询、IB。\n\n你拿了一杯 KPMG 免费咖啡，走到 Goldman Sachs 摊位前。一个 25 岁西装男在跟一个英国学生聊"我妈妈是 partner"。\n\n你后退一步。',
      choices: [
        { label: '硬着头皮去搭话', effect: { energy: -8, belonging: 3, flag: 'careers_fair_brave' },
          feedback: '你说 "Hi, I\'m an MSc student in Cultural Studies. Are there any tracks for non-finance backgrounds?"\n\n他笑了："Honestly, not really. But come to our coffee morning next Thursday."\n\n你拿了名片。他叫 James。Coffee morning 你去了——但没有真的 follow-up。这是英国职场社交的常态——polite but not personal。' },
        { label: '只去华人公司摊位（Bytedance / Alibaba UK）', effect: { energy: -3, belonging: 5 },
          feedback: '你跟两个 Bytedance 的 recruiter 聊了。她们说中文："我们 UK office 不大，但有 product manager grad scheme。" 你拿了二维码。\n\n回家投了。两周后第一轮面试。母语应聘的舒适感——你这一年第一次。' },
      ],
    },
  ],
};
