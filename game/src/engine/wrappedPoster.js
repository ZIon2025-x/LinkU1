// Year-End Wrapped 海报 —— 1080×1920 朋友圈竖版分享物。
//
// 用 wrapped-bg.png 做底图（一面木墙 + 空 polaroid 框 + 手写便签 + 装饰）。
// 代码在 bg 顶部 30% 加 title，中段填 4-6 张已解锁成就缩略图，底部 15% 加
// stats 数字 + Link2Ur attribution。
//
// 输出 PNG，玩家可直接转发朋友圈。

import { ACHIEVEMENT_BY_ID } from '../data/achievements.js';
import { getMiscImage, getAchievementImage, loadImage } from './imageRegistry.js';

const W = 1080;
const H = 1920;

const INK       = '#f4ead8';
const INK_SOFT  = 'rgba(244, 234, 216, 0.7)';
const INK_FAINT = 'rgba(244, 234, 216, 0.4)';
const ACCENT    = '#d4b070';

// 中段 4 张 polaroid 的位置（2×2 grid）；每张 240×290，留 30px 间距
// 假设 bg 中段是 y=620-1450 的"墙面"区域。
const POLAROID_SLOTS = [
  { x: 200, y: 720,  w: 280, h: 320, rotate: -3 },
  { x: 600, y: 720,  w: 280, h: 320, rotate: 2 },
  { x: 200, y: 1100, w: 280, h: 320, rotate: 4 },
  { x: 600, y: 1100, w: 280, h: 320, rotate: -2 },
];

// ──────────────────────────────────────────────────────
// Drawing
// ──────────────────────────────────────────────────────

function drawTitle(ctx, weekCount, achCount) {
  // 顶部 30% 空白区: y=0~576
  ctx.fillStyle = INK;
  ctx.font = '500 80px "Cormorant Garamond", "Songti SC", "Source Han Serif", serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText('我的留學一年', W / 2, 220);

  ctx.fillStyle = INK_SOFT;
  ctx.font = 'italic 32px ui-serif, "Songti SC", serif';
  ctx.fillText('A Study Abroad RPG · Year-End Wrapped', W / 2, 320);

  ctx.fillStyle = INK_FAINT;
  ctx.font = '24px ui-monospace, monospace';
  ctx.fillText(`${weekCount} 周 · ${achCount} 成就解锁`, W / 2, 380);

  // 装饰线
  ctx.strokeStyle = INK_FAINT;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.moveTo(W / 2 - 80, 440);
  ctx.lineTo(W / 2 + 80, 440);
  ctx.stroke();
}

function drawPolaroid(ctx, slot, ach, img) {
  ctx.save();
  ctx.translate(slot.x + slot.w / 2, slot.y + slot.h / 2);
  ctx.rotate(slot.rotate * Math.PI / 180);

  const pw = slot.w;
  const ph = slot.h;
  const x = -pw / 2;
  const y = -ph / 2;

  // Polaroid paper bg
  ctx.fillStyle = '#f4ead8';
  ctx.fillRect(x, y, pw, ph);
  ctx.shadowColor = 'rgba(0,0,0,0.4)';
  ctx.shadowBlur = 16;
  ctx.shadowOffsetY = 4;
  ctx.fillRect(x, y, pw, ph);
  ctx.shadowColor = 'transparent';

  // Photo area (square, top of polaroid)
  const photoMargin = 16;
  const photoSize = pw - photoMargin * 2;
  const photoY = y + photoMargin;

  if (img) {
    ctx.save();
    ctx.beginPath();
    ctx.rect(x + photoMargin, photoY, photoSize, photoSize);
    ctx.clip();
    ctx.drawImage(img, x + photoMargin, photoY, photoSize, photoSize);
    ctx.restore();
  } else {
    // Fallback: emoji on tier color
    ctx.fillStyle = '#3a3530';
    ctx.fillRect(x + photoMargin, photoY, photoSize, photoSize);
    if (ach.icon) {
      ctx.fillStyle = '#f4ead8';
      ctx.font = `${Math.round(photoSize * 0.5)}px serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(ach.icon, x + pw / 2, photoY + photoSize / 2 + 4);
    }
  }

  // Caption under photo
  ctx.fillStyle = '#2a2520';
  ctx.font = '500 22px "Cormorant Garamond", "Songti SC", serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  const captionY = photoY + photoSize + (ph - photoSize - photoMargin * 2) / 2;
  ctx.fillText(ach.title.slice(0, 10), x + pw / 2, captionY);

  ctx.restore();
}

function drawStats(ctx, stats) {
  // 底部 15% 区: y=1632~1920
  const baseY = 1640;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';

  ctx.fillStyle = INK_SOFT;
  ctx.font = '20px ui-monospace, monospace';
  ctx.fillText('— FINAL STATS · 学年总结 —', W / 2, baseY);

  // 4 stats in row
  const cells = [
    { label: '学业', value: `${stats.academic}%` },
    { label: '钱包', value: `£${stats.wallet}` },
    { label: '精力', value: `${stats.energy}%` },
    { label: '归属', value: `${stats.belonging}%` },
  ];
  const cellW = W / cells.length;
  cells.forEach((c, i) => {
    const cx = i * cellW + cellW / 2;
    ctx.fillStyle = INK_FAINT;
    ctx.font = '18px ui-serif, "Songti SC", serif';
    ctx.fillText(c.label, cx, baseY + 50);
    ctx.fillStyle = INK;
    ctx.font = 'bold 44px ui-sans-serif, system-ui, sans-serif';
    ctx.fillText(c.value, cx, baseY + 78);
  });

  // Bottom Link2Ur attribution
  ctx.fillStyle = INK_FAINT;
  ctx.font = '18px ui-monospace, monospace';
  ctx.fillText('Made with ♥ by Link2Ur · 留学生互助平台 · link2ur.com', W / 2, H - 60);
}

// ──────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────

export async function renderWrappedPoster(canvas, state) {
  const ctx = canvas.getContext('2d');

  // Bg paper fallback
  ctx.fillStyle = '#2a2520';
  ctx.fillRect(0, 0, W, H);

  // Load wrapped bg
  const bgUrl = getMiscImage('wrapped-bg');
  const bg = await loadImage(bgUrl);
  if (bg) ctx.drawImage(bg, 0, 0, W, H);

  // Title block
  const week = Math.ceil((state.day || 1) / 7);
  const unlocked = state.unlockedAchievements || [];
  drawTitle(ctx, week, unlocked.length);

  // 4 highlight achievements: prefer legendary > epic > rare > common
  const ranked = unlocked
    .map(u => ({ ...u, def: ACHIEVEMENT_BY_ID[u.id] }))
    .filter(u => !!u.def)
    .sort((a, b) => {
      const tierRank = { legendary: 4, epic: 3, rare: 2, common: 1 };
      return (tierRank[b.def.tier] || 0) - (tierRank[a.def.tier] || 0);
    })
    .slice(0, POLAROID_SLOTS.length);

  // Preload achievement images in parallel
  const imgs = await Promise.all(
    ranked.map(u => loadImage(getAchievementImage(u.id))),
  );

  ranked.forEach((u, i) => {
    drawPolaroid(ctx, POLAROID_SLOTS[i], u.def, imgs[i]);
  });

  drawStats(ctx, state.stats || {});
}

export async function renderWrappedToBlob(state) {
  const canvas = document.createElement('canvas');
  canvas.width = W;
  canvas.height = H;
  await renderWrappedPoster(canvas, state);
  return new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
}
