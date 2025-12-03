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
        // 直接使用API验证，不需要检测Cookie
        // 后端会自动验证HttpOnly Cookie
        const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        const response = await fetch(`${API_BASE_URL}/api/auth/service/profile`, {
          credentials: 'include'
        });
        
        if (response.ok) {
          const service = await response.json();
          setIsAuthorized(true);
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

    // 直接检查认证，不需要延迟
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
    // 无权限，重定向到客服登录页面
    return <Navigate to="/en/customer-service/login" replace />;
  }

  // 有权限，显示子组件
  return <>{children}</>;
};

export default CustomerServiceRoute;
