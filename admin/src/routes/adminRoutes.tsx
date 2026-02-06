import React, { lazy, Suspense } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { AdminLayout } from '../layouts/AdminLayout';

// Lazy load components for code splitting
const Dashboard = lazy(() => import('../pages/admin/dashboard/Dashboard'));
const CouponManagement = lazy(() => import('../pages/admin/coupons').then(m => ({ default: m.CouponManagement })));

// Placeholder components for other modules (to be extracted later)
const UserManagement = lazy(() => import('../pages/admin/users/UserManagement'));
const ExpertManagement = lazy(() => import('../pages/admin/experts/ExpertManagement'));
const DisputeManagement = lazy(() => import('../pages/admin/disputes/DisputeManagement'));
const RefundManagement = lazy(() => import('../pages/admin/refunds/RefundManagement'));
const NotificationManagement = lazy(() => import('../pages/admin/notifications/NotificationManagement'));
const InvitationManagement = lazy(() => import('../pages/admin/invitations/InvitationManagement'));
const ForumManagement = lazy(() => import('../pages/admin/forum/ForumManagement'));
const FleaMarketManagement = lazy(() => import('../pages/admin/flea-market/FleaMarketManagement'));
const LeaderboardManagement = lazy(() => import('../pages/admin/leaderboard/LeaderboardManagement'));
const BannerManagement = lazy(() => import('../pages/admin/banners/BannerManagement'));
const ReportManagement = lazy(() => import('../pages/admin/reports/ReportManagement'));
const Settings = lazy(() => import('../pages/admin/settings/Settings'));

// Loading component
const LoadingFallback = () => (
  <div style={{
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    fontSize: '16px',
    color: '#6c757d'
  }}>
    加载中...
  </div>
);

/**
 * Admin Routes Configuration
 * All admin routes are wrapped with AdminLayout and use lazy loading for better performance
 */
export const AdminRoutes: React.FC = () => {
  return (
    <AdminLayout>
      <Suspense fallback={<LoadingFallback />}>
        <Routes>
          {/* Dashboard - 使用 index 路由匹配 /admin */}
          <Route index element={<Dashboard />} />

          {/* Coupon Management - 相对路径，匹配 /admin/coupons */}
          <Route path="coupons" element={<CouponManagement />} />

          {/* User Management */}
          <Route path="users" element={<UserManagement />} />

          {/* Expert Management */}
          <Route path="experts" element={<ExpertManagement />} />

          {/* Dispute Management */}
          <Route path="disputes" element={<DisputeManagement />} />

          {/* Refund Management */}
          <Route path="refunds" element={<RefundManagement />} />

          {/* Notification Management */}
          <Route path="notifications" element={<NotificationManagement />} />

          {/* Invitation Management */}
          <Route path="invitations" element={<InvitationManagement />} />

          {/* Forum Management */}
          <Route path="forum" element={<ForumManagement />} />

          {/* Flea Market Management */}
          <Route path="flea-market" element={<FleaMarketManagement />} />

          {/* Leaderboard Management */}
          <Route path="leaderboard" element={<LeaderboardManagement />} />

          {/* Banner Management */}
          <Route path="banners" element={<BannerManagement />} />

          {/* Report Management */}
          <Route path="reports" element={<ReportManagement />} />

          {/* Settings */}
          <Route path="settings" element={<Settings />} />

          {/* Catch all - redirect to dashboard */}
          <Route path="*" element={<Navigate to="/admin" replace />} />
        </Routes>
      </Suspense>
    </AdminLayout>
  );
};

export default AdminRoutes;
