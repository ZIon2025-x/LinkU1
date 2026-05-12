// Centralized ambient audio file registry.
//
// Vite 的 import.meta.glob eager-loads `assets/audio/ambient-*.{mp3,wav,flac,ogg}`
// 并按 `ambient-<id>` 解析成 { id → fingerprinted URL }。
//
// 文件名 -> id 映射:
//   ambient-mei.flac    → AMBIENT_URLS.mei
//   ambient-rain.wav    → AMBIENT_URLS.rain

const ambientRaw = import.meta.glob(
  '../assets/audio/ambient-*.{mp3,wav,flac,ogg,m4a}',
  { eager: true, query: '?url', import: 'default' },
);

const stripPath = (rec, prefix) => {
  const out = {};
  for (const [path, url] of Object.entries(rec)) {
    const name = path.split('/').pop().replace(/\.(mp3|wav|flac|ogg|m4a)$/i, '');
    const id = name.startsWith(prefix) ? name.slice(prefix.length) : name;
    out[id] = url;
  }
  return out;
};

export const AMBIENT_URLS = stripPath(ambientRaw, 'ambient-');
