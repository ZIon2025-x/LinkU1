# Minigame 内容方向 pivot · UK 留学硬核知识 + 高阶学术英语

**日期**：2026-05-16
**Scope**：`src/data/textMinigames.js` + `src/data/lectureMinigame.js` + `src/components/Minigames.jsx`（仅文案）

---

## 背景

当前 minigame 内容方向是 **人文社科理论**（Foucault / Bourdieu / Said / Butler / Hall / Spivak），核心问题：

- Match 必须知道 "Foucault 提出了 panopticon" 才能玩；不是文化研究 / 社会学专业的留学生（特别是 STEM / 商科 / 法律 / 工程）完全没接触
- 之前考虑过营销 pivot，但本质上只是把门槛换给营销专业 — 用户决定改为 **通用 / 跨专业 / 留学生都该学** 的内容方向

新方向：

- **Match** → 留学硬核实用知识（签证 / NHS / 学术诚信 / 银行 / 租房 / 学位制度 等）
- **Lecture** → 高阶学术英语词汇（写 essay 用的、CET-6 / IELTS 7+ 学术高频词）
- **Essay** → 不动（puzzle 内容暂保持）
- **Whitmore** → 不动（剧情教授身份保持，仅 Lecture/Match intro 措辞微调）

## 目标

- **G1**：Match 内容从 12 个理论家替换为 **18 个留学硬核类别**，每类 6-8 个标志物，总 ~120 item。
- **G2**：Lecture 主题词池从理论词替换为 **12 个高阶学术英语主题**，每主题 12-15 个 ★ bonus 词，总 ~160 ★ 词。
- **G3**：跨专业友好 — 任何专业留学生都能从 minigame 中学到日后用得上的东西。
- **G4**：重玩不重复感 — round 抽取 4-12 item，pool 至少 5 倍于 round size。

## Non-Goals

- ❌ 不动 minigame UI（tier 系统 / ? 按钮 / 仪式 / 计时器 全部保留）
- ❌ 不动 Whitmore 角色身份或剧情台词
- ❌ 不动 Essay puzzles
- ❌ 不动其他 NPC 聊天 / 周事件 / Moodle 内容（Foucault 等理论家可在剧情对话残留）
- ❌ 不做 i18n
- ❌ 不动 `src/data/lectureMinigame.js` 中的 RAW_WORDS 字典（继续支持 ~3000 常用英语词识别）

---

## 设计

### Block 1 · Match → 留学硬核知识 18 类

**数据结构同构原 THEORIST_MATCH**（类别 ≡ theorist，item ≡ concept，每 item 唯一归属一个类别）。

#### 18 类列表

| # | 类别（categoryId） | 标志物预览（每类最终 6-8 个） |
|---|---|---|
| 1 | `visa` 签证 | Tier 4 / BRP / NHS Surcharge / PSW / Right to Rent / Biometrics |
| 2 | `nhs` 看病 | GP / 111 / 999 / A&E / Walk-in / Prescription / EHIC |
| 3 | `council_tax` 房费 | Exempt Cert / Single Occupancy / Band / TV License / Direct Debit |
| 4 | `academic_integrity` 学术诚信 | Turnitin / Paraphrase / Similarity Score / Harvard / APA / Mitigating Circumstances |
| 5 | `banking` 银行财务 | Sort Code / Overdraft / Direct Debit / Standing Order / ISA / Contactless |
| 6 | `renting` 租房 | Holding Deposit / Break Clause / EPC / Inventory / Deposit Protection / DPS |
| 7 | `tax_wages` 税工资 | HMRC / NI Number / PAYE / P45 / P60 / Minimum Wage |
| 8 | `academic_writing` 学术写作 | Footnote / Bibliography / Abstract / Citation / Word Count / Cover Sheet |
| 9 | `transport` 交通 | Oyster / Railcard / 16-25 / Coach / TfL / National Rail |
| 10 | `campus_systems` 校园系统 | Moodle / Eduroam / Library Card / NUS Card / Reading Week / Welcome Week |
| 11 | `job_hunt` 求职 | CV / Cover Letter / Sandwich Placement / Milkround / Grad Scheme / Assessment Centre |
| 12 | `saving_money` 省钱 | Meal Deal / Clubcard / Yellow Sticker / Wetherspoons App / Boots Advantage |
| 13 | `degrees` 学位制度 | Undergrad / PGT / PGR / PhD / MSc / MA / MBA / Foundation Year |
| 14 | `grading` 成绩制度 | First / 2:1 / 2:2 / Third / Distinction / Merit / 40% pass |
| 15 | `class_types` 课程类型 | Lecture / Seminar / Tutorial / Lab / Workshop / Office Hours |
| 16 | `assessment` 评估方式 | Coursework / Dissertation / Viva / Open Book / Take-home / Group Project |
| 17 | `online_tools` 网课工具 | Zoom / Teams / Panopto / Blackboard / Padlet / Mentimeter |
| 18 | `uni_groupings` 学校机构 | Russell Group / Red Brick / Plate Glass / Ancient / Oxbridge / QS Top 100 |

