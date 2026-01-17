import React, { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { Spin } from 'antd';
import { API_BASE_URL, API_ENDPOINTS } from '../config';

interface AdminRouteProps {
  children: React.ReactNode;
}

/**
 * 管理员路由守卫
 * 检查用户是否已登录并具有管理员权限
 */
const AdminRoute: React.FC<AdminRouteProps> = ({ children }) => {
  const [isAuthorized, setIsAuthorized] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.ADMIN_PROFILE}`, {
          credentials: 'include',
          headers: {
            'Content-Type': 'application/json',
          }
        });
        
        if (response.ok) {
          setIsAuthorized(true);
        } else {
          setIsAuthorized(false);
        }
      } catch (error) {
        console.error('认证检查失败:', error);
        setIsAuthorized(false);
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  // 加载中
  if (loading || isAuthorized === null) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        background: '#f0f2f5'
      }}>
        <Spin size="large" tip="验证权限中..." />
      </div>
    );
  }

  // 未授权，重定向到登录页
  if (!isAuthorized) {
    return <Navigate to="/login" replace />;
  }

  // 已授权，显示子组件
  return <>{children}</>;
};

export default AdminRoute;
