# Homepage Feed Redesign — Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Flutter home page from 3-tab to 5-tab Xiaohongshu-style layout with unified waterfall feed.

**Architecture:** Modify existing HomeBloc/HomeView to support 5 tabs. Add new repositories (Follow, Ticker). Update DiscoveryFeedItem model for new feed types. Create new card widgets for task/activity/completion in the waterfall.

**Tech Stack:** Flutter/Dart, BLoC, GoRouter

**Spec:** `docs/superpowers/specs/2026-03-23-homepage-feed-redesign-frontend.md`

---

### Task 1: Data Layer — Models, Repositories, API Endpoints

**Files:**
- Modify: `link2ur/lib/data/models/discovery_feed.dart`
- Create: `link2ur/lib/data/repositories/follow_repository.dart`
- Create: `link2ur/lib/data/repositories/ticker_repository.dart`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: Add new API endpoints**

In `link2ur/lib/core/constants/api_endpoints.dart`, add:

```dart
// Follow system
static const String followUser = '/api/users'; // POST /api/users/{userId}/follow
static const String followFeed = '/api/follow/feed';

// Ticker
static const String feedTicker = '/api/feed/ticker';
```

- [ ] **Step 2: Update DiscoveryFeedItem model for new feed types**

In `link2ur/lib/data/models/discovery_feed.dart`, add getters for new types:

```dart
  /// 是否是任务
  bool get isTask => feedType == 'task';

  /// 是否是活动
  bool get isActivity => feedType == 'activity';

  /// 是否是完成记录（仅关注 Feed）
  bool get isCompletion => feedType == 'completion';

  // Task-specific getters (from extra_data)
  String? get taskType => extraData?['task_type'];
  double? get reward => extraData?['reward'] != null ? (extraData!['reward'] as num).toDouble() : null;
  String? get taskLocation => extraData?['location'];
  String? get taskDeadline => extraData?['deadline'];
  int? get applicationCount => extraData?['application_count'];
  double? get matchScore => extraData?['match_score'] != null ? (extraData!['match_score'] as num).toDouble() : null;
  String? get recommendationReason => extraData?['recommendation_reason'];
  bool? get rewardToBeQuoted => extraData?['reward_to_be_quoted'];

  // Activity-specific getters (from activity_info)
  String? get activityType => activityInfo?.activityType;
  int? get maxParticipants => activityInfo?.maxParticipants;
  int? get currentParticipants => activityInfo?.currentParticipants;
```

Also check that the `ActivityBrief` model in the same file has `maxParticipants` and `currentParticipants` fields. If not, add them.

- [ ] **Step 3: Create FollowRepository**

Create `link2ur/lib/data/repositories/follow_repository.dart`:

```dart
import '../services/api_service.dart';
import '../models/discovery_feed.dart';

class FollowRepository {
  FollowRepository({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  /// Follow a user
  Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/api/users/$userId/follow',
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'follow_failed');
    }
    return response.data!;
  }

  /// Unfollow a user
  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    final response = await _apiService.delete<Map<String, dynamic>>(
      '/api/users/$userId/follow',
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'unfollow_failed');
    }
    return response.data!;
  }

  /// Get followers list
  Future<Map<String, dynamic>> getFollowers(String userId, {int page = 1, int pageSize = 20}) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/api/users/$userId/followers',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'get_followers_failed');
    }
    return response.data!;
  }

  /// Get following list
  Future<Map<String, dynamic>> getFollowing(String userId, {int page = 1, int pageSize = 20}) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/api/users/$userId/following',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'get_following_failed');
    }
    return response.data!;
  }

  /// Get follow feed (timeline of followed users' content)
  Future<DiscoveryFeedResponse> getFollowFeed({int page = 1, int pageSize = 20}) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/api/follow/feed',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'get_follow_feed_failed');
    }
    return DiscoveryFeedResponse.fromJson(response.data!);
  }
}
```

- [ ] **Step 4: Create TickerRepository**

Create `link2ur/lib/data/repositories/ticker_repository.dart`:

