// Y 姐 / 陈思敏 / Yvonne Chan
//
// 第 7 主线 mentor NPC, AI 广告创业线引路人。
// 8 人达人团队 LinkU Bespoke 创始人, 私人定制旅行 niche。
// 通过 inbox DM 在 Ch 4 W22 邀请玩家;后续 7 个场景串起 9 章。

export const YJIE_PROFILE = {
  id: 'yjie',
  realName: '陈思敏',
  englishName: 'Yvonne Chan',
  age: 28,
  hometown: '广东中山',
  education: 'UCL MSc Tourism & Heritage',
  yearsPostgrad: 6,
  visaStatus: 'ILR pending',
  business: 'LinkU Bespoke',
  businessTagline: '私人定制旅行',
  teamSize: 8,
  pricePoint: '£400-600/day',
  avatar: '💼',
  avatarColor: '#a855f7',
  avatarImage: 'yjie',
  toneSamples: [
    '呢单嘢值唔值得做?算你 LTV, 三个月入 12 单。OK 嘅。',
    'Don\'t say sorry. Say thank you. Sorry 系 client side 嘅嘢, 你而家 vendor side。',
    '撑住吖。论文写完你就识乜嘢叫 freedom。',
    '你做的留学生级别的作品 我看了。技术上可以做品牌级, 但你一个人接不过来。',
  ],
};

