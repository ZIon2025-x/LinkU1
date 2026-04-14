# 团队级咨询设计

**日期**: 2026-04-14
**状态**: 待实现

## 背景

现有咨询体系只支持"服务级咨询"——用户必须先选一个具体服务才能发起咨询。但实际场景中，用户经常不确定要哪个服务，想先跟团队聊需求，再由双方协商确定服务和价格。

目前团队详情页的"咨询达人"按钮只是跳到跟 owner 的普通私聊，没有咨询记录、议价工作流。

## 目标

- 用户可从团队详情页发起"团队咨询"，不绑定具体服务
- 咨询内双方可议价，报价时必须同时选择一个团队服务（报价=选服务+出价）
- 价格敲定后转为该服务的正式申请，走现有 approve → 支付流程
- 团队咨询与服务咨询在申请管理列表中统一展示
- 修复 Dashboard 申请管理的交互问题（卡片不可点、按钮缺失）

## 流程

```
用户在团队详情页点"咨询达人"
  → POST /api/experts/{expert_id}/consult
  → 创建 ServiceApplication(status="consulting", service_id=NULL, new_expert_id=团队ID)
  → 创建占位 Task(status="consulting", task_type="expert_service")
  → 返回 {task_id, application_id}
  → 跳转咨询聊天页

聊天中议价：
  → 任一方点"报价" → 弹窗：选团队服务 + 填价格 → 提交
  → POST /api/applications/{id}/negotiate (带 service_id + price)
  → 对方可接受 / 还价（还价也要带 service_id + price）
  → 价格敲定 → application.status="price_agreed", service_id 写入

正式申请：
  → 用户点"正式申请" → 走现有 formal_apply 流程
  → 团队 approve → 创建正式 Task + PaymentIntent → 用户支付
```

## 后端改动

### 1. 新端点 `POST /api/experts/{expert_id}/consult`

文件: `expert_consultation_routes.py`

- 参数: `expert_id` (路径), `body: Optional[dict]` (可选 message)
- 校验: 团队存在 + active, 用户已登录, 不能咨询自己的团队
- 幂等: 已有进行中咨询(consulting/negotiating/price_agreed)直接返回
- 创建:
  - `Task(title="团队咨询: {team_name}", status="consulting", task_type="expert_service", poster_id=user_id)`
  - `ServiceApplication(service_id=NULL, new_expert_id=expert_id, applicant_id=user_id, status="consulting", task_id=task.id)`
- 通知团队 owner+admin
- 返回: `{task_id, application_id, status}`

### 2. 修改议价端点 `POST /api/applications/{id}/negotiate`

文件: `expert_consultation_routes.py`

- 请求体新增可选字段 `service_id: Optional[int]`
- 当 application.service_id 为 NULL（团队咨询）时:
  - `service_id` 必填，校验该服务属于 application.new_expert_id 的团队
  - 写入 application.service_id
- 当 application.service_id 已有值（服务咨询）时:
  - `service_id` 忽略（不能换服务）
- 其余逻辑不变

### 3. 修改报价端点 `POST /api/applications/{id}/quote`

同上逻辑：团队咨询时报价必须带 service_id。

### 4. 申请列表端点

现有列表已返回 `service_id` 和 `service_name`。`service_id=NULL` 的条目 Flutter 端自行标记为"团队咨询"。无需改后端。

## Flutter 改动

### 1. 团队详情页底部按钮

文件: `expert_team_detail_view.dart` (~L1970)

- 现状: `context.push('/chat/${owners.first.userId}')`
- 改为:
  - 调 `ExpertTeamRepository.createTeamConsultation(expertId)`
  - 成功后跳 `/tasks/$taskId/applications/$appId/chat?consultation=true`
- Repository 新增 `createTeamConsultation(String expertId)` 方法
- API endpoint 常量: `ApiEndpoints.consultExpert(expertId)`

### 2. 咨询聊天议价弹窗

文件: `service_consultation_actions.dart` (或 `consultation_base.dart`)

- 现有"还价"弹窗只有价格输入
- 团队咨询时(application.service_id == null)增加服务选择器:
  - 从团队服务列表中选择（调 `GET /api/experts/{expert_id}/services`）
  - 选完服务后再填价格
  - 服务咨询时隐藏服务选择器（已绑定服务）

### 3. Dashboard 申请管理

文件: `applications_tab.dart`

**卡片可点击:**
- consulting/negotiating/price_agreed 状态: onTap 跳到咨询聊天页
- approved 状态: onTap 跳到任务详情

**按钮组完善:**

| 状态 | 操作按钮 |
|------|----------|
| consulting | 沟通（进聊天）、报价（弹窗选服务+出价） |
| negotiating | 沟通、报价（还价） |
| price_agreed | 沟通、同意（approve） |
| pending | 同意、拒绝 |

**团队咨询标识:**
- `service_id == null` → 显示"团队咨询"标签
- 有 `service_id` → 显示服务名

**历史数据兼容:**
- `task_id == null` 的旧咨询记录 → "沟通"按钮降级为跳到跟用户的私聊

## 数据模型

不需要新表。复用现有:
- `tasks` 表: 占位 task, status="consulting"
- `service_applications` 表: service_id 允许 NULL（已支持）

## 不做的事

- 不新建独立的"团队咨询"表/模型
- 不新增聊天类型，复用现有 ApplicationChatView
- 不做团队咨询的独立 tab，统一在申请管理列表
