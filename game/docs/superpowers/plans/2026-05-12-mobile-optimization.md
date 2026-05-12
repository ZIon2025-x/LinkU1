# 移动端布局优化 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 PlayingScreen + 所有居中 modal 改成 mobile-first 布局：压缩 header + 底部 sticky CTA + 4-tab 底栏 + 🎒 背包 sheet + 通用 BottomSheet。

**Architecture:** 抽 `BottomSheet` 通用组件作为所有 sheet/modal 的统一容器（mobile = 底部弹出，md+ = 居中 dialog）；`BagSheet` 包装 BottomSheet 提供 3 段内容（完整状态 / 本周 / 设置），替换原 `GameMenuPanel`；PlayingScreen 用 `flex h-[100dvh]` 三段布局（压缩 header / 滚动内容 / 固定底栏）。

**Tech Stack:** React 18 + Vite + Tailwind CSS 3.4 + Vitest 2.1 + @testing-library/react（按文件 opt-in jsdom 环境）。

**Spec:** `docs/superpowers/specs/2026-05-12-mobile-optimization-design.md`

---

## File Structure

| 路径 | 操作 | 责任 |
|---|---|---|
| `tailwind.config.js` | Modify | 加 safe-area spacing tokens |
| `index.html` | Modify | viewport-fit=cover |
| `src/styles.css` | Modify | overscroll-behavior / user-select / touch-callout |
| `src/components/BottomSheet.jsx` | **Create** | 通用 sheet 容器（mobile bottom-sheet / md+ centered modal） |
| `tests/components/BottomSheet.test.jsx` | **Create** | BottomSheet 行为单测（jsdom） |
| `src/components/BagSheet.jsx` | **Create** | 背包内容（3 段） |
| `tests/components/BagSheet.test.jsx` | **Create** | BagSheet 渲染单测（jsdom） |
| `src/components/Modals.jsx` | Modify | 删除 GameMenuPanel；其余 12 个 modal 改用 BottomSheet |
| `src/components/Screens.jsx` | Modify | PlayingScreen 重构 + 5 个 modal 改用 BottomSheet |
| `src/components/AchievementsView.jsx` | Modify | 2 个 modal 改用 BottomSheet |
| `src/components/Views.jsx` | Modify | 100vh → 100dvh（3 处） |
| `src/main.jsx` | Modify | 100vh → 100dvh（1 处错误兜底） |
| `src/App.jsx` | Modify | GameMenuPanel → BagSheet；menu state → bag state |

---

## Phase 1 · Foundation（CSS / config / viewport）

### Task 1: index.html viewport-fit=cover

**Files:**
- Modify: `index.html:5`

- [ ] **Step 1: Update viewport meta**

替换 `index.html:5`:

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat(mobile): viewport-fit=cover for safe-area support"
```

---

### Task 2: Tailwind safe-area spacing tokens

**Files:**
- Modify: `tailwind.config.js`

- [ ] **Step 1: Read existing config**

```bash
cat tailwind.config.js
```

- [ ] **Step 2: Add `theme.extend.spacing` with safe-area tokens**

合并到 `theme.extend`（如果不存在 spacing 则新增）：

```js
theme: {
  extend: {
    spacing: {
      'safe-b': 'env(safe-area-inset-bottom)',
      'safe-t': 'env(safe-area-inset-top)',
      'safe-l': 'env(safe-area-inset-left)',
      'safe-r': 'env(safe-area-inset-right)',
    },
  },
},
```

- [ ] **Step 3: Verify Tailwind picks up new utility**

```bash
npm run build 2>&1 | tail -5
```
Expected: build success；产物 CSS 含 `pb-safe-b` / `pt-safe-t` 类。

- [ ] **Step 4: Commit**

```bash
git add tailwind.config.js
git commit -m "feat(mobile): tailwind safe-area-inset spacing tokens"
```

---

### Task 3: 全局 CSS 防误操作 + 滚动锚定

**Files:**
- Modify: `src/styles.css`

- [ ] **Step 1: Append mobile-hardening rules to `@layer base { body { ... } }`**

在 `src/styles.css` 的 `body` 块内追加：

```css
/* Mobile hardening：防 iOS 上拉刷新 / 防长按弹选词菜单 */
overscroll-behavior: none;
-webkit-touch-callout: none;
```

并新增一条规则（在 body 块**外**，仍在 `@layer base` 内）：

```css
/* UI chrome 上禁用文本选择，但允许内容区选中 */
button, .ui-chrome { user-select: none; -webkit-user-select: none; }
```

- [ ] **Step 2: Sanity check：dev server 启动后 body 不变白 / 文本仍可选**

```bash
$env:PATH = "F:\flutter\bin;" + $env:PATH; npm run dev 2>&1 | head -3
```
（手动验证：浏览器打开 dev URL，body 显示正常；`<p>` 文本可双击选中；`<button>` label 不能被选中）

- [ ] **Step 3: Commit**

```bash
git add src/styles.css
git commit -m "feat(mobile): overscroll/user-select/touch-callout hardening"
```

---

### Task 4: 100vh → 100dvh

**Files:**
- Modify: `src/components/Views.jsx:469, 554, 704`
- Modify: `src/main.jsx:25`

- [ ] **Step 1: 改 Views.jsx 3 处**

3 处都是同一字符串：

```js
style={{ height: 'calc(100vh - 120px)', maxHeight: 600 }}
```

改为：

```js
style={{ height: 'calc(100dvh - 120px)', maxHeight: 600 }}
```

- [ ] **Step 2: 改 main.jsx:25**

```js
minHeight: '100vh',
```
改为：
```js
minHeight: '100dvh',
```

- [ ] **Step 3: Run tests**

```bash
npm test 2>&1 | tail -5
```
Expected: 245+ tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/components/Views.jsx src/main.jsx
git commit -m "feat(mobile): 100vh → 100dvh for iOS dynamic viewport"
```

---

## Phase 2 · Vitest jsdom 支持

### Task 5: 安装并验证 jsdom 环境（per-file opt-in）

**Files:**
- (无新增文件；只验证现有 `package.json` 已含 jsdom + @testing-library/react)

- [ ] **Step 1: 验证依赖在 package.json**

```bash
cat package.json | grep -E "jsdom|testing-library"
```
Expected: 看到 `jsdom`、`@testing-library/react`、`@testing-library/jest-dom`。

- [ ] **Step 2: 写一个最小冒烟 test 验证 jsdom 切换工作**

新建 `tests/components/_smoke.test.jsx`:

```jsx
// @vitest-environment jsdom
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';

describe('jsdom smoke', () => {
  it('renders a div', () => {
    render(<div>hello mobile</div>);
    expect(screen.getByText('hello mobile')).toBeTruthy();
  });
});
```

