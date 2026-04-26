# `backend/app/forum_routes.py` 拆分设计

**日期**: 2026-04-26
**作者**: Claude + Ryan
**状态**: Design — 待 user review
**前置工作**: `docs/superpowers/specs/2026-04-25-routers-py-split-design.md`（同模式，已实施完成；本次复用其全套基础设施）

---

## 1. 背景与动机

`backend/app/forum_routes.py` 当前 **8,345 行 / 64 个 `@router` 端点 / 30+ 个 helper**，是 `routers.py` 拆分完成后仓库里最大的单文件，也是当前的"单文件 ceiling"。

- 单挂载点 `main.py:511-512`（`forum_router` 自带 `prefix="/api/forum"`）
- 30+ helper 中 `build_user_info`、`preload_badge_cache`、`get_current_user_optional`、`visible_forums`、`invalidate_forum_visibility_cache` 等被 **19 处外部 importer** 复用（`custom_leaderboard_routes` / `discovery_routes` / `follow_routes` / `routes/message_routes` / `admin_student_verification_routes` 等）
- 8,345 行单文件对 IDE、code review、AI 上下文窗口都是显著负担——尤其是后续如果论坛域有功能迭代（举报系统、积分挂钩、新交互），AI 改动时的误改概率随上下文长度线性上升

## 2. 目标 / 非目标

### 目标

1. 把 `forum_routes.py` 的 64 个路由全部迁到 `backend/app/routes/forum_*_routes.py`，按职责切成 7 个聚焦域
2. **行为 100% 等价**：所有 `(method, URL)` 对在拆分前后都可达；无路由删除，diff 应为 ∅
3. 复用 `routers.py` 拆分留下的全套验收基础设施（`dump_routes.py`、`routes_baseline.json`、smoke 测试、`.github/workflows/routes-snapshot.yml`、`smoke_linktest.sh`）——零新增 infra
4. 保留 `forum_routes.py` 作为 helper 仓库（30+ 模块级 helper），对 19 处外部 importer **零改动**

### 非目标

- **不**改任何路由的业务逻辑、URL、响应结构、鉴权依赖
- **不**重组 / 下沉 helper（`build_user_info`、`visible_forums` 等留在 `forum_routes.py` 原位）——避免和路由迁移耦合
- **不**改 `/api/forum` 前缀（单前缀，不像 `routers.py` 是双前缀）
- **不**改外部 importer 任何一行 import 路径
- **不**引入子包（`app/routes/forum/`）——保持 `app/routes/` 现有扁平风格

## 3. 域划分（7 新文件）

64 条路由归入 **7 个新文件**，全部位于 `backend/app/routes/`，扁平命名 + `forum_` 前缀：

| # | 新文件 | 路由数 | 职责 | 代表路径 |
|---|---|---:|---|---|
| 1 | `forum_categories_routes.py` | ~11 | 板块 CRUD、申请审核、可见性、feed、统计 | `/forums/visible`, `/categories`, `/categories/{id}`, `/categories/{id}/feed`, `/categories/{id}/stats`, `/categories/requests*` |
| 2 | `forum_posts_routes.py` | ~13 | 帖子 CRUD + 管理动作 | `/posts`, `/posts/{id}`, `/posts/{id}/{pin,feature,lock,hide,restore,unhide}` |
| 3 | `forum_replies_routes.py` | ~4 | 回复 CRUD | `/posts/{id}/replies`, `/replies/{id}`, `/replies/{id}/restore` |
| 4 | `forum_interactions_routes.py` | ~8 | 点赞 + 收藏（含板块收藏） | `/likes`, `/posts/{id}/likes`, `/replies/{id}/likes`, `/favorites`, `/categories/{id}/favorite*`, `/categories/favorites/batch` |
| 5 | `forum_my_routes.py` | ~5 | 我的内容 | `/my/posts`, `/my/replies`, `/my/favorites`, `/my/likes`, `/my/category-favorites` |
| 6 | `forum_discovery_routes.py` | ~15 | 搜索、热门、排行榜、可链接搜索、用户公开数据、通知 | `/search`, `/search-linkable`, `/linkable-for-user`, `/hot-posts`, `/leaderboard/*`, `/users/{id}/stats`, `/users/{id}/hot-posts`, `/notifications/*` |
| 7 | `forum_admin_routes.py` | ~8 | 举报 + admin 管理 | `/reports`, `/admin/reports/{id}/process`, `/admin/operation-logs`, `/admin/stats`, `/admin/categories`, `/admin/pending-requests/count`, `/admin/fix-statistics` |

