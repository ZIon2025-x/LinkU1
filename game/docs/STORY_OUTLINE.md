# 《异乡》剧情大纲与结构

> 本文从 `src/data/` 25+ 数据文件抽取的真实剧情骨架，作为开发回顾文档。
> 最后更新：2026-05-09

---

## 总体定位

| 项 | 内容 |
|---|---|
| **类型** | 叙事驱动生活模拟 RPG（slice-of-life 留学题材） |
| **同类参考** | 80 Days · Roadwarden · Cart Life · Choice of Games · Persona 5 社交线 |
| **时长** | 1 学年 = Day 0 + 364 天 = 52 周 |
| **主角** | 22-25 岁中国 MSc 研究生（玩家选男/女） |
| **题材** | 真实英国留学生活（无超自然、无战斗、无 3D） |
| **核心机制** | 选择驱动 + 数值管理 + 时间推进 |

---

## 四维数值

| 维度 | 起始 | 来源 | 至高用途 |
|---|---|---|---|
| **学业** academic | 0% | tutorial 出勤、essay、exam、论文 | 出勤率 < 75% → 触发签证撤销 bad ending |
| **钱包** wallet | £2,000（房租已付清）+ £500/月妈妈补贴 | 兼职 / 代购 / 合作做生意 | < 0 → broke bad ending |
| **精力** energy | 100 | 行动消耗、休息恢复 | 每个事件都消耗，决定单日上限 |
| **归属** belonging | 0 | NPC 关系、社交事件、文化融入 | **结局核心维度** — 决定 Tier 4 结局走向 |

---

## 三幕结构

### Act 1 · W0–W12 · 秋学期 · 落地求生
> 主题：从"机票降落"到"我能不能活下去"

#### Day 0
1. **机舱**（Plane Scene）— "11 个小时。你已经在云上 9 个小时了。妈妈在浦东塞了一袋老干妈"
2. **Heathrow T3** — 入关 40 分钟、行李最后一个出来
3. **三选一交通**：
   - 🚇 Tube（£6 / 90min / -15 energy）— 在 Earl's Court 翻箱
   - 🚆 Heathrow Express（£28 / 50min / -5 energy）
   - 🚖 Black Cab（£75 / 60min / +5 energy）— 司机说 "Don't worry, you'll figure it out, love."
4. **公寓门口** — 中介递合同就走："£8,000 房租已收讫"。打开手机银行 £2,000

#### W1 Welcome Week（必办行政）
| 事件 | 关键 | 不办的代价 |
|---|---|---|
| BRP 取证 | Acton Lane Post Office 排 40min | 罚 £125 + 影响续签 |
| GP 注册 | 走 10min 去 surgery 填 GMS1 表 | 三个月后重感冒挂号等 2 周 |
| Open Monzo / HSBC | 5min vs 1h 排队（HSBC 送 £80 Amazon） | 没 UK 卡 = 妈妈钱转不进来 |
| Council Tax 豁免 | 邮件 5min | 每月白扣 £100-150 |
| Student Oyster | TFL £20 + 5 工作日 | 全年通勤多花 £900 |
| Freshers Fair | CSSA 200 人群 / 辩论社全英文 / 只拿 freebies | 错过华人圈/英国圈入口 |
| Bicester Day Trip | 帮代购净赚 £85 / 自己买 £215 / 只逛 -£45 | 无 |
| Loon Fung 华人超市 | £8 老干妈 / 半瓶腐乳 | "我来英国第一次觉得这就是家的味道" |

#### W2-W6 立足 · 4 大 NPC 切入点
| NPC | 切入位置 | 第一句话 |
|---|---|---|
| Sarah | Pub 吧台前犹豫 | "First time? Try a cider." |
| 王凯 | Mei's 中餐馆 | "诶 学弟/学妹？我王凯 PhD 二年级。加微信。" |
| Aditi | 图书馆 4 楼凌晨 1 点 | (推过来一杯咖啡) "Want some? I think we both need it." |
| Whitmore | Office hours | "Come in, do come in. What's on your mind?" |
| 林可儿/林楠 | 图书馆同班同学 | "你的 Foucault 笔记能借我抄一下吗？" |
| Mei 姐 | 中餐馆点单 | "傻孩子 第一次来吧？麻婆豆腐多给你一勺。" |

