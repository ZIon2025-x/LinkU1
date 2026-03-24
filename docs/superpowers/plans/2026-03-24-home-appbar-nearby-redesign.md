# Home AppBar & Nearby Tab Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home AppBar location picker with a menu/drawer button, and redesign the Nearby tab as a xiaohongshu-style waterfall grid.

**Architecture:** Two independent changes to `home_view.dart` and `home_task_cards.dart`. The AppBar gets a menu icon that opens a Drawer; the Nearby tab replaces its linear list with a location bar + radius selector + `MasonryGridView` waterfall grid mixing tasks and services.

**Tech Stack:** Flutter, BLoC, `flutter_staggered_grid_view` (already a dependency), GoRouter

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `link2ur/lib/features/home/views/home_view.dart` | Modify | Replace location picker with menu icon, add Drawer to Scaffold, remove `_showLocationPicker` |
| `link2ur/lib/features/home/views/home_task_cards.dart` | Modify | Rewrite `_NearbyTab.build()` — location bar, radius selector, waterfall grid, new card widget |
| `link2ur/lib/l10n/app_en.arb` | Modify | Add new l10n keys for drawer & nearby location bar |
| `link2ur/lib/l10n/app_zh.arb` | Modify | Add new l10n keys (zh) |
| `link2ur/lib/l10n/app_zh_Hant.arb` | Modify | Add new l10n keys (zh_Hant) |

---

## Task 1: Add l10n keys

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add keys to all three ARB files**

Add before the closing `}` in each file:

**app_en.arb:**
```json
"drawerMyTasks": "My Tasks",
"drawerMyWallet": "My Wallet",
"drawerSettings": "Settings",
"drawerHelpFeedback": "Help & Feedback",
"drawerLogin": "Log in",
"nearbyCurrentLocation": "Current location: {city}",
"@nearbyCurrentLocation": { "placeholders": { "city": { "type": "String" } } },
"nearbySwitch": "Switch",
"nearbyApplicants": "{count} applicants",
"@nearbyApplicants": { "placeholders": { "count": { "type": "int" } } }
```

**app_zh.arb:**
```json
"drawerMyTasks": "我的任务",
"drawerMyWallet": "我的钱包",
"drawerSettings": "设置",
"drawerHelpFeedback": "帮助与反馈",
"drawerLogin": "登录",
"nearbyCurrentLocation": "当前定位：{city}",
"@nearbyCurrentLocation": { "placeholders": { "city": { "type": "String" } } },
"nearbySwitch": "切换",
"nearbyApplicants": "{count}人申请",
"@nearbyApplicants": { "placeholders": { "count": { "type": "int" } } }
```

**app_zh_Hant.arb:**
```json
"drawerMyTasks": "我的任務",
"drawerMyWallet": "我的錢包",
"drawerSettings": "設定",
"drawerHelpFeedback": "幫助與回饋",
"drawerLogin": "登入",
"nearbyCurrentLocation": "當前定位：{city}",
"@nearbyCurrentLocation": { "placeholders": { "city": { "type": "String" } } },
"nearbySwitch": "切換",
"nearbyApplicants": "{count}人申請",
"@nearbyApplicants": { "placeholders": { "count": { "type": "int" } } }
```

- [ ] **Step 2: Generate l10n files**

Run from `link2ur/`:
```bash
flutter gen-l10n
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat: add l10n keys for drawer menu and nearby waterfall"
```

---

## Task 2: Replace AppBar location picker with menu button + Drawer

**Files:**
- Modify: `link2ur/lib/features/home/views/home_view.dart`

**Context:** The current `_buildMobileAppBar` (line ~242) has a left-side location picker (lines 253-293) and `_showLocationPicker` method (lines 343-428). Replace the location picker with a menu icon, add a Drawer to the Scaffold.

- [ ] **Step 1: Replace the location picker widget in `_buildMobileAppBar`**

In `_buildMobileAppBar`, replace the entire left-side `SizedBox(width: 72, height: 44, child: GestureDetector(... location ...))` block (lines 253-293) with:

```dart
          // 左上角：菜单按钮（与右侧搜索按钮对称）
          SizedBox(
            width: 72,
            height: 44,
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                Scaffold.of(context).openDrawer();
              },
              behavior: HitTestBehavior.opaque,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.menu,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  size: 24,
                ),
              ),
            ),
          ),
```

