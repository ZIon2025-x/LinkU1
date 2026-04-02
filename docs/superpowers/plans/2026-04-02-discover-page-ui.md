# 发现页 (Discover Page) UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the community tab with a "发现" (Discover) page matching mockup `homepage_mockups/option_A_discover.html` — 7 modules: search, trending, boards, leaderboards, skill categories, recommended experts, activities.

**Architecture:** New `DiscoverBloc` orchestrates loading data from 5 existing repositories (TrendingSearch, Forum, Leaderboard, TaskExpert, Activity). New `DiscoverView` replaces `ForumView` on the `/community` tab. ForumView remains available at `/forum` route. User's city (`residenceCity`) drives location-based filtering for leaderboards, experts, and activities.

**Tech Stack:** Flutter, BLoC, Equatable, existing ApiService/repositories

**Mockup reference:** `homepage_mockups/option_A_discover.html`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `lib/features/discover/bloc/discover_bloc.dart` | BLoC + events + states (parts) — loads all 7 modules |
| `lib/features/discover/bloc/discover_event.dart` | Part file: events |
| `lib/features/discover/bloc/discover_state.dart` | Part file: state |
| `lib/features/discover/views/discover_view.dart` | Main discover page with all 7 sections |

### Modified Files
| File | Change |
|------|--------|
| `lib/data/models/forum.dart` | Add `serviceCount`, `taskCount`, `viewCount` to ForumCategory |
| `lib/data/repositories/activity_repository.dart` | Add `location` and `sortBy` params to `getActivities()` |
| `lib/core/router/app_router.dart` | Change `/community` tab from ForumView to DiscoverView |
| `lib/app_providers.dart` | No change needed — repositories already registered, DiscoverBloc created at route level |

### Unchanged (reused as-is)
| File | Usage |
|------|-------|
| `lib/data/repositories/trending_search_repository.dart` | Trending searches |
| `lib/data/repositories/forum_repository.dart` | Categories + hot posts |
| `lib/data/repositories/leaderboard_repository.dart` | Leaderboards (already has `location` param) |
| `lib/data/repositories/task_expert_repository.dart` | Experts (already has `location` + `sort` params) |
| `lib/data/repositories/activity_repository.dart` | Activities (after modification) |
| `lib/data/models/trending_search.dart` | TrendingSearchItem model |
| `lib/data/models/leaderboard.dart` | Leaderboard model |
| `lib/data/models/forum.dart` | ForumCategory, ForumPost models |

---

## Task 1: Update ForumCategory model

**Files:**
- Modify: `lib/data/models/forum.dart` — ForumCategory class

- [ ] **Step 1: Add fields to ForumCategory**

In `lib/data/models/forum.dart`, add three fields to the ForumCategory class:

```dart
// Add after postCount field (~line 74):
final int serviceCount;
final int taskCount;
final int viewCount;
```

Update constructor to include them with defaults:

```dart
this.serviceCount = 0,
this.taskCount = 0,
this.viewCount = 0,
```

Update `fromJson` factory:

```dart
serviceCount: json['service_count'] as int? ?? 0,
taskCount: json['task_count'] as int? ?? 0,
viewCount: json['view_count'] as int? ?? 0,
```

Update `copyWith` method to include all three fields.

Update `props` list to include all three fields.

