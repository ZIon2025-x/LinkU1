# Stripe 支付系统部署指南

## 部署架构

- **前端**：Vercel（`https://www.link2ur.com`）
- **后端**：Railway（`https://api.link2ur.com`）
- **iOS**：App Store / TestFlight

---

## 一、Railway 后端配置

### 1.1 环境变量配置

在 Railway Dashboard 中，进入你的后端项目 → **Variables**，添加以下环境变量：

```env
# Stripe 配置（测试环境）
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# 前端 URL（用于支付回调）
FRONTEND_URL=https://www.link2ur.com

# 数据库配置（如果还没有）
DATABASE_URL=postgresql://...

# 其他必需的环境变量
# （参考 backend/production.env.template）
```

### 1.2 数据库迁移

✅ **自动迁移已配置** - 无需手动操作！

**自动迁移机制**：
- 应用启动时自动执行所有未执行的迁移
- 通过 `AUTO_MIGRATE` 环境变量控制（默认为 `true`）
- 迁移文件：`backend/migrations/038_add_stripe_connect_account_id.sql`

**验证迁移**：

部署后，在 Railway 日志中应该看到：
```
开始执行数据库迁移...
🔄 执行迁移: 038_add_stripe_connect_account_id.sql
✅ 迁移执行成功: 038_add_stripe_connect_account_id.sql (耗时: XXms)
数据库迁移执行完成！
```

**手动验证**（可选）：

如果需要手动验证，在 Railway PostgreSQL 控制台中执行：
```sql
-- 检查迁移是否已执行
SELECT migration_name, executed_at 
FROM schema_migrations 
WHERE migration_name = '038_add_stripe_connect_account_id.sql';

-- 检查字段是否已添加
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'stripe_account_id';
```

### 1.3 配置 Stripe Webhook

1. **在 Stripe Dashboard 中配置 Webhook**：
   - 登录：https://dashboard.stripe.com/
   - 进入 **Developers → Webhooks**
   - 点击 **"Add endpoint"**
   - Webhook URL：`https://api.link2ur.com/api/users/stripe/webhook`
   - 选择事件：
     - ✅ `payment_intent.succeeded`
     - ✅ `payment_intent.payment_failed`
     - ✅ `charge.refunded`
     - ✅ `charge.dispute.created`
     - ✅ `account.updated`（如果使用 Connect）
   - 复制 **Signing secret**（`whsec_...`）
   - 添加到 Railway 环境变量：`STRIPE_WEBHOOK_SECRET`

2. **验证 Webhook**：
   - 在 Stripe Dashboard → Webhooks → 点击你的端点
   - 点击 **"Send test webhook"**
   - 选择 `payment_intent.succeeded`
   - 检查 Railway 日志，确认收到事件

### 1.4 部署检查清单

- [ ] 环境变量已配置（STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, FRONTEND_URL）
- [ ] 数据库迁移已执行
- [ ] Webhook 端点已配置
- [ ] 后端服务正常运行
- [ ] 日志中无错误

---

## 二、Vercel 前端配置

### 2.1 环境变量配置

在 Vercel Dashboard 中，进入你的前端项目 → **Settings → Environment Variables**，添加：

```env
# Stripe 配置（测试环境）
STRIPE_PUBLISHABLE_KEY=pk_test_...

# API 配置（如果还没有）
REACT_APP_API_URL=https://api.link2ur.com
REACT_APP_WS_URL=wss://api.link2ur.com
```

**注意**：
- Vercel 会自动读取 `vercel.json` 中的 `env` 配置
- 但 `STRIPE_PUBLISHABLE_KEY` 需要在 Vercel Dashboard 中单独配置
- 如果使用 `REACT_APP_` 前缀，也需要在 Dashboard 中配置

### 2.2 安装依赖

**方法一：在 package.json 中添加依赖**

确保 `frontend/package.json` 中有：

```json
{
  "dependencies": {
    "@stripe/stripe-js": "^2.0.0",
    "@stripe/react-stripe-js": "^2.0.0"
  }
}
```

**方法二：通过 Vercel 构建时安装**

Vercel 会在构建时自动运行 `npm install`，所以只要 `package.json` 中有依赖即可。

### 2.3 更新 vercel.json（可选）

如果需要，可以在 `vercel.json` 中添加环境变量：

```json
{
  "env": {
    "REACT_APP_API_URL": "https://api.link2ur.com",
    "REACT_APP_WS_URL": "wss://api.link2ur.com",
    "STRIPE_PUBLISHABLE_KEY": "pk_test_..."
  }
}
```

**但推荐在 Vercel Dashboard 中配置**，更安全。

### 2.4 部署检查清单

- [ ] 环境变量已配置（STRIPE_PUBLISHABLE_KEY）
- [ ] package.json 中包含 Stripe 依赖
- [ ] 构建成功（检查 Vercel 构建日志）
- [ ] 前端页面可以访问
- [ ] 支付页面可以加载

---

## 三、iOS 配置

