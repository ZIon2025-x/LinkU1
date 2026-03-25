# Flea Market Rental Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add second-hand rental support to the flea market, allowing users to rent items with deposit + rental pricing, application-based flow, and multi-rental support.

**Architecture:** Extend the existing FleaMarketItem model with `listing_type` and rental fields. New `FleaMarketRentalRequest` and `FleaMarketRental` tables/models handle the rental lifecycle. A separate `FleaMarketRentalBloc` (page-level) manages rental operations while the existing `FleaMarketBloc` gains only a `listingTypeFilter`. Backend adds rental endpoints in `flea_market_routes.py`.

**Tech Stack:** Flutter (BLoC, Equatable, GoRouter), Python (FastAPI, SQLAlchemy, Pydantic), Stripe (PaymentIntent + Partial Refund), PostgreSQL

**Spec:** `docs/superpowers/specs/2026-03-25-flea-market-rental-design.md`

---

## File Structure

### Backend — New Files
- `backend/app/flea_market_rental_routes.py` — All rental-specific route handlers (rental requests, approve/reject/counter-offer, confirm return, rental detail, my-rentals)

### Backend — Modified Files
- `backend/app/models.py` — Add `FleaMarketRentalRequest` and `FleaMarketRental` models, extend `FleaMarketItem` with rental fields
- `backend/app/schemas.py` — Add rental request/response schemas, extend item create/update/response schemas
- `backend/app/flea_market_constants.py` — Add rental constants (listing types, rental statuses, rental unit types)
- `backend/app/flea_market_routes.py` — Extend `GET /items` with `listing_type` filter, extend `POST /items` and `PUT /items` with rental fields, extend item response with `active_rentals`
- `backend/app/flea_market_extensions.py` — Add rental notification helpers
- `backend/app/main.py` or `backend/app/routers.py` — Register rental router

### Flutter — New Files
- `link2ur/lib/data/models/flea_market_rental.dart` — `FleaMarketRentalRequest` and `FleaMarketRental` models
- `link2ur/lib/features/flea_market/bloc/flea_market_rental_bloc.dart` — Rental BLoC (events, state, handlers)
- `link2ur/lib/features/flea_market/views/rental_request_sheet.dart` — Bottom sheet for rental application
- `link2ur/lib/features/flea_market/views/rental_detail_view.dart` — Rental detail page
- `link2ur/lib/features/flea_market/views/my_rentals_view.dart` — My rentals list page

### Flutter — Modified Files
- `link2ur/lib/data/models/flea_market.dart` — Add rental fields to `FleaMarketItem`, extend `CreateFleaMarketRequest`
- `link2ur/lib/data/repositories/flea_market_repository.dart` — Add 9 rental repository methods
- `link2ur/lib/features/flea_market/bloc/flea_market_bloc.dart` — Add `listingTypeFilter` to state + filter event
- `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart` — Add listing type toggle + rental form fields
- `link2ur/lib/features/flea_market/views/edit_flea_market_item_view.dart` — Show rental fields for rental items (type not editable)
- `link2ur/lib/features/flea_market/views/flea_market_view.dart` — Rental badge on cards, price format, listing type filter
- `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart` — Rental detail display, apply button, owner management
- `link2ur/lib/core/constants/api_endpoints.dart` — Add 9 rental endpoint constants
- `link2ur/lib/core/constants/app_constants.dart` — Add rental constants
- `link2ur/lib/core/router/app_routes.dart` — Add rental routes
- `link2ur/lib/core/router/routes/flea_market_routes.dart` — Register rental detail + my-rentals routes
- `link2ur/lib/core/utils/error_localizer.dart` — Add rental error codes
- `link2ur/lib/l10n/app_en.arb` — Add ~35 rental localization keys
- `link2ur/lib/l10n/app_zh.arb` — Add ~35 rental localization keys
- `link2ur/lib/l10n/app_zh_Hant.arb` — Add ~35 rental localization keys

---

## Task 1: Backend — Constants & Database Models

**Files:**
- Modify: `backend/app/flea_market_constants.py`
- Modify: `backend/app/models.py:1784-1821` (FleaMarketItem), `1876-1900` (reference: PurchaseRequest)

- [ ] **Step 1: Add rental constants**

In `backend/app/flea_market_constants.py`, add:

```python
# Listing types
LISTING_TYPE_SALE = 'sale'
LISTING_TYPE_RENTAL = 'rental'
LISTING_TYPES = [LISTING_TYPE_SALE, LISTING_TYPE_RENTAL]

# Rental request statuses
RENTAL_REQUEST_PENDING = 'pending'
RENTAL_REQUEST_APPROVED = 'approved'
RENTAL_REQUEST_REJECTED = 'rejected'
RENTAL_REQUEST_COUNTER_OFFER = 'counter_offer'
RENTAL_REQUEST_EXPIRED = 'expired'

# Rental statuses
RENTAL_STATUS_ACTIVE = 'active'
RENTAL_STATUS_RETURNED = 'returned'
RENTAL_STATUS_OVERDUE = 'overdue'
RENTAL_STATUS_DISPUTED = 'disputed'

# Deposit statuses
DEPOSIT_HELD = 'held'
DEPOSIT_REFUNDED = 'refunded'
DEPOSIT_FORFEITED = 'forfeited'

# Rental unit types
RENTAL_UNIT_DAY = 'day'
RENTAL_UNIT_WEEK = 'week'
RENTAL_UNIT_MONTH = 'month'
RENTAL_UNITS = [RENTAL_UNIT_DAY, RENTAL_UNIT_WEEK, RENTAL_UNIT_MONTH]

# Rental constraints
RENTAL_PAYMENT_TIMEOUT_HOURS = 24
```

