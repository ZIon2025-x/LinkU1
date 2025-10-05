import React, { useEffect, useState, useCallback } from 'react';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout } from '../api';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import { useLanguage } from '../contexts/LanguageContext';

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
  
  // 添加自定义下拉菜单样式
  const dropdownStyles = `
    /* 自定义下拉菜单样式 */
    .custom-select {
      position: relative;
      display: inline-block;
    }
    
    .custom-select select {
      appearance: none;
      -webkit-appearance: none;
      -moz-appearance: none;
      background: transparent;
      border: none;
      outline: none;
      cursor: pointer;
    }
    
    .custom-select select option {
      background: #ffffff;
      color: #374151;
      padding: 12px 16px;
      font-size: 14px;
      font-weight: 500;
      border: none;
      border-radius: 8px;
      margin: 2px 0;
      transition: all 0.2s ease;
    }
    
    .custom-select select option:hover {
      background: #f3f4f6;
      color: #1f2937;
    }
    
    .custom-select select option:checked {
      background: #3b82f6;
      color: #ffffff;
      font-weight: 600;
    }
    
    /* 美化select下拉箭头 */
    .custom-select::after {
      content: '▼';
      position: absolute;
      right: 16px;
      top: 50%;
      transform: translateY(-50%);
      color: #9ca3af;
      font-size: 12px;
      pointer-events: none;
      transition: color 0.3s ease;
    }
    
    .custom-select:hover::after {
      color: #6b7280;
    }
    
    /* 自定义下拉菜单容器 */
    .custom-dropdown {
      position: relative;
      display: inline-block;
    }
    
    .custom-dropdown-content {
      display: none;
      position: absolute;
      top: 100%;
      left: 0;
      right: 0;
      background: #ffffff;
      border: 1px solid #e5e7eb;
      border-radius: 12px;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
      z-index: 1000;
      margin-top: 4px;
      overflow: hidden;
      min-width: 200px;
    }
    
    .custom-dropdown-content.show {
      display: block;
      animation: dropdownFadeIn 0.2s ease-out;
    }
    
    .custom-dropdown-item {
      padding: 12px 16px;
      cursor: pointer;
      transition: all 0.2s ease;
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 14px;
      font-weight: 500;
      color: #374151;
      border-bottom: 1px solid #f3f4f6;
    }
    
    .custom-dropdown-item:last-child {
      border-bottom: none;
    }
    
    .custom-dropdown-item:hover {
      background: #f8fafc;
      color: #1f2937;
    }
    
    .custom-dropdown-item.selected {
      background: #3b82f6;
      color: #ffffff;
    }
    
    .custom-dropdown-item .icon {
      width: 20px;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 16px;
    }
    
    @keyframes dropdownFadeIn {
      from {
        opacity: 0;
        transform: translateY(-10px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
  `;
  
  const dropdownStyleElement = document.createElement('style');
  dropdownStyleElement.textContent = dropdownStyles;
  document.head.appendChild(dropdownStyleElement);
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
function getRemainTime(deadline: string, t: (key: string) => string) {
  const now = dayjs();
  const end = dayjs(deadline).local();
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

export const TASK_TYPES = [
  "Housekeeping", "Campus Life", "Second-hand & Rental", "Errand Running", "Skill Service", "Social Help", "Transportation", "Pet Care", "Life Convenience", "Other"
];

export const CITIES = [
  "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

const Tasks: React.FC = () => {
  const { t } = useLanguage();
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [type, setType] = useState('all');
  const [city, setCity] = useState('all');
  const [keyword, setKeyword] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize] = useState(12);
  const [total, setTotal] = useState(0);
  const [user, setUser] = useState<any>(null);
  const [sortBy, setSortBy] = useState('latest'); // latest, reward_asc, reward_desc, deadline_asc, deadline_desc
  const [rewardSort, setRewardSort] = useState(''); // '', 'asc', 'desc'
  const [deadlineSort, setDeadlineSort] = useState(''); // '', 'asc', 'desc'
  const [showRewardDropdown, setShowRewardDropdown] = useState(false);
  const [showDeadlineDropdown, setShowDeadlineDropdown] = useState(false);
  const [showLevelDropdown, setShowLevelDropdown] = useState(false);
  const [taskLevel, setTaskLevel] = useState('all');
  const [isMobile, setIsMobile] = useState(false);
  const [userLocation, setUserLocation] = useState('London, UK'); // 用户当前位置
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);

  // 检测屏幕尺寸
  useEffect(() => {
    const checkScreenSize = () => {
      setIsMobile(window.innerWidth <= 768);
    };
    
    checkScreenSize();
    window.addEventListener('resize', checkScreenSize);
    
    return () => window.removeEventListener('resize', checkScreenSize);
  }, []);

  // 点击外部区域关闭下拉菜单
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (showLocationDropdown && !target.closest('[data-location-dropdown]')) {
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

  // 处理金额排序变化
  const handleRewardSortChange = (value: string) => {
    setRewardSort(value);
    setDeadlineSort(''); // 清除截止日期排序
    if (value === '') {
      setSortBy('latest');
    } else {
      setSortBy(`reward_${value}`);
    }
  };

  // 处理截止日期排序变化
  const handleDeadlineSortChange = (value: string) => {
    setDeadlineSort(value);
    setRewardSort(''); // 清除金额排序
    if (value === '') {
      setSortBy('latest');
    } else {
      setSortBy(`deadline_${value}`);
    }
  };

  // 处理任务等级变化
  const handleLevelChange = (newLevel: string) => {
    setTaskLevel(newLevel);
    setShowLevelDropdown(false);
  };

  // 处理城市选择变化
  const handleLocationChange = (newCity: string) => {
    setCity(newCity); // 更新城市筛选状态
    if (newCity !== 'all') {
      setUserLocation(newCity); // 只有非"all"时才更新用户位置显示
    }
    setShowLocationDropdown(false);
    setPage(1); // 重置到第一页
  };
  
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
  
  // 任务详情弹窗状态
  const [showTaskDetailModal, setShowTaskDetailModal] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);
  
  // 已申请任务状态
  const [appliedTasks, setAppliedTasks] = useState<Set<number>>(new Set());
  
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
          // 加载通知 - 获取所有未读通知和最近10条已读通知
          const [notificationsData, unreadCountData, settingsData] = await Promise.all([
            getNotificationsWithRecentRead(10),
            getUnreadNotificationCount(),
            getPublicSystemSettings()
          ]);
          
          setNotifications(notificationsData);
          setUnreadCount(unreadCountData.unread_count);
          setSystemSettings(settingsData);
        } catch (error) {
          console.error('加载通知或系统设置失败:', error);
        }
      }
    };
    
    loadNotificationsAndSettings();
  }, [user]);

  // 加载任务列表
  const loadTasks = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        page: page,
        page_size: pageSize,
        ...(type !== 'all' && { task_type: type }),
        ...(city !== 'all' && { location: city }),
        ...(keyword && { keyword }),
        sort_by: sortBy,
      };
      
      console.log('Tasks页面请求参数:', params);
      console.log('当前城市状态:', city);
      
      const response = await api.get('/api/tasks', { params });
      const data = response.data;
      
      setTasks(data.tasks || []);
      setTotal(data.total || 0);
    } catch (error) {
      console.error('加载任务失败:', error);
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, type, city, keyword, sortBy]);

  useEffect(() => {
    loadTasks();
  }, [page, type, city, keyword, sortBy, loadTasks]);

  // 点击外部关闭下拉菜单
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('[data-location-dropdown]')) {
        setShowLocationDropdown(false);
      }
      if (!target.closest('.reward-dropdown-container')) {
        setShowRewardDropdown(false);
      }
      if (!target.closest('.deadline-dropdown-container')) {
        setShowDeadlineDropdown(false);
      }
      if (!target.closest('.level-dropdown-container')) {
        setShowLevelDropdown(false);
      }
    };

    if (showLocationDropdown || showRewardDropdown || showDeadlineDropdown || showLevelDropdown) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showLocationDropdown, showRewardDropdown, showDeadlineDropdown, showLevelDropdown]);


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
        alert(t('tasks.acceptSuccess'));
        // 将任务添加到已申请列表，隐藏申请按钮
        setAppliedTasks(prev => new Set([...Array.from(prev), taskId]));
        loadTasks(); // 重新加载任务列表
      } else {
        alert(data.detail || t('tasks.acceptFailed'));
      }
    } catch (error) {
      console.error('接受任务失败:', error);
      alert(t('tasks.acceptFailed'));
    }
  };

  // 处理任务详情查看
  const handleViewTask = (taskId: number) => {
    setSelectedTaskId(taskId);
    setShowTaskDetailModal(true);
  };

  // 处理联系发布者
  const handleContactPoster = (taskId: number) => {
    navigate(`/message?uid=${taskId}`);
  };

  // 检查用户是否可以查看/申请任务（等级匹配）
  const canViewTask = (user: any, task: any) => {
    if (!task) return false;
    
    // 如果用户未登录，只能查看普通任务
    if (!user) {
      return task.task_level === 'normal';
    }
    
    const levelHierarchy = { 'normal': 1, 'vip': 2, 'super': 3 };
    const userLevelValue = levelHierarchy[user.user_level as keyof typeof levelHierarchy] || 1;
    const taskLevelValue = levelHierarchy[task.task_level as keyof typeof levelHierarchy] || 1;
    
    return userLevelValue >= taskLevelValue;
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
        return t('home.superTask');
      case 'vip':
        return t('home.vipTask');
      case 'normal':
      default:
        return t('home.normalTask');
    }
  };

  // 任务等级筛选逻辑
  const getFilteredTasks = () => {
    let filtered = [...tasks];

    // 按任务等级筛选
    if (taskLevel !== 'all') {
      const levelMap: { [key: string]: string } = {
        [t('home.normalTask')]: 'normal',
        [t('home.vipTask')]: 'vip',
        [t('home.superTask')]: 'super'
      };
      
      const targetLevel = levelMap[taskLevel];
      if (targetLevel) {
        filtered = filtered.filter(task => task.task_level === targetLevel);
      }
    }

    // 按城市筛选
    if (city !== 'all') {
      filtered = filtered.filter(task => task.location === city);
    }

    // 按类型筛选
    if (type !== 'all') {
      filtered = filtered.filter(task => task.task_type === type);
    }

    // 按搜索关键词筛选
    if (keyword.trim()) {
      const query = keyword.toLowerCase();
      filtered = filtered.filter(task => 
        task.title.toLowerCase().includes(query) ||
        task.description.toLowerCase().includes(query) ||
        task.location.toLowerCase().includes(query)
      );
    }

    // 注意：排序应该在服务端进行，这里只进行筛选
    // 客户端排序会破坏服务端的分页排序逻辑

    return filtered;
  };

  // 获取筛选后的任务列表
  const filteredTasks = getFilteredTasks();

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#f5f5f5'
    }}>
      {/* 顶部导航栏 - 使用汉堡菜单 */}
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
        <div className="header-container" style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          maxWidth: '1200px',
          margin: '0 auto',
          gap: '8px',
          minHeight: '44px'
        }}>
          {/* Logo和位置信息 */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '16px',
            flexShrink: 0
        }}>
          {/* Logo */}
            <div 
            className="header-logo"
              style={{
                fontWeight: 'bold',
                fontSize: '24px',
                color: '#6EC1E4',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                padding: '4px 8px',
              borderRadius: '8px',
              flexShrink: 0
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

          {/* 位置信息 */}
          <div 
            className="location-container"
            style={{
              position: 'relative',
              flexShrink: 0
            }}
            data-location-dropdown
          >
            <div 
              onClick={() => setShowLocationDropdown(!showLocationDropdown)}
              style={{
                display: 'flex',
                alignItems: 'center',
                  gap: '6px',
                color: '#6b7280',
                fontSize: '14px',
                cursor: 'pointer',
                padding: '8px 12px',
                  borderRadius: '8px',
                transition: 'all 0.2s ease',
                  background: showLocationDropdown ? '#f3f4f6' : 'transparent',
                  border: '1px solid #e5e7eb'
              }}
              onMouseEnter={(e) => {
                if (!showLocationDropdown) {
                    e.currentTarget.style.background = '#f8fafc';
                    e.currentTarget.style.borderColor = '#d1d5db';
                }
              }}
              onMouseLeave={(e) => {
                if (!showLocationDropdown) {
                  e.currentTarget.style.background = 'transparent';
                    e.currentTarget.style.borderColor = '#e5e7eb';
                }
              }}
            >
                <span style={{ fontSize: '16px' }}>📍</span>
                <span style={{ fontWeight: '500' }}>
                  {city === 'all' ? t('home.allCities') : userLocation}
                </span>
              <span style={{
                transform: showLocationDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                  transition: 'transform 0.2s ease',
                  fontSize: '12px'
              }}>▼</span>
            </div>
            
            {/* 位置下拉菜单 */}
            {showLocationDropdown && (
              <div 
                className="location-dropdown"
                style={{
                  position: isMobile ? 'fixed' : 'absolute',
                  top: isMobile ? '70px' : '100%',
                  left: isMobile ? '10px' : '0',
                  right: isMobile ? '10px' : '0',
                  background: '#fff',
                  border: '1px solid #e5e7eb',
                  borderRadius: '8px',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                  zIndex: 9999,
                  marginTop: isMobile ? '8px' : '4px',
                  maxHeight: '200px',
                  overflowY: 'auto',
                  minWidth: '150px',
                  maxWidth: isMobile ? 'calc(100vw - 20px)' : 'none'
                }}>
                <div
                  onClick={() => handleLocationChange('all')}
                  style={{
                    padding: '12px 16px',
                    cursor: 'pointer',
                    fontSize: '14px',
                    color: '#374151',
                    borderBottom: '1px solid #f3f4f6',
                    transition: 'background 0.2s ease',
                    fontWeight: '600'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = '#f9fafb';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'transparent';
                  }}
                >
                  {t('home.allCities')}
                </div>
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
          </div>

          {/* 通知按钮和汉堡菜单 */}
          <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
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
          <div className="category-section" style={{
            background: '#fff',
            borderRadius: '12px',
            padding: '16px',
            marginBottom: '16px',
            boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
            position: 'relative'
          }}>
            <div className="category-icons" style={{
              display: 'flex',
              gap: '12px',
              justifyContent: 'space-between',
              paddingBottom: '8px',
              flexWrap: 'wrap',
              overflowX: 'auto',
              scrollbarWidth: 'none',
              msOverflowStyle: 'none'
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

          {/* 排序按钮和搜索框行 */}
          <div style={{
            background: '#fff',
            borderRadius: '12px',
            padding: '16px',
            marginBottom: '16px',
            boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
            display: 'flex',
            alignItems: 'center',
            gap: '20px',
            flexWrap: 'wrap'
          }}>
            {/* 排序控制区域 - 重新设计 */}
            <div className="sort-controls" style={{
              display: 'flex',
              gap: '12px',
              flex: '1',
              minWidth: '0',
              alignItems: 'center',
              flexWrap: 'wrap'
            }}>
              {/* 任务等级下拉菜单 */}
              <div className="level-dropdown-container" style={{ position: 'relative' }}>
                <div
                  onClick={() => setShowLevelDropdown(!showLevelDropdown)}
                  style={{
                    background: taskLevel !== t('tasks.levels.all') 
                      ? taskLevel === t('tasks.levels.vip') 
                        ? 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)'
                        : taskLevel === t('tasks.levels.super')
                        ? 'linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%)'
                        : 'linear-gradient(135deg, #6b7280 0%, #4b5563 100%)'
                      : '#ffffff',
                    color: taskLevel !== t('tasks.levels.all') ? '#ffffff' : '#374151',
                    border: '1px solid #e5e7eb',
                    borderRadius: '16px',
                    padding: '12px 20px',
                    cursor: 'pointer',
                    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    flexShrink: 0,
                    boxShadow: taskLevel !== t('tasks.levels.all') 
                      ? taskLevel === t('tasks.levels.vip')
                        ? '0 8px 25px rgba(245, 158, 11, 0.3)'
                        : taskLevel === t('tasks.levels.super')
                        ? '0 8px 25px rgba(139, 92, 246, 0.3)'
                        : '0 8px 25px rgba(107, 114, 128, 0.3)'
                      : '0 2px 8px rgba(0, 0, 0, 0.08)',
                    transform: taskLevel !== t('tasks.levels.all') ? 'translateY(-2px)' : 'translateY(0)',
                    minWidth: '140px'
                  }}
                  onMouseEnter={(e) => {
                    if (taskLevel === t('tasks.levels.all')) {
                      e.currentTarget.style.transform = 'translateY(-1px)';
                      e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (taskLevel === t('tasks.levels.all')) {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
                    }
                  }}
                >
                  <div style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: '50%',
                    background: taskLevel !== t('tasks.levels.all') 
                      ? 'rgba(255, 255, 255, 0.2)' 
                      : '#f3f4f6',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '16px'
                  }}>
                    {taskLevel === t('tasks.levels.vip') ? '👑' : taskLevel === t('tasks.levels.super') ? '⭐' : '📋'}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '14px', fontWeight: '600' }}>
                      {taskLevel}
                    </div>
                    <div style={{ fontSize: '11px', opacity: 0.8 }}>
                      {taskLevel !== t('tasks.levels.all') ? t('tasks.levels.taskLevel') : t('tasks.levels.selectLevel')}
                    </div>
                  </div>
                  <div style={{
                    color: taskLevel !== t('tasks.levels.all') ? '#ffffff' : '#9ca3af',
                    fontSize: '12px',
                    transition: 'color 0.3s ease',
                    transform: showLevelDropdown ? 'rotate(180deg)' : 'rotate(0deg)'
                  }}>
                    ▼
                  </div>
                </div>
                
                {/* 自定义下拉菜单 */}
                {showLevelDropdown && (
                  <div className="custom-dropdown-content show" style={{
                    position: 'absolute',
                    top: '100%',
                    left: 0,
                    right: 0,
                    background: '#ffffff',
                    border: '1px solid #e5e7eb',
                    borderRadius: '12px',
                    boxShadow: '0 10px 25px rgba(0, 0, 0, 0.15)',
                    zIndex: 1000,
                    marginTop: '4px',
                    overflow: 'hidden',
                    minWidth: '200px'
                  }}>
                    <div 
                      className={`custom-dropdown-item ${taskLevel === t('tasks.levels.all') ? 'selected' : ''}`}
                      onClick={() => handleLevelChange(t('tasks.levels.all'))}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                    fontSize: '14px',
                    fontWeight: '500',
                        color: taskLevel === t('tasks.levels.all') ? '#ffffff' : '#374151',
                        background: taskLevel === t('tasks.levels.all') ? '#3b82f6' : 'transparent',
                        borderBottom: '1px solid #f3f4f6'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        📋
                      </div>
                      <span>{t('tasks.levels.all')}</span>
                    </div>
                    <div 
                      className={`custom-dropdown-item ${taskLevel === t('tasks.levels.normal') ? 'selected' : ''}`}
                      onClick={() => handleLevelChange(t('tasks.levels.normal'))}
                      style={{
                        padding: '12px 16px',
                    cursor: 'pointer',
                    transition: 'all 0.2s ease',
                    display: 'flex',
                    alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: taskLevel === t('tasks.levels.normal') ? '#ffffff' : '#374151',
                        background: taskLevel === t('tasks.levels.normal') ? '#3b82f6' : 'transparent',
                        borderBottom: '1px solid #f3f4f6'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        📋
                      </div>
                      <span>{t('tasks.levels.normal')}</span>
                    </div>
                    <div 
                      className={`custom-dropdown-item ${taskLevel === t('tasks.levels.vip') ? 'selected' : ''}`}
                      onClick={() => handleLevelChange(t('tasks.levels.vip'))}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: taskLevel === t('tasks.levels.vip') ? '#ffffff' : '#374151',
                        background: taskLevel === t('tasks.levels.vip') ? '#3b82f6' : 'transparent',
                        borderBottom: '1px solid #f3f4f6'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        👑
                      </div>
                      <span>{t('tasks.levels.vip')}</span>
                    </div>
                    <div 
                      className={`custom-dropdown-item ${taskLevel === t('tasks.levels.super') ? 'selected' : ''}`}
                      onClick={() => handleLevelChange(t('tasks.levels.super'))}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: taskLevel === t('tasks.levels.super') ? '#ffffff' : '#374151',
                        background: taskLevel === t('tasks.levels.super') ? '#3b82f6' : 'transparent'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        ⭐
                      </div>
                      <span>{t('tasks.levels.super')}</span>
                    </div>
                  </div>
                )}
              </div>

              {/* 排序标签 */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                color: '#6b7280',
                fontSize: '14px',
                fontWeight: '500',
                flexShrink: 0
              }}>
                <span>排序:</span>
              </div>

              {/* 最新发布卡片 */}
              <div
                onClick={() => {
                  setSortBy('latest');
                  setRewardSort('');
                  setDeadlineSort('');
                }}
                  style={{
                  background: sortBy === 'latest' 
                    ? 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)' 
                    : '#ffffff',
                  color: sortBy === 'latest' ? '#ffffff' : '#374151',
                  border: '1px solid #e5e7eb',
                  borderRadius: '16px',
                  padding: '12px 20px',
                    cursor: 'pointer',
                  transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    display: 'flex',
                    alignItems: 'center',
                  gap: '8px',
                  flexShrink: 0,
                  boxShadow: sortBy === 'latest' 
                    ? '0 8px 25px rgba(102, 126, 234, 0.3)' 
                    : '0 2px 8px rgba(0, 0, 0, 0.08)',
                  transform: sortBy === 'latest' ? 'translateY(-2px)' : 'translateY(0)',
                  position: 'relative',
                  overflow: 'hidden'
                }}
                onMouseEnter={(e) => {
                  if (sortBy !== 'latest') {
                    e.currentTarget.style.transform = 'translateY(-1px)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
                  }
                }}
                onMouseLeave={(e) => {
                  if (sortBy !== 'latest') {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
                  }
                }}
              >
                <div style={{
                  width: '32px',
                  height: '32px',
                  borderRadius: '50%',
                  background: sortBy === 'latest' 
                    ? 'rgba(255, 255, 255, 0.2)' 
                    : '#f3f4f6',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '16px'
                }}>
                  🕒
                </div>
                <div>
                  <div style={{ fontSize: '14px', fontWeight: '600' }}>最新发布</div>
                  <div style={{ fontSize: '11px', opacity: 0.8 }}>按时间排序</div>
                </div>
              </div>

              {/* 金额排序卡片 */}
              <div className="reward-dropdown-container" style={{ position: 'relative' }}>
                <div
                  onClick={() => setShowRewardDropdown(!showRewardDropdown)}
                  style={{
                    background: rewardSort 
                      ? 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)' 
                      : '#ffffff',
                    color: rewardSort ? '#ffffff' : '#374151',
                    border: '1px solid #e5e7eb',
                    borderRadius: '16px',
                    padding: '12px 20px',
                    cursor: 'pointer',
                    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    flexShrink: 0,
                    boxShadow: rewardSort 
                      ? '0 8px 25px rgba(240, 147, 251, 0.3)' 
                      : '0 2px 8px rgba(0, 0, 0, 0.08)',
                    transform: rewardSort ? 'translateY(-2px)' : 'translateY(0)',
                    minWidth: '140px'
                  }}
                  onMouseEnter={(e) => {
                    if (!rewardSort) {
                      e.currentTarget.style.transform = 'translateY(-1px)';
                      e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (!rewardSort) {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
                    }
                  }}
                >
                  <div style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: '50%',
                    background: rewardSort 
                      ? 'rgba(255, 255, 255, 0.2)' 
                      : '#fef3c7',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '16px'
                  }}>
                    💰
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '14px', fontWeight: '600' }}>
                      {rewardSort === 'desc' ? '金额降序' : 
                       rewardSort === 'asc' ? '金额升序' : '金额排序'}
                    </div>
                    <div style={{ fontSize: '11px', opacity: 0.8 }}>
                      {rewardSort ? '按金额排序' : '选择排序方式'}
                    </div>
                  </div>
                  <div style={{
                    color: rewardSort ? '#ffffff' : '#9ca3af',
                    fontSize: '12px',
                    transition: 'color 0.3s ease',
                    transform: showRewardDropdown ? 'rotate(180deg)' : 'rotate(0deg)'
                  }}>
                    ▼
                  </div>
                </div>
                
                {/* 自定义下拉菜单 */}
                {showRewardDropdown && (
                  <div className="custom-dropdown-content show" style={{
                    position: 'absolute',
                    top: '100%',
                    left: 0,
                    right: 0,
                    background: '#ffffff',
                    border: '1px solid #e5e7eb',
                    borderRadius: '12px',
                    boxShadow: '0 10px 25px rgba(0, 0, 0, 0.15)',
                    zIndex: 1000,
                    marginTop: '4px',
                    overflow: 'hidden',
                    minWidth: '200px'
                  }}>
                    <div 
                      className={`custom-dropdown-item ${rewardSort === '' ? 'selected' : ''}`}
                      onClick={() => {
                        handleRewardSortChange('');
                        setShowRewardDropdown(false);
                      }}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                    fontSize: '14px',
                    fontWeight: '500',
                        color: rewardSort === '' ? '#ffffff' : '#374151',
                        background: rewardSort === '' ? '#3b82f6' : 'transparent',
                        borderBottom: '1px solid #f3f4f6'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        💰
                      </div>
                      <span>金额排序</span>
                    </div>
                    <div 
                      className={`custom-dropdown-item ${rewardSort === 'desc' ? 'selected' : ''}`}
                      onClick={() => {
                        handleRewardSortChange('desc');
                        setShowRewardDropdown(false);
                      }}
                      style={{
                        padding: '12px 16px',
                    cursor: 'pointer',
                    transition: 'all 0.2s ease',
                    display: 'flex',
                    alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: rewardSort === 'desc' ? '#ffffff' : '#374151',
                        background: rewardSort === 'desc' ? '#3b82f6' : 'transparent',
                        borderBottom: '1px solid #f3f4f6'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        💰
                      </div>
                      <span>金额降序</span>
                    </div>
                    <div 
                      className={`custom-dropdown-item ${rewardSort === 'asc' ? 'selected' : ''}`}
                      onClick={() => {
                        handleRewardSortChange('asc');
                        setShowRewardDropdown(false);
                      }}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: rewardSort === 'asc' ? '#ffffff' : '#374151',
                        background: rewardSort === 'asc' ? '#3b82f6' : 'transparent'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        💰
                      </div>
                      <span>金额升序</span>
                    </div>
                  </div>
                )}
              </div>

              {/* 截止日期排序卡片 */}
              <div className="deadline-dropdown-container" style={{ position: 'relative' }}>
                <div
                  onClick={() => setShowDeadlineDropdown(!showDeadlineDropdown)}
                  style={{
                    background: deadlineSort 
                      ? 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)' 
                      : '#ffffff',
                    color: deadlineSort ? '#ffffff' : '#374151',
                    border: '1px solid #e5e7eb',
                    borderRadius: '16px',
                    padding: '12px 20px',
                    cursor: 'pointer',
                    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    flexShrink: 0,
                    boxShadow: deadlineSort 
                      ? '0 8px 25px rgba(79, 172, 254, 0.3)' 
                      : '0 2px 8px rgba(0, 0, 0, 0.08)',
                    transform: deadlineSort ? 'translateY(-2px)' : 'translateY(0)',
                    minWidth: '160px'
                  }}
                  onMouseEnter={(e) => {
                    if (!deadlineSort) {
                      e.currentTarget.style.transform = 'translateY(-1px)';
                      e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (!deadlineSort) {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
                    }
                  }}
                >
                  <div style={{
                    width: '32px',
                    height: '32px',
                    borderRadius: '50%',
                    background: deadlineSort 
                      ? 'rgba(255, 255, 255, 0.2)' 
                      : '#fef3c7',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '16px'
                  }}>
                    ⏰
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '14px', fontWeight: '600' }}>
                      {deadlineSort === 'asc' ? '截止升序' : 
                       deadlineSort === 'desc' ? '截止降序' : '截止时间排序'}
                    </div>
                    <div style={{ fontSize: '11px', opacity: 0.8 }}>
                      {deadlineSort ? '按截止时间排序' : '选择排序方式'}
                    </div>
                  </div>
                  <div style={{
                    color: deadlineSort ? '#ffffff' : '#9ca3af',
                    fontSize: '12px',
                    transition: 'color 0.3s ease',
                    transform: showDeadlineDropdown ? 'rotate(180deg)' : 'rotate(0deg)'
                  }}>
                    ▼
                  </div>
                </div>
                
                {/* 自定义下拉菜单 */}
                {showDeadlineDropdown && (
                  <div className="custom-dropdown-content show" style={{
                    position: 'absolute',
                    top: '100%',
                    left: 0,
                    right: 0,
                    background: '#ffffff',
                    border: '1px solid #e5e7eb',
                    borderRadius: '12px',
                    boxShadow: '0 10px 25px rgba(0, 0, 0, 0.15)',
                    zIndex: 1000,
                    marginTop: '4px',
                    overflow: 'hidden',
                    minWidth: '200px'
                  }}>
                    <div 
                      className={`custom-dropdown-item ${deadlineSort === '' ? 'selected' : ''}`}
                      onClick={() => {
                        handleDeadlineSortChange('');
                        setShowDeadlineDropdown(false);
                      }}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: deadlineSort === '' ? '#ffffff' : '#374151',
                        background: deadlineSort === '' ? '#3b82f6' : 'transparent',
                        borderBottom: '1px solid #f3f4f6'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        ⏰
                      </div>
                      <span>截止时间排序</span>
                    </div>
                    <div 
                      className={`custom-dropdown-item ${deadlineSort === 'asc' ? 'selected' : ''}`}
                      onClick={() => {
                        handleDeadlineSortChange('asc');
                        setShowDeadlineDropdown(false);
                      }}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: deadlineSort === 'asc' ? '#ffffff' : '#374151',
                        background: deadlineSort === 'asc' ? '#3b82f6' : 'transparent',
                        borderBottom: '1px solid #f3f4f6'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        ⏰
                      </div>
                      <span>截止时间升序</span>
                    </div>
                    <div 
                      className={`custom-dropdown-item ${deadlineSort === 'desc' ? 'selected' : ''}`}
                      onClick={() => {
                        handleDeadlineSortChange('desc');
                        setShowDeadlineDropdown(false);
                      }}
                      style={{
                        padding: '12px 16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        fontSize: '14px',
                        fontWeight: '500',
                        color: deadlineSort === 'desc' ? '#ffffff' : '#374151',
                        background: deadlineSort === 'desc' ? '#3b82f6' : 'transparent'
                      }}
                    >
                      <div className="icon" style={{
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px'
                      }}>
                        ⏰
                      </div>
                      <span>截止时间降序</span>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* 搜索框区域 */}
            <div className="search-section" style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              flexShrink: 0,
              minWidth: '300px'
            }}>
              <div className="search-input-container" style={{
                position: 'relative',
                minWidth: '250px',
                maxWidth: '400px'
              }}>
                <input
                  type="text"
                  placeholder="搜索任务..."
                  value={keyword}
                  onChange={(e) => setKeyword(e.target.value)}
                  style={{ 
                    width: '100%',
                    padding: '8px 12px 8px 35px',
                    border: '2px solid #e5e7eb',
                    borderRadius: '20px',
                    fontSize: '14px',
                    background: '#f9fafb',
                    outline: 'none',
                    transition: 'all 0.3s ease',
                    boxSizing: 'border-box'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                    e.target.style.background = '#fff';
                    e.target.style.boxShadow = '0 0 0 3px rgba(59, 130, 246, 0.1)';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#e5e7eb';
                    e.target.style.background = '#f9fafb';
                    e.target.style.boxShadow = 'none';
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
              
              {/* 搜索统计信息 */}
              <div style={{
                color: '#6b7280',
                fontSize: '12px',
                whiteSpace: 'nowrap',
                minWidth: '80px'
              }}>
                {keyword ? `${tasks.length}个结果` : `${tasks.length}个任务`}
              </div>
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

          {/* 任务统计信息 */}
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginTop: '20px',
            marginBottom: '12px',
            padding: '0 4px'
          }}>
            <div style={{
              fontSize: '14px',
              color: '#6b7280',
              fontWeight: '500'
            }}>
              找到 <span style={{ color: '#3b82f6', fontWeight: '600' }}>{filteredTasks.length}</span> 个任务
              {tasks.length !== filteredTasks.length && (
                <span style={{ color: '#9ca3af', marginLeft: '8px' }}>
                  (共 {tasks.length} 个)
                </span>
              )}
            </div>
            {taskLevel !== '全部等级' && (
              <div style={{
                fontSize: '12px',
                color: '#6b7280',
                background: '#f3f4f6',
                padding: '4px 8px',
                borderRadius: '6px',
                display: 'flex',
                alignItems: 'center',
                gap: '4px'
              }}>
                <span>筛选:</span>
                <span style={{ fontWeight: '500' }}>{taskLevel}</span>
                <button
                  onClick={() => setTaskLevel('全部等级')}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#9ca3af',
                    cursor: 'pointer',
                    fontSize: '12px',
                    padding: '2px',
                    borderRadius: '2px',
                    transition: 'color 0.2s ease'
                  }}
                  onMouseEnter={(e) => e.currentTarget.style.color = '#6b7280'}
                  onMouseLeave={(e) => e.currentTarget.style.color = '#9ca3af'}
                >
                  ✕
                </button>
              </div>
            )}
          </div>

          {/* 任务列表 */}
          <div className="tasks-grid" style={{
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
            ) : filteredTasks.length === 0 ? (
              <div style={{ 
                gridColumn: '1 / -1',
                textAlign: 'center', 
                padding: '80px 20px',
                color: '#6b7280'
              }}>
                <div style={{ fontSize: 48, marginBottom: 16 }}>📝</div>
                <div>
                  {tasks.length === 0 ? '暂无任务' : '没有找到符合条件的任务'}
                </div>
                {tasks.length > 0 && (
                  <div style={{ fontSize: '14px', color: '#999', marginTop: '8px' }}>
                    尝试调整筛选条件
                  </div>
                )}
              </div>
            ) : (
              filteredTasks.map(task => (
                <div
                  key={task.id}
                  className="task-card"
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
                    
                    <div className="task-info" style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      marginBottom: '8px',
                      fontSize: '12px',
                      color: '#6b7280'
                    }}>
                      <span>
                        {task.location === 'Online' ? '🌐' : '📍'} {task.location}
                      </span>
                      <span>•</span>
                      <span>🏷️ {task.task_type}</span>
                    </div>
                    
                    <div className="task-description" style={{
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
                      <div className="task-reward" style={{
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
                        {isExpired(task.deadline) ? t('home.taskExpired') : 
                         isExpiringSoon(task.deadline) ? t('home.taskExpiringSoon') : getRemainTime(task.deadline, t)}
                      </div>
                    </div>
                    
                    {/* 操作按钮 */}
                    <div className="task-actions" style={{ display: 'flex', gap: '8px' }}>
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
                      
                      {(task.status === 'open' || task.status === 'taken') && user && user.id !== task.poster_id && canViewTask(user, task) && !appliedTasks.has(task.id) && (
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
                          申请任务
                        </button>
                      )}
                      
                      {/* 等级不足提示 */}
                      {(task.status === 'open' || task.status === 'taken') && user && user.id !== task.poster_id && !canViewTask(user, task) && (
                        <div style={{
                          flex: 1,
                          padding: '8px 12px',
                          borderRadius: '6px',
                          background: '#f3f4f6',
                          color: '#6b7280',
                          fontSize: '14px',
                          fontWeight: '500',
                          textAlign: 'center',
                          border: '1px solid #d1d5db'
                        }}>
                          🔒 需要{task.task_level === 'vip' ? 'VIP' : '超级VIP'}用户
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* 分页 */}
          {total > pageSize && (
            <div className="pagination" style={{
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
              
              <div className="page-numbers" style={{
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
      
      {/* 通知弹窗 */}
      <NotificationPanel
        isOpen={showNotifications}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />
      
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

      {/* 移动端响应式样式 */}
      <style>
        {`
          /* 移动端适配 */
          @media (max-width: 768px) {
            /* 顶部导航栏移动端优化 */
            .header-container {
              flex-wrap: nowrap !important;
              overflow: hidden !important;
            }
            
            .header-logo {
              font-size: 20px !important;
              flex-shrink: 0 !important;
            }
            
            /* 排序和搜索区域移动端优化 */
            .sort-controls {
              flex-direction: column !important;
              gap: 16px !important;
              width: 100% !important;
            }
            
            .sort-controls > div {
              width: 100% !important;
              min-width: 100% !important;
            }
            
            .search-section {
              flex-direction: column !important;
              gap: 8px !important;
              min-width: 100% !important;
              margin-top: 12px !important;
            }
            
            .search-input-container {
              min-width: 100% !important;
              max-width: 100% !important;
            }
            
            .search-input-container input {
              font-size: 14px !important;
              padding: 10px 14px 10px 40px !important;
            }
            
            .location-container {
              margin-right: 4px !important;
              flex-shrink: 0 !important;
            }
            
            .location-container > div {
              font-size: 12px !important;
              padding: 6px 8px !important;
            }
            
            /* 手机端下拉菜单优化 */
            .location-container [data-location-dropdown] {
              position: relative !important;
            }
            
            .location-dropdown {
              position: fixed !important;
              top: 70px !important;
              left: 10px !important;
              right: 10px !important;
              width: auto !important;
              max-width: calc(100vw - 20px) !important;
              z-index: 99999 !important;
              margin-top: 8px !important;
              box-shadow: 0 8px 25px rgba(0,0,0,0.15) !important;
              border-radius: 12px !important;
              max-height: 60vh !important;
              overflow-y: auto !important;
            }
            
            /* 任务网格移动端优化 */
            .tasks-grid {
              grid-template-columns: 1fr !important;
              gap: 12px !important;
            }
            
            /* 分类图标行移动端优化 */
            .category-icons {
              gap: 8px !important;
              padding: 12px !important;
              flex-wrap: nowrap !important;
              justify-content: flex-start !important;
              overflow-x: auto !important;
              scrollbar-width: none !important;
              -ms-overflow-style: none !important;
            }
            
            .category-icons::-webkit-scrollbar {
              display: none !important;
            }
            
            /* 分类区域滚动提示 */
            .category-section::after {
              content: '← 滑动查看更多 →' !important;
              position: absolute !important;
              bottom: 4px !important;
              left: 50% !important;
              transform: translateX(-50%) !important;
              font-size: 10px !important;
              color: #999 !important;
              background: rgba(255, 255, 255, 0.9) !important;
              padding: 2px 8px !important;
              border-radius: 10px !important;
              pointer-events: none !important;
              animation: fadeInOut 3s infinite !important;
            }
            
            @keyframes fadeInOut {
              0%, 100% { opacity: 0.3; }
              50% { opacity: 1; }
            }
            
            .category-icons > div {
              min-width: 60px !important;
              max-width: 80px !important;
              flex-shrink: 0 !important;
            }
            
            .category-icons > div > div {
              width: 36px !important;
              height: 36px !important;
              font-size: 16px !important;
            }
            
            .category-icons span {
              font-size: 10px !important;
            }
            
            /* 排序按钮移动端优化 */
            .sort-buttons {
              gap: 8px !important;
              padding: 12px !important;
              overflow-x: auto !important;
            }
            
            .sort-buttons button {
              padding: 6px 12px !important;
              font-size: 12px !important;
              white-space: nowrap !important;
            }
            
            /* 任务卡片移动端优化 */
            .task-card {
              margin: 0 !important;
            }
            
            .task-card h3 {
              font-size: 14px !important;
            }
            
            .task-card .task-info {
              font-size: 11px !important;
            }
            
            .task-card .task-description {
              font-size: 12px !important;
            }
            
            .task-card .task-reward {
              font-size: 16px !important;
            }
            
            .task-card .task-actions {
              flex-direction: column !important;
              gap: 8px !important;
            }
            
            .task-card .task-actions button {
              width: 100% !important;
              padding: 10px !important;
              font-size: 13px !important;
            }
            
            /* 分页移动端优化 */
            .pagination {
              flex-direction: column !important;
              gap: 8px !important;
              padding: 12px !important;
            }
            
            .pagination button {
              padding: 8px 16px !important;
              font-size: 12px !important;
            }
            
            .pagination .page-numbers {
              flex-wrap: wrap !important;
              justify-content: center !important;
            }
            
            .pagination .page-numbers button {
              width: 28px !important;
              height: 28px !important;
              font-size: 12px !important;
            }
            
            /* 通知弹窗移动端优化 */
            .notification-container {
              right: 10px !important;
              left: 10px !important;
              top: 70px !important;
              min-width: auto !important;
              max-width: none !important;
            }
          }
          
          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            .header-container {
              gap: 4px !important;
            }
            
            .header-logo {
              font-size: 18px !important;
            }
            
            .search-section {
              margin-top: 8px !important;
            }
            
            .search-input-container input {
              font-size: 13px !important;
              padding: 8px 12px 8px 35px !important;
            }
            
            .location-container > div {
              font-size: 11px !important;
              padding: 4px 6px !important;
            }
            
            .category-icons {
              gap: 6px !important;
              padding: 8px !important;
            }
            
            .category-icons > div {
              min-width: 50px !important;
              max-width: 70px !important;
            }
            
            .category-icons > div > div {
              width: 32px !important;
              height: 32px !important;
              font-size: 14px !important;
            }
            
            .category-icons span {
              font-size: 9px !important;
            }
          }
          
          /* 极小屏幕优化 */
          @media (max-width: 360px) {
            .header-container {
              padding: 8px 12px !important;
            }
            
            .search-section {
              margin-top: 6px !important;
            }
            
            .search-input-container input {
              font-size: 12px !important;
              padding: 6px 10px 6px 30px !important;
            }
            
            .location-container > div {
              font-size: 10px !important;
              padding: 3px 4px !important;
            }
            
            .category-icons {
              gap: 4px !important;
              padding: 6px !important;
            }
            
            .category-icons > div {
              min-width: 45px !important;
              max-width: 60px !important;
            }
            
            .category-icons > div > div {
              width: 28px !important;
              height: 28px !important;
              font-size: 12px !important;
            }
            
            .category-icons span {
              font-size: 8px !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default Tasks;
