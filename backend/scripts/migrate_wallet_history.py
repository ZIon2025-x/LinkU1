"""
One-time migration: Create WalletAccount + WalletTransaction records
for existing users based on PaymentTransfer history.

Old users get balance=0 (money is already in their Stripe Connect accounts).
No individual withdrawal records are created for old payouts.
"""
from decimal import Decimal
from app.database import SessionLocal
from app.models import PaymentTransfer
from app.wallet_models import WalletAccount, WalletTransaction
import sys


def migrate(dry_run=False):
    db = SessionLocal()
    try:
        # Get all users who have successful transfers as taker
        taker_ids = db.query(PaymentTransfer.taker_id).filter(
            PaymentTransfer.status == "succeeded"
        ).distinct().all()
        taker_ids = [t[0] for t in taker_ids]

        migrated = 0
        for user_id in taker_ids:
            transfers = db.query(PaymentTransfer).filter(
                PaymentTransfer.taker_id == user_id,
                PaymentTransfer.status == "succeeded",
            ).all()

            # Group by currency
            by_currency = {}
            for t in transfers:
                curr = t.currency or "GBP"
                if curr not in by_currency:
                    by_currency[curr] = []
                by_currency[curr].append(t)

            for currency, currency_transfers in by_currency.items():
                # Check if wallet already exists
                existing = db.query(WalletAccount).filter(
                    WalletAccount.user_id == user_id,
                    WalletAccount.currency == currency,
                ).first()
                if existing:
                    continue

                total_earned = Decimal("0")
                for t in currency_transfers:
                    amount = Decimal(str(t.amount))
                    total_earned += amount

                    # Create earning transaction record
                    tx = WalletTransaction(
                        user_id=user_id,
                        type="earning",
                        amount=amount,
                        balance_after=Decimal("0"),
                        status="completed",
                        source="task_reward",
                        currency=currency,
                        related_id=str(t.task_id),
                        related_type="task",
                        description=f"[历史迁移] 任务 #{t.task_id} 奖励",
                        idempotency_key=f"migration:earning:task:{t.task_id}:user:{user_id}",
                        created_at=t.succeeded_at or t.created_at,
                    )
                    db.add(tx)

                account = WalletAccount(
                    user_id=user_id,
                    balance=Decimal("0"),
                    total_earned=total_earned,
                    total_withdrawn=total_earned,
                    currency=currency,
                )
                db.add(account)
                db.flush()
                migrated += 1
                print(f"  User {user_id} [{currency}]: {len(currency_transfers)} records, total {total_earned}")

        if dry_run:
            db.rollback()
            print(f"\n[DRY RUN] Would migrate {migrated} wallets for {len(taker_ids)} users")
        else:
            db.commit()
            print(f"\nMigration complete: {migrated} wallets for {len(taker_ids)} users")
    except Exception as e:
        db.rollback()
        print(f"Migration failed: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    dry = "--dry-run" in sys.argv
    if dry:
        print("Running in DRY RUN mode (no changes will be committed)\n")
    migrate(dry_run=dry)
