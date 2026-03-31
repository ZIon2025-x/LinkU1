# 咨询聊天页面重构设计

**日期**: 2026-03-31
**范围**: `lib/features/tasks/views/application_chat_view.dart` (1768行) → 按咨询类型拆分

## 背景

`application_chat_view.dart` 同时处理三种咨询类型（service / task / fleaMarket），导致：
- 5+ 处 `switch(consultationType)` 分支散布各处
- actions、dialogs、dispatch 逻辑全部耦合在一个 State 类中
- 新增咨询类型需要修改多处 switch，维护成本高

## 目标

- **流程不变** — 三种类型的操作按钮、弹窗、dispatch 逻辑保持原样
- **按类型拆分** — 每个类型文件完全自包含（actions + dialogs + dispatch）
- **主页面瘦身** — 消除所有 `switch(consultationType)` 分支

## 文件结构

```
lib/features/tasks/views/
├── application_chat_view.dart              # 主页面 (~500行)
├── consultation/
│   ├── consultation_base.dart              # 枚举、抽象接口、共享 widget
│   ├── service_consultation_actions.dart   # 服务咨询
│   ├── task_consultation_actions.dart      # 任务咨询
│   └── flea_market_consultation_actions.dart # 跳蚤市场咨询
```

## 详细设计

### consultation_base.dart

```dart
/// 咨询类型枚举 (从 application_chat_view.dart 迁移)
enum ConsultationType { service, task, fleaMarket }

/// 咨询操作抽象接口
abstract class ConsultationActions {
  /// 工厂方法
  static ConsultationActions of({
    required ConsultationType type,
    required int applicationId,
    required int taskId,
  });

  /// API endpoint: 加载咨询状态
  String get statusEndpoint;

  /// 判断当前用户是否为申请方
  bool isApplicant(String? currentUserId, Map<String, dynamic>? consultationApp);

  /// 消息加载/发送时是否需要 application_id 参数
  bool get needsApplicationIdInMessages;

  /// 构建操作按钮栏
  Widget buildActions({
    required BuildContext context,
    required String? appStatus,
    required bool isSubmitting,
    required bool isApplicant,
  });

  /// 关闭咨询 — dispatch 对应 bloc event
  void dispatchClose(BuildContext context);
}
```

包含共享 widget:
- `ActionPill` — pill 形状按钮（从当前 `_ActionPill` 提升为可跨文件使用）
- `NegotiationActionButton` — 议价卡片中的小按钮（从当前 `_NegotiationActionButton` 迁移）

### service_consultation_actions.dart

自包含内容：
- `ServiceConsultationActions implements ConsultationActions`
- `statusEndpoint` → `ApiEndpoints.consultationStatus(applicationId)`
- `isApplicant` → 检查 `applicant_id`
- `needsApplicationIdInMessages` → `false`
- `buildActions` → 议价、正式申请、报价、审批(expert/owner)、关闭
- dialogs: `_showNegotiateDialog`, `_showQuoteDialog`, `_showFormalApplyDialog`, `_showApproveConfirmation`, `_showCloseConfirmation`, `_showCounterOfferDialog`
- dispatch: `TaskExpertNegotiatePrice`, `TaskExpertQuotePrice`, `TaskExpertFormalApply`, `TaskExpertApproveApplication` / `TaskExpertOwnerApproveApplication`, `TaskExpertCloseConsultation`, `TaskExpertNegotiateResponse`

### task_consultation_actions.dart

自包含内容：
- `TaskConsultationActions implements ConsultationActions`
- `statusEndpoint` → `ApiEndpoints.taskConsultStatus(taskId, applicationId)`
- `isApplicant` → 检查 `applicant_id`
- `needsApplicationIdInMessages` → `true`
- `buildActions` → 议价、正式申请、报价、审批(TaskDetailBloc)、关闭
- dialogs: 同上结构，但审批用 `TaskDetailAcceptApplicant`
- dispatch: `TaskExpertTaskNegotiate`, `TaskExpertTaskQuote`, `TaskExpertTaskFormalApply`, `TaskDetailAcceptApplicant`, `TaskExpertCloseTaskConsultation`, `TaskExpertTaskNegotiateResponse`

