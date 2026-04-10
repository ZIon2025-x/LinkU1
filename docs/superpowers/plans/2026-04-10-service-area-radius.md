# Service Area / Radius Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let experts set a base address + service radius on their team, with services/activities inheriting by default, and show "outside service area" soft warnings to users.

**Architecture:** Add `latitude`, `longitude`, `service_radius_km` to Expert model (team-level base). Add `service_radius_km` to TaskExpertService. Add `latitude`, `longitude`, `service_radius_km` to Activity. Services/activities fallback to team values when their own are null. Browse API returns `distance_km` + `within_service_area`.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/BLoC (frontend), PostgreSQL (migration)

**Spec:** `docs/superpowers/specs/2026-04-10-service-area-radius-design.md`

---

### Task 1: Database Migration

**Files:**
- Create: `backend/migrations/195_add_service_radius.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- 195_add_service_radius.sql
-- Expert team: base address + default radius
ALTER TABLE experts ADD COLUMN latitude DECIMAL(10, 8) DEFAULT NULL;
ALTER TABLE experts ADD COLUMN longitude DECIMAL(11, 8) DEFAULT NULL;
ALTER TABLE experts ADD COLUMN service_radius_km INTEGER DEFAULT NULL;

-- Service: per-service radius override (lat/lng already exist)
ALTER TABLE task_expert_services ADD COLUMN service_radius_km INTEGER DEFAULT NULL;

-- Activity: coordinates + radius (only has text location today)
ALTER TABLE activities ADD COLUMN latitude DECIMAL(10, 8) DEFAULT NULL;
ALTER TABLE activities ADD COLUMN longitude DECIMAL(11, 8) DEFAULT NULL;
ALTER TABLE activities ADD COLUMN service_radius_km INTEGER DEFAULT NULL;
```

- [ ] **Step 2: Run migration against dev DB**

```bash
cd backend
python run_migrations.py
```

Expected: Migration 195 applies successfully, no errors.

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/195_add_service_radius.sql
git commit -m "feat: add service_radius_km to experts, services, activities (migration 195)"
```

---

### Task 2: Backend Models

**Files:**
- Modify: `backend/app/models_expert.py:34-94` (Expert class)
- Modify: `backend/app/models.py:1572-1659` (TaskExpertService class)
- Modify: `backend/app/models.py:2118-2217` (Activity class)

- [ ] **Step 1: Add fields to Expert model**

In `backend/app/models_expert.py`, add after line 76 (`user_level` field), before `created_at`:

```python
    # 基地地址 + 默认服务半径 (migration 195)
    latitude = Column(DECIMAL(10, 8), nullable=True)
    longitude = Column(DECIMAL(11, 8), nullable=True)
    service_radius_km = Column(Integer, nullable=True)
```

- [ ] **Step 2: Add field to TaskExpertService model**

In `backend/app/models.py`, in the `TaskExpertService` class, add after the existing `longitude` field (line 1587):

```python
    service_radius_km = Column(Integer, nullable=True)  # null = inherit from expert team
```

- [ ] **Step 3: Add fields to Activity model**

In `backend/app/models.py`, in the `Activity` class, add after `location` field (line 2134):

```python
    latitude = Column(DECIMAL(10, 8), nullable=True)
    longitude = Column(DECIMAL(11, 8), nullable=True)
    service_radius_km = Column(Integer, nullable=True)
