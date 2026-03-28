# 达人服务咨询功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to start a lightweight consultation chat with experts directly from the service detail page, without submitting a formal application first. Support in-chat negotiation, quoting, and conversion to formal application/task creation.

**Architecture:** Adds a new `consulting` application status to the existing `ServiceApplication` model. Reuses `ApplicationChatView` with enhancements for consulting mode (service info card, action buttons for negotiate/quote/formal-apply). Backend adds 6 new API endpoints under existing routers. New negotiation message types rendered as interactive cards in chat.

**Tech Stack:** Python/FastAPI (backend), Flutter/BLoC (frontend), SQLAlchemy (ORM), Dart Equatable models

**Spec:** `docs/superpowers/specs/2026-03-28-expert-consultation-chat-design.md`

---

## File Map

### Backend (New Files)
- `backend/migrations/031_add_consulting_status.sql` — DB migration for consulting status and new message types

### Backend (Modified Files)
- `backend/app/task_expert_routes.py` — New endpoints: create consultation, negotiate, quote, negotiate-response, formal-apply, close
- `backend/app/schemas.py` — New Pydantic schemas for consultation/negotiation requests
- `backend/app/models.py` — Update `message_type` CHECK constraint to include new types

### Frontend (Modified Files)
- `link2ur/lib/core/constants/api_endpoints.dart` — New endpoint constants
- `link2ur/lib/data/repositories/task_expert_repository.dart` — New repository methods
- `link2ur/lib/data/models/task_application.dart` — Add `isConsulting` getter
- `link2ur/lib/data/models/message.dart` — Add negotiation-related fields to Message model
- `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart` — New events/handlers for consultation
- `link2ur/lib/features/task_expert/views/service_detail_view.dart` — Add "咨询达人" button to bottom bar
- `link2ur/lib/features/tasks/views/application_chat_view.dart` — Enhance for consulting mode (service card, action buttons, negotiation message rendering)
- `link2ur/lib/features/task_expert/views/expert_applications_management_view.dart` — Show "咨询中" status label
- `link2ur/lib/l10n/app_zh.arb` — Chinese l10n strings
- `link2ur/lib/l10n/app_en.arb` — English l10n strings
- `link2ur/lib/l10n/app_zh_Hant.arb` — Traditional Chinese l10n strings
- `link2ur/lib/l10n/app_localizations.dart` — Generated
- `link2ur/lib/l10n/app_localizations_zh.dart` — Generated
- `link2ur/lib/l10n/app_localizations_en.dart` — Generated

---

## Task 1: Backend — DB Migration & Model Update

**Files:**
- Create: `backend/migrations/031_add_consulting_status.sql`
- Modify: `backend/app/models.py` (message_type CHECK constraint)

- [ ] **Step 1: Create migration file**

```sql
-- 031_add_consulting_status.sql
-- Add consulting status to service_applications and new message types

-- 1. Update message_type CHECK constraint to include negotiation types
-- Drop old constraint
ALTER TABLE messages DROP CONSTRAINT IF EXISTS ck_messages_type;

-- Add new constraint with negotiation message types
ALTER TABLE messages ADD CONSTRAINT ck_messages_type
    CHECK (message_type IN ('normal', 'system', 'price_proposal', 'negotiation', 'quote', 'counter_offer', 'negotiation_accepted', 'negotiation_rejected'));

-- 2. service_applications.status is a VARCHAR(20) with no CHECK constraint,
--    so 'consulting' is already valid without schema changes.

-- 3. Add index for consulting applications lookup (unique active consulting per user+service)
CREATE INDEX IF NOT EXISTS ix_service_applications_consulting
    ON service_applications (applicant_id, service_id, status)
    WHERE status = 'consulting';
```

- [ ] **Step 2: Update Message model CHECK constraint in models.py**

In `backend/app/models.py`, find the `ck_messages_type` constraint (around line 455) and update it:

```python
# Old:
CheckConstraint(
    "message_type IN ('normal', 'system', 'price_proposal')",
    name="ck_messages_type"
),
# New:
CheckConstraint(
    "message_type IN ('normal', 'system', 'price_proposal', 'negotiation', 'quote', 'counter_offer', 'negotiation_accepted', 'negotiation_rejected')",
    name="ck_messages_type"
),
```

- [ ] **Step 3: Run migration**

```bash
cd backend
# Apply migration via your DB tool or Railway console
```

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/031_add_consulting_status.sql backend/app/models.py
git commit -m "feat: add consulting status and negotiation message types to DB"
```

---

## Task 2: Backend — Pydantic Schemas for Consultation & Negotiation

**Files:**
- Modify: `backend/app/schemas.py`

- [ ] **Step 1: Add new schemas after `ServiceApplicationOut` (around line 2720)**

```python
class ConsultationOut(BaseModel):
    """Response for creating/getting a consultation"""
    application_id: int
    service_id: int
    task_id: Optional[int] = None
    status: str
    created_at: datetime.datetime
    is_existing: bool = False  # True if returning existing consultation

    class Config:
        from_attributes = True


class NegotiateRequest(BaseModel):
    """User initiates price negotiation"""
    proposed_price: condecimal(gt=0, max_digits=12, decimal_places=2)


class QuoteRequest(BaseModel):
    """Expert quotes a price"""
    quoted_price: condecimal(gt=0, max_digits=12, decimal_places=2)
    message: Optional[str] = None


class NegotiateResponseRequest(BaseModel):
    """Response to a negotiation/quote"""
    action: Literal["accept", "reject", "counter"]
    counter_price: Optional[condecimal(gt=0, max_digits=12, decimal_places=2)] = None

    @model_validator(mode="after")
    def validate_counter_price(self):
        if self.action == "counter" and self.counter_price is None:
            raise ValueError("counter_price is required when action is 'counter'")
        return self


