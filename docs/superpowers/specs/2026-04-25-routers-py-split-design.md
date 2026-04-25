# `backend/app/routers.py` 拆分设计（2026-04-25 版）

**日期**: 2026-04-25
**作者**: Claude + Ryan
**状态**: Design — 待 user review
**Supersedes**: `docs/superpowers/specs/2026-04-17-routers-split-design.md`（同主题，未 approve；本次复用其骨架并 patch 三处差异）

---

## 0. 与 2026-04-17 版的差异（变更摘要）

旧 spec 的设计大体保留，本次 brainstorm 仅修订三点：

| # | 项 | 旧 spec | 本版 | 理由 |
|---|---|---|---|---|
| 1 | 分支策略 | feature 分支 `refactor/split-routers`，11 commit 后 `git merge --ff-only` 合 main | **直接推 main**，每 commit 单独 push | 用户偏好 `feedback_direct_to_main`；并且每 commit 推一次能让 Railway 部署 linktest，得到**逐 commit** 的 staging 烟测信号，feature 分支期间这层信号是隐藏的 |
| 2 | 拆分后续 | 未规划 | 7 个域全部拆完后，**用 `/schedule` 起一个 2 周后的 agent 做"前缀审计"**：扫 Flutter / Web 实际调用的前缀，把不需要的那一侧 mount 删掉 | 双挂载是过渡保险，长期保留会污染 main.py；用 schedule 把"清洁化"和"主拆分"解耦 |
| 3 | CI 工具链 | `.github/workflows/routes-snapshot.yml`（新建） | 同；明确 fit 进既有 6 个 workflow 的风格（`api-tests.yml` / `main-ci.yml` 等） | `.github/workflows/` 已经在用，新工作流和现有保持一致即可 |

其余决策（域划分、子包位置、双挂载、验收机制、debug 路由删除、外部 importer re-export）均沿用旧 spec。

---

## 1. 背景与动机

`backend/app/routers.py` 当前 **15,232 行 / 162 个路由装饰器 / ~19 个模块级辅助函数**，是 backend 最大的单文件。

- 原计划写在 `backend/app/routes/__init__.py` 注释里（基于 12,748 行估算、7 个域），自该计划写就以来文件又增长 ~2,500 行，溢出原 7 域假设。
- 同级目录 `backend/app/` 下已有 70+ 个独立 `*_routes.py` 文件，每个都有独立 `APIRouter` 并在 `main.py` 单独 `include_router` 注册——`routers.py` 是唯一的巨石例外。
- 该文件同时被挂在 **`/api/users`** 和 **`/api`** 两个 URL 前缀下（`main.py:283` 和 `main.py:339`），所有路由双暴露。Flutter 与 Web 前端对**两个前缀都有真实流量**，不能废除任一。
- 15,232 行单文件对 IDE、linter、code review、AI 上下文窗口都是明显负担。

## 2. 目标 / 非目标

### 目标

1. 把 `routers.py` 的 162 个路由全部迁到 `backend/app/routes/*_routes.py`，每个新文件按职责聚焦一个域。
2. **行为 100% 等价**：除被主动删除的 10 个 debug 路由外，所有 `(method, URL)` 对在拆分前后都可达，且在 `/api/` 与 `/api/users/` 两个前缀下都可达。
3. 建立可复用的验收机制：路由清单快照 + smoke test，保证本次不出回归、并可在未来路由变动时复用。
4. 保留 `routers.py` 作为 helper 仓库（19 个模块级 `_xxx` 函数），对 4 处外部 importer 零改动。

### 非目标

- **不**改任何路由的业务逻辑、URL、响应结构、鉴权依赖。
- **不**拆分 `schemas.py`（4,977 行）或重建 `crud.py`——独立的技术债，以后再说。
- **不**统一 `/api` 与 `/api/users` 前缀——破坏性改动，需要前端配合，不在本次范围（参见 §10 follow-up）。
- **不**迁出 `routers.py` 里的 19 个辅助函数；这轮只动路由。
- **不**引入 `combined_router` 间接层——老计划的 `routes/__init__.py` `combined_router` 设想已放弃，保持和项目现有 `*_routes.py` 扁平挂载风格一致。

