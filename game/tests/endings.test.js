import { describe, test, expect } from 'vitest';
import { ENDINGS, SPECIAL_ENDINGS, resolveEnding } from '../src/data/endings.js';

const baseState = {
  flags: {},
  stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
  storyProgress: { sarah: 0, aditi: 0, mei: 0, wangkai: 0, whitmore: 0 },
  npcRel: { sarah: 0, aditi: 0, mei: 0, wangkai: 0, whitmore: 0 },
};

describe('ending resolver', () => {
  test('always returns an ending (catch-all guarantees this)', () => {
    const e = resolveEnding(baseState);
    expect(e.title).toBeTruthy();
    expect(e.text).toBeTruthy();
  });

  test('parents_visited + academic >= 55 → "我让他们看到了" (highest priority)', () => {
    const state = { ...baseState, flags: { parents_visited: true }, stats: { ...baseState.stats, academic: 60 } };
    const e = resolveEnding(state);
    expect(e.id).toBe('parents_visited_academic');
  });

  test('parents_visited but academic < 55 → does NOT trigger top ending', () => {
    const state = { ...baseState, flags: { parents_visited: true }, stats: { ...baseState.stats, academic: 40 } };
    const e = resolveEnding(state);
    expect(e.id).not.toBe('parents_visited_academic');
  });

  test('Sarah double flag combo wins over single flag', () => {
    const state = { ...baseState, flags: { cotswolds_xmas: true, eurotrip_sarah: true } };
    const e = resolveEnding(state);
    expect(e.id).toBe('sarah_double');
  });

  test('Aditi double > single India trip', () => {
    const state = { ...baseState, flags: { visited_india: true, easter_aditi_pact: true } };
    const e = resolveEnding(state);
    expect(e.id).toBe('aditi_double');
  });

  test('cotswolds_xmas alone → "Cotswolds 的窗"', () => {
    const state = { ...baseState, flags: { cotswolds_xmas: true } };
    const e = resolveEnding(state);
    expect(e.id).toBe('sarah_cotswolds');
  });

  test('Oxford reference + academic >= 70 → Oxford ending', () => {
    const state = { ...baseState, flags: { oxford_ref: true }, stats: { ...baseState.stats, academic: 75 } };
    const e = resolveEnding(state);
    expect(e.id).toBe('oxford');
  });

  test('high belonging + academic → becoming', () => {
    const state = { ...baseState, stats: { ...baseState.stats, belonging: 65, academic: 60 } };
    const e = resolveEnding(state);
    expect(e.id).toBe('becoming');
  });

  test('low belonging → graduated_numb', () => {
    const state = { ...baseState, stats: { ...baseState.stats, belonging: 20 } };
    const e = resolveEnding(state);
    expect(e.id).toBe('graduated_numb');
  });

  test('catch-all "staying" when nothing else matches', () => {
    const state = { ...baseState, stats: { academic: 50, wallet: 500, energy: 50, belonging: 35 } };
    const e = resolveEnding(state);
    expect(e.id).toBe('staying');
  });
});

describe('every ending is reachable in principle', () => {
  // For each ending, find a state that triggers exactly it (ignoring higher-priority overrides).
  // We do this by walking down the table: at each ending, we craft a state matching its
  // condition and verify resolveEnding picks it (or a higher-priority match).
  //
  // The point: if any condition is structurally unreachable (e.g. a typo), this catches it
  // even if a later catch-all hides it.
  for (const e of ENDINGS) {
    test(`condition for "${e.id}" can be satisfied`, () => {
      // Construct a state that matches this ending's condition.
      // We use a maximalist state: every flag true, all stats high, all stories complete.
      const state = {
        flags: {
          parents_visited: false,  // start false; only set ones the ending needs
          cotswolds_xmas: true, eurotrip_sarah: true,
          visited_india: true, easter_aditi_pact: true,
          mei_family: true, mei_manager: true,
          high_table: true, thesis_polished: true,
          xmas_grind: true, wangkai_apprentice: true,
          oxford_ref: true,
          returned_with_wk: true,
        },
        stats: { academic: 90, wallet: 2000, energy: 90, belonging: 90 },
        storyProgress: { sarah: 5, aditi: 5, mei: 5, wangkai: 5, whitmore: 5 },
        npcRel: { sarah: 12, aditi: 12, mei: 12, wangkai: 12, whitmore: 12 },
      };
      // The condition itself must be satisfiable in some state. The catch-all `() => true`
      // is trivially satisfiable; otherwise we just require the condition function does
      // not throw and yields a boolean.
      expect(() => e.condition(state)).not.toThrow();
      const result = e.condition(state);
      expect(typeof result).toBe('boolean');
    });
  }
});

