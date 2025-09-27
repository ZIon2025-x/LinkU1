import React, { useEffect, useState } from 'react';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings } from '../api';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

// 添加可爱的动画样式
const bellStyles = `
  @keyframes bellShake {
    0%, 100% { transform: rotate(0deg); }
    10%, 30%, 50%, 70%, 90% { transform: rotate(5deg); }
    20%, 40%, 60%, 80% { transform: rotate(-5deg); }
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }
  @keyframes bounce {
    0%, 20%, 50%, 80%, 100% { transform: translateY(0); }
    40% { transform: translateY(-3px); }
    60% { transform: translateY(-2px); }
  }
  
  /* VIP任务动画 */
  @keyframes vipGlow {
    0%, 100% { 
      box-shadow: 0 4px 15px rgba(245, 158, 11, 0.2);
    }
    50% { 
      box-shadow: 0 6px 20px rgba(245, 158, 11, 0.4);
    }
  }
  
  /* 超级任务动画 */
  @keyframes superPulse {
    0%, 100% { 
      box-shadow: 0 4px 20px rgba(139, 92, 246, 0.3);
    }
    50% { 
      box-shadow: 0 8px 25px rgba(139, 92, 246, 0.5);
    }
  }
`;

// 注入样式到页面
if (typeof document !== 'undefined') {
  const styleElement = document.createElement('style');
  styleElement.textContent = bellStyles;
  document.head.appendChild(styleElement);
}

interface Notification {
  id: number;
  type: string;
  title: string;
  content: string;
  related_id?: number;
  is_read: number;
  created_at: string;
}

// 剩余时间计算函数 - 使用本地时间
function getRemainTime(deadline: string) {
  const now = dayjs();
  const end = dayjs(deadline).local();
  const diff = end.diff(now, 'minute');
  
  if (diff <= 0) return "已过期";
  
  const hours = Math.floor(diff / 60);
  const minutes = diff % 60;
  
  if (hours > 0) {
    return `${hours}小时${minutes}分钟`;
  }
  return `${minutes}分钟`;
}

// 检查是否即将过期 - 使用本地时间
function isExpiringSoon(deadline: string) {
  const now = dayjs();
  const end = dayjs(deadline).local();
  const oneDayLater = now.add(1, 'day');
  
  return now.isBefore(end) && end.isBefore(oneDayLater);
}

// 检查是否已过期 - 使用本地时间
function isExpired(deadline: string) {
  const now = dayjs();
  const end = dayjs(deadline).local();
  return now.isAfter(end);
}

export const TASK_TYPES = [
  "Housekeeping", "Campus Life", "Second-hand & Rental", "Errand Running", "Skill Service", "Social Help", "Transportation", "Pet Care", "Life Convenience", "Other"
];

