# Local Wallet System Design

本地钱包余额系统 — 允许用户先赚钱、后设置收款账户提现

## Background

当前系统中，任务完成后平台直接通过 `stripe.Transfer` 将资金转入用户的 Stripe Connect 账户。这要求用户在接单/卖东西之前就完成 Connect 账户设置（包含 KYC 验证），注册摩擦大。

本设计引入**本地钱包余额系统**，将资金记录与 Stripe Connect 解耦：
- 用户无需 Connect 账户即可接单、卖二手物品、查看收入
- 仅在提现时才需要设置 Connect 账户
- 同时支持余额支付任务（含混合支付）

## Data Models

### WalletAccount 表

```sql
CREATE TABLE wallet_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) UNIQUE,
    balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    total_earned DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_withdrawn DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_spent DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'GBP',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

- `balance`: 可用余额（英镑），数据库级 CHECK 约束确保非负
- `total_earned`: 累计收入（扣手续费后的净收入）
- `total_withdrawn`: 累计已提现金额
- `total_spent`: 累计余额支付消费金额
- `currency`: 默认 GBP，预留多币种扩展

### WalletTransaction 表

```sql
CREATE TABLE wallet_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id),
    type VARCHAR(20) NOT NULL,          -- earning, withdrawal, payment
    amount DECIMAL(12, 2) NOT NULL,     -- 正数=收入, 负数=支出
    balance_after DECIMAL(12, 2) NOT NULL,
    source VARCHAR(50) NOT NULL,        -- task_reward, flea_market_sale, stripe_transfer, task_payment
    related_id VARCHAR(255),            -- 关联对象 ID
    related_type VARCHAR(50),           -- task, flea_market_item, payout
    description TEXT,
    fee_amount DECIMAL(12, 2),          -- 平台手续费（仅 earning 类型）
    gross_amount DECIMAL(12, 2),        -- 扣费前原始金额（仅 earning 类型）
    idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_wallet_tx_user_id ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_tx_type ON wallet_transactions(type);
CREATE INDEX idx_wallet_tx_created_at ON wallet_transactions(created_at);
CREATE INDEX idx_wallet_tx_related ON wallet_transactions(related_type, related_id);
```

- `idempotency_key`: 防重复入账，格式如 `earning:task:{task_id}:user:{user_id}`
- `balance_after`: 每笔交易后的余额快照，便于审计
- `fee_amount` + `gross_amount`: 仅 earning 类型使用，记录毛收入和手续费

## Safety Mechanisms

### 1. 数据库级保障

- **余额非负约束**: `CHECK (balance >= 0)` — 即使代码有 bug 也不会出现负余额
- **行级锁**: 所有余额变更使用 `SELECT ... FOR UPDATE` 锁定 WalletAccount 行
- **事务原子性**: 余额变更 + 流水写入在同一事务中，要么都成功要么都回滚

### 2. 幂等性保障

每笔操作生成唯一 `idempotency_key`:
- 收入: `earning:task:{task_id}:user:{user_id}`
- 提现: `withdrawal:{timestamp}:user:{user_id}`
- 支付: `payment:task:{task_id}:user:{user_id}`

插入前检查 key 是否已存在，已存在则跳过，绝不重复入账。

### 3. 双重记账校验

每笔操作流程:
1. `SELECT wallet_account FOR UPDATE WHERE user_id = ?`
2. 检查 `balance >= 扣减金额`（支出类）
3. 更新 `balance`
4. 插入 WalletTransaction，`balance_after = 更新后的 balance`
5. COMMIT

可通过 `SUM(amount) WHERE user_id = ?` 与 `balance` 比对进行定期对账。

## Business Flows

### 1. 任务完成 → 入账（替代现有 stripe.Transfer）

```
confirm_completion 被调用
  ↓
计算手续费（根据任务类型，后端已有逻辑）
  ↓
净收入 = escrow_amount - 手续费
  ↓
检查 idempotency_key 是否已存在 → 已存在则跳过
  ↓
锁定接单人 WalletAccount (FOR UPDATE)
  ↓
balance += 净收入
total_earned += 净收入
  ↓
写入 WalletTransaction:
  type=earning, source=task_reward
  amount=净收入, gross_amount=escrow_amount, fee_amount=手续费
  related_id=task_id, related_type=task
  ↓
COMMIT
```

不再调用 `stripe.Transfer`。二手物品售出同理，`source=flea_market_sale`。

### 2. 提现流程

```
用户请求提现(amount)
  ↓
检查 Connect 账户
  ├─ 无 → 返回 HTTP 428，引导设置
  └─ 有 → 继续
  ↓
锁定 WalletAccount (FOR UPDATE)
  ↓
验证 balance >= amount
  ↓
balance -= amount
total_withdrawn += amount
  ↓
写入 WalletTransaction:
  type=withdrawal, source=stripe_transfer
  amount=-amount
  ↓
stripe.Transfer(amount_in_pence, destination=connect_account_id)
  ├─ 成功 → COMMIT
  └─ 失败 → ROLLBACK（余额自动恢复）
```

### 3. 余额支付（混合支付）

```
用户发起任务支付 (use_wallet_balance=true)
  ↓
total_amount = 任务总价
  ↓
锁定 WalletAccount (FOR UPDATE)
  ↓
