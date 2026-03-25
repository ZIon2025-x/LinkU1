"""
Wallet Service — core wallet operations module.

All balance-mutating operations follow the lock-first pattern:
  1. lock_wallet() — acquire FOR UPDATE row lock
  2. idempotency check — prevent duplicate processing
  3. business validation — balance check, amount check, etc.
  4. mutation — update wallet + insert transaction

This ordering prevents TOCTOU (time-of-check/time-of-use) race conditions.
"""
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.wallet_models import WalletAccount, WalletTransaction
from app.utils.time_utils import get_utc_time


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _find_transaction(db: Session, idempotency_key: str) -> Optional[WalletTransaction]:
    return (
        db.query(WalletTransaction)
        .filter(WalletTransaction.idempotency_key == idempotency_key)
        .first()
    )


# ---------------------------------------------------------------------------
# 1. get_or_create_wallet
# ---------------------------------------------------------------------------

def get_or_create_wallet(db: Session, user_id: str, currency: str = "GBP") -> WalletAccount:
    """
    Return the WalletAccount for *user_id*, creating one with defaults if it
    does not yet exist.

    Does NOT acquire a row lock — callers that will mutate the wallet must use
    lock_wallet() instead.
    """
    wallet = (
        db.query(WalletAccount)
        .filter(WalletAccount.user_id == user_id, WalletAccount.currency == currency)
        .first()
    )
    if wallet is None:
        wallet = WalletAccount(
            user_id=user_id,
            balance=Decimal("0.00"),
            total_earned=Decimal("0.00"),
            total_withdrawn=Decimal("0.00"),
            total_spent=Decimal("0.00"),
            currency=currency,
        )
        db.add(wallet)
        db.flush()
    return wallet


# ---------------------------------------------------------------------------
# 2. lock_wallet
# ---------------------------------------------------------------------------

def lock_wallet(db: Session, user_id: str, currency: str = "GBP") -> WalletAccount:
    """
    Return the WalletAccount for *user_id* with a FOR UPDATE row lock.

    If the account does not yet exist it is created, flushed (to assign a PK),
    and then re-queried with FOR UPDATE so the lock is properly held.
    """
    wallet = (
        db.query(WalletAccount)
        .filter(WalletAccount.user_id == user_id, WalletAccount.currency == currency)
        .with_for_update()
        .first()
    )
    if wallet is None:
        # Create without a lock first, flush to persist the row …
        wallet = WalletAccount(
            user_id=user_id,
            balance=Decimal("0.00"),
            total_earned=Decimal("0.00"),
            total_withdrawn=Decimal("0.00"),
            total_spent=Decimal("0.00"),
            currency=currency,
        )
        db.add(wallet)
        db.flush()
        # … then re-query with FOR UPDATE to obtain the lock.
        wallet = (
            db.query(WalletAccount)
            .filter(WalletAccount.user_id == user_id, WalletAccount.currency == currency)
            .with_for_update()
            .first()
        )
    return wallet


# ---------------------------------------------------------------------------
# 3. credit_wallet
# ---------------------------------------------------------------------------

def credit_wallet(
    db: Session,
    user_id: str,
    amount: Decimal,
    source: str,
    related_id: Optional[str] = None,
    related_type: Optional[str] = None,
    description: Optional[str] = None,
    fee_amount: Optional[Decimal] = None,
    gross_amount: Optional[Decimal] = None,
    idempotency_key: Optional[str] = None,
    currency: str = "GBP",
) -> Optional[WalletTransaction]:
    """
    Credit *amount* to the wallet of *user_id*.

    Lock-first pattern:
      1. Acquire row lock.
      2. Check idempotency — return None if already processed.
      3. Validate amount > 0.
      4. Update balance + total_earned.
      5. Insert WalletTransaction(type="earning", status="completed").

    Returns the new WalletTransaction, or None if the operation was already
    applied (idempotent skip).
    """
    if idempotency_key is None:
        idempotency_key = f"earning:{related_type}:{related_id}:user:{user_id}"

    # 1. Lock first
    wallet = lock_wallet(db, user_id, currency)

    # 2. Idempotency check (after lock to prevent TOCTOU)
    if _find_transaction(db, idempotency_key) is not None:
        return None

    # 3. Validate
    amount = Decimal(str(amount))
    if amount <= Decimal("0"):
        raise ValueError(f"credit_wallet: amount must be > 0, got {amount}")

    # 4. Mutate wallet
    wallet.balance = wallet.balance + amount
    wallet.total_earned = wallet.total_earned + amount
    wallet.updated_at = get_utc_time()

    # 5. Record transaction
    new_balance = wallet.balance
    tx = WalletTransaction(
        user_id=user_id,
        type="earning",
        amount=amount,
        balance_after=new_balance,
        status="completed",
        source=source,
        related_id=related_id,
        related_type=related_type,
        description=description,
        fee_amount=fee_amount,
        gross_amount=gross_amount,
        currency=currency,
        idempotency_key=idempotency_key,
        created_at=get_utc_time(),
    )
    db.add(tx)
    db.flush()
    return tx


