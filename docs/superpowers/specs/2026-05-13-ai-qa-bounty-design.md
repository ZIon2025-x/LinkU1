# AI 限时问答 设计稿

**日期**: 2026-05-13
**作者**: brainstorming with @zixiong316
**状态**: 设计待 review

## 1. 背景与目标

平台希望以 AI 名义定期发布开放式问题，吸引全站用户图文作答，结束后按答案质量发奖金，所有人都能看所有答案——本质上是一个**类知乎的悬赏问答模块**，主要目的是**拉活跃和沉淀 UGC**。

### 已有相关基础设施（不直接复用）

- `OfficialTask` + `OfficialTaskSubmission`：平台发任务 + 用户提交论坛帖 + 拿固定积分。**和本模块语义重叠但模型不够用**（无定时、无 AI 出题、无评分、无现金、奖励定额）。本模块**另起一套**，不扩展 OfficialTask。
- `Expert.is_official=True`：平台官方达人团队（`admin_official_routes.py`）——题目挂名在此。
- `ForumPost`：现有论坛帖模型——**复用为答案载体**。
- `PointsAccount` + `add_points_transaction`：现有积分体系——参与积分走这套。
- `scheduled_tasks.py` + Celery：定时调度——加任务时同步加 Celery 包装（参考 `feedback_scheduled_tasks_celery_sync`）。
- AI 模型配置（参考 `project_ai_model_setup`）：小模型 GLM-4.7-FlashX（出题用），大模型 Claude Sonnet 4.5（评分用，简化输出节省 token）。
- AI prompt 动态编辑（参考 `project_admin_ai_prompt_editor`）：出题/评分 prompt 都从 DB 读，admin 可改。
- `risk_control.check_risk()` + `device_fingerprint.py` + `models.DeviceFingerprint`：现有风控系统——直接接入答题入口，不重造（详见 §4.2 步骤 7、L4 决策）。
- `forum_posts.is_featured` / `is_pinned` 字段：现有论坛精选标记——top 1 答案 settle 时复用，自动进论坛 hot tab（详见 §4.4、L3.b 决策）。
- `crud/audit.py` + `models.AuditLog` 表：现有审计日志系统。所有 admin 写操作（settle / cancel / hide / 改分 / draft publish）必须调 `create_audit_log()` 写入痕迹（详见 §4.4、§5.2、S3 决策）。
- `email_utils.py`：现有邮件发送工具，用于 S6 异常发奖告警。
- `models.SystemSettings`：现有 KV 配置表，用于存 `ai_qa_weekly_settle_cap_pence` 等运行时可调参数。
- **Wallet 钱包体系（`wallet_models.py` + `wallet_service.py` + `/api/wallet/*`）** —— 平台已有完整现金钱包：
  - `WalletAccount` 表：per user per currency，字段 `balance` / `total_earned` / `total_withdrawn` / `total_spent` (DECIMAL(12,2))；UNIQUE(user_id, currency) + CHECK balance ≥ 0
  - `WalletTransaction` 表：每笔流水含 `idempotency_key` UNIQUE 防重，含 `source` / `related_id` / `related_type` 可追溯到 ai_question
  - 关键服务函数：`get_or_create_wallet()` / `lock_wallet()` (行锁) / `credit_wallet()` / `debit_wallet()` / `create_pending_withdrawal()` / `complete_withdrawal()` / `fail_withdrawal()` / `reverse_debit()`
  - 现成端点：`GET /api/wallet/balance` / `GET /api/wallet/transactions` / `POST /api/wallet/withdraw`
- AI 限时问答 settle 时直接调 `wallet_service.credit_wallet(source='ai_qa_reward', related_id=ai_question_id, ...)`——钱进用户 WalletAccount.balance，用户自己在"我的-钱包"页面提现。**不直发 Stripe**。

## 2. 核心产品规则

| 项目 | 规则 |
|---|---|
| 题目来源 | 两条路径：①Cycle 路径：admin 配 direction_prompt + cadence → AI 生 3-5 候选 → admin 审一个 → 发布（P1）  ②Draft 手填：admin 直接写题 → 发布（P0 兜底） |
| 周期 | admin 可配（每周 / 每两周 / 一次性） |
| 用户答题 | 1 用户 1 题 1 答，截止前 1 小时锁编辑（可配） |
| 答案载体 | 一个绑了 `ai_question_id` 的 ForumPost，**论坛流和问答页双露脸** |
| 评分 | AI 简化输出 `{score, off_topic, ai_generated}` + admin 终审改分 |
| 奖金池 | 固定（如 10 GBP），admin 可改 |
| 分配 | 默认 50% 比例公式，封顶 30 人，不足 10 人全员分；可后期切 fixed 模式 |
| 现金落地 | settle 时调 `wallet_service.credit_wallet()` → 钱进用户 `WalletAccount.balance`（DECIMAL，默认 GBP）；流水 `source='ai_qa_reward'` + `related_type='ai_question'` + `related_id=qid` + `idempotency_key='ai_qa_settle_{qid}_{user_id}'` 防双发。**提现**：用户在 Link2Ur "我的-钱包" 页面（现成）调 `/api/wallet/withdraw` → 走现有 Stripe Transfer 到 `stripe_account_id` → 用户银行 |
| 参与积分 | 答题即得 5 积分（admin 可配） |
| 通知 | 发布、截止前 24h、发奖完成、admin 撤稿（如发生） 全站推送，发奖话术不区分中奖与否 |
| 入口 | 首页"发现更多"区 + "官方活动"区 |
| 命名 | 用户面统一叫"AI 限时问答"（区别于 OfficialTask 的"新手任务"——后者在 `features/newbie_tasks/` 模块独立） |
| 答题长度 | 建议 100-1500 字 + 0-3 张图（spec 推荐值，代码不强约束；可在题面/出题指南中提示） |
| 反作弊 | 接现有 `risk_control.check_risk('ai_qa_answer', ...)`：硬封禁拒答；高风险（score≥30）记录但放行 admin highlight |
| AI 生成识别 | AI 评分输出 `ai_generated=high` 的答案，前端展示时打"可能为 AI 生成"提示标签（仅 scored 后；admin 可改 score） |

### 2.1 中奖人数公式

```python
def calc_cash_winners(answer_count: int, formula: dict) -> int:
    if answer_count == 0:
        return 0
    if answer_count < formula["min_for_full_split"]:  # 默认 10
        return answer_count
    if formula["mode"] == "fixed":
        return min(formula["fixed_winners"], formula["max_winners"], answer_count)
    # mode == "ratio"
    import math
    n = math.ceil(answer_count * formula["ratio"])
    return min(n, formula["max_winners"], answer_count)
```

**上线默认 formula JSON**：

```json
{
  "min_for_full_split": 10,
  "mode": "ratio",
  "fixed_winners": 10,
  "ratio": 0.5,
  "max_winners": 30,
  "floor_pence": 10
}
```

> `withdraw_threshold_pence` 已删——本 feature 不设提现门槛；用户提现走现有 wallet_service / `/api/wallet/withdraw` 的全局风控（参考 §1 wallet 体系说明）

举例（默认参数下）：

