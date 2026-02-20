# Admin Frontend Overhaul Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix orphaned pages, add Dashboard charts, refactor all pages to shared hooks, and add CSV export + task management operations across 4 phases.

**Architecture:** React 18 + TypeScript + Ant Design 5 + React Router 6. Feature modules under `src/pages/admin/<feature>/`. Shared state via `useAdminTable` (pagination/filter) and `useModalForm` (create/edit dialogs). All API calls in `src/api.ts`.

**Tech Stack:** React 18, TypeScript 4.9, Ant Design 5, recharts (new), react-router-dom 6, axios, dayjs

**Design doc:** `docs/plans/2026-02-20-admin-frontend-overhaul-design.md`

**TypeScript check command:** `cd admin && npx tsc --noEmit`
**Dev server:** `cd admin && npm start` (HTTPS on port 3001)

---

## P1: Quick Fixes — Connect Orphaned Pages

### Task 1: Move TaskManagement to canonical location

**Files:**
- Move: `src/components/TaskManagement.tsx` → `src/pages/admin/tasks/TaskManagement.tsx`
- Create: `src/pages/admin/tasks/index.ts`
- Modify: `src/routes/adminRoutes.tsx`
- Modify: `src/layouts/AdminLayout.tsx`

**Step 1: Move the file**

```bash
mkdir -p admin/src/pages/admin/tasks
cp admin/src/components/TaskManagement.tsx admin/src/pages/admin/tasks/TaskManagement.tsx
```

Then delete the original: remove `admin/src/components/TaskManagement.tsx`.

**Step 2: Create index.ts**

Create `src/pages/admin/tasks/index.ts`:
```typescript
export { default as TaskManagement } from './TaskManagement';
```

**Step 3: Fix any import path issues in TaskManagement.tsx**

The moved file has this at the top:
```typescript
import { ... } from '../api';         // was src/components/ → src/api.ts (same level)
import { TimeHandlerV2 } from '../utils/timeUtils';
```

After moving to `src/pages/admin/tasks/`, the imports need to go up 3 levels:
```typescript
import { ... } from '../../../api';
import { TimeHandlerV2 } from '../../../utils/timeUtils';
```

Open `src/pages/admin/tasks/TaskManagement.tsx` and update ALL relative imports:
- `'../api'` → `'../../../api'`
- `'../utils/...'` → `'../../../utils/...'`
- `'../components/...'` → `'../../../components/...'`

**Step 4: Add lazy import to adminRoutes.tsx**

In `src/routes/adminRoutes.tsx`, add after the existing lazy imports:
```typescript
const TaskManagement = lazy(() => import('../pages/admin/tasks').then(m => ({ default: m.TaskManagement })));
```

**Step 5: Add route in adminRoutes.tsx**

Inside the `<Routes>` block, add:
```tsx
<Route path="tasks" element={<TaskManagement />} />
```

**Step 6: Add menu item in AdminLayout.tsx**

In `defaultMenuItems`, add after the `experts` entry:
```typescript
{
  key: 'tasks',
  label: '任务管理',
  icon: '📋',
  path: '/admin/tasks',
},
```

