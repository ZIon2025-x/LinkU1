# Link2Ur AI 广告创业线 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 game/ 项目里实现第 7 主线 "Link2Ur AI 广告创业线" — Y 姐(陈思敏) + 9 章 + Solo/Team 双路径 + Phase 1/2 双阶段 + 3 个新结局 + 4 个新机制 (回头客/Inbox/时效冲突/团队系统)。

**Architecture:** 数据驱动 (Vite + Vitest + React) — 新增 7 个 data/engine 文件,修改 6 个现有文件。机制通过 `state.js` reducer + 独立 helper 模块实现,叙事内容拆在 `link2urMainline.js` 9 章 + `npcYjie.js` 7 场景 + `link2urCustomers.js` 8 客户 + `link2urTeam.js` 5 团员。UI 在 `Link2UrView.jsx` 加 Inbox tab + Team panel + Phase Indicator。

**Tech Stack:** JavaScript (ES2022 modules), React 18, Vite 6, Vitest 2, Tailwind CSS

**Spec reference:** `game/docs/superpowers/specs/2026-05-12-link2ur-skill-entrepreneurship-line-design.md`

**约定:**
- 所有路径相对 `F:\python_work\LinkU\game\` 仓库根
- 测试用 Vitest, 已存在 `game/tests/*.test.js` 模式
- 每个 Task 末尾必须 commit (直推 main, solo 项目无 feature 分支)
- 测试用 `pnpm test` 或 `npm test` (项目 `package.json` 已配)

---

## Phase 0 · 准备 + 占位 NPC 重命名

### Task 0.1: 重命名占位 NPC `priya` → `yjie` + 写测试

**Files:**
- Modify: `game/src/engine/state.js:19-23` (INTERACTIVE_NPC_IDS 列表)
- Test: `game/tests/state.test.js` (新增 test)

- [ ] **Step 1: 看一眼 state.js 第 19-23 行确认现状**

```bash
sed -n '19,23p' game/src/engine/state.js
```

期望输出:
```
export const INTERACTIVE_NPC_IDS = [
  'sarah', 'aditi', 'wangkai', 'mei', 'whitmore', 'linnan', 'mark', 'tom', 'mom',
  'priya',  // Link2Ur Ops · 30 单后主动联系 → 招你做合伙人
];
```

- [ ] **Step 2: 写测试** — 在 `game/tests/state.test.js` 末尾追加

```javascript
import { INTERACTIVE_NPC_IDS } from '../src/engine/state.js';

describe('Y 姐 NPC ID', () => {
  test('uses yjie as the npc id (not priya placeholder)', () => {
    expect(INTERACTIVE_NPC_IDS).toContain('yjie');
    expect(INTERACTIVE_NPC_IDS).not.toContain('priya');
  });
});
```

- [ ] **Step 3: 跑测试看红**

```bash
npm test -- tests/state.test.js
```

Expected: FAIL (priya 还在,yjie 不在)

- [ ] **Step 4: 改 state.js**

将第 21 行 `'priya'` 改成 `'yjie'`, 注释更新:

```javascript
'yjie',  // Y 姐 / 陈思敏 / Yvonne Chan · Link2Ur 创业线 mentor · 30 单后主动 DM
```

- [ ] **Step 5: 跑测试看绿**

```bash
npm test -- tests/state.test.js
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add game/src/engine/state.js game/tests/state.test.js
git commit -m "$(cat <<'EOF'
refactor(game/state): priya 占位 → yjie (Link2Ur 创业线 mentor)

为第 7 主线 Y 姐(陈思敏)接入做准备。INTERACTIVE_NPC_IDS 中
原占位 'priya' 重命名为 'yjie',对齐 spec 里 npcId 字段。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 1 · 基础数据层 (state + migration + 2 个 helper 模块)

### Task 1.1: state.js 新增 10 个 Link2Ur 创业线字段

**Files:**
- Modify: `game/src/engine/state.js:24-130` (initialState 函数)
- Test: `game/tests/state.test.js`

- [ ] **Step 1: 写测试** — 在 `state.test.js` 加新 describe

```javascript
import { initialState } from '../src/engine/state.js';

describe('Link2Ur 创业线 state 字段 (v2 spec)', () => {
  const s = initialState();

  test('回头客追踪字段存在', () => {
    expect(s.link2urRepeatCustomers).toEqual({});
  });

  test('指定任务 inbox 初始为空数组', () => {
    expect(s.link2urInbox).toEqual([]);
  });

  test('时效冲突计数 + 历史初始化', () => {
    expect(s.link2urClashCount).toBe(0);
    expect(s.link2urClashEvents).toEqual([]);
  });

  test('路径选择字段初始为 null', () => {
    expect(s.link2urPath).toBe(null);
    expect(s.link2urPathDecidedDay).toBe(null);
  });

  test('Phase 字段初始为 1', () => {
    expect(s.link2urPhase).toBe(1);
    expect(s.link2urPhaseShiftDay).toBe(null);
  });

  test('Team 状态字段', () => {
    expect(s.link2urTeamMembers).toEqual([]);
    expect(s.link2urTeamRevenue).toBe(0);
  });

  test('Y 姐关系字段', () => {
    expect(s.yjieRelationship).toBe(0);
    expect(s.yjieChapter).toBe(0);
  });
});
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/state.test.js -t "Link2Ur 创业线 state 字段"
```

Expected: FAIL (字段都不存在)

- [ ] **Step 3: 改 state.js initialState** — 在现有 `link2urRejected: []` (约第 108 行) 之后添加

```javascript
// ── Link2Ur 创业线 (第 7 主线, v2 AI 广告方向) ──
// 回头客追踪 (key=customerId, value={count, lastTaskDay, relationship, phase})
link2urRepeatCustomers: {},
// 指定任务 inbox (绕过 board, customer 主动发)
link2urInbox: [],
// 时效冲突累积 + 历史
link2urClashCount: 0,
link2urClashEvents: [],
// 路径选择 (Ch 4 W22 Sketch 邀请后定): null / 'solo' / 'team' / 'undecided'
link2urPath: null,
link2urPathDecidedDay: null,
// 双阶段 (Ch 4 W22 Phase 1→2 不可逆 pivot)
link2urPhase: 1,
link2urPhaseShiftDay: null,
// Team 路径状态
link2urTeamMembers: [],  // [{ memberId, joinedDay, specialty, energy, completed, cutPercent, status }]
link2urTeamRevenue: 0,
// Y 姐 (陈思敏) 关系 + 章节进度
yjieRelationship: 0,
yjieChapter: 0,
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/state.test.js -t "Link2Ur 创业线 state 字段"
```

Expected: PASS (7 tests)

- [ ] **Step 5: 跑全套 state 测试确认无回归**

```bash
npm test -- tests/state.test.js
```

Expected: 所有原有测试 + 8 个新测试 全 PASS

- [ ] **Step 6: Commit**

```bash
git add game/src/engine/state.js game/tests/state.test.js
git commit -m "$(cat <<'EOF'
feat(game/state): 加 10 个 Link2Ur 创业线字段 (第 7 主线 v2)

- link2urRepeatCustomers / Inbox / ClashCount + Events (4 机制基础)
- link2urPath + Phase + PhaseShiftDay (双路径 + 双阶段)
- link2urTeamMembers / TeamRevenue (Team 路径)
- yjieRelationship / yjieChapter (Y 姐角色)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 1.2: persistence.js 改"schema 不符就丢弃"为"按字段 migrate"

**Files:**
- Modify: `game/src/engine/persistence.js` (load 函数 + 加 migrate)
- Test: `game/tests/persistence.test.js` (新建)

- [ ] **Step 1: 写测试** — 新建 `game/tests/persistence.test.js`

```javascript
import { describe, test, expect, beforeEach, vi } from 'vitest';

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
});

describe('persistence migration · Link2Ur 创业线字段兜底', () => {
  test('旧存档 (无 Link2Ur 创业线字段) 加载后字段自动补全', async () => {
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

    const { load } = await import('../src/engine/persistence.js');
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

  test('schema=5 时也走 migrate (forward-compat 兜底)', async () => {
    const newState = { day: 50, link2urPhase: 2, link2urInbox: [{ id: 'x' }] };
    window.localStorage.setItem(
      'yixiang.save',
      JSON.stringify({ schema: 5, savedAt: Date.now(), state: newState })
    );
    const { load } = await import('../src/engine/persistence.js');
    const loaded = load();
    expect(loaded.day).toBe(50);
    expect(loaded.link2urPhase).toBe(2);
    expect(loaded.link2urInbox).toEqual([{ id: 'x' }]);
    expect(loaded.link2urRepeatCustomers).toEqual({});  // 仍补全缺失字段
  });
});
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/persistence.test.js
```

Expected: FAIL (load 函数当前 schema mismatch 直接 return null)

- [ ] **Step 3: 改 persistence.js** — 整文件替换为:

```javascript
// localStorage save/load. Game state is the single source of truth, so we
// just JSON-serialize it. Schema version lets us migrate forward.

const KEY = 'yixiang.save';
const SCHEMA = 5;  // bump (V5: Link2Ur 创业线 v2 字段)

// ── Migration · 加 Link2Ur 创业线字段兜底 ──
// 旧存档 (V4 及之前) 加载时通过此函数补全缺失字段,而非整个丢弃。
function migrateLinkU(state) {
  return {
    ...state,
    link2urRepeatCustomers: state.link2urRepeatCustomers || {},
    link2urInbox: state.link2urInbox || [],
    link2urClashCount: state.link2urClashCount || 0,
    link2urClashEvents: state.link2urClashEvents || [],
    link2urPath: state.link2urPath ?? null,
    link2urPathDecidedDay: state.link2urPathDecidedDay ?? null,
    link2urPhase: state.link2urPhase || 1,
    link2urPhaseShiftDay: state.link2urPhaseShiftDay ?? null,
    link2urTeamMembers: state.link2urTeamMembers || [],
    link2urTeamRevenue: state.link2urTeamRevenue || 0,
    yjieRelationship: state.yjieRelationship || 0,
    yjieChapter: state.yjieChapter || 0,
  };
}

export function save(state) {
  if (typeof window === 'undefined') return;
  try {
    const payload = { schema: SCHEMA, savedAt: Date.now(), state };
    window.localStorage.setItem(KEY, JSON.stringify(payload));
  } catch (e) { /* quota / private mode — silently skip */ }
}

export function load() {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    // V4+ 都走 migrate 兜底,只有更老的不兼容 schema 才丢弃
    if (parsed.schema < 4) return null;
    return migrateLinkU(parsed.state);
  } catch (e) { return null; }
}

export function clear() {
  if (typeof window === 'undefined') return;
  try { window.localStorage.removeItem(KEY); } catch (e) { /* ignore */ }
}

export function hasSave() {
  if (typeof window === 'undefined') return false;
  try { return !!window.localStorage.getItem(KEY); } catch (e) { return false; }
}
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/persistence.test.js
```

Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add game/src/engine/persistence.js game/tests/persistence.test.js
git commit -m "$(cat <<'EOF'
feat(game/persistence): schema V5 + Link2Ur 创业线字段 migration

V4 → V5 不丢弃,通过 migrateLinkU() 补全缺失字段。
旧存档加载后 link2urPhase=1, link2urInbox=[] 等新字段自动归位,
玩家从 Ch 1 起跳。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 1.3: 新建 `link2urRepeat.js` (回头客系统)

**Files:**
- Create: `game/src/engine/link2urRepeat.js`
- Test: `game/tests/link2urRepeat.test.js`

- [ ] **Step 1: 写测试** — 新建 `game/tests/link2urRepeat.test.js`

```javascript
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
    expect(relationshipLevel({ count: 6, rating: 4.4 })).toBe('first_impression');
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
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/link2urRepeat.test.js
```

Expected: FAIL (module 不存在)

- [ ] **Step 3: 创建 `game/src/engine/link2urRepeat.js`**

```javascript
// Link2Ur 创业线 · 回头客关系递进
//
// 玩家完成任务后调用 maybePromoteToRepeat(state, completedTask),
// 维护 state.link2urRepeatCustomers map。
// 关系阶梯: none → first_impression → repeat_unlocked → fan_unlocked → loyal
//
// 阈值 (spec §4.1):
//   1 单 + 评分≥4.5  → first_impression
//   2 单 + 评分≥4.8  → repeat_unlocked  (解锁 inbox 任务)
//   4 单 + 评分≥4.8  → fan_unlocked     (解锁专属对话)
//   6 单 + 评分≥4.9  → loyal            (触发独家事件)

const TIERS = [
  { name: 'loyal',            minCount: 6, minRating: 4.9 },
  { name: 'fan_unlocked',     minCount: 4, minRating: 4.8 },
  { name: 'repeat_unlocked',  minCount: 2, minRating: 4.8 },
  { name: 'first_impression', minCount: 1, minRating: 4.5 },
];

export function relationshipLevel({ count = 0, rating = 0 } = {}) {
  for (const t of TIERS) {
    if (count >= t.minCount && rating >= t.minRating) return t.name;
  }
  return 'none';
}

// 完成任务后调用,可能晋升该 customer。返回新 state。
// completedTask: { customerId, taskRating, day }
export function maybePromoteToRepeat(state, completedTask) {
  const { customerId, taskRating, day } = completedTask || {};
  if (!customerId) return state;

  const prev = state.link2urRepeatCustomers[customerId] || {
    count: 0,
    lastTaskDay: 0,
    avgRating: 0,
    relationship: 'none',
  };

  const nextCount = prev.count + 1;
  // 移动平均评分
  const nextAvg = (prev.avgRating * prev.count + (taskRating || 5)) / nextCount;
  const nextRelationship = relationshipLevel({ count: nextCount, rating: nextAvg });

  return {
    ...state,
    link2urRepeatCustomers: {
      ...state.link2urRepeatCustomers,
      [customerId]: {
        count: nextCount,
        lastTaskDay: day,
        avgRating: Math.round(nextAvg * 100) / 100,
        relationship: nextRelationship,
      },
    },
  };
}
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/link2urRepeat.test.js
```

Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add game/src/engine/link2urRepeat.js game/tests/link2urRepeat.test.js
git commit -m "$(cat <<'EOF'
feat(game/link2ur): 回头客关系递进系统 (机制 A)

阶梯: none → first_impression → repeat_unlocked → fan_unlocked → loyal
玩家完单后由 maybePromoteToRepeat 维护 customer 累计 count + 移动平均 rating。
为 inbox 指定任务 (机制 B) 提供解锁信号。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 1.4: 新建 `link2urSchedule.js` (时效冲突检测)

**Files:**
- Create: `game/src/engine/link2urSchedule.js`
- Test: `game/tests/link2urSchedule.test.js`

- [ ] **Step 1: 写测试** — 新建 `game/tests/link2urSchedule.test.js`

```javascript
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
      { id: 'a', mustCompleteByDay: 10, preferredTimeWindow: [9, 13] },
      { id: 'b', mustCompleteByDay: 10, preferredTimeWindow: [11, 15] },
      { id: 'c', mustCompleteByDay: 10, preferredTimeWindow: [13, 17] },
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
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/link2urSchedule.test.js
```

Expected: FAIL (module 不存在)

- [ ] **Step 3: 创建 `game/src/engine/link2urSchedule.js`**

```javascript
// Link2Ur 创业线 · 时效冲突检测 + Y 姐邀请触发条件
//
// 机制 C (spec §4.3): inbox 中多个指定任务的 [preferredTimeWindow] 重叠
// 且未过期 → 触发 clash event,玩家三选一 (硬扛/拒一/拖延或转团员)
// Y 姐邀请触发: 撞档 ≥ 3 + W21+ + 评分 ≥ 4.7 + 完单 ≥ 18 + Phase==1 + 未邀

