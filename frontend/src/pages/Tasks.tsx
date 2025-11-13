import React, { useEffect, useState, useCallback, useMemo, useRef } from 'react';
import { useLocation, useNavigate as useRouterNavigate } from 'react-router-dom';
import { message } from 'antd';
import api, { fetchTasks, fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout, getUserApplications, applyForTask } from '../api';
import { API_BASE_URL } from '../config';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import TaskTitle from '../components/TaskTitle';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import SEOHead from '../components/SEOHead';
import { useLanguage } from '../contexts/LanguageContext';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

// 添加可爱的动画样式
const bellStyles = `
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

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
    const separator = t('home.timeSeparator');
    
    // 优化时间显示格式（使用翻译）
    if (days >= 30) {
      const months = Math.floor(days / 30);
      const remainingDays = days % 30;
      if (remainingDays > 0) {
        return `${months}${t('home.months')}${separator}${remainingDays}${t('home.days')}`;
      }
      return `${months}${t('home.months')}`;
    } else if (days > 0) {
      if (hours > 0) {
        return `${days}${t('home.days')}${separator}${hours}${t('home.hours')}`;
      }
      return `${days}${t('home.days')}`;
    } else if (hours > 0) {
      if (minutes > 0) {
        return `${hours}${t('home.hours')}${separator}${minutes}${t('home.minutes')}`;
      }
      return `${hours}${t('home.hours')}`;
    } else {
      return `${minutes}${t('home.minutes')}`;
    }
  } catch (error) {
    console.error(t('home.timeCalculationError'), error);
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

// 获取任务类型的默认图片路径
const getTaskTypeDefaultImage = (taskType: string): string => {
  const taskTypeMap: Record<string, string> = {
    "Housekeeping": "/static/task-types/housekeeping.jpg",
    "Campus Life": "/static/task-types/campus-life.jpg",
    "Second-hand & Rental": "/static/task-types/secondhand.jpg",
    "Errand Running": "/static/task-types/errand.jpg",
    "Skill Service": "/static/task-types/skill.jpg",
    "Social Help": "/static/task-types/social.jpg",
    "Transportation": "/static/task-types/transportation.jpg",
    "Pet Care": "/static/task-types/pet.jpg",
    "Life Convenience": "/static/task-types/convenience.jpg",
    "Other": "/static/task-types/other.jpg"
  };
  return taskTypeMap[taskType] || "/static/task-types/default.jpg";
};

const Tasks: React.FC = () => {
  const { t, language, setLanguage } = useLanguage();
  const location = useLocation();
  
  // 获取翻译后的任务类型名称
  const getTaskTypeLabel = (taskType: string): string => {
    return t(`publishTask.taskTypes.${taskType}`) || taskType;
  };
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [type, setType] = useState('all');
  const [city, setCity] = useState('all');
  const [cityInitialized, setCityInitialized] = useState(false); // 标记城市是否已初始化
  const [keyword, setKeyword] = useState(''); // 实时输入值（用于显示）
  const [debouncedKeyword, setDebouncedKeyword] = useState(''); // 防抖后的搜索关键词（用于筛选）
  const keywordDebounceRef = useRef<NodeJS.Timeout | null>(null);
  const locationDropdownRef = useRef<HTMLDivElement | null>(null);
  const locationButtonRef = useRef<HTMLDivElement | null>(null);
  const [page, setPage] = useState(1);
  const [pageSize] = useState(12);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
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
    // 检查是否是任务详情页，如果是则不设置meta标签（让任务详情页自己管理）
    const isTaskDetailPage = /\/tasks\/\d+/.test(location.pathname);
    if (isTaskDetailPage) {
      return; // 不设置meta标签，让任务详情页自己管理
    }
    
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

    // 设置favicon图片（完整URL，添加版本号避免缓存）
    const shareImageUrl = `${window.location.origin}/static/favicon.png?v=3`;
    
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
    const shareImageUrl = `${window.location.origin}/static/favicon.png?v=3`;
    
    // 等待一小段时间确保SEOHead已经执行
    const timer = setTimeout(() => {
      // 强制检查并更新og:image
      const existingOgImage = document.querySelector('meta[property="og:image"]') as HTMLMetaElement;
      if (!existingOgImage || !existingOgImage.content.includes('/static/favicon.png')) {
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
      if (!existingWeixinImage || !existingWeixinImage.content.includes('/static/favicon.png')) {
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
      
      // 移动端计算下拉菜单位置
      if (isMobile && locationDropdownRef.current && locationButtonRef.current) {
        const buttonRect = locationButtonRef.current.getBoundingClientRect();
        const dropdown = locationDropdownRef.current;
        dropdown.style.top = `${buttonRect.bottom + 4}px`;
        dropdown.style.left = `${buttonRect.left}px`;
      }
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showLocationDropdown, isMobile]);

  // 处理金额排序变化
  const handleRewardSortChange = useCallback((value: string) => {
    console.log('[Tasks] 金额排序变化:', value);
    setRewardSort(value);
    setDeadlineSort(''); // 清除截止日期排序
    if (value === '') {
      console.log('[Tasks] 清除金额排序，设置为 latest');
      setSortBy('latest');
    } else {
      const newSortBy = `reward_${value}`;
      console.log('[Tasks] 设置排序为:', newSortBy);
      setSortBy(newSortBy);
      // 立即触发加载，确保排序生效
      setTimeout(() => {
        console.log('[Tasks] 触发任务重新加载，排序参数:', newSortBy);
      }, 0);
    }
  }, []);

  // 处理截止日期排序变化
  const handleDeadlineSortChange = useCallback((value: string) => {
    console.log('[Tasks] 截止日期排序变化:', value);
    setDeadlineSort(value);
    setRewardSort(''); // 清除金额排序
    if (value === '') {
      console.log('[Tasks] 清除截止时间排序，设置为 latest');
      setSortBy('latest');
    } else {
      const newSortBy = `deadline_${value}`;
      console.log('[Tasks] 设置排序为:', newSortBy);
      setSortBy(newSortBy);
      // 立即触发加载，确保排序生效
      setTimeout(() => {
        console.log('[Tasks] 触发任务重新加载，排序参数:', newSortBy);
      }, 0);
    }
  }, []);

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
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  const [showNotifications, setShowNotifications] = useState(false);
  
  // 调试：打印未读数量
  React.useEffect(() => {
    console.log('[Tasks] 未读消息数量:', messageUnreadCount);
  }, [messageUnreadCount]);
  
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
  
  // 申请任务弹窗状态
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [selectedTaskForApply, setSelectedTaskForApply] = useState<number | null>(null);
  const [applyMessage, setApplyMessage] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState<number | undefined>();
  const [isNegotiateChecked, setIsNegotiateChecked] = useState(false);
  
  const { navigate } = useLocalizedNavigation();
  const navigateRaw = useRouterNavigate(); // 原始navigate用于语言切换

  // 检查按钮是否被渲染（在组件挂载后）
  useEffect(() => {
    console.log('[Tasks] ========== 组件已挂载，检查按钮渲染 ==========');
    setTimeout(() => {
      const rewardContainer = document.querySelector('.reward-dropdown-container');
      const deadlineContainer = document.querySelector('.deadline-dropdown-container');
      console.log('[Tasks] 金额排序容器:', rewardContainer);
      console.log('[Tasks] 截止时间排序容器:', deadlineContainer);
      if (rewardContainer) {
        console.log('[Tasks] 金额排序容器已找到，位置:', rewardContainer.getBoundingClientRect());
      } else {
        console.warn('[Tasks] ⚠️ 金额排序容器未找到！');
      }
      if (deadlineContainer) {
        console.log('[Tasks] 截止时间排序容器已找到，位置:', deadlineContainer.getBoundingClientRect());
      } else {
        console.warn('[Tasks] ⚠️ 截止时间排序容器未找到！');
      }
    }, 1000); // 延迟1秒检查，确保DOM已渲染
  }, []);

  // 加载用户信息和已申请任务
  useEffect(() => {
    const loadUser = async () => {
      try {
        // 直接调用 API，添加时间戳避免缓存
        const userData = await api.get('/api/users/profile/me', {
          params: { _t: Date.now() } // 添加时间戳避免缓存
        }).then(res => res.data);
        setUser(userData);
        
        // 设置用户位置和默认地点
        if (userData) {
          // 如果用户有常住城市，设置为默认地点
          // 清理首尾空格（防止数据库中的空格问题）
          const residenceCity = userData.residence_city ? String(userData.residence_city).trim() : null;
          
          if (residenceCity && CITIES.includes(residenceCity)) {
            setCity(residenceCity);
            setUserLocation(residenceCity);
            setCityInitialized(true); // 标记城市已初始化
          } else if (userData.location) {
            // 兼容旧的位置字段
            setUserLocation(userData.location);
            setCityInitialized(true); // 即使没有常住城市，也标记为已初始化
          } else {
            // 用户没有设置常住城市，保持'all'，但也标记为已初始化
            setCityInitialized(true);
          }
        } else {
          // 用户未登录，标记为已初始化（保持默认'all'）
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

  // 设置滑动提示文本的双语化CSS变量
  useEffect(() => {
    const swipeText = `← ${t('tasks.swipeToSeeMore')} →`;
    document.documentElement.style.setProperty('--swipe-text', `'${swipeText}'`);
    
    return () => {
      document.documentElement.style.removeProperty('--swipe-text');
    };
  }, [t]);

  // 加载任务列表 - 使用缓存和防抖优化
  const loadTasks = useCallback(async (isLoadMore = false, targetPage?: number) => {
    if (isLoadMore) {
      setLoadingMore(true);
    } else {
      setLoading(true);
      setPage(1); // 重置页码
      setHasMore(true);
    }
    
    try {
      // 使用优化后的 fetchTasks，它已经包含了缓存和防抖
      // 使用防抖后的关键词，确保搜索更稳定
      const searchKeyword = debouncedKeyword.trim() || keyword.trim() || undefined;
      // 如果是加载更多，使用传入的页码或当前页码+1
      const currentPage = isLoadMore ? (targetPage ?? page + 1) : 1;
      
      // 调试：输出排序参数
      console.log('[Tasks] 加载任务，排序参数:', sortBy);
      console.log('[Tasks] 当前状态 - rewardSort:', rewardSort, 'deadlineSort:', deadlineSort, 'sortBy:', sortBy);
      
      const data = await fetchTasks({
        type: type !== 'all' ? type : undefined,
        city: city !== 'all' ? city : undefined,
        keyword: searchKeyword,
        page: currentPage,
        pageSize: pageSize,
        sort_by: sortBy || 'latest'  // 确保总是传递一个值
      });
      
      console.log('[Tasks] fetchTasks 返回数据，任务数量:', data.tasks?.length || 0);
      
      const tasksList = (data.tasks || []).map((task: any) => {
        // 确保 images 是数组格式
        if (task.images) {
          if (typeof task.images === 'string') {
            try {
              task.images = JSON.parse(task.images);
            } catch (e) {
              task.images = [];
            }
          }
          if (!Array.isArray(task.images)) {
            task.images = [];
          }
        } else {
          task.images = [];
        }
        return task;
      });
      
      if (isLoadMore) {
        // 追加任务
        setTasks(prev => [...prev, ...tasksList]);
        // 更新页码
        setPage(currentPage);
      } else {
        // 替换任务列表
        setTasks(tasksList);
        setPage(1);
      }
      
      setTotal(data.total || 0);
      
      // 判断是否还有更多任务
      const totalPages = Math.ceil((data.total || 0) / pageSize);
      setHasMore(currentPage < totalPages && tasksList.length > 0);
    } catch (error) {
      if (!isLoadMore) {
        setTasks([]);
        setTotal(0);
      }
      setHasMore(false);
    } finally {
      if (isLoadMore) {
        setLoadingMore(false);
      } else {
        setLoading(false);
      }
    }
  }, [page, pageSize, type, city, debouncedKeyword, keyword, sortBy]);
  
  // 监听 sortBy 变化，用于调试
  useEffect(() => {
    console.log('[Tasks] sortBy 状态已更新为:', sortBy);
  }, [sortBy]);
  
  // 加载更多任务
  const loadMoreTasks = useCallback(() => {
    if (!loadingMore && !loading && hasMore) {
      loadTasks(true);
    }
  }, [loadingMore, loading, hasMore, loadTasks]);

  useEffect(() => {
    // 只有当城市已初始化后才加载任务，避免初始加载时使用错误的城市筛选
    // 使用 debouncedKeyword 触发搜索，避免频繁请求
    if (cityInitialized) {
      console.log('[Tasks] useEffect 触发 loadTasks，当前 sortBy:', sortBy);
      loadTasks(false); // 初始加载，不是加载更多
    }
  }, [type, city, debouncedKeyword, sortBy, cityInitialized, loadTasks]); // 添加 loadTasks 依赖
  
  // 滚动监听，实现无限滚动
  useEffect(() => {
    const handleScroll = () => {
      if (loadingMore || loading || !hasMore) return;
      
      const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
      const windowHeight = window.innerHeight;
      const documentHeight = document.documentElement.scrollHeight;
      
      // 当滚动到距离底部200px时，开始加载更多
      if (scrollTop + windowHeight >= documentHeight - 200) {
        loadMoreTasks();
      }
    };
    
    // 使用节流优化滚动事件
    let ticking = false;
    const throttledHandleScroll = () => {
      if (!ticking) {
        window.requestAnimationFrame(() => {
          handleScroll();
          ticking = false;
        });
        ticking = true;
      }
    };
    
    window.addEventListener('scroll', throttledHandleScroll, { passive: true });
    return () => window.removeEventListener('scroll', throttledHandleScroll);
  }, [loadingMore, loading, hasMore, loadMoreTasks]);

  // 点击外部关闭下拉菜单
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      
      // 检查位置下拉菜单
      if (showLocationDropdown && !target.closest('[data-location-dropdown]')) {
        setShowLocationDropdown(false);
      }
      
      // 检查语言下拉菜单
      if (showLanguageDropdown && !target.closest('[data-language-dropdown]')) {
        setShowLanguageDropdown(false);
      }
      
      // 检查金额排序下拉菜单
      if (showRewardDropdown && !target.closest('.reward-dropdown-container')) {
        setShowRewardDropdown(false);
      }
      
      // 检查截止时间排序下拉菜单
      if (showDeadlineDropdown && !target.closest('.deadline-dropdown-container')) {
        setShowDeadlineDropdown(false);
      }
      
      // 检查任务等级下拉菜单
      if (showLevelDropdown && !target.closest('.level-dropdown-container')) {
        setShowLevelDropdown(false);
      }
    };

    if (showLocationDropdown || showLanguageDropdown || showRewardDropdown || showDeadlineDropdown || showLevelDropdown) {
      // 使用 mousedown 事件，在 click 之前触发，避免与按钮的 onClick 冲突
      document.addEventListener('mousedown', handleClickOutside);

      return () => {
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
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

  // 处理任务申请（显示弹窗）
  const handleAcceptTask = (taskId: number) => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    // 显示申请弹窗
    setSelectedTaskForApply(taskId);
    // 重置议价相关状态
    setNegotiatedPrice(undefined);
    setIsNegotiateChecked(false);
    setShowApplyModal(true);
    setApplyMessage('');
  };
  
  // 提交申请
  const handleSubmitApplication = async () => {
    if (!selectedTaskForApply) return;
    
    // 验证议价金额：如果勾选了议价，金额必须大于0
    if (isNegotiateChecked && (negotiatedPrice === undefined || negotiatedPrice === null || negotiatedPrice <= 0)) {
      message.error('如果选择议价，请输入大于0的议价金额');
      return;
    }
    
    // 获取任务信息以获取货币类型和原本金额
    const task = tasks.find(t => t.id === selectedTaskForApply);
    if (!task) return;
    
    const currency = task?.currency || 'GBP';
    const baseReward = task?.base_reward ?? task?.reward ?? 0;
    
    // 如果没有勾选议价或输入框为空，则不发送议价金额（保持原本金额）
    const finalNegotiatedPrice = (isNegotiateChecked && negotiatedPrice !== undefined && negotiatedPrice !== null && negotiatedPrice > 0) 
      ? negotiatedPrice 
      : undefined;
    
    // 如果议价金额小于原本金额，提示用户确认
    if (finalNegotiatedPrice !== undefined && finalNegotiatedPrice < baseReward) {
      const confirmed = window.confirm(
        `您输入的议价金额（£${finalNegotiatedPrice.toFixed(2)}）低于任务原本金额（£${baseReward.toFixed(2)}）。\n\n` +
        `这将降低您获得的金额。是否确定要继续？`
      );
      if (!confirmed) {
        return;
      }
    }
    
    try {
      
      await applyForTask(
        selectedTaskForApply,
        applyMessage || undefined,
        finalNegotiatedPrice,
        currency
      );
      
      message.success(t('tasks.acceptSuccess'));
      // 将任务添加到已申请列表，隐藏申请按钮
      setAppliedTasks(prev => new Set([...Array.from(prev), selectedTaskForApply]));
      loadTasks(); // 重新加载任务列表
      
      // 关闭弹窗
      setShowApplyModal(false);
      setSelectedTaskForApply(null);
      setApplyMessage('');
      setNegotiatedPrice(undefined);
    } catch (error: any) {
      console.error('申请任务失败:', error);
      message.error(error.response?.data?.detail || t('tasks.acceptFailed'));
    }
  };

  // 处理任务详情查看
  const handleViewTask = (taskId: number) => {
    setSelectedTaskId(taskId);
    setShowTaskDetailModal(true);
  };

  // 处理联系发布者（跳转到任务聊天页面）
  const handleContactPoster = (taskId: number) => {
    navigate(`/message?taskId=${taskId}`);
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

  // 防抖处理搜索关键词，减少输入延迟
  useEffect(() => {
    // 清除之前的定时器
    if (keywordDebounceRef.current) {
      clearTimeout(keywordDebounceRef.current);
    }
    
    // 设置新的防抖定时器，300ms后更新防抖关键词
    keywordDebounceRef.current = setTimeout(() => {
      setDebouncedKeyword(keyword);
    }, 300);
    
    // 清理函数
    return () => {
      if (keywordDebounceRef.current) {
        clearTimeout(keywordDebounceRef.current);
      }
    };
  }, [keyword]);

  // 使用 useMemo 优化任务筛选逻辑，避免不必要的重新计算
  const filteredTasks = useMemo(() => {
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

    // 注意：搜索关键词已经在服务端处理，这里不需要再次过滤
    // 如果服务端返回了搜索结果，说明已经匹配了标题和描述
    // 客户端过滤会导致搜索结果不准确，因为只过滤了已加载的任务

    // 注意：排序应该在服务端进行，这里只进行筛选
    // 客户端排序会破坏服务端的分页排序逻辑
    
    return filtered;
  }, [tasks, taskLevel, city, type, debouncedKeyword, t]);

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
        ogImage="/static/favicon.png"
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
                  top: isMobile ? undefined : '100%',
                  bottom: isMobile ? 'auto' : undefined,
                  left: isMobile ? undefined : '0',
                  right: isMobile ? undefined : 'auto',
                  background: '#fff',
                  border: '1px solid #e5e7eb',
                  borderRadius: '8px',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                  zIndex: 99999,
                  marginTop: isMobile ? '0' : '4px',
                  maxHeight: '200px',
                  overflowY: 'auto',
                  overflowX: 'hidden',
                  minWidth: '150px',
                  width: 'auto',
                  maxWidth: '200px',
                  boxSizing: 'border-box'
                }}
                ref={locationDropdownRef}>
                <div
                  onClick={() => handleLocationChange('all')}
                  style={{
                    padding: '12px 16px',
                    paddingRight: '20px',
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
                      paddingRight: '20px',
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
              unreadCount={messageUnreadCount}
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
            background: 'transparent',
            borderRadius: '16px',
            padding: '20px',
            marginBottom: '20px',
            position: 'relative'
          }}>
            <div className="category-icons" style={{
              display: 'flex',
              gap: '16px',
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
                    gap: '10px',
                    flex: '1',
                    minWidth: '90px',
                    maxWidth: '140px',
                    cursor: 'pointer',
                    padding: '12px',
                    borderRadius: '12px',
                    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    position: 'relative'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)';
                    e.currentTarget.style.transform = 'translateY(-4px)';
                    e.currentTarget.style.boxShadow = '0 8px 24px rgba(0,0,0,0.12)';
                    const iconCircle = e.currentTarget.querySelector('.category-icon-circle') as HTMLElement;
                    if (iconCircle) {
                      iconCircle.style.transform = 'scale(1.1) rotate(5deg)';
                      iconCircle.style.boxShadow = '0 6px 20px rgba(0,0,0,0.2), 0 4px 12px rgba(0,0,0,0.15)';
                    }
                    const glowEffect = e.currentTarget.querySelector('.icon-glow') as HTMLElement;
                    if (glowEffect) {
                      glowEffect.style.opacity = '1';
                    }
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'transparent';
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = 'none';
                    const iconCircle = e.currentTarget.querySelector('.category-icon-circle') as HTMLElement;
                    if (iconCircle) {
                      iconCircle.style.transform = 'scale(1) rotate(0deg)';
                      iconCircle.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)';
                    }
                    const glowEffect = e.currentTarget.querySelector('.icon-glow') as HTMLElement;
                    if (glowEffect) {
                      glowEffect.style.opacity = '0';
                    }
                  }}
                  onClick={() => setType(taskType)}
                >
                  <div 
                    className="category-icon-circle"
                    style={{
                      width: '64px',
                      height: '64px',
                      background: `linear-gradient(135deg, ${['#ef4444', '#f59e0b', '#10b981', '#3b82f6', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16', '#94a3b8', '#78716c'][index]}, ${['#dc2626', '#d97706', '#059669', '#2563eb', '#7c3aed', '#db2777', '#0891b2', '#65a30d', '#cbd5e1', '#57534e'][index]})`,
                      borderRadius: '50%',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '28px',
                      color: '#fff',
                      boxShadow: '0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)',
                      transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                      position: 'relative',
                      overflow: 'hidden'
                    }}
                  >
                    <div 
                      className="icon-glow"
                      style={{
                        position: 'absolute',
                        top: '-50%',
                        left: '-50%',
                        width: '200%',
                        height: '200%',
                        background: 'radial-gradient(circle, rgba(255,255,255,0.3) 0%, transparent 70%)',
                        opacity: 0,
                        transition: 'opacity 0.3s ease',
                        pointerEvents: 'none'
                      }}
                    />
                    <span style={{ position: 'relative', zIndex: 1 }}>
                      {['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'][index]}
                    </span>
                  </div>
                  <span style={{
                    fontSize: '14px',
                    color: '#374151',
                    textAlign: 'center',
                    fontWeight: '600',
                    lineHeight: '1.4',
                    transition: 'color 0.2s ease'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.color = '#1f2937';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.color = '#374151';
                  }}
                  >
                    {getTaskTypeLabel(taskType)}
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
                    {taskLevel === t('tasks.levels.vip') ? '👑' : taskLevel === t('tasks.levels.super') ? '⭐' : '🎯'}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '14px', fontWeight: '600' }}>
                      {taskLevel}
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
                    width: 'auto',
                    minWidth: '120px',
                    maxWidth: '160px'
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
                        🎯
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
                </div>
              </div>

              {/* 金额排序卡片 */}
              <div 
                className="reward-dropdown-container" 
                style={{ position: 'relative', zIndex: 10 }}
                ref={(el) => {
                  if (el) {
                    console.log('[Tasks] 金额排序容器已渲染:', el);
                  }
                }}
              >
                <div
                  onClick={(e) => {
                    console.log('[Tasks] ========== 点击金额排序按钮 ==========');
                    console.log('[Tasks] 当前 showRewardDropdown:', showRewardDropdown);
                    console.log('[Tasks] 事件对象:', e);
                    e.stopPropagation();
                    const newValue = !showRewardDropdown;
                    console.log('[Tasks] 设置 showRewardDropdown 为:', newValue);
                    setShowRewardDropdown(newValue);
                    console.log('[Tasks] showRewardDropdown 已更新');
                  }}
                  onMouseDown={(e) => {
                    console.log('[Tasks] 金额排序按钮 onMouseDown');
                    e.stopPropagation();
                  }}
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
                    minWidth: '140px',
                    position: 'relative',
                    zIndex: 11,
                    pointerEvents: 'auto',
                    userSelect: 'none',
                    WebkitUserSelect: 'none'
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
                  <div 
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '50%',
                      background: rewardSort 
                        ? 'rgba(255, 255, 255, 0.2)' 
                        : '#fef3c7',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '16px',
                      pointerEvents: 'none'
                    }}
                  >
                    💰
                  </div>
                  <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: '6px', pointerEvents: 'none' }}>
                    <div style={{ fontSize: '14px', fontWeight: '600' }}>
                      {rewardSort === 'desc' ? t('tasks.sorting.rewardDesc') : 
                       rewardSort === 'asc' ? t('tasks.sorting.rewardAsc') : t('tasks.sorting.rewardSort')}
                    </div>
                    <div style={{
                      color: rewardSort ? '#ffffff' : '#9ca3af',
                      fontSize: '12px',
                      transition: 'color 0.3s ease',
                      transform: showRewardDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                      display: 'flex',
                      alignItems: 'center'
                    }}>
                      ▼
                    </div>
                  </div>
                </div>
                
                {/* 自定义下拉菜单 */}
                {showRewardDropdown && (
                  <div 
                    className="custom-dropdown-content show" 
                    onClick={(e) => {
                      // 如果点击的是容器本身（不是子元素），才阻止冒泡
                      if (e.target === e.currentTarget) {
                        console.log('[Tasks] ========== 点击金额排序下拉菜单容器 ==========');
                        e.stopPropagation();
                      }
                    }}
                    onMouseDown={(e) => {
                      // 如果点击的是容器本身（不是子元素），才阻止冒泡
                      if (e.target === e.currentTarget) {
                        console.log('[Tasks] 金额排序下拉菜单容器 onMouseDown');
                        e.stopPropagation();
                      }
                    }}
                    style={{
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
                      width: 'auto',
                      minWidth: '120px',
                      maxWidth: '160px'
                    }}>
                    <div 
                      className={`custom-dropdown-item ${rewardSort === 'desc' ? 'selected' : ''}`}
                      onClick={(e) => {
                        console.log('[Tasks] ========== 点击金额排序降序选项 ==========');
                        e.stopPropagation();
                        e.preventDefault();
                        console.log('[Tasks] 调用 handleRewardSortChange("desc")');
                        handleRewardSortChange('desc');
                        console.log('[Tasks] 关闭下拉菜单');
                        setShowRewardDropdown(false);
                      }}
                      onMouseDown={(e) => {
                        e.stopPropagation();
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
                      onClick={(e) => {
                        console.log('[Tasks] ========== 点击金额排序升序选项 ==========');
                        e.stopPropagation();
                        e.preventDefault();
                        console.log('[Tasks] 调用 handleRewardSortChange("asc")');
                        handleRewardSortChange('asc');
                        console.log('[Tasks] 关闭下拉菜单');
                        setShowRewardDropdown(false);
                      }}
                      onMouseDown={(e) => {
                        e.stopPropagation();
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
              <div 
                className="deadline-dropdown-container" 
                style={{ position: 'relative', zIndex: 10 }}
                ref={(el) => {
                  if (el) {
                    console.log('[Tasks] 截止时间排序容器已渲染:', el);
                  }
                }}
              >
                <div
                  onClick={(e) => {
                    console.log('[Tasks] ========== 点击截止时间排序按钮 ==========');
                    console.log('[Tasks] 当前 showDeadlineDropdown:', showDeadlineDropdown);
                    console.log('[Tasks] 事件对象:', e);
                    e.stopPropagation();
                    const newValue = !showDeadlineDropdown;
                    console.log('[Tasks] 设置 showDeadlineDropdown 为:', newValue);
                    setShowDeadlineDropdown(newValue);
                    console.log('[Tasks] showDeadlineDropdown 已更新');
                  }}
                  onMouseDown={(e) => {
                    console.log('[Tasks] 截止时间排序按钮 onMouseDown');
                    e.stopPropagation();
                  }}
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
                    minWidth: '160px',
                    position: 'relative',
                    zIndex: 11,
                    pointerEvents: 'auto',
                    userSelect: 'none',
                    WebkitUserSelect: 'none'
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
                  <div 
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '50%',
                      background: deadlineSort 
                        ? 'rgba(255, 255, 255, 0.2)' 
                        : '#fef3c7',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '16px',
                      pointerEvents: 'none'
                    }}
                  >
                    ⏰
                  </div>
                  <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: '6px', pointerEvents: 'none' }}>
                    <div style={{ fontSize: '14px', fontWeight: '600' }}>
                      {deadlineSort === 'asc' ? t('tasks.sorting.deadlineAsc') : 
                       deadlineSort === 'desc' ? t('tasks.sorting.deadlineDesc') : t('tasks.sorting.deadlineSort')}
                    </div>
                    <div style={{
                      color: deadlineSort ? '#ffffff' : '#9ca3af',
                      fontSize: '12px',
                      transition: 'color 0.3s ease',
                      transform: showDeadlineDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                      display: 'flex',
                      alignItems: 'center'
                    }}>
                      ▼
                    </div>
                  </div>
                </div>
                
                {/* 自定义下拉菜单 */}
                {showDeadlineDropdown && (
                  <div 
                    className="custom-dropdown-content show" 
                    onClick={(e) => {
                      // 如果点击的是容器本身（不是子元素），才阻止冒泡
                      if (e.target === e.currentTarget) {
                        console.log('[Tasks] ========== 点击截止时间排序下拉菜单容器 ==========');
                        e.stopPropagation();
                      }
                    }}
                    onMouseDown={(e) => {
                      // 如果点击的是容器本身（不是子元素），才阻止冒泡
                      if (e.target === e.currentTarget) {
                        console.log('[Tasks] 截止时间排序下拉菜单容器 onMouseDown');
                        e.stopPropagation();
                      }
                    }}
                    style={{
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
                      width: 'auto',
                      minWidth: '120px',
                      maxWidth: '160px'
                    }}>
                    <div 
                      className={`custom-dropdown-item ${deadlineSort === 'asc' ? 'selected' : ''}`}
                      onClick={(e) => {
                        console.log('[Tasks] ========== 点击截止时间排序升序选项 ==========');
                        e.stopPropagation();
                        e.preventDefault();
                        console.log('[Tasks] 调用 handleDeadlineSortChange("asc")');
                        handleDeadlineSortChange('asc');
                        console.log('[Tasks] 关闭下拉菜单');
                        setShowDeadlineDropdown(false);
                      }}
                      onMouseDown={(e) => {
                        e.stopPropagation();
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
                      onClick={(e) => {
                        console.log('[Tasks] ========== 点击截止时间排序降序选项 ==========');
                        e.stopPropagation();
                        e.preventDefault();
                        console.log('[Tasks] 调用 handleDeadlineSortChange("desc")');
                        handleDeadlineSortChange('desc');
                        console.log('[Tasks] 关闭下拉菜单');
                        setShowDeadlineDropdown(false);
                      }}
                      onMouseDown={(e) => {
                        e.stopPropagation();
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
              {t('tasks.search.found')} <span style={{ color: '#3b82f6', fontWeight: '600' }}>{total}</span> {t('tasks.search.tasks')}
              {debouncedKeyword && (
                <span style={{ color: '#9ca3af', marginLeft: '8px' }}>
                  ({t('tasks.search.total')} {tasks.length} {t('tasks.search.tasks')})
                </span>
              )}
            </div>
          </div>


          {/* 任务列表 */}
          <div className="tasks-grid" style={{
            display: 'grid',
            gridTemplateColumns: `repeat(auto-fill, minmax(${isMobile ? '170px' : '300px'}, 1fr))`,
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
                  onClick={() => handleViewTask(task.id)}
                >
                  {/* 任务图片区域 */}
                  <div style={{
                    aspectRatio: isMobile ? '9 / 16' : '16 / 9',
                    width: '100%',
                    position: 'relative',
                    overflow: 'hidden',
                    background: `linear-gradient(135deg, ${getTaskLevelColor(task.task_level)}20, ${getTaskLevelColor(task.task_level)}40)`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}>
                    {/* 任务类型图标占位符 - 仅在没有图片时显示 */}
                    {(!task.images || !Array.isArray(task.images) || task.images.length === 0 || !task.images[0]) && (
                      <div 
                        className={`task-icon-placeholder-${task.id}`}
                        style={{
                          position: 'absolute',
                          top: 0,
                          left: 0,
                          width: '100%',
                          height: '100%',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          zIndex: 0,
                          pointerEvents: 'none'
                        }}>
                        <div style={{
                          fontSize: isMobile ? '48px' : '64px',
                          opacity: 0.6,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          {['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'][TASK_TYPES.indexOf(task.task_type) % 10]}
                        </div>
                      </div>
                    )}
                    
                    {/* 如果有任务图片，显示图片 */}
                    {task.images && Array.isArray(task.images) && task.images.length > 0 && task.images[0] && (
                      <img
                        key={`task-img-${task.id}-${String(task.images[0])}`}
                        src={String(task.images[0])}
                        alt={task.title}
                        style={{
                          position: 'absolute',
                          top: 0,
                          left: 0,
                          width: '100%',
                          height: '100%',
                          objectFit: 'cover',
                          zIndex: 1,
                          backgroundColor: 'transparent',
                          display: 'block'
                        }}
                        loading="lazy"
                        onLoad={(e) => {
                          // 图片加载成功，确保占位符图标隐藏
                          const placeholder = e.currentTarget.parentElement?.querySelector(`.task-icon-placeholder-${task.id}`) as HTMLElement;
                          if (placeholder) {
                            placeholder.style.display = 'none';
                          }
                        }}
                        onError={(e) => {
                          // 图片加载失败，隐藏图片并显示占位符图标
                          e.currentTarget.style.display = 'none';
                          const placeholder = e.currentTarget.parentElement?.querySelector(`.task-icon-placeholder-${task.id}`) as HTMLElement;
                          if (!placeholder) {
                            // 如果占位符不存在，创建一个
                            const placeholderDiv = document.createElement('div');
                            placeholderDiv.className = `task-icon-placeholder-${task.id}`;
                            placeholderDiv.style.cssText = `
                              position: absolute;
                              top: 0;
                              left: 0;
                              width: 100%;
                              height: 100%;
                              display: flex;
                              align-items: center;
                              justify-content: center;
                              z-index: 0;
                              pointer-events: none;
                            `;
                            placeholderDiv.innerHTML = `
                              <div style="font-size: ${isMobile ? '48px' : '64px'}; opacity: 0.6; display: flex; align-items: center; justify-content: center;">
                                ${['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'][TASK_TYPES.indexOf(task.task_type) % 10]}
                              </div>
                            `;
                            e.currentTarget.parentElement?.appendChild(placeholderDiv);
                          } else {
                            placeholder.style.display = 'flex';
                          }
                        }}
                      />
                    )}
                    
                    {/* 图片遮罩层，确保文字清晰可读 - 放在图片之上 */}
                    <div style={{
                      position: 'absolute',
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      background: task.images && Array.isArray(task.images) && task.images.length > 0 && task.images[0]
                        ? 'linear-gradient(to bottom, rgba(0,0,0,0.3) 0%, rgba(0,0,0,0.1) 50%, rgba(0,0,0,0.5) 100%)'
                        : 'transparent',
                      zIndex: 2,
                      pointerEvents: 'none'
                    }} />

                    {/* 地点 - 左上角 */}
                    <div style={{
                      position: 'absolute',
                      top: isMobile ? '8px' : '12px',
                      left: isMobile ? '8px' : '12px',
                      background: 'rgba(0, 0, 0, 0.6)',
                      backdropFilter: 'blur(4px)',
                      color: '#fff',
                      padding: isMobile ? '4px 8px' : '6px 12px',
                      borderRadius: '20px',
                      fontSize: isMobile ? '10px' : '12px',
                      fontWeight: '600',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                      zIndex: 3,
                      boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
                      maxWidth: isMobile ? 'calc(50% - 16px)' : 'auto'
                    }}>
                      <span>{task.location === 'Online' ? '🌐' : '📍'}</span>
                      <span style={{
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis'
                      }}>{task.location}</span>
                    </div>

                    {/* 任务类型 - 右上角 */}
                    <div style={{
                      position: 'absolute',
                      top: isMobile ? '8px' : '12px',
                      right: isMobile ? '8px' : '12px',
                      background: 'rgba(0, 0, 0, 0.6)',
                      backdropFilter: 'blur(4px)',
                      color: '#fff',
                      padding: isMobile ? '4px 8px' : '6px 12px',
                      borderRadius: '20px',
                      fontSize: isMobile ? '10px' : '12px',
                      fontWeight: '600',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                      zIndex: 3,
                      boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
                      maxWidth: isMobile ? 'calc(50% - 16px)' : 'auto'
                    }}>
                      <span>🏷️</span>
                      <span style={{
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis'
                      }}>{getTaskTypeLabel(task.task_type)}</span>
                    </div>

                    {/* 金额 - 右下角 */}
                    <div style={{
                      position: 'absolute',
                      bottom: isMobile ? '8px' : '12px',
                      right: isMobile ? '8px' : '12px',
                      background: 'rgba(5, 150, 105, 0.9)',
                      backdropFilter: 'blur(4px)',
                      color: '#fff',
                      padding: isMobile ? '6px 10px' : '8px 14px',
                      borderRadius: '20px',
                      fontSize: isMobile ? '14px' : '18px',
                      fontWeight: '700',
                      zIndex: 3,
                      boxShadow: '0 2px 12px rgba(5, 150, 105, 0.4)'
                    }}>
                      £{((task.base_reward ?? task.reward) || 0).toFixed(2)}
                    </div>

                    {/* 截止时间 - 左下角 */}
                    <div style={{
                      position: 'absolute',
                      bottom: isMobile ? '8px' : '12px',
                      left: isMobile ? '8px' : '12px',
                      background: 'rgba(0, 0, 0, 0.6)',
                      backdropFilter: 'blur(4px)',
                      color: isExpired(task.deadline) ? '#fca5a5' : 
                             isExpiringSoon(task.deadline) ? '#fde68a' : '#fff',
                      padding: isMobile ? '4px 8px' : '6px 12px',
                      borderRadius: '20px',
                      fontSize: isMobile ? '9px' : '11px',
                      fontWeight: '600',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                      zIndex: 3,
                      boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
                      maxWidth: isMobile ? 'calc(50% - 16px)' : 'auto'
                    }}>
                      <span>⏰</span>
                      <span style={{
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis'
                      }}>
                        {isExpired(task.deadline) ? t('home.taskExpired') : 
                         isExpiringSoon(task.deadline) ? t('home.taskExpiringSoon') : getRemainTime(task.deadline, t)}
                      </span>
                    </div>

                    {/* 任务等级标签 - 右上角，在任务类型下方 */}
                    {task.task_level && task.task_level !== 'normal' && (
                      <div style={{
                        position: 'absolute',
                        top: isMobile ? '42px' : '48px',
                        right: isMobile ? '8px' : '12px',
                        background: getTaskLevelColor(task.task_level),
                        color: '#fff',
                        padding: isMobile ? '3px 8px' : '4px 10px',
                        borderRadius: '16px',
                        fontSize: isMobile ? '9px' : '11px',
                        fontWeight: '700',
                        zIndex: 3,
                        boxShadow: task.task_level === 'vip' ? '0 2px 8px rgba(245, 158, 11, 0.4)' : 
                                  task.task_level === 'super' ? '0 2px 10px rgba(139, 92, 246, 0.5)' : 
                                  '0 2px 6px rgba(0,0,0,0.2)'
                      }}>
                        {getTaskLevelLabel(task.task_level)}
                      </div>
                    )}
                  </div>
                  
                  {/* 任务标题 - 放在图片下面 */}
                  <div style={{
                    padding: '12px',
                    fontSize: '15px',
                    fontWeight: '600',
                    color: '#1f2937',
                    whiteSpace: isMobile ? 'nowrap' : 'normal',
                    overflow: 'hidden',
                    textOverflow: isMobile ? 'ellipsis' : 'ellipsis',
                    lineHeight: '1.4',
                    background: 'transparent',
                    display: isMobile ? 'block' : '-webkit-box',
                    WebkitLineClamp: isMobile ? 1 : 2,
                    WebkitBoxOrient: isMobile ? 'unset' : 'vertical'
                  }}>
                    <TaskTitle
                      title={task.title}
                      language={language}
                      style={{
                        fontSize: 'inherit',
                        fontWeight: 'inherit',
                        color: 'inherit',
                        whiteSpace: isMobile ? 'nowrap' : 'normal',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        display: isMobile ? 'block' : '-webkit-box',
                        WebkitLineClamp: isMobile ? 1 : 2,
                        WebkitBoxOrient: isMobile ? 'unset' : 'vertical'
                      }}
                    />
                  </div>
                </div>
              ))
            )}
          </div>

          {/* 滚动加载提示 */}
          <div ref={scrollContainerRef}>
            {loadingMore && (
              <div style={{
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                padding: '32px',
                marginTop: '24px'
              }}>
                <div style={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  gap: '12px',
                  color: '#6b7280'
                }}>
                  <div style={{
                    width: '32px',
                    height: '32px',
                    border: '3px solid #e5e7eb',
                    borderTopColor: '#3b82f6',
                    borderRadius: '50%',
                    animation: 'spin 1s linear infinite'
                  }} />
                  <span style={{ fontSize: '14px' }}>
                    {language === 'zh' ? '加载更多任务...' : 'Loading more tasks...'}
                  </span>
                </div>
              </div>
            )}
            
            {!hasMore && tasks.length > 0 && (
              <div style={{
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                padding: '32px',
                marginTop: '24px',
                color: '#9ca3af',
                fontSize: '14px'
              }}>
                {language === 'zh' ? '没有更多任务了' : 'No more tasks'}
              </div>
            )}
          </div>
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
      
      {/* 申请任务弹窗 */}
      {showApplyModal && selectedTaskForApply && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          zIndex: 10000,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '20px'
        }}
        onClick={() => {
          setShowApplyModal(false);
          setSelectedTaskForApply(null);
          setApplyMessage('');
          setNegotiatedPrice(undefined);
        }}
        >
          <div style={{
            background: '#fff',
            borderRadius: '16px',
            padding: '24px',
            maxWidth: '500px',
            width: '100%',
            maxHeight: '90vh',
            overflowY: 'auto',
            boxShadow: '0 20px 60px rgba(0,0,0,0.3)'
          }}
          onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '20px', fontWeight: 600 }}>申请任务</h3>
            
            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'block',
                marginBottom: '8px',
                fontSize: '14px',
                fontWeight: 600,
                color: '#374151'
              }}>
                申请留言（可选）
              </label>
              <textarea
                value={applyMessage}
                onChange={(e) => setApplyMessage(e.target.value)}
                placeholder={t('tasks.apply.applicationMessagePlaceholder')}
                style={{
                  width: '100%',
                  minHeight: '100px',
                  padding: '12px',
                  border: '2px solid #e5e7eb',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontFamily: 'inherit',
                  resize: 'vertical',
                  outline: 'none',
                  transition: 'border-color 0.2s ease'
                }}
                onFocus={(e) => {
                  e.currentTarget.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.borderColor = '#e5e7eb';
                }}
              />
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '14px',
                fontWeight: 600,
                color: '#374151',
                cursor: 'pointer'
              }}>
                <input
                  type="checkbox"
                  checked={isNegotiateChecked}
                  onChange={(e) => {
                    setIsNegotiateChecked(e.target.checked);
                    if (e.target.checked) {
                      // 如果勾选，设置默认值为任务金额
                      const task = tasks.find(t => t.id === selectedTaskForApply);
                      const defaultPrice = task?.agreed_reward ?? task?.base_reward ?? task?.reward;
                      setNegotiatedPrice(defaultPrice);
                    } else {
                      setNegotiatedPrice(undefined);
                    }
                  }}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span>{t('tasks.apply.wantToNegotiate')}</span>
              </label>
              
              {isNegotiateChecked && (
              <div style={{ marginTop: '12px' }}>
                <label style={{
                  display: 'block',
                  marginBottom: '8px',
                  fontSize: '14px',
                  fontWeight: 600,
                  color: '#374151'
                }}>
                  {t('tasks.apply.negotiationAmount')}
                </label>
                <input
                  type="number"
                  value={negotiatedPrice !== undefined ? negotiatedPrice : ''}
                  onChange={(e) => {
                    const value = e.target.value ? parseFloat(e.target.value) : undefined;
                    setNegotiatedPrice(value);
                  }}
                  placeholder={t('tasks.apply.negotiationAmountPlaceholder')}
                  min="0.01"
                  step="0.01"
                  style={{
                    width: '100%',
                    padding: '12px',
                    border: '2px solid #e5e7eb',
                    borderRadius: '8px',
                    fontSize: '14px',
                    outline: 'none',
                    transition: 'border-color 0.2s ease'
                  }}
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '#e5e7eb';
                  }}
                />
              </div>
              )}
            </div>

            <div style={{
              display: 'flex',
              gap: '12px',
              justifyContent: 'flex-end'
            }}>
              <button
                onClick={() => {
                  setShowApplyModal(false);
                  setSelectedTaskForApply(null);
                  setApplyMessage('');
                  setNegotiatedPrice(undefined);
                }}
                style={{
                  padding: '12px 24px',
                  background: '#f3f4f6',
                  color: '#374151',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#e5e7eb';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f3f4f6';
                }}
              >
                {t('tasks.apply.cancel')}
              </button>
              <button
                onClick={handleSubmitApplication}
                style={{
                  padding: '12px 24px',
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-1px)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = 'none';
                }}
              >
                {t('tasks.apply.submitApplication')}
              </button>
            </div>
          </div>
        </div>
      )}
      
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
              flex-direction: row !important;
              gap: 8px !important;
              width: 100% !important;
            }
            
            .sort-controls > div {
              flex: 1 !important;
              min-width: 0 !important;
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
              top: auto !important;
              left: auto !important;
              right: auto !important;
              width: auto !important;
              max-width: 200px !important;
              z-index: 99999 !important;
              margin-top: 0 !important;
              box-shadow: 0 8px 25px rgba(0,0,0,0.15) !important;
              border-radius: 12px !important;
              max-height: 60vh !important;
              overflow-y: auto !important;
              overflow-x: hidden !important;
              box-sizing: border-box !important;
            }
            
            /* 确保滚动条在容器内部 */
            .location-dropdown::-webkit-scrollbar {
              width: 8px !important;
            }
            
            .location-dropdown::-webkit-scrollbar-track {
              background: transparent !important;
              border-radius: 0 8px 8px 0 !important;
            }
            
            .location-dropdown::-webkit-scrollbar-thumb {
              background: #d1d5db !important;
              border-radius: 4px !important;
            }
            
            .location-dropdown::-webkit-scrollbar-thumb:hover {
              background: #9ca3af !important;
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
              bottom: 2px !important;
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
            
            .category-section {
              padding: 4px 4px !important;
              margin-bottom: 12px !important;
            }
            
            .category-icons {
              padding-bottom: 4px !important;
            }
            
            .category-icons > div {
              min-width: 80px !important;
              max-width: 100px !important;
              flex-shrink: 0 !important;
              padding: 8px 6px !important;
              gap: 8px !important;
            }
            
            .category-icons > div > div,
            .category-icon-circle {
              width: 50px !important;
              height: 50px !important;
            }
            
            .category-icon-circle {
              font-size: 45px !important;
            }
            
            .category-icons > div > div {
              font-size: 45px !important;
            }
            
            .category-icons span {
              font-size: 12px !important;
              font-weight: 600 !important;
              line-height: 1.3 !important;
            }
            
            /* 调整类别图标容器大小 */
            .category-icons > div {
              min-width: 70px !important;
              max-width: 85px !important;
              padding: 6px 4px !important;
            }
            
            /* 排序按钮移动端优化 - 两行两列布局 */
            .sort-controls {
              display: grid !important;
              grid-template-columns: 1fr 1fr !important;
              grid-template-rows: auto auto !important;
              gap: 8px !important;
            }
            
            /* 第一行：等级选择和最新发布 */
            .level-dropdown-container {
              grid-column: 1 !important;
              grid-row: 1 !important;
            }
            
            .sort-controls > div:not(.level-dropdown-container):not(.reward-dropdown-container):not(.deadline-dropdown-container) {
              grid-column: 2 !important;
              grid-row: 1 !important;
            }
            
            /* 第二行：金额排序和截止时间排序 */
            .reward-dropdown-container {
              grid-column: 1 !important;
              grid-row: 2 !important;
            }
            
            .deadline-dropdown-container {
              grid-column: 2 !important;
              grid-row: 2 !important;
            }
            
            /* 所有按钮在移动端自适应宽度 */
            .sort-controls > div {
              flex: 1 !important;
              min-width: 0 !important;
              max-width: none !important;
            }
            
            /* 下拉容器内部的按钮变成方块 */
            .reward-dropdown-container > div:first-child,
            .deadline-dropdown-container > div:first-child {
              padding: 10px 8px !important;
              flex-direction: column !important;
              align-items: center !important;
              justify-content: center !important;
              text-align: center !important;
              gap: 6px !important;
              min-height: 80px !important;
              height: auto !important;
              width: 100% !important;
              min-width: 0 !important;
              pointer-events: auto !important;
              cursor: pointer !important;
              position: relative !important;
              z-index: 12 !important;
            }
            
            /* Latest 按钮（非下拉容器）也变成方块 */
            .sort-controls > div:not(.level-dropdown-container):not(.reward-dropdown-container):not(.deadline-dropdown-container) {
              padding: 10px 8px !important;
              flex-direction: column !important;
              align-items: center !important;
              justify-content: center !important;
              text-align: center !important;
              gap: 6px !important;
              min-height: 80px !important;
              height: auto !important;
            }
            
            /* 图标在移动端放大显示 */
            .sort-controls > div:not(.level-dropdown-container):not(.reward-dropdown-container):not(.deadline-dropdown-container) > div:first-child,
            .reward-dropdown-container > div:first-child > div:first-child,
            .deadline-dropdown-container > div:first-child > div:first-child {
              width: 40px !important;
              height: 40px !important;
              font-size: 24px !important;
            }
            
            /* 等级选择图标也放大 */
            .level-dropdown-container > div:first-child > div:first-child {
              width: 40px !important;
              height: 40px !important;
              font-size: 24px !important;
            }
            
            /* 文字在移动端显示 */
            .sort-controls > div:not(.level-dropdown-container):not(.reward-dropdown-container):not(.deadline-dropdown-container) > div:last-child {
              display: flex !important;
              flex-direction: column !important;
              align-items: center !important;
              gap: 2px !important;
            }
            
            /* 金额排序和截止时间排序：文本和箭头在同一行 */
            .reward-dropdown-container > div:first-child > div:nth-child(2),
            .deadline-dropdown-container > div:first-child > div:nth-child(2) {
              display: flex !important;
              flex-direction: row !important;
              align-items: center !important;
              gap: 6px !important;
            }
            
            .sort-controls > div:not(.level-dropdown-container):not(.reward-dropdown-container):not(.deadline-dropdown-container) > div:last-child > div:first-child,
            .reward-dropdown-container > div:first-child > div:nth-child(2) > div:first-child,
            .deadline-dropdown-container > div:first-child > div:nth-child(2) > div:first-child {
              font-size: 12px !important;
              font-weight: 600 !important;
              white-space: nowrap !important;
            }
            
            .sort-controls > div:not(.level-dropdown-container):not(.reward-dropdown-container):not(.deadline-dropdown-container) > div:last-child > div:last-child,
            .reward-dropdown-container > div:first-child > div:nth-child(2) > div:last-child,
            .deadline-dropdown-container > div:first-child > div:nth-child(2) > div:last-child {
              font-size: 9px !important;
              opacity: 0.8 !important;
              white-space: nowrap !important;
            }
            
            /* 下拉箭头在移动端显示 */
            .reward-dropdown-container > div:first-child > div:last-child,
            .deadline-dropdown-container > div:first-child > div:last-child {
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
            }
            
            /* 任务等级下拉菜单在移动端保持原样或调整 */
            .level-dropdown-container {
              flex: 1 !important;
              min-width: 0 !important;
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
              min-width: 70px !important;
              max-width: 85px !important;
              padding: 6px 4px !important;
            }
            
            .category-icons > div > div,
            .category-icon-circle {
              width: 50px !important;
              height: 50px !important;
            }
            
            .category-icon-circle {
              font-size: 45px !important;
            }
            
            .category-icons > div > div {
              font-size: 45px !important;
            }
            
            .category-icons span {
              font-size: 12px !important;
              font-weight: 600 !important;
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
              min-width: 70px !important;
              max-width: 85px !important;
              padding: 6px 4px !important;
            }
            
            .category-icons > div > div,
            .category-icon-circle {
              width: 50px !important;
              height: 50px !important;
            }
            
            .category-icon-circle {
              font-size: 45px !important;
            }
            
            .category-icons > div > div {
              font-size: 45px !important;
            }
            
            .category-icons span {
              font-size: 12px !important;
              font-weight: 600 !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default Tasks;
