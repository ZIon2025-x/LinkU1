// Sanity tests for the 5-batch expansion (post-grad / romance / friction /
// end-game / wellbeing). Catches structural mistakes (missing ids, broken
// conditions, choice-level conditions) without requiring a full play.

import { describe, test, expect } from 'vitest';
import { POST_GRAD_EVENTS } from '../src/data/postGrad.js';
import { CULTURE_FRICTION_EVENTS } from '../src/data/cultureFriction.js';
import { END_GAME_EVENTS } from '../src/data/endGame.js';
import { WELLBEING_EVENTS } from '../src/data/wellbeing.js';
import { MARK_ARC_EVENTS } from '../src/data/markArc.js';
import { FLAT_HUNT_EVENTS } from '../src/data/flatHunt.js';
import { JOB_HUNT_DEEP_EVENTS } from '../src/data/jobHuntDeep.js';
import { STORYLINES } from '../src/data/storylines.js';
import { NPCS } from '../src/data/npcs.js';
import { ENDINGS, resolveEnding } from '../src/data/endings.js';
import { initialState } from '../src/engine/state.js';

const ALL_BATCH_FILES = {
  postGrad: POST_GRAD_EVENTS,
  cultureFriction: CULTURE_FRICTION_EVENTS,
  endGame: END_GAME_EVENTS,
  wellbeing: WELLBEING_EVENTS,
  markArc: MARK_ARC_EVENTS,
  flatHunt: FLAT_HUNT_EVENTS,
  jobHuntDeep: JOB_HUNT_DEEP_EVENTS,
};

describe('batch 1: post-grad visa + jobs', () => {
  test('PSW visa + LinkedIn + Big4 FOMO + sponsor + mom call + decision night exist', () => {
    const ids = POST_GRAD_EVENTS.flat.map(e => e.id);
    expect(ids).toContain('psw_visa_apply');
    expect(ids).toContain('linkedin_open_to_work');
    expect(ids).toContain('classmate_big4_offer');
    expect(ids).toContain('sponsor_list_search');
    expect(ids).toContain('mom_call_come_home');
    expect(ids).toContain('first_interview_online');
    expect(ids).toContain('china_bias_interview');
    expect(ids).toContain('psw_decision_eve');
  });

  test('PSW decision night gated on psw_applied', () => {
    const ev = POST_GRAD_EVENTS.flat.find(e => e.id === 'psw_decision_eve');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { psw_applied: true } })).toBeTruthy();
  });

  test('all post-grad events fire in W37+ (dissertation / job hunt season)', () => {
    for (const events of Object.values(POST_GRAD_EVENTS)) {
      for (const ev of events) {
        expect(ev.minWeek).toBeGreaterThanOrEqual(37);
      }
    }
  });
});

describe('batch 2: Lin Nan romance line', () => {
  test('NPC registered with locations', () => {
    expect(NPCS.linnan).toBeDefined();
    expect(NPCS.linnan.locations).toContain('library');
  });

  test('storyline has 5 chapters with progressive rel gates', () => {
    const line = STORYLINES.linnan;
    expect(line).toBeDefined();
    expect(line.chapters.length).toBe(5);
    const relGates = line.chapters.map(c => c.trigger?.rel ?? 0);
    // Each subsequent chapter requires more rel
    for (let i = 1; i < relGates.length; i++) {
      expect(relGates[i]).toBeGreaterThanOrEqual(relGates[i - 1]);
    }
  });

  test('ch4-5 require linnan_dating flag (friend-zone branch caps progress)', () => {
    const ch4 = STORYLINES.linnan.chapters[3];
    const ch5 = STORYLINES.linnan.chapters[4];
    expect(ch4.trigger.flag).toBe('linnan_dating');
    expect(ch5.trigger.flag).toBe('linnan_dating');
  });

  test('initialState includes linnan progress + rel', () => {
    const s = initialState();
    expect(s.npcRel.linnan).toBe(0);
    expect(s.storyProgress.linnan).toBe(0);
  });

  test('three Lin Nan endings exist + are mutually exclusive on flags', () => {
    const ids = ENDINGS.map(e => e.id);
    expect(ids).toContain('linnan_stayed');
    expect(ids).toContain('linnan_ldr');
    expect(ids).toContain('linnan_broke');

    // Only one of the 3 linnan flags should fire at a time
    const stay = resolveEnding({
      flags: { linnan_stay_together: true },
      stats: { academic: 0, wallet: 0, energy: 0, belonging: 0 },
      storyProgress: {}, npcRel: {},
    });
    expect(stay.id).toBe('linnan_stayed');
  });
});

