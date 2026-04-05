# 群聊功能设计

## 概述

为 Link2Ur 平台新增兴趣/话题群组功能，支持用户创建和加入兴趣社区，进行实时群聊交流，并与平台现有功能（任务、活动、跳蚤市场）深度联动。

## 需求

- **群组类型**：兴趣/话题群组，长期社区频道
- **加入方式**：群主创建时可选——开放 / 审批 / 邀请制
- **规模**：上限 500-1000 人
- **管理体系**：群主 → 管理员 → 普通成员（三级）
- **消息类型**：文字 / 图片 / 文件 / @提及 / 回复引用 / 投票 / 活动
- **平台联动**：分享卡片（任务/商品/活动）+ 群内发起任务/活动/组队
- **实时性**：WebSocket 在线推送 + FCM/APNs 离线推送
- **离线体验**：本地缓存群聊记录，断网可看历史

## 架构方案

**方案 B：独立群聊表 + 未来 Conversation 统一**

分两阶段：
1. **第一阶段（本次）**：只建群聊相关的新表（`chat_groups`、`group_messages` 等），现有私聊/任务聊天保持不动
2. **第二阶段（后续）**：引入 `Conversation` 统一抽象，把私聊/任务聊天/群聊合并到一个聊天列表模型下

## 消息列表设计

**统一混排**：私聊、任务聊天、群组全部显示在同一个消息列表中，按最后消息时间倒序排列。置顶的排前面。

> **Phase 1 现状**：`MessageView` 当前只显示任务聊天（`getTaskChats()`），私聊联系人未在消息 Tab 展示。Phase 1 群组作为新条目与任务聊天并列显示，**不做私聊混排**（留到 Phase 4 Conversation 统一时处理）。

**不做类型标记**：群组有群名、任务有任务标题、私聊有用户名，天然可区分，不额外加图标/标签/边框。

**头像风格**：保持现有 56px 圆角方形（borderRadius: 16），群组用群组头像，与现有任务聊天图标风格一致。

## 数据模型

> **约定**：用户 ID 统一为 `VARCHAR(8)`（对应 User.id `String(8)`），所有 DATETIME 字段带时区 `DateTime(timezone=True)`，JSON 字段使用 PostgreSQL `JSONB` 类型。

### chat_groups

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| name | VARCHAR(100) | 群组名称 |
| description | TEXT | 群组描述 |
| avatar_url | VARCHAR | 群组头像 URL |
| owner_id | VARCHAR(8) FK → users | 群主用户 ID |
| join_mode | ENUM('open','approval','invite') | 加入方式 |
| max_members | INT DEFAULT 1000 | 人数上限 |
| category | VARCHAR(50) | 分类（摄影、编程、设计等） |
| tags | JSONB | 标签数组 `["摄影","户外"]` |
| member_count | INT DEFAULT 0 | 当前成员数（冗余，加入/退出/踢出时同事务更新，Celery 定期校准） |
| last_message_id | INT FK → group_messages | 最新消息 ID（冗余，消息列表排序，避免 window function） |
| last_message_time | DATETIME | 最新消息时间（冗余，冷启动排序依据，每条新消息时更新） |
| last_message_preview | VARCHAR(100) | 最新消息预览文本（冗余，消息列表展示用） |
| is_active | BOOL DEFAULT true | 软删除标记 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 最后更新时间 |

### group_members

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 所属群组 |
| user_id | VARCHAR(8) FK → users | 用户 ID |
| role | ENUM('owner','admin','member') | 角色 |
| nickname | VARCHAR(50) | 群内昵称（可选） |
| muted_until | DATETIME | 禁言截止时间（NULL 表示未禁言） |
| joined_at | DATETIME | 加入时间 |
| status | ENUM('active','banned','left') | 状态 |

约束：`UNIQUE(group_id, user_id)`

> **重新加入**：用户退出（status='left'）后重新加入时，UPDATE 现有行（status→'active', role→'member', joined_at→now()），不 INSERT 新行。

