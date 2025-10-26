import React, { useEffect, useState } from 'react';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, customerServiceLogout, getPublicSystemSettings, logout } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import Footer from '../components/Footer';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';

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
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  
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
        console.log('User data loaded successfully:', userData);
        setUser(userData);
      } catch (error: any) {
        console.log('Failed to load user data:', error);
        console.log('Error details:', error.response?.status, error.response?.data);
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
      console.log('Getting notification data, user ID:', user.id);
      // Get notification list - get all unread notifications and recent 10 read notifications
      getNotificationsWithRecentRead(10).then(notifications => {
        console.log('Notification list loaded (unread + recent read):', notifications);
        setNotifications(notifications);
      }).catch(error => {
        console.error('Failed to get notifications:', error);
        // If getting failed, get recent notifications
        getNotifications(20).then(notifications => {
          console.log('Notification list loaded:', notifications);
          setNotifications(notifications);
        }).catch(error => {
          console.error('Failed to get notifications:', error);
        });
      });
      // Get unread count
      getUnreadNotificationCount().then(count => {
        console.log('Unread notification count:', count);
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
            console.log('定期更新未读通知数量:', count);
            setUnreadCount(count);
          }).catch(error => {
            console.error('定期更新未读数量失败:', error);
          });
        }
      }, 30000); // 每30秒更新一次
      return () => clearInterval(interval);
    }
  }, [user]);

  // 获取任务数据 - 只显示赏金最高且最新的3个任务
  useEffect(() => {
    setLoading(true);
    console.log('开始获取首页任务数据');
    fetchTasks({ type: 'all', city: 'all', keyword: '', page: 1, pageSize: 50 })
      .then(data => {
        console.log('获取到的任务数据:', data);
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
      console.log('通知标记为已读成功');
    } catch (error) {
      console.error('标记通知为已读失败:', error);
      alert('标记通知为已读失败，请重试');
    }
  };

  // 标记所有通知为已读
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setUnreadCount(0);
      // 更新通知列表，标记所有为已读
      setNotifications(prev => prev.map(n => ({ ...n, is_read: 1 })));
      console.log('所有通知标记为已读成功');
    } catch (error) {
      console.error('标记所有通知为已读失败:', error);
      alert('标记所有通知为已读失败，请重试');
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

  return (
    <div>
      {/* 顶部导航栏 - 使用汉堡菜单 */}
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
                  console.log('登出请求失败:', error);
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
      <div style={{height: 60}} />
      
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
      <section className="hero-section" style={{
        backgroundImage: 'url(/static/background.jpg)',
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
        minHeight: '100vh',
        padding: '80px 0',
        textAlign: 'center',
        position: 'relative',
        overflow: 'hidden',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        {/* 背景遮罩层 */}
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          background: 'rgba(0, 0, 0, 0.4)',
          pointerEvents: 'none'
        }} />
        
        <div style={{maxWidth: 1200, width: '100%', padding: '0 24px', position: 'relative', zIndex: 2}}>
          <h1 className="hero-title" style={{
            fontSize: '48px',
            fontWeight: '800',
            marginBottom: '24px',
            color: '#fff',
            textShadow: '0 4px 8px rgba(0,0,0,0.3)',
            lineHeight: '1.2'
          }}>
            {t('home.welcome')}
            <br />
            <span style={{color: '#FFD700'}}>{t('home.subtitle')}</span>
          </h1>
          
          <p className="hero-subtitle" style={{
            fontSize: '20px',
            color: 'rgba(255,255,255,0.9)',
            marginBottom: '40px',
            maxWidth: '600px',
            margin: '0 auto 40px',
            lineHeight: '1.6'
          }}>
            {t('home.heroDescription')}
          </p>
          
          <div style={{display: 'flex', justifyContent: 'center', gap: '20px', flexWrap: 'wrap', marginBottom: '60px'}}>
            <button 
              onClick={() => navigate('/tasks')}
              style={{
                background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                color: '#8B4513',
                padding: '16px 32px',
                borderRadius: '50px',
                fontSize: '18px',
                fontWeight: '700',
                border: 'none',
                cursor: 'pointer',
                boxShadow: '0 8px 24px rgba(255, 215, 0, 0.4)',
                transition: 'all 0.3s ease',
                transform: 'translateY(0)'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 12px 32px rgba(255, 215, 0, 0.6)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 8px 24px rgba(255, 215, 0, 0.4)';
              }}
            >
              🚀 {t('navigation.tasks')}
            </button>
            
            <button 
              onClick={() => navigate('/publish')}
              style={{
                background: 'rgba(255,255,255,0.2)',
                color: '#fff',
                padding: '16px 32px',
                borderRadius: '50px',
                fontSize: '18px',
                fontWeight: '700',
                border: '2px solid rgba(255,255,255,0.3)',
                cursor: 'pointer',
                backdropFilter: 'blur(10px)',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.3)';
                e.currentTarget.style.borderColor = 'rgba(255,255,255,0.5)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                e.currentTarget.style.borderColor = 'rgba(255,255,255,0.3)';
              }}
            >
              ✨ {t('navigation.publish')}
            </button>
        </div>
          
          {/* 统计数据 */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: '40px',
            maxWidth: '800px',
            margin: '0 auto'
          }}>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>{t('home.betaVersion')}</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>{t('about.teamText')}</div>
          </div>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>{t('home.coverageArea')}</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>{t('profile.tasksCompleted')}</div>
          </div>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>100%</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>{t('home.userSatisfactionGoal')}</div>
            </div>
          </div>
        </div>
      </section>
      
      {/* 特色功能区域 */}
      <section style={{padding: '80px 0', background: '#f8fafc'}}>
        <div style={{maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          <h2 style={{
            fontSize: '36px',
            fontWeight: '700',
            textAlign: 'center',
            marginBottom: '16px',
            color: '#2d3748'
          }}>
            {t('about.title')}
          </h2>
          <p style={{
            fontSize: '18px',
            color: '#718096',
            textAlign: 'center',
            marginBottom: '60px',
            maxWidth: '600px',
            margin: '0 auto 60px'
          }}>
            {t('about.subtitle')}
          </p>
          
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: '40px'
          }}>
            <div style={{
              background: '#fff',
              padding: '40px 30px',
              borderRadius: '20px',
              boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
              textAlign: 'center',
              transition: 'transform 0.3s ease',
              border: '1px solid #e2e8f0'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-8px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
            }}
            >
              <div style={{
                width: '80px',
                height: '80px',
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 24px',
                fontSize: '32px'
              }}>
                🎯
              </div>
              <h3 style={{fontSize: '24px', fontWeight: '700', marginBottom: '16px', color: '#2d3748'}}>
                {t('about.values')}
              </h3>
              <p style={{color: '#718096', lineHeight: '1.6'}}>
                {t('about.valuesText')}
              </p>
            </div>
            
            <div style={{
              background: '#fff',
              padding: '40px 30px',
              borderRadius: '20px',
              boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
              textAlign: 'center',
              transition: 'transform 0.3s ease',
              border: '1px solid #e2e8f0'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-8px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
            }}
            >
              <div style={{
                width: '80px',
                height: '80px',
                background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 24px',
                fontSize: '32px'
              }}>
                🛡️
              </div>
              <h3 style={{fontSize: '24px', fontWeight: '700', marginBottom: '16px', color: '#2d3748'}}>
                {t('about.mission')}
              </h3>
              <p style={{color: '#718096', lineHeight: '1.6'}}>
                {t('about.missionText')}
              </p>
            </div>
            
            <div style={{
              background: '#fff',
              padding: '40px 30px',
              borderRadius: '20px',
              boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
              textAlign: 'center',
              transition: 'transform 0.3s ease',
              border: '1px solid #e2e8f0'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-8px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
            }}
            >
              <div style={{
                width: '80px',
                height: '80px',
                background: 'linear-gradient(135deg, #48bb78, #38a169)',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 24px',
                fontSize: '32px'
              }}>
                ⚡
              </div>
              <h3 style={{fontSize: '24px', fontWeight: '700', marginBottom: '16px', color: '#2d3748'}}>
                {t('about.vision')}
              </h3>
              <p style={{color: '#718096', lineHeight: '1.6'}}>
                {t('about.visionText')}
              </p>
            </div>
          </div>
        </div>
      </section>
      {/* 最新任务区块 - 重新设计 */}
      <main style={{maxWidth: 1200, margin: '0 auto', padding: '80px 24px'}}>
        <div style={{textAlign: 'center', marginBottom: '60px'}}>
          <h2 style={{
            fontSize: '36px',
            fontWeight: '700',
            marginBottom: '16px',
            color: '#2d3748'
          }}>
            {t('home.recentTasks')}
          </h2>
          <p style={{
            fontSize: '18px',
            color: '#718096',
            maxWidth: '600px',
            margin: '0 auto'
          }}>
            {t('home.subtitle')}
          </p>
        </div>
        {/* 任务卡片列表 - 重新设计 */}
        {loading ? (
          <div style={{
            textAlign: 'center', 
            padding: '80px 40px',
            background: '#fff',
            borderRadius: '16px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
          }}>
            <div style={{fontSize: '18px', color: '#718096'}}>🔄 {t('home.loadingTasks')}</div>
          </div>
        ) : tasks.length === 0 ? (
          <div style={{
            textAlign: 'center', 
            padding: '80px 40px',
            background: '#fff',
            borderRadius: '16px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.08)'
          }}>
            <div style={{fontSize: '48px', marginBottom: '16px'}}>📝</div>
            <div style={{fontSize: '18px', color: '#718096', marginBottom: '8px'}}>{t('home.noTasksAvailable')}</div>
            <div style={{fontSize: '14px', color: '#a0aec0'}}>{t('home.noTasksDesc')}</div>
          </div>
        ) : (
          <div style={{
            display: 'grid', 
            gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', 
            gap: '32px'
          }}>
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
                <div key={task.id} style={{
                  background: '#fff', 
                  borderRadius: '20px', 
                  boxShadow: '0 8px 32px rgba(0,0,0,0.08)', 
                  padding: '24px', 
                  display: 'flex', 
                  flexDirection: 'column', 
                  justifyContent: 'space-between', 
                  border: '1px solid #e2e8f0',
                  position: 'relative',
                  overflow: 'hidden',
                  transition: 'all 0.3s ease',
                  cursor: 'pointer'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-4px)';
                  e.currentTarget.style.boxShadow = '0 12px 40px rgba(0,0,0,0.12)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 8px 32px rgba(0,0,0,0.08)';
                }}
                onClick={() => {
                  setSelectedTaskId(task.id);
                  setShowTaskDetailModal(true);
                }}
                >
                  {/* 任务等级标签 */}
                  {task.task_level && task.task_level !== 'normal' && (
                    <div style={{
                      position: 'absolute',
                      top: 12,
                      right: 12,
                      padding: '4px 8px',
                      borderRadius: 12,
                      fontSize: 12,
                      fontWeight: 700,
                      zIndex: 1,
                      ...getTaskLevelStyle(task.task_level)
                    }}>
                      {getTaskLevelText(task.task_level)}
                    </div>
                  )}
                  
                  <div>
                    <div style={{
                      fontWeight: '700', 
                      fontSize: '20px', 
                      marginBottom: '12px',
                      color: '#2d3748',
                      lineHeight: '1.4'
                    }}>
                      {task.title}
                    </div>
                    
                    <div style={{
                      display: 'flex',
                      gap: '12px',
                      marginBottom: '16px',
                      flexWrap: 'wrap'
                    }}>
                      <span style={{
                        background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                        color: '#fff',
                        padding: '4px 12px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: '600'
                      }}>
                        {task.task_type}
                      </span>
                      <span style={{
                        background: task.location === 'Online' ? '#e6f3ff' : '#f7fafc',
                        color: task.location === 'Online' ? '#2563eb' : '#4a5568',
                        padding: '4px 12px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: '500',
                        border: task.location === 'Online' ? '1px solid #93c5fd' : '1px solid #e2e8f0'
                      }}>
                        {task.location === 'Online' ? '🌐' : '📍'} {t(`tasks.cities.${task.location}`) || task.location}
                      </span>
                    </div>
                    
                    <div style={{
                      color: '#4a5568', 
                      marginBottom: '16px',
                      lineHeight: '1.6',
                      fontSize: '14px',
                      display: '-webkit-box',
                      WebkitLineClamp: 3,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden'
                    }}>
                      {task.description}
                    </div>
                    {/* 任务状态和时间信息 */}
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '20px',
                      padding: '12px 16px',
                      background: '#f8fafc',
                      borderRadius: '12px',
                      border: '1px solid #e2e8f0'
                    }}>
                      <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
                        <div style={{
                          width: '8px',
                          height: '8px',
                          borderRadius: '50%',
                          background: (displayStatus === 'open' || displayStatus === 'taken') ? '#48bb78' : 
                                     displayStatus === 'in_progress' ? '#4299e1' : 
                                     displayStatus === 'completed' ? '#9f7aea' : 
                                     displayStatus === 'cancelled' ? '#f56565' : '#a0aec0'
                        }} />
                        <span style={{
                          color: (displayStatus === 'open' || displayStatus === 'taken') ? '#48bb78' : 
                                 displayStatus === 'in_progress' ? '#4299e1' : 
                                 displayStatus === 'completed' ? '#9f7aea' : 
                                 displayStatus === 'cancelled' ? '#f56565' : '#a0aec0',
                          fontWeight: '600',
                          fontSize: '14px'
                      }}>
                        {(displayStatus === 'open' || displayStatus === 'taken') ? t('taskStatuses.published') :
                         displayStatus === 'in_progress' ? t('taskStatuses.inProgress') :
                         displayStatus === 'completed' ? t('taskStatuses.completed') :
                         displayStatus === 'cancelled' ? t('taskStatuses.cancelled') : displayStatus}
                      </span>
                    </div>
                      
                    {(task.status === 'open' || task.status === 'taken') && (
                        <div style={{
                          color: isExpiringSoon(task.deadline) ? '#ed8936' : '#48bb78',
                          fontWeight: '600',
                          fontSize: '12px'
                        }}>
                          ⏰ {getRemainTime(task.deadline, t)}
                      </div>
                    )}
                  </div>
                  </div>
                  
                  {/* 底部价格和操作区域 */}
                  <div style={{
                    display: 'flex', 
                    justifyContent: 'space-between', 
                    alignItems: 'center',
                    paddingTop: '16px',
                    borderTop: '1px solid #e2e8f0'
                  }}>
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px'
                    }}>
                      <span style={{
                        color: '#2d3748', 
                        fontWeight: '800', 
                        fontSize: '24px'
                      }}>
                        £{task.reward.toFixed(2)}
                      </span>
                      <span style={{
                        color: '#718096',
                        fontSize: '12px',
                        fontWeight: '500'
                      }}>
                        {t('home.taskReward')}
                      </span>
                    </div>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedTaskId(task.id);
                        setShowTaskDetailModal(true);
                      }} 
                      style={{
                        background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                        color: '#fff',
                        border: 'none',
                        borderRadius: '8px',
                        padding: '8px 16px',
                        fontWeight: '600',
                        fontSize: '14px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        boxShadow: '0 2px 8px rgba(59, 130, 246, 0.3)'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.transform = 'translateY(-1px)';
                        e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.4)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(59, 130, 246, 0.3)';
                      }}
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
      {/* 平台公告区块 */}
      <section style={{background: '#f8fbff', padding: '48px 0'}}>
        <div style={{maxWidth: 900, margin: '0 auto', textAlign: 'center'}}>
          <h3 style={{fontSize: 24, fontWeight: 700, marginBottom: 32, color: '#A67C52'}}>平台公告</h3>
          <div style={{display: 'flex', justifyContent: 'center', gap: 40, flexWrap: 'wrap'}}>
            <div style={{minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 24, marginBottom: 16, borderLeft: '6px solid #A67C52'}}>
              <div style={{fontWeight: 600, marginBottom: 8, color: '#A67C52'}}>【公告】目前平台属于测试阶段，如有问题欢迎发送邮件至 support@link2ur.com</div>
              <div style={{color: '#888'}}>2025-10-09</div>
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