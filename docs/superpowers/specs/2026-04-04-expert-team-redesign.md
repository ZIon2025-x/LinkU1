# 达人团队体系重设计

## 概述

将达人（Expert）从"个人身份"升级为"团队实体"，支持多用户关联、团队协作、达人板块、内部群聊，并清理现有架构中的数据冗余和职责混乱问题。

## 设计决策总览

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | 达人创建流程 | 管理员审核制，每次创建都审核 |
| 2 | 团队角色 | Owner / Admin / Member 三级 |
| 3 | 加入方式 | 邀请 + 申请，达人可关闭申请入口 |
| 4 | 任务聊天升级 | 原地升级为多人聊天，历史消息对新成员可见 |
| 5 | 身份切换 | 按场景自动关联，无全局切换 |
| 6 | 员工聊天权限 | 只能聊天，无业务操作权限 |
| 7 | 对外展示 | 团队品牌 |
| 8 | 数据迁移 | 自动迁移，用户无感 |
| 9 | 团队上限 | 20 人 |
| 10 | 达人 ID | 8 位随机字符串 |
| 11 | 统计数据 | 存 experts 表，事件触发更新 |
| 12 | 信息修改 | 保留管理员审核 |
| 13 | 邀请进聊天 | Owner / Admin 可邀请团队成员 |
| 14 | 聊天信息可见性 | 全部可见，含价格协商 |
| 15 | 个人服务 | 保留，统一 services 表多态 owner |
| 16 | 角色变更 | Owner 可提升/降级/转让 |
| 17 | 权限分配 | Owner 全权，Admin 管理服务+活动+申请，Member 仅聊天 |
| 18 | 达人板块 | 达人专属论坛板块，类型为"达人"，公开可见 |
| 19 | 板块发帖权 | 仅团队成员可发帖，所有人可评论/回复 |
| 20 | 帖子作者显示 | "团队名 · 个人名" |
| 21 | 达人内部群聊 | 纯内部，成员自动同步，私密 |
| 22 | 服务咨询回复 | Owner/Admin 都能回复，需要 Member 协助时邀请进聊天 |
| 23 | 咨询通知 | 通知所有 Owner + Admin |
| 24 | 关注体系 | 关注达人和关注用户分开，新增 expert_follows 表 |
| 25 | 评价体系 | reviews 表新增 expert_id 字段，达人评价和普通评价共表区分 |
| 26 | 达人服务审核 | 不需要审核，Owner/Admin 可自行创建和编辑 |
| 27 | 达人活动审核 | 需要管理员审核 |
| 28 | 拼单模式 | 活动支持拼单，N 人成单，在 activities 表上扩展字段 |
| 29 | 拼单付款 | Stripe 预授权，成单后扣款，未成单自动释放 |
| 30 | 拼单进度 | 完全公开，显示"已拼 X/N 人" |
| 31 | 拼单成单后任务 | 达人自选：每人独立任务 或 一个多人任务 |
| 32 | 拼单轮次 | 达人自选：单轮 或 多轮自动开 |
| 33 | 拼单截止 | 达人自选：设截止日期 或 不设时间限制 |
| 34 | 拼单取消 | 成单前用户可随时取消，预授权自动释放 |
| 35 | 活动奖励 | 暂停现金返现，只保留积分奖励 |
| 36 | 达人收款 | 达人团队独立 Stripe Connect 账户，不用 Owner 个人账户 |
| 37 | 达人注销 | 有进行中任务不可注销；注销时服务自动下架，板块帖子隐藏 |
| 38 | 成员退出 | 自动移出内部群聊和所有任务聊天；Owner 始终保留在每个达人任务聊天中 |
| 39 | 活动关联服务 | 不强制；不关联服务的活动可用 lottery/first_come 类型 |
| 40 | 套餐/次卡 | services 表加 package_type 字段，支持单次/次卡/组合套餐 |
| 41 | 员工分配 | 不做系统级分配，咨询时自行协商 |
| 42 | 评价回复 | reviews 表加 reply_content/reply_at/reply_by 字段 |
| 43 | 达人优惠券 | coupons 表加 expert_id 字段，达人自行创建管理，免审核 |
| 44 | 达人多语言 | experts 表支持 name/bio 的中英文字段 |
| 45 | 达人板块展示 | 论坛独立"达人"Tab，不和其他板块混排 |
| 46 | 关注 feed 联动 | 关注达人后，动态流推送该达人新帖 |
| 47 | 达人搜索 | 独立达人搜索 + 服务搜索间接发现 |
| 48 | 达人板块命名 | 达人可自由编辑板块名称和描述，无需审核 |

## 现有架构问题

### 1. `TaskExpert` 与 `FeaturedTaskExpert` 数据冗余

`FeaturedTaskExpert` 大量复制 `TaskExpert` 和 `User` 的字段（name、avatar、bio、rating、completedTasks 等），两张表数据容易不同步。`FeaturedTaskExpert` 本质上只是"是否推荐 + 排序"的标记，不应该存实体数据。

### 2. `TaskExpert.id = user.id` 硬绑定

达人和用户共用主键，无法解耦，无法支持多人团队。

### 3. `TaskExpertService` 混合两种业务

`service_type` 分 `personal` 和 `expert`，一张表承载两种不同业务。`expert_id` 和 `user_id` 二选一的 nullable 设计不干净。

### 4. 统计数据散落

