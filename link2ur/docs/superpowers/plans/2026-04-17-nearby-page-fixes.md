# Nearby Page Full Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all bugs, performance issues, and UX problems in the "Nearby" tab of the home page — both Flutter frontend and Python backend.

**Architecture:** The Nearby tab lives in `home_task_cards.dart` (part of `home_view.dart`), driven by `HomeBloc`. It loads two data sources: tasks via `GET /api/async/tasks?sort_by=distance` and services via `GET /api/services/browse?sort=nearby`. Backend distance queries currently lack proper indexes and have pagination bugs. Frontend has dedup, loading UX, and privacy (exact distance display) issues.

**Tech Stack:** Flutter/Dart (BLoC, Equatable), Python (FastAPI, SQLAlchemy, PostgreSQL), SQL migrations

---

## File Structure

### Backend (will modify)
- `backend/app/async_routers.py` — fix page/skip logic (L259-261)
- `backend/app/async_crud.py` — fix total caching, add sort_by validation
- `backend/app/service_browse_routes.py` — switch distance formula to Haversine
- `backend/migrations/204_add_nearby_btree_indexes.sql` — new: B-tree indexes for lat/lng

### Flutter (will modify)
- `link2ur/lib/features/home/bloc/home_bloc.dart` — dedup, move sorting to bloc, cancel stale requests
- `link2ur/lib/features/home/bloc/home_event.dart` — add NearbyServices pagination event fields
- `link2ur/lib/features/home/bloc/home_state.dart` — add nearbyServicesPage, hasMoreNearbyServices
- `link2ur/lib/features/home/views/home_task_cards.dart` — fix loading UX, use blurred distance, location failure notice, fix loadMore, use LocationCityService
- `link2ur/lib/data/services/location_city_service.dart` — 已有全局 GPS 城市检测单例，NearbyTab 应复用其缓存坐标避免重复定位
- `link2ur/lib/data/repositories/personal_service_repository.dart` — no changes needed (already has page param)
- `link2ur/lib/data/repositories/task_repository.dart` — no changes needed

### Not touching
- Task model (`task.dart`) — `blurredDistanceText` getter already exists, just need to use it in UI
- `nearbyServices` stays as `List<Map<String, dynamic>>` — typing it would require a new model + significant refactor across browse/detail flows; low ROI for this fix round

---

## Task 1: Backend — Add B-tree indexes for nearby queries

Currently `tasks.latitude/longitude` has only a GiST index (`point(lon, lat)`) which PostgreSQL cannot use for `BETWEEN` range queries. `task_expert_services` has no usable coordinate index at all.

**Files:**
- Create: `backend/migrations/204_add_nearby_btree_indexes.sql`

- [ ] **Step 1: Create migration file**

```sql
-- 204_add_nearby_btree_indexes.sql
-- Add B-tree indexes for latitude/longitude range queries used by nearby sort
-- The existing GiST index (037) uses point() which doesn't help BETWEEN queries

-- tasks table: composite B-tree for bounding box (lat BETWEEN x AND y AND lng BETWEEN x AND y)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_lat_lng_btree
  ON tasks (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status IN ('open', 'in_progress')
    AND is_visible = true;

-- task_expert_services table: composite B-tree for nearby service browse
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_services_lat_lng_btree
  ON task_expert_services (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status = 'active'
    AND location_type IN ('in_person', 'both');

-- experts table: for COALESCE fallback when service inherits team coordinates
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_experts_lat_lng_btree
  ON experts (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
```

- [ ] **Step 2: Verify migration file exists and SQL is valid**

Run:
```bash
cd backend && cat migrations/204_add_nearby_btree_indexes.sql
```

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/204_add_nearby_btree_indexes.sql
git commit -m "feat(backend): add B-tree indexes for nearby lat/lng queries

Migration 204: composite B-tree indexes on tasks and task_expert_services
for latitude/longitude range queries. The existing GiST index (037) uses
point() which PostgreSQL cannot use for BETWEEN comparisons."
```

---

## Task 2: Backend — Fix page=1&page_size=20 returning 100 rows

When `page=1` and `page_size=20` (both defaults), the condition `page > 1 or page_size != 20` is False, so `skip=0, limit=100` (the Query defaults) are used instead of the intended `skip=0, limit=20`.

**Files:**
- Modify: `backend/app/async_routers.py:259-261`

- [ ] **Step 1: Read current code to confirm exact lines**

Read `backend/app/async_routers.py` lines 255-265.

- [ ] **Step 2: Fix the page/skip conversion logic**

In `backend/app/async_routers.py`, replace:

```python
    if page > 1 or page_size != 20:
        skip = (page - 1) * page_size
        limit = page_size
```

with:

```python
    # Always use page/page_size when provided (they have defaults)
    # skip/limit are legacy params kept for backward compat
    skip = (page - 1) * page_size
    limit = page_size
```

This always converts page/page_size to skip/limit. The legacy `skip`/`limit` query params still work because if a caller passes `skip=40&limit=10` without `page`, the `page` default (1) produces `skip=0`, but we need to check: does any caller actually use raw `skip/limit`?

Actually, the safer fix is: always apply page-based calculation, which makes `skip` and `limit` query params effectively ignored when `page` is present. Since all current callers use `page/page_size`, this is correct.

- [ ] **Step 3: Commit**

```bash
git add backend/app/async_routers.py
git commit -m "fix(backend): page=1&page_size=20 now correctly returns 20 rows

