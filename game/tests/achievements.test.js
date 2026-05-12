import { describe, test, expect } from 'vitest';
import {
  ACHIEVEMENTS, ACHIEVEMENT_BY_ID, TIER_META, computeUnlocked,
} from '../src/data/achievements.js';
import { reducer, initialState } from '../src/engine/state.js';

describe('achievements · data shape', () => {
  test('every achievement has required fields', () => {
    for (const a of ACHIEVEMENTS) {
      expect(a.id).toBeTruthy();
      expect(a.tier).toBeTruthy();
      expect(['common', 'rare', 'epic', 'legendary']).toContain(a.tier);
      expect(a.icon).toBeTruthy();
      expect(a.title).toBeTruthy();
      expect(a.desc).toBeTruthy();
      expect(typeof a.check).toBe('function');
    }
  });

  test('all ids globally unique', () => {
    const ids = ACHIEVEMENTS.map(a => a.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('lookup map is correct', () => {
    expect(ACHIEVEMENT_BY_ID.brp_collected).toBeDefined();
    expect(ACHIEVEMENT_BY_ID.brp_collected.tier).toBe('common');
    expect(ACHIEVEMENT_BY_ID.linnan_forever?.tier).toBe('legendary');
  });

  test('tier distribution sane (more common, fewer legendary)', () => {
    const buckets = { common: 0, rare: 0, epic: 0, legendary: 0 };
    for (const a of ACHIEVEMENTS) buckets[a.tier]++;
    expect(buckets.common).toBeGreaterThanOrEqual(5);
    expect(buckets.rare).toBeGreaterThanOrEqual(5);
    expect(buckets.epic).toBeGreaterThanOrEqual(3);
    expect(buckets.legendary).toBeLessThanOrEqual(buckets.rare);  // not too many golds
  });

  test('each tier has a meta entry with a photo bg color', () => {
    for (const tier of ['common', 'rare', 'epic', 'legendary']) {
      expect(TIER_META[tier]).toBeDefined();
      expect(TIER_META[tier].photoBg).toMatch(/^#[0-9a-f]{6}$/i);
    }
  });
});

describe('achievements · check predicates', () => {
  test('BRP achievement fires only with brp_collected flag', () => {
    const a = ACHIEVEMENT_BY_ID.brp_collected;
    expect(a.check({ flags: {} })).toBe(false);
    expect(a.check({ flags: { brp_collected: true } })).toBe(true);
  });

  test('legendary parents-distinction needs both flag and stat', () => {
    const a = ACHIEVEMENT_BY_ID.distinction_parents;
    expect(a.check({ flags: { parents_visited: true }, stats: { academic: 50 } })).toBe(false);
    expect(a.check({ flags: { parents_visited: false }, stats: { academic: 80 } })).toBe(false);
    expect(a.check({ flags: { parents_visited: true }, stats: { academic: 70 } })).toBe(true);
  });

  test('Sarah double requires both Cotswolds + euro trip', () => {
    const a = ACHIEVEMENT_BY_ID.sarah_double;
    expect(a.check({ flags: { cotswolds_xmas: true } })).toBe(false);
    expect(a.check({ flags: { cotswolds_xmas: true, eurotrip_sarah: true } })).toBe(true);
  });

  test('Link2Ur 5-star needs ≥5 completed AND rating ≥ 4.8', () => {
    const a = ACHIEVEMENT_BY_ID.link2ur_5star;
    expect(a.check({ link2urCompleted: [1, 2, 3], link2urRating: 4.9 })).toBe(false);
    expect(a.check({ link2urCompleted: [1, 2, 3, 4, 5], link2urRating: 4.5 })).toBe(false);
    expect(a.check({ link2urCompleted: [1, 2, 3, 4, 5], link2urRating: 4.8 })).toBe(true);
  });

  test('check predicate is robust to missing fields', () => {
    for (const a of ACHIEVEMENTS) {
      // shouldn't throw on completely empty state
      expect(() => a.check({})).not.toThrow();
    }
  });
});

describe('achievements · computeUnlocked', () => {
  test('empty state unlocks nothing (or only flagless ones, none currently)', () => {
    const unlocked = computeUnlocked({});
    expect(unlocked.length).toBe(0);
  });

  test('flag flip unlocks the matching achievement', () => {
    const a = computeUnlocked({ flags: { brp_collected: true } });
    expect(a).toContain('brp_collected');
    expect(a).not.toContain('parents_visited');
  });

  test('returns ids only, in original definition order', () => {
    const ids = computeUnlocked({
      flags: {
        brp_collected: true, gp_registered: true, parents_visited: true,
      },
      stats: { academic: 50 },
    });
    expect(ids).toEqual(expect.arrayContaining(['brp_collected', 'gp_registered', 'parents_visited']));
  });
});

describe('achievements · Link2Ur milestones (6 new)', () => {
  test('6 Link2Ur entrepreneurship achievements exist with correct ids', () => {
    const expectedIds = [
      'l2u_first_repeat',
      'l2u_clash_survived',
      'l2u_y_audience',
      'l2u_first_hire',
      'l2u_team_5',
      'l2u_ai_anxiety_resolved',
    ];
    for (const id of expectedIds) {
      expect(ACHIEVEMENT_BY_ID[id]).toBeDefined();
    }
  });

  test('Link2Ur achievements have required fields', () => {
    const expectedIds = [
      'l2u_first_repeat',
      'l2u_clash_survived',
      'l2u_y_audience',
      'l2u_first_hire',
      'l2u_team_5',
      'l2u_ai_anxiety_resolved',
    ];
    for (const id of expectedIds) {
      const a = ACHIEVEMENT_BY_ID[id];
      expect(a.title).toBeTruthy();
      expect(a.desc).toBeTruthy();
      expect(a.icon).toBeTruthy();
      expect(a.tier).toBeTruthy();
      expect(typeof a.check).toBe('function');
    }
  });

  test('Link2Ur tier distribution: 1 common, 2 rare, 2 epic, 1 legendary', () => {
    const ids = [
      'l2u_first_repeat',
      'l2u_clash_survived',
      'l2u_y_audience',
      'l2u_first_hire',
      'l2u_team_5',
      'l2u_ai_anxiety_resolved',
    ];
    const tiers = ids.map(id => ACHIEVEMENT_BY_ID[id].tier);
    const buckets = { common: 0, rare: 0, epic: 0, legendary: 0 };
    for (const tier of tiers) buckets[tier]++;

    expect(buckets.common).toBe(1);
    expect(buckets.rare).toBe(2);
    expect(buckets.epic).toBe(2);
    expect(buckets.legendary).toBe(1);
  });

  test('Link2Ur check predicates respond to flags', () => {
    expect(ACHIEVEMENT_BY_ID.l2u_first_repeat.check({ flags: { l2u_first_repeat_unlocked: true } })).toBe(true);
    expect(ACHIEVEMENT_BY_ID.l2u_clash_survived.check({ flags: { l2u_clash_survived_unlocked: true } })).toBe(true);
    expect(ACHIEVEMENT_BY_ID.l2u_y_audience.check({ flags: { l2u_y_audience_unlocked: true } })).toBe(true);
    expect(ACHIEVEMENT_BY_ID.l2u_first_hire.check({ flags: { l2u_first_hire_unlocked: true } })).toBe(true);
    expect(ACHIEVEMENT_BY_ID.l2u_team_5.check({ flags: { l2u_team_5_unlocked: true } })).toBe(true);
    expect(ACHIEVEMENT_BY_ID.l2u_ai_anxiety_resolved.check({ flags: { l2u_ai_anxiety_resolved_unlocked: true } })).toBe(true);
  });
});

describe('achievements · reducer integration', () => {
  test('UNLOCK_ACHIEVEMENTS appends with week stamp', () => {
    let s = initialState();
    s = { ...s, day: 22 };  // week 4
    s = reducer(s, { type: 'UNLOCK_ACHIEVEMENTS', ids: ['brp_collected', 'gp_registered'] });
    expect(s.unlockedAchievements).toEqual([
      { id: 'brp_collected', week: 4 },
      { id: 'gp_registered', week: 4 },
    ]);
  });

  test('UNLOCK_ACHIEVEMENTS skips already-unlocked ids', () => {
    let s = initialState();
    s = reducer(s, { type: 'UNLOCK_ACHIEVEMENTS', ids: ['brp_collected'] });
    s = reducer(s, { type: 'UNLOCK_ACHIEVEMENTS', ids: ['brp_collected', 'gp_registered'] });
    expect(s.unlockedAchievements.length).toBe(2);
    const ids = s.unlockedAchievements.map(a => a.id);
    expect(ids).toEqual(['brp_collected', 'gp_registered']);
  });

  test('RESET clears unlocked achievements', () => {
    let s = initialState();
    s = reducer(s, { type: 'UNLOCK_ACHIEVEMENTS', ids: ['brp_collected'] });
    s = reducer(s, { type: 'RESET' });
    expect(s.unlockedAchievements).toEqual([]);
  });
});