- [ ] **Step 2: Add Drawer to `_buildMobileHome` Scaffold**

In `_buildMobileHome` (line ~205), add `drawer:` parameter to the `Scaffold`:

```dart
    return Scaffold(
      drawer: _buildDrawer(context),
      body: Stack(
        // ... existing children unchanged ...
      ),
    );
```

- [ ] **Step 3: Add `_buildDrawer` method to `_HomeViewContentState`**

Add this method after `_buildMobileAppBar`:

```dart
  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header: user info
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final isLoggedIn = authState.status == AuthStatus.authenticated;
                final user = authState.user;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: (isLoggedIn && user?.avatar != null)
                            ? NetworkImage(user!.avatar!)
                            : null,
                        child: (!isLoggedIn || user?.avatar == null)
                            ? const Icon(Icons.person, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isLoggedIn
                            ? Text(
                                user?.name ?? '',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/login');
                                },
                                child: Text(
                                  l10n.drawerLogin,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),
            // Menu items
            _DrawerMenuItem(
              icon: Icons.task_alt_outlined,
              label: l10n.drawerMyTasks,
              onTap: () {
                Navigator.pop(context);
                context.push('/my-tasks');
              },
            ),
            _DrawerMenuItem(
              icon: Icons.account_balance_wallet_outlined,
              label: l10n.drawerMyWallet,
              onTap: () {
                Navigator.pop(context);
                context.push('/wallet');
              },
            ),
            _DrawerMenuItem(
              icon: Icons.settings_outlined,
              label: l10n.drawerSettings,
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            _DrawerMenuItem(
              icon: Icons.help_outline,
              label: l10n.drawerHelpFeedback,
              onTap: () {
                Navigator.pop(context);
                context.push('/feedback');
              },
            ),
            const Spacer(),
            // Version
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'v${AppConfig.instance.appVersion}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Add `_DrawerMenuItem` widget**

Add at the end of `home_view.dart` (before closing), as a private widget:

```dart
class _DrawerMenuItem extends StatelessWidget {
  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon,
          size: 22,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
```

- [ ] **Step 5: Remove `_showLocationPicker` method**

Delete the entire `_showLocationPicker` method (lines ~343-428) from `_HomeViewContentState`.

- [ ] **Step 6: Clean up unused imports**

Remove these imports from `home_view.dart` if no longer referenced:
- `import '../../../core/utils/city_display_helper.dart';` (line 25)
- `import 'package:geocoding/geocoding.dart';` (line 34) — check if used elsewhere in the file's `part` files first
- `import 'package:geolocator/geolocator.dart';` (line 35) — check same

**Note:** `geocoding` and `geolocator` are imported here because `home_task_cards.dart` is a `part of` this file and uses them. Keep them. Only remove `city_display_helper` if it's not used in any part file.

- [ ] **Step 7: Add AppConfig import if not present**

Check if `AppConfig` is already imported. If not, add:
```dart
import '../../../core/config/app_config.dart';
```

Check that `AppConfig.instance.appVersion` exists. If not, use a hardcoded string or find the correct property.

- [ ] **Step 8: Verify it compiles**

Run from `link2ur/`:
```bash
flutter analyze lib/features/home/views/home_view.dart
```

- [ ] **Step 9: Commit**

```bash
git add link2ur/lib/features/home/views/home_view.dart
git commit -m "feat: replace home AppBar location picker with menu drawer"
```

---

## Task 3: Redesign Nearby tab — location bar + waterfall grid

**Files:**
- Modify: `link2ur/lib/features/home/views/home_task_cards.dart`

**Context:** This file is `part of 'home_view.dart'` so it shares all imports. The current `_NearbyTab` (line 5) uses a linear `SliverList` layout. Replace with: location bar → radius selector → `MasonryGridView` waterfall grid.

- [ ] **Step 1: Add `_NearbyLocationBar` widget**

Add a new widget in `home_task_cards.dart` after `_NearbyRadiusSelector`:

```dart
/// 附近 tab 顶部定位条 — "📍 当前定位：{city} · 切换"
class _NearbyLocationBar extends StatelessWidget {
  const _NearbyLocationBar({
    required this.city,
    required this.onSwitchTap,
  });

