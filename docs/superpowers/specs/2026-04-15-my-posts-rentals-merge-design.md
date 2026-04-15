# 我的闲置与我的租赁合并设计

**日期**：2026-04-15
**范围**：Flutter app (`link2ur/`) + 后端 (`backend/`)
**目标**：将 Profile 菜单中并列的"我的闲置"与"我的租赁"两个入口合并为单一"我的闲置"页面，通过 6 个 tab 统一承载闲置买卖 + 租赁两种业务。

---

## 1. 背景与现状

### 现状

| 页面 | 文件 | 架构 | Tab | 数据 |
|------|------|------|-----|------|
| 我的闲置 | `features/profile/views/my_posts_view.dart` | StatefulWidget + 本地 state + TabController | 4 tab：出售中 / 收的闲置 / 收藏的 / 已售出 | `FleaMarketRepository.getMyRelatedFleaItems` + `getMyFavoriteFleaItems` |
| 我的租赁 | `features/flea_market/views/my_rentals_view.dart` | `FleaMarketRentalBloc` 专用 | 无 tab，单列表带状态徽章 | `FleaMarketRepository.getMyRentals` |

两者都挂在 `ProfileView` 菜单下，都走 `FleaMarketRepository`，业务域同属闲置/租赁。

### 问题

1. 入口分裂，用户需在 Profile 里分辨两个语义相似的菜单项
2. 租赁相关信息（我租出的 listing 状态、我租入的订单）割裂在不同页面
3. `FleaMarketRentalBloc` 仅服务一个页面，过度设计

---

## 2. 合并方案

### 2.1 入口与路由

- **Profile 菜单**：保留单一 `myPostsTitle` 入口（"我的闲置"），移除 `fleaMarketMyRentals` 菜单项。
- **主路由**：`/profile/my-posts`（沿用）
- **兼容重定向**：`/flea-market/my-rentals` → `/profile/my-posts?tab=rented-in`，保证旧深链 / 推送通知不报 404。
- **初始 tab 参数**：`MyPostsView({int initialTab = 0})`。路由 query `?tab=selling|sold|bought|rented-out|rented-in|favorites` 映射到索引。

### 2.2 Tab 结构

6 个 tab，`TabBar` 设 `isScrollable: true`。

| 索引 | Tab 标题 | 视角 | 数据源 | 说明 |
|------|---------|------|--------|------|
| 0 | 出售中 | listing | `getMyRelatedFleaItems(type=sale, status=active)` | 我发布的在售商品 |
| 1 | 已售出 | listing | `getMyRelatedFleaItems(type=sale, status=sold)` | 历史售出 |
| 2 | 收的闲置 | order | `getMyRelatedFleaItems(role=buyer)` | 我买到的商品 |
| 3 | **我租出的** | listing | `getMyRelatedFleaItems(type=rental)` | 我发布的租赁商品，**无论当前是否被租走都显示**，每行带当前租赁状态徽章（可租 / 租赁中 / 逾期） |
| 4 | **我租入的** | order | `getMyRentals()` | 我作为租客的租赁订单，**包含所有状态**（active / returned / overdue / disputed） |
| 5 | 收藏的 | listing | `getMyFavoriteFleaItems()` | 收藏 |

### 2.3 关键语义抉择

- **Tab 3"我租出的"= listing 视角**：展示商品本体，未被租走的也在列表中；点击进入商品详情可查看该商品的租赁订单流水（现有详情页功能）。
- **Tab 4"我租入的"= order 视角**：每行是一笔租赁订单。
- 两者语义不对称，但匹配实际心智：房东关心"我挂出去的东西"，租客关心"我这笔订单"。

---

## 3. 后端改动

### 3.1 必改

**A. `getMyRelatedFleaItems` 增加 `type` 过滤**

端点（以现有路由文件为准，预期在 `backend/app/routers.py` 或 `flea_market_*_routes.py` 中的 `GET /api/flea-market/my-related-items` 类端点）增加 query 参数：

- `type`: `sale` | `rental`（省略 = 全部）

Tab 0/1/3 都依赖此过滤。

**B. `GET /api/flea-market/my-rentals` 确认返回全部状态**

现阶段 `flea_market_rental_routes.py` 已 `WHERE renter_id = current_user.id`，但需确认是否有 `status != returned` 之类的隐性过滤。若有，**移除**，让默认返回全部状态。

前端按需在 UI 层做状态分组/排序。

**C. listing 响应增加 `current_rental_status` 字段**

`FleaMarketItem` 序列化响应对 `type=rental` 的 item 增加字段：

- `current_rental_status`: `available` | `renting` | `overdue` | `null`（非租赁商品）

实现：对每个 rental item 查 `FleaMarketRental WHERE item_id = X AND status IN ('active','overdue') ORDER BY created DESC LIMIT 1`，据此映射。

> 性能注意：需在列表查询里做批量 JOIN 或子查询，避免 N+1。

### 3.2 不做

- ~~原先提过的 `/my-rentals?role=owner|renter|all`~~ — 因 Tab 3 走 listing 端点，无需从订单侧反向聚合。
- 无数据库迁移，无新表。

---

## 4. 前端改动

### 4.1 删除

- `features/flea_market/views/my_rentals_view.dart`
- `features/flea_market/bloc/flea_market_rental_bloc.dart`（及其 events / states `part of` 文件内部定义）
- 对应的 BlocProvider 注册（检查 `app_providers.dart` 及 `flea_market_routes.dart`）
- `ProfileView` 中指向"我的租赁"的菜单项

### 4.2 改造 `my_posts_view.dart`

- **构造参数**：`MyPostsView({this.initialTab = 0})`
- **TabController**：`length: 6`，`initialIndex: widget.initialTab`
- **TabBar**：`isScrollable: true`
- **懒加载**：用 `Map<int, _TabData>` 缓存每 tab 分页状态，首次切换到该 tab 时才触发加载
- **分页**：每 tab 独立 `page` / `hasMore` / `loading` / `items`
- **Tab 3 卡片**：复用 `FleaMarketItemCard`，外层叠加状态徽章（基于 `item.currentRentalStatus`）
- **Tab 4 卡片**：把原 `my_rentals_view` 的卡片样式整体迁移为 `_RentedInTab` 私有 widget，逻辑直接调 `FleaMarketRepository.getMyRentals`

### 4.3 Model 改动

`FleaMarketItem` 增加字段：

```dart
final String? currentRentalStatus; // 'available' | 'renting' | 'overdue' | null
```

- `fromJson`：读 `current_rental_status`，缺失为 `null`
- `copyWith`：加对应参数
- `props`：加入 Equatable 比较

### 4.4 Repository 改动

`FleaMarketRepository.getMyRelatedFleaItems` 增加可选参数：

```dart
Future<...> getMyRelatedFleaItems({
  int page = 1,
  int pageSize = 20,
  String? type,       // 新增: 'sale' | 'rental'
  String? role,       // 既有: 'seller' | 'buyer' 等
  String? status,     // 既有
});
```

`getMyRentals` 签名不变。

### 4.5 i18n

**新增 key**（3 份 ARB 同步：`app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb`）：

| Key | zh | zh_Hant | en |
|-----|-----|--------|-----|
| `myPostsTabRentedOut` | 我租出的 | 我租出的 | Rented Out |
| `myPostsTabRentedIn` | 我租入的 | 我租入的 | Rented In |
| `rentalListingStatusAvailable` | 可租 | 可租 | Available |
| `rentalListingStatusRenting` | 租赁中 | 租賃中 | Renting |
| `rentalListingStatusOverdue` | 逾期 | 逾期 | Overdue |

**保留**：`fleaMarketMyRentals` key 不删（避免潜在遗留引用报错），但菜单不再使用。

### 4.6 错误处理

按项目 `ErrorLocalizer` 约定：

- 各 tab 加载失败 → 该 tab 内显示 `ErrorStateView` + onRetry
- error code：`my_posts_load_failed`（已有）/ 新增 `my_posts_rentals_load_failed`
- 在 `ErrorLocalizer.localize()` 中注册新 code 的 l10n 映射

---

## 5. 测试

### 5.1 后端

- `getMyRelatedFleaItems` with `type=sale` 只返回 sale items
- `getMyRelatedFleaItems` with `type=rental` 返回 rental items，且每项带 `current_rental_status`
- `current_rental_status` 逻辑：无 active 订单 → `available`；有 active 未逾期 → `renting`；有 overdue → `overdue`
- `getMyRentals` 返回 renter 全状态订单

### 5.2 前端

- `MyPostsView` 渲染 6 个 tab，`initialTab` 参数正确生效
- 路由 `/flea-market/my-rentals` 重定向到 `/profile/my-posts?tab=rented-in` 且初始落在 Tab 4
- Tab 3 列表项状态徽章按 `currentRentalStatus` 正确渲染三种样式
- Tab 4 列表复用原状态徽章逻辑，所有状态（active/returned/overdue/disputed）可见
- 各 tab 分页独立，切换后不重新拉第一页
- 删除 `FleaMarketRentalBloc` 后 `flutter analyze` 无引用残留

---

## 6. 跨层一致性清单

按 `full-stack-consistency-check` 要求核对：

- [ ] DB：无改动
- [ ] Backend model：`FleaMarketItem` ORM 无改动（`current_rental_status` 是派生字段，非持久化列）
- [ ] Pydantic schema：`FleaMarketItemOut` 增 `current_rental_status: Optional[str]`
- [ ] API route：`/api/flea-market/my-related-items` 增 `type` 参数；`/api/flea-market/my-rentals` 确认无隐式状态过滤
- [ ] Frontend endpoint：`api_endpoints.dart` 无新增（复用现有端点 + query 参数）
- [ ] Repository：`getMyRelatedFleaItems` 签名增 `type`
- [ ] Model.fromJson：`FleaMarketItem` 增 `currentRentalStatus`
- [ ] BLoC：`FleaMarketRentalBloc` 删除；`MyPostsView` 继续用本地 state（沿袭现有风格）
- [ ] UI：`ProfileView` 菜单项删除、`MyPostsView` 扩 6 tab、删除 `my_rentals_view.dart`
- [ ] 路由：加 `/flea-market/my-rentals` → `/profile/my-posts?tab=rented-in` 重定向

---

## 7. 不做的事（YAGNI）

- 不做 "我租出的订单视图"（owner 角度的订单流水页）—— 通过商品详情页已可查看
- 不改 `getMyRentals` 端点加 `role` 参数
- 不新增数据库列 / 表
- 不重构 `my_posts_view` 为 BLoC（保持 StatefulWidget + 本地 state，现有风格）
- 不做跨版本 Profile 菜单 A/B 切换

---

## 8. 风险与取舍

| 风险 | 缓解 |
|------|------|
| `current_rental_status` 派生字段在列表查询中引入 N+1 | 要求后端实现时用批量子查询或 LEFT JOIN 聚合，code review 时核查 SQL |
| 删除 `FleaMarketRentalBloc` 若有外部引用会编译失败 | 删除前 `grep FleaMarketRentalBloc` 全仓确认仅 `my_rentals_view` 使用 |
| 旧路由 `/flea-market/my-rentals` 的推送通知 payload | 保留路由并做内部重定向，兼容无感 |
| Tab 数量从 4 → 6 可能挤压小屏展示 | `TabBar.isScrollable = true`，允许横向滚动 |
