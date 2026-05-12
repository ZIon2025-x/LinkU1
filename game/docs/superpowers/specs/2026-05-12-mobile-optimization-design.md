# 移动端布局优化设计 · B1 + 背包 + Bottom-Sheet Modal

**日期**: 2026-05-12
**状态**: 设计稿
**作者**: Brainstorm session

---

## Why · 为什么做

游戏玩家**主要在手机上玩**。当前 PlayingScreen 在手机上有一个核心痛点：

> 一个屏幕装不下整个游戏，需要上下滑动；很多操作按钮都在下面，导致**又想操作又想看上面的文本做不到**。

技术原因：
- 顶部 header (week info + 5 stats grid + tab strip) 吃掉竖屏 ~30% 高度
- 主 CTA「🌙 结束今天」在内容区底部，长滚动时滚出视野
- 各 modal (HolidayScreen / NPC dialog / Story chapter) 是「居中 max-w-md max-h-[90vh] overflow-y-auto」结构，scene text 与选项在同一滚动容器里 —— 选完成时 scene 已滚出视野

## What · 要做什么

把 PlayingScreen + 通用 Modal 改造成 mobile-native 布局：

1. **Header 压成 1 行 pill + 1 行 stats**（B1 LEAN 方案，5 stats 显示 4 个，省略「归属」）
2. **「设置」改名为「🎒 背包」**，承载完整状态明细 + 周信息 + 设置项
3. **底部固定 sticky 区**：上层（🎒 + 🌙 结束今天）+ 下层（4 tab 底栏）
4. **所有 Modal 改 bottom-sheet**（从底滑入，scene text 在顶部固定，选项 sticky 在底部）
5. **触控/safe-area/防误操作** 配套移动端硬件适配

## Out of Scope · 不做

- 横屏深度优化（保持基本可用即可）
- PWA / standalone 模式
- 触觉反馈（Vibration API）
- 字号系统化设置
- 桌面端独立设计（沿用同一 mobile-first 布局，桌面端居中留白）
- Intro / Plane / Arrival / Holiday secrets 等单屏 onboarding（已经够紧凑）
- Minigames（独立全屏体验，结构已合理，本轮不动）

## 详细设计

### 1. Header 重构（PlayingScreen）

**现状结构**（`Screens.jsx:234-336`）：
```
┌──────────────────────────────────┐
│ DAY 042 · WEEK 6/52 · 学期        │  ← top-row pill 区
│ 第6周·周三 ☔ 学期 ⏰DEADLINE      │
│ ┌──┬──┬──┬──┬──┐                │  ← stats grid (5 cells)
│ │学│钱│精│压│归│                │
│ └──┴──┴──┴──┴──┘                │
│ 出勤提示 / 论文进度（条件性）       │
│ ┌──────┬──────┬──────┬──────┐  │  ← tab strip
│ │🗺️地图│💬消息│LLink │📔手账│  │
│ └──────┴──────┴──────┴──────┘  │
└──────────────────────────────────┘
```
高度 ~30% 屏幕。

**新结构**：
```
┌──────────────────────────────────┐
│ [D42 · W6 · 周三 · 📚 学期]  ●●○ │  ← row 1: pill + ACTIONS dots
│ 📚 72%  £420  💪 还行  🧠 能扛   │  ← row 2: 4 stats inline
│       ▼ 点击查看完整状态           │  ← row 3: tap hint
└──────────────────────────────────┘
```

**字段映射**：
- pill: `D{day} · W{week} · 周{dayName} · {weekTypeIcon} {weekTypeLabel}`
  - 天气 emoji（如有）拼到 pill 末尾
  - DEADLINE 标签（条件性）显示在 pill 右侧加红色描边
- ACTIONS dots: 现状 3 个圆点（实/空），保持不变
- stats line: 显示 4 个（学业 / 钱包 / 精力 / 压力），**省略「归属」**
  - emoji 前缀 + 当前值文字（按现有颜色映射）
  - 「归属」移入背包内部完整状态段
- tap hint: "▼ 点击查看完整状态"，opacity 0.45 引导