**Step 7: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```
Expected: 0 errors. Fix any import path issues if they appear.

**Step 8: Verify in browser**

Start dev server, navigate to `/admin/tasks`, confirm the page renders and loads task data.

**Step 9: Commit**

```bash
git add admin/src/pages/admin/tasks/ admin/src/routes/adminRoutes.tsx admin/src/layouts/AdminLayout.tsx
git commit -m "feat(admin): connect TaskManagement to routes and sidebar"
```

---

### Task 2: Move JobPositionManagement to canonical location

**Files:**
- Move: `src/pages/JobPositionManagement.tsx` → `src/pages/admin/job-positions/JobPositionManagement.tsx`
- Create: `src/pages/admin/job-positions/index.ts`
- Modify: `src/routes/adminRoutes.tsx`
- Modify: `src/layouts/AdminLayout.tsx`

**Step 1: Move the file**

```bash
mkdir -p admin/src/pages/admin/job-positions
cp admin/src/pages/JobPositionManagement.tsx admin/src/pages/admin/job-positions/JobPositionManagement.tsx
```

Then delete `admin/src/pages/JobPositionManagement.tsx`.

**Step 2: Create index.ts**

Create `src/pages/admin/job-positions/index.ts`:
```typescript
export { default as JobPositionManagement } from './JobPositionManagement';
```

**Step 3: Fix import paths in JobPositionManagement.tsx**

The file was at `src/pages/` — now it's at `src/pages/admin/job-positions/`. Relative imports that were `'../api'` are now `'../../../api'`. Check and update all relative imports.

**Step 4: Add lazy import to adminRoutes.tsx**

```typescript
const JobPositionManagement = lazy(() => import('../pages/admin/job-positions').then(m => ({ default: m.JobPositionManagement })));
```

**Step 5: Add route**

```tsx
<Route path="job-positions" element={<JobPositionManagement />} />
```

**Step 6: Add menu item in AdminLayout.tsx**

Add after the `tasks` entry:
```typescript
{
  key: 'job-positions',
  label: '岗位管理',
  icon: '💼',
  path: '/admin/job-positions',
},
```

**Step 7: TypeScript check + verify**

```bash
cd admin && npx tsc --noEmit
```

Navigate to `/admin/job-positions` and verify it renders.

**Step 8: Commit**

```bash
git add admin/src/pages/admin/job-positions/ admin/src/routes/adminRoutes.tsx admin/src/layouts/AdminLayout.tsx
git commit -m "feat(admin): connect JobPositionManagement to routes and sidebar"
```

---

### Task 3: Move CustomerServiceManagement to canonical location

**Files:**
- Move: `src/components/CustomerServiceManagement.tsx` → `src/pages/admin/customer-service/CustomerServiceManagement.tsx`
- Create: `src/pages/admin/customer-service/index.ts`
- Modify: `src/routes/adminRoutes.tsx`
- Modify: `src/layouts/AdminLayout.tsx`

**Step 1: Move the file**

```bash
mkdir -p admin/src/pages/admin/customer-service
cp admin/src/components/CustomerServiceManagement.tsx admin/src/pages/admin/customer-service/CustomerServiceManagement.tsx
```

Delete `admin/src/components/CustomerServiceManagement.tsx`.

**Step 2: Create index.ts**

```typescript
export { default as CustomerServiceManagement } from './CustomerServiceManagement';
```

**Step 3: Fix import paths**

File was at `src/components/`. Now at `src/pages/admin/customer-service/`. Update all relative imports:
- `'../api'` → `'../../../api'`
- `'../utils/...'` → `'../../../utils/...'`

**Step 4: Add lazy import**

```typescript
const CustomerServiceManagement = lazy(() => import('../pages/admin/customer-service').then(m => ({ default: m.CustomerServiceManagement })));
```

**Step 5: Add route**

```tsx
<Route path="customer-service" element={<CustomerServiceManagement />} />
```

**Step 6: Add menu item**

Add after `job-positions`:
```typescript
{
  key: 'customer-service',
  label: '客服管理',
  icon: '🎧',
  path: '/admin/customer-service',
},
```

**Step 7: TypeScript check + verify**

```bash
cd admin && npx tsc --noEmit
```

Navigate to `/admin/customer-service` and verify it renders.

**Step 8: Commit**

```bash
git add admin/src/pages/admin/customer-service/ admin/src/routes/adminRoutes.tsx admin/src/layouts/AdminLayout.tsx
git commit -m "feat(admin): connect CustomerServiceManagement to routes and sidebar"
```

---

### Task 4: Mount NotificationBell + NotificationModal in AdminLayout

**Files:**
- Modify: `src/layouts/AdminLayout.tsx`

**Step 1: Read the current AdminLayout.tsx**

Note: `NotificationBell` uses `forwardRef` and requires:
- `userType: 'customer_service' | 'admin'`
- `onOpenModal: () => void`

`NotificationModal` requires:
- `isOpen: boolean`
- `onClose: () => void`
- `userType: 'customer_service' | 'admin'`
- `onNotificationRead?: () => void`

**Step 2: Update AdminLayout.tsx imports**

Add at the top of `AdminLayout.tsx`:
```typescript
import { useRef } from 'react';
import NotificationBell, { NotificationBellRef } from '../components/NotificationBell';
import NotificationModal from '../components/NotificationModal';
```

**Step 3: Add state + ref inside AdminLayout component**

Inside `AdminLayout` component body, after the existing `useState` calls:
```typescript
const [showNotificationModal, setShowNotificationModal] = useState(false);
const notificationBellRef = useRef<NotificationBellRef>(null);
```

**Step 4: Mount components in TopBar**

Find the `topBarActions` div in the JSX. Insert `NotificationBell` BEFORE the userMenuContainer div:
```tsx
<div className={styles.topBarActions}>
  {/* Notification Bell */}
  <NotificationBell
    ref={notificationBellRef}
    userType="admin"
    onOpenModal={() => setShowNotificationModal(true)}
  />

  {/* User Menu — existing code unchanged */}
  <div className={styles.userMenuContainer}>
    ...
  </div>
</div>
```

After the closing `</div>` of `mainContainer`, add the modal:
```tsx
<NotificationModal
  isOpen={showNotificationModal}
  onClose={() => setShowNotificationModal(false)}
  userType="admin"
  onNotificationRead={() => notificationBellRef.current?.refreshUnreadCount()}
/>
```

**Step 5: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```

**Step 6: Verify in browser**

Bell icon appears in TopBar, click shows notification modal.

**Step 7: Commit**

```bash
git add admin/src/layouts/AdminLayout.tsx
git commit -m "feat(admin): mount NotificationBell and NotificationModal in AdminLayout"
```

---

### Task 5: Add Breadcrumb navigation to AdminLayout

**Files:**
- Modify: `src/layouts/AdminLayout.tsx`
- Modify: `src/layouts/AdminLayout.module.css` (optional: style adjustments)

**Step 1: Build a path→label map**

