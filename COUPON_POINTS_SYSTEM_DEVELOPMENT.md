# 优惠券和积分系统开发日志

> **版本**: v3.1（权威版）  
> **最后更新**: 2025-01-20  
> **设计原则**: 大厂标准、合规优先、性能优化、可扩展性  
> **重要说明**: 本文档为最终权威版本，所有表结构、API接口、数据类型均已统一为最新规范
> **更新说明**: 
> - 统一字段类型：所有时间字段使用 TIMESTAMPTZ，所有ID字段使用 BIGSERIAL/BIGINT
> - 统一交易来源命名：移除 task_payment，统一使用 platform_fee
> - 统一积分奖励策略：任务完成和邀请奖励改为固定值或梯度值，明确标注"平台赠送，非任务报酬"
> - 优化并发控制：使用部分唯一索引（WHERE子句）替代表级唯一约束

---

## 📋 需求概述

开发一套完整的优惠券和积分系统，用于提升用户活跃度和平台粘性。积分作为平台奖励机制，仅限平台内使用，不可提现，避免触发电子货币监管。

**核心功能：**
- **优惠券系统**：支持多种优惠券类型（满减券、折扣券、新用户券等），可设置有效期、使用条件限制
- **积分系统**：用户完成任务、邀请好友等行为获得积分奖励，积分仅限平台内抵扣费用，不可提现、不可转账
- **积分使用范围**：仅可抵扣平台侧收费（发布费/会员/平台服务费），可兑换自营商品、兑换折扣券，不得用于向第三方付款，不可提现/转账（合规要求）
- **签到系统**：每日签到功能，连续签到可获得积分或优惠券奖励
- **邀请码系统**：管理员可创建邀请码，设置注册奖励，查看使用统计和用户详情
- **管理员配置**：所有系统参数（积分规则、优惠券规则、签到规则、邀请码规则）都可在管理员后台配置
- **反滥用风控**：设备指纹、行为频控、限额与冷却期等风控措施
- **优惠叠加规则**：可配置的优惠叠加矩阵和计算顺序

**业务价值：**
- 提升用户注册和活跃度
- 增加任务完成率
- 促进用户邀请和分享
- 增强用户粘性和复购率

---

## 🗄️ 数据库模型设计

### 1. 优惠券表 (coupons)

```sql
CREATE TABLE coupons (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,  -- 优惠券代码（不区分大小写唯一）
    name VARCHAR(100) NOT NULL,  -- 优惠券名称
    description TEXT,  -- 优惠券描述
    type VARCHAR(20) NOT NULL,  -- 类型：fixed_amount(满减), percentage(折扣)
    discount_value BIGINT,  -- 优惠金额或折扣基点（整数）
    -- fixed_amount: 直接减免金额（最小货币单位，如200 = £2.00）
    -- percentage: 折扣基点（basis points），如1000表示10%（计算时用 bp/10000）
    min_amount BIGINT DEFAULT 0,  -- 最低使用金额（整数，最小货币单位）
    max_discount BIGINT,  -- 最大折扣金额（整数，最小货币单位）
    currency CHAR(3) DEFAULT 'GBP',  -- 货币类型
    total_quantity INTEGER,  -- 总发放数量（NULL表示无限制，需用触发器或查询统计实际使用）
    per_user_limit INTEGER DEFAULT 1,  -- 每个用户限用次数
    per_device_limit INTEGER,  -- 每个设备限用次数（反滥用）
    per_ip_limit INTEGER,  -- 每个IP限用次数（反滥用）
    can_combine BOOLEAN DEFAULT false,  -- 是否可与其他优惠叠加
    combine_limit INTEGER DEFAULT 1,  -- 最多可叠加数量（如果can_combine=true）
    apply_order INTEGER DEFAULT 0,  -- 应用顺序（数值越小越先应用，用于叠加计算）
    valid_from TIMESTAMPTZ NOT NULL,  -- 有效期开始时间（带时区）
    valid_until TIMESTAMPTZ NOT NULL,  -- 有效期结束时间（带时区）
    status VARCHAR(20) DEFAULT 'active',  -- 状态：active, inactive, expired
    -- 使用条件限制（JSON格式存储，便于扩展）
    usage_conditions JSONB,  -- 使用条件：地点、时间、任务类型等限制（包含timezone字段）
    eligibility_type VARCHAR(20),  -- 资格类型：first_order(首单), new_user(新用户), user_type(用户类型), member(会员), all(所有用户)
    eligibility_value TEXT,  -- 资格值（如果eligibility_type=user_type，存储用户类型列表JSON）
    per_day_limit INTEGER,  -- 每日限用次数（按用户）
    vat_category VARCHAR(20),  -- VAT分类（用于税务处理）
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_coupons_code_lower UNIQUE (LOWER(code)),  -- 不区分大小写唯一索引
    CONSTRAINT chk_coupon_dates CHECK (valid_until > valid_from),  -- 有效期结束时间必须大于开始时间
    CONSTRAINT chk_coupon_discount CHECK (
        (type = 'fixed_amount' AND discount_value > 0) OR
        (type = 'percentage' AND discount_value BETWEEN 1 AND 10000)
    )  -- 满减券折扣值必须>0，折扣券折扣基点必须在1-10000之间（0.01%-100%）
);

CREATE INDEX idx_coupons_status ON coupons(status);
CREATE INDEX idx_coupons_valid ON coupons(valid_from, valid_until);
CREATE INDEX idx_coupons_conditions ON coupons USING GIN(usage_conditions);  -- GIN索引用于JSONB查询
CREATE INDEX idx_coupons_combine ON coupons(can_combine, apply_order);  -- 叠加规则索引
```

**字段说明：**
- `type`: 
  - `fixed_amount`: 满减券，如满10减2
  - `percentage`: 折扣券，使用基点（basis points）表示
- `discount_value`: 
  - **满减券（fixed_amount）**：直接减免金额（整数，最小货币单位，如200 = £2.00 = 200 pence）
  - **折扣券（percentage）**：折扣基点（basis points），如1000表示10%（计算时用 `discount_value / 10000`）
    - 示例：1000 bp = 10%，9000 bp = 90%（即9折），10000 bp = 100%（即免费）
    - 计算：`discount_amount = order_amount * discount_value / 10000`
- **注意**：已移除 `type=new_user`，新用户限制通过 `eligibility_type='new_user'` 实现
- `min_amount`: 满减券的最低使用门槛（整数，最小货币单位）
- `max_discount`: 折扣券的最大优惠金额上限（整数，最小货币单位）
- `currency`: 货币类型，支持多币种
- `can_combine`: 是否可与其他优惠叠加
- `combine_limit`: 最多可叠加数量
- `apply_order`: 应用顺序（用于叠加计算，数值越小越先应用）
- `per_device_limit/per_ip_limit`: 设备/IP限用次数（反滥用）
- `valid_from/valid_until`: 优惠券有效期（带时区，过期时间）
- `vat_category`: VAT分类（用于英国VAT处理）
- `usage_conditions`: 使用条件限制（JSON格式），包含：
  - `locations`: 地点限制（数组，如 ["London", "Manchester"]）
  - `time_restrictions`: 时间限制
    - `allowed_days`: 允许使用的星期（数组，如 [1,2,3,4,5] 表示周一到周五）
    - `allowed_hours`: 允许使用的时间段（如 {"start": "09:00", "end": "18:00"}）
    - `blackout_dates`: 禁用日期（数组，如 ["2024-12-25", "2025-01-01"]）
    - `timezone`: 时区（必须指定，如 "Europe/London"），用于判断星期和时间段
  - `task_types`: 任务类型限制（数组，如 ["delivery", "cleaning"]）
  - `min_task_amount`: 任务金额下限（如果设置，任务金额必须≥此值）
  - `max_task_amount`: 任务金额上限（如果设置，任务金额必须≤此值）
  - `excluded_task_types`: 排除的任务类型（数组）

**usage_conditions JSON示例：**
```json
{
  "locations": ["London", "Manchester", "Birmingham"],
  "time_restrictions": {
    "allowed_days": [1, 2, 3, 4, 5],
    "allowed_hours": {
      "start": "09:00",
      "end": "18:00"
    },
    "blackout_dates": ["2024-12-25", "2025-01-01"],
    "timezone": "Europe/London"
  },
  "task_types": ["delivery", "cleaning", "handyman"],
  "min_task_amount": 2000,
  "max_task_amount": 50000,
  "excluded_task_types": ["urgent"]
}
```

**注意：**
- `min_task_amount` 和 `max_task_amount` 使用整数（最小货币单位），如2000 = £20.00
- `timezone` 字段必须指定，用于明确判断星期和时间段，避免跨时区歧义

### 2. 用户优惠券表 (user_coupons)

```sql
CREATE TABLE user_coupons (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    promotion_code_id BIGINT REFERENCES promotion_codes(id),  -- 使用的推广码ID（如果通过推广码领取）
    status VARCHAR(20) DEFAULT 'unused',  -- unused, used, expired
    obtained_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,  -- 获得时间（带时区）
    used_at TIMESTAMPTZ,  -- 使用时间（带时区）
    used_in_task_id BIGINT REFERENCES tasks(id),  -- 使用的任务ID（统一为BIGINT）
    device_fingerprint VARCHAR(64),  -- 设备指纹（反滥用）
    ip_address INET,  -- IP地址（反滥用）
    idempotency_key VARCHAR(64) UNIQUE,  -- 幂等键，防止重复领取/使用
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    -- 注意：通过 idempotency_key 和业务层校验 per_user_limit 防止重复领取
    -- 如果 per_user_limit=1，业务层应检查 (user_id, coupon_id) 是否已存在未使用的记录
);

CREATE INDEX idx_user_coupons_user ON user_coupons(user_id);
CREATE INDEX idx_user_coupons_status ON user_coupons(status);
CREATE INDEX idx_user_coupons_coupon ON user_coupons(coupon_id);
```

**字段说明：**
- `status`: 
  - `unused`: 未使用
  - `used`: 已使用
  - `expired`: 已过期（通过定时任务更新）
- `obtained_at`: 记录领取时间，用于判断是否重复领取
- `promotion_code_id`: 如果通过推广码领取，记录推广码ID

**并发控制优化：**
- 使用 `SELECT FOR UPDATE` 锁定行，防止并发使用
- 引入 `coupon_redemptions` 表记录实际使用，便于并发控制

### 2.1 优惠券使用记录表 (coupon_redemptions) - 两阶段使用控制

```sql
CREATE TABLE coupon_redemptions (
    id BIGSERIAL PRIMARY KEY,
    user_coupon_id BIGINT NOT NULL REFERENCES user_coupons(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    task_id BIGINT REFERENCES tasks(id),  -- 任务ID（统一为BIGINT）
    status VARCHAR(20) DEFAULT 'reserved',  -- reserved(预授权), confirmed(确认使用), cancelled(取消)
    reserved_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,  -- 预授权时间
    confirmed_at TIMESTAMPTZ,  -- 确认使用时间
    expires_at TIMESTAMPTZ,  -- 预授权过期时间（如5分钟内未确认则自动取消）
    idempotency_key VARCHAR(64) UNIQUE,  -- 幂等键
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    -- 注意：不使用表级唯一约束，因为 task_id 可能为 NULL，NULL 值在唯一约束中不相等
    -- 改用部分唯一索引，仅对 task_id IS NOT NULL 生效
);

CREATE INDEX idx_coupon_redemptions_user_coupon ON coupon_redemptions(user_coupon_id);
CREATE INDEX idx_coupon_redemptions_status ON coupon_redemptions(status);
CREATE INDEX idx_coupon_redemptions_expires ON coupon_redemptions(expires_at);

-- 并发护栏1：使用部分唯一索引确保同一张券同一时刻至多一条未确认的预留
-- PostgreSQL 14+ 支持部分唯一索引
CREATE UNIQUE INDEX idx_coupon_redemptions_reserved_unique 
    ON coupon_redemptions(user_coupon_id) 
    WHERE status = 'reserved';

-- 并发护栏2：防止同一任务重复使用同一张券（仅在 task_id 非空时约束）
CREATE UNIQUE INDEX uq_redemption_task_nonnull
    ON coupon_redemptions(user_id, coupon_id, task_id)
    WHERE task_id IS NOT NULL;
```

**两阶段使用流程：**
1. **预授权阶段**：创建 `coupon_redemptions` 记录，状态为 `reserved`，设置过期时间（如5分钟）
2. **确认使用阶段**：支付成功后，更新状态为 `confirmed`，更新 `user_coupons.status=used`
3. **自动取消**：定时任务清理过期的 `reserved` 记录

**并发控制：**
- 使用 `SELECT FOR UPDATE` 锁定 `coupon_redemptions` 行
- 使用部分唯一索引 `(user_id, coupon_id, task_id) WHERE task_id IS NOT NULL` 防止同一任务重复使用同一张券
- 使用部分唯一索引 `(user_coupon_id) WHERE status = 'reserved'` 防止同一张券同一时刻多条未确认的预留

### 3. 积分账户表 (points_accounts)

```sql
CREATE TABLE points_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    balance BIGINT DEFAULT 0,  -- 当前积分余额（整数，100积分=£1.00=100 pence）
    currency CHAR(3) DEFAULT 'GBP',  -- 货币类型（GBP, USD等），支持多币种
    total_earned BIGINT DEFAULT 0,  -- 累计获得积分（整数）
    total_spent BIGINT DEFAULT 0,  -- 累计消费积分（整数）
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_points_accounts_user ON points_accounts(user_id);
```

**字段说明：**
- `balance`: 当前可用积分余额（整数，100积分=£1.00=100 pence）
- `currency`: 货币类型（GBP, USD等），支持多币种（仅为计价货币，不代表积分=现金）
- `total_earned`: 累计获得积分（整数，用于统计）
- `total_spent`: 累计消费积分（整数，用于统计）
- **注意**：积分与现金比例为100:1（100积分=£1.00），例如：1000积分=£10.00=1000 pence

### 4. 积分交易记录表 (points_transactions)

```sql
CREATE TABLE points_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,  -- 类型：earn(获得), spend(消费), refund(退款), expire(过期)
    amount BIGINT NOT NULL,  -- 积分数量（整数，正数表示增加，负数表示减少）
    balance_after BIGINT NOT NULL,  -- 交易后余额（整数）
    currency CHAR(3) DEFAULT 'GBP',  -- 货币类型
    source VARCHAR(50),  -- 来源：task_complete_bonus(任务完成奖励，平台赠送，非任务报酬), invite_bonus(邀请奖励), checkin_bonus(签到奖励，平台赠送), coupon_refund(优惠券退款), points_refund(积分退款), platform_fee(抵扣平台费), task_boost(任务曝光度提升，平台自营服务), coupon_exchange(兑换优惠券), product_exchange(兑换自营商品), admin_adjustment(管理员调整)等
    related_id BIGINT,  -- 关联ID（如任务ID、优惠券ID等）
    related_type VARCHAR(50),  -- 关联类型：task, coupon, admin_reward等
    batch_id VARCHAR(50),  -- 批次ID（用于会计合规，追踪积分批次）
    expires_at TIMESTAMPTZ,  -- 过期时间（如果积分有有效期）
    description TEXT,  -- 交易描述
    idempotency_key VARCHAR(64) UNIQUE,  -- 幂等键，防止重复操作
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_points_amount_sign CHECK (
        (type = 'earn' AND amount > 0) OR
        (type = 'spend' AND amount < 0) OR
        (type = 'refund' AND amount > 0) OR
        (type = 'expire' AND amount < 0)
    )  -- 确保金额符号正确：earn/refund为正，spend/expire为负
);

CREATE INDEX idx_points_transactions_user ON points_transactions(user_id);
CREATE INDEX idx_points_transactions_type ON points_transactions(type);
CREATE INDEX idx_points_transactions_created ON points_transactions(created_at);
CREATE INDEX idx_points_transactions_related ON points_transactions(related_type, related_id);
```

**字段说明：**
- `type`: 
  - `earn`: 获得积分（任务完成、邀请好友等）
  - `spend`: 消费积分（抵扣申请费/平台服务费、兑换自营商品、兑换折扣券等，**不可提现、不可用于向第三方付款**）
  - `refund`: 退款（任务取消、优惠券退款等）
  - `expire`: 过期（积分过期扣除，需按批次处理）
- `amount`: 整数，正数表示增加，负数表示减少（积分数量，100积分=£1.00）
- `batch_id`: 积分批次ID，用于会计合规和过期处理
- `expires_at`: 积分过期时间（如果配置了有效期）
- `idempotency_key`: 幂等键，防止重复操作（如重复发放、重复使用等）
- `source`: 积分来源或去向的具体场景（见"积分全局规则"章节）
- **注意**：积分与现金比例为100:1，例如：amount=1000表示1000积分=£10.00
- **全局规则**：金额符号规则、消费顺序规则（FIFO）、source 枚举规则见"积分全局规则"章节

### 5. 优惠券使用记录表 (coupon_usage_logs)