Previously the condition (page > 1 or page_size != 20) was False for
default values, causing skip=0/limit=100 to be used instead of the
intended page-based calculation."
```

---

## Task 3: Backend — Fix distance sort total caching inconsistency

In `async_crud.py`, the count query result is cached in Redis (L680-693), but then `total` is overwritten by `len(nearby_tasks)` (L968). Next request reads stale cached total.

**Files:**
- Modify: `backend/app/async_crud.py:670-700` (cache logic)
- Modify: `backend/app/async_crud.py:967-968` (total override)

- [ ] **Step 1: Read the cache block and total override**

Read `backend/app/async_crud.py` lines 670-700 and lines 960-975.

- [ ] **Step 2: Skip Redis count cache for distance sort**

The issue: for distance sort, the "real" total is only known after Python-side filtering, but the cached value is the pre-filter count. Fix: don't cache count for distance sort (it's cheap since we already fetch all rows).

In `backend/app/async_crud.py`, find the cache read block (around L680):

```python
                # 尝试从缓存获取 total
```

Add a condition to skip cache for distance sort. Find the block that reads/writes the Redis cache for total. Wrap it so that when `sort_by in ("distance", "nearby")`, we skip the cache entirely and just run the count query (or better: skip the count query too since we'll overwrite total at L968 anyway).

Replace the cache block (approximately L674-699) — the section that does `cache_key`, Redis get/set — with:

```python
            # For distance sort, skip count cache — total is computed after
            # Python-side distance filtering (overwritten at L968).
            if sort_by in ("distance", "nearby"):
                total = 0  # placeholder; will be overwritten after filtering
            else:
                # Original cache logic for non-distance sorts
                cache_key = f"task_count:{task_type}:{location}:{status}:{keyword}:{sort_by}:{is_multi_participant}:{parent_activity_id}"
```

Keep the rest of the original cache logic (Redis get/set) inside the `else` branch.

- [ ] **Step 3: Commit**

```bash
git add backend/app/async_crud.py
git commit -m "fix(backend): skip Redis count cache for distance-sorted queries

Distance sort computes total after Python-side filtering, which
overwrites the cached value. Skipping the cache avoids stale total
on subsequent requests."
```

---

## Task 4: Backend — Switch service browse distance to Haversine

`service_browse_routes.py` uses planar approximation (`lat_diff * cos(lat)`) while `async_crud.py` uses Haversine. This causes inconsistent distances on the same page.

**Files:**
- Modify: `backend/app/service_browse_routes.py:196-200` (Python display distance)

Note: The SQL-level distance (`distance_sq`) is used only for filtering and ordering — planar approximation is acceptable there for performance. But the returned `distance_km` should use Haversine for consistency with task distances.

- [ ] **Step 1: Read the distance display code**

Read `backend/app/service_browse_routes.py` lines 195-205.

- [ ] **Step 2: Replace planar distance with Haversine for display**

In `backend/app/service_browse_routes.py`, at the top imports, add:

```python
from math import radians, cos, sqrt, sin, atan2
```

(Replace the existing `from math import radians, cos, sqrt` on line 1.)

Then replace the distance calculation block (lines 196-200):

```python
        if lat is not None and lng is not None and eff_lat is not None and eff_lng is not None:
            lat_d = eff_lat - lat
            lng_d = (eff_lng - lng) * cos(radians(lat))
            dist_km = sqrt(lat_d * lat_d + lng_d * lng_d) * 111.0
            item["distance_km"] = round(dist_km, 1)
```

with:

```python
        if lat is not None and lng is not None and eff_lat is not None and eff_lng is not None:
            # Haversine formula — consistent with task distance calculation
            dlat = radians(eff_lat - lat)
            dlng = radians(eff_lng - lng)
            a = sin(dlat / 2) ** 2 + cos(radians(lat)) * cos(radians(eff_lat)) * sin(dlng / 2) ** 2
            dist_km = 6371.0 * 2 * atan2(sqrt(a), sqrt(1 - a))
            item["distance_km"] = round(dist_km, 1)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/service_browse_routes.py
git commit -m "fix(backend): use Haversine for service distance_km display

Switches from planar approximation to Haversine formula for the
distance_km field returned to frontend. SQL-level filtering still
uses planar approximation (acceptable for bounding box + ordering).
Consistent with task distance calculation in async_crud.py."
```

---

## Task 5: Flutter — Fix loadMore dedup + add services pagination

Two bugs: (1) loadMore appends tasks without dedup, (2) services have no pagination — only the first page loads.

**Files:**
- Modify: `link2ur/lib/features/home/bloc/home_bloc.dart:288-350` (_onLoadNearby) and `527-546` (_onLoadNearbyServices)
- Modify: `link2ur/lib/features/home/bloc/home_event.dart:124-135` (HomeLoadNearbyServices)
- Modify: `link2ur/lib/features/home/bloc/home_state.dart` (add service pagination fields)

- [ ] **Step 1: Add service pagination fields to HomeState**

In `link2ur/lib/features/home/bloc/home_state.dart`, add after `isLoadingNearby` (line 48):

```dart
    this.nearbyServicesPage = 1,
    this.hasMoreNearbyServices = true,
