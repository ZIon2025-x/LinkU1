# 新手任务与用户激励系统设计

> 日期：2026-03-08
> 状态：设计阶段

## 一、目标

核心目标：**促进用户主动曝光自己的技能和生活**，形成"曝光 → 被发现 → 收到指定任务"的闭环。

具体目标：
1. 引导新用户完善身份信息，提高个人资料完整度
2. 推动用户通过论坛、跳蚤市场等渠道展示自己
3. 通过技能排行榜建立分类口碑，让优秀用户被看见
4. 官方运营任务引导用户产出优质内容

## 二、系统组成

本方案包含四个子系统：

1. **新手任务中心** — 阶段性引导任务 + 积分/优惠券奖励
2. **官方任务** — 运营动态发布的主题内容任务
3. **技能排行榜** — 按技能分类的用户排名
4. **勋章系统** — 仅技能排行榜 Top N 用户获得，显示在头像旁

---

## 三、新手任务中心

### 3.1 入口与呈现

- **首页 Banner**：管理员在后台创建一张 Banner，跳转路径指向新手任务中心路由（如 `/newbie-tasks`），作为轮播 Banner 的其中一张
- **任务中心页面**：完整的任务列表，分阶段展示，每个任务显示完成状态和奖励预览
- 入口也可从个人中心进入

### 3.2 适用范围

- **所有用户均可参与**（包括老用户）
- 老用户已完成的动作（如已上传头像、已发过帖子）自动标记为"可领取"，用户进入任务中心即可领取奖励
- 首次打开任务中心时，后端批量检测已完成的任务

### 3.3 完成机制

- **自动检测**：后端追踪用户行为，满足条件自动标记任务为"可领取"
- **手动领取**：用户在任务中心点击"领取奖励"，增加仪式感和回访动力
- 领取时后端二次校验，防止作弊
- **通知推送**：任务完成时推送多语言通知（如"你已完成'上传头像'任务，快去领取50积分！"）

### 3.4 任务清单与奖励

> 以下积分数值为默认值，管理员可在后台配置表中修改。

#### 第一阶段：完善身份

| 任务 | 检测条件 | 奖励 |
|------|----------|------|
| 上传头像 | `user.avatar` 非预设头像（用户上传了自己的头像） | 50 积分 |
| 填写个人简介 | `user.bio` 非空且长度 >= 10 | 50 积分 |
| 添加至少 3 个技能标签 | `user_skills` 记录数 >= 3 | 100 积分 |
| 完成学生认证 | `user.is_student_verified = true` | 200 积分 |
| **阶段完成奖励** | 以上全部完成 | +100 积分 bonus |

第一阶段总计：最高 **500 积分（£5.00）**

#### 第二阶段：开始曝光

| 任务 | 检测条件 | 奖励 |
|------|----------|------|
| 发布第一个论坛帖子 | `forum_posts` 中有该用户的帖子 | 200 积分 |
| 跳蚤市场发布第一个商品/服务 | `flea_items` 中有该用户的商品 | 200 积分 |
| 参加一个活动 | `activity_applications` 中有记录 | 200 积分 |
| **阶段完成奖励** | 以上全部完成 | 首单 8 折优惠券 |

第二阶段总计：**600 积分 + 优惠券**

#### 第三阶段：长期成就

| 成就 | 检测条件 | 奖励 |
|------|----------|------|
| 累计发帖 5 个 | `forum_posts` count >= 5 | 300 积分 |
| 累计发帖 20 个 | `forum_posts` count >= 20 | 500 积分 |
| 收到第一个指定任务 | 有 task 的 `assigned_to = user_id` | 500 积分 |
| 完成 5 个任务且好评 | 已完成 task count >= 5 且 avg_rating >= 4 | 500 积分 |
| 主页被浏览 50 次 | `profile_views` count >= 50 | 300 积分 |
| 主页被浏览 200 次 | `profile_views` count >= 200 | 500 积分 |
| 连续签到 7 天 | 复用现有签到系统 streak >= 7 | 200 积分 |
| 连续签到 30 天 | 复用现有签到系统 streak >= 30 | 500 积分 |

---

## 四、官方任务

### 4.1 概念

