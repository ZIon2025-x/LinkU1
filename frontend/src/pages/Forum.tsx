import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Spin, Empty, Typography, Space, Tag, Button } from 'antd';
import { 
  MessageOutlined, EyeOutlined, ClockCircleOutlined, UserOutlined,
  SearchOutlined, TrophyOutlined, FileTextOutlined, PlusOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { getVisibleForums, fetchCurrentUser, getPublicSystemSettings, logout } from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { formatRelativeTime } from '../utils/timeUtils';
import styles from './Forum.module.css';

const { Title, Text } = Typography;

interface ForumCategory {
  id: number;
  name: string;
  description?: string;
  icon?: string;
  post_count: number;
  last_post_at?: string;
  latest_post?: {
    id: number;
    title: string;
    author: {
      id: string;
      name: string;
      avatar?: string;
    };
    last_reply_at: string;
    reply_count: number;
    view_count: number;
  } | null;
}

const Forum: React.FC = () => {
  const { lang: langParam } = useParams<{ lang: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const { user: currentUser } = useCurrentUser();
  
  // 确保 lang 有值，防止路由错误
  const lang = langParam || language || 'zh';
  
  const [categories, setCategories] = useState<ForumCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount, setUnreadCount] = useState(0);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const { unreadCount: messageUnreadCount } = useUnreadMessages();

  useEffect(() => {
    loadCategories();
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
  }, [currentUser]); // 当用户登录/退出时刷新板块列表

  const loadCategories = async () => {
    try {
      setLoading(true);
      // 使用新的可见板块接口，自动根据用户身份返回可见板块
      const response = await getVisibleForums(false);
      const categoriesData = response.categories || [];
      
      setCategories(categoriesData);
    } catch (error: any) {
      // API失败时设置为空数组，显示"暂无板块"提示
      // 如果是权限错误（404），也显示空数组（隐藏学校板块存在性）
      console.error('加载板块列表失败:', error);
      setCategories([]);
    } finally {
      setLoading(false);
    }
  };

  const handleCategoryClick = (categoryId: number) => {
    navigate(`/${lang}/forum/category/${categoryId}`);
  };

  if (loading) {
    return (
      <div className={styles.container}>
        <header className={styles.header}>
          <div className={styles.headerContainer}>
            <div className={styles.logo}>Link²Ur</div>
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
        <div className={styles.loadingContainer}>
          <Spin size="large" />
        </div>
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <SEOHead 
        title={t('forum.title')}
        description={t('forum.description')}
      />
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          <div className={styles.logo} onClick={() => navigate(`/${lang}`)} style={{ cursor: 'pointer' }}>
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
        <div className={styles.pageHeader}>
          <Title level={2} className={styles.pageTitle}>
            {t('forum.title')}
          </Title>
          <div className={styles.navigationButtons}>
            <Button
              type="default"
              icon={<SearchOutlined />}
              onClick={() => navigate(`/${lang}/forum/search`)}
              className={styles.navButton}
            >
              {t('forum.search')}
            </Button>
            <Button
              type="default"
              icon={<TrophyOutlined />}
              onClick={() => navigate(`/${lang}/forum/leaderboard`)}
              className={styles.navButton}
            >
              {t('forum.leaderboard')}
            </Button>
            {currentUser && (
              <>
                <Button
                  type="default"
                  icon={<FileTextOutlined />}
                  onClick={() => navigate(`/${lang}/forum/my`)}
                  className={styles.navButton}
                >
                  {t('forum.myContent')}
                </Button>
                <Button
                  type="primary"
                  icon={<PlusOutlined />}
                  onClick={() => navigate(`/${lang}/forum/create`)}
                  className={styles.navButton}
                >
                  {t('forum.createPost')}
                </Button>
              </>
            )}
          </div>
        </div>
        {categories.length === 0 ? (
          <Empty description={t('forum.noCategories')} />
        ) : (
          <div className={styles.categoriesGrid}>
            {categories.map((category) => (
              <Card
                key={category.id}
                className={styles.categoryCard}
                hoverable
                onClick={() => handleCategoryClick(category.id)}
              >
                <div className={styles.categoryHeader}>
                  <Title level={4} className={styles.categoryName}>
                    {category.icon && <span className={styles.categoryIcon}>{category.icon}</span>}
                    {category.name}
                  </Title>
                  <Tag color="blue">{category.post_count} {t('forum.posts')}</Tag>
                </div>
                
                {category.description && (
                  <Text type="secondary" className={styles.categoryDescription}>
                    {category.description}
                  </Text>
                )}

                {category.latest_post && (
                  <div className={styles.latestPost}>
                    <div className={styles.latestPostTitle}>
                      <MessageOutlined /> {category.latest_post.title}
                    </div>
                    <div className={styles.latestPostMeta}>
                      <Space size="small" split="|">
                        {category.latest_post.author && (
                          <span>
                            <UserOutlined /> {category.latest_post.author.name}
                          </span>
                        )}
                        <span>
                          <ClockCircleOutlined /> {formatRelativeTime(category.latest_post.last_reply_at)}
                        </span>
                        <span>
                          <MessageOutlined /> {category.latest_post.reply_count}
                        </span>
                        <span>
                          <EyeOutlined /> {category.latest_post.view_count}
                        </span>
                      </Space>
                    </div>
                  </div>
                )}

                {!category.latest_post && category.post_count === 0 && (
                  <Text type="secondary" className={styles.noPosts}>
                    {t('forum.noPosts')}
                  </Text>
                )}
              </Card>
            ))}
          </div>
        )}
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

export default Forum;

