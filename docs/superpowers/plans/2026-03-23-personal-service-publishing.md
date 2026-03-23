# Personal Service Publishing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow all users to publish personal services alongside existing expert services.

**Architecture:** Extend the existing `TaskExpertService` table with `service_type`, `user_id`, and `pricing_type` columns. New `/api/services/` endpoints for personal service CRUD. New Flutter feature module for personal service management. Unified public browse endpoint merges both types.

**Tech Stack:** FastAPI + SQLAlchemy async (backend), Flutter + BLoC (frontend), existing Dio-based ApiService

**Spec:** `docs/superpowers/specs/2026-03-23-personal-service-publishing-design.md`

---

### Task 1: Database model changes

**Files:**
- Modify: `backend/app/models.py:1585-1621` (TaskExpertService)
- Modify: `backend/app/models.py:1695-1734` (ServiceApplication)

- [ ] **Step 1: Add columns to TaskExpertService model**

In `backend/app/models.py`, add to the `TaskExpertService` class after line 1590:

```python
# After expert_id line, make expert_id nullable:
# Change: expert_id = Column(String(8), ForeignKey("task_experts.id", ondelete="CASCADE"), nullable=False)
# To:
expert_id = Column(String(8), ForeignKey("task_experts.id", ondelete="CASCADE"), nullable=True)

# Add new columns after expert_id:
service_type = Column(String(20), nullable=False, default="expert", server_default="expert")  # 'personal' | 'expert'
user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)  # owner for personal services
pricing_type = Column(String(20), nullable=False, default="fixed", server_default="fixed")  # 'fixed' | 'hourly' | 'negotiable'
```

Add a relationship and helper property at the end of the class:

```python
# Relationship for personal service owner
owner = relationship("User", foreign_keys=[user_id])

@property
def owner_user_id(self):
    """Resolve owner user ID regardless of service type.

    For expert services: expert_id is used, which equals users.id because
    TaskExpert.id is set to user.id on expert approval (see admin_task_expert_routes.py).
    For personal services: user_id is the direct FK to users.id.
    """
    if self.service_type == "personal":
        return self.user_id
    return self.expert_id
```

- [ ] **Step 2: Add columns to ServiceApplication model**

In `backend/app/models.py`, modify the `ServiceApplication` class:

```python
# Change expert_id to nullable:
expert_id = Column(String(8), ForeignKey("task_experts.id", ondelete="CASCADE"), nullable=True)

# Add after expert_id:
service_owner_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
```

- [ ] **Step 3: Create migration SQL**

Since alembic is not set up, create a manual migration script at `backend/migrations/add_personal_services.sql`:

```sql
-- Add columns to task_expert_services
ALTER TABLE task_expert_services
  ALTER COLUMN expert_id DROP NOT NULL;

ALTER TABLE task_expert_services
  ADD COLUMN IF NOT EXISTS service_type VARCHAR(20) NOT NULL DEFAULT 'expert',
  ADD COLUMN IF NOT EXISTS user_id VARCHAR(36) REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS pricing_type VARCHAR(20) NOT NULL DEFAULT 'fixed';

CREATE INDEX IF NOT EXISTS idx_task_expert_services_type_status
  ON task_expert_services(service_type, status);

CREATE INDEX IF NOT EXISTS idx_task_expert_services_user_id
  ON task_expert_services(user_id);

-- Add columns to service_applications
ALTER TABLE service_applications
  ALTER COLUMN expert_id DROP NOT NULL;

ALTER TABLE service_applications
  ADD COLUMN IF NOT EXISTS service_owner_id VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL;

-- Backfill service_owner_id for existing applications (join through task_experts for clarity)
UPDATE service_applications sa
SET service_owner_id = te.id
FROM task_experts te
WHERE sa.expert_id = te.id AND sa.service_owner_id IS NULL;
```

- [ ] **Step 4: Verify model changes load without errors**

