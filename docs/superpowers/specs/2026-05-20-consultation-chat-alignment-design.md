# 咨询聊天对齐任务聊天 — 设计文档

日期：2026-05-20
分支：main（直推 main，参见 feedback_direct_to_main）

## 背景与动机

仓库里目前存在 3 个聊天界面：

| 界面 | 文件 | 行数 | 用途 |
|---|---|---|---|
| `ChatView` | `link2ur/lib/features/chat/views/chat_view.dart` | 566 | P2P 用户聊天（消息中心入口） |
| `TaskChatView` | `link2ur/lib/features/chat/views/task_chat_view.dart` | 1218 | 成交后的任务工作聊天，全媒体能力 |
| `ApplicationChatView` | `link2ur/lib/features/tasks/views/application_chat_view.dart` | 1749 | 议价阶段 + 咨询（service / task / fleaMarket 三种） |

`ApplicationChatView` 业务上是 `TaskChatView` 的超集（多了议价/报价/还价/批准等业务），但 **媒体/聚合/上传体验是子集**（无视频消息、无文件消息、无消息聚合气泡、无媒体上传进度 banner、无 ActionMenu）。底层架构上 ApplicationChatView 自己管 WebSocket + 分页 + 消息加载，而 TaskChatView 用 ChatBloc。两边重复实现且体验割裂。

本次重构目标：

1. **统一气泡样式** — 咨询聊天换用 `MessageGroupBubble`（带头像 / 时间分组 / 系统消息样式）
2. **统一输入区 + ActionMenu** — 咨询聊天复用 `task_chat_action_menu.dart`，自动获得相册/相机/文件/位置入口
3. **底层架构对齐** — 咨询聊天的消息流改走 `ChatBloc`，不再各写一套 WS / 分页 / 加载逻辑

延伸目标：抽出 `ConsultationBloc`，让 `TaskDetailBloc` 回归"只管任务详情"本职。

## 关键发现

**ApplicationChatView 的消息加载/发送走的是和 TaskChatView 同一个 endpoint**（`ApiEndpoints.taskChatMessages(taskId)` + `ApiEndpoints.taskChatSend(taskId)`），仅在 application 模式下额外带 `application_id` 字段（由 `ConsultationActions.needsApplicationIdInMessages` 控制）。

意味着 ChatBloc 不需要新增"channel 类型"分支，只需在现有 taskId 路径上加一个可选 `applicationId` 透传给同一个 endpoint。

## 重构方案 — 方案 A（已确认）

扩 ChatBloc 加 application 维度 + 议价业务**新抽** ConsultationBloc + ChatScaffold / MessageGroupBubble 共用 widget。已否决的备选：

- 方案 B（抽 ChatCoreBloc 基类）：BLoC 继承在 Flutter 不是推荐做法，state/event 泛型混乱
- 方案 C（不动 ChatBloc，只共享 widget）：违背"底层架构对齐"初衷，消息分页/WS 逻辑重复实现

## 架构总览

```
                                ┌─ ChatBloc (扩 applicationId 字段)
ApplicationChatView ─┬─ 消息流  ┤
                     │          └─ MessageRepository (现有端点 + application_id)
                     │
                     │          ┌─ ConsultationBloc (新)
                     ├─ 议价业务┤   onNegotiate / onQuote / onCounterOffer
                     │          │   onFormalApply / onApprove / onClose
                     │          │   按 ConsultationType 内部派发到对应 repository
                     │
                     │          ┌─ ChatScaffold (新, 共用)
                     ├─ UI 骨架 ┤   header slot / messages / inputBar / actionMenu
                     │          │
                     │          └─ MessageGroupBubble (加 customBubbleBuilder)
                     │
                     └─ 顶部 / 底部业务 widget
                           ServiceInfoCard / PriceBar / ReadOnlyBanner / ClosedBanner
                           ConsultationActionBar (议价/报价/还价/批准/关闭按钮)
                           NegotiationActionCard (最新议价的接受/拒绝/还价浮卡)

TaskChatView ───── 消息流 / UI 骨架 (复用同一套 ChatBloc + ChatScaffold + MessageGroupBubble)

TaskDetailBloc ─── 回归本职 (只管 task 详情加载)，不再处理议价业务 action
```

## ChatBloc 扩展

### 事件层

```dart
class ChatLoadMessages extends ChatEvent {
  const ChatLoadMessages({
    required this.userId,
    this.taskId,
    this.applicationId,   // 新增
  });
  final int? applicationId;
}

// ChatSendMessage / ChatSendImage / ChatSendVideo / ChatSendFile 同样新增 applicationId
```

