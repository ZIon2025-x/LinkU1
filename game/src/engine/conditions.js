// Unified condition evaluation.
//
// The original game has two trigger styles:
//   1. STORYLINES.chapters[i].trigger = { rel: 5, location: 'uni', flag: 'foo' }  — declarative object
//   2. AT_YOU_EVENTS / NPC_NETWORK_EVENTS / HOLIDAY_SECRETS use condition: (state) => bool
//
// We accept both. Pass any item to `matches(item, state)` and it figures out the rest.

/**
 * Evaluate a declarative trigger object against the current game state.
 * Supported keys:
 *   rel:     minimum NPC relationship (resolved via `npcId` arg or item.npc)
 *   location: required current location id
 *   flag:    flag name that must be truthy
 *   flagAny: array of flag names — at least one must be truthy
 *   minWeek: earliest week
 */
export function matchTrigger(trigger, state, npcId) {
  if (!trigger) return true;
  if (trigger.rel !== undefined && npcId) {
    if ((state.npcRel?.[npcId] || 0) < trigger.rel) return false;
  }
  if (trigger.location && trigger.location !== state.currentLocationId) return false;
  if (trigger.flag && !state.flags?.[trigger.flag]) return false;
  if (trigger.flagAny && Array.isArray(trigger.flagAny)) {
    if (!trigger.flagAny.some(f => state.flags?.[f])) return false;
  }
  if (trigger.minWeek && state.week < trigger.minWeek) return false;
  return true;
}

/**
 * Match either a condition function or a trigger object on the same item.
 * `state` should contain at least: npcRel, flags, stats, week, currentLocationId, storyProgress.
 */
export function matches(item, state) {
  if (!item) return false;
  if (typeof item.condition === 'function') {
    return !!item.condition({
      npcRel: state.npcRel || {},
      stats: state.stats || {},
      flags: state.flags || {},
      storyProgress: state.storyProgress || {},
      week: state.week,
      day: state.day,
    });
  }
  if (item.trigger) return matchTrigger(item.trigger, state, item.npc);
  return true;
}

/**
 * Find next unseen storyline chapter triggered by the current state.
 * Returns { lineId, chapter } or null.
 */
export function findStoryTrigger(storylines, state) {
  for (const lineId of Object.keys(storylines)) {
    const line = storylines[lineId];
    // Gender-locked storylines: only fire for matching player gender. This is
    // for scam lines whose narrative requires opposite-gender attraction
    // (pig butchering Daniel/Diana mirror) or gender-specific funnels
    // (cosmetic MLM aimed at women / trading-mentor aimed at men).
    if (line.forGender && line.forGender !== state.gender) continue;
    const progress = state.storyProgress?.[lineId] || 0;
    if (progress >= line.chapters.length) continue;
    const chapter = line.chapters[progress];
    if (state.seenChapters?.includes(chapter.id)) continue;
    if (!matchTrigger(chapter.trigger, state, line.npc)) continue;
    return { lineId, chapter };
  }
  return null;
}
