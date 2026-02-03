# 其它 App 用 Link²Ur 登录 — 开发文档（详细版）

本文档描述如何将 Link²Ur 实现为 **OAuth 2.0 / OpenID Connect (OIDC) 提供方**，使第三方应用可以支持「使用 Link²Ur 账号登录」。面向开发实现，包含端点规格、数据模型、错误码、安全与实现步骤。

---

## 目录

1. [目标与范围](#1-目标与范围)
2. [整体架构与时序](#2-整体架构与时序)
3. [端点规格（详细）](#3-端点规格详细)
4. [数据模型与迁移](#4-数据模型与迁移)
5. [PKCE 详细说明](#5-pkce-详细说明)
6. [同意页与登录页](#6-同意页与登录页)
7. [安全要点与防护](#7-安全要点与防护)
8. [环境变量与配置](#8-环境变量与配置)
9. [实现步骤清单](#9-实现步骤清单)
10. [与现有代码衔接](#10-与现有代码衔接)
11. [管理后台与运维](#11-管理后台与运维)
12. [测试与验收](#12-测试与验收)
13. [第三方接入示例](#13-第三方接入示例)
14. [合规性说明](#14-合规性说明)
15. [API 版本策略](#15-api-版本策略)
16. [参考](#16-参考)

---

## 1. 目标与范围

### 1.1 目标

- **第三方应用**（Web / iOS / Android / 后端服务）可引导用户到 Link²Ur 授权页登录。
- 用户同意后，第三方应用获得 **访问令牌 (access_token)** 和可选的 **ID Token、用户信息**，用于代表用户调用第三方自己的服务。
- 不暴露 Link²Ur 用户密码，符合 OAuth 2.0 / OIDC 标准。

### 1.2 不包含

- Link²Ur 本产品的登录/注册流程（已有）。
- 「用 Google/微信登录 Link²Ur」—— 那是 OAuth **客户端**，另见其它文档。

### 1.3 标准与缩写

| 术语 | 说明 |
|------|------|
| **RP** | Relying Party，依赖方，即「使用 Link²Ur 登录」的第三方应用 |
| **OP** | OpenID Provider，即 Link²Ur 在本方案中的角色 |
| **Authorization Code** | 授权码，短期一次性使用，用于换取 token |
| **OIDC** | OpenID Connect，在 OAuth 2.0 之上增加 ID Token 与用户信息 |
| **Issuer** | 签发者，即 Link²Ur 的根 URL，如 `https://api.link2ur.com` |

---

## 2. 整体架构与时序

### 2.1 授权码模式时序图

```
┌─────────────────┐         ┌──────────────────────────────────┐         ┌─────────────────┐
│  第三方 App (RP)  │         │     Link²Ur (OP / 授权服务)         │         │  Link²Ur 用户    │
│  Web / iOS / …   │         │  backend + 授权/登录/同意页         │         │  浏览器 / App    │
└────────┬────────┘         └────────────────┬─────────────────┘         └────────┬────────┘
         │                                   │                                    │
         │  1. 重定向到授权页                   │                                    │
         │  GET /api/oauth/authorize?client_id=…  &redirect_uri=…&response_type=code │
         │  &scope=openid profile email&state=…  │                                    │
         ├───────────────────────────────────►│                                    │
         │                                    │  2. 未登录则跳转 Link²Ur 登录       │
         │                                    │───────────────────────────────────►│
         │                                    │  3. 登录成功 → 显示同意页            │
         │                                    │◄───────────────────────────────────│
         │                                    │  4. 用户同意                         │
         │  5. 重定向回 RP + code              │                                    │
         │  redirect_uri?code=xxx&state=…      │                                    │
         │◄───────────────────────────────────│                                    │
         │  6. RP 用 code 换 token             │                                    │
         │  POST /api/oauth/token              │                                    │
         ├───────────────────────────────────►│                                    │
         │  7. 返回 access_token, id_token,    │                                    │
         │     refresh_token(可选)             │                                    │
         │◄───────────────────────────────────│                                    │
         │  8. (可选) GET /api/oauth/userinfo  │                                    │
         ├───────────────────────────────────►│                                    │
         │  9. 返回 sub, name, email 等        │                                    │
         │◄───────────────────────────────────│                                    │
```

### 2.2 授权流程分支说明

| 步骤 | 条件 | 行为 |
|------|------|------|
| 进入 /authorize | 未登录 | 重定向到 Link²Ur 登录页，登录成功后再重定向回 /authorize（原参数通过 session 或 query 保留） |
| 进入 /authorize | 已登录且 prompt≠consent 且已有同意记录 | 可跳过同意页，直接发 code（可选策略） |
| 进入 /authorize | 已登录 | 展示同意页 |
| 同意页 | 用户点击「同意」 | 生成 code，重定向 redirect_uri?code=…&state=… |
| 同意页 | 用户点击「拒绝」 | 重定向 redirect_uri?error=access_denied&state=… |
| Token | code 无效/过期/已用 | 返回 400 + error=invalid_grant |

---

## 3. 端点规格（详细）

### 3.1 端点一览

| 用途 | 方法 | 路径（建议） | 认证 | 说明 |
|------|------|--------------|------|------|
| 授权 | GET | `/api/oauth/authorize` | 无（浏览器 Cookie/Session） | 展示登录/同意页，成功后重定向带 code |
| 换 Token | POST | `/api/oauth/token` | client_id + client_secret（Body） | 用 authorization_code 或 refresh_token 换 token |
| 用户信息 | GET | `/api/oauth/userinfo` | Bearer access_token | 返回 OIDC UserInfo claims |
| 发现/配置 | GET | `/.well-known/openid-configuration` | 无 | 返回 issuer、各端点 URL、scopes 等 |
| 注销（可选） | GET/POST | `/api/oauth/logout` | 无 | id_token_hint + post_logout_redirect_uri（可选） |

---

### 3.2 GET /api/oauth/authorize

**请求：** 仅支持 GET，参数放在 Query String。

| 参数 | 必填 | 说明 | 示例 |
|------|------|------|------|
| `response_type` | 是 | 固定 `code` | `code` |
| `client_id` | 是 | 在 Link²Ur 注册的 RP 应用 ID | `abc123xyz` |
| `redirect_uri` | 是 | 授权后回调地址，必须与注册时完全一致（含 scheme、host、path、无 fragment） | `https://rp.com/callback` |
| `scope` | 推荐 | 空格分隔，OIDC 至少含 `openid` | `openid profile email` |
| `state` | 强烈推荐 | RP 生成，防 CSRF，回调时原样带回 | `s_abc123` |
| `nonce` | 可选 | 用于 ID Token 防重放，若请求则须回填到 id_token | `n_xyz789` |
| `prompt` | 可选 | `login`=强制登录，`consent`=强制同意，`none`=不交互（无会话则报错） | `consent` |
| `code_challenge` | PKCE | 见 [5. PKCE](#5-pkce-详细说明) | Base64URL(SHA256(code_verifier)) |
| `code_challenge_method` | PKCE | 推荐 `S256` | `S256` |

**成功响应：** 不直接返回 JSON，而是 **302 重定向** 到 RP 的 `redirect_uri`：

```http
HTTP/1.1 302 Found
Location: https://rp.com/callback?code=4/P7q6Wr91&state=s_abc123
```

- `code`：授权码，建议 32 字节随机数 Base64URL，有效期建议 **5–10 分钟**，一次性使用。
- `state`：与请求中一致。

**错误响应：** 同样通过 **重定向** 到 `redirect_uri` 带回错误（便于 RP 统一处理）：

```http
HTTP/1.1 302 Found
Location: https://rp.com/callback?error=invalid_request&error_description=redirect_uri+mismatch&state=s_abc123
```

常见错误码（RFC 6749 §4.1.2.1）：

| error | 说明 |
|-------|------|
| `invalid_request` | 缺少必填参数、response_type 非 code、redirect_uri 与注册不一致等 |
| `unauthorized_client` | client_id 未注册或已禁用 |
| `access_denied` | 用户拒绝授权 |
| `unsupported_response_type` | response_type 不是 code |
| `invalid_scope` | scope 包含不支持或无效值 |
| `server_error` | 服务端异常 |

若 **无法重定向**（例如 client_id 无效、redirect_uri 完全无法校验），可退回 **200 + 错误页** 或 **400 + JSON**，并在文档中约定。

**服务端校验顺序建议：**

1. 必填参数：`response_type`、`client_id`、`redirect_uri`。
2. `response_type === "code"`。
3. 根据 `client_id` 查 `oauth_client`，存在且启用。
4. `redirect_uri` 必须在该客户端的 `redirect_uris` 白名单中，**逐字节一致**（不含 fragment）。
5. `scope` 若包含 `openid` 则按 OIDC 处理；校验所有 scope 均在支持列表中。
6. 未登录 → 跳转登录并保存当前 authorize 参数（session 或加密 query）。
7. 已登录 → 渲染同意页或（按策略）直接发 code。

---

### 3.3 POST /api/oauth/token

**请求：** 必须为 **application/x-www-form-urlencoded**，Body 传参。

**用授权码换 Token：**

| 参数 | 必填 | 说明 |
|------|------|------|
| `grant_type` | 是 | 固定 `authorization_code` |
| `code` | 是 | 授权端点返回的 code |
| `redirect_uri` | 是 | 必须与发起授权请求时使用的 redirect_uri **完全一致** |
| `client_id` | 是 | 客户端 ID |
| `client_secret` | 机密客户端 | 客户端密钥（公开客户端不传，改用 PKCE） |
| `code_verifier` | PKCE 时 | 见 [5. PKCE](#5-pkce-详细说明) |

**用 Refresh Token 换新 Token：**

| 参数 | 必填 | 说明 |
|------|------|------|
| `grant_type` | 是 | 固定 `refresh_token` |
| `refresh_token` | 是 | 此前颁发的 refresh_token |
| `client_id` | 是 | 客户端 ID |
| `client_secret` | 机密客户端 | 客户端密钥 |
| `scope` | 可选 | 请求的 scope 不得大于原授权 scope |

**成功响应：** `200 OK`，`Content-Type: application/json`。

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "def50200a1b2c3...",
  "scope": "openid profile email",
  "id_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

- `expires_in`：access_token 有效秒数，建议 3600（1 小时）。
- `refresh_token`：可选，若客户端在授权时请求了 offline_access 或配置允许则返回；有效期建议 30 天或更长，可配置。
- `id_token`：OIDC 时返回，JWT 格式，见 [3.6 id_token 结构](#36-id_token-jwt-结构)。

**错误响应：** `400 Bad Request`，`Content-Type: application/json`。

```json
{
  "error": "invalid_grant",
  "error_description": "The provided authorization grant is invalid, expired, or revoked."
}
```

常见 error 值（RFC 6749 §5.2）：

| error | 说明 |
|-------|------|
| `invalid_request` | 缺少参数、格式错误 |
| `invalid_client` | client_id/client_secret 错误或客户端被禁用 |
| `invalid_grant` | code 无效/过期/已使用、redirect_uri 不一致、code_verifier 错误等 |
| `unauthorized_client` | 该客户端不允许此 grant_type |
| `unsupported_grant_type` | grant_type 不支持 |
| `invalid_scope` | 请求的 scope 超出原授权范围 |

**服务端校验顺序（authorization_code）：**

1. `grant_type === "authorization_code"`。
2. 从库/Redis 根据 `code` 取授权记录；不存在或已过期或已使用 → `invalid_grant`。
3. 校验 `client_id` 与记录一致；校验 `redirect_uri` 与记录一致。
4. 若为机密客户端，校验 `client_secret`；若为公开客户端，校验 `code_verifier` 与保存的 `code_challenge` 一致。
5. 标记 code 已使用（或删除），生成 access_token（及可选 refresh_token、id_token），返回。

---

### 3.4 GET /api/oauth/userinfo

**请求：**  
`Authorization: Bearer {access_token}`  
可选 Header：`Accept: application/json`。

**成功响应：** `200 OK`，`Content-Type: application/json`。

**完整示例（含 profile + email scope）：**

```json
{
  "sub": "12345678",
  "name": "张三",
  "given_name": "三",
  "family_name": "张",
  "email": "zhangsan@example.com",
  "email_verified": true,
  "picture": "https://cdn.link2ur.com/avatars/12345678.jpg",
  "locale": "zh-CN",
  "updated_at": 1640000000
}
```

**仅 openid 时的最小示例：** `{"sub":"12345678"}`。根据授权 scope 决定返回字段，未授权 scope 不返回对应 claim。

**UserInfo 标准 Claims（OIDC）：**

| Claim | 类型 | 说明 | Link²Ur 来源 |
|-------|------|------|------------------|
| `sub` | string | 用户唯一标识，同一用户在不同 client 一致 | `User.id`（8 位） |
| `name` | string | 显示名 | `User.name` |
| `given_name` | string | 名 | 可从 name 拆分或暂用 name |
| `family_name` | string | 姓 | 可从 name 拆分或空 |
| `email` | string | 邮箱 | `User.email` |
| `email_verified` | boolean | 邮箱是否验证 | 对应 `User.is_verified` |
| `picture` | string | 头像 URL | `User.avatar` 或拼接 CDN |
| `locale` | string | 语言 | `User.language_preference` |
| `updated_at` | number | 最后更新时间（Unix 秒） | 可取自 `User` 某时间戳 |

根据授权 `scope` 决定返回哪些字段：例如仅 `openid` 时至少返回 `sub`；`profile` 增加 name/picture 等；`email` 增加 email、email_verified。未授权 scope 对应的 claim 不返回。

**错误响应：**  
`401 Unauthorized`，可带 `WWW-Authenticate: Bearer error="invalid_token"`；或返回 JSON：

```json
{
  "error": "invalid_token",
  "error_description": "The access token is invalid or expired."
}
```

---

### 3.5 GET /.well-known/openid-configuration

**请求：** 无认证。

**成功响应：** `200 OK`，`Content-Type: application/json`。

```json
{
  "issuer": "https://api.link2ur.com",
  "authorization_endpoint": "https://api.link2ur.com/api/oauth/authorize",
  "token_endpoint": "https://api.link2ur.com/api/oauth/token",
  "userinfo_endpoint": "https://api.link2ur.com/api/oauth/userinfo",
  "jwks_uri": "https://api.link2ur.com/api/oauth/jwks",
  "scopes_supported": ["openid", "profile", "email"],
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["HS256"],
  "code_challenge_methods_supported": ["S256"],
  "token_endpoint_auth_methods_supported": ["client_secret_post", "client_secret_basic"]
}
```

若使用 HS256 签 id_token，可暂无 `jwks_uri`；若使用 RS256，需提供 JWKS 端点。  
`issuer` 必须与 id_token 中的 `iss` 一致，且无末尾斜杠。

---

### 3.6 id_token JWT 结构

**Header：**  
`{"alg":"HS256","typ":"JWT"}`

**Payload 建议字段：**

| Claim | 类型 | 说明 |
|-------|------|------|
| `iss` | string | Issuer，与 .well-known 的 issuer 一致 |
| `sub` | string | 用户 ID，同 UserInfo 的 sub |
| `aud` | string 或 array | 受众，一般为 client_id |
| `exp` | number | 过期时间（Unix 秒），建议与 access_token 一致或略长 |
| `iat` | number | 签发时间（Unix 秒） |
| `nonce` | string | 若授权请求带了 nonce 则必须回填，RP 用于防重放 |
| `auth_time` | number | 可选，用户最近一次认证时间 |

**签名：** 使用与 access_token 一致的密钥（或单独 OAUTH_ID_TOKEN_SECRET），算法 HS256。  
同一用户同一 client 多次登录，每次应生成新的 id_token（新 iat/exp）。

---

### 3.7 错误响应统一格式与降级

**统一格式（符合 RFC 6749 / OIDC）：**

所有 OAuth/OIDC 错误响应应包含以下字段（JSON 或重定向 query 参数）：

| 字段 | 必填 | 说明 |
|------|------|------|
| `error` | 是 | 错误代码，符合 RFC 标准（如 invalid_request、invalid_grant） |
| `error_description` | 推荐 | 人类可读的错误描述，便于调试 |
| `error_uri` | 可选 | 指向错误详情文档的 URL，供合作方查阅 |
| `state` | 授权流程 | 原样返回客户端的 state，便于 RP 关联请求 |

**示例（Token 端点 400）：**

```json
{
  "error": "invalid_grant",
  "error_description": "The provided authorization grant is invalid, expired, or revoked.",
  "error_uri": "https://docs.link2ur.com/oauth/errors#invalid_grant"
}
```

**授权端点错误重定向示例：**

```http
Location: https://rp.com/callback?error=access_denied&error_description=User+denied+authorization&state=s_abc123
```

**错误日志记录规范：**

- **必须记录（脱敏）：** 时间、client_id、error 类型、IP、请求路径；不记录 code、token、client_secret、用户密码。
- **可选记录：** user_id（仅内部日志，不对外）、redirect_uri（用于排查配置）。
- **日志级别：** 4xx 建议 WARNING，5xx 为 ERROR；重复 invalid_grant 可聚合避免刷屏。

**降级策略（授权服务不可用时）：**

- **授权页/登录页不可用：** 返回 503 + Retry-After，或友好错误页「服务暂时不可用，请稍后再试」；RP 应提示用户稍后重试。
- **Token 端点不可用：** 返回 503；RP 不应重复重试过频，建议指数退避。
- **Userinfo 端点不可用：** 返回 503；RP 可仅依赖 id_token 中的 sub 做会话，稍后再拉 userinfo。
- **数据库/Redis 不可用：** 拒绝新授权与 token 请求（503），不返回 200 与假 token；已有 access_token 在有效期内可继续用于 userinfo（若 access_token 为 JWT 自包含且不依赖库查）。

---

## 4. 数据模型与迁移

### 4.1 表：oauth_client

用于存储第三方应用（RP）的注册信息。

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| `id` | BIGSERIAL / INTEGER | PK | 主键 |
| `client_id` | VARCHAR(64) | UNIQUE NOT NULL | 对外暴露的应用 ID，建议 UUID 或 32 位随机 |
| `client_secret_hash` | VARCHAR(128) | 可 NULL | bcrypt 等哈希，机密客户端必填；公开客户端可为空 |
| `client_name` | VARCHAR(255) | NOT NULL | 应用名称，用于同意页展示 |
| `client_uri` | VARCHAR(512) | 可 NULL | 应用官网/介绍链接 |
| `logo_uri` | VARCHAR(512) | 可 NULL | 应用 logo，同意页可选展示 |
| `redirect_uris` | JSONB / TEXT[] | NOT NULL | 允许的回调 URI 列表，如 `["https://rp.com/cb"]` |
| `scope_default` | VARCHAR(512) | 可 NULL | 默认 scope，如 `openid profile email` |
| `allowed_grant_types` | JSONB / TEXT[] | NOT NULL | 如 `["authorization_code","refresh_token"]` |
| `is_confidential` | BOOLEAN | DEFAULT true | 是否有 client_secret |
| `is_active` | BOOLEAN | DEFAULT true | 是否启用，禁用后所有 token 请求拒绝 |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | 创建时间 |
| `updated_at` | TIMESTAMPTZ | DEFAULT now() | 更新时间 |

**redirect_uri 校验规则：** 请求中的 redirect_uri 必须与表中某一条 **完全一致**（包括 scheme、host、port、path）；不允许用通配符或只匹配前缀（避免开放重定向）。

**示例 SQL（PostgreSQL）：**

```sql
-- migrations/xxx_create_oauth_tables.sql
CREATE TABLE oauth_client (
    id SERIAL PRIMARY KEY,
    client_id VARCHAR(64) NOT NULL UNIQUE,
    client_secret_hash VARCHAR(128),
    client_name VARCHAR(255) NOT NULL,
    client_uri VARCHAR(512),
    logo_uri VARCHAR(512),
    redirect_uris JSONB NOT NULL DEFAULT '[]',
    scope_default VARCHAR(512),
    allowed_grant_types JSONB NOT NULL DEFAULT '["authorization_code"]',
    is_confidential BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_oauth_client_client_id ON oauth_client(client_id);
CREATE INDEX idx_oauth_client_is_active ON oauth_client(is_active);
```

---

### 4.2 表：oauth_authorization_code

用于存储授权码，可替代方案：仅用 Redis，key 如 `oauth:code:{code}`，value 为 JSON，TTL 600 秒。

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| `code` | VARCHAR(128) | PK | 授权码，随机生成，一次性 |
| `client_id` | VARCHAR(64) | NOT NULL, FK→oauth_client(client_id) | 客户端 ID |
| `user_id` | VARCHAR(8) | NOT NULL, FK→users(id) | Link²Ur 用户 ID |
| `redirect_uri` | VARCHAR(512) | NOT NULL | 与授权请求一致 |
| `scope` | VARCHAR(512) | NOT NULL | 已授权 scope |
| `nonce` | VARCHAR(128) | 可 NULL | 若请求带 nonce 则存于此，生成 id_token 时回填 |
| `code_challenge` | VARCHAR(256) | 可 NULL | PKCE 的 code_challenge |
| `code_challenge_method` | VARCHAR(16) | 可 NULL | 如 S256 |
| `expires_at` | TIMESTAMPTZ | NOT NULL | 过期时间 |
| `used_at` | TIMESTAMPTZ | 可 NULL | 使用时间，非空表示已使用 |

**示例 SQL：**

```sql
CREATE TABLE oauth_authorization_code (
    code VARCHAR(128) PRIMARY KEY,
    client_id VARCHAR(64) NOT NULL REFERENCES oauth_client(client_id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    redirect_uri VARCHAR(512) NOT NULL,
    scope VARCHAR(512) NOT NULL,
    nonce VARCHAR(128),
    code_challenge VARCHAR(256),
    code_challenge_method VARCHAR(16),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ
);

CREATE INDEX idx_oauth_code_expires ON oauth_authorization_code(expires_at);
CREATE INDEX idx_oauth_code_client ON oauth_authorization_code(client_id);
CREATE INDEX idx_oauth_code_user_client ON oauth_authorization_code(user_id, client_id);
```

**索引策略：**

| 索引 | 用途 |
|------|------|
| `code` (PK) | 换 token 时按 code 查询 |
| `idx_oauth_code_expires` | 定时任务按过期时间清理；查询时过滤未过期 |
| `idx_oauth_code_client` | 按 client 统计或排查问题 |
| `idx_oauth_code_user_client` | 按用户+客户端查询（如「是否已有同意记录」） |

**数据保留策略：**

- **oauth_authorization_code：** 使用后立即标记 `used_at` 或删除；未使用的码在 `expires_at` 后由定时任务删除（建议每日或每小时），保留时间不超过 24 小时。
- **oauth_refresh_token（若落表）：** 按 `expires_at` 清理；撤销后软删除或标记 revoked；审计需求可保留 90 天再物理删除。
- **oauth_client：** 不自动删除；禁用时设 `is_active=false`，历史 token 可设置宽限期后失效。

---

### 4.3 Access Token 与 Refresh Token 存储

**Access Token：**  
- 方案 A：JWT 自包含，不落库；payload 含 `sub`、`client_id`、`scope`、`exp`、`iss`、`aud`；用独立密钥签名（如 `OAUTH_ACCESS_TOKEN_SECRET`），与现有「本产品登录」JWT 区分。  
- 方案 B：随机 token 存 Redis/表，key 如 `oauth:access:{token}`，value 含 user_id、client_id、scope、exp；校验时查库/Redis。

**Refresh Token：**  
- 建议存表或 Redis，便于撤销、审计。  
- 表字段示例：`token`(PK)、`client_id`、`user_id`、`scope`、`expires_at`、`created_at`；或 Redis key `oauth:refresh:{token}`，value JSON，TTL 如 30 天。

**与现有代码隔离：**  
- 现有 `secure_auth` 的 access/refresh 用于「Link²Ur 本产品」会话；OAuth 的 token 仅用于「第三方 RP 代表用户」，不在同一 Redis key 空间或 JWT aud/claim 混用，避免误用。

---

## 5. PKCE 详细说明

用于 **无 client_secret** 的客户端（如 SPA、原生 App），防止授权码被拦截后换 token（RFC 7636）。

### 5.1 流程

1. RP 生成随机 `code_verifier`（43–128 字符，[A-Za-z0-9-._~]）。
2. RP 计算 `code_challenge = BASE64URL(SHA256(code_verifier))`，即 `code_challenge_method=S256`。
3. 授权请求中增加 `code_challenge`、`code_challenge_method=S256`；服务端将 code_challenge 与授权码一起保存。
4. 用 code 换 token 时，RP 在 Body 中传 `code_verifier`；服务端计算 `BASE64URL(SHA256(code_verifier))`，与保存的 code_challenge 比较，一致才发放 token。

### 5.2 code_verifier 规则

- 长度：43–128 字符。
- 字符集：`[A-Z] [a-z] [0-9] - . _ ~`。

### 5.3 code_challenge 计算（S256）

伪代码：

```text
code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
```

Python 示例（服务端校验可用 `hmac.compare_digest` 做常数时间比较）：

```python
import hashlib
import base64

def make_code_challenge(code_verifier: str) -> str:
    digest = hashlib.sha256(code_verifier.encode("ascii")).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
```

服务端校验：

```python
def verify_code_verifier(code_verifier: str, code_challenge: str) -> bool:
    expected = make_code_challenge(code_verifier)
    return constant_time_compare(expected, code_challenge)
```

### 5.4 授权请求示例（带 PKCE）

```http
GET /api/oauth/authorize?response_type=code&client_id=public_app_id&redirect_uri=https://spa.example.com/callback&scope=openid%20profile%20email&state=xyz&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256
```

### 5.5 Token 请求示例（带 code_verifier）

```http
POST /api/oauth/token HTTP/1.1
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=收到的code&redirect_uri=https://spa.example.com/callback&client_id=public_app_id&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

公开客户端不传 `client_secret`；若同时传了 code_verifier 且与 code_challenge 匹配，则通过校验。

---

## 6. 同意页与登录页

### 6.1 登录页衔接

- 未登录用户访问 `/api/oauth/authorize` 时，重定向到 **现有 Link²Ur 登录页**（如 `https://www.link2ur.com/login`）。
- 登录页 URL 可带参数保存「返回授权页」的完整 URL，例如：  
  `https://www.link2ur.com/login?return_to=https%3A%2F%2Fapi.link2ur.com%2Fapi%2Foauth%2Fauthorize%3Fclient_id%3D...%26redirect_uri%3D...%26...`
- 登录成功后，前端或后端重定向到 `return_to`，即再次进入 `/api/oauth/authorize`，此时已登录，展示同意页。

替代方案：用 Session 存 authorize 的 query 参数，登录成功后从 Session 取出并重定向回 `/api/oauth/authorize?…`（参数还原）。

### 6.2 同意页内容与文案

- **标题：** 如「XXX 应用请求访问你的 Link²Ur 账号」。
- **应用信息：** 显示 `client_name`，可选 `logo_uri`、`client_uri`。
- **Scope 说明（按请求的 scope 展示）：**

| scope | 中文说明 | 英文说明 |
|-------|----------|----------|
| openid | 验证你的身份 | Verify your identity |
| profile | 读取你的昵称和头像 | Read your name and profile picture |
| email | 读取你的邮箱 | Read your email address |

- **按钮：** 「同意 / Authorize」「拒绝 / Deny」。
- **状态保持：** 同意页表单提交时把原 authorize 的 `state`、`redirect_uri`、`client_id`、`scope` 等一并提交，确保重定向时带正确 state。

### 6.3 多语言

根据用户 `language_preference` 或 Accept-Language 选择中文/英文文案；与现有前端 i18n 一致即可。

---

## 7. 安全要点与防护

### 7.1 redirect_uri

- **白名单：** 仅允许 oauth_client 表中该 client 的 `redirect_uris` 列表中的 URI。
- **完全匹配：** 请求中的 redirect_uri 与列表中某一项 **逐字节一致**（scheme、host、port、path）；不允许只匹配前缀或域名，避免开放重定向。
- **Fragment：** 请求中的 redirect_uri **不得包含 fragment**（`#`），服务端在 authorize 与 consent 中会校验并返回 invalid_request；重定向时 Location 仅使用 query，不带 fragment。

### 7.2 state

- RP 必须生成随机 state 并在回调时校验与发起授权时一致，防 CSRF；服务端不解析 state 含义，只原样带回。

### 7.3 授权码

- 一次性：使用后立即标记删除或 `used_at` 写入，禁止重复使用。
- 短有效期：建议 5–10 分钟。
- 随机性：至少 32 字节随机数，Base64URL 编码。

### 7.4 client_secret 与 Token 端点认证

- 仅服务端使用；不在前端、移动端代码或公开仓库中暴露。
- 存储使用 bcrypt 等哈希，不存明文。
- 轮换时：生成新 secret，更新哈希，旧 secret 作废；可保留短暂重叠期供 RP 更新配置。
- **Token 端点认证方式：** 支持 `client_secret_post`（body 中传 client_id、client_secret）与 `client_secret_basic`（`Authorization: Basic base64(client_id:client_secret)`）；client_id 与 client_secret 可从 Body 或 Basic 头中任一处提供，Body 优先。

### 7.5 HTTPS

- 生产环境下 authorize、token、userinfo、.well-known 均通过 HTTPS 提供。

### 7.6 速率限制

- 对 `/api/oauth/token` 按 IP 做速率限制（如 30 次/分钟），防止暴力尝试 code 或 refresh_token。
- 对 `/api/oauth/authorize` 按 IP 限制频率（如 60 次/分钟），防止爬取或滥用。
- 对 `/api/oauth/consent`（同意页 POST）按 IP 限流（如 60 次/分钟），防止滥用或自动化提交。

### 7.7 日志与审计

- 记录：授权成功/拒绝、token 颁发、userinfo 访问；不记录密码或 token 明文；可记录 client_id、user_id、scope、IP、时间，便于审计与排查。

### 7.8 性能优化建议

| 场景 | 建议 | 说明 |
|------|------|------|
| **授权码存储** | 优先 Redis，TTL 10 分钟 | 自动过期，无需定时清理；高并发下减少 DB 压力；key 如 `oauth:code:{code}`，value JSON（client_id、user_id、redirect_uri、scope、code_challenge 等）。 |
| **Client 配置** | Redis 缓存 | 按 client_id 缓存 oauth_client 行，TTL 5–15 分钟，减少 /authorize、/token 的 DB 查询。 |
| **用户同意记录** | 可选缓存 | 缓存「用户 U 对 client C 已同意」最近 30 天，避免重复展示同意页；缓存 key 如 `oauth:consent:{user_id}:{client_id}`，TTL 30 天。 |
| **Token 验证** | JWT 自包含 + 可选黑名单 | access_token 用 JWT 自包含时，userinfo 端点仅验签与 exp，无需查库；若需「立即撤销」，可配合 Redis 黑名单（key `oauth:revoked:{jti}`）。 |
| **数据库连接** | 连接池 | 使用 SQLAlchemy/async 连接池，避免每请求新建连接；池大小按 QPS 与 DB 能力调优。 |
| **高并发** | 限流 + 降级 | /token 按 client_id 与 IP 限流；DB/Redis 不可用时返回 503 而非 200+ 假数据。 |

**存储选型小结：** 授权码推荐 Redis；access_token 推荐 JWT 自包含（减少存储与查询）；refresh_token 可 Redis 或表，便于撤销与审计。

---

## 8. 环境变量与配置

建议在 `backend` 或 `app.config` 中集中配置，例如：

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `OAUTH_ISSUER` | Issuer URL，与 .well-known 及 id_token iss 一致 | `https://api.link2ur.com` |
| `OAUTH_ACCESS_TOKEN_EXPIRE_SECONDS` | access_token 有效秒数 | `3600` |
| `OAUTH_REFRESH_TOKEN_EXPIRE_DAYS` | refresh_token 有效天数 | `30` |
| `OAUTH_AUTHORIZATION_CODE_EXPIRE_SECONDS` | 授权码有效秒数 | `600` |
| `OAUTH_ACCESS_TOKEN_SECRET` 或 `OAUTH_ID_TOKEN_SECRET` | 签 JWT 用密钥（可与现有 SECRET_KEY 不同） | 长随机字符串 |
| `OAUTH_CONSENT_PAGE_URL` | 同意页完整 URL（若前后端分离） | 可选 |

若与现有 `SECRET_KEY` 共用 JWT 密钥，需在 payload 中通过 `aud` 或自定义 claim 区分「本产品登录」与「OAuth 第三方」，避免 token 混用。

---

## 9. 实现步骤清单

### 阶段一：后端核心

- [ ] 新增迁移：创建 `oauth_client`、`oauth_authorization_code`（及可选 `oauth_refresh_token`）表。
- [ ] 实现客户端注册：管理接口或脚本，生成 client_id、client_secret，写入 oauth_client，配置 redirect_uris。
- [ ] **GET /api/oauth/authorize**：校验参数 → 未登录跳转登录并带回 authorize URL → 已登录渲染同意页（或返回同意页 URL）；同意页提交后生成 code 并重定向 redirect_uri?code=…&state=…。
- [ ] **POST /api/oauth/token**：grant_type=authorization_code 时校验 code、client_id、redirect_uri、client_secret 或 code_verifier；签发 access_token（及可选 refresh_token、id_token）；标记 code 已使用。
- [ ] **GET /api/oauth/userinfo**：校验 Bearer access_token，根据 scope 返回 sub、name、email、picture 等。

### 阶段二：OIDC 与发现

- [ ] id_token：JWT 含 iss、sub、aud、exp、iat、nonce（若存在）；使用独立密钥或 aud 区分。
- [ ] refresh_token：实现 grant_type=refresh_token，校验 refresh_token 与 client_id，签发新 access_token（及可选新 refresh_token、id_token）。
- [ ] **GET /.well-known/openid-configuration**：返回 issuer、各 endpoint、scopes_supported、code_challenge_methods_supported 等。

### 阶段三：前端与运营

- [ ] 同意页：接入前端/设计系统，多语言 scope 文案、同意/拒绝。
- [x] 管理后台：RP 应用 CRUD、redirect_uris 配置、编辑 client_uri/logo_uri、client_secret 创建时/轮换后展示与复制、启用/禁用、创建时间展示。
- [ ] 第三方文档：授权 URL、token URL、scope、示例代码（含 PKCE）。

### 阶段四：可选

- [ ] PKCE：authorize 保存 code_challenge；token 校验 code_verifier。
- [ ] **GET/POST /api/oauth/logout**：id_token_hint + post_logout_redirect_uri（可选）。
- [ ] 速率限制与审计日志。

---

## 10. 与现有代码衔接

- **登录：** 继续使用 `secure_auth_routes` 的登录；授权流程中未登录时跳转到现有登录页，登录成功后再回到 authorize。
- **用户信息：** userinfo 的 sub、name、email、avatar 等从现有 `User` 模型与 crud 读取；sub 使用 `User.id`（8 位）。
- **JWT/密钥：** 可为 OAuth 单独配置 `OAUTH_ACCESS_TOKEN_SECRET` / `OAUTH_ID_TOKEN_SECRET`，或在现有 SECRET_KEY 下用 `aud`/type 区分 OAuth token，避免与「本产品登录」token 混用。

---

## 11. 管理后台与运维

### 11.1 客户端管理接口与前端

**后端 API（`/api/admin/oauth/clients`，需管理员认证）：**

- **创建客户端**：POST，入参 client_name、redirect_uris、client_uri、logo_uri、is_confidential 等；返回 client_id、client_secret（仅创建时返回一次，需妥善交付 RP）。
- **列表/详情**：GET，仅管理员，可查询参数 is_active 过滤。
- **更新**：PATCH redirect_uris、client_name、client_uri、logo_uri、is_active 等；不直接改 client_secret，通过「轮换」接口生成新 secret。
- **轮换 client_secret**：POST `.../rotate-secret`，生成新 secret，更新 client_secret_hash，返回新 client_secret（仅此次展示，管理员可复制后关闭弹窗）。

**管理前端（OAuth 客户端管理页）：**

- 列表展示：应用名称、Client ID（支持一键复制）、回调地址摘要、状态、创建时间。
- 新建客户端：弹窗填写名称、回调地址（多行/逗号）、应用官网、Logo URL、是否机密客户端；创建成功后弹窗展示 Client ID / Client Secret 及复制按钮。
- 编辑：弹窗修改应用名称、回调地址、client_uri、logo_uri。
- 启用/禁用、轮换 Secret；轮换成功后弹窗展示新 Secret 及复制按钮。

### 11.2 运维

- 定时清理过期/已用 authorization_code；可选清理过期 refresh_token。
- 监控 token 端点 4xx/5xx、授权重定向错误比例，便于发现配置错误或滥用。

### 11.3 监控指标

**关键指标：**

| 指标 | 说明 | 目标 |
|------|------|------|
| 授权成功率 | authorize 成功重定向（带 code）/ 总 authorize 请求 | ≥ 95%（排除用户主动拒绝） |
| Token 颁发延迟 | POST /token 从请求到响应的耗时 | P50 &lt; 200ms，P95 &lt; 500ms，P99 &lt; 1s |
| 错误率 | 按 error 类型分类（invalid_grant、invalid_client 等） | 监控异常峰值，便于发现配置或攻击 |
| 活跃客户端数 | 近 24h 内发起过 authorize 或 token 的 client_id 数 | 趋势与异常新增 |
| 异常 IP 频率 | 同一 IP 对 /token 或 /authorize 的请求频率 | 识别爬取或暴力尝试 |

**告警阈值建议：**

| 条件 | 级别 | 动作 |
|------|------|------|
| 授权成功率 &lt; 95%（按小时） | Warning | 排查 redirect_uri、client 配置与前端回调 |
| Token 颁发 P99 延迟 &gt; 500ms | Warning | 排查 DB/Redis 与网络 |
| 5 分钟内同一 IP 对 /token 请求 &gt; 100 次 | Critical | 可能暴力尝试 code，限流或封禁 IP |
| /token 或 /userinfo 5xx 率 &gt; 1% | Critical | 排查服务与依赖 |

### 11.4 灾难恢复与应急

**数据备份：**

- **oauth_client：** 随主库备份；变更少，可纳入常规 DB 备份与 PITR。
- **oauth_authorization_code：** 若用 Redis，可开启 RDB/AOF；若用表，随主库备份即可（短期数据，不必单独归档）。
- **refresh_token 存储：** 若落表，随主库备份；若 Redis，同 Redis 持久化策略。

**client_secret 泄露应急：**

1. 在管理后台将该客户端 **禁用**（is_active=false），或立即 **轮换 client_secret**。
2. 轮换后通知 RP 更新配置；旧 secret 作废后，使用旧 refresh_token 的请求将返回 invalid_grant。
3. 若需撤销该客户端已签发的所有 token：将 refresh_token 撤销（删除或标记）；access_token 为 JWT 时无法逐个撤销，依赖短期过期；必要时可加入 Redis 黑名单（按 jti 或按 user_id+client_id 批量）。

**服务降级：**

- 授权/登录/同意页不可用：返回 503 + 友好提示，不重定向到 RP 带假 code。
- Token 端点不可用：返回 503；RP 应提示用户稍后重试。
- Userinfo 不可用：返回 503；RP 可仅依赖 id_token 的 sub 维持会话。

---

## 12. 测试与验收

### 12.1 单元/集成测试要点

- [ ] authorize：缺少 client_id/redirect_uri → 错误重定向；无效 client_id → unauthorized_client；redirect_uri 不在白名单 → invalid_request。
- [ ] authorize：已登录 + 用户同意 → 重定向带 code + state；用户拒绝 → error=access_denied。
- [ ] token：无效 code → invalid_grant；错误 redirect_uri → invalid_grant；错误 client_secret → invalid_client；PKCE code_verifier 错误 → invalid_grant。
- [ ] token：有效 code → 200，返回 access_token、id_token（若 scope 含 openid）、refresh_token（若配置）。
- [ ] userinfo：无效/过期 token → 401；有效 token → 200，含 sub 及授权 scope 对应 claims。
- [ ] refresh_token：无效/过期 refresh_token → invalid_grant；有效 → 新 access_token。

### 12.2 手动验收

- 使用浏览器完成一次完整流程：RP 重定向 → Link²Ur 登录 → 同意页 → 回调拿 code → 用 code 换 token → 用 access_token 调 userinfo。
- 使用 Postman 或脚本测试 token、userinfo；测试 PKCE 流程（不传 client_secret）。

---

## 13. 第三方接入示例

### 13.1 授权链接（含 PKCE 的 SPA 示例）

```http
GET https://api.link2ur.com/api/oauth/authorize?response_type=code&client_id=YOUR_CLIENT_ID&redirect_uri=https://your-app.com/callback&scope=openid%20profile%20email&state=random_state_xyz&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256
```

### 13.2 用 code 换 token（form-urlencoded）

```http
POST https://api.link2ur.com/api/oauth/token HTTP/1.1
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=RECEIVED_CODE&redirect_uri=https://your-app.com/callback&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

（机密客户端必传 client_secret；公开客户端不传 client_secret，必传 code_verifier。）

### 13.3 用 refresh_token 换新 token

```http
POST https://api.link2ur.com/api/oauth/token HTTP/1.1
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token&refresh_token=REFRESH_TOKEN&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET
```

### 13.4 获取用户信息

```http
GET https://api.link2ur.com/api/oauth/userinfo HTTP/1.1
Authorization: Bearer ACCESS_TOKEN
```

### 13.5 发现配置

```http
GET https://api.link2ur.com/.well-known/openid-configuration
```

### 13.6 Node.js 完整示例（PKCE）

```javascript
const crypto = require('crypto');

function base64URLEncode(buf) {
  return buf.toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function generatePKCE() {
  const verifier = base64URLEncode(crypto.randomBytes(32));
  const challenge = base64URLEncode(
    crypto.createHash('sha256').update(verifier).digest()
  );
  return { verifier, challenge };
}

function generateState() {
  return base64URLEncode(crypto.randomBytes(16));
}

const CLIENT_ID = 'YOUR_CLIENT_ID';
const REDIRECT_URI = 'https://your-app.com/callback';

// 1. 构建授权 URL
const { verifier, challenge } = generatePKCE();
const state = generateState();
// 将 verifier、state 存入 session 或 cookie，回调时校验 state 并用 verifier 换 token
const authUrl =
  'https://api.link2ur.com/api/oauth/authorize?' +
  `response_type=code` +
  `&client_id=${encodeURIComponent(CLIENT_ID)}` +
  `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
  `&scope=openid%20profile%20email` +
  `&state=${encodeURIComponent(state)}` +
  `&code_challenge=${encodeURIComponent(challenge)}` +
  `&code_challenge_method=S256`;

// 2. 用户同意后，在回调中用 code 换 token
async function exchangeCodeForToken(code, codeVerifier) {
  const res = await fetch('https://api.link2ur.com/api/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: REDIRECT_URI,
      client_id: CLIENT_ID,
      code_verifier: codeVerifier,
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error_description || err.error || res.statusText);
  }
  return res.json();
}
```

### 13.7 错误处理示例（RP 端）

**回调页处理授权错误：**

```javascript
// 从 redirect_uri 的 query 解析
const params = new URLSearchParams(window.location.search);
const error = params.get('error');
const errorDescription = params.get('error_description');
const state = params.get('state');

if (error) {
  // 校验 state 与发起授权时一致后，再展示错误
  if (error === 'access_denied') {
    showMessage('您已取消授权');
  } else {
    showMessage(errorDescription || error);
  }
  return;
}

const code = params.get('code');
if (!code) {
  showMessage('未收到授权码');
  return;
}
// 用 code + 保存的 code_verifier 换 token...
```

**Token 请求错误处理：**

```javascript
const res = await fetch(TOKEN_URL, { method: 'POST', body: formBody });
const data = await res.json().catch(() => ({}));

if (!res.ok) {
  switch (data.error) {
    case 'invalid_grant':
      // code 过期/已用/错误 → 引导用户重新授权
      redirectToAuthorize();
      break;
    case 'invalid_client':
      // client_id/client_secret 错误 → 检查配置，不要重试
      logError('OAuth client configuration error');
      break;
    default:
      showMessage(data.error_description || '登录失败，请重试');
  }
  return;
}
```

### 13.8 移动端（iOS/Android）PKCE 说明

- **授权：** 使用 WebView 或 ASWebAuthenticationSession（iOS）/ Custom Tabs（Android）打开授权 URL（带 code_challenge、state）；拦截回调 URL 获取 code、state。
- **code_verifier：** 在 App 内安全存储（Keychain/Keystore），换 token 时在**后端**或**本机**用 code_verifier 请求 /token（若在本机请求，需确保 HTTPS 且不暴露 client_secret；公开客户端不传 client_secret，必传 code_verifier）。
- **state：** 发起授权前生成并保存，回调时校验一致，防 CSRF。

---

## 14. 合规性说明

### 14.1 数据处理（含 GDPR）

- **法律依据：** 用户点击「同意」授权第三方应用获取其数据，构成合同履行与同意（Consent）；授权范围由 scope 限定。
- **数据最小化：** 仅返回授权 scope 对应的 claims（如 profile、email）；不向 RP 提供密码或未授权字段。
- **用户权利：** 用户可在 Link²Ur 账号设置中查看「已授权的第三方应用」，并撤销对某客户端的授权（需实现「撤销同意」接口或数据表，使该 client 的 refresh_token 失效、不再签发新 token）。

### 14.2 用户数据删除

- **用户注销 Link²Ur 账号时：** 应使该用户对所有 OAuth 客户端的 refresh_token、未过期的授权关系失效（删除或标记）；已签发的 access_token 在过期前仍可能被 RP 使用，无法逐个召回，依赖短期过期。
- **RP 请求删除用户数据：** 若 RP 提供「删除我的数据」能力，应由 RP 删除其系统内基于 sub 存储的数据；Link²Ur 侧可提供「撤销该客户端对当前用户的授权」，停止后续数据共享。

### 14.3 数据跨境

- 若 Link²Ur 与 RP 位于不同法域，应在隐私政策与同意页中说明数据可能传输至境外；RP 作为数据控制者或处理者，需自行满足当地合规要求。

---

## 15. API 版本策略

| 项目 | 说明 |
|------|------|
| **当前版本** | v1 |
| **版本管理** | URL 路径包含版本，如 `/api/oauth/authorize`（当前即 v1）；未来若有破坏性变更可引入 `/api/v2/oauth/authorize`。 |
| **废弃策略** | 旧版本至少保留 6 个月；在 .well-known 或文档中标注 deprecated 与替代端点。 |
| **变更通知** | 提前 30 天通知合作方（邮件/开发者站）；非破坏性变更（如新增 scope、新增可选参数）可仅文档更新。 |

---

## 16. 参考

- [RFC 6749 – The OAuth 2.0 Authorization Framework](https://datatracker.ietf.org/doc/html/rfc6749)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [RFC 7636 – Proof Key for Code Exchange (PKCE)](https://datatracker.ietf.org/doc/html/rfc7636)
- [OAuth 2.0 Security BCP](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)（安全实践）

---

**文档版本：** 3.0（优化版）  
**最后更新：** 2026-02  
**变更说明：** 增加错误响应统一格式与降级、索引与数据保留策略、性能优化、监控与灾难恢复、合规性、API 版本策略、Node.js/错误处理/移动端示例。
