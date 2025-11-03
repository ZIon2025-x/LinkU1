import React, { useEffect, useState, useCallback } from 'react';
import { useLocation, useNavigate as useRouterNavigate } from 'react-router-dom';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout, getUserApplications } from '../api';
import { API_BASE_URL } from '../config';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import SEOHead from '../components/SEOHead';
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

// 剩余时间计算函数 - 使用英国时间
function getRemainTime(deadline: string, t: (key: string) => string) {
  try {
    // 解析UTC时间并转换为英国时间
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
    console.error('剩余时间计算错误:', error);
    return t('home.taskExpired');
  }
}

// 检查是否即将过期 - 使用英国时间
function isExpiringSoon(deadline: string) {
  try {
    // 解析UTC时间并转换为英国时间
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
    const oneDayLater = nowUK.add(1, 'day');
    
    return nowUK.isBefore(endUK) && endUK.isBefore(oneDayLater);
  } catch (error) {
    console.error('过期检查错误:', error);
    return false;
  }
}

// 检查是否已过期 - 使用英国时间
function isExpired(deadline: string) {
  try {
    // 解析UTC时间并转换为英国时间
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
    console.error('过期检查错误:', error);
    return true; // 如果解析失败，假设已过期
  }
}

export const TASK_TYPES = [
  "Housekeeping", "Campus Life", "Second-hand & Rental", "Errand Running", "Skill Service", "Social Help", "Transportation", "Pet Care", "Life Convenience", "Other"
];

