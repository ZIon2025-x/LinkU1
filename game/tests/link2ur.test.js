import { describe, test, expect } from 'vitest';
import {
  LINK2UR_BRAND, LINK2UR_ACCEPT_TEMPLATES, LINK2UR_POST_TEMPLATES,
  generateBoard, availablePosts, updateRating,
} from '../src/data/link2ur.js';
import { reducer, initialState } from '../src/engine/state.js';

describe('Link2Ur · brand + data shape', () => {
  test('brand has the actual Link2Ur primary blue + accent orange', () => {
    expect(LINK2UR_BRAND.primary).toBe('#007AFF');
    expect(LINK2UR_BRAND.accent).toBe('#FF8033');
    expect(LINK2UR_BRAND.gold).toBe('#FFD700');
  });

  test('every accept template has required fields', () => {
    for (const t of LINK2UR_ACCEPT_TEMPLATES) {
      expect(t.id).toBeTruthy();
      expect(t.type).toBeTruthy();
      expect(Array.isArray(t.titles)).toBe(true);
      expect(t.titles.length).toBeGreaterThan(0);
      expect(t.rewardMin).toBeLessThanOrEqual(t.rewardMax);
      expect(t.energyCost).toBeGreaterThanOrEqual(0);
      expect(t.minWeek).toBeGreaterThanOrEqual(1);
    }
  });

  test('every post template has required fields', () => {
    for (const p of LINK2UR_POST_TEMPLATES) {
      expect(p.id).toBeTruthy();
      expect(p.title).toBeTruthy();
      expect(p.cost).toBeGreaterThan(0);
    }
  });

  test('all template ids globally unique', () => {
    const ids = [
      ...LINK2UR_ACCEPT_TEMPLATES.map(t => t.id),
      ...LINK2UR_POST_TEMPLATES.map(p => p.id),
    ];
    expect(new Set(ids).size).toBe(ids.length);
  });
});

describe('Link2Ur · board generation', () => {
  test('generateBoard returns 4-6 tasks for a normal week', () => {
    const board = generateBoard(10);
    expect(board.length).toBeGreaterThanOrEqual(4);
    expect(board.length).toBeLessThanOrEqual(6);
  });

  test('each spawned task has a reward in [min, max]', () => {
    const board = generateBoard(10, { rng: () => 0.7 });
    for (const t of board) {
      const tmpl = LINK2UR_ACCEPT_TEMPLATES.find(x => x.id === t.templateId);
      expect(t.reward).toBeGreaterThanOrEqual(tmpl.rewardMin);
      expect(t.reward).toBeLessThanOrEqual(tmpl.rewardMax);
    }
  });

  test('week-locked tasks (Bicester after W4, PhD PS after W36) are filtered', () => {
    // At W2, Bicester (minWeek 4) and personal_statement (minWeek 36) should not appear
    const earlyBoard = generateBoard(2, { rng: () => 0.5 });
    const ids = earlyBoard.map(t => t.templateId);
    expect(ids).not.toContain('l2u_bicester_coach');
    expect(ids).not.toContain('l2u_personal_statement');

    // At W40, both should be eligible (PS yes, Bicester yes)
    const lateBoard = generateBoard(40, { rng: () => 0.5 });
    // (we don't assert they appear since sampling is random — just that they're eligible)
  });

  test('seeded rng produces deterministic boards', () => {
    let seed = 0;
    const rng = () => {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    };
    const a = generateBoard(10, { rng });
    seed = 0;
    const b = generateBoard(10, { rng });
    expect(a.map(t => t.templateId)).toEqual(b.map(t => t.templateId));
  });
});

describe('Link2Ur · post availability', () => {
  test('BRP post requires brp_pending flag', () => {
    const stateNoBrp = { ...initialState(), flags: {} };
    const stateBrp = { ...initialState(), flags: { brp_pending: true } };
    const noBrpPosts = availablePosts(stateNoBrp).map(p => p.id);
    const brpPosts = availablePosts(stateBrp).map(p => p.id);
    expect(noBrpPosts).not.toContain('post_brp_skip');
    expect(brpPosts).toContain('post_brp_skip');
  });

  test('packing-home post only after W50', () => {
    const earlyState = { ...initialState(), day: 7 * 30 };  // W30
    const lateState = { ...initialState(), day: 7 * 51 };  // W51
    expect(availablePosts(earlyState).map(p => p.id)).not.toContain('post_packing_home');
    expect(availablePosts(lateState).map(p => p.id)).toContain('post_packing_home');
  });
});

