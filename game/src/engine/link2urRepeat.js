// Link2Ur 创业线 · 回头客关系递进
//
// 玩家完成任务后调用 maybePromoteToRepeat(state, completedTask),
// 维护 state.link2urRepeatCustomers map。
// 关系阶梯: none → first_impression → repeat_unlocked → fan_unlocked → loyal
//
// 阈值 (spec §4.1):
//   1 单 + 评分≥4.5  → first_impression
//   2 单 + 评分≥4.8  → repeat_unlocked  (解锁 inbox 任务)
//   4 单 + 评分≥4.8  → fan_unlocked     (解锁专属对话)
//   6 单 + 评分≥4.9  → loyal            (触发独家事件)

const TIERS = [
  { name: 'loyal',            minCount: 6, minRating: 4.9 },
  { name: 'fan_unlocked',     minCount: 4, minRating: 4.8 },
  { name: 'repeat_unlocked',  minCount: 2, minRating: 4.8 },
  { name: 'first_impression', minCount: 1, minRating: 4.5 },
];

export function relationshipLevel({ count = 0, rating = 0 } = {}) {
  for (const t of TIERS) {
    if (count >= t.minCount && rating >= t.minRating) return t.name;
  }
  return 'none';
}

// 完成任务后调用, 可能晋升该 customer。返回新 state。
// completedTask: { customerId, taskRating, day }
export function maybePromoteToRepeat(state, completedTask) {
  const { customerId, taskRating, day } = completedTask || {};
  if (!customerId) return state;

  const prev = state.link2urRepeatCustomers[customerId] || {
    count: 0,
    lastTaskDay: 0,
    avgRating: 0,
    relationship: 'none',
  };

  const nextCount = prev.count + 1;
  // 移动平均评分
  const nextAvg = (prev.avgRating * prev.count + (taskRating || 5)) / nextCount;
  const nextRelationship = relationshipLevel({ count: nextCount, rating: nextAvg });

  return {
    ...state,
    link2urRepeatCustomers: {
      ...state.link2urRepeatCustomers,
      [customerId]: {
        count: nextCount,
        lastTaskDay: day,
        avgRating: Math.round(nextAvg * 100) / 100,
        relationship: nextRelationship,
      },
    },
  };
}
