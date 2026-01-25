# 项目潜在问题检查报告

**检查时间**: 2025-01-25  
**范围**: 后端、前端、iOS、配置与安全  
**本次复核**: 2025-01-25（对照代码与运行状态做增量更新）

---

## 一、自上次报告以来已改善项

- **Stripe / 图片密钥**：`main.py` 启动时在生产环境已校验 `STRIPE_SECRET_KEY`、`IMAGE_ACCESS_SECRET`、`STRIPE_WEBHOOK_SECRET` 必配且禁止占位符；`image_system.py` 已无 `IMAGE_ACCESS_SECRET` 默认值。
- **Debug 路由**：`/api/debug/*` 与 `POST /api/register/debug` 已加 `require_debug_environment()`，在 `ENVIRONMENT=production` 时返回 404。
- **CORS**：使用 `Config.ALLOWED_ORIGINS`，非 `["*"]`，与 `config.py` 中生产/开发域名配置一致。
- **`charge.dispute.created`**：已实现通知（poster、taker、管理员），不再仅是 `logger.warning`；是否冻结资金、工单等可按业务再扩展。

---

## 二、高优先级（建议尽快处理）

### 1. Debug 路由保护不完整

**位置**: `backend/app/routers.py`

- **`require_debug_environment()` 与 `Config.IS_PRODUCTION` 不一致**：  
  - 当前仅判断 `ENVIRONMENT == "production"`。  
  - `Config.IS_PRODUCTION` 还考虑 `RAILWAY_ENVIRONMENT`、`RAILWAY_PROJECT_ID`。  
  - 若部署在 Railway 且只设了 `RAILWAY_*`、未显式设 `ENVIRONMENT=production`，debug 路由仍可被访问。
- **`POST /api/register/test`**：无鉴权、未使用 `require_debug_environment`，可被随意调用于探测注册数据格式。

**建议**：

- 将 `require_debug_environment` 与 `Config.IS_PRODUCTION` 对齐（例如在“生产”判断上复用 `Config.IS_PRODUCTION` 或同一套环境变量逻辑）。
- 对 `POST /api/register/test` 加上 `Depends(require_debug_environment)`，或移除/迁移到仅开发可用的路由。

---

### 2. SECRET_KEY 未统一且未做生产校验

| 位置 | 默认值 | 说明 |
|------|--------|------|
| `config.Config.SECRET_KEY` | `"change-this-secret-key-in-production"` | 用于邮件 token、部分序列化 |
| `security.SECRET_KEY` | `"dev-secret-key-change-in-production"` | 用于 JWT 编解码 |

- 两处默认值不同，易混淆，且生产若漏配会静默使用弱密钥。
- `main.py` 的 startup 只校验 Stripe / 图片相关密钥，**未校验 `SECRET_KEY` 是否已配置且非占位符**。

**建议**：`SECRET_KEY` 统一从 `Config` 读取（或单一 `os.getenv` 源）；在生产启动时对 `SECRET_KEY` 做存在性与占位符检查，未通过则 `raise` 退出。

---

### 3. 生产代码中的 `print` 与 DEBUG 输出

以下文件中仍有 `print`，在生产会直接输出到 stdout，不利于日志等级与敏感信息控制：

- **`async_routers.py`**：大量 `print(f"DEBUG: ...")`（任务创建、申请、会话、评价等）。
- **`deps.py`**：`print(f"[DEBUG] 会话认证...")`、`print(f"[DEBUG] 移动端...")` 等。
- **`security.py`**：`print(f"[DEBUG] SyncCookieHTTPBearer...")`、Cookie/Header 等。
- **`database.py`**：`print("⚠️  asyncpg not available...")`、`print(f"Database health check failed: {e}")`。
- **`email_utils.py`**：`print(f"send_email...")`、`print("SMTP/Resend/SendGrid...")` 等。
- **`init_db.py`**：初始化流程的 `print`（若仅用于 CLI 可保留，但建议统一用 `logger`）。
- **`task_notifications.py`**：`print(f"DEBUG: 开始发送任务申请通知...")`。
- **`code_cleanup.py`**、**`security_logger.py`**：零散 `print`。

**建议**：统一改为 `logger.debug` / `logger.info` / `logger.warning`，用 `logging` 等级控制；生产默认 `INFO`，需要时再开 `DEBUG`。

---

## 三、中优先级（建议排期处理）

### 4. 争议流程的可选增强

- **`charge.dispute.created`**：已实现 poster、taker、管理员的站内通知；当前无冻结资金、工单、自动退款等。若业务需要，可在此基础上补全。

---

### 5. 后端单测：缺少 `db` fixture，测试全部失败

- **`backend/tests/`**：仅有 `test_task_recommendation.py`，且依赖 `db: Session` fixture。
- **无 `conftest.py`**：未定义 `db`，pytest 报错 `fixture 'db' not found`，**现有 9 个测试均 ERROR，无法运行**。
- **CI**：`main-ci.yml` 仅做 import、`compileall` 等校验，未执行 `pytest`，因此当前测试失败不会阻挡合并。
- 核心流程（注册、登录、支付、任务创建/完成、争议）仍缺乏自动化测试。

