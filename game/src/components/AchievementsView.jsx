import React, { useEffect, useRef, useState } from 'react';
import { ACHIEVEMENTS, TIER_META } from '../data/achievements.js';
import { renderAchievementCard, renderToBlob } from '../engine/achievementCard.js';
import { renderWrappedPoster, renderWrappedToBlob } from '../engine/wrappedPoster.js';
import { pronounize } from '../engine/pronouns.js';
import { download } from '../engine/diaryExport.js';
import { BottomSheet } from './BottomSheet.jsx';

export function AchievementsView({ unlockedAchievements, gender, gameState }) {
  const [filter, setFilter] = useState('all');  // all | unlocked | locked
  const [openCard, setOpenCard] = useState(null);
  const [wrappedOpen, setWrappedOpen] = useState(false);

  const unlockedMap = Object.fromEntries(
    (unlockedAchievements || []).map(a => [a.id, a]),
  );
  const total = ACHIEVEMENTS.length;
  const unlockedCount = (unlockedAchievements || []).length;

  let visible = ACHIEVEMENTS;
  if (filter === 'unlocked') visible = ACHIEVEMENTS.filter(a => unlockedMap[a.id]);
  if (filter === 'locked')   visible = ACHIEVEMENTS.filter(a => !unlockedMap[a.id]);

  // Group by tier within visible
  const byTier = { common: [], rare: [], epic: [], legendary: [] };
  for (const a of visible) byTier[a.tier]?.push(a);

  return (
    <div className="animate-fadein">
      <div className="text-xs tracking-[0.2em] opacity-60 mb-3 flex justify-between items-center" style={{ fontFamily: 'monospace' }}>
        <span>🎖 成就 · {unlockedCount} / {total}</span>
        <span className="opacity-60">点击解锁卡片可查看 + 下载</span>
      </div>

      {gameState && unlockedCount > 0 && (
        <button onClick={() => setWrappedOpen(true)}
          className="w-full mb-3 py-2 border text-xs tracking-[0.2em] flex items-center justify-center gap-2 transition-colors"
          style={{ borderColor: '#d4b070a0', color: '#d4b070', background: '#d4b07012' }}>
          <span>📸</span>
          <span>导出 Year-End Wrapped 海报</span>
        </button>
      )}

      <div className="grid grid-cols-3 gap-1 mb-3 text-xs">
        <button onClick={() => setFilter('all')}
          className={`py-1.5 border ${filter === 'all' ? 'border-current bg-current/10' : 'border-current/30 opacity-60'}`}>
          全部 {total}
        </button>
        <button onClick={() => setFilter('unlocked')}
          className={`py-1.5 border ${filter === 'unlocked' ? 'border-amber-300/70 bg-amber-300/10' : 'border-current/30 opacity-60'}`}>
          已解锁 {unlockedCount}
        </button>
        <button onClick={() => setFilter('locked')}
          className={`py-1.5 border ${filter === 'locked' ? 'border-current bg-current/10' : 'border-current/30 opacity-60'}`}>
          未解锁 {total - unlockedCount}
        </button>
      </div>

      <div className="space-y-3 max-h-[60vh] overflow-y-auto pr-1">
        {['common', 'rare', 'epic', 'legendary'].map(tier => {
          const tierAchievements = byTier[tier];
          if (tierAchievements.length === 0) return null;
          const meta = TIER_META[tier];
          return (
            <div key={tier}>
              <div className="text-xs opacity-50 mb-1.5" style={{ fontFamily: 'monospace', color: meta.accent }}>
                ◆ {meta.label}
              </div>
              <div className="grid grid-cols-3 gap-2">
                {tierAchievements.map(a => {
                  const u = unlockedMap[a.id];
                  return (
                    <button key={a.id}
                      onClick={() => u && setOpenCard({ ...a, week: u.week })}
                      disabled={!u}
                      className={`p-2 border text-center transition-all ${u
                        ? 'hover:scale-105 cursor-pointer'
                        : 'opacity-30 cursor-not-allowed grayscale'}`}
                      style={u
                        ? { borderColor: meta.borderColor, background: meta.photoBg + '20' }
                        : { borderColor: 'rgba(232,224,208,0.15)' }}>
                      <div className="text-3xl mb-1">{u ? a.icon : '🔒'}</div>
                      <div className="text-xs" style={{ lineHeight: '1.4' }}>
                        {u ? pronounize(a.title, gender) : '???'}
                      </div>
                      {u && u.week && (
                        <div className="text-[10px] opacity-50 mt-1" style={{ fontFamily: 'monospace' }}>W{u.week}</div>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>

      {openCard && (
        <AchievementCardModal achievement={openCard} gender={gender} onClose={() => setOpenCard(null)} />
      )}
      {wrappedOpen && gameState && (
        <WrappedPosterModal gameState={gameState} onClose={() => setWrappedOpen(false)} />
      )}
    </div>
  );
}

// Web Share API helper —— 浏览器支持 navigator.canShare({ files }) 时直接拉起系统分享；
// 否则尝试 clipboard 把 PNG 复制（部分浏览器支持），最后兜底成下载。
async function sharePngBlob(blob, filename, title = '异乡') {
  if (!blob) return { ok: false, reason: 'no-blob' };
  try {
    const file = new File([blob], filename, { type: 'image/png' });
    if (navigator.share && navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], title });
      return { ok: true, mode: 'native' };
    }
  } catch (e) { /* user cancelled or unsupported */ }
  // Clipboard 兜底
  try {
    if (navigator.clipboard && window.ClipboardItem) {
      await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
      return { ok: true, mode: 'clipboard' };
    }
  } catch (e) { /* fall through */ }
  // 最终兜底：触发下载
  download(blob, filename);
  return { ok: true, mode: 'download' };
}

export function WrappedPosterModal({ gameState, onClose }) {
  const canvasRef = useRef(null);
  const [busy, setBusy] = useState(null);   // null | 'download' | 'share'
  const [hint, setHint] = useState('1080×1920 · 朋友圈竖版分享物');

  useEffect(() => {
    if (canvasRef.current) {
      renderWrappedPoster(canvasRef.current, gameState).catch(() => {});
    }
  }, [gameState]);

  const filename = `异乡-Wrapped-W${Math.ceil((gameState?.day || 1) / 7)}.png`;

  async function handleDownload() {
    setBusy('download');
    try {
      const blob = await renderWrappedToBlob(gameState);
      download(blob, filename);
    } finally {
      setBusy(null);
    }
  }
  async function handleShare() {
    setBusy('share');
    try {
      const blob = await renderWrappedToBlob(gameState);
      const r = await sharePngBlob(blob, filename, '异乡 · Year-End Wrapped');
      if (r.mode === 'clipboard') setHint('✓ 已复制到剪贴板，去聊天里粘贴');
      else if (r.mode === 'download') setHint('✓ 已下载，去相册转发');
    } finally {
      setBusy(null);
    }
  }

  return (
    <BottomSheet open={true} onClose={onClose}>
      <div className="text-xs tracking-[0.3em] opacity-60 mb-2 text-center" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
        ◆ YEAR-END WRAPPED
      </div>
      <canvas ref={canvasRef} width={1080} height={1920}
        className="w-full mb-4 shadow-2xl"
        style={{ aspectRatio: '1080 / 1920' }} />
      <div className="grid grid-cols-3 gap-2">
        <button onClick={handleDownload} disabled={!!busy}
          className="py-2.5 border text-sm tracking-[0.2em] transition-colors disabled:opacity-50"
          style={{ borderColor: '#d4b070a0', color: '#d4b070', background: '#d4b07012' }}>
          {busy === 'download' ? '生成中…' : '↓ 下载'}
        </button>
        <button onClick={handleShare} disabled={!!busy}
          className="py-2.5 border text-sm tracking-[0.2em] transition-colors disabled:opacity-50"
          style={{ borderColor: '#a0c890a0', color: '#a0c890', background: '#a0c89012' }}>
          {busy === 'share' ? '生成中…' : '↗ 分享'}
        </button>
        <button onClick={onClose}
          className="py-2.5 border border-current/40 hover:bg-current/5 active:bg-current/10 transition-colors text-sm tracking-[0.2em]">
          取消
        </button>
      </div>
      <div className="text-xs opacity-50 italic text-center mt-3" style={{ lineHeight: '1.7' }}>
        {hint}
      </div>
    </BottomSheet>
  );
}

export function AchievementCardModal({ achievement, gender, onClose }) {
  const canvasRef = useRef(null);
  const [busy, setBusy] = useState(null);
  const [hint, setHint] = useState('下载到本地 → 长按转发到微信 / 朋友圈');

  const localized = {
    ...achievement,
    title: pronounize(achievement.title, gender),
    desc: pronounize(achievement.desc, gender),
  };

  useEffect(() => {
    if (canvasRef.current) {
      renderAchievementCard(canvasRef.current, localized, { week: achievement.week })
        .catch(() => {});
    }
  }, [achievement]);

  const filename = `异乡-成就-${achievement.id}.png`;

  async function handleDownload() {
    setBusy('download');
    try {
      const blob = await renderToBlob(localized, { week: achievement.week });
      download(blob, filename);
    } finally {
      setBusy(null);
    }
  }
  async function handleShare() {
    setBusy('share');
    try {
      const blob = await renderToBlob(localized, { week: achievement.week });
      const r = await sharePngBlob(blob, filename, `异乡 · ${localized.title}`);
      if (r.mode === 'clipboard') setHint('✓ 已复制到剪贴板，去聊天里粘贴');
      else if (r.mode === 'download') setHint('✓ 已下载，去相册转发');
    } finally {
      setBusy(null);
    }
  }

  return (
    <BottomSheet open={true} onClose={onClose}>
      <div className="text-xs tracking-[0.3em] opacity-60 mb-2 text-center" style={{ fontFamily: 'monospace' }}>
        ◆ {TIER_META[achievement.tier]?.label || 'COMMON'}
      </div>
      <canvas ref={canvasRef} width={600} height={720}
        className="w-full mb-4 shadow-2xl"
        style={{ aspectRatio: '600 / 720' }} />
      <div className="grid grid-cols-3 gap-2">
        <button onClick={handleDownload} disabled={!!busy}
          className="py-2.5 border border-amber-300/60 hover:bg-amber-300/10 active:bg-amber-300/15 transition-colors text-sm tracking-[0.2em] disabled:opacity-50"
          style={{ color: '#d4b070' }}>
          {busy === 'download' ? '生成中…' : '↓ 下载'}
        </button>
        <button onClick={handleShare} disabled={!!busy}
          className="py-2.5 border text-sm tracking-[0.2em] transition-colors disabled:opacity-50"
          style={{ borderColor: '#a0c890a0', color: '#a0c890', background: '#a0c89012' }}>
          {busy === 'share' ? '生成中…' : '↗ 分享'}
        </button>
        <button onClick={onClose}
          className="py-2.5 border border-current/40 hover:bg-current/5 active:bg-current/10 transition-colors text-sm tracking-[0.2em]">
          取消
        </button>
      </div>
      <div className="text-xs opacity-50 italic text-center mt-3" style={{ lineHeight: '1.7' }}>
        {hint}
      </div>
    </BottomSheet>
  );
}
