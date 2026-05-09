// Diary export helpers — Markdown file + canvas-rendered PNG.
//
// No external dependencies. PNG is hand-rendered onto a 2D canvas with
// simple line-wrapped text, scaled for a phone-screenshot share use case.

const TYPE_HEADERS = {
  choice: { title: '我做过的决定', icon: '◆', color: '#d4b070' },
  dream: { title: '梦', icon: '☾', color: '#c8b8e0' },
  insomnia: { title: '失眠', icon: '☾', color: '#a8a09c' },
  nostalgia: { title: '想家', icon: '🏮', color: '#e8c8c0' },
};

/**
 * Build the four diary sections from raw state in a uniform shape so the
 * exporters don't need to know the source format.
 */
export function collectEntries({ diaryChoices = [], dreams = [], insomnias = [], nostalgias = [] }) {
  return {
    choice: diaryChoices.map(c => ({
      title: c.title,
      body: c.line,
      week: c.week,
      day: c.day,
    })),
    dream: dreams.map(d => ({ title: d.title, body: d.body })),
    insomnia: insomnias.map(d => ({ title: d.title, body: d.body })),
    nostalgia: nostalgias.map(d => ({ title: d.title, body: d.body })),
  };
}

/**
 * Build a Markdown document of the player's full diary. Newest first, grouped
 * by category. The result is suitable for sharing or saving locally.
 */
export function toMarkdown(buckets, meta = {}) {
  const { week, totalWeeks = 52 } = meta;
  let md = `# 异乡 · 我的留学日记\n\n`;
  if (week) md += `> 第 ${week} / ${totalWeeks} 周\n\n`;
  md += `> 导出于 ${new Date().toLocaleString('zh-CN')}\n\n---\n\n`;

  for (const key of ['choice', 'dream', 'insomnia', 'nostalgia']) {
    const items = buckets[key];
    if (!items || items.length === 0) continue;
    const meta = TYPE_HEADERS[key];
    md += `## ${meta.icon} ${meta.title}（${items.length}）\n\n`;
    for (const item of items) {
      const tag = item.week ? ` _W${item.week}_` : '';
      md += `### ${item.title}${tag}\n\n`;
      md += `${item.body}\n\n`;
    }
    md += `---\n\n`;
  }
  md += `_这是一年留学生活留下的日记。_\n`;
  return md;
}

/**
 * Render the diary as a PNG using a 2D canvas. The canvas is grown vertically
 * as text overflows, then exported via toBlob.
 */
export function toPNG(buckets, meta = {}, opts = {}) {
  const W = opts.width || 800;
  const margin = 48;
  const titleSize = 32;
  const sectionSize = 22;
  const entryTitleSize = 17;
  const bodySize = 14;
  const lineHeight = 1.7;
  const fontSerif = '"EB Garamond", "Songti SC", "Source Han Serif", serif';
  const fontMono = 'ui-monospace, SFMono-Regular, Menlo, monospace';

  // First pass: measure to determine canvas height.
  const measureCanvas = document.createElement('canvas');
  const m = measureCanvas.getContext('2d');

  function wrapLines(text, maxWidth, font) {
    m.font = font;
    const out = [];
    for (const para of text.split('\n')) {
      if (!para) { out.push(''); continue; }
      let line = '';
      for (const ch of para) {
        const test = line + ch;
        if (m.measureText(test).width > maxWidth && line) {
          out.push(line);
          line = ch;
        } else {
          line = test;
        }
      }
      if (line) out.push(line);
    }
    return out;
  }

  const contentWidth = W - margin * 2;
  const segments = [];
  let y = margin;

  // Header
  segments.push({ kind: 'title', text: '异乡 · 我的留学日记', y });
  y += titleSize * lineHeight;
  if (meta.week) {
    segments.push({ kind: 'subtitle', text: `第 ${meta.week} / ${meta.totalWeeks || 52} 周 · 导出于 ${new Date().toLocaleString('zh-CN')}`, y });
    y += bodySize * lineHeight;
  }
  y += 12;
  segments.push({ kind: 'divider', y });
  y += 16;

  for (const key of ['choice', 'dream', 'insomnia', 'nostalgia']) {
    const items = buckets[key];
    if (!items || items.length === 0) continue;
    const sectionMeta = TYPE_HEADERS[key];

    segments.push({ kind: 'section', text: `${sectionMeta.icon} ${sectionMeta.title}（${items.length}）`, color: sectionMeta.color, y });
    y += sectionSize * lineHeight + 8;

    for (const item of items) {
      const titleText = item.week ? `${item.title}  ·  W${item.week}` : item.title;
      segments.push({ kind: 'entry-title', text: titleText, y });
      y += entryTitleSize * lineHeight;

      const bodyLines = wrapLines(item.body, contentWidth, `${bodySize}px ${fontSerif}`);
      for (const line of bodyLines) {
        segments.push({ kind: 'entry-body', text: line, y });
        y += bodySize * lineHeight;
      }
      y += 14;
    }
    y += 6;
    segments.push({ kind: 'divider', y });
    y += 16;
  }

  segments.push({ kind: 'footer', text: '这是一年留学生活留下的日记。', y });
  y += bodySize * lineHeight;
  const H = y + margin;

  // Second pass: actually render.
  const canvas = document.createElement('canvas');
  canvas.width = W;
  canvas.height = H;
  const ctx = canvas.getContext('2d');

  // Background gradient (matches game)
  const bg = ctx.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#2a2520');
  bg.addColorStop(1, '#1a1612');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // Subtle noise (very light) — skipped for performance, the gradient alone is fine.

  for (const seg of segments) {
    switch (seg.kind) {
      case 'title':
        ctx.fillStyle = '#e8e0d0';
        ctx.font = `300 ${titleSize}px ${fontSerif}`;
        ctx.fillText(seg.text, margin, seg.y + titleSize);
        break;
      case 'subtitle':
        ctx.fillStyle = 'rgba(232, 224, 208, 0.5)';
        ctx.font = `${bodySize}px ${fontMono}`;
        ctx.fillText(seg.text, margin, seg.y + bodySize);
        break;
      case 'section':
        ctx.fillStyle = seg.color;
        ctx.font = `${sectionSize}px ${fontSerif}`;
        ctx.fillText(seg.text, margin, seg.y + sectionSize);
        break;
      case 'entry-title':
        ctx.fillStyle = '#e8e0d0';
        ctx.font = `${entryTitleSize}px ${fontSerif}`;
        ctx.fillText(seg.text, margin, seg.y + entryTitleSize);
        break;
      case 'entry-body':
        ctx.fillStyle = 'rgba(232, 224, 208, 0.85)';
        ctx.font = `${bodySize}px ${fontSerif}`;
        ctx.fillText(seg.text, margin, seg.y + bodySize);
        break;
      case 'divider':
        ctx.strokeStyle = 'rgba(232, 224, 208, 0.18)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(margin, seg.y);
        ctx.lineTo(W - margin, seg.y);
        ctx.stroke();
        break;
      case 'footer':
        ctx.fillStyle = 'rgba(232, 224, 208, 0.45)';
        ctx.font = `italic ${bodySize}px ${fontSerif}`;
        ctx.fillText(seg.text, margin, seg.y + bodySize);
        break;
    }
  }

  return new Promise((resolve) => {
    canvas.toBlob((blob) => resolve(blob), 'image/png');
  });
}

/**
 * Trigger a browser file download for a Blob.
 */
export function download(blob, filename) {
  if (!blob) return;
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
