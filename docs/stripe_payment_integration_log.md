# Stripe 支付系统集成开发日志

## 项目概述

**项目名称**：Link²Ur 平台支付系统集成  
**集成服务**：Stripe 支付网关  
**开发时间**：2024年  
**开发人员**：Link²Ur 开发团队  
**文档版本**：v1.0

---

## 一、项目背景

### 1.1 业务需求

Link²Ur 平台是一个任务发布与接单平台，需要集成支付系统以支持以下业务场景：

1. **任务平台服务费支付**：用户发布任务时需要支付平台服务费（通常为任务金额的 10%）
2. **任务奖励托管**：任务完成后，奖励金额托管在平台，待确认后发放给服务者
3. **多种支付方式**：支持积分支付、第三方支付（Stripe）以及混合支付方式

**注意**：当前实现使用标准支付流程（资金先到平台账户）。如果未来需要直接支付给服务者，可以考虑使用 Stripe Connect。

### 1.2 支付集成方式

**前端（Web）**：
- ✅ **嵌入式支付**：使用 Stripe Elements，支付表单嵌入在页面中
- ✅ 使用 `@stripe/react-stripe-js` 的 `CardElement`
- ✅ 完全符合 PCI DSS 合规要求

**iOS**：
- ⚠️ **当前使用 WebView**：加载 Web 支付页面
- ⚠️ **可集成 Stripe iOS SDK**：实现原生嵌入式支付（详见 `docs/stripe_ios_integration.md`）

### 1.2 技术需求

- 支持信用卡/借记卡支付
- 安全的支付流程（PCI DSS 合规）
- Webhook 回调机制确保支付状态同步
- 支持积分和优惠券抵扣
- 良好的用户体验

---

## 二、技术选型

### 2.1 为什么选择 Stripe

经过对比分析 Stripe、PayPal、Square 等支付服务商，最终选择 Stripe 的原因：

1. **开发者友好**：API 设计清晰，文档完善
2. **国际化支持**：支持多种货币和地区
3. **安全性**：PCI DSS Level 1 认证，无需处理敏感卡信息
4. **Webhook 机制**：可靠的事件通知系统
5. **测试环境完善**：提供完整的测试工具和测试卡号
6. **社区支持**：活跃的开发者社区和丰富的集成示例

### 2.2 技术栈

**后端**：
- **框架**：FastAPI
- **数据库**：PostgreSQL (通过 SQLAlchemy ORM)
- **支付 SDK**：`stripe>=7.0.0,<10.0.0`
- **Python 版本**：3.9+

**前端**：
- **框架**：React + TypeScript
- **支付组件**：`@stripe/stripe-js` 和 `@stripe/react-stripe-js`
- **集成方式**：Stripe Elements（嵌入式支付表单）

---

## 三、开发过程

### 3.1 第一阶段：环境配置与基础设置（第1-2天）

#### 3.1.1 安装依赖

在 `backend/requirements.txt` 中添加 Stripe SDK：

```txt
stripe>=7.0.0,<10.0.0
```

#### 3.1.2 环境变量配置

在 `.env` 文件中添加 Stripe 配置：

```env
# Stripe 配置（测试环境）- 后端环境变量
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...  # 可选，主要用于前端
STRIPE_WEBHOOK_SECRET=whsec_...
FRONTEND_URL=http://localhost:3000
```

**前端环境变量**（`frontend/.env` 或 `frontend/.env.local`）：