```sql
CREATE TABLE coupon_usage_logs (
    id BIGSERIAL PRIMARY KEY,
    user_coupon_id BIGINT NOT NULL REFERENCES user_coupons(id) ON DELETE CASCADE,
    redemption_id BIGINT REFERENCES coupon_redemptions(id),  -- 关联的使用记录（如果使用两阶段）
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    promotion_code_id BIGINT REFERENCES promotion_codes(id),  -- 使用的推广码
    task_id BIGINT REFERENCES tasks(id),  -- 使用的任务ID（统一为BIGINT）
    discount_amount_before_tax BIGINT NOT NULL,  -- 折前优惠金额（整数，最小货币单位）
    discount_amount BIGINT NOT NULL,  -- 实际优惠金额（整数，最小货币单位，含税）
    order_amount_before_tax BIGINT NOT NULL,  -- 订单原始金额（折前，整数）
    order_amount_incl_tax BIGINT NOT NULL,  -- 订单原始金额（整数，含税）
    final_amount_before_tax BIGINT NOT NULL,  -- 优惠后金额（折前，整数）
    final_amount_incl_tax BIGINT NOT NULL,  -- 优惠后金额（整数，含税）
    vat_amount BIGINT,  -- VAT税额（整数，最小货币单位，使用银行家舍入）
    vat_rate DECIMAL(5, 2),  -- VAT税率（如20.00表示20%）
    vat_category VARCHAR(20),  -- VAT分类（用于HMRC审计）
    rounding_method VARCHAR(20) DEFAULT 'bankers',  -- 舍入方法：bankers(银行家舍入), half_up(四舍五入)
    currency CHAR(3) DEFAULT 'GBP',  -- 货币类型
    applied_coupons JSONB,  -- 应用的优惠券列表（用于叠加场景）
    refund_status VARCHAR(20) DEFAULT 'none',  -- 退款状态：none, partial, full
    refunded_at TIMESTAMPTZ,  -- 退款时间
    refund_reason TEXT,  -- 退款原因
    idempotency_key VARCHAR(64) UNIQUE,  -- 幂等键
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_coupon_usage_logs_user ON coupon_usage_logs(user_id);
CREATE INDEX idx_coupon_usage_logs_task ON coupon_usage_logs(task_id);
CREATE INDEX idx_coupon_usage_logs_coupon ON coupon_usage_logs(coupon_id);
```

**字段说明：**
- 记录每次优惠券使用的详细信息，用于审计和统计

### 6. 签到记录表 (check_ins)

```sql
CREATE TABLE check_ins (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    check_in_date DATE NOT NULL,  -- 签到日期（按Europe/London时区判断"今天"，使用DATE类型但明确时区）
    timezone VARCHAR(50) DEFAULT 'Europe/London',  -- 时区（用于明确判断"今天"）
    consecutive_days INTEGER DEFAULT 1,  -- 连续签到天数
    reward_type VARCHAR(20),  -- 奖励类型：points(积分), coupon(优惠券)
    points_reward BIGINT,  -- 积分奖励（整数，如果reward_type=points）
    coupon_id BIGINT REFERENCES coupons(id),  -- 优惠券ID（如果reward_type=coupon）
    reward_description TEXT,  -- 奖励描述
    device_fingerprint VARCHAR(64),  -- 设备指纹（反滥用）
    ip_address INET,  -- IP地址（反滥用）
    idempotency_key VARCHAR(64) UNIQUE,  -- 幂等键
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_checkin_date UNIQUE(user_id, check_in_date),  -- 每个用户每天只能签到一次
    CONSTRAINT chk_checkin_reward CHECK (
        (reward_type = 'points' AND points_reward IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_reward IS NULL)
    )  -- 确保奖励类型和值匹配
);

CREATE INDEX idx_check_ins_user ON check_ins(user_id);
CREATE INDEX idx_check_ins_date ON check_ins(check_in_date);
CREATE INDEX idx_check_ins_user_date ON check_ins(user_id, check_in_date);
```

**字段说明：**
- `check_in_date`: 签到日期，使用DATE类型，只记录日期不记录时间
- `timezone`: 时区（默认Europe/London），用于明确判断"今天"，考虑夏令时（DST）
- `consecutive_days`: 连续签到天数，用于计算连续签到奖励
- `reward_type`: 奖励类型，可以是积分或优惠券
- `points_reward`: 积分奖励（整数，如果reward_type=points）
- `coupon_id`: 优惠券ID（如果reward_type=coupon）
- **多态字段拆分**：使用 `points_reward` 和 `coupon_id` 两个字段，通过CHECK约束确保一致性，避免混淆

### 7. 签到奖励配置表 (check_in_rewards)

```sql
CREATE TABLE check_in_rewards (
    id BIGSERIAL PRIMARY KEY,
    consecutive_days INTEGER NOT NULL UNIQUE,  -- 连续签到天数
    reward_type VARCHAR(20) NOT NULL,  -- 奖励类型：points, coupon
    points_reward BIGINT,  -- 积分奖励（整数，如果reward_type=points）
    coupon_id BIGINT REFERENCES coupons(id),  -- 优惠券ID（如果reward_type=coupon）
    reward_description TEXT,  -- 奖励描述
    is_active BOOLEAN DEFAULT true,  -- 是否启用
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_checkin_reward_value CHECK (
        (reward_type = 'points' AND points_reward IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_reward IS NULL)
    )  -- 确保奖励类型和值匹配（多态字段拆分，避免混淆）
);

CREATE INDEX idx_check_in_rewards_days ON check_in_rewards(consecutive_days);
CREATE INDEX idx_check_in_rewards_active ON check_in_rewards(is_active);
```

**字段说明：**
- `consecutive_days`: 连续签到天数，唯一约束确保每个天数只有一个配置
- `reward_type`: 奖励类型，points（积分）或coupon（优惠券）
- `points_reward`: 积分奖励（整数，如果reward_type=points）
- `coupon_id`: 优惠券ID（如果reward_type=coupon）
- `is_active`: 是否启用该奖励配置

### 8. 邀请码表 (invitation_codes)

```sql
CREATE TABLE invitation_codes (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,  -- 邀请码（不区分大小写唯一，高熵随机码10-14位Base32）
    name VARCHAR(100),  -- 邀请码名称/描述
    description TEXT,  -- 详细描述
    reward_type VARCHAR(20) NOT NULL,  -- 奖励类型：points(积分), coupon(优惠券), both(两者都有)
    points_reward BIGINT DEFAULT 0,  -- 积分奖励数量（整数）
    coupon_id BIGINT REFERENCES coupons(id),  -- 优惠券奖励ID（如果reward_type包含coupon）
    currency CHAR(3) DEFAULT 'GBP',  -- 货币类型
    max_uses INTEGER,  -- 最大使用次数（NULL表示无限制，需用查询统计实际使用）
    valid_from TIMESTAMPTZ NOT NULL,  -- 有效期开始时间（带时区）
    valid_until TIMESTAMPTZ NOT NULL,  -- 有效期结束时间（带时区）
    is_active BOOLEAN DEFAULT true,  -- 是否启用
    created_by VARCHAR(8) REFERENCES admin_users(id),  -- 创建者（管理员ID）
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_invitation_code_lower UNIQUE (LOWER(code))  -- 不区分大小写唯一索引
);

-- 生成高熵随机码函数（建议使用Base32，避免易混字符如0/O, 1/I）
-- 示例：使用10-14位Base32编码，避免0/O, 1/I等易混字符

CREATE INDEX idx_invitation_codes_active ON invitation_codes(is_active);
CREATE INDEX idx_invitation_codes_valid ON invitation_codes(valid_from, valid_until);
CREATE INDEX idx_invitation_codes_created_by ON invitation_codes(created_by);

-- 邀请码使用统计视图（替代 used_count 字段，避免并发累加不准确）
CREATE VIEW invitation_code_stats AS
SELECT 
    ic.id,
    ic.code,
    ic.name,
    ic.max_uses,
    COUNT(uiu.*) FILTER (WHERE uiu.reward_received = true) AS used_count
FROM invitation_codes ic
LEFT JOIN user_invitation_usage uiu ON uiu.invitation_code_id = ic.id
GROUP BY ic.id, ic.code, ic.name, ic.max_uses;
```

**字段说明：**
- `code`: 邀请码，唯一标识，用户注册时输入
- `reward_type`: 
  - `points`: 仅积分奖励
  - `coupon`: 仅优惠券奖励
  - `both`: 积分+优惠券
- `points_reward`: 注册时获得的积分数量（积分数量，整数）
- `coupon_id`: 注册时获得的优惠券ID（如果reward_type包含coupon）
- `max_uses`: 最大使用次数限制，NULL表示无限制
- `valid_from/valid_until`: 邀请码有效期
- **注意**：`used_count` 不在表中维护，通过统计视图 `invitation_code_stats` 查询，避免并发累加不准确

### 9. 用户邀请码使用记录表 (user_invitation_usage)

```sql
CREATE TABLE user_invitation_usage (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitation_code_id BIGINT NOT NULL REFERENCES invitation_codes(id) ON DELETE CASCADE,
    used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,  -- 使用时间（注册时间，带时区）
    reward_received BOOLEAN DEFAULT false,  -- 是否已发放奖励
    points_received BIGINT,  -- 实际获得的积分（积分数量，整数）
    coupon_received_id BIGINT REFERENCES coupons(id),  -- 实际获得的优惠券ID
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, invitation_code_id)  -- 每个用户每个邀请码只能使用一次
);

CREATE INDEX idx_user_invitation_usage_user ON user_invitation_usage(user_id);
CREATE INDEX idx_user_invitation_usage_code ON user_invitation_usage(invitation_code_id);
CREATE INDEX idx_user_invitation_usage_used_at ON user_invitation_usage(used_at);
```

**字段说明：**
- `user_id`: 使用邀请码注册的用户ID
- `invitation_code_id`: 使用的邀请码ID
- `used_at`: 使用时间（即用户注册时间）
- `reward_received`: 奖励是否已成功发放
- `points_received`: 实际获得的积分（记录实际发放值，便于审计）
- `coupon_received_id`: 实际获得的优惠券ID（记录实际发放值）

**注意：** 需要在 `users` 表中添加 `invitation_code_id` 字段（如果还没有的话）：
```sql
-- 删除旧的外键字段（如果存在）
ALTER TABLE users DROP COLUMN IF EXISTS invitation_code;

-- 添加新的外键字段（引用id，不是code）
ALTER TABLE users ADD COLUMN invitation_code_id BIGINT REFERENCES invitation_codes(id);

-- 如需展示原始邀请码文本（可选）
ALTER TABLE users ADD COLUMN invitation_code_text VARCHAR(50);

CREATE INDEX idx_users_invitation_code_id ON users(invitation_code_id);
```

**说明：** 由于 `invitation_codes.code` 使用了表达式唯一索引 `UNIQUE (LOWER(code))`，不能作为外键引用。因此使用 `invitation_code_id` 引用 `invitation_codes.id`，并可选存储 `invitation_code_text` 用于展示。

### 10. 管理员发放记录表 (admin_rewards)

```sql
CREATE TABLE admin_rewards (
    id BIGSERIAL PRIMARY KEY,
    reward_type VARCHAR(20) NOT NULL,  -- 奖励类型：points(积分), coupon(优惠券)
    target_type VARCHAR(20) NOT NULL,  -- 目标类型：user(指定用户), user_type(用户类型), all(所有用户)
    target_value TEXT,  -- 目标值：用户ID列表(JSON)或用户类型(如"vip", "normal")
    points_value BIGINT,  -- 积分数量（整数，如果reward_type=points）
    coupon_id BIGINT REFERENCES coupons(id),  -- 优惠券ID（如果reward_type=coupon）
    total_users INTEGER DEFAULT 0,  -- 发放用户总数
    success_count INTEGER DEFAULT 0,  -- 成功发放数量
    failed_count INTEGER DEFAULT 0,  -- 失败数量
    status VARCHAR(20) DEFAULT 'pending',  -- 状态：pending, processing, completed, failed
    description TEXT,  -- 发放说明
    created_by VARCHAR(8) NOT NULL REFERENCES admin_users(id),  -- 操作管理员
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,  -- 完成时间（带时区）
    CONSTRAINT chk_admin_rewards_value CHECK (
        (reward_type = 'points' AND points_value IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_value IS NULL)
    )  -- 确保奖励类型和值匹配（互斥校验）
);

CREATE INDEX idx_admin_rewards_type ON admin_rewards(reward_type);
CREATE INDEX idx_admin_rewards_target ON admin_rewards(target_type);
CREATE INDEX idx_admin_rewards_status ON admin_rewards(status);
CREATE INDEX idx_admin_rewards_created_by ON admin_rewards(created_by);
CREATE INDEX idx_admin_rewards_created_at ON admin_rewards(created_at);
```

**字段说明：**
- `reward_type`: 奖励类型，points（积分）或coupon（优惠券）
- `target_type`: 
  - `user`: 指定用户（target_value存储用户ID列表，JSON格式）
  - `user_type`: 用户类型（target_value存储用户类型，如"vip", "super", "normal"）
  - `all`: 所有用户（target_value为空）
- `target_value`: 
  - 如果target_type=user：存储用户ID数组，如 ["user001", "user002"]
  - 如果target_type=user_type：存储用户类型字符串，如 "vip"
  - 如果target_type=all：为空
- `points_value`: 积分数量（整数，如果reward_type=points）
- `coupon_id`: 优惠券ID（如果reward_type=coupon）
- `status`: 发放状态，用于异步批量发放

### 11. 管理员发放详情表 (admin_reward_details)

```sql
CREATE TABLE admin_reward_details (
    id BIGSERIAL PRIMARY KEY,
    admin_reward_id BIGINT NOT NULL REFERENCES admin_rewards(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_type VARCHAR(20) NOT NULL,  -- 奖励类型：points, coupon
    points_value BIGINT,  -- 积分数量（整数，如果reward_type=points）
    coupon_id BIGINT REFERENCES coupons(id),  -- 优惠券ID（如果reward_type=coupon）
    status VARCHAR(20) DEFAULT 'pending',  -- 状态：pending, success, failed
    error_message TEXT,  -- 失败原因
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,  -- 完成时间（带时区）
    CONSTRAINT chk_admin_reward_details_value CHECK (
        (reward_type = 'points' AND points_value IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_value IS NULL)
    )  -- 确保奖励类型和值匹配（互斥校验）
);

CREATE INDEX idx_admin_reward_details_reward ON admin_reward_details(admin_reward_id);
CREATE INDEX idx_admin_reward_details_user ON admin_reward_details(user_id);
CREATE INDEX idx_admin_reward_details_status ON admin_reward_details(status);
```

**字段说明：**
- 记录每次发放操作的详细信息，用于追踪和审计
- 每个用户一条记录，便于查看发放状态

### 12. 设备指纹表 (device_fingerprints)

```sql
CREATE TABLE device_fingerprints (
    id BIGSERIAL PRIMARY KEY,
    fingerprint VARCHAR(64) UNIQUE NOT NULL,  -- 设备指纹（哈希值）
    user_id VARCHAR(8) REFERENCES users(id),  -- 关联用户（可为空，用于匿名设备）
    device_info JSONB,  -- 设备信息（浏览器、操作系统等）
    ip_address INET,  -- IP地址
    first_seen TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    risk_score INTEGER DEFAULT 0,  -- 风险评分（0-100）
    is_blocked BOOLEAN DEFAULT false  -- 是否被阻止
);

CREATE INDEX idx_device_fingerprints_fp ON device_fingerprints(fingerprint);
CREATE INDEX idx_device_fingerprints_user ON device_fingerprints(user_id);
CREATE INDEX idx_device_fingerprints_risk ON device_fingerprints(risk_score);
```

**字段说明：**
- `fingerprint`: 设备指纹（基于浏览器特征、硬件信息等生成的唯一标识）
- `risk_score`: 风险评分，用于识别可疑设备
- 用于反滥用：检测多账号、批量操作等

### 13. 风控记录表 (risk_control_logs)

```sql
CREATE TABLE risk_control_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) REFERENCES users(id),
    device_fingerprint VARCHAR(64) REFERENCES device_fingerprints(fingerprint),
    action_type VARCHAR(50) NOT NULL,  -- 操作类型：checkin, coupon_claim, points_earn等
    risk_level VARCHAR(20),  -- 风险等级：low, medium, high, critical
    risk_reason TEXT,  -- 风险原因
    action_blocked BOOLEAN DEFAULT false,  -- 是否被阻止
    metadata JSONB,  -- 额外信息（IP、频率等）
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_risk_logs_user ON risk_control_logs(user_id);
CREATE INDEX idx_risk_logs_device ON risk_control_logs(device_fingerprint);
CREATE INDEX idx_risk_logs_action ON risk_control_logs(action_type);
CREATE INDEX idx_risk_logs_risk ON risk_control_logs(risk_level);
CREATE INDEX idx_risk_logs_created ON risk_control_logs(created_at);
```

**字段说明：**
- 记录所有风控检查和结果
- 用于分析和优化风控规则

### 14. 推广码表 (promotion_codes) - Stripe风格设计

```sql
CREATE TABLE promotion_codes (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,  -- 推广码（不区分大小写唯一，高熵随机码10-14位Base32）
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,  -- 关联的优惠券
    name VARCHAR(100),  -- 推广码名称/描述
    description TEXT,  -- 详细描述
    max_uses INTEGER,  -- 最大使用次数（NULL表示无限制，需用查询统计实际使用）
    per_user_limit INTEGER DEFAULT 1,  -- 每个用户限用次数
    min_order_amount BIGINT,  -- 最低订单金额（整数，最小货币单位，NULL表示无限制）
    can_combine BOOLEAN,  -- 是否可叠加（NULL表示继承coupon的can_combine）
    valid_from TIMESTAMPTZ NOT NULL,  -- 有效期开始时间（带时区）
    valid_until TIMESTAMPTZ NOT NULL,  -- 有效期结束时间（带时区）
    is_active BOOLEAN DEFAULT true,  -- 是否启用
    target_user_type VARCHAR(20),  -- 目标用户类型（vip, super, normal, all）
    created_by VARCHAR(8) REFERENCES admin_users(id),  -- 创建者（管理员ID）
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_promotion_code_lower UNIQUE (LOWER(code)),  -- 不区分大小写唯一索引
    CONSTRAINT chk_promo_dates CHECK (valid_until > valid_from)  -- 有效期结束时间必须大于开始时间
);

CREATE INDEX idx_promotion_codes_coupon ON promotion_codes(coupon_id);
CREATE INDEX idx_promotion_codes_active ON promotion_codes(is_active);
CREATE INDEX idx_promotion_codes_valid ON promotion_codes(valid_from, valid_until);
```

