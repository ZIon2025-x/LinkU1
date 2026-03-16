# Task Chat Before Payment — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign task flow so poster and applicant can chat and negotiate price before payment commitment.

**Architecture:** Add `chatting` status to tasks and applications. Create per-application chat channels by adding `application_id` to the messages table. New backend endpoints for start-chat, propose-price, confirm-and-pay. Flutter UI gets an application chat view with inline price negotiation and payment trigger.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/BLoC (frontend), Stripe PaymentIntent, WebSocket

**Spec:** `docs/superpowers/specs/2026-03-16-task-chat-before-payment-design.md`

---

## Chunk 1: Backend — Database Migration & Models

### Task 1: Database Migration — Add `application_id` to Messages

**Files:**
- Create: `backend/alembic/versions/xxxx_add_application_id_to_messages.py`
- Modify: `backend/app/models.py:413-456` (Message model)
- Modify: `backend/app/models.py:952-966` (MessageReadCursor model)

- [ ] **Step 1: Create Alembic migration**

```python
"""add application_id to messages and message_read_cursors

Revision ID: auto-generated
"""
from alembic import op
import sqlalchemy as sa

def upgrade():
    op.add_column('messages', sa.Column('application_id', sa.Integer(),
                  sa.ForeignKey('task_applications.id', ondelete='CASCADE'), nullable=True))
    op.create_index('ix_messages_task_application', 'messages', ['task_id', 'application_id'])

    op.add_column('message_read_cursors', sa.Column('application_id', sa.Integer(),
                  sa.ForeignKey('task_applications.id', ondelete='CASCADE'), nullable=True))
    # Drop old unique constraint and add new one with application_id
    op.drop_constraint('uq_message_read_cursors_task_user', 'message_read_cursors', type_='unique')
    op.create_unique_constraint('uq_message_read_cursors_task_user_app',
                                'message_read_cursors', ['task_id', 'user_id', 'application_id'])

def downgrade():
    op.drop_constraint('uq_message_read_cursors_task_user_app', 'message_read_cursors', type_='unique')
    op.create_unique_constraint('uq_message_read_cursors_task_user',
                                'message_read_cursors', ['task_id', 'user_id'])
    op.drop_column('message_read_cursors', 'application_id')
    op.drop_index('ix_messages_task_application', 'messages')
    op.drop_column('messages', 'application_id')
```

- [ ] **Step 2: Update Message model (models.py:413-456)**

Add after line 428 (`meta` field):

```python
application_id = Column(Integer, ForeignKey("task_applications.id", ondelete="CASCADE"), nullable=True)
```

- [ ] **Step 3: Update MessageReadCursor model (models.py:952-966)**

Add after line 958 (`user_id` field):

```python
application_id = Column(Integer, ForeignKey("task_applications.id", ondelete="CASCADE"), nullable=True)
```

Update the unique constraint (line 963) from `(task_id, user_id)` to `(task_id, user_id, application_id)`.

- [ ] **Step 4: Add `chatting` status constant and update CHECK constraint**

Update the comment near TaskApplication model (models.py:753):

```python
status = Column(String(20), default="pending")  # pending, chatting, approved, rejected
```

- [ ] **Step 5: Add migration to update `message_type` CHECK constraint**

The existing CHECK constraint at models.py:440-442 only allows `'normal'` and `'system'`. We need to add `'price_proposal'`:

```python
# In the same migration file, add:
def upgrade():
    # ... (existing application_id column additions) ...

    # Update message_type CHECK constraint to include price_proposal
    op.drop_constraint('ck_messages_type', 'messages', type_='check')
    op.create_check_constraint('ck_messages_type', 'messages',
                               "message_type IN ('normal', 'system', 'price_proposal')")

def downgrade():
    # ... (existing downgrades) ...
    op.drop_constraint('ck_messages_type', 'messages', type_='check')
    op.create_check_constraint('ck_messages_type', 'messages',
                               "message_type IN ('normal', 'system')")
```

Also update the model constraint in models.py:440-442:

```python
CheckConstraint(
    "message_type IN ('normal', 'system', 'price_proposal')",
    name="ck_messages_type"
),
```

- [ ] **Step 5: Run migration and verify**

```bash
cd backend && alembic upgrade head
```

- [ ] **Step 6: Commit**