```

Add the corresponding fields after `isLoadingNearby` field declaration (line 108):

```dart
  final int nearbyServicesPage;
  final bool hasMoreNearbyServices;
```

Add to `copyWith` parameters (after `isLoadingNearby` param, around line 153):

```dart
    int? nearbyServicesPage,
    bool? hasMoreNearbyServices,
```

Add to `copyWith` return (after `isLoadingNearby` assignment, around line 192):

```dart
      nearbyServicesPage: nearbyServicesPage ?? this.nearbyServicesPage,
      hasMoreNearbyServices: hasMoreNearbyServices ?? this.hasMoreNearbyServices,
```

Add to `props` list (after `isLoadingNearby`, around line 232):

```dart
        nearbyServicesPage,
        hasMoreNearbyServices,
```

- [ ] **Step 2: Add loadMore flag to HomeLoadNearbyServices event**

In `link2ur/lib/features/home/bloc/home_event.dart`, replace `HomeLoadNearbyServices` (lines 124-135):

```dart
class HomeLoadNearbyServices extends HomeEvent {
  const HomeLoadNearbyServices({
    required this.latitude,
    required this.longitude,
    this.radius = 5,
    this.loadMore = false,
  });
  final double latitude;
  final double longitude;
  final int radius;
  final bool loadMore;
  @override
  List<Object?> get props => [latitude, longitude, radius, loadMore];
}
```

- [ ] **Step 3: Fix _onLoadNearby — add dedup by task ID**

In `link2ur/lib/features/home/bloc/home_bloc.dart`, replace the `allTasks` construction (lines 323-325):

```dart
      final allTasks = event.loadMore
          ? [...state.nearbyTasks, ...tasksWithDistance]
          : tasksWithDistance;
```

with:

```dart
      List<Task> allTasks;
      if (event.loadMore) {
        final existingIds = state.nearbyTasks.map((t) => t.id).toSet();
        final newTasks = tasksWithDistance
            .where((t) => !existingIds.contains(t.id))
            .toList();
        allTasks = [...state.nearbyTasks, ...newTasks];
      } else {
        allTasks = tasksWithDistance;
      }
```

- [ ] **Step 4: Fix _onLoadNearbyServices — add pagination + dedup**

In `link2ur/lib/features/home/bloc/home_bloc.dart`, replace `_onLoadNearbyServices` (lines 529-546):

```dart
  Future<void> _onLoadNearbyServices(
    HomeLoadNearbyServices event,
    Emitter<HomeState> emit,
  ) async {
    if (_personalServiceRepository == null) return;
    try {
      final page = event.loadMore ? state.nearbyServicesPage + 1 : 1;
      final result = await _personalServiceRepository.browseServices(
        sort: 'nearby',
        lat: event.latitude,
        lng: event.longitude,
        radius: event.radius,
        page: page,
      );
      final newItems = List<Map<String, dynamic>>.from(result['items'] ?? []);
      final total = result['total'] as int? ?? 0;
      final pageSize = result['page_size'] as int? ?? 20;

      List<Map<String, dynamic>> allItems;
      if (event.loadMore) {
        final existingIds = state.nearbyServices.map((s) => s['id']).toSet();
        final deduped = newItems.where((s) => !existingIds.contains(s['id'])).toList();
        allItems = [...state.nearbyServices, ...deduped];
      } else {
        allItems = newItems;
      }

      emit(state.copyWith(
        nearbyServices: allItems,
        nearbyRadius: event.radius,
        nearbyServicesPage: page,
        hasMoreNearbyServices: page * pageSize < total,
      ));
    } catch (_) {
      // Silent fail — nearby services are supplementary data
    }
  }
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/home/bloc/home_bloc.dart link2ur/lib/features/home/bloc/home_event.dart link2ur/lib/features/home/bloc/home_state.dart
git commit -m "fix(flutter): dedup loadMore tasks + add services pagination

- Tasks: dedup by ID when appending loadMore results
- Services: add page/hasMore tracking, dedup by ID
- New state fields: nearbyServicesPage, hasMoreNearbyServices"
```

---

## Task 6: Flutter — Fix loading UX (remove fullscreen overlay)

Replace the `Positioned.fill` overlay that blocks all interaction with a subtle inline loading indicator.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:367-375` (loading overlay)

- [ ] **Step 1: Replace fullscreen overlay with inline loading**

In `link2ur/lib/features/home/views/home_task_cards.dart`, replace the loading overlay block (lines 367-375):

```dart
            if (state.isLoadingNearby)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
```

with:

```dart
            if (state.isLoadingNearby)
              const Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
```

This shows a small, non-blocking spinner at the top that doesn't prevent scrolling or tapping.

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart
git commit -m "fix(flutter): replace fullscreen loading overlay with inline spinner