- [ ] **Step 3: Run test**

```bash
npm test -- tests/components/_smoke.test.jsx 2>&1 | tail -10
```
Expected: PASS, 1 test。如果失败说明 jsdom env 没切到，检查注释拼写 `// @vitest-environment jsdom` 是否在文件首行。

- [ ] **Step 4: 删除 smoke 文件（不留垃圾）**

```bash
rm tests/components/_smoke.test.jsx
```

- [ ] **Step 5: Commit**

```bash
# 没文件改动可跳过 commit；如有 package.json 改动则 commit
git status --short package*.json
```
（这步通常无需 commit）

---

## Phase 3 · BottomSheet 通用组件（TDD）

### Task 6: BottomSheet 测试（先写失败的）

**Files:**
- Create: `tests/components/BottomSheet.test.jsx`

- [ ] **Step 1: Write failing test**

```jsx
// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { BottomSheet } from '../../src/components/BottomSheet.jsx';

describe('BottomSheet', () => {
  it('renders nothing when open=false', () => {
    const { container } = render(
      <BottomSheet open={false} onClose={() => {}}>
        <div>body</div>
      </BottomSheet>,
    );
    expect(container.firstChild).toBeNull();
  });

  it('renders children when open=true', () => {
    render(
      <BottomSheet open={true} onClose={() => {}}>
        <div>body content</div>
      </BottomSheet>,
    );
    expect(screen.getByText('body content')).toBeTruthy();
  });

  it('renders title when provided', () => {
    render(
      <BottomSheet open={true} onClose={() => {}} title="🎒 背包">
        <div>body</div>
      </BottomSheet>,
    );
    expect(screen.getByText('🎒 背包')).toBeTruthy();
  });

  it('renders footer when provided', () => {
    render(
      <BottomSheet open={true} onClose={() => {}} footer={<button>OK</button>}>
        <div>body</div>
      </BottomSheet>,
    );
    expect(screen.getByText('OK')).toBeTruthy();
  });

  it('calls onClose when backdrop clicked', () => {
    const onClose = vi.fn();
    render(
      <BottomSheet open={true} onClose={onClose} data-testid="bs">
        <div>body</div>
      </BottomSheet>,
    );
    fireEvent.click(screen.getByTestId('bs-backdrop'));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('does NOT call onClose when sheet body clicked', () => {
    const onClose = vi.fn();
    render(
      <BottomSheet open={true} onClose={onClose}>
        <div>body</div>
      </BottomSheet>,
    );
    fireEvent.click(screen.getByText('body'));
    expect(onClose).not.toHaveBeenCalled();
  });

  it('calls onClose when Escape pressed', () => {
    const onClose = vi.fn();
    render(
      <BottomSheet open={true} onClose={onClose}>
        <div>body</div>
      </BottomSheet>,
    );
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(onClose).toHaveBeenCalledOnce();
  });
});
```

- [ ] **Step 2: Run, expect fail**

```bash
npm test -- tests/components/BottomSheet.test.jsx 2>&1 | tail -15
```
Expected: FAIL — `Cannot find module '../../src/components/BottomSheet.jsx'`.

---

### Task 7: BottomSheet 实现（最小通过）

**Files:**
- Create: `src/components/BottomSheet.jsx`

- [ ] **Step 1: Write implementation**

```jsx
import React, { useEffect } from 'react';

// 通用 bottom-sheet：mobile 从底滑入，md+ 退化成居中 modal
// API:
//   open       : boolean
//   onClose    : () => void
//   title      : ReactNode (可选)
//   footer     : ReactNode (可选, sticky 底部)
//   children   : 内容区（独立滚动）
//   data-testid: 透传给最外层 div，便于测试 backdrop 选择
export function BottomSheet({ open, onClose, title, footer, children, ...rest }) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  const tid = rest['data-testid'];

  return (
    <div
      className="fixed inset-0 z-50 bg-black/85 backdrop-blur-sm
                 flex items-end justify-center
                 md:items-center md:p-4
                 animate-fadein"
      data-testid={tid ? `${tid}-backdrop` : undefined}
      onClick={onClose}
    >
      <div
        className="bg-[#1a1612] border border-current/40
                   w-full max-h-[90dvh]
                   rounded-t-2xl
                   md:rounded-2xl md:max-w-md md:w-auto
                   flex flex-col
                   animate-slide-up-sheet
                   md:animate-fadein
                   pb-[env(safe-area-inset-bottom)]
                   md:pb-0"
        onClick={(e) => e.stopPropagation()}
        {...(tid ? { 'data-testid': tid } : {})}
      >
        {/* 顶部 handle（视觉装饰，无拖动手势） */}
        <div className="md:hidden flex justify-center pt-2 pb-1 flex-shrink-0">
          <div className="w-9 h-1 rounded-full bg-current/30" />
        </div>
        {title && (
          <div className="px-5 pt-1 pb-2 flex-shrink-0 text-center text-xs tracking-[0.3em] opacity-70"
               style={{ fontFamily: 'monospace', color: '#d4b070' }}>
            {title}
          </div>
        )}
        <div className="flex-1 overflow-y-auto px-5 py-3">
          {children}
        </div>
        {footer && (
          <div className="px-5 py-3 border-t border-current/15 flex-shrink-0">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Run BottomSheet tests, expect PASS**

```bash
npm test -- tests/components/BottomSheet.test.jsx 2>&1 | tail -15
```
Expected: 7 tests PASS.

- [ ] **Step 3: Run full suite to ensure no regression**

```bash
npm test 2>&1 | tail -5
```
Expected: 245 + 7 = 252 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/components/BottomSheet.jsx tests/components/BottomSheet.test.jsx
git commit -m "feat(ui): BottomSheet 通用 sheet 组件 (mobile bottom-sheet / md+ centered)"
```

---

## Phase 4 · BagSheet（TDD）

### Task 8: BagSheet 测试（先写失败的）

**Files:**
- Create: `tests/components/BagSheet.test.jsx`

- [ ] **Step 1: Write failing test**

