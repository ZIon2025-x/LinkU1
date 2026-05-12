import { describe, test, expect } from 'vitest';
import {
  detectClashes,
  shouldTriggerYInvitation,
} from '../src/engine/link2urSchedule.js';

describe('detectClashes · window 重叠检测', () => {
  test('无重叠 → 无 clash', () => {
    const inbox = [
      { id: 'a', mustCompleteByDay: 10, preferredTimeWindow: [9, 11] },
      { id: 'b', mustCompleteByDay: 10, preferredTimeWindow: [14, 16] },
    ];
    expect(detectClashes(inbox, 8)).toEqual([]);
  });

  test('同 day + window 重叠 → 1 个 clash', () => {
    const inbox = [
      { id: 'a', mustCompleteByDay: 10, preferredTimeWindow: [10, 14] },
      { id: 'b', mustCompleteByDay: 10, preferredTimeWindow: [12, 16] },
    ];
    const clashes = detectClashes(inbox, 8);
    expect(clashes.length).toBe(1);
    expect(clashes[0].taskA).toBe('a');
    expect(clashes[0].taskB).toBe('b');
  });

  test('两个 dueDay 都已过期 → 不算 clash (玩家已经 missed)', () => {
    const inbox = [
      { id: 'a', mustCompleteByDay: 5, preferredTimeWindow: [10, 14] },
      { id: 'b', mustCompleteByDay: 5, preferredTimeWindow: [12, 16] },
    ];
    expect(detectClashes(inbox, 8)).toEqual([]);
  });

  test('3 个任务两两重叠 → 3 个 clash', () => {
    const inbox = [
      { id: 'a', mustCompleteByDay: 10, preferredTimeWindow: [9, 14] },
      { id: 'b', mustCompleteByDay: 10, preferredTimeWindow: [11, 16] },
      { id: 'c', mustCompleteByDay: 10, preferredTimeWindow: [12, 17] },
    ];
    const clashes = detectClashes(inbox, 8);
    expect(clashes.length).toBe(3);
  });
});

describe('shouldTriggerYInvitation · 4 重 AND 条件', () => {
  const baseState = () => ({
    day: 21 * 7,  // W21 起
    link2urClashCount: 3,
    link2urRating: 4.7,
    link2urCompleted: new Array(18).fill('x'),
    link2urPhase: 1,
    flags: {},
  });

  test('全部满足 → true', () => {
    expect(shouldTriggerYInvitation(baseState())).toBe(true);
  });

  test('clash<3 → false', () => {
    const s = baseState(); s.link2urClashCount = 2;
    expect(shouldTriggerYInvitation(s)).toBe(false);
  });

  test('W20 → false (不到 W21)', () => {
    const s = baseState(); s.day = 20 * 7;
    expect(shouldTriggerYInvitation(s)).toBe(false);
  });

  test('rating<4.7 → false', () => {
    const s = baseState(); s.link2urRating = 4.6;
    expect(shouldTriggerYInvitation(s)).toBe(false);
  });

  test('完单<18 → false', () => {
    const s = baseState(); s.link2urCompleted = new Array(17).fill('x');
    expect(shouldTriggerYInvitation(s)).toBe(false);
  });

  test('Phase 已 = 2 → false (Y 姐已邀请过)', () => {
    const s = baseState(); s.link2urPhase = 2;
    expect(shouldTriggerYInvitation(s)).toBe(false);
  });

  test('已邀请 flag 设过 → false (不重发)', () => {
    const s = baseState(); s.flags = { l2u_y_invited: true };
    expect(shouldTriggerYInvitation(s)).toBe(false);
  });
});
