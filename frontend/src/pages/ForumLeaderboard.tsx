import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Tabs, Spin, Empty, Typography, Space, Tag, Button, Avatar, Select } from 'antd';
import { 
  TrophyOutlined, UserOutlined, MessageOutlined, LikeOutlined,
  FireOutlined, StarOutlined, ClockCircleOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { getForumLeaderboard, fetchCurrentUser, getPublicSystemSettings, logout } from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import SEOHead from '../components/SEOHead';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import styles from './ForumLeaderboard.module.css';

const { Title, Text } = Typography;
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
  
  const [activeTab, setActiveTab] = useState<'posts' | 'replies' | 'likes'>('posts');
  const [period, setPeriod] = useState<'all' | 'today' | 'week' | 'month'>('all');
  const [users, setUsers] = useState<LeaderboardUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    loadLeaderboard();
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
    try {
      setLoading(true);
      const response = await getForumLeaderboard(activeTab, {
        period,
        limit: 50
      });
      setUsers(response.users || []);
    } catch (error: any) {
      console.error('加载排行榜失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const getRankIcon = (rank: number) => {
    if (rank === 1) return <TrophyOutlined style={{ color: '#FFD700' }} />;
    if (rank === 2) return <TrophyOutlined style={{ color: '#C0C0C0' }} />;
    if (rank === 3) return <TrophyOutlined style={{ color: '#CD7F32' }} />;
    return <span className={styles.rankNumber}>{rank}</span>;
  };

  const getTabIcon = (type: string) => {
    switch (type) {
      case 'posts':
        return <MessageOutlined />;
      case 'replies':
        return <MessageOutlined />;
      case 'likes':
        return <LikeOutlined />;
      default:
        return null;
    }
  };

  const getTabTitle = (type: string) => {
    switch (type) {
      case 'posts':
        return t('forum.leaderboardPosts');
      case 'replies':
        return t('forum.leaderboardReplies');
      case 'likes':
        return t('forum.leaderboardLikes');
      default:
        return '';
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
              onLoginClick={() => {}}
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
              {loading ? (
                <div className={styles.loadingContainer}>
                  <Spin size="large" />
                </div>
              ) : users.length === 0 ? (
                <Empty description={t('forum.noData')} />
              ) : (
                <div className={styles.leaderboardList}>
                  {users.map((item, index) => (
                    <Card
                      key={item.user.id}
                      className={`${styles.leaderboardItem} ${index < 3 ? styles.topThree : ''}`}
                      hoverable
                      onClick={() => navigate(`/${lang}/user/${item.user.id}`)}
                    >
                      <div className={styles.rankSection}>
                        {getRankIcon(item.rank)}
                      </div>
                      <div className={styles.userSection}>
                        <Avatar
                          src={item.user.avatar}
                          icon={<UserOutlined />}
                          size="large"
                        />
                        <div className={styles.userInfo}>
                          <Text strong>{item.user.name}</Text>
                        </div>
                      </div>
                      <div className={styles.countSection}>
                        <Text strong style={{ fontSize: 18 }}>
                          {item.count}
                        </Text>
                        <Text type="secondary" style={{ fontSize: 12 }}>
                          {getTabTitle(activeTab)}
                        </Text>
                      </div>
                    </Card>
                  ))}
                </div>
              )}
            </TabPane>

            <TabPane 
              tab={
                <span>
                  {getTabIcon('replies')} {t('forum.leaderboardReplies')}
                </span>
              } 
              key="replies"
            >
              {loading ? (
                <div className={styles.loadingContainer}>
                  <Spin size="large" />
                </div>
              ) : users.length === 0 ? (
                <Empty description={t('forum.noData')} />
              ) : (
                <div className={styles.leaderboardList}>
                  {users.map((item, index) => (
                    <Card
                      key={item.user.id}
                      className={`${styles.leaderboardItem} ${index < 3 ? styles.topThree : ''}`}
                      hoverable
                      onClick={() => navigate(`/${lang}/user/${item.user.id}`)}
                    >
                      <div className={styles.rankSection}>
                        {getRankIcon(item.rank)}
                      </div>
                      <div className={styles.userSection}>
                        <Avatar
                          src={item.user.avatar}
                          icon={<UserOutlined />}
                          size="large"
                        />
                        <div className={styles.userInfo}>
                          <Text strong>{item.user.name}</Text>
                        </div>
                      </div>
                      <div className={styles.countSection}>
                        <Text strong style={{ fontSize: 18 }}>
                          {item.count}
                        </Text>
                        <Text type="secondary" style={{ fontSize: 12 }}>
                          {getTabTitle(activeTab)}
                        </Text>
                      </div>
                    </Card>
                  ))}
                </div>
              )}
            </TabPane>

            <TabPane 
              tab={
                <span>
                  {getTabIcon('likes')} {t('forum.leaderboardLikes')}
                </span>
              } 
              key="likes"
            >
              {loading ? (
                <div className={styles.loadingContainer}>
                  <Spin size="large" />
                </div>
              ) : users.length === 0 ? (
                <Empty description={t('forum.noData')} />
              ) : (
                <div className={styles.leaderboardList}>
                  {users.map((item, index) => (
                    <Card
                      key={item.user.id}
                      className={`${styles.leaderboardItem} ${index < 3 ? styles.topThree : ''}`}
                      hoverable
                      onClick={() => navigate(`/${lang}/user/${item.user.id}`)}
                    >
                      <div className={styles.rankSection}>
                        {getRankIcon(item.rank)}
                      </div>
                      <div className={styles.userSection}>
                        <Avatar
                          src={item.user.avatar}
                          icon={<UserOutlined />}
                          size="large"
                        />
                        <div className={styles.userInfo}>
                          <Text strong>{item.user.name}</Text>
                        </div>
                      </div>
                      <div className={styles.countSection}>
                        <Text strong style={{ fontSize: 18 }}>
                          {item.count}
                        </Text>
                        <Text type="secondary" style={{ fontSize: 12 }}>
                          {getTabTitle(activeTab)}
                        </Text>
                      </div>
                    </Card>
                  ))}
                </div>
              )}
            </TabPane>
          </Tabs>
        </Card>
      </div>
    </div>
  );
};

export default ForumLeaderboard;