- [ ] **Step 2: Add rental fields to FleaMarketItem model**

In `backend/app/models.py`, add to the `FleaMarketItem` class (after `category` field, around line 1800):

```python
listing_type = Column(String(20), default="sale", nullable=False, index=True)
deposit = Column(DECIMAL(12, 2), nullable=True)
rental_price = Column(DECIMAL(12, 2), nullable=True)
rental_unit = Column(String(20), nullable=True)  # day, week, month
```

Add CheckConstraint:
```python
CheckConstraint("listing_type IN ('sale', 'rental')", name="check_listing_type_valid"),
```

- [ ] **Step 3: Add FleaMarketRentalRequest model**

In `backend/app/models.py`, after the `FleaMarketPurchaseRequest` class:

```python
class FleaMarketRentalRequest(Base):
    __tablename__ = "flea_market_rental_requests"

    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("flea_market_items.id", ondelete="CASCADE"), nullable=False, index=True)
    renter_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    rental_duration = Column(Integer, nullable=False)
    desired_time = Column(Text, nullable=True)
    usage_description = Column(Text, nullable=True)
    proposed_rental_price = Column(DECIMAL(12, 2), nullable=True)
    counter_rental_price = Column(DECIMAL(12, 2), nullable=True)
    status = Column(String(20), default="pending", nullable=False)
    payment_expires_at = Column(DateTime(timezone=True), nullable=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)

    item = relationship("FleaMarketItem", backref="rental_requests")
    renter = relationship("User", backref="flea_market_rental_requests", foreign_keys=[renter_id])

    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'counter_offer', 'expired')",
            name="check_rental_request_status_valid"
        ),
    )
```

- [ ] **Step 4: Add FleaMarketRental model**

```python
class FleaMarketRental(Base):
    __tablename__ = "flea_market_rentals"

    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("flea_market_items.id", ondelete="CASCADE"), nullable=False, index=True)
    renter_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    request_id = Column(Integer, ForeignKey("flea_market_rental_requests.id", ondelete="SET NULL"), nullable=True)
    rental_duration = Column(Integer, nullable=False)
    rental_unit = Column(String(20), nullable=False)
    total_rent = Column(DECIMAL(12, 2), nullable=False)
    deposit_amount = Column(DECIMAL(12, 2), nullable=False)
    total_paid = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(10), default="GBP", nullable=False)
    start_date = Column(DateTime(timezone=True), nullable=False)
    end_date = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(20), default="active", nullable=False)
    deposit_status = Column(String(20), default="held", nullable=False)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)
    stripe_refund_id = Column(String(255), nullable=True)
    returned_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)

    item = relationship("FleaMarketItem", backref="rentals")
    renter = relationship("User", backref="flea_market_rentals", foreign_keys=[renter_id])
    request = relationship("FleaMarketRentalRequest", backref="rental")

    __table_args__ = (
        CheckConstraint(
            "status IN ('active', 'returned', 'overdue', 'disputed')",
            name="check_rental_status_valid"
        ),
        CheckConstraint(
            "deposit_status IN ('held', 'refunded', 'forfeited')",
            name="check_deposit_status_valid"
        ),
    )
```

- [ ] **Step 5: Create Alembic migration**

```bash
cd backend
alembic revision --autogenerate -m "add flea market rental support"
alembic upgrade head
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/flea_market_constants.py backend/app/models.py backend/alembic/versions/
git commit -m "feat(backend): add rental database models and constants"
```

---

## Task 2: Backend — Schemas

**Files:**
- Modify: `backend/app/schemas.py:2721-2810`

- [ ] **Step 1: Extend FleaMarketItemCreate schema**

Around line 2723, add rental fields:

```python
class FleaMarketItemCreate(FleaMarketItemBase):
    # existing fields...
    listing_type: str = "sale"
    deposit: Optional[Decimal] = None
    rental_price: Optional[Decimal] = None
    rental_unit: Optional[str] = None

    @model_validator(mode='after')
    def validate_rental_fields(self):
        if self.listing_type == 'rental':
            if not self.deposit or self.deposit <= 0:
                raise ValueError('Deposit is required for rental items')
            if not self.rental_price or self.rental_price <= 0:
                raise ValueError('Rental price is required for rental items')
            if self.rental_unit not in ('day', 'week', 'month'):
                raise ValueError('Rental unit must be day, week, or month')
        return self
```

- [ ] **Step 2: Extend FleaMarketItemUpdate schema**

Add `deposit`, `rental_price`, `rental_unit` as optional fields. Do NOT include `listing_type`. Add validation: these fields are only accepted when the item's `listing_type == 'rental'` (check in route handler, not schema, since schema doesn't know existing item state).

- [ ] **Step 3: Extend FleaMarketItemResponse schema**

Add to response: `listing_type`, `deposit`, `rental_price`, `rental_unit`, `active_rentals: List[FleaMarketRentalSummary]`, `user_rental_request_id: Optional[int]`, `user_rental_request_status: Optional[str]`.

