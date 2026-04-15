# 我的闲置与我的租赁合并 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Profile 菜单中并列的"我的闲置"与"我的租赁"合并为单一"我的闲置"页面，通过 6 个 tab 统一承载闲置买卖 + 租赁业务。

**Architecture:** 复用现有 `my_posts_view.dart`（StatefulWidget + 本地 state），将 `TabController` 从 4 扩展到 6；Tab 3"我租出的"走 listing 视角复用 `getMyRelatedFleaItems`（新增 `type` 参数和 `current_rental_status` 派生字段），Tab 4"我租入的"走订单视角复用 `getMyRentals`；删除 `my_rentals_view.dart` 与 `FleaMarketRentalBloc`。

**Tech Stack:** Flutter (BLoC + StatefulWidget 本地 state 混合) / FastAPI + SQLAlchemy async / Dio + GoRouter + Hive / Pydantic v2

**Spec:** `docs/superpowers/specs/2026-04-15-my-posts-rentals-merge-design.md`

---

## File Structure

**后端修改**：
- Modify `backend/app/routes/flea_market_routes.py` — `/my-related-items` 加 `type` 参数
- Modify `backend/app/schemas.py`（或 schema_modules）— `MyRelatedFleaItemResponse` 增 `current_rental_status`
- Modify `backend/app/schemas.py` — `FleaMarketItemResponse` 增 `current_rental_status`

**Flutter 修改**：
- Modify `link2ur/lib/data/models/flea_market_item.dart` — 增 `currentRentalStatus`
- Modify `link2ur/lib/data/repositories/flea_market_repository.dart` — `getMyRelatedFleaItems` 增 `type` 参数
- Modify `link2ur/lib/features/profile/views/my_posts_view.dart` — 4 → 6 tab，支持 initialTab
- Create `link2ur/lib/features/profile/views/widgets/rented_in_tab.dart` — 迁移 `_RentalCard`
- Modify `link2ur/lib/l10n/app_{en,zh,zh_Hant}.arb` — 新增 5 个 key
- Modify `link2ur/lib/core/router/app_router.dart`（或 `profile_routes.dart` / `flea_market_routes.dart`）— 重定向 + tab 参数
- Modify `link2ur/lib/features/profile/views/widgets/profile_menu_widgets.dart` — 删除租赁菜单项
- Delete `link2ur/lib/features/flea_market/views/my_rentals_view.dart`
- Delete `link2ur/lib/features/flea_market/bloc/flea_market_rental_bloc.dart`（若其他处未使用）

---

## Task 1: 后端 — 给 `my-related-items` 增加 `type` 过滤参数

**Files:**
- Modify: `backend/app/routes/flea_market_routes.py` 约 1488-1522 行

- [ ] **Step 1: 定位并阅读当前端点**

Run: `grep -n "my-related-items" backend/app/routes/flea_market_routes.py`
Expected: 找到 `@flea_market_router.get("/my-related-items", ...)` 行。

- [ ] **Step 2: 修改端点签名，增加 `type` Query 参数**

在 `get_my_related_flea_items` 函数签名上增加参数：

```python
from fastapi import Query
from typing import Optional, Literal

@flea_market_router.get("/my-related-items", response_model=schemas.MyRelatedFleaListResponse)
async def get_my_related_flea_items(
    type: Optional[Literal["sale", "rental"]] = Query(None, description="Filter by listing_type"),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    ...
```

- [ ] **Step 3: 在查询中加入 type 过滤**

在现有 Task/FleaMarketItem 查询的 `where` 条件中增加：

```python
if type == "sale":
    stmt = stmt.where(models.FleaMarketItem.listing_type == "sale")
elif type == "rental":
    stmt = stmt.where(models.FleaMarketItem.listing_type == "rental")
```

> 具体 statement 变量名请按该文件现有模式（通常是 `stmt` 或 `query`）。若现有查询未直接 join `FleaMarketItem`，需通过 `Task.flea_market_item` relationship 过滤 —— 阅读当前代码后按其模式改。

- [ ] **Step 4: 手动测试**

Run: `curl -H "Cookie: ..." "https://linktest.up.railway.app/api/flea-market/my-related-items?type=rental"`
Expected: 仅返回 `listing_type == "rental"` 的 item。

Run: `curl -H "Cookie: ..." "https://linktest.up.railway.app/api/flea-market/my-related-items?type=sale"`
Expected: 仅返回 `listing_type == "sale"` 的 item。

