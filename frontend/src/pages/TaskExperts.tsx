import React, { useState, useEffect } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import api, { fetchCurrentUser, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout } from '../api';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';

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
  const [experts, setExperts] = useState<TaskExpert[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedCity, setSelectedCity] = useState('all');
  const [sortBy, setSortBy] = useState('rating');
  const [isMobile, setIsMobile] = useState(false);
  
  // 用户和通知相关状态
  const [user, setUser] = useState<any>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 登录弹窗状态
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

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
    },
    {
      id: '2',
      name: '李设计',
      avatar: '/static/avatar2.png',
      user_level: 'vip',
      avg_rating: 4.8,
      completed_tasks: 89,
      total_tasks: 92,
      completion_rate: 96.7,
      expertise_areas: ['UI/UX设计', '平面设计', '品牌设计'],
      is_verified: true,
      bio: '专业UI/UX设计师，拥有丰富的设计经验和敏锐的审美眼光。',
      join_date: '2023-03-20',
      last_active: '2024-01-09',
      featured_skills: ['Figma', 'Photoshop', 'Illustrator', 'Sketch'],
      achievements: ['设计认证', '创意达人'],
      response_time: '4小时内',
      success_rate: 96,
      location: 'Manchester'
    },
    {
      id: '3',
      name: '王营销',
      avatar: '/static/avatar3.png',
      user_level: 'vip',
      avg_rating: 4.7,
      completed_tasks: 67,
      total_tasks: 70,
      completion_rate: 95.7,
      expertise_areas: ['数字营销', '社交媒体', '内容创作'],
      is_verified: true,
      bio: '数字营销专家，擅长品牌推广和社交媒体运营。',
      join_date: '2023-05-10',
      last_active: '2024-01-08',
      featured_skills: ['SEO', 'SEM', '社交媒体', '内容营销'],
      achievements: ['营销认证', '增长专家'],
      response_time: '6小时内',
      success_rate: 94,
      location: 'Birmingham'
    },
    {
      id: '4',
      name: '陈写作',
      avatar: '/static/avatar4.png',
      user_level: 'normal',
      avg_rating: 4.6,
      completed_tasks: 45,
      total_tasks: 48,
      completion_rate: 93.8,
      expertise_areas: ['文案写作', '内容创作', '翻译'],
      is_verified: false,
      bio: '专业文案写手，擅长各种类型的文案创作和内容策划。',
      join_date: '2023-07-15',
      last_active: '2024-01-07',
      featured_skills: ['文案写作', '内容策划', 'SEO写作', '翻译'],
      achievements: ['写作认证'],
      response_time: '8小时内',
      success_rate: 92,
      location: 'Online'
    },
    {
      id: '5',
      name: '刘翻译',
      avatar: '/static/avatar5.png',
      user_level: 'vip',
      avg_rating: 4.8,
      completed_tasks: 78,
      total_tasks: 80,
      completion_rate: 97.5,
      expertise_areas: ['翻译服务', '语言学习', '跨文化交流'],
      is_verified: true,
      bio: '专业翻译师，精通中英日韩四种语言，拥有丰富的翻译经验。',
      join_date: '2023-02-28',
      last_active: '2024-01-06',
      featured_skills: ['英语', '日语', '韩语', '商务翻译'],
      achievements: ['翻译认证', '语言专家', '文化使者'],
      response_time: '3小时内',
      success_rate: 97,
      location: 'Edinburgh'
    }
  ];

  const categories = [
    { value: 'all', label: t('taskExperts.allCategories') },
    { value: 'programming', label: t('taskExperts.programming') },
    { value: 'design', label: t('taskExperts.design') },
    { value: 'marketing', label: t('taskExperts.marketing') },
    { value: 'writing', label: t('taskExperts.writing') },
    { value: 'translation', label: t('taskExperts.translation') },
    { value: 'food', label: t('taskExperts.food') },
    { value: 'beverage', label: t('taskExperts.beverage') },
    { value: 'cake', label: t('taskExperts.cake') }
  ];

  const sortOptions = [
    { value: 'rating', label: t('taskExperts.sortByRating') },
    { value: 'tasks', label: t('taskExperts.sortByTasks') },
    { value: 'recent', label: t('taskExperts.sortByRecent') }
  ];

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
      } catch (error: any) {
        setUser(null);
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
    // 模拟API调用
    setTimeout(() => {
      setExperts(mockExperts);
      setLoading(false);
    }, 1000);
  }, []);

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
    } catch (error) {
      console.error('标记所有通知为已读失败:', error);
      alert('标记所有通知为已读失败，请重试');
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

  const handleRequestService = (expertId: string) => {
    navigate(`/message?uid=${expertId}`);
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
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
      }}>
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
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
    }}>
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
          color: '#fff'
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
                    onClick={() => handleExpertClick(expert.id)}
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
                    onClick={() => handleRequestService(expert.id)}
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
                      transition: 'all 0.3s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'translateY(-1px)';
                      e.currentTarget.style.boxShadow = '0 4px 15px rgba(102, 126, 234, 0.4)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = 'none';
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
    </div>
  );
};

export default TaskExperts;
