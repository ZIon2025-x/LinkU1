# Forum 体验优化：板块可选化 + 评论热度排序 + 折叠回复

**日期**: 2026-05-15
**作者**: Ryan + Claude
**状态**: Spec 已确认，待写实施 plan
**范围**: 两块并行改动 ——
- **Part 1**: 板块从必选改为可选话题
- **Part 2**: 评论热度排序 + 前端折叠

## 背景

当前发帖流程要求用户在 `forum_categories` 21 个 skill 板块（代购/辅导/翻译/设计/编程/写作…）+ general + 校园 + 达人 + admin-only 这 20+ 项里**必选一个**才能发布。

通过和用户讨论确认三个真实问题：

1. **板块语义错位**：`forum_categories` 的 skill 板块名字 = `TASK_TYPES`，本质是按"服务技能"切分的；但用户发帖动机更多按"日常 / 求助 / 经验 / 教程"切分；未来推荐 feed 又按"兴趣"切分。三层根本对不齐，所以"这条帖到底属于哪个板块"经常有边界感。
2. **必选无收益**：`backend/app/routes/forum_discovery_routes.py:73` 已经证明社区发现流的 `category_id` 是可选 query 参数——不传就出全部可见板块的帖子。**所以帖子无论选不选板块，都会出现在社区发现流**。强制选板块只是为了一个"板块详情页深耕入口"，对发现流毫无作用。
3. **板块冷热不均**：用户观察实际板块流量极不均衡，部分 skill 板块几乎无人发帖。

## 设计原则

- **板块降格为"话题"**：依然存在，但从必选变可选
- **入口决定默认值**：行为继承现有 `lockCategory:true` 模式（已在 `create_post_view.dart:43` 实现）
- **YAGNI**：不重做分类体系、不做 AI 自动归类、不引入 hashtag、不做"广场"虚拟板块——先把"可选"放出去看数据再决定下一步

## 数据模型变更

```sql
ALTER TABLE forum_posts ALTER COLUMN category_id DROP NOT NULL;
```

- `forum_posts.category_id` 从 NOT NULL 改 nullable
- `forum_categories` 表**完全不动**（21 个 skill + general + 校园 + 达人 + admin-only 全部原样保留）
- 历史帖子原 `category_id` 不动

## 行为定义

| 入口 | 进发帖页时的初始状态 | 用户能否改话题 | 提交时 `category_id` |
|---|---|---|---|
| 首页悬浮 + | `category_id = null`，话题区显示"+ 添加话题（可选）" | 能（从 21 个 skill 话题里选 1 个，或不选） | 可为 null |
| 板块详情页 + | 锁定到当前板块（现有 `lockCategory:true`） | 否 | 必为当前板块 id |
| 达人后台 + | 锁定到达人专属板块（现有） | 否 | 必为达人板块 id |
| Admin 公告 + | 锁定到 admin-only 板块（现有） | 否 | 必为 admin 板块 id |
| 编辑帖子 | 沿用原 `category_id`，可清空可改 | 能 | 可为 null |

**关键不变量**：`lockCategory:true` 路径的行为完全不变。新增逻辑仅作用于 `lockCategory:false` 且 `initialCategoryId == null` 的发帖。

## 话题选择器内容

发帖时的话题列表 =
`ForumPermissionHelper.filterPostableCategories(state.categories, currentUser)` 的输出
**减去**（admin-only ∪ 达人专属 ∪ 校园专属）
≈ **21 个 skill 板块 + general**

校园板块只在用户主动进了"我的学校"板块详情页时才被看到并锁定，不在通用话题选择器里出现。

## 读取/展示行为

