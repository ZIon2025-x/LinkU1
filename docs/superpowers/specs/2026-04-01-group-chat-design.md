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
- **离线体验**：Hive 本地缓存群聊记录，断网可看历史

## 架构方案

**方案 B：独立群聊表 + 未来 Conversation 统一**

分两阶段：
1. **第一阶段（本次）**：只建群聊相关的新表（`chat_groups`、`group_messages` 等），现有私聊/任务聊天保持不动
2. **第二阶段（后续）**：引入 `Conversation` 统一抽象，把私聊/任务聊天/群聊合并到一个聊天列表模型下

## 消息列表设计

**统一混排**：私聊、任务聊天、群组全部显示在同一个消息列表中，按最后消息时间倒序排列。置顶的排前面。

**不做类型标记**：群组有群名、任务有任务标题、私聊有用户名，天然可区分，不额外加图标/标签/边框。

**头像风格**：保持现有 56px 圆角方形（borderRadius: 16），群组用群组头像，与现有任务聊天图标风格一致。

## 数据模型

### chat_groups

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| name | VARCHAR(100) | 群组名称 |
| description | TEXT | 群组描述 |
| avatar_url | VARCHAR | 群组头像 URL |
| owner_id | VARCHAR FK → users | 群主用户 ID |
| join_mode | ENUM('open','approval','invite') | 加入方式 |
| max_members | INT DEFAULT 1000 | 人数上限 |
| category | VARCHAR(50) | 分类（摄影、编程、设计等） |
| tags | JSON | 标签数组 `["摄影","户外"]` |
| member_count | INT DEFAULT 0 | 当前成员数（冗余计数） |
| is_active | BOOL DEFAULT true | 软删除标记 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 最后更新时间 |

### group_members

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 所属群组 |
| user_id | VARCHAR FK → users | 用户 ID |
| role | ENUM('owner','admin','member') | 角色 |
| nickname | VARCHAR(50) | 群内昵称（可选） |
| muted_until | DATETIME | 禁言截止时间（NULL 表示未禁言） |
| joined_at | DATETIME | 加入时间 |
| status | ENUM('active','banned','left') | 状态 |

约束：`UNIQUE(group_id, user_id)`

### group_messages

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 所属群组 |
| sender_id | VARCHAR FK → users | 发送者（NULL 表示系统消息） |
| content | TEXT | 消息内容 |
| message_type | ENUM('text','image','file','system','poll','share','activity') | 消息类型 |
| reply_to_id | INT FK → group_messages | 回复的消息 ID（NULL 表示非回复） |
| mentions | JSON | 被 @ 的用户 ID 列表 `["user1","user2","all"]` |
| attachments | JSON | 附件列表 `[{type, url, meta}]` |
| meta | JSON | 扩展数据（分享卡片信息、投票 ID 等） |
| is_pinned | BOOL DEFAULT false | 是否置顶 |
| is_deleted | BOOL DEFAULT false | 软删除标记（删除后 reply_to 引用不断链） |
| created_at | DATETIME | 发送时间 |
| edited_at | DATETIME | 编辑时间（NULL 表示未编辑） |

### group_message_reads

| 字段 | 类型 | 说明 |
|------|------|------|
| group_id | INT PK, FK → chat_groups | 群组 ID |
| user_id | VARCHAR PK, FK → users | 用户 ID |
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
| options | JSON | 选项列表 `["选项A","选项B"]` |
| is_anonymous | BOOL DEFAULT false | 是否匿名投票 |
| is_multiple | BOOL DEFAULT false | 是否多选 |
| expires_at | DATETIME | 过期时间 |
| created_by | VARCHAR FK → users | 创建者 |

### group_poll_votes

投票数据独立成表，避免大群并发更新同一 JSON 字段的冲突问题。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| poll_id | INT FK → group_polls | 所属投票 |
| user_id | VARCHAR FK → users | 投票者 |
| option_index | INT | 选项索引（对应 options 数组下标） |
| created_at | DATETIME | 投票时间 |

约束：`UNIQUE(poll_id, user_id, option_index)`（多选时同一用户可投多个选项，但不能重复投同一选项）

