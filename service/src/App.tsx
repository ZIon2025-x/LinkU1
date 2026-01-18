import React, { Suspense, lazy } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Spin } from 'antd';
import CustomerServiceRoute from './components/CustomerServiceRoute';

// 懒加载页面组件
const CustomerServiceLogin = lazy(() => import('./pages/CustomerServiceLogin'));
const CustomerService = lazy(() => import('./pages/CustomerService'));

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
          <Route path="/login" element={<CustomerServiceLogin />} />
          
          {/* 客服管理主页 - 需要认证 */}
          <Route path="/" element={
            <CustomerServiceRoute>
              <CustomerService />
            </CustomerServiceRoute>
          } />
          
          {/* 其他路由重定向到首页 */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </Router>
  );
};

export default App;