- **帖子卡片**：`category_id != null` → 渲染话题 chip；为空 → 不渲染 chip
- **社区发现流**：行为不变（`forum_discovery_routes.py:73` 已是聚合所有可见帖）
- **板块详情页**：行为不变（按 `category_id` 过滤；NULL 帖不出现在任何板块详情页，这是预期行为——它们只活在社区发现流）
- **通知/权限里依赖 `category_id` 的可见性检查**：`category_id is None` 视为"对所有可见"（无归属板块就没有特殊可见性限制；学校私有板块的隔离仍由 `lockCategory` 路径强制）
- **`post_count` 统计**：NULL 不计入任何 category 的 `post_count`（自然不计入，无需特殊处理）

## 后端改动面

1. **Migration** (`backend/migrations/220_make_forum_post_category_optional.sql`)：
   ```sql
   ALTER TABLE forum_posts ALTER COLUMN category_id DROP NOT NULL;
   ```
2. **`backend/app/models.py`**：`ForumPost.category_id` 加 `nullable=True`
3. **`backend/app/schemas.py`**：
   - `ForumPostCreate.category_id`：`int` → `Optional[int] = None`
   - `ForumPostOut.category_id`：`int` → `Optional[int]`
4. **`backend/app/routes/forum_*` 路由**：
   - 创建/编辑路由：移除 `category_id` 必填校验（如有）；当 `category_id is None` 时跳过 `assert_forum_visible` / `is_admin_only` 检查
   - `forum_discovery_routes.py` 列表查询：当未传 `category_id` 时，`visible_category_ids` 过滤里要**额外包含 `category_id IS NULL`** 的帖子（否则 NULL 帖会被排除在社区发现流外，破坏核心承诺）
   - 通知相关 `category_id` 校验（`forum_discovery_routes.py:298-303` 等）：NULL 视为"可见"
5. **`scheduled_tasks.py` / `celery_tasks.py`** 若有依赖 category 的统计/清理：审核 NULL 兜底

## 前端改动面（Flutter）

1. **`link2ur/lib/data/models/forum.dart`**：
   - `ForumPost.categoryId`：`int` → `int?`
   - `CreatePostRequest.categoryId`：`int` → `int?`（构造函数也改可空）
2. **`link2ur/lib/features/forum/views/create_post_view.dart`**：
   - 去掉 `_selectedCategoryId == null` 的 warning + return（line 283-286）
   - 把"分类"措辞改"话题"（l10n key 改 `forumSelectCategory` → `forumSelectTopic` 或加新 key）
   - section label 改"添加话题（可选）"
   - 提交时允许 `category_id` 为 null
3. **`link2ur/lib/features/forum/views/edit_post_view.dart`**：允许清空话题
4. **`link2ur/lib/features/forum/views/forum_post_list_view.dart`** + 帖子卡片：category chip 条件渲染（`if (categoryId != null)`）
5. **`link2ur/lib/l10n/`**：新增/调整话题相关文案（en / zh / zh_Hant 三套）

## Web frontend 改动面

- `frontend/` 里发帖入口（如果有独立 Web 发帖 UI）做同样的可选化处理
- 帖子卡片同步条件渲染

## 不做的事（YAGNI）

- ❌ 不重做话题体系（保留 21 个 skill 话题）
- ❌ 不引入 hashtag（避免和现有话题/板块概念二元化）
- ❌ 不做 AI 自动推荐话题（先观察"可选"上线后的数据）
- ❌ 不做"广场"虚拟板块（NULL 就是 NULL，不做兜底 category）
- ❌ 不动校园 / 达人 / admin-only 板块的现有锁定逻辑
- ❌ 不重命名 `forum_categories` 表 / `category_id` 字段（只是 UI 文案改"话题"，DB 字段保留语义）

## 验收标准

- 从首页悬浮 + 入口发帖：不选话题也能成功发布
- 该无话题帖出现在社区发现流，但不出现在任何板块详情页
- 从板块详情页 / 达人后台 / Admin 入口发帖：行为和现状完全一致
- 历史帖子的话题展示和过滤行为不变
- 编辑现有帖子可以清空话题
- iOS + Android Flutter 端 + Web 端发帖行为一致

