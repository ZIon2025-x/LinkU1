export const PRET_QUESTIONS = [
  {
    staff: '"What can I get you, love?"',
    options: [
      { text: 'A flat white please', correct: true, feedback: '"Lovely, anything else?"' },
      { text: 'Yes', correct: false, feedback: '店员愣了一下："...yes what?"' },
      { text: 'I don\'t know', correct: false, feedback: '店员忍住没翻白眼。' },
    ],
  },
  {
    staff: '"For here or takeaway?"',
    options: [
      { text: 'Takeaway please', correct: true, feedback: '"Cool."' },
      { text: '"For here please" 但你其实想外带', correct: false, feedback: '你不敢改口。最后捧着杯子站着喝完了。' },
      { text: '"Both?"', correct: false, feedback: '店员笑了："Choose one, love."' },
    ],
  },
  {
    staff: '"That\'ll be 4.85, please. Cash or card?"',
    options: [
      { text: '递卡', correct: true, feedback: '"Tap or insert?"' },
      { text: '"Card... I think?"', correct: false, feedback: '店员等了 5 秒。后面的人开始翻白眼。' },
      { text: '掏出现金', correct: false, feedback: '店员说"Sorry love, we\'re cashless." 你拿着 £20 现金愣住。' },
    ],
  },
  {
    staff: '"Would you like a paper bag? It\'s 10p."',
    options: [
      { text: '"No thanks"', correct: true, feedback: '"Cheers."' },
      { text: '点头但没说话', correct: false, feedback: '店员看着你："...is that a yes or a no?"' },
      { text: '"What does that mean?"', correct: false, feedback: '店员耐心解释了 30 秒。后面排队的人脸都黑了。' },
    ],
  },
  {
    staff: '"Have a lovely day!"',
    options: [
      { text: '"You too!"', correct: true, feedback: '你接住了。这是你今天最自然的英语对话。' },
      { text: '"Thanks"', correct: false, feedback: '没错但缺了点温度。' },
      { text: '"Same to you!"', correct: false, feedback: '"Same to you" 也行，但有点僵。' },
    ],
  },
];

// ========================================
// 迷你游戏：写论文（句子选择）
// ========================================

export const ESSAY_PUZZLES = [
  {
    context: '论文段落 · 引言',
    paragraph: 'This dissertation examines the experience of Chinese international students in the UK. ___ Drawing on qualitative interviews, it argues that belonging is not a static state but a continuous negotiation.',
    options: [
      { text: 'Specifically, it focuses on how identity is negotiated in cross-cultural settings.', correct: true,
        feedback: '✓ 这个句子精确连接了"主题"和"方法"。Whitmore 写："Excellent transition."' },
      { text: 'I interviewed many people for this paper.', correct: false,
        feedback: '✗ 太口语，"I" 在学术写作里要慎用。Whitmore 写："Avoid first person."' },
      { text: 'Chinese students are very interesting to study.', correct: false,
        feedback: '✗ 太宽泛，缺乏论点。Whitmore 写："What is your argument?"' },
      { text: 'In this essay, I will discuss many things.', correct: false,
        feedback: '✗ "discuss many things" = 没有焦点。这是大一新生的写法。' },
    ],
  },
  {
    context: '论文段落 · 文献综述',
    paragraph: 'Bourdieu\'s concept of habitus has been widely used in studies of migration. ___ However, recent scholarship has questioned its applicability to digitally connected migrants.',
    options: [
      { text: 'It captures how dispositions are shaped by social structures.', correct: true,
        feedback: '✓ 用一句话精准定义概念，再引出反驳。这是研究生水平。' },
      { text: 'Many people have written about it.', correct: false,
        feedback: '✗ 完全空洞。' },
      { text: 'It\'s a complicated theory.', correct: false,
        feedback: '✗ "complicated" 是描述，不是论证。' },
      { text: 'Bourdieu was a French sociologist.', correct: false,
        feedback: '✗ 这个是百科信息，不是文献综述。' },
    ],
  },
  {
    context: '论文段落 · 结论',
    paragraph: 'These findings suggest that the experience of "异乡" cannot be reduced to a binary of integration or alienation. ___ Future research might explore how this in-between state is articulated across different generations of migrants.',
    options: [
      { text: 'It is, rather, a continually shifting affective terrain.', correct: true,
        feedback: '✓ 优雅，且把核心概念升华了。Whitmore："This is the sentence the whole thesis was building toward."' },
      { text: 'It is more complex than that.', correct: false,
        feedback: '✗ "more complex" 太懒——具体怎么 complex？' },
      { text: 'Therefore, I am right.', correct: false,
        feedback: '✗ 学术写作不要这么"赢"。' },
      { text: 'In conclusion, China is far away.', correct: false,
        feedback: '✗ 既不准确也不学术。' },
    ],
  },
];

// ========================================
// 迷你游戏：理论家概念匹配
// ========================================

export const THEORIST_MATCH = {
  theorists: [
    { id: 'foucault', name: 'Foucault', concepts: ['discipline', 'biopower', 'panopticon'] },
    { id: 'bourdieu', name: 'Bourdieu', concepts: ['habitus', 'cultural_capital', 'field'] },
    { id: 'butler', name: 'Butler', concepts: ['performativity', 'gender_trouble'] },
    { id: 'said', name: 'Said', concepts: ['orientalism'] },
  ],
  concepts: {
    discipline: { label: 'Discipline', desc: '规训' },
    biopower: { label: 'Biopower', desc: '生命权力' },
    panopticon: { label: 'Panopticon', desc: '全景监狱' },
    habitus: { label: 'Habitus', desc: '惯习' },
    cultural_capital: { label: 'Cultural Capital', desc: '文化资本' },
    field: { label: 'Field', desc: '场域' },
    performativity: { label: 'Performativity', desc: '操演性' },
    gender_trouble: { label: 'Gender Trouble', desc: '性别麻烦' },
    orientalism: { label: 'Orientalism', desc: '东方主义' },
  },
};