In `AdminLayout.tsx`, add this constant (after `defaultMenuItems`):
```typescript
const PATH_LABELS: Record<string, string> = {
  '/admin': '仪表盘',
  '/admin/users': '用户管理',
  '/admin/experts': '专家管理',
  '/admin/tasks': '任务管理',
  '/admin/job-positions': '岗位管理',
  '/admin/customer-service': '客服管理',
  '/admin/coupons': '优惠券管理',
  '/admin/disputes': '纠纷管理',
  '/admin/refunds': '退款管理',
  '/admin/notifications': '通知管理',
  '/admin/invitations': '邀请码管理',
  '/admin/forum': '论坛管理',
  '/admin/flea-market': '跳蚤市场',
  '/admin/leaderboard': '排行榜',
  '/admin/banners': 'Banner管理',
  '/admin/reports': '举报管理',
  '/admin/settings': '设置',
};
```

**Step 2: Add Breadcrumb import**

```typescript
import { Breadcrumb } from 'antd';
```

**Step 3: Build breadcrumb items from location.pathname**

Inside the `AdminLayout` component (before the return):
```typescript
const breadcrumbItems = React.useMemo(() => {
  const pathname = location.pathname;
  const items = [{ title: 'LinkU 管理后台' }];
  if (PATH_LABELS[pathname] && pathname !== '/admin') {
    items.push({ title: PATH_LABELS[pathname] });
  }
  return items;
}, [location.pathname]);
```

**Step 4: Replace empty breadcrumb div in JSX**

Find:
```tsx
<div className={styles.breadcrumb}>
  {/* Breadcrumb can be added later */}
</div>
```

Replace with:
```tsx
<Breadcrumb items={breadcrumbItems} className={styles.breadcrumb} />
```

**Step 5: TypeScript check + verify**

```bash
cd admin && npx tsc --noEmit
```

Navigate to different pages and confirm breadcrumb updates.

**Step 6: Commit**

```bash
git add admin/src/layouts/AdminLayout.tsx
git commit -m "feat(admin): add breadcrumb navigation to AdminLayout TopBar"
```

---

### Task 6: Complete the Settings page

**Files:**
- Modify: `src/pages/admin/settings/Settings.tsx`

**Step 1: Read the existing Settings.tsx**

It currently only has a "clear cache" button. We need to add:
1. System info panel (version, environment, backend URL)
2. 2FA / admin password entry point

**Step 2: Add imports**

```typescript
import { API_BASE_URL } from '../../../config';
```

**Step 3: Replace the Settings component body**

Replace the return JSX with:
```tsx
return (
  <div>
    <h2 style={{ marginBottom: '20px' }}>系统设置</h2>
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>

      {/* 缓存管理 — existing section, keep unchanged */}
      ...

      {/* 系统信息 */}
      <div style={{ background: 'white', padding: '24px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
        <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>系统信息</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
          <div>
            <div style={{ color: '#666', fontSize: '12px', marginBottom: '4px' }}>版本</div>
            <div style={{ fontWeight: '500' }}>v1.0.0</div>
          </div>
          <div>
            <div style={{ color: '#666', fontSize: '12px', marginBottom: '4px' }}>环境</div>
            <div style={{ fontWeight: '500' }}>
              {process.env.NODE_ENV === 'production' ? '生产环境' : '开发环境'}
            </div>
          </div>
          <div>
            <div style={{ color: '#666', fontSize: '12px', marginBottom: '4px' }}>后端地址</div>
            <div style={{ fontWeight: '500', fontSize: '12px', wordBreak: 'break-all' }}>{API_BASE_URL}</div>
          </div>
        </div>
      </div>

      {/* 安全设置 */}
      <div style={{ background: 'white', padding: '24px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
        <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>安全设置</h3>
        <p style={{ color: '#666', marginBottom: '16px', fontSize: '14px' }}>
          管理双因素认证 (2FA) 和账号安全。
        </p>
        <button
          onClick={() => window.location.href = '/2fa-settings'}
          style={{
            padding: '10px 20px', border: '1px solid #d9d9d9', background: 'white',
            borderRadius: '4px', cursor: 'pointer', fontSize: '14px'
          }}
        >
          🔐 管理双因素认证 (2FA)
        </button>
      </div>

    </div>
  </div>
);
```

> Note: The 2FA settings page is at `src/components/TwoFactorAuthSettings.tsx`. If it has its own route already, update the `href` accordingly. Check `App.tsx` for existing routes.

**Step 4: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```

**Step 5: Commit**

```bash
git add admin/src/pages/admin/settings/Settings.tsx
git commit -m "feat(admin): complete Settings page with system info and security entry"
```

---

## P2: Dashboard Charts

### Task 7: Install recharts

**Step 1: Install**

```bash
cd admin && npm install recharts
cd admin && npm install --save-dev @types/recharts
```

> Note: `@types/recharts` may not exist (recharts ships its own types). If the install fails, skip the `@types/recharts` step — recharts v2 includes TypeScript types.

**Step 2: Verify TypeScript check still passes**

```bash
cd admin && npx tsc --noEmit
```

**Step 3: Commit**

```bash
git add admin/package.json admin/package-lock.json
git commit -m "chore(admin): add recharts for Dashboard charts"
```

---

### Task 8: Add stats trend API functions

**Files:**
- Modify: `src/api.ts`

**Step 1: Add types and functions to api.ts**

Find the end of the API function section and add:
```typescript
// ===== Dashboard Stats Trends =====

