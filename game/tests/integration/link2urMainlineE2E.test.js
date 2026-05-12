/**
 * Link2Ur 创业线 3-path E2E 集成测试
 *
 * 三条路径从 initialState() 出发，通过 reducer 模拟关键 action 序列，
 * 最终验证 resolveEnding() 返回正确的结局 id。
 *
 * Path A · Solo apex      → link2ur_solo_apex
 * Path B · Team merged    → y_double
 * Path C · Team independent → link2ur_team_founded
 *
 * 注意：endings.js 中 resolveEnding() 使用 state.link2urCompletedCount（数字），
 * 而该字段在 App.jsx 中被计算为 (state.link2urCompleted || []).length 再注入。
 * 在测试中，我们在调用 resolveEnding 前手动注入该派生字段。
 */

import { describe, test, expect } from 'vitest';
import { reducer, initialState } from '../../src/engine/state.js';
import { resolveEnding } from '../../src/data/endings.js';

// ─── helpers ────────────────────────────────────────────────────────────────

/**
 * 向 inbox 添加一个任务，然后接受它。
 * taskId 和 customerId 都是字符串；reward 以英镑计；rating 影响平台评分（通过回头客系统）。
 * 注意：L2U_INBOX_ACCEPTED 走 maybePromoteToRepeat，rating 会通过回头客系统更新，
 * 但对于直接 inbox 路径评分不自动升高 —— 对于 E2E 测试我们用 PATCH_STATS 手动设定最终评分。
 */
function simulateCompleteInboxTask(state, { taskId, customerId = 'cust_generic', reward = 50 }) {
  const withTask = reducer(state, {
    type: 'L2U_INBOX_RECEIVED',
    task: { id: taskId, customerId, reward, taskRating: 5 },
  });
  return reducer(withTask, { type: 'L2U_INBOX_ACCEPTED', taskId });
}

/**
 * 批量完成 n 个匿名 inbox 任务（用于快速积累 completedCount）。
 */
function bulkCompleteTasks(state, n, rewardEach = 80) {
  let s = state;
  for (let i = 0; i < n; i++) {
    s = simulateCompleteInboxTask(s, {
      taskId: `bulk_task_${i}`,
      customerId: `cust_${i % 5}`,
      reward: rewardEach,
    });
  }
  return s;
}

/**
 * 注入 resolveEnding 所需的派生字段并调用。
 * App.jsx 中 link2urCompletedCount = (state.link2urCompleted || []).length。
 */
function resolveWithDerived(state) {
  const enriched = {
    ...state,
    link2urCompletedCount: (state.link2urCompleted || []).length,
  };
  return resolveEnding(enriched);
}

// ─── Path A · Solo apex ──────────────────────────────────────────────────────

describe('Path A · Solo apex → link2ur_solo_apex', () => {
  test('40+ completed + rating 4.95+ + solo flags → resolves to link2ur_solo_apex', () => {
    let s = initialState();

    // W2-W21: 积累 40 单（通过 inbox 完成）
    s = bulkCompleteTasks(s, 42);

    // W22: Phase pivot (Ch 4 Sketch 邀请后触发)
    s = reducer(s, { type: 'L2U_PHASE_PIVOT' });

    // 选择 solo 路径 + 设置对应 flag（App.jsx 在 L2U_PATH_DECIDED 后设 flag）
    s = reducer(s, { type: 'L2U_PATH_DECIDED', path: 'solo' });
    s = reducer(s, { type: 'SET_FLAG', flag: 'link2urPath_solo' });

    // Ch 5 W26: 选好 AI niche
    s = reducer(s, { type: 'SET_FLAG', flag: 'l2u_solo_niche_chosen' });
    s = reducer(s, { type: 'MARK_CHAPTER_EVENT_SEEN', eventId: 'ch5_solo_niche_choice' });

    // 拒绝 Y 姐合并（不设 l2u_y_merger_accepted）
    s = reducer(s, { type: 'SET_FLAG', flag: 'l2u_y_invited' });
    // 明确不接受合并：只标记 invited，不设 merger_accepted

    // 强制设定最终评分 ≥ 4.95（真实游戏中通过高评分任务积累）
    s = { ...s, link2urRating: 4.95 };

    expect(s.link2urPath).toBe('solo');
    expect(s.flags.link2urPath_solo).toBe(true);
    expect(s.flags.l2u_solo_niche_chosen).toBe(true);
    expect(s.link2urRating).toBeGreaterThanOrEqual(4.95);
    expect((s.link2urCompleted || []).length).toBeGreaterThanOrEqual(40);

    const ending = resolveWithDerived(s);
    expect(ending.id).toBe('link2ur_solo_apex');
  });
});

