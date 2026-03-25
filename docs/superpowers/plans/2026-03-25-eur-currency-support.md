# EUR Currency Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add EUR as a supported currency alongside GBP — users can publish tasks/items/services in EUR, pay in any card currency (Stripe auto-converts), and wallet tracks balances per currency.

**Architecture:** Currency is stored per-entity (task, flea market item, service). Wallet becomes multi-currency: one WalletAccount row per (user_id, currency). All display logic uses a shared `currencySymbol()` helper instead of hardcoded '£'. Backend validates currency is one of `['GBP', 'EUR']`, frontend provides a currency picker on publish forms.

**Tech Stack:** Python/FastAPI (backend), Flutter/BLoC (frontend), PostgreSQL, Stripe API

---

## File Structure

### Backend Changes
| File | Action | Responsibility |
|------|--------|----------------|
| `backend/app/models.py` | Modify | Remove FleaMarketItem `check_currency_gbp` constraint |
| `backend/app/wallet_models.py` | Modify | Change WalletAccount unique constraint from `user_id` to `(user_id, currency)` |
| `backend/app/schemas.py` | Modify | Expand currency literals to `["GBP", "EUR"]` |
| `backend/app/wallet_service.py` | Modify | Add `currency` param to get/create/lock/credit/debit |
| `backend/app/flea_market_routes.py` | Modify | Use item's currency in PaymentIntent |
| `backend/app/routers.py` | Modify | Use task's currency in payment/transfer/wallet flows |
| `backend/app/payment_transfer_service.py` | Modify | Already accepts currency param — just ensure callers pass it |
| `backend/app/async_crud.py` | Modify | Already uses `getattr(task, "currency", "GBP")` — no change needed |
| `backend/alembic/versions/xxxx_add_eur.py` | Create | DB migration |

### Frontend Changes
| File | Action | Responsibility |
|------|--------|----------------|
| `lib/core/constants/app_constants.dart` | Modify | Add `supportedCurrencies`, `currencySymbolFor()` |
| `lib/core/constants/expert_constants.dart` | Modify | Add EUR to `serviceCurrencies` |
| `lib/core/utils/helpers.dart` | Modify | Make `formatPrice()` currency-aware |
| `lib/data/models/payment.dart` | Modify | Fix hardcoded £ in display getters |
| `lib/data/models/flea_market.dart` | Modify | Fix hardcoded £ in `priceDisplay` |
| `lib/data/models/task_expert.dart` | Modify | Fix hardcoded £ in `priceDisplay` |
| `lib/features/tasks/views/create_task_view.dart` | Modify | Already has `_selectedCurrency` — just needs EUR option |
| `lib/features/tasks/views/create_task_widgets.dart` | Modify | Dynamic currency symbol in PriceRow |
| `lib/features/flea_market/views/create_flea_market_item_view.dart` | Modify | Add currency selector, dynamic prefix |
| `lib/features/wallet/views/wallet_view.dart` | Modify | Show per-currency balances |
| `lib/features/ai_chat/widgets/task_draft_card.dart` | Modify | Already handles non-GBP — just add € mapping |
| `lib/features/ai_chat/widgets/task_result_cards.dart` | Modify | Same — add € mapping |
| `lib/features/ai_chat/widgets/service_draft_card.dart` | Modify | Same |
| Various UI files with hardcoded £ | Modify | Replace with `Helpers.currencySymbolFor()` |

---

### Task 1: Backend — DB Migration & Model Changes

**Files:**
- Modify: `backend/app/models.py:1820` (remove CheckConstraint)
- Modify: `backend/app/wallet_models.py:12,21` (unique constraint change)
- Modify: `backend/app/schemas.py:2269,2288,362`
- Create: `backend/alembic/versions/xxxx_add_eur_currency_support.py`

- [ ] **Step 1: Remove FleaMarketItem GBP-only constraint**

In `backend/app/models.py`, find and remove the CheckConstraint on FleaMarketItem:
```python
# REMOVE this line from __table_args__:
CheckConstraint("currency = 'GBP'", name="check_currency_gbp"),
```

- [ ] **Step 2: Update WalletAccount unique constraint**

In `backend/app/wallet_models.py`, change `user_id` from `unique=True` to part of a composite unique index:
```python
class WalletAccount(Base):
    __tablename__ = "wallet_accounts"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(8), nullable=False, index=True)  # Remove unique=True
    balance = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_earned = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_withdrawn = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_spent = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    currency = Column(String(3), nullable=False, default="GBP")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        CheckConstraint("balance >= 0", name="ck_wallet_balance_non_negative"),
        Index("uq_wallet_user_currency", "user_id", "currency", unique=True),
    )
```

- [ ] **Step 3: Add `currency` column to WalletTransaction**