describe('batch 3: cultural friction', () => {
  test('key microaggression events exist across locations', () => {
    const allIds = Object.values(CULTURE_FRICTION_EVENTS).flatMap(arr => arr.map(e => e.id));
    expect(allIds).toContain('where_really_from');
    expect(allIds).toContain('classroom_microaggression');
    expect(allIds).toContain('pub_overheard_hostile');
    expect(allIds).toContain('shop_followed');
    expect(allIds).toContain('landlord_silent_reject');
    expect(allIds).toContain('package_misdelivered');
    expect(allIds).toContain('tube_seat_avoided');
  });

  test('tube seat avoidance is repeatable (passive accumulation)', () => {
    const ev = CULTURE_FRICTION_EVENTS.station.find(e => e.id === 'tube_seat_avoided');
    expect(ev.repeatable).toBe(true);
  });
});

describe('batch 4: end-game content', () => {
  test('housing search + dissertation panic + last Pret + packing + last call exist', () => {
    const ids = END_GAME_EVENTS.flat.map(e => e.id);
    expect(ids).toContain('housing_search_2nd_year');
    expect(ids).toContain('dissertation_panic');
    expect(ids).toContain('last_pret_meal_deal');
    expect(ids).toContain('packing_box_to_china');
    expect(ids).toContain('last_call_with_mom');
  });

  test('Mei goodbye event splits into staying / returning by stayed_uk_grad flag', () => {
    const stay = END_GAME_EVENTS.mei.find(e => e.id === 'last_visit_mei_staying');
    const leave = END_GAME_EVENTS.mei.find(e => e.id === 'last_visit_mei_returning');
    expect(stay.condition({ npcRel: { mei: 5 }, flags: { stayed_uk_grad: true } })).toBeTruthy();
    expect(stay.condition({ npcRel: { mei: 5 }, flags: {} })).toBeFalsy();
    expect(leave.condition({ npcRel: { mei: 5 }, flags: {} })).toBeTruthy();
    expect(leave.condition({ npcRel: { mei: 5 }, flags: { stayed_uk_grad: true } })).toBeFalsy();
  });

  test('graduation ceremony exists at W52', () => {
    const grad = END_GAME_EVENTS.uni.find(e => e.id === 'graduation_ceremony');
    expect(grad).toBeDefined();
    expect(grad.minWeek).toBe(52);
  });
});

describe('batch 5: wellbeing — body / mental / family conflict', () => {
  test('body-care events (vit D / weight / hair) exist', () => {
    const ids = WELLBEING_EVENTS.flat.map(e => e.id);
    expect(ids).toContain('vitamin_d_deficiency');
    expect(ids).toContain('pret_weight_gain');
    expect(ids).toContain('hair_falling_out');
  });

  test('mental support infrastructure (SU / Samaritans / NHS Talking) exists', () => {
    const ids = WELLBEING_EVENTS.flat.map(e => e.id);
    expect(ids).toContain('su_wellbeing_referral');
    expect(ids).toContain('samaritans_late_night');
    expect(ids).toContain('nhs_talking_therapies');
  });

  test('NHS Talking Therapies gated on gp_registered', () => {
    const ev = WELLBEING_EVENTS.flat.find(e => e.id === 'nhs_talking_therapies');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { gp_registered: true } })).toBeTruthy();
  });

  test('family-conflict events (career / dad hospital / marriage) exist', () => {
    const ids = WELLBEING_EVENTS.flat.map(e => e.id);
    expect(ids).toContain('mom_career_pressure');
    expect(ids).toContain('dad_hospital_news');
  });

  test('marriage pressure splits by linnan_dating', () => {
    const withPartner = WELLBEING_EVENTS.flat.find(e => e.id === 'mom_marriage_pressure_with_partner');
    const solo = WELLBEING_EVENTS.flat.find(e => e.id === 'mom_marriage_pressure_solo');
    expect(withPartner.condition({ flags: { linnan_dating: true } })).toBeTruthy();
    expect(withPartner.condition({ flags: {} })).toBeFalsy();
    expect(solo.condition({ flags: { linnan_dating: true } })).toBeFalsy();
    expect(solo.condition({ flags: {} })).toBeTruthy();
  });
});

