# Minigame 内容方向 pivot · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Match 和 Lecture 的内容从 humanities 理论换成 UK 留学硬核知识 + 高阶学术英语，让所有专业留学生都能玩并学到东西。

**Architecture:** 增量式 — 先在数据文件里建新结构（不动旧的），分 5 个 batch 把内容填进新结构（每 batch 一次 commit，便于审核 + 回滚），最后一个 atomic commit 删旧 / 换名 / 改 Minigames.jsx 引用与文案。

**Tech Stack:** 纯数据 + 少量字符串改动，没有新依赖、没有新组件、没有新测试。

**Spec：** `docs/superpowers/specs/2026-05-16-minigame-content-pivot-design.md`

**Branch policy：** 直接 commit 到 `main`（per `feedback_direct_to_main`），不开 feature 分支。

---

## File Structure

```
修改:
  src/data/textMinigames.js
    - 新增 UK_KNOWLEDGE_MATCH (18 类 + ~110 items)
    - 后期删除 THEORIST_MATCH
    - 后期 pickMatchRound 改用新结构 + 18 spotlight 切换

  src/data/lectureMinigame.js
    - 新增 LECTURE_THEMES_V2 + THEME_WORDS_V2
    - 后期删除旧 LECTURE_THEMES + THEME_WORDS,V2 改名替换

  src/components/Minigames.jsx
    - import THEORIST_MATCH → UK_KNOWLEDGE_MATCH
    - 6 处文案微调 (intro / 标题 / 选项提示)

不动:
  渲染逻辑 / tier 系统 / ? 按钮 / 仪式 / Essay
  tests/ (不依赖具体主题数据)
```

**所有 task 的 content draft 都是初稿** — 实施时 commit 前后用户可随时改任何 item label / desc / bonus 词。

---

## Task 1: 数据文件加 skeleton (空结构,不接线)

**Files:**
- Modify: `src/data/textMinigames.js`
- Modify: `src/data/lectureMinigame.js`

- [ ] **Step 1: 在 textMinigames.js 加 UK_KNOWLEDGE_MATCH 空结构**

打开 `src/data/textMinigames.js`，找到 `export const THEORIST_MATCH = {` 行（约 line 480）。在该行**之前**插入：

```jsx
// ============================================================
// UK 留学硬核知识 Match —— 取代 THEORIST_MATCH（内容方向 pivot, spec 2026-05-16）
// 数据结构同构 THEORIST_MATCH:
//   { categories: [{ id, name, items: [id...] }], items: { id: { label, desc } } }
// 18 categories × 6-8 items = ~110 items 总池。每 item 唯一归属一个 category。
// ============================================================
export const UK_KNOWLEDGE_MATCH = {
  categories: [
    // Batch 2 (Task 2): visa / nhs / council_tax / academic_integrity / banking / renting
    // Batch 3 (Task 3): tax_wages / academic_writing / transport / campus_systems / job_hunt / saving_money
    // Batch 4 (Task 4): degrees / grading / class_types / assessment / online_tools / uni_groupings
  ],
  items: {
    // Filled in batches across Task 2 / 3 / 4
  },
};

```

- [ ] **Step 2: 在 lectureMinigame.js 加 V2 空结构**

打开 `src/data/lectureMinigame.js`，找到 `export const LECTURE_THEMES = [` 行。在该行**之前**插入：

```jsx
// ============================================================
// V2 主题池 —— 取代 LECTURE_THEMES（内容方向 pivot, spec 2026-05-16）
// 12 主题 × 12-15 bonus 词 = ~150 ★ 词总池。Task 7 atomic swap 时替换 LECTURE_THEMES + THEME_WORDS。
// ============================================================
export const LECTURE_THEMES_V2 = [
  // Batch 5 (Task 5): W1-24 themes 1-6
  // Batch 6 (Task 6): W25-52 themes 7-12
];

// V2 bonus 词大全（去重）—— Task 7 atomic swap 时替换 THEME_WORDS
const THEME_WORDS_V2 = [];

```

- [ ] **Step 3: 验证文件仍能编译**

Run: `cd F:/python_work/LinkU/game && npm run build`
Expected: 编译通过（新加的常量没引用 = 无影响）。

- [ ] **Step 4: Commit**

