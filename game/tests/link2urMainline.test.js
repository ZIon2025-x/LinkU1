import { describe, test, expect } from 'vitest';
import {
  LINK2UR_CHAPTERS,
  getActiveChapter,
} from '../src/data/link2urMainline.js';

describe('Link2Ur 9 章主线', () => {
  test('恰好 9 章', () => {
    expect(LINK2UR_CHAPTERS.length).toBe(9);
  });

  test('每章有 chapterId / weekStart / weekEnd / events', () => {
    for (const c of LINK2UR_CHAPTERS) {
      expect(c.chapterId).toMatch(/^link2ur_ch\d/);
      expect(typeof c.weekStart).toBe('number');
      expect(typeof c.weekEnd).toBe('number');
      expect(Array.isArray(c.events)).toBe(true);
    }
  });

  test('Ch 1 在 W2-W7', () => {
    const ch1 = LINK2UR_CHAPTERS[0];
    expect(ch1.weekStart).toBe(2);
    expect(ch1.weekEnd).toBe(7);
  });

  test('Ch 4 Sketch 邀请在 W21-22', () => {
    const ch4 = LINK2UR_CHAPTERS[3];
    expect(ch4.weekStart).toBe(21);
    expect(ch4.weekEnd).toBe(22);
  });

  test('Ch 9 W48-52', () => {
    const ch9 = LINK2UR_CHAPTERS[8];
    expect(ch9.weekStart).toBe(48);
    expect(ch9.weekEnd).toBe(52);
  });

  test('getActiveChapter 按 day 取章', () => {
    expect(getActiveChapter(7 * 3).chapterId).toBe('link2ur_ch1');  // W3
    expect(getActiveChapter(7 * 22).chapterId).toBe('link2ur_ch4');  // W22
    expect(getActiveChapter(7 * 51).chapterId).toBe('link2ur_ch9');  // W51
  });
});