## 3. 域划分（10 新文件 + 1 合并 + 10 删除）

162 条路由归入 **10 个新文件**（`backend/app/routes/*_routes.py`，与既有 10 个小模块同居子包），另有 13 条 admin/task-expert 路由直接**并入已有的** `backend/app/admin_task_expert_routes.py`，10 条 debug 路由直接删除。

| # | 新文件 | 路由数 | 职责 | 代表路径 |
|---|---|---|---|---|
| 1 | `auth_inline_routes.py` | ~13 | 注册、邮箱验证、密码重置、用户登出、CSP 报告等「旧 auth」路由（不含 `secure_auth_routes.py` 已覆盖的部分） | `/register`, `/verify-email/*`, `/forgot_password`, `/reset_password/{token}`, `/confirm/{token}`, `/admin/login`, `/logout`, `/csp-report`, `/password/validate`, `/user/info` |
| 2 | `task_routes.py` | ~18 | 任务生命周期、推荐、评价 | `/tasks/{id}/{accept,approve,reject,reward,visibility,review,complete,dispute,cancel,delete,history}`, `/recommendations`, `/my-tasks`, `/tasks/{id}/reviews`, `/users/{id}/received-reviews` |
| 3 | `refund_routes.py` | ~8 | 退款与争议 | `/tasks/{id}/refund-request*`, `/refund-status`, `/dispute-timeline`, `/refund-history`, `/confirm_completion` |
| 4 | `profile_routes.py` | ~10 | 个人资料、统计 | `/profile/me`, `/profile/{user_id}`, `/profile/{avatar,timezone,…}`, `/users/{id}/task-statistics` |
| 5 | `message_routes.py` | ~17 | 消息、通知、设备 token、账号删除、联系人、共享任务 | `/messages/*`, `/notifications/*`, `/users/device-token`, `/users/account`, `/contacts`, `/users/shared-tasks/{…}` |
| 6 | `payment_inline_routes.py` | ~10 | 支付、Stripe webhook、VIP、Apple IAP | `/tasks/{id}/pay`, `/stripe/webhook`, `/tasks/{id}/confirm_complete`, `/users/vip/*`, `/webhooks/apple-iap` |
| 7 | `cs_routes.py` | ~30 | 客服全链路（最大一块） | `/customer-service/*`, `/user/customer-service/*`, `/admin/customer-service-*`, `/timeout-*` |
| 8 | `translation_routes.py` | ~12 | 翻译 | `/translate/*` |
| 9 | `system_routes.py` | ~11 | 系统设置、偏好、时区、banner、版本检查、FAQ、法律文档、岗位申请 | `/stats`, `/system-settings/public`, `/user-preferences`, `/timezone/info`, `/banners`, `/app/version-check`, `/faq`, `/legal/{doc_type}`, `/job-*` |
| 10 | `upload_inline_routes.py` | ~7 | 图片/文件上传（与 `upload_v2_router` 并存） | `/upload/image`, `/upload/public-image`, `/upload/file`, `/private-image/{id}`, `/private-file`, `/refresh-image-url`, `/messages/generate-image-url` |

**并入既有文件**：12,705–13,574 行的 13 条 admin/task-expert 路由 → 直接并入 `backend/app/admin_task_expert_routes.py`（commit 11）。

**删除**：10 条 debug / test 路由，一律直接删，不迁移：

- `/register/test`、`/register/debug`
- `/debug/test-token/{token}`、`/debug/simple-test`、`/debug/fix-avatar-null`、`/debug/check-user-avatar/{user_id}`、`/debug/test-reviews/{user_id}`、`/debug/session-status`、`/debug/check-pending/{email}`、`/debug/test-confirm-simple`

### 路由→域映射的精度约束