| 答题人数 | 中奖人数 |
|---|---|
| 5 | 5（全员） |
| 9 | 9（全员） |
| 10 | 10（max 兜底） |
| 30 | 15 |
| 50 | 25 |
| 100 | 30（封顶） |
| 300 | 30（封顶） |

### 2.2 池子分配算法

```python
def distribute_pool(scored_answers, pool_pence, floor_pence):
    """
    scored_answers: List[(answer_id, final_score)] —— admin 终审后的有效答案，已按分降序
    返回 List[(answer_id, reward_pence)]
    """
    winners = scored_answers[:calc_cash_winners(...)]
    total_score = sum(s for _, s in winners)
    if total_score == 0:
        return [(aid, 0) for aid, _ in winners]
    raw = [(aid, round(pool_pence * s / total_score)) for aid, s in winners]
    # 抹零：低于 floor_pence 的归零
    cleaned = [(aid, amt if amt >= floor_pence else 0) for aid, amt in raw]
    # 总额误差修正：差额加到第 1 名
    diff = pool_pence - sum(a for _, a in cleaned)
    if cleaned:
        first_aid, first_amt = cleaned[0]
        cleaned[0] = (first_aid, first_amt + diff)
    return cleaned
```

**未中奖者**（非 top-N）拿固定参与积分，不进现金分配。**未中奖+未发出的钱**留在 reward_pool_pence 字段里历史记录，不退、不补、不滚——本来钱就没动过。

### 2.3 出题原则（admin guideline）

题目方向决定**谁会被吸引来答**，进而决定 UGC 质量、反作弊压力、平台调性。admin 配置 `direction_prompt` / 手填 draft 时遵循：

1. **优先海外华人/留学生场景强相关题**——例：`"第一次找陪诊有什么注意事项？"` `"在英国怎么辨别靠谱代写？"` `"留学生怎么省钱寄国内包裹？"` `"刚到英国第一周必做的 5 件事？"`
2. **避免通用开放问**——例：`"你最爱的电影是什么？"` `"分享你的故事"`。这类题非平台用户也能瞎写，是羊毛党的天堂。
3. **避免一句话能答完的题**——题目应能撑起 100+ 字回答，鼓励信息量。
4. **避免政治/宗教/争议性话题**——风险高、对平台调性无收益。
5. **题面带场景细节**——例：把 `"找室友的建议"` 写成 `"在伦敦 Zone 2 找合租室友，怎么避坑？"`，更精准过滤受众。

> 本节是软约束（admin 出题指南），不在数据模型层面强制；admin Web `/admin/ai-qa/drafts` + `/admin/ai-qa/config` 页面在 prompt/题面输入框旁内嵌该清单作为提示。

## 3. 数据模型

### 3.1 新表

```sql
CREATE TABLE ai_questions (
    id              SERIAL PRIMARY KEY,
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    posed_by_expert_id  VARCHAR(8) NOT NULL REFERENCES experts(id),  -- official Expert,题目必须挂名
                                                                      -- draft/candidate publish 时 admin 必填或后端默认填
                                                                      -- 配置项 SystemSettings['ai_qa_default_expert_id']
                                                                      -- (P0 上线前 admin 后台先建一个 is_official=True 的 Expert)
    status          VARCHAR(20) NOT NULL DEFAULT 'draft',
                    -- 完整 10 状态枚举 (§3.3 状态机):
                    -- draft | published | canceled | closed | closed_empty
                    -- | scoring | scoring_failed | scored | settled | settle_failed
    published_at    TIMESTAMPTZ,
    deadline        TIMESTAMPTZ,
    edit_lock_at    TIMESTAMPTZ,           -- 通常 = deadline - 1h
    canceled_at     TIMESTAMPTZ,           -- admin 撤稿时间
    cancel_reason   TEXT,                  -- admin 撤稿理由(留底,不分类)
    settled_at      TIMESTAMPTZ,
    reward_pool_pence       INT NOT NULL DEFAULT 1000 CHECK (reward_pool_pence BETWEEN 0 AND 100000),  -- S2:单期最高 £1000 硬封顶
    participation_points    INT NOT NULL DEFAULT 5 CHECK (participation_points BETWEEN 0 AND 1000),
    topn_formula            JSONB NOT NULL,
    ai_prompt_used          TEXT,           -- 出题时所用 prompt 留底
    target_forum_category_id INT NOT NULL REFERENCES forum_categories(id),  -- 答题强制进的论坛板块,从 cycle_config 复制或 draft 手填
    cycle_config_id         INT REFERENCES ai_qa_cycle_configs(id),  -- 手填 draft 路径可空
    created_by_admin_id     VARCHAR(5) NOT NULL REFERENCES admin_users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_questions_status ON ai_questions(status);
CREATE INDEX idx_ai_questions_deadline ON ai_questions(deadline) WHERE status = 'published';

CREATE TABLE ai_question_candidates (
    id              SERIAL PRIMARY KEY,
    cycle_run_id    VARCHAR(36) NOT NULL,   -- 一次出题运行的 UUID,3-5 条同一 cycle_run
    cycle_config_id INT NOT NULL REFERENCES ai_qa_cycle_configs(id),
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    ai_model_used   VARCHAR(80),
    chosen          BOOLEAN DEFAULT FALSE,  -- admin 选了哪个发布
    expired_at      TIMESTAMPTZ,            -- 超期作废
    -- 默认参数快照(候选生成时从 cycle_config.default_* 复制,锁定该候选的参考值)
    -- 即使后续 admin 改了 cycle_config 默认值,候选 publish 时 pre-fill 仍用此快照
    snapshot_reward_pool_pence       INT NOT NULL,
    snapshot_topn_formula            JSONB NOT NULL,
    snapshot_duration_hours          INT NOT NULL,
    snapshot_edit_lock_hours_before  INT NOT NULL,
    snapshot_participation_points    INT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_question_candidates_cycle ON ai_question_candidates(cycle_run_id);
CREATE INDEX idx_ai_question_candidates_cycle_config ON ai_question_candidates(cycle_config_id);

CREATE TABLE ai_qa_cycle_configs (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(80) NOT NULL,
    cadence         VARCHAR(20) NOT NULL,   -- weekly | biweekly | monthly | once
    next_run_at     TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE,
    direction_prompt        TEXT NOT NULL,  -- "题目方向" prompt,送给 AI
    default_reward_pool_pence       INT NOT NULL DEFAULT 1000 CHECK (default_reward_pool_pence BETWEEN 0 AND 100000),  -- S2:单期最高 £1000
    default_participation_points    INT NOT NULL DEFAULT 5 CHECK (default_participation_points BETWEEN 0 AND 1000),
    default_topn_formula            JSONB NOT NULL,
    default_duration_hours          INT NOT NULL DEFAULT 168,  -- 7 天
    default_edit_lock_hours_before  INT NOT NULL DEFAULT 1,
    target_forum_category_id        INT NOT NULL REFERENCES forum_categories(id),  -- 该周期答题落入的论坛板块
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 注意：本表语义是"答案+评分"完整记录,不是"仅评分"
-- 答题时(§4.2)就 INSERT 一行,记 risk_score/risk_reasons/user_id/forum_post_id;评分阶段(§4.3) UPDATE 评分字段
CREATE TABLE ai_answer_scores (
    id              SERIAL PRIMARY KEY,
    ai_question_id  INT NOT NULL REFERENCES ai_questions(id) ON DELETE CASCADE,
    forum_post_id   INT NOT NULL,           -- 注意: 不加 FK,允许帖子被删后保留历史
    user_id         VARCHAR(8) NOT NULL,    -- 冗余,防 ForumPost 删后丢追溯
    -- 答题时立即写入(L4 反作弊)
    risk_score      INT DEFAULT 0,          -- 接 risk_control.check_risk() 返回值,0-100
    risk_reasons    TEXT,                   -- check_risk 返回的 reasons join('; ');admin review 页面 highlight
    -- 评分阶段写入
    ai_score        INT,                    -- 0-100
    off_topic       BOOLEAN DEFAULT FALSE,
    ai_generated    VARCHAR(10),            -- low | medium | high;前端 settled 后展示"可能为 AI 生成"标签
    ai_raw_response JSONB,                  -- 留底
    -- admin 终审写入
    admin_override_score    INT,                    -- 0-100,前后端双校验拒绝越界
    admin_reviewer_id       VARCHAR(5) REFERENCES admin_users(id),
    admin_reviewed_at       TIMESTAMPTZ,
    hide_in_qa              BOOLEAN DEFAULT FALSE,  -- admin 终审"屏蔽"(业务级,不影响该帖在论坛流)
    -- settle 写入
    final_score             INT,            -- COALESCE(admin_override_score, ai_score); hide_in_qa=True 时强制 0
    rank_final              INT,            -- 1..N,排名;前端用 rank_final ≤ 3 判定"top 3 高亮"(L3.a 曝光)
    reward_pence            INT DEFAULT 0,
    reward_points           INT DEFAULT 0,
    settled_at      TIMESTAMPTZ,
    -- 资金流向：reward_pence > 0 时,settle 事务内通过 wallet_service.credit_wallet 写入用户 WalletAccount
    -- 流水可通过 wallet_transactions WHERE related_type='ai_question' AND related_id=ai_question_id 反查
    -- 本表不再单独记 transfer 状态,以 wallet_transactions 为准
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (ai_question_id, forum_post_id),
    UNIQUE (ai_question_id, user_id)        -- 一人一题一答,DB 层 enforce
);
CREATE INDEX idx_ai_answer_scores_question ON ai_answer_scores(ai_question_id);
CREATE INDEX idx_ai_answer_scores_user ON ai_answer_scores(user_id);  -- leaderboard / 个人答题历史

CREATE TABLE ai_qa_leaderboard (
    id              SERIAL PRIMARY KEY,
    user_id         VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    total_won_pence INT DEFAULT 0,
    win_count       INT DEFAULT 0,
    answer_count    INT DEFAULT 0,
    last_won_at     TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.2 现有表改动

```sql
ALTER TABLE forum_posts ADD COLUMN ai_question_id INT REFERENCES ai_questions(id);
CREATE INDEX idx_forum_posts_ai_question_id ON forum_posts(ai_question_id) WHERE ai_question_id IS NOT NULL;
```

### 3.3 状态机

10 个状态。两条入题路径汇入 `published`，异常态全部可恢复或为终态。

```
                         ┌─ admin 手填(POST /admin/ai-qa/drafts) ─► draft ──发布──┐
                         │                                                          ▼
