# UserServicePackage 生命周期补完设计

**Date**: 2026-04-09
**Author**: Brainstorming with Ryan
**Status**: Design phase
**Scope**: Backend (Python/FastAPI) + Flutter (minor UI)

---

## 1. 背景与问题

达人团队套餐子系统 (`UserServicePackage` + `PackageUsageLog`) 在 2026-04 上线了最小可行路径 **购买 → 核销 → 查看**,但整条生命周期的其余环节全部缺失,且存在一个潜在资金问题。

### 1.1 当前套餐系统状态(2026-04-09 审计结果)

**已实现**:
1. 购买流程(`POST /api/services/{id}/purchase-package` → Stripe PaymentIntent → webhook 创建 `UserServicePackage`)
2. 幂等保护(migration 187 加了 `payment_intent_id` partial unique index)
3. QR/OTP 核销(`POST /api/experts/{id}/packages/redeem`)
4. 简单核销(`POST /api/experts/{id}/packages/{pid}/use`,和上面并存,技术债)
5. `PackageUsageLog` 历史记录
6. 用完自动 `status='exhausted'` 状态转换
7. 懒惰式过期检查(核销时发现 `expires_at < now` 就 mark `status='expired'`)

**缺失**:
1. 🔴 **资金释放机制**——钱在平台账户里托管,但没有任何机制转给达人团队的 Stripe Connect 账户。既不是黑洞(钱是安全的),但达人永远收不到。
2. 🔴 **主动退款**——买家无法发起退款,`refund_service.py` 不认识 `UserServicePackage`
3. 🔴 **定时过期处理**——只有懒惰式检查,真正过期未核销的套餐 status 永远停留在 `active`
4. 🟡 **过期前提醒**——`send_package_expiry_reminders` 不存在
5. 🟡 **评价系统**——`Review` 表没有 `package_id` 字段
6. 🟡 **争议流程**——`TaskDispute` 表没有 `package_id` 字段
7. 🟡 **状态机不完整**——代码里只用到 `active / exhausted / expired`,没有 `released / refunded / partially_refunded / disputed / cancelled`
8. 🟡 **`UserServicePackage.task_id` 死字段**——从未被 webhook 或任何代码设置/读取
9. 🟡 **`application_fee` 计算了但从未使用**——`package_purchase_routes.py:275` 算了 fee 存 metadata,但没传给 Stripe,也没留给 release 逻辑用

### 1.2 为什么现在做

- **虽然无生产套餐数据**,但功能已经在线,任何真实购买都会立即触发上述所有 bug
- 先把底座补完,后续"我的订单"页重构(单独 spec)才有意义的数据依托
- 现在做成本最低(无历史数据 backfill 负担)

### 1.3 与套餐相关的 Task 模型比较

用户的核心产品数据模型是"所有付费交互都变成 Task",但**套餐是例外**:

| | Task | UserServicePackage |
|---|---|---|
| 概念 | 一锤子买卖(一次付款一次服务) | 凭证/配额(一次付款多次消费) |
| 数据 | 单次金额、deadline、status | total_sessions/used_sessions/bundle_breakdown/有效期 |
| 状态机 | open→in_progress→completed | active→部分使用→完全使用/过期 |

套餐独立是对的,但独立意味着 **Task 流程已有的所有基础设施(支付转账、退款、争议、评价、定时任务)套餐子系统都要单独接一遍**,这是本次设计的工作量来源。

---

## 2. Scope

### 2.1 In Scope

1. 资金释放机制(释放时机 + 分账公式 + 执行路径)
2. 8 状态状态机定义 + DB CHECK 约束
3. 主动退款端点(冷静期全退 + pro-rata)
4. 定时过期任务 + 过期前提醒
5. 评价系统扩展(reviews 表加 `package_id`)
6. 轻量争议流程(task_disputes 表加 `package_id`,复用 admin 裁决 UI)
7. 通知模板新增
8. 清理死字段 `UserServicePackage.task_id`
9. Flutter 端最小 UI 改动(退款按钮 / 评价按钮 / 过期提醒)

### 2.2 Out of Scope(明确不做)

1. **"我的订单/我的接单"页重构** —— 等套餐底座修完后单独 spec
2. **个人服务支持套餐** —— 短期内保持 `package_purchase_routes.py:200` 的 block
3. **活动支持套餐** —— `Activity` 模型不加 `package_type`
4. **两个核销端点合并** —— 技术债记录留未来做,本次只要求两处同步改动
5. **Stripe Destination Charge 模式** —— 继续用 "separate charges and transfers" 模式,和 Task 流程对齐
6. **`task_source` enum 化 + DB CHECK** —— 顺手可做但不阻塞,本次不含

---

## 3. 关键决策

本节记录讨论中已拍板的所有产品 / 技术决策,供未来 reference。

### 3.1 释放时机 — 方案 C(用完或过期时整体释放)

**决策**:套餐的钱在以下两种情况时整体释放给达人:
- `used_sessions == total_sessions`(完全用完)
- `expires_at < now`(时间过期)

**不选**:每次核销按次释放 / 购买即释放 / 多阶段释放。

**理由**:
- 买家保护最强(active 期间随时可申请 pro-rata 退款)
- 状态机简单(每个套餐只有一次释放事件)
- 分账公式只需实现一次

### 3.2 过期归属 — 全归达人扣 fee,不退买家

**决策**:`expires_at` 到期触发时,**按整额** `paid_amount` 归达人,扣 8% fee,买家**不退款**。

