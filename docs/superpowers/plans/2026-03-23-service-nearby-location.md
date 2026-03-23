# Service & Task Nearby Location — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add location fields to personal services, enhance LocationInputField with auto-geocode, and mix nearby services into the 附近 tab.

**Architecture:** Add location/lat/lng columns to TaskExpertService. Enhance the shared LocationInputField widget with debounced geocoding on manual input. Add `nearby` sort mode to the service browse API. Merge nearby services into HomeBloc's nearby tab alongside tasks.

**Tech Stack:** FastAPI + SQLAlchemy (backend), Flutter + BLoC + geocoding package (frontend)

**Spec:** `docs/superpowers/specs/2026-03-23-service-nearby-location-design.md`

---

### Task 1: Database model + migration

**Files:**
- Modify: `backend/app/models.py` (TaskExpertService class, around line 1593)
- Create: `backend/migrations/126_add_service_location.sql`

- [ ] **Step 1: Add columns to TaskExpertService model**

In `backend/app/models.py`, in the `TaskExpertService` class, after the `location_type` column (line ~1594), add:

```python
location = Column(String(100), nullable=True)  # city/address text for display
latitude = Column(DECIMAL(10, 8), nullable=True)  # for distance calc
longitude = Column(DECIMAL(11, 8), nullable=True)  # for distance calc
```

- [ ] **Step 2: Create migration SQL**

Create `backend/migrations/126_add_service_location.sql`:

```sql
ALTER TABLE task_expert_services
  ADD COLUMN IF NOT EXISTS location VARCHAR(100),
  ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
  ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

CREATE INDEX IF NOT EXISTS idx_task_expert_services_location_type_coords
  ON task_expert_services(location_type)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
```

- [ ] **Step 3: Verify**

Run: `cd backend && python -c "from app.models import TaskExpertService; print(TaskExpertService.location)"`

- [ ] **Step 4: Commit**

```bash
git add backend/app/models.py backend/migrations/126_add_service_location.sql
git commit -m "feat: add location/latitude/longitude columns to TaskExpertService"
```

---

### Task 2: Backend schemas + CRUD updates

**Files:**
- Modify: `backend/app/schemas.py` (PersonalServiceCreate, PersonalServiceUpdate)
- Modify: `backend/app/personal_service_routes.py` (create + list response)

- [ ] **Step 1: Add location fields to schemas**

In `backend/app/schemas.py`, add to `PersonalServiceCreate` (after `location_type`):

```python
location: Optional[str] = Field(None, max_length=100)
latitude: Optional[condecimal(ge=-90, le=90, max_digits=10, decimal_places=8)] = None
longitude: Optional[condecimal(ge=-180, le=180, max_digits=11, decimal_places=8)] = None
```

Add same 3 fields to `PersonalServiceUpdate`.

- [ ] **Step 2: Update create endpoint**

In `backend/app/personal_service_routes.py`, in `create_personal_service`, add to the `TaskExpertService(...)` constructor:

```python
location=data.location,
latitude=data.latitude,
longitude=data.longitude,
```

- [ ] **Step 3: Update list response**

In the list endpoint response dict, add:

```python
"location": s.location,
"latitude": float(s.latitude) if s.latitude else None,
"longitude": float(s.longitude) if s.longitude else None,
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas.py backend/app/personal_service_routes.py
git commit -m "feat: add location fields to personal service schemas and CRUD"
```

---

### Task 3: Browse endpoint — nearby sort

**Files:**
- Modify: `backend/app/service_browse_routes.py`

- [ ] **Step 1: Add nearby query params and sort**

In `backend/app/service_browse_routes.py`, update `browse_services` function:

Add params:
```python
lat: Optional[float] = Query(None),
lng: Optional[float] = Query(None),
radius: int = Query(25, ge=5, le=100),
```

Update sort pattern to `"^(recommended|newest|price_asc|price_desc|nearby)$"`.

