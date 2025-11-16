import React, { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { fetchCurrentUser } from '../api';
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
    // ⚠️ 使用ReturnType<typeof setTimeout>，避免浏览器环境类型不匹配
    let timeoutId: ReturnType<typeof setTimeout> | null = null;
    
    const checkAuth = async () => {
      try {
        // 设置超时，防止请求一直挂起
        const timeoutPromise = new Promise((_, reject) => {
          timeoutId = setTimeout(() => {
            reject(new Error('认证检查超时'));
          }, 10000); // 10秒超时
        });

        // ⚠️ 使用fetchCurrentUser，利用缓存机制
        const response = await Promise.race([
          fetchCurrentUser().finally(() => {
            // ⚠️ 请求完成时清理定时器
            if (timeoutId) {
              clearTimeout(timeoutId);
              timeoutId = null;
            }
          }),
          timeoutPromise
        ]) as any;
        
        // ⚠️ 清理定时器
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
        
        // ⚠️ isMounted守卫，避免在卸载组件上setState
        if (isMounted) {
          setIsAuthenticated(true);
          setLoading(false);
        }
      } catch (error: any) {
        // ⚠️ 清理定时器
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
        
        if (!isMounted) return;
        
        // 超时后的UX处理
        if (error.message === '认证检查超时') {
          // 选项1：显示骨架屏，允许用户继续使用（如果之前已认证）
          // 选项2：跳转登录页
          // 选项3：显示离线模式提示
          console.warn('Auth check timeout, using cached state');
          // 这里可以根据业务需求选择策略
        }
        
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