运营通过后台动态发布主题任务，如"分享你的英国生活"、"分享住宿体验"、"推荐生活攻略"等。

**官方任务只出现在新手任务中心**，不出现在任务大厅（任务大厅是用户之间的付费任务）。

### 4.2 任务类型与完成方式

| 任务类型 | 场景示例 | 完成方式 |
|----------|----------|----------|
| **论坛帖子类** | "分享你的英国生活"、"分享住宿体验" | 发帖时关联官方任务 + 话题标签，**自动检测完成** |
| **跳蚤市场类** | "出闲置活动" | 用户完成后联系客服，**管理员手动发奖** |
| **任务大厅类** | "发布一个设计类任务" | 用户完成后联系客服，**管理员手动发奖** |

只有论坛帖子有关联功能，其他类型通过管理员手动发奖完成。

### 4.3 用户流程（论坛帖子类）

1. 用户在任务中心看到官方任务卡片（标注"官方"标签）
2. 点击查看任务详情和要求
3. 去论坛发帖，发帖时选择关联的官方任务，帖子自动带上指定话题标签
4. 发帖成功后任务自动标记为"可领取"
5. 回到任务中心领取奖励

**注意**：不需要"接任务"步骤，直接发帖关联即可。

### 4.4 用户流程（跳蚤市场/任务大厅类）

1. 用户在任务中心看到官方任务卡片
2. 按要求去跳蚤市场发布商品或去任务大厅发布任务
3. 完成后联系客服或发邮件
4. 管理员审核后手动发放奖励（见 4.7）

### 4.5 规则

- 每个官方任务有**次数限制**（如每人最多参与 1 次或 N 次，运营可配置）
- 每个官方任务有有效期（开始/结束时间）
- 奖励由运营自定义（积分金额 / 指定优惠券）
- 论坛帖子必须带指定话题标签才算关联成功

### 4.6 后台管理

运营可以：
- 创建/编辑/下架官方任务
- 设置标题、描述、话题标签、奖励类型和金额
- 设置任务类型（论坛帖子类/跳蚤市场类/任务大厅类）
- 设置每人参与次数上限
- 设置有效期
- 查看参与统计（参与人数、提交数）

### 4.7 管理员手动发奖

管理员可在后台给**指定用户**手动发放奖励，用于无法自动检测的场景：

- 搜索用户（按名称 / ID / 邮箱）
- 选择奖励类型（积分 / 指定优惠券）
- 填写积分金额
- 填写发放原因（备注）
- 所有手动发放记录可查询、可追溯

---

## 五、技能排行榜

### 5.1 排名规则

- 按技能分类排名（如：设计、翻译、编程、摄影、家教等）
- 分类来源：系统预设的技能标签分类
- 计算依据（按优先级排序）：
  1. **该分类下完成的任务数**（主要权重）
  2. **该分类下任务的总金额**（区分高价值任务）
  3. **该分类下的平均评分**（质量指标）
- 排名公式：`score = completed_tasks * 50 + total_amount_gbp * 2 + avg_rating * 10`
  - 任务数权重最高：10 个任务 = 500 分
  - 总金额次之：£100 = 200 分
  - 评分辅助：5.0 满分 = 50 分
  - 公式可由管理员调整权重参数
- 定期更新（每日凌晨重算）
- 展示 **Top 10**

### 5.2 展示

- 可从发现/社区页面进入技能排行榜
- 按分类 Tab 切换查看
- 每个分类展示 Top 10
- 展示用户头像、名称、完成任务数、总金额、评分、勋章

---

## 六、勋章系统

### 6.1 规则

- **只有技能排行榜 Top 10 用户获得勋章**，无其他类型勋章
- 勋章名称随分类，如"设计 Top10"、"翻译 Top10"
- **动态更新**：每日排行榜重算后，掉出 Top 10 的用户失去勋章
- 一个用户可在多个分类上榜，获得多个勋章

### 6.2 展示

- **个人主页**：展示所有获得的勋章
- **头像旁**：用户选择一个主要勋章显示在头像旁（论坛帖子、任务列表等公开场景可见）
- 只有技能排行榜勋章可以显示在头像旁，新手任务/成就不产出勋章