### 状态层

`ChatState` 加 `currentApplicationId` 字段，用于 reload / loadMore / WebSocket 过滤时复用。

### Repository 层

`MessageRepository` 的 4 个发送方法 + GET 方法各加可选 `int? applicationId`：存在时序列化进 body/query 的 `application_id` 字段。**端点本身不变**——复用 `ApiEndpoints.taskChatMessages(taskId)` / `ApiEndpoints.taskChatSend(taskId)`。

### WebSocket 过滤

```dart
void _onWsMessage(WebSocketMessage wsMessage) {
  if (message.taskId != state.taskId) return;
  
  // 新增: application 模式下还要看 applicationId, 顺手修复同一 task 多 application 串台的潜在 bug
  if (state.applicationId != null && message.applicationId != state.applicationId) return;
}
```

**实施前需验证**：`Message.fromJson` 是否已正确解析后端推送中的 `application_id` 字段；若未解析需要在 Message 模型里加字段。

### TaskChatView 兼容性

现有 `ChatLoadMessages(userId: '', taskId: taskId)` 调用零变化——`applicationId` 默认 null。任务聊天回归 0 风险。

### 规模

ChatBloc 总行数预估：986 → ~1100（4 个可选字段 + WS 过滤 + 一处 reload 逻辑）

## ChatScaffold widget

新建 `link2ur/lib/features/chat/widgets/chat_scaffold.dart`，约 200 行，承载两个聊天页共有的骨架。

```dart
class ChatScaffold extends StatelessWidget {
  const ChatScaffold({
    super.key,
    required this.appBarTitle,
    required this.appBarActions,
    required this.headerSlot,         // 任务: TaskInfoCard / 咨询: PriceBar+ServiceInfoCard
    required this.bannerSlot,         // ReadOnlyBanner / ClosedBanner / MediaProgressBanner
    required this.messageListBuilder, // 自定义渲染 (由父传入,用 MessageGroupBubble)
    required this.inputBar,           // readOnly 时父传 SizedBox.shrink()
    required this.actionMenu,         // TaskChatActionMenu, readOnly 时同上
    this.aboveInputSlot,              // 咨询: ConsultationActionBar; 任务: null
    this.scrollController,
    this.onScrollNearTop,             // 触底拉更多 (旧消息) 的回调
  });
}
```

**布局自顶向下**：

```
AppBar (title + actions)
├─ headerSlot              ← 任务: TaskInfoCard / 咨询: PriceBar+ServiceInfoCard
├─ bannerSlot              ← ReadOnly / Closed / MediaProgress
├─ Expanded
│  └─ messageListBuilder() ← ListView.builder(reverse: true) 用 MessageGroupBubble
├─ aboveInputSlot          ← 咨询: ConsultationActionBar
├─ inputBar                ← TextField + 发送按钮
└─ AnimatedSize(actionMenu)← + 号面板展开
```

**readOnly 处理**：父在传 inputBar/actionMenu/aboveInputSlot 时按需传 `SizedBox.shrink()`，ChatScaffold 自己不管 readOnly 概念，保持单一职责。

### 顺带迁移到独立 widget 文件

| 来源 | 新位置 |
|---|---|
| `TaskChatView._buildTaskInfoCard` | `chat/widgets/task_info_card.dart` |
| `TaskChatView._buildMediaProgressBanner` | `chat/widgets/media_progress_banner.dart` |
| `TaskChatView._buildClosedTaskBar` | `chat/widgets/closed_task_banner.dart` |
| `ApplicationChatView._buildPriceBar` | `tasks/views/consultation/widgets/price_bar.dart` |
| `ApplicationChatView._buildServiceInfoCard` | `tasks/views/consultation/widgets/service_info_card.dart` |
| `ApplicationChatView._buildReadOnlyBanner` | `tasks/views/consultation/widgets/read_only_banner.dart` |
| `ApplicationChatView._buildClosedBanner` | `tasks/views/consultation/widgets/closed_consultation_banner.dart` |
| `ApplicationChatView._buildPriceProposalBubble` | `tasks/views/consultation/widgets/price_proposal_bubble.dart` |
| `ApplicationChatView._buildNegotiationCard` | `tasks/views/consultation/widgets/negotiation_action_card.dart` |
| `ApplicationChatView._buildNegotiationStatusMessage` | `tasks/views/consultation/widgets/negotiation_status_banner.dart` |

## 议价业务气泡 — 在分组逻辑里特殊处理

### Message 类型枚举

