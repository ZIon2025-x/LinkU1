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

describe('Ch 4 · Sketch 下午茶', () => {
  const ch4 = LINK2UR_CHAPTERS.find((c) => c.chapterId === 'link2ur_ch4');

  test('Ch 4 events 包含 Sketch 邀请 + Phase pivot', () => {
    const eventIds = ch4.events.map((e) => e.id);
    expect(eventIds).toContain('ch4_y_sketch_invite');
    expect(eventIds).toContain('ch4_phase_pivot');
  });

  test('Phase pivot 落在 W22 周末', () => {
    const pivot = ch4.events.find((e) => e.id === 'ch4_phase_pivot');
    expect(pivot.week).toBe(22);
  });
});

describe('Ch 5 · 第一步分化', () => {
  const ch5 = LINK2UR_CHAPTERS.find((c) => c.chapterId === 'link2ur_ch5');

  test('Ch 5 events 包含蓝瓶茶饮首单 + 团员招募 (Path B)', () => {
    const eventIds = ch5.events.map((e) => e.id);
    expect(eventIds).toContain('ch5_brand_tea_first');
    expect(eventIds).toContain('ch5_team_recruit_xiaoyu');
  });

  test('Solo 路径 Ch 5 选 niche 事件', () => {
    const ch5 = LINK2UR_CHAPTERS.find((c) => c.chapterId === 'link2ur_ch5');
    const nicheEvent = ch5.events.find((e) => e.id === 'ch5_solo_niche_choice');
    expect(nicheEvent).toBeTruthy();
    expect(nicheEvent.week).toBe(26);
  });
});

describe('Ch 6 · 复活节深化', () => {
  const ch6 = LINK2UR_CHAPTERS.find((c) => c.chapterId === 'link2ur_ch6');

  test('Omar 上线 W28', () => {
    const omarEvent = ch6.events.find((e) => e.id === 'ch6_omar_first');
    expect(omarEvent.week).toBe(28);
    expect(omarEvent.customerId).toBe('cust_omar');
  });

  test('复活节 capstone scene 引用', () => {
    const capstone = ch6.events.find((e) => e.sceneId === 'yjie_easter_capstone');
    expect(capstone).toBeTruthy();
  });
});

describe('Ch 7 · 论文期低维持', () => {
  const ch7 = LINK2UR_CHAPTERS.find((c) => c.chapterId === 'link2ur_ch7');

  test('陈一帆推 Whitmore W33 (跨圈联动)', () => {
    const chenEvent = ch7.events.find((e) => e.id === 'ch7_chen_recommends_whitmore');
    expect(chenEvent.week).toBe(33);
  });

  test('Paul BBC 采访 W38', () => {
    const paulEvent = ch7.events.find((e) => e.id === 'ch7_paul_bbc_interview');
    expect(paulEvent.week).toBe(38);
  });

  test('Aman clash W40', () => {
    const amanEvent = ch7.events.find((e) => e.id === 'ch7_aman_clash');
    expect(amanEvent.week).toBe(40);
  });

  test('王凯介绍 Eric W41', () => {
    const ericEvent = ch7.events.find((e) => e.id === 'ch7_wangkai_introduces_eric');
    expect(ericEvent.week).toBe(41);
  });
});
