# Forum UI 视觉重做（发帖页 + 详情页）

**日期**: 2026-05-17
**作者**: Ryan + Claude
**状态**: Spec 已确认，待写实施 plan
**前置**: 行为层重做（`2026-05-15-forum-category-optional-design.md`）已完成全部 37 commits。本 spec 是其视觉对照实施。

## 背景

2026-05-15 用户最初要求"发帖页太朴素，写 HTML mockup 给我看"。我做了 `link2ur/docs/mockups/forum-create-post-mockup.html`（现代轻拟物 + 横向底部工具栏 + 详情页对照视图）。讨论过程中话题转向"板块必选有必要吗"，spec 落在**行为重做**（板块可选 + 评论排序+折叠）上，已实施完毕。

但 mockup 上那套**视觉**——底部 4 色工具栏、大头作者条 + 认证勾、PDF 进度条、紫色关联卡、3 图无缝拼、彩色头像评论卡、@ 跳转黄色脉冲——目前 Flutter 端**完全没做**，UI 仍是行为重做前的原结构，只多了一个排序 chip 和一个"展开剩余"文字按钮。

本 spec 收口这个视觉缺口。

## 设计原则

1. **复用现有设计 token**：所有颜色/圆角/间距/阴影走 `core/design/app_colors.dart` / `app_radius.dart` / `app_spacing.dart` / `app_shadows.dart`。mockup 上找不到精确对应的颜色用最近 token 填，**不为这次重做引入新 token**。
2. **暗色模式优先**：每个新组件双模适配，浅色对齐 mockup，深色用 `AppColors.xxxFor(brightness)` 系列。
3. **零行为改动**：BLoC events/state/repository/endpoint 全部保留。所有现有交互（@ 跳转、展开、排序、点赞、删除、举报、编辑、官方任务发帖、达人板块发帖、admin 公告）继续走原 dispatch path。
4. **骨架屏替代转圈**：详情页加载用 `core/widgets/skeleton_*`（项目已有），不是 `CircularProgressIndicator`。
5. **动画过渡保守**：implicit animations（`AnimatedContainer` / `AnimatedOpacity` / `FadeTransition`）+ 评论高亮脉冲沿用现有 `_highlightStream`。不引入 third-party 动画库。

## 范围

两个 page 文件：
- `link2ur/lib/features/forum/views/create_post_view.dart`
- `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

**不在范围内**：
- 帖子列表卡片 / 板块详情页 / 我的回复 / 我的收藏 / 评论编辑 dialog —— 这些都用现有视觉，下次另开 spec
- 表情选择器（mockup 把表情位换成了话题，本来就没有表情功能）
- 富文本编辑（mockup 也没有，正文仍是纯文本 `TextField multiLine`）

## 组件清单

### 发帖页（`create_post_view.dart`）

| 私有 widget | 替换什么 | 关键设计点 |
|---|---|---|
| `_CreateAppBar` | 现有 AppBar | 渐变蓝发布药丸（gradient `[primary, primaryLight]`），sticky 顶部，亮度自适应 |
| `_DraftBanner` | **沿用现有** | 视觉小调：加 icon + 时间副标题，已是 spec 内容 |
| `_TopicChip` | 替换大分类卡 | 小药丸：emoji + 名 + ×；**仅选中时渲染**；未选则不显示，由底部工具栏的 `话题` 按钮触发 picker |
| `_TitleField` | 现有 TextField | 大字号、粗体、无边框、`textInputAction: next` |
| `_ContentField` | 现有 TextField | 大书写区（`minLines: 10`），无边框，字数计数器右下角 |
| `_ImageThumbGrid4` | 现有 Wrap+ImageRemoveButton | 4 列 1:1 网格，第一张带"封面"徽章，其余带顺序号；dashed 加号位（最多 5） |
| `_FilePdfCard` | 现有 file card | PDF 红渐变图标（`#F24D4D → #FF7A7A`）+ 名 + 大小 + 上传进度条 + 圆形 × 按钮 |
| `_LinkedChip` | 现有 OutlinedButton/Chip | 紫色渐变（`#7359F2 → #A18BFF`）+ 类型标签 + 名字（≤1 行 ellipsis）+ × |
| `_BottomComposerToolbar` | **全新** | sticky 底部，4 键横排：图片绿 / 附件红 / 关联紫 / 话题蓝，每键带角标 count，半透明 blur 背景 |

