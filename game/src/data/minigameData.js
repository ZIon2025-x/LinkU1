// Tesco 黄标 minigame · 30+ items (真实英国 Tesco 价格)
//
// 玩法重做(2026 v2):
//   1. 牌面朝上展示 N 秒(让玩家记哪几张是黄标)
//   2. 卡牌翻面(背面 ?)
//   3. 洗牌 K 次(位置 swap 动画,带 transition)
//   4. 玩家点击哪几张原本是黄标
//
// 难度随周递增:
//   · W1-5  : 4 cards / 1 yellow / 2 shuffles @ 600ms / peek 3s
//   · W6-15 : 6 cards / 2 yellow / 4 shuffles @ 500ms / peek 2.5s
//   · W16-25: 6 cards / 2 yellow / 6 shuffles @ 400ms / peek 2s
//   · W26+  : 8 cards / 3 yellow / 8 shuffles @ 350ms / peek 1.5s

export const YELLOW_LABEL_ITEMS = [
  // fresh produce / dairy
  { name: '寿司', emoji: '🍣', price: 1.5 },
  { name: '三明治', emoji: '🥪', price: 2 },
  { name: '苹果', emoji: '🍎', price: 3 },
  { name: '面包', emoji: '🍞', price: 1 },
  { name: '牛奶', emoji: '🥛', price: 2.5 },
  { name: '可乐', emoji: '🥤', price: 2 },
  { name: '酸奶', emoji: '🥣', price: 1.8 },
  { name: '香蕉', emoji: '🍌', price: 1.2 },
  { name: '草莓盒', emoji: '🍓', price: 2.5 },
  { name: '葡萄', emoji: '🍇', price: 3.5 },
  { name: '橙汁', emoji: '🧃', price: 2.8 },
  // ready meal / prepared
  { name: 'Pasta box', emoji: '🍝', price: 4 },
  { name: '咖喱饭', emoji: '🍛', price: 4.5 },
  { name: '披萨片', emoji: '🍕', price: 3.5 },
  { name: '汉堡盒', emoji: '🍔', price: 5 },
  { name: '寿司卷', emoji: '🍱', price: 5.5 },
  { name: 'Pret salad', emoji: '🥗', price: 4 },
  { name: '烤鸡', emoji: '🍗', price: 4.5 },
  { name: 'Fish & Chips', emoji: '🍟', price: 6 },
  // bakery
  { name: 'Croissant', emoji: '🥐', price: 1.5 },
  { name: '小蛋糕', emoji: '🧁', price: 2 },
  { name: '甜甜圈', emoji: '🍩', price: 1.5 },
  { name: 'Cookie', emoji: '🍪', price: 1 },
  { name: '苹果派', emoji: '🥧', price: 3 },
  // packaged
  { name: '巧克力', emoji: '🍫', price: 2 },
  { name: '薯片', emoji: '🥨', price: 1.5 },
  { name: '冰淇淋', emoji: '🍨', price: 3.5 },
  { name: 'Pasta 干', emoji: '🍜', price: 1.2 },
  { name: '麦片', emoji: '🥣', price: 3 },
  { name: '罐头汤', emoji: '🥫', price: 1.8 },
  { name: '蛋盒', emoji: '🥚', price: 2.2 },
  { name: '黄油', emoji: '🧈', price: 2.5 },
  { name: '奶酪', emoji: '🧀', price: 3.5 },
];

// 难度配置:按 week 返回当场参数
export function yellowLabelConfig(week) {
  if (week <= 5)  return { cards: 4, yellowCount: 1, shuffles: 2, shuffleMs: 600, peekMs: 3000, baseReward: 0 };
  if (week <= 15) return { cards: 6, yellowCount: 2, shuffles: 4, shuffleMs: 500, peekMs: 2500, baseReward: 0 };
  if (week <= 25) return { cards: 6, yellowCount: 2, shuffles: 6, shuffleMs: 400, peekMs: 2000, baseReward: 0 };
  return            { cards: 8, yellowCount: 3, shuffles: 8, shuffleMs: 350, peekMs: 1500, baseReward: 0 };
}

// 抽 N 个 items + 标 yellowCount 个为 isYellow
export function generateYellowLabelRound(week, rng = Math.random) {
  const cfg = yellowLabelConfig(week);
  const shuffled = [...YELLOW_LABEL_ITEMS].sort(() => rng() - 0.5).slice(0, cfg.cards);
  const yellowIndices = new Set();
  while (yellowIndices.size < cfg.yellowCount) {
    yellowIndices.add(Math.floor(rng() * cfg.cards));
  }
  return {
    cfg,
    items: shuffled.map((it, i) => ({ ...it, id: `${i}-${it.name}`, isYellow: yellowIndices.has(i) })),
  };
}

// 考试题
export const EXAM_QUESTIONS = [
  {
    q: 'Which of these is a key feature of post-structuralist theory?',
    options: ['Fixed meanings', 'Decentering of subject', 'Empirical verification', 'Linear narrative'],
    correct: 1,
  },
  {
    q: 'In academic writing, "ergo" is best translated as:',
    options: ['However', 'Therefore', 'Although', 'Despite'],
    correct: 1,
  },
  {
    q: 'The Harvard referencing style requires:',
    options: ['Footnotes only', 'Author-date in text', 'No bibliography', 'Numerical citations'],
    correct: 1,
  },
  {
    q: 'A "tutorial" in UK universities typically refers to:',
    options: ['Online video', 'Small group discussion', 'Lecture hall class', 'Lab session'],
    correct: 1,
  },
  {
    q: 'What does "ibid." mean in citations?',
    options: ['In another book', 'In the same source', 'According to', 'Compare with'],
    correct: 1,
  },
];