**字段说明：**
- 一个优惠券（Coupon）可以关联多个推广码（Promotion Code）
- 每个推广码可以独立设置使用限制、有效期、目标用户群体
- 支持批量生成推广码（如活动期间生成1000个不同的推广码）

### 15. 审计日志表 (audit_logs)

```sql
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    action_type VARCHAR(50) NOT NULL,  -- 操作类型：coupon_create, points_adjust, admin_reward等
    entity_type VARCHAR(50),  -- 实体类型：coupon, points_account, admin_reward等
    entity_id VARCHAR(50),  -- 实体ID
    user_id VARCHAR(8) REFERENCES users(id),  -- 操作用户（可为管理员）
    admin_id VARCHAR(8) REFERENCES admin_users(id),  -- 操作管理员
    old_value JSONB,  -- 旧值（变更前）
    new_value JSONB,  -- 新值（变更后）
    reason TEXT,  -- 操作原因
    ip_address INET,  -- IP地址
    device_fingerprint VARCHAR(64),  -- 设备指纹
    error_code VARCHAR(50),  -- 错误码（如果操作失败）
    error_message TEXT,  -- 错误信息
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_action ON audit_logs(action_type);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_admin ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);
```

**字段说明：**
- 统一记录所有重要操作的审计日志
- 包含操作者、旧值/新值、原因、错误信息等
- 用于合规审计和问题排查

### 16. 优惠券资格表 (coupon_eligibility) - 可选，用于复杂资格规则

```sql
CREATE TABLE coupon_eligibility (
    id BIGSERIAL PRIMARY KEY,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    eligibility_type VARCHAR(20) NOT NULL,  -- 资格类型：first_order, new_user, user_type, member等
    eligibility_value TEXT,  -- 资格值（JSON格式，如用户类型列表）
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_coupon_eligibility_coupon ON coupon_eligibility(coupon_id);
CREATE INDEX idx_coupon_eligibility_type ON coupon_eligibility(eligibility_type);
```

**字段说明：**
- 支持一个优惠券有多个资格规则（如：新用户 + VIP用户）
- 如果资格规则简单，可以直接存储在coupons表的eligibility_type和eligibility_value字段

---

## 💰 积分系统设计

### 1. 积分获取规则

**任务完成奖励：**
- 完成任务：获得平台赠送积分（**非任务报酬**，平台另行发放的忠诚度奖励）
- 例如：完成任务后，平台按法币向服务者结算任务奖励，同时另行赠送1000积分（£10.00）作为完成奖励
- **合规说明**：该积分非任务对价、无现金价值，仅可抵平台费/兑自营/兑券

**邀请奖励：**
- 邀请新用户注册：获得平台赠送积分（固定值，如5000积分=£50.00）
- 被邀请用户完成任务：邀请者获得平台赠送积分（固定值，如500积分=£5.00，**非任务报酬**）

**签到奖励：**
- 每日签到：获得基础积分（如500积分=£5.00）
- 连续签到：根据连续天数获得额外奖励（积分或优惠券）
  - 连续3天：额外500积分（£5.00）
  - 连续7天：额外1000积分（£10.00）或优惠券
  - 连续15天：额外2000积分（£20.00）或优惠券
  - 连续30天：额外5000积分（£50.00）或优惠券
- 连续签到奖励规则可在管理员后台配置

**平台行为奖励（固定值或梯度值，非任务报酬）：**
- **合规设计**：所有积分奖励均为平台赠送的忠诚度奖励，**非任务对价、无现金价值**，仅可抵平台费/兑自营/兑券
- **完善资料/KYC**：
  - 完善个人资料：获得平台赠送积分（如500积分=£5.00）
  - 完成KYC验证：获得平台赠送积分（如1000积分=£10.00）
- **签到连击**：
  - 连续签到奖励（见签到系统设计）
- **平台培训或测验**：
  - 完成平台培训：获得平台赠送积分（如500积分=£5.00）
  - 通过安全测验：获得平台赠送积分（如300积分=£3.00）
- **活动任务（由平台发起）**：
  - 完成平台活动任务：获得平台赠送积分（固定值或梯度值，如300-1000积分）
- **邀请好友**：
  - 邀请新用户注册：获得平台赠送积分（如5000积分=£50.00）
  - 被邀请用户完成任务：邀请者获得平台赠送积分（固定值，如500积分=£5.00）

**任务完成奖励（固定值或梯度值，非任务报酬）：**
- **合规设计**：任务结算路径为"发布者→（法币）→学生"，平台只做法币结算
- **积分发放**：平台另行发放积分作为完成奖励，该积分**非任务对价、无现金价值**，仅可抵平台费/兑自营/兑券
- **发放策略**：使用固定值或梯度值，**不按任务金额计算，避免"积分=任务对价"的合规风险**
- **触发场景**（固定值示例）：
  - 首次完成任务：获得平台赠送积分（固定值：500积分=£5.00）
  - 按时完成：获得平台赠送积分（固定值：200积分=£2.00）
  - 五星好评：获得平台赠送积分（固定值：100积分=£1.00）
  - 完成 N 单里程碑：获得平台赠送积分（梯度值：10单=500积分，50单=2000积分，100单=5000积分）
  - 完成安全培训：获得平台赠送积分（固定值：500积分=£5.00）
  - 月度Top贡献者：获得平台赠送积分（梯度值：Top 10=2000积分，Top 5=5000积分）
- **记录方式**：`points_transactions` 表，`type=earn`, `source=task_complete_bonus`, `amount>0`
- **UI 标注**：所有任务完成积分奖励需标注"平台赠送积分，非任务报酬"

**其他奖励：**
- 首次发布任务：获得奖励积分（如2000积分=£20.00）

### 2. 积分使用规则

**允许的使用场景（严格限制）：**
- ✅ **抵扣申请费**：抵扣任务发布费用（平台服务费/申请费）
  - 积分与现金100:1兑换（100积分=£1.00）
  - 例如：发布任务需支付£10平台服务费，可以使用1000积分抵扣
- ✅ **兑换自营商品**：兑换平台自营商品（如会员权益、平台服务等）
- ✅ **兑换折扣券**：兑换优惠券/折扣券

**严格禁止的使用场景（合规要求）：**
- ❌ **不可提现**：积分不可兑换现金或提现（避免触发电子货币监管）
- ❌ **不可转账**：积分不可在用户间转账或转让
- ❌ **不可作为任务报酬**：积分不能作为任务奖励支付给服务者（任务报酬必须用法币结算）
- ❌ **不可用于第三方支付**：积分不能用于向第三方服务者付款，仅可抵扣平台侧收费
- ❌ **不可兑现**：积分不可兑换为现金等价物
- ❌ **禁止发布者直接向学生转账积分**：发布者不能把积分直接打给学生，这等同于第三方接受积分作为支付手段

**合规说明：**
- **任务完成奖励设计**：
  - 任务结算路径：发布者→（法币）→学生，平台只做法币结算
  - 平台另行发放积分作为完成奖励，该积分**非任务对价、无现金价值**，仅可抵平台费/兑自营/兑券
  - 积分必须是平台赠送的忠诚度奖励，而不是任务的支付货币
  - UI 需明确标注"平台赠送积分，非任务报酬"
- **任务曝光度提升（Boost）**：
  - 发布者可用积分购买 Boost/置顶等平台服务（属于"平台自营服务"）
  - 记录为 `type=spend`, `source=task_boost`，金额为负
  - 这笔积分不会直接流向学生，因此不构成"向第三方支付"
- **通用规则**：
  - 积分仅用于抵扣平台侧收费（申请费/服务费）和兑换平台自营商品/折扣券
  - 积分不能作为用户间价值转移的工具（不能转账、不能作为奖励支付给其他用户）
  - 平台先收单（用户使用积分+现金支付平台服务费），然后按法币向服务者结算任务奖励
  - 确保积分不直接作为对第三方的酬劳，避免触发电子货币监管

### 3. 积分全局规则

**金额符号规则：**
- 所有积分交易必须符合以下符号规则（通过数据库 CHECK 约束强制执行）：
  - `earn`（获得）：`amount > 0`（正数）
  - `spend`（消费）：`amount < 0`（负数）
  - `refund`（退款）：`amount > 0`（正数）
  - `expire`（过期）：`amount < 0`（负数）

**消费顺序规则（FIFO）：**
- 积分消费时按最早到期（FIFO - First In First Out）顺序扣减
- 优先扣减即将过期的积分批次（`expires_at` 最早）
- 便于会计侧处理 breakage（弃用率）和有效期管理
- 实现方式：查询时按 `expires_at ASC, batch_id ASC` 排序

**积分来源/去向枚举（source 字段）：**
- `task_complete_bonus`: 任务完成奖励（平台赠送，非任务报酬）
- `invite_bonus`: 邀请奖励
- `checkin_bonus`: 签到奖励（平台赠送）
- `coupon_refund`: 优惠券退款
- `points_refund`: 积分退款（订单退款时积分返还）
- `platform_fee`: 抵扣平台费（申请费/服务费）
- `task_boost`: 任务曝光度提升（Boost/置顶等平台自营服务）
- `coupon_exchange`: 兑换优惠券
- `product_exchange`: 兑换自营商品
- `admin_adjustment`: 管理员调整
- **注意**：
  - 不再使用 `task_payment`，统一使用 `platform_fee` 表示抵扣平台侧收费
  - `task_boost` 用于发布者购买平台自营服务（如任务曝光度提升），属于平台侧收费，不构成向第三方支付

**API 统一规则：**
- 所有积分相关 API 必须遵循上述金额符号规则和消费顺序规则
- 所有积分消费操作必须明确 `source` 字段，不得使用已废弃的枚举值
- 所有积分消费必须明确说明"仅用于抵扣申请费/平台服务费，不可向第三方付款"

**有效期管理：**
- 默认永久有效（符合会计要求）
- 可选：滚动有效期（近3个月有赚分则续期，减少会计负债累积）
- 可选：固定有效期（如12个月，需符合会计要求）

### 4. 积分过期规则（可选）

- 积分有效期：如12个月
- 过期提醒：到期前30天、7天提醒
- 自动扣除：过期积分自动从账户扣除

---

## 🎫 优惠券系统设计

### 1. 优惠券类型

**满减券 (fixed_amount)：**
- 示例：满£10减£2
- 使用条件：订单金额≥min_amount
- 优惠金额：discount_value

**折扣券 (percentage)：**
- 示例：9折券（discount_value=9000 bp，表示90%，即9折）
- 使用条件：订单金额≥min_amount（可选）
- 优惠金额：订单金额 × (discount_value/10000)，不超过max_discount
- **注意**：折扣使用基点（basis points），1000 bp = 10%，9000 bp = 90%（即9折）

### 2. 优惠券发放规则

**自动发放：**
- 新用户注册：自动发放新用户专享券
- 完成任务：随机发放优惠券（可选）

**手动发放：**
- 管理员后台发放
- 活动期间批量发放

**用户领取：**
- 优惠券中心展示可用优惠券
- 用户主动领取
- 检查领取限制（per_user_limit）

### 3. 优惠券使用流程（支持叠加）

1. **选择优惠券**：用户在支付任务申请费时选择可用优惠券（可多选，如果允许叠加）
2. **验证优惠券**：
   - 检查优惠券是否有效（状态、有效期）
   - 检查过期时间：当前时间必须在 valid_from 和 valid_until 之间（使用TIMESTAMPTZ）
   - 检查使用条件（订单金额、用户类型等）
   - 检查使用条件限制：
     * **地点限制**：任务地点必须在允许的地点列表中
     * **时间限制**：
       - 当前日期必须在允许的星期范围内
       - 当前时间必须在允许的时间段内（考虑时区）
       - 当前日期不能在禁用日期列表中
     * **任务类型限制**：任务类型必须在允许的类型列表中，且不在排除列表中
     * **金额限制**：任务金额必须在 min_task_amount 和 max_task_amount 范围内
   - 检查用户是否已使用（per_user_limit）
   - 检查设备/IP限制（per_device_limit, per_ip_limit）
3. **优惠叠加计算**：
   - 如果选择了多个优惠券，检查是否允许叠加（can_combine）
   - 按 apply_order 排序优惠券
   - 按顺序应用优惠券，计算最终优惠金额
   - 确保不超过 combine_limit 限制
4. **计算优惠金额**：根据优惠券类型和叠加规则计算实际优惠
5. **应用优惠**：从订单金额中扣除优惠金额（使用整数计算）
6. **记录使用**：更新user_coupons状态，记录使用日志（包含叠加信息）

**验证失败处理：**
- 如果优惠券已过期：返回 "优惠券已过期，过期时间：{valid_until}"
- 如果优惠券未生效：返回 "优惠券尚未生效，生效时间：{valid_from}"
- 如果地点不符合：返回 "该优惠券仅限在 {locations} 使用"
- 如果时间不符合：返回 "该优惠券仅在 {time_restrictions} 可使用"
- 如果任务类型不符合：返回 "该优惠券不适用于此任务类型"
- 如果金额不符合：返回 "任务金额不符合优惠券使用条件"

---

## 🔌 API 设计

### 1. 积分相关API

#### 1.1 获取积分账户信息
```
GET /api/points/account
Response: {
    "balance": 15000,  // 整数，积分数量（15000积分 = £150.00）
    "balance_display": "150.00",  // 前端显示格式（£150.00）
    "currency": "GBP",
    "total_earned": 50000,  // 累计获得50000积分
    "total_spent": 35000,   // 累计消费35000积分
    "usage_restrictions": {
        "allowed": [
            "抵扣申请费（任务发布费）",
            "兑换自营商品",
            "兑换折扣券"
        ],
        "forbidden": [
            "转账",
            "提现",
            "作为用户奖励支付给服务者"
        ]
    }
}
```

**积分使用说明：**
- ✅ **允许**：抵扣申请费（任务发布费）、兑换自营商品、兑换折扣券
- ❌ **禁止**：转账、提现、作为用户奖励支付给服务者或其他用户

#### 1.2 积分兑换优惠券
```
POST /api/points/redeem/coupon
Request: {
    "coupon_id": 1,  // 优惠券模板ID（从优惠券列表中选择）
    "idempotency_key": "unique-key-123"  // 幂等键，防止重复兑换
}
Response: {
    "success": true,
    "user_coupon_id": 456,  // 用户获得的优惠券ID
    "coupon": {
        "id": 1,
        "name": "新用户专享券",
        "discount_value": 200,  // 整数，最小货币单位（200 pence = £2.00）
        "discount_value_display": "2.00",  // 前端显示格式（£2.00）
        "valid_until": "2024-12-31T23:59:59Z"
    },
    "points_used": 200,  // 整数，最小货币单位（200积分 = £2.00）
    "points_used_display": "2.00",  // 前端显示格式（£2.00）
    "balance_after": 14800,  // 整数，最小货币单位（14800积分 = £148.00）
    "balance_after_display": "148.00",  // 前端显示格式（£148.00）
    "transaction_id": 789,  // 积分交易记录ID
    "message": "兑换成功"
}
```

**兑换说明：**
- 兑换比例：100积分 = £1.00（即兑换£2.00的优惠券需要200积分）
- 使用idempotency_key防止重复兑换
- 兑换成功后创建积分交易记录（type=spend, source=coupon_exchange）
- 兑换的优惠券有效期和规则与原优惠券模板一致

#### 1.3 积分兑换自营商品
```
POST /api/points/redeem/product
Request: {
    "product_sku": "VIP_MONTHLY",  // 自营商品SKU（如会员权益、平台服务等）
    "idempotency_key": "unique-key-456"  // 幂等键，防止重复兑换
}
Response: {
    "success": true,
    "order_id": "order_123",  // 兑换订单ID
    "product": {
        "sku": "VIP_MONTHLY",
        "name": "VIP月度会员",
        "points_cost": 10000,  // 整数，最小货币单位（10000积分 = £100.00）
        "points_cost_display": "100.00",  // 前端显示格式（£100.00）
        "valid_until": "2024-02-15T23:59:59Z"  // 会员有效期
    },
    "points_used": 10000,  // 整数，最小货币单位（10000积分 = £100.00）
    "points_used_display": "100.00",  // 前端显示格式（£100.00）
    "balance_after": 5000,  // 整数，最小货币单位（5000积分 = £50.00）
    "balance_after_display": "50.00",  // 前端显示格式（£50.00）
    "transaction_id": 790,  // 积分交易记录ID
    "message": "兑换成功"
}
```

**兑换说明：**
- 仅限平台自营商品（会员权益、平台服务等），不涉及第三方商品
- 使用idempotency_key防止重复兑换
- 兑换成功后创建积分交易记录（type=spend, source=product_exchange）
- 兑换的商品/服务立即生效

#### 1.4 获取积分交易记录
```
GET /api/points/transactions?page=1&limit=20
Response: {
    "total": 50,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": 1,
            "type": "earn",
            "amount": 1000,  // 整数，积分数量（1000积分 = £10.00）
            "amount_display": "10.00",  // 前端显示格式（£10.00）
            "balance_after": 15000,  // 积分余额（15000积分 = £150.00）
            "balance_after_display": "150.00",
            "currency": "GBP",
            "source": "task_complete_bonus",
            "description": "完成任务 #123 获得积分（平台赠送，非任务报酬）",
            "batch_id": "batch_20240115_001",  // 批次ID（用于会计合规）
            "created_at": "2024-01-15T10:30:00Z"
        }
    ]
}
```

**注意：** 积分不可提现，仅限平台内使用（合规要求）

### 2. 优惠券相关API

#### 2.1 获取可用优惠券列表
```
GET /api/coupons/available
Response: {
    "data": [
        {
            "id": 1,
            "code": "NEWUSER10",
            "name": "新用户专享券",
            "type": "fixed_amount",
            "discount_value": 200,  // 整数，最小货币单位（200 pence = £2.00）
            "discount_value_display": "2.00",  // 前端显示格式（£2.00）
            "min_amount": 1000,  // 整数，最小货币单位（1000 pence = £10.00）
            "min_amount_display": "10.00",  // 前端显示格式（£10.00）
            "currency": "GBP",
            "valid_until": "2024-12-31T23:59:59Z"
        }
    ]
}
```

