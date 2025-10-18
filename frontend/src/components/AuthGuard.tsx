import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth, AuthRole } from '../hooks/useAuth';

interface AuthGuardProps {
  children: React.ReactNode;
  requiredRole?: AuthRole;
  allowedRoles?: AuthRole[];
  redirectTo?: string;
}

const AuthGuard: React.FC<AuthGuardProps> = ({
  children,
  requiredRole,
  allowedRoles,
  redirectTo = '/login'
}) => {
  const { isAuthenticated, role, loading } = useAuth();
  const location = useLocation();

  // 如果正在加载，显示加载状态
  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        fontSize: '18px'
      }}>
        检查认证状态中...
      </div>
    );
  }

  // 如果未认证，重定向到登录页
  if (!isAuthenticated) {
    return <Navigate to={redirectTo} state={{ from: location }} replace />;
  }

  // 如果指定了特定角色要求
  if (requiredRole && role !== requiredRole) {
    // 根据当前角色重定向到相应的登录页
    let loginPath = '/login';
    switch (role) {
      case 'admin':
        loginPath = '/admin/login';
        break;
      case 'service':
        loginPath = '/service/login';
        break;
      case 'user':
        loginPath = '/login';
        break;
    }
    return <Navigate to={loginPath} replace />;
  }

  // 如果指定了允许的角色列表
  if (allowedRoles && role && !allowedRoles.includes(role)) {
    // 根据当前角色重定向到相应的登录页
    let loginPath = '/login';
    switch (role) {
      case 'admin':
        loginPath = '/admin/login';
        break;
      case 'service':
        loginPath = '/service/login';
        break;
      case 'user':
        loginPath = '/login';
        break;
    }
    return <Navigate to={loginPath} replace />;
  }

  return <>{children}</>;
};

// 管理员专用保护组件
export const AdminGuard: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AuthGuard requiredRole="admin" redirectTo="/admin/login">
    {children}
  </AuthGuard>
);

// 客服专用保护组件
export const ServiceGuard: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AuthGuard requiredRole="service" redirectTo="/service/login">
    {children}
  </AuthGuard>
);

// 用户专用保护组件
export const UserGuard: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AuthGuard requiredRole="user" redirectTo="/login">
    {children}
  </AuthGuard>
);

// 多角色保护组件
export const MultiRoleGuard: React.FC<{ 
  children: React.ReactNode;
  allowedRoles: AuthRole[];
  redirectTo?: string;
}> = ({ children, allowedRoles, redirectTo }) => (
  <AuthGuard allowedRoles={allowedRoles} redirectTo={redirectTo}>
    {children}
  </AuthGuard>
);

export default AuthGuard;