class FormalApplyRequest(BaseModel):
    """Convert consultation to formal application"""
    proposed_price: Optional[condecimal(gt=0, max_digits=12, decimal_places=2)] = None
    message: Optional[str] = None
    time_slot_id: Optional[int] = None
    deadline: Optional[datetime.datetime] = None
    is_flexible: Optional[int] = 0
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat: add Pydantic schemas for consultation and negotiation"
```

---

## Task 3: Backend — Consultation & Negotiation API Endpoints

**Files:**
- Modify: `backend/app/task_expert_routes.py`

This task adds 6 new endpoints to `task_expert_routes.py`. They go after the existing `apply_for_service` endpoint (after line ~2940).

- [ ] **Step 1: Add create consultation endpoint**

```python
@task_expert_router.post("/services/{service_id}/consult")
async def create_consultation(
    service_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建咨询申请（轻量，无需填写表单）"""
    # 1. Validate service exists and is active
    service = await db.get(models.TaskExpertService, service_id)
    if not service or service.status != "active":
        raise HTTPException(status_code=404, detail="服务不存在或未上架")

    # 2. Cannot consult own service
    is_own_service = False
    if service.is_personal_service:
        is_own_service = (service.user_id == current_user.id)
    else:
        is_own_service = (service.expert_id == current_user.id)
    if is_own_service:
        raise HTTPException(status_code=400, detail="不能咨询自己的服务")

    # 3. Check for existing active consulting application
    existing = await db.execute(
        select(models.ServiceApplication).where(
            models.ServiceApplication.service_id == service_id,
            models.ServiceApplication.applicant_id == current_user.id,
            models.ServiceApplication.status == "consulting",
        )
    )
    existing_app = existing.scalar_one_or_none()
    if existing_app:
        return {
            "application_id": existing_app.id,
            "service_id": existing_app.service_id,
            "task_id": existing_app.task_id,
            "status": existing_app.status,
            "created_at": existing_app.created_at.isoformat(),
            "is_existing": True,
        }

    # 4. Create lightweight consulting application
    application = models.ServiceApplication(
        service_id=service_id,
        applicant_id=current_user.id,
        expert_id=service.expert_id if not service.is_personal_service else None,
        service_owner_id=service.user_id if service.is_personal_service else None,
        status="consulting",
        currency=service.currency or "GBP",
        is_flexible=1,  # No deadline for consultation
    )
    db.add(application)
    await db.flush()

    # 5. Create a placeholder task for message routing
    #    (ApplicationChatView needs a task_id for message endpoints)
    new_task = models.Task(
        title=f"咨询: {service.service_name}",
        description=f"服务咨询 - {service.service_name}",
        reward=float(service.base_price),
        base_reward=float(service.base_price),
        currency=service.currency or "GBP",
        location=service.location or "线上",
        task_type=service.category or "其他",
        task_level="normal",
        poster_id=current_user.id,
        taker_id=service.user_id if service.is_personal_service else service.expert_id,
        expert_service_id=service.id,
        status="consulting",
        is_paid=0,
        task_source="consultation",
    )
    db.add(new_task)
    await db.flush()

    application.task_id = new_task.id
    await db.commit()
    await db.refresh(application)

    # 6. Send system message to start chat
    system_msg = models.Message(
        sender_id=None,
        receiver_id=service.user_id if service.is_personal_service else service.expert_id,
        content=f"{current_user.name} 想咨询您的服务「{service.service_name}」",
        task_id=new_task.id,
        application_id=application.id,
        message_type="system",
        conversation_type="task",
    )
    db.add(system_msg)
    await db.commit()

    return {
        "application_id": application.id,
        "service_id": application.service_id,
        "task_id": new_task.id,
        "status": application.status,
        "created_at": application.created_at.isoformat(),
        "is_existing": False,
    }
```

- [ ] **Step 2: Add negotiate endpoint (user initiates)**

```python
@task_expert_router.post("/applications/{application_id}/negotiate")
async def negotiate_price(
    application_id: int,
    request: schemas.NegotiateRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户发起议价"""
    application = await db.get(models.ServiceApplication, application_id)
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status not in ("consulting", "negotiating"):
        raise HTTPException(status_code=400, detail="当前状态不允许议价")

    application.status = "negotiating"
    application.negotiated_price = request.proposed_price
    application.updated_at = get_utc_time()

    # Insert negotiation message into chat
    price_display = f"£{float(request.proposed_price):.2f}"
    msg = models.Message(
        sender_id=current_user.id,
        receiver_id=application.service_owner_id or application.expert_id,
        content=price_display,
        task_id=application.task_id,
        application_id=application.id,
        message_type="negotiation",
        conversation_type="task",
        meta=json.dumps({"price": float(request.proposed_price), "currency": application.currency}),
    )
    db.add(msg)
    await db.commit()

    return {"message": "议价已发送", "status": "negotiating", "application_id": application_id}
```

- [ ] **Step 3: Add quote endpoint (expert initiates)**

```python
@task_expert_router.post("/applications/{application_id}/quote")
async def quote_price(
    application_id: int,
    request: schemas.QuoteRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """达人/服务主报价"""
    application = await db.get(models.ServiceApplication, application_id)
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # Verify current user is the service owner
    is_owner = (application.service_owner_id == current_user.id) or (application.expert_id == current_user.id)
    if not is_owner:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status not in ("consulting", "negotiating"):
        raise HTTPException(status_code=400, detail="当前状态不允许报价")

    application.status = "negotiating"
    application.expert_counter_price = request.quoted_price
    application.updated_at = get_utc_time()

    price_display = f"£{float(request.quoted_price):.2f}"
    quote_content = price_display
    if request.message:
        quote_content = f"{price_display}\n{request.message}"

    msg = models.Message(
        sender_id=current_user.id,
        receiver_id=application.applicant_id,
        content=quote_content,
        task_id=application.task_id,
        application_id=application.id,
        message_type="quote",
        conversation_type="task",
        meta=json.dumps({
            "price": float(request.quoted_price),
            "currency": application.currency,
            "message": request.message,
        }),
    )
    db.add(msg)
    await db.commit()

    return {"message": "报价已发送", "status": "negotiating", "application_id": application_id}
```

- [ ] **Step 4: Add negotiate-response endpoint**

```python
@task_expert_router.post("/applications/{application_id}/negotiate-response")
async def negotiate_response(
    application_id: int,
    request: schemas.NegotiateResponseRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """回应议价/报价（同意/拒绝/还价）"""
    application = await db.get(models.ServiceApplication, application_id)
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # Both parties can respond
    is_applicant = application.applicant_id == current_user.id
    is_owner = (application.service_owner_id == current_user.id) or (application.expert_id == current_user.id)
    if not is_applicant and not is_owner:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status != "negotiating":
        raise HTTPException(status_code=400, detail="当前状态不允许此操作")

    receiver_id = application.applicant_id if is_owner else (application.service_owner_id or application.expert_id)

    if request.action == "accept":
        # Determine agreed price
        agreed_price = application.expert_counter_price or application.negotiated_price
        if not agreed_price:
            raise HTTPException(status_code=400, detail="无法确定最终价格")

        application.status = "price_agreed"
        application.final_price = agreed_price
        application.price_agreed_at = get_utc_time()
        application.updated_at = get_utc_time()

        price_display = f"£{float(agreed_price):.2f}"
        msg = models.Message(
            sender_id=current_user.id,
            receiver_id=receiver_id,
            content=f"双方已同意价格 {price_display}",
            task_id=application.task_id,
            application_id=application.id,
            message_type="negotiation_accepted",
            conversation_type="task",
            meta=json.dumps({"price": float(agreed_price), "currency": application.currency}),
        )
        db.add(msg)
        await db.commit()

        # Now auto-create/update the task via owner_approve flow
        # We reuse the existing approval logic by calling it internally
        # For now, return price_agreed status; frontend handles the next step
        return {
            "message": "价格已达成一致",
            "status": "price_agreed",
            "agreed_price": float(agreed_price),
            "application_id": application_id,
        }

    elif request.action == "reject":
        application.status = "consulting"
        application.updated_at = get_utc_time()

        msg = models.Message(
            sender_id=current_user.id,
            receiver_id=receiver_id,
            content="对方拒绝了报价",
            task_id=application.task_id,
            application_id=application.id,
            message_type="negotiation_rejected",
            conversation_type="task",
        )
        db.add(msg)
        await db.commit()

        return {"message": "已拒绝", "status": "consulting", "application_id": application_id}

    elif request.action == "counter":
        # Update the price fields based on who is countering
        if is_applicant:
            application.negotiated_price = request.counter_price
        else:
            application.expert_counter_price = request.counter_price
        application.updated_at = get_utc_time()

        price_display = f"£{float(request.counter_price):.2f}"
        msg = models.Message(
            sender_id=current_user.id,
            receiver_id=receiver_id,
            content=price_display,
            task_id=application.task_id,
            application_id=application.id,
            message_type="counter_offer",
            conversation_type="task",
            meta=json.dumps({"price": float(request.counter_price), "currency": application.currency}),
        )
        db.add(msg)
        await db.commit()

        return {"message": "还价已发送", "status": "negotiating", "application_id": application_id}
```

- [ ] **Step 5: Add formal-apply endpoint**

```python
@task_expert_router.post("/applications/{application_id}/formal-apply")
async def formal_apply(
    application_id: int,
    request: schemas.FormalApplyRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """咨询转正式申请"""
    application = await db.get(models.ServiceApplication, application_id)
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status != "consulting":
        raise HTTPException(status_code=400, detail="只有咨询状态可以转为正式申请")

    # Update application fields
    application.status = "pending"
    if request.proposed_price is not None:
        application.negotiated_price = request.proposed_price
    if request.message:
        application.application_message = request.message
    if request.time_slot_id is not None:
        application.time_slot_id = request.time_slot_id
    if request.deadline is not None:
        application.deadline = request.deadline
    application.is_flexible = request.is_flexible or 0
    application.updated_at = get_utc_time()

    # System message
    msg = models.Message(
        sender_id=None,
        receiver_id=application.service_owner_id or application.expert_id,
        content=f"{current_user.name} 已提交正式申请",
        task_id=application.task_id,
        application_id=application.id,
        message_type="system",
        conversation_type="task",
    )
    db.add(msg)
    await db.commit()
    await db.refresh(application)

    return {
        "message": "已转为正式申请",
        "status": "pending",
        "application_id": application_id,
    }
```

- [ ] **Step 6: Add close consultation endpoint**

```python
@task_expert_router.post("/applications/{application_id}/close")
async def close_consultation(
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """关闭咨询"""
    application = await db.get(models.ServiceApplication, application_id)
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    is_applicant = application.applicant_id == current_user.id
    is_owner = (application.service_owner_id == current_user.id) or (application.expert_id == current_user.id)
    if not is_applicant and not is_owner:
        raise HTTPException(status_code=403, detail="无权操作")
    if application.status not in ("consulting", "negotiating"):
        raise HTTPException(status_code=400, detail="当前状态不允许关闭")

    application.status = "cancelled"
    application.updated_at = get_utc_time()

    msg = models.Message(
        sender_id=None,
        receiver_id=application.applicant_id if is_owner else (application.service_owner_id or application.expert_id),
        content="咨询已关闭",
        task_id=application.task_id,
        application_id=application.id,
        message_type="system",
        conversation_type="task",
    )
    db.add(msg)
    await db.commit()

    return {"message": "咨询已关闭", "status": "cancelled", "application_id": application_id}
```

- [ ] **Step 7: Update `send_task_message` to allow consulting status**

In `backend/app/task_chat_routes.py`, find the `send_task_message` handler. It currently validates that the application status is `"chatting"` before allowing messages. Update this check to also allow `"consulting"` and `"negotiating"`:

Find the line (approximately line 1010-1020):
```python
if app_record.status != "chatting":
```

Change to:
```python
if app_record.status not in ("chatting", "consulting", "negotiating"):
```

- [ ] **Step 8: Commit**

```bash
git add backend/app/task_expert_routes.py backend/app/task_chat_routes.py
git commit -m "feat: add consultation and negotiation API endpoints"
```

---

## Task 4: Frontend — L10n Strings

**Files:**
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add Chinese l10n strings to `app_zh.arb`**

Add after the existing `expertApplication*` keys:

```json
"consultExpert": "咨询达人",
"continueConsultation": "继续咨询",
"consultationStarted": "咨询已创建",
"consultationFailed": "创建咨询失败",
"consultationStatus": "咨询中",
"negotiatePrice": "议价",
"quotePrice": "报价",
"formalApply": "正式申请",
"closeConsultation": "关闭咨询",
"closeConsultationConfirm": "确定关闭咨询吗？",
"negotiatePriceHint": "输入您的期望价格",
"quotePriceHint": "输入您的报价",
"quoteMessageHint": "添加报价说明（可选）",
"negotiationSent": "议价已发送",
"quoteSent": "报价已发送",
"negotiationAccepted": "已同意报价",
"negotiationRejected": "已拒绝报价",
"counterOffer": "还价",
"counterOfferHint": "输入还价金额",
"acceptPrice": "同意",
"rejectPrice": "拒绝",
"priceAgreed": "价格已达成一致",
"formalApplySubmitted": "已转为正式申请",
"consultationClosed": "咨询已关闭",
"serviceInfoCard": "服务信息",
"expertApplicationStatusConsulting": "咨询中"
```

- [ ] **Step 2: Add English l10n strings to `app_en.arb`**

```json
"consultExpert": "Consult Expert",
"continueConsultation": "Continue Consultation",
"consultationStarted": "Consultation created",
"consultationFailed": "Failed to create consultation",
"consultationStatus": "Consulting",
"negotiatePrice": "Negotiate",
"quotePrice": "Quote",
"formalApply": "Formal Apply",
"closeConsultation": "Close Consultation",
"closeConsultationConfirm": "Close this consultation?",
"negotiatePriceHint": "Enter your desired price",
"quotePriceHint": "Enter your quote price",
"quoteMessageHint": "Add a note (optional)",
"negotiationSent": "Negotiation sent",
"quoteSent": "Quote sent",
"negotiationAccepted": "Price accepted",
"negotiationRejected": "Price rejected",
"counterOffer": "Counter Offer",
"counterOfferHint": "Enter counter price",
"acceptPrice": "Accept",
"rejectPrice": "Reject",
"priceAgreed": "Price agreed",
"formalApplySubmitted": "Formal application submitted",
"consultationClosed": "Consultation closed",
"serviceInfoCard": "Service Info",
"expertApplicationStatusConsulting": "Consulting"
```

- [ ] **Step 3: Add Traditional Chinese l10n strings to `app_zh_Hant.arb`**

```json
"consultExpert": "諮詢達人",
"continueConsultation": "繼續諮詢",
"consultationStarted": "諮詢已建立",
"consultationFailed": "建立諮詢失敗",
"consultationStatus": "諮詢中",
"negotiatePrice": "議價",
"quotePrice": "報價",
"formalApply": "正式申請",
"closeConsultation": "關閉諮詢",
"closeConsultationConfirm": "確定關閉諮詢嗎？",
"negotiatePriceHint": "輸入您的期望價格",
"quotePriceHint": "輸入您的報價",
"quoteMessageHint": "添加報價說明（可選）",
"negotiationSent": "議價已發送",
"quoteSent": "報價已發送",
"negotiationAccepted": "已同意報價",
"negotiationRejected": "已拒絕報價",
"counterOffer": "還價",
"counterOfferHint": "輸入還價金額",
"acceptPrice": "同意",
"rejectPrice": "拒絕",
"priceAgreed": "價格已達成一致",
"formalApplySubmitted": "已轉為正式申請",
"consultationClosed": "諮詢已關閉",
"serviceInfoCard": "服務資訊",
"expertApplicationStatusConsulting": "諮詢中"
```

- [ ] **Step 4: Generate l10n files**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat: add l10n strings for consultation and negotiation"
```

---

## Task 5: Frontend — API Endpoints & Repository Methods

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/repositories/task_expert_repository.dart`

- [ ] **Step 1: Add endpoint constants to `api_endpoints.dart`**

Add after the existing expert application endpoints (around line 238):

```dart
// Consultation endpoints
static String consultService(int serviceId) =>
    '/api/task-experts/services/$serviceId/consult';
static String negotiateApplication(int applicationId) =>
    '/api/task-experts/applications/$applicationId/negotiate';
static String quoteApplication(int applicationId) =>
    '/api/task-experts/applications/$applicationId/quote';
static String negotiateResponse(int applicationId) =>
    '/api/task-experts/applications/$applicationId/negotiate-response';
static String formalApply(int applicationId) =>
    '/api/task-experts/applications/$applicationId/formal-apply';
static String closeConsultation(int applicationId) =>
    '/api/task-experts/applications/$applicationId/close';
```

- [ ] **Step 2: Add repository methods to `task_expert_repository.dart`**

Add after the existing `counterOfferServiceApplication` method (around line 736):

```dart
/// 创建咨询申请
Future<Map<String, dynamic>> createConsultation(int serviceId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.consultService(serviceId),
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '创建咨询失败');
  }

  return response.data!;
}

/// 用户发起议价
Future<Map<String, dynamic>> negotiatePrice(
  int applicationId, {
  required double proposedPrice,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.negotiateApplication(applicationId),
    data: {'proposed_price': proposedPrice},
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '议价失败');
  }

  return response.data!;
}

/// 达人报价
Future<Map<String, dynamic>> quotePrice(
  int applicationId, {
  required double quotedPrice,
  String? message,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.quoteApplication(applicationId),
    data: {
      'quoted_price': quotedPrice,
      if (message != null && message.isNotEmpty) 'message': message,
    },
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '报价失败');
  }

  return response.data!;
}

/// 回应议价/报价
Future<Map<String, dynamic>> respondToNegotiation(
  int applicationId, {
  required String action,
  double? counterPrice,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.negotiateResponse(applicationId),
    data: {
      'action': action,
      if (counterPrice != null) 'counter_price': counterPrice,
    },
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '操作失败');
  }

  return response.data!;
}