`rating`、`completed_tasks` 在 `TaskExpert` 上有一份，`avg_rating`、`completed_tasks`、`completion_rate`、`success_rate` 在 `FeaturedTaskExpert` 上又有一份。定时任务同步两边容易漂移。

## 新架构

### 分层设计

```
┌─ 展示层 ──────────────────────────────────────────┐
│  featured_experts (纯展示控制：expert_id + 排序)    │
├─ 团队层 ──────────────────────────────────────────┤
│  experts (独立实体，8位随机ID)                       │
│  expert_members (user ↔ expert 多对多 + 角色)       │
│  expert_applications (创建达人审核)                  │
│  expert_join_requests (申请加入团队)                 │
│  expert_invitations (邀请加入团队)                   │
│  expert_profile_update_requests (修改信息审核)       │
│  expert_closed_dates (关门日期)                      │
├─ 服务层 ──────────────────────────────────────────┤
│  services (统一服务表，多态 owner_type + owner_id)   │
│  service_applications (服务申请/协商)                │
│  service_time_slots (时间段)                        │
├─ 互动层 ──────────────────────────────────────────┤
│  forum_categories (达人板块，type='expert')          │
│  forum_posts (达人发帖，expert_id 标识团队身份)       │
│  chat_groups (达人内部群聊，type='expert_internal')   │
├─ 聊天层 ──────────────────────────────────────────┤
│  chat_participants (任务聊天多人化)                   │
└───────────────────────────────────────────────────┘
```

### 关系总览

```
users (many) ←→ (many) experts       [通过 expert_members]
experts (1) → (many) services         [owner_type='expert']
users (1) → (many) services           [owner_type='user', 个人服务]
experts (1) → (1) forum_categories    [type='expert']
experts (1) → (1) chat_groups         [type='expert_internal']
experts (1) → (0..1) featured_experts [展示控制]
```

## 数据模型

### `experts`（取代 `task_experts`）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(8) PK | 随机字符串，独立于用户 ID |
| name | VARCHAR(100) NOT NULL | 团队品牌名称 |
| name_en | VARCHAR(100) | 英文名称 |
| name_zh | VARCHAR(100) | 中文名称 |
| bio | TEXT | 团队简介 |
| bio_en | TEXT | 英文简介 |
| bio_zh | TEXT | 中文简介 |
| avatar | TEXT | 团队头像 URL |
| status | VARCHAR(20) DEFAULT 'active' | active / inactive / suspended / dissolved |
| stripe_account_id | VARCHAR(255), nullable | Stripe Connect 账户 ID |
| stripe_connect_country | VARCHAR(10), nullable | Stripe Connect 国家 |
| stripe_onboarding_complete | BOOL DEFAULT false | Stripe 入驻是否完成 |
| allow_applications | BOOL DEFAULT true | 是否开放申请加入团队 |
| max_members | INT DEFAULT 20 | 成员上限 |
| member_count | INT DEFAULT 1 | 当前成员数（冗余，事件更新） |
| rating | DECIMAL(3,2) DEFAULT 0 | 平均评分（事件更新） |
| total_services | INT DEFAULT 0 | 服务数（事件更新） |
| completed_tasks | INT DEFAULT 0 | 完成任务数（事件更新） |
| completion_rate | FLOAT DEFAULT 0 | 完成率（事件更新） |
| is_official | BOOL DEFAULT false | 官方认证标记 |
| official_badge | VARCHAR(50) | 认证徽章文本 |
| forum_category_id | INT FK → forum_categories | 达人板块（创建时自动生成） |
| internal_group_id | INT FK → chat_groups | 内部群聊（创建时自动生成） |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

索引：
- `ix_experts_status` (status)
- `ix_experts_rating` (rating)

### `expert_members`（新表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| expert_id | VARCHAR(8) FK → experts ON DELETE CASCADE | 达人团队 |
| user_id | VARCHAR(8) FK → users ON DELETE CASCADE | 用户 |
| role | VARCHAR(20) NOT NULL | owner / admin / member |
| status | VARCHAR(20) DEFAULT 'active' | active / left / removed |
| joined_at | DATETIME | 加入时间 |
| updated_at | DATETIME | 状态变更时间 |

约束：
- `UNIQUE(expert_id, user_id)`

索引：
- `ix_expert_members_user` (user_id) WHERE status = 'active'
- `ix_expert_members_expert_role` (expert_id, role) WHERE status = 'active'

### `expert_applications`（取代 `task_expert_applications`）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| user_id | VARCHAR(8) FK → users | 申请人 |
| expert_name | VARCHAR(100) NOT NULL | 申请的团队名称 |
| bio | TEXT | 申请的团队简介 |
| avatar | TEXT | 申请的团队头像 |
| application_message | TEXT | 申请理由 |
| status | VARCHAR(20) DEFAULT 'pending' | pending / approved / rejected |
| reviewed_by | VARCHAR(5) FK → admin_users | 审核人 |
| reviewed_at | DATETIME | 审核时间 |
| review_comment | TEXT | 审核意见 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

审核通过后自动执行：
1. 创建 `experts` 记录（生成 8 位 ID）
2. 创建 `expert_members` 记录（user_id = 申请人，role = 'owner'）
3. 创建 `forum_categories` 记录（type = 'expert'，name = 团队名称）
4. 创建 `chat_groups` 记录（type = 'expert_internal'，自动加入 owner）
5. 关联 `experts.forum_category_id` 和 `experts.internal_group_id`

索引：
- `ix_expert_applications_user_status` (user_id, status)
- Partial unique: 每个用户同时只能有一个 pending 申请