#### W7 Reading Week — 第一次喘气

#### W8-W11 第一次 Essay 危机
- W11 deadline。Whitmore 把你的 essay 还给你 62 分："Adequate. But your argument lacks conviction."
- 选择：去找他讨论（→ 重写到 78）/ 自己琢磨（→ 65）/ "我尽力了"（→ 接受 62）

#### W12 关键决定 — 圣诞怎么过

---

### Act 2 · W13–W30 · 圣诞 + 春学期 + 复活节 · 关系深化
> 主题：从"我认识他们了"到"我属于哪里"

#### W13-W15 圣诞假期（7 默认 + 5 NPC 暗线）

**默认选项**：
| 选项 | 钱 | 归属 | 标志事件 |
|---|---|---|---|
| 🏠 留伦敦一个人过 | -£50 | -15 | 看完一整季 The Crown |
| 🥟 留下跟其他留学生过 | -£100 | +18 | "5 人挤 Aditi 公寓 茅台 + 春晚" |
| 🗼 巴黎 | -£120 | +12 | "塞纳河边法国老人对你笑了笑走开" |
| 🏰 爱丁堡 | -£60 | +10 | Arthur's Seat 看日出 |
| 🇮🇹 罗马 | -£180 | +14 | "你想起小时候你爸说\'等你大了带你去看罗马\'" |
| ✈️ 回国 14 天 | -£800 | +30 | "妈妈瘦了 爸爸头发更白了" |
| 💼 Mei 姐店打工 | +£600 | +6 | 全是落单的中国人 |

**NPC 圣诞暗线**（需对应 NPC ≥ 6 好感 + 主线进度）：
| 暗线 | 触发条件 | flag | 决定结局走向 |
|---|---|---|---|
| 🌹 Cotswolds 过节（Sarah） | sarah ≥ 6 | `cotswolds_xmas` | Tier 1+2 |
| 💜 印度看 Aditi 爸（Aditi） | aditi ≥ 8 + 主线 ch3 | `visited_india` | Tier 1+2 |
| 🥟 王凯爆肝代购（W凯） | wk ≥ 5 + business 已开 | `xmas_grind` | Tier 1+2 |
| 🍜 Mei 姐家叫"姨"（Mei） | mei ≥ 7 + 兼职过 | `mei_family` | Tier 1+2 |
| 🎓 High Table dinner（Whitmore） | whitmore ≥ 7 | `high_table` | Tier 1+2 |

#### W16-W19 春学期 + 父母来访
**父母线 5 章** — 整个游戏权重最高的副线：
1. **W6 提议** — "我和你爸商量了 春节后来看看你"（视频）
2. **W17 准备** — 妈学 "How. Are. You." 念古诗腔，跟爸吵 1 分钟
3. **W19 接机** — 妈手里捧 8 岁时最爱的饼干，"瘦了瘦了"
4. **W19 逛伦敦** — 爸抚摸学校牌匾："我大学没毕业。爷爷生病我退学回去打工。"
5. **W20 Heathrow 送别** — 妈塞 £100 现金，爸："这一年让你一个人。对不起。"

#### W20-W22 关键事件
- 林可儿/林楠 春节回国错过（你北京 ta 杭州，相亲压力）
- Group Project deadline (W22)
- 妈妈相亲压力（带 partner / solo 两版）

#### W23-W26 春学期收尾
- Essay 2 deadline (W26)
- 学校罢工 / 物价上涨等社会突发事件
- Tutorial 上的主动举手（Whitmore ch3）

#### W27-W30 复活节假期（6 默认 + 5 NPC 暗线）