wallet_deduction = min(balance, total_amount)
stripe_amount = total_amount - wallet_deduction

if stripe_amount > 0:
  创建 PaymentIntent(amount=stripe_amount_in_pence)
  ↓
  Webhook 确认支付成功后:
    锁定 WalletAccount (FOR UPDATE)
    balance -= wallet_deduction
    total_spent += wallet_deduction
    写入 WalletTransaction:
      type=payment, source=task_payment
      amount=-wallet_deduction
      related_id=task_id, related_type=task
    标记任务已支付
    COMMIT
else:
  全额余额支付:
    balance -= total_amount
    total_spent += total_amount
    写入 WalletTransaction (同上)
    直接标记任务已支付（无需 PaymentIntent）
    COMMIT
```

### 4. 去掉的校验

- **接单**: 去掉 Connect 账户 `chargesEnabled` 校验
- **发布二手物品**: 去掉 Connect 账户校验
- 这两个场景只需用户登录即可

## API Design

### 新增接口

#### GET `/api/wallet/balance`

```json
Response: {
  "balance": 90.00,
  "total_earned": 150.00,
  "total_withdrawn": 50.00,
  "total_spent": 10.00,
  "currency": "GBP"
}
```

#### GET `/api/wallet/transactions?page=1&page_size=20&type=earning`

```json
Response: {
  "items": [{
    "id": 1,
    "type": "earning",
    "amount": 90.00,
    "balance_after": 90.00,
    "source": "task_reward",
    "gross_amount": 100.00,
    "fee_amount": 10.00,
    "description": "任务 #123 奖励",
    "related_id": "123",
    "related_type": "task",
    "created_at": "2026-03-25T10:00:00Z"
  }],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

#### POST `/api/wallet/withdraw`

```json
Request: { "amount": 50.00 }
Response: {
  "success": true,
  "transfer_id": "tr_xxx",
  "amount": 50.00,
  "balance_after": 40.00
}
// 前提: 用户已设置 Connect 账户，否则返回 428
```

### 修改的现有接口

| 接口 | 改动 |
|------|------|
| `POST /tasks/{task_id}/confirm_completion` | 不再调用 stripe.Transfer，改为本地入账 |
| `POST /coupon-points/tasks/{task_id}/payment` | 新增 `use_wallet_balance` 字段，支持混合支付 |
| 接单相关接口 | 去掉 Connect 账户校验 |
| 发布二手物品相关接口 | 去掉 Connect 账户校验 |
| `GET /coupon-points/account` | `total_payment_income` 改为查 WalletAccount.total_earned |

## Flutter Frontend Changes

### 1. 钱包页面 (wallet_view.dart)

- "未提现收入" → 从 `GET /api/wallet/balance` 读 `balance`（替代 Stripe Connect Balance）
- "累计收入" / "累计消费" → 从同一接口读 `total_earned` / `total_spent`
- Connect 状态区域改为"提现账户设置"，不影响余额显示

### 2. 提现页面 (stripe_connect_payouts_view.dart)

- 余额从本地钱包接口读取
- 提现按钮: 没有 Connect 账户 → 弹窗引导设置; 有 → 正常提现
- 调用 `POST /api/wallet/withdraw`

### 3. 任务支付页面

- 新增余额支付选项（开关/勾选"使用余额支付"）
- 余额够 → 显示"余额支付 £X"
- 余额不够 → 显示"余额抵扣 £X + 银行卡支付 £Y"
- 不使用余额 → 走原有 Stripe 支付流程

### 4. 新增/修改 Repository & BLoC

- `PaymentRepository` 新增: `getWalletBalance()`, `getWalletTransactions()`, `requestWithdrawal()`
- `WalletBloc` 修改: 加载本地钱包余额替代 Stripe Connect Balance
- 新增 `WalletWithdrawRequested` 事件

### 5. 去掉 Connect 校验 UI

- `task_detail_view.dart` — 去掉 `stripe_setup_required` 弹窗拦截
- `create_flea_market_item_view.dart` — 去掉 `stripe_setup_required` 弹窗拦截

### 6. 流水页面

交易记录从 Stripe API 读取 → 改为从 `/api/wallet/transactions` 读取本地流水。

## Data Migration

### 老用户历史数据迁移

一次性迁移脚本:

1. **收入记录**: 遍历 `PaymentTransfer WHERE status=succeeded`，为每条创建 `WalletTransaction(type=earning, source=task_reward)`
2. **提现记录**: 查 Stripe Payout 历史，写入 `WalletTransaction(type=withdrawal, source=stripe_transfer)`
3. **余额处理**: 老用户的 `WalletAccount.balance` 设为 **0**（钱已在 Connect 账户里，不在平台）
4. **累计字段**: `total_earned` / `total_withdrawn` 根据迁移的流水计算

### 现有 PaymentTransfer 表

保留不删，角色变更:
- **之前**: 任务完成时创建，执行 stripe.Transfer 给用户
- **之后**: 仅在用户主动提现时创建，记录提现的 stripe.Transfer
- `process_pending_transfers()` 定时任务保留，处理提现失败重试

## Currency

- 平台统一使用 GBP 记账和转账
- 非 GBP 国家的用户提现时，Stripe 自动换汇到 Connect 账户对应货币
- 换汇手续费由 Stripe 收取（约 1%），用户承担