// 两个时间窗口是否重叠 ([a1, a2] 与 [b1, b2])
function windowOverlaps(a, b) {
  if (!a || !b || a.length !== 2 || b.length !== 2) return false;
  return a[0] < b[1] && b[0] < a[1];
}

// 输入 inbox 任务列表 + 当前 day, 返回冲突对数组
export function detectClashes(inbox, currentDay) {
  const clashes = [];
  const active = (inbox || []).filter(
    (t) => (t.mustCompleteByDay ?? Infinity) >= currentDay
  );
  for (let i = 0; i < active.length; i++) {
    for (let j = i + 1; j < active.length; j++) {
      const a = active[i], b = active[j];
      // 同日截止 (或者一日内)
      if (Math.abs((a.mustCompleteByDay || 0) - (b.mustCompleteByDay || 0)) > 1) continue;
      if (!windowOverlaps(a.preferredTimeWindow, b.preferredTimeWindow)) continue;
      clashes.push({
        taskA: a.id,
        taskB: b.id,
        severity: severityOf(a, b),
      });
    }
  }
  return clashes;
}

function severityOf(a, b) {
  // 简单的 severity = 两任务 reward 之和 (后续可加权)
  return (a.reward || 0) + (b.reward || 0);
}

// Ch 4 Y 姐 Sketch 邀请触发条件 (spec §4.3)
export function shouldTriggerYInvitation(state) {
  if (!state) return false;
  const week = Math.ceil((state.day || 0) / 7);
  return (
    (state.link2urClashCount || 0) >= 3 &&
    week >= 21 &&
    (state.link2urRating || 0) >= 4.7 &&
    (state.link2urCompleted?.length || 0) >= 18 &&
    state.link2urPhase === 1 &&
    !state.flags?.l2u_y_invited
  );
}
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/link2urSchedule.test.js
```

Expected: PASS (11 tests)

- [ ] **Step 5: Commit**

```bash
git add game/src/engine/link2urSchedule.js game/tests/link2urSchedule.test.js
git commit -m "$(cat <<'EOF'
feat(game/link2ur): 时效冲突检测 + Y 姐邀请触发条件 (机制 C)

detectClashes 检测 inbox 中两两 preferredTimeWindow 重叠的指定任务。
shouldTriggerYInvitation 实现 4 重 AND 条件 (撞档≥3 + W21+ +
rating≥4.7 + 完单≥18 + Phase==1 + 未邀) → Y 姐 Sketch DM。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 · NPC 角色数据 (Y 姐 + 8 客户 + 5 团员)

### Task 2.1: 新建 `npcYjie.js` (Y 姐角色卡 + 7 场景)

**Files:**
- Create: `game/src/data/npcYjie.js`
- Test: `game/tests/npcYjie.test.js`

- [ ] **Step 1: 写测试** — 新建 `game/tests/npcYjie.test.js`

```javascript
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
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/npcYjie.test.js
```

Expected: FAIL

- [ ] **Step 3: 创建 `game/src/data/npcYjie.js`** — 写完整的 7 场景对话树。**注意**: 每个场景的 `body` + `choices[i].label` + `choices[i].feedback` 都要写完整文本,不是 placeholder。参考现有 `link2urFriends.js` 里 narrative 的写法。

```javascript
// Y 姐 / 陈思敏 / Yvonne Chan
//
// 第 7 主线 mentor NPC, AI 广告创业线引路人。
// 8 人达人团队 LinkU Bespoke 创始人, 私人定制旅行 niche。
// 通过 inbox DM 在 Ch 4 W22 邀请玩家;后续 7 个场景串起 9 章。

export const YJIE_PROFILE = {
  id: 'yjie',
  realName: '陈思敏',
  englishName: 'Yvonne Chan',
  age: 28,
  hometown: '广东中山',
  education: 'UCL MSc Tourism & Heritage',
  yearsPostgrad: 6,
  visaStatus: 'ILR pending',
  business: 'LinkU Bespoke',
  businessTagline: '私人定制旅行',
  teamSize: 8,
  pricePoint: '£400-600/day',
  avatar: '💼',
  avatarColor: '#a855f7',
  toneSamples: [
    '呢单嘢值唔值得做?算你 LTV, 三个月入 12 单。OK 嘅。',
    'Don\'t say sorry. Say thank you. Sorry 系 client side 嘅嘢, 你而家 vendor side。',
    '撑住吖。论文写完你就识乜嘢叫 freedom。',
    '你做的留学生级别的作品 我看了。技术上可以做品牌级, 但你一个人接不过来。',
  ],
};

// 7 个关键场景 (spec §5.2)
// 每个场景被 link2urMainline.js 引用为章节关键节点
export const YJIE_SCENES = [
  // 场景 1 · Ch 4 W22 · Sketch 邀请 + Phase pivot
  {
    id: 'yjie_sketch_invitation',
    chapter: 4,
    weekStart: 21,
    weekEnd: 22,
    title: 'Sketch · 那个 pink room',
    triggerFlag: 'l2u_y_invited',  // 触发条件: shouldTriggerYInvitation === true 时设
    flagOnComplete: 'l2u_y_sketch_done',
    body: `周六上午 11 点。Sketch 餐厅那个粉色房间。

你按地址进去, 一个穿米色 trench coat、Mulberry tote 摆在椅背上的女生抬头看你。
她面前桌上摆着一杯黑咖、一杯燕麦拿铁、自己印的 menu booklet。

"过嚟。我系 Y。" 她切到普通话 + 港式: "唔知你饮咩, 都点咗。"

她翻开 booklet 第一页 — 是 LinkU Bespoke 团队 8 个人的合影。
"我五年前 UCL Tourism MSc 毕业那年留下来的。第一单 £20 带个交换生逛 Borough Market。
你这两个月的曲线, 比当年的我陡。"

她合上 booklet, 看着你: "我之所以约你, 不是为咗 random 嘅好奇。
我嘅高净值客户订完旅游后系要喺 IG / 小红书度晒。AI 内容包系 missing piece。
我团队冇人识做。你识。"

"想搞唔搞一个 team?"`,
    choices: [
      {
        label: '"我想试 team。" — 加入 Path B',
        effect: {
          stats: { belonging: 8 },
          npc: { yjie: 4 },
          flag: 'link2urPath_team',
          phasePivot: 2,  // Phase 1 → 2 不可逆
        },
        feedback: `Y 姐眨了一下眼。"OK。下周我介绍我学妹小雨给你, 你哋自己谈。
唔好以为我塞人。佢系 KCL 应用语言学 MA, 双语本地化嘅 talent。睇你 fit 唔 fit。"

她结账时拿出一张名片: "我电话, 24/7。你 panic 嗰阵就打。"
名片正面 minimalist 设计, 反面手写了三行: "1. 客户开心 你就开心  2. 收钱要爽  3. 唔好 burnout"

你回去 tube 上想: 这一年我可能要 reshape 自己。`,
      },
      {
        label: '"我想试 Solo。" — 委婉拒绝 Path A',
        effect: {
          stats: { belonging: 4 },
          npc: { yjie: 2 },
          flag: 'link2urPath_solo',
          phasePivot: 2,  // Phase 仍升级,玩家自己承接品牌单
        },
        feedback: `Y 姐想了 3 秒。"OK。我尊重你嘅 choice。"

她从 tote 里抽出一张她的 LinkedIn QR: "Solo 都有 Solo 嘅活法。
你如果想 referral, 或者 panic, 随时 ping me。"

走出 Sketch, 你心里其实有点慌。但你知道:
你不是为了"加入 LinkU Bespoke" 才来读这个 MSc 的。`,
      },
      {
        label: '"让我想想。" — 限定接单, 暂留 undecided',
        effect: {
          stats: { belonging: 2 },
          npc: { yjie: 1 },
          flag: 'link2urPath_undecided',
          phasePivot: 2,
        },
        feedback: `Y 姐笑了。"OK lah, 不急。下周我团队有个 capstone 项目, 我 cc 你一封 email。
你睇下 — 唔做都唔紧要, 当 reference 都好。"

