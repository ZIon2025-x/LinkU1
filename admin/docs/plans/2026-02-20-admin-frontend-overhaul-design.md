# Admin Frontend Overhaul Design
**Date**: 2026-02-20
**Status**: Approved
**Scope**: `admin/` frontend

---

## Background

The admin frontend was migrated from a single 12,571-line monolithic file into feature modules. However, the migration was incomplete:

1. Three feature components were extracted but never wired into the routing system or sidebar, making them inaccessible.
2. Only `CouponManagement` was refactored to use shared hooks/components; the other 12 pages still use raw local state.
3. The Dashboard shows only 6 static numbers with no charts or trends.
4. Settings is nearly empty.
5. No breadcrumb navigation.
6. `NotificationBell` component exists but is not mounted.

---

## Goals

| Priority | Goal |
|----------|------|
| P1 | Connect orphaned components to routes + sidebar; mount notification bell; improve Settings; add breadcrumbs |
| P2 | Add user registration trend + task volume trend charts to Dashboard |
| P3 | Refactor all 12 remaining pages to use shared `useAdminTable` / `useModalForm` pattern |
| P4 | Add CSV export to User/Task/Refund pages; complete task management operations |

---

## P1: Quick Fixes

### 1.1 Orphaned Components → Routes + Sidebar

Three components were extracted from the monolith but never connected:

| Component | Current Location | Target Location | Sidebar Label |
|-----------|-----------------|-----------------|---------------|
| `TaskManagement.tsx` | `src/components/` | `src/pages/admin/tasks/` | 📋 任务管理 |
| `JobPositionManagement.tsx` | `src/pages/` (root) | `src/pages/admin/job-positions/` | 💼 岗位管理 |
| `CustomerServiceManagement.tsx` | `src/components/` | `src/pages/admin/customer-service/` | 🎧 客服管理 |

**Changes required:**
- Move files to canonical location under `src/pages/admin/`
- Add lazy imports in `src/routes/adminRoutes.tsx`
- Add `<Route>` entries in `AdminRoutes`
- Add menu items to `defaultMenuItems` in `AdminLayout.tsx`

### 1.2 NotificationBell

- Mount `<NotificationBell />` in `AdminLayout.tsx` TopBar alongside the user menu button

### 1.3 Settings Completion

Add to `src/pages/admin/settings/Settings.tsx`:
- System info panel: version, environment (dev/prod), backend URL
- Admin password change entry (link to `TwoFactorAuthSettings` component)

### 1.4 Breadcrumbs

- In `AdminLayout.tsx` TopBar, replace the empty `<div className={styles.breadcrumb}>` with Ant Design `<Breadcrumb />` that maps `location.pathname` to human-readable labels using the menu item list

### Sidebar Menu Order (After P1)

```
仪表盘 | 用户管理 | 专家管理 | 任务管理 | 岗位管理 | 客服管理
优惠券管理 | 纠纷管理 | 退款管理 | 通知管理 | 邀请码管理
论坛管理 | 跳蚤市场 | 排行榜 | Banner管理 | 举报管理 | 设置
```

---

## P2: Dashboard Charts

### Chart Library

Use `recharts` (lightweight, React-native, no additional peer deps vs antd Charts).

```bash
npm install recharts
```

### New Backend Endpoints Required

```
GET /api/admin/stats/user-growth?period=7d|30d|90d
→ { dates: string[], counts: number[] }

GET /api/admin/stats/task-growth?period=7d|30d|90d
→ { dates: string[], counts: number[] }
```

If backend endpoints are not yet available, use mock data with a `// TODO: connect backend` comment.

### Dashboard Layout

```
┌──────────────────────────────────────────────────────────────┐
│  数据概览  [7天] [30天] [90天]                    [🗑️ 清理]   │
├──────────┬──────────┬──────────┬──────────┬──────────────────┤
│ 总用户数  │ 总任务数  │ 活跃会话  │  总收入   │  平均评分        │
│  12,345  │  3,456   │   128    │ £8,900   │    4.8           │
├──────────────────────────────┬───────────────────────────────┤
│  📈 用户注册趋势              │  📊 任务发布趋势               │
│  LineChart (recharts)        │  LineChart (recharts)         │
│  X: date, Y: new users/day   │  X: date, Y: new tasks/day   │
└──────────────────────────────┴───────────────────────────────┘
```

**Implementation notes:**
- Period switcher: `useState<'7d'|'30d'|'90d'>('30d')` — triggers chart data refetch
- `<ResponsiveContainer width="100%" height={240}>` for responsive sizing
- Loading skeleton while fetching chart data

---

## P3: Full Page Refactoring

### Canonical Pattern (reference: `CouponManagement.refactored.tsx`)

```typescript
// 1. useAdminTable — handles pagination, loading, error, refetch
const table = useAdminTable<T>({
  fetchData: async ({ page, pageSize, filters }) => {
    const res = await getXxx({ page, limit: pageSize, ...filters });
    return { data: res.items, total: res.total };
  },
  onError: (err) => message.error(getErrorMessage(err)),
});

// 2. useModalForm — handles open/close, submit, edit state
const modal = useModalForm<FormT>({
  initialValues: { ... },
  onSubmit: async (values, isEdit) => { ... },
  onSuccess: () => { message.success('...'); table.refresh(); },
});

// 3. Render with shared components
<AdminTable columns={...} data={table.data} loading={table.loading} />
<AdminPagination page={table.page} total={table.total} onChange={table.setPage} />
<AdminModal open={modal.open} onClose={modal.close} onSubmit={modal.submit} />
```

### Pages to Refactor

| Page | Key Changes |
|------|-------------|
| `UserManagement` | useAdminTable; suspend modal → AdminModal |
| `DisputeManagement` | useAdminTable; detail/action modals → AdminModal |
| `RefundManagement` | useAdminTable |
| `ExpertManagement` | useAdminTable |
| `ForumManagement` | useAdminTable |
| `FleaMarketManagement` | useAdminTable |
| `ReportManagement` | useAdminTable × 2 (forum tab + flea tab); add TypeScript types |
| `NotificationManagement` | useAdminTable |
| `InvitationManagement` | useAdminTable |
| `LeaderboardManagement` | useAdminTable |
| `BannerManagement` | useAdminTable + AdminModal |
| `TaskManagement` | Move from components/, refactor to new pattern |

**Additional cleanup:**
- Rename `CouponManagement.refactored.tsx` → `CouponManagement.tsx`, update `index.ts` export
- Remove the now-empty `CouponManagement.refactored.tsx`

---

## P4: New Features

### 4.1 CSV Export (Client-side, Current Page Only)

Create `src/utils/exportUtils.ts`:

```typescript
export function exportToCSV(
  data: Record<string, any>[],
  filename: string,
  columns: { key: string; label: string }[]
): void {
  const header = columns.map(c => c.label).join(',');
  const rows = data.map(row =>
    columns.map(c => JSON.stringify(row[c.key] ?? '')).join(',')
  );
  const csv = [header, ...rows].join('\n');
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' }); // BOM for Excel
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = `${filename}.csv`; a.click();
  URL.revokeObjectURL(url);
}
```

**"导出 CSV" button added to:**
- `UserManagement` — exports: ID, 用户名, 邮箱, 等级, 状态, 任务数, 评分, 注册时间
- `TaskManagement` — exports: ID, 标题, 类型, 城市, 状态, 悬赏, 发布者, 创建时间
- `RefundManagement` — exports: ID, 金额, 状态, 申请人, 申请时间

### 4.2 Task Management Operations

`TaskManagement` already implements most operations. Ensure these are complete and accessible:
- **Cancel task**: `updateAdminTask(id, { status: 'cancelled' })` with confirmation dialog
- **Delete task**: `deleteAdminTask(id)` with confirmation dialog
- **Batch cancel/delete**: using existing `batchUpdateAdminTasks` / `batchDeleteAdminTasks`
- **Participant management**: approve/reject participant, approve/reject exit requests
- **Filter by status/city/task type**: existing UI, verify all filter params work correctly

---

## Architecture Constraints

- No changes to `src/api.ts` API layer
- No new backend endpoints beyond the two stats endpoints in P2
- `useAdminTable` and `useModalForm` hooks extended only if a genuine gap is found; no new hooks for one-off use cases
- All new pages follow feature-directory pattern: `src/pages/admin/<feature>/index.ts` + `<Feature>Management.tsx`

---

## File Structure After Implementation

```
src/
├── components/admin/         # shared components (unchanged)
├── hooks/                    # shared hooks (unchanged)
├── pages/admin/
│   ├── tasks/                # NEW (moved from components/)
│   ├── job-positions/        # NEW (moved from pages root)
│   ├── customer-service/     # NEW (moved from components/)
│   ├── users/                # refactored
│   ├── disputes/             # refactored
│   ├── ... (all other pages refactored)
│   └── coupons/              # rename .refactored.tsx → .tsx
├── utils/
│   └── exportUtils.ts        # NEW
└── routes/adminRoutes.tsx    # 3 new lazy imports + routes
```
