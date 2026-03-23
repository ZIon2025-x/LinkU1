# Service Nearby Location — Design Spec

## Overview

Add geographic location to personal services so they appear in the "附近" (nearby) tab. Users can find in-person/both services near them, mixed with nearby tasks.

## Key Decisions

| Decision | Choice |
|---|---|
| Location input | GPS + manual input with auto-geocode (native `geocoding` package, free) |
| Geocode accuracy | Limit to UK results to reduce mismatches; show resolved result for user confirmation |
| Search radius | User-adjustable: 5/10/25/50/100 km, default 25km |
| Nearby display | Mixed — tasks and services together, sorted by distance |

## Data Model

Add 3 columns to `TaskExpertService`:

```
location      VARCHAR(100)   NULLABLE   -- city/address text for display
latitude      DECIMAL(10,8)  NULLABLE   -- lat for distance calc
longitude     DECIMAL(11,8)  NULLABLE   -- lng for distance calc
```

Only required when `location_type` is `in_person` or `both`. `online` services have no location.

Migration: append to existing `125_add_personal_services.sql` or create `126_add_service_location.sql`.

## Backend API Changes

### PersonalServiceCreate / Update schemas

Add optional fields:

```python
location: Optional[str] = Field(None, max_length=100)
latitude: Optional[condecimal(ge=-90, le=90, max_digits=10, decimal_places=8)] = None
longitude: Optional[condecimal(ge=-180, le=180, max_digits=11, decimal_places=8)] = None
```

### personal_service_routes.py — create endpoint

Set `location`, `latitude`, `longitude` from request data. Validate: if `location_type` in (`in_person`, `both`), `location` should be provided (warning, not error — GPS may fail).

### service_browse_routes.py — add nearby sort

New query params:
- `lat: float` — user latitude (required for `sort=nearby`)
- `lng: float` — user longitude (required for `sort=nearby`)
- `radius: int` — km, one of 5/10/25/50/100, default 25

When `sort=nearby`:
1. Filter: `location_type IN ('in_person', 'both')` AND `latitude IS NOT NULL` AND `longitude IS NOT NULL`
2. Calculate approximate distance: `(latitude - :lat)^2 + (longitude - :lng * cos(radians(:lat)))^2`
3. Filter by radius (convert km to approximate degree delta)
4. Order by distance ascending

### Browse response

Add `location`, `latitude`, `longitude`, `distance_km` (calculated, rounded to 1 decimal) to response items.

## Frontend Changes

### 1. Service form — location input

In `personal_service_form_view.dart`, when `location_type` is `in_person` or `both`, show location section:

- Reuse existing `LocationInputField` widget (supports GPS + manual input + map picker)
- After manual text input: debounce 500ms → call `locationFromAddress(text)` with locale hint for UK → show resolved address below input for confirmation
- If geocode fails or returns unexpected country, show warning but don't block
- Store `location` (text), `latitude`, `longitude` in form state
- Include in submit data

### 2. TaskExpertService model

Add `location`, `latitude`, `longitude` fields to Dart model, `fromJson`, `toJson`, `props`.

### 3. Home "附近" tab — mixed content

In `HomeBloc`:
- When loading nearby tab, also call `PersonalServiceRepository.browseServices(sort: 'nearby', lat: ..., lng: ..., radius: ...)`
- Merge nearby tasks + nearby services into a unified list, sorted by distance
- Each item needs a `type` discriminator ('task' vs 'service') for the UI to render the right card

In the nearby tab view:
- Render task cards and service cards differently based on type
- Service cards show: service name, price, location, distance badge, owner avatar
- Add radius selector (horizontal chips: 5/10/25/50/100 km)

### 4. l10n

Add keys for radius labels and nearby service display.

## File Changes

### Backend (~3 files + migration)

| File | Change |
|---|---|
| `backend/app/models.py` | Add `location`, `latitude`, `longitude` to TaskExpertService |
| `backend/app/schemas.py` | Add location fields to PersonalServiceCreate/Update |
| `backend/app/personal_service_routes.py` | Include location in create/list response |
| `backend/app/service_browse_routes.py` | Add `nearby` sort with lat/lng/radius params + distance calc |
| `backend/migrations/126_add_service_location.sql` | Add 3 columns |

### Frontend (~5 files)

| File | Change |
|---|---|
| `link2ur/lib/data/models/task_expert.dart` | Add location/lat/lng fields |
| `link2ur/lib/features/personal_service/views/personal_service_form_view.dart` | Conditional location input using LocationInputField |
| `link2ur/lib/features/home/bloc/home_bloc.dart` | Fetch nearby services, merge with tasks |
| `link2ur/lib/features/home/views/home_view.dart` (nearby tab) | Render mixed list + radius selector |
| `link2ur/lib/l10n/*.arb` | Radius and nearby service l10n keys |

## Not In Scope

- Google Places Autocomplete (using native geocoding instead)
- Map view for browsing nearby services
- Push notifications for new nearby services
- Location-based service recommendations