Add `nearby` sort case:
```python
elif sort == "nearby":
    if lat is None or lng is None:
        raise HTTPException(status_code=400, detail="lat and lng are required for nearby sort")
    # Filter to in-person/both services with coordinates
    query = query.where(
        models.TaskExpertService.location_type.in_(["in_person", "both"]),
        models.TaskExpertService.latitude.isnot(None),
        models.TaskExpertService.longitude.isnot(None),
    )
    # Approximate distance in degrees (1 degree ≈ 111km)
    from sqlalchemy import func as sa_func
    radius_deg = radius / 111.0
    lat_diff = models.TaskExpertService.latitude - lat
    lng_diff = (models.TaskExpertService.longitude - lng) * sa_func.cos(sa_func.radians(lat))
    distance_sq = lat_diff * lat_diff + lng_diff * lng_diff
    # Filter by radius
    query = query.where(distance_sq <= radius_deg * radius_deg)
    query = query.order_by(distance_sq.asc())
```

In the response builder, add distance_km when sort=nearby:
```python
if sort == "nearby" and lat is not None and lng is not None and s.latitude and s.longitude:
    from math import radians, cos, sqrt
    lat_d = float(s.latitude) - lat
    lng_d = (float(s.longitude) - lng) * cos(radians(lat))
    dist_km = sqrt(lat_d * lat_d + lng_d * lng_d) * 111.0
    item["distance_km"] = round(dist_km, 1)
```

Add `location` to all response items:
```python
"location": s.location,
```

- [ ] **Step 2: Verify import works**

Run: `cd backend && python -c "from app.service_browse_routes import service_browse_router; print('OK')"`

- [ ] **Step 3: Commit**

```bash
git add backend/app/service_browse_routes.py
git commit -m "feat: add nearby sort to service browse endpoint with radius filter"
```

---

### Task 4: Flutter model — add location fields

**Files:**
- Modify: `link2ur/lib/data/models/task_expert.dart` (TaskExpertService class)

- [ ] **Step 1: Add fields**

In the `TaskExpertService` class:

Constructor — add after `locationType`:
```dart
this.location,
this.latitude,
this.longitude,
```

Fields — add after `locationType`:
```dart
final String? location;
final double? latitude;
final double? longitude;
```

fromJson — add after `locationType` parse:
```dart
location: json['location']?.toString(),
latitude: (json['latitude'] as num?)?.toDouble(),
longitude: (json['longitude'] as num?)?.toDouble(),
```

toJson — add:
```dart
'location': location,
'latitude': latitude,
'longitude': longitude,
```

props — add `location, latitude, longitude`.

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/models/task_expert.dart
git commit -m "feat: add location/latitude/longitude to TaskExpertService model"
```

---

### Task 5: Enhance LocationInputField — debounced auto-geocode

**Files:**
- Modify: `link2ur/lib/core/widgets/location_picker.dart` (LocationInputField class)

- [ ] **Step 1: Add debounce timer and geocode state**

In `_LocationInputFieldState`, add fields:
```dart
Timer? _debounceTimer;
String? _resolvedAddress;
bool _isGeocoding = false;
```

Add import at top of file:
```dart
import 'dart:async';
```

- [ ] **Step 2: Add auto-geocode method**

```dart
Future<void> _geocodeManualInput(String text) async {
  if (text.trim().length < 2) {
    setState(() => _resolvedAddress = null);
    return;
  }
  setState(() => _isGeocoding = true);
  try {
    final locations = await locationFromAddress(text);
    if (locations.isNotEmpty && mounted) {
      final loc = locations.first;
      _latitude = loc.latitude;
      _longitude = loc.longitude;
      // Reverse geocode to get formatted address
      try {
        final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
        if (placemarks.isNotEmpty) {
          _resolvedAddress = _formatPlacemarkAddress(placemarks.first);
        }
      } catch (_) {
        _resolvedAddress = '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
      }
      widget.onLocationPicked?.call(
        _controller.text,
        _latitude,
        _longitude,
      );
    }
  } catch (_) {
    if (mounted) {
      setState(() => _resolvedAddress = null);
      // Coordinates stay null — service won't appear in nearby, but that's OK
    }
  } finally {
    if (mounted) setState(() => _isGeocoding = false);
  }
}
```

- [ ] **Step 3: Update onChanged to use debounce**

Replace the existing `onChanged` callback on the TextField:
```dart
onChanged: (value) {
  // Clear coordinates immediately on new input
  _latitude = null;
  _longitude = null;
  _resolvedAddress = null;
  widget.onChanged?.call(value);

  // Debounce geocode
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    _geocodeManualInput(value);
  });
},
```

- [ ] **Step 4: Add resolved address confirmation chip below input**

After the TextField in the `build` method, before the quick options Row, add:
```dart
if (_isGeocoding)
  Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecondaryLight)),
        const SizedBox(width: 8),
        Text('解析中...', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
      ],
    ),
  )