上表的路由数为估计值；**精确的路由→域映射由实现计划（writing-plans skill）生成**，每条路由引用 `routers.py` 中对应行号。本 spec 只钉决策，不钉行号。

### `routers.py` 的最终状态

- 保留 19 个模块级 `_xxx` 辅助函数（`_handle_account_updated`、`_handle_dispute_team_reversal`、`_payment_method_types_for_currency`、`_safe_json_loads`、`_request_lang_sync`、`_get_task_detail_legacy`、`_safe_parse_images`、`_safe_int_metadata`、`_decode_jws_*`、`_handle_v2_*`、`_translate_missing_tasks_async`、`_trigger_background_translation_prefetch`、`_parse_semver`、`_deprecated_get_public_task_experts`、`admin_required`、`require_debug_environment`）+ 模块级 import 与常量。
- 删除 `router = APIRouter()`（最后一个 commit 一并做）。
- 顶部 docstring 改为："Shared helpers for route modules. Routes have been migrated to `app/routes/*_routes.py`."

### 外部 importer 零改动

`routers.py` 的 4 处外部 importer 继续有效：

- `backend/app/async_routers.py:1743` → `from app.routers import confirm_task_completion as sync_confirm`
- `backend/app/expert_consultation_routes.py:951` → `from app.routers import _payment_method_types_for_currency`
- `backend/tests/test_stripe_webhook_handlers_team.py` → `from app.routers import _handle_account_updated`
- `backend/tests/test_team_dispute_reversal.py` → `from app.routers import _handle_dispute_team_reversal`

第一条（`confirm_task_completion`）是公有路由处理函数，会随 refund 域迁走。**在 commit 5（提取 refund 域）中**，`routers.py` 需要**同步加一行** `from app.routes.refund_routes import confirm_task_completion  # noqa: F401` 重导出，以保持 `async_routers.py:1743` 的 import 站点不变。其余三条函数（`_payment_method_types_for_currency`、`_handle_account_updated`、`_handle_dispute_team_reversal`）本身就留在 `routers.py` 里，无需额外处理。

**实施前置审计**（在 commit 0 之前由 writing-plans 阶段完成）：grep 全仓 `from app.routers import` 与 `import app.routers` 的所有用法，验证仅有上述 4 处；若发现新的，spec 需更新（但本 spec 对"保留 helper + commit 5 添加 re-export"的处理模式不变）。

**特殊路由位置**：`/logout`（位于 cs 区附近）在逻辑上归属 `auth_inline_routes.py`。commit 4（auth-inline 提取）时，实施计划需从 cs 区单独挑出这条路由迁走，不要等 commit 10 才处理。

## 4. 验收机制

### 4.1 路由清单快照（主验收）

新脚本：`backend/scripts/dump_routes.py`

- 启动 FastAPI app（仅 import，不绑定端口）
- 遍历 `app.routes`，仅保留 `APIRoute` 实例（跳过 `/docs`、`/openapi.json` 等）
- 对每条路由，输出 `{"method": <单 verb>, "path": <完整 URL>, "name": <endpoint 函数名>}`
- 按 `(method, path)` 字典序排序后 dump 为 JSON

**Baseline**：commit 0 跑一次，输出 `backend/scripts/routes_baseline.json` 并入库。

**每个 commit 后**：重新跑脚本，对比 baseline。允许的差异**仅**：

1. 被刻意删除的 10 条 debug 路由（在 commit 4 后出现在 diff 的 "removed" 侧）
2. 拆分是纯移动，(method, path) 集合不变——如果 diff 显示 path 变了，**立刻回滚**

### 4.2 Smoke 测试

新文件：`backend/tests/test_routers_split_smoke.py`

约 15 个 `TestClient` 探针，每个探针在 `/api/*` 与 `/api/users/*` 两个前缀各测一次（≈ 30 个断言），每条域至少覆盖一条路径：