# ---------------------------------------------------------------------------
# 4. debit_wallet
# ---------------------------------------------------------------------------

def debit_wallet(
    db: Session,
    user_id: str,
    amount: Decimal,
    source: str,
    related_id: Optional[str] = None,
    related_type: Optional[str] = None,
    description: Optional[str] = None,
    status: str = "completed",
    idempotency_key: Optional[str] = None,
    currency: str = "GBP",
) -> WalletTransaction:
    """
    Debit *amount* from the wallet of *user_id*.

    Lock-first pattern:
      1. Acquire row lock.
      2. Check idempotency:
         - If a completed/pending transaction exists → raise ValueError (duplicate).
         - If a failed/reversed transaction exists → generate a retry key.
      3. Validate balance >= amount.
      4. Update balance + total_spent.
      5. Insert WalletTransaction(type="payment", amount=-amount).

    Returns the new WalletTransaction.
    """
    if idempotency_key is None:
        idempotency_key = f"payment:{related_type}:{related_id}:user:{user_id}"

    # 1. Lock first
    wallet = lock_wallet(db, user_id, currency)

    # 2. Idempotency check (after lock)
    existing = _find_transaction(db, idempotency_key)
    if existing is not None:
        if existing.status in ("completed", "pending"):
            raise ValueError(
                f"debit_wallet: duplicate operation — transaction {existing.id} "
                f"already exists with status '{existing.status}' "
                f"for idempotency_key='{idempotency_key}'"
            )
        # Previous attempt failed/reversed — generate a fresh retry key
        idempotency_key = f"{idempotency_key}:retry:{get_utc_time().timestamp()}"

    # 3. Validate
    amount = Decimal(str(amount))
    if amount <= Decimal("0"):
        raise ValueError(f"debit_wallet: amount must be > 0, got {amount}")
    if wallet.balance < amount:
        raise ValueError(
            f"debit_wallet: insufficient balance — "
            f"balance={wallet.balance}, requested={amount}"
        )

    # 4. Mutate wallet
    wallet.balance = wallet.balance - amount
    wallet.total_spent = wallet.total_spent + amount
    wallet.updated_at = get_utc_time()

    # 5. Record transaction (stored amount is negative for a debit)
    new_balance = wallet.balance
    tx = WalletTransaction(
        user_id=user_id,
        type="payment",
        amount=-amount,
        balance_after=new_balance,
        status=status,
        source=source,
        related_id=related_id,
        related_type=related_type,
        description=description,
        currency=currency,
        idempotency_key=idempotency_key,
        created_at=get_utc_time(),
    )
    db.add(tx)
    db.flush()
    return tx


# ---------------------------------------------------------------------------
# 5. create_pending_withdrawal
# ---------------------------------------------------------------------------

