# Home AppBar & Nearby Tab Redesign

**Date:** 2026-03-24
**Status:** Approved

## Summary

1. Replace the top-left location picker with a menu button that opens a Drawer
2. Redesign the Nearby tab to use a xiaohongshu-style waterfall grid with distance badges

## Motivation

The location picker in the AppBar misleads users into thinking location affects the entire feed, but the discovery feed has no location-based sorting. Location is only relevant to the Nearby tab, so move it there.

---

## 1. AppBar: Location → Menu Button + Drawer

### AppBar Changes (`home_view.dart` → `_buildMobileAppBar`)

**Remove:**
- Location icon + city text + dropdown arrow (lines 253-293)
- `_showLocationPicker()` method (lines 343-428)
- Imports: `city_display_helper`, `location_picker`, `geocoding`, `geolocator` (moved to `home_task_cards.dart`)

**Replace with:**
- `Icons.menu` button, same 72×44 SizedBox for symmetry with right-side search button
- `onTap` → `Scaffold.of(context).openDrawer()`

### Drawer (`home_view.dart` → `_buildMobileHome`)

Add `drawer:` parameter to Scaffold. Content:

- **Header:** User avatar + name (from AuthBloc). If not logged in, show "Log in" button → `/login`
- **Menu items:**
  - My Tasks (`/my-tasks`)
  - My Wallet (`/wallet`)
  - Settings (`/settings`)
  - Help & Feedback (`/feedback`)
- **Footer:** App version number

### Desktop: No changes
Desktop layout (`_buildDesktopHome`) has no location picker, so no changes needed.

---

## 2. Nearby Tab: Waterfall Grid

### Layout Structure (`home_task_cards.dart` → `_NearbyTab`)

```
┌──────────────────────────────────┐
│ 📍 当前定位：伦敦 · [切换]       │  ← Location bar (tappable "切换")
├──────────────────────────────────┤
│ [5km] [10km] [25km] [50km]      │  ← Radius selector (keep existing)
├───────────────┬──────────────────┤
│ ┌───────────┐ │ ┌──────────────┐ │
│ │  image     │ │ │   image      │ │
│ │ 📍 0.8km  │ │ │  📍 1.2km   │ │
│ ├───────────┤ │ ├──────────────┤ │
│ │ Title     │ │ │ Title        │ │
│ │ [tag] £80 │ │ │ [tag] £25/h  │ │
│ │ 3人申请   │ │ │ 5人申请      │ │
│ └───────────┘ │ └──────────────┘ │
│ ┌───────────┐ │                  │
│ │  ...      │ │                  │
└───────────────┴──────────────────┘
```

### Location Bar (new widget)

- Text: `📍 当前定位：{city} · 切换`
- "切换" is tappable, opens the existing `LocationInputField` bottom sheet (moved from AppBar)
- City comes from `_city` local state (existing `_resolveCity` logic)
- Also updates `HomeBloc.locationCity` for persistence

### Waterfall Card Design

Each card in `MasonryGridView.count(crossAxisCount: 2)`:

- **Image area:** Task/service first image or gradient placeholder. Variable height (staggered).
- **Distance badge:** Bottom-left of image, frosted glass style: `📍 {distance}km`
- **Card body:**
  - Title (2 lines max, ellipsis)
  - Tags row: category tag + price tag (colored)
  - Applicant count: `{n}人申请` or localized equivalent
- **No:** author avatar, author name, like count

### Data Source

Mix `state.nearbyTasks` and `state.nearbyServices` into a single list, sorted by distance. Each item already has distance calculated by `_haversineDistance` in HomeBloc. Services need distance added (use same formula from coordinates).

### Card Tap

- Task → `context.goToTaskDetail(id)`
- Service → `context.push('/personal-services/$id')`

---

## 3. Cleanup

- Remove `city_display_helper` import from `home_view.dart` (only used in AppBar location display)
- `location_picker` import stays — needed by nearby tab's location bar sheet
- `geocoding` and `geolocator` imports stay — used by `_NearbyTabState`
- `HomeLocationCityUpdated` event: keep in bloc, now dispatched from nearby tab only
- `locationCity` state field: keep for persistence across tab switches

---

## Files Changed

| File | Change |
|------|--------|
| `home_view.dart` | Replace location picker with menu button, add Drawer, remove `_showLocationPicker` |
| `home_task_cards.dart` | Rewrite `_NearbyTab` build: location bar + radius selector + waterfall grid |
| `home_task_cards.dart` | Add `_NearbyWaterfallCard` widget |
| `home_bloc.dart` | No changes needed |
| `home_state.dart` | No changes needed |
| `home_event.dart` | No changes needed |