#### 数据结构（textMinigames.js）

```jsx
export const UK_KNOWLEDGE_MATCH = {
  categories: [
    { id: 'visa',                name: '签证 / Visa',           items: ['tier4','brp','nhs_surcharge',...] },
    { id: 'nhs',                 name: 'NHS 看病',              items: ['gp','111','999','ae',...] },
    // ... 18 类
  ],
  items: {
    tier4:           { label: 'Tier 4',          desc: '学生签证类别' },
    brp:             { label: 'BRP',             desc: '生物指纹居留卡' },
    nhs_surcharge:   { label: 'NHS Surcharge',   desc: '签证医疗附加费' },
    psw:             { label: 'PSW Visa',        desc: '毕业生工作签证' },
    right_to_rent:   { label: 'Right to Rent',   desc: '租房身份核查' },
    // ... ~120 items 全部定义
  },
};
```

#### Round 选择逻辑（pickMatchRound week-spotlight 扩展）

原 6 个 spotlight 切换点扩到 **18 个**，每 ~3 周轮播：

```js
const SPOTLIGHT_BY_WEEK = [
  [3,  'visa'],            // W1-3
  [6,  'nhs'],             // W4-6
  [9,  'academic_integrity'], // W7-9
  [12, 'banking'],         // W10-12
  [15, 'renting'],         // W13-15
  [18, 'tax_wages'],       // W16-18
  [21, 'academic_writing'],// W19-21
  [24, 'transport'],       // W22-24
  [27, 'campus_systems'],  // W25-27
  [30, 'job_hunt'],        // W28-30
  [33, 'degrees'],         // W31-33
  [36, 'grading'],         // W34-36
  [39, 'class_types'],     // W37-39
  [42, 'assessment'],      // W40-42
  [45, 'online_tools'],    // W43-45
  [48, 'uni_groupings'],   // W46-48
  [51, 'council_tax'],     // W49-51
  [Infinity, 'saving_money'], // W52+
];

function pickWeekSpotlight(week) {
  return SPOTLIGHT_BY_WEEK.find(([upper, _]) => week <= upper)[1];
}
```

Phase / round size 不变（W1-15: 4 类 / 6 item，W16-30: 6 类 / 9 item，W30+: 8 类 / 12 item）。

### Block 2 · Lecture → 高阶学术英语 12 主题

**数据结构同构原 LECTURE_THEMES**（主题名 / weeks / bonus 词 / bias 字母）。

#### 12 主题渐进