```jsx
// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BagSheet } from '../../src/components/BagSheet.jsx';

const baseProps = {
  open: true,
  onClose: () => {},
  stats: { academic: 72, wallet: 420, energy: 60, stress: 40, belonging: 35 },
  mealsToday: 1,
  weekInfo: { type: 'term', cn: '学期' },
  attendanceRate: 82,
  classesAttendedThisWeek: 3,
  dissertationProgress: null,
  dissertationTopic: null,
  muted: false,
  onToggleMute: () => {},
  onRestart: () => {},
};

describe('BagSheet', () => {
  it('renders all 5 stat names', () => {
    render(<BagSheet {...baseProps} />);
    expect(screen.getByText(/学业/)).toBeTruthy();
    expect(screen.getByText(/钱包/)).toBeTruthy();
    expect(screen.getByText(/精力/)).toBeTruthy();
    expect(screen.getByText(/压力/)).toBeTruthy();
    expect(screen.getByText(/归属/)).toBeTruthy();
  });

  it('renders meal count', () => {
    render(<BagSheet {...baseProps} mealsToday={1} />);
    expect(screen.getByText(/1\s*\/\s*2/)).toBeTruthy();
  });

  it('renders week type and attendance', () => {
    render(<BagSheet {...baseProps} />);
    expect(screen.getByText(/学期/)).toBeTruthy();
    expect(screen.getByText(/82%/)).toBeTruthy();
    expect(screen.getByText(/3\s*\/\s*6/)).toBeTruthy();
  });

  it('does NOT render dissertation section when type !== dissertation', () => {
    render(<BagSheet {...baseProps} />);
    expect(screen.queryByText(/论文进度/)).toBeNull();
  });

  it('renders dissertation section when type === dissertation', () => {
    render(<BagSheet {...baseProps}
      weekInfo={{ type: 'dissertation', cn: '论文季' }}
      dissertationProgress={45}
      dissertationTopic={{ label: 'AI 在课堂的伦理影响' }}
    />);
    expect(screen.getByText(/论文进度/)).toBeTruthy();
    expect(screen.getByText(/45%/)).toBeTruthy();
    expect(screen.getByText(/AI 在课堂的伦理影响/)).toBeTruthy();
  });

  it('renders mute toggle and restart button', () => {
    render(<BagSheet {...baseProps} muted={false} />);
    expect(screen.getByText(/声音开|音乐|音效/)).toBeTruthy();
    expect(screen.getByText(/重新开始/)).toBeTruthy();
  });

  it('shows muted label when muted', () => {
    render(<BagSheet {...baseProps} muted={true} />);
    expect(screen.getByText(/已静音|🔇/)).toBeTruthy();
  });

  it('renders nothing when open=false', () => {
    const { container } = render(<BagSheet {...baseProps} open={false} />);
    expect(container.firstChild).toBeNull();
  });
});
```

- [ ] **Step 2: Run, expect fail**

```bash
npm test -- tests/components/BagSheet.test.jsx 2>&1 | tail -10
```
Expected: FAIL — `Cannot find module BagSheet.jsx`.

---

### Task 9: BagSheet 实现（最小通过）

**Files:**
- Create: `src/components/BagSheet.jsx`

- [ ] **Step 1: Write implementation**

```jsx
import React, { useState } from 'react';
import { BottomSheet } from './BottomSheet.jsx';

// 5 stat 颜色映射：与 PlayingScreen header 现有逻辑保持一致
function statColor(name, value) {
  if (name === 'academic') {
    if (value >= 70) return '#22c55e';
    if (value >= 50) return undefined;
    if (value >= 35) return '#f97316';
    return '#ef4444';
  }
  if (name === 'wallet') {
    if (value < 0) return '#ef4444';
    if (value < 150) return '#f97316';
    if (value < 400) return '#eab308';
    if (value < 800) return undefined;
    return '#22c55e';
  }
  if (name === 'energy') {
    if (value >= 75) return '#22c55e';
    if (value >= 50) return undefined;
    if (value >= 25) return '#eab308';
    if (value >= 10) return '#f97316';
    return '#ef4444';
  }
  if (name === 'stress') {
    if (value >= 85) return '#ef4444';
    if (value >= 75) return '#f97316';
    if (value >= 60) return '#eab308';
    if (value >= 30) return undefined;
    return '#22c55e';
  }
  if (name === 'belonging') {
    if (value >= 75) return '#22c55e';
    if (value >= 50) return '#a0c890';
    if (value >= 30) return undefined;
    if (value >= 15) return '#f97316';
    return '#ef4444';
  }
  return undefined;
}

function statLabel(name, value) {
  if (name === 'energy') {
    if (value >= 75) return '充沛'; if (value >= 50) return '还行';
    if (value >= 25) return '疲惫'; if (value >= 10) return '虚脱'; return '濒崩';
  }
  if (name === 'stress') {
    if (value >= 95) return '崩盘'; if (value >= 85) return '濒崩';
    if (value >= 75) return '紧绷'; if (value >= 60) return '有点累';
    if (value >= 30) return '能扛'; return '平静';
  }
  if (name === 'belonging') {
    if (value >= 75) return '找到了'; if (value >= 50) return '渐入佳境';
    if (value >= 30) return '适应中'; if (value >= 15) return '有点疏离'; return '孤岛感';
  }
  return null;
}

function StatRow({ icon, name, statKey, value, displayValue }) {
  const color = statColor(statKey, value);
  const fillPct = Math.max(0, Math.min(100, statKey === 'wallet' ? Math.min(100, value/10) : value));
  return (
    <div className="grid grid-cols-[80px_1fr_60px] items-center gap-2 mb-1.5 text-sm">
      <span className="opacity-75">{icon} {name}</span>
      <div className="h-1 bg-current/10 relative">
        <div className="absolute inset-y-0 left-0 transition-all"
             style={{ width: `${fillPct}%`, background: color || '#d4b070' }} />
      </div>
      <span className="text-right text-xs" style={{ fontFamily: 'monospace', color }}>
        {displayValue}
      </span>
    </div>
  );
}

export function BagSheet({
  open, onClose,
  stats, mealsToday,
  weekInfo, attendanceRate, classesAttendedThisWeek,
  dissertationProgress, dissertationTopic,
  muted, onToggleMute, onRestart,
}) {
  const [confirmRestart, setConfirmRestart] = useState(false);

  const mealColor = mealsToday >= 2 ? '#22c55e' : mealsToday === 1 ? '#eab308' : '#ef4444';

  return (
    <BottomSheet open={open} onClose={() => { setConfirmRestart(false); onClose(); }} title="🎒 背包">
      {/* ── 完整状态 ── */}
      <section className="mb-4 p-3 border border-current/20">
        <div className="text-[10px] tracking-[0.2em] opacity-50 mb-2"
             style={{ fontFamily: 'monospace' }}>完整状态</div>
        <StatRow icon="📚" name="学业" statKey="academic" value={stats.academic}
          displayValue={`${stats.academic}%`} />
        <StatRow icon="💰" name="钱包" statKey="wallet" value={stats.wallet}
          displayValue={`£${stats.wallet}`} />
        <StatRow icon="💪" name="精力" statKey="energy" value={stats.energy}
          displayValue={statLabel('energy', stats.energy)} />
        <StatRow icon="🧠" name="压力" statKey="stress" value={stats.stress}
          displayValue={statLabel('stress', stats.stress)} />
        <StatRow icon="🏠" name="归属" statKey="belonging" value={stats.belonging}
          displayValue={statLabel('belonging', stats.belonging)} />
        <div className="flex justify-between items-center mt-2 text-xs"
             style={{ fontFamily: 'monospace' }}>
          <span className="opacity-75">🍴 今日餐</span>
          <span style={{ color: mealColor }}>{mealsToday}/2 顿</span>
        </div>
      </section>

      {/* ── 本周 ── */}
      <section className="mb-4 p-3 border border-current/20">
        <div className="text-[10px] tracking-[0.2em] opacity-50 mb-2"
             style={{ fontFamily: 'monospace' }}>本周</div>
        <div className="flex justify-between text-sm py-0.5">
          <span className="opacity-75">周类型</span>
          <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{weekInfo?.cn || '—'}</span>
        </div>
        <div className="flex justify-between text-sm py-0.5">
          <span className="opacity-75">出勤累计</span>
          <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{attendanceRate}%</span>
        </div>
        <div className="flex justify-between text-sm py-0.5">
          <span className="opacity-75">本周课</span>
          <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{classesAttendedThisWeek}/6</span>
        </div>
        {weekInfo?.type === 'dissertation' && dissertationTopic && (
          <>
            <div className="flex justify-between text-sm py-0.5 mt-2 pt-2 border-t border-current/10">
              <span className="opacity-75">论文进度</span>
              <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{dissertationProgress}%</span>
            </div>
            <div className="text-xs opacity-60 italic mt-1">题目：{dissertationTopic.label}</div>
          </>
        )}
      </section>

      {/* ── 设置 ── */}
      <section className="mb-2 p-3 border border-current/20">
        <div className="text-[10px] tracking-[0.2em] opacity-50 mb-2"
             style={{ fontFamily: 'monospace' }}>设置</div>
        <button onClick={onToggleMute}
          className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all text-sm flex items-center justify-between min-h-[44px]">
          <span>{muted ? '🔇 已静音' : '🔊 声音开'}</span>
          <span className="text-xs opacity-50" style={{ fontFamily: 'monospace' }}>{muted ? 'OFF' : 'ON'}</span>
        </button>
        {!confirmRestart ? (
          <button onClick={() => setConfirmRestart(true)}
            className="w-full text-left p-3 border border-current/40 hover:border-red-400 hover:bg-red-400/5 active:bg-red-400/10 transition-all text-sm min-h-[44px]">
            🗑️ 清空存档 · 重新开始
          </button>
        ) : (
          <div className="border border-red-400/60 p-3 bg-red-400/5">
            <div className="text-xs opacity-80 italic mb-3" style={{ lineHeight: '1.7' }}>
              真的要清空当前进度并重开吗？这一年的所有选择都会消失。
            </div>
            <div className="flex gap-2">
              <button onClick={() => { setConfirmRestart(false); onClose(); onRestart(); }}
                className="flex-1 py-2 border border-red-400/60 text-red-300 hover:bg-red-400/10 active:bg-red-400/15 text-xs tracking-[0.2em] min-h-[44px]">
                确认
              </button>
              <button onClick={() => setConfirmRestart(false)}
                className="flex-1 py-2 border border-current/40 hover:border-current active:bg-current/10 text-xs tracking-[0.2em] min-h-[44px]">
                取消
              </button>
            </div>
          </div>
        )}
        <div className="mt-3 pt-2 border-t border-current/10 text-xs opacity-50 italic" style={{ lineHeight: '1.6' }}>
          每次行动会自动存档到本地。
        </div>
      </section>
    </BottomSheet>
  );
}
```