candidate ──admin 选中+publish──────────────────────────────────────────────► published
                                                                                    │
                                                                  admin 撤稿        │
                                                                       │            │ deadline 到
                                                                       ▼            ▼
                                                                  canceled         closed
                                                                  (终态)            │
                                                                            ┌──────┴──────┐
                                                                          0 答案        有答案
                                                                            │            │
                                                                            ▼            ▼
                                                                      closed_empty    scoring ──AI 错──► scoring_failed
                                                                       (终态)             │                    │
                                                                                          │              admin 重跑评分
                                                                                       AI 完成                 │
                                                                                          ▼ ◄──────────────────┘
                                                                                       scored
                                                                                          │
                                                                       admin 终审+settle ──发奖事务挂──► settle_failed
                                                                                          ▼                    │
                                                                                       settled            admin 再点 settle 端点
                                                                                  (终态,绝对不可逆) ◄─────────┘
```

**状态语义**：

| 状态 | 含义 | 转入 | 可去 |
|---|---|---|---|
| `draft` | admin 手填草稿(候选 publish 路径不经此态) | 手填 | published |
| `published` | 答题进行中 | candidate publish / draft publish | closed (deadline) / canceled (admin 撤) |
| `canceled` | admin 撤稿(题面错/敏感) | published | (终态) |
| `closed` | deadline 到,停收答 | published | scoring (有答) / closed_empty (无答) |
| `closed_empty` | 0 答案 | closed | (终态) |
| `scoring` | AI 评分中 | closed | scored / scoring_failed |
| `scoring_failed` | AI API 挂(超时/JSON 损坏/部分缺) | scoring | scoring (admin 重跑) |
| `scored` | AI 评分完,等 admin 终审 | scoring | settled / settle_failed |
| `settled` | 已发奖 | scored | (终态,绝对不可逆) |
| `settle_failed` | settle 事务挂(钱包写失败回滚) | scored | settled (admin 重试 settle 端点成功) / settle_failed (再次失败) |

**关键约束**：
- `settled` 是**绝对终态**——admin 终审失误等任何反悔走客服手动钱包出账(参考 [`feedback_destructive_operations`])
- `canceled` 是**软终态**——已答用户参与积分照给(详见 §7),奖金池不发,ForumPost 绑定保留(详情页加 banner)
- `scoring_failed` 与 `settle_failed` 是两个独立异常——前者 AI 挂,后者发奖事务挂,各自有独立重试入口

## 4. 业务流程

### 4.1 出题管道

两条路径：**周期 cycle 自动出题**（主） + **admin 手填**（兜底，AI 出题失败 / 急用）。

#### 4.1.a Cycle 路径（主）

```
ai_qa_cycle_configs.next_run_at ──Celery beat 扫到──► run_qa_cycle(cycle_config_id)
                                                       ├─ AI 用 direction_prompt 生 3-5 候选
                                                       ├─ 写 ai_question_candidates (同一 cycle_run_id + cycle_config_id)
                                                       ├─ 把 cycle_config.default_* 5 字段快照到 candidate.snapshot_*
                                                       ├─ 设置 expired_at = now + 48h
                                                       └─ 通知 admin "新候选题等审核"
                                                              ↓
                                                     admin /admin/ai-qa/candidates
                                                       ├─ 选一题 + 改文案 + 设 deadline + (可改池子等)
                                                       └─ POST /admin/ai-qa/candidates/{id}/publish
                                                              ↓
                                                     pre-fill 取 candidate.snapshot_* (锁定值,非实时 cycle_config)
                                                     admin 可在 body 用 overrides 覆盖任意字段
                                                              ↓
                                                     创建 ai_questions (status=published, cycle_config_id 沿用)
                                                     标 chosen=True,同 cycle_run 其余候选 expired
                                                     更新 cycle.next_run_at
                                                              ↓
                                                     全站通知"新一期问答开放"
