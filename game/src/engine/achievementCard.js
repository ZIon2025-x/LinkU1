// Renders a Polaroid-style achievement card to a canvas. Identical look to
// achievement-png-preview.html so users get the same image when they click
// "下载" inside the game as in the standalone preview.
//
// 600 × 720 px portrait. Photo area (square) on top with tier-tinted bg
// (used as fallback) or a real illustration when one exists for this id.
// Caption below with title, desc, weekly stamp, brand mark.

import { TIER_META } from '../data/achievements.js';
import { getAchievementImage, loadImage } from './imageRegistry.js';

/**
 * Synchronous renderer — the `img` arg is an already-loaded HTMLImageElement
 * (or null). Callers should preload via loadImage() first; the public
 * `renderAchievementCard` async wrapper does this for you.
 */
function paintCard(canvas, achievement, meta, img) {
  const ctx = canvas.getContext('2d');
  const W = canvas.width;
  const H = canvas.height;
  const tier = TIER_META[achievement.tier] || TIER_META.common;
  const week = meta.week || null;

  // White polaroid paper
  ctx.fillStyle = '#f4ead8';
  ctx.fillRect(0, 0, W, H);

  // Subtle paper noise
  for (let i = 0; i < 800; i++) {
    ctx.fillStyle = `rgba(0,0,0,${Math.random() * 0.018})`;
    ctx.fillRect(Math.random() * W, Math.random() * H, 1, 1);
  }

  // Photo area (square)
  const photoMargin = 30;
  const photoSize = W - photoMargin * 2;
  const photoY = photoMargin;

  if (img) {
    // Real illustration: cover-fit into the square photo area
    ctx.save();
    ctx.beginPath();
    ctx.rect(photoMargin, photoY, photoSize, photoSize);
    ctx.clip();
    // The PNGs are 1080×1080 already designed with tier-color bg, so just fill.
    ctx.drawImage(img, photoMargin, photoY, photoSize, photoSize);
    ctx.restore();
  } else {
    // Fallback: solid tier-tinted square + emoji centered
    ctx.fillStyle = tier.photoBg;
    ctx.fillRect(photoMargin, photoY, photoSize, photoSize);

    const grad = ctx.createRadialGradient(
      photoMargin + photoSize * 0.3, photoY + photoSize * 0.3, 50,
      photoMargin + photoSize * 0.5, photoY + photoSize * 0.5, photoSize * 0.7,
    );
    grad.addColorStop(0, 'rgba(255,255,255,0.08)');
    grad.addColorStop(1, 'rgba(0,0,0,0.15)');
    ctx.fillStyle = grad;
    ctx.fillRect(photoMargin, photoY, photoSize, photoSize);

    ctx.fillStyle = '#f4ead8';
    ctx.font = '180px serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(achievement.icon, W / 2, photoY + photoSize / 2 + 10);
  }

  // Rarity tag in photo top-left
  ctx.font = '11px ui-monospace, SFMono-Regular, monospace';
  ctx.fillStyle = 'rgba(244, 234, 216, 0.85)';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  // Tag plate so it stays legible regardless of underlying image
  const tag = `◆ ${tier.label}`;
  const tagW = ctx.measureText(tag).width + 14;
  ctx.fillStyle = 'rgba(0,0,0,0.4)';
  ctx.fillRect(photoMargin + 10, photoY + 10, tagW, 22);
  ctx.fillStyle = 'rgba(244, 234, 216, 0.95)';
  ctx.fillText(tag, photoMargin + 17, photoY + 16);

  // Week stamp top-right (rotated stamp style)
  if (week) {
    ctx.save();
    ctx.translate(W - photoMargin - 50, photoY + 30);
    ctx.rotate(8 * Math.PI / 180);
    ctx.font = 'bold 12px "Special Elite", monospace';
    ctx.fillStyle = '#b85040';
    ctx.strokeStyle = '#b85040';
    ctx.lineWidth = 1.5;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.strokeRect(-22, -12, 44, 24);
    ctx.fillText(`W${week}`, 0, 0);
    ctx.restore();
  }

  // Caption block
  const captionY = photoY + photoSize + 40;

  // Title — Cormorant-style serif, dark
  ctx.fillStyle = '#2a2520';
  ctx.font = '500 32px "Cormorant Garamond", "Songti SC", "Source Han Serif", serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText(achievement.title, W / 2, captionY);

  // Description — italic gray with manual word wrap
  ctx.fillStyle = 'rgba(42, 37, 32, 0.65)';
  ctx.font = 'italic 18px "EB Garamond", "Songti SC", serif';
  const desc = achievement.desc;
  const maxWidth = W - 60;
  let line = '';
  let lineY = captionY + 50;
  for (const ch of desc) {
    const test = line + ch;
    if (ctx.measureText(test).width > maxWidth) {
      ctx.fillText(line, W / 2, lineY);
      line = ch;
      lineY += 24;
    } else {
      line = test;
    }
  }
  if (line) ctx.fillText(line, W / 2, lineY);

  // Bottom bar: brand + date
  ctx.fillStyle = 'rgba(42, 37, 32, 0.4)';
  ctx.font = '11px ui-monospace, SFMono-Regular, monospace';
  ctx.textAlign = 'left';
  ctx.fillText('异乡 · A STUDY ABROAD RPG', 30, H - 26);
  ctx.textAlign = 'right';
  const year = new Date().getFullYear();
  const dateText = week ? `WEEK ${String(week).padStart(2, '0')} · ${year}` : `${year}`;
  ctx.fillText(dateText, W - 30, H - 26);

  // Powered-by mark (centered, very small) — your Link2Ur attribution
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(42, 37, 32, 0.3)';
  ctx.font = '9px ui-monospace, SFMono-Regular, monospace';
  ctx.fillText('Powered by Link2Ur', W / 2, H - 12);
}

/**
 * Async public renderer — preloads the achievement illustration (if any)
 * before painting. Resolves once the canvas is fully drawn.
 */
export async function renderAchievementCard(canvas, achievement, meta = {}) {
  const url = getAchievementImage(achievement.id);
  const img = await loadImage(url);
  paintCard(canvas, achievement, meta, img);
}

/**
 * Render to a Promise<Blob> for downloading.
 */
export async function renderToBlob(achievement, meta = {}) {
  const canvas = document.createElement('canvas');
  canvas.width = 600;
  canvas.height = 720;
  await renderAchievementCard(canvas, achievement, meta);
  return new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
}