```bash
git add src/data/textMinigames.js src/data/lectureMinigame.js
git commit -m "feat(minigame): 加 UK_KNOWLEDGE_MATCH + LECTURE_THEMES_V2 空结构 (内容 pivot 第 1 步)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Match Batch 1 —— 类 1-6 (visa / nhs / council_tax / academic_integrity / banking / renting)

**Files:**
- Modify: `src/data/textMinigames.js`

- [ ] **Step 1: 在 UK_KNOWLEDGE_MATCH.categories 加 6 个类别**

把 Task 1 加的 `categories: []` 数组改为：

```jsx
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
    // Batch 3 (Task 3) appends 6 more here
    // Batch 4 (Task 4) appends 6 more here
  ],
```

- [ ] **Step 2: 在 UK_KNOWLEDGE_MATCH.items 加 35 个 item 定义**

把 Task 1 加的 `items: {}` 改为：

```jsx
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
    // Batch 3 (Task 3) appends ~36 more here
    // Batch 4 (Task 4) appends ~39 more here
  },
```

- [ ] **Step 2.5: 验证文件仍能编译 + 不破坏现有游戏**

Run: `cd F:/python_work/LinkU/game && npm run build && npm test`
Expected: 编译过、362 pass / 8 pre-existing fail（不增不减）。

- [ ] **Step 3: Commit**

```bash
git add src/data/textMinigames.js
git commit -m "feat(minigame): Match Batch 1 — 类 1-6 (visa/NHS/Council Tax/学术诚信/银行/租房, 35 items)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Match Batch 2 —— 类 7-12 (tax_wages / academic_writing / transport / campus_systems / job_hunt / saving_money)

**Files:**
- Modify: `src/data/textMinigames.js`

- [ ] **Step 1: 把 6 类 append 到 categories 数组**

找到 `UK_KNOWLEDGE_MATCH.categories` 数组中的注释 `// Batch 3 (Task 3) appends 6 more here`，**替换**为：

```jsx
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
    // Batch 4 (Task 4) appends 6 more here
```

- [ ] **Step 2: 把 36 个 item 定义 append 到 items 对象**

找到 items 对象中的注释 `// Batch 3 (Task 3) appends ~36 more here`，**替换**为：

```jsx
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
    sandwich_placement:{label: 'Sandwich Placement', desc: '三明治课程实习年（本科第 3 年）' },
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
    // Batch 4 (Task 4) appends ~39 more here
```

- [ ] **Step 3: 验证 + Commit**

Run: `cd F:/python_work/LinkU/game && npm run build`
Expected: 编译通过。

```bash
git add src/data/textMinigames.js
git commit -m "feat(minigame): Match Batch 2 — 类 7-12 (税/学术写作/交通/校园/求职/省钱, 36 items)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Match Batch 3 —— 类 13-18 (degrees / grading / class_types / assessment / online_tools / uni_groupings)

**Files:**
- Modify: `src/data/textMinigames.js`

- [ ] **Step 1: 把 6 类 append 到 categories 数组**

找到 `// Batch 4 (Task 4) appends 6 more here`，**替换**为：

```jsx
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
```

- [ ] **Step 2: 把 ~39 个 item 定义 append 到 items 对象**

找到 `// Batch 4 (Task 4) appends ~39 more here`，**替换**为：

```jsx
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
```

- [ ] **Step 3: 验证 + Commit**

Run: `cd F:/python_work/LinkU/game && npm run build`
Expected: 编译通过。

```bash
git add src/data/textMinigames.js
git commit -m "feat(minigame): Match Batch 3 — 类 13-18 (学位/成绩/课程类型/评估/网课/大学集团, 39 items)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Lecture Batch 1 —— W1-24 主题 1-6

**Files:**
- Modify: `src/data/lectureMinigame.js`

- [ ] **Step 1: 把 6 个主题 append 到 LECTURE_THEMES_V2 数组**

找到 `// Batch 5 (Task 5): W1-24 themes 1-6`，**替换**为：

