# 社区限时问答（用户提议题目）（User-Submitted）设计稿

**日期**: 2026-05-18
**作者**: brainstorming with @zixiong316
**状态**: 设计待 review
**前置依赖**:
- `2026-05-13-ai-qa-bounty-design.md` (P0 必须先上线)
- `2026-05-18-ai-qa-sponsor-pledge-design.md` (可独立,但 carry-over / 加注池逻辑互不影响)

## 1. 背景与目标

P0 + cycle (P1) 两条题目来源都是 admin 主导（AI 出题或 admin 手填），用户面称"**AI 限时问答**"。本 spec 开**第三条题目来源**：**任何 Link2Ur 已注册用户都可付费提议一道题**，admin 一键审核通过 / 拒绝。这条路径用户面叫"**社区限时问答**"——不带 AI 标签，强调"社区共创"。通过后题目走 P0 标准流程（用户答题 → AI 评分 → admin 终审 → settle 发奖），跟 AI 限时问答在**同一列表展示**但**卡片视觉不同**便于一眼分辨。

**目标**：
- 用户感觉"我也能开题"——自助、有归属感
- 付费门槛筛掉垃圾提议（不需要复杂防刷机制）
- admin 审核压力低（只决"做不做"，不动题面）
- 通过的题挂"由 @username 提议" 显式署名，给用户曝光感

### 不是什么

- **不是免费建议箱**：用户提议要付钱（£10-£100 base pool），筛掉随手乱提。
- **不是 P2P 悬赏**：通过后题目走标准 AI 限时问答流程，奖金按 P0 算法分给所有答主（**不是给指定答主**）。
- **不是 admin 不审核**：所有用户提议必须 admin 通过才上线，避免垃圾/政治/广告题目。

### 已有相关基础设施

- 全部复用 P0 spec 基础设施 + sponsor spec 的混合付款流程（钱包余额 + Stripe 卡支付差额）。
- `crud/audit.py`：每次 submit / approve / reject / withdraw / refund 都写 audit log。
- `wallet_service.debit_wallet` / `credit_wallet`：用户付费走 debit；拒绝/撤回退款走 credit。

## 2. 核心产品规则

