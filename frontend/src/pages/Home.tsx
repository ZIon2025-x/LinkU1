import React, { useEffect, useState, useLayoutEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { message } from 'antd';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, customerServiceLogout, getPublicSystemSettings, logout } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import TaskTitle from '../components/TaskTitle';
import Footer from '../components/Footer';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import SEOHead from '../components/SEOHead';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import styles from './Home.module.css';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

// 剩余时间计算函数 - 使用英国时间
function getRemainTime(deadline: string, t: (key: string) => string) {
  try {
    // Parse UTC time and convert to UK time
    let utcTime;
    if (deadline.endsWith('Z')) {
      utcTime = dayjs.utc(deadline);
    } else if (deadline.includes('T')) {
      utcTime = dayjs.utc(deadline + 'Z');
    } else {
      utcTime = dayjs.utc(deadline);
    }
    
    const nowUK = dayjs().tz('Europe/London');
    const endUK = utcTime.tz('Europe/London');
    const diff = endUK.diff(nowUK, 'minute');
    
    if (diff <= 0) return t('home.taskExpired');
    
    const days = Math.floor(diff / (24 * 60));
    const hours = Math.floor((diff % (24 * 60)) / 60);
    const minutes = diff % 60;
    
    // 优化时间显示格式
    if (days >= 30) {
      const months = Math.floor(days / 30);
      const remainingDays = days % 30;
      if (remainingDays > 0) {
        return `${months}个月 · ${remainingDays}天`;
      }
      return `${months}个月`;
    } else if (days > 0) {
      if (hours > 0) {
        return `${days}天 · ${hours}小时`;
      }
      return `${days}天`;
    } else if (hours > 0) {
      if (minutes > 0) {
        return `${hours}小时 · ${minutes}分钟`;
      }
      return `${hours}小时`;
    } else {
      return `${minutes}分钟`;
    }
  } catch (error) {
    console.error('Remaining time calculation error:', error);
    return t('home.taskExpired');
  }
}

// Check if task is expiring soon - using UK time
function isExpiringSoon(deadline: string) {
  try {
    // Parse UTC time and convert to UK time
    let utcTime;
    if (deadline.endsWith('Z')) {
      utcTime = dayjs.utc(deadline);
    } else if (deadline.includes('T')) {
      utcTime = dayjs.utc(deadline + 'Z');
    } else {
      utcTime = dayjs.utc(deadline);
    }
    
    const nowUK = dayjs().tz('Europe/London');
    const endUK = utcTime.tz('Europe/London');
    const twoHoursLater = nowUK.add(2, 'hour');
    
    return nowUK.isBefore(endUK) && endUK.isBefore(twoHoursLater);
  } catch (error) {
    console.error('Expiration check error:', error);
    return false;
  }
}

// Check if task has expired - using UK time
function isExpired(deadline: string) {
  try {
    // Parse UTC time and convert to UK time
    let utcTime;
    if (deadline.endsWith('Z')) {
      utcTime = dayjs.utc(deadline);
    } else if (deadline.includes('T')) {
      utcTime = dayjs.utc(deadline + 'Z');
    } else {
      utcTime = dayjs.utc(deadline);
    }
    
    const nowUK = dayjs().tz('Europe/London');
    const endUK = utcTime.tz('Europe/London');
    return nowUK.isAfter(endUK);
  } catch (error) {
    console.error('Expiration check error:', error);
    return true; // If parsing fails, assume expired
  }
}

// Add cute animation styles
const bellStyles = `
  @keyframes bellShake {
    0%, 100% { transform: rotate(0deg); }
    10%, 30%, 50%, 70%, 90% { transform: rotate(5deg); }
    20%, 40%, 60%, 80% { transform: rotate(-5deg); }
  }
  
  @keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.1); }
    100% { transform: scale(1); }
  }
  
  @keyframes bounce {
    0%, 20%, 50%, 80%, 100% { transform: translateY(0); }
    40% { transform: translateY(-3px); }
    60% { transform: translateY(-2px); }
  }
  
  @keyframes float {
    0% { transform: translateX(-50%) translateY(-50%) rotate(0deg); }
    100% { transform: translateX(-50%) translateY(-50%) rotate(360deg); }
  }
  
  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(30px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
`;