- [ ] **Step 2: Verify no compile errors**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/data/models/forum.dart`

Expected: No errors

- [ ] **Step 3: Commit**

```
feat: add serviceCount/taskCount/viewCount to ForumCategory model
```

---

## Task 2: Update ActivityRepository — add location and sortBy params

**Files:**
- Modify: `lib/data/repositories/activity_repository.dart` — `getActivities()` method

- [ ] **Step 1: Add parameters**

In `getActivities()` method signature (~line 24), add two optional params:

```dart
Future<ActivityListResponse> getActivities({
  int page = 1,
  int pageSize = 20,
  String? status,
  String? keyword,
  bool? hasTimeSlots,
  String? expertId,
  String? location,     // NEW
  String? sortBy,       // NEW: 'view_count'
  CancelToken? cancelToken,
}) async {
```

In the query params map inside the method, add:

```dart
if (location != null && location.isNotEmpty) 'location': location,
if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
```

- [ ] **Step 2: Verify no compile errors**

Run: `flutter analyze lib/data/repositories/activity_repository.dart`

Expected: No errors

- [ ] **Step 3: Commit**

```
feat: add location and sortBy params to ActivityRepository.getActivities
```

---

## Task 3: Create DiscoverBloc — events and state

**Files:**
- Create: `lib/features/discover/bloc/discover_event.dart`
- Create: `lib/features/discover/bloc/discover_state.dart`
- Create: `lib/features/discover/bloc/discover_bloc.dart`

- [ ] **Step 1: Create discover_event.dart**

```dart
part of 'discover_bloc.dart';

abstract class DiscoverEvent extends Equatable {
  const DiscoverEvent();
  @override
  List<Object?> get props => [];
}

/// 初始化加载所有模块
class DiscoverLoadRequested extends DiscoverEvent {
  const DiscoverLoadRequested();
}

/// 下拉刷新
class DiscoverRefreshRequested extends DiscoverEvent {
  const DiscoverRefreshRequested();
}
```

- [ ] **Step 2: Create discover_state.dart**

```dart
part of 'discover_bloc.dart';

enum DiscoverStatus { initial, loading, loaded, error }

class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.trendingSearches = const [],
    this.hotPosts = const [],
    this.boards = const [],
    this.leaderboards = const [],
    this.skillCategories = const [],
    this.experts = const [],
    this.activities = const [],
    this.errorMessage,
    this.userCity,
  });

  final DiscoverStatus status;
  final List<TrendingSearchItem> trendingSearches;
  final List<ForumPost> hotPosts;
  final List<ForumCategory> boards;        // non-skill visible categories
  final List<Leaderboard> leaderboards;
  final List<ForumCategory> skillCategories; // skill_type != null, top 6 by viewCount
  final List<dynamic> experts;              // raw JSON maps from API
  final List<Activity> activities;
  final String? errorMessage;
  final String? userCity;

  DiscoverState copyWith({
    DiscoverStatus? status,
    List<TrendingSearchItem>? trendingSearches,
    List<ForumPost>? hotPosts,
    List<ForumCategory>? boards,
    List<Leaderboard>? leaderboards,
    List<ForumCategory>? skillCategories,
    List<dynamic>? experts,
    List<Activity>? activities,
    String? errorMessage,
    String? userCity,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      trendingSearches: trendingSearches ?? this.trendingSearches,
      hotPosts: hotPosts ?? this.hotPosts,
      boards: boards ?? this.boards,
      leaderboards: leaderboards ?? this.leaderboards,
      skillCategories: skillCategories ?? this.skillCategories,
      experts: experts ?? this.experts,
      activities: activities ?? this.activities,
      errorMessage: errorMessage,
      userCity: userCity ?? this.userCity,
    );
  }

  @override
  List<Object?> get props => [
    status, trendingSearches, hotPosts, boards, leaderboards,
    skillCategories, experts, activities, errorMessage, userCity,
  ];
}
```

- [ ] **Step 3: Create discover_bloc.dart**

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/core/utils/logger.dart';
import 'package:link2ur/data/models/activity.dart';
import 'package:link2ur/data/models/forum.dart';
import 'package:link2ur/data/models/leaderboard.dart';
import 'package:link2ur/data/models/trending_search.dart';
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/data/repositories/leaderboard_repository.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
import 'package:link2ur/data/repositories/trending_search_repository.dart';
import 'package:link2ur/data/services/storage_service.dart';

part 'discover_event.dart';
part 'discover_state.dart';

class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  DiscoverBloc({
    required TrendingSearchRepository trendingSearchRepository,
    required ForumRepository forumRepository,
    required LeaderboardRepository leaderboardRepository,
    required TaskExpertRepository taskExpertRepository,
    required ActivityRepository activityRepository,
  })  : _trendingRepo = trendingSearchRepository,
        _forumRepo = forumRepository,
        _leaderboardRepo = leaderboardRepository,
        _expertRepo = taskExpertRepository,
        _activityRepo = activityRepository,
        super(const DiscoverState()) {
    on<DiscoverLoadRequested>(_onLoad);
    on<DiscoverRefreshRequested>(_onRefresh);
  }

  final TrendingSearchRepository _trendingRepo;
  final ForumRepository _forumRepo;
  final LeaderboardRepository _leaderboardRepo;
  final TaskExpertRepository _expertRepo;
  final ActivityRepository _activityRepo;

  Future<void> _onLoad(DiscoverLoadRequested event, Emitter<DiscoverState> emit) async {
    if (state.status == DiscoverStatus.loading) return;
    emit(state.copyWith(status: DiscoverStatus.loading));

    // Get user city for location-based filtering
    final userInfo = await StorageService.instance.getUserInfo();
    final city = userInfo?['residence_city'] as String?;

    await _loadAll(emit, city);
  }

  Future<void> _onRefresh(DiscoverRefreshRequested event, Emitter<DiscoverState> emit) async {
    final city = state.userCity;
    await _loadAll(emit, city);
  }

  Future<void> _loadAll(Emitter<DiscoverState> emit, String? city) async {
    try {
      // Fire all requests in parallel
      final results = await Future.wait([
        _loadTrending(),
        _loadHotPosts(),
        _loadCategories(),
        _loadLeaderboards(city),
        _loadExperts(city),
        _loadActivities(city),
      ]);

      final allCategories = results[2] as List<ForumCategory>;

      // Split categories: boards (non-skill) and skill categories
      final boards = allCategories
          .where((c) => c.skillType == null || c.skillType!.isEmpty)
          .toList();
      final skillCats = allCategories
          .where((c) => c.skillType != null && c.skillType!.isNotEmpty)
          .toList()
        ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
      final topSkillCats = skillCats.take(6).toList();

      emit(state.copyWith(
        status: DiscoverStatus.loaded,
        trendingSearches: results[0] as List<TrendingSearchItem>,
        hotPosts: results[1] as List<ForumPost>,
        boards: boards,
        leaderboards: results[3] as List<Leaderboard>,
        skillCategories: topSkillCats,
        experts: results[4] as List<dynamic>,
        activities: results[5] as List<Activity>,
        userCity: city,
      ));
    } catch (e) {
      AppLogger.error('Discover load failed', e);
      emit(state.copyWith(
        status: DiscoverStatus.error,
        errorMessage: 'discover_load_failed',
      ));
    }
  }

  Future<List<TrendingSearchItem>> _loadTrending() async {
    try {
      final response = await _trendingRepo.getTrendingSearches();
      return response.items;
    } catch (e) {
      AppLogger.error('Trending load failed', e);
      return [];
    }
  }

  Future<List<ForumPost>> _loadHotPosts() async {
    try {
      final response = await _forumRepo.getHotPosts(page: 1, pageSize: 5);
      return response.posts;
    } catch (e) {
      AppLogger.error('Hot posts load failed', e);
      return [];
    }
  }

  Future<List<ForumCategory>> _loadCategories() async {
    try {
      return await _forumRepo.getVisibleCategories();
    } catch (e) {
      AppLogger.error('Categories load failed', e);
      return [];
    }
  }

  Future<List<Leaderboard>> _loadLeaderboards(String? city) async {
    try {
      final response = await _leaderboardRepo.getLeaderboards(
        page: 1,
        pageSize: 10,
        location: city,
      );
      return response.leaderboards;
    } catch (e) {
      AppLogger.error('Leaderboards load failed', e);
      return [];
    }
  }

  Future<List<dynamic>> _loadExperts(String? city) async {
    try {
      return await _expertRepo.getExperts(
        page: 1,
        pageSize: 3,
        location: city,
        sort: 'random',
      );
    } catch (e) {
      AppLogger.error('Experts load failed', e);
      return [];
    }
  }

  Future<List<Activity>> _loadActivities(String? city) async {
    try {
      final response = await _activityRepo.getActivities(
        page: 1,
        pageSize: 3,
        location: city,
        sortBy: 'view_count',
      );
      return response.activities;
    } catch (e) {
      AppLogger.error('Activities load failed', e);
      return [];
    }
  }
}
```