export const CITIES = [
  "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

const Tasks: React.FC = () => {
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [type, setType] = useState('全部类型');
  const [city, setCity] = useState('全部城市');
  const [keyword, setKeyword] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize] = useState(12);
  const [total, setTotal] = useState(0);
  const [user, setUser] = useState<any>(null);
  const [sortBy, setSortBy] = useState('latest'); // latest, reward_asc, reward_desc, deadline_asc, deadline_desc
  const [userLocation, setUserLocation] = useState('London, UK'); // 用户当前位置
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);
  
  // 用户菜单和通知相关状态
  const [showMenu, setShowMenu] = useState(false);
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
  
  const navigate = useNavigate();

  // 加载用户信息
  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        console.log('Tasks页面获取用户资料成功:', userData);
        setUser(userData);
        
        // 设置用户位置
        if (userData && userData.location) {
          setUserLocation(userData.location);
        }
      } catch (error: any) {
        console.error('Tasks页面加载用户信息失败:', error);
        console.log('错误详情:', error.response?.status, error.response?.data);
        // 如果获取用户信息失败，设置为未登录状态
        setUser(null);
      }
    };
    
    // 添加短暂延迟，确保页面完全加载后再获取用户资料
    const timer = setTimeout(loadUser, 100);
    return () => clearTimeout(timer);
  }, []);

  // 加载通知和系统设置
  useEffect(() => {
    const loadNotificationsAndSettings = async () => {
      if (user) {
        try {
          // 加载通知
          const [notificationsData, unreadCountData, settingsData] = await Promise.all([
            getNotifications(),
            getUnreadNotificationCount(),
            getPublicSystemSettings()
          ]);
          
          setNotifications(notificationsData);
          setUnreadCount(unreadCountData.count);
          setSystemSettings(settingsData);
        } catch (error) {
          console.error('加载通知或系统设置失败:', error);
        }
      }
    };
    
    loadNotificationsAndSettings();
  }, [user]);

  // 加载任务列表
  const loadTasks = async () => {
    setLoading(true);
    try {
      const params = {
        page: page,
        page_size: pageSize,
        ...(type !== '全部类型' && { task_type: type }),
        ...(city !== '全部城市' && { location: city }),
        ...(keyword && { keyword }),
        sort_by: sortBy,
      };
      
      const response = await api.get('/api/tasks', { params });
      const data = response.data;
      
      setTasks(data.tasks || []);
      setTotal(data.total || 0);
    } catch (error) {
      console.error('加载任务失败:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadTasks();
  }, [page, type, city, keyword, sortBy]);

  // 点击外部关闭位置下拉菜单
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('[data-location-dropdown]')) {
        setShowLocationDropdown(false);
      }
    };

    if (showLocationDropdown) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showLocationDropdown]);

  // 处理位置切换
  const handleLocationChange = (newLocation: string) => {
    setUserLocation(newLocation);
    setShowLocationDropdown(false);
    // 可以根据位置重新加载任务
    setPage(1);
  };

  // 处理通知标记为已读
  const handleMarkAsRead = async (notificationId: number) => {
    try {
      await markNotificationRead(notificationId);
      setNotifications(prev => 
        prev.map(notif => 
          notif.id === notificationId ? { ...notif, is_read: 1 } : notif
        )
      );
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch (error) {
      console.error('标记通知为已读失败:', error);
    }
  };

  // 处理标记所有通知为已读
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setNotifications(prev => 
        prev.map(notif => ({ ...notif, is_read: 1 }))
      );
      setUnreadCount(0);
    } catch (error) {
      console.error('标记所有通知为已读失败:', error);
    }
  };

  // 处理任务接受
  const handleAcceptTask = async (taskId: number) => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }

    try {
      const response = await fetch(`http://localhost:8000/api/tasks/${taskId}/accept`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',  // 使用Cookie认证
      });

      const data = await response.json();
      
      if (response.ok) {
        alert('任务接受成功！');
        loadTasks(); // 重新加载任务列表
      } else {
        alert(data.detail || '接受任务失败');
      }
    } catch (error) {
      console.error('接受任务失败:', error);
      alert('接受任务失败');
    }
  };

  // 处理任务详情查看
  const handleViewTask = (taskId: number) => {
    navigate(`/tasks/${taskId}`);
  };

  // 处理联系发布者
  const handleContactPoster = (taskId: number) => {
    navigate(`/message?uid=${taskId}`);
  };

  // 获取任务等级颜色
  const getTaskLevelColor = (taskLevel: string) => {
    switch (taskLevel) {
      case 'super':
        return '#8b5cf6';
      case 'vip':
        return '#f59e0b';
      case 'normal':
      default:
        return '#95a5a6';
    }
  };

  // 获取任务等级标签
  const getTaskLevelLabel = (taskLevel: string) => {
    switch (taskLevel) {
      case 'super':
        return '超级VIP';
      case 'vip':
        return 'VIP';
      case 'normal':
      default:
        return '普通';
    }
  };

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#f5f5f5'
    }}>
      {/* 顶部导航栏 */}
      <header style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        background: '#fff',
        zIndex: 100,
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        padding: '12px 16px'
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          maxWidth: '1200px',
          margin: '0 auto'
        }}>
          {/* Logo */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}>
            <div 
              style={{
                fontWeight: 'bold',
                fontSize: '24px',
                color: '#6EC1E4',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                padding: '4px 8px',
                borderRadius: '8px'
              }}
              onClick={() => navigate('/')}
              onMouseEnter={(e) => {
                e.currentTarget.style.color = '#4A90E2';
                e.currentTarget.style.background = 'rgba(110, 193, 228, 0.1)';
                e.currentTarget.style.transform = 'scale(1.05)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.color = '#6EC1E4';
                e.currentTarget.style.background = 'transparent';
                e.currentTarget.style.transform = 'scale(1)';
              }}
            >
              LinkU
            </div>
          </div>

          {/* 导航菜单 */}
          <nav style={{ display: 'flex', gap: '24px' }}>
            <button 
              onClick={() => navigate('/tasks')} 
              style={{ 
                color: '#A67C52', 
                fontWeight: 600, 
                background: 'none', 
                border: 'none', 
                cursor: 'pointer', 
                fontSize: 'inherit' 
              }}
            >
              任务大厅
            </button>
            <button 
              onClick={() => navigate('/publish')} 
              style={{ 
                color: '#A67C52', 
                fontWeight: 600, 
                background: 'none', 
                border: 'none', 
                cursor: 'pointer', 
                fontSize: 'inherit' 
              }}
            >
              发布任务
            </button>
            <button 
              onClick={() => navigate('/join-us')} 
              style={{ 
                color: '#A67C52', 
                fontWeight: 600, 
                background: 'none', 
                border: 'none', 
                cursor: 'pointer', 
                fontSize: 'inherit' 
              }}
            >
              加入我们
            </button>
            <button 
              onClick={() => navigate('/about')} 
              style={{ 
                color: '#A67C52', 
                fontWeight: 600, 
                background: 'none', 
                border: 'none', 
                cursor: 'pointer', 
                fontSize: 'inherit' 
              }}
            >
              关于我们
            </button>
          </nav>

          {/* 位置信息 */}
          <div 
            style={{
              position: 'relative'
            }}
            data-location-dropdown
          >
            <div 
              onClick={() => setShowLocationDropdown(!showLocationDropdown)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                color: '#6b7280',
                fontSize: '14px',
                cursor: 'pointer',
                padding: '8px 12px',
                borderRadius: '6px',
                transition: 'all 0.2s ease',
                background: showLocationDropdown ? '#f3f4f6' : 'transparent'
              }}
              onMouseEnter={(e) => {
                if (!showLocationDropdown) {
                  e.currentTarget.style.background = '#f3f4f6';
                }
              }}
              onMouseLeave={(e) => {
                if (!showLocationDropdown) {
                  e.currentTarget.style.background = 'transparent';
                }
              }}
            >
              <span>📍</span>
              <span>{userLocation}</span>
              <span style={{
                transform: showLocationDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                transition: 'transform 0.2s ease'
              }}>▼</span>
            </div>
            
            {/* 位置下拉菜单 */}
            {showLocationDropdown && (
              <div style={{
                position: 'absolute',
                top: '100%',
                left: '0',
                right: '0',
                background: '#fff',
                border: '1px solid #e5e7eb',
                borderRadius: '8px',
                boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                zIndex: 1000,
                marginTop: '4px',
                maxHeight: '200px',
                overflowY: 'auto'
              }}>
                {CITIES.map((cityName) => (
                  <div
                    key={cityName}
                    onClick={() => handleLocationChange(cityName)}
                    style={{
                      padding: '12px 16px',
                      cursor: 'pointer',
                      fontSize: '14px',
                      color: '#374151',
                      borderBottom: '1px solid #f3f4f6',
                      transition: 'background 0.2s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = '#f9fafb';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'transparent';
                    }}
                  >
                    {cityName}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* 搜索框 */}
          <div style={{
            position: 'relative',
            flex: '1',
            maxWidth: '300px',
            margin: '0 16px'
          }}>
            <input
              type="text"
              placeholder="搜索任务..."
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
              style={{
                width: '100%',
                padding: '10px 16px 10px 40px',
                border: '1px solid #e5e7eb',
                borderRadius: '20px',
                fontSize: '14px',
                background: '#f9fafb',
                outline: 'none'
              }}
            />
            <div style={{
              position: 'absolute',
              left: '12px',
              top: '50%',
              transform: 'translateY(-50%)',
              color: '#6b7280',
              fontSize: '16px'
            }}>
              🔍
            </div>
          </div>

          {/* 用户菜单 */}
          <div style={{
            position: 'relative',
            display: 'flex',
            alignItems: 'center',
            gap: '16px'
          }}>
            {user ? (
              <>
                {/* 可爱的卡通铃铛图标 */}
                <div className="bell-icon" style={{position: 'relative', cursor: 'pointer'}} onClick={() => { setShowNotifications(prev => !prev); setShowMenu(false); }}>
                  <div style={{
                    width: 40,
                    height: 40,
                    background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: '0 6px 12px rgba(255, 215, 0, 0.4), inset 0 2px 4px rgba(255,255,255,0.3)',
                    border: '3px solid #FFF',
                    position: 'relative',
                    animation: unreadCount > 0 ? 'bellShake 2s infinite' : 'none',
                    transition: 'all 0.3s ease',
                    cursor: 'pointer'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'scale(1.15) rotate(5deg)';
                    e.currentTarget.style.boxShadow = '0 8px 16px rgba(255, 215, 0, 0.6), inset 0 2px 4px rgba(255,255,255,0.3)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = unreadCount > 0 ? 'scale(1)' : 'scale(1)';
                    e.currentTarget.style.boxShadow = '0 6px 12px rgba(255, 215, 0, 0.4), inset 0 2px 4px rgba(255,255,255,0.3)';
                  }}
                  >
                    <div style={{
                      fontSize: 20,
                      color: '#8B4513',
                      fontWeight: 'bold',
                      textShadow: '2px 2px 4px rgba(255,255,255,0.9)',
                      filter: 'drop-shadow(1px 1px 2px rgba(0,0,0,0.1))'
                    }}>
                      🔔
                    </div>
                    {/* 铃铛的装饰小点 */}
                    <div style={{
                      position: 'absolute',
                      top: 3,
                      right: 3,
                      width: 5,
                      height: 5,
                      background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
                      borderRadius: '50%',
                      boxShadow: '0 0 6px rgba(255, 107, 107, 0.8), inset 0 1px 2px rgba(255,255,255,0.3)',
                      animation: 'pulse 2s infinite'
                    }} />
                    {/* 铃铛的光晕效果 */}
                    <div style={{
                      position: 'absolute',
                      top: -2,
                      left: -2,
                      right: -2,
                      bottom: -2,
                      background: 'radial-gradient(circle, rgba(255,215,0,0.2) 0%, transparent 70%)',
                      borderRadius: '50%',
                      animation: unreadCount > 0 ? 'pulse 3s infinite' : 'none'
                    }} />
                  </div>
                  
                  {unreadCount > 0 && (
                    <div style={{
                      position: 'absolute',
                      top: -6,
                      right: -6,
                      background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
                      color: 'white',
                      borderRadius: '50%',
                      width: 22,
                      height: 22,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: 11,
                      fontWeight: 'bold',
                      border: '3px solid #fff',
                      boxShadow: '0 3px 6px rgba(255, 107, 107, 0.4), 0 0 0 2px rgba(255, 107, 107, 0.2)',
                      animation: 'pulse 1.5s infinite'
                    }}>
                      {unreadCount > 99 ? '99+' : unreadCount}
                    </div>
                  )}
                </div>
                
                {/* 可爱的通知弹窗 */}
                {showNotifications && (
                  <div className="notification-container" style={{
                    position: 'absolute',
                    right: 0,
                    top: 48,
                    background: 'linear-gradient(135deg, #fff 0%, #f8f9fa 100%)',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.15), 0 4px 8px rgba(255, 215, 0, 0.1)',
                    borderRadius: 16,
                    minWidth: 320,
                    maxWidth: 400,
                    maxHeight: 400,
                    overflowY: 'auto',
                    zIndex: 1000,
                    border: '2px solid rgba(255, 215, 0, 0.2)',
                    animation: 'bounce 0.5s ease-out'
                  }}>
                    <div style={{
                      padding: '16px 20px',
                      borderBottom: '2px solid rgba(255, 215, 0, 0.2)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      background: 'linear-gradient(135deg, rgba(255, 215, 0, 0.05) 0%, rgba(255, 215, 0, 0.1) 100%)'
                    }}>
                      <span style={{
                        fontWeight: 700, 
                        color: '#A67C52',
                        fontSize: 16,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8
                      }}>
                        🔔 通知
                      </span>
                      <div style={{display: 'flex', gap: 8}}>
                        {unreadCount > 0 && (
                          <button
                            onClick={handleMarkAllRead}
                            style={{
                              background: 'linear-gradient(135deg, #6EC1E4, #4A90E2)',
                              border: 'none',
                              color: 'white',
                              fontSize: 12,
                              cursor: 'pointer',
                              padding: '6px 12px',
                              borderRadius: 12,
                              fontWeight: 600,
                              boxShadow: '0 2px 4px rgba(110, 193, 228, 0.3)',
                              transition: 'all 0.2s ease'
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.transform = 'scale(1.05)';
                              e.currentTarget.style.boxShadow = '0 4px 8px rgba(110, 193, 228, 0.4)';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.transform = 'scale(1)';
                              e.currentTarget.style.boxShadow = '0 2px 4px rgba(110, 193, 228, 0.3)';
                            }}
                          >
                            全部已读
                          </button>
                        )}
                        <button
                          onClick={() => setShowNotifications(false)}
                          style={{
                            background: 'transparent',
                            border: 'none',
                            color: '#A67C52',
                            fontSize: 18,
                            cursor: 'pointer',
                            padding: '4px',
                            borderRadius: 4,
                            transition: 'all 0.2s ease'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = 'rgba(166, 124, 82, 0.1)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = 'transparent';
                          }}
                        >
                          ✕
                        </button>
                      </div>
                    </div>
                    <div style={{maxHeight: 300, overflowY: 'auto'}}>
                      {notifications.length === 0 ? (
                        <div style={{
                          padding: '40px 20px',
                          textAlign: 'center',
                          color: '#888',
                          fontSize: 14
                        }}>
                          <div style={{fontSize: 32, marginBottom: 8}}>🔔</div>
                          暂无通知
                        </div>
                      ) : (
                        notifications.map((notification) => (
                          <div
                            key={notification.id}
                            onClick={() => {
                              if (notification.is_read === 0) {
                                handleMarkAsRead(notification.id);
                              }
                            }}
                            style={{
                              padding: '16px 20px',
                              borderBottom: '1px solid #f0f0f0',
                              cursor: 'pointer',
                              background: notification.is_read === 0 ? 'rgba(255, 215, 0, 0.05)' : 'transparent',
                              transition: 'all 0.2s ease',
                              position: 'relative'
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.background = notification.is_read === 0 ? 'rgba(255, 215, 0, 0.1)' : 'rgba(0,0,0,0.02)';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.background = notification.is_read === 0 ? 'rgba(255, 215, 0, 0.05)' : 'transparent';
                            }}
                          >
                            {notification.is_read === 0 && (
                              <div style={{
                                position: 'absolute',
                                left: 8,
                                top: '50%',
                                transform: 'translateY(-50%)',
                                width: 8,
                                height: 8,
                                background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
                                borderRadius: '50%',
                                animation: 'pulse 2s infinite'
                              }} />
                            )}
                            <div style={{
                              fontWeight: notification.is_read === 0 ? 700 : 500,
                              color: '#333',
                              fontSize: 14,
                              marginBottom: 4,
                              paddingLeft: notification.is_read === 0 ? 16 : 0
                            }}>
                              {notification.title}
                            </div>
                            <div style={{
                              color: '#666',
                              fontSize: 12,
                              lineHeight: 1.4,
                              paddingLeft: notification.is_read === 0 ? 16 : 0
                            }}>
                              {notification.content}
                            </div>
                            <div style={{
                              color: '#999',
                              fontSize: 11,
                              marginTop: 6,
                              paddingLeft: notification.is_read === 0 ? 16 : 0
                            }}>
                              {dayjs(notification.created_at).tz('Europe/London').format('MM-DD HH:mm')} (英国时间)
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                )}
                
                <img
                  src={user.avatar || '/avatar1.png'}
                  alt="头像"
                  style={{width: 38, height: 38, borderRadius: '50%', border: '2px solid #6EC1E4', background: '#f8fbff', objectFit: 'cover', verticalAlign: 'middle', cursor: 'pointer'}}
                  onClick={() => { setShowMenu(prev => !prev); setShowNotifications(false); }}
                />
                {showMenu && (
                  <div className="avatar-menu" style={{position: 'absolute', right: 0, top: 48, background: '#fff', boxShadow: '0 2px 8px #e6f7ff', borderRadius: 8, minWidth: 160, zIndex: 999}}>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/my-tasks'); }}>我的任务</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/message'); }}>我的信息</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/profile'); }}>个人主页</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/wallet'); }}>💰 我的钱包</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#A67C52', fontWeight: 600}} onClick={() => { setShowMenu(false); navigate('/settings'); }}>⚙️ 设置</div>
                    <div style={{padding: '10px 20px', cursor: 'pointer', color: '#d32f2f', fontWeight: 600, borderTop: '1px solid #eee'}} onClick={async () => { 
                      setShowMenu(false); 
                      // 调用后端登出接口清除HttpOnly Cookie
                      try {
                        await api.post('/api/users/logout');
                      } catch (error) {
                        console.log('登出请求失败:', error);
                      }
                      window.location.reload(); 
                    }}>退出登录</div>
                  </div>
                )}
                
                {/* VIP按钮 - 根据系统设置显示 */}
                {systemSettings.vip_button_visible && (
                  <button 
                    onClick={() => navigate('/vip')} 
                    style={{
                      padding: '8px 16px',
                      background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '20px',
                      fontSize: '14px',
                      fontWeight: 'bold',
                      cursor: 'pointer',
                      boxShadow: '0 2px 8px rgba(255, 215, 0, 0.3)',
                      transition: 'all 0.3s ease',
                      textShadow: '0 1px 2px rgba(0,0,0,0.2)'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'translateY(-2px)';
                      e.currentTarget.style.boxShadow = '0 4px 12px rgba(255, 215, 0, 0.4)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 2px 8px rgba(255, 215, 0, 0.3)';
                    }}
                  >
                    ✨ VIP
                  </button>
                )}
              </>
            ) : (
              <>
                <button 
                  onClick={() => setShowLoginModal(true)}
                  style={{
                    color: '#A67C52', 
                    fontWeight: 600, 
                    background: 'none', 
                    border: 'none', 
                    cursor: 'pointer', 
                    fontSize: 'inherit'
                  }}
                >
                  登录
                </button>
              </>
            )}
          </div>
        </div>
      </header>

      {/* 主要内容区域 */}
      <div style={{
        marginTop: '80px',
        padding: '16px'
      }}>
        <div style={{
          maxWidth: '1200px',
          margin: '0 auto'
        }}>
          {/* 分类图标行 */}
          <div style={{
            background: '#fff',
            borderRadius: '12px',
            padding: '16px',
            marginBottom: '16px',
            boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
          }}>
            <div style={{
              display: 'flex',
              gap: '12px',
              justifyContent: 'space-between',
              paddingBottom: '8px',
              flexWrap: 'wrap'
            }}>
              {TASK_TYPES.slice(0, 10).map((taskType, index) => (
                <div
                  key={taskType}
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: '8px',
                    flex: '1',
                    minWidth: '80px',
                    maxWidth: '120px',
                    cursor: 'pointer',
                    padding: '8px',
                    borderRadius: '8px',
                    transition: 'all 0.2s ease'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = '#f3f4f6';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'transparent';
                  }}
                  onClick={() => setType(taskType)}
                >
                  <div style={{
                    width: '48px',
                    height: '48px',
                    background: `linear-gradient(135deg, ${['#ef4444', '#f59e0b', '#10b981', '#3b82f6', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16'][index]}, ${['#dc2626', '#d97706', '#059669', '#2563eb', '#7c3aed', '#db2777', '#0891b2', '#65a30d'][index]})`,
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '20px',
                    color: '#fff'
                  }}>
                    {['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'][index]}
                  </div>
                  <span style={{
                    fontSize: '12px',
                    color: '#374151',
                    textAlign: 'center',
                    fontWeight: '500'
                  }}>
                    {taskType}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* 排序按钮行 */}
          <div style={{
            background: '#fff',
            borderRadius: '12px',
            padding: '16px',
            marginBottom: '16px',
            boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
          }}>
            <div style={{
              display: 'flex',
              gap: '12px',
              overflowX: 'auto',
              paddingBottom: '8px'
            }}>
              {[
                { key: 'latest', label: '最新发布', icon: '🕒' },
                { key: 'reward_desc', label: '金额降序', icon: '💰' },
                { key: 'reward_asc', label: '金额升序', icon: '💰' },
                { key: 'deadline_asc', label: '截止时间升序', icon: '⏰' },
                { key: 'deadline_desc', label: '截止时间降序', icon: '⏰' }
              ].map((sortOption) => (
                <button
                  key={sortOption.key}
                  onClick={() => setSortBy(sortOption.key)}
                  style={{
                    background: sortBy === sortOption.key ? '#3b82f6' : '#f3f4f6',
                    color: sortBy === sortOption.key ? '#fff' : '#374151',
                    border: 'none',
                    padding: '8px 16px',
                    borderRadius: '20px',
                    fontSize: '14px',
                    fontWeight: '500',
                    cursor: 'pointer',
                    whiteSpace: 'nowrap',
                    transition: 'all 0.2s ease',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px'
                  }}
                >
                  <span>{sortOption.icon}</span>
                  <span>{sortOption.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* 自动取消过期任务提示 */}
          <div style={{
            background: 'linear-gradient(135deg, #fff3cd, #ffeaa7)',
            border: '1px solid #ffc107',
            borderRadius: '12px',
            padding: '16px',
            marginBottom: '16px',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
          }}>
            <span style={{fontSize: '20px'}}>⏰</span>
            <span style={{color: '#856404', fontSize: '14px', fontWeight: '500'}}>
              系统会自动取消超过截止日期的任务，确保任务时效性
            </span>
          </div>

          {/* 任务列表 */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
            gap: '16px'
          }}>
            {loading ? (
              <div style={{ 
                gridColumn: '1 / -1',
                textAlign: 'center', 
                padding: '80px 20px',
                color: '#6b7280'
              }}>
                <div style={{ fontSize: 48, marginBottom: 16 }}>⏳</div>
                <div>加载中...</div>
              </div>
            ) : tasks.length === 0 ? (
              <div style={{ 
                gridColumn: '1 / -1',
                textAlign: 'center', 
                padding: '80px 20px',
                color: '#6b7280'
              }}>
                <div style={{ fontSize: 48, marginBottom: 16 }}>📝</div>
                <div>暂无任务</div>
              </div>
            ) : (
              tasks.map(task => (
                <div
                  key={task.id}
                  style={{
                    background: '#fff',
                    borderRadius: '12px',
                    overflow: 'hidden',
                    transition: 'all 0.2s ease',
                    cursor: 'pointer',
                    boxShadow: task.task_level === 'vip' ? '0 4px 15px rgba(245, 158, 11, 0.2)' : 
                               task.task_level === 'super' ? '0 4px 20px rgba(139, 92, 246, 0.3)' : 
                               '0 2px 8px rgba(0,0,0,0.05)',
                    border: task.task_level === 'vip' ? '2px solid #f59e0b' : 
                           task.task_level === 'super' ? '2px solid #8b5cf6' : 
                           '1px solid #e5e7eb',
                    animation: task.task_level === 'vip' ? 'vipGlow 4s infinite' : 
                              task.task_level === 'super' ? 'superPulse 3s infinite' : 'none'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateY(-2px)';
                    if (task.task_level === 'vip') {
                      e.currentTarget.style.boxShadow = '0 6px 20px rgba(245, 158, 11, 0.4)';
                    } else if (task.task_level === 'super') {
                      e.currentTarget.style.boxShadow = '0 8px 25px rgba(139, 92, 246, 0.5)';
                    } else {
                      e.currentTarget.style.boxShadow = '0 4px 16px rgba(0,0,0,0.1)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    if (task.task_level === 'vip') {
                      e.currentTarget.style.boxShadow = '0 4px 15px rgba(245, 158, 11, 0.2)';
                    } else if (task.task_level === 'super') {
                      e.currentTarget.style.boxShadow = '0 4px 20px rgba(139, 92, 246, 0.3)';
                    } else {
                      e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
                    }
                  }}
                >
                  {/* 任务图片区域 */}
                  <div style={{
                    height: '120px',
                    background: `linear-gradient(135deg, ${getTaskLevelColor(task.task_level)}20, ${getTaskLevelColor(task.task_level)}40)`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    position: 'relative',
                    overflow: 'hidden'
                  }}>
                    <div style={{
                      fontSize: '48px',
                      opacity: 0.7
                    }}>
                      {['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'][TASK_TYPES.indexOf(task.task_type) % 10]}
                    </div>
                    <div style={{
                      position: 'absolute',
                      top: '12px',
                      right: '12px',
                      background: getTaskLevelColor(task.task_level),
                      color: '#fff',
                      padding: '4px 8px',
                      borderRadius: '12px',
                      fontSize: '12px',
                      fontWeight: '600',
                      boxShadow: task.task_level === 'vip' ? '0 2px 8px rgba(245, 158, 11, 0.3)' : 
                                task.task_level === 'super' ? '0 2px 10px rgba(139, 92, 246, 0.4)' : 'none'
                    }}>
                      {getTaskLevelLabel(task.task_level)}
                    </div>
                  </div>

                  {/* 任务信息 */}
                  <div style={{
                    padding: '16px'
                  }}>
                    <h3 style={{
                      margin: '0 0 8px 0',
                      fontSize: '16px',
                      fontWeight: '600',
                      color: '#1f2937',
                      lineHeight: '1.4'
                    }}>
                      {task.title}
                    </h3>
                    
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      marginBottom: '8px',
                      fontSize: '12px',
                      color: '#6b7280'
                    }}>
                      <span>📍 {task.location}</span>
                      <span>•</span>
                      <span>🏷️ {task.task_type}</span>
                    </div>
                    
                    <div style={{
                      fontSize: '14px',
                      color: '#4b5563',
                      lineHeight: '1.4',
                      marginBottom: '12px',
                      display: '-webkit-box',
                      WebkitLineClamp: 2,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden'
                    }}>
                      {task.description}
                    </div>

                    {/* 底部信息 */}
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '12px'
                    }}>
                      <div style={{
                        fontSize: '18px',
                        fontWeight: '700',
                        color: '#059669'
                      }}>
                        £{task.reward.toFixed(2)}
                      </div>
                      <div style={{
                        fontSize: '12px',
                        color: isExpired(task.deadline) ? '#ef4444' : 
                               isExpiringSoon(task.deadline) ? '#f59e0b' : '#6b7280'
                      }}>
                        {isExpired(task.deadline) ? '已过期' : 
                         isExpiringSoon(task.deadline) ? '即将过期' : getRemainTime(task.deadline)}
                      </div>
                    </div>
                    
                    {/* 操作按钮 */}
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleViewTask(task.id);
                        }}
                        style={{
                          flex: 1,
                          padding: '8px 12px',
                          border: '1px solid #3b82f6',
                          borderRadius: '6px',
                          background: 'transparent',
                          color: '#3b82f6',
                          cursor: 'pointer',
                          fontSize: '14px',
                          fontWeight: '500',
                          transition: 'all 0.2s ease'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.background = '#3b82f6';
                          e.currentTarget.style.color = '#fff';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.background = 'transparent';
                          e.currentTarget.style.color = '#3b82f6';
                        }}
                      >
                        查看详情
                      </button>
                      
                      {task.status === 'open' && user && user.id !== task.poster_id && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleAcceptTask(task.id);
                          }}
                          style={{
                            flex: 1,
                            padding: '8px 12px',
                            border: 'none',
                            borderRadius: '6px',
                            background: '#10b981',
                            color: '#fff',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: '500',
                            transition: 'all 0.2s ease'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#059669';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#10b981';
                          }}
                        >
                          接受任务
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* 分页 */}
          {total > pageSize && (
            <div style={{
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              gap: '12px',
              marginTop: '32px',
              padding: '16px',
              background: '#fff',
              borderRadius: '12px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
            }}>
              <button
                onClick={() => setPage(prev => Math.max(1, prev - 1))}
                disabled={page === 1}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '8px',
                  background: page === 1 ? '#f3f4f6' : '#3b82f6',
                  color: page === 1 ? '#9ca3af' : '#fff',
                  cursor: page === 1 ? 'not-allowed' : 'pointer',
                  fontSize: '14px',
                  fontWeight: '500',
                  transition: 'all 0.2s ease'
                }}
              >
                ← 上一页
              </button>
              
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '0 16px'
              }}>
                {Array.from({ length: Math.min(5, Math.ceil(total / pageSize)) }, (_, i) => {
                  const pageNum = i + 1;
                  const isActive = pageNum === page;
                  return (
                    <button
                      key={pageNum}
                      onClick={() => setPage(pageNum)}
                      style={{
                        width: '32px',
                        height: '32px',
                        border: 'none',
                        borderRadius: '6px',
                        background: isActive ? '#3b82f6' : 'transparent',
                        color: isActive ? '#fff' : '#6b7280',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: '500',
                        transition: 'all 0.2s ease'
                      }}
                    >
                      {pageNum}
                    </button>
                  );
                })}
              </div>
              
              <button
                onClick={() => setPage(prev => prev + 1)}
                disabled={page >= Math.ceil(total / pageSize)}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '8px',
                  background: page >= Math.ceil(total / pageSize) ? '#f3f4f6' : '#3b82f6',
                  color: page >= Math.ceil(total / pageSize) ? '#9ca3af' : '#fff',
                  cursor: page >= Math.ceil(total / pageSize) ? 'not-allowed' : 'pointer',
                  fontSize: '14px',
                  fontWeight: '500',
                  transition: 'all 0.2s ease'
                }}
              >
                下一页 →
              </button>
            </div>
          )}
        </div>
      </div>
      
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

export default Tasks;
