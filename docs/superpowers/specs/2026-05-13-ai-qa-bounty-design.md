# AI 悬赏问答 设计稿

**日期**: 2026-05-13
**作者**: brainstorming with @zixiong316
**状态**: 设计待 review

## 1. 背景与目标

平台希望以 AI 名义定期发布开放式问题，吸引全站用户图文作答，结束后按答案质量发奖金，所有人都能看所有答案——本质上是一个**类知乎的悬赏问答模块**，主要目的是**拉活跃和沉淀 UGC**。

### 已有相关基础设施（不直接复用）

- `OfficialTask` + `OfficialTaskSubmission`：平台发任务 + 用户提交论坛帖 + 拿固定积分。**和本模块语义重叠但模型不够用**（无定时、无 AI 出题、无评分、无现金、奖励定额）。本模块**另起一套**，不扩展 OfficialTask。
- `Expert.is_official=True`：平台官方达人团队（`admin_official_routes.py`）——题目挂名在此。
- `ForumPost`：现有论坛帖模型——**复用为答案载体**。
- `wallet` + `add_points_transaction`：钱包 + 积分体系——直接复用。
- `scheduled_tasks.py` + Celery：定时调度——加任务时同步加 Celery 包装（参考 `feedback_scheduled_tasks_celery_sync`）。
- AI 模型配置（参考 `project_ai_model_setup`）：小模型 GLM-4.7-FlashX（出题用），大模型 Claude Sonnet 4.5（评分用，简化输出节省 token）。
- AI prompt 动态编辑（参考 `project_admin_ai_prompt_editor`）：出题/评分 prompt 都从 DB 读，admin 可改。

## 2. 核心产品规则

