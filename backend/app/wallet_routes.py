"""
Wallet API Routes — balance, transactions, and withdrawal endpoints.

All endpoints require authenticated user (session-based auth with CSRF).
"""
import logging
from decimal import Decimal, ROUND_DOWN
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
import stripe

from app import models
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.wallet_models import WalletAccount, WalletTransaction
from app.wallet_schemas import (
    WalletBalanceOut,
    WalletBalancesResponse,
    WalletTransactionOut,
    WalletTransactionsResponse,
    WithdrawRequest,
    WithdrawResponse,
)
from app.wallet_service import (
    get_or_create_wallet,
    create_pending_withdrawal,
    complete_withdrawal,
    fail_withdrawal,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/wallet", tags=["Wallet"])


# ---------------------------------------------------------------------------
# GET /api/wallet/balance
# ---------------------------------------------------------------------------

def _format_wallet(w: WalletAccount) -> WalletBalanceOut:
    """Convert a WalletAccount ORM object to a response schema."""
    return WalletBalanceOut(
        # NOTE: float has ~15-digit precision; sufficient for balances < 1 trillion
        # but may lose sub-penny precision. Acceptable for display purposes.
        balance=float(w.balance),
        total_earned=float(w.total_earned),
        total_withdrawn=float(w.total_withdrawn),
        total_spent=float(w.total_spent),
        currency=w.currency,
    )


@router.get("/balance", response_model=WalletBalancesResponse)
def get_balance(
    currency: Optional[str] = Query(None, description="Filter by currency (e.g. GBP, EUR). Omit to get all wallets."),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """Return wallet balance(s) for the authenticated user. Creates wallet if not exists."""
    if currency:
        account = get_or_create_wallet(db, current_user.id, currency.upper())
        wallets = [account]
    else:
        wallets = (
            db.query(WalletAccount)
            .filter(WalletAccount.user_id == current_user.id)
            .all()
        )
        if not wallets:
            # Create default GBP wallet
            wallets = [get_or_create_wallet(db, current_user.id, "GBP")]
    db.commit()
    return WalletBalancesResponse(
        wallets=[_format_wallet(w) for w in wallets],
    )


# ---------------------------------------------------------------------------
# GET /api/wallet/transactions
# ---------------------------------------------------------------------------

@router.get("/transactions", response_model=WalletTransactionsResponse)
def get_transactions(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    type: Optional[str] = Query(None, description="Filter by transaction type"),
    currency: Optional[str] = Query(None, description="Filter by currency (e.g. GBP, EUR)"),
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """Return paginated wallet transactions. Only completed and pending are shown."""
    query = (
        db.query(WalletTransaction)
        .filter(
            WalletTransaction.user_id == current_user.id,
            WalletTransaction.status.in_(["completed", "pending"]),
        )
    )
    if type:
        query = query.filter(WalletTransaction.type == type)
    if currency:
        query = query.filter(WalletTransaction.currency == currency.upper())

    total = query.count()
    items = (
        query.order_by(WalletTransaction.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return WalletTransactionsResponse(
        items=[
            WalletTransactionOut(
                id=tx.id,
                type=tx.type,
                amount=float(tx.amount),
                balance_after=float(tx.balance_after),
                status=tx.status,
                source=tx.source,
                related_id=tx.related_id,
                related_type=tx.related_type,
                description=tx.description,
                fee_amount=float(tx.fee_amount) if tx.fee_amount is not None else None,
                gross_amount=float(tx.gross_amount) if tx.gross_amount is not None else None,
                currency=tx.currency,
                created_at=tx.created_at,
            )
            for tx in items
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


# ---------------------------------------------------------------------------
# POST /api/wallet/withdraw
# ---------------------------------------------------------------------------

@router.post("/withdraw", response_model=WithdrawResponse)
def withdraw(
    req: WithdrawRequest,
    current_user: models.User = Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """
    Two-phase withdrawal:
      1. create_pending_withdrawal — deducts balance, creates pending tx (DB commit)
      2. stripe.Transfer.create — sends funds to user's Connect account
      3. complete_withdrawal or fail_withdrawal depending on Stripe result
    """
    # Check user has a Stripe Connect account
    stripe_account_id = current_user.stripe_account_id
    if not stripe_account_id:
        raise HTTPException(
            status_code=428,
            detail="Stripe Connect account not set up. Please complete onboarding first.",
        )

    # Convert to Decimal for precise arithmetic
    amount = Decimal(str(req.amount)).quantize(Decimal("0.01"), rounding=ROUND_DOWN)
    amount_pence = int(amount * 100)

    currency = req.currency.upper()

    # Phase 1: DB — create pending withdrawal (commits internally via flush, we commit here)
    try:
        pending_tx = create_pending_withdrawal(
            db=db,
            user_id=current_user.id,
            amount=amount,
            request_uuid=req.request_id,
            currency=currency,
        )
        db.commit()
    except ValueError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

    # Phase 2: Stripe Transfer
    try:
        transfer = stripe.Transfer.create(
            amount=amount_pence,
            currency=currency.lower(),
            destination=stripe_account_id,
            description=f"Wallet withdrawal for user {current_user.id}",
            metadata={
                "user_id": str(current_user.id),
                "wallet_tx_id": str(pending_tx.id),
                "request_id": req.request_id,
            },
        )
    except stripe.error.StripeError as e:
        # Phase 3a: Stripe failed — refund balance
        logger.error(
            f"Stripe Transfer failed for user {current_user.id}, "
            f"tx {pending_tx.id}: {e}"
        )
        try:
            fail_withdrawal(db, pending_tx.id, current_user.id, amount)
            db.commit()
        except Exception as rollback_err:
            logger.critical(
                f"Failed to rollback withdrawal tx {pending_tx.id}: {rollback_err}"
            )
            db.rollback()

        raise HTTPException(
            status_code=502,
            detail=f"Stripe transfer failed: {str(e)}",
        )

    # Phase 3b: Stripe succeeded — mark completed
    try:
        complete_withdrawal(db, pending_tx.id, transfer.id)
        db.commit()
    except Exception as e:
        logger.critical(
            f"Stripe Transfer {transfer.id} succeeded but DB update failed "
            f"for tx {pending_tx.id}: {e}"
        )
        db.rollback()
        # Return success anyway — money was sent. Manual reconciliation needed.

    # Re-read wallet for updated balance
    wallet = get_or_create_wallet(db, current_user.id, currency)

    return WithdrawResponse(
        success=True,
        transfer_id=transfer.id,
        amount=float(amount),
        balance_after=float(wallet.balance),
        currency=currency,
    )
