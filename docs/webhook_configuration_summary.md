# Webhook 配置总结

## 当前架构：托管模式（Escrow）

你的系统使用**托管模式**，资金流程：
1. 客户支付 → 平台账户（主账户）
2. 任务完成 → 平台转账给服务者（Connect 账户）

## Webhook 端点配置

### 1. 主账户 Webhook（必需）✅

**端点 URL**: `https://api.link2ur.com/api/stripe/webhook`  
**事件来源**: **"Account"**（主账户）  
**路由**: `backend/app/routers.py` → `stripe_webhook()`  
**环境变量**: `STRIPE_WEBHOOK_SECRET`

**订阅的事件**：
- ✅ `payment_intent.succeeded` - 支付成功（**最重要**）
- ✅ `payment_intent.payment_failed` - 支付失败
- ✅ `payment_intent.requires_action` - 需要额外操作（如 3D Secure）
- ✅ `charge.refunded` - 退款
- ✅ `charge.dispute.created` - 争议创建

**处理的业务逻辑**：
- 更新任务支付状态（`is_paid = 1`）
- 批准申请（如果 `pending_approval = true`）
- 更新任务状态为 `in_progress`
- 设置任务接受者（`taker_id`）
- 拒绝其他申请
- 发送通知

### 2. Connect Webhook（可选，但推荐）✅

**端点 URL**: `https://api.link2ur.com/api/stripe/connect/webhook`  
**事件来源**: **"Connect 子账户"**  
**路由**: `backend/app/stripe_connect_routes.py` → `connect_webhook()`  
**环境变量**: `STRIPE_CONNECT_WEBHOOK_SECRET`（如果未设置，回退到 `STRIPE_WEBHOOK_SECRET`）

**订阅的事件**：
- ✅ `account.created` / `v2.core.account.created` - 账户创建
- ✅ `account.updated` / `v2.core.account.updated` - 账户更新
- ✅ `v2.core.account.*` - V2 API 账户相关事件

**处理的业务逻辑**：
- 更新用户 `stripe_account_id`
- 同步账户状态（`charges_enabled`, `payouts_enabled` 等）
- 处理账户验证状态

**❌ 不需要订阅支付事件**：
- `payment_intent.*` - **不需要**（在主账户 webhook 处理）
- `charge.*` - **不需要**（在主账户 webhook 处理）

## 为什么 Connect Webhook 不需要支付事件？

### 托管模式（当前实现）

```
客户支付 → 平台账户（主账户） → Webhook 发送到主账户端点
         ↓
任务完成 → Transfer.create → Connect 账户
```

- PaymentIntent 在主账户创建
- 支付事件发送到主账户 webhook
- Connect webhook 只接收账户管理事件

### Direct Charges 模式（如果将来改用）

```
客户支付 → Connect 账户（直接） → Webhook 发送到 Connect 端点
         ↓
平台抽成 → application_fee_amount
```

- PaymentIntent 在 Connect 账户创建（使用 `on_behalf_of`）
- 支付事件发送到 Connect webhook
- **需要**在 Connect webhook 中处理支付事件

## 配置检查清单

### 主账户 Webhook（必需）

- [ ] 端点 URL: `https://api.link2ur.com/api/stripe/webhook`
- [ ] 事件来源: **"Account"**（不是 "Connect 子账户"）
- [ ] 已订阅: `payment_intent.succeeded`
- [ ] 环境变量: `STRIPE_WEBHOOK_SECRET` 已配置
- [ ] 签名密钥: 从主账户 webhook 端点获取

### Connect Webhook（推荐）

- [ ] 端点 URL: `https://api.link2ur.com/api/stripe/connect/webhook`
- [ ] 事件来源: **"Connect 子账户"**
- [ ] 已订阅: `account.*` 或 `v2.core.account.*`
- [ ] **未订阅**: `payment_intent.*`（不需要）
- [ ] 环境变量: `STRIPE_CONNECT_WEBHOOK_SECRET` 已配置（可选，会回退到 `STRIPE_WEBHOOK_SECRET`）

## 常见错误

### ❌ 错误 1：在主账户 webhook 中订阅 Connect 账户事件

**问题**: 主账户 webhook 的事件来源是 "Connect 子账户"  
**结果**: 收不到 `payment_intent.succeeded` 事件  
**解决**: 创建事件来源为 "Account" 的主账户 webhook

### ❌ 错误 2：在 Connect webhook 中订阅支付事件

**问题**: Connect webhook 订阅了 `payment_intent.succeeded`  
**结果**: 收不到事件（因为 PaymentIntent 在主账户创建）  
**解决**: 只在主账户 webhook 中订阅支付事件

### ✅ 正确配置

- **主账户 webhook**: 事件来源 "Account"，订阅支付事件
- **Connect webhook**: 事件来源 "Connect 子账户"，只订阅账户事件

## 测试验证

### 测试主账户 Webhook

```bash
# 使用 Stripe CLI
stripe listen --forward-to https://api.link2ur.com/api/stripe/webhook

# 触发支付事件
stripe trigger payment_intent.succeeded
```

### 测试 Connect Webhook

```bash
# 使用 Stripe CLI
stripe listen --forward-to https://api.link2ur.com/api/stripe/connect/webhook

# 触发账户事件
stripe trigger account.updated
```

## 总结

**当前配置**：
- ✅ 主账户 webhook：处理所有支付事件
- ✅ Connect webhook：只处理账户管理事件
- ❌ Connect webhook：**不需要**订阅支付事件

**原因**：使用托管模式，PaymentIntent 在主账户创建，支付事件发送到主账户 webhook。

