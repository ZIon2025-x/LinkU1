# Stripe Webhook 配置说明

## Webhook 端点配置

### 1. 支付相关 Webhook
- **端点路径**: `/api/stripe/webhook`
- **完整 URL**: `https://api.link2ur.com/api/stripe/webhook`
- **环境变量**: `STRIPE_WEBHOOK_SECRET`
- **处理的事件**: 
  - `payment_intent.succeeded` - 支付成功
  - `payment_intent.payment_failed` - 支付失败
  - `charge.*` - 支付相关事件
  - 其他支付相关事件

### 2. 账户相关 Webhook (Stripe Connect)
- **端点路径**: `/api/stripe/connect/webhook`
- **完整 URL**: `https://api.link2ur.com/api/stripe/connect/webhook`
- **环境变量**: `STRIPE_CONNECT_WEBHOOK_SECRET` (如果未设置，会回退到 `STRIPE_WEBHOOK_SECRET`)
- **处理的事件**:
  - `account.created` / `v2.core.account.created` - 账户创建
  - `account.updated` / `v2.core.account.updated` - 账户更新
  - `v2.core.account.*` - V2 API 账户相关事件
  - 其他 Stripe Connect 账户相关事件

## 环境变量配置

### 必需的环境变量

1. **STRIPE_WEBHOOK_SECRET**
   - 用于验证支付相关 webhook 的签名
   - 从 Stripe Dashboard → Developers → Webhooks → 支付 webhook 端点获取
   - 格式: `whsec_...`

2. **STRIPE_CONNECT_WEBHOOK_SECRET** (推荐)
   - 用于验证 Stripe Connect 账户相关 webhook 的签名
   - 从 Stripe Dashboard → Developers → Webhooks → Connect webhook 端点获取
   - 格式: `whsec_...`
   - 如果未设置，会回退到 `STRIPE_WEBHOOK_SECRET`（向后兼容）

## 代码实现位置

### 支付 Webhook
- **文件**: `backend/app/routers.py`
- **函数**: `stripe_webhook()`
- **路由**: `@router.post("/stripe/webhook")`
- **注册**: `app.include_router(main_router, prefix="/api")`
- **完整路径**: `/api/stripe/webhook`

### Connect Webhook
- **文件**: `backend/app/stripe_connect_routes.py`
- **函数**: `connect_webhook()`
- **路由**: `@router.post("/webhook")`
- **注册**: `router = APIRouter(prefix="/api/stripe/connect")`
- **完整路径**: `/api/stripe/connect/webhook`

## 验证配置

### 检查环境变量
确保以下环境变量已正确设置：
```bash
STRIPE_WEBHOOK_SECRET=whsec_...          # 支付 webhook 签名密钥
STRIPE_CONNECT_WEBHOOK_SECRET=whsec_...  # Connect webhook 签名密钥（推荐）
```

### 在 Stripe Dashboard 中配置

1. **支付 Webhook**:
   - 登录 Stripe Dashboard
   - 进入 Developers → Webhooks
   - 找到或创建支付 webhook 端点: `https://api.link2ur.com/api/stripe/webhook`
   - 复制签名密钥到 `STRIPE_WEBHOOK_SECRET`

2. **Connect Webhook**:
   - 在同一个 Webhooks 页面
   - 找到或创建 Connect webhook 端点: `https://api.link2ur.com/api/stripe/connect/webhook`
   - 复制签名密钥到 `STRIPE_CONNECT_WEBHOOK_SECRET`

## 注意事项

1. **两个不同的签名密钥**: 
   - 支付 webhook 和 Connect webhook 使用不同的签名密钥
   - 必须分别从对应的 webhook 端点获取

2. **向后兼容**:
   - 如果 `STRIPE_CONNECT_WEBHOOK_SECRET` 未设置，Connect webhook 会回退到使用 `STRIPE_WEBHOOK_SECRET`
   - 但为了安全，建议分别设置两个密钥

3. **事件订阅**:
   - 确保在 Stripe Dashboard 中为每个 webhook 端点订阅了正确的事件
   - 支付 webhook 需要订阅支付相关事件
   - Connect webhook 需要订阅账户相关事件

