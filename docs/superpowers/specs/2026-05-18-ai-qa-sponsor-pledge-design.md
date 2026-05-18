# AI 限时问答 · 用户加注（Sponsor Pledge） 设计稿

**日期**: 2026-05-18
**作者**: brainstorming with @zixiong316
**状态**: 设计待 review
**前置依赖**: `2026-05-13-ai-qa-bounty-design.md` (P0 已 spec, 含分配算法重写)

## 1. 背景与目标

P0 spec 里 AI 限时问答的奖金池只由平台单边出资（默认 £10/期）。本 spec 增加 **用户加注（pledge）机制**：任何 Link2Ur 已注册用户都可从自己 `WalletAccount.balance` 拿钱加进某道题的奖金池——既能"我也想看大家答这个"表达 endorsement，又能让公司账号通过加注获得社区曝光（无广告 push）。

**目标**：
- 让奖金池规模随社区兴趣浮动（受关注题 → 更多加注 → 更大池子）
- 给公司/品牌账号一个低调的"刷存在感"通路，**不引入广告位**
- 加注资金一旦投入不退还（题目 canceled/closed_empty 时进全局加注池 carry over 到下一期）

### 不是什么

- **不是 B2B 广告系统**：没有 logo 突出位、没有跳转链接、没有 CTA。公司账号跟普通用户视觉上一样。
- **不是众筹平台模式**：加注无 reward tier、无 unlock 机制、无 stretch goal。
- **不是 P2P 打赏**：钱进总池子按 P0 算法（按 final_score 比例 + floor 抹零）分给所有答主，**不是给特定答主**。

### 已有相关基础设施

- **Wallet 钱包体系** (`wallet_models.py` + `wallet_service.py`)：用户余额已存在；加注走 `debit_wallet(source='ai_qa_pledge')`；P0 settle 走 `credit_wallet(source='ai_qa_reward')`。
- **任务支付现有流程**：钱包余额不足时已有 "钱包用一部分 + Stripe 直接支付差额" 的混合支付 fallback 逻辑（参考 `payment_inline_routes.py`）。**平台不支持用户主动充值钱包**——钱包只接收 settle 奖金作为"未提现收入"。加注复用任务支付的混合 fallback。
- **AuditLog** (`crud/audit.py`)：每次加注 / carry over / 退款都写一条 audit。
- **现有论坛 like/favorite 机制**：答案是 ForumPost，自带 like/favorite，无需在 sponsor spec 内新加。

## 2. 核心产品规则

| 项目 | 规则 |
|---|---|
| 加注人 | 任何已注册的 Link2Ur 用户（含外部公司用户、Expert team 用户、普通用户）|
| 资金来源 | 优先用 `WalletAccount.balance`（未提现奖金累积），不足部分直接 Stripe 支付；**钱包不支持主动充值**（复用任务支付的混合支付流程，跟现有任务付费一样） |
| 单笔加注 | **£1 - £100**（DB CHECK 100 ≤ amount_pence ≤ 10000）|
| 单题加注上限 | **总加注 ≤ £1000**（sponsor_pool_pence ≤ 100000，含 carry_over）|
| 加注时机 | 题目 `status = 'published'` 时；deadline 之前；不要求 edit_lock_at（加注跟编辑答案无关）|
| 是否可撤回 | **否**——一旦 debit 不可逆；加注是 commitment |
| 退款机制 | 仅 `canceled` / `closed_empty` 触发：所有加注资金（含本期 sponsor + 前期 carry_over）**不退给用户**，进**全局加注池** `ai_qa_pledge_pool`，下一期 publish 时自动 carry over |
| 曝光形态 | 题目详情页底部"加注支持者"列表：头像 + 名字 + 单笔总额（同人多次合并）按总额降序；公司账号视觉跟普通用户一致 |
| 奖金池展示 | 题目页拆分显示：`£10 平台金 + £45 来自支持者 = £55 总池`（含 carry_over 部分） |
| 点赞 / 收藏 | 加注不触发；答案是 ForumPost，自带论坛 like/favorite UI（详情页直接复用），跟加注无关 |
| 与 P0 分配算法关系 | reward_pool_pence 增大 → distribute_pool 自动算 → 更多答主能高于 floor 拿到钱（参考 P0 spec §2.1 新算法） |