// 7 个关键场景 (spec §5.2)
// 每个场景被 link2urMainline.js 引用为章节关键节点
export const YJIE_SCENES = [
  // 场景 1 · Ch 4 W22 · Sketch 邀请 + Phase pivot
  {
    id: 'yjie_sketch_invitation',
    chapter: 4,
    weekStart: 21,
    weekEnd: 22,
    title: 'Sketch · 那个 pink room',
    triggerFlag: 'l2u_y_invited',  // 触发条件: shouldTriggerYInvitation === true 时设
    flagOnComplete: 'l2u_y_sketch_done',
    body: `周六上午 11 点。Sketch 餐厅那个粉色房间。

你按地址进去, 一个穿米色 trench coat、Mulberry tote 摆在椅背上的女生抬头看你。
她面前桌上摆着一杯黑咖、一杯燕麦拿铁、自己印的 menu booklet。

"过嚟。我系 Y。" 她切到普通话 + 港式: "唔知你饮咩, 都点咗。"

她翻开 booklet 第一页 — 是 LinkU Bespoke 团队 8 个人的合影。
"我五年前 UCL Tourism MSc 毕业那年留下来的。第一单 £20 带个交换生逛 Borough Market。
你这两个月的曲线, 比当年的我陡。"

她合上 booklet, 看着你: "我之所以约你, 不是为咗 random 嘅好奇。
我嘅高净值客户订完旅游后系要喺 IG / 小红书度晒。AI 内容包系 missing piece。
我团队冇人识做。你识。"

"想搞唔搞一个 team?"`,
    choices: [
      {
        label: '"我想试 team。" — 加入 Path B',
        effect: {
          stats: { belonging: 8 },
          npc: { yjie: 4 },
          flag: 'link2urPath_team',
          phasePivot: 2,  // Phase 1 → 2 不可逆
        },
        feedback: `Y 姐眨了一下眼。"OK。下周我介绍我学妹小雨给你, 你哋自己谈。
唔好以为我塞人。佢系 KCL 应用语言学 MA, 双语本地化嘅 talent。睇你 fit 唔 fit。"

她结账时拿出一张名片: "我电话, 24/7。你 panic 嗰阵就打。"
名片正面 minimalist 设计, 反面手写了三行: "1. 客户开心 你就开心  2. 收钱要爽  3. 唔好 burnout"

你回去 tube 上想: 这一年我可能要 reshape 自己。`,
      },
      {
        label: '"我想试 Solo。" — 委婉拒绝 Path A',
        effect: {
          stats: { belonging: 4 },
          npc: { yjie: 2 },
          flag: 'link2urPath_solo',
          phasePivot: 2,  // Phase 仍升级,玩家自己承接品牌单
        },
        feedback: `Y 姐想了 3 秒。"OK。我尊重你嘅 choice。"

她从 tote 里抽出一张她的 LinkedIn QR: "Solo 都有 Solo 嘅活法。
你如果想 referral, 或者 panic, 随时 ping me。"

走出 Sketch, 你心里其实有点慌。但你知道:
你不是为了"加入 LinkU Bespoke" 才来读这个 MSc 的。`,
      },
      {
        label: '"让我想想。" — 限定接单, 暂留 undecided',
        effect: {
          stats: { belonging: 2 },
          npc: { yjie: 1 },
          flag: 'link2urPath_undecided',
          phasePivot: 2,
        },
        feedback: `Y 姐笑了。"OK lah, 不急。下周我团队有个 capstone 项目, 我 cc 你一封 email。
你睇下 — 唔做都唔紧要, 当 reference 都好。"

她临走说: "记住 — undecided 唔系 indecisive。
undecided 系 'I'll decide when I have more data'。OK?"`,
      },
    ],
  },

  // 场景 2 · Ch 5 W23-25 · Team 路径 · 介绍小雨
  {
    id: 'yjie_team_referral_xiaoyu',
    chapter: 5,
    weekStart: 23,
    weekEnd: 25,
    title: 'DM · "我学妹小雨想入行"',
    requireFlag: 'link2urPath_team',
    flagOnComplete: 'l2u_y_referred_first',
    body: `Y 姐 DM:

"小雨 — 李雨彤, KCL 应用语言学 MA Y1, 23 岁, 双语 perfect。
她最近想找 AI 文案的 internship, 我建议她先做 freelance 攒 portfolio。
你考虑唔考虑要 ta? 你定 cut percent, 我唔参与。

我介绍人嘅唯一条件: 唔 fit 就直接讲, 唔 fit 嘅人留喺 team 系 hurt 大家。"

附了她 LinkedIn + 一份小雨的 sample 中英文案 (你看完觉得 talent 真的不错)。`,
    choices: [
      {
        label: '"约她下周 Pret 聊。" — 招入团队',
        effect: {
          npc: { yjie: 2, xiaoyu: 1 },
          flag: 'l2u_team_recruited_xiaoyu',
          // ↑ reducer 在 setFlag 时检测后会把 xiaoyu 加进 link2urTeamMembers
        },
        feedback: `周三下午 Pret Tottenham Court Road。小雨穿运动外套, 没化妆。
她说话很慢, 用 "嗯, 我觉得..." 开头。
你跟她讲了三件事: 1. cut 18%  2. 第一单我会陪改  3. 你不喜欢可以随时退。

她说: "我想试。"

招进来了。Link2Ur 后台显示: Team size 1。
你心里的紧张比她还多。`,
      },
      {
        label: '"我先一个人再试一段。" — 推迟招人',
        effect: {
          npc: { yjie: 0 },
          flag: 'l2u_xiaoyu_deferred',
        },
        feedback: `你 DM 回 Y 姐: "学妹挺 talent 但我还没 ready。"

Y 姐: "OK。你 ready 嘅时候话我知。她不急, 我也不急。"

你接下来一个月评分 4.95, 但完单也只升了 4 单 — 一个人 capacity 明显 cap 了。`,
      },
    ],
  },

  // 场景 3 · Ch 5 W25-26 · Solo 路径 · check-in
  {
    id: 'yjie_solo_checkin',
    chapter: 5,
    weekStart: 25,
    weekEnd: 26,
    title: 'DM · "Solo 都有 Solo 嘅活法"',
    requireFlag: 'link2urPath_solo',
    flagOnComplete: 'l2u_y_solo_checkin',
    body: `Y 姐 DM:

"你嗰日 Sketch 拒咗我, 我其实挺欣赏。我哋呢一行做久咗, 见太多人冲住合伙就答应, 之后后悔。

我冇要约你 — 就一句: Solo 唔系一定走孤独路。Network 唔等於 team。
我团队有一个 referral 系统, 我推俾你, 你 cut 唔同 — 你做 Solo, 我推 referral, 大家 win。

唔急答, 自己睇 LinkedIn 加我。"

附上她 LinkedIn QR + 一份"Solo Pro 客户 Referral 协议草稿"PDF。`,
    choices: [
      {
        label: '"加 LinkedIn。" — 接受 referral 网络 (推荐选)',
        effect: { npc: { yjie: 2 }, flag: 'l2u_y_referral_network' },
        feedback: `你加了 Y 姐 LinkedIn。她的 profile 1.2k followers, 头像是她在 Sketch 那张。

她接受好友请求 30 秒后 DM: "Welcome to the network。下周第一个 referral 推给你 — Lily 推荐过你, 你应该已经熟。Carrie at 蓝瓶茶饮。"

你打开 inbox: 已经有了 — 蓝瓶茶饮 marketing director 找你做英国 launch。
Y 姐做了第一次桥, 没拿一分钱。`,
      },
      {
        label: '"谢谢, 我自己摸索一下。" — 完全独立',
        effect: { npc: { yjie: 1 }, flag: 'l2u_solo_full_independent' },
        feedback: `你 DM 回 Y 姐: "感谢, 我想自己摸索一阵。"

Y 姐: "OK lah。Don't be a stranger though。"

你接下来 3 个月的客户都靠 Lily / Marcus 自己介绍。慢, 但都是你自己接到的。`,
      },
    ],
  },

  // 场景 4 · Ch 6 W28-29 · 复活节 capstone
  {
    id: 'yjie_easter_capstone',
    chapter: 6,
    weekStart: 28,
    weekEnd: 29,
    title: '复活节 · Bespoke 客户行后 AI 内容包',
    flagOnComplete: 'l2u_y_easter_capstone_completed',
    body: `Y 姐 group chat (Team) 或 DM (Solo):

"4 月头我有个 Bespoke 大客户: 上海一对 finance 夫妇, 5 月飞英国 11 天蜜月。
我团队负责 itinerary + 私陪 + 米其林预订。
但客人提议: 'Could you guys also do the IG content for us?'

我哋唔做内容。所以我想 outsource 俾你。
£800, 1 周交付。内容包要求:
· 11 天每日 1 条短视频 (双语字幕)
· 5 张精修图 (Midjourney 后期)
· 1 篇小红书长图文 (3000 字 + 12 张图)
· 1 个 IG Highlights cover set"

附 brief 文档 + 客人的 vibe board (Cotswolds 田园 / 苏格兰高地 / 牛津学院)。`,
    choices: [
      {
        label: '"接 — 全包。"',
        effect: {
          stats: { wallet: 800, energy: -25, academic: -5 },
          npc: { yjie: 3 },
          flag: 'l2u_y_easter_capstone_completed',
          flag2: 'l2u_y_easter_capstone_quality_high',
        },
        feedback: `你 (+ Team 团员们) 4 天没合眼。但出来的东西自己都觉得震撼:
那条苏格兰高地的 30s 视频, Sora 生成的雾气画面里 overlay 客人的实拍片段, BGM 用了 Skye Boat Song。

客人收到的当天发了一条长 message: "I cried watching the Cotswolds reel. Thank you."
Y 姐转 forward 给你: "她说哭了。OK 系真嘅 OK。"

Y 姐当晚加 200 bonus: "你哋 deserve。"`,
      },
      {
        label: '"接 — 只做视频 + 图, 不做小红书。"',
        effect: {
          stats: { wallet: 500, energy: -15, academic: -2 },
          npc: { yjie: 2 },
          flag: 'l2u_y_easter_capstone_completed',
        },
        feedback: `你跟 Y 姐说: "小红书我现在还做不到那个 quality。我接前两个 deliverable。"

Y 姐: "Fair。"

3 天交付。客人喜欢。Y 姐说: "你诚实, 我 respect。"`,
      },
      {
        label: '"我这周复活节复习 / 实习 / 回国, 不接。"',
        effect: {
          stats: { wallet: 0, energy: 0 },
          npc: { yjie: -1 },
          flag: 'l2u_y_easter_capstone_declined',
        },
        feedback: `Y 姐: "OK。下次仲有机会。"

你过完复活节回到 London, 听说她最后是自己团队的 Chloe 用 ChatGPT 撑下来的, 客人 4 星不是 5 星。
Y 姐没怪你, 但你能感觉到她对 Chloe 比对你更亲了一点。`,
      },
    ],
  },

  // 场景 5 · Ch 7 W36-38 · 论文期 cameo
  {
    id: 'yjie_thesis_checkin',
    chapter: 7,
    weekStart: 36,
    weekEnd: 38,
    title: 'DM · "撑住吖。"',
    flagOnComplete: 'l2u_y_thesis_checkin',
    body: `凌晨 1:42。Senate House 7 楼。你正在改论文 Methodology 章节。
Link2Ur 弹一条 DM。

Y 姐: "撑住吖。论文写完你就识乜嘢叫 freedom。

我嗰阵 2020 年 lockdown 写嘅, 比你 worse — 图书馆全部 close, 我喺一个 6 平米嘅 ensuite 写咗 8 个月。 Submit 嘅嗰一日我哭咗 30 分钟。冇人陪。

你而家有 inbox 一堆人等你。我建议: 论文期把 inbox 关 2 周。
你 brand 已经有 trust, 客户唔会走。"`,
    choices: [
      {
        label: '"OK 我关 inbox 2 周。" — 听建议',
        effect: {
          stats: { academic: 8, belonging: 3 },
          npc: { yjie: 2 },
          flag: 'l2u_inbox_paused',
          flag2: 'l2u_y_thesis_checkin',
        },
        feedback: `你关了 inbox。第 4 天客人 Lily 通过 IG 私信你: "你 inbox 怎么关了 咩事?"
你: "论文 panic 中。"
Lily: "OK 我自己等。"

你 14 天后 submit, 论文 grade 75 (Distinction 边缘)。
你想: Y 姐讲嘅 freedom 系真嘅。`,
      },
      {
        label: '"谢谢, 但我自己 manage。" — 继续接单',
        effect: {
          stats: { energy: -5 },
          npc: { yjie: 1 },
          flag: 'l2u_y_thesis_checkin',
        },
        feedback: `Y 姐: "OK。但你 burnout 就发 SOS, 唔好硬撑。"

你这 2 周 inbox 没关, 但拒了 70% 的单。论文 grade 68, 不错但不是 distinction。`,
      },
    ],
  },

  // 场景 6 · Ch 8 W45-47 · 🔴 合并提议 (核心场景)
  {
    id: 'yjie_merger_offer',
    chapter: 8,
    weekStart: 45,
    weekEnd: 47,
    title: 'Sketch 二访 · "客户复用 cross-sell"',
    flagOnComplete: 'l2u_y_merger_offered',
    body: `周六上午 11 点。还是 Sketch 那个 pink room。
Y 姐穿同一件米色 trench (你心想她可能就买了一件)。

她今天没准备 menu booklet。她准备了一张 napkin, 上面手写了一个数字模型:

  LinkU Bespoke 客户 = 220 个 / 年 · 客单 £4500 平均
  + Player AI Studio = 假设并入 = 全部客户 +£1500 行后 IG/小红书内容包
  = ARR 增量 £33万

她推过来: "我哋共用客户。我服务旅游, 你服务内容。同一批人, 两次买单, 两次值钱。
合并条款我大概想咗:
· 你嘅 brand 保留为 LinkU Bespoke 嘅 'AI Content Atelier' sub-brand
· 你嘅团队全部并入, 我 100% 不动你嘅 cut 结构
· 我哋 founding share 70/30, 你 30
· 你嘅人喺品牌内独立 budget, 我唔 micromanage"

她喝了一口 cappuccino: "下午茶我请, 但 Decision Day 系一周后。"`,
    choices: [
      {
        label: '"我接受合并。"',
        effect: {
          stats: { belonging: 12, wallet: 0 },
          npc: { yjie: 5 },
          flag: 'l2u_y_merger_accepted',
          requireFlag: 'link2urPath_team',
        },
        feedback: `Y 姐点头, 没大声说什么。但她把那张 napkin 折起来放进 tote。
"OK。下周我律师会发 LOI 草稿。"

走出 Sketch 的时候她突然停下来回头: "其实我 nervous 咗 4 个晚上你会唔会答应。
真嘅 — 你嘅 work 系我团队冇人识做嘅。"

你坐 Tube 回去, 心跳一直没平复。
今天下午, 妈妈电话: "你王阿姨女儿选调上岸了 25w + 户口..."
你: "妈, 我今天上午签了一个合伙人。"

她在电话那头沉默了 8 秒。然后: "...真的？"
"真的。"
"...好。妈支持你。"`,
      },
      {
        label: '"我不接受合并 — 我想独立。"',
        effect: {
          stats: { belonging: 6 },
          npc: { yjie: 2 },
          flag: 'l2u_y_merger_declined_independent',
          requireFlag: 'link2urPath_team',
        },
        feedback: `Y 姐看了你 3 秒。然后她把 napkin 收起来, 没说什么。
她笑了: "OK。你年轻 你应该试试自己。"

"五年后如果你想合并 我还在这里。If we're both still here. And if AI hasn't replaced both of us by then."

走出 Sketch 你松了一口气, 也有点 regret 的预感。
但你知道: 你不是为了"被 Y 姐 acquire" 而努力。`,
      },
      {
        label: '"我想散伙 Team, 回到 Solo。"',
        effect: {
          stats: { belonging: -3, wallet: -200 },
          npc: { yjie: 0 },
          flag: 'l2u_y_merger_team_disbanded',
          requireFlag: 'link2urPath_team',
        },
        feedback: `Y 姐听完没说什么。她说: "OK。Team 解散嘅原因系...你想 Solo? 定系你觉得呢条 team 路走唔通?"

你: "...都有。"

她叹气: "Solo 比 team 更难, 但你可以试。你嘅团员我 inbox 接住, 给佢哋开新的 chapter。"

(后续触发: 团员散场场景, 玩家 wallet 损失 £200 用于 severance, 团员 status 转 'departed_yjie')`,
      },
      {
        label: 'Solo 路径分支 · "我做你 Bespoke 独家 AI 供应商"',
        effect: {
          stats: { belonging: 8, wallet: 200 },
          npc: { yjie: 3 },
          flag: 'l2u_solo_consultant',
          requireFlag: 'link2urPath_solo',
        },
        feedback: `Y 姐: "OK。咁我哋系合作 partner, 唔系合伙。你 invoice me。"

你签了一份 retainer: £200 × 220 个客户/年 = £44000 baseline + bonus。
这是 Solo 路径最优解 — 你不被并购但有稳定 cashflow。`,
      },
    ],
  },

  // 场景 7 · Ch 9 W51-52 · 毕业典礼前最后一面
  {
    id: 'yjie_farewell',
    chapter: 9,
    weekStart: 51,
    weekEnd: 52,
    title: 'Royal Festival Hall 旁 · 最后一杯咖啡',
    flagOnComplete: 'l2u_y_farewell',
    body: `毕业典礼前一天。Royal Festival Hall 旁那家不出名的精品咖啡店。
Y 姐已经到了, 这次穿了一件你没见过的颜色: 深绿色丝绒外套。
她说: "今日唔系工作日。"

她从 tote 里抽出一个小礼物盒。`,
    choices: [
      {
        label: '【展开】 Y 姐说了什么',
        effect: {
          stats: { belonging: 8 },
          npc: { yjie: 3 },
          flag: 'l2u_y_farewell',
        },
        feedback: `不同 path 不同对白 (由 link2urMainline.js Ch 9 引用,根据 link2urPath + merger_decision 分支):

【合并】 "Welcome partner。Real partner。" 礼物是一张 LinkU Bespoke + AI Studio 的双联名 brand 草稿。

【独立 Team】 "你嘅 brand 我 5 年内 reference 给 220 个客户。我 promise。" 礼物是她团队 8 个人手写的明信片。

【Solo Apex】 "I might call you in 3 years if I'm ready to be acquired." 礼物是她第一年接的那只 Borough Market 5 镑充电宝, 装了一封手写信。

【Solo Consultant】 "下年我哋每周一次 strategy call, OK?" 礼物是一本 Y 姐 5 年来的产品手记 (复印件)。`,
      },
    ],
  },
];