| 周 | 主题 | bonus 词预览（每主题最终 12-15 个） |
|---|---|---|
| W1-4 | **学术名词** | METHOD, THESIS, EVIDENCE, CONCEPT, THEORY, REVIEW, ANALYSIS, ARGUMENT, FRAMEWORK, HYPOTHESIS, FINDING, CONCLUSION |
| W5-8 | **学术动词** | ARGUE, REFUTE, ASSERT, IMPLY, INFER, ANALYSE, EXAMINE, EVALUATE, ELABORATE, ADDRESS |
| W9-12 | **学术形容词** | EMPIRICAL, CRITICAL, RIGOROUS, ROBUST, COHERENT, COGENT, NUANCED, SUBSTANTIVE |
| W13-16 | **过渡 / 连接词** | HOWEVER, MOREOVER, NEVERTHELESS, FURTHERMORE, OTHERWISE, ACCORDINGLY, CONSEQUENTLY |
| W17-20 | **量化描述** | SIGNIFICANT, MARGINAL, SUBSTANTIAL, NEGLIGIBLE, MODEST, PROFOUND, MODERATE |
| W21-24 | **逻辑推理** | EXTRAPOLATE, GENERALIZE, CORRELATE, INFERENCE, CAUSATION, RATIONALE, PREMISE |
| W25-28 | **研究方法** | QUALITATIVE, QUANTITATIVE, LONGITUDINAL, METHODOLOGY, VARIABLE, CONTROL, SAMPLE |
| W29-32 | **批判 / 评价** | DICHOTOMY, PARADIGM, ASSUMPTION, LIMITATION, BIAS, FALLACY, OVERSIGHT |
| W33-36 | **GRE 高频** | UBIQUITOUS, EPHEMERAL, AMBIGUOUS, FORTUITOUS, MITIGATE, EXACERBATE, SCRUTINY |
| W37-40 | **数据 / 统计** | VARIABLE, SAMPLE, OUTLIER, DEVIATION, REGRESSION, AVERAGE, MEDIAN, VARIANCE |
| W41-44 | **复杂关系词** | NOTWITHSTANDING, ALBEIT, HEREBY, INASMUCH, WHEREBY, THEREOF, HENCEFORTH |
| W45-52 | **综合复习** | 抽前 11 个主题的 ★ 词池合并 |

#### 数据结构（lectureMinigame.js）

```js
export const LECTURE_THEMES = [
  { id: 'academic_nouns', weeks: [1, 4], name: '学术名词 · Academic Nouns',
    bonus: ['METHOD','THESIS','EVIDENCE','CONCEPT','THEORY',...],
    bias: 'METHODTHESISEVIDENCE' },
  // ... 12 themes
];
```

#### THEME_WORDS 替换

去掉所有理论家关键词（FOUCAULT/PANOPTICON/HABITUS 等），换成上面 12 主题的所有 ★ 词大全（~160 词），让 WORD_SET 能识别这些高阶学术词。

#### pickLectureTheme / lectureTimeForWeek / 其他函数

不动（数据驱动，行为不变）。

### Block 3 · Whitmore + intro 文案微调

最小化改动，保留 Whitmore 教授身份和已有剧情：

| 位置 | 改前 | 改后 |
|---|---|---|
| LectureMinigame intro 第 1 行 | "Whitmore 在黑板上写理论" | "Whitmore 讲 lecture，你想把听到的关键词抓住" |
| LectureMinigame 主题展示 | "Foucault · Power & Gaze" | "学术名词 · Academic Nouns" 等（自动从 LECTURE_THEMES.name 取）|
| MatchMinigame 卡片标题 h2 | "理论家与概念" | "留学知识匹配" |
| MatchMinigame intro 副标题 | "把概念匹配到对的人" | "把这些留学硬核知识分组配对" |
| MatchMinigame intro RulesBody | "期末复习。你列了一张表想搞清谁说了什么。..." | "期末复习。你列了一张表想搞清楚这些留学常识到底属于哪类。..." |
| MatchMinigame play 提示 | "选一个概念 →" / "选一个理论家 →" | "选一个知识点 →" / "选一个类别 →" |
| MatchMinigame done 评语 (line 549-552) | "Aditi 路过看你的笔记本" 类台词不动 | 不动 |

### Block 4 · 不动的部分（明确边界）