/// 咨询转正式申请
Future<Map<String, dynamic>> formalApply(
  int applicationId, {
  double? proposedPrice,
  String? message,
  int? timeSlotId,
  String? deadline,
  int isFlexible = 0,
}) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.formalApply(applicationId),
    data: {
      if (proposedPrice != null) 'proposed_price': proposedPrice,
      if (message != null && message.isNotEmpty) 'message': message,
      if (timeSlotId != null) 'time_slot_id': timeSlotId,
      if (deadline != null) 'deadline': deadline,
      'is_flexible': isFlexible,
    },
  );

  if (!response.isSuccess || response.data == null) {
    throw TaskExpertException(response.message ?? '提交申请失败');
  }

  return response.data!;
}

/// 关闭咨询
Future<void> closeConsultation(int applicationId) async {
  final response = await _apiService.post(
    ApiEndpoints.closeConsultation(applicationId),
  );

  if (!response.isSuccess) {
    throw TaskExpertException(response.message ?? '关闭咨询失败');
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/task_expert_repository.dart
git commit -m "feat: add API endpoints and repository methods for consultation"
```

---

## Task 6: Frontend — Model Updates

**Files:**
- Modify: `link2ur/lib/data/models/task_application.dart`
- Modify: `link2ur/lib/data/models/message.dart`

- [ ] **Step 1: Add `isConsulting` getter to `TaskApplication`**

In `task_application.dart`, add after the existing `isChatting` getter (around line 44):

```dart
bool get isConsulting => status == 'consulting';
bool get isNegotiating => status == 'negotiating';
```

- [ ] **Step 2: Add negotiation fields to `Message` model**

In `message.dart`, add `negotiationPrice` and `negotiationCurrency` fields to the `Message` class:

Add fields to the constructor (after `attachments`):
```dart
this.negotiationPrice,
this.negotiationCurrency,
```

Add field declarations:
```dart
final double? negotiationPrice;
final String? negotiationCurrency;
```

Add helper getters:
```dart
bool get isNegotiation => messageType == 'negotiation';
bool get isQuote => messageType == 'quote';
bool get isCounterOffer => messageType == 'counter_offer';
bool get isNegotiationAccepted => messageType == 'negotiation_accepted';
bool get isNegotiationRejected => messageType == 'negotiation_rejected';
bool get isNegotiationType => isNegotiation || isQuote || isCounterOffer || isNegotiationAccepted || isNegotiationRejected;
```

Update `fromJson` to parse meta for negotiation data:
```dart
// In fromJson, after existing parsing:
final metaStr = json['meta'] as String?;
Map<String, dynamic>? metaMap;
if (metaStr != null && metaStr.isNotEmpty) {
  try {
    metaMap = jsonDecode(metaStr) as Map<String, dynamic>?;
  } catch (_) {}
}
```

Then use `metaMap` for negotiation fields:
```dart
negotiationPrice: metaMap?['price'] != null
    ? (metaMap!['price'] as num).toDouble()
    : null,
negotiationCurrency: metaMap?['currency'] as String?,
```

Add `negotiationPrice` and `negotiationCurrency` to the `props` list.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/task_application.dart link2ur/lib/data/models/message.dart
git commit -m "feat: add consulting status and negotiation fields to models"
```

---

## Task 7: Frontend — BLoC Events & Handlers

**Files:**
- Modify: `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart`

- [ ] **Step 1: Add new events**

Add after `TaskExpertApplyServiceEnhanced` (around line 189):

```dart
/// 创建咨询
class TaskExpertStartConsultation extends TaskExpertEvent {
  const TaskExpertStartConsultation(this.serviceId);
  final int serviceId;

  @override
  List<Object?> get props => [serviceId];
}

/// 用户议价
class TaskExpertNegotiatePrice extends TaskExpertEvent {
  const TaskExpertNegotiatePrice(this.applicationId, {required this.price});
  final int applicationId;
  final double price;

  @override
  List<Object?> get props => [applicationId, price];
}

/// 达人报价
class TaskExpertQuotePrice extends TaskExpertEvent {
  const TaskExpertQuotePrice(this.applicationId, {required this.price, this.message});
  final int applicationId;
  final double price;
  final String? message;

  @override
  List<Object?> get props => [applicationId, price, message];
}

/// 回应议价/报价
class TaskExpertNegotiateResponse extends TaskExpertEvent {
  const TaskExpertNegotiateResponse(this.applicationId, {required this.action, this.counterPrice});
  final int applicationId;
  final String action; // 'accept', 'reject', 'counter'
  final double? counterPrice;

  @override
  List<Object?> get props => [applicationId, action, counterPrice];
}

/// 咨询转正式申请
class TaskExpertFormalApply extends TaskExpertEvent {
  const TaskExpertFormalApply(
    this.applicationId, {
    this.proposedPrice,
    this.message,
    this.timeSlotId,
    this.deadline,
    this.isFlexible = 0,
  });
  final int applicationId;
  final double? proposedPrice;
  final String? message;
  final int? timeSlotId;
  final String? deadline;
  final int isFlexible;

  @override
  List<Object?> get props => [applicationId, proposedPrice, message, timeSlotId, deadline, isFlexible];
}

/// 关闭咨询
class TaskExpertCloseConsultation extends TaskExpertEvent {
  const TaskExpertCloseConsultation(this.applicationId);
  final int applicationId;

  @override
  List<Object?> get props => [applicationId];
}
```

- [ ] **Step 2: Register event handlers in constructor**

Add in the bloc constructor, after existing `on<>` registrations:

```dart
on<TaskExpertStartConsultation>(_onStartConsultation);
on<TaskExpertNegotiatePrice>(_onNegotiatePrice);
on<TaskExpertQuotePrice>(_onQuotePrice);
on<TaskExpertNegotiateResponse>(_onNegotiateResponse);
on<TaskExpertFormalApply>(_onFormalApply);
on<TaskExpertCloseConsultation>(_onCloseConsultation);
```

- [ ] **Step 3: Add handler implementations**

Add after the existing `_onCounterOffer` handler:

```dart
Future<void> _onStartConsultation(
  TaskExpertStartConsultation event,
  Emitter<TaskExpertState> emit,
) async {
  emit(state.copyWith(isSubmitting: true, errorMessage: null, actionMessage: null));
  try {
    final result = await _taskExpertRepository.createConsultation(event.serviceId);
    emit(state.copyWith(
      isSubmitting: false,
      actionMessage: 'consultation_started',
      consultationData: result,
    ));
  } on TaskExpertException catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.message, actionMessage: 'consultation_failed'));
  } catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.toString(), actionMessage: 'consultation_failed'));
  }
}

Future<void> _onNegotiatePrice(
  TaskExpertNegotiatePrice event,
  Emitter<TaskExpertState> emit,
) async {
  emit(state.copyWith(isSubmitting: true, errorMessage: null, actionMessage: null));
  try {
    await _taskExpertRepository.negotiatePrice(event.applicationId, proposedPrice: event.price);
    emit(state.copyWith(isSubmitting: false, actionMessage: 'negotiation_sent'));
  } on TaskExpertException catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
  } catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
  }
}

Future<void> _onQuotePrice(
  TaskExpertQuotePrice event,
  Emitter<TaskExpertState> emit,
) async {
  emit(state.copyWith(isSubmitting: true, errorMessage: null, actionMessage: null));
  try {
    await _taskExpertRepository.quotePrice(event.applicationId, quotedPrice: event.price, message: event.message);
    emit(state.copyWith(isSubmitting: false, actionMessage: 'quote_sent'));
  } on TaskExpertException catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
  } catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
  }
}

Future<void> _onNegotiateResponse(
  TaskExpertNegotiateResponse event,
  Emitter<TaskExpertState> emit,
) async {
  emit(state.copyWith(isSubmitting: true, errorMessage: null, actionMessage: null));
  try {
    final result = await _taskExpertRepository.respondToNegotiation(
      event.applicationId,
      action: event.action,
      counterPrice: event.counterPrice,
    );
    final status = result['status'] as String? ?? '';
    emit(state.copyWith(
      isSubmitting: false,
      actionMessage: 'negotiate_response_$status',
    ));
  } on TaskExpertException catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
  } catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
  }
}

Future<void> _onFormalApply(
  TaskExpertFormalApply event,
  Emitter<TaskExpertState> emit,
) async {
  emit(state.copyWith(isSubmitting: true, errorMessage: null, actionMessage: null));
  try {
    await _taskExpertRepository.formalApply(
      event.applicationId,
      proposedPrice: event.proposedPrice,
      message: event.message,
      timeSlotId: event.timeSlotId,
      deadline: event.deadline,
      isFlexible: event.isFlexible,
    );
    emit(state.copyWith(isSubmitting: false, actionMessage: 'formal_apply_submitted'));
  } on TaskExpertException catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
  } catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
  }
}

Future<void> _onCloseConsultation(
  TaskExpertCloseConsultation event,
  Emitter<TaskExpertState> emit,
) async {
  emit(state.copyWith(isSubmitting: true, errorMessage: null, actionMessage: null));
  try {
    await _taskExpertRepository.closeConsultation(event.applicationId);
    emit(state.copyWith(isSubmitting: false, actionMessage: 'consultation_closed'));
  } on TaskExpertException catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
  } catch (e) {
    emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
  }
}
```

- [ ] **Step 4: Add `consultationData` field to state**

In `TaskExpertState`, add:

```dart
final Map<String, dynamic>? consultationData;
```

Add to constructor, `props`, and `copyWith`. The `consultationData` holds the response from `createConsultation` (contains `application_id`, `task_id`, etc.) so the view can navigate to the chat.

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart
git commit -m "feat: add BLoC events and handlers for consultation and negotiation"
```

---

## Task 8: Frontend — Service Detail Page "咨询达人" Button

**Files:**
- Modify: `link2ur/lib/features/task_expert/views/service_detail_view.dart`

- [ ] **Step 1: Update `_BottomApplyBar` to include consult button**

In the `_BottomApplyBar.build()` method (around line 1233), modify the `Row` children to add a consult button before the apply button. The current layout has an optional "Ask" question button on the left and the main apply button on the right.

Add a new consult button between them. The logic:
- If user is service owner: don't show consult button
- If user has existing `consulting` application: show "继续咨询" button
- Otherwise: show "咨询达人" button

Update the `Row` children section to add a consult button. Find the area around line 1270 where the main button Row is built. Before the existing apply button (`Expanded` child), add:

```dart
// Consult button (left side, secondary style)
if (!_isOwner)
  Expanded(
    child: BlocConsumer<TaskExpertBloc, TaskExpertState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage &&
          (curr.actionMessage == 'consultation_started' || curr.actionMessage == 'consultation_failed'),
      listener: (context, state) {
        if (state.actionMessage == 'consultation_started' && state.consultationData != null) {
          final taskId = state.consultationData!['task_id'] as int?;
          final appId = state.consultationData!['application_id'] as int?;
          if (taskId != null && appId != null) {
            context.push('/tasks/$taskId/applications/$appId/chat');
          }
        } else if (state.actionMessage == 'consultation_failed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage))),
          );
        }
      },
      builder: (context, state) {
        final hasConsulting = service.userApplicationStatus == 'consulting';
        final label = hasConsulting
            ? context.l10n.continueConsultation
            : context.l10n.consultExpert;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton.icon(
            onPressed: state.isSubmitting
                ? null
                : () {
                    if (hasConsulting && service.userApplicationId != null) {
                      // Navigate to existing consultation chat
                      // Need task_id — fetch from service application data
                      context.read<TaskExpertBloc>().add(
                        TaskExpertStartConsultation(serviceId),
                      );
                    } else {
                      context.read<TaskExpertBloc>().add(
                        TaskExpertStartConsultation(serviceId),
                      );
                    }
                  },
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(hasConsulting ? Icons.chat : Icons.chat_bubble_outline, size: 18),
            label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
            ),
          ),
        );
      },
    ),
  ),
