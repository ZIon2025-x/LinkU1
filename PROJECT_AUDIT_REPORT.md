# 项目潜在问题检查报告

**检查时间**: 2025-01-25  
**范围**: 后端、前端、iOS、配置与安全

---

## 高优先级（建议尽快处理）

### 1. 调试接口在生产环境完全暴露

**位置**: `backend/app/routers.py`

以下接口**无鉴权、无环境判断**，挂载在 `/api` 下，生产环境可直接访问：

| 路径 | 风险 |
|------|------|
| `POST /api/register/debug` | 回显请求体，可被用来探测接口 |
| `GET /api/debug/test-token/{token}` | 泄露 `Config.SECRET_KEY` 长度、是否默认值，并可解析 token |
| `GET /api/debug/simple-test` | 简单存活探测 |
| `POST /api/debug/fix-avatar-null` | **直接修改 DB**：把所有 `avatar IS NULL` 的用户改为 `/static/avatar1.png`，可被滥用 |
| `GET /api/debug/check-user-avatar/{user_id}` | 按 user_id 查用户头像等数据，信息泄露 |
| `GET /api/debug/test-reviews/{user_id}` | 按 user_id 探测 |
| `GET /api/debug/session-status` | 返回 **cookies、headers、session 校验结果**，敏感信息泄露 |
| `GET /api/debug/check-pending/{email}` | 按邮箱查 PendingUser、User，**隐私泄露** |
| `GET /api/debug/test-confirm-simple` | 存活探测 |

**建议**（任选一种或组合）：

- **方案 A**：生产彻底关闭：用 `if os.getenv("ENVIRONMENT") != "production":` 包一层，仅在开发/测试注册这些路由；或把这批路由移到单独 `debug_router`，只在非 production 时 `include_router(debug_router, prefix="/api/debug")`。
- **方案 B**：若必须保留，加上管理员鉴权，例如 `Depends(get_current_admin)`，并限制可访问的 path。

---

### 2. 默认密钥与占位符

| 位置 | 代码 | 说明 |
|------|------|------|
| `routers.py` | `os.getenv("STRIPE_SECRET_KEY", "sk_test_placeholder_replace_with_real_key")` | 未配置时用占位符，支付会失败，但占位符写死在代码里，建议无默认值，启动时校验并快速失败 |
| `image_system.py` | `os.getenv("IMAGE_ACCESS_SECRET", "your-image-secret-key-change-in-production")` | 未配置时使用固定默认密钥，**若生产漏配则所有人可用同一密钥访问私密图**，建议去掉默认或启动校验 |
| `routers.py` | `os.getenv("STRIPE_WEBHOOK_SECRET", "whsec_...yourkey...")` | 未配置时用占位，Webhook 校验会失败；生产应必配，并避免占位符进仓库 |

**建议**：对 `STRIPE_SECRET_KEY`、`STRIPE_WEBHOOK_SECRET`、`IMAGE_ACCESS_SECRET` 等，在 `main.py` 的 `startup` 中做存在性检查，`ENVIRONMENT=production` 时未配置则直接 `raise` 并退出，避免静默用占位符。

---

### 3. 生产代码中的 `print` 与 DEBUG 输出

这些在**生产也会执行**，会打满日志、混入敏感信息：

- **`backend/app/async_crud.py`**：约 20+ 处 `print(f"DEBUG: ...")`（申请任务、批准申请等）。
- **`backend/app/crud.py`**：`print(f"DEBUG: ...")`、`print(f"🔍 [DEBUG] ...")`、`print(f"清除缓存失败: ...")`、`print(f"检测到重复消息...)`、`print(f"Failed to create upgrade notification: ...")` 等。
- **`backend/app/routers.py`**：`print("开发环境：跳过邮件验证...")`、`print("生产环境：需要邮箱验证")`、`print(f"Failed to create notification: ...")`、`print(f"邀请人ID验证成功: ...")` 等。
- **`backend/app/models.py`**：`print("在线时间获取已禁用...")`、`print(f"尝试使用 {api['name']} 获取英国时间...")` 等。

**建议**：统一改为 `logger.debug` / `logger.info` / `logger.warning`，并通过 `logging` 等级控制；生产默认 `INFO`，需要时再开 `DEBUG`。`PRE_LAUNCH_CHECKLIST.md` 中“移除所有 print() 调试语句”建议落实。

---

## 中优先级（建议排期处理）

### 4. 未实现的业务逻辑

- **`routers.py` 约 5254 行**：`charge.dispute.created` 的 TODO：
  ```python
  # TODO: 处理争议逻辑，可能需要冻结资金、通知用户等
  ```
  Stripe 争议创建后仅有 `logger.warning`，无冻结、通知、工单等，需按业务补全。