#### 2.2 领取优惠券（支持推广码）
```
POST /api/coupons/claim
Request: {
    "coupon_id": 1,  // 直接领取优惠券
    "promotion_code": "SPRING2024",  // 或使用推广码（二选一）
    "idempotency_key": "unique-key-123"  // 幂等键，防止重复领取
}
Response: {
    "user_coupon_id": 123,
    "coupon_id": 1,
    "promotion_code_id": 5,  // 如果通过推广码领取
    "message": "优惠券领取成功"
}
```

**领取说明：**
- 支持直接领取优惠券或使用推广码领取
- 验证用户资格（首单、新用户、用户类型等）
- 检查领取限制（per_user_limit, per_device_limit, per_ip_limit, per_day_limit）
- 使用 `SELECT FOR UPDATE` 锁定优惠券行，检查全局余量
- **全局余量统计**：
  - 如果 `total_quantity` 控制**发放量**：`SELECT COUNT(*) FROM user_coupons WHERE coupon_id = ? AND status IN ('unused', 'used', 'expired')`（统计已发放的优惠券，排除未发放状态）
  - 如果 `total_quantity` 控制**使用量**：`SELECT COUNT(*) FROM user_coupons WHERE coupon_id = ? AND status = 'used'`
  - 建议统一为**发放量控制**，使用查询统计避免手动累加造成漂移
  - **注意**：`user_coupons.status` 没有 `cancelled` 状态，取消操作在 `coupon_redemptions.status` 中（reserved/confirmed/cancelled）
- 使用idempotency_key防止重复领取
- 如果 `per_user_limit=1`，业务层检查 `(user_id, coupon_id)` 是否已存在未使用的记录

#### 2.3 获取用户优惠券列表
```
GET /api/coupons/my?status=unused
Response: {
    "data": [
        {
            "id": 123,
            "coupon": {
                "id": 1,
                "code": "NEWUSER10",
                "name": "新用户专享券",
                "type": "fixed_amount",
                "discount_value": 200,  // 整数，最小货币单位（200 pence = £2.00）
                "discount_value_display": "2.00",  // 前端显示格式（£2.00）
                "min_amount": 1000,  // 整数，最小货币单位（1000 pence = £10.00）
                "min_amount_display": "10.00"  // 前端显示格式（£10.00）
            },
            "status": "unused",
            "obtained_at": "2024-01-15T10:00:00Z",
            "valid_until": "2024-12-31T23:59:59Z"
        }
    ]
}
```

#### 2.4 验证优惠券（支付前）
```
POST /api/coupons/validate
Request: {
    "coupon_code": "NEWUSER10",
    "order_amount": 1500,  // 整数，最小货币单位（1500 pence = £15.00）
    "task_location": "London",  // 任务地点
    "task_type": "delivery",  // 任务类型
    "task_date": "2024-01-15T14:30:00Z"  // 任务日期时间（用于时间限制验证）
}
Response: {
    "valid": true,
    "discount_amount": 200,  // 整数，最小货币单位（200 pence = £2.00）
    "discount_amount_display": "2.00",  // 前端显示格式（£2.00）
    "final_amount": 1300,  // 整数，最小货币单位（1300 pence = £13.00）
    "final_amount_display": "13.00",  // 前端显示格式（£13.00）
    "currency": "GBP",
    "coupon_id": 1,
    "usage_conditions": {
        "locations": ["London", "Manchester"],
        "time_restrictions": {
            "allowed_days": [1, 2, 3, 4, 5],
            "allowed_hours": {"start": "09:00", "end": "18:00"},
            "timezone": "Europe/London"
        },
        "task_types": ["delivery", "cleaning"]
    }
}
```

**验证说明：**
- 验证优惠券的有效期（valid_from 和 valid_until，使用TIMESTAMPTZ）
- 验证用户资格：
  - 首单限制：检查用户是否首次下单
  - 新用户限制：检查用户注册时间
  - 用户类型限制：检查用户类型是否符合要求
- 验证使用条件限制：
  - 地点限制：检查任务地点是否在允许列表中
  - 时间限制：检查当前时间是否符合允许的星期和时间段（考虑时区）
  - 任务类型限制：检查任务类型是否符合要求
  - 金额限制：检查任务金额是否在允许范围内
- 验证使用次数限制：
  - 每用户限次：检查用户是否已使用
  - 每设备限次：检查设备是否已使用
  - 每IP限次：检查IP是否已使用
  - 每日限次：检查今日是否已使用
- 如果验证失败，返回可机器解析的错误码（如 `COUPON_EXPIRED`, `COUPON_NOT_ELIGIBLE`, `COUPON_LIMIT_EXCEEDED`等）

#### 2.5 使用优惠券（支付时，支持两阶段或合并）

**方式一：合并验证和使用（推荐，简单场景）**
```
POST /api/coupons/use
Request: {
    "user_coupon_id": 123,
    "task_id": 456,
    "order_amount": 1500,  // 整数，最小货币单位（1500 pence = £15.00）
    "task_location": "London",
    "task_type": "delivery",
    "task_date": "2024-01-15T14:30:00Z",
    "idempotency_key": "unique-key-123"  // 幂等键，防止重复使用
}
Response: {
    "discount_amount": 200,  // 整数，最小货币单位（200 pence = £2.00）
    "discount_amount_display": "2.00",  // 前端显示格式（£2.00）
    "final_amount": 1300,  // 整数，最小货币单位（1300 pence = £13.00）
    "final_amount_display": "13.00",  // 前端显示格式（£13.00）
    "currency": "GBP",
    "usage_log_id": 789,
    "message": "优惠券使用成功"
}
```

**方式二：两阶段使用（复杂场景，支持预授权）**
```
# 阶段1：预授权（创建reservation）
POST /api/coupons/reserve
Request: {
    "user_coupon_id": 123,
    "task_id": 456,
    "order_amount": 1500,
    "reservation_duration": 300  // 预授权有效期（秒，默认5分钟）
}
Response: {
    "redemption_id": 789,
    "reserved_at": "2024-01-15T14:30:00Z",
    "expires_at": "2024-01-15T14:35:00Z",
    "status": "reserved"
}

# 阶段2：确认使用（支付成功后）
POST /api/coupons/confirm
Request: {
    "redemption_id": 789,
    "idempotency_key": "unique-key-123"
}
Response: {
    "discount_amount": 200,
    "final_amount": 1300,
    "usage_log_id": 790,
    "status": "confirmed"
}
```

**使用说明：**
- 使用前会再次验证所有使用条件限制（双重验证）
- 使用 `SELECT FOR UPDATE` 锁定 `user_coupons` 行，防止并发使用
- 如果验证失败，返回可机器解析的错误码，不扣除优惠券
- 验证通过后，更新user_coupons状态为used，记录使用日志
- 支持幂等性：使用idempotency_key防止重复使用

### 3. 签到相关API

#### 3.1 每日签到
```
POST /api/checkin
Response: {
    "success": true,
    "check_in_date": "2024-01-15",
    "consecutive_days": 5,
    "reward": {
        "type": "points",
        "points_reward": 10,  // 整数，最小货币单位（10积分 = £0.10）
        "points_reward_display": "0.10",  // 前端显示格式（£0.10）
        "description": "连续签到5天，获得10积分"
    },
    "message": "签到成功！连续签到5天"
}
```

#### 3.2 获取签到状态
```
GET /api/checkin/status
Response: {
    "today_checked": true,  // 今天是否已签到
    "consecutive_days": 5,  // 当前连续签到天数
    "last_check_in_date": "2024-01-15",  // 最后签到日期
    "next_check_in_date": "2024-01-16",  // 下次可签到日期
    "check_in_history": [  // 最近7天签到记录
        {
            "date": "2024-01-15",
            "checked": true,
            "reward": "10积分"
        }
    ]
}
```

#### 3.3 获取签到奖励配置（用户端）
```
GET /api/checkin/rewards
Response: {
    "rewards": [
        {
            "consecutive_days": 3,
            "reward_type": "points",
            "points_reward": 500,  // 整数，最小货币单位（500积分 = £5.00）
            "points_reward_display": "5.00",  // 前端显示格式（£5.00）
            "description": "连续签到3天，额外获得500积分（£5.00）"
        },
        {
            "consecutive_days": 7,
            "reward_type": "coupon",
            "coupon_id": 1,  // 优惠券ID
            "description": "连续签到7天，获得优惠券"
        }
    ]
}
```

### 3.4 验证邀请码（注册前）
```
POST /api/invitation-codes/validate
Request: {
    "code": "WELCOME2024"
}
Response: {
    "valid": true,
    "code": "WELCOME2024",
    "name": "2024欢迎码",
    "reward_type": "both",
    "points_reward": 5000,  // 整数，最小货币单位（5000积分 = £50.00）
    "points_reward_display": "50.00",  // 前端显示格式（£50.00）
    "coupon": {
        "id": 1,
        "name": "新用户专享券"
    },
    "message": "邀请码有效，注册后可获得50积分和新用户专享券"
}
```

### 4. 管理员配置API

#### 4.1 获取系统配置
```
GET /api/admin/settings/points
Response: {
    "points_exchange_rate": 100.0,  // 100积分=100 pence=£1.00（数值型）
    "points_task_complete_bonus": 500,  // 任务完成奖励积分（固定值，整数，如500积分=£5.00，平台赠送，非任务报酬）
    "points_invite_reward": 5000,  // 邀请新用户奖励积分（固定值，整数，如5000积分=£50.00，平台赠送）
    "points_invite_task_bonus": 500,  // 被邀请用户完成任务，邀请者获得积分奖励（固定值，整数，如500积分=£5.00，平台赠送，非任务报酬）
    "points_expire_days": 0  // 积分有效期（0表示永不过期，整数）
}
```

#### 4.2 更新系统配置
```
PUT /api/admin/settings/points
Request: {
    "points_exchange_rate": 100.0,  // 100积分=100 pence=£1.00（数值型）
    "points_task_complete_bonus": 500,  // 任务完成奖励积分（固定值，整数，如500积分=£5.00，平台赠送，非任务报酬）
    "points_invite_reward": 5000,  // 邀请新用户奖励积分（固定值，整数，如5000积分=£50.00，平台赠送）
    "points_invite_task_bonus": 500,  // 被邀请用户完成任务，邀请者获得积分奖励（固定值，整数，如500积分=£5.00，平台赠送，非任务报酬）
    "points_expire_days": 0  // 积分有效期（0表示永不过期，整数）
}
Response: {
    "success": true,
    "message": "配置更新成功"
}
```

**配置说明：**
- 所有积分相关配置都可以通过此接口修改
- 配置修改后立即生效，无需重启服务
- 修改记录会保存到系统设置表，便于追踪

#### 4.3 获取签到配置
```
GET /api/admin/checkin/settings
Response: {
    "daily_base_points": 500,  // 整数，最小货币单位（500积分 = £5.00）
    "daily_base_points_display": "5.00",  // 前端显示格式（£5.00）
    "max_consecutive_days": 30,  // 最大连续签到天数（超过后重置）
    "rewards": [
        {
            "id": 1,
            "consecutive_days": 3,
            "reward_type": "points",
            "points_reward": 500,  // 整数，最小货币单位（500积分 = £5.00）
            "points_reward_display": "5.00",  // 前端显示格式（£5.00）
            "is_active": true
        }
    ]
}
```

#### 4.4 更新签到配置
```
PUT /api/admin/checkin/settings
Request: {
    "daily_base_points": 500,  // 整数，最小货币单位（500积分 = £5.00）
    "max_consecutive_days": 30
}
Response: {
    "success": true
}
```

#### 4.5 管理签到奖励规则

**4.5.1 获取签到奖励规则列表**
```
GET /api/admin/checkin/rewards?is_active=true&page=1&limit=20
Response: {
    "total": 5,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": 1,
            "consecutive_days": 3,
            "reward_type": "points",
            "points_reward": 500,  // 整数，最小货币单位（500积分 = £5.00）
            "points_reward_display": "5.00",  // 前端显示格式（£5.00）
            "coupon_id": null,
            "coupon": null,
            "reward_description": "连续签到3天，额外获得500积分（£5.00）",
            "is_active": true,
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        },
        {
            "id": 2,
            "consecutive_days": 7,
            "reward_type": "coupon",
            "points_reward": null,
            "coupon_id": 1,
            "coupon": {
                "id": 1,
                "name": "连续签到7天奖励券",
                "discount_value": 1000,  // 整数，最小货币单位（1000 pence = £10.00）
                "discount_value_display": "10.00"  // 前端显示格式（£10.00）
            },
            "reward_description": "连续签到7天，获得优惠券",
            "is_active": true,
            "created_at": "2024-01-01T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
    ]
}
```

**4.5.2 创建签到奖励规则**
```
POST /api/admin/checkin/rewards
Request: {
    "consecutive_days": 15,  // 连续签到天数（必须唯一）
    "reward_type": "points",  // points 或 coupon
    "points_reward": 2000,  // 整数，最小货币单位（2000积分 = £20.00），如果reward_type=points
    "coupon_id": null,  // 优惠券ID，如果reward_type=coupon
    "reward_description": "连续签到15天，额外获得2000积分（£20.00）",
    "is_active": true
}
Response: {
    "success": true,
    "id": 3,
    "message": "签到奖励规则创建成功"
}
```

**4.5.3 更新签到奖励规则**
```
PUT /api/admin/checkin/rewards/{id}
Request: {
    "consecutive_days": 15,  // 可以修改连续签到天数（如果修改，需确保唯一性）
    "reward_type": "coupon",  // 可以修改奖励类型
    "points_reward": null,  // 如果改为coupon，设为null
    "coupon_id": 2,  // 如果改为coupon，设置优惠券ID
    "reward_description": "连续签到15天，获得优惠券",
    "is_active": true  // 可以启用/禁用
}
Response: {
    "success": true,
    "message": "签到奖励规则更新成功"
}
```

**4.5.4 删除签到奖励规则**
```
DELETE /api/admin/checkin/rewards/{id}
Response: {
    "success": true,
    "message": "签到奖励规则删除成功"
}
```

**4.5.5 启用/禁用签到奖励规则**
```
PUT /api/admin/checkin/rewards/{id}/toggle
Request: {
    "is_active": false  // true启用，false禁用
}
Response: {
    "success": true,
    "is_active": false,
    "message": "签到奖励规则已禁用"
}
```

**操作说明：**
- `consecutive_days` 必须唯一，不能有重复的连续天数配置
- 修改 `reward_type` 时，需要同时更新对应的 `points_reward` 或 `coupon_id` 字段
- 禁用规则后，该连续天数将不再发放奖励，但历史记录保留
- 删除规则前建议先禁用，确认无影响后再删除

#### 4.6 管理优惠券配置
```
GET /api/admin/coupons/settings
PUT /api/admin/coupons/settings
Request: {
    "coupon_new_user_auto_issue": true,  // 布尔类型（不是字符串）
    "coupon_new_user_type": "fixed_amount",
    "coupon_new_user_value": 200,  // 整数，最小货币单位（200 pence = £2.00）
    "coupon_new_user_min_amount": 1000  // 整数，最小货币单位（1000 pence = £10.00）
}
```

#### 4.7 创建优惠券（管理员）
```
POST /api/admin/coupons
Request: {
    "code": "SPRING2024",
    "name": "春季优惠券",
    "description": "春季活动专享",
    "type": "fixed_amount",
    "discount_value": 500,  // 整数，最小货币单位（500 pence = £5.00）
    "discount_value_display": "5.00",  // 前端显示格式（£5.00）
    "min_amount": 2000,  // 整数，最小货币单位（2000 pence = £20.00）
    "min_amount_display": "20.00",  // 前端显示格式（£20.00）
    "max_discount": null,
    "total_quantity": 1000,
    "per_user_limit": 1,
    "valid_from": "2024-03-01T00:00:00Z",
    "valid_until": "2024-05-31T23:59:59Z",
    "usage_conditions": {
        "locations": ["London", "Manchester", "Birmingham"],
        "time_restrictions": {
            "allowed_days": [1, 2, 3, 4, 5],
            "allowed_hours": {
                "start": "09:00",
                "end": "18:00"
            },
            "blackout_dates": ["2024-04-01"],
            "timezone": "Europe/London"
        },
        "task_types": ["delivery", "cleaning"],
        "min_task_amount": 2000,  // 整数，最小货币单位（2000 pence = £20.00）
        "max_task_amount": 50000  // 整数，最小货币单位（50000 pence = £500.00）
        "excluded_task_types": ["urgent"]
    }
}
Response: {
    "id": 10,
    "code": "SPRING2024",
    "message": "优惠券创建成功"
}
```

#### 4.8 更新优惠券（管理员）
```
PUT /api/admin/coupons/{id}
Request: {
    "name": "春季优惠券（更新）",
    "valid_until": "2024-06-30T23:59:59Z",  // 可以修改过期时间
    "usage_conditions": {
        "locations": ["London", "Manchester", "Birmingham", "Leeds"],
        "time_restrictions": {
            "allowed_days": [1, 2, 3, 4, 5, 6],
            "allowed_hours": {
                "start": "08:00",
                "end": "20:00"
            },
            "timezone": "Europe/London"
        }
    }
}
Response: {
    "success": true,
    "message": "优惠券更新成功"
}
```