```

The existing apply button should also be wrapped in `Expanded`.

- [ ] **Step 2: Ensure `_isOwner` is accessible as a getter**

The existing `_isServiceOwner` method is on `_ServiceDetailContent`. Make sure the `_BottomApplyBar` has access to it. It currently receives `service` and can check `service.userId == currentUserId` or `service.expertId == currentUserId`. Add a helper:

```dart
bool get _isOwner {
  final userId = StorageService.instance.getUserId();
  if (userId == null) return false;
  if (service.isPersonalService) return service.userId == userId;
  return service.expertId == userId;
}
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/task_expert/views/service_detail_view.dart
git commit -m "feat: add consult expert button to service detail bottom bar"
```

---

## Task 9: Frontend — ApplicationChatView Enhancement (Consulting Mode)

**Files:**
- Modify: `link2ur/lib/features/tasks/views/application_chat_view.dart`

This is the largest frontend task. The ApplicationChatView needs to:
1. Show a service info card at the top when in consulting/negotiating mode
2. Render negotiation message types as interactive cards
3. Show action buttons (negotiate/quote/formal-apply/close) based on role and status
4. Allow sending messages in consulting and negotiating states (not just chatting)

- [ ] **Step 1: Update `isChatActive` check to include consulting/negotiating**

In `_ApplicationChatContentState.build()` (around line 316), change:

```dart
// Old:
final isChatActive = application?.isChatting ?? false;
// New:
final isChatActive = application?.isChatting == true ||
    application?.isConsulting == true ||
    application?.isNegotiating == true;
