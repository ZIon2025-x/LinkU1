# 任务和商品咨询功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the consultation chat feature to tasks and flea market items, allowing users to chat with posters/sellers before applying/buying.

**Architecture:** Task consultations use `TaskApplication` (status=consulting) with existing task chat endpoints (application_id is already TaskApplication.id). Flea market consultations use `FleaMarketPurchaseRequest` (status=consulting) with a placeholder task for message routing. Frontend reuses `ApplicationChatView` with a new `consultationType` enum to route API calls per source type. Task and flea market detail pages get a consult icon button in the bottom bar.

**Tech Stack:** Python/FastAPI, Flutter/BLoC, SQLAlchemy

**Spec:** `docs/superpowers/specs/2026-03-28-task-fleamarket-consultation-design.md`

---

## File Map

### Backend (New)
- `backend/migrations/143_task_fleamarket_consultation.sql` — DB migration

### Backend (Modified)
- `backend/app/task_chat_routes.py` — New task consultation endpoints + chat list update
- `backend/app/flea_market_routes.py` — New flea market consultation endpoints
- `backend/app/models.py` — FleaMarketPurchaseRequest CHECK constraint update + task_id/final_price fields

### Frontend (Modified)
- `link2ur/lib/core/constants/api_endpoints.dart` — New endpoint constants
- `link2ur/lib/data/repositories/task_expert_repository.dart` — New repository methods
- `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart` — New events/handlers
- `link2ur/lib/features/tasks/views/application_chat_view.dart` — ConsultationType enum + routing
- `link2ur/lib/features/tasks/views/task_detail_view.dart` — Remove Ask button, add consult icon
- `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart` — Add consult icon
- `link2ur/lib/core/router/routes/task_routes.dart` — Parse consultationType query param
- `link2ur/lib/features/message/views/message_view.dart` — Update navigation for new types
- `link2ur/lib/features/notification/views/task_chat_list_view.dart` — Same navigation update
- `link2ur/lib/data/models/message.dart` — TaskChat model update for new task sources

---

## Task 1: Backend — DB Migration

**Files:**
- Create: `backend/migrations/143_task_fleamarket_consultation.sql`
- Modify: `backend/app/models.py`

- [ ] **Step 1: Create migration file**

```sql
-- 143_task_fleamarket_consultation.sql
-- Add consulting support to task_applications and flea_market_purchase_requests

-- 1. task_applications.status is VARCHAR(20) with no CHECK constraint,
--    so 'consulting', 'negotiating', 'price_agreed' are already valid.

-- 2. flea_market_purchase_requests: drop old CHECK and add new statuses
ALTER TABLE flea_market_purchase_requests
    DROP CONSTRAINT IF EXISTS check_status_valid;

ALTER TABLE flea_market_purchase_requests
    ADD CONSTRAINT check_status_valid
    CHECK (status IN ('pending', 'seller_negotiating', 'accepted', 'rejected',
                      'consulting', 'negotiating', 'price_agreed', 'cancelled'));

-- 3. Add task_id column for message routing (placeholder task)
ALTER TABLE flea_market_purchase_requests
    ADD COLUMN IF NOT EXISTS task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL;

-- 4. Add final_price column for agreed negotiation price
ALTER TABLE flea_market_purchase_requests
    ADD COLUMN IF NOT EXISTS final_price DECIMAL(12,2);

-- 5. Add expert_counter_price column (for consistency with negotiation pattern)
ALTER TABLE flea_market_purchase_requests
    ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'GBP';

-- 6. Index for consulting lookups
CREATE INDEX IF NOT EXISTS ix_task_applications_consulting
    ON task_applications (applicant_id, task_id, status)
    WHERE status IN ('consulting', 'negotiating', 'price_agreed');

CREATE INDEX IF NOT EXISTS ix_flea_purchase_consulting
    ON flea_market_purchase_requests (buyer_id, item_id, status)
    WHERE status IN ('consulting', 'negotiating', 'price_agreed');
```

- [ ] **Step 2: Update FleaMarketPurchaseRequest model CHECK constraint in models.py**

Find the `check_status_valid` CheckConstraint (around line 1905) and update:

```python
# Old:
CheckConstraint("status IN ('pending', 'seller_negotiating', 'accepted', 'rejected')", name="check_status_valid"),
# New:
CheckConstraint("status IN ('pending', 'seller_negotiating', 'accepted', 'rejected', 'consulting', 'negotiating', 'price_agreed', 'cancelled')", name="check_status_valid"),
```

Add new columns to the model class:

```python
task_id = Column(Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)
final_price = Column(DECIMAL(12, 2), nullable=True)
```

Add relationship:

```python
task = relationship("Task", foreign_keys=[task_id])
```

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/143_task_fleamarket_consultation.sql backend/app/models.py
git commit -m "feat: add consulting status support to task_applications and flea_market_purchase_requests"
```

---

## Task 2: Backend — Task Consultation Endpoints

**Files:**
- Modify: `backend/app/task_chat_routes.py`

Add 6 new endpoints for task consultation. These operate on `TaskApplication` and use the existing task's ID directly (no placeholder task needed).

- [ ] **Step 1: Add create task consultation endpoint**

Add after existing endpoints in `task_chat_routes.py`:

```python
@task_chat_router.post("/tasks/{task_id}/consult")
async def create_task_consultation(
    task_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建任务咨询（轻量，无需填表）"""
    task = await db.get(models.Task, task_id)
    if not task or task.status not in ("open", "chatting"):
        raise HTTPException(status_code=404, detail="任务不存在或不可咨询")

    if task.poster_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能咨询自己的任务")

    # Check existing active consultation
    existing = await db.execute(
        select(models.TaskApplication).where(
            models.TaskApplication.task_id == task_id,
            models.TaskApplication.applicant_id == current_user.id,
            models.TaskApplication.status.in_(["consulting", "negotiating", "price_agreed"]),
        )
    )
    existing_app = existing.scalar_one_or_none()
    if existing_app:
        return {
            "application_id": existing_app.id,
            "task_id": task_id,
            "status": existing_app.status,
            "created_at": existing_app.created_at.isoformat() if existing_app.created_at else None,
            "is_existing": True,
        }

    application = models.TaskApplication(
        task_id=task_id,
        applicant_id=current_user.id,
        status="consulting",
        currency=task.currency or "GBP",
    )
    db.add(application)
    await db.flush()

    # System message
    msg = models.Message(
        sender_id=None,
        receiver_id=task.poster_id,
        content=f"{current_user.name} 想咨询您的任务「{task.title}」",
        task_id=task_id,
        application_id=application.id,
        message_type="system",
        conversation_type="task",
    )
    db.add(msg)
    await db.commit()

    return {
        "application_id": application.id,
        "task_id": task_id,
        "status": "consulting",
        "created_at": application.created_at.isoformat() if application.created_at else None,
        "is_existing": False,
    }
```

- [ ] **Step 2: Add task consultation negotiate endpoint**

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-negotiate")
async def task_consult_negotiate(
    task_id: int,
    application_id: int,
    request_data: schemas.NegotiateRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务咨询 — 用户议价"""
    result = await db.execute(
        select(models.TaskApplication)
        .where(models.TaskApplication.id == application_id, models.TaskApplication.task_id == task_id)
        .with_for_update()
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status not in ("consulting", "negotiating"):
        raise HTTPException(status_code=400, detail="当前状态不允许议价")

    task = await db.get(models.Task, task_id)
    application.status = "negotiating"
    application.negotiated_price = request_data.proposed_price
    price_display = f"£{float(request_data.proposed_price):.2f}"

    msg = models.Message(
        sender_id=current_user.id,
        receiver_id=task.poster_id,
        content=price_display,
        task_id=task_id,
        application_id=application.id,
        message_type="negotiation",
        conversation_type="task",
        meta=json.dumps({"price": float(request_data.proposed_price), "currency": application.currency or "GBP"}),
    )
    db.add(msg)
    await db.commit()

    # Notification
    try:
        await async_crud.async_notification_crud.create_notification(
            db, user_id=task.poster_id, title="收到议价",
            body=f"用户对您的任务提出了议价: {price_display}",
            notification_type="task", data={"task_id": task_id, "application_id": application_id},
        )
    except Exception as e:
        logger.error(f"Failed to send negotiate notification: {e}")

    return {"message": "议价已发送", "status": "negotiating", "application_id": application_id}
```

- [ ] **Step 3: Add task consultation quote endpoint (poster quotes)**

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-quote")
async def task_consult_quote(
    task_id: int,
    application_id: int,
    request_data: schemas.QuoteRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务咨询 — 发布者报价"""
    result = await db.execute(
        select(models.TaskApplication)
        .where(models.TaskApplication.id == application_id, models.TaskApplication.task_id == task_id)
        .with_for_update()
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    task = await db.get(models.Task, task_id)
    if task.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status not in ("consulting", "negotiating"):
        raise HTTPException(status_code=400, detail="当前状态不允许报价")

    application.status = "negotiating"
    # Store poster's quote in negotiated_price field (TaskApplication doesn't have expert_counter_price)
    # Use a convention: store the latest quote. Track who quoted via the message.
    application.negotiated_price = request_data.quoted_price
    price_display = f"£{float(request_data.quoted_price):.2f}"
    quote_content = price_display
    if request_data.message:
        quote_content = f"{price_display}\n{request_data.message}"

    msg = models.Message(
        sender_id=current_user.id,
        receiver_id=application.applicant_id,
        content=quote_content,
        task_id=task_id,
        application_id=application.id,
        message_type="quote",
        conversation_type="task",
        meta=json.dumps({"price": float(request_data.quoted_price), "currency": application.currency or "GBP", "message": request_data.message}),
    )
    db.add(msg)
    await db.commit()

    try:
        await async_crud.async_notification_crud.create_notification(
            db, user_id=application.applicant_id, title="收到报价",
            body=f"任务发布者发送了报价: {price_display}",
            notification_type="task", data={"task_id": task_id, "application_id": application_id},
        )
    except Exception as e:
        logger.error(f"Failed to send quote notification: {e}")

    return {"message": "报价已发送", "status": "negotiating", "application_id": application_id}
```

- [ ] **Step 4: Add task consultation negotiate-response endpoint**

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-respond")
async def task_consult_respond(
    task_id: int,
    application_id: int,
    request_data: schemas.NegotiateResponseRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务咨询 — 回应议价/报价"""
    result = await db.execute(
        select(models.TaskApplication)
        .where(models.TaskApplication.id == application_id, models.TaskApplication.task_id == task_id)
        .with_for_update()
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    task = await db.get(models.Task, task_id)
    is_applicant = application.applicant_id == current_user.id
    is_poster = task.poster_id == current_user.id
    if not is_applicant and not is_poster:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status != "negotiating":
        raise HTTPException(status_code=400, detail="当前状态不允许此操作")

    receiver_id = application.applicant_id if is_poster else task.poster_id

    if request_data.action == "accept":
        agreed_price = application.negotiated_price
        if not agreed_price:
            raise HTTPException(status_code=400, detail="无法确定最终价格")
        application.status = "price_agreed"
        price_display = f"£{float(agreed_price):.2f}"
        msg = models.Message(
            sender_id=current_user.id, receiver_id=receiver_id,
            content=f"已接受价格: {price_display}",
            task_id=task_id, application_id=application.id,
            message_type="negotiation_accepted", conversation_type="task",
            meta=json.dumps({"price": float(agreed_price), "currency": application.currency or "GBP"}),
        )
        db.add(msg)
        await db.commit()
        try:
            await async_crud.async_notification_crud.create_notification(
                db, user_id=receiver_id, title="报价已接受",
                body=f"对方已接受价格 {price_display}",
                notification_type="task", data={"task_id": task_id},
            )
        except Exception:
            pass
        return {"message": "价格已达成一致", "status": "price_agreed", "agreed_price": float(agreed_price), "application_id": application_id}

    elif request_data.action == "reject":
        application.status = "consulting"
        msg = models.Message(
            sender_id=current_user.id, receiver_id=receiver_id,
            content="对方拒绝了报价",
            task_id=task_id, application_id=application.id,
            message_type="negotiation_rejected", conversation_type="task",
        )
        db.add(msg)
        await db.commit()
        try:
            await async_crud.async_notification_crud.create_notification(
                db, user_id=receiver_id, title="报价被拒绝",
                body="对方拒绝了报价",
                notification_type="task", data={"task_id": task_id},
            )
        except Exception:
            pass
        return {"message": "已拒绝", "status": "consulting", "application_id": application_id}

    elif request_data.action == "counter":
        application.negotiated_price = request_data.counter_price
        price_display = f"£{float(request_data.counter_price):.2f}"
        msg = models.Message(
            sender_id=current_user.id, receiver_id=receiver_id,
            content=price_display,
            task_id=task_id, application_id=application.id,
            message_type="counter_offer", conversation_type="task",
            meta=json.dumps({"price": float(request_data.counter_price), "currency": application.currency or "GBP"}),
        )
        db.add(msg)
        await db.commit()
        try:
            await async_crud.async_notification_crud.create_notification(
                db, user_id=receiver_id, title="收到还价",
                body=f"对方提出了新的价格: {price_display}",
                notification_type="task", data={"task_id": task_id},
            )
        except Exception:
            pass
        return {"message": "还价已发送", "status": "negotiating", "application_id": application_id}
```

- [ ] **Step 5: Add task consultation formal-apply and close endpoints**

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-formal-apply")
async def task_consult_formal_apply(
    task_id: int,
    application_id: int,
    request_data: schemas.FormalApplyRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """任务咨询转正式申请"""
    result = await db.execute(
        select(models.TaskApplication)
        .where(models.TaskApplication.id == application_id, models.TaskApplication.task_id == task_id)
        .with_for_update()
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status not in ("consulting", "price_agreed"):
        raise HTTPException(status_code=400, detail="当前状态不允许提交正式申请")

    application.status = "pending"
    if request_data.proposed_price is not None:
        application.negotiated_price = request_data.proposed_price
    if request_data.message:
        application.message = request_data.message

    task = await db.get(models.Task, task_id)
    msg = models.Message(
        sender_id=None, receiver_id=task.poster_id,
        content=f"{current_user.name} 已提交正式申请",
        task_id=task_id, application_id=application.id,
        message_type="system", conversation_type="task",
    )
    db.add(msg)
    await db.commit()

    return {"message": "已转为正式申请", "status": "pending", "application_id": application_id}


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-close")
async def task_consult_close(
    task_id: int,
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """关闭任务咨询"""
    result = await db.execute(
        select(models.TaskApplication)
        .where(models.TaskApplication.id == application_id, models.TaskApplication.task_id == task_id)
        .with_for_update()
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    is_applicant = application.applicant_id == current_user.id
    task = await db.get(models.Task, task_id)
    is_poster = task.poster_id == current_user.id
    if not is_applicant and not is_poster:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status not in ("consulting", "negotiating"):
        raise HTTPException(status_code=400, detail="当前状态不允许关闭")

    application.status = "cancelled"
    receiver_id = application.applicant_id if is_poster else task.poster_id
    msg = models.Message(
        sender_id=None, receiver_id=receiver_id,
        content="咨询已关闭",
        task_id=task_id, application_id=application.id,
        message_type="system", conversation_type="task",
    )
    db.add(msg)
    await db.commit()

    return {"message": "咨询已关闭", "status": "cancelled", "application_id": application_id}
```

- [ ] **Step 6: Add task consultation status endpoint**

```python
@task_chat_router.get("/tasks/{task_id}/applications/{application_id}/consult-status")
async def task_consult_status(
    task_id: int,
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取任务咨询申请状态"""
    application = await db.get(models.TaskApplication, application_id)
    if not application or application.task_id != task_id:
        raise HTTPException(status_code=404, detail="申请不存在")

    task = await db.get(models.Task, task_id)
    is_applicant = application.applicant_id == current_user.id
    is_poster = task.poster_id == current_user.id
    if not is_applicant and not is_poster:
        raise HTTPException(status_code=403, detail="无权查看")

    return {
        "id": application.id,
        "task_id": task_id,
        "applicant_id": application.applicant_id,
        "status": application.status,
        "negotiated_price": float(application.negotiated_price) if application.negotiated_price else None,
        "currency": application.currency,
        "poster_id": task.poster_id,
    }
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: add task consultation endpoints (consult, negotiate, quote, respond, formal-apply, close, status)"
```

---

## Task 3: Backend — Flea Market Consultation Endpoints

**Files:**
- Modify: `backend/app/flea_market_routes.py`

Same pattern as task consultation but operates on `FleaMarketPurchaseRequest` and creates a placeholder task for message routing.

- [ ] **Step 1: Add create flea market consultation endpoint**

```python
@flea_market_router.post("/items/{item_id}/consult")
async def create_flea_market_consultation(
    item_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建商品咨询"""
    item_id_int = int(item_id)
    item = await db.get(models.FleaMarketItem, item_id_int)
    if not item or item.status != "active":
        raise HTTPException(status_code=404, detail="商品不存在或已下架")

    if item.seller_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能咨询自己的商品")

    # Check existing
    existing = await db.execute(
        select(models.FleaMarketPurchaseRequest).where(
            models.FleaMarketPurchaseRequest.item_id == item_id_int,
            models.FleaMarketPurchaseRequest.buyer_id == current_user.id,
            models.FleaMarketPurchaseRequest.status.in_(["consulting", "negotiating", "price_agreed"]),
        )
    )
    existing_req = existing.scalar_one_or_none()
    if existing_req:
        return {
            "purchase_request_id": existing_req.id,
            "task_id": existing_req.task_id,
            "item_id": item_id_int,
            "status": existing_req.status,
            "created_at": existing_req.created_at.isoformat() if existing_req.created_at else None,
            "is_existing": True,
        }

    # Create purchase request
    purchase_req = models.FleaMarketPurchaseRequest(
        item_id=item_id_int,
        buyer_id=current_user.id,
        status="consulting",
    )
    db.add(purchase_req)
    await db.flush()

    # Create placeholder task for message routing
    new_task = models.Task(
        title=f"咨询: {item.title}",
        description=f"商品咨询 - {item.title}",
        reward=float(item.price),
        base_reward=float(item.price),
        currency=item.currency or "GBP",
        location="线上",
        task_type="跳蚤市场",
        task_level="normal",
        poster_id=current_user.id,
        taker_id=item.seller_id,
        status="consulting",
        is_paid=0,
        task_source="flea_market_consultation",
    )
    db.add(new_task)
    await db.flush()

    purchase_req.task_id = new_task.id
    await db.commit()

    # System message
    msg = models.Message(
        sender_id=None,
        receiver_id=item.seller_id,
        content=f"{current_user.name} 想咨询您的商品「{item.title}」",
        task_id=new_task.id,
        message_type="system",
        conversation_type="task",
    )
    db.add(msg)
    await db.commit()

    return {
        "purchase_request_id": purchase_req.id,
        "task_id": new_task.id,
        "item_id": item_id_int,
        "status": "consulting",
        "created_at": purchase_req.created_at.isoformat() if purchase_req.created_at else None,
        "is_existing": False,
    }
```

- [ ] **Step 2: Add flea market negotiate/quote/respond/formal-buy/close/status endpoints**

Follow the same pattern as service consultation endpoints in `task_expert_routes.py`, but operating on `FleaMarketPurchaseRequest`:

- `POST /flea-market/purchase-requests/{request_id}/consult-negotiate` — buyer negotiates
- `POST /flea-market/purchase-requests/{request_id}/consult-quote` — seller quotes
- `POST /flea-market/purchase-requests/{request_id}/consult-respond` — accept/reject/counter
- `POST /flea-market/purchase-requests/{request_id}/consult-formal-buy` — convert to purchase
- `POST /flea-market/purchase-requests/{request_id}/consult-close` — close consultation
- `GET /flea-market/purchase-requests/{request_id}/consult-status` — get status

Key differences from task consultation:
- The request model is `FleaMarketPurchaseRequest` (has `buyer_id`, `proposed_price`, `seller_counter_price`, `final_price`)
- Messages go through the `purchase_req.task_id` (placeholder task), WITHOUT `application_id`
- On accept: set `final_price` on the purchase request
- On formal-buy: trigger the existing flea market purchase approval flow
- The seller is identified from `item.seller_id`, the buyer from `purchase_req.buyer_id`

Each endpoint should:
1. Load `FleaMarketPurchaseRequest` by ID with `with_for_update()`
2. Validate permissions (buyer vs seller)
3. Check status constraints
4. Update status and price fields
5. Create negotiation message with `message_type` and `meta`
6. Send notification
7. Return `{message, status, purchase_request_id}`

For `consult-respond` accept branch:
```python
purchase_req.status = "price_agreed"
purchase_req.final_price = agreed_price
```

For `consult-formal-buy`:
```python
purchase_req.status = "accepted"
# Trigger existing purchase/payment flow
```

For `consult-close`:
```python
purchase_req.status = "cancelled"
# Also cancel the placeholder task
task = await db.get(models.Task, purchase_req.task_id)
if task:
    task.status = "cancelled"
```

For `consult-status`:
```python
return {
    "id": purchase_req.id,
    "item_id": purchase_req.item_id,
    "buyer_id": purchase_req.buyer_id,
    "seller_id": item.seller_id,
    "status": purchase_req.status,
    "proposed_price": float(purchase_req.proposed_price) if purchase_req.proposed_price else None,
    "seller_counter_price": float(purchase_req.seller_counter_price) if purchase_req.seller_counter_price else None,
    "final_price": float(purchase_req.final_price) if purchase_req.final_price else None,
    "currency": purchase_req.currency or item.currency or "GBP",
    "task_id": purchase_req.task_id,
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/flea_market_routes.py
git commit -m "feat: add flea market consultation endpoints"
```

---

## Task 4: Frontend — API Endpoints & Repository Methods

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/repositories/task_expert_repository.dart`

- [ ] **Step 1: Add task consultation endpoint constants**

```dart
// Task consultation endpoints
static String consultTask(int taskId) => '/api/tasks/$taskId/consult';
static String taskConsultNegotiate(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/consult-negotiate';
static String taskConsultQuote(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/consult-quote';
static String taskConsultRespond(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/consult-respond';
static String taskConsultFormalApply(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/consult-formal-apply';
static String taskConsultClose(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/consult-close';
static String taskConsultStatus(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/consult-status';
```

- [ ] **Step 2: Add flea market consultation endpoint constants**

```dart
// Flea market consultation endpoints
static String consultFleaMarketItem(String itemId) => '/api/flea-market/items/$itemId/consult';
static String fleaMarketConsultNegotiate(int requestId) =>
    '/api/flea-market/purchase-requests/$requestId/consult-negotiate';
static String fleaMarketConsultQuote(int requestId) =>
    '/api/flea-market/purchase-requests/$requestId/consult-quote';
static String fleaMarketConsultRespond(int requestId) =>
    '/api/flea-market/purchase-requests/$requestId/consult-respond';
static String fleaMarketConsultFormalBuy(int requestId) =>
    '/api/flea-market/purchase-requests/$requestId/consult-formal-buy';
static String fleaMarketConsultClose(int requestId) =>
    '/api/flea-market/purchase-requests/$requestId/consult-close';
static String fleaMarketConsultStatus(int requestId) =>
    '/api/flea-market/purchase-requests/$requestId/consult-status';
```

- [ ] **Step 3: Add repository methods**

Add to `task_expert_repository.dart`:

```dart
// ── Task consultation ──────────────────────────────
Future<Map<String, dynamic>> createTaskConsultation(int taskId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.consultTask(taskId),
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '创建咨询失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> negotiateTaskConsultation(
  int taskId, int applicationId, {required double proposedPrice,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.taskConsultNegotiate(taskId, applicationId),
    data: {'proposed_price': proposedPrice},
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '议价失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> quoteTaskConsultation(
  int taskId, int applicationId, {required double quotedPrice, String? message,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.taskConsultQuote(taskId, applicationId),
    data: {'quoted_price': quotedPrice, if (message != null && message.isNotEmpty) 'message': message},
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '报价失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> respondTaskNegotiation(
  int taskId, int applicationId, {required String action, double? counterPrice,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.taskConsultRespond(taskId, applicationId),
    data: {'action': action, if (counterPrice != null) 'counter_price': counterPrice},
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '操作失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> formalApplyTaskConsultation(
  int taskId, int applicationId, {double? proposedPrice, String? message,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.taskConsultFormalApply(taskId, applicationId),
    data: {
      if (proposedPrice != null) 'proposed_price': proposedPrice,
      if (message != null && message.isNotEmpty) 'message': message,
    },
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '提交申请失败');
  }
  return response.data!;
}

Future<void> closeTaskConsultation(int taskId, int applicationId) async {
  final response = await _apiService.post(
    ApiEndpoints.taskConsultClose(taskId, applicationId),
  );
  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '关闭咨询失败');
  }
}

// ── Flea market consultation ──────────────────────
Future<Map<String, dynamic>> createFleaMarketConsultation(String itemId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.consultFleaMarketItem(itemId),
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '创建咨询失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> negotiateFleaMarketConsultation(
  int requestId, {required double proposedPrice,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.fleaMarketConsultNegotiate(requestId),
    data: {'proposed_price': proposedPrice},
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '议价失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> quoteFleaMarketConsultation(
  int requestId, {required double quotedPrice, String? message,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.fleaMarketConsultQuote(requestId),
    data: {'quoted_price': quotedPrice, if (message != null && message.isNotEmpty) 'message': message},
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '报价失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> respondFleaMarketNegotiation(
  int requestId, {required String action, double? counterPrice,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.fleaMarketConsultRespond(requestId),
    data: {'action': action, if (counterPrice != null) 'counter_price': counterPrice},
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '操作失败');
  }
  return response.data!;
}

Future<Map<String, dynamic>> formalBuyFleaMarket(int requestId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.fleaMarketConsultFormalBuy(requestId),
  );
  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '购买失败');
  }
  return response.data!;
}

Future<void> closeFleaMarketConsultation(int requestId) async {
  final response = await _apiService.post(
    ApiEndpoints.fleaMarketConsultClose(requestId),
  );
  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '关闭咨询失败');
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/task_expert_repository.dart
git commit -m "feat: add task and flea market consultation API endpoints and repository methods"
```

---

## Task 5: Frontend — BLoC Events & Handlers

**Files:**
- Modify: `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart`

- [ ] **Step 1: Add task consultation events**

```dart
class TaskExpertStartTaskConsultation extends TaskExpertEvent {
  const TaskExpertStartTaskConsultation(this.taskId);
  final int taskId;
  @override
  List<Object?> get props => [taskId];
}

class TaskExpertTaskNegotiate extends TaskExpertEvent {
  const TaskExpertTaskNegotiate(this.taskId, this.applicationId, {required this.price});
  final int taskId;
  final int applicationId;
  final double price;
  @override
  List<Object?> get props => [taskId, applicationId, price];
}

class TaskExpertTaskQuote extends TaskExpertEvent {
  const TaskExpertTaskQuote(this.taskId, this.applicationId, {required this.price, this.message});
  final int taskId;
  final int applicationId;
  final double price;
  final String? message;
  @override
  List<Object?> get props => [taskId, applicationId, price, message];
}

class TaskExpertTaskNegotiateResponse extends TaskExpertEvent {
  const TaskExpertTaskNegotiateResponse(this.taskId, this.applicationId, {required this.action, this.counterPrice});
  final int taskId;
  final int applicationId;
  final String action;
  final double? counterPrice;
  @override
  List<Object?> get props => [taskId, applicationId, action, counterPrice];
}

class TaskExpertTaskFormalApply extends TaskExpertEvent {
  const TaskExpertTaskFormalApply(this.taskId, this.applicationId, {this.proposedPrice, this.message});
  final int taskId;
  final int applicationId;
  final double? proposedPrice;
  final String? message;
  @override
  List<Object?> get props => [taskId, applicationId, proposedPrice, message];
}

class TaskExpertCloseTaskConsultation extends TaskExpertEvent {
  const TaskExpertCloseTaskConsultation(this.taskId, this.applicationId);
  final int taskId;
  final int applicationId;
  @override
  List<Object?> get props => [taskId, applicationId];
}
```

- [ ] **Step 2: Add flea market consultation events**

```dart
class TaskExpertStartFleaMarketConsultation extends TaskExpertEvent {
  const TaskExpertStartFleaMarketConsultation(this.itemId);
  final String itemId;
  @override
  List<Object?> get props => [itemId];
}

class TaskExpertFleaMarketNegotiate extends TaskExpertEvent {
  const TaskExpertFleaMarketNegotiate(this.requestId, {required this.price});
  final int requestId;
  final double price;
  @override
  List<Object?> get props => [requestId, price];
}

class TaskExpertFleaMarketQuote extends TaskExpertEvent {
  const TaskExpertFleaMarketQuote(this.requestId, {required this.price, this.message});
  final int requestId;
  final double price;
  final String? message;
  @override
  List<Object?> get props => [requestId, price, message];
}

class TaskExpertFleaMarketNegotiateResponse extends TaskExpertEvent {
  const TaskExpertFleaMarketNegotiateResponse(this.requestId, {required this.action, this.counterPrice});
  final int requestId;
  final String action;
  final double? counterPrice;
  @override
  List<Object?> get props => [requestId, action, counterPrice];
}

class TaskExpertFleaMarketFormalBuy extends TaskExpertEvent {
  const TaskExpertFleaMarketFormalBuy(this.requestId);
  final int requestId;
  @override
  List<Object?> get props => [requestId];
}

class TaskExpertCloseFleaMarketConsultation extends TaskExpertEvent {
  const TaskExpertCloseFleaMarketConsultation(this.requestId);
  final int requestId;
  @override
  List<Object?> get props => [requestId];
}
```

- [ ] **Step 3: Register and implement all handlers**

Follow the exact same pattern as existing consultation handlers (`_onStartConsultation`, `_onNegotiatePrice`, etc.). Each handler:
1. Emits `isSubmitting: true, errorMessage: null, actionMessage: null`
2. Calls the appropriate repository method
3. On success: emits `isSubmitting: false, actionMessage: '<action>_done'`
4. On error: emits `isSubmitting: false, errorMessage: e.message`

Use the same `actionMessage` values as existing consultation: `consultation_started`, `negotiation_sent`, `quote_sent`, `negotiate_response_*`, `formal_apply_submitted`, `consultation_closed`.

For task consultation start, also emit `consultationData: result`.

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart
git commit -m "feat: add BLoC events and handlers for task and flea market consultation"
```

---

## Task 6: Frontend — ApplicationChatView ConsultationType Routing

**Files:**
- Modify: `link2ur/lib/features/tasks/views/application_chat_view.dart`
- Modify: `link2ur/lib/core/router/routes/task_routes.dart`

- [ ] **Step 1: Add ConsultationType enum**

At the top of `application_chat_view.dart`:

```dart
enum ConsultationType { service, task, fleaMarket }
```

- [ ] **Step 2: Add consultationType parameter**

Update `ApplicationChatView` and `_ApplicationChatContent`:

```dart
final ConsultationType consultationType;
```

Default to `ConsultationType.service` for backward compatibility. Pass through to child.

- [ ] **Step 3: Update _loadConsultationStatus to use correct endpoint per type**

```dart
Future<void> _loadConsultationStatus() async {
  if (!widget.isConsultation) return;
  setState(() => _isLoadingConsultation = true);
  try {
    final apiService = context.read<ApiService>();
    final String endpoint;
    switch (widget.consultationType) {
      case ConsultationType.service:
        endpoint = ApiEndpoints.consultationStatus(widget.applicationId);
      case ConsultationType.task:
        endpoint = ApiEndpoints.taskConsultStatus(widget.taskId, widget.applicationId);
      case ConsultationType.fleaMarket:
        endpoint = ApiEndpoints.fleaMarketConsultStatus(widget.applicationId);
    }
    final response = await apiService.get<Map<String, dynamic>>(endpoint);
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() { _consultationApp = response.data; _isLoadingConsultation = false; });
    } else {
      setState(() => _isLoadingConsultation = false);
    }
  } catch (e) {
    if (!mounted) return;
    setState(() => _isLoadingConsultation = false);
  }
}
```

- [ ] **Step 4: Update dialog actions to dispatch correct BLoC events per type**

In each dialog (`_showNegotiateDialog`, `_showQuoteDialog`, etc.), dispatch different events based on `consultationType`:

```dart
void _dispatchNegotiate(double price) {
  final bloc = context.read<TaskExpertBloc>();
  switch (widget.consultationType) {
    case ConsultationType.service:
      bloc.add(TaskExpertNegotiatePrice(widget.applicationId, price: price));
    case ConsultationType.task:
      bloc.add(TaskExpertTaskNegotiate(widget.taskId, widget.applicationId, price: price));
    case ConsultationType.fleaMarket:
      bloc.add(TaskExpertFleaMarketNegotiate(widget.applicationId, price: price));
  }
}
```

Create similar dispatch helpers: `_dispatchQuote`, `_dispatchNegotiateResponse`, `_dispatchFormalApply`, `_dispatchClose`, `_dispatchApprove`.

Replace direct `context.read<TaskExpertBloc>().add(...)` calls in each dialog with the dispatch helpers.

- [ ] **Step 5: Update _isApplicantInConsultation for different response shapes**

For task consultations, the status endpoint returns `applicant_id` and `poster_id`.
For flea market, it returns `buyer_id` and `seller_id`.

```dart
bool _isApplicantInConsultation() {
  if (!widget.isConsultation) return false;
  switch (widget.consultationType) {
    case ConsultationType.service:
      return _currentUserId == _consultationApp?['applicant_id']?.toString();
    case ConsultationType.task:
      return _currentUserId == _consultationApp?['applicant_id']?.toString();
    case ConsultationType.fleaMarket:
      return _currentUserId == _consultationApp?['buyer_id']?.toString();
  }
}
```

- [ ] **Step 6: Update route to parse consultationType**

In `task_routes.dart`:

```dart
final isConsultation = state.uri.queryParameters['consultation'] == 'true';
final typeStr = state.uri.queryParameters['type'];
final consultationType = typeStr == 'task'
    ? ConsultationType.task
    : typeStr == 'flea_market'
        ? ConsultationType.fleaMarket
        : ConsultationType.service;

child: ApplicationChatView(
  taskId: taskId!,
  applicationId: applicationId!,
  isConsultation: isConsultation,
  consultationType: consultationType,
),
```

- [ ] **Step 7: Commit**

```bash
git add link2ur/lib/features/tasks/views/application_chat_view.dart link2ur/lib/core/router/routes/task_routes.dart
git commit -m "feat: add ConsultationType routing to ApplicationChatView"
```

---

## Task 7: Frontend — Task Detail Page (Remove Ask, Add Consult)

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart`

- [ ] **Step 1: Remove Ask button from bottom bar**

In `_buildBottomBar`, find the `showAsk` variable and the Ask `IconActionButton` block. Remove both:

```dart
// DELETE these lines:
final showAsk = !isPoster && currentUserId != null && ...;
// DELETE the IconActionButton for Ask and its spacing
```

- [ ] **Step 2: Add consult icon button**

Add a consult icon button in the same position (left of the apply button):

```dart
// Show consult button: non-poster, logged in, task is open
final showConsult = !isPoster && currentUserId != null &&
    task.status == AppConstants.taskStatusOpen;

// In the Row children:
if (showConsult)
  BlocConsumer<TaskExpertBloc, TaskExpertState>(
    listenWhen: (prev, curr) =>
        prev.actionMessage != curr.actionMessage &&
        (curr.actionMessage == 'consultation_started' || curr.actionMessage == 'consultation_failed'),
    listener: (context, state) {
      if (state.actionMessage == 'consultation_started' && state.consultationData != null) {
        final taskId = state.consultationData!['task_id'] as int?;
        final appId = state.consultationData!['application_id'] as int?;
        if (taskId != null && appId != null) {
          context.push('/tasks/$taskId/applications/$appId/chat?consultation=true&type=task');
        }
      } else if (state.actionMessage == 'consultation_failed') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.localizeError(state.errorMessage))),
        );
      }
    },
    builder: (context, expertState) {
      return IconActionButton(
        icon: Icons.chat_bubble_outline,
        onPressed: expertState.isSubmitting ? null : () {
          context.read<TaskExpertBloc>().add(TaskExpertStartTaskConsultation(task.id));
        },
        backgroundColor: AppColors.skeletonBase,
      );
    },
  ),
if (showConsult) AppSpacing.hMd,
```

Note: `TaskExpertBloc` needs to be provided. Check if it's available in the widget tree. If not, wrap with `BlocProvider<TaskExpertBloc>`. The task detail page may need the same pattern as service detail — check if TaskExpertBloc is already provided by a parent route.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat: replace Ask button with consult icon in task detail bottom bar"
```

---

## Task 8: Frontend — Flea Market Detail Page (Add Consult)

**Files:**
- Modify: `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart`

- [ ] **Step 1: Add consult icon button to buyer bottom bar**

In `_buildBuyerBottomBar`, add a consult icon button before the buy/CTA button:

```dart
return Row(
  children: [
    // Consult button (new)
    BlocConsumer<TaskExpertBloc, TaskExpertState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage &&
          (curr.actionMessage == 'consultation_started' || curr.actionMessage == 'consultation_failed'),
      listener: (context, state) {
        if (state.actionMessage == 'consultation_started' && state.consultationData != null) {
          final taskId = state.consultationData!['task_id'] as int?;
          final reqId = state.consultationData!['purchase_request_id'] as int?;
          if (taskId != null && reqId != null) {
            context.push('/tasks/$taskId/applications/$reqId/chat?consultation=true&type=flea_market');
          }
        } else if (state.actionMessage == 'consultation_failed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage))),
          );
        }
      },
      builder: (context, expertState) {
        return IconActionButton(
          icon: Icons.chat_bubble_outline,
          onPressed: expertState.isSubmitting ? null : () {
            context.read<TaskExpertBloc>().add(
              TaskExpertStartFleaMarketConsultation(item.id),
            );
          },
          backgroundColor: AppColors.skeletonBase,
        );
      },
    ),
    AppSpacing.hMd,
    Expanded(
      child: isUnavailable
          ? _buildUnavailableButton(context, item)
          : _buildBuyerCTAButton(context, state, item),
    ),
  ],
);
```

Note: `TaskExpertBloc` needs to be provided. Add a `BlocProvider<TaskExpertBloc>` in the flea market detail view if not already present.

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/flea_market/views/flea_market_detail_view.dart
git commit -m "feat: add consult icon button to flea market detail bottom bar"
```

---

## Task 9: Frontend — Message List Navigation Update

**Files:**
- Modify: `link2ur/lib/data/models/message.dart`
- Modify: `link2ur/lib/features/message/views/message_view.dart`
- Modify: `link2ur/lib/features/notification/views/task_chat_list_view.dart`

- [ ] **Step 1: Update TaskChat.isConsultation getter**

Currently checks `taskSource == 'consultation'`. Extend to also check `flea_market_consultation`:

```dart
bool get isConsultation => taskSource == 'consultation' || taskSource == 'flea_market_consultation';

String get consultationTypeParam {
  if (taskSource == 'consultation') return 'service';
  if (taskSource == 'flea_market_consultation') return 'flea_market';
  return 'service';
}
```

For task consultations, `taskSource` stays as the task's original source (e.g., "normal") but the chat is scoped via `application_id`. We need a different way to detect task consultations in the chat list. The task status being "consulting" AND having an application with consulting status is the indicator.

Actually, task consultations don't change `task.task_source` — the task already exists. So the message list won't show task consultations differently unless we add logic. For now, task consultations go through the regular task chat flow (with application_id), and the user can see the consulting-mode buttons because the ApplicationChatView detects the application status.

For flea market consultations, `task_source = "flea_market_consultation"` on the placeholder task, so the message list CAN detect it.

- [ ] **Step 2: Update message list navigation**

In `message_view.dart` and `task_chat_list_view.dart`, update the navigation logic:

```dart
if (taskChat.isConsultation && taskChat.serviceApplicationId != null) {
  final type = taskChat.consultationTypeParam;
  context.push('/tasks/${taskChat.taskId}/applications/${taskChat.serviceApplicationId}/chat?consultation=true&type=$type');
} else {
  context.push('/task-chat/${taskChat.taskId}');
}
```

- [ ] **Step 3: Update backend task chat list to return purchase_request_id for flea market consultations**

In `backend/app/task_chat_routes.py`, the task chat list already queries `ServiceApplication` for `service_application_id`. Extend it to also query `FleaMarketPurchaseRequest` for flea market consultation tasks:

```python
# After existing service_app_map logic:
flea_consultation_task_ids = [t.id for t in tasks if getattr(t, 'task_source', '') == 'flea_market_consultation']
flea_app_map = {}
if flea_consultation_task_ids:
    flea_query = select(
        models.FleaMarketPurchaseRequest.task_id,
        models.FleaMarketPurchaseRequest.id
    ).where(
        models.FleaMarketPurchaseRequest.task_id.in_(flea_consultation_task_ids)
    )
    flea_result = await db.execute(flea_query)
    flea_app_map = {row[0]: row[1] for row in flea_result.all()}

# In task_data dict:
"service_application_id": service_app_map.get(task.id) or flea_app_map.get(task.id),
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/message.dart link2ur/lib/features/message/views/message_view.dart link2ur/lib/features/notification/views/task_chat_list_view.dart backend/app/task_chat_routes.py
git commit -m "feat: update message list navigation for task and flea market consultations"
```

---

## Task 10: Integration Verification

- [ ] **Step 1: Run flutter analyze**

```powershell
cd F:\python_work\LinkU\link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

Fix any errors.

- [ ] **Step 2: Run tests**

```powershell
cd F:\python_work\LinkU\link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test
```

Fix any test failures.

- [ ] **Step 3: Manual verification checklist**

1. Task detail page: Ask button removed, consult icon visible
2. Task consult: click icon → creates consultation → opens chat
3. Task chat: negotiate/quote/counter/accept/reject/formal-apply/close all work
4. Flea market detail page: consult icon visible
5. Flea market consult: click icon → creates consultation → opens chat
6. Flea market chat: negotiate/quote/counter/accept/reject/formal-buy/close all work
7. Message list: consultation chats route to correct ApplicationChatView
8. Existing service consultation still works unchanged

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration fixes for task and flea market consultation"
```
