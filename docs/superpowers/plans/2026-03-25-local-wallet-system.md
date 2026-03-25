# Local Wallet System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a platform-managed wallet balance system so users can earn money before setting up a Stripe Connect payout account, with support for wallet-based payments.

**Architecture:** New `WalletAccount` + `WalletTransaction` tables in the backend database track user cash balances. Task completion credits the local wallet instead of calling `stripe.Transfer`. Withdrawal triggers a two-phase Stripe Transfer. Task payments support mixed mode (wallet + Stripe). Flutter frontend switches balance display from Stripe Connect API to local wallet API.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/BLoC (frontend), PostgreSQL, Stripe API

**Spec:** `docs/superpowers/specs/2026-03-25-local-wallet-system-design.md`

---

## File Structure

### Backend — New Files
| File | Responsibility |
|------|---------------|
| `backend/app/wallet_models.py` | WalletAccount + WalletTransaction SQLAlchemy models |
| `backend/app/wallet_service.py` | Core wallet operations: credit, debit, withdraw (all with FOR UPDATE locking + idempotency) |
| `backend/app/wallet_routes.py` | FastAPI router: GET /balance, GET /transactions, POST /withdraw |
| `backend/app/wallet_schemas.py` | Pydantic schemas for wallet API request/response |
| `backend/migrations/add_wallet_tables.py` | Alembic migration for new tables |

### Backend — Modified Files
| File | Changes |
|------|---------|
| `backend/app/main.py` | Register wallet_routes router |
| `backend/app/routers.py:3840-4410` | `confirm_completion`: replace stripe.Transfer with wallet credit |
| `backend/app/routers.py:4169-4177` | Task accept: remove Connect account check |
| `backend/app/coupon_points_routes.py:62-66` | `total_payment_income`: read from WalletAccount.total_earned |
| `backend/app/coupon_points_routes.py:496+` | Task payment: add `use_wallet_balance` support |
| `backend/app/models.py` | Import wallet models (keep models discoverable) |

### Flutter — Modified Files
| File | Changes |
|------|---------|
| `link2ur/lib/core/constants/api_endpoints.dart` | Add wallet endpoint constants |
| `link2ur/lib/data/models/payment.dart` | Add WalletBalance + WalletTransaction models |
| `link2ur/lib/data/repositories/payment_repository.dart` | Add getWalletBalance(), getWalletTransactions(), requestWithdrawal() |
| `link2ur/lib/features/wallet/bloc/wallet_bloc.dart` | Load wallet balance from local API instead of Stripe Connect |
| `link2ur/lib/features/wallet/views/wallet_view.dart` | Display balance from local wallet data |
| `link2ur/lib/features/payment/views/stripe_connect_payouts_view.dart` | Use wallet balance for withdrawals |
| `link2ur/lib/features/tasks/views/task_detail_view.dart:143-156` | Remove stripe_setup_required check |
| `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart:753-759` | Remove stripe_setup_required error handling |
| `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart:206-219` | Remove stripe_setup_required check |
| `link2ur/lib/features/flea_market/bloc/flea_market_bloc.dart:604-608` | Remove stripe_setup_required error handling |

---

## Task 1: Backend — Wallet Models & Migration

**Files:**
- Create: `backend/app/wallet_models.py`
- Create: `backend/migrations/add_wallet_tables.py`
- Modify: `backend/app/models.py` (add import)

- [ ] **Step 1: Create WalletAccount and WalletTransaction models**

Create `backend/app/wallet_models.py`:

```python
from sqlalchemy import (
    Column, BigInteger, String, DECIMAL, DateTime, Text, Index,
    CheckConstraint, func
)
from sqlalchemy.orm import relationship
from app.database import Base


class WalletAccount(Base):
    __tablename__ = "wallet_accounts"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(8), nullable=False, unique=True, index=True)
    balance = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_earned = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_withdrawn = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_spent = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    currency = Column(String(3), nullable=False, default="GBP")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        CheckConstraint("balance >= 0", name="ck_wallet_balance_non_negative"),
    )


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(8), nullable=False, index=True)
    type = Column(String(20), nullable=False)           # earning, withdrawal, payment
    amount = Column(DECIMAL(12, 2), nullable=False)     # positive=income, negative=expense
    balance_after = Column(DECIMAL(12, 2), nullable=False)
    status = Column(String(20), nullable=False, default="completed")  # completed, pending, failed, reversed
    source = Column(String(50), nullable=False)         # task_reward, flea_market_sale, stripe_transfer, task_payment
    related_id = Column(String(255), nullable=True)
    related_type = Column(String(50), nullable=True)    # task, flea_market_item, payout
    description = Column(Text, nullable=True)
    fee_amount = Column(DECIMAL(12, 2), nullable=True)
    gross_amount = Column(DECIMAL(12, 2), nullable=True)
    idempotency_key = Column(String(64), nullable=False, unique=True)
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index("idx_wallet_tx_type", "type"),
        Index("idx_wallet_tx_status", "status"),
        Index("idx_wallet_tx_created_at", "created_at"),
        Index("idx_wallet_tx_related", "related_type", "related_id"),
    )
```