**移除**：
- 「出勤提示」(`Screens.jsx:340-348`) → 移入背包「本周」段
- 「论文进度」面板 (`Screens.jsx:351-365`) → 移入背包「本周」段
- 「餐数」`🍴 1/2 顿` → 移入背包「完整状态」段

**点击行为**：
- 整个 header 区是一个 `<button>`，tap 打开 BagSheet
- 视觉上保持非按钮外观（无 hover 高亮），仅 tap hint 暗示

---

### 2. 底部 sticky 操作区

```
┌──────────────────────────────────┐
│ ...内容滚动区...                  │
│                                  │
├──────────────────────────────────┤
│ [🎒]  [🌙 结束今天          ]    │  ← row 1: 操作行
├──────────────────────────────────┤
│ [🗺️] [💬·3] [L] [📔]              │  ← row 2: 底 tab 栏
│       (env(safe-area-inset-bottom)) │
└──────────────────────────────────┘
```

**操作行**（替换现有 `Screens.jsx:435-446` 的 `<div className="flex gap-2 mt-4">`）：
- 左：🎒 按钮（min-w 44px，原 ⚙️ menu 按钮的位置语义）
- 右：🌙 结束今天（flex:1）

**底 tab 栏**（从 `Screens.jsx:368-388` 移到底部）：
- 4 列 grid：🗺️ 地图 / 💬 消息·N / L Link2Ur / 📔 手账
- 每个 tab：icon (16px) + label (8px)，min-h 56px（含安全区）
- 选中态：opacity 1 + color #d4b070
- 未选中：opacity 0.55
- 未读 badge：橙色圆角小角标
- Link2Ur 锁定时：灰显 + "—锁定—" 文字（保持现有逻辑）

**布局实现**：
- PlayingScreen 顶层用 `flex flex-col h-[100dvh]`（动态视口高度）
- header 段 `flex-shrink-0`
- 中间内容 `flex-1 overflow-y-auto`（独立滚动）
- 底 sticky 操作区 `flex-shrink-0` + `pb-[env(safe-area-inset-bottom)]`

---

### 3. 🎒 背包 Sheet（替换 GameMenuPanel）

**触发**：
- header tap
- 底部 🎒 button tap

**形态**：
- **复用 §4 的 `BottomSheet` 通用组件**（不另外做一个），title 设为 "🎒 背包"
- max-height 沿用 BottomSheet 的 90vh（背包内容超过即内部滚动）
- backdrop tap / 外部 close / esc 键 关闭（v1 不支持 handle drag，与 §4 一致）

**结构**：
```
┌──────────────────────────────────┐
│         ─── (handle)              │
│         🎒 背包                    │
│                                  │
│ ┌── 完整状态 ──────────────────┐  │
│ │ 📚 学业  ▓▓▓▓▓▓░░░░  72%    │  │
│ │ 💰 钱包  ▓▓▓▓▓░░░░░  £420   │  │
│ │ 💪 精力  ▓▓▓▓▓▓░░░░  还行   │  │
│ │ 🧠 压力  ▓▓▓▓░░░░░░  能扛   │  │
│ │ 🏠 归属  ▓▓▓▓░░░░░░  适应中  │  │
│ │ 🍴 今日餐  1/2 顿            │  │
│ └────────────────────────────────┘ │
│                                  │
│ ┌── 本周 ─────────────────────┐  │
│ │ 周类型  📚 学期               │  │
│ │ 出勤累计 82%                  │  │
│ │ 本周课  3/6                   │  │
│ │ (论文季: 论文进度 45%)         │  │
│ └────────────────────────────────┘ │
│                                  │
│ ┌── 设置 ─────────────────────┐  │
│ │ 🔊 音乐 / 音效        [开]    │  │
│ │ 🔄 重新开始            [→]    │  │
│ └────────────────────────────────┘ │
└──────────────────────────────────┘
```

**段位规则**：
- 「完整状态」：永远显示 5 stat（含归属）+ 餐数
- 「本周」：周类型 + 出勤% + 本周课时；论文季（`weekInfo?.type === 'dissertation'`）追加「论文进度」+ 题目；考试季可考虑追加「考试日期」（暂不做，等需求）
- 「设置」：迁移现有 GameMenuPanel 的内容（mute toggle + restart 按钮）

