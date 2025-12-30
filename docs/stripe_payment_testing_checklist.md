# Stripe 支付系统测试清单

## 开发完成状态

### ✅ 已完成的功能

#### 后端
- [x] Payment Intent 创建 API（替代 Checkout Session）
- [x] Webhook 处理（payment_intent.succeeded, payment_intent.payment_failed）
- [x] 退款和争议 Webhook 处理（charge.refunded, charge.dispute.created）
- [x] Stripe Connect Express Account 创建 API
- [x] Connect 账户状态查询 API
- [x] Connect onboarding 链接创建 API
- [x] Connect Webhook 处理
- [x] 数据库模型更新（User.stripe_account_id）
- [x] Schema 定义更新

#### 前端
- [x] Stripe Elements 支付组件（StripePaymentForm.tsx）
- [x] 支付页面（TaskPayment.tsx）
- [x] 路由配置
- [ ] **待安装依赖**：`@stripe/stripe-js` 和 `@stripe/react-stripe-js`

#### 数据库
- [x] 迁移文件创建（038_add_stripe_connect_account_id.sql）
- [ ] **待执行迁移**：运行迁移文件

---

## 测试前准备清单

### 1. 环境变量配置 ✅

**后端环境变量**（`.env` 或生产环境配置）：
```env
STRIPE_SECRET_KEY=sk_test_...  # 测试环境
STRIPE_WEBHOOK_SECRET=whsec_...  # Webhook 签名密钥
FRONTEND_URL=http://localhost:3000  # 或生产环境 URL
```

**前端环境变量**（`frontend/.env` 或 `frontend/.env.local`）：
```env
STRIPE_PUBLISHABLE_KEY=pk_test_...  # 测试环境
```

### 2. 安装前端依赖 ⚠️

**必须执行**：
```bash
cd frontend
npm install @stripe/stripe-js @stripe/react-stripe-js
```

### 3. 数据库迁移 ⚠️

**必须执行**：
```bash
# 方法一：使用 psql
psql -d your_database -f backend/migrations/038_add_stripe_connect_account_id.sql

# 方法二：如果使用迁移脚本
python backend/run_migrations.py
```

**验证迁移**：
```sql
-- 检查字段是否添加成功
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'stripe_account_id';
```

### 4. Stripe Dashboard 配置 ⚠️

#### 4.1 Webhook 端点配置

**生产环境**：
1. 登录 Stripe Dashboard：https://dashboard.stripe.com/
2. 进入 **Developers → Webhooks**
3. 点击 **"Add endpoint"**
4. 填写 Webhook URL：
   ```
   https://your-domain.com/api/users/stripe/webhook
   ```
5. 选择要监听的事件：
   - ✅ `payment_intent.succeeded`（必需）
   - ✅ `payment_intent.payment_failed`（推荐）
   - ✅ `charge.refunded`（推荐）
   - ✅ `charge.dispute.created`（推荐）
   - ✅ `account.updated`（如果使用 Connect）
6. 复制 Webhook 签名密钥到环境变量

**本地开发**：
```bash
# 使用 Stripe CLI
stripe listen --forward-to localhost:8000/api/users/stripe/webhook
# 复制输出的 whsec_... 密钥
```

#### 4.2 Connect 设置（如果使用 Connect）

1. 在 Stripe Dashboard 中启用 Connect
2. 配置 Connect 设置
3. 设置 Connect Webhook（如果需要）：
   ```
   https://your-domain.com/api/stripe/connect/webhook
   ```

### 5. 代码检查 ✅

- [x] 后端代码无 lint 错误
- [x] 前端代码无 lint 错误
- [x] 路由已注册
- [x] Schema 定义完整

---

## 测试步骤

### 测试 1：基础支付流程

1. **启动服务**：
   ```bash
   # 后端
   cd backend
   python main.py
   
   # 前端
   cd frontend
   npm start
   ```

2. **创建测试任务**：
   - 登录系统
   - 发布一个测试任务（金额：£10.00）

3. **测试支付**：
   - 访问支付页面：`/tasks/{task_id}/payment`
   - 选择支付方式：Stripe
   - 使用测试卡号：`4242 4242 4242 4242`
   - 任意未来日期和 CVC（如：12/25, 123）
   - 完成支付

