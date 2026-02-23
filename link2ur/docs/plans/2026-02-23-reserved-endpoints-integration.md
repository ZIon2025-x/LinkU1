# Flutter [RESERVED] 端点接入计划

> 创建日期: 2026-02-23
> 目标: 对齐 iOS 原生实现，补全 Flutter 中已有 Repository 但未接入 UI/Bloc 的功能，以及完全缺失的功能。

## 分析方法

通过对比 `api_endpoints.dart` 中标记 `[RESERVED]` 的端点与 iOS 原生代码（`ios/link2ur/link2ur/`），确认哪些在 iOS 中已实现、在 Flutter 中缺失或不完整。

---

## 一、优先级 P0 — 核心交易流程缺口（直接影响用户体验）

### 1.1 跳蚤市场：买家回应还价

| 项目 | 说明 |
|------|------|
| 端点 | `POST /api/flea-market/items/{id}/respond-counter-offer` |
| iOS 状态 | 有数据模型（`sellerCounterPrice` 字段），但 UI 不完整 |
| Flutter 状态 | Repository `respondCounterOffer()` 已有，**Bloc 事件和 UI 缺失** |
| 工作量 | Bloc 事件 + 详情页买家视角添加「接受/拒绝还价」按钮 |
| 涉及文件 | `flea_market_bloc.dart`, `flea_market_detail_view.dart` |

### 1.2 任务申请消息：发送与回复

| 项目 | 说明 |
|------|------|
| 端点 | `POST /api/tasks/{id}/applications/{id}/send-message` |
|      | `POST /api/tasks/{id}/applications/{id}/reply-message` |
| iOS 状态 | ✅ 完整实现（`APIService+Chat.swift`） |
| Flutter 状态 | Repository `sendApplicationMessage()` / `replyApplicationMessage()` 已有，**Bloc 事件和 UI 缺失** |
| 工作量 | TaskDetailBloc 添加事件 + 申请详情中添加消息输入 UI |
| 涉及文件 | `task_detail_bloc.dart`, `task_detail_view.dart` |

---

## 二、优先级 P1 — 完善已有功能的细节

### 2.1 跳蚤市场：同意须知

| 项目 | 说明 |
|------|------|
| 端点 | `POST /api/flea-market/agree-notice` |
| iOS 状态 | 未明确发现 UI，但后端已有 |
| Flutter 状态 | Repository `agreeNotice()` 已有，**Bloc 事件和 UI 缺失** |
| 工作量 | 首次使用跳蚤市场时弹出须知对话框 + Bloc 事件 |
| 涉及文件 | `flea_market_bloc.dart`, `flea_market_view.dart` |

### 2.2 论坛：分类收藏批量获取

| 项目 | 说明 |
|------|------|
| 端点 | `POST /api/forum/categories/favorites/batch` |
| iOS 状态 | ✅ 已实现（`ForumViewModel.swift` 加载分类时批量获取收藏状态） |
| Flutter 状态 | Repository `getCategoryFavoritesBatch()` 已有，**Bloc/UI 未调用** |
| 工作量 | ForumBloc 加载分类时调用批量接口，在分类列表显示收藏状态 |
| 涉及文件 | `forum_bloc.dart`, `forum_view.dart` |

### 2.3 任务达人：我的达人申请状态

| 项目 | 说明 |
|------|------|
| 端点 | `GET /api/task-experts/my-application` |
| iOS 状态 | ✅ 已实现（`TaskExpertsIntroView.swift` 查看申请状态） |
| Flutter 状态 | Repository `getMyExpertApplication()` 已有，**无 Bloc 事件和 UI** |
| 工作量 | Bloc 新增事件 + 达人介绍页显示申请状态 |
| 涉及文件 | `task_expert_bloc.dart`, `task_experts_intro_view.dart` |

### 2.4 私有图片/文件访问

| 项目 | 说明 |
|------|------|
| 端点 | `GET /api/private-image/{imageId}`, `GET /api/private-file` |
| iOS 状态 | ✅ 已实现（任务聊天、客服聊天私密图片、任务证据文件） |
| Flutter 状态 | Repository `getPrivateImage()` / `getPrivateFile()` 已有，**UI 未调用** |
| 工作量 | 在聊天图片展示和任务证据文件下载中使用私有 URL |
| 涉及文件 | `chat_view.dart`, `task_chat_view.dart`, `task_detail_view.dart` |

---

## 三、优先级 P2 — 增强功能（iOS 中已有但非核心）

### 3.1 论坛用户统计/排行

| 项目 | 说明 |
|------|------|
| 端点 | `GET /api/forum/users/{userId}/stats`, `GET /api/forum/users/{userId}/hot-posts`, `GET /api/forum/leaderboard/*`, `GET /api/forum/categories/{id}/stats` |
| iOS 状态 | ❌ 未实现 |
| Flutter 状态 | 端点已定义，无实现 |
| 建议 | 暂不接入（iOS 也未做），等产品需求明确后再实现 |

### 3.2 任务达人管理端（达人侧）