**精确路由 → 域映射的精度约束**：上表路由数为估计值；**精确映射由 writing-plans skill 生成**，每条路由引用 `forum_routes.py` 中对应行号。本 spec 只钉决策，不钉行号。

### `forum_routes.py` 的最终状态

- 保留 30+ 个模块级 helper（`_post_identity`、`_bg_translate_post`、`log_admin_operation`、`check_and_trigger_risk_control`、`get_current_user_secure_async_csrf`、`get_current_user_optional`、`get_current_admin_async`、`invalidate_forum_visibility_cache`、`clear_all_forum_visibility_cache`、`is_uk_university`、`visible_forums`、`assert_forum_visible`、`require_student_verified`、`check_forum_visibility`、`build_user_info`、`preload_badge_cache`、`build_admin_user_info`、`get_post_author_info`、`get_reply_author_info`、`get_user_language_preference`、`create_latest_post_info`、`strip_markdown`、`_parse_attachments`、`_resolve_linked_item_name`、`get_post_with_permissions`、`get_post_display_view_count`、`_batch_get_user_liked_favorited_posts`、`_batch_get_users_by_ids_async`、`_batch_get_post_display_view_counts`、`_batch_get_category_post_counts_and_latest_posts`、`update_category_stats`、`_parse_json_field`、`_post_to_feed_data`、`_task_to_feed_data`、`_service_to_feed_data`）+ 模块级 import 与常量
- 删除 `router = APIRouter(prefix="/api/forum", tags=["论坛"])`（最后一个 commit 一并做）
- 顶部 docstring 改为："Shared helpers for forum route modules. Routes have been migrated to `app/routes/forum_*_routes.py` (extraction completed 2026-04-XX)."
- 预期最终行数 ~1,200-1,500 行（纯 helper + import）

### 外部 importer 零改动

`forum_routes.py` 当前被 19 处外部 import 引用（覆盖 `custom_leaderboard_routes.py` / `discovery_routes.py` / `follow_routes.py` / `admin_student_verification_routes.py` / `routes/message_routes.py` 等）。所有这些 importer 引用的 helper（`build_user_info`、`preload_badge_cache`、`get_current_user_optional`、`visible_forums`、`invalidate_forum_visibility_cache` 等）**全部留在 `forum_routes.py` 原位**，零 import 路径修改。

**实施前置审计**（在 commit 0 之前由 writing-plans 阶段完成）：grep 全仓 `from app.forum_routes import` 与 `import app.forum_routes` 的所有用法，列出每处引用的具体名字，验证全部命中保留 helper 集合；若某 importer 引用了**路由处理函数**（不太可能，但需排查），spec 需要在对应 commit 加 re-export shim。

## 4. 挂载机制

### 4.1 新文件结构模板

```python
# backend/app/routes/forum_posts_routes.py
from fastapi import APIRouter
# ... 共享 import（Depends、schemas、crud、forum_routes 中的 helper 等）
from app.forum_routes import (
    visible_forums, build_user_info, get_post_with_permissions, ...
)

router = APIRouter()  # 不带 prefix

@router.post("/posts", response_model=schemas.ForumPostOut)
async def create_post(...):
    ...
```

**关键**：`APIRouter()` **不设 `prefix=`**，因为 main.py 集中挂载 `/api/forum` 前缀。

### 4.2 `main.py` 注册循环

