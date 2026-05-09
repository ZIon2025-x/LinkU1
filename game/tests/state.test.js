import { describe, test, expect } from 'vitest';
import { reducer, initialState, applyEffect } from '../src/engine/state.js';

describe('reducer initial state', () => {
  test('starts on intro screen with default stats', () => {
    const s = initialState();
    expect(s.screen).toBe('intro');
    expect(s.day).toBe(1);
    expect(s.stats).toEqual({ academic: 0, wallet: 2000, energy: 80, belonging: 20 });
    expect(s.actionsLeft).toBe(3);
  });
});

describe('applyEffect', () => {
  const base = initialState();

  test('clamps stats into [0, 100]', () => {
    const out = applyEffect(base, { academic: 200 });
    expect(out.stats.academic).toBe(100);
    const out2 = applyEffect(base, { energy: -200 });
    expect(out2.stats.energy).toBe(0);
  });

  test('wallet is unclamped (can go negative)', () => {
    const out = applyEffect(base, { wallet: -2500 });
    expect(out.stats.wallet).toBe(-500);
  });

  test('rel target bumps named npc relationship', () => {
    const out = applyEffect(base, { rel: 3 }, 'sarah');
    expect(out.npcRel.sarah).toBe(3);
  });

  test('npc map updates multiple npcs at once', () => {
    const out = applyEffect(base, { npc: { sarah: 2, mei: 1 } });
    expect(out.npcRel.sarah).toBe(2);
    expect(out.npcRel.mei).toBe(1);
  });

  test('flag sets to true', () => {
    const out = applyEffect(base, { flag: 'parents_coming' });
    expect(out.flags.parents_coming).toBe(true);
  });

  test('object-form rel (from holiday secrets) bumps multiple', () => {
    const out = applyEffect(base, { rel: { sarah: 4, aditi: 2 } });
    expect(out.npcRel.sarah).toBe(4);
    expect(out.npcRel.aditi).toBe(2);
  });
});

describe('reducer actions', () => {
  test('SPEND_ACTION decrements actionsLeft, floors at 0', () => {
    let s = initialState();
    s = reducer(s, { type: 'SPEND_ACTION' });
    expect(s.actionsLeft).toBe(2);
    s = reducer(s, { type: 'SPEND_ACTION' });
    s = reducer(s, { type: 'SPEND_ACTION' });
    s = reducer(s, { type: 'SPEND_ACTION' });
    expect(s.actionsLeft).toBe(0);
  });

  test('END_DAY advances day, restores actions, +15 energy', () => {
    let s = initialState();
    s = reducer(s, { type: 'PATCH_STATS', stats: { energy: 50 } });
    s = reducer(s, { type: 'SPEND_ACTION' });
    s = reducer(s, { type: 'END_DAY' });
    expect(s.day).toBe(2);
    expect(s.actionsLeft).toBe(3);
    expect(s.stats.energy).toBe(65);
  });

  test('STORY_ADVANCE bumps progress and marks chapter seen', () => {
    let s = initialState();
    s = reducer(s, { type: 'STORY_ADVANCE', lineId: 'sarah', chapterId: 'sarah_1' });
    expect(s.storyProgress.sarah).toBe(1);
    expect(s.seenChapters).toContain('sarah_1');
  });

  test('STORY_ADVANCE is idempotent on chapter id (no duplicate seen)', () => {
    let s = initialState();
    s = reducer(s, { type: 'STORY_ADVANCE', lineId: 'sarah', chapterId: 'sarah_1' });
    s = reducer(s, { type: 'STORY_ADVANCE', lineId: 'sarah', chapterId: 'sarah_1' });
    expect(s.seenChapters.filter(id => id === 'sarah_1').length).toBe(1);
    expect(s.storyProgress.sarah).toBe(2);  // progress still bumps
  });

  test('ADD_MESSAGE appends and bumps unread', () => {
    let s = initialState();
    s = reducer(s, { type: 'ADD_MESSAGE', message: { id: 1, text: 'hi' } });
    s = reducer(s, { type: 'ADD_MESSAGE', message: { id: 2, text: 'yo' } });
    expect(s.messages.length).toBe(2);
    expect(s.unreadMessages).toBe(2);
    s = reducer(s, { type: 'READ_MESSAGES' });
    expect(s.unreadMessages).toBe(0);
  });

  test('SET_ENDING transitions screen to ending', () => {
    let s = initialState();
    s = reducer(s, { type: 'SET_ENDING', ending: { title: 'X', text: 'Y' } });
    expect(s.screen).toBe('ending');
    expect(s.ending.title).toBe('X');
  });

  test('RESET returns to initial', () => {
    let s = initialState();
    s = reducer(s, { type: 'PATCH_STATS', stats: { academic: 99 } });
    s = reducer(s, { type: 'SET_FLAG', flag: 'foo' });
    s = reducer(s, { type: 'RESET' });
    expect(s.stats.academic).toBe(0);
    expect(s.flags).toEqual({});
  });
});

describe('weather + festival tracking', () => {
  test('SET_WEEK_WEATHER sets weather for week', () => {
    let s = initialState();
    s = reducer(s, { type: 'SET_WEEK_WEATHER', week: 5, weather: 'sunny' });
    expect(s.weekWeather[5]).toBe('sunny');
  });

  test('MARK_FESTIVAL_SEEN deduplicates', () => {
    let s = initialState();
    s = reducer(s, { type: 'MARK_FESTIVAL_SEEN', id: 'halloween' });
    s = reducer(s, { type: 'MARK_FESTIVAL_SEEN', id: 'halloween' });
    expect(s.seenFestivals.filter(id => id === 'halloween').length).toBe(1);
  });
});
