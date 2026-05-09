// Gender-aware pronoun substitution.
//
// The game's narrative was written with slash placeholders for gendered terms:
//   "他 / 她"  ·  "学弟 / 学妹"  ·  "男生 / 女生"  ·  etc.
// (Order in source is consistently MALE / FEMALE.)
//
// Once the player picks a gender at game start, we collapse those slashes:
//   gender === 'male'    → keep first option, drop the rest
//   gender === 'female'  → keep second option
//
// If gender is null (e.g. player skipped or pre-game), text passes through unchanged.

const PAIRS = [
  // 代词
  ['他', '她'],
  // 称呼
  ['学弟', '学妹'],
  ['哥们', '姐们'],
  ['哥', '姐'],
  ['儿子', '女儿'],
  ['侄子', '侄女'],
  ['男朋友', '女朋友'],
  ['男生', '女生'],
  ['男孩子', '女孩子'],
  ['男孩', '女孩'],
  // 学长 / 学姐 — the player is a fresh MSc, so this only applies when an
  // older student (王凯, 上岸了的姐) refers to themselves. Order: 学长 then 学姐.
  ['学长', '学姐'],

  // ── Romance partner names (opposite-gender default) ──
  // The romance NPC has two gendered name variants. Storyline text writes
  // them in OPPOSITE-gender order ("林可儿 / 林楠") so a male player gets
  // the female 林可儿, female player gets male 林楠.
  ['林可儿', '林楠'],
];

// Build a regex that matches any of the pairs separated by optional spaces and a slash.
// e.g.  "他 / 她"   "学弟/学妹"   "男生 / 女生"
function buildRegex() {
  const escape = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const alt = PAIRS.map(([m, f]) => `(?:${escape(m)})\\s*\\/\\s*(?:${escape(f)})`).join('|');
  return new RegExp(alt, 'g');
}

const PRONOUN_REGEX = buildRegex();

// Map from any matched "X / Y" to its parts so we can pick the right side.
function parseMatch(matched) {
  const [left, right] = matched.split(/\s*\/\s*/);
  return [left, right];
}

/**
 * Substitute gendered slash-pairs in a string. Safe to call on any string —
 * if the pattern doesn't match, the string is returned untouched.
 */
export function pronounize(text, gender) {
  if (!text || typeof text !== 'string') return text;
  if (!gender) return text;
  return text.replace(PRONOUN_REGEX, (matched) => {
    const [m, f] = parseMatch(matched);
    return gender === 'female' ? f : m;
  });
}

/**
 * Apply pronounize over an entire event-shaped object.
 * Used when feeding events into modals so the modal itself doesn't have to
 * know about gender.
 */
export function pronounizeEvent(ev, gender) {
  if (!ev || !gender) return ev;
  return {
    ...ev,
    title: pronounize(ev.title, gender),
    title_full: pronounize(ev.title_full, gender),
    body: pronounize(ev.body, gender),
    feedback: pronounize(ev.feedback, gender),
    askerMsg: pronounize(ev.askerMsg, gender),
    setup: pronounize(ev.setup, gender),
    choices: ev.choices?.map(c => ({
      ...c,
      label: pronounize(c.label, gender),
      feedback: pronounize(c.feedback, gender),
    })),
  };
}