export interface TrendDataPoint {
  date: string;
  count: number;
}

export interface TrendResponse {
  dates: string[];
  counts: number[];
}

export async function getUserGrowthStats(period: '7d' | '30d' | '90d'): Promise<TrendDataPoint[]> {
  const response = await api.get<TrendResponse>(`/api/admin/stats/user-growth?period=${period}`);
  const { dates, counts } = response.data;
  return dates.map((date, i) => ({ date, count: counts[i] ?? 0 }));
}

export async function getTaskGrowthStats(period: '7d' | '30d' | '90d'): Promise<TrendDataPoint[]> {
  const response = await api.get<TrendResponse>(`/api/admin/stats/task-growth?period=${period}`);
  const { dates, counts } = response.data;
  return dates.map((date, i) => ({ date, count: counts[i] ?? 0 }));
}
```

> **Backend note:** If `/api/admin/stats/user-growth` and `/api/admin/stats/task-growth` endpoints do not yet exist in `backend/app/routers.py`, they need to be added. The endpoints should query the DB for daily new user/task counts grouped by `created_at::date` for the given period.

**Step 2: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```

**Step 3: Commit**

```bash
git add admin/src/api.ts
git commit -m "feat(admin): add getUserGrowthStats and getTaskGrowthStats API functions"
```

---

### Task 9: Update Dashboard with period switcher and trend charts

**Files:**
- Modify: `src/pages/admin/dashboard/Dashboard.tsx`
- Modify: `src/pages/admin/dashboard/types.ts`
- Modify: `src/pages/admin/dashboard/Dashboard.module.css`

**Step 1: Update types.ts**

Add to `src/pages/admin/dashboard/types.ts`:
```typescript
export type StatPeriod = '7d' | '30d' | '90d';

export interface TrendDataPoint {
  date: string;
  count: number;
}
```

**Step 2: Add chart section to Dashboard.tsx**

Replace the full `Dashboard.tsx` content with the expanded version. Key changes:
1. Add `period` state: `const [period, setPeriod] = useState<StatPeriod>('30d');`
2. Add `userTrend`, `taskTrend`, `chartLoading` states
3. Add `fetchTrends` callback using `getUserGrowthStats` + `getTaskGrowthStats`
4. Call `fetchTrends` in `useEffect` when `period` changes
5. Add period switcher buttons
6. Add two `<LineChart>` components

Complete updated `Dashboard.tsx`:
```typescript
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { message } from 'antd';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer
} from 'recharts';
import api, { getDashboardStats, getUserGrowthStats, getTaskGrowthStats, TrendDataPoint } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import { DashboardStats, StatCardProps, StatPeriod } from './types';
import styles from './Dashboard.module.css';

const StatCard: React.FC<StatCardProps> = ({ label, value, prefix = '', suffix = '' }) => (
  <div className={styles.statCard}>
    <h3 className={styles.statLabel}>{label}</h3>
    <p className={styles.statValue}>
      {prefix}{typeof value === 'number' ? value.toLocaleString() : value}{suffix}
    </p>
  </div>
);

const PERIOD_LABELS: Record<StatPeriod, string> = {
  '7d': '7天',
  '30d': '30天',
  '90d': '90天',
};

const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cleanupLoading, setCleanupLoading] = useState(false);
  const [period, setPeriod] = useState<StatPeriod>('30d');
  const [userTrend, setUserTrend] = useState<TrendDataPoint[]>([]);
  const [taskTrend, setTaskTrend] = useState<TrendDataPoint[]>([]);
  const [chartLoading, setChartLoading] = useState(false);

  const fetchStats = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getDashboardStats();
      setStats(data);
    } catch (err: any) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchTrends = useCallback(async () => {
    setChartLoading(true);
    try {
      const [users, tasks] = await Promise.all([
        getUserGrowthStats(period),
        getTaskGrowthStats(period),
      ]);
      setUserTrend(users);
      setTaskTrend(tasks);
    } catch (err: any) {
      message.warning('趋势数据加载失败: ' + getErrorMessage(err));
    } finally {
      setChartLoading(false);
    }
  }, [period]);

  useEffect(() => { fetchStats(); }, [fetchStats]);
  useEffect(() => { fetchTrends(); }, [fetchTrends]);

  const handleCleanupOldTasks = useCallback(async () => {
    // keep existing implementation unchanged
    ...
  }, [fetchStats]);

  if (loading) return <div className={styles.loadingContainer}>...</div>;
  if (error) return <div className={styles.errorContainer}>...</div>;

  return (
    <div className={styles.dashboardSection}>
      {/* Header with period switcher */}
      <div className={styles.dashboardHeader}>
        <h2 className={styles.dashboardTitle}>数据概览</h2>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          {(['7d', '30d', '90d'] as StatPeriod[]).map(p => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`${styles.periodBtn} ${period === p ? styles.periodBtnActive : ''}`}
            >
              {PERIOD_LABELS[p]}
            </button>
          ))}
          <button onClick={handleCleanupOldTasks} disabled={cleanupLoading} className={styles.cleanupBtn}>
            {cleanupLoading ? '清理中...' : '🗑️ 一键清理'}
          </button>
        </div>
      </div>

      {/* Stats cards */}
      {stats && (
        <div className={styles.statsGrid}>
          <StatCard label="总用户数" value={stats.total_users} />
          <StatCard label="总任务数" value={stats.total_tasks} />
          <StatCard label="客服数量" value={stats.total_customer_service} />
          <StatCard label="活跃会话" value={stats.active_sessions} />
          <StatCard label="总收入" value={stats.total_revenue.toFixed(2)} prefix="£" />
          <StatCard label="平均评分" value={stats.avg_rating.toFixed(1)} />
        </div>
      )}

      {/* Trend charts */}
      <div className={styles.chartsGrid}>
        <div className={styles.chartCard}>
          <h3 className={styles.chartTitle}>📈 用户注册趋势</h3>
          {chartLoading ? (
            <div className={styles.chartLoading}>加载中...</div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <LineChart data={userTrend} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#1890ff" dot={false} strokeWidth={2} name="新增用户" />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
        <div className={styles.chartCard}>
          <h3 className={styles.chartTitle}>📊 任务发布趋势</h3>
          {chartLoading ? (
            <div className={styles.chartLoading}>加载中...</div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <LineChart data={taskTrend} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#52c41a" dot={false} strokeWidth={2} name="新增任务" />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
```