### group_join_requests

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 目标群组 |
| user_id | VARCHAR FK → users | 申请者 |
| status | ENUM('pending','approved','rejected') | 审批状态 |
| message | TEXT | 申请理由 |
| reviewed_by | VARCHAR FK → users | 审批人 |
| created_at | DATETIME | 申请时间 |
| reviewed_at | DATETIME | 审批时间 |

### group_announcements

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT PK | 自增主键 |
| group_id | INT FK → chat_groups | 所属群组 |
| message_id | INT FK → group_messages | 关联的消息 |
| pinned_by | VARCHAR FK → users | 置顶操作人 |
| pinned_at | DATETIME | 置顶时间 |

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

-- 投票查询
CREATE INDEX ix_poll_votes_poll ON group_poll_votes(poll_id);
CREATE UNIQUE INDEX ux_poll_votes ON group_poll_votes(poll_id, user_id, option_index);
```

## API 设计

### 群组管理

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/groups` | 创建群组 | 达人用户（Phase 1），后续开放给所有用户 |
| GET | `/api/groups` | 发现群组（搜索/分类/标签筛选） | 登录用户 |
| GET | `/api/groups/my` | 我的群组列表 | 登录用户 |
| GET | `/api/groups/{id}` | 群组详情 | 登录用户 |
| PUT | `/api/groups/{id}` | 编辑群组信息 | 群主/管理员 |
| DELETE | `/api/groups/{id}` | 解散群组 | 群主 |

### 成员管理

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/groups/{id}/join` | 申请/直接加入 | 登录用户 |
| POST | `/api/groups/{id}/invite` | 邀请用户 | 群主/管理员 |
| GET | `/api/groups/{id}/members` | 成员列表 | 群成员 |
| PUT | `/api/groups/{id}/members/{uid}/role` | 设置角色 | 群主 |
| POST | `/api/groups/{id}/members/{uid}/mute` | 禁言 | 群主/管理员 |
| POST | `/api/groups/{id}/members/{uid}/ban` | 踢出 | 群主/管理员 |
| POST | `/api/groups/{id}/leave` | 退出群组 | 群成员 |
| GET | `/api/groups/{id}/join-requests` | 加入申请列表 | 群主/管理员 |
| PUT | `/api/groups/{id}/join-requests/{rid}` | 审批加入申请 | 群主/管理员 |

### 消息

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/groups/{id}/messages` | 消息列表（cursor 分页，cursor = message_id） | 群成员 |
| POST | `/api/groups/{id}/messages` | 发送消息 | 群成员（未禁言） |
| POST | `/api/groups/{id}/messages/read` | 标记已读 | 群成员 |
| PUT | `/api/groups/{id}/messages/{mid}/pin` | 置顶/取消置顶 | 群主/管理员 |
| PUT | `/api/groups/{id}/messages/{mid}` | 编辑消息（仅文字，5 分钟内） | 发送者 |
| DELETE | `/api/groups/{id}/messages/{mid}` | 删除消息（软删除） | 发送者/管理员 |

### 投票 & 公告

| 方法 | 端点 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/groups/{id}/polls` | 创建投票 | 群成员 |
| POST | `/api/groups/{id}/polls/{pid}/vote` | 投票 | 群成员 |
| GET | `/api/groups/{id}/announcements` | 公告列表 | 群成员 |

## WebSocket 设计

### 连接复用

不新建 WebSocket 连接。群聊消息通过现有的 `wss://{host}/ws/chat/{userId}` 连接传输，用 `group_id` 字段区分。

### 新增消息类型

**客户端 → 服务器：**
- `group_message`：`{ type, group_id, content, msg_type, reply_to?, mentions? }`
- `group_typing`：`{ type, group_id }`
- `group_read`：`{ type, group_id, last_read_message_id }`

