from sqlalchemy import (
    Column, BigInteger, String, DECIMAL, DateTime, Text, Index,
    CheckConstraint, UniqueConstraint, func
)
from app.models import Base


class WalletAccount(Base):
    __tablename__ = "wallet_accounts"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(8), nullable=False, index=True)
    balance = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_earned = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_withdrawn = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_spent = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    currency = Column(String(3), nullable=False, default="GBP")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        CheckConstraint("balance >= 0", name="ck_wallet_balance_non_negative"),
        UniqueConstraint("user_id", "currency", name="uq_wallet_user_currency"),
    )


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(8), nullable=False, index=True)
    type = Column(String(20), nullable=False)
    amount = Column(DECIMAL(12, 2), nullable=False)
    balance_after = Column(DECIMAL(12, 2), nullable=False)
    status = Column(String(20), nullable=False, default="completed")
    source = Column(String(50), nullable=False)
    related_id = Column(String(255), nullable=True)
    related_type = Column(String(50), nullable=True)
    description = Column(Text, nullable=True)
    fee_amount = Column(DECIMAL(12, 2), nullable=True)
    gross_amount = Column(DECIMAL(12, 2), nullable=True)
    currency = Column(String(3), nullable=False, default="GBP")
    idempotency_key = Column(String(128), nullable=False, unique=True)
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index("idx_wallet_tx_type", "type"),
        Index("idx_wallet_tx_status", "status"),
        Index("idx_wallet_tx_created_at", "created_at"),
        Index("idx_wallet_tx_related", "related_type", "related_id"),
    )
