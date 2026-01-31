import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Tabs, Spin, Empty, Avatar, Select } from 'antd';
import { 
  TrophyOutlined, UserOutlined, MessageOutlined, LikeOutlined,
  StarOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { getForumLeaderboard, fetchCurrentUser, getPublicSystemSettings, logout } from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import CustomLeaderboardsTab from '../components/CustomLeaderboardsTab';
import styles from './ForumLeaderboard.module.css';

const { TabPane } = Tabs;
const { Option } = Select;

interface LeaderboardUser {
  user: {
    id: string;
    name: string;
    avatar?: string;
  };
  count: number;
  rank: number;
}

const ForumLeaderboard: React.FC = () => {
  const { lang: langParam } = useParams<{ lang: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  
  // 确保 lang 有值，防止路由错误
  const lang = langParam || language || 'zh';
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [activeTab, setActiveTab] = useState<'posts' | 'favorites' | 'likes' | 'custom'>('posts');
  const [period, setPeriod] = useState<'all' | 'today' | 'week' | 'month'>('all');
  const [users, setUsers] = useState<LeaderboardUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount] = useState(0);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  useEffect(() => {
    // 只在非custom tab时加载论坛排行榜数据
    if (activeTab !== 'custom') {
      loadLeaderboard();
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
  }, [activeTab, period]);

  const loadLeaderboard = async () => {
    // 只在非custom tab时加载论坛排行榜数据
    if (activeTab === 'custom') {
      return;
    }
    try {
      setLoading(true);
      const response = await getForumLeaderboard(activeTab as 'posts' | 'favorites' | 'likes', {
        period,
        limit: 50
      });
      setUsers(response.users || []);
    } catch (error: any) {
          } finally {
      setLoading(false);
    }
  };

  const renderLeaderboardContent = () => {
    if (loading) {
      return (
        <div className={styles.loadingContainer}>
          <Spin size="large" />
        </div>
      );
    }

    if (users.length === 0) {
      return <Empty description={t('forum.noData')} />;
    }

    const topThree = users.slice(0, 3);
    const restUsers = users.slice(3);

    return (
      <>
        {/* 领奖台 - 前三名 */}
        {topThree.length > 0 && (
          <div className={styles.podiumContainer}>
            {/* 第二名 */}
            {topThree[1] && (
              <div 
                className={`${styles.podiumItem} ${styles.podium2}`}
                onClick={() => navigate(`/${lang}/user/${topThree[1]!.user.id}`)}
              >
                <Avatar
                  src={topThree[1].user.avatar}
                  icon={<UserOutlined />}
                  size={80}
                  className={styles.podiumAvatar}
                />
                <div className={styles.podiumName}>{topThree[1].user.name}</div>
                <div className={styles.podiumCount}>{topThree[1].count}</div>
                <div className={styles.podiumBase}>
                  <span style={{ fontSize: '32px' }}>🥈</span>
                </div>
              </div>
            )}
            
            {/* 第一名 */}
            {topThree[0] && (
              <div 
                className={`${styles.podiumItem} ${styles.podium1}`}
                onClick={() => navigate(`/${lang}/user/${topThree[0]!.user.id}`)}
              >
                <Avatar
                  src={topThree[0].user.avatar}
                  icon={<UserOutlined />}
                  size={100}
                  className={styles.podiumAvatar}
                />
                <div className={styles.podiumName}>{topThree[0].user.name}</div>
                <div className={styles.podiumCount}>{topThree[0].count}</div>
                <div className={styles.podiumBase}>
                  <span style={{ fontSize: '32px' }}>🥇</span>
                </div>
              </div>
            )}
            
            {/* 第三名 */}
            {topThree[2] && (
              <div 
                className={`${styles.podiumItem} ${styles.podium3}`}
                onClick={() => navigate(`/${lang}/user/${topThree[2]!.user.id}`)}
              >
                <Avatar
                  src={topThree[2].user.avatar}
                  icon={<UserOutlined />}
                  size={80}
                  className={styles.podiumAvatar}
                />
                <div className={styles.podiumName}>{topThree[2].user.name}</div>
                <div className={styles.podiumCount}>{topThree[2].count}</div>
                <div className={styles.podiumBase}>
                  <span style={{ fontSize: '32px' }}>🥉</span>
                </div>
              </div>
            )}
          </div>
        )}

        {/* 其余用户列表 */}
        {restUsers.length > 0 && (
          <div className={styles.listAfterPodium}>
            {restUsers.map((item) => (
              <div
                key={item.user.id}
                className={styles.listItem}
                onClick={() => navigate(`/${lang}/user/${item.user.id}`)}
              >
                <div className={styles.listRank}>{item.rank}</div>
                <Avatar
                  src={item.user.avatar}
                  icon={<UserOutlined />}
                  size={40}
                  className={styles.listAvatar}
                />
                <div className={styles.listInfo}>
                  <div className={styles.listName}>{item.user.name}</div>
                </div>
                <div className={styles.listCount}>{item.count}</div>
              </div>
            ))}
          </div>
        )}
      </>
    );
  };

  const getTabIcon = (type: string) => {
    switch (type) {
      case 'posts':
        return <MessageOutlined />;
      case 'favorites':
        return <StarOutlined />;
      case 'likes':
        return <LikeOutlined />;
      default:
        return null;
    }
  };

  return (
    <div className={styles.container}>
      <SEOHead 
        title={t('forum.leaderboard')}
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
            {/* ⚠️ 重要：自定义排行榜不使用时间周期筛选，只在论坛排行榜时显示 */}
            {activeTab !== 'custom' && (
              <Select
                value={period}
                onChange={setPeriod}
                style={{ width: 150 }}
              >
                <Option value="all">{t('forum.periodAll')}</Option>
                <Option value="today">{t('forum.periodToday')}</Option>
                <Option value="week">{t('forum.periodWeek')}</Option>
                <Option value="month">{t('forum.periodMonth')}</Option>
              </Select>
            )}
          </div>

          <Tabs activeKey={activeTab} onChange={(key) => setActiveTab(key as any)}>
            <TabPane 
              tab={
                <span>
                  {getTabIcon('posts')} {t('forum.leaderboardPosts')}
                </span>
              } 
              key="posts"
            >
              {renderLeaderboardContent()}
            </TabPane>

            <TabPane 
              tab={
                <span>
                  {getTabIcon('favorites')} {t('forum.leaderboardFavorites')}
                </span>
              } 
              key="favorites"
            >
              {renderLeaderboardContent()}
            </TabPane>

            <TabPane 
              tab={
                <span>
                  {getTabIcon('likes')} {t('forum.leaderboardLikes')}
                </span>
              } 
              key="likes"
            >
              {renderLeaderboardContent()}
            </TabPane>

            <TabPane 
              tab={
                <span>
                  <TrophyOutlined /> {t('forum.customLeaderboard')}
                </span>
              } 
              key="custom"
            >
              <CustomLeaderboardsTab onShowLogin={() => setShowLoginModal(true)} />
            </TabPane>
          </Tabs>
        </Card>
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

export default ForumLeaderboard;

