# Stripe 支付功能测试指南

## 测试环境配置

### 1. 确认使用测试密钥

**后端环境变量**（Railway 或本地 `.env`）：
```env
STRIPE_SECRET_KEY=sk_test_...  # 必须以 sk_test_ 开头
STRIPE_WEBHOOK_SECRET=whsec_...  # 测试环境的 webhook 密钥
```

**前端环境变量**（Vercel 或本地 `.env`）：
```env
REACT_APP_STRIPE_PUBLISHABLE_KEY=pk_test_...  # 必须以 pk_test_ 开头
# 或
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

### 2. 验证密钥配置

**检查后端密钥**：
```bash
# 在 Railway 日志或本地终端查看
# 应该看到使用 sk_test_ 开头的密钥
```

**检查前端密钥**：
1. 打开浏览器开发者工具（F12）
2. 在 Console 中输入：
```javascript
console.log(process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || process.env.STRIPE_PUBLISHABLE_KEY);
```
3. 应该显示 `pk_test_` 开头的密钥

## 测试支付流程

### 步骤 1: 准备测试数据

1. **确保有测试任务**
   - 创建一个测试任务
   - 任务金额：例如 £10.00

2. **确保任务接受人有 Stripe Connect 账户**
   - 任务接受人需要先完成 Stripe Connect 注册
   - 在测试模式下，可以使用测试账户

### 步骤 2: 批准申请并跳转到支付页面

1. **作为任务发布者，批准一个申请**
   - 点击"批准"按钮
   - 系统会自动跳转到支付页面（新标签页）

2. **验证支付页面显示**
   - ✅ 任务标题显示正确
   - ✅ 任务图片显示（如果有）
   - ✅ 任务金额显示正确
   - ✅ 支付表单可以加载

### 步骤 3: 使用 Stripe 测试卡号完成支付

**Stripe 测试卡号**（在测试模式下使用）：

| 卡号 | 用途 | 结果 |
|------|------|------|
| `4242 4242 4242 4242` | 成功支付 | ✅ 支付成功 |
| `4000 0000 0000 0002` | 支付被拒绝 | ❌ 支付失败 |
| `4000 0025 0000 3155` | 需要 3D Secure | 🔐 需要额外验证 |

**测试卡信息**：
- **卡号**：`4242 4242 4242 4242`
- **过期日期**：任何未来的日期（如 `12/34`）
- **CVC**：任何 3 位数字（如 `123`）
- **邮编**：任何有效邮编（如 `12345`）

### 步骤 4: 完成支付测试

1. **在支付页面填写测试卡信息**
   - 输入测试卡号：`4242 4242 4242 4242`
   - 输入过期日期：`12/34`
   - 输入 CVC：`123`
   - 输入邮编：`12345`

2. **点击"支付"按钮**
   - 支付应该立即成功（测试模式）
   - 看到"支付成功"提示

3. **验证支付结果**
   - ✅ 支付页面显示成功消息
   - ✅ 任务状态更新为 `in_progress`
   - ✅ 申请状态更新为 `approved`
   - ✅ Stripe Dashboard 中可以看到测试支付记录

### 步骤 5: 验证 Webhook

1. **检查 Stripe Dashboard**
   - 登录 https://dashboard.stripe.com/test/webhooks
   - 查看 Webhook 事件日志
   - 应该看到 `payment_intent.succeeded` 事件

2. **检查后端日志**
   - 在 Railway 日志中查看
   - 应该看到 webhook 处理日志
   - 确认任务状态已更新

## 测试场景

### 场景 1: 正常支付流程 ✅

1. 批准申请 → 跳转到支付页面
2. 使用测试卡 `4242 4242 4242 4242` 完成支付
3. 验证支付成功，任务状态更新

### 场景 2: 支付失败 ❌

1. 批准申请 → 跳转到支付页面
2. 使用测试卡 `4000 0000 0000 0002`（会被拒绝）
3. 验证支付失败，申请状态恢复为 `pending`

### 场景 3: 3D Secure 验证 🔐

1. 批准申请 → 跳转到支付页面
2. 使用测试卡 `4000 0025 0000 3155`（需要 3D Secure）
3. 完成 3D Secure 验证
4. 验证支付成功

### 场景 4: 积分支付 💰

1. 确保用户有足够的积分
2. 在支付页面选择"积分支付"
3. 输入积分数量
4. 验证纯积分支付成功（无需 Stripe）

### 场景 5: 混合支付 💳💰

1. 在支付页面选择"混合支付"
2. 输入部分积分
3. 剩余金额使用 Stripe 支付
4. 验证支付成功

## 常见问题排查

### 问题 1: 支付表单无法加载

**可能原因**：
- Stripe Publishable Key 未配置或配置错误
- 网络问题

**解决方法**：
1. 检查浏览器控制台错误
2. 确认环境变量已正确设置
3. 检查 Stripe 密钥格式（必须以 `pk_test_` 开头）

### 问题 2: 支付后任务状态未更新

**可能原因**：
- Webhook 未正确配置
- Webhook 签名验证失败

**解决方法**：
1. 检查 Stripe Dashboard 中的 Webhook 事件
2. 检查后端日志中的 webhook 处理记录
3. 确认 `STRIPE_WEBHOOK_SECRET` 配置正确

### 问题 3: 支付页面显示错误

**可能原因**：
- 任务信息加载失败
- API 调用错误

**解决方法**：
1. 检查浏览器控制台错误
2. 检查网络请求（Network 标签）
3. 确认任务 ID 有效

## 测试检查清单

### 前端测试 ✅
- [ ] 支付页面可以正常加载
- [ ] 任务信息（标题、图片、金额）正确显示
- [ ] Stripe 支付表单可以加载
- [ ] 可以使用测试卡号完成支付
- [ ] 支付成功后正确跳转

### 后端测试 ✅
- [ ] Payment Intent 创建成功
- [ ] Webhook 可以接收事件
- [ ] 任务状态正确更新
- [ ] 申请状态正确更新
- [ ] 支付历史记录创建

### 集成测试 ✅
- [ ] 完整支付流程（批准 → 支付 → 成功）
- [ ] 支付失败处理（申请状态恢复）
- [ ] Webhook 异步处理正常

## Stripe Dashboard 测试工具

### 1. 测试模式切换

在 Stripe Dashboard 右上角：
- **Test mode**：使用测试密钥和测试数据
- **Live mode**：使用生产密钥和真实数据

**测试时确保在 Test mode** ✅

### 2. 查看测试支付

1. 进入 Stripe Dashboard → **Payments**
2. 应该看到所有测试支付记录
3. 点击支付记录查看详情

### 3. 查看 Webhook 事件

1. 进入 Stripe Dashboard → **Developers** → **Webhooks**
2. 选择你的 Webhook 端点
3. 查看事件日志
4. 应该看到 `payment_intent.succeeded` 等事件

### 4. 测试 Webhook

1. 在 Webhook 详情页面
2. 点击 "Send test webhook"
3. 选择事件类型（如 `payment_intent.succeeded`）
4. 发送测试事件
5. 检查后端是否收到并处理

## 测试数据准备

### 创建测试 Stripe Connect 账户

1. **在测试模式下创建 Connect 账户**
   - 使用 `/api/stripe/connect/account/create-embedded` API
   - 完成 onboarding 流程
   - 获取 `stripe_account_id`

2. **验证账户状态**
   - 使用 `/api/stripe/connect/account/status` API
   - 确认账户状态为 `active`

## 注意事项

1. **测试模式 vs 生产模式**
   - 测试模式使用 `sk_test_` 和 `pk_test_` 密钥
   - 测试支付不会产生真实费用
   - 测试数据不会影响生产数据

2. **Webhook 配置**
   - 测试环境和生产环境需要不同的 Webhook 端点
   - 测试环境可以使用 Stripe CLI 本地转发
   - 生产环境需要在 Stripe Dashboard 中配置

3. **测试卡号限制**
   - 测试卡号只能在测试模式下使用
   - 生产模式下使用测试卡号会失败

## 快速测试命令

### 使用 Stripe CLI 测试 Webhook（本地开发）

```bash
# 安装 Stripe CLI
# macOS: brew install stripe/stripe-cli/stripe
# 其他平台: https://stripe.com/docs/stripe-cli

# 登录
stripe login

# 转发 webhook 到本地服务器
stripe listen --forward-to localhost:8000/api/stripe/webhook

# 触发测试事件
stripe trigger payment_intent.succeeded
```

## 测试完成标准

✅ **支付功能测试通过的标准**：

1. ✅ 可以使用测试卡号完成支付
2. ✅ 支付成功后任务状态正确更新
3. ✅ Webhook 事件正确接收和处理
4. ✅ 支付失败时申请状态正确恢复
5. ✅ 支付页面 UI 正常显示
6. ✅ 所有支付方式（Stripe、积分、混合）都可以正常工作

---

**现在可以开始测试了！** 🚀

如果遇到问题，请检查：
1. 环境变量配置是否正确
2. Stripe Dashboard 是否在测试模式
3. Webhook 端点是否正确配置
4. 浏览器控制台是否有错误