她临走说: "记住 — undecided 唔系 indecisive。
undecided 系 'I'll decide when I have more data'。OK?"`,
      },
    ],
  },

  // 场景 2 · Ch 5 W23-25 · Team 路径 · 介绍小雨
  {
    id: 'yjie_team_referral_xiaoyu',
    chapter: 5,
    weekStart: 23,
    weekEnd: 25,
    title: 'DM · "我学妹小雨想入行"',
    requireFlag: 'link2urPath_team',
    flagOnComplete: 'l2u_y_referred_first',
    body: `Y 姐 DM:

"小雨 — 李雨彤, KCL 应用语言学 MA Y1, 23 岁, 双语 perfect。
她最近想找 AI 文案的 internship, 我建议她先做 freelance 攒 portfolio。
你考虑唔考虑要 ta? 你定 cut percent, 我唔参与。

我介绍人嘅唯一条件: 唔 fit 就直接讲, 唔 fit 嘅人留喺 team 系 hurt 大家。"

附了她 LinkedIn + 一份小雨的 sample 中英文案 (你看完觉得 talent 真的不错)。`,
    choices: [
      {
        label: '"约她下周 Pret 聊。" — 招入团队',
        effect: {
          npc: { yjie: 2, xiaoyu: 1 },
          flag: 'l2u_team_recruited_xiaoyu',
          // ↑ reducer 在 setFlag 时检测后会把 xiaoyu 加进 link2urTeamMembers
        },
        feedback: `周三下午 Pret Tottenham Court Road。小雨穿运动外套, 没化妆。
她说话很慢, 用 "嗯, 我觉得..." 开头。
你跟她讲了三件事: 1. cut 18%  2. 第一单我会陪改  3. 你不喜欢可以随时退。

她说: "我想试。"

招进来了。Link2Ur 后台显示: Team size 1。
你心里的紧张比她还多。`,
      },
      {
        label: '"我先一个人再试一段。" — 推迟招人',
        effect: {
          npc: { yjie: 0 },
          flag: 'l2u_xiaoyu_deferred',
        },
        feedback: `你 DM 回 Y 姐: "学妹挺 talent 但我还没 ready。"

Y 姐: "OK。你 ready 嘅时候话我知。她不急, 我也不急。"

你接下来一个月评分 4.95, 但完单也只升了 4 单 — 一个人 capacity 明显 cap 了。`,
      },
    ],
  },

  // 场景 3 · Ch 5 W25-26 · Solo 路径 · check-in
  {
    id: 'yjie_solo_checkin',
    chapter: 5,
    weekStart: 25,
    weekEnd: 26,
    title: 'DM · "Solo 都有 Solo 嘅活法"',
    requireFlag: 'link2urPath_solo',
    flagOnComplete: 'l2u_y_solo_checkin',
    body: `Y 姐 DM:

"你嗰日 Sketch 拒咗我, 我其实挺欣赏。我哋呢一行做久咗, 见太多人冲住合伙就答应, 之后后悔。

我冇要约你 — 就一句: Solo 唔系一定走孤独路。Network 唔等於 team。
我团队有一个 referral 系统, 我推俾你, 你 cut 唔同 — 你做 Solo, 我推 referral, 大家 win。

唔急答, 自己睇 LinkedIn 加我。"

附上她 LinkedIn QR + 一份"Solo Pro 客户 Referral 协议草稿"PDF。`,
    choices: [
      {
        label: '"加 LinkedIn。" — 接受 referral 网络 (推荐选)',
        effect: { npc: { yjie: 2 }, flag: 'l2u_y_referral_network' },
        feedback: `你加了 Y 姐 LinkedIn。她的 profile 1.2k followers, 头像是她在 Sketch 那张。

她接受好友请求 30 秒后 DM: "Welcome to the network。下周第一个 referral 推给你 — Lily 推荐过你, 你应该已经熟。Carrie at 蓝瓶茶饮。"

你打开 inbox: 已经有了 — 蓝瓶茶饮 marketing director 找你做英国 launch。
Y 姐做了第一次桥, 没拿一分钱。`,
      },
      {
        label: '"谢谢, 我自己摸索一下。" — 完全独立',
        effect: { npc: { yjie: 1 }, flag: 'l2u_solo_full_independent' },
        feedback: `你 DM 回 Y 姐: "感谢, 我想自己摸索一阵。"

Y 姐: "OK lah。Don't be a stranger though。"

你接下来 3 个月的客户都靠 Lily / Marcus 自己介绍。慢, 但都是你自己接到的。`,
      },
    ],
  },

  // 场景 4 · Ch 6 W28-29 · 复活节 capstone
  {
    id: 'yjie_easter_capstone',
    chapter: 6,
    weekStart: 28,
    weekEnd: 29,
    title: '复活节 · Bespoke 客户行后 AI 内容包',
    flagOnComplete: 'l2u_y_easter_capstone_completed',
    body: `Y 姐 group chat (Team) 或 DM (Solo):

"4 月头我有个 Bespoke 大客户: 上海一对 finance 夫妇, 5 月飞英国 11 天蜜月。
我团队负责 itinerary + 私陪 + 米其林预订。
但客人提议: 'Could you guys also do the IG content for us?'

我哋唔做内容。所以我想 outsource 俾你。
£800, 1 周交付。内容包要求:
· 11 天每日 1 条短视频 (双语字幕)
· 5 张精修图 (Midjourney 后期)
· 1 篇小红书长图文 (3000 字 + 12 张图)
· 1 个 IG Highlights cover set"

附 brief 文档 + 客人的 vibe board (Cotswolds 田园 / 苏格兰高地 / 牛津学院)。`,
    choices: [
      {
        label: '"接 — 全包。"',
        effect: {
          stats: { wallet: 800, energy: -25, academic: -5 },
          npc: { yjie: 3 },
          flag: 'l2u_y_easter_capstone_completed',
          flag2: 'l2u_y_easter_capstone_quality_high',
        },
        feedback: `你 (+ Team 团员们) 4 天没合眼。但出来的东西自己都觉得震撼:
那条苏格兰高地的 30s 视频, Sora 生成的雾气画面里 overlay 客人的实拍片段, BGM 用了 Skye Boat Song。

客人收到的当天发了一条长 message: "I cried watching the Cotswolds reel. Thank you."
Y 姐转 forward 给你: "她说哭了。OK 系真嘅 OK。"

Y 姐当晚加 200 bonus: "你哋 deserve。"`,
      },
      {
        label: '"接 — 只做视频 + 图, 不做小红书。"',
        effect: {
          stats: { wallet: 500, energy: -15, academic: -2 },
          npc: { yjie: 2 },
          flag: 'l2u_y_easter_capstone_completed',
        },
        feedback: `你跟 Y 姐说: "小红书我现在还做不到那个 quality。我接前两个 deliverable。"

Y 姐: "Fair。"

3 天交付。客人喜欢。Y 姐说: "你诚实, 我 respect。"`,
      },
      {
        label: '"我这周复活节复习 / 实习 / 回国, 不接。"',
        effect: {
          stats: { wallet: 0, energy: 0 },
          npc: { yjie: -1 },
          flag: 'l2u_y_easter_capstone_declined',
        },
        feedback: `Y 姐: "OK。下次仲有机会。"

你过完复活节回到 London, 听说她最后是自己团队的 Chloe 用 ChatGPT 撑下来的, 客人 4 星不是 5 星。
Y 姐没怪你, 但你能感觉到她对 Chloe 比对你更亲了一点。`,
      },
    ],
  },

  // 场景 5 · Ch 7 W36-38 · 论文期 cameo
  {
    id: 'yjie_thesis_checkin',
    chapter: 7,
    weekStart: 36,
    weekEnd: 38,
    title: 'DM · "撑住吖。"',
    flagOnComplete: 'l2u_y_thesis_checkin',
    body: `凌晨 1:42。Senate House 7 楼。你正在改论文 Methodology 章节。
Link2Ur 弹一条 DM。

Y 姐: "撑住吖。论文写完你就识乜嘢叫 freedom。

我嗰阵 2020 年 lockdown 写嘅, 比你 worse — 图书馆全部 close, 我喺一个 6 平米嘅 ensuite 写咗 8 个月。 Submit 嘅嗰一日我哭咗 30 分钟。冇人陪。

你而家有 inbox 一堆人等你。我建议: 论文期把 inbox 关 2 周。
你 brand 已经有 trust, 客户唔会走。"`,
    choices: [
      {
        label: '"OK 我关 inbox 2 周。" — 听建议',
        effect: {
          stats: { academic: 8, belonging: 3 },
          npc: { yjie: 2 },
          flag: 'l2u_inbox_paused',
          flag2: 'l2u_y_thesis_checkin',
        },
        feedback: `你关了 inbox。第 4 天客人 Lily 通过 IG 私信你: "你 inbox 怎么关了 咩事?"
你: "论文 panic 中。"
Lily: "OK 我自己等。"

你 14 天后 submit, 论文 grade 75 (Distinction 边缘)。
你想: Y 姐讲嘅 freedom 系真嘅。`,
      },
      {
        label: '"谢谢, 但我自己 manage。" — 继续接单',
        effect: {
          stats: { energy: -5 },
          npc: { yjie: 1 },
          flag: 'l2u_y_thesis_checkin',
        },
        feedback: `Y 姐: "OK。但你 burnout 就发 SOS, 唔好硬撑。"

你这 2 周 inbox 没关, 但拒了 70% 的单。论文 grade 68, 不错但不是 distinction。`,
      },
    ],
  },

  // 场景 6 · Ch 8 W45-47 · 🔴 合并提议 (核心场景)
  {
    id: 'yjie_merger_offer',
    chapter: 8,
    weekStart: 45,
    weekEnd: 47,
    title: 'Sketch 二访 · "客户复用 cross-sell"',
    flagOnComplete: 'l2u_y_merger_offered',
    body: `周六上午 11 点。还是 Sketch 那个 pink room。
Y 姐穿同一件米色 trench (你心想她可能就买了一件)。

她今天没准备 menu booklet。她准备了一张 napkin, 上面手写了一个数字模型:

  LinkU Bespoke 客户 = 220 个 / 年 · 客单 £4500 平均
  + Player AI Studio = 假设并入 = 全部客户 +£1500 行后 IG/小红书内容包
  = ARR 增量 £33万

她推过来: "我哋共用客户。我服务旅游, 你服务内容。同一批人, 两次买单, 两次值钱。
合并条款我大概想咗:
· 你嘅 brand 保留为 LinkU Bespoke 嘅 'AI Content Atelier' sub-brand
· 你嘅团队全部并入, 我 100% 不动你嘅 cut 结构
· 我哋 founding share 70/30, 你 30
· 你嘅人喺品牌内独立 budget, 我唔 micromanage"

她喝了一口 cappuccino: "下午茶我请, 但 Decision Day 系一周后。"`,
    choices: [
      {
        label: '"我接受合并。"',
        effect: {
          stats: { belonging: 12, wallet: 0 },
          npc: { yjie: 5 },
          flag: 'l2u_y_merger_accepted',
          requireFlag: 'link2urPath_team',
        },
        feedback: `Y 姐点头, 没大声说什么。但她把那张 napkin 折起来放进 tote。
"OK。下周我律师会发 LOI 草稿。"

走出 Sketch 的时候她突然停下来回头: "其实我 nervous 咗 4 个晚上你会唔会答应。
真嘅 — 你嘅 work 系我团队冇人识做嘅。"

你坐 Tube 回去, 心跳一直没平复。
今天下午, 妈妈电话: "你王阿姨女儿选调上岸了 25w + 户口..."
你: "妈, 我今天上午签了一个合伙人。"

她在电话那头沉默了 8 秒。然后: "...真的？"
"真的。"
"...好。妈支持你。"`,
      },
      {
        label: '"我不接受合并 — 我想独立。"',
        effect: {
          stats: { belonging: 6 },
          npc: { yjie: 2 },
          flag: 'l2u_y_merger_declined_independent',
          requireFlag: 'link2urPath_team',
        },
        feedback: `Y 姐看了你 3 秒。然后她把 napkin 收起来, 没说什么。
她笑了: "OK。你年轻 你应该试试自己。"

"五年后如果你想合并 我还在这里。If we're both still here. And if AI hasn't replaced both of us by then."

走出 Sketch 你松了一口气, 也有点 regret 的预感。
但你知道: 你不是为了"被 Y 姐 acquire" 而努力。`,
      },
      {
        label: '"我想散伙 Team, 回到 Solo。"',
        effect: {
          stats: { belonging: -3, wallet: -200 },
          npc: { yjie: 0 },
          flag: 'l2u_y_merger_team_disbanded',
          requireFlag: 'link2urPath_team',
        },
        feedback: `Y 姐听完没说什么。她说: "OK。Team 解散嘅原因系...你想 Solo? 定系你觉得呢条 team 路走唔通?"

你: "...都有。"

她叹气: "Solo 比 team 更难, 但你可以试。你嘅团员我 inbox 接住, 给佢哋开新的 chapter。"

(后续触发: 团员散场场景, 玩家 wallet 损失 £200 用于 severance, 团员 status 转 'departed_yjie')`,
      },
      {
        label: 'Solo 路径分支 · "我做你 Bespoke 独家 AI 供应商"',
        effect: {
          stats: { belonging: 8, wallet: 200 },
          npc: { yjie: 3 },
          flag: 'l2u_solo_consultant',
          requireFlag: 'link2urPath_solo',
        },
        feedback: `Y 姐: "OK。咁我哋系合作 partner, 唔系合伙。你 invoice me。"

你签了一份 retainer: £200 × 220 个客户/年 = £44000 baseline + bonus。
这是 Solo 路径最优解 — 你不被并购但有稳定 cashflow。`,
      },
    ],
  },

  // 场景 7 · Ch 9 W51-52 · 毕业典礼前最后一面
  {
    id: 'yjie_farewell',
    chapter: 9,
    weekStart: 51,
    weekEnd: 52,
    title: 'Royal Festival Hall 旁 · 最后一杯咖啡',
    flagOnComplete: 'l2u_y_farewell',
    body: `毕业典礼前一天。Royal Festival Hall 旁那家不出名的精品咖啡店。
Y 姐已经到了, 这次穿了一件你没见过的颜色: 深绿色丝绒外套。
她说: "今日唔系工作日。"

她从 tote 里抽出一个小礼物盒。`,
    choices: [
      {
        label: '【展开】 Y 姐说了什么',
        effect: {
          stats: { belonging: 8 },
          npc: { yjie: 3 },
          flag: 'l2u_y_farewell',
        },
        feedback: `不同 path 不同对白 (由 link2urMainline.js Ch 9 引用,根据 link2urPath + merger_decision 分支):

【合并】 "Welcome partner。Real partner。" 礼物是一张 LinkU Bespoke + AI Studio 的双联名 brand 草稿。

【独立 Team】 "你嘅 brand 我 5 年内 reference 给 220 个客户。我 promise。" 礼物是她团队 8 个人手写的明信片。

【Solo Apex】 "I might call you in 3 years if I'm ready to be acquired." 礼物是她第一年接的那只 Borough Market 5 镑充电宝, 装了一封手写信。

【Solo Consultant】 "下年我哋每周一次 strategy call, OK?" 礼物是一本 Y 姐 5 年来的产品手记 (复印件)。`,
      },
    ],
  },
];
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/npcYjie.test.js
```

Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add game/src/data/npcYjie.js game/tests/npcYjie.test.js
git commit -m "$(cat <<'EOF'
feat(game/data): Y 姐 (陈思敏) 角色卡 + 7 个关键场景

第 7 主线 mentor NPC, AI 广告创业线引路人。
7 场景: Sketch 邀请 / Team 介绍小雨 / Solo check-in /
复活节 capstone / 论文期 cameo / W47 合并提议 / 毕业前告别。

每个场景含完整 body + 2-4 choices + effect/flag/feedback。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2.2: 新建 `link2urCustomers.js` (8 个老客户 NPC)

**Files:**
- Create: `game/src/data/link2urCustomers.js`
- Test: `game/tests/link2urCustomers.test.js`

- [ ] **Step 1: 写测试** — 验证 8 客户结构

```javascript
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
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/link2urCustomers.test.js
```

- [ ] **Step 3: 创建 `game/src/data/link2urCustomers.js`** — 8 个完整客户数据

```javascript
// Link2Ur 8 个老客户 NPC (spec §5.3)
// 3 Phase 1 + 3 Phase 2 + 2 跨阶段

export const LINK2UR_CUSTOMERS = [
  // —— Phase 1 客户 (W2-W22 主力) ——
  {
    id: 'cust_lily',
    name: '王 Lily',
    fullName: 'Lily 王 (Wang Liyi)',
    age: 25,
    role: '留学网红 + Burberry 代购',
    avatar: '🎬',
    avatarColor: '#e879b8',
    phase: 1,  // Phase 1 起步, Ch 5 升级到 Phase 2 桥梁
    affinityTypes: ['ai_video_short', 'ai_copy_bilingual', 'ai_ig_content'],
    personality: '北京二代 / 30万 IG 粉 / Burberry 控 / 出差频繁',
    intro: 'Lily 是你 Phase 1 第一个 repeat 客户。AI 双语字幕做得好。',
    keyEvents: [
      { week: 8, event: '首次 inbox 指定单 (双语短视频 5 条)' },
      { week: 17, event: '被中资茶饮品牌相中签约, 是 Phase 1→2 关键桥梁' },
      { week: 50, event: '婚礼前邀玩家做 wedding planner cameo' },
    ],
  },
  {
    id: 'cust_jess',
    name: 'Jess Wong',
    fullName: 'Jess Wong (黄思敏)',
    age: 22,
    role: 'ABC + DTC 美妆店主理人',
    avatar: '💄',
    avatarColor: '#f472b6',
    phase: 1,
    affinityTypes: ['ai_visual_product', 'ai_copy_bilingual', 'ai_ig_content'],
    personality: '香港 ABC / IG-first / 自创美妆品牌',
    intro: 'Jess 想做"双语 listing + AI 产品图"内容。',
    keyEvents: [
      { week: 14, event: 'Christmas Gift Guide 视觉首单' },
      { week: 28, event: '邀玩家做品牌大使 (拍 IG 推广)' },
    ],
  },
  {
    id: 'cust_marcus_p1',
    name: 'Marcus',
    fullName: 'Marcus Okafor',
    age: 21,
    role: 'LSE + 留学生互助公众号主理人',
    avatar: '✊',
    avatarColor: '#7a6552',
    phase: 1,
    affinityTypes: ['ai_copy_bilingual', 'ai_visual_poster', 'ai_long_article'],
    personality: '同 diaspora kid / 公益项目多 / 反诈先锋',
    intro: 'Marcus 做留学生互助公众号, 找你做"留学生反诈"系列内容。',
    keyEvents: [
      { week: 10, event: '首单 (反诈双语长图文)' },
      { week: 23, event: '推荐 Paul 给你 — 跨圈联动 + Phase 2 客户引荐' },
    ],
  },

  // —— Phase 2 客户 (W23-W52 主力) ——
  {
    id: 'cust_brand_tea',
    name: 'Carrie · 蓝瓶茶饮',
    fullName: 'Carrie Lin · 蓝瓶茶饮 UK Marketing Director',
    age: 32,
    role: '中资茶饮品牌 进 UK · marketing director',
    avatar: '🍵',
    avatarColor: '#3b82f6',
    phase: 2,
    affinityTypes: ['ai_bilingual_campaign', 'ai_ads_meta', 'ai_xiaohongshu'],
    personality: '商业化 / 数据驱动 / 工作狂 / 工业风沟通',
    intro: '蓝瓶茶饮进 UK 第一个 marketing director。Lily 推荐你给她。',
    keyEvents: [
      { week: 23, event: '首个品牌单 £1200 (UK Launch Campaign)' },
      { week: 35, event: '升级年度合约 £15000 retainer' },
    ],
  },
  {
    id: 'cust_omar',
    name: 'Omar',
    fullName: 'Omar Al-Saud',
    age: 25,
    role: '迪拜留学 → 家族 startup CMO',
    avatar: '🏰',
    avatarColor: '#fbbf24',
    phase: 2,
    affinityTypes: ['ai_premium_creative', 'ai_arabic_english_localization', 'ai_video_long'],
    personality: '巨富 / 孤独 / 想 sponsor 你的 visa',
    intro: '家族 startup 出海, 玩家迄今最高客单 £1500。',
    keyEvents: [
      { week: 28, event: '家族 startup 出海素材 £1500' },
      { week: 45, event: '升级年度 £30k retainer (Ch 8 W47 合并提议关键论据)' },
    ],
  },
  {
    id: 'cust_paul',
    name: 'Paul Hartwell',
    fullName: 'Paul Hartwell · BBC 记者',
    age: 35,
    role: 'BBC 记者 / 工党左倾',
    avatar: '📰',
    avatarColor: '#9ca3af',
    phase: 2,
    affinityTypes: ['ai_long_article', 'ai_research_assist', 'ai_documentary_script'],
    personality: 'Hackney 公寓 / 离异 / 关注 AI 时代 immigrant labor',
    intro: '通过 Marcus 介绍。Phase 2 后期触发"BBC AI 时代 immigrant labor" 专题, 母题反思核心场景。',
    keyEvents: [
      { week: 23, event: '首单 (BBC 选题协助)' },
      { week: 38, event: '🔴 BBC 专题采访 — 玩家身份感悟时刻' },
    ],
  },

  // —— 跨阶段客户 (W2-W52 一直 work) ——
  {
    id: 'cust_grandma',
    name: '张奶奶',
    fullName: '张惠兰 (67, 伦敦养老)',
    age: 67,
    role: '老北京华侨 / 伦敦养老',
    avatar: '👵',
    avatarColor: '#fde68a',
    phase: 'both',
    affinityTypes: ['ai_video_short', 'ai_copy_bilingual', 'companion_chat'],
    personality: '老北京 / 老伴去年走了 / 寂寞 / 关心你的吃饭',
    intro: 'Phase 1 让你帮她发朋友圈双语视频问候孙女。Phase 2 加入她孙女的小生意。',
    keyEvents: [
      { week: 12, event: '首次让你陪她去看金毛 + 顺便发个朋友圈' },
      { week: 23, event: '介绍她孙女 (ABC 在伦敦开 boutique 茶店) 给你' },
    ],
  },
  {
    id: 'cust_chen',
    name: '陈一帆',
    fullName: '陈一帆 (26, PhD Y3)',
    age: 26,
    role: 'UCL 历史系 PhD Y3 → 学术机构 researcher',
    avatar: '📚',
    avatarColor: '#a3a3a3',
    phase: 'both',
    affinityTypes: ['ai_academic_proofread', 'ai_long_article', 'ai_research_assist'],
    personality: 'UCL 历史系 / 焦虑 / 论文马拉松式',
    intro: '论文校对老主顾。Phase 2 后引荐学术内容外包 → 推 Whitmore 给你 (Ch 7 W33 跨圈联动)。',
    keyEvents: [
      { week: 10, event: '首单 (论文 first chapter 校对)' },
      { week: 33, event: '推荐你给 Whitmore — 学术 AI 校对长期客户引荐' },
    ],
  },
];
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/link2urCustomers.test.js
```

- [ ] **Step 5: Commit**

```bash
git add game/src/data/link2urCustomers.js game/tests/link2urCustomers.test.js
git commit -m "$(cat <<'EOF'
feat(game/data): 8 个老客户 NPC (3 P1 + 3 P2 + 2 跨阶段)

