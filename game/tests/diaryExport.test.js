import { describe, test, expect } from 'vitest';
import { collectEntries, toMarkdown } from '../src/engine/diaryExport.js';

describe('diary export · collectEntries', () => {
  test('shapes 4 buckets from raw state', () => {
    const out = collectEntries({
      diaryChoices: [{ title: 'BRP', line: '今天就去', day: 5, week: 1 }],
      dreams: [{ title: '梦 1', body: '一段梦' }],
      insomnias: [{ title: '失眠 1', body: '凌晨 3 点' }],
      nostalgias: [{ title: '想家 1', body: '红包' }],
    });
    expect(out.choice.length).toBe(1);
    expect(out.dream.length).toBe(1);
    expect(out.insomnia.length).toBe(1);
    expect(out.nostalgia.length).toBe(1);
    expect(out.choice[0].week).toBe(1);
  });

  test('handles missing inputs gracefully', () => {
    const out = collectEntries({});
    expect(out.choice).toEqual([]);
    expect(out.dream).toEqual([]);
    expect(out.insomnia).toEqual([]);
    expect(out.nostalgia).toEqual([]);
  });
});

describe('diary export · toMarkdown', () => {
  test('produces a non-empty markdown document with all sections', () => {
    const buckets = collectEntries({
      diaryChoices: [{ title: '加 CSSA', line: '"加" 选项', day: 14, week: 2 }],
      dreams: [{ title: '梦回出国前', body: '爸爸在检查箱子。' }],
      insomnias: [{ title: '凌晨刷分数', body: '3:14 你已经第 11 次刷新...' }],
      nostalgias: [{ title: '群里抢红包', body: '8 个红包，你一个都没抢到' }],
    });
    const md = toMarkdown(buckets);
    // top-level header
    expect(md).toMatch(/^# 异乡 · 我的留学日记/);
    // each section heading
    expect(md).toMatch(/## ◆ 我做过的决定/);
    expect(md).toMatch(/## ☾ 梦/);
    expect(md).toMatch(/## ☾ 失眠/);
    expect(md).toMatch(/## 🏮 想家/);
    // choice's week tag
    expect(md).toMatch(/_W2_/);
    // body text passes through
    expect(md).toContain('"加" 选项');
    expect(md).toContain('爸爸在检查箱子');
  });

  test('omits empty sections', () => {
    const buckets = collectEntries({ diaryChoices: [{ title: 'X', line: 'Y', day: 1, week: 1 }] });
    const md = toMarkdown(buckets);
    expect(md).toContain('## ◆ 我做过的决定');
    // no dream/insomnia/nostalgia headers
    expect(md).not.toContain('## ☾ 梦');
    expect(md).not.toContain('## ☾ 失眠');
    expect(md).not.toContain('## 🏮 想家');
  });

  test('includes meta week when provided', () => {
    const md = toMarkdown(collectEntries({}), { week: 26, totalWeeks: 52 });
    expect(md).toMatch(/第 26 \/ 52 周/);
  });

  test('output is deterministic save for the timestamp', () => {
    const buckets = collectEntries({
      diaryChoices: [{ title: 'a', line: 'A', day: 1, week: 1 }],
    });
    const a = toMarkdown(buckets);
    const b = toMarkdown(buckets);
    // strip the timestamps before comparing
    const stripDate = s => s.replace(/导出于 [^\n]+/g, '导出于 X');
    expect(stripDate(a)).toBe(stripDate(b));
  });
});