Run: `curl -H "Cookie: ..." "https://linktest.up.railway.app/api/flea-market/my-related-items"`
Expected: 返回全部（兼容旧调用）。

- [ ] **Step 5: Commit**

```bash
git add backend/app/routes/flea_market_routes.py
git commit -m "feat(backend): add type filter to /my-related-items for sale/rental split"
```

---

## Task 2: 后端 — 给 Listing 响应增加 `current_rental_status` 派生字段

**Files:**
- Modify: `backend/app/schemas.py`（`FleaMarketItemResponse` 和 `MyRelatedFleaItemResponse`）
- Modify: `backend/app/routes/flea_market_routes.py`（`/my-related-items` 端点的响应构造逻辑）

- [ ] **Step 1: Schema 增字段**

在 `schemas.py` 中找到 `FleaMarketItemResponse`（约 2965 行附近）和 `MyRelatedFleaItemResponse`，增加字段：

```python
current_rental_status: Optional[Literal["available", "renting", "overdue"]] = None
```

对所有 rental 类 item 都会填值；非 rental 类保持 `None`。

- [ ] **Step 2: 在 `/my-related-items` 端点中批量查询当前租赁状态**

在查询完 items 之后，对 `listing_type == "rental"` 的 item 批量查询最新未归还订单：

```python
rental_item_ids = [it.id for it in items if it.listing_type == "rental"]
current_rentals = {}
if rental_item_ids:
    rental_stmt = (
        select(models.FleaMarketRental)
        .where(
            models.FleaMarketRental.item_id.in_(rental_item_ids),
            models.FleaMarketRental.status.in_(["active", "overdue"]),
        )
        .order_by(models.FleaMarketRental.created_at.desc())
    )
    rental_rows = (await db.execute(rental_stmt)).scalars().all()
    # 每个 item 取最新一条
    for r in rental_rows:
        current_rentals.setdefault(r.item_id, r)

def _derive_status(item):
    if item.listing_type != "rental":
        return None
    r = current_rentals.get(item.id)
    if r is None:
        return "available"
    return "overdue" if r.status == "overdue" else "renting"
```

在构造 response item 时设置 `current_rental_status=_derive_status(it)`。

> **N+1 预防**：务必用上面的批量 `IN` 子查询，而非每个 item 单独查询。

- [ ] **Step 3: 手动测试**

Run: `curl ".../my-related-items?type=rental"` 用一个发过租赁商品的测试账号
Expected: 每个 rental item 响应含 `current_rental_status`，未被租的是 `"available"`，有 active 订单的是 `"renting"`。

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas.py backend/app/routes/flea_market_routes.py
git commit -m "feat(backend): derive current_rental_status for flea market listings"
```

---

## Task 3: 后端 — 确认 `/my-rentals` 返回全部状态

**Files:**
- Read-only: `backend/app/routes/flea_market_rental_routes.py` 约 1340-1400 行

- [ ] **Step 1: 阅读 `get_my_rentals` 过滤逻辑**

Run: `grep -n -A 40 "async def get_my_rentals" backend/app/routes/flea_market_rental_routes.py`
Expected: 查看 where 子句。

- [ ] **Step 2: 验证无隐式状态过滤**

查找代码中是否有 `status != "returned"` 或类似条件。若无，此任务结束。若有，移除并提交。

- [ ] **Step 3: 若有改动则 commit（否则跳过）**

```bash
git add backend/app/routes/flea_market_rental_routes.py
git commit -m "fix(backend): /my-rentals returns all statuses including returned"
```

---

## Task 4: Flutter — Model 增 `currentRentalStatus` 字段

**Files:**
- Modify: `link2ur/lib/data/models/flea_market_item.dart`

- [ ] **Step 1: 字段声明**

在 `FleaMarketItem` class 的字段区（`activeRentals` 附近，约 109 行）加：

```dart
final String? currentRentalStatus; // 'available' | 'renting' | 'overdue' | null
```

- [ ] **Step 2: 构造函数参数**

在 `const FleaMarketItem({...})` 构造中加：

```dart
this.currentRentalStatus,
```

- [ ] **Step 3: `fromJson` 读取**

在 `factory FleaMarketItem.fromJson` 中加（与 `activeRentals` 同一区域）：

```dart
currentRentalStatus: json['current_rental_status'] as String?,
```

- [ ] **Step 4: `toJson` 序列化**

```dart
if (currentRentalStatus != null) 'current_rental_status': currentRentalStatus,
```

- [ ] **Step 5: `copyWith` 参数**

增加 `String? currentRentalStatus,` 参数和 `currentRentalStatus: currentRentalStatus ?? this.currentRentalStatus,` 映射。

- [ ] **Step 6: `props` 加入**

在 `Equatable props` 列表（文件末尾）中加 `currentRentalStatus`。

- [ ] **Step 7: 验证编译**

Run: `cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/data/models/flea_market_item.dart`
Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add link2ur/lib/data/models/flea_market_item.dart
git commit -m "feat(flutter): add currentRentalStatus field to FleaMarketItem"
```