  final String? city;
  final VoidCallback onSwitchTap;

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
          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            l10n.nearbyCurrentLocation(displayCity),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSwitchTap,
            child: Text(
              l10n.nearbySwitch,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add `_NearbyWaterfallCard` widget**

Add a new widget for the waterfall card:

```dart
/// 附近瀑布流卡片 — 小红书风格
class _NearbyWaterfallCard extends StatelessWidget {
  const _NearbyWaterfallCard({
    required this.title,
    this.imageUrl,
    this.distance,
    this.tags = const [],
    this.price,
    this.applicantCount = 0,
    this.onTap,
  });

  final String title;
  final String? imageUrl;
  final double? distance;
  final List<String> tags;
  final String? price;
  final int applicantCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with distance badge
            _buildImageArea(isDark),
            // Card body
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Tags + price
                  if (tags.isNotEmpty || price != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...tags.map((tag) => _TagChip(label: tag)),
                          if (price != null) _TagChip(label: price!, isPrice: true),
                        ],
                      ),
                    ),
                  // Applicant count
                  if (applicantCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.l10n.nearbyApplicants(applicantCount),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea(bool isDark) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Stack(
      children: [
        // Image or gradient placeholder
        if (hasImage)
          AsyncImageView(
            url: imageUrl!,
            width: double.infinity,
            height: 140,
            fit: BoxFit.cover,
          )
        else
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.task_outlined,
                size: 36,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
        // Distance badge (bottom-left, frosted glass)
        if (distance != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 11, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      _formatDistance(distance!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

/// Tag chip for waterfall card
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.isPrice = false});

  final String label;
  final bool isPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPrice ? const Color(0xFFFFF0F0) : const Color(0xFFF0F0FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isPrice ? const Color(0xFFEE5A24) : AppColors.primary,
          fontWeight: isPrice ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add `_showNearbyLocationPicker` method to `_NearbyTabState`**

Move the location picker sheet logic from the deleted `_showLocationPicker` into `_NearbyTabState`:

```dart
  void _showNearbyLocationPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? pickedAddress;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.locationSetLocation,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.locationSetLocationHint,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),
              LocationInputField(
                initialValue: _city,
                showOnlineOption: false,
                onChanged: (value) => pickedAddress = value,
                onLocationPicked: (address, lat, lng) {
                  pickedAddress = address;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final address = pickedAddress;
                    if (address != null && address.isNotEmpty) {
                      setState(() => _city = address);
                      context.read<HomeBloc>().add(HomeLocationCityUpdated(address));
                    }
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.l10n.commonConfirm),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
```

- [ ] **Step 4: Rewrite `_NearbyTabState.build()` to use waterfall grid**

Replace the `build` method of `_NearbyTabState`:

```dart
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    if (_locationLoading) {
      const body = SkeletonTopImageCardList();
      return isDesktop ? const ContentConstraint(child: body) : body;
    }

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.nearbyTasks != curr.nearbyTasks ||
          prev.nearbyServices != curr.nearbyServices ||
          prev.nearbyRadius != curr.nearbyRadius ||
          prev.isLoading != curr.isLoading,
      builder: (context, state) {
        if (state.isLoading && state.nearbyTasks.isEmpty) {
          const body = SkeletonTopImageCardList();
          return isDesktop ? const ContentConstraint(child: body) : body;
        }

        if (state.nearbyTasks.isEmpty && state.nearbyServices.isEmpty) {
          final center = Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off_outlined,
                    size: 64, color: AppColors.textTertiaryLight),
                AppSpacing.vMd,
                Text(context.l10n.homeNoNearbyTasks,
                    style: const TextStyle(color: AppColors.textSecondaryLight)),
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

        // Build mixed list of tasks + services for waterfall
        final waterfallItems = _buildWaterfallItems(state);

        final content = RefreshIndicator(
          onRefresh: () async {
            await _loadLocation();
            final homeBloc = context.read<HomeBloc>();
            await homeBloc.stream
                .firstWhere((s) => !s.isLoading, orElse: () => state);
          },
          child: CustomScrollView(
            slivers: [
              // Location bar
              SliverToBoxAdapter(
                child: _NearbyLocationBar(
                  city: _city,
                  onSwitchTap: _showNearbyLocationPicker,
                ),
              ),
              // Radius selector
              SliverToBoxAdapter(
                child: _NearbyRadiusSelector(
                  selectedRadius: state.nearbyRadius,
                  onChanged: _onRadiusChanged,
                ),
              ),
              // Waterfall grid
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childCount: waterfallItems.length,
                  itemBuilder: (context, index) => waterfallItems[index],
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.lg)),
            ],
          ),
        );
        return isDesktop ? ContentConstraint(child: content) : content;
      },
    );
  }