describe('batch 6a: Mark redemption arc', () => {
  test('Mark arc has 3 chapters chained on flags', () => {
    const ids = MARK_ARC_EVENTS.flat.map(e => e.id);
    expect(ids).toEqual(['mark_arc_apology', 'mark_arc_friendship', 'mark_arc_farewell']);
  });

  test('apology chapter requires mark_called_out + not yet apologized', () => {
    const ev = MARK_ARC_EVENTS.flat.find(e => e.id === 'mark_arc_apology');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { mark_called_out: true } })).toBeTruthy();
    expect(ev.condition({ flags: { mark_called_out: true, mark_apologized: true } })).toBeFalsy();
  });

  test('friendship chapter requires mark_apologized + not yet friend', () => {
    const ev = MARK_ARC_EVENTS.flat.find(e => e.id === 'mark_arc_friendship');
    expect(ev.condition({ flags: { mark_apologized: true } })).toBeTruthy();
    expect(ev.condition({ flags: { mark_apologized: true, mark_friend: true } })).toBeFalsy();
  });

  test('farewell chapter requires mark_friend (only at year-end)', () => {
    const ev = MARK_ARC_EVENTS.flat.find(e => e.id === 'mark_arc_farewell');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { mark_friend: true } })).toBeTruthy();
    expect(ev.minWeek).toBeGreaterThanOrEqual(50);
  });
});

describe('batch 6b: flat hunt arc', () => {
  test('5 events covering RightMove → viewing → reject → guarantor → moving', () => {
    const ids = FLAT_HUNT_EVENTS.flat.map(e => e.id);
    expect(ids).toContain('rightmove_obsession');
    expect(ids).toContain('first_viewing_chaos');
    expect(ids).toContain('reference_silent_reject');
    expect(ids).toContain('guarantor_service');
    expect(ids).toContain('moving_day');
  });

  test('moving_day gated on private_flat (from endGame)', () => {
    const ev = FLAT_HUNT_EVENTS.flat.find(e => e.id === 'moving_day');
    expect(ev.condition({ flags: {} })).toBeFalsy();
    expect(ev.condition({ flags: { private_flat: true } })).toBeTruthy();
  });

  test('flat hunt sequence is W30+', () => {
    for (const ev of FLAT_HUNT_EVENTS.flat) {
      expect(ev.minWeek).toBeGreaterThanOrEqual(30);
    }
  });
});

describe('batch 6c: job hunt deep arc', () => {
  test('AC + final round + offer + fallback events exist', () => {
    const ids = [...JOB_HUNT_DEEP_EVENTS.uni.map(e => e.id), ...JOB_HUNT_DEEP_EVENTS.flat.map(e => e.id)];
    expect(ids).toContain('assessment_centre');
    expect(ids).toContain('final_round_rejected');
    expect(ids).toContain('offer_negotiation');
    expect(ids).toContain('fallback_plan');
  });

  test('fallback plan only fires if no offer accepted yet', () => {
    const ev = JOB_HUNT_DEEP_EVENTS.flat.find(e => e.id === 'fallback_plan');
    expect(ev.condition({ flags: {} })).toBeTruthy();
    expect(ev.condition({ flags: { accepted_first_offer: true } })).toBeFalsy();
    expect(ev.condition({ flags: { negotiated_offer: true } })).toBeFalsy();
    expect(ev.condition({ flags: { stayed_uk_grad: true } })).toBeFalsy();
  });
});

describe('cross-batch invariants', () => {
  test('no batch contains choice-level condition (engine only supports event-level)', () => {
    for (const [name, events] of Object.entries(ALL_BATCH_FILES)) {
      for (const arr of Object.values(events)) {
        for (const ev of arr) {
          for (const ch of ev.choices || []) {
            expect(ch.condition, `${name}: ${ev.id}: choice has unsupported condition`).toBeUndefined();
          }
        }
      }
    }
  });

  test('all batch event ids are globally unique', () => {
    const ids = [];
    for (const events of Object.values(ALL_BATCH_FILES)) {
      for (const arr of Object.values(events)) {
        for (const ev of arr) ids.push(ev.id);
      }
    }
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('every event has a play path (effect or choices)', () => {
    for (const events of Object.values(ALL_BATCH_FILES)) {
      for (const arr of Object.values(events)) {
        for (const ev of arr) {
          const hasPath = !!ev.effect || (Array.isArray(ev.choices) && ev.choices.length > 0);
          expect(hasPath, `${ev.id}: no effect or choices`).toBe(true);
        }
      }
    }
  });
});