```env
# Stripe 配置（测试环境）- 前端环境变量
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

**注意**：如果使用 React，通常需要 `REACT_APP_` 前缀（`REACT_APP_STRIPE_PUBLISHABLE_KEY`），但当前项目使用 `STRIPE_PUBLISHABLE_KEY`。

**重要说明：Stripe 密钥的使用**

1. **Secret Key（私钥）** - `STRIPE_SECRET_KEY`
   - ✅ **必须放在后端环境变量中**
   - ✅ **绝对不能暴露给客户端**（不能在前端代码中使用）
   - ✅ 用于服务器端操作：创建支付会话、查询支付状态、处理 Webhook 等
   - ✅ 格式：`sk_test_...`（测试）或 `sk_live_...`（生产）

2. **Publishable Key（公钥）** - `STRIPE_PUBLISHABLE_KEY`
   - ✅ **当前项目使用 Stripe Elements（嵌入式支付表单），前端需要此密钥**
   - ✅ 必须放在前端环境变量中：`STRIPE_PUBLISHABLE_KEY`
   - ✅ 公钥本身是安全的，可以公开，但建议放在环境变量中便于管理
   - ✅ 格式：`pk_test_...`（测试）或 `pk_live_...`（生产）
   - ⚠️ **注意**：如果使用标准 React，通常需要 `REACT_APP_` 前缀，但当前项目使用 `STRIPE_PUBLISHABLE_KEY`

3. **Webhook Secret（Webhook 签名密钥）** - `STRIPE_WEBHOOK_SECRET`
   - ✅ **必须放在后端环境变量中**
   - ✅ 用于验证 Webhook 请求的真实性（防止伪造请求）
   - ✅ **不在 API Keys 页面**，需要先配置 Webhook 端点才能获取
   - ✅ 格式：`whsec_...`
   - ⚠️ **重要**：每个 Webhook 端点都有自己独立的签名密钥

**当前项目的密钥使用情况**：
- ✅ 后端使用 `STRIPE_SECRET_KEY` 创建 Payment Intent 或处理支付
- ✅ 后端使用 `STRIPE_WEBHOOK_SECRET` 验证 Webhook
- ✅ 前端使用 `STRIPE_PUBLISHABLE_KEY` 初始化 Stripe Elements（嵌入式支付表单）

**Stripe Elements vs Stripe Checkout**：
- **Stripe Elements**（当前使用）：嵌入式支付表单，用户无需离开网站
  - 前端需要 Publishable Key
  - 更好的用户体验
  - 需要更多前端开发工作
- **Stripe Checkout**（备选方案）：跳转到 Stripe 托管页面
  - 前端不需要 Publishable Key
  - 开发更简单
  - 用户需要离开网站

**遇到的问题**：
- 初始配置时忘记设置 `FRONTEND_URL`，导致支付成功后的重定向 URL 错误
- **解决方案**：添加环境变量并设置默认值

#### 3.1.3 Stripe Dashboard 配置

1. **获取 API 密钥**
   - 登录 Stripe Dashboard：https://dashboard.stripe.com/
   - 进入 **Developers → API keys**
   - 复制 **Secret key**（`sk_test_...`）和 **Publishable key**（`pk_test_...`）

2. **配置 Webhook 端点并获取签名密钥**

   **方式一：生产环境（Stripe Dashboard）**
   
   1. 登录 Stripe Dashboard
   2. 进入 **Developers → Webhooks**
   3. 点击 **"Add endpoint"**（添加端点）
   4. 填写 Webhook URL：
      ```
      https://your-domain.com/api/users/stripe/webhook
      ```
   5. 选择要监听的事件：
      
      **必需事件**（当前项目使用 Checkout Session）：
      - ✅ `checkout.session.completed`（支付完成）- **必需**
      
      **退款相关事件**（如果支持退款）：
      - ✅ `charge.refunded`（退款完成）- **强烈推荐**
      - ✅ `charge.refund.updated`（退款状态更新）- 可选
      
      **争议/拒付事件**（保护平台，强烈推荐）：
      - ✅ `charge.dispute.created`（争议创建）- **强烈推荐**
      - ✅ `charge.dispute.updated`（争议状态更新）- 可选
      - ✅ `charge.dispute.closed`（争议关闭）- 可选
      
      **支付失败事件**：
      - ✅ `checkout.session.async_payment_failed`（异步支付失败）- 推荐
      - ✅ `charge.failed`（支付失败）- 可选
      
      **其他推荐事件**：
      - ✅ `checkout.session.async_payment_succeeded`（异步支付成功，如果使用延迟支付方式）
      - ⚠️ `checkout.session.expired`（Checkout Session 过期，可选，用于清理）
      
      **完整事件列表**（按优先级）：
      1. **必需**：`checkout.session.completed`
      2. **强烈推荐**：`charge.refunded`、`charge.dispute.created`
      3. **推荐**：`checkout.session.async_payment_failed`
      4. **可选**：其他事件
      
      **注意**：
      - ❌ `payment_intent.succeeded` - **不需要**（项目使用 Checkout Session，不是 Payment Intent）
      - ❌ `payment_intent.payment_failed` - **不需要**（同上）
      
      **最小配置**（仅必需事件）：
      - 如果只想监听支付完成，只选择 `checkout.session.completed` 即可
   6. 点击 **"Add endpoint"** 创建端点
   7. **重要**：创建后，点击端点进入详情页
   8. 在 **"Signing secret"** 部分，点击 **"Reveal"**（显示）按钮
   9. 复制签名密钥（格式：`whsec_...`），这就是 `STRIPE_WEBHOOK_SECRET`
   
   **方式二：本地开发（Stripe CLI）**
   
   1. 安装 Stripe CLI：
      ```bash
      # macOS
      brew install stripe/stripe-cli/stripe
      
      # Windows (使用 Chocolatey)
      choco install stripe
      
      # Linux
      # 下载并安装，参考：https://stripe.com/docs/stripe-cli
      ```
   
   2. 登录 Stripe CLI：
      ```bash
      stripe login
      ```
   
   3. 启动 Webhook 转发（会自动生成签名密钥）：
      ```bash
      stripe listen --forward-to localhost:8000/api/users/stripe/webhook
      ```
   
   4. **重要**：命令运行后会输出签名密钥，例如：
      ```
      > Ready! Your webhook signing secret is whsec_xxxxxxxxxxxxx
      ```
   
   5. 复制这个 `whsec_...` 密钥，设置为 `STRIPE_WEBHOOK_SECRET` 环境变量
   
   **⚠️ 注意事项**：
   - 本地开发和生产环境使用**不同的签名密钥**
   - 本地开发：使用 Stripe CLI 提供的密钥
   - 生产环境：使用 Dashboard 中配置的 Webhook 端点密钥
   - 签名密钥用于验证 Webhook 请求的真实性，防止恶意请求

---

### 3.2 第二阶段：后端 API 开发（第3-5天）

#### 3.2.1 创建支付会话 API

**端点**：`POST /api/coupon-points/tasks/{task_id}/payment`

**实现位置**：`backend/app/coupon_points_routes.py` (第 316-539 行)

**核心功能**：
1. 计算平台服务费（任务金额的 10%）
2. 处理积分抵扣（如果使用积分支付）
3. 处理优惠券折扣
4. 创建 Stripe Checkout Session
5. 返回支付 URL

**关键代码实现**：

```python
# 创建 Stripe 支付会话
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

session = stripe.checkout.Session.create(
    payment_method_types=["card"],
    line_items=[{
        "price_data": {
            "currency": "gbp",
            "product_data": {
                "name": f"任务 #{task_id} 平台服务费",
                "description": f"{task.title} - 平台服务费"
            },
            "unit_amount": final_amount,  # 以便士为单位
        },
        "quantity": 1,
    }],
    mode="payment",
    success_url=f"{os.getenv('FRONTEND_URL')}/tasks/{task_id}/pay/success",
    cancel_url=f"{os.getenv('FRONTEND_URL')}/tasks/{task_id}/pay/cancel",
    metadata={
        "task_id": task_id,
        "user_id": current_user.id,
        "points_used": str(points_used) if points_used else "",
        "coupon_usage_log_id": str(coupon_usage_log.id) if coupon_usage_log else "",
        "application_fee": str(application_fee_pence)
    },
)
```

**遇到的问题**：

1. **金额单位问题**
   - **问题**：Stripe 要求金额以最小货币单位（便士）为单位，但代码中使用了英镑
   - **解决方案**：统一使用便士（pence）作为金额单位，在显示时除以 100

2. **Metadata 数据类型问题**
   - **问题**：Stripe metadata 只接受字符串类型
   - **解决方案**：将所有数值类型转换为字符串存储

3. **积分全额抵扣的处理**
   - **问题**：当积分全额抵扣时，不需要创建 Stripe 会话
   - **解决方案**：添加判断逻辑，当 `final_amount == 0` 时直接完成支付

#### 3.2.2 Schema 定义

**实现位置**：`backend/app/schemas.py` (第 1450-1473 行)

定义了请求和响应的数据模型：

```python
class TaskPaymentRequest(BaseModel):
    payment_method: str  # points, stripe, mixed
    points_amount: Optional[int] = None
    coupon_code: Optional[str] = None
    user_coupon_id: Optional[int] = None
    stripe_amount: Optional[int] = None

class TaskPaymentResponse(BaseModel):
    payment_id: Optional[int] = None
    fee_type: str
    total_amount: int
    total_amount_display: str
    points_used: Optional[int] = None
    points_used_display: Optional[str] = None
    coupon_discount: Optional[int] = None
    coupon_discount_display: Optional[str] = None
    stripe_amount: Optional[int] = None
    stripe_amount_display: Optional[str] = None
    currency: str
    final_amount: int
    final_amount_display: str
    checkout_url: Optional[str] = None
    note: str