```jsx
  { id: 'academic_nouns',    weeks: [1, 4],    name: '学术名词 · Academic Nouns',
    bonus: ['METHOD','THESIS','EVIDENCE','CONCEPT','THEORY','REVIEW','ANALYSIS','ARGUMENT','FRAMEWORK','HYPOTHESIS','FINDING','CONCLUSION','PERSPECTIVE','APPROACH','CRITIQUE'],
    bias: 'METHODTHESISEVIDENCEANALYSIS' },
  { id: 'academic_verbs',    weeks: [5, 8],    name: '学术动词 · Academic Verbs',
    bonus: ['ARGUE','REFUTE','ASSERT','IMPLY','INFER','ANALYSE','EXAMINE','EVALUATE','ELABORATE','ADDRESS','COMPARE','CONTRAST'],
    bias: 'ARGUEEXAMINEVALUATE' },
  { id: 'academic_adjs',     weeks: [9, 12],   name: '学术形容词 · Academic Adjectives',
    bonus: ['EMPIRICAL','CRITICAL','RIGOROUS','ROBUST','COHERENT','COGENT','NUANCED','SUBSTANTIVE','INHERENT','RELEVANT','SIGNIFICANT','VIABLE'],
    bias: 'EMPIRICALROBUSTCOHERENT' },
  { id: 'transition_words',  weeks: [13, 16],  name: '过渡 / 连接词 · Transitions',
    bonus: ['HOWEVER','MOREOVER','NEVERTHELESS','FURTHERMORE','OTHERWISE','ACCORDINGLY','CONSEQUENTLY','HENCE','THEREFORE','THUS','MEANWHILE','WHEREAS'],
    bias: 'HOWEVERTHEREFOREHENCE' },
  { id: 'quantifiers',       weeks: [17, 20],  name: '量化描述 · Quantifiers',
    bonus: ['SIGNIFICANT','MARGINAL','SUBSTANTIAL','NEGLIGIBLE','MODEST','PROFOUND','MODERATE','CONSIDERABLE','MINIMAL','EXTENSIVE','NOTABLE','PARTIAL'],
    bias: 'SIGNIFICANTSUBSTANTIALMODEST' },
  { id: 'reasoning',         weeks: [21, 24],  name: '逻辑推理 · Reasoning',
    bonus: ['EXTRAPOLATE','GENERALIZE','CORRELATE','INFERENCE','CAUSATION','RATIONALE','PREMISE','DEDUCE','CONCLUDE','JUSTIFY','REASON','VALIDATE'],
    bias: 'INFERENCECAUSATIONREASON' },
  // Batch 6 (Task 6) appends 6 more here
```

- [ ] **Step 2: 把 batch 1 的 bonus 词 append 到 THEME_WORDS_V2**

找到 `const THEME_WORDS_V2 = [];`，**替换**为：

```jsx
// V2 bonus 词大全（去重）—— Task 7 atomic swap 时替换 THEME_WORDS
const THEME_WORDS_V2 = [
  // Batch 5 (Task 5) — themes 1-6
  'METHOD','THESIS','EVIDENCE','CONCEPT','THEORY','REVIEW','ANALYSIS','ARGUMENT','FRAMEWORK','HYPOTHESIS','FINDING','CONCLUSION','PERSPECTIVE','APPROACH','CRITIQUE',
  'ARGUE','REFUTE','ASSERT','IMPLY','INFER','ANALYSE','EXAMINE','EVALUATE','ELABORATE','ADDRESS','COMPARE','CONTRAST',
  'EMPIRICAL','CRITICAL','RIGOROUS','ROBUST','COHERENT','COGENT','NUANCED','SUBSTANTIVE','INHERENT','RELEVANT','SIGNIFICANT','VIABLE',
  'HOWEVER','MOREOVER','NEVERTHELESS','FURTHERMORE','OTHERWISE','ACCORDINGLY','CONSEQUENTLY','HENCE','THEREFORE','THUS','MEANWHILE','WHEREAS',
  'MARGINAL','SUBSTANTIAL','NEGLIGIBLE','MODEST','PROFOUND','MODERATE','CONSIDERABLE','MINIMAL','EXTENSIVE','NOTABLE','PARTIAL',
  'EXTRAPOLATE','GENERALIZE','CORRELATE','INFERENCE','CAUSATION','RATIONALE','PREMISE','DEDUCE','CONCLUDE','JUSTIFY','REASON','VALIDATE',
  // Batch 6 (Task 6) — themes 7-12
];

```

(注意：'SIGNIFICANT' 已在 quantifiers theme 出现一次，academic_adjs theme 也包含，去重时只列一次。)

- [ ] **Step 3: 验证 + Commit**

Run: `cd F:/python_work/LinkU/game && npm run build`
Expected: 编译通过。