```

**超期未审**：beat 跑 `expire_unaudited_candidates`，把 `expired_at < now AND chosen = FALSE` 的候选标记作废。

#### 4.1.b Draft 手填路径（兜底）

```
admin POST /admin/ai-qa/drafts (body: title, content, target_forum_category_id, deadline,
                                       reward_pool_pence, participation_points, topn_formula,
                                       posed_by_expert_id?: 不填则用 SystemSettings['ai_qa_default_expert_id'])
       ↓
   创建 ai_questions (status=draft, cycle_config_id=NULL,
                      posed_by_expert_id=body 或默认 SystemSettings)
       ↓
admin PATCH /admin/ai-qa/drafts/{id}  (反复编辑,仅 status=draft 可改)
       ↓
admin POST  /admin/ai-qa/drafts/{id}/publish
       ↓
   切 status=published,published_at=NOW()
       ↓
   全站通知"新一期问答开放"
```

### 4.2 答题流程

```
首页 home_discovery_cards 渲染 AIQuestion 卡片
   ↓
点击 → ai_qa_detail_view（题面 + 倒计时 + 奖金池 + 答案列表）
   ↓
"我来答" → 跳论坛发帖编辑器
          - 板块字段 lock 到题目预设板块
          - 隐藏字段 ai_question_id 已填,不可改
   ↓
提交 → POST /api/forum/posts （现有接口扩展接受 ai_question_id 字段）
       OR
       POST /api/ai-qa/{id}/answer （新接口,内部调论坛 crud 创建带 ai_question_id 的帖子）
   ↓
返回 → 跳回 ai_qa_detail_view，自己的答案高亮"你的回答"
```

**说明**：选第二种（新独立接口）更干净——`/api/ai-qa/{id}/answer` 对前端是一个语义清晰的端点。校验顺序：

1. 题目存在 → 404
2. `status = 'published'` → 否则 409（含 canceled / closed / scoring 等）
3. `now < deadline` → 否则 409 `ai_qa_deadline_passed`
4. `now < edit_lock_at` → 否则 409 `ai_qa_edit_locked`
5. 该 user_id 在该 ai_question_id 下未发过答案 → 否则 409 `ai_qa_already_answered`（依赖 ai_answer_scores 的 UNIQUE 约束）
6. 校验 ForumPost 板块 = `target_forum_category_id`（前端已锁，后端复核）
7. **风控（L4）**：`allowed, reason, score = risk_control.check_risk(user_id, 'ai_qa_answer', device_fingerprint, ip)`
   - `allowed=False` → 403 `ai_qa_blocked_by_risk`（reason 透传）
   - `allowed=True` → 通过，无论 score 高低
8. 全部通过 → 事务里同时写两行：
   - 调论坛 CRUD 创建带 `ai_question_id` 的 ForumPost
   - 写入 `ai_answer_scores`（仅填 ai_question_id, forum_post_id, user_id, risk_score, risk_reasons；评分字段全 NULL）

### 4.3 评分管道

```
deadline 扫描 beat ── 找 status=published & deadline < now ── 切 closed
                                                              ↓
                                                       拉所有 ai_answer_scores WHERE ai_question_id = X
                                                       LEFT JOIN forum_posts AND forum_posts.is_deleted = False
                                                       (答题时已建行,这里读取并跳过已删的)
                                                              ↓
                                                       敏感词命中(现有论坛 hidden 机制)的 ForumPost → 该行 hide_in_qa=True
                                                              ↓
                                                  ┌── 0 行 (全删 / 全 hidden) ─► 切 closed_empty
                                                  │
                                                  └── 有行 ─► 切 status=scoring
                                                              ↓
                                                       分批送 Claude Sonnet 4.5（每批 10 个,简化 JSON 输出）
                                                              ↓
                                                       UPDATE ai_answer_scores 写 ai_score / off_topic /
                                                              ai_generated / ai_raw_response
                                                              ↓
                                                       切 status=scored
                                                       通知 admin 终审
```

**评分 prompt 简化**（核心是省 token）：

```
你是问答评分员。给每条答案打分,只输出 JSON 数组：
[{"id": <answer_id>, "score": 0-100, "off_topic": bool, "ai_generated": "low|medium|high"}]

评分维度（按权重）：
- 切题度（核心）：偏题严重 score ≤ 30 且 off_topic=true
- 真人感：明显 AI 味重 ai_generated="high",可疑"medium",自然"low"
- 内容质量：信息量、表达、独特性

题目：{question}
答案列表：
[{"id": 1, "content": "..."}, {"id": 2, "content": "..."}]
```

**不输出 reasoning** 节省 token；admin 想看单条 reasoning 单独跑一次更详细的 prompt。

### 4.4 终审 + 发奖

```
admin /admin/ai-qa/review/{qid}
   表格：排名 / 用户 / 答案预览 / AI分 / 改分输入框 / 现金预算 / 操作（看全文 / 屏蔽 hide_in_qa）
   合计：£X.XX / 池 £10.00  （前端实时算）
   ↓
admin 点 [确认发奖] → POST /admin/ai-qa/review/{qid}/settle
   后端事务里：
     ├─ **S1 幂等行锁**：SELECT * FROM ai_questions WHERE id=X FOR UPDATE
     │     (同事务内别的 settle 请求会阻塞;如需跨节点幂等可加 idempotency_key)
     ├─ **S1 状态二次校验**：锁内再次确认 status IN ('scored','settle_failed'),否则直接返回
     │     (避免 admin 双击 / 两个 admin 同时点导致双发)
     ├─ **S5 周度上限校验**（防 admin 被攻陷高频刷题）：
     │     SELECT SUM(reward_pence) FROM ai_answer_scores
     │       WHERE settled_at >= NOW() - INTERVAL '7 days'
     │     cap = SystemSettings['ai_qa_weekly_settle_cap_pence']  (默认 20000 = £200/周)
     │     若 sum + 本期 reward_pool_pence > cap → 拒,409 + audit log + 触发 S6 邮件
     │     修改该 setting 本身需 2 步确认（admin UI 强制）+ 单独 audit
     ├─ 用 admin_override_score (or ai_score) 重算 final_score 排序
     ├─ 调 calc_cash_winners() 得 winner 列表
     ├─ 调 distribute_pool() 得每人金额
     ├─ 写 ai_answer_scores.reward_pence / reward_points / rank_final / settled_at
     ├─ **入账 wallet**（对每个 reward_pence > 0 的中奖者，事务内同步）：
     │     wallet_service.lock_wallet(db, user_id, currency='GBP')        # 行锁防并发
     │     wallet_service.credit_wallet(
     │         db, user_id=user_id,
     │         amount=Decimal(reward_pence)/100,                          # pence → £
     │         currency='GBP',
     │         source='ai_qa_reward',
     │         related_type='ai_question',
     │         related_id=str(qid),
     │         idempotency_key=f'ai_qa_settle_{qid}_{user_id}',           # 关键:防双发
     │         description=f'AI 限时问答 #{qid} 第 {rank_final} 名奖金'
     │     )
     │     若任一 credit_wallet 抛异常 → 整个事务回滚至 settle_failed
     │     idempotency_key UNIQUE 保证即使行锁/状态校验失效,DB 层也拒绝双发
     ├─ add_points_transaction（所有未被拉黑答主，含未中奖者）
     ├─ 更新 ai_qa_leaderboard
     ├─ **L3.b 曝光**：若有 rank_final=1 的答案,UPDATE forum_posts.is_featured=True
     ├─ 切 ai_questions.status = settled
     ├─ **S3 审计日志**：调 create_audit_log(action_type='ai_qa_settle',
     │      entity_type='ai_question', entity_id=X, admin_id=current_admin,
     │      new_value={total_settled_pence, winner_count, top1_user_id},
     │      reason=...)
     └─ **S6 异常发奖邮件告警**（事务外异步）：
            若当周累计 settled >= 阈值（默认 10000 = £100/周）→ email_utils.send 给所有 admin
            email 内容：本周累计 + 触发题目 id + 时间，强制 admin 关注

