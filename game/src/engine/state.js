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

// 哪些 message sender 是"可点开私聊的真人"——他们的消息会同时进 chatThreads。
// 其它 sender (uni / l2u / l2u_cs / l2u_review / Faculty Office 等) 留在
// flat messages list 当系统通知用。
export const INTERACTIVE_NPC_IDS = [
  'sarah', 'aditi', 'wangkai', 'mei', 'whitmore', 'linnan', 'mark', 'tom', 'mom',
  'yjie',  // Y 姐 / 陈思敏 / Yvonne Chan · Link2Ur 创业线 mentor · 30 单后主动 DM
];

export function initialState() {
  return {
    screen: 'intro',  // intro | plane | arrival | playing | travel | ending
    day: 1,
    actionsLeft: DAILY_ACTIONS,
    stats: { academic: STARTING_ACADEMIC, wallet: STARTING_WALLET, energy: 80, belonging: 20 },
    npcRel: { sarah: 0, wangkai: 0, aditi: 0, whitmore: 0, mei: 0, linnan: 0 },
    storyProgress: { sarah: 0, mei: 0, wangkai: 0, aditi: 0, whitmore: 0, linnan: 0 },
    // Link2Ur 从 day 1 解锁（不再走 W3-5 的 discovery 事件）—— 平台是
    // 留学生 essential tool 而非可选副业。
    flags: { link2ur_discovered: true },
    seenChapters: [],
    seenLocationEvents: {},

    // Messaging
    messages: [],
    unreadMessages: 0,
    groupChat: [],
    seenGroupWeeks: [],
    unreadGroup: 0,

    // Per-NPC chat threads (V6 微信改造) —— 每个交互 NPC 一组对话历史
    // shape: { [npcId]: [{ role: 'them'|'you', text, day, time, fromName? }] }
    chatThreads: {},
    // 每个 thread 未读计数，进入 detail 后清零
    chatThreadUnread: {},
    // 已用过的 chatTopic option ids（防止同一选项重复出现）
    seenChatOptions: [],
    seenChatOptionsToday: [],   // 一日内问过的选项 id，END_DAY 时重置
    // NPC 主动发来的 hook ids（防止同一主动消息重复发）
    seenProactiveHooks: [],

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
    // ── 任务积压 · 紧迫感指数（0-100）──
    // 每天涨 +6（生活琐事越积越多：取快递/翻信/陪同/搬家/取药/...）。
    // 每接 1 单 −12，每发 1 个 post −18。压到 70+ 时:
    //   · belonging 每天 -2（"事情忙不过来"的焦虑）
    //   · energy 每天 -3
    //   · 80+ 触发 crisis 提示
    // 压到 30 以下时 belonging +1（"今天事情挺有把握"的踏实感）
    stress: 25,
    mealsToday: 0,    // 今日吃饭次数（吃饭/买菜/做饭/外卖/Meal Deal 都算），END_DAY 重置
    // ── Link2Ur 申请池 · 等待客户回复的任务 ──
    // shape: [{ taskId, templateId, appliedDay, requirement: {rating, count, skill} }]
    link2urPending: [],
    // 历史拒绝记录用于 "我的申请" 历史 tab
    link2urRejected: [],

    // ── Link2Ur 创业线 (第 7 主线, v2 AI 广告方向) ──
    // 回头客追踪 (key=customerId, value={count, lastTaskDay, avgRating, relationship})
    link2urRepeatCustomers: {},
    // 指定任务 inbox (绕过 board, customer 主动发)
    link2urInbox: [],
    // 时效冲突累积 + 历史
    link2urClashCount: 0,
    link2urClashEvents: [],
    // 路径选择 (Ch 4 W22 Sketch 邀请后定): null / 'solo' / 'team' / 'undecided'
    link2urPath: null,
    link2urPathDecidedDay: null,
    // 双阶段 (Ch 4 W22 Phase 1→2 不可逆 pivot)
    link2urPhase: 1,
    link2urPhaseShiftDay: null,
    // Team 路径状态
    link2urTeamMembers: [],  // runtime: [{ memberId, joinedDay, specialty, energy, completed, cutPercent, status }]
    link2urTeamRevenue: 0,
    // Y 姐 (陈思敏) 关系 + 章节进度
    yjieRelationship: 0,
    yjieChapter: 0,

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
    const classWeeks = state.attendanceHistory.filter(a => (a.required || 6) > 0);
    if (classWeeks.length === 0) return 100;
    const att = classWeeks.reduce((s, h) => s + h.attended, 0);
    const req = classWeeks.reduce((s, h) => s + (h.required || 6), 0);
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
  // 压力是顶层 state 字段，单独 patch
  if (typeof effect.stress === 'number') {
    out.stress = clamp((state.stress ?? 25) + effect.stress, 0, 100);
  }
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

    case 'ADD_MESSAGE': {
      const msg = action.message;
      const next = {
        ...state,
        messages: [...state.messages, msg],
        unreadMessages: state.unreadMessages + 1,
      };
      // 如果 sender 是交互 NPC，同步进 thread
      if (INTERACTIVE_NPC_IDS.includes(msg.from)) {
        next.chatThreads = {
          ...state.chatThreads,
          [msg.from]: [...(state.chatThreads[msg.from] || []), {
            role: 'them', text: msg.text, day: msg.day, time: msg.time, fromName: msg.fromName,
          }],
        };
        next.chatThreadUnread = {
          ...state.chatThreadUnread,
          [msg.from]: (state.chatThreadUnread[msg.from] || 0) + 1,
        };
      }
      return next;
    }
    case 'READ_MESSAGES':
      return { ...state, unreadMessages: 0 };

    case 'CHAT_THREAD_READ': {
      // 进入 detail 时清零该 thread 的未读
      if (!state.chatThreadUnread[action.npcId]) return state;
      const next = { ...state.chatThreadUnread };
      delete next[action.npcId];
      return { ...state, chatThreadUnread: next };
    }

    case 'CHAT_PLAYER_REPLY': {
      // 玩家发了 1 条消息（你气泡）+ 可选 NPC 立即回应（他/她气泡）。
      // npcReply 通常 null —— 由 CHAT_APPEND_NPC_REPLY 在延迟后追加。
      // groupId: 互斥组 id —— 同 group 任一选完，整组都进 seen 不再出现。
      // todayId: 若提供，会进 seenChatOptionsToday（每日重置）—— 用于
      //   smalltalk / 普通 ask 当天问过就不再冒出，但跨天还能再问。
      const { npcId, playerText, npcReply, optionId, groupId, todayId } = action;
      const day = state.day;
      const time = new Date().toLocaleTimeString().slice(0, 5);
      const adds = [{ role: 'you', text: playerText, day, time }];
      if (npcReply) adds.push({ role: 'them', text: npcReply, day, time });
      let seenNext = state.seenChatOptions;
      if (optionId && !seenNext.includes(optionId)) {
        seenNext = [...seenNext, optionId];
      }
      // group marker 用 '__g:' 前缀和 option id 区分
      if (groupId) {
        const gKey = `__g:${groupId}`;
        if (!seenNext.includes(gKey)) seenNext = [...seenNext, gKey];
      }
      let todayNext = state.seenChatOptionsToday || [];
      if (todayId && !todayNext.includes(todayId)) {
        todayNext = [...todayNext, todayId];
      }
      return {
        ...state,
        chatThreads: {
          ...state.chatThreads,
          [npcId]: [...(state.chatThreads[npcId] || []), ...adds],
        },
        seenChatOptions: seenNext,
        seenChatOptionsToday: todayNext,
      };
    }

    case 'CHAT_APPEND_NPC_REPLY': {
      // 给 thread 追加一条 NPC 气泡 (typing 延迟之后)
      const { npcId, text } = action;
      const day = state.day;
      const time = new Date().toLocaleTimeString().slice(0, 5);
      return {
        ...state,
        chatThreads: {
          ...state.chatThreads,
          [npcId]: [...(state.chatThreads[npcId] || []), {
            role: 'them', text, day, time,
          }],
        },
      };
    }

    case 'GROUP_PLAYER_POST': {
      // 玩家在群里发言。groupChat 结构 [{ id, from, week, day, text }]。
      // 玩家 from 用 '_you' 区分。follows 现在通常空 — 由
      // GROUP_APPEND_FOLLOW 在延迟后追加。
      const { text, follows, optionId, groupId } = action;
      const w = Math.ceil(state.day / 7);
      const baseId = Date.now() + Math.random();
      const entries = [{ id: baseId, from: '_you', week: w, day: state.day, text }];
      if (follows && follows.length) {
        follows.forEach((f, i) => entries.push({
          id: baseId + 0.001 + i * 0.001,
          from: f.from, week: w, day: state.day, text: f.text,
        }));
      }
      let seenNext = state.seenChatOptions;
      if (optionId && !seenNext.includes(optionId)) {
        seenNext = [...seenNext, optionId];
      }
      if (groupId) {
        const gKey = `__g:${groupId}`;
        if (!seenNext.includes(gKey)) seenNext = [...seenNext, gKey];
      }
      return {
        ...state,
        groupChat: [...state.groupChat, ...entries],
        seenChatOptions: seenNext,
      };
    }

    case 'GROUP_APPEND_FOLLOW': {
      // 群成员错峰回应玩家 post
      const { follow } = action;
      const w = Math.ceil(state.day / 7);
      return {
        ...state,
        groupChat: [...state.groupChat, {
          id: Date.now() + Math.random(),
          from: follow.from, week: w, day: state.day, text: follow.text,
        }],
      };
    }

    case 'MARK_PROACTIVE_HOOK_SEEN':
      return state.seenProactiveHooks.includes(action.id)
        ? state
        : { ...state, seenProactiveHooks: [...state.seenProactiveHooks, action.id] };

    case 'APPEND_GROUP_MESSAGES':
      return {
        ...state,
        groupChat: [...state.groupChat, ...action.messages.map(m => ({ day: state.day, ...m }))],
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
      const friendsCompleted = t.friendTask
        ? [...(state.link2urFriendsCompleted || []), t.templateId]
        : (state.link2urFriendsCompleted || []);
      const newCompletedCount = state.link2urCompleted.length + 1;
      const milestoneFlags = { ...state.flags };
      if (newCompletedCount >= 3) milestoneFlags.l2u_3_done = true;
      if (newCompletedCount >= 8) milestoneFlags.l2u_8_done = true;
      if (newCompletedCount >= 10) milestoneFlags.l2u_10_done = true;
      if (newCompletedCount >= 30) milestoneFlags.l2u_30_done = true;
      if (newCompletedCount >= 50) milestoneFlags.l2u_50_done = true;
      return {
        ...state,
        link2urBoard: newBoard,
        link2urCompleted: [...state.link2urCompleted, { id: t.id, templateId: t.templateId, type: t.type, reward: t.reward, week: t.week }],
        link2urFriendsCompleted: friendsCompleted,
        link2urRating: newRating,
        link2urEarnings: state.link2urEarnings + t.reward,
        actionsLeft: Math.max(0, state.actionsLeft - (t.actionCost || 1)),
        flags: milestoneFlags,
        // 接 1 单 −12 积压（你帮别人解决一件事，相当于消化生活琐事）
        stress: Math.max(0, (state.stress ?? 25) - 12),
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
        // 发 1 个 post −18 积压（外包了一件事，焦虑减轻最大）
        stress: Math.max(0, (state.stress ?? 25) - 18),
        stats: {
          ...state.stats,
          wallet: state.stats.wallet - p.cost,
          ...patches,
        },
      };
    }
    // 每天 endDay 增长积压（生活琐事自然累积）
    // 玩家做了一顿饭 / 买了菜 / 吃了外面 / Meal Deal 等 → mealsToday +1
    case 'INCREMENT_MEAL':
      return { ...state, mealsToday: (state.mealsToday || 0) + 1 };

    case 'L2U_BACKLOG_TICK':
      return { ...state, stress: Math.min(100, (state.stress ?? 25) + (action.amount ?? 6)) };
    // 申请 task 进 pending（等待客户回复）
    case 'L2U_APPLY_TASK': {
      const t = action.task;
      return {
        ...state,
        link2urBoard: state.link2urBoard.filter(x => x.id !== t.id),
        link2urPending: [...state.link2urPending, {
          taskId: t.id, templateId: t.templateId, title: t.title, emoji: t.emoji,
          reward: t.reward, rating: t.rating,
          actionCost: t.actionCost, energyCost: t.energyCost,
          appliedDay: state.day,
          requirement: t.requirement || null,
          // 熟人单 narrative —— 批准后 endDay 拉出来弹 EventModal
          friendTask: t.friendTask || false,
          narrative: t.narrative || null,
        }],
        // 申请也算消化一点积压（你 took initiative）
        stress: Math.max(0, (state.stress ?? 25) - 3),
      };
    }
    // pending 通过 → 转 completed（同 ACCEPT_TASK 逻辑）
    // 客户回复 approve —— 任务停在 pending 里但 status='approved'，
    // 等玩家点"完成"才真正消耗 action + energy + 拿钱（L2U_COMPLETE_TASK）。
    case 'L2U_PENDING_APPROVED': {
      const t = action.task;
      return {
        ...state,
        link2urPending: state.link2urPending.map(p =>
          p.taskId === t.taskId ? { ...p, status: 'approved', approvedDay: state.day } : p
        ),
      };
    }
    // 玩家点"完成"按钮 —— 真正消耗 action + energy + 结算奖励
    case 'L2U_COMPLETE_TASK': {
      const t = action.task;
      const newRating = (() => {
        const count = state.link2urCompleted.length + 1;
        const w = Math.min(0.3, 1 / Math.max(1, count));
        return Math.round((state.link2urRating * (1 - w) + (t.rating || 5) * w) * 10) / 10;
      })();
      const newCompletedCount = state.link2urCompleted.length + 1;
      const milestoneFlags = { ...state.flags };
      if (newCompletedCount >= 3)  milestoneFlags.l2u_3_done = true;
      if (newCompletedCount >= 8)  milestoneFlags.l2u_8_done = true;
      if (newCompletedCount >= 10) milestoneFlags.l2u_10_done = true;
      if (newCompletedCount >= 30) milestoneFlags.l2u_30_done = true;
      if (newCompletedCount >= 50) milestoneFlags.l2u_50_done = true;
      // 熟人单 → 同步进 friendsCompleted
      const friendsCompleted = t.friendTask
        ? [...(state.link2urFriendsCompleted || []), t.templateId]
        : (state.link2urFriendsCompleted || []);
      return {
        ...state,
        link2urPending: state.link2urPending.filter(x => x.taskId !== t.taskId),
        link2urCompleted: [...state.link2urCompleted, { id: t.taskId, templateId: t.templateId, type: t.type, reward: t.reward, week: Math.ceil(state.day / 7) }],
        link2urFriendsCompleted: friendsCompleted,
        link2urRating: newRating,
        link2urEarnings: state.link2urEarnings + t.reward,
        flags: milestoneFlags,
        // 完成 1 单 −12 积压 + 消耗 action + energy
        stress: Math.max(0, (state.stress ?? 25) - 12),
        actionsLeft: Math.max(0, state.actionsLeft - (t.actionCost || 1)),
        stats: {
          ...state.stats,
          wallet: state.stats.wallet + t.reward,
          energy: clamp(state.stats.energy - (t.energyCost || 0), 0, 100),
        },
      };
    }
    // pending 被拒 → 进历史 + 增积压
    case 'L2U_PENDING_REJECTED': {
      const { task, reason } = action;
      return {
        ...state,
        link2urPending: state.link2urPending.filter(x => x.taskId !== task.taskId),
        link2urRejected: [
          { id: task.taskId, templateId: task.templateId, title: task.title,
            reason, day: state.day, reward: task.reward },
          ...state.link2urRejected,
        ].slice(0, 30),
        stress: Math.min(100, (state.stress ?? 25) + 4),
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

    case 'END_DAY': {
      // 新一天的行动点按 stress 阶梯发：压力越高，今天能做的事越少。
      //   0-74   3 actions (正常)
      //   75-84  2 actions ("我今天只能 cover 2 件事")
      //   85+    1 action  ("快崩了 只能撑一件")
      // 失败游戏由 App.jsx 在 stress >= 95 时通过 SET_ENDING 触发。
      const meals = state.mealsToday || 0;
      const mealsMissed = Math.max(0, 2 - meals);   // 0 / 1 / 2 顿没吃
      // 没吃够饭的 penalty —— 次日 stress 涨 + energy 受损 + **晚上自动点外卖扣钱**
      const mealsPenaltyStress = meals === 0 ? 8 : meals === 1 ? 4 : 0;
      const mealsPenaltyEnergy = meals === 0 ? -10 : meals === 1 ? -5 : 0;
      const DELIVERY_FEE = 15;  // 每漏一顿 £15 外卖费
      const deliveryCost = mealsMissed * DELIVERY_FEE;
      const baseStress = state.stress ?? 25;
      const s = clamp(baseStress + mealsPenaltyStress, 0, 100);
      let dailyActions = DAILY_ACTIONS;  // 3
      if (s >= 85) dailyActions = 1;
      else if (s >= 75) dailyActions = 2;
      // 能量恢复也按压力衰减：高压时睡不好
      const energyRecover = s >= 75 ? 5 : s >= 60 ? 10 : 15;
      return {
        ...state,
        day: state.day + 1,
        actionsLeft: dailyActions,
        stress: s,
        mealsToday: 0,   // 跨天重置
        stats: {
          ...state.stats,
          energy: clamp(state.stats.energy + energyRecover + mealsPenaltyEnergy, 0, 100),
          // 漏的顿数 × £15 自动 Deliveroo 扣钱（饿狠了的人最后还是会点外卖）
          wallet: state.stats.wallet - deliveryCost,
        },
        seenChatOptionsToday: [],   // 跨天重置：smalltalk 和普通 ask 重新可问
      };
    }

    case 'SET_ENDING':
      return { ...state, ending: action.ending, screen: 'ending' };

    default:
      return state;
  }
}