Lily (网红) / Jess (ABC 美妆) / Marcus (LSE 公众号) — Phase 1 主力
Carrie 蓝瓶茶饮 / Omar (迪拜) / Paul (BBC) — Phase 2 主力
张奶奶 / 陈一帆 — 跨阶段陪伴客户

每个客户带 affinityTypes (回头客匹配) + keyEvents (章节关键节点)。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2.3: 新建 `link2urTeam.js` (5 个可招团员 NPC)

**Files:**
- Create: `game/src/data/link2urTeam.js`
- Test: `game/tests/link2urTeam.test.js`

- [ ] **Step 1: 写测试**

```javascript
import { describe, test, expect } from 'vitest';
import {
  LINK2UR_TEAM_MEMBERS,
  getMiniArcScene,
} from '../src/data/link2urTeam.js';

describe('5 个可招团员 NPC', () => {
  test('恰好 5 个', () => {
    expect(LINK2UR_TEAM_MEMBERS.length).toBe(5);
  });

  test('5 个专精全覆盖 AI 广告分工', () => {
    const specialties = LINK2UR_TEAM_MEMBERS.map((m) => m.specialty);
    expect(specialties).toContain('ai_copywriting_bilingual');
    expect(specialties).toContain('ai_video_generation');
    expect(specialties).toContain('ads_strategy_data');
    expect(specialties).toContain('account_management');
    expect(specialties).toContain('ai_visual_design');
  });

  test('每个团员有 4 个 mini-arc 场景', () => {
    for (const m of LINK2UR_TEAM_MEMBERS) {
      expect(m.miniArc.length).toBe(4);
      for (const a of m.miniArc) {
        expect(['recruited', 'mentored', 'clash', 'departure']).toContain(a.phase);
        expect(a.body).toBeTruthy();
      }
    }
  });

  test('Eric 标记需要王凯介绍', () => {
    const eric = LINK2UR_TEAM_MEMBERS.find((m) => m.id === 'team_eric');
    expect(eric.recruitedVia).toBe('wangkai_referral');
  });

  test('getMiniArcScene 按 phase 取场景', () => {
    const scene = getMiniArcScene('team_xiaoyu', 'recruited');
    expect(scene).toBeTruthy();
    expect(scene.body).toBeTruthy();
  });
});
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/link2urTeam.test.js
```

- [ ] **Step 3: 创建 `game/src/data/link2urTeam.js`** — 5 团员完整结构 + mini-arc。**注意**: 每个 mini-arc 4 阶段都要写完整 body 文本, 不是 placeholder。

```javascript
// Link2Ur Team 路径 · 5 个可招团员 NPC (spec §5.4)
// 每个团员的 mini-arc 4 节拍: recruited → mentored → clash → departure
//
// 玩家在 Ch 5/6/7/8 招人, 每个团员 specialty 在 AI 广告分工里独立。
// 5 个 specialty 合起来 = 完整 AI 广告 studio。

export const LINK2UR_TEAM_MEMBERS = [
  {
    id: 'team_xiaoyu',
    name: '小雨',
    realName: '李雨彤',
    age: 23,
    school: "King's College London",
    major: '应用语言学 MA',
    specialty: 'ai_copywriting_bilingual',
    specialtyDisplay: 'AI 文案 + 双语本地化',
    recruitedVia: 'aditi_referral',
    minWeek: 23,
    maxWeek: 26,
    baseRating: 4.6,
    baseEnergy: 80,
    cutPercent: 18,
    avatar: '🌸',
    miniArc: [
      {
        phase: 'recruited',
        title: '小雨 · Pret 面谈',
        body: `Pret Tottenham Court Road, 周三下午 2 点。
小雨穿米色运动外套, 没化妆, 头发梳得整齐但有点紧张。
她说话很慢, 用"嗯, 我觉得..." 开头。

你跟她讲三件事:
1. cut 18% (你拿 82%, 她拿 cut 后)
2. 第一单我会陪改
3. 不喜欢可以随时退

她说: "我想试。"`,
      },
      {
        phase: 'mentored',
        title: '小雨 · 第一单 · 蓝瓶茶饮 brand copy',
        body: `小雨第一单是 Carrie 给的 brand copy。她写了 3 个版本, 你帮她改第 4 个。
最后客户用了第 2 个 — 是小雨自己写的, 你没改。

她私聊你: "我以为客户会选你改过的那版。"
你: "客户不傻。"
她沉默了一下: "谢谢。"`,
      },
      {
        phase: 'clash',
        title: '小雨 · 第一次冲突 · 客户偏好你不偏好她',
        body: `Lily 上次单子明确说: "下次我希望你自己来, 不要 team 接。"
你转告小雨。她安静了一会儿。

她: "OK 我懂。是不是我做得不够好?"
你: "不是。客户和员工的 fit 不能强求。"

她那周完单数下降, 你能看出她在自我怀疑。`,
      },
      {
        phase: 'departure',
        title: '小雨 · 毕业 · PhD 申请书',
        body: `W50。小雨拿着 PhD 申请书来找你: "你能帮我写一封 reference letter 吗?
我想申回上海大学应用语言学 PhD, 做'AI 时代双语本地化'方向。"

你: "可以。但你的写作能力我都没指点过, 你是自己长起来的。我写什么?"
她笑了: "你 mentor 过我'客户不傻'。 写那个。"

你给她写了 1200 字的推荐信。
她毕业回上海的飞机上发你一张照片: 她在 Heathrow 的 Costa 喝最后一杯 latte。
"In London I learned how to listen to a client. Thank you 😊"`,
      },
    ],
  },
  {
    id: 'team_kenji',
    name: 'Kenji',
    realName: '健治',
    age: 24,
    school: 'Goldsmiths College',
    major: 'Media MA',
    specialty: 'ai_video_generation',
    specialtyDisplay: 'AI 视频生成 (Sora/Runway)',
    recruitedVia: 'linkedin_dm',
    minWeek: 27,
    maxWeek: 32,
    baseRating: 4.8,
    baseEnergy: 75,
    cutPercent: 22,
    avatar: '🎌',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Kenji · LinkedIn DM',
        body: `LinkedIn DM:
"Hi, I saw your portfolio. I'm Kenji, Goldsmiths Media MA Y1.
I do Sora + Runway commercial work. I want to apply for your team but I'm Japanese.
I think this can be your bridge to Japanese clients in London."

(他的 portfolio: 4 条 30s AI 视频, 1 条是 Tokyo Pop 风格 made with Sora。质量惊艳。)`,
      },
      {
        phase: 'mentored',
        title: 'Kenji · 美容品牌 30s spec',
        body: `Kenji 第一单是给一个香港美容品牌做 30s IG Reels。
他 1 天就交了。视频是 Sora 生成的雾气画面里 overlay 模特实拍片段, BGM 用了一段 80s 港片配乐。

客户: "我们做美容 10 年, 没见过这个 quality。"
Kenji: "I have done 4 versions before this one. The first 3 were... not me."

你才明白: AI 工具不是替代品。是磨刀。`,
      },
      {
        phase: 'clash',
        title: 'Kenji · 想回东京',
        body: `W42。Kenji 喝多了某次 team dinner 后跟你说:
"我妈昨天 video 我。她 72 了, 一个人在 Setagaya。
我想 maybe... 回东京继续做 freelance。
你 ok 吗?"

你说: "你想回就回。"
他: "But this team is mine too. I don't want to just leave."

你给他时间想。但你知道: 他可能要走了。`,
      },
      {
        phase: 'departure',
        title: 'Kenji · 回东京 / 留下',
        body: `W50。Kenji 给你两个选项:
A. 回东京, 在 Tokyo 继续做你的 freelance 合作伙伴 (远程)
B. 留下, 跟随合并 (如 Path B + 合并)

你尊重他的选择。无论选哪个, 他都给你寄了一份手写的 thank you letter + 一个 Tokyo Banana。`,
      },
    ],
  },
  {
    id: 'team_aman',
    name: 'Aman',
    realName: 'Aman Singh',
    age: 25,
    school: 'Imperial College',
    major: 'MEng',
    specialty: 'ads_strategy_data',
    specialtyDisplay: '广告投放 + 数据分析',
    recruitedVia: 'aditi_classmate',
    minWeek: 27,
    maxWeek: 36,
    baseRating: 4.5,
    baseEnergy: 90,
    cutPercent: 12,  // 最便宜
    avatar: '🇮🇳',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Aman · 最便宜 / 最 hungry',
        body: `Aditi 介绍。Aman 是 Imperial MEng Y2, 想转 ad-tech 副业。
他主动报了 £12/h cut (远低于其他团员)。

你: "为什么这么低?"
他: "I need experience more than money. Six months from now I'll be your most expensive person."

你看出他的野心。招进来。`,
      },
      {
        phase: 'mentored',
        title: 'Aman · 第一次 Meta ad campaign',
        body: `Aman 第一单: 蓝瓶茶饮 Meta launch campaign。
他设了 3 个 audience segment + 7 个 creative variants + 4 个 landing pages。
跑了 14 天, ROAS 4.2 (业内平均 1.8)。

Carrie 直接跟你说: "他 worth 你 cut 3 倍。"`,
      },
      {
        phase: 'clash',
        title: 'Aman · 🔴 "我做得多但 cut 一样"',
        body: `W40。Aman 跟你 1-on-1: "Look. I make you the most money in the team.
My ROAS for Carrie is 4.2. Chloe's account management is great but it's not the same.
£12/h cut is what I agreed when I had no leverage. Now I have. I want £22."

(玩家三选一:)
A. 涨到 £22 (Aman 留 + 你利润降)
B. 涨到 £18 (折衷, Aman 不爽但留)
C. 不涨 (Aman 1 周内自己离开)`,
      },
      {
        phase: 'departure',
        title: 'Aman · 取决于 clash 选择',
        body: `根据 W40 clash 选择 (玩家选 A/B/C):

A 涨 £22 → Aman 留到 W52, 跟随合并 (Path B) 或继续 Solo 合作 (Path A)
B 折衷 £18 → Aman 留到 W48 然后离开去 BCG ad-tech 部门
C 不涨 → Aman 离开。3 个月后他在 LinkedIn 写: "Founder integrity matters more than salary."
你看到那条 post 心里不是滋味。`,
      },
    ],
  },
  {
    id: 'team_chloe',
    name: 'Chloe',
    realName: '周婧',
    age: 22,
    school: 'KCL English Literature',
    major: 'BA',
    specialty: 'account_management',
    specialtyDisplay: '客户对接 + ABC 双向客户经理',
    recruitedVia: 'pret_encounter',
    minWeek: 30,
    maxWeek: 38,
    baseRating: 4.7,
    baseEnergy: 70,
    cutPercent: 20,
    avatar: '🎤',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Chloe · Pret 偶遇',
        body: `Pret Bedford Square 早上 8 点。你在改一份 brief。
旁边一个穿 Reformation 连衣裙的女生用粤语普通话英语三种打电话, 30 秒内切换 4 次。
她挂电话, 看见你的 MacBook 上是 LinkU brand brief。

"Sorry to be nosy. Is that for Carrie at 蓝瓶?"
你: "...你怎么知道?"
"我之前给她做过 freelance interpreter 一次。她说过她在找 AI 内容团队。"
她递过来一张名片。

招进来。她是 ABC, 父亲 BBC 父亲, 母亲香港 ABC, 她自己在 KCL 读 English Lit。`,
      },
      {
        phase: 'mentored',
        title: 'Chloe · Paul BBC 采访的协调员',
        body: `Paul 要采访你做 BBC 专题, 但他不会粤语, 他想顺便采访 Y 姐 + 中资客户群体。
Chloe 自告奋勇做 fixer。她 3 天内 lined up 8 个采访对象 + 2 个翻译 + 1 个录音师 + 现场协调。

Paul 后来跟你说: "She's the best fixer I've worked with in London in 7 years."`,
      },
      {
        phase: 'clash',
        title: 'Chloe · 客户 Lily 指名她',
        body: `Lily 通过 Chloe 联系你: "下次 Burberry 那单, 我希望 Chloe 直接和我对接。
你做 strategy 就行, account management 让她做。"

你心里有点不爽 — Lily 是你的 OG 客户。
你跟 Chloe 谈, 她说: "我会让 Lily 知道是 your strategy。我不会越过你。"

你 trust 她。结果客户满意度 +0.4。`,
      },
      {
        phase: 'departure',
        title: 'Chloe · 跟随合并最忠诚',
        body: `W52。无论你选哪条 path, Chloe 都跟着。

Path B + 合并: 她加入 LinkU Bespoke + AI Studio joint, 后来成为 head of account。
Path B + 独立: 她跟你独立, 一年后她说"I'd rather be your #2 than Y 姐's #15."
Path A: 她说 "I'll work part-time for you whenever you need." 兼职到她毕业。`,
      },
    ],
  },
  {
    id: 'team_eric',
    name: 'Eric',
    realName: '陈以晨',
    age: 22,
    school: 'Brunel University',
    major: 'Design BA',
    specialty: 'ai_visual_design',
    specialtyDisplay: 'AI 视觉 (Midjourney) + 电商产品图',
    recruitedVia: 'wangkai_referral',  // 王凯介绍 → 跨圈联动
    minWeek: 41,
    maxWeek: 45,
    baseRating: 4.4,
    baseEnergy: 85,
    cutPercent: 16,
    avatar: '🥡',
    miniArc: [
      {
        phase: 'recruited',
        title: 'Eric · 王凯酒桌拉人',
        body: `Soho 一家烤串店。王凯请客。Eric 是他奶茶店的"半个员工" — 兼职做海报 + 朋友圈。
王凯: "哥们这小子 Midjourney 玩得溜, 你团队需要不?"
Eric: "我想跟你学 AI 视觉。"

你: "我 cut 16%, 你 ok 吗?"
Eric: "OK"。

王凯: "记住, 这小子你照顾好。他妈是我老乡。"`,
      },
      {
        phase: 'mentored',
        title: 'Eric · DTC 美妆产品图首单',
        body: `Jess 给的单: 8 个 SKU 产品图, 各 5 个 angle。
