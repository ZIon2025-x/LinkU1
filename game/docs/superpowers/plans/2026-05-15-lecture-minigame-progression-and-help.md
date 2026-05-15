# Lecture Minigame · 渐进解锁 + 全游戏帮助系统 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `lectureMinigame.js` 已写好但没接的 tier 系统接到 UI 上，加上首次升级仪式；同时给所有 6 个 minigame 加共享的 `?` 详情按钮，并补上 Essay / Match 缺失的 intro 屏。

**Architecture:** 一个新共享组件 `MinigameRulesModal.jsx` 提供 `<MinigameHelpButton>` + `<MinigameRulesModal>`；每个 minigame 内部把规则正文抽成本地常量 / 子组件供 intro 屏与 modal 复用，避免双份维护；Lecture 通过新增 `lecture_tier2_seen` / `lecture_tier3_seen` 两个 `state.flags` 标记首次升级。

**Tech Stack:** React 18 + Vite + Tailwind + Vitest + @testing-library/react，沿用现有 `state.flags` + `SET_FLAG` action 机制。

**Spec：** `docs/superpowers/specs/2026-05-15-lecture-minigame-progression-and-help-design.md`

**Branch policy：** 直接 commit 到 `main`（per user memory `feedback_direct_to_main`），不开 feature 分支。

---

## File Structure

```
新建:
  src/components/MinigameRulesModal.jsx      ~80 行 — 两个 export
  tests/lectureMinigame.test.js              ~60 行 — 数据层 tier API 测试
  tests/components/MinigameRulesModal.test.jsx ~80 行 — 模态 smoke 测试

修改:
  src/components/Minigames.jsx               6 个 minigame 全改 (LectureMinigame 改动最大)
  src/App.jsx                                LectureMinigame call site 多传 2 个 prop

不动:
  src/data/lectureMinigame.js                tier 函数已就绪
  src/engine/state.js                        现有 SET_FLAG action 够用
```

每个 minigame 在文件内本地定义一个 `XxxRulesBody` 组件（或常量 JSX），同时被 `intro/ready` phase 与 `MinigameRulesModal` 引用——文案只一处维护。

---

## Task 1: 给 lectureMinigame.js 的 tier API 加单元测试

> 这两个函数已存在但没测试。先固化行为，后续如果 tier 边界要调，测试会守住回归。

**Files:**
- Create: `tests/lectureMinigame.test.js`

- [ ] **Step 1: 写测试**

```js
// tests/lectureMinigame.test.js
import { describe, it, expect } from 'vitest';
import {
  lectureDirTier,
  lectureDirInfo,
  isLectureAdjacent,
} from '../src/data/lectureMinigame.js';

describe('lectureDirTier', () => {
  it('W1-10 returns tier 1', () => {
    expect(lectureDirTier(1)).toBe(1);
    expect(lectureDirTier(10)).toBe(1);
  });
  it('W11-22 returns tier 2', () => {
    expect(lectureDirTier(11)).toBe(2);
    expect(lectureDirTier(22)).toBe(2);
  });
  it('W23+ returns tier 3', () => {
    expect(lectureDirTier(23)).toBe(3);
    expect(lectureDirTier(40)).toBe(3);
  });
});

describe('lectureDirInfo', () => {
  it('tier 1 only allows horizontal', () => {
    const info = lectureDirInfo(5);
    expect(info.tier).toBe(1);
    expect(info.dirs).toEqual(['h']);
  });
  it('tier 2 allows horizontal + vertical', () => {
    const info = lectureDirInfo(15);
    expect(info.tier).toBe(2);
    expect(info.dirs).toEqual(['h', 'v']);
  });
  it('tier 3 allows all 8 directions', () => {
    const info = lectureDirInfo(30);
    expect(info.tier).toBe(3);
    expect(info.dirs).toEqual(['h', 'v', 'd']);
  });
});

describe('isLectureAdjacent', () => {
  const a = { r: 5, c: 5 };
  it('tier 1 (h only) — horizontal yes, vertical no, diagonal no', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 6 }, ['h'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 5 }, ['h'])).toBe(false);
    expect(isLectureAdjacent(a, { r: 6, c: 6 }, ['h'])).toBe(false);
  });
  it('tier 2 (h+v) — horizontal yes, vertical yes, diagonal no', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 6 }, ['h', 'v'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 5 }, ['h', 'v'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 6 }, ['h', 'v'])).toBe(false);
  });
  it('tier 3 (h+v+d) — all 8 directions allowed', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 6 }, ['h', 'v', 'd'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 5 }, ['h', 'v', 'd'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 6, c: 6 }, ['h', 'v', 'd'])).toBe(true);
    expect(isLectureAdjacent(a, { r: 4, c: 4 }, ['h', 'v', 'd'])).toBe(true);
  });
  it('rejects same cell, non-adjacent, null', () => {
    expect(isLectureAdjacent(a, { r: 5, c: 5 }, ['h', 'v', 'd'])).toBe(false);
    expect(isLectureAdjacent(a, { r: 7, c: 5 }, ['h', 'v', 'd'])).toBe(false);
    expect(isLectureAdjacent(null, a, ['h', 'v', 'd'])).toBe(false);
    expect(isLectureAdjacent(a, null, ['h', 'v', 'd'])).toBe(false);
  });
});
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- lectureMinigame`
Expected: 所有 11 个 it() PASS（函数已存在）。

- [ ] **Step 3: Commit**

```bash
git add tests/lectureMinigame.test.js
git commit -m "test(lecture): 给 tier API 加单元测试 (lectureDirInfo / isLectureAdjacent)"
```

---

