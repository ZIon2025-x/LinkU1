export const READING_WEEK_EVENTS = [
  { id: 'rw_lucky', title: 'Reading Week 第一天', body: '没有课。整个伦敦的留学生都在做同一件事——睡到自然醒。',
    effect: { energy: 12, academic: 2 }, isAuto: true },
];

// ========================================
// 考试系统
// ========================================

export const EXAM_PAPERS = [
  {
    id: 'exam_theory', subject: 'Critical Theory', cn: '批判理论',
    questions: [
      { q: 'Foucault 在《规训与惩罚》中如何定义权力？',
        options: ['一种自上而下的压制力', '弥散在社会关系中的微观结构', '国家机器的暴力', '经济基础的反映'],
        correct: 1 },
      { q: '后结构主义认为意义是：',
        options: ['固定的', '由 signifier 之间的差异生成的', '作者意图的还原', '客观世界的反映'],
        correct: 1 },
      { q: '"erasure under erasure" 是哪位理论家的概念？',
        options: ['Derrida', 'Foucault', 'Lacan', 'Žižek'],
        correct: 0 },
      { q: 'Said 的 Orientalism 主要批判：',
        options: ['西方的殖民历史', '西方对东方的话语建构', '东方学家学术不严谨', '所有跨文化研究'],
        correct: 1 },
      { q: 'Butler 的 performativity 是指：',
        options: ['表演性的虚假', '通过重复实践构成主体', '剧院理论的延伸', '社会角色扮演'],
        correct: 1 },
    ],
  },
  {
    id: 'exam_method', subject: 'Research Methods', cn: '研究方法',
    questions: [
      { q: 'Qualitative research 的核心特点是：',
        options: ['追求统计显著性', '理解意义和经验', '排除研究者主观性', '大规模数据收集'],
        correct: 1 },
      { q: '"thick description" 是哪位学者提出的？',
        options: ['Geertz', 'Bourdieu', 'Goffman', 'Garfinkel'],
        correct: 0 },
      { q: 'Triangulation 在研究中指的是：',
        options: ['三角形采样', '使用多种方法验证', '三个研究者合作', '三阶段数据分析'],
        correct: 1 },
      { q: 'IRB approval 在英国大学称为：',
        options: ['Ethics Committee', 'Research Board', 'Senate Committee', 'Faculty Review'],
        correct: 0 },
      { q: '半结构化访谈最适合：',
        options: ['大样本调查', '探索性研究', '实验对照', '内容分析'],
        correct: 1 },
    ],
  },
  {
    id: 'exam_dissert_prep', subject: 'Dissertation Prep', cn: '论文准备',
    questions: [
      { q: '一个好的研究问题需要：',
        options: ['有现成答案', '可被研究、有意义、可控范围', '导师指定', '紧跟热点'],
        correct: 1 },
      { q: 'Literature gap 指的是：',
        options: ['找不到文献', '已有研究尚未涵盖的领域', '文献质量不高', '过时的研究'],
        correct: 1 },
      { q: 'UK Master 论文一般字数是：',
        options: ['5,000-10,000', '12,000-15,000', '20,000+', '30,000+'],
        correct: 1 },
      { q: '提交论文时常见的格式要求不包括：',
        options: ['Harvard 引用', '双倍行距', '12 号字', '强制使用宋体'],
        correct: 3 },
      { q: 'Viva 是指：',
        options: ['期末聚会', '论文答辩', '小组报告', '欢呼仪式'],
        correct: 1 },
    ],
  },
];

// ========================================
// 论文（Dissertation）事件 / 选择
// ========================================

export const DISSERTATION_TOPICS = [
  { id: 'safe', label: '保守题目（导师推荐的方向）', desc: '风险低，分数稳，但可能拿不到distinction',
    effect: { academic: 5, energy: -5 },
    flag: 'diss_safe',
    feedback: 'Whitmore 看完你的 proposal 点头："Solid. Predictable but solid." 你知道这就是你这一年的总结。' },
  { id: 'ambitious', label: '冒险题目（你自己想做的方向）', desc: '风险高，但可能拿到distinction',
    effect: { academic: 8, energy: -10 },
    flag: 'diss_ambitious',
    feedback: 'Whitmore 看完皱了眉："This is ambitious. Are you sure?" 你说你确定。他叹气，然后笑了。"Then I\'ll help you do it well."' },
  { id: 'personal', label: '个人化题目（关于你自己的留学经历）', desc: '风险极高，但有特别意义',
    effect: { academic: 6, energy: -8, belonging: 10 },
    flag: 'diss_personal',
    feedback: '你的题目是关于"中国留学生在英国的身份建构"。Whitmore 沉默了很久，然后说："This will be hard to write. But you should write it."' },
];
