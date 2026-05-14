# Link2Ur ChatGPT App — MCP Server + OAuth 2.1 + Widgets 设计

**日期**：2026-05-13（v2 修订 2026-05-14）
**作者**：zixiong316 + Claude（brainstorming session）
**状态**：Design v2 — 待 review

> **v2 修订记录** — v1 review 后发现 15 处问题，本版逐项修复。修订摘要见末尾 §12 "Spec v2 修订记录"。

---

## 0. 概述与目标

把 **Link2Ur 作为 ChatGPT App 上架到 OpenAI ChatGPT 应用市场**，让任何 ChatGPT 用户能在对话中：
- 查看自己在 link2ur 的任务
- 用自然语言描述需求，获得达人/服务推荐
- 用自然语言生成任务草稿，在 widget 里编辑确认后一键发布

技术栈：**MCP server (Streamable HTTP) + OAuth 2.1 (PKCE-only public client) + 3 个 React widget (`@modelcontextprotocol/ext-apps`)**。

**不在本设计范围内**：
- ChatGPT MCP Connector（手动添加）—— 复用同一套 MCP server 自动可用，无需单独设计
- Custom GPT + Actions（旧路径，不走 MCP）
- 自家 backend 内部 OpenAI Agent —— 之前讨论过的"两阶段"路线，本设计完成后再单独评估
- 写入工具（除 `publish_task` 之外）—— 第一版保守

**前置依赖**：
- 现有 backend `ai_tool_registry`（35+ 注册工具）+ `ToolExecutor`（绑 DB session + user 上下文）
- 现有 Cloudflare DNS（link2ur.com 已在 Cloudflare 管理）
- 现有 Railway 部署流水线（linktest + prod）

---

## 1. 整体架构

### 1.1 模块拆分

```
backend/app/
├── mcp/                          # 新增 MCP 子系统
│   ├── server.py                 # FastMCP 实例 + 启动入口 + lowlevel hooks 绑定
│   ├── lowlevel_bridge.py        # 用 _mcp_server.list_tools() + request_handlers 接管 list/call，绕过 FastMCP 推断
│   ├── tool_descriptions.py      # ChatGPT 专用 tool description override
│   ├── widget_bridge.py          # tool → widget _meta 绑定
│   ├── widget_registry.py        # widget HTML 缓存 + resource 注册
│   ├── token_verifier.py         # 自定义 TokenVerifier 子类（OAuth JWT → AccessToken）
│   ├── rate_limit.py             # 独立于 backend slowapi 的 user 级限流
│   └── audit.py                  # publish_task 等敏感操作审计
├── oauth/                        # 新增 OAuth 2.1 server
│   ├── routes.py                 # /oauth/* + /.well-known/*
│   ├── consent.py                # Jinja2 同意页渲染
│   ├── tokens.py                 # access/refresh token 签发与吊销
│   └── models.py                 # OAuth 4 张新表的 SQLAlchemy 模型
├── crud/
│   └── task_publish.py           # 新增：抽自 async_routers.create_task_async 的内部共享 helper
└── main.py                       # mount /mcp、/oauth、/.well-known/*

(monorepo 同级新目录)
LinkU/chatgpt-widgets/            # 新增 React widget 项目
├── package.json                  # @modelcontextprotocol/ext-apps + @openai/apps-sdk-ui (UI 组件)
├── vite.config.ts
├── src/
│   ├── widgets/
│   │   ├── task-list/
│   │   ├── helper-list/
│   │   └── task-confirm-form/
│   ├── sdk/                      # useApp() 封装 + 类型导出
│   ├── shared/                   # 共享组件（Avatar/Tag/Button）
│   └── types/                    # TS 类型，与 backend tool response 对齐
└── scripts/deploy.sh             # Cloudflare Pages 部署脚本
```

### 1.2 关键架构原则

1. **MCP server mount 在同一个 FastAPI 进程**：路径 `/mcp`，复用现有 DB session 工厂、Redis 客户端、`ToolExecutor`。
2. **`ai_tool_registry` 是单一真理源**：MCP 工具不重新定义，桥接代码用 lowlevel API 绕过 FastMCP 推断，直接复用 ai_tool_registry 里手写的 JSON Schema。
3. **OAuth server 独立模块、独立数据表**：不污染现有 user/admin/service 三套 auth，单独 4 张表。
4. **Widget 仓库独立**：`chatgpt-widgets/` 与 `backend/` 平级，独立 build pipeline + 独立 CDN 部署。
5. **Task creation 走共享 helper**：`publish_task` 工具不能直接调 `create_task_async` 路由（依赖 CSRF/HTTP），而是调 `crud/task_publish.py` 抽出的内部函数 —— 保证学生认证、内容过滤等业务规则不被绕过。

### 1.3 部署形态

- **Backend**：单一 Railway service（同 link2ur backend），mount `/mcp` 和 `/oauth/*`
- **Widget CDN**：Cloudflare Pages，子域 `chatgpt-widgets.link2ur.com`（prod）/ `chatgpt-widgets-staging.link2ur.com`（linktest）
- **Discovery 端点**：
  - `https://api.link2ur.com/.well-known/oauth-authorization-server`
  - `https://api.link2ur.com/.well-known/oauth-protected-resource` → resource: `https://api.link2ur.com/mcp`

---

## 2. OAuth 2.1 Server

### 2.1 库选择

**`authlib`** (`pip install authlib`)。支持 OAuth 2.1 / PKCE (S256) / DCR (RFC 7591) / refresh rotation / discovery metadata，FastAPI 集成成熟。

### 2.2 端点

| Method | 路径 | RFC | 作用 |
|---|---|---|---|
| GET | `/.well-known/oauth-authorization-server` | RFC 8414 | AS metadata |
| GET | `/.well-known/oauth-protected-resource` | RFC 9728 | PRM，告诉 MCP client 资源服务器 `https://api.link2ur.com/mcp` 的 AS 在哪 |
| POST | `/oauth/register` | RFC 7591 | ChatGPT DCR 注册（public client） |
| GET | `/oauth/authorize` | RFC 6749 | 渲染同意页 |
| POST | `/oauth/authorize` | — | 处理用户授权决定 |
| POST | `/oauth/token` | RFC 6749 | code→token (PKCE) / refresh→token |
| POST | `/oauth/revoke` | RFC 7009 | 撤销 token |
| POST | `/oauth/introspect` | RFC 7662 | （可选）内部 token 验证 |

### 2.3 数据表

**ChatGPT 是 OAuth public client (PKCE-only, no client_secret)**。`token_endpoint_auth_method` 取 `none` 或 `private_key_jwt`（OpenAI 官方支持的两种）。`client_secret_hash` 字段保留但仅为未来其他 confidential client 服务，对 ChatGPT 始终为 NULL。