---

## Task 5: Flutter — Repository 增 `type` 参数

**Files:**
- Modify: `link2ur/lib/data/repositories/flea_market_repository.dart` 约 259-278 行

- [ ] **Step 1: 改签名**

将 `getMyRelatedFleaItems` 改为：

```dart
Future<List<FleaMarketItem>> getMyRelatedFleaItems({
  bool forceRefresh = false,
  String? type, // 'sale' | 'rental' | null (all)
}) async {
  final queryParams = <String, dynamic>{};
  if (type != null) queryParams['type'] = type;

  final response = await _apiService.get(
    ApiEndpoints.fleaMarketMyRelatedItems,
    queryParameters: queryParams.isEmpty ? null : queryParams,
  );
  // ... 保留现有解析逻辑
}
```

> 若现有实现用了缓存（Hive），需让缓存 key 随 `type` 变化：`'flea_market_my_related_${type ?? "all"}'`。

- [ ] **Step 2: 验证编译**

Run: `flutter analyze lib/data/repositories/flea_market_repository.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/repositories/flea_market_repository.dart
git commit -m "feat(flutter): add type param to getMyRelatedFleaItems"
```

---

## Task 6: Flutter — i18n 新增 5 个 key

**Files:**
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Modify: `link2ur/lib/l10n/app_en.arb`

- [ ] **Step 1: 在 `app_zh.arb` 末尾（最后一个 key 后）加入**

```json
,
"myPostsTabRentedOut": "我租出的",
"@myPostsTabRentedOut": {"description": "Tab label: items I listed for rent"},
"myPostsTabRentedIn": "我租入的",
"@myPostsTabRentedIn": {"description": "Tab label: rentals where I'm the renter"},
"rentalListingStatusAvailable": "可租",
"@rentalListingStatusAvailable": {"description": "Rental item status badge: available"},
"rentalListingStatusRenting": "租赁中",
"@rentalListingStatusRenting": {"description": "Rental item status badge: currently rented"},
"rentalListingStatusOverdue": "逾期",
"@rentalListingStatusOverdue": {"description": "Rental item status badge: overdue"}
```

- [ ] **Step 2: `app_zh_Hant.arb` 同步**

```json
,
"myPostsTabRentedOut": "我租出的",
"myPostsTabRentedIn": "我租入的",
"rentalListingStatusAvailable": "可租",
"rentalListingStatusRenting": "租賃中",
"rentalListingStatusOverdue": "逾期"
```

(加 `@description` 如上，保持风格一致)

- [ ] **Step 3: `app_en.arb` 同步**

```json
,
"myPostsTabRentedOut": "Rented Out",
"myPostsTabRentedIn": "Rented In",
"rentalListingStatusAvailable": "Available",
"rentalListingStatusRenting": "Renting",
"rentalListingStatusOverdue": "Overdue"
```

(加 `@description` 同上)

- [ ] **Step 4: 生成 l10n**