- ❌ 不动 minigame UI 渲染 / tier 系统 / ? 按钮 / 仪式
- ❌ 不动 Whitmore 剧情台词 / NPC 描述 / 教授身份
- ❌ 不动 Essay 数据 / EssayMinigame
- ❌ 不动 YellowLabel / Pret / DesignBrief
- ❌ 不动 lectureMinigame.js 的 tier 函数（lectureDirInfo / isLectureAdjacent / scoreWord / generateLectureGrid）
- ❌ 不动 tests/（现有测试不依赖具体主题数据）

---

## 改动清单

```
修改:
  src/data/textMinigames.js
    - 删除 THEORIST_MATCH 常量(line 480-545)
    - 新增 UK_KNOWLEDGE_MATCH 常量(同结构,18 类 + ~120 items)
    - 改 pickMatchRound(week) — 18 个 spotlight 切换点

  src/data/lectureMinigame.js
    - 替换 LECTURE_THEMES (12 个主题,bonus 词 + bias 字母全换)
    - 替换 THEME_WORDS (~160 高阶学术词)
    - pickLectureTheme / lectureTimeForWeek 不动

  src/components/Minigames.jsx
    - Lecture intro 第一行措辞调
    - Match intro 副标题 / RulesBody / play 提示语 / 卡片标题 调
    - import 改 THEORIST_MATCH → UK_KNOWLEDGE_MATCH 引用名 (3 处:Minigames.jsx 顶 import + 2 处使用)

不动:
  渲染逻辑 / tier / ? / 仪式 / Essay 全部
  tests/lectureMinigame.test.js (测 tier API,数据无关)
  tests/components/MinigameRulesModal.test.jsx
```

---

## 风险与边角情况

- **跨周存档兼容**：玩家如果在 W11 时游戏正在玩，重启后切到新数据，主题名会变（"Bourdieu · Habitus" → "学术形容词"）。无 state 序列化问题（state 只存 score / found words / week，不存 theme.id 引用）。**可接受**，老玩家可能短暂困惑。
- **WORD_SET 兼容**：玩家如果连出 "HABITUS"，旧数据下识别（在 THEME_WORDS）；新数据下不识别。这会让连过该词的存档玩家觉得"以前能连的现在不能"。**轻度回归**，可接受 — 这些词本来就不是 RAW_WORDS 通用词。
- **Whitmore 与新主题的小不一致**：Whitmore 是社会理论教授，但 Lecture 主题变成学术英语 — 用户已确认接受。游戏内可视为"Whitmore 这学期开了门学术英语写作课"，无需显式 lampshade。
- **内容写作工作量**：~120 个 Match item 中文释义 + ~160 个 Lecture ★ 词 ≈ 8-12 小时实写。技术改动小，内容是瓶颈。
- **拼写正确性 + 字典命中**：Lecture ★ 词必须 .toUpperCase() 后跟 WORD_SET 比对，所以必须加入 THEME_WORDS 数组。批量添加后跑 tests/lectureMinigame.test.js 不会受影响（tier API 与字典无关）。
- **重玩去重**：当前 pickMatchRound 没有"避免上轮已抽 item"逻辑。若 user 觉得连抽两轮就重复，可加 lastRoundItems prop。**本 spec 暂不做**，先看实际玩感。

---

## 内容写作工作流（实现阶段）

由于内容量大，建议实现阶段分批起草让用户过：

1. **批次 1 - Match 类 1-6**（visa / nhs / council_tax / academic_integrity / banking / renting）— 起草 6 类 × 6-8 item 中文 desc → 用户过 → commit
2. **批次 2 - Match 类 7-12**（tax_wages / academic_writing / transport / campus_systems / job_hunt / saving_money）— 同上
3. **批次 3 - Match 类 13-18**（degrees / grading / class_types / assessment / online_tools / uni_groupings）— 同上
4. **批次 4 - Lecture 主题 1-6** ★ 词扩充
5. **批次 5 - Lecture 主题 7-12** ★ 词扩充
6. **批次 6 - intro 文案调 + Minigames.jsx import 引用名改**

每批次独立 commit，便于回滚 / 中途调整。