| 域 | 探针 | 期望 |
|---|---|---|
| auth_inline | `POST /csp-report` | 204 或可接受状态码 |
| task | `GET /tasks/1/history` (无 auth) | 401 |
| refund | `GET /tasks/1/refund-status` (无 auth) | 401 |
| profile | `GET /profile/me` (无 auth) | 401 |
| message | `GET /messages/unread/count` (无 auth) | 401 |
| payment | `POST /stripe/webhook` (空 body) | 400 |
| cs | `GET /customer-service/status` (无 auth) | 401 |
| translation | `GET /translate/metrics` | 实测值 |
| system | `GET /banners` | 200 |
| system | `GET /faq` | 200 |
| upload_inline | `POST /upload/image` (无 file) | 422 |

探针目的**仅证明**：路由已注册、依赖注入不崩、双前缀都生效。**不**覆盖业务流程。遇到对实际鉴权行为不确定的路径（如 `/translate/metrics`），允许按真实响应校准断言。

### 4.3 Import 完整性检查

每个 commit 跑：

```bash
python -c "from app.main import app; print('ok')"
python -c "from app.async_routers import *; from app.expert_consultation_routes import *"
pytest backend/tests/test_stripe_webhook_handlers_team.py backend/tests/test_team_dispute_reversal.py
```

这三组 import / test 是 `routers.py` 的外部消费路径，必须始终绿。

### 4.4 GitHub Actions 钩子

新增 `.github/workflows/routes-snapshot.yml`，与既有 `api-tests.yml` / `main-ci.yml` 同风格，在 push 到任意分支时：

1. 安装 backend 依赖
2. 跑 `dump_routes.py` 输出 `routes_current.json`
3. `diff routes_baseline.json routes_current.json`（允许 commit 4 之后 10 条 debug 缺席；其它差异 fail）
4. 跑 `pytest backend/tests/test_routers_split_smoke.py`

merge 到 main 后此 workflow 仍常驻，作为未来路由回归的长期守门。

### 4.5 Linktest 部署烟测（每 commit 后）

直推 main → Railway 自动部署到 linktest → 部署成功后**手动**或脚本化跑：

```bash
backend/scripts/smoke_linktest.sh   # 新建，curl 上述探针打 https://linktest.up.railway.app
```

每个域 commit 推完都要跑一次，过了再开下一个 commit。这是 GH Actions 抓不到的"实际部署后是否健康"那一层。

## 5. 双前缀挂载机制

### 5.1 新文件结构模板

```python
# backend/app/routes/task_routes.py
from fastapi import APIRouter
# ... 共享 import（Depends、schemas、crud 等）

router = APIRouter()

@router.post("/tasks/{task_id}/accept", response_model=schemas.TaskOut)
async def accept_task(task_id: int, ...):
    ...
```

**关键**：`APIRouter()` **不设 `prefix=`**，因为 main.py 会双挂载。

### 5.2 `main.py` 注册循环

```python
from app.routes import (
    auth_inline_routes,
    task_routes,
    refund_routes,
    profile_routes,
    message_routes,
    payment_inline_routes,
    cs_routes,
    translation_routes,
    system_routes,
    upload_inline_routes,
)

_SPLIT_ROUTERS: list[tuple[APIRouter, str]] = [
    (auth_inline_routes.router, "auth-inline"),
    (task_routes.router, "任务"),
    (refund_routes.router, "退款"),
    (profile_routes.router, "用户资料"),
    (message_routes.router, "消息与通知"),
    (payment_inline_routes.router, "支付-inline"),
    (cs_routes.router, "客服"),
    (translation_routes.router, "翻译"),
    (system_routes.router, "系统"),
    (upload_inline_routes.router, "上传-inline"),
]

for r, tag in _SPLIT_ROUTERS:
    app.include_router(r, prefix="/api/users", tags=[tag])
    app.include_router(r, prefix="/api", tags=[tag])
```

当前 `main_router` 的两次 `include_router(main_router, prefix="/api/users" / "/api", ...)` 在过渡期内保留，最后一个 commit 删除 `main_router` 挂载（helper-only 的 `routers.py` 不再需要被 include）。