4. **验证结果**：
   - 检查 Webhook 是否收到 `payment_intent.succeeded` 事件
   - 检查任务状态是否更新为已支付
   - 检查数据库中的任务记录

### 测试 2：积分支付

1. **获取积分**：
   - 通过签到或其他方式获取积分

2. **测试纯积分支付**：
   - 访问支付页面
   - 选择"积分支付"
   - 使用积分全额抵扣
   - 验证任务状态直接更新

3. **测试混合支付**：
   - 选择"混合支付"
   - 使用部分积分 + Stripe 支付
   - 验证计算正确

### 测试 3：优惠券支付

1. **使用优惠券**：
   - 访问支付页面
   - 输入优惠券代码
   - 验证折扣计算正确
   - 完成支付

### 测试 4：Stripe Connect 账户创建

1. **创建 Connect 账户**：
   ```bash
   POST /api/stripe/connect/account/create
   Authorization: Bearer <token>
   ```

2. **完成 Onboarding**：
   - 使用返回的 `onboarding_url`
   - 在测试环境中完成账户设置
   - 使用测试数据完成验证

3. **检查账户状态**：
   ```bash
   GET /api/stripe/connect/account/status
   Authorization: Bearer <token>
   ```

### 测试 5：Webhook 测试

1. **使用 Stripe CLI 测试**（本地）：
   ```bash
   stripe listen --forward-to localhost:8000/api/users/stripe/webhook
   ```

2. **触发测试事件**：
   ```bash
   stripe trigger payment_intent.succeeded
   ```

3. **验证处理**：
   - 检查后端日志
   - 检查数据库更新

### 测试 6：错误处理

1. **支付失败测试**：
   - 使用测试卡号：`4000 0000 0000 0002`（支付被拒绝）
   - 验证错误处理

2. **3D Secure 测试**：
   - 使用测试卡号：`4000 0025 0000 3155`
   - 验证 3D Secure 流程

---

## 常见问题排查

### 问题 1：前端 Stripe 组件未加载

**症状**：支付表单不显示

**检查**：
- [ ] 是否安装了 `@stripe/stripe-js` 和 `@stripe/react-stripe-js`
- [ ] 环境变量 `STRIPE_PUBLISHABLE_KEY` 是否配置
- [ ] 浏览器控制台是否有错误

**解决**：
```bash
cd frontend
npm install @stripe/stripe-js @stripe/react-stripe-js
# 重启前端服务
```

### 问题 2：Webhook 未收到事件

**症状**：支付完成但任务状态未更新

**检查**：
- [ ] Webhook URL 是否正确配置
- [ ] Webhook 签名密钥是否正确
- [ ] Stripe Dashboard 中 Webhook 日志是否有错误

**解决**：
- 检查 Stripe Dashboard → Webhooks → 查看事件日志
- 验证 Webhook 签名密钥

### 问题 3：数据库字段不存在

**症状**：`stripe_account_id` 字段错误

**检查**：
- [ ] 是否运行了数据库迁移
- [ ] 迁移文件是否执行成功

**解决**：
```bash
# 运行迁移
psql -d your_database -f backend/migrations/038_add_stripe_connect_account_id.sql
```

### 问题 4：Payment Intent 创建失败

**症状**：API 返回错误

**检查**：
- [ ] `STRIPE_SECRET_KEY` 是否正确配置
- [ ] 密钥格式是否正确（`sk_test_...` 或 `sk_live_...`）
- [ ] 后端日志中的错误信息

---

## 测试完成标准

- [ ] 基础支付流程测试通过
- [ ] 积分支付测试通过
- [ ] 优惠券支付测试通过
- [ ] Webhook 事件处理正常
- [ ] 错误处理正常
- [ ] Connect 账户创建测试通过（如果使用）
- [ ] 所有测试卡号场景测试通过

---

## 下一步

测试通过后：
1. 切换到生产环境密钥
2. 配置生产环境 Webhook
3. 进行生产环境测试
4. 监控支付流程和错误日志

---

**最后更新**：2024年