```dart
import '../services/api_service.dart';

class TickerItem {
  TickerItem({required this.textZh, required this.textEn, this.linkType, this.linkId});

  final String textZh;
  final String textEn;
  final String? linkType;
  final String? linkId;

  factory TickerItem.fromJson(Map<String, dynamic> json) => TickerItem(
    textZh: json['text_zh'] ?? '',
    textEn: json['text_en'] ?? '',
    linkType: json['link_type'],
    linkId: json['link_id'],
  );

  String displayText(String locale) => locale.startsWith('en') ? textEn : textZh;
}

class TickerRepository {
  TickerRepository({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  Future<List<TickerItem>> getTicker() async {
    final response = await _apiService.get<Map<String, dynamic>>('/api/feed/ticker');
    if (!response.isSuccess || response.data == null) return [];
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => TickerItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

- [ ] **Step 5: Register repositories in app_providers.dart**

Add `FollowRepository` and `TickerRepository` to `MultiRepositoryProvider` in `link2ur/lib/app_providers.dart`, following existing patterns.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add data layer for homepage feed redesign (models, repos, endpoints)"
```

---

### Task 2: HomeBloc — Expand State and Events for 5 Tabs

**Files:**
- Modify: `link2ur/lib/features/home/bloc/home_event.dart`
- Modify: `link2ur/lib/features/home/bloc/home_state.dart`
- Modify: `link2ur/lib/features/home/bloc/home_bloc.dart`

- [ ] **Step 1: Add new events**

In `home_event.dart`, add:

```dart
/// Load follow feed
class HomeLoadFollowFeed extends HomeEvent {
  const HomeLoadFollowFeed({this.loadMore = false});
  final bool loadMore;
}

/// Load ticker data
class HomeLoadTicker extends HomeEvent {
  const HomeLoadTicker();
}

/// Load activities list (for Activities tab)
class HomeLoadActivitiesList extends HomeEvent {
  const HomeLoadActivitiesList({this.loadMore = false});
  final bool loadMore;
}
```

- [ ] **Step 2: Expand state**

In `home_state.dart`, add fields:

```dart
  // Follow feed
  final List<DiscoveryFeedItem> followFeedItems;
  final bool isLoadingFollowFeed;
  final bool hasMoreFollowFeed;
  final int followFeedPage;

  // Ticker
  final List<TickerItem> tickerItems;

  // Activities tab (separate from openActivities in recommended section)
  final List<Activity> activitiesListItems;
  final bool isLoadingActivitiesList;
  final bool hasMoreActivitiesList;
  final int activitiesListPage;
```

Update `copyWith()`, constructor defaults, and `props` list accordingly.

Change default `currentTab` from `1` to `1` (still Recommend, but now index 1 out of 5).

- [ ] **Step 3: Add event handlers in HomeBloc**

Add handlers for the new events. The bloc constructor needs `FollowRepository` and `TickerRepository` injected.

```dart
// In constructor:
on<HomeLoadFollowFeed>(_onLoadFollowFeed);
on<HomeLoadTicker>(_onLoadTicker);
on<HomeLoadActivitiesList>(_onLoadActivitiesList);

// Handler for follow feed:
Future<void> _onLoadFollowFeed(HomeLoadFollowFeed event, Emitter<HomeState> emit) async {
  if (state.isLoadingFollowFeed) return;
  final page = event.loadMore ? state.followFeedPage + 1 : 1;
  emit(state.copyWith(isLoadingFollowFeed: true));
  try {
    final response = await _followRepository.getFollowFeed(page: page);
    final items = event.loadMore
        ? [...state.followFeedItems, ...response.items]
        : response.items;
    emit(state.copyWith(
      followFeedItems: items,
      followFeedPage: page,
      hasMoreFollowFeed: response.hasMore,
      isLoadingFollowFeed: false,
    ));
  } catch (e) {
    emit(state.copyWith(isLoadingFollowFeed: false, errorMessage: e.toString()));
  }
}

// Handler for ticker:
Future<void> _onLoadTicker(HomeLoadTicker event, Emitter<HomeState> emit) async {
  try {
    final items = await _tickerRepository.getTicker();
    emit(state.copyWith(tickerItems: items));
  } catch (e) {
    // Ticker is non-critical — silently ignore
  }
}

// Handler for activities list:
Future<void> _onLoadActivitiesList(HomeLoadActivitiesList event, Emitter<HomeState> emit) async {
  if (state.isLoadingActivitiesList) return;
  final page = event.loadMore ? state.activitiesListPage + 1 : 1;
  emit(state.copyWith(isLoadingActivitiesList: true));
  try {
    final activities = await _activityRepository.getActivities(
      status: 'open',
      page: page,
    );
    final items = event.loadMore
        ? [...state.activitiesListItems, ...activities]
        : activities;
    emit(state.copyWith(
      activitiesListItems: items,
      activitiesListPage: page,
      hasMoreActivitiesList: activities.length >= 20,
      isLoadingActivitiesList: false,
    ));
  } catch (e) {
    emit(state.copyWith(isLoadingActivitiesList: false, errorMessage: e.toString()));
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: expand HomeBloc for 5-tab layout (follow feed, ticker, activities)"
```