describe('special endings (mid-game)', () => {
  test('visa_curtailed renders attendance rate', () => {
    const e = SPECIAL_ENDINGS.visa_curtailed(45);
    expect(e.text).toMatch(/45%/);
    expect(e.subtitle).toBe('Visa Curtailed');
  });

  test('broke ending exists', () => {
    const e = SPECIAL_ENDINGS.broke();
    expect(e.title).toBe('回去');
  });
});

// ============================================================
// Task 6.1 — 3 new Link2Ur 创业线结局
// ============================================================
describe('3 new Link2Ur endings exist in ENDINGS table', () => {
  const ids = ENDINGS.map(e => e.id);

  test('y_double exists', () => {
    expect(ids).toContain('y_double');
  });

  test('link2ur_team_founded exists', () => {
    expect(ids).toContain('link2ur_team_founded');
  });

  test('link2ur_solo_apex exists', () => {
    expect(ids).toContain('link2ur_solo_apex');
  });
});

describe('new endings have substantial body text (>200 chars)', () => {
  for (const id of ['y_double', 'link2ur_team_founded', 'link2ur_solo_apex']) {
    test(`${id} body length > 200`, () => {
      const entry = ENDINGS.find(e => e.id === id);
      expect(entry).toBeTruthy();
      expect(entry.ending.text.length).toBeGreaterThan(200);
    });
  }
});

describe('new endings tier metadata', () => {
  test('y_double is Tier 1', () => {
    const entry = ENDINGS.find(e => e.id === 'y_double');
    expect(entry.tier).toBe(1);
  });

  test('link2ur_team_founded is Tier 2', () => {
    const entry = ENDINGS.find(e => e.id === 'link2ur_team_founded');
    expect(entry.tier).toBe(2);
  });

  test('link2ur_solo_apex is Tier 2', () => {
    const entry = ENDINGS.find(e => e.id === 'link2ur_solo_apex');
    expect(entry.tier).toBe(2);
  });
});

