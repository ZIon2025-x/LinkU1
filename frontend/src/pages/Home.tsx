import React, { useEffect, useState } from 'react';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, customerServiceLogout, getPublicSystemSettings, logout } from '../api';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import Footer from '../components/Footer';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import { useLanguage } from '../contexts/LanguageContext';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

// 剩余时间计算函数 - 正确处理UTC时间
function getRemainTime(deadline: string, t: (key: string) => string) {
  const now = dayjs();
  // 假设deadline是UTC时间，先解析为UTC，再转换为本地时间进行比较
  const end = dayjs.utc(deadline).local();
  const diff = end.diff(now, 'minute');
  
  if (diff <= 0) return t('home.taskExpired');
  
  const hours = Math.floor(diff / 60);
  const minutes = diff % 60;
  
  if (hours > 0) {
    return `${hours}${t('home.hours')}${minutes}${t('home.minutes')}`;
  }
  return `${minutes}${t('home.minutes')}`;
}

// 检查是否即将过期 - 正确处理UTC时间
function isExpiringSoon(deadline: string) {
  const now = dayjs();
  // 假设deadline是UTC时间，先解析为UTC，再转换为本地时间进行比较
  const end = dayjs.utc(deadline).local();
  const oneDayLater = now.add(1, 'day');
  
  return now.isBefore(end) && end.isBefore(oneDayLater);
}

// 检查是否已过期 - 正确处理UTC时间
function isExpired(deadline: string) {
  const now = dayjs();
  // 假设deadline是UTC时间，先解析为UTC，再转换为本地时间进行比较
  const end = dayjs.utc(deadline).local();
  return now.isAfter(end);
}

// 添加可爱的动画样式
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

