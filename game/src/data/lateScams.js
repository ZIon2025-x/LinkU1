// Late-game scam events (W30-52).
//
// 之前 6 条反诈剧情线（storylines.js）全部集中在 W4-22；W23 之后零反诈。
// 但临毕业那段 scam 反而更密——这个文件补：
//
//   1. Gumtree / SpareRoom 押金骗子 (W30-36，对应 flatHunt 期)
//   2. Tier 4 → PSW 假"加急中介" (W37-44)
//   3. 假 sponsor 工签——"先付 visa fee" (W42-50)
//
// 都是 2024-2025 真实模板。每条 3 选项：抗住 / 部分被骗 / 全梭。
// 抗住的 flag 进入 cross-line ripple 池（"你这阵子人怪怪的"）。

export const LATE_SCAM_EVENTS = {
  flat: [
    {
      id: 'scam_deposit_gumtree',
      minWeek: 30, maxWeek: 36,
      title: 'Gumtree · 太完美的 Earl\'s Court ensuite',
      body: '你刷 Gumtree 找下学年的房子。一个 listing 跳出来：\n\n"Earl\'s Court · ensuite double · £680/月（含水电 wifi council tax）· 现房东出国转卖 needs quick handover · 立即可入住"\n\n5 张照片：欧式装修 + 朝南阳台 + 全新厨房。这个价位能 unlock 这种条件——离谱。\n\n你 message 房东。30 秒内回复（异常快）："Hi! Sorry I\'m currently in Edinburgh closing another flat. Lots of interest, can\'t do viewings. To secure I need £400 holding deposit via bank transfer. I\'ll send the BRP/contract once received."\n\n你下个月就要搬。',
      choices: [
        { label: '坚持先视频看房 + 验房东 BRP', effect: { energy: -3, belonging: 6, flag: 'scam_deposit_resisted' },
          feedback: '你回："I can\'t transfer without a video viewing first. Can someone show me the flat live now?"\n\n房东："my brother left his keys in Manchester unfortunately. Can you transfer £200 just to hold the spot for 24h?"\n\n你 Google 那地址 + 反查 listing 图片——3 张盗自一个 Foxtons listing（在 Hampstead 不是 Earl\'s Court）。\n\n你 report 给 Gumtree + 发 CSSA 群警告：\n\n上岸了的姐：典型 SpareRoom/Gumtree 押金骗 funnel——所有"急转""国外""不能 viewing"都是假的。\n@Lily：天我室友上周差点被这种骗 £600 ✨\n狗哥：兄弟 Earl\'s Court 那个价位的 ensuite 早就涨到 £900+ 了 一看就假\n新生小王：救命 我前天给 Gumtree 一个房东转了 £200... 我现在该咋办\n潜水的人：（出现）UK 找房子永远先 in-person viewing 再付 deposit。SpareRoom 比 Gumtree 安全但也要 verify。' },
        { label: '"急于 secure" + 转 £400', effect: { wallet: -400, energy: -8, belonging: -6, flag: 'scammed_deposit' },
          feedback: '你转了 £400。第二天她说还要再转 £400 第二期 deposit (full month rent)。你犹豫——她："other applicants are ready to transfer right now."\n\n你又转了 £400。3 天后联系不上她。\n\n你坐在 ensuite 看银行账单——£800 没了。\n\n你这次没敢告诉爸妈——你跟 Action Fraud 报案，银行 chargeback 拿回 £200。净损 £600 + 1 个月找房子的精力。\n\n下个月你不得不接一份 Mei 姐多的 shift。' },
        { label: '"算了" 关闭 Gumtree 找正规中介', effect: { energy: 1 },
          feedback: '你关闭 Gumtree。3 周后通过 SpareRoom + Foxtons 找到一个 Zone 2 ensuite £750——比 Gumtree 那个贵 £70 但你能 in-person viewing。\n\n你没省到那 £70。但你也没踩坑。' },
      ],
    },
  ],

  uni: [
    {
      id: 'scam_psw_visa_agent',
      minWeek: 37, maxWeek: 44,
      title: '"Tier 4 → PSW 加急 7 天 £800"',
      body: 'CSSA 群里突然冒出来一个号"伦敦留学生签证服务"。\n\n群里 push 一张 PPT："Tier 4 → Graduate Visa（PSW）转换。官方 8 周。我们 7 天 £800。已服务 200+ 留英学生 0 拒签。"\n\n附 4 张"成功案例"截图——签证 stamp 印章 + 学生喜笑颜开。\n\n你毕业 deadline 紧——offer 已经在催你 visa。你算了下：£800 vs 自己等 8 周让 offer 飞走。',
      choices: [
        { label: '"加急根本不是这么个流程"+ Block', effect: { energy: 1, belonging: 8, academic: 3, flag: 'scam_psw_resisted' },
          feedback: '你回那个号："Home Office 不存在 7 天加急 channel。Graduate Visa 8 周是 standard，priority service 是 5 天但价格 £500（official，不通过中介）。你这是诈骗。"\n\n他直接 block 你。\n\n你发 CSSA 群警告：\n\n上岸了的姐：每年都有 1-2 个新冒出来的"加急中介"。0 例外都是诈骗。Home Office 不会让中介接触你的 visa。\n@Lily：天 ✨ 我室友前天还咨询了这个号 我让她退\n狗哥：FCA 持牌移民律师 OISC 网站可查——这种群推号 100% 没牌\n潜水的人：UKVI 官方 Priority Service £500 自己 apply。10 分钟就能 submit。' },
        { label: '付 £800 + 让中介帮处理', effect: { wallet: -800, energy: -10, belonging: -8, flag: 'scammed_psw_agent' },
          feedback: '你转了 £800。中介给你一份"申请 progress 截图"——你以为是 Home Office 后台。\n\n2 周后他说"系统升级 你的 case 卡了 需再付 £400 加速"。你拒了。他消失。\n\n你自己重新申请——standard processing 8 周。你拿到 PSW 时 offer 已经 deadline 过了——公司另招。\n\n你净损 £800 + 第一份工作机会。\n\n你最后还是拿到了 PSW（自己申请）。但你这一笔学费很贵——比 dissertation 还贵。' },
        { label: '自己上 GOV.UK 申请 + 走官方 priority £500', effect: { wallet: -500, energy: -5, academic: 5, flag: 'psw_self_filed' },
          feedback: '你打开 GOV.UK Graduate Visa 申请页面。表格 30 页但每一项 self-explanatory——你 1 小时填完 + £500 priority fee + £624 IHS。\n\n6 天后 BRP 寄到你 ensuite——上面写着 "Graduate Visa, valid until..."。\n\n你拍照发 CSSA 群："自己 apply 的 兄弟姐妹们 别走中介。"\n\n上岸了的姐：你这条置顶。' },
      ],
    },
    {
      id: 'scam_fake_sponsor_visa_fee',
      minWeek: 42, maxWeek: 50,
      title: '"我们 sponsor 你 但你先付 £2,000 visa fee"',
      body: 'LinkedIn DM。"James Wong · HR Director · TechFusion London"——profile 看着合理（200 connections，2 年前注册）。\n\n"Saw your dissertation topic. We\'re a Series A AI startup, looking for a Junior Strategy Analyst (£42k). Skilled Worker visa sponsor. Interested?"\n\n你做了 take-home + video interview——他态度专业。第二轮他说："Final stage. We sponsor your visa, but candidate covers the £2,000 sponsorship application fee. Reimbursable in your first paycheck."\n\n你在 LinkedIn 上反查 TechFusion：office address 真实，team 12 人，但 Glassdoor 上 0 reviews。',
      choices: [
        { label: '查 UKVI sponsor list + 发现没注册 + 拒绝', effect: { energy: 1, academic: 3, belonging: 8, flag: 'scam_sponsor_resisted' },
          feedback: '你打开 GOV.UK "Register of Worker and Temporary Worker sponsors" — search "TechFusion"——0 results。\n\n你 google 真实数据：Skilled Worker sponsor license 是 employer 自己付的（£574 起 + £199 immigration skills surcharge）。**Candidate never pays for sponsorship.**\n\n你回 James："I checked the UKVI sponsor register. TechFusion isn\'t listed. Sponsor licence fees are paid by the employer, not the candidate. I won\'t be proceeding."\n\n他立刻 unmatch。\n\n你发 CSSA 群 + LinkedIn 警告。3 个 connection comment 说他们也收到过类似 DM。' },
        { label: '"听起来合理" 付 £2,000', effect: { wallet: -2000, energy: -20, belonging: -15, flag: 'scammed_sponsor_full' },
          feedback: '你转了 £2,000 到他给的"HR partner account"。第二天他说还需要 £1,000 background check fee。\n\n你拒了。LinkedIn unmatch。TechFusion 网站突然 404。\n\n你净损 £2,000 + 一个 empty offer 的破灭。\n\n你回家给妈打电话——这次没忍住，全说了。妈安静 30 秒："傻孩子。这钱妈给你转回来。但你要答应妈一件事——下次任何 offer 让你出钱的，先打给妈。"\n\n你哭着说"嗯"。\n\n2 个月后你拿到一个真正 sponsor 的 offer——这次你查了 UKVI register。' },
        { label: '"我跟 Whitmore confirm 一下"', effect: { energy: -3, belonging: 6, flag: 'scam_sponsor_consulted_whitmore' },
          condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 5,
          feedback: 'Whitmore 听完你描述 30 秒就皱眉："Sponsor fees paid by candidate is a textbook scam signal. Look up the company on the UKVI register before responding to anything else."\n\n你回去查——果然 TechFusion 不在 register。你 block + 报 Action Fraud。\n\n第二周 Whitmore office hour 时他说："I\'ve been meaning to mention—be especially careful with LinkedIn recruiters this year. Three of my supervisees in 2023-24 lost between £1k and £4k to fake sponsors. You came to ask. That\'s the difference."\n\n你那一刻知道——一个 £80,000 学费的硕士最值钱的 ROI 不是 dissertation——是当你需要 sanity check 时有人愿意接你电话的能力。' },
      ],
    },
  ],
};