- [ ] **Step 2: Add import to models.py**

Add at the end of `backend/app/models.py`:

```python
from app.wallet_models import WalletAccount, WalletTransaction  # noqa: F401, E402
```

This ensures Alembic discovers the new models.

- [ ] **Step 3: Create migration script**

Create `backend/migrations/add_wallet_tables.py` (or run `alembic revision --autogenerate -m "add wallet tables"`). The migration should create both tables with all indexes and the CHECK constraint.

- [ ] **Step 4: Run migration**

```bash
cd backend && alembic upgrade head
```

Verify tables exist: `SELECT * FROM wallet_accounts LIMIT 1;` and `SELECT * FROM wallet_transactions LIMIT 1;`

- [ ] **Step 5: Commit**

```bash
git add backend/app/wallet_models.py backend/app/models.py backend/migrations/
git commit -m "feat(wallet): add WalletAccount and WalletTransaction models"
```

---

## Task 2: Backend — Wallet Service (Core Operations)

**Files:**
- Create: `backend/app/wallet_service.py`

- [ ] **Step 1: Create wallet service with get_or_create_account**

```python
from decimal import Decimal
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.wallet_models import WalletAccount, WalletTransaction
from app.utils import get_utc_time
import logging

logger = logging.getLogger(__name__)


def get_or_create_wallet(db: Session, user_id: str) -> WalletAccount:
    """Get or create a wallet account for user. Does NOT lock — caller must lock if mutating."""
    account = db.query(WalletAccount).filter(WalletAccount.user_id == user_id).first()
    if not account:
        account = WalletAccount(user_id=user_id)
        db.add(account)
        db.flush()
    return account


def lock_wallet(db: Session, user_id: str) -> WalletAccount:
    """Lock wallet row with FOR UPDATE. Creates if not exists."""
    account = db.query(WalletAccount).filter(
        WalletAccount.user_id == user_id
    ).with_for_update().first()
    if not account:
        account = WalletAccount(user_id=user_id)
        db.add(account)
        db.flush()
        # Re-lock the newly created row
        account = db.query(WalletAccount).filter(
            WalletAccount.user_id == user_id
        ).with_for_update().first()
    return account
```

- [ ] **Step 2: Add credit_wallet function (for earnings)**

```python
def credit_wallet(
    db: Session,
    user_id: str,
    amount: Decimal,
    source: str,
    related_id: str,
    related_type: str,
    description: str = "",
    fee_amount: Decimal | None = None,
    gross_amount: Decimal | None = None,
    idempotency_key: str | None = None,
) -> WalletTransaction | None:
    """Credit user's wallet. Returns None if idempotency_key already exists."""
    if amount <= 0:
        raise ValueError("Credit amount must be positive")

    if idempotency_key is None:
        idempotency_key = f"earning:{related_type}:{related_id}:user:{user_id}"

    # Idempotency check
    existing = db.query(WalletTransaction).filter(
        WalletTransaction.idempotency_key == idempotency_key
    ).first()
    if existing:
        logger.info(f"Idempotent skip: {idempotency_key}")
        return None

    account = lock_wallet(db, user_id)
    account.balance += amount
    account.total_earned += amount
    account.updated_at = get_utc_time()

    tx = WalletTransaction(
        user_id=user_id,
        type="earning",
        amount=amount,
        balance_after=account.balance,
        status="completed",
        source=source,
        related_id=str(related_id),
        related_type=related_type,
        description=description,
        fee_amount=fee_amount,
        gross_amount=gross_amount,
        idempotency_key=idempotency_key,
    )
    db.add(tx)
    return tx
```

- [ ] **Step 3: Add debit_wallet function (for payments)**