```

- [ ] **Step 4: Verify server starts**

```bash
cd backend
python -c "from app.models import *; from app.models_expert import *; print('OK')"
```

Expected: "OK", no import errors.

- [ ] **Step 5: Commit**

```bash
git add backend/app/models_expert.py backend/app/models.py
git commit -m "feat: add service_radius_km columns to Expert, TaskExpertService, Activity models"
```

---

### Task 3: Backend Schemas

**Files:**
- Modify: `backend/app/schemas_expert.py:9-49` (ExpertOut)
- Modify: `backend/app/schemas_expert.py:188-197` (ExpertProfileUpdateCreate — no change needed, this is for name/bio/avatar review flow)
- Modify: `backend/app/schemas.py:2281-2320` (TaskExpertServiceCreate)
- Modify: `backend/app/schemas.py:2323-2364` (TaskExpertServiceUpdate)
- Modify: `backend/app/schemas.py:3199-3231` (ActivityCreate)
- Modify: `backend/app/schemas.py:3233-3298` (ActivityOut)

- [ ] **Step 1: Add fields to ExpertOut schema**

In `backend/app/schemas_expert.py`, in `ExpertOut` class, add after `user_level` (line 43):

```python
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    service_radius_km: Optional[int] = None
```

- [ ] **Step 2: Add service_radius_km to TaskExpertServiceCreate**

In `backend/app/schemas.py`, in `TaskExpertServiceCreate`, add after `weekly_time_slot_config` (line 2308):

```python
    # 服务区域
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

- [ ] **Step 3: Add service_radius_km to TaskExpertServiceUpdate**

In `backend/app/schemas.py`, in `TaskExpertServiceUpdate`, add after `weekly_time_slot_config` (line 2355):

```python
    # 服务区域
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

- [ ] **Step 4: Add fields to ActivityCreate**

In `backend/app/schemas.py`, in `ActivityCreate`, add after `location` (line 3205):

```python
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

- [ ] **Step 5: Add fields to ActivityOut**

In `backend/app/schemas.py`, in `ActivityOut`, add after `location` (line 3249):

```python
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    service_radius_km: Optional[int] = None
```

- [ ] **Step 6: Verify imports**

`Literal` is already imported in both `schemas_expert.py` (line 3) and `schemas.py`. Verify no import errors:

```bash
cd backend
python -c "from app.schemas import *; from app.schemas_expert import *; print('OK')"
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas_expert.py backend/app/schemas.py
git commit -m "feat: add service_radius_km to Expert/Service/Activity schemas"
```

---

### Task 4: Backend — Expert Team Base Address Endpoint

**Files:**
- Modify: `backend/app/expert_routes.py` (add new PUT endpoint)
- Modify: `backend/app/schemas_expert.py` (add new schema)

The existing `request_profile_update` endpoint (line 1410) goes through admin review for name/bio/avatar. Base address and radius are operational settings — they should be directly editable by the team owner without review.

- [ ] **Step 1: Add ExpertLocationUpdate schema**

In `backend/app/schemas_expert.py`, add before the `# Forward ref` line (line 222):

```python
class ExpertLocationUpdate(BaseModel):
    """更新达人团队基地地址 + 默认服务半径（Owner 直接生效，无需审核）"""
    location: Optional[str] = Field(None, max_length=100)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None

    @model_validator(mode='after')
    def check_lat_lng_pair(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("latitude 和 longitude 必须同时提供或同时为空")
        return self
```

- [ ] **Step 2: Add PUT endpoint in expert_routes.py**

In `backend/app/expert_routes.py`, add a new endpoint. Find the import section at the top and ensure `ExpertLocationUpdate` is imported from `app.schemas_expert`. Then add the endpoint after the `update_expert_board` function (around line 1520):

```python
@expert_router.put("/{expert_id}/location")
async def update_expert_location(
    expert_id: str,
    body: ExpertLocationUpdate,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """更新达人团队基地地址和默认服务半径（Owner only，直接生效）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    update_data = body.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="至少需要修改一个字段")

    for key, value in update_data.items():
        setattr(expert, key, value)

    await db.commit()
    await db.refresh(expert)
    return {
        "message": "基地地址已更新",
        "location": expert.location,
        "latitude": float(expert.latitude) if expert.latitude else None,
        "longitude": float(expert.longitude) if expert.longitude else None,
        "service_radius_km": expert.service_radius_km,
    }
```

- [ ] **Step 3: Add import for ExpertLocationUpdate**

In `backend/app/expert_routes.py`, find the import from `app.schemas_expert` and add `ExpertLocationUpdate` to the import list.

