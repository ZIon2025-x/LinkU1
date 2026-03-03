import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  RocketOutlined,
  TeamOutlined,
  TrophyOutlined,
  ThunderboltOutlined,
  StarOutlined,
  GlobalOutlined,
  ShopOutlined,
  SmileOutlined,
} from '@ant-design/icons';
import { fetchCurrentUser, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead } from '../api';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import SEOHead from '../components/SEOHead';
import { useLanguage } from '../contexts/LanguageContext';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import styles from './Milestones.module.css';

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
}

interface MilestoneEvent {
  date: string;
  icon: React.ReactNode;
  iconBg: string;
  titleEn: string;
  titleZh: string;
  descriptionEn: string;
  descriptionZh: string;
}

const milestoneEvents: MilestoneEvent[] = [
  {
    date: '2024.09',
    icon: <RocketOutlined />,
    iconBg: '#3b82f6',
    titleEn: 'Link²Ur Founded',
    titleZh: 'Link²Ur 正式成立',
    descriptionEn: 'A group of passionate young people came together to build a skill-exchange platform, officially starting our journey.',
    descriptionZh: '一群志同道合的年轻人汇聚在一起，创建技能互助平台，正式开启我们的旅程。',
  },
  {
    date: '2024.12',
    icon: <ThunderboltOutlined />,
    iconBg: '#f59e0b',
    titleEn: 'Platform Beta Launch',
    titleZh: '平台内测上线',
    descriptionEn: 'The first version of the platform went live for beta testing, receiving enthusiastic feedback from early users.',
    descriptionZh: '平台第一个版本正式上线内测，获得了首批用户的热情反馈。',
  },
  {
    date: '2025.02',
    icon: <TeamOutlined />,
    iconBg: '#10b981',
    titleEn: '100+ Registered Users',
    titleZh: '注册用户突破 100+',
    descriptionEn: 'Within months of launch, the platform reached over 100 registered users, validating our community-first approach.',
    descriptionZh: '上线短短几个月，平台注册用户突破100人，验证了我们以社区为核心的理念。',
  },
  {
    date: '2025.04',
    icon: <ShopOutlined />,
    iconBg: '#8b5cf6',
    titleEn: 'Flea Market Feature Launched',
    titleZh: '跳蚤市场功能上线',
    descriptionEn: 'Expanded beyond task matching with a community marketplace, allowing users to buy and sell items.',
    descriptionZh: '平台功能扩展至社区二手交易，支持用户买卖闲置物品。',
  },
  {
    date: '2025.06',
    icon: <StarOutlined />,
    iconBg: '#ec4899',
    titleEn: 'First Community Event in London',
    titleZh: '伦敦首场线下社区活动',
    descriptionEn: 'Organized our first offline meetup in London, bringing together community members for networking and fun.',
    descriptionZh: '在伦敦举办首次线下见面会，社区成员齐聚一堂，交流互动。',
  },
  {
    date: '2025.09',
    icon: <SmileOutlined />,
    iconBg: '#06b6d4',
    titleEn: 'AI Customer Service Introduced',
    titleZh: 'AI智能客服上线',
    descriptionEn: 'Launched AI-powered customer support to provide instant, 24/7 assistance to our growing user base.',
    descriptionZh: '推出AI智能客服系统，为日益增长的用户群体提供全天候即时服务。',
  },
  {
    date: '2025.12',
    icon: <TrophyOutlined />,
    iconBg: '#f97316',
    titleEn: '500+ Tasks Completed',
    titleZh: '完成任务突破 500+',
    descriptionEn: 'A milestone moment — over 500 tasks successfully matched and completed through our platform.',
    descriptionZh: '里程碑时刻——平台成功匹配并完成超过500个任务。',
  },
  {
    date: '2026.03',
    icon: <GlobalOutlined />,
    iconBg: '#6366f1',
    titleEn: 'Expanding to More Cities',
    titleZh: '拓展至更多城市',
    descriptionEn: 'Continuing to grow our reach, connecting skilled individuals in more cities across the UK and beyond.',
    descriptionZh: '持续扩大覆盖范围，连接英国及更多城市的技能人才。',
  },
];

const statsData = [
  { numberEn: '100+', numberZh: '100+', labelEn: 'Registered Users', labelZh: '注册用户' },
  { numberEn: '500+', numberZh: '500+', labelEn: 'Tasks Completed', labelZh: '完成任务' },
  { numberEn: '5+', numberZh: '5+', labelEn: 'Cities Covered', labelZh: '覆盖城市' },
  { numberEn: '97%', numberZh: '97%', labelEn: 'User Satisfaction', labelZh: '用户满意度' },
];

