// Link2Ur 成就墙 PNG 导出 —— 1080 × 1350 (4:5) 适合朋友圈 / IG / 微博。
//
// 区别于 achievementCard.js 的单卡 polaroid，这张专门展示 Link2Ur 履历：
// 总收入 + 单数 + 评分 + 帮过的熟人 + 接单类型 + 精选留言。
//
// 数据来自 game state，模板类型查 LINK2UR_ACCEPT_TEMPLATES 映射。

import { LINK2UR_BRAND, LINK2UR_ACCEPT_TEMPLATES } from '../data/link2ur.js';
import { LINK2UR_FRIEND_TASKS } from '../data/link2urFriends.js';
import { getUnlockedReviews } from '../data/link2urReviews.js';

const W = 1080;
const H = 1350;

const PRIMARY = LINK2UR_BRAND.primary;   // #007AFF
const ACCENT  = LINK2UR_BRAND.accent;    // #FF8033
const GOLD    = LINK2UR_BRAND.gold;      // #FFD700

const PAPER     = '#f4ead8';
const INK       = '#1f1812';
const INK_SOFT  = 'rgba(31, 24, 18, 0.65)';
const INK_FAINT = 'rgba(31, 24, 18, 0.35)';

const TYPE_LABEL = {
  shopping: '代购', pickup_dropoff: '跑腿', accompany: '陪同',
  translation: '翻译', writing: '校对', tutoring: '家教',
  moving: '搬运', cleaning: '打扫', cooking: '做饭',
  digital: '电子', errand: '杂跑', rental_housing: '看房',
  language_help: '语言', campus_life: '校园',
};

const TEMPLATE_BY_ID = (() => {
  const m = {};
  for (const t of LINK2UR_ACCEPT_TEMPLATES) m[t.id] = t;
  for (const t of LINK2UR_FRIEND_TASKS) m[t.templateId] = t;
  return m;
})();

const NPC_DISPLAY = {
  aditi: { name: 'Aditi', emoji: '💊' },
  linnan: { name: 'Lin', emoji: '🎓' },
  mark: { name: 'Mark', emoji: '🥩' },
};

// ──────────────────────────────────────────────────────
// Stats helpers
// ──────────────────────────────────────────────────────

function aggregateCategories(completed) {
  const counts = {};
  for (const c of completed || []) {
    const tpl = TEMPLATE_BY_ID[c.templateId];
    const type = tpl?.type || 'other';
    counts[type] = (counts[type] || 0) + 1;
  }
  // Sort desc, take top 5
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([type, count]) => ({ type, label: TYPE_LABEL[type] || type, count }));
}

function friendsHelped(friendsCompleted) {
  const set = new Set(friendsCompleted || []);
  return LINK2UR_FRIEND_TASKS
    .filter(t => set.has(t.templateId))
    .map(t => NPC_DISPLAY[t.npcId])
    .filter(Boolean);
}

// ──────────────────────────────────────────────────────
// Drawing primitives
// ──────────────────────────────────────────────────────

function fillPaperNoise(ctx) {
  for (let i = 0; i < 1500; i++) {
    ctx.fillStyle = `rgba(0,0,0,${Math.random() * 0.018})`;
    ctx.fillRect(Math.random() * W, Math.random() * H, 1, 1);
  }
}

function stars(rating) {
  const filled = Math.round(rating);
  return '★'.repeat(filled) + '☆'.repeat(Math.max(0, 5 - filled));
}

function drawHeaderBand(ctx) {
  ctx.fillStyle = PRIMARY;
  ctx.fillRect(0, 0, W, 180);

  // L logo box
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(60, 60, 60, 60);
  ctx.fillStyle = PRIMARY;
  ctx.font = 'bold 40px ui-sans-serif, system-ui, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('L', 60 + 30, 60 + 32);

  // Brand text
  ctx.fillStyle = '#ffffff';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.font = '500 38px ui-sans-serif, system-ui, sans-serif';
  ctx.fillText('Link2Ur', 145, 65);
  ctx.fillStyle = 'rgba(255,255,255,0.7)';
  ctx.font = 'italic 22px ui-serif, "Songti SC", serif';
  ctx.fillText('留学生互助平台', 145, 110);

  // Right: timestamp
  ctx.textAlign = 'right';
  ctx.fillStyle = 'rgba(255,255,255,0.65)';
  ctx.font = '20px ui-monospace, monospace';
  const yr = new Date().getFullYear();
  ctx.fillText(`MY YEAR · ${yr}`, W - 60, 75);
  ctx.fillStyle = 'rgba(255,255,255,0.45)';
  ctx.font = '15px ui-monospace, monospace';
  ctx.fillText('shareable resume', W - 60, 105);
}