**理由**:
- 符合 Groupon / 健身房月卡 / SPA 代金券的行业惯例
- 在英国消法下合规(只要 `validity_days` 在购买时清楚展示,且期限合理)
- 简化状态机(expired 和 exhausted 释放公式完全一致)

**护栏**(防止达人设套):
- **最小 `validity_days >= 30`** —— 达人后台创建 bundle 套餐时 validation
- **购买时 prominent 展示"有效期 XX 天,过期未使用不退款"** —— Flutter 端
- **过期前 7/3/1 天三次通知** —— 定时任务

### 3.3 主动退款策略 — 场景驱动(不选单一规则)

**决策**:

| 场景 | 条件 | 退款 | 终态 |
|---|---|---|---|
| A | < 24h **且** 0 次使用 | 全额退 `paid_amount` | `refunded` |
| B | < 24h **且** 已使用 ≥1 次 | pro-rata(已用给达人,未用退买家) | `partially_refunded` |
| C1 | ≥ 24h, 未过期, **0 次使用** | 全额退(pro-rata 公式退化:consumed=0 → refund=paid) | `refunded` |
| C2 | ≥ 24h, 未过期, 已使用 ≥1 次 | pro-rata | `partially_refunded` |
| D | `expires_at` 到期 | 不退,全额归达人扣 fee | `released`(via `expired`) |
| E | `used == total` | 全额归达人扣 fee | `released`(via `exhausted`) |

**场景 A 的关键点**:"用过一次就不能享受冷静期全退"——一旦服务开始履行,买家失去"免费体验然后全退"的空间。

**场景 C1 的语义**:"从没用过的套餐无论何时退都应该全退"——英国消费者法下,未提供服务必须退款。实现上 `_process_partial_refund` 检测到 `consumed_value == 0` 时自动 fall-through 到 `_process_full_refund`,terminal status 记为 `refunded`(而非 `partially_refunded`),audit trail 更清晰。

### 3.4 Pro-rata 分账公式 — 方案 2(按子服务单价加权)

**决策**:bundle 套餐的每次消费按**子服务列表单价**加权,bundle 折扣均匀摊到每次消费。

**数学**:

```
unbundled_total = Σ(item.total × item.unit_price_pence)
consumed_list = Σ(item.used × item.unit_price_pence)
consumed_fair_value = paid_amount × (consumed_list / unbundled_total)
unconsumed_fair_value = paid_amount × ((unbundled_total - consumed_list) / unbundled_total)
```

**例子**:bundle A×3(£10 单价) + B×2(£20) + C×1(£30),列表总价 £100,达人定 package_price £80(8 折)。

每次消费的公允价值:
- A 每次 = £10 × 0.8 = £8
- B 每次 = £20 × 0.8 = £16
- C 每次 = £30 × 0.8 = £24

用户消费 2A + 1B + 0C:
- consumed_fair = 2×£8 + 1×£16 = £32
- unconsumed_fair = 1×£8 + 1×£16 + 1×£24 = £48
- 验算:£32 + £48 = £80 ✓

**不选方案 1(按次数等权重)**,因为会被买家套利(只消费高价值子服务然后退款)。

**不选方案 3(让达人自定义权重)**,因为复杂度高且可被达人操控。

### 3.5 平台服务费规则

**决策**:只对"真正落进达人口袋的那笔金额"按 **8%**(`expert_service` 费率,最低 50 便士)抽 fee,最低 50 便士。

```
exhausted:            transfer = paid - fee(paid),        refund = 0
expired:              transfer = paid - fee(paid),        refund = 0
refunded(场景A):     transfer = 0,                       refund = paid
partially_refunded:   transfer = consumed - fee(consumed), refund = unconsumed
```

**未消费部分永远不抽 fee**(服务没发生,平台无理由收)。

### 3.6 合约原则 — Snapshot 定价,达人改价不影响已卖套餐

**决策**:购买时把所有相关单价 snapshot 到 `UserServicePackage`(multi 用 `unit_price_pence_snapshot`,bundle 用 `bundle_breakdown[x].unit_price_pence`)。达人后续修改 `TaskExpertService.base_price` **不影响**已售出的老套餐。

**理由**:合约法原则——购买时已经说好了价格,不能事后改。

### 3.7 异步资金操作 — 复用 Task 流程基础设施

**决策**:套餐的 transfer 和 refund **不同步调 Stripe API**,而是:
1. 状态转换时同步写 DB 状态字段
2. 同时创建 `PaymentTransfer` / `RefundRequest` 行(DB 事务内)
3. 现有的 `payment_transfer_service` / `refund_service` 定时 job 异步处理
4. 成功后回写 `released_at` / `refunded_at`

**为此需要**:
- `payment_transfers` 表加 `package_id` nullable FK(和 `task_id` 二选一)
- `refund_requests` 表加 `package_id` nullable FK(和 `task_id` 二选一)
- 两个服务文件内部加 package 分支处理

### 3.8 争议扩展 — 轻量复用 TaskDispute 基础设施

**决策**:不造新的 `package_disputes` 表,直接在 `task_disputes` 表加 `package_id` nullable FK(和 `task_id` 二选一)。复用现有 admin 裁决 UI + 流程,加一个 package 分支处理器。

**三种 verdict 对套餐的作用**:
- `favor_buyer` → 全额退买家(即使已消费的部分也算"服务不达标")
- `favor_expert` → 全额转达人扣 fee
- `compromise` → 按 Pro-rata 公式分账(复用 `partially_refunded` 逻辑)