---

### 5. 后端单测覆盖不足

- `backend/tests/` 下仅 `test_task_recommendation.py`，核心流程（注册、登录、支付、任务创建/完成、争议）缺乏自动化测试，回归成本高。

**建议**：至少为支付、认证、任务状态流转写集成测试；CI 中强制跑测试再部署。

---

### 6. iOS 密钥与配置

- **`Constants.swift`**：Stripe `publishableKey`、`applePayMerchantIdentifier` 在 env 未配置时分别 fallback 到 `"pk_test_..."` / `"pk_live_..."` 和 `nil`。若生产构建未正确设 `STRIPE_PUBLISHABLE_KEY`、`APPLE_PAY_MERCHANT_ID`，支付/Apple Pay 会异常。
- **建议**：在 build/run 前做一次校验（脚本或 Xcode Run Script），Release 下未配置则报错，避免带着占位符上架。

---

### 7. 前端 API 与环境

- **`useAuth.ts`**：`REACT_APP_API_URL` 未设置时回退到 `http://localhost:8000`，仅开发合理；需确认 Vercel/生产构建时 `REACT_APP_API_URL` 已正确注入，避免生产打到本地。
- **`config.ts`**：`NODE_ENV === 'production'` 下使用 `api.link2ur.com`，逻辑合理；建议和 `useAuth` 统一从同一 `config` 读 API/WS，避免多处硬编码或 fallback 不一致。

---

## 低优先级 / 观察

### 8. 依赖与版本

- **`requirements.txt`**：`pytz>=2023.3` 与项目内“已移除 pytz，统一 zoneinfo”的注释并存，若已不用 pytz，可考虑从依赖中移除，避免误用。
- 各包多为 `>=`，大版本升级可能引入破坏性变更，建议在测试环境定期 `pip list --outdated` 与 `pip-audit`，并在 CI 中跑。

---

### 9. 日志中的敏感信息

- 已有 `logging_filters.setup_sensitive_data_filter()`，方向正确。需确认 filter 覆盖：token、session_id、password、`client_secret`、`ephemeral_key_secret`、`device_token` 等，避免进入日志或监控。
- `APIService`、`MessageViewModel` 等有较多 `Logger.debug`，若线上开启 DEBUG，需评估是否包含用户/任务/支付相关 ID 或摘要，必要时对部分字段做脱敏。

---

### 10. 其它

- **CORS**：`main.py` 使用 `CORSMiddleware`，需确认生产 `allow_origins` 未使用 `["*"]`，且与前端/移动端实际域名一致。
- **`.gitignore`**：`.env`、`.env.local`、`.env.*.local` 已忽略，符合常见做法；需确保 CI/生产不使用提交进仓库的 `.env.example` 等作为实际 secret 来源。
- **SQL**：`crud.py` 中 `text()` 使用 `:task_id` 等绑定参数，未发现拼接用户输入的 raw SQL，目前看无明显 SQL 注入点；新增 raw SQL 时继续用参数化。

---

## 已做得较好的点

- 密码使用 `get_password_hash` / `verify_password`，未见明文存储。
- 会话与 CSRF 有专门路由与逻辑。
- 支付相关 Stripe 调用多从 `os.getenv("STRIPE_SECRET_KEY")` 读取，未在代码中写死真实密钥。
- 有 `PRE_LAUNCH_CHECKLIST.md`、`PAYMENT_*_AUDIT.md` 等文档，利于按项排查。
- 图片回退（活动/达人服务/跳蚤市场）和任务详情缓存失效策略已补齐，逻辑清晰。

---

## 建议的修复顺序

1. **立即**：用环境判断或鉴权**关闭或严格限制** `/api/debug/*` 和 `/api/register/debug` 在生产环境的访问。
2. **短期**：去掉 `IMAGE_ACCESS_SECRET`、`STRIPE_SECRET_KEY`、`STRIPE_WEBHOOK_SECRET` 的危险默认值，并在 production 启动时做必配校验。
3. **短期**：将 `print` 换成 `logger`，并区分 `DEBUG`/`INFO`/`WARNING`。
4. **中期**：实现 `charge.dispute.created` 的争议处理流程；为支付、认证、任务等补充测试。
5. **持续**：在发布前跑一遍 `PRE_LAUNCH_CHECKLIST.md`，并结合本报告做增量检查。

如需，我可以按上述顺序给出具体修改示例（例如如何用环境判断包裹 debug 路由、启动时校验环境变量、以及把 `print` 改成 `logger` 的 diff）。