### `expert_join_requests`（新表：申请加入团队）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| expert_id | VARCHAR(8) FK → experts | 目标团队 |
| user_id | VARCHAR(8) FK → users | 申请人 |
| message | TEXT | 申请理由 |
| status | VARCHAR(20) DEFAULT 'pending' | pending / approved / rejected |
| reviewed_by | VARCHAR(8) FK → users | 审批人（Owner/Admin） |
| created_at | DATETIME | 申请时间 |
| reviewed_at | DATETIME | 审批时间 |

审批通过后自动执行：
1. 创建 `expert_members` 记录（role = 'member'）
2. 更新 `experts.member_count`
3. 将用户加入达人内部群聊 `chat_groups`

约束：
- Partial unique: 每个用户对每个团队同时只能有一个 pending 请求

### `expert_invitations`（新表：邀请加入团队）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| expert_id | VARCHAR(8) FK → experts | 达人团队 |
| inviter_id | VARCHAR(8) FK → users | 邀请人（Owner/Admin） |
| invitee_id | VARCHAR(8) FK → users | 被邀请人 |
| status | VARCHAR(20) DEFAULT 'pending' | pending / accepted / rejected / expired |
| created_at | DATETIME | 邀请时间 |
| responded_at | DATETIME | 响应时间 |

接受邀请后自动执行：
1. 创建 `expert_members` 记录（role = 'member'）
2. 更新 `experts.member_count`
3. 将用户加入达人内部群聊 `chat_groups`

约束：
- Partial unique: `UNIQUE(expert_id, invitee_id)` WHERE status = 'pending'

### `expert_follows`（新表：关注达人）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| user_id | VARCHAR(8) FK → users ON DELETE CASCADE | 关注者 |
| expert_id | VARCHAR(8) FK → experts ON DELETE CASCADE | 被关注的达人 |
| created_at | DATETIME | 关注时间 |

约束：
- `UNIQUE(user_id, expert_id)`

索引：
- `ix_expert_follows_user` (user_id)
- `ix_expert_follows_expert` (expert_id)

与现有 `user_follows`（用户关注用户）完全独立，互不影响。

### `expert_profile_update_requests`（保留，改关联）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| expert_id | VARCHAR(8) FK → experts | 达人团队 |
| requester_id | VARCHAR(8) FK → users | 请求人（必须是 Owner） |
| new_name | VARCHAR(100) | 新名称 |
| new_bio | TEXT | 新简介 |
| new_avatar | TEXT | 新头像 |
| status | VARCHAR(20) DEFAULT 'pending' | pending / approved / rejected |
| reviewed_by | VARCHAR(5) FK → admin_users | 审核人 |
| reviewed_at | DATETIME | 审核时间 |
| review_comment | TEXT | 审核意见 |
| created_at | DATETIME | 创建时间 |

审核通过后自动更新 `experts` 表对应字段及关联的 `forum_categories` 板块名称。

### `expert_closed_dates`（保留，改 FK）

结构不变，`expert_id` FK 指向新的 `experts.id`。

### `featured_experts`（取代 `featured_task_experts`）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| expert_id | VARCHAR(8) FK → experts, UNIQUE | 达人团队 |
| is_featured | BOOL DEFAULT true | 是否展示 |
| display_order | INT DEFAULT 0 | 排序权重 |
| category | VARCHAR(50) | 展示分类标签 |
| created_by | VARCHAR(5) FK → admin_users | 操作管理员 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

**不再复制任何实体数据**。展示时 JOIN `experts` 表获取 name/bio/avatar/rating 等。

### `services`（取代 `task_expert_services`）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| owner_type | VARCHAR(20) NOT NULL | 'expert' / 'user' |
| owner_id | VARCHAR(8) NOT NULL | experts.id 或 users.id |
| service_name | VARCHAR(200) NOT NULL | 服务名称 |
| service_name_en | VARCHAR(200) | 英文名称 |
| service_name_zh | VARCHAR(200) | 中文名称 |
| description | TEXT NOT NULL | 服务描述 |
| description_en | TEXT | 英文描述 |
| description_zh | TEXT | 中文描述 |
| images | JSONB | 图片 URL 列表 |
| base_price | DECIMAL(12,2) NOT NULL | 基础价格 |
| currency | VARCHAR(3) DEFAULT 'GBP' | 货币 |
| pricing_type | VARCHAR(20) DEFAULT 'fixed' | fixed / negotiable |
| location_type | VARCHAR(20) DEFAULT 'online' | online / in_person / both |
| location | VARCHAR(255) | 地点描述 |
| latitude | DECIMAL(10,8) | 纬度 |
| longitude | DECIMAL(11,8) | 经度 |
| skills | JSONB | 技能标签数组 |
| category | VARCHAR(50) | 服务分类 |
| status | VARCHAR(20) DEFAULT 'active' | active / inactive / pending |
| display_order | INT DEFAULT 0 | 排序 |
| view_count | INT DEFAULT 0 | 浏览数 |
| application_count | INT DEFAULT 0 | 申请数 |
| has_time_slots | BOOL DEFAULT false | 是否启用时间段 |
| time_slot_duration_minutes | INT | 时间段时长 |
| participants_per_slot | INT | 每段人数上限 |
| weekly_time_slot_config | JSONB | 每周时间段配置 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

索引：
- `ix_services_owner` (owner_type, owner_id, status)
- `ix_services_category` (category, status)
- `ix_services_status` (status)