```

- [ ] **Step 2: Add service info card widget**

Add a new method after `_buildPriceBar`:

```dart
Widget _buildServiceInfoCard(TaskDetailState state) {
  final task = state.task;
  if (task == null) return const SizedBox.shrink();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.2),
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: const Icon(Icons.design_services, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.displayReward != null)
                Text(
                  '${Helpers.currencySymbolFor(task.currency ?? "GBP")}${task.displayReward!.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Add negotiation message card rendering**

Add methods for rendering negotiation/quote/counter_offer messages as interactive cards:

```dart
Widget _buildNegotiationCard(Message message, bool isMe) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final price = message.negotiationPrice;
  final currency = message.negotiationCurrency ?? 'GBP';
  final symbol = Helpers.currencySymbolFor(currency);

  String title;
  IconData icon;
  if (message.isNegotiation) {
    title = context.l10n.negotiatePrice;
    icon = Icons.local_offer;
  } else if (message.isQuote) {
    title = context.l10n.quotePrice;
    icon = Icons.request_quote;
  } else {
    title = context.l10n.counterOffer;
    icon = Icons.swap_horiz;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
    child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2340), const Color(0xFF1E2A4A)]
                : [const Color(0xFFF0F4FF), const Color(0xFFE8EEFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            if (price != null)
              Text(
                '$symbol${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            // Show accept/reject/counter buttons only for the other party
            if (!isMe) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNegotiationActionButton(
                    label: context.l10n.acceptPrice,
                    color: AppColors.success,
                    onPressed: () => _handleNegotiationResponse('accept'),
                  ),
                  const SizedBox(width: 8),
                  _buildNegotiationActionButton(
                    label: context.l10n.rejectPrice,
                    color: AppColors.error,
                    onPressed: () => _handleNegotiationResponse('reject'),
                  ),
                  const SizedBox(width: 8),
                  _buildNegotiationActionButton(
                    label: context.l10n.counterOffer,
                    color: AppColors.primary,
                    onPressed: _showCounterOfferDialog,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget _buildNegotiationActionButton({
  required String label,
  required Color color,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    height: 30,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(label),
    ),
  );
}

Widget _buildNegotiationStatusMessage(Message message) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isAccepted = message.isNegotiationAccepted;
  final color = isAccepted ? AppColors.success : AppColors.error;
  final icon = isAccepted ? Icons.check_circle : Icons.cancel;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message.content,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Add action handlers for negotiation responses**

```dart
void _handleNegotiationResponse(String action) {
  // This will be dispatched via the TaskExpertBloc which needs to be provided
  // Since ApplicationChatView uses TaskDetailBloc, we need a way to call
  // the negotiation APIs. Use ApiService directly (same pattern as _sendMessage).
  if (action == 'accept' || action == 'reject') {
    _respondToNegotiation(action);
  }
}

Future<void> _respondToNegotiation(String action) async {
  try {
    final apiService = context.read<ApiService>();
    final response = await apiService.post<Map<String, dynamic>>(
      ApiEndpoints.negotiateResponse(widget.applicationId),
      data: {'action': action},
    );

    if (!mounted) return;
    if (response.isSuccess) {
      _loadMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'accept'
            ? context.l10n.negotiationAccepted
            : context.l10n.negotiationRejected)),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizeError(e.toString()))),
    );
  }
}

