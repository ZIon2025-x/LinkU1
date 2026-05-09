import React, { useEffect } from 'react';
import { getMiscImage } from '../engine/imageRegistry.js';

/**
 * Full-screen transition overlay shown briefly during scene switches.
 * Auto-dismisses after `duration` ms, then calls `onDone`.
 *
 * Used for:
 *  - 去地点（地图 → 地点详情）
 *  - 去 Pret 触发 minigame
 *  - 结束今天 / 进入新周
 *  - 进入 holiday
 *
 * Picks the icon by `context` so different transitions feel different
 * (rain / pret / plane / night / etc).
 */
export function LoadingOverlay({ context, duration = 280, onDone }) {
  useEffect(() => {
    const t = setTimeout(() => onDone && onDone(), duration);
    return () => clearTimeout(t);
  }, [duration, onDone]);

  const icon = pickLoadingIcon(context);
  const caption = pickLoadingCaption(context);

  return (
    <div className="fixed inset-0 z-[60] flex flex-col items-center justify-center animate-fadein"
      style={{ background: 'rgba(10, 8, 6, 0.96)' }}>
      {icon && (
        <img src={icon} alt=""
          className="max-w-[200px] max-h-[200px] object-contain mb-6 animate-pulse"
          style={{ animationDuration: '1.2s' }} />
      )}
      {caption && (
        <div className="text-xs tracking-[0.4em] opacity-60" style={{ fontFamily: 'monospace' }}>
          {caption}
        </div>
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────
// Icon + caption pickers
// ──────────────────────────────────────────────────────

function pickLoadingIcon(ctx = {}) {
  switch (ctx.type) {
    case 'pret':
      return getMiscImage('loading-pret');
    case 'day_end':
      // 优先用 loading-night（如果作者补图了），否则退回 rain（夜雨意境）
      return getMiscImage('loading-night') || getMiscImage('loading-rain');
    case 'week_start':
      return getMiscImage('loading-week') || getMiscImage('loading-plane');
    case 'holiday':
      return getMiscImage('loading-holiday') || getMiscImage('loading-plane');
    case 'travel':
      // 跨城 / 出国旅行
      return getMiscImage('loading-plane');
    case 'essay':
      return getMiscImage('loading-essay') || getMiscImage('loading-rain');
    case 'location':
      // 普通地点切换：默认用 tube（伦敦地铁是主要出行方式）
      if (ctx.locationId === 'station') return getMiscImage('loading-plane');
      if (ctx.weather === 'rainy' || ctx.weather === 'storm') return getMiscImage('loading-rain');
      return getMiscImage('loading-tube') || getMiscImage('loading-rain');
    default:
      return getMiscImage('loading-rain');
  }
}

function pickLoadingCaption(ctx = {}) {
  switch (ctx.type) {
    case 'pret':       return 'Bloomsbury · Pret a Manger';
    case 'essay':      return 'Dissertation · Word Count';
    case 'day_end':    return '今天结束了 · End of Day';
    case 'week_start': return `Week ${ctx.week || ''} · Monday`;
    case 'holiday':    return ctx.holidayType === 'easter' ? 'Easter Break' : 'Christmas Holiday';
    case 'travel':     return ctx.label || 'Travelling…';
    case 'location':   return ctx.label || 'Loading…';
    default:           return 'Loading…';
  }
}
