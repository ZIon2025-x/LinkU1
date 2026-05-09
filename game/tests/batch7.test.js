import { describe, test, expect } from 'vitest';
import { NPC_DEEPENING_EVENTS } from '../src/data/npcDeepening.js';
import { MEI_WORK_EVENTS } from '../src/data/meiWork.js';
import { STRANGERS } from '../src/data/strangers.js';
import { STRANGER_EVENTS } from '../src/data/strangerEvents.js';
import { reducer, initialState } from '../src/engine/state.js';

describe('batch 7a: NPC deepening events', () => {
  test('Sarah / Aditi / Whitmore deepening events exist', () => {
    const allIds = Object.values(NPC_DEEPENING_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('sarah_cotswolds_secret');
    expect(allIds).toContain('aditi_dad_worsening');
    expect(allIds).toContain('aditi_quits_program');
    expect(allIds).toContain('whitmore_retiring');
    expect(allIds).toContain('whitmore_last_office_hour');
  });

  test('Sarah secret gated on cotswolds_visited + sarah rel >= 7', () => {
    const ev = NPC_DEEPENING_EVENTS.flat.find(e => e.id === 'sarah_cotswolds_secret');
    expect(ev.condition({ flags: {}, npcRel: { sarah: 9 } })).toBeFalsy();
    expect(ev.condition({ flags: { cotswolds_visited: true }, npcRel: { sarah: 4 } })).toBeFalsy();
    expect(ev.condition({ flags: { cotswolds_visited: true }, npcRel: { sarah: 7 } })).toBeTruthy();
  });

  test('Whitmore last office hour requires whitmore_retiring flag', () => {
    const ev = NPC_DEEPENING_EVENTS.uni.find(e => e.id === 'whitmore_last_office_hour');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { whitmore_retiring: true } })).toBeTruthy();
    expect(ev.minWeek).toBeGreaterThanOrEqual(50);
  });
});

describe('batch 7b: new strangers (Aisha / Marcus / Park)', () => {
  test('all 3 new strangers registered', () => {
    const ids = STRANGERS.map(s => s.id);
    expect(ids).toContain('aisha');
    expect(ids).toContain('marcus');
    expect(ids).toContain('park');
  });

  test('each has a distinct meeting location', () => {
    const aisha = STRANGERS.find(s => s.id === 'aisha');
    const marcus = STRANGERS.find(s => s.id === 'marcus');
    const park = STRANGERS.find(s => s.id === 'park');
    expect(aisha.metAt).toBe('library');
    expect(marcus.metAt).toBe('pub');
    expect(park.metAt).toBe('soho');
  });

  test('each has follow-up events with weeksAfter progression', () => {
    const eventsFor = (sid) => STRANGER_EVENTS.filter(e => e.strangerId === sid);
    expect(eventsFor('aisha').length).toBeGreaterThanOrEqual(2);
    expect(eventsFor('marcus').length).toBeGreaterThanOrEqual(2);
    expect(eventsFor('park').length).toBeGreaterThanOrEqual(2);

    // Each NPC's deeper event requires their friend flag from the first
    for (const sid of ['aisha', 'marcus', 'park']) {
      const events = eventsFor(sid);
      const requireFlagged = events.filter(e => e.requireFlag);
      expect(requireFlagged.length).toBeGreaterThanOrEqual(1);
    }
  });
});

describe('batch 7c: Mei work arc', () => {
  test('5 mei work events chain through flags', () => {
    const ids = MEI_WORK_EVENTS.mei.map(e => e.id);
    expect(ids).toContain('mei_first_shift');
    expect(ids).toContain('mei_difficult_customer');
    expect(ids).toContain('mei_late_night_chat');
    expect(ids).toContain('mei_promotion_offer');
    expect(ids).toContain('mei_first_paycheck_home');
  });

  test('first shift requires mei_job (set by existing storyline) + not yet serving', () => {
    const ev = MEI_WORK_EVENTS.mei.find(e => e.id === 'mei_first_shift');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { mei_job: true } })).toBeTruthy();
    expect(ev.condition({ flags: { mei_job: true, mei_serving: true } })).toBeFalsy();
  });

  test('promotion requires intimate-talk to have happened', () => {
    const ev = MEI_WORK_EVENTS.mei.find(e => e.id === 'mei_promotion_offer');
    expect(ev.condition({ flags: { mei_serving: true } })).toBeFalsy();
    expect(ev.condition({ flags: { mei_intimate: true } })).toBeTruthy();
    expect(ev.condition({ flags: { mei_intimate: true, mei_manager_path: true } })).toBeFalsy();
  });
});

describe('batch 7d: diary system', () => {
  test('initial state has empty diaryChoices array', () => {
    const s = initialState();
    expect(s.diaryChoices).toEqual([]);
  });

  test('LOG_DIARY action prepends new entry with day + week', () => {
    let s = initialState();
    s = { ...s, day: 22 };  // simulate week 4 day 22
    s = reducer(s, { type: 'LOG_DIARY', title: '加 CSSA', line: '"我加" 选项' });
    expect(s.diaryChoices.length).toBe(1);
    expect(s.diaryChoices[0]).toMatchObject({
      day: 22, week: 4, title: '加 CSSA', line: '"我加" 选项',
    });
  });

  test('multiple LOG_DIARY entries are stored newest-first', () => {
    let s = initialState();
    s = { ...s, day: 5 };
    s = reducer(s, { type: 'LOG_DIARY', title: '一', line: 'x' });
    s = { ...s, day: 10 };
    s = reducer(s, { type: 'LOG_DIARY', title: '二', line: 'y' });
    s = { ...s, day: 15 };
    s = reducer(s, { type: 'LOG_DIARY', title: '三', line: 'z' });
    expect(s.diaryChoices.map(e => e.title)).toEqual(['三', '二', '一']);
  });

  test('RESET clears diaryChoices', () => {
    let s = initialState();
    s = reducer(s, { type: 'LOG_DIARY', title: '一', line: 'x' });
    s = reducer(s, { type: 'RESET' });
    expect(s.diaryChoices).toEqual([]);
  });
});