```python
def debit_wallet(
    db: Session,
    user_id: str,
    amount: Decimal,
    source: str,
    related_id: str,
    related_type: str,
    description: str = "",
    status: str = "completed",
    idempotency_key: str | None = None,
) -> WalletTransaction:
    """Debit user's wallet. Raises ValueError if insufficient balance."""
    if amount <= 0:
        raise ValueError("Debit amount must be positive")

    if idempotency_key is None:
        idempotency_key = f"payment:{related_type}:{related_id}:user:{user_id}"

    # Idempotency check
    existing = db.query(WalletTransaction).filter(
        WalletTransaction.idempotency_key == idempotency_key
    ).first()
    if existing:
        if existing.status in ("completed", "pending"):
            raise ValueError("Duplicate debit request")
        # If previous attempt failed/reversed, allow retry with new key
        idempotency_key = f"{idempotency_key}:retry:{int(get_utc_time().timestamp())}"

    account = lock_wallet(db, user_id)
    if account.balance < amount:
        raise ValueError(f"Insufficient balance: {account.balance} < {amount}")

    account.balance -= amount
    account.total_spent += amount
    account.updated_at = get_utc_time()

    tx = WalletTransaction(
        user_id=user_id,
        type="payment",
        amount=-amount,
        balance_after=account.balance,
        status=status,
        source=source,
        related_id=str(related_id),
        related_type=related_type,
        description=description,
        idempotency_key=idempotency_key,
    )
    db.add(tx)
    return tx
```

- [ ] **Step 4: Add withdraw function (two-phase)**

```python
def create_pending_withdrawal(
    db: Session,
    user_id: str,
    amount: Decimal,
    request_uuid: str,
) -> WalletTransaction:
    """Phase 1: Deduct balance and create pending withdrawal. Caller must COMMIT."""
    if amount < Decimal("1.00"):
        raise ValueError("Minimum withdrawal amount is £1.00")

    idempotency_key = f"withdrawal:{request_uuid}:user:{user_id}"

    existing = db.query(WalletTransaction).filter(
        WalletTransaction.idempotency_key == idempotency_key
    ).first()
    if existing:
        raise ValueError("Duplicate withdrawal request")

    account = lock_wallet(db, user_id)
    if account.balance < amount:
        raise ValueError(f"Insufficient balance: {account.balance} < {amount}")

    account.balance -= amount
    account.total_withdrawn += amount
    account.updated_at = get_utc_time()

    tx = WalletTransaction(
        user_id=user_id,
        type="withdrawal",
        amount=-amount,
        balance_after=account.balance,
        status="pending",
        source="stripe_transfer",
        description="提现到银行账户",
        idempotency_key=idempotency_key,
    )
    db.add(tx)
    db.flush()
    return tx


def complete_withdrawal(db: Session, tx_id: int, transfer_id: str):
    """Phase 3 (success): Mark withdrawal as completed."""
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == tx_id).first()
    if tx:
        tx.status = "completed"
        tx.related_id = transfer_id
        tx.related_type = "payout"


def fail_withdrawal(db: Session, tx_id: int, user_id: str, amount: Decimal):
    """Phase 3 (failure): Mark withdrawal as failed and refund balance."""
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == tx_id).first()
    if tx:
        tx.status = "failed"

    account = lock_wallet(db, user_id)
    account.balance += amount
    account.total_withdrawn -= amount
    account.updated_at = get_utc_time()
```

- [ ] **Step 5: Add reverse_debit for mixed payment failure**

```python
def reverse_debit(db: Session, tx_id: int, user_id: str, amount: Decimal):
    """Reverse a pending wallet payment (e.g., Stripe payment failed)."""
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == tx_id).first()
    if tx and tx.status == "pending":
        tx.status = "reversed"

        account = lock_wallet(db, user_id)
        account.balance += amount
        account.total_spent -= amount
        account.updated_at = get_utc_time()
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/wallet_service.py
git commit -m "feat(wallet): add wallet service with credit, debit, withdraw operations"
```

---

## Task 3: Backend — Wallet API Routes & Schemas

**Files:**
- Create: `backend/app/wallet_schemas.py`
- Create: `backend/app/wallet_routes.py`
- Modify: `backend/app/main.py` (register router)

- [ ] **Step 1: Create Pydantic schemas**

Create `backend/app/wallet_schemas.py`:

```python
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class WalletBalanceResponse(BaseModel):
    balance: float
    total_earned: float
    total_withdrawn: float
    total_spent: float
    currency: str = "GBP"


class WalletTransactionOut(BaseModel):
    id: int
    type: str
    amount: float
    balance_after: float
    status: str
    source: str
    related_id: Optional[str] = None
    related_type: Optional[str] = None
    description: Optional[str] = None
    fee_amount: Optional[float] = None
    gross_amount: Optional[float] = None
    created_at: datetime

    class Config:
        from_attributes = True


class WalletTransactionsResponse(BaseModel):
    items: List[WalletTransactionOut]
    total: int
    page: int
    page_size: int


class WithdrawRequest(BaseModel):
    amount: float = Field(gt=0, description="Withdrawal amount in GBP")
    request_id: str = Field(min_length=1, max_length=64, description="Client-generated UUID for idempotency")


class WithdrawResponse(BaseModel):
    success: bool
    transfer_id: Optional[str] = None
    amount: float
    balance_after: float
    error: Optional[str] = None
```

- [ ] **Step 2: Create wallet routes — GET /balance**