## 风险点

1. **NULL 帖出现在社区发现流的可见性过滤**：`forum_discovery_routes.py` 的 `visible_category_ids.in_()` 过滤逻辑必须改造为 `OR category_id IS NULL`，否则 NULL 帖会被吞掉。这是最容易踩坑的一处。
2. **学校私有板块隔离**：必须确认无 `category_id` 的帖子**不会**意外暴露给其他学校用户。当前社区发现流是按"可见 categories ∪ NULL"过滤；NULL 是全网可见而非校内可见，这是预期行为，但要在 review 时再次确认 product 意图。
3. **现有 `category_id` filter 的 BLoC 状态**：`ForumBloc` 切换板块时如何处理"全部"vs"未分类"vs"具体板块"三种状态，需要在实施时设计清楚。

---

# Part 2: 评论热度排序 + 渐进式折叠

## 背景

发帖页 mockup 评估时复盘评论详情页，三个观察：

1. **当前评论按时间正序展示**（`forum_replies_routes.py:85` `created_at.asc()`），热门评论可能埋在中间或末尾。
2. **后端一次拉满最多 500 条**（`forum_replies_routes.py:94`），热门帖一进详情页就拉一堆，浪费带宽 + 拖慢首屏。
3. **`@xxx` 精确跳转已经实现**（`forum_post_detail_view.dart:593-609` 用 `parentReplyId` 走 highlight stream），不需要额外改动。

## 设计原则

- **排序分层**：根评论按热度，子回复内部仍按时间——保住对话连贯性
- **渐进式展开**：默认每根评论只露 top 3 子回复，"展开剩余 N 条"按需分批拉
- **@ 跳转兼容折叠**：目标在折叠区时，自动触发加载到包含目标的那批，再 scroll + 高亮

## A. 评论排序：根评论按热度 / 子回复按时间

### 行为

| 排序模式 | 根评论 | 子回复 |
|---|---|---|
| `hot`（默认）| `like_count DESC, created_at DESC` | `created_at ASC`（对话顺序）|
| `time` | `created_at ASC` | `created_at ASC` |

子回复**始终按时间**，否则「@小红 平均 1.5 小时」可能排在「@阿明 想问一下你练多久」前面，对话链断。

### 后端改动

`GET /api/forum/posts/{post_id}/replies?sort=hot|time`（默认 `hot`）：
- 根评论查询加 ORDER BY 分支
- 子回复 ORDER BY 不变

### 前端改动

- 详情页加排序 chip："按热度 ▼ / 按时间 ▼"
- 切换时 `ForumBloc` 重 fetch（latest-request-wins 防 race）

## C. 渐进式折叠（替代纯前端折叠 C1）

### 行为

- **首屏**：每根评论展示前 3 条子回复 + "展开剩余 N 条回复" 按钮（N = `total_children - 3`）
- **点击展开**：分批加载下一组（每批 5 条）；按钮变成 "展开剩余 N-5 条" 或加载结束后消失
- **`@xxx` 跳转兜底**：如果 `parent_reply_id` 对应的回复**不在已加载列表里**：
  1. 先触发该根下的批量加载（直到包含 target，或一直加载到末尾）
  2. 加载完成 → scroll 到 target → 触发现有 800ms 黄色脉冲

### 数据流

**端点 1（改造）**：`GET /api/forum/posts/{post_id}/replies?sort=hot`
- 只返回根评论（`parent_reply_id IS NULL`），按 `sort` 排序
- 每个根附带：
  - `preview_children: List[ForumReplyOut]`（前 3 条按时间正序）
  - `total_children: int`（该根下子回复总数）

**端点 2（新增）**：`GET /api/forum/replies/{root_reply_id}/children?offset=3&limit=5`
- 返回该根评论的子回复分批
- offset 默认 3（跳过 preview）；limit 默认 5
- 返回 `replies + has_more`

### 后端改动

