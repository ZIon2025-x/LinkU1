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
        // 更精确的Cookie检测 - 支持跨域Cookie
        const serviceAuthMatch = document.cookie.match(/service_authenticated=([^;]+)/);
        const serviceSessionMatch = document.cookie.match(/service_session_id=([^;]+)/);
        const serviceIdMatch = document.cookie.match(/service_id=([^;]+)/);
        
        // 调试：检查所有包含service的Cookie
        const allServiceCookies = document.cookie.split(';').filter(cookie => 
          cookie.trim().toLowerCase().includes('service')
        );
        console.log('所有service相关Cookie:', allServiceCookies);
        
        console.log(`客服路由认证检查 (尝试 ${retryCount + 1}):`);
        console.log('- 所有Cookie:', document.cookie);
        console.log('- service_authenticated:', serviceAuthMatch ? serviceAuthMatch[1] : '未找到');
        console.log('- service_session_id:', serviceSessionMatch ? '存在' : '未找到 (HttpOnly Cookie，前端无法访问)');
        console.log('- service_id:', serviceIdMatch ? serviceIdMatch[1] : '未找到');
        
        // 检查是否有客服Cookie标识
        const hasServiceCookie = serviceAuthMatch && serviceAuthMatch[1] === 'true';
        const hasServiceId = !!serviceIdMatch;
        
        // 注意：service_session_id是HttpOnly Cookie，前端无法检测
        // 我们只需要检查service_authenticated和service_id即可
        if (!hasServiceCookie || !hasServiceId) {
          if (retryCount < 2) { // 只重试2次
            console.log(`客服Cookie不完整，${300}ms后重试... (${retryCount + 1}/2)`);
            setTimeout(() => checkAuth(retryCount + 1), 300);
            return;
          } else {
            console.log('客服Cookie不完整，直接尝试API验证');
            // 即使Cookie检测失败，也尝试直接调用API验证
            // 这可能是因为Cookie设置延迟或跨域问题
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
    return <Navigate to="/en/customer-service/login" replace />;
  }

  // 有权限，显示子组件
  return <>{children}</>;
};

export default CustomerServiceRoute;