### 3.9 评价扩展 — 复用 Review 表

**决策**:`reviews` 表加 `package_id` nullable FK(和 `task_id` 二选一)。套餐评价算入达人的 rating 聚合。

**可评价状态**:`exhausted / expired / released / partially_refunded`(只要有至少一次真实服务发生)。

**不可评价**:`active / refunded / cancelled / disputed`。

### 3.10 部署策略 — 一次性全量

**决策**:无生产套餐数据,无需渐进上线,无需 feature flag,无需 backfill。5 个 migration + backend 代码 + Flutter 代码一次部署完成。

---

## 4. 状态机

### 4.1 完整状态 enum

```
'active'            — 正常可用(含 24h 冷静期)
'exhausted'         — 次数用完(等待 release 异步执行)
'expired'           — 时间过期(等待 release 异步执行)
'released'          — 已释放给达人(终态)
'refunded'          — 冷静期内全额退款(终态)
'partially_refunded'— 冷静期后 pro-rata 退款(终态)
'disputed'          — 争议冻结(admin 处理中)
'cancelled'         — 客服强制取消(终态)
```

**已有(代码里实际用到)**:`active`, `exhausted`, `expired`
**新加**:`released`, `refunded`, `partially_refunded`, `disputed`, `cancelled`

### 4.2 状态转换图

```
                         ┌──────────────┐
                         │   PURCHASE   │
                         │ webhook 创建 │
                         │ cooldown_until = now + 24h
                         └──────┬───────┘
                                │
                                ▼
                           ┌─────────┐
                      ┌────┤ active  ├────┐
                      │    └────┬────┘    │
                用完  │         │         │  到期
               (同步)│         │         │  (cron)
                      │         │         │
                      ▼         │         ▼
                 exhausted      │      expired
                      │         │         │
                      │   24h内 │         │
                      │   0次用 │         │
                      │  (主动退)│         │
                      │         ▼         │
                      │    refunded 🟢    │
                      │ (创建 Refund)     │
                      │                   │
                 PaymentTransfer    PaymentTransfer
                  (async)            (async)
                      │                   │
                      ▼                   ▼
                 released 🟢         released 🟢


            24h 后 / 或 24h 内已用 (主动退款)
                      │
                      ▼
             partially_refunded 🟢
             (同时创建 Transfer + Refund)
             │              │
             │ (async)      │ (async)
             ▼              ▼
        released_at     refunded_at
        (status 不变,partially_refunded 是终态)


          任何 active 期间也可能被触发:
           ├──► disputed  (争议冻结,待 admin 裁决)
           └──► cancelled (客服强制取消,终态)


          🟢 = 终态
```

---

## 5. 数据模型改动

### 5.1 `UserServicePackage` 表(migration 189)

```sql
ALTER TABLE user_service_packages
  -- 24h 冷静期到期时间(purchase webhook 写入 purchased_at + 24h)
  ADD COLUMN cooldown_until TIMESTAMPTZ NULL,

  -- 资金释放记录字段
  ADD COLUMN released_at TIMESTAMPTZ NULL,
  ADD COLUMN released_amount_pence INTEGER NULL,
  ADD COLUMN platform_fee_pence INTEGER NULL,
  ADD COLUMN refunded_amount_pence INTEGER NULL,
  ADD COLUMN refunded_at TIMESTAMPTZ NULL,

  -- multi 套餐的单价快照(bundle 套餐的单价在 bundle_breakdown 里)
  ADD COLUMN unit_price_pence_snapshot INTEGER NULL;

-- 删除死字段(从未被 webhook / 代码写入或读取)
ALTER TABLE user_service_packages DROP COLUMN task_id;

-- status 白名单 CHECK
ALTER TABLE user_service_packages
  ADD CONSTRAINT user_service_packages_status_check
  CHECK (status IN (
    'active','exhausted','expired','released',
    'refunded','partially_refunded','disputed','cancelled'
  ));

-- 定时 job 扫描优化索引
CREATE INDEX IF NOT EXISTS ix_user_packages_status_expires
  ON user_service_packages (status, expires_at);

CREATE INDEX IF NOT EXISTS ix_user_packages_cooldown
  ON user_service_packages (cooldown_until)
  WHERE cooldown_until IS NOT NULL;
```

### 5.2 `payment_transfers` 表(migration 190)

```sql
ALTER TABLE payment_transfers
  ADD COLUMN package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE payment_transfers
  ADD CONSTRAINT payment_transfers_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX ix_payment_transfers_package
  ON payment_transfers(package_id)
  WHERE package_id IS NOT NULL;
```

### 5.3 `refund_requests` 表(migration 191)

```sql
ALTER TABLE refund_requests
  ADD COLUMN package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE refund_requests
  ADD CONSTRAINT refund_requests_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX ix_refund_requests_package
  ON refund_requests(package_id)
  WHERE package_id IS NOT NULL;
```

### 5.4 `reviews` 表(migration 192)

```sql
ALTER TABLE reviews
  ADD COLUMN package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE reviews
  ADD CONSTRAINT reviews_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX ix_reviews_package
  ON reviews(package_id)
  WHERE package_id IS NOT NULL;
```

### 5.5 `task_disputes` 表(migration 193)

```sql
ALTER TABLE task_disputes
  ADD COLUMN package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE task_disputes
  ADD CONSTRAINT task_disputes_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX ix_task_disputes_package
  ON task_disputes(package_id)
  WHERE package_id IS NOT NULL;
```