Eric 用 Midjourney + Photoshop refine, 3 天交付。Jess 说"比我用 Shopify default 的好 10 倍"。

你: "你 Photoshop 哪里学的?"
Eric: "B 站。免费的。我 16 岁开始看 PS 教程。"`,
      },
      {
        phase: 'clash',
        title: 'Eric · 🔴 王凯也要他做奶茶店内容',
        body: `跨圈联动场景 (link2urCrossover.js: cross_wangkai_eric_steal):

W43 某天王凯吃饭跟你说: "Eric 这两周给奶茶店做新菜单海报, 我让他暂停你的活两天。OK 吗?"
你: "你说让 Eric 选, 不是你直接 reassign。"
王凯: "嗨, 他 part-time 给我做 longer than 给你做。"

你三选一:
A. 让 Eric 自己选 (公平但你可能输)
B. 涨 cut 留人 (Eric 留 + 王凯关系倒退)
C. 散伙让 (Eric 走 + 你保住和王凯关系)`,
      },
      {
        phase: 'departure',
        title: 'Eric · 取决于 clash 选择',
        body: `根据 W43 clash 选择:

A 让 Eric 选 → 他 50% 概率选你 50% 选王凯 (基于你 npcRel.wangkai vs Eric mentored 阶段评分)
B 涨 cut 留人 → Eric 留 + 王凯 -3 关系
C 散伙让 → Eric 退队 + 王凯 +2 关系 + 你 wallet -£100 severance`,
      },
    ],
  },
];

export function getMiniArcScene(memberId, phase) {
  const member = LINK2UR_TEAM_MEMBERS.find((m) => m.id === memberId);
  if (!member) return null;
  return member.miniArc.find((a) => a.phase === phase) || null;
}
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/link2urTeam.test.js
```

- [ ] **Step 5: Commit**

```bash
git add game/src/data/link2urTeam.js game/tests/link2urTeam.test.js
git commit -m "$(cat <<'EOF'
feat(game/data): 5 个可招团员 NPC + mini-arc 4 节拍

小雨 (双语文案) / Kenji (AI 视频) / Aman (投放) /
Chloe (客户对接) / Eric (AI 视觉)

每个团员 mini-arc: recruited → mentored → clash → departure
其中 Aman clash "我做得多但 cut 一样" + Eric clash "王凯也要他" 是
跨圈联动的关键场景。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3 · 章节事件链 (9 章 outline)

### Task 3.1: 新建 `link2urMainline.js` 骨架 + Ch 1-3 (Phase 1)

**Files:**
- Create: `game/src/data/link2urMainline.js`
- Test: `game/tests/link2urMainline.test.js`

- [ ] **Step 1: 写测试**

```javascript
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
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/link2urMainline.test.js
```

- [ ] **Step 3: 创建 `game/src/data/link2urMainline.js`** — 9 章骨架, Ch 1-3 完整 events

```javascript
// Link2Ur 创业线 · 9 章主线事件链 (spec §6)
//
// 每章 events 数组列出该章关键事件 (按周触发)。
// 关键事件类型:
//   - npc_scene: 引用 npcYjie.js 里的某个 YJIE_SCENES 项
//   - customer_unlock: 某个 customer 晋升到指定 relationship
//   - inbox_task: 触发某个客户的指定任务
//   - clash_trigger: 触发 clash event
//   - mini_arc: 触发某团员 mini-arc 阶段
//   - crossover: 引用 link2urCrossover.js
//   - flag_set: 设置某个 flag
//
// App.jsx 的 tick 循环每周扫一次 active chapter 的 events,
// 根据 trigger 条件 dispatch action。

export const LINK2UR_CHAPTERS = [
  // ── Ch 1 · W2-W7 · 试水 ──
  {
    chapterId: 'link2ur_ch1',
    title: '试水',
    weekStart: 2,
    weekEnd: 7,
    summary: 'Phase 1 起步。玩家用 Link2Ur 接 2-3 个简单 AI 小单 (双语字幕 / IG 海报 AI 加工)。第一个客户给五星记住你了。',
    events: [
      {
        id: 'ch1_first_simple_task',
        week: 3,
        type: 'inbox_task',
        customerId: null,  // board 单, 还没 inbox
        narrative: '你接了第一个 AI 双语字幕单 (Loon Fung 跑腿单的升级版)',
      },
      {
        id: 'ch1_lily_first_repeat',
        week: 6,
        type: 'customer_unlock',
        customerId: 'cust_lily',
        relationship: 'first_impression',
        narrative: 'Lily 给你五星 + 留言 "下次再约"',
        flagOnSet: 'l2u_first_repeat_unlocked',
      },
    ],
  },

  // ── Ch 2 · W8-W12 · 第一个回头客 ──
  {
    chapterId: 'link2ur_ch2',
    title: '第一个回头客',
    weekStart: 8,
    weekEnd: 12,
    summary: 'Lily 通过 inbox 发首个指定单 (双语短视频 5 条 +20% VIP)。Marcus 加入。Essay 危机时可能拒接, 关系倒退 (可恢复)。',
    events: [
      {
        id: 'ch2_lily_first_inbox',
        week: 8,
        type: 'inbox_task',
        customerId: 'cust_lily',
        title: 'Lily · 双语短视频 5 条 + 20% VIP',
        reward: 180,
        narrative: '"上次那个 AI 字幕做的特别好, 这次代理品牌签约, 5 条短视频本周内出。"',
        flagOnAccept: 'l2u_first_inbox_accepted',
      },
      {
        id: 'ch2_marcus_first_repeat',
        week: 10,
        type: 'customer_unlock',
        customerId: 'cust_marcus_p1',
        relationship: 'first_impression',
        narrative: 'Marcus 找你做"留学生反诈"系列双语长图文',
      },
      {
        id: 'ch2_essay_clash',
        week: 11,
        type: 'flag_set',
        flagOnSet: 'l2u_inbox_unlocked',
        narrative: 'Essay 危机叠加 (主线 Whitmore 62 分时刻), 玩家可能拒一个 inbox 任务',
      },
    ],
  },

  // ── Ch 3 · W13-W17 · 撞档·初体验 ──
  {
    chapterId: 'link2ur_ch3',
    title: '撞档·初体验',
    weekStart: 13,
    weekEnd: 17,
    summary: '圣诞期 demand 飙升。Lily + 张奶奶 + 陈一帆 三任务撞档。Lily W17 被中资品牌相中签约 (Phase 2 hook 预埋)。',
    events: [
      {
        id: 'ch3_xmas_clash',
        week: 14,
        type: 'clash_trigger',
        narrative: '圣诞前三个客户同周发指定任务 → 第一次时间撞档',
      },
      {
        id: 'ch3_grandma_repeat',
        week: 12,
        type: 'customer_unlock',
        customerId: 'cust_grandma',
        relationship: 'first_impression',
        narrative: '张奶奶让你陪她去看金毛 + 顺便发个朋友圈',
      },
      {
        id: 'ch3_chen_repeat',
        week: 10,
        type: 'customer_unlock',
        customerId: 'cust_chen',
        relationship: 'first_impression',
        narrative: '陈一帆论文 first chapter 校对单',
      },
      {
        id: 'ch3_lily_signed',
        week: 17,
        type: 'flag_set',
        flagOnSet: 'l2u_lily_signed',
        narrative: 'Lily 被中资茶饮品牌相中签约, 告诉玩家 "可能要介绍你给品牌方" (Phase 2 hook)',
      },
    ],
  },

  // Ch 4-9 在 Task 3.2-3.4 续写,先放 placeholder 让测试通过
  { chapterId: 'link2ur_ch4', title: 'Sketch 下午茶', weekStart: 21, weekEnd: 22, summary: '', events: [] },
  { chapterId: 'link2ur_ch5', title: '第一步分化', weekStart: 23, weekEnd: 26, summary: '', events: [] },
  { chapterId: 'link2ur_ch6', title: '复活节深化', weekStart: 27, weekEnd: 30, summary: '', events: [] },
  { chapterId: 'link2ur_ch7', title: '论文期低维持', weekStart: 31, weekEnd: 42, summary: '', events: [] },
  { chapterId: 'link2ur_ch8', title: 'Y 姐合并提议', weekStart: 45, weekEnd: 47, summary: '', events: [] },
  { chapterId: 'link2ur_ch9', title: '终局抉择 + 结局', weekStart: 48, weekEnd: 52, summary: '', events: [] },
];

export function getActiveChapter(day) {
  const week = Math.ceil(day / 7);
  return (
    LINK2UR_CHAPTERS.find((c) => week >= c.weekStart && week <= c.weekEnd) ||
    LINK2UR_CHAPTERS[0]
  );
}
```

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/link2urMainline.test.js
```

- [ ] **Step 5: Commit**

```bash
git add game/src/data/link2urMainline.js game/tests/link2urMainline.test.js
git commit -m "$(cat <<'EOF'
feat(game/data): Link2Ur 9 章骨架 + Ch 1-3 完整 events

Ch 1 · W2-W7 · 试水 (Phase 1 起步)
Ch 2 · W8-W12 · 第一个回头客 (Lily inbox 解锁)
Ch 3 · W13-W17 · 撞档·初体验 (圣诞撞档 + Lily 签约 Phase 2 hook)

Ch 4-9 留骨架占位, 后续 task 填充。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.2: link2urMainline.js Ch 4-5 (Phase pivot + 路径分化)

**Files:**
- Modify: `game/src/data/link2urMainline.js` (Ch 4 + Ch 5 events)
- Test: `game/tests/link2urMainline.test.js` (新增 events 测试)

- [ ] **Step 1: 写测试** — 追加

```javascript
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
```

- [ ] **Step 2: 跑测试看红**

- [ ] **Step 3: Edit `link2urMainline.js`** — 替换 Ch 4 / Ch 5 占位为:

```javascript
  // ── Ch 4 · W21-W22 · Sketch 下午茶 + Phase pivot ──
  {
    chapterId: 'link2ur_ch4',
    title: 'Sketch 下午茶',
    weekStart: 21,
    weekEnd: 22,
    summary: '父母走后撞档第 3 次 + Lily 正式介绍品牌方 → Y 姐 DM Sketch 邀请。无论玩家选什么 path, Phase 1 → 2 不可逆 pivot。',
    events: [
      {
        id: 'ch4_clash_third',
        week: 21,
        type: 'clash_trigger',
        narrative: '父母周末后第三次时间撞档 (累计 3 次, 满足 Y 姐邀请条件)',
      },
      {
        id: 'ch4_lily_brand_intro',
        week: 21,
        type: 'flag_set',
        flagOnSet: 'l2u_lily_brand_intro_pending',
        narrative: 'Lily 正式介绍蓝瓶茶饮 marketing director Carrie 给你',
      },
      {
        id: 'ch4_y_sketch_invite',
        week: 22,
        type: 'npc_scene',
        sceneId: 'yjie_sketch_invitation',
        narrative: 'Y 姐 inbox DM 约你 Sketch pink room 下午茶。三选一: 加入 Team / 委婉拒绝 / 限定接单',
      },
      {
        id: 'ch4_phase_pivot',
        week: 22,
        type: 'flag_set',
        flagOnSet: 'l2u_phase_2_active',
        statePatch: { link2urPhase: 2 },
        narrative: 'Phase 1 → 2 不可逆 pivot。玩家开始服务 Carrie / 品牌方,客单跳变。',
      },
    ],
  },

  // ── Ch 5 · W23-W26 · 第一步分化 ──
  {
    chapterId: 'link2ur_ch5',
    title: '第一步分化',
    weekStart: 23,
    weekEnd: 26,
    summary: '蓝瓶茶饮首单 £1200。Phase 1 客户 (Marcus / Jess) 部分流失或留下。Path A 玩家选 niche / Path B 招小雨。',
    events: [
      {
        id: 'ch5_brand_tea_first',
        week: 23,
        type: 'inbox_task',
        customerId: 'cust_brand_tea',
        title: '蓝瓶茶饮 · UK Launch Campaign',
        reward: 1200,
        narrative: 'Carrie: "我们 4 月 1 号 launch。 brief 后天给。如果做得好, 年度合约 retainer 直接谈。"',
        flagOnAccept: 'l2u_brand_tea_signed',
      },
      {
        id: 'ch5_marcus_introduces_paul',
        week: 23,
        type: 'flag_set',
        flagOnSet: 'l2u_marcus_paul_intro',
        narrative: 'Marcus 推荐 Paul (BBC 记者) 给你 — Phase 2 客户引荐 + 跨圈联动 hook',
      },
      // Path A · Solo
      {
        id: 'ch5_solo_capacity_limit',
        week: 24,
        type: 'flag_set',
        requireFlag: 'link2urPath_solo',
        flagOnSet: 'l2u_solo_capacity_learned',
        narrative: 'Solo 路径: 玩家学到"接单上限 N/周"机制 (UI slider 启用)',
      },
      {
        id: 'ch5_solo_niche_choice',
        week: 26,
        type: 'choice',
        requireFlag: 'link2urPath_solo',
        flagOnComplete: 'l2u_solo_niche_chosen',
        prompt: 'AI 4 专精方向 (4 选 1)',
        choices: [
          { id: 'ai_copy_pro', label: 'AI 文案专家', flag: 'l2u_solo_niche_copy' },
          { id: 'ai_visual_pro', label: 'AI 视觉专家', flag: 'l2u_solo_niche_visual' },
          { id: 'ai_video_pro', label: 'AI 视频专家', flag: 'l2u_solo_niche_video' },
          { id: 'ai_ads_pro', label: 'AI 投放策略专家', flag: 'l2u_solo_niche_ads' },
        ],
      },
      // Path B · Team
      {
        id: 'ch5_team_recruit_xiaoyu',
        week: 24,
        type: 'npc_scene',
        sceneId: 'yjie_team_referral_xiaoyu',
        requireFlag: 'link2urPath_team',
        narrative: 'Y 姐 DM 介绍小雨。玩家面谈后决定是否招人',
      },
      {
        id: 'ch5_team_assign_learned',
        week: 26,
        type: 'flag_set',
        requireFlag: 'l2u_team_recruited_xiaoyu',
        flagOnSet: 'l2u_team_assign_learned',
        narrative: 'Team 路径: 玩家学到 inbox 分单机制 (UI assign button 启用)',
      },
    ],
  },
```

- [ ] **Step 4: 跑测试看绿**

- [ ] **Step 5: Commit**

```bash
git add game/src/data/link2urMainline.js game/tests/link2urMainline.test.js
git commit -m "$(cat <<'EOF'
feat(game/mainline): Ch 4 (Sketch 邀请 + Phase pivot) + Ch 5 (路径分化)

Ch 4 W21-W22: 撞档第 3 次 + Lily 推 Carrie + Y 姐 Sketch 邀请 +
  无条件 Phase 1→2 不可逆 pivot
Ch 5 W23-W26: 蓝瓶茶饮首单 + Marcus 推 Paul + Path A 选 niche /
  Path B 招小雨 + 学分单机制

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.3: link2urMainline.js Ch 6-7 (复活节 + 论文期)

**Files:**
- Modify: `game/src/data/link2urMainline.js`
- Test: `game/tests/link2urMainline.test.js`