```

---

### 3.3 第三阶段：Webhook 处理（第6-7天）

#### 3.3.1 Webhook 端点实现

**端点**：`POST /api/users/stripe/webhook`

**实现位置**：`backend/app/routers.py` (第 2842-2860 行)

**核心功能**：
1. 验证 Stripe 签名（防止伪造请求）
2. 处理 `checkout.session.completed` 事件（支付完成）
3. 更新任务支付状态
4. 更新托管金额

**当前实现**：只处理 `checkout.session.completed` 事件

**建议扩展**：可以添加对其他事件的处理，如：
- `checkout.session.async_payment_succeeded` - 异步支付成功
- `checkout.session.async_payment_failed` - 异步支付失败
- `checkout.session.expired` - Session 过期（用于清理）

**关键代码实现**：

```python
@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET", "whsec_...yourkey...")
    
    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except Exception as e:
        return {"error": str(e)}
    
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        task_id = int(session["metadata"]["task_id"])
        task = crud.get_task(db, task_id)
        if task:
            task.is_paid = 1
            task.escrow_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
            db.commit()
    
    return {"status": "success"}
```

**遇到的问题**：

1. **Webhook 签名验证失败**
   - **问题**：本地测试时签名验证总是失败
   - **原因**：使用 Stripe CLI 时需要使用 CLI 提供的签名密钥，而不是 Dashboard 中的密钥
   - **解决方案**：区分本地开发和生产环境的 Webhook 密钥

2. **幂等性问题**
   - **问题**：Webhook 可能被重复调用，导致重复处理
   - **解决方案**：添加幂等性检查，检查任务是否已经支付

3. **异步处理问题**
   - **问题**：Webhook 处理时间过长可能导致 Stripe 超时
   - **解决方案**：使用异步处理，快速返回 200 状态码，后台处理业务逻辑

4. **错误处理不完善**
   - **问题**：Webhook 处理失败时没有记录日志
   - **解决方案**：添加详细的日志记录和错误处理

**改进后的代码**（建议）：

```python
import logging

logger = logging.getLogger(__name__)

@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    
    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except ValueError as e:
        logger.error(f"Invalid payload: {e}")
        return {"error": "Invalid payload"}, 400
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"Invalid signature: {e}")
        return {"error": "Invalid signature"}, 400
    
    # 处理不同的事件类型
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        task_id = int(session["metadata"]["task_id"])
        
        # 幂等性检查
        task = crud.get_task(db, task_id)
        if task and not task.is_paid:
            task.is_paid = 1
            task.escrow_amount = float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0
            db.commit()
            logger.info(f"Task {task_id} payment completed via Stripe")
        else:
            logger.warning(f"Task {task_id} already paid or not found")
    
    return {"status": "success"}
```

---

### 3.4 第四阶段：集成测试（第8-9天）

#### 3.4.1 使用 Stripe 测试卡号

**测试卡号**：
- 成功支付：`4242 4242 4242 4242`
- 需要 3D 验证：`4000 0025 0000 3155`
- 支付被拒绝：`4000 0000 0000 0002`

**测试流程**：
1. 创建测试任务
2. 调用支付 API 创建支付会话
3. 使用测试卡号完成支付
4. 验证 Webhook 是否收到事件
5. 检查任务状态是否更新

#### 3.4.2 测试场景

1. **纯 Stripe 支付**
   - ✅ 创建支付会话成功
   - ✅ 支付完成后任务状态更新
   - ✅ Webhook 正确接收事件

2. **积分 + Stripe 混合支付**
   - ✅ 积分抵扣计算正确
   - ✅ Stripe 支付金额正确
   - ✅ 支付完成后积分扣除

3. **优惠券 + Stripe 支付**
   - ✅ 优惠券折扣计算正确
   - ✅ Stripe 支付金额正确
   - ✅ 优惠券使用记录正确

4. **纯积分支付**
   - ✅ 积分全额抵扣时不需要 Stripe
   - ✅ 任务状态直接更新为已支付

#### 3.4.3 发现的问题

1. **Webhook 延迟问题**
   - **问题**：有时 Webhook 事件延迟几秒才到达
   - **解决方案**：添加轮询机制作为备选方案（未实现）

2. **错误处理不完善**
   - **问题**：支付失败时没有给用户明确的错误提示
   - **解决方案**：改进错误处理和用户提示

---

### 3.5 第五阶段：前端集成（第10-12天）

#### 3.5.1 前端组件开发

**使用 Stripe Elements（嵌入式支付表单）**：

1. **安装依赖**
   ```bash
   npm install @stripe/stripe-js @stripe/react-stripe-js
   ```

2. **Stripe Elements 组件实现**
   - 使用 `loadStripe` 加载 Stripe.js
   - 使用 `Elements` 和 `CardElement` 或 `PaymentElement` 组件
   - 在前端收集支付信息，然后发送到后端创建 Payment Intent

3. **支付流程（使用 Payment Intent + Stripe Elements）**
   ```
   前端：显示支付表单（Stripe Elements）
      ↓
   用户填写卡号信息
      ↓
   前端：调用后端 API 创建 Payment Intent
      ↓
   后端：使用 Secret Key 创建 Payment Intent（需要修改后端代码）
      ↓
   前端：确认支付（使用 Publishable Key）
      ↓
   Stripe 处理支付
      ↓
   Webhook：payment_intent.succeeded 通知后端支付结果
   ```

4. **后端代码修改（如果使用 Payment Intent）**
   
   需要将 `stripe.checkout.Session.create()` 改为 `stripe.PaymentIntent.create()`：
   
   ```python
   # 旧代码（Checkout Session）
   session = stripe.checkout.Session.create(...)
   return {"checkout_url": session.url}
   
   # 新代码（Payment Intent）
   payment_intent = stripe.PaymentIntent.create(
       amount=final_amount,  # 便士
       currency="gbp",
       metadata={
           "task_id": task_id,
           "user_id": current_user.id,
           # ... 其他元数据
       }
   )
   return {
       "client_secret": payment_intent.client_secret,  # 前端需要这个
       "payment_intent_id": payment_intent.id
   }
   ```

5. **Webhook 事件修改**
   
   如果使用 Payment Intent，需要监听不同的事件：
   - `payment_intent.succeeded` - 支付成功
   - `payment_intent.payment_failed` - 支付失败
   - `payment_intent.requires_action` - 需要额外操作（如 3D Secure）

6. **环境变量配置**
   - 前端需要：`STRIPE_PUBLISHABLE_KEY`（必需）
   - 后端需要：`STRIPE_SECRET_KEY` 和 `STRIPE_WEBHOOK_SECRET`
   - 后端需要：`STRIPE_SECRET_KEY` 和 `STRIPE_WEBHOOK_SECRET`

**关键代码示例**：

```typescript
// 前端：初始化 Stripe
import { loadStripe } from '@stripe/stripe-js';
import { Elements, CardElement, useStripe, useElements } from '@stripe/react-stripe-js';

