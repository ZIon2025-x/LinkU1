# 咨询聊天对齐 — 实施前后端契约校准

日期: 2026-05-20

## Step 1: WS / GET 推送是否带 application_id

**调查方法**: 查阅 `backend/app/task_chat_routes.py` 的 GET handler (`get_task_messages`, line 821) 和 POST/WS broadcast handler (`send_task_message`, line 1247)。

**结论**:
- GET response (`/api/messages/task/{task_id}`) Message body 顶层是否带 `application_id`: **否** — `message_data` 字典只含 `id / sender_id / sender_name / sender_avatar / content / message_type / task_id / created_at / is_read / attachments / meta`，无 `application_id` 字段 (task_chat_routes.py:1125-1138)。
- WS push (event=`task_message`) Message body 是否带 `application_id`: **是** — `message_response["message"]` 中明确包含 `"application_id": new_message.application_id` (task_chat_routes.py:1641)。

**附加发现 — 议价类消息的 WS 推送**:
- `POST /tasks/{task_id}/applications/{application_id}/consult-negotiate` — 只写 DB，**不推送 WS** (task_chat_routes.py:5566-5594)。
- `POST /tasks/{task_id}/applications/{application_id}/consult-quote` — 只写 DB，**不推送 WS** (task_chat_routes.py:5669-5697)。
- `POST /tasks/{task_id}/applications/{application_id}/consult-respond` — 只写 DB，**不推送 WS** (task_chat_routes.py:5910-5948)。
- `POST /tasks/{task_id}/applications/{application_id}/propose-price` — 推送 WS，payload 带 `application_id` (task_chat_routes.py:2900-2915)。
- `POST /tasks/{task_id}/applications/{application_id}/start-chat` — 推送 WS 系统消息，payload 带 `application_id` (task_chat_routes.py:2690-2703)。

议价三步（negotiate / quote / respond）收到新消息靠推送通知（Notification），不靠 WS push；接收端收到通知后会主动调 GET 刷新消息列表。

**证据**:
- `backend/app/task_chat_routes.py:1125-1138` — GET message_data 字典构造，无 application_id 字段
- `backend/app/task_chat_routes.py:1629-1641` — WS broadcast 注释："application_id: 前端用 (task_id, application_id) 复合键精准定位 chat row"，并写入 `"application_id": new_message.application_id`
- `backend/app/task_chat_routes.py:826` — GET endpoint 接受 `application_id` query param 用于筛选消息
- `backend/app/task_chat_routes.py:911-922` — 按 application_id 筛选 DB 消息的逻辑（含 ServiceApplication fallback）
- `backend/app/models.py:465` — `Message.application_id` 是 nullable FK 字段
- `backend/app/models.py:493` — `Index("ix_messages_task_application", task_id, application_id)`

**对前端的影响**:
- WS push 带 application_id → Task 3 的 WS 过滤 `(task_id, application_id)` 复合键逻辑**完全可行**，backend 已设计为此。
- GET response 不带 application_id → Task 1 的 `Message.applicationId` getter 不能从顶层 JSON 取；若需要在 Message 对象上拿到 applicationId，有两条路：
  1. 让后端在 GET response 里也加 application_id（小改动，建议配套提 PR）。
  2. 前端在 MessageRepository 加载消息时把 query param `application_id` 注入到每条 Message 对象（客户端 fallback，无需等后端）。
  - **推荐方案**：后端 GET 路径加 application_id 字段（单行改动），Task 1 直接用顶层路径。

## Step 2: message_type 议价类枚举实际值

**前端假设的 5 个值**:
- `negotiation`
- `quote`
- `counter_offer`
- `negotiation_accepted`
- `negotiation_rejected`

**后端实际使用的值**: 与前端假设**完全吻合**。

| 前端假设 | 后端实际写入位置 |
|---|---|
| `negotiation` | `task_chat_routes.py:5566`, `expert_consultation_routes.py:643`, `flea_market_routes.py:4326` |
| `quote` | `task_chat_routes.py:5669`, `expert_consultation_routes.py:722`, `flea_market_routes.py:4420` |
| `counter_offer` | `task_chat_routes.py:5889`, `expert_consultation_routes.py:857,1635`, `flea_market_routes.py:4537` |
| `negotiation_accepted` | `task_chat_routes.py:5765`, `expert_consultation_routes.py:849`, `flea_market_routes.py:4509` |
| `negotiation_rejected` | `task_chat_routes.py:5877`, `expert_consultation_routes.py:853`, `flea_market_routes.py:4528` |

DB CheckConstraint 白名单（`backend/app/models.py:478`）:
```
message_type IN ('normal', 'system', 'price_proposal', 'negotiation', 'quote', 'counter_offer', 'negotiation_accepted', 'negotiation_rejected')
```

**额外发现**: DB 还有 `price_proposal` 类型（由 `propose-price` endpoint 写入，task_chat_routes.py:2838），前端 Message 模型目前**没有** `isPriceProposal` getter。这是 Task 4 (MessageGroupBubble) 需要处理的，但不阻塞 Task 1-3。

**差异**: 无。前端 5 个假设值与后端实际值 100% 对齐。

## Step 3: WS 串台 bug 复现 (TODO - 待用户手测)

**怎么测**: 同时在两台设备 / 两个浏览器 tab 登录，各自打开同一个 task 下不同 application 的议价聊天会话。在 A 设备发一条消息，观察 B 设备是否被错误推送（B 应该看不到，因为属于不同 application）。

**后端现状分析** (coding agent 从代码推断):
- `send_task_message` 广播时，application-scoped chat 只推给 `{poster, taker, applicant}` 三方 (task_chat_routes.py:1562-1569)。
- 但**接收端没有过滤** application_id — 若用户 A (poster) 同时在两个 application 频道，A 会收到两个频道的所有推送，由前端区分属于哪个 application。
- 当前前端 `ChatBloc` / `TaskChatView` 接收 WS 消息时是否有 application_id 过滤，尚未实现（Task 3 的目标）。

**结论 (待用户填)**: [出现串台 / 未出现 / 待测]

**对前端的影响**:
- 出现 → Task 3 的 WS 过滤新增 application 维度是 **bug fix**
- 未出现 → 后端已带 application 过滤，Task 3 的过滤是健壮性强化
- 无论哪种结论，Task 3 的代码本身一致，不阻塞后续 task

## 实施前注意事项

**一个潜在阻塞项** (非强阻塞，有绕过方案):

GET `/api/messages/task/{task_id}` 返回的 Message 对象不含顶层 `application_id` 字段。Task 1 的 `Message.applicationId` getter 若依赖顶层路径，历史消息（通过 GET 加载）会读不到 application_id。

建议解法（按优先级）:
1. **(推荐) 后端单行改动**: 在 `task_chat_routes.py:1137` (`message_data` dict 构造) 加 `"application_id": msg.application_id`。这是一行 change，无 migration，无副作用。
2. **(纯前端绕过)** MessageRepository 在 `getTaskMessages(taskId, applicationId)` 拿到消息列表后，对每条消息注入 `applicationId` 字段（用传入的 query param 值）。

WS push 已有 application_id（后端已实现），Task 3 的实时过滤不受影响。

**其他注意事项**:
- `price_proposal` message_type 存在于 DB 白名单和后端代码，但前端模型缺少对应 getter — Task 4 实现 `MessageGroupBubble` 时需要处理（不阻塞 Task 1-3）。
- 议价三步（negotiate/quote/respond）不推 WS，靠通知驱动刷新 — ConsultationBloc（Task 9-10）的实时刷新逻辑需要考虑这一点（监听通知或轮询，而非只依赖 WS）。

**总结**: GET response 缺 application_id 是轻微不对齐，建议后端配合加一行；其余所有契约均对齐，**可推进 Task 1+**（后端 PR 不需要先合并，前端可用绕过方案）。
