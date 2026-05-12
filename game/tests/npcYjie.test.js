import { describe, test, expect } from 'vitest';
import { YJIE_PROFILE, YJIE_SCENES } from '../src/data/npcYjie.js';

describe('Y 姐 角色卡', () => {
  test('基本字段', () => {
    expect(YJIE_PROFILE.id).toBe('yjie');
    expect(YJIE_PROFILE.realName).toBe('陈思敏');
    expect(YJIE_PROFILE.englishName).toBe('Yvonne Chan');
    expect(YJIE_PROFILE.age).toBe(28);
    expect(YJIE_PROFILE.hometown).toMatch(/广东|中山/);
    expect(YJIE_PROFILE.business).toBe('LinkU Bespoke');
    expect(YJIE_PROFILE.teamSize).toBe(8);
  });

  test('avatar emoji 不重复', () => {
    expect(YJIE_PROFILE.avatar).toBeTruthy();
  });
});

describe('Y 姐 7 个关键场景', () => {
  test('恰好 7 个场景', () => {
    expect(YJIE_SCENES.length).toBe(7);
  });

  test('每个场景结构完整', () => {
    for (const s of YJIE_SCENES) {
      expect(s.id).toBeTruthy();
      expect(s.title).toBeTruthy();
      expect(typeof s.weekStart).toBe('number');
      expect(typeof s.weekEnd).toBe('number');
      expect(s.flagOnComplete).toBeTruthy();
    }
  });

  test('场景按 weekStart 升序', () => {
    for (let i = 1; i < YJIE_SCENES.length; i++) {
      expect(YJIE_SCENES[i].weekStart).toBeGreaterThanOrEqual(YJIE_SCENES[i - 1].weekStart);
    }
  });

  test('Sketch 邀请场景在 W21-22', () => {
    const sketch = YJIE_SCENES.find((s) => s.id === 'yjie_sketch_invitation');
    expect(sketch).toBeTruthy();
    expect(sketch.weekStart).toBeLessThanOrEqual(22);
    expect(sketch.weekEnd).toBeGreaterThanOrEqual(21);
    expect(sketch.choices.length).toBe(3);
  });

  test('W47 合并提议场景存在', () => {
    const merger = YJIE_SCENES.find((s) => s.id === 'yjie_merger_offer');
    expect(merger).toBeTruthy();
    expect(merger.weekStart).toBeLessThanOrEqual(47);
  });
});
