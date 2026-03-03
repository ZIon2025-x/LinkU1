# Design: Designated Task Taker Counter-Offer

**Date:** 2026-03-03
**Feature:** 被指定方可对指定任务发起议价，发布方可接受或拒绝

---

## Background

当前指定任务流程：
1. 发布方创建指定任务（含目标价格）→ 被指定方收到通知
2. 被指定方只能 **接受** 或 **拒绝**，无法提出反报价

现有「发布方发起议价」功能（`/negotiate`）使用 Redis one-time token（TTL 5 分钟），存在异步响应问题（5 分钟内对方未响应则 token 失效）。

---

## Goals

- 被指定方可在任务处于 `pending_acceptance` 状态时发起反报价
- 发布方收到通知后可接受或拒绝反报价
- 修复现有议价 token TTL 过短问题（5min → 24h）

---

## Architecture

### Backend

#### 1. 数据库变更 — `TaskApplication` 表新增字段

```sql
counter_offer_price   INTEGER   NULLABLE   -- 被指定方提出的反报价（分为单位）
counter_offer_status  VARCHAR   NULLABLE   -- 'pending' | 'accepted' | 'rejected'
```

#### 2. 新端点：被指定方提交反报价

```
POST /tasks/{task_id}/applications/{app_id}/counter-offer
```

- **权限**：`current_user.id == application.applicant_id`（被指定方本人）
- **前置检查**：
  - 任务状态为 `pending_acceptance`
  - `application.counter_offer_status` 不为 `pending`（防止重复提交）
- **操作**：
  - 更新 `counter_offer_price` 和 `counter_offer_status = 'pending'`
  - 给发布方发送通知：`type = 'counter_offer'`，`related_id = task_id`，`task_id = task_id`
- **Request body**：`{ "price": int }`
- **Response**：更新后的 application 对象

#### 3. 新端点：发布方响应反报价

```
POST /tasks/{task_id}/applications/{app_id}/respond-counter-offer
```

- **权限**：`current_user.id == task.poster_id`（发布方本人）
- **前置检查**：`counter_offer_status == 'pending'`
- **操作（接受）**：
  - 更新 `counter_offer_status = 'accepted'`
  - 更新任务价格为 `counter_offer_price`
  - 调用现有 `acceptTask` 逻辑（将任务推进到 `in_progress`）
  - 给被指定方发送通知：`type = 'counter_offer_accepted'`，`task_id = task_id`
- **操作（拒绝）**：
  - 更新 `counter_offer_status = 'rejected'`
  - 任务状态保持 `pending_acceptance`（被指定方仍可重新选择接受/拒绝/议价）
  - 给被指定方发送通知：`type = 'counter_offer_rejected'`，`task_id = task_id`
- **Request body**：`{ "action": "accept" | "reject" }`

#### 4. 修复现有议价 TTL

`task_chat_routes.py` `/negotiate` 端点：`ex=300` → `ex=86400`

---

### Frontend (Flutter)

#### 被指定方视角 — 任务详情（`pending_acceptance` 状态）

现有：`[接受]  [拒绝]`
新增：`[接受]  [议价]  [拒绝]`

- 点击「议价」→ 弹出 `AlertDialog`，含金额输入框（仅数字）
- 确认后调用新 Repo 方法 `submitCounterOffer(taskId, appId, price)`
- 提交成功后显示提示：「反报价已发送，等待对方回应」
- 若已有 `pending` 的反报价，按钮变为「等待回应中」（disabled）

若发布方拒绝反报价：
- 被指定方收到 `counter_offer_rejected` 通知 → 跳转任务详情
- 任务仍为 `pending_acceptance`，可继续接受/拒绝/再次议价

#### 发布方视角 — 任务详情（`pending_acceptance` 状态）

当 `application.counter_offer_status == 'pending'` 时，显示：

```
被指定方提出反报价：¥XX
[同意报价]  [拒绝]
```

- 点击「同意报价」→ 调用 `respondCounterOffer(taskId, appId, accept: true)`
  - 成功后任务进入 `in_progress`，正常流程继续
- 点击「拒绝」→ 调用 `respondCounterOffer(taskId, appId, accept: false)`
  - 成功后提示「已拒绝反报价」，任务仍为 `pending_acceptance`

#### 通知路由

`counter_offer` 和 `counter_offer_accepted/rejected` 通知已在 `notification_list_view.dart` 中路由到 `/service/$relatedId`。

**需要修正**：这些通知应路由到 `/tasks/$taskId`（task_id 字段），因为 related_id 是 task_id 而非 service_id。现有代码中已有 `counter_offer` → `/service/$relatedId` 的路由，需更新。

---

### Data Flow

```
被指定方
  → POST /counter-offer
  → DB: counter_offer_price, counter_offer_status=pending
  → Notification → 发布方 (type: counter_offer)

发布方
  → 任务详情显示反报价
  → POST /respond-counter-offer { action: accept }
    → DB: status=accepted, task.price=counter_offer_price, task→in_progress
    → Notification → 被指定方 (type: counter_offer_accepted)
  → POST /respond-counter-offer { action: reject }
    → DB: status=rejected
    → Notification → 被指定方 (type: counter_offer_rejected)
```

---

## Out of Scope

- 多轮议价（本期只支持单轮：提交一次反报价，发布方响应后结束）
- 被指定方在反报价 pending 期间修改报价（需先等发布方响应或拒绝后再提）
- 议价超时自动处理

---

## Affected Files

**Backend:**
- `app/models.py` — TaskApplication 新增字段
- `app/schemas.py` — 相关 schema 更新
- `app/task_chat_routes.py` — 新增两个端点 + 修改 TTL
- `app/utils/notification_utils.py` — 新增通知类型

**Flutter:**
- `lib/data/models/task.dart` 或 `application.dart` — 新增字段
- `lib/data/repositories/task_repository.dart` — 新增两个方法
- `lib/core/constants/api_endpoints.dart` — 新增端点常量
- `lib/features/tasks/bloc/task_detail_bloc.dart` — 新增事件/状态
- `lib/features/tasks/views/task_detail_view.dart` — UI 变更
- `lib/features/notification/views/notification_list_view.dart` — 修正 counter_offer 路由
- `lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb` — 新增文案