In `backend/app/wallet_models.py`, add currency field to WalletTransaction:
```python
currency = Column(String(3), nullable=False, default="GBP")
```

- [ ] **Step 4: Update schemas**

In `backend/app/schemas.py`:

1. Define allowed currencies constant at the top:
```python
SUPPORTED_CURRENCIES = ("GBP", "EUR")
```

2. Update `TaskCreate` (line ~362):
```python
currency: Optional[str] = "GBP"
# Add validator:
@field_validator("currency")
@classmethod
def validate_currency(cls, v):
    if v and v not in SUPPORTED_CURRENCIES:
        raise ValueError(f"currency must be one of {SUPPORTED_CURRENCIES}")
    return v or "GBP"
```

3. Update `FleaMarketItemCreate` (line ~2269):
```python
currency: Literal["GBP", "EUR"] = "GBP"
```

4. Update `FleaMarketItemUpdate` (line ~2288):
```python
currency: Optional[Literal["GBP", "EUR"]] = None
```

- [ ] **Step 5: Create Alembic migration**

```bash
cd backend && alembic revision --autogenerate -m "add EUR currency support"
```

Review the generated migration and manually add:
```python
# Drop the GBP-only constraint on flea_market_items
op.drop_constraint("check_currency_gbp", "flea_market_items", type_="check")

# Add currency-in-set constraint (optional but recommended)
op.create_check_constraint(
    "check_currency_supported",
    "flea_market_items",
    "currency IN ('GBP', 'EUR')"
)

# Drop old unique constraint on wallet_accounts.user_id
op.drop_constraint("wallet_accounts_user_id_key", "wallet_accounts", type_="unique")

# Create new composite unique index
op.create_index("uq_wallet_user_currency", "wallet_accounts", ["user_id", "currency"], unique=True)

# Add currency column to wallet_transactions
op.add_column("wallet_transactions", sa.Column("currency", sa.String(3), nullable=False, server_default="GBP"))
```

- [ ] **Step 6: Run migration**

```bash
cd backend && alembic upgrade head
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/models.py backend/app/wallet_models.py backend/app/schemas.py backend/alembic/versions/
git commit -m "feat: add EUR currency support — DB models and migration"
```

---

### Task 2: Backend — Wallet Service Multi-Currency

**Files:**
- Modify: `backend/app/wallet_service.py`

- [ ] **Step 1: Update `get_or_create_wallet` to accept currency**

```python
def get_or_create_wallet(db: Session, user_id: str, currency: str = "GBP") -> WalletAccount:
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
```

- [ ] **Step 2: Update `lock_wallet` to accept currency**

```python
def lock_wallet(db: Session, user_id: str, currency: str = "GBP") -> WalletAccount:
    wallet = (
        db.query(WalletAccount)
        .filter(WalletAccount.user_id == user_id, WalletAccount.currency == currency)
        .with_for_update()
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
        wallet = (
            db.query(WalletAccount)
            .filter(WalletAccount.user_id == user_id, WalletAccount.currency == currency)
            .with_for_update()
            .first()
        )
    return wallet
```

- [ ] **Step 3: Update `credit_wallet` to accept currency**

Add `currency: str = "GBP"` parameter. Pass it to `lock_wallet(db, user_id, currency)`. Set `tx.currency = currency`.

- [ ] **Step 4: Update `debit_wallet` to accept currency**

Same pattern — add `currency` param, pass to `lock_wallet`, set on transaction.

- [ ] **Step 5: Update `create_pending_withdrawal` to accept currency**

Same pattern.

- [ ] **Step 6: Commit**

```bash
git add backend/app/wallet_service.py
git commit -m "feat(wallet): support multi-currency wallets (GBP + EUR)"
```

---

### Task 3: Backend — Payment & Transfer Routes Use Entity Currency

**Files:**
- Modify: `backend/app/flea_market_routes.py:1841`
- Modify: `backend/app/routers.py` (multiple locations)

- [ ] **Step 1: Update flea market PaymentIntent creation**

In `flea_market_routes.py`, change hardcoded `"gbp"` to use the item's currency:
```python
create_pi_kw = {
    "amount": task_amount_pence,
    "currency": (item.currency or "GBP").lower(),  # Was hardcoded "gbp"
    ...
}
```

- [ ] **Step 2: Update task payment PaymentIntent creation in routers.py**

Search for all `"currency": "gbp"` or `currency="GBP"` in PaymentIntent creation and replace with `task.currency.lower()`.

- [ ] **Step 3: Update wallet credit calls to pass currency**

In `routers.py`, wherever `credit_wallet()` is called for task completion:
```python
credit_wallet(
    db=db,
    user_id=task.taker_id,
    amount=net_amount,
    currency=task.currency or "GBP",  # ADD THIS
    source=source,
    ...
)
```

