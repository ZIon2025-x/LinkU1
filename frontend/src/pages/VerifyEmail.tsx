import React, { useEffect, useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { Card, Spin, Alert, Button } from 'antd';
import styled from 'styled-components';
import api, { fetchCurrentUser, getUnreadNotificationCount, getNotificationsWithRecentRead, markNotificationRead, markAllNotificationsRead, logout, getPublicSystemSettings, getNotifications } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';

const Wrapper = styled.div`
  min-height: 80vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f9f9f9;
  padding-top: 60px;
`;

const StyledCard = styled(Card)`
  width: 500px;
  text-align: center;
  box-shadow: 0 2px 8px #f0f1f2;
`;

const SuccessIcon = styled.div`
  font-size: 64px;
  color: #52c41a;
  margin-bottom: 16px;
`;

const ErrorIcon = styled.div`
  font-size: 64px;
  color: #ff4d4f;
  margin-bottom: 16px;
`;

const VerifyEmail: React.FC = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState<'success' | 'error' | 'loading'>('loading');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
  // 导航栏相关状态
  const [user, setUser] = useState<any>(null);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });

  useEffect(() => {
    const verifyEmail = async () => {
      const token = searchParams.get('token');
      const success = searchParams.get('success');
      const error = searchParams.get('error');
      
      // 如果已经有success参数，说明后端已经验证成功并重定向回来
      if (success === 'true' || success === '1') {
        console.log('邮箱验证成功，显示成功页面');
        setStatus('success');
        setMessage(t('auth.verificationSuccess') || '邮箱验证成功！您现在可以正常使用平台了。');
        setLoading(false);
        return;
      }
      
      // 如果有error参数，说明后端验证失败并重定向回来
      if (error) {
        console.log('邮箱验证失败:', error);
        setStatus('error');
        setError(decodeURIComponent(error));
        setLoading(false);
        return;
      }
      
      // 如果有token，调用API验证（兼容旧的方式）
      if (token) {
        try {
          const response = await api.get(`/api/users/verify-email?token=${token}`);
          setStatus('success');
          setMessage(response.data.message);
        } catch (err: any) {
          setStatus('error');
          setError(err.response?.data?.detail || t('auth.verificationFailed'));
        } finally {
          setLoading(false);
        }
      } else {
        // 没有token也没有其他参数，显示错误
        setStatus('error');
        setError(t('auth.verificationFailed') || '缺少验证令牌');
        setLoading(false);
      }
    };

    verifyEmail();
  }, [searchParams, t]);

  // 加载用户数据和通知
  useEffect(() => {
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (err) {
        // 用户未登录，忽略错误
        setUser(null);
      }
    };

    // 加载系统设置
    const loadSystemSettings = async () => {
      try {
        const settings = await getPublicSystemSettings();
        setSystemSettings(settings);
      } catch (err) {
        console.error('加载系统设置失败:', err);
        setSystemSettings({ vip_button_visible: false });
      }
    };

    loadUserData();
    loadSystemSettings();
  }, []);

  // 加载通知数据
  useEffect(() => {
    if (user) {
      // 获取通知列表 - 获取所有未读通知和最近10条已读通知
      getNotificationsWithRecentRead(10).then(notifications => {
        setNotifications(notifications);
      }).catch(error => {
        console.error('获取通知失败:', error);
        // 如果获取失败，获取最近的通知
        getNotifications(20).then(notifications => {
          setNotifications(notifications);
        }).catch(error => {
          console.error('获取通知失败:', error);
        });
      });
      
      // 获取未读数量
      getUnreadNotificationCount().then(count => {
        setUnreadCount(count);
      }).catch(error => {
        console.error('获取未读数量失败:', error);
      });
    }
  }, [user]);

  // 定期更新未读通知数量
  useEffect(() => {
    if (user) {
      const interval = setInterval(() => {
        // 只在页面可见时才更新
        if (!document.hidden) {
          getUnreadNotificationCount().then(count => {
            setUnreadCount(count);
          }).catch(error => {
            console.error('定期更新未读数量失败:', error);
          });
        }
      }, 30000); // 每30秒更新一次
      return () => clearInterval(interval);
    }
  }, [user]);

  // 处理通知标记为已读
  const handleMarkAsRead = async (id: number) => {
    try {
      await markNotificationRead(id);
      
      // 更新本地状态，标记为已读
      setNotifications(prev => 
        prev.map(n => n.id === id ? { ...n, is_read: 1 } : n)
      );
      
      // 更新未读数量
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch (error) {
      console.error('标记通知为已读失败:', error);
    }
  };

  // 处理标记所有通知为已读
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setUnreadCount(0);
      // 更新通知列表，标记所有为已读
      setNotifications(prev => prev.map(n => ({ ...n, is_read: 1 })));
    } catch (error) {
      console.error('标记所有通知为已读失败:', error);
    }
  };

  const handleGoToLogin = () => {
    setShowLoginModal(true);
  };

  const handleGoToRegister = () => {
    setShowLoginModal(true);
  };

  if (loading) {
    return (
      <>
        {/* 顶部导航栏 */}
        <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
          <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
            {/* Logo */}
            <div style={{fontWeight: 'bold', fontSize: 24, background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent'}}>Link²Ur</div>
            
            {/* 语言切换器、通知按钮和汉堡菜单 */}
            <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
              <LanguageSwitcher />
              <NotificationButton
                user={user}
                unreadCount={unreadCount}
                onNotificationClick={() => setShowNotifications(prev => !prev)}
              />
              <HamburgerMenu
                user={user}
                onLogout={async () => {
                  try {
                    await logout();
                  } catch (error) {
                  }
                  window.location.reload();
                }}
                onLoginClick={() => setShowLoginModal(true)}
                systemSettings={systemSettings}
              />
            </div>
          </div>
        </header>
        
        {/* 通知弹窗 */}
        <NotificationPanel
          isOpen={showNotifications && !!user}
          onClose={() => setShowNotifications(false)}
          notifications={notifications}
          unreadCount={unreadCount}
          onMarkAsRead={handleMarkAsRead}
          onMarkAllRead={handleMarkAllRead}
        />
        
        <Wrapper>
          {/* SEO优化：可见的H1标签 */}
          <h1 style={{ 
            position: 'absolute',
            top: '-100px',
            left: '-100px',
            width: '1px',
            height: '1px',
            padding: '0',
            margin: '0',
            overflow: 'hidden',
            clip: 'rect(0, 0, 0, 0)',
            whiteSpace: 'nowrap',
            border: '0',
            fontSize: '1px',
            color: 'transparent',
            background: 'transparent'
          }}>
            邮箱验证 - Link²Ur
          </h1>
          <StyledCard>
            <Spin size="large" />
            <div style={{ marginTop: 16, fontSize: 16 }}>{t('common.loading')}</div>
          </StyledCard>
        </Wrapper>
      </>
    );
  }

  return (
    <>
      {/* 顶部导航栏 */}
      <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          {/* Logo */}
          <div style={{fontWeight: 'bold', fontSize: 24, background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent'}}>Link²Ur</div>
          
          {/* 语言切换器、通知按钮和汉堡菜单 */}
          <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
            <LanguageSwitcher />
            <NotificationButton
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => setShowNotifications(prev => !prev)}
            />
            <HamburgerMenu
              user={user}
              onLogout={async () => {
                try {
                  await logout();
                } catch (error) {
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>
      
      {/* 通知弹窗 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />
      
      <Wrapper>
      {/* SEO优化：可见的H1标签 */}
      <h1 style={{ 
        position: 'absolute',
        top: '-100px',
        left: '-100px',
        width: '1px',
        height: '1px',
        padding: '0',
        margin: '0',
        overflow: 'hidden',
        clip: 'rect(0, 0, 0, 0)',
        whiteSpace: 'nowrap',
        border: '0',
        fontSize: '1px',
        color: 'transparent',
        background: 'transparent'
      }}>
        邮箱验证 - Link²Ur
      </h1>
      <StyledCard>
        {status === 'success' ? (
          <>
            <SuccessIcon>✅</SuccessIcon>
            <h2 style={{ color: '#52c41a', marginBottom: 16 }}>{t('auth.verificationSuccess')}</h2>
            <p style={{ fontSize: 16, marginBottom: 24, color: '#666' }}>
              {message}
            </p>
            <Button type="primary" size="large" onClick={handleGoToLogin}>
              {t('common.login')}
            </Button>
          </>
        ) : (
          <>
            <ErrorIcon>❌</ErrorIcon>
            <h2 style={{ color: '#ff4d4f', marginBottom: 16 }}>{t('auth.verificationFailed')}</h2>
            <Alert
              message={error}
              type="error"
              showIcon
              style={{ marginBottom: 24, textAlign: 'left' }}
            />
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <Button onClick={handleGoToRegister}>
                {t('common.register')}
              </Button>
              <Button type="primary" onClick={handleGoToLogin}>
                {t('common.login')}
              </Button>
            </div>
          </>
        )}
      </StyledCard>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => setShowForgotPasswordModal(true)}
        onHideForgotPassword={() => setShowForgotPasswordModal(false)}
      />
      </Wrapper>
    </>
  );
};

export default VerifyEmail;