---

### Task 3: HomeView — 5-Tab Layout

**Files:**
- Modify: `link2ur/lib/features/home/views/home_view.dart`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add localization keys**

In all 3 ARB files, add:

```json
"homeFollow": "关注",
"homeActivities": "活动",
"homeFeedTicker": "动态",
"homeOnlineCount": "{count}人在线",
```

English:
```json
"homeFollow": "Following",
"homeActivities": "Events",
"homeFeedTicker": "Live",
"homeOnlineCount": "{count} online",
```

- [ ] **Step 2: Update HomeView to 5 tabs**

In `home_view.dart`:

1. Change `_selectedTab` default from `1` to `1` (Recommend is still index 1)
2. Change tab count from 3 to 5
3. Update tab labels: Follow, Recommend, Nearby, Experts, Activities
4. Update `_visitedTabs` initial set to `{1}` (still default Recommend)
5. Update PageView `itemCount` to 5
6. Add lazy-loading triggers: when switching to Follow tab → dispatch `HomeLoadFollowFeed()` + `HomeLoadTicker()`; Activities tab → dispatch `HomeLoadActivitiesList()`

Tab labels:
```dart
final tabLabels = [
  context.l10n.homeFollow,      // 0: 关注
  context.l10n.homeRecommended,  // 1: 推荐
  context.l10n.homeNearby,       // 2: 附近
  context.l10n.homeExperts,      // 3: 达人
  context.l10n.homeActivities,   // 4: 活动
];
```

Tab content:
```dart
// In PageView children:
_FollowTab(),           // 0
_RecommendedTab(),      // 1 (existing, will be redesigned in Task 4)
_NearbyTab(),           // 2 (existing, unchanged)
_ExpertsTab(),          // 3 (existing, moved from index 0)
_ActivitiesTab(),       // 4 (new)
```

- [ ] **Step 3: Create _FollowTab widget**

Simple placeholder initially — will show follow feed items using the same waterfall/list as discovery feed. If user is not logged in, show a login prompt.

```dart
class _FollowTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (p, c) =>
          p.followFeedItems != c.followFeedItems ||
          p.isLoadingFollowFeed != c.isLoadingFollowFeed,
      builder: (context, state) {
        if (state.isLoadingFollowFeed && state.followFeedItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.followFeedItems.isEmpty) {
          return Center(child: Text('关注用户后这里将显示他们的动态'));
        }
        return ListView.builder(
          itemCount: state.followFeedItems.length,
          itemBuilder: (context, index) {
            // Reuse discovery card builder
            return _buildFeedCard(context, state.followFeedItems[index]);
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: Create _ActivitiesTab widget**

```dart
class _ActivitiesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (p, c) =>
          p.activitiesListItems != c.activitiesListItems ||
          p.isLoadingActivitiesList != c.isLoadingActivitiesList,
      builder: (context, state) {
        if (state.isLoadingActivitiesList && state.activitiesListItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.activitiesListItems.isEmpty) {
          return Center(child: Text(context.l10n.homeNoNearbyTasks));
        }
        return ListView.builder(
          itemCount: state.activitiesListItems.length,
          itemBuilder: (context, index) {
            final activity = state.activitiesListItems[index];
            // Reuse existing activity card widget
            return ActivityListCard(activity: activity);
          },
        );
      },
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: home page 5-tab layout (Follow, Recommend, Nearby, Experts, Activities)"
```

---

### Task 4: Recommend Tab — Story Row + Ticker + Waterfall

**Files:**
- Modify: `link2ur/lib/features/home/views/home_recommended_section.dart`
- Modify: `link2ur/lib/features/home/views/home_widgets.dart` (ticker widget)

This is the main visual redesign of the Recommend tab.

- [ ] **Step 1: Create Story Row widget**

Add to `home_recommended_section.dart` (or a new `home_story_row.dart`):

A horizontal scrollable row of circular icons, each navigating to a page:

```dart
class _StoryRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final entries = [
      _StoryEntry(emoji: '🤖', label: 'Linker AI', onTap: () => context.push('/ai-chat')),
      _StoryEntry(emoji: '📐', label: context.l10n.homeExperts, onTap: () => /* switch to experts tab */),
      _StoryEntry(emoji: '🛒', label: '跳蚤市场', onTap: () => context.push('/flea-market')),
      // ... more entries
    ];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => entries[i],
      ),
    );
  }
}
```

- [ ] **Step 2: Create Ticker widget**

Scrolling text overlay that rotates through ticker items:

```dart
class _TickerBar extends StatefulWidget { ... }

