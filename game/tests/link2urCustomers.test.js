import { describe, test, expect } from 'vitest';
import { LINK2UR_CUSTOMERS } from '../src/data/link2urCustomers.js';

describe('Link2Ur 8 个老客户 NPC', () => {
  test('恰好 8 个', () => {
    expect(LINK2UR_CUSTOMERS.length).toBe(8);
  });

  test('Phase 1 客户 3 个 / Phase 2 客户 3 个 / 跨阶段 2 个', () => {
    const phase1 = LINK2UR_CUSTOMERS.filter((c) => c.phase === 1);
    const phase2 = LINK2UR_CUSTOMERS.filter((c) => c.phase === 2);
    const cross = LINK2UR_CUSTOMERS.filter((c) => c.phase === 'both');
    expect(phase1.length).toBe(3);
    expect(phase2.length).toBe(3);
    expect(cross.length).toBe(2);
  });

  test('每个客户结构完整', () => {
    for (const c of LINK2UR_CUSTOMERS) {
      expect(c.id).toMatch(/^cust_/);
      expect(c.name).toBeTruthy();
      expect(c.avatar).toBeTruthy();
      expect(Array.isArray(c.affinityTypes)).toBe(true);
      expect(c.affinityTypes.length).toBeGreaterThan(0);
      expect([1, 2, 'both']).toContain(c.phase);
    }
  });

  test('id 全部唯一', () => {
    const ids = LINK2UR_CUSTOMERS.map((c) => c.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('Lily / Brand Tea / Paul 等关键客户存在', () => {
    const ids = LINK2UR_CUSTOMERS.map((c) => c.id);
    expect(ids).toContain('cust_lily');
    expect(ids).toContain('cust_brand_tea');
    expect(ids).toContain('cust_paul');
    expect(ids).toContain('cust_omar');
  });
});
