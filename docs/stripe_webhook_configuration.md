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

### 测试支付 Webhook
```bash
# 使用 Stripe CLI 测试
stripe listen --forward-to https://api.link2ur.com/api/stripe/webhook
stripe trigger payment_intent.succeeded
```

### 测试 Connect Webhook
```bash
# 使用 Stripe CLI 测试
stripe listen --forward-to https://api.link2ur.com/api/stripe/connect/webhook
stripe trigger account.updated
```