- [ ] **Step 4: Update PaymentHistory creation to use task currency**

Replace hardcoded `currency="GBP"` with `currency=task.currency or "GBP"` in PaymentHistory creation.

- [ ] **Step 5: Update transfer creation to use task currency**

In locations where `create_transfer_record()` is called, pass `currency=task.currency or "GBP"`.

- [ ] **Step 6: Update wallet API responses**

The wallet info endpoint should return all wallets for the user (GBP + EUR). Update the response to include a list of balances:
```python
wallets = db.query(WalletAccount).filter(WalletAccount.user_id == user_id).all()
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/flea_market_routes.py backend/app/routers.py
git commit -m "feat: use entity currency in payment/transfer/wallet flows"
```

---

### Task 4: Frontend — Currency Helper & Constants

**Files:**
- Modify: `lib/core/constants/app_constants.dart:85-87`
- Modify: `lib/core/constants/expert_constants.dart:40`
- Modify: `lib/core/utils/helpers.dart:10-17`

- [ ] **Step 1: Update app_constants.dart**

```dart
/// 支持的货币
static const List<String> supportedCurrencies = ['GBP', 'EUR'];
static const String defaultCurrency = 'GBP';

/// 根据货币代码返回符号
static String currencySymbolFor(String currency) {
  switch (currency.toUpperCase()) {
    case 'EUR': return '€';
    case 'GBP': return '£';
    default: return '£';
  }
}
static const String currencySymbol = '£'; // 保留向后兼容
```

- [ ] **Step 2: Update helpers.dart**

```dart
// ==================== 货币格式化 ====================
/// 货币符号（默认英镑，支持多币种）
static const String currencySymbol = '£';

/// 根据货币代码返回符号
static String currencySymbolFor(String currency) {
  switch (currency.toUpperCase()) {
    case 'EUR': return '€';
    case 'GBP': return '£';
    default: return '£';
  }
}

/// 格式化价格：支持多币种
static String formatPrice(double price, {String currency = 'GBP'}) {
  return '${currencySymbolFor(currency)}${formatAmountNumber(price)}';
}
```

- [ ] **Step 3: Update expert_constants.dart**

```dart
static const List<String> serviceCurrencies = ['GBP', 'EUR', 'CNY', 'USD'];
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/constants/ lib/core/utils/helpers.dart
git commit -m "feat: add EUR to currency helpers and constants"
```

---

### Task 5: Frontend — Fix Hardcoded £ in Models

**Files:**
- Modify: `lib/data/models/payment.dart` (WalletInfo, Transaction, StripeConnectBalance, StripeConnectTransaction display getters)
- Modify: `lib/data/models/flea_market.dart` (priceDisplay)
- Modify: `lib/data/models/task_expert.dart` (priceDisplay)

- [ ] **Step 1: Fix payment.dart display getters**

WalletInfo (line ~178):
```dart
String get balanceDisplay => '${Helpers.currencySymbolFor(currency)}${balance.toStringAsFixed(2)}';
String get totalEarnedDisplay => '${Helpers.currencySymbolFor(currency)}${totalEarned.toStringAsFixed(2)}';
String get totalSpentDisplay => '${Helpers.currencySymbolFor(currency)}${totalSpent.toStringAsFixed(2)}';
```

Transaction (line ~224):
```dart
String get amountDisplay => '${isIncome ? '+' : ''}${Helpers.currencySymbolFor(currency)}${amount.abs().toStringAsFixed(2)}';
```

StripeConnectBalance (line ~260):
```dart
String formatAmount(double amount) {
  return '${Helpers.currencySymbolFor(currency)}${amount.toStringAsFixed(2)}';
}
```

StripeConnectTransaction (line ~426):
```dart
String get amountDisplay {
  final prefix = isIncome ? '+' : '-';
  return '$prefix${Helpers.currencySymbolFor(currency)}${amount.abs().toStringAsFixed(2)}';
}
```

- [ ] **Step 2: Fix flea_market.dart priceDisplay**

Line ~107:
```dart
String get priceDisplay => '${Helpers.currencySymbolFor(currency)}${price.toStringAsFixed(2)}';
```

- [ ] **Step 3: Fix task_expert.dart priceDisplay**

Line ~388:
```dart
String get priceDisplay => '${Helpers.currencySymbolFor(currency)}${basePrice.toStringAsFixed(2)}';
```

- [ ] **Step 4: Fix AI chat cards**