### 5.6 `bundle_breakdown` JSON 格式升级

**旧格式**(legacy,留 fallback):
```json
{"7": {"total": 3, "used": 0}, "8": {"total": 2, "used": 0}}
```

**新格式**:
```json
{
  "7": {"total": 3, "used": 0, "unit_price_pence": 1000},
  "8": {"total": 2, "used": 0, "unit_price_pence": 2000}
}
```

**在何处 snapshot**:`routers.py:7795` webhook `package_purchase` 分支创建 `UserServicePackage` 时,从 `TaskExpertService.base_price` 读取并写入。

**兼容性代码**:`compute_package_split()` 检测旧格式时退化到"按次数等权重",仅防御用,生产数据不应出现旧格式。

---

## 6. 核心业务逻辑

### 6.1 `compute_package_split()` 辅助函数

位置:**新文件** `backend/app/services/package_settlement.py`

职责:计算一个套餐的分账金额(单位 pence)。

```python
def compute_package_split(package: UserServicePackage) -> dict:
    """返回:
        paid_total_pence:     原始付款总额
        consumed_value_pence: 已消费的公允价值
        unconsumed_value_pence: 未消费的公允价值
        fee_pence:            平台服务费(仅对已消费部分)
        transfer_pence:       应转给达人(已扣 fee)
        refund_pence:         默认 0,调用方按场景填写
        calculation_mode:     bundle_weighted / multi_uniform / legacy_equal
    """
    paid = int(round(float(package.paid_amount) * 100))

    if package.bundle_breakdown:
        has_new_format = all(
            isinstance(item, dict) and "unit_price_pence" in item
            for item in package.bundle_breakdown.values()
        )
        if has_new_format:
            unbundled_total = sum(
                int(item["total"]) * int(item["unit_price_pence"])
                for item in package.bundle_breakdown.values()
            )
            consumed_list = sum(
                int(item["used"]) * int(item["unit_price_pence"])
                for item in package.bundle_breakdown.values()
            )
            mode = "bundle_weighted"
        else:
            # Legacy fallback: 按次数等权重
            total_count = sum(
                int(item["total"]) for item in package.bundle_breakdown.values()
            )
            used_count = sum(
                int(item["used"]) for item in package.bundle_breakdown.values()
            )
            unbundled_total = total_count
            consumed_list = used_count
            mode = "legacy_equal"
    elif package.unit_price_pence_snapshot:
        # multi 模式:均匀价格
        unbundled_total = package.total_sessions * package.unit_price_pence_snapshot
        consumed_list = package.used_sessions * package.unit_price_pence_snapshot
        mode = "multi_uniform"
    else:
        # Legacy fallback:按 session 比例
        unbundled_total = package.total_sessions
        consumed_list = package.used_sessions
        mode = "legacy_equal"

    if unbundled_total == 0:
        # Defensive:全退买家
        return {
            "paid_total_pence": paid,
            "consumed_value_pence": 0,
            "unconsumed_value_pence": paid,
            "fee_pence": 0,
            "transfer_pence": 0,
            "refund_pence": paid,
            "calculation_mode": mode,
        }

    consumed_fair = paid * consumed_list // unbundled_total
    unconsumed_fair = paid - consumed_fair  # 保证两者之和 = paid,避免精度损失

    from app.utils.fee_calculator import calculate_application_fee_pence
    fee = calculate_application_fee_pence(consumed_fair, "expert_service", None)
    transfer = consumed_fair - fee

    return {
        "paid_total_pence": paid,
        "consumed_value_pence": consumed_fair,
        "unconsumed_value_pence": unconsumed_fair,
        "fee_pence": fee,
        "transfer_pence": transfer,
        "refund_pence": 0,
        "calculation_mode": mode,
    }
```

### 6.2 `trigger_package_release()` 共享辅助函数

位置:同上,`package_settlement.py`

职责:在 `exhausted` 或 `expired` 状态下创建 PaymentTransfer 行,供异步 job 执行。

```python
def trigger_package_release(db, pkg: UserServicePackage, reason: str) -> None:
    """套餐释放:创建一行 PaymentTransfer(pending),等 payment_transfer_service 异步处理。

    调用前必须已经把 pkg.status 设置为 'exhausted' 或 'expired'。
    幂等:通过 idempotency_key + released_amount_pence IS NULL 双重保护。
    """
    if pkg.status not in ("exhausted", "expired"):
        raise ValueError(f"Invalid status for release: {pkg.status}")

    if pkg.released_amount_pence is not None:
        # 已经处理过,跳过
        return

    from app.utils.fee_calculator import calculate_application_fee_pence
    paid_pence = int(round(float(pkg.paid_amount) * 100))
    fee = calculate_application_fee_pence(paid_pence, "expert_service", None)
    transfer_pence = paid_pence - fee

    pkg.platform_fee_pence = fee
    # released_amount_pence 和 released_at 等 async job 成功后才回写

    db.add(models.PaymentTransfer(
        task_id=None,
        package_id=pkg.id,
        taker_id=None,
        taker_expert_id=pkg.expert_id,
        poster_id=pkg.user_id,
        amount=transfer_pence / 100.0,
        currency=pkg.currency or "GBP",
        status="pending",
        idempotency_key=f"pkg_{pkg.id}_{reason}",  # "exhausted" or "expired"
    ))
```

### 6.3 主动退款端点逻辑

位置:`package_purchase_routes.py` 新增函数