### group_messages

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| client_message_id | VARCHAR(36) | 客户端生成的 UUID，用于乐观更新去重（发送时携带，广播时回传） |
| group_id | INT FK → chat_groups | 所属群组 |
| sender_id | VARCHAR(8) FK → users | 发送者（NULL 表示系统消息） |
| content | TEXT | 消息内容（应用层限制 max 5000 字符，与现有任务聊天一致） |
| message_type | ENUM('text','image','file','system','poll','share','activity') | 消息类型 |
| reply_to_id | INT FK → group_messages | 回复的消息 ID（NULL 表示非回复） |
| mentions | JSONB | 被 @ 的用户 ID 列表 `["user1","user2","all"]` |
| attachments | JSONB | 附件列表 `[{type, url, meta}]` |
| meta | JSONB | 扩展数据（分享卡片信息、投票 ID 等） |
| is_pinned | BOOL DEFAULT false | 是否置顶（聊天窗口内的消息钉住） |
| is_deleted | BOOL DEFAULT false | 软删除标记（删除后 reply_to 引用不断链） |
| created_at | DATETIME | 发送时间 |
| edited_at | DATETIME | 编辑时间（NULL 表示未编辑） |

> **消息排序**：客户端始终按 `id` 升序显示消息（不用 `created_at`），保证全局有序。

### group_message_reads

| 字段 | 类型 | 说明 |
|------|------|------|
| group_id | INT PK, FK → chat_groups | 群组 ID |
| user_id | VARCHAR(8) PK, FK → users | 用户 ID |
| last_read_message_id | INT | 最后已读消息 ID |
| updated_at | DATETIME | 更新时间 |

复合主键：`(group_id, user_id)`

### group_polls

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 所属群组 |
| message_id | INT FK → group_messages | 关联的消息 |
| question | VARCHAR(200) | 投票问题 |
| options | JSONB | 选项列表 `["选项A","选项B"]` |
| is_anonymous | BOOL DEFAULT false | 是否匿名投票 |
| is_multiple | BOOL DEFAULT false | 是否多选 |
| expires_at | DATETIME | 过期时间 |
| created_by | VARCHAR(8) FK → users | 创建者 |
| created_at | DATETIME | 创建时间 |

### group_poll_votes

投票数据独立成表，避免大群并发更新同一 JSON 字段的冲突问题。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| poll_id | INT FK → group_polls | 所属投票 |
| user_id | VARCHAR(8) FK → users | 投票者 |
| option_index | INT | 选项索引（对应 options 数组下标） |
| created_at | DATETIME | 投票时间 |

约束：`UNIQUE(poll_id, user_id, option_index)`（多选时同一用户可投多个选项，但不能重复投同一选项）

### group_join_requests

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 目标群组 |
| user_id | VARCHAR(8) FK → users | 申请者 |
| status | ENUM('pending','approved','rejected') | 审批状态 |
| message | TEXT | 申请理由 |
| reviewed_by | VARCHAR(8) FK → users | 审批人 |
| created_at | DATETIME | 申请时间 |
| reviewed_at | DATETIME | 审批时间 |

### group_invitations

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 目标群组 |
| inviter_id | VARCHAR(8) FK → users | 邀请人 |
| invitee_id | VARCHAR(8) FK → users | 被邀请人 |
| status | ENUM('pending','accepted','rejected','expired') | 状态 |
| created_at | DATETIME | 邀请时间 |
| responded_at | DATETIME | 响应时间 |

约束：`UNIQUE(group_id, invitee_id)` WHERE status = 'pending'（同一群对同一用户只能有一个 pending 邀请）

### group_announcements

> **与 `is_pinned` 的区别**：`is_pinned` 是聊天窗口内的消息钉住（滚动到顶部可见），`group_announcements` 是群公告栏（独立入口，进群时弹窗提醒，可有多条历史公告）。两者是不同概念。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 所属群组 |
| content | TEXT | 公告内容（独立于消息，公告可能不来自某条消息） |
| message_id | INT FK → group_messages | 关联的消息（可选，NULL 表示手动创建的公告） |
| created_by | VARCHAR(8) FK → users | 发布人 |
| is_active | BOOL DEFAULT true | 是否有效（撤销公告时置 false） |
| created_at | DATETIME | 发布时间 |

### 索引策略