### 2.1 加注资金流水

每笔加注一条 `ai_qa_pledges` 行 + 一条 `wallet_transactions` 行（idempotency_key=`ai_qa_pledge_{ai_question_id}_{user_id}_{nonce}`）。

举例（user U1 给题 Q34 加注 £5）：
1. 前端 `POST /api/ai-qa/{34}/pledge {amount_pence: 500}`
2. 后端事务里：
   - `wallet_service.lock_wallet(U1, GBP)` 行锁
   - `wallet_service.debit_wallet(U1, 5.00, source='ai_qa_pledge', related_type='ai_question', related_id=34, idempotency_key='ai_qa_pledge_34_U1_<uuid>')`
   - INSERT `ai_qa_pledges(ai_question_id=34, sponsor_user_id=U1, amount_pence=500, wallet_transaction_id=<tx>, status='active')`
   - UPDATE `ai_questions.reward_pool_pence += 500`
   - UPDATE `ai_questions.sponsor_pool_pence += 500`
   - audit log
3. 钱包不足 → 调任务支付的混合付款 fallback：
   - 后端算出 wallet 用 X、Stripe 直付差额 Y (Y = amount - X)
   - 返 200 + body {wallet_used_pence: X, stripe_amount_pence: Y, stripe_payment_intent_client_secret}
   - 前端用 Stripe.js confirmPayment 拉起卡支付，成功后 webhook 一次性同时：debit wallet X + 写 ai_qa_pledges + UPDATE 池子（同事务 idempotency_key 防重）
   - **不走"先充值钱包再扣"的两步逻辑**

### 2.2 退款 / Carry Over 逻辑

题目 `status` 切到 `canceled` 或 `closed_empty` 时（在原 cancel 端点 + close beat 任务里加挂钩）：

```
for pledge in ai_qa_pledges WHERE ai_question_id = X AND status = 'active':
    pledge.status = 'carried_over'

# 把整个 sponsor + carry_over 部分进全局池
amount_to_pool = ai_questions.sponsor_pool_pence + ai_questions.pledge_pool_carryover_pence
if amount_to_pool > 0:
    ai_qa_pledge_pool.balance_pence += amount_to_pool
    INSERT ai_qa_pledge_pool_transactions(type='credit', amount_pence=amount_to_pool,
                                          balance_after=..., related_ai_question_id=X)
    audit log
```

新题 publish 时：

```
# 全量 carry over (用户决策: 简单直接)
current_pool_balance = ai_qa_pledge_pool.balance_pence
if current_pool_balance > 0:
    ai_questions.pledge_pool_carryover_pence = current_pool_balance
    ai_questions.reward_pool_pence += current_pool_balance
    ai_qa_pledge_pool.balance_pence = 0
    INSERT ai_qa_pledge_pool_transactions(type='debit', amount_pence=current_pool_balance,
                                          balance_after=0, related_ai_question_id=new_qid)
    audit log
```

**关键约束**：admin publish 时 UI 提示"加注池余额 £X.XX，将并入新题"，admin 看得到但**无权拒绝**——这部分钱必须用掉，不能留在加注池积累。

### 2.3 上限触发

- 单笔加注 > £100 → 前端拒（input max=10000） + 后端 DB CHECK 拒
- 单题总加注 ≥ £1000（sponsor_pool_pence 触上限）→ 前端"加注"按钮 disabled + tooltip "本题加注已达 £1000 上限" + 后端 409 `ai_qa_pledge_cap_reached`
- 单笔加注会让总加注超 £1000（如已 £950 还想加 £100）→ 后端拒 + 错误码 `ai_qa_pledge_would_exceed_cap`，建议金额返回 £50（剩余空间）

## 3. 数据模型

### 3.1 新表