```python
from app.routes import (
    forum_categories_routes,
    forum_posts_routes,
    forum_replies_routes,
    forum_interactions_routes,
    forum_my_routes,
    forum_discovery_routes,
    forum_admin_routes,
)

_FORUM_ROUTERS: list[tuple[APIRouter, str]] = [
    (forum_categories_routes.router, "论坛-板块"),
    (forum_posts_routes.router, "论坛-帖子"),
    (forum_replies_routes.router, "论坛-回复"),
    (forum_interactions_routes.router, "论坛-互动"),
    (forum_my_routes.router, "论坛-我的"),
    (forum_discovery_routes.router, "论坛-发现"),
    (forum_admin_routes.router, "论坛-管理"),
]
for r, tag in _FORUM_ROUTERS:
    app.include_router(r, prefix="/api/forum", tags=[tag])
```

当前 `app.include_router(forum_router)` 在过渡期内保留（路由全部已迁出后才删除），最后一个 commit 把 `forum_routes.py` 里的 `router = APIRouter(prefix="/api/forum", ...)` 删掉，并删除 `main.py` 里 `forum_router` 的 import + include_router 两行。

**注册顺序**：`_FORUM_ROUTERS` 循环位置**不挑剔**——`/api/forum/*` 前缀和其他显式声明优先匹配的路由（`staff_notification_router`、`profile_v2_router` 等）零 URL 冲突。放在 `_SPLIT_ROUTERS` 循环附近便于后续维护。

## 5. 验收机制

全套复用 `routers.py` 拆分留下的基础设施，零新增 infra。

### 5.1 路由清单快照（主验收）

- 脚本：**复用** `backend/scripts/dump_routes.py`（已存在，dump 全 app 路由，不挑域）
- Baseline：**重新生成一次**作为 forum 拆分的新基线（commit 0 跑一次，输出覆盖 `backend/scripts/routes_baseline.json`）
- 每个 commit 后：重新跑脚本，对比 baseline。**允许的差异 = ∅**（forum 拆分是纯移动，不删任何路由）。任何 diff（path 变了 / 数量变了）→ 立刻回滚

### 5.2 Smoke 测试

- 文件：**复用并扩展** `backend/tests/test_routers_split_smoke.py`
- 追加 7 条 forum 探针（每个新文件至少一条）：

| 域 | 探针 | 期望 |
|---|---|---|
| forum_categories | `GET /api/forum/categories` | 200 或 401（按当前公开性）|
| forum_posts | `GET /api/forum/posts/1` | 401 或 404 |
| forum_replies | `GET /api/forum/posts/1/replies` | 401 或 404 |
| forum_interactions | `POST /api/forum/likes` (空 body) | 401 或 422 |
| forum_my | `GET /api/forum/my/posts` (无 auth) | 401 |
| forum_discovery | `GET /api/forum/hot-posts` | 200 或 401 |
| forum_admin | `GET /api/forum/admin/stats` (无 auth) | 401 |

探针目的**仅证明**：路由已注册、依赖注入不崩。**不**覆盖业务流程。遇到对实际鉴权行为不确定的路径，允许按真实响应校准断言。

### 5.3 Import 完整性检查

每个 commit 跑：

```bash
python -c "from app.main import app; print('ok')"
python -c "from app.custom_leaderboard_routes import *; from app.discovery_routes import *; from app.follow_routes import *"
python -c "from app.admin_student_verification_routes import *; from app.routes.message_routes import *"
```

这五组 import 是 `forum_routes.py` 的主要外部消费路径，必须始终绿。

### 5.4 GitHub Actions 钩子

`.github/workflows/routes-snapshot.yml` **已存在**（`routers.py` 拆分时建立），覆盖本次拆分零改动。每次 push 自动跑 dump + diff + smoke。

### 5.5 Linktest 部署烟测（每 commit 后）

**复用** `backend/scripts/smoke_linktest.sh`，追加 5-6 条 forum 端点 curl：