**Important notes for implementation:**
- Check `ForumRepository.getHotPosts()` return type — it returns a response object with a `posts` field. Verify the exact field name in `lib/data/repositories/forum_repository.dart` around line 656.
- Check `LeaderboardRepository.getLeaderboards()` return type — verify if it returns `response.leaderboards` or `response.items`. Check `lib/data/repositories/leaderboard_repository.dart` around line 20.
- Check `TaskExpertRepository.getExperts()` return type — it may return `List<dynamic>` (raw JSON maps) or typed objects. Check `lib/data/repositories/task_expert_repository.dart` around line 20.
- Check `ActivityRepository.getActivities()` return type — verify `response.activities` field name. Check `lib/data/repositories/activity_repository.dart`.
- Adjust field names and types as needed after verifying actual return types.

- [ ] **Step 4: Verify no compile errors**

Run: `flutter analyze lib/features/discover/`

Expected: No errors (may have warnings about unused imports until the view is created)

- [ ] **Step 5: Commit**

```
feat: create DiscoverBloc with parallel data loading for all 7 modules
```

---

## Task 4: Create DiscoverView — main page

**Files:**
- Create: `lib/features/discover/views/discover_view.dart`

This is the largest task. The view should match mockup A's layout:

1. **Header** — search bar + camera icon
2. **Trending** — 🔥 热搜榜 (5 items with rank, keyword, tag, heat)
3. **Boards** — 🏷️ 热门板块 (horizontal scroll cards, exclude skill categories)
4. **Leaderboards** — 🏆 热门榜单 (horizontal scroll cards)
5. **Skill Categories** — 📂 技能分类 (2x3 grid with gradient backgrounds)
6. **Experts** — ✨ 推荐达人 (3 expert cards with follow button)
7. **Activities** — 🎪 热门活动 (horizontal scroll cards)