```bash
git add backend/alembic/versions/ backend/app/models.py
git commit -m "feat: add application_id to messages for per-application chat channels"
```

---

## Chunk 2: Backend — New Endpoints

### Task 2: `start-chat` Endpoint

**Files:**
- Modify: `backend/app/task_chat_routes.py` (add new endpoint after line 1805)

- [ ] **Step 1: Add `start-chat` endpoint**

Add after the `accept_application` endpoint (~line 1805). **IMPORTANT: Use async SQLAlchemy pattern** — `AsyncSession`, `select()`, `await db.execute()`, `await db.commit()` — matching the existing codebase style (see `accept_application` at line 1422 for reference).

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/start-chat")
async def start_application_chat(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """Poster agrees to chat with an applicant. Opens the chat channel."""
    from sqlalchemy import select, update

    task_result = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    if task.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only task poster can start chat")

    if task.status not in ("open", "chatting"):
        raise HTTPException(status_code=400, detail="Task is not accepting applications")

    if task.is_multi_participant:
        raise HTTPException(status_code=400, detail="Multi-participant tasks use direct accept flow")

    app_result = await db.execute(
        select(models.TaskApplication).where(
            models.TaskApplication.id == application_id,
            models.TaskApplication.task_id == task_id
        )
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    if application.status != "pending":
        raise HTTPException(status_code=400, detail=f"Application is already {application.status}")

    # Update application status
    await db.execute(
        update(models.TaskApplication)
        .where(models.TaskApplication.id == application_id)
        .values(status="chatting")
    )

    # Update task status to chatting if it was open
    if task.status == "open":
        await db.execute(
            update(models.Task).where(models.Task.id == task_id).values(status="chatting")
        )

    # Send system message to the new chat channel
    system_msg = models.Message(
        task_id=task_id,
        application_id=application_id,
        content="Chat channel opened. You can now discuss task details and negotiate price.",
        message_type="system",
        conversation_type="task"
    )
    db.add(system_msg)
    await db.commit()

    # TODO: Send notification to applicant (reuse existing notification logic)

    return {"status": "ok", "message": "Chat started", "application_status": "chatting"}
```

**Note for all subsequent backend endpoints:** Follow the same async pattern — `AsyncSession`, `select()`, `await db.execute()`, `update()`, `await db.commit()`. Reference `accept_application` (line 1422-1805) for the exact style used in this codebase.

- [ ] **Step 2: Test endpoint manually or with existing test framework**

```bash
# Verify server starts without errors
cd backend && python -m uvicorn app.main:app --port 8000
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: add start-chat endpoint for application chat channels"
```

### Task 3: `propose-price` Endpoint

**Files:**
- Modify: `backend/app/task_chat_routes.py`

- [ ] **Step 1: Add `propose-price` endpoint**

Use async SQLAlchemy pattern (same as `start-chat` above and `accept_application` reference):

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/propose-price")
async def propose_price(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """Either party proposes a new price during chatting phase."""
    from sqlalchemy import select, update
    from decimal import Decimal
    import json

    body = await request.json()
    proposed_price = body.get("proposedPrice")
    if proposed_price is None or proposed_price <= 0:
        raise HTTPException(status_code=400, detail="Invalid price")

    task_result = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    app_result = await db.execute(
        select(models.TaskApplication).where(
            models.TaskApplication.id == application_id,
            models.TaskApplication.task_id == task_id
        )
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    if application.status != "chatting":
        raise HTTPException(status_code=400, detail="Chat is not active for this application")

    if current_user.id not in (task.poster_id, application.applicant_id):
        raise HTTPException(status_code=403, detail="Not authorized")

    # Update negotiated price
    await db.execute(
        update(models.TaskApplication)
        .where(models.TaskApplication.id == application_id)
        .values(negotiated_price=Decimal(str(proposed_price)))
    )

    # Create price proposal message
    receiver = task.poster_id if current_user.id == application.applicant_id else application.applicant_id
    price_msg = models.Message(
        task_id=task_id,
        application_id=application_id,
        sender_id=current_user.id,
        receiver_id=receiver,
        content=f"Proposed new price: £{proposed_price:.2f}",
        message_type="price_proposal",
        conversation_type="task",
        meta=json.dumps({
            "proposedPrice": float(proposed_price),
            "proposedBy": current_user.id
        })
    )
    db.add(price_msg)
    await db.commit()

    return {
        "status": "ok",
        "negotiatedPrice": float(proposed_price),
    }
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: add propose-price endpoint for in-chat price negotiation"
```

### Task 4: `confirm-and-pay` Endpoint

**Files:**
- Modify: `backend/app/task_chat_routes.py`

- [ ] **Step 1: Add `confirm-and-pay` endpoint**

This reuses the PaymentIntent creation logic from the existing `accept_application` (lines 1672-1736) but with the new flow. **Use async SQLAlchemy and model the code closely on `accept_application`** — copy its Stripe customer/ephemeral key helper, `SELECT FOR UPDATE` pattern, and error handling style.

```python
@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/confirm-and-pay")
async def confirm_and_pay(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """Poster confirms applicant selection and initiates payment.
    Closely follows accept_application() at line 1422 for Stripe logic."""
    from sqlalchemy import select, update

    try:
        # Lock task (SELECT FOR UPDATE) — same pattern as accept_application line 1502
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id).with_for_update()
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")

        if task.poster_id != current_user.id:
            raise HTTPException(status_code=403, detail="Only task poster can confirm and pay")

        if task.status != "chatting":
            raise HTTPException(status_code=400, detail="Task is not in chatting status")

        if task.is_paid:
            raise HTTPException(status_code=400, detail="Task is already paid")

        # Lock application
        app_result = await db.execute(
            select(models.TaskApplication).where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            ).with_for_update()
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        if application.status != "chatting":
            raise HTTPException(status_code=400, detail="Application is not in chatting status")

        # Determine final price (negotiated or original reward)
        final_price = application.negotiated_price or task.reward
        if not final_price or final_price <= 0:
            raise HTTPException(status_code=400, detail="No valid price set")

        # === Copy Stripe validation & PaymentIntent logic from accept_application ===
        # Lines 1622-1736 of accept_application:
        # - Validate applicant's Stripe Connect account
        # - Calculate amount in pence via fee_calculator
        # - Create/reuse PaymentIntent with metadata including application_id
        # - Create customer & ephemeral key via _create_customer_and_ephemeral_key helper
        # - Save payment_intent_id to task
        #
        # The only difference: use `final_price` instead of `task.reward` for the amount.
        # Copy the exact code from accept_application and change the amount source.

        # (Implementation: copy lines 1622-1792 from accept_application,
        #  replace `task.reward` with `final_price` for amount calculation)

        await db.commit()

        # Return same response format as accept_application (line 1766-1792)
        # { client_secret, payment_intent_id, amount, currency,
        #   customer_id, ephemeral_key_secret, applicant_name, ... }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
```

**Key implementation note:** Do NOT rewrite the Stripe logic from scratch. Copy lines 1622-1792 from `accept_application` and make these changes:
1. Use `final_price` (from `application.negotiated_price or task.reward`) instead of `task.reward`
2. Keep all the same Stripe customer creation, ephemeral key, error handling
3. Keep the same response format so Flutter's existing `AcceptPaymentData` parsing works

- [ ] **Step 2: Update Stripe webhook handler to auto-reject other applicants**

In the existing webhook handler (where `payment_intent.succeeded` is processed), add logic after setting task to `in_progress`. Use async SQLAlchemy:

```python
# After task status = "in_progress" and application status = "approved":

# Auto-reject all other applications
other_apps_result = await db.execute(
    select(models.TaskApplication).where(
        models.TaskApplication.task_id == task_id,
        models.TaskApplication.id != application_id,
        models.TaskApplication.status.in_(["chatting", "pending"])
    )
)
other_apps = other_apps_result.scalars().all()

for other_app in other_apps:
    was_chatting = other_app.status == "chatting"
    await db.execute(
        update(models.TaskApplication)
        .where(models.TaskApplication.id == other_app.id)
        .values(status="rejected")
    )
    if was_chatting:
        reject_msg = models.Message(
            task_id=task_id,
            application_id=other_app.id,
            content="The poster has selected another applicant for this task.",
            message_type="system",
            conversation_type="task"
        )
        db.add(reject_msg)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: add confirm-and-pay endpoint with auto-reject logic"
```

### Task 5: Modify Existing Message Endpoints for `application_id` Scoping

**Files:**
- Modify: `backend/app/task_chat_routes.py:519-849` (get_task_messages)
- Modify: `backend/app/task_chat_routes.py:850-1156` (send_task_message)
- Modify: `backend/app/task_chat_routes.py:1157-1421` (mark_messages_read)

- [ ] **Step 1: Update `get_task_messages` to accept `application_id` query param**

Add `application_id: Optional[int] = None` parameter. When provided, filter messages by `application_id`:

```python
# Add to query filters (around line 600-650 area):
if application_id is not None:
    query = query.filter(models.Message.application_id == application_id)
    # Permission check: must be poster or this application's applicant
    app = db.query(models.TaskApplication).filter(
        models.TaskApplication.id == application_id,
        models.TaskApplication.task_id == task_id
    ).first()
    if not app or current_user.id not in (task.poster_id, app.applicant_id):
        raise HTTPException(status_code=403, detail="Not authorized to view this chat")
```

- [ ] **Step 2: Update `send_task_message` to accept `application_id`**

Add `application_id: Optional[int] = None` to request body. When provided:
- Validate application exists and is in `chatting` status
- Validate sender is poster or applicant
- Set `application_id` on created Message
- Set `receiver_id` to the other party

- [ ] **Step 3: Update `mark_messages_read` for application-scoped cursors**

When `application_id` is provided, look up/create `MessageReadCursor` with `(task_id, user_id, application_id)` instead of `(task_id, user_id)`.

- [ ] **Step 4: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: scope task messages by application_id for per-applicant chat"
```

### Task 6: Update Application List Endpoint

**Files:**
- Modify: `backend/app/task_chat_routes.py` or `backend/app/routers.py` (wherever `GET /tasks/{id}/applications` is)

- [ ] **Step 1: Add unread message count per application**

For each application in the response, include `unread_count` — the number of messages with `application_id = app.id` that are newer than the poster's read cursor for that application.

- [ ] **Step 2: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: include unread count in application list response"
```

### Task 7: Handle `chatting` → `open` Fallback

**Files:**
- Modify: `backend/app/task_chat_routes.py` (reject and withdraw endpoints)

- [ ] **Step 1: Add fallback check to `reject_application` (~line 1806)**

After setting application status to `rejected`, check if any `chatting` or `pending` applications remain:

```python
# After application.status = "rejected"
remaining = db.query(models.TaskApplication).filter(
    models.TaskApplication.task_id == task_id,
    models.TaskApplication.status.in_(["chatting", "pending"])
).count()
if remaining == 0 and task.status == "chatting":
    task.status = "open"
```

- [ ] **Step 2: Add same fallback check to `withdraw_application` (~line 1930)**

Same logic as above.

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "feat: revert task to open when all applications rejected/withdrawn"
```

---

## Chunk 3: Flutter — Models, Constants & Repository

### Task 8: Update Flutter Constants

**Files:**
- Modify: `link2ur/lib/core/constants/app_constants.dart:28-37`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart:96-118`

- [ ] **Step 1: Add `chatting` task status constant**

In `app_constants.dart` after line 37 (`taskStatusPendingAcceptance`):

```dart
static const String taskStatusChatting = 'chatting';
```

- [ ] **Step 2: Add application status constants**

```dart
static const String applicationStatusPending = 'pending';
static const String applicationStatusChatting = 'chatting';
static const String applicationStatusApproved = 'approved';
static const String applicationStatusRejected = 'rejected';
```

- [ ] **Step 3: Add new API endpoints**

In `api_endpoints.dart`, add:

```dart
static String startApplicationChat(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/start-chat';
static String proposePrice(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/propose-price';
static String confirmAndPay(int taskId, int applicationId) =>
    '/api/tasks/$taskId/applications/$applicationId/confirm-and-pay';
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/core/constants/
git commit -m "feat: add chatting status constants and new API endpoints"
```

### Task 9: Update Flutter Models

**Files:**
- Modify: `link2ur/lib/data/models/task.dart:213-217` (canApply getter)
- Modify: `link2ur/lib/data/models/task_application.dart:31-33` (status getters)

- [ ] **Step 1: Update `canApply` getter (task.dart:213)**

Change from:
```dart
bool get canApply =>
    status == AppConstants.taskStatusOpen &&
    !hasApplied &&
    !isExpired &&
    currentParticipants < maxParticipants;
```

To:
```dart
bool get canApply =>
    (status == AppConstants.taskStatusOpen || status == AppConstants.taskStatusChatting) &&
    !hasApplied &&
    !isExpired &&
    currentParticipants < maxParticipants;
```

- [ ] **Step 2: Add `isChatting` getter to TaskApplication (task_application.dart:31-33)**

Add after existing status getters:

```dart
bool get isChatting => status == 'chatting';
```

- [ ] **Step 3: Commit**

```bash
cd link2ur && git add lib/data/models/
git commit -m "feat: update models for chatting status support"
```

### Task 10: Update TaskRepository

**Files:**
- Modify: `link2ur/lib/data/repositories/task_repository.dart`

- [ ] **Step 1: Add `startApplicationChat` method**

Add after `acceptApplication` method (~line 366):

```dart
Future<Map<String, dynamic>?> startApplicationChat(int taskId, int applicationId) async {
  final response = await _apiService.post(
    ApiEndpoints.startApplicationChat(taskId, applicationId),
  );
  if (response.isSuccess) {
    invalidateTaskCache(taskId);
    return response.data;
  }
  throw Exception(response.message ?? 'Failed to start chat');
}
```

- [ ] **Step 2: Add `proposePrice` method**

```dart
Future<Map<String, dynamic>?> proposePrice(int taskId, int applicationId, double price) async {
  final response = await _apiService.post(
    ApiEndpoints.proposePrice(taskId, applicationId),
    data: {'proposedPrice': price},
  );
  if (response.isSuccess) {
    return response.data;
  }
  throw Exception(response.message ?? 'Failed to propose price');
}
```

- [ ] **Step 3: Add `confirmAndPay` method**

```dart
Future<Map<String, dynamic>?> confirmAndPay(int taskId, int applicationId) async {
  final response = await _apiService.post(
    ApiEndpoints.confirmAndPay(taskId, applicationId),
  );
  if (response.isSuccess) {
    invalidateTaskCache(taskId);
    return response.data;
  }
  throw Exception(response.message ?? 'Failed to initiate payment');
}
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/data/repositories/task_repository.dart
git commit -m "feat: add repository methods for chat-before-payment flow"
```

---

## Chunk 4: Flutter — BLoC Changes

### Task 11: Update TaskDetailBloc Events

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

- [ ] **Step 1: Add new events (after `TaskDetailRejectApplicant` ~line 87)**

```dart
class TaskDetailStartChat extends TaskDetailEvent {
  const TaskDetailStartChat(this.applicationId);
  final int applicationId;
  @override
  List<Object> get props => [applicationId];
}

class TaskDetailProposePrice extends TaskDetailEvent {
  const TaskDetailProposePrice(this.applicationId, this.price);
  final int applicationId;
  final double price;
  @override
  List<Object> get props => [applicationId, price];
}

class TaskDetailConfirmAndPay extends TaskDetailEvent {
  const TaskDetailConfirmAndPay(this.applicationId);
  final int applicationId;
  @override
  List<Object> get props => [applicationId];
}
```

- [ ] **Step 2: Register event handlers in bloc constructor**

```dart
on<TaskDetailStartChat>(_onStartChat);
on<TaskDetailProposePrice>(_onProposePrice);
on<TaskDetailConfirmAndPay>(_onConfirmAndPay);
```

- [ ] **Step 3: Implement `_onStartChat` handler**

```dart
Future<void> _onStartChat(
  TaskDetailStartChat event,
  Emitter<TaskDetailState> emit,
) async {
  emit(state.copyWith(isSubmitting: true));
  try {
    await _taskRepository.startApplicationChat(_taskId!, event.applicationId);
    // Refresh applications list
    final apps = await _taskRepository.getTaskApplications(_taskId!);
    final task = await _taskRepository.getTaskDetail(_taskId!);
    emit(state.copyWith(
      isSubmitting: false,
      applications: apps,
      task: task,
      actionMessage: 'chat_started',
    ));
  } catch (e) {
    emit(state.copyWith(
      isSubmitting: false,
      errorMessage: e.toString(),
    ));
  }
}
```

- [ ] **Step 4: Implement `_onConfirmAndPay` handler**

```dart
Future<void> _onConfirmAndPay(
  TaskDetailConfirmAndPay event,
  Emitter<TaskDetailState> emit,
) async {
  emit(state.copyWith(isSubmitting: true));
  try {
    final result = await _taskRepository.confirmAndPay(_taskId!, event.applicationId);
    if (result != null && result.containsKey('client_secret')) {
      // Payment needed — pass payment data to UI
      final paymentData = AcceptPaymentData(
        clientSecret: result['client_secret'],
        customerId: result['customer_id'],
        ephemeralKeySecret: result['ephemeral_key_secret'],
        amountDisplay: '£${(result['amount'] / 100).toStringAsFixed(2)}',
        taskId: _taskId!,
        applicationId: event.applicationId,
        taskTitle: state.task?.title ?? '',
        applicantName: result['applicant_name'] ?? '',
      );
      emit(state.copyWith(
        isSubmitting: false,
        acceptPaymentData: paymentData,
        actionMessage: 'open_payment',
      ));
    }
  } catch (e) {
    emit(state.copyWith(
      isSubmitting: false,
      errorMessage: e.toString(),
    ));
  }
}
```

- [ ] **Step 5: Implement `_onProposePrice` handler**

```dart
Future<void> _onProposePrice(
  TaskDetailProposePrice event,
  Emitter<TaskDetailState> emit,
) async {
  try {
    await _taskRepository.proposePrice(_taskId!, event.applicationId, event.price);
    // Refresh applications to get updated negotiatedPrice
    final apps = await _taskRepository.getTaskApplications(_taskId!);
    emit(state.copyWith(
      applications: apps,
      actionMessage: 'price_proposed',
    ));
  } catch (e) {
    emit(state.copyWith(errorMessage: e.toString()));
  }
}
```

- [ ] **Step 6: Commit**

```bash
cd link2ur && git add lib/features/tasks/bloc/
git commit -m "feat: add BLoC events and handlers for chat-before-payment flow"
```

---

## Chunk 5: Flutter — UI Changes

### Task 12: Update Application List Buttons

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_components.dart:820-848`

- [ ] **Step 1: Change "Accept" button to "Agree to Chat" for pending applications**

In `_ApplicationItem` widget (line 820-848), replace the accept button logic:

Change the accept button (lines 825-833) from dispatching `TaskDetailAcceptApplicant` to `TaskDetailStartChat`:

```dart
// For pending applications: "Agree to Chat" button
if (application.isPending) ...[
  _ActionCircleButton(
    icon: Icons.chat_bubble_outline,
    color: Colors.blue,
    onTap: () {
      context.read<TaskDetailBloc>().add(
        TaskDetailStartChat(application.id),
      );
    },
  ),
],
// For chatting applications: show "Open Chat" link
if (application.isChatting) ...[
  _ActionCircleButton(
    icon: Icons.chat,
    color: Colors.green,
    onTap: () {
      // Navigate to application chat view
      // (will be implemented in Task 13)
    },
  ),
],
```

- [ ] **Step 2: Add visual indicator for `chatting` status**

Update the status color mapping (lines 677-682) to include chatting:

```dart
'chatting': Colors.blue,
```

- [ ] **Step 3: Show application list for `chatting` status too**

In `task_detail_view.dart` (~line 563-572), the applications list is only shown when `task.status == 'open'`. Update condition:

```dart
if (isPoster && (task.status == 'open' || task.status == 'chatting'))
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/features/tasks/views/
git commit -m "feat: update application list UI with chat-before-payment buttons"
```

### Task 13: Create Application Chat View

**Files:**
- Create: `link2ur/lib/features/tasks/views/application_chat_view.dart`

- [ ] **Step 1: Create the application chat view**

This is a new page with:
- Header showing applicant info and current negotiated price
- Message list (filtered by `application_id`)
- Message input bar
- "Modify Quote" floating action button
- "Confirm & Pay" button (poster only)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../data/models/task_application.dart';
import '../bloc/task_detail_bloc.dart';

class ApplicationChatView extends StatefulWidget {
  const ApplicationChatView({
    super.key,
    required this.taskId,
    required this.applicationId,
    required this.isPoster,
  });

  final int taskId;
  final int applicationId;
  final bool isPoster;

  @override
  State<ApplicationChatView> createState() => _ApplicationChatViewState();
}

class _ApplicationChatViewState extends State<ApplicationChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showPriceProposalDialog() {
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.modifyQuote),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '£',
            hintText: '0.00',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final price = double.tryParse(priceController.text);
              if (price != null && price > 0) {
                context.read<TaskDetailBloc>().add(
                  TaskDetailProposePrice(widget.applicationId, price),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.taskChat),
      ),
      body: Column(
        children: [
          // Price bar
          _PriceBar(
            applicationId: widget.applicationId,
            onModifyPrice: _showPriceProposalDialog,
          ),
          // Message list
          Expanded(
            child: _MessageList(
              taskId: widget.taskId,
              applicationId: widget.applicationId,
              scrollController: _scrollController,
            ),
          ),
          // Input bar
          _MessageInputBar(
            controller: _messageController,
            onSend: () {
              // Send message via existing task message endpoint with application_id
              final text = _messageController.text.trim();
              if (text.isNotEmpty) {
                // TODO: dispatch send message event
                _messageController.clear();
              }
            },
          ),
          // Confirm & Pay button (poster only)
          if (widget.isPoster)
            _ConfirmPayButton(
              onPressed: () {
                context.read<TaskDetailBloc>().add(
                  TaskDetailConfirmAndPay(widget.applicationId),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PriceBar extends StatelessWidget {
  const _PriceBar({required this.applicationId, required this.onModifyPrice});
  final int applicationId;
  final VoidCallback onModifyPrice;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskDetailBloc, TaskDetailState>(
      buildWhen: (p, c) => p.applications != c.applications,
      builder: (context, state) {
        // state.applications is List<TaskApplication>
        final app = state.applications.cast<TaskApplication?>().firstWhere(
          (a) => a?.id == applicationId,
          orElse: () => null,
        );
        final price = app?.proposedPrice;
        final priceText = price != null ? '£${price.toStringAsFixed(2)}' : 'TBD';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text('${context.l10n.currentPrice}: $priceText',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: onModifyPrice,
                icon: const Icon(Icons.edit, size: 16),
                label: Text(context.l10n.modifyQuote),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfirmPayButton extends StatelessWidget {
  const _ConfirmPayButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.payment),
            label: Text(context.l10n.confirmAndPay),
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.taskId,
    required this.applicationId,
    required this.scrollController,
  });
  final int taskId;
  final int applicationId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // TODO: Full implementation — load messages from
    // GET /api/messages/task/{taskId}?application_id={applicationId}
    // Reuse existing task chat message rendering widgets.
    // This is a placeholder — implement as a separate sub-task during execution.
    return const Center(child: CircularProgressIndicator());
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: context.l10n.typeMessage,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add route in app_router.dart**

Add a route for the application chat view:

```dart
GoRoute(
  path: '/tasks/:taskId/applications/:applicationId/chat',
  builder: (context, state) {
    final taskId = int.parse(state.pathParameters['taskId']!);
    final applicationId = int.parse(state.pathParameters['applicationId']!);
    // Derive isPoster from current user, not URL params (security)
    final userId = context.read<AuthBloc>().state.user?.id;
    final task = context.read<TaskDetailBloc>().state.task;
    final isPoster = userId != null && task?.posterId == userId;
    return ApplicationChatView(
      taskId: taskId,
      applicationId: applicationId,
      isPoster: isPoster,
    );
  },
),
```

- [ ] **Step 3: Wire up navigation from application list**

In `task_detail_components.dart`, update the chatting application's "Open Chat" button to navigate:

```dart
onTap: () {
  context.push(
    '/tasks/${task.id}/applications/${application.id}/chat',
  );
},
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/features/tasks/views/application_chat_view.dart lib/core/router/
git commit -m "feat: add application chat view with price negotiation and payment trigger"
```

### Task 14: Add Localization Keys

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add new l10n keys to all three ARB files**

English (`app_en.arb`):
```json
"agreeToChat": "Agree to Chat",
"modifyQuote": "Modify Quote",
"confirmAndPay": "Confirm & Pay",
"chatStarted": "Chat channel opened",
"priceProposed": "New price proposed",
"applicationChatting": "Chatting",
"posterSelectedAnother": "The poster has selected another applicant",
"taskChat": "Task Chat",
"currentPrice": "Current price: £{price}",
"typeMessage": "Type a message..."
```

Simplified Chinese (`app_zh.arb`):
```json
"agreeToChat": "同意沟通",
"modifyQuote": "修改报价",
"confirmAndPay": "确认并付款",
"chatStarted": "聊天通道已开启",
"priceProposed": "已提出新报价",
"applicationChatting": "沟通中",
"posterSelectedAnother": "发布者已选择了其他申请者",
"taskChat": "任务聊天",
"currentPrice": "当前价格: £{price}",
"typeMessage": "输入消息..."
```

Traditional Chinese (`app_zh_Hant.arb`):
```json
"agreeToChat": "同意溝通",
"modifyQuote": "修改報價",
"confirmAndPay": "確認並付款",
"chatStarted": "聊天通道已開啟",
"priceProposed": "已提出新報價",
"applicationChatting": "溝通中",
"posterSelectedAnother": "發佈者已選擇了其他申請者",
"taskChat": "任務聊天",
"currentPrice": "當前價格: £{price}",
"typeMessage": "輸入訊息..."
```

- [ ] **Step 2: Add error codes to error localizer**

In `core/utils/error_localizer.dart`, add cases for new error codes.

- [ ] **Step 3: Generate l10n files**

```bash
cd link2ur && flutter gen-l10n
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/l10n/ lib/core/utils/error_localizer.dart
git commit -m "feat: add localization keys for chat-before-payment flow"
```

### Task 14.5: Messages Tab Integration

**Files:**
- Modify: `link2ur/lib/features/chat/` (or wherever the messages tab list is)
- Modify: `backend/app/task_chat_routes.py:101-421` (get_task_chat_list)

- [ ] **Step 1: Update backend chat list to include application chats**

In `get_task_chat_list` (~line 101), ensure application-scoped chats appear as separate entries. Each `chatting` application should show as a distinct chat item with the applicant's name and last message.

- [ ] **Step 2: Update Flutter messages tab**

In the messages list view, distinguish application chats from regular task chats:
- Show a badge or subtitle indicating "Task Application Chat"
- Tapping opens `ApplicationChatView` instead of regular chat
- Show unread count per application channel

- [ ] **Step 3: Commit**

```bash
cd link2ur && git add lib/features/chat/
git commit -m "feat: show application chats in messages tab"
```

**Note on task ordering:** Task 14 (localization) should be completed before Task 13 (application chat view) since the view uses `context.l10n.*` keys. During execution, implement in order: 14 → 13 → 14.5.

---

## Chunk 6: Integration & Testing

### Task 15: Update Existing Accept Flow for Backward Compatibility

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_components.dart`
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

- [ ] **Step 1: Keep old accept handler for multi-participant tasks**

In `_ApplicationItem`, check if task is multi-participant. If so, keep old "Accept" button behavior:

```dart
if (task.isMultiParticipant) {
  // Old flow: direct accept + payment
  _ActionCircleButton(
    icon: Icons.check,
    color: Colors.green,
    onTap: () => context.read<TaskDetailBloc>().add(
      TaskDetailAcceptApplicant(application.id),
    ),
  ),
} else {
  // New flow: agree to chat
  // ... (already implemented in Task 12)
}
```

- [ ] **Step 2: Commit**

```bash
cd link2ur && git add lib/features/tasks/
git commit -m "feat: preserve old accept flow for multi-participant tasks"
```

### Task 16: End-to-End Testing

- [ ] **Step 1: Test the full new flow manually**

1. Create a new single-participant task
2. Apply from another account
3. As poster, click "Agree to Chat" — verify application status becomes `chatting`
4. Send messages in the chat channel — verify messages are scoped to this application
5. Propose a new price — verify `negotiatedPrice` updates
6. Click "Confirm & Pay" — verify Stripe payment sheet opens with correct amount
7. Complete payment — verify task becomes `in_progress` and other applicants are auto-rejected
8. Verify rejected applicants' chat channels are read-only

- [ ] **Step 2: Test backward compatibility**

1. Verify existing tasks in `pending_acceptance`/`pending_payment` still work
2. Verify multi-participant tasks still use old accept flow
3. Verify old app version doesn't crash on `chatting` status

- [ ] **Step 3: Test edge cases**

1. Applicant withdraws during chatting — verify task falls back to `open` if no other applicants
2. Poster rejects all chatting applicants — verify task falls back to `open`
3. Stripe payment fails — verify application stays `chatting`, can retry
4. New applications come in while task is `chatting` — verify they appear as `pending`

- [ ] **Step 4: Final commit**

```bash
git add backend/app/ link2ur/lib/
git commit -m "feat: complete chat-before-payment task flow implementation"
```
