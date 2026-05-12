import { describe, test, expect } from 'vitest';
import {
  LINK2UR_CROSSOVERS,
  getEligibleCrossovers,
} from '../src/data/link2urCrossover.js';

describe('Link2Ur 6 条跨圈联动事件', () => {
  test('恰好 6 条', () => {
    expect(LINK2UR_CROSSOVERS.length).toBe(6);
  });

  test('每条有 trigger / narrative / choices (可选)', () => {
    for (const c of LINK2UR_CROSSOVERS) {
      expect(c.id).toMatch(/^cross_/);
      expect(typeof c.trigger).toBe('function');
      expect(c.narrative || c.scene).toBeTruthy();
    }
  });

  test('Paul BBC 在列表', () => {
    const ids = LINK2UR_CROSSOVERS.map((c) => c.id);
    expect(ids).toContain('cross_yjie_paul_bbc');
  });

  test('getEligibleCrossovers 按 state 过滤', () => {
    const mockState = {
      day: 7 * 38,
      link2urCompleted: new Array(25).fill('x'),
      link2urRepeatCustomers: { cust_paul: { count: 5, relationship: 'fan_unlocked' } },
      flags: {},
      npcRel: { wangkai: 6, mei: 5, whitmore: 5, aditi: 6 },
    };
    const eligible = getEligibleCrossovers(mockState);
    expect(eligible.some((c) => c.id === 'cross_yjie_paul_bbc')).toBe(true);
  });
});