// Inject styles into page
if (typeof document !== 'undefined') {
  const styleElement = document.createElement('style');
  styleElement.textContent = bellStyles + `
    /* Responsive background styles */
    @media (max-width: 768px) {
      .hero-section {
        min-height: 100vh !important;
        padding: 40px 0 !important;
      }
      .hero-title {
        font-size: 32px !important;
        line-height: 1.3 !important;
      }
      .hero-subtitle {
        font-size: 16px !important;
      }
    }
    
    @media (max-width: 480px) {
      .hero-section {
        padding: 20px 0 !important;
      }
      .hero-title {
        font-size: 28px !important;
      }
    }
    
    /* Ensure background image perfect fit */
    .hero-section {
      background-attachment: fixed;
    }
    
    @media (max-width: 1024px) {
      .hero-section {
        background-attachment: scroll;
      }
    }
  `;
  document.head.appendChild(styleElement);
}

// TASK_TYPES will be defined inside the component to use translations
export const CITIES = [
  "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

interface Notification {
  id: number;
  type: string;
  title: string;
  content: string;
  related_id?: number;
  is_read: number;
  created_at: string;
}

const Home: React.FC = () => {
  const location = useLocation();
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  
  // 生成canonical URL - 确保包含语言前缀
  // 由于语言路由重定向，这里只会处理有语言前缀的路径（如 /en, /zh）
  // 确保每个语言版本指向自己的 URL
  const canonicalUrl = location.pathname.startsWith('/en') || location.pathname.startsWith('/zh')
    ? `https://www.link2ur.com${location.pathname}`
    : 'https://www.link2ur.com/en'; // 默认情况下指向英文版
  
  // Task types array - using translations
  const TASK_TYPES = [
    t('taskCategories.housekeeping'),
    t('taskCategories.campusLife'),
    t('taskCategories.secondHandRental'),
    t('taskCategories.errandRunning'),
    t('taskCategories.skillService'),
    t('taskCategories.socialHelp'),
    t('taskCategories.transportation'),
    t('taskCategories.petCare'),
    t('taskCategories.lifeConvenience'),
    t('taskCategories.other')
  ];
  
  // Debug related states
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  // User login and avatar logic
  const [user, setUser] = useState<any>(null);
  const [showMenu, setShowMenu] = useState(false);
  
  // Notification related states
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  
  // Message unread count from context
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  
  // System settings state
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // Login modal states
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
  // Task detail modal states
  const [showTaskDetailModal, setShowTaskDetailModal] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);
  
  useEffect(() => {
    const loadUserData = async () => {
      try {
        // Directly try to get user info, HttpOnly Cookie will be sent automatically
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error: any) {
        setUser(null);
      }
    };
    
    // Add short delay to ensure page is fully loaded before getting user data
    const timer = setTimeout(loadUserData, 100);
    
    // Load system settings
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
    
    return () => clearTimeout(timer);
  }, []);

  // Get notification data
  useEffect(() => {
    if (user) {
      // Get notification list - get all unread notifications and recent 10 read notifications
      getNotificationsWithRecentRead(10).then(notifications => {
        setNotifications(notifications);
      }).catch(error => {
        console.error('Failed to get notifications:', error);
        // If getting failed, get recent notifications
        getNotifications(20).then(notifications => {
          setNotifications(notifications);
        }).catch(error => {
          console.error('Failed to get notifications:', error);
        });
      });
      // Get unread count
      getUnreadNotificationCount().then(count => {
        setUnreadCount(count);
      }).catch(error => {
        console.error('Failed to get unread count:', error);
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

  // 当通知面板打开时，定期刷新通知列表
  useEffect(() => {
    if (showNotifications && user) {
      // 打开时立即刷新一次
      const loadNotificationsList = async () => {
        try {
          const notificationsData = await getNotificationsWithRecentRead(10);
          setNotifications(notificationsData);
        } catch (error) {
          console.error('刷新通知列表失败:', error);
        }
      };
      loadNotificationsList();
      
      // 每10秒刷新一次通知列表（比未读数量刷新更频繁）
      const interval = setInterval(() => {
        if (!document.hidden) {
          loadNotificationsList();
        }
      }, 10000);
      
      return () => clearInterval(interval);
    }
  }, [showNotifications, user]);

  // 获取任务数据 - 只显示赏金最高且最新的3个任务
  useEffect(() => {
    setLoading(true);
    fetchTasks({ type: 'all', city: 'all', keyword: '', page: 1, pageSize: 50 })
      .then(data => {
        const allTasks = Array.isArray(data) ? data : (data.tasks || []);
        
        // 按赏金从高到低排序，然后按创建时间从新到旧排序，取前3个
        const sortedTasks = allTasks
          .sort((a: any, b: any) => {
            // 首先按赏金排序（从高到低）
            const rewardA = parseFloat(a.reward) || 0;
            const rewardB = parseFloat(b.reward) || 0;
            if (rewardA !== rewardB) {
              return rewardB - rewardA;
            }
            // 如果赏金相同，按创建时间排序（从新到旧）
            return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
          })
          .slice(0, 3); // 只取前3个
        
        setTasks(sortedTasks);
      })
      .catch(error => {
        console.error('获取任务数据失败:', error);
        setTasks([]);
      })
      .finally(() => setLoading(false));
  }, []);

  // 定期刷新任务列表以更新剩余时间和状态
  useEffect(() => {
    const interval = setInterval(() => {
      if (tasks.length > 0) {
        // 重新获取任务数据以更新状态
        fetchTasks({ type: 'all', city: 'all', keyword: '', page: 1, pageSize: 50 })
          .then(data => {
            const allTasks = Array.isArray(data) ? data : (data.tasks || []);
            
            // 按赏金从高到低排序，然后按创建时间从新到旧排序，取前3个
            const sortedTasks = allTasks
              .sort((a: any, b: any) => {
                // 首先按赏金排序（从高到低）
                const rewardA = parseFloat(a.reward) || 0;
                const rewardB = parseFloat(b.reward) || 0;
                if (rewardA !== rewardB) {
                  return rewardB - rewardA;
                }
                // 如果赏金相同，按创建时间排序（从新到旧）
                return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
              })
              .slice(0, 3); // 只取前3个
            
            setTasks(sortedTasks);
          })
          .catch(error => {
            console.error('定期刷新任务列表失败:', error);
          });
      }
    }, 60000); // 每分钟更新一次
    return () => clearInterval(interval);
  }, [tasks.length]);

  // 处理通知点击 - 只标记为已读，不跳转
  const handleNotificationClick = async (notification: Notification) => {
    // 只标记通知为已读，不进行任何跳转
    await markNotificationRead(notification.id);
    
    // 更新本地状态，标记为已读
    setNotifications(prev => 
      prev.map(n => 
        n.id === notification.id ? { ...n, is_read: 1 } : n
      )
    );
    
    // 更新未读数量
    setUnreadCount(prev => Math.max(0, prev - 1));
    
    // 不关闭通知面板，让用户可以继续查看其他通知
  };

  // 处理单个通知标记为已读
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
      message.error('标记通知为已读失败，请重试');
    }
  };

  // 标记所有通知为已读
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setUnreadCount(0);
      // 更新通知列表，标记所有为已读
      setNotifications(prev => prev.map(n => ({ ...n, is_read: 1 })));
    } catch (error) {
      console.error('标记所有通知为已读失败:', error);
      message.error('标记所有通知为已读失败，请重试');
    }
  };



  // 点击外部关闭弹窗
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('.notification-panel') && !target.closest('.notification-btn') && !target.closest('.hamburger-menu')) {
        setShowNotifications(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // 使用useLayoutEffect确保在DOM渲染前就设置meta标签，优先级最高
  // 防止搜索引擎抓取到页面内容（如公告）作为描述
  useLayoutEffect(() => {
    // 检查是否是任务详情页，如果是则不设置meta标签（让任务详情页自己管理）
    const isTaskDetailPage = /\/tasks\/\d+/.test(location.pathname);
    if (isTaskDetailPage) {
      return; // 不设置meta标签，让任务详情页自己管理
    }
    
    // 强制更新meta description，确保在head最前面
    const description = t('home.metaDescription') || 'Link²Ur - Professional task publishing and skill matching platform, connecting skilled people with those who need help, making value creation more efficient.';
    
    // 移除所有旧的description标签（包括可能包含公告内容的标签）
    const allDescriptions = document.querySelectorAll('meta[name="description"]');
    allDescriptions.forEach(tag => {
      const metaTag = tag as HTMLMetaElement;
      // 特别检查并移除包含公告关键词的标签
      if (metaTag.content && (
        metaTag.content.includes('平台公告') || 
        metaTag.content.includes('测试阶段') || 
        metaTag.content.includes('support@link2ur.com') ||
        metaTag.content.includes('Platform Announcement') ||
        metaTag.content.includes('testing phase') ||
        metaTag.content.includes('2025-10-09')
      )) {
        metaTag.remove();
      } else {
        metaTag.remove(); // 移除所有，重新创建
      }
    });
    
    // 创建新的description标签并插入到head最前面
    const descTag = document.createElement('meta');
    descTag.name = 'description';
    descTag.content = description;
    document.head.insertBefore(descTag, document.head.firstChild);
    
    // 同样处理og:description
    const ogDescription = description;
    const allOgDescriptions = document.querySelectorAll('meta[property="og:description"]');
    allOgDescriptions.forEach(tag => {
      const metaTag = tag as HTMLMetaElement;
      // 特别检查并移除包含公告关键词的标签
      if (metaTag.content && (
        metaTag.content.includes('平台公告') || 
        metaTag.content.includes('测试阶段') || 
        metaTag.content.includes('support@link2ur.com') ||
        metaTag.content.includes('Platform Announcement') ||
        metaTag.content.includes('testing phase') ||
        metaTag.content.includes('2025-10-09')
      )) {
        metaTag.remove();
      } else {
        metaTag.remove(); // 移除所有，重新创建
      }
    });
    
    const ogDescTag = document.createElement('meta');
    ogDescTag.setAttribute('property', 'og:description');
    ogDescTag.content = ogDescription;
    document.head.insertBefore(ogDescTag, document.head.firstChild);
    
    // 同样处理微信分享描述
    const allWeixinDescriptions = document.querySelectorAll('meta[name="weixin:description"]');
    allWeixinDescriptions.forEach(tag => {
      const metaTag = tag as HTMLMetaElement;
      if (metaTag.content && (
        metaTag.content.includes('平台公告') || 
        metaTag.content.includes('测试阶段') || 
        metaTag.content.includes('support@link2ur.com') ||
        metaTag.content.includes('Platform Announcement') ||
        metaTag.content.includes('testing phase') ||
        metaTag.content.includes('2025-10-09')
      )) {
        metaTag.remove();
      } else {
        metaTag.remove();
      }
    });
    
    const weixinDescTag = document.createElement('meta');
    weixinDescTag.setAttribute('name', 'weixin:description');
    weixinDescTag.content = ogDescription;
    document.head.insertBefore(weixinDescTag, document.head.firstChild);
    
    // 使用setTimeout确保在DOM完全加载后再次检查并移除公告内容
    setTimeout(() => {
      // 再次检查并移除任何包含公告内容的meta标签
      const allMetaDescriptions = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="weixin:description"]');
      allMetaDescriptions.forEach(tag => {
        const metaTag = tag as HTMLMetaElement;
        if (metaTag.content && (
          metaTag.content.includes('平台公告') || 
          metaTag.content.includes('测试阶段') || 
          metaTag.content.includes('support@link2ur.com') ||
          metaTag.content.includes('Platform Announcement') ||
          metaTag.content.includes('testing phase') ||
          metaTag.content.includes('2025-10-09')
        )) {
          metaTag.remove();
        }
      });
      
      // 重新插入正确的描述
      const finalDescTag = document.createElement('meta');
      finalDescTag.name = 'description';
      finalDescTag.content = description;
      document.head.insertBefore(finalDescTag, document.head.firstChild);
      
      const finalOgDescTag = document.createElement('meta');
      finalOgDescTag.setAttribute('property', 'og:description');
      finalOgDescTag.content = ogDescription;
      document.head.insertBefore(finalOgDescTag, document.head.firstChild);
      
      const finalWeixinDescTag = document.createElement('meta');
      finalWeixinDescTag.setAttribute('name', 'weixin:description');
      finalWeixinDescTag.content = ogDescription;
      document.head.insertBefore(finalWeixinDescTag, document.head.firstChild);
    }, 100);
  }, [t]);

  return (
    <div>
      <SEOHead 
        title={t('home.pageTitle') || 'Link²Ur - Connect, Capability, Create'}
        description={t('home.metaDescription') || 'Link²Ur - Professional task publishing and skill matching platform, connecting skilled people with those who need help, making value creation more efficient.'}
        canonicalUrl={canonicalUrl}
        ogTitle={t('home.pageTitle') || 'Link²Ur - Connect, Capability, Create'}
        ogDescription={t('home.metaDescription') || 'Link²Ur - Professional task publishing and skill matching platform, connecting skilled people with those who need help, making value creation more efficient.'}
        ogImage="/static/favicon.png"
        ogUrl={canonicalUrl}
      />
      {/* 顶部导航栏 - 使用汉堡菜单 */}
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          {/* Logo */}
          <div className={styles.logo}>Link²Ur</div>
          
          {/* 语言切换器、通知按钮和汉堡菜单 */}
          <div className={styles.headerActions}>
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
              unreadCount={messageUnreadCount}
            />
          </div>
        </div>
      </header>
      {/* 占位，防止内容被导航栏遮挡 */}
      <div className={styles.headerSpacer} />
      
      {/* 通知弹窗 - 独立显示 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />
      
      {/* 英雄区域 - 重新设计 */}
      <section 
        className={styles.heroSection}
        style={{ backgroundImage: 'url(/static/background.jpg)' }}
      >
        {/* 背景遮罩层 */}
        <div className={styles.heroOverlay} />
        
        <div className={styles.heroContent}>
          {/* SEO 优化的主标题 - 使用 h1 作为页面主标题 */}
          <h1 className={styles.heroTitle}>
            {t('home.welcome')}
            <span className={styles.heroTitleHighlight}>
              {t('home.subtitle')}
            </span>
          </h1>
          
          <p className={styles.heroSubtitle}>
            {t('home.heroDescription')}
          </p>
          
          <div className={styles.heroButtons}>
            <button 
              onClick={() => navigate('/tasks')}
              className={styles.heroButton}
            >
              ✨ {t('navigation.tasks')}
            </button>
            
            <button 
              onClick={() => navigate('/publish')}
              className={styles.heroButton}
            >
              🚀 {t('navigation.publish')}
            </button>
            
            <button 
              onClick={() => navigate('/task-experts')}
              className={styles.heroButton}
            >
              👑 {t('footer.taskExperts')}
            </button>
          </div>
          
          {/* 统计数据 */}
          <div className={styles.heroStats}>
            <div className={styles.heroStatItem}>
              <div className={styles.heroStatValue}>{t('home.betaVersion')}</div>
              <div className={styles.heroStatLabel}>{t('about.teamText')}</div>
            </div>
            <div className={styles.heroStatItem}>
              <div className={styles.heroStatValue}>{t('home.coverageArea')}</div>
              <div className={styles.heroStatLabel}>{t('profile.tasksCompleted')}</div>
            </div>
            <div className={styles.heroStatItem}>
              <div className={styles.heroStatValue}>100%</div>
              <div className={styles.heroStatLabel}>{t('home.userSatisfactionGoal')}</div>
            </div>
          </div>
        </div>
      </section>
      
      {/* 特色功能区域 */}
      <section className={styles.featuresSection}>
        <div className={styles.featuresContainer}>
          <h2 className={styles.featuresTitle}>
            {t('about.title')}
          </h2>
          <p className={styles.featuresSubtitle}>
            {t('about.subtitle')}
          </p>
          
          <div className={styles.featuresGrid}>
            <div className={styles.featureCard}>
              <div className={`${styles.featureIcon} ${styles.featureIconValues}`}>
                🎯
              </div>
              <h3 className={styles.featureTitle}>
                {t('about.values')}
              </h3>
              <p className={styles.featureText}>
                {t('about.valuesText')}
              </p>
            </div>
            
            <div className={styles.featureCard}>
              <div className={`${styles.featureIcon} ${styles.featureIconMission}`}>
                🛡️
              </div>
              <h3 className={styles.featureTitle}>
                {t('about.mission')}
              </h3>
              <p className={styles.featureText}>
                {t('about.missionText')}
              </p>
            </div>
            
            <div className={styles.featureCard}>
              <div className={`${styles.featureIcon} ${styles.featureIconVision}`}>
                ⚡
              </div>
              <h3 className={styles.featureTitle}>
                {t('about.vision')}
              </h3>
              <p className={styles.featureText}>
                {t('about.visionText')}
              </p>
            </div>
          </div>
        </div>
      </section>
      {/* 最新任务区块 - 重新设计 */}
      <main className={styles.tasksSection}>
        <div className={styles.tasksHeader}>
          <h2 className={styles.tasksTitle}>
            {t('home.recentTasks')}
          </h2>
          <p className={styles.tasksSubtitle}>
            {t('home.subtitle')}
          </p>
        </div>
        {/* 任务卡片列表 - 重新设计 */}
        {loading ? (
          <div className={styles.loadingContainer}>
            <div className={styles.loadingText}>🔄 {t('home.loadingTasks')}</div>
          </div>
        ) : tasks.length === 0 ? (
          <div className={styles.emptyContainer}>
            <div className={styles.emptyIcon}>📝</div>
            <div className={styles.emptyTitle}>{t('home.noTasksAvailable')}</div>
            <div className={styles.emptyDesc}>{t('home.noTasksDesc')}</div>
          </div>
        ) : (
          <div className={styles.tasksGrid}>
            {tasks.map(task => {
              // 判断是否应该对非相关用户隐藏真实状态（显示为open）
              const shouldHideStatus = () => {
                if (!task || !user) return false;
                const isPoster = task.poster_id === user.id;
                const isTaker = task.taker_id === user.id;
                
                // 如果用户不是发布者或接收者，且状态是taken，应显示为open
                if (!isPoster && !isTaker && task.status === 'taken') {
                  return true;
                }
                return false;
              };
              
              // 获取显示的状态
              const displayStatus = shouldHideStatus() ? 'open' : task.status;
              
              // 任务等级标签样式
              const getTaskLevelStyle = (level: string) => {
                switch (level) {
                  case 'vip':
                    return {
                      background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                      color: '#8B4513',
                      border: '2px solid #FFD700',
                      boxShadow: '0 2px 8px rgba(255, 215, 0, 0.3)'
                    };
                  case 'super':
                    return {
                      background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
                      color: '#fff',
                      border: '2px solid #FF4757',
                      boxShadow: '0 2px 8px rgba(255, 107, 107, 0.3)'
                    };
                  default:
                    return {
                      background: '#f8f9fa',
                      color: '#6c757d',
                      border: '1px solid #dee2e6'
                    };
                }
              };

              const getTaskLevelText = (level: string) => {
                switch (level) {
                  case 'vip':
                    return t('home.vipTask');
                  case 'super':
                    return t('home.superTask');
                  default:
                    return t('home.normalTask');
                }
              };

              return (
                <div 
                  key={task.id} 
                  className={styles.taskCard}
                  onClick={() => {
                    setSelectedTaskId(task.id);
                    setShowTaskDetailModal(true);
                  }}
                >
                  {/* 任务等级标签 */}
                  {task.task_level && task.task_level !== 'normal' && (
                    <div className={`${styles.taskLevelBadge} ${
                      task.task_level === 'vip' ? styles.taskLevelBadgeVip : 
                      task.task_level === 'super' ? styles.taskLevelBadgeSuper : ''
                    }`}>
                      {getTaskLevelText(task.task_level)}
                    </div>
                  )}
                  
                  <div>
                    <div className={styles.taskTitle}>
                      <TaskTitle
                        title={task.title}
                        language={language}
                        style={{
                          fontSize: 'inherit',
                          fontWeight: 'inherit',
                          color: 'inherit',
                          lineHeight: 'inherit'
                        }}
                      />
                    </div>
                    
                    <div className={styles.taskInfoRow}>
                      <span className={styles.taskTypeBadge}>
                        {task.task_type}
                      </span>
                      <span className={`${styles.taskLocationBadge} ${
                        task.location === 'Online' ? styles.taskLocationOnline : styles.taskLocationOffline
                      }`}>
                        {task.location === 'Online' ? '🌐' : '📍'} {task.location}
                      </span>
                    </div>
                    
                    <div className={styles.taskDescription}>
                      {task.description}
                    </div>
                    {/* 任务状态和时间信息 */}
                    <div className={styles.taskStatusContainer}>
                      <div className={styles.taskStatusIndicator}>
                        <div 
                          className={styles.taskStatusDot}
                          style={{
                            background: (displayStatus === 'open' || displayStatus === 'taken') ? '#48bb78' : 
                                       displayStatus === 'in_progress' ? '#4299e1' : 
                                       displayStatus === 'completed' ? '#9f7aea' : 
                                       displayStatus === 'cancelled' ? '#f56565' : '#a0aec0'
                          }}
                        />
                        <span 
                          className={styles.taskStatusText}
                          style={{
                            color: (displayStatus === 'open' || displayStatus === 'taken') ? '#48bb78' : 
                                   displayStatus === 'in_progress' ? '#4299e1' : 
                                   displayStatus === 'completed' ? '#9f7aea' : 
                                   displayStatus === 'cancelled' ? '#f56565' : '#a0aec0'
                          }}
                        >
                          {(displayStatus === 'open' || displayStatus === 'taken') ? t('taskStatuses.published') :
                           displayStatus === 'in_progress' ? t('taskStatuses.inProgress') :
                           displayStatus === 'completed' ? t('taskStatuses.completed') :
                           displayStatus === 'cancelled' ? t('taskStatuses.cancelled') : displayStatus}
                        </span>
                      </div>
                    </div>
                      
                    {(task.status === 'open' || task.status === 'taken') && (
                        <div className={`${styles.taskTimeRemaining} ${
                          isExpiringSoon(task.deadline) ? styles.taskTimeRemainingSoon : styles.taskTimeRemainingNormal
                        }`}>
                          ⏰ {getRemainTime(task.deadline, t)}
                        </div>
                    )}
                  </div>
                  
                  {/* 底部价格和操作区域 */}
                  <div className={styles.taskRewardContainer}>
                    <div className={styles.taskRewardInfo}>
                      <span className={styles.taskRewardAmount}>
                        £{((task.base_reward ?? task.reward) || 0).toFixed(2)}
                      </span>
                      <span className={styles.taskRewardLabel}>
                        {t('home.taskReward')}
                      </span>
                    </div>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedTaskId(task.id);
                        setShowTaskDetailModal(true);
                      }} 
                      className={styles.taskViewButton}
                    >
                      {t('home.viewDetails')}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </main>
      {/* 平台公告区块 - 使用多种方法防止搜索引擎抓取为描述 */}
      {/* 注意：此区块内容不应被搜索引擎抓取，仅用于用户查看 */}
      <section 
        style={{background: '#f8fbff', padding: '48px 0'}}
        data-nosnippet="true"
        data-noindex="true"
        aria-hidden="true"
      >
        <div style={{maxWidth: 900, margin: '0 auto', textAlign: 'center'}}>
          <h3 
            style={{fontSize: 24, fontWeight: 700, marginBottom: 32, color: '#A67C52'}} 
            data-nosnippet="true"
            data-noindex="true"
            aria-hidden="true"
          >
            {t('home.announcementTitle')}
          </h3>
          <div style={{display: 'flex', justifyContent: 'center', gap: 40, flexWrap: 'wrap'}}>
            <div 
              style={{minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 24, marginBottom: 16, borderLeft: '6px solid #A67C52'}}
              data-nosnippet="true"
              data-noindex="true"
              aria-hidden="true"
            >
              {/* 使用注释包裹内容，进一步防止抓取 */}
              {/*googleoff: snippet*/}
              {/*googleoff: index*/}
              {t('home.announcementContent')}
              <br/>
              <span style={{color: '#888', fontSize: '14px'}}>{t('home.announcementDate')}</span>
              {/*googleon: index*/}
              {/*googleon: snippet*/}
            </div>
          </div>
        </div>
      </section>
      {/* 底部信息区块 */}
      <Footer />
      
      {/* 任务详情弹窗 */}
      <TaskDetailModal
        isOpen={showTaskDetailModal}
        onClose={() => {
          setShowTaskDetailModal(false);
          setSelectedTaskId(null);
        }}
        taskId={selectedTaskId}
      />
      
      {/* 登录弹窗 */}
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          // 登录成功后刷新用户状态
          window.location.reload();
        }}
        onReopen={() => {
          // 重新打开登录弹窗
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

export default Home; 