- [ ] **Step 4: Add rental request schemas**

```python
class FleaMarketRentalRequestCreate(BaseModel):
    rental_duration: int
    desired_time: Optional[str] = None
    usage_description: Optional[str] = None
    proposed_rental_price: Optional[Decimal] = None  # renter can propose a different price

    @field_validator('rental_duration')
    @classmethod
    def validate_duration(cls, v):
        if v < 1:
            raise ValueError('Rental duration must be at least 1')
        return v

class FleaMarketRentalSummary(BaseModel):
    """Lightweight rental info for item detail response active_rentals list"""
    id: int
    renter_name: Optional[str] = None
    start_date: str
    end_date: str
    status: str

class FleaMarketRentalRequestResponse(BaseModel):
    id: int
    item_id: str
    renter_id: str
    renter_name: Optional[str] = None
    renter_avatar: Optional[str] = None
    rental_duration: int
    desired_time: Optional[str] = None
    usage_description: Optional[str] = None
    proposed_rental_price: Optional[float] = None
    counter_rental_price: Optional[float] = None
    status: str
    created_at: str
    updated_at: str

class FleaMarketRentalResponse(BaseModel):
    id: int
    item_id: str
    renter_id: str
    renter_name: Optional[str] = None
    renter_avatar: Optional[str] = None
    rental_duration: int
    rental_unit: str
    total_rent: float
    deposit_amount: float
    total_paid: float
    currency: str
    start_date: str
    end_date: str
    status: str
    deposit_status: str
    returned_at: Optional[str] = None
    created_at: str
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat(backend): add rental schemas and extend item schemas"
```

---

## Task 3: Backend — Rental Route Handlers

**Files:**
- Create: `backend/app/flea_market_rental_routes.py`
- Modify: `backend/app/flea_market_routes.py` (register sub-router, extend item endpoints)

- [ ] **Step 1: Create rental routes file with router setup**

Create `backend/app/flea_market_rental_routes.py` with the rental router (prefix shared with flea market). Include these endpoints:

```python
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
# ... imports

rental_router = APIRouter(prefix="/api/flea-market", tags=["跳蚤市场-租赁"])
```

- [ ] **Step 2: Implement POST /items/{item_id}/rental-request**

Validates:
- Item exists and is `listing_type='rental'` and `status='active'`
- Renter is not the seller (`renter_id != seller_id`)
- `rental_duration >= 1`
- Creates `FleaMarketRentalRequest(status='pending')`
- Sends notification to seller

- [ ] **Step 3: Implement GET /items/{item_id}/rental-requests**

- Seller only (or item owner)
- Returns list of rental requests with renter info
- Paginated, sorted by `created_at DESC`

- [ ] **Step 4: Implement POST /rental-requests/{id}/approve**

- Seller only
- Sets status to `approved`
- Creates Task with `task_source='flea_market_rental'`
- Creates Stripe PaymentIntent for `total_rent + deposit`
- Sets `payment_expires_at` = now + 24h
- Returns payment info (client_secret, amount, etc.)
- Sends notification to renter

- [ ] **Step 5: Implement POST /rental-requests/{id}/reject**

- Seller only
- Sets status to `rejected`
- Sends notification to renter

- [ ] **Step 6: Implement POST /rental-requests/{id}/counter-offer**

- Seller only
- Accepts `counter_rental_price` in body
- Sets status to `counter_offer`, stores counter price
- Sends notification to renter

- [ ] **Step 7: Implement POST /rental-requests/{id}/respond-counter-offer**

- Renter only
- `accept=true` → status becomes `approved`, create Task + PaymentIntent (same as approve)
- `accept=false` → status becomes `rejected`

- [ ] **Step 8: Implement rental payment callback**

On payment success (webhook or polling):
- Create `FleaMarketRental` record with `status='active'`, `deposit_status='held'`
- `start_date` = now, `end_date` = now + duration × unit
- Link `task_id`

- [ ] **Step 9: Implement POST /rentals/{id}/confirm-return**

- Seller only (item owner)
- Rental must be `status='active'` or `status='overdue'`
- Sets `status='returned'`, `returned_at=now`
- Stripe Partial Refund for `deposit_amount`
- Records `stripe_refund_id`
- Sets `deposit_status='refunded'`

- [ ] **Step 10: Implement GET /rentals/{id}**

- Renter or seller can view
- Returns full rental detail with item info

- [ ] **Step 11: Implement GET /my-rentals**

- Returns current user's rentals (as renter)
- Paginated, sorted by `created_at DESC`

- [ ] **Step 12: Add payment expiration check-on-read**

In every endpoint that reads rental requests (GET rental-requests, approve, etc.), add a pre-check:
```python
# Expire any approved requests past their payment deadline
expired = await db.execute(
    select(FleaMarketRentalRequest).where(
        FleaMarketRentalRequest.item_id == item.id,
        FleaMarketRentalRequest.status == 'approved',
        FleaMarketRentalRequest.payment_expires_at < get_utc_time()
    )
)
for req in expired.scalars():
    req.status = 'expired'
await db.flush()
```

This lazy-expiration pattern avoids needing a Celery background task. Requests are expired when they are next accessed.

- [ ] **Step 13: Audit task_source compatibility**