```python
@package_purchase_router.post("/api/my/packages/{package_id}/refund")
async def request_refund(
    package_id: int,
    body: dict,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    pkg = await _load_package_for_update(db, package_id, current_user.id)

    # 状态守卫
    if pkg.status != "active":
        error_code = {
            "exhausted": "package_already_exhausted",
            "expired": "package_expired",
            "disputed": "package_disputed",
        }.get(pkg.status, "package_not_active")
        raise HTTPException(400, {"error_code": error_code})

    now = get_utc_time()

    # 过期懒检查(防止用户在边缘发起退款)
    if pkg.expires_at and pkg.expires_at < now:
        pkg.status = "expired"
        trigger_package_release(db, pkg, reason="expired")
        await db.commit()
        raise HTTPException(400, {"error_code": "package_expired"})

    in_cooldown = pkg.cooldown_until and now < pkg.cooldown_until
    never_used = pkg.used_sessions == 0
    reason = (body or {}).get("reason", "").strip()[:500]

    if in_cooldown and never_used:
        return await _process_full_refund(db, pkg, reason)
    else:
        return await _process_partial_refund(db, pkg, reason)


async def _process_full_refund(db, pkg, reason):
    paid_pence = int(round(float(pkg.paid_amount) * 100))
    pkg.status = "refunded"
    pkg.refunded_amount_pence = paid_pence

    db.add(models.RefundRequest(
        task_id=None,
        package_id=pkg.id,
        requester_id=pkg.user_id,
        amount=paid_pence / 100.0,
        reason=reason or "cooldown_full_refund",
        status="approved_auto",
        payment_intent_id=pkg.payment_intent_id,
    ))
    await db.commit()
    await _notify_package_refunded(pkg, full=True)

    return {
        "refund_type": "full",
        "status": "refunded",
        "refund_amount_pence": paid_pence,
        "transfer_amount_pence": 0,
        "platform_fee_pence": 0,
    }


async def _process_partial_refund(db, pkg, reason):
    split = compute_package_split(pkg)

    if split["consumed_value_pence"] == 0:
        # 已过 24h 但完全没用 — 对买家公平起见,全退
        return await _process_full_refund(db, pkg, reason)

    if split["unconsumed_value_pence"] == 0:
        # 已全部用完 — 理论上 status 应该已是 exhausted,防御性处理
        raise HTTPException(400, {"error_code": "package_already_exhausted"})

    pkg.status = "partially_refunded"
    pkg.released_amount_pence = split["transfer_pence"]
    pkg.platform_fee_pence = split["fee_pence"]
    pkg.refunded_amount_pence = split["unconsumed_value_pence"]

    db.add(models.PaymentTransfer(
        task_id=None,
        package_id=pkg.id,
        taker_expert_id=pkg.expert_id,
        poster_id=pkg.user_id,
        amount=split["transfer_pence"] / 100.0,
        currency=pkg.currency or "GBP",
        status="pending",
        idempotency_key=f"pkg_{pkg.id}_partial_transfer",
    ))
    db.add(models.RefundRequest(
        task_id=None,
        package_id=pkg.id,
        requester_id=pkg.user_id,
        amount=split["unconsumed_value_pence"] / 100.0,
        reason=reason or "user_cancel_partial",
        status="approved_auto",
        payment_intent_id=pkg.payment_intent_id,
    ))
    await db.commit()
    await _notify_package_refunded(pkg, full=False, split=split)

    return {
        "refund_type": "pro_rata",
        "status": "partially_refunded",
        "refund_amount_pence": split["unconsumed_value_pence"],
        "transfer_amount_pence": split["transfer_pence"],
        "platform_fee_pence": split["fee_pence"],
    }
```

### 6.4 核销端点改动

**`package_purchase_routes.py:623` 附近**:
```python
if pkg.used_sessions >= pkg.total_sessions:
    pkg.status = "exhausted"
    trigger_package_release(db, pkg, reason="exhausted")  # 新增一行
```

**`expert_package_routes.py:115` 附近**:
```python
if package.used_sessions >= package.total_sessions:
    package.status = "exhausted"
    trigger_package_release(db, package, reason="exhausted")  # 新增一行
```

**两处必须同步改动**(技术债已记录:`project_package_redemption_dup.md`)。

### 6.5 Webhook 创建套餐改动

位置:`routers.py:7795` 附近

```python
# 原代码(省略部分):
new_pkg = UserServicePackage(
    user_id=buyer_id,
    service_id=int(service_id_meta),
    expert_id=expert_id_meta,
    total_sessions=final_total,
    used_sessions=0,
    status="active",
    purchased_at=get_utc_time(),
    expires_at=exp_at,
    payment_intent_id=payment_intent_id,
    paid_amount=package_price_meta,
    currency="GBP",
    bundle_breakdown=breakdown,
)

# 新代码(加 3 个字段):
from datetime import timedelta as _td

new_pkg = UserServicePackage(
    user_id=buyer_id,
    service_id=int(service_id_meta),
    expert_id=expert_id_meta,
    total_sessions=final_total,
    used_sessions=0,
    status="active",
    purchased_at=get_utc_time(),
    cooldown_until=get_utc_time() + _td(hours=24),  # 新增
    expires_at=exp_at,
    payment_intent_id=payment_intent_id,
    paid_amount=package_price_meta,
    currency="GBP",
    bundle_breakdown=breakdown,  # 新格式,见 _build_bundle_breakdown 改动
    unit_price_pence_snapshot=(                      # 新增
        int(round(float(service_obj.base_price) * 100))
        if package_type_meta == "multi" else None
    ),
)
```