**建议**：

- 在 `backend/tests/conftest.py` 中提供 `db`（或 `session`）fixture，使用内存 SQLite 或 testcontainers 等，使 `test_task_recommendation.py` 可跑通。
- 为支付、认证、任务状态流转补充集成测试，并在 CI（如 `main-ci.yml`）中增加 `pytest` 步骤。

---

### 6. iOS 密钥与配置

- **`Constants.swift`**：Stripe `publishableKey`、`applePayMerchantIdentifier` 在 env 未配置时分别 fallback 到 `"pk_test_..."` / `"pk_live_..."` 和 `nil`。若生产构建未正确设 `STRIPE_PUBLISHABLE_KEY`、`APPLE_PAY_MERCHANT_ID`，支付/Apple Pay 会异常。
- **建议**：在 build/run 前做一次校验（脚本或 Xcode Run Script），Release 下未配置则报错，避免带着占位符上架。

---

### 7. 前端 API 与环境

- **`useAuth.ts`**：`REACT_APP_API_URL` 未设置时回退到 `http://localhost:8000`，仅开发合理；需确认 Vercel/生产构建时 `REACT_APP_API_URL` 已正确注入，避免生产打到本地。
- **`config.ts`**：`NODE_ENV === 'production'` 下使用 `api.link2ur.com`，逻辑合理；建议和 `useAuth` 统一从同一 `config` 读 API/WS，避免多处硬编码或 fallback 不一致。

---

## 四、低优先级 / 观察

### 8. 依赖与版本

- **`requirements.txt`**：`pytz>=2023.3` 与 `main.py` 注释“已移除 pytz，统一 zoneinfo”不一致；若已不用 pytz，可从 `requirements.txt` 移除，避免误用。
- 各包多为 `>=`，大版本升级可能引入破坏性变更，建议在测试环境定期 `pip list --outdated` 与 `pip-audit`，并在 CI 中跑。

---

### 9. 日志中的敏感信息

- 已有 `logging_filters.setup_sensitive_data_filter()`，方向正确。需确认 filter 覆盖：token、session_id、password、`client_secret`、`ephemeral_key_secret`、`device_token` 等，避免进入日志或监控。
- `APIService`、`MessageViewModel` 等有较多 `Logger.debug`，若线上开启 DEBUG，需评估是否包含用户/任务/支付相关 ID 或摘要，必要时对部分字段做脱敏。

---

### 10. 其它

- **CORS**：`main.py` 使用 `Config.ALLOWED_ORIGINS`，未使用 `["*"]`；生产/开发域名在 `config.py` 中分离配置，符合预期。
- **`.gitignore`**：`.env`、`.env.local`、`.env.*.local` 已忽略；需确保 CI/生产不使用提交进仓库的 `.env.example` 等作为实际 secret 来源。
- **SQL**：`crud.py` 中 `text()` 使用 `:task_id` 等绑定参数，未发现拼接用户输入的 raw SQL，目前看无明显 SQL 注入点；新增 raw SQL 时继续用参数化。

---

## 五、已做得较好的点

- 密码使用 `get_password_hash` / `verify_password`，未见明文存储。
- 会话与 CSRF 有专门路由与逻辑。
- 支付相关 Stripe 调用从 `os.getenv("STRIPE_SECRET_KEY")` 读取，未在代码中写死真实密钥；生产启动已校验 Stripe、`IMAGE_ACCESS_SECRET`、`STRIPE_WEBHOOK_SECRET`。
- Debug 路由已加 `require_debug_environment()`，在 `ENVIRONMENT=production` 时返回 404。
- 有 `PRE_LAUNCH_CHECKLIST.md`、`PAYMENT_*_AUDIT.md` 等文档，利于按项排查。
- 图片回退（活动/达人服务/跳蚤市场）和任务详情缓存失效策略已补齐；CORS 使用白名单，非 `["*"]`。

---

## 六、建议的修复顺序

1. **立即**：  
   - 将 `require_debug_environment` 与 `Config.IS_PRODUCTION` 对齐（或统一“生产”判定），避免 Railway 等场景下漏关 debug。  
   - 对 `POST /api/register/test` 加 `require_debug_environment` 或移出生产路由。

2. **短期**：  
   - 统一 `SECRET_KEY` 来源，并在 production 启动时校验 `SECRET_KEY` 已配置且非占位符。  
   - 将 `print` 改为 `logger`，并按 `DEBUG`/`INFO`/`WARNING` 区分。

3. **短期**：  
   - 在 `backend/tests/conftest.py` 提供 `db` fixture，使 `test_task_recommendation.py` 可运行；在 `main-ci.yml` 等 CI 中增加 `pytest` 步骤。

4. **中期**：  
   - 按业务需要增强 `charge.dispute.created`（如冻结资金、工单）；为支付、认证、任务等补充集成测试。

5. **持续**：  
   - 发布前跑一遍 `PRE_LAUNCH_CHECKLIST.md`，并结合本报告做增量检查。
