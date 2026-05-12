// localStorage save/load. Game state is the single source of truth, so we
// just JSON-serialize it. Schema version lets us discard incompatible saves
// instead of crashing.

const KEY = 'yixiang.save';
const SCHEMA = 4;  // bump (V4: Link2Ur day-1 unlock + backlogStress)

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
    if (parsed.schema !== SCHEMA) return null;
    return parsed.state;
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
