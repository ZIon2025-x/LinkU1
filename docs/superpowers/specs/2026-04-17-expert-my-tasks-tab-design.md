# Expert Dashboard — My Tasks Tab + Admin Auto-Join Chat

**Date**: 2026-04-17  
**Status**: Draft

## Problem

达人团队成员（尤其是 member 和 admin）被邀请进入任务聊天后，没有入口找到这些任务和聊天。当前 Expert Dashboard 没有任务列表 tab，成员不知道从哪里进入协作。

此外，admin 审批申请后创建的任务，admin 本人不会自动加入任务聊天，需要 owner 手动邀请。

### 发现的既有 Bug

`chat_participant_routes.py` 的 invite 端点用 `task.expert_creator_id` 做团队关联校验（第 85-87 行），但通过服务申请审批创建的任务（`_approve_team_service_application`）只设了 `taker_expert_id`，没设 `expert_creator_id`。导致：
- 这类任务调 invite 端点直接报 "该任务未关联达人团队，无法邀请成员"
- 团队服务任务的多人聊天功能完全不可用

**修复方案**：`chat_participant_routes.py` 的团队 ID 解析逻辑应 fallback 到 `task.taker_expert_id`。

## Solution

### Feature 0: 修复 invite 端点的团队关联

**文件**: `chat_participant_routes.py`

**改动**: 第 85-87 行，团队 ID 查找逻辑改为：
```python
expert_id_for_check = getattr(task, 'taker_expert_id', None) or getattr(task, 'expert_creator_id', None)
```
优先用 `taker_expert_id`（团队 ID），fallback 到 `expert_creator_id`（旧路径）。

同时第 130 行的 "确保达人 Owner 在聊天中" 也做同样修改。

### Feature 1: Admin 审批时自动加入任务聊天

**触发点**: `expert_consultation_routes.py` → `_approve_team_service_application()` — 在 commit 之后（best-effort）。

**逻辑**:
- 审批操作的 `current_user.id` 如果不等于 `taker_id`（即 admin 不是 owner），则自动创建 ChatParticipant 记录
- 同时为 poster（客户）和 taker（owner）也创建 ChatParticipant，保持与现有"首次升级"逻辑一致
- Admin role 为 `expert_admin`
- 用 best-effort try/except 包裹，不阻塞审批主流程

**数据写入**:
```
ChatParticipant(task_id=new_task.id, user_id=poster_id, role="client")
ChatParticipant(task_id=new_task.id, user_id=taker_id, role="expert_owner")
ChatParticipant(task_id=new_task.id, user_id=current_user.id, role="expert_admin")  -- if different from above
```

### Feature 2: My Tasks Tab

#### Backend: `GET /api/experts/{expert_id}/my-tasks`

**文件**: `expert_service_routes.py`（复用现有 router prefix `/api/experts/{expert_id}/...`）

**权限**: 团队活跃成员（owner/admin/member）

**查询逻辑**:
- **Owner**: `SELECT * FROM tasks WHERE taker_expert_id = :expert_id AND status NOT IN ('deleted', 'cancelled')`
- **Admin/Member**: `SELECT t.* FROM tasks t JOIN chat_participants cp ON t.id = cp.task_id WHERE cp.user_id = :current_user_id AND t.taker_expert_id = :expert_id AND t.status NOT IN ('deleted', 'cancelled')`

**返回字段**（每个任务）:
- `id`, `title`, `status`, `task_source`
- `poster_id`, `poster_name`, `poster_avatar` — 客户信息（JOIN users）
- `created_at`, `accepted_at`
- `reward`, `currency`
- `joined_at` — admin/member 从 ChatParticipant.joined_at 取；owner 从 task.accepted_at 取

**排序**: `joined_at DESC`（最新参与的排前面）

**分页**: `page` + `page_size`（默认 20）

#### Flutter: New Tab

**位置**: Expert Dashboard，放在 Services 和 Applications 之间，所有角色可见。

**Tab 标题**: "我的任务" / "My Tasks"

**列表项**:
- 客户头像 + 名字
- 任务标题
- 状态 badge（pending_payment / in_progress / completed 等）
- 时间（joined_at 或 created_at）

**交互**: 点击 → 直接跳转任务聊天页面

**空状态**: 图标 + "暂无任务" 提示文字

**数据流**:
1. 新 event: `ExpertDashboardLoadMyTasks`
2. Repository: `getMyTasks(expertId)` → `GET /api/experts/{expert_id}/my-tasks`
3. State: `myTasks: List<Map<String, dynamic>>`
4. UI: `MyTasksTab` widget

## Tab Visibility Summary

| Tab | Owner | Admin | Member |
|-----|-------|-------|--------|
| Stats | ✅ | ✅ | ✅ |
| Services | ✅ | ✅ | ✅（只读） |
| **My Tasks** | ✅（全部） | ✅（被邀请的） | ✅（被邀请的） |
| Applications | ✅ | ✅ | ❌ |
| TimeSlots | ✅ | ✅ | ✅ |
| Schedule | ✅ | ✅ | ✅ |
| Activities | ✅ | ✅ | ❌ |

## Out of Scope

- 任务详情页（点击直接进聊天，不做详情页）
- 任务筛选/搜索（第一版不做）
- 未读消息数 badge（后续迭代）