- [ ] **Step 1: Create the discover_view.dart file**

Build a `DiscoverView` StatelessWidget that:
- Creates `DiscoverBloc` via `BlocProvider` (read repositories from context)
- Dispatches `DiscoverLoadRequested` on init
- Uses `BlocBuilder<DiscoverBloc, DiscoverState>` to render
- Loading state: `SkeletonList` or shimmer
- Error state: `ErrorStateView` with retry
- Loaded state: `CustomScrollView` with slivers for each section

Each section should be a private widget (e.g., `_TrendingSection`, `_BoardsSection`, etc.) that takes the relevant data as constructor params.

**Section-specific requirements:**

**Trending section:**
- Show "暂无热搜" when empty
- Top 3 ranks in red (#FF2D55), rest gray
- Tag badges: hot (pink), new (blue), up (green) — same as existing `_TagBadge` in forum_view.dart
- Tap keyword → navigate to `/search?q={keyword}`

**Boards section:**
- Horizontal scroll, 140px wide cards with gradient bg + icon + name + post count
- Exclude categories where `skillType` is not null
- Student categories (type=root, type=university) included if user has access (they come from visible endpoint)
- Tap → navigate to `/forum/category/{id}` or `/forum/skill/{id}`

**Leaderboards section:**
- Horizontal scroll, 200px wide cards
- Show cover image, name, location, stats (item count, vote count, view count)
- Tap → navigate to `/leaderboard/{id}`

**Skill categories section:**
- 2-column grid, top 6 by viewCount
- Gradient background cards with icon + name + stats line: "XX帖子 · XX服务 · XX任务"
- Uses `postCount`, `serviceCount`, `taskCount` from ForumCategory
- Tap → navigate to `/forum/skill/{id}`

**Experts section:**
- Vertical list, 3 experts
- Avatar + name + verified badge + description + skill tags + follow button
- Follow button calls `FollowRepository.followUser(expertId)`
- Hide section if empty

**Activities section:**
- Horizontal scroll cards
- Image/icon + title + date + participant count + price/free button
- Hide section if empty
- Tap → navigate to activity detail

**Styling notes:**
- Follow existing design system: `AppColors`, `AppTypography`, `AppRadius`, `AppSpacing` from `core/design/`
- Use `context.l10n` for all user-facing strings
- Add localization keys for section titles and empty states to all 3 ARB files

- [ ] **Step 2: Add localization keys**

Add to all 3 ARB files (`lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`):

```
"discoverTitle": "发现" / "Discover" / "發現"
"discoverTrending": "热搜榜" / "Trending" / "熱搜榜"
"discoverNoTrending": "暂无热搜" / "No trending searches" / "暫無熱搜"
"discoverBoards": "热门板块" / "Popular Boards" / "熱門板塊"
"discoverLeaderboards": "热门榜单" / "Leaderboards" / "熱門榜單"
"discoverSkillCategories": "技能分类" / "Skill Categories" / "技能分類"
"discoverExperts": "推荐达人" / "Recommended Experts" / "推薦達人"
"discoverActivities": "热门活动" / "Popular Activities" / "熱門活動"
"discoverSearchHint": "搜索技能、达人、话题..." / "Search skills, experts, topics..." / "搜索技能、達人、話題..."
"discoverViewAll": "全部" / "View All" / "全部"
"discoverFree": "免费参加" / "Free" / "免費參加"
"discoverNPosts": "{count} 帖子" / "{count} posts" / "{count} 帖子"
"discoverNServices": "{count} 服务" / "{count} services" / "{count} 服務"  
"discoverNTasks": "{count} 任务" / "{count} tasks" / "{count} 任務"
"discoverNItems": "{count} 项目" / "{count} items" / "{count} 項目"
"discoverFollow": "关注" / "Follow" / "關注"
```

- [ ] **Step 3: Verify no compile errors**

Run: `flutter analyze lib/features/discover/`

- [ ] **Step 4: Commit**

```
feat: create DiscoverView with 7 modules matching mockup A
```

---

## Task 5: Update router — community tab uses DiscoverView

**Files:**
- Modify: `lib/core/router/app_router.dart` — community tab route

- [ ] **Step 1: Update the /community route**

Find the `/community` branch in `StatefulShellRoute.indexedStack` (around line 133-144). Change:

```dart
// Before:
Widget: ForumView()

// After:
Widget: DiscoverView()
```

Add import: `import 'package:link2ur/features/discover/views/discover_view.dart';`

The DiscoverView should wrap itself in a `BlocProvider<DiscoverBloc>` internally (reading repositories from context), so the route definition stays simple.

- [ ] **Step 2: Verify the /forum route still exists**

The `/forum` route (which renders `ForumView(showLeaderboardTab: false)`) should remain unchanged. Users can still navigate to the full forum view from within the discover page (e.g., "全部 ›" links).

- [ ] **Step 3: Verify no compile errors**

Run: `flutter analyze lib/core/router/`

- [ ] **Step 4: Commit**

```
feat: replace community tab with DiscoverView
```

---

## Task 6: Integration testing and polish

- [ ] **Step 1: Run full analyze**

Run: `flutter analyze`

Fix any warnings or errors.

- [ ] **Step 2: Run existing tests**

Run: `flutter test`

Fix any broken tests (e.g., if tests reference ForumView on community tab).

- [ ] **Step 3: Manual testing checklist**

Test on web (`flutter run -d web-server`):

- [ ] Discover page loads all 7 sections
- [ ] Trending shows items with correct tags (hot/new/up)
- [ ] Trending empty state shows "暂无热搜"
- [ ] Boards horizontal scroll works, skill categories excluded
- [ ] Leaderboards horizontal scroll works
- [ ] Skill categories grid shows top 6 with correct stats
- [ ] Experts section shows 3 experts with follow button
- [ ] Activities hidden when no activities
- [ ] Pull-to-refresh works
- [ ] Search bar taps navigate to search
- [ ] Card taps navigate to correct detail pages
- [ ] `/forum` route still works independently

- [ ] **Step 4: Final commit**

```
fix: polish discover page and fix integration issues
```

---

## Notes

- **No TDD for UI:** This is primarily UI/view code. Flutter widget tests for views are high-maintenance and low-value for this initial implementation. The BLoC can be unit tested later if needed.
- **Expert return type:** `TaskExpertRepository.getExperts()` returns `List<dynamic>` (raw JSON maps). Access fields like `expert['name']`, `expert['avatar']`, `expert['id']`, etc.
- **ForumRepository.getHotPosts():** Verify exact return type. May need to check if it returns `ForumPostListResponse` with `.posts` field or similar.
- **Gradients for skill cards:** Use different gradient colors per index (cycle through 6 predefined gradients matching mockup A colors).
- **Follow button:** Use `FollowRepository` from context. Call `followUser(expertId)`. Toggle button state optimistically.
- **Bottom nav tab name:** The tab label in bottom nav should change from "社区" to "发现" — update in the bottom nav widget and ARB files.