class _TickerBarState extends State<_TickerBar> {
  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() => _currentIndex = (_currentIndex + 1) % widget.items.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Animated text switcher showing current ticker item
  }
}
```

- [ ] **Step 3: Redesign _RecommendedTab layout**

Replace the current sections (greeting, banner, recommended tasks, hot activities, discover more) with:

```
CustomScrollView [
  SliverToBoxAdapter: _StoryRow
  SliverToBoxAdapter: _TickerBanner (ticker overlay + banner card)
  SliverToBoxAdapter: "为你推荐" header
  SliverMasonryGrid: waterfall feed (all discovery items including tasks/activities)
]
```

Remove: greeting section, Linker thought cloud, separate recommended tasks horizontal scroll, separate hot activities section.

The waterfall uses existing `_buildDiscoveryCard()` from `home_discovery_cards.dart` but needs to handle new `task` and `activity` feed types.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: recommend tab with story row, ticker, and unified waterfall"
```

---

### Task 5: Waterfall Cards — Task and Activity Card Widgets

**Files:**
- Modify: `link2ur/lib/features/home/views/home_discovery_cards.dart`

- [ ] **Step 1: Add TaskCard to the card builder**

In `home_discovery_cards.dart`, find the card builder switch/if chain and add:

```dart
if (item.isTask) return _TaskCard(item: item);
if (item.isActivity) return _ActivityCard(item: item);
if (item.isCompletion) return _CompletionCard(item: item);
```

- [ ] **Step 2: Create _TaskCard widget**

Xiaohongshu-style card: image top, title, task_type tag + price tag, poster avatar + name.

```dart
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final taskId = item.id.replaceFirst('task_', '');
        context.push('/tasks/$taskId');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (if available) or gradient placeholder
            if (item.hasImages)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(item.firstImage!, fit: BoxFit.cover, width: double.infinity),
              )
            else
              _GradientPlaceholder(taskType: item.taskType),
            // Body
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayTitle(Localizations.localeOf(context).languageCode),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  // Tags row
                  Wrap(spacing: 4, children: [
                    if (item.taskType != null)
                      _Tag(text: item.taskType!, color: const Color(0xFF667eea)),
                    if (item.price != null)
                      _Tag(text: '£${item.price!.toStringAsFixed(0)}',
                        color: const Color(0xFFee5a24), isPrice: true),
                  ]),
                  const SizedBox(height: 10),
                  // Footer: avatar + name + views
                  _CardFooter(item: item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create _ActivityCard widget**

Similar to TaskCard but shows participant count badge and activity info.

- [ ] **Step 4: Create _CompletionCard widget**

Simple card for follow feed: user avatar + "completed a task" text.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add task, activity, and completion card widgets for waterfall feed"
```

---

### Task 6: Bottom Nav — Rename Community to Discover

**Files:**
- Modify: `link2ur/lib/features/main/main_tab_view.dart`
- Modify: `link2ur/lib/l10n/app_zh.arb`, `app_en.arb`, `app_zh_Hant.arb`

- [ ] **Step 1: Add localization key**

```json
"navDiscover": "发现"  // zh
"navDiscover": "Discover"  // en
```

- [ ] **Step 2: Update bottom nav label**

In `main_tab_view.dart`, find the Community tab label and change it from `context.l10n.navCommunity` (or similar) to `context.l10n.navDiscover`.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: rename bottom nav Community to Discover"
```

---

### Task 7: Wire Up — Provider Registration and Initial Data Loading

**Files:**
- Modify: `link2ur/lib/app_providers.dart`
- Modify: `link2ur/lib/features/main/main_tab_view.dart`

- [ ] **Step 1: Register new repositories**

In `app_providers.dart`, add `FollowRepository` and `TickerRepository` to the `MultiRepositoryProvider`.

- [ ] **Step 2: Pass repositories to HomeBloc**

In `main_tab_view.dart` where HomeBloc is created, inject the new repositories.

- [ ] **Step 3: Load ticker on home init**

When HomeBloc is created, dispatch `HomeLoadTicker()` along with existing `HomeLoadRequested()` and `HomeLoadDiscoveryFeed()`.

- [ ] **Step 4: Test the full flow**

```bash
cd link2ur && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: wire up new repositories and data loading for homepage redesign"
```
