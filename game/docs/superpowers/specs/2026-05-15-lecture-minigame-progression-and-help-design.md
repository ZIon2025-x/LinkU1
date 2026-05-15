# Lecture Minigame · 渐进解锁 + 全游戏帮助系统

**日期**：2026-05-15
**Scope**：`src/components/Minigames.jsx`、`src/App.jsx`、新增 `src/components/MinigameRulesModal.jsx`

---

## 背景

1. `src/data/lectureMinigame.js` 已定义按周分级的连词方向 (`lectureDirTier` / `lectureDirInfo` / `isLectureAdjacent`)：W1-10 横向、W11-22 横+竖、W23+ 全 8 方向。但 `Minigames.jsx::LectureMinigame` 没有 import 这些，本地 `isAdjacent()` 一上来就允许全 8 方向，分级形同虚设。
2. 6 个 minigame 中只有 3 个有 intro 屏（Lecture / Pret / DesignBrief）。YellowLabel / Essay / Match 一打开直接就玩，玩家不知道规则。

## 目标

- **G1**：Lecture 连词按周渐进解锁，第一次解锁新方向时给"难度升级"全屏提示，之后每场 intro 都标注当前可用方向。
- **G2**：全部 6 个 minigame 都有 intro 屏 + 卡片右上角 `?` 详情按钮，可在游戏中暂停打开规则。

## Non-Goals

- ❌ 不改词典、主题、网格生成器
- ❌ 不为 tier 1 网格强制塞水平方向 bonus 词（先看实际玩感）
- ❌ 不做 i18n
- ❌ 不重做任何 minigame 的核心玩法
- ❌ 不在网格 cell 上画方向箭头（用文字提示已足够）

---

## 设计

### Block 1 · Lecture 渐进解锁接线

`Minigames.jsx::LectureMinigame` 改用现成的 tier API：

```js
import { lectureDirInfo, isLectureAdjacent, /* ...其余原有 import */ } from '../data';

const dirInfo = useMemo(() => lectureDirInfo(week || 1), [week]);
// 替换原本地 isAdjacent
const isAdjacent = useCallback((a, b) => isLectureAdjacent(a, b, dirInfo.dirs), [dirInfo]);
```

- **Intro 文案动态化**：原 "点击相邻字母 (横/竖/斜) 连成英文单词" 改为根据 `dirInfo`：
  - tier 1：「点击相邻字母 (**横向**) 连成英文单词」
  - tier 2：「点击相邻字母 (**横 / 竖**) 连成英文单词」
  - tier 3：「点击相邻字母 (**横 / 竖 / 斜 全 8 方向**) 连成英文单词」
- 同时在 intro 顶部加一行高亮：`本周可连：{dirInfo.label}（{dirInfo.desc}）`
- **非法方向反馈**：玩家戳超出当前 tier 的相邻 cell 时，原代码直接 `return`，玩家不知发生了啥。改为 `audio.fail()` + `setLastWordFeedback({ message: 'W{week} 还不能{dir}着连', bad: true })`。沿用现有 `lastWordFeedback` 机制（持久显示直到下次操作），不另加 setTimeout。

### Block 2 · 难度升级仪式（首次进入 W11 / W23）

**State flag**（沿用现有 `state.flags` 机制 + `SET_FLAG` action）：

- `flags.lecture_tier2_seen` — 看过 W11 升级提示
- `flags.lecture_tier3_seen` — 看过 W23 升级提示

**Prop / callback 接线**（`App.jsx` → `<LectureMinigame>`）：

```jsx
<LectureMinigame
  week={week}
  tierFlags={{
    tier2Seen: !!state.flags.lecture_tier2_seen,
    tier3Seen: !!state.flags.lecture_tier3_seen,
  }}
  onMarkTierSeen={(tier) => dispatch({
    type: 'SET_FLAG',
    flag: tier === 2 ? 'lecture_tier2_seen' : 'lecture_tier3_seen',
  })}
  onComplete={...}
  onCancel={...}
/>
```

**Phase 流程**：

```
进入 → check tier
  ├─ week≥11 && !tier2Seen → phase='tier-upgrade-2'
  ├─ week≥23 && !tier3Seen → phase='tier-upgrade-3'
  └─ 否则                    → phase='intro'

仪式屏点「开始挑战」→ onMarkTierSeen(2 | 3) → setPhase('intro')
```

**仪式屏 UI**（与现有暗金 monospace 风格一致）：

```
┌──────────────────────────────────────┐
│  🎓 难度升级                          │
│  ─────────────                       │
│  W11 · 你的英文连词能力升了一档        │
│  现在开始：可以「竖着」连词了          │
│                                      │
│  [ 开始挑战 ]                         │
└──────────────────────────────────────┘
```