### flea_market_consultation_actions.dart

自包含内容：
- `FleaMarketConsultationActions implements ConsultationActions`
- `statusEndpoint` → `ApiEndpoints.fleaMarketConsultStatus(applicationId)`
- `isApplicant` → 检查 `buyer_id`（区别于其他两种）
- `needsApplicationIdInMessages` → `false`
- `buildActions` → 议价、购买确认、报价、卖家审批(API直调)、关闭
- dialogs: 正式申请弹窗为简单确认（无价格/消息输入），审批用直接 API 调用 `fleaMarketApprovePurchaseRequest`
- dispatch: `TaskExpertFleaMarketNegotiate`, `TaskExpertFleaMarketQuote`, `TaskExpertFleaMarketFormalBuy`, `TaskExpertCloseFleaMarketConsultation`, `TaskExpertFleaMarketNegotiateResponse`

### application_chat_view.dart (主页面改动)

**移除的内容：**
- `ConsultationType` 枚举定义 → 迁移到 `consultation_base.dart`
- `_buildConsultingActions2()` 方法
- 所有 `_dispatch*()` 方法（negotiate/quote/formalApply/close/negotiateResponse）
- 所有 `_show*Dialog()` 咨询弹窗方法
- `_isApplicantInConsultation()` 方法
- `_loadConsultationStatus()` 中的 switch
- `_approveFleaMarketPurchase()` 方法
- `_NegotiationActionButton` 和 `_ActionPill` widget 类

**替换方式：**
```dart
// State 中持有 consultation actions 引用
late final ConsultationActions? _consultationActions;

@override
void initState() {
  super.initState();
  if (widget.isConsultation) {
    _consultationActions = ConsultationActions.of(
      type: widget.consultationType,
      applicationId: widget.applicationId,
      taskId: widget.taskId,
    );
  }
  // ...
}

// 加载咨询状态 — 不再 switch
Future<void> _loadConsultationStatus() async {
  final endpoint = _consultationActions!.statusEndpoint;
  // ... 其余逻辑不变
}

// 消息加载 — 用属性替代 switch
queryParameters: {
  if (_consultationActions?.needsApplicationIdInMessages ?? true)
    'application_id': widget.applicationId,
},

// 判断是否申请方
final isApplicant = _consultationActions!.isApplicant(_currentUserId, _consultationApp);

// 构建 actions — 直接调用
_consultationActions!.buildActions(
  context: context,
  appStatus: appStatus,
  isSubmitting: isSubmitting,
  isApplicant: isApplicant,
),
```

**保留在主页面的内容：**
- Scaffold 骨架、AppBar
- 消息列表（`_buildMessageList`）、输入框（`_buildInputBar`）
- 消息加载/发送（`_loadMessages`, `_sendMessage`）
- 服务信息卡片（`_buildServiceInfoCard`）
- 价格栏（`_buildPriceBar`）、关闭横幅（`_buildClosedBanner`）
- 确认支付按钮（`_buildConfirmAndPayButton`）
- BlocListener/BlocConsumer 结构
- `_getCurrencySymbol`、`_findApplication`、`_isPoster` 等辅助方法

## 不在此次范围

- 消息加载/发送迁移到 BLoC（当前用 setState 手动管理，保持不变）
- BlocListener 中的 action 消息处理逻辑（保持不变）
- 非咨询模式的逻辑（`isConsultation == false` 的代码路径不受影响）

## 回调机制

类型文件中的 dialogs 和 dispatch 需要访问 `BuildContext` 来读取 BLoC。设计为：
- `buildActions` 接收 `BuildContext`，内部通过 `context.read<T>()` 访问 BLoC
- dialogs 作为类型文件内的静态/顶层方法，接收 context
- 成功后的刷新操作（`_loadMessages`, `_loadConsultationStatus`）通过回调参数传入

```dart
abstract class ConsultationActions {
  Widget buildActions({
    required BuildContext context,
    required String? appStatus,
    required bool isSubmitting,
    required bool isApplicant,
    required VoidCallback onActionCompleted, // 刷新消息+状态
  });
}
```
