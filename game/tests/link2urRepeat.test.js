import { describe, test, expect } from 'vitest';
import { initialState } from '../src/engine/state.js';
import {
  maybePromoteToRepeat,
  relationshipLevel,
} from '../src/engine/link2urRepeat.js';

describe('回头客关系阶梯', () => {
  test('relationshipLevel 阈值正确', () => {
    expect(relationshipLevel({ count: 0, rating: 5 })).toBe('none');
    expect(relationshipLevel({ count: 1, rating: 4.5 })).toBe('first_impression');
    expect(relationshipLevel({ count: 2, rating: 4.8 })).toBe('repeat_unlocked');
    expect(relationshipLevel({ count: 4, rating: 4.85 })).toBe('fan_unlocked');
    expect(relationshipLevel({ count: 6, rating: 4.9 })).toBe('loyal');
  });

  test('低评分不晋升 (count 够但 rating 不到)', () => {
    expect(relationshipLevel({ count: 6, rating: 4.4 })).toBe('none');
  });
});

describe('maybePromoteToRepeat', () => {
  test('完成单后 customer.count++', () => {
    const s = initialState();
    const next = maybePromoteToRepeat(s, {
      customerId: 'cust_lily',
      taskRating: 5,
      day: 50,
    });
    expect(next.link2urRepeatCustomers.cust_lily.count).toBe(1);
    expect(next.link2urRepeatCustomers.cust_lily.relationship).toBe('first_impression');
  });

  test('重复完成同 customer 累加 + 升级关系', () => {
    let s = initialState();
    for (let i = 1; i <= 2; i++) {
      s = maybePromoteToRepeat(s, {
        customerId: 'cust_lily',
        taskRating: 5,
        day: 50 + i,
      });
    }
    expect(s.link2urRepeatCustomers.cust_lily.count).toBe(2);
    expect(s.link2urRepeatCustomers.cust_lily.relationship).toBe('repeat_unlocked');
  });

  test('customerId 缺失时不报错, 返回原 state', () => {
    const s = initialState();
    const next = maybePromoteToRepeat(s, { taskRating: 5, day: 50 });
    expect(next).toBe(s);
  });
});
