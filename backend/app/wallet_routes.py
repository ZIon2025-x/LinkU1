"""
Wallet API Routes — balance, transactions, and withdrawal endpoints.

All endpoints require authenticated user (session-based auth with CSRF).
"""
import logging
from decimal import Decimal, ROUND_DOWN
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func
from sqlalchemy.orm import Session
import stripe

from app import models
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.rate_limiting import rate_limit
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

def _format_wallet(w: WalletAccount, total_all_earned: float = None, total_all_spent: float = None) -> WalletBalanceOut:
    """Convert a WalletAccount ORM object to a response schema."""
    return WalletBalanceOut(
        # NOTE: float has ~15-digit precision; sufficient for balances < 1 trillion
        # but may lose sub-penny precision. Acceptable for display purposes.
        balance=float(w.balance),
        total_earned=float(w.total_earned),
        total_withdrawn=float(w.total_withdrawn),
        total_spent=float(w.total_spent),
        currency=w.currency,
        total_all_earned=total_all_earned,
        total_all_spent=total_all_spent,
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
            # Create default wallet — use user's Stripe Connect country currency, fallback to GBP
            from app.stripe_connect_routes import STRIPE_COUNTRY_CONFIG
            default_currency = "GBP"
            if current_user.stripe_connect_country:
                cfg = STRIPE_COUNTRY_CONFIG.get(current_user.stripe_connect_country.upper())
                if cfg:
                    default_currency = cfg["currency"]
            wallets = [get_or_create_wallet(db, current_user.id, default_currency)]
    db.commit()

    # 全局汇总：包含所有支付方式（Stripe 直接支付 + 钱包 + 优惠券等）
    # 累计消费：PaymentHistory 中所有 succeeded 的 total_amount（便士→英镑）
    total_all_spent_pence = db.query(
        func.coalesce(func.sum(models.PaymentHistory.total_amount), 0)
    ).filter(
        models.PaymentHistory.user_id == current_user.id,
        models.PaymentHistory.status == "succeeded",
    ).scalar()
    total_all_spent = float(total_all_spent_pence) / 100.0

    # 累计收款：PaymentTransfer 中所有 succeeded 且 taker_id 是当前用户的 amount（已是英镑）
    total_all_earned_raw = db.query(
        func.coalesce(func.sum(models.PaymentTransfer.amount), 0)
    ).filter(
        models.PaymentTransfer.taker_id == current_user.id,
        models.PaymentTransfer.status == "succeeded",
    ).scalar()
    total_all_earned = float(total_all_earned_raw)
    # 也加上钱包的 total_earned（包含非 transfer 来源的入账，如退款等）
    wallet_earned = sum(float(w.total_earned) for w in wallets)
    if wallet_earned > total_all_earned:
        total_all_earned = wallet_earned

    return WalletBalancesResponse(
        wallets=[_format_wallet(w, total_all_earned=total_all_earned, total_all_spent=total_all_spent) for w in wallets],
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

# 🔒 Fix W3: 提现金额限制
MAX_SINGLE_WITHDRAWAL = Decimal("5000.00")  # 单笔上限 £5000
MAX_DAILY_WITHDRAWAL = Decimal("10000.00")  # 日累计上限 £10000


@router.post("/withdraw", response_model=WithdrawResponse)
@rate_limit("wallet_withdraw")
def withdraw(
    req: WithdrawRequest,
    request: Request,  # rate_limit 需要
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

    # 🔒 Fix W3: 单笔提现上限
    if amount > MAX_SINGLE_WITHDRAWAL:
        raise HTTPException(
            status_code=400,
            detail=f"单笔提现不能超过 £{MAX_SINGLE_WITHDRAWAL}",
        )

    # 🔒 Fix W3: 日累计提现上限（查最近 24 小时已完成 + pending 的提现总额）
    from datetime import datetime, timedelta, timezone as tz
    _24h_ago = datetime.now(tz.utc) - timedelta(hours=24)
    daily_total = (
        db.query(func.coalesce(func.sum(func.abs(WalletTransaction.amount)), 0))
        .filter(
            WalletTransaction.user_id == current_user.id,
            WalletTransaction.type == "withdrawal",
            WalletTransaction.status.in_(["completed", "pending"]),
            WalletTransaction.currency == currency,
            WalletTransaction.created_at >= _24h_ago,
        )
        .scalar()
    )
    if Decimal(str(daily_total)) + amount > MAX_DAILY_WITHDRAWAL:
        raise HTTPException(
            status_code=400,
            detail=f"24小时内累计提现不能超过 £{MAX_DAILY_WITHDRAWAL}（已提 £{daily_total:.2f}）",
        )

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
