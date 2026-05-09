import { describe, test, expect } from 'vitest';
import { DAILY_LIFE_EVENTS } from '../src/data/dailyLife.js';

describe('daily-life event data', () => {
  test('every event has id, minWeek, and a play path', () => {
    for (const events of Object.values(DAILY_LIFE_EVENTS)) {
      for (const ev of events) {
        expect(ev.id).toBeTruthy();
        expect(typeof ev.minWeek).toBe('number');
        expect(!!ev.effect || (Array.isArray(ev.choices) && ev.choices.length > 0)).toBe(true);
      }
    }
  });

  test('all event ids globally unique', () => {
    const ids = [];
    for (const events of Object.values(DAILY_LIFE_EVENTS)) {
      for (const ev of events) ids.push(ev.id);
    }
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('ensuite kitchen drama events exist and are repeatable', () => {
    const flat = DAILY_LIFE_EVENTS.flat;
    const repeatableIds = flat.filter(e => e.repeatable).map(e => e.id);
    // Kitchen pain points should recur — they happen every week IRL
    expect(repeatableIds).toContain('fridge_yoghurt_stolen');
    expect(repeatableIds).toContain('milk_drunk');
    expect(repeatableIds).toContain('kitchen_party_2am');
    expect(repeatableIds).toContain('kitchen_messy_friday');
  });

  test('heating drama is winter-only (W8-16)', () => {
    const heating = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'heating_broken');
    expect(heating).toBeDefined();
    expect(heating.minWeek).toBeGreaterThanOrEqual(8);
    expect(heating.maxWeek).toBeLessThanOrEqual(16);
  });

  test('BRP typo only fires after BRP collected', () => {
    const brpTypo = DAILY_LIFE_EVENTS.station.find(e => e.id === 'brp_typo');
    expect(brpTypo).toBeDefined();
    expect(typeof brpTypo.condition).toBe('function');
    // gating: must have brp_collected flag
    expect(brpTypo.condition({ flags: {} })).toBeFalsy();
    expect(brpTypo.condition({ flags: { brp_collected: true } })).toBeTruthy();
  });

  test('Apple Pay realisation only fires before settling Oyster habits (W2-12)', () => {
    const ap = DAILY_LIFE_EVENTS.station.find(e => e.id === 'apple_pay_tap');
    expect(ap).toBeDefined();
    expect(ap.minWeek).toBeGreaterThanOrEqual(2);
    expect(ap.maxWeek).toBeLessThanOrEqual(12);
  });

  test('city-life one-shots (Argos, Boots, contactless limit) exist', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('argos_pickup');
    expect(allIds).toContain('boots_first_visit');
    expect(allIds).toContain('contactless_limit');
  });

  test('fire-alarm event chain wires through fire_alarm_witnessed flag', () => {
    const fa = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'fire_alarm_3am');
    expect(fa.choices.some(c => c.effect.flag === 'fire_alarm_witnessed')).toBe(true);

    const aftermath = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'fire_alarm_aftermath');
    expect(aftermath).toBeDefined();
    expect(aftermath.condition({ flags: {} })).toBeFalsy();
    expect(aftermath.condition({ flags: { fire_alarm_witnessed: true } })).toBeTruthy();
  });

  test('parcel held hostage is repeatable (housemates forget more than once)', () => {
    const e = DAILY_LIFE_EVENTS.flat.find(x => x.id === 'parcel_held_hostage');
    expect(e?.repeatable).toBe(true);
  });

  test('self-checkout unexpected-item event repeats (it always happens again)', () => {
    const e = DAILY_LIFE_EVENTS.tesco.find(x => x.id === 'self_checkout_unexpected');
    expect(e?.repeatable).toBe(true);
  });

  test('night bus + sorting office + self-checkout exist', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('night_bus_n29');
    expect(allIds).toContain('royal_mail_missed');
    expect(allIds).toContain('self_checkout_unexpected');
  });

  test('no heating-bill events exist (utilities included in student rent)', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    const billIds = allIds.filter(id =>
      id.includes('heating_bill') || id.includes('gas_bill') || id.includes('electric_bill')
    );
    expect(billIds).toEqual([]);
  });

  test('NHS health pipeline (screening + vaccinations + GP appointment) exists', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('nhs_screening_letter');
    expect(allIds).toContain('nhs_vaccinations');
    expect(allIds).toContain('gp_appointment');
  });

  test('NHS vaccinations gated on gp_registered', () => {
    const ev = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'nhs_vaccinations');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { gp_registered: true } })).toBeTruthy();
  });

  test('housemate beats (Mark / Tom roast / paper-thin walls / 5C moves out) exist', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('mark_confrontation');
    expect(allIds).toContain('tom_sunday_roast');
    expect(allIds).toContain('paper_thin_walls');
    expect(allIds).toContain('housemate_moves_out');
  });

  test('Tom Sunday roast gated on tom_friend (the fire-alarm aftermath flag)', () => {
    const ev = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'tom_sunday_roast');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { tom_friend: true } })).toBeTruthy();
  });

  test('Boots Photo passport-photo continuation gated on brp_reissued', () => {
    const ev = DAILY_LIFE_EVENTS.soho.find(e => e.id === 'boots_photo_passport');
    expect(ev).toBeDefined();
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { brp_reissued: true } })).toBeTruthy();
  });

  test('no per-choice condition functions (engine only supports event-level condition)', () => {
    // Choice-level conditions silently no-op in the current engine; if a future
    // change adds support, drop this test. For now, prevent regression.
    for (const events of Object.values(DAILY_LIFE_EVENTS)) {
      for (const ev of events) {
        for (const ch of ev.choices || []) {
          expect(ch.condition, `${ev.id}: choice has unsupported condition`).toBeUndefined();
        }
      }
    }
  });

  test('seasonal/cultural events span the full year', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('bonfire_night');           // Nov
    expect(allIds).toContain('black_friday');            // late Nov
    expect(allIds).toContain('boxing_day_selfridges');   // Dec 26
    expect(allIds).toContain('st_patricks');             // Mar 17
    expect(allIds).toContain('freshers_flu');            // W3-4
    expect(allIds).toContain('house_meeting');           // any time
    expect(allIds).toContain('wagamama_first');
    expect(allIds).toContain('nandos_first');
    expect(allIds).toContain('westfield_first');
  });

  test('Eurovision splits into mutually-exclusive variants based on tom_friend', () => {
    const withTom = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'eurovision_with_tom');
    const alone = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'eurovision_alone');
    expect(withTom).toBeDefined();
    expect(alone).toBeDefined();
    // Exactly one fires for any given state — never both, never neither.
    const stateNoTom = { flags: {} };
    const stateTom = { flags: { tom_friend: true } };
    expect(withTom.condition(stateNoTom)).toBeFalsy();
    expect(alone.condition(stateNoTom)).toBeTruthy();
    expect(withTom.condition(stateTom)).toBeTruthy();
    expect(alone.condition(stateTom)).toBeFalsy();
  });

  test('Bonfire Night lives at park (Hyde Park is the venue)', () => {
    const ev = DAILY_LIFE_EVENTS.park.find(e => e.id === 'bonfire_night');
    expect(ev).toBeDefined();
    expect(ev.minWeek).toBeGreaterThanOrEqual(10);
  });

  test('St Patrick\'s lives at pub (drinking holiday)', () => {
    const ev = DAILY_LIFE_EVENTS.pub.find(e => e.id === 'st_patricks');
    expect(ev).toBeDefined();
  });

  test('Boxing Day fires within Christmas break window (W14-16)', () => {
    const ev = DAILY_LIFE_EVENTS.soho.find(e => e.id === 'boxing_day_selfridges');
    expect(ev).toBeDefined();
    expect(ev.minWeek).toBeGreaterThanOrEqual(14);
    expect(ev.maxWeek).toBeLessThanOrEqual(16);
  });

  test('academic events live at uni / library', () => {
    const uniIds = DAILY_LIFE_EVENTS.uni.map(e => e.id);
    expect(uniIds).toContain('reading_list_overwhelm');
    expect(uniIds).toContain('turnitin_crashes');
    expect(uniIds).toContain('tutor_silent_email');
    expect(uniIds).toContain('group_project_freeloader');

    const libIds = DAILY_LIFE_EVENTS.library.map(e => e.id);
    expect(libIds).toContain('library_group_room');
    expect(libIds).toContain('library_2am');
    expect(libIds).toContain('library_phone_glare');
  });

  test('Turnitin crash fires near first essay deadline (W10-12)', () => {
    const ev = DAILY_LIFE_EVENTS.uni.find(e => e.id === 'turnitin_crashes');
    expect(ev.minWeek).toBeGreaterThanOrEqual(10);
    expect(ev.maxWeek).toBeLessThanOrEqual(12);
  });

  test('group project freeloader timed to spring deadline (W20-22)', () => {
    const ev = DAILY_LIFE_EVENTS.uni.find(e => e.id === 'group_project_freeloader');
    expect(ev.minWeek).toBeGreaterThanOrEqual(20);
    expect(ev.maxWeek).toBeLessThanOrEqual(22);
  });

  test('strikes are present and time-windowed correctly', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('ucu_strike');
    expect(allIds).toContain('rail_strike');
    expect(allIds).toContain('royal_mail_strike');

    const royal = DAILY_LIFE_EVENTS.flat.find(e => e.id === 'royal_mail_strike');
    // Royal Mail Christmas strike — must fire around Christmas weeks
    expect(royal.minWeek).toBeGreaterThanOrEqual(12);
    expect(royal.maxWeek).toBeLessThanOrEqual(16);
  });

  test('rail strike repeats (recurring throughout the year)', () => {
    const ev = DAILY_LIFE_EVENTS.station.find(e => e.id === 'rail_strike');
    expect(ev.repeatable).toBe(true);
  });

  test('cost-of-living events present', () => {
    const allIds = Object.values(DAILY_LIFE_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('meal_deal_hike');
    expect(allIds).toContain('inflation_milk');
    expect(allIds).toContain('tube_fare_hike');
  });

  test('Tube fare annual hike fires in January (W16-18)', () => {
    const ev = DAILY_LIFE_EVENTS.station.find(e => e.id === 'tube_fare_hike');
    expect(ev.minWeek).toBeGreaterThanOrEqual(16);
    expect(ev.maxWeek).toBeLessThanOrEqual(18);
  });

  test('milk inflation event repeats (prices keep creeping up)', () => {
    const ev = DAILY_LIFE_EVENTS.tesco.find(e => e.id === 'inflation_milk');
    expect(ev.repeatable).toBe(true);
  });
});