```bash
git add src/data/lectureMinigame.js
git commit -m "feat(lecture): V2 Batch 1 — 主题 1-6 (学术名词/动词/形容词/过渡/量化/推理, 74 ★ 词)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Lecture Batch 2 —— W25-52 主题 7-12

**Files:**
- Modify: `src/data/lectureMinigame.js`

- [ ] **Step 1: 把剩 6 主题 append**

找到 `// Batch 6 (Task 6) appends 6 more here`，**替换**为：

```jsx
  { id: 'research_methods',  weeks: [25, 28],  name: '研究方法 · Research Methods',
    bonus: ['QUALITATIVE','QUANTITATIVE','LONGITUDINAL','METHODOLOGY','VARIABLE','CONTROL','SAMPLE','POPULATION','SURVEY','INTERVIEW','FIELDWORK','CASE'],
    bias: 'QUALITATIVESAMPLECONTROL' },
  { id: 'critique',          weeks: [29, 32],  name: '批判 / 评价 · Critique',
    bonus: ['DICHOTOMY','PARADIGM','ASSUMPTION','LIMITATION','BIAS','FALLACY','OVERSIGHT','FLAW','GAP','CONTRADICTION','AMBIGUITY','WEAKNESS'],
    bias: 'PARADIGMASSUMPTIONBIAS' },
  { id: 'gre_high_freq',     weeks: [33, 36],  name: 'GRE 高频词 · GRE Vocab',
    bonus: ['UBIQUITOUS','EPHEMERAL','AMBIGUOUS','FORTUITOUS','MITIGATE','EXACERBATE','SCRUTINY','RESILIENT','PARSIMONIOUS','AUSTERE','SAGACIOUS','OSTENSIBLE'],
    bias: 'UBIQUITOUSMITIGATESCRUTINY' },
  { id: 'data_stats',        weeks: [37, 40],  name: '数据 / 统计 · Data & Stats',
    bonus: ['OUTLIER','DEVIATION','REGRESSION','AVERAGE','MEDIAN','VARIANCE','CORRELATION','COEFFICIENT','DISTRIBUTION','PERCENTILE','RATIO','MEAN'],
    bias: 'OUTLIERDEVIATIONAVERAGE' },
  { id: 'complex_rel',       weeks: [41, 44],  name: '复杂关系词 · Complex Relations',
    bonus: ['NOTWITHSTANDING','ALBEIT','HEREBY','INASMUCH','WHEREBY','THEREOF','HENCEFORTH','INSOFAR','BESIDES','ASIDE','RATHER','SAVE'],
    bias: 'NOTWITHSTANDINGALBEIT' },
  { id: 'comprehensive',     weeks: [45, 99],  name: '综合复习 · Comprehensive',
    bonus: ['THESIS','EVIDENCE','ARGUE','EMPIRICAL','HOWEVER','SIGNIFICANT','INFERENCE','METHODOLOGY','PARADIGM','UBIQUITOUS','OUTLIER','NOTWITHSTANDING','ANALYSE','FRAMEWORK','HYPOTHESIS'],
    bias: 'EMPIRICALPARADIGMVARIABLE' },
```

- [ ] **Step 2: 把剩余 bonus 词 append 到 THEME_WORDS_V2**

找到 `// Batch 6 (Task 6) — themes 7-12`，**替换**为：

```jsx
  // Batch 6 (Task 6) — themes 7-12
  'QUALITATIVE','QUANTITATIVE','LONGITUDINAL','METHODOLOGY','VARIABLE','CONTROL','SAMPLE','POPULATION','SURVEY','INTERVIEW','FIELDWORK','CASE',
  'DICHOTOMY','PARADIGM','ASSUMPTION','LIMITATION','BIAS','FALLACY','OVERSIGHT','FLAW','GAP','CONTRADICTION','AMBIGUITY','WEAKNESS',
  'UBIQUITOUS','EPHEMERAL','AMBIGUOUS','FORTUITOUS','MITIGATE','EXACERBATE','SCRUTINY','RESILIENT','PARSIMONIOUS','AUSTERE','SAGACIOUS','OSTENSIBLE',
  'OUTLIER','DEVIATION','REGRESSION','AVERAGE','MEDIAN','VARIANCE','CORRELATION','COEFFICIENT','DISTRIBUTION','PERCENTILE','RATIO','MEAN',
  'NOTWITHSTANDING','ALBEIT','HEREBY','INASMUCH','WHEREBY','THEREOF','HENCEFORTH','INSOFAR','BESIDES','ASIDE','RATHER','SAVE',
  // 综合复习 theme 用前 11 主题的子集,无新词
```