---

## 七、数据库变更

### 7.1 User 表新增字段

```
bio          TEXT       -- 个人简介（当前缺失）
profile_views INTEGER   -- 主页浏览次数（或单独建表记录明细）
```

### 7.2 新增表

#### user_skills — 用户技能标签

```
id              INTEGER PRIMARY KEY
user_id         INTEGER FK -> users.id
skill_category  VARCHAR(50)   -- 技能分类（设计/翻译/编程等）
skill_name      VARCHAR(100)  -- 具体技能名
created_at      DATETIME
UNIQUE(user_id, skill_name)
```

#### newbie_task_config — 新手任务奖励配置表（管理员可修改）

```
id              INTEGER PRIMARY KEY
task_key        VARCHAR(50) UNIQUE  -- 任务标识（如 'upload_avatar', 'first_post'）
stage           INTEGER       -- 所属阶段：1, 2, 3
title_zh        VARCHAR(200)  -- 任务名称（中文）
title_en        VARCHAR(200)  -- 任务名称（英文）
description_zh  TEXT          -- 任务描述（中文）
description_en  TEXT          -- 任务描述（英文）
reward_type     VARCHAR(20)   -- points / coupon
reward_amount   INTEGER       -- 积分数（pence）
coupon_id       INTEGER FK -> coupons.id (nullable)
display_order   INTEGER       -- 排序
is_active       BOOLEAN DEFAULT true
created_at      DATETIME
updated_at      DATETIME
```

#### stage_bonus_config — 阶段奖励配置表（管理员可修改）

```
id              INTEGER PRIMARY KEY
stage           INTEGER UNIQUE  -- 阶段：1, 2, 3
title_zh        VARCHAR(200)
title_en        VARCHAR(200)
reward_type     VARCHAR(20)   -- points / coupon
reward_amount   INTEGER       -- 积分数（pence）
coupon_id       INTEGER FK -> coupons.id (nullable)
is_active       BOOLEAN DEFAULT true
updated_at      DATETIME
```

#### user_tasks_progress — 新手任务进度（用户维度）

```
id              INTEGER PRIMARY KEY
user_id         INTEGER FK -> users.id
task_key        VARCHAR(50)   -- 关联 newbie_task_config.task_key
status          VARCHAR(20)   -- pending / completed / claimed
completed_at    DATETIME
claimed_at      DATETIME
UNIQUE(user_id, task_key)
```

#### stage_bonus_progress — 阶段奖励进度

```
id              INTEGER PRIMARY KEY
user_id         INTEGER FK -> users.id
stage           INTEGER       -- 1, 2, 3
status          VARCHAR(20)   -- pending / completed / claimed
claimed_at      DATETIME
UNIQUE(user_id, stage)
```

#### official_tasks — 官方任务（运营后台管理）

```
id              INTEGER PRIMARY KEY
title_zh        VARCHAR(200)
title_en        VARCHAR(200)
description_zh  TEXT
description_en  TEXT
topic_tag       VARCHAR(50)   -- 关联的话题标签（论坛帖子用）
task_type       VARCHAR(20)   -- forum_post / flea_item / task（标识任务类型，仅 forum_post 支持自动关联）
reward_type     VARCHAR(20)   -- points / coupon
reward_amount   INTEGER       -- 积分数（pence）
coupon_id       INTEGER FK -> coupons.id (nullable)
max_per_user    INTEGER       -- 每人最多参与次数
valid_from      DATETIME
valid_until     DATETIME
is_active       BOOLEAN DEFAULT true
created_by      INTEGER FK -> admin_users.id
created_at      DATETIME
updated_at      DATETIME
```

#### official_task_submissions — 用户参与官方任务记录

```
id              INTEGER PRIMARY KEY
user_id         INTEGER FK -> users.id
official_task_id INTEGER FK -> official_tasks.id
forum_post_id   INTEGER FK -> forum_posts.id  -- 关联的帖子（仅论坛帖子类任务）
status          VARCHAR(20)   -- submitted / claimed
submitted_at    DATETIME
claimed_at      DATETIME
reward_amount   INTEGER
```

#### admin_reward_logs — 管理员手动发奖记录