def create_pending_withdrawal(
    db: Session,
    user_id: str,
    amount: Decimal,
    request_uuid: str,
    currency: str = "GBP",
) -> WalletTransaction:
    """
    Reserve *amount* for a pending withdrawal (Stripe payout).

    Lock-first pattern:
      1. Acquire row lock.
      2. Validate amount >= 1.00 (minimum withdrawal).
      3. Check idempotency — raise if already submitted.
      4. Validate balance >= amount.
      5. Deduct balance, increment total_withdrawn.
      6. Insert WalletTransaction(type="withdrawal", status="pending").

    Returns the new WalletTransaction.
    """
    idempotency_key = f"withdrawal:{request_uuid}:user:{user_id}"

    # 1. Lock first
    wallet = lock_wallet(db, user_id, currency)

    # 2. Minimum withdrawal check
    amount = Decimal(str(amount))
    if amount < Decimal("1.00"):
        raise ValueError(
            f"create_pending_withdrawal: minimum withdrawal is £1.00, got {amount}"
        )

    # 3. Idempotency check (after lock)
    if _find_transaction(db, idempotency_key) is not None:
        raise ValueError(
            f"create_pending_withdrawal: duplicate withdrawal request — "
            f"idempotency_key='{idempotency_key}' already exists"
        )

    # 4. Balance check
    if wallet.balance < amount:
        raise ValueError(
            f"create_pending_withdrawal: insufficient balance — "
            f"balance={wallet.balance}, requested={amount}"
        )

    # 5. Mutate wallet
    wallet.balance = wallet.balance - amount
    wallet.total_withdrawn = wallet.total_withdrawn + amount
    wallet.updated_at = get_utc_time()

    # 6. Record transaction
    new_balance = wallet.balance
    tx = WalletTransaction(
        user_id=user_id,
        type="withdrawal",
        amount=-amount,
        balance_after=new_balance,
        status="pending",
        source="stripe_transfer",
        related_id=None,
        related_type=None,
        description=None,
        currency=currency,
        idempotency_key=idempotency_key,
        created_at=get_utc_time(),
    )
    db.add(tx)
    db.flush()
    return tx


# ---------------------------------------------------------------------------
# 6. complete_withdrawal
# ---------------------------------------------------------------------------

def complete_withdrawal(db: Session, tx_id: int, transfer_id: str) -> None:
    """
    Mark a pending withdrawal transaction as completed and record the Stripe
    transfer ID.
    """
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == tx_id).first()
    if tx is None:
        raise ValueError(f"complete_withdrawal: transaction {tx_id} not found")
    tx.status = "completed"
    tx.related_id = transfer_id
    tx.related_type = "payout"
    db.flush()


# ---------------------------------------------------------------------------
# 7. fail_withdrawal
# ---------------------------------------------------------------------------

def fail_withdrawal(db: Session, tx_id: int, user_id: str, amount: Decimal, currency: str = "GBP") -> None:
    """
    Mark a pending withdrawal as failed and refund the reserved amount back to
    the wallet.

    Lock-first pattern:
      1. Mark transaction as failed.
      2. Acquire row lock on wallet.
      3. Refund balance, decrement total_withdrawn.
    """
    amount = Decimal(str(amount))

    # 1. Update transaction status
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == tx_id).first()
    if tx is None:
        raise ValueError(f"fail_withdrawal: transaction {tx_id} not found")
    tx.status = "failed"

    # 2. Lock wallet and refund
    wallet = lock_wallet(db, user_id, currency)
    wallet.balance = wallet.balance + amount
    wallet.total_withdrawn = wallet.total_withdrawn - amount
    wallet.updated_at = get_utc_time()
    db.flush()


# ---------------------------------------------------------------------------
# 8. reverse_debit
# ---------------------------------------------------------------------------

def reverse_debit(db: Session, tx_id: int, user_id: str, amount: Decimal, currency: str = "GBP") -> None:
    """
    Reverse a pending debit transaction.

    Only transactions with status "pending" can be reversed.
    Lock-first pattern:
      1. Check transaction is pending, set to "reversed".
      2. Acquire row lock on wallet.
      3. Refund balance, decrement total_spent.
    """
    amount = Decimal(str(amount))

    tx = db.query(WalletTransaction).filter(WalletTransaction.id == tx_id).first()
    if tx is None:
        raise ValueError(f"reverse_debit: transaction {tx_id} not found")
    if tx.status != "pending":
        raise ValueError(
            f"reverse_debit: can only reverse pending transactions, "
            f"but transaction {tx_id} has status '{tx.status}'"
        )
    tx.status = "reversed"

    # Lock wallet and refund
    wallet = lock_wallet(db, user_id, currency)
    wallet.balance = wallet.balance + amount
    wallet.total_spent = wallet.total_spent - amount
    wallet.updated_at = get_utc_time()
    db.flush()


# ---------------------------------------------------------------------------
# 9. complete_debit
# ---------------------------------------------------------------------------

def complete_debit(db: Session, tx_id: int) -> None:
    """
    Transition a pending payment transaction to completed.
    """
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == tx_id).first()
    if tx is None:
        raise ValueError(f"complete_debit: transaction {tx_id} not found")
    if tx.status != "pending":
        raise ValueError(
            f"complete_debit: expected status 'pending', "
            f"got '{tx.status}' for transaction {tx_id}"
        )
    tx.status = "completed"
    db.flush()