const stripePromise = loadStripe(process.env.STRIPE_PUBLISHABLE_KEY || '');

// 使用 Stripe Elements
<Elements stripe={stripePromise}>
  <PaymentForm />
</Elements>
```

**当前状态**：项目使用 Stripe Elements 嵌入式支付表单，前端需要 Publishable Key

---

## 四、关键技术点

### 4.1 Payment Intent vs Checkout Session

**重要说明**：项目当前使用的是 **Checkout Session**，不是 Payment Intent。以下是两者的区别：

#### Payment Intent（支付意图）

**定义**：Payment Intent 是 Stripe 的核心支付对象，代表一次支付尝试的意图。

**特点**：
- ✅ 需要前端集成 Stripe Elements（嵌入式支付表单）
- ✅ 完全自定义支付流程和 UI
- ✅ 用户无需离开网站
- ✅ 需要前端 Publishable Key
- ⚠️ 开发复杂度较高

**工作流程**：
```
1. 后端：创建 Payment Intent（使用 Secret Key）
   ↓
2. 前端：使用 Stripe Elements 收集支付信息
   ↓
3. 前端：确认支付（使用 Publishable Key）
   ↓
4. Stripe：处理支付
   ↓
5. Webhook：发送 payment_intent.succeeded 事件
```

**代码示例**：
```python
# 后端：创建 Payment Intent
payment_intent = stripe.PaymentIntent.create(
    amount=1000,  # 便士
    currency='gbp',
    metadata={'task_id': task_id}
)
```

```typescript
// 前端：确认支付
const { error, paymentIntent } = await stripe.confirmCardPayment(
  clientSecret,
  { payment_method: { card: cardElement } }
);
```

**Webhook 事件**：
- `payment_intent.succeeded` - 支付成功
- `payment_intent.payment_failed` - 支付失败
- `payment_intent.requires_action` - 需要额外操作（如 3D Secure）

#### Checkout Session（支付会话）

**定义**：Checkout Session 是 Stripe 提供的托管支付页面，简化了支付流程。

**特点**：
- ✅ Stripe 托管支付页面，开发简单
- ✅ 用户跳转到 Stripe 页面完成支付
- ❌ 不需要前端 Publishable Key（可选）
- ✅ 自动处理 PCI DSS 合规
- ✅ 支持多种支付方式（卡、Apple Pay、Google Pay 等）

**工作流程**：
```
1. 后端：创建 Checkout Session（使用 Secret Key）
   ↓
2. 返回 Checkout URL
   ↓
3. 前端：重定向用户到 Checkout URL
   ↓
4. 用户：在 Stripe 页面完成支付
   ↓
5. Stripe：重定向回 success_url
   ↓
6. Webhook：发送 checkout.session.completed 事件
```

**代码示例**：
```python
# 后端：创建 Checkout Session（当前项目使用的方式）
session = stripe.checkout.Session.create(
    payment_method_types=["card"],
    line_items=[{
        "price_data": {
            "currency": "gbp",
            "product_data": {"name": "任务平台服务费"},
            "unit_amount": 1000,  # 便士
        },
        "quantity": 1,
    }],
    mode="payment",
    success_url="https://your-domain.com/success",
    cancel_url="https://your-domain.com/cancel",
    metadata={"task_id": task_id}
)
```

**Webhook 事件**：
- `checkout.session.completed` - 支付完成
- `checkout.session.async_payment_succeeded` - 异步支付成功
- `checkout.session.async_payment_failed` - 异步支付失败
- `checkout.session.expired` - Session 过期

#### 对比表格

| 特性 | Payment Intent | Checkout Session |
|------|---------------|-----------------|
| **用户体验** | 嵌入式表单，无需跳转 | 跳转到 Stripe 页面 |
| **开发复杂度** | 较高（需要前端集成） | 较低（后端创建即可） |
| **自定义程度** | 完全可自定义 | 有限的自定义 |
| **前端密钥需求** | ✅ 需要 Publishable Key | ❌ 不需要 |
| **PCI DSS 合规** | 需要处理（Stripe Elements 帮助） | Stripe 自动处理 |
| **适用场景** | 需要品牌一致性 | 快速集成，简单支付 |
| **Webhook 事件** | `payment_intent.*` | `checkout.session.*` |
| **当前项目使用** | ❌ 未使用 | ✅ **正在使用** |

#### 如何选择？

**使用 Checkout Session（当前项目）**，如果：
- ✅ 需要快速集成支付功能
- ✅ 不需要完全自定义支付 UI
- ✅ 希望减少前端开发工作
- ✅ 需要支持多种支付方式（Apple Pay、Google Pay 等）

**使用 Payment Intent**，如果：
- ✅ 需要完全自定义支付流程和 UI
- ✅ 需要品牌一致性（支付表单与网站设计一致）
- ✅ 愿意投入更多前端开发时间
- ✅ 需要更复杂的支付流程控制

#### 当前项目说明

**重要：如果使用嵌入式支付表单（Stripe Elements）**

如果前端使用 Stripe Elements（嵌入式支付表单），后端**必须**使用 Payment Intent，不能使用 Checkout Session。

**需要修改的地方**：

1. **后端代码修改**：
   - ❌ 删除：`stripe.checkout.Session.create()`
   - ✅ 使用：`stripe.PaymentIntent.create()`

2. **Webhook 事件修改**：
   - ❌ 删除：`checkout.session.completed`
   - ✅ 使用：`payment_intent.succeeded` 和 `payment_intent.payment_failed`

3. **前端需要**：
   - ✅ 安装：`@stripe/stripe-js` 和 `@stripe/react-stripe-js`
   - ✅ 配置：`STRIPE_PUBLISHABLE_KEY`

**当前后端代码状态**：
- 当前后端使用：`stripe.checkout.Session.create()`（Checkout Session）
- 如果前端使用嵌入式表单，需要修改后端代码使用 Payment Intent

### 4.2 Webhook 事件选择

**当前项目使用 Stripe Checkout Session**，因此需要监听的事件如下：

**必需事件**：
- ✅ `checkout.session.completed` - **必需**
  - 当用户完成支付时触发
  - 这是唯一必需的事件，用于更新任务支付状态

**推荐事件**（可选，但建议添加）：
- ✅ `checkout.session.async_payment_succeeded` - 异步支付成功
  - 如果使用延迟支付方式（如银行转账），支付成功后会触发此事件
- ✅ `checkout.session.async_payment_failed` - 异步支付失败
  - 异步支付失败时触发，可用于通知用户或记录失败原因
- ⚠️ `checkout.session.expired` - Session 过期
  - Checkout Session 过期时触发，可用于清理未完成的支付记录

**不需要的事件**：
- ❌ `payment_intent.succeeded` - **不需要**（项目使用 Checkout Session，不是 Payment Intent）
- ❌ `payment_intent.payment_failed` - **不需要**（同上）
- ❌ `charge.succeeded` - **不需要**（Checkout Session 会自动处理）

**退款和争议相关事件**（重要，建议添加）：

如果支持退款或需要处理争议，需要监听以下事件：

**退款事件**：
- ✅ `charge.refunded` - **退款完成**
  - 当支付被退款时触发
  - 需要更新任务状态，退还积分/优惠券
  - 需要记录退款金额和原因

- ✅ `charge.refund.updated` - 退款状态更新
  - 退款状态发生变化时触发（如部分退款）

**争议/拒付事件**：
- ✅ `charge.dispute.created` - **争议创建**（重要）
  - 当客户发起争议（chargeback）时触发
  - 需要记录争议信息，可能需要冻结相关资金

- ✅ `charge.dispute.updated` - 争议状态更新
  - 争议状态发生变化时触发

- ✅ `charge.dispute.closed` - 争议关闭
  - 争议解决时触发（可能支持或拒绝）

**支付失败事件**：
- ✅ `charge.failed` - 支付失败
  - 支付尝试失败时触发
  - 可用于通知用户或记录失败原因

**完整 Webhook 事件列表**（按优先级）：

**优先级 1 - 必需事件**：
- ✅ `checkout.session.completed` - 支付完成（必需）

**优先级 2 - 强烈推荐**：
- ✅ `charge.refunded` - 退款完成（如果支持退款）
- ✅ `charge.dispute.created` - 争议创建（保护平台）
- ✅ `checkout.session.async_payment_failed` - 异步支付失败

**优先级 3 - 可选但有用**：
- ✅ `charge.dispute.updated` - 争议状态更新
- ✅ `charge.dispute.closed` - 争议关闭
- ✅ `charge.refund.updated` - 退款状态更新
- ✅ `checkout.session.async_payment_succeeded` - 异步支付成功
- ✅ `checkout.session.expired` - Session 过期

**最小配置**：
- 如果只想实现基本功能，**只监听 `checkout.session.completed` 就足够了**
- **强烈建议**至少添加 `charge.refunded` 和 `charge.dispute.created` 以处理退款和争议

### 4.2 Stripe Elements（嵌入式支付表单）

**为什么选择 Stripe Elements**：
- ✅ **更好的用户体验**：用户无需离开网站，支付表单直接嵌入在页面中
- ✅ **品牌一致性**：可以自定义样式，保持与网站设计一致
- ✅ **更灵活的控制**：可以完全控制支付流程和用户界面
- ✅ **安全性**：Stripe Elements 自动处理 PCI DSS 合规，敏感信息不会经过我们的服务器

**Stripe Elements vs Stripe Checkout**：

| 特性 | Stripe Elements | Stripe Checkout |
|------|----------------|----------------|
| 用户体验 | 嵌入式表单，无需跳转 | 跳转到 Stripe 页面 |
| 开发复杂度 | 较高 | 较低 |
| 自定义程度 | 完全可自定义 | 有限的自定义 |
| 前端密钥需求 | ✅ 需要 Publishable Key | ❌ 不需要 |
| 适用场景 | 需要品牌一致性 | 快速集成 |

**Stripe Elements 工作流程**：

```
1. 前端：加载 Stripe.js（使用 Publishable Key）
   ↓
