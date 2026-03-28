# 达人服务咨询功能设计

## 概述

在服务详情页新增"咨询达人"入口，用户无需填写申请表单即可直接与达人就某个服务进行聊天咨询。咨询通过创建 `consulting` 状态的轻量申请实现，复用现有 `ApplicationChatView`。聊天中支持正式申请、议价、报价，议价同意后可直接创建任务。

## 用户流程

```
用户在服务详情页点"咨询达人"
    ↓
系统自动创建申请（状态: consulting，只需 service_id）
    ↓
进入 ApplicationChatView（绑定该申请）
    ↓
双方自由聊天
    ↓
用户可以：发起正式申请（填价格/时间）、发起议价
达人可以：主动报价
    ↓
议价/报价同意 → 直接创建任务
正式申请 → 状态升级为 pending → 走现有审核流程
```

## 新增申请状态：`consulting`

### 与现有状态的关系

| 状态 | 含义 | 触发方式 |
|------|------|----------|
| **`consulting`（新）** | 用户咨询中，尚未正式申请 | 用户点击"咨询达人" |
| `pending` | 正式申请待审核 | 用户提交申请表单 / 咨询中点"正式申请" |
| `chatting` | 正式申请进入聊天阶段 | 达人同意聊天 |
| `negotiating` | 议价中 | 任一方发起议价 |
| `price_agreed` | 议价达成 | 双方同意价格 |
| `approved` | 已批准，待付款 | 达人批准 / 议价同意后自动创建任务 |

### 状态流转

```
consulting → pending（用户正式申请）
consulting → negotiating（用户或达人发起议价/报价）
negotiating → price_agreed（双方同意价格）
price_agreed → approved（自动创建任务）
consulting → cancelled（任一方关闭咨询）
```

### 特性

- **不过期**：咨询申请不设自动过期，任一方可手动关闭
- **唯一性**：同一用户对同一服务只能有一个活跃的 `consulting` 申请，重复点击"咨询"跳转到已有聊天
- **轻量创建**：只需 `service_id`，不需要填写消息、价格、时间等

## 前端变化

### 1. 服务详情页（`service_detail_view.dart`）

**底部栏变化：**
- 在"申请服务"按钮旁新增"咨询达人"按钮
- 布局：左侧"咨询达人"（次要样式），右侧"申请服务"（主要样式）
- 如果已有 `consulting` 状态的申请，"咨询达人"按钮变为"继续咨询"，点击直接跳转到已有聊天
- 服务拥有者不显示此按钮

**新增 BLoC 事件：**
- `TaskExpertStartConsultation(serviceId)` → 调用 API 创建咨询申请 → 成功后导航到 ApplicationChatView

### 2. ApplicationChatView 增强（咨询模式）

**聊天顶部 — 服务信息卡片：**
- 显示服务名称、基础价格、定价类型（固定/按时/可议价）
- 轻量展示，不占过多空间

**底部工具栏 — 操作按钮（根据角色和状态显示）：**

| 角色 | 按钮 | 操作 |
|------|------|------|
| 用户（consulting 状态） | "正式申请" | 弹出申请表单（价格、时间偏好、时间槽） → 状态升级为 `pending` |
| 用户（consulting 状态） | "议价" | 弹出议价输入框 → 发送议价请求 → 状态变为 `negotiating` |
| 达人（consulting 状态） | "报价" | 弹出报价输入框 → 发送报价 → 状态变为 `negotiating` |
| 双方（negotiating 状态） | "同意" / "拒绝" / "还价" | 同意 → 创建任务；拒绝 → 回到 consulting；还价 → 继续议价 |

**议价/报价消息展示：**
- 议价和报价作为特殊消息类型在聊天中展示（卡片样式，显示金额和操作按钮）
- 同意后显示"已达成一致，任务已创建"的系统消息

### 3. 达人申请管理页（`expert_applications_management_view.dart`）

- 咨询申请用"咨询中"标签（区别于正式申请的"待审核"）
- 可使用不同颜色区分（如蓝色=咨询中，橙色=待审核）
- 点击咨询申请直接进入 ApplicationChatView

## 后端变化

### 新增 API

#### 1. 创建咨询申请
```
POST /api/expert-services/{service_id}/consult
```
- 无需 body（只需 service_id）
- 返回：创建的申请信息（application_id, task_id 等）
- 逻辑：检查是否已有活跃的 consulting 申请，有则返回已有的
- 自动创建关联的 task（状态为 consulting 或类似的初始状态）

#### 2. 聊天内发起议价（用户）
```
POST /api/applications/{application_id}/negotiate
Body: { "proposed_price": 2500 }  // 单位：pence
```
- 申请状态 → `negotiating`
- 在聊天中插入议价消息

#### 3. 聊天内发起报价（达人）
```
POST /api/applications/{application_id}/quote
Body: { "quoted_price": 3000, "message": "包含额外辅导材料" }
```
- 申请状态 → `negotiating`
- 在聊天中插入报价消息

#### 4. 回应议价/报价
```
POST /api/applications/{application_id}/negotiate-response
Body: { "action": "accept" | "reject" | "counter", "counter_price": 2800 }
```
- accept → 状态变为 `price_agreed`，自动创建任务
- reject → 状态回到 `consulting`
- counter → 保持 `negotiating`，在聊天中插入还价消息

#### 5. 咨询中转正式申请
```
POST /api/applications/{application_id}/formal-apply
Body: { "proposed_price": 2500, "message": "...", "time_slot_id": 1, "deadline": "..." }
```
- 申请状态 → `pending`
- 走现有的审核流程

#### 6. 关闭咨询
```
POST /api/applications/{application_id}/close
```
- 申请状态 → `cancelled`
- 任一方可操作

### 新增消息类型

| message_type | 用途 | 展示 |
|-------------|------|------|
| `negotiation` | 用户发起议价 | 卡片：议价金额 + 同意/拒绝/还价按钮 |
| `quote` | 达人发起报价 | 卡片：报价金额 + 备注 + 同意/拒绝/还价按钮 |
| `negotiation_accepted` | 议价/报价被接受 | 系统消息："双方已同意£XX，任务已创建" |
| `negotiation_rejected` | 议价/报价被拒绝 | 系统消息："对方拒绝了报价" |
| `counter_offer` | 还价 | 卡片：还价金额 + 同意/拒绝/还价按钮 |

## 数据模型变化

### 后端 — Application 表

- `status` 枚举新增 `consulting` 值
- 无需新增字段，consulting 申请复用现有表结构

### 前端 — TaskExpertService model

- `userApplicationStatus` 已支持字符串状态，新增 `consulting` 无需改 model
- 可能需要在 `ApplicationChatView` 增加对 consulting 状态的 UI 判断

### 前端 — Message model

- 新增 `negotiation`、`quote`、`negotiation_accepted`、`negotiation_rejected`、`counter_offer` 消息类型
- 议价/报价消息需要额外字段：`price`（金额）、`negotiation_status`（状态）

## 不在范围内

- 咨询申请的推送通知（可后续迭代）
- 咨询转化率统计/分析
- 咨询申请的搜索/筛选
- 多个服务合并咨询