`service_applications` 和 `service_time_slots` 结构基本不变，FK 指向 `services.id`。

### `reviews` 表变更（现有表扩展）

新增字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| expert_id | VARCHAR(8) FK → experts ON DELETE SET NULL, nullable | 被评价的达人团队 |

- `expert_id` 为 NULL → 普通任务评价（用户 ↔ 用户）
- `expert_id` 不为 NULL → 达人服务评价（用户 → 达人团队）
- 当任务来源于达人服务时，创建评价时自动填入 `expert_id`
- 达人的 `experts.rating` 从 `reviews WHERE expert_id = ?` 聚合计算并事件更新

索引：
- `ix_reviews_expert_id` (expert_id) WHERE expert_id IS NOT NULL

## 角色权限矩阵

### 达人团队管理

| 操作 | Owner | Admin | Member |
|------|-------|-------|--------|
| 修改达人信息（触发审核） | ✅ | ❌ | ❌ |
| 转让 Owner | ✅ | ❌ | ❌ |
| 提升/降级成员角色 | ✅ | ❌ | ❌ |
| 移除成员 | ✅ | ❌ | ❌ |
| 邀请用户加入团队 | ✅ | ✅ | ❌ |
| 审批加入申请 | ✅ | ✅ | ❌ |
| 开关申请入口 | ✅ | ❌ | ❌ |

### 服务与活动

| 操作 | Owner | Admin | Member |
|------|-------|-------|--------|
| 创建/编辑/删除服务（无需审核） | ✅ | ✅ | ❌ |
| 创建/编辑活动（需管理员审核） | ✅ | ✅ | ❌ |
| 删除活动 | ✅ | ✅ | ❌ |
| 管理时间段 | ✅ | ✅ | ❌ |
| 处理服务申请（审批/拒绝/协商） | ✅ | ✅ | ❌ |
| 管理关门日期 | ✅ | ✅ | ❌ |

### 服务咨询

| 操作 | Owner | Admin | Member |
|------|-------|-------|--------|
| 查看/回复用户咨询 | ✅ | ✅ | ❌ |
| 接收咨询通知 | ✅ | ✅ | ❌ |
| 被邀请进咨询聊天协助 | ✅ | ✅ | ✅ |

用户对达人服务发起咨询时，所有 Owner 和 Admin 收到通知，谁有空谁回复。如果需要 Member 协助，Owner/Admin 可以通过邀请进聊天的方式拉人（走任务聊天多人化流程）。

### 任务聊天

| 操作 | Owner | Admin | Member |
|------|-------|-------|--------|
| 邀请团队成员进入任务聊天 | ✅ | ✅ | ❌ |
| 在任务聊天中发消息 | ✅ | ✅ | ✅ |
| 业务操作（接单/改价/确认完成） | ✅ | ✅ | ❌ |
| 查看全部聊天记录（含价格） | ✅ | ✅ | ✅ |

### 达人板块

| 操作 | Owner | Admin | Member | 普通用户 |
|------|-------|-------|--------|---------|
| 发帖（以"团队 · 个人"身份） | ✅ | ✅ | ✅ | ❌ |
| 置顶/加精帖子 | ✅ | ✅ | ❌ | ❌ |
| 删除板块内帖子 | ✅ | ✅ | ❌ | ❌ |
| 锁帖（禁止回复） | ✅ | ✅ | ❌ | ❌ |
| 评论/回复 | ✅ | ✅ | ✅ | ✅ |
| 点赞/收藏 | ✅ | ✅ | ✅ | ✅ |
| 浏览帖子 | ✅ | ✅ | ✅ | ✅ |

### 达人内部群聊

| 操作 | Owner | Admin | Member |
|------|-------|-------|--------|
| 发消息 | ✅ | ✅ | ✅ |
| 查看所有消息 | ✅ | ✅ | ✅ |
| 群内禁言成员 | ✅ | ✅ | ❌ |

成员加入/退出团队时自动同步到群聊，不支持手动邀请外部人。

## Owner 转让流程

1. Owner 选择团队内一个成员（任意角色）
2. 确认转让（二次确认弹窗）
3. 被转让者 role 变为 `owner`
4. 原 Owner role 变为 `admin`
5. 在内部群聊中发送系统消息通知全体成员

## 达人板块设计

### 论坛集成方式

复用现有 `forum_categories` 表，新增字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| expert_id | VARCHAR(8) FK → experts | 关联达人团队（仅 type='expert' 时有值） |

达人板块创建时自动设置：
- `type = 'expert'`
- `name = 达人团队名称`（初始值，达人可自由修改）
- `expert_id = 达人 ID`
- `is_visible = true`
- `is_admin_only = false`

达人 Owner/Admin 可以自由编辑板块名称和描述，无需审核。板块名称不强制和达人团队名一致。

### 帖子身份标识

复用现有 `forum_posts` 表，新增字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| expert_id | VARCHAR(8) FK → experts | 发帖的达人团队（NULL 表示普通用户发帖） |

帖子展示时：
- `expert_id` 不为空 → 显示"团队名 · 作者名"
- `expert_id` 为空 → 显示普通用户名（现有逻辑不变）

### 板块管理权限

达人板块的管理操作（置顶/加精/删帖/锁帖）不走平台管理员，而是由达人 Owner/Admin 直接操作。