```sql
-- ========== 1. ai_qa_pledges (每笔加注流水) ==========
CREATE TABLE ai_qa_pledges (
    id              SERIAL PRIMARY KEY,
    ai_question_id  INT NOT NULL REFERENCES ai_questions(id) ON DELETE CASCADE,
    sponsor_user_id VARCHAR(8) NOT NULL REFERENCES users(id),
    amount_pence    INT NOT NULL CHECK (amount_pence BETWEEN 100 AND 10000),  -- £1-£100/笔
    wallet_transaction_id BIGINT,        -- 关联 wallet_transactions.id;不加 FK 防跨库
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
                    -- active | carried_over (canceled/closed_empty 后)
    carried_over_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_qa_pledges_question ON ai_qa_pledges(ai_question_id);
CREATE INDEX idx_ai_qa_pledges_sponsor ON ai_qa_pledges(sponsor_user_id);

-- ========== 2. ai_qa_pledge_pool (全局加注池, singleton) ==========
CREATE TABLE ai_qa_pledge_pool (
    id              INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- singleton enforce
    balance_pence   INT NOT NULL DEFAULT 0 CHECK (balance_pence >= 0),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
-- 初始化:
INSERT INTO ai_qa_pledge_pool (id, balance_pence) VALUES (1, 0) ON CONFLICT DO NOTHING;

-- ========== 3. ai_qa_pledge_pool_transactions (加注池流水) ==========
CREATE TABLE ai_qa_pledge_pool_transactions (
    id              SERIAL PRIMARY KEY,
    type            VARCHAR(20) NOT NULL CHECK (type IN ('credit', 'debit')),
                    -- credit: canceled/closed_empty 钱进池;debit: 新题 publish 时用掉
    amount_pence    INT NOT NULL CHECK (amount_pence > 0),
    balance_after   INT NOT NULL CHECK (balance_after >= 0),
    related_ai_question_id INT REFERENCES ai_questions(id),
    description     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_qa_pledge_pool_tx_question ON ai_qa_pledge_pool_transactions(related_ai_question_id);
```

### 3.2 现有表改动

```sql
-- ai_questions 加 2 字段(拆分奖金池来源)
ALTER TABLE ai_questions
  ADD COLUMN sponsor_pool_pence INT NOT NULL DEFAULT 0
    CHECK (sponsor_pool_pence BETWEEN 0 AND 100000),  -- 用户加注累计
  ADD COLUMN pledge_pool_carryover_pence INT NOT NULL DEFAULT 0
    CHECK (pledge_pool_carryover_pence BETWEEN 0 AND 1000000);
    -- carry_over 没有 cap,因为如果加注池积累很多必须 carry 出来

-- 含义:
-- reward_pool_pence = platform_base + sponsor_pool_pence + pledge_pool_carryover_pence
-- 前端展示时可拆: platform_base = reward_pool_pence - sponsor_pool_pence - pledge_pool_carryover_pence
```

### 3.3 字段语义

| 字段 | 来源 | 何时变 |
|---|---|---|
| `ai_questions.reward_pool_pence` | publish 初始化为 platform_base + pledge_pool_carryover；加注时 += amount | publish / 每次加注 |
| `ai_questions.sponsor_pool_pence` | publish 初始化 0；加注时 += amount | 每次加注 |
| `ai_questions.pledge_pool_carryover_pence` | publish 时一次性 = 加注池余额 | publish |
| `ai_qa_pledges.status` | active → carried_over (canceled/closed_empty) | 题目状态切换时 |
| `ai_qa_pledge_pool.balance_pence` | += sponsor+carryover (canceled/closed_empty); -= 全额 (新题 publish) | canceled/closed_empty/publish |

## 4. 业务流程

### 4.1 用户加注

```
用户在 ai_qa_detail_view 看到题目
   ↓
点击"💰 加注"按钮 (奖金池条右侧)
   ↓
弹出加注弹窗:
   - 预设档位: £1 / £5 / £10 / £20 / £50 (button)
   - 自定义金额 input (1-100)
   - 显示当前余额: "你的钱包: £X.XX"
   - 提示: "加注不可撤回"
   ↓
确认 → POST /api/ai-qa/{qid}/pledge {amount_pence: 500}
   ↓
后端事务校验顺序:
   1. 题目 status = 'published' → 否则 409 `ai_qa_pledge_status_invalid`
   2. now < deadline → 否则 409 `ai_qa_pledge_deadline_passed`
   3. amount_pence 在 100-10000 → 否则 422 `ai_qa_pledge_amount_invalid`
   4. ai_questions.sponsor_pool_pence + amount ≤ 100000 → 否则 409 `ai_qa_pledge_would_exceed_cap` + body 含 max_allowed
   5. lock_wallet(user_id, GBP)
   6. debit_wallet (失败抛 wallet_service.InsufficientBalanceError) → 402 + redirect_url
   7. INSERT ai_qa_pledges
   8. UPDATE ai_questions.reward_pool_pence + sponsor_pool_pence
   9. audit log
   ↓
返回 {pledge_id, new_total_pool_pence, user_remaining_balance}
   ↓
前端刷新奖金池条 + 加注者列表 (新加注者出现在自己头像)
```

