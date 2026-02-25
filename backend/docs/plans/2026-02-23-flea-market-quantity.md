# 跳蚤市场商品数量（库存）功能

**日期：** 2026-02-23
**状态：** 待开发
**目标：** 卖家发布商品时可设置数量（如"出3个同样的东西"），每次购买减 1，卖完自动下架。

---

## 一、需求概述

| 项目 | 说明 |
|------|------|
| 卖家发布 | 新增"数量"字段，默认 1，最大 999 |
| 买家购买 | 每次只能买 1 个（不支持选购数量） |
| 议价 | 仍按单件议价，不受数量影响 |
| 库存耗尽 | `quantity` 降到 0 时，商品自动变为 `sold` 状态 |
| 向后兼容 | 老数据 `quantity` 默认 1，行为不变 |

## 二、数据流

```
卖家设置 quantity=3
  ↓
买家A购买 → quantity=2, status=active
  ↓
买家B购买 → quantity=1, status=active
  ↓
买家C购买 → quantity=0, status=sold（自动下架）
```

付费商品的完整流程：

```
买家点击购买
  → 后端: quantity -= 1, 创建 task (pending_payment)
  → 买家支付成功 (webhook)
  → 如果 quantity == 0: status = sold
  → 如果 quantity > 0: 商品仍可购买

买家支付超时/取消
  → 后端定时任务: quantity += 1（回滚库存）
  → 商品恢复可购买
```

## 三、改动清单

### 3.1 数据库迁移

**新建文件：** `backend/migrations/097_add_flea_market_quantity.sql`

```sql
-- 跳蚤市场商品增加数量字段
ALTER TABLE flea_market_items
    ADD COLUMN IF NOT EXISTS quantity INTEGER NOT NULL DEFAULT 1;

-- 约束：数量不能为负
ALTER TABLE flea_market_items
    ADD CONSTRAINT check_quantity_non_negative CHECK (quantity >= 0);
```

### 3.2 后端 Model

**文件：** `backend/app/models.py`（`FleaMarketItem` 类，约第 1725 行）

```python
# 在 sold_task_id 下方添加
quantity = Column(Integer, nullable=False, default=1)  # 库存数量
```

`__table_args__` 中添加约束：
```python
CheckConstraint("quantity >= 0", name="check_quantity_non_negative"),
```

### 3.3 后端 Schema

**文件：** `backend/app/schemas.py`

| Schema | 修改 |
|--------|------|
| `FleaMarketItemBase` | 添加 `quantity: int = Field(default=1, ge=1, le=999)` |
| `FleaMarketItemUpdate` | 添加 `quantity: Optional[int] = Field(None, ge=1, le=999)` |
| `FleaMarketItemResponse` | 添加 `quantity: int` |

### 3.4 后端购买流程（核心改动）

**文件：** `backend/app/flea_market_routes.py`

涉及 3 个购买端点，改动逻辑一致：

| 端点 | 函数 |
|------|------|
| `POST /items/{id}/direct-purchase` | 直接购买 |
| `POST /purchase-requests/{id}/approve` | 卖家同意议价 |
| `POST /items/{id}/accept-purchase` | 买家接受卖家议价 |

**当前逻辑（单件）：**
```python
# 防并发：检查 sold_task_id 为空
update_result = await db.execute(
    update(models.FleaMarketItem)
    .where(and_(
        models.FleaMarketItem.id == db_id,
        models.FleaMarketItem.status == "active",
        models.FleaMarketItem.sold_task_id.is_(None)
    ))
    .values(sold_task_id=new_task.id)
)
```

**新逻辑（支持数量）：**
```python
# 防并发：原子递减 quantity，同时检查 quantity > 0
update_result = await db.execute(
    update(models.FleaMarketItem)
    .where(and_(
        models.FleaMarketItem.id == db_id,
        models.FleaMarketItem.status == "active",
        models.FleaMarketItem.quantity > 0
    ))
    .values(
        quantity=models.FleaMarketItem.quantity - 1,
        sold_task_id=new_task.id  # 最后一个购买者的 task_id
    )
)

if update_result.rowcount == 0:
    await db.rollback()
    raise HTTPException(status_code=409, detail="商品已售罄")

# 刷新获取最新 quantity
await db.refresh(item)
if item.quantity == 0:
    item.status = "sold"
```

免费商品额外处理：
```python
if is_free_item:
    # 免费商品不走支付，直接 status 判断
    if item.quantity == 0:
        item.status = "sold"
    # task 直接 in_progress
```

### 3.5 后端支付回调

**文件：** `backend/app/routers.py`（webhook，约第 6265 行）

当前：支付成功后无条件设 `status = "sold"`。

修改为：支付成功后检查 `quantity == 0` 才设 `sold`：
```python
if flea_item:
    if flea_item.quantity == 0:
        flea_item.status = "sold"
    # sold_task_id 已在购买时设置，不再覆盖
```

### 3.6 后端支付超时回滚

**文件：** `backend/app/task_scheduler.py` 或 `backend/app/scheduled_tasks.py`

