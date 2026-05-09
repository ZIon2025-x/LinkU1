import { describe, test, expect } from 'vitest';
import { matchTrigger, matches, findStoryTrigger } from '../src/engine/conditions.js';
import { STORYLINES } from '../src/data/storylines.js';

const baseState = {
  npcRel: { sarah: 0, mei: 0, wangkai: 0, aditi: 0, whitmore: 0 },
  storyProgress: { sarah: 0, mei: 0, wangkai: 0, aditi: 0, whitmore: 0 },
  flags: {},
  stats: { academic: 30, wallet: 800, energy: 80, belonging: 20 },
  week: 1, day: 1,
  currentLocationId: null,
  seenChapters: [],
};

describe('matchTrigger (object-style trigger from STORYLINES)', () => {
  test('rel threshold respected', () => {
    expect(matchTrigger({ rel: 3 }, baseState, 'sarah')).toBe(false);
    expect(matchTrigger({ rel: 3 }, { ...baseState, npcRel: { sarah: 5 } }, 'sarah')).toBe(true);
  });

  test('location must match', () => {
    expect(matchTrigger({ location: 'pub' }, { ...baseState, currentLocationId: 'pub' })).toBe(true);
    expect(matchTrigger({ location: 'pub' }, { ...baseState, currentLocationId: 'mei' })).toBe(false);
  });

  test('flag must be truthy', () => {
    expect(matchTrigger({ flag: 'cotswolds_visited' }, baseState)).toBe(false);
    expect(matchTrigger({ flag: 'cotswolds_visited' }, { ...baseState, flags: { cotswolds_visited: true } })).toBe(true);
  });

  test('rel + location + flag combine (all must hold)', () => {
    const trigger = { rel: 9, flag: 'cotswolds_visited' };
    expect(matchTrigger(trigger, { ...baseState, npcRel: { sarah: 9 } }, 'sarah')).toBe(false);  // missing flag
    expect(matchTrigger(trigger, { ...baseState, npcRel: { sarah: 9 }, flags: { cotswolds_visited: true } }, 'sarah')).toBe(true);
  });

  test('null/undefined trigger always matches', () => {
    expect(matchTrigger(null, baseState)).toBe(true);
    expect(matchTrigger(undefined, baseState)).toBe(true);
  });
});

describe('matches (function-style condition)', () => {
  test('function condition is invoked with full state', () => {
    const item = { condition: ({ stats }) => stats.academic >= 50 };
    expect(matches(item, baseState)).toBe(false);
    expect(matches(item, { ...baseState, stats: { ...baseState.stats, academic: 80 } })).toBe(true);
  });

  test('falls through to matchTrigger when only trigger is set', () => {
    const item = { trigger: { rel: 2 }, npc: 'sarah' };
    expect(matches(item, { ...baseState, npcRel: { sarah: 5 } })).toBe(true);
  });
});

describe('findStoryTrigger', () => {
  test('finds Sarah ch1 when at pub with rel >= 1 and no progress', () => {
    // sarah_1 trigger requires { rel: 1, location: 'pub' }
    const state = { ...baseState, currentLocationId: 'pub', npcRel: { ...baseState.npcRel, sarah: 1 } };
    const found = findStoryTrigger(STORYLINES, state);
    expect(found?.lineId).toBe('sarah');
    expect(found?.chapter.id).toBe('sarah_1');
  });

  test('finds Mei ch1 when at mei (no rel requirement)', () => {
    // mei_1 trigger is { rel: 0, location: 'mei' } — matches with default rel:0
    const state = { ...baseState, currentLocationId: 'mei' };
    const found = findStoryTrigger(STORYLINES, state);
    expect(found?.lineId).toBe('mei');
  });

  test('skips lines whose progress is exhausted', () => {
    const state = {
      ...baseState,
      currentLocationId: 'pub',
      storyProgress: { sarah: STORYLINES.sarah.chapters.length },
    };
    const found = findStoryTrigger(STORYLINES, state);
    expect(found?.lineId).not.toBe('sarah');
  });

  test('respects rel gating', () => {
    // sarah_2 needs rel:3, location:library
    const state = {
      ...baseState,
      currentLocationId: 'library',
      storyProgress: { sarah: 1 },  // already past ch1
      npcRel: { sarah: 2 },  // too low
    };
    const found = findStoryTrigger(STORYLINES, state);
    // should not match Sarah ch2 because rel < 3
    expect(found?.chapter?.id).not.toBe('sarah_2');
  });
});