- [ ] **Step 3: 验证 + Commit**

Run: `cd F:/python_work/LinkU/game && npm run build`
Expected: 编译通过。

```bash
git add src/data/lectureMinigame.js
git commit -m "feat(lecture): V2 Batch 2 — 主题 7-12 (研究方法/批判/GRE/数据/复杂关系词/综合, 76 ★ 词)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Atomic Swap —— 删旧 / 改名 / 接 Minigames.jsx

**Files:**
- Modify: `src/data/textMinigames.js`
- Modify: `src/data/lectureMinigame.js`
- Modify: `src/components/Minigames.jsx`

### Step 1: textMinigames.js —— 删除 THEORIST_MATCH + 改 pickMatchRound

在 `src/data/textMinigames.js`：

**(a) 删除 `export const THEORIST_MATCH = { ... };`** —— 整个常量定义（约 line 480-545）

**(b) 把 `UK_KNOWLEDGE_MATCH` 重命名为 `THEORIST_MATCH`** —— 用 Edit 工具 `replace_all`，把所有 `UK_KNOWLEDGE_MATCH` 替换为 `THEORIST_MATCH`（包括注释和定义本身）。这样 Minigames.jsx 的 import 不用改。

> 注：之所以保留旧名字 `THEORIST_MATCH` 而不是引入新名，是为了 Minigames.jsx 引用面更小。语义上虽然不再是 theorist，但作为内部 ID 可接受。

**(c) 把 `pickMatchRound(week)` 的 mustInclude 切换逻辑** 替换为：

```jsx
/**
 * 按周抽 match round。phase 1 (W2-15): 4 类 + 6 items;
 * phase 2 (W16-30): 6 类 + 9 items; phase 3 (W30+): 8 类 + 12 items。
 * spotlight 每 ~3 周轮换，一年覆盖 18 类。
 */
