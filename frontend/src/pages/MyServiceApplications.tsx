/**
 * 用户服务申请管理页面
 * 路径: /users/me/service-applications
 * 功能: 查看和管理用户提交的服务申请
 */

import React, { useState, useEffect } from 'react';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import {
  fetchCurrentUser,
  getMyServiceApplications,
  respondToCounterOffer,
  cancelServiceApplication,
  getPublicSystemSettings,
  logout,
} from '../api';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import SEOHead from '../components/SEOHead';

interface ServiceApplication {
  id: number;
  service_id: number;
  service_name: string;
  expert_id: string;
  expert_name?: string;
  status: string;
  application_message?: string;
  negotiated_price?: number;
  expert_counter_price?: number;
  final_price?: number;
  currency?: string;
  task_id?: number;
  created_at: string;
  updated_at: string;
}

const MyServiceApplications: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [user, setUser] = useState<any>(null);
  const [applications, setApplications] = useState<ServiceApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>('all');
  
  // 通知相关状态
  const [notifications, setNotifications] = useState<any[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 登录弹窗状态
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    if (user) {
      loadApplications();
    }
  }, [user, statusFilter]);

  const loadData = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
      
      // 加载系统设置
      try {
        const settings = await getPublicSystemSettings();
        setSystemSettings(settings);
      } catch (error) {
              }
    } catch (err: any) {
      if (err.response?.status === 401) {
        setShowLoginModal(true);
      }
    } finally {
      setLoading(false);
    }
  };

  const loadApplications = async () => {
    if (!user) return;
    
    setLoading(true);
    try {
      const params: any = { limit: 50, offset: 0 };
      if (statusFilter !== 'all') {
        params.status = statusFilter;
      }
      const data = await getMyServiceApplications(params);
      setApplications(Array.isArray(data) ? data : (data.items || []));
    } catch (err: any) {
      message.error('加载申请列表失败');
          } finally {
      setLoading(false);
    }
  };

  const handleRespondToCounterOffer = async (applicationId: number, accept: boolean) => {
    try {
      await respondToCounterOffer(applicationId, accept);
      message.success(accept ? '已同意议价' : '已拒绝议价');
      loadApplications();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '操作失败');
    }
  };

  const handleCancelApplication = async (applicationId: number) => {
    if (!window.confirm('确定要取消这个申请吗？')) {
      return;
    }
    
    try {
      await cancelServiceApplication(applicationId);
      message.success('申请已取消');
      loadApplications();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '取消申请失败');
    }
  };

  const getStatusText = (status: string) => {
    const statusMap: { [key: string]: string } = {
      pending: '待处理',
      negotiating: '议价中',
      price_agreed: '价格已达成',
      approved: '已同意',
      rejected: '已拒绝',
      cancelled: '已取消',
    };
    return statusMap[status] || status;
  };

  const getStatusColor = (status: string) => {
    const colorMap: { [key: string]: string } = {
      pending: '#f59e0b',
      negotiating: '#3b82f6',
      price_agreed: '#10b981',
      approved: '#10b981',
      rejected: '#ef4444',
      cancelled: '#6b7280',
    };
    return colorMap[status] || '#6b7280';
  };

  if (loading && !user) {
    return (
      <div style={{ textAlign: 'center', padding: '60px', fontSize: '18px' }}>
        加载中...
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', background: '#f7fafc' }}>
      <SEOHead 
        title="我的服务申请"
        description="查看和管理您提交的服务申请"
      />
      
      {/* 顶部导航栏 */}
      <header style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        background: '#fff',
        zIndex: 100,
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          height: 60,
          maxWidth: 1200,
          margin: '0 auto',
          padding: '0 24px'
        }}>
          <div
            onClick={() => navigate('/')}
            style={{
              fontWeight: 'bold',
              fontSize: 24,
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer'
            }}
          >
            Link²Ur
          </div>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
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

      {/* 占位，防止内容被导航栏遮挡 */}
      <div style={{ height: 60 }} />

      {/* 通知弹窗 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={async (id) => {
          // 标记已读逻辑
        }}
        onMarkAllRead={async () => {
          // 标记全部已读逻辑
        }}
      />

      <div style={{
        maxWidth: '1200px',
        margin: '0 auto',
        padding: '20px'
      }}>
        {/* 页面标题 */}
        <div style={{
          background: '#fff',
          borderRadius: '12px',
          padding: '24px',
          marginBottom: '24px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
        }}>
          <h1 style={{ margin: 0, fontSize: '24px', fontWeight: 600, color: '#1a202c' }}>
            我的服务申请
          </h1>
        </div>

        {/* 状态筛选 */}
        <div style={{
          background: '#fff',
          borderRadius: '12px',
          padding: '16px',
          marginBottom: '24px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
        }}>
          <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
            {['all', 'pending', 'negotiating', 'price_agreed', 'approved', 'rejected'].map((status) => (
              <button
                key={status}
                onClick={() => setStatusFilter(status)}
                style={{
                  padding: '8px 16px',
                  background: statusFilter === status ? '#3b82f6' : '#f3f4f6',
                  color: statusFilter === status ? '#fff' : '#333',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                {status === 'all' ? '全部' : getStatusText(status)}
              </button>
            ))}
          </div>
        </div>

        {/* 申请列表 */}
        <div style={{
          background: '#fff',
          borderRadius: '12px',
          padding: '24px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
        }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
          ) : applications.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
              暂无申请记录
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {applications.map((app) => (
                <div
                  key={app.id}
                  style={{
                    border: '1px solid #e2e8f0',
                    borderRadius: '12px',
                    padding: '20px',
                    background: '#fff',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '12px' }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: '18px', fontWeight: 600, color: '#1a202c', marginBottom: '4px' }}>
                        {app.service_name}
                      </div>
                      <div style={{ fontSize: '14px', color: '#718096' }}>
                        任务达人: {app.expert_name || app.expert_id}
                      </div>
                    </div>
                    <span
                      style={{
                        padding: '6px 12px',
                        borderRadius: '6px',
                        fontSize: '12px',
                        fontWeight: 600,
                        background: getStatusColor(app.status) + '20',
                        color: getStatusColor(app.status),
                      }}
                    >
                      {getStatusText(app.status)}
                    </span>
                  </div>

                  {app.application_message && (
                    <div style={{
                      fontSize: '14px',
                      color: '#4a5568',
                      marginBottom: '12px',
                      padding: '12px',
                      background: '#f7fafc',
                      borderRadius: '8px'
                    }}>
                      {app.application_message}
                    </div>
                  )}

                  <div style={{ display: 'flex', gap: '16px', marginBottom: '12px', fontSize: '14px', color: '#718096', flexWrap: 'wrap' }}>
                    {app.negotiated_price && (
                      <span>我的议价: {app.currency || 'GBP'} {app.negotiated_price.toFixed(2)}</span>
                    )}
                    {app.expert_counter_price && (
                      <span>任务达人议价: {app.currency || 'GBP'} {app.expert_counter_price.toFixed(2)}</span>
                    )}
                    {app.final_price && (
                      <span>最终价格: {app.currency || 'GBP'} {app.final_price.toFixed(2)}</span>
                    )}
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ fontSize: '12px', color: '#999' }}>
                      {new Date(app.created_at).toLocaleString('zh-CN')}
                    </div>
                    
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      {app.status === 'negotiating' && (
                        <>
                          <button
                            onClick={() => handleRespondToCounterOffer(app.id, true)}
                            style={{
                              padding: '8px 16px',
                              background: '#10b981',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            同意议价
                          </button>
                          <button
                            onClick={() => handleRespondToCounterOffer(app.id, false)}
                            style={{
                              padding: '8px 16px',
                              background: '#ef4444',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            拒绝议价
                          </button>
                        </>
                      )}
                      {app.status === 'approved' && app.task_id && (
                        <button
                          onClick={() => navigate(`/tasks/${app.task_id}`)}
                          style={{
                            padding: '8px 16px',
                            background: '#3b82f6',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: 600,
                          }}
                        >
                          查看任务
                        </button>
                      )}
                      {(app.status === 'pending' || app.status === 'negotiating') && (
                        <button
                          onClick={() => handleCancelApplication(app.id)}
                          style={{
                            padding: '8px 16px',
                            background: '#f3f4f6',
                            color: '#333',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: 600,
                          }}
                        >
                          取消申请
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
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
    </div>
  );
};

export default MyServiceApplications;

