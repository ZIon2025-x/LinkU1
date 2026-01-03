# 手动处理未收到的 Webhook 事件

## 问题
支付成功但 webhook 未到达服务器，导致任务状态未更新。

## 解决方案

### 方案 1：在 Stripe Dashboard 中手动重放事件（推荐）

1. 登录 Stripe Dashboard
2. 切换到 **Test mode**（因为事件是测试模式）
3. 进入 **Developers → Events**
4. 找到事件：`evt_3SlX8W8JTHo8Clga1HHDUnra`
5. 点击事件进入详情页
6. 点击 **"Send test webhook"** 或 **"Replay"** 按钮
7. 选择你的 webhook 端点：`https://api.link2ur.com/api/stripe/webhook`
8. 点击发送
9. 检查服务器日志，应该看到 `🔔 [WEBHOOK]` 日志

### 方案 2：使用 Stripe CLI 手动发送事件

```bash
# 1. 安装 Stripe CLI（如果还没有）
brew install stripe/stripe-cli/stripe

# 2. 登录
stripe login

# 3. 获取事件详情
stripe events retrieve evt_3SlX8W8JTHo8Clga1HHDUnra

# 4. 手动触发 webhook（转发到服务器）
stripe events resend evt_3SlX8W8JTHo8Clga1HHDUnra
```

### 方案 3：使用 API 手动处理（如果以上方法都不行）

如果 webhook 端点配置有问题，可以临时使用 API 手动处理这个支付：

```python
# 临时脚本：手动处理支付成功
import stripe
import os
from app import crud, models
from app.database import SessionLocal

# 设置 Stripe API Key
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

# Payment Intent ID
payment_intent_id = "pi_3SlX8W8JTHo8Clga1wQXDcrY"

# 获取 Payment Intent
payment_intent = stripe.PaymentIntent.retrieve(payment_intent_id)

# 检查 metadata
metadata = payment_intent.metadata
task_id = int(metadata.get("task_id", 0))
application_id = int(metadata.get("application_id", 0))
is_pending_approval = metadata.get("pending_approval") == "true"

print(f"Task ID: {task_id}")
print(f"Application ID: {application_id}")
print(f"Pending Approval: {is_pending_approval}")

if task_id and is_pending_approval:
    db = SessionLocal()
    try:
        # 获取任务
        task = crud.get_task(db, task_id)
        if not task:
            print(f"❌ 任务 {task_id} 不存在")
        elif task.is_paid:
            print(f"✅ 任务 {task_id} 已经支付过了")
        else:
            # 手动执行 webhook 逻辑
            task.is_paid = 1
            task.payment_intent_id = payment_intent_id
            
            # 计算金额和服务费
            task_amount = float(task.agreed_reward) if task.agreed_reward else float(task.base_reward)
            application_fee_pence = int(metadata.get("application_fee", 0))
            application_fee = application_fee_pence / 100.0
            taker_amount = task_amount - application_fee
            task.escrow_amount = max(0.0, taker_amount)
            
            # 批准申请
            if application_id:
                from sqlalchemy import select
                application = db.execute(
                    select(models.TaskApplication).where(
                        models.TaskApplication.id == application_id,
                        models.TaskApplication.task_id == task_id,
                        models.TaskApplication.status == "pending"
                    )
                ).scalar_one_or_none()
                
                if application:
                    application.status = "approved"
                    task.taker_id = application.applicant_id
                    task.status = "in_progress"
                    
                    # 拒绝其他申请
                    other_applications = db.execute(
                        select(models.TaskApplication).where(
                            models.TaskApplication.task_id == task_id,
                            models.TaskApplication.id != application_id,
                            models.TaskApplication.status == "pending"
                        )
                    ).scalars().all()
                    
                    for other_app in other_applications:
                        other_app.status = "rejected"
                    
                    print(f"✅ 申请 {application_id} 已批准")
                    print(f"✅ 任务 {task_id} 状态已更新为 in_progress")
            
            db.commit()
            print(f"✅ 任务 {task_id} 支付状态已更新")
    except Exception as e:
        db.rollback()
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()
```

## 预防措施

完成手动处理后，**必须**配置正确的 webhook 端点，避免以后再次出现此问题：

1. **在 Stripe Dashboard 中配置 Webhook**：
   - Test mode: 创建端点 `https://api.link2ur.com/api/stripe/webhook`
   - 订阅事件：`payment_intent.succeeded`
   - 复制 Signing secret 到环境变量

2. **验证配置**：
   - 进行一次新的测试支付
   - 检查服务器日志是否收到 webhook
   - 确认任务状态自动更新

## 当前事件信息

- **事件 ID**: `evt_3SlX8W8JTHo8Clga1HHDUnra`
- **Payment Intent ID**: `pi_3SlX8W8JTHo8Clga1wQXDcrY`
- **任务 ID**: `128`
- **申请 ID**: `40`
- **金额**: £1.00 (100 pence)
- **模式**: Test mode (`livemode: false`)