export function pickMatchRound(week) {
  let phase, theoristCount, conceptCount;
  if (week <= 15) { phase = 1; theoristCount = 4; conceptCount = 6; }
  else if (week <= 30) { phase = 2; theoristCount = 6; conceptCount = 9; }
  else { phase = 3; theoristCount = 8; conceptCount = 12; }

  // spotlight 每 3 周轮换 18 类
  const SPOTLIGHT = [
    [3,  'visa'], [6,  'nhs'], [9,  'academic_integrity'], [12, 'banking'],
    [15, 'renting'], [18, 'tax_wages'], [21, 'academic_writing'], [24, 'transport'],
    [27, 'campus_systems'], [30, 'job_hunt'], [33, 'degrees'], [36, 'grading'],
    [39, 'class_types'], [42, 'assessment'], [45, 'online_tools'], [48, 'uni_groupings'],
    [51, 'council_tax'], [Infinity, 'saving_money'],
  ];
  const mustInclude = SPOTLIGHT.find(([upper]) => week <= upper)[1];

  const allCategories = THEORIST_MATCH.categories;
  const mustC = allCategories.find(c => c.id === mustInclude);
  const others = allCategories.filter(c => c.id !== mustInclude).sort(() => Math.random() - 0.5);
  const categories = [mustC, ...others.slice(0, theoristCount - 1)];

  // item pool: 从选出的 categories 各取 1-2 个 + 填满到 conceptCount
  const conceptIds = [];
  categories.forEach(c => {
    const picks = c.items.slice().sort(() => Math.random() - 0.5).slice(0, 2);
    conceptIds.push(...picks);
  });
  while (conceptIds.length < conceptCount) {
    const allItems = categories.flatMap(c => c.items);
    const candidate = allItems[Math.floor(Math.random() * allItems.length)];
    if (!conceptIds.includes(candidate)) conceptIds.push(candidate);
  }
  while (conceptIds.length > conceptCount) conceptIds.pop();

  return { phase, theorists: categories, concepts: conceptIds };
}
```

> 注：返回 shape 保持 `{ phase, theorists, concepts }` 以兼容 Minigames.jsx，但 `theorists` 实际是 categories 数组。Minigames.jsx 已经把 `roundData.theorists` 当数组处理，无需改。

### Step 2: lectureMinigame.js —— 删旧 LECTURE_THEMES + THEME_WORDS，V2 改名

在 `src/data/lectureMinigame.js`：

**(a) 删除整个旧 `export const LECTURE_THEMES = [ ... ];`** —— 整个 12-theme 数组（约 line 81-118）

**(b) 删除整个旧 `THEME_WORDS = [ ... ];`** —— 整个数组（约 line 53-70）

**(c) 把 `LECTURE_THEMES_V2` 重命名为 `LECTURE_THEMES`** —— `replace_all`

**(d) 把 `THEME_WORDS_V2` 重命名为 `THEME_WORDS`** —— `replace_all`

**(e) 检查 WORD_SET** —— 找到 line ~72 附近：

```jsx
export const WORD_SET = (() => {
  const s = new Set();
  RAW_WORDS.forEach(w => s.add(w.toUpperCase()));
  THEME_WORDS.forEach(w => s.add(w));
  return s;
})();
```

确认不变（已自动用新 THEME_WORDS）。

### Step 3: Minigames.jsx —— 文案微调（6 处）

在 `src/components/Minigames.jsx`，做以下精确替换（注意每条都唯一）：

**(a) LectureRulesBody 第一行**（line ~651 模块级 LectureRulesBody）：
```jsx
// 旧:
Whitmore 在黑板上写理论。你的笔记本上是一团字母。<br/>
// 新:
Whitmore 讲 lecture，你想把听到的关键词抓住。笔记本上是一团字母。<br/>
```

**(b) Match 卡片 h2 标题**（MatchMinigame 内 ~line 660）：
```jsx
// 旧:
<h2 className="text-xl mb-1 font-light">理论家与概念</h2>
// 新:
<h2 className="text-xl mb-1 font-light">留学知识匹配</h2>
```

**(c) Match 卡片副标题**（同区域 ~line 661）：
```jsx
// 旧:
<div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>把概念匹配到对的人</div>
// 新:
<div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>把这些留学硬核知识分组配对</div>
```

**(d) MatchRulesBody 全文**（模块级 ~line 584）：
```jsx
// 旧:
期末复习。你列了一张表想搞清谁说了什么。<br/>
<br/>
· 把 {totalConcepts} 个概念匹配到对应的理论家<br/>
· 步骤：先点一个概念 → 再点理论家<br/>
· 全部匹配完看评分，对越多 academic 越高<br/>
· 5/6+ 还有 belonging 加成
// 新:
期末复习。你列了一张表想搞清楚这些留学常识到底属于哪类。<br/>
<br/>
· 把 {totalConcepts} 个知识点匹配到对应的类别<br/>
· 步骤：先点一个知识点 → 再点类别<br/>
· 全部匹配完看评分，对越多 academic 越高<br/>
· 5/6+ 还有 belonging 加成
```

**(e) Match play phase 提示语**（MatchMinigame 内 ~line 700 的 select 提示）：
```jsx
// 旧:
{selectedConcept ? '选一个理论家 →' : '选一个概念 →'}
// 新:
{selectedConcept ? '选一个类别 →' : '选一个知识点 →'}
```

**(f) Match play 标题 "理论家"** （MatchMinigame 内 ~line 727）：
```jsx
// 旧:
<div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>理论家</div>
// 新:
<div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>类别</div>
```

**(g) MinigameRulesModal title for Match**（~line 753）：
```jsx
// 旧:
title="MATCH · 理论家与概念"
// 新:
title="MATCH · 留学知识匹配"
```

### Step 4: 跑全套测试 + build

Run: `cd F:/python_work/LinkU/game && npm test && npm run build`
Expected: 362 pass / 8 pre-existing fail（state.test.js 不相关），build 通过。

### Step 5: Commit (atomic)

```bash
git add src/data/textMinigames.js src/data/lectureMinigame.js src/components/Minigames.jsx
git commit -m "feat(minigame): 内容方向 pivot — UK 留学硬核知识 + 高阶学术英语 (atomic swap)

- textMinigames.js: 删 THEORIST_MATCH 旧数据, UK_KNOWLEDGE_MATCH 改名替换;
  pickMatchRound 18 spotlight 轮换
- lectureMinigame.js: 删旧 LECTURE_THEMES + THEME_WORDS, V2 改名替换
- Minigames.jsx: 文案微调 6 处 (intro / 标题 / 选项提示)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 全量 dev-server playthrough + 测试

**Files:**
- 无（验证 only）