- [ ] **Step 2: Run BagSheet tests, expect PASS**

```bash
npm test -- tests/components/BagSheet.test.jsx 2>&1 | tail -10
```
Expected: 8 tests PASS.

- [ ] **Step 3: Run full suite, no regression**

```bash
npm test 2>&1 | tail -5
```
Expected: 252 + 8 = 260 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/components/BagSheet.jsx tests/components/BagSheet.test.jsx
git commit -m "feat(ui): BagSheet 替换 GameMenuPanel (3 段：状态/本周/设置)"
```

---

## Phase 5 · 接入 BagSheet 到 App.jsx + 删除 GameMenuPanel

### Task 10: 替换 App.jsx 中的 GameMenuPanel

**Files:**
- Modify: `src/App.jsx:82, 102, 1561-1568`
- Modify: `src/components/Modals.jsx:7-63` (删除 GameMenuPanel)

- [ ] **Step 1: Read context**

```bash
grep -n "GameMenuPanel\|menuOpen\|setMenuOpen" F:/python_work/LinkU/game/src/App.jsx
```

- [ ] **Step 2: 改 App.jsx import**

`src/App.jsx:82` 把 `GameMenuPanel,` 删除；新增一行 import：

```jsx
import { BagSheet } from './components/BagSheet.jsx';
```

- [ ] **Step 3: 改 state 名（menuOpen → bagOpen）**

`src/App.jsx:102` 附近找到 `const [menuOpen, setMenuOpen] = useState(false);`，改为：

```jsx
const [bagOpen, setBagOpen] = useState(false);
```

把所有 `menuOpen` / `setMenuOpen(...)` 全替换为 `bagOpen` / `setBagOpen(...)`（应有 3-4 处）。

- [ ] **Step 4: 改 render 块（约 1561-1568）**

把：

```jsx
{menuOpen && (
  <GameMenuPanel
    muted={muted}
    onToggleMute={() => setMuted(!muted)}
    onRestart={restart}
    onClose={() => setMenuOpen(false)}
  />
)}
```

改为：

```jsx
<BagSheet
  open={bagOpen}
  onClose={() => setBagOpen(false)}
  stats={state.stats}
  mealsToday={state.mealsToday ?? 0}
  weekInfo={weekInfo}
  attendanceRate={attendanceRate}
  classesAttendedThisWeek={classesAttendedThisWeek}
  dissertationProgress={state.dissertationProgress}
  dissertationTopic={state.dissertationTopic}
  muted={muted}
  onToggleMute={() => setMuted(!muted)}
  onRestart={restart}