### 详情页（`forum_post_detail_view.dart`）

| 私有 widget | 替换什么 | 关键设计点 |
|---|---|---|
| `_DetailCompactAppBar` | 现有 AppBar | 返回 + 迷你头像作者卡 + + 关注 outlined 按钮 + 三点更多 |
| `_AuthorHeader` | 现有作者行 | 44×44 圆头像（紫色渐变 + initial）+ 认证蓝勾 + 角色·时间·**同城高亮** |
| `_PostBody` | 现有 Text | `white-space: pre-wrap` 风格，font-size 15 line-height 1.65 |
| `_PostImageGrid3` | 现有图片网格 | 3 列无缝拼接 + 第三张 `+N` 黑色半透明遮罩（当 N≥4） |
| `_PostFileCard` | 现有 file widget | PDF 红渐变图标 + 名 + 大小+页数 + 蓝色"下载"药丸 |
| `_LinkedItemCard` | 现有 linked | 紫色渐变图标方块 + 类型标签 + 名字 + 右侧 `›` 箭头 |
| `_StatsRow` | 现有 | 👁️ 浏览数 · 编辑时间，灰色小字 |
| `_EngagementBar` | 现有底部操作 | 跨满宽 4 键：❤️ count（已点红） · 💬 count · 📤 count · 🔖 count（已收藏橙），顶下 1px divider |
| `_CommentsHeader` | **现有**（Task 15） | 视觉收紧：count 灰、sort chip 圆角胶囊 |
| `_RootReplyGroup` | **现有**（Task 15） | 加蓝色 "X 条回复" 徽章（仅 totalChildren > 0 时） |
| `_CommentItem` | 现有 | 36×36 彩色圆头像（4 色渐变循环按 author_id 取）+ 名 + 内容 + footer：时间·❤️ count·回复 |
| `_NestedReplyItem` | 现有（缩进 child） | 缩进 46px + 28×28 头像 + `@xxx` 蓝色 mention chip |
| `_PulsingComment` | 包装高亮态 | 黄色背景 1.6s 脉冲 2 次（被 @ 跳转锚定时） |
| `_ExpandMoreReplies` | **现有**（Task 15） | 重做：18px 短虚线 + 蓝色文字 "展开剩余 N 条回复" |
| `_BottomCommentInput` | 现有底部输入 | sticky 圆形头像 + 圆角灰底输入条 + 右侧表情/点赞快捷圆按钮 |

### 共享 widget（抽到 `link2ur/lib/features/forum/widgets/`）

仅当组件**两个页面都用**才抽出去，否则内联：
- `topic_chip.dart` — 发帖页/详情页都展示选中话题，统一外观

其余都是单 page 私有 widget，不抽。

## 数据流 / 行为

**完全不变**。

- ForumBloc events / state / repository / endpoint：零改动
- 现有交互全部保留：@ 跳转 + highlightStream、展开剩余 N 条、排序切换、点赞乐观更新、删除级联、举报、编辑、官方任务关联、达人板块锁定、admin 公告锁定
- `lockCategory == true` 路径行为不变：发帖页锁定话题展示，UI 用现有方式（read-only chip + 锁图标），不渲染底部工具栏的"话题"按钮（已锁定无需切换）

## 错误/边界处理