### 3.1 当前状态

**iOS 应用目前未集成 Stripe SDK**，如果需要支持 iOS 内支付，需要：

1. **使用 WebView 加载支付页面**（推荐，最简单）
2. **集成 Stripe iOS SDK**（需要更多开发工作）

### 3.2 方案一：WebView 支付（推荐）

**优点**：
- ✅ 无需额外开发
- ✅ 使用现有的 Web 支付页面
- ✅ 维护简单

**实现**：
iOS 应用已经可以使用 `InAppWebView` 加载支付页面：

```swift
// 在 iOS 中打开支付页面
let paymentURL = "https://www.link2ur.com/en/tasks/\(taskId)/payment"
// 使用 InAppWebView 打开
```

### 3.3 方案二：集成 Stripe iOS SDK（未来）

如果需要原生支付体验，可以集成：

1. **添加 Stripe iOS SDK**：
   ```swift
   // Package.swift 或 Podfile
   dependencies: [
       .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0")
   ]
   ```

2. **创建支付视图**：
   - 使用 `STPPaymentCardTextField` 收集卡号
   - 调用后端 API 创建 Payment Intent
   - 使用 `STPPaymentHandler` 确认支付

3. **配置**：
   - 在 `Info.plist` 中添加 Stripe Publishable Key
   - 处理支付回调

**当前建议**：先使用 WebView 方案，验证支付流程正常后，再考虑原生集成。

### 3.4 iOS 部署检查清单

- [ ] 支付页面可以通过 WebView 访问
- [ ] 测试支付流程
- [ ] 处理支付成功/失败回调
- [ ] 更新任务状态

---

## 四、测试步骤

### 4.1 后端测试

1. **测试 Payment Intent 创建**：
   ```bash
   curl -X POST https://api.link2ur.com/api/coupon-points/tasks/{task_id}/payment \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"payment_method": "stripe"}'
   ```

2. **检查响应**：
   - 应该返回 `client_secret`
   - 应该返回 `payment_intent_id`

3. **测试 Webhook**：
   - 在 Stripe Dashboard → Webhooks → 发送测试事件
   - 检查 Railway 日志

### 4.2 前端测试

1. **访问支付页面**：
   ```
   https://www.link2ur.com/en/tasks/{task_id}/payment
   ```

2. **测试支付**：
   - 使用测试卡号：`4242 4242 4242 4242`
   - 任意未来日期和 CVC
   - 完成支付

3. **验证结果**：
   - 检查任务状态是否更新
   - 检查 Stripe Dashboard 中的支付记录

### 4.3 iOS 测试

1. **在 iOS 应用中**：
   - 打开任务详情
   - 点击支付按钮
   - 在 WebView 中完成支付

2. **验证**：
   - 支付成功后返回应用
   - 任务状态更新

---

## 五、生产环境切换

### 5.1 切换到生产密钥

**Railway**：
```env
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...  # 生产环境的 Webhook Secret
```

**Vercel**：
```env
STRIPE_PUBLISHABLE_KEY=pk_live_...
```

### 5.2 配置生产 Webhook

1. 在 Stripe Dashboard 中创建新的 Webhook 端点
2. URL：`https://api.link2ur.com/api/users/stripe/webhook`
3. 选择生产环境事件
4. 复制新的 Signing secret

### 5.3 测试生产环境

1. 使用真实银行卡（小额测试）
2. 验证支付流程
3. 检查 Webhook 事件
4. 验证数据库更新

---

## 六、常见问题

### 问题 1：前端无法加载 Stripe 组件

**原因**：环境变量未配置或依赖未安装

**解决**：
1. 检查 Vercel Dashboard 中的环境变量
2. 检查 `package.json` 中的依赖
3. 重新部署前端

### 问题 2：Webhook 未收到事件

**原因**：Webhook URL 配置错误或签名验证失败

**解决**：
1. 检查 Stripe Dashboard 中的 Webhook URL
2. 验证 `STRIPE_WEBHOOK_SECRET` 是否正确
3. 检查 Railway 日志中的错误信息

### 问题 3：数据库字段不存在

**原因**：迁移未执行

**解决**：
1. 在 Railway PostgreSQL 控制台中执行迁移 SQL
2. 验证字段已添加

### 问题 4：支付成功但任务状态未更新

**原因**：Webhook 处理失败

**解决**：
1. 检查 Railway 日志
2. 验证 Webhook 事件是否收到
3. 检查数据库连接

---

## 七、监控和维护

### 7.1 监控指标

- **支付成功率**：Stripe Dashboard → Payments
- **Webhook 成功率**：Stripe Dashboard → Webhooks → 事件日志
- **错误日志**：Railway → Logs
- **数据库状态**：Railway → PostgreSQL

### 7.2 定期检查

- [ ] 检查 Stripe Dashboard 中的支付记录
- [ ] 检查 Webhook 事件日志
- [ ] 检查 Railway 应用日志
- [ ] 验证数据库数据一致性

---

**最后更新**：2024年