/>
```

注意：`open` 由 BagSheet 内部根据 `open` prop 决定渲染，不再需要外层 `{bagOpen && ...}`。

- [ ] **Step 5: 删 Modals.jsx 中的 GameMenuPanel**

删除 `src/components/Modals.jsx:7-63`（含上面的 JSDoc 注释和 `export function GameMenuPanel ... }` 整块）。

- [ ] **Step 6: Run tests + sanity build**

```bash
npm test 2>&1 | tail -5
npm run build 2>&1 | tail -5
```
Expected: 全 PASS；build 成功。

- [ ] **Step 7: Manual smoke test**

```bash
$env:PATH = "F:\flutter\bin;" + $env:PATH; npm run dev
```
浏览器打开 dev URL → 走到 PlayingScreen → 点 ⚙️ 应弹出新背包 sheet（旧 menu 视觉应消失）。临时 OK 即可，后续会改 ⚙️ icon。

- [ ] **Step 8: Commit**

```bash
git add src/App.jsx src/components/Modals.jsx
git commit -m "feat(ui): 接入 BagSheet 替换 GameMenuPanel"
```

---

## Phase 6 · PlayingScreen 重构

### Task 11: 抽出 BagButton 入口（header tap + bottom 🎒）

**Files:**
- Modify: `src/components/Screens.jsx` PlayingScreen

- [ ] **Step 1: 改 PlayingScreen 接收新 prop `onOpenBag`，并把现有 `onOpenMenu` rename 为 `onOpenBag`**

App.jsx 已经传 `onOpenMenu={() => setMenuOpen(true)}`，需要改成 `onOpenBag={() => setBagOpen(true)}`。

PlayingScreen 内部所有 `onOpenMenu` 替换为 `onOpenBag`。

- [ ] **Step 2: Run tests**

```bash
npm test 2>&1 | tail -5
```
Expected: 全 PASS。

- [ ] **Step 3: Commit**

```bash
git add src/App.jsx src/components/Screens.jsx
git commit -m "refactor(ui): rename onOpenMenu → onOpenBag for new BagSheet"
```

---

### Task 12: 重构 PlayingScreen 顶层布局为 flex h-[100dvh] 三段

**Files:**
- Modify: `src/components/Screens.jsx` PlayingScreen 的 `return (...)` 块

- [ ] **Step 1: 改 PlayingScreen 顶层 div 结构**

把原来的 `<div className="animate-fadein">` 改为：

```jsx
<div className="animate-fadein flex flex-col h-[100dvh]">
```

并把内部分成三段：
- **段 A (header)**: `flex-shrink-0` —— 装 compact header（Task 13 内容）
- **段 B (content)**: `flex-1 overflow-y-auto` —— 装 tab 切换区（map / phone / link2ur / journal）
- **段 C (footer)**: `flex-shrink-0 border-t border-current/30 bg-[#1a1612]` —— 装 sticky CTA + tabs（Task 14 内容）

外层 App.jsx 的容器 (`relative max-w-3xl mx-auto px-3 py-6`) 与新 100dvh 冲突 —— 把 PlayingScreen 顶层改为：

```jsx
<div className="animate-fadein flex flex-col h-[100dvh] -mx-3 -my-6">
  {/* segments */}
</div>
```

`-mx-3 -my-6` 是为了「打破」外层 padding，让 sheet 真正占满 dvh。其他 screen (intro/plane 等) 不动。

- [ ] **Step 2: 暂时把现有 header / content / footer 平铺塞进新 3 段，保证不 broken**

保留所有现有渲染逻辑，只是包装到对应 div：

```jsx
return (
  <div className="animate-fadein flex flex-col h-[100dvh] -mx-3 -my-6">
    {/* === A: HEADER === */}
    <div className="flex-shrink-0 px-3 pt-[env(safe-area-inset-top)]">
      {/* 现有 header 代码（顶部状态 + stats 5-grid + 出勤面板 + tabs）暂时全塞这里 */}
      ...
    </div>

    {/* === B: CONTENT === */}
    <div className="flex-1 overflow-y-auto px-3">
      {/* {tab === 'map' && ...} 等四块 */}
    </div>

    {/* === C: FOOTER === */}
    <div className="flex-shrink-0 px-3 py-3 border-t border-current/30 bg-[#1a1612]
                    pb-[max(0.75rem,env(safe-area-inset-bottom))]">
      {/* 现有 ⚙️ menu + 🌙 结束今天 暂时塞这里 */}
    </div>
  </div>
);
```

- [ ] **Step 3: Run tests**

```bash
npm test 2>&1 | tail -5
```
Expected: 全 PASS（vitest 不渲染 UI）。

- [ ] **Step 4: Manual smoke**

dev 启动 → playing screen → 滚动 content 时 header/footer 应固定不动。

- [ ] **Step 5: Commit**

```bash
git add src/components/Screens.jsx
git commit -m "refactor(ui): PlayingScreen 顶层改 flex h-[100dvh] 三段布局"
```

---

### Task 13: Header 压缩成 LEAN（pill + 4 stats line + tap hint）

**Files:**
- Modify: `src/components/Screens.jsx` PlayingScreen 段 A 内容

- [ ] **Step 1: 替换段 A 内容**

把段 A 内的全部现有 header HTML（DAY/WEEK 标题 + stats 5-grid + 出勤面板 + 论文面板 + tabs）**全部删除**，替换为：

```jsx
<button
  type="button"
  onClick={() => { audio?.click?.(); onOpenBag(); }}
  className="w-full text-left px-3 pt-2 pb-1.5 border-b border-current/20
             active:bg-current/5 transition-colors"
>
  {/* row 1: pill + ACTIONS dots */}
  <div className="flex justify-between items-center">
    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-mono tracking-wider"
          style={{
            background: 'rgba(212,176,112,0.15)',
            border: '1px solid rgba(212,176,112,0.4)',
            color: '#d4b070',
          }}>
      D{day} · W{week} · 周{dayNames[dayOfWeek-1]}
      {weekInfo && <> · {weekTypeIcon} {weekInfo.cn}</>}
      {weather && <> · {WEATHERS[weather]?.emoji}</>}
      {weekInfo?.deadline && <span className="ml-1.5 text-orange-300">⏰</span>}
    </span>
    <div className="flex gap-1">
      {[...Array(3)].map((_, i) => (
        <div key={i} className={`w-2 h-2 rounded-full ${
          i < actionsLeft ? 'bg-current/80' : 'bg-current/15 border border-current/30'
        }`} />
      ))}
    </div>
  </div>

  {/* row 2: 4 stats inline (省略归属) */}
  <div className="mt-1.5 flex justify-between text-[11px]" style={{ fontFamily: 'monospace' }}>
    {(() => {
      const a = stats.academic;
      const aColor = a >= 70 ? '#22c55e' : a >= 50 ? undefined : a >= 35 ? '#f97316' : '#ef4444';
      const w = stats.wallet;
      const wColor = w < 0 ? '#ef4444' : w < 150 ? '#f97316' : w < 400 ? '#eab308' : w < 800 ? undefined : '#22c55e';
      const e = stats.energy;
      const eText = e >= 75 ? '充沛' : e >= 50 ? '还行' : e >= 25 ? '疲惫' : e >= 10 ? '虚脱' : '濒崩';
      const eColor = e >= 75 ? '#22c55e' : e >= 50 ? undefined : e >= 25 ? '#eab308' : e >= 10 ? '#f97316' : '#ef4444';
      const s = props.gameState?.stress ?? 25;
      const sText = s >= 95 ? '崩盘' : s >= 85 ? '濒崩' : s >= 75 ? '紧绷' : s >= 60 ? '有点累' : s >= 30 ? '能扛' : '平静';
      const sColor = s >= 85 ? '#ef4444' : s >= 75 ? '#f97316' : s >= 60 ? '#eab308' : s >= 30 ? undefined : '#22c55e';
      return (
        <>
          <span>📚 <span style={{ color: aColor }}>{a}%</span></span>
          <span style={{ color: wColor }}>💰 £{w}</span>
          <span>💪 <span style={{ color: eColor }}>{eText}</span></span>
          <span>🧠 <span style={{ color: sColor }}>{sText}</span></span>
        </>
      );
    })()}
  </div>

  {/* row 3: tap hint */}
  <div className="text-center text-[9px] opacity-40 mt-1" style={{ fontFamily: 'monospace' }}>
    ▼ 点击查看完整状态
  </div>
</button>
```

注意：`audio` 还没 import，需要确认 Screens.jsx 顶部是否已 import audio（之前 grep 看到 `import { audio } from '../engine/audio.js';` 在第 2 行 — 已有）。

确保 `WEATHERS` 也已 import（应已存在）。

- [ ] **Step 2: 删除原 header 块（DAY/WEEK 标题 + 出勤提示 + 论文进度 + 旧 tab strip 全部）**

旧 header（约 235-388 行的 PlayingScreen 内）整段移除。**保留** tab content 渲染（`{tab === 'map' && <MapView ...}` 等）—— 这些去段 B。

- [ ] **Step 3: Run tests**

```bash
npm test 2>&1 | tail -5
```

- [ ] **Step 4: Manual smoke**

dev → playing screen → 看到新 LEAN header → 点击 header 弹出背包。

- [ ] **Step 5: Commit**

```bash
git add src/components/Screens.jsx
git commit -m "feat(ui): PlayingScreen LEAN header (pill + 4 stats + tap-to-bag)"
```

---

### Task 14: 底部 sticky CTA + 4-tab 底栏

**Files:**
- Modify: `src/components/Screens.jsx` PlayingScreen 段 C

- [ ] **Step 1: 替换段 C 内容**

把段 C 内的现有 ⚙️ menu + 🌙 结束今天 替换为「上层 CTA + 下层 tabs」结构：

```jsx
<>
  {/* 上层：🎒 + 🌙 结束今天 */}
  <div className="px-3 pt-3 pb-2 flex gap-2 border-t border-current/30 bg-[#1a1612]">
    <button onClick={() => { audio?.click?.(); onOpenBag(); }}
      aria-label="背包"
      className="px-4 min-h-[44px] border border-current/60 hover:bg-current/10 active:bg-current/15 transition-colors text-sm">
      🎒
    </button>
    <button onClick={onEndDay}
      className="flex-1 min-h-[44px] py-3 border border-current/60 tracking-[0.3em] text-sm hover:bg-current hover:text-black active:bg-current/30 transition-colors duration-300">
      🌙 结束今天
    </button>
  </div>

  {/* 下层：4 tabs */}
  <div className="grid grid-cols-4 border-t border-current/20 bg-[#1a1612]
                  pb-[max(0.5rem,env(safe-area-inset-bottom))]">
    <button onClick={() => { audio?.click?.(); setTab('map'); }}
      className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'map' ? 'text-[#d4b070]' : 'opacity-55'}`}>
      <span className="text-[18px] leading-none">🗺️</span>
      <span className="text-[10px] mt-0.5 tracking-wide">地图</span>
    </button>
    <button onClick={() => {
      audio?.click?.();
      setTab('phone'); onReadMessages(); onReadGroup && onReadGroup();
    }}
      className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'phone' ? 'text-[#d4b070]' : 'opacity-55'}`}>
      <span className="text-[18px] leading-none">💬</span>
      <span className="text-[10px] mt-0.5 tracking-wide">
        消息{(unreadMessages + unreadGroup) > 0 &&
          <span className="ml-0.5 px-1 rounded text-white text-[8px]" style={{ background: '#f97316' }}>
            {unreadMessages + unreadGroup}
          </span>}
      </span>
    </button>
    {flags?.link2ur_discovered ? (
      <button onClick={() => { audio?.click?.(); setTab('link2ur'); }}
        className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'link2ur' ? 'text-[#d4b070]' : 'opacity-55'}`}>
        <span className="text-[18px] leading-none" style={{ color: '#007AFF' }}>L</span>
        <span className="text-[10px] mt-0.5 tracking-wide">Link2Ur</span>
      </button>
    ) : (
      <div className="flex flex-col items-center py-2 opacity-30">
        <span className="text-[18px] leading-none">🔒</span>
        <span className="text-[10px] mt-0.5 tracking-wide">锁定</span>
      </div>
    )}
    <button onClick={() => { audio?.click?.(); setTab('journal'); }}
      className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'journal' ? 'text-[#d4b070]' : 'opacity-55'}`}>
      <span className="text-[18px] leading-none">📔</span>
      <span className="text-[10px] mt-0.5 tracking-wide">
        手账{diaryTotal > 0 && <span className="ml-0.5 opacity-60">·{diaryTotal}</span>}
      </span>
    </button>
  </div>
</>
```

