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
| last_message_id | INT | 最新消息 ID（冗余，**无 FK** — 避免与 group_messages 循环依赖，应用层保证一致） |
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
| muted_until | DATETIME | 禁言截止时间（NULL 表示未禁言，管理员操作） |
| notification_muted | BOOL DEFAULT false | 用户主动免打扰（不影响发消息，只跳过推送） |
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

#### 未读数计算

对齐现有 `UnreadCountLogic`（`task_chat_business_logic.py`）模式：

```sql
-- 单群未读
SELECT COUNT(*) FROM group_messages
WHERE group_id = :gid AND id > :last_read_message_id
  AND sender_id != :current_user AND is_deleted = false;

-- 批量未读（消息列表页）：收集用户所有群的 cursor，分组查询，Redis 缓存 30s
```

#### `last_message_preview` 内容规范

非文字消息存 i18n key，客户端根据 locale 翻译：

| message_type | preview 值 | 客户端显示（中/英） |
|-------------|-----------|-------------------|
| text | 截取前 100 字符 | 原文 |
| image | `msg_type_image` | [图片] / [Image] |
| file | `msg_type_file` | [文件] / [File] |
| system | `msg_type_system` | [系统消息] / [System] |
| poll | `msg_type_poll` | [投票] / [Poll] |
| share | `msg_type_share` | [分享] / [Share] |
| activity | `msg_type_activity` | [活动] / [Activity] |

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
| POST | `/api/groups/{id}/members/{uid}/unban` | 解禁（status→left，允许重新加入） | 群主/管理员 |
| PUT | `/api/groups/{id}/notification-mute` | 设置免打扰（body: `{muted: bool}`） | 群成员本人 |
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

> **已读标记**：客户端只通过 REST `POST /api/groups/{id}/messages/read` 持久化已读状态。后端持久化后，对**小群（≤50 人）**通过 WS 广播 `group_read` 事件；**大群（>50 人）不广播**（前端按需查询"N 人已读"聚合数）。
>
> **WebSocket handler 改动**：需要在 `main.py` 的 WebSocket 消息循环中新增 `group_typing` 的 case 分支，转发给群成员。

**服务器 → 客户端：**
- `group_message`：`{ type, group_id, message: {...}, client_message_id? }`
- `group_typing`：`{ type, group_id, sender_id, sender_name }`
- `group_read`：`{ type, group_id, user_id, last_read_message_id }`（仅小群 ≤50 人，由后端在 REST 已读接口中触发）
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
5. 离线成员加入 FCM/APNs 推送队列（Celery task，异步不阻塞 API 响应）；**跳过 `notification_muted=true` 的成员**
6. 更新 Redis：群组 last_message 缓存 + 各成员的 `user_conversations:{userId}` sorted set
7. REST API 立即返回创建后的消息对象（客户端用 `client_message_id` 匹配乐观更新，替换临时消息）

### Redis 缓存策略

| Key | 类型 | 说明 | 一致性 |
|-----|------|------|--------|
| `group_members:{group_id}` | SET | 群活跃成员 user_id 集合 | 加入/退出/踢出时同步更新；Redis 重启后首次广播时从 DB 重建并缓存 |
| `user_conversations:{userId}` | SORTED SET | 用户的所有会话（score=lastMessageTime） | 新消息时 ZADD 更新；冷启动时从 DB 查 `chat_groups` + task chats 重建 |
| `group_last_msg:{group_id}` | STRING/HASH | 群最新消息缓存 | 每条新消息时覆写 |
| `group_unread:{userId}` | HASH | 各群未读数 field=group_id value=count | 标记已读时重算；TTL 30s 自然过期后从 DB 重算 |

### 通知集成

新增 Notification type（应用层校验，无需 DB 迁移）：

| type | 触发场景 | related_type | related_id |
|------|----------|-------------|------------|
| `group_invitation` | 收到群邀请 | `group_id` | group_id |
| `group_join_request` | 收到加入申请（通知群主/管理员） | `group_id` | group_id |
| `group_mention` | 群内被 @（含 @all） | `group_id` | group_id |
| `group_announcement` | 新公告发布 | `group_id` | group_id |

Flutter 端 `notification_list_view.dart` 的 if-chain 加 `group_*` 前缀路由跳转到 `/groups/{id}`。

> **@all 权限**：`mentions` 中包含 `"all"` 时，后端校验发送者必须是 `owner` 或 `admin`，否则拒绝。普通成员只能 @ 具体用户。

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

### GoRouter 路由

在 `app_routes.dart` 新增：

```dart
static const String groupDiscover = '/groups/discover';
static const String groupCreate = '/groups/create';
static const String groupChat = '/groups/:groupId';
static const String groupInfo = '/groups/:groupId/info';
static const String groupMembers = '/groups/:groupId/members';
```