- [ ] **Step 4: Verify server starts**

```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 &
sleep 2
curl -s http://localhost:8000/docs | head -5
kill %1
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_routes.py backend/app/schemas_expert.py
git commit -m "feat: add PUT /experts/{id}/location for team base address"
```

---

### Task 5: Backend — Service Create/Update Radius Handling

**Files:**
- Modify: `backend/app/expert_service_routes.py:157-199` (create endpoint)
- Modify: `backend/app/expert_service_routes.py:263-302` (update endpoint)
- Modify: `backend/app/expert_service_routes.py:75-153` (list endpoint — return radius)
- Modify: `backend/app/expert_service_routes.py:203-259` (detail endpoint — return radius)

- [ ] **Step 1: Handle service_radius_km in create endpoint**

In `backend/app/expert_service_routes.py`, in the `create_expert_service` function, after the line that does `model_dump` and creates the service (around line 192), add logic to null out `service_radius_km` when `location_type` is `online`:

```python
    # Null out service_radius_km for online services
    if new_service.location_type == "online":
        new_service.service_radius_km = None
```

The `service_radius_km` field from the schema will be included automatically via `model_dump()` since it's already in the schema (Task 3 Step 2).

- [ ] **Step 2: Handle service_radius_km in update endpoint**

In the `update_expert_service` function, after applying updates via `model_dump(exclude_unset=True)`, add the same guard:

```python
    # Null out service_radius_km if location_type changed to online
    if service.location_type == "online":
        service.service_radius_km = None
```

- [ ] **Step 3: Return service_radius_km in list endpoint**

In the `list_expert_services` function, in the response dict construction (around lines 118-148), add:

```python
            "service_radius_km": s.service_radius_km,
```

- [ ] **Step 4: Return service_radius_km in detail endpoint**

In the `get_expert_service_detail` function, in the response dict (around lines 225-255), add:

```python
        "service_radius_km": service.service_radius_km,
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_service_routes.py
git commit -m "feat: handle service_radius_km in service create/update/list/detail"
```

---

### Task 6: Backend — Activity Create with Coordinates + Radius

**Files:**
- Modify: `backend/app/expert_activity_routes.py:71-196` (create endpoint)

- [ ] **Step 1: Pass new fields in activity creation**

In `backend/app/expert_activity_routes.py`, in the `create_team_activity` function, find where the `Activity` model is constructed (around line 151). The `body` is of type `ActivityCreate` which now includes `latitude`, `longitude`, `service_radius_km` (from Task 3 Step 4). Ensure these fields are passed to the Activity constructor. If the function uses `body.model_dump()` or sets fields manually, add:

```python
        latitude=body.latitude,
        longitude=body.longitude,
        service_radius_km=body.service_radius_km if body.latitude else None,
```

