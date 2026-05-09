// Game state shape + reducer.
//
// Original game had 50+ useState hooks. Collapsing them all into a single
// reducer made action handlers (chooseStoryOption, chooseHoliday, replyAtYou,
// etc.) much shorter — they all converge on the same effect-application path.
//
// Actions are intentionally fine-grained and named after the player intent,
// not the state slice they touch. Most domain logic still lives in the App
// orchestrator (which decides *which* action to dispatch given the situation)
// but the *effect* of a chosen branch is uniform here.

import { clamp } from './util.js';
import { DAILY_ACTIONS } from '../data/calendar.js';
import { STARTING_WALLET, STARTING_ACADEMIC } from '../data/onboarding.js';

export function initialState() {
  return {
    screen: 'intro',  // intro | plane | arrival | playing | travel | ending
    day: 1,
    actionsLeft: DAILY_ACTIONS,
    stats: { academic: STARTING_ACADEMIC, wallet: STARTING_WALLET, energy: 80, belonging: 20 },
    npcRel: { sarah: 0, wangkai: 0, aditi: 0, whitmore: 0, mei: 0, linnan: 0 },
    storyProgress: { sarah: 0, mei: 0, wangkai: 0, aditi: 0, whitmore: 0, linnan: 0 },
    flags: {},
    seenChapters: [],
    seenLocationEvents: {},

    // Messaging
    messages: [],
    unreadMessages: 0,
    groupChat: [],
    seenGroupWeeks: [],
    unreadGroup: 0,

    // Calendar features
    weekWeather: {},
    seenFestivals: [],
    seenWeatherEvents: [],

    // Player customization
    birthdayMonth: null,
    birthdayCelebrated: false,
    gender: null,           // 'male' | 'female' | null (set during onboarding)

    // Stranger system
    addedStrangers: [],
    strangerAddedAt: {},
    seenAtYouEvents: [],
    seenStrangerEvents: [],

    // Diary / mental state
    seenDreams: [],
    seenInsomnia: [],
    seenNostalgia: [],
    nostalgiaCount: 0,
    crisisTriggered: false,

    // Auto-logged "decisions that mattered" — appended whenever a choice
    // sets a flag. Newest first. UI surfaces this in the Diary tab.
    diaryChoices: [],

    // Unlocked achievement ids — paired with week of unlock for display.
    // Shape: [{ id, week }]
    unlockedAchievements: [],

    // Link2Ur in-game platform state
    link2urBoard: [],          // tasks currently visible
    link2urBoardWeek: 0,       // when the board was last refreshed
    link2urCompleted: [],      // task ids completed (for stats)
    link2urPosted: [],         // template ids the player has posted (one-shot)
    link2urRating: 5.0,        // player's seller rating
    link2urEarnings: 0,        // total £ earned via accept
    link2urFriendsCompleted: [], // friend-task ids completed (one-shot)

    // Parents storyline
    parentsChapter: 0,

    // Attendance
    classesAttendedThisWeek: 0,
    attendanceHistory: [],
    monthAttendance: [],

    // Holiday + exam + dissertation
    holidayChoice: null,
    examResults: {},
    dissertationProgress: 0,
    dissertationTopic: null,

    // Travel
    travelMode: null,
    travelEventsSeen: {},
    travelDayUsed: 0,
    postcards: [],

    // Ending payload
    ending: null,
  };
}

/**
 * Derived helpers used by the reducer & UI.
 */
export const derive = {
  week: (state) => Math.ceil(state.day / 7),
  dayOfWeek: (state) => ((state.day - 1) % 7) + 1,
  attendanceRate: (state) => {
    const classWeeks = state.attendanceHistory.filter(a => (a.required || 4) > 0);
    if (classWeeks.length === 0) return 100;
    const att = classWeeks.reduce((s, h) => s + h.attended, 0);
    const req = classWeeks.reduce((s, h) => s + (h.required || 4), 0);
    return req > 0 ? Math.round((att / req) * 100) : 100;
  },
  currentMonthRate: (state) =>
    state.monthAttendance.length > 0
      ? state.monthAttendance[state.monthAttendance.length - 1].rate
      : null,
};

/**
 * Apply an effect object ({ academic, wallet, energy, belonging, flag, npc, rel })
 * to a state slice. Returns a partial { stats, flags, npcRel } update.
 *
 * `npcRelTarget` is the npc id whose relationship `effect.rel` (a single delta
 * from STORYLINES / NPC dialog) applies to. `effect.npc` is a multi-NPC delta
 * map used by NPC_NETWORK_EVENTS.
 */