Run: `cd link2ur && flutter gen-l10n`
Expected: No errors; `AppLocalizations` 类已更新。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/*.arb
git commit -m "feat(i18n): add rental tab and status badge keys for merged my-posts view"
```

---

## Task 7: Flutter — 创建"我租入的" Tab 组件（迁移 RentalCard）

**Files:**
- Create: `link2ur/lib/features/profile/views/widgets/rented_in_tab.dart`

- [ ] **Step 1: 创建文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/colors.dart';
import '../../../../data/models/flea_market_rental.dart';
import '../../../../data/repositories/flea_market_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/utils/error_localizer.dart';

class RentedInTab extends StatefulWidget {
  const RentedInTab({super.key});

  @override
  State<RentedInTab> createState() => _RentedInTabState();
}

class _RentedInTabState extends State<RentedInTab>
    with AutomaticKeepAliveClientMixin {
  final List<FleaMarketRental> _rentals = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _errorCode;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading && _hasMore) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() { _loading = true; _errorCode = null; });
    try {
      final repo = context.read<FleaMarketRepository>();
      final list = await repo.getMyRentals(page: _page, pageSize: 20);
      setState(() {
        _rentals.addAll(list);
        _hasMore = list.length >= 20;
        _page++;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorCode = 'my_posts_rentals_load_failed';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _rentals.clear();
      _page = 1;
      _hasMore = true;
      _errorCode = null;
    });
    await _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_errorCode != null && _rentals.isEmpty) {
      return ErrorStateView(
        message: context.localizeError(_errorCode!),
        onRetry: _refresh,
      );
    }
    if (_rentals.isEmpty && !_loading) {
      return Center(child: Text(context.l10n.emptyState));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _rentals.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _rentals.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _RentalCard(rental: _rentals[i]);
        },
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final FleaMarketRental rental;
  const _RentalCard({required this.rental});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (statusLabel, statusColor) = switch (rental.status) {
      'active' => (l10n.fleaMarketRentalActive, AppColors.success),
      'returned' => (l10n.fleaMarketRentalReturned, AppColors.info),
      'overdue' => (l10n.fleaMarketRentalOverdue, AppColors.error),
      'disputed' => ('Disputed', AppColors.warning),
      _ => (rental.status, AppColors.info),
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(rental.itemTitle ?? '#${rental.itemId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${rental.startDate} ~ ${rental.endDate}'),
            Text('${rental.currency} ${rental.totalPaid}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
```

> **实现注意**：以上是骨架。执行时请对照原 `my_rentals_view.dart:152-283` 的完整 `_RentalCard` 实现（图片、点击跳详情等），把那些细节 **原样迁移过来**，替换掉上面的简化 `ListTile`。保持 UI 风格一致。

- [ ] **Step 2: 在 `error_localizer.dart` 注册新 error code**

Run: `grep -n "my_posts_load_failed" link2ur/lib/core/utils/error_localizer.dart`

找到 `ErrorLocalizer.localize()` switch/case，增加：

```dart
case 'my_posts_rentals_load_failed':
  return context.l10n.myPostsLoadFailed; // 复用现有 key
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze lib/features/profile/views/widgets/rented_in_tab.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/profile/views/widgets/rented_in_tab.dart link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat(flutter): add RentedInTab widget migrating _RentalCard from my_rentals_view"
```

---

## Task 8: Flutter — 改造 `my_posts_view.dart` 为 6 tab

**Files:**
- Modify: `link2ur/lib/features/profile/views/my_posts_view.dart`

- [ ] **Step 1: 构造器支持 initialTab**

在 `MyPostsView` class 上加：

```dart
class MyPostsView extends StatefulWidget {
  final int initialTab;
  const MyPostsView({super.key, this.initialTab = 0});
  @override State<MyPostsView> createState() => _MyPostsViewState();
}
```

- [ ] **Step 2: 扩 TabController 到 6**

在 `_MyPostsViewState.initState` 中：

```dart
_tabController = TabController(
  length: 6,
  vsync: this,
  initialIndex: widget.initialTab.clamp(0, 5),
);
```

- [ ] **Step 3: 修改 `_MyItemsCategory` 枚举**

在文件顶部（或原 enum 定义处）把枚举扩展为：

```dart
enum _MyItemsCategory { selling, sold, bought, rentedOut, favorites }
// 注意: rentedIn 不在此枚举内，因为它不从 _allRelatedItems 派生，由 RentedInTab 独立管理
```

- [ ] **Step 4: 更新 `_getFilteredItems`**

```dart
List<FleaMarketItem> _getFilteredItems(_MyItemsCategory category) {
  switch (category) {
    case _MyItemsCategory.selling:
      return _allRelatedItems.where((i) =>
        i.listingType == 'sale' && i.status == 'active' && i.myRole == 'seller'
      ).toList();
    case _MyItemsCategory.sold:
      return _allRelatedItems.where((i) =>
        i.listingType == 'sale' && i.status == 'sold' && i.myRole == 'seller'
      ).toList();
    case _MyItemsCategory.bought:
      return _allRelatedItems.where((i) => i.myRole == 'buyer').toList();
    case _MyItemsCategory.rentedOut:
      return _allRelatedItems.where((i) =>
        i.listingType == 'rental' && i.myRole == 'seller'
      ).toList();
    case _MyItemsCategory.favorites:
      return _favoriteItems;
  }
}
```

> **关键**：真实字段名（`myRole` / `listingType` / `status`）以 `flea_market_item.dart` 为准。若原有的 `_getFilteredItems` 实现有差异，按现有逻辑调整。

- [ ] **Step 5: TabBar 扩展到 6 个**

找到原 `TabBar(tabs: [...])`（约 180-206 行）改为：

```dart
TabBar(
  isScrollable: true,
  controller: _tabController,
  tabs: [
    Tab(text: l10n.myPostsTabSelling),        // 出售中
    Tab(text: l10n.myPostsTabSold),           // 已售出
    Tab(text: l10n.myPostsTabBought),         // 收的闲置
    Tab(text: l10n.myPostsTabRentedOut),      // 我租出的
    Tab(text: l10n.myPostsTabRentedIn),       // 我租入的
    Tab(text: l10n.myPostsTabFavorites),      // 收藏的
  ],
)
```

> 真实现有 tab key 以当前文件为准；仅新增 `myPostsTabRentedOut` / `myPostsTabRentedIn`。

- [ ] **Step 6: TabBarView 增加 RentedInTab**

```dart
import 'widgets/rented_in_tab.dart';

// ...
TabBarView(
  controller: _tabController,
  children: [
    _buildItemsList(_MyItemsCategory.selling),
    _buildItemsList(_MyItemsCategory.sold),
    _buildItemsList(_MyItemsCategory.bought),
    _buildRentedOutList(),  // 带状态徽章
    const RentedInTab(),    // 独立组件
    _buildItemsList(_MyItemsCategory.favorites),
  ],
)
```

- [ ] **Step 7: 新增 `_buildRentedOutList`**

```dart
Widget _buildRentedOutList() {
  final items = _getFilteredItems(_MyItemsCategory.rentedOut);
  if (_allRelatedLoading) return const Center(child: CircularProgressIndicator());
  if (items.isEmpty) return Center(child: Text(context.l10n.emptyState));
  return RefreshIndicator(
    onRefresh: () => _loadAllRelated(forceRefresh: true),
    child: ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Stack(
          children: [
            FleaMarketItemCard(item: item), // 复用现有卡片
            Positioned(
              top: 12, right: 12,
              child: _buildRentalStatusBadge(item.currentRentalStatus),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildRentalStatusBadge(String? status) {
  if (status == null) return const SizedBox.shrink();
  final l10n = context.l10n;
  final (label, color) = switch (status) {
    'available' => (l10n.rentalListingStatusAvailable, AppColors.success),
    'renting' => (l10n.rentalListingStatusRenting, AppColors.info),
    'overdue' => (l10n.rentalListingStatusOverdue, AppColors.error),
    _ => (status, AppColors.info),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
  );
}
```

> `FleaMarketItemCard` 若不存在，用现有 my_posts_view 里的列表项 widget 同名封装。

- [ ] **Step 8: 验证编译**

Run: `flutter analyze lib/features/profile/views/my_posts_view.dart`
Expected: No issues.

- [ ] **Step 9: Commit**

```bash
git add link2ur/lib/features/profile/views/my_posts_view.dart
git commit -m "feat(flutter): expand my_posts_view to 6 tabs with rented-out/rented-in"
```

---

## Task 9: Flutter — 路由重定向 `/flea-market/my-rentals` → `/profile/my-posts?tab=4`

**Files:**
- Modify: `link2ur/lib/core/router/app_router.dart` 或 `features/flea_market/flea_market_routes.dart` 或 `features/profile/profile_routes.dart`

- [ ] **Step 1: 找到现有 `/profile/my-posts` 路由定义**

Run: `grep -rn "my-posts" link2ur/lib/core/router/ link2ur/lib/features/profile/`
Expected: 找到 GoRoute 配置。

- [ ] **Step 2: 修改 `/profile/my-posts` 支持 `?tab=` query**

```dart
GoRoute(
  path: '/profile/my-posts',
  name: 'myPosts',
  builder: (ctx, state) {
    final tabStr = state.uri.queryParameters['tab'];
    final tabIndex = _parseTabIndex(tabStr);
    return MyPostsView(initialTab: tabIndex);
  },
),

int _parseTabIndex(String? tab) {
  switch (tab) {
    case 'selling': return 0;
    case 'sold': return 1;
    case 'bought': return 2;
    case 'rented-out': return 3;
    case 'rented-in': return 4;
    case 'favorites': return 5;
    default:
      final n = int.tryParse(tab ?? '');
      return (n != null && n >= 0 && n <= 5) ? n : 0;
  }
}
```

- [ ] **Step 3: 改造 `/flea-market/my-rentals` 路由为重定向**

找到现有 `GoRoute(path: '/flea-market/my-rentals', ...)` 定义，替换为：

```dart
GoRoute(
  path: '/flea-market/my-rentals',
  name: 'fleaMarketMyRentals',
  redirect: (ctx, state) => '/profile/my-posts?tab=rented-in',
),
```

- [ ] **Step 4: 验证编译**

Run: `flutter analyze lib/core/router/`
Expected: No issues.

- [ ] **Step 5: 手动测试路由**

在 app 里走任何已有的"我的租赁"深链（如推送通知/profile 菜单，若 Task 10 还没做）。
Expected: 进入 my-posts 页并定位到 Tab 4。

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/core/router/ link2ur/lib/features/
git commit -m "feat(flutter): redirect /flea-market/my-rentals to /profile/my-posts tab=rented-in"
```

---

## Task 10: Flutter — Profile 菜单移除"我的租赁"

**Files:**
- Modify: `link2ur/lib/features/profile/views/widgets/profile_menu_widgets.dart` 约 64-77 行

- [ ] **Step 1: 删除"我的租赁"菜单项**

找到：

```dart
// 约 line 74: 我的租赁菜单项
ListTile(
  leading: ...,
  title: Text(l10n.fleaMarketMyRentals),
  onTap: () => context.go('/flea-market/my-rentals'),
),
```

**整段删除**（包括 leading icon、分隔符，若有）。

- [ ] **Step 2: 验证编译**

Run: `flutter analyze lib/features/profile/views/widgets/profile_menu_widgets.dart`
Expected: No issues.

- [ ] **Step 3: 运行 app 检查 Profile 菜单**

Run: `cd link2ur && flutter run -d web-server`
手动进入 Profile 页，确认只剩一个"我的闲置"入口。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/profile/views/widgets/profile_menu_widgets.dart
git commit -m "feat(flutter): remove my-rentals entry from profile menu (merged into my-posts)"
```

---

## Task 11: Flutter — 删除 `my_rentals_view.dart` 和 `FleaMarketRentalBloc`

**Files:**
- Delete: `link2ur/lib/features/flea_market/views/my_rentals_view.dart`
- Delete: `link2ur/lib/features/flea_market/bloc/flea_market_rental_bloc.dart`

- [ ] **Step 1: 全仓扫 `FleaMarketRentalBloc` 引用**

Run: `grep -rn "FleaMarketRentalBloc" link2ur/lib/`
Expected: 只有 `my_rentals_view.dart`、`flea_market_rental_bloc.dart` 本体，以及可能的 `app_providers.dart` / `flea_market_routes.dart` 注册处。

> **如果有其他业务页面引用此 bloc**，停下来处理：那些页面可能依赖 bloc 的其他 event/state（非 `RentalLoadMyRentals`）。需逐个评估。若仅是 `RentalLoadMyRentals` 相关代码，照删不误；若有其他 event/state 被其他 view 使用（如详情页），**保留 bloc** 但删除 `RentalLoadMyRentals` / 相关 state 字段。

- [ ] **Step 2: 删除 `my_rentals_view.dart`**

Run: `rm link2ur/lib/features/flea_market/views/my_rentals_view.dart`

- [ ] **Step 3: 根据 Step 1 的结果决定 bloc 处理**

若 bloc 只为 `my_rentals_view` 服务：

```bash
rm link2ur/lib/features/flea_market/bloc/flea_market_rental_bloc.dart
rm link2ur/lib/features/flea_market/bloc/flea_market_rental_event.dart  # 若存在
rm link2ur/lib/features/flea_market/bloc/flea_market_rental_state.dart  # 若存在
```

若 bloc 被其他页面使用：只删除 `RentalLoadMyRentals` event、`_onLoadMyRentals` handler、以及 state 里的 `myRentals / isLoadingMyRentals / hasMoreRentals / rentalsPage` 字段。

- [ ] **Step 4: 清理 `app_providers.dart` / 其他 provider 注册**

Run: `grep -rn "FleaMarketRentalBloc\|MyRentalsView" link2ur/lib/`

删除所有指向被删文件/类的 import / BlocProvider / route 注册。

- [ ] **Step 5: 验证编译**

Run: `cd link2ur && flutter analyze`
Expected: No issues. 若有红色 error 说明遗漏了某处引用，回到 Step 4。

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/
git commit -m "refactor(flutter): delete my_rentals_view and FleaMarketRentalBloc (merged into my_posts_view)"
```

---

## Task 12: 端到端验证

**Files:** 无代码改动

- [ ] **Step 1: Full project analyze**

Run: `cd link2ur && flutter analyze`
Expected: No issues found.

- [ ] **Step 2: 启动 app**

Run: `cd link2ur && flutter run -d web-server`

- [ ] **Step 3: 手动测试检查表**

用一个有历史出售 / 购买 / 租赁订单 / 租赁 listing 的测试账号。

- [ ] Profile 菜单只看到一个"我的闲置"入口（无"我的租赁"）
- [ ] 点击进入，TabBar 显示 6 个 tab 且横向可滚动
- [ ] Tab 0 "出售中"：仅看到自己发的 sale 类 active 商品
- [ ] Tab 1 "已售出"：仅看到 sale 类 sold 商品
- [ ] Tab 2 "收的闲置"：仅看到自己作为买家的商品
- [ ] Tab 3 "我租出的"：看到自己发的 rental 类商品，**未被租的也在**，每行有状态徽章（可租/租赁中/逾期）
- [ ] Tab 4 "我租入的"：看到作为租客的订单，**含 returned 状态的历史订单**
- [ ] Tab 5 "收藏的"：收藏列表
- [ ] 访问 `http://localhost:port/flea-market/my-rentals` 被重定向到 my-posts 且落在 Tab 4
- [ ] 访问 `http://localhost:port/profile/my-posts?tab=rented-out` 直接落在 Tab 3
- [ ] 各 tab 下拉刷新正常
- [ ] 各 tab 错误态显示 ErrorStateView + 重试按钮正常

- [ ] **Step 4: 中英繁三语切换验证**

在设置里切换语言，回到 my-posts，确认 5 个新 key（租出的/租入的/可租/租赁中/逾期）都正确本地化。

- [ ] **Step 5: 后端 smoke test**

Run:
```bash
curl -H "Cookie: ..." "https://linktest.up.railway.app/api/flea-market/my-related-items?type=rental" | jq '.items[0].current_rental_status'
```
Expected: 返回 `"available"` / `"renting"` / `"overdue"` 之一（或对该用户此前无租赁商品时返回空数组）。

- [ ] **Step 6: Final commit（若需要任何 lint/调整）**

```bash
git add -A
git commit -m "chore: post-merge cleanup and verification" --allow-empty
```

---

## 附录：跨层一致性复核

参照 `full-stack-consistency-check` 技能，实施完后逐项确认：

- [ ] DB：无改动 ✅
- [ ] Backend model：`FleaMarketItem` ORM 无改动（`current_rental_status` 是派生字段）✅
- [ ] Pydantic schema：`FleaMarketItemResponse` / `MyRelatedFleaItemResponse` 增 `current_rental_status` ✅（Task 2）
- [ ] API route：`/my-related-items` 增 `type` 参数 ✅（Task 1）；`/my-rentals` 确认无隐式过滤 ✅（Task 3）
- [ ] Frontend endpoint：`api_endpoints.dart` 无新增 ✅
- [ ] Repository：`getMyRelatedFleaItems` 增 `type` ✅（Task 5）
- [ ] Model.fromJson：`FleaMarketItem` 增 `currentRentalStatus` ✅（Task 4）
- [ ] BLoC：`FleaMarketRentalBloc` 删除 ✅（Task 11）
- [ ] UI：Profile 菜单项删除（Task 10）、`MyPostsView` 扩 6 tab（Task 8）、删除 `my_rentals_view.dart`（Task 11）
- [ ] 路由：旧路径重定向（Task 9）