```
oauth_clients
  client_id                  TEXT PK
  client_secret_hash         TEXT NULL    -- 仅 confidential client 使用，ChatGPT 始终 NULL
  token_endpoint_auth_method TEXT         -- "none" | "private_key_jwt" | "client_secret_basic"
  jwks_uri                   TEXT NULL    -- private_key_jwt 时存放
  client_name                TEXT         -- DCR 注册的 client_name（"ChatGPT (gpt-x)"）
  redirect_uris              JSONB
  grant_types                JSONB        -- ["authorization_code", "refresh_token"]
  scope                      TEXT         -- 允许的 scope 空格分隔
  created_at                 TIMESTAMP
  is_active                  BOOLEAN

oauth_authorization_codes
  code                  TEXT PK            -- 32 字节 urlsafe random
  client_id             TEXT FK
  user_id               INT FK → users.id
  redirect_uri          TEXT
  scope                 TEXT
  code_challenge        TEXT               -- PKCE S256（强制）
  code_challenge_method TEXT               -- "S256"
  expires_at            TIMESTAMP          -- created + 10min
  consumed              BOOLEAN

oauth_access_tokens
  jti                 TEXT PK              -- JWT id，用于 revoke 黑名单
  client_id           TEXT FK
  user_id             INT FK
  scope               TEXT
  expires_at          TIMESTAMP
  revoked             BOOLEAN

oauth_refresh_tokens
  token_hash          TEXT PK              -- bcrypt hash，原 token 不存
  client_id           TEXT FK
  user_id             INT FK
  scope               TEXT
  rotation_chain_id   TEXT                 -- 检测 refresh token 重放
  expires_at          TIMESTAMP
  revoked             BOOLEAN
  replaced_by_hash    TEXT                 -- rotation 链

-- 索引
CREATE INDEX idx_oauth_access_tokens_user ON oauth_access_tokens(user_id, expires_at);
CREATE INDEX idx_oauth_refresh_tokens_user ON oauth_refresh_tokens(user_id, expires_at);
CREATE INDEX idx_oauth_codes_user ON oauth_authorization_codes(user_id, expires_at);
```

Migration 文件：**`backend/migrations/231_oauth_tables.sql`**（最新 migration 是 230）。

### 2.4 Token 格式与生命周期

- **Access token**：JWT 自包含，HS256，独立的 `OAUTH_JWT_SECRET` 环境变量（**不复用** `JWT_SECRET_KEY`）。payload 含 `sub=user_id`、`client_id`、`scope`、`exp`、`jti`、`aud="https://api.link2ur.com/mcp"`。MCP `TokenVerifier` 验 token 时只查 `jti` 黑名单（`oauth_access_tokens.revoked=true`）。
- **Refresh token**：Opaque random (32 字节 urlsafe)，DB lookup（rotation 需要查链）。
- **生命周期**：code 10min / access 1h / refresh 30 days，refresh 每次使用都 rotate（旧的立即 revoked，新的 `replaced_by_hash` 指向旧）。如检测到 revoked refresh token 被二次使用 → 整条 chain 全部 revoke（防盗用）。

### 2.5 Scopes（第一版）

| Scope | 用途 |
|---|---|
| `mcp:read` | 调任何只读 MCP 工具（fallback for tools without specific scope） |
| `profile:read` | 读 user profile（get_my_profile, get_my_notifications_summary） |
| `tasks:read` | 读任务（query_my_tasks, search_tasks, get_task_detail, recommend_tasks, get_next_action, prepare_task_draft） |
| `tasks:write` | **`publish_task` 必需**（仅此一个写入工具） |
| `helpers:read` | recommend_helpers_by_intent, search_services, get_expert_detail, list_activities |

同意页必须显式列出每个 scope 的中文化解释。`tasks:write` 必须明确说"允许 ChatGPT 代你发布任务，每次发布前你都会在 ChatGPT 里看到确认页面"。

### 2.6 授权 flow（PKCE public client）

```
1. 用户在 ChatGPT 里点 "Connect Link2Ur"
2. ChatGPT 拉 /.well-known/oauth-authorization-server
3. ChatGPT POST /oauth/register
     - 申请 token_endpoint_auth_method=none（public client，无 secret）
     - 返回 client_id（无 secret）
4. ChatGPT 浏览器 302 到 /oauth/authorize?
     response_type=code
     &client_id=<chatgpt_client_id>
     &redirect_uri=https://chatgpt.com/connector_platform_oauth_redirect
     &scope=mcp:read+tasks:read+tasks:write+helpers:read+profile:read
     &state=<csrf>
     &code_challenge=<pkce_s256>
     &code_challenge_method=S256
5. /oauth/authorize 检查 link2ur web 会话:
     - 未登录 → 302 到 https://link2ur.com/login?return_to=<encoded /oauth/authorize URL>
     - 已登录 → 渲染 Jinja2 同意页 HTML
6. 用户点同意 → POST /oauth/authorize:
     - 写 oauth_authorization_codes（含 code_challenge）
     - 302 回 ChatGPT redirect_uri 带 code + state
7. ChatGPT POST /oauth/token (code + code_verifier，**无 client_secret**):
     - 验证 SHA256(code_verifier) == code_challenge
     - 验证 code 未过期、未消费
     - 签发 JWT access_token + 生成 opaque refresh_token
8. 后续 ChatGPT 调 /mcp 时 header 带 Authorization: Bearer <jwt>
9. MCP server TokenVerifier verify → user_id 注入 auth_context_var contextvar
```

### 2.7 同意页 UI

第一版用 **backend Jinja2 渲染 HTML**（不上 React）。原因：React frontend 独立部署在 Vercel，跨域复杂；同意页是一次性流程不需要交互。设计参考 Notion/Linear OAuth 风格：app logo + 申请权限列表（中文化）+ 同意/拒绝按钮 + 隐私政策链接。

后续可升级为 React 页面（路由 `/connect/authorize`），第一版不做。

### 2.8 用户撤销 UI

Flutter app 新增页面 **"已连接的应用"**（路由 `/settings/connected-apps`）。后端加：
- `GET /api/me/oauth/clients` — 列当前用户授权过的所有 client
- `DELETE /api/me/oauth/clients/{client_id}` — 撤销该 client 所有 token

这是 ChatGPT Apps 隐私合规硬性要求。

### 2.9 移动端用户体验注意

手机端 ChatGPT 用户点 connect → 系统浏览器打开 link2ur.com/login → 需要他们在浏览器里登 link2ur web（不是 Flutter app）。这个体验有点割裂但 OAuth 标准要求只能跳浏览器。第一版接受此 UX，后续可考虑 universal link 唤起 Flutter app。

**前端 return_to 支持改造**：现有 `frontend/src/pages/Login.tsx` 需要 verify 是否支持 `?return_to=<encoded URL>` 参数。如不支持，需要在 web frontend 加：登录成功后从 query 取 return_to，安全校验 URL host 在白名单（仅 `api.link2ur.com/oauth/authorize`）后 302 跳转。**这是阻塞 M2 完成的前端改造点**，工期已计入 M2。