| `message_type` | 含义 | 渲染方式 |
|---|---|---|
| `text` | 普通文本 | MessageGroupBubble 默认气泡 |
| `image` / `video` / `file` | 媒体 | MessageGroupBubble 默认气泡 |
| `system` | 系统消息（"已批准"等） | groupMessages flushGroup 独立成组（已有） |
| `price_proposal` | 价格提议（议价/报价/还价的快照） | **新：** flushGroup 独立成组 + customBubbleBuilder |
| `negotiation_status` | 议价状态变化（"对方已还价 £50"） | **新：** 当 system 子类型处理 |

**实施前需校准**：检查后端 `message_type` 实际枚举值是否就是 `price_proposal` / `negotiation_status`，命名以后端为准。

### groupMessages() 改造

`link2ur/lib/features/chat/widgets/message_group_bubble.dart:47` 现有 `groupMessages` 函数加判断：

```dart
for (final message in messages) {
  final isSpecialBubble = message.isSystem
      || message.messageType == 'price_proposal'
      || message.messageType == 'negotiation_status';
  
  if (isSpecialBubble) {
    flushGroup();
    groups.add(MessageGroup(
      messages: [message],
      direction: ...,
      isSystem: message.isSystem,
      // price_proposal / negotiation_status 走 customBubbleBuilder
    ));
    continue;
  }
  // ... 原有按 sender + time 分组逻辑
}
```

### MessageGroupBubble 接口扩展

```dart
class MessageGroupBubble extends StatelessWidget {
  const MessageGroupBubble({
    // ... 原有
    this.customBubbleBuilder,
  });
  
  /// 返回 null 时回落到默认气泡逻辑；返回 Widget 则用自定义替换整个气泡区
  final Widget? Function(BuildContext, Message)? customBubbleBuilder;
}
```

- **任务聊天调用方**：不传 customBubbleBuilder，行为零变化
- **咨询聊天调用方**：传 builder 内部 switch on `message.messageType`，分发到 `PriceProposalBubble` / `NegotiationStatusBanner`

### NegotiationActionCard 安置

最新议价的"接受/拒绝/还价"操作浮卡（现有 `_buildNegotiationCard`）不是普通消息气泡，而是**贴在最新一条 price_proposal 旁的浮动面板**。留在 `_ConsultationChatView` 父层渲染，紧贴最新 price_proposal 显示——和 system message 同等地位。

## ConsultationBloc — 新

新建 `link2ur/lib/features/tasks/bloc/consultation_bloc.dart`，沿用项目"单文件 events+state+bloc 不用 part of"约定（CLAUDE.md 明文规定）。

### 状态

```dart
class ConsultationState extends Equatable {
  final int applicationId;
  final int taskId;
  final ConsultationType consultationType;
  final Map<String, dynamic>? consultationApp;  // 议价上下文快照
  final ConsultationStatus status;              // negotiating/quoted/approved/closed/readOnly
  final bool isSubmitting;
  final String? errorCode;
}
```

### 事件

```dart
ConsultationLoadStatus
ConsultationNegotiate({double price, int? serviceId})
ConsultationQuote({double price, String? message, int? serviceId})
ConsultationCounterOffer({double price, int? serviceId})
ConsultationRespond({String action})   // accept / reject / counter
ConsultationFormalApply({double price, String? message})
ConsultationApprove
ConsultationClose
```

### 内部派发

ConsultationBloc 内部按 `consultationType` 派发到对应 repository：

| consultationType | repository |
|---|---|
| service | TaskExpertRepository（或团队相关 repo，按 expert_id 存在判断） |
| task | TaskRepository |
| fleaMarket | FleaMarketRepository |

`ConsultationActions` 抽象层（现有 `consultation_base.dart` + 3 个子类）**删除**——逻辑搬进 ConsultationBloc 内部 private 方法，dialog widgets（`_NegotiateDialog` / `_QuoteDialog` / `_CounterOfferDialog` / `_FormalApplyDialog`）保留为独立 widget 文件供 UI 触发。

### TaskDetailBloc 回归本职

- 删除议价相关的 events / state / handler
- 保留：`TaskDetailLoadRequested`、task 数据加载
- ApplicationChatView 不再依赖 TaskDetailBloc 来跑议价业务；议价 chat 场景（chat-before-payment）仍可继续 provide TaskDetailBloc 用于展示任务详情