void _showCounterOfferDialog() {
  final priceController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.counterOffer),
      content: TextField(
        controller: priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: context.l10n.counterOfferHint,
          prefixText: '£',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () async {
            final price = double.tryParse(priceController.text.trim());
            if (price == null || price <= 0) return;
            Navigator.pop(dialogContext);
            try {
              final apiService = context.read<ApiService>();
              await apiService.post<Map<String, dynamic>>(
                ApiEndpoints.negotiateResponse(widget.applicationId),
                data: {'action': 'counter', 'counter_price': price},
              );
              if (mounted) _loadMessages();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.localizeError(e.toString()))),
                );
              }
            }
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  ).then((_) => priceController.dispose());
}
```

- [ ] **Step 5: Add consulting action buttons (negotiate/quote/formal-apply/close)**

Add a method for the consulting-mode action bar that sits above the input bar:

```dart
Widget _buildConsultingActions(TaskApplication application) {
  final isApplicant = _currentUserId == application.applicantId;
  final isConsulting = application.isConsulting;
  final isNegotiating = application.isNegotiating;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: isDark
          ? AppColors.cardBackgroundDark.withValues(alpha: 0.9)
          : AppColors.cardBackgroundLight.withValues(alpha: 0.95),
      border: Border(
        top: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (isConsulting && isApplicant) ...[
            _buildActionChip(
              label: context.l10n.negotiatePrice,
              icon: Icons.local_offer,
              onPressed: () => _showNegotiateDialog(),
            ),
            const SizedBox(width: 8),
            _buildActionChip(
              label: context.l10n.formalApply,
              icon: Icons.assignment,
              onPressed: () => _showFormalApplyDialog(),
            ),
          ],
          if (isConsulting && !isApplicant) ...[
            _buildActionChip(
              label: context.l10n.quotePrice,
              icon: Icons.request_quote,
              onPressed: () => _showQuoteDialog(),
            ),
          ],
          if (isConsulting || isNegotiating) ...[
            const SizedBox(width: 8),
            _buildActionChip(
              label: context.l10n.closeConsultation,
              icon: Icons.close,
              color: AppColors.error,
              onPressed: () => _showCloseConfirmation(),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildActionChip({
  required String label,
  required IconData icon,
  required VoidCallback onPressed,
  Color? color,
}) {
  final chipColor = color ?? AppColors.primary;
  return ActionChip(
    avatar: Icon(icon, size: 16, color: chipColor),
    label: Text(label, style: TextStyle(fontSize: 13, color: chipColor)),
    onPressed: onPressed,
    side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
    backgroundColor: chipColor.withValues(alpha: 0.08),
  );
}
```

- [ ] **Step 6: Add dialog methods for negotiate, quote, formal-apply, close**

```dart
void _showNegotiateDialog() {
  final priceController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.negotiatePrice),
      content: TextField(
        controller: priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: context.l10n.negotiatePriceHint,
          prefixText: '£',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () async {
            final price = double.tryParse(priceController.text.trim());
            if (price == null || price <= 0) return;
            Navigator.pop(dialogContext);
            try {
              final apiService = context.read<ApiService>();
              await apiService.post(
                ApiEndpoints.negotiateApplication(widget.applicationId),
                data: {'proposed_price': price},
              );
              if (mounted) {
                _loadMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.negotiationSent)),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.localizeError(e.toString()))),
                );
              }
            }
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  ).then((_) => priceController.dispose());
}