In `flea_market_routes.py`, find all queries that filter by `task_source == 'flea_market'` (e.g., `get_my_related_items`, `get_my_purchases`). Update these to use:
```python
models.Task.task_source.in_(['flea_market', 'flea_market_rental'])
```

- [ ] **Step 14: Add item deletion guards for rental items**

In the existing `DELETE /items/{item_id}` handler in `flea_market_routes.py`:
- If item has any `FleaMarketRental` with `status='active'`, reject deletion with 400 error
- Auto-reject all `pending`/`approved` `FleaMarketRentalRequest` records for this item
- Send notification to affected renters

- [ ] **Step 15: Ensure item_id string formatting in all rental responses**

All rental route handlers must format `item_id` as the display string (e.g., `f"S{item.id:04d}"`) in responses, matching the existing pattern used in `FleaMarketItemResponse`. Similarly format `renter_id` and include `renter_name`/`renter_avatar` from the User relationship.

- [ ] **Step 16: Extend GET /items with listing_type filter**

In `flea_market_routes.py`, in the `get_flea_market_items` handler (line 288), add:

```python
listing_type: Optional[str] = Query(None),
```

Add to query filter:
```python
if listing_type:
    query = query.where(models.FleaMarketItem.listing_type == listing_type)
```

- [ ] **Step 17: Extend POST /items with rental validation**

In the `create_flea_market_item` handler (line 856), when `listing_type='rental'`:
- Set `price = rental_price` (for backward compat with `isFree` checks)
- Store `deposit`, `rental_price`, `rental_unit`

- [ ] **Step 18: Extend GET /items/{id} response with active_rentals**

In item detail response, query `FleaMarketRental` where `item_id=item.id` and `status='active'`, include as `active_rentals` list. Also include `user_rental_request_id` and `user_rental_request_status` for the current user.

- [ ] **Step 19: Register rental router**

In `backend/app/main.py`, import and include the rental router alongside the existing flea market router:
```python
from app.flea_market_rental_routes import rental_router
app.include_router(rental_router)
```

- [ ] **Step 20: Commit**

```bash
git add backend/app/flea_market_rental_routes.py backend/app/flea_market_routes.py
git commit -m "feat(backend): add rental request and rental lifecycle endpoints"
```

---

## Task 4: Flutter — Constants, Endpoints & Localization

**Files:**
- Modify: `link2ur/lib/core/constants/app_constants.dart:64-93`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart:129-162`
- Modify: `link2ur/lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

- [ ] **Step 1: Add rental constants to app_constants.dart**

After the existing flea market constants (around line 67):

```dart
// Listing types
static const String listingTypeSale = 'sale';
static const String listingTypeRental = 'rental';

// Rental units
static const String rentalUnitDay = 'day';
static const String rentalUnitWeek = 'week';
static const String rentalUnitMonth = 'month';

// Rental request statuses
static const String rentalRequestPending = 'pending';
static const String rentalRequestApproved = 'approved';
static const String rentalRequestRejected = 'rejected';
static const String rentalRequestCounterOffer = 'counter_offer';
static const String rentalRequestExpired = 'expired';

// Rental statuses
static const String rentalStatusActive = 'active';
static const String rentalStatusReturned = 'returned';
static const String rentalStatusOverdue = 'overdue';
static const String rentalStatusDisputed = 'disputed';

// Deposit statuses
static const String depositHeld = 'held';
static const String depositRefunded = 'refunded';
static const String depositForfeited = 'forfeited';
```

- [ ] **Step 2: Add rental API endpoints**

In `api_endpoints.dart`, after the existing flea market endpoints (around line 162):

```dart
// Flea market rental
static String fleaMarketRentalRequest(String id) => '/api/flea-market/items/$id/rental-request';
static String fleaMarketItemRentalRequests(String id) => '/api/flea-market/items/$id/rental-requests';
static String fleaMarketRentalRequestApprove(String requestId) => '/api/flea-market/rental-requests/$requestId/approve';
static String fleaMarketRentalRequestReject(String requestId) => '/api/flea-market/rental-requests/$requestId/reject';
static String fleaMarketRentalRequestCounterOffer(String requestId) => '/api/flea-market/rental-requests/$requestId/counter-offer';
static String fleaMarketRentalRequestRespondCounterOffer(String requestId) => '/api/flea-market/rental-requests/$requestId/respond-counter-offer';
static String fleaMarketRentalConfirmReturn(String rentalId) => '/api/flea-market/rentals/$rentalId/confirm-return';
static String fleaMarketRentalDetail(String rentalId) => '/api/flea-market/rentals/$rentalId';
static const String fleaMarketMyRentals = '/api/flea-market/my-rentals';
```

- [ ] **Step 3: Add localization keys to all 3 ARB files**

Add ~35 keys to each ARB file. English examples:

```json
"fleaMarketListingTypeSale": "For Sale",
"fleaMarketListingTypeRental": "For Rent",
"fleaMarketDeposit": "Deposit",
"fleaMarketRentalPrice": "Rental Price",
"fleaMarketRentalUnit": "Rental Unit",
"fleaMarketRentalUnitDay": "Day",
"fleaMarketRentalUnitWeek": "Week",
"fleaMarketRentalUnitMonth": "Month",
"fleaMarketPerDay": "/day",
"fleaMarketPerWeek": "/week",
"fleaMarketPerMonth": "/month",
"fleaMarketApplyToRent": "Apply to Rent",
"fleaMarketRentalDuration": "Rental Duration",
"fleaMarketDesiredTime": "Desired Start Time",
"fleaMarketDesiredTimeHint": "Please describe when you'd like to start renting",
"fleaMarketUsageDescription": "Usage Description",
"fleaMarketUsageDescriptionHint": "Briefly describe your intended use",
"fleaMarketRentalCostPreview": "Cost Preview",
"fleaMarketRentalSubtotal": "Rental Subtotal",
"fleaMarketRentalTotal": "Total",
"fleaMarketRentalRequestSent": "Rental request sent",
"fleaMarketRentalApproved": "Rental Approved",
"fleaMarketRentalRejected": "Rental Rejected",
"fleaMarketConfirmReturn": "Confirm Return",
"fleaMarketConfirmReturnMessage": "Confirm the item has been returned? The deposit will be refunded to the renter.",
"fleaMarketRentalActive": "Currently Rented",
"fleaMarketRentalReturned": "Returned",
"fleaMarketRentalOverdue": "Overdue",
"fleaMarketDepositHeld": "Deposit Held",
"fleaMarketDepositRefunded": "Deposit Refunded",
"fleaMarketMyRentals": "My Rentals",
"fleaMarketRentalDetail": "Rental Detail",
"fleaMarketRentalRequests": "Rental Requests",
"fleaMarketNoRentalRequests": "No rental requests yet",
"fleaMarketRentBadge": "Rent"
```

Add Chinese translations for `app_zh.arb` and Traditional Chinese for `app_zh_Hant.arb`.

- [ ] **Step 4: Run gen-l10n**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 5: Add error codes to error_localizer.dart**

Add cases for:
- `flea_market_error_rental_request_failed`
- `flea_market_error_approve_rental_failed`
- `flea_market_error_reject_rental_failed`
- `flea_market_error_counter_offer_rental_failed`
- `flea_market_error_confirm_return_failed`
- `flea_market_error_get_rental_detail_failed`
- `flea_market_error_get_rental_requests_failed`
- `flea_market_error_not_rental_item`
- `flea_market_error_cannot_rent_own_item`
- `flea_market_error_rental_payment_expired`

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/core/constants/ link2ur/lib/l10n/ link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat(flutter): add rental constants, endpoints, and localization"
```

---

## Task 5: Flutter — Data Models

**Files:**
- Modify: `link2ur/lib/data/models/flea_market.dart:7-46` (FleaMarketItem), `409-445` (CreateFleaMarketRequest)
- Create: `link2ur/lib/data/models/flea_market_rental.dart`

- [ ] **Step 1: Extend FleaMarketItem with rental fields**

Add to constructor (around line 46):
```dart
this.listingType = 'sale',
this.deposit,
this.rentalPrice,
this.rentalUnit,
this.activeRentals = const [],
this.userRentalRequestId,
this.userRentalRequestStatus,
```

Add fields:
```dart
final String listingType;
final double? deposit;
final double? rentalPrice;
final String? rentalUnit;
final List<FleaMarketRentalSummary> activeRentals;
final int? userRentalRequestId;
final String? userRentalRequestStatus;
```

Add getters:
```dart
bool get isRental => listingType == 'rental';
bool get hasActiveRentals => activeRentals.isNotEmpty;
```

Modify `isFree` getter (line 105):
```dart
bool get isFree => !isRental && price == 0;
```

Note: Rental price display (e.g., "£5/天") requires localized unit strings, so format in the **view layer** using `context.l10n.fleaMarketPerDay` etc., not as a model getter. Add a helper in the view:
```dart
String rentalPriceDisplay(FleaMarketItem item, AppLocalizations l10n) {
  final symbol = item.currency == 'EUR' ? '€' : '£';
  final price = item.rentalPrice?.toStringAsFixed(2) ?? '0.00';
  final unit = item.rentalUnit == 'day' ? l10n.fleaMarketPerDay
      : item.rentalUnit == 'week' ? l10n.fleaMarketPerWeek
      : l10n.fleaMarketPerMonth;
  return '$symbol$price$unit';
}
```

Update `fromJson`, `toJson`, `copyWith`, and `props` to include all new fields.

- [ ] **Step 2: Add FleaMarketRentalSummary inline class**

Small class for the `active_rentals` list in item response:
```dart
class FleaMarketRentalSummary extends Equatable {
  final int id;
  final String renterName;
  final String startDate;
  final String endDate;
  final String status;
  // fromJson, props
}
```

- [ ] **Step 3: Extend CreateFleaMarketRequest**

Add to constructor and `toJson` (around line 432):
```dart
final String listingType;
final double? deposit;
final double? rentalPrice;
final String? rentalUnit;
```

In `toJson`, conditionally include rental fields when `listingType == 'rental'`. Note: the existing `CreateFleaMarketRequest` has `required this.price`. For rental items, the Flutter side should still pass `price` (set to `rentalPrice` value) for backward compatibility — the backend also sets `price = rental_price`, but having it from the client avoids issues.

- [ ] **Step 4: Create flea_market_rental.dart**

Create `link2ur/lib/data/models/flea_market_rental.dart` with:

```dart
class FleaMarketRentalRequest extends Equatable {
  final int id;
  final String itemId;
  final String renterId;
  final String? renterName;
  final String? renterAvatar;
  final int rentalDuration;
  final String? desiredTime;
  final String? usageDescription;
  final double? proposedRentalPrice;
  final double? counterRentalPrice;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  // constructor, fromJson, toJson, props
}