```bash
# 追加到 smoke_linktest.sh
curl -sf "$BASE/api/forum/categories" -o /dev/null && echo "forum/categories OK" || echo "FAIL"
curl -sf "$BASE/api/forum/hot-posts" -o /dev/null && echo "forum/hot-posts OK" || echo "FAIL"
# ... 等
```

每个域 commit 推完都要跑一次，过了再开下一个 commit。

## 6. Commit 序列

**直接推 main**（用户偏好 `feedback_direct_to_main`，solo 项目）。每 commit 单独 push，等 Railway 部署 linktest 完成 + 烟测通过后才开下一个 commit。任一 commit 在 main 上挂掉 → `git revert <sha>` + push，Railway 自动部署回上一版。

| # | Commit | 域 | 路由数 | 风险 |
|---|---|---|---:|---|
| 0 | `chore(forum): regenerate route baseline + add forum smoke probes` | — | — | 无（纯增） |
| 1 | `refactor(forum): extract my-content routes` | forum_my | 5 | 低 |
| 2 | `refactor(forum): extract reply routes` | forum_replies | 4 | 低 |
| 3 | `refactor(forum): extract interaction routes (likes + favorites)` | forum_interactions | 8 | 低 |
| 4 | `refactor(forum): extract admin + report routes` | forum_admin | 8 | 中 |
| 5 | `refactor(forum): extract discovery routes (search + leaderboard + notifications)` | forum_discovery | 15 | 中 |
| 6 | `refactor(forum): extract category routes` | forum_categories | 11 | 中-高 |
| 7 | `refactor(forum): extract post routes + remove forum_router from main.py` | forum_posts | 13 | 高 |

**排序原则**：低风险低体量的域先做，建立流程与信心；核心业务（categories 含 visibility 逻辑、posts 是最大也最复杂）最后做。每个 commit 独立可 revert，互不依赖。

**为什么 categories 排在 posts 前**：categories 包含 `visible_forums` 调用（决定哪些板块对当前用户可见），但 `visible_forums` helper **保留在 `forum_routes.py`**，所以 categories 路由迁出时只是 import helper，不影响 posts 域。posts 是体量最大、helper 依赖最多的，放最后单独验证。

### 每个 commit 的 gate（强制，本地）

1. `python backend/scripts/dump_routes.py` → diff baseline：集合一致（forum 拆分允许差异 = ∅）
2. `pytest backend/tests/test_routers_split_smoke.py`：全绿
3. `python -c "from app.main import app"`：成功
4. Import 完整性 5 组检查（§5.3）：全绿
5. `pytest backend/tests/`（全量）：全绿

### 每个 commit 的 gate（push 后）

6. GH Actions `routes-snapshot.yml`：绿
7. Railway 部署 linktest 成功
8. `backend/scripts/smoke_linktest.sh` 跑一遍：所有探针返回预期码

任何一条未过 → 立即 `git revert`，分析后再续做。

## 7. 回滚 / 安全网

### 7.1 直推 main + 单 commit 隔离

每个 commit 是独立的纯路由迁移，commit N 失败不影响 commit N-1 的状态。回滚 = `git revert <sha>` + push，Railway 部署回上一版。无 feature 分支隔离层，保险全靠：

- 每 commit 的 8 道 gate（本地 5 道 + push 后 3 道）
- 单前缀挂载比 `routers.py` 双前缀**更简单**——少了一层"漏挂某前缀"风险

### 7.2 全局 abort

做到一半判断需重来：把已 commit 的批量 revert 回去（`git revert <oldest>..HEAD` + push 到 main）。

### 7.3 已知不回滚边界

- `forum_routes.py` 文件**不删**，仅清空 `router = APIRouter()`；30+ helper 全部保留
- 19 处外部 importer 路径**零改动**，回滚不涉及他们

## 8. 成功标准

所有条件同时满足方视为完成：