| 项目 | 规则 |
|---|---|
| 谁能提议 | 任何已注册 Link2Ur 用户（无 expert / VIP 门槛）|
| 提议费用 | 用户自付 base pool £10-£100（DB CHECK 1000 ≤ reward_pool_pence ≤ 10000）|
| 资金时机 | 提交时**立即 debit**（commitment 性质）；拒绝 / 用户撤回 → credit_wallet 全额退到提议者钱包 |
| 资金路径 | 钱包余额优先 debit；不足部分走 Stripe 卡支付差额（**复用 sponsor spec §4.1 的混合付款流程**）|
| 审核方式 | admin 看队列 → 一键通过 / 拒绝（**不动题面、不动奖金池、不动截止时间**）|
| 通过后状态 | 题目变 `published`，走 P0 标准流程；用户提议者**自己不能答**（避免自问自答）|
| 拒绝理由 | admin 必填 `reason_code`（preset enum: off_topic / duplicate / violation / quality_low / other）+ 可选自由备注 `reason_detail`。**两者都展示给提议者**（在"我的提议"页面）|
| 题面署名 | 题目详情页 hero 显式 "由 @username 提议 · 社区限时问答 #N"，提议者头像并列在出题方信息区 |
| 视觉区分 (vs AI 限时问答) | **AI 路径**: 金色 hero (#FFD700 → #FFAA00) + 🤖 角标。**社区路径**: 蓝色 hero (#007AFF → #409CFF) + 💡 角标 + 提议者小头像。列表卡同样视觉分组（金 vs 蓝），首页瀑布流混合展示 |
| 防滥用 | **不做 rate limit / 信誉机制**——付费门槛（£10 起步）已足够过滤；上线后看数据再加 |
| 用户每天提议数 | 无硬限制（付费门槛兜底）|
| 用户撤回 | 仅 `pending_review` 状态可撤；撤回 → status='withdrawn' + 全额退款 |
| Admin 撤稿 | 通过后题目变 `published`，admin 仍可走 P0 cancel 流程；canceled 时钱按 P0 + sponsor 逻辑处理（**钱不退回提议者**——这是平台 + 提议者共同的奖金，进加注池 carry over）|
| 用户提议者收益 | 题目 settled 时**不分提议者额外奖金**——他付的钱就是池子，按 P0 算法分给所有答主。提议者获得：①题目署名曝光 ②"我提议被采纳"成就感（profile 可加勋章，P1 阶段）|

### 2.1 关键约束（用户提议者不能答自己提议的题）

防止 "用户 A 提议 → admin 通过 → A 自己答 + 同伙刷低分 → A 拿大头" 这种自肥模式：

- `/api/ai-qa/{qid}/answer` 端点校验：若 `ai_questions.submitted_by_user_id == current_user.id` → 拒 403 `ai_qa_self_submission_cannot_answer`
- 同设备多账号 → 已有 risk_control 风控覆盖
- 关联检测（提议者 + 高分答主关系，如 Stripe 收款同一银行） → 不在本 spec 范围，依赖现有平台风控

### 2.2 跟现有 cycle / draft 路径并列

P0 spec §2 表"题目来源" 一行扩展：

| 路径 | 用户面命名 | 卡片视觉 | 后端字段判定 |
|---|---|---|---|
| ① Cycle (P1): admin 配 prompt + AI 出候选 + admin 审 | **AI 限时问答** | 金色 + 🤖 角标 | submitted_by_user_id IS NULL + cycle_config_id IS NOT NULL |
| ② Draft 手填 (P0): admin 直接写题 | **AI 限时问答** | 金色 + 🤖 角标 | submitted_by_user_id IS NULL + cycle_config_id IS NULL |
| ③ User-submitted (本 spec): 用户付费提议 + admin 审 | **社区限时问答** | 蓝色 + 💡 角标 + 提议者头像 | submitted_by_user_id IS NOT NULL |

3 条路径**共用同一个 ai_questions 表** + **同一套 published 后流程** + **同一个用户答题/评分/settle 机制**——区别仅在 ① 用户面命名 ② 卡片视觉调子。后端模型完全统一，前端 derived type 根据 `submitted_by_user_id` 判断展示哪种皮肤。

## 3. 数据模型

### 3.1 ai_questions 表加 5 字段

```sql
ALTER TABLE ai_questions
  ADD COLUMN submitted_by_user_id  VARCHAR(8) REFERENCES users(id),
    -- NULL = admin draft 或 cycle 路径;非 NULL = 用户提议
  ADD COLUMN submitted_at          TIMESTAMPTZ,
  ADD COLUMN rejected_at           TIMESTAMPTZ,
  ADD COLUMN rejected_reason_code  VARCHAR(30),
    -- enum: off_topic | duplicate | violation | quality_low | other
  ADD COLUMN rejected_reason_detail TEXT,
  ADD COLUMN withdrawn_at          TIMESTAMPTZ;

-- 索引: admin 查待审队列
CREATE INDEX idx_ai_questions_pending_review
  ON ai_questions(submitted_at)
  WHERE status = 'pending_review';

-- 索引: 用户查"我的提议"
CREATE INDEX idx_ai_questions_submitted_by_user
  ON ai_questions(submitted_by_user_id, submitted_at DESC)
  WHERE submitted_by_user_id IS NOT NULL;
```

### 3.2 status 枚举扩展（共 13 个状态）

旧 10 个 + 新 3 个：

```
pending_review  -- 用户提议后,等 admin 审
rejected        -- admin 拒绝,终态;钱已退
withdrawn       -- 用户撤回,终态;钱已退
```

更新后完整状态机：

```
             ┌── admin 手填 draft 路径 ────────► draft ──发布──┐
             │                                                  ▼
candidate ──admin 选中+publish─────────────────────────────► published ──admin 撤稿──► canceled (终态)
             │                                                  │
user submit ──┐                                                 │ deadline 到
              │                                                 ▼
              └► pending_review ──┬─ admin approve ──► (并入 published)
                                  │
                                  ├─ admin reject ──► rejected (终态,退款)
                                  │
                                  └─ user withdraw ──► withdrawn (终态,退款)

                                              closed ─► closed_empty / scoring → scored → settled (终态)
```

### 3.3 状态语义补充

| 状态 | 含义 | 转入 | 可去 |
|---|---|---|---|
| `pending_review` | 用户提议 + 已付费,等 admin 审核 | 用户 submit | published (approve) / rejected (admin reject) / withdrawn (user withdraw) |
| `rejected` | admin 拒绝 (终态) | pending_review | (退款已完成,无后续) |
| `withdrawn` | 用户主动撤回 (终态) | pending_review | (退款已完成,无后续) |

### 3.4 钱包流水的 source

- 用户付费提交: `source='ai_qa_submission_paid'`, `related_type='ai_question'`, `related_id=qid`, `idempotency_key='ai_qa_submit_{user_id}_{nonce}'`
- 拒绝退款: `source='ai_qa_submission_refund'`, `related_type='ai_question'`, `related_id=qid`, `idempotency_key='ai_qa_refund_{qid}_{user_id}'`
- 撤回退款: 同 refund

## 4. 业务流程

### 4.1 用户提议

```
用户在"我来提议一道题"入口（profile / 列表页底部按钮）
   ↓
打开表单页 (ai_qa_user_submit_view):
   - 题面 input (max 200 字)
   - 题干描述 textarea
   - topic_tag dropdown (复用 P0 enum)
   - target_forum_category_id dropdown
   - 截止时长 (建议 7 天,可选 3/7/14 天)
   - base pool (£10-£100, 滑块 + 自定义)
   - "提交需付款 £X.XX" 提示 + "拒绝/撤回全额退款"
   ↓
点 "提交" → POST /api/ai-qa/submit
   ↓
后端事务:
   1. 校验题面 + base pool 范围
   2. lock_wallet(user_id, GBP) 行锁
   3. debit_wallet(amount=reward_pool_pence/100, source='ai_qa_submission_paid', idempotency_key=...)
      - 钱包不够 → 走混合付款 fallback (sponsor spec §4.1 流程)
      - 全额 debit 成功 → 继续
   4. INSERT ai_questions (status='pending_review', submitted_by_user_id, submitted_at=NOW(),
                            reward_pool_pence=用户付的金额,
                            posed_by_expert_id=SystemSettings['ai_qa_default_expert_id'])
   5. audit log
   6. 通知 admin "新用户提议待审"
   ↓
返回 {qid, status='pending_review', wallet_charged_pence, stripe_charged_pence}
   ↓
前端跳"我的提议"页,显示该题 pending 状态
```

### 4.2 用户撤回

```
用户在"我的提议"页看到 pending_review 题
   ↓
点 "撤回提议" 按钮
   ↓
弹窗确认: "撤回后题目从队列删除,你的 £X.XX 会退回钱包"
   ↓
DELETE /api/ai-qa/submissions/{qid}
   ↓
后端事务:
   1. 校验题目存在 + status='pending_review' + submitted_by_user_id = current_user.id
   2. lock_wallet 行锁
   3. credit_wallet(amount, source='ai_qa_submission_refund', idempotency_key='ai_qa_refund_{qid}_{user_id}')
   4. UPDATE ai_questions.status='withdrawn', withdrawn_at=NOW()
   5. audit log
   ↓
返回 {refunded_pence}
   ↓
前端刷新页面,显示该题已撤回
```

### 4.3 admin 审核

```
admin 在 /admin/ai-qa/submissions 看待审队列 (按 submitted_at 升序)
   ↓
点单道题 → 看题面 + 提议者 + base pool + topic_tag
   ↓
左下角两个按钮: [✓ 通过] / [✗ 拒绝]
   ↓
拒绝点击 → 弹窗:
   - reason_code dropdown (off_topic / duplicate / violation / quality_low / other)
   - reason_detail textarea (可选,500 字内)
   - 提示: "用户会在'我的提议'页看到这个理由 + 退款 £X.XX 自动到钱包"
   ↓
通过点击 → POST /api/admin/ai-qa/submissions/{qid}/approve
   后端:
     1. 校验 status='pending_review'
     2. UPDATE status='published', published_at=NOW()
        (deadline 不变,跟用户提交时填的一致;edit_lock_at = deadline - 1h)
     3. audit log
   ↓
拒绝 → POST /api/admin/ai-qa/submissions/{qid}/reject body: {reason_code, reason_detail?}
   后端事务:
     1. 校验 status='pending_review' + reason_code 在 enum 中
     2. credit_wallet 退款 (idempotency_key='ai_qa_refund_{qid}_{user_id}')
     3. UPDATE status='rejected', rejected_at=NOW(), rejected_reason_code, rejected_reason_detail
     4. audit log
   ↓
通知提议者 "你的提议已被通过/拒绝" + 拒绝时附 reason
```

### 4.4 通过后 published 流程

完全跟 P0 一致。**唯一差别**：
- `/api/ai-qa/{qid}/answer` 校验：若 `submitted_by_user_id == current_user.id` → 拒 403
- 详情页 hero 区显示"由 @{user_name} 提议"+ 提议者头像
- `posed_by_expert_id` 仍填 SystemSettings 默认 official Expert（保证 NOT NULL 约束兼容）
- 通过后题目跟 admin draft / cycle 题在 published 队列里**无差别**，admin cancel / scoring / settle 都走 P0 流程

## 5. API 设计

### 5.1 用户端

```
POST   /api/ai-qa/submit                   提议一道题
                                            body: {title, content, topic_tag?, target_forum_category_id,
                                                   deadline, reward_pool_pence (1000-10000)}
                                            钱包够: 直接 debit + 创建 pending_review,返:
                                              {qid, wallet_used_pence, stripe_amount_pence: 0}
                                            钱包不够: 混合付款 fallback,返:
                                              {wallet_used_pence, stripe_amount_pence, stripe_payment_intent_client_secret}

DELETE /api/ai-qa/submissions/{qid}        撤回提议（仅 pending_review + 自己的）
                                            返: {refunded_pence}

GET    /api/ai-qa/my-submissions           我的提议列表（含审核状态 + 拒绝理由）
                                            返: [{qid, title, status, submitted_at, base_pool_pence,
                                                  rejected_reason_code?, rejected_reason_detail?,
                                                  published_at?, ...}, ...]
                                            含所有状态: pending_review / published / canceled / closed /
                                                       closed_empty / scoring / scored / settled / rejected / withdrawn
```

### 5.2 Admin 端

```
GET    /api/admin/ai-qa/submissions        待审队列（按 submitted_at 升序）
                                            返: [{qid, title, content, topic_tag,
                                                  submitted_by_user_id, submitted_by_user_name,
                                                  submitted_at, reward_pool_pence, deadline,
                                                  target_forum_category_id, days_waiting (now - submitted_at)}, ...]

POST   /api/admin/ai-qa/submissions/{qid}/approve     通过
                                            前置: status='pending_review'
                                            后置: status='published', published_at=NOW()
                                            返: {qid, status: 'published'}

POST   /api/admin/ai-qa/submissions/{qid}/reject      拒绝
                                            body: {reason_code: enum, reason_detail?: string}
                                            前置: status='pending_review'
                                            后置: status='rejected', rejected_at=NOW(),
                                                  reason_code/detail 写入, credit_wallet 退款
                                            返: {qid, status: 'rejected', refunded_pence}
```

### 5.3 端点统一规范

所有写操作端点都接现有 audit_log，action_type 命名：
- `ai_qa_user_submit` / `ai_qa_user_withdraw` / `ai_qa_admin_approve` / `ai_qa_admin_reject`

## 6. 前端落地

### 6.1 Flutter

新模块 `lib/features/ai_qa/views/ai_qa_user_submit_view.dart`：
- form 类似 admin draft 表单（参考 P0 mockup A3 草稿管理）
- 关键差异：
  - base pool 是用户付费,放在最上方显眼
  - 实时显示 "提交需付款 £X.XX"
  - 提交按钮 "支付 £X.XX 并提交提议"
  - 钱包不足走 sponsor spec M9 的混合付款 dialog（共享 widget）

新模块 `lib/features/ai_qa/views/ai_qa_my_submissions_view.dart`：
- 列表 grouped by status (pending / approved / rejected / withdrawn)
- 每条显示 title + status pill + submitted_at + base_pool_pence
- rejected 行展开显示 reject_reason_code + reason_detail + "已退款 £X.XX"
- pending_review 行有"撤回"按钮

详情页 (`ai_qa_detail_view.dart`) 改动：
- **type derived**：根据 `submitted_by_user_id` 判定 isUserSubmitted = true/false
- isUserSubmitted=true (社区限时问答):
  - app bar title: "社区限时问答 · 第 N 期"
  - hero 区主调色: 蓝色渐变（Apple Blue #007AFF → #409CFF）
  - 角标改 💡 替代 🤖
  - hero 区底部加 "由 @{user_name} 提议" + 头像（点击跳 user profile）
- isUserSubmitted=false (AI 限时问答):
  - app bar title: "AI 限时问答 · 第 N 期"
  - hero 区主调色: 金色（#FFD700 → #FFAA00）
  - 角标 🤖
  - 出题方信息: "由 AI 出题 · 平台官方活动"

首页列表 / 双列瀑布流：两种 type 卡片混合排列，视觉区分（金 vs 蓝 + 角标）

入口位置：
- 列表页 (M2) 底部加 "💡 我来提议一道题" 浮动按钮
- profile 页"我的"加入口 "我的提议"

### 6.2 Admin Web

新增页面 `/admin/ai-qa/submissions` (用户提议审核队列)：
- 顶部 badge: 待审 N 道（红色 pill）
- 表格列: ID / 提议者 / 题面 / topic_tag / base pool / 截止 / 等待时长 / 操作
- 每行操作: [查看详情] [✓ 通过] [✗ 拒绝]
- 拒绝弹窗: reason_code dropdown + reason_detail textarea
- 列表按 submitted_at 升序（先提交先审）

侧边栏菜单加 "用户提议审核 (N)" 红色 badge 提示。

## 7. 边界 & 错误处理

| 情况 | 处理 |
|---|---|
| 用户提议时钱包+Stripe 都失败 | 事务回滚,ai_questions 行未创建,无脏数据 |
| 用户撤回但 admin 同时点了通过 (race) | DB lock + 状态二次校验：先到的赢；admin approve 后用户 DELETE 返 409 `ai_qa_submission_already_decided` |
| admin 拒绝时退款失败 | 事务回滚到 pending_review 状态,admin 后台 banner 报警；不强制状态变更,等钱包系统恢复后 admin 重试 |
| 用户提议自己当唯一答主 | `/api/ai-qa/{qid}/answer` 端点拒 403 `ai_qa_self_submission_cannot_answer`,前端"我来答"按钮在该 user 视角下 hide |
| 用户提议通过后想再撤回 | 不允许（已 published）；只能联系客服走人工撤稿（参考 [`feedback_destructive_operations`]）|
| admin 通过后题目被 cancel | 走 P0 cancel 流程：reward_pool_pence (用户付的钱) 进加注池 carry over 下期用；**不退还提议者**（因为题目已经面向公众了,跟其他题一样处理）|
| 提议者被封号 | 退款仍正常（用户 pending 题目自动拒绝并退款）；通过 published 题目继续走 P0 流程 |
| 用户提议 base pool > £100 | DB CHECK 约束拒绝 (reward_pool_pence ≤ 10000); 前端 input max 同步限制 |
| 用户连续提交大量题 | 不限制（付费门槛 £10/题 已足够过滤）；上线后看数据,若需可后期加 rate limit |
| admin 不审核 > 7 天 | 不自动拒绝/退款；admin 队列按 submitted_at 升序，超期题在最顶；P1 可加邮件 escalation 提醒 admin |
| 用户提议的题目方向违规 (敏感/广告) | admin reject + reason_code='violation' + detail 说明；用户能看到理由 |
| 用户重复提交相同题 | 不前端去重 (难判)；admin reject + reason_code='duplicate' |

## 8. 测试策略

### 集成测试

| 端点 | 覆盖 |
|---|---|
| `POST /api/ai-qa/submit` | 校验题面/base pool 范围 + 钱包足够直接 debit + 钱包不足混合付款 + 状态=pending_review + audit log |
| `DELETE /api/ai-qa/submissions/{qid}` | 仅 pending_review + 仅自己 + 退款 + status='withdrawn' + audit log |
| `POST /api/admin/ai-qa/submissions/{qid}/approve` | 前置状态 + 后置 published + published_at + audit log + 通知用户 |
| `POST /api/admin/ai-qa/submissions/{qid}/reject` | reason_code enum 校验 + reason_detail 可选 + 退款 + status='rejected' + audit log |
| `POST /api/ai-qa/{qid}/answer` | 提议者自答拒 403 `ai_qa_self_submission_cannot_answer` |

### 状态机测试

| 路径 | 测试 |
|---|---|
| pending_review → published (approve) | 转移合法 + 时间戳正确 |
| pending_review → rejected | 退款正确 + reason 记录 |
| pending_review → withdrawn | 退款正确 |
| published (用户提议) → canceled | 钱进加注池 (跟普通题一样) |
| published → settled | 正常分钱 (不退给提议者) |
| approved 后用户撤回 | 拒 409 |
| 双并发 approve 同 qid | DB row lock 保证只赢一次 |

### Flutter widget 测试

- `ai_qa_user_submit_view`: form 校验 + base pool 滑块 + 钱包不足走混合付款 dialog
- `ai_qa_my_submissions_view`: 状态分组 + 撤回按钮仅 pending 显示 + rejected 展示理由
- `ai_qa_detail_view`: submitted_by_user_id 非 NULL 时显示提议者署名

### 手动 QA

- 用户 A 提议（£20）→ admin 通过 → 用户 B/C 答题 → A 试答被拒 → settle 正常分钱给 B/C
- 用户 A 提议 → admin 拒绝 → 验证 £20 退到 A 钱包 + A 能看到拒绝理由
- 用户 A 提议 → A 撤回 → 验证退款

## 9. 上线分期建议

| 期 | 内容 |
|---|---|
| **P0-user-submitted (本 spec MVP)** | ai_questions 加 5 字段；3 新 status；用户端 3 端点 + admin 端 2 端点；Flutter 提议表单 + 我的提议页 + 详情页署名；admin 审核队列页 |
| **P1-user-submitted** | admin 审核超 7 天自动 email escalation；提议者勋章（累计 N 道被采纳）|
| **P2-user-submitted** | 用户撤回后允许 admin 在 7 天内"恢复审核"（用户改主意）|

**前置依赖**: AI 限时问答 P0 + sponsor spec 的混合付款流程（共享 wallet+Stripe fallback）。如果 sponsor spec 不上线,user-submitted 需要独立实现混合付款（增量工程量）。

## 10. 风险 & 决策记录

| 风险 | 决策 |
|---|---|
| 用户付费提议但 admin 审核慢导致体验差 | 接受——付费即承诺；P1 加 email escalation；UI 显示"admin 通常 X 天内审核"提示 |
| 用户提议被拒后情绪不爽 | reason_code + detail 双重透明 + 全额退款；客服处理强烈不满 |
| admin 通过后才发现题面有问题 | 走 P0 cancel 流程；钱进加注池不退提议者；用户视角"我提议被采纳后又被取消"——展示 cancel reason 给提议者 |
| 用户提议变成 SEO 工具 (公司提议带品牌题目) | reason_code='violation' 拒；admin 出题原则 §2.3 同样适用 (海外华人场景为主) |
| 用户付费高 → 期望 admin 必须通过 | UI 明确写"付费不等于必通过；不符合方向会被拒+退款"|
| 提议者跟答主串通（提议 + 同伙答 + 评分操控） | L4 风控 + 提议者自答拒 + admin 终审兜底；深度风控依赖现有平台机制 |
| 提议 base pool 跟现金奖金本质一样,法律上算什么 | 跟 sponsor 加注一样：用户行为不算广告 (ASA)；可能算 "user-funded prize pool"——上线前咨询会计师确认 |
| admin 被攻陷 → 攻击者批量通过同伙提议 | S5 周度 cap 同样防御 (settle 时检查); S6 邮件告警 + audit log 留痕 |

## 11. 不在本期范围

- 提议者勋章 / 排行榜 / 累计统计 ——P1
- 提议者额外分成（提议者自动拿题目奖金的 X%）——产品方向决定**不做**（避免自肥模式）
- 用户对其他用户的提议投票（让社区决定 admin 通过哪些）——P2 之后视情况
- 用户撤回后 admin "恢复审核"机制 ——P2
- 提议时 AI 辅助润色题面 ——P2
- admin 通过时编辑题面 ——明确不做（保持"一键审核"语义）
- 自动 reject 关键词过滤（敏感词）——依赖现有论坛 hidden 机制 + admin 人工审

## 附录 A: 相关 spec / memory 引用

- [`2026-05-13-ai-qa-bounty-design.md`](2026-05-13-ai-qa-bounty-design.md) —— AI 限时问答 P0 spec
- [`2026-05-18-ai-qa-sponsor-pledge-design.md`](2026-05-18-ai-qa-sponsor-pledge-design.md) —— sponsor 加注 spec (本 spec 复用其混合付款流程)
- [`feedback_destructive_operations`] —— 通过后撤稿走客服等规则
- [`feedback_db_migration`] —— 编号 SQL migration (本 spec migration 编号待定,当前最新 237 + sponsor 238)
- [`feedback_direct_to_main`] —— solo 项目直推 main