---

## 3. MCP Server + 工具桥接

### 3.1 库选择

**`mcp` Python SDK 官方版**（`pip install "mcp[cli]"`），同时使用：
- `FastMCP`（顶层 server 实例 + auth middleware + streamable_http_app 工厂）
- **Lowlevel escape hatch**：`mcp._mcp_server.list_tools()` 装饰器 + `request_handlers[CallToolRequest]` 直接覆盖

这种 hybrid 模式是 OpenAI 官方 [`authenticated_server_python`](https://github.com/openai/openai-apps-sdk-examples/blob/main/authenticated_server_python/main.py) 示例的范式，绕过 FastMCP 从 Python 函数签名推断 schema 的限制，让我们能复用 `ai_tool_registry` 已有的 35 个手写 JSON Schema。

### 3.2 工具白名单（14 个）

| 工具 | 类型 | scope | Widget |
|---|---|---|---|
| `query_my_tasks` | read | tasks:read | `task-list` |
| `get_task_detail` | read | tasks:read | — (text) |
| `search_tasks` | read | tasks:read | — |
| `recommend_tasks` | read | tasks:read | — |
| `get_my_profile` | read | profile:read | — |
| `recommend_helpers_by_intent` | read | helpers:read | `helper-list` |
| `search_services` | read | helpers:read | `helper-list` |
| `get_expert_detail` | read | helpers:read | — (text) |
| `list_activities` | read | helpers:read | — |
| `get_platform_faq` | read | mcp:read | — |
| `get_my_notifications_summary` | read | profile:read | — |
| `get_next_action` | read | tasks:read | — |
| `prepare_task_draft` | read | tasks:read | `task-confirm-form` |
| `publish_task` | **write** | **tasks:write** | （由 task-confirm-form 调用） |

其余现有 21+ 个工具第一版**不暴露**，理由：内部场景重 + 对 ChatGPT 用户不直观 + 候选越多模型选错率越高。

### 3.3 Tool description 重写

ChatGPT 模型选工具靠 description，**单独维护一份 ChatGPT 用的 description override**（`app/mcp/tool_descriptions.py`），不改 `ai_tool_registry` 原始定义。原则：
- 英文为主（OpenAI 模型对英文 description 更敏感）
- 用户视角语言（"the user asks ..." > "查询当前用户的 ..."）
- 触发关键词明确（"use this when the user wants to ..."）

### 3.4 工具桥接（lowlevel hybrid 模式）

```python
# app/mcp/lowlevel_bridge.py
import mcp.types as types
from mcp.server.fastmcp import FastMCP
from mcp.server.auth.middleware.auth_context import get_access_token
from app.database import AsyncSessionLocal
from app.redis_cache import get_redis_client
from app.services.ai_tool_registry import tool_registry
from app.services.ai_tools import ToolExecutor
from app.mcp.tool_descriptions import CHATGPT_TOOL_DESCRIPTIONS
from app.mcp.widget_bridge import WIDGET_BINDINGS
from app.mcp.rate_limit import check_mcp_quota
from app.mcp.audit import audit_publish
from app import models

EXPOSED_TOOLS = {
    "query_my_tasks", "get_task_detail", "search_tasks", "recommend_tasks",
    "get_my_profile", "recommend_helpers_by_intent", "search_services",
    "get_expert_detail", "list_activities", "get_platform_faq",
    "get_my_notifications_summary", "get_next_action",
    "prepare_task_draft", "publish_task",
}

def register_lowlevel_handlers(mcp: FastMCP):
    @mcp._mcp_server.list_tools()
    async def _list_tools() -> list[types.Tool]:
        tools = []
        for name, td in tool_registry._tools.items():
            if name not in EXPOSED_TOOLS:
                continue
            widget_uri = WIDGET_BINDINGS.get(name)
            meta = {"openai/outputTemplate": widget_uri} if widget_uri else None
            tools.append(types.Tool(
                name=name,
                description=CHATGPT_TOOL_DESCRIPTIONS.get(name, td.description),
                inputSchema=td.input_schema,   # ← 直接用 ai_tool_registry 手写 schema
                _meta=meta,
            ))
        return tools

    async def _call_tool(req: types.CallToolRequest) -> types.ServerResult:
        name = req.params.name
        args = req.params.arguments or {}

        # 1. Auth check
        from app.mcp.token_verifier import resolve_user_id
        access_token = get_access_token()
        if not access_token:
            return _oauth_error("missing_token")
        user_id = resolve_user_id(access_token)

        # 2. Scope check
        required_scope = TOOL_SCOPE[name]
        if required_scope not in access_token.scopes:
            return _oauth_error("insufficient_scope", needed=required_scope)

        # 3. Rate limit
        try:
            await check_mcp_quota(user_id, name)
        except MCPRateLimitError as e:
            return _rate_limited_error(e.retry_after)

        # 4. Execute tool
        async with AsyncSessionLocal() as db:
            user = await db.get(models.User, user_id)
            if not user:
                return _error("user_not_found")
            executor = ToolExecutor(db, user)
            try:
                result = await executor.execute(name, args, request_lang=user.language_preference)
            except Exception as e:
                return _error("tool_execution_failed", detail=str(e))

            if name == "publish_task":
                await audit_publish(db, user_id, access_token.client_id, args, result)

            return _to_mcp_call_result(name, result)

    mcp._mcp_server.request_handlers[types.CallToolRequest] = _call_tool


def _to_mcp_call_result(tool_name: str, raw: dict) -> types.ServerResult:
    widget_uri = WIDGET_BINDINGS.get(tool_name)
    meta = {"openai/outputTemplate": widget_uri} if widget_uri else {}
    return types.ServerResult(
        types.CallToolResult(
            content=[types.TextContent(type="text", text=_slim_text_for_chatgpt(raw))],
            structuredContent=raw,
            _meta=meta,
        )
    )
```

**关键变更点 vs v1**：
- ❌ v1 错的 `@mcp.tool(input_schema=...)` 装饰器 → ✅ v2 lowlevel `list_tools()` + `request_handlers[CallToolRequest]`，直接传 `types.Tool(inputSchema=dict)`
- ❌ v1 错的 `async with get_async_session()` → ✅ `async with AsyncSessionLocal()`（导入自 `app.database`）
- ❌ v1 错的 `ctx.session.user_id` → ✅ `mcp.server.auth.middleware.auth_context.get_access_token()` (contextvar)

### 3.5 MCP 响应格式 + Widget 绑定

```python
WIDGET_BINDINGS = {
    "query_my_tasks":              "ui://widget/task-list",
    "recommend_helpers_by_intent": "ui://widget/helper-list",
    "search_services":             "ui://widget/helper-list",
    "prepare_task_draft":          "ui://widget/task-confirm-form",
}
```

- `content[].text`：给 ChatGPT 模型阅读的紧凑文本/JSON 摘要
- `structuredContent`：完整结构化数据，传给 widget iframe（widget 通过 `useApp().toolOutput` 或 `window.openai.toolOutput` 取）
- `_meta.openai/outputTemplate`：指明 widget URI，ChatGPT 据此挑 widget 渲染

### 3.6 User 上下文注入（TokenVerifier + contextvar）

```python
# app/mcp/token_verifier.py
from mcp.server.auth.provider import TokenVerifier, AccessToken
import jwt
from app.config import Config

class L2UTokenVerifier(TokenVerifier):
    async def verify_token(self, token: str) -> AccessToken | None:
        try:
            payload = jwt.decode(
                token,
                Config.OAUTH_JWT_SECRET,
                algorithms=["HS256"],
                audience="https://api.link2ur.com/mcp",
            )
        except jwt.PyJWTError:
            return None

        # 检查 jti 黑名单
        if await _is_jti_revoked(payload["jti"]):
            return None

        return AccessToken(
            token=token,
            client_id=payload["client_id"],
            scopes=payload["scope"].split(),
            expires_at=payload["exp"],
            resource=str(payload["sub"]),   # ← user_id 载体，见下方注释
        )

def resolve_user_id(at: AccessToken) -> int:
    """
    从 AccessToken 解出 link2ur user_id。

    实现说明（写 plan 时 verify SDK 真实兼容性）：
    SDK 的 `AccessToken` pydantic 模型没有干净的"自定义字段"槽位。
    第一版用 `resource` 字段载 user_id（语义上略 hack 但兼容性最好）。
    如果 SDK 后续版本对 `resource` 做严格校验（必须是 URL），改用：
      - 方案 B: 自定义 `class L2UAccessToken(AccessToken): user_id: int`
      - 方案 C: 把 user_id 编进 JWT `sub` claim，handler 里每次重新 decode 一次 token
    实施时 prototype 验证。
    """
    return int(at.resource)
```

```python
# app/mcp/server.py
from mcp.server.fastmcp import FastMCP
from mcp.server.auth.settings import AuthSettings
from app.mcp.token_verifier import L2UTokenVerifier
from app.mcp.lowlevel_bridge import register_lowlevel_handlers
from app.mcp.widget_registry import register_widgets

def build_mcp_app():
    mcp = FastMCP(
        name="Link2Ur",
        stateless_http=True,
        token_verifier=L2UTokenVerifier(),
        auth=AuthSettings(
            issuer_url="https://api.link2ur.com",
            required_scopes=[],  # tool 级 scope 在 lowlevel handler 里检查
            resource_server_url="https://api.link2ur.com/mcp",
        ),
    )
    register_lowlevel_handlers(mcp)
    register_widgets(mcp)
    return mcp.streamable_http_app()  # ASGI app，mount 到 FastAPI
```

```python
# app/main.py
from app.mcp.server import build_mcp_app
app.mount("/mcp", build_mcp_app())
```

**关键**：FastMCP 内部的 `RequireAuthMiddleware` 在每个 MCP 请求前自动跑 `TokenVerifier.verify_token`，把 `AccessToken` 塞进 `auth_context_var` contextvar。tool handler 用 `get_access_token()` 拿到，零样板代码。

### 3.7 `publish_task` 工具的安全设计

```python
# 注册到 ai_tool_registry（沿用现有装饰器风格，handler 签名一致）
@tool_registry.register(
    name="publish_task",
    description=(
        "Publish a previously prepared task draft. "
        "INTERNAL: only callable from the task-confirm-form widget "
        "after the user clicks 'Publish'. Do NOT call this directly "
        "from the conversation flow — call prepare_task_draft first."
    ),
    input_schema={
        "type": "object",
        "properties": {
            "draft_id": {
                "type": "string",
                "description": "ID returned by prepare_task_draft (Redis TTL 5min, user-scoped)",
            },
            "overrides": {
                "type": "object",
                "description": (
                    "Partial diff of fields the user edited in the widget. "
                    "Shallow-merged onto the original draft stored in Redis. "
                    "Allowed keys: title, description, task_type, reward, currency, "
                    "pricing_type, task_mode, required_skills, location, deadline."
                ),
            },
        },
        "required": ["draft_id"],
    },
    categories=[ToolCategory.TASK],
)
async def _publish_task(executor: ToolExecutor, input: dict) -> dict:
    import json
    from app.redis_cache import get_redis_client
    from app.crud.task_publish import create_task_for_user

    draft_id = input["draft_id"]
    redis = get_redis_client()
    raw = redis.get(f"task_draft:{executor.user.id}:{draft_id}")
    if not raw:
        return {"error": "draft_expired_or_not_found"}

    base_draft = json.loads(raw)
    overrides = input.get("overrides") or {}
    # 只允许 whitelist 字段覆盖
    ALLOWED = {"title", "description", "task_type", "reward", "currency",
               "pricing_type", "task_mode", "required_skills", "location", "deadline"}
    filtered_overrides = {k: v for k, v in overrides.items() if k in ALLOWED}
    final = {**base_draft, **filtered_overrides}

    # 调内部共享 helper（包含学生认证检查 + 内容过滤）
    task, errors = await create_task_for_user(executor.db, executor.user, final)
    if errors:
        return {"error": "task_creation_failed", "details": errors}

    redis.delete(f"task_draft:{executor.user.id}:{draft_id}")
    return {
        "task_id": task.id,
        "url": f"https://link2ur.com/tasks/{task.id}",
        "title": task.title,
        "status": "published",
    }
```

**关键变更点 vs v1**：
- ❌ v1 编的 `_create_task_internal` → ✅ v2 真实的 `app.crud.task_publish.create_task_for_user`
- ❌ v1 直接 `await redis_client.get(...)` → ✅ `get_redis_client()` 工厂（来自 `app.redis_cache`）
- ✅ 加 overrides 字段白名单过滤（防 widget 端注入额外字段）

### 3.7.1 重构 task creation（前置工作，M3 内）

**问题**：现有 `async_routers.py:692 create_task_async` 是 FastAPI 路由，业务逻辑（学生认证、内容过滤、价格阈值、user_level 判定）和 HTTP/CSRF 耦合。`publish_task` 工具不能调路由，否则要伪造 CSRF token 和 user 会话。

**解决**：抽出共享 helper `app/crud/task_publish.py`：

```python
# app/crud/task_publish.py
from typing import TypedDict
from app.models import User, Task
from app.async_crud import AsyncTaskCRUD
from app.content_filter import check_content
from app.crud.student_verification import has_valid_student_verification

class TaskDraft(TypedDict, total=False):
    title: str
    description: str
    task_type: str
    reward: float | None
    currency: str
    pricing_type: str
    task_mode: str
    required_skills: list[str] | None
    location: str
    deadline: str | None

async def create_task_for_user(
    db: AsyncSession,
    user: User,
    draft: TaskDraft,
) -> tuple[Task | None, list[str]]:
    """
    Shared helper: 复用同一份学生认证 + 内容过滤 + 价格阈值 + level 判定逻辑。
    被 async_routers.create_task_async (route) 和 mcp publish_task (tool) 共同调用。
    """
    errors = []
    # 1. 学生认证检查（Campus Life 类型）
    if draft.get("task_type") == "Campus Life":
        if not await has_valid_student_verification(db, user.id):
            errors.append("student_verification_required")
            return None, errors
    # 2. 内容过滤
    title_result = await check_content(db, draft["title"], "task", user.id)
    desc_result = await check_content(db, draft["description"], "task", user.id)
    if "block" in (title_result.action, desc_result.action):
        errors.append("content_blocked")
        return None, errors
    # 3. 转 TaskCreate schema + 调 CRUD
    task_create = schemas.TaskCreate(**draft)
    task = await AsyncTaskCRUD.create_task(db, task_create, str(user.id))
    return task, errors
```

**然后** `async_routers.create_task_async` 改为简单包装：

```python
@async_router.post("/tasks", response_model=schemas.TaskOut)
@rate_limit("create_task")
async def create_task_async(task: schemas.TaskCreate, current_user, db):
    task_obj, errors = await create_task_for_user(db, current_user, task.model_dump())
    if errors:
        raise HTTPException(status_code=400, detail=errors)
    return task_obj
```

这个重构是 `publish_task` 的硬前置。**计入 M3 工期 + 1 天**。

### 3.7.2 `prepare_task_draft` 向后兼容

**问题**：v1 spec 说"原工具保留行为不变，新增 draft_id 字段"，但加字段就不是"不变"。现有 AI Chat 前端可能基于 `draft.action == "task_draft"` 解析，不读 `draft_id`，所以加字段不会破坏现有解析。**但**：保险起见做兼容策略：

- `prepare_task_draft` 内部增加 Redis 暂存逻辑：`SETEX task_draft:{user_id}:{draft_id} 300 <json>`
- 返回值在原结构基础上**追加** `draft_id` 字段（不改原有字段）
- 现有 AI Chat 前端可以忽略 `draft_id`，行为完全一致
- MCP / widget 路径强制使用 `draft_id`

### 3.8 错误处理

- ToolExecutor 业务异常 → `CallToolResult(isError=True, content=[TextContent(...)])`
- OAuth token 失效 → SDK `RequireAuthMiddleware` 自动返回 HTTP 401 + `WWW-Authenticate: Bearer realm="link2ur"`，触发 ChatGPT refresh flow
- 限流 → HTTP 429 + `Retry-After: <s>` (自定义 Starlette middleware 在 mount 点处理)
- `publish_task` draft 过期 → `CallToolResult(isError=True, content=[TextContent("Draft expired, please prepare a new one")])`

---

## 4. Widget 选型与部署

### 4.1 3 个 Widget

| URI | 触发工具 | Display Mode | 功能 |
|---|---|---|---|
| `ui://widget/task-list` | `query_my_tasks` | inline | 任务卡片列表，每张可点击 → `app.callServerTool("get_task_detail")` |
| `ui://widget/helper-list` | `recommend_helpers_by_intent`, `search_services` | inline | 达人/服务卡片列表，点 "Contact" → `app.sendMessage("帮我联系 @xxx")` |
| `ui://widget/task-confirm-form` | `prepare_task_draft` | fullscreen | 任务草稿表单（可编辑）+ Publish 按钮 → `app.callServerTool("publish_task", {draft_id, overrides})` |

### 4.2 技术栈

| 项 | 选择 |
|---|---|
| Framework | React 18 + TypeScript |
| Build | Vite + `vite-plugin-singlefile` |
| Styling | Tailwind CSS（preflight 关闭） |
| MCP Apps SDK | **`@modelcontextprotocol/ext-apps`**（提供 `useApp()` hook + `app.callServerTool` / `app.sendMessage` / `app.ontoolresult`） |
| UI 组件库（可选） | **`@openai/apps-sdk-ui`**（Badge / Button / Icon，OpenAI 官方风格） |
| 状态持久化 | `window.openai.widgetState` + `setWidgetState()` 跨调用快照 |
| 主题/locale | `window.openai.theme` / `locale` 直接读 |

**关键变更点 vs v1**：
- ❌ v1 编造 `@openai/apps-sdk` 包 → ✅ v2 使用真实 `@modelcontextprotocol/ext-apps` (MCP 工具调用) + `@openai/apps-sdk-ui` (UI 组件)
- ❌ v1 编造 `useToolOutput / useCallTool / useTheme / useLocale` hooks → ✅ v2 使用真实 `useApp()` hook + `window.openai.*` 属性读取

### 4.3 仓库位置

Monorepo 同级新目录 `LinkU/chatgpt-widgets/`，独立 `package.json` + 独立 vite config + 独立部署流水线。理由：与 backend 改动可一次 commit；不污染 web frontend 依赖；build target 完全不同（singlefile + 沙箱 + 小体积）。

### 4.4 CDN 部署

- **Cloudflare Pages**，子域：
  - prod：`chatgpt-widgets.link2ur.com`
  - linktest：`chatgpt-widgets-staging.link2ur.com`
- 每 widget 一个 HTML URL：`https://.../task-list.html?v=<git-sha>`
- Cache-Control: `public, max-age=3600, immutable`（hash 在 URL 里）
- 部署：push 到 main → GitHub Actions `pnpm build` → `wrangler pages deploy`

### 4.5 MCP Resource 注册

ChatGPT 通过 MCP resource 拿 widget HTML。**MIME 必须是 `text/html;profile=mcp-app`**（OpenAI Apps SDK 规范，常量 `RESOURCE_MIME_TYPE` 来自 `@modelcontextprotocol/ext-apps/server` 包）。

```python
# app/mcp/widget_registry.py
import os
import httpx
import mcp.types as types
from mcp.server.fastmcp import FastMCP

WIDGET_CDN_BASE = os.getenv(
    "CHATGPT_WIDGETS_CDN",
    "https://chatgpt-widgets.link2ur.com",
)
WIDGET_VERSION = os.getenv("CHATGPT_WIDGETS_VERSION", "latest")
WIDGET_MIME = "text/html;profile=mcp-app"

WIDGETS = {
    "ui://widget/task-list":          "task-list",
    "ui://widget/helper-list":        "helper-list",
    "ui://widget/task-confirm-form":  "task-confirm-form",
}

_widget_cache: dict[str, str] = {}   # 每个 gunicorn worker 各一份，无需共享

async def _fetch_widget_html(name: str) -> str:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{WIDGET_CDN_BASE}/{name}.html?v={WIDGET_VERSION}",
            timeout=10,
        )
        resp.raise_for_status()
        return resp.text

def register_widgets(mcp: FastMCP):
    @mcp._mcp_server.list_resources()
    async def _list_resources() -> list[types.Resource]:
        return [
            types.Resource(uri=uri, name=name, mimeType=WIDGET_MIME)
            for uri, name in WIDGETS.items()
        ]

    async def _read_resource(req: types.ReadResourceRequest) -> types.ServerResult:
        uri = str(req.params.uri)
        if uri not in WIDGETS:
            return types.ServerResult(types.ReadResourceResult(contents=[]))
        if uri not in _widget_cache:
            _widget_cache[uri] = await _fetch_widget_html(WIDGETS[uri])
        return types.ServerResult(types.ReadResourceResult(
            contents=[types.TextResourceContents(
                uri=req.params.uri,
                mimeType=WIDGET_MIME,
                text=_widget_cache[uri],
            )]
        ))

    mcp._mcp_server.request_handlers[types.ReadResourceRequest] = _read_resource
```

**版本管理**：
1. CDN 部署新版（hash URL）
2. Railway 改 `CHATGPT_WIDGETS_VERSION` env → 触发重启
3. 重启后 `_widget_cache` 全部 worker 清空，下次拉新版

**Gunicorn 多 worker 注意**：`_widget_cache` 是模块级 dict，每个 worker 进程各持一份。首次访问 widget 时每个 worker 各拉一次 CDN（3-5 个 worker × 几 KB-MB = 可接受）。无需 Redis 共享缓存。

### 4.6 Widget ↔ Tool 通信

**Widget 读 tool response + 调写入工具**（task-confirm-form 完整示例）：

```tsx
// src/widgets/task-confirm-form/index.tsx
import { useApp } from "@modelcontextprotocol/ext-apps/react";
import { useState, useEffect } from "react";

type TaskDraft = { title: string; description: string; reward: number; /* ... */ };
type PrepareDraftOutput = { draft: TaskDraft; draft_id: string };
type PublishOutput = { task_id: number; url: string; title: string; status: string };

function TaskConfirmForm() {
  const { app } = useApp({ appInfo: { name: "Publish Task", version: "1.0.0" } });
  const initial = (window as any).openai.toolOutput as PrepareDraftOutput;
  const [edited, setEdited] = useState<TaskDraft>(initial.draft);
  const [state, setState] = useState<"editing" | "publishing" | "success" | "error">("editing");
  const [published, setPublished] = useState<PublishOutput | null>(null);
  const [errorMsg, setErrorMsg] = useState<string>("");

  const handlePublish = async () => {
    setState("publishing");
    const result = await app.callServerTool({
      name: "publish_task",
      arguments: {
        draft_id: initial.draft_id,
        overrides: diff(initial.draft, edited),
      },
    });
    if (result.isError) {
      setErrorMsg(result.content?.[0]?.text ?? "Unknown error");
      setState("error");
      return;
    }
    const out = result.structuredContent as PublishOutput;
    setPublished(out);
    setState("success");
    await app.sendMessage({
      role: "user",
      content: [{ type: "text", text: `Task published: ${out.url}` }],
    });
  };

  if (state === "success" && published) return <SuccessCard taskUrl={published.url} />;
  if (state === "error") return <ErrorCard message={errorMsg} onRetry={() => setState("editing")} />;
  return (
    <Form value={edited} onChange={setEdited}>
      <Button onClick={handlePublish} disabled={state === "publishing"}>
        {state === "publishing" ? "Publishing..." : "Publish Task"}
      </Button>
    </Form>
  );
}
```

**关键变更点 vs v1**：
- ❌ v1 编造的 `useToolOutput` hook → ✅ v2 真实 `window.openai.toolOutput` 属性
- ❌ v1 `window.openai.callTool(name, args)` 直签名 → ✅ v2 真实 `app.callServerTool({ name, arguments })` 对象签名（命名 arguments，不是 args）
- ❌ v1 `window.openai.sendFollowupMessage(text)` 字符串签名 → ✅ v2 真实 `app.sendMessage({ role, content })` 结构化签名
- ✅ 加错误状态处理（result.isError → 显示 ErrorCard + retry）

### 4.7 类型契约

Backend tool response 的 `structuredContent` 是 widget 唯一数据来源。前后端类型必须严格对齐：
- Backend：`app/mcp/lowlevel_bridge.py` 给每个绑 widget 的 tool 加 TypedDict
- Frontend：`chatgpt-widgets/src/types/` 同步维护 TS interface
- CI 时手动 review 一致性（第一版不自动 schema check）

### 4.8 体积策略

第一版用 **A 策略**：`vite-plugin-singlefile` 全 inline，每 widget HTML ~200-500KB。接受 1-2s 首次渲染延迟换沙箱兼容稳定性。M5 联调时如果首屏超过 1.5s 启动 **B 策略**（拆 CDN 引用，HTML shell ~10KB + 外链 JS），预留 1 天工作量。

---

## 5. 限流、可观测性、审计

### 5.1 限流（独立于 backend slowapi）

| 维度 | 限额 | 备注 |
|---|---|---|
| 每 user / 分钟 | 30 次工具调用 | |
| 每 user / 小时 | 300 次工具调用 | |
| 每 user / 天 / `publish_task` | **5 次** | 高风险写入 |
| 每 user / 小时 / 写入 scope | 20 次 | 留余量 |
| 全局 / 分钟 | 500 次 | 防 OpenAI 端 bug |

实现：Redis pipeline `INCR + EXPIRE`，超限 → `MCPRateLimitError` → 429 + `Retry-After`。模块：`app/mcp/rate_limit.py`。Redis 客户端用 `from app.redis_cache import get_redis_client`。

### 5.2 可观测性

**结构化日志字段**：`event=mcp_tool_call`, `mcp_user_id`, `mcp_client_id`, `mcp_tool`, `mcp_duration_ms`, `mcp_status`, `mcp_scope`。

**Prometheus metrics**：
- `mcp_tool_calls_total{tool, status}` Counter
- `mcp_tool_duration_seconds{tool}` Histogram
- `mcp_active_oauth_clients` Gauge
- `mcp_tasks_published_total` Counter
- `mcp_oauth_token_issued_total{grant_type}` Counter
- `mcp_oauth_auth_failed_total{reason}` Counter

**告警**：
- OAuth 验证失败率 > 5% / 5min → P2
- `publish_task` 错误率 > 10% / 10min → P2
- Widget HTML 拉取失败 → P3
- 单 user 24h 内 `publish_task` 触达 5 次上限 ≥ 3 次 → 风控复核

### 5.3 审计

**新表 `mcp_audit_log`**：

```
mcp_audit_log
  id              SERIAL PK
  user_id         INT FK
  client_id       TEXT
  tool_name       TEXT
  draft_id        TEXT NULL
  task_id         INT NULL
  input_summary   JSONB
    -- For publish_task: {task_type, reward, currency, location, has_deadline, title_len, desc_len}
    -- For errors:       {error_code, http_status, scope}
    -- For OAuth events: {grant_type, scope}
    -- 不存原始 title/description 文本（隐私），只存元数据
  result_status   TEXT           -- "ok" | "error" | "rate_limited"
  created_at      TIMESTAMP

-- 索引
CREATE INDEX idx_mcp_audit_log_user_tool_created
  ON mcp_audit_log(user_id, tool_name, created_at DESC);
CREATE INDEX idx_mcp_audit_log_task ON mcp_audit_log(task_id) WHERE task_id IS NOT NULL;
```

**只记关键事件**（控制表增长）：
- 所有 `publish_task` 调用
- 任何 4xx/5xx 错误
- OAuth grant / revoke

**用户可见**：Flutter app "已连接应用" 页下钻显示 ChatGPT 代理操作历史。审核硬要求。

---

## 6. 审核资产清单

| 类别 | 资产 | 负责 |
|---|---|---|
| 基本信息 | App 名 "Link2Ur" + 副标题（≤80 字） + 长描述（≤500 字） + 分类 + 关键词，中英双版 | 你/产品 |
| 视觉 | Icon 1024×1024 PNG + 3-5 张 widget 截图 | 设计 |
| 演示 | 30-60s demo 视频，必含 OAuth flow + ≥2 widget | 你录 |
| 法务 | 隐私政策 URL（含 ChatGPT 数据章节，改 link2ur.com/privacy） | 你写 |
| 法务 | 服务条款 URL（含 ChatGPT 接入条款） | 你写 |
| 联系 | 支持邮箱 + OpenAI 开发者认证 | 你 |
| 测试 | 给 OpenAI 审核员的 link2ur 测试账号 + 5-10 个预置 demo 任务数据 | 你 |
| 技术 | OAuth 2.1 metadata 自检（`.well-known` 可访问、TLS 有效） | 自动化 |

---

## 7. 环境策略

| 环境 | MCP URL | Widgets CDN | OAuth DCR | 备注 |
|---|---|---|---|---|
| local | http://localhost:8000/mcp | localhost vite dev | seed | 集成测试 |
| linktest | https://linktest.up.railway.app/mcp | chatgpt-widgets-staging.link2ur.com | 开放 | 团队内测 + ChatGPT Developer Mode + 审核员测试账号 |
| prod | https://api.link2ur.com/mcp | chatgpt-widgets.link2ur.com | 开放 + 限流 + 审计 | 审核通过后切流量 |

linktest 没 Celery，但 MCP 不依赖 Celery，链路完整可用。

---

## 8. 里程碑与工期

| M | 内容 | 工期 |
|---|---|---|
| **M1** | Dev Mode MCP — FastMCP + lowlevel `list_tools` + 3 只读工具 + 无 OAuth + linktest 部署，用 MCP Inspector 调通 | 3 天 |
| **M2** | OAuth 2.1 — authlib 接入 + 4 张新表 (migration 231) + Jinja2 同意页 + Flutter "已连接应用" UI + **web frontend Login.tsx 加 return_to 支持** | 5 天 |
| **M3** | 全工具桥接 — 重构 task creation 抽 `crud/task_publish.py` 共享 helper + 12 只读 + `prepare_task_draft` (with draft_id) + `publish_task` + tool desc 重写 + 限流 + 审计 + L2UTokenVerifier | **5 天**（+1 天 vs v1 因 task 重构） |
| **M4** | 3 个 widget — chatgpt-widgets 仓库初始化 (`@modelcontextprotocol/ext-apps` + `@openai/apps-sdk-ui`) + 3 widget 实现 + Cloudflare Pages 部署 + tool 响应绑定 | 5 天 |
| **M5** | 联调 — ChatGPT Developer Mode 接 linktest，跑完整 OAuth + 14 工具 + 3 widget 流程，修 bug | 3 天 |
| **M6** | 审核资产 — icon / 截图 / demo 视频 / 隐私政策章节 / ToS 章节 / 测试账号 | 3 天 |
| **M7** | 提交 OpenAI 审核 | 0.5 天 |
| **M8** | 审核反馈循环（每轮 1-3 周） | 不可控 |
| **M9** | 灰度上架 — 小流量观察 1 周 → 全量 | 1 周 |

**总开发工期 M1-M6 ≈ 24 天**（全职）。M8 不可控，乐观 1 月、悲观 3 月。

**M2-M6 期间策略**：同步上 **ChatGPT MCP Connector beta**（Plus/Pro 用户手动添加 URL），验证产品 PMF 不依赖 OpenAI 审核。

---

## 9. 风险登记

| 风险 | 影响 | 缓解 |
|---|---|---|
| OpenAI 审核反复 | 上线时间延后数月 | M2-M6 并行上 MCP Connector beta，不依赖审核 |
| `publish_task` 被滥用（spam 任务） | 平台内容质量下降 | 5 次/天硬限 + 审计告警 + 用户 1h 内可删 |
| Widget HTML 体积 500KB → 渲染慢 | 用户体验差 | M5 联调实测，超 1.5s 启动 B 方案（拆 CDN）|
| `authlib` 未来弃 PKCE 或 DCR | 维护负担 | 锁版本 + 关注 Apps SDK spec 演进 |
| ChatGPT 模型不调 `prepare_task_draft` 直跳 `publish_task` | 写入逻辑被绕过 | `publish_task` schema 只有 `draft_id`，无 draft_id 直接返回 isError |
| ChatGPT iframe sandbox 禁 cross-origin script | B 方案失效 | 第一版 A 方案 inline 不依赖此能力 |
| 手机端 ChatGPT 用户跳浏览器登 link2ur web 体验割裂 | 转化率低 | 接受第一版，后续考虑 universal link 唤起 Flutter |
| Cloudflare Pages 速率限制（免费层）影响 widget 拉取 | 大流量下 widget 加载失败 | Backend 启动时缓存 widget HTML，按 `CHATGPT_WIDGETS_VERSION` 刷新 |
| `mcp` Python SDK lowlevel API 在新版本里变动（`_mcp_server.list_tools()` 是半私有） | 升级 SDK 时桥接代码可能炸 | 锁 mcp 包版本 + CI 跑 MCP Inspector 烟雾测试 |
| OpenAI 改 widget MIME / SDK 包名 | widget 加载失败 | 在 `app/mcp/widget_registry.py` 抽 `WIDGET_MIME` 常量，单点改 |
| `@modelcontextprotocol/ext-apps` npm 包早期版本 API 不稳定 | widget 代码要跟改 | 锁 package.json 版本 + 每次升级跑完整 widget regression |
| task creation 重构破坏 `async_routers.create_task_async` 现有 web/Flutter 调用 | 现有用户发任务 500 | M3 重构后 backend 集成测试覆盖 create_task 全 path |
| frontend Login.tsx 不支持 return_to | OAuth flow 在 web 端断 | M2 第一周先确认 + 改造 |

---

## 10. 后续可能性（不在第一版范围）

- 加 `prepare_service_draft` + `publish_service`（发布个人服务）
- 加 task application 写入工具（向他人任务申请）
- ChatGPT 内嵌支付（Stripe via ChatGPT Apps payments，等 OpenAI 支持）
- 自家 backend OpenAI Agent（用 OpenAI Agents SDK 重写 `ai_agent.py` 主链路，复用同一套 MCP server）
- 多语言 widget（第一版只 zh + en，后续 zh_Hant 等）
- Widget 离线缓存（PWA service worker）
- 升级到 widget B 体积策略（CDN 拆引用）

---

## 11. 决策日志

设计期间用户明确确认的决策：

1. 路线：**ChatGPT Apps（官方上架）**，不走 Custom GPT Actions / 只 Connector
2. 工具范围：**14 个**（12 只读 + prepare_task_draft + publish_task），不做 service 发布、不做 task application
3. 写入流程：**prepare_task_draft（草稿） → widget 编辑 → 点 Publish → publish_task 实发**
4. Widget 数量：3 个（task-list / helper-list / task-confirm-form）
5. Widget 仓库位置：monorepo `chatgpt-widgets/` 同级目录
6. OAuth library：**authlib**
7. 同意页：第一版 Jinja2 HTML，不上 React
8. 身份模型：代表 C 端最终用户（不是 B2B / 自家 service）
9. 部署形态：MCP server mount 在现有 FastAPI 同进程
10. Widget 体积策略：第一版 A 方案（singlefile inline），B 方案作为优化项后置
11. **v2 新增**：FastMCP lowlevel hybrid 模式（`_mcp_server.list_tools` + `request_handlers[CallToolRequest]`）绕过推断，复用 ai_tool_registry 35 个手写 JSON Schema
12. **v2 新增**：ChatGPT 为 OAuth public client (PKCE-only)，`client_secret_hash` 字段保留但对 ChatGPT 始终 NULL
13. **v2 新增**：task creation 重构抽 `app/crud/task_publish.py` 共享 helper，保证 `publish_task` 工具不绕过学生认证/内容过滤

---

## 12. Spec v2 修订记录

v1 提交 review 后发现 15 处问题，v2 全部修复。修订汇总：

### 致命问题（影响核心可行性）

| # | 问题 | v2 修复 |
|---|---|---|
| P1 | v1 声称 `window.openai.callTool` API，曾被质疑"未在官方 surface" | Verify 确认 **实际存在**，且 `@modelcontextprotocol/ext-apps/react` 的 `useApp().app.callServerTool` 是更干净的官方 API。Section 4.6 重写 widget 代码用 `app.callServerTool({ name, arguments })` |
| P2 | v1 用 `@mcp.tool(input_schema=...)` 装饰器 — FastMCP 实际从函数签名推断 schema，不接受 input_schema kwarg | 改用官方 escape hatch：`mcp._mcp_server.list_tools()` + `request_handlers[CallToolRequest]` 覆盖，直接传 `types.Tool(inputSchema=dict)`。Section 3.4 重写桥接代码 |
| P3 | v1 用 `ctx.session.user_id` 注入 user — FastMCP Context 不能写自定义字段 | 改用 SDK 自带 `mcp.server.auth.middleware.auth_context.get_access_token()` contextvar + 自定义 `L2UTokenVerifier` 子类。Section 3.6 新增 token_verifier.py |

### 严重问题（影响实现路径）

| # | 问题 | v2 修复 |
|---|---|---|
| P4 | Widget MIME `text/html+skybridge` 错误 | 改为官方 `text/html;profile=mcp-app`（Section 4.5） |
| P5 | npm 包 `@openai/apps-sdk` + `useToolOutput/useCallTool` hooks 是虚构 | 改用真实 `@modelcontextprotocol/ext-apps`（MCP 调用）+ `@openai/apps-sdk-ui`（UI 组件），hooks 改用真实 `useApp()` + `window.openai.toolOutput` 属性。Section 4.2 + 4.6 |
| P6 | OAuth `client_secret_hash` 对 ChatGPT 冗余 | ChatGPT 是 PKCE public client（无 secret），`client_secret_hash` 字段保留但允许 NULL，加 `token_endpoint_auth_method` 字段。Section 2.3 |
| P7 | `_create_task_internal` 函数虚构，且 `publish_task` 不走路由会绕过学生认证/内容过滤 | Section 3.7.1 新增 — 重构 `async_routers.create_task_async` 抽 `app/crud/task_publish.py` 共享 helper `create_task_for_user`，路由和 MCP 工具共调用 |
| P8 | `async with get_async_session()` helper 不存在 | 改为 `async with AsyncSessionLocal()`（来自 `app.database`）。Section 3.4 |
| P9 | `redis_client` 直接使用，真实路径错 | 改为 `from app.redis_cache import get_redis_client`。Section 3.4 / 3.7 |

### 小问题

| # | 问题 | v2 修复 |
|---|---|---|
| P10 | Migration `NNN` 未指定 | 填 **231**（最新 migration 是 230） |
| P11 | `mcp` + `authlib` 依赖未提及 requirements.txt | Section 1.1 模块树注明 + 新增 §12.2 依赖增量 |
| P12 | `prepare_task_draft` 加 `draft_id` 字段声称"行为不变"实际不一致 | Section 3.7.2 显式说明：原 `draft.action == "task_draft"` 字段不变，`draft_id` 是追加字段，AI Chat 前端可忽略 |
| P13 | `mcp_audit_log` 缺索引 | Section 5.3 加 `(user_id, tool_name, created_at DESC)` + 部分索引 `task_id` |
| P14 | 同意页 return_to 跳转依赖前端 `Login.tsx` 未 verify | Section 2.9 + M2 工期 + Section 9 风险登记三处标注，M2 第一周阻塞性 verify |
| P15 | Widget cache 多 worker 行为未说明 | Section 4.5 显式说明每个 gunicorn worker 各持一份是预期行为，无需 Redis 共享 |

### 12.1 工期变更

- M3 由 4 天 → **5 天**（加 task creation 重构 +1 天）
- 总工期 M1-M6 由 23 天 → **24 天**

### 12.2 依赖增量

**`backend/requirements.txt` 新增**：
```
mcp[cli]>=1.6.0,<2.0.0
authlib>=1.3.0,<2.0.0
```

**`chatgpt-widgets/package.json`**：
```json
{
  "dependencies": {
    "@modelcontextprotocol/ext-apps": "latest",
    "@openai/apps-sdk-ui": "latest",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "tailwindcss": "^3.4.0"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "vite-plugin-singlefile": "^2.0.0",
    "@types/react": "^18.3.0",
    "typescript": "^5.4.0"
  }
}
```

具体版本号在实施时锁定（写 plan 时填精确 minor / patch）。
