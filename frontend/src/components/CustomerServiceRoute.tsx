import React, { useState, useEffect } from 'react';
import { Navigate } from 'react-router-dom';
import api from '../api';

interface CustomerServiceRouteProps {
  children: React.ReactNode;
}

const CustomerServiceRoute: React.FC<CustomerServiceRouteProps> = ({ children }) => {
  const [isAuthorized, setIsAuthorized] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        // 首先检查是否有客服Cookie标识
        const hasServiceCookie = document.cookie.includes('service_authenticated=true');
        
        if (!hasServiceCookie) {
          console.log('没有检测到客服Cookie标识，直接设置为未授权');
          setIsAuthorized(false);
          setLoading(false);
          return;
        }

        // 使用客服认证路由检查权限
        const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        const response = await fetch(`${API_BASE_URL}/api/auth/service/profile`, {
          credentials: 'include'
        });
        
        if (response.ok) {
          const service = await response.json();
          setIsAuthorized(true);
          console.log('客服访问客服管理页面:', service.id);
        } else {
          setIsAuthorized(false);
          console.warn('客服认证失败:', response.status);
        }
      } catch (error) {
        // 认证失败
        setIsAuthorized(false);
        console.error('客服认证检查失败:', error);
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  if (loading) {
    // 显示加载状态
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        fontSize: '16px',
        color: '#666'
      }}>
        验证权限中...
      </div>
    );
  }

  if (!isAuthorized) {
    // 无权限，重定向到客服登录页面
    return <Navigate to="/customer-service/login" replace />;
  }

  // 有权限，显示子组件
  return <>{children}</>;
};

export default CustomerServiceRoute;