### 6.6 `_build_bundle_breakdown()` 改动

位置:`package_purchase_routes.py`

新增参数 `db`(用于查 sub_service 的 base_price):

```python
def _build_bundle_breakdown(bundle_service_ids, db) -> dict | None:
    """新格式:{"<sid>": {"total": N, "used": 0, "unit_price_pence": P}}"""
    if not bundle_service_ids:
        return None

    sid_counts = {}
    for item in bundle_service_ids:
        if isinstance(item, int):
            sid_counts[item] = sid_counts.get(item, 0) + 1
        elif isinstance(item, dict):
            sid = item.get("service_id")
            cnt = item.get("count", 1)
            if sid is not None:
                sid_counts[sid] = sid_counts.get(sid, 0) + int(cnt)

    if not sid_counts:
        return None

    sids = list(sid_counts.keys())
    sub_services = db.query(models.TaskExpertService).filter(
        models.TaskExpertService.id.in_(sids)
    ).all()
    price_map = {
        s.id: int(round(float(s.base_price) * 100))
        for s in sub_services
    }

    breakdown = {}
    for sid, total in sid_counts.items():
        breakdown[str(sid)] = {
            "total": total,
            "used": 0,
            "unit_price_pence": price_map.get(sid, 0),
        }
    return breakdown
```

**调用方两处**:
- `routers.py` webhook 分支(sync Session,传 `db`)
- `package_purchase_routes.py:purchase_package` 的前置检查如果要重算(async,需要异步查询 adapter,或者 purchase endpoint 不需要 breakdown,webhook 才需要)

实际只有 webhook 需要调用 `_build_bundle_breakdown`。

### 6.7 `payment_transfer_service.py` 扩展

位置:`backend/app/payment_transfer_service.py`

**当前行为**:扫描 `status='pending'` 的 `PaymentTransfer`,调 `stripe.Transfer.create()` 转钱给 `task.taker_expert_id` 对应的 Stripe Connect 账户,成功后 mark `status='succeeded'`。

**新行为**:同时支持 `package_id` 分支。具体改动:

1. **读取 PaymentTransfer 时**:如果 `transfer_record.package_id IS NOT NULL`,从 `UserServicePackage` 表读 `expert_id` 作为目标 team
2. **destination 计算**:通过 `pkg.expert_id` → `Expert.stripe_account_id`
3. **Stripe Transfer 调用**:除了 metadata 里的 `task_id` 之外,加 `package_id`
4. **成功回写**:除了 mark transfer record `succeeded`,还要回写:
   ```python
   pkg.released_at = now
   pkg.released_amount_pence = int(round(transfer_record.amount * 100))
   if pkg.status in ("exhausted", "expired"):
       pkg.status = "released"
   # partially_refunded 的情况下 status 不变(是终态)
   ```

**幂等性**:`idempotency_key = f"pkg_{pkg.id}_{reason}"`(reason ∈ `exhausted / expired / partial_transfer`)确保不会重复转账。

### 6.8 `refund_service.py` 扩展

位置:`backend/app/refund_service.py`

**当前行为**:处理 task 相关的 `RefundRequest`,调 `stripe.Refund.create(payment_intent=...)`。

**新行为**:支持 `package_id` 分支,调用同样的 Stripe Refund API(用 `pkg.payment_intent_id`),成功后回写:
```python
pkg.refunded_at = now
pkg.refunded_amount_pence = int(round(refund_request.amount * 100))
# status 不变(refunded / partially_refunded 是终态)
```

---

## 7. 定时任务

新增两个,位置:`backend/app/scheduled_tasks.py`,注册到 `task_scheduler.py`。

### 7.1 `check_expired_packages`

**间隔**:3600 秒(1 小时)

**逻辑**:
```python
def check_expired_packages(db):
    now = get_utc_time()
    expired_pkgs = db.query(UserServicePackage).filter(
        UserServicePackage.status.in_(["active", "expired"]),
        UserServicePackage.expires_at < now,
        UserServicePackage.released_at.is_(None),
    ).limit(500).all()

    processed = 0
    for pkg in expired_pkgs:
        try:
            if pkg.status == "active":
                pkg.status = "expired"
            trigger_package_release(db, pkg, reason="expired")
            processed += 1
        except Exception as e:
            logger.error(f"Failed to process expired package {pkg.id}: {e}")
            continue

    if processed > 0:
        db.commit()
        logger.info(f"check_expired_packages: processed {processed} packages")

    return {"processed": processed}
```

### 7.2 `send_package_expiry_reminders`

**间隔**:3600 秒(每小时扫描,每个窗口只发一次)

**逻辑**:
```python
def send_package_expiry_reminders(db):
    now = get_utc_time()
    sent = 0

    # 三个提醒窗口:7 天、3 天、1 天
    for days, reminder_key in [(7, "7d"), (3, "3d"), (1, "1d")]:
        window_start = now + timedelta(days=days, hours=-12)
        window_end = now + timedelta(days=days, hours=12)

        due = db.query(UserServicePackage).filter(
            UserServicePackage.status == "active",
            UserServicePackage.expires_at.between(window_start, window_end),
            UserServicePackage.used_sessions < UserServicePackage.total_sessions,
        ).all()

        for pkg in due:
            # 去重:查看该 package 是否已发过该 reminder_key 的通知
            existing = db.query(Notification).filter(
                Notification.user_id == pkg.user_id,
                Notification.related_id == str(pkg.id),
                Notification.type == f"package_expiry_reminder_{reminder_key}",
            ).first()
            if existing:
                continue

            _send_expiry_reminder(db, pkg, reminder_key)
            sent += 1

    if sent > 0:
        db.commit()
        logger.info(f"send_package_expiry_reminders: sent {sent} reminders")

    return {"sent": sent}
```