export function applyEffect(state, effect, npcRelTarget) {
  if (!effect) return {};
  const stats = {
    academic: clamp(state.stats.academic + (effect.academic || 0), 0, 100),
    wallet: state.stats.wallet + (effect.wallet || 0),
    energy: clamp(state.stats.energy + (effect.energy || 0), 0, 100),
    belonging: clamp(state.stats.belonging + (effect.belonging || 0), 0, 100),
  };
  const out = { stats };
  if (effect.flag) out.flags = { ...state.flags, [effect.flag]: true };
  if (effect.rel && npcRelTarget) {
    out.npcRel = { ...state.npcRel, [npcRelTarget]: (state.npcRel[npcRelTarget] || 0) + effect.rel };
  }
  if (effect.npc) {
    const next = out.npcRel ? { ...out.npcRel } : { ...state.npcRel };
    Object.entries(effect.npc).forEach(([id, delta]) => {
      next[id] = (next[id] || 0) + delta;
    });
    out.npcRel = next;
  }
  // Effects with `rel: { sarah: 4, ... }` (object) come from holiday secrets etc.
  if (effect.rel && typeof effect.rel === 'object') {
    const next = out.npcRel ? { ...out.npcRel } : { ...state.npcRel };
    Object.entries(effect.rel).forEach(([id, delta]) => {
      next[id] = (next[id] || 0) + delta;
    });
    out.npcRel = next;
  }
  return out;
}

