from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class WalletBalanceOut(BaseModel):
    """Single wallet balance for one currency."""
    # NOTE: float has ~15-digit precision, which may lose sub-penny accuracy
    # on very large balances. Acceptable for display; all DB arithmetic uses Decimal.
    balance: float
    total_earned: float
    total_withdrawn: float
    total_spent: float
    currency: str = "GBP"


# Legacy alias — kept for backward compatibility during migration
WalletBalanceResponse = WalletBalanceOut


class WalletBalancesResponse(BaseModel):
    """Response containing one or more wallet balances (multi-currency)."""
    wallets: List[WalletBalanceOut]


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
    currency: str = "GBP"
    created_at: datetime

    class Config:
        from_attributes = True


class WalletTransactionsResponse(BaseModel):
    items: List[WalletTransactionOut]
    total: int
    page: int
    page_size: int


class WithdrawRequest(BaseModel):
    amount: float = Field(gt=0, description="Withdrawal amount")
    request_id: str = Field(min_length=1, max_length=64, description="Client-generated UUID")
    currency: str = Field(default="GBP", description="Currency: GBP or EUR")


class WithdrawResponse(BaseModel):
    success: bool
    transfer_id: Optional[str] = None
    amount: float
    balance_after: float
    currency: str = "GBP"
    error: Optional[str] = None