**用户提现**：完全复用现有钱包流程——用户在"我的-钱包"页面看 balance 与流水（流水 source 为 `ai_qa_reward` 时含题目链接），点提现 → `/api/wallet/withdraw` → 现有 wallet_service 走 Stripe Transfer 到 stripe_account_id（未绑会被现有钱包流程引导先绑）。**本 feature 不实现单独的领奖入口/提现链路**。
   ↓
全站推送统一话术："本期问答评分结束,来看看大家的回答"
```

**事务保证**：钱包入账 + 积分 + leaderboard 在同一 DB transaction；失败 → 切 status=settle_failed（事务外的状态写）；admin 在 review 页可见 banner 提示并再点一次 settle 即可重试。

**leaderboard 写入语义**（per user_id 在 ai_qa_leaderboard 行的字段更新）：

```python
# 对所有 hide_in_qa=False 的答主（含未中奖）：
answer_count += 1

# 仅对 reward_pence > 0 的中奖者：
total_won_pence += reward_pence
win_count += 1
last_won_at = NOW()
```

注意：**canceled 题不写 leaderboard**（题目根本没走到 settle）。canceled 时虽然给参与积分（§7），但不计入 answer_count——保持 leaderboard 数据干净，只反映正常完成的问答统计。

## 5. API 设计

### 5.1 用户端

```
GET    /api/ai-qa                          列表（当期 + 历史）
GET    /api/ai-qa/{id}                     详情（含奖金池/倒计时/answers 列表）
GET    /api/ai-qa/{id}/answers             答案列表（按 final_score 降序,settled 后展示金额）
POST   /api/ai-qa/{id}/answer              作答（body: {title, content, images}）
PATCH  /api/ai-qa/{id}/answer              编辑（仅 edit_lock_at 之前）
GET    /api/ai-qa/leaderboard              答主累计榜（top 50,P2 才实现端点；表 P0 已写入）
```

### 5.2 Admin 端

```
# 周期配置
GET    /api/admin/ai-qa/cycles             周期配置列表
POST   /api/admin/ai-qa/cycles             新建
PATCH  /api/admin/ai-qa/cycles/{id}        修改（含 direction_prompt）
POST   /api/admin/ai-qa/cycles/{id}/run-now  手动触发出题（linktest 用,因为无 Celery）

# 候选题（cycle 路径）
GET    /api/admin/ai-qa/candidates         待审候选题（含已过期）
POST   /api/admin/ai-qa/candidates/{id}/publish   发布
                                           body: {deadline, title?, content?, ...overrides}
                                           pre-fill 用 candidate.snapshot_*,overrides 覆盖任意字段
DELETE /api/admin/ai-qa/candidates/{id}    作废候选

# 草稿（手填路径,兜底）
POST   /api/admin/ai-qa/drafts             手填创建草稿
                                           body: {title, content, target_forum_category_id, deadline,
                                                  reward_pool_pence, participation_points, topn_formula, ...}
                                           创建 ai_questions (status=draft, cycle_config_id=NULL)
PATCH  /api/admin/ai-qa/drafts/{id}        编辑草稿（仅 status=draft 可改,否则 409）
DELETE /api/admin/ai-qa/drafts/{id}        删除草稿（仅 status=draft,硬删,无用户面）
POST   /api/admin/ai-qa/drafts/{id}/publish  草稿发布（status: draft → published）

# 题目管理
GET    /api/admin/ai-qa/questions          所有问答列表（含状态过滤）
POST   /api/admin/ai-qa/questions/{id}/cancel    admin 撤稿（仅 published）
                                           body: {reason} （写入 cancel_reason 留底）
                                           前置：status = 'published' 才允许（draft 走 DELETE /drafts/{id}）;
                                           后置：status → canceled, canceled_at = NOW();
                                                参与积分仍照发(详见 §7),奖金不发
GET    /api/admin/ai-qa/questions/{id}/review   终审表格数据
PATCH  /api/admin/ai-qa/scores/{id}        改分（body: {admin_override_score: 0-100, hide_in_qa?}）
POST   /api/admin/ai-qa/questions/{id}/rescore   重跑 AI 评分（前置 status=scoring_failed → 切 scoring 后跑）
POST   /api/admin/ai-qa/questions/{id}/settle    确认发奖（事务）
                                                 前置 status IN (scored, settle_failed)（同端点支持首次发奖+重试）
                                                 事务失败 → status = settle_failed,admin 再点同端点即可重试
                                                 **S1 幂等**：事务内 SELECT FOR UPDATE 行锁 + 锁内状态二次校验
                                                 **S5 周度上限**：超 SystemSettings['ai_qa_weekly_settle_cap_pence'] 拒 409
                                                 **Wallet 入账**：调 wallet_service.credit_wallet (idempotency_key 防双发);失败回滚 settle_failed
                                                 **S3 审计**：成功/失败均写 create_audit_log（new_value 含 total_settled_pence / winner_count / top1_user_id）
                                                 **S6 告警**：周累计 ≥ 阈值时事务外 email 报警

POST   /api/admin/ai-qa/settings                 修改 SystemSettings 关键参数（如 ai_qa_weekly_settle_cap_pence）
                                                 强制 2 步确认 (body: {key, new_value, confirm_token})
                                                 每次修改写独立 audit log，避免攻陷后偷偷拉高上限

# 所有 admin 写操作端点统一规范（S3）
# 以下端点每次成功执行都需调 create_audit_log()：
#   /drafts (POST/PATCH/DELETE/publish)、/candidates/{id}/publish、
#   /scores/{id} (改分)、/questions/{id}/cancel、/questions/{id}/rescore、
#   /questions/{id}/settle、/cycles (POST/PATCH)
# 字段规范：action_type='ai_qa_<verb>'、entity_type='ai_question' 或 'ai_answer_score' 或 'ai_qa_cycle_config'、
#         entity_id=对象 id、admin_id=current_admin、old_value/new_value=变更前后
```

## 6. 前端落地

### 6.1 Flutter (`link2ur/`)

新模块 `lib/features/ai_qa/`：

```
ai_qa/
├── bloc/
│   ├── ai_qa_bloc.dart                 列表/详情 state
│   └── ai_qa_leaderboard_bloc.dart
└── views/
    ├── ai_qa_list_view.dart            列表（当期 + 历史 tab）
    ├── ai_qa_detail_view.dart          详情
    ├── ai_qa_answer_form_view.dart     作答（复用论坛编辑器 widget）
    └── ai_qa_leaderboard_view.dart     答主榜