void _showQuoteDialog() {
  final priceController = TextEditingController();
  final messageController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.quotePrice),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: context.l10n.quotePriceHint,
              prefixText: '£',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: messageController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: context.l10n.quoteMessageHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () async {
            final price = double.tryParse(priceController.text.trim());
            if (price == null || price <= 0) return;
            Navigator.pop(dialogContext);
            try {
              final apiService = context.read<ApiService>();
              await apiService.post(
                ApiEndpoints.quoteApplication(widget.applicationId),
                data: {
                  'quoted_price': price,
                  if (messageController.text.trim().isNotEmpty)
                    'message': messageController.text.trim(),
                },
              );
              if (mounted) {
                _loadMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.quoteSent)),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.localizeError(e.toString()))),
                );
              }
            }
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  ).then((_) {
    priceController.dispose();
    messageController.dispose();
  });
}

void _showFormalApplyDialog() {
  final priceController = TextEditingController();
  final messageController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.formalApply),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: context.l10n.negotiatePriceHint,
              prefixText: '£',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: context.l10n.serviceNeedDescription,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              final apiService = context.read<ApiService>();
              final price = double.tryParse(priceController.text.trim());
              await apiService.post(
                ApiEndpoints.formalApply(widget.applicationId),
                data: {
                  if (price != null) 'proposed_price': price,
                  if (messageController.text.trim().isNotEmpty)
                    'message': messageController.text.trim(),
                  'is_flexible': 1,
                },
              );
              if (mounted) {
                _loadMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.formalApplySubmitted)),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.localizeError(e.toString()))),
                );
              }
            }
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  ).then((_) {
    priceController.dispose();
    messageController.dispose();
  });
}