在 `app_router.dart` 中加入对应 `GoRoute`，群聊页面不在 `ShellRoute`（底部 Tab）内，走独立的全屏页面栈。

### BLoC 层级

全部 Page 级，无需提升到 Root：

| BLoC | 职责 |
|------|------|
| GroupListBloc | 我的群组列表 + 发现群组，搜索/筛选/分页 |
| GroupChatBloc | 群聊消息，WebSocket 订阅，typing，@提及，乐观更新（client_message_id），cursor 分页 |
| GroupManageBloc | 成员列表、角色变更、禁言、踢出、加入审批、群设置、群主转让 |

已有的 `NotificationBloc`（Root 级）扩展：群聊未读计数、@提及通知。

### 消息列表整合

**Phase 1**：扩展 `MessageBloc` / `MessageView`，群聊与任务聊天并列显示。

#### 类型适配

> **现状**：`displayTaskChats` 返回 `List<TaskChat>`，`TaskChat` 含 `taskId`/`taskTitle`/`taskStatus` 等任务特有字段，群聊无法塞入。

引入通用包装类型 `ConversationItem`（`lib/data/models/conversation_item.dart`）：

```dart
class ConversationItem extends Equatable {
  final String type;           // 'task' | 'group'
  final int id;                // taskId 或 groupId
  final String title;          // taskTitle 或 groupName
  final String? subtitle;      // 角色描述 / 成员数
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? avatarUrl;
  final TaskChat? taskChat;    // type='task' 时非空
  final ChatGroup? chatGroup;  // type='group' 时非空
}
```

- `MessageBloc` 的 state 改为 `List<ConversationItem>`
- `_TaskChatItem` widget 改为通用 `_ConversationItem`，根据 `type` 分发渲染
- 点击跳转：task → `/task-chat/:taskId`，group → `/groups/:groupId`

#### 后端聚合

- 新增 `GET /api/conversations` 端点，返回统一格式的会话列表（任务聊天 + 群聊混排）
- **统一会话索引**：在 Redis 维护 `user_conversations:{userId}` sorted set（score = lastMessageTime）
  - member 格式：`task:{taskId}` 或 `group:{groupId}`（前缀区分类型）
  - 任务聊天/群聊有新消息时，同步 `ZADD` 更新
  - 拉取列表时：`ZREVRANGE` 分页取出 → 按前缀分组 → 批量查详情 → 合并返回
- 现有 `GET /api/messages/tasks` 保留不动（向后兼容）

#### Flutter 扩展

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
- 数据库表 + 迁移脚本（从 `166_` 开始，`last_message_id` 无 FK 避免循环依赖）
- 群组 CRUD API（**创建限达人用户，后端查 `task_experts` 表 status='active'，前端按角色显隐创建按钮**）
- **Phase 1 只支持 `open` 加入模式**（创建时 join_mode 强制 open，approval/invite 留到 Phase 2）
- 群主转让 API
- 成员加入/退出（`group_invitations` 表建好但 Phase 1 不启用邀请功能）
- 群消息发送（REST API）/接收（WebSocket 广播），支持文字 + 图片
- 乐观更新：`client_message_id` 去重
- WebSocket 群消息广播（`asyncio.gather()` 并发推送）
- WebSocket handler 新增 `group_typing` 处理分支
- Flutter：群列表 + 群聊页 + `ConversationItem` 通用包装类型
- 消息列表加入群聊条目（与任务聊天并列，**不含私聊混排**）
- 已读标记（REST 持久化，小群 ≤50 人广播 `group_read`）
- 未读数计算（对齐现有 `MessageReadCursor` 模式）
- 本地缓存（复用 CacheManager）
- 免打扰（`notification_muted`）
- Rate limit：复用现有 `send_message` 限速（30/60s）
- 图片上传：复用现有 upload endpoint，新增 `group_chat`/`group_avatar` category
- 通知类型：`group_invitation`/`group_mention`/`group_announcement`/`group_join_request`

### Phase 2 — 管理 & 互动
- 三级角色管理（群主/管理员/成员）
- 禁言/踢出/解禁
- approval + invite 加入模式（启用 `group_join_requests` 审批 + `group_invitations` 邀请）
- @提及（@all 限群主/管理员）+ 消息回复/引用
- 公告发布/管理
- 消息置顶
- 群组发现（trgm 搜索/分类/标签）
- 文件分享
- 平台管理员审核群组内容（admin 端口）
- 群主账号被平台封禁时自动转让给最资深管理员，无管理员则冻结群组

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

---

## 达人内部群聊（依赖群聊 Phase 1 完成后实施）