当 `pending_payment` 任务超时被取消时，需要回滚库存：
```python
# 在支付超时处理逻辑中，如果 task_source == "flea_market"
await db.execute(
    update(models.FleaMarketItem)
    .where(models.FleaMarketItem.sold_task_id == expired_task.id)
    .values(
        quantity=models.FleaMarketItem.quantity + 1,
        status="active",  # 回滚状态（如果之前因 quantity==0 变成 sold）
        sold_task_id=None
    )
)
```

### 3.7 后端商品详情/列表 API

**文件：** `backend/app/flea_market_routes.py`

在构建响应字典时添加 `quantity` 字段：
```python
"quantity": item.quantity,
```

`is_available` 判断从 `sold_task_id is None` 改为 `quantity > 0`。

### 3.8 后端编辑 API

编辑商品时允许修改 `quantity`（仅 `active` 状态）：
```python
if "quantity" in item_data:
    qty = int(item_data["quantity"])
    if qty < 1 or qty > 999:
        raise HTTPException(status_code=400, detail="数量必须在1-999之间")
    item.quantity = qty
```

---

### 3.9 iOS Model

**文件：** `ios/link2ur/link2ur/Models/FleaMarket.swift`

`FleaMarketItem` struct 添加：
```swift
let quantity: Int
```

`CodingKeys` 添加 `case quantity`。

`init(from decoder:)` 中添加：
```swift
quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1
```

### 3.10 iOS 发布/编辑

**文件：**
- `ios/link2ur/link2ur/Views/FleaMarket/CreateFleaMarketItemView.swift`
- `ios/link2ur/link2ur/ViewModels/CreateFleaMarketItemViewModel.swift`
- `ios/link2ur/link2ur/Views/FleaMarket/EditFleaMarketItemView.swift`

添加数量输入（Stepper 或 TextField），范围 1-999，默认 1。

ViewModel 中添加 `@Published var quantity: Int = 1`，请求 body 中加入 `"quantity": self.quantity`。

### 3.11 iOS 详情/列表

**文件：**
- `ios/link2ur/link2ur/Views/FleaMarket/FleaMarketDetailView.swift`
- `ios/link2ur/link2ur/Views/FleaMarket/FleaMarketView.swift`

详情页价格旁显示库存：
```swift
if item.quantity > 1 {
    Text("剩余 \(item.quantity) 件")  // 用 LocalizationKey
}
```

列表页卡片上可选显示库存角标（当 quantity > 1 时）。

### 3.12 Flutter Model

**文件：** `link2ur/lib/data/models/flea_market.dart`

```dart
final int quantity;  // 默认 1
```

`fromJson` 中：
```dart
quantity: _toInt(json['quantity'], defaultValue: 1),
```

`copyWith` 和 `props` 中同步添加。

### 3.13 Flutter 发布/编辑

**文件：**
- `link2ur/lib/features/flea_market/views/create_flea_market_item_view.dart`
- `link2ur/lib/features/flea_market/views/edit_flea_market_item_view.dart`
- `link2ur/lib/features/publish/views/publish_view.dart`

添加数量输入（`TextFormField` 或 Stepper），范围 1-999，默认 1。

### 3.14 Flutter 详情/列表

**文件：**
- `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart`
- `link2ur/lib/features/flea_market/views/flea_market_view.dart`

详情页价格区域显示 "剩余 X 件"（`quantity > 1` 时）。
列表页可选在卡片上显示库存。

### 3.15 国际化

**Flutter ARB 文件** (`link2ur/lib/l10n/app_*.arb`)：
```json
"fleaMarketQuantity": "数量",
"fleaMarketQuantityHint": "请输入数量（1-999）",
"fleaMarketRemainingCount": "剩余 {count} 件",
"fleaMarketSoldOut": "已售罄"
```

**iOS Localizable.strings** (en / zh-Hans / zh-Hant)：
```
"flea_market.quantity" = "数量";
"flea_market.remaining_count" = "剩余 %d 件";
"flea_market.sold_out" = "已售罄";
```

---

## 四、注意事项

1. **并发安全**：使用 SQL `WHERE quantity > 0` + 原子 `quantity = quantity - 1`，数据库级别防超卖，无需应用层锁。

2. **支付超时回滚**：这是最容易遗漏的点。当 `pending_payment` 任务超时被清理时，必须 `quantity += 1` 恢复库存，否则会出现"幽灵库存损失"。

3. **`sold_task_id` 兼容性**：多件商品时 `sold_task_id` 保存最后一个购买者的 task_id。如果未来需要查看所有购买记录，应通过 `tasks` 表的 `task_source = 'flea_market'` 关联查询。

4. **缓存失效**：每次购买后 `invalidate_item_cache(item.id)` 已有，无需额外处理。

5. **向后兼容**：迁移设 `DEFAULT 1`，老数据自动获得 `quantity = 1`，行为完全不变。

---

## 五、实施顺序

| 步骤 | 内容 | 风险 |
|------|------|------|
| 1 | 数据库迁移 | 低 — `ADD COLUMN ... DEFAULT 1` 不锁表 |
| 2 | 后端 model + schema | 低 — 仅添加字段 |
| 3 | 后端购买流程 + webhook + 超时回滚 | **高** — 核心业务逻辑 |
| 4 | 后端 API 响应 + 编辑 | 低 |
| 5 | iOS model + views | 中 |
| 6 | Flutter model + views | 中 |
| 7 | 国际化 | 低 |
