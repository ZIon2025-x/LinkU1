# Forum 板块：从必选 → 可选话题

**日期**: 2026-05-15
**作者**: Ryan + Claude
**状态**: Spec 已确认，待写实施 plan

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