// ─── Path B · Team merged ────────────────────────────────────────────────────

describe('Path B · Team merged → y_double', () => {
  test('team path + 4 members + Y 姐 merger accepted → resolves to y_double', () => {
    let s = initialState();

    // 早期接单建立基础
    s = bulkCompleteTasks(s, 10);

    // W22: Phase pivot
    s = reducer(s, { type: 'L2U_PHASE_PIVOT' });

    // 选 team 路径
    s = reducer(s, { type: 'L2U_PATH_DECIDED', path: 'team' });
    s = reducer(s, { type: 'SET_FLAG', flag: 'link2urPath_team' });

    // Ch 5-7: 招募 4 名团员
    const members = [
      { memberId: 'team_xiaoyu', specialty: 'ai_copywriting_bilingual', cutPercent: 18 },
      { memberId: 'team_aman',   specialty: 'ads_strategy_data',        cutPercent: 18 },
      { memberId: 'team_preet',  specialty: 'account_management',       cutPercent: 18 },
      { memberId: 'team_miki',   specialty: 'ai_visual_design',         cutPercent: 18 },
    ];
    for (const m of members) {
      s = reducer(s, { type: 'L2U_TEAM_RECRUIT', ...m });
    }

    // Y 姐邀请 + 接受合并
    s = reducer(s, { type: 'SET_FLAG', flag: 'l2u_y_invited' });
    s = reducer(s, { type: 'SET_FLAG', flag: 'l2u_y_merger_accepted' });
    s = reducer(s, { type: 'MARK_CHAPTER_EVENT_SEEN', eventId: 'ch8_y_merger_scene' });

    expect(s.flags.l2u_y_invited).toBe(true);
    expect(s.flags.link2urPath_team).toBe(true);
    expect(s.flags.l2u_y_merger_accepted).toBe(true);
    expect(s.link2urTeamMembers.length).toBeGreaterThanOrEqual(4);

    const ending = resolveWithDerived(s);
    expect(ending.id).toBe('y_double');
  });
});

// ─── Path C · Team independent ───────────────────────────────────────────────

describe('Path C · Team independent → link2ur_team_founded', () => {
  test('team path + 2 members + Y 姐 merger declined → resolves to link2ur_team_founded', () => {
    let s = initialState();

    // 早期接单
    s = bulkCompleteTasks(s, 10);

    // W22: Phase pivot
    s = reducer(s, { type: 'L2U_PHASE_PIVOT' });

    // 选 team 路径
    s = reducer(s, { type: 'L2U_PATH_DECIDED', path: 'team' });
    s = reducer(s, { type: 'SET_FLAG', flag: 'link2urPath_team' });

    // 招募 2 名团员（比 merged 路径少）
    s = reducer(s, {
      type: 'L2U_TEAM_RECRUIT',
      memberId: 'team_xiaoyu',
      specialty: 'ai_copywriting_bilingual',
      cutPercent: 18,
    });
    s = reducer(s, {
      type: 'L2U_TEAM_RECRUIT',
      memberId: 'team_aman',
      specialty: 'ads_strategy_data',
      cutPercent: 18,
    });

    // Y 姐邀请，但拒绝合并 → 选择独立
    s = reducer(s, { type: 'SET_FLAG', flag: 'l2u_y_invited' });
    s = reducer(s, { type: 'SET_FLAG', flag: 'l2u_y_merger_declined_independent' });
    s = reducer(s, { type: 'MARK_CHAPTER_EVENT_SEEN', eventId: 'ch8_y_merger_declined' });

    expect(s.flags.link2urPath_team).toBe(true);
    expect(s.flags.l2u_y_merger_declined_independent).toBe(true);
    expect(s.link2urTeamMembers.length).toBeGreaterThanOrEqual(2);
    expect(s.flags.l2u_y_merger_accepted).toBeFalsy();

    const ending = resolveWithDerived(s);
    expect(ending.id).toBe('link2ur_team_founded');
  });
});
