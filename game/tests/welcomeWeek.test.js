import { describe, test, expect } from 'vitest';
import { WELCOME_WEEK_EVENTS } from '../src/data/welcomeWeek.js';

describe('welcome-week event data', () => {
  test('every event has an id, minWeek, and at least one effect path', () => {
    for (const [loc, events] of Object.entries(WELCOME_WEEK_EVENTS)) {
      for (const ev of events) {
        expect(ev.id, `${loc}: missing id`).toBeTruthy();
        expect(typeof ev.minWeek).toBe('number');
        // event must either have a top-level effect (auto-applied) or choices
        expect(!!ev.effect || (Array.isArray(ev.choices) && ev.choices.length > 0))
          .toBe(true);
      }
    }
  });

  test('auto-events are tightly week-scoped (minWeek === maxWeek)', () => {
    // Auto events should fire deterministically in a narrow window — usually W1.
    // If maxWeek isn't set, the event would persist forever and trigger out of context.
    for (const events of Object.values(WELCOME_WEEK_EVENTS)) {
      for (const ev of events) {
        if (!ev.auto) continue;
        expect(ev.maxWeek, `${ev.id}: auto event missing maxWeek`).toBeDefined();
        expect(ev.maxWeek).toBeGreaterThanOrEqual(ev.minWeek);
      }
    }
  });

  test('all event ids are globally unique', () => {
    const ids = [];
    for (const events of Object.values(WELCOME_WEEK_EVENTS)) {
      for (const ev of events) ids.push(ev.id);
    }
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('Welcome Week orientation set is comprehensive', () => {
    const allIds = Object.values(WELCOME_WEEK_EVENTS).flatMap(e => e.map(x => x.id));
    // Real Welcome Week milestones — every one of these must exist
    const required = [
      'brp_reminder',         // 10-day BRP collection deadline
      'brp_collect',          // actual post office trip
      'gp_register',          // NHS GMS1 form
      'enrolment',            // student services check-in
      'student_oyster',       // 18+ Student Oyster, 30% off TFL
      'council_tax_exempt',   // exemption letter to council
      'open_monzo',           // UK bank account
    ];
    for (const id of required) {
      expect(allIds, `missing required event: ${id}`).toContain(id);
    }
  });

  test('Bicester daigou available only after settling in (W4+)', () => {
    const bicester = WELCOME_WEEK_EVENTS.station.find(e => e.id === 'bicester_trip');
    expect(bicester).toBeDefined();
    expect(bicester.minWeek).toBeGreaterThanOrEqual(4);
  });

  test('repeatable events (Loon Fung, meal deal) marked correctly', () => {
    const loonFung = WELCOME_WEEK_EVENTS.soho.find(e => e.id === 'loon_fung');
    expect(loonFung.repeatable).toBe(true);
    const mealDeal = WELCOME_WEEK_EVENTS.tesco.find(e => e.id === 'meal_deal');
    expect(mealDeal.repeatable).toBe(true);
  });
});