Create `backend/app/wallet_routes.py`:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from decimal import Decimal
import stripe
import logging

from app.database import get_db
from app.auth import secure_auth
from app.wallet_models import WalletAccount, WalletTransaction
from app.wallet_service import (
    get_or_create_wallet, create_pending_withdrawal,
    complete_withdrawal, fail_withdrawal,
)
from app.wallet_schemas import (
    WalletBalanceResponse, WalletTransactionsResponse,
    WalletTransactionOut, WithdrawRequest, WithdrawResponse,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/wallet", tags=["wallet"])


@router.get("/balance", response_model=WalletBalanceResponse)
def get_wallet_balance(
    db: Session = Depends(get_db),
    current_user=Depends(secure_auth),
):
    account = get_or_create_wallet(db, current_user.id)
    db.commit()
    return WalletBalanceResponse(
        balance=float(account.balance),
        total_earned=float(account.total_earned),
        total_withdrawn=float(account.total_withdrawn),
        total_spent=float(account.total_spent),
        currency=account.currency,
    )
```

- [ ] **Step 3: Add GET /transactions**

```python
@router.get("/transactions", response_model=WalletTransactionsResponse)
def get_wallet_transactions(
    page: int = 1,
    page_size: int = 20,
    type: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(secure_auth),
):
    query = db.query(WalletTransaction).filter(
        WalletTransaction.user_id == current_user.id,
        WalletTransaction.status.in_(["completed", "pending"]),
    )
    if type:
        query = query.filter(WalletTransaction.type == type)

    total = query.count()
    items = (
        query.order_by(WalletTransaction.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return WalletTransactionsResponse(
        items=[WalletTransactionOut.model_validate(item) for item in items],
        total=total,
        page=page,
        page_size=page_size,
    )
```

- [ ] **Step 4: Add POST /withdraw**

```python
@router.post("/withdraw", response_model=WithdrawResponse)
def withdraw_to_connect(
    req: WithdrawRequest,
    db: Session = Depends(get_db),
    current_user=Depends(secure_auth),
):
    # Check Connect account exists
    stripe_account_id = current_user.stripe_account_id
    if not stripe_account_id:
        raise HTTPException(status_code=428, detail="请先设置收款账户")

    amount = Decimal(str(req.amount))

    # Phase 1: Deduct balance, create pending transaction
    try:
        tx = create_pending_withdrawal(db, current_user.id, amount, req.request_id)
        db.commit()
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Phase 2: Stripe Transfer
    try:
        transfer = stripe.Transfer.create(
            amount=int(amount * 100),  # Convert to pence
            currency="gbp",
            destination=stripe_account_id,
            description=f"用户提现 £{amount}",
            metadata={
                "user_id": current_user.id,
                "wallet_tx_id": str(tx.id),
                "type": "wallet_withdrawal",
            },
        )
    except stripe.error.StripeError as e:
        # Phase 3 (failure): Rollback balance
        logger.error(f"Withdrawal Stripe error for user {current_user.id}: {e}")
        fail_withdrawal(db, tx.id, current_user.id, amount)
        db.commit()
        raise HTTPException(status_code=502, detail="提现失败，余额已退回，请稍后重试")

    # Phase 3 (success): Mark completed
    complete_withdrawal(db, tx.id, transfer.id)
    db.commit()

    # Re-read balance after commit
    from app.wallet_service import get_or_create_wallet
    account = get_or_create_wallet(db, current_user.id)

    return WithdrawResponse(
        success=True,
        transfer_id=transfer.id,
        amount=float(amount),
        balance_after=float(account.balance),
    )
```

- [ ] **Step 5: Register router in main.py**

In `backend/app/main.py`, add:

```python
from app.wallet_routes import router as wallet_router
app.include_router(wallet_router)
```

Add this next to the existing router registrations.

- [ ] **Step 6: Commit**

```bash
git add backend/app/wallet_schemas.py backend/app/wallet_routes.py backend/app/main.py
git commit -m "feat(wallet): add wallet API routes (balance, transactions, withdraw)"
```

---

## Task 4: Backend — Modify confirm_completion for Local Wallet Credit

**Files:**
- Modify: `backend/app/routers.py:3840-4410` (confirm_completion endpoint)

- [ ] **Step 1: Read the current confirm_completion code**

Read `backend/app/routers.py` lines 3840-4450 to understand the current transfer logic.

- [ ] **Step 2: Replace stripe.Transfer with wallet credit**

In the `confirm_completion` endpoint, find the section that calls `create_transfer_record()` and `execute_transfer()` (around lines 4261-4410). Replace with:

```python
# --- NEW: Local wallet credit instead of Stripe Transfer ---
from app.wallet_service import credit_wallet
from decimal import Decimal

if task.is_paid == 1 and task.taker_id and task.escrow_amount > 0:
    net_amount = Decimal(str(task.escrow_amount))  # escrow_amount is already net of platform fee
    # Fee tracking: gross = original task payment amount, fee = gross - net
    # (Adjust based on how your fee calculation actually works)

    idempotency_key = f"earning:task:{task.id}:user:{task.taker_id}"

    credit_wallet(
        db=db,
        user_id=task.taker_id,
        amount=net_amount,
        source="task_reward",
        related_id=str(task.id),
        related_type="task",
        description=f"任务 #{task.id} 奖励",
        idempotency_key=idempotency_key,
    )

    # Clear escrow
    task.escrow_amount = Decimal("0.00")
    task.paid_to_user_id = task.taker_id
```

Remove or comment out the old `create_transfer_record()` / `execute_transfer()` calls for NEW tasks. Keep the old code path for transition period (old pending transfers).

- [ ] **Step 3: Handle the flea market sale case**

The flea market sale goes through the same `confirm_completion` logic. Ensure `source` is set based on task metadata:

```python
source = "flea_market_sale" if task.sold_task_id else "task_reward"
```

- [ ] **Step 4: Test manually by reading the code path**

Trace through the modified function to ensure:
- Idempotency key is unique per task+taker
- `escrow_amount` is cleared after credit
- Old pending transfers still processed by `process_pending_transfers()`

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(wallet): credit local wallet on task completion instead of stripe.Transfer"
```

---

## Task 5: Backend — Remove Connect Account Checks for Accept/Publish

**Files:**
- Modify: `backend/app/routers.py:4169-4177` (task accept Connect check)
- Modify: backend flea market publish endpoint (find and remove Connect check)

- [ ] **Step 1: Read task accept endpoint to find Connect check**

Read `backend/app/routers.py` around lines 4169-4177 to find the Connect account validation.

- [ ] **Step 2: Remove or disable Connect check for task acceptance**

Comment out or remove the block that checks `stripe_account_id`, `details_submitted`, and `charges_enabled` before allowing task acceptance. The response should no longer return `stripe_setup_required`.

- [ ] **Step 3: Find and remove Connect check for flea market item publish**

Search for `stripe_setup_required` in flea market related routes and remove the check.

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(wallet): remove Connect account requirement for task accept and flea market publish"
```

---

## Task 6: Backend — Add Wallet Balance Payment Support (Mixed Payment)

**Files:**
- Modify: `backend/app/coupon_points_routes.py:496+` (task payment endpoint)

- [ ] **Step 1: Read the current task payment endpoint**

Read the task payment creation code in `backend/app/coupon_points_routes.py` to understand how PaymentIntent is created.

- [ ] **Step 2: Add use_wallet_balance parameter**

Modify the payment request schema to accept `use_wallet_balance: bool = False`.

- [ ] **Step 3: Implement mixed payment logic**

Before creating PaymentIntent, if `use_wallet_balance=True`:

```python
from app.wallet_service import lock_wallet, debit_wallet
from decimal import Decimal

wallet_deduction = Decimal("0")
wallet_tx_id = None

if use_wallet_balance:
    account = lock_wallet(db, current_user.id)
    total = Decimal(str(total_amount_in_pounds))
    wallet_deduction = min(account.balance, total)
    stripe_amount_pounds = total - wallet_deduction

    if wallet_deduction > 0:
        tx = debit_wallet(
            db=db,
            user_id=current_user.id,
            amount=wallet_deduction,
            source="task_payment",
            related_id=str(task_id),
            related_type="task",
            description=f"任务 #{task_id} 余额支付",
            status="pending",  # Pending until Stripe confirms or full-wallet completes
        )
        wallet_tx_id = tx.id

    if stripe_amount_pounds <= 0:
        # Full wallet payment — no PaymentIntent needed
        tx.status = "completed"
        # Mark task as paid directly
        task.is_paid = 1
        task.status = "pending_confirmation"
        db.commit()
        return {"payment_type": "wallet", "wallet_amount": float(wallet_deduction)}

    # Mixed payment — create PaymentIntent for the remainder
    stripe_amount_pence = int(stripe_amount_pounds * 100)
    # Store wallet_deduction and wallet_tx_id in PaymentIntent metadata
    # so webhook can finalize or reverse the wallet debit
```

- [ ] **Step 4: Modify webhook handler for mixed payment**

In the payment success webhook, if metadata contains `wallet_tx_id`:
- Update WalletTransaction status to `completed`

In the payment failure/expiry webhook:
- Call `reverse_debit(db, wallet_tx_id, user_id, wallet_deduction)`

- [ ] **Step 5: Commit**

```bash
git add backend/app/coupon_points_routes.py
git commit -m "feat(wallet): support wallet balance payment and mixed payment for tasks"
```

---

## Task 7: Backend — Update total_payment_income Query

**Files:**
- Modify: `backend/app/coupon_points_routes.py:62-66`

- [ ] **Step 1: Read current total_payment_income calculation**

Currently queries `PaymentTransfer WHERE status=succeeded`.

- [ ] **Step 2: Replace with WalletAccount.total_earned**

```python
from app.wallet_service import get_or_create_wallet

wallet = get_or_create_wallet(db, current_user.id)
total_payment_income = float(wallet.total_earned)
```

Remove the old `db.query(func.sum(PaymentTransfer.amount))` query.

- [ ] **Step 3: Commit**

```bash
git add backend/app/coupon_points_routes.py
git commit -m "feat(wallet): read total_payment_income from WalletAccount instead of PaymentTransfer"
```

---

## Task 8: Flutter — Add Wallet API Endpoints & Models

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/models/payment.dart`

- [ ] **Step 1: Add wallet endpoint constants**

In `link2ur/lib/core/constants/api_endpoints.dart`, add:

```dart
// Wallet endpoints
static const String walletBalance = '/api/wallet/balance';
static const String walletTransactions = '/api/wallet/transactions';
static const String walletWithdraw = '/api/wallet/withdraw';
```

- [ ] **Step 2: Add WalletBalance model**

In `link2ur/lib/data/models/payment.dart`, add:

```dart
class WalletBalance extends Equatable {
  final double balance;
  final double totalEarned;
  final double totalWithdrawn;
  final double totalSpent;
  final String currency;

  const WalletBalance({
    this.balance = 0.0,
    this.totalEarned = 0.0,
    this.totalWithdrawn = 0.0,
    this.totalSpent = 0.0,
    this.currency = 'GBP',
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawn: (json['total_withdrawn'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'GBP',
    );
  }

  @override
  List<Object?> get props => [balance, totalEarned, totalWithdrawn, totalSpent, currency];
}
```

- [ ] **Step 3: Add WalletTransactionItem model**

```dart
class WalletTransactionItem extends Equatable {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String status;
  final String source;
  final String? relatedId;
  final String? relatedType;
  final String? description;
  final double? feeAmount;
  final double? grossAmount;
  final String createdAt;

  const WalletTransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.status,
    required this.source,
    this.relatedId,
    this.relatedType,
    this.description,
    this.feeAmount,
    this.grossAmount,
    required this.createdAt,
  });

  factory WalletTransactionItem.fromJson(Map<String, dynamic> json) {
    return WalletTransactionItem(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      status: json['status'] as String,
      source: json['source'] as String,
      relatedId: json['related_id'] as String?,
      relatedType: json['related_type'] as String?,
      description: json['description'] as String?,
      feeAmount: (json['fee_amount'] as num?)?.toDouble(),
      grossAmount: (json['gross_amount'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, status, source, createdAt];
}
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/core/constants/api_endpoints.dart lib/data/models/payment.dart
git commit -m "feat(wallet): add wallet API endpoints and Flutter models"
```

---

## Task 9: Flutter — Add Wallet Repository Methods

**Files:**
- Modify: `link2ur/lib/data/repositories/payment_repository.dart`

- [ ] **Step 1: Add getWalletBalance method**

```dart
Future<WalletBalance> getWalletBalance() async {
  final response = await _apiService.get(ApiEndpoints.walletBalance);
  if (response.isSuccess && response.data != null) {
    return WalletBalance.fromJson(response.data);
  }
  throw PaymentException(response.message ?? '获取钱包余额失败');
}
```

- [ ] **Step 2: Add getWalletTransactions method**

```dart
Future<Map<String, dynamic>> getWalletTransactions({
  int page = 1,
  int pageSize = 20,
  String? type,
}) async {
  final params = <String, dynamic>{
    'page': page,
    'page_size': pageSize,
  };
  if (type != null) params['type'] = type;

  final response = await _apiService.get(
    ApiEndpoints.walletTransactions,
    queryParameters: params,
  );
  if (response.isSuccess && response.data != null) {
    final items = (response.data['items'] as List)
        .map((e) => WalletTransactionItem.fromJson(e))
        .toList();
    return {
      'items': items,
      'total': response.data['total'],
      'page': response.data['page'],
      'page_size': response.data['page_size'],
    };
  }
  throw PaymentException(response.message ?? '获取钱包流水失败');
}
```

- [ ] **Step 3: Add requestWithdrawal method**

```dart
Future<Map<String, dynamic>> requestWithdrawal({
  required double amount,
  required String requestId,
}) async {
  final response = await _apiService.post(
    ApiEndpoints.walletWithdraw,
    data: {
      'amount': amount,
      'request_id': requestId,
    },
  );
  if (response.isSuccess && response.data != null) {
    return response.data;
  }
  throw PaymentException(response.message ?? '提现失败');
}
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/data/repositories/payment_repository.dart
git commit -m "feat(wallet): add wallet repository methods (balance, transactions, withdraw)"
```

---

## Task 10: Flutter — Update WalletBloc to Use Local Wallet

**Files:**
- Modify: `link2ur/lib/features/wallet/bloc/wallet_bloc.dart`

- [ ] **Step 1: Read current WalletBloc and WalletState**

Read the file to understand the current state structure and how Stripe Connect balance is loaded.

- [ ] **Step 2: Add walletBalance to WalletState**

Add `WalletBalance? walletBalance` field to WalletState, alongside or replacing the existing `connectBalance`.

- [ ] **Step 3: Update _onLoadRequested to fetch local wallet balance**

Replace the `getStripeConnectBalanceTyped()` call with `getWalletBalance()`:

```dart
// Replace this:
// try {
//   final connectBalance = await paymentRepo.getStripeConnectBalanceTyped();
//   ...
// }

// With this:
try {
  final walletBalance = await paymentRepo.getWalletBalance();
  // Store in state
} catch (e) {
  // Graceful fallback — show 0 balance
}
```

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/features/wallet/bloc/wallet_bloc.dart
git commit -m "feat(wallet): update WalletBloc to load balance from local wallet API"
```

---

## Task 11: Flutter — Update Wallet View to Display Local Balance

**Files:**
- Modify: `link2ur/lib/features/wallet/views/wallet_view.dart`

- [ ] **Step 1: Read current wallet view**

Read the file to find the _PointsCard and balance display sections.

- [ ] **Step 2: Update balance display**

In the `_PointsCard` widget, change the "未提现收入" value from `connectBalance?.available` to `walletBalance?.balance`:

```dart
// Replace Stripe Connect balance with local wallet balance
final walletBalance = state.walletBalance;
final displayBalance = walletBalance?.balance ?? 0.0;
```

Update "累计收入" and "累计消费" similarly to read from `walletBalance.totalEarned` / `walletBalance.totalSpent`.

- [ ] **Step 3: Update Connect status section**

Change the Connect section label from account status to "提现账户设置". Balance should be visible regardless of Connect status.

- [ ] **Step 4: Commit**

```bash
cd link2ur && git add lib/features/wallet/views/wallet_view.dart
git commit -m "feat(wallet): display local wallet balance in wallet page"
```

---

## Task 12: Flutter — Update Payout View for Local Wallet Withdrawal

**Files:**
- Modify: `link2ur/lib/features/payment/views/stripe_connect_payouts_view.dart`

- [ ] **Step 1: Read current payout view**

Understand the current balance loading and payout creation flow.

- [ ] **Step 2: Update balance source**

Replace Stripe Connect balance loading with local wallet balance:

```dart
// Replace _loadAll() balance fetch:
final walletBalance = await _paymentRepo.getWalletBalance();
```

- [ ] **Step 3: Update payout creation to use wallet withdraw API**

In `_createPayout`, replace `requestPayoutInPounds` with `requestWithdrawal`:

```dart
import 'package:uuid/uuid.dart';

Future<void> _createPayout(double amount) async {
  final requestId = const Uuid().v4();
  try {
    final result = await _paymentRepo.requestWithdrawal(
      amount: amount,
      requestId: requestId,
    );
    // Show success, refresh balance
  } catch (e) {
    // Handle 428 (no Connect account) — navigate to onboarding
    // Handle other errors — show error message
  }
}
```

- [ ] **Step 4: Add Connect account check before payout**

Before showing the payout sheet, check Connect status. If not set up, show dialog to navigate to onboarding instead of the payout input.

- [ ] **Step 5: Commit**

```bash
cd link2ur && git add lib/features/payment/views/stripe_connect_payouts_view.dart
git commit -m "feat(wallet): update payout view to withdraw from local wallet"
```

---

## Task 13: Flutter — Remove stripe_setup_required Checks

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:143-156`
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart:753-759`
- Modify: `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart:206-219`
- Modify: `link2ur/lib/features/flea_market/bloc/flea_market_bloc.dart:604-608`

- [ ] **Step 1: Remove stripe_setup_required listener in task_detail_view.dart**

Remove the BlocListener block (lines 143-156) that shows the "Stripe Setup Required" dialog.

- [ ] **Step 2: Remove stripe_setup_required detection in task_detail_bloc.dart**

Remove the code (lines 753-759) that checks exception message for 'stripe_setup_required' and sets actionMessage.

- [ ] **Step 3: Remove stripe_setup_required listener in create_flea_market_item_view.dart**

Remove the listener block (lines 206-219) that intercepts stripe_setup_required.

- [ ] **Step 4: Remove stripe_setup_required detection in flea_market_bloc.dart**

Remove the code (lines 604-608) that checks for 'stripe_setup_required' in exceptions.

- [ ] **Step 5: Commit**

```bash
cd link2ur && git add lib/features/tasks/ lib/features/flea_market/
git commit -m "feat(wallet): remove stripe_setup_required checks from task accept and flea market publish"
```

---

## Task 14: Backend — Data Migration Script

**Files:**
- Create: `backend/scripts/migrate_wallet_history.py`

- [ ] **Step 1: Write migration script**

```python
"""
One-time migration: Create WalletAccount + WalletTransaction records
for existing users based on PaymentTransfer history.

Old users get balance=0 (money is already in their Stripe Connect accounts).
"""
from decimal import Decimal
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models import PaymentTransfer, User
from app.wallet_models import WalletAccount, WalletTransaction
from app.utils import get_utc_time


def migrate():
    db = SessionLocal()
    try:
        # Get all users who have successful transfers as taker
        taker_ids = db.query(PaymentTransfer.taker_id).filter(
            PaymentTransfer.status == "succeeded"
        ).distinct().all()
        taker_ids = [t[0] for t in taker_ids]

        for user_id in taker_ids:
            # Create WalletAccount with balance=0
            existing = db.query(WalletAccount).filter(
                WalletAccount.user_id == user_id
            ).first()
            if existing:
                continue

            # Sum earnings
            transfers = db.query(PaymentTransfer).filter(
                PaymentTransfer.taker_id == user_id,
                PaymentTransfer.status == "succeeded",
            ).all()

            total_earned = Decimal("0")
            for t in transfers:
                amount = Decimal(str(t.amount))
                total_earned += amount

                # Create earning transaction record
                tx = WalletTransaction(
                    user_id=user_id,
                    type="earning",
                    amount=amount,
                    balance_after=Decimal("0"),  # Historical — balance was in Stripe
                    status="completed",
                    source="task_reward",
                    related_id=str(t.task_id),
                    related_type="task",
                    description=f"[历史迁移] 任务 #{t.task_id} 奖励",
                    idempotency_key=f"migration:earning:task:{t.task_id}:user:{user_id}",
                    created_at=t.succeeded_at or t.created_at,
                )
                db.add(tx)

            account = WalletAccount(
                user_id=user_id,
                balance=Decimal("0"),  # Money is in Connect, not platform
                total_earned=total_earned,
                total_withdrawn=total_earned,  # Effectively "withdrawn" to Connect
                currency="GBP",
            )
            db.add(account)
            db.flush()

            print(f"Migrated user {user_id}: {len(transfers)} earning records, total £{total_earned}")

        db.commit()
        print(f"Migration complete: {len(taker_ids)} users processed")
    except Exception as e:
        db.rollback()
        print(f"Migration failed: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    migrate()
```

- [ ] **Step 2: Test with dry run**

Add a `--dry-run` flag that rolls back instead of committing, to verify the script works.

- [ ] **Step 3: Commit**

```bash
git add backend/scripts/migrate_wallet_history.py
git commit -m "feat(wallet): add one-time data migration script for existing users"
```

---

## Task 15: Integration Testing & Verification

- [ ] **Step 1: Test wallet balance API**

```bash
# After deploying backend, test with curl or httpie:
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/wallet/balance
# Expected: {"balance": 0.0, "total_earned": 0.0, ...}
```

- [ ] **Step 2: Test wallet transactions API**

```bash
curl -H "Authorization: Bearer $TOKEN" "http://localhost:8000/api/wallet/transactions?page=1&page_size=5"
# Expected: {"items": [], "total": 0, ...}
```

- [ ] **Step 3: Test task completion credits wallet**

Complete a test task and verify:
- WalletAccount.balance increases
- WalletTransaction record created with type=earning
- No stripe.Transfer is called

- [ ] **Step 4: Test withdrawal flow**

With a Connect account set up:
- POST /api/wallet/withdraw with a valid amount
- Verify balance decreases
- Verify Stripe Transfer is created

Without a Connect account:
- Should return 428

- [ ] **Step 5: Test mixed payment**

Create a task payment with `use_wallet_balance=true`:
- If balance covers full amount → no PaymentIntent created
- If balance is partial → PaymentIntent created for remainder

- [ ] **Step 6: Test task accept without Connect account**

Accept a task without having a Connect account set up:
- Should succeed (no stripe_setup_required error)

- [ ] **Step 7: Verify Flutter wallet page shows correct balance**

Run the Flutter app and check:
- Wallet page shows local balance (not Stripe Connect balance)
- Transaction history shows local wallet transactions

- [ ] **Step 8: Final commit**

```bash
git commit -m "feat(wallet): local wallet system complete"
```