Run: `cd backend && python -c "from app.models import TaskExpertService, ServiceApplication; print('OK')"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add backend/app/models.py backend/migrations/add_personal_services.sql
git commit -m "feat: add personal service columns to TaskExpertService and ServiceApplication"
```

---

### Task 2: Backend schemas for personal services

**Files:**
- Modify: `backend/app/schemas.py` (add new schemas after line ~2251)

- [ ] **Step 1: Add PersonalServiceCreate schema**

In `backend/app/schemas.py`, add after the existing `TaskExpertServiceCreate`:

```python
class PersonalServiceCreate(BaseModel):
    service_name: str = Field(..., max_length=100)
    description: str = Field(..., max_length=2000)
    base_price: condecimal(gt=0, max_digits=12, decimal_places=2)
    currency: str = Field(default="GBP", max_length=10)
    pricing_type: str = Field(default="fixed", pattern="^(fixed|hourly|negotiable)$")
    images: Optional[conlist(str, max_length=6)] = None

class PersonalServiceUpdate(BaseModel):
    service_name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None, max_length=2000)
    base_price: Optional[condecimal(gt=0, max_digits=12, decimal_places=2)] = None
    currency: Optional[str] = Field(None, max_length=10)
    pricing_type: Optional[str] = Field(None, pattern="^(fixed|hourly|negotiable)$")
    images: Optional[conlist(str, max_length=6)] = None

class ServiceBrowseItem(BaseModel):
    id: str
    service_name: str
    description: str
    base_price: float
    currency: str
    pricing_type: str
    service_type: str  # 'personal' | 'expert'
    is_expert_verified: bool
    status: str
    images: Optional[List[str]]
    owner_id: str
    owner_name: str
    owner_avatar: Optional[str]
    owner_rating: Optional[float]
    created_at: Optional[str]

    class Config:
        from_attributes = True
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat: add PersonalServiceCreate, PersonalServiceUpdate, ServiceBrowseItem schemas"
```

---

### Task 3: Personal service CRUD endpoints

**Files:**
- Create: `backend/app/personal_service_routes.py`
- Modify: `backend/app/main.py:415-416` (register router)

- [ ] **Step 1: Create personal service router**

Create `backend/app/personal_service_routes.py`:

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.auth import get_current_user_secure_async_csrf
from app.database import get_async_db_dependency

personal_service_router = APIRouter(
    prefix="/api/services",
    tags=["personal-services"],
)

MAX_PERSONAL_SERVICES_PER_USER = 10


@personal_service_router.post("/me", status_code=status.HTTP_201_CREATED)
async def create_personal_service(
    data: schemas.PersonalServiceCreate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    # Rate limit check
    count_result = await db.execute(
        select(func.count(models.TaskExpertService.id)).where(
            models.TaskExpertService.user_id == current_user.id,
            models.TaskExpertService.service_type == "personal",
            models.TaskExpertService.status.in_(["active", "pending"]),
        )
    )
    count = count_result.scalar() or 0
    if count >= MAX_PERSONAL_SERVICES_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"最多创建 {MAX_PERSONAL_SERVICES_PER_USER} 个个人服务",
        )

    # id is Integer auto-increment — do NOT set it manually
    new_service = models.TaskExpertService(
        service_type="personal",
        user_id=current_user.id,
        expert_id=None,
        service_name=data.service_name,
        description=data.description,
        base_price=data.base_price,
        currency=data.currency,
        pricing_type=data.pricing_type,
        images=data.images or [],
        status="active",
    )
    db.add(new_service)
    await db.commit()
    await db.refresh(new_service)
    return {"message": "服务发布成功", "service_id": new_service.id}