**钱包不足 fallback**：
- 后端返 200 + body {wallet_used_pence: 230, stripe_amount_pence: 270, stripe_payment_intent_client_secret: "pi_xxx_secret_xxx"}
- 前端用 Stripe.js confirmPayment 拉起卡支付（Apple Pay / Google Pay / 卡）；成功后 Stripe webhook 回调一次性完成：debit wallet 230 pence + 创建 ai_qa_pledges 行 (amount_pence=500) + UPDATE 池子（同事务 idempotency_key 防重）
- **跟任务支付的混合付款流程完全一致**——平台不引入新的支付路径

### 4.2 Carry Over 流程（canceled / closed_empty）

挂钩到现有 P0 流程：
- **cancel 端点** (`/api/admin/ai-qa/questions/{qid}/cancel`) 末尾加 hook
- **scheduled_tasks.close_expired_ai_questions** beat 任务里, 切 `closed_empty` 时加 hook
- **scheduled_tasks.score_closed_ai_questions** 里, 切 `closed_empty`（全 hidden）时也加 hook

hook 函数：

```python
def carry_over_pledges_to_pool(db: Session, qid: int):
    """题目走 canceled/closed_empty 时,把所有加注 + 前期 carry_over 进全局池。"""
    q = db.get(AiQuestion, qid)
    amount = q.sponsor_pool_pence + q.pledge_pool_carryover_pence
    if amount <= 0:
        return
    # 锁加注池行
    pool = db.execute(select(AiQaPledgePool).with_for_update()).scalar_one()
    pool.balance_pence += amount
    db.add(AiQaPledgePoolTransaction(
        type='credit', amount_pence=amount, balance_after=pool.balance_pence,
        related_ai_question_id=qid,
        description=f"carry_over from question #{qid} (status={q.status})"
    ))
    # 标记所有 active pledge 为 carried_over
    db.query(AiQaPledge).filter_by(ai_question_id=qid, status='active').update(
        {"status": "carried_over", "carried_over_at": datetime.now(timezone.utc)}
    )
    # audit log
    create_audit_log(db, action_type='ai_qa_pledge_carry_over',
                     entity_type='ai_question', entity_id=str(qid),
                     new_value={'amount_pence': amount, 'pool_balance_after': pool.balance_pence})
    db.flush()
```

### 4.3 新题 Publish 时 Consume 加注池

挂钩到 `publish_draft()` + `publish_candidate()` (P1 cycle 路径)：

```python
def consume_pledge_pool_for_new_question(db: Session, q: AiQuestion):
    """publish 时把加注池余额全 carry over 到新题。"""
    pool = db.execute(select(AiQaPledgePool).with_for_update()).scalar_one()
    if pool.balance_pence <= 0:
        return
    amount = pool.balance_pence
    q.pledge_pool_carryover_pence = amount
    q.reward_pool_pence += amount  # 加到总池
    pool.balance_pence = 0
    db.add(AiQaPledgePoolTransaction(
        type='debit', amount_pence=amount, balance_after=0,
        related_ai_question_id=q.id,
        description=f"carry_over to new question #{q.id}"
    ))
    create_audit_log(db, action_type='ai_qa_pledge_carry_consumed',
                     entity_type='ai_question', entity_id=str(q.id),
                     new_value={'amount_pence': amount})
    db.flush()
```

## 5. API 设计

### 5.1 用户端