export const CITIES = [
  "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

const Tasks: React.FC = () => {
  const { t, language, setLanguage } = useLanguage();
  const location = useLocation();
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [type, setType] = useState('all');
  const [city, setCity] = useState('all');
  const [cityInitialized, setCityInitialized] = useState(false); // 标记城市是否已初始化
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
  const [taskLevel, setTaskLevel] = useState(t('tasks.levels.all'));
  const [isMobile, setIsMobile] = useState(false);
  const [userLocation, setUserLocation] = useState('London, UK'); // 用户当前位置
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);
  const [showLanguageDropdown, setShowLanguageDropdown] = useState(false);

  // 生成canonical URL - 不带查询参数，统一URL格式
  // 无论是否有查询参数（?type=xxx&location=xxx），canonical URL都不包含这些参数
  const canonicalUrl = location.pathname.startsWith('/en') || location.pathname.startsWith('/zh')
    ? `https://www.link2ur.com${location.pathname}`
    : 'https://www.link2ur.com/en/tasks';

  // 立即更新meta标签以确保微信分享能识别logo（必须在组件加载时立即执行）
  // 使用useLayoutEffect确保在DOM渲染前同步执行，优先级高于useEffect
  React.useLayoutEffect(() => {
    const updateMetaTag = (name: string, content: string, property?: boolean) => {
      const selector = property ? `meta[property="${name}"]` : `meta[name="${name}"]`;
      // 先移除所有同名的标签，确保没有重复
      const allTags = document.querySelectorAll(selector);
      allTags.forEach(tag => tag.remove());
      
      // 创建新标签
      const metaTag = document.createElement('meta');
      if (property) {
        metaTag.setAttribute('property', name);
      } else {
        metaTag.setAttribute('name', name);
      }
      metaTag.content = content;
      document.head.appendChild(metaTag);
    };

    // 强制移除所有旧的og:image相关标签（包括index.html中的默认标签）
    const allOgImages = document.querySelectorAll('meta[property="og:image"], meta[property="og:image:width"], meta[property="og:image:height"], meta[property="og:image:type"]');
    allOgImages.forEach(tag => tag.remove());

    // 设置logo图片（完整URL，添加版本号避免缓存）
    const shareImageUrl = `${window.location.origin}/static/logo.png?v=3`;
    
    // 创建新的og:image标签（直接插入到head最前面）
    const ogImage = document.createElement('meta');
    ogImage.setAttribute('property', 'og:image');
    ogImage.content = shareImageUrl;
    document.head.insertBefore(ogImage, document.head.firstChild);
    
    const ogImageWidth = document.createElement('meta');
    ogImageWidth.setAttribute('property', 'og:image:width');
    ogImageWidth.content = '1200';
    document.head.insertBefore(ogImageWidth, document.head.firstChild);
    
    const ogImageHeight = document.createElement('meta');
    ogImageHeight.setAttribute('property', 'og:image:height');
    ogImageHeight.content = '630';
    document.head.insertBefore(ogImageHeight, document.head.firstChild);
    
    const ogImageType = document.createElement('meta');
    ogImageType.setAttribute('property', 'og:image:type');
    ogImageType.content = 'image/png';
    document.head.insertBefore(ogImageType, document.head.firstChild);
    
    // 设置微信分享标签
    const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
    allWeixinImages.forEach(tag => tag.remove());
    
    const weixinImage = document.createElement('meta');
    weixinImage.setAttribute('name', 'weixin:image');
    weixinImage.content = shareImageUrl;
    document.head.insertBefore(weixinImage, document.head.firstChild);
    
    // 设置微信分享标题和描述
    const ogTitle = t('tasks.pageTitle');
    const ogDescription = t('tasks.seoDescription');
    
    if (ogTitle) {
      const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
      allWeixinTitles.forEach(tag => tag.remove());
      const allOgTitles = document.querySelectorAll('meta[property="og:title"]');
      allOgTitles.forEach(tag => tag.remove());
      
      const weixinTitle = document.createElement('meta');
      weixinTitle.setAttribute('name', 'weixin:title');
      weixinTitle.content = ogTitle;
      document.head.insertBefore(weixinTitle, document.head.firstChild);
      
      const ogTitleTag = document.createElement('meta');
      ogTitleTag.setAttribute('property', 'og:title');
      ogTitleTag.content = ogTitle;
      document.head.insertBefore(ogTitleTag, document.head.firstChild);
    }
    
    if (ogDescription) {
      const allWeixinDescriptions = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDescriptions.forEach(tag => tag.remove());
      const allOgDescriptions = document.querySelectorAll('meta[property="og:description"]');
      allOgDescriptions.forEach(tag => tag.remove());
      
      const weixinDescription = document.createElement('meta');
      weixinDescription.setAttribute('name', 'weixin:description');
      weixinDescription.content = ogDescription;
      document.head.insertBefore(weixinDescription, document.head.firstChild);
      
      const ogDescriptionTag = document.createElement('meta');
      ogDescriptionTag.setAttribute('property', 'og:description');
      ogDescriptionTag.content = ogDescription;
      document.head.insertBefore(ogDescriptionTag, document.head.firstChild);
    }
  }, [location.pathname, t]); // 依赖路径和翻译函数，当路径或语言变化时重新设置

  // 额外的useEffect，在SEOHead执行后再次强制更新（作为保险）
  useEffect(() => {
    const shareImageUrl = `${window.location.origin}/static/logo.png?v=3`;
    
    // 等待一小段时间确保SEOHead已经执行
    const timer = setTimeout(() => {
      // 强制检查并更新og:image
      const existingOgImage = document.querySelector('meta[property="og:image"]') as HTMLMetaElement;
      if (!existingOgImage || !existingOgImage.content.includes('/static/logo.png')) {
        // 如果不存在或不正确，强制更新
        if (existingOgImage) {
          existingOgImage.remove();
        }
        const ogImage = document.createElement('meta');
        ogImage.setAttribute('property', 'og:image');
        ogImage.content = shareImageUrl;
        document.head.insertBefore(ogImage, document.head.firstChild);
      } else {
        // 如果存在但内容不对，更新它
        existingOgImage.content = shareImageUrl;
        document.head.insertBefore(existingOgImage, document.head.firstChild);
      }
      
      // 同样处理weixin:image
      const existingWeixinImage = document.querySelector('meta[name="weixin:image"]') as HTMLMetaElement;
      if (!existingWeixinImage || !existingWeixinImage.content.includes('/static/logo.png')) {
        if (existingWeixinImage) {
          existingWeixinImage.remove();
        }
        const weixinImage = document.createElement('meta');
        weixinImage.setAttribute('name', 'weixin:image');
        weixinImage.content = shareImageUrl;
        document.head.insertBefore(weixinImage, document.head.firstChild);
      } else {
        existingWeixinImage.content = shareImageUrl;
        document.head.insertBefore(existingWeixinImage, document.head.firstChild);
      }
    }, 100); // 延迟100ms，确保SEOHead已经执行
    
    return () => clearTimeout(timer);
  }, [location.pathname]);

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
  
  const { navigate } = useLocalizedNavigation();
  const navigateRaw = useRouterNavigate(); // 原始navigate用于语言切换

  // 加载用户信息和已申请任务
  useEffect(() => {
    const loadUser = async () => {
      try {
        // 直接调用 API，添加时间戳避免缓存
        const userData = await api.get('/api/users/profile/me', {
          params: { _t: Date.now() } // 添加时间戳避免缓存
        }).then(res => res.data);
        console.log('[DEBUG] Tasks - 加载的用户数据:', userData);
        console.log('[DEBUG] Tasks - residence_city:', userData?.residence_city);
        setUser(userData);
        
        // 设置用户位置和默认地点
        if (userData) {
          // 如果用户有常住城市，设置为默认地点
          // 清理首尾空格（防止数据库中的空格问题）
          const residenceCity = userData.residence_city ? String(userData.residence_city).trim() : null;
          console.log('[DEBUG] Tasks - residence_city 原始值:', userData.residence_city);
          console.log('[DEBUG] Tasks - residence_city 清理后值:', residenceCity);
          console.log('[DEBUG] Tasks - CITIES 是否包含:', residenceCity ? CITIES.includes(residenceCity) : false);
          
          if (residenceCity && CITIES.includes(residenceCity)) {
            console.log('[DEBUG] Tasks - 设置默认城市为:', residenceCity);
            setCity(residenceCity);
            setUserLocation(residenceCity);
            setCityInitialized(true); // 标记城市已初始化
          } else if (userData.location) {
            // 兼容旧的位置字段
            console.log('[DEBUG] Tasks - 使用旧的位置字段:', userData.location);
            setUserLocation(userData.location);
            setCityInitialized(true); // 即使没有常住城市，也标记为已初始化
          } else {
            // 用户没有设置常住城市，保持'all'，但也标记为已初始化
            console.log('[DEBUG] Tasks - 用户没有设置常住城市，使用默认值 all');
            console.log('[DEBUG] Tasks - residence_city 检查失败原因:', {
              hasResidenceCity: !!residenceCity,
              inCITIES: residenceCity ? CITIES.includes(residenceCity) : false,
              residenceCityValue: residenceCity
            });
            setCityInitialized(true);
          }
        } else {
          // 用户未登录，标记为已初始化（保持默认'all'）
          console.log('[DEBUG] Tasks - 用户未登录，使用默认值 all');
          setCityInitialized(true);
        }
        
        // 加载已申请的任务列表
        try {
          const applications = await getUserApplications();
          
          // 将申请的任务ID添加到状态中
          const taskIds = applications.map((app: any) => Number(app.task_id)).filter((id: number) => !isNaN(id));
          setAppliedTasks(new Set(taskIds));
        } catch (error) {
          console.error('加载已申请任务失败:', error);
        }
      } catch (error: any) {
        console.error('Tasks页面加载用户信息失败:', error);
        // 如果获取用户信息失败，设置为未登录状态，但标记城市已初始化
        setUser(null);
        setCityInitialized(true); // 即使加载失败，也标记为已初始化，避免无限等待
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
          setUnreadCount(unreadCountData);
          setSystemSettings(settingsData);
        } catch (error) {
          console.error('加载通知或系统设置失败:', error);
        }
      }
    };
    
    loadNotificationsAndSettings();
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

  // 设置滑动提示文本的双语化CSS变量
  useEffect(() => {
    const swipeText = `← ${t('tasks.swipeToSeeMore')} →`;
    document.documentElement.style.setProperty('--swipe-text', `'${swipeText}'`);
    
    return () => {
      document.documentElement.style.removeProperty('--swipe-text');
    };
  }, [t]);

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
    // 只有当城市已初始化后才加载任务，避免初始加载时使用错误的城市筛选
    if (cityInitialized) {
      loadTasks();
    }
  }, [page, type, city, keyword, sortBy, loadTasks, cityInitialized]);

  // 点击外部关闭下拉菜单
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('[data-location-dropdown]')) {
        setShowLocationDropdown(false);
      }
      if (!target.closest('[data-language-dropdown]')) {
        setShowLanguageDropdown(false);
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

    if (showLocationDropdown || showLanguageDropdown || showRewardDropdown || showDeadlineDropdown || showLevelDropdown) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showLocationDropdown, showLanguageDropdown, showRewardDropdown, showDeadlineDropdown, showLevelDropdown]);


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

  // 处理任务申请
  const handleAcceptTask = async (taskId: number) => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }

    try {
      // 使用 apply 端点，创建申请记录等待发布者同意
      const data = await api.post(`/api/tasks/${taskId}/apply`, { message: "" });
      
      alert(t('tasks.acceptSuccess'));
      // 将任务添加到已申请列表，隐藏申请按钮
      setAppliedTasks(prev => new Set([...Array.from(prev), taskId]));
      loadTasks(); // 重新加载任务列表
    } catch (error: any) {
      console.error('申请任务失败:', error);
      alert(error.response?.data?.detail || t('tasks.acceptFailed'));
    }
  };

  // 处理任务详情查看
  const handleViewTask = (taskId: number) => {
    setSelectedTaskId(taskId);
    setShowTaskDetailModal(true);
  };

  // 处理联系发布者
  const handleContactPoster = (posterId: string) => {
    navigate(`/message?uid=${posterId}`);
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
    if (taskLevel !== t('tasks.levels.all')) {
      const levelMap: { [key: string]: string } = {
        [t('tasks.levels.normal')]: 'normal',
        [t('tasks.levels.vip')]: 'vip',
        [t('tasks.levels.super')]: 'super'
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
      {/* SEO优化 - 添加canonical URL防止重复索引 */}
      <SEOHead 
        title={t('tasks.pageTitle')}
        description={t('tasks.seoDescription')}
        canonicalUrl={canonicalUrl}
        ogTitle={t('tasks.pageTitle')}
        ogDescription={t('tasks.seoDescription')}
        ogImage="/static/logo.png"
        ogUrl={canonicalUrl}
      />

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
              Link²Ur
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
        {/* 浮空双语选择按钮 */}
        <div 
          style={{
            position: 'fixed',
            bottom: isMobile ? '20px' : '30px',
            right: isMobile ? '16px' : 'max(16px, calc((100vw - 1200px) / 2 + 16px))',
            zIndex: 1000,
            width: 'auto'
          }}
          data-language-dropdown
        >
          <div 
            onClick={() => setShowLanguageDropdown(!showLanguageDropdown)}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: '56px',
              height: '56px',
              borderRadius: '50%',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              background: showLanguageDropdown ? '#f3f4f6' : '#fff',
              border: '1px solid #e5e7eb',
              boxShadow: showLanguageDropdown 
                ? '0 4px 16px rgba(0,0,0,0.15)' 
                : '0 4px 12px rgba(0,0,0,0.12)',
              transform: showLanguageDropdown ? 'translateY(-2px) scale(1.05)' : 'translateY(0) scale(1)'
            }}
            onMouseEnter={(e) => {
              if (!showLanguageDropdown) {
                e.currentTarget.style.background = '#fff';
                e.currentTarget.style.borderColor = '#d1d5db';
                e.currentTarget.style.boxShadow = '0 6px 16px rgba(0,0,0,0.15)';
                e.currentTarget.style.transform = 'translateY(-2px) scale(1.05)';
              }
            }}
            onMouseLeave={(e) => {
              if (!showLanguageDropdown) {
                e.currentTarget.style.background = '#fff';
                e.currentTarget.style.borderColor = '#e5e7eb';
                e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.12)';
                e.currentTarget.style.transform = 'translateY(0) scale(1)';
              }
            }}
            title={language === 'zh' ? 'English' : '中文'}
          >
            <span style={{ fontSize: '24px' }}>🌐</span>
          </div>
          
          {/* 语言选择下拉菜单 */}
          {showLanguageDropdown && (
            <div 
              style={{
                position: 'absolute',
                bottom: '100%',
                left: '0',
                background: '#fff',
                border: '1px solid #e5e7eb',
                borderRadius: '12px',
                boxShadow: '0 8px 24px rgba(0,0,0,0.15), 0 2px 8px rgba(0,0,0,0.1)',
                zIndex: 9999,
                marginBottom: '6px',
                minWidth: '120px',
                transform: 'translateY(0)',
                animation: 'fadeInUp 0.2s ease-out',
                backdropFilter: 'blur(10px)'
              }}>
              <div
                onClick={() => {
                  setLanguage('zh', navigateRaw);
                  setShowLanguageDropdown(false);
                }}
                style={{
                  padding: '12px 16px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  color: language === 'zh' ? '#1890ff' : '#374151',
                  borderBottom: '1px solid #f3f4f6',
                  transition: 'background 0.2s ease',
                  fontWeight: language === 'zh' ? '600' : '400',
                  background: language === 'zh' ? '#f0f9ff' : 'transparent'
                }}
                onMouseEnter={(e) => {
                  if (language !== 'zh') {
                    e.currentTarget.style.background = '#f9fafb';
                  }
                }}
                onMouseLeave={(e) => {
                  if (language !== 'zh') {
                    e.currentTarget.style.background = 'transparent';
                  }
                }}
              >
                中文
              </div>
              <div
                onClick={() => {
                  setLanguage('en', navigateRaw);
                  setShowLanguageDropdown(false);
                }}
                style={{
                  padding: '12px 16px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  color: language === 'en' ? '#1890ff' : '#374151',
                  transition: 'background 0.2s ease',
                  fontWeight: language === 'en' ? '600' : '400',
                  background: language === 'en' ? '#f0f9ff' : 'transparent',
                  borderRadius: '0 0 12px 12px'
                }}
                onMouseEnter={(e) => {
                  if (language !== 'en') {
                    e.currentTarget.style.background = '#f9fafb';
                  }
                }}
                onMouseLeave={(e) => {
                  if (language !== 'en') {
                    e.currentTarget.style.background = 'transparent';
                  }
                }}
              >
                English
              </div>
            </div>
          )}
        </div>
        
        <div style={{
          maxWidth: '1200px',
          margin: '0 auto'
        }}>
          {/* SEO优化：可见的H1标签 */}
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
            任务大厅 - Link²Ur
          </h1>
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
                  <div style={{ fontSize: '14px', fontWeight: '600' }}>{t('tasks.sorting.latest')}</div>
                  <div style={{ fontSize: '11px', opacity: 0.8 }}>{t('tasks.sorting.byTime')}</div>
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
                      {rewardSort === 'desc' ? t('tasks.sorting.rewardDesc') : 
                       rewardSort === 'asc' ? t('tasks.sorting.rewardAsc') : t('tasks.sorting.rewardSort')}
                    </div>
                    <div style={{ fontSize: '11px', opacity: 0.8 }}>
                      {rewardSort ? t('tasks.sorting.byReward') : t('tasks.sorting.selectSort')}
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
                      <span>{t('tasks.sorting.rewardSort')}</span>
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
                      <span>{t('tasks.sorting.rewardDesc')}</span>
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
                      <span>{t('tasks.sorting.rewardAsc')}</span>
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
                      {deadlineSort === 'asc' ? t('tasks.sorting.deadlineAsc') : 
                       deadlineSort === 'desc' ? t('tasks.sorting.deadlineDesc') : t('tasks.sorting.deadlineSort')}
                    </div>
                    <div style={{ fontSize: '11px', opacity: 0.8 }}>
                      {deadlineSort ? t('tasks.sorting.byDeadline') : t('tasks.sorting.selectSort')}
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
                      <span>{t('tasks.sorting.deadlineSort')}</span>
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
                      <span>{t('tasks.sorting.deadlineAsc')}</span>
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
                      <span>{t('tasks.sorting.deadlineDesc')}</span>
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
                  placeholder={t('tasks.search.placeholder')}
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
              {t('tasks.systemNotice')}
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
            {taskLevel !== t('tasks.levels.all') && (
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
                <span>{t('tasks.search.filter')}</span>
                <span style={{ fontWeight: '500' }}>{taskLevel}</span>
                <button
                  onClick={() => setTaskLevel(t('tasks.levels.all'))}
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
                  {tasks.length === 0 ? t('tasks.search.noTasks') : t('tasks.search.noMatchingTasks')}
                </div>
                {tasks.length > 0 && (
                  <div style={{ fontSize: '14px', color: '#999', marginTop: '8px' }}>
                    {t('tasks.search.tryAdjustFilter')}
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
                      
                      {/* 已申请状态 */}
                      {(task.status === 'open' || task.status === 'taken') && user && user.id !== task.poster_id && appliedTasks.has(task.id) && (
                        <div style={{
                          flex: 1,
                          padding: '8px 12px',
                          borderRadius: '6px',
                          background: '#e5e7eb',
                          color: '#6b7280',
                          fontSize: '14px',
                          fontWeight: '500',
                          textAlign: 'center',
                          cursor: 'not-allowed',
                          opacity: 0.6
                        }}>
                          ✓ {t('tasks.applied')}
                        </div>
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
          /* 语言选择框浮空动画 */
          @keyframes fadeInDown {
            from {
              opacity: 0;
              transform: translateY(-8px);
            }
            to {
              opacity: 1;
              transform: translateY(0);
            }
          }
          
          @keyframes fadeInUp {
            from {
              opacity: 0;
              transform: translateY(8px);
            }
            to {
              opacity: 1;
              transform: translateY(0);
            }
          }
          
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
            
            /* 任务网格移动端优化 - 两个一行显示 */
            .tasks-grid {
              grid-template-columns: repeat(2, 1fr) !important;
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
              content: var(--swipe-text, '← 滑动查看更多 →') !important;
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
