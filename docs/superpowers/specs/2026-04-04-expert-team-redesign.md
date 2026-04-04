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
| bio | TEXT | 团队简介 |
| avatar | TEXT | 团队头像 URL |
| status | VARCHAR(20) DEFAULT 'active' | active / inactive / suspended |
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
| 创建/编辑/删除服务 | ✅ | ✅ | ❌ |
| 创建/编辑/删除活动 | ✅ | ✅ | ❌ |
| 管理时间段 | ✅ | ✅ | ❌ |
| 处理服务申请（审批/拒绝/协商） | ✅ | ✅ | ❌ |
| 管理关门日期 | ✅ | ✅ | ❌ |

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
- `name = 达人团队名称`
- `expert_id = 达人 ID`
- `is_visible = true`
- `is_admin_only = false`

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
   - `service_applications.expert_id` → 使用新 expert_id
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