```
id              INTEGER PRIMARY KEY
admin_id        INTEGER FK -> admin_users.id
user_id         INTEGER FK -> users.id
reward_type     VARCHAR(20)   -- points / coupon
points_amount   INTEGER       -- 积分数（pence），nullable
coupon_id       INTEGER FK -> coupons.id (nullable)
reason          TEXT          -- 发放原因/备注
created_at      DATETIME
```

#### skill_leaderboard — 技能排行榜（定期重算）

```
id              INTEGER PRIMARY KEY
skill_category  VARCHAR(50)   -- 技能分类
user_id         INTEGER FK -> users.id
completed_tasks INTEGER       -- 该分类下完成的任务数
total_amount    INTEGER       -- 该分类下任务总金额（pence）
avg_rating      FLOAT         -- 该分类下的平均评分
score           FLOAT         -- 综合得分
rank            INTEGER       -- 排名
updated_at      DATETIME
UNIQUE(skill_category, user_id)
```

#### user_badges — 用户勋章

```
id              INTEGER PRIMARY KEY
user_id         INTEGER FK -> users.id
badge_type      VARCHAR(50)   -- 'skill_rank'
skill_category  VARCHAR(50)   -- 技能分类
rank            INTEGER       -- Top N 中的名次
is_displayed    BOOLEAN DEFAULT false  -- 是否设为头像旁展示
granted_at      DATETIME
UNIQUE(user_id, skill_category)
```

### 7.3 现有表变更

#### forum_posts 新增字段

```
official_task_id  INTEGER FK -> official_tasks.id (nullable)
-- 关联官方任务，发帖时选择
```


#### API 接口变更

PATCH `/profile` 接口需支持 `bio` 和 `skills` 更新。

---

## 八、API 接口设计

### 8.1 新手任务

```
GET  /api/tasks-progress              -- 获取用户所有任务进度
POST /api/tasks-progress/{task_key}/claim  -- 领取奖励
GET  /api/tasks-progress/stages       -- 获取阶段完成状态
POST /api/tasks-progress/stages/{stage}/claim  -- 领取阶段奖励
```

### 8.2 官方任务

```
GET  /api/official-tasks              -- 获取可用官方任务列表
GET  /api/official-tasks/{id}         -- 官方任务详情
POST /api/official-tasks/{id}/submit  -- 提交（content_type + content_id）
POST /api/official-tasks/{id}/claim   -- 领取奖励
```

### 8.3 技能排行榜

```
GET  /api/leaderboard/skills                    -- 获取所有技能分类
GET  /api/leaderboard/skills/{category}         -- 获取某分类排行榜
GET  /api/leaderboard/skills/{category}/my-rank -- 获取我的排名
```

### 8.4 勋章

```
GET  /api/badges/my                   -- 获取我的勋章列表
PUT  /api/badges/{id}/display         -- 设置/取消头像旁展示
GET  /api/users/{id}/badges           -- 获取某用户的勋章（公开）
```

### 8.5 用户资料扩展

```
PATCH /api/profile        -- 扩展支持 bio, skills 字段
GET   /api/skills/categories  -- 获取系统预设技能分类列表
```

### 8.6 后台管理

```
POST   /api/admin/official-tasks          -- 创建官方任务
PUT    /api/admin/official-tasks/{id}     -- 编辑官方任务
DELETE /api/admin/official-tasks/{id}     -- 下架官方任务
GET    /api/admin/official-tasks/{id}/stats -- 参与统计
POST   /api/admin/leaderboard/refresh     -- 手动触发排行榜重算
GET    /api/admin/skill-categories        -- 管理技能分类
POST   /api/admin/skill-categories        -- 新增技能分类
```

### 8.7 管理员手动发奖

```
POST /api/admin/rewards/send             -- 给指定用户发放积分/优惠券
GET  /api/admin/rewards/logs             -- 查询手动发奖记录
```

### 8.8 签到奖励管理

```
GET  /api/admin/checkin/rewards          -- 获取签到奖励配置列表
PUT  /api/admin/checkin/rewards/{id}     -- 修改签到奖励（积分数值等）
POST /api/admin/checkin/rewards          -- 新增签到奖励配置
```