describe('Link2Ur · reducer actions', () => {
  test('initial state has empty board + 5.0 rating + 0 earnings', () => {
    const s = initialState();
    expect(s.link2urBoard).toEqual([]);
    expect(s.link2urRating).toBe(5.0);
    expect(s.link2urEarnings).toBe(0);
    expect(s.link2urCompleted).toEqual([]);
    expect(s.link2urPosted).toEqual([]);
  });

  test('L2U_REFRESH_BOARD replaces board', () => {
    let s = initialState();
    const tasks = generateBoard(5);
    s = reducer(s, { type: 'L2U_REFRESH_BOARD', tasks, week: 5 });
    expect(s.link2urBoard.length).toBe(tasks.length);
    expect(s.link2urBoardWeek).toBe(5);
  });

  test('L2U_ACCEPT_TASK pays reward, deducts action+energy, removes from board', () => {
    let s = initialState();
    const task = {
      id: 't-1', templateId: 'l2u_pret_queue', reward: 10,
      energyCost: 2, actionCost: 1, rating: 5, week: 2,
    };
    s = reducer(s, { type: 'L2U_REFRESH_BOARD', tasks: [task], week: 2 });
    s = reducer(s, { type: 'L2U_ACCEPT_TASK', task });
    expect(s.link2urBoard.length).toBe(0);
    expect(s.link2urCompleted.length).toBe(1);
    expect(s.link2urEarnings).toBe(10);
    expect(s.stats.wallet).toBe(2000 + 10);
    expect(s.stats.energy).toBe(80 - 2);
    expect(s.actionsLeft).toBe(2);
  });

  test('L2U_POST_TASK deducts wallet, applies energy/action gains, sets flag', () => {
    let s = initialState();
    s = { ...s, stats: { ...s.stats, energy: 50 } };
    const post = { id: 'post_brp_skip', cost: 35, energyGain: 8, actionGain: 1, setsFlag: 'brp_collected' };
    s = reducer(s, { type: 'L2U_POST_TASK', post });
    expect(s.link2urPosted).toContain('post_brp_skip');
    expect(s.flags.brp_collected).toBe(true);
    expect(s.stats.wallet).toBe(2000 - 35);
    expect(s.stats.energy).toBe(50 + 8);
  });

  test('rating uses exponential moving average (one bad review does not crater)', () => {
    // 5 perfect ratings then a 4 — should still be > 4.7
    expect(updateRating(5.0, 5, 1)).toBe(5);
    expect(updateRating(5.0, 5, 2)).toBe(5);
    expect(updateRating(5.0, 5, 3)).toBe(5);
    const after4 = updateRating(5.0, 4, 4);
    expect(after4).toBeGreaterThan(4.7);
  });
});

// Discovery event 已删除 — Link2Ur 改成 day-1 essential tool (state.js:32-34)。
// 旧 LINK2UR_DISCOVERY_EVENTS 是死代码（initialState 已 set link2ur_discovered:true
// 让条件永不通过）。整个 discovery 事件链已从 link2ur.js 移除。

describe('AI 广告任务模板 (v2 spec)', () => {
  test('LINK2UR_ACCEPT_TEMPLATES 含 ≥ 71 个 (56 原有 + 15 新)', () => {
    expect(LINK2UR_ACCEPT_TEMPLATES.length).toBeGreaterThanOrEqual(71);
  });

  test('所有 AI 广告模板带 phase 字段 (1/2/both)', () => {
    const aiTemplates = LINK2UR_ACCEPT_TEMPLATES.filter((t) => t.id.startsWith('l2u_ai_'));
    expect(aiTemplates.length).toBe(15);
    for (const t of aiTemplates) {
      expect([1, 2, 'both']).toContain(t.phase);
    }
  });

  test('generateBoard with phase=1 过滤掉 Phase 2 only 模板', () => {
    const board = generateBoard(10, { rng: () => 0.5, phase: 1 });
    const hasPhase2Only = board.some((t) => {
      const tmpl = LINK2UR_ACCEPT_TEMPLATES.find((x) => x.id === t.templateId);
      return tmpl?.phase === 2;
    });
    expect(hasPhase2Only).toBe(false);
  });

  describe('Phase board filter regression', () => {
    function mulberry32(a) {
      return function() {
        let t = a += 0x6D2B79F5;
        t = Math.imul(t ^ t >>> 15, t | 1);
        t ^= t + Math.imul(t ^ t >>> 7, t | 61);
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
      };
    }

    test('phase=2 board can include Phase 2 only templates', () => {
      // run generateBoard many times with phase 2, verify at least one P2-only template appears
      const seenIds = new Set();
      const rng = mulberry32(42); // deterministic
      for (let i = 0; i < 50; i++) {
        const board = generateBoard(30, { phase: 2, rng });
        for (const t of board) seenIds.add(t.templateId);
      }
      // 至少有一个 Phase 2 only template 出现
      const p2OnlyTemplates = LINK2UR_ACCEPT_TEMPLATES.filter(t => t.phase === 2);
      const anyP2Found = p2OnlyTemplates.some(t => seenIds.has(t.id));
      expect(anyP2Found).toBe(true);
    });

    test('phase=1 board never includes Phase 2 only templates', () => {
      const seenIds = new Set();
      const rng = mulberry32(42);
      for (let i = 0; i < 50; i++) {
        const board = generateBoard(30, { phase: 1, rng });
        for (const t of board) seenIds.add(t.templateId);
      }
      const p2OnlyTemplates = LINK2UR_ACCEPT_TEMPLATES.filter(t => t.phase === 2);
      const anyP2Found = p2OnlyTemplates.some(t => seenIds.has(t.id));
      expect(anyP2Found).toBe(false);
    });
  });
});
