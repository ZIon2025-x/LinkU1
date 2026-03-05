import React, { useEffect, useState, useLayoutEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { message } from 'antd';
import { performanceMonitor } from '../utils/performanceMonitor';
import { fetchTasks, fetchCurrentUser, getNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout, getPublicTaskExperts, getHotForumPosts, getCustomLeaderboards, getPublicStats, getForumNotifications, getForumUnreadNotificationCount, markForumNotificationRead, markAllForumNotificationsRead } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { formatViewCount, obfuscateLocation } from '../utils/formatUtils';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import TaskTitle from '../components/TaskTitle';
import Footer from '../components/Footer';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import SEOHead from '../components/SEOHead';
import HreflangManager from '../components/HreflangManager';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import WebSocketManager from '../utils/WebSocketManager';
import { WS_BASE_URL } from '../config';
import LazyImage from '../components/LazyImage';
import MemberBadge from '../components/MemberBadge';
import { loadTaskTranslationsBatch } from '../utils/taskTranslationBatch';
import { logger } from '../utils/logger';
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
        return false;
  }
}

// Convert number to rounded up approximate value
// 规则：150以下（包括150）显示100+，150以上才显示200+，以此类推
function roundUpApproximate(num: number): string {
  if (num <= 0) return '100+';
  
  // 150以下（包括150）显示100+
  if (num <= 150) return '100+';
  
  // 150以上，向上取整到最近的100
  const rounded = Math.ceil(num / 100) * 100;
  return `${rounded}+`;
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
  type?: string;
  title?: string;
  content: string;
  related_id?: number;
  is_read: number;
  created_at: string;
  // 论坛通知字段
  notification_type?: 'reply_post' | 'reply_reply' | 'like_post' | 'feature_post' | 'pin_post';
  target_type?: 'post' | 'reply';
  target_id?: number;
  from_user?: {
    id: string;
    name: string;
    avatar?: string;
  } | null;
  is_forum?: boolean; // 标识是否为论坛通知
}

