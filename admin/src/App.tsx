import React, { Suspense, lazy } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Spin } from 'antd';
import AdminRoute from './components/AdminRoute';
import { AdminRoutes } from './routes/adminRoutes';

// 懒加载页面组件
const AdminLogin = lazy(() => import('./pages/AdminLogin'));
const AdminDashboard = lazy(() => import('./pages/AdminDashboard'));

// 加载中占位组件
const LoadingFallback: React.FC = () => (
  <div style={{
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    height: '100vh',
    background: '#f0f2f5'
  }}>
    <Spin size="large" tip="加载中..." />
  </div>
);

const App: React.FC = () => {
  return (
    <Router>
      <Suspense fallback={<LoadingFallback />}>
        <Routes>
          {/* 登录页 */}
          <Route path="/login" element={<AdminLogin />} />

          {/* Admin 子路由 - 需要认证 */}
          <Route path="/admin/*" element={
            <AdminRoute>
              <AdminRoutes />
            </AdminRoute>
          } />

          {/* 旧的管理后台主页保留作为后备（可选） */}
          <Route path="/legacy" element={
            <AdminRoute>
              <AdminDashboard />
            </AdminRoute>
          } />

          {/* 根路径重定向到 admin */}
          <Route path="/" element={<Navigate to="/admin" replace />} />

          {/* 其他路由重定向到 admin */}
          <Route path="*" element={<Navigate to="/admin" replace />} />
        </Routes>
      </Suspense>
    </Router>
  );
};

export default App;