后端权限判断逻辑：
1. 如果板块 `type = 'expert'`，检查操作者是否为该达人的 Owner 或 Admin
2. 如果板块是其他类型，走现有的平台管理员权限逻辑
3. 平台管理员对所有板块始终有权限（兜底）

### 论坛展示方式

达人板块在论坛页使用独立的"达人"Tab，不和通用/技能/地区等板块混排。

- 论坛页顶部 Tab：`全部` / `通用` / `技能` / `地区` / **`达人`**
- "达人"Tab 内展示所有达人板块列表，支持搜索/分类筛选
- 其他 Tab 不显示达人板块

### 关注 feed 联动

用户关注达人后，该达人板块的新帖子会推送到用户的动态流：

- 达人成员发帖时，查 `expert_follows` 获取所有关注者
- 向关注者的 feed 插入一条动态（复用现有 follow feed 机制）
- 推送内容："[达人名] 发布了新帖子：[帖子标题]"

### 发帖权限

达人板块的发帖权限：
1. 检查帖子的 `category_id` 对应的板块是否为 `type = 'expert'`
2. 如果是，检查发帖人是否为该达人团队的活跃成员（`expert_members` 中 status = 'active'）
3. 非成员只能评论/回复，不能发帖
4. 平台管理员可以在任何板块发帖

## 达人内部群聊设计

### 群聊集成方式

复用已有的群聊设计（`chat_groups` 表），达人创建时自动创建一个特殊类型的群：

- `type = 'expert_internal'`（新增类型，区别于普通兴趣群）
- `name = 达人团队名称 + " 内部群"`
- `owner_id = 达人 Owner 的 user_id`
- `join_mode = 'invite'`（不开放加入，完全由团队成员变动驱动）
- `max_members = 20`（与达人团队上限一致）

### 成员自动同步

| 团队事件 | 群聊操作 |
|---------|---------|
| 用户加入团队（邀请/申请通过） | 自动加入内部群聊 |
| 用户退出团队 | 自动退出内部群聊 |
| 用户被移除 | 自动移出内部群聊 |
| Owner 转让 | 群聊 owner_id 同步更新 |
| 成员角色变更 | 群聊中角色同步更新 |

### 与普通群聊的区别

| | 普通群聊 | 达人内部群聊 |
|--|---------|-------------|
| 创建方式 | 用户/达人手动创建 | 达人创建时自动生成 |
| 成员管理 | 群内邀请/申请 | 团队成员变动自动同步 |
| 解散条件 | 群主解散 | 达人被注销时自动解散 |
| 邀请外部人 | 可以 | 不可以 |
| 退出方式 | 自行退出 | 退出团队时自动退出 |

## 任务聊天多人化

### 新增 `chat_participants` 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| task_id | INT FK → tasks | 任务 |
| user_id | VARCHAR(8) FK → users | 参与者 |
| role | VARCHAR(20) | client / expert_owner / expert_admin / expert_member |
| invited_by | VARCHAR(8) FK → users | 邀请人（NULL = 原始参与者） |
| joined_at | DATETIME | 加入时间 |

约束：
- `UNIQUE(task_id, user_id)`

### 升级流程

1. **初始状态**：任务聊天为 1 对 1（发布者 ↔ 达人），`chat_participants` 表为空，走现有 `sender_id` + `receiver_id` 逻辑
2. **邀请触发**：达人 Owner/Admin 邀请团队成员进入任务聊天
3. **自动升级**：
   - 在 `chat_participants` 中插入所有参与者（原有两人 + 新成员）
   - 原有两人的 role 根据身份设置（client / expert_owner 或 expert_admin）
   - 新成员 role 为 expert_member
4. **消息发送**：
   - `chat_participants` 存在时，消息的 `receiver_id` 设为 NULL（多人聊天无单一接收者）
   - 发送系统消息："[用户名] 邀请 [成员名] 加入了聊天"
5. **消息广播**：
   - 查 `chat_participants` 获取所有参与者
   - 通过 WebSocket 向所有在线参与者推送
6. **兼容策略**：
   - `chat_participants` 为空 → 走现有双人逻辑
   - `chat_participants` 有记录 → 走多人逻辑

### 邀请限制

- 只能邀请该达人团队的活跃成员
- 被邀请人不能已在聊天中
- 一个任务聊天中的团队成员数量无额外限制（受团队 20 人上限自然约束）

## 数据迁移方案

### 迁移步骤

1. **创建新表**：`experts`、`expert_members`、`expert_applications`、`expert_join_requests`、`expert_invitations`、`expert_profile_update_requests`（新结构）、`featured_experts`、`services`、`chat_participants`

2. **迁移 `task_experts` → `experts`**：
   - 为每条记录生成新的 8 位随机 ID
   - 映射字段：expert_name → name, bio → bio, avatar → avatar, status → status, rating → rating, total_services → total_services, completed_tasks → completed_tasks, is_official → is_official, official_badge → official_badge
   - 创建关联的 `forum_categories`（type='expert'）
   - 创建关联的 `chat_groups`（type='expert_internal'）
   - 维护 old_id → new_id 映射表用于后续迁移

3. **迁移 `task_experts` → `expert_members`**：
   - 原 `task_experts.id`（= user_id）插入为 role = 'owner', status = 'active'

4. **迁移 `featured_task_experts` → `featured_experts`**：
   - 通过 old_id → new_id 映射关联到新 expert_id
   - 只保留 display_order, is_featured, category, created_by

