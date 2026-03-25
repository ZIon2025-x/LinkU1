# 闲置市场二手出租功能设计

## 概述

在现有闲置市场（flea market）基础上，新增「二手出租」功能。发布者可以选择将物品出租而非出售。出租模式包含押金 + 按单位计费的租金，租客需要先申请、出租人审批后才能租用。

## 核心决策

| 决策 | 结论 |
|------|------|
| 实现方案 | 在现有 FleaMarketItem 上扩展字段，不新建独立模块 |
| 出售/出租关系 | 发布时二选一，不可同时支持 |
| 租金模式 | 押金 + 租金单价 × 租期 |
| 租期单位 | 发布者选一个：天 / 周 / 月 |
| 支付方式 | 一次性付清（押金 + 全部租金） |
| 下单流程 | 申请制，出租人审批后租客才能支付 |
| 归还方式 | 出租人手动确认归还，触发退押金 |
| 到期处理 | 仅发通知提醒，不自动扣款 |
| 重复申请 | 被拒绝后可重新申请，无限制 |

## 数据模型

### FleaMarketItem 表 — 新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `listing_type` | String, default `'sale'` | `sale` 或 `rental` |
| `deposit` | Decimal(12,2), nullable | 押金金额（仅 rental） |
| `rental_price` | Decimal(12,2), nullable | 租金单价（仅 rental） |
| `rental_unit` | String, nullable | `day` / `week` / `month` |

### 新增表：FleaMarketRentalRequest

租用申请记录，独立于 PurchaseRequest（出售议价），因为有租期、时间、用途等独有字段。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | PK | |
| `item_id` | FK → FleaMarketItem | |
| `renter_id` | FK → User | 租客 |
| `rental_duration` | Integer | 租几个单位 |
| `desired_time` | Text | 期望开始时间（自由文本） |
| `usage_description` | Text | 使用场景描述 |
| `proposed_rental_price` | Decimal(12,2), nullable | 租客议价的租金单价 |
| `counter_rental_price` | Decimal(12,2), nullable | 出租人还价的租金单价 |
| `status` | String | `pending` / `approved` / `rejected` / `counter_offer` |
| `created_at` | DateTime | |
| `updated_at` | DateTime | |

### 新增表：FleaMarketRental

活跃租赁记录，出租人同意且租客支付成功后创建。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | PK | |
| `item_id` | FK → FleaMarketItem | |
| `renter_id` | FK → User | 租客 |
| `rental_duration` | Integer | 租几个单位 |
| `total_rent` | Decimal(12,2) | rental_price × duration |
| `deposit_amount` | Decimal(12,2) | 快照押金金额 |
| `total_paid` | Decimal(12,2) | total_rent + deposit |
| `currency` | String | GBP / EUR |
| `start_date` | DateTime | 租期开始 |
| `end_date` | DateTime | 租期结束 |
| `status` | String | `active` / `returned` / `overdue` / `disputed` |
| `deposit_status` | String | `held` / `refunded` / `forfeited` |
| `task_id` | FK → Task | 关联的支付任务 |
| `returned_at` | DateTime, nullable | 出租人确认归还时间 |
| `created_at` | DateTime | |

### Flutter 模型变更

**FleaMarketItem** 新增字段：
- `listingType: String` — `'sale'` | `'rental'`
- `deposit: double?` — 押金
- `rentalPrice: double?` — 租金单价
- `rentalUnit: String?` — `'day'` | `'week'` | `'month'`
- `activeRentalId: int?` — 当前活跃租赁 ID（有值表示出租中）

**新增 FleaMarketRentalRequest 模型** — 对应后端表

**新增 FleaMarketRental 模型** — 对应后端表

## API 设计

### 修改现有接口

| 接口 | 变更 |
|------|------|
| `POST /api/flea-market/items` | 支持 `listing_type`, `deposit`, `rental_price`, `rental_unit` 字段 |
| `PUT /api/flea-market/items/{id}` | 可编辑 `deposit`, `rental_price`, `rental_unit`；`listing_type` 不可更改 |
| `GET /api/flea-market/items` | 新增 `listing_type` 查询参数用于筛选 |
| `GET /api/flea-market/items/{id}` | 响应中包含出租字段 + `active_rental_id` |

### 新增接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/flea-market/items/{id}/rental-request` | POST | 提交租用申请 |
| `/api/flea-market/rental-requests/{id}/approve` | POST | 出租人同意 → 创建 Task + PaymentIntent |
| `/api/flea-market/rental-requests/{id}/reject` | POST | 出租人拒绝 |
| `/api/flea-market/rental-requests/{id}/counter-offer` | POST | 出租人议价 |
| `/api/flea-market/rental-requests/{id}/respond-counter-offer` | POST | 租客回应议价 |
| `/api/flea-market/rentals/{id}/confirm-return` | POST | 出租人确认归还 → 退押金 |
| `/api/flea-market/rentals/{id}` | GET | 查看租赁详情 |
| `/api/flea-market/items/{id}/rental-requests` | GET | 出租人查看收到的申请列表 |
| `/api/flea-market/my-rentals` | GET | 租客查看自己的租赁记录 |

### 请求/响应示例

**提交租用申请：**
```json
POST /api/flea-market/items/{id}/rental-request
{
  "rental_duration": 3,
  "desired_time": "下周一开始",
  "usage_description": "周末搬家需要用"
}
```

**出租人议价：**
```json
POST /api/flea-market/rental-requests/{id}/counter-offer
{
  "counter_rental_price": 8.00
}
```

**出租人同意后返回支付信息：**
```json
{
  "task_id": 123,
  "client_secret": "pi_xxx_secret_xxx",
  "amount": 6500,
  "currency": "gbp",
  "deposit_amount": 5000,
  "rent_amount": 1500
}
```

## 发布流程

### 发布页 UI 变更

- 表单顶部新增类型切换：「出售」|「出租」，默认「出售」
- 选「出售」：表单不变
- 选「出租」：隐藏原价格字段，显示：
  - 押金（必填，金额输入）
  - 租金单价（必填，金额输入）
  - 租期单位（下拉：天 / 周 / 月）
- 其余字段（标题、描述、分类、图片、位置）共用

### 后端校验

- `listing_type=sale`：`price` 必填，出租字段忽略
- `listing_type=rental`：`deposit`、`rental_price`、`rental_unit` 必填，`price` 设为 0
- `listing_type` 发布后不可更改

## 列表与详情展示

### 列表页

- 出租物品卡片显示「出租」角标
- 价格显示：出售 `£50`，出租 `£5/天`
- 新增 listing_type 筛选：全部 | 出售 | 出租

### 详情页 — 出租类型

**价格区域：** 租金 `£5/天` + 押金 `£50`

**状态展示：**
- 无活跃租赁 → 可租，显示「申请租用」按钮
- 有活跃租赁 → 显示「出租中」，不可申请

**租客操作 — 申请租用弹窗：**
- 租期：数量输入 + 单位显示（跟随物品设定）
- 期望时间：文本输入，提示"请说明希望什么时候开始租用"
- 使用场景：文本输入，提示"请简要描述用途，帮助出租人了解"
- 底部费用预览：租金小计 + 押金 = 总计

**出租人操作 — 收到申请时：**
- 查看申请详情（租期、期望时间、用途）
- 同意 → 租客收到通知去支付
- 拒绝
- 议价 → 调整租金单价

**出租人操作 — 出租中时：**
- 确认归还 → 确认弹窗 → 退押金 → 物品恢复可租
- 查看租赁详情 → 租客信息、租期、到期时间

## 支付与生命周期

### 支付流程

1. 出租人同意申请 → 创建 Task（`source='flea_market_rental'`）+ Stripe PaymentIntent
2. 租客收到通知 → 进入支付页，金额 = 租金小计 + 押金
3. 复用现有 Stripe 支付流程，一次性付清
4. 支付成功 → 创建 FleaMarketRental（`status=active`），物品标记为出租中

### 租赁生命周期

```
申请提交(pending)
    → 出租人同意(approved) → 租客支付 → 租赁中(active)
    → 出租人拒绝(rejected) → 结束，租客可重新申请
    → 出租人议价(counter_offer) → 租客接受/拒绝
```

```
租赁中(active)
    → 到期提醒(overdue)
    → 出租人确认归还 → returned → Stripe Refund 退押金
    → 出租人发起纠纷 → disputed → 平台介入
```

### 押金退还

- 出租人点「确认归还」→ Stripe Refund 退押金部分到租客原支付方式
- 租金不退
- `deposit_status`: `held` → `refunded`

### 到期提醒

- 到期前 1 天 + 到期当天：给双方发通知
- 超期后每天提醒一次，连续 3 天
- 不自动扣款，等出租人手动操作

### 物品状态流转

- 无活跃租赁 → `active`，可接受新申请
- 有活跃租赁 → 显示「出租中」，不可提交新申请
- 归还后 → 恢复 `active`，可再次出租

## Flutter 前端变更清单

### 模型层（data/models/）

- `FleaMarketItem` 新增 5 个字段
- 新增 `FleaMarketRentalRequest` 模型
- 新增 `FleaMarketRental` 模型

### Repository 层

`flea_market_repository.dart` 新增方法：
- `submitRentalRequest(itemId, duration, desiredTime, usageDescription)`
- `approveRentalRequest(requestId)`
- `rejectRentalRequest(requestId)`
- `counterOfferRental(requestId, counterPrice)`
- `respondRentalCounterOffer(requestId, accept)`
- `confirmReturn(rentalId)`
- `getRentalDetail(rentalId)`
- `getItemRentalRequests(itemId)`
- `getMyRentals(page, pageSize)`

### BLoC 层

在现有 `FleaMarketBloc` 中扩展：

**新增 Events：**
- `FleaMarketSubmitRentalRequest`
- `FleaMarketApproveRentalRequest`
- `FleaMarketRejectRentalRequest`
- `FleaMarketCounterOfferRental`
- `FleaMarketRespondRentalCounterOffer`
- `FleaMarketConfirmReturn`
- `FleaMarketLoadRentalRequests`
- `FleaMarketLoadRentalDetail`

**State 新增字段：**
- `rentalRequests: List<FleaMarketRentalRequest>`
- `isLoadingRentalRequests: bool`
- `currentRental: FleaMarketRental?`
- `listingTypeFilter: String` — `'all'` / `'sale'` / `'rental'`

### View 层

**修改：**
- `create_flea_market_item_view.dart` — 类型切换 + 出租表单字段
- `edit_flea_market_item_view.dart` — 根据类型显示对应字段
- `flea_market_view.dart` — 角标、价格适配、listing_type 筛选
- `flea_market_detail_view.dart` — 出租详情展示、申请弹窗、出租人管理

**新增：**
- `rental_request_sheet.dart` — 租用申请表单底部弹窗
- `rental_detail_view.dart` — 租赁详情页
- `my_rentals_view.dart` — 我的租赁列表

### 本地化

三个 ARB 文件新增约 30-40 个 key。

### 路由

新增：
- `/flea-market/rental/:id` — 租赁详情
- `/flea-market/my-rentals` — 我的租赁列表

## API Endpoints 常量

`api_endpoints.dart` 新增：
```dart
static const String fleaMarketRentalRequest = '/api/flea-market/items/{id}/rental-request';
static const String fleaMarketRentalRequestApprove = '/api/flea-market/rental-requests/{id}/approve';
static const String fleaMarketRentalRequestReject = '/api/flea-market/rental-requests/{id}/reject';
static const String fleaMarketRentalRequestCounterOffer = '/api/flea-market/rental-requests/{id}/counter-offer';
static const String fleaMarketRentalRequestRespondCounterOffer = '/api/flea-market/rental-requests/{id}/respond-counter-offer';
static const String fleaMarketRentalConfirmReturn = '/api/flea-market/rentals/{id}/confirm-return';
static const String fleaMarketRentalDetail = '/api/flea-market/rentals/{id}';
static const String fleaMarketItemRentalRequests = '/api/flea-market/items/{id}/rental-requests';
static const String fleaMarketMyRentals = '/api/flea-market/my-rentals';
```

## 错误处理

新增错误码：
- `flea_market_error_rental_request_failed`
- `flea_market_error_approve_rental_failed`
- `flea_market_error_reject_rental_failed`
- `flea_market_error_counter_offer_rental_failed`
- `flea_market_error_confirm_return_failed`
- `flea_market_error_get_rental_detail_failed`
- `flea_market_error_get_rental_requests_failed`
- `flea_market_error_item_rented` — 物品已被租出
- `flea_market_error_not_rental_item` — 物品不是出租类型