**默认选项**：
| 选项 | 钱 | 学业 | 标志事件 |
|---|---|---|---|
| 📚 全力复习 | 0 | +25 | "出来发现已经春天了 错过整个樱花季" |
| 🚆 欧铁通票（25 天 5 城市） | -£400 | -8 | "回伦敦发现伦敦看起来好小" |
| 💼 全职打工 | +£1200 | 0 | "瘦 4 公斤 给爸妈转 ¥5000\'我自己赚的\'" |
| 🗼 巴黎 + 阿姆 | -£250 | -3 | "巴黎被偷一次手机 学会钱分三处放" |
| ✈️ 回国 4 周 | -£800 | -10 | "陪爷爷下了 50 盘棋 奶奶塞老干妈" |
| 💻 无薪实习 | 0 | +15 | "推荐信" `easter_internship` |

**NPC 复活节暗线**：
| 暗线 | flag | 配套 |
|---|---|---|
| 🌹 Sarah 欧铁穷游（5 国 21 天） | `eurotrip_sarah` | Sarah 至高 |
| 💜 Aditi 7am pact 4 周 | `easter_aditi_pact` | Aditi 至高 |
| 🥟 王凯 4 周代管店（£1500） | `wangkai_apprentice` | 王凯至高 |
| 🎓 Whitmore 论文密集辅导 | `thesis_polished` | Whitmore 至高 |
| 🍜 Mei 4 周代理经理（£1800） | `mei_manager` | Mei 至高 |

---

### Act 3 · W31–W52 · 考试 + 论文 + 离别
> 主题：从"我能毕业吗"到"我留还是走"

#### W31-W33 复习周（3 周）
- 图书馆死磕 / 突袭 wellbeing 事件（掉头发 / 失眠 / 维 D 不足）

#### W34-W36 期末考试（3 门 MCQ）
1. **Critical Theory**（Foucault / 后结构 / Said / Butler）
2. **Research Methods**（Geertz thick description / triangulation）
3. **Dissertation Prep**（research question / lit gap / Viva）

#### W37-W40 论文 · 文献综述阶段
**选题三选一**：
| 选项 | 学业增益 | flag | 风险 |
|---|---|---|---|
| 保守题目（导师推荐） | +5 | `diss_safe` | 拿不到 distinction |
| 冒险题目（你想做的） | +8 | `diss_ambitious` | "Are you sure?" |
| **个人化题目**（关于你自己留学经历） | +6 + 归属 +10 | `diss_personal` | "This will be hard to write." |

#### W37+ 同步打开"职场战线"（postGrad 事件链）
- **Graduate Route 工签** £2,374（一次性 + 2 年 IHS）— 买"留下来的权利"
- **LinkedIn Open to Work** — 改 location → 6 小时收到第一个 InMail
- **CSSA 群 PwC offer 战报** — 王同学（你认识，挂过一门课，但他爸是知名银行 VP）
- **Sponsor list 1.4 万家** — 80 家过滤；工资门槛 £38,700/年
- **HireVue 第一次** — 5 个 STAR 题，对着 webcam 录
- **China bias 面试** — HR："Just to confirm, do you have right to work in the UK long-term?"
- **妈妈电话 W47** — "你王阿姨女儿选调上岸了 25w + 户口 + 房补 你回来吧"

#### W41-W50 论文 · 调研 + 写作 · 日复一日

#### W49-W51 论文 panic（5 天前）
| 选择 | 后果 |
|---|---|
| 24h 图书馆 5 天不出门 | 写 6,800 字 / 睡 4h 一晚 / 提交 15,003 字 |
| 熬夜 + ChatGPT 帮草稿 | Turnitin AI 标 12% 刚好阈值下，但心里有疙瘩 |
| 申 supervisor extension | GP 信 + housing 压力 → 7 天宽限，但用了一次 buffer |

