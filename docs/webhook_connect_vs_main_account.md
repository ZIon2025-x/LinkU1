# Webhook 端点配置：主账户 vs Connect 账户

## 问题说明

你的当前 webhook 端点配置：
- **端点 URL**: `https://api.link2ur.com/api/stripe/webhook` ✅
- **事件来源**: "Connect 子账户" ⚠️ **这是问题所在！**
- **已订阅**: `payment_intent.succeeded` ✅

但是 `payment_intent.succeeded` 事件应该来自**主账户**，不是 Connect 子账户。

## 为什么会出现这个问题？

1. **PaymentIntent 在主账户创建**：
   - 代码中创建 PaymentIntent 时没有设置 `on_behalf_of`
   - 所以 PaymentIntent 是在主账户（平台账户）下创建的
   - 事件会发送到主账户的 webhook

2. **当前 webhook 端点配置错误**：
   - 你的 webhook 端点事件来源是 "Connect 子账户"
   - 这个端点只接收 Connect 账户相关的事件
   - `payment_intent.succeeded` 不会发送到这个端点

## 解决方案

### 方案 1：创建主账户的 Webhook 端点（推荐）

1. **登录 Stripe Dashboard**
   - https://dashboard.stripe.com
   - 切换到 **Test mode**（如果使用测试环境）

2. **创建新的 Webhook 端点**：
   - 进入 **Developers → Webhooks**
   - 点击 **"Add endpoint"**
   - **端点 URL**: `https://api.link2ur.com/api/stripe/webhook`
   - **事件来源**: 选择 **"Account"**（不是 "Connect 子账户"）
   - **订阅事件**: 
     - ✅ `payment_intent.succeeded`
     - ✅ `payment_intent.payment_failed`
     - ✅ 其他支付相关事件
   - 点击 **"Add endpoint"**

3. **复制 Signing Secret**：
   - 端点创建后，点击进入详情页
   - 找到 **"Signing secret"**
   - 点击 **"Reveal"** 按钮
   - 复制 `whsec_...` 密钥

4. **更新环境变量**：
   - 将 Signing secret 设置到 `STRIPE_WEBHOOK_SECRET`
   - 确保后端环境变量已更新

5. **验证配置**：
   - 端点详情页应该显示：
     - **事件来源**: "Account" ✅
     - **端点 URL**: `https://api.link2ur.com/api/stripe/webhook` ✅
     - **已订阅事件**: 包含 `payment_intent.succeeded` ✅

### 方案 2：保留两个 Webhook 端点（最佳实践）

如果你同时使用 Connect 和主账户支付，应该有两个 webhook 端点：

1. **主账户 Webhook**（支付相关）：
   - **端点 URL**: `https://api.link2ur.com/api/stripe/webhook`
   - **事件来源**: "Account"
   - **订阅事件**: `payment_intent.*`, `charge.*` 等
   - **环境变量**: `STRIPE_WEBHOOK_SECRET`

2. **Connect Webhook**（账户相关）：
   - **端点 URL**: `https://api.link2ur.com/api/stripe/connect/webhook`
   - **事件来源**: "Connect 子账户"
   - **订阅事件**: `account.*`, `v2.core.account.*` 等
   - **环境变量**: `STRIPE_CONNECT_WEBHOOK_SECRET`

## 如何区分主账户和 Connect 账户的 Webhook？

在 Stripe Dashboard → Webhooks 中：

- **主账户 Webhook**：
  - 事件来源显示为 **"Account"**
  - 接收主账户下的所有事件（支付、客户等）

- **Connect Webhook**：
  - 事件来源显示为 **"Connect 子账户"**
  - 只接收 Connect 账户相关的事件（账户创建、更新等）

## 当前事件信息

从你提供的事件数据看：
- **Payment Intent ID**: `pi_3SlX8W8JTHo8Clga1wQXDcrY`
- **Metadata**: 包含 `taker_stripe_account_id`（Connect 账户 ID）
- **但 PaymentIntent 本身是在主账户创建的**

所以事件应该发送到**主账户的 webhook**，不是 Connect webhook。

## 立即行动

1. **检查现有端点**：
   - 查看 `https://api.link2ur.com/api/stripe/webhook` 的事件来源
   - 如果是 "Connect 子账户"，需要创建新的主账户端点

2. **创建主账户端点**（如果不存在）：
   - 事件来源选择 **"Account"**
   - 订阅 `payment_intent.succeeded`

3. **手动重放事件**：
   - 在 Stripe Dashboard → Events
   - 找到事件 `evt_3SlX8W8JTHo8Clga1HHDUnra`
   - 重放到**主账户的 webhook 端点**

4. **验证修复**：
   - 进行一次新的测试支付
   - 检查服务器日志是否收到 webhook
   - 确认任务状态自动更新

## 常见问题

**Q: 为什么会有两个不同的 webhook 端点？**

A: Stripe 区分主账户事件和 Connect 账户事件：
- 主账户事件：支付、客户、订阅等
- Connect 账户事件：账户创建、更新、验证等

**Q: 可以共用一个 webhook 端点吗？**

A: 技术上可以，但不推荐。因为：
- 需要处理两种不同来源的事件
- 签名验证可能不同
- 代码逻辑更复杂

**Q: 如何知道事件应该发送到哪个端点？**

A: 查看事件详情：
- 如果事件对象是 `payment_intent`、`charge` 等 → 主账户 webhook
- 如果事件对象是 `account`、`v2.core.account` 等 → Connect webhook