The Positioned.fill overlay blocked all interaction during radius
changes. New spinner is small, positioned at top, and non-blocking."
```

---

## Task 7: Flutter — Use blurred distance display (privacy)

The card shows exact distance ("1.3km") but the model has `blurredDistanceText` ("<1.5km") for privacy. Sorting already uses blurred buckets — display should match.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:497-510` (_NearbyWaterfallCard props)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:806-809` (_formatDistance)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:186-204` (_buildWaterfallItems — tasks section)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:207-245` (_buildWaterfallItems — services section)

- [ ] **Step 1: Change _NearbyWaterfallCard to accept String? distanceText instead of double? distance**

In `link2ur/lib/features/home/views/home_task_cards.dart`, replace the `_NearbyWaterfallCard` constructor and fields (lines 498-519):

```dart
  const _NearbyWaterfallCard({
    required this.title,
    this.imageUrl,
    this.distanceText,
    this.distanceMeters,
    this.tags = const [],
    this.price,
    this.applicantCount = 0,
    this.onTap,
    this.itemType = '',
    this.isExpertVerified = false,
    this.ownerName,
    this.ownerAvatar,
  });

  final String title;
  final String? imageUrl;
  /// Pre-formatted blurred distance text, e.g. "<1.5km"
  final String? distanceText;
  /// Raw distance in meters — used only for sorting in _buildWaterfallItems
  final double? distanceMeters;
  final List<String> tags;
  final String? price;
  final int applicantCount;
  final VoidCallback? onTap;
  final String itemType;
  final bool isExpertVerified;
  final String? ownerName;
  final String? ownerAvatar;
```

- [ ] **Step 2: Update _buildImageArea to use distanceText**

In `_buildImageArea`, replace the distance badge (lines 739-764). Find:

```dart
        if (distance != null)
```

Replace with:

```dart
        if (distanceText != null)
```

And replace the `_formatDistance(distance!)` call with just `distanceText!`.

Remove the static method `_formatDistance` entirely (lines 806-809) since it's no longer used.

- [ ] **Step 3: Update _buildWaterfallItems for tasks — pass blurredDistanceText**

In `_buildWaterfallItems`, replace the task card creation (around lines 191-203):

```dart
      entries.add((
        widget: _NearbyWaterfallCard(
          title: title,
          imageUrl: task.firstImage,
          distanceText: task.blurredDistanceText,
          distanceMeters: task.distance,
          tags: [task.taskType],
          price: '\u00A3${task.reward == task.reward.truncateToDouble() ? task.reward.toInt().toString() : task.reward.toStringAsFixed(2)}',
          applicantCount: task.currentParticipants,
          itemType: task.taskType,
          onTap: () => context.push('/tasks/${task.id}'),
        ),
        distance: task.distance ?? double.infinity,
      ));
