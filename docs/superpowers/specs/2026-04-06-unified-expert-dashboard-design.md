# 统一达人管理页面 Design Spec

**日期**: 2026-04-06
**状态**: Approved (awaiting implementation plan)

## 目标

把 `features/task_expert/` 和 `features/expert_team/` 两个分散的达人功能模块整合成一个**统一的达人管理页面**，实现：

1. **一个入口** — 用户通过单一 URL（`/expert-dashboard`）访问所有达人相关的日常工作流和管理功能
2. **多团队切换** — 用户可能属于多个达人团队，在页面内通过 AppBar 切换器切换
3. **角色感知 UI** — 根据 `Expert.myRole`（owner/admin/member）显示对应的 tab 和管理项，无权限项直接隐藏

## 范围

### 包含
- Dashboard 重构为 5 核心 tab + 管理中心（方案 A）
- 团队切换器（AppBar 标题点击打开 bottom sheet）
- 管理中心独立路由（整合成员/申请审核/优惠券/套餐/Stripe/评价回复/团队资料/公开主页/离开）
- 角色权限规则
- 代码迁移：`features/task_expert/` 的管理相关 views + `features/expert_team/` 的管理相关 views → 新目录 `features/expert_dashboard/`
- 删除重复的 `expert_services_manage_view.dart`

### 不包含
- ❌ 内部群聊 tab（等群聊 Phase 1，已 defer）
- ❌ Dashboard 内的系统通知 / 消息中心
- ❌ 数据导出 / 图表
- ❌ 任何后端 schema 或端点的新增（上一轮已经完成字段对齐）

### 保留独立，不迁入
这些页面不属于"单团队管理"范畴，保持现有位置和路由：

| 页面 | 理由 | 当前位置 |
|---|---|---|
| `my_teams_view` | 被团队切换器的"查看所有团队"替代，保留用于团队列表浏览 | `features/expert_team/` |
| `create_team_view` | 申请创建团队属于 onboarding，不是"管理现有团队" | `features/expert_team/` |
| `my_invitations_view` | 邀请跨团队（是个人收件箱），通过切换器"我的邀请"入口访问 | `features/expert_team/` |
| `expert_team_detail_view` | 公开主页，供其他用户浏览 | `features/expert_team/` |
| `group_buy_view` | 拼单活动页面，面向买家 | `features/expert_team/` |
| `task_expert_list_view`, `task_expert_search_view`, `task_expert_detail_view`, `service_detail_view`, `task_experts_intro_view` | 公开浏览达人/服务，面向买家 | `features/task_expert/` 保留 |

## 架构

### 目录结构

```
link2ur/lib/features/expert_dashboard/      ← 新目录
├── bloc/
│   ├── selected_expert_cubit.dart          ← 持有当前 expertId，team switcher 更新它
│   ├── expert_dashboard_bloc.dart          ← 从 task_expert/ 迁移，统计/服务/时段/日程
│   ├── applications_bloc.dart              ← 从 task_expert_bloc.dart 拆出申请相关 handler
│   ├── members_bloc.dart                   ← 从 expert_team_bloc.dart 拆出成员相关 handler
│   └── ... (其他管理中心子页的 bloc)
├── views/
│   ├── expert_dashboard_shell.dart         ← 新：两阶段 widget + AppBar 团队切换器 + 5 tab
│   ├── tabs/
│   │   ├── stats_tab.dart                  ← 从 expert_dashboard_stats_tab.dart 迁移
│   │   ├── services_tab.dart
│   │   ├── applications_tab.dart
│   │   ├── time_slots_tab.dart
│   │   └── schedule_tab.dart
│   ├── team_switcher_sheet.dart            ← 新：AppBar 标题点击打开的 bottom sheet
│   └── management/
│       ├── management_center_view.dart     ← 新：⚙ 按钮打开的主页面
│       ├── members_view.dart               ← 从 expert_team/views/expert_team_members_view.dart 迁移
│       ├── join_requests_view.dart         ← 迁移
│       ├── edit_team_profile_view.dart     ← 迁移（替换 task_expert/ 的 expert_profile_edit_view）
│       ├── coupons_view.dart               ← 从 expert_coupons_view.dart 迁移
│       ├── packages_view.dart              ← 从 expert_packages_view.dart 迁移
│       ├── review_replies_view.dart        ← 新建（后端已有 endpoint POST /api/reviews/{id}/reply）
│       │                                      列表使用 GET /api/experts/{id}/reviews
│       └── （Stripe Connect 不新建 view，
│           Management Center 直接链接到现有 features/payment/views/stripe_connect_onboarding_view.dart）
│       └── leave_team_dialog.dart          ← 新：离开团队确认
```