export function reducer(state, action) {
  switch (action.type) {
    case 'RESET':
      return initialState();

    case 'SET_BIRTHDAY':
      return {
        ...state,
        birthdayMonth: action.month,
        gender: action.gender || state.gender,
        screen: 'plane',
      };

    case 'SET_SCREEN':
      return { ...state, screen: action.screen };

    case 'SPEND_ACTION':
      return { ...state, actionsLeft: Math.max(0, state.actionsLeft - 1) };

    case 'APPLY_EFFECT': {
      const patch = applyEffect(state, action.effect, action.npcRelTarget);
      return { ...state, ...patch };
    }

    case 'PATCH_STATS':
      return { ...state, stats: { ...state.stats, ...action.stats } };

    case 'SET_FLAG':
      return { ...state, flags: { ...state.flags, [action.flag]: action.value !== undefined ? action.value : true } };

    case 'SET_FLAGS':
      return { ...state, flags: { ...state.flags, ...action.flags } };

    case 'BUMP_NPC_REL': {
      const next = { ...state.npcRel };
      Object.entries(action.delta || {}).forEach(([id, d]) => { next[id] = (next[id] || 0) + d; });
      return { ...state, npcRel: next };
    }

    case 'STORY_ADVANCE': {
      const seen = state.seenChapters.includes(action.chapterId)
        ? state.seenChapters
        : [...state.seenChapters, action.chapterId];
      return {
        ...state,
        seenChapters: seen,
        storyProgress: {
          ...state.storyProgress,
          [action.lineId]: (state.storyProgress[action.lineId] || 0) + 1,
        },
      };
    }

    case 'MARK_LOCATION_EVENT_SEEN': {
      const list = state.seenLocationEvents[action.locId] || [];
      return {
        ...state,
        seenLocationEvents: {
          ...state.seenLocationEvents,
          [action.locId]: list.includes(action.eventId) ? list : [...list, action.eventId],
        },
      };
    }

    case 'MARK_NETWORK_EVENT_SEEN': {
      const network = state.seenLocationEvents._network || [];
      return {
        ...state,
        seenLocationEvents: {
          ...state.seenLocationEvents,
          _network: network.includes(action.eventId) ? network : [...network, action.eventId],
        },
      };
    }

    case 'ADD_MESSAGE':
      return {
        ...state,
        messages: [...state.messages, action.message],
        unreadMessages: state.unreadMessages + 1,
      };
    case 'READ_MESSAGES':
      return { ...state, unreadMessages: 0 };

    case 'APPEND_GROUP_MESSAGES':
      return {
        ...state,
        groupChat: [...state.groupChat, ...action.messages],
        unreadGroup: state.unreadGroup + action.messages.length,
        seenGroupWeeks: action.markWeek != null && !state.seenGroupWeeks.includes(action.markWeek)
          ? [...state.seenGroupWeeks, action.markWeek]
          : state.seenGroupWeeks,
      };
    case 'READ_GROUP':
      return { ...state, unreadGroup: 0 };

    case 'SET_WEEK_WEATHER':
      return { ...state, weekWeather: { ...state.weekWeather, [action.week]: action.weather } };

    case 'MARK_FESTIVAL_SEEN':
      return state.seenFestivals.includes(action.id)
        ? state
        : { ...state, seenFestivals: [...state.seenFestivals, action.id] };

    case 'MARK_WEATHER_EVENT_SEEN':
      return state.seenWeatherEvents.includes(action.id)
        ? state
        : { ...state, seenWeatherEvents: [...state.seenWeatherEvents, action.id] };

    case 'ADD_STRANGER':
      return {
        ...state,
        addedStrangers: [...state.addedStrangers, action.id],
        strangerAddedAt: { ...state.strangerAddedAt, [action.id]: action.week },
      };
    case 'MARK_AT_YOU_SEEN':
      return state.seenAtYouEvents.includes(action.id)
        ? state
        : { ...state, seenAtYouEvents: [...state.seenAtYouEvents, action.id] };
    case 'MARK_STRANGER_EVENT_SEEN':
      return state.seenStrangerEvents.includes(action.id)
        ? state
        : { ...state, seenStrangerEvents: [...state.seenStrangerEvents, action.id] };

    case 'MARK_DREAM_SEEN':
      return { ...state, seenDreams: [...state.seenDreams, action.id] };
    case 'MARK_INSOMNIA_SEEN':
      return { ...state, seenInsomnia: [...state.seenInsomnia, action.id] };
    case 'MARK_NOSTALGIA_SEEN':
      return state.seenNostalgia.includes(action.id)
        ? state
        : { ...state, seenNostalgia: [...state.seenNostalgia, action.id] };
    case 'BUMP_NOSTALGIA_COUNT':
      return { ...state, nostalgiaCount: state.nostalgiaCount + 1 };
    case 'RESET_NOSTALGIA_COUNT':
      return { ...state, nostalgiaCount: 0 };
    case 'TRIGGER_CRISIS':
      return { ...state, crisisTriggered: true };

    // ── Link2Ur ──
    case 'L2U_REFRESH_BOARD':
      return { ...state, link2urBoard: action.tasks, link2urBoardWeek: action.week };
    case 'L2U_ACCEPT_TASK': {
      // Remove from board, add to completed, pay reward, deduct action+energy.
      const t = action.task;
      const newBoard = state.link2urBoard.filter(x => x.id !== t.id);
      const newRating = (() => {
        const count = state.link2urCompleted.length + 1;
        const w = Math.min(0.3, 1 / Math.max(1, count));
        return Math.round((state.link2urRating * (1 - w) + t.rating * w) * 10) / 10;
      })();
      // 熟人单：把 templateId 加进 link2urFriendsCompleted，确保不会再刷
      const friendsCompleted = t.friendTask
        ? [...(state.link2urFriendsCompleted || []), t.templateId]
        : (state.link2urFriendsCompleted || []);
      // 完成数量里程碑 → 触发 freelance 剧情线对应章节的 flag
      const newCompletedCount = state.link2urCompleted.length + 1;
      const milestoneFlags = { ...state.flags };
      if (newCompletedCount >= 3) milestoneFlags.l2u_3_done = true;
      if (newCompletedCount >= 8) milestoneFlags.l2u_8_done = true;
      return {
        ...state,
        link2urBoard: newBoard,
        link2urCompleted: [...state.link2urCompleted, { id: t.id, templateId: t.templateId, reward: t.reward, week: t.week }],
        link2urFriendsCompleted: friendsCompleted,
        link2urRating: newRating,
        link2urEarnings: state.link2urEarnings + t.reward,
        actionsLeft: Math.max(0, state.actionsLeft - (t.actionCost || 1)),
        flags: milestoneFlags,
        stats: {
          ...state.stats,
          wallet: state.stats.wallet + t.reward,
          energy: clamp(state.stats.energy - (t.energyCost || 0), 0, 100),
        },
      };
    }
    case 'L2U_POST_TASK': {
      const p = action.post;
      const patches = {};
      if (p.energyGain) {
        patches.energy = clamp(state.stats.energy + p.energyGain, 0, 100);
      }
      if (p.academicGain) {
        patches.academic = clamp(state.stats.academic + p.academicGain, 0, 100);
      }
      const flags = p.setsFlag ? { ...state.flags, [p.setsFlag]: true } : state.flags;
      return {
        ...state,
        link2urPosted: [...state.link2urPosted, p.id],
        flags,
        actionsLeft: p.actionGain ? Math.min(3, state.actionsLeft + p.actionGain) : state.actionsLeft,
        stats: {
          ...state.stats,
          wallet: state.stats.wallet - p.cost,
          ...patches,
        },
      };
    }

    case 'UNLOCK_ACHIEVEMENTS': {
      // action.ids is a list of achievement ids that just newly satisfied
      // their predicate. Skip ones already unlocked.
      const existing = new Set(state.unlockedAchievements.map(a => a.id));
      const fresh = action.ids
        .filter(id => !existing.has(id))
        .map(id => ({ id, week: Math.ceil(state.day / 7) }));
      if (fresh.length === 0) return state;
      return { ...state, unlockedAchievements: [...state.unlockedAchievements, ...fresh] };
    }

    case 'LOG_DIARY':
      return {
        ...state,
        diaryChoices: [
          { day: state.day, week: Math.ceil(state.day / 7), title: action.title, line: action.line },
          ...state.diaryChoices,
        ],
      };

    case 'PARENTS_ADVANCE':
      return { ...state, parentsChapter: action.chapter };

    case 'CLASSES_ATTENDED_INC':
      return { ...state, classesAttendedThisWeek: state.classesAttendedThisWeek + 1 };
    case 'CLASSES_ATTENDED_RESET':
      return { ...state, classesAttendedThisWeek: 0 };
    case 'PUSH_ATTENDANCE':
      return { ...state, attendanceHistory: [...state.attendanceHistory, action.entry] };
    case 'PUSH_MONTH_ATTENDANCE':
      return { ...state, monthAttendance: [...state.monthAttendance, action.entry] };

    case 'SET_HOLIDAY_CHOICE':
      return { ...state, holidayChoice: action.value };
    case 'RECORD_EXAM_SCORE':
      return { ...state, examResults: { ...state.examResults, [action.id]: action.score } };
    case 'SET_DISSERTATION_TOPIC':
      return { ...state, dissertationTopic: action.topic };
    case 'BUMP_DISSERTATION':
      return { ...state, dissertationProgress: Math.min(100, state.dissertationProgress + action.amount) };
    case 'BIRTHDAY_DONE':
      return { ...state, birthdayCelebrated: true };

    case 'START_TRAVEL':
      return {
        ...state,
        travelMode: { destination: action.destination, daysLeft: action.destination.days },
        travelDayUsed: 0,
        screen: 'travel',
      };
    case 'TRAVEL_DAY_TICK':
      return { ...state, travelDayUsed: state.travelDayUsed + 1 };
    case 'MARK_TRAVEL_EVENT_SEEN': {
      const cityList = state.travelEventsSeen[action.city] || [];
      return {
        ...state,
        travelEventsSeen: {
          ...state.travelEventsSeen,
          [action.city]: cityList.includes(action.eventId) ? cityList : [...cityList, action.eventId],
        },
      };
    }
    case 'ADD_POSTCARD':
      return state.postcards.find(p => p.id === action.postcard.id)
        ? state
        : { ...state, postcards: [...state.postcards, action.postcard] };
    case 'FINISH_TRAVEL':
      return {
        ...state,
        day: Math.min(state.day + (state.travelMode?.destination.days || 0), 364),
        travelMode: null,
        travelDayUsed: 0,
        screen: 'playing',
        actionsLeft: DAILY_ACTIONS,
        stats: { ...state.stats, energy: clamp(state.stats.energy + 5, 0, 100) },
      };

    case 'END_DAY':
      // Most of end-of-day logic is orchestrated by App.jsx because it dispatches
      // multiple actions in sequence (rent, attendance, weather, festival, etc.).
      // Here we just advance the day counter & restore actions/energy.
      return {
        ...state,
        day: state.day + 1,
        actionsLeft: DAILY_ACTIONS,
        stats: { ...state.stats, energy: clamp(state.stats.energy + 15, 0, 100) },
      };

    case 'SET_ENDING':
      return { ...state, ending: action.ending, screen: 'ending' };

    default:
      return state;
  }
}