const Home: React.FC = () => {
  const location = useLocation();
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  
  // 生成canonical URL - 确保包含语言前缀和尾部斜杠
  // 统一格式：/en/ 和 /zh/（带尾部斜杠）
  let canonicalUrl = 'https://www.link2ur.com/en/'; // 默认指向英文版
  if (location.pathname.startsWith('/en') || location.pathname.startsWith('/zh')) {
    // 确保路径以 / 结尾（对于根路径 /en 或 /zh）
    const path = location.pathname === '/en' || location.pathname === '/zh'
      ? `${location.pathname}/`
      : location.pathname;
    canonicalUrl = `https://www.link2ur.com${path}`;
  }
  
  // 生成页面标题 - 使用翻译文件中的标题
  const pageTitle = t('home.pageTitle') || (language === 'zh' 
    ? 'Link²Ur - 专业任务发布和技能匹配平台 | 首页'
    : 'Link²Ur - Professional Task Publishing and Skill Matching Platform');
  
  // 生成唯一的 meta description - 根据路径和语言创建不同的描述
  const metaDescription = location.pathname === '/' || location.pathname === ''
    ? (language === 'zh' 
      ? '欢迎来到Link²Ur - 专业任务发布与技能匹配平台。连接有技能的人与需要帮助的人，提供家政、跑腿、校园、二手等多类型任务服务。立即开始！'
      : 'Welcome to Link²Ur - Professional task publishing and skill matching platform. Connect skilled people with those who need help. Start now!')
    : (t('home.metaDescription') || (language === 'zh'
      ? 'Link²Ur是专业任务发布与技能匹配平台，连接有技能的人与需要帮助的人。提供家政、跑腿、校园、二手等多类型任务服务。让价值创造更高效，立即开始！'
      : 'Link²Ur - Professional task publishing and skill matching platform, connecting skilled people with those who need help, making value creation more efficient.'));

  // 性能监控
  useEffect(() => {
    performanceMonitor.measurePageLoad('HomePage');
  }, []);

  // Debug related states
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [maxTaskId, setMaxTaskId] = useState<number>(0);
  const [, setTotalTasks] = useState<number>(0);
  
  // 热门达人相关状态
  const [hotExperts, setHotExperts] = useState<any[]>([]);
  const [loadingExperts, setLoadingExperts] = useState(false);
  
  // 热门帖子相关状态
  const [hotPosts, setHotPosts] = useState<any[]>([]);
  const [loadingHotPosts, setLoadingHotPosts] = useState(false);
  
  // 热门榜单相关状态
  const [hotLeaderboards, setHotLeaderboards] = useState<any[]>([]);
  const [loadingHotLeaderboards, setLoadingHotLeaderboards] = useState(false);
  
  // 平台统计数据
  const [totalUsers, setTotalUsers] = useState<number>(0);
  const [loadingStats, setLoadingStats] = useState(false);

  // 移动端检测
  const [isMobile, setIsMobile] = useState(false);

  // User login and avatar logic
  const [user, setUser] = useState<any>(null);
  const [, setShowMenu] = useState(false);
  void setShowMenu;
  
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
  
  // 移动端检测
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  useEffect(() => {
    const loadUserData = async () => {
      try {
        // Directly try to get user info, HttpOnly Cookie will be sent automatically
        const userData = await fetchCurrentUser();
        setUser(userData);
        
        // 检查用户邮箱是否为系统默认的占位邮箱
        if (userData?.email?.endsWith('@link2ur.com')) {
          // 检查是否已经提醒过（避免重复提醒）
          const emailWarningKey = `email_warning_shown_${userData.id}`;
          const lastWarningTime = localStorage.getItem(emailWarningKey);
          const now = Date.now();
          // 每24小时最多提醒一次
          if (!lastWarningTime || (now - parseInt(lastWarningTime)) > 24 * 60 * 60 * 1000) {
            message.warning(t('profile.pleaseUpdateEmail'), 8);
            localStorage.setItem(emailWarningKey, now.toString());
          }
        }
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
  }, [t]);

  // Get notification data - 同时获取任务和论坛通知
  useEffect(() => {
    if (user) {
      // 同时获取任务通知和论坛通知
      Promise.all([
        getNotificationsWithRecentRead(10).catch(() => []),
        getForumNotifications({ page: 1, page_size: 10 }).catch(() => ({ notifications: [] }))
      ]).then(([taskNotifications, forumResponse]) => {
        const forumNotifications = (forumResponse.notifications || []).map((fn: any) => {
          // 生成论坛通知的显示文本
          const userName = fn.from_user?.name || t('forum.user');
          let contentText = '';
          switch (fn.notification_type) {
            case 'reply_post':
              contentText = t('forum.notificationReplyPost', { userName });
              break;
            case 'reply_reply':
              contentText = t('forum.notificationReplyReply', { userName });
              break;
            case 'like_post':
              contentText = t('forum.notificationLikePost', { userName });
              break;
            case 'feature_post':
              contentText = t('forum.notificationFeaturePost');
              break;
            case 'pin_post':
              contentText = t('forum.notificationPinPost');
              break;
            default:
              contentText = t('forum.notificationDefault');
          }
          
          return {
            ...fn,
            id: fn.id,
            content: contentText,
            is_read: fn.is_read ? 1 : 0,
            created_at: fn.created_at,
            is_forum: true,
            notification_type: fn.notification_type,
            target_type: fn.target_type,
            target_id: fn.target_id,
            from_user: fn.from_user
          };
        });
        
        // 合并通知并按时间排序
        const allNotifications = [...taskNotifications, ...forumNotifications].sort((a, b) => {
          return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
        });
        
        setNotifications(allNotifications);
      }).catch(() => {
        // 如果获取失败，尝试单独获取任务通知
        getNotifications(20).then(notifications => {
          setNotifications(notifications);
        }).catch(() => {});
      });
      
      // 合并未读数量
      Promise.all([
        getUnreadNotificationCount().catch(() => 0),
        getForumUnreadNotificationCount().catch(() => ({ unread_count: 0 }))
      ]).then(([taskCount, forumResponse]) => {
        const forumCount = forumResponse.unread_count || 0;
        setUnreadCount(taskCount + forumCount);
      }).catch(() => {});
    }
  }, [user]);

  // 定期更新未读通知数量 - 合并论坛和任务通知
  useEffect(() => {
    if (user) {
      let interval: NodeJS.Timeout | null = null;
      let consecutiveErrors = 0;
      const MAX_CONSECUTIVE_ERRORS = 2; // 连续错误2次后停止
      
      const updateUnreadCount = () => {
        // 只在页面可见时才更新
        if (!document.hidden) {
          Promise.all([
            getUnreadNotificationCount().catch(() => 0),
            getForumUnreadNotificationCount().catch(() => ({ unread_count: 0 }))
          ]).then(([taskCount, forumResponse]) => {
            const forumCount = forumResponse.unread_count || 0;
            setUnreadCount(taskCount + forumCount);
            consecutiveErrors = 0; // 成功时重置错误计数
          }).catch(error => {
            consecutiveErrors++;
            const status = error?.response?.status || error?.status;
            
            // 如果是401错误（未授权），说明token已过期或用户未登录
            if (status === 401) {
              if (interval) {
                clearInterval(interval);
                interval = null;
              }
              return;
            }
            
            // 如果连续错误次数过多，停止定时器
            if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
              if (interval) {
                clearInterval(interval);
                interval = null;
              }
              return;
            }
          });
        }
      };
      
      interval = setInterval(updateUnreadCount, 30000); // 每30秒更新一次
      updateUnreadCount(); // 立即执行一次
      
      return () => {
        if (interval) {
          clearInterval(interval);
        }
      };
    }
    return;
  }, [user]);

  // 当通知面板打开时，定期刷新通知列表 - 合并论坛和任务通知
  useEffect(() => {
    if (showNotifications && user) {
      // 打开时立即刷新一次
      const loadNotificationsList = async () => {
        try {
          const [taskNotifications, forumResponse] = await Promise.all([
            getNotificationsWithRecentRead(10).catch(() => []),
            getForumNotifications({ page: 1, page_size: 10 }).catch(() => ({ notifications: [] }))
          ]);
          
          const forumNotifications = (forumResponse.notifications || []).map((fn: any) => {
            const userName = fn.from_user?.name || t('forum.user');
            let contentText = '';
            switch (fn.notification_type) {
              case 'reply_post':
                contentText = t('forum.notificationReplyPost', { userName });
                break;
              case 'reply_reply':
                contentText = t('forum.notificationReplyReply', { userName });
                break;
              case 'like_post':
                contentText = t('forum.notificationLikePost', { userName });
                break;
              case 'feature_post':
                contentText = t('forum.notificationFeaturePost');
                break;
              case 'pin_post':
                contentText = t('forum.notificationPinPost');
                break;
              default:
                contentText = t('forum.notificationDefault');
            }
            
            return {
              ...fn,
              id: fn.id,
              content: contentText,
              is_read: fn.is_read ? 1 : 0,
              created_at: fn.created_at,
              is_forum: true,
              notification_type: fn.notification_type,
              target_type: fn.target_type,
              target_id: fn.target_id,
              from_user: fn.from_user
            };
          });
          
          // 合并通知并按时间排序
          const allNotifications = [...taskNotifications, ...forumNotifications].sort((a, b) => {
            return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
          });
          
          setNotifications(allNotifications);
        } catch {
          // 忽略错误
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
    return;
  }, [showNotifications, user]);

  // WebSocket实时更新通知（监听notification_created事件）- 合并论坛和任务通知
  useEffect(() => {
    if (!user) return;

    // 初始化WebSocket管理器
    WebSocketManager.initialize(WS_BASE_URL);
    WebSocketManager.connect(user.id);

    // 订阅WebSocket消息
    const unsubscribe = WebSocketManager.subscribe((msg) => {
      // 处理通知创建事件
      if (msg.type === 'notification_created') {
        // 立即刷新未读通知数量（合并论坛和任务）
        Promise.all([
          getUnreadNotificationCount().catch(() => 0),
          getForumUnreadNotificationCount().catch(() => ({ unread_count: 0 }))
        ]).then(([taskCount, forumResponse]) => {
          const forumCount = forumResponse.unread_count || 0;
          setUnreadCount(taskCount + forumCount);
        }).catch(() => {});

        // 如果通知面板已打开，刷新通知列表
        if (showNotifications) {
          Promise.all([
            getNotificationsWithRecentRead(10).catch(() => []),
            getForumNotifications({ page: 1, page_size: 10 }).catch(() => ({ notifications: [] }))
          ]).then(([taskNotifications, forumResponse]) => {
            const forumNotifications = (forumResponse.notifications || []).map((fn: any) => {
              const userName = fn.from_user?.name || t('forum.user');
              let contentText = '';
              switch (fn.notification_type) {
                case 'reply_post':
                  contentText = t('forum.notificationReplyPost', { userName });
                  break;
                case 'reply_reply':
                  contentText = t('forum.notificationReplyReply', { userName });
                  break;
                case 'like_post':
                  contentText = t('forum.notificationLikePost', { userName });
                  break;
                case 'feature_post':
                  contentText = t('forum.notificationFeaturePost');
                  break;
                case 'pin_post':
                  contentText = t('forum.notificationPinPost');
                  break;
                default:
                  contentText = t('forum.notificationDefault');
              }
              
              return {
                ...fn,
                id: fn.id,
                content: contentText,
                is_read: fn.is_read ? 1 : 0,
                created_at: fn.created_at,
                is_forum: true,
                notification_type: fn.notification_type,
                target_type: fn.target_type,
                target_id: fn.target_id,
                from_user: fn.from_user
              };
            });
            
            const allNotifications = [...taskNotifications, ...forumNotifications].sort((a, b) => {
              return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
            });
            
            setNotifications(allNotifications);
          }).catch(() => {});
        }
      }
    });

    return () => {
      unsubscribe();
      // 注意：不断开连接，因为可能其他组件也在使用
    };
  }, [user, showNotifications]);

  // 获取任务数据 - 只显示赏金最高且最新的3个任务
  useEffect(() => {
    setLoading(true);
    fetchTasks({ type: 'all', city: 'all', keyword: '', page: 1, pageSize: 50 })
      .then(data => {
        const allTasks = Array.isArray(data) ? data : (data.tasks || []);
        
        // 计算最大任务ID和任务总数
        if (allTasks.length > 0) {
          const maxId = Math.max(...allTasks.map((task: any) => task.id || 0));
          setMaxTaskId(maxId);
          setTotalTasks(allTasks.length);
        }
        
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
        
        // 批量预加载任务翻译（优化性能）
        if (sortedTasks.length > 0) {
          const taskIds = sortedTasks.map((t: any) => t.id);
          loadTaskTranslationsBatch(taskIds, language, 'title').catch(err => {
            // 静默失败，不影响主流程
            logger.debug('批量预加载任务翻译失败:', err);
          });
        }
      })
      .catch(() => {
                setTasks([]);
      })
      .finally(() => setLoading(false));
  }, [language]);  // 添加language依赖，语言切换时重新加载

  // 获取热门榜单数据 - 显示前3个
  useEffect(() => {
    setLoadingHotLeaderboards(true);
    getCustomLeaderboards({ 
      status: 'active',
      sort: 'hot',
      limit: 3,
      offset: 0
    })
      .then(data => {
        const leaderboardsList = data.items || [];
        setHotLeaderboards(leaderboardsList.slice(0, 3)); // 只取前3个
      })
      .catch(() => { setHotLeaderboards([]); })
      .finally(() => setLoadingHotLeaderboards(false));
  }, []);

  // 获取热门帖子数据 - 显示前3个
  useEffect(() => {
    setLoadingHotPosts(true);
    getHotForumPosts({ limit: 3 })
      .then(data => {
        const postsList = data.posts || [];
        setHotPosts(postsList.slice(0, 3)); // 只取前3个
      })
      .catch(() => { setHotPosts([]); })
      .finally(() => setLoadingHotPosts(false));
  }, []);

  // 获取平台统计数据
  useEffect(() => {
    setLoadingStats(true);
    getPublicStats()
      .then(data => {
        setTotalUsers(data.total_users || 0);
      })
      .catch(() => { setTotalUsers(0); })
      .finally(() => {
        setLoadingStats(false);
      });
  }, []);

  // 获取热门达人数据 - 显示前3个
  useEffect(() => {
    setLoadingExperts(true);
    getPublicTaskExperts()
      .then(data => {
        let expertsList: any[] = [];
        if (Array.isArray(data)) {
          expertsList = data;
        } else if (data.task_experts) {
          expertsList = data.task_experts;
        } else if (data.items) {
          expertsList = data.items;
        }
        
        // 按评分和完成任务数排序，取前3个
        const sortedExperts = expertsList
          .sort((a: any, b: any) => {
            // 首先按评分排序（从高到低）
            const ratingA = parseFloat(a.avg_rating) || 0;
            const ratingB = parseFloat(b.avg_rating) || 0;
            if (ratingA !== ratingB) {
              return ratingB - ratingA;
            }
            // 如果评分相同，按完成任务数排序（从高到低）
            const tasksA = parseInt(a.completed_tasks) || 0;
            const tasksB = parseInt(b.completed_tasks) || 0;
            return tasksB - tasksA;
          })
          .slice(0, 3); // 只取前3个
        
        setHotExperts(sortedExperts);
      })
      .catch(() => { setHotExperts([]); })
      .finally(() => setLoadingExperts(false));
  }, []);

  // 定期刷新任务列表以更新剩余时间和状态
  useEffect(() => {
    const interval = setInterval(() => {
      if (tasks.length > 0) {
        // 重新获取任务数据以更新状态
        fetchTasks({ type: 'all', city: 'all', keyword: '', page: 1, pageSize: 50 })
          .then(data => {
            const allTasks = Array.isArray(data) ? data : (data.tasks || []);
            
            // 更新最大任务ID和任务总数
            if (allTasks.length > 0) {
              const maxId = Math.max(...allTasks.map((task: any) => task.id || 0));
              setMaxTaskId(maxId);
              setTotalTasks(allTasks.length);
            }
            
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
          .catch(() => {});
      }
    }, 60000); // 每分钟更新一次
    return () => clearInterval(interval);
  }, [tasks.length]);

  // 处理通知点击 - 只标记为已读，不跳转（预留，NotificationPanel 使用 onMarkAsRead）
  const _handleNotificationClick = async (notification: Notification) => {
    await markNotificationRead(notification.id);
    setNotifications(prev => prev.map(n => n.id === notification.id ? { ...n, is_read: 1 } : n));
    setUnreadCount(prev => Math.max(0, prev - 1));
  };
  void _handleNotificationClick;

  // 处理单个通知标记为已读 - 支持论坛和任务通知
  const handleMarkAsRead = async (id: number) => {
    try {
      // 查找通知，判断是论坛通知还是任务通知
      // 使用更精确的匹配，避免 ID 冲突
      const notification = notifications.find(n => {
        // 如果通知有 is_forum 标识，使用它来区分
        if (n.is_forum !== undefined) {
          return n.id === id && n.is_forum === true;
        }
        // 否则是任务通知
        return n.id === id && !n.is_forum;
      });
      
      // 如果找不到，尝试简单匹配（向后兼容）
      const fallbackNotification = notification || notifications.find(n => n.id === id);
      const isForumNotification = fallbackNotification?.is_forum;
      
      if (isForumNotification) {
        await markForumNotificationRead(id);
      } else {
        await markNotificationRead(id);
      }
      
      // 更新本地状态，标记为已读 - 使用更精确的匹配
      setNotifications(prev => 
        prev.map(n => {
          if (n.is_forum !== undefined) {
            // 有 is_forum 标识时，需要同时匹配 ID 和类型
            if (n.is_forum && isForumNotification && n.id === id) {
              return { ...n, is_read: 1 };
            }
            if (!n.is_forum && !isForumNotification && n.id === id) {
              return { ...n, is_read: 1 };
            }
          } else {
            // 向后兼容：只匹配 ID
            if (n.id === id) {
              return { ...n, is_read: 1 };
            }
          }
          return n;
        })
      );
      
      // 更新未读数量
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch (error) {
            message.error('标记通知为已读失败，请重试');
    }
  };

  // 标记所有通知为已读 - 同时标记论坛和任务通知
  const handleMarkAllRead = async () => {
    try {
      await Promise.all([
        markAllNotificationsRead().catch(() => {}),
        markAllForumNotificationsRead().catch(() => {})
      ]);
      
      setUnreadCount(0);
      // 更新通知列表，标记所有为已读
      setNotifications(prev => prev.map(n => ({ ...n, is_read: 1 })));
    } catch (error) {
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
    // 使用与SEOHead相同的描述逻辑
    const description = location.pathname === '/' || location.pathname === ''
      ? (language === 'zh' 
        ? '欢迎来到Link²Ur - 专业任务发布与技能匹配平台。连接有技能的人与需要帮助的人，提供家政、跑腿、校园、二手等多类型任务服务。立即开始！'
        : 'Welcome to Link²Ur - Professional task publishing and skill matching platform. Connect skilled people with those who need help. Start now!')
      : (t('home.metaDescription') || (language === 'zh'
        ? 'Link²Ur是专业任务发布与技能匹配平台，连接有技能的人与需要帮助的人。提供家政、跑腿、校园、二手等多类型任务服务。让价值创造更高效，立即开始！'
        : 'Link²Ur - Professional task publishing and skill matching platform, connecting skilled people with those who need help, making value creation more efficient.'));
    
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
        title={pageTitle}
        description={metaDescription}
        canonicalUrl={canonicalUrl}
        ogTitle={pageTitle}
        ogDescription={metaDescription}
        ogImage="/static/favicon.png"
        ogUrl={canonicalUrl}
      />
      <HreflangManager type="page" path="/" />
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
            <a
              href="https://app.link2ur.com/tasks"
              target="_blank"
              rel="noopener noreferrer"
              className={styles.heroButton}
            >
              ✨ {t('navigation.tasks')}
            </a>

            <a
              href="https://app.link2ur.com/publish"
              target="_blank"
              rel="noopener noreferrer"
              className={styles.heroButton}
            >
              🚀 {t('navigation.publish')}
            </a>

            <a
              href="https://app.link2ur.com/task-experts"
              target="_blank"
              rel="noopener noreferrer"
              className={styles.heroButton}
            >
              👑 {t('footer.taskExperts')}
            </a>
          </div>
          
          {/* 统计数据 */}
          <div className={styles.heroStats}>
            <div className={styles.heroStatItem}>
              <div className={styles.heroStatValue}>
                {loadingStats ? '...' : roundUpApproximate(totalUsers)}
              </div>
              <div className={styles.heroStatLabel}>{t('about.registeredUsers')}</div>
            </div>
            <div className={styles.heroStatItem}>
              <div className={styles.heroStatValue}>{t('home.coverageArea')}</div>
              <div className={styles.heroStatLabel}>{t('profile.tasksCompleted')}</div>
            </div>
            <div className={styles.heroStatItem}>
              <div className={styles.heroStatValue}>
                {maxTaskId > 0 ? roundUpApproximate(maxTaskId) : '0'}
              </div>
              <div className={styles.heroStatLabel}>{t('home.totalTasksPublished')}</div>
            </div>
          </div>
        </div>
      </section>
      
      {/* 热门榜单区域 */}
      <section className={styles.featuresSection} style={{ background: '#fff' }}>
        <div className={styles.featuresContainer}>
          <div style={{ textAlign: 'center', marginBottom: '16px', position: 'relative' }}>
            <h2 className={styles.featuresTitle} style={{ color: '#1f2937', margin: 0 }}>
              🏆 {t('forum.hotLeaderboards')}
            </h2>
            <button
              onClick={() => navigate(`/${language || 'zh'}/forum/leaderboard`)}
              style={{
                position: isMobile ? 'relative' : 'absolute',
                right: isMobile ? 'auto' : 0,
                top: isMobile ? 'auto' : '50%',
                transform: isMobile ? 'none' : 'translateY(-50%)',
                marginTop: isMobile ? '12px' : 0,
                padding: isMobile ? '8px 16px' : '8px 20px',
                background: '#10b981',
                border: 'none',
                borderRadius: '8px',
                color: 'white',
                fontSize: isMobile ? '13px' : '14px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                display: isMobile ? 'inline-block' : 'block'
              }}
              onMouseEnter={(e) => {
                if (!isMobile) {
                  e.currentTarget.style.background = '#059669';
                  e.currentTarget.style.transform = 'translateY(-50%) translateY(-2px)';
                }
              }}
              onMouseLeave={(e) => {
                if (!isMobile) {
                  e.currentTarget.style.background = '#10b981';
                  e.currentTarget.style.transform = 'translateY(-50%)';
                }
              }}
            >
              {t('common.more') || '更多'} →
            </button>
          </div>
          <p className={styles.featuresSubtitle} style={{ color: '#6b7280' }}>
            {t('forum.hotLeaderboardsSubtitle')}
          </p>
          
          {loadingHotLeaderboards ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#6b7280' }}>
              <div>🔄 {t('common.loading') || '加载中...'}</div>
            </div>
          ) : hotLeaderboards.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#6b7280' }}>
              <div>{t('forum.noHotLeaderboards')}</div>
            </div>
          ) : (
            <div className={styles.featuresGrid} style={{ 
              gridTemplateColumns: isMobile ? '1fr' : 'repeat(3, 1fr)',
              gap: isMobile ? '20px' : '24px'
            }}>
              {hotLeaderboards.map((leaderboard: any) => {
                return (
                  <div
                    key={leaderboard.id}
                    style={{
                      background: '#ffffff',
                      borderRadius: isMobile ? '16px' : '24px',
                      padding: isMobile ? '20px' : '28px',
                      border: '1px solid #e2e8f0',
                      boxShadow: '0 8px 32px rgba(0, 0, 0, 0.08)',
                      transition: 'all 0.3s ease',
                      cursor: 'pointer',
                      position: 'relative',
                      overflow: 'hidden',
                      display: 'flex',
                      flexDirection: 'column'
                    }}
                    onMouseEnter={(e) => {
                      if (!isMobile) {
                        e.currentTarget.style.transform = 'translateY(-5px)';
                        e.currentTarget.style.boxShadow = '0 12px 40px rgba(0, 0, 0, 0.12)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!isMobile) {
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.08)';
                      }
                    }}
                    onClick={() => navigate(`/${language || 'zh'}/leaderboard/custom/${leaderboard.id}`)}
                  >
                    {/* 封面图片 */}
                    {leaderboard.cover_image && (
                      <div style={{
                        width: '100%',
                        height: isMobile ? '120px' : '160px',
                        marginBottom: '16px',
                        borderRadius: '12px',
                        overflow: 'hidden',
                        background: '#f1f5f9'
                      }}>
                        <LazyImage
                          src={leaderboard.cover_image}
                          alt={leaderboard.name}
                          style={{
                            width: '100%',
                            height: '100%',
                            objectFit: 'cover'
                          }}
                        />
                      </div>
                    )}
                    
                    {/* 标题 */}
                    <h3 style={{
                      fontSize: isMobile ? '16px' : '18px',
                      fontWeight: '700',
                      color: '#1a202c',
                      marginBottom: isMobile ? '12px' : '16px',
                      margin: 0,
                      display: '-webkit-box',
                      WebkitLineClamp: 2,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden',
                      lineHeight: '1.4'
                    }}>
                      🏆 {leaderboard.name}
                    </h3>
                    
                    {/* 描述 */}
                    {leaderboard.description && (
                      <p style={{
                        color: '#4a5568',
                        fontSize: isMobile ? '13px' : '14px',
                        lineHeight: '1.6',
                        marginBottom: isMobile ? '12px' : '16px',
                        margin: 0,
                        display: '-webkit-box',
                        WebkitLineClamp: 3,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden',
                        flex: 1
                      }}>
                        {leaderboard.description}
                      </p>
                    )}
                    
                    {/* 标签和统计信息 */}
                    <div style={{
                      display: 'flex',
                      flexWrap: 'wrap',
                      gap: '8px',
                      marginBottom: '12px'
                    }}>
                      {leaderboard.location && (
                        <span style={{
                          padding: '4px 10px',
                          background: '#f1f5f9',
                          borderRadius: '8px',
                          fontSize: '12px',
                          color: '#475569',
                          border: '1px solid #e2e8f0',
                          display: 'inline-block'
                        }}>
                          📍 {leaderboard.location}
                        </span>
                      )}
                    </div>
                    
                    {/* 统计信息 */}
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: isMobile ? '12px' : '16px',
                      paddingTop: '12px',
                      borderTop: '1px solid #e2e8f0',
                      fontSize: '12px',
                      color: '#64748b'
                    }}>
                      <span>📦 {leaderboard.item_count || 0} {t('forum.itemsCount')}</span>
                      <span>👍 {leaderboard.vote_count || 0} {t('forum.votesCount')}</span>
                      <span>👁️ {formatViewCount(leaderboard.view_count || 0)} {t('forum.viewsCount')}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>
      
      {/* 热门帖子区域 */}
      <section className={styles.featuresSection} style={{ background: '#f8fafc' }}>
        <div className={styles.featuresContainer}>
          <div style={{ textAlign: 'center', marginBottom: '16px', position: 'relative' }}>
            <h2 className={styles.featuresTitle} style={{ color: '#1f2937', margin: 0 }}>
              {t('forum.hotPosts') || '热门帖子'}
            </h2>
            <button
              onClick={() => navigate('/forum')}
              style={{
                position: isMobile ? 'relative' : 'absolute',
                right: isMobile ? 'auto' : 0,
                top: isMobile ? 'auto' : '50%',
                transform: isMobile ? 'none' : 'translateY(-50%)',
                marginTop: isMobile ? '12px' : 0,
                padding: isMobile ? '8px 16px' : '8px 20px',
                background: '#10b981',
                border: 'none',
                borderRadius: '8px',
                color: 'white',
                fontSize: isMobile ? '13px' : '14px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                display: isMobile ? 'inline-block' : 'block'
              }}
              onMouseEnter={(e) => {
                if (!isMobile) {
                  e.currentTarget.style.background = '#059669';
                  e.currentTarget.style.transform = 'translateY(-50%) translateY(-2px)';
                }
              }}
              onMouseLeave={(e) => {
                if (!isMobile) {
                  e.currentTarget.style.background = '#10b981';
                  e.currentTarget.style.transform = 'translateY(-50%)';
                }
              }}
            >
              {t('common.more') || '更多'} →
            </button>
          </div>
          <p className={styles.featuresSubtitle} style={{ color: '#6b7280' }}>
            {t('forum.hotPostsSubtitle') || '发现社区最受欢迎的讨论'}
          </p>
          
          {loadingHotPosts ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#6b7280' }}>
              <div>🔄 {t('common.loading') || '加载中...'}</div>
            </div>
          ) : hotPosts.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#6b7280' }}>
              <div>{t('forum.noPosts') || '暂无热门帖子'}</div>
            </div>
          ) : (
            <div className={styles.featuresGrid} style={{ 
              gridTemplateColumns: isMobile ? '1fr' : 'repeat(3, 1fr)',
              gap: isMobile ? '20px' : '24px'
            }}>
              {hotPosts.map((post: any) => {
                const formatDate = (dateString: string) => {
                  try {
                    const date = new Date(dateString);
                    const now = new Date();
                    const diff = now.getTime() - date.getTime();
                    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
                    const hours = Math.floor(diff / (1000 * 60 * 60));
                    const minutes = Math.floor(diff / (1000 * 60));
                    
                    if (days > 0) {
                      return t('common.daysAgo', { count: days });
                    } else if (hours > 0) {
                      return t('common.hoursAgo', { count: hours });
                    } else if (minutes > 0) {
                      return t('common.minutesAgo', { count: minutes });
                    } else {
                      return t('common.justNow');
                    }
                  } catch {
                    return dateString;
                  }
                };
                
                return (
                  <div
                    key={post.id}
                    style={{
                      background: '#ffffff',
                      borderRadius: isMobile ? '16px' : '24px',
                      padding: isMobile ? '20px' : '28px',
                      border: '1px solid #e2e8f0',
                      boxShadow: '0 8px 32px rgba(0, 0, 0, 0.08)',
                      transition: 'all 0.3s ease',
                      cursor: 'pointer',
                      position: 'relative',
                      overflow: 'hidden',
                      display: 'flex',
                      flexDirection: 'column'
                    }}
                    onMouseEnter={(e) => {
                      if (!isMobile) {
                        e.currentTarget.style.transform = 'translateY(-5px)';
                        e.currentTarget.style.boxShadow = '0 12px 40px rgba(0, 0, 0, 0.12)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!isMobile) {
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.08)';
                      }
                    }}
                    onClick={() => navigate(`/${language}/forum/post/${post.id}`)}
                  >
                    {/* 板块标签 */}
                    {post.category && (
                      <div style={{
                        marginBottom: '12px'
                      }}>
                        <span style={{
                          padding: '4px 10px',
                          background: '#f1f5f9',
                          borderRadius: '8px',
                          fontSize: '12px',
                          color: '#475569',
                          border: '1px solid #e2e8f0',
                          display: 'inline-block'
                        }}>
                          📌 {post.category.name}
                        </span>
                      </div>
                    )}
                    
                    {/* 标题 */}
                    <h3 style={{
                      fontSize: isMobile ? '16px' : '18px',
                      fontWeight: '700',
                      color: '#1a202c',
                      marginBottom: isMobile ? '12px' : '16px',
                      margin: 0,
                      display: '-webkit-box',
                      WebkitLineClamp: 2,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden',
                      lineHeight: '1.4'
                    }}>
                      {post.title}
                    </h3>
                    
                    {/* 内容预览 */}
                    {post.content_preview && (
                      <p style={{
                        color: '#4a5568',
                        fontSize: isMobile ? '13px' : '14px',
                        lineHeight: '1.6',
                        marginBottom: isMobile ? '12px' : '16px',
                        margin: 0,
                        display: '-webkit-box',
                        WebkitLineClamp: 3,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden',
                        flex: 1
                      }}>
                        {post.content_preview}
                      </p>
                    )}
                    
                    {/* 作者信息 */}
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      marginBottom: '12px'
                    }}>
                      {post.author && (
                        <>
                          <LazyImage
                            src={post.author.avatar || 'https://via.placeholder.com/24'}
                            alt={post.author.name}
                            style={{
                              width: '24px',
                              height: '24px',
                              borderRadius: '50%',
                              objectFit: 'cover',
                              border: '1px solid #e2e8f0'
                            }}
                          />
                          <span style={{
                            fontSize: '13px',
                            color: '#64748b',
                            fontWeight: '500'
                          }}>
                            {post.author.name}
                          </span>
                          {post.author.is_admin && (
                            <span style={{
                              fontSize: '11px',
                              color: '#1890ff',
                              backgroundColor: '#e6f7ff',
                              padding: '2px 6px',
                              borderRadius: '4px',
                              marginLeft: '6px',
                              border: '1px solid #91d5ff'
                            }}>
                              {t('forum.official')}
                            </span>
                          )}
                        </>
                      )}
                    </div>
                    
                    {/* 统计信息 */}
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: isMobile ? '12px' : '16px',
                      paddingTop: '12px',
                      borderTop: '1px solid #e2e8f0',
                      fontSize: '12px',
                      color: '#64748b'
                    }}>
                      <span>👁️ {formatViewCount(post.view_count || 0)}</span>
                      <span>💬 {post.reply_count || 0}</span>
                      <span>❤️ {post.like_count || 0}</span>
                      {post.created_at && (
                        <span style={{ marginLeft: 'auto' }}>
                          {formatDate(post.created_at)}
                        </span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>
      
      {/* 最新任务区块 - 重新设计 */}
      <main className={styles.tasksSection}>
        <div className={styles.tasksHeader}>
          <div style={{ textAlign: 'center', marginBottom: '16px', position: 'relative' }}>
            <h2 className={styles.tasksTitle} style={{ margin: 0 }}>
              {t('home.recentTasks')}
            </h2>
            <button
              onClick={() => navigate('/tasks')}
              style={{
                position: 'absolute',
                right: 0,
                top: '50%',
                transform: 'translateY(-50%)',
                padding: '8px 20px',
                background: '#10b981',
                border: 'none',
                borderRadius: '8px',
                color: 'white',
                fontSize: '14px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = '#059669';
                e.currentTarget.style.transform = 'translateY(-50%) translateY(-2px)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = '#10b981';
                e.currentTarget.style.transform = 'translateY(-50%)';
              }}
            >
              {t('common.more') || '更多'} →
            </button>
          </div>
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
              
              // 任务等级标签样式（预留，当前用 getTaskLevelText）
              const _getTaskLevelStyle = (level: string) => {
                switch (level) {
                  case 'vip': return { background: 'linear-gradient(135deg, #FFD700, #FFA500)', color: '#8B4513', border: '2px solid #FFD700', boxShadow: '0 2px 8px rgba(255, 215, 0, 0.3)' };
                  case 'super': return { background: 'linear-gradient(135deg, #FF6B6B, #FF4757)', color: '#fff', border: '2px solid #FF4757', boxShadow: '0 2px 8px rgba(255, 107, 107, 0.3)' };
                  default: return { background: '#f8f9fa', color: '#6c757d', border: '1px solid #dee2e6' };
                }
              };
              void _getTaskLevelStyle;

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
                  {/* 会员发布角标 */}
                  {task.poster_user_level && (task.poster_user_level === 'vip' || task.poster_user_level === 'super') && (
                    <div className={styles.taskLevelBadge} style={{ background: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)', fontSize: '11px', padding: '4px 8px' }}>
                      {t('home.memberPublished') || '会员发布'}
                    </div>
                  )}
                  
                  <div>
                    <div className={styles.taskTitle}>
                      <TaskTitle
                        title={task.title}
                        language={language}
                        taskId={task.id}
                        task={task}
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
                        {t(`taskTypes.${task.task_type}`, task.task_type)}
                      </span>
                      <span className={`${styles.taskLocationBadge} ${
                        task.location?.toLowerCase() === 'online' ? styles.taskLocationOnline : styles.taskLocationOffline
                      }`}>
                        {task.location?.toLowerCase() === 'online' ? '🌐' : '📍'} {obfuscateLocation(task.location)}
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
                        £{((task.agreed_reward ?? task.base_reward ?? task.reward) || 0).toFixed(2)}
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
      
      {/* 热门达人区域 */}
      <section className={styles.featuresSection} style={{ background: '#fff' }}>
        <div className={styles.featuresContainer}>
          <div style={{ textAlign: 'center', marginBottom: '16px', position: 'relative' }}>
            <h2 className={styles.featuresTitle} style={{ color: '#1f2937', margin: 0 }}>
              {t('taskExperts.title') || '热门达人'}
            </h2>
            <button
              onClick={() => navigate('/task-experts')}
              style={{
                position: isMobile ? 'relative' : 'absolute',
                right: isMobile ? 'auto' : 0,
                top: isMobile ? 'auto' : '50%',
                transform: isMobile ? 'none' : 'translateY(-50%)',
                marginTop: isMobile ? '12px' : 0,
                padding: isMobile ? '8px 16px' : '8px 20px',
                background: '#10b981',
                border: 'none',
                borderRadius: '8px',
                color: 'white',
                fontSize: isMobile ? '13px' : '14px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                display: isMobile ? 'inline-block' : 'block'
              }}
              onMouseEnter={(e) => {
                if (!isMobile) {
                  e.currentTarget.style.background = '#059669';
                  e.currentTarget.style.transform = 'translateY(-50%) translateY(-2px)';
                }
              }}
              onMouseLeave={(e) => {
                if (!isMobile) {
                  e.currentTarget.style.background = '#10b981';
                  e.currentTarget.style.transform = 'translateY(-50%)';
                }
              }}
            >
              {t('common.more') || '更多'} →
            </button>
          </div>
          <p className={styles.featuresSubtitle} style={{ color: '#6b7280' }}>
            {t('taskExperts.subtitle') || '发现平台上的优秀任务执行者'}
          </p>
          
          {loadingExperts ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#6b7280' }}>
              <div>🔄 {t('taskExperts.loading') || '加载中...'}</div>
            </div>
          ) : hotExperts.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: '#6b7280' }}>
              <div>{t('taskExperts.noExpertsFound') || '暂无热门达人'}</div>
            </div>
          ) : (
            <div className={styles.featuresGrid} style={{ 
              gridTemplateColumns: isMobile ? '1fr' : 'repeat(3, 1fr)',
              gap: isMobile ? '20px' : '24px'
            }}>
              {hotExperts.map((expert: any) => {
                // 将下划线格式转换为驼峰格式用于翻译键
                const categoryKey = expert.category ? expert.category.replace(/_([a-z])/g, (_: string, letter: string) => letter.toUpperCase()) : '';
                const categoryLabel = expert.category ? (t(`taskExperts.${categoryKey}`) || expert.category) : '';
                
                return (
                  <div
                    key={expert.id}
                    style={{
                      background: '#ffffff',
                      borderRadius: isMobile ? '16px' : '24px',
                      padding: isMobile ? '20px' : '28px',
                      border: '1px solid #e2e8f0',
                      boxShadow: '0 8px 32px rgba(0, 0, 0, 0.08)',
                      transition: 'all 0.3s ease',
                      cursor: 'pointer',
                      position: 'relative',
                      overflow: 'hidden'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = '#ffffff';
                      e.currentTarget.style.transform = 'translateY(-5px)';
                      e.currentTarget.style.boxShadow = '0 12px 40px rgba(0, 0, 0, 0.12)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = '#ffffff';
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.08)';
                    }}
                    onClick={() => navigate(`/task-experts`)}
                  >
                    {/* 地点 - 右上角 */}
                    {expert.location && expert.location !== 'Online' && (
                      <div style={{
                        position: 'absolute',
                        top: isMobile ? '12px' : '20px',
                        right: isMobile ? '12px' : '20px',
                        padding: isMobile ? '3px 8px' : '4px 10px',
                        background: '#f1f5f9',
                        borderRadius: '8px',
                        fontSize: isMobile ? '11px' : '12px',
                        color: '#475569',
                        border: '1px solid #e2e8f0',
                        fontWeight: 500,
                        zIndex: 10
                      }}>
                        📍 {expert.location}
                      </div>
                    )}

                    {/* 专家头部信息 */}
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: isMobile ? '12px' : '18px',
                      marginBottom: isMobile ? '16px' : '20px'
                    }}>
                      <div style={{ position: 'relative' }}>
                        <LazyImage
                          src={expert.avatar || 'https://via.placeholder.com/72'}
                          alt={expert.name}
                          width={isMobile ? 56 : 72}
                          height={isMobile ? 56 : 72}
                          style={{
                            borderRadius: '50%',
                            objectFit: 'cover',
                            border: isMobile ? '2px solid #e2e8f0' : '3px solid #e2e8f0',
                            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.1)'
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

                      <div style={{ flex: 1, minWidth: 0 }}>
                        <h3 style={{
                          fontSize: isMobile ? '16px' : '20px',
                          fontWeight: '700',
                          color: '#1a202c',
                          marginBottom: isMobile ? '4px' : '6px',
                          margin: 0,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap'
                        }}>
                          {expert.name}
                        </h3>
                        <MemberBadge
                          level={expert.user_level}
                          variant="compact"
                          labelVip="taskExperts.vipExpert"
                          labelSuper="taskExperts.superExpert"
                        />
                      </div>
                    </div>

                    {/* 简介 */}
                    {expert.bio && (
                      <p style={{
                        color: '#4a5568',
                        fontSize: isMobile ? '13px' : '14px',
                        lineHeight: '1.6',
                        marginBottom: isMobile ? '12px' : '16px',
                        margin: 0,
                        display: '-webkit-box',
                        WebkitLineClamp: isMobile ? 2 : 3,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden'
                      }}>
                        {expert.bio}
                      </p>
                    )}

                    {/* 类别 */}
                    {categoryLabel && (
                      <div style={{ marginBottom: '16px' }}>
                        <span style={{
                          padding: '4px 10px',
                          background: '#f1f5f9',
                          borderRadius: '8px',
                          fontSize: '12px',
                          color: '#475569',
                          border: '1px solid #e2e8f0',
                          display: 'inline-block'
                        }}>
                          💼 {categoryLabel}
                        </span>
                      </div>
                    )}

                    {/* 评分和统计 */}
                    <div style={{
                      display: 'grid',
                      gridTemplateColumns: 'repeat(3, 1fr)',
                      gap: isMobile ? '8px' : '12px',
                      marginBottom: isMobile ? '16px' : '20px'
                    }}>
                      <div style={{
                        padding: isMobile ? '10px 8px' : '12px',
                        background: '#f8fafc',
                        borderRadius: isMobile ? '10px' : '12px',
                        textAlign: 'center',
                        border: '1px solid #e2e8f0'
                      }}>
                        <div style={{
                          fontSize: isMobile ? '16px' : '18px',
                          fontWeight: '700',
                          color: '#1a202c',
                          marginBottom: '4px'
                        }}>
                          {expert.avg_rating ? expert.avg_rating.toFixed(1) : '0.0'}
                        </div>
                        <div style={{
                          fontSize: isMobile ? '10px' : '11px',
                          color: '#64748b'
                        }}>
                          评分
                        </div>
                      </div>
                      <div style={{
                        padding: isMobile ? '10px 8px' : '12px',
                        background: '#f8fafc',
                        borderRadius: isMobile ? '10px' : '12px',
                        textAlign: 'center',
                        border: '1px solid #e2e8f0'
                      }}>
                        <div style={{
                          fontSize: isMobile ? '16px' : '18px',
                          fontWeight: '700',
                          color: '#1a202c',
                          marginBottom: '4px'
                        }}>
                          {expert.completed_tasks || 0}
                        </div>
                        <div style={{
                          fontSize: isMobile ? '10px' : '11px',
                          color: '#64748b'
                        }}>
                          任务
                        </div>
                      </div>
                      <div style={{
                        padding: isMobile ? '10px 8px' : '12px',
                        background: '#f8fafc',
                        borderRadius: isMobile ? '10px' : '12px',
                        textAlign: 'center',
                        border: '1px solid #e2e8f0'
                      }}>
                        <div style={{
                          fontSize: isMobile ? '16px' : '18px',
                          fontWeight: '700',
                          color: '#1a202c',
                          marginBottom: '4px'
                        }}>
                          {expert.completion_rate || 0}%
                        </div>
                        <div style={{
                          fontSize: isMobile ? '10px' : '11px',
                          color: '#64748b'
                        }}>
                          完成率
                        </div>
                      </div>
                    </div>

                    {/* 查看资料按钮 */}
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        navigate(`/task-experts`);
                      }}
                      style={{
                        width: '100%',
                        padding: isMobile ? '12px' : '14px',
                        background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                        border: 'none',
                        borderRadius: isMobile ? '10px' : '12px',
                        color: 'white',
                        fontSize: isMobile ? '14px' : '15px',
                        fontWeight: '600',
                        cursor: 'pointer',
                        transition: 'all 0.3s ease',
                        boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
                      }}
                      onMouseEnter={(e) => {
                        if (!isMobile) {
                          e.currentTarget.style.background = 'linear-gradient(135deg, #2563eb, #7c3aed)';
                          e.currentTarget.style.transform = 'scale(1.02)';
                          e.currentTarget.style.boxShadow = '0 6px 16px rgba(59, 130, 246, 0.4)';
                        }
                      }}
                      onMouseLeave={(e) => {
                        if (!isMobile) {
                          e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #8b5cf6)';
                          e.currentTarget.style.transform = 'scale(1)';
                          e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                        }
                      }}
                    >
                      {t('taskExperts.viewProfile') || '查看资料'}
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>
      {/* 底部信息区块 */}
      <Footer />
      
      {/* 跳蚤市场悬浮入口 */}
      <div
        onClick={() => navigate('/flea-market')}
        className={styles.fleaMarketFloatButton}
        title={t('fleaMarket.cardTitle') || '跳蚤市场'}
      >
        <LazyImage 
          src="/static/Flea.png"
          alt="跳蚤市场"
          className={styles.fleaMarketIcon}
        />
      </div>
      
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