// Centralized illustration registry — maps semantic ids to bundled image URLs.
//
// Vite's `import.meta.glob` with `{ eager: true, query: '?url', import: 'default' }`
// resolves PNGs at build time to hashed URLs (so they get fingerprinting/CDN
// behavior). Each category exports `id → url` so callers don't have to know
// the file path layout.
//
// Filename convention (from IMAGE_PROMPTS.md):
//   achievements/  achievement-{id}.png
//   locations/     location-{id}.png
//   npcs/          npc-{id}.png  (linnan: npc-linnan-female.png / npc-linnan-male.png)
//   scenes/        scene-{key}.png
//   misc/          {name}.png

const stripPath = (rec, prefix) => {
  const out = {};
  for (const [path, url] of Object.entries(rec)) {
    const name = path.split('/').pop().replace(/\.(webp|png)$/, '');
    const id = name.startsWith(prefix) ? name.slice(prefix.length) : name;
    out[id] = url;
  }
  return out;
};

const achievementsRaw = import.meta.glob(
  '../assets/illustrations/achievements/*.{webp,png}',
  { eager: true, query: '?url', import: 'default' },
);
const locationsRaw = import.meta.glob(
  '../assets/illustrations/locations/*.{webp,png}',
  { eager: true, query: '?url', import: 'default' },
);
const npcsRaw = import.meta.glob(
  '../assets/illustrations/npcs/*.{webp,png}',
  { eager: true, query: '?url', import: 'default' },
);
const scenesRaw = import.meta.glob(
  '../assets/illustrations/scenes/*.{webp,png}',
  { eager: true, query: '?url', import: 'default' },
);
const miscRaw = import.meta.glob(
  '../assets/illustrations/misc/*.{webp,png}',
  { eager: true, query: '?url', import: 'default' },
);

export const ACHIEVEMENT_IMAGES = stripPath(achievementsRaw, 'achievement-');
export const LOCATION_IMAGES    = stripPath(locationsRaw, 'location-');
export const NPC_IMAGES         = stripPath(npcsRaw, 'npc-');
export const SCENE_IMAGES       = stripPath(scenesRaw, 'scene-');
export const MISC_IMAGES        = stripPath(miscRaw, '');  // logo, wrapped-bg, etc.

// ──────────────────────────────────────────────────────
// Lookup helpers
// ──────────────────────────────────────────────────────

/** Achievement image url, or null if no PNG exists for this id. */
export function getAchievementImage(id) {
  return ACHIEVEMENT_IMAGES[id] || null;
}

/** Location image url, or null. */
export function getLocationImage(locId) {
  return LOCATION_IMAGES[locId] || null;
}

/** NPC image url, gender-aware for linnan. */
export function getNpcImage(npcId, gender) {
  if (npcId === 'linnan') {
    const variant = gender === 'female' ? 'linnan-male' : 'linnan-female';
    return NPC_IMAGES[variant] || NPC_IMAGES['linnan-female'] || null;
  }
  return NPC_IMAGES[npcId] || null;
}

/** Scene image url for a known scene key, or null. */
export function getSceneImage(key) {
  return SCENE_IMAGES[key] || null;
}

// Map game event ids to scene illustration keys. Only events whose narrative
// landmark matches a hand-drawn scene get a banner — the rest stay text-only.
const EVENT_TO_SCENE = {
  // dailyLife
  fire_alarm_3am: 'fire_alarm',
  fire_alarm_aftermath: 'fire_alarm',
  bonfire_night: 'bonfire_night',
  boxing_day_selfridges: 'boxing_day',
  tom_sunday_roast: 'sunday_roast',
  // mei family christmas
  mei_christmas_dinner: 'mei_christmas',
  mei_family_christmas: 'mei_christmas',
  xmas_mei_family: 'mei_christmas',
  // parents arrival (welcomeWeek + storyline)
  parents_arrival: 'parents_arrival',
  parents_5_arrival: 'parents_arrival',
  // 4:38 AM crisis
  crisis_438am: 'crisis_4am',
  homesick_crisis: 'crisis_4am',
  diss_existential_crisis_3am: 'crisis_4am',
  // linnan confession
  linnan_5_confession: 'linnan_confession',
  linnan_confession_eve: 'linnan_confession',
  linnan_3: 'linnan_confession',
  // graduation
  graduation_ceremony: 'graduation',
  // ── 之前画了但没接进 event 的 scene ──
  // 公寓 / 搬家钥匙
  moving_day: 'apartment_keys',
  housing_search_2nd_year: 'apartment_keys',
  first_viewing_chaos: 'apartment_keys',
  // Bicester 一日游 (王凯创业线 ch2 + dailyLife)
  wangkai_2: 'bicester_outlets',
  bicester_trip: 'bicester_outlets',
  // Sarah 邀去 Cotswolds (storyline ch3)
  sarah_3: 'cotswolds_visit',
  xmas_sarah_cotswolds: 'cotswolds_visit',
  // Whitmore 高桌晚宴 (storyline ch4 + holiday secret)
  whitmore_4: 'high_table',
  xmas_whitmore_dinner: 'high_table',
  whitmore_common_room_invite: 'high_table',
  // Aditi 印度孟买 (storyline ch3 hospital + holiday secret)
  aditi_3: 'mumbai_visit',
  aditi_4: 'mumbai_visit',
  xmas_aditi_india: 'mumbai_visit',
  // Link2Ur 合伙人 ending banner + Old Street office tour 章节
  link2ur_partner: 'link2ur_office',
  l2u_partner_1: 'link2ur_office',
  // 飞机 / Heathrow 落地 — onboarding 流程
  plane_takeoff: 'plane',
  arrival_heathrow: 'heathrow_arrival',
  // ── Link2Ur 创业线 (第 7 主线) ──
  // 3 新结局 banner
  y_double: 'ending_y_double',
  link2ur_team_founded: 'ending_team_founded',
  link2ur_solo_apex: 'ending_solo_apex',
  // Y 姐 Sketch 邀请 + 合并提议都用 pink room 背景
  yjie_sketch_invitation: 'sketch_pink_room',
  yjie_merger_offer: 'sketch_pink_room',
};

/** Returns scene image url for a given event/chapter id, or null. */
export function getSceneForEvent(eventId) {
  if (!eventId) return null;
  const key = EVENT_TO_SCENE[eventId];
  return key ? getSceneImage(key) : null;
}

/** Misc image url by file basename (e.g. 'logo', 'wrapped-bg'). */
export function getMiscImage(name) {
  return MISC_IMAGES[name] || null;
}

// ──────────────────────────────────────────────────────
// Async image loader — for canvas drawImage
// ──────────────────────────────────────────────────────

const _imageCache = new Map();

export function loadImage(url) {
  if (!url) return Promise.resolve(null);
  if (_imageCache.has(url)) return _imageCache.get(url);
  const promise = new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);  // fall back gracefully
    img.src = url;
  });
  _imageCache.set(url, promise);
  return promise;
}