#### W50-W52 离别周
- **Housing 续签三选一**：续 ensuite -£500 / 合租 Hackney -£800 / 不续准备回国
- **寄箱子回国** — 4 个 60×40×40 / £400 EMS / 半瓶老干妈 + Bonfire Night 大衣
- **最后一次 Pret** — 收银员 Maria："Last week before you go home? Your regulars look like they're saying goodbye to a sandwich." → 送一个免费 cookie
- **最后一次 Mei's** — Mei 姐塞 £200 红包 + 字条 "常回来。这里也是你家。"
- **Mark 搬走** — Tesco £3 卡片 "Cheers for the cooking lessons. Cheers for not telling anyone I cried watching Eurovision (you saw, I know)."
- **回国前最后一通视频** — 妈："家里你的房间妈给你收拾了。床单换了你小时候那套——蓝色小熊那个。"

#### W52 毕业典礼 + 结局解析
- Royal Festival Hall。head of department 念你名字（读音念错 1 个字）
- 如果父母来过 → 他们坐在台下
- 脱学袍时风把流苏吹起来。Sarah："Send it to your mum, mate."
- → **结局表 walk-down 决定文本**

---

## 6 个 NPC 主线总览

| NPC | 线名 | 章数 | 关键节点 | 最高 flag |
|---|---|---|---|---|
| **Sarah** 🌹 | 友情线 | 4 | cider → 图书馆 → Cotswolds → 凌晨 2 点 | `cotswolds_xmas` + `eurotrip_sarah` |
| **王凯** 🥟 | 创业线 | 5 | Mei's 搭话 → Bicester £80 → Soho 奶茶店 → 第一桶金差评 → 回国 vs 留下 | `xmas_grind` + `wangkai_apprentice` |
| **Aditi** 💜 | 互助线 | 5 | 推咖啡 → 互改 essay → 凌晨"爸住院" → 一起做炒饭+chai → Heathrow 拥抱 | `visited_india` + `easter_aditi_pact` |
| **Whitmore** 🎓 | 学术线 | 5 | Office hours → essay 62 分 → tutorial 举手 → coffee 投稿 → 牛津 reference | `high_table` + `thesis_polished` |
| **Mei 姐** 🍜 | 温情线 | 3 | "傻孩子" → 兼职 → 打烊后 1995 年的故事 | `mei_family` + `mei_manager` |
| **林可儿/林楠** 💗 | 恋爱线（可选） | 5 | 借笔记 → Nando's → Trafalgar 跨年告白 → 春节相亲错过 → long-distance/留下/分手 | `linnan_*` 三结局 |

### NPC 跨圈联动事件
- 王凯引荐 Mei 姐 — 闽南话开场
- Sarah 转述 Whitmore 夸你（"He doesn't say that about anyone."）
- Whitmore 让你去找 Aditi（她过劳）
- 三人午餐（Sarah + Aditi）— 主动当桥梁 vs 让她们自己处理
- 王凯遇到 Sarah 在 pub — 中英两个世界第一次碰头
- Mei 姐说起王凯（去年圣诞独自一人）

---

## 3 条副线

### 1. 父母线（5 ch · W6 → W20）
权重最高的单 flag。`parents_visited` 满足 + 学业 ≥ 55 = 触发 **Tier 0 至高结局**。

### 2. Mark · 隔壁房英国男生救赎线（3 ch · W8-W52）
- W8 厨房脏乱叫板 → 触发 `mark_called_out`
- W8+ 11 点带啤酒来道歉 → `mark_apologized`
- W12+ 教他洗烧黑炒锅 → `mark_friend`（之后他每周日来问做饭）
- W50-52 他爸生病搬走 → 留 £3 Tesco 卡片 → `mark_kept_in_touch`

### 3. Wellbeing 心理 / 身体 / 家庭线（散布 W8-W50）
**身体**：
- 维 D 不足（妈视频远程发现脸色不对）
- Pret 增重（一周 5 次 meal deal = 3,750 多余 cal）
- 伦敦硬水掉头发（£15 滤水头）