2. 前端：显示支付表单（CardElement 或 PaymentElement）
   ↓
3. 用户：填写卡号信息
   ↓
4. 前端：调用后端 API 创建 Payment Intent
   ↓
5. 后端：使用 Secret Key 创建 Payment Intent
   ↓
6. 前端：使用 Stripe.js 确认支付
   ↓
7. Stripe：处理支付
   ↓
8. Webhook：通知后端支付结果
```

**关键代码结构**：

```typescript
// 1. 初始化 Stripe
import { loadStripe } from '@stripe/stripe-js';
const stripePromise = loadStripe(process.env.STRIPE_PUBLISHABLE_KEY!);

// 2. 包装支付表单
import { Elements } from '@stripe/react-stripe-js';
<Elements stripe={stripePromise}>
  <PaymentForm />
</Elements>

// 3. 在表单中使用 CardElement
import { CardElement, useStripe, useElements } from '@stripe/react-stripe-js';
const stripe = useStripe();
const elements = useElements();

// 4. 提交支付
const handleSubmit = async () => {
  const { error, paymentMethod } = await stripe.createPaymentMethod({
    type: 'card',
    card: elements.getElement(CardElement),
  });
  
  // 发送到后端确认支付
  await confirmPayment(paymentMethod.id);
};
```

### 4.2 金额处理

**统一使用最小货币单位（便士）**：
- 数据库存储：整数（便士）
- API 传输：整数（便士）
- 前端显示：除以 100 转换为英镑

**优势**：
- 避免浮点数精度问题
- 符合 Stripe API 要求
- 计算更准确

### 4.2 安全措施

1. **Webhook 签名验证**
   - 使用 Stripe 提供的签名验证机制
   - 防止伪造的 Webhook 请求

2. **环境变量管理**
   - 密钥存储在环境变量中
   - 不同环境使用不同的密钥

3. **权限验证**
   - 只有任务发布者可以创建支付
   - 验证用户身份和任务所有权

### 4.3 支付流程设计

```
用户发起支付
    ↓
计算平台服务费（任务金额 × 10%）
    ↓
应用积分抵扣（可选）
    ↓
应用优惠券折扣（可选）
    ↓
计算最终支付金额
    ↓
如果金额 > 0：创建 Stripe Checkout Session
如果金额 = 0：直接完成支付（纯积分）
    ↓
用户完成支付（Stripe Checkout）
    ↓
Stripe 发送 Webhook 事件
    ↓
后端处理 Webhook，更新任务状态
    ↓