**注册顺序**：`_SPLIT_ROUTERS` 循环必须放在所有"显式声明优先匹配"的路由（`staff_notification_router`、`profile_v2_router` 等，参见 `main.py` 现有注释）之**后**注册，以保留既有匹配优先级。

### 5.3 `backend/app/routes/__init__.py`

保留为空文件或仅含文档注释；可更新原有"迁移计划"注释为"迁移已完成 / 见 specs/2026-04-25-...md"。**不**暴露 `combined_router`；保持和现有 `*_routes.py` 的扁平挂载风格一致。

## 6. Commit 序列

**直接推 main**（用户偏好 `feedback_direct_to_main`，solo 项目）。每 commit 单独 push，等 Railway 部署 linktest 完成 + 烟测通过后才开下一个 commit。任一 commit 在 main 上挂掉 → `git revert <sha>` + push，Railway 自动部署回上一版。

| # | Commit | 域 | 路由数 | 风险 |
|---|---|---|---|---|
| 0 | `chore(routers): add route snapshot script + baseline + GH Actions workflow` | — | — | 无（纯增） |
| 1 | `refactor(routers): extract translation routes` | translation | 12 | 低 |
| 2 | `refactor(routers): extract system routes` | system | 11 | 低 |
| 3 | `refactor(routers): extract upload-inline routes` | upload_inline | 7 | 中 |
| 4 | `refactor(routers): extract auth-inline routes + delete 10 debug endpoints` | auth_inline | ~23 → ~13（删 10 debug，并收 `/logout`） | 中 |
| 5 | `refactor(routers): extract refund routes + add confirm_task_completion re-export` | refund | 8 | 中 |
| 6 | `refactor(routers): extract profile routes` | profile | 10 | 中 |
| 7 | `refactor(routers): extract message routes` | message | 17 | 中 |
| 8 | `refactor(routers): extract payment-inline routes` | payment_inline | 10 | 高 |
| 9 | `refactor(routers): extract task routes` | task | 18 | 高 |
| 10 | `refactor(routers): extract cs routes + remove main_router include_router calls` | cs | 30 | 最高 |
| 11 | `refactor(admin): merge inline admin/task-expert routes into admin_task_expert_routes` | admin_task_expert | 13 | 中 |

排序原则：**低风险低体量的域先做**，建立流程与信心；核心业务（payment、task、cs）最后做。每个 commit 独立可 revert，互不依赖。

### 每个 commit 的 gate（强制，本地）

1. `python backend/scripts/dump_routes.py` → diff baseline：集合一致（除 commit 4 后允许 10 条 debug 缺席）
2. `pytest backend/tests/test_routers_split_smoke.py`：全绿
3. `python -c "from app.main import app"`：成功
4. `pytest backend/tests/test_stripe_webhook_handlers_team.py backend/tests/test_team_dispute_reversal.py`：全绿（守护外部 importer）
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
- 双挂载本身就是契约保险（漏挂某前缀 → smoke test 立刻 404）

### 7.2 全局 abort

做到一半判断需重来：把已 commit 的批量 revert 回去（`git revert <oldest>..HEAD` + push 到 main）。如果 revert 顺序有依赖问题（unlikely，因 commit 是独立的），手动把 routers.py 的内容从 git history 取回也能行。

### 7.3 运行时隐形保险

双挂载 × smoke test 双前缀测试：任何"一个新 router 漏注册一个前缀"的 bug 会被 smoke 捕获为 404，而不是静默路由消失。

### 7.4 已知不回滚边界

- 10 条 debug 路由**永久删除**，不回滚
- `routers.py` 文件本身**不删**，仅清空 `router = APIRouter()`；19 个 helper 保留

## 8. 成功标准

所有条件同时满足方视为完成：

