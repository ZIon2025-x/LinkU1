# Stripe 支付系统快速开始

## 🚀 快速部署清单

### 第一步：Railway 后端配置（5分钟）

1. **添加环境变量**：
   - 进入 Railway Dashboard → 你的后端项目 → Variables
   - 添加：
     ```
     STRIPE_SECRET_KEY=sk_test_...
     STRIPE_WEBHOOK_SECRET=whsec_...
     FRONTEND_URL=https://www.link2ur.com
     ```

2. **数据库迁移**：
   - ✅ **自动执行**：应用启动时自动运行迁移
   - ✅ 无需手动操作
   - ✅ 迁移文件：`038_add_stripe_connect_account_id.sql`
   - ⚠️ 确保 `AUTO_MIGRATE=true`（默认已启用）

3. **配置 Stripe Webhook**：
   - Stripe Dashboard → Developers → Webhooks → Add endpoint
   - URL: `https://api.link2ur.com/api/users/stripe/webhook`
   - 选择事件：`payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`, `charge.dispute.created`
   - 复制 Signing secret → 添加到 Railway 环境变量

### 第二步：Vercel 前端配置（3分钟）

1. **添加环境变量**：
   - Vercel Dashboard → 你的前端项目 → Settings → Environment Variables
   - 添加：
     ```
     STRIPE_PUBLISHABLE_KEY=pk_test_...
     ```

2. **依赖已添加**：
   - `package.json` 已包含 `@stripe/stripe-js` 和 `@stripe/react-stripe-js`
   - Vercel 会在下次部署时自动安装

3. **触发部署**：
   - 推送代码到 GitHub（如果使用 Git 集成）
   - 或在 Vercel Dashboard 中点击 "Redeploy"

### 第三步：测试（2分钟）

1. **访问支付页面**：
   ```
   https://www.link2ur.com/en/tasks/{task_id}/payment
   ```

2. **测试支付**：
   - 卡号：`4242 4242 4242 4242`
   - 日期：任意未来日期（如 12/25）
   - CVC：任意 3 位数字（如 123）

3. **验证**：
   - 检查任务状态是否更新
   - 检查 Stripe Dashboard → Payments

---

## ✅ 完成检查清单

### Railway 后端
- [ ] `STRIPE_SECRET_KEY` 已配置
- [ ] `STRIPE_WEBHOOK_SECRET` 已配置
- [ ] `FRONTEND_URL` 已配置
- [ ] 数据库迁移已执行
- [ ] Webhook 端点已配置
- [ ] 后端服务正常运行

### Vercel 前端
- [ ] `STRIPE_PUBLISHABLE_KEY` 已配置
- [ ] 依赖已添加到 `package.json`
- [ ] 前端已重新部署
- [ ] 支付页面可以访问

### Stripe Dashboard
- [ ] Webhook 端点已创建
- [ ] 事件已选择
- [ ] Signing secret 已复制

### 测试
- [ ] 支付页面可以加载
- [ ] 测试支付成功
- [ ] 任务状态已更新
- [ ] Webhook 事件已收到

---

## 📱 iOS 应用

iOS 应用可以使用 WebView 加载支付页面，无需额外配置。

**测试步骤**：
1. 在 iOS 应用中打开任务详情
2. 点击支付按钮
3. 在 WebView 中完成支付
4. 返回应用，验证状态更新

---

## 🔧 如果遇到问题

### 前端无法加载 Stripe
- 检查 Vercel 环境变量
- 检查构建日志
- 确认依赖已安装

### Webhook 未收到事件
- 检查 Stripe Dashboard 中的 Webhook URL
- 验证 `STRIPE_WEBHOOK_SECRET` 是否正确
- 查看 Railway 日志

### 支付成功但状态未更新
- 检查 Webhook 事件日志
- 查看 Railway 应用日志
- 验证数据库连接

---

**详细文档**：查看 `docs/stripe_deployment_guide.md`

