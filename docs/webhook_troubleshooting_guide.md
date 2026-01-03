# Webhook 未收到问题诊断指南

## 🔍 问题：支付成功但没有收到 Webhook

如果支付成功了，但后端没有收到 webhook，请按以下步骤排查：

## 第一步：检查 Stripe Dashboard 中的 Webhook 配置

### 1.1 检查 Webhook 端点是否存在

1. 登录 [Stripe Dashboard](https://dashboard.stripe.com)
2. 进入 **Developers → Webhooks**
3. 查找端点：`https://api.link2ur.com/api/stripe/webhook`
4. 如果不存在，需要创建它

### 1.2 检查 Webhook 端点状态

在 Webhook 端点详情页，检查：
- ✅ **状态**：应该是 "Enabled"（已启用）
- ✅ **URL**：应该是 `https://api.link2ur.com/api/stripe/webhook`（注意是 `/api/stripe/webhook`，不是 `/api/users/stripe/webhook`）
- ✅ **事件订阅**：必须包含 `payment_intent.succeeded` 事件

### 1.3 检查 Webhook 事件日志

在 Stripe Dashboard 的 Webhook 详情页：
1. 点击 **"Events"** 标签
2. 查看最近的 webhook 事件
3. 检查是否有失败的请求（红色标记）
4. 点击失败的事件，查看错误详情：
   - **HTTP 状态码**：应该是 200
   - **错误信息**：查看具体错误原因

### 1.4 检查签名密钥

1. 在 Webhook 端点详情页
2. 找到 **"Signing secret"** 部分
3. 点击 **"Reveal"** 按钮
4. 复制 `whsec_...` 密钥
5. 确认后端环境变量 `STRIPE_WEBHOOK_SECRET` 的值与此一致

## 第二步：检查后端配置

### 2.1 检查环境变量

确认后端环境变量已正确设置：

```bash
# 检查环境变量
echo $STRIPE_WEBHOOK_SECRET

# 应该输出类似：whsec_xxxxxxxxxxxxx
# 不应该输出：whsec_...yourkey... 或空值
```

### 2.2 检查 Webhook 路由注册

Webhook 路由应该注册在：
- **文件**：`backend/app/routers.py`
- **路由**：`@router.post("/stripe/webhook")`
- **注册**：`app.include_router(main_router, prefix="/api")`
- **完整路径**：`/api/stripe/webhook`

### 2.3 检查服务器日志

查看服务器日志，查找以下信息：

#### 如果 Webhook 被接收：
```
🔔 [WEBHOOK] 收到 Stripe Webhook 请求
✅ [WEBHOOK] 事件验证成功（签名已验证）
📦 [WEBHOOK] 事件详情:
  - 事件类型: payment_intent.succeeded
```

#### 如果 Webhook 签名验证失败：
```
❌ [WEBHOOK] 安全错误：签名验证失败
```

#### 如果 Webhook Secret 未配置：
```
❌ [WEBHOOK] 安全错误：Webhook Secret 未正确配置
```

#### 如果没有收到任何日志：
- Webhook 可能根本没有到达服务器
- 检查防火墙、负载均衡器、反向代理配置

## 第三步：检查网络和服务器配置

### 3.1 检查 Webhook 端点是否可访问

使用 curl 测试端点是否可访问：

```bash
# 测试端点是否可访问（应该返回 400，因为没有签名）
curl -X POST https://api.link2ur.com/api/stripe/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# 如果返回 400 或 500，说明端点可访问
# 如果返回连接错误，说明端点不可访问
```

### 3.2 检查防火墙和负载均衡器

确保以下配置正确：
- ✅ 防火墙允许来自 Stripe IP 的请求
- ✅ 负载均衡器/反向代理正确转发请求
- ✅ SSL/TLS 证书有效
- ✅ 服务器可以接收 POST 请求

### 3.3 检查 Stripe IP 白名单（如果使用）

如果服务器有 IP 白名单，需要添加 Stripe 的 IP 地址：
- Stripe Webhook IP 地址列表：https://stripe.com/docs/ips

## 第四步：使用 Stripe CLI 测试

### 4.1 安装 Stripe CLI

```bash
# macOS
brew install stripe/stripe-cli/stripe

# 或查看官方文档：https://stripe.com/docs/stripe-cli
```

### 4.2 登录 Stripe CLI

```bash
stripe login
```

### 4.3 监听并转发 Webhook

```bash
# 监听并转发到生产环境
stripe listen --forward-to https://api.link2ur.com/api/stripe/webhook

# 在另一个终端触发测试事件
stripe trigger payment_intent.succeeded
```

### 4.4 检查转发结果

如果转发成功，你应该看到：
- Stripe CLI 显示事件被转发
- 服务器日志显示收到 webhook
- 如果失败，会显示错误信息

## 第五步：检查测试环境 vs 生产环境

### 5.1 确认使用的 Stripe 模式

- **测试模式**：使用 `sk_test_...` 和 `pk_test_...`
- **生产模式**：使用 `sk_live_...` 和 `pk_live_...`

### 5.2 确认 Webhook Secret 匹配

- **测试模式**：Webhook Secret 应该是测试环境的 `whsec_...`
- **生产模式**：Webhook Secret 应该是生产环境的 `whsec_...`

⚠️ **重要**：测试环境和生产环境的 Webhook Secret **不同**，必须分别配置。

### 5.3 检查 Stripe Dashboard 模式

在 Stripe Dashboard 右上角，确认：
- 如果使用测试模式，切换到 **"Test mode"**
- 如果使用生产模式，切换到 **"Live mode"**
- 确保 Webhook 端点是在正确的模式下创建的

## 第六步：手动重放 Webhook 事件

如果之前的支付没有触发 webhook，可以手动重放：

1. 登录 Stripe Dashboard
2. 进入 **Developers → Events**
3. 找到对应的 `payment_intent.succeeded` 事件
4. 点击事件进入详情页
5. 点击 **"Send test webhook"** 或 **"Replay"** 按钮
6. 选择你的 webhook 端点
7. 点击发送

## 第七步：常见问题和解决方案

### 问题 1：Webhook 端点返回 500 错误

**可能原因**：
- Webhook Secret 配置错误
- 数据库连接问题
- 代码错误

**解决方法**：
1. 检查服务器日志，查看具体错误
2. 检查环境变量 `STRIPE_WEBHOOK_SECRET` 是否正确
3. 检查数据库连接是否正常

### 问题 2：Webhook 端点返回 400 错误（签名验证失败）

**可能原因**：
- Webhook Secret 不匹配
- 使用了错误的 Secret（测试/生产混淆）

**解决方法**：
1. 确认使用的是正确的 Webhook Secret
2. 确认测试/生产环境匹配
3. 在 Stripe Dashboard 中重新获取 Signing secret

### 问题 3：Webhook 根本没有到达服务器

**可能原因**：
- URL 配置错误
- 服务器不可访问
- 防火墙阻止

**解决方法**：
1. 检查 Stripe Dashboard 中的 Webhook URL 是否正确
2. 使用 curl 测试端点是否可访问
3. 检查防火墙和网络配置

### 问题 4：Webhook 到达但事件类型不匹配

**可能原因**：
- 没有订阅 `payment_intent.succeeded` 事件
- 订阅了错误的事件类型

**解决方法**：
1. 在 Stripe Dashboard 中检查事件订阅
2. 确保订阅了 `payment_intent.succeeded` 事件
3. 可以订阅所有支付相关事件：`payment_intent.*`

## 第八步：验证修复

修复后，验证 webhook 是否正常工作：

1. **进行一次新的支付**
2. **检查服务器日志**，应该看到：
   ```
   🔔 [WEBHOOK] 收到 Stripe Webhook 请求
   ✅ [WEBHOOK] 事件验证成功（签名已验证）
   💳 [WEBHOOK] Payment Intent 详情:
   ✅ [WEBHOOK] 支付成功，申请 xxx 已批准
   ✅ [WEBHOOK] 任务状态从 pending_payment 更新为 in_progress
   ```

3. **检查数据库**：
   - 任务状态应该是 `in_progress`
   - 任务 `is_paid` 应该是 `1`
   - 申请状态应该是 `approved`
   - 任务 `taker_id` 应该已设置

## 快速检查清单

- [ ] Stripe Dashboard 中 Webhook 端点存在且已启用
- [ ] Webhook URL 正确：`https://api.link2ur.com/api/stripe/webhook`
- [ ] 已订阅 `payment_intent.succeeded` 事件
- [ ] Webhook Secret 已正确配置（环境变量 `STRIPE_WEBHOOK_SECRET`）
- [ ] 测试/生产环境匹配（Secret 和 API Key 都是同一模式）
- [ ] 服务器日志显示收到 webhook 请求
- [ ] 服务器可以访问（curl 测试通过）
- [ ] 防火墙允许 Stripe IP 访问

## 需要帮助？

如果以上步骤都无法解决问题，请提供以下信息：

1. **Stripe Dashboard 截图**：
   - Webhook 端点详情页
   - 最近的事件日志（包括失败的事件）

2. **服务器日志**：
   - 支付成功后的日志
   - 任何与 webhook 相关的错误

3. **环境信息**：
   - 使用的 Stripe 模式（测试/生产）
   - Webhook URL
   - 环境变量配置（隐藏敏感信息）

4. **测试结果**：
   - Stripe CLI 测试结果
   - curl 测试结果