If `location_type` is not a concept on Activity (it isn't — activities are always in-person or online based on their parent service), just pass the values through.

- [ ] **Step 2: Return new fields in activity responses**

Check where activity responses are built. Since `ActivityOut` now includes the new fields and has `from_attributes = True`, Pydantic will auto-populate them from the ORM model. No manual mapping needed for endpoints using `response_model=ActivityOut`.

For any manually constructed dicts, add:

```python
        "latitude": float(activity.latitude) if activity.latitude else None,
        "longitude": float(activity.longitude) if activity.longitude else None,
        "service_radius_km": activity.service_radius_km,
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/expert_activity_routes.py
git commit -m "feat: support latitude/longitude/service_radius_km in activity creation"
```

---

### Task 7: Backend — Service Browse with distance_km + within_service_area

**Files:**
- Modify: `backend/app/service_browse_routes.py:14-153`

- [ ] **Step 1: Add service_radius_km and within_service_area to response**

In `backend/app/service_browse_routes.py`, in the `browse_services` function, modify the response item construction (lines 121-151).

First, add `service_radius_km` to every item:

```python
            "service_radius_km": s.service_radius_km,
```

Then modify the existing distance calculation block (lines 145-150) to also compute `within_service_area`. Replace the existing block:

```python
        if sort == "nearby" and lat is not None and lng is not None and s.latitude and s.longitude:
            from math import radians, cos, sqrt
            lat_d = float(s.latitude) - lat
            lng_d = (float(s.longitude) - lng) * cos(radians(lat))
            dist_km = sqrt(lat_d * lat_d + lng_d * lng_d) * 111.0
            item["distance_km"] = round(dist_km, 1)
```

With:

```python
        if lat is not None and lng is not None and s.latitude and s.longitude:
            from math import radians, cos, sqrt
            lat_d = float(s.latitude) - lat
            lng_d = (float(s.longitude) - lng) * cos(radians(lat))
            dist_km = sqrt(lat_d * lat_d + lng_d * lng_d) * 111.0
            item["distance_km"] = round(dist_km, 1)
            # within_service_area: null/0 radius = no limit = always true
            radius = s.service_radius_km
            if radius is None or radius == 0 or s.location_type == "online":
                item["within_service_area"] = True
            else:
                item["within_service_area"] = dist_km <= radius
```

This change computes distance for **all** sort modes (not just "nearby"), as long as user provides lat/lng and the service has coordinates. This allows the frontend to always show the "outside service area" warning.

- [ ] **Step 2: Commit**

```bash
git add backend/app/service_browse_routes.py
git commit -m "feat: return service_radius_km + within_service_area in service browse"
```

---

### Task 8: Flutter — Update Models

**Files:**
- Modify: `link2ur/lib/data/models/expert_team.dart:4-106` (ExpertTeam)
- Modify: `link2ur/lib/data/models/task_expert.dart:309-514` (TaskExpertService)
- Modify: `link2ur/lib/data/models/activity.dart:11-287` (Activity)

- [ ] **Step 1: Add fields to ExpertTeam model**

In `link2ur/lib/data/models/expert_team.dart`, in the `ExpertTeam` class:

Add fields after `isFeatured` (line 28):

```dart
  final double? latitude;
  final double? longitude;
  final int? serviceRadiusKm;
```

Add to constructor after `this.isFeatured` (line 54):

```dart
    this.latitude,
    this.longitude,
    this.serviceRadiusKm,
```

Add to `fromJson` after `isFeatured` (line 84):

```dart
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      serviceRadiusKm: json['service_radius_km'] as int?,
```

Add to `props` list (line 104):

```dart
        latitude, longitude, serviceRadiusKm,
```

- [ ] **Step 2: Add field to TaskExpertService model**

In `link2ur/lib/data/models/task_expert.dart`, in the `TaskExpertService` class:

Add field after `longitude` (line 373):

```dart
  final int? serviceRadiusKm;
```

Add to constructor:

```dart
    this.serviceRadiusKm,
```

Add to `fromJson` after longitude parsing (around line 474):

```dart
      serviceRadiusKm: json['service_radius_km'] as int?,
```

Add to `props` list.

- [ ] **Step 3: Add fields to Activity model**

In `link2ur/lib/data/models/activity.dart`, in the `Activity` class:

Add fields after `location` (line 80):

```dart
  final double? latitude;
  final double? longitude;
  final int? serviceRadiusKm;
```

Add to constructor:

```dart
    this.latitude,
    this.longitude,
    this.serviceRadiusKm,
```

Add to `fromJson` after location parsing:

```dart
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      serviceRadiusKm: json['service_radius_km'] as int?,
```

Add to `props` list.

- [ ] **Step 4: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze --no-fatal-infos
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/data/models/expert_team.dart link2ur/lib/data/models/task_expert.dart link2ur/lib/data/models/activity.dart
git commit -m "feat(flutter): add serviceRadiusKm to ExpertTeam, TaskExpertService, Activity models"
```

---

### Task 9: Flutter — Expert Team Base Address UI

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/views/management/edit_team_profile_view.dart`
- Modify: `link2ur/lib/data/repositories/expert_team_repository.dart` (add updateLocation method)

- [ ] **Step 1: Add updateLocation to ExpertTeamRepository**

In `link2ur/lib/data/repositories/expert_team_repository.dart`, add method:

```dart
  Future<void> updateExpertLocation(
    String expertId, {
    String? location,
    double? latitude,
    double? longitude,
    int? serviceRadiusKm,
  }) async {
    final data = <String, dynamic>{};
    if (location != null) data['location'] = location;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (serviceRadiusKm != null) data['service_radius_km'] = serviceRadiusKm;
    await _apiService.put(
      '${ApiEndpoints.experts}/$expertId/location',
      data: data,
    );
  }
```

Check that `ApiEndpoints.experts` exists (should be `/api/experts`). If not, find the correct constant in `api_endpoints.dart`.

- [ ] **Step 2: Add base address section to edit_team_profile_view.dart**

In `link2ur/lib/features/expert_dashboard/views/management/edit_team_profile_view.dart`:

Add imports at the top:

```dart
import 'package:link2ur/core/widgets/location_picker.dart';
```

Add state variables in `_EditBodyState` (after line 37):

```dart
  String? _location;
  double? _latitude;
  double? _longitude;
  int? _serviceRadiusKm;
```

In `_initFromTeam` method (line 46), add:

```dart
      _location = team.location;
      _latitude = team.latitude;
      _longitude = team.longitude;
      _serviceRadiusKm = team.serviceRadiusKm;
```

In the `ListView.children` list, after the bio `TextFormField` and review note (after line 134), add the base address section:

```dart
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.baseAddress,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LocationInputField(
                          initialLocation: _location,
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          onChanged: (value) => _location = value,
                          onLocationPicked: (address, lat, lng) {
                            setState(() {
                              _location = address;
                              _latitude = lat;
                              _longitude = lng;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.defaultServiceRadius,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [5, 10, 25, 50, 0].map((r) {
                            final label = r == 0
                                ? context.l10n.serviceRadiusWholeCity
                                : context.l10n.serviceRadiusKm(r);
                            return ChoiceChip(
                              label: Text(label),
                              selected: _serviceRadiusKm == r,
                              onSelected: (selected) {
                                setState(() {
                                  _serviceRadiusKm = selected ? r : null;
                                });
                              },
                            );
                          }).toList(),
                        ),
```

- [ ] **Step 3: Add save logic for location**

The existing save button submits a profile update request (name/bio/avatar) which goes through admin review. Location should be saved separately via the direct endpoint.

In the submit button's `onPressed` handler, after the existing profile update logic, add a separate call for location if changed:

```dart
    // Save location directly (no review needed)
    final team = state.currentTeam!;
    final locationChanged = _location != team.location ||
        _latitude != team.latitude ||
        _longitude != team.longitude ||
        _serviceRadiusKm != team.serviceRadiusKm;
    if (locationChanged) {
      try {
        await context.read<ExpertTeamRepository>().updateExpertLocation(
          widget.expertId,
          location: _location,
          latitude: _latitude,
          longitude: _longitude,
          serviceRadiusKm: _serviceRadiusKm,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(e.toString()))),
          );
        }
      }
    }
```

- [ ] **Step 4: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze --no-fatal-infos
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/expert_dashboard/views/management/edit_team_profile_view.dart link2ur/lib/data/repositories/expert_team_repository.dart
git commit -m "feat(flutter): add base address + default radius to expert team edit page"
```

---

### Task 10: Flutter — Service Creation Radius Selector

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/views/tabs/services_tab.dart:407-907`

- [ ] **Step 1: Add state variable**

In `services_tab.dart`, in the service creation form state, add:

```dart
  int? _serviceRadiusKm;
```

When editing an existing service, initialize from the service data:

```dart
  _serviceRadiusKm = service.serviceRadiusKm;
```

- [ ] **Step 2: Add radius selector UI**

After the `LocationInputField` widget (around line 909), when `_locationType != 'online'`, add:

```dart
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.selectServiceRadius,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(context.l10n.inheritTeamDefault),
                              selected: _serviceRadiusKm == null,
                              onSelected: (selected) {
                                if (selected) setState(() => _serviceRadiusKm = null);
                              },
                            ),
                            ...[5, 10, 25, 50, 0].map((r) {
                              final label = r == 0
                                  ? context.l10n.serviceRadiusWholeCity
                                  : context.l10n.serviceRadiusKm(r);
                              return ChoiceChip(
                                label: Text(label),
                                selected: _serviceRadiusKm == r,
                                onSelected: (selected) {
                                  setState(() => _serviceRadiusKm = selected ? r : null);
                                },
                              );
                            }),
                          ],
                        ),
```

- [ ] **Step 3: Include in API submission**

In the service submission data construction (around line 533-549), add:

```dart
if (_locationType != 'online' && _serviceRadiusKm != null) {
  data['service_radius_km'] = _serviceRadiusKm;
}
```

- [ ] **Step 4: Reset radius when switching to online**

In the `location_type` SegmentedButton's `onSelectionChanged` callback, when "online" is selected, clear the radius:

```dart
if (newType == 'online') {
  _serviceRadiusKm = null;
}
```

- [ ] **Step 5: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze --no-fatal-infos
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/expert_dashboard/views/tabs/services_tab.dart
git commit -m "feat(flutter): add service radius selector to service creation/edit"
```

---

### Task 11: Flutter — Activity Creation with Location + Radius

**Files:**
- Find and modify the activity creation UI (likely in `link2ur/lib/features/expert_dashboard/views/tabs/` or a dedicated activity creation view)

- [ ] **Step 1: Locate activity creation UI**

Search for the activity creation form in Flutter:

```bash
grep -rn "ActivityCreate\|create.*activity\|ActivityBloc" link2ur/lib/features/expert_dashboard/
```

- [ ] **Step 2: Replace text location input with LocationInputField**

Replace the existing plain `TextFormField` for location with the `LocationInputField` widget (same pattern as services_tab.dart):

```dart
LocationInputField(
  initialLocation: _location,
  initialLatitude: _latitude,
  initialLongitude: _longitude,
  onChanged: (value) => _location = value,
  onLocationPicked: (address, lat, lng) {
    setState(() {
      _location = address;
      _latitude = lat;
      _longitude = lng;
    });
  },
),
```

- [ ] **Step 3: Add radius selector**

Add the same `ChoiceChip` radius selector as Task 10, with the "inherit team default" option.

- [ ] **Step 4: Include new fields in API submission**

Add `latitude`, `longitude`, and `service_radius_km` to the activity creation request body.

- [ ] **Step 5: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze --no-fatal-infos
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/
git commit -m "feat(flutter): add LocationInputField + radius selector to activity creation"
```

---

### Task 12: Flutter — Service Browse/Detail Area Display

**Files:**
- Find and modify service browse card widget
- Find and modify service detail view

- [ ] **Step 1: Locate service browse card and detail views**

```bash
grep -rn "service_radius_km\|distance_km\|within_service_area\|ServiceCard\|service.*detail" link2ur/lib/features/ --include="*.dart" | head -20
```

Also search for where the browse API response is consumed.

- [ ] **Step 2: Add service_radius_km display to service card**

In the service card widget, when `serviceRadiusKm` is not null, show a small label:

```dart
if (service.serviceRadiusKm != null)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      service.serviceRadiusKm == 0
          ? context.l10n.serviceRadiusWholeCity
          : context.l10n.serviceRadiusKm(service.serviceRadiusKm!),
      style: Theme.of(context).textTheme.labelSmall,
    ),
  ),
```

- [ ] **Step 3: Add "outside service area" banner to service detail**

In the service detail view, if the API response includes `within_service_area == false`, show a soft warning banner:

```dart
if (withinServiceArea == false)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.outsideServiceArea,
            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
          ),
        ),
      ],
    ),
  ),
```

- [ ] **Step 4: Parse new fields from browse API response**

Where the browse API response is parsed, ensure `service_radius_km`, `distance_km`, and `within_service_area` are extracted and made available to the UI.

- [ ] **Step 5: Verify compilation and commit**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze --no-fatal-infos
```

```bash
git add link2ur/lib/
git commit -m "feat(flutter): display service radius + outside-area warning in browse/detail"
```

---

### Task 13: Localization — ARB Files

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add keys to app_en.arb**

```json
  "serviceRadius": "Service Area",
  "serviceRadiusKm": "{radius}km",
  "@serviceRadiusKm": {
    "placeholders": {
      "radius": { "type": "int" }
    }
  },
  "serviceRadiusWholeCity": "Whole City",
  "outsideServiceArea": "This service may not cover your area. Contact the expert to confirm.",
  "selectServiceRadius": "Select service area",
  "baseAddress": "Base Address",
  "defaultServiceRadius": "Default Service Area",
  "inheritTeamDefault": "Use team default"
```

- [ ] **Step 2: Add keys to app_zh.arb**

```json
  "serviceRadius": "服务范围",
  "serviceRadiusKm": "{radius}公里",
  "@serviceRadiusKm": {
    "placeholders": {
      "radius": { "type": "int" }
    }
  },
  "serviceRadiusWholeCity": "全城",
  "outsideServiceArea": "该服务可能不在您的区域内，建议联系达人确认",
  "selectServiceRadius": "选择服务范围",
  "baseAddress": "基地地址",
  "defaultServiceRadius": "默认服务范围",
  "inheritTeamDefault": "使用团队默认"
```

- [ ] **Step 3: Add keys to app_zh_Hant.arb**

```json
  "serviceRadius": "服務範圍",
  "serviceRadiusKm": "{radius}公里",
  "@serviceRadiusKm": {
    "placeholders": {
      "radius": { "type": "int" }
    }
  },
  "serviceRadiusWholeCity": "全城",
  "outsideServiceArea": "該服務可能不在您的區域內，建議聯繫達人確認",
  "selectServiceRadius": "選擇服務範圍",
  "baseAddress": "基地地址",
  "defaultServiceRadius": "預設服務範圍",
  "inheritTeamDefault": "使用團隊預設"
```

- [ ] **Step 4: Regenerate l10n**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter gen-l10n
```

Expected: No errors, generated files updated.

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat(flutter): add service area i18n keys (en/zh/zh_Hant)"
```

---

### Task 14: Full-Stack Consistency Check

- [ ] **Step 1: Verify the full chain is aligned**

Check the complete data flow:

| Layer | Field | File |
|-------|-------|------|
| DB | `experts.service_radius_km` | migration 195 |
| Model | `Expert.service_radius_km` | `models_expert.py` |
| Schema Out | `ExpertOut.service_radius_km` | `schemas_expert.py` |
| Schema In | `ExpertLocationUpdate.service_radius_km` | `schemas_expert.py` |
| API | `PUT /experts/{id}/location` | `expert_routes.py` |
| Flutter Model | `ExpertTeam.serviceRadiusKm` | `expert_team.dart` |
| Flutter Repo | `updateExpertLocation()` | `expert_team_repository.dart` |
| Flutter UI | ChoiceChip selector | `edit_team_profile_view.dart` |

Repeat for TaskExpertService and Activity chains.

- [ ] **Step 2: Verify field names match across stack**

- Backend returns `service_radius_km` (snake_case)
- Flutter parses `json['service_radius_km']`
- Browse API returns `distance_km`, `within_service_area`
- Flutter handles both new fields

- [ ] **Step 3: Test end-to-end manually**

1. Set expert team base address via team edit page
2. Create a service with `location_type = in_person`, verify radius defaults
3. Browse services with lat/lng, verify `distance_km` and `within_service_area` in response
4. View service from far away, verify soft warning appears

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: service area/radius — full-stack implementation complete"
```