#### 4.9 获取优惠券列表（管理员）
```
GET /api/admin/coupons?page=1&limit=20&status=active
Response: {
    "total": 50,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": 10,
            "code": "SPRING2024",
            "name": "春季优惠券",
            "type": "fixed_amount",
            "discount_value": 500,  // 整数，最小货币单位（500 pence = £5.00）
            "discount_value_display": "5.00",  // 前端显示格式（£5.00）
            "min_amount": 2000,  // 整数，最小货币单位（2000 pence = £20.00）
            "min_amount_display": "20.00",  // 前端显示格式（£20.00）
            "valid_from": "2024-03-01T00:00:00Z",
            "valid_until": "2024-05-31T23:59:59Z",
            "status": "active",
            "usage_conditions": {
                "locations": ["London", "Manchester"],
                "task_types": ["delivery", "cleaning"]
            },
            "total_quantity": 1000,
            "used_quantity": 250
        }
    ]
}
```

#### 4.10 获取优惠券详情（管理员）
```
GET /api/admin/coupons/{id}
Response: {
    "id": 10,
    "code": "SPRING2024",
    "name": "春季优惠券",
    "description": "春季活动专享",
    "type": "fixed_amount",
    "discount_value": 500,  // 整数，最小货币单位（500 pence = £5.00）
    "discount_value_display": "5.00",  // 前端显示格式（£5.00）
    "min_amount": 2000,  // 整数，最小货币单位（2000 pence = £20.00）
    "min_amount_display": "20.00",  // 前端显示格式（£20.00）
    "valid_from": "2024-03-01T00:00:00Z",
    "valid_until": "2024-05-31T23:59:59Z",
    "status": "active",
    "usage_conditions": {
        "locations": ["London", "Manchester", "Birmingham"],
        "time_restrictions": {
            "allowed_days": [1, 2, 3, 4, 5],
            "allowed_hours": {"start": "09:00", "end": "18:00"},
            "blackout_dates": ["2024-04-01"],
            "timezone": "Europe/London"
        },
        "task_types": ["delivery", "cleaning"],
        "min_task_amount": 2000,  // 整数，最小货币单位（2000 pence = £20.00）
        "max_task_amount": 50000  // 整数，最小货币单位（50000 pence = £500.00）
    },
    "statistics": {
        "total_issued": 500,
        "total_used": 250,
        "total_discount_given": 125000,  // 整数，最小货币单位（125000 pence = £1250.00）
        "total_discount_given_display": "1250.00"  // 前端显示格式（£1250.00）
    }
}
```

#### 4.11 删除优惠券（管理员）
```
DELETE /api/admin/coupons/{id}
Request: {
    "force": false  // 是否强制删除（即使有使用记录）
}
Response: {
    "success": true,
    "message": "优惠券删除成功"
}
```

**删除说明：**
- 如果优惠券已有使用记录，建议软删除（设置status为inactive或设置过期时间）
- 如果从未使用，可以硬删除
- 强制删除会删除所有相关记录（不推荐）

### 5. 邀请码管理API（管理员）

#### 5.1 创建邀请码
```
POST /api/admin/invitation-codes
Request: {
    "code": "WELCOME2024",
    "name": "2024欢迎码",
    "description": "新用户注册专享",
    "reward_type": "both",  // points, coupon, both
    "points_reward": 5000,  // 整数，最小货币单位（5000积分 = £50.00）
    "points_reward_display": "50.00",  // 前端显示格式（£50.00）
    "coupon_id": 1,  // 如果reward_type包含coupon
    "max_uses": 100,  // NULL表示无限制
    "valid_from": "2024-01-01T00:00:00Z",
    "valid_until": "2024-12-31T23:59:59Z",
    "is_active": true
}
Response: {
    "id": 1,
    "code": "WELCOME2024",
    "message": "邀请码创建成功"
}
```

#### 5.2 获取邀请码列表
```
GET /api/admin/invitation-codes?page=1&limit=20&status=active
Response: {
    "total": 50,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": 1,
            "code": "WELCOME2024",
            "name": "2024欢迎码",
            "reward_type": "both",
            "points_reward": 5000,  // 整数，最小货币单位（5000积分 = £50.00）
    "points_reward_display": "50.00",  // 前端显示格式（£50.00）
            "coupon_id": 1,
            "max_uses": 100,
            "used_count": 25,  // 从 invitation_code_stats 视图查询
            "valid_from": "2024-01-01T00:00:00Z",
            "valid_until": "2024-12-31T23:59:59Z",
            "is_active": true,
            "created_by": "admin001",
            "created_at": "2024-01-01T10:00:00Z"
        }
    ]
}
```

#### 5.3 获取邀请码详情
```
GET /api/admin/invitation-codes/{id}
Response: {
    "id": 1,
    "code": "WELCOME2024",
    "name": "2024欢迎码",
    "description": "新用户注册专享",
    "reward_type": "both",
    "points_reward": 5000,  // 整数，最小货币单位（5000积分 = £50.00）
    "points_reward_display": "50.00",  // 前端显示格式（£50.00）
    "coupon": {
        "id": 1,
        "name": "新用户专享券",
        "type": "fixed_amount",
        "discount_value": 200,  // 整数，最小货币单位（200 pence = £2.00）
        "discount_value_display": "2.00"  // 前端显示格式（£2.00）
    },
    "max_uses": 100,
    "used_count": 25,
    "remaining_uses": 75,
    "valid_from": "2024-01-01T00:00:00Z",
    "valid_until": "2024-12-31T23:59:59Z",
    "is_active": true,
    "created_by": "admin001",
    "created_at": "2024-01-01T10:00:00Z",
    "statistics": {
        "total_users": 25,
        "total_points_given": 125000,  // 整数，最小货币单位（125000积分 = £1250.00）
        "total_points_given_display": "1250.00",  // 前端显示格式（£1250.00）
        "total_coupons_given": 25
    }
}
```

#### 5.4 更新邀请码
```
PUT /api/admin/invitation-codes/{id}
Request: {
    "name": "2024欢迎码（更新）",
    "description": "更新后的描述",
    "is_active": false,  // 可以禁用邀请码
    "max_uses": 200,
    "valid_from": "2024-01-01T00:00:00Z",  // 可以修改有效期开始时间
    "valid_until": "2025-12-31T23:59:59Z",  // 可以修改有效期结束时间（设置过期时间）
    "points_reward": 100,  // 整数，最小货币单位（可以修改积分奖励）
    "coupon_id": 2  // 可以修改优惠券奖励
}
Response: {
    "success": true,
    "message": "邀请码更新成功",
    "data": {
        "id": 1,
        "code": "WELCOME2024",
        "valid_until": "2025-12-31T23:59:59Z"
    }
}
```

**更新说明：**
- 可以修改邀请码的所有属性，包括过期时间
- 修改过期时间后，如果当前时间已超过新的过期时间，邀请码将立即失效
- 修改 `is_active` 为 `false` 可以立即禁用邀请码，即使未过期
- 修改奖励信息只影响后续使用该邀请码的新用户，已使用用户不受影响

#### 5.5 删除邀请码
```
DELETE /api/admin/invitation-codes/{id}
Request: {
    "force": false  // 可选，是否强制删除（即使有使用记录）
}
Response: {
    "success": true,
    "message": "邀请码删除成功",
    "deleted_at": "2024-01-15T10:30:00Z"
}
```

**删除说明：**
- **软删除策略**：如果邀请码已有使用记录（通过 invitation_code_stats 视图查询 used_count > 0），建议使用软删除：
  - 将 `is_active` 设置为 `false`
  - 将 `valid_until` 设置为当前时间（立即过期）
  - 保留邀请码记录，以便查看历史数据
- **硬删除策略**：如果邀请码从未使用（通过 invitation_code_stats 视图查询 used_count = 0），可以硬删除：
  - 直接删除邀请码记录
  - 由于外键约束 `ON DELETE CASCADE`，相关的 `user_invitation_usage` 记录也会被删除
- **强制删除**：如果设置了 `force=true`，即使有使用记录也会删除（不推荐，除非确定要清理历史数据）
- **删除前检查**：
  - 检查是否有用户使用过该邀请码
  - 如果有使用记录，建议先禁用或设置过期，而不是直接删除
  - 删除操作不可逆，需要谨慎操作

#### 5.6 获取使用邀请码的用户列表
```
GET /api/admin/invitation-codes/{id}/users?page=1&limit=20
Response: {
    "total": 25,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "user_id": "user001",
            "username": "john_doe",
            "email": "john@example.com",
            "used_at": "2024-01-15T10:30:00Z",
            "reward_received": true,
            "points_received": 5000,  // 整数，最小货币单位（5000积分 = £50.00）
            "points_received_display": "50.00",  // 前端显示格式（£50.00）
            "coupon_received": {
                "id": 1,
                "name": "新用户专享券"
            }
        }
    ]
}
```

#### 5.7 获取邀请码统计信息
```
GET /api/admin/invitation-codes/{id}/statistics
Response: {
    "code": "WELCOME2024",
    "total_users": 25,
    "total_points_given": 125000,  // 整数，最小货币单位（125000积分 = £1250.00）
    "total_points_given_display": "1250.00",  // 前端显示格式（£1250.00）
    "total_coupons_given": 25,
    "usage_by_date": [
        {
            "date": "2024-01-15",
            "count": 5
        }
    ],
    "recent_users": [
        {
            "user_id": "user001",
            "username": "john_doe",
            "used_at": "2024-01-15T10:30:00Z"
        }
    ]
}
```

### 6. 用户详情管理API（管理员）

#### 6.1 获取用户详情（包含积分和优惠券）
```
GET /api/admin/users/{user_id}/details
Response: {
    "user": {
        "id": "user001",
        "username": "john_doe",
        "email": "john@example.com",
        "phone": "+1234567890",
        "created_at": "2024-01-15T10:00:00Z",
        "invitation_code": "WELCOME2024"
    },
    "points_account": {
        "balance": 15000,  // 整数，最小货币单位（15000积分 = £150.00）
        "balance_display": "150.00",  // 前端显示格式（£150.00）
        "total_earned": 50000,  // 整数，最小货币单位（50000积分 = £500.00）
        "total_earned_display": "500.00",  // 前端显示格式（£500.00）
        "total_spent": 35000,  // 整数，最小货币单位（35000积分 = £350.00）
        "total_spent_display": "350.00"  // 前端显示格式（£350.00）
    },
    "coupons": {
        "total": 5,
        "unused": 3,
        "used": 2,
        "expired": 0,
        "list": [
            {
                "id": 123,
                "coupon": {
                    "id": 1,
                    "code": "NEWUSER10",
                    "name": "新用户专享券",
                    "type": "fixed_amount",
                    "discount_value": 200,  // 整数，最小货币单位（200 pence = £2.00）
        "discount_value_display": "2.00"  // 前端显示格式（£2.00）
                },
                "status": "unused",
                "obtained_at": "2024-01-15T10:00:00Z",
                "valid_until": "2024-12-31T23:59:59Z"
            }
        ]
    },
    "points_transactions": {
        "total": 50,
        "recent": [
            {
                "id": 1,
                "type": "earn",
                "amount": 1000,  // 整数，最小货币单位（1000积分 = £10.00）
                "amount_display": "10.00",  // 前端显示格式（£10.00）
                "source": "task_complete_bonus",
                "description": "完成任务 #123 获得积分（平台赠送，非任务报酬）",
                "created_at": "2024-01-15T10:30:00Z"
            }
        ]
    },
    "check_in_stats": {
        "total_days": 15,
        "consecutive_days": 5,
        "last_check_in": "2024-01-15"
    },
    "invitation_usage": {
        "code": "WELCOME2024",
        "used_at": "2024-01-15T10:00:00Z",
        "reward_received": true
    }
}
```

#### 6.2 获取用户积分交易记录
```
GET /api/admin/users/{user_id}/points/transactions?page=1&limit=20
Response: {
    "total": 50,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": 1,
            "type": "earn",
                "amount": 1000,  // 整数，最小货币单位（1000积分 = £10.00）
                "amount_display": "10.00",  // 前端显示格式（£10.00）
                "balance_after": 15000,  // 整数，最小货币单位（15000积分 = £150.00）
                "balance_after_display": "150.00",  // 前端显示格式（£150.00）
            "source": "task_complete_bonus",
            "description": "完成任务 #123 获得积分（平台赠送，非任务报酬）",
            "created_at": "2024-01-15T10:30:00Z"
        }
    ]
}
```

#### 6.3 获取用户优惠券列表
```
GET /api/admin/users/{user_id}/coupons?status=unused
Response: {
    "total": 5,
    "data": [
        {
            "id": 123,
            "coupon": {
                "id": 1,
                "code": "NEWUSER10",
                "name": "新用户专享券",
                "type": "fixed_amount",
                "discount_value": 200,  // 整数，最小货币单位（200 pence = £2.00）
                "discount_value_display": "2.00",  // 前端显示格式（£2.00）
                "min_amount": 1000,  // 整数，最小货币单位（1000 pence = £10.00）
                "min_amount_display": "10.00"  // 前端显示格式（£10.00）
            },
            "status": "unused",
            "obtained_at": "2024-01-15T10:00:00Z",
            "used_at": null,
            "valid_until": "2024-12-31T23:59:59Z"
        }
    ]
}
```

#### 6.4 获取用户签到记录
```
GET /api/admin/users/{user_id}/checkins?page=1&limit=30
Response: {
    "total": 15,
    "page": 1,
    "limit": 30,
    "data": [
        {
            "check_in_date": "2024-01-15",
            "consecutive_days": 5,
            "reward_type": "points",
            "points_reward": 1000,  // 整数，最小货币单位（1000积分 = £10.00）
            "points_reward_display": "10.00",  // 前端显示格式（£10.00）
            "reward_description": "连续签到5天，获得10积分"
        }
    ]
}
```

#### 6.5 搜索用户（支持多条件）
```
GET /api/admin/users/search?keyword=john&page=1&limit=20
GET /api/admin/users/search?invitation_code_text=WELCOME2024&page=1&limit=20
GET /api/admin/users/search?min_points=100&page=1&limit=20
GET /api/admin/users/search?user_type=vip&page=1&limit=20
Response: {
    "total": 10,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": "user001",
            "username": "john_doe",
            "email": "john@example.com",
            "points_balance": 15000,  // 整数，最小货币单位（15000积分 = £150.00）
            "points_balance_display": "150.00",  // 前端显示格式（£150.00）
            "coupons_count": 5,
            "invitation_code": "WELCOME2024",
            "user_type": "vip",
            "created_at": "2024-01-15T10:00:00Z"
        }
    ]
}
```

#### 6.6 修改用户积分（管理员）
```
PUT /api/admin/users/{user_id}/points
Request: {
    "action": "add",  // add(增加), subtract(减少), set(设置)
    "amount": 50.00,
    "description": "管理员手动调整积分",
    "reason": "补偿用户"  // 操作原因
}
Response: {
    "success": true,
    "user_id": "user001",
    "action": "add",
    "amount": 5000,  // 整数，最小货币单位（5000积分 = £50.00）
    "amount_display": "50.00",  // 前端显示格式（£50.00）
    "balance_before": 15000,  // 整数，最小货币单位（15000积分 = £150.00）
    "balance_before_display": "150.00",  // 前端显示格式（£150.00）
    "balance_after": 20000,  // 整数，最小货币单位（20000积分 = £200.00）
    "balance_after_display": "200.00",  // 前端显示格式（£200.00）
    "transaction_id": 123
}
```

**操作说明：**
- `add`: 增加积分（amount为正数）
- `subtract`: 减少积分（amount为正数，系统会转为负数）
- `set`: 设置积分余额为指定值（会计算差值）
- 所有操作都会创建积分交易记录，source标记为"admin_adjustment"
- 操作需要记录管理员ID和操作原因，便于审计

#### 6.7 批量发放积分（管理员）
```
POST /api/admin/rewards/points/batch
Request: {
    "target_type": "user_type",  // user, user_type, all
    "target_value": "vip",  // 用户类型：vip, super, normal
    "amount": 10000,  // 整数，最小货币单位（10000积分 = £100.00）
    "amount_display": "100.00",  // 前端显示格式（£100.00）
    "description": "VIP用户专属积分奖励",
    "is_async": true  // 是否异步处理（大批量时建议异步）
}
Response: {
    "reward_id": 1,
    "status": "processing",
    "estimated_users": 500,
    "message": "批量发放任务已创建，正在处理中"
}
```

**批量发放说明：**
- `target_type=user`: 指定用户列表，target_value为JSON数组，如 ["user001", "user002"]
- `target_type=user_type`: 按用户类型，target_value为类型字符串（vip, super, normal）
- `target_type=all`: 所有用户，target_value为空
- 如果async=true，返回任务ID，可以通过查询接口查看进度
- 如果async=false，同步处理，返回处理结果

#### 6.8 批量发放优惠券（管理员）
```
POST /api/admin/rewards/coupons/batch
Request: {
    "target_type": "user",
    "target_value": ["user001", "user002", "user003"],  // 用户ID列表
    "coupon_id": 5,
    "description": "活动期间优惠券发放",
    "is_async": false
}
Response: {
    "reward_id": 2,
    "status": "completed",
    "total_users": 3,
    "success_count": 3,
    "failed_count": 0,
    "details": [
        {
            "user_id": "user001",
            "status": "success",
            "user_coupon_id": 456
        }
    ]
}
```

#### 6.9 查询发放任务状态
```
GET /api/admin/rewards/{reward_id}
Response: {
    "id": 1,
    "reward_type": "points",
    "target_type": "user_type",
    "target_value": "vip",
    "points_value": 10000,  // 整数，最小货币单位（10000积分 = £100.00）
    "points_value_display": "100.00",  // 前端显示格式（£100.00）
    "total_users": 500,
    "success_count": 498,
    "failed_count": 2,
    "status": "processing",  // pending, processing, completed, failed
    "description": "VIP用户专属积分奖励",
    "created_by": "admin001",
    "created_at": "2024-01-15T10:00:00Z",
    "progress": 99.6,  // 进度百分比
    "failed_users": [
        {
            "user_id": "user999",
            "error": "用户不存在"
        }
    ]
}
```