> The `handleCleanupOldTasks` function is unchanged from the original — keep the full existing implementation.

**Step 3: Add CSS for new classes in Dashboard.module.css**

Add these classes:
```css
.periodBtn {
  padding: 4px 12px;
  border: 1px solid #d9d9d9;
  background: white;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
  color: #666;
}
.periodBtn:hover { border-color: #1890ff; color: #1890ff; }
.periodBtnActive { border-color: #1890ff; color: #1890ff; background: #e6f7ff; font-weight: 500; }

.chartsGrid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 24px;
}
@media (max-width: 900px) {
  .chartsGrid { grid-template-columns: 1fr; }
}

.chartCard {
  background: white;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}
.chartTitle { font-size: 15px; font-weight: 600; margin: 0 0 16px 0; }
.chartLoading { height: 240px; display: flex; align-items: center; justify-content: center; color: #999; }
```

**Step 4: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```

**Step 5: Verify in browser**

Dashboard shows 6 stat cards + 2 line charts. Period buttons switch 7d/30d/90d and charts reload.

**Step 6: Commit**

```bash
git add admin/src/pages/admin/dashboard/ admin/package.json admin/package-lock.json
git commit -m "feat(admin): add trend charts to Dashboard with period switcher"
```

---

## P3: Full Page Refactoring

**Pattern to follow** (reference: `src/pages/admin/coupons/CouponManagement.refactored.tsx`):
```typescript
// 1. useAdminTable for list + pagination
const table = useAdminTable<T>({
  fetchData: async ({ page, pageSize, filters }) => ({
    data: response.items,
    total: response.total,
  }),
  initialPageSize: 20,
  onError: (err) => message.error(getErrorMessage(err)),
});

// 2. useModalForm for create/edit (only if the page has create/edit dialogs)
const modal = useModalForm<FormT>({
  initialValues: { ... },
  onSubmit: async (values, isEdit) => { await api(...); },
  onSuccess: () => { message.success('成功'); table.refresh(); },
  onError: (err) => message.error(getErrorMessage(err)),
});

// 3. Render
<AdminTable columns={columns} data={table.data} loading={table.loading} rowKey="id" />
<AdminPagination
  currentPage={table.currentPage}
  totalPages={table.totalPages}
  total={table.total}
  pageSize={table.pageSize}
  onPageChange={table.setCurrentPage}
/>
```

---

### Task 10: Refactor UserManagement

**Files:**
- Modify: `src/pages/admin/users/UserManagement.tsx`

**What changes:**
- Replace manual `useState` for `users`, `loading`, `currentPage`, `totalPages`, `searchTerm` with `useAdminTable`
- Replace manual suspend modal state with `useModalForm` (suspend form)
- Keep `handleBanUser`, `handleSuspendUser`, `handleUpdateUserLevel` action handlers (these are not modal forms but direct API calls)
- Keep suspend duration logic but route through `useModalForm`

**Step 1: Import shared hooks/components**

```typescript
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
```

**Step 2: Replace state block with useAdminTable**

Remove:
```typescript
const [users, setUsers] = useState<User[]>([]);
const [loading, setLoading] = useState(false);
const [currentPage, setCurrentPage] = useState(1);
const [totalPages, setTotalPages] = useState(1);
const [searchTerm, setSearchTerm] = useState('');
const [userActionLoading, setUserActionLoading] = useState<string | null>(null);
```

Replace with:
```typescript
const [userActionLoading, setUserActionLoading] = useState<string | null>(null);