else if (_resolvedAddress != null)
  Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        const Icon(Icons.check_circle, size: 14, color: AppColors.success),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '📍 $_resolvedAddress',
            style: const TextStyle(fontSize: 12, color: AppColors.success),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  ),
```

- [ ] **Step 5: Dispose timer**

In `dispose()`:
```dart
_debounceTimer?.cancel();
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/core/widgets/location_picker.dart
git commit -m "feat: add debounced auto-geocode on manual text input in LocationInputField"
```

---

### Task 6: Service form — conditional location input

**Files:**
- Modify: `link2ur/lib/features/personal_service/views/personal_service_form_view.dart`

- [ ] **Step 1: Add location state variables**

In `_FormContentState`, add:
```dart
String? _location;
double? _latitude;
double? _longitude;
```

In `initState` edit mode, add:
```dart
_location = (data['location'] as String?);
_latitude = (data['latitude'] as num?)?.toDouble();
_longitude = (data['longitude'] as num?)?.toDouble();
```

- [ ] **Step 2: Add import for LocationInputField**

```dart
import '../../../core/widgets/location_picker.dart';
```

- [ ] **Step 3: Add location section to form**

Between the Location Type `SegmentedButton` and the Images placeholder, add:

```dart
// ── Location (show when in_person or both) ──
if (_locationType == 'in_person' || _locationType == 'both') ...[
  _SectionLabel(label: context.l10n.personalServiceLocation),
  const SizedBox(height: AppSpacing.sm),
  LocationInputField(
    initialValue: _location,
    initialLatitude: _latitude,
    initialLongitude: _longitude,
    showOnlineOption: false,
    onChanged: (value) {
      _location = value;
    },
    onLocationPicked: (address, lat, lng) {
      _location = address;
      _latitude = lat;
      _longitude = lng;
    },
  ),
  const SizedBox(height: AppSpacing.md),
],
```

- [ ] **Step 4: Include location in submit data**

In `_submit()`, add to the `data` map:
```dart
if (_locationType != 'online') {
  if (_location != null && _location!.isNotEmpty) {
    data['location'] = _location;
  }
  if (_latitude != null) data['latitude'] = _latitude;
  if (_longitude != null) data['longitude'] = _longitude;
}
```

- [ ] **Step 5: Clear location when switching to online**

In the `_locationType` SegmentedButton `onSelectionChanged`, after `setState`:
```dart
if (selected.first == 'online') {
  _location = null;
  _latitude = null;
  _longitude = null;
}
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/personal_service/views/personal_service_form_view.dart
git commit -m "feat: add conditional location input to service form"
```

---

### Task 7: Home nearby tab — fetch and merge services

**Files:**
- Modify: `link2ur/lib/features/home/bloc/home_state.dart`
- Modify: `link2ur/lib/features/home/bloc/home_bloc.dart`

- [ ] **Step 1: Add state fields**

In `home_state.dart`, add to `HomeState`:
```dart
this.nearbyServices = const [],
this.nearbyRadius = 25,
```

Fields:
```dart
final List<Map<String, dynamic>> nearbyServices;
final int nearbyRadius;
```

Add to `copyWith` and `props`.

- [ ] **Step 2: Add events**

In `home_event.dart`, add:
```dart
class HomeLoadNearbyServices extends HomeEvent {
  const HomeLoadNearbyServices({required this.latitude, required this.longitude, this.radius = 25});
  final double latitude;
  final double longitude;
  final int radius;
  @override
  List<Object?> get props => [latitude, longitude, radius];
}