W23 同样模板，文案换成"现在开始：横、竖、斜，全 8 方向都能连"。

### Block 3 · 共享 RulesModal + 6 个 minigame 接入

**新文件**：`src/components/MinigameRulesModal.jsx`

```jsx
// 两个 export:
export function MinigameHelpButton({ onClick }) {
  // 右上角圆形 ? 按钮,monospace 风格
  return (
    <button onClick={onClick} className="absolute top-3 right-3 w-7 h-7 ..."
            title="玩法说明">?</button>
  );
}

export function MinigameRulesModal({ open, onClose, title, children }) {
  // 半透明黑底覆盖 + 居中卡(z-index 高于 minigame 卡)
  // 点 backdrop / 「明白了」按钮 → onClose()
}
```

**接入模式**（每个 minigame 都一样）：

```jsx
const [rulesOpen, setRulesOpen] = useState(false);

// 1. 卡片头部加 <MinigameHelpButton onClick={() => setRulesOpen(true)} />
// 2. 卡片底部 / 顶层加:
<MinigameRulesModal open={rulesOpen} onClose={() => setRulesOpen(false)}
                    title="LECTURE · 字母连词">
  {/* 与 intro 屏同源的规则文本 */}
</MinigameRulesModal>

// 3. 计时器跳过 tick:
useEffect(() => {
  if (phase !== 'playing' || rulesOpen) return;  // ← 加 rulesOpen 判断
  timerRef.current = setInterval(...);
  return () => clearInterval(timerRef.current);
}, [phase, rulesOpen]);
```

**Intro 屏首次自动展开**：用户已确认 — intro phase 默认就是规则全展开状态（现状如此），玩家点「开始」才进入 playing。中途想看规则就点 ? 按钮。

**避免规则文案双份维护**：每个 minigame 把规则正文抽成一个本地常量或子组件（如 `LectureRulesBody = () => <>...</>`），intro 屏和 RulesModal 都引用它。后续改文案只动一处。

**6 个 minigame 改造矩阵**：

| Minigame | 当前 intro? | 计时器? | 本次动作 |
|---|---|---|---|
| LectureMinigame | ✅ (`'intro'`) | ✅ setInterval | + ? 按钮、+ 仪式屏、动态 dirInfo 文案、? 暂停计时器 |
| PretMinigame | ✅ (`'intro'`) | ❌ | + ? 按钮，规则文本复用现有 intro |
| DesignBriefMinigame | ✅ (`'intro'`) | ❌ | + ? 按钮，同上 |
| YellowLabelMinigame | ✅ (`'ready'`) | ⚠️ setTimeout 链 | + ? 按钮（仅在 `ready/pick/done` 阶段显示，避免暂停 peek/shuffle 动画的复杂度） |
| EssayMinigame | ❌ | ❌ | + `'intro'` phase + ? 按钮，需起草 intro 文案 |
| MatchMinigame | ❌ | ❌ | + `'intro'` phase + ? 按钮，需起草 intro 文案 |

> 两个新 intro 文案（Essay / Match）在实现阶段会先读完代码起草草稿（与现有 intro 风格一致：1 句叙事钩子 + 4-5 条规则 bullet + 「本场参数」），起草完同步给用户过一遍再合入。

---

## 文件改动清单

```
新建:
  src/components/MinigameRulesModal.jsx     ~80 行
  
修改:
  src/components/Minigames.jsx               6 个 minigame 全改
  src/App.jsx                                LectureMinigame 多传 tierFlags + onMarkTierSeen

不动:
  src/data/lectureMinigame.js                tier 函数已就绪
  src/engine/state.js                        SET_FLAG action 够用
```

---

## 边界 / 边角情况

- **存档兼容**：`lecture_tier2_seen` / `lecture_tier3_seen` 是新 flag，老存档读取时 undefined → falsy，第一次 W11/W23 会触发仪式。符合预期，无需迁移。
- **跳关测试**：如果玩家第一次进入 lecture 时已经在 W23（极端情况），W11 的仪式不会回放——直接看 W23 仪式。可接受，不做 backfill。
- **? 按钮 z-index**：模态需要高于 minigame 卡，但低于 toast / crisis modal。统一 `z-[60]`（minigame 卡是 `z-50`）。
- **键盘 ESC**：MinigameRulesModal 默认监听 ESC 关闭。
- **`onMarkTierSeen` 重复触发**：一旦 flag 已 true 不会再 dispatch（仪式屏不会进），不需要去重逻辑。
