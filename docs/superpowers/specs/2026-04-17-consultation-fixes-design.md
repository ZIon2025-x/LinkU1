# Consultation 功能修复 — Track 1 设计文档

- **日期**: 2026-04-17
- **范围**: Track 1(代码重构 + 小修复,无 DB schema 变更)
- **状态**: Design
- **相关技术债**: `project_consultation_task_id_overwrite.md`(归入 Track 2 重构,不在本 Track 处理)

## 背景

咨询功能(service / task / flea_market 三种类型)已运行一段时间,代码审查发现 10 项问题。按架构决策分两个独立 track:

- **Track 1(本文档)** — 代码层修复,不动 DB schema,1-2 周可完成并上线
- **Track 2(后续独立立项)** — `tasks` 表 task-first 架构重构为 conversation-first;在此之前 `ServiceApplication.task_id` 覆盖问题、占位任务语义污染、`application_id` 映射缓存、`last_activity_at` 索引等问题都是重构的前置或被重构替代,本 Track 不处理

本 Track 处理的 7 项修复:

| 编号 | 修复项 | 优先级 | 范围 |
|---|---|---|---|
| F1 | Celery 分布式锁 TTL 脱钩调度间隔 | P0 | 后端 |
| F2 | stale cleanup 补测试 + 可配置阈值 | P1 | 后端 |
| F3 | 团队权限检查统一 helper | P0 | 后端 |
| F4 | 咨询代码层统一(后端 helper + Flutter 基类) | P1 | 两端 |
| F5 | 通知文案走双语 helper | P1 | 后端 |
| F6 | BLoC 咨询错误码细分 + l10n | P1 | 两端 |
| F7 | ExpertMember 权限 request-scoped 缓存 | P2 | 后端 |

### 明确不在本 Track 的项(已延后到 Track 2)

| 原编号 | 项 | 延后原因 |
|---|---|---|
| #1 | `ServiceApplication.task_id` 覆盖 | conversation-first 重构后不再创建占位 task,问题自然消失 |
| #6 | `task_id` 语义重载 | 同上 |
| #8 | `task_id → application_id` 映射缓存 | 重构后消息不靠 task_id 路由,映射消失 |
| #9 | `last_activity_at` 索引 | 字段位置随 conversation 表方案决定 |

---

## F1 — Celery 分布式锁 TTL

### 问题

`backend/app/celery_tasks.py:1724-1744` 的 `close_stale_consultations_task` 使用 `lock_ttl=3600`,与 `interval_seconds=3600`(`task_scheduler.py:646-651`)相同。任务运行时间若超过 59 分钟,下一次调度会获取到已释放的锁,导致并发执行。

### 方案

新增通用装饰器 `backend/app/celery_lock.py`:

```python
def celery_task_with_lock(task_name: str, interval_seconds: int, max_runtime_seconds: int):
    """
    获取分布式锁,lock_ttl = max_runtime_seconds * 2,
    既能覆盖最长运行时间,又比调度间隔小(调度更密的任务不会叠锁)。
    """
    def decorator(func):
        lock_ttl = max_runtime_seconds * 2
        # ... 实现 SET NX + EX lock_ttl
    return decorator
```

`close_stale_consultations_task` 迁移到装饰器,`max_runtime_seconds=600`(实测 5 分钟封顶,留 1 倍余量) → `lock_ttl=1200`。

### 兼容性

- 装饰器独立引入,不强制其他 Celery 任务迁移
- 旧锁 key 复用,无数据影响

---

## F2 — stale cleanup 可配置阈值 + 测试

### 问题

`scheduled_tasks.py:912-992` 的 14 天阈值硬编码。运行路径正确,但缺测试覆盖,且无法在 staging / prod 分别调整。

### 方案

1. **可配置**:在 `backend/app/config.py` 新增 `CONSULTATION_STALE_DAYS: int = 14`,通过环境变量 `CONSULTATION_STALE_DAYS` 覆盖
2. **测试**:`backend/tests/test_stale_consultation_cleanup.py` 覆盖:
   - 14 天无消息 → task 关闭 + ServiceApplication 变 `cancelled`
   - 有最近消息 → 保留
   - FleaMarket 咨询联动关闭 `FleaMarketPurchaseRequest`
   - task_source 不是 consultation 类 → 不动
3. **不改逻辑** — `conversation_type="task"` 过滤经核实覆盖所有咨询消息,无需扩展

### 兼容性

环境变量缺省 = 14,与现状一致。

---

## F3 — 团队权限检查统一

### 问题

三处不同实现:

| 位置 | 允许的角色 |
|---|---|
| `expert_consultation_routes.py:72-76` | owner + admin |
| `expert_consultation_routes.py:271-276` | 仅 owner |
| `task_chat_routes.py:374` | owner + admin |

没有统一函数,改权限策略需要多处搜索。

### 方案

新建 `backend/app/permissions/expert_permissions.py`:

```python
from typing import Literal, Optional

TeamRole = Literal["owner", "admin", "member"]

async def get_team_role(db, expert_id: str, user_id: int) -> Optional[TeamRole]:
    """返回当前用户在团队中的角色,不是成员返回 None。"""

async def require_team_role(
    db, expert_id: str, user_id: int, minimum: TeamRole
) -> TeamRole:
    """不满足最低角色时抛 HTTPException(403, code='INSUFFICIENT_TEAM_ROLE')。
    minimum='owner' 仅 owner 通过;
    minimum='admin' owner+admin 通过;
    minimum='member' 全部成员通过。
    """
```

所有咨询路由替换为调用这两个函数。

### 兼容性

API 行为不变(403 响应 + 同等限制);错误响应 detail 新增 `code` 字段(见 F6)。

---

## F4 — 咨询代码层统一

### 问题

三种咨询类型(service / task / flea_market)的代码高度相似但分散:

- **后端**:创建占位 task、关闭咨询 task、解析 taker、幂等性检查等逻辑在 `expert_consultation_routes.py` / `task_chat_routes.py` / `flea_market_routes.py` 三处重复
- **Flutter**:`service_consultation_actions.dart` / `task_consultation_actions.dart` / `flea_market_consultation_actions.dart` 三个 ~300 行文件,对话框(议价/报价/反驳/正式申请/批准确认)都重复

### 方案

#### 后端:新包 `backend/app/consultation/`

```
consultation/
├── __init__.py
├── helpers.py        # 公共业务逻辑
└── notifications.py  # 双语通知模板(F5)
```

`helpers.py` 公开函数:

```python
async def create_placeholder_task(
    db, *, consultation_type: str, applicant_id: int,
    taker_id: Optional[int], service_id: Optional[int] = None,
    expert_id: Optional[str] = None, item_id: Optional[str] = None
) -> Task

async def close_consultation_task(
    db, application, *, reason: str
) -> None
# 原 expert_consultation_routes._close_consultation_task 的通用版

async def resolve_taker_from_service(db, service) -> tuple[int, Optional[str]]
# 已存在,提取到公共位置

async def check_consultation_idempotency(
    db, applicant_id: int, subject_id,
    subject_type: Literal["service", "task", "flea_market_item"]
) -> Optional[Application]
# 返回已存在的 consulting/negotiating/price_agreed/pending 申请
```

三个路由文件改为调用这些 helper,删除复制粘贴。

#### Flutter:重构 `ConsultationActions`

现状:`consultation_base.dart` 已有 `ConsultationActions` 抽象基类 + 工厂,但三个子类各自实现了对话框方法(`_showNegotiateDialog` / `_showQuoteDialog` / `_showCounterOfferDialog` / `_showFormalApplyDialog` / `_showApproveConfirmation`),代码几乎一字不差。

重构:

- `consultation_base.dart` 新增非 abstract 方法 `showNegotiateDialog()` / `showQuoteDialog()` 等,放在基类里
- 基类暴露 abstract 方法 `Future<void> onNegotiate(int price)` 等业务回调给子类实现
- 子类只实现 repository 调用,不再复制对话框 UI

### 兼容性

API 端点不变,UI 表现不变,测试策略见下文。

---

## F5 — 通知文案双语化

### 问题

`expert_consultation_routes.py:81-87` 等处硬编码中英文字符串:

```python
content_zh = f"用户「{applicant_name}」对服务「{service_name}」发起了新申请"
content_en = f"「{applicant_name}」submitted a new request for service「{service_name}」"
```

- 英文用了中文全角引号「」,显示不自然
- 散落在路由文件中,难维护
- 后端已有 `utils/bilingual_helper.py` + `translation_manager.py`,170+ 处走此模式,唯独咨询通知没对齐

### 方案

新建 `backend/app/consultation/notifications.py`,集中定义所有咨询通知模板:

```python
def consultation_submitted(*, applicant_name: str, service_name: str) -> dict:
    return {
        "content_zh": f"用户「{applicant_name}」对服务「{service_name}」发起了新咨询",
        "content_en": f'{applicant_name} started a new consultation for "{service_name}"',
    }

# 覆盖:submitted / negotiated / quoted / formally_applied /
#       approved / rejected / closed / stale_auto_closed
```

所有通知创建点改为:

```python
from app.consultation.notifications import consultation_submitted
msg = consultation_submitted(applicant_name=..., service_name=...)
# insert into messages table with content_zh=msg["content_zh"], content_en=msg["content_en"]
```

### 兼容性

通知消息行结构不变(`content_zh` + `content_en` 字段保持),只有文案略有调整(英文去掉全角引号)。

---

## F6 — BLoC 咨询错误码细分

### 问题

- 后端咨询 `HTTPException` 的 detail 是裸字符串,前端无法区分错误种类
- Flutter `TaskExpertBloc` 失败时 `actionMessage = 'consultation_failed'` 一刀切,UI 不知道是"已有咨询"、"服务下架"还是"不能咨询自己"
- `errorMessage` 只能显示原始后端字符串,无法本地化

### 方案

#### 后端:标准化 HTTPException detail

所有咨询相关 HTTPException 改为:

```python
raise HTTPException(
    status_code=400,
    detail={
        "code": "CONSULTATION_ALREADY_EXISTS",
        "message": "您已有进行中的咨询申请",  # 保留原中文,作为 fallback
    },
)
```

错误码清单(12 个):

| Code | HTTP | 场景 |
|---|---|---|
| `CONSULTATION_ALREADY_EXISTS` | 400 | 用户对同一服务/任务已有未结束咨询 |
| `CONSULTATION_NOT_FOUND` | 404 | application_id 不存在 |
| `CONSULTATION_CLOSED` | 400 | 咨询已关闭,不可继续操作 |
| `SERVICE_NOT_FOUND` | 404 | service_id 不存在 |
| `SERVICE_INACTIVE` | 400 | 服务已下架 |
| `EXPERT_TEAM_NOT_FOUND` | 404 | expert_id 不存在 |
| `EXPERT_TEAM_INACTIVE` | 400 | 团队非 active |
| `CANNOT_CONSULT_SELF` | 400 | 对自己的服务/团队咨询 |
| `NOT_SERVICE_OWNER` | 403 | 非个人服务的 owner |
| `NOT_TEAM_MEMBER` | 403 | 非团队成员 |
| `INSUFFICIENT_TEAM_ROLE` | 403 | 成员但角色不够(如 member 试图 approve) |
| `INVALID_STATUS_TRANSITION` | 400 | 状态机非法跳转(如 rejected → approved) |
| `PRICE_OUT_OF_RANGE` | 400 | 议价/报价超出服务定价范围 |

#### Flutter:errorCode 字段

1. `ApiService` 扩展 `detail` 解析(兼容 string 和 object 两种形态):当 detail 是 dict 时抽取 `code` 字段到 `ApiException.errorCode`,否则保留裸字符串到 `errorMessage`。**实施前先读 `api_service.dart` 当前错误处理路径,确认兼容方向。**
2. `TaskExpertException`(及其他咨询异常)新增 `errorCode` 可选字段
3. `TaskExpertState` 新增 `errorCode: String?` 字段(与 `errorMessage` 并存)
4. BLoC 失败时同时填 `errorCode` 和 `errorMessage`
5. UI 优先读 `context.l10n.consultationError<ErrorCode>` ,回退到 `errorMessage`

#### l10n

`app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` 各新增 13 个 key(12 个错误码 + 1 个 `consultationErrorGeneric` fallback):

```json
"consultationErrorAlreadyExists": "You already have an ongoing consultation"
"consultationErrorCannotConsultSelf": "You cannot consult your own service"
...
```

`error_localizer.dart` 扩展 switch,映射 code → l10n key。

### 兼容性

- 旧 client 忽略 `detail.code`,读 `detail.message`(或 `detail` 本身 fallback)仍工作
- 新 client `errorMessage` 字段继续可用,没有 breaking

---

## F7 — ExpertMember 权限 request-scoped 缓存

### 问题

同一个请求内多次查 `ExpertMember`(权限检查 + 业务读 + 通知分发),N+1 风险。

### 方案

`backend/app/permissions/expert_permissions.py` 内部使用 `contextvars.ContextVar` 持有 per-request dict:

```python
_role_cache: ContextVar[Optional[dict[tuple[str, int], TeamRole]]] = ContextVar("_role_cache", default=None)

async def get_team_role(db, expert_id, user_id) -> Optional[TeamRole]:
    cache = _role_cache.get()
    if cache is None:
        cache = {}
        _role_cache.set(cache)
    key = (expert_id, user_id)
    if key in cache:
        return cache[key]
    role = await _query_team_role(db, expert_id, user_id)
    cache[key] = role
    return role
```

FastAPI middleware 在每个请求开始时 reset cache(避免跨请求泄露)。

### 兼容性

