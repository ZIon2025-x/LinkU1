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

// 新 wrapped-bg.png 是干净的：中间一大块空白 cork board，周围是道具
// (挂衣架 / 干花 / 旅行箱 / 书堆 / Tower Bridge / 老干妈)。
// Polaroid 在 cork board 区域内动态排版 —— 数量越多排越密。
const CORK_AREA = { x: 150, y: 240, w: 670, h: 590 };

// 计算 n 张 polaroid 的位置。Polaroid 数量自适应：
//   1     → 1 张大居中
//   2-3   → 横排
//   4     → 2×2 grid
//   5-6   → 2×3 grid
//   7-9   → 3×3 grid
// 每张轻微随机旋转（按 index 取固定值确保稳定），看起来像随手贴上的。
function computeLayout(count) {
  if (count <= 0) return [];
  const { x: ax, y: ay, w: aw, h: ah } = CORK_AREA;
  const ROTS = [-4, 2, -2, 3, -3, 1, -1, 4, 0];

  if (count === 1) {
    const pw = 280, ph = 340;
    return [{
      x: ax + (aw - pw) / 2, y: ay + (ah - ph) / 2,
      w: pw, h: ph, rotate: -2,
    }];
  }
  if (count <= 3) {
    const pw = 200, ph = 240, gap = 30;
    const totalW = count * pw + (count - 1) * gap;
    const startX = ax + (aw - totalW) / 2;
    const py = ay + (ah - ph) / 2;
    return Array.from({ length: count }, (_, i) => ({
      x: startX + i * (pw + gap), y: py, w: pw, h: ph,
      rotate: ROTS[i],
    }));
  }
  if (count === 4) {
    const pw = 220, ph = 260;
    const gapX = (aw - 2 * pw) / 3;
    const gapY = (ah - 2 * ph) / 3;
    return [
      { x: ax + gapX,            y: ay + gapY,            w: pw, h: ph, rotate: -3 },
      { x: ax + 2*gapX + pw,     y: ay + gapY,            w: pw, h: ph, rotate:  2 },
      { x: ax + gapX,            y: ay + 2*gapY + ph,     w: pw, h: ph, rotate:  1 },
      { x: ax + 2*gapX + pw,     y: ay + 2*gapY + ph,     w: pw, h: ph, rotate: -2 },
    ];
  }
  if (count <= 6) {
    const cols = 3, rows = 2;
    const pw = 190, ph = 230;
    const gapX = (aw - cols * pw) / (cols + 1);
    const gapY = (ah - rows * ph) / (rows + 1);
    const slots = [];
    for (let r = 0; r < rows && slots.length < count; r++) {
      for (let c = 0; c < cols && slots.length < count; c++) {
        slots.push({
          x: ax + gapX * (c + 1) + c * pw,
          y: ay + gapY * (r + 1) + r * ph,
          w: pw, h: ph,
          rotate: ROTS[slots.length],
        });
      }
    }
    return slots;
  }
  // count >= 7 → 3×3 grid, max 9
  const cols = 3, rows = 3;
  const pw = 170, ph = 200;
  const gapX = (aw - cols * pw) / (cols + 1);
  const gapY = (ah - rows * ph) / (rows + 1);
  const slots = [];
  const cap = Math.min(count, 9);
  for (let r = 0; r < rows && slots.length < cap; r++) {
    for (let c = 0; c < cols && slots.length < cap; c++) {
      slots.push({
        x: ax + gapX * (c + 1) + c * pw,
        y: ay + gapY * (r + 1) + r * ph,
        w: pw, h: ph,
        rotate: ROTS[slots.length],
      });
    }
  }
  return slots;
}

// ──────────────────────────────────────────────────────
// Drawing
// ──────────────────────────────────────────────────────

function drawTitle(ctx, weekCount, achCount) {
  // 标题压缩到 y=70~245 —— 紧贴 wrapped-bg.png 上方木墙窄带，
  // 让出 y=270+ 给 R1 polaroid。右侧 / 中间区域空，左侧画了挂衣架（避开）。
  ctx.fillStyle = INK;
  ctx.font = '500 64px "Cormorant Garamond", "Songti SC", "Source Han Serif", serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText('我的留學一年', W / 2, 70);

  ctx.fillStyle = INK_SOFT;
  ctx.font = 'italic 26px ui-serif, "Songti SC", serif';
  ctx.fillText('A Study Abroad RPG · Year-End Wrapped', W / 2, 150);

  ctx.fillStyle = INK_FAINT;
  ctx.font = '20px ui-monospace, monospace';
  ctx.fillText(`${weekCount} 周 · ${achCount} 成就解锁`, W / 2, 190);

  // 装饰线
  ctx.strokeStyle = INK_FAINT;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.moveTo(W / 2 - 80, 232);
  ctx.lineTo(W / 2 + 80, 232);
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
  // 底部加深色遮罩，stats 才看得清（不然会被画里的旅行箱/书堆/地板搅花眼）
  const stripH = 200;
  const stripY = H - stripH;
  const grad = ctx.createLinearGradient(0, stripY, 0, H);
  grad.addColorStop(0, 'rgba(10, 8, 6, 0)');
  grad.addColorStop(0.35, 'rgba(10, 8, 6, 0.78)');
  grad.addColorStop(1, 'rgba(10, 8, 6, 0.92)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, stripY, W, stripH);

  const baseY = H - 160;
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
    ctx.fillText(c.label, cx, baseY + 38);
    ctx.fillStyle = INK;
    ctx.font = 'bold 40px ui-sans-serif, system-ui, sans-serif';
    ctx.fillText(c.value, cx, baseY + 66);
  });

  // Bottom Link2Ur attribution
  ctx.fillStyle = INK_FAINT;
  ctx.font = '16px ui-monospace, monospace';
  ctx.fillText('Made with ♥ by Link2Ur · 留学生互助平台 · link2ur.com', W / 2, H - 36);
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

  // 选成就：按 tier 倒排，最多取 9 张（cork board 容量上限）
  const ranked = unlocked
    .map(u => ({ ...u, def: ACHIEVEMENT_BY_ID[u.id] }))
    .filter(u => !!u.def)
    .sort((a, b) => {
      const tierRank = { legendary: 4, epic: 3, rare: 2, common: 1 };
      return (tierRank[b.def.tier] || 0) - (tierRank[a.def.tier] || 0);
    })
    .slice(0, 9);

  // 按数量计算 polaroid 槽位（1 / 2-3 / 4 / 5-6 / 7-9 不同 layout）
  const slots = computeLayout(ranked.length);

  // 并行加载图
  const imgs = await Promise.all(
    ranked.map(u => loadImage(getAchievementImage(u.id))),
  );

  ranked.forEach((u, i) => {
    if (!slots[i]) return;
    drawPolaroid(ctx, slots[i], u.def, imgs[i]);
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