In `task_draft_card.dart`, `task_result_cards.dart`, `service_draft_card.dart`, update the symbol mapping:
```dart
final currencySymbol = Helpers.currencySymbolFor(currency);
```

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/ lib/features/ai_chat/widgets/
git commit -m "feat: use dynamic currency symbols in models and AI chat cards"
```

---

### Task 6: Frontend — Currency Selector in Publish Forms

**Files:**
- Modify: `lib/features/tasks/views/create_task_view.dart`
- Modify: `lib/features/tasks/views/create_task_widgets.dart`
- Modify: `lib/features/flea_market/views/create_flea_market_item_view.dart`

- [ ] **Step 1: Update create_task_view.dart**

The file already has `_selectedCurrency = 'GBP'`. Ensure the currency selector dropdown includes EUR. Find the currency selection widget and add EUR option. If no selector UI exists yet, add a simple toggle/dropdown near the price field:

```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'GBP', label: Text('£ GBP')),
    ButtonSegment(value: 'EUR', label: Text('€ EUR')),
  ],
  selected: {_selectedCurrency},
  onSelectionChanged: (v) => setState(() => _selectedCurrency = v.first),
)
```

- [ ] **Step 2: Update create_task_widgets.dart PriceRow**

Replace the hardcoded `'£'` text (line ~158) with a currency parameter:
```dart
Text(currencySymbol,
    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
```
The PriceRow widget needs to accept a `currency` parameter.

- [ ] **Step 3: Update create_flea_market_item_view.dart**

Add `_selectedCurrency` state variable (default 'GBP'), add currency selector near price field, change `prefixText: '£ '` to dynamic:
```dart
prefixText: '${Helpers.currencySymbolFor(_selectedCurrency)} ',
```
Pass `_selectedCurrency` to `CreateFleaMarketRequest(currency: _selectedCurrency)`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/tasks/views/ lib/features/flea_market/views/
git commit -m "feat: add EUR currency selector to task and flea market publish forms"
```

---

### Task 7: Frontend — Wallet Multi-Currency Display

**Files:**
- Modify: `lib/features/wallet/views/wallet_view.dart`
- Modify: `lib/data/models/payment.dart` (WalletInfo model or add new multi-wallet response)
- Modify: `lib/features/wallet/bloc/wallet_bloc.dart` (if needed)

- [ ] **Step 1: Update wallet API response model**

The backend will now return multiple wallets. Update or add a model to hold per-currency balances:
```dart
class WalletInfo {
  // Keep existing fields for primary (GBP) wallet
  // Add optional EUR wallet info
  final double balanceEur;
  final double totalEarnedEur;
  // Or better: change to a list of per-currency balances
}
```

Alternatively, backend returns `wallets: [{ currency: "GBP", balance: ... }, { currency: "EUR", balance: ... }]` and frontend renders both.

- [ ] **Step 2: Update wallet_view.dart**

Show two balance cards (or tabs) — one for GBP, one for EUR. Only show EUR section if EUR wallet exists and has non-zero activity.

- [ ] **Step 3: Commit**

```bash
git add lib/features/wallet/ lib/data/models/payment.dart
git commit -m "feat(wallet): display multi-currency balances (GBP + EUR)"
```

---

### Task 8: Frontend — Replace Remaining Hardcoded £ in UI

**Files:**
- Modify: Multiple UI files with hardcoded `'£'` symbols

- [ ] **Step 1: Search and replace hardcoded £ in feature views**

Key files to update:
- `home_view.dart` — reward/price display
- `home_discovery_cards.dart` — price display
- `home_experts_search.dart` — price display
- `home_activities_section.dart` — `_currencySymbol()` function
- `activity_detail_view.dart` — activity pricing
- `activity_list_view.dart` — activity pricing
- `coupon_points_view.dart` — coupon minimum amount
- `flea_market_detail_view.dart` — price display
- `task_detail_components.dart:3080` — already partially dynamic, fix fallback

For each: replace `'£'` with `Helpers.currencySymbolFor(item.currency)` or the appropriate currency source from the data model.

- [ ] **Step 2: Run `flutter analyze`**

```bash
cd link2ur && flutter analyze
```
Fix any issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ lib/core/
git commit -m "feat: replace hardcoded £ with dynamic currency symbols across UI"
```

---

### Task 9: Verification & Testing

- [ ] **Step 1: Backend — test creating a task with EUR currency**

```bash
# Via API or test script
curl -X POST /api/tasks -d '{"title": "Test EUR task", "reward": 10, "currency": "EUR", ...}'
```

- [ ] **Step 2: Backend — test wallet credit in EUR**

Verify that completing an EUR task creates/credits an EUR wallet for the taker.

- [ ] **Step 3: Frontend — test task creation with EUR**

Create a task with EUR selected, verify it displays € symbol.

- [ ] **Step 4: Frontend — test wallet shows both currencies**

Verify wallet view shows GBP and EUR balances correctly.

- [ ] **Step 5: Run full `flutter analyze` and existing tests**

```bash
cd link2ur && flutter analyze && flutter test
```

- [ ] **Step 6: Final commit**

```bash
git commit -m "feat: EUR currency support complete"
```