1. `backend/app/routers.py` 行数从 15,232 下降到 ~3,000 以下（仅剩 helper + import + 模块常量 + 重导出 shim）
2. `backend/app/routes/` 下 10 个新 `*_routes.py` 文件创建完毕、各自自洽
3. `backend/app/admin_task_expert_routes.py` 扩容以吸纳 13 条 admin/task-expert 路由
4. `dump_routes.py` 输出 diff = 10 条 debug 删除（且无其它差异）
5. `test_routers_split_smoke.py` 全绿
6. 外部 importer（async_routers、expert_consultation_routes、2 个测试）零改动下仍能成功 import 并测试通过
7. Flutter dev build 对 linktest 后端：登录、看 profile、收消息、查 banner——冒烟正常
8. 11 个 commit 全部带 `refactor(routers):` 或 `refactor(admin):` 前缀，commit message 清晰
9. `.github/workflows/routes-snapshot.yml` 已合入 main 且至少一次绿色运行

## 9. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 迁移过程中 helper 和路由被意外分割（路由搬走、helper 留下、但 helper 是该路由独有） | 搬走的文件 import 找不到 | 每个 commit 内跑 `python -c "from app.main import app"`；helper 在 `routers.py` 留到 commit 10 统一清理 |
| 某个路由的 path 在迁移中拼写错（少字符、多斜杠） | 客户端 404 | `dump_routes.py` 集合对比捕获 100% |
| 某个新 router 只挂了 `/api` 没挂 `/api/users` | 一个前缀下客户端全 404 | smoke test 每条双前缀测，立即发现 |
| 直推 main 期间，某 commit 上线后才暴露问题 | 短窗口线上故障 | 每 commit 推完不立刻开下一个，等 linktest 烟测过；故障 → `git revert` + push，Railway 自动回退 |
| 迁移期间有新路由被加进 `routers.py`（其它工作流） | 可能漏迁 | 本次重构期间避免给 `routers.py` 加新路由；如必须加，迁移 commit 会显式带上 |
| Stripe webhook（commit 8）迁移中 webhook secret 绑定错 | 生产 webhook 失败 | 不改 webhook URL；不改签名验证；仅移动函数文件位置。smoke 覆盖路由注册，linktest 烟测 + Railway 日志确认首个 webhook 正常响应 |
| `admin_task_expert_routes.py` 合并（commit 11）与现有 admin panel 14 调用不匹配 | admin 功能坏 | 合并时保持 URL 不变；admin/src/api.ts 不改；smoke 加一条 admin/task-experts 路由存在性断言 |

## 10. 范围外 / 后续

以下不在本次范围，记录以免遗忘：

- **前缀审计 follow-up**：拆分全部完成后，用 `/schedule` 创建一个 ~2 周后的 agent，扫 Flutter (`link2ur/lib/`) + Web (`frontend/`) 实际调用的前缀（`/api/users/...` vs `/api/...`），对每条路由确定真正在用的前缀，把不需要的那一侧 `include_router` 调用从 main.py 删掉。该 agent 只开 PR 不直推
- `schemas.py` (4,977 行) 拆分，对照 `schema_modules/__init__.py` 既有计划
- `crud_modules/` 填充（`crud.py` 已不存在，需重建或确认历史已拆完）
- `routers.py` 的 19 个 helper 进一步归位到各 `*_routes.py` 模块——属于第二阶段整洁化
- admin panel `admin/src/api.ts` 中 14 条 `/api/task-experts/*` 调用迁到新 `/api/admin/*` URL——属于 legacy 达人路由迁移 Phase 3，本次不做

## 11. 实施计划

本 spec 经 user approve 后，调用 `superpowers:writing-plans` skill 基于本文档产出逐 commit 的详细实现计划，包含：

- 每个 commit 要移动的精确路由列表（method + path + routers.py 行号范围）
- 每个 commit 要复制的 import 与 helper 引用
- 每个 commit 的 gate 检查清单
- 前置审计 grep 任务（`from app.routers import` 全仓扫描）的具体命令与预期输出

---

**Design sign-off**: 待 user review