### 7.3 现有 `process_pending_payment_transfers` 改动

不改任务本身的调度,只改内部处理逻辑(增加 `package_id` 分支,见 6.7)。

---

## 8. API 端点清单

### 8.1 新增端点

| 方法 | 路径 | 用途 |
|---|---|---|
| POST | `/api/my/packages/{package_id}/refund` | 买家主动退款 |
| POST | `/api/my/packages/{package_id}/review` | 套餐评价 |
| POST | `/api/my/packages/{package_id}/dispute` | 开启争议 |

### 8.2 修改端点

| 方法 | 路径 | 改动 |
|---|---|---|
| POST | `/api/services/{service_id}/purchase-package` | webhook 分支写入新字段 |
| POST | `/api/experts/{expert_id}/packages/redeem` | exhausted 时 `trigger_package_release` |
| POST | `/api/experts/{expert_id}/packages/{package_id}/use` | 同上(老核销端点) |
| GET | `/api/my/packages` | 响应加新字段 + `can_*` 布尔位 |
| GET | `/api/my/packages/{package_id}` | 同上 + `split_preview` |
| GET | `/api/admin/disputes` | 支持 `package_id` 过滤 |
| POST | `/api/admin/disputes/{id}/resolve` | 裁决时走 package 分支 |

### 8.3 GET `/api/my/packages` 响应新字段

```json
{
  "id": 123,
  "service_id": 7,
  "expert_id": "78682901",
  "total_sessions": 10,
  "used_sessions": 3,
  "remaining_sessions": 7,
  "status": "active",
  "status_display": "使用中",              // 新:i18n 后的用户可读状态
  "purchased_at": "2026-04-09T14:00:00Z",
  "cooldown_until": "2026-04-10T14:00:00Z", // 新
  "in_cooldown": true,                      // 新
  "expires_at": "2026-06-09T14:00:00Z",
  "payment_intent_id": "pi_xxx",
  "paid_amount": 100.0,
  "currency": "GBP",
  "bundle_breakdown": {...},
  "released_amount_pence": null,            // 新
  "refunded_amount_pence": null,            // 新
  "platform_fee_pence": null,               // 新
  "released_at": null,                      // 新
  "refunded_at": null,                      // 新
  "can_refund_full": true,                  // 新
  "can_refund_partial": false,              // 新
  "can_review": false,                      // 新
  "can_dispute": false                      // 新
}
```

---

## 9. 通知模板

新增 9 个,位置:`backend/app/utils/notification_templates.py`

| key | 触发 | 收件人 |
|---|---|---|
| `package_exhausted_released` | 套餐用完释放成功 | expert team owner/admin |
| `package_expired_released` | 套餐过期释放成功 | expert team + buyer |
| `package_expiry_reminder_7d` | 过期前 7 天有未使用 | buyer |
| `package_expiry_reminder_3d` | 过期前 3 天 | buyer |
| `package_expiry_reminder_1d` | 过期前 1 天 | buyer |
| `package_refunded_full` | 冷静期全退完成 | buyer + expert |
| `package_refunded_partial` | pro-rata 退款完成 | buyer + expert |
| `package_dispute_opened` | 买家开启争议 | expert + admin |
| `package_dispute_resolved` | admin 裁决完成 | buyer + expert |

全部复用现有的 `create_notification()` 基础设施 + i18n 模板系统,双语(中英)。

---

## 10. Flutter 端改动(最小)

### 10.1 `UserServicePackage` 模型新增字段

`link2ur/lib/data/models/user_service_package.dart`:

```dart
final DateTime? cooldownUntil;
final bool inCooldown;
final int? releasedAmountPence;
final int? refundedAmountPence;
final int? platformFeePence;
final DateTime? releasedAt;
final DateTime? refundedAt;
final bool canRefundFull;
final bool canRefundPartial;
final bool canReview;
final bool canDispute;
final String statusDisplay;
```

### 10.2 `PackagePurchaseRepository` 新方法

`link2ur/lib/data/repositories/package_purchase_repository.dart`:

```dart
Future<RefundResponse> requestRefund(int packageId, {String? reason});
Future<void> submitReview(int packageId, int rating, String comment);
Future<void> openDispute(int packageId, String reason, List<String> evidenceUrls);
```

### 10.3 `my_package_detail_view.dart` UI 改动

在详情页加三个按钮(条件显示):
- **申请退款**(`can_refund_full || can_refund_partial` 时显示)
- **评价**(`can_review` 时显示)
- **开启争议**(`can_dispute` 时显示)

加一个 banner 提示:
- 如果 `in_cooldown` → "24 小时冷静期内,未使用可全额退款"
- 如果 `expires_at` 在 7 天内 → "套餐将于 X 天后过期,请及时使用"

### 10.4 `i18n` 新增 key(约 20 个)

所有新增文案的中/英版本加入 `app_en.arb / app_zh.arb / app_zh_Hant.arb`。

---

## 11. Migration + 部署

### 11.1 Migration 清单(5 个,执行顺序不敏感因为互不冲突)

- `backend/migrations/189_package_lifecycle_fields.sql`
- `backend/migrations/190_payment_transfers_add_package.sql`
- `backend/migrations/191_refund_requests_add_package.sql`
- `backend/migrations/192_reviews_add_package.sql`
- `backend/migrations/193_task_disputes_add_package.sql`