```sql
-- 消息查询（主查询路径）
CREATE INDEX ix_gmsg_group_created ON group_messages(group_id, created_at DESC);
CREATE INDEX ix_gmsg_group_pinned ON group_messages(group_id) WHERE is_pinned = true;

-- 成员查询
CREATE INDEX ix_gmember_user ON group_members(user_id) WHERE status = 'active';
CREATE INDEX ix_gmember_group ON group_members(group_id, role);

-- 已读追踪
CREATE UNIQUE INDEX ux_group_reads ON group_message_reads(group_id, user_id);

-- 群组发现
CREATE INDEX ix_groups_category ON chat_groups(category) WHERE is_active = true;
CREATE INDEX ix_groups_tags ON chat_groups USING gin(tags);
CREATE INDEX ix_groups_name_trgm ON chat_groups USING gin(name gin_trgm_ops);

-- 投票查询
CREATE INDEX ix_poll_votes_poll ON group_poll_votes(poll_id);
CREATE UNIQUE INDEX ux_poll_votes ON group_poll_votes(poll_id, user_id, option_index);

-- 邀请查询
CREATE INDEX ix_invitations_invitee ON group_invitations(invitee_id) WHERE status = 'pending';
CREATE UNIQUE INDEX ux_invitations_pending ON group_invitations(group_id, invitee_id) WHERE status = 'pending';

-- 公告查询
CREATE INDEX ix_announcements_group ON group_announcements(group_id) WHERE is_active = true;

-- 消息列表排序（冷启动）
CREATE INDEX ix_groups_last_msg ON chat_groups(last_message_time DESC) WHERE is_active = true;

-- 乐观更新去重
CREATE INDEX ix_gmsg_client_id ON group_messages(client_message_id) WHERE client_message_id IS NOT NULL;
```

## API 设计

### 群组管理

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/groups` | 创建群组 | 达人用户（Phase 1，查 `task_experts` 表 status='active'），后续开放 |
| GET | `/api/groups` | 发现群组（搜索用 trgm 模糊匹配/分类/标签筛选） | 登录用户 |
| GET | `/api/groups/my` | 我的群组列表 | 登录用户 |
| GET | `/api/groups/{id}` | 群组详情 | 登录用户 |
| PUT | `/api/groups/{id}` | 编辑群组信息 | 群主/管理员 |
| DELETE | `/api/groups/{id}` | 解散群组（软删除，消息保留） | 群主 |
| POST | `/api/groups/{id}/transfer` | 转让群主 | 群主 |

### 成员管理

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/groups/{id}/join` | 申请/直接加入 | 登录用户 |
| POST | `/api/groups/{id}/invite` | 邀请用户（写入 group_invitations） | 群主/管理员 |
| GET | `/api/groups/{id}/members` | 成员列表（分页） | 群成员 |
| PUT | `/api/groups/{id}/members/{uid}/role` | 设置角色 | 群主 |
| POST | `/api/groups/{id}/members/{uid}/mute` | 禁言（指定时长） | 群主/管理员 |
| POST | `/api/groups/{id}/members/{uid}/ban` | 踢出（status→banned） | 群主/管理员 |
| POST | `/api/groups/{id}/leave` | 退出群组 | 群成员（群主须先转让） |
| GET | `/api/groups/{id}/join-requests` | 加入申请列表 | 群主/管理员 |
| PUT | `/api/groups/{id}/join-requests/{rid}` | 审批加入申请 | 群主/管理员 |

### 消息

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/groups/{id}/messages` | 消息列表（cursor 分页，cursor = message_id） | 群成员 |
| POST | `/api/groups/{id}/messages` | 发送消息（body 含 `client_message_id`，content max 5000） | 群成员（未禁言） |
| POST | `/api/groups/{id}/messages/read` | 标记已读（持久化到 group_message_reads） | 群成员 |
| PUT | `/api/groups/{id}/messages/{mid}/pin` | 置顶/取消置顶 | 群主/管理员 |
| PUT | `/api/groups/{id}/messages/{mid}` | 编辑消息（仅文字，5 分钟内） | 发送者 |
| DELETE | `/api/groups/{id}/messages/{mid}` | 删除消息（软删除，is_deleted=true） | 发送者/管理员 |

> **Rate limit**：群消息发送复用现有 `send_message` 限速（30 次/60 秒）。

### 投票 & 公告

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/groups/{id}/polls` | 创建投票 | 群成员 |
| POST | `/api/groups/{id}/polls/{pid}/vote` | 投票 | 群成员 |
| GET | `/api/groups/{id}/announcements` | 公告列表 | 群成员 |
| POST | `/api/groups/{id}/announcements` | 发布公告 | 群主/管理员 |

### 图片上传

复用现有 `POST /api/v2/upload/image`，新增 category `"group_chat"`（群消息图片）和 `"group_avatar"`（群头像）。

## WebSocket 设计

### 连接复用

不新建 WebSocket 连接。群聊消息通过现有的 `wss://{host}/ws/chat/{userId}` 连接传输，用 `group_id` 字段区分。

