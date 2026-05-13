// localStorage save/load. Game state is the single source of truth, so we
// just JSON-serialize it. Schema version lets us migrate forward instead of
// discarding incompatible saves.

const KEY = 'yixiang.save';
const SCHEMA = 5;  // bump (V5: Link2Ur 创业线 v2 字段)

// ── Migration · 加 Link2Ur 创业线字段兜底 ──
// 旧存档 (V4 及之前) 加载时通过此函数补全缺失字段, 而非整个丢弃。
function migrateLinkU(state) {
  return {
    ...state,
    link2urRepeatCustomers: state.link2urRepeatCustomers || {},
    link2urInbox: state.link2urInbox || [],
    link2urClashCount: state.link2urClashCount || 0,
    link2urClashEvents: state.link2urClashEvents || [],
    link2urPath: state.link2urPath ?? null,
    link2urPathDecidedDay: state.link2urPathDecidedDay ?? null,
    link2urPhase: state.link2urPhase || 1,
    link2urPhaseShiftDay: state.link2urPhaseShiftDay ?? null,
    link2urTeamMembers: state.link2urTeamMembers || [],
    link2urTeamRevenue: state.link2urTeamRevenue || 0,
    yjieRelationship: state.yjieRelationship || 0,
    yjieChapter: state.yjieChapter || 0,
    npcSpokenToday: state.npcSpokenToday || [],
  };
}

export function save(state) {
  if (typeof window === 'undefined') return;
  try {
    const payload = { schema: SCHEMA, savedAt: Date.now(), state };
    window.localStorage.setItem(KEY, JSON.stringify(payload));
  } catch (e) { /* quota / private mode — silently skip */ }
}

export function load() {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    // V4+ 都走 migrate 兜底, 只有更老的不兼容 schema 才丢弃
    if (parsed.schema < 4) return null;
    return migrateLinkU(parsed.state);
  } catch (e) { return null; }
}

export function clear() {
  if (typeof window === 'undefined') return;
  try { window.localStorage.removeItem(KEY); } catch (e) { /* ignore */ }
}

export function hasSave() {
  if (typeof window === 'undefined') return false;
  try { return !!window.localStorage.getItem(KEY); } catch (e) { return false; }
}