5. **迁移 `task_expert_services` → `services`**：
   - `service_type = 'expert'`：owner_type = 'expert', owner_id = 新 expert_id（通过映射）
   - `service_type = 'personal'`：owner_type = 'user', owner_id = user_id
   - 其他字段直接映射

6. **更新 FK 引用**：
   - `service_applications.expert_id` → 改 FK 指向 `experts.id`，使用新 expert_id
   - `service_applications.service_owner_id` → 保留不变（个人服务时有值）
   - `activities.expert_id` → 改 FK 从 `users.id` 指向 `experts.id`，使用新 expert_id
   - `service_time_slots` 的 service_id 不变（services 表 ID 保持一致或重新映射）
   - `expert_closed_dates.expert_id` → 新 expert_id

7. **迁移 `task_expert_applications` → `expert_applications`**：
   - 已审核通过的：标记为 approved，关联新 expert_id
   - pending 的：迁移到新表，保持 pending

8. **迁移 `task_expert_profile_update_requests` → `expert_profile_update_requests`**：
   - expert_id 更新为新 ID，新增 requester_id = 原 expert_id 对应的 user_id

### 迁移策略

- 编写编号 SQL 迁移脚本（`backend/migrations/NNN_expert_team_redesign.sql`）
- 在事务中执行，失败可回滚
- 迁移完成后保留旧表（加 `_deprecated` 后缀），观察一段时间后删除

## API 变更概览

### 新增端点

**团队管理：**
- `POST /api/experts/apply` — 申请创建达人团队
- `GET /api/experts/my-applications` — 我的达人申请
- `GET /api/experts/my-teams` — 我关联的所有达人团队
- `GET /api/experts/{id}/members` — 团队成员列表
- `POST /api/experts/{id}/invite` — 邀请用户加入
- `POST /api/experts/{id}/join` — 申请加入团队
- `GET /api/experts/{id}/join-requests` — 加入申请列表（Owner/Admin）
- `PUT /api/experts/{id}/join-requests/{rid}` — 审批加入申请
- `PUT /api/experts/{id}/members/{uid}/role` — 变更成员角色
- `DELETE /api/experts/{id}/members/{uid}` — 移除成员
- `POST /api/experts/{id}/transfer` — 转让 Owner
- `POST /api/experts/{id}/leave` — 退出团队

**任务聊天多人化：**
- `POST /api/chat/tasks/{task_id}/invite` — 邀请团队成员进入聊天
- `GET /api/chat/tasks/{task_id}/participants` — 获取聊天参与者列表

**个人服务：**
- `POST /api/services/personal` — 创建个人服务
- `GET /api/services/personal/me` — 我的个人服务列表
- `PUT /api/services/personal/{id}` — 编辑个人服务
- `DELETE /api/services/personal/{id}` — 删除个人服务

**达人搜索/发现：**
- `GET /api/experts/search` — 搜索达人（按名称/分类/技能）
- `GET /api/experts/featured` — 精选达人列表

**达人关注：**
- `POST /api/experts/{id}/follow` — 关注/取消关注达人
- `GET /api/experts/{id}/follow/status` — 关注状态
- `GET /api/my/following-experts` — 我关注的达人列表

**达人优惠券：**
- `POST /api/experts/{id}/coupons` — 创建达人优惠券
- `GET /api/experts/{id}/coupons` — 达人优惠券列表
- `PUT /api/experts/{id}/coupons/{cid}` — 编辑优惠券
- `DELETE /api/experts/{id}/coupons/{cid}` — 停用优惠券

**套餐/次卡：**
- `POST /api/services/{id}/packages/purchase` — 购买套餐
- `GET /api/my/packages` — 我的套餐列表
- `POST /api/experts/{id}/packages/{pid}/use` — 核销一次

**评价回复：**
- `POST /api/reviews/{id}/reply` — 达人回复评价

**达人板块管理：**
- `PUT /api/experts/{id}/board` — 编辑达人板块名称和描述

### 改造端点

- `GET /api/experts` — 列表查询不变，返回数据改为团队信息
- `GET /api/experts/{id}` — 详情增加成员列表
- `POST /api/experts/{id}/profile-update-request` — 权限改为仅 Owner
- 达人服务相关端点 `/api/experts/me/services/*` → `/api/experts/{id}/services/*`（支持多团队身份）
- 达人面板端点 `/api/experts/me/dashboard/*` → `/api/experts/{id}/dashboard/*`

### 论坛端点扩展

- `POST /api/forums/posts` — 新增 `expert_id` 参数，以团队身份发帖
- `POST /api/forums/posts/{id}/pin` — 达人板块内 Owner/Admin 可操作
- `POST /api/forums/posts/{id}/feature` — 达人板块内 Owner/Admin 可操作
- `DELETE /api/forums/posts/{id}` — 达人板块内 Owner/Admin 可操作

## 套餐/次卡

### `services` 表新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| package_type | VARCHAR(20) DEFAULT 'single' | single（单次）/ multi_session（次卡）/ bundle（组合套餐） |
| total_sessions | INT, nullable | 次卡总次数（仅 multi_session 时有值） |
| bundle_service_ids | JSONB, nullable | 包含的子服务 ID 列表（仅 bundle 时有值） |