**服务器 → 客户端：**
- `group_message`：`{ type, group_id, message: {...} }`
- `group_typing`：`{ type, group_id, sender_id, sender_name }`
- `group_read`：`{ type, group_id, user_id, last_read_message_id }`
- `group_member_joined`：`{ type, group_id, user: {...} }`
- `group_member_left`：`{ type, group_id, user_id }`
- `group_updated`：`{ type, group_id, changes: {...} }`
- `group_message_edited`：`{ type, group_id, message_id, content, edited_at }`
- `group_message_deleted`：`{ type, group_id, message_id }`
- `group_poll_vote`：`{ type, group_id, poll_id, voter_id, option }`

### 广播策略

1. 消息持久化到 `group_messages` 表
2. 查询该群所有 active 成员（从 Redis SET `group_members:{group_id}` 缓存读取）
3. 在线成员通过 `WebSocketManager.send_to_user()` 逐一推送
4. 离线成员加入 FCM/APNs 推送队列（Celery task）
5. 更新群组的 last_message 缓存（Redis）

### 性能优化

- 群成员列表缓存在 Redis SET `group_members:{group_id}`，避免每条消息查 DB
- `typing` 事件只广播给最近 5 分钟活跃的成员
- 大群（>200 人）的 `typing` 事件降频到每 5 秒最多一次

## Flutter 架构

### 文件结构

```
lib/
├── data/
│   ├── models/
│   │   ├── chat_group.dart          # ChatGroup, GroupMember, JoinRequest
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
│               ├── group_message_bubble.dart  # 群消息气泡
│               ├── poll_card.dart             # 投票卡片
│               ├── share_card.dart            # 分享卡片
│               └── mention_input.dart         # @提及输入框
```

### BLoC 层级

全部 Page 级，无需提升到 Root：

| BLoC | 职责 |
|------|------|
| GroupListBloc | 我的群组列表 + 发现群组，搜索/筛选/分页 |
| GroupChatBloc | 群聊消息，WebSocket 订阅，typing，@提及，乐观更新，cursor 分页 |
| GroupManageBloc | 成员列表、角色变更、禁言、踢出、加入审批、群设置 |

已有的 `NotificationBloc`（Root 级）扩展：群聊未读计数、@提及通知。

### 消息列表整合

现有 `MessageBloc` / `MessageView` 扩展：
- **统一会话索引**：在 Redis 维护 `user_conversations:{userId}` sorted set（score = lastMessageTime），避免每次三路查询再排序
  - 私聊/任务聊天/群聊有新消息时，同步更新该 sorted set
  - 拉取列表时：`ZREVRANGE` 分页取出 conversation ID，再批量查详情
- 置顶逻辑：置顶项排前面，其余按时间倒序
- 不区分类型标记：群组用群名 + 群头像，自然可辨别

### 本地缓存（Hive）

| Box | 内容 | 策略 |
|-----|------|------|
| `group_list` | 我的群组 + 最后消息 + 未读数 | 打开 app 先显示缓存，后台刷新 |
| `group_messages` | 所有群的消息，key 为 `{groupId}_{messageId}` | 每群保留最近 200 条，超过淘汰最旧的。单 Box 避免群数多时 Box 数量爆炸 |
| `group_members` | 所有群的成员列表，key 为 `{groupId}` | TTL 5 分钟 |

## 分阶段实施

### Phase 1 — 核心群聊（MVP）
- 数据库表 + 迁移脚本
- 群组 CRUD API（**创建限达人用户，后端校验 `is_expert`，前端按角色显隐创建按钮**）
- 成员加入/退出/邀请
- 群消息发送/接收（文字 + 图片）
- WebSocket 群消息广播
- Flutter：群列表 + 群聊页
- 消息列表统一混排
- Hive 本地缓存

### Phase 2 — 管理 & 互动
- 三级角色管理（群主/管理员/成员）
- 禁言/踢出/审批加入
- @提及 + 消息回复/引用
- 公告置顶
- 群组发现（搜索/分类/标签）
- 文件分享

### Phase 3 — 高级功能
- 投票功能
- 深度联动（分享任务/商品/活动卡片）
- 群内发起任务/活动
- FCM/APNs 离线推送

### Phase 4 — 统一 & 优化
- Conversation 抽象层统一聊天列表
- 消息归档策略（冷热分离）
- 大群性能优化
- 消息搜索