注意 `setTab` / `unreadMessages` / `unreadGroup` / `flags` / `diaryTotal` 都已在 PlayingScreen props 解构内，直接用。

- [ ] **Step 2: 把段 C 外层 div 的 `pb-[max(...)]` 移除**（因为内层 tabs 已经 handle 了 safe-area）

把段 C 外层从 Task 12 的：
```jsx
<div className="flex-shrink-0 px-3 py-3 border-t border-current/30 bg-[#1a1612]
                pb-[max(0.75rem,env(safe-area-inset-bottom))]">
```
改为：
```jsx
<div className="flex-shrink-0">
  <>...上层 + 下层...</>
</div>
```

（背景色和 border 在内层各自给）

- [ ] **Step 3: Run tests**

```bash
npm test 2>&1 | tail -5
```

- [ ] **Step 4: Manual smoke**

dev → playing → 看到底部 sticky CTA + 4 tabs，切 tab 正常，点 🎒 弹背包，点 🌙 走 endDay 流程。

- [ ] **Step 5: Commit**

```bash
git add src/components/Screens.jsx
git commit -m "feat(ui): PlayingScreen sticky bottom CTA + 4-tab nav"
```

---

## Phase 7 · Modal 改 BottomSheet

### Task 15: Modals.jsx — EventModal / StoryModal / NpcDialogModal（前 3 个）