### 用户购买记录：`user_service_packages`（新表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| user_id | VARCHAR(8) FK → users | 购买者 |
| service_id | INT FK → services | 套餐服务 |
| expert_id | VARCHAR(8) FK → experts | 达人团队 |
| total_sessions | INT | 总次数 |
| used_sessions | INT DEFAULT 0 | 已用次数 |
| status | VARCHAR(20) DEFAULT 'active' | active / exhausted / expired / refunded |
| purchased_at | DATETIME | 购买时间 |
| expires_at | DATETIME, nullable | 过期时间（NULL = 不过期） |
| task_id | INT FK → tasks, nullable | 关联的支付任务 |

约束：
- `UNIQUE(user_id, service_id, task_id)`

### 核销记录：`package_usage_logs`（新表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| package_id | INT FK → user_service_packages | 套餐记录 |
| used_at | DATETIME | 核销时间 |
| used_by | VARCHAR(8) FK → users | 核销操作人（Owner/Admin） |
| note | TEXT, nullable | 备注 |

### 流程

- **次卡购买**：用户购买次卡 → 创建支付任务 → 支付完成 → 创建 `user_service_packages` 记录
- **次卡核销**：每次使用服务时，Owner/Admin 在聊天/服务管理中核销一次 → `used_sessions + 1`
- **次卡用完**：`used_sessions = total_sessions` 时 status → 'exhausted'
- **组合套餐**：购买后按 `bundle_service_ids` 中的子服务逐一预约使用，每个子服务各自独立核销

## 达人回复评价

### `reviews` 表新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| reply_content | TEXT, nullable | 达人回复内容 |
| reply_at | DATETIME, nullable | 回复时间 |
| reply_by | VARCHAR(8) FK → users, nullable | 回复人（Owner/Admin） |

- 一条评价只能回复一次
- Owner 和 Admin 都可以回复
- 回复后不可编辑（防止篡改）

## 达人优惠券

### `coupons` 表新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| expert_id | VARCHAR(8) FK → experts, nullable | 归属达人（NULL = 平台券） |

- `expert_id` 为 NULL → 平台优惠券（现有逻辑不变）
- `expert_id` 不为 NULL → 达人专属券，只能用于该达人的服务
- Owner/Admin 可创建/编辑/停用，免审核
- 复用现有全部优惠券能力：`type`（fixed_amount/percentage）、`per_user_limit`、`valid_from/until`、`applicable_scenarios`、积分兑换等

### 权限

| 操作 | Owner | Admin | Member |
|------|-------|-------|--------|
| 创建/编辑/停用优惠券 | ✅ | ✅ | ❌ |
| 查看优惠券使用数据 | ✅ | ✅ | ❌ |

## 达人收款账户

达人团队拥有独立的 Stripe Connect 账户，不复用 Owner 的个人 Stripe 账户。

### `experts` 表新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| stripe_account_id | VARCHAR(255), nullable | Stripe Connect 账户 ID |
| stripe_connect_country | VARCHAR(10), nullable | Stripe Connect 国家 |
| stripe_onboarding_complete | BOOL DEFAULT false | Stripe 入驻是否完成 |

### 流程

1. 达人创建通过审核后，Owner 在达人管理页面发起 Stripe Connect 入驻
2. 入驻完成后 `stripe_account_id` 写入 `experts` 表
3. 达人服务产生的收款全部进入团队 Stripe 账户
4. 团队内部的分账由 Owner 自行线下处理（平台不介入）

## 达人注销/解散

### 注销条件

- 仅 Owner 可发起注销
- **有进行中的任务时不可注销**（status 为 in_progress、pending_payment、pending_confirmation 的任务）
- 系统自动检查，不满足条件时拒绝并提示原因

### 注销流程

1. Owner 发起注销请求
2. 系统检查是否有进行中的任务
3. 通过后执行：
   - 达人状态 → `dissolved`
   - 所有服务状态 → `inactive`（自动下架）
   - 所有未完成的活动状态 → `cancelled`（拼单中的释放预授权）
   - 达人板块 `is_visible` → false（帖子隐藏，不删除）
   - 内部群聊解散
   - `featured_experts` 中对应记录删除
   - 所有成员的 `expert_members.status` → `left`
   - 通知所有成员"达人团队已解散"

### 数据保留

- 历史任务、评价、帖子数据保留不删除（软隐藏）
- 达人 ID 保留，不回收
- Stripe Connect 账户不自动注销（可能有待结算款项）

## 成员退出与任务聊天保障

### 成员退出/移除时

1. 自动移出内部团队群聊
2. 自动移出该成员参与的**所有达人相关任务聊天**（从 `chat_participants` 中移除）
3. 在被移出的聊天中发送系统消息："[成员名] 已退出团队"

### Owner 保障机制

- 每个达人任务聊天中，**Owner 始终自动在场**
- 创建任务聊天时自动将 Owner 加入 `chat_participants`（role = 'expert_owner'）
- Owner 不能被从任务聊天中移除（除非达人注销）
- Owner 转让时，新 Owner 自动加入所有现有的达人任务聊天，原 Owner 保留（身份降为 expert_admin）

## 活动与服务关联

### 关联规则调整

- 活动**不再强制关联服务**
- 关联服务的活动：支持时间段模式、咨询定价等完整服务流程
- 不关联服务的活动：可用 `lottery`（抽奖）和 `first_come`（先到先得）类型，适用于推广、福利活动等场景
- 拼单活动可以关联或不关联服务

## 拼单模式

### 概述

达人活动支持拼单模式：需要凑够 N 人才正式成单。未凑够则到期自动取消，预授权释放。

