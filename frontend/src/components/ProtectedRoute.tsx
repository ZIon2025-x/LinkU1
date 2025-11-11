import React, { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import api from '../api';
import LoginModal from './LoginModal';

interface ProtectedRouteProps {
  children: React.ReactNode;
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  useEffect(() => {
    let isMounted = true;
    let timeoutId: NodeJS.Timeout;
    
    const checkAuth = async () => {
      try {
        // 设置超时，防止请求一直挂起
        const timeoutPromise = new Promise((_, reject) => {
          timeoutId = setTimeout(() => {
            reject(new Error('认证检查超时'));
          }, 10000); // 10秒超时
        });

        // 直接尝试获取用户信息，HttpOnly Cookie会自动发送
        const response = await Promise.race([
          api.get('/api/users/profile/me'),
          timeoutPromise
        ]) as any;
        
        if (isMounted) {
          setIsAuthenticated(true);
          setLoading(false);
        }
      } catch (error: any) {
        if (!isMounted) return;
        
        // 认证失败，用户未登录（401是预期的，不需要显示错误）
        // 只在非401错误时才记录（比如网络错误）
        if (error.response?.status !== 401 && error.message !== '认证检查超时') {
          console.debug('ProtectedRoute 认证检查失败（非401）:', error);
        }
        setIsAuthenticated(false);
        setLoading(false);
      }
    };

    // 添加短暂延迟，确保页面完全加载后再检查认证状态
    const timer = setTimeout(checkAuth, 50);
    
    return () => {
      isMounted = false;
      clearTimeout(timer);
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    };
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
        验证登录状态中...
      </div>
    );
  }

  if (!isAuthenticated) {
    // 未登录，直接显示登录弹窗
    return (
      <LoginModal 
        isOpen={true}
        onClose={() => {
          // 关闭弹窗时重定向到首页
          window.location.href = '/';
        }}
        onSuccess={() => {
          window.location.reload();
        }}
        onReopen={() => {
          setShowLoginModal(true);
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => {
          setShowForgotPasswordModal(true);
        }}
        onHideForgotPassword={() => {
          setShowForgotPasswordModal(false);
        }}
      />
    );
  }

  // 已登录，显示子组件
  return <>{children}</>;
};

export default ProtectedRoute; 