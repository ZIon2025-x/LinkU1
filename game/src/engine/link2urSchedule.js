// Link2Ur 创业线 · 时效冲突检测 + Y 姐邀请触发条件
//
// 机制 C (spec §4.3): inbox 中多个指定任务的 [preferredTimeWindow] 重叠
// 且未过期 → 触发 clash event, 玩家三选一 (硬扛/拒一/拖延或转团员)
// Y 姐邀请触发: 撞档 ≥ 3 + W21+ + 评分 ≥ 4.7 + 完单 ≥ 18 + Phase==1 + 未邀

// 两个时间窗口是否重叠 ([a1, a2] 与 [b1, b2])
function windowOverlaps(a, b) {
  if (!a || !b || a.length !== 2 || b.length !== 2) return false;
  return a[0] < b[1] && b[0] < a[1];
}

// 输入 inbox 任务列表 + 当前 day, 返回冲突对数组
export function detectClashes(inbox, currentDay) {
  const clashes = [];
  const active = (inbox || []).filter(
    (t) => (t.mustCompleteByDay ?? Infinity) >= currentDay
  );
  for (let i = 0; i < active.length; i++) {
    for (let j = i + 1; j < active.length; j++) {
      const a = active[i], b = active[j];
      // 同日截止 (或者一日内)
      if (Math.abs((a.mustCompleteByDay || 0) - (b.mustCompleteByDay || 0)) > 1) continue;
      if (!windowOverlaps(a.preferredTimeWindow, b.preferredTimeWindow)) continue;
      clashes.push({
        taskA: a.id,
        taskB: b.id,
        severity: severityOf(a, b),
      });
    }
  }
  return clashes;
}

function severityOf(a, b) {
  // 简单的 severity = 两任务 reward 之和 (后续可加权)
  return (a.reward || 0) + (b.reward || 0);
}

// Ch 4 Y 姐 Sketch 邀请触发条件 (spec §4.3)
export function shouldTriggerYInvitation(state) {
  if (!state) return false;
  const week = Math.ceil((state.day || 0) / 7);
  return (
    (state.link2urClashCount || 0) >= 3 &&
    week >= 21 &&
    (state.link2urRating || 0) >= 4.7 &&
    (state.link2urCompleted?.length || 0) >= 18 &&
    state.link2urPhase === 1 &&
    !state.flags?.l2u_y_invited
  );
}