@personal_service_router.get("/me")
async def list_my_personal_services(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(
        select(models.TaskExpertService)
        .where(
            models.TaskExpertService.user_id == current_user.id,
            models.TaskExpertService.service_type == "personal",
        )
        .order_by(models.TaskExpertService.created_at.desc())
    )
    services = result.scalars().all()
    return [
        {
            "id": s.id,
            "service_name": s.service_name,
            "description": s.description,
            "base_price": float(s.base_price) if s.base_price else 0,
            "currency": s.currency,
            "pricing_type": s.pricing_type or "fixed",
            "images": s.images or [],
            "status": s.status,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        }
        for s in services
    ]


@personal_service_router.put("/me/{service_id}")
async def update_personal_service(
    service_id: str,
    data: schemas.PersonalServiceUpdate,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.service_type == "personal",
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权修改此服务")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(service, key, value)

    await db.commit()
    return {"message": "服务更新成功"}


@personal_service_router.delete("/me/{service_id}")
async def delete_personal_service(
    service_id: str,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    result = await db.execute(
        select(models.TaskExpertService).where(
            models.TaskExpertService.id == service_id,
            models.TaskExpertService.service_type == "personal",
        )
    )
    service = result.scalar_one_or_none()
    if not service:
        raise HTTPException(status_code=404, detail="服务不存在")
    if service.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权删除此服务")

    await db.delete(service)
    await db.commit()
    return {"message": "服务已删除"}
```

- [ ] **Step 2: Register router in main.py**

In `backend/app/main.py`, after line 416 add:

```python
from app.personal_service_routes import personal_service_router
app.include_router(personal_service_router)
```

- [ ] **Step 3: Verify server starts**

Run: `cd backend && python -c "from app.personal_service_routes import personal_service_router; print('OK')"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add backend/app/personal_service_routes.py backend/app/main.py
git commit -m "feat: add personal service CRUD endpoints"
```

---

### Task 4: Public service browse endpoint

**Files:**
- Create: `backend/app/service_browse_routes.py`
- Modify: `backend/app/main.py` (register router)

- [ ] **Step 1: Create browse router**

Create `backend/app/service_browse_routes.py`:

```python
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, case, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.database import get_async_db_dependency

service_browse_router = APIRouter(
    prefix="/api/services",
    tags=["service-browse"],
)


@service_browse_router.get("/browse")
async def browse_services(
    type: str = Query("all", pattern="^(all|expert|personal)$"),
    category: str = Query(None, max_length=50),
    q: str = Query(None, max_length=100),
    sort: str = Query("recommended", pattern="^(recommended|newest|price_asc|price_desc)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    query = select(models.TaskExpertService).where(
        models.TaskExpertService.status == "active",
    )

    # Type filter
    if type == "expert":
        query = query.where(models.TaskExpertService.service_type == "expert")
    elif type == "personal":
        query = query.where(models.TaskExpertService.service_type == "personal")

    # Text search
    if q:
        search = f"%{q}%"
        query = query.where(
            or_(
                models.TaskExpertService.service_name.ilike(search),
                models.TaskExpertService.description.ilike(search),
            )
        )

    # Sort
    if sort == "recommended":
        # Expert services first, then by created_at
        query = query.order_by(
            case(
                (models.TaskExpertService.service_type == "expert", 0),
                else_=1,
            ),
            models.TaskExpertService.created_at.desc(),
        )
    elif sort == "newest":
        query = query.order_by(models.TaskExpertService.created_at.desc())
    elif sort == "price_asc":
        query = query.order_by(models.TaskExpertService.base_price.asc())
    elif sort == "price_desc":
        query = query.order_by(models.TaskExpertService.base_price.desc())

    # Pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    # Count total for pagination
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    result = await db.execute(query)
    services = result.scalars().all()

    # Batch-load owner user info (avoid N+1)
    owner_ids = list({s.owner_user_id for s in services if s.owner_user_id})
    owners_map = {}
    if owner_ids:
        owners_result = await db.execute(
            select(models.User).where(models.User.id.in_(owner_ids))
        )
        for u in owners_result.scalars().all():
            owners_map[u.id] = u

    items = []
    for s in services:
        owner = owners_map.get(s.owner_user_id)
        items.append({
            "id": s.id,
            "service_name": s.service_name,
            "description": s.description,
            "base_price": float(s.base_price) if s.base_price else 0,
            "currency": s.currency or "GBP",
            "pricing_type": s.pricing_type or "fixed",
            "service_type": s.service_type or "expert",
            "is_expert_verified": s.service_type == "expert",
            "status": s.status,
            "images": s.images or [],
            "owner_id": s.owner_user_id or "",
            "owner_name": owner.name if owner else "Unknown",
            "owner_avatar": owner.avatar if owner else None,
            "owner_rating": float(owner.avg_rating) if owner and owner.avg_rating else None,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}
```

- [ ] **Step 2: Register in main.py**

Add after previous router registration:

```python
from app.service_browse_routes import service_browse_router
app.include_router(service_browse_router)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/service_browse_routes.py backend/app/main.py
git commit -m "feat: add public service browse endpoint with type filter and sort"
```

---

### Task 5: Update apply_for_service for personal services

**Files:**
- Modify: `backend/app/task_expert_routes.py:2579-2628`

- [ ] **Step 1: Update self-apply guard and application creation**

In `backend/app/task_expert_routes.py`, find the `apply_for_service` endpoint (line ~2579). Update:

1. Change the self-apply check from `service.expert_id == current_user.id` to `service.owner_user_id == current_user.id`
2. In the `ServiceApplication` creation, set `service_owner_id = service.owner_user_id` and make `expert_id = service.expert_id` (nullable for personal)

Find the line that creates the application (around line 2691):
```python
# Change from:
# expert_id=service.expert_id,
# To:
expert_id=service.expert_id,  # None for personal services
service_owner_id=service.owner_user_id,
```

Find the self-apply guard (around line 2613):
```python
# Change from:
# if service.expert_id == current_user.id:
# To:
if service.owner_user_id == current_user.id:
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/task_expert_routes.py
git commit -m "fix: update apply_for_service to support personal services"
```

---

### Task 6: Flutter — API endpoints and model updates

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart:164-220`
- Modify: `link2ur/lib/data/models/task_expert.dart:305-428`

- [ ] **Step 1: Add personal service endpoints**

In `link2ur/lib/core/constants/api_endpoints.dart`, add after the task expert endpoints section:

```dart
// Personal Services
static const String myPersonalServices = '$baseUrl/services/me';
static String myPersonalServiceById(String id) => '$baseUrl/services/me/$id';
static const String browseServices = '$baseUrl/services/browse';
```

- [ ] **Step 2: Update TaskExpertService model**

In `link2ur/lib/data/models/task_expert.dart`, update the `TaskExpertService` class:

Add fields after `expertId`:
```dart
final String serviceType; // 'personal' | 'expert'
final String? userId;
final String pricingType; // 'fixed' | 'hourly' | 'negotiable'
final bool isExpertVerified;
final String? ownerName;
final String? ownerAvatar;
final double? ownerRating;
```

Update constructor to include these fields.

Update `fromJson` (line ~379) to parse:
```dart
serviceType: json['service_type']?.toString() ?? 'expert',
userId: json['user_id']?.toString(),
pricingType: json['pricing_type']?.toString() ?? 'fixed',
isExpertVerified: json['is_expert_verified'] == true,
ownerName: json['owner_name']?.toString(),
ownerAvatar: json['owner_avatar']?.toString(),
ownerRating: (json['owner_rating'] as num?)?.toDouble(),
```

Update `props` list to include new fields.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/models/task_expert.dart
git commit -m "feat: add personal service API endpoints and model fields"
```

---

### Task 7: Flutter — Personal service repository

**Files:**
- Create: `link2ur/lib/data/repositories/personal_service_repository.dart`

- [ ] **Step 1: Create repository**

Create `link2ur/lib/data/repositories/personal_service_repository.dart`:

```dart
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class PersonalServiceRepository {
  PersonalServiceRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  Future<Map<String, dynamic>> createService(Map<String, dynamic> data) async {
    final response = await _apiService.post(
      ApiEndpoints.myPersonalServices,
      data: data,
    );
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getMyServices() async {
    final response = await _apiService.get(ApiEndpoints.myPersonalServices);
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _apiService.put(
      ApiEndpoints.myPersonalServiceById(id),
      data: data,
    );
  }

  Future<void> deleteService(String id) async {
    await _apiService.delete(ApiEndpoints.myPersonalServiceById(id));
  }

  Future<Map<String, dynamic>> browseServices({
    String type = 'all',
    String? query,
    String sort = 'recommended',
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'type': type,
      'sort': sort,
      'page': page,
      'page_size': pageSize,
    };
    if (query != null && query.isNotEmpty) params['q'] = query;

    final response = await _apiService.get(
      ApiEndpoints.browseServices,
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data);
  }
}
```

- [ ] **Step 2: Register in app_providers.dart**

In `link2ur/lib/app_providers.dart`, add import and provider:

```dart
import 'data/repositories/personal_service_repository.dart';

// In MultiRepositoryProvider children list (after TaskExpertRepository):
RepositoryProvider<PersonalServiceRepository>(
  create: (_) => PersonalServiceRepository(apiService: apiService),
),
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/repositories/personal_service_repository.dart link2ur/lib/app_providers.dart
git commit -m "feat: add PersonalServiceRepository and register in providers"
```

---

### Task 8: Flutter — Personal service BLoC

**Files:**
- Create: `link2ur/lib/features/personal_service/bloc/personal_service_bloc.dart`

- [ ] **Step 1: Create BLoC with events and states**

Create `link2ur/lib/features/personal_service/bloc/personal_service_bloc.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/personal_service_repository.dart';

// ==================== Events ====================
abstract class PersonalServiceEvent extends Equatable {
  const PersonalServiceEvent();
  @override
  List<Object?> get props => [];
}

class PersonalServiceLoadRequested extends PersonalServiceEvent {
  const PersonalServiceLoadRequested();
}

class PersonalServiceCreateRequested extends PersonalServiceEvent {
  const PersonalServiceCreateRequested(this.data);
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [data];
}

class PersonalServiceUpdateRequested extends PersonalServiceEvent {
  const PersonalServiceUpdateRequested(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [id, data];
}

class PersonalServiceDeleteRequested extends PersonalServiceEvent {
  const PersonalServiceDeleteRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

// ==================== State ====================
enum PersonalServiceStatus { initial, loading, loaded, error }

class PersonalServiceState extends Equatable {
  const PersonalServiceState({
    this.status = PersonalServiceStatus.initial,
    this.services = const [],
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final PersonalServiceStatus status;
  final List<Map<String, dynamic>> services;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  PersonalServiceState copyWith({
    PersonalServiceStatus? status,
    List<Map<String, dynamic>>? services,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return PersonalServiceState(
      status: status ?? this.status,
      services: services ?? this.services,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, services, errorMessage, isSubmitting, actionMessage];
}

// ==================== BLoC ====================
class PersonalServiceBloc extends Bloc<PersonalServiceEvent, PersonalServiceState> {
  PersonalServiceBloc({required PersonalServiceRepository repository})
      : _repository = repository,
        super(const PersonalServiceState()) {
    on<PersonalServiceLoadRequested>(_onLoad);
    on<PersonalServiceCreateRequested>(_onCreate);
    on<PersonalServiceUpdateRequested>(_onUpdate);
    on<PersonalServiceDeleteRequested>(_onDelete);
  }

  final PersonalServiceRepository _repository;

  Future<void> _onLoad(
    PersonalServiceLoadRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(status: PersonalServiceStatus.loading));
    try {
      final services = await _repository.getMyServices();
      emit(state.copyWith(status: PersonalServiceStatus.loaded, services: services));
    } catch (e) {
      emit(state.copyWith(
        status: PersonalServiceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreate(
    PersonalServiceCreateRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.createService(event.data);
      emit(state.copyWith(isSubmitting: false, actionMessage: 'service_created'));
      add(const PersonalServiceLoadRequested());
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdate(
    PersonalServiceUpdateRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.updateService(event.id, event.data);
      emit(state.copyWith(isSubmitting: false, actionMessage: 'service_updated'));
      add(const PersonalServiceLoadRequested());
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onDelete(
    PersonalServiceDeleteRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.deleteService(event.id);
      emit(state.copyWith(isSubmitting: false, actionMessage: 'service_deleted'));
      add(const PersonalServiceLoadRequested());
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/personal_service/bloc/personal_service_bloc.dart
git commit -m "feat: add PersonalServiceBloc with CRUD events"
```

---

### Task 9: Flutter — Personal service list view (My Services page)

**Files:**
- Create: `link2ur/lib/features/personal_service/views/my_services_view.dart`

- [ ] **Step 1: Create my services list page**

Create `link2ur/lib/features/personal_service/views/my_services_view.dart` — a standard list view following the existing pattern from `profile_menu_widgets.dart`. Shows user's personal services with status, price, edit/delete actions, and a FAB to create new service. Uses `BlocProvider` to create `PersonalServiceBloc` at page level. Follows existing design system: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`.

Key elements:
- `BlocProvider<PersonalServiceBloc>` wrapping the page
- `BlocBuilder` for list state (loading skeleton, error, empty, loaded)
- Each service card: service name, price, status pill, edit/delete buttons
- FAB: "发布服务" button → navigates to create form
- Pull-to-refresh via `RefreshIndicator`

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/personal_service/views/my_services_view.dart
git commit -m "feat: add My Services list view"
```

---

### Task 10: Flutter — Personal service create/edit form

**Files:**
- Create: `link2ur/lib/features/personal_service/views/personal_service_form_view.dart`

- [ ] **Step 1: Create service form page**

Create `link2ur/lib/features/personal_service/views/personal_service_form_view.dart` — a form with 4 fields following existing form patterns (e.g., `edit_profile_view.dart`):

- Service name: `TextFormField` with validation
- Description: `TextFormField` multiline with validation
- Price: `TextFormField` with `£` prefix + pricing_type `SegmentedButton` (固定价/时薪/面议)
- Images: image picker grid (reuse existing image upload pattern)

Supports both create and edit modes (pass optional `serviceData` map). Dispatches `PersonalServiceCreateRequested` or `PersonalServiceUpdateRequested` on submit.

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/personal_service/views/personal_service_form_view.dart
git commit -m "feat: add personal service create/edit form"
```

---

### Task 11: Add l10n keys (must come before UI integration)

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add localization keys to all 3 ARB files**

Add to each ARB file:

```json
"profileMyServices": "My Services" / "我的服务" / "我的服務",
"profileMyServicesSubtitle": "Manage your published services" / "管理已发布的服务" / "管理已發佈的服務",
"personalServiceCreate": "Publish Service" / "发布服务" / "發佈服務",
"personalServiceName": "Service Name" / "服务名称" / "服務名稱",
"personalServiceDescription": "Service Description" / "服务描述" / "服務描述",
"personalServicePrice": "Price" / "价格" / "價格",
"personalServiceImages": "Images" / "图片" / "圖片",
"personalServicePricingFixed": "Fixed" / "固定价" / "固定價",
"personalServicePricingHourly": "Hourly" / "时薪" / "時薪",
"personalServicePricingNegotiable": "Negotiable" / "面议" / "面議",
"personalServiceCreated": "Service published!" / "服务发布成功！" / "服務發佈成功！",
"personalServiceUpdated": "Service updated" / "服务已更新" / "服務已更新",
"personalServiceDeleted": "Service deleted" / "服务已删除" / "服務已刪除",
"personalServiceLimitReached": "Maximum 10 services reached" / "最多发布10个服务" / "最多發佈10個服務",
"publishService": "Publish Service" / "发布服务" / "發佈服務",
"publishServiceDesc": "Offer your skills" / "展示你的技能" / "展示你的技能"
```

- [ ] **Step 2: Generate l10n**

Run: `cd link2ur && flutter gen-l10n`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat: add l10n keys for personal service feature"
```

---

### Task 12: Flutter — Route and menu integration

**Files:**
- Create: `link2ur/lib/core/router/routes/personal_service_routes.dart`
- Modify: `link2ur/lib/core/router/app_router.dart`
- Modify: `link2ur/lib/features/profile/views/profile_menu_widgets.dart:42-91`
- Modify: `link2ur/lib/features/publish/views/publish_view.dart:645-724`

- [ ] **Step 1: Add routes**

Create `link2ur/lib/core/router/routes/personal_service_routes.dart` (following existing pattern in `task_expert_routes.dart`). Then import and add it to the routes list in `app_router.dart` (NOT inside the expert guard):

```dart
GoRoute(
  path: '/services/my',
  builder: (context, state) => const MyServicesView(),
),
GoRoute(
  path: '/services/create',
  builder: (context, state) => const PersonalServiceFormView(),
),
GoRoute(
  path: '/services/edit/:id',
  builder: (context, state) {
    final data = state.extra as Map<String, dynamic>?;
    return PersonalServiceFormView(serviceData: data);
  },
),
```

Add imports for the new views.

- [ ] **Step 2: Add "我的服务" to profile menu**

In `link2ur/lib/features/profile/views/profile_menu_widgets.dart`, in `_buildMyContentSection` after the "我的任务" row (line ~48), add:

```dart
_profileDivider(isDark),
_ProfileRow(
  icon: Icons.home_repair_service,
  title: context.l10n.profileMyServices,  // Add l10n key
  subtitle: context.l10n.profileMyServicesSubtitle,  // Add l10n key
  color: AppColors.accent,
  onTap: () => context.push('/services/my'),
),
```

- [ ] **Step 3: Add "发布服务" to publish sheet**

In `link2ur/lib/features/publish/views/publish_view.dart`, in the publish type picker (line ~645), add a new type to the enum and grid:

Add to the `_PublishType` enum (or equivalent):
```dart
service,  // New type
```

Add a new grid item for "发布服务" in `_buildTypePicker`. **Important:** also add a `case _PublishType.service:` branch to the switch in `_buildFormHeader` (line ~953) and any other switch on `_PublishType` — for `service` type, navigate to `/services/create` via `context.push` and close the publish sheet, instead of building an inline form like the other types.

- [ ] **Step 4: Verify app compiles**

Run: `cd link2ur && flutter analyze`
Expected: No errors related to personal service files

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/core/router/app_router.dart link2ur/lib/features/profile/views/profile_menu_widgets.dart link2ur/lib/features/publish/views/publish_view.dart
git commit -m "feat: integrate personal service routes, profile menu, and publish sheet"
```

---

### Task 13: Run migration on database

- [ ] **Step 1: Run migration SQL on staging database**

Execute `backend/migrations/add_personal_services.sql` against the staging database (Railway).

- [ ] **Step 2: Verify migration**

```sql
SELECT column_name, is_nullable FROM information_schema.columns
WHERE table_name = 'task_expert_services'
AND column_name IN ('service_type', 'user_id', 'pricing_type', 'expert_id');
```

Expected: `service_type` NOT NULL default 'expert', `user_id` nullable, `pricing_type` NOT NULL default 'fixed', `expert_id` nullable.

- [ ] **Step 3: Verify existing services unaffected**

```sql
SELECT id, service_type, expert_id, status FROM task_expert_services LIMIT 5;
```

Expected: All existing rows have `service_type='expert'` and valid `expert_id`.
