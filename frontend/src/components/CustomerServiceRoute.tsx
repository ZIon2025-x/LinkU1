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
        // 使用Cookie认证检查用户信息
        const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        const response = await fetch(`${API_BASE_URL}/api/users/profile/me`, {
          credentials: 'include'
        });
        
        if (response.ok) {
          const user = await response.json();
          
          // 只有通过客服登录系统登录的用户才能访问客服管理界面
          if (user.user_type === 'customer_service') {
            setIsAuthorized(true);
            console.log('客服访问客服管理页面:', user.id);
          } else {
            setIsAuthorized(false);
            console.warn('非客服用户尝试访问客服管理页面:', user.user_type);
          }
        } else {
          setIsAuthorized(false);
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