| 项目 | 说明 |
|------|------|
| 端点 | `GET /api/task-experts/me`（我的达人资料）, `GET /api/task-experts/me/services`（我的服务列表）, `GET /api/task-experts/me/applications`（收到的申请）, `GET /api/task-experts/me/dashboard/stats`（仪表盘统计）, `GET /api/task-experts/me/schedule`（日程）, `GET /api/task-experts/me/closed-dates`（关闭日期）, `PUT /api/task-experts/me/services/{id}/time-slots`（管理时间段）, `POST /api/task-experts/me/profile-update-request`（资料更新请求） |
| iOS 状态 | ❌ 未实现达人端管理界面 |
| Flutter 状态 | 端点已定义，部分有 Repository（达人收到的申请有 Bloc 事件），但无独立管理页面 |
| 建议 | 暂不接入完整管理面板（iOS 也未做），但可先实现「收到的申请」管理，因为 Bloc 事件已有 |

### 3.3 消息图片 URL 生成

| 项目 | 说明 |
|------|------|
| 端点 | `POST /api/messages/generate-image-url` |
| iOS 状态 | 使用 `/api/upload/image` 而非此端点 |
| Flutter 状态 | 端点已定义，未使用；Flutter 也使用 `/api/upload/image` |
| 建议 | 无需接入（两端均使用 upload/image） |

### 3.4 议价 Token

| 项目 | 说明 |
|------|------|
| 端点 | `GET /api/notifications/{id}/negotiation-tokens` |
| iOS 状态 | ✅ 已实现 |
| Flutter 状态 | Repository `getNegotiationTokens()` 已有，需确认 UI 是否已调用 |
| 建议 | 确认通知中心的议价通知是否已使用此接口；若未使用，在议价通知点击时加载 token |

### 3.5 IAP 商品列表

| 项目 | 说明 |
|------|------|
| 端点 | `GET /api/iap/products` |
| iOS 状态 | 使用 StoreKit 2 直接从 App Store 加载商品，不依赖此端点 |
| Flutter 状态 | 使用 `in_app_purchase` 插件直接加载，不依赖此端点 |
| 建议 | 无需接入（两端均使用原生 IAP SDK） |

---

## 四、优先级 P3 — 暂缓（iOS 未实现或无需求）

| 端点 | 原因 |
|------|------|
| VIP 状态 `GET /api/users/vip/status` | ✅ Flutter 已实现 |
| 论坛用户统计/排行全套 | iOS 未实现，暂无产品需求 |
| 达人管理完整面板 | iOS 未实现 |
| 消息图片 URL 生成 | 两端均使用 upload/image |
| IAP 商品列表 | 两端均使用原生 IAP SDK |

---

## 五、实施顺序建议

```
阶段 1 (P0): 核心交易缺口     ─── 预计 2-3 天
  ├── 1.1 跳蚤市场买家回应还价（Bloc + UI）
  └── 1.2 任务申请消息发送/回复（Bloc + UI）

阶段 2 (P1): 功能细节完善     ─── 预计 3-4 天
  ├── 2.1 跳蚤市场同意须知
  ├── 2.2 论坛分类收藏批量获取
  ├── 2.3 达人申请状态查看
  └── 2.4 私有图片/文件访问

阶段 3 (P2): 增强功能         ─── 按需
  ├── 3.4 议价 Token 确认与补全
  └── 3.2 达人收到的申请管理页面优化
```

---

## 六、每项工作的具体改动文件

| 任务 | 需改文件 | 改动类型 |
|------|----------|----------|
| 1.1 买家回应还价 | `flea_market_bloc.dart` | 新增事件 `FleaMarketRespondCounterOffer` |
|                  | `flea_market_detail_view.dart` | 买家视角添加接受/拒绝还价 UI |
| 1.2 申请消息 | `task_detail_bloc.dart` | 新增事件 `TaskSendApplicationMessage` / `TaskReplyApplicationMessage` |
|              | `task_detail_view.dart` 或 `task_detail_components.dart` | 申请卡片中添加消息输入 |
| 2.1 同意须知 | `flea_market_bloc.dart` | 新增事件 `FleaMarketAgreeNotice` |
|              | `flea_market_view.dart` | 首次进入时弹出须知对话框 |
| 2.2 论坛批量收藏 | `forum_bloc.dart` | 加载分类后调用 `getCategoryFavoritesBatch` |
|                  | `forum_view.dart` | 分类项显示收藏图标 |
| 2.3 达人申请状态 | `task_expert_bloc.dart` | 新增事件 `TaskExpertLoadMyApplicationStatus` |
|                  | `task_experts_intro_view.dart` | 显示申请状态 |
| 2.4 私有图片/文件 | `chat_view.dart`, `task_chat_view.dart` | 图片消息使用 `getPrivateImage` |
|                   | `task_detail_view.dart` | 证据文件使用 `getPrivateFile` |

---

## 七、备注

- 所有 P0/P1 项的 Repository 方法已实现，只需补 Bloc 事件处理 + UI。
- 实施时应参考 iOS 对应 ViewModel 的逻辑和 API 调用方式。
- P3 中 VIP 状态实际已在 Flutter 中完成，可从 [RESERVED] 标记中移除。
