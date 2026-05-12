import React, { useState, useEffect, useReducer, useRef, useMemo, useCallback, lazy, Suspense } from 'react';

import { audio } from './engine/audio.js';
import { clamp } from './engine/util.js';
import { reducer, initialState, derive, applyEffect } from './engine/state.js';
import * as persistence from './engine/persistence.js';
import { findStoryTrigger, matches } from './engine/conditions.js';
import { resolveEnding, SPECIAL_ENDINGS } from './data/endings.js';
import { pronounize, pronounizeEvent } from './engine/pronouns.js';
import { computeUnlocked, ACHIEVEMENT_BY_ID } from './data/achievements.js';

import {
  TOTAL_DAYS, DAILY_ACTIONS, getWeekInfo,
  WEATHERS, generateWeekWeather, WEATHER_EVENTS,
  FESTIVALS, FESTIVAL_EVENTS,
  GROUP_MEMBERS, GROUP_MESSAGES,
  STRANGERS, AT_YOU_EVENTS,
  DREAMS, INSOMNIA_THOUGHTS, NOSTALGIA_MOMENTS,
  PARENTS_STORY,
  STRANGER_EVENTS,
  LOCATIONS, TRAVEL_DESTINATIONS, TRAVEL_EVENTS,
  NPC_NETWORK_EVENTS, NPCS,
  STORYLINES,
  LOCATION_EVENTS, WELCOME_WEEK_EVENTS, DAILY_LIFE_EVENTS, POST_GRAD_EVENTS,
  CULTURE_FRICTION_EVENTS, END_GAME_EVENTS, WELLBEING_EVENTS,
  MARK_ARC_EVENTS, FLAT_HUNT_EVENTS, JOB_HUNT_DEEP_EVENTS,
  NPC_DEEPENING_EVENTS, CROSS_LINE_RIPPLE_EVENTS, DISSERTATION_EVENTS, LATE_SCAM_EVENTS,
  NPC_LIGHT_INTERACTIONS, SCAM_PULSE_EVENTS, DAILY_ACCIDENT_EVENTS, MEI_WORK_EVENTS,
  generateBoard, availablePosts,
  getEligibleCsMessages,
  HOLIDAY_CHOICES_XMAS, HOLIDAY_CHOICES_EASTER,
  HOLIDAY_SECRETS_XMAS, HOLIDAY_SECRETS_EASTER,
  EXAM_PAPERS, READING_WEEK_EVENTS,
  MONTHLY_STIPEND, isStipendWeek,
} from './data/index.js';

import { scanProactiveChats } from './data/proactiveChats.js';
import { getActiveChapter } from './data/link2urMainline.js';
import { getEligibleCrossovers } from './data/link2urCrossover.js';
import { shouldTriggerYInvitation } from './engine/link2urSchedule.js';
import { YJIE_SCENES } from './data/npcYjie.js';

// Link2Ur 申请审核：根据 task.requirement 跟玩家状态对比，返回
// { approved: bool, reason: string }。reason 是给玩家看的具体拒绝理由。
function resolvePendingApplication(task, state) {
  const req = task.requirement;
  const playerRating = state.link2urRating ?? 5;
  const playerCount = (state.link2urCompleted || []).length;

  // 没 requirement 的 task —— 客户挑剔程度看 base rating
  if (!req) {
    // 5% 客户随机拒绝（找了别人 / 时间冲突等）
    if (Math.random() < 0.05) {
      return { approved: false, reason: '客户提前 2 小时被另一位 helper 接走 · 抱歉' };
    }
    return { approved: true };
  }

  // 有 requirement —— 逐条检查
  if (req.rating && playerRating < req.rating) {
    return { approved: false,
      reason: `客户优先评分 ≥ ${req.rating} · 你目前 ${playerRating.toFixed(1)}` };
  }
  if (req.count && playerCount < req.count) {
    return { approved: false,
      reason: `客户要求 ≥ ${req.count} 单完成史 · 你目前 ${playerCount} 单` };
  }
  if (req.skill && !(state.flags?.[`skill_${req.skill}`])) {
    return { approved: false,
      reason: `客户找 ${req.skill} 专项经验 · 你 profile 还没标记` };
  }
  // 满足所有 hard requirement，但 high-tier 客户仍 30% 几率挑剔挑别人
  if ((req.rating && req.rating >= 4.7) && Math.random() < 0.25) {
    return { approved: false,
      reason: '客户列了 3 个 candidate · 这次选了 6 个月 Link2Ur 经验的另一位' };
  }
  return { approved: true };
}

import {
  IntroScreen, PlayingScreen, BirthdayPromptScreen, HolidayScreen,
  ExamScreen, DissertationTopicScreen, TravelScreen, EndingScreen,
  PlaneScreen, ArrivalScreen,
} from './components/Screens.jsx';
import {
  EventModal, StoryModal, NpcDialogModal, StrangerEncounterModal,
  AtYouModal, DreamModal, InsomniaModal, NostalgiaModal,
  ParentsChapterModal, StrangerEventModal, CrisisModal, TravelEventModal,
} from './components/Modals.jsx';
import { BagSheet } from './components/BagSheet.jsx';
// Minigames 只在玩家触发对应任务时渲染，懒加载剪掉首屏 ~22KB
const YellowLabelMinigame = lazy(() => import('./components/Minigames.jsx').then(m => ({ default: m.YellowLabelMinigame })));
const PretMinigame        = lazy(() => import('./components/Minigames.jsx').then(m => ({ default: m.PretMinigame })));
const EssayMinigame       = lazy(() => import('./components/Minigames.jsx').then(m => ({ default: m.EssayMinigame })));
const MatchMinigame       = lazy(() => import('./components/Minigames.jsx').then(m => ({ default: m.MatchMinigame })));
import { LoadingOverlay } from './components/LoadingOverlay.jsx';