1. **`forum_replies_routes.py`** 重构 `get_replies`：
   - 根评论 query 加 `.where(parent_reply_id.is_(None))`
   - 用 `selectinload` + post-process 给每个根填充前 3 条 children
   - 单独 count 每根的 `total_children`
2. **新端点 `get_reply_children`**：cursor/offset 分页
3. **Schemas**:
   - `ForumReplyOut` 增 `preview_children: List[ForumReplyOut] = []` 和 `total_children: int = 0`（向后兼容默认值）
   - 新增 `ForumReplyChildrenPage { replies: List[ForumReplyOut], has_more: bool }`
4. **保留 500-cap 不动**：渐进加载后单次请求量级不会触及

### 前端改动

1. **`forum_repository.dart`**：
   - `getReplies(postId, {sort})` 返回新结构
   - 新方法 `getReplyChildren(rootReplyId, {offset, limit})`
2. **`forum_bloc.dart`**：
   - state 加 `Map<int rootId, List<ForumReply>> loadedChildren`
   - state 加 `Map<int rootId, bool> hasMoreChildren`
   - event：`ReplySortChanged`、`LoadMoreChildren(rootId)`、`ScrollToReply(replyId)`
3. **`forum_post_detail_view.dart`**：
   - 排序 chip + onChanged
   - "展开剩余 N 条" button + onTap dispatch `LoadMoreChildren`
   - `@xxx` onTap：若 target 不在 `loadedChildren[rootId]` 里 → 先 dispatch `ScrollToReply` 触发批量加载，加载完成后再走现有 highlight 流

## B. @xxx 精确跳转（已实现，无改动）

- `forum_replies.parent_reply_id` 已是指向具体回复的 FK
- `forum_post_detail_view.dart:593-609` 已用 `parentReplyId` + highlightStream 实现 800ms 黄色脉冲
- 唯一需要新增的是 C 引入的"target 在折叠区时先加载"逻辑（已包含在 C 的前端改动里）

## 验收标准（Part 2）

- 详情页打开后默认 `sort=hot`，根评论按 `like_count` 降序展示
- 切换"按时间"后，根评论按 `created_at` 升序展示
- 每根评论默认展示前 3 条子回复，第 4 条起折叠
- 点"展开剩余 N 条"后，新加载 5 条子回复追加显示，按钮文案更新
- 全部加载完后按钮消失
- 点击 `@xxx` 跳转：目标在折叠区时自动加载该根全部子回复 → scroll → 黄色脉冲

## 不做的事（Part 2 YAGNI）

- ❌ 不做服务端真分页根评论（500-cap + 前 N 根足够，未来加 cursor 再说）
- ❌ 不引入 cursor 分页（offset/limit 简单够用；forum 场景子回复并发插入率低）
- ❌ 不做"按踩数排序"或"按引用数排序"等高级排序
- ❌ 不动 reply 写入路径（创建/删除/点赞接口完全不变）

## 风险点（Part 2）

1. **排序切换 race condition**：用户快速切 hot↔time 时旧请求可能后到。`ForumBloc` 实施时用 sequence id 或 dropping pattern 保证 latest-wins。
2. **`@xxx` 跳转在跨根评论场景下的体验**：如果被 @ 的回复属于另一个根评论的子回复（极少见但有可能），需要决定是 scroll 到那个根并展开，还是降级展示一个 toast。本期先按"同根折叠区自动展开"实现，跨根降级为不展开仅尝试 scroll（如果该根的 preview 里有则可见，没有则不动）。
3. **`total_children` 准确性**：删除子回复时要保证根评论的 `total_children` count 同步。当前 reply 删除是软删（`is_deleted=True`），需要在 count 查询里加 `is_deleted=False` 过滤——否则数字会虚高。
4. **历史数据兼容**：旧客户端拿到的 `ForumReplyOut` 不带 `preview_children`/`total_children` 字段，schema 默认值要兜底。
