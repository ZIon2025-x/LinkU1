# 支付问题诊断指南

## 问题：支付成功后没有响应，Webhook 没有事件

### 诊断步骤

#### 1. 检查前端支付确认

在浏览器控制台查看以下日志：
- `✅ 支付成功，PaymentIntent ID: pi_xxx 状态: succeeded` - 支付确认成功
- `✅ 前端支付成功回调触发` - 成功回调被调用
- `📤 通知原页面支付成功` - 消息发送到原页面
- `📨 收到支付成功消息` - 原页面收到消息

#### 2. 检查 Webhook 接收

在服务器日志中查找：
- `🔔 Webhook 请求接收` - Webhook 被接收
- `✅ Received Stripe webhook event: payment_intent.succeeded` - Webhook 事件被处理
- `🔍 Webhook检查: is_pending_approval=True` - 检查待确认批准
- `✅ 支付成功，申请 xxx 已批准` - 申请被批准
- `✅ Task xxx payment completed` - 任务状态更新

#### 3. 检查支付状态轮询

在浏览器控制台查看：
- `🔄 轮询支付状态 (1/10)` - 开始轮询
- `📊 支付状态响应: { is_paid: true, status: 'succeeded' }` - 支付状态

### 常见问题

#### 问题 1: 前端显示支付成功，但 Webhook 没有事件

**可能原因**:
1. 支付实际上没有完成（状态可能是 `processing`）
2. Webhook 端点配置错误
3. Webhook 签名验证失败

**解决方法**:
1. 检查浏览器控制台，查看 PaymentIntent 的实际状态
2. 检查 Stripe Dashboard → Webhooks，确认端点 URL 正确
3. 检查环境变量 `STRIPE_WEBHOOK_SECRET` 是否正确配置
4. 查看服务器日志，确认是否有签名验证错误

#### 问题 2: Webhook 被接收，但任务状态没有更新

**可能原因**:
1. 元数据中缺少 `pending_approval` 或 `application_id`
2. 申请状态不是 `pending`
3. 数据库提交失败

**解决方法**:
1. 查看服务器日志中的 `🔍 Webhook检查` 日志
2. 确认 `is_pending_approval=True` 和 `application_id` 存在
3. 检查 `🔍 找到申请` 日志，确认申请被找到
4. 查看是否有数据库错误日志

#### 问题 3: 支付成功消息发送，但原页面没有响应

**可能原因**:
1. `window.opener` 为 `null`（窗口已关闭）
2. 消息监听器未正确设置
3. 消息验证失败

**解决方法**:
1. 检查浏览器控制台的 `📨 收到支付成功消息` 日志
2. 确认 `event.data?.type === 'payment_success'` 和 `event.data?.taskId === activeTaskId`
3. 检查 `window.opener` 是否存在

### 测试步骤

1. **打开浏览器开发者工具** (F12)
2. **切换到 Console 标签**
3. **完成一次支付**
4. **观察日志输出**:
   - 前端支付确认日志
   - 支付成功消息日志
   - 轮询状态日志
5. **检查服务器日志**:
   - Webhook 接收日志
   - 支付处理日志
   - 申请批准日志

### 手动测试 Webhook

如果 Webhook 没有自动触发，可以手动测试：

1. **使用 Stripe Dashboard**:
   - 登录 Stripe Dashboard
   - 进入 Developers → Webhooks
   - 找到你的 webhook 端点
   - 点击 "Send test webhook"
   - 选择 `payment_intent.succeeded` 事件
   - 点击 "Send test webhook"

2. **使用 Stripe CLI**:
   ```bash
   stripe trigger payment_intent.succeeded
   ```

3. **检查服务器日志**:
   - 确认 Webhook 被接收
   - 确认事件被处理
   - 确认任务状态被更新

### 环境变量检查

确保以下环境变量已正确配置：

```bash
STRIPE_SECRET_KEY=sk_test_... 或 sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_CONNECT_WEBHOOK_SECRET=whsec_... (可选，但推荐)
```

### 联系支持

如果问题仍然存在，请提供：
1. 浏览器控制台日志（完整）
2. 服务器日志（包含 Webhook 相关日志）
3. PaymentIntent ID
4. Task ID
5. Application ID