```
POST   /api/ai-qa/{qid}/pledge          加注
                                         body: {amount_pence: 100-10000}
                                         钱包够: 直接 debit + 创建 pledge,返:
                                            {pledge_id, new_total_pool_pence, new_sponsor_pool_pence,
                                             wallet_used_pence: amount, stripe_amount_pence: 0,
                                             user_remaining_balance_pence}
                                         钱包不够: 拆 wallet + Stripe 混合付款,返:
                                            {wallet_used_pence: <balance>, stripe_amount_pence: <diff>,
                                             stripe_payment_intent_client_secret: "pi_xxx_secret_xxx"}
                                            前端用 Stripe.js confirmPayment → webhook 一次性完成所有写入

GET    /api/ai-qa/{qid}/pledges         本题加注者列表
                                         返: [{user_id, user_name, user_avatar,
                                               total_pledged_pence, latest_pledged_at, pledge_count}, ...]
                                         按 total_pledged_pence 降序;同人多笔合并
                                         上限 100 (够展示)

GET    /api/ai-qa/{qid}                  (扩展 P0 现有端点) 返回值 schema 新增:
                                         sponsor_pool_pence, pledge_pool_carryover_pence,
                                         platform_base_pence (= reward - sponsor - carryover)
```

### 5.2 Admin 端

```
GET    /api/admin/ai-qa/pledge-pool      查看全局加注池余额 + 流水
                                         返: {balance_pence,
                                              recent_transactions: [{type, amount_pence,
                                                                     balance_after, related_qid,
                                                                     created_at}, ...]}

GET    /api/admin/ai-qa/questions/{qid}/pledges    某题加注详情(含未合并的每笔流水)
                                         返: [{id, sponsor_user_id, amount_pence, status,
                                               wallet_transaction_id, created_at, carried_over_at}, ...]
```

**注意**: admin **不能**手动操纵加注池余额（防止 admin 被攻陷直接吞了池子的钱）。只能查看，所有变动通过 carry_over / carry_consumed 自动流转 + audit log 留痕。

## 6. 前端落地

### 6.1 Flutter

新增 BLoC 事件 + state 到 `ai_qa_bloc.dart` (扩展 P0):

```dart
// event
class AiQaPledgeSubmit extends AiQaEvent {
  final int qid;
  final int amountPence;
  const AiQaPledgeSubmit({required this.qid, required this.amountPence});
}

// state 加字段
class AiQaState {
  ...
  final List<AiQaPledger> pledgers;  // 加注者列表(合并后)
  final int sponsorPoolPence;
  final int platformBasePence;
  final int pledgePoolCarryoverPence;
}
```

新 view: `ai_qa_pledge_dialog.dart`
- 弹窗形式 (showModalBottomSheet)
- 预设档位 button (£1/£5/£10/£20/£50)
- 自定义金额 TextField (input formatter 限 100-10000 pence,即 1-100 GBP)
- 展示当前钱包余额: `BlocBuilder<WalletBloc>` 读 balance
- 不足时显示"余额不足，钱包 £X + Stripe 直付 £Y"（不是充值，是直接混合支付）
- 确认 → dispatch AiQaPledgeSubmit
- 处理 402 → 跳 Stripe webview

详情页 (`ai_qa_detail_view.dart`) 改动:
- 奖金池条新增拆分显示 (Q7 决策):
  ```
  £55 总奖池
  └─ £10 平台金 · £35 来自 23 位支持者 · £10 加注池 carry over
  [💰 加注] (button, 右侧)
  ```
- 详情页底部新增"加注支持者"section:
  ```
  ## 加注支持者 (23 人,共 £45)
  [头像] Lily_LDN  · £20  · 2 笔
  [头像] 公寓运营商A · £10 · 1 笔
  [头像] 小Anna   · £5   · 1 笔
  ... (按总额降序,展开"查看全部")
  ```
  - 注: 这部分 UI 用户面叫"加注支持者"或"支持者"; 不叫"赞助商"避免广告联想

### 6.2 Admin Web

新增页面 `/admin/ai-qa/pledge-pool`:
- 顶部卡片: 当前加注池余额 £X
- 流水表格: 时间 / 类型 (credit/debit) / 金额 / 关联题目 / 描述
- 只读, 无操作

题目列表页 (`/admin/ai-qa/questions`) 列表加列: "加注总额 £X (N 人)"

题目终审页 (`/admin/ai-qa/review/:qid`) 表头加: "本题加注 £X (N 笔)"

## 7. 边界 & 错误处理

| 情况 | 处理 |
|---|---|
| 加注用户钱包余额不足 | 后端返混合付款 body (wallet_used + stripe_amount + payment_intent_secret); 前端 Stripe.js 拉起卡支付; webhook 一次性完成 wallet debit + 创建 pledge; idempotency_key 防 webhook 重放 |
| 加注请求重复提交 (前端按钮抖动) | 后端 `ai_qa_pledges` 没强 unique（允许同人多笔），但用 idempotency_key + 前端按钮 throttle 防瞬时双发 |
| 单题加注接近 £1000 但单笔超剩余 | 后端返 `ai_qa_pledge_would_exceed_cap` + body.max_allowed_pence; 前端弹"剩余空间 £X,改为加注 £X?" 让用户调整 |
| canceled 时 sponsor_pool=0 | carry_over hook 直接返 (amount=0); 不写 ai_qa_pledge_pool_transactions |
| 新题 publish 时加注池余额=0 | consume hook 直接返; 不写 ai_qa_pledge_pool_transactions |
| 加注后题目立刻被 admin 撤稿 | 加注者钱**不退**到用户钱包,进加注池. 用户体验上: app 内 banner "本期已取消,你的加注 £X 已转入下期奖金池" |
| 加注池余额大于单题 100000 cap | 全 carry 进新题 (`pledge_pool_carryover_pence` 无 cap); 新题总池 = platform £10 + carry £200 = £210; admin UI 提示"加注池较大,本期池子 £210" |
| 加注用户被封号 | 答题 middleware 拦封号用户,加注也拦同样 middleware (复用 get_current_user_secure_sync_csrf) |
| Stripe 卡支付失败/用户取消 | confirmPayment 返失败 → 前端展示重试按钮;ai_qa_pledges 行**未创建**(webhook 才写),wallet **未 debit**,无脏数据 |
| 系统时钟错乱导致 deadline 误判 | 用 UTC 统一时间,跟 P0 spec 一致 |
| 公司账号买的曝光纠纷（"我加注了为什么不显示"） | 加注者列表上限 100;若加注人数 > 100,只展示按总额降序前 100;尾部加"...还有 N 位支持者"。公司加大额自然排前面 |
| admin 后台被攻陷 → 想偷加注池 | 没有"admin 直接 debit 加注池"端点;只能通过新题 publish 自动 carry over (走正常 settle 给用户); attacker 仍受 S5 周度 settle cap 限制 |

## 8. 测试策略

### 单元测试

| 测试 | 覆盖 |
|---|---|
| `carry_over_pledges_to_pool` | 0 加注 / 有加注 / 含前期 carry_over / 池子流水正确写 |
| `consume_pledge_pool_for_new_question` | 池子非空 carry / 池子=0 跳过 / debit 后 pool 归零 |
| 加注 amount_pence 校验 | 100-10000 范围;100001 拒;0 拒 |

### 集成测试

| 端点 | 覆盖 |
|---|---|
| `POST /api/ai-qa/{qid}/pledge` | 状态校验 + cap 校验 + 钱包足额走 debit 路径 + 钱包不足返混合付款 body + Stripe webhook 完成创建（含 idempotency_key 防重放）+ 成功后 reward_pool_pence/sponsor_pool_pence 正确 + audit log |
| `GET /api/ai-qa/{qid}/pledges` | 同人多笔合并;按总额降序;返字段正确 |
| `cancel + carry_over` | canceled 题加注资金进池子;ai_qa_pledges status → carried_over;audit log;池子余额正确 |
| `closed_empty + carry_over` | beat 任务 close_expired 触发 + 0 答案触发 carry_over hook |
| `publish + consume_pool` | 新题 publish 时加注池余额自动归并 + 新题 reward_pool 正确 + 池子归零 |

### Flutter widget 测试

- `ai_qa_pledge_dialog`: 档位 button 切换 + 自定义金额 + 钱包不足提示
- `ai_qa_detail_view`: 奖金池条拆分显示 + 加注者列表渲染

### 手动 QA（上线前）

- linktest 完整流程: 建题 → 用户加注 £10 → 池子从 £10 涨到 £20 → cancel 该题 → 验证池子余额变 £20 → publish 新题（base £10）→ 验证新题 reward_pool = £30
- 钱包不足时混合付款流程跑通（钱包 X + Stripe Y → webhook 一次性写入）
- 加注超 cap 报错 UI