达人团队体系（`docs/superpowers/specs/2026-04-04-expert-team-redesign.md`）的 Phase 4 需要群聊基础系统支持。当群聊 Phase 1 完成后，按以下方案接入达人内部群聊。

### 概述

每个达人团队自动拥有一个私密的内部群聊，成员变动自动同步，不支持手动邀请外部人。

### 集成方式

复用 `chat_groups` 表，达人创建时自动创建一个特殊类型的群：

- `type = 'expert_internal'`（新增类型，区别于普通兴趣群 `'normal'`）
- `name = 达人团队名称 + " 内部群"`
- `owner_id = 达人 Owner 的 user_id`
- `join_mode = 'invite'`（不开放加入，完全由团队成员变动驱动）
- `max_members = 20`（与达人团队上限一致）

### `experts` 表关联

`experts.internal_group_id` 字段已存在（Phase 1a 创建），当前为 NULL。群聊系统上线后：

```sql
-- 为已有达人创建内部群聊
INSERT INTO chat_groups (name, type, owner_id, join_mode, max_members)
SELECT
    e.name || ' 内部群',
    'expert_internal',
    em.user_id,  -- owner 的 user_id
    'invite',
    20
FROM experts e
JOIN expert_members em ON em.expert_id = e.id AND em.role = 'owner' AND em.status = 'active'
WHERE e.internal_group_id IS NULL AND e.status = 'active';

-- 关联 internal_group_id
UPDATE experts e
SET internal_group_id = cg.id
FROM chat_groups cg
WHERE cg.type = 'expert_internal'
  AND cg.owner_id = (SELECT em.user_id FROM expert_members em WHERE em.expert_id = e.id AND em.role = 'owner' LIMIT 1)
  AND e.internal_group_id IS NULL;

-- 把所有活跃成员加入群聊
INSERT INTO group_members (group_id, user_id, role)
SELECT
    e.internal_group_id,
    em.user_id,
    CASE em.role WHEN 'owner' THEN 'owner' WHEN 'admin' THEN 'admin' ELSE 'member' END
FROM experts e
JOIN expert_members em ON em.expert_id = e.id AND em.status = 'active'
WHERE e.internal_group_id IS NOT NULL
ON CONFLICT (group_id, user_id) DO NOTHING;
```

### 成员自动同步

在 `expert_routes.py` 的以下端点中，成员变动后同步到群聊：

| 团队事件 | 群聊操作 | 端点 |
|---------|---------|------|
| 用户加入团队（邀请/申请通过） | `INSERT INTO group_members` | `respond_to_invitation`, `review_join_request` |
| 用户退出团队 | `UPDATE group_members SET status='left'` | `leave_team` |
| 用户被移除 | `UPDATE group_members SET status='banned'` | `remove_member` |
| Owner 转让 | `UPDATE group_members` 双方角色 + `UPDATE chat_groups SET owner_id` | `transfer_ownership` |
| 成员角色变更 | `UPDATE group_members SET role` | `change_member_role` |

### 与普通群聊的区别

| | 普通群聊 | 达人内部群聊 |
|--|---------|-------------|
| 创建方式 | 用户手动创建 | 达人创建时自动生成 |
| type | `'normal'` | `'expert_internal'` |
| 成员管理 | 群内邀请/申请 | 团队成员变动自动同步 |
| 解散条件 | 群主解散 | 达人注销时自动解散 |
| 邀请外部人 | 可以 | 不可以 |
| 退出方式 | 自行退出 | 退出团队时自动退出 |
| 在消息列表中 | 显示 | 显示（和普通群聊一样） |

### chat_groups 表需要的扩展

`chat_groups` 设计中 `type` 字段目前未定义（spec 中无此列）。需要在 Phase 1 建表时加入：

```sql
ALTER TABLE chat_groups ADD COLUMN IF NOT EXISTS type VARCHAR(20) NOT NULL DEFAULT 'normal';
-- type: 'normal' (普通群聊) | 'expert_internal' (达人内部群聊)
```

### 后端代码改动点

1. **`admin_expert_routes.py` `review_application`（approve 分支）**：创建群聊 + 设 `internal_group_id`
2. **`expert_routes.py` `dissolve_expert_team`**：解散内部群聊
3. **`expert_routes.py` 成员变动端点**：同步到 `group_members`
4. **群聊路由**：`type='expert_internal'` 的群禁止手动邀请/申请加入

### Flutter 改动点

1. 达人详情页加"内部群聊"入口按钮 → 跳转到 `GroupChatView(groupId: expert.internalGroupId)`
2. `ExpertTeam` 模型已有 `internalGroupId` 字段的存储位但尚未解析（加 `json['internal_group_id']`）
3. 消息列表中自然显示（群聊 Phase 1 的消息列表混排已覆盖）
