import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import api, { fetchCurrentUser, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout, getPublicTaskExperts, getTaskExpert } from '../api';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import SEOHead from '../components/SEOHead';
import ServiceDetailModal from '../components/ServiceDetailModal';

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
  const [isMobile, setIsMobile] = useState(false);

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
  
  // 服务详情弹窗状态
  const [showServiceDetailModal, setShowServiceDetailModal] = useState(false);
  const [selectedServiceId, setSelectedServiceId] = useState<number | null>(null);

  // 模拟数据 - 实际项目中应该从API获取
  const mockExperts: TaskExpert[] = [
    {
      id: '1',
      name: '张技术',
      avatar: '/static/avatar1.png',
      user_level: 'super',
      avg_rating: 4.9,
      completed_tasks: 156,
      total_tasks: 160,
      completion_rate: 97.5,
      expertise_areas: ['编程开发', '网站建设', '移动应用'],
      is_verified: true,
      bio: '资深全栈开发工程师，10年开发经验，精通多种编程语言和框架。',
      join_date: '2023-01-15',
      last_active: '2024-01-10',
      featured_skills: ['React', 'Node.js', 'Python', 'Vue.js'],
      achievements: ['技术认证', '优秀贡献者', '年度达人'],
      response_time: '2小时内',
      success_rate: 98,
      location: 'London'
    }
  ];

  const categories = [
    { value: 'all', label: t('taskExperts.allCategories') },
    { value: 'programming', label: t('taskExperts.programming') },
    { value: 'design', label: t('taskExperts.design') },
    { value: 'marketing', label: t('taskExperts.marketing') },
    { value: 'writing', label: t('taskExperts.writing') },
    { value: 'translation', label: t('taskExperts.translation') },
    { value: 'tutoring', label: t('taskExperts.tutoring') },
    { value: 'food', label: t('taskExperts.food') },
    { value: 'beverage', label: t('taskExperts.beverage') },
    { value: 'cake', label: t('taskExperts.cake') }
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
        
        // 检查用户是否是任务达人
        if (userData && userData.id) {
          try {
            await getTaskExpert(userData.id);
            setIsTaskExpert(true);
          } catch (error: any) {
            // 如果不是任务达人（404错误），设置为false
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
      }).catch(error => {
        console.error('Failed to get notifications:', error);
      });
      
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

  useEffect(() => {
    loadExperts();
  }, [selectedCategory, selectedCity, sortBy]);

  const loadExperts = async () => {
    setLoading(true);
    try {
      // 从API获取任务达人列表
      const expertsData = await getPublicTaskExperts(selectedCategory !== 'all' ? selectedCategory : undefined);
      
      // 转换数据格式 - 后端返回 { task_experts: [...] }
      let expertsList: any[] = [];
      if (Array.isArray(expertsData)) {
        expertsList = expertsData;
      } else if (expertsData.task_experts) {
        expertsList = expertsData.task_experts;
      } else if (expertsData.items) {
        expertsList = expertsData.items;
      }
      
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
      }));
      
      // 应用城市筛选
      if (selectedCity !== 'all') {
        expertsList = expertsList.filter((expert: any) => expert.location === selectedCity);
      }
      
      // 应用排序
      expertsList.sort((a: any, b: any) => {
        switch (sortBy) {
          case 'rating':
            return (b.avg_rating || 0) - (a.avg_rating || 0);
          case 'tasks':
            return (b.completed_tasks || 0) - (a.completed_tasks || 0);
          case 'recent':
            return new Date(b.last_active || 0).getTime() - new Date(a.last_active || 0).getTime();
          default:
            return 0;
        }
      });
      
      console.log('加载的任务达人列表:', expertsList);
      setExperts(expertsList);
    } catch (err: any) {
      console.error('加载任务达人列表失败:', err);
      console.error('错误详情:', err.response?.data);
      message.error('加载任务达人列表失败');
      // 失败时使用空数组
      setExperts([]);
    } finally {
      setLoading(false);
    }
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

  const filteredExperts = experts.filter(expert => {
    // 按分类筛选
    if (selectedCategory !== 'all') {
      const categoryMatch = expert.expertise_areas.some(area => 
        area.toLowerCase().includes(selectedCategory.toLowerCase())
      );
      if (!categoryMatch) return false;
    }
    
    // 按城市筛选
    if (selectedCity !== 'all') {
      if (!expert.location || expert.location !== selectedCity) {
        return false;
      }
    }
    
    return true;
  });

  const sortedExperts = [...filteredExperts].sort((a, b) => {
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

  const handleExpertClick = (expertId: string) => {
    navigate(`/user/${expertId}`);
  };

  const handleRequestService = async (expertId: string, e: React.MouseEvent) => {
    e.stopPropagation(); // 阻止事件冒泡，避免触发卡片的点击事件
    
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    // 获取任务达人的服务列表
    try {
      const { getTaskExpertServices } = await import('../api');
      const services = await getTaskExpertServices(expertId, 'active');
      
      if (services && services.length > 0) {
        // 如果有多个服务，可以显示服务列表让用户选择
        // 这里简化处理：直接显示第一个服务
        setSelectedServiceId(services[0].id);
        setShowServiceDetailModal(true);
      } else {
        message.info('该任务达人暂无可用服务');
      }
    } catch (err: any) {
      message.error('加载服务列表失败');
      console.error('Failed to load services:', err);
    }
  };


  const getLevelColor = (level: string) => {
    switch (level) {
      case 'super': return '#8b5cf6';
      case 'vip': return '#f59e0b';
      default: return '#6b7280';
    }
  };

  const getLevelText = (level: string) => {
    switch (level) {
      case 'super': return t('taskExperts.superExpert');
      case 'vip': return t('taskExperts.vipExpert');
      default: return t('taskExperts.normalExpert');
    }
  };

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
      
      <div style={{
        maxWidth: '1200px',
        margin: '0 auto',
        padding: '0 20px 20px 20px'
      }}>
        {/* 页面头部 */}
        <div style={{
          textAlign: 'center',
          marginBottom: '40px',
          color: '#1f2937'
        }}>
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
          <p style={{
            fontSize: '18px',
            opacity: 0.9,
            margin: '0 auto',
            maxWidth: '600px',
            lineHeight: '1.6'
          }}>
            {t('taskExperts.subtitle')}
          </p>
          
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
        <div style={{
          background: 'rgba(255, 255, 255, 0.95)',
          backdropFilter: 'blur(20px)',
          borderRadius: '20px',
          padding: '24px',
          marginBottom: '32px',
          boxShadow: '0 15px 35px rgba(0,0,0,0.1)'
        }}>
          <div style={{
            display: 'flex',
            gap: '20px',
            flexWrap: 'wrap',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <label style={{ 
                fontSize: '16px', 
                fontWeight: '600', 
                color: '#374151' 
              }}>
                {t('taskExperts.filterBy')}:
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                style={{
                  padding: '8px 16px',
                  borderRadius: '12px',
                  border: '2px solid #e5e7eb',
                  fontSize: '14px',
                  outline: 'none',
                  cursor: 'pointer',
                  background: '#fff'
                }}
              >
                {categories.map(cat => (
                  <option key={cat.value} value={cat.value}>
                    {cat.label}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <label style={{ 
                fontSize: '16px', 
                fontWeight: '600', 
                color: '#374151' 
              }}>
                {t('taskExperts.filterByCity')}:
              </label>
              <select
                value={selectedCity}
                onChange={(e) => setSelectedCity(e.target.value)}
                style={{
                  padding: '8px 16px',
                  borderRadius: '12px',
                  border: '2px solid #e5e7eb',
                  fontSize: '14px',
                  outline: 'none',
                  cursor: 'pointer',
                  background: '#fff'
                }}
              >
                <option value="all">{t('home.allCities')}</option>
                {CITIES.map(city => (
                  <option key={city} value={city}>
                    {city}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <label style={{ 
                fontSize: '16px', 
                fontWeight: '600', 
                color: '#374151' 
              }}>
                {t('taskExperts.sortBy')}:
              </label>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                style={{
                  padding: '8px 16px',
                  borderRadius: '12px',
                  border: '2px solid #e5e7eb',
                  fontSize: '14px',
                  outline: 'none',
                  cursor: 'pointer',
                  background: '#fff'
                }}
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

        {/* 任务达人列表 */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: isMobile ? '1fr' : 'repeat(auto-fit, minmax(350px, 1fr))',
          gap: '24px',
          marginBottom: '40px'
        }}>
          {sortedExperts.map(expert => (
            <div
              key={expert.id}
              style={{
                background: 'rgba(255, 255, 255, 0.95)',
                backdropFilter: 'blur(20px)',
                borderRadius: '20px',
                padding: '24px',
                boxShadow: '0 15px 35px rgba(0,0,0,0.1)',
                transition: 'all 0.3s ease',
                cursor: 'pointer',
                position: 'relative',
                overflow: 'hidden'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-5px)';
                e.currentTarget.style.boxShadow = '0 20px 40px rgba(0,0,0,0.15)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 15px 35px rgba(0,0,0,0.1)';
              }}
            >
              {/* 装饰性背景 */}
              <div style={{
                position: 'absolute',
                top: '-20px',
                right: '-20px',
                width: '80px',
                height: '80px',
                background: 'linear-gradient(45deg, #667eea, #764ba2)',
                borderRadius: '50%',
                opacity: 0.1
              }} />

              <div style={{ position: 'relative', zIndex: 1 }}>
                {/* 专家头部信息 */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '16px',
                  marginBottom: '20px'
                }}>
                  <div style={{ position: 'relative' }}>
                    <img
                      src={expert.avatar}
                      alt={expert.name}
                      style={{
                        width: '60px',
                        height: '60px',
                        borderRadius: '50%',
                        objectFit: 'cover',
                        border: '3px solid #fff',
                        boxShadow: '0 4px 15px rgba(0,0,0,0.1)'
                      }}
                    />
                    {expert.is_verified && (
                      <div style={{
                        position: 'absolute',
                        bottom: '-2px',
                        right: '-2px',
                        width: '20px',
                        height: '20px',
                        background: '#10b981',
                        borderRadius: '50%',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '12px',
                        color: '#fff'
                      }}>
                        ✓
                      </div>
                    )}
                  </div>

                  <div style={{ flex: 1 }}>
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      marginBottom: '4px'
                    }}>
                      <h3 style={{
                        fontSize: '20px',
                        fontWeight: '700',
                        color: '#1f2937',
                        margin: 0
                      }}>
                        {expert.name}
                      </h3>
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '12px',
                        fontSize: '12px',
                        fontWeight: '600',
                        color: '#fff',
                        background: getLevelColor(expert.user_level)
                      }}>
                        {getLevelText(expert.user_level)}
                      </span>
                    </div>
                    <p style={{
                      fontSize: '14px',
                      color: '#6b7280',
                      margin: 0,
                      lineHeight: '1.4'
                    }}>
                      {expert.bio}
                    </p>
                  </div>
                </div>

                {/* 评分和统计 */}
                <div style={{
                  display: 'flex',
                  gap: '16px',
                  marginBottom: '20px',
                  flexWrap: 'wrap'
                }}>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '6px 12px',
                    background: 'rgba(255, 193, 7, 0.1)',
                    borderRadius: '12px'
                  }}>
                    <span style={{ color: '#f59e0b', fontSize: '16px' }}>⭐</span>
                    <span style={{ fontSize: '14px', fontWeight: '600', color: '#374151' }}>
                      {expert.avg_rating.toFixed(1)}
                    </span>
                  </div>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '6px 12px',
                    background: 'rgba(16, 185, 129, 0.1)',
                    borderRadius: '12px'
                  }}>
                    <span style={{ color: '#10b981', fontSize: '16px' }}>✅</span>
                    <span style={{ fontSize: '14px', fontWeight: '600', color: '#374151' }}>
                      {expert.completed_tasks} {t('taskExperts.tasks')}
                    </span>
                  </div>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '6px 12px',
                    background: 'rgba(59, 130, 246, 0.1)',
                    borderRadius: '12px'
                  }}>
                    <span style={{ color: '#3b82f6', fontSize: '16px' }}>📊</span>
                    <span style={{ fontSize: '14px', fontWeight: '600', color: '#374151' }}>
                      {expert.completion_rate}%
                    </span>
                  </div>
                </div>

                {/* 专业领域 */}
                <div style={{ marginBottom: '20px' }}>
                  <h4 style={{
                    fontSize: '14px',
                    fontWeight: '600',
                    color: '#374151',
                    marginBottom: '8px'
                  }}>
                    {t('taskExperts.expertiseAreas')}:
                  </h4>
                  <div style={{
                    display: 'flex',
                    flexWrap: 'wrap',
                    gap: '6px'
                  }}>
                    {expert.expertise_areas.map((area, index) => (
                      <span
                        key={index}
                        style={{
                          padding: '4px 8px',
                          background: 'linear-gradient(135deg, #667eea, #764ba2)',
                          color: '#fff',
                          borderRadius: '8px',
                          fontSize: '12px',
                          fontWeight: '500'
                        }}
                      >
                        {area}
                      </span>
                    ))}
                  </div>
                </div>

                {/* 特色技能 */}
                <div style={{ marginBottom: '20px' }}>
                  <h4 style={{
                    fontSize: '14px',
                    fontWeight: '600',
                    color: '#374151',
                    marginBottom: '8px'
                  }}>
                    {t('taskExperts.featuredSkills')}:
                  </h4>
                  <div style={{
                    display: 'flex',
                    flexWrap: 'wrap',
                    gap: '6px'
                  }}>
                    {expert.featured_skills.map((skill, index) => (
                      <span
                        key={index}
                        style={{
                          padding: '4px 8px',
                          background: 'rgba(102, 126, 234, 0.1)',
                          color: '#667eea',
                          borderRadius: '8px',
                          fontSize: '12px',
                          fontWeight: '500',
                          border: '1px solid rgba(102, 126, 234, 0.2)'
                        }}
                      >
                        {skill}
                      </span>
                    ))}
                  </div>
                </div>

                {/* 成就徽章 */}
                {expert.achievements.length > 0 && (
                  <div style={{ marginBottom: '20px' }}>
                    <h4 style={{
                      fontSize: '14px',
                      fontWeight: '600',
                      color: '#374151',
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
                            padding: '4px 8px',
                            background: 'rgba(245, 158, 11, 0.1)',
                            color: '#f59e0b',
                            borderRadius: '8px',
                            fontSize: '12px',
                            fontWeight: '500',
                            border: '1px solid rgba(245, 158, 11, 0.2)'
                          }}
                        >
                          🏆 {achievement}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {/* 响应时间和成功率 */}
                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  marginBottom: '20px',
                  fontSize: '12px',
                  color: '#6b7280'
                }}>
                  <span>{t('taskExperts.responseTime')}: {expert.response_time}</span>
                  <span>{t('taskExperts.successRate')}: {expert.success_rate}%</span>
                </div>

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
                      padding: '12px 16px',
                      background: 'transparent',
                      border: '2px solid #667eea',
                      borderRadius: '12px',
                      color: '#667eea',
                      fontSize: '14px',
                      fontWeight: '600',
                      cursor: 'pointer',
                      transition: 'all 0.3s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = '#667eea';
                      e.currentTarget.style.color = '#fff';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'transparent';
                      e.currentTarget.style.color = '#667eea';
                    }}
                  >
                    {t('taskExperts.viewProfile')}
                  </button>
                  <button
                    onClick={(e) => handleRequestService(expert.id, e)}
                    style={{
                      flex: 1,
                      padding: '12px 16px',
                      background: 'linear-gradient(135deg, #667eea, #764ba2)',
                      border: 'none',
                      borderRadius: '12px',
                      color: '#fff',
                      fontSize: '14px',
                      fontWeight: '600',
                      cursor: 'pointer',
                      transition: 'all 0.3s ease',
                      boxShadow: '0 4px 15px rgba(102, 126, 234, 0.3)'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'translateY(-2px)';
                      e.currentTarget.style.boxShadow = '0 6px 20px rgba(102, 126, 234, 0.4)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 4px 15px rgba(102, 126, 234, 0.3)';
                    }}
                  >
                    {t('taskExperts.requestService')}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* 空状态 */}
        {sortedExperts.length === 0 && (
          <div style={{
            textAlign: 'center',
            padding: '60px 20px',
            background: 'rgba(255, 255, 255, 0.95)',
            backdropFilter: 'blur(20px)',
            borderRadius: '20px',
            boxShadow: '0 15px 35px rgba(0,0,0,0.1)'
          }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>🔍</div>
            <div style={{ fontSize: '18px', color: '#6b7280', marginBottom: '8px' }}>
              {t('taskExperts.noExpertsFound')}
            </div>
            <div style={{ fontSize: '14px', color: '#9ca3af' }}>
              {t('taskExperts.tryDifferentFilter')}
            </div>
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
    </div>
  );
};

export default TaskExperts;
