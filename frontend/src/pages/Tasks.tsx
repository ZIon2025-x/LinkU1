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
import TaskCard from '../components/TaskCard';
import SortControls from '../components/SortControls';
import CategoryIcons from '../components/CategoryIcons';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import SEOHead from '../components/SEOHead';
import { useLanguage } from '../contexts/LanguageContext';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import { useTaskFilters } from '../hooks/useTaskFilters';
import WebSocketManager from '../utils/WebSocketManager';
import { WS_BASE_URL } from '../config';
import { useTaskSorting } from '../hooks/useTaskSorting';
import { useThrottledCallback } from '../hooks/useThrottledCallback';
import { Grid, GridImperativeAPI } from 'react-window';
import { injectTasksStyles } from '../styles/Tasks.styles';
import styles from './Tasks.module.css';

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
  
  // 注入样式（只需调用一次）
  useEffect(() => {
    injectTasksStyles();
  }, []);
  
  // 获取翻译后的任务类型名称
  const getTaskTypeLabel = useCallback((taskType: string): string => {
    return t(`publishTask.taskTypes.${taskType}`) || taskType;
  }, [t]);
  
  // 使用筛选 hook
  const filters = useTaskFilters(t('tasks.levels.all'));
  
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const locationDropdownRef = useRef<HTMLDivElement | null>(null);
  const locationButtonRef = useRef<HTMLDivElement | null>(null);
  const [page, setPage] = useState(1);
  const [pageSize] = useState(12);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const [user, setUser] = useState<any>(null);
  const [showLevelDropdown, setShowLevelDropdown] = useState(false);
  
  // 先定义 loadTasks，但需要稍后使用 sorting hook
  // 使用 ref 来存储 sortBy，避免循环依赖
  const sortByRef = useRef('latest');
  
  // 加载任务列表 - 使用缓存和防抖优化
  const loadTasks = useCallback(async (isLoadMore = false, targetPage?: number, overrideSortBy?: string) => {
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
      const searchKeyword = filters.debouncedKeyword.trim() || filters.keyword.trim() || undefined;
      // 如果是加载更多，使用传入的页码或当前页码+1
      const currentPage = isLoadMore ? (targetPage ?? page + 1) : 1;
      
      // 使用传入的排序值，如果没有则使用 ref 中的最新值（避免闭包问题）
      const currentSortBy = overrideSortBy !== undefined ? overrideSortBy : (sortByRef.current || 'latest');
      
      const data = await fetchTasks({
        type: filters.type !== 'all' ? filters.type : undefined,
        city: filters.city !== 'all' ? filters.city : undefined,
        keyword: searchKeyword,
        page: currentPage,
        pageSize: pageSize,
        sort_by: currentSortBy  // 使用计算后的排序值
      });
      
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
  }, [page, pageSize, filters.type, filters.city, filters.debouncedKeyword, filters.keyword]);
  
  // 使用排序 hook
  const sorting = useTaskSorting(loadTasks);
  
  // 同步 sorting.sortByRef 到 sortByRef
  useEffect(() => {
    sortByRef.current = sorting.sortByRef.current;
  }, [sorting.sortByRef.current]);
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
    const handleClickOutside = (event: MouseEvent | TouchEvent) => {
      const target = event.target as HTMLElement;
      if (showLocationDropdown && !target.closest('[data-location-dropdown]')) {
        setShowLocationDropdown(false);
      }
    };

    if (showLocationDropdown) {
      document.addEventListener('mousedown', handleClickOutside);
      document.addEventListener('touchstart', handleClickOutside);
      
      // 移动端计算下拉菜单位置
      if (isMobile && locationDropdownRef.current && locationButtonRef.current) {
        const updatePosition = () => {
          const buttonRect = locationButtonRef.current!.getBoundingClientRect();
          const dropdown = locationDropdownRef.current!;
          const viewportHeight = window.innerHeight;
          const viewportWidth = window.innerWidth;
          const dropdownHeight = 400; // 预估高度
          
          // 计算下拉菜单应该显示的位置
          let top = buttonRect.bottom + 4;
          let left = buttonRect.left;
          
          // 如果下拉菜单会超出视口底部，则显示在按钮上方
          if (top + dropdownHeight > viewportHeight) {
            top = buttonRect.top - dropdownHeight - 4;
            // 确保不会超出视口顶部
            if (top < 0) {
              top = 8;
              dropdown.style.maxHeight = `${viewportHeight - top - 8}px`;
            }
          }
          
          // 计算下拉菜单宽度（使用按钮宽度，但最大180px）
          const buttonWidth = buttonRect.width;
          const dropdownWidth = Math.min(Math.max(buttonWidth, 160), 180);
          
          // 确保下拉菜单不会超出视口右侧
          if (left + dropdownWidth > viewportWidth - 16) {
            left = viewportWidth - dropdownWidth - 16;
          }
          // 确保不会超出视口左侧
          if (left < 16) {
            left = 16;
          }
          
          dropdown.style.top = `${top}px`;
          dropdown.style.left = `${left}px`;
          dropdown.style.width = `${dropdownWidth}px`;
        };
        
        // 立即更新位置
        updatePosition();
        
        // 监听窗口大小变化和滚动，重新计算位置
        window.addEventListener('resize', updatePosition);
        window.addEventListener('scroll', updatePosition, true);
        
        return () => {
          window.removeEventListener('resize', updatePosition);
          window.removeEventListener('scroll', updatePosition, true);
        };
      }
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('touchstart', handleClickOutside);
    };
  }, [showLocationDropdown, isMobile]);


  // 处理任务等级变化（使用 filters hook 的 handleLevelChange）
  const handleLevelChangeWrapper = (newLevel: string): string => {
    filters.handleLevelChange(newLevel);
    setShowLevelDropdown(false);
    return newLevel;
  };

  // 处理城市选择变化
  const handleLocationChange = (newCity: string) => {
    filters.setCity(newCity); // 更新城市筛选状态
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
            filters.setCity(residenceCity);
            setUserLocation(residenceCity);
            filters.setCityInitialized(true); // 标记城市已初始化
          } else if (userData.location) {
            // 兼容旧的位置字段
            setUserLocation(userData.location);
            filters.setCityInitialized(true); // 即使没有常住城市，也标记为已初始化
          } else {
            // 用户没有设置常住城市，保持'all'，但也标记为已初始化
            filters.setCityInitialized(true);
          }
        } else {
          // 用户未登录，标记为已初始化（保持默认'all'）
          filters.setCityInitialized(true);
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
        filters.setCityInitialized(true); // 即使加载失败，也标记为已初始化，避免无限等待
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

  // WebSocket实时更新通知（监听notification_created事件）
  useEffect(() => {
    if (!user) return;

    // 初始化WebSocket管理器
    WebSocketManager.initialize(WS_BASE_URL);
    WebSocketManager.connect(user.id);

    // 订阅WebSocket消息
    const unsubscribe = WebSocketManager.subscribe((msg) => {
      // 处理通知创建事件
      if (msg.type === 'notification_created') {
        // 立即刷新未读通知数量
        getUnreadNotificationCount().then(count => {
          setUnreadCount(count);
        }).catch(error => {
          console.error('更新未读通知数量失败:', error);
        });

        // 如果通知面板已打开，刷新通知列表
        if (showNotifications) {
          getNotificationsWithRecentRead(10).then(notificationsData => {
            setNotifications(notificationsData);
          }).catch(error => {
            console.error('刷新通知列表失败:', error);
          });
        }
      }
    });

    return () => {
      unsubscribe();
      // 注意：不断开连接，因为可能其他组件也在使用
    };
  }, [user, showNotifications]);

  // 设置滑动提示文本的双语化CSS变量
  useEffect(() => {
    const swipeText = `← ${t('tasks.swipeToSeeMore')} →`;
    document.documentElement.style.setProperty('--swipe-text', `'${swipeText}'`);
    
    return () => {
      document.documentElement.style.removeProperty('--swipe-text');
    };
  }, [t]);

  // 注意：sortBy, rewardSort, deadlineSort 不包含在依赖项中
  // 因为排序变化通过 overrideSortBy 参数传递，不需要依赖这些状态
  
  // 加载更多任务
  const loadMoreTasks = useCallback(() => {
    if (!loadingMore && !loading && hasMore) {
      loadTasks(true);
    }
  }, [loadingMore, loading, hasMore, loadTasks]);

  // 使用 useRef 保存 loadTasks 的引用，避免在 useEffect 中依赖它
  const loadTasksRef = useRef(loadTasks);
  useEffect(() => {
    loadTasksRef.current = loadTasks;
  }, [loadTasks]);

  useEffect(() => {
    // 只有当城市已初始化后才加载任务，避免初始加载时使用错误的城市筛选
    // 使用 debouncedKeyword 触发搜索，避免频繁请求
    // 注意：sortBy 变化由 handleRewardSortChange、handleDeadlineSortChange 和"最新"按钮直接处理，不在这里触发
    if (filters.cityInitialized) {
      // 使用 ref 来调用，避免依赖 loadTasks 导致循环
      loadTasksRef.current(false); // 初始加载，不是加载更多
    }
  }, [filters.type, filters.city, filters.debouncedKeyword, filters.cityInitialized]); // 移除 loadTasks 依赖，使用 ref 避免循环触发
  
  // 使用 useMemo 优化任务筛选逻辑，避免不必要的重新计算
  // 注意：需要在 handleScroll 之前定义，因为虚拟滚动相关变量会使用它
  const filteredTasks = useMemo(() => {
    let filtered = [...tasks];

    // 按任务等级筛选
    if (filters.taskLevel !== t('tasks.levels.all')) {
      const levelMap: { [key: string]: string } = {
        [t('tasks.levels.normal')]: 'normal',
        [t('tasks.levels.vip')]: 'vip',
        [t('tasks.levels.super')]: 'super'
      };
      
      const targetLevel = levelMap[filters.taskLevel];
      if (targetLevel) {
        filtered = filtered.filter(task => task.task_level === targetLevel);
      }
    }

    // 按城市筛选
    if (filters.city !== 'all') {
      filtered = filtered.filter(task => task.location === filters.city);
    }

    // 按类型筛选
    if (filters.type !== 'all') {
      filtered = filtered.filter(task => task.task_type === filters.type);
    }

    // 注意：搜索关键词已经在服务端处理，这里不需要再次过滤
    // 如果服务端返回了搜索结果，说明已经匹配了标题和描述
    // 客户端过滤会导致搜索结果不准确，因为只过滤了已加载的任务

    // 注意：排序应该在服务端进行，这里只进行筛选
    // 客户端排序会破坏服务端的分页排序逻辑
    
    return filtered;
  }, [tasks, filters.taskLevel, filters.city, filters.type, filters.debouncedKeyword, t]);

  // 动态判断是否使用虚拟滚动（任务数超过 50 时启用）
  const shouldUseVirtualList = filteredTasks.length > 50;
  
  // 计算任务卡片高度（移动端和桌面端不同）
  // 移动端：卡片更小，约 300px；桌面端：约 400px
  const taskCardHeight = isMobile ? 300 : 400;
  const containerHeight = typeof window !== 'undefined' ? window.innerHeight - 200 : 600; // 减去头部等高度
  
  // 计算网格布局参数
  const cardWidth = isMobile ? 170 : 300; // 卡片最小宽度
  const gap = 16; // 网格间距
  const gridContainerRef = useRef<HTMLDivElement>(null);
  const [columnCount, setColumnCount] = useState(3); // 默认列数
  const [rowCount, setRowCount] = useState(0);
  
  // 计算列数和行数
  useEffect(() => {
    if (!shouldUseVirtualList || !gridContainerRef.current) return;
    
    const updateGridDimensions = () => {
      const container = gridContainerRef.current;
      if (!container) return;
      
      const containerWidth = container.clientWidth;
      // 计算每行能放多少个卡片：(容器宽度 + 间距) / (卡片宽度 + 间距)
      const cols = Math.max(1, Math.floor((containerWidth + gap) / (cardWidth + gap)));
      const rows = Math.ceil(filteredTasks.length / cols);
      
      setColumnCount(cols);
      setRowCount(rows);
    };
    
    updateGridDimensions();
    
    // 监听窗口大小变化
    const resizeObserver = new ResizeObserver(updateGridDimensions);
    if (gridContainerRef.current) {
      resizeObserver.observe(gridContainerRef.current);
    }
    
    return () => {
      resizeObserver.disconnect();
    };
  }, [shouldUseVirtualList, filteredTasks.length, cardWidth, gap, isMobile]);

  // Grid 组件的滚动处理（用于无限滚动）
  const gridRef = useRef<GridImperativeAPI>(null);
  
  // Grid 的滚动事件处理
  const handleGridScroll = useCallback(() => {
    if (loadingMore || loading || !hasMore) return;
    
    const grid = gridRef.current;
    if (!grid || !grid.element) return;
    
    const container = grid.element;
    const scrollTop = container.scrollTop;
    const containerHeight = container.clientHeight;
    const scrollHeight = container.scrollHeight;
    
    // 当滚动到距离底部200px时，开始加载更多
    if (scrollTop + containerHeight >= scrollHeight - 200) {
      loadMoreTasks();
    }
  }, [loadingMore, loading, hasMore]);
  
  // 普通模式的滚动监听
  const handleScroll = useThrottledCallback(() => {
    if (loadingMore || loading || !hasMore) return;
    
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    const windowHeight = window.innerHeight;
    const documentHeight = document.documentElement.scrollHeight;
    
    if (scrollTop + windowHeight >= documentHeight - 200) {
      loadMoreTasks();
    }
  }, 100);

  useEffect(() => {
    if (!shouldUseVirtualList) {
      window.addEventListener('scroll', handleScroll, { passive: true });
      return () => window.removeEventListener('scroll', handleScroll);
    }
  }, [handleScroll, shouldUseVirtualList]);
  
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
      // 需要检查是否点击在下拉菜单容器内，包括下拉菜单项和下拉菜单内容
      if (sorting.showRewardDropdown) {
        const isInsideContainer = target.closest('.reward-dropdown-container');
        const isDropdownContent = target.closest('.custom-dropdown-content');
        const isDropdownItem = target.closest('.custom-dropdown-item');
        // 如果点击在容器外、下拉内容外、且不是菜单项，才关闭菜单
        if (!isInsideContainer && !isDropdownContent && !isDropdownItem) {
          sorting.setShowRewardDropdown(false);
        }
      }
      
      // 检查截止时间排序下拉菜单
      // 需要检查是否点击在下拉菜单容器内，包括下拉菜单项和下拉菜单内容
      if (sorting.showDeadlineDropdown) {
        const isInsideContainer = target.closest('.deadline-dropdown-container');
        const isDropdownContent = target.closest('.custom-dropdown-content');
        const isDropdownItem = target.closest('.custom-dropdown-item');
        // 如果点击在容器外、下拉内容外、且不是菜单项，才关闭菜单
        if (!isInsideContainer && !isDropdownContent && !isDropdownItem) {
          sorting.setShowDeadlineDropdown(false);
        }
      }
      
      // 检查任务等级下拉菜单
      if (showLevelDropdown && !target.closest('.level-dropdown-container')) {
        setShowLevelDropdown(false);
      }
    };

    if (showLocationDropdown || showLanguageDropdown || sorting.showRewardDropdown || sorting.showDeadlineDropdown || showLevelDropdown) {
      // 使用 mousedown 事件，在 click 之前触发
      // 菜单项会在 mousedown 时阻止事件传播，所以不会关闭菜单
      document.addEventListener('mousedown', handleClickOutside);

      return () => {
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [showLocationDropdown, showLanguageDropdown, sorting.showRewardDropdown, sorting.showDeadlineDropdown, showLevelDropdown]);


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
  const handleViewTask = useCallback((taskId: number) => {
    setSelectedTaskId(taskId);
    setShowTaskDetailModal(true);
  }, []);

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
  const getTaskLevelColor = useCallback((taskLevel: string) => {
    switch (taskLevel) {
      case 'super':
        return '#8b5cf6';
      case 'vip':
        return '#f59e0b';
      case 'normal':
      default:
        return '#95a5a6';
    }
  }, []);

  // 获取任务等级标签
  const getTaskLevelLabel = useCallback((taskLevel: string) => {
    switch (taskLevel) {
      case 'super':
        return t('home.superTask');
      case 'vip':
        return t('home.vipTask');
      case 'normal':
      default:
        return t('home.normalTask');
    }
  }, [t]);

  // Grid 单元格渲染函数（必须在所有依赖的函数定义之后）
  const Cell = useCallback(({ columnIndex, rowIndex, style, ...props }: { columnIndex: number; rowIndex: number; style: React.CSSProperties; [key: string]: any }) => {
    const index = rowIndex * columnCount + columnIndex;
    
    if (index >= filteredTasks.length) {
      return <div style={style} />;
    }
    
    const task = filteredTasks[index];
    
    return (
      <div style={{ ...style, padding: `${gap / 2}px` }}>
        <TaskCard
          key={task.id}
          task={task}
          isMobile={isMobile}
          language={language}
          onViewTask={handleViewTask}
          getTaskTypeLabel={getTaskTypeLabel}
          getRemainTime={getRemainTime}
          isExpired={isExpired}
          isExpiringSoon={isExpiringSoon}
          getTaskLevelColor={getTaskLevelColor}
          getTaskLevelLabel={getTaskLevelLabel}
          t={t}
        />
      </div>
    );
  }, [filteredTasks, columnCount, gap, isMobile, language, handleViewTask, getTaskTypeLabel, getRemainTime, isExpired, isExpiringSoon, getTaskLevelColor, getTaskLevelLabel, t]);

  return (
    <div className={styles.pageContainer}>
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
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          {/* Logo和位置信息 */}
          <div className={styles.headerLeft}>
          {/* Logo */}
            <div 
              className={styles.logo}
              onClick={() => navigate('/')}
            >
              Link²Ur
          </div>

          {/* 位置信息 */}
          <div 
            className={styles.locationContainer}
            data-location-dropdown
          >
            <div 
              ref={locationButtonRef}
              onClick={() => setShowLocationDropdown(!showLocationDropdown)}
              className={`${styles.locationButton} ${showLocationDropdown ? styles.locationButtonActive : ''}`}
            >
              <span className={styles.locationIcon}>📍</span>
              <span className={styles.locationText}>
                  {filters.city === 'all' ? t('home.allCities') : userLocation}
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
                className={styles.locationDropdown}
                style={{
                  position: isMobile ? 'fixed' : 'absolute',
                  top: isMobile ? undefined : 'calc(100% + 8px)',
                  left: isMobile ? undefined : '0',
                  zIndex: 99999,
                  maxHeight: isMobile ? '60vh' : '400px'
                }}
                ref={locationDropdownRef}
              >
                <div className={styles.locationDropdownContent}>
                  <div
                    onClick={() => handleLocationChange('all')}
                    className={styles.locationDropdownItem}
                    style={{ fontWeight: '600' }}
                  >
                    {t('home.allCities')}
                  </div>
                  {CITIES.map((cityName) => (
                    <div
                      key={cityName}
                      onClick={() => handleLocationChange(cityName)}
                      className={styles.locationDropdownItem}
                    >
                      {cityName}
                    </div>
                  ))}
                </div>
              </div>
            )}
            </div>
          </div>

          {/* 通知按钮和汉堡菜单 */}
          <div className={styles.headerRight}>
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
      <div className={styles.mainContent}>
        {/* 浮空双语选择按钮 */}
        <div 
          className={`${styles.languageSwitcherContainer} ${isMobile ? styles.languageSwitcherContainerMobile : ''}`}
          style={{
            right: isMobile ? '16px' : 'max(16px, calc((100vw - 1200px) / 2 + 16px))'
          }}
          data-language-dropdown
        >
          <div 
            onClick={() => setShowLanguageDropdown(!showLanguageDropdown)}
            className={`${styles.languageButton} ${showLanguageDropdown ? styles.languageButtonActive : ''}`}
            title={language === 'zh' ? 'English' : '中文'}
          >
            <span style={{ fontSize: '24px' }}>🌐</span>
          </div>
          
          {/* 语言选择下拉菜单 */}
          {showLanguageDropdown && (
            <div className={styles.languageDropdown}>
              <div
                onClick={() => {
                  setLanguage('zh', navigateRaw);
                  setShowLanguageDropdown(false);
                }}
                className={`${styles.languageOption} ${language === 'zh' ? styles.languageOptionActive : ''}`}
              >
                中文
              </div>
              <div
                onClick={() => {
                  setLanguage('en', navigateRaw);
                  setShowLanguageDropdown(false);
                }}
                className={`${styles.languageOption} ${language === 'en' ? styles.languageOptionActive : ''}`}
              >
                English
              </div>
            </div>
          )}
        </div>
        
        <div className={styles.contentWrapper}>
          {/* SEO优化：可见的H1标签 */}
          <h1 className={styles.seoH1}>
            任务大厅 - Link²Ur
          </h1>
          {/* 分类图标行 */}
          <div className={styles.categorySection}>
            <CategoryIcons
              taskTypes={TASK_TYPES}
              getTaskTypeLabel={getTaskTypeLabel}
              onTypeClick={filters.setType}
              selectedType={filters.type}
            />
          </div>

          {/* 排序按钮和搜索框行 */}
          <div className={styles.sortSearchSection}>
            {/* 排序控制区域 - 使用 SortControls 组件 */}
            <SortControls
              loadTasks={loadTasks}
              taskLevel={filters.taskLevel}
              showLevelDropdown={showLevelDropdown}
              setShowLevelDropdown={setShowLevelDropdown}
              handleLevelChange={handleLevelChangeWrapper}
              t={t}
            />

            {/* 搜索框区域 */}
            <div className={styles.searchSection}>
              <div className={styles.searchInputContainer}>
                <input
                  type="text"
                  placeholder={t('tasks.search.placeholder')}
                  value={filters.keyword}
                  onChange={(e) => filters.setKeyword(e.target.value)}
                  className={styles.searchInput}
                />
                <div className={styles.searchIcon}>
                  🔍
                </div>
              </div>
            </div>
          </div>

          {/* 自动取消过期任务提示 */}
          <div className={styles.systemNotice}>
            <span className={styles.systemNoticeIcon}>⏰</span>
            <span className={styles.systemNoticeText}>
              {t('tasks.systemNotice')}
            </span>
          </div>

          {/* 任务统计信息 */}
          <div className={styles.taskStats}>
            <div className={styles.taskStatsText}>
              {t('tasks.search.found')} <span className={styles.taskStatsCount}>{total}</span> {t('tasks.search.tasks')}
              {filters.debouncedKeyword && (
                <span className={styles.taskStatsSubtext}>
                  ({t('tasks.search.total')} {tasks.length} {t('tasks.search.tasks')})
                </span>
              )}
            </div>
          </div>


          {/* 任务列表 - 动态使用虚拟滚动 */}
          {loading ? (
            <div className={styles.loadingContainer}>
              <div className={styles.loadingIcon}>⏳</div>
              <div>加载中...</div>
            </div>
          ) : filteredTasks.length === 0 ? (
            <div className={styles.emptyContainer}>
              <div className={styles.emptyIcon}>📝</div>
              <div>
                {tasks.length === 0 ? t('tasks.search.noTasks') : t('tasks.search.noMatchingTasks')}
              </div>
              {tasks.length > 0 && (
                <div className={styles.emptySubtext}>
                  {t('tasks.search.tryAdjustFilter')}
                </div>
              )}
            </div>
          ) : shouldUseVirtualList ? (
            // 虚拟滚动模式（任务数 > 50）- 使用 react-window Grid
            <div
              ref={gridContainerRef}
              className={styles.virtualGridContainer}
              style={{ height: containerHeight }}
            >
              {rowCount > 0 && columnCount > 0 && (
                <Grid
                  gridRef={gridRef}
                  columnCount={columnCount}
                  columnWidth={cardWidth + gap}
                  rowCount={rowCount}
                  rowHeight={taskCardHeight + gap}
                  defaultHeight={containerHeight}
                  defaultWidth={gridContainerRef.current?.clientWidth || 0}
                  overscanCount={2}
                  cellComponent={Cell}
                  cellProps={{} as any}
                />
              )}
            </div>
          ) : (
            // 普通模式（任务数 <= 50）
            <div className={styles.tasksGrid} style={{
              gridTemplateColumns: `repeat(auto-fill, minmax(${isMobile ? '170px' : '300px'}, 1fr))`
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
                  <TaskCard
                    key={task.id}
                    task={task}
                    isMobile={isMobile}
                    language={language}
                    onViewTask={handleViewTask}
                    getTaskTypeLabel={getTaskTypeLabel}
                    getRemainTime={getRemainTime}
                    isExpired={isExpired}
                    isExpiringSoon={isExpiringSoon}
                    getTaskLevelColor={getTaskLevelColor}
                    getTaskLevelLabel={getTaskLevelLabel}
                    t={t}
                  />
                ))
              )}
            </div>
          )}

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
        <div 
          className={styles.applyModalOverlay}
          onClick={() => {
            setShowApplyModal(false);
            setSelectedTaskForApply(null);
            setApplyMessage('');
            setNegotiatedPrice(undefined);
          }}
        >
          <div 
            className={styles.applyModalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className={styles.applyModalTitle}>申请任务</h3>
            
            <div className={styles.applyModalForm}>
              <div>
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
                className={styles.applyModalTextarea}
              />
              </div>

              <div>
                <label className={styles.applyModalCheckbox}>
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
                    className={styles.applyModalInput}
                  />
                </div>
                )}
              </div>

              <div className={styles.applyModalButtons}>
                <button
                  onClick={() => {
                    setShowApplyModal(false);
                    setSelectedTaskForApply(null);
                    setApplyMessage('');
                    setNegotiatedPrice(undefined);
                  }}
                  className={`${styles.applyModalButton} ${styles.applyModalButtonCancel}`}
                >
                  {t('tasks.apply.cancel')}
                </button>
                <button
                  onClick={handleSubmitApplication}
                  className={`${styles.applyModalButton} ${styles.applyModalButtonSubmit}`}
                >
                  {t('tasks.apply.submitApplication')}
                </button>
              </div>
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
              max-width: 150px !important;
              min-width: 130px !important;
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
              padding: 0 !important;
              margin-left: -8px !important;
              margin-right: -8px !important;
              margin-bottom: 8px !important;
              width: calc(100% + 16px) !important;
            }
            
            .category-icons {
              padding: 4px 8px !important;
              padding-bottom: 2px !important;
            }
            
            .category-icons > div {
              min-width: 80px !important;
              max-width: 100px !important;
              flex-shrink: 0 !important;
              padding: 6px 4px !important;
              gap: 6px !important;
            }
            
            .category-icons > div > div,
            .category-icon-circle {
              width: 50px !important;
              height: 50px !important;
            }
            
            .category-icon-circle {
              font-size: 32px !important;
            }
            
            .category-icon-circle span {
              font-size: 32px !important;
              line-height: 1 !important;
            }
            
            .category-icons > div > div {
              font-size: 32px !important;
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