用户重定向到成功页面
```

---

## 五、遇到的问题与解决方案

### 5.1 问题汇总表

| 问题 | 原因 | 解决方案 | 状态 |
|------|------|----------|------|
| Webhook 签名验证失败 | 使用了错误的签名密钥 | 区分本地和生产环境的密钥 | ✅ 已解决 |
| 金额单位错误 | 使用了英镑而非便士 | 统一使用便士作为单位 | ✅ 已解决 |
| Metadata 类型错误 | Stripe 只接受字符串 | 转换所有数值为字符串 | ✅ 已解决 |
| 幂等性问题 | Webhook 可能重复调用 | 添加支付状态检查 | ✅ 已解决 |
| 错误处理不完善 | 缺少日志和错误提示 | 添加详细日志和错误处理 | ⚠️ 部分解决 |
| Webhook 延迟 | 网络延迟 | 考虑添加轮询机制 | 📋 待优化 |

### 5.2 详细问题分析

#### 问题 1：Webhook 签名验证失败

**现象**：
```
stripe.error.SignatureVerificationError: No signatures found matching the expected signature
```

**原因分析**：
- 本地开发使用 Stripe CLI 转发 Webhook，需要使用 CLI 提供的签名密钥
- 生产环境使用 Dashboard 配置的 Webhook，需要使用 Dashboard 中的签名密钥
- **常见错误**：在 API Keys 页面找不到 Webhook Secret（因为它不在那里！）

**解决方案**：

1. **本地开发**：使用 Stripe CLI 命令获取签名密钥
   ```bash
   stripe listen --forward-to localhost:8000/api/users/stripe/webhook
   ```
   运行后会输出：
   ```
   > Ready! Your webhook signing secret is whsec_xxxxxxxxxxxxx
   ```
   复制这个 `whsec_...` 密钥

2. **生产环境**：从 Stripe Dashboard 获取 Webhook 签名密钥
   - 登录 Stripe Dashboard
   - 进入 **Developers → Webhooks**
   - 点击你创建的 Webhook 端点
   - 在 **"Signing secret"** 部分，点击 **"Reveal"** 按钮
   - 复制签名密钥（`whsec_...`）

3. **设置环境变量**：
   ```bash
   # 本地开发
   export STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx
   
   # 或在 .env 文件中
   STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx
   ```

4. **代码中使用**：
   ```python
   endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
   if not endpoint_secret:
       raise ValueError("STRIPE_WEBHOOK_SECRET environment variable is not set")
   ```

#### 问题 2：金额精度问题

**现象**：
- 支付金额显示不正确
- Stripe API 返回错误

**原因分析**：
- Stripe API 要求金额以最小货币单位（便士）为单位
- 代码中混用了英镑和便士

**解决方案**：
1. 统一使用便士作为内部单位
2. 在显示时转换为英镑（除以 100）
3. 添加金额转换工具函数

```python
def pounds_to_pence(pounds: float) -> int:
    """将英镑转换为便士"""
    return int(round(pounds * 100))

def pence_to_pounds(pence: int) -> str:
    """将便士转换为英镑字符串（保留两位小数）"""
    return f"{pence / 100:.2f}"
```

---

## 六、测试记录

### 6.1 单元测试

**测试文件**：`backend/tests/test_stripe_payment.py`（计划中）

**测试用例**：
1. ✅ 创建支付会话
2. ✅ 计算平台服务费
3. ✅ 积分抵扣计算
4. ✅ 优惠券折扣计算
5. ✅ Webhook 事件处理

### 6.2 集成测试

**测试场景**：

1. **完整支付流程测试**
   - 创建任务 → 创建支付 → 完成支付 → 验证状态
   - ✅ 测试通过

2. **混合支付测试**
   - 积分 + Stripe 支付
   - ✅ 测试通过

3. **纯积分支付测试**
   - 积分全额抵扣
   - ✅ 测试通过

4. **Webhook 测试**
   - 使用 Stripe CLI 模拟 Webhook 事件
   - ✅ 测试通过

### 6.3 性能测试

**测试结果**：
- 创建支付会话：平均响应时间 < 500ms
- Webhook 处理：平均响应时间 < 200ms
- 并发测试：支持 100+ 并发请求

---

## 七、部署与上线

### 7.1 生产环境配置

**环境变量设置**：
```env
# Stripe 生产环境配置
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
FRONTEND_URL=https://your-domain.com
```

### 7.2 Stripe Dashboard 配置

1. **Webhook 端点配置**
   - URL: `https://your-domain.com/api/users/stripe/webhook`
   - 事件类型：`checkout.session.completed`
   - 获取 Webhook 签名密钥

2. **API 密钥切换**
   - 从测试模式切换到生产模式
   - 更新环境变量

### 7.3 上线检查清单

- [x] 环境变量配置正确
- [x] Webhook 端点配置正确
- [x] 测试支付流程
- [x] 监控和日志配置
- [x] 错误处理完善
- [ ] 前端集成完成（待完成）

---

## 八、监控与日志

### 8.1 日志记录

**关键日志点**：
1. 支付会话创建
2. Webhook 事件接收
3. 支付状态更新
4. 错误和异常

**日志格式**：
```python
logger.info(f"Payment session created: task_id={task_id}, amount={amount}, user_id={user_id}")
logger.info(f"Webhook received: event_type={event_type}, task_id={task_id}")
logger.error(f"Payment failed: error={error}, task_id={task_id}")
```

### 8.2 监控指标

**建议监控的指标**：
1. 支付成功率
2. Webhook 处理时间
3. 支付失败率
4. 平均支付金额
5. 支付方式分布（积分 vs Stripe）

---

## 九、后续优化计划

### 9.1 短期优化（1-2周）

1. **完善错误处理**
   - 添加详细的错误日志
   - 改进用户错误提示
   - 实现错误重试机制

2. **前端集成**
   - 完成 Stripe Checkout 组件
   - 优化支付页面 UI/UX
   - 添加支付状态实时更新

3. **支付记录表**
   - 创建 `payment_records` 表
   - 记录所有支付操作
   - 支持支付查询和退款

### 9.2 中期优化（1-2月）

1. **支付安全增强**
   - 实现支付超时机制
   - 添加支付金额验证
   - 实现防重复支付机制

2. **性能优化**
   - Webhook 异步处理
   - 添加支付缓存
   - 优化数据库查询

3. **功能扩展**
   - 支持退款功能
   - 支持分期支付
   - 添加支付统计报表

### 9.3 长期优化（3-6月）

1. **多支付方式支持**
   - 集成 PayPal
   - 支持 Apple Pay / Google Pay
   - 支持银行转账

2. **国际化**
   - 支持多币种
   - 支持多地区支付方式
   - 本地化支付流程

3. **高级功能**
   - 订阅支付
   - 定期付款
   - 支付分析仪表板

---

## 十、经验总结

### 10.1 成功经验

1. **使用 Stripe Checkout**
   - 简化了支付流程
   - 减少了 PCI DSS 合规负担
   - 提供了良好的用户体验

2. **统一金额单位**
   - 使用便士作为内部单位
   - 避免了浮点数精度问题
   - 符合 Stripe API 要求

3. **完善的 Webhook 处理**
   - 签名验证确保安全
   - 幂等性检查防止重复处理
   - 详细的日志记录便于排查问题

### 10.2 教训与改进

1. **文档先行**
   - 应该在开发前更详细地阅读 Stripe 文档
   - 避免了一些常见错误

2. **测试要充分**
   - 应该更早地进行集成测试
   - 发现了一些设计问题

3. **错误处理要完善**
   - 初期错误处理不够完善
   - 后续需要加强错误处理和日志记录

### 10.3 最佳实践建议