| 项目 | 规则 |
|---|---|
| 题目来源 | admin 配置"题目方向"+ AI 生成 3–5 候选 → admin 审一个 → 发布 |
| 周期 | admin 可配（每周 / 每两周 / 一次性） |
| 用户答题 | 1 用户 1 题 1 答，截止前 1 小时锁编辑（可配） |
| 答案载体 | 一个绑了 `ai_question_id` 的 ForumPost，**论坛流和问答页双露脸** |
| 评分 | AI 简化输出 `{score, off_topic, ai_generated}` + admin 终审改分 |
| 奖金池 | 固定（如 10 GBP），admin 可改 |
| 分配 | 默认 50% 比例公式，封顶 30 人，不足 10 人全员分；可后期切 fixed 模式 |
| 现金落地 | 进现有 wallet；提现门槛 5 GBP（admin 可配） |
| 参与积分 | 答题即得 5 积分（admin 可配） |
| 通知 | 发布、截止前 24h、发奖完成 三个节点全站推送，发奖话术不区分中奖与否 |
| 入口 | 首页"发现更多"区 + "官方活动"区 |

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
  "floor_pence": 10,
  "withdraw_threshold_pence": 500
}
```

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

## 3. 数据模型

### 3.1 新表

```sql
CREATE TABLE ai_questions (
    id              SERIAL PRIMARY KEY,
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    posed_by_expert_id  VARCHAR(8) REFERENCES experts(id),  -- official Expert
    status          VARCHAR(20) NOT NULL DEFAULT 'draft',
                    -- draft | published | closed | scoring | scored | settled | closed_empty | settle_failed
    published_at    TIMESTAMPTZ,
    deadline        TIMESTAMPTZ,
    edit_lock_at    TIMESTAMPTZ,           -- 通常 = deadline - 1h
    settled_at      TIMESTAMPTZ,
    reward_pool_pence       INT NOT NULL DEFAULT 1000,
    participation_points    INT NOT NULL DEFAULT 5,
    topn_formula            JSONB NOT NULL,
    ai_prompt_used          TEXT,           -- 出题时所用 prompt 留底
    target_forum_section_id INT,            -- 答题强制进的论坛板块,从 cycle_config 复制
    cycle_config_id         INT REFERENCES ai_qa_cycle_configs(id),
    created_by_admin_id     VARCHAR(5),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_questions_status ON ai_questions(status);
CREATE INDEX idx_ai_questions_deadline ON ai_questions(deadline) WHERE status = 'published';

CREATE TABLE ai_question_candidates (
    id              SERIAL PRIMARY KEY,
    cycle_run_id    VARCHAR(36) NOT NULL,   -- 一次出题运行的 UUID,3-5 条同一 cycle_run
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    ai_model_used   VARCHAR(80),
    chosen          BOOLEAN DEFAULT FALSE,  -- admin 选了哪个发布
    expired_at      TIMESTAMPTZ,            -- 超期作废
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_question_candidates_cycle ON ai_question_candidates(cycle_run_id);

CREATE TABLE ai_qa_cycle_configs (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(80) NOT NULL,
    cadence         VARCHAR(20) NOT NULL,   -- weekly | biweekly | monthly | once
    next_run_at     TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE,
    direction_prompt        TEXT NOT NULL,  -- "题目方向" prompt,送给 AI
    default_reward_pool_pence       INT NOT NULL DEFAULT 1000,
    default_participation_points    INT NOT NULL DEFAULT 5,
    default_topn_formula            JSONB NOT NULL,
    default_duration_hours          INT NOT NULL DEFAULT 168,  -- 7 天
    default_edit_lock_hours_before  INT NOT NULL DEFAULT 1,
    target_forum_section_id         INT NOT NULL,           -- 该周期答题落入的论坛板块
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_answer_scores (
    id              SERIAL PRIMARY KEY,
    ai_question_id  INT NOT NULL REFERENCES ai_questions(id) ON DELETE CASCADE,
    forum_post_id   INT NOT NULL,           -- 注意: 不加 FK,允许帖子被删后保留历史
    user_id         VARCHAR(8) NOT NULL,    -- 冗余,防 ForumPost 删后丢追溯
    ai_score        INT,                    -- 0-100
    off_topic       BOOLEAN DEFAULT FALSE,
    ai_generated    VARCHAR(10),            -- low | medium | high
    ai_raw_response JSONB,                  -- 留底
    admin_override_score    INT,
    admin_reviewer_id       VARCHAR(5),
    admin_reviewed_at       TIMESTAMPTZ,
    hide_in_qa              BOOLEAN DEFAULT FALSE,  -- admin 终审"屏蔽"(业务级,不影响该帖在论坛流)
    final_score             INT,            -- COALESCE(admin_override_score, ai_score); hide_in_qa=True 时强制 0
    rank_final              INT,
    reward_pence            INT DEFAULT 0,
    reward_points           INT DEFAULT 0,
    settled_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (ai_question_id, forum_post_id)
);
CREATE INDEX idx_ai_answer_scores_question ON ai_answer_scores(ai_question_id);

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

```
draft ──admin 发布──► published ──deadline──► closed ──AI 评分──► scored ──admin 终审──► settled
                                              │                  │
                                              └─无答案─► closed_empty   │
                                                                 │
                                                                 └─AI 错─► scoring_failed (admin 可重跑)
                                                                                          ↓
                                                                                       重跑后回 scored
                                                                                          ↓
                                                                            admin 发奖失败 → settle_failed
```

## 4. 业务流程

### 4.1 出题管道（admin 监督）

```
ai_qa_cycle_configs.next_run_at ──Celery beat 扫到──► run_qa_cycle(cycle_config_id)
                                                       ├─ AI 用 direction_prompt 生 3-5 候选
                                                       ├─ 写 ai_question_candidates (同一 cycle_run_id)
                                                       ├─ 设置 expired_at = now + 48h
                                                       └─ 通知 admin "新候选题等审核"
                                                              ↓
                                                     admin /admin/ai-qa/candidates
                                                       ├─ 选一题 + 改文案 + 设 deadline/池子
                                                       └─ POST /admin/ai-qa/candidates/{id}/publish
                                                              ↓
                                                     创建 ai_questions (status=published)
                                                     标 chosen=True，其余候选 expired
                                                     更新 cycle.next_run_at
                                                              ↓
                                                     全站通知"新一期问答开放"
```

**超期未审**：beat 跑 `expire_unaudited_candidates`，把 `expired_at < now` 的候选标记作废。

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

**说明**：选第二种（新独立接口）更干净——`/api/ai-qa/{id}/answer` 校验题目状态/截止时间/重复答/锁定后调论坛 CRUD，对前端是一个语义清晰的端点。

### 4.3 评分管道

```
deadline 扫描 beat ── 找 status=published & deadline < now ── 切 closed
                                                              ↓
                                                       拉所有 forum_posts WHERE ai_question_id = X AND is_deleted = False
                                                              ↓
                                                       过滤敏感词命中(现有论坛 hidden 机制) → hide_in_qa
                                                              ↓
                                                       切 status=scoring
                                                       分批送 Claude Sonnet 4.5（每批 10 个,简化 JSON 输出）
                                                              ↓
                                                       写 ai_answer_scores
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
     ├─ 用 admin_override_score (or ai_score) 重算 final_score 排序
     ├─ 调 calc_cash_winners() 得 winner 列表
     ├─ 调 distribute_pool() 得每人金额
     ├─ 写 ai_answer_scores.reward_pence / reward_points / rank_final
     ├─ wallet 入账（reward_pence > 0 的所有人）
     ├─ add_points_transaction（所有未被拉黑答主，含未中奖者）
     ├─ 更新 ai_qa_leaderboard
     └─ 切 ai_questions.status = settled
   ↓
全站推送统一话术："本期问答评分结束,来看看大家的回答"
```

**事务保证**：钱包入账 + 积分 + leaderboard 在同一 DB transaction；失败回滚到 scored 状态，admin 可再点。

## 5. API 设计

### 5.1 用户端

```
GET    /api/ai-qa                          列表（当期 + 历史）
GET    /api/ai-qa/{id}                     详情（含奖金池/倒计时/answers 列表）
GET    /api/ai-qa/{id}/answers             答案列表（按 final_score 降序,settled 后展示金额）
POST   /api/ai-qa/{id}/answer              作答（body: {title, content, images}）
PATCH  /api/ai-qa/{id}/answer              编辑（仅 edit_lock_at 之前）
GET    /api/ai-qa/leaderboard              答主累计榜（top 50）
```

### 5.2 Admin 端

```
GET    /api/admin/ai-qa/cycles             周期配置列表
POST   /api/admin/ai-qa/cycles             新建
PATCH  /api/admin/ai-qa/cycles/{id}        修改（含 direction_prompt）
POST   /api/admin/ai-qa/cycles/{id}/run-now  手动触发出题（linktest 用,因为无 Celery）

GET    /api/admin/ai-qa/candidates         待审候选题（含已过期）
POST   /api/admin/ai-qa/candidates/{id}/publish   发布（body: {title?, content?, deadline, reward_pool_pence?, ...overrides}）
DELETE /api/admin/ai-qa/candidates/{id}    作废候选

GET    /api/admin/ai-qa/questions          所有问答列表（含状态过滤）
GET    /api/admin/ai-qa/questions/{id}/review   终审表格数据
PATCH  /api/admin/ai-qa/scores/{id}        改分（body: {admin_override_score, hide_in_qa?}）
POST   /api/admin/ai-qa/questions/{id}/rescore   重跑 AI 评分
POST   /api/admin/ai-qa/questions/{id}/settle    确认发奖（事务）
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

### 6.2 Admin Web (`admin/`)

新增 3 个页面：

```
/admin/ai-qa/config           周期/Prompt/默认 formula 配置
/admin/ai-qa/candidates       候选题待审
/admin/ai-qa/review/:qid      评分终审（表格 + 改分 + 一键发奖）
```

## 7. 边界 & 错误处理

| 情况 | 处理 |
|---|---|
| 答题人数 = 0 | 题目状态切 `closed_empty`，奖金池不发；钱本来就没动 |
| 答题人数 < 10 但 > 0 | 全员分（按 formula 规则） |
| AI 出题失败 / 超时 | 候选表空，admin 后台显示 "AI 没出题，可手填"；admin 可手动建一道发 |
| AI 评分 API 错 | 切 `scoring_failed`，admin 可点 "重跑评分"；不自动重试（防 API 抖动烧钱） |
| 评分超期 24h admin 没审 | 邮件 escalation；不自动发奖 |
| 帖子被 admin 删 / 用户删 | 同步删 `ai_answer_scores` 对应行，不参与发奖；不影响其他答主 |
| 同人发了 2 个答案（绕过 lock） | 后端 `/api/ai-qa/{id}/answer` 入口去重：返回 409；如绕过入口直接调论坛接口，beat 跑分前去重取最新 |
| 答案触发敏感词 | ForumPost 走现有 hidden 机制（系统级，论坛和问答页都不显示），不计评分 |
| Admin 终审"屏蔽"某答案 | 写 `ai_answer_scores.hide_in_qa=True`（业务级，仅问答页不计分/不展示；该 ForumPost 在论坛流仍正常显示） |
| admin 改分后总额 ≠ 池 | 前端实时校验；后端 settle 前再校验，不一致返回 400 |
| 现金到钱包但用户钱包冻结 | 入账正常，提现走现有钱包冻结逻辑 |
| 候选题 admin 漏审 > 48h | 候选作废；下个周期 beat 重新出 |
| 用户被封号 | 答题入口已被现有封号 middleware 拦截，根本进不来 |

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
| `POST /api/admin/ai-qa/candidates/{id}/publish` | 权限校验 + 候选不存在 + 已发布 |
| `POST /api/ai-qa/{id}/answer` | 状态校验（draft/closed 拒）+ 重复答 + 锁定后拒 + 板块自动绑 |
| `POST /api/admin/ai-qa/scores/{id}` 改分 | 权限 + 改分后总额刷新 |
| `POST /api/admin/ai-qa/questions/{id}/settle` | 事务一致性（强制 wallet 写失败 → 全回滚） |

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
| **P0 — MVP** | 表 + admin 后台手动建题 + 用户答题 + AI 评分 + admin 终审 + 发奖；**不接 Celery 出题**（手动建即可，验证产品形态） |
| **P1** | 接 Celery 出题 + admin prompt 编辑 + 候选题审核流 |
| **P2** | Flutter 入口（discovery + activities）+ 答主排行榜 + 通知优化 |
| **P3** | Admin 数据看板（参与率/平均分/答题分布） |

solo 项目直推 main，不开 feature 分支（参考 `feedback_direct_to_main`）。

## 10. 风险 & 决策记录

| 风险 | 决策 |
|---|---|
| AI 评分不稳一致 | 接受——人工终审是兜底；评分只跑一次，重跑需 admin 显式点 |
| Stripe 高频低额提现成本 | 不直发 Stripe，全部进钱包；提现门槛 5 GBP |
| 0 人答题尴尬 | 题目状态 closed_empty 不发奖；不滚下期（钱本来就没动） |
| 论坛流被 AI 问答帖子刷屏 | 帖子量受答题人数限制，比一般用户 UGC 量小；不专门做隔离 |
| 用户绕过 `/api/ai-qa/{id}/answer` 直接调论坛接口塞 ai_question_id | beat 评分前后端去重 + 后期可加论坛侧入口审计 |

## 11. 不在本期范围

- 跨题目的答主声望系统（仅做累计奖金/次数榜）
- 用户对答案的点赞/反对加权评分（避免拉票）
- 答案二级评论加分
- 移动端 Web 入口（先做 Flutter 即可，Web 仅 admin）
- 出题语义去重（避免 AI 出过类似题目）—— P2 之后再加

## 附录 A: 相关 memory 引用

- [`feedback_scheduled_tasks_celery_sync`] —— scheduled_tasks 必须同步加 Celery 包装
- [`architecture_celery_linktest_vs_prod`] —— linktest 无 Celery
- [`feedback_migration_before_deploy`] —— 加列 migration 先跑 DB 再 push
- [`project_ai_model_setup`] —— GLM-4.7-FlashX 出题，Claude Sonnet 4.5 评分
- [`project_admin_ai_prompt_editor`] —— prompt 走 DB，admin 后台改
- [`feedback_direct_to_main`] —— solo 项目直推 main
- [`feedback_db_migration`] —— 编号 SQL migration 文件