### 路由

所有管理中心子页使用嵌套路由 + `expertId` 路径参数：

```
/expert-dashboard
/expert-dashboard/:expertId                           ← shell 入口（5 tab）
/expert-dashboard/:expertId/management                ← 管理中心主页
/expert-dashboard/:expertId/management/members
/expert-dashboard/:expertId/management/join-requests
/expert-dashboard/:expertId/management/edit-profile
/expert-dashboard/:expertId/management/coupons
/expert-dashboard/:expertId/management/packages
/expert-dashboard/:expertId/management/review-replies
/expert-dashboard/:expertId/management/stripe-connect
```

`/expert-dashboard`（无 expertId）是入口页，自动解析：
1. fetch `GET /api/experts/my-teams`
2. 0 teams → 重定向到 `/task-experts/intro`
3. 1+ teams → 读取 `StorageService.getSelectedExpertId()` 或默认 `teams.first.id`，重定向到 `/expert-dashboard/:expertId`

### 数据流

**`SelectedExpertCubit`**：
- 构造时接收 `my-teams` 结果
- State: `{ currentExpertId: String, myTeams: List<ExpertTeam> }`
- 方法: `switchTo(String expertId)` → 更新 state + 持久化到 StorageService
- 提供在 Dashboard shell 层级，所有 tab 和管理子页通过 `context.read<SelectedExpertCubit>()` 读取当前 expertId 和角色

**各 tab BLoC**：
- 在 shell 内创建，接收 `expertId` 作为构造参数
- 切换团队时整个 shell 重建（简单可靠），或各 tab 监听 cubit 并重新加载

采用**整体重建方案**：`ExpertDashboardShell` 包一层 `BlocBuilder<SelectedExpertCubit>`，`buildWhen: (prev, curr) => prev.currentExpertId != curr.currentExpertId`，切换时重建整个子树。简单、无状态残留。

### 角色权限

**数据源**：`Expert.myRole`（后端 `GET /api/experts/{id}` 和 `/my-teams` 均返回）

**Tab 可见性**：

| Tab | Owner | Admin | Member |
|---|---|---|---|
| 看板 Stats | ✓ | ✓ | ✓ |
| 服务 Services | ✓ CRUD | ✓ CRUD | ✓ 只读 |
| 申请 Applications | ✓ | ✓ | ❌ 隐藏 |
| 时段 Time Slots | ✓ CRUD | ✓ CRUD | ✓ 只读 |
| 日程 Schedule | ✓ | ✓ | ✓ |

Member 角色只看到 4 个 tab（无申请 tab），TabBar 动态生成。

**管理中心可见项**：

| 分组 | 项 | Owner | Admin | Member |
|---|---|---|---|---|
| 团队 | 成员管理 | ✓ | ✓ | ✓ 只读 |
| 团队 | 入队申请 | ✓ | ✓ | ❌ |
| 团队 | 编辑团队资料 | ✓ | ❌ | ❌ |
| 营销 | 优惠券 | ✓ | ✓ | ❌ |
| 营销 | 服务套餐 | ✓ | ✓ | ❌ |
| 营销 | 评价回复 | ✓ | ✓ | ❌ |
| 财务 | Stripe Connect | ✓ | ❌ | ❌ |
| 其他 | 查看公开主页 | ✓ | ✓ | ✓ |
| 其他 | 离开团队 | ❌ | ✓ | ✓ |

> **解散团队**：不做 app 内自助入口。Owner 想停用团队需要联系客服/运营处理。后端 `POST /api/experts/{id}/dissolve` endpoint 保留（供管理后台使用）。

未授权项**完全不显示**（不灰掉）。

### 团队切换器（Team Switcher Sheet）

- 触发：点击 AppBar 标题区域
- 布局：Bottom sheet
- 内容：
  - 顶部 drag handle
  - 标题 "切换达人团队"
  - 每个团队一行：头像 + 名称 + 角色 badge + 服务数（`total_services`）；当前选中项右侧显示 ✓
  - 分隔线
  - 底部两项：
    - 「申请新团队」→ `context.push('/expert-teams/create')`
    - 「我的邀请」→ `context.push('/expert-teams/invitations')`，带未读数 badge
- 用户选中一个团队：cubit `.switchTo(expertId)` → StorageService 持久化 → sheet 关闭 → shell 重建

### 管理中心（Management Center View）

- 路由：`/expert-dashboard/:expertId/management`
- 布局：普通 Scaffold + 分组 ListView（`Material` CupertinoLikedListTile 样式）
- 数据：从 `SelectedExpertCubit` 读取 `currentTeam.myRole`，根据权限表动态构建分组和项
- 每项点击：`context.push('/expert-dashboard/$expertId/management/<sub-route>')`
- 危险操作（仅离开）：点击弹出确认 dialog
  - 离开：简单确认 dialog（Owner 不显示此项）

### 管理子页

每个子页（members / join_requests / coupons / packages 等）：
- 从路由参数读取 `expertId`
- 各自创建自己的 BLoC（page level），避免全局状态污染
- 复用 `features/expert_team/` 中现有的 BLoC 逻辑（`ExpertTeamBloc` 或从中拆分）
- AppBar 带返回按钮（默认路由行为）

## 错误处理

- **团队加载失败**：shell 显示 error state + retry 按钮，调用 `_loadMyTeams()`
- **角色过期**（比如用户被踢出）：切换团队或 API 返回 403 时 → 重定向到 `/expert-dashboard`（重新解析）
- **管理子页权限错误**：返回 + SnackBar 提示"无权限"
- **切换团队失败**（持久化失败）：UI 仍切换，log 记录错误，不阻塞

所有错误走现有的 `error_localizer.dart` + `l10n` 机制。

## 测试

本次以 UI 重构 + 代码迁移为主，测试策略：

- **无新增单元测试**（重用现有 repository 测试）
- **手动验证清单**（放在实现计划末尾）：
  1. Owner/Admin/Member 三种角色分别进入 dashboard，tab 可见性正确
  2. 多团队用户通过切换器切换团队，内容正确更新，持久化正确
  3. 管理中心各项可见性匹配角色表
  4. 每个管理子页能正常 CRUD
  5. 刷新页面后自动恢复上次选中的团队
  6. Member 用户看不到申请 tab
  7. 0 teams 用户被重定向到 intro 页
  8. Owner 看不到"离开团队"选项；Admin/Member 能正常离开

## 代码清理

迁移完成后删除：
- `link2ur/lib/features/task_expert/views/expert_dashboard_view.dart`（→ `expert_dashboard_shell.dart`）
- `link2ur/lib/features/task_expert/views/expert_dashboard_*_tab.dart`（5 个，→ `tabs/`）
- `link2ur/lib/features/task_expert/views/expert_profile_edit_view.dart`（→ `management/edit_team_profile_view.dart` 替代）
- `link2ur/lib/features/task_expert/views/expert_applications_management_view.dart`（→ `tabs/applications_tab.dart`）
- `link2ur/lib/features/task_expert/bloc/expert_dashboard_bloc.dart` 及其 part 文件（→ 新 bloc）
- `link2ur/lib/features/expert_team/views/expert_team_members_view.dart`（→ `management/members_view.dart`）
- `link2ur/lib/features/expert_team/views/join_requests_view.dart`（→ `management/`）
- `link2ur/lib/features/expert_team/views/edit_team_profile_view.dart`（→ `management/`）
- `link2ur/lib/features/expert_team/views/expert_coupons_view.dart`（→ `management/coupons_view.dart`）
- `link2ur/lib/features/expert_team/views/expert_packages_view.dart`（→ `management/packages_view.dart`）
- `link2ur/lib/features/expert_team/views/expert_services_manage_view.dart`（**完全删除**，与 `services_tab` 重复）

路由注册：
- `lib/core/router/routes/task_expert_routes.dart`：删除 `expertDashboard` / `expertProfileEdit` / `expertApplicationsManagement` 三条路由
- 新建 `lib/core/router/routes/expert_dashboard_routes.dart`：注册新的 shell + 嵌套管理路由

## Non-Goals (明确不做)

- 不改后端端点（上一轮已对齐）
- 不改 `task_expert/` 中的公开浏览页面（list / search / detail / intro / service_detail）
- 不改 `expert_team/` 中的 `create_team_view`、`my_teams_view`、`my_invitations_view`、`expert_team_detail_view`、`group_buy_view`
- 不实现内部群聊
- 不改 `ApiEndpoints` 常量

## 实施策略

建议按以下顺序执行，每步独立可测：

1. **Phase A**: 建新目录 + `SelectedExpertCubit` + 新 shell + 迁移 5 tab（保持现有 bloc 行为）
2. **Phase B**: 团队切换器 + 多团队支持 + StorageService 持久化
3. **Phase C**: 管理中心主页 + 子页迁移（成员、申请审核、团队资料、优惠券、套餐）
4. **Phase D**: 新建评价回复 view + 链接到已有 Stripe Connect onboarding view
5. **Phase E**: 离开团队（非 Owner）
6. **Phase F**: 路由切换、清理旧目录、手动验证清单

Phase A 和 B 完成后 dashboard 已可用（只差团队 switcher，单团队用户无感）。C/D/E 逐步添加管理功能。F 清理。
