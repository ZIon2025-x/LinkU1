// Link2Ur 创业线 · 9 章主线事件链 (spec §6)
//
// 每章 events 数组列出该章关键事件 (按周触发)。
// 关键事件类型:
//   - npc_scene: 引用 npcYjie.js 里的某个 YJIE_SCENES 项
//   - customer_unlock: 某个 customer 晋升到指定 relationship
//   - inbox_task: 触发某个客户的指定任务
//   - clash_trigger: 触发 clash event
//   - mini_arc: 触发某团员 mini-arc 阶段
//   - crossover: 引用 link2urCrossover.js
//   - flag_set: 设置某个 flag
//
// App.jsx 的 tick 循环每周扫一次 active chapter 的 events,
// 根据 trigger 条件 dispatch action。

export const LINK2UR_CHAPTERS = [
  // ── Ch 1 · W2-W7 · 试水 ──
  {
    chapterId: 'link2ur_ch1',
    title: '试水',
    weekStart: 2,
    weekEnd: 7,
    summary: 'Phase 1 起步。玩家用 Link2Ur 接 2-3 个简单 AI 小单 (双语字幕 / IG 海报 AI 加工)。第一个客户给五星记住你了。',
    events: [
      {
        id: 'ch1_first_simple_task',
        week: 3,
        type: 'inbox_task',
        customerId: null,  // board 单, 还没 inbox
        narrative: '你接了第一个 AI 双语字幕单 (Loon Fung 跑腿单的升级版)',
      },
      {
        id: 'ch1_lily_first_repeat',
        week: 6,
        type: 'customer_unlock',
        customerId: 'cust_lily',
        relationship: 'first_impression',
        narrative: 'Lily 给你五星 + 留言 "下次再约"',
        flagOnSet: 'l2u_first_repeat_unlocked',
      },
    ],
  },

  // ── Ch 2 · W8-W12 · 第一个回头客 ──
  {
    chapterId: 'link2ur_ch2',
    title: '第一个回头客',
    weekStart: 8,
    weekEnd: 12,
    summary: 'Lily 通过 inbox 发首个指定单 (双语短视频 5 条 +20% VIP)。Marcus 加入。Essay 危机时可能拒接, 关系倒退 (可恢复)。',
    events: [
      {
        id: 'ch2_lily_first_inbox',
        week: 8,
        type: 'inbox_task',
        customerId: 'cust_lily',
        title: 'Lily · 双语短视频 5 条 + 20% VIP',
        reward: 180,
        narrative: '"上次那个 AI 字幕做的特别好, 这次代理品牌签约, 5 条短视频本周内出。"',
        flagOnAccept: 'l2u_first_inbox_accepted',
      },
      {
        id: 'ch2_marcus_first_repeat',
        week: 10,
        type: 'customer_unlock',
        customerId: 'cust_marcus_p1',
        relationship: 'first_impression',
        narrative: 'Marcus 找你做"留学生反诈"系列双语长图文',
      },
      {
        id: 'ch2_essay_clash',
        week: 11,
        type: 'flag_set',
        flagOnSet: 'l2u_inbox_unlocked',
        narrative: 'Essay 危机叠加 (主线 Whitmore 62 分时刻), 玩家可能拒一个 inbox 任务',
      },
    ],
  },

  // ── Ch 3 · W13-W17 · 撞档·初体验 ──
  {
    chapterId: 'link2ur_ch3',
    title: '撞档·初体验',
    weekStart: 13,
    weekEnd: 17,
    summary: '圣诞期 demand 飙升。Lily + 张奶奶 + 陈一帆 三任务撞档。Lily W17 被中资品牌相中签约 (Phase 2 hook 预埋)。',
    events: [
      {
        id: 'ch3_xmas_clash',
        week: 14,
        type: 'clash_trigger',
        narrative: '圣诞前三个客户同周发指定任务 → 第一次时间撞档',
      },
      {
        id: 'ch3_grandma_repeat',
        week: 12,
        type: 'customer_unlock',
        customerId: 'cust_grandma',
        relationship: 'first_impression',
        narrative: '张奶奶让你陪她去看金毛 + 顺便发个朋友圈',
      },
      {
        id: 'ch3_chen_repeat',
        week: 10,
        type: 'customer_unlock',
        customerId: 'cust_chen',
        relationship: 'first_impression',
        narrative: '陈一帆论文 first chapter 校对单',
      },
      {
        id: 'ch3_lily_signed',
        week: 17,
        type: 'flag_set',
        flagOnSet: 'l2u_lily_signed',
        narrative: 'Lily 被中资茶饮品牌相中签约, 告诉玩家 "可能要介绍你给品牌方" (Phase 2 hook)',
      },
    ],
  },

  // Ch 4-9 在 Task 3.2-3.4 续写,先放 placeholder 让测试通过
  { chapterId: 'link2ur_ch4', title: 'Sketch 下午茶', weekStart: 21, weekEnd: 22, summary: '', events: [] },
  { chapterId: 'link2ur_ch5', title: '第一步分化', weekStart: 23, weekEnd: 26, summary: '', events: [] },
  { chapterId: 'link2ur_ch6', title: '复活节深化', weekStart: 27, weekEnd: 30, summary: '', events: [] },
  { chapterId: 'link2ur_ch7', title: '论文期低维持', weekStart: 31, weekEnd: 42, summary: '', events: [] },
  { chapterId: 'link2ur_ch8', title: 'Y 姐合并提议', weekStart: 45, weekEnd: 47, summary: '', events: [] },
  { chapterId: 'link2ur_ch9', title: '终局抉择 + 结局', weekStart: 48, weekEnd: 52, summary: '', events: [] },
];

export function getActiveChapter(day) {
  const week = Math.ceil(day / 7);
  return (
    LINK2UR_CHAPTERS.find((c) => week >= c.weekStart && week <= c.weekEnd) ||
    LINK2UR_CHAPTERS[0]
  );
}