## 9. 上线分期建议

**前置**: AI 限时问答 P0 必须先上线（本 spec 直接依赖 P0 的 ai_questions / answer / settle 流程）。

| 期 | 内容 |
|---|---|
| **P0-sponsor (本 spec MVP)** | 3 张新表 + ai_questions 加 2 字段；用户加注端点 + 后端 carry_over/consume hook；admin 后台只读页面 (pledge-pool + 题目列表加注列)；Flutter 加注 dialog + 详情页奖金池拆分 + 支持者列表 |
| **P1-sponsor** | 加注者勋章（累计加注 £X → 解锁勋章，跟 L3.c/d 答主勋章并列）；加注排行榜（top sponsor 累计）|
| **P2-sponsor** | 公司账号"赞助回顾"年报（"你今年共加注 £X 给 N 道题"）|

solo 项目直推 main（参考 P0 spec `feedback_direct_to_main`）。

## 10. 风险 & 决策记录

| 风险 | 决策 |
|---|---|
| 用户加注后撤回需求 | **不支持**——加注是 commitment, 防止"先加再撤"试探心理。canceled 走 carry over |
| 加注 = 广告位的滑坡 | 加注者列表无 logo / 无链接 / 公司账号视觉跟普通用户一样;只能靠加注金额排序"刷存在感"。如未来产品方向变, 再开 B2B 广告 feature |
| 加注池余额积累过大 (如 admin 长期不 publish 新题) | 接受——加注池没有 cap, balance_pence 字段是 INT 最大 21 亿 pence = £21M, 足够；新题 publish 时自动归并 |
| 加注被用作洗钱 (用户 A 加注给某题 → admin 终审让用户 A 拿头奖) | L4 风控 + S5 周度 cap + audit log 留痕 + 加注/拿奖关联检测可后期加 |
| 加注用户买 Stripe 失败 → 体验差 | 复用任务支付现有 Stripe fallback (成熟流程); 不在本 feature 新增 Stripe 集成 |
| 加注用户后悔, 客服压力 | 客服话术统一: "加注是承诺, 不退；如本期 canceled 钱会进入下期池子继续用" + 入加注弹窗强提示 "加注不可撤回" |
| 公司账号违规(发广告/拉新)被封号 | wallet 余额冻结由现有风控处理;加注端点拦封号用户(middleware);已加注的钱进加注池, 不退 |
| 加注资金跨 SystemSettings 周度 cap | S5 周度 settle cap 只看 ai_answer_scores.settled_at,不看 sponsor 加注流水。加注本身**不受 cap 限制**(因为不是 admin 操作);settle 时若 reward_pool_pence (含加注) 触发 cap, 会拒发奖 → admin 改 cap 或下期处理 |

## 11. 不在本期范围

- 加注分配给特定答案(P2P 打赏)——保持"全池子按 P0 算法分"
- 加注者奖励(勋章/排行榜)——P1-sponsor
- B2B 广告位(logo / 链接 / CTA)——产品方向决定不做
- 加注的"匿名/实名"切换——默认实名,以后看反馈
- 加注的部分退款机制(碗筷)
- 加注池余额上限——目前不限,担心积累过大时再加 cap
- 加注的赠送/转赠——不做
- 钱包主动充值入口（平台目前**不支持**用户主动充值；钱包余额只来自 settle 奖金累积）

## 附录 A: 相关 spec / memory 引用

- [`2026-05-13-ai-qa-bounty-design.md`](2026-05-13-ai-qa-bounty-design.md) —— AI 限时问答 P0 spec,本 feature 直接依赖
- [`feedback_scheduled_tasks_celery_sync`] —— scheduled_tasks 同步 Celery 包装
- [`feedback_migration_before_deploy`] —— migration 先于代码 push
- [`feedback_db_migration`] —— 编号 SQL migration 文件 (本 spec migration 编号待定, 当前最新 237)
- [`feedback_direct_to_main`] —— solo 项目直推 main
- [`feedback_destructive_operations`] —— 加注不可撤回属于"破坏性操作走规则", 跟 spec §7 一致