```

新增 repository `data/repositories/ai_qa_repository.dart`。

**Bloc 层级**：page-level（参考 CLAUDE.md 的"narrowest scope"原则）。

**入口改动**：

- `data/models/discovery_feed.dart` —— `DiscoveryFeedItem.type` 加 `ai_qa_question`
- `features/home/views/home_discovery_cards.dart` —— 新增 AIQuestion 卡片 builder
- `features/home/views/home_activities_section.dart` —— "官方活动" 区列表里支持 AIQuestion 类型

**路由**（GoRouter）：

```dart
/ai-qa                       → AiQaListView
/ai-qa/:id                   → AiQaDetailView
/ai-qa/:id/answer            → AiQaAnswerFormView
/ai-qa/leaderboard           → AiQaLeaderboardView
```

`BuildContext` 扩展：`context.goToAiQaDetail(id)` 等。

**l10n**：3 locale（en / zh / zh_Hant）所有用户面字符串加 key。错误码走 `error_localizer.dart`（参考 CLAUDE.md 错误处理规范）。

**答案卡片展示规则（L3 + L4 衍生）**：

| 条件 | 展示 |
|---|---|
| `rank_final ∈ [1, 3]` 且题目 `status = 'settled'` | 卡片边框金色 + "精选 #N" 角标（L3.a） |
| `ai_answer_scores.ai_generated = 'high'` 且 `status IN ('scored', 'settled')` | 卡片底部小字"⚠ 可能为 AI 生成"灰色提示标签（L4 透明化）|
| `ai_answer_scores.hide_in_qa = True` | 卡片完全不展示在问答页（admin 屏蔽业务态）|
| `forum_posts.is_deleted = True` 且题目 `status IN ('settled','canceled')` 且 `ai_answer_scores` 行存在 | 占位卡片"该答案已被删除" + 仍展示 reward_pence（仅 settled 后才有）|
| `forum_posts.is_deleted = True` 且题目 `status` 在 published / closed / scoring / scored 阶段 | **不展示**（无意义占位；评分管道也跳过；ai_answer_scores 行保留待 settled 时再决定是否进 leaderboard） |
| 题目 `status = 'canceled'` | 顶部 banner "本期问答已取消"，答案仍可见但无金色边框 |

**入口命名**（F 决策）：用户面统一称"AI 限时问答"，l10n key `ai_qa_*`。卡片右上角金色 badge "现金奖励 £{reward_pool_pence/100}" 用以与 OfficialTask（积分任务、新手入口）视觉区分。

### 6.2 Admin Web (`admin/`)

**通用规范**：
- `topn_formula` JSONB 字段在 admin 表单中**不**以 raw JSON 暴露。拆成 5 个 input：
  `mode` dropdown (ratio/fixed) · `ratio` (0-1, 仅 ratio 模式) / `fixed_winners` (仅 fixed 模式) · `max_winners` · `floor_pence` · `min_for_full_split`
  下方实时显示**预览**："9 人答 → 9 人全员分 ≈ £X/人 · 30 人答 → Y 人中奖 ≈ £Z/人 · 100 人答 → max 封顶 ≈ £W/人"
  保存时前端将表单值组装为 JSON 存入 JSONB。同样规则适用于 cycle_config.default_topn_formula 和 candidate snapshot/draft 编辑。
- **S2 大额二次确认**：reward_pool_pence input 校验 0 ≤ x ≤ 100000 (£0-£1000)。
  当 admin 提交时若 reward_pool_pence > 5000（即 > £50），弹模态框二次确认：
  "⚠ 你正设置一个 £X.XX 的奖金池（高于 £50）。本期发奖后无法撤回，请确认。"
  必须勾选 "我已确认该金额"才能 submit。 settle 时 admin 也再次看到金额(已在 review 页表头)。

新增 4 个页面：

```
/admin/ai-qa/config           周期/Prompt/默认 formula 配置（P1）
/admin/ai-qa/candidates       候选题待审（P1）
/admin/ai-qa/drafts           草稿管理（新建/编辑/发布/删除）（P0）
/admin/ai-qa/questions        题目列表（含状态过滤 + 撤稿入口 + 进入 review）（P0）
/admin/ai-qa/review/:qid      评分终审（表格 + 改分 + 一键发奖,settle_failed 时显示重试 banner）（P0）
                              表格列：排名 / 用户(头像+id+device 关联账号数) /
                                     **发布时间 forum_posts.created_at + 编辑标记** /
                                     答案预览 / AI分 /
                                     ai_generated 标(low/med/high 不同色) / risk_score (≥30 红底) /
                                     risk_reasons / 改分 input / hide_in_qa checkbox / 现金预算
                              排序：默认 risk_score 降序 + ai_generated=high 优先（让 admin 先看可疑的）;
                                   可切换"按 created_at 升序"——帮 admin 看时序判模仿
                              时序提示：使用 `forum_posts.created_at`（首次写入时刻）,**不是** updated_at;
                                      若 updated_at != created_at,显示"已编辑（X 分钟前）"小字;
                                      admin 凭经验判"晚答 + 内容高度相似 + 编辑时间集中在某高分答案发布后" 等模式