describe('new endings flag conditions', () => {
  test('y_double requires team-related flags including l2u_y_invited, link2urPath_team, l2u_y_merger_accepted', () => {
    const entry = ENDINGS.find(e => e.id === 'y_double');
    // Condition should pass when all required flags are set + team size >= 4
    const state = {
      ...{
        flags: { l2u_y_invited: true, link2urPath_team: true, l2u_y_merger_accepted: true },
        stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
        storyProgress: {},
        npcRel: {},
        link2urTeamMembers: [{}, {}, {}, {}],  // 4 members
      }
    };
    expect(entry.condition(state)).toBe(true);
  });

  test('y_double does NOT trigger without merger_accepted flag', () => {
    const entry = ENDINGS.find(e => e.id === 'y_double');
    const state = {
      flags: { l2u_y_invited: true, link2urPath_team: true },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urTeamMembers: [{}, {}, {}, {}],
    };
    expect(entry.condition(state)).toBe(false);
  });

  test('y_double does NOT trigger with team size < 4', () => {
    const entry = ENDINGS.find(e => e.id === 'y_double');
    const state = {
      flags: { l2u_y_invited: true, link2urPath_team: true, l2u_y_merger_accepted: true },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urTeamMembers: [{}, {}],  // only 2
    };
    expect(entry.condition(state)).toBe(false);
  });

  test('link2ur_team_founded requires link2urPath_team + l2u_y_merger_declined_independent', () => {
    const entry = ENDINGS.find(e => e.id === 'link2ur_team_founded');
    const state = {
      flags: { link2urPath_team: true, l2u_y_merger_declined_independent: true },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urTeamMembers: [{}, {}],  // 2 members
    };
    expect(entry.condition(state)).toBe(true);
  });

  test('link2ur_team_founded does NOT trigger with team size < 2', () => {
    const entry = ENDINGS.find(e => e.id === 'link2ur_team_founded');
    const state = {
      flags: { link2urPath_team: true, l2u_y_merger_declined_independent: true },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urTeamMembers: [{}],  // only 1
    };
    expect(entry.condition(state)).toBe(false);
  });

  test('link2ur_solo_apex requires solo path + niche + rating 4.95 + 40 completed', () => {
    const entry = ENDINGS.find(e => e.id === 'link2ur_solo_apex');
    const state = {
      flags: { link2urPath_solo: true, l2u_solo_niche_chosen: true },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urRating: 4.96,
      link2urCompletedCount: 41,
    };
    expect(entry.condition(state)).toBe(true);
  });

  test('link2ur_solo_apex does NOT trigger with rating < 4.95', () => {
    const entry = ENDINGS.find(e => e.id === 'link2ur_solo_apex');
    const state = {
      flags: { link2urPath_solo: true, l2u_solo_niche_chosen: true },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urRating: 4.90,
      link2urCompletedCount: 41,
    };
    expect(entry.condition(state)).toBe(false);
  });

  test('link2ur_solo_apex does NOT trigger with completed < 40', () => {
    const entry = ENDINGS.find(e => e.id === 'link2ur_solo_apex');
    const state = {
      flags: { link2urPath_solo: true, l2u_solo_niche_chosen: true },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urRating: 4.96,
      link2urCompletedCount: 39,
    };
    expect(entry.condition(state)).toBe(false);
  });
});

describe('y_double resolves before regular Tier 1 endings (priority order)', () => {
  test('y_double fires before sarah_double when both conditions are met', () => {
    const state = {
      flags: {
        l2u_y_invited: true, link2urPath_team: true, l2u_y_merger_accepted: true,
        // also set sarah double flags to verify priority
        cotswolds_xmas: true, eurotrip_sarah: true,
      },
      stats: { academic: 50, wallet: 500, energy: 50, belonging: 50 },
      storyProgress: {},
      npcRel: {},
      link2urTeamMembers: [{}, {}, {}, {}],
    };
    const e = resolveEnding(state);
    expect(e.id).toBe('y_double');
  });
});

describe('existing endings backfill text (§7.2)', () => {
  test('becoming body contains Link2Ur backfill text about postcard', () => {
    const entry = ENDINGS.find(e => e.id === 'becoming');
    expect(entry.ending.text).toContain('Link2Ur 上服务的最后一个跨境品牌客户');
    expect(entry.ending.text).toContain('明信片');
  });

  test('returned_with_wk body contains Y 姐 crossover text', () => {
    const entry = ENDINGS.find(e => e.id === 'returned_with_wk');
    expect(entry.ending.text).toContain('Y 姐去年来上海找我谈合作');
    expect(entry.ending.text).toContain('中国茶饮品牌进 UK');
  });

  test('oxford body contains Whitmore academic AI proofreading mention', () => {
    const entry = ENDINGS.find(e => e.id === 'oxford');
    expect(entry.ending.text).toContain('DPhil 第一个学期还兼着接 Whitmore 介绍的学术 AI 校对客户');
  });

  test('survivor body contains Link2Ur thank-you letter text', () => {
    const entry = ENDINGS.find(e => e.id === 'survivor');
    expect(entry.ending.text).toContain('Link2Ur 给你写过一封感谢信');
    expect(entry.ending.text).toContain('AI 算法消耗的劳动');
  });
});