### `activities` 表新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| is_group_buy | BOOL DEFAULT false | 是否拼单活动 |
| group_buy_min | INT | 最少成单人数（拼单时必填） |
| group_buy_deadline | DATETIME, nullable | 拼单截止时间（NULL = 不设时间限制） |
| group_buy_task_mode | VARCHAR(20) | 成单后任务模式：'individual'（每人独立任务）/ 'shared'（一个多人任务） |
| group_buy_multi_round | BOOL DEFAULT false | 是否多轮拼单（凑够一轮后自动开下一轮） |
| group_buy_current_count | INT DEFAULT 0 | 当前轮已报名人数（冗余，事件更新） |
| group_buy_round | INT DEFAULT 1 | 当前轮次 |

### 拼单流程

```
用户报名 → Stripe 预授权（冻结金额，不扣款）
    ↓
拼单中（显示 "已拼 X/N 人"）
    ↓
├── 凑够 N 人 → 成单
│   ├── Stripe capture（正式扣款）
│   ├── 根据 group_buy_task_mode 创建任务
│   │   ├── individual → 每人各创建一个单人任务
│   │   └── shared → 创建一个多人任务，所有人在同一聊天
│   ├── 通知所有参与者"拼单成功"
│   └── 多轮模式？
│       ├── 是 → round+1, current_count 归零，继续接受报名
│       └── 否 → 活动状态变更
│
├── 到截止日期未凑够 → 拼单失败
│   ├── 释放所有预授权
│   └── 通知所有参与者"拼单未成功，已自动退款"
│
└── 用户主动取消（成单前）
    ├── 释放该用户的预授权
    ├── current_count - 1
    └── 通知用户"已取消"
```

### 拼单报名记录

复用现有 `official_activity_applications` 表或新增 `group_buy_participants` 表：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK AUTO | 自增 |
| activity_id | INT FK → activities | 活动 |
| user_id | VARCHAR(8) FK → users | 报名用户 |
| round | INT DEFAULT 1 | 所属轮次 |
| stripe_payment_intent_id | VARCHAR(255) | Stripe 预授权 ID |
| status | VARCHAR(20) | pending（预授权中）/ confirmed（已成单扣款）/ cancelled（用户取消）/ expired（拼单失败释放） |
| created_at | DATETIME | 报名时间 |
| cancelled_at | DATETIME, nullable | 取消时间 |

约束：
- `UNIQUE(activity_id, user_id, round)`

### Stripe 预授权技术方案

1. 用户报名时：创建 `PaymentIntent` with `capture_method='manual'`，冻结金额
2. 拼单成功时：对所有参与者的 PaymentIntent 调用 `capture()`，正式扣款
3. 拼单失败/用户取消：调用 `cancel()` 释放预授权
4. 预授权有效期：Stripe 默认 7 天，超过需要重新授权。对于无截止日期的拼单，需要定时任务在到期前重新授权或提醒用户

### 定时任务

- **拼单到期检查**：每分钟检查是否有到期未成单的拼单活动，触发退款流程
- **预授权续期**：对于无截止日期的拼单，在 Stripe 预授权到期前（第 6 天）重新授权或通知用户
- **多轮拼单清理**：达人手动关闭或活动到截止日期时，处理最后一轮未凑够的退款

## 分阶段实施建议

### Phase 1 — 团队基础

- 新表创建 + 数据迁移脚本
- `experts` + `expert_members` 核心模型
- 达人申请/审核流程改造
- 团队成员邀请/申请/审批
- 角色管理（提升/降级/转让/移除）
- Flutter：达人管理页面改造（团队信息、成员管理）
- Admin：达人管理页面适配新模型

### Phase 2 — 服务层改造

- `services` 统一表迁移
- 个人服务和达人服务分流
- 服务 CRUD 适配新权限（Owner/Admin 可操作）
- `featured_experts` 精简迁移
- Flutter：服务管理页面适配
- Flutter：达人详情页展示团队品牌 + 成员列表

### Phase 3 — 达人板块

- `forum_categories` 新增 `expert_id` 字段
- `forum_posts` 新增 `expert_id` 字段
- 达人板块自动创建逻辑
- 板块管理权限（置顶/加精/删帖/锁帖）
- 发帖权限控制（仅团队成员）
- 帖子作者显示"团队名 · 个人名"
- Flutter：达人板块 UI

### Phase 4 — 达人内部群聊

- `chat_groups` 新增 `type = 'expert_internal'` 支持
- 达人创建时自动建群
- 成员变动自动同步群聊
- Flutter：内部群聊入口（达人管理页面）

### Phase 5 — 任务聊天多人化

- `chat_participants` 表
- 邀请团队成员进入任务聊天
- 消息广播改造（双人 → 多人兼容）
- WebSocket 推送适配
- Flutter：任务聊天 UI 支持多人（成员列表、系统消息）

### Phase 6 — 拼单模式

- `activities` 表新增拼单字段
- `group_buy_participants` 表
- Stripe 预授权/capture/cancel 流程
- 拼单成单 → 创建任务（individual / shared 两种模式）
- 多轮拼单逻辑
- 定时任务（到期检查、预授权续期）
- Flutter：拼单活动 UI（进度展示、报名/取消）

### Phase 7 — 套餐与营销

- `services` 表新增 package_type 字段
- `user_service_packages` + `package_usage_logs` 表
- 套餐购买、核销流程
- `reviews` 表新增回复字段
- `coupons` 表新增 expert_id 字段
- 达人优惠券创建/管理 API
- Flutter：套餐购买/核销 UI、评价回复 UI、达人优惠券管理 UI