- **暗色模式**：每个组件 `build()` 顶部 `final isDark = Theme.of(context).brightness == Brightness.dark;`，颜色走 `AppColors.xxxFor(isDark ? Brightness.dark : Brightness.light)`
- **加载状态**：`state.status == ForumStatus.loading` 时详情页 body 渲染骨架屏（`core/widgets/skeleton_*` 现有），不是 `CircularProgressIndicator`。发帖页提交中 `state.isCreatingPost` 仍走现有 "发布" 按钮转圈（不动）
- **错误**：`context.localizeError(state.errorMessage)` + `ErrorStateView` 沿用，视觉换成新设计
- **空评论**：mockup 没画 —— 简单显示一行 "暂无评论，做第一个" + 暗色文字（不画插画，YAGNI）
- **空图片/附件/关联**：未选时不渲染那一段（不显示空占位），底部工具栏角标也不显示

## 文件结构

- 私有 widget 都内联在对应 page 文件里（保留单文件易导航）
- 共享 widget（`_TopicChip`）抽到 `link2ur/lib/features/forum/widgets/topic_chip.dart`
- 预计每个 page 文件最终 ~1000-1200 行（单文件略大但单职责清晰，避免跨文件跳转）
- 现有 helper（`_handleMentionTap` / `_replyKeys` / `_highlightStream` / `_pruneReplyKeys`）保留位置不变

## 测试

- **不写新 widget test**：纯视觉重做，自动化 widget test 对 visual regression 价值低
- **flutter analyze 0 error 是硬门槛**
- **回归门槛**：现有 33 BLoC test + 6 sort/load more test + 4 create/edit test = 43 test 必须不回归
- **真正验证 = 手动跑 dev**：浏览器 + 真机各 5 分钟，浅色 + 深色双 mode 看一遍
  - 发帖页：草稿恢复 / 不选话题 / 选话题 + 删 / 加图至 5 张 / 删图 / 上传 PDF / 加关联 / 锁定话题模式（从板块详情页发帖）
  - 详情页：默认按热度 / 切按时间 / 展开剩余 N / 点 @xxx 普通跳转 / 点 @xxx 折叠区跳转 / 点赞根 / 点赞子 / 删子 / 收藏 / 下拉刷新

## 执行节奏

- 不动行为意味着可以**细粒度 commit**：一个 widget 一个 commit
- 估计 18-22 个 commit 跨两个页面
- 发帖页 8-10 个 commit（含底部工具栏抽 widget）+ 详情页 10-12 个 commit
- 最后一个 commit 整页串起来 + flutter analyze 收尾

## 不做的事（YAGNI）

- ❌ 不引入新设计 token，所有颜色用现有 `AppColors`
- ❌ 不引入 third-party 动画库（lottie / rive / animations）
- ❌ 不做空状态插画
- ❌ 不重构其他 forum 页面（列表 / 板块详情 / 我的）
- ❌ 不抽通用底部工具栏 widget（其他 page 没用，YAGNI）
- ❌ 不做 widget test
- ❌ 不改 BLoC / repository / API / schemas / 数据模型

## 风险点

1. **现有 view 大文件改动面广**：`forum_post_detail_view.dart` 当前 ~1900 行，本次重做大量行；diff review 困难。**对策**：细粒度 commit，每个 widget 替换独立 commit
2. **暗色模式 mockup 没画**：颜色判断只能凭对设计系统的理解。**对策**：每个 widget 实施完成立刻 flutter run -d web-server 浅+深两 mode 截图自检
3. **官方任务 / 达人板块 / admin 公告锁定模式**：mockup 没画这些场景。**对策**：保留现有锁定 widget 不动，只重做非锁定路径
4. **骨架屏组件可能不齐**：`core/widgets/skeleton_*` 现状未审。**对策**：实施时如缺则按 mockup body 主结构现写一个 skeleton（接受为本 spec 的一部分）

## 验收标准

- 发帖页视觉 ≈ mockup（适配现有设计系统的近似度）
- 详情页视觉 ≈ mockup（同上）
- 浅色 + 暗色双模适配，无明显错配色 / 透明白底
- 所有现有交互流程通过手动 dev 跑一遍：发帖（锁定+非锁定）、编辑、删帖、回复、@ 跳转、展开折叠、排序切换、点赞、收藏、举报
- 43 个回归测试不破
- flutter analyze 0 error（pre-existing curly braces info lints 可接受）
