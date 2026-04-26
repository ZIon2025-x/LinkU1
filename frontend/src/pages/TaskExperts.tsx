import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import api, { fetchCurrentUser, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout, getPublicTaskExperts, fetchMyExpertTeams, applyToActivity } from '../api';
import { API_BASE_URL } from '../config';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import SEOHead from '../components/SEOHead';
import ServiceDetailModal from '../components/ServiceDetailModal';
import ServiceListModal from '../components/ServiceListModal';
import ExpertDetailModal from '../components/ExpertDetailModal';
import LazyImage from '../components/LazyImage';
import MemberBadge from '../components/MemberBadge';
import styles from './TaskExperts.module.css';

interface TaskExpert {
  id: string;
  name: string;
  avatar: string;
  user_level: string;
  avg_rating: number;
  completed_tasks: number;
  total_tasks: number;
  completion_rate: number;
  expertise_areas: string[];
  is_verified: boolean;
  bio: string;
  join_date: string;
  last_active: string;
  featured_skills: string[];
  achievements: string[];
  response_time: string;
  success_rate: number;
  location?: string; // 添加城市字段
  category?: string; // 添加类别字段
}

// 城市列表 - 与其他页面保持一致
const CITIES = [
  "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

interface Notification {
  id: number;
  type: string;
  title: string;
  content: string;
  is_read: number;
  created_at: string;
}

const TaskExperts: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  const location = useLocation();
  const [experts, setExperts] = useState<TaskExpert[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedCity, setSelectedCity] = useState('all');
  const [sortBy, setSortBy] = useState('rating');
  const [, setIsMobile] = useState(false); void setIsMobile;

  // 处理活动图片URL（确保相对路径能正确显示）
  const getActivityImageUrl = useCallback((imageValue: string | null | undefined): string => {
    if (!imageValue) {
      return 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=400&h=300&fit=crop';
    }
    
    const imageStr = String(imageValue);
    
    // 如果已经是完整的URL（包含 http:// 或 https://），直接返回
    if (imageStr.startsWith('http://') || imageStr.startsWith('https://')) {
      return imageStr;
    }
    
    // 如果是相对路径（以 / 开头），添加API base URL
    if (imageStr.startsWith('/')) {
      return `${API_BASE_URL}${imageStr}`;
    }
    
    // 其他情况直接返回
    return imageStr;
  }, []);

  // 生成canonical URL
  const canonicalUrl = location.pathname.startsWith('/en') || location.pathname.startsWith('/zh')
    ? `https://www.link2ur.com${location.pathname}`
    : 'https://www.link2ur.com/en/task-experts';
  
  // 用户和通知相关状态
  const [user, setUser] = useState<any>(null);
  const [isTaskExpert, setIsTaskExpert] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 登录弹窗状态
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
  // 服务列表弹窗状态
  const [showServiceListModal, setShowServiceListModal] = useState(false);
  const [selectedExpertId, setSelectedExpertId] = useState<string | null>(null);
  const [selectedExpertName, setSelectedExpertName] = useState<string | null>(null);
  
  // 服务详情弹窗状态
  const [showServiceDetailModal, setShowServiceDetailModal] = useState(false);
  const [selectedServiceId, setSelectedServiceId] = useState<number | null>(null);
  
  // 专家详情弹窗状态
  const [showExpertDetailModal, setShowExpertDetailModal] = useState(false);
  const [selectedExpertDetailId, setSelectedExpertDetailId] = useState<string | null>(null);
  
  // 达人活动相关状态
  const [expertActivities, setExpertActivities] = useState<{[key: string]: any[]}>({});
  const [, setLoadingActivities] = useState<{[key: string]: boolean}>({});
  const [showActivityDetailModal, setShowActivityDetailModal] = useState(false);
  const [selectedActivity, setSelectedActivity] = useState<any>(null);
  // 活动时间段列表（用于时间段服务）
  const [activityTimeSlots, setActivityTimeSlots] = useState<any[]>([]);
  const [loadingActivityTimeSlots, setLoadingActivityTimeSlots] = useState(false);
  // 选中的时间段ID（用于多时间段活动）
  const [selectedTimeSlotId, setSelectedTimeSlotId] = useState<number | null>(null);

  const categories = [
    { value: 'all', label: t('taskExperts.allCategories') },
    { value: 'programming', label: t('taskExperts.programming') },
    { value: 'translation', label: t('taskExperts.translation') },
    { value: 'tutoring', label: t('taskExperts.tutoring') },
    { value: 'food', label: t('taskExperts.food') },
    { value: 'beverage', label: t('taskExperts.beverage') },
    { value: 'cake', label: t('taskExperts.cake') },
    { value: 'errand_transport', label: t('taskExperts.errandTransport') },
    { value: 'social_entertainment', label: t('taskExperts.socialEntertainment') },
    { value: 'beauty_skincare', label: t('taskExperts.beautySkincare') },
    { value: 'handicraft', label: t('taskExperts.handicraft') }
  ];

  const sortOptions = [
    { value: 'rating', label: t('taskExperts.sortByRating') },
    { value: 'tasks', label: t('taskExperts.sortByTasks') },
    { value: 'recent', label: t('taskExperts.sortByRecent') }
  ];

  // 立即更新meta标签以确保微信分享能识别logo（必须在组件加载时立即执行）
  useEffect(() => {
    // 检查是否是任务详情页，如果是则不设置meta标签（让任务详情页自己管理）
    const isTaskDetailPage = /\/tasks\/\d+/.test(location.pathname);
    if (isTaskDetailPage) {
      return; // 不设置meta标签，让任务详情页自己管理
    }
    
    const updateMetaTag = (name: string, content: string, property?: boolean) => {
      const selector = property ? `meta[property="${name}"]` : `meta[name="${name}"]`;
      let metaTag = document.querySelector(selector) as HTMLMetaElement;
      
      if (!metaTag) {
        metaTag = document.createElement('meta');
        if (property) {
          metaTag.setAttribute('property', name);
        } else {
          metaTag.setAttribute('name', name);
        }
        document.head.appendChild(metaTag);
      }
      
      metaTag.content = content;
    };

    // 强制移除旧的og:image标签（包括index.html中的默认标签）
    const existingOgImage = document.querySelector('meta[property="og:image"]');
    if (existingOgImage) {
      existingOgImage.remove();
    }

    // 设置favicon图片（完整URL，添加版本号避免缓存）
    const shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    
    // 创建新的og:image标签
    updateMetaTag('og:image', shareImageUrl, true);
    updateMetaTag('og:image:width', '1200', true);
    updateMetaTag('og:image:height', '630', true);
    updateMetaTag('og:image:type', 'image/png', true);
    
    // 设置微信分享标签
    const existingWeixinImage = document.querySelector('meta[name="weixin:image"]');
    if (existingWeixinImage) {
      existingWeixinImage.remove();
    }
    updateMetaTag('weixin:image', shareImageUrl);
    
    // 设置微信分享标题和描述
    const ogTitle = t('taskExperts.title');
    const ogDescription = t('taskExperts.subtitle');
    
    if (ogTitle) {
      updateMetaTag('weixin:title', ogTitle);
      updateMetaTag('og:title', ogTitle, true);
    }
    if (ogDescription) {
      updateMetaTag('weixin:description', ogDescription);
      updateMetaTag('og:description', ogDescription, true);
    }
    
    // 将关键标签移到head前面（确保微信爬虫能读取到）
    const moveToTop = (selector: string) => {
      const element = document.querySelector(selector);
      if (element && element.parentNode) {
        const head = document.head;
        const firstChild = head.firstChild;
        if (firstChild && element !== firstChild) {
          head.insertBefore(element, firstChild);
        }
      }
    };
    
    // 延迟执行确保DOM已更新
    setTimeout(() => {
      moveToTop('meta[property="og:image"]');
      moveToTop('meta[name="weixin:image"]');
      moveToTop('meta[property="og:title"]');
      moveToTop('meta[name="weixin:title"]');
      moveToTop('meta[property="og:description"]');
      moveToTop('meta[name="weixin:description"]');
    }, 0);
  }, [location.pathname, t]); // 依赖路径和翻译函数，当路径或语言变化时重新设置

  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // 加载用户数据
  useEffect(() => {
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
        
        // 如果用户有常住城市，设置为默认地点
        if (userData && userData.residence_city && CITIES.includes(userData.residence_city)) {
          setSelectedCity(userData.residence_city);
        }
        
        // 检查用户是否是任务达人 (Phase B1 收口: 改用 fetchMyExpertTeams,
        // 新模型下"是达人"= 拥有至少一个团队或作为 active 成员)
        if (userData && userData.id) {
          try {
            const teams = await fetchMyExpertTeams();
            setIsTaskExpert(Array.isArray(teams) && teams.length > 0);
          } catch (_error: any) {
            setIsTaskExpert(false);
          }
        } else {
          setIsTaskExpert(false);
        }
      } catch (error: any) {
        setUser(null);
        setIsTaskExpert(false);
      }
    };
    
    const timer = setTimeout(loadUserData, 100);
    
    // Load system settings
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
    
    return () => clearTimeout(timer);
  }, []);

  // 获取通知数据
  useEffect(() => {
    if (user) {
      getNotificationsWithRecentRead(10).then(notifications => {
        setNotifications(notifications);
      }).catch(() => {
              });
      
      getUnreadNotificationCount().then(count => {
        setUnreadCount(count);
      }).catch(() => {
              });
    }
  }, [user]);

  // 定期更新未读通知数量
  useEffect(() => {
    if (user) {
      const interval = setInterval(() => {
        if (!document.hidden) {
          getUnreadNotificationCount().then(count => {
            setUnreadCount(count);
          }).catch(() => {
                      });
        }
      }, 30000); // 每30秒更新一次
      return () => clearInterval(interval);
    }
    return undefined;
  }, [user]);

  // 使用useCallback优化loadExperts函数，避免不必要的重新创建
  const loadExperts = useCallback(async () => {
    setLoading(true);
    try {
      // 从API获取任务达人列表，传递城市筛选参数
      const expertsData = await getPublicTaskExperts(
        selectedCategory !== 'all' ? selectedCategory : undefined,
        selectedCity !== 'all' ? selectedCity : undefined
      );
      
      // Phase B1 收口: getPublicTaskExperts 现在总是返回数组 (ExpertOut[]),
      // 不再需要 legacy { task_experts: [...] } / { items: [...] } object-shape fallback
      let expertsList: any[] = Array.isArray(expertsData) ? expertsData : [];
      
      // 确保所有必需字段都有默认值
      expertsList = expertsList.map((expert: any) => ({
        ...expert,
        expertise_areas: expert.expertise_areas || [],
        featured_skills: expert.featured_skills || [],
        achievements: expert.achievements || [],
        bio: expert.bio || '',
        join_date: expert.join_date || expert.created_at || new Date().toISOString(),
        last_active: expert.last_active || expert.updated_at || new Date().toISOString(),
        avg_rating: expert.avg_rating || 0,
        completed_tasks: expert.completed_tasks || 0,
        total_tasks: expert.total_tasks || 0,
        completion_rate: expert.completion_rate || 0,
        response_time: expert.response_time || '',
        success_rate: expert.success_rate || 0,
        is_verified: expert.is_verified || false,
        location: expert.location || 'Online',
        category: expert.category || null,  // 添加类别字段
      }));
      
      // 注意：城市筛选和排序在 filteredExperts 和 sortedExperts 中统一处理
      
            setExperts(expertsList);
      
      // 并行加载每个达人的活动
      const activitiesMap: {[key: string]: any[]} = {};
      const loadingMap: {[key: string]: boolean} = {};
      
      await Promise.all(
        expertsList.map(async (expert: any) => {
          loadingMap[expert.id] = true;
          try {
            const response = await api.get('/api/activities', {
              params: {
                expert_id: expert.id,
                status: 'open',
                limit: 5
              }
            });
            const activities = response.data || [];
            activitiesMap[expert.id] = activities.slice(0, 3); // 只显示最近3个
          } catch (err) {
                        activitiesMap[expert.id] = [];
          } finally {
            loadingMap[expert.id] = false;
          }
        })
      );
      
      setExpertActivities(activitiesMap);
      setLoadingActivities(loadingMap);
    } catch (err: any) {
                  message.error('加载任务达人列表失败');
      // 失败时使用空数组
      setExperts([]);
    } finally {
      setLoading(false);
    }
  }, [selectedCategory, selectedCity, t]);

  // 当筛选条件改变时，只重新加载数据，不刷新整个页面
  // sortBy变化时不需要重新加载数据，只需要重新排序（由useMemo处理）
  useEffect(() => {
    loadExperts();
  }, [loadExperts]);

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
            message.error('标记所有通知为已读失败，请重试');
    }
  };

  // 使用useMemo优化排序计算，只在experts或sortBy变化时重新计算
  const sortedExperts = useMemo(() => {
    return [...experts].sort((a, b) => {
      switch (sortBy) {
        case 'rating':
          return b.avg_rating - a.avg_rating;
        case 'tasks':
          return b.completed_tasks - a.completed_tasks;
        case 'recent':
          return new Date(b.last_active).getTime() - new Date(a.last_active).getTime();
        default:
          return 0;
      }
    });
  }, [experts, sortBy]);

  // 使用useCallback优化事件处理函数
  const handleExpertClick = useCallback((expertId: string) => {
    setSelectedExpertDetailId(expertId);
    setShowExpertDetailModal(true);
  }, []);

  const handleRequestService = useCallback(async (expertId: string, expertName: string, e: React.MouseEvent) => {
    e.stopPropagation(); // 阻止事件冒泡，避免触发卡片的点击事件
    
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    // 打开服务列表弹窗
    setSelectedExpertId(expertId);
    setSelectedExpertName(expertName);
    setShowServiceListModal(true);
  }, [user]);

  // 处理活动详情查看（达人发布的多人活动）
  const handleViewActivity = async (activity: any) => {
    setSelectedActivity(activity);
    setShowActivityDetailModal(true);
    setSelectedTimeSlotId(null); // 重置选中的时间段
    
    // 如果是时间段服务，加载时间段列表
    if (activity.has_time_slots && activity.expert_service_id) {
      setLoadingActivityTimeSlots(true);
      try {
        const { getServiceTimeSlotsPublic } = await import('../api');
        const today = new Date();
        const futureDate = new Date(today);
        futureDate.setDate(today.getDate() + 60); // 加载未来60天的时间段
        const slots = await getServiceTimeSlotsPublic(activity.expert_service_id, {
          start_date: today.toISOString().split('T')[0],
          end_date: futureDate.toISOString().split('T')[0],
        });
        // 只显示与该活动关联的时间段（通过activity_id匹配）
        const activitySlots = Array.isArray(slots) 
          ? slots.filter((slot: any) => slot.has_activity && slot.activity_id === activity.id)
          : [];
        setActivityTimeSlots(activitySlots);
      } catch (err: any) {
                setActivityTimeSlots([]);
      } finally {
        setLoadingActivityTimeSlots(false);
      }
    } else {
      setActivityTimeSlots([]);
    }
  };


  const _getLevelColor = (level: string) => {
    switch (level) {
      case 'super': return '#8b5cf6';
      case 'vip': return '#f59e0b';
      default: return '#6b7280';
    }
  }; void _getLevelColor;

  if (loading) {
    return (
      <div style={{ 
        minHeight: '100vh', 
        background: '#fff'
      }}>
        <SEOHead 
          title={t('taskExperts.title')}
          description={t('taskExperts.subtitle')}
          canonicalUrl={canonicalUrl}
          ogTitle={t('taskExperts.title')}
          ogDescription={t('taskExperts.subtitle')}
          ogImage="/static/favicon.png"
          ogUrl={canonicalUrl}
        />
        {/* 顶部导航栏 - 与首页一致 */}
        <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
          <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
            {/* Logo - 可点击跳转到首页 */}
            <div 
              onClick={() => navigate('/')}
              style={{
                fontWeight: 'bold', 
                fontSize: 24, 
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
                WebkitBackgroundClip: 'text', 
                WebkitTextFillColor: 'transparent',
                cursor: 'pointer'
              }}
            >
              Link²Ur
            </div>
            
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
        <div style={{height: 60}} />
        
        {/* 加载内容 */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: 'calc(100vh - 60px)'
        }}>
          <div style={{ 
            background: '#fff', 
            padding: '40px', 
            borderRadius: '20px',
            textAlign: 'center',
            boxShadow: '0 20px 40px rgba(0,0,0,0.1)'
          }}>
            <div style={{ fontSize: '48px', marginBottom: '20px' }}>⏳</div>
            <div style={{ fontSize: '18px', color: '#64748b' }}>{t('taskExperts.loading')}</div>
          </div>
        </div>
        
        {/* 通知弹窗 */}
        <NotificationPanel
          isOpen={showNotifications && !!user}
          onClose={() => setShowNotifications(false)}
          notifications={notifications}
          unreadCount={unreadCount}
          onMarkAsRead={handleMarkAsRead}
          onMarkAllRead={handleMarkAllRead}
        />
        
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
  }

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#fff'
    }}>
      <SEOHead 
        title={t('taskExperts.title')}
        description={t('taskExperts.subtitle')}
        canonicalUrl={canonicalUrl}
        ogTitle={t('taskExperts.title')}
        ogDescription={t('taskExperts.subtitle')}
        ogImage="/static/favicon.png"
        ogUrl={canonicalUrl}
      />
      {/* 顶部导航栏 - 与首页一致 */}
      <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          {/* Logo - 可点击跳转到首页 */}
          <div 
            onClick={() => navigate('/')}
            style={{
              fontWeight: 'bold', 
              fontSize: 24, 
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
              WebkitBackgroundClip: 'text', 
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer'
            }}
          >
            Link²Ur
          </div>
          
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
      
      {/* 通知弹窗 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />
      
      <div className={styles.container}>
        <div className={styles.content}>
          {/* 页面头部 */}
          <div className={styles.header}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>👑</div>
            <h1 style={{
              position: 'absolute',
              top: '-100px',
              left: '-100px',
              width: '1px',
              height: '1px',
              padding: '0',
              margin: '0',
              overflow: 'hidden',
              clip: 'rect(0, 0, 0, 0)',
              whiteSpace: 'nowrap',
              border: '0',
              fontSize: '1px',
              color: 'transparent',
              background: 'transparent'
            }}>
              {t('taskExperts.title')}
            </h1>
            <h2 className={styles.title}>{t('taskExperts.title')}</h2>
            <p className={styles.subtitle}>
              {t('taskExperts.subtitle')}
            </p>
          
          {/* 想成为任务达人按钮 */}
          {!isTaskExpert && (
            <div style={{ marginTop: '24px' }}>
              <button
                onClick={() => navigate('/task-experts/intro')}
                style={{
                  background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '50px',
                  padding: '12px 32px',
                  fontSize: '16px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  boxShadow: '0 4px 20px rgba(59, 130, 246, 0.4)',
                  transition: 'all 0.3s ease',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '8px'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 6px 25px rgba(59, 130, 246, 0.5)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 4px 20px rgba(59, 130, 246, 0.4)';
                }}
              >
                <span style={{ fontSize: '18px' }}>✨</span>
                想成为任务达人？
              </button>
            </div>
          )}
          
          {/* 任务达人管理按钮 - 只有任务达人才能看到 */}
          {isTaskExpert && user && (
            <div style={{ marginTop: '24px' }}>
              <button
                onClick={() => navigate('/task-experts/me/dashboard')}
                style={{
                  background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '50px',
                  padding: '12px 32px',
                  fontSize: '16px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  boxShadow: '0 4px 20px rgba(59, 130, 246, 0.4)',
                  transition: 'all 0.3s ease',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '8px'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 6px 25px rgba(59, 130, 246, 0.5)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 4px 20px rgba(59, 130, 246, 0.4)';
                }}
              >
                <span style={{ fontSize: '18px' }}>⚙️</span>
                进入管理后台
              </button>
            </div>
          )}
        </div>

        {/* 筛选和排序 */}
        <div className={styles.filtersContainer}>
          <div className={styles.filtersContent}>
            <div className={styles.filterGroup}>
              <label className={styles.filterLabel}>
                {t('taskExperts.filterBy')}
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className={styles.filterSelect}
              >
                {categories.map(cat => (
                  <option key={cat.value} value={cat.value}>
                    {cat.label}
                  </option>
                ))}
              </select>
            </div>

            <div className={styles.filterGroup}>
              <label className={styles.filterLabel}>
                {t('taskExperts.filterByCity')}
              </label>
              <select
                value={selectedCity}
                onChange={(e) => setSelectedCity(e.target.value)}
                className={styles.filterSelect}
              >
                <option value="all">{t('home.allCities')}</option>
                {CITIES.map(city => (
                  <option key={city} value={city}>
                    {city}
                  </option>
                ))}
              </select>
            </div>

            <div className={styles.filterGroup}>
              <label className={styles.filterLabel}>
                {t('taskExperts.sortBy')}
              </label>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className={styles.filterSelect}
              >
                {sortOptions.map(option => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {/* 任务达人列表 - 使用CSS模块优化 */}
        <div className={`${styles.contentArea} ${loading ? styles.loading : ''}`}>
          <div className={styles.expertsGrid}>
            {sortedExperts.map(expert => (
              <div
                key={expert.id}
                className={styles.expertCard}
                onClick={() => handleExpertClick(expert.id)}
              >
                {/* 地点 - 右上角 */}
                {expert.location && (
                  <div className={styles.locationBadge}>
                    📍 {expert.location}
                  </div>
                )}

                {/* 专家头部信息 */}
                <div className={styles.expertHeader}>
                  <div className={styles.avatarContainer}>
                    <LazyImage
                      src={expert.avatar}
                      alt={expert.name}
                      className={styles.avatar}
                      width={72}
                      height={72}
                    />
                    {expert.is_verified && (
                      <div className={styles.verifiedBadge}>
                        ✓
                      </div>
                    )}
                  </div>

                  <div className={styles.expertInfo}>
                    <h3 className={styles.expertName}>
                      {expert.name}
                    </h3>
                    <MemberBadge
                      level={expert.user_level}
                      variant="compact"
                      labelVip="taskExperts.vipExpert"
                      labelSuper="taskExperts.superExpert"
                      style={{ marginTop: 4 }}
                    />
                  </div>
                </div>

                {/* 简介 */}
                <p className={styles.bio}>
                  {expert.bio}
                </p>

                {/* 类别 */}
                {expert.category && (() => {
                  // 将下划线格式转换为驼峰格式用于翻译键
                  const categoryKey = expert.category.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
                  const categoryLabel = t(`taskExperts.${categoryKey}`) || expert.category;
                  return (
                    <div style={{ marginBottom: '16px' }}>
                      <span className={styles.categoryBadge}>
                        💼 {categoryLabel}
                      </span>
                    </div>
                  );
                })()}

              {/* 评分和统计 - 网格布局 */}
              <div className={styles.statsGrid}>
                <div className={styles.statCard}>
                  <div className={styles.statValue}>
                    {expert.avg_rating.toFixed(1)}
                  </div>
                  <div className={styles.statLabel}>
                    评分
                  </div>
                </div>
                <div className={styles.statCard}>
                  <div className={styles.statValue}>
                    {expert.completed_tasks}
                  </div>
                  <div style={{
                    fontSize: '11px',
                    color: 'rgba(255, 255, 255, 0.8)'
                  }}>
                    任务
                  </div>
                </div>
                <div style={{
                  padding: '12px',
                  background: 'rgba(255, 255, 255, 0.1)',
                  backdropFilter: 'blur(10px)',
                  borderRadius: '12px',
                  textAlign: 'center',
                  border: '1px solid rgba(255, 255, 255, 0.1)'
                }}>
                  <div style={{
                    fontSize: '18px',
                    fontWeight: '700',
                    color: 'white',
                    marginBottom: '4px'
                  }}>
                    {Math.round((expert.completion_rate || 0) * 100) / 100}%
                  </div>
                  <div style={{
                    fontSize: '11px',
                    color: 'rgba(255, 255, 255, 0.8)'
                  }}>
                    完成率
                  </div>
                </div>
              </div>

              {/* 成就徽章 */}
              {expert.achievements.length > 0 && (
                  <div style={{ marginBottom: '20px' }}>
                    <h4 style={{
                      fontSize: '14px',
                      fontWeight: '600',
                      color: 'white',
                      marginBottom: '8px'
                    }}>
                      {t('taskExperts.achievements')}:
                    </h4>
                    <div style={{
                      display: 'flex',
                      flexWrap: 'wrap',
                      gap: '6px'
                    }}>
                      {expert.achievements.map((achievement, index) => (
                        <span
                          key={index}
                          style={{
                            padding: '6px 14px',
                            background: 'rgba(255, 255, 255, 0.15)',
                            backdropFilter: 'blur(10px)',
                            color: 'white',
                            borderRadius: '10px',
                            fontSize: '12px',
                            border: '1px solid rgba(255, 255, 255, 0.2)'
                          }}
                        >
                          🏆 {achievement}
                        </span>
                      ))}
                    </div>
                  </div>
              )}

              {/* 操作按钮 */}
              <div style={{
                  display: 'flex',
                  gap: '12px'
                }}>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleExpertClick(expert.id);
                    }}
                    style={{
                      flex: 1,
                      padding: '14px',
                      background: 'rgba(255, 255, 255, 0.2)',
                      backdropFilter: 'blur(10px)',
                      border: '1px solid rgba(255, 255, 255, 0.3)',
                      borderRadius: '12px',
                      color: 'white',
                      fontSize: '15px',
                      fontWeight: '600',
                      cursor: 'pointer',
                      transition: 'all 0.3s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = 'rgba(255, 255, 255, 0.3)';
                      e.currentTarget.style.transform = 'scale(1.02)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)';
                      e.currentTarget.style.transform = 'scale(1)';
                    }}
                  >
                    {t('taskExperts.viewProfile')}
                  </button>
                  <button
                    onClick={(e) => handleRequestService(expert.id, expert.name, e)}
                    style={{
                      flex: 1,
                      padding: '14px',
                      background: 'rgba(255, 255, 255, 0.2)',
                      backdropFilter: 'blur(10px)',
                      border: '1px solid rgba(255, 255, 255, 0.3)',
                      borderRadius: '12px',
                      color: 'white',
                      fontSize: '15px',
                      fontWeight: '600',
                      cursor: 'pointer',
                      transition: 'all 0.3s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = 'rgba(255, 255, 255, 0.3)';
                      e.currentTarget.style.transform = 'scale(1.02)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)';
                      e.currentTarget.style.transform = 'scale(1)';
                    }}
                  >
                    {t('taskExperts.requestService')}
                  </button>
              </div>
              
              {/* 达人活动卡片 */}
              {(expertActivities[expert.id] ?? []).length > 0 && (
                <div style={{ marginTop: '24px', paddingTop: '24px', borderTop: '1px solid rgba(255, 255, 255, 0.2)' }}>
                    <h4 style={{ fontSize: '16px', fontWeight: 600, color: 'white', marginBottom: '16px' }}>
                      🎯 达人活动
                    </h4>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      {(expertActivities[expert.id] ?? []).map((activity: any) => {
                        // 获取活动图片
                        let rawImageUrl: string | null = null;
                        if (activity.images && Array.isArray(activity.images) && activity.images.length > 0) {
                          rawImageUrl = activity.images[0];
                        } else if (activity.service_images && Array.isArray(activity.service_images) && activity.service_images.length > 0) {
                          rawImageUrl = activity.service_images[0];
                        }
                        
                        // 处理图片URL，确保能正确显示
                        const activityImage = getActivityImageUrl(rawImageUrl);
                        
                        // 格式化价格显示（支持折扣）
                        const hasDiscount = activity.discount_percentage && activity.discount_percentage > 0;
                        const originalPrice = activity.original_price_per_participant || activity.reward;
                        const currentPrice = activity.discounted_price_per_participant || activity.reward;
                        const currency = activity.currency || 'GBP';
                        
                        // 格式化日期显示
                        // 对于多时间段活动，不显示单个日期，而是显示提示
                        let dateText = '';
                        let timeText = '';
                        if (!activity.has_time_slots && activity.deadline) {
                          dateText = new Date(activity.deadline).toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit' });
                          timeText = new Date(activity.deadline).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false });
                        } else if (activity.has_time_slots) {
                          // 多时间段活动显示提示
                          dateText = '多个时间段可选';
                          timeText = '';
                        }
                        
                        return (
                          <div
                            key={activity.id}
                            onClick={() => {
                              handleViewActivity(activity);
                            }}
                            style={{
                              background: '#fff',
                              border: '1px solid #e2e8f0',
                              borderRadius: '12px',
                              padding: 0,
                              cursor: 'pointer',
                              transition: 'all 0.2s',
                              overflow: 'hidden',
                              position: 'relative',
                              minHeight: '180px',
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.borderColor = '#3b82f6';
                              e.currentTarget.style.boxShadow = '0 8px 24px rgba(59, 130, 246, 0.2)';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.borderColor = '#e2e8f0';
                              e.currentTarget.style.boxShadow = 'none';
                            }}
                          >
                            {/* 背景图片层 */}
                            <div
                              style={{
                                position: 'absolute',
                                top: 0,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                                zIndex: 0,
                                overflow: 'hidden',
                              }}
                            >
                              <LazyImage
                                src={activityImage}
                                alt={activity.title}
                                style={{
                                  position: 'absolute',
                                  top: 0,
                                  left: 0,
                                  width: '100%',
                                  height: '100%',
                                  minHeight: '100%',
                                  objectFit: 'cover',
                                  objectPosition: 'center',
                                  opacity: 0.85,
                                }}
                              />
                              {/* 渐变遮罩层，确保文字可读性 */}
                              <div
                                style={{
                                  position: 'absolute',
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  background: 'linear-gradient(to bottom, rgba(0,0,0,0.3) 0%, rgba(0,0,0,0.6) 100%)',
                                }}
                              />
                            </div>
                            
                            {/* 内容层 */}
                            <div
                              style={{
                                position: 'relative',
                                zIndex: 1,
                                padding: '16px',
                                color: 'white',
                                display: 'flex',
                                flexDirection: 'column',
                                justifyContent: 'space-between',
                                minHeight: '180px',
                              }}
                            >
                              {/* 顶部：活动标签和价格 */}
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                                <div
                                  style={{
                                    background: 'rgba(255, 255, 255, 0.25)',
                                    backdropFilter: 'blur(10px)',
                                    color: 'white',
                                    padding: '4px 10px',
                                    borderRadius: '20px',
                                    fontSize: '10px',
                                    fontWeight: 600,
                                    border: '1px solid rgba(255, 255, 255, 0.3)',
                                  }}
                                >
                                  🎯 活动
                                </div>
                                {currentPrice && currentPrice > 0 && (
                                  <div
                                    style={{
                                      background: 'rgba(255, 255, 255, 0.9)',
                                      color: '#059669',
                                      padding: '3px 8px',
                                      borderRadius: '14px',
                                      fontSize: '11px',
                                      fontWeight: 700,
                                      display: 'flex',
                                      flexDirection: 'column',
                                      alignItems: 'flex-end',
                                      gap: '2px',
                                    }}
                                  >
                                    {hasDiscount && originalPrice && originalPrice > currentPrice ? (
                                      <>
                                        <div
                                          style={{
                                            fontSize: '9px',
                                            color: '#6b7280',
                                            textDecoration: 'line-through',
                                            opacity: 0.8,
                                          }}
                                        >
                                          {currency}{originalPrice.toFixed(2)}
                                        </div>
                                        <div style={{ color: '#059669' }}>
                                          {currency}{currentPrice.toFixed(2)}/人
                                        </div>
                                      </>
                                    ) : (
                                      <div style={{ color: '#059669' }}>
                                        {currency}{currentPrice.toFixed(2)}/人
                                      </div>
                                    )}
                                  </div>
                                )}
                              </div>
                              
                              {/* 中间：标题 */}
                              <div style={{ flex: 1 }}>
                                <h3
                                  style={{
                                    margin: '0 0 6px 0',
                                    fontSize: '16px',
                                    fontWeight: 700,
                                    color: 'white',
                                    lineHeight: 1.3,
                                    textShadow: '0 2px 4px rgba(0,0,0,0.3)',
                                  }}
                                >
                                  {activity.title}
                                </h3>
                              </div>
                              
                              {/* 底部：参与信息和时间 */}
                              <div>
                                <div
                                  style={{
                                    display: 'flex',
                                    flexDirection: 'row',
                                    justifyContent: 'space-between',
                                    alignItems: 'center',
                                    gap: '8px',
                                    padding: '10px 12px',
                                    background: 'rgba(255, 255, 255, 0.15)',
                                    backdropFilter: 'blur(10px)',
                                    borderRadius: '8px',
                                    border: '1px solid rgba(255, 255, 255, 0.2)',
                                  }}
                                >
                                  <div style={{ 
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: '6px',
                                    fontSize: '12px', 
                                    fontWeight: 500,
                                    flex: 1,
                                    minWidth: 0,
                                  }}>
                                    <span style={{ 
                                      fontSize: '14px',
                                      opacity: 0.9 
                                    }}>👥</span>
                                    <span style={{ opacity: 0.9 }}>参与者: </span>
                                    <span style={{ fontWeight: 700, color: '#fff' }}>
                                      {activity.current_participants || 0} / {activity.max_participants}
                                    </span>
                                  </div>
                                  {activity.has_time_slots ? (
                                    <div
                                      style={{
                                        display: 'flex',
                                        alignItems: 'center',
                                        gap: '4px',
                                        fontSize: '11px',
                                        background: 'rgba(16, 185, 129, 0.3)',
                                        padding: '4px 8px',
                                        borderRadius: '6px',
                                        fontWeight: 500,
                                        whiteSpace: 'nowrap',
                                        flexShrink: 0,
                                      }}
                                    >
                                      <span>⏰</span>
                                      <span>{dateText}</span>
                                    </div>
                                  ) : (dateText || timeText) ? (
                                    <div
                                      style={{
                                        display: 'flex',
                                        alignItems: 'center',
                                        gap: '4px',
                                        fontSize: '11px',
                                        background: 'rgba(255, 255, 255, 0.25)',
                                        padding: '4px 8px',
                                        borderRadius: '6px',
                                        whiteSpace: 'nowrap',
                                        flexShrink: 0,
                                      }}
                                    >
                                      <span>📅</span>
                                      <span>{dateText} {timeText}</span>
                                    </div>
                                  ) : null}
                                </div>
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
            </div>
          ))}
        </div>

        {/* 空状态 */}
        {sortedExperts.length === 0 && (
          <div style={{
            textAlign: 'center',
            padding: '60px 20px',
            background: '#f9fafb',
            borderRadius: '20px',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
            border: '1px solid #e5e7eb'
          }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>🔍</div>
            <div style={{ fontSize: '18px', color: '#1f2937', marginBottom: '8px' }}>
              {t('taskExperts.noExpertsFound')}
            </div>
            <div style={{ fontSize: '14px', color: '#6b7280' }}>
              {t('taskExperts.tryDifferentFilter')}
            </div>
          </div>
        )}
        </div>
      </div>
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
      
      {/* 专家详情弹窗 */}
      <ExpertDetailModal
        isOpen={showExpertDetailModal}
        onClose={() => {
          setShowExpertDetailModal(false);
          setSelectedExpertDetailId(null);
        }}
        expertId={selectedExpertDetailId || ''}
        onViewServices={() => {
          if (selectedExpertDetailId) {
            const expert = experts.find(e => e.id === selectedExpertDetailId);
            if (expert) {
              setSelectedExpertId(selectedExpertDetailId);
              setSelectedExpertName(expert.name);
              setShowServiceListModal(true);
            }
          }
        }}
      />
      
      {/* 服务列表弹窗 */}
      <ServiceListModal
        isOpen={showServiceListModal}
        onClose={() => {
          setShowServiceListModal(false);
          setSelectedExpertId(null);
          setSelectedExpertName(null);
        }}
        expertId={selectedExpertId || ''}
        expertName={selectedExpertName || undefined}
      />

      {/* 服务详情弹窗 */}
      <ServiceDetailModal
        isOpen={showServiceDetailModal}
        onClose={() => {
          setShowServiceDetailModal(false);
          setSelectedServiceId(null);
        }}
        serviceId={selectedServiceId}
        onApplySuccess={() => {
          // 申请成功后可以刷新或更新状态
          message.success('服务申请已提交');
        }}
      />
      
      {/* 活动详情弹窗 */}
      {showActivityDetailModal && selectedActivity && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.6)',
            backdropFilter: 'blur(4px)',
            zIndex: 1000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px',
            overflowY: 'auto',
          }}
          onClick={() => {
            setShowActivityDetailModal(false);
            setSelectedActivity(null);
          }}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '16px',
              maxWidth: '600px',
              width: '100%',
              maxHeight: '90vh',
              overflowY: 'auto',
              boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
              position: 'relative',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => {
                setShowActivityDetailModal(false);
                setSelectedActivity(null);
              }}
              style={{
                position: 'absolute',
                top: '16px',
                right: '16px',
                width: '32px',
                height: '32px',
                borderRadius: '50%',
                background: 'rgba(0, 0, 0, 0.5)',
                color: '#fff',
                border: 'none',
                fontSize: '20px',
                cursor: 'pointer',
                zIndex: 10,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              ×
            </button>
            
            {/* 活动图片 */}
            <div
              style={{
                width: '100%',
                height: '200px',
                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                position: 'relative',
                overflow: 'hidden',
              }}
            >
              <LazyImage
                src={(() => {
                  let rawImageUrl: string | null = null;
                  if (selectedActivity.images && Array.isArray(selectedActivity.images) && selectedActivity.images.length > 0) {
                    rawImageUrl = selectedActivity.images[0];
                  } else if (selectedActivity.service_images && Array.isArray(selectedActivity.service_images) && selectedActivity.service_images.length > 0) {
                    rawImageUrl = selectedActivity.service_images[0];
                  }
                  return getActivityImageUrl(rawImageUrl);
                })()}
                alt={selectedActivity.title}
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  width: '100%',
                  height: '100%',
                  minHeight: '100%',
                  objectFit: 'cover',
                  objectPosition: 'center',
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  background: 'linear-gradient(to bottom, rgba(0,0,0,0.2) 0%, rgba(0,0,0,0.4) 100%)',
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  top: '16px',
                  left: '16px',
                  background: 'rgba(255, 255, 255, 0.25)',
                  backdropFilter: 'blur(10px)',
                  color: 'white',
                  padding: '6px 12px',
                  borderRadius: '20px',
                  fontSize: '12px',
                  fontWeight: 600,
                  border: '1px solid rgba(255, 255, 255, 0.3)',
                }}
              >
                🎯 活动
              </div>
            </div>

            {/* 活动内容 */}
            <div style={{ padding: '24px' }}>
              {/* 标题 */}
              <h2
                style={{
                  margin: '0 0 12px 0',
                  fontSize: '24px',
                  fontWeight: 700,
                  color: '#1a202c',
                  lineHeight: 1.3,
                }}
              >
                {selectedActivity.title}
              </h2>

              {/* 价格和参与者信息 */}
              <div
                style={{
                  display: 'flex',
                  gap: '16px',
                  marginBottom: '20px',
                  padding: '16px',
                  background: '#f0f9ff',
                  borderRadius: '12px',
                  border: '1px solid #bae6fd',
                }}
              >
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '12px', color: '#0369a1', marginBottom: '6px', fontWeight: 500 }}>
                    参与费用
                  </div>
                  <div style={{ fontSize: '24px', fontWeight: 700, color: '#0284c7' }}>
                    {(() => {
                      const hasDiscount = selectedActivity.discount_percentage && selectedActivity.discount_percentage > 0;
                      const originalPrice = selectedActivity.original_price_per_participant || selectedActivity.reward;
                      const currentPrice = selectedActivity.discounted_price_per_participant || selectedActivity.reward;
                      const currency = selectedActivity.currency || 'GBP';
                      
                      if (!currentPrice || currentPrice <= 0) {
                        return <span>免费</span>;
                      }
                      
                      if (hasDiscount && originalPrice && originalPrice > currentPrice) {
                        return (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <span style={{ textDecoration: 'line-through', fontSize: '18px', color: '#9ca3af', fontWeight: 400 }}>
                                {currency}{originalPrice.toFixed(2)}
                              </span>
                              <span style={{ fontSize: '12px', color: '#ef4444', fontWeight: 600, background: '#fee2e2', padding: '2px 6px', borderRadius: '4px' }}>
                                -{selectedActivity.discount_percentage.toFixed(0)}%
                              </span>
                            </div>
                            <div>
                              <span style={{ color: '#0284c7' }}>
                                {currency}{currentPrice.toFixed(2)}
                              </span>
                              <span style={{ fontSize: '14px', fontWeight: 400, color: '#0369a1' }}> / 人</span>
                            </div>
                          </div>
                        );
                      }
                      
                      return (
                        <>
                          <span>{currency}{currentPrice.toFixed(2)}</span>
                          <span style={{ fontSize: '14px', fontWeight: 400, color: '#0369a1' }}> / 人</span>
                        </>
                      );
                    })()}
                  </div>
                </div>
                <div
                  style={{
                    width: '1px',
                    background: '#bae6fd',
                  }}
                />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '12px', color: '#0369a1', marginBottom: '6px', fontWeight: 500 }}>
                    参与者
                  </div>
                  <div style={{ fontSize: '20px', fontWeight: 700, color: '#0284c7' }}>
                    <span>{selectedActivity.current_participants || 0}</span> /{' '}
                    <span>{selectedActivity.max_participants}</span>
                  </div>
                  <div style={{ fontSize: '11px', color: '#0369a1', marginTop: '4px' }}>
                    <span>
                      {(selectedActivity.max_participants || 0) - (selectedActivity.current_participants || 0)}
                    </span>{' '}
                    个空位
                  </div>
                </div>
              </div>

              {/* 活动描述 */}
              <div style={{ marginBottom: '20px' }}>
                <h3
                  style={{
                    margin: '0 0 8px 0',
                    fontSize: '16px',
                    fontWeight: 600,
                    color: '#2d3748',
                  }}
                >
                  活动描述
                </h3>
                <p
                  style={{
                    margin: 0,
                    fontSize: '14px',
                    color: '#4a5568',
                    lineHeight: 1.7,
                    whiteSpace: 'pre-wrap',
                  }}
                >
                  {selectedActivity.description}
                </p>
              </div>

              {/* 时间段信息 */}
              {selectedActivity.has_time_slots ? (
                // 时间段服务：显示时间段列表
                <div
                  style={{
                    marginBottom: '20px',
                    padding: '16px',
                    background: '#f8fafc',
                    borderRadius: '12px',
                    border: '1px solid #e2e8f0',
                  }}
                >
                  <h3
                    style={{
                      margin: '0 0 12px 0',
                      fontSize: '16px',
                      fontWeight: 600,
                      color: '#2d3748',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                    }}
                  >
                    <span>⏰</span>
                    <span>可选时间段</span>
                  </h3>
                  {loadingActivityTimeSlots ? (
                    <div style={{ textAlign: 'center', padding: '20px', color: '#718096' }}>
                      加载时间段中...
                    </div>
                  ) : activityTimeSlots.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '20px', color: '#718096' }}>
                      暂无可用时间段
                    </div>
                  ) : (
                    <div style={{ 
                      maxHeight: '300px', 
                      overflowY: 'auto',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '8px',
                    }}>
                      {(() => {
                        // 按日期分组显示时间段
                        const { TimeHandlerV2 } = require('../utils/timeUtils');
                        const slotsByDate: { [key: string]: any[] } = {};
                        activityTimeSlots
                          .sort((a, b) => {
                            const aStart = a.slot_start_datetime || (a.slot_date + 'T' + a.start_time + 'Z');
                            const bStart = b.slot_start_datetime || (b.slot_date + 'T' + b.start_time + 'Z');
                            return aStart.localeCompare(bStart);
                          })
                          .forEach((slot: any) => {
                            const slotStartStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                            const slotDateUK = TimeHandlerV2.formatUtcToLocal(
                              slotStartStr.includes('T') ? slotStartStr : `${slotStartStr}T00:00:00Z`,
                              'YYYY-MM-DD',
                              'Europe/London'
                            );
                            if (!slotsByDate[slotDateUK]) {
                              slotsByDate[slotDateUK] = [];
                            }
                            slotsByDate[slotDateUK]!.push(slot);
                          });

                        const dates = Object.keys(slotsByDate).sort();
                        
                        return dates.map(date => {
                          const slots = slotsByDate[date] ?? [];
                          const firstSlot = slots[0];
                          const dateStr = firstSlot.slot_start_datetime || firstSlot.slot_date;
                          const formattedDate = TimeHandlerV2.formatUtcToLocal(
                            dateStr.includes('T') ? dateStr : `${dateStr}T00:00:00Z`,
                            'YYYY年MM月DD日 ddd',
                            'Europe/London'
                          );
                          
                          return (
                            <div key={date} style={{ marginBottom: '12px' }}>
                              <div style={{ 
                                fontSize: '13px', 
                                fontWeight: 600, 
                                color: '#1a202c', 
                                marginBottom: '8px',
                                paddingBottom: '6px',
                                borderBottom: '1px solid #e2e8f0',
                              }}>
                                📅 {formattedDate}
                              </div>
                              <div style={{ 
                                display: 'grid', 
                                gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', 
                                gap: '8px',
                              }}>
                                {(slots ?? []).map((slot: any) => {
                                  const isFull = slot.current_participants >= slot.max_participants;
                                  const isExpired = slot.is_expired === true;
                                  const availableSpots = slot.max_participants - slot.current_participants;
                                  const isSelected = selectedTimeSlotId === slot.id;
                                  const isClickable = !isExpired && !isFull;
                                  
                                  const startTimeStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                                  const endTimeStr = slot.slot_end_datetime || (slot.slot_date + 'T' + slot.end_time + 'Z');
                                  const startTimeUK = TimeHandlerV2.formatUtcToLocal(
                                    startTimeStr.includes('T') ? startTimeStr : `${startTimeStr}T00:00:00Z`,
                                    'HH:mm',
                                    'Europe/London'
                                  );
                                  const endTimeUK = TimeHandlerV2.formatUtcToLocal(
                                    endTimeStr.includes('T') ? endTimeStr : `${endTimeStr}T00:00:00Z`,
                                    'HH:mm',
                                    'Europe/London'
                                  );
                                  
                                  return (
                                    <div
                                      key={slot.id}
                                      onClick={() => {
                                        if (isClickable) {
                                          setSelectedTimeSlotId(slot.id);
                                        }
                                      }}
                                      style={{
                                        padding: '10px',
                                        border: `2px solid ${isSelected ? '#3b82f6' : (isExpired || isFull ? '#e2e8f0' : '#cbd5e0')}`,
                                        borderRadius: '8px',
                                        background: isSelected ? '#eff6ff' : (isExpired || isFull ? '#f7fafc' : '#fff'),
                                        opacity: isExpired || isFull ? 0.7 : 1,
                                        cursor: isClickable ? 'pointer' : 'not-allowed',
                                        transition: 'all 0.2s',
                                      }}
                                      onMouseEnter={(e) => {
                                        if (isClickable && !isSelected) {
                                          e.currentTarget.style.borderColor = '#3b82f6';
                                          e.currentTarget.style.boxShadow = '0 2px 8px rgba(59, 130, 246, 0.2)';
                                        }
                                      }}
                                      onMouseLeave={(e) => {
                                        if (isClickable && !isSelected) {
                                          e.currentTarget.style.borderColor = '#cbd5e0';
                                          e.currentTarget.style.boxShadow = 'none';
                                        }
                                      }}
                                    >
                                      <div style={{ 
                                        fontWeight: 600, 
                                        color: isExpired ? '#9ca3af' : (isSelected ? '#3b82f6' : '#1a202c'), 
                                        marginBottom: '4px',
                                        fontSize: '13px',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'space-between',
                                      }}>
                                        <span>{startTimeUK} - {endTimeUK}</span>
                                        {isSelected && (
                                          <span style={{ 
                                            fontSize: '11px', 
                                            color: '#3b82f6',
                                            fontWeight: 600,
                                          }}>✓ 已选择</span>
                                        )}
                                        {isExpired && <span style={{ marginLeft: '4px', fontSize: '11px', color: '#ef4444' }}>(已过期)</span>}
                                      </div>
                                      <div style={{ 
                                        fontSize: '12px', 
                                        color: '#059669', 
                                        marginBottom: '4px',
                                        fontWeight: 600,
                                      }}>
                                        {selectedActivity.currency || 'GBP'} {slot.activity_price?.toFixed(2) || slot.price_per_participant.toFixed(2)} / 人
                                      </div>
                                      <div style={{ 
                                        fontSize: '11px', 
                                        color: isFull ? '#e53e3e' : '#48bb78',
                                      }}>
                                        {isFull ? `已满 (${slot.current_participants}/${slot.max_participants})` : `${slot.current_participants}/${slot.max_participants} 人 (${availableSpots} 个空位)`}
                                      </div>
                                    </div>
                                  );
                                })}
                              </div>
                            </div>
                          );
                        });
                      })()}
                    </div>
                  )}
                </div>
              ) : selectedActivity.deadline ? (
                // 非时间段服务：显示截止日期
                <div
                  style={{
                    marginBottom: '20px',
                    padding: '16px',
                    background: '#f8fafc',
                    borderRadius: '12px',
                    border: '1px solid #e2e8f0',
                  }}
                >
                  <h3
                    style={{
                      margin: '0 0 12px 0',
                      fontSize: '16px',
                      fontWeight: 600,
                      color: '#2d3748',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                    }}
                  >
                    <span>⏰</span>
                    <span>活动时间</span>
                  </h3>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '12px',
                      fontSize: '15px',
                      color: '#1a202c',
                      fontWeight: 500,
                    }}
                  >
                    <span>📅</span>
                    <span>
                      {new Date(selectedActivity.deadline).toLocaleDateString('zh-CN', {
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric',
                      })}
                    </span>
                    {selectedActivity.deadline && (
                      <>
                        <span style={{ color: '#cbd5e0' }}>|</span>
                        <span>
                          {new Date(selectedActivity.deadline).toLocaleTimeString('zh-CN', {
                            hour: '2-digit',
                            minute: '2-digit',
                            hour12: false,
                          })}
                        </span>
                      </>
                    )}
                  </div>
                </div>
              ) : null}

              {/* 操作按钮 */}
              <div style={{ display: 'flex', gap: '12px' }}>
                <button
                  onClick={() => {
                    setShowActivityDetailModal(false);
                    setSelectedActivity(null);
                  }}
                  style={{
                    flex: 1,
                    padding: '14px',
                    background: '#f3f4f6',
                    color: '#374151',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '15px',
                    fontWeight: 600,
                    cursor: 'pointer',
                    transition: 'all 0.2s',
                  }}
                  onMouseOver={(e) => {
                    e.currentTarget.style.background = '#e5e7eb';
                  }}
                  onMouseOut={(e) => {
                    e.currentTarget.style.background = '#f3f4f6';
                  }}
                >
                  关闭
                </button>
                <button
                  onClick={async () => {
                    if (!user) {
                      setShowLoginModal(true);
                      return;
                    }
                    
                    // 如果是时间段服务，需要选择时间段
                    if (selectedActivity.has_time_slots) {
                      // 检查是否已选择时间段
                      if (!selectedTimeSlotId) {
                        message.warning('请先选择一个时间段');
                        return;
                      }
                      // 验证选中的时间段是否仍然可用
                      const selectedSlot = activityTimeSlots.find((slot: any) => slot.id === selectedTimeSlotId);
                      if (!selectedSlot) {
                        message.warning('选中的时间段不存在');
                        return;
                      }
                      if (selectedSlot.is_expired || selectedSlot.current_participants >= selectedSlot.max_participants) {
                        message.warning('选中的时间段已不可用，请重新选择');
                        setSelectedTimeSlotId(null);
                        return;
                      }
                      try {
                        const idempotencyKey = `${user.id}_${selectedActivity.id}_${Date.now()}`;
                        await applyToActivity(selectedActivity.id, {
                          idempotency_key: idempotencyKey,
                          time_slot_id: selectedTimeSlotId,
                          is_multi_participant: (selectedActivity.max_participants || 1) > 1, // 根据活动的max_participants判断
                        });
                        message.success('申请成功！已为您创建任务');
                        setShowActivityDetailModal(false);
                        setSelectedActivity(null);
                        setActivityTimeSlots([]);
                        setSelectedTimeSlotId(null);
                      } catch (err: any) {
                                                message.error(err.response?.data?.detail || '申请失败，请重试');
                      }
                    } else {
                      // 非时间段服务
                      try {
                        const idempotencyKey = `${user.id}_${selectedActivity.id}_${Date.now()}`;
                        await applyToActivity(selectedActivity.id, {
                          idempotency_key: idempotencyKey,
                          is_multi_participant: (selectedActivity.max_participants || 1) > 1, // 根据活动的max_participants判断
                        });
                        message.success('申请成功！已为您创建任务');
                        setShowActivityDetailModal(false);
                        setSelectedActivity(null);
                        setActivityTimeSlots([]);
                        setSelectedTimeSlotId(null);
                      } catch (err: any) {
                                                message.error(err.response?.data?.detail || '申请失败，请重试');
                      }
                    }
                  }}
                  disabled={selectedActivity.has_time_slots && !selectedTimeSlotId}
                  style={{
                    flex: 2,
                    padding: '14px',
                    background: selectedActivity.has_time_slots && !selectedTimeSlotId 
                      ? 'linear-gradient(135deg, #9ca3af, #6b7280)' 
                      : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                    color: 'white',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '15px',
                    fontWeight: 600,
                    cursor: selectedActivity.has_time_slots && !selectedTimeSlotId ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s',
                    boxShadow: selectedActivity.has_time_slots && !selectedTimeSlotId 
                      ? 'none' 
                      : '0 4px 12px rgba(59, 130, 246, 0.3)',
                    opacity: selectedActivity.has_time_slots && !selectedTimeSlotId ? 0.6 : 1,
                  }}
                  onMouseOver={(e) => {
                    if (!(selectedActivity.has_time_slots && !selectedTimeSlotId)) {
                      e.currentTarget.style.transform = 'translateY(-2px)';
                      e.currentTarget.style.boxShadow = '0 6px 16px rgba(59, 130, 246, 0.4)';
                    }
                  }}
                  onMouseOut={(e) => {
                    if (!(selectedActivity.has_time_slots && !selectedTimeSlotId)) {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                    }
                  }}
                >
                  {selectedActivity.has_time_slots 
                    ? (selectedTimeSlotId ? '立即申请参与' : '请先选择一个时间段')
                    : '立即申请参与'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default TaskExperts;