const Milestones: React.FC = () => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  const [user, setUser] = useState<any>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [systemSettings] = useState({});
  const timelineRefs = useRef<(HTMLDivElement | null)[]>([]);

  const isZh = language === 'zh';

  useEffect(() => {
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
        if (userData) {
          try {
            const [notificationsData, unreadCountData] = await Promise.all([
              getNotificationsWithRecentRead(10),
              getUnreadNotificationCount()
            ]);
            setNotifications(notificationsData);
            setUnreadCount(unreadCountData.unread_count);
          } catch { /* ignore */ }
        }
      } catch {
        setUser(null);
      }
    };
    loadUserData();
  }, []);

  // IntersectionObserver for scroll animations
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add(styles.visible || 'visible');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15 }
    );

    timelineRefs.current.forEach((ref) => {
      if (ref) observer.observe(ref);
    });

    return () => observer.disconnect();
  }, []);

  const setTimelineRef = useCallback((index: number) => (el: HTMLDivElement | null) => {
    timelineRefs.current[index] = el;
  }, []);

  const handleMarkAsRead = async (notificationId: number) => {
    try {
      await markNotificationRead(notificationId);
      setNotifications(prev =>
        prev.map(n => n.id === notificationId ? { ...n, is_read: 1 } : n)
      );
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch {
      alert(t('notificationPanel.markAsReadFailed'));
    }
  };

  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setNotifications(prev => prev.map(n => ({ ...n, is_read: 1 })));
      setUnreadCount(0);
    } catch {
      alert(t('notificationPanel.markAllReadFailed'));
    }
  };

  return (
    <div className={styles.page}>
      <SEOHead
        title={isZh ? '发展历程 - Link²Ur' : 'Our Journey - Link²Ur'}
        description={isZh ? 'Link²Ur的发展历程与里程碑事件' : "Link²Ur's journey and milestones"}
      />

      {/* Header */}
      <header style={{ position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px' }}>
          <div
            style={{
              fontWeight: 'bold',
              fontSize: 24,
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer',
              padding: '4px 8px',
              borderRadius: '8px',
              flexShrink: 0,
            }}
            onClick={() => navigate('/')}
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
              onLogout={async () => { window.location.reload(); }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
              unreadCount={messageUnreadCount}
            />
          </div>
        </div>
      </header>
      <div style={{ height: 60 }} />

      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />

      {/* Hero Banner */}
      <section className={styles.hero}>
        <div className={styles.heroContent}>
          <h1 className={styles.heroTitle}>
            {isZh ? '我们的历程' : 'Our Journey'}
          </h1>
          <p className={styles.heroSubtitle}>
            {isZh
              ? '从一个想法到连接无数人的平台，每一步都承载着我们的热情与坚持。'
              : 'From an idea to a platform connecting people, every step carries our passion and perseverance.'}
          </p>
        </div>
      </section>

      {/* Timeline */}
      <section className={styles.timelineSection}>
        <h2 className={styles.sectionTitle}>
          {isZh ? '发展里程碑' : 'Milestones'}
        </h2>
        <div className={styles.timeline}>
          {milestoneEvents.map((event, index) => (
            <div
              key={index}
              ref={setTimelineRef(index)}
              className={`${styles.timelineItem} ${index % 2 === 0 ? styles.timelineItemLeft : styles.timelineItemRight}`}
            >
              <div className={styles.timelineDot} />
              <div className={styles.timelineCard}>
                <div className={styles.cardIcon} style={{ background: event.iconBg }}>
                  {event.icon}
                </div>
                <div className={styles.cardDate}>{event.date}</div>
                <div className={styles.cardTitle}>
                  {isZh ? event.titleZh : event.titleEn}
                </div>
                <p className={styles.cardDescription}>
                  {isZh ? event.descriptionZh : event.descriptionEn}
                </p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Stats */}
      <section className={styles.statsSection}>
        <h2 className={styles.sectionTitle}>
          {isZh ? '数据一览' : 'By the Numbers'}
        </h2>
        <div className={styles.statsGrid}>
          {statsData.map((stat, index) => (
            <div key={index} className={styles.statItem}>
              <div className={styles.statNumber}>
                {isZh ? stat.numberZh : stat.numberEn}
              </div>
              <div className={styles.statLabel}>
                {isZh ? stat.labelZh : stat.labelEn}
              </div>
            </div>
          ))}
        </div>
      </section>

      <Footer />

      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
      />
    </div>
  );
};

export default Milestones;
