import { describe, test, expect, beforeEach } from 'vitest';
import { load, save, clear, hasSave } from '../src/engine/persistence.js';

// localStorage mock
beforeEach(() => {
  global.window = {
    localStorage: {
      _store: {},
      getItem(k) { return this._store[k] ?? null; },
      setItem(k, v) { this._store[k] = v; },
      removeItem(k) { delete this._store[k]; },
    },
  };
  clear();
});

describe('persistence migration · Link2Ur 创业线字段兜底', () => {
  test('旧存档 (无 Link2Ur 创业线字段) 加载后字段自动补全', () => {
    // 模拟旧 V4 存档,没有创业线字段
    const oldState = {
      day: 100,
      stats: { wallet: 500, energy: 60, academic: 50, belonging: 30 },
      link2urRating: 4.8,
      link2urCompleted: ['l2u_loon_fung-w5-0', 'l2u_brp-w4-1'],
      // ↑ 注意: 没有 link2urInbox / link2urPhase 等新字段
    };
    window.localStorage.setItem(
      'yixiang.save',
      JSON.stringify({ schema: 4, savedAt: Date.now(), state: oldState })
    );

    const loaded = load();

    expect(loaded).not.toBeNull();
    expect(loaded.day).toBe(100);  // 旧字段保留
    expect(loaded.link2urRepeatCustomers).toEqual({});  // 新字段补全
    expect(loaded.link2urInbox).toEqual([]);
    expect(loaded.link2urPhase).toBe(1);
    expect(loaded.link2urPath).toBe(null);
    expect(loaded.link2urTeamMembers).toEqual([]);
    expect(loaded.yjieRelationship).toBe(0);
  });

  test('schema=5 时也走 migrate (forward-compat 兜底)', () => {
    const newState = { day: 50, link2urPhase: 2, link2urInbox: [{ id: 'x' }] };
    window.localStorage.setItem(
      'yixiang.save',
      JSON.stringify({ schema: 5, savedAt: Date.now(), state: newState })
    );
    const loaded = load();
    expect(loaded).not.toBeNull();
    expect(loaded.day).toBe(50);
    expect(loaded.link2urPhase).toBe(2);
    expect(loaded.link2urInbox).toEqual([{ id: 'x' }]);
    expect(loaded.link2urRepeatCustomers).toEqual({});  // 仍补全缺失字段
  });

  test('schema < 4 时丢弃 (不兼容)', () => {
    window.localStorage.setItem(
      'yixiang.save',
      JSON.stringify({ schema: 3, savedAt: Date.now(), state: { day: 1 } })
    );
    const loaded = load();
    expect(loaded).toBeNull();
  });

  test('无存档时返回 null', () => {
    expect(load()).toBeNull();
  });

  test('损坏的 JSON 返回 null', () => {
    window.localStorage.setItem('yixiang.save', 'not valid json');
    expect(load()).toBeNull();
  });
});