#### 6.10 获取发放任务列表
```
GET /api/admin/rewards?page=1&limit=20&reward_type=points&status=completed
Response: {
    "total": 50,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": 1,
            "reward_type": "points",
            "target_type": "user_type",
            "target_value": "vip",
            "points_value": 10000,  // 整数，最小货币单位（10000积分 = £100.00）
    "points_value_display": "100.00",  // 前端显示格式（£100.00）
            "total_users": 500,
            "success_count": 498,
            "status": "completed",
            "created_at": "2024-01-15T10:00:00Z",
            "completed_at": "2024-01-15T10:05:00Z"
        }
    ]
}
```

#### 6.11 获取发放任务详情（用户列表）
```
GET /api/admin/rewards/{reward_id}/details?page=1&limit=20&status=success
Response: {
    "total": 498,
    "page": 1,
    "limit": 20,
    "data": [
        {
            "id": 1,
            "user_id": "user001",
            "username": "john_doe",
            "email": "john@example.com",
            "reward_type": "points",
            "points_value": 10000,  // 整数，最小货币单位（10000积分 = £100.00）
    "points_value_display": "100.00",  // 前端显示格式（£100.00）
            "status": "success",
            "completed_at": "2024-01-15T10:01:00Z"
        }
    ]
}
```

### 7. 任务支付集成

#### 7.1 创建任务支付（支持积分和优惠券）
```
POST /api/tasks/{task_id}/payment
Request: {
    "payment_method": "points",  // points（仅用于抵扣平台服务费，source=platform_fee）, stripe, coupon+points等
    "points_amount": 1000,  // 整数，最小货币单位（1000积分 = £10.00），仅用于抵扣平台服务费（申请费），不能用于向第三方付款
    "coupon_code": "NEWUSER10",  // 优惠券代码（可选）
    "stripe_amount": 0  // 整数，最小货币单位（Stripe支付金额，如果使用混合支付）
}
Response: {
    "payment_id": 123,
    "fee_type": "application_fee",  // 费用类型：application_fee（申请费），积分仅能抵扣申请费
    "total_amount": 1500,  // 整数，最小货币单位（1500 pence = £15.00）
    "total_amount_display": "15.00",  // 前端显示格式（£15.00）
    "points_used": 1000,  // 整数，最小货币单位（1000积分 = £10.00），仅用于抵扣申请费
    "points_used_display": "10.00",  // 前端显示格式（£10.00）
    "coupon_discount": 200,  // 整数，最小货币单位（200 pence = £2.00）
    "coupon_discount_display": "2.00",  // 前端显示格式（£2.00）
    "stripe_amount": 300,  // 整数，最小货币单位（300 pence = £3.00）
    "stripe_amount_display": "3.00",  // 前端显示格式（£3.00）
    "currency": "GBP",
    "final_amount": 300,  // 整数，最小货币单位（300 pence = £3.00）
    "final_amount_display": "3.00",  // 前端显示格式（£3.00）
    "checkout_url": "https://...",  // 如果需要Stripe支付
    "note": "积分仅用于抵扣申请费/平台服务费，任务奖励将按法币结算给服务者"  // 合规说明
}
```

**重要说明：**
- **任务结算**：发布者→（法币）→学生，平台只做法币结算
- **积分抵扣**：积分仅用于抵扣任务发布费（申请费/平台服务费）
- **任务曝光度提升**：发布者可用积分购买 Boost/置顶等平台服务（`source=task_boost`），属于平台自营服务，不构成向第三方支付
- **任务完成奖励**：平台另行发放积分作为完成奖励（`source=task_complete_bonus`），该积分**非任务对价、无现金价值**，仅可抵平台费/兑自营/兑券
- **合规边界**：积分不能用于向第三方付款，任务奖励将按法币结算给服务者，确保积分不直接作为对服务者的酬劳

---

## 🎨 前端实现

### 1. 积分账户页面

**功能：**
- 显示当前积分余额
- 显示累计获得/消费积分
- 积分交易记录列表（分页）
- 积分使用说明：
  - ✅ **允许**：抵扣申请费（任务发布费）、兑换自营商品、兑换折扣券
  - ❌ **禁止**：转账、提现、作为用户奖励支付给服务者

**组件位置：**
- `frontend/src/pages/PointsAccount.tsx` 或集成到个人中心

### 2. 优惠券中心

**功能：**
- 展示可用优惠券列表
- 领取优惠券
- 我的优惠券列表（未使用/已使用/已过期）
- 优惠券详情和使用说明
- 显示使用条件限制：
  - 过期时间显示（有效期倒计时）
  - 地点限制提示
  - 时间限制提示（允许使用的星期和时间段）
  - 任务类型限制提示
  - 金额限制提示

**组件位置：**
- `frontend/src/pages/CouponCenter.tsx`

### 3. 任务支付集成

**功能：**
- 平台服务费支付方式选择（积分抵扣/Stripe支付/混合支付）
  - **注意**：积分仅用于抵扣平台服务费（申请费），不能用于向第三方付款，任务奖励按法币结算
- 优惠券选择器（用于抵扣平台服务费）
- 实时计算优惠后金额
- 支付确认

**集成位置：**
- 修改 `TaskDetail.tsx` 中的支付流程
- 添加积分抵扣选项（仅用于抵扣平台服务费，source=platform_fee）
- 添加优惠券选择器

**支付流程说明：**
1. 用户发布任务，需支付平台服务费（申请费）
2. 用户可以使用积分抵扣平台服务费（100积分=£1.00，source=platform_fee）
3. 任务完成后，平台按法币向服务者结算任务奖励（不使用积分）
4. 确保积分不直接作为对服务者的酬劳，仅用于抵扣平台侧收费

### 4. 积分获取提示

**功能：**
- 完成任务后显示积分奖励
- 邀请成功显示积分奖励
- 积分变动通知

**实现方式：**
- Toast 通知
- 通知中心消息

### 5. 签到页面

**功能：**
- 每日签到按钮
- 显示连续签到天数
- 签到日历（显示最近7天签到状态）
- 签到奖励预览（显示连续签到奖励规则）
- 签到成功动画和奖励提示

**组件位置：**
- `frontend/src/pages/CheckIn.tsx` 或集成到个人中心

### 6. 管理员配置页面

**功能：**
  - 积分系统配置
  - 积分兑换比例（100积分=£1.00）
  - 积分使用限制设置（仅允许抵扣申请费、兑换自营商品、兑换折扣券）
  - 积分获取规则（任务完成、邀请等）
  - 积分过期设置
  - **注意**：积分不可转账、不可提现、不可作为用户奖励、不可用于向第三方付款
- 优惠券系统配置
  - 新用户自动发放设置
  - 优惠券默认参数
- 优惠券管理
  - 创建优惠券（设置过期时间、使用条件限制）
  - 编辑优惠券（修改过期时间、使用条件等）
  - 删除优惠券
  - 优惠券列表和详情查看
  - 使用条件限制设置：
    - 地点限制（多选）
    - 时间限制（星期、时间段、禁用日期）
    - 任务类型限制（允许/排除）
    - 金额限制（最小/最大金额）
- 积分和优惠券发放管理
  - 修改用户积分（增加/减少/设置）
  - 批量发放积分（按用户类型或指定用户）
  - 批量发放优惠券（按用户类型或指定用户）
  - 发放任务列表和详情查看
  - 发放进度查询
  - 发放记录和审计
- 签到系统配置
  - 每日基础积分
  - 最大连续签到天数
  - 连续签到奖励规则管理（增删改查）

**组件位置：**
- `frontend/src/pages/admin/SystemSettings.tsx`
- `frontend/src/pages/admin/CheckInSettings.tsx`
- `frontend/src/pages/admin/CouponSettings.tsx`

### 7. 邀请码管理页面（管理员）

**功能：**
- 邀请码列表
  - 显示所有邀请码（支持筛选：全部/启用/禁用/已过期/即将过期）
  - 显示邀请码基本信息（代码、名称、奖励类型、使用次数、有效期等）
  - 显示过期状态（已过期/即将过期/有效）
  - 支持搜索邀请码
  - 支持按过期时间排序
- 创建邀请码
  - 邀请码代码输入（自动生成或手动输入）
  - 邀请码名称和描述
  - 奖励类型选择（积分/优惠券/两者都有）
  - 积分奖励数量设置
  - 优惠券选择（如果选择优惠券奖励）
  - 使用次数限制设置
  - 有效期设置
- 编辑邀请码
  - 修改邀请码信息
  - 启用/禁用邀请码
  - 修改过期时间（可以提前设置过期或延长有效期）
- 删除邀请码
  - 软删除：禁用并设置过期（保留历史记录）
  - 硬删除：完全删除（仅限未使用的邀请码）
  - 删除前确认和提示
- 邀请码详情
  - 显示邀请码完整信息
  - 使用统计（总使用次数、总发放积分、总发放优惠券）
  - 使用趋势图表
- 使用邀请码的用户列表
  - 显示所有使用该邀请码的用户
  - 显示用户基本信息（用户名、邮箱、注册时间）
  - 显示奖励发放情况
  - 支持导出用户列表

**组件位置：**
- `frontend/src/pages/admin/InvitationCodeManagement.tsx`
- `frontend/src/pages/admin/InvitationCodeDetail.tsx`
- `frontend/src/pages/admin/InvitationCodeUsers.tsx`

### 8. 用户详情管理页面（管理员）

**功能：**
- 用户搜索
  - 支持按用户名、邮箱、用户ID搜索
  - 支持按邀请码筛选
  - 支持按积分范围筛选
  - 支持按注册时间范围筛选
- 用户详情展示
  - 用户基本信息（ID、用户名、邮箱、手机号、注册时间等）
  - 积分账户信息
    - 当前余额
    - 累计获得/消费积分
    - 积分交易记录列表（支持分页）
  - 优惠券信息
    - 优惠券总数统计（未使用/已使用/已过期）
    - 优惠券列表（支持按状态筛选）
    - 优惠券详情（优惠券信息、获得时间、使用时间等）
  - 签到信息
    - 总签到天数
    - 连续签到天数
    - 最后签到日期
    - 签到记录列表
  - 邀请码使用信息
    - 使用的邀请码
    - 使用时间
    - 获得的奖励
- 数据导出
  - 导出用户积分交易记录
  - 导出用户优惠券列表
  - 导出用户签到记录

**组件位置：**
- `frontend/src/pages/admin/UserManagement.tsx`
- `frontend/src/pages/admin/UserDetail.tsx`
- `frontend/src/pages/admin/UserSearch.tsx`

---

## 🔄 业务流程

### 1. 任务完成获得积分流程（平台赠送，非任务报酬）

**合规设计说明：**
- 任务结算路径：发布者→（法币）→学生，平台只做法币结算
- 平台另行发放积分作为完成奖励，该积分**非任务对价、无现金价值**，仅可抵平台费/兑自营/兑券
- 积分必须是平台赠送的忠诚度奖励，而不是任务的支付货币

**流程：**
```
1. 用户完成任务
2. 任务状态更新为 completed
3. **法币结算**：平台按法币向服务者结算任务奖励（不使用积分）
4. **积分发放**（并行触发）：
   - 调用积分发放服务：type=earn, source=task_complete_bonus, amount=300（带 idempotency_key）
   - 记录批次与过期时间：batch_id=2025Q1-COMP, expires_at=2026-03-31T23:59:59Z
   - 记录关联信息：related_type=task, related_id=123
   - 更新用户积分账户余额
5. 发送通知给用户："完成任务获得XX积分（平台赠送，非任务报酬）"
6. UI 标注："平台赠送积分，非任务报酬"
```

**示例记录（points_transactions）：**
```sql
-- 学生完成任务 #123，平台赠送 300 积分
type=earn
source=task_complete_bonus
related_type=task
related_id=123
amount=300  -- 300积分 = £3.00
batch_id=2025Q1-COMP
expires_at=2026-03-31T23:59:59Z
```

**发布者购买任务曝光度提升（Boost）示例：**
```sql
-- 发布者为任务 #124 购买 7 天曝光 Boost，花 1500 积分
type=spend
source=task_boost  -- 任务曝光度提升（平台自营服务）
related_type=task
related_id=124
amount=-1500  -- 1500积分 = £15.00
-- 属于"平台自营服务消费"，不构成向第三方支付
```

**风控与限额：**
- 对"接单送积分"设每日/每月上限
- 完成校验、评价达标、作弊拦截（设备/账号/IP 聚类）以防刷分
- 利用批次、幂等键，易于审计

### 2. 使用积分抵扣平台发布费流程（仅抵扣 platform fee，不涉及服务者结算）

```
1. 用户发布任务，需支付平台服务费（申请费）
2. 用户选择使用积分抵扣申请费（100积分=£1.00）
3. 系统检查用户积分余额是否足够
4. 如果足够：
   - 创建支付记录（fee_type: "application_fee"，仅用于平台服务费）
   - 扣除用户积分（创建积分交易记录 type=spend, source=platform_fee）
   - 更新任务平台服务费支付状态（任务奖励仍按法币结算给服务者）
5. 如果不足：
   - 提示用户积分不足
   - 提供混合支付选项（积分+Stripe）
6. 任务完成后的服务者奖励仅法币结算（不使用积分）
```

### 3. 使用优惠券抵扣任务申请费流程

```
1. 用户在支付任务申请费时选择优惠券
2. 系统验证优惠券：
   - 检查优惠券状态和有效期（valid_from <= 当前时间 <= valid_until）
   - 检查过期时间：如果已过期，返回错误
   - 检查使用条件（订单金额、用户类型等）
   - 检查使用条件限制：
     * 地点限制：任务地点必须在允许的地点列表中
     * 时间限制：
       - 当前日期必须在允许的星期范围内
       - 当前时间必须在允许的时间段内
       - 当前日期不能在禁用日期列表中
     * 任务类型限制：任务类型必须在允许的类型列表中，且不在排除列表中
     * 金额限制：任务金额必须在 min_task_amount 和 max_task_amount 范围内
   - 检查用户是否已使用（per_user_limit）
3. 计算优惠金额：根据优惠券类型计算实际优惠
4. 应用优惠：
   - 从订单金额中扣除优惠金额
   - 更新 user_coupons 状态为 used
   - 记录使用日志
5. 完成支付（剩余金额使用积分或Stripe支付）
```

**验证失败处理：**
- 如果优惠券已过期：返回 "优惠券已过期，过期时间：{valid_until}"
- 如果地点不符合：返回 "该优惠券仅限在 {locations} 使用，当前任务地点：{task_location}"
- 如果时间不符合：返回 "该优惠券仅在 {time_restrictions} 可使用"
- 如果任务类型不符合：返回 "该优惠券不适用于此任务类型：{task_type}"
- 如果金额不符合：返回 "任务金额 {amount} 不符合优惠券使用条件（{min} - {max}）"

**注意：** 积分不可提现，仅限平台内使用（合规要求，避免触发电子货币监管）

**合规使用范围（重要，对齐Grab做法）：**
- ✅ **允许**：抵扣平台侧收费（任务发布费、平台服务费、会员费等）
- ❌ **禁止**：直接作为对第三方服务者的酬劳（不构成用户间价值转移）
- ❌ **禁止**：提现、转账、兑换现金
- ❌ **禁止**：在用户间转让或交易

**合规模型说明：**
积分仅用于抵扣平台侧收费（申请费/服务费）和兑换平台自营商品/折扣券，不能转账、不能提现、不能作为用户奖励。平台先收单（用户使用积分+现金支付平台服务费），然后按法币向服务者结算任务奖励，确保积分不直接作为对第三方的酬劳，避免触发电子货币监管。

### 5. 退款处理流程

**退款规则：**

1. **使用优惠券的订单退款**：
   - **原路返还策略**：优惠券返还到用户账户（如果未过期）
     - 如果优惠券已过期：发放新优惠券（相同类型和金额）或等值积分
     - 新券有效期：从退款时间开始，使用原券的剩余有效期或默认有效期
   - **新券补发策略**：如果原券已过期，补发新券
   - 记录退款来源（`source='coupon_refund'`）
   - 在 `coupon_usage_logs` 中更新 `refund_status` 和 `refunded_at`

2. **使用积分的订单退款**：
   - **原路返还**：积分返还到用户账户
   - 记录退款来源（`source='points_refund'`）
   - **保持批次信息**：使用原始交易的 `batch_id`，用于会计合规
   - 在 `points_transactions` 中记录退款（`type=refund`，关联原始交易ID）

3. **混合支付退款**：
   - **按比例返还**：先返还优惠券，再返还积分
   - 记录退款详情（包含原始支付信息、各部分的退款金额）

4. **退款记录和审计**：
   - 在 `points_transactions` 中记录退款（`type=refund`，`related_type='task'`，`related_id=task_id`）
   - 在 `coupon_usage_logs` 中标记退款状态（`refund_status='full'` 或 `'partial'`）
   - 在 `audit_logs` 中记录退款操作（操作者、原因、金额等）
   - 保留原始交易关联，便于审计和会计合规

### 6. 每日签到流程

```
1. 用户点击签到按钮
2. 系统检查：
   - 检查今天是否已签到（通过check_in_date判断）
   - 检查昨天是否签到（计算连续天数）
   - 如果昨天未签到，连续天数重置为1
3. 计算奖励：
   - 发放每日基础积分（从系统设置读取）
   - 检查连续签到天数，匹配奖励规则
   - 如果达到连续签到奖励条件，发放额外奖励（积分或优惠券）
4. 记录签到：
   - 创建签到记录（check_ins表）
   - 如果奖励是积分，创建积分交易记录（type=earn, source=checkin_bonus）
   - 如果奖励是优惠券，创建user_coupons记录
5. 返回签到结果和奖励信息
```

### 7. 连续签到奖励计算流程

