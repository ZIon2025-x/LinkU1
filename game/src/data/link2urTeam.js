// Link2Ur Team 路径 · 5 个可招团员 NPC (spec §5.4)
// 每个团员的 mini-arc 4 节拍: recruited → mentored → clash → departure
//
// 玩家在 Ch 5/6/7/8 招人, 每个团员 specialty 在 AI 广告分工里独立。
// 5 个 specialty 合起来 = 完整 AI 广告 studio。

export const LINK2UR_TEAM_MEMBERS = [
  {
    id: 'team_xiaoyu',
    name: '小雨',
    realName: '李雨彤',
    age: 23,
    school: "King's College London",
    major: '应用语言学 MA',
    specialty: 'ai_copywriting_bilingual',
    specialtyDisplay: 'AI 文案 + 双语本地化',
    recruitedVia: 'aditi_referral',
    minWeek: 23,
    maxWeek: 26,
    baseRating: 4.6,
    baseEnergy: 80,
    cutPercent: 18,
    avatar: '🌸',
    miniArc: [
      {
        phase: 'recruited',
        title: '小雨 · Pret 面谈',
        body: `Pret Tottenham Court Road, 周三下午 2 点。
小雨穿米色运动外套, 没化妆, 头发梳得整齐但有点紧张。
她说话很慢, 用"嗯, 我觉得..." 开头。

你跟她讲三件事:
1. cut 18% (你拿 82%, 她拿 cut 后)
2. 第一单我会陪改
3. 不喜欢可以随时退

她说: "我想试。"`,
      },
      {
        phase: 'mentored',
        title: '小雨 · 第一单 · 蓝瓶茶饮 brand copy',
        body: `小雨第一单是 Carrie 给的 brand copy。她写了 3 个版本, 你帮她改第 4 个。
最后客户用了第 2 个 — 是小雨自己写的, 你没改。

她私聊你: "我以为客户会选你改过的那版。"
你: "客户不傻。"
她沉默了一下: "谢谢。"`,
      },
      {
        phase: 'clash',
        title: '小雨 · 第一次冲突 · 客户偏好你不偏好她',
        body: `Lily 上次单子明确说: "下次我希望你自己来, 不要 team 接。"
你转告小雨。她安静了一会儿。

她: "OK 我懂。是不是我做得不够好?"
你: "不是。客户和员工的 fit 不能强求。"

她那周完单数下降, 你能看出她在自我怀疑。`,
      },
      {
        phase: 'departure',
        title: '小雨 · 毕业 · PhD 申请书',
        body: `W50。小雨拿着 PhD 申请书来找你: "你能帮我写一封 reference letter 吗?
我想申回上海大学应用语言学 PhD, 做'AI 时代双语本地化'方向。"

你: "可以。但你的写作能力我都没指点过, 你是自己长起来的。我写什么?"
她笑了: "你 mentor 过我'客户不傻'。 写那个。"

你给她写了 1200 字的推荐信。
她毕业回上海的飞机上发你一张照片: 她在 Heathrow 的 Costa 喝最后一杯 latte。
"In London I learned how to listen to a client. Thank you 😊"`,
      },
    ],
  },
  {
    id: 'team_kenji',
    name: 'Kenji',
    realName: '健治',
    age: 24,
    school: 'Goldsmiths College',
    major: 'Media MA',
    specialty: 'ai_video_generation',
    specialtyDisplay: 'AI 视频生成 (Sora/Runway)',
    recruitedVia: 'linkedin_dm',
    minWeek: 27,
    maxWeek: 32,
    baseRating: 4.8,
    baseEnergy: 75,
    cutPercent: 22,
    avatar: '🎌',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Kenji · LinkedIn DM',
        body: `LinkedIn DM:
"Hi, I saw your portfolio. I'm Kenji, Goldsmiths Media MA Y1.
I do Sora + Runway commercial work. I want to apply for your team but I'm Japanese.
I think this can be your bridge to Japanese clients in London."

(他的 portfolio: 4 条 30s AI 视频, 1 条是 Tokyo Pop 风格 made with Sora。质量惊艳。)`,
      },
      {
        phase: 'mentored',
        title: 'Kenji · 美容品牌 30s spec',
        body: `Kenji 第一单是给一个香港美容品牌做 30s IG Reels。
他 1 天就交了。视频是 Sora 生成的雾气画面里 overlay 模特实拍片段, BGM 用了一段 80s 港片配乐。

客户: "我们做美容 10 年, 没见过这个 quality。"
Kenji: "I have done 4 versions before this one. The first 3 were... not me."

你才明白: AI 工具不是替代品。是磨刀。`,
      },
      {
        phase: 'clash',
        title: 'Kenji · 想回东京',
        body: `W42。Kenji 喝多了某次 team dinner 后跟你说:
"我妈昨天 video 我。她 72 了, 一个人在 Setagaya。
我想 maybe... 回东京继续做 freelance。
你 ok 吗?"

你说: "你想回就回。"
他: "But this team is mine too. I don't want to just leave."

你给他时间想。但你知道: 他可能要走了。`,
      },
      {
        phase: 'departure',
        title: 'Kenji · 回东京 / 留下',
        body: `W50。Kenji 给你两个选项:
A. 回东京, 在 Tokyo 继续做你的 freelance 合作伙伴 (远程)
B. 留下, 跟随合并 (如 Path B + 合并)

你尊重他的选择。无论选哪个, 他都给你寄了一份手写的 thank you letter + 一个 Tokyo Banana。`,
      },
    ],
  },
  {
    id: 'team_aman',
    name: 'Aman',
    realName: 'Aman Singh',
    age: 25,
    school: 'Imperial College',
    major: 'MEng',
    specialty: 'ads_strategy_data',
    specialtyDisplay: '广告投放 + 数据分析',
    recruitedVia: 'aditi_classmate',
    minWeek: 27,
    maxWeek: 36,
    baseRating: 4.5,
    baseEnergy: 90,
    cutPercent: 12,  // 最便宜
    avatar: '🇮🇳',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Aman · 最便宜 / 最 hungry',
        body: `Aditi 介绍。Aman 是 Imperial MEng Y2, 想转 ad-tech 副业。
他主动报了 £12/h cut (远低于其他团员)。

你: "为什么这么低?"
他: "I need experience more than money. Six months from now I'll be your most expensive person."

你看出他的野心。招进来。`,
      },
      {
        phase: 'mentored',
        title: 'Aman · 第一次 Meta ad campaign',
        body: `Aman 第一单: 蓝瓶茶饮 Meta launch campaign。
他设了 3 个 audience segment + 7 个 creative variants + 4 个 landing pages。
跑了 14 天, ROAS 4.2 (业内平均 1.8)。

Carrie 直接跟你说: "他 worth 你 cut 3 倍。"`,
      },
      {
        phase: 'clash',
        title: 'Aman · 🔴 "我做得多但 cut 一样"',
        body: `W40。Aman 跟你 1-on-1: "Look. I make you the most money in the team.
My ROAS for Carrie is 4.2. Chloe's account management is great but it's not the same.
£12/h cut is what I agreed when I had no leverage. Now I have. I want £22."

(玩家三选一:)
A. 涨到 £22 (Aman 留 + 你利润降)
B. 涨到 £18 (折衷, Aman 不爽但留)
C. 不涨 (Aman 1 周内自己离开)`,
      },
      {
        phase: 'departure',
        title: 'Aman · 取决于 clash 选择',
        body: `根据 W40 clash 选择 (玩家选 A/B/C):

A 涨 £22 → Aman 留到 W52, 跟随合并 (Path B) 或继续 Solo 合作 (Path A)
B 折衷 £18 → Aman 留到 W48 然后离开去 BCG ad-tech 部门
C 不涨 → Aman 离开。3 个月后他在 LinkedIn 写: "Founder integrity matters more than salary."
你看到那条 post 心里不是滋味。`,
      },
    ],
  },
  {
    id: 'team_chloe',
    name: 'Chloe',
    realName: '周婧',
    age: 22,
    school: 'KCL English Literature',
    major: 'BA',
    specialty: 'account_management',
    specialtyDisplay: '客户对接 + ABC 双向客户经理',
    recruitedVia: 'pret_encounter',
    minWeek: 30,
    maxWeek: 38,
    baseRating: 4.7,
    baseEnergy: 70,
    cutPercent: 20,
    avatar: '🎤',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Chloe · Pret 偶遇',
        body: `Pret Bedford Square 早上 8 点。你在改一份 brief。
旁边一个穿 Reformation 连衣裙的女生用粤语普通话英语三种打电话, 30 秒内切换 4 次。
她挂电话, 看见你的 MacBook 上是 LinkU brand brief。

"Sorry to be nosy. Is that for Carrie at 蓝瓶?"
你: "...你怎么知道?"
"我之前给她做过 freelance interpreter 一次。她说过她在找 AI 内容团队。"
她递过来一张名片。

招进来。她是 ABC, 父亲 BBC 父亲, 母亲香港 ABC, 她自己在 KCL 读 English Lit。`,
      },
      {
        phase: 'mentored',
        title: 'Chloe · Paul BBC 采访的协调员',
        body: `Paul 要采访你做 BBC 专题, 但他不会粤语, 他想顺便采访 Y 姐 + 中资客户群体。
Chloe 自告奋勇做 fixer。她 3 天内 lined up 8 个采访对象 + 2 个翻译 + 1 个录音师 + 现场协调。

Paul 后来跟你说: "She's the best fixer I've worked with in London in 7 years."`,
      },
      {
        phase: 'clash',
        title: 'Chloe · 客户 Lily 指名她',
        body: `Lily 通过 Chloe 联系你: "下次 Burberry 那单, 我希望 Chloe 直接和我对接。
你做 strategy 就行, account management 让她做。"

你心里有点不爽 — Lily 是你的 OG 客户。
你跟 Chloe 谈, 她说: "我会让 Lily 知道是 your strategy。我不会越过你。"

你 trust 她。结果客户满意度 +0.4。`,
      },
      {
        phase: 'departure',
        title: 'Chloe · 跟随合并最忠诚',
        body: `W52。无论你选哪条 path, Chloe 都跟着。

Path B + 合并: 她加入 LinkU Bespoke + AI Studio joint, 后来成为 head of account。
Path B + 独立: 她跟你独立, 一年后她说"I'd rather be your #2 than Y 姐's #15."
Path A: 她说 "I'll work part-time for you whenever you need." 兼职到她毕业。`,
      },
    ],
  },
  {
    id: 'team_eric',
    name: 'Eric',
    realName: '陈以晨',
    age: 22,
    school: 'Brunel University',
    major: 'Design BA',
    specialty: 'ai_visual_design',
    specialtyDisplay: 'AI 视觉 (Midjourney) + 电商产品图',
    recruitedVia: 'wangkai_referral',  // 王凯介绍 → 跨圈联动
    minWeek: 41,
    maxWeek: 45,
    baseRating: 4.4,
    baseEnergy: 85,
    cutPercent: 16,
    avatar: '🥡',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Eric · 王凯酒桌拉人',
        body: `Soho 一家烤串店。王凯请客。Eric 是他奶茶店的"半个员工" — 兼职做海报 + 朋友圈。
王凯: "哥们这小子 Midjourney 玩得溜, 你团队需要不?"
Eric: "我想跟你学 AI 视觉。"

你: "我 cut 16%, 你 ok 吗?"
Eric: "OK"。

王凯: "记住, 这小子你照顾好。他妈是我老乡。"`,
      },
      {
        phase: 'mentored',
        title: 'Eric · DTC 美妆产品图首单',
        body: `Jess 给的单: 8 个 SKU 产品图, 各 5 个 angle。
Eric 用 Midjourney + Photoshop refine, 3 天交付。Jess 说"比我用 Shopify default 的好 10 倍"。

你: "你 Photoshop 哪里学的?"
Eric: "B 站。免费的。我 16 岁开始看 PS 教程。"`,
      },
      {
        phase: 'clash',
        title: 'Eric · 🔴 王凯也要他做奶茶店内容',
        body: `跨圈联动场景 (link2urCrossover.js: cross_wangkai_eric_steal):

W43 某天王凯吃饭跟你说: "Eric 这两周给奶茶店做新菜单海报, 我让他暂停你的活两天。OK 吗?"
你: "你说让 Eric 选, 不是你直接 reassign。"
王凯: "嗨, 他 part-time 给我做 longer than 给你做。"

你三选一:
A. 让 Eric 自己选 (公平但你可能输)
B. 涨 cut 留人 (Eric 留 + 王凯关系倒退)
C. 散伙让 (Eric 走 + 你保住和王凯关系)`,
      },
      {
        phase: 'departure',
        title: 'Eric · 取决于 clash 选择',
        body: `根据 W43 clash 选择:

A 让 Eric 选 → 他 50% 概率选你 50% 选王凯 (基于你 npcRel.wangkai vs Eric mentored 阶段评分)
B 涨 cut 留人 → Eric 留 + 王凯 -3 关系
C 散伙让 → Eric 退队 + 王凯 +2 关系 + 你 wallet -£100 severance`,
      },
    ],
  },
];

export function getMiniArcScene(memberId, phase) {
  const member = LINK2UR_TEAM_MEMBERS.find((m) => m.id === memberId);
  if (!member) return null;
  return member.miniArc.find((a) => a.phase === phase) || null;
}