export default function App() {
  // -- Persistent game state --
  const [state, dispatch] = useReducer(reducer, undefined, () => {
    const saved = persistence.load();
    return saved || initialState();
  });

  // -- Ephemeral UI-only state --
  const [muted, setMuted] = useState(false);
  const [tab, setTab] = useState('map');
  const [currentLocation, setCurrentLocation] = useState(null);

  // 每天醒来 + 进入 playing 屏第一帧：默认在公寓（flat）。
  // 跨天 → 回家睡觉，自动回 flat。玩家手动离开（点"← 返回地图"）则跳到地图视图。
  useEffect(() => {
    if (state.screen !== 'playing') return;
    const flat = LOCATIONS.find(l => l.id === 'flat');
    if (flat) setCurrentLocation(flat);
    // 注：依赖 day → 每天 reset；依赖 screen → 第一次进 playing reset
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.day, state.screen]);
  const [activeEvent, setActiveEvent] = useState(null);
  const [activeStoryChapter, setActiveStoryChapter] = useState(null);
  const [activeNpcDialog, setActiveNpcDialog] = useState(null);
  const [eventFeedback, setEventFeedback] = useState(null);
  const [showStoryNotification, setShowStoryNotification] = useState(null);

  const [showHolidayScreen, setShowHolidayScreen] = useState(null);
  const [activeExam, setActiveExam] = useState(null);
  const [showDissertationTopicScreen, setShowDissertationTopicScreen] = useState(false);
  const [showBirthdayPrompt, setShowBirthdayPrompt] = useState(false);

  const [activeTravelEvent, setActiveTravelEvent] = useState(null);
  const [activeStrangerEvent, setActiveStrangerEvent] = useState(null);
  const [activeAtYouEvent, setActiveAtYouEvent] = useState(null);
  const [activeStrangerEventModal, setActiveStrangerEventModal] = useState(null);
  const [activeParentsChapter, setActiveParentsChapter] = useState(null);
  const [activeCrisis, setActiveCrisis] = useState(null);
  const [activeDream, setActiveDream] = useState(null);
  const [activeInsomnia, setActiveInsomnia] = useState(null);
  const [activeNostalgia, setActiveNostalgia] = useState(null);

  const [loadingContext, setLoadingContext] = useState(null);
  const [activeMinigamePret, setActiveMinigamePret] = useState(false);
  const [activeMinigameEssay, setActiveMinigameEssay] = useState(false);
  const [activeMinigameMatch, setActiveMinigameMatch] = useState(false);
  // Link2Ur 完成时正在跑的 minigame —— { task, type } 形如 { task, type: 'yellow'|'pret'|'essay'|'match' }
  const [activeL2uMinigame, setActiveL2uMinigame] = useState(null);

  const [bagOpen, setBagOpen] = useState(false);

  // -- Derived (memoized to skip recompute on unrelated re-renders) --
  const week = useMemo(() => derive.week(state), [state.day]);
  const dayOfWeek = useMemo(() => derive.dayOfWeek(state), [state.day]);
  const weekInfo = useMemo(() => getWeekInfo(week), [week]);
  const attendanceRate = useMemo(() => derive.attendanceRate(state), [state.attendanceHistory]);
  const currentMonthRate = useMemo(() => derive.currentMonthRate(state), [state.monthAttendance]);
  const postsAvailable = useMemo(() => availablePosts(state),
    [state.day, state.flags, state.stats, state.link2urCompleted, state.link2urRating, state.link2urPosted, state.stress, state.dissertationProgress]);

  // -- Persist on every meaningful change (debounced 300ms — avoid serializing
  //    a 50KB+ state JSON on every keystroke / typing-delay dispatch). --
  const persistTimerRef = useRef(null);
  useEffect(() => {
    if (state.screen === 'intro') return;
    if (persistTimerRef.current) clearTimeout(persistTimerRef.current);
    persistTimerRef.current = setTimeout(() => persistence.save(state), 300);
    return () => persistTimerRef.current && clearTimeout(persistTimerRef.current);
  }, [state]);

  // -- Achievement detection — fire when flags / stats / completed change --
  const [achievementToast, setAchievementToast] = useState(null);
  // 已在本会话 toast 过的成就 id —— StrictMode 在 dev 会让 effect 双跑，
  // dispatch 还没 settle 之前 alreadyKnown 看上去仍是空，就会重复 toast。
  // ref 不参与 React 重渲染，正好做 idempotent dedupe。
  const toastedAchRef = useRef(new Set());
  useEffect(() => {
    if (state.screen === 'intro' || state.screen === 'plane' || state.screen === 'arrival') return;
    const currentlyUnlocked = computeUnlocked(state);
    const alreadyKnown = new Set(state.unlockedAchievements.map(a => a.id));
    const newlyUnlocked = currentlyUnlocked.filter(id =>
      !alreadyKnown.has(id) && !toastedAchRef.current.has(id),
    );
    if (newlyUnlocked.length > 0) {
      newlyUnlocked.forEach(id => toastedAchRef.current.add(id));
      dispatch({ type: 'UNLOCK_ACHIEVEMENTS', ids: newlyUnlocked });
      // 只 toast 第一个新解锁的（多个同时解锁的等下次 effect 重跑再 toast 下一个）
      const first = newlyUnlocked[0];
      const ach = ACHIEVEMENT_BY_ID[first];
      if (ach) {
        setAchievementToast(ach);
        audio.ding();
        setTimeout(() => setAchievementToast(null), 4000);
      }
    }
  }, [state.flags, state.stats, state.link2urCompleted, state.link2urRating]);

  // -- Link2Ur 客服「小U」: 4 条数据驱动的关键节点提醒。每条 flag 锁住只发一次，
  //    用 ref 在同一会话里再 dedupe 一道（防止 dispatch 间隔内同条目重复发）。
  const firedCsRef = useRef(new Set());
  // 已 schedule 的 chat typing setTimeout id 集合 —— 组件 unmount 时全部清掉防泄漏
  const chatTimersRef = useRef(new Set());
  useEffect(() => () => {
    chatTimersRef.current.forEach(id => clearTimeout(id));
    chatTimersRef.current.clear();
  }, []);
  useEffect(() => {
    if (state.screen !== 'playing') return;
    if (!state.flags.link2ur_discovered) return;
    const eligible = getEligibleCsMessages(state);
    eligible.forEach((msg) => {
      if (firedCsRef.current.has(msg.id)) return;
      firedCsRef.current.add(msg.id);
      // 立刻打 flag —— 即便延迟内 state 二次 settle 也不会重发
      dispatch({ type: 'SET_FLAG', flag: msg.flag });
      setTimeout(() => {
        addMessage('l2u_cs', '👤 小U · Link2Ur 助手', msg.text);
      }, msg.delayMs || 800);
    });
  }, [state.flags, state.link2urCompleted.length, state.link2urRating, state.screen]);

  // -- Audio lifecycle --
  useEffect(() => { audio.init(); audio.setMuted(muted); }, [muted]);
  useEffect(() => {
    if (muted) return;
    if (state.screen !== 'playing') {
      audio.stopAmbient();
      return () => audio.stopAmbient();
    }
    // 冬天 W9-16 雨声 override 一切（无视地点）—— 留学生最深刻的伦敦记忆
    const isWinter = week >= 9 && week <= 16;
    if (isWinter) {
      audio.startRain(0.3);
    } else if (currentLocation && currentLocation.id) {
      // 进入特定地点 → 该地点的 procedural ambient
      audio.playLocationAmbient(currentLocation.id);
    } else {
      // 在地图选择界面 → 默认 quiet
      audio.startQuiet();
    }
    return () => audio.stopAmbient();
  }, [state.screen, muted, week, currentLocation?.id]);

  // -- Helpers --
  function addMessage(from, fromName, text) {
    dispatch({
      type: 'ADD_MESSAGE',
      message: {
        id: Date.now() + Math.random(),
        from, fromName, text,
        day: state.day,
        time: new Date().toLocaleTimeString().slice(0, 5),
        read: false,
      },
    });
    audio.message();
  }

  // 玩家在私聊里选了一个回复 / 提问选项。
  // option = { id, kind, label, playerText, npcReply, effect }
  // NPC 回复延迟 800-1400ms 模拟"正在输入"的真实感。
  function pickChatOption(npcId, option) {
    audio.click();
    // 1. 立刻把玩家气泡 + effect 推上去（不传 npcReply，等 timeout 后再追加）
    if (option.effect) {
      dispatch({ type: 'APPLY_EFFECT', effect: option.effect });
    }
    // smalltalk 和 普通 ask 进 todayId（每日重置），其它一次性 option 进 optionId
    const isDailyKind = option.kind === 'smalltalk' || option.kind === 'ask';
    dispatch({
      type: 'CHAT_PLAYER_REPLY',
      npcId,
      playerText: option.playerText || option.label,
      npcReply: null,  // 延迟追加
      // 'reply' / 带 flag effect / 带 group / 带 requires 的 deep-chain ask = 一次性
      optionId: (option.kind === 'reply' || option.effect?.flag || option.requires?.length)
        ? option.id : null,
      groupId: option.group || null,  // 同组其它选项一起消失
      todayId: isDailyKind ? option.id : null,  // 每日重置 set
    });
    // 2. 模拟"正在输入..."延迟。延迟随回复长度变化：
    //    短回复 ~1.5s，长回复（>40 字符）按 30字/秒 模拟打字速度，封顶 4s。
    if (option.npcReply) {
      dispatch({ type: 'SET_FLAG', flag: `_chat_typing_${npcId}` });
      const len = option.npcReply.length;
      const baseMs = 1200 + Math.random() * 600;
      const perCharMs = Math.min(len * 35, 2200);
      const delay = Math.min(baseMs + perCharMs, 4000);
      // 给 timer id 起名字 + 加进 ref 让组件 unmount 时能 clear
      const tid = setTimeout(() => {
        dispatch({
          type: 'CHAT_APPEND_NPC_REPLY',
          npcId,
          text: option.npcReply,
        });
        dispatch({ type: 'SET_FLAG', flag: `_chat_typing_${npcId}`, value: false });
        audio.message();
        chatTimersRef.current.delete(tid);
      }, delay);
      chatTimersRef.current.add(tid);
    }
  }

  // 玩家在群聊里发了一条言。
  // option = { id, label, text, follows: [{from,text}], effect }
  // 群成员的 follows 也用错峰延迟出现，让群聊有节奏。
  // Link2Ur task type → 完成时要做的 minigame。没列出的 type = 体力活直接结算。
  const TASK_TYPE_MINIGAME = {
    shopping: 'yellow',         // 代购 / 抢限量 → 抢黄标 timing
    errand: 'yellow',           // 跑腿 → timing
    pickup_dropoff: 'yellow',   // 取件送件 → timing
    tour: 'yellow',             // 一日游导览 → timing
    translation: 'pret',        // 翻译外国话 → Pret 听力
    accompany: 'pret',          // 陪同 → 对话
    rental_housing: 'pret',     // 找房咨询中介 → 对话
    writing: 'essay',           // 代修文章 → 打字
    design: 'essay',            // 设计 → creative
    digital: 'essay',           // 数字活 → 打字
    tech: 'essay',              // 技术 → 打字
    tutoring: 'match',          // 家教 → 教学卡牌配对
  };

  // 真正结算 Link2Ur 任务（dispatch + 消息 + 熟人 narrative）。
  // 不带 minigame 的直接调；带 minigame 的从 minigame onComplete callback 里调。
  function finalizeL2uTask(task) {
    audio.click();
    dispatch({ type: 'L2U_COMPLETE_TASK', task });
    addMessage('l2u', '⚡ Link2Ur', `任务 "${task.title}" 完成 +£${task.reward}`);
    audio.success();
    if (task.friendTask && task.narrative) {
      setTimeout(() => {
        setActiveEvent({
          id: `l2u_friend_${task.templateId}`,
          title: task.narrative.title,
          body: task.narrative.body,
          choices: task.narrative.choices,
        });
        audio.ding();
      }, 400);
    }
    setActiveL2uMinigame(null);
  }

  function pickGroupOption(option) {
    audio.click();
    if (option.effect) {
      dispatch({ type: 'APPLY_EFFECT', effect: option.effect });
    }
    // 立即推 player post —— 群里所有 post 都是一次性，永远标 seen
    dispatch({
      type: 'GROUP_PLAYER_POST',
      text: option.text || option.label,
      follows: [],   // follows 延后追加
      optionId: option.id,
      groupId: option.group || null,
    });
    // 错峰追加群成员 follows（每条按字数延迟 + 随机抖动模拟真实输入节奏）
    if (option.follows && option.follows.length) {
      let cumMs = 1500 + Math.random() * 600;
      option.follows.forEach((f, i) => {
        const fLen = (f.text || '').length;
        const thisDelay = cumMs;
        cumMs += 800 + fLen * 30 + Math.random() * 600;
        const tid = setTimeout(() => {
          dispatch({ type: 'GROUP_APPEND_FOLLOW', follow: f });
          audio.message();
          chatTimersRef.current.delete(tid);
        }, thisDelay);
        chatTimersRef.current.add(tid);
      });
    }
  }

  // ── Loading transition helper ──
  // 在场景切换时显示 LoadingOverlay (~1800ms ≈ 2s)，overlay onDone 后才跑真实 action。
  // 调用方传 context (用于挑图 + 文案) 和 action (要在 overlay 闭合后执行的副作用)。
  function withLoading(context, action, duration = 1800) {
    setLoadingContext({
      ...context,
      duration,
      action,
    });
  }

  function applyChoice(effect, npcRelTarget, diaryContext) {
    dispatch({ type: 'APPLY_EFFECT', effect, npcRelTarget });
    // If the choice sets a flag, treat it as a "decision that mattered" —
    // auto-log to the diary so the player can review it later.
    if (effect?.flag && diaryContext) {
      dispatch({ type: 'LOG_DIARY', title: diaryContext.title, line: diaryContext.line });
    }
  }

  // ============================================================
  // Game start
  // ============================================================
  function startGame() {
    // unlock() 必须在 user gesture 同步栈内，否则 iOS Safari / Android Chrome
    // 之后异步触发的 ambient HTMLAudio.play() 会被 autoplay policy 拒掉。
    audio.unlock(); audio.click();
    setShowBirthdayPrompt(true);
  }

  function setBirthdayAndStart(month, gender) {
    audio.click();
    // SET_BIRTHDAY transitions to 'plane'. The next two beats (plane → arrival
    // → playing) are user-driven, dispatched from the respective screens.
    dispatch({ type: 'SET_BIRTHDAY', month, gender });
    setShowBirthdayPrompt(false);
  }

  function leavePlaneScene() {
    audio.click();
    dispatch({ type: 'SET_SCREEN', screen: 'arrival' });
  }

  function chooseTransport(opt) {
    audio.click();
    // Apply transport cost & energy hit, then enter the regular playing loop.
    dispatch({ type: 'PATCH_STATS', stats: {
      wallet: state.stats.wallet - opt.cost,
      energy: clamp(state.stats.energy + opt.energyDelta, 0, 100),
    }});
    dispatch({ type: 'SET_FLAG', flag: `arrival_${opt.id}` });
    dispatch({ type: 'SET_WEEK_WEATHER', week: 1, weather: generateWeekWeather(1) });
    dispatch({ type: 'SET_SCREEN', screen: 'playing' });
    addMessage('mom', '🇨🇳 妈妈', '到了吗？给妈报个平安');
    setTimeout(() => addMessage('sarah', 'Sarah', 'Hey! Welcome to UK 🇬🇧 see you in class!'), 500);
  }

  function restart() {
    audio.click();
    persistence.clear();
    dispatch({ type: 'RESET' });
    setCurrentLocation(null);
    setActiveEvent(null); setActiveStoryChapter(null); setActiveNpcDialog(null);
    setEventFeedback(null); setShowStoryNotification(null);
    setShowHolidayScreen(null); setActiveExam(null); setShowDissertationTopicScreen(false);
    setShowBirthdayPrompt(false);
    setActiveTravelEvent(null); setActiveStrangerEvent(null); setActiveAtYouEvent(null);
    setActiveStrangerEventModal(null); setActiveParentsChapter(null); setActiveCrisis(null);
    setActiveDream(null); setActiveInsomnia(null); setActiveNostalgia(null);
    setActiveMinigamePret(false); setActiveMinigameEssay(false); setActiveMinigameMatch(false);
    setTab('map');
  }

  // ============================================================
  // Location / event dispatch
  // ============================================================
  function evalState() {
    return {
      npcRel: state.npcRel, stats: state.stats, flags: state.flags,
      storyProgress: state.storyProgress,
      week, day: state.day,
      currentLocationId: currentLocation?.id,
      seenChapters: state.seenChapters,
    };
  }

  // 自动门槛：如果事件 title 包含某 NPC 的名字（不论是否有 · / : 分隔），
  // 玩家还没认识 → 屏蔽。用 rel >= 1 OR storyProgress >= 1 OR 室友/家人豁免。
  // 这层保护 catches 个别 event 漏写 condition 导致的"陌生人事件"穿帮。
  const NPC_TITLE_PATTERNS = [
    ['sarah',    /Sarah/],
    ['aditi',    /Aditi/],
    ['wangkai',  /王凯/],
    ['mei',      /Mei\b|梅姐/],
    ['whitmore', /Whitmore|教授(?!\w)/],
    ['linnan',   /林可儿|林楠/],
    ['priya',    /Priya/],
  ];
  function npcInTitle(title) {
    if (!title) return null;
    for (const [npc, re] of NPC_TITLE_PATTERNS) {
      if (re.test(title)) return npc;
    }
    return null;
  }
  // 同 npcInTitle 但作用在 body 上。返回 body 里点名却没认识的 NPC（如有）。
  function unmetNpcInBody(body) {
    if (!body) return null;
    for (const [npc, re] of NPC_TITLE_PATTERNS) {
      if (re.test(body) && !isAcquainted(npc)) return npc;
    }
    return null;
  }
  // Sarah / Tom / Mark 都是合租 flatmate（第 1 天就住一起），
  // Mom 是家人。这几个不需要主动建立 rel 也能在事件 / 旁白里出现。
  const FLATMATE_OR_FAMILY = new Set(['mom', 'tom', 'mark', 'sarah']);
  function isAcquainted(npcId) {
    if (!npcId) return true;
    if (FLATMATE_OR_FAMILY.has(npcId)) return true;
    const rel = state.npcRel?.[npcId] || 0;
    const sp  = state.storyProgress?.[npcId] || 0;
    return rel >= 1 || sp >= 1;
  }

  function checkStoryTriggers(locId) {
    const evState = { ...evalState(), currentLocationId: locId };
    return findStoryTrigger(STORYLINES, evState);
  }

  function checkNetworkEvent(locId) {
    const seen = state.seenLocationEvents._network || [];
    const evState = { ...evalState(), currentLocationId: locId };
    for (const ev of NPC_NETWORK_EVENTS) {
      if (seen.includes(ev.id)) continue;
      if (ev.location !== locId) continue;
      if (!matches(ev, evState)) continue;
      if (ev.auto || Math.random() < 0.5) return ev;
    }
    return null;
  }

  function checkWeatherEvent(locId) {
    const currentWeather = state.weekWeather[week];
    if (!currentWeather) return null;
    for (const ev of WEATHER_EVENTS) {
      if (ev.weather !== currentWeather) continue;
      if (week < (ev.minWeek || 1)) continue;
      if (!ev.repeatable && state.seenWeatherEvents.includes(ev.id)) continue;
      if (ev.weather === 'rain' && !['flat', 'uni'].includes(locId)) continue;
      if (ev.weather === 'fog' && locId === 'flat') continue;
      if (ev.weather === 'snow' && locId === 'flat') continue;
      if (ev.weather === 'sunny' && !['park', 'soho', 'tate'].includes(locId)) continue;
      if (Math.random() < 0.4) return ev;
    }
    return null;
  }

  // 出行方式费率 —— 跟 Views.jsx#TRANSIT_COSTS 保持一致
  const TRANSIT = {
    bus:  { fare: 2.5, action: 1, energy: 3 },
    taxi: { fare: 12,  action: 0, energy: 1 },
  };

  function goToLocation(loc, mode = 'bus') {
    const t = TRANSIT[mode] || TRANSIT.bus;
    // 行动检查 / 钱包检查
    if (state.actionsLeft < t.action) return;
    if (state.stats.wallet < t.fare) return;
    audio.click();
    const weatherKey = state.weekWeather[week] || 'cloudy';
    withLoading({ type: 'location', locationId: loc.id, weather: weatherKey, label: loc.name }, () => {
      _doGoToLocation(loc, weatherKey, t);
    });
  }

  function _doGoToLocation(loc, weatherKey, transit) {
    // 出行 fare + (可选) action + weather modulated energy
    if (transit.action > 0) {
      for (let i = 0; i < transit.action; i++) dispatch({ type: 'SPEND_ACTION' });
    }
    setCurrentLocation(loc);
    const w = WEATHERS[weatherKey];
    // 公交需要走/挤地铁所以受天气影响；taxi 坐车里基本免疫
    const weatherMod = transit.action > 0 ? (w.energyMod || 0) : 0;
    const energyCost = transit.energy - weatherMod;
    dispatch({ type: 'PATCH_STATS', stats: {
      wallet: state.stats.wallet - transit.fare,
      energy: clamp(state.stats.energy - energyCost, 0, 100),
    }});

    const story = checkStoryTriggers(loc.id);
    if (story) {
      setTimeout(() => { setActiveStoryChapter(story); audio.ding(); }, 400);
      return;
    }

    const network = checkNetworkEvent(loc.id);
    if (network) {
      setTimeout(() => {
        setActiveEvent(network);
        audio.ding();
        dispatch({ type: 'MARK_NETWORK_EVENT_SEEN', eventId: network.id });
      }, 400);
      return;
    }

    const weatherEv = checkWeatherEvent(loc.id);
    if (weatherEv) {
      setTimeout(() => {
        setActiveEvent(weatherEv);
        audio.ding();
        dispatch({ type: 'MARK_WEATHER_EVENT_SEEN', id: weatherEv.id });
      }, 400);
      return;
    }

    const stranger = STRANGERS.find(s => s.metAt === loc.id && !state.addedStrangers.includes(s.id));
    if (stranger && week >= 3 && Math.random() < 0.35) {
      setTimeout(() => { setActiveStrangerEvent(stranger); audio.message(); }, 400);
      return;
    }

    // 进入地点不再自动抽 location-event-pool —— 只保留 storyline / network /
    // weather / stranger 这种"大事件"自动 fire。Pool 池现在由 activity 动作触发。
    // Auto events (event.auto: true) 仍按 minWeek 自动 fire 一次。
    const autoEv = collectLocationEventPool(loc.id).find(e => {
      if (!e.auto) return false;
      if (week < (e.minWeek || 1)) return false;
      if (e.maxWeek && week > e.maxWeek) return false;
      if (!e.repeatable && (state.seenLocationEvents[loc.id] || []).includes(e.id)) return false;
      const ctxLocal = {
        npcRel: state.npcRel, stats: state.stats, flags: state.flags,
        storyProgress: state.storyProgress, week, day: state.day,
        currentLocationId: loc.id,
      };
      if (e.condition && !matches(e, ctxLocal)) return false;
      const titleNpc = npcInTitle(e.title);
      if (titleNpc && !isAcquainted(titleNpc)) return false;
      if (unmetNpcInBody(e.body)) return false;
      return true;
    });
    if (autoEv) {
      setTimeout(() => {
        setActiveEvent(filterEventChoices(autoEv, loc.id));
        audio.ding();
        if (!autoEv.repeatable) {
          dispatch({ type: 'MARK_LOCATION_EVENT_SEEN', locId: loc.id, eventId: autoEv.id });
        }
      }, 300);
    }
  }

  // 合并所有 event source 给某地点的池子
  function collectLocationEventPool(locId) {
    return [
      ...(LOCATION_EVENTS[locId] || []),
      ...(WELCOME_WEEK_EVENTS[locId] || []),
      ...(DAILY_LIFE_EVENTS[locId] || []),
      ...(POST_GRAD_EVENTS[locId] || []),
      ...(CULTURE_FRICTION_EVENTS[locId] || []),
      ...(END_GAME_EVENTS[locId] || []),
      ...(WELLBEING_EVENTS[locId] || []),
      ...(MARK_ARC_EVENTS[locId] || []),
      ...(FLAT_HUNT_EVENTS[locId] || []),
      ...(JOB_HUNT_DEEP_EVENTS[locId] || []),
      ...(NPC_DEEPENING_EVENTS[locId] || []),
      ...(CROSS_LINE_RIPPLE_EVENTS[locId] || []),
      ...(DISSERTATION_EVENTS[locId] || []),
      ...(LATE_SCAM_EVENTS[locId] || []),
      ...(NPC_LIGHT_INTERACTIONS[locId] || []),
      ...(SCAM_PULSE_EVENTS[locId] || []),
      ...(DAILY_ACCIDENT_EVENTS[locId] || []),
      ...(MEI_WORK_EVENTS[locId] || []),
    ];
  }
  // 把 event 里 condition false 的 choices 过滤掉
  function filterEventChoices(ev, locId) {
    if (!ev?.choices?.some(c => typeof c.condition === 'function')) return ev;
    const ctxLocal = {
      npcRel: state.npcRel, stats: state.stats, flags: state.flags,
      storyProgress: state.storyProgress, week, day: state.day,
      currentLocationId: locId,
    };
    return { ...ev, choices: ev.choices.filter(c =>
      typeof c.condition !== 'function' || c.condition(ctxLocal),
    )};
  }
  // 玩家点 activity 按钮时调用：先尝试抽一个该地点池里的事件，没抽到才直接返回（已经
  // 应用 effect 了）。chance 是 activity 设的触发概率。
  function tryFireLocationEvent(locId, chance) {
    if (Math.random() >= chance) return false;
    const pool = collectLocationEventPool(locId);
    const ctxLocal = {
      npcRel: state.npcRel, stats: state.stats, flags: state.flags,
      storyProgress: state.storyProgress, week, day: state.day,
      currentLocationId: locId,
    };
    const eligible = pool.filter(ev => {
      if (ev.auto) return false;  // auto 不走这条路
      if (week < (ev.minWeek || 1)) return false;
      if (ev.maxWeek && week > ev.maxWeek) return false;
      if (!ev.repeatable && (state.seenLocationEvents[locId] || []).includes(ev.id)) return false;
      if (ev.condition && !matches(ev, ctxLocal)) return false;
      const titleNpc = npcInTitle(ev.title);
      if (titleNpc && !isAcquainted(titleNpc)) return false;
      if (unmetNpcInBody(ev.body)) return false;
      return true;
    });
    if (eligible.length === 0) return false;
    const ev = eligible[Math.floor(Math.random() * eligible.length)];
    setTimeout(() => {
      setActiveEvent(filterEventChoices(ev, locId));
      audio.ding();
      if (!ev.repeatable) {
        dispatch({ type: 'MARK_LOCATION_EVENT_SEEN', locId, eventId: ev.id });
      }
    }, 300);
    return true;
  }

  // 通用 activity dispatcher —— 每个 activity button 走这里。
  // act = { effect, eventChance } —— effect 是 stats 增量，
  // eventChance 是 0-1 触发 location event 的概率。
  // ⚠ 不 auto-return —— 玩家做完事还在这地方。
  function doActivity(locId, act) {
    if (state.actionsLeft <= 0) return;
    // 防御：钱不够也别让 wallet 直接撞负 → 触发破产 ending
    const fee = -(act.effect?.wallet || 0);
    if (fee > 0 && state.stats.wallet < fee) return;
    audio.click();
    dispatch({ type: 'SPEND_ACTION' });
    if (act.effect) {
      dispatch({ type: 'APPLY_EFFECT', effect: act.effect });
    }
    if (act.meal) {
      dispatch({ type: 'INCREMENT_MEAL' });
    }
    withLoading(
      { type: 'activity', locationId: locId },
      () => {
        if (act.eventChance > 0) {
          tryFireLocationEvent(locId, act.eventChance);
        }
      },
    );
  }


  // Stranger encounter resolution
  function addStranger(stranger) {
    audio.click();
    dispatch({ type: 'ADD_STRANGER', id: stranger.id, week });
    dispatch({
      type: 'APPEND_GROUP_MESSAGES',
      messages: [{
        from: stranger.id,
        text: stranger.welcomeMsg,
        id: `stranger-${stranger.id}-${Date.now()}`,
        week,
        time: new Date().toLocaleTimeString().slice(0, 5),
      }],
    });
    dispatch({ type: 'PATCH_STATS', stats: {
      energy: clamp(state.stats.energy - 2, 0, 100),
      belonging: clamp(state.stats.belonging + 4, 0, 100),
    }});
    setActiveStrangerEvent(null);
  }

  function rejectStranger() {
    audio.click();
    dispatch({ type: 'PATCH_STATS', stats: {
      energy: clamp(state.stats.energy - 1, 0, 100),
      belonging: clamp(state.stats.belonging - 1, 0, 100),
    }});
    setActiveStrangerEvent(null);
  }

  // ============================================================
  // Choice handlers (story / event / npc / parents / etc)
  // ============================================================
  function chooseStoryOption(choice) {
    audio.click();
    const npcId = activeStoryChapter ? STORYLINES[activeStoryChapter.lineId].npc : null;
    const diary = activeStoryChapter ? {
      title: activeStoryChapter.chapter.title_full || activeStoryChapter.chapter.title,
      line: choice.label,
    } : null;
    applyChoice(choice.effect, npcId, diary);
    setEventFeedback(choice.feedback);
    if (activeStoryChapter) {
      dispatch({ type: 'STORY_ADVANCE', lineId: activeStoryChapter.lineId, chapterId: activeStoryChapter.chapter.id });
      setShowStoryNotification(pronounize(STORYLINES[activeStoryChapter.lineId].name, state.gender));
      setTimeout(() => setShowStoryNotification(null), 3000);

      // 章节完成 + 选项有正向 rel + 之前 chatThread 为空 → 自动注入"加好友"消息
      // 让 NPC 出现在消息列表里（之前会出现"刚和 wangkai 聊完但消息里没他"的怪事）
      const isFirstChapter = (state.storyProgress?.[activeStoryChapter.lineId] || 0) === 0;
      const gainedRel = (choice.effect?.rel || 0) > 0;
      const threadEmpty = !state.chatThreads?.[npcId]?.length;
      if (npcId && isFirstChapter && gainedRel && threadEmpty && CHAT_INTRO_MESSAGES[npcId]) {
        setTimeout(() => {
          dispatch({
            type: 'CHAT_APPEND_NPC_REPLY',
            npcId,
            text: CHAT_INTRO_MESSAGES[npcId],
          });
          audio.message();
        }, 2500);
      }
    }
  }

  // NPC 第一章完成后 ta 主动加你微信发的第一句话 —— 保证消息列表里能看到 ta
  const CHAT_INTRO_MESSAGES = {
    sarah:    "yo we should grab a pint soon. The Crown round the corner from us 🍻",
    aditi:    "Hey it's Aditi — saved your number. Library 4F again soon? ☕",
    wangkai:  "哥们 加上了 你有什么 PhD 学长能帮上忙的 ping 我",
    mei:      "傻孩子 加上了。下次来店里 姐给你留菜。",
    whitmore: "Saved your contact. Office hours Wednesday 4-5pm — door's open.",
    linnan:   "笔记发给你了 word 文档 你看看",
  };

  function chooseEventOption(choice) {
    audio.click();
    const diary = activeEvent ? { title: activeEvent.title, line: choice.label } : null;
    applyChoice(choice.effect, null, diary);
    setEventFeedback(choice.feedback);
    // Special: when Link2Ur is first discovered, populate the initial board
    // so the player can use the new tab right away.
    if (choice.effect?.flag === 'link2ur_discovered') {
      dispatch({ type: 'L2U_REFRESH_BOARD', tasks: generateBoard(week, { state }), week });
    }
  }

  function dismissEvent() {
    audio.click();
    setActiveEvent(null);
    setActiveStoryChapter(null);
    setEventFeedback(null);
    // 不强制跳回地图 —— 玩家关掉事件后留在原地点。
    // 想离开地点用 LocationView 里的"← 离开"按钮，行为更可预测。
  }

  // Daily actions
  // 通用 helper：所有 in-location action 走 ~1.8s loading
  // ⚠ 不再 auto-return to map —— 玩家做完事还在这地方，要走才点"← 返回地图"
  function runLocationAction(locId, effect, after) {
    if (state.actionsLeft <= 0) return;
    audio.click();
    dispatch({ type: 'SPEND_ACTION' });
    if (effect) dispatch({ type: 'APPLY_EFFECT', effect });
    withLoading(
      { type: 'activity', locationId: locId },
      () => {
        if (after) after();
      },
    );
  }

  function attendClass() {
    runLocationAction('uni',
      { academic: 6, energy: -8 },
      () => dispatch({ type: 'CLASSES_ATTENDED_INC' }),
    );
  }

  function workShift() {
    // workShift 可以在 mei 或 pub 触发；用当前 currentLocation 选 loading 图
    const locId = currentLocation?.id || 'mei';
    runLocationAction(locId,
      { academic: -2, wallet: 50, energy: -12, belonging: 1 },
    );
  }

  function restAtFlat() {
    runLocationAction('flat',
      { energy: 25, belonging: -1 },
    );
  }

  // ── 3 个固定学习入口（W2 以后任何时候都能用）──
  // 学业增长只来自这些 + attendClass + writeDissertation + 考试 + dissertation 季的迷你游戏。
  function studyAtFlat() {
    runLocationAction('flat',
      { academic: 3, energy: -8 },
    );
  }
  function studyAtLibrary() {
    runLocationAction('library',
      { academic: 6, energy: -10, belonging: 1 },
    );
  }
  function studyAtUni() {
    runLocationAction('uni',
      { academic: 4, energy: -8 },
    );
  }

  function callHome() {
    runLocationAction('flat',
      { energy: -3, belonging: 10 },
      () => {
        addMessage('mom', '🇨🇳 妈妈', '挂了电话妈妈又转了 500 块给你 😊');
        if (week >= 6 && state.parentsChapter === 0 && !state.flags.parents_declined && Math.random() < 0.4) {
          const ch1 = PARENTS_STORY.find(p => p.id === 'parents_1_offer');
          setTimeout(() => { setActiveParentsChapter(ch1); audio.ding(); }, 800);
        }
      },
    );
  }

  function chooseParentsChapter(choice) {
    audio.click();
    const diary = activeParentsChapter ? {
      title: `父母 · ${activeParentsChapter.title}`,
      line: choice.label,
    } : null;
    applyChoice(choice.effect, null, diary);
    setEventFeedback(choice.feedback);
  }
  function dismissParentsChapter() {
    audio.click();
    if (activeParentsChapter) dispatch({ type: 'PARENTS_ADVANCE', chapter: activeParentsChapter.chapter });
    setActiveParentsChapter(null);
    setEventFeedback(null);
  }

  function talkToNPC(npc) { audio.click(); setActiveNpcDialog(npc); }
  function chooseNpcTopic(topic) {
    audio.click();
    applyChoice(topic.effect, activeNpcDialog?.id);
    setEventFeedback(topic.feedback);
  }
  function dismissNpcDialog() {
    audio.click();
    setActiveNpcDialog(null);
    setEventFeedback(null);
    // 不跳回地图 —— 跟 NPC 说完话还在这个地方
  }

  // Birthday triggered when calendar month matches player's birthday month
  function triggerBirthday() {
    const totalRel = (state.npcRel.sarah || 0) + (state.npcRel.aditi || 0)
                   + (state.npcRel.wangkai || 0) + (state.npcRel.mei || 0);
    if (totalRel >= 12) {
      setActiveEvent({
        id: 'birthday_friends', tag: 'birthday',
        title: '🎂 你的生日',
        body: '你完全没跟人提过你生日。但下午 6 点，门铃响了。\n\n你打开门——Sarah、Aditi、王凯（如果关系够都来了）站在门口，捧着一个 Sainsbury\'s 蛋糕，齐声唱"Happy Birthday"。\n\nMei 姐还偷偷塞给 Sarah 一袋自己做的红烧肉。',
        choices: [
          { label: '哭出来', effect: { energy: 5, belonging: 25, npc: { sarah: 2, aditi: 2, wangkai: 2, mei: 2 } },
            feedback: '你哭着说"你们怎么知道的"。原来 Aditi 偷看过你的护照照片。Sarah 笑你眼泪鼻涕一起来。\n\n那一晚你们 4 个人在公寓里挤在沙发上看电影，吃外卖披萨。\n\n你想：第一年在异乡过生日，原来可以是这样的。' },
        ],
      });
      audio.ding();
    } else {
      setActiveEvent({
        id: 'birthday_alone', tag: 'birthday',
        title: '🎂 你的生日',
        body: '今天你生日。微信群里收到了 23 条祝福。室友不知道。',
        choices: [
          { label: '自己给自己买个蛋糕', effect: { wallet: -12, energy: 3, belonging: 2 },
            feedback: 'Sainsbury\'s 的小蛋糕，£8。你吹了蜡烛。许愿的时候想了想，没什么想许的。' },
          { label: '什么也不做', effect: { energy: -8, belonging: -8 },
            feedback: '你正常上了课，吃了泡面，睡了。直到第二天看到爸爸发的"生日快乐"，你才反应过来昨天发生了什么。' },
        ],
      });
      audio.ding();
    }
  }

  // Holiday choice
  function chooseHoliday(choice) {
    audio.click();
    const diary = { title: showHolidayScreen === 'xmas' ? '圣诞假期' : '复活节假期', line: choice.label };
    applyChoice(choice.effect, null, diary);
    setEventFeedback(choice.feedback);
  }
  function dismissHoliday() {
    audio.click();
    if (showHolidayScreen === 'xmas') dispatch({ type: 'SET_HOLIDAY_CHOICE', value: 'xmas_done' });
    if (showHolidayScreen === 'easter') dispatch({ type: 'SET_HOLIDAY_CHOICE', value: 'easter_done' });
    setShowHolidayScreen(null);
    setEventFeedback(null);
  }

  function finishExam(score) {
    audio.click();
    if (score >= 70) audio.success(); else if (score >= 40) audio.click(); else audio.fail();
    dispatch({ type: 'RECORD_EXAM_SCORE', id: activeExam.id, score });
    dispatch({ type: 'PATCH_STATS', stats: {
      academic: clamp(state.stats.academic + (score >= 70 ? 8 : score >= 50 ? 3 : -5), 0, 100),
      energy: clamp(state.stats.energy - 15, 0, 100),
      belonging: clamp(state.stats.belonging + (score >= 70 ? 4 : 0), 0, 100),
    }});
    setActiveExam(null);
  }

  function chooseDissertationTopic(topic) {
    audio.click();
    dispatch({ type: 'SET_DISSERTATION_TOPIC', topic });
    applyChoice(topic.effect, null);
    setEventFeedback(topic.feedback);
  }
  function dismissDissertationTopic() {
    audio.click();
    setShowDissertationTopicScreen(false);
    setEventFeedback(null);
  }

  function writeDissertation() {
    if (state.actionsLeft <= 0) return;
    const topic = state.dissertationTopic;
    const progress = topic?.id === 'ambitious' ? 4 : topic?.id === 'personal' ? 5 : 6;
    const locId = currentLocation?.id || 'library';
    runLocationAction(locId,
      { energy: -12, academic: 2 },
      () => dispatch({ type: 'BUMP_DISSERTATION', amount: progress }),
    );
  }

  // Stranger / @ you / dream / insomnia / nostalgia
  function chooseStrangerEventOption(choice) {
    audio.click();
    const diary = activeStrangerEventModal ? { title: activeStrangerEventModal.title, line: choice.label } : null;
    applyChoice(choice.effect, null, diary);
    setEventFeedback(choice.feedback);
  }
  function dismissStrangerEvent() { audio.click(); setActiveStrangerEventModal(null); setEventFeedback(null); }

  function replyAtYou(choice) {
    audio.click();
    const diary = activeAtYouEvent ? { title: activeAtYouEvent.title, line: choice.label } : null;
    applyChoice(choice.effect, null, diary);
    if (activeAtYouEvent) {
      const member = GROUP_MEMBERS.find(g => g.id === activeAtYouEvent.askerId)
                  || STRANGERS.find(s => s.id === activeAtYouEvent.askerId);
      if (member) {
        dispatch({
          type: 'APPEND_GROUP_MESSAGES',
          messages: [{
            from: activeAtYouEvent.askerId,
            text: activeAtYouEvent.askerMsg,
            id: `at-${activeAtYouEvent.id}-q`,
            week,
            time: new Date().toLocaleTimeString().slice(0, 5),
          }],
        });
      }
    }
    setEventFeedback(choice.feedback);
  }
  function dismissAtYou() { audio.click(); setActiveAtYouEvent(null); setEventFeedback(null); }

  function dismissDream() { audio.click(); setActiveDream(null); }
  function dismissInsomnia() {
    audio.click();
    dispatch({ type: 'PATCH_STATS', stats: {
      energy: clamp(state.stats.energy + 5, 0, 100),
      belonging: clamp(state.stats.belonging - 3, 0, 100),
    }});
    setActiveInsomnia(null);
  }

  function triggerNostalgia(triggerKey) {
    const moments = NOSTALGIA_MOMENTS.filter(m => m.trigger === triggerKey && !state.seenNostalgia.includes(m.id));
    if (moments.length > 0) {
      const m = moments[Math.floor(Math.random() * moments.length)];
      setActiveNostalgia(m);
      dispatch({ type: 'MARK_NOSTALGIA_SEEN', id: m.id });
      audio.message();
    }
  }

  function dismissNostalgia() {
    audio.click();
    const newBelonging = clamp(state.stats.belonging - 8, 0, 100);
    dispatch({ type: 'PATCH_STATS', stats: { belonging: newBelonging } });
    dispatch({ type: 'SET_FLAG', flag: 'recent_nostalgia' });
    setActiveNostalgia(null);

    const newCount = state.nostalgiaCount + 1;
    dispatch({ type: 'BUMP_NOSTALGIA_COUNT' });

    if (newCount >= 3 && newBelonging < 30 && !state.crisisTriggered) {
      setTimeout(() => {
        setActiveCrisis({
          id: 'crisis_quit',
          title: '一个让你坐起来的念头',
          body: '凌晨 4:38。\n\n你睁眼看着天花板。\n\n你在伦敦已经待了 ' + week + ' 周。\n\n你想：\n\n如果我现在订机票回去呢？\n如果我不要这个学位呢？\n如果我承认这个事情我做不到呢？\n\n你想了 5 分钟。\n你想了 20 分钟。\n你拿起手机。',
        });
        dispatch({ type: 'TRIGGER_CRISIS' });
        audio.warning();
      }, 1000);
    }
  }

  function chooseCrisis(choice) {
    audio.click();
    if (choice.id === 'quit') {
      setActiveCrisis(null);
      let text = '你订了 7 天后的机票。回程。\n\n你坐在床边 看着那张确认信。心跳得很慢。你以为做这个决定会很痛。但你只是觉得 安静。';
      text += '\n\n— ⋅ —\n\n你给爸妈打了视频电话。\n\n妈妈以为你要告诉她什么坏消息。但你只是说："我想回家了。我读不下去了。"\n\n她沉默了 3 秒。然后说："那就回来。"\n\n爸爸在背景里："对 回来。我们家不缺这个学位。"\n\n你哭了。你说"对不起"。\n\n妈妈说："对不起什么。家是用来回的。"';
      const messages = [];
      if ((state.npcRel.sarah || 0) >= 4) messages.push('Sarah："Where are you?? You weren\'t in tutorial. Coffee tomorrow?"');
      if ((state.npcRel.aditi || 0) >= 4) messages.push('Aditi："I noticed you haven\'t been around. Are you ok?"');
      if ((state.npcRel.wangkai || 0) >= 4) messages.push('王凯："哥们/姐们 你最近怎么不来店里 出什么事了"');
      if ((state.npcRel.whitmore || 0) >= 4) messages.push('Whitmore："I missed you in supervision yesterday. Hope all is well."');
      if ((state.npcRel.mei || 0) >= 4) messages.push('Mei 姐："傻孩子 这两天没来吃饭啊"');
      if (messages.length > 0) {
        text += '\n\n— ⋅ —\n\n你登机前打开手机。\n\n' + messages.join('\n') + '\n\n你看着这些消息看了很久。\n\n原来不是没人在意。\n\n你回了大家一句话："I\'m going home for a while. Take care."\n\n你不知道是为什么 但你没说"再也不回来了"。';
      } else {
        text += '\n\n— ⋅ —\n\n7 天里你删了几个 app 登录。退了图书馆账号。把房子转租出去。\n\n这一年你结识了一些人 但没有真正进入任何一个圈子。所以走得也没人发觉。';
      }
      if ((state.npcRel.mei || 0) >= 6) {
        text += '\n\n— ⋅ —\n\nHeathrow T3。你已经过了安检 在登机口。\n\n手机响了。Mei 姐："傻孩子 你看你身后。"\n\n你回头。\n\n她真的从 Croydon 坐了 1.5 小时地铁过来。她比你印象中老了一点 头发上有点白霜。她手里捧着一个保温杯。\n\n"刚煮的。让你飞机上喝。"\n\n你眼眶一下红了。你说"姐..."\n\n她打断你："叫姨。"\n\n你叫了。"姨。"\n\n她推你："快去 别误了飞机。" 但她自己也在哭。\n\n你们在 Heathrow T3 的 candy 店门口抱了 30 秒。\n\n你登机。保温杯打开是红枣枸杞汤。还热的。\n\n飞机起飞的时候你想：我在这个城市 至少有一个真正的家人。';
      }
      const monthNames = ['9月', '10月', '11月', '12月', '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月'];
      const monthIdx = Math.min(11, Math.floor((week - 1) / 4));
      const currentMonth = monthNames[monthIdx] || '某月';
      text += '\n\n— ⋅ —\n\n飞机起飞了。\n\n你看着舷窗外的伦敦慢慢变小。从你 9 月份来的那座你害怕的城市 变成你 ' + currentMonth + '份离开的这一座 你已经爱过又放下的城市。\n\n这不是失败。这只是你做了一个艰难但诚实的决定——比硬撑着读完一个让自己破碎的学位 要诚实。\n\n人生还很长。家是用来回的。';
      dispatch({ type: 'SET_ENDING', ending: { title: '中途回去', subtitle: 'Going Home, Mid-Way', text } });
    } else if (choice.id === 'persist') {
      dispatch({ type: 'PATCH_STATS', stats: {
        energy: clamp(state.stats.energy + 5, 0, 100),
        belonging: clamp(state.stats.belonging + 8, 0, 100),
      }});
      dispatch({ type: 'RESET_NOSTALGIA_COUNT' });
      dispatch({ type: 'SET_FLAG', flag: 'crisis_survived' });
      setEventFeedback('你放下手机。\n\n你想：再坚持一周看看。\n\n你不知道这一周会发生什么。但你知道现在订机票，是 4:38 凌晨的决定，不是清醒的决定。\n\n你睡了。\n\n第二天醒来的时候，你没那么想走了。');
    } else if (choice.id === 'call_mom') {
      dispatch({ type: 'PATCH_STATS', stats: {
        energy: clamp(state.stats.energy - 5, 0, 100),
        belonging: clamp(state.stats.belonging + 20, 0, 100),
      }});
      dispatch({ type: 'RESET_NOSTALGIA_COUNT' });
      dispatch({ type: 'SET_FLAG', flag: 'crisis_survived' });
      setEventFeedback('你按了视频键。\n\n中国是中午 12:38。妈妈在做饭。\n\n你说："妈 我...我有点想家。"\n\n她没有惊慌。她只是看着你说："那就视频陪我做饭吧。" 然后她把手机架在台子上。\n\n你看着她炒菜 30 分钟。一个字没说。\n\n你听到锅铲碰到锅的声音。听到她跟你爸说"加点盐"。听到楼下有车开过。\n\n半小时后她说："吃饭了 你也去睡吧。"\n\n你说"嗯"。然后挂了。\n\n你睡了一个 8 个月以来最沉的觉。');
    }
  }
  function dismissCrisis() { audio.click(); setActiveCrisis(null); setEventFeedback(null); }

  function triggerNightState(newDay) {
    const r = Math.random();
    if (state.stats.belonging < 35 && week >= 4 && r < 0.08) {
      const available = DREAMS.filter(d => !state.seenDreams.includes(d.id));
      if (available.length > 0) {
        const dream = available[Math.floor(Math.random() * available.length)];
        setTimeout(() => { setActiveDream(dream); audio.message(); }, 600);
        dispatch({ type: 'MARK_DREAM_SEEN', id: dream.id });
        return;
      }
    }
    if (state.stats.energy < 25 && state.stats.academic > 55 && r < 0.12) {
      const available = INSOMNIA_THOUGHTS.filter(i => !state.seenInsomnia.includes(i.id));
      if (available.length > 0) {
        const ins = available[Math.floor(Math.random() * available.length)];
        setTimeout(() => { setActiveInsomnia(ins); audio.warning(); }, 600);
        dispatch({ type: 'MARK_INSOMNIA_SEEN', id: ins.id });
      }
    }
  }

  // ============================================================
  // Link2Ur 创业线 tick — called at end of every day advance.
  // Runs after END_DAY dispatch so newDay/newWeek reflect tomorrow.
  // ============================================================
  function link2urMainlineTick(newDay, newWeek) {
    // 1. 章节 events: flag_set + phase_pivot (其余类型 Task 7 wire)
    const activeChapter = getActiveChapter(newDay);
    if (activeChapter) {
      for (const event of (activeChapter.events || [])) {
        if (event.week !== newWeek) continue;
        if (state.seenChapters.includes(event.id)) continue;

        // Mark as seen first (idempotent guard)
        dispatch({ type: 'MARK_CHAPTER_EVENT_SEEN', eventId: event.id });

        if (event.type === 'flag_set') {
          if (event.flagOnSet) {
            dispatch({ type: 'SET_FLAG', flag: event.flagOnSet, value: true });
          }
          if (event.statePatch?.link2urPhase === 2) {
            dispatch({ type: 'L2U_PHASE_PIVOT' });
          }
        }
        // npc_scene / inbox_task / customer_unlock / clash_trigger / mini_arc / choice
        // → deferred to Task 7 integration tests; recognised here but not yet wired
      }
    }

    // 2. Crossovers: mark flag占位 (narrative wiring deferred to Task 7)
    const crossovers = getEligibleCrossovers({ ...state, day: newDay });
    for (const c of crossovers) {
      const flagKey = `crossover_seen_${c.id}`;
      if (!state.flags?.[flagKey]) {
        dispatch({ type: 'SET_FLAG', flag: flagKey, value: true });
      }
    }

    // 3. Y 姐邀请 — 检测条件，满足则设 flag 并弹 Sketch 场景
    const stateForYCheck = { ...state, day: newDay };
    if (shouldTriggerYInvitation(stateForYCheck)) {
      dispatch({ type: 'SET_FLAG', flag: 'l2u_y_invited', value: true });
      const sketchScene = YJIE_SCENES.find(s => s.id === 'yjie_sketch_invitation');
      if (sketchScene) {
        // 延迟 2s 错峰，不和跨周 banner 撞
        setTimeout(() => {
          setActiveEvent({
            id: sketchScene.id,
            title: sketchScene.title,
            body: sketchScene.body,
            choices: (sketchScene.choices || []).map(c => ({
              ...c,
              effect: c.effect || {},
            })),
          });
          audio.ding();
        }, 2000);
      }
    }
  }

  // ============================================================
  // End of day — heaviest handler
  // ============================================================
  function endDay() {
    audio.click();
    const newDay = state.day + 1;
    const newWeek = Math.ceil(newDay / 7);
    // Loading transition：周一刷新用 week_start，否则用 day_end。
    if (newWeek !== week) {
      withLoading({ type: 'week_start', week: newWeek }, () => _doEndDay(), 2200);
      return;
    }
    withLoading({ type: 'day_end' }, () => _doEndDay(), 1800);
  }

  function _doEndDay() {
    const newDay = state.day + 1;
    const newWeek = Math.ceil(newDay / 7);
    const oldWeekInfo = getWeekInfo(week);
    const newWeekInfo = getWeekInfo(newWeek);

    // 漏顿外卖：今日 mealsToday < 2 → 自动 Deliveroo 扣钱（END_DAY reducer 会扣 wallet）
    // 这里发个 message 让玩家知道扣了多少
    const mealsToday = state.mealsToday || 0;
    if (mealsToday < 2) {
      const missed = 2 - mealsToday;
      const fee = missed * 15;
      const msg = missed === 2
        ? `🛵 你今天一顿没吃。深夜饿到不行点了两份 Deliveroo —— 扣 £${fee}。压力 +8，明天精力 -10。`
        : `🛵 你今天只吃了一顿。睡前饿了点 Deliveroo —— 扣 £${fee}。压力 +4，明天精力 -5。`;
      addMessage('system', '🛵 Deliveroo', msg);
    }

    let attendanceHistory = state.attendanceHistory;
    let monthAttendance = state.monthAttendance;
    let walletAfter = state.stats.wallet;

    // Sunday — settle the week.
    if (dayOfWeek === 7) {
      if (oldWeekInfo.requireClass) {
        const entry = { week, attended: state.classesAttendedThisWeek, required: 6 };
        attendanceHistory = [...attendanceHistory, entry];
        dispatch({ type: 'PUSH_ATTENDANCE', entry });

        const reqWeeks = attendanceHistory.filter(a => a.required > 0);
        if (reqWeeks.length > 0 && reqWeeks.length % 4 === 0) {
          const last4 = reqWeeks.slice(-4);
          const att = last4.reduce((s, a) => s + a.attended, 0);
          const req = last4.reduce((s, a) => s + a.required, 0);
          const rate = Math.round((att / req) * 100);
          const monthNum = monthAttendance.length + 1;
          const ma = { month: monthNum, attended: att, required: req, rate };
          monthAttendance = [...monthAttendance, ma];
          dispatch({ type: 'PUSH_MONTH_ATTENDANCE', entry: ma });

          if (rate < 60) {
            addMessage('uni', 'International Office', `⚠️ Month ${monthNum} attendance: ${rate}%. Below 60% requires immediate meeting. Risk of visa curtailment.`);
            audio.warning();
          } else if (rate < 70) {
            addMessage('uni', 'International Office', `📋 Month ${monthNum} attendance: ${rate}%. We are monitoring this closely.`);
          } else if (rate < 80) {
            addMessage('uni', 'Personal Tutor', `Hi, just checking in—your attendance this month was ${rate}%. Anything we can help with?`);
          }
        }
      }
      dispatch({ type: 'CLASSES_ATTENDED_RESET' });

      const allClassWeeks = attendanceHistory.filter(a => a.required > 0);
      const totalAtt = allClassWeeks.reduce((s, a) => s + a.attended, 0);
      const totalReq = allClassWeeks.reduce((s, a) => s + (a.required || 6), 0);
      const newRate = totalReq > 0 ? Math.round((totalAtt / totalReq) * 100) : 100;

      // Rent is prepaid annually (handled in onboarding narrative), so no
      // weekly deduction. walletAfter stays at the current wallet for the
      // downstream broke-ending check.
      walletAfter = state.stats.wallet;

      if (newRate < 50 && week >= 4 && allClassWeeks.length >= 4) {
        dispatch({ type: 'SET_ENDING', ending: SPECIAL_ENDINGS.visa_curtailed(newRate) });
        audio.warning();
        return;
      }
    }

    // Bump day & restore actions/energy.
    dispatch({ type: 'END_DAY' });

    // ── 压力指数 (stress) 处理 · 阶梯惩罚 + 失败触发 ──
    // 每日自然增长：基础 +3 / 天 + 阶段叠加（freshman 期低、dissertation 期最高）
    //   W1-W6  迎新/秋初:  +3   (玩家摸索期，温和)
    //   W7-W30 学期/春期:  +5   (学业开始堆积)
    //   W31-W36 复习+考试: +7   (考试压力 + 学校 ddl)
    //   W37-W52 论文期:    +8   (dissertation grind)
    // + 特殊状态额外 +2: scam 后 / parents 来访 / 4:38AM crisis
    const phaseInc =
      week <= 6 ? 3 :
      week <= 30 ? 5 :
      week <= 36 ? 7 : 8;
    const stateBonus = (
      (state.flags?.scammed_pig_full || state.flags?.scammed_trading_full) ? 2 : 0
    ) + (state.flags?.parents_arriving_soon ? 2 : 0);
    dispatch({ type: 'L2U_BACKLOG_TICK', amount: phaseInc + stateBonus });
    const currentStress = state.stress ?? 25;
    if (currentStress >= 95) {
      // ★ 失败 ending · burnout breakdown
      dispatch({ type: 'SET_ENDING', ending: SPECIAL_ENDINGS.stress_breakdown() });
      audio.fail();
      return;
    } else if (currentStress >= 85) {
      // 极高：actionsLeft 已经在 END_DAY 里降到 1，再叠加 -5 belonging -5 energy
      dispatch({ type: 'APPLY_EFFECT', effect: { belonging: -5, energy: -5, academic: -2 } });
      setTimeout(() => addMessage('l2u_cs', '👤 小U · Link2Ur 助手',
        '⚠️ 系统提示：你压力指数 85+。今天只剩 1 个行动点。求救不丢人——发个 post 把事 offload 出去。'), 800);
    } else if (currentStress >= 75) {
      // 高：actionsLeft 降到 2，叠加表现下降
      dispatch({ type: 'APPLY_EFFECT', effect: { belonging: -3, energy: -3, academic: -1 } });
      setTimeout(() => addMessage('l2u_cs', '👤 小U · Link2Ur 助手',
        '压力指数 75。今天行动点 -1（剩 2 个）。建议发 1-2 个 post 让别人帮你 cover。'), 800);
    } else if (currentStress >= 60) {
      // 中高：表现略下滑但 actionsLeft 不变
      dispatch({ type: 'APPLY_EFFECT', effect: { energy: -2, academic: -1 } });
      if (Math.random() < 0.4) {
        setTimeout(() => addMessage('l2u_cs', '👤 小U · Link2Ur 助手',
          '注意压力指数 60+。表现开始受影响。试试在 Link2Ur 发个 post 让自己喘口气。'), 1000);
      }
    } else if (currentStress <= 30) {
      // 低：表现略 boost
      dispatch({ type: 'APPLY_EFFECT', effect: { belonging: 1 } });
    }
    // ── 处理 Link2Ur pending applications · 12-36h 后 resolve ──
    (state.link2urPending || []).forEach((p, i) => {
      const daysWaited = (newDay - p.appliedDay);
      // 0.5-1.5 天后处理（newDay - appliedDay >= 1 即触发）
      if (daysWaited < 1) return;
      const result = resolvePendingApplication(p, state);
      const delay = 800 + i * 600 + Math.random() * 800;
      setTimeout(() => {
        if (result.approved) {
          addMessage('l2u', '⚡ Link2Ur',
            `✅ 客户已确认你的申请："${p.title}"。去申请 tab 点"完成"开工，+£${p.reward}`);
          dispatch({ type: 'L2U_PENDING_APPROVED', task: p });
        } else {
          addMessage('l2u', '⚡ Link2Ur',
            `❌ 申请未通过："${p.title}"。原因：${result.reason}`);
          dispatch({ type: 'L2U_PENDING_REJECTED', task: p, reason: result.reason });
        }
      }, delay);
    });

    // 扫描 NPC 主动联系 hooks —— 满足条件的延迟 1.5-3s 错峰推进 thread。
    const proactiveState = { ...state, day: newDay };
    const triggered = scanProactiveChats(proactiveState);
    triggered.forEach((hook, i) => {
      const delay = 1500 + i * 800 + Math.random() * 700;
      setTimeout(() => {
        addMessage(hook.npcId, hook.fromName, hook.text);
        dispatch({ type: 'MARK_PROACTIVE_HOOK_SEEN', id: hook.id });
        if (hook.flag) dispatch({ type: 'SET_FLAG', flag: hook.flag });
      }, delay);
    });

    if (newDay > TOTAL_DAYS) {
      generateEnding();
      return;
    }
    if (walletAfter < 0) {
      dispatch({ type: 'SET_ENDING', ending: SPECIAL_ENDINGS.broke() });
      return;
    }

    // === Special week transitions ===
    // Reading week 进入第一天 → auto-fire 提示事件（睡到自然醒 +12 精力）
    if (newWeekInfo?.type === 'reading' && week !== newWeek) {
      const rwEv = READING_WEEK_EVENTS.find(e => e.isAuto);
      if (rwEv) {
        if (rwEv.effect) dispatch({ type: 'APPLY_EFFECT', effect: rwEv.effect });
        setActiveEvent({ ...rwEv, id: `${rwEv.id}_w${newWeek}` });
      }
    }
    if (newWeek === 13 && week === 12 && state.holidayChoice !== 'xmas_done') {
      setCurrentLocation(null);
      withLoading({ type: 'holiday', holidayType: 'xmas' }, () => setShowHolidayScreen('xmas'), 2200);
      return;
    }
    if (newWeek === 27 && week === 26 && state.holidayChoice !== 'easter_done') {
      setCurrentLocation(null);
      withLoading({ type: 'holiday', holidayType: 'easter' }, () => setShowHolidayScreen('easter'), 2200);
      return;
    }
    if (newWeekInfo.isExam && newWeek !== week) {
      const exam = EXAM_PAPERS[newWeekInfo.examNumber - 1];
      if (exam && !state.examResults[exam.id]) {
        setActiveExam(exam);
        setCurrentLocation(null);
        return;
      }
    }
    if (newWeek === 37 && week === 36 && !state.dissertationTopic) {
      setShowDissertationTopicScreen(true);
      setCurrentLocation(null);
      return;
    }
    if (newWeekInfo.type === 'reading' && newWeekInfo.week !== oldWeekInfo.week) {
      addMessage('uni', 'Faculty Office', '📅 Reminder: This week is Reading Week. No classes scheduled. Catch up on readings or take a break.');
    }

    // === New week triggers ===
    if (newWeek !== week) {
      if (!state.weekWeather[newWeek]) {
        dispatch({ type: 'SET_WEEK_WEATHER', week: newWeek, weather: generateWeekWeather(newWeek) });
      }

      // Link2Ur board refresh — only after platform discovered
      if (state.flags.link2ur_discovered) {
        dispatch({ type: 'L2U_REFRESH_BOARD', tasks: generateBoard(newWeek, { state }), week: newWeek });
      }

      // Monthly stipend — fires on entering a new "month" (every 4 weeks).
      if (isStipendWeek(newWeek)) {
        dispatch({ type: 'PATCH_STATS', stats: { wallet: walletAfter + MONTHLY_STIPEND } });
        addMessage('mom', '🇨🇳 妈妈', `这个月生活费转给你了 £${MONTHLY_STIPEND}。少吃外卖。`);
        audio.ding();
      }

      // Festival
      const festival = FESTIVALS[newWeek];
      if (festival && !state.seenFestivals.includes(festival.id)) {
        const fEvent = FESTIVAL_EVENTS[festival.id];
        if (fEvent) {
          // 选项级 condition：让节日按玩家社交进度（npcRel/flags）显示不同选项。
          // 无 condition 的选项始终显示，保持向后兼容。
          const choiceCtx = {
            npcRel: state.npcRel || {},
            flags: state.flags || {},
            stats: state.stats || {},
            week: newWeek,
            gender: state.gender,
          };
          const visibleChoices = (fEvent.choices || []).filter(c =>
            typeof c.condition !== 'function' || c.condition(choiceCtx)
          );
          setTimeout(() => {
            setActiveEvent({
              id: festival.id, tag: 'festival',
              title: fEvent.title, body: fEvent.body, choices: visibleChoices,
              isFestival: true,
            });
            audio.ding();
          }, 600);
          dispatch({ type: 'MARK_FESTIVAL_SEEN', id: festival.id });
          if (festival.id === 'spring_festival') {
            setTimeout(() => triggerNostalgia('spring_festival'), 3500);
          }
        }
      }

      // Random nostalgia
      if (!festival && state.stats.belonging < 30 && state.stats.energy < 40 && Math.random() < 0.06) {
        const randomMoments = NOSTALGIA_MOMENTS.filter(m => m.trigger === 'random' && !state.seenNostalgia.includes(m.id));
        if (randomMoments.length > 0) {
          const m = randomMoments[Math.floor(Math.random() * randomMoments.length)];
          setTimeout(() => { setActiveNostalgia(m); audio.message(); }, 1500);
          dispatch({ type: 'MARK_NOSTALGIA_SEEN', id: m.id });
        }
      }

      // Birthday
      if (state.birthdayMonth && !state.birthdayCelebrated) {
        const calendarMonth = ((Math.floor((newWeek - 1) / 4) + 8) % 12) + 1;
        if (calendarMonth === state.birthdayMonth) {
          setTimeout(() => triggerBirthday(), 800);
          dispatch({ type: 'BIRTHDAY_DONE' });
        }
      }

      // Group messages
      const groupMsg = GROUP_MESSAGES.find(m => m.week === newWeek && !state.seenGroupWeeks.includes(m.week));
      if (groupMsg) {
        dispatch({
          type: 'APPEND_GROUP_MESSAGES',
          messages: groupMsg.messages.map((msg, i) => ({
            ...msg, id: `${newWeek}-${i}`, week: newWeek, time: new Date().toLocaleTimeString().slice(0, 5),
          })),
          markWeek: newWeek,
        });
        audio.message();
      }

      // @ you events
      const evState = evalState();
      const atEvent = AT_YOU_EVENTS.find(e =>
        e.week === newWeek && !state.seenAtYouEvents.includes(e.id) && (!e.condition || matches(e, { ...evState, week: newWeek }))
      );
      if (atEvent) {
        setTimeout(() => { setActiveAtYouEvent(atEvent); audio.message(); }, 1200);
        dispatch({ type: 'MARK_AT_YOU_SEEN', id: atEvent.id });
      }

      // Stranger events
      const strangerEv = STRANGER_EVENTS.find(e => {
        if (state.seenStrangerEvents.includes(e.id)) return false;
        if (!state.addedStrangers.includes(e.strangerId)) return false;
        const addedWeek = state.strangerAddedAt[e.strangerId];
        if (!addedWeek) return false;
        if (newWeek - addedWeek < e.weeksAfter) return false;
        if (e.requireFlag && !state.flags[e.requireFlag]) return false;
        return true;
      });
      if (strangerEv) {
        setTimeout(() => { setActiveStrangerEventModal(strangerEv); audio.ding(); }, 1800);
        dispatch({ type: 'MARK_STRANGER_EVENT_SEEN', id: strangerEv.id });
      }

      // Parents storyline ch 2-5
      const parentsEv = PARENTS_STORY.find(p => {
        if (p.chapter <= state.parentsChapter) return false;
        if (p.triggerType === 'after_call_home') return false;
        if (newWeek < p.triggerWeek) return false;
        if (p.requireFlag && !state.flags[p.requireFlag]) return false;
        return true;
      });
      if (parentsEv) {
        setTimeout(() => { setActiveParentsChapter(parentsEv); audio.ding(); }, 2400);
      }
    }

    // ── Link2Ur 创业线 tick ──
    link2urMainlineTick(newDay, newWeek);

    triggerNightState(newDay);
    setCurrentLocation(null);
  }

  // ============================================================
  // Endings
  // ============================================================
  function generateEnding() {
    const ending = resolveEnding({
      flags: state.flags, stats: state.stats,
      storyProgress: state.storyProgress, npcRel: state.npcRel,
      link2urRating: state.link2urRating,
      link2urCompletedCount: (state.link2urCompleted || []).length,
    });
    dispatch({ type: 'SET_ENDING', ending });
  }

  // ============================================================
  // Travel
  // ============================================================
  function startTravel(dest) {
    audio.click();
    if (state.stats.wallet < dest.cost) return;
    dispatch({ type: 'PATCH_STATS', stats: { wallet: state.stats.wallet - dest.cost } });
    dispatch({ type: 'START_TRAVEL', destination: dest });
    setCurrentLocation(null);
  }
  function chooseTravelEvent(ev) { audio.click(); setActiveTravelEvent(ev); }
  function completeTravelEvent(choice) {
    audio.click();
    applyChoice(choice.effect, null);
    if (activeTravelEvent?.postcard && state.travelMode) {
      dispatch({
        type: 'ADD_POSTCARD',
        postcard: {
          id: activeTravelEvent.id,
          city: state.travelMode.destination.id,
          text: activeTravelEvent.postcard,
          day: state.day,
        },
      });
    }
    if (state.travelMode) {
      dispatch({ type: 'MARK_TRAVEL_EVENT_SEEN', city: state.travelMode.destination.id, eventId: activeTravelEvent.id });
    }
    setEventFeedback(choice.feedback);
  }
  function dismissTravelEvent() {
    audio.click();
    setActiveTravelEvent(null);
    setEventFeedback(null);
    const newDayUsed = state.travelDayUsed + 1;
    if (state.travelMode && newDayUsed >= state.travelMode.destination.days) {
      finishTravel();
    } else {
      dispatch({ type: 'TRAVEL_DAY_TICK' });
    }
  }
  function skipTravelDay() {
    audio.click();
    const newDayUsed = state.travelDayUsed + 1;
    if (state.travelMode && newDayUsed >= state.travelMode.destination.days) {
      finishTravel();
    } else {
      dispatch({ type: 'TRAVEL_DAY_TICK' });
    }
  }
  function finishTravel() {
    audio.click();
    dispatch({ type: 'FINISH_TRAVEL' });
    setActiveTravelEvent(null);
    setEventFeedback(null);
  }

  // ============================================================
  // Render
  // ============================================================
  return (
    <Suspense fallback={null}>
    <div className="min-h-screen w-full" style={{
      background: 'linear-gradient(180deg, #2a2520 0%, #1a1612 100%)',
      fontFamily: '"EB Garamond", "Songti SC", "Source Han Serif", serif',
      color: '#e8e0d0',
    }}>
      <div className="fixed inset-0 pointer-events-none opacity-15" style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.4'/%3E%3C/svg%3E")`,
        zIndex: 1,
      }} />
      {loadingContext && (
        <LoadingOverlay
          context={loadingContext}
          duration={loadingContext.duration || 1800}
          onDone={() => {
            const action = loadingContext.action;
            setLoadingContext(null);
            if (action) action();
          }}
        />
      )}

      {state.screen === 'intro' && (
        <button onClick={() => setMuted(!muted)}
          className="fixed top-3 right-3 z-30 w-9 h-9 border border-current/40 bg-[#1a1612]/80 hover:border-current/80 flex items-center justify-center text-sm">
          {muted ? '🔇' : '🔊'}
        </button>
      )}
      <BagSheet
        open={bagOpen}
        onClose={() => setBagOpen(false)}
        stats={state.stats}
        mealsToday={state.mealsToday ?? 0}
        weekInfo={weekInfo}
        attendanceRate={attendanceRate}
        classesAttendedThisWeek={state.classesAttendedThisWeek}
        dissertationProgress={state.dissertationProgress}
        dissertationTopic={state.dissertationTopic}
        muted={muted}
        onToggleMute={() => setMuted(!muted)}
        onRestart={restart}
      />

      {showStoryNotification && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50 px-6 py-3 border border-amber-300/60 bg-[#1a1612]/95 animate-fadein-slow">
          <div className="text-xs tracking-[0.3em] opacity-60" style={{ fontFamily: 'monospace' }}>STORY ADVANCED</div>
          <div className="text-sm mt-1">{showStoryNotification}</div>
        </div>
      )}
      {achievementToast && (
        // 外层定位居中（用 flex 而不是 translate，避免和动画 transform 冲突）
        <div className="fixed top-16 left-0 right-0 z-50 flex justify-center pointer-events-none">
          <div className="px-5 py-3 border bg-[#1a1612]/95 animate-fadein-slow flex items-center gap-3 pointer-events-auto"
            style={{ borderColor: '#FFD700' }}>
            <div className="text-3xl">{achievementToast.icon}</div>
            <div>
              <div className="text-xs tracking-[0.3em] opacity-60" style={{ fontFamily: 'monospace', color: '#FFD700' }}>
                🎖 ACHIEVEMENT UNLOCKED
              </div>
              <div className="text-sm mt-0.5">{pronounize(achievementToast.title, state.gender)}</div>
            </div>
          </div>
        </div>
      )}

      <div className="relative max-w-3xl mx-auto px-3 py-6" style={{ zIndex: 2 }}>
        {state.screen === 'intro' && <IntroScreen onStart={startGame} />}
        {state.screen === 'plane' && <PlaneScreen onContinue={leavePlaneScene} />}
        {state.screen === 'arrival' && (
          <ArrivalScreen wallet={state.stats.wallet} onChoose={chooseTransport} />
        )}
        {state.screen === 'playing' && (
          <PlayingScreen
            day={state.day} week={week} dayOfWeek={dayOfWeek}
            stats={state.stats} actionsLeft={state.actionsLeft}
            weekInfo={weekInfo}
            tab={tab} setTab={setTab}
            currentLocation={currentLocation}
            setCurrentLocation={(l) => { audio.click(); setCurrentLocation(l); }}
            onGoToLocation={goToLocation}
            onAttendClass={attendClass} onWorkShift={workShift} onRestAtFlat={restAtFlat} onCallHome={callHome}
            onStudyAtFlat={studyAtFlat} onStudyAtLibrary={studyAtLibrary} onStudyAtUni={studyAtUni}
            onActivity={doActivity}
            onTalkNPC={talkToNPC}
            onWriteDissertation={writeDissertation}
            dissertationProgress={state.dissertationProgress}
            dissertationTopic={state.dissertationTopic}
            onEndDay={endDay}
            messages={state.messages} unreadMessages={state.unreadMessages}
            onReadMessages={() => dispatch({ type: 'READ_MESSAGES' })}
            npcRel={state.npcRel}
            attendanceRate={attendanceRate}
            currentMonthRate={currentMonthRate}
            classesAttendedThisWeek={state.classesAttendedThisWeek}
            storyProgress={state.storyProgress}
            travelMode={state.travelMode}
            onStartTravel={startTravel}
            monthAttendance={state.monthAttendance}
            examResults={state.examResults}
            weather={state.weekWeather[week]}
            groupChat={state.groupChat}
            unreadGroup={state.unreadGroup}
            onReadGroup={() => dispatch({ type: 'READ_GROUP' })}
            addedStrangers={state.addedStrangers}
            seenDreams={state.seenDreams}
            seenInsomnia={state.seenInsomnia}
            seenNostalgia={state.seenNostalgia}
            diaryChoices={state.diaryChoices}
            unlockedAchievements={state.unlockedAchievements}
            gender={state.gender}
            gameState={state}
            parentsChapter={state.parentsChapter}
            flags={state.flags}
            chatThreads={state.chatThreads}
            chatThreadUnread={state.chatThreadUnread}
            seenChatOptions={state.seenChatOptions}
            seenChatOptionsToday={state.seenChatOptionsToday}
            onPickChatOption={pickChatOption}
            onMarkThreadRead={(npcId) => dispatch({ type: 'CHAT_THREAD_READ', npcId })}
            onPickGroupOption={pickGroupOption}
            onTriggerPret={() => withLoading({ type: 'pret' }, () => setActiveMinigamePret(true))}
            onTriggerEssay={() => withLoading({ type: 'essay' }, () => setActiveMinigameEssay(true))}
            onTriggerMatch={() => setActiveMinigameMatch(true)}
            onOpenBag={() => setBagOpen(true)}
            link2urProps={{
              board: state.link2urBoard,
              completed: state.link2urCompleted,
              posted: state.link2urPosted,
              rating: state.link2urRating,
              earnings: state.link2urEarnings,
              walletNow: state.stats.wallet,
              actionsLeft: state.actionsLeft,
              postsAvailable,
              flags: state.flags,
              gameState: state,
              week,
              onApply: (task) => {
                audio.click();
                dispatch({ type: 'L2U_APPLY_TASK', task });
                addMessage('l2u', '⚡ Link2Ur',
                  `📋 申请已提交："${task.title}"。客户通常 12-36h 内回复。`);
              },
              // 客户已 approve，玩家点"完成"才真正消耗 action+energy + 拿钱
              // 不同 type 任务需要做不同 minigame 才能完成；没 minigame 的直接结算
              onComplete: (task) => {
                if (state.actionsLeft <= 0) return;
                const mg = TASK_TYPE_MINIGAME[task.type];
                if (!mg) {
                  // 体力活类（cleaning/cooking/moving/pet/photography）→ 直接结算
                  finalizeL2uTask(task);
                  return;
                }
                // 有 minigame → 暂存任务弹 minigame
                audio.click();
                setActiveL2uMinigame({ task, type: mg });
              },
              onPost: (post) => {
                audio.click();
                dispatch({ type: 'L2U_POST_TASK', post });
                addMessage('l2u', '⚡ Link2Ur', `发单 "${post.title}" 已匹配，扣 £${post.cost}`);
                if (post.feedback) {
                  setEventFeedback(post.feedback);
                  setActiveEvent({
                    id: `l2u_post_${post.id}`,
                    title: `Link2Ur · ${post.title}`,
                    body: '',
                    choices: [],
                  });
                }
              },
              // ── Inbox task callbacks (Task 5.3 Phase 5 wiring) ──
              onInboxAccept: (taskId) => {
                audio.click();
                dispatch({ type: 'L2U_INBOX_ACCEPTED', taskId });
                const task = state.link2urInbox.find(t => t.id === taskId);
                if (task) {
                  addMessage('l2u', '⚡ Link2Ur',
                    `✅ 已接受指定任务："${task.title}"。+£${task.reward || 0}`);
                }
              },
              onInboxDecline: (taskId) => {
                audio.click();
                dispatch({ type: 'L2U_INBOX_DECLINED', taskId });
                const task = state.link2urInbox.find(t => t.id === taskId);
                if (task) {
                  addMessage('l2u', '⚡ Link2Ur',
                    `❌ 已婉拒指定任务："${task.title}"。`);
                }
              },
              onInboxAssign: (taskId, memberId) => {
                audio.click();
                // 转派：接单拿钱（团员分成），复用 L2U_INBOX_ACCEPTED
                dispatch({ type: 'L2U_INBOX_ACCEPTED', taskId });
                const task = state.link2urInbox.find(t => t.id === taskId);
                if (task) {
                  addMessage('l2u', '⚡ Link2Ur',
                    `📤 指定任务"${task.title}"已转派给团员。收入分成后到账。`);
                }
              },
            }}
          />
        )}

        {activeEvent && !activeEvent.minigame && (
          <EventModal event={pronounizeEvent(activeEvent, state.gender)} feedback={pronounize(eventFeedback, state.gender)}
            onChoose={chooseEventOption} onDismiss={dismissEvent} />
        )}
        {activeEvent && activeEvent.minigame === 'yellow_grab' && (
          <YellowLabelMinigame onComplete={(result) => {
            audio.click();
            if (result.success) audio.success(); else audio.fail();
            dispatch({ type: 'PATCH_STATS', stats: {
              wallet: state.stats.wallet - result.cost,
              energy: clamp(state.stats.energy + result.energy, 0, 100),
              belonging: clamp(state.stats.belonging + result.belonging, 0, 100),
            }});
            // 抢到任意一件 = 成就解锁（result.success === true）
            if (result.success) {
              dispatch({ type: 'SET_FLAG', flag: 'yellow_label_grabbed' });
            }
            setEventFeedback(result.feedback);
          }} feedback={pronounize(eventFeedback, state.gender)} onDismiss={dismissEvent} />
        )}
        {activeStoryChapter && (
          <StoryModal chapter={pronounizeEvent(activeStoryChapter.chapter, state.gender)} lineName={pronounize(STORYLINES[activeStoryChapter.lineId].name, state.gender)}
            feedback={pronounize(eventFeedback, state.gender)} onChoose={chooseStoryOption} onDismiss={dismissEvent} />
        )}
        {activeNpcDialog && (
          <NpcDialogModal npc={activeNpcDialog} rel={state.npcRel[activeNpcDialog.id] || 0}
            feedback={pronounize(eventFeedback, state.gender)} onChoose={chooseNpcTopic} onDismiss={dismissNpcDialog}
            gender={state.gender} />
        )}
        {showHolidayScreen && (
          <HolidayScreen type={showHolidayScreen}
            choices={(showHolidayScreen === 'xmas' ? HOLIDAY_CHOICES_XMAS : HOLIDAY_CHOICES_EASTER).map(c => ({
              ...c,
              label: pronounize(c.label, state.gender),
              feedback: pronounize(c.feedback, state.gender),
            }))}
            secrets={(showHolidayScreen === 'xmas' ? HOLIDAY_SECRETS_XMAS : HOLIDAY_SECRETS_EASTER).map(s => ({
              ...s,
              feedback: pronounize(s.feedback, state.gender),
            }))}
            stats={state.stats} npcRel={state.npcRel} storyProgress={state.storyProgress} flags={state.flags}
            feedback={pronounize(eventFeedback, state.gender)} onChoose={chooseHoliday} onDismiss={dismissHoliday}
            gender={state.gender} />
        )}
        {activeExam && (
          <ExamScreen exam={activeExam} academic={state.stats.academic} onFinish={finishExam} />
        )}
        {showBirthdayPrompt && <BirthdayPromptScreen onSelect={setBirthdayAndStart} />}
        {activeStrangerEvent && (
          <StrangerEncounterModal stranger={pronounizeEvent(activeStrangerEvent, state.gender)}
            onAdd={addStranger} onReject={rejectStranger} />
        )}
        {activeAtYouEvent && (
          <AtYouModal event={pronounizeEvent(activeAtYouEvent, state.gender)}
            members={GROUP_MEMBERS} strangers={STRANGERS}
            feedback={pronounize(eventFeedback, state.gender)}
            onChoose={replyAtYou} onDismiss={dismissAtYou} />
        )}
        {activeDream && <DreamModal dream={pronounizeEvent(activeDream, state.gender)} onDismiss={dismissDream} />}
        {activeInsomnia && <InsomniaModal thought={pronounizeEvent(activeInsomnia, state.gender)} onDismiss={dismissInsomnia} />}
        {activeNostalgia && <NostalgiaModal moment={pronounizeEvent(activeNostalgia, state.gender)} onDismiss={dismissNostalgia} />}
        {activeStrangerEventModal && (
          <StrangerEventModal event={pronounizeEvent(activeStrangerEventModal, state.gender)} strangers={STRANGERS}
            feedback={pronounize(eventFeedback, state.gender)}
            onChoose={chooseStrangerEventOption}
            onDismiss={dismissStrangerEvent} />
        )}
        {activeParentsChapter && (
          <ParentsChapterModal chapter={pronounizeEvent(activeParentsChapter, state.gender)}
            feedback={pronounize(eventFeedback, state.gender)}
            onChoose={chooseParentsChapter}
            onDismiss={dismissParentsChapter} />
        )}
        {activeCrisis && (
          <CrisisModal crisis={pronounizeEvent(activeCrisis, state.gender)} feedback={pronounize(eventFeedback, state.gender)}
            onChoose={chooseCrisis} onDismiss={dismissCrisis} />
        )}
        {activeMinigamePret && (
          <PretMinigame
            onComplete={(result) => {
              audio.click();
              dispatch({ type: 'PATCH_STATS', stats: {
                wallet: state.stats.wallet + (result.effect.wallet || 0),
                energy: clamp(state.stats.energy + (result.effect.energy || 0), 0, 100),
                belonging: clamp(state.stats.belonging + (result.effect.belonging || 0), 0, 100),
              }});
              // 完成 Pret minigame = 第一次 Pret 成就解锁
              dispatch({ type: 'SET_FLAG', flag: 'first_pret' });
              setActiveMinigamePret(false);
              setActiveEvent({
                id: 'pret_result', title: '走出 Pret',
                body: result.feedback,
                choices: [{ label: '回去', effect: {}, feedback: '...' }],
              });
            }}
            onCancel={() => { audio.click(); setActiveMinigamePret(false); }}
          />
        )}
        {activeMinigameEssay && (
          <EssayMinigame
            onComplete={(result) => {
              audio.click();
              dispatch({ type: 'PATCH_STATS', stats: {
                academic: clamp(state.stats.academic + (result.effect.academic || 0), 0, 100),
                energy: clamp(state.stats.energy + (result.effect.energy || 0), 0, 100),
                belonging: clamp(state.stats.belonging + (result.effect.belonging || 0), 0, 100),
              }});
              dispatch({ type: 'BUMP_DISSERTATION', amount: result.score * 8 });
              setActiveMinigameEssay(false);
              setActiveEvent({
                id: 'essay_result', title: '📝 写完一段',
                body: result.feedback,
                choices: [{ label: '继续', effect: {}, feedback: '...' }],
              });
            }}
            onCancel={() => { audio.click(); setActiveMinigameEssay(false); }}
          />
        )}
        {activeMinigameMatch && (
          <MatchMinigame
            onComplete={(result) => {
              audio.click();
              dispatch({ type: 'PATCH_STATS', stats: {
                academic: clamp(state.stats.academic + (result.effect.academic || 0), 0, 100),
                energy: clamp(state.stats.energy + (result.effect.energy || 0), 0, 100),
                belonging: clamp(state.stats.belonging + (result.effect.belonging || 0), 0, 100),
              }});
              setActiveMinigameMatch(false);
              setActiveEvent({
                id: 'match_result', title: '🎴 复习卡牌',
                body: result.feedback,
                choices: [{ label: '收起卡牌', effect: {}, feedback: '...' }],
              });
            }}
            onCancel={() => { audio.click(); setActiveMinigameMatch(false); }}
          />
        )}

        {/* ── Link2Ur 任务完成时的 minigame ──
            走完 minigame 自动 finalizeL2uTask；中途 cancel 任务回到 approved 状态等再点 */}
        {activeL2uMinigame?.type === 'yellow' && (
          <YellowLabelMinigame
            onComplete={(result) => {
              audio.click();
              if (result.success) audio.success(); else audio.fail();
              // minigame 成功 → 任务正常结算；失败 → 客户给差评但仍然结算（一次性 5% rating 下调）
              finalizeL2uTask(activeL2uMinigame.task);
              if (!result.success) {
                addMessage('l2u', '⚡ Link2Ur',
                  '⚠ 客户反馈不太满意 · 评分有微调');
              }
            }}
            feedback={null}
            onDismiss={() => { audio.click(); setActiveL2uMinigame(null); }}
          />
        )}
        {activeL2uMinigame?.type === 'pret' && (
          <PretMinigame
            onComplete={(result) => {
              audio.click();
              finalizeL2uTask(activeL2uMinigame.task);
            }}
            onCancel={() => { audio.click(); setActiveL2uMinigame(null); }}
          />
        )}
        {activeL2uMinigame?.type === 'essay' && (
          <EssayMinigame
            onComplete={(result) => {
              audio.click();
              finalizeL2uTask(activeL2uMinigame.task);
            }}
            onCancel={() => { audio.click(); setActiveL2uMinigame(null); }}
          />
        )}
        {activeL2uMinigame?.type === 'match' && (
          <MatchMinigame
            onComplete={(result) => {
              audio.click();
              finalizeL2uTask(activeL2uMinigame.task);
            }}
            onCancel={() => { audio.click(); setActiveL2uMinigame(null); }}
          />
        )}

        {showDissertationTopicScreen && (
          <DissertationTopicScreen
            feedback={eventFeedback}
            onChoose={chooseDissertationTopic}
            onDismiss={dismissDissertationTopic} />
        )}
        {state.screen === 'travel' && state.travelMode && (
          <TravelScreen
            destination={state.travelMode.destination}
            daysLeft={state.travelMode.destination.days - state.travelDayUsed}
            totalDays={state.travelMode.destination.days}
            events={(TRAVEL_EVENTS[state.travelMode.destination.id] || []).filter(
              e => !(state.travelEventsSeen[state.travelMode.destination.id] || []).includes(e.id)
            )}
            allEvents={TRAVEL_EVENTS[state.travelMode.destination.id] || []}
            seenEvents={state.travelEventsSeen[state.travelMode.destination.id] || []}
            stats={state.stats}
            onChooseEvent={chooseTravelEvent}
            onSkipDay={skipTravelDay}
            onFinish={finishTravel}
          />
        )}
        {activeTravelEvent && (
          <TravelEventModal event={pronounizeEvent(activeTravelEvent, state.gender)}
            feedback={pronounize(eventFeedback, state.gender)}
            onChoose={completeTravelEvent}
            onDismiss={dismissTravelEvent} />
        )}
        {state.screen === 'ending' && state.ending && (
          <EndingScreen ending={{
              ...state.ending,
              text: pronounize(state.ending.text, state.gender),
              title: pronounize(state.ending.title, state.gender),
            }} stats={state.stats} npcRel={state.npcRel}
            attendanceRate={attendanceRate} storyProgress={state.storyProgress}
            examResults={state.examResults} dissertationProgress={state.dissertationProgress}
            postcards={state.postcards}
            flags={state.flags} addedStrangers={state.addedStrangers}
            gender={state.gender}
            onRestart={restart} />
        )}
      </div>
    </div>
    </Suspense>
  );
}