class FleaMarketRental extends Equatable {
  final int id;
  final String itemId;
  final String renterId;
  final String? renterName;
  final String? renterAvatar;
  final int rentalDuration;
  final String rentalUnit;
  final double totalRent;
  final double depositAmount;
  final double totalPaid;
  final String currency;
  final String startDate;
  final String endDate;
  final String status;
  final String depositStatus;
  final String? returnedAt;
  final String? createdAt;
  // constructor, fromJson, toJson, props
}
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/data/models/
git commit -m "feat(flutter): add rental data models and extend FleaMarketItem"
```

---

## Task 6: Flutter — Repository Methods

**Files:**
- Modify: `link2ur/lib/data/repositories/flea_market_repository.dart`

- [ ] **Step 1: Add rental request methods**

Follow the pattern of existing methods (e.g., `sendPurchaseRequest` at line 195). Add:

```dart
Future<ApiResponse> submitRentalRequest(String itemId, {
  required int rentalDuration,
  String? desiredTime,
  String? usageDescription,
  double? proposedRentalPrice,
}) async {
  // POST to ApiEndpoints.fleaMarketRentalRequest(itemId)
  // Body: { rental_duration, desired_time, usage_description, proposed_rental_price }
  // Invalidate cache
}

Future<ApiResponse<List<FleaMarketRentalRequest>>> getItemRentalRequests(String itemId) async {
  // GET ApiEndpoints.fleaMarketItemRentalRequests(itemId)
  // Parse list of FleaMarketRentalRequest
}

Future<ApiResponse> approveRentalRequest(String requestId) async {
  // POST ApiEndpoints.fleaMarketRentalRequestApprove(requestId)
  // Returns payment info (AcceptPaymentData)
}

Future<ApiResponse> rejectRentalRequest(String requestId) async {
  // POST ApiEndpoints.fleaMarketRentalRequestReject(requestId)
}

Future<ApiResponse> counterOfferRental(String requestId, double counterPrice) async {
  // POST ApiEndpoints.fleaMarketRentalRequestCounterOffer(requestId)
  // Body: { counter_rental_price: counterPrice }
}

Future<ApiResponse> respondRentalCounterOffer(String requestId, bool accept) async {
  // POST ApiEndpoints.fleaMarketRentalRequestRespondCounterOffer(requestId)
  // Body: { accept: accept }
}

Future<ApiResponse> confirmReturn(String rentalId) async {
  // POST ApiEndpoints.fleaMarketRentalConfirmReturn(rentalId)
}

Future<ApiResponse<FleaMarketRental>> getRentalDetail(String rentalId) async {
  // GET ApiEndpoints.fleaMarketRentalDetail(rentalId)
}