```
1. 用户签到后，系统查询连续签到天数
2. 查询签到奖励配置表（check_in_rewards）：
   - 查找匹配的连续天数配置（consecutive_days <= 当前连续天数）
   - 选择最大匹配的奖励配置
3. 如果找到匹配的奖励配置：
   - 检查奖励类型（points或coupon）
   - 如果奖励类型是积分：
     - 发放积分到用户账户
     - 创建积分交易记录（type=earn, source=checkin_bonus）
   - 如果奖励类型是优惠券：
     - 检查优惠券是否存在且有效
     - 发放优惠券到用户账户
     - 创建user_coupons记录
4. 更新签到记录的奖励信息
```

### 7. 使用邀请码注册流程

```
1. 用户注册时输入邀请码
2. 系统验证邀请码：
   - 检查邀请码是否存在
   - 检查邀请码是否启用（is_active=true）
   - 检查邀请码是否在有效期内：
     * 当前时间 >= valid_from
     * 当前时间 <= valid_until
     * 如果已过期，返回错误："邀请码已过期"
   - 检查使用次数限制（used_count < max_uses 或 max_uses为NULL）
   - 如果使用次数已达上限，返回错误："邀请码使用次数已达上限"
3. 创建用户账户：
   - 保存用户信息
   - 记录用户使用的邀请码（users.invitation_code_id 和 users.invitation_code_text）
4. 发放注册奖励：
   - 如果奖励类型包含积分：
     - 创建积分账户（如果不存在）
     - 增加用户积分余额
     - 创建积分交易记录（type=earn, source=invite_bonus）
   - 如果奖励类型包含优惠券：
     - 检查优惠券是否存在且有效
     - 创建user_coupons记录
5. 记录使用情况：
   - 创建user_invitation_usage记录
   - 更新invitation_codes.used_count
   - 标记reward_received=true
6. 返回注册成功信息和奖励详情
```

**验证失败处理：**
- 如果邀请码不存在：返回 "邀请码不存在"
- 如果邀请码已禁用：返回 "邀请码已禁用"
- 如果邀请码已过期：返回 "邀请码已过期，过期时间：{valid_until}"
- 如果邀请码未生效：返回 "邀请码尚未生效，生效时间：{valid_from}"
- 如果使用次数已达上限：返回 "邀请码使用次数已达上限"

### 8. 管理员查看用户详情流程

```
1. 管理员在用户管理页面搜索用户
2. 点击用户进入详情页
3. 系统加载用户完整信息：
   - 用户基本信息（从users表）
   - 积分账户信息（从points_accounts表）
   - 积分交易记录（从points_transactions表，分页加载）
   - 优惠券列表（从user_coupons表，关联coupons表）
   - 签到记录（从check_ins表）
   - 邀请码使用记录（从user_invitation_usage表，关联invitation_codes表）
4. 展示所有信息，支持筛选和导出
```

---

## 🛠️ 开发步骤

### 阶段一：数据库设计（已完成）

1. ✅ 创建优惠券相关表（coupons, user_coupons, coupon_usage_logs）
2. ✅ 创建积分相关表（points_accounts, points_transactions）
3. ✅ 创建签到相关表（check_ins, check_in_rewards）
4. ✅ 创建邀请码相关表（invitation_codes, user_invitation_usage）
5. ✅ 创建管理员发放记录表（admin_rewards, admin_reward_details）
6. ✅ 修改users表添加invitation_code字段
7. ✅ 创建必要的索引和外键约束
8. ✅ 添加数据验证约束（CHECK约束）

### 阶段二：后端模型和CRUD

1. **创建SQLAlchemy模型**
   - `backend/app/models.py` 中添加 Coupon, UserCoupon, PointsAccount, PointsTransaction, CouponUsageLog, CheckIn, CheckInReward, InvitationCode, UserInvitationUsage, AdminReward, AdminRewardDetail 模型

2. **创建Pydantic Schema**
   - `backend/app/schemas.py` 中添加相关Schema

3. **实现CRUD操作**
   - `backend/app/crud.py` 中添加积分和优惠券的CRUD函数

### 阶段三：后端API实现

1. **积分API**
   - 获取积分账户信息
   - 获取积分交易记录
   - **注意：** 积分不可提现，仅限平台内使用

2. **优惠券API**
   - 获取可用优惠券列表
   - 领取优惠券
   - 获取用户优惠券列表
   - 验证和使用优惠券

3. **任务支付集成**
   - 修改任务支付接口，支持积分和优惠券
   - 添加支付方式选择逻辑

4. **积分自动发放**
   - 任务完成时自动发放积分
   - 邀请成功时发放积分
   - 其他奖励场景

5. **签到API**
   - 每日签到接口
   - 获取签到状态接口
   - 获取签到奖励配置接口

6. **管理员配置API**
   - 积分系统配置管理
   - 优惠券系统配置管理
   - 签到系统配置管理
   - 签到奖励规则管理（CRUD）

7. **邀请码管理API**
   - 创建、更新、删除邀请码
   - 获取邀请码列表和详情
   - 获取使用邀请码的用户列表
   - 获取邀请码统计信息

8. **用户详情管理API**
   - 获取用户完整详情（包含积分、优惠券、签到等）
   - 获取用户积分交易记录
   - 获取用户优惠券列表
   - 获取用户签到记录
   - 用户搜索（支持多条件）
   - 修改用户积分（增加/减少/设置）

9. **批量发放API**
   - 批量发放积分（按用户类型或指定用户）
   - 批量发放优惠券（按用户类型或指定用户）
   - 查询发放任务状态和进度
   - 获取发放任务列表和详情
   - 获取发放任务用户列表

10. **注册流程集成**
   - 修改用户注册接口，支持邀请码验证
   - 注册时自动发放邀请码奖励
   - 记录邀请码使用情况

### 阶段四：前端实现

1. **积分账户页面**
   - 创建积分账户组件
   - 显示余额和交易记录
   - 积分使用说明展示（仅可抵扣申请费、兑换自营商品、兑换折扣券）

2. **优惠券中心**
   - 创建优惠券中心页面
   - 实现领取和使用功能
   - 我的优惠券列表

3. **任务支付集成**
   - 修改任务支付流程
   - 添加积分支付选项
   - 添加优惠券选择器

4. **通知和提示**
   - 积分获得提示
   - 优惠券使用提示

5. **签到页面**
   - 创建签到组件
   - 签到日历显示
   - 连续签到天数显示
   - 签到奖励预览

6. **管理员配置页面**
   - 系统设置页面
   - 积分配置管理
   - 优惠券配置管理
   - 签到配置管理
   - 签到奖励规则管理界面

7. **邀请码管理页面**
   - 邀请码列表和搜索
   - 创建/编辑邀请码
   - 邀请码详情和统计
   - 使用邀请码的用户列表

8. **用户详情管理页面**
   - 用户搜索（多条件）
   - 用户详情展示（积分、优惠券、签到、邀请码等）
   - 修改用户积分功能
   - 数据导出功能

9. **批量发放管理页面**
   - 批量发放积分界面
   - 批量发放优惠券界面
   - 发放任务列表
   - 发放任务详情和进度查看
   - 发放记录查询和导出

### 阶段五：定时任务和自动化

1. **优惠券过期检查**
   - 定时任务检查过期优惠券（valid_until < 当前时间）
   - 自动将过期优惠券的 status 设置为 'expired'
   - 更新 user_coupons 状态为 expired
   - 记录过期时间，便于统计和分析

2. **积分过期处理**（如果启用）
   - 定时任务检查过期积分
   - 自动扣除过期积分

3. **签到重置处理**
   - 定时任务检查连续签到中断
   - 如果用户超过1天未签到，连续天数自动重置

4. **邀请码过期处理**
   - 定时任务检查过期邀请码（valid_until < 当前时间）
   - 自动将过期邀请码的 `is_active` 设置为 `false`
   - 记录过期时间，便于统计和分析

5. **数据统计和报表**
   - 积分发放统计
   - 优惠券使用统计
   - 邀请码使用统计

6. **数据库约束和触发器**
   - 创建 updated_at 自动更新触发器
   - 添加数据验证约束（CHECK约束）

### 阶段六：测试和优化

1. **单元测试**
   - 积分计算逻辑测试
   - 优惠券验证逻辑测试

2. **集成测试**
   - 支付流程测试
   - 积分发放流程测试

3. **性能优化**
   - 数据库查询优化
   - 缓存策略（Redis缓存积分余额等）

---

## 📊 系统设置

在 `system_settings` 表中添加以下配置项：

```sql
-- 积分相关设置
INSERT INTO system_settings (key, value, description) VALUES
('points_exchange_rate', '100.0', '积分兑换比例（100积分=100最小货币单位=£1.00，仅限平台内使用）'),
('points_task_complete_bonus', '500', '任务完成奖励积分（固定值，整数，如500积分=£5.00，平台赠送，非任务报酬）'),
('points_invite_reward', '5000', '邀请新用户奖励积分（固定值，整数，如5000积分=£50.00，平台赠送）'),
('points_invite_task_bonus', '500', '被邀请用户完成任务，邀请者获得积分奖励（固定值，整数，如500积分=£5.00，平台赠送，非任务报酬）'),
('points_expire_days', '0', '积分有效期（天），0表示永不过期（符合会计要求）'),
('points_batch_tracking', 'true', '是否启用积分批次追踪（用于会计合规）'),

-- 优惠券相关设置
('coupon_new_user_auto_issue', 'true', '新用户自动发放优惠券'),
('coupon_new_user_type', 'fixed_amount', '新用户优惠券类型'),
('coupon_new_user_value', '200', '新用户优惠券金额（整数，最小货币单位，如200=£2.00）'),
('coupon_new_user_min_amount', '1000', '新用户优惠券最低使用金额（整数，最小货币单位）'),

-- 签到相关设置
('checkin_daily_base_points', '500', '每日签到基础积分奖励（整数，如500积分=£5.00）'),
('checkin_max_consecutive_days', '30', '最大连续签到天数（超过后重置）'),
('checkin_enabled', 'true', '是否启用签到功能'),
('checkin_timezone', 'Europe/London', '签到时区（用于判断"今天"）'),

-- 邀请码相关设置
('invitation_code_enabled', 'true', '是否启用邀请码功能'),
('invitation_code_auto_generate', 'false', '是否自动生成邀请码（如果创建时未指定）'),
('invitation_code_length', '12', '自动生成邀请码长度（建议10-14位高熵随机码）'),
('invitation_code_default_points', '0', '默认积分奖励（整数，如0积分=£0.00）'),

-- 风控相关设置
('risk_control_enabled', 'true', '是否启用风控系统'),
('device_fingerprint_enabled', 'true', '是否启用设备指纹'),
('max_checkin_per_device_per_day', '1', '每个设备每天最多签到次数'),
('max_coupon_claim_per_ip_per_hour', '10', '每个IP每小时最多领取优惠券次数'),
('risk_score_threshold_high', '70', '高风险阈值'),
('risk_score_threshold_critical', '90', '严重风险阈值'),

-- 优惠叠加设置
('coupon_combine_default', 'false', '优惠券默认是否可叠加'),
('coupon_combine_max', '5', '最多可叠加优惠券数量'),
('coupon_points_combine', 'true', '优惠券是否可与积分叠加'),

-- VAT设置
('vat_enabled', 'true', '是否启用VAT'),
('vat_default_rate', '20.00', '默认VAT税率（%）'),
('vat_timezone', 'Europe/London', 'VAT计算时区');
```

**签到奖励规则配置：**

签到奖励规则存储在 `check_in_rewards` 表中，管理员可以通过后台管理界面进行配置。默认配置示例：

```sql
-- 默认签到奖励规则（使用整数，100积分=£1.00）
INSERT INTO check_in_rewards (consecutive_days, reward_type, points_reward, coupon_id, reward_description) VALUES
(3, 'points', 500, NULL, '连续签到3天，额外获得500积分（£5.00）'),
(7, 'points', 1000, NULL, '连续签到7天，额外获得1000积分（£10.00）'),
(15, 'coupon', NULL, 1, '连续签到15天，获得优惠券（ID=1）'),
(30, 'points', 5000, NULL, '连续签到30天，额外获得5000积分（£50.00）');
```

**数据库约束和触发器：**

```sql
-- 1. 创建 updated_at 自动更新触发器函数
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. 为需要的表统一挂触发器（在 UPDATE 时自动刷新 updated_at）
CREATE TRIGGER trg_coupons_updated
  BEFORE UPDATE ON coupons
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_points_accounts_updated
  BEFORE UPDATE ON points_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_check_in_rewards_updated
  BEFORE UPDATE ON check_in_rewards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_invitation_codes_updated
  BEFORE UPDATE ON invitation_codes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_promotion_codes_updated
  BEFORE UPDATE ON promotion_codes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_coupons_updated
  BEFORE UPDATE ON user_coupons
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_coupon_redemptions_updated
  BEFORE UPDATE ON coupon_redemptions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_points_transactions_updated
  BEFORE UPDATE ON points_transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_coupon_usage_logs_updated
  BEFORE UPDATE ON coupon_usage_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_admin_rewards_updated
  BEFORE UPDATE ON admin_rewards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_admin_reward_details_updated
  BEFORE UPDATE ON admin_reward_details
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3. 数据验证约束（已在表定义中添加，此处为说明）
-- coupons 表：
--   - chk_coupon_dates: valid_until > valid_from
--   - chk_coupon_discount: 
--     * type='fixed_amount' → discount_value > 0
--     * type='percentage' → discount_value BETWEEN 1 AND 10000（基点，0.01%-100%）
-- promotion_codes 表：
--   - chk_promo_dates: valid_until > valid_from
```

**管理员配置说明：**

所有系统参数都可以通过管理员后台进行配置，包括：
- 积分系统的所有参数（兑换比例、奖励规则等，**注意：积分不可提现**）
- 优惠券系统的所有参数（新用户发放规则、叠加规则等）
- 签到系统的所有参数（基础积分、最大连续天数、时区等）
- 签到奖励规则（可以添加、修改、删除、启用/禁用）
- 风控系统参数（风险阈值、频率限制等）
- VAT设置（税率、时区等）

---

## 🎯 规则体系（学习大厂做法）

### 1. 优惠叠加矩阵（后台可配）

**默认规则（与Stripe/多数电商一致）：**
- 优惠券默认不可叠加（`can_combine=false`）
- "优惠券 + 积分"可以叠加
- 叠加顺序：先应用优惠券，再应用积分（`apply_order`数值越小越先应用）

**高阶配置（类似Shopify）：**
- 支持"允许组合"的粒度开关（`can_combine`）
- 设置最多可叠加数量（`combine_limit`，如最多5张）
- 支持运费券单独叠加（如果未来有运费券功能）
- 支持"可组合"的优惠券类型配置

**叠加计算示例（使用整数和基点）：**
```
原始金额：£100.00 (10000 pence)
优惠券1（满减£10，apply_order=1，can_combine=true）：
  10000 - 1000 = 9000 pence

优惠券2（9折，discount_value=1000 bp，apply_order=2，can_combine=true）：
  折扣金额 = 9000 * 1000 / 10000 = 900 pence
  9000 - 900 = 8100 pence

积分抵扣（£20.00，2000积分）：
  8100 - 2000 = 6100 pence

最终金额：£61.00 (6100 pence)
```

**叠加规则引擎（类似Shopify）：**
- 枚举所有允许的组合
- 计算每种组合的最终金额
- 自动选择对用户最有利的组合
- 支持后台配置可组合清单和优先级

### 2. 资格与限次规则

**用户资格限制：**
- **首单限制**：仅限首次下单使用（`eligibility_type='first_order'`）
- **新用户限制**：仅限新用户使用（注册30天内，`eligibility_type='new_user'`）
- **特定分群**：按用户类型限制（vip, super, normal，`eligibility_type='user_type'`）
- **会员限制**：仅限会员使用（`eligibility_type='member'`）

**使用次数限制：**
- **每码每人仅一次**：`per_user_limit=1`（数据库唯一约束保证）
- **全局兑换上限**：`total_quantity`（使用查询统计实际使用，避免手动累加）
- **每日限次**：`per_day_limit`（按设备/IP/用户）
- **每设备限次**：`per_device_limit`（反滥用）
- **每IP限次**：`per_ip_limit`（反滥用）

**Stripe风格的Coupon vs Promotion Code分离：**
- **Coupon（优惠券模板）**：定义优惠规则（折扣、满减等）
- **Promotion Code（推广码）**：一个Coupon可以映射多个Promotion Code
- 每个Promotion Code可以独立设置：
  - 使用次数限制
  - 有效期
  - 目标用户群体
  - 是否激活

**实现方式：**
- 创建 `promotion_codes` 表，关联到 `coupons` 表
- 用户使用推广码，系统查找对应的优惠券
- 支持批量生成推广码（如活动期间生成1000个不同的推广码，都指向同一个优惠券）

---

## 🛡️ 反滥用与风控系统

### 1. 账户/设备绑定

**多维度绑定：**
- **手机号绑定**：一个手机号只能绑定一个账户
- **支付工具绑定**：支付方式（银行卡、PayPal等）与账户绑定
- **设备指纹绑定**：设备指纹与账户关联，检测多账号

**异常检测：**
- **异常设备聚类**：同一设备关联多个账号 → 标记为可疑
- **地址聚类识别**：同一IP/地址大量账号 → 标记为羊毛党
- **行为模式分析**：短时间内大量操作 → 触发风控

**拉新奖励风控：**
- **真实支付验证**：被邀请人需完成真实支付/任务才记奖励
- **任务完成验证**：被邀请人需完成至少一个真实任务
- **防虚假拉新**：检测循环邀请、批量注册等

### 2. 运营保护

**大额/批量发放保护：**
- **两人复核机制**：大额发放需要两个管理员确认
- **幂等性保证**：所有发放操作支持idempotency_key
- **审计日志**：详细记录所有操作（操作者、旧值/新值、原因）

**Dry-run预估成本：**
- 批量发放前支持dry-run模式
- 预估发放成本（总积分/优惠券数量）
- 确认后再执行实际发放

**审批流程：**
- 大额发放需要审批流程
- 审批状态：pending → approved → processing → completed
- 支持审批拒绝和取消

