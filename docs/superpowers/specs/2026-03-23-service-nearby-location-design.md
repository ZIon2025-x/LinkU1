# Service & Task Nearby Location — Design Spec

## Overview

1. Enhance `LocationInputField` with auto-geocoding on manual text input — benefits both task and service publishing
2. Add geographic location fields to personal services
3. Add nearby sort to service browse API
4. Mix nearby services into the "附近" tab alongside tasks

## Key Decisions

| Decision | Choice |
|---|---|
| Location input | GPS + manual input with debounced auto-geocode (native `geocoding` package, free on mobile) |
| Geocode accuracy | Show resolved result for user confirmation; no country restriction (geocoding package uses device locale) |
| Search radius | User-adjustable: 5/10/25/50/100 km, default 25km |
| Nearby display | Mixed — tasks and services together, sorted by distance |

## 1. LocationInputField Enhancement (shared widget)

**File:** `link2ur/lib/core/widgets/location_picker.dart`

Current behavior: manual text input → only updates `location` text, no coordinates. GPS and map picker produce coordinates, but typing does not.

**New behavior:** After user stops typing for 500ms, auto-call `locationFromAddress(text)` → if successful, update `latitude`/`longitude` and show a confirmation chip below the input:

```
📍 已定位到: Birmingham, West Midlands, UK
```

If geocode returns no result or fails, show subtle hint: "未能解析地址，建议使用定位按钮" — but don't block submission. The text is still saved as `location`, just without coordinates (service won't appear in nearby search, but can still be found by text search).

This change improves **both task and service publishing** — any screen using `LocationInputField` gets auto-geocode for free.

## 2. Data Model — Service Location

Add 3 columns to `TaskExpertService`:

```
location      VARCHAR(100)   NULLABLE   -- city/address text for display
latitude      DECIMAL(10,8)  NULLABLE   -- lat for distance calc
longitude     DECIMAL(11,8)  NULLABLE   -- lng for distance calc
```

Only meaningful when `location_type` is `in_person` or `both`. `online` services have no location.

## 3. Backend API Changes

### PersonalServiceCreate / Update schemas

Add optional fields:

```python
location: Optional[str] = Field(None, max_length=100)
latitude: Optional[condecimal(ge=-90, le=90, max_digits=10, decimal_places=8)] = None
longitude: Optional[condecimal(ge=-180, le=180, max_digits=11, decimal_places=8)] = None
```

### personal_service_routes.py

- Create: set `location`, `latitude`, `longitude` from request data
- List response: include `location`, `latitude`, `longitude`

### service_browse_routes.py — add nearby sort

New query params:
- `lat: float` — user latitude (required for `sort=nearby`)
- `lng: float` — user longitude (required for `sort=nearby`)
- `radius: int` — km, one of 5/10/25/50/100, default 25

When `sort=nearby`:
1. Filter: `location_type IN ('in_person', 'both')` AND `latitude IS NOT NULL` AND `longitude IS NOT NULL`
2. Approximate distance: `(latitude - :lat)^2 + (longitude - :lng * cos(radians(:lat)))^2`
3. Filter by radius (convert km to approximate degree delta)
4. Order by distance ascending

### Browse response

Add `location`, `distance_km` (calculated, rounded to 1 decimal) to response items when `sort=nearby`.

## 4. Frontend Changes

### Service form — conditional location input

In `personal_service_form_view.dart`, when `_locationType` is `in_person` or `both`:
- Show `LocationInputField` widget (already supports GPS + manual + map)
- Now with auto-geocode on manual input (from enhancement in section 1)
- Store `location`, `latitude`, `longitude` in form state, include in submit data
- When `_locationType` changes to `online`, clear location data

### TaskExpertService model

Add `location` (String?), `latitude` (double?), `longitude` (double?) to Dart model, `fromJson`, `toJson`, `props`.

### Home "附近" tab — mixed content

**HomeBloc:**
- When loading nearby tab, also call `PersonalServiceRepository.browseServices(sort: 'nearby', lat, lng, radius)`
- Merge nearby tasks + nearby services into a unified list sorted by distance
- Add `nearbyRadius` to state, default 25

**Nearby tab view:**
- Radius selector chips at top (5/10/25/50/100 km)
- Mixed list: task cards and service cards, distinguished by type
- Service cards show: name, price, location, distance badge (📍 0.8km), owner avatar

### l10n

Add keys for: radius labels, resolved location confirmation text, geocode failure hint, nearby service card elements.

## File Changes

### Backend (~4 files + migration)

| File | Change |
|---|---|
| `backend/app/models.py` | Add `location`, `latitude`, `longitude` to TaskExpertService |
| `backend/app/schemas.py` | Add location fields to PersonalServiceCreate/Update |
| `backend/app/personal_service_routes.py` | Include location in create/list response |
| `backend/app/service_browse_routes.py` | Add `nearby` sort with lat/lng/radius params + distance calc |
| `backend/migrations/126_add_service_location.sql` | Add 3 columns |

### Frontend (~6 files)

| File | Change |
|---|---|
| `link2ur/lib/core/widgets/location_picker.dart` | Add debounced auto-geocode on manual text input + confirmation chip |
| `link2ur/lib/data/models/task_expert.dart` | Add location/lat/lng fields |
| `link2ur/lib/features/personal_service/views/personal_service_form_view.dart` | Conditional LocationInputField when in_person/both |
| `link2ur/lib/features/home/bloc/home_bloc.dart` | Fetch nearby services, merge with tasks, radius state |
| `link2ur/lib/features/home/views/home_view.dart` (nearby tab) | Render mixed list + radius selector chips |
| `link2ur/lib/l10n/*.arb` | New l10n keys |

## Not In Scope

- Google Places Autocomplete
- Map view for browsing nearby services
- Push notifications for new nearby services
- Location-based service recommendations
- Modifying existing task location fields (tasks already have lat/lng)
