# 任务和商品咨询功能设计

## 概述

将咨询功能从服务扩展到任务和跳蚤市场商品。用户可以在申请任务或购买商品之前，先和发布者/卖家进行咨询聊天。复用现有表结构（TaskApplication / FleaMarketPurchaseRequest），加 `consulting` 状态。前端复用 `ApplicationChatView` 的咨询模式。

## 入口

### 任务详情页底部栏

- **去掉**原有的问答图标按钮（QA button）
- **新增**咨询图标按钮（chat_bubble_outline），放在底部栏左侧
- 右侧保持"申请任务"主按钮不变
- 已有咨询时图标按钮显示未读标记或高亮
- 任务发布者不显示咨询按钮

### 商品详情页底部栏

- **去掉**原有的聊天/问答图标按钮（如果有）
- **新增**咨询图标按钮，放在底部栏左侧
- 右侧保持"购买"/"预订"主按钮不变
- 卖家不显示咨询按钮

## 后端

### 任务咨询

**创建咨询：** `POST /api/tasks/{task_id}/consult`
- 创建 `TaskApplication`，status=`consulting`
- 不需要创建 placeholder task（任务本身就是 task，消息直接走 task chat 端点）
- 设置 `applicant_id=current_user.id`，`task_id=task_id`
- 发送系统消息："{user.name} 想咨询您的任务「{task.title}」"
- 幂等：已有 consulting/negotiating/price_agreed 状态的申请则返回已有的
- 返回：`{application_id, task_id, status, is_existing}`

**议价/报价/还价：** 复用已有的咨询端点
- `POST /api/tasks/{task_id}/applications/{application_id}/negotiate` — 新增，用于任务咨询议价
- `POST /api/tasks/{task_id}/applications/{application_id}/quote` — 新增，发布者报价
- `POST /api/tasks/{task_id}/applications/{application_id}/negotiate-response` — 接受/拒绝/还价
- 这些端点操作 `TaskApplication` 表（不是 ServiceApplication），需要新写

**正式申请：** `POST /api/tasks/{task_id}/applications/{application_id}/formal-apply`
- TaskApplication 状态从 consulting/price_agreed → pending
- 可附带 message、proposed_price

**关闭咨询：** `POST /api/tasks/{task_id}/applications/{application_id}/close-consultation`
- 设置 TaskApplication status=cancelled
- 发送系统消息

**消息：** 复用现有 task chat 端点
- `GET /api/messages/task/{task_id}?application_id={app_id}` — 已支持 TaskApplication
- `POST /api/messages/task/{task_id}/send` + `application_id` — 已支持
- 需要更新 `send_task_message` 允许 consulting 状态的 TaskApplication 发消息

### 商品咨询

**创建咨询：** `POST /api/flea-market/{item_id}/consult`
- 创建 `FleaMarketPurchaseRequest`，status=`consulting`
- 创建 placeholder `Task`（status=consulting, task_source=flea_market_consultation）用于消息路由
- 设置 `buyer_id=current_user.id`
- 发送系统消息："{user.name} 想咨询您的商品「{item.title}」"
- 幂等：已有 consulting/negotiating/price_agreed 状态的请求则返回已有的
- 返回：`{purchase_request_id, task_id, item_id, status, is_existing}`

**议价/报价/还价：** 新端点
- `POST /api/flea-market/purchase-requests/{request_id}/negotiate` — 买家议价
- `POST /api/flea-market/purchase-requests/{request_id}/quote` — 卖家报价
- `POST /api/flea-market/purchase-requests/{request_id}/negotiate-response` — 接受/拒绝/还价

**正式购买：** `POST /api/flea-market/purchase-requests/{request_id}/formal-buy`
- 从 consulting/price_agreed 转为正式购买
- 触发现有购买流程（创建支付）

**关闭咨询：** `POST /api/flea-market/purchase-requests/{request_id}/close-consultation`
- 设置 status=cancelled，task=cancelled

**消息：** 通过 placeholder task
- 不传 application_id（和服务咨询一样，每个咨询 task 只对应一个请求）

### 消息类型

复用已有的议价消息类型，无需新增：
- `negotiation` / `quote` / `counter_offer` / `negotiation_accepted` / `negotiation_rejected`

### 通知

所有咨询操作（创建、议价、报价、接受、拒绝、还价）都发送通知给对方。

## 前端

### ApplicationChatView 扩展

新增 `consultationType` 参数：

```dart
enum ConsultationType { service, task, fleaMarket }

class ApplicationChatView extends StatelessWidget {
  final int taskId;
  final int applicationId;
  final bool isConsultation;
  final ConsultationType consultationType;  // 新增
}
```

根据 `consultationType` 决定：
- 加载哪个状态端点（ServiceApplication / TaskApplication / PurchaseRequest）
- 议价/报价调哪组端点
- 正式申请/购买调哪个端点
- 审批调哪个端点

### 聊天内操作按钮

| 状态 | 用户（咨询方） | 发布者/卖家 |
|------|---------------|-------------|
| consulting | 议价、正式申请/购买 | 报价 |
| negotiating | 议价、正式申请/购买 | 报价 |
| price_agreed | 正式申请/购买 | 确认（触发支付） |
| consulting/negotiating | 关闭咨询 | 关闭咨询 |

### 路由

扩展 `consultation` query 参数：
- `?consultation=true&type=service` — 服务咨询（现有）
- `?consultation=true&type=task` — 任务咨询
- `?consultation=true&type=flea_market` — 商品咨询

### 消息列表导航

`TaskChat.taskSource` 新增 `flea_market_consultation` 值，消息列表根据 taskSource 判断跳转到哪种咨询聊天。

### BLoC

给 `TaskDetailBloc` 和 `FleaMarketBloc` 各加咨询相关事件，或统一在 `TaskExpertBloc` 中处理（推荐后者，减少重复）。

在 `TaskExpertBloc` 中新增：
- `TaskExpertStartTaskConsultation(taskId)` — 创建任务咨询
- `TaskExpertStartFleaMarketConsultation(itemId)` — 创建商品咨询

议价/报价/还价/关闭的事件和处理器需要按 consultationType 路由到不同端点。

### Repository

`TaskExpertRepository` 新增方法：
- `createTaskConsultation(taskId)`
- `createFleaMarketConsultation(itemId)`
- `negotiateTaskApplication(appId, price)`
- `quoteTaskApplication(appId, price, message)`
- `respondTaskNegotiation(appId, action, counterPrice)`
- `formalApplyTask(appId, price, message)`
- `closeTaskConsultation(appId)`
- 跳蚤市场同理一套

### L10n

复用已有的咨询/议价字符串，无需新增（"咨询"、"继续咨询"、"议价"、"报价"等已有）。

## 数据模型变化

### TaskApplication 表
- `status` 新增 `consulting` 值（VARCHAR，无 CHECK 约束，直接可用）
- 无需新增字段

### FleaMarketPurchaseRequest 表
- `status` 新增 `consulting`、`negotiating`、`price_agreed` 值
- 新增 `task_id` 字段（FK to tasks，nullable）— 用于消息路由的 placeholder task
- 新增 `final_price` 字段（DECIMAL，nullable）— 议价达成的最终价格

### Message 表
- 已支持所有需要的 message_type，无需改动

## 不在范围内

- 去掉"批准聊天"流程（后续迭代）
- WebSocket 实时消息推送到咨询聊天（后续迭代）
- 咨询记录的搜索/筛选