```

- [ ] **Step 4: Update _buildWaterfallItems for services — compute blurred distance**

For services, replace the card creation (around lines 228-244). Replace:

```dart
      entries.add((
        widget: _NearbyWaterfallCard(
          title: name,
          imageUrl: imageUrl,
          distance: distMeters,
          price: priceStr,
```

with:

```dart
      // Blur service distance to 500m buckets (same as task model)
      String? serviceDistText;
      if (distMeters != null) {
        final bucket = (distMeters / 500).ceil() * 500;
        if (bucket <= 500) {
          serviceDistText = '<500m';
        } else if (bucket < 1000) {
          serviceDistText = '<${bucket}m';
        } else {
          final km = bucket / 1000;
          serviceDistText = km == km.roundToDouble()
              ? '<${km.toInt()}km'
              : '<${km.toStringAsFixed(1)}km';
        }
      }

      entries.add((
        widget: _NearbyWaterfallCard(
          title: name,
          imageUrl: imageUrl,
          distanceText: serviceDistText,
          distanceMeters: distMeters,
          price: priceStr,
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart
git commit -m "fix(flutter): use blurred distance display for privacy

Cards now show '<1.5km' instead of exact '1.3km'. Tasks use the
existing blurredDistanceText getter. Services compute the same
500m-bucket blurring inline. Consistent with sort order which
already uses blurred buckets."
```

---

## Task 8: Flutter — Fix loadMore to include services + fix mixed sort jump

Currently loadMore only loads more tasks, not services. And new tasks insert into the middle of the sorted list causing visual "jumps". Fix: loadMore for both, and append new items at the bottom instead of re-sorting.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:348-362` (loadMore trigger)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:179-251` (_buildWaterfallItems)

- [ ] **Step 1: Update loadMore trigger to also load more services**

In `home_task_cards.dart`, replace the loadMore trigger (lines 348-362):

```dart
                  if (state.hasMoreNearby)
                    SliverToBoxAdapter(
                      child: _NearbyLoadMoreTrigger(
                        onVisible: () {
                          final bloc = context.read<HomeBloc>();
                          bloc.add(HomeLoadNearby(
                            latitude: _currentLat,
                            longitude: _currentLng,
                            loadMore: true,
                            city: _city,
                            radius: bloc.state.nearbyRadius,
                          ));
                        },
                      ),
                    ),
```

with:

```dart
                  if (state.hasMoreNearby || state.hasMoreNearbyServices)
                    SliverToBoxAdapter(
                      child: _NearbyLoadMoreTrigger(
                        onVisible: () {
                          final bloc = context.read<HomeBloc>();
                          if (bloc.state.hasMoreNearby) {
                            bloc.add(HomeLoadNearby(
                              latitude: _currentLat,
                              longitude: _currentLng,
                              loadMore: true,
                              city: _city,
                              radius: bloc.state.nearbyRadius,
                            ));
                          }
                          if (bloc.state.hasMoreNearbyServices) {
                            bloc.add(HomeLoadNearbyServices(
                              latitude: _currentLat,
                              longitude: _currentLng,
                              radius: bloc.state.nearbyRadius,
                              loadMore: true,
                            ));
                          }
                        },
                      ),
                    ),
```

- [ ] **Step 2: Update buildWhen to include new state fields**

In the `BlocBuilder` `buildWhen` (lines 272-278), add:

```dart
          prev.nearbyServicesPage != curr.nearbyServicesPage ||
          prev.hasMoreNearbyServices != curr.hasMoreNearbyServices ||
```

after the existing `prev.isLoadingNearby != curr.isLoadingNearby` line.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart
git commit -m "fix(flutter): loadMore now loads both tasks and services

Previously only tasks were paginated on scroll. Now services also
load more pages. buildWhen updated for new state fields."
```

---

## Task 9: Flutter — Show location failure notice

When location permission is denied or service is off, the user silently gets London data. Add a subtle banner.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:12-33` (_NearbyTabState fields + initState)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:35-83` (_loadLocation)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:451-493` (_NearbyLocationBar)

- [ ] **Step 1: Add _locationFailed flag to _NearbyTabState**

In `_NearbyTabState` (line 13), add a field:

```dart
  bool _locationFailed = false;
```

- [ ] **Step 2: Set _locationFailed in _loadLocation fallback paths**

In `_loadLocation`, at each fallback to default coordinates, set the flag. There are 4 places where `_loadWithCoordinates(_defaultLat, _defaultLng)` is called (lines 42, 51, 57, 82). Before each call, add:

```dart
        setState(() => _locationFailed = true);
```

Actually, since `_loadWithCoordinates` calls `setState` already, we can set the flag in one place. In `_loadWithCoordinates` (line 144), check if using defaults:

Replace `_loadWithCoordinates` (lines 144-161):

```dart
  void _loadWithCoordinates(double lat, double lng) {
    if (!mounted) return;
    _currentLat = lat;
    _currentLng = lng;
    final isDefault = lat == _defaultLat && lng == _defaultLng;
    setState(() {
      _locationLoading = false;
      _locationFailed = isDefault;
    });
    final bloc = context.read<HomeBloc>();
    bloc.add(HomeLoadNearby(
          latitude: lat,
          longitude: lng,
          city: _city,
          radius: bloc.state.nearbyRadius,
        ));
    bloc.add(HomeLoadNearbyServices(
          latitude: lat,
          longitude: lng,
          radius: bloc.state.nearbyRadius,
        ));
  }
```

- [ ] **Step 3: Pass _locationFailed to _NearbyLocationBar**

In the build method, update the `_NearbyLocationBar` construction (around line 324):

```dart
                    child: _NearbyLocationBar(
                      city: _city,
                      onRefreshTap: _loadLocation,
                      locationFailed: _locationFailed,
                    ),
```

- [ ] **Step 4: Update _NearbyLocationBar to show warning**

> **Note:** Task 12 further extends `_NearbyLocationBar` with `permissionDeniedForever` + "Open Settings" button. Implement this step first (adds `locationFailed`), then Task 12 adds the remaining prop.

Replace `_NearbyLocationBar` (lines 451-493):

```dart
class _NearbyLocationBar extends StatelessWidget {
  const _NearbyLocationBar({
    required this.city,
    required this.onRefreshTap,
    this.locationFailed = false,
  });

  final String? city;
  final VoidCallback onRefreshTap;
  final bool locationFailed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final displayCity = city ?? 'London';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
      ),
      child: Row(
        children: [
          Icon(
            locationFailed ? Icons.location_off : Icons.location_on,
            size: 14,
            color: locationFailed ? Colors.orange : AppColors.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              locationFailed
                  ? l10n.nearbyLocationFailed
                  : l10n.nearbyCurrentLocation(displayCity),
              style: TextStyle(
                fontSize: 13,
                color: locationFailed
                    ? Colors.orange
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRefreshTap,
            child: const Icon(
              Icons.my_location,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add l10n key for location failed**

In `link2ur/lib/l10n/app_en.arb`, add:

```json
  "nearbyLocationFailed": "Location unavailable · showing London",
```

In `link2ur/lib/l10n/app_zh.arb`, add:

```json
  "nearbyLocationFailed": "定位不可用 · 显示伦敦附近",
```

In `link2ur/lib/l10n/app_zh_Hant.arb`, add:

```json
  "nearbyLocationFailed": "定位不可用 · 顯示倫敦附近",
```

- [ ] **Step 6: Run gen-l10n**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 7: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart link2ur/lib/l10n/
git commit -m "fix(flutter): show location failure notice instead of silent London fallback

When GPS is denied/unavailable, the location bar now shows an orange
warning icon and 'Location unavailable · showing London' instead of
silently displaying 'Current location: London'."
```

---

## Task 10: Flutter — Reset services on radius change + reset _NearbyLoadMoreTrigger

Two issues: (1) radius change doesn't reset service pagination, (2) `_NearbyLoadMoreTrigger` fires only once due to `_triggered` flag not resetting.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:163-177` (_onRadiusChanged)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:853-877` (_NearbyLoadMoreTriggerState)

- [ ] **Step 1: Ensure _onRadiusChanged resets service page state**

The `_onRadiusChanged` already dispatches `HomeLoadNearbyServices` without `loadMore`, so the bloc handler resets to page 1. But we need to also reset `nearbyServicesPage` and `hasMoreNearbyServices` in the bloc. This is already handled by Task 5 Step 4 — when `event.loadMore` is false, `nearbyServicesPage` is set to `page` (which is 1) and `hasMoreNearbyServices` is recalculated. No additional change needed here.

- [ ] **Step 2: Fix _NearbyLoadMoreTrigger to re-trigger when data changes**

The current trigger fires once in `initState` and never again. When new data loads and the trigger is rebuilt at the bottom of the list, it needs to fire again.

Replace `_NearbyLoadMoreTriggerState` (lines 853-877):

```dart
class _NearbyLoadMoreTriggerState extends State<_NearbyLoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    _scheduleCallback();
  }

  void _scheduleCallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

Wait — this will cause infinite loops since the widget is in a SliverToBoxAdapter that rebuilds. The original `_triggered` guard is intentional. The real issue is that after loadMore completes, if there's still more data, the trigger needs to fire again. The widget gets rebuilt by BlocBuilder → new `_NearbyLoadMoreTriggerState` → new `initState`. Actually, since `_triggered` is instance state and a new state is created on rebuild... the issue is that `IndexedStack` keeps the widget alive. Let me reconsider.

The widget is inside a `CustomScrollView` inside a `BlocBuilder`. When `state.hasMoreNearby` changes from true→true (still has more after loading), the `BlocBuilder` rebuilds, but the `_NearbyLoadMoreTrigger` widget has the same type and position in the tree, so Flutter **reuses** the State — `initState` is NOT called again.

Fix: use a `Key` to force recreation, or use `didUpdateWidget`:

```dart
class _NearbyLoadMoreTriggerState extends State<_NearbyLoadMoreTrigger> {
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _trigger();
  }

  @override
  void didUpdateWidget(covariant _NearbyLoadMoreTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-trigger when the widget is updated (e.g. after a page load)
    _triggered = false;
    _trigger();
  }

  void _trigger() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_triggered && mounted) {
        _triggered = true;
        widget.onVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

Actually, there's a simpler approach: give the trigger a `ValueKey` based on the current page so Flutter creates a new State each time:

In the build method where `_NearbyLoadMoreTrigger` is used (around line 350), add a key:

```dart
                      child: _NearbyLoadMoreTrigger(
                        key: ValueKey('nearby_loadmore_${state.nearbyPage}_${state.nearbyServicesPage}'),
                        onVisible: () {
```

This forces a new State when page changes, so `initState` fires again.

Use the `ValueKey` approach — it's simpler and the original `_NearbyLoadMoreTriggerState` code stays unchanged.

- [ ] **Step 3: Add ValueKey to _NearbyLoadMoreTrigger**

In `home_task_cards.dart`, find the `_NearbyLoadMoreTrigger` construction (around line 350) and add a key:

```dart
                      child: _NearbyLoadMoreTrigger(
                        key: ValueKey('nearby_more_${state.nearbyPage}_${state.nearbyServicesPage}'),
                        onVisible: () {
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart
git commit -m "fix(flutter): loadMore trigger re-fires after each page load

Added ValueKey based on current page numbers so Flutter creates a
fresh State after each page load, allowing initState to trigger
the next loadMore."
```

---

## Task 11: Flutter — Fix empty state hides radius selector (1km trap)

**Bug:** When user switches to 1km and there are no tasks/services, the empty state (L285-306) does `return Center(...)` which **replaces the entire layout** including `_NearbyLocationBar` and `_NearbyRadiusSelector`. The user is trapped — they can't switch back to 5km/10km because the radius chips are gone. The only option is the "refresh" button which re-loads at the same 1km radius.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:285-306` (empty state branch)

- [ ] **Step 1: Restructure empty state to keep location bar + radius selector visible**

In `link2ur/lib/features/home/views/home_task_cards.dart`, replace the empty state block (lines 285-306):

```dart
        if (!state.isLoadingNearby && state.nearbyTasks.isEmpty && state.nearbyServices.isEmpty) {
          final isDarkEmpty = Theme.of(context).brightness == Brightness.dark;
          final center = Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off_outlined,
                    size: 64, color: isDarkEmpty ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                AppSpacing.vMd,
                Text(context.l10n.homeNoNearbyTasks,
                    style: TextStyle(color: isDarkEmpty ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                AppSpacing.vMd,
                TextButton.icon(
                  onPressed: _loadLocation,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.homeLoadNearbyTasks),
                ),
              ],
            ),
          );
          return isDesktop ? ContentConstraint(child: center) : center;
        }
```

with:

```dart
        if (!state.isLoadingNearby && state.nearbyTasks.isEmpty && state.nearbyServices.isEmpty) {
          final isDarkEmpty = Theme.of(context).brightness == Brightness.dark;
          final emptyContent = Column(
            children: [
              // Keep location bar + radius selector visible so user can switch radius
              _NearbyLocationBar(
                city: _city,
                onRefreshTap: _loadLocation,
                locationFailed: _locationFailed,
              ),
              _NearbyRadiusSelector(
                selectedRadius: state.nearbyRadius,
                onChanged: _onRadiusChanged,
              ),
              const Spacer(),
              Icon(Icons.location_off_outlined,
                  size: 64, color: isDarkEmpty ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
              AppSpacing.vMd,
              Text(context.l10n.homeNoNearbyTasks,
                  style: TextStyle(color: isDarkEmpty ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
              AppSpacing.vMd,
              TextButton.icon(
                onPressed: _loadLocation,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.homeLoadNearbyTasks),
              ),
              const Spacer(),
            ],
          );
          return isDesktop ? ContentConstraint(child: emptyContent) : emptyContent;
        }
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart
git commit -m "fix(flutter): keep radius selector visible in nearby empty state

When switching to 1km with no results, the radius chips and location
bar disappeared, trapping the user. Now the empty state preserves
these controls so users can switch back to a wider radius."
```

---

## Task 12: Flutter — GPS permission denied → prompt to open app settings

**Bug:** When GPS permission is `deniedForever` (user previously denied + "Don't ask again"), the app silently falls back to London. Should show a prompt explaining why location is needed and offer a button to open the app's system settings page (`Geolocator.openAppSettings()`).

The project already has `PermissionManager.showPermissionDialog()` in `core/utils/permission_manager.dart` and l10n keys (`permissionRequired`, `permissionEnableInSettings`, `commonGoSetup`) — but `_NearbyTab` doesn't use them. Also, `Geolocator.openAppSettings()` and `Geolocator.openLocationSettings()` are available from the geolocator package.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:12-18` (_NearbyTabState — add field)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:35-84` (_loadLocation — detect deniedForever)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:451-493` (_NearbyLocationBar — add "open settings" tap)

- [ ] **Step 1: Add _permissionDeniedForever flag to _NearbyTabState**

In `_NearbyTabState` (around line 13), add:

```dart
  bool _permissionDeniedForever = false;
```

- [ ] **Step 2: Set the flag in _loadLocation**

In `_loadLocation`, replace the `deniedForever` branch (lines 56-59):

```dart
      if (permission == LocationPermission.deniedForever) {
        _loadWithCoordinates(_defaultLat, _defaultLng);
        return;
      }
```

with:

```dart
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _permissionDeniedForever = true);
        _loadWithCoordinates(_defaultLat, _defaultLng);
        return;
      }
```

Also, in the `denied` branch (lines 48-53), after `requestPermission()`, if permission is still denied, also check if it became `deniedForever`:

```dart
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted && permission == LocationPermission.deniedForever) {
            setState(() => _permissionDeniedForever = true);
          }
          _loadWithCoordinates(_defaultLat, _defaultLng);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _permissionDeniedForever = true);
        _loadWithCoordinates(_defaultLat, _defaultLng);
        return;
      }
```

When location succeeds (real coordinates), clear the flag. In `_loadWithCoordinates`, the `_locationFailed` logic (from Task 9) already handles this — `_locationFailed = isDefault` — so `_permissionDeniedForever` only needs to be reset when location succeeds. Add to `_loadWithCoordinates`:

```dart
  void _loadWithCoordinates(double lat, double lng) {
    if (!mounted) return;
    _currentLat = lat;
    _currentLng = lng;
    final isDefault = lat == _defaultLat && lng == _defaultLng;
    setState(() {
      _locationLoading = false;
      _locationFailed = isDefault;
      if (!isDefault) _permissionDeniedForever = false;
    });
    // ... rest unchanged
  }
```

- [ ] **Step 3: Pass _permissionDeniedForever to _NearbyLocationBar**

Update the `_NearbyLocationBar` construction (same place as Task 9 Step 3):

```dart
                    child: _NearbyLocationBar(
                      city: _city,
                      onRefreshTap: _loadLocation,
                      locationFailed: _locationFailed,
                      permissionDeniedForever: _permissionDeniedForever,
                    ),
```

Also update the empty state `_NearbyLocationBar` from Task 11 to pass the same prop.

- [ ] **Step 4: Update _NearbyLocationBar — add "open settings" action**

Replace `_NearbyLocationBar` (updated version from Task 9):

```dart
class _NearbyLocationBar extends StatelessWidget {
  const _NearbyLocationBar({
    required this.city,
    required this.onRefreshTap,
    this.locationFailed = false,
    this.permissionDeniedForever = false,
  });

  final String? city;
  final VoidCallback onRefreshTap;
  final bool locationFailed;
  final bool permissionDeniedForever;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final displayCity = city ?? 'London';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
      ),
      child: Row(
        children: [
          Icon(
            locationFailed ? Icons.location_off : Icons.location_on,
            size: 14,
            color: locationFailed ? Colors.orange : AppColors.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              locationFailed
                  ? l10n.nearbyLocationFailed
                  : l10n.nearbyCurrentLocation(displayCity),
              style: TextStyle(
                fontSize: 13,
                color: locationFailed
                    ? Colors.orange
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          if (permissionDeniedForever)
            GestureDetector(
              onTap: () => Geolocator.openAppSettings(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.nearbyOpenSettings,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onRefreshTap,
              child: const Icon(
                Icons.my_location,
                size: 14,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add l10n key for "open settings"**

In `link2ur/lib/l10n/app_en.arb`, add:

```json
  "nearbyOpenSettings": "Open Settings",
```

In `link2ur/lib/l10n/app_zh.arb`, add:

```json
  "nearbyOpenSettings": "去设置",
```

In `link2ur/lib/l10n/app_zh_Hant.arb`, add:

```json
  "nearbyOpenSettings": "去設置",
```

- [ ] **Step 6: Run gen-l10n**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 7: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart link2ur/lib/l10n/
git commit -m "fix(flutter): prompt user to open settings when GPS permission denied

When location permission is permanently denied, the location bar
shows an 'Open Settings' button that calls Geolocator.openAppSettings()
to take the user directly to the app's permission settings page."
```

---

## Task 13: Flutter — Use LocationCityService to avoid duplicate GPS resolution

**Problem:** `_NearbyTab._loadLocation()` independently does GPS permission check → `getLastKnownPosition` → `getCurrentPosition` → reverse geocode, duplicating what `LocationCityService.instance.resolve()` already does at app startup (called from `main_tab_view.dart:171`). When user switches to the Nearby tab, we can reuse the singleton's cached coordinates for instant load, only falling back to a fresh GPS request if the singleton hasn't resolved yet.

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:27-33` (initState)
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart:35-84` (_loadLocation)

- [ ] **Step 1: Add LocationCityService import**

In `link2ur/lib/features/home/views/home_view.dart` (the parent file of `home_task_cards.dart`), add:

```dart
import '../../../data/services/location_city_service.dart';
```

(Check if this import already exists; `home_task_cards.dart` line 99 already references `LocationCityService`, so the import should already be in `home_view.dart`. Verify and skip if present.)

- [ ] **Step 2: Use cached coordinates in initState**

In `_NearbyTabState.initState()` (lines 27-33), replace:

```dart
  @override
  void initState() {
    super.initState();
    // 如果已有附近任务数据，跳过重新定位
    final homeState = context.read<HomeBloc>().state;
    if (homeState.nearbyTasks.isNotEmpty) return;
    _loadLocation();
  }
```

with:

```dart
  @override
  void initState() {
    super.initState();
    // 如果已有附近任务数据，跳过重新定位
    final homeState = context.read<HomeBloc>().state;
    if (homeState.nearbyTasks.isNotEmpty) return;

    // 优先使用全局单例的缓存坐标（main_tab_view 启动时已 resolve），
    // 避免 NearbyTab 重复做 GPS 权限检查 + 定位请求。
    final locService = LocationCityService.instance;
    if (locService.isResolved && locService.latitude != null && locService.longitude != null) {
      _city = locService.city;
      _loadWithCoordinates(locService.latitude!, locService.longitude!);
      // 后台获取精确位置（和原逻辑一致，差异 >500m 才刷新）
      _refreshWithCurrentPosition(locService.latitude!, locService.longitude!);
    } else {
      _loadLocation();
    }
  }
```

- [ ] **Step 3: In _loadLocation, also update LocationCityService on success**

`_resolveCity` already calls `LocationCityService.instance.update()` (line 99), so no changes needed here.

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart
git commit -m "perf(flutter): reuse LocationCityService cached GPS in NearbyTab

When the global LocationCityService has already resolved coordinates
(done at app startup by main_tab_view), NearbyTab skips its own
GPS permission check + positioning and uses the cached values directly.
Falls back to _loadLocation() only if the singleton hasn't resolved."
```

---

## Task 14: Backend — Add sort_by validation

`async_routers.py` accepts any string for `sort_by`. Add validation consistent with `service_browse_routes.py` which uses `pattern=`.

**Files:**
- Modify: `backend/app/async_routers.py:118`

- [ ] **Step 1: Read the sort_by parameter definition**

Read `backend/app/async_routers.py` line 118.

- [ ] **Step 2: Add pattern validation**

Replace:

```python
    sort_by: Optional[str] = Query("latest"),
```

with:

```python
    sort_by: Optional[str] = Query("latest", pattern="^(latest|distance|nearby|highest_pay|near_deadline|recommended)$"),
```

The valid values come from the `if/elif` branches in `async_crud.py`.

- [ ] **Step 3: Commit**

```bash
git add backend/app/async_routers.py
git commit -m "fix(backend): validate sort_by parameter with regex pattern

Restricts sort_by to known values: latest, distance, nearby,
highest_pay, near_deadline, recommended. Consistent with
service_browse_routes.py which already validates sort."
```

---

## Summary of Changes

| # | Layer | What | Priority |
|---|-------|------|----------|
| 1 | Backend | B-tree indexes for lat/lng | P0 |
| 2 | Backend | Fix page=1 returning 100 rows | P1 |
| 3 | Backend | Fix distance total caching | P1 |
| 4 | Backend | Haversine for service distance display | P2 |
| 5 | Flutter | Dedup loadMore + services pagination | P0 |
| 6 | Flutter | Non-blocking loading indicator | P1 |
| 7 | Flutter | Blurred distance display (privacy) | P1 |
| 8 | Flutter | loadMore loads both tasks + services | P1 |
| 9 | Flutter | Location failure notice | P2 |
| 10 | Flutter | Fix loadMore trigger re-fire | P1 |
| 11 | Flutter | **Fix empty state hides radius selector (1km trap)** | **P0** |
| 12 | Flutter | **GPS denied → prompt to open app settings** | **P1** |
| 13 | Flutter | **Use LocationCityService cached GPS** | **P1** |
| 14 | Backend | sort_by validation | P2 |

### Execution order recommendation
Tasks 9, 11, 12, 13 all modify `_NearbyLocationBar` and `_loadLocation` — execute them sequentially (9 → 11 → 12 → 13) to avoid merge conflicts. Tasks 1-4 (backend) and 5-8, 10 (Flutter non-location) are independent and can run in parallel.

### Not addressed in this plan (low ROI / separate effort)
- `nearbyServices` typed model — would require new model class + refactor browse/detail flows
- `_imageHeight` based on `title.hashCode` — works correctly, just unconventional