**字段计算**：
- stats 进度条 fill width：`max(0, min(100, value))%`
- stats 颜色：复用现有的颜色映射逻辑（`Screens.jsx:282-325`）
- 出勤累计：复用 `attendanceRate` prop
- 论文进度：复用 `dissertationProgress` prop

**组件改名**：
- `GameMenuPanel`（App.jsx 内联或 components/）→ `BagSheet`
- 文件路径：`src/components/BagSheet.jsx`

---

### 4. Modal → Bottom-Sheet（E 方案）

**改造对象**（凡是 `fixed inset-0 ... max-w-md mx-auto max-h-[90vh] overflow-y-auto` 形式的居中 modal）：

| 文件 | 组件 | 现状 → 新形态 |
|---|---|---|
| `Screens.jsx:450+` | `HolidayScreen` | 居中 modal → bottom-sheet |
| `Screens.jsx:?` | `ChooseScreen` 类 | 同上 |
| `Modals.jsx` | NPC dialog / Story chapter / Stranger event / Crisis / At-you / Dream / Insomnia / Nostalgia / Parents chapter 等 | 全部 |
| `AchievementsView.jsx:165, 241` | AchievementCardModal / WrappedPosterModal | 同上 |
| `Minigames.jsx` | Pret/Essay/Match minigames | **本轮不动**（全屏交互，结构合理） |

**通用组件**：`src/components/BottomSheet.jsx`

```
<BottomSheet open={...} onClose={...} title="..." dismissable>
  <BottomSheet.Body>
    {/* scene text + 内容滚动区 */}
  </BottomSheet.Body>
  <BottomSheet.Footer>
    {/* 选项按钮 sticky 在底 */}
  </BottomSheet.Footer>
</BottomSheet>
```

**结构**：
- 全屏 backdrop（rgba(10,8,6,0.85) + blur 4px），tap 关闭
- 内容容器：`fixed bottom-0 left-0 right-0`，max-height 90vh，圆角 `rounded-t-2xl`
- 顶部 handle（36×4 dragable bar，可选拖动手势 v1 不做）
- Body：`flex-1 overflow-y-auto`，承载 scene text / NPC 头像 / 描述
- Footer（可选）：`flex-shrink-0` + `pb-[env(safe-area-inset-bottom)]`，承载选项按钮 + dismiss CTA
- 进入动画：复用现有 `animate-slide-up-sheet` keyframe (`styles.css:54-57`)

**桌面端 fallback**（屏宽 ≥ md / 768px）：
- 保持当前居中 dialog 形态
- 用 Tailwind `md:` 断点 override：`md:bottom-auto md:top-1/2 md:-translate-y-1/2 md:left-1/2 md:-translate-x-1/2 md:rounded-2xl md:max-w-md`
- 这样代码一套，两端自适应

---

### 5. 触控热区 + 移动端硬件适配

**触控**：
- 主 CTA / 选项 button：`min-h-[44px]` (Apple HIG)；列表 item 按现状（已较高，不强行改）
- MapMarker 已有 ::before 透明热区（上轮已做）
- **新增 `active:` 状态**：仅给当前已有 `hover:` 类的 button 配套加（搜索 `hover:bg-current` / `hover:bg-amber-300/5` 等已知形态，按形态成对加 `active:bg-current/10` 等）。**不全局 blanket 加**——避免覆盖已有自定义状态。
- 桌面端 `active:` 也会触发但 mousedown 状态短暂，视觉无冲突。

**Safe area**：
- `index.html` viewport meta 增加 `viewport-fit=cover`
  ```
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
  ```
- 底部 sticky 区 `padding-bottom: env(safe-area-inset-bottom)`
- 顶部如需要：`padding-top: env(safe-area-inset-top)`（PlayingScreen header 用）

**Viewport 单位**：
- `100vh` → `100dvh`（dynamic viewport，自动适配 iOS Safari URL bar 收缩）
- 现有 `calc(100vh - 120px)` 用法（`Views.jsx:465,550,700`）改为 `calc(100dvh - 120px)`