- 非咨询路由可选使用,不影响现状
- 缓存只活在单次请求上下文,不走 Redis,避免跨 user/跨 session 污染

---

## 不变的部分(明确)

- API 端点签名 / 请求体 / 响应字段结构
- 三张申请表(`service_applications` / `task_applications` / `flea_market_purchase_requests`)schema
- `tasks` 表 schema
- WebSocket 协议、消息路由、推送通知机制
- Stripe 支付流程
- Flutter 端 model / endpoint 常量 / 路由表
- 现有 BLoC 事件命名

---

## 测试策略

### 后端(pytest)

- `test_consultation_helpers.py` — `create_placeholder_task` / `close_consultation_task` / `check_consultation_idempotency` 各函数单测
- `test_consultation_idempotency.py` — 同一用户对同一服务重复 POST,返回已有 application
- `test_consultation_close_lifecycle.py` — approve 关闭占位任务 + application 状态同步(不测 task_id 覆盖,Track 2 再管)
- `test_stale_consultation_cleanup.py` — 14 天阈值边界、有消息保留、flea market 联动、可配置阈值
- `test_expert_permissions.py` — `require_team_role` 四种 minimum 的矩阵测试
- `test_consultation_error_codes.py` — 12 个错误码的 HTTP 响应格式、中英文 fallback message 存在
- `test_consultation_notifications.py` — 8 个通知模板的 zh/en 文案断言
- `test_celery_lock.py` — `celery_task_with_lock` 并发测试(第二个进程拿不到锁)

### Flutter(bloc_test + widget test)

- `task_expert_bloc_consultation_test.dart` — 三种咨询类型成功/失败路径、errorCode 正确填充到 state
- `consultation_actions_base_test.dart` — widget test 验证三种类型子类调用的对话框行为一致(快照级)
- `error_localizer_test.dart` — 12 个咨询 error code 映射到正确 l10n key

---

## 风险和回滚

| 风险 | 影响 | 缓解 |
|---|---|---|
| 后端 helper 重构引入回归 | 咨询流程全部断 | helper 单测覆盖、API 签名不变使得现有集成测试仍有效;先在 staging 完整跑一遍 |
| Celery 锁调整导致定时任务不执行 | 14 天后才能看到 stale task 堆积 | Staging 灰度 24 小时观察;监控 `close_stale_consultations` 执行次数 |
| HTTPException detail 变成对象,旧 client 崩溃 | Flutter 历史版本报错 | 检查 `ApiService` 已能处理 object/string 两种 detail;如不兼容,改为保持 detail=str 但 header 加 `X-Error-Code` |
| Flutter 对话框基类改动 UX 回归 | 用户看到不一致的对话框 | widget test + 手测覆盖三种类型的每个对话框 |
| 双语通知文案变化 | 老用户看到新文案略觉奇怪 | 改动前后文案 diff review;关键通知(approve/reject)保持原措辞,仅修正英文引号 |

**回滚**:所有改动均为代码级,无 DB migration、无数据回填。单 commit 可 revert,粒度:

1. F1/F2 可独立 revert
2. F3/F7 绑定(F7 依赖 F3 的模块结构)
3. F4 可独立 revert,但后端 helper 删除后三个路由文件恢复为复制粘贴状态
4. F5 可独立 revert
5. F6 后端部分(error_code)可独立 revert;Flutter 部分向后兼容,不 revert 也无害

---

## 上线顺序建议

1. **Week 1 day 1-2** — F1(Celery 锁)+ F3(权限 helper)+ F7(缓存):最底层,给其他修复提供基础
2. **Week 1 day 3-4** — F4(后端 helper 抽取)+ F5(通知双语化):基于 F3,抽取公共逻辑并改进通知
3. **Week 1 day 5** — F2(stale cleanup 测试)+ 后端全量测试
4. **Week 2 day 1-3** — F6 后端(HTTPException 带 code)+ F4 Flutter 重构 + F6 Flutter(errorCode + l10n)
5. **Week 2 day 4-5** — 集成测试、staging 验证、文档更新

每两天一个 PR 节奏,最多 5 个小 PR,不堆大 commit。

---

## 成功标准

- [ ] 7 项修复全部合入,测试全绿
- [ ] `close_stale_consultations_task` 在 staging 连续运行 7 天无并发告警
- [ ] Flutter 咨询错误场景至少 5 个(已有/下架/自己的/权限不够/状态非法)显示正确的本地化文案
- [ ] `expert_consultation_routes.py` + `task_chat_routes.py`(咨询部分)+ `flea_market_routes.py`(咨询部分)三文件合计代码行数减少 20% 以上
- [ ] 新增测试用例 ≥ 25 个