### ApplicationChatView 的 BlocProvider

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => ConsultationBloc(...)..add(ConsultationLoadStatus())),
    BlocProvider(create: (_) => ChatBloc(...)..add(ChatLoadMessages(taskId, applicationId))),
    // TaskDetailBloc 仅在需要展示完整任务详情时才 provide
  ],
)
```

## 5 种场景的入口分发

| 场景 | `isConsultation` | `consultationType` | `readOnly` | 需要的 bloc | header / aboveInput slot |
|---|---|---|---|---|---|
| 议价 (chat-before-payment) | false | (默认) | false | ChatBloc + TaskDetailBloc | PriceBar / ConfirmAndPayBar |
| Service 咨询 | true | service | false | ChatBloc + ConsultationBloc | ServiceInfoCard / ConsultationActionBar |
| Task 咨询 | true | task | false | ChatBloc + ConsultationBloc | TaskInfoCardForConsultation / ConsultationActionBar |
| FleaMarket 咨询 | true | fleaMarket | false | ChatBloc + ConsultationBloc | FleaItemCard / ConsultationActionBar |
| 议价历史回看 | (任意) | (任意) | true | ChatBloc | ReadOnlyBanner + PriceBar / null |

### 入口拆三个内部 View

`ApplicationChatView` 改造为薄分发：

```dart
class ApplicationChatView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (readOnly) return _ReadOnlyChatView(taskId, applicationId);
    if (isConsultation) return _ConsultationChatView(taskId, applicationId, consultationType);
    return _BiddingChatView(taskId, applicationId);  // chat-before-payment
  }
}
```

三个内部 View 各自管自己需要的 bloc，对应实际场景需求，不再"一个 View 五种 mode if-else"。

**_ConsultationChatView 内部按 consultationType 切 header widget**：

```dart
Widget _consultationHeader(ConsultationType type) {
  switch (type) {
    case ConsultationType.service:    return const ServiceInfoCard();
    case ConsultationType.task:       return const TaskInfoCard();   // 复用从 TaskChatView 抽出的
    case ConsultationType.fleaMarket: return const FleaMarketItemCard();
  }
}
```

每个独有 header widget（ServiceInfoCard / FleaMarketItemCard）独立成文件，独立测试。Task 咨询直接复用从 TaskChatView 抽出的 `TaskInfoCard`——成本最低，因为 task 咨询的头部信息和 task 工作群完全一致。

**AppBar 标题**：现有 `_consultationTitle` 把后端返回的"团队咨询: xxx" / "Consultation: xxx" 等前缀剥离再加本地化类型标签——这段逻辑搬到独立 helper `consultation/utils/consultation_title.dart`，由 `_ConsultationChatView` 计算后传给 ChatScaffold。

**_ReadOnlyChatView 最简**：只 provide ChatBloc + 渲染 ChatScaffold 的 header/messages 两个 slot，inputBar/actionMenu/aboveInputSlot 传 SizedBox.shrink()。

**路由层不变**：`task_routes.dart:78` 的 `ApplicationChatView(taskId, applicationId, isConsultation, consultationType, readOnly)` 签名保持，外部 0 感知。

## 渐进迁移顺序

每步独立可 commit、独立可测试、独立可回滚。

1. **基建** — ChatBloc 加 applicationId 字段 + MessageGroupBubble customBubbleBuilder + groupMessages 特殊气泡支持。两条聊天页都不动，验证现有任务聊天回归通过
2. **抽 widget** — ChatScaffold + TaskInfoCard / MediaProgressBanner / ClosedTaskBanner 抽出。TaskChatView 切换到 ChatScaffold，验证任务聊天 UI 0 变化
3. **抽 ConsultationBloc** — 写完整 bloc + tests。**先不接 UI**，独立验证 bloc 测试通过
4. **接 service consultation** — `_ConsultationChatView` 落地 service 类型 + 接 ConsultationBloc。冒烟测试 service 咨询整条流程（议价/报价/还价/批准/关闭）
5. **接 task 和 fleaMarket consultation** — 同上模式扩展两种类型
6. **接议价 (chat-before-payment)** — `_BiddingChatView` 实现，TaskDetailBloc 在这里继续 provide
7. **接 readOnly** — `_ReadOnlyChatView` 实现
8. **清理** — 删 ApplicationChatView 旧的 `_ApplicationChatContent` State（1500+ 行）+ ConsultationActions 抽象（逻辑已搬到 ConsultationBloc 内部）

## 错误处理

沿用项目现状（CLAUDE.md 已规定）：bloc state 存 `errorCode: String`（错误码，不是 UI 文本），UI 层用 `context.localizeError(state.errorCode)` 翻译。

### ChatBloc 新增 error codes

- `chat_application_not_found` — application_id 已被取消/删除
- `chat_application_forbidden` — 用户不在 application 双方名单里

### ConsultationBloc 新增 error codes

- `consultation_load_failed`
- `consultation_negotiate_failed`
- `consultation_quote_failed`
- `consultation_counter_offer_failed`
- `consultation_formal_apply_failed`
- `consultation_approve_failed`
- `consultation_close_failed`
- `consultation_state_conflict` — 状态机不允许（例如已关闭还想 negotiate）
- `consultation_service_required` — Service 类型未选具体 service

每个 error code 在 3 份 ARB 文件（en / zh / zh_Hant）加翻译 + `ErrorLocalizer.localize()` 加 case。

### UI 反馈

- 全页错误（加载状态失败）→ `ErrorStateView` + retry
- 议价提交失败（snackbar）→ `SnackBar(content: Text(context.localizeError(state.errorCode)))`

## 测试策略

### Bloc 单测（bloc_test + mocktail）

| Bloc | 覆盖场景 | 估算用例数 |
|---|---|---|
| ChatBloc（新增的 applicationId 路径） | load / loadMore / send×4 各带/不带 applicationId × 成功/失败/网络断开 | +20 |
| ConsultationBloc | 6 个 action × 3 个 type × 成功/失败 + readOnly 无 action + loadStatus 成功/失败/forbidden + 状态机非法转换 | ~40 |
| TaskDetailBloc | 验证议价相关 events 已删除 / 现有 task detail load 路径不变 | 回归现有用例 |

### Widget 测试

| Widget | 测什么 |
|---|---|
| MessageGroupBubble | customBubbleBuilder 返回 null 走默认 / 返回 Widget 替换；price_proposal / negotiation_status 类型独立成组 |
| ChatScaffold | 各 slot 传 null 时不渲染；readOnly 配置（无 input/menu）布局正确 |
| ConsultationActionBar | 6 个按钮在不同 status 下的显隐 + disable 状态 |
| NegotiationActionCard | accept / reject / counter 点击触发对应 event |

### 集成回归（手测清单）

1. **任务聊天** 发文本/图片/视频/文件 — 0 变化验证
2. **Service 咨询** 全流程：议价 → 对方报价 → 还价 → 批准 → 进入任务工作群
3. **Task 咨询** 全流程同上
4. **FleaMarket 咨询**：确认购买 → 支付
5. **chat-before-payment 议价**：发起申请 → 报价 → 确认支付
6. **议价历史 readOnly**：无输入框、无操作按钮、能正常滚动看历史

## 规模评估

| 改动 | 行数估算 |
|---|---|
| ChatBloc 扩展 | +120 |
| ChatScaffold 新建 | +200 |
| 独立 widget 抽出（10 个文件） | +0（搬迁，无净增） |
| MessageGroupBubble + groupMessages 改造 | +50 |
| ConsultationBloc 新建 | +400 |
| TaskDetailBloc 议价部分删除 | -200 |
| ApplicationChatView 拆分 + 简化 | -800 |
| ConsultationActions 抽象删除 | -300 |
| 测试新增 | +500 |
| ARB l10n 新增 | +30 (×3 语言) |
| **净增** | **-100 ~ 0** |

## 已知风险与缓解

1. **后端 message_type 命名校准** — 实施 §议价业务气泡 前需先确认后端实际枚举值（`price_proposal` / `negotiation_status` 是假设）
2. **Message 模型缺 applicationId 字段** — 若 `Message.fromJson` 未解析 application_id，需先在 Message 模型加字段
3. **议价 chat 现有 WebSocket 串台 bug**（待验证）— 现状 `_onWsMessage` 只按 taskId 过滤，理论上同一 task 多 application 时消息可能误投。实施前先复现确认（多开两个议价会话观察），若确认存在则本次重构顺手修复；若实际后端 WS 推送已带 application 维度过滤则只是健壮性强化
4. **议价 state machine 迁移风险** — accepted / rejected / counter_offered 等多态状态在 ConsultationBloc 重建时要细心，需要细的回归测试

## 决策记录

- **方案选择**：方案 A（扩 ChatBloc + 抽 ConsultationBloc + 共用 widget），否决 B / C
- **议价业务归属**：抽 ConsultationBloc（最优派），否决"保留 TaskDetailBloc 兼管"（安全派）—— 用户明确选最优
- **媒体能力**：议价/咨询阶段开放图片+视频+文件全量（与任务聊天一致）
- **特殊气泡处理**：在 groupMessages 里特殊处理 + customBubbleBuilder（推荐选项）
- **范围**：5 种场景一次性全改（service / task / fleaMarket 咨询 + chat-before-payment 议价 + readOnly 议价历史）
- **入口分发**：ApplicationChatView 拆成 3 个内部 View（_ConsultationChatView / _BiddingChatView / _ReadOnlyChatView）
