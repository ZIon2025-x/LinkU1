# Stripe 和 PayPal 支付集成开发文档

## 目录

1. [概述](#概述)
2. [技术栈](#技术栈)
3. [Stripe 集成](#stripe-集成)
4. [PayPal 集成](#paypal-集成)
5. [数据库设计](#数据库设计)
6. [API 接口设计](#api-接口设计)
7. [前端集成](#前端集成)
8. [Webhook 处理](#webhook-处理)
9. [测试指南](#测试指南)
10. [部署配置](#部署配置)
11. [安全注意事项](#安全注意事项)
12. [故障排查](#故障排查)

---

## 概述

本文档详细说明如何在 LinkU 平台中集成 Stripe 和 PayPal 支付系统。平台支持多种支付方式：

- **Stripe**：信用卡/借记卡支付
- **PayPal**：PayPal 账户支付
- **积分支付**：平台内部积分系统
- **混合支付**：积分 + 第三方支付的组合

### 支付场景

当前支付主要用于以下场景：

1. **任务平台服务费支付**：发布任务时需要支付平台服务费（通常为任务金额的 10%）
2. **任务奖励托管**：任务完成后，奖励金额托管在平台，待确认后发放给服务者

### 支付流程

```
用户发起支付
    ↓
计算总金额（平台服务费）
    ↓
应用积分抵扣（可选）
    ↓
应用优惠券折扣（可选）
    ↓
计算最终支付金额
    ↓
如果金额 > 0：创建第三方支付会话（Stripe/PayPal）
如果金额 = 0：直接完成支付（纯积分支付）
    ↓
等待支付完成（Webhook 回调）
    ↓
更新任务状态为已支付
```

---

## 技术栈

### 后端

- **框架**：FastAPI
- **数据库**：PostgreSQL (通过 SQLAlchemy ORM)
- **支付 SDK**：
  - `stripe>=7.0.0,<10.0.0` (已安装)
  - `paypalrestsdk` (需要安装，用于 PayPal)

### 前端

- **框架**：React + TypeScript
- **支付组件**：
  - Stripe: `@stripe/stripe-js` 和 `@stripe/react-stripe-js`
  - PayPal: `@paypal/react-paypal-js`

---

## Stripe 集成

### 1. 环境配置

在 `.env` 或生产环境配置文件中添加：

```env
# Stripe 配置
STRIPE_SECRET_KEY=sk_test_...  # 测试环境密钥
STRIPE_PUBLISHABLE_KEY=pk_test_...  # 测试环境公钥
STRIPE_WEBHOOK_SECRET=whsec_...  # Webhook 签名密钥
```

**生产环境配置**：

```env
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

### 2. 现有代码结构

项目已实现 Stripe 集成，主要代码位于：

- **路由文件**：`backend/app/coupon_points_routes.py` (第 314-543 行)
- **Webhook 处理**：`backend/app/routers.py` (第 2688-2706 行)
- **Schema 定义**：`backend/app/schemas.py` (第 1438-1463 行)

### 3. 核心 API 接口

#### 3.1 创建支付会话

**端点**：`POST /api/coupon-points/tasks/{task_id}/payment`

**请求体**：
```json
{
  "payment_method": "stripe",  // 或 "points", "mixed"
  "points_amount": 0,  // 可选，积分数量（最小货币单位）
  "coupon_code": "DISCOUNT10",  // 可选，优惠券代码
  "user_coupon_id": 123,  // 可选，用户优惠券ID
  "stripe_amount": 1000  // 可选，Stripe支付金额（便士）
}
```

**响应**：
```json
{
  "payment_id": null,
  "fee_type": "application_fee",
  "total_amount": 1000,
  "total_amount_display": "10.00",
  "points_used": 0,
  "points_used_display": null,
  "coupon_discount": 0,
  "coupon_discount_display": null,
  "stripe_amount": 1000,
  "stripe_amount_display": "10.00",
  "currency": "GBP",
  "final_amount": 1000,
  "final_amount_display": "10.00",
  "checkout_url": "https://checkout.stripe.com/pay/cs_test_...",
  "note": "积分仅用于抵扣申请费/平台服务费，任务奖励将按法币结算给服务者"
}
```

#### 3.2 Stripe Webhook 处理

**端点**：`POST /api/users/stripe/webhook`

**功能**：
- 验证 Stripe 签名
- 处理 `checkout.session.completed` 事件
- 更新任务支付状态

**关键代码**：
```python
@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    endpoint_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    
    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except Exception as e:
        return {"error": str(e)}
    
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        task_id = int(session["metadata"]["task_id"])
        # 更新任务状态...
```

### 4. Stripe Dashboard 配置

1. **创建 Webhook 端点**：
   - 登录 Stripe Dashboard
   - 进入 Developers → Webhooks
   - 添加端点：`https://your-domain.com/api/users/stripe/webhook`
   - 选择事件：`checkout.session.completed`
   - 复制 Webhook 签名密钥到环境变量

2. **测试模式**：
   - 使用测试 API 密钥进行开发
   - 测试卡号：`4242 4242 4242 4242`
   - 任意未来日期和 CVC

---

## PayPal 集成

### 1. 安装依赖

在 `backend/requirements.txt` 中添加：

```txt
paypalrestsdk>=1.13.0,<2.0.0
```

或使用 PayPal SDK v2 (推荐)：

```txt
paypalhttp>=1.0.0
```

### 2. 环境配置

在 `.env` 文件中添加：

```env
# PayPal 配置
PAYPAL_CLIENT_ID=your_paypal_client_id
PAYPAL_CLIENT_SECRET=your_paypal_client_secret
PAYPAL_MODE=sandbox  # 或 'live' 用于生产环境
PAYPAL_WEBHOOK_ID=your_webhook_id
```

### 3. 创建 PayPal 支付服务

创建文件 `backend/app/services/paypal_service.py`：

```python
"""
PayPal 支付服务
"""
import os
import logging
from typing import Optional, Dict, Any
from paypalrestsdk import Payment, ResourceNotFound, Api

logger = logging.getLogger(__name__)

class PayPalService:
    """PayPal 支付服务类"""
    
    def __init__(self):
        self.api = Api({
            'mode': os.getenv('PAYPAL_MODE', 'sandbox'),  # 'sandbox' 或 'live'
            'client_id': os.getenv('PAYPAL_CLIENT_ID'),
            'client_secret': os.getenv('PAYPAL_CLIENT_SECRET')
        })
    
    def create_payment(
        self,
        amount: float,
        currency: str = "GBP",
        description: str = "",
        return_url: str = "",
        cancel_url: str = "",
        metadata: Optional[Dict[str, Any]] = None
    ) -> Optional[Dict[str, Any]]:
        """
        创建 PayPal 支付
        
        Args:
            amount: 支付金额（英镑）
            currency: 货币代码
            description: 支付描述
            return_url: 支付成功返回URL
            cancel_url: 支付取消返回URL
            metadata: 元数据（用于存储任务ID等信息）
        
        Returns:
            支付对象字典，包含 approval_url
        """
        try:
            payment = Payment({
                "intent": "sale",
                "payer": {
                    "payment_method": "paypal"
                },
                "redirect_urls": {
                    "return_url": return_url,
                    "cancel_url": cancel_url
                },
                "transactions": [{
                    "item_list": {
                        "items": [{
                            "name": description,
                            "sku": metadata.get("task_id") if metadata else "item",
                            "price": f"{amount:.2f}",
                            "currency": currency,
                            "quantity": 1
                        }]
                    },
                    "amount": {
                        "total": f"{amount:.2f}",
                        "currency": currency
                    },
                    "description": description
                }]
            })
            
            if payment.create():
                logger.info(f"PayPal payment created: {payment.id}")
                
                # 查找 approval_url
                approval_url = None
                for link in payment.links:
                    if link.rel == "approval_url":
                        approval_url = link.href
                        break
                
                return {
                    "payment_id": payment.id,
                    "approval_url": approval_url,
                    "state": payment.state
                }
            else:
                logger.error(f"PayPal payment creation failed: {payment.error}")
                return None
                
        except Exception as e:
            logger.error(f"PayPal payment creation error: {str(e)}")
            return None
    
    def execute_payment(
        self,
        payment_id: str,
        payer_id: str
    ) -> Optional[Dict[str, Any]]:
        """
        执行 PayPal 支付（在用户确认后）
        
        Args:
            payment_id: PayPal 支付ID
            payer_id: 支付者ID（从回调URL获取）
        
        Returns:
            支付执行结果
        """
        try:
            payment = Payment.find(payment_id)
            
            if payment.execute({"payer_id": payer_id}):
                logger.info(f"PayPal payment executed: {payment.id}")
                return {
                    "payment_id": payment.id,
                    "state": payment.state,
                    "transaction_id": payment.transactions[0].related_resources[0].sale.id if payment.transactions else None
                }
            else:
                logger.error(f"PayPal payment execution failed: {payment.error}")
                return None
                
        except ResourceNotFound:
            logger.error(f"PayPal payment not found: {payment_id}")
            return None
        except Exception as e:
            logger.error(f"PayPal payment execution error: {str(e)}")
            return None
    
    def get_payment(self, payment_id: str) -> Optional[Dict[str, Any]]:
        """
        查询支付状态
        
        Args:
            payment_id: PayPal 支付ID
        
        Returns:
            支付信息
        """
        try:
            payment = Payment.find(payment_id)
            return {
                "payment_id": payment.id,
                "state": payment.state,
                "amount": payment.transactions[0].amount.total if payment.transactions else None
            }
        except ResourceNotFound:
            return None
        except Exception as e:
            logger.error(f"PayPal payment query error: {str(e)}")
            return None
```

### 4. 创建 PayPal 路由

在 `backend/app/coupon_points_routes.py` 中添加 PayPal 支付端点：

```python
from app.services.paypal_service import PayPalService

# 在 create_task_payment 函数中添加 PayPal 支持
@router.post("/tasks/{task_id}/payment", response_model=schemas.TaskPaymentResponse)
def create_task_payment(
    task_id: int,
    payment_request: schemas.TaskPaymentRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """创建任务支付（支持积分、优惠券、Stripe和PayPal）"""
    # ... 现有代码 ...
    
    # 如果需要支付，根据 payment_method 选择支付方式
    if final_amount > 0:
        if payment_request.payment_method == "paypal":
            # PayPal 支付
            paypal_service = PayPalService()
            payment_result = paypal_service.create_payment(
                amount=final_amount / 100,  # 转换为英镑
                currency="GBP",
                description=f"任务 #{task_id} 平台服务费 - {task.title}",
                return_url=f"{os.getenv('FRONTEND_URL', 'http://localhost:3000')}/tasks/{task_id}/pay/paypal/success",
                cancel_url=f"{os.getenv('FRONTEND_URL', 'http://localhost:3000')}/tasks/{task_id}/pay/paypal/cancel",
                metadata={
                    "task_id": task_id,
                    "user_id": current_user.id,
                    "points_used": str(points_used) if points_used else "",
                    "coupon_usage_log_id": str(coupon_usage_log.id) if coupon_usage_log else "",
                    "application_fee": str(application_fee_pence)
                }
            )
            
            if payment_result:
                return {
                    # ... 其他字段 ...
                    "checkout_url": payment_result["approval_url"],
                    "payment_provider": "paypal",
                    "paypal_payment_id": payment_result["payment_id"]
                }
            else:
                raise HTTPException(status_code=500, detail="PayPal支付创建失败")
        
        elif payment_request.payment_method in ["stripe", "mixed"]:
            # Stripe 支付（现有代码）
            stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
            # ... 现有 Stripe 代码 ...
```

### 5. PayPal Webhook 处理

创建 PayPal Webhook 端点：

```python
@router.post("/paypal/webhook")
async def paypal_webhook(request: Request, db: Session = Depends(get_db)):
    """处理 PayPal Webhook 事件"""
    from app.services.paypal_service import PayPalService
    import json
    
    try:
        payload = await request.json()
        event_type = payload.get("event_type")
        
        # 验证 Webhook 签名（PayPal 提供验证工具）
        # 这里简化处理，生产环境需要验证签名
        
        if event_type == "PAYMENT.SALE.COMPLETED":
            # 支付完成
            resource = payload.get("resource", {})
            payment_id = resource.get("parent_payment")
            
            # 从数据库查找对应的任务
            # 这里需要存储 payment_id 和 task_id 的映射关系
            # 可以通过 Payment 表的 metadata 字段存储
            
            # 更新任务状态
            # task.is_paid = 1
            # db.commit()
            
            return {"status": "success"}
        
        return {"status": "ignored"}
        
    except Exception as e:
        logger.error(f"PayPal webhook error: {str(e)}")
        return {"error": str(e)}
```

### 6. PayPal 支付确认端点

```python
@router.get("/tasks/{task_id}/pay/paypal/success")
def paypal_payment_success(
    task_id: int,
    paymentId: str,
    PayerID: str,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """PayPal 支付成功回调"""
    from app.services.paypal_service import PayPalService
    
    paypal_service = PayPalService()
    result = paypal_service.execute_payment(paymentId, PayerID)
    
    if result and result.get("state") == "approved":
        # 更新任务状态
        task = crud.get_task(db, task_id)
        if task and task.poster_id == current_user.id:
            task.is_paid = 1
            task.escrow_amount = float(task.agreed_reward) if task.agreed_reward else float(task.base_reward)
            db.commit()
        
        return RedirectResponse(url=f"{os.getenv('FRONTEND_URL')}/tasks/{task_id}/pay/success")
    else:
        return RedirectResponse(url=f"{os.getenv('FRONTEND_URL')}/tasks/{task_id}/pay/cancel")
```

---

## 数据库设计

### 支付记录表（建议新增）

创建迁移文件 `backend/migrations/037_add_payment_records.sql`：

```sql
-- 支付记录表
CREATE TABLE IF NOT EXISTS payment_records (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 支付信息
    payment_provider VARCHAR(20) NOT NULL,  -- 'stripe', 'paypal', 'points'
    payment_method VARCHAR(50),  -- 'card', 'paypal', 'points'
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending',  -- 'pending', 'completed', 'failed', 'refunded'
    
    -- 金额信息
    total_amount INTEGER NOT NULL,  -- 总金额（最小货币单位）
    points_used INTEGER DEFAULT 0,  -- 使用的积分
    coupon_discount INTEGER DEFAULT 0,  -- 优惠券折扣
    final_amount INTEGER NOT NULL,  -- 最终支付金额
    
    -- 第三方支付信息
    provider_payment_id VARCHAR(255),  -- Stripe/PayPal 支付ID
    provider_transaction_id VARCHAR(255),  -- 交易ID
    
    -- 优惠券使用记录
    coupon_usage_log_id INTEGER REFERENCES coupon_usage_logs(id),
    
    -- 时间戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- 元数据（JSON格式，存储额外信息）
    metadata JSONB
);

-- 索引
CREATE INDEX idx_payment_records_task_id ON payment_records(task_id);
CREATE INDEX idx_payment_records_user_id ON payment_records(user_id);
CREATE INDEX idx_payment_records_provider_payment_id ON payment_records(provider_payment_id);
CREATE INDEX idx_payment_records_status ON payment_records(payment_status);
```

### 更新模型文件

在 `backend/app/models.py` 中添加：

```python
class PaymentRecord(Base):
    __tablename__ = "payment_records"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    payment_provider = Column(String(20), nullable=False)  # stripe, paypal, points
    payment_method = Column(String(50))
    payment_status = Column(String(20), nullable=False, default="pending")
    
    total_amount = Column(Integer, nullable=False)
    points_used = Column(Integer, default=0)
    coupon_discount = Column(Integer, default=0)
    final_amount = Column(Integer, nullable=False)
    
    provider_payment_id = Column(String(255))
    provider_transaction_id = Column(String(255))
    
    coupon_usage_log_id = Column(Integer, ForeignKey("coupon_usage_logs.id"))
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    completed_at = Column(DateTime(timezone=True))
    
    metadata = Column(JSON)
    
    # 关系
    task = relationship("Task", back_populates="payment_records")
    user = relationship("User")
    coupon_usage_log = relationship("CouponUsageLog")
```

---

## API 接口设计

### 更新 Schema

在 `backend/app/schemas.py` 中更新：

```python
class TaskPaymentRequest(BaseModel):
    payment_method: str  # 'points', 'stripe', 'paypal', 'mixed'
    points_amount: Optional[int] = None
    coupon_code: Optional[str] = None
    user_coupon_id: Optional[int] = None
    stripe_amount: Optional[int] = None
    paypal_amount: Optional[int] = None

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
    paypal_amount: Optional[int] = None
    paypal_amount_display: Optional[str] = None
    currency: str
    final_amount: int
    final_amount_display: str
    checkout_url: Optional[str] = None
    payment_provider: Optional[str] = None  # 'stripe', 'paypal', 'points'
    paypal_payment_id: Optional[str] = None
    note: str
```

### API 端点列表

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/api/coupon-points/tasks/{task_id}/payment` | 创建支付会话 |
| POST | `/api/users/stripe/webhook` | Stripe Webhook |
| POST | `/api/users/paypal/webhook` | PayPal Webhook |
| GET | `/api/users/tasks/{task_id}/pay/paypal/success` | PayPal 支付成功回调 |
| GET | `/api/users/tasks/{task_id}/pay/paypal/cancel` | PayPal 支付取消回调 |
| GET | `/api/users/payments/{payment_id}` | 查询支付状态 |

---

## 前端集成

### 1. 安装依赖

```bash
cd frontend
npm install @stripe/stripe-js @stripe/react-stripe-js
npm install @paypal/react-paypal-js
```

### 2. Stripe 集成

创建 `frontend/src/components/payment/StripeCheckout.tsx`：

```typescript
import React, { useEffect } from 'react';
import { loadStripe } from '@stripe/stripe-js';

const stripePromise = loadStripe(process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || '');

interface StripeCheckoutProps {
  checkoutUrl: string;
  onSuccess?: () => void;
  onCancel?: () => void;
}

export const StripeCheckout: React.FC<StripeCheckoutProps> = ({
  checkoutUrl,
  onSuccess,
  onCancel
}) => {
  useEffect(() => {
    if (checkoutUrl) {
      window.location.href = checkoutUrl;
    }
  }, [checkoutUrl]);

  return <div>正在跳转到支付页面...</div>;
};
```

### 3. PayPal 集成

创建 `frontend/src/components/payment/PayPalButton.tsx`：

```typescript
import React from 'react';
import { PayPalScriptProvider, PayPalButtons } from '@paypal/react-paypal-js';

interface PayPalButtonProps {
  amount: number;
  currency: string;
  onSuccess: (paymentId: string) => void;
  onError: (error: any) => void;
  onCancel: () => void;
}

export const PayPalButton: React.FC<PayPalButtonProps> = ({
  amount,
  currency,
  onSuccess,
  onError,
  onCancel
}) => {
  const initialOptions = {
    clientId: process.env.REACT_APP_PAYPAL_CLIENT_ID || '',
    currency: currency,
    intent: 'capture',
  };

  return (
    <PayPalScriptProvider options={initialOptions}>
      <PayPalButtons
        createOrder={(data, actions) => {
          return actions.order.create({
            purchase_units: [
              {
                amount: {
                  value: amount.toFixed(2),
                  currency_code: currency,
                },
              },
            ],
          });
        }}
        onApprove={(data, actions) => {
          return actions.order?.capture().then((details) => {
            onSuccess(data.orderID);
          });
        }}
        onError={onError}
        onCancel={onCancel}
      />
    </PayPalScriptProvider>
  );
};
```

### 4. 支付页面组件

创建 `frontend/src/pages/TaskPayment.tsx`：

```typescript
import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { PayPalButton } from '../components/payment/PayPalButton';
import { StripeCheckout } from '../components/payment/StripeCheckout';
import api from '../services/api';

export const TaskPayment: React.FC = () => {
  const { taskId } = useParams<{ taskId: string }>();
  const navigate = useNavigate();
  const [paymentMethod, setPaymentMethod] = useState<'stripe' | 'paypal' | 'points'>('stripe');
  const [paymentData, setPaymentData] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const handleCreatePayment = async () => {
    setLoading(true);
    try {
      const response = await api.post(`/coupon-points/tasks/${taskId}/payment`, {
        payment_method: paymentMethod,
      });
      setPaymentData(response.data);
    } catch (error) {
      console.error('创建支付失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const handlePayPalSuccess = async (paymentId: string) => {
    // 处理 PayPal 支付成功
    navigate(`/tasks/${taskId}/pay/success`);
  };

  return (
    <div className="payment-page">
      <h2>支付平台服务费</h2>
      
      {/* 支付方式选择 */}
      <div className="payment-methods">
        <button onClick={() => setPaymentMethod('stripe')}>
          Stripe (信用卡)
        </button>
        <button onClick={() => setPaymentMethod('paypal')}>
          PayPal
        </button>
        <button onClick={() => setPaymentMethod('points')}>
          积分支付
        </button>
      </div>

      {/* 支付信息显示 */}
      {paymentData && (
        <div className="payment-info">
          <p>总金额: £{paymentData.total_amount_display}</p>
          {paymentData.points_used_display && (
            <p>积分抵扣: £{paymentData.points_used_display}</p>
          )}
          <p>最终支付: £{paymentData.final_amount_display}</p>
        </div>
      )}

      {/* 支付按钮 */}
      {!paymentData && (
        <button onClick={handleCreatePayment} disabled={loading}>
          {loading ? '创建支付中...' : '创建支付'}
        </button>
      )}

      {/* Stripe 支付 */}
      {paymentData?.payment_provider === 'stripe' && paymentData.checkout_url && (
        <StripeCheckout
          checkoutUrl={paymentData.checkout_url}
          onSuccess={() => navigate(`/tasks/${taskId}/pay/success`)}
          onCancel={() => navigate(`/tasks/${taskId}/pay/cancel`)}
        />
      )}

      {/* PayPal 支付 */}
      {paymentData?.payment_provider === 'paypal' && (
        <PayPalButton
          amount={parseFloat(paymentData.final_amount_display)}
          currency={paymentData.currency}
          onSuccess={handlePayPalSuccess}
          onError={(error) => console.error('PayPal错误:', error)}
          onCancel={() => navigate(`/tasks/${taskId}/pay/cancel`)}
        />
      )}
    </div>
  );
};
```

---

## Webhook 处理

### Stripe Webhook

**事件类型**：
- `checkout.session.completed`：支付完成

**处理流程**：
1. 验证 Stripe 签名
2. 解析事件数据
3. 从 metadata 获取任务ID
4. 更新任务支付状态
5. 记录支付记录

### PayPal Webhook

**事件类型**：
- `PAYMENT.SALE.COMPLETED`：支付完成
- `PAYMENT.SALE.DENIED`：支付被拒绝
- `PAYMENT.SALE.REFUNDED`：支付退款

**处理流程**：
1. 验证 Webhook 签名（使用 PayPal 验证工具）
2. 解析事件数据
3. 查找对应的支付记录
4. 更新任务支付状态
5. 记录支付记录

### Webhook 安全

1. **验证签名**：始终验证 Webhook 签名
2. **幂等性**：确保 Webhook 处理是幂等的
3. **日志记录**：记录所有 Webhook 事件
4. **错误处理**：妥善处理错误，避免重复处理

---

## 测试指南

### 1. Stripe 测试

**测试卡号**：
- 成功：`4242 4242 4242 4242`
- 需要3D验证：`4000 0025 0000 3155`
- 被拒绝：`4000 0000 0000 0002`

**测试步骤**：
1. 使用测试 API 密钥
2. 创建支付会话
3. 使用测试卡号完成支付
4. 检查 Webhook 是否收到事件
5. 验证任务状态是否更新

### 2. PayPal 测试

**测试账户**：
- 在 PayPal Sandbox 创建测试账户
- 使用测试账户登录进行支付

**测试步骤**：
1. 使用 Sandbox 模式
2. 创建支付
3. 使用测试账户完成支付
4. 检查 Webhook 是否收到事件
5. 验证任务状态是否更新

### 3. 集成测试

```python
# backend/tests/test_payment.py
import pytest
from app.services.paypal_service import PayPalService
from app.services.stripe_service import StripeService

def test_stripe_payment_creation():
    """测试 Stripe 支付创建"""
    # 测试代码

def test_paypal_payment_creation():
    """测试 PayPal 支付创建"""
    # 测试代码

def test_webhook_handling():
    """测试 Webhook 处理"""
    # 测试代码
```

---

## 部署配置

### 1. 环境变量

在生产环境配置文件中添加：

```env
# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# PayPal
PAYPAL_CLIENT_ID=your_live_client_id
PAYPAL_CLIENT_SECRET=your_live_client_secret
PAYPAL_MODE=live
PAYPAL_WEBHOOK_ID=your_webhook_id
```

### 2. Webhook URL 配置

**Stripe**：
- Dashboard → Webhooks → 添加端点
- URL: `https://your-domain.com/api/users/stripe/webhook`
- 事件：`checkout.session.completed`

**PayPal**：
- Dashboard → Webhooks → 添加端点
- URL: `https://your-domain.com/api/users/paypal/webhook`
- 事件：`PAYMENT.SALE.COMPLETED`

### 3. 前端环境变量

在 `frontend/.env.production` 中：

```env
REACT_APP_STRIPE_PUBLISHABLE_KEY=pk_live_...
REACT_APP_PAYPAL_CLIENT_ID=your_live_client_id
```

---

## 安全注意事项

### 1. API 密钥安全

- ✅ 永远不要将密钥提交到代码仓库
- ✅ 使用环境变量存储密钥
- ✅ 定期轮换密钥
- ✅ 使用不同的测试和生产密钥

### 2. Webhook 安全

- ✅ 始终验证 Webhook 签名
- ✅ 使用 HTTPS
- ✅ 实现幂等性检查
- ✅ 记录所有 Webhook 事件

### 3. 支付安全

- ✅ 在服务器端验证支付金额
- ✅ 使用 HTTPS 传输所有支付数据
- ✅ 实现支付超时机制
- ✅ 记录所有支付操作

### 4. 数据保护

- ✅ 不存储完整的支付卡信息
- ✅ 加密敏感数据
- ✅ 遵守 PCI DSS 合规要求
- ✅ 定期进行安全审计

---

## 故障排查

### 常见问题

#### 1. Stripe Webhook 未收到事件

**检查项**：
- Webhook URL 是否正确配置
- Webhook 签名密钥是否正确
- 服务器是否可访问（防火墙/网络）
- 查看 Stripe Dashboard 中的 Webhook 日志

#### 2. PayPal 支付创建失败

**检查项**：
- PayPal 客户端ID和密钥是否正确
- PayPal 模式（sandbox/live）是否匹配
- 金额格式是否正确（字符串，保留2位小数）
- 查看 PayPal 日志

#### 3. 支付状态未更新

**检查项**：
- Webhook 处理逻辑是否正确
- 数据库事务是否提交
- 任务ID是否匹配
- 查看应用日志

### 日志记录

建议记录以下信息：

```python
logger.info(f"Payment created: task_id={task_id}, provider={provider}, amount={amount}")
logger.info(f"Webhook received: event_type={event_type}, payment_id={payment_id}")
logger.error(f"Payment failed: error={error}, task_id={task_id}")
```

### 监控指标

建议监控：
- 支付成功率
- Webhook 处理时间
- 支付失败率
- 退款率

---

## 附录

### A. 参考文档

- [Stripe API 文档](https://stripe.com/docs/api)
- [PayPal REST API 文档](https://developer.paypal.com/docs/api/overview/)
- [Stripe Webhooks 指南](https://stripe.com/docs/webhooks)
- [PayPal Webhooks 指南](https://developer.paypal.com/docs/api-basics/notifications/webhooks/)

### B. 代码示例

完整的代码示例请参考：
- `backend/app/services/paypal_service.py`
- `backend/app/coupon_points_routes.py`
- `frontend/src/components/payment/`

### C. 联系支持

如有问题，请联系开发团队或查看：
- 项目 Issue 跟踪
- 内部文档 Wiki
- 技术团队 Slack 频道

---

**文档版本**：v1.0  
**最后更新**：2024年  
**维护者**：LinkU 开发团队