class HomeChangeNearbyRadius extends HomeEvent {
  const HomeChangeNearbyRadius(this.radius);
  final int radius;
  @override
  List<Object?> get props => [radius];
}
```

- [ ] **Step 3: Add handler in HomeBloc**

Register handlers:
```dart
on<HomeLoadNearbyServices>(_onLoadNearbyServices);
on<HomeChangeNearbyRadius>(_onChangeNearbyRadius);
```

Implement:
```dart
Future<void> _onLoadNearbyServices(
  HomeLoadNearbyServices event,
  Emitter<HomeState> emit,
) async {
  try {
    final result = await _personalServiceRepository.browseServices(
      sort: 'nearby',
      lat: event.latitude,
      lng: event.longitude,
      radius: event.radius,
    );
    final items = List<Map<String, dynamic>>.from(result['items'] ?? []);
    emit(state.copyWith(nearbyServices: items, nearbyRadius: event.radius));
  } catch (_) {
    // Silent fail — nearby services are supplementary
  }
}

void _onChangeNearbyRadius(
  HomeChangeNearbyRadius event,
  Emitter<HomeState> emit,
) {
  emit(state.copyWith(nearbyRadius: event.radius));
}
```

HomeBloc needs `PersonalServiceRepository` injected. Add it to the constructor.

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/home/bloc/
git commit -m "feat: add nearby services loading and radius to HomeBloc"
```

---

### Task 8: Nearby tab view — mixed list + radius selector

**Files:**
- Modify: nearby tab in `link2ur/lib/features/home/views/` (the file that builds the nearby tab content)

- [ ] **Step 1: Add radius selector chips**

At the top of the nearby tab, add horizontal chips:
```dart
SizedBox(
  height: 36,
  child: ListView(
    scrollDirection: Axis.horizontal,
    padding: EdgeInsets.symmetric(horizontal: 16),
    children: [5, 10, 25, 50, 100].map((r) {
      final isSelected = r == state.nearbyRadius;
      return Padding(
        padding: EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('${r}km'),
          selected: isSelected,
          onSelected: (_) {
            context.read<HomeBloc>().add(HomeChangeNearbyRadius(r));
            // Re-fetch with new radius
          },
        ),
      );
    }).toList(),
  ),
),
```

- [ ] **Step 2: Merge tasks + services into mixed list**

Combine `state.nearbyTasks` and `state.nearbyServices` into a single list sorted by distance. Each item needs a type tag ('task' vs 'service') so the list builder renders the right card widget.

- [ ] **Step 3: Add service card variant**

For service items in the mixed list, render: service name, price, pricing type badge, location, distance badge (📍 0.8km), owner avatar + name.

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/home/views/
git commit -m "feat: mixed nearby tab with services, radius selector chips"
```

---

### Task 9: l10n keys + wiring

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`
- Modify: `link2ur/lib/app_providers.dart` (inject PersonalServiceRepository into HomeBloc)

- [ ] **Step 1: Add l10n keys**

```
"nearbyRadius": "Search Radius" / "搜索范围" / "搜索範圍"
"nearbyNoServices": "No nearby services" / "附近暂无服务" / "附近暫無服務"
"locationResolving": "Resolving..." / "解析中..." / "解析中..."
"locationResolved": "Located" / "已定位" / "已定位"
```

- [ ] **Step 2: Inject PersonalServiceRepository into HomeBloc**

In `app_providers.dart` or wherever HomeBloc is created, pass `PersonalServiceRepository` to its constructor.

- [ ] **Step 3: Run gen-l10n and analyze**

```bash
cd link2ur && flutter gen-l10n && flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/app_providers.dart
git commit -m "feat: add nearby l10n keys and wire PersonalServiceRepository into HomeBloc"
```