**防误操作**：
- `<body>` CSS：`overscroll-behavior: none`（防 iOS 上拉刷新触发）
- UI chrome 上 `user-select: none` + `-webkit-touch-callout: none`（防长按弹出 iOS 选词菜单），但允许内容文本选中
- 不加 `maximum-scale=1`（避免损失无障碍缩放）

**Tailwind 配置补充**：
- `tailwind.config.js` 加 safe-area spacing：
  ```js
  spacing: { 'safe-b': 'env(safe-area-inset-bottom)', 'safe-t': 'env(safe-area-inset-top)' }
  ```

---

## 实现影响范围

### 新建文件
- `src/components/BottomSheet.jsx`（通用 sheet 容器）
- `src/components/BagSheet.jsx`（背包内容）

### 修改文件
- `src/App.jsx`：替换 GameMenuPanel render 为 BagSheet；调整 menu open/close state 命名
- `src/components/Screens.jsx`：PlayingScreen 重构 header / 底部 sticky 区 / 移除条件面板
- `src/components/Modals.jsx`：所有适用 modal 用 BottomSheet 包装
- `src/components/AchievementsView.jsx`：AchievementCardModal / WrappedPosterModal 用 BottomSheet 包装
- `src/styles.css`：safe-area utilities + body overscroll/user-select/touch-callout
- `tailwind.config.js`：safe-area spacing
- `index.html`：viewport-fit=cover

### 不动
- `src/engine/*`（业务逻辑零改动）
- `src/data/*`（内容零改动）
- `tests/*`（已有 245 测试覆盖逻辑层，本次纯 UI 改不影响）

---

## 测试计划

**自动化**：
- 现有 245 vitest 测试全过（必要条件）
- BagSheet 内容渲染：用 React Testing Library 加 1-2 个 smoke test，验证 5 stat / 周信息 / 设置项 都渲染

**手动**（必须）：
1. iOS Safari 实机：iPhone（任意带 home indicator 的型号）
2. Android Chrome：任意 Android 设备
3. 桌面 Chrome / Firefox：验证 md+ 断点 fallback 到居中 modal

**手动覆盖路径**：
- BEGIN → 一路打到 playing screen
- 切 4 个 tab，每个 tab 都看 sticky CTA 是否常驻
- 触发 1 个 modal（如 NPC dialog 或 Holiday）→ 验证 bottom-sheet 形态
- 打开背包 → 滚动 / handle 下拉 / backdrop tap 各关一次
- 横屏切换 → 不期望完美但不能崩
- 刷新页面（持久化恢复直接落到 playing）→ 验证背景音乐 retry fallback 仍生效

---

## 风险

1. **iOS Safari `position: sticky` bug**：iOS 16.x 某些版本对嵌套 flex 内 sticky 有 bug。Fallback：用 `position: fixed` + JS 计算偏移。先按 sticky 实现，遇到再换。
2. **BottomSheet drag 手势**（v1 不做）：拖动 handle 关闭 sheet 是 nice-to-have，但 touch event 容易和 iOS momentum scroll 冲突。v1 只支持 backdrop tap / 外部 close button 关闭，drag 留 v2。
3. **大量 modal 改造引入回归**：vitest 不覆盖 UI 渲染。Mitigation：
   - BottomSheet 抽象出通用组件，改 1 处 = 改全部
   - 手动测试覆盖所有改动 modal
4. **桌面端样式跨断点切换**：md 断点切换处可能有视觉跳变。Mitigation：md+ 时直接用居中 modal 老样式，bottom-sheet 仅 mobile 使用。

---

## 上线 / 迁移

- Solo 项目，按用户偏好直接合 main，不开 feature 分支
- 一次 commit 即可，不分阶段（改动有耦合，分批反而易破坏）
- 没 staging 环境，本地 dev + manual mobile test 即可

## v2+（本次不做但记录）

- BottomSheet 拖动手势关闭
- 横屏专属布局优化（split-pane）
- 字号 / 字体设置（背包追加段）
- 背包追加：成就快捷入口 / 关系网快照
- PWA manifest + standalone 模式
- 触觉反馈（Vibration API）