## Task 2: 创建共享组件 MinigameRulesModal.jsx

**Files:**
- Create: `src/components/MinigameRulesModal.jsx`
- Create: `tests/components/MinigameRulesModal.test.jsx`

- [ ] **Step 1: 写组件 smoke 测试**

```jsx
// tests/components/MinigameRulesModal.test.jsx
// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import {
  MinigameRulesModal,
  MinigameHelpButton,
} from '../../src/components/MinigameRulesModal.jsx';

describe('MinigameRulesModal', () => {
  it('renders nothing when open=false', () => {
    const { container } = render(
      <MinigameRulesModal open={false} onClose={() => {}} title="T">
        body
      </MinigameRulesModal>,
    );
    expect(container.firstChild).toBeNull();
  });

  it('renders title + children when open=true', () => {
    render(
      <MinigameRulesModal open={true} onClose={() => {}} title="LECTURE 玩法">
        <p>规则正文</p>
      </MinigameRulesModal>,
    );
    expect(screen.getByText('LECTURE 玩法')).toBeTruthy();
    expect(screen.getByText('规则正文')).toBeTruthy();
  });

  it('calls onClose when backdrop clicked', () => {
    const onClose = vi.fn();
    render(
      <MinigameRulesModal open={true} onClose={onClose} title="T">
        body
      </MinigameRulesModal>,
    );
    fireEvent.click(screen.getByTestId('rules-modal-backdrop'));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('calls onClose when 明白了 button clicked', () => {
    const onClose = vi.fn();
    render(
      <MinigameRulesModal open={true} onClose={onClose} title="T">
        body
      </MinigameRulesModal>,
    );
    fireEvent.click(screen.getByText('明白了'));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('does NOT call onClose when modal body clicked', () => {
    const onClose = vi.fn();
    render(
      <MinigameRulesModal open={true} onClose={onClose} title="T">
        <p>body</p>
      </MinigameRulesModal>,
    );
    fireEvent.click(screen.getByText('body'));
    expect(onClose).not.toHaveBeenCalled();
  });
});

describe('MinigameHelpButton', () => {
  it('renders ? glyph and calls onClick', () => {
    const onClick = vi.fn();
    render(<MinigameHelpButton onClick={onClick} />);
    const btn = screen.getByRole('button', { name: /玩法说明/i });
    expect(btn.textContent).toContain('?');
    fireEvent.click(btn);
    expect(onClick).toHaveBeenCalledOnce();
  });
});
```

- [ ] **Step 2: 跑测试看失败**

Run: `npm test -- MinigameRulesModal`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: 实现组件**

```jsx
// src/components/MinigameRulesModal.jsx
import React, { useEffect } from 'react';

export function MinigameHelpButton({ onClick }) {
  return (
    <button
      onClick={onClick}
      title="玩法说明"
      aria-label="玩法说明"
      className="absolute top-3 right-3 w-7 h-7 flex items-center justify-center
                 border border-current/40 rounded-full text-sm
                 hover:bg-current/10 transition-colors"
      style={{ fontFamily: 'monospace' }}
    >
      ?
    </button>
  );
}

export function MinigameRulesModal({ open, onClose, title, children }) {
  // ESC 关闭
  useEffect(() => {
    if (!open) return;
    const handler = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      data-testid="rules-modal-backdrop"
      onClick={onClose}
      className="fixed inset-0 z-[60] flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'rgba(10, 8, 6, 0.85)' }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="bg-[#1a1612] border border-current/50 max-w-md w-full p-5 max-h-[85vh] overflow-y-auto"
      >
        <div
          className="text-xs tracking-[0.3em] mb-3 opacity-60"
          style={{ fontFamily: 'monospace' }}
        >
          📖 {title}
        </div>
        <div className="text-sm" style={{ lineHeight: '1.85' }}>
          {children}
        </div>
        <button
          onClick={onClose}
          className="w-full mt-4 py-2 border border-current text-xs tracking-[0.2em]
                     hover:bg-current hover:text-black transition-colors"
        >
          明白了
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: 跑测试看通过**

Run: `npm test -- MinigameRulesModal`
Expected: 6 个 it() 全 PASS。

- [ ] **Step 5: Commit**

```bash
git add src/components/MinigameRulesModal.jsx tests/components/MinigameRulesModal.test.jsx
git commit -m "feat(minigame): 加共享 MinigameRulesModal + HelpButton"
```

---

## Task 3: LectureMinigame — 接线 tier 系统 + 动态 intro 文案 + 非法方向反馈

**Files:**
- Modify: `src/components/Minigames.jsx`（LectureMinigame，约 line 650-786）

- [ ] **Step 1: 改 import**

把 `src/components/Minigames.jsx` 第 6-7 行附近的 lecture import 加两个新名字：

```jsx
// before:
WORD_SET, LECTURE_THEMES, pickLectureTheme, lectureTimeForWeek,
scoreWord, lectureAcademic, generateLectureGrid,