(测试和实现遵循 Task 3.2 同样模式。Ch 6 events 关键节点: Omar 上线 W28 + Y 姐复活节 capstone W29 + 团队招第 2 人。Ch 7 events 关键: 陈一帆推 Whitmore W33 + Y 姐 thesis check-in W36 + 🔴 Paul BBC 采访 W38 + Aman clash W40 + 王凯介绍 Eric W41。完整代码模式参考 Task 3.2。)

- [ ] **Step 1: 写测试 (Ch 6 / Ch 7)**

```javascript
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
```

- [ ] **Step 2: 跑测试看红**

- [ ] **Step 3: Edit `link2urMainline.js`** — 替换 Ch 6 / Ch 7 占位 (内容详细参考 spec §6 Ch 6/Ch 7 outline。每个 event 至少有 id / week / type / narrative 字段)

```javascript
  // ── Ch 6 · W27-W30 · 复活节深化 + Omar 上线 ──
  {
    chapterId: 'link2ur_ch6',
    title: '复活节深化',
    weekStart: 27,
    weekEnd: 30,
    summary: 'Omar 家族 startup 出海素材 £1500 (玩家迄今最高客单)。Path A 玩家独立做 Y 姐 capstone。Path B 招第 2 团员。',
    events: [
      {
        id: 'ch6_omar_first',
        week: 28,
        type: 'inbox_task',
        customerId: 'cust_omar',
        title: 'Omar · 家族 startup 出海素材',
        reward: 1500,
        narrative: 'Omar: "我家族这个 sustainability tech startup 要进英国。我想要的不是 traditional ads, 而是 storytelling video + cross-cultural localization。预算 £1500 first deliverable。"',
        flagOnAccept: 'l2u_omar_signed',
      },
      {
        id: 'ch6_easter_capstone',
        week: 29,
        type: 'npc_scene',
        sceneId: 'yjie_easter_capstone',
        narrative: 'Y 姐 group chat (Team) 或 DM (Solo): 上海一对 finance 夫妇蜜月行后 AI 内容包',
      },
      {
        id: 'ch6_team_recruit_second',
        week: 28,
        type: 'team_recruit_window',
        requireFlag: 'link2urPath_team',
        availableMembers: ['team_kenji', 'team_aman', 'team_chloe'],
        narrative: 'Team 路径: 招第 2 团员 (Kenji / Aman / Chloe 三选一)',
      },
    ],
  },

  // ── Ch 7 · W31-W42 · 论文期低维持 + 跨圈 + Paul BBC ──
  {
    chapterId: 'link2ur_ch7',
    title: '论文期低维持',
    weekStart: 31,
    weekEnd: 42,
    summary: '事件密度低但 inbox 持续滴答。Y 姐论文期 cameo。陈一帆推 Whitmore。Paul BBC 采访玩家 — AI 时代身份感悟核心场景。Aman clash。王凯介绍 Eric。',
    events: [
      {
        id: 'ch7_chen_recommends_whitmore',
        week: 33,
        type: 'crossover',
        crossoverId: 'cross_yjie_whitmore_indirect',
        narrative: '陈一帆推荐玩家给 Whitmore。Whitmore office hour: "Heard you\'ve built an AI thing. Make sure it\'s still you doing the thinking."',
      },
      {
        id: 'ch7_y_thesis_checkin',
        week: 36,
        type: 'npc_scene',
        sceneId: 'yjie_thesis_checkin',
        narrative: 'Y 姐凌晨 DM "撑住吖。论文写完你就识乜嘢叫 freedom。"',
      },
      {
        id: 'ch7_paul_bbc_interview',
        week: 38,
        type: 'crossover',
        crossoverId: 'cross_yjie_paul_bbc',
        flagOnComplete: 'l2u_paul_interview_done',
        flagOnComplete2: 'l2u_ai_anxiety_resolved',
        narrative: '🔴 Paul BBC "AI Times: Immigrant Labor in the Age of Algorithms" 专题采访。玩家身份感悟时刻 + 母题反思。',
      },
      {
        id: 'ch7_aman_clash',
        week: 40,
        type: 'mini_arc',
        memberId: 'team_aman',
        phase: 'clash',
        requireFlag: 'l2u_team_recruited_aman',
        narrative: 'Aman: "I make you the most money. £12/h cut needs to be £22." 三选一: 涨 £22 / 折衷 £18 / 不涨',
      },
      {
        id: 'ch7_wangkai_introduces_eric',
        week: 41,
        type: 'crossover',
        crossoverId: 'cross_wangkai_eric_steal',
        requireFlag: 'link2urPath_team',
        narrative: '王凯酒桌介绍 Eric。Eric 可选招入 (替换 Ch 7 常规 slot)',
      },
      {
        id: 'ch7_thesis_period_end',
        week: 42,
        type: 'flag_set',
        flagOnSet: 'l2u_thesis_period_survived',
        narrative: '论文期 low-maintenance 阶段结束',
      },
    ],
  },
```

- [ ] **Step 4: 跑测试看绿**

- [ ] **Step 5: Commit**

```bash
git add game/src/data/link2urMainline.js game/tests/link2urMainline.test.js
git commit -m "$(cat <<'EOF'
feat(game/mainline): Ch 6 (复活节深化) + Ch 7 (论文期 + Paul BBC)

Ch 6 W27-30: Omar £1500 首单 + Y 姐 capstone + 团队招第 2 人
Ch 7 W31-42: 陈一帆推 Whitmore (cross) + Y 姐 thesis check-in +
  🔴 Paul BBC AI 时代 immigrant labor 采访 (母题反思核心场景) +
  Aman cut clash + 王凯介绍 Eric

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.4: link2urMainline.js Ch 8-9 (合并提议 + 终局)

**Files:**
- Modify: `game/src/data/link2urMainline.js`
- Test: `game/tests/link2urMainline.test.js`

- [ ] **Step 1: 写测试**

```javascript
describe('Ch 8 · Y 姐合并提议 (对撞妈妈电话)', () => {
  const ch8 = LINK2UR_CHAPTERS.find((c) => c.chapterId === 'link2ur_ch8');

  test('Omar 升级 W45', () => {
    const omarUpgrade = ch8.events.find((e) => e.id === 'ch8_omar_upgrade');
    expect(omarUpgrade.week).toBe(45);
  });

  test('W47 Sketch 合并提议 + 妈妈电话 同周', () => {
    const merger = ch8.events.find((e) => e.sceneId === 'yjie_merger_offer');
    const mama = ch8.events.find((e) => e.id === 'ch8_mama_call_overlap');
    expect(merger.week).toBe(47);
    expect(mama.week).toBe(47);
  });
});

describe('Ch 9 · 终局抉择 + 结局', () => {
  const ch9 = LINK2UR_CHAPTERS.find((c) => c.chapterId === 'link2ur_ch9');

  test('W50 Y 姐告别', () => {
    const farewell = ch9.events.find((e) => e.sceneId === 'yjie_farewell');
    expect(farewell.weekStart).toBeLessThanOrEqual(52);
  });

  test('W52 结局触发', () => {
    const endTrigger = ch9.events.find((e) => e.id === 'ch9_ending_walk_down');
    expect(endTrigger.week).toBe(52);
  });
});
```

- [ ] **Step 2: 跑测试看红**

- [ ] **Step 3: Edit `link2urMainline.js`** — 替换 Ch 8 / Ch 9 占位

```javascript
  // ── Ch 8 · W45-W47 · Y 姐合并提议 (对撞妈妈电话) ──
  {
    chapterId: 'link2ur_ch8',
    title: 'Y 姐合并提议',
    weekStart: 45,
    weekEnd: 47,
    summary: 'Omar 升级 £30k/年 → Y 姐发现 → Sketch 二访合并提议。妈妈电话同周 W47, 留下做事业 vs 回国稳定的双重 pressure 浓缩。',
    events: [
      {
        id: 'ch8_omar_upgrade',
        week: 45,
        type: 'inbox_task',
        customerId: 'cust_omar',
        title: 'Omar · 家族基金年度 retainer £30k',
        reward: 30000,
        recurring: 'yearly',
        narrative: 'Omar: "We want you on retainer for the family\'s sustainability portfolio. £30k/year. 12 deliverables. Sponsor visa is on the table if you want."',
        flagOnAccept: 'l2u_omar_retainer_signed',
      },
      {
        id: 'ch8_y_merger',
        week: 47,
        type: 'npc_scene',
        sceneId: 'yjie_merger_offer',
        narrative: 'Y 姐 Sketch 二访合并提议: "客户复用 cross-sell" napkin model。三/四选一根据 path。',
      },
      {
        id: 'ch8_mama_call_overlap',
        week: 47,
        type: 'flag_set',
        flagOnSet: 'l2u_mama_call_during_merger',
        narrative: 'Y 姐提议同一天下午, 妈妈打来电话 (主线 W47): "你王阿姨女儿选调上岸了 25w + 户口" — 双重 pressure',
      },
    ],
  },

  // ── Ch 9 · W48-W52 · 终局抉择 + 结局 ──
  {
    chapterId: 'link2ur_ch9',
    title: '终局抉择 + 结局',
    weekStart: 48,
    weekEnd: 52,
    summary: '根据 Ch 8 决定不同走向: 合并 / 独立 Team / Solo。W50 Y 姐 Sketch 再约。W51-52 和主线离别周并行。W52 毕业典礼后结局 walk-down。',
    events: [
      {
        id: 'ch9_post_merger_setup',
        week: 48,
        type: 'flag_set',
        flagOnSet: 'l2u_path_finalized',
        narrative: '合并 path: 起草协议 + 联合署名 LinkU Bespoke + AI Studio / 独立 Team: 品牌升级 6 人团队 / Solo: 成"伦敦最难约的 AI 内容专家"',
      },
      {
        id: 'ch9_y_farewell',
        week: 51,
        type: 'npc_scene',
        sceneId: 'yjie_farewell',
        narrative: 'Y 姐 RFH 旁咖啡店最后一面 (不同 path 不同对白 + 不同礼物)',
      },
      {
        id: 'ch9_lily_scarf',
        week: 51,
        type: 'flag_set',
        flagOnSet: 'l2u_lily_scarf_packed',
        requireRelationship: { customerId: 'cust_lily', minRelationship: 'fan_unlocked' },
        narrative: '寄箱子时把 Lily 送的 Mulberry 围巾装进去 (跨阶段陪伴 callback)',
      },
      {
        id: 'ch9_ending_walk_down',
        week: 52,
        type: 'ending_resolve',
        narrative: '毕业典礼后结局表 walk-down 触发对应 ending (y_double / link2ur_solo_apex / link2ur_team_founded / Tier 4 兜底)',
      },
    ],
  },
```

- [ ] **Step 4: 跑测试看绿**

- [ ] **Step 5: Commit**

```bash
git add game/src/data/link2urMainline.js game/tests/link2urMainline.test.js
git commit -m "$(cat <<'EOF'
feat(game/mainline): Ch 8 (合并提议) + Ch 9 (终局)

Ch 8 W45-47: Omar £30k 升级 → Y 姐 Sketch 二访 + W47 妈妈电话同周
  双重 pressure 浓缩 (留下做事业 vs 回国稳定)
Ch 9 W48-52: 路径 finalize → Y 姐告别 RFH 咖啡 → W51 寄围巾 →
  W52 毕业典礼后结局 walk-down

9 章 outline 完成。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.5: 新建 `link2urCrossover.js` (6 条跨圈联动事件)

**Files:**
- Create: `game/src/data/link2urCrossover.js`
- Test: `game/tests/link2urCrossover.test.js`

- [ ] **Step 1: 写测试**

```javascript
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
```

- [ ] **Step 2: 跑测试看红**

- [ ] **Step 3: 创建 `game/src/data/link2urCrossover.js`**

```javascript
// Link2Ur 创业线 · 6 条跨圈联动事件 (spec §8)
// 把 Y 姐线和其他 6 主线 NPC 缝合的关键节点

export const LINK2UR_CROSSOVERS = [
  {
    id: 'cross_yjie_wangkai_pub',
    title: '王凯 Soho pub 偶遇 Y 姐',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 26 && w <= 30 && (s.npcRel?.wangkai || 0) >= 5 && s.link2urPath === 'team';
    },
    narrative: `王凯吃饭跟玩家: "那 Y 姐有意思啊 哥们感觉她想撬你的 AI 团队跟她合并。
你小心点啊。她那种人, 谈生意都说 'finesse', 听着就比咱们文。
但你跟她比的是品牌, 不是融钱。你的 AI 比她的旅游更新, 你 leverage 更大。"`,
  },
  {
    id: 'cross_yjie_whitmore_indirect',
    title: 'Whitmore office hour 提一句',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 33 && w <= 37 && (s.link2urCompleted?.length || 0) >= 18 && (s.npcRel?.whitmore || 0) >= 4;
    },
    narrative: `Whitmore 在 office hour 突然停下来:
"Heard you\'ve built an AI thing on that platform. Link2Ur, was it?
That\'s clever. Make sure it\'s still you doing the thinking, not the machine.
Now — back to Foucault."`,
  },
  {
    id: 'cross_yjie_mei_dinner',
    title: 'Y 姐带 Bespoke 客户来 Mei\'s 吃饭',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 30 && (s.npcRel?.mei || 0) >= 4 && s.link2urPath === 'team';
    },
    narrative: `Mei 私下跟玩家: "这丫头是个聪明姑娘, 不过我得告诉你 — 小心被她搞累。
她跟你王凯不一样 — 王凯亲, 她精。她吃饭的时候我看了, 给客户夹菜的手势特别熟。
那种熟不是天生的, 是练的。
你跟她合作可以。但别全押她。"`,
  },
  {
    id: 'cross_yjie_aditi_referral',
    title: 'Aditi 想找 AI 翻译兼职',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 22 && w <= 30 && (s.npcRel?.aditi || 0) >= 5;
    },
    narrative: `Aditi 论文写完跟玩家说: "I want to do some freelance AI translation/academic proofread.
Do you have a referral pipeline? Yvonne 那边可以接吗?"`,
    choices: [
      {
        label: '推给 Y 姐网络',
        effect: { npc: { aditi: 3, yjie: 1 }, flag: 'l2u_aditi_referred_yjie' },
        feedback: 'Aditi 加入 Y 姐 referral 网络。她每月通过 referral 接 4-5 个学术 AI 单, 月入 £400 补贴生活。你心里有点 mixed feelings — 帮了 Aditi, 但客户分流了。',
      },
      {
        label: '自留 (你的客户)',
        effect: { npc: { aditi: 1 }, flag: 'l2u_aditi_stayed_yours' },
        feedback: 'Aditi 加入你的客户池。她做你的学术 AI 单, 你做她的"客户"。这种 dynamic 一开始有点尴尬, 后来变成你们最深的友谊之一。',
      },
    ],
  },
  {
    id: 'cross_wangkai_eric_steal',
    title: '王凯也要 Eric 做奶茶店海报',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 41 && w <= 45 && s.link2urPath === 'team' && s.flags?.l2u_team_recruited_eric;
    },
    narrative: `Soho 烤串店。王凯: "Eric 这两周给奶茶店做新菜单海报, 我让他暂停你的活两天。OK 吗?"`,
    choices: [
      {
        label: '让 Eric 自己选',
        effect: { npc: { wangkai: 0 }, flag: 'cross_eric_chose_self' },
      },
      {
        label: '涨 cut 留人',
        effect: { stats: { wallet: -200 }, npc: { wangkai: -3 }, flag: 'cross_eric_retained_with_raise' },
      },
      {
        label: '散伙让 Eric 走',
        effect: { stats: { wallet: -100 }, npc: { wangkai: 2 }, flag: 'cross_eric_left_to_wangkai' },
      },
    ],
  },
  {
    id: 'cross_yjie_paul_bbc',
    title: '🔴 Paul BBC "AI 时代 immigrant labor" 专题',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      const paulRel = s.link2urRepeatCustomers?.cust_paul?.count || 0;
      return w >= 37 && w <= 39 && paulRel >= 4 && (s.link2urCompleted?.length || 0) >= 25;
    },
    narrative: `Paul DM: "I'm doing a BBC long-form on 'AI Times: Immigrant Labor in the Age of Algorithms'.
You're one of the 5 subjects. I want 90 min interview, on camera.

Y 姐 is also on my list. Want to do a joint shot or solo?

Questions I'll ask:
- AI 帮你做了多少 vs 你自己做了多少?
- 你觉得自己是被 AI 替代的人 还是替代别人的人?
- 在英国做 AI 内容, 跟在中国做有什么不同?"`,
    choices: [
      {
        label: '"Joint shot with Y 姐"',
        effect: {
          stats: { belonging: 10 },
          npc: { yjie: 3 },
          flag: 'l2u_paul_interview_done',
          flag2: 'l2u_paul_joint_with_yjie',
          flag3: 'l2u_ai_anxiety_resolved',
        },
      },
      {
        label: '"Solo, I want my own narrative"',
        effect: {
          stats: { belonging: 8 },
          flag: 'l2u_paul_interview_done',
          flag2: 'l2u_paul_solo',
          flag3: 'l2u_ai_anxiety_resolved',
        },
      },
      {
        label: '"Pass for now, my thesis is at 4 weeks out"',
        effect: { stats: { academic: 3 }, flag: 'l2u_paul_interview_declined' },
      },
    ],
  },
];