### 4. 风控处理流程

```
1. 用户操作触发风控检查
2. 收集风控数据：
   - 设备指纹
   - IP地址
   - 操作频率
   - 历史行为
   - 账户绑定信息
3. 计算风险评分（0-100）：
   - 设备风险：多账号关联 → +30
   - 行为风险：异常频率 → +20
   - IP风险：地址聚类 → +25
   - 支付风险：异常支付模式 → +15
4. 根据风险等级处理：
   - low (0-40): 正常处理
   - medium (41-70): 需要验证码或额外验证
   - high (71-90): 限制操作或延迟处理
   - critical (91-100): 阻止操作，标记账户
5. 记录风控日志（risk_control_logs表）
6. 更新设备风险评分（device_fingerprints表）
```

---

## 🔒 安全考虑

### 1. 积分安全

- **防刷机制**：限制同一任务重复发放积分，使用idempotency_key防止重复操作
- **并发控制**：使用数据库事务和行级锁（SELECT FOR UPDATE）防止并发问题
- **原子性操作**：所有积分操作使用事务，确保原子性
- **幂等性**：所有操作支持idempotency_key，防止重复执行
- **审计日志**：所有积分变动都有详细记录（包含批次信息）
- **余额校验**：每次积分操作都校验余额，防止负数
- **批次追踪**：积分按批次追踪，支持会计合规和过期处理

### 2. 优惠券安全

- **防刷机制**：
  - 限制领取频率和数量（per_user_limit, per_device_limit, per_ip_limit）
  - 使用idempotency_key防止重复领取/使用
  - 设备指纹和IP地址检测
- **唯一性校验**：优惠券代码不区分大小写唯一（LOWER(code)），防止重复使用
- **过期时间管理**：支持设置和修改过期时间，定时任务自动处理过期优惠券
- **并发控制**：
  - 使用 `SELECT FOR UPDATE` 锁定 `user_coupons` 行，防止并发使用
  - 使用 `SELECT FOR UPDATE` 锁定 `coupons` 行检查全局余量
  - 引入 `coupon_redemptions` 表实现两阶段使用（预授权+确认）
  - 使用 `idempotency_key` 和业务层校验防止重复领取（如果 `per_user_limit=1`，业务层检查 `(user_id, coupon_id)` 是否已存在未使用的记录）
  - 使用部分唯一索引防止重复使用：`(user_id, coupon_id, task_id)` 在 `coupon_redemptions` 表（仅在 `task_id IS NOT NULL` 时约束）
  - 使用部分唯一索引防止并发预留：`(user_coupon_id)` 在 `coupon_redemptions` 表（仅在 `status = 'reserved'` 时约束）
  - 全局余量使用查询统计：`SELECT COUNT(*) FROM user_coupons WHERE coupon_id = ? AND status IN ('unused', 'used', 'expired')`，避免手动累加造成漂移
- **使用条件校验**：严格校验所有使用条件限制，防止滥用
  - 地点限制验证：确保任务地点符合要求
  - 时间限制验证：确保使用时间符合允许的星期和时间段（考虑时区）
  - 任务类型限制验证：确保任务类型符合要求
  - 金额限制验证：确保任务金额在允许范围内
- **使用条件双重验证**：在验证和使用时都要检查，防止绕过验证
- **叠加规则验证**：严格验证优惠叠加规则，防止滥用
- **状态管理**：优惠券状态变更需要严格校验
- **JSON数据验证**：usage_conditions JSON数据要验证格式和内容，防止注入攻击

### 3. 支付安全

- **双重验证**：支付前再次验证积分余额和优惠券有效性
- **事务处理**：支付操作使用数据库事务，确保数据一致性
- **幂等性**：支付接口支持幂等性，防止重复支付

### 4. 签到安全

- **防刷机制**：通过数据库唯一约束（user_id, check_in_date）防止重复签到
- **时区处理**：使用服务器时区判断"今天"，防止跨时区刷签到
- **连续天数计算**：严格校验连续签到逻辑，防止数据异常
- **奖励发放验证**：发放奖励前验证奖励配置的有效性

### 5. 管理员配置安全

- **权限控制**：只有管理员可以访问配置接口
- **参数验证**：所有配置参数都要进行类型和范围验证
- **配置审计**：记录配置变更日志，便于追踪
- **默认值保护**：关键配置设置合理的默认值和范围限制

### 6. 邀请码安全

- **唯一性校验**：邀请码代码必须唯一，防止重复
- **使用次数限制**：严格校验使用次数，防止超限使用
- **有效期校验**：严格校验有效期，防止过期使用
- **过期时间管理**：支持设置和修改过期时间，定时任务自动处理过期邀请码
- **删除保护**：有使用记录的邀请码建议软删除，保留历史数据
- **并发控制**：使用数据库事务和锁防止并发问题
- **奖励发放验证**：发放奖励前验证邀请码状态和奖励配置
- **防刷机制**：每个用户每个邀请码只能使用一次（数据库唯一约束）
- **状态管理**：通过 `is_active` 和 `valid_until` 双重控制，确保过期邀请码无法使用

### 7. 用户数据安全

- **权限控制**：只有管理员可以查看用户详细信息
- **数据脱敏**：敏感信息（如邮箱、手机号）在列表中可以部分隐藏
- **访问日志**：记录管理员查看用户详情的操作日志
- **数据导出限制**：数据导出功能需要额外权限验证

---

## 📈 未来扩展

### 1. 积分商城

- 积分兑换商品
- 积分兑换会员权益
- 积分兑换优惠券

### 2. 积分等级系统

- 根据积分余额划分用户等级
- 不同等级享受不同权益
- 等级奖励机制

### 3. 优惠券活动

- 限时抢券活动
- 节日优惠券
- 任务完成奖励优惠券

### 4. 积分营销

- 积分翻倍活动
- 积分抽奖
- 积分竞拍

### 5. 签到功能扩展

- 签到补签功能（消耗积分或优惠券）
- 签到排行榜
- 签到任务系统（完成特定任务获得额外签到奖励）
- 签到分享奖励（分享签到获得额外积分）

### 6. 邀请码功能扩展

- 邀请码分组管理（按活动、渠道等分组）
- 邀请码批量生成和导入
- 邀请码使用统计报表（按时间、地区等维度）
- 邀请码推荐系统（根据用户特征推荐合适的邀请码）
- 邀请码分享链接（生成专属分享链接，追踪来源）
- 邀请码等级系统（不同等级的邀请码提供不同奖励）

---

## 📝 开发注意事项（大厂标准）

### 1. 数据模型统一性

**金额字段统一：**
- 所有金额字段统一为 `BIGINT`（最小货币单位），包括：
  - `points_accounts.balance/total_earned/total_spent`
  - `points_transactions.amount/balance_after`
  - `coupons.discount_value/min_amount/max_discount`
  - `coupon_usage_logs` 所有金额字段
  - `check_in_rewards.points_reward`
- 避免DECIMAL精度问题和四舍五入问题

**时间字段统一：**
- 所有时间字段统一为 `TIMESTAMPTZ`（带时区），包括：
  - 所有 `created_at/updated_at`
  - `coupons.valid_from/valid_until`
  - `check_ins.created_at`
  - `points_transactions.created_at`
- 避免时区歧义和夏令时问题

**ID字段统一：**
- 所有ID字段统一为 `BIGSERIAL`，支持大规模数据

**多态字段拆分：**
- `check_in_rewards` 和 `check_ins` 都使用 `points_reward BIGINT` 和 `coupon_id BIGINT`
- 通过CHECK约束确保一致性，避免混淆

### 2. 业务逻辑一致性

**积分与现金比例：**
- 积分和现金保持100:1关系（100积分=£1.00=100 pence，仅限平台内使用，不可提现）
- 积分数量使用整数存储，避免浮点数精度问题
- 前端显示时：积分数量 ÷ 100 = 货币金额（£），例如：15000积分 ÷ 100 = £150.00
- 例如：15000积分 = £150.00 = 15000 pence

**优惠券折扣值统一：**
- **满减券（fixed_amount）**：直接减免金额（整数，最小货币单位），如200 = £2.00 = 200 pence
- **折扣券（percentage）**：折扣基点（basis points），如1000表示10%（计算时用 `discount_value / 10000`）
  - 示例：1000 bp = 10%，9000 bp = 90%（即9折），10000 bp = 100%（即免费）
  - 计算：`discount_amount = order_amount * discount_value / 10000`
- 在表注释和API示例中统一说明

**优惠券类型清理：**
- 移除 `type=new_user`，统一使用 `eligibility_type='new_user'`
- 优惠券类型仅保留 `fixed_amount` 和 `percentage`

2. **事务处理**：所有涉及积分和优惠券的操作都要使用数据库事务，确保数据一致性

3. **并发控制**：使用数据库锁（SELECT FOR UPDATE）防止并发问题，特别是在更新积分余额时

4. **错误处理**：完善的错误处理和回滚机制，确保操作失败时数据能够正确回滚

5. **日志记录**：详细记录所有积分和优惠券操作，便于审计和问题排查

6. **性能优化**：积分余额可以考虑使用Redis缓存，减少数据库查询

7. **用户体验**：及时反馈积分变动和优惠券使用情况，提升用户体验

8. **时区处理**：签到功能需要特别注意时区处理，使用服务器时区统一判断"今天"，避免跨时区问题

9. **连续签到计算**：连续签到天数的计算逻辑要准确，考虑跨天、跨月、跨年的情况

10. **管理员配置灵活性**：所有配置项都要有合理的默认值，并且支持动态修改，无需重启服务

11. **邀请码唯一性**：邀请码代码必须全局唯一，创建前要检查是否已存在

12. **邀请码奖励发放**：注册时发放奖励要使用事务，确保数据一致性，如果奖励发放失败，要回滚用户创建

13. **邀请码使用统计**：定期统计邀请码使用情况，更新统计数据，便于管理员查看

14. **用户数据查询性能**：用户详情页面涉及多表关联查询，要注意性能优化，使用适当的索引和分页

15. **邀请码验证时机**：邀请码验证要在用户注册前进行，如果验证失败，要给出明确的错误提示

16. **邀请码过期处理**：定时任务检查过期邀请码，自动更新状态；验证时也要检查过期时间

17. **邀请码删除策略**：有使用记录的邀请码建议软删除（禁用+设置过期），保留历史数据；未使用的可以硬删除

18. **过期时间设置**：创建和更新邀请码时，要验证 `valid_until` 必须大于 `valid_from`，过期时间不能早于当前时间（除非是禁用操作）

19. **优惠券过期时间**：创建和更新优惠券时，要验证 `valid_until` 必须大于 `valid_from`，过期时间不能早于当前时间（除非是禁用操作）

20. **优惠券使用条件限制**：
    - usage_conditions JSON数据要验证格式和内容有效性
    - 地点限制：验证地点列表不为空（如果设置了地点限制）
    - 时间限制：验证时间段格式正确，start < end
    - 任务类型限制：验证任务类型列表不为空（如果设置了类型限制）
    - 金额限制：验证 min_task_amount <= max_task_amount（如果都设置了）
    - 使用前要完整验证所有条件，不能遗漏任何限制

21. **优惠券验证性能**：使用条件限制验证可能涉及多个检查，要注意性能优化，使用索引和缓存

22. **时区处理**：时间限制验证要考虑时区问题，统一使用服务器时区或用户时区

23. **管理员积分修改**：
    - 修改用户积分时要验证操作合法性，防止恶意操作（如设置负数、过大数值等）
    - 所有修改操作都要记录操作原因和管理员ID，便于审计
    - 减少积分时要检查余额是否足够，防止余额变为负数
    - 设置积分时要计算差值，正确更新total_earned和total_spent

24. **批量发放性能**：
    - 批量发放操作要考虑性能，大批量（>1000用户）时使用异步处理，避免阻塞
    - 使用队列或后台任务处理异步发放
    - 分批处理，每批处理一定数量用户，避免长时间占用资源

25. **批量发放事务**：
    - 批量发放时每个用户的发放操作要独立事务，失败不影响其他用户
    - 记录每个用户的发放状态（成功/失败），支持重试失败操作
    - 更新发放任务的总统计（success_count, failed_count）

26. **发放任务状态管理**：
    - 异步发放任务要正确更新状态（pending -> processing -> completed/failed）
    - 支持查询发放进度（已完成/总数）
    - 支持查看失败用户列表和失败原因
    - 支持重试失败操作

27. **用户类型筛选**：按用户类型发放时，要正确查询用户类型字段，确保筛选准确

---

## ✅ 开发检查清单

### 数据库
- [ ] 创建所有相关表（优惠券、积分、签到、邀请码、管理员发放记录、设备指纹、风控记录、推广码、审计日志）
- [ ] 修改users表添加invitation_code_id字段（引用invitation_codes.id，不是code）
- [ ] **统一字段类型**：
  - [ ] 所有金额字段改为 `BIGINT`（最小货币单位），包括 `points_accounts.balance/total_earned/total_spent`
  - [ ] 所有时间字段改为 `TIMESTAMPTZ`（带时区），包括所有 `created_at/updated_at`
  - [ ] 所有ID字段改为 `BIGSERIAL`
- [ ] **多态字段拆分**：
  - [ ] `check_in_rewards` 使用 `points_reward BIGINT` 和 `coupon_id BIGINT`，移除 `reward_value DECIMAL`
  - [ ] 添加CHECK约束确保一致性
- [ ] **优惠券折扣值统一**：
  - [ ] 折扣券使用基点（basis points）：1000 bp = 10%
  - [ ] 在表注释和API示例中统一说明
- [ ] **移除type=new_user**：
  - [ ] 统一使用 `eligibility_type='new_user'`
- [ ] 创建不区分大小写的唯一索引（LOWER(code)）
- [ ] **并发护栏**：
  - [ ] `coupon_redemptions` 添加部分唯一索引：`CREATE UNIQUE INDEX ... WHERE status = 'reserved'`
- [ ] **唯一约束优化**：
  - [ ] `user_coupons` 移除 `UNIQUE(user_id, coupon_id, obtained_at)`，通过 `idempotency_key` 和业务层校验
- [ ] 创建索引和外键
- [ ] 添加数据验证约束（CHECK约束、唯一约束）
- [ ] 添加系统设置项
- [ ] 初始化签到奖励规则（使用整数）

### 后端
- [ ] 创建SQLAlchemy模型
- [ ] 创建Pydantic Schema
- [ ] 实现CRUD操作
- [ ] 实现积分API
- [ ] 实现优惠券API
- [ ] 实现优惠券使用条件限制验证逻辑
- [ ] 实现优惠券叠加规则和计算逻辑
- [ ] 实现管理员优惠券管理API（创建、更新、删除）
- [ ] 实现设备指纹生成和识别
- [ ] 实现风控系统（风险评分、行为检测）
- [ ] 实现签到API
- [ ] 实现管理员配置API
- [ ] 实现邀请码管理API
- [ ] 实现用户详情管理API
- [ ] 实现修改用户积分API
- [ ] 实现批量发放积分/优惠券API
- [ ] 实现发放任务查询API
- [ ] 实现异步批量发放任务处理
- [ ] 集成任务支付
- [ ] 实现积分自动发放
- [ ] 实现签到奖励发放逻辑
- [ ] 实现邀请码注册奖励发放逻辑
- [ ] 修改注册接口支持邀请码
- [ ] 添加定时任务

### 前端
- [ ] 积分账户页面
- [ ] 优惠券中心页面
- [ ] 优惠券使用条件限制显示
- [ ] 管理员优惠券管理页面（创建、编辑、设置使用条件）
- [ ] 签到页面
- [ ] 管理员配置页面
  - [ ] 积分系统配置
  - [ ] 优惠券系统配置
  - [ ] 签到系统配置
  - [ ] 签到奖励规则管理
- [ ] 邀请码管理页面
  - [ ] 邀请码列表
  - [ ] 创建/编辑邀请码
  - [ ] 邀请码详情和统计
  - [ ] 使用邀请码的用户列表
- [ ] 用户详情管理页面
  - [ ] 用户搜索
  - [ ] 用户详情展示
  - [ ] 修改用户积分功能
  - [ ] 数据导出
- [ ] 批量发放管理页面
  - [ ] 批量发放积分界面
  - [ ] 批量发放优惠券界面
  - [ ] 发放任务列表和详情
  - [ ] 发放进度显示
- [ ] 任务支付集成

---

## 📎 附录

### A. 历史设计参考（已废弃）

#### A.1 提现风控（已禁用）

**注意：当前系统积分严格禁止提现和转账，以下为历史设计参考（已废弃）**

**KYC验证：**
- 身份验证（身份证、护照等）
- 地址验证
- 银行账户验证

**黑白名单：**
- 黑名单：禁止提现的用户/设备/IP
- 白名单：可信用户快速提现

**限额控制：**
- **首次提现延迟**：首次提现需要等待24-48小时（人工审核）
- **单笔限额**：单次提现金额上限
- **单日限额**：每日提现金额上限
- **单月限额**：每月提现金额上限

**高风险检测：**
- **高风险国家/区域限制**：禁止或限制特定国家/地区的提现
- **资金来源校验**：验证积分来源是否正常
- **异常策略触发**：异常行为触发人工复核

**重要说明：** 以上内容仅为历史设计参考，当前系统已完全禁用提现功能，积分仅可用于抵扣平台侧费用、兑换自营商品和折扣券，不可提现、不可转账、不可用于向第三方付款（合规要求）。
- [ ] 注册页面集成邀请码
- [ ] 通知和提示
- [ ] 多语言支持

### 测试
- [ ] 单元测试
- [ ] 集成测试
- [ ] 安全测试
- [ ] 性能测试

### 文档
- [ ] API文档
- [ ] 用户使用文档
- [ ] 管理员操作文档

---

**开发日期：** 2024年1月
**最后更新：** 2025年1月
**状态：** 规划中