### 消息发送模式

与现有任务聊天一致：**REST API 发送 → 后端持久化 → WebSocket 广播**。不通过 WebSocket 直接发送消息，避免丢消息。

### 新增消息类型

**客户端 → 服务器（仅轻量实时事件走 WebSocket）：**
- `group_typing`：`{ type, group_id }`
- `group_read`：`{ type, group_id, last_read_message_id }`（实时通知其他成员，同时 REST 持久化）

> **WebSocket handler 改动**：需要在 `main.py` 的 WebSocket 消息循环中新增 `group_typing` 和 `group_read` 的 case 分支，转发给群成员。

**服务器 → 客户端：**
- `group_message`：`{ type, group_id, message: {...}, client_message_id? }`
- `group_typing`：`{ type, group_id, sender_id, sender_name }`
- `group_read`：`{ type, group_id, user_id, last_read_message_id }`
- `group_member_joined`：`{ type, group_id, user: {...} }`
- `group_member_left`：`{ type, group_id, user_id }`
- `group_updated`：`{ type, group_id, changes: {...} }`
- `group_message_edited`：`{ type, group_id, message_id, content, edited_at }`
- `group_message_deleted`：`{ type, group_id, message_id }`
- `group_poll_vote`：`{ type, group_id, poll_id, voter_id, option }`

### 广播策略

1. 客户端通过 REST API `POST /api/groups/{id}/messages` 发送消息（携带 `client_message_id`）
2. 后端持久化到 `group_messages` 表，同时更新 `chat_groups.last_message_*` 字段
3. 查询该群所有 active 成员（从 Redis SET `group_members:{group_id}` 缓存读取）
4. 在线成员通过 `asyncio.gather()` 并发调用 `WebSocketManager.send_to_user()` 推送（避免串行 N 次调用）
5. 离线成员加入 FCM/APNs 推送队列（Celery task，异步不阻塞 API 响应）
6. 更新 Redis：群组 last_message 缓存 + 各成员的 `user_conversations:{userId}` sorted set
7. REST API 立即返回创建后的消息对象（客户端用 `client_message_id` 匹配乐观更新，替换临时消息）

### Redis 缓存策略

| Key | 类型 | 说明 | 一致性 |
|-----|------|------|--------|
| `group_members:{group_id}` | SET | 群活跃成员 user_id 集合 | 加入/退出/踢出时同步更新；Redis 重启后首次广播时从 DB 重建并缓存 |
| `user_conversations:{userId}` | SORTED SET | 用户的所有会话（score=lastMessageTime） | 新消息时 ZADD 更新；冷启动时从 DB 查 `chat_groups` + task chats 重建 |
| `group_last_msg:{group_id}` | STRING/HASH | 群最新消息缓存 | 每条新消息时覆写 |
| `group_unread:{userId}` | HASH | 各群未读数 field=group_id value=count | 标记已读时重算；TTL 30s 自然过期后从 DB 重算 |

### 性能优化

- 群成员列表缓存在 Redis SET `group_members:{group_id}`，避免每条消息查 DB
- `typing` 事件只广播给最近 5 分钟活跃的成员
- 大群（>200 人）的 `typing` 事件降频到每 5 秒最多一次
- 大群（>200 人）广播可分批推送（每批 50-100 人，`asyncio.gather` 内分组），避免单次 gather 过大

## Flutter 架构

### 文件结构

```
lib/
├── data/
│   ├── models/
│   │   ├── chat_group.dart          # ChatGroup, GroupMember, JoinRequest, GroupInvitation
│   │   ├── group_message.dart       # GroupMessage（独立于现有 Message）
│   │   └── group_poll.dart          # GroupPoll, PollOption, PollVote
│   └── repositories/
│       └── group_repository.dart    # GroupRepository
│
├── features/
│   └── group_chat/
│       ├── bloc/
│       │   ├── group_list_bloc.dart   # 我的群组列表 + 发现群组
│       │   ├── group_chat_bloc.dart   # 群聊消息
│       │   └── group_manage_bloc.dart # 群组管理
│       └── views/
│           ├── group_discover_view.dart  # 发现群组
│           ├── group_list_view.dart      # 我的群组列表
│           ├── group_chat_view.dart      # 群聊主界面
│           ├── group_info_view.dart      # 群组详情/设置
│           ├── group_members_view.dart   # 成员管理
│           ├── group_create_view.dart    # 创建群组
│           └── widgets/
│               ├── group_message_bubble.dart  # 群消息气泡（显示发送者头像+昵称）
│               ├── poll_card.dart             # 投票卡片
│               ├── share_card.dart            # 分享卡片
│               └── mention_input.dart         # @提及输入框
```

