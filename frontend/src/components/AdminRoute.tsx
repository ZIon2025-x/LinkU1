import React, { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import api from '../api';

interface AdminRouteProps {
  children: React.ReactNode;
}

const AdminRoute: React.FC<AdminRouteProps> = ({ children }) => {
  const [isAuthorized, setIsAuthorized] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        // 使用管理员专用端点检查管理员权限
        const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        const response = await fetch(`${API_BASE_URL}/api/auth/admin/profile`, {
          credentials: 'include'
        });
        
        if (response.ok) {
          const admin = await response.json();
          setIsAuthorized(true);
          console.log('管理员访问管理后台:', admin.id);
        } else {
          setIsAuthorized(false);
          console.warn('管理员认证失败:', response.status);
        }
      } catch (error) {
        // 认证失败
        setIsAuthorized(false);
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  // 在认证完成前，不显示任何内容
  if (loading || isAuthorized === null) {
    // 显示加载状态
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        fontSize: '16px',
        color: '#666',
        background: '#f5f5f5'
      }}>
        验证权限中...
      </div>
    );
  }

  if (!isAuthorized) {
    // 无权限，重定向到后台管理员登录页面
    return <Navigate to="/admin/login" replace />;
  }

  // 有权限，显示子组件
  return <>{children}</>;
};

export default AdminRoute;
