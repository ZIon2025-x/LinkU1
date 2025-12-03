import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Spin, Empty, Typography, Space, Tag, Button, Avatar, Pagination } from 'antd';
import { 
  MessageOutlined, LikeOutlined, StarOutlined, PushpinOutlined,
  UserOutlined, ClockCircleOutlined, CheckOutlined, CheckCircleOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { 
  getForumNotifications, markForumNotificationRead, markAllForumNotificationsRead,
  getForumUnreadNotificationCount, fetchCurrentUser, getPublicSystemSettings, logout
} from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import { message } from 'antd';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { formatRelativeTime } from '../utils/timeUtils';
import styles from './ForumNotifications.module.css';

const { Title, Text } = Typography;

interface ForumNotification {
  id: number;
  notification_type: 'reply_post' | 'reply_reply' | 'like_post' | 'feature_post' | 'pin_post';
  target_type: 'post' | 'reply';
  target_id: number;
  from_user: {
    id: string;
    name: string;
    avatar?: string;
  } | null;
  is_read: boolean;
  created_at: string;
}

const ForumNotifications: React.FC = () => {
  const { lang: langParam } = useParams<{ lang: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const { user: currentUser } = useCurrentUser();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  // 确保 lang 有值，防止路由错误
  const lang = langParam || language || 'zh';
  
  const [notifications, setNotifications] = useState<ForumNotification[]>([]);
  const [loading, setLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [unreadCount, setUnreadCount] = useState(0);
  const [pageSize] = useState(20);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [filter, setFilter] = useState<'all' | 'unread'>('all');
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });

  useEffect(() => {
    if (!currentUser) {
      setShowLoginModal(true);
    } else {
      loadNotifications();
      loadUnreadCount();
    }
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error: any) {
        setUser(null);
      }
    };
    loadUserData();
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
  }, [currentPage, filter, currentUser]);

  const loadNotifications = async () => {
    if (!currentUser) return;
    
    try {
      setLoading(true);
      const params: any = {
        page: currentPage,
        page_size: pageSize
      };
      if (filter === 'unread') {
        params.is_read = false;
      }
      const response = await getForumNotifications(params);
      setNotifications(response.notifications || []);
      setTotal(response.total || 0);
    } catch (error: any) {
            message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setLoading(false);
    }
  };

  const loadUnreadCount = async () => {
    if (!currentUser) return;
    
    try {
      const response = await getForumUnreadNotificationCount();
      setUnreadCount(response.unread_count || 0);
    } catch (error: any) {
          }
  };

  const handleMarkRead = async (notificationId: number) => {
    try {
      await markForumNotificationRead(notificationId);
      loadNotifications();
      loadUnreadCount();
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleMarkAllRead = async () => {
    try {
      await markAllForumNotificationsRead();
      message.success(t('forum.markAllReadSuccess'));
      loadNotifications();
      loadUnreadCount();
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleNotificationClick = async (notification: ForumNotification) => {
    if (!notification.is_read) {
      await handleMarkRead(notification.id);
    }
    navigate(`/${lang}/forum/post/${notification.target_id}`);
  };

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'reply_post':
      case 'reply_reply':
        return <MessageOutlined />;
      case 'like_post':
        return <LikeOutlined />;
      case 'feature_post':
        return <StarOutlined />;
      case 'pin_post':
        return <PushpinOutlined />;
      default:
        return <UserOutlined />;
    }
  };

  const getNotificationText = (notification: ForumNotification) => {
    const userName = notification.from_user?.name || t('forum.user');
    switch (notification.notification_type) {
      case 'reply_post':
        return t('forum.notificationReplyPost', { userName });
      case 'reply_reply':
        return t('forum.notificationReplyReply', { userName });
      case 'like_post':
        return t('forum.notificationLikePost', { userName });
      case 'feature_post':
        return t('forum.notificationFeaturePost', { userName });
      case 'pin_post':
        return t('forum.notificationPinPost', { userName });
      default:
        return '';
    }
  };

  if (!currentUser) {
    return (
      <div className={styles.container}>
        <header className={styles.header}>
          <div className={styles.headerContainer}>
            <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
              Link²Ur
            </div>
            <div className={styles.headerActions}>
              <LanguageSwitcher />
              <NotificationButton 
                user={user}
                unreadCount={unreadCount}
                onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
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
                unreadCount={messageUnreadCount}
              />
            </div>
          </div>
        </header>
        <div className={styles.headerSpacer} />
        <LoginModal
          isOpen={showLoginModal}
          onClose={() => {
            setShowLoginModal(false);
            navigate(`/${lang}/forum`);
          }}
        />
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <SEOHead 
        title={t('forum.notifications')}
        description={t('forum.description')}
      />
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
            Link²Ur
          </div>
          <div className={styles.headerActions}>
            <LanguageSwitcher />
            <NotificationButton 
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
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
              unreadCount={messageUnreadCount}
            />
          </div>
        </div>
      </header>
      <div className={styles.headerSpacer} />

      <div className={styles.content}>
        <Card>
          <div className={styles.toolbar}>
            <Space>
              <Button
                type={filter === 'all' ? 'primary' : 'default'}
                onClick={() => {
                  setFilter('all');
                  setCurrentPage(1);
                }}
              >
                {t('forum.all')}
              </Button>
              <Button
                type={filter === 'unread' ? 'primary' : 'default'}
                onClick={() => {
                  setFilter('unread');
                  setCurrentPage(1);
                }}
              >
                {t('forum.unreadCount')} {unreadCount > 0 && `(${unreadCount})`}
              </Button>
            </Space>
            {unreadCount > 0 && (
              <Button
                type="default"
                icon={<CheckCircleOutlined />}
                onClick={handleMarkAllRead}
              >
                {t('forum.markAllRead')}
              </Button>
            )}
          </div>

          {loading ? (
            <div className={styles.loadingContainer}>
              <Spin size="large" />
            </div>
          ) : notifications.length === 0 ? (
            <Empty description={t('forum.noNotifications')} />
          ) : (
            <>
              <div className={styles.notificationsList}>
                {notifications.map((notification) => (
                  <Card
                    key={notification.id}
                    className={`${styles.notificationCard} ${!notification.is_read ? styles.unread : ''}`}
                    hoverable
                    onClick={() => handleNotificationClick(notification)}
                  >
                    <div className={styles.notificationHeader}>
                      <Space>
                        <Avatar
                          src={notification.from_user?.avatar}
                          icon={<UserOutlined />}
                          size="small"
                        />
                        <div className={styles.notificationContent}>
                          <Text strong={!notification.is_read}>
                            {getNotificationIcon(notification.notification_type)}
                            {' '}
                            {getNotificationText(notification)}
                          </Text>
                          <div className={styles.notificationMeta}>
                            <Text type="secondary" style={{ fontSize: 12 }}>
                              <ClockCircleOutlined /> {formatRelativeTime(notification.created_at)}
                            </Text>
                          </div>
                        </div>
                      </Space>
                      {!notification.is_read && (
                        <Button
                          type="text"
                          size="small"
                          icon={<CheckOutlined />}
                          onClick={(e) => {
                            e.stopPropagation();
                            handleMarkRead(notification.id);
                          }}
                        >
                          {t('forum.markAsRead')}
                        </Button>
                      )}
                    </div>
                  </Card>
                ))}
              </div>
              {total > pageSize && (
                <div className={styles.pagination}>
                  <Pagination
                    current={currentPage}
                    total={total}
                    pageSize={pageSize}
                    onChange={(page) => setCurrentPage(page)}
                  />
                </div>
              )}
            </>
          )}
        </Card>
      </div>
    </div>
  );
};

export default ForumNotifications;