**Files:**
- Modify: `src/components/Modals.jsx:65-185` (3 modals)

- [ ] **Step 1: EventModal 改造**

`Modals.jsx:65-99` 替换为：

```jsx
export function EventModal({ event, feedback, onChoose, onDismiss }) {
  const banner = getSceneForEvent(event?.id);
  return (
    <BottomSheet open={true} onClose={onDismiss}
      title={<>EVENT</>}>
      {banner && (
        <div className="relative w-full -mx-5 mb-3" style={{ aspectRatio: '16 / 9' }}>
          <img src={banner} alt="" className="w-full h-full object-cover" />
          <div className="absolute inset-0"
            style={{ background: 'linear-gradient(180deg, transparent 60%, #1a1612 100%)' }} />
        </div>
      )}
      <h2 className="text-xl mb-3 font-light">{event.title}</h2>
      <div className="text-sm leading-relaxed mb-4 opacity-90" style={{ lineHeight: '1.8' }}>
        {event.body}
      </div>
      {!feedback ? (
        (event.choices || [{ label: '继续', effect: event.effect || {}, feedback: event.feedback || '...' }]).map((c, i) => (
          <button key={i} onClick={() => onChoose(c)}
            className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all min-h-[44px]">
            <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65+i)}.</span>
            {c.label}
          </button>
        ))
      ) : (
        <>
          <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors min-h-[44px]">CONTINUE</button>
        </>
      )}
    </BottomSheet>
  );
}
```

- [ ] **Step 2: StoryModal 改造（Modals.jsx:101-126）**

```jsx
export function StoryModal({ chapter, lineName, feedback, onChoose, onDismiss }) {
  return (
    <BottomSheet open={true} onClose={onDismiss}
      title={<span style={{ color: '#d4b070' }}>📖 STORY · {lineName}</span>}>
      <div className="text-xs opacity-50 mb-3" style={{ fontFamily: 'monospace' }}>CHAPTER · {chapter.title}</div>
      <h2 className="text-xl mb-3 font-light">{chapter.title_full}</h2>
      <div className="text-sm leading-relaxed mb-4 opacity-90" style={{ lineHeight: '1.8' }}>{chapter.body}</div>
      {!feedback ? (
        chapter.choices.map((c, i) => (
          <button key={i} onClick={() => onChoose(c)}
            className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all min-h-[44px]">
            <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65+i)}.</span>
            {c.label}
          </button>
        ))
      ) : (
        <>
          <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors min-h-[44px]">CONTINUE</button>
        </>
      )}
    </BottomSheet>
  );
}
```

- [ ] **Step 3: NpcDialogModal 改造（Modals.jsx:128-185）**

把外层 `<div className="fixed inset-0 z-40 flex items-center...">` + `<div className="bg-[#1a1612]...">` 包装替换为 `<BottomSheet open={true} onClose={onDismiss}>`，删除 `p-5`（BottomSheet 已有），其余内部内容（NpcAvatar / topics / feedback）保留。

- [ ] **Step 4: 在文件顶部 import BottomSheet**

`src/components/Modals.jsx:1-3` 加：

```jsx
import { BottomSheet } from './BottomSheet.jsx';
```

- [ ] **Step 5: Run tests + manual**

```bash
npm test 2>&1 | tail -5
```
dev：触发 NPC dialog（点 NPC 头像）→ 看新 bottom-sheet 形态。触发 story chapter / event 模态。

- [ ] **Step 6: Commit**

```bash
git add src/components/Modals.jsx
git commit -m "refactor(ui): EventModal/StoryModal/NpcDialogModal → BottomSheet"
```

---

### Task 16: Modals.jsx — 剩余 9 个 modal

**Files:**
- Modify: `src/components/Modals.jsx:187-end` (StrangerEventModal / CrisisModal / AtYouModal / DreamModal / InsomniaModal / NostalgiaModal / ParentsChapterModal / 等)

- [ ] **Step 1: 逐个替换外层包装**

每个 modal 的：
```jsx
<div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
     style={{ background: 'rgba(...)' }}>
  <div className="bg-[#1a1612] border border-... max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
    {/* 内部内容 */}
  </div>
</div>
```

替换为：
```jsx
<BottomSheet open={true} onClose={onDismiss /* 或对应的 close handler */}>
  {/* 内部内容（删 p-5，BottomSheet 已含 padding） */}
</BottomSheet>
```

如内部有「头部 monospace label + 标题」结构，可保留为内容首行（不强制走 BottomSheet `title` prop）。

- [ ] **Step 2: 边界 case：modal 没有 onDismiss 但有其他 close handler**

如 CrisisModal 用 `onDismiss`、StrangerEventModal 用 `onDismiss`。逐个找文件内对应 prop 名传给 `onClose`。

- [ ] **Step 3: Run tests**

```bash
npm test 2>&1 | tail -5
```

- [ ] **Step 4: Manual：触发尽可能多的 modal**

清单（手动触发用）：
- 雪 4:38 危机 (CrisisModal): 高 stress 时
- 陌生人事件 (StrangerEventModal): 概率触发
- 梦 (DreamModal): 高 stress + 入睡
- 失眠 (InsomniaModal): 高 stress + 入睡
- 怀乡 (NostalgiaModal): 节日触发
- 父母章节 (ParentsChapterModal): 特定 week 触发
- AtYou 事件 (AtYouModal): 概率
- 旅行事件等

- [ ] **Step 5: Commit**

```bash
git add src/components/Modals.jsx
git commit -m "refactor(ui): 剩余 9 个 modal → BottomSheet"
```

---

### Task 17: Screens.jsx — HolidayScreen + 其余 4 个 modal

**Files:**
- Modify: `src/components/Screens.jsx:450+` HolidayScreen + 其余 4 处 `fixed inset-0 z-(40|50)`

- [ ] **Step 1: HolidayScreen (Screens.jsx:450+) 改造**

外层 `<div className="fixed inset-0 z-50 flex items-center justify-center p-4">` 替换为 `<BottomSheet open={true} onClose={onDismiss}>`，删除内层 padding 容器，保留 holiday 自己的内容结构。