### 11.2 部署步骤

1. `git pull` + run 5 个 migration
2. 部署 backend(webhook 改动、核销释放、新端点、定时任务、通知)
3. 部署 Flutter(可稍后,老版本对新字段是宽容读取)

**无需**:feature flag / 渐进上线 / 数据 backfill / 回滚预案(除常规 `git revert`)—— 因为无生产套餐数据。

### 11.3 Smoke test(部署后手动跑)

**环境**:生产 Stripe test mode

**测试账号**:一个普通买家 + 一个达人团队 owner

**9 条路径**:

| # | 步骤 | 期望 |
|---|---|---|
| 1 | 买 multi 套餐 £10(10 次 £1) | DB 有 `cooldown_until` 和 `unit_price_pence_snapshot` |
| 2 | 立即退款(0 次用,24h 内) | 全退 £10,status='refunded',refund_requests 有行 |
| 3 | 再买一个,核销 1 次,退款 | Pro-rata:达人 £0.92,买家 £9,status='partially_refunded' |
| 4 | 再买一个,核销 10 次 | 自动 exhausted,几分钟后 released,达人拿 £9.20 |
| 5 | 再买一个,手动把 `expires_at` 改到过去 | 1 小时内 cron 触发 → expired → released,达人拿 £9.20 |
| 6 | 买 bundle(A×2 £5 + B×3 £10 共 £40),核销 A×1 + B×1,退款 | 已消费公允价值 £15 → 达人 £13.80,买家退 £25 |
| 7 | 买一个,用完,评价 | Review 表有 package_id,达人 rating 聚合包含 |
| 8 | 买一个,核销 1 次,开启争议 | status='disputed',pending transfer 冻结 |
| 9 | Admin 裁决(三种 verdict 各跑一次) | 金额分布正确 |

---

## 12. 测试策略

### 12.1 单元测试

新文件 `backend/tests/test_package_settlement.py`:

- `test_compute_package_split_bundle_weighted` — 方案 2 的典型 bundle
- `test_compute_package_split_multi_uniform` — multi 等权重
- `test_compute_package_split_legacy_no_unit_price` — 老格式兜底
- `test_compute_package_split_zero_unbundled` — 防御:unbundled_total == 0 时全退
- `test_compute_package_split_all_consumed` — 100% 消费
- `test_compute_package_split_zero_consumed` — 0% 消费
- `test_trigger_package_release_idempotent` — 重复调用只创建一行

新文件 `backend/tests/test_package_refund_endpoint.py`:

- `test_refund_cooldown_full` — 场景 A
- `test_refund_cooldown_but_used` — 场景 B
- `test_refund_after_cooldown` — 场景 C
- `test_refund_expired_rejected` — 场景 D(过期不退)
- `test_refund_disputed_rejected` — 争议中不可退
- `test_refund_exhausted_rejected` — 已用完不可退

### 12.2 集成测试

`backend/tests/test_package_lifecycle_integration.py`:

- `test_webhook_creates_package_with_cooldown_and_snapshot`
- `test_redeem_to_exhausted_triggers_release`
- `test_expired_cron_triggers_release`
- `test_partial_refund_creates_transfer_and_refund`
- `test_review_contributes_to_expert_rating`
- `test_dispute_freezes_pending_transfer`

### 12.3 手动 smoke test

见 11.3。

---

## 13. 技术债记录

1. **两个核销端点并存**(`package_purchase_routes.py` + `expert_package_routes.py`)—— 本次改动必须两处同步,未来应合并。已记录:`memory/project_package_redemption_dup.md`
2. **`application_fee` 字段在 `package_purchase_routes.py:295` 的 metadata 里是 dead data** —— 本次修复后,实际 fee 从 `compute_package_split()` 算出,metadata 里的字段可以考虑删除(下个迭代)
3. **`task_source` 字段缺 DB CHECK 约束** —— 和套餐无直接关系,但整体 Task 模型健康度可以顺手提升,本次不做

---

## 14. 成功指标(部署后观察)

- **核心指标**:套餐购买到达人 Stripe Connect 账户收到钱的 lead time < 24 小时(用完/过期后)
- **错误率**:`payment_transfers` 里 package_id 非空的行,`status='succeeded'` 占比 > 99%
- **用户行为**:至少一次完整跑通 "买 → 全用 → 评价" 流程
- **异常监控**:7 天内无 `UserServicePackage` 卡在 `exhausted` 或 `expired` 超过 24 小时未变 `released`

---

## 15. Appendix · 参考文件

- `backend/app/models_expert.py:289` — UserServicePackage 模型
- `backend/app/package_purchase_routes.py` — 购买 + 核销 + 新端点位置
- `backend/app/expert_package_routes.py` — 老核销端点(需同步修改)
- `backend/app/routers.py:7738` — webhook package_purchase 分支
- `backend/app/payment_transfer_service.py` — 异步转账服务(需扩展)
- `backend/app/refund_service.py` — 异步退款服务(需扩展)
- `backend/app/utils/fee_calculator.py:42` — 平台费计算(复用)
- `backend/app/scheduled_tasks.py` — 定时任务(加新任务)
- `backend/app/task_scheduler.py` — 定时任务注册(加新注册)
- `link2ur/lib/features/expert_team/views/expert_packages_view.dart` — 买家侧套餐列表 UI

---

**End of Design Doc**
