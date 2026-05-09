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
    const name = path.split('/').pop().replace(/\.png$/, '');
    const id = name.startsWith(prefix) ? name.slice(prefix.length) : name;
    out[id] = url;
  }
  return out;
};

const achievementsRaw = import.meta.glob(
  '../assets/illustrations/achievements/*.png',
  { eager: true, query: '?url', import: 'default' },
);
const locationsRaw = import.meta.glob(
  '../assets/illustrations/locations/*.png',
  { eager: true, query: '?url', import: 'default' },
);
const npcsRaw = import.meta.glob(
  '../assets/illustrations/npcs/*.png',
  { eager: true, query: '?url', import: 'default' },
);
const scenesRaw = import.meta.glob(
  '../assets/illustrations/scenes/*.png',
  { eager: true, query: '?url', import: 'default' },
);
const miscRaw = import.meta.glob(
  '../assets/illustrations/misc/*.png',
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
  // tom Sunday roast (label varies by file — extend here when located)
  tom_sunday_roast: 'sunday_roast',
  // mei family christmas
  mei_christmas_dinner: 'mei_christmas',
  mei_family_christmas: 'mei_christmas',
  // parents arrival
  parents_arrival: 'parents_arrival',
  parents_5_arrival: 'parents_arrival',
  // 4:38 AM crisis
  crisis_438am: 'crisis_4am',
  homesick_crisis: 'crisis_4am',
  // linnan confession
  linnan_5_confession: 'linnan_confession',
  linnan_confession_eve: 'linnan_confession',
  // graduation
  graduation_ceremony: 'graduation',
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