export function getEligibleCrossovers(state) {
  return LINK2UR_CROSSOVERS.filter((c) => {
    try {
      return c.trigger(state) && !state.flags?.[`crossover_seen_${c.id}`];
    } catch (e) {
      return false;
    }
  });
}
```

- [ ] **Step 4: 跑测试看绿**

- [ ] **Step 5: Commit**

```bash
git add game/src/data/link2urCrossover.js game/tests/link2urCrossover.test.js
git commit -m "$(cat <<'EOF'
feat(game/data): 6 条 Link2Ur × 主线 NPC 跨圈联动事件

王凯 pub 偶遇 / Whitmore office 警句 / Mei dinner 提醒 /
Aditi referral / 王凯抢 Eric / 🔴 Paul BBC AI 时代 immigrant labor 专题

Paul BBC 是整条 Y 姐线最深的母题反思场景。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4 · UI 改动

### Task 4.1: 新建 `<InboxCard />` + `<PhaseIndicator />` 两个 atom

**Files:**
- Modify: `game/src/components/Atoms.jsx` (加 2 个新 component)
- Test: 手动 visual review (无独立测试)

- [ ] **Step 1: 看 Atoms.jsx 现有风格**

```bash
head -40 game/src/components/Atoms.jsx
```

- [ ] **Step 2: 在 `Atoms.jsx` 末尾添加 InboxCard + PhaseIndicator**

```jsx
// ── Link2Ur 创业线 v2 atoms ──

export function InboxCard({ task, onAccept, onDecline, onAssign, hasTeam }) {
  const daysLeft = (task.dueByDay || 0) - (task.currentDay || 0);
  const urgent = daysLeft <= 2;
  return (
    <div className={`bg-white rounded-lg p-4 shadow-sm border ${urgent ? 'border-orange-400' : 'border-gray-200'}`}>
      <div className="flex justify-between items-start mb-2">
        <div>
          <span className="text-2xl mr-2">{task.emoji}</span>
          <span className="font-semibold">{task.title}</span>
        </div>
        <span className="text-sm text-orange-600 font-medium">
          £{task.reward} {task.rewardBonus ? `(+${Math.round(task.rewardBonus * 100)}% VIP)` : ''}
        </span>
      </div>
      <p className="text-sm text-gray-600 mb-2">{task.desc}</p>
      <div className="flex items-center gap-3 text-xs text-gray-500 mb-3">
        <span>⏰ {daysLeft} 天后过期</span>
        <span>📅 必须 {task.mustCompleteByDay - task.currentDay} 天内完成</span>
        <span>⚡ -{task.energyCost}</span>
      </div>
      <div className="flex gap-2">
        <button onClick={onAccept} className="flex-1 bg-blue-600 text-white py-2 rounded font-medium hover:bg-blue-700">接受</button>
        {hasTeam && <button onClick={onAssign} className="flex-1 bg-purple-600 text-white py-2 rounded font-medium hover:bg-purple-700">分给团员</button>}
        <button onClick={onDecline} className="flex-1 bg-gray-200 text-gray-700 py-2 rounded font-medium hover:bg-gray-300">拒绝</button>
      </div>
    </div>
  );
}

export function PhaseIndicator({ phase, daysUntilShift }) {
  if (phase === 1) {
    return (
      <div className="bg-green-50 text-green-800 text-sm rounded px-3 py-2 flex items-center gap-2">
        🌱 <span className="font-medium">Phase 1 · 留学生 AI 服务</span>
        {daysUntilShift && <span className="text-xs ml-auto opacity-75">距离转型 {daysUntilShift} 天</span>}
      </div>
    );
  }
  return (
    <div className="bg-blue-50 text-blue-800 text-sm rounded px-3 py-2 flex items-center gap-2">
      🚀 <span className="font-medium">Phase 2 · 跨境 AI Studio</span>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add game/src/components/Atoms.jsx
git commit -m "feat(game/ui): 加 InboxCard + PhaseIndicator atom"
```

---

### Task 4.2: 新建 `<TeamMemberRow />` + `<ClashWarningModal />`

(类似 4.1 模式。给两个 component 加完整 jsx, 用 Tailwind, 跟现有 Atoms.jsx 风格一致。)

- [ ] **Step 1-3**: 在 `Atoms.jsx` 加 TeamMemberRow + ClashWarningModal, commit。

```jsx
export function TeamMemberRow({ member, onMessage }) {
  const energyPct = Math.min(100, member.energy);
  const energyBar = (
    <div className="w-12 h-1.5 bg-gray-200 rounded">
      <div className="h-1.5 bg-green-500 rounded" style={{ width: `${energyPct}%` }} />
    </div>
  );
  return (
    <div className="flex items-center gap-3 py-2 border-b last:border-0">
      <span className="text-2xl">{member.avatar}</span>
      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium truncate">{member.name}</div>
        <div className="text-xs text-gray-500 truncate">{member.specialtyDisplay}</div>
      </div>
      <span className="text-xs text-gray-600">⭐ {member.rating}</span>
      {energyBar}
      <button onClick={() => onMessage?.(member.id)} className="text-xs text-blue-600 hover:underline">聊</button>
    </div>
  );
}

export function ClashWarningModal({ taskA, taskB, hasTeam, onResolve, onClose }) {
  if (!taskA || !taskB) return null;
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg max-w-md w-full p-6 m-4">
        <h3 className="text-lg font-bold mb-2">⚠️ 时间撞档了</h3>
        <p className="text-sm text-gray-700 mb-3">两个指定任务的时间窗口重叠了。你只能选一种处理方式。</p>
        <div className="space-y-2 mb-4 text-xs">
          <div className="bg-orange-50 px-3 py-2 rounded">
            <span className="font-medium">A.</span> {taskA.title} · £{taskA.reward}
          </div>
          <div className="bg-orange-50 px-3 py-2 rounded">
            <span className="font-medium">B.</span> {taskB.title} · £{taskB.reward}
          </div>
        </div>
        <div className="space-y-2">
          <button onClick={() => onResolve('self')} className="block w-full bg-red-100 text-red-800 py-2 rounded text-sm hover:bg-red-200">
            硬扛两个 (-30 energy, -3 学业, -0.02 评分)
          </button>
          <button onClick={() => onResolve('decline_a')} className="block w-full bg-gray-100 text-gray-800 py-2 rounded text-sm hover:bg-gray-200">
            拒掉 A 保 B
          </button>
          <button onClick={() => onResolve('decline_b')} className="block w-full bg-gray-100 text-gray-800 py-2 rounded text-sm hover:bg-gray-200">
            拒掉 B 保 A
          </button>
          {hasTeam && (
            <button onClick={() => onResolve('team')} className="block w-full bg-purple-100 text-purple-800 py-2 rounded text-sm hover:bg-purple-200">
              转 A 给团员处理 (-15% cut)
            </button>
          )}
        </div>
        <button onClick={onClose} className="mt-3 text-xs text-gray-500 underline">稍后再说</button>
      </div>
    </div>
  );
}
```

```bash
git add game/src/components/Atoms.jsx
git commit -m "feat(game/ui): 加 TeamMemberRow + ClashWarningModal atom"
```

---

### Task 4.3: `Link2UrView.jsx` 加 Inbox tab + Team panel

**Files:**
- Modify: `game/src/components/Link2UrView.jsx`

- [ ] **Step 1-5**: Read Link2UrView 现状, 在现有 tab 旁加 Inbox + Team tab。引入 InboxCard / TeamMemberRow / PhaseIndicator。tab 切换用 useState。Inbox tab 显示 `state.link2urInbox` 数组, 每个用 InboxCard。Team tab 仅 `link2urPath === 'team'` 时显示, 显示 `state.link2urTeamMembers` 用 TeamMemberRow。Commit:

```bash
git add game/src/components/Link2UrView.jsx
git commit -m "feat(game/ui): Link2UrView 加 Inbox / Team tab + Phase indicator"
```

---

## Phase 5 · 接单 templates + Reducer 集成

### Task 5.1: `link2ur.js` 加 15 个 AI 广告任务模板 + phase 字段

**Files:**
- Modify: `game/src/data/link2ur.js`
- Test: `game/tests/link2ur.test.js`

- [ ] **Step 1: 写测试** — 在 `game/tests/link2ur.test.js` 加

```javascript
describe('AI 广告任务模板 (v2 spec)', () => {
  test('LINK2UR_ACCEPT_TEMPLATES 含 ≥ 75 个 (60 原有 + 15 新)', () => {
    expect(LINK2UR_ACCEPT_TEMPLATES.length).toBeGreaterThanOrEqual(75);
  });

  test('所有 AI 广告模板带 phase 字段 (1/2/both)', () => {
    const aiTemplates = LINK2UR_ACCEPT_TEMPLATES.filter((t) => t.id.startsWith('l2u_ai_'));
    expect(aiTemplates.length).toBe(15);
    for (const t of aiTemplates) {
      expect([1, 2, 'both']).toContain(t.phase);
    }
  });

  test('generateBoard with phase=1 过滤掉 Phase 2 only 模板', () => {
    const board = generateBoard(10, { rng: () => 0.5, phase: 1 });
    const hasPhase2Only = board.some((t) => {
      const tmpl = LINK2UR_ACCEPT_TEMPLATES.find((x) => x.id === t.templateId);
      return tmpl?.phase === 2;
    });
    expect(hasPhase2Only).toBe(false);
  });
});
```

- [ ] **Step 2: 跑测试看红**

- [ ] **Step 3: Edit `link2ur.js`** — 在 LINK2UR_ACCEPT_TEMPLATES 末尾加 15 个 AI 广告模板。

**完整模板示例 (1 个 P1 + 1 个 P2 + 1 个 both),余下 12 个照同样模式补**:

```javascript
// ── AI 广告类任务 (v2 创业线) ──
{
  id: 'l2u_ai_bilingual_subtitle', type: 'ai_video_short', emoji: '🎬',
  titles: ['双语字幕 AI 加工 1 条', '短视频中英 AI 字幕 + 时间轴'],
  desc: '客户做留学生 vlog,需要 native AI 双语字幕。Whisper 转录 + GPT 校对 + 时间轴对齐。',
  rewardMin: 40, rewardMax: 70,
  energyCost: 6, actionCost: 1,
  minWeek: 2, maxWeek: 52,
  rating: 5,
  phase: 1,                       // 🆕 仅 Phase 1 上板
  customerAffinityType: 'ai_video_short',
},
{
  id: 'l2u_ai_brand_copy_bilingual', type: 'ai_copy_bilingual', emoji: '📝',
  titles: ['跨境 brand copy 中英双语 5 个 SKU', 'DTC 品牌 listing 双语优化'],
  desc: '客户是中资 DTC 品牌进 UK。需要每个 SKU 的 brand voice 中英双向打通 + 本地化文化梗。',
  rewardMin: 800, rewardMax: 1500,
  energyCost: 18, actionCost: 1,
  minWeek: 22, maxWeek: 52,
  rating: 5,
  phase: 2,                       // 🆕 Phase 2 only
  customerAffinityType: 'ai_copy_bilingual',
  requirement: { count: 5, rating: 4.6 },
},
{
  id: 'l2u_ai_midjourney_product', type: 'ai_visual_design', emoji: '🎨',
  titles: ['Midjourney 电商产品图 5 SKU', 'AI 产品照 + Photoshop refine'],
  desc: 'Midjourney 出 base + Photoshop 修。8 个 SKU × 5 angle。',
  rewardMin: 150, rewardMax: 350,
  energyCost: 10, actionCost: 1,
  minWeek: 2, maxWeek: 52,
  rating: 5,
  phase: 'both',                  // 🆕 跨阶段
  customerAffinityType: 'ai_visual_product',
},
```

**剩余 12 个 AI 模板** (按上面 3 个示例的字段结构补全文案):

| # | id | phase | type | reward 区间 | minWeek |
|---|---|---|---|---|---|
| 4 | `l2u_ai_short_video_localization` | 1 | ai_video_short | 50-90 | 2 |
| 5 | `l2u_ai_xhs_content_pack` | 1 | ai_xhs_content | 80-200 | 4 |
| 6 | `l2u_ai_ig_visual_set` | 1 | ai_ig_visual | 60-150 | 2 |
| 7 | `l2u_ai_student_showreel` | 1 | ai_personal_brand | 40-180 | 6 |
| 8 | `l2u_ai_logo_brand_kit` | 1 | ai_branding | 100-400 | 8 |
| 9 | `l2u_ai_sora_30s_spec` | 2 | ai_video_long | 600-1500 | 23 |
| 10 | `l2u_ai_meta_campaign` | 2 | ai_ads_meta | 800-2500 | 23 |
| 11 | `l2u_ai_google_campaign` | 2 | ai_ads_google | 600-2000 | 23 |
| 12 | `l2u_ai_xhs_kol_match` | 2 | ai_xhs_kol | 400-1200 | 25 |
| 13 | `l2u_ai_bilingual_gtm` | 2 | ai_gtm_strategy | 1000-3000 | 30 |
| 14 | `l2u_ai_dtc_listing` | 2 | ai_dtc_listing | 300-800 | 25 |
| 15 | `l2u_ai_academic_proofread` | both | ai_academic | 50-150 | 8 |

- [ ] **Step 4: 改 generateBoard 加 phase filter**

```javascript
export function generateBoard(week, opts = {}) {
  const rng = opts.rng || Math.random;
  const phase = opts.phase || 1;  // 🆕
  const eligible = LINK2UR_ACCEPT_TEMPLATES.filter(
    (t) => week >= (t.minWeek || 1) && week <= (t.maxWeek || 99)
      && (t.phase === undefined || t.phase === 'both' || t.phase === phase),  // 🆕
  );
  // ... rest unchanged
}
```