**心理基础设施**（按递进式）：
- SU Wellbeing 1:1（30 分钟免费 talk session）
- Samaritans 116 123（凌晨 3 点免费热线）
- NHS Talking Therapies（自助 referral，等 8 周 CBT）
- 4:38 AM 危机点

**家庭冲突**：
- 妈"找份稳定工作"（vs 王阿姨女儿中信银行 25w）
- 爸住院（订当天机票回国 / 不回 + 视频陪伴 / 哭一小时）
- 春节相亲压力（带 partner / solo 两版本）

---

## 22 + 2 结局完整列表

### Tier 0 · 至高单 flag — 父母权重（1 个）
| ID | 触发 | 标题 | 中心情节 |
|---|---|---|---|
| `parents_visited_academic` | `parents_visited` + 学业 ≥ 55 | **我让他们看到了** What They Saw | 爸第一次说"对不起"，发家族群"这孩子让我和她妈这一辈子值了"，群里安静 30 秒 |

### Tier 1 · 双 NPC 暗线组合（5 个最稀有）
| ID | 双 flag | 标题 |
|---|---|---|
| `sarah_double` | cotswolds + eurotrip | **一辈子的朋友** Sarah's Best Mate（三年后参加 Sarah 婚礼，伴娘致辞 "her family is my family"） |
| `aditi_double` | india + pact | **一封孟买来的信** Letter from Mumbai（Aditi 写信告诉你她爸去世前感谢） |
| `mei_double` | family + manager | **Lucky Star 的少东家** Auntie's Heir（30% 干股管伦敦扩张，5 年 7 家店） |
| `whitmore_double` | high table + polished | **《剑桥评论》的作者** A Voice in Print（论文 distinction + 期刊发表，他退休前对你说 "Call me James"） |
| `wangkai_double` | xmas grind + apprentice | **"哥们 仗义"** Brothers in Bubble Tea（Lucky Tea 32 家店，福布斯 30 under 30） |

### Tier 2 · 单 NPC 延伸（6 个）
| ID | 单 flag | 标题 |
|---|---|---|
| `sarah_cotswolds` | cotswolds_xmas | **Cotswolds 的窗** A Window in the Hills（妈跟 Sarah 妈在厨房比手势教做饺子和 Yorkshire pudding） |
| `aditi_india` | visited_india | **印度的春天** Spring in Mumbai（去孟买半年做客座研究员） |
| `mei_family` | mei_family | **叫一声"姨"** Calling Her "Auntie" |
| `whitmore_high_table` | high_table | **坐到桌子那头** A Seat at the Table（三年后回大学做 lecturer） |
| `wangkai_grind_or_apprentice` | xmas OR easter | **£2500 的那个晚上** The £2500 Night |
| `eurotrip_sarah` | eurotrip_sarah | **5 个国家的春天** Spring in Five Countries（每年 4 月她发"I miss." 你回"Me too."） |
| `easter_aditi_pact` | easter_aditi_pact | **把彼此变好的人** Made Each Other Better（毕业后 6 年每天 7am zoom） |

### 林可儿/林楠 三结局（恋爱线）
| ID | 触发 | 标题 |
|---|---|---|
| `linnan_stayed` | linnan_stay_together | **我们都留了下来** Together in London（Hackney 二居 / ta 妈第四天打来"那孩子大陆的？"） |
| `linnan_ldr` | linnan_long_distance | **一年后她/他真的来了** A Year, Then Forever（"我裸辞了 我想跟你试一试"） |
| `linnan_broke` | linnan_breakup | **没有谁的错** Neither Wrong（LinkedIn 看到 ta 升职"那条路我没走"） |

### Tier 3 · 原稀有结局（4 个）
| ID | 触发 | 标题 |
|---|---|---|
| `oxford` | oxford_ref + 学业 ≥ 70 | **牛津的录取信** The Oxford Letter（Christ Church DPhil 全奖） |
| `returned_with_wk` | returned_with_wk | **回去创业** The Bet（三年扩到 12 家奶茶店） |
| `aditi_sarah` | Aditi ≥ 5ch + Sarah ≥ 4ch | **我的人在异乡** My People（"这是我朋友"五个字在嘴里转了一年） |
| `mei_belonging` | Mei ≥ 3ch + 归属 ≥ 50 | **留在 Mei 姐身边** Family（中餐馆做一年还债给那个孤单的自己） |