```

- [ ] **Step 5: Add `_buildWaterfallItems` helper method to `_NearbyTabState`**

```dart
  List<Widget> _buildWaterfallItems(HomeState state) {
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';
    final items = <Widget>[];

    // Tasks
    for (final task in state.nearbyTasks) {
      final title = isEn
          ? (task.titleEn ?? task.title)
          : (task.titleZh ?? task.title);
      items.add(_NearbyWaterfallCard(
        title: title,
        imageUrl: task.firstImage,
        distance: task.distance,
        tags: [task.taskType],
        price: '\u00A3${(task.reward / 100).toStringAsFixed(task.reward % 100 == 0 ? 0 : 2)}',
        applicantCount: task.currentParticipants,
        onTap: () => context.push('/tasks/${task.id}'),
      ));
    }

    // Services
    for (final service in state.nearbyServices) {
      final name = (isEn
              ? (service['service_name_en'] ?? service['service_name'])
              : service['service_name']) as String? ?? '';
      final price = service['base_price'];
      final pricingType = service['pricing_type'] as String? ?? '';
      final priceStr = price != null
          ? '\u00A3${_NearbyServiceCard._formatPrice(price)}${pricingType.isNotEmpty ? '/$pricingType' : ''}'
          : null;
      final distKm = service['distance_km'] as num?;
      final imageUrl = service['cover_image'] as String?;

      items.add(_NearbyWaterfallCard(
        title: name,
        imageUrl: imageUrl,
        distance: distKm != null ? distKm.toDouble() * 1000 : null,
        tags: [],
        price: priceStr,
        applicantCount: 0,
        onTap: () {
          final id = service['id'];
          if (id != null) context.push('/service/$id');
        },
      ));
    }

    return items;
  }
```

- [ ] **Step 6: Add MasonryGridView import**

Verify that `flutter_staggered_grid_view` is already imported in `home_view.dart` (line 4: `import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';`). The `SliverMasonryGrid` class comes from this package. Since `home_task_cards.dart` is `part of 'home_view.dart'`, no additional import needed.

- [ ] **Step 7: Verify it compiles**

Run from `link2ur/`:
```bash
flutter analyze lib/features/home/
```

Fix any compile errors.

- [ ] **Step 8: Commit**

```bash
git add link2ur/lib/features/home/views/home_task_cards.dart
git commit -m "feat: redesign nearby tab with waterfall grid and location bar"
```

---

## Task 4: Final cleanup and verify

- [ ] **Step 1: Remove unused `_TaskCard` and `_NearbyServiceCard` if no longer referenced**

Check if `_TaskCard` and `_NearbyServiceCard` in `home_task_cards.dart` are still used elsewhere. If only used by the old `_NearbyTab.build()`, they can be removed. If `_NearbyServiceCard._formatPrice` is still needed by `_buildWaterfallItems`, keep it or extract the helper.

- [ ] **Step 2: Remove `city_display_helper` import from `home_view.dart`**

If `CityDisplayHelper` is not used in any of the part files (`home_recommended_section.dart`, `home_widgets.dart`, `home_activities_section.dart`, `home_discovery_cards.dart`, `home_task_cards.dart`, `home_experts_search.dart`), remove the import.

Search for `CityDisplayHelper` usage — it's used in `home_experts_search.dart` (line 391). Keep the import.

- [ ] **Step 3: Run full analysis**

```bash
flutter analyze
```

- [ ] **Step 4: Test on device/emulator**

Run the app and verify:
1. Home AppBar shows menu icon (left) and search icon (right)
2. Tapping menu opens Drawer with user info + menu items
3. Drawer menu items navigate correctly
4. Nearby tab shows location bar with city name + "切换" link
5. Tapping "切换" opens location picker sheet
6. Radius selector works as before
7. Tasks and services display in 2-column waterfall grid
8. Distance badges show on cards
9. Applicant count shows on task cards

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "chore: cleanup unused code after home redesign"
```