- [ ] **Step 5: 跑测试看绿**

```bash
npm test -- tests/link2ur.test.js
```

- [ ] **Step 6: Commit**

```bash
git add game/src/data/link2ur.js game/tests/link2ur.test.js
git commit -m "$(cat <<'EOF'
feat(game/link2ur): +15 AI 广告任务模板 + phase filter

P1 (8 个): 双语字幕 / 短视频本地化 / 小红书 pack / IG visual /
  Midjourney 产品 / 留学生 showreel / logo brand kit
P2 (6 个): brand copy / Sora 30s / Meta campaign / Google campaign /
  小红书 KOL / 双语 GTM / DTC listing
跨阶段 (1 个): 学术 AI 校对

generateBoard 加 phase 参数,默认 1。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5.2: `state.js` reducer 加 4 个新 action

**Files:**
- Modify: `game/src/engine/state.js` (reducer 函数)
- Test: `game/tests/state.test.js`

- [ ] **Step 1: 写测试** — 在 `game/tests/state.test.js` 加

```javascript
import { reducer, initialState } from '../src/engine/state.js';

describe('Link2Ur 创业线 reducer actions', () => {
  test('L2U_INBOX_RECEIVED push task', () => {
    const s = initialState();
    const next = reducer(s, {
      type: 'L2U_INBOX_RECEIVED',
      task: { id: 'inbox_x', customerId: 'cust_lily', reward: 100 },
    });
    expect(next.link2urInbox.length).toBe(1);
    expect(next.link2urInbox[0].id).toBe('inbox_x');
  });

  test('L2U_INBOX_ACCEPTED 移除 + 加 wallet + 加 completed', () => {
    const s = { ...initialState(),
      link2urInbox: [{ id: 'inbox_x', customerId: 'cust_lily', reward: 100, taskRating: 5 }],
    };
    const next = reducer(s, { type: 'L2U_INBOX_ACCEPTED', taskId: 'inbox_x' });
    expect(next.link2urInbox.length).toBe(0);
    expect(next.stats.wallet).toBe(s.stats.wallet + 100);
    expect(next.link2urCompleted).toContain('inbox_x');
    expect(next.link2urRepeatCustomers.cust_lily.count).toBe(1);
  });

  test('L2U_PHASE_PIVOT 不可逆', () => {
    const s = initialState();
    const next = reducer(s, { type: 'L2U_PHASE_PIVOT' });
    expect(next.link2urPhase).toBe(2);
    expect(next.link2urPhaseShiftDay).toBe(s.day);
  });

  test('L2U_PATH_DECIDED 锁定路径', () => {
    const s = initialState();
    const next = reducer(s, { type: 'L2U_PATH_DECIDED', path: 'team' });
    expect(next.link2urPath).toBe('team');
    expect(next.link2urPathDecidedDay).toBe(s.day);
  });

  test('L2U_TEAM_RECRUIT 加团员到 runtime 数组', () => {
    const s = initialState();
    const next = reducer(s, {
      type: 'L2U_TEAM_RECRUIT',
      memberId: 'team_xiaoyu',
      specialty: 'ai_copywriting_bilingual',
      cutPercent: 18,
    });
    expect(next.link2urTeamMembers.length).toBe(1);
    expect(next.link2urTeamMembers[0].memberId).toBe('team_xiaoyu');
    expect(next.link2urTeamMembers[0].status).toBe('active');
    expect(next.link2urTeamMembers[0].energy).toBe(80);  // 默认初始 energy
  });
});
```

- [ ] **Step 2: 跑测试看红**

```bash
npm test -- tests/state.test.js -t "Link2Ur 创业线 reducer actions"
```

- [ ] **Step 3: 在 reducer 函数里加 7 个 cases**

在 state.js 现有 reducer switch 内添加 (示例 2 个,其余 5 个照同模式):

```javascript
case 'L2U_INBOX_RECEIVED':
  return { ...state, link2urInbox: [...state.link2urInbox, action.task] };

case 'L2U_INBOX_ACCEPTED': {
  const task = state.link2urInbox.find((t) => t.id === action.taskId);
  if (!task) return state;
  // 移除 inbox / 加 wallet / 加 completed / 升级 customer
  const afterPromote = maybePromoteToRepeat(
    { ...state,
      link2urInbox: state.link2urInbox.filter((t) => t.id !== action.taskId),
      stats: { ...state.stats, wallet: state.stats.wallet + (task.reward || 0) },
      link2urCompleted: [...state.link2urCompleted, task.id],
    },
    { customerId: task.customerId, taskRating: task.taskRating || 5, day: state.day }
  );
  return afterPromote;
}

case 'L2U_INBOX_DECLINED': {
  const task = state.link2urInbox.find((t) => t.id === action.taskId);
  if (!task) return state;
  const p = task.declinePenalty || {};
  return {
    ...state,
    link2urInbox: state.link2urInbox.filter((t) => t.id !== action.taskId),
    link2urRating: Math.max(0, state.link2urRating - (p.ratingDecay || 0)),
    // customer 关系倒退 (简化版,后续可加 lastDeclinedDay)
  };
}

case 'L2U_CLASH_RESOLVED': {
  // action.resolution: 'self' / 'decline_a' / 'decline_b' / 'team'
  // 委托各自的 L2U_INBOX_* action 拆分处理 (此 case 仅记录)
  return {
    ...state,
    link2urClashCount: state.link2urClashCount + 1,
    link2urClashEvents: [
      ...state.link2urClashEvents,
      { day: state.day, taskIds: action.taskIds, resolution: action.resolution },
    ],
  };
}

case 'L2U_PHASE_PIVOT':
  if (state.link2urPhase === 2) return state;  // 已 pivot 不重做
  return {
    ...state,
    link2urPhase: 2,
    link2urPhaseShiftDay: state.day,
  };

case 'L2U_PATH_DECIDED':
  return {
    ...state,
    link2urPath: action.path,
    link2urPathDecidedDay: state.day,
  };

case 'L2U_TEAM_RECRUIT':
  return {
    ...state,
    link2urTeamMembers: [
      ...state.link2urTeamMembers,
      {
        memberId: action.memberId,
        joinedDay: state.day,
        specialty: action.specialty,
        energy: action.baseEnergy || 80,
        completed: 0,
        cutPercent: action.cutPercent || 18,
        status: 'active',
      },
    ],
  };

case 'L2U_TEAM_MEMBER_LEAVE':
  return {
    ...state,
    link2urTeamMembers: state.link2urTeamMembers.map((m) =>
      m.memberId === action.memberId ? { ...m, status: action.status || 'departed' } : m
    ),
  };
```

注意: `L2U_INBOX_ACCEPTED` 引用了 `maybePromoteToRepeat`,所以 state.js 顶部要 `import { maybePromoteToRepeat } from './link2urRepeat.js';`

**Catalog vs runtime 区分**: `LINK2UR_TEAM_MEMBERS` (Task 2.3) 是**模板目录**(static catalog),`state.link2urTeamMembers` 是**运行时实例**。`L2U_TEAM_RECRUIT` 从 catalog 读取 (memberId/specialty/cutPercent) → 构造 runtime instance push 到 state。

- [ ] **Step 4: 跑测试看绿**

```bash
npm test -- tests/state.test.js -t "Link2Ur 创业线 reducer actions"
```

- [ ] **Step 5: Commit**

```bash
git add game/src/engine/state.js game/tests/state.test.js
git commit -m "$(cat <<'EOF'
feat(game/state): reducer 加 7 个 Link2Ur 创业线 actions

L2U_INBOX_RECEIVED / ACCEPTED / DECLINED · 指定任务流转
L2U_CLASH_RESOLVED · 撞档累计 + 历史
L2U_PHASE_PIVOT · Phase 1→2 不可逆 pivot
L2U_PATH_DECIDED · Solo/Team 路径锁定
L2U_TEAM_RECRUIT + L2U_TEAM_MEMBER_LEAVE · 团员生命周期

ACCEPTED 内嵌 maybePromoteToRepeat 链式 customer 关系晋升。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5.3: `App.jsx` 集成: 章节 tick + scene 弹出 + crossover 检测

**Files:**
- Modify: `game/src/App.jsx`
- Manual playtest

- [ ] **Step 1-5**: 在 App.jsx 的 `endDay` / `endWeek` 逻辑里加:
  1. 调 `getActiveChapter(state.day)` 取当前章节
  2. 扫该章节 events, week === currentWeek 的 trigger dispatch
  3. 扫 `getEligibleCrossovers(state)` 触发未见过的 crossover
  4. 跑 `shouldTriggerYInvitation(state)` — true 时 dispatch L2U_Y_INVITATION

```bash
git add game/src/App.jsx
git commit -m "feat(game/app): 集成 Link2Ur 创业线 tick — 章节 events + crossover + Y 姐邀请触发"
```

---

## Phase 6 · 结局 + 成就 + 联动

### Task 6.1: `endings.js` 加 3 新结局 + 5 处现有结局回填

**Files:**
- Modify: `game/src/data/endings.js`
- Test: `game/tests/endings.test.js`

- [ ] **Step 1-5**: 写测试 + 加 3 个新结局对象 (`y_double` / `link2ur_team_founded` / `link2ur_solo_apex`),完整 body 文本来自 spec §7.1。修改 `resolveEnding` 函数加新结局 require 检查。5 处现有结局轻微回填 spec §7.2 改 body。Commit:

```bash
git add game/src/data/endings.js game/tests/endings.test.js
git commit -m "feat(game/endings): +3 Link2Ur 创业线结局 + 5 现有结局 AI 广告回填"
```

---

### Task 6.2: `achievements.js` 加 6 新成就

**Files:**
- Modify: `game/src/data/achievements.js`
- Test: `game/tests/achievements.test.js`

- [ ] **Step 1-5**: 加 6 个新 achievement 对象 (`l2u_first_repeat` / `l2u_clash_survived` / `l2u_y_audience` / `l2u_first_hire` / `l2u_team_5` / `l2u_ai_anxiety_resolved`)。所有 trigger 条件来自 spec §10.3。

```bash
git add game/src/data/achievements.js game/tests/achievements.test.js
git commit -m "feat(game/achievements): +6 Link2Ur 创业线成就 (含 'AI 时代我是匠人 不是工具人')"
```

---

### Task 6.3: `link2urCs.js` 加 2 条 mid-game 关怀

**Files:**
- Modify: `game/src/data/link2urCs.js`

- [ ] **Step 1-3**: 在 `LINK2UR_CS_MESSAGES` 末尾追加 2 条 (`cs_phase_pivot` + `cs_mama_call`)。Commit:

```bash
git add game/src/data/link2urCs.js
git commit -m "feat(game/cs): 小 U 加 cs_phase_pivot + cs_mama_call 两条 mid-game 关怀"
```

---

### Task 6.4: `storylines.js` 注册 Y 姐为第 7 主线

**Files:**
- Modify: `game/src/data/storylines.js`

- [ ] **Step 1-3**: 在 storylines.js 末尾导出 `YJIE_STORYLINE` 对象, 引用 `LINK2UR_CHAPTERS`。

```bash
git add game/src/data/storylines.js
git commit -m "feat(game/storylines): 注册 Y 姐 (yjie) 为第 7 主线"
```

---

### Task 6.5: 更新 `STORY_OUTLINE.md` 同步

**Files:**
- Modify: `game/docs/STORY_OUTLINE.md`

- [ ] **Step 1-3**: 总览表加第 7 行 (Y 姐 / Link2Ur AI 广告线 / 9 章 / Phase 1/2)。加 §3.5 节"Link2Ur AI 广告创业线 (第 7 主线)"。结局表加 3 行新结局。跨圈联动 section 加 6 条。

```bash
git add game/docs/STORY_OUTLINE.md
git commit -m "docs(game/outline): 同步 STORY_OUTLINE.md — Y 姐线第 7 主线"
```

---

## Phase 7 · 集成测试 + Playtest

### Task 7.1: 端到端集成测试 (3 path 各一)

**Files:**
- Create: `game/tests/integration/link2urMainlineE2E.test.js`

- [ ] **Step 1-5**: 写 3 个 end-to-end 测试模拟从 W2 到 W52 的完整 path:
  - `path A solo apex`: 拒 Y 姐邀请 + 选 AI 文案 niche + W47 拒合并 + W52 触发 `link2ur_solo_apex` 结局
  - `path B team merged`: 接 Y 姐邀请 + 招 4 团员 + W47 接合并 + W52 触发 `y_double` 结局
  - `path B team independent`: 接 Y 姐邀请 + 招 2 团员 + W47 拒合并独立 + W52 触发 `link2ur_team_founded` 结局

每个测试用 reducer 一步步 simulate state transitions, 最后验证最终 ending ID 正确。

```bash
git add game/tests/integration/
git commit -m "test(game): Link2Ur 创业线 3 path end-to-end 集成测试"
```

---

### Task 7.2: 手动 playtest + 修 bug

**Files:**
- 浮动 (基于 playtest 发现)

- [ ] **Step 1: 启动 dev server**

```bash
cd game && npm run dev
```

- [ ] **Step 2: 创建新存档, 走完 Path A Solo 全程**

至少 spot check:
- Ch 1 Lily 第一个 repeat 提示
- Ch 2 inbox UI 首次显示
- Ch 3 撞档 modal 弹出
- Ch 4 Sketch 邀请场景 + 拒 Y
- Phase pivot 后任务 type 切换
- Ch 5 selected AI niche
- Ch 7 W38 Paul BBC 采访
- Ch 8 W47 拒合并 + 妈妈电话同周
- Ch 9 W52 结局 walk-down 显示 link2ur_solo_apex

- [ ] **Step 3: 创建新存档, 走完 Path B Team merged**

类似 Step 2, 但接 Y 姐 + 招 4 团员 + 接合并。

- [ ] **Step 4: 修 playtest 中发现的 bug**

每个 bug 写 regression test 后修。Commit:

```bash
git add <changed-files>
git commit -m "fix(game/link2ur): playtest 暴露 bug · <具体描述>"
```

- [ ] **Step 5: balance 调整**

根据 playtest 实际体感调整数字:
- 单价 / energy cost / phase pivot 节奏 / 团员 cut 比例 etc.

```bash
git add game/src/data/ game/src/engine/
git commit -m "tune(game/link2ur): playtest 后 balance 调整 · 单价/energy/cut 比例"
```

---

## 总结

**全部 commits 数量预估:** 28 + (playtest fix 数量)

**全部测试覆盖:**
- state.test.js (Link2Ur 字段)
- persistence.test.js (migration)
- link2urRepeat.test.js (回头客)
- link2urSchedule.test.js (撞档 + Y 邀请触发)
- npcYjie.test.js (Y 姐 7 场景)
- link2urCustomers.test.js (8 客户)
- link2urTeam.test.js (5 团员 mini-arc)
- link2urMainline.test.js (9 章 events)
- link2urCrossover.test.js (6 联动事件)
- endings.test.js (3 新结局)
- achievements.test.js (6 新成就)
- link2ur.test.js (15 新 AI 模板 + phase filter)
- integration/link2urMainlineE2E.test.js (3 path 端到端)

**完成期估算:** 3-4 周 (含 playtest 与 bug 修复)