// 注入样式到页面
if (typeof document !== 'undefined') {
  const styleElement = document.createElement('style');
  styleElement.textContent = bellStyles;
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
  
  // 任务类型数组 - 使用翻译
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
  
  // 联调相关状态
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [type, setType] = useState(t('home.allTypes'));
  const [city, setCity] = useState('all');
  const [keyword, setKeyword] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize] = useState(6);
  const [total, setTotal] = useState(0);

  // 用户登录与头像逻辑
  const [user, setUser] = useState<any>(null);
  const [showMenu, setShowMenu] = useState(false);
  
  // 通知相关状态
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  
  // 系统设置状态
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 登录弹窗状态
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
  // 任务详情弹窗状态
  const [showTaskDetailModal, setShowTaskDetailModal] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);
  
  useEffect(() => {
    const loadUserData = async () => {
      try {
        // 直接尝试获取用户信息，HttpOnly Cookie会自动发送
        const userData = await fetchCurrentUser();
        console.log('获取用户资料成功:', userData);
        setUser(userData);
      } catch (error: any) {
        console.log('获取用户资料失败:', error);
        console.log('错误详情:', error.response?.status, error.response?.data);
        setUser(null);
      }
    };
    
    // 添加短暂延迟，确保页面完全加载后再获取用户资料
    const timer = setTimeout(loadUserData, 100);
    
    // 加载系统设置
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
    
    return () => clearTimeout(timer);
  }, []);

  // 获取通知数据
  useEffect(() => {
    if (user) {
      console.log('获取通知数据，用户ID:', user.id);
      // 获取通知列表 - 获取所有未读通知和最近10条已读通知
      getNotificationsWithRecentRead(10).then(notifications => {
        console.log('获取到的通知列表（未读+最近已读）:', notifications);
        setNotifications(notifications);
      }).catch(error => {
        console.error('获取通知失败:', error);
        // 如果获取失败，则获取最近的通知
        getNotifications(20).then(notifications => {
          console.log('获取到的通知列表:', notifications);
          setNotifications(notifications);
        }).catch(error => {
          console.error('获取通知失败:', error);
        });
      });
      // 获取未读数量
      getUnreadNotificationCount().then(count => {
        console.log('获取到的未读通知数量:', count);
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

  // 获取任务数据
  useEffect(() => {
    setLoading(true);
    console.log('开始获取任务数据，参数:', { type, city, keyword, page, pageSize });
    console.log('Home页面城市状态:', city);
    fetchTasks({ type, city, keyword, page, pageSize })
      .then(data => {
        console.log('获取到的任务数据:', data);
        setTasks(Array.isArray(data) ? data : (data.items || []));
        setTotal(data.total || 0);
      })
      .catch(error => {
        console.error('获取任务数据失败:', error);
        setTasks([]);
        setTotal(0);
      })
      .finally(() => setLoading(false));
  }, [type, city, keyword, page, pageSize]);

  // 定期刷新任务列表以更新剩余时间和状态
  useEffect(() => {
    const interval = setInterval(() => {
      if (tasks.length > 0) {
        // 重新获取任务数据以更新状态
        fetchTasks({ type, city, keyword, page, pageSize })
          .then(data => {
            const newTasks = Array.isArray(data) ? data : (data.items || []);
            setTasks(newTasks);
            setTotal(data.total || 0);
          })
          .catch(error => {
            console.error('定期刷新任务列表失败:', error);
          });
      }
    }, 60000); // 每分钟更新一次
    return () => clearInterval(interval);
  }, [type, city, keyword, page, pageSize, tasks.length]);

  const navigate = useNavigate();

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
          <div style={{fontWeight: 'bold', fontSize: 24, background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent'}}>Link2Ur</div>
          
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
      <section style={{
        background: 'linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%)',
        padding: '80px 0',
        textAlign: 'center',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* 背景装饰 */}
        <div style={{
          position: 'absolute',
          top: '-50%',
          left: '-50%',
          width: '200%',
          height: '200%',
          background: 'radial-gradient(circle, rgba(255,255,255,0.1) 1px, transparent 1px)',
          backgroundSize: '50px 50px',
          animation: 'float 20s infinite linear',
          pointerEvents: 'none'
        }} />
        
        <div style={{maxWidth: 1200, margin: '0 auto', padding: '0 24px', position: 'relative', zIndex: 2}}>
          <h1 style={{
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
          
          <p style={{
            fontSize: '20px',
            color: 'rgba(255,255,255,0.9)',
            marginBottom: '40px',
            maxWidth: '600px',
            margin: '0 auto 40px',
            lineHeight: '1.6'
          }}>
            {t('about.missionText')}
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
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>1000+</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>{t('about.teamText')}</div>
          </div>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>5000+</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>{t('profile.tasksCompleted')}</div>
          </div>
            <div style={{textAlign: 'center'}}>
              <div style={{fontSize: '36px', fontWeight: '800', color: '#FFD700', marginBottom: '8px'}}>98%</div>
              <div style={{color: 'rgba(255,255,255,0.8)', fontSize: '16px'}}>{t('profile.rating')}</div>
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
        {/* 筛选/搜索栏 - 重新设计 */}
        <div style={{
          background: '#fff',
          borderRadius: '16px',
          padding: '24px',
          boxShadow: '0 4px 20px rgba(0,0,0,0.08)',
          marginBottom: '40px',
          border: '1px solid #e2e8f0'
        }}>
          <div style={{display: 'flex', gap: '16px', flexWrap: 'wrap', alignItems: 'center'}}>
            <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
              <span style={{color: '#4a5568', fontWeight: '600', fontSize: '14px'}}>{t('tasks.taskCategory')}:</span>
              <select 
                value={type} 
                onChange={e => { setType(e.target.value); setPage(1); }} 
                style={{
                  padding: '10px 16px',
                  borderRadius: '8px',
                  border: '1px solid #e2e8f0',
                  color: '#4a5568',
                  fontWeight: '500',
                  background: '#fff',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#8b5cf6';
                  e.target.style.boxShadow = '0 0 0 3px rgba(139, 92, 246, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = 'none';
                }}
              >
            <option>{t('tasks.filterByCategory')}</option>
            {TASK_TYPES.map(type => (
              <option key={type} value={type}>{type}</option>
            ))}
          </select>
            </div>
            
            <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
              <span style={{color: '#4a5568', fontWeight: '600', fontSize: '14px'}}>{t('common.city')}:</span>
              <select 
                value={city} 
                onChange={e => { setCity(e.target.value); setPage(1); }} 
                style={{
                  padding: '10px 16px',
                  borderRadius: '8px',
                  border: '1px solid #e2e8f0',
                  color: '#4a5568',
                  fontWeight: '500',
                  background: '#fff',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#8b5cf6';
                  e.target.style.boxShadow = '0 0 0 3px rgba(139, 92, 246, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = 'none';
                }}
              >
            <option value="all">{t('home.allCities')}</option>
            {CITIES.map(cityName => (
              <option key={cityName} value={cityName}>{cityName}</option>
            ))}
          </select>
            </div>
            
            <div style={{flex: 1, minWidth: '200px'}}>
              <input 
                type="text" 
                value={keyword} 
                onChange={e => setKeyword(e.target.value)} 
                placeholder={t('tasks.searchPlaceholder')} 
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  borderRadius: '8px',
                  border: '1px solid #e2e8f0',
                  color: '#4a5568',
                  fontSize: '14px',
                  transition: 'all 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#8b5cf6';
                  e.target.style.boxShadow = '0 0 0 3px rgba(139, 92, 246, 0.1)';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e2e8f0';
                  e.target.style.boxShadow = 'none';
                }}
              />
            </div>
            
            <button 
              onClick={() => { setPage(1); }} 
              style={{
                padding: '12px 24px',
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                color: '#fff',
                border: 'none',
                borderRadius: '8px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-1px)';
                e.currentTarget.style.boxShadow = '0 6px 16px rgba(59, 130, 246, 0.4)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
              }}
            >
              🔍 {t('home.search')}
            </button>
          </div>
        </div>
        {/* 自动取消过期任务提示 */}
        <div style={{
          background: 'linear-gradient(135deg, #fff3cd, #ffeaa7)',
          border: '1px solid #ffc107',
          borderRadius: 8,
          padding: 12,
          marginBottom: 16,
          display: 'flex',
          alignItems: 'center',
          gap: 8
        }}>
          <span style={{fontSize: 16}}>⏰</span>
          <span style={{color: '#856404', fontSize: 14}}>
            {t('home.autoCancelExpired')}
          </span>
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
                        {task.location === 'Online' ? '🌐' : '📍'} {task.location}
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
                          background: (task.status === 'open' || task.status === 'taken') ? '#48bb78' : 
                                     task.status === 'in_progress' ? '#4299e1' : 
                                     task.status === 'completed' ? '#9f7aea' : 
                                     task.status === 'cancelled' ? '#f56565' : '#a0aec0'
                        }} />
                        <span style={{
                          color: (task.status === 'open' || task.status === 'taken') ? '#48bb78' : 
                                 task.status === 'in_progress' ? '#4299e1' : 
                                 task.status === 'completed' ? '#9f7aea' : 
                                 task.status === 'cancelled' ? '#f56565' : '#a0aec0',
                          fontWeight: '600',
                          fontSize: '14px'
                      }}>
                        {(task.status === 'open' || task.status === 'taken') ? t('taskStatuses.published') :
                         task.status === 'in_progress' ? t('taskStatuses.inProgress') :
                         task.status === 'completed' ? t('taskStatuses.completed') :
                         task.status === 'cancelled' ? t('taskStatuses.cancelled') : task.status}
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
        {/* 分页按钮 */}
        <div style={{marginTop: 32, textAlign: 'center'}}>
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} style={{marginRight: 8, padding: '6px 16px', borderRadius: 4, border: '1px solid #8b5cf6', background: page === 1 ? '#eee' : '#fff', color: '#8b5cf6', fontWeight: 700}}>{t('home.previousPage')}</button>
          <span style={{margin: '0 12px', color: '#A67C52', fontWeight: 600}}>{t('home.page')} {page} {t('home.of')}</span>
          <button onClick={() => setPage(p => p + 1)} disabled={tasks.length < pageSize} style={{padding: '6px 16px', borderRadius: 4, border: '1px solid #8b5cf6', background: tasks.length < pageSize ? '#eee' : '#8b5cf6', color: tasks.length < pageSize ? '#8b5cf6' : '#fff', fontWeight: 700}}>{t('home.nextPage')}</button>
        </div>
      </main>
      {/* 平台优势/亮点区块 */}
      <section style={{background: '#f8fbff', padding: '48px 0'}}>
        <div style={{maxWidth: 1200, margin: '0 auto', display: 'flex', gap: 32, flexWrap: 'wrap', justifyContent: 'center'}}>
          <div style={{flex: 1, minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 32, textAlign: 'center', borderTop: '4px solid #8b5cf6'}}>
            <div style={{fontSize: 32, color: '#8b5cf6', marginBottom: 12}}>🌟</div>
            <div style={{fontWeight: 600, fontSize: 20, marginBottom: 8, color: '#A67C52'}}>{t('home.diverseTaskTypes')}</div>
            <div style={{color: '#888'}}>{t('home.diverseTaskTypesDesc')}</div>
          </div>
          <div style={{flex: 1, minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 32, textAlign: 'center', borderTop: '4px solid #A67C52'}}>
            <div style={{fontSize: 32, color: '#A67C52', marginBottom: 12}}>🔒</div>
            <div style={{fontWeight: 600, fontSize: 20, marginBottom: 8, color: '#A67C52'}}>{t('home.securePayment')}</div>
            <div style={{color: '#888'}}>{t('home.securePaymentDesc')}</div>
          </div>
          <div style={{flex: 1, minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 32, textAlign: 'center', borderTop: '4px solid #8b5cf6'}}>
            <div style={{fontSize: 32, color: '#8b5cf6', marginBottom: 12}}>⏱️</div>
            <div style={{fontWeight: 600, fontSize: 20, marginBottom: 8, color: '#A67C52'}}>{t('home.efficientMatching')}</div>
            <div style={{color: '#888'}}>{t('home.efficientMatchingDesc')}</div>
          </div>
        </div>
      </section>
      {/* 新手引导/操作流程区块 */}
      <section style={{background: '#fff', padding: '48px 0'}}>
        <div style={{maxWidth: 900, margin: '0 auto', textAlign: 'center'}}>
          <h3 style={{fontSize: 24, fontWeight: 700, marginBottom: 32, color: '#A67C52'}}>{t('home.newUserGuide')}</h3>
          <div style={{display: 'flex', justifyContent: 'center', gap: 40, flexWrap: 'wrap'}}>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#8b5cf6', marginBottom: 8}}>📝</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>1. {t('home.step1')}</div>
              <div style={{color: '#888'}}>{t('home.step1Desc')}</div>
            </div>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#A67C52', marginBottom: 8}}>🔍</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>2. {t('home.step2')}</div>
              <div style={{color: '#888'}}>{t('home.step2Desc')}</div>
            </div>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#A67C52', marginBottom: 8}}>🤝</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>3. {t('home.step3')}</div>
              <div style={{color: '#888'}}>{t('home.step3Desc')}</div>
            </div>
            <div style={{minWidth: 180}}>
              <div style={{fontSize: 32, color: '#A67C52', marginBottom: 8}}>💬</div>
              <div style={{fontWeight: 600, marginBottom: 4, color: '#A67C52'}}>4. {t('home.step4')}</div>
              <div style={{color: '#888'}}>{t('home.step4Desc')}</div>
            </div>
          </div>
        </div>
      </section>
      {/* 用户反馈/平台公告区块 */}
      <section style={{background: '#f8fbff', padding: '48px 0'}}>
        <div style={{maxWidth: 900, margin: '0 auto', textAlign: 'center'}}>
          <h3 style={{fontSize: 24, fontWeight: 700, marginBottom: 32, color: '#A67C52'}}>用户反馈 & 平台公告</h3>
          <div style={{display: 'flex', justifyContent: 'center', gap: 40, flexWrap: 'wrap'}}>
            <div style={{minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 24, marginBottom: 16, borderLeft: '6px solid #A67C52'}}>
              <div style={{fontWeight: 600, marginBottom: 8, color: '#A67C52'}}>“平台很靠谱，接单流程很顺畅！”</div>
              <div style={{color: '#888'}}>—— 用户A</div>
            </div>
            <div style={{minWidth: 260, background: '#fff', borderRadius: 8, boxShadow: '0 2px 8px #e6f7ff', padding: 24, marginBottom: 16, borderLeft: '6px solid #8b5cf6'}}>
              <div style={{fontWeight: 600, marginBottom: 8, color: '#A67C52'}}>“任务种类多，结算也很安全。”</div>
              <div style={{color: '#888'}}>—— 用户B</div>
            </div>
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