const table = useAdminTable<User>({
  fetchData: async ({ page, pageSize, searchTerm }) => {
    const response = await getUsersForAdmin(page, pageSize, searchTerm || undefined);
    return { data: response.users || [], total: (response.total_pages || 1) * pageSize };
  },
  initialPageSize: 20,
  onError: (err) => { setError(getErrorMessage(err)); },
});
```

> Note: `getUsersForAdmin` returns `total_pages` not `total`. If it doesn't return a `total` count, use `total_pages * pageSize` as an estimate, or check if the API was updated to return `total`.

**Step 3: Replace suspend modal state with useModalForm**

Remove:
```typescript
const [showSuspendModal, setShowSuspendModal] = useState(false);
const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
const [suspendDuration, setSuspendDuration] = useState(1);
```

Replace with:
```typescript
interface SuspendForm { userId: string; days: number; }
const suspendModal = useModalForm<SuspendForm>({
  initialValues: { userId: '', days: 1 },
  onSubmit: async (values) => {
    const suspendUntil = new Date();
    suspendUntil.setDate(suspendUntil.getDate() + values.days);
    await updateUserByAdmin(values.userId, {
      is_suspended: 1,
      suspend_until: suspendUntil.toISOString(),
    });
    message.success(`用户已暂停${values.days}天`);
    table.refresh();
  },
  onError: (err) => message.error(getErrorMessage(err)),
});
```

**Step 4: Define columns array**

```typescript
const columns: Column<User>[] = [
  { key: 'id', title: 'ID', dataIndex: 'id', fixed: 'left', width: 80 },
  { key: 'name', title: '用户名', dataIndex: 'name', fixed: 'left', width: 120 },
  { key: 'email', title: '邮箱', dataIndex: 'email', width: 200 },
  {
    key: 'user_level', title: '等级', width: 120,
    render: (_, user) => (
      <select value={user.user_level} onChange={e => handleUpdateUserLevel(user.id, e.target.value)}
        disabled={userActionLoading === user.id} className={styles.levelSelect}>
        {Object.entries(USER_LEVEL_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
      </select>
    ),
  },
  {
    key: 'status', title: '状态', width: 100,
    render: (_, user) => (
      <span className={`${styles.statusBadge} ${getStatusClassName(user)}`}>{getStatusText(user)}</span>
    ),
  },
  { key: 'task_count', title: '任务数', dataIndex: 'task_count', width: 80 },
  { key: 'avg_rating', title: '评分', width: 80, render: (_, u) => u.avg_rating.toFixed(1) },
  { key: 'invitation_code_text', title: '邀请码', width: 120, render: (_, u) => u.invitation_code_text || '-' },
  {
    key: 'inviter_id', title: '邀请人', width: 120,
    render: (_, u) => u.inviter_id
      ? <span className={styles.inviterId} onClick={() => table.setSearchTerm(u.inviter_id!)}>{u.inviter_id}</span>
      : '-',
  },
  { key: 'created_at', title: '注册时间', width: 120, render: (_, u) => dayjs(u.created_at).format('YYYY-MM-DD') },
  {
    key: 'actions', title: '操作', width: 220,
    render: (_, user) => (
      <div className={styles.actionGroup}>
        <button onClick={() => handleBanUser(user.id, user.is_banned ? 0 : 1)}
          disabled={userActionLoading === user.id}
          className={`${styles.actionBtn} ${user.is_banned ? styles.btnSuccess : styles.btnDanger}`}>
          {user.is_banned ? '解封' : '封禁'}
        </button>
        <button
          onClick={() => user.is_suspended
            ? handleSuspendUser(user.id, 0)
            : suspendModal.open({ userId: user.id, days: 1 })}
          disabled={userActionLoading === user.id}
          className={`${styles.actionBtn} ${user.is_suspended ? styles.btnSuccess : styles.btnWarning}`}>
          {user.is_suspended ? '恢复' : '暂停'}
        </button>
        <button onClick={() => handleUpdateUserLevel(user.id, 'normal')}
          disabled={userActionLoading === user.id}
          className={`${styles.actionBtn} ${styles.btnPrimary}`}>
          重置等级
        </button>
      </div>
    ),
  },
];
```

**Step 5: Replace JSX**

```tsx
return (
  <div className={styles.container}>
    <div className={styles.header}>
      <h2 className={styles.title}>用户管理</h2>
    </div>
    <div className={styles.searchContainer}>
      <input
        type="text"
        placeholder="搜索用户ID、用户名或邮箱..."
        value={table.searchTerm}
        onChange={e => table.setSearchTerm(e.target.value)}
        className={styles.searchInput}
      />
    </div>
    {error && <div className={styles.errorMessage}>{error}</div>}
    <AdminTable columns={columns} data={table.data} loading={table.loading} rowKey="id" />
    <AdminPagination
      currentPage={table.currentPage}
      totalPages={table.totalPages}
      total={table.total}
      pageSize={table.pageSize}
      onPageChange={table.setCurrentPage}
    />
    <AdminModal
      isOpen={suspendModal.isOpen}
      onClose={suspendModal.close}
      title="暂停用户"
      footer={
        <>
          <button onClick={suspendModal.close}>取消</button>
          <button onClick={suspendModal.handleSubmit} disabled={suspendModal.loading}>确认暂停</button>
        </>
      }
    >
      <label>暂停天数</label>
      <input
        type="number" min="1" max="365"
        value={suspendModal.formData.days}
        onChange={e => suspendModal.updateField('days', parseInt(e.target.value) || 1)}
      />
    </AdminModal>
  </div>
);
```

**Step 6: TypeScript check + verify**

```bash
cd admin && npx tsc --noEmit
```

Verify user list loads, search works, ban/suspend/level actions work.

**Step 7: Commit**

```bash
git add admin/src/pages/admin/users/UserManagement.tsx
git commit -m "refactor(admin): refactor UserManagement to use useAdminTable + useModalForm"
```

---

### Task 11: Refactor DisputeManagement, RefundManagement, ExpertManagement

These three pages all follow the same refactor pattern — `useAdminTable` for listing, `AdminModal` for detail/action dialogs. Refactor one at a time.

For each page:

**Step 1:** Read the existing file to understand its state variables and API calls.

**Step 2:** Add imports:
```typescript
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
```

**Step 3:** Replace the `useState` block for list state with `useAdminTable`.

**Step 4:** Replace `useState` blocks for modal state with `useModalForm` (if the page has create/edit dialogs).

**Step 5:** Define `columns: Column<T>[]` array (move cell render logic from JSX into column `render` functions).

**Step 6:** Replace the JSX with `<AdminTable>`, `<AdminPagination>`, `<AdminModal>`.

**Step 7:** TypeScript check + verify each page works.

**Step 8:** Commit after each page:
```bash
git commit -m "refactor(admin): refactor DisputeManagement to shared hooks"
git commit -m "refactor(admin): refactor RefundManagement to shared hooks"
git commit -m "refactor(admin): refactor ExpertManagement to shared hooks"
```

---

### Task 12: Refactor ForumManagement, FleaMarketManagement, ReportManagement

Same pattern as Task 11. `ReportManagement` has two sub-tabs (forum + flea market) so it needs **two** `useAdminTable` calls — one per tab.

For `ReportManagement` specifically:
1. Define TypeScript interfaces for `ForumReport` and `FleaReport` (replace `any[]`)
2. Use `useAdminTable<ForumReport>` for the forum tab
3. Use `useAdminTable<FleaReport>` for the flea market tab

Commit after each page.

---

### Task 13: Refactor NotificationManagement, InvitationManagement, LeaderboardManagement, BannerManagement

Same pattern. `BannerManagement` has create/edit functionality so it needs both `useAdminTable` + `useModalForm`.

Commit after each page.

---

### Task 14: Rename CouponManagement.refactored.tsx

**Files:**
- Rename: `src/pages/admin/coupons/CouponManagement.refactored.tsx` → `src/pages/admin/coupons/CouponManagement.tsx`
- Modify: `src/pages/admin/coupons/index.ts`

**Step 1: Rename the file**

```bash
cp admin/src/pages/admin/coupons/CouponManagement.refactored.tsx admin/src/pages/admin/coupons/CouponManagement.tsx
```

Delete `CouponManagement.refactored.tsx`.

**Step 2: Update index.ts**

Open `src/pages/admin/coupons/index.ts` and ensure it exports from `CouponManagement` not `CouponManagement.refactored`.

Current content might be:
```typescript
export { CouponManagement } from './CouponManagement.refactored';
```

Update to:
```typescript
export { CouponManagement } from './CouponManagement';
```

**Step 3: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```

**Step 4: Commit**

```bash
git add admin/src/pages/admin/coupons/
git commit -m "refactor(admin): rename CouponManagement.refactored.tsx to CouponManagement.tsx"
```

---

## P4: New Features

### Task 15: Create CSV export utility

**Files:**
- Create: `src/utils/exportUtils.ts`

**Step 1: Create the utility**

Create `src/utils/exportUtils.ts`:
```typescript
export interface ExportColumn {
  key: string;
  label: string;
  /** Optional transform function for the cell value */
  format?: (value: any, row: Record<string, any>) => string;
}

/**
 * Export data as CSV and trigger browser download.
 * UTF-8 BOM is prepended so Excel opens Chinese characters correctly.
 */
export function exportToCSV(
  data: Record<string, any>[],
  filename: string,
  columns: ExportColumn[]
): void {
  const header = columns.map(c => `"${c.label}"`).join(',');
  const rows = data.map(row =>
    columns
      .map(c => {
        const raw = c.format ? c.format(row[c.key], row) : row[c.key];
        const value = raw == null ? '' : String(raw);
        return `"${value.replace(/"/g, '""')}"`;
      })
      .join(',')
  );
  const csv = [header, ...rows].join('\r\n');
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${filename}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
```

**Step 2: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```

**Step 3: Commit**

```bash
git add admin/src/utils/exportUtils.ts
git commit -m "feat(admin): add exportToCSV utility for client-side CSV export"
```

---

### Task 16: Add CSV export buttons to UserManagement, TaskManagement, RefundManagement

**Files:**
- Modify: `src/pages/admin/users/UserManagement.tsx`
- Modify: `src/pages/admin/tasks/TaskManagement.tsx`
- Modify: `src/pages/admin/refunds/RefundManagement.tsx`

For each page, add an export button in the page header area. Example for `UserManagement`:

**Step 1: Import exportToCSV**

```typescript
import { exportToCSV, ExportColumn } from '../../../utils/exportUtils';
```

**Step 2: Define export columns**

```typescript
const USER_EXPORT_COLUMNS: ExportColumn[] = [
  { key: 'id', label: 'ID' },
  { key: 'name', label: '用户名' },
  { key: 'email', label: '邮箱' },
  { key: 'user_level', label: '等级', format: v => USER_LEVEL_LABELS[v as UserLevel] || v },
  { key: 'is_banned', label: '封禁', format: v => v ? '是' : '否' },
  { key: 'is_suspended', label: '暂停', format: v => v ? '是' : '否' },
  { key: 'task_count', label: '任务数' },
  { key: 'avg_rating', label: '评分', format: v => Number(v).toFixed(1) },
  { key: 'created_at', label: '注册时间', format: v => dayjs(v).format('YYYY-MM-DD') },
];
```

**Step 3: Add export handler**

```typescript
const handleExport = () => {
  exportToCSV(
    table.data as Record<string, any>[],
    `users-${dayjs().format('YYYY-MM-DD')}`,
    USER_EXPORT_COLUMNS
  );
};
```

**Step 4: Add button in header**

```tsx
<div className={styles.header}>
  <h2 className={styles.title}>用户管理</h2>
  <button onClick={handleExport} disabled={table.data.length === 0} className={styles.exportBtn}>
    📥 导出 CSV
  </button>
</div>
```

Add `.exportBtn` CSS:
```css
.exportBtn {
  padding: 8px 16px;
  border: 1px solid #52c41a;
  background: white;
  color: #52c41a;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}
.exportBtn:hover { background: #f6ffed; }
.exportBtn:disabled { opacity: 0.5; cursor: not-allowed; }
```

**Step 5:** Repeat for `TaskManagement` and `RefundManagement` with appropriate column definitions.

**Step 6: TypeScript check**

```bash
cd admin && npx tsc --noEmit
```

**Step 7: Verify**

Click export button — CSV downloads with correct data and Chinese characters open correctly in Excel.

**Step 8: Commit**

```bash
git add admin/src/pages/admin/users/UserManagement.tsx admin/src/pages/admin/tasks/TaskManagement.tsx admin/src/pages/admin/refunds/RefundManagement.tsx
git commit -m "feat(admin): add CSV export to UserManagement, TaskManagement, RefundManagement"
```

---

### Task 17: Verify TaskManagement operations are complete

**Files:**
- Modify: `src/pages/admin/tasks/TaskManagement.tsx` (only if gaps found)

**Step 1: Read the complete TaskManagement.tsx**

Verify these operations are present and working:
- [ ] Cancel task: calls `updateAdminTask(id, { status: 'cancelled' })` with confirmation
- [ ] Delete task: calls `deleteAdminTask(id)` with confirmation
- [ ] Batch cancel: calls `batchUpdateAdminTasks`
- [ ] Batch delete: calls `batchDeleteAdminTasks`
- [ ] Approve participant: calls `approveParticipant`
- [ ] Reject participant: calls `rejectParticipant`
- [ ] Approve exit request: calls `approveExitRequest`
- [ ] Reject exit request: calls `rejectExitRequest`
- [ ] Filter by status/city/task type

**Step 2: Add any missing operations**

For cancel + delete confirmations, use `window.confirm()` or Ant Design `Modal.confirm()`:
```typescript
const handleCancelTask = async (taskId: number) => {
  if (!window.confirm('确定要取消此任务吗？此操作将通知所有参与者。')) return;
  try {
    await updateAdminTask(taskId, { status: 'cancelled' });
    message.success('任务已取消');
    // refresh list
  } catch (err: any) {
    message.error(getErrorMessage(err));
  }
};

const handleDeleteTask = async (taskId: number) => {
  if (!window.confirm('确定要删除此任务吗？此操作不可恢复！')) return;
  try {
    await deleteAdminTask(taskId);
    message.success('任务已删除');
    // refresh list
  } catch (err: any) {
    message.error(getErrorMessage(err));
  }
};
```

**Step 3: TypeScript check + manual verify**

```bash
cd admin && npx tsc --noEmit
```

Test cancel and delete operations on a test task.

**Step 4: Commit (if changes made)**

```bash
git add admin/src/pages/admin/tasks/TaskManagement.tsx
git commit -m "feat(admin): complete TaskManagement cancel/delete operations with confirmations"
```

---

## Final Verification

After all tasks are complete:

**Step 1: Full TypeScript check**
```bash
cd admin && npx tsc --noEmit
```
Expected: 0 errors.

**Step 2: Build check**
```bash
cd admin && npm run build
```
Expected: Successful build, no warnings about import paths.

**Step 3: Manual smoke test checklist**
- [ ] All 17 sidebar items navigate to correct pages
- [ ] Dashboard shows stats + charts, period switcher works
- [ ] Breadcrumb updates on navigation
- [ ] Notification bell shows unread count
- [ ] TaskManagement: list loads, cancel/delete/batch work
- [ ] JobPositionManagement: list loads
- [ ] CustomerServiceManagement: list loads
- [ ] UserManagement: search, ban, suspend, export CSV
- [ ] Settings: system info visible, cache clear works
- [ ] All refactored pages load without console errors