### Tier 4 · 通用兜底（4 个 catch-all）
| ID | 触发 | 标题 |
|---|---|---|
| `becoming` | 归属 ≥ 60 + 学业 ≥ 55 | **找到自己** Becoming（"你成了一个新的人"） |
| `graduated_numb` | 归属 < 25 | **麻木地毕业** Graduated（想不起上次笑出声是什么时候） |
| `survivor` | 钱包 ≥ 1500 + 归属 < 45 | **打工人** Survivor（说得最多的英语是"哥要不要加波霸"） |
| `staying` | 兜底 catch-all | **留下来** Staying（"已经在英国五年了"） |

### Special Bad Endings（中途触发，跳过结局表）
- `visa_curtailed` — 出勤率太低 → Home Office 撤销签证 → 28 天离境
- `broke` — 钱包负数 → 撑不下去 订机票回国 给爸妈打电话没敢说真话

---

## 核心叙事张力

游戏在拉扯 **4 种压力**：

1. **垂直**：父母期望（中国剧本）vs 自我探索（异乡剧本）
2. **横向**：英国本地圈（Sarah/Whitmore）vs 华人圈（王凯/Mei）vs 国际生圈（Aditi/Lin）
3. **时间**：每天 3 个 action point + 365 天的总账
4. **金钱 vs 自我**：£2,374 PSW 工签买"留下来的权利" vs ¥250k 中信银行管培生 + 户口

→ **所有结局其实都在回答一个问题：你到底属于哪里？**

---

## 数据文件索引

| 文件 | 内容 |
|---|---|
| `calendar.js` | 52 周学年节奏（Welcome / Term / Reading / Christmas / Spring / Easter / Revision / Exam / Dissertation） |
| `onboarding.js` | Day 0 机舱 + Heathrow + 三选一交通 + 公寓门口 |
| `welcomeWeek.js` | W1 必办行政（BRP/GP/银行/Council Tax/Oyster/Freshers/Bicester/Loon Fung） |
| `dailyLife.js` | 日常事件池（Mark 厨房 / 房间 paper-thin walls / Tesco 黄标 etc） |
| `npcs.js` | 6 NPC 定义 + 跨圈联动事件 |
| `storylines.js` | 6 NPC 主线 3-5 章 |
| `parentsStory.js` | 父母线 5 章 |
| `markArc.js` | Mark 救赎 3 章 |
| `wellbeing.js` | 身心健康 + 家庭冲突散布事件 |
| `cultureFriction.js` | 文化摩擦 / 罢工 / 物价 / 学术圈细节 |
| `holidays.js` | 圣诞 + 复活节默认选项 + NPC 暗线 |
| `exams.js` | 期末 MCQ + 论文选题 |
| `endGame.js` | W30+ 房子 / 论文 panic / 离别周 / 毕业典礼 |
| `postGrad.js` | W37+ PSW 工签 / Sponsor list / HireVue / China bias 面试 |
| `flatHunt.js` | 第二年合租房细节（如果留下） |
| `jobHuntDeep.js` | 进阶职场叙事（spring week / interview rounds） |
| `meiWork.js` | Mei 餐厅打工事件 |
| `link2ur.js` | 平台任务系统（接单/发单） |
| `dreams.js` `insomnia.js` `nostalgia.js` | 失眠 / 梦境 / 想家 散布事件 |
| `festivals.js` | 中秋 / 春节 / Bonfire Night / Boxing Day Sale |
| `echoes.js` | 结局回响（NPC 留下的话）|
| `endings.js` | 22 + 2 结局表 + resolveEnding 函数 |
| `achievements.js` | 41 个成就（按稀有度 common/rare/epic/legendary）|