// after:
WORD_SET, LECTURE_THEMES, pickLectureTheme, lectureTimeForWeek,
scoreWord, lectureAcademic, generateLectureGrid,
lectureDirInfo, isLectureAdjacent,
```

- [ ] **Step 2: 在 LectureMinigame 顶部加 dirInfo memo（line 651 附近）**

```jsx
// 在 const totalTime = useMemo(...) 之后加:
const dirInfo = useMemo(() => lectureDirInfo(week || 1), [week]);
```

- [ ] **Step 3: 替换本地 isAdjacent + 加非法方向反馈（line 680 附近）**

把 line 680-683 的：

```jsx
const isAdjacent = useCallback((a, b) => {
  if (!a || !b) return false;
  return Math.abs(a.r - b.r) <= 1 && Math.abs(a.c - b.c) <= 1 && !(a.r === b.r && a.c === b.c);
}, []);
```

替换为：

```jsx
const isAdjacent = useCallback((a, b) => isLectureAdjacent(a, b, dirInfo.dirs), [dirInfo]);
```

然后改 `tapCell()` 函数（line 685-698），让非法方向给出反馈：

```jsx
function tapCell(r, c) {
  if (phase !== 'playing') return;
  audio.click();
  const last = path[path.length - 1];
  const prev = path[path.length - 2];
  if (prev && prev.r === r && prev.c === c) {
    setPath(path.slice(0, -1));
    return;
  }
  if (path.some(p => p.r === r && p.c === c)) return;
  if (path.length === 0) {
    setPath([...path, { r, c }]);
    return;
  }
  if (isAdjacent(last, { r, c })) {
    setPath([...path, { r, c }]);
    return;
  }
  // 不相邻或方向受 tier 限制 — 给反馈
  const dr = Math.abs(last.r - r);
  const dc = Math.abs(last.c - c);
  if (dr <= 1 && dc <= 1 && !(dr === 0 && dc === 0)) {
    // 是相邻 cell 但被 tier 限制
    let dirName = '';
    if (dr === 1 && dc === 0) dirName = '竖';
    else if (dr === 1 && dc === 1) dirName = '斜';
    if (dirName) {
      audio.fail();
      setLastWordFeedback({
        word: '',
        message: `W${week} 还不能${dirName}着连 (本周:${dirInfo.label})`,
        bad: true,
      });
    }
  }
}
```

- [ ] **Step 4: intro 屏文案动态化（line 769-786）**

把 line 771-780 的 intro 内容替换为：

```jsx
<div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.85' }}>
  Whitmore 在黑板上写理论。你的笔记本上是一团字母。<br/>
  <br/>
  <span style={{ color: '#d4b070' }}>· 本周可连：<strong>{dirInfo.label}</strong>（{dirInfo.desc}）</span><br/>
  · 点击相邻字母连成英文单词<br/>
  · 3+ 字母才算分，越长分越高<br/>
  · 撞当周主题词 ★ 分数翻倍<br/>
  · 时间到自动交卷<br/>
  <br/>
  <span className="opacity-60">本场:{totalTime} 秒 · 主题 {theme.bonus.slice(0, 4).join(' / ')} ...</span>
</div>
```

- [ ] **Step 5: 跑现有 lecture 测试不回归**

Run: `npm test -- lectureMinigame`
Expected: 11 个 it() 仍 PASS（数据层没动）。

- [ ] **Step 6: 手动验证（dev server）**

Run: `npm run dev` → 浏览器打开 → 进入一节 lecture（W1）→ 尝试斜着戳两个相邻字母 → 应看到红色提示「W1 还不能斜着连 (本周:只能横着连)」。

如果游戏 state 不在 W1，可在 console 修改 `localStorage` 或用游戏内调试入口。

- [ ] **Step 7: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "feat(lecture): 接线 tier 渐进解锁 — W1-10 横, W11-22 横+竖, W23+ 全方向"
```

---

## Task 4: LectureMinigame — 计时器重构成 useEffect（为暂停做准备）

> 单独一步，便于回滚验证。**不改变行为**，只把 setInterval 从 `start()` 函数挪到 useEffect。

**Files:**
- Modify: `src/components/Minigames.jsx`（LectureMinigame timer 部分）

- [ ] **Step 1: 简化 start() 函数（line 664-677）**

替换为：

```jsx
function start() {
  audio.click();
  setPhase('playing');
}
```

- [ ] **Step 2: 改 useEffect 持有计时器（line 758）**

替换：

```jsx
useEffect(() => () => clearInterval(timerRef.current), []);
```

为：

```jsx
useEffect(() => {
  if (phase !== 'playing') return;
  timerRef.current = setInterval(() => {
    setTimeLeft(t => {
      if (t <= 1) {
        clearInterval(timerRef.current);
        setPhase('done');
        return 0;
      }
      return t - 1;
    });
  }, 1000);
  return () => clearInterval(timerRef.current);
}, [phase]);
```

把 `finish()` 函数里 line 738 的 `clearInterval(timerRef.current); setPhase('done')` 保留——useEffect 的 cleanup 也会清，双重保险无害。

- [ ] **Step 3: 手动验证**

Run: `npm run dev` → 进入 lecture → 点开始 → 计时器正常倒数 → 时间到自动 done → 重玩一次 → 计时器重置正常。

- [ ] **Step 4: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "refactor(lecture): 计时器移入 useEffect, 准备支持暂停"
```

---

## Task 5: LectureMinigame — 抽 LectureRulesBody + 加 ? 按钮 + 模态（带计时器暂停）

**Files:**
- Modify: `src/components/Minigames.jsx`

- [ ] **Step 1: import MinigameRulesModal**

在 Minigames.jsx 顶部加：

```jsx
import { MinigameHelpButton, MinigameRulesModal } from './MinigameRulesModal.jsx';
```

- [ ] **Step 2: 在 LectureMinigame 函数体最前面把规则正文抽成本地组件**

放在 `function LectureMinigame(...) {` 之后、`const theme = useMemo(...)` 之前：

```jsx
function LectureRulesBody({ dirInfo, totalTime, theme, week }) {
  return (
    <>
      Whitmore 在黑板上写理论。你的笔记本上是一团字母。<br/>
      <br/>
      <span style={{ color: '#d4b070' }}>· 本周可连：<strong>{dirInfo.label}</strong>（{dirInfo.desc}）</span><br/>
      · 点击相邻字母连成英文单词<br/>
      · 3+ 字母才算分，越长分越高<br/>
      · 撞当周主题词 ★ 分数翻倍<br/>
      · 时间到自动交卷<br/>
      <br/>
      <span className="opacity-60">本场:{totalTime} 秒 · W{week} · 主题 {theme.bonus.slice(0, 4).join(' / ')} ...</span>
    </>
  );
}
```

注意：**这个组件是 module-level 的**（写在 LectureMinigame 函数**外**，不要嵌套到 LectureMinigame 内部以避免每次 re-render 重建）。

- [ ] **Step 3: intro phase 改用 LectureRulesBody**

把 Task 3 Step 4 写的 intro `<div className="text-sm opacity-90 mb-4">...</div>` 替换为：

```jsx
<div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.85' }}>
  <LectureRulesBody dirInfo={dirInfo} totalTime={totalTime} theme={theme} week={week || 1} />
</div>
```

- [ ] **Step 4: 加 rulesOpen state 与 ? 按钮**

在 LectureMinigame `useState` 一堆里加：

```jsx
const [rulesOpen, setRulesOpen] = useState(false);
```

外层卡 `<div className="bg-[#1a1612] border ...">` 加 `relative` 定位，并在卡片内顶部插 `?` 按钮：

```jsx
<div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-4 max-h-[95vh] overflow-y-auto relative">
  <MinigameHelpButton onClick={() => { audio.click(); setRulesOpen(true); }} />
  {/* 已有的 monospace 标题、h2 等保持 */}
  ...
```

- [ ] **Step 5: 在卡片末尾插 RulesModal**

在 `{phase === 'done' && (...)}` 的闭合 `</>` 之后、外层 `</div></div>` 之前加：

```jsx
<MinigameRulesModal
  open={rulesOpen}
  onClose={() => setRulesOpen(false)}
  title={`LECTURE · ${theme.name}`}
>
  <LectureRulesBody dirInfo={dirInfo} totalTime={totalTime} theme={theme} week={week || 1} />
</MinigameRulesModal>
```

- [ ] **Step 6: 计时器 useEffect 加 rulesOpen 依赖**

把 Task 4 Step 2 的 useEffect 改为：

```jsx
useEffect(() => {
  if (phase !== 'playing' || rulesOpen) return;
  timerRef.current = setInterval(() => {
    setTimeLeft(t => {
      if (t <= 1) {
        clearInterval(timerRef.current);
        setPhase('done');
        return 0;
      }
      return t - 1;
    });
  }, 1000);
  return () => clearInterval(timerRef.current);
}, [phase, rulesOpen]);
```

- [ ] **Step 7: 手动验证**

Run: `npm run dev` → 进入 lecture → intro 屏点开始 → 进 playing → 戳几个字母 → 点右上角 ? → 模态弹出，计时器停了（看 timeLeft 不变） → 关掉模态 → 计时器恢复倒数。

- [ ] **Step 8: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "feat(lecture): 加 ? 详情按钮, 中途可暂停看规则"
```

---

## Task 6: LectureMinigame — 首次升级仪式 + flag 持久化 + App.jsx 接线

**Files:**
- Modify: `src/components/Minigames.jsx`（LectureMinigame）
- Modify: `src/App.jsx`（LectureMinigame call site）

- [ ] **Step 1: LectureMinigame 加 props**

函数签名改为：

```jsx
export function LectureMinigame({ onComplete, onCancel, week, tierFlags = {}, onMarkTierSeen = () => {} }) {
```

- [ ] **Step 2: 初始 phase 决策**

把 line 654 的 `const [phase, setPhase] = useState('intro');` 替换为：

```jsx
const [phase, setPhase] = useState(() => {
  const w = week || 1;
  if (w >= 23 && !tierFlags.tier3Seen) return 'tier-upgrade-3';
  if (w >= 11 && !tierFlags.tier2Seen) return 'tier-upgrade-2';
  return 'intro';
});
```

> 注意：这里只用 `tierFlags` 的初始值决定起始 phase（useState lazy init），后续 props 变化不会重算 — 这是想要的行为，避免 dispatch 后 props 更新导致 phase 跳回。

- [ ] **Step 3: 加仪式屏渲染**

在 `{phase === 'intro' && (...)}` **之前**加两个仪式 phase 的渲染块：

```jsx
{phase === 'tier-upgrade-2' && (
  <div className="text-center py-6">
    <div className="text-3xl mb-3">🎓</div>
    <div className="text-xs tracking-[0.3em] mb-2" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
      难度升级
    </div>
    <div className="text-base font-light mb-2">
      W{week || 11} · 你的英文连词能力升了一档
    </div>
    <div className="text-sm opacity-80 mb-6" style={{ lineHeight: '1.85' }}>
      现在开始：可以「<strong style={{ color: '#d4b070' }}>竖着</strong>」连词了
    </div>
    <button
      onClick={() => {
        audio.click();
        onMarkTierSeen(2);
        setPhase('intro');
      }}
      className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm"
    >
      开始挑战
    </button>
  </div>
)}

{phase === 'tier-upgrade-3' && (
  <div className="text-center py-6">
    <div className="text-3xl mb-3">🎓</div>
    <div className="text-xs tracking-[0.3em] mb-2" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
      难度升级
    </div>
    <div className="text-base font-light mb-2">
      W{week || 23} · 你的英文连词能力再升一档
    </div>
    <div className="text-sm opacity-80 mb-6" style={{ lineHeight: '1.85' }}>
      现在开始：横、竖、<strong style={{ color: '#d4b070' }}>斜，全 8 方向</strong>都能连
    </div>
    <button
      onClick={() => {
        audio.click();
        onMarkTierSeen(3);
        setPhase('intro');
      }}
      className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm"
    >
      开始挑战
    </button>
  </div>
)}
```

- [ ] **Step 4: App.jsx 接线**

在 `src/App.jsx` 找到 LectureMinigame call site（line ~2065），改为：

```jsx
{activeMinigameLecture && (
  <LectureMinigame
    week={week}
    tierFlags={{
      tier2Seen: !!state.flags?.lecture_tier2_seen,
      tier3Seen: !!state.flags?.lecture_tier3_seen,
    }}
    onMarkTierSeen={(tier) => dispatch({
      type: 'SET_FLAG',
      flag: tier === 2 ? 'lecture_tier2_seen' : 'lecture_tier3_seen',
    })}
    onComplete={(result) => {
      audio.click();
      dispatch({ type: 'APPLY_EFFECT', effect: result.effect });
      if (result.attendedClass) dispatch({ type: 'CLASSES_ATTENDED_INC' });
      setActiveMinigameLecture(false);
      setActiveEvent({
        id: 'lecture_result', title: '下课了',
        body: result.feedback,
        choices: [{ label: '回去', effect: {}, feedback: '...' }],
      });
    }}
    onCancel={() => { audio.click(); setActiveMinigameLecture(false); }}
  />
)}
```

- [ ] **Step 5: 手动验证**

Run: `npm run dev` →
1. 把游戏 state 推到 W11（在浏览器 console: `JSON.parse(localStorage.getItem('yixiang-save')).state.week` 检查；或在游戏内推进）
2. 进入一节 lecture → 应看到 W11 仪式屏「难度升级 / 现在开始：可以竖着连词了」
3. 点「开始挑战」→ 进入 intro 屏（intro 文案显示「本周可连：横 + 竖」）
4. 退出 minigame，再进一次 → **直接看到 intro，没有仪式屏**（flag 已 set）
5. 把 state.flags 里的 `lecture_tier2_seen` 删掉再进 → 仪式重现（验证 flag 控制）

W23 同样验证。

- [ ] **Step 6: Commit**

```bash
git add src/components/Minigames.jsx src/App.jsx
git commit -m "feat(lecture): W11/W23 首次升级仪式 + flag 持久化"
```

---

## Task 7: PretMinigame — 抽 PretRulesBody + ? 按钮

> Pret 没有计时器，模态不需要暂停逻辑。

**Files:**
- Modify: `src/components/Minigames.jsx`（PretMinigame，line 261-399 附近）

- [ ] **Step 1: 找到 Pret intro 屏内容**

PretMinigame 在 `phase === 'intro'` 分支（line 334 附近）渲染了一段规则文本。先 Read 该段提取出来。

```bash
# 不要真跑这个,只用来提示哪行
# Lines around 334-395 in Minigames.jsx
```

- [ ] **Step 2: 在 PretMinigame 函数外加 PretRulesBody 组件**

放在 `export function PretMinigame(...) {` 之前。把 intro 屏现有的规则正文 JSX 原样剪贴进去，把它需要的变量（如 `set`、`maskRate`）改成 props：

```jsx
function PretRulesBody({ set, maskRate }) {
  return (
    <>
      {/* 把现有 PretMinigame intro 块中的规则正文 JSX 完整 paste 在此处 */}
      {/* 引用 set / maskRate 处保持不变 */}
    </>
  );
}
```

> ⚠️ 实施时打开 line 334-395 范围 Read 一次，把 intro 的规则正文（除去「开始」和「不去」按钮）整块剪贴成 PretRulesBody 的 JSX body。

- [ ] **Step 3: intro 屏改用 PretRulesBody**

PretMinigame 内 `phase === 'intro'` 分支改为：

```jsx
{phase === 'intro' && (
  <>
    <PretRulesBody set={set} maskRate={maskRate} />
    {/* 保持原「开始」「不去」按钮 */}
  </>
)}
```

- [ ] **Step 4: 加 rulesOpen state + ? 按钮 + 模态**

在 PretMinigame 顶部加：

```jsx
const [rulesOpen, setRulesOpen] = useState(false);
```

外层卡 `<div>` 加 `relative` 类名，紧跟在卡片开头加：

```jsx
<MinigameHelpButton onClick={() => { audio.click(); setRulesOpen(true); }} />
```

卡片闭合 `</div></div>` 之前加：

```jsx
<MinigameRulesModal
  open={rulesOpen}
  onClose={() => setRulesOpen(false)}
  title="PRET · 听不懂的英语"
>
  <PretRulesBody set={set} maskRate={maskRate} />
</MinigameRulesModal>
```

- [ ] **Step 5: 手动验证**

Run: `npm run dev` → 触发 Pret minigame → intro 屏正常显示 → 点开始 → 玩到一半 → 点 ? → 模态弹出规则 → 关掉 → 继续答题正常。

- [ ] **Step 6: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "feat(pret): 加 ? 详情按钮, 抽 PretRulesBody 共享文案"
```

---

## Task 8: DesignBriefMinigame — 抽 DesignBriefRulesBody + ? 按钮

> 没有计时器。同 Task 7 套路。

**Files:**
- Modify: `src/components/Minigames.jsx`（DesignBriefMinigame，line 885-1072）

- [ ] **Step 1: 抽 DesignBriefRulesBody（module-level）**

放在 `export function DesignBriefMinigame(...)` 之前。把 line 992-1000 的 intro 规则正文（不含按钮）整块剪贴成：

```jsx
function DesignBriefRulesBody({ phase, brief }) {
  return (
    <>
      客户给的 brief 通常含糊。你的工作是把废话翻译成 4 个明确的设计决定。<br/>
      <br/>
      · 4 步:解读意图 / mood / 配色 / 格式<br/>
      · 每步 4 选项,1 正确 + 3 典型失败<br/>
      · 满分 4/4 = 5⭐ + 25% 奖励金<br/>
      · Phase {phase} = {phase === 1 ? '入门级' : phase === 2 ? '客户有矛盾要求' : '挑剔客户,wrong option 也 plausible'}<br/>
      <br/>
      <span className="opacity-60">本单 £{brief.reward}（满分 25% bonus）</span>
    </>
  );
}
```

- [ ] **Step 2: stage === 'intro' 改用 DesignBriefRulesBody**

```jsx
{stage === 'intro' && (
  <>
    <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.85' }}>
      <DesignBriefRulesBody phase={phase} brief={brief} />
    </div>
    {/* 保持原「开始接单」「不接」按钮 */}
  </>
)}
```

- [ ] **Step 3: 加 rulesOpen + ? 按钮 + 模态**

DesignBriefMinigame 内：

```jsx
const [rulesOpen, setRulesOpen] = useState(false);
```

外层卡片 div 加 `relative`，紧跟卡片开头加：

```jsx
<MinigameHelpButton onClick={() => { audio.click(); setRulesOpen(true); }} />
```

卡片末尾加：

```jsx
<MinigameRulesModal
  open={rulesOpen}
  onClose={() => setRulesOpen(false)}
  title={`BRIEF · ${brief.subject}`}
>
  <DesignBriefRulesBody phase={phase} brief={brief} />
</MinigameRulesModal>
```

- [ ] **Step 4: 手动验证**

Run: `npm run dev` → 触发 Design Brief minigame → intro 显示正常 → 进 step → 点 ? → 模态弹出 → 关掉 → 继续答题。

- [ ] **Step 5: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "feat(design-brief): 加 ? 详情按钮, 抽 DesignBriefRulesBody"
```

---

## Task 9: YellowLabelMinigame — 抽 YellowLabelRulesBody + 阶段化 ? 按钮

> ⚠️ Yellow Label 有 `peek/flipping/shuffling` 动画阶段（setTimeout 链），不暂停。**? 按钮只在 `ready/pick/done` 阶段显示**，避免在 peek 时打开模态导致玩家错过记忆窗口。

**Files:**
- Modify: `src/components/Minigames.jsx`（YellowLabelMinigame，line 35-260）

- [ ] **Step 1: 抽 YellowLabelRulesBody（module-level）**

放在 `export function YellowLabelMinigame(...)` 之前，把 line 210-217 的规则正文剪贴：

```jsx
function YellowLabelRulesBody({ cfg }) {
  return (
    <>
      晚上 9 点 Tesco。员工把一批 <span style={{ color: '#d4b070' }}>£X 黄标</span> 商品摆出来。<br/>
      <br/>
      · 看 {cfg.peekMs/1000}s 记住哪几张是黄标<br/>
      · 卡牌翻面 + 洗 {cfg.shuffles} 次<br/>
      · 点出 <strong style={{ color: '#d4b070' }}>{cfg.yellowCount}</strong> 张黄标的位置<br/>
      · 错抢扣 1.5× 价
    </>
  );
}
```

- [ ] **Step 2: ready phase 改用 YellowLabelRulesBody**

```jsx
{phase === 'ready' && (
  <>
    <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.8' }}>
      <YellowLabelRulesBody cfg={cfg} />
    </div>
    {/* 保持原「开始」「不抢」按钮 */}
  </>
)}
```

- [ ] **Step 3: 加 rulesOpen + 条件 ? 按钮 + 模态**

```jsx
const [rulesOpen, setRulesOpen] = useState(false);
const helpAvailable = phase === 'ready' || phase === 'pick' || phase === 'done';
```

外层卡 div 加 `relative`，紧跟卡开头：

```jsx
{helpAvailable && (
  <MinigameHelpButton onClick={() => { audio.click(); setRulesOpen(true); }} />
)}
```

卡末尾：

```jsx
<MinigameRulesModal
  open={rulesOpen}
  onClose={() => setRulesOpen(false)}
  title={`抢黄标 · LV ${cfg.cards}x${cfg.yellowCount}`}
>
  <YellowLabelRulesBody cfg={cfg} />
</MinigameRulesModal>
```

- [ ] **Step 4: 手动验证**

Run: `npm run dev` → 触发 Yellow Label → ready 阶段右上角有 ? → 点开始 → peek/shuffle 阶段**没有 ?** → pick 阶段 ? 出现 → 点 ? → 模态正常 → 关掉 → 选卡正常。

- [ ] **Step 5: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "feat(yellow-label): 加 ? 详情按钮 (仅 ready/pick/done 阶段)"
```

---

## Task 10: EssayMinigame — 加 intro 屏 + ? 按钮

> 这个 minigame 现在没 intro，直接进答题。要新增 `'intro'` phase。

**Files:**
- Modify: `src/components/Minigames.jsx`（EssayMinigame，line 401-498）

- [ ] **Step 1: 起草 EssayRulesBody 文案，跟用户过一遍**

读 line 401-450 理解 Essay 玩法：3 个 puzzle，每个有 context + paragraph 含填空 ___ + 几个选项，对了 +1 score，影响 academic +finalScore*4。

起草本地 RulesBody（module-level）：

```jsx
function EssayRulesBody({ totalPuzzles }) {
  return (
    <>
      凌晨 1 点。你试图把一段卡壳的 paragraph 写完。<br/>
      <br/>
      · 一共 <strong style={{ color: '#9080b8' }}>{totalPuzzles}</strong> 道填空题<br/>
      · 每题有几个候选句子，挑最贴合 context 的那句填进 ___<br/>
      · 选错会看到为什么不对（也是知识点）<br/>
      · 对越多，academic 涨越多；2/3+ 还有 belonging 加成
    </>
  );
}
```

> **暂停点**：把这段草稿展示给用户，确认 OK 再继续 Step 2。

- [ ] **Step 2: 加 intro phase state**

把 line 404-408 的 useState 一堆里加：

```jsx
const [introPhase, setIntroPhase] = useState(true);
const [rulesOpen, setRulesOpen] = useState(false);
```

> 用 `introPhase` 而不是 `phase` 字符串，避免跟现有 `showFb` 冲突。

- [ ] **Step 3: render intro 屏**

在 line 451 的最外层 `<div className="fixed inset-0 ...">` 之内、`<div className="bg-[#1a1612] ...">` 之内、`<div className="text-xs tracking-[0.3em] ...">` 之后插入一个新分支。整个 return 结构改为：

```jsx
return (
  <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
       style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
    <div className="bg-[#1a1612] border border-purple-300/40 max-w-md w-full p-5 relative">
      <MinigameHelpButton onClick={() => { audio.click(); setRulesOpen(true); }} />
      <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#9080b8' }}>📝 MINIGAME</div>
      <h2 className="text-xl mb-1 font-light">写论文</h2>
      <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>
        {introPhase ? `填入最合适的句子 · 共 ${puzzles.length} 题` : `填入最合适的句子 · ${puzzleIdx + 1}/${puzzles.length}`}
      </div>

      {introPhase ? (
        <>
          <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.85' }}>
            <EssayRulesBody totalPuzzles={puzzles.length} />
          </div>
          <button
            onClick={() => { audio.click(); setIntroPhase(false); }}
            className="w-full py-3 border hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm"
            style={{ borderColor: '#9080b8', color: '#9080b8' }}
          >
            开始写
          </button>
          <button onClick={onCancel} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">下次再说 →</button>
        </>
      ) : !showFb ? (
        <>
          {/* 原 line 458-483 的内容保持不变 */}
        </>
      ) : (
        <>
          {/* 原 line 484-494 的内容保持不变 */}
        </>
      )}

      <MinigameRulesModal
        open={rulesOpen}
        onClose={() => setRulesOpen(false)}
        title="ESSAY · 写论文"
      >
        <EssayRulesBody totalPuzzles={puzzles.length} />
      </MinigameRulesModal>
    </div>
  </div>
);
```

- [ ] **Step 4: 手动验证**

Run: `npm run dev` → 触发 essay → 看到新 intro 屏「凌晨 1 点...」→ 点开始 → 进入第 1 题 → 点 ? → 模态弹出 → 关掉 → 继续答题正常 → 答完看结果。

- [ ] **Step 5: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "feat(essay): 加 intro 屏 + ? 详情按钮"
```

---

## Task 11: MatchMinigame — 加 intro 屏 + ? 按钮

> 同 Task 10 套路。

**Files:**
- Modify: `src/components/Minigames.jsx`（MatchMinigame，line 504-645）

- [ ] **Step 1: 起草 MatchRulesBody 文案，跟用户过一遍**

读 line 504-555 理解：抽一组 theorist + concept，玩家把 concept 拖到对应 theorist 上，正确数 ≥5/6 满分。

起草：

```jsx
function MatchRulesBody({ totalConcepts }) {
  return (
    <>
      期末复习。你列了一张表想搞清谁说了什么。<br/>
      <br/>
      · 把 {totalConcepts} 个概念匹配到对应的理论家<br/>
      · 步骤：先点一个概念 → 再点理论家<br/>
      · 全部匹配完看评分，对越多 academic 越高<br/>
      · 5/6+ 还有 belonging 加成
    </>
  );
}
```

> **暂停点**：草稿给用户过。

- [ ] **Step 2: 加 intro state**

把 line 514 附近：

```jsx
const [phase, setPhase] = useState('play'); // play | done
```

改为：

```jsx
const [phase, setPhase] = useState('intro'); // intro | play | done
const [rulesOpen, setRulesOpen] = useState(false);
```

- [ ] **Step 3: render intro 屏**

最外层 return 结构改为（保持原 phase=='play' 和 phase=='done' 的内容不变）：

```jsx
return (
  <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
       style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
    <div className="bg-[#1a1612] border border-blue-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 relative">
      <MinigameHelpButton onClick={() => { audio.click(); setRulesOpen(true); }} />
      <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#a0a0c8' }}>🎴 MINIGAME</div>
      <h2 className="text-xl mb-1 font-light">理论家与概念</h2>
      <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>把概念匹配到对的人</div>

      {phase === 'intro' && (
        <>
          <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.85' }}>
            <MatchRulesBody totalConcepts={round.length} />
          </div>
          <button
            onClick={() => { audio.click(); setPhase('play'); }}
            className="w-full py-3 border hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm"
            style={{ borderColor: '#a0a0c8', color: '#a0a0c8' }}
          >
            开始匹配
          </button>
          <button onClick={onCancel} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">先不玩 →</button>
        </>
      )}

      {phase === 'play' && (
        <>
          {/* 原 line 564-611 的 play 分支内容,完整保留 */}
        </>
      )}

      {phase === 'done' && (
        <>
          {/* 原 line 614-640 的 done 分支内容,完整保留 */}
        </>
      )}

      <MinigameRulesModal
        open={rulesOpen}
        onClose={() => setRulesOpen(false)}
        title="MATCH · 理论家与概念"
      >
        <MatchRulesBody totalConcepts={round.length} />
      </MinigameRulesModal>
    </div>
  </div>
);
```

- [ ] **Step 4: 手动验证**

Run: `npm run dev` → 触发 match → 看到新 intro「期末复习...」→ 开始匹配 → 选概念选 theorist 正常 → 点 ? → 模态显示 → 关掉 → 继续 → 完成看评分。

- [ ] **Step 5: Commit**

```bash
git add src/components/Minigames.jsx
git commit -m "feat(match): 加 intro 屏 + ? 详情按钮"
```

---

## Task 12: 全量 dev-server playthrough + 跑全测试

> 最后一道闸门。验证 6 个 minigame 串起来都正常 + 没有跨任务的回归。

**Files:**
- 无（验证 only）

- [ ] **Step 1: 跑全测试套件**

Run: `npm test`
Expected: 全部测试 PASS（含原有 25+ 测试 + 新加的 lectureMinigame.test.js + MinigameRulesModal.test.jsx）。如果有失败的，回到对应任务排查。

- [ ] **Step 2: 起 dev server**

Run: `npm run dev`

- [ ] **Step 3: 手动 playthrough 清单**

逐项过：

- [ ] **Lecture W1**：进 lecture → intro 显示「本周可连：只能横着连」→ 开始 → 试斜着戳 → 看到 fail 提示「W1 还不能斜着连」→ 横着连出 3 个词 → 提交 → done
- [ ] **Lecture ?**：playing 中点 ? → 模态弹出，时间不动 → 关掉 → 时间继续
- [ ] **Lecture W11 仪式**：把 state.flags.lecture_tier2_seen 删掉, week 推到 11+ → 进 lecture → 看到「难度升级 / 现在开始：可以竖着连了」→ 点开始挑战 → flag 自动 set → 进 intro
- [ ] **Lecture W11 仪式只一次**：再进 lecture → 直接 intro，无仪式
- [ ] **Lecture W23 仪式**：同上验证 tier3
- [ ] **Pret ?**：进 Pret → intro → 开始 → 答题中点 ? → 模态正常 → 关掉
- [ ] **Design Brief ?**：进 brief → intro → 开始 → 答题中点 ? → 模态正常
- [ ] **Yellow Label**：进 yellow → ready 阶段有 ? → 开始 → peek/shuffle 阶段无 ? → pick 阶段 ? 重新出现 → 点 ? → 模态 → 关掉 → 选卡正常
- [ ] **Essay 新 intro**：进 essay → 看到新 intro「凌晨 1 点...」→ 开始 → 答题中 ? → 模态 → 关掉 → 答完
- [ ] **Match 新 intro**：进 match → 看到新 intro「期末复习...」→ 开始 → 匹配中 ? → 模态 → 关掉 → 完成

- [ ] **Step 4: 任何回归 / 偏差，回相应任务修；测试清单全过则收工**

如果 12 项 playthrough 全过，向用户汇报：6 个 minigame 全部接入 ? 按钮、Lecture 渐进解锁 + 仪式生效、3 个 minigame 拥有正确 intro 文案。

- [ ] **Step 5（可选）：如果 spec 中任何描述与最终实现有出入，更新 spec 并 commit**

```bash
# 如有需要:
git add docs/superpowers/specs/2026-05-15-lecture-minigame-progression-and-help-design.md
git commit -m "docs: 同步 spec 与最终实现"
```

---

## 风险与边角情况

- **存档兼容**：新加的两个 flag 在老存档中 undefined → falsy，老用户首次到 W11/W23 会触发仪式。这是想要的行为，无需迁移。
- **跳关**：玩家若第一次进 lecture 时已在 W23（极端 / 调试），只看 W23 仪式（W11 不补播）。可接受，spec 已声明。
- **z-index**：MinigameRulesModal 用 `z-[60]`，高于 minigame 卡的 `z-50`，低于全局 toast / crisis modal。
- **lazy useState 初值依赖 props**：Task 6 用 `useState(() => ...)` lazy init 初始 phase。后续 props 变化不会重算 — 这是想要的，避免 dispatch 后 props 更新跳回仪式 phase。
- **? 按钮 audio**：每次点击都 `audio.click()`，与现有交互一致。
- **无 i18n**：保持现有 hardcoded 中文风格，不引入新 i18n 基建。

---

## Self-Review

- ✅ Spec Block 1（tier 接线 + 动态 intro + 非法反馈）→ Task 3 覆盖
- ✅ Spec Block 2（仪式屏 + flag）→ Task 6 覆盖
- ✅ Spec Block 3（共享模态 + 6 个 minigame 接入 + 计时器暂停）→ Tasks 2, 5, 7, 8, 9, 10, 11
- ✅ Spec 提到的「规则文案抽常量避免双份维护」→ 每个 Task（5、7、8、9、10、11）都明确抽 RulesBody
- ✅ Spec 提到 Essay/Match intro 文案需用户过一遍 → Tasks 10/11 Step 1 明确暂停点
- ✅ 无 TBD / TODO / "implement later"
- ✅ 类型一致：`tierFlags.tier2Seen` 在 Task 6 定义，App.jsx Step 4 一致使用
- ✅ MinigameRulesModal 的 `open/onClose/title/children` 接口在 Task 2 定义，所有调用方（Tasks 5/7/8/9/10/11）一致
- ✅ MinigameHelpButton 的 `onClick` 接口在 Task 2 定义，所有调用方一致