Future<ApiResponse<List<FleaMarketRental>>> getMyRentals({int page = 1, int pageSize = 20}) async {
  // GET ApiEndpoints.fleaMarketMyRentals with pagination
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/repositories/flea_market_repository.dart
git commit -m "feat(flutter): add rental repository methods"
```

---

## Task 7: Flutter — Rental BLoC

**Files:**
- Create: `link2ur/lib/features/flea_market/bloc/flea_market_rental_bloc.dart`
- Modify: `link2ur/lib/features/flea_market/bloc/flea_market_bloc.dart:271-403`

- [ ] **Step 1: Create FleaMarketRentalBloc**

Create `link2ur/lib/features/flea_market/bloc/flea_market_rental_bloc.dart` with events, state, and bloc in one file (following the existing pattern where events/state are `part of` the bloc file).

**Events:**
```dart
abstract class FleaMarketRentalEvent extends Equatable {
  const FleaMarketRentalEvent();
}

class RentalSubmitRequest extends FleaMarketRentalEvent {
  final String itemId;
  final int rentalDuration;
  final String? desiredTime;
  final String? usageDescription;
  final double? proposedRentalPrice;  // renter can propose a different price

class RentalLoadRequests extends FleaMarketRentalEvent {
  final String itemId;
}

class RentalApproveRequest extends FleaMarketRentalEvent {
  final String requestId;
  final String itemId;
}

class RentalRejectRequest extends FleaMarketRentalEvent {
  final String requestId;
  final String itemId;
}

class RentalCounterOffer extends FleaMarketRentalEvent {
  final String requestId;
  final String itemId;
  final double counterPrice;
}

class RentalRespondCounterOffer extends FleaMarketRentalEvent {
  final String requestId;
  final String itemId;
  final bool accept;
}

class RentalConfirmReturn extends FleaMarketRentalEvent {
  final String rentalId;
}

class RentalLoadDetail extends FleaMarketRentalEvent {
  final String rentalId;
}

class RentalLoadMyRentals extends FleaMarketRentalEvent {
  final int page;
}

class RentalClearPaymentData extends FleaMarketRentalEvent {}
```

**State:**
```dart
class FleaMarketRentalState extends Equatable {
  final List<FleaMarketRentalRequest> rentalRequests;
  final bool isLoadingRequests;
  final FleaMarketRental? currentRental;
  final List<FleaMarketRental> myRentals;
  final bool isLoadingMyRentals;
  final bool hasMoreRentals;
  final int rentalsPage;
  final bool isSubmitting;
  final String? actionMessage;
  final String? errorMessage;
  final AcceptPaymentData? acceptPaymentData;
  // constructor with defaults, copyWith, props
}
```

**Bloc:** Register all event handlers, inject `FleaMarketRepository`. Import `AcceptPaymentData` from task detail bloc:
```dart
import '../../tasks/bloc/task_detail_bloc.dart' show AcceptPaymentData;
```

- [ ] **Step 2: Extend FleaMarketBloc with listingTypeFilter**

In `flea_market_bloc.dart`, add to state (around line 290):
```dart
final String listingTypeFilter; // 'all', 'sale', 'rental'
```

Add event:
```dart
class FleaMarketListingTypeFilterChanged extends FleaMarketEvent {
  final String listingType;
  const FleaMarketListingTypeFilterChanged(this.listingType);
  @override
  List<Object?> get props => [listingType];
}
```

In handler, update filter and reload items with `listing_type` parameter.

Update `copyWith` and `props`.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/flea_market/bloc/
git commit -m "feat(flutter): add FleaMarketRentalBloc and listing type filter"
```

---

## Task 8: Flutter — Publish & Edit Views

**Files:**
- Modify: `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart:307-342` (price section), `140-201` (submit)
- Modify: `link2ur/lib/features/flea_market/views/edit_flea_market_item_view.dart`

- [ ] **Step 1: Add listing type toggle to create view**

Above the price section (around line 307), add a `SegmentedButton` or toggle:

```dart
// Listing type selector
SegmentedButton<String>(
  segments: [
    ButtonSegment(value: 'sale', label: Text(context.l10n.fleaMarketListingTypeSale)),
    ButtonSegment(value: 'rental', label: Text(context.l10n.fleaMarketListingTypeRental)),
  ],
  selected: {_listingType},
  onSelectionChanged: (s) => setState(() => _listingType = s.first),
)
```

- [ ] **Step 2: Add conditional rental form fields**

When `_listingType == 'rental'`, replace the price field with:

```dart
// Deposit field
TextFormField(
  controller: _depositController,
  decoration: InputDecoration(labelText: context.l10n.fleaMarketDeposit),
  keyboardType: TextInputType.numberWithOptions(decimal: true),
  validator: (v) => /* required, > 0 */,
)

// Rental price field
TextFormField(
  controller: _rentalPriceController,
  decoration: InputDecoration(labelText: context.l10n.fleaMarketRentalPrice),
  keyboardType: TextInputType.numberWithOptions(decimal: true),
  validator: (v) => /* required, > 0 */,
)

// Rental unit dropdown
DropdownButtonFormField<String>(
  initialValue: _rentalUnit,
  items: [
    DropdownMenuItem(value: 'day', child: Text(context.l10n.fleaMarketRentalUnitDay)),
    DropdownMenuItem(value: 'week', child: Text(context.l10n.fleaMarketRentalUnitWeek)),
    DropdownMenuItem(value: 'month', child: Text(context.l10n.fleaMarketRentalUnitMonth)),
  ],
  onChanged: (v) => setState(() => _rentalUnit = v!),
)
```

- [ ] **Step 3: Update form submission**

In `_submitForm` (line 140), pass rental fields to `CreateFleaMarketRequest`:

```dart
final request = CreateFleaMarketRequest(
  // existing fields...
  listingType: _listingType,
  deposit: _listingType == 'rental' ? double.parse(_depositController.text) : null,
  rentalPrice: _listingType == 'rental' ? double.parse(_rentalPriceController.text) : null,
  rentalUnit: _listingType == 'rental' ? _rentalUnit : null,
);
```

- [ ] **Step 4: Update edit view**

In `edit_flea_market_item_view.dart`:
- Pre-fill rental fields from existing item
- Hide listing type toggle (not editable)
- Show rental fields if `item.isRental`, sale fields otherwise

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart link2ur/lib/features/flea_market/views/edit_flea_market_item_view.dart
git commit -m "feat(flutter): add rental fields to publish and edit views"
```

---

## Task 9: Flutter — List View Updates

**Files:**
- Modify: `link2ur/lib/features/flea_market/views/flea_market_view.dart:380-645` (card), `69-175` (filter), `594-636` (price)

- [ ] **Step 1: Add listing type filter**

Near the category filter section, add a listing type filter (3 chips or segmented button):
- 全部 | 出售 | 出租
- Dispatches `FleaMarketListingTypeFilterChanged` event

- [ ] **Step 2: Add rental badge to item card**

In the card widget (around line 464, near category label), add a conditional rental badge:

```dart
if (item.isRental)
  Positioned(
    top: 8,
    right: 8,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(context.l10n.fleaMarketRentBadge, style: TextStyle(color: Colors.white, fontSize: 10)),
    ),
  ),
```

- [ ] **Step 3: Update price display**

In the price display section (around line 597), use rental format:

```dart
Text(
  item.isRental ? item.rentalPriceDisplay : (item.isFree ? context.l10n.fleaMarketFree : item.priceDisplay),
  // existing style
)
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/flea_market/views/flea_market_view.dart
git commit -m "feat(flutter): add rental badge, price format, and listing type filter to list view"
```

---

## Task 10: Flutter — Detail View & Rental Request Sheet

**Files:**
- Modify: `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart:807-912` (buyer CTA), price area
- Create: `link2ur/lib/features/flea_market/views/rental_request_sheet.dart`

- [ ] **Step 1: Create rental request bottom sheet**

Create `rental_request_sheet.dart` — a `StatefulWidget` bottom sheet with:

```dart
class RentalRequestSheet extends StatefulWidget {
  final FleaMarketItem item;
  final FleaMarketRentalBloc rentalBloc;
  // show() static method
}
```

Form fields:
- Rental duration: `TextFormField` (number) + unit label from item
- Desired time: `TextFormField` with hint
- Usage description: `TextFormField` (multiline) with hint
- Proposed rental price: `TextFormField` (optional, number) — "如果你想议价，可以填写期望租金单价"
- Cost preview: calculated rental subtotal (using item price or proposed price) + deposit = total
- Submit button → dispatches `RentalSubmitRequest` (with optional `proposedRentalPrice`)

- [ ] **Step 2: Update detail view — price area for rental items**

When `item.isRental`, replace the simple price display with:

```dart
Column(children: [
  Row(children: [
    Text('${context.l10n.fleaMarketRentalPrice}: ${item.rentalPriceDisplay}'),
  ]),
  Row(children: [
    Text('${context.l10n.fleaMarketDeposit}: ${item.currencySymbol}${item.deposit?.toStringAsFixed(2)}'),
  ]),
])
```

- [ ] **Step 3: Update detail view — buyer CTA button**

In `_buildBuyerCTAButton` (line 807), for rental items:
- Always show "申请租用" button (regardless of active rentals)
- If `item.hasActiveRentals`, show a hint text like "当前出租中，你可以申请未来的时间段"
- On tap → show `RentalRequestSheet`
- If user has a pending request (`item.userRentalRequestStatus == 'pending'`), show "申请已提交" disabled state

- [ ] **Step 4: Update detail view — seller rental request management**

For the item owner, when `item.isRental`:
- Provide `FleaMarketRentalBloc` via `BlocProvider` at page level
- Load rental requests on page mount
- Display rental requests list (similar to purchase requests display)
- Each request shows: renter name, duration, desired time, usage, status
- Action buttons: Approve / Reject / Counter Offer
- Show active rentals list with "Confirm Return" button for each

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/flea_market/views/rental_request_sheet.dart link2ur/lib/features/flea_market/views/flea_market_detail_view.dart
git commit -m "feat(flutter): add rental request sheet and update detail view for rental items"
```

---

## Task 11: Flutter — Rental Detail & My Rentals Views

**Files:**
- Create: `link2ur/lib/features/flea_market/views/rental_detail_view.dart`
- Create: `link2ur/lib/features/flea_market/views/my_rentals_view.dart`
- Modify: `link2ur/lib/core/router/app_routes.dart`
- Modify: `link2ur/lib/core/router/routes/flea_market_routes.dart`

- [ ] **Step 1: Create rental detail view**

```dart
class RentalDetailView extends StatelessWidget {
  final String rentalId;
}
```

Shows:
- Item info (thumbnail, title)
- Rental info: duration, unit, start/end dates, status
- Financial: rent amount, deposit, total paid
- Deposit status (held/refunded/forfeited)
- For owner: "Confirm Return" button (if status is active/overdue)
- Timeline: created → active → returned/overdue

- [ ] **Step 2: Create my rentals view**

```dart
class MyRentalsView extends StatelessWidget {}
```

Shows:
- List of user's rentals (as renter)
- Each card: item thumbnail, title, dates, status badge, amounts
- Tap → navigate to rental detail
- Pull-to-refresh, pagination

- [ ] **Step 3: Add routes**

In `app_routes.dart`:
```dart
static const String fleaMarketRentalDetail = '/flea-market/rental/:id';
static const String fleaMarketMyRentals = '/flea-market/my-rentals';
```

In `flea_market_routes.dart`, add:
```dart
GoRoute(
  path: AppRoutes.fleaMarketRentalDetail,
  name: 'fleaMarketRentalDetail',
  pageBuilder: (context, state) {
    final id = state.pathParameters['id'] ?? '';
    return platformDetailPage(context, key: state.pageKey, child: RentalDetailView(rentalId: id));
  },
),
GoRoute(
  path: AppRoutes.fleaMarketMyRentals,
  name: 'fleaMarketMyRentals',
  builder: (context, state) => const MyRentalsView(),
),
```

- [ ] **Step 4: Add navigation extensions**

In the GoRouter extensions file, add:
```dart
void goToRentalDetail(String rentalId) => go('/flea-market/rental/$rentalId');
void goToMyRentals() => go('/flea-market/my-rentals');
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/flea_market/views/rental_detail_view.dart link2ur/lib/features/flea_market/views/my_rentals_view.dart link2ur/lib/core/router/
git commit -m "feat(flutter): add rental detail view, my rentals view, and routes"
```

---

## Task 12: Integration & Verification

- [ ] **Step 1: Run flutter analyze**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

Fix any warnings or errors.

- [ ] **Step 2: Verify backend starts**

```bash
cd backend
python -m uvicorn app.main:app --reload
```

Test endpoints manually or via curl.

- [ ] **Step 3: Run existing tests**

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test
```

Ensure no regressions in existing flea market tests.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "fix: resolve any analysis issues from rental feature"
```
