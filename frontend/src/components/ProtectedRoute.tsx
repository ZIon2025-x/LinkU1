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
    const checkAuth = async () => {
      try {
        console.log('ProtectedRoute: 开始检查认证状态...');
        // 直接尝试获取用户信息，HttpOnly Cookie会自动发送
        const response = await api.get('/api/users/profile/me');
        console.log('ProtectedRoute: 用户认证成功:', response.data);
        setIsAuthenticated(true);
      } catch (error: any) {
        // 认证失败，用户未登录
        console.log('ProtectedRoute: 用户未登录或认证失败:', error);
        console.log('ProtectedRoute: 错误详情:', error.response?.status, error.response?.data);
        setIsAuthenticated(false);
      } finally {
        console.log('ProtectedRoute: 认证检查完成，设置loading为false');
        setLoading(false);
      }
    };

    // 添加短暂延迟，确保页面完全加载后再检查认证状态
    const timer = setTimeout(checkAuth, 50);
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
        验证登录状态中...
      </div>
    );
  }

  if (!isAuthenticated) {
    // 未登录，直接显示登录弹窗
    console.log('ProtectedRoute: 用户未认证，显示登录弹窗');
    return (
      <LoginModal 
        isOpen={true}
        onClose={() => {
          console.log('ProtectedRoute: 用户关闭登录弹窗，重定向到首页');
          // 关闭弹窗时重定向到首页
          window.location.href = '/';
        }}
        onSuccess={() => {
          console.log('ProtectedRoute: 用户登录成功，重新加载页面');
          window.location.reload();
        }}
        onReopen={() => {
          console.log('ProtectedRoute: 重新打开登录弹窗');
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