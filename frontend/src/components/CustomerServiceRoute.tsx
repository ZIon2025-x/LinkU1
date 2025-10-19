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
    const checkAuth = async (retryCount = 0) => {
      try {
        // 更精确的Cookie检测
        const serviceAuthMatch = document.cookie.match(/service_authenticated=([^;]+)/);
        const serviceSessionMatch = document.cookie.match(/service_session_id=([^;]+)/);
        
        console.log(`客服路由认证检查 (尝试 ${retryCount + 1}):`);
        console.log('- service_authenticated:', serviceAuthMatch ? serviceAuthMatch[1] : '未找到');
        console.log('- service_session_id:', serviceSessionMatch ? '存在' : '未找到');
        
        // 检查是否有客服Cookie标识
        const hasServiceCookie = serviceAuthMatch && serviceAuthMatch[1] === 'true';
        const hasSessionCookie = !!serviceSessionMatch;
        
        if (!hasServiceCookie || !hasSessionCookie) {
          // 如果Cookie不完整且还有重试次数，则重试
          if (retryCount < 3) {
            console.log(`客服Cookie不完整，${500}ms后重试...`);
            setTimeout(() => checkAuth(retryCount + 1), 500);
            return;
          } else {
            console.log('客服Cookie不完整，重试次数用完，设置为未授权');
            setIsAuthorized(false);
            setLoading(false);
            return;
          }
        }

        // 使用客服认证路由检查权限
        const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        const response = await fetch(`${API_BASE_URL}/api/auth/service/profile`, {
          credentials: 'include'
        });
        
        if (response.ok) {
          const service = await response.json();
          setIsAuthorized(true);
          console.log('客服认证成功，访问客服管理页面:', service.id);
        } else {
          setIsAuthorized(false);
          console.warn('客服认证失败:', response.status, response.statusText);
        }
      } catch (error) {
        // 认证失败
        setIsAuthorized(false);
        console.error('客服认证检查失败:', error);
      } finally {
        setLoading(false);
      }
    };

    // 稍微延迟检查，确保Cookie已设置
    const timer = setTimeout(() => checkAuth(0), 100);
    return () => clearTimeout(timer);
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