void _showCloseConfirmation() {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.closeConsultation),
      content: Text(context.l10n.closeConsultationConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              final apiService = context.read<ApiService>();
              await apiService.post(ApiEndpoints.closeConsultation(widget.applicationId));
              if (mounted) {
                _loadMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.consultationClosed)),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.localizeError(e.toString()))),
                );
              }
            }
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(context.l10n.closeConsultation),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 7: Update build method to include new components**

In the `build()` method's `Column` children (around line 328), add the service info card and consulting actions:

```dart
body: Column(
  children: [
    // Service info card (consulting/negotiating mode)
    if (isLoaded && (application?.isConsulting == true || application?.isNegotiating == true))
      _buildServiceInfoCard(state),

    // Price bar (non-consulting mode)
    if (isLoaded && application?.isConsulting != true && application?.isNegotiating != true)
      _buildPriceBar(state, application),

    // Closed channel banner
    if (isLoaded && !isChatActive) _buildClosedBanner(),

    // Message list
    Expanded(child: _buildMessageList()),

    // Consulting action buttons
    if (isChatActive && application != null &&
        (application.isConsulting || application.isNegotiating))
      _buildConsultingActions(application),

    // Input bar (when chat is active)
    if (isChatActive) _buildInputBar(),

    // Confirm & Pay button (poster only, chatting mode — not consulting)
    if (application?.isChatting == true && isPoster)
      _buildConfirmAndPayButton(state),
  ],
),
```

- [ ] **Step 8: Update message list to render negotiation types**

In `_buildMessageList`, update the `itemBuilder` (around line 472):

```dart
itemBuilder: (context, index) {
  final message = _messages[index];
  final isMe = message.senderId == currentUserId;

  // Negotiation status messages (accepted/rejected)
  if (message.isNegotiationAccepted || message.isNegotiationRejected) {
    return _buildNegotiationStatusMessage(message);
  }

  // Negotiation/quote/counter_offer cards
  if (message.isNegotiation || message.isQuote || message.isCounterOffer) {
    return _buildNegotiationCard(message, isMe);
  }

  // Price proposal (existing)
  if (message.messageType == 'price_proposal') {
    return _buildPriceProposalBubble(message, isMe);
  }

  // System messages
  if (message.isSystem) {
    return _buildSystemMessage(message);
  }

  // Normal message bubble
  return _buildMessageBubble(message, isMe);
},
```

- [ ] **Step 9: Commit**

```bash
git add link2ur/lib/features/tasks/views/application_chat_view.dart
git commit -m "feat: enhance ApplicationChatView with consulting mode, negotiation cards, and action buttons"
```

---

## Task 10: Frontend — Expert Applications Management View Update

**Files:**
- Modify: `link2ur/lib/features/task_expert/views/expert_applications_management_view.dart`

- [ ] **Step 1: Add `consulting` status to color/label mapping**

Find the status color mapping (around line 169-192) and add consulting status:

```dart
'consulting' => AppColors.info,  // Blue color for consulting
```

The label will use the l10n key `expertApplicationStatusConsulting` which we added in Task 4.

Find where status labels are resolved (where `expertApplicationStatusPending`, etc. are used) and add:

```dart
'consulting' => context.l10n.expertApplicationStatusConsulting,
```

- [ ] **Step 2: Allow clicking consulting applications to open chat**

In the `_ApplicationCard` onTap handler, add navigation for consulting status applications. If an application has status `consulting` and a `task_id`, navigate to ApplicationChatView:

Find the card's `GestureDetector` or `InkWell` onTap (or add one if it doesn't exist). When status is `consulting` or `negotiating`, navigate to:

```dart
context.push('/tasks/${application.taskId}/applications/${application.id}/chat');
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/task_expert/views/expert_applications_management_view.dart
git commit -m "feat: show consulting status in expert applications management"
```

---

## Task 11: Integration Verification

- [ ] **Step 1: Run Flutter analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

Fix any errors or warnings.

- [ ] **Step 2: Run existing tests**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test
```

Fix any test failures.

- [ ] **Step 3: Manual verification checklist**

Verify the following flows work end-to-end:

1. **Create consultation**: Service detail page → "咨询达人" → creates consulting application → navigates to ApplicationChatView
2. **Repeat consultation**: Service detail page → "继续咨询" → navigates to existing chat
3. **Send messages**: Both user and expert can send text messages in consulting state
4. **User negotiate**: User clicks "议价" → enters price → negotiation card appears in chat
5. **Expert quote**: Expert clicks "报价" → enters price + message → quote card appears in chat
6. **Accept/Reject/Counter**: Other party sees action buttons on negotiation cards
7. **Formal apply**: User clicks "正式申请" → fills form → application status changes to pending
8. **Close consultation**: Either party clicks "关闭咨询" → status changes to cancelled
9. **Expert management**: Consulting applications show "咨询中" label with blue color

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete expert consultation chat feature"
```