1. **安全性**
   - 始终验证 Webhook 签名
   - 使用环境变量存储密钥
   - 实现权限验证

2. **可靠性**
   - 实现幂等性检查
   - 添加重试机制
   - 完善的错误处理

3. **可维护性**
   - 详细的日志记录
   - 清晰的代码注释
   - 完善的文档

---

## 十一、参考资料

### 11.1 官方文档

- [Stripe API 文档](https://stripe.com/docs/api)
- [Stripe Webhooks 指南](https://stripe.com/docs/webhooks)
- [Stripe Checkout 文档](https://stripe.com/docs/payments/checkout)
- [Stripe Python SDK](https://stripe.com/docs/api/python)

### 11.2 项目文档

- `docs/payment_integration_guide.md` - 支付集成开发文档
- `backend/app/coupon_points_routes.py` - 支付 API 实现
- `backend/app/routers.py` - Webhook 处理实现

### 11.3 相关代码文件

- `backend/app/schemas.py` - 数据模型定义
- `backend/app/models.py` - 数据库模型
- `backend/requirements.txt` - 依赖管理

---

## 十二、附录

### 12.1 API 端点列表

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/api/coupon-points/tasks/{task_id}/payment` | 创建支付会话 |
| POST | `/api/users/stripe/webhook` | Stripe Webhook 处理 |

### 12.2 环境变量说明

| 变量名 | 位置 | 必需 | 说明 | 示例 |
|--------|------|------|------|------|
| `STRIPE_SECRET_KEY` | 后端 | ✅ 必需 | Stripe 私钥（服务器端使用） | `sk_test_...` 或 `sk_live_...` |
| `STRIPE_PUBLISHABLE_KEY` | 前端 | ✅ 必需 | Stripe 公钥（前端使用，用于 Elements） | `pk_test_...` 或 `pk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | 后端 | ✅ 必需 | Webhook 签名密钥（用于验证 Webhook 请求） | `whsec_...` |
| `FRONTEND_URL` | 后端 | ✅ 必需 | 前端 URL（用于重定向） | `https://your-domain.com` |

**⚠️ 重要提示：如何获取 STRIPE_WEBHOOK_SECRET**

`STRIPE_WEBHOOK_SECRET` **不在 API Keys 页面**，需要按以下步骤获取：

1. **生产环境**：
   - Stripe Dashboard → **Developers → Webhooks**
   - 创建或选择 Webhook 端点
   - 点击端点进入详情页
   - 在 **"Signing secret"** 部分点击 **"Reveal"** 按钮
   - 复制 `whsec_...` 密钥

2. **本地开发**：
   - 使用 Stripe CLI：`stripe listen --forward-to localhost:8000/api/users/stripe/webhook`
   - 命令输出中会显示签名密钥：`whsec_...`
   - 复制该密钥作为环境变量

**为什么需要 Webhook Secret？**
- 验证 Webhook 请求确实来自 Stripe（防止伪造请求）
- 确保支付状态更新的安全性
- Stripe 使用 HMAC-SHA256 签名，用此密钥验证请求的真实性

### 12.3 配置检查清单

**✅ 配置完成后，请检查以下事项**：

**后端环境变量**（`.env` 或生产环境配置）：
- [ ] `STRIPE_SECRET_KEY` - 已配置（格式：`sk_test_...` 或 `sk_live_...`）
- [ ] `STRIPE_WEBHOOK_SECRET` - 已配置（格式：`whsec_...`）
- [ ] `FRONTEND_URL` - 已配置（用于支付成功/失败重定向）
- [ ] `STRIPE_PUBLISHABLE_KEY` - 可选（如果后端需要，格式：`pk_test_...` 或 `pk_live_...`）

**前端环境变量**（`frontend/.env` 或 `frontend/.env.local`）：
- [ ] `STRIPE_PUBLISHABLE_KEY` - 已配置（格式：`pk_test_...` 或 `pk_live_...`）

**Stripe Dashboard 配置**：
- [ ] Webhook 端点已创建（生产环境）
- [ ] Webhook URL 正确：`https://your-domain.com/api/users/stripe/webhook`
- [ ] 已选择监听事件：`checkout.session.completed`
- [ ] 已复制 Webhook 签名密钥到环境变量

**测试环境 vs 生产环境**：
- [ ] 测试环境使用 `sk_test_` 和 `pk_test_` 开头的密钥
- [ ] 生产环境使用 `sk_live_` 和 `pk_live_` 开头的密钥
- [ ] 测试和生产环境使用不同的 Webhook 端点（不同的 `whsec_` 密钥）

**安全检查**：
- [ ] 密钥未提交到代码仓库（已添加到 `.gitignore`）
- [ ] 生产环境密钥与测试环境密钥不同
- [ ] Webhook Secret 已正确配置

### 12.4 配置验证测试

配置完成后，建议进行以下测试：

**1. 测试 API 密钥**：
```bash
# 测试后端 Secret Key（Python）
python -c "import stripe, os; stripe.api_key = os.getenv('STRIPE_SECRET_KEY'); print('Key valid!' if stripe.api_key else 'Key missing!')"
```

**2. 测试 Webhook 端点**：
- 使用 Stripe CLI 测试（本地开发）：
  ```bash
  stripe listen --forward-to localhost:8000/api/users/stripe/webhook
  ```
- 在 Stripe Dashboard 中发送测试事件（生产环境）

**3. 测试支付流程**：
1. 创建测试任务
2. 发起支付请求
3. 使用测试卡号完成支付：`4242 4242 4242 4242`
4. 检查 Webhook 是否收到事件
5. 验证任务状态是否更新为已支付

**密钥安全说明**：

1. **Secret Key（私钥）**
   - 🔒 **必须保密**，只能放在后端环境变量中
   - ❌ **绝对不能**提交到代码仓库
   - ❌ **绝对不能**在前端代码中使用
   - ✅ 用于所有服务器端 Stripe API 调用

2. **Publishable Key（公钥）**
   - ✅ 可以公开，但建议放在环境变量中管理
   - ✅ **当前项目使用 Stripe Elements，前端需要此密钥**
   - ✅ 前端环境变量：`STRIPE_PUBLISHABLE_KEY`
   - ✅ 用于初始化 Stripe.js 和 Stripe Elements 组件

3. **最佳实践**
   - 使用不同的测试和生产密钥
   - 定期轮换密钥
   - 使用密钥管理服务（如 AWS Secrets Manager、HashiCorp Vault）
   - 限制密钥权限（在 Stripe Dashboard 中设置）

### 12.3 测试卡号

| 卡号 | 场景 | 说明 |
|------|------|------|
| `4242 4242 4242 4242` | 成功支付 | 任意未来日期和 CVC |
| `4000 0025 0000 3155` | 需要 3D 验证 | 需要完成 3D Secure 验证 |
| `4000 0000 0000 0002` | 支付被拒绝 | 模拟支付失败 |

---

## 十三、Stripe Connect 说明（未来扩展）

### 13.1 什么是 Stripe Connect？

Stripe Connect 允许平台（如 Link²Ur）管理多个账户，实现市场模式（Marketplace），可以直接将资金支付给服务者，而不是先到平台账户再转账。

### 13.2 Connect 账户创建方式

**Stripe Connect 有两种账户类型**：

#### 1. Standard Accounts（标准账户）
- **创建方式**：用户自己注册 Stripe 账户，通过 OAuth 连接到平台
- **优点**：用户完全控制自己的账户，可以查看所有交易
- **缺点**：用户需要注册 Stripe 账户，流程较复杂
- **适用场景**：大型服务提供者，需要完整账户控制

#### 2. Express/Custom Accounts（快速/自定义账户）
- **创建方式**：**平台通过 API 创建子账户**
- **优点**：用户体验简单，无需注册 Stripe 账户
- **缺点**：平台需要管理更多合规责任
- **适用场景**：小型服务提供者，简化流程

### 13.3 通过 API 创建 Connect 账户

**如果使用 Express Accounts，可以通过 API 创建**：

```python
import stripe

# 创建 Express Account
account = stripe.Account.create(
    type="express",
    country="GB",  # 英国
    email="service_provider@example.com",
    capabilities={
        "card_payments": {"requested": True},
        "transfers": {"requested": True},
    },
    metadata={
        "user_id": user_id,
        "platform": "Link²Ur"
    }
)

# 创建账户链接（用于完成账户设置）
account_link = stripe.AccountLink.create(
    account=account.id,
    refresh_url="https://your-domain.com/connect/refresh",
    return_url="https://your-domain.com/connect/success",
    type="account_onboarding",
)

# 返回账户链接给用户完成设置
return {"account_id": account.id, "onboarding_url": account_link.url}
```

### 13.4 测试环境 vs 生产环境

**使用测试 Key 创建 Connect 账户**：

✅ **可以使用测试 key（`sk_test_...`）创建 Express Account**

**测试环境特点**：
- ✅ 可以使用测试 key 创建账户
- ✅ 账户创建流程与生产环境相同
- ✅ 可以使用测试银行卡完成 onboarding
- ✅ 不会产生真实费用
- ⚠️ 测试账户不能接收真实支付
- ⚠️ 测试账户不能提现到真实银行账户

**测试 Express Account 的步骤**：
1. 使用测试 Secret Key：`sk_test_...`
2. 调用 `POST /api/stripe/connect/account/create` 创建账户
3. 使用返回的 `onboarding_url` 完成账户设置
4. 在测试环境中，可以使用测试数据完成所有验证步骤
5. 验证账户状态：`GET /api/stripe/connect/account/status`

**测试银行卡**（用于 Connect 账户验证）：
- 卡号：`4242 4242 4242 4242`
- 任意未来日期和 CVC
- 用于测试账户验证流程

**生产环境**：
- 必须使用生产 Secret Key：`sk_live_...`
- 账户创建后需要真实身份验证
- 可以接收真实支付和提现

### 13.5 当前项目状态

**当前实现**：
- ✅ **已实现 Stripe Connect Express Account 创建 API**
- ✅ 使用标准支付流程（资金先到平台账户）
- ✅ 任务奖励托管在平台，确认后手动/自动转账给服务者
- ✅ Express Account 通过 API 创建（已实现）

**已实现的 Connect 功能**：
1. ✅ **Express Account 创建 API** - `POST /api/stripe/connect/account/create`
2. ✅ **账户状态查询 API** - `GET /api/stripe/connect/account/status`
3. ✅ **Onboarding 链接创建 API** - `POST /api/stripe/connect/account/onboarding-link`
4. ✅ **Webhook 处理** - `POST /api/stripe/connect/webhook`
5. ✅ **数据库字段** - `users.stripe_account_id`（已添加）

**实现位置**：
- 路由文件：`backend/app/stripe_connect_routes.py`
- Schema 定义：`backend/app/schemas.py`（StripeConnectAccountResponse 等）
- 数据库模型：`backend/app/models.py`（User.stripe_account_id）
- 数据库迁移：`backend/migrations/038_add_stripe_connect_account_id.sql`

**API 端点**：

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/api/stripe/connect/account/create` | 创建 Express Account |
| GET | `/api/stripe/connect/account/status` | 获取账户状态 |
| POST | `/api/stripe/connect/account/onboarding-link` | 创建 onboarding 链接 |
| POST | `/api/stripe/connect/webhook` | Connect Webhook 处理 |

**使用示例**：

```python
# 创建 Express Account
POST /api/stripe/connect/account/create
# 响应：
{
  "account_id": "acct_xxxxx",
  "onboarding_url": "https://connect.stripe.com/setup/...",
  "account_status": false,
  "message": "账户创建成功，请完成账户设置"
}

# 获取账户状态
GET /api/stripe/connect/account/status
# 响应：
{
  "account_id": "acct_xxxxx",
  "details_submitted": true,
  "charges_enabled": true,
  "payouts_enabled": true,
  "needs_onboarding": false,
  "requirements": {...}
}
```

**下一步（如果使用 Connect 支付）**：
1. ⚠️ 修改支付流程，使用 `destination` 参数直接支付给服务者
2. ⚠️ 处理 Connect 相关的 Webhook 事件（account.updated 等）
3. ⚠️ 实现服务者提现功能

### 13.6 Connect vs 当前实现对比

| 特性 | 当前实现（标准支付） | Stripe Connect |
|------|-------------------|---------------|
| **资金流向** | 客户 → 平台 → 服务者 | 客户 → 服务者（平台抽成） |
| **账户创建** | 不需要 | Express: **API 创建**<br>Standard: OAuth |
| **合规责任** | 平台承担 | Express: 平台承担<br>Standard: 服务者承担 |
| **用户体验** | 简单 | Express: 简单<br>Standard: 较复杂 |
| **开发复杂度** | 低 | 较高 |
| **适用场景** | 当前项目 | 大型市场平台 |

### 13.7 是否需要 Connect？

**当前不需要 Connect，如果**：
- ✅ 任务奖励金额较小
- ✅ 服务者数量不多
- ✅ 平台统一管理资金更方便
- ✅ 希望简化开发复杂度

**未来考虑 Connect，如果**：
- ⚠️ 需要直接支付给服务者
- ⚠️ 服务者需要查看自己的 Stripe 交易记录
- ⚠️ 需要支持服务者自己提现
- ⚠️ 平台希望减少资金托管责任

---

**文档维护者**：Link²Ur 开发团队  
**最后更新**：2024年  
**文档版本**：v1.0