## 测试

### 使用 Stripe CLI 测试 Webhook

#### 方法 1: 监听并转发到服务器（推荐用于生产测试）

```bash
# 1. 启动监听并转发到支付 webhook
stripe listen --forward-to https://api.link2ur.com/api/stripe/webhook

# 2. 在另一个终端触发测试事件
stripe trigger payment_intent.succeeded
```

**注意**: 如果 `--forward-to` 参数不工作，可能是 Stripe CLI 版本问题。请尝试：
- 更新 Stripe CLI: `brew upgrade stripe/stripe-cli/stripe` (macOS) 或查看 [Stripe CLI 文档](https://stripe.com/docs/stripe-cli)
- 或者使用方法 2（仅监听，不转发）

#### 方法 2: 仅监听事件（用于查看事件详情）

```bash
# 1. 启动监听（不转发，仅显示事件）
stripe listen

# 2. 在另一个终端触发测试事件
stripe trigger payment_intent.succeeded
```

监听器会显示接收到的所有事件，你可以：
- 查看事件 ID
- 复制事件数据用于测试
- 手动在 Stripe Dashboard 中重放事件

#### 方法 2.1: 创建包含正确 metadata 的测试事件

**重要**: 默认的 `stripe trigger payment_intent.succeeded` 创建的测试事件**不包含**我们代码需要的 metadata（如 `task_id`, `application_id` 等），因此不会触发业务逻辑。

要创建包含正确 metadata 的测试事件，你需要：

1. **先创建一个包含 metadata 的 PaymentIntent**（通过 API 或使用实际的任务支付流程）
2. **然后确认该 PaymentIntent**（通过 Stripe Dashboard 或 API）

或者，你可以使用以下方法创建测试事件：

```bash
# 方法 A: 使用 Stripe CLI 创建包含 metadata 的 PaymentIntent，然后确认它
# 1. 创建 PaymentIntent（包含 metadata）
stripe payment_intents create \
  --amount=2000 \
  --currency=gbp \
  --metadata[task_id]=127 \
  --metadata[application_id]=39 \
  --metadata[pending_approval]=true \
  --metadata[application_fee]=200

# 2. 确认该 PaymentIntent（这会触发 payment_intent.succeeded 事件）
stripe payment_intents confirm <payment_intent_id> \
  --payment-method=pm_card_visa
```

**注意**: 使用实际的任务 ID 和申请 ID 进行测试，确保：
- `task_id` 对应数据库中存在的任务
- `application_id` 对应该任务的待处理申请
- `pending_approval=true` 表示这是批准申请时的支付

#### 方法 3: 使用 Stripe Dashboard 测试

1. 登录 Stripe Dashboard
2. 进入 Developers → Webhooks
3. 找到你的 webhook 端点
4. 点击 "Send test webhook"
5. 选择要测试的事件类型（如 `payment_intent.succeeded`）
6. 点击 "Send test webhook"

### 测试 Connect Webhook

```bash
# 监听并转发到 Connect webhook
stripe listen --forward-to https://api.link2ur.com/api/stripe/connect/webhook

# 在另一个终端触发测试事件
stripe trigger account.updated
```

### 查看 Webhook 日志

在服务器日志中查找以下信息：
- `Received Stripe webhook event: payment_intent.succeeded`
- `✅ 支付成功，申请 xxx 已批准`
- `✅ Task xxx payment completed via Stripe Payment Intent, status updated to in_progress`

### 常见问题

**Q: `--forward-to` 参数不工作？**
A: 
- 确保 Stripe CLI 已更新到最新版本
- 检查是否需要先登录: `stripe login`
- 尝试使用 `stripe listen` 仅监听事件，然后手动在 Dashboard 中重放

**Q: 如何查看 webhook 事件详情？**
A: 使用 `stripe events retrieve <event_id>` 查看特定事件的详细信息

**Q: 如何测试特定的事件？**
A: 使用 `stripe trigger <event_type>` 触发测试事件，例如：
- `stripe trigger payment_intent.succeeded`
- `stripe trigger payment_intent.payment_failed`
- `stripe trigger account.updated`