### BLoC 层级

全部 Page 级，无需提升到 Root：

| BLoC | 职责 |
|------|------|
| GroupListBloc | 我的群组列表 + 发现群组，搜索/筛选/分页 |
| GroupChatBloc | 群聊消息，WebSocket 订阅，typing，@提及，乐观更新（client_message_id），cursor 分页 |
| GroupManageBloc | 成员列表、角色变更、禁言、踢出、加入审批、群设置、群主转让 |

已有的 `NotificationBloc`（Root 级）扩展：群聊未读计数、@提及通知。

### 消息列表整合

**Phase 1**：扩展 `MessageBloc` / `MessageView`，群聊与任务聊天并列显示：

- **后端**：新增 `/api/conversations` 端点，或扩展现有 `GET /api/messages/tasks` 返回群聊条目
- **统一会话索引**：在 Redis 维护 `user_conversations:{userId}` sorted set（score = lastMessageTime）
  - 任务聊天/群聊有新消息时，同步更新该 sorted set
  - 拉取列表时：`ZREVRANGE` 分页取出 conversation ID + type，再批量查详情
- **Flutter `MessageBloc` 扩展**：
  - `WebSocketMessage` 增加 `isGroupMessage` getter（匹配 `group_message` 类型）
  - 收到群消息 WebSocket 事件时，触发列表刷新（同现有 task_message 逻辑）
- 置顶逻辑：置顶项排前面，其余按时间倒序
- 不区分类型标记：群组用群名 + 群头像，自然可辨别

### 本地缓存

复用现有 `CacheManager`（双层：内存 + Hive disk，带 TTL 和淘汰），不新建裸 Hive Box：

| Cache Key 前缀 | 内容 | TTL | 说明 |
|----------------|------|-----|------|
| `group_list_` | 我的群组 + 最后消息 + 未读数 | shortTTL (3min) | 打开 app 先显示缓存，后台刷新 |
| `group_msg_{groupId}_` | 群聊消息（cursor 分页的每页） | defaultTTL (5min) | 同现有 `task_msg_` 模式 |
| `group_members_{groupId}` | 成员列表 | shortTTL (3min) | 成员变动频率较高 |
| `group_detail_{groupId}` | 群组详情 | defaultTTL (5min) | 群设置页使用 |

离线回看：`CacheManager.getWithOfflineFallback()` 返回过期缓存数据。

## 分阶段实施

### Phase 1 — 核心群聊（MVP）
- 数据库表 + 迁移脚本（从 `166_` 开始）
- 群组 CRUD API（**创建限达人用户，后端查 `task_experts` 表 status='active'，前端按角色显隐创建按钮**）
- 群主转让 API
- 成员加入/退出/邀请（含 `group_invitations` 表）
- 群消息发送（REST API）/接收（WebSocket 广播），支持文字 + 图片
- 乐观更新：`client_message_id` 去重
- WebSocket 群消息广播（`asyncio.gather()` 并发推送）
- WebSocket handler 新增 `group_typing` / `group_read` 处理分支
- Flutter：群列表 + 群聊页
- 消息列表加入群聊条目（与任务聊天并列，**不含私聊混排**）
- 本地缓存（复用 CacheManager）
- Rate limit：复用现有 `send_message` 限速（30/60s）
- 图片上传：复用现有 upload endpoint，新增 `group_chat`/`group_avatar` category

### Phase 2 — 管理 & 互动
- 三级角色管理（群主/管理员/成员）
- 禁言/踢出/审批加入
- @提及 + 消息回复/引用
- 公告发布/管理
- 消息置顶
- 群组发现（trgm 搜索/分类/标签）
- 文件分享
- 平台管理员审核群组内容（admin 端口）

### Phase 3 — 高级功能
- 投票功能
- 深度联动（分享任务/商品/活动卡片）
- 群内发起任务/活动
- FCM/APNs 离线推送

### Phase 4 — 统一 & 优化
- Conversation 抽象层统一聊天列表（私聊 + 任务聊天 + 群聊三路混排）
- 消息归档策略（冷热分离）
- 大群性能优化（分批广播、消息压缩）
- 消息搜索