function drawProfile(ctx, { displayName, weekHint, rating }) {
  const y = 230;

  // Avatar circle
  ctx.fillStyle = PRIMARY + '20';
  ctx.beginPath();
  ctx.arc(140, y + 50, 56, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = PRIMARY;
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.fillStyle = PRIMARY;
  ctx.font = 'bold 56px serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('异', 140, y + 56);

  // Name + meta
  ctx.fillStyle = INK;
  ctx.font = '500 42px ui-sans-serif, system-ui, "Songti SC", serif';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.fillText(displayName, 220, y + 8);

  ctx.fillStyle = INK_SOFT;
  ctx.font = '22px ui-serif, "Songti SC", serif';
  ctx.fillText(weekHint, 220, y + 60);

  // Big rating
  ctx.fillStyle = GOLD;
  ctx.font = '40px serif';
  ctx.fillText(stars(rating), 220, y + 95);
  ctx.fillStyle = INK_SOFT;
  ctx.font = '20px ui-monospace, monospace';
  ctx.fillText(`${rating.toFixed(1)} / 5.0`, 470, y + 105);
}

function drawStatsGrid(ctx, { earnings, completedCount, rating }) {
  const y = 410;
  const cellW = (W - 120 - 40) / 3;
  const cellH = 160;
  const cells = [
    { label: '总收入', value: `£${earnings}`, sub: 'EARNED' },
    { label: '完成接单', value: `${completedCount}`, sub: 'TASKS' },
    { label: '客户评分', value: rating.toFixed(1), sub: '/ 5.00' },
  ];
  cells.forEach((c, i) => {
    const x = 60 + i * (cellW + 20);
    ctx.strokeStyle = INK_FAINT;
    ctx.lineWidth = 1.5;
    ctx.strokeRect(x, y, cellW, cellH);

    ctx.fillStyle = INK_SOFT;
    ctx.font = '20px ui-serif, "Songti SC", serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText(c.label, x + cellW / 2, y + 22);

    ctx.fillStyle = INK;
    ctx.font = 'bold 56px ui-sans-serif, system-ui, sans-serif';
    ctx.fillText(c.value, x + cellW / 2, y + 56);

    ctx.fillStyle = INK_FAINT;
    ctx.font = '15px ui-monospace, monospace';
    ctx.fillText(c.sub, x + cellW / 2, y + 122);
  });
}

function drawFriendsRow(ctx, friends) {
  if (friends.length === 0) return 580;
  const y = 600;

  // Section title
  ctx.fillStyle = INK_SOFT;
  ctx.font = '20px ui-monospace, monospace';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.fillText('◆ FRIENDS HELPED · 帮过的熟人', 60, y);

  // Chips
  let cx = 60;
  const chipY = y + 35;
  ctx.font = '500 26px ui-sans-serif, system-ui, "Songti SC", serif';
  for (const f of friends) {
    const text = `${f.emoji}  ${f.name}`;
    const tw = ctx.measureText(text).width;
    const padX = 22;
    const chipW = tw + padX * 2;
    const chipH = 56;

    ctx.fillStyle = ACCENT + '15';
    ctx.fillRect(cx, chipY, chipW, chipH);
    ctx.strokeStyle = ACCENT + '70';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(cx, chipY, chipW, chipH);

    ctx.fillStyle = INK;
    ctx.textBaseline = 'middle';
    ctx.fillText(text, cx + padX, chipY + chipH / 2 + 1);
    cx += chipW + 14;
    if (cx > W - 200) break;
  }

  return chipY + 100;
}

function drawCategoryBars(ctx, categories, startY) {
  if (categories.length === 0) return startY;
  const y = startY;

  ctx.fillStyle = INK_SOFT;
  ctx.font = '20px ui-monospace, monospace';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.fillText('◆ TASK CATEGORIES · 接单类型', 60, y);

  const max = Math.max(...categories.map(c => c.count));
  const barX = 60;
  const barWMax = W - 60 - 120;
  const rowH = 42;

  categories.forEach((c, i) => {
    const ry = y + 40 + i * rowH;
    ctx.fillStyle = INK_SOFT;
    ctx.font = '22px ui-sans-serif, system-ui, "Songti SC", serif';
    ctx.textBaseline = 'middle';
    ctx.fillText(c.label, barX, ry + 14);

    const barX2 = barX + 110;
    const barW = (c.count / max) * (barWMax - 110);
    ctx.fillStyle = PRIMARY + '90';
    ctx.fillRect(barX2, ry + 4, barW, 22);

    ctx.fillStyle = INK;
    ctx.font = 'bold 22px ui-monospace, monospace';
    ctx.textAlign = 'right';
    ctx.fillText(`${c.count}`, W - 60, ry + 14);
    ctx.textAlign = 'left';
  });

  return y + 40 + categories.length * rowH + 10;
}

function drawFeaturedReview(ctx, review, startY) {
  if (!review || startY > H - 280) return startY;
  const y = startY + 10;

  ctx.fillStyle = INK_SOFT;
  ctx.font = '20px ui-monospace, monospace';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.fillText('◆ FEATURED REVIEW · 一段留言', 60, y);

  // Quote box
  const boxY = y + 35;
  const boxH = 170;
  ctx.fillStyle = GOLD + '12';
  ctx.fillRect(60, boxY, W - 120, boxH);
  ctx.strokeStyle = GOLD + '70';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(60, boxY, W - 120, boxH);

  // From + role
  ctx.fillStyle = INK;
  ctx.font = '500 24px ui-sans-serif, system-ui, "Songti SC", serif';
  ctx.fillText(`${review.avatar} ${review.from}`, 80, boxY + 18);
  ctx.fillStyle = INK_SOFT;
  ctx.font = 'italic 18px ui-serif, "Songti SC", serif';
  ctx.fillText(review.role, 80, boxY + 50);

  // Stars
  ctx.fillStyle = GOLD;
  ctx.font = '22px serif';
  ctx.textAlign = 'right';
  ctx.fillText('★★★★★', W - 80, boxY + 25);
  ctx.textAlign = 'left';

  // Message (1-2 lines, truncated)
  ctx.fillStyle = INK;
  ctx.font = '20px ui-serif, "Songti SC", serif';
  const text = review.message.replace(/\n+/g, ' ');
  const maxW = W - 160;
  let line = '';
  let lineY = boxY + 90;
  let linesDone = 0;
  for (const ch of text) {
    const test = line + ch;
    if (ctx.measureText(test).width > maxW) {
      ctx.fillText(line, 80, lineY);
      line = ch;
      lineY += 28;
      linesDone += 1;
      if (linesDone >= 2) {
        line = line + '...';
        break;
      }
    } else {
      line = test;
    }
  }
  if (line && linesDone < 3) ctx.fillText(line, 80, lineY);

  return boxY + boxH + 20;
}

function drawFooter(ctx) {
  ctx.fillStyle = INK;
  ctx.fillRect(0, H - 80, W, 80);

  ctx.fillStyle = '#ffffff';
  ctx.font = '500 22px ui-sans-serif, system-ui, "Songti SC", serif';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('Made with ♥ by Link2Ur · 留学生互助平台', 60, H - 40);

  ctx.fillStyle = 'rgba(255,255,255,0.5)';
  ctx.font = '16px ui-monospace, monospace';
  ctx.textAlign = 'right';
  ctx.fillText('link2ur.com', W - 60, H - 40);
}

// ──────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────

export function renderLink2UrWall(canvas, state) {
  const ctx = canvas.getContext('2d');

  // Bg paper
  ctx.fillStyle = PAPER;
  ctx.fillRect(0, 0, W, H);
  fillPaperNoise(ctx);

  drawHeaderBand(ctx);

  const week = Math.ceil((state.day || 1) / 7);
  const completed = state.link2urCompleted || [];
  const earnings = state.link2urEarnings || 0;
  const rating = state.link2urRating || 5.0;
  const friends = friendsHelped(state.link2urFriendsCompleted);
  const categories = aggregateCategories(completed);
  const reviews = getUnlockedReviews(state);
  const featuredReview = reviews[0] || null;

  drawProfile(ctx, {
    displayName: '异乡 · LDN',
    weekHint: `第 ${week} 周 · ${week >= 30 ? '下学期' : '上学期'}`,
    rating,
  });

  drawStatsGrid(ctx, {
    earnings,
    completedCount: completed.length,
    rating,
  });

  let cursorY = drawFriendsRow(ctx, friends);
  cursorY = drawCategoryBars(ctx, categories, cursorY);
  drawFeaturedReview(ctx, featuredReview, cursorY);

  drawFooter(ctx);
}

export function renderWallToBlob(state) {
  const canvas = document.createElement('canvas');
  canvas.width = W;
  canvas.height = H;
  renderLink2UrWall(canvas, state);
  return new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
}