### 8.9 新手任务奖励配置

```
GET  /api/admin/newbie-tasks/config      -- 获取所有新手任务配置（含文案和奖励）
PUT  /api/admin/newbie-tasks/config/{task_key}  -- 修改某任务的奖励数值/文案
GET  /api/admin/stage-bonus/config       -- 获取阶段奖励配置
PUT  /api/admin/stage-bonus/config/{stage}     -- 修改阶段奖励
```

---

## 九、Flutter 前端结构

### 9.1 新增 Feature 模块

```
lib/features/
├── newbie_tasks/
│   ├── bloc/
│   │   ├── newbie_tasks_bloc.dart
│   │   ├── newbie_tasks_event.dart
│   │   └── newbie_tasks_state.dart
│   └── views/
│       ├── newbie_tasks_center_view.dart    -- 任务中心主页
│       ├── newbie_task_card.dart            -- 首页进度卡片
│       └── widgets/
│           ├── task_item_widget.dart
│           ├── stage_progress_widget.dart
│           └── official_task_card.dart
├── skill_leaderboard/
│   ├── bloc/
│   │   ├── skill_leaderboard_bloc.dart
│   │   ├── skill_leaderboard_event.dart
│   │   └── skill_leaderboard_state.dart
│   └── views/
│       ├── skill_leaderboard_view.dart     -- 排行榜主页
│       └── widgets/
│           └── leaderboard_item_widget.dart
└── badges/
    ├── bloc/
    │   ├── badges_bloc.dart
    │   ├── badges_event.dart
    │   └── badges_state.dart
    └── views/
        ├── badges_display_view.dart        -- 个人主页勋章展示
        └── badge_selector_dialog.dart      -- 选择展示勋章
```

### 9.2 新增 Repository

```
lib/data/repositories/
├── newbie_tasks_repository.dart
├── skill_leaderboard_repository.dart
└── badges_repository.dart
```

### 9.3 新增/修改 Model

```
lib/data/models/
├── newbie_task.dart           -- 新手任务进度模型
├── official_task.dart         -- 官方任务模型
├── skill_leaderboard.dart     -- 排行榜条目模型
├── badge.dart                 -- 勋章模型
├── skill_category.dart        -- 技能分类模型
└── user.dart                  -- 新增 bio, skills, displayedBadge 字段
```

### 9.4 现有页面修改

- **首页** (`home_view.dart`)：顶部插入新手任务进度卡片
- **个人主页** (`profile_view.dart`)：添加勋章展示区
- **编辑资料页**：新增 bio 编辑、技能标签管理
- **论坛发帖页**：新增"关联官方任务"选择器和话题标签
- **用户头像组件**：支持在头像旁显示勋章标识

---

## 十、管理员前端（React Admin）

### 10.1 新增页面

| 页面 | 功能 |
|------|------|
| **签到奖励管理** | 查看/修改每天签到获得的积分数值 |
| **官方任务管理** | 创建/编辑/下架官方任务，设置关联类型、奖励、次数限制、有效期 |
| **官方任务统计** | 查看某个官方任务的参与人数、提交数 |
| **手动发奖** | 搜索用户，给指定用户发放积分或优惠券，填写原因 |
| **发奖记录** | 查看所有手动发奖的历史记录 |
| **技能分类管理** | 增删改系统预设的技能分类 |
| **排行榜管理** | 查看各分类排行榜，手动触发重算 |
| **新手任务奖励配置** | 修改每个新手任务的积分数值 |

---

## 十一、实现优先级建议

1. **P0 — 基础设施**：User 表加 bio，新建 user_skills 表，PATCH /profile 扩展
2. **P1 — 新手任务系统**：任务进度表 + 检测逻辑 + 领取接口 + 任务中心页面
3. **P2 — 官方任务**：官方任务表 + 后台管理 + 论坛帖子关联 + 前端展示
4. **P3 — 管理员工具**：签到奖励管理 + 手动发奖 + 新手任务奖励配置
5. **P4 — 技能排行榜**：排行榜计算 + 展示页面
6. **P5 — 勋章系统**：勋章表 + 头像旁展示 + 个人主页勋章墙