```

## 7. 边界 & 错误处理

| 情况 | 处理 |
|---|---|
| 答题人数 = 0 | 题目状态切 `closed_empty`，奖金池不发；钱本来就没动 |
| 答题人数 < 10 但 > 0 | 全员分（按 formula 规则） |
| AI 出题失败 / 超时 | 候选表空，admin 后台显示 "AI 没出题，可手填"；admin 可手动建一道发 |
| AI 评分 API 错 | 切 `scoring_failed`，admin 可点 "重跑评分"；不自动重试（防 API 抖动烧钱） |
| 评分超期 24h admin 没审 | 邮件 escalation；不自动发奖 |
| 帖子被 admin 删 / 用户删（settled 前） | ForumPost.is_deleted=True；评分管道 WHERE is_deleted=False 自动过滤；不写 ai_answer_scores |
| 帖子被 admin 删 / 用户删（settled 后） | **保留 `ai_answer_scores` 行**（无 FK,不级联）；详情页查 `forum_posts.is_deleted` 显示"该答案已删除"占位 + 仍展示获奖金额；钱已发不退 |
| 同人发了 2 个答案（绕过 lock） | 后端 `/api/ai-qa/{id}/answer` 入口去重：返回 409；如绕过入口直接调论坛接口，beat 跑分前去重取最新 |
| 答案触发敏感词 | ForumPost 走现有 hidden 机制（系统级，论坛和问答页都不显示），不计评分 |
| Admin 终审"屏蔽"某答案 | 写 `ai_answer_scores.hide_in_qa=True`（业务级，仅问答页不计分/不展示；该 ForumPost 在论坛流仍正常显示） |
| **admin 撤稿（published → canceled）** | 1) 已答用户参与积分**照给**(扫 forum_posts WHERE ai_question_id=X AND is_deleted=False,逐个 add_points_transaction);2) ForumPost.ai_question_id **不清空**,详情页加"本期问答已被取消"banner 但答案仍可见;3) 奖金池不发;4) 全站推送"本期问答已取消" |
| **admin 终审失误（settled 后发现错发奖）** | settled 是**绝对终态**,不提供程序化撤回;走客服手动钱包出账(参考 [`feedback_destructive_operations`]) |
| admin 改分后总额 ≠ 池 | 前端实时校验；后端 settle 前再校验，不一致返回 400 |
| 现金到钱包但用户钱包冻结 | 入账正常，提现走现有钱包冻结逻辑 |
| 候选题 admin 漏审 > 48h | 候选作废（chosen=FALSE 且 expired_at < now）；下个周期 beat 重新出 |
| 用户被封号 | 答题入口已被现有封号 middleware 拦截，根本进不来 |
| `admin_override_score` 越界（< 0 或 > 100） | 前后端双校验拒绝；后端 422 + 错误码 `ai_qa_score_out_of_range` |
| **`risk_control.check_risk` allowed=False** | 答题端点直接 403 + 错误码 `ai_qa_blocked_by_risk` + 透传 reason；不写 ai_answer_scores（用户不可见自己被拦） |
| **同 device fingerprint 多账号 (risk_score≥30)** | 答案进库（不影响其他用户体验），admin review 页面 highlight 红底 + 显示 risk_reasons（"设备关联了 N 个账号"等）；admin 决定是否 hide_in_qa |
| **AI 误判 ai_generated=high (人手写却被打 high)** | 不强制扣分，前端仅作"⚠ 可能为 AI 生成"灰色提示标签；admin 终审可保持 ai_score 或 admin_override_score 拉回；用户能看到提示但不影响投票（无投票机制）|
| **风控误伤（同宿舍 / 同 wifi / 同设备共享）** | 接受——L4 选档 2 mixed，仅高风险标记不直接拒；admin 终审兜底；用户面无任何自动拒（除 allowed=False 硬封禁）|
| **答案模仿/抄袭嫌疑** | **不做自动相似度检测**（YAGNI）；admin review 表格显示 `forum_posts.created_at`（非 updated_at）+ 编辑标记，可按 created_at 升序排列查看时序；admin 凭经验判"晚答 + 内容高度相似 + 编辑时间在某高分答案发布后"等模式，用 `admin_override_score` / `hide_in_qa` 处理；设计上接受"内容公开 + 后答有抄袭风险"的代价 |
| **S1 settle 双发（admin 双击 / 多 admin 同时点）** | 事务内 SELECT FOR UPDATE 行锁 + 锁内状态二次校验；后到的请求看到 status=settled 直接 409 `ai_qa_already_settled` |
| **S2 admin 设置超额池子** | DB CHECK 拒绝 reward_pool_pence > 100000（£1000）；UI 大额（>£50）弹二次确认 + 必勾"我已确认"；settle 前 review 页表头再次显示总额 |
| **S5 周度发奖累计超上限（防 admin 被攻陷高频刷题）** | 事务前置查 7 天累计 settled pence + 本期 ≤ SystemSettings cap（默认 £200/周）；超过 409 + audit log + S6 邮件触发；admin 修改该 setting 需 2 步确认 + 独立 audit log |
| **S6 异常发奖邮件告警** | 周累计 settled ≥ 阈值（默认 £100/周）→ 事务外异步 email_utils 发邮件给所有 admin；攻陷场景下攻击者拿到 admin 不一定能修改邮箱即时告警 |
| **中奖者未绑 Stripe Connect** | 钱**照样进入 WalletAccount.balance**，用户在"我的-钱包"看得到；只是点提现时现有钱包流程会引导先绑 Stripe Connect（已有交互，不在本 feature 范围）|
| **wallet_service.credit_wallet 抛异常（DB 锁冲突/IO 失败）** | 事务回滚 → settle_failed；幂等 key UNIQUE 保证重试时不会双发 |
| **idempotency_key 冲突（settle 重试时已部分成功）** | UNIQUE 约束触发 IntegrityError → wallet_service 内部捕获并视为已入账（跳过该用户），其他用户继续；保证最终一致 |
| **用户钱包被冻结 / balance 异常** | credit_wallet 仍然能入账（balance 字段不阻塞）；提现时由现有钱包冻结流程处理，与本 feature 解耦 |

## 8. 测试策略

### 单元测试（pytest）

| 测试 | 覆盖 |
|---|---|
| `calc_cash_winners` | 0/5/9/10/30/50/300 等边界，fixed/ratio 两模式 |
| `distribute_pool` | 加权分配 / floor 抹零 / 总额修正 / 全 0 分情况 |
| AI 评分 mock | 正常响应 / JSON 损坏 / 超时 / 部分答案缺失 |
| 状态机转换 | 所有合法路径 + 非法跳转拒绝 |

### 集成测试（FastAPI TestClient）

| 端点 | 覆盖 |
|---|---|
| `POST /api/admin/ai-qa/drafts` + `PATCH` + `DELETE` + `/publish` | 权限 + 状态前置（draft 才可改/删/发）+ target_forum_category_id NOT NULL 校验 |
| `POST /api/admin/ai-qa/candidates/{id}/publish` | 权限校验 + 候选不存在 + 已发布 + pre-fill 用 snapshot 验证 |
| `POST /api/admin/ai-qa/questions/{id}/cancel` | 前置 status=published（draft 拒 409,settled/canceled 拒 409）+ 参与积分对所有未删答主补发 + ForumPost.ai_question_id 不变 |
| `POST /api/ai-qa/{id}/answer` | 状态校验（draft/closed/canceled 全拒）+ 重复答 409 + 锁定后拒 + 板块复核 + risk_control allowed=False → 403 + 通过时写 ai_answer_scores 行（risk_score / risk_reasons 正确填入）|
| `POST /api/admin/ai-qa/scores/{id}` 改分 | 权限 + score 越界 422 + 改分后总额刷新 |
| `POST /api/admin/ai-qa/questions/{id}/settle` | (a) 事务一致性：mock `wallet_service.credit_wallet` 抛异常 → 全回滚 → status=settle_failed → 重试同端点成功；(b) 副作用正确：top 1 答案 `forum_posts.is_featured=True`、leaderboard 写入语义（answer_count 对所有未 hide 答主 +1，reward_pence>0 时 win_count/total_won_pence/last_won_at 更新）；(c) canceled 流程**不**经 settle，不写 leaderboard；**(d) S1 幂等**：mock 双并发 settle，验证只有 1 次成功，另 1 次拿到行锁等待后看到 status=settled 返回 409；**(e) S2 池子上限**：reward_pool_pence=100001 直接 DB CHECK 失败；**(f) S5 周度上限**：mock SystemSettings cap=10000，已 settle £95 + 本期 £10 → settle 拒 409 + 触发 S6；**(g) S3 审计**：成功/失败均产生 1 条 AuditLog 记录；**(h) idempotency_key 防双发**：同 settle 跑 2 次,第 2 次因 wallet_transactions UNIQUE 约束跳过已入账行 |

### Flutter widget 测试

- `ai_qa_detail_view` 锁定状态 / 倒计时 / 答案列表渲染
- `ai_qa_answer_form_view` 板块锁、ai_question_id 隐藏字段保留

### 手动 QA（上线前）

| 步骤 | 注意 |
|---|---|
| 在 linktest 跑完整流程 | Celery 在 linktest 没装，beat 类只能在 prod 灰度（[`architecture_celery_linktest_vs_prod`]）；用 admin "手动触发" 按钮模拟 |
| Migration 顺序 | 先跑 DB migration 再 push 代码（[`feedback_migration_before_deploy`]） |
| 跨层一致性 | 按 `full-stack-consistency-check` skill 跑一遍 DB → schema → route → frontend |

## 9. 上线分期建议

| 期 | 内容 |
|---|---|
| **P0 — MVP** | 5 张新表全建（含 `ai_qa_leaderboard`）+ admin 后台 draft 手填（drafts 增删改 + publish + cancel）+ 用户答题（含 **L4 接 risk_control.check_risk**）+ AI 评分（含 ai_generated 字段写入）+ admin 终审（含 risk_score / ai_generated 高亮表格）+ 发奖（settle 时同步写 leaderboard + **L3.b ForumPost.is_featured 置 top1**）+ **L3.a 详情页 top 3 高亮**；前端答案卡片 **L4 "可能为 AI 生成" 提示标签**；**不接 Celery 出题**（draft 路径足够验证产品形态）|
| **P1** | Cycle 自动出题 + candidate 审核流（含 snapshot pre-fill）+ admin prompt 动态编辑 |
| **P2** | Flutter 用户入口（home discovery + 官方活动区卡片）+ 答主排行榜前端入口（表早已写满数据,直接读）+ 通知优化 + **L3.c 头像角标 7 天**（需新表 `user_badges`）+ **L3.d Profile 累积勋章** |
| **P3+** | Admin 数据看板（参与率/平均分/答题分布）+ **L3.e 首页 banner top 1 推荐一周**（动 home_discovery 架构）+ **L3.f Expert 邀请通道**（top N 期获奖触发 admin 邀请加 Expert 团队，接现有 ExpertApplication）|

solo 项目直推 main，不开 feature 分支（参考 `feedback_direct_to_main`）。

## 10. 风险 & 决策记录

| 风险 | 决策 |
|---|---|
| AI 评分不稳一致 | 接受——人工终审是兜底；评分只跑一次，重跑需 admin 显式点 |
| **admin 终审失误（settled 后才发现）** | settled 是绝对终态,程序化不可逆；走客服手动钱包出账（参考 [`feedback_destructive_operations`]） |
| **admin 撤稿伤已答用户** | canceled 后参与积分照给（admin 独担过失）；ForumPost 绑定保留(详情页 banner)；不区分撤稿原因 |
| Stripe 高频低额提现成本 | settle 不直发 Stripe，进用户 WalletAccount.balance；提现走现有 wallet_service 全局风控（门槛/限额由钱包系统统一管理，本 feature 不另设）|
| 0 人答题尴尬 | 题目状态 closed_empty 不发奖；不滚下期（钱本来就没动） |
| 论坛流被 AI 问答帖子刷屏 | 帖子量受答题人数限制，比一般用户 UGC 量小；不专门做隔离 |
| 用户绕过 `/api/ai-qa/{id}/answer` 直接调论坛接口塞 ai_question_id | beat 评分前后端去重 + 后期可加论坛侧入口审计 |
| cycle_config 删除导致 ai_questions/candidates 孤儿 | cycle_config 表不提供删除,只能 is_active=False 停用;FK 默认 RESTRICT 防止误删 |
| **目标受众错位（核心用户不答 / 边缘用户不来 / 羊毛党扎堆）** | 接受——靠 §2.3 出题原则 admin 自律 + L4 反作弊基线兜底；上线后 1-2 个 cycle 看 risk_score 高的答案占比，决定是否收紧 check_risk 阈值 |
| **经济模型 ROI 不明（10 GBP/期诱因弱）** | P0 不调，先验证产品形态；上线后看 DAU/答题率/UGC 阅读量决定是否调高池子或加 L3.e/f 曝光 |
| **L4 风控误伤（同设备共享场景）** | 选档 2 mixed,不直接拒答；admin 终审兜底；上线后 admin 反馈风控误伤多则收紧 / 少则放宽 |
| **AI 误判 ai_generated** | 前端只做"可能为 AI 生成"灰色提示标签，不影响 score 自动扣减；admin 改分兜底；用户能看到提示但无投票机制可受影响 |
| **C1 HMRC 税务 / promotional expense** | 英国法律下平台向用户付现金奖励的法律定性不明（用户角度 < £1000/年 在 trading allowance 内；平台角度作为 promotional expense 入账）。**上线前需咨询会计师**确认申报方式；若某用户年累计获奖 > £500 可能需主动告知 |
| **C2 AML / FCA 钱包合规** | 单期 £10 不直接触发，但 wallet 累计余额 + 跨渠道合算可能触线。**复用现有钱包合规链路**（KYC + 提现风控），本 feature 不新增合规面 |
| **C3 假账号 / 反洗钱** | L4 风控基线（device fingerprint + check_risk）覆盖部分；深层（同身份证多账号、KYC 后绑不同收款账户）属现有钱包系统范畴，本 feature 不重造 |
| **admin 后台被攻陷 → 高频刷题给同伙发奖 → 同伙提现跑路** | 攻击路径：admin 高频 settle → 钱进同伙 WalletAccount → 同伙调 `/api/wallet/withdraw` → Stripe Transfer 到同伙银行（不可逆）。防御：① **S5 周度入账上限**（DB 硬墙，默认 £200/周）② **S6 邮件告警**（早期发现）③ **现有钱包提现流程的风控**（KYC、提现门槛、风控审核）④ audit log 全量留痕便于追溯并对未提现 balance 做 `reverse_debit`。攻陷场景下最坏损失 = 同伙已提现到 Stripe 部分（cap 之内）|

## 11. 不在本期范围

- 跨题目的答主声望系统（仅做累计奖金/次数榜）
- 用户对答案的点赞/反对加权评分（避免拉票）
- 答案二级评论加分
- 移动端 Web 入口（先做 Flutter 即可，Web 仅 admin）
- 出题语义去重（避免 AI 出过类似题目）—— P2 之后再加
- 多 admin 联合审批（solo 项目 1 admin 即可，未来扩展再加）
- AI 限时问答专用提现入口（复用现有 `/api/wallet/withdraw`，不另起一套）
- 提现冷静期（S10 提议但未采纳，详见上一轮决策）
- 钱包内"奖金按题目分类显示"（仅按 source/related 流水查得到，不做专门 UI）

## 附录 A: 相关 memory 引用

- [`feedback_scheduled_tasks_celery_sync`] —— scheduled_tasks 必须同步加 Celery 包装
- [`architecture_celery_linktest_vs_prod`] —— linktest 无 Celery
- [`feedback_migration_before_deploy`] —— 加列 migration 先跑 DB 再 push
- [`project_ai_model_setup`] —— GLM-4.7-FlashX 出题，Claude Sonnet 4.5 评分
- [`project_admin_ai_prompt_editor`] —— prompt 走 DB，admin 后台改
- [`feedback_direct_to_main`] —— solo 项目直推 main
- [`feedback_db_migration`] —— 编号 SQL migration 文件
- [`feedback_destructive_operations`] —— settled 反悔 / canceled 后救济等破坏性操作走客服