1. `backend/app/forum_routes.py` 行数从 8,345 下降到 ~1,200-1,500（仅剩 helper + import + 模块常量）
2. `backend/app/routes/` 下 7 个新 `forum_*_routes.py` 文件创建完毕、各自自洽
3. `dump_routes.py` 输出 diff = ∅（无路由删除，无路径变动）
4. `test_routers_split_smoke.py` 全绿（含新增 7 条 forum 探针）
5. 19 处外部 importer 零改动下仍能成功 import 并测试通过
6. Flutter dev build 对 linktest 后端：浏览板块、看帖子、点赞、搜索——冒烟正常
7. 8 个 commit（1 个 `chore(forum):` + 7 个 `refactor(forum):`）全部 push 到 main，commit message 清晰
8. `main.py` 中原 `forum_router` 的 import + include_router 两行删除，由 `_FORUM_ROUTERS` 列表循环替代

## 9. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 迁移过程中某 helper 被路由迁走（路由文件用 `def some_helper`，但 helper 本应留在 `forum_routes.py`） | 外部 importer 找不到 helper | commit 0 前置审计 grep 所有 `from app.forum_routes import`，列出全部被引用的 helper 名字，迁移时严格对照清单不动 |
| 某个路由的 path 在迁移中拼写错（少字符、多斜杠） | 客户端 404 | `dump_routes.py` 集合对比捕获 100%（forum 拆分 diff 应严格 = ∅） |
| 某新 router 漏挂 `/api/forum` prefix | 该域所有路由 404 | smoke test 对每个域至少一条断言；`_FORUM_ROUTERS` 循环统一加 prefix，结构上不可能漏 |
| `visible_forums` 等核心 helper 在迁移过程中被意外修改 | 板块可见性逻辑全局错乱 | 本次重构**不动 helper**；commit 内严格只做"路由函数从 A 文件搬到 B 文件 + 调整 import"，不重构、不优化 |
| 迁移期间有新路由被加进 `forum_routes.py`（其它工作流） | 可能漏迁 | 本次重构期间避免给 `forum_routes.py` 加新路由；如必须加，迁移 commit 显式带上 |
| 论坛通知（commit 5）迁移时和 WebSocket 推送依赖错配 | 通知功能坏 | 通知端点是纯 REST（拉取 + 已读标记），不和 WebSocket 推送链路耦合；smoke 覆盖 `GET /notifications` 注册即可 |
| `posts` 域（commit 7）端点最多最复杂，迁移过程中漏一两条 | 部分功能 404 | 排在最后，前 6 个 commit 已建立信心；dump_routes diff 100% 捕获 |

## 10. 范围外 / 后续

以下不在本次范围，记录以免遗忘：

- **forum 域 helper 重组**：把 30+ helper 按职责下沉（`build_user_info` → user_info_helpers、`visible_forums` → forum_visibility_helpers、batch_* → forum_batch_helpers），让 `forum_routes.py` 彻底退役为空文件。需要改 19 处 importer，独立成一次重构（属于第二阶段整洁化）
- **下一个待拆单文件**：`task_chat_routes.py` (6,244 行)、`flea_market_routes.py` (4,758 行)、`schemas.py` (5,022 行)、`models.py` (3,945 行)
- **schemas.py + models.py 拆分**：`schema_modules/` 占位包已建（2026-02-09），但计划没执行；这俩拆分价值最大但风险最高（全后端 import）
- **前缀审计 follow-up**：本次 forum 是单前缀 `/api/forum`，无前缀审计需求

## 11. 实施计划

本 spec 经 user approve 后，调用 `superpowers:writing-plans` skill 基于本文档产出逐 commit 的详细实现计划，包含：

- 每个 commit 要移动的精确路由列表（method + path + `forum_routes.py` 行号范围）
- 每个 commit 要复制的 import 与 helper 引用清单
- 每个 commit 的 gate 检查清单
- 前置审计 grep 任务（`from app.forum_routes import` 全仓扫描）的具体命令与预期输出

---

**Design sign-off**: 待 user review