- [ ] **Step 2: 处理 Screens.jsx:566 / 625 / 666 / 721 四处 modal（grep 结果）**

每个用同样 pattern 替换。

- [ ] **Step 3: 在 Screens.jsx 顶部 import BottomSheet**

`src/components/Screens.jsx:1-12` 加：

```jsx
import { BottomSheet } from './BottomSheet.jsx';
```

- [ ] **Step 4: Run tests**

```bash
npm test 2>&1 | tail -5
```

- [ ] **Step 5: Manual：触发圣诞/复活节 holiday + 其他 4 个 modal**

- [ ] **Step 6: Commit**

```bash
git add src/components/Screens.jsx
git commit -m "refactor(ui): HolidayScreen + 4 modals → BottomSheet"
```

---

### Task 18: AchievementsView.jsx — AchievementCardModal + WrappedPosterModal

**Files:**
- Modify: `src/components/AchievementsView.jsx:165, 241`

- [ ] **Step 1: AchievementCardModal (line 165) 改造**

外层 `<div className="fixed inset-0 z-50 ...">` 替换为 `<BottomSheet open={true} onClose={onClose}>`。

- [ ] **Step 2: WrappedPosterModal (line 241) 同样改造**

- [ ] **Step 3: Import**

`src/components/AchievementsView.jsx:1-3` 加：

```jsx
import { BottomSheet } from './BottomSheet.jsx';
```

- [ ] **Step 4: Run tests + manual**

dev：手账 → 成就卡 → 看新 bottom-sheet。

- [ ] **Step 5: Commit**

```bash
git add src/components/AchievementsView.jsx
git commit -m "refactor(ui): AchievementCard/WrappedPoster modals → BottomSheet"
```

---

## Phase 8 · 触控反馈系统化补充

### Task 19: 给现有 hover: 类按钮成对加 active:

**Files:**
- Modify: `src/components/*.jsx`（已知 hover: 用法）

- [ ] **Step 1: 列出所有 hover: 用法**

```bash
grep -rn "hover:bg-current\|hover:bg-amber\|hover:bg-red\|hover:border-current\|hover:border-amber\|hover:border-red" F:/python_work/LinkU/game/src/components/ | wc -l
```

应在 ~30-40 处。

- [ ] **Step 2: 按形态成对补 active:（用 sed 风格批量但需 review）**

经验对应：
- `hover:bg-current hover:text-black` → 加 `active:bg-current/30`
- `hover:bg-current/5` → 加 `active:bg-current/10`
- `hover:bg-amber-300/5` → 加 `active:bg-amber-300/10`
- `hover:bg-red-400/5` → 加 `active:bg-red-400/10`
- `hover:border-current` → 加 `active:bg-current/5`（border 在 mobile 不够明显，加底色）

挨个文件逐个 button 用 Edit 工具加。**不要 sed 一刀切**——避免改坏意外字符串。

- [ ] **Step 3: Run tests**

```bash
npm test 2>&1 | tail -5
```

- [ ] **Step 4: Manual：手机 / DevTools mobile 模拟点击各类按钮验证 tap 反馈**

- [ ] **Step 5: Commit**

```bash
git add src/components/
git commit -m "feat(mobile): 给所有 hover: 按钮成对加 active: 触控反馈"
```

---

## Phase 9 · 端到端验证 + 收尾

### Task 20: 完整手动验证清单

**Files:**
- (无；只做 manual QA)

- [ ] **Step 1: dev 启动**

```bash
$env:PATH = "F:\flutter\bin;" + $env:PATH; npm run dev -- --host 0.0.0.0
```

记录 LAN URL，手机连同 WiFi 直接访问。

- [ ] **Step 2: 桌面 Chrome DevTools mobile 模拟（iPhone 12 Pro）走完整路径**

- BEGIN → birthday → plane → arrival → 进入 playing
- 切 4 个 tab，每个都看 sticky CTA / tabs 是否常驻
- 点 header → 弹背包，验证 5 stat / 本周信息显示正确
- 触发 2-3 个 modal（NPC dialog / story chapter / holiday）→ bottom-sheet 形态正确
- 进入 minigame（Pret/Essay/Match）→ **不应**变 bottom-sheet（本计划 out-of-scope）
- 横屏切换 → 不能崩，背包仍能开

- [ ] **Step 3: 真手机 iOS Safari 验证（如果有设备）**

- 同上路径
- 重点：
  - safe-area-inset-bottom 是否生效（底栏有适当下边距，home indicator 不遮按钮）
  - autoplay 解锁后背景音乐是否响
  - 100dvh 是否正确（URL bar 收缩时不出黑边）
  - 长按文本不弹 iOS 选词菜单

- [ ] **Step 4: 真手机 Android Chrome 验证（如果有设备）**

- [ ] **Step 5: 不通过的项 → 列出回 issue 单独修，通过则继续**

---

### Task 21: 整理 + 最终 commit

**Files:**
- (各种 polish)

- [ ] **Step 1: 检查是否有遗漏的 .gitignore / 临时文件**

```bash
git -C F:/python_work/LinkU/game status
```

- [ ] **Step 2: 跑全 suite + build**

```bash
npm test 2>&1 | tail -5
npm run build 2>&1 | tail -5
```

- [ ] **Step 3: 如果上面 commit 间漏了文件、改了 import 路径 等收尾，最后一个 commit 收口**

```bash
git add -p   # 选择性 stage
git commit -m "chore(mobile): 收尾 polish"
```

- [ ] **Step 4: 推送**

```bash
git push origin main
```

---

## 验证矩阵

| 测试项 | 方式 | 通过条件 |
|---|---|---|
| 全 vitest 通过 | `npm test` | 260+ tests PASS |
| BottomSheet 单测 | 自动 | 7/7 PASS |
| BagSheet 单测 | 自动 | 8/8 PASS |
| build 成功 | `npm run build` | 0 error |
| 桌面 Chrome 走完 onboarding+playing | manual | 不崩 |
| iPhone Safari 走完同流程 | manual | 不崩 + 底栏避开 home indicator |
| 背景音乐自动响 | manual mobile | 进 playing 后听到 ambient |
| 长按文本不弹选词菜单 | manual iOS | 不弹 |
| 横屏切换 | manual | 不崩 |

---

## Out-of-scope（明确不做，记录）

- Minigames bottom-sheet 化（v2 评估）
- BottomSheet 拖动手势关闭（v2）
- 横屏专属布局优化（v2）
- PWA manifest（v2）
- 触觉反馈 Vibration API（v2）
- 字号 / 字体设置（v2）
- 完整 a11y aria-label 补完（v2）