- [ ] **Step 1: 跑全测试套件**

Run: `cd F:/python_work/LinkU/game && npm test`
Expected: 362 pass / 8 pre-existing fail（state.test.js 不变）。

- [ ] **Step 2: 跑 build**

Run: `cd F:/python_work/LinkU/game && npm run build`
Expected: 编译通过。

- [ ] **Step 3: 起 dev server playthrough**

Run: `npm run dev` → 浏览器打开，逐项验证：

- [ ] **Match 在 W1**：触发 Match minigame → intro 显示 "把这些留学硬核知识分组配对" / "签证" 类高亮 → 进 play → 选一个 item（如 BRP）→ 选一个类别（visa）→ ✓ 匹配 → 全完一轮看评分
- [ ] **Match 在 W11**：spotlight 应是 banking 类，验证 round 必含 banking
- [ ] **Match 在 W30**：phase 2 进 phase 3 切换，类数从 6 → 8
- [ ] **Lecture 在 W1**：intro 显示 "学术名词 · Academic Nouns" 而不是 "Foucault · Power & Gaze" → 进 playing → 连出 ARGUE / THESIS 等 → 看 ★ 加分
- [ ] **Lecture 在 W11**：主题切换到 "学术形容词" → 连 EMPIRICAL 得 ★ bonus
- [ ] **Lecture 在 W30**：主题 "批判 / 评价"
- [ ] **? 详情按钮**：Match / Lecture 中点 ? → 模态弹出新文案
- [ ] **Whitmore 剧情**：随便触发一个有 Whitmore 的事件（emails / locationEvents） → 旧理论台词仍在（"忍一点不一致"）

- [ ] **Step 4: 任何回归回相应任务修；全过则收工**

---

## 风险与边角情况

- **跨周存档兼容**：玩家如果之前进度在 W11，旧存档触发 Lecture 时会从新 LECTURE_THEMES 找 W11 对应主题（现在是"学术形容词"，旧是"Bourdieu · Habitus"）。state 只存 score 不存 theme.id，无序列化问题。**可接受**，老玩家短暂困惑。
- **WORD_SET 兼容**：旧玩家如果之前连出过 HABITUS、ORIENTALISM 等理论词，新存档下 WORD_SET 不包含，重玩同一周连这些词不再识别。**轻度回归**，可接受 — 这些词本来就不是 RAW_WORDS 通用词。
- **重玩去重**：当前 pickMatchRound 没"避免上轮已抽 item"逻辑，连续两轮可能 30% item 重复。**本 spec 暂不做**，先看实际玩感再决定是否加 lastRoundItems prop。
- **新增 ★ 词拼写**：批次 1-6 的 ★ 词全 .toUpperCase() 后加入 WORD_SET，没拼错就能识别。spec self-review 已 check 过常见拼法（ANALYSE 英式，ANALYZE 美式 — 用英式合 UK 主题）。
- **import 不破**：Task 7 保留 `THEORIST_MATCH` 作为内部 ID，Minigames.jsx 顶部 import 行不用改，减少破坏面。

---

## Self-Review

- ✅ Spec G1（Match 18 类）→ Tasks 2/3/4 覆盖
- ✅ Spec G2（Lecture 12 主题）→ Tasks 5/6 覆盖
- ✅ Spec G3（跨专业友好）→ 内容选择体现：visa / NHS / 学术诚信 / 银行 不分专业都用得上
- ✅ Spec G4（重玩不重复）→ 110 item / 18 类 / Phase 1 抽 4 类 6 item ≈ 5.5% 覆盖,留有足够新鲜度
- ✅ Whitmore 不动剧情 → Task 7 Step 3 只动 minigame 内部文案
- ✅ Essay 不动 → 无 Essay 相关任务
- ✅ 无 TBD / TODO / placeholder
- ✅ pickMatchRound 18 spotlight 数组与 18 categories ID 一一对应
- ✅ LECTURE_THEMES_V2 12 主题 weeks 覆盖 [1, 99] 无 gap（W1-4 / 5-8 / 9-12 / 13-16 / 17-20 / 21-24 / 25-28 / 29-32 / 33-36 / 37-40 / 41-44 / 45-99）
- ✅ THEME_WORDS_V2 与 LECTURE_THEMES_V2 的 bonus 词同步（每 batch task 都明确两者一起改）
- ✅ Atomic swap commit 一气呵成 → 没有半完成状态
