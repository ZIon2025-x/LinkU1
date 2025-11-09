import React, { useEffect, useState, useRef, useLayoutEffect } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import api, { fetchCurrentUser, applyForTask, completeTask, confirmTaskCompletion, createReview, getTaskReviews, approveTaskTaker, rejectTaskTaker, sendMessage, getTaskApplications, approveApplication, getUserApplications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, logout, getPublicSystemSettings } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LanguageSwitcher from '../components/LanguageSwitcher';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useTranslation } from '../hooks/useTranslation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
}

const TaskDetail: React.FC = () => {
  const { id } = useParams();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { translate } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const [task, setTask] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [user, setUser] = useState<any>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [hoverRating, setHoverRating] = useState(0);
  const [reviewComment, setReviewComment] = useState('');
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [reviews, setReviews] = useState<any[]>([]);
  const [showReviews, setShowReviews] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [applications, setApplications] = useState<any[]>([]);
  const [loadingApplications, setLoadingApplications] = useState(false);
  const [userApplication, setUserApplication] = useState<any>(null);
  const [hasApplied, setHasApplied] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [systemSettings, setSystemSettings] = useState<any>({});
  // 翻译相关状态
  const [translatedTitle, setTranslatedTitle] = useState<string | null>(null);
  const [translatedDescription, setTranslatedDescription] = useState<string | null>(null);
  const [isTranslatingTitle, setIsTranslatingTitle] = useState(false);
  const [isTranslatingDescription, setIsTranslatingDescription] = useState(false);

  // 加载用户数据、通知和系统设置
  useEffect(() => {
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
        
        // 加载通知数据
        if (userData) {
          try {
            const [notificationsData, unreadCountData] = await Promise.all([
              getNotificationsWithRecentRead(10),
              getUnreadNotificationCount()
            ]);
            setNotifications(notificationsData);
            setUnreadCount(unreadCountData.unread_count);
          } catch (error) {
            console.error('加载通知失败:', error);
          }
        }
      } catch (error: any) {
        setUser(null);
      }
    };
    
    loadUserData();

    // 加载系统设置
    const loadSystemSettings = async () => {
      try {
        const settings = await getPublicSystemSettings();
        setSystemSettings(settings);
      } catch (error) {
        console.error('加载系统设置失败:', error);
      }
    };
    loadSystemSettings();
  }, []);

  // 更新或创建meta标签的工具函数（必须在useEffect之前定义）
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

  // 立即更新基础meta标签（在数据加载前就设置，避免爬虫抓取到默认值）
  useEffect(() => {
    // 即使任务数据还没加载，也先更新URL和类型，确保不会被抓取到默认值
    const taskUrl = `${window.location.origin}${window.location.pathname}`;
    
    // 强制移除默认的描述标签，避免被微信缓存
    const existingOgDescription = document.querySelector('meta[property="og:description"]');
    if (existingOgDescription) {
      existingOgDescription.remove();
    }
    const existingDescription = document.querySelector('meta[name="description"]') as HTMLMetaElement;
    if (existingDescription && existingDescription.content && existingDescription.content.includes('Professional task publishing')) {
      existingDescription.remove();
    }
    const existingTwitterDescription = document.querySelector('meta[name="twitter:description"]') as HTMLMetaElement;
    if (existingTwitterDescription && existingTwitterDescription.content && existingTwitterDescription.content.includes('Professional task publishing')) {
      existingTwitterDescription.remove();
    }
    
    updateMetaTag('og:url', taskUrl, true);
    updateMetaTag('og:type', 'article', true);
    
    // 设置favicon图片（带版本号避免缓存问题）
    const shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    // 强制移除旧的图片标签
    const existingOgImage = document.querySelector('meta[property="og:image"]');
    if (existingOgImage) {
      existingOgImage.remove();
    }
    updateMetaTag('og:image', shareImageUrl, true);
    updateMetaTag('og:image:type', 'image/png', true);
    updateMetaTag('twitter:image', shareImageUrl);
  }, [id]);

  // 加载任务数据
  useEffect(() => {
    setLoading(true);
    api.get(`/api/tasks/${id}`)
      .then(res => {
        setTask(res.data);
        // 如果任务已完成，加载评价
        if (res.data.status === 'completed') {
          loadTaskReviews();
        }
        
      })
      .catch((error) => {
        console.error('获取任务详情失败:', error);
        console.error('错误详情:', error.response?.data);
        setError('任务不存在');
      })
      .finally(() => setLoading(false));
  }, [id]);

  // SEO优化：使用useLayoutEffect确保在DOM渲染前就设置meta标签，优先级最高
  // 防止被其他页面的useLayoutEffect覆盖，确保任务描述优先显示
  useLayoutEffect(() => {
    if (task) {
      // 构建任务详情页的URL
      const taskUrl = `${window.location.origin}${window.location.pathname}`;
      
      // 更新页面标题
      const seoTitle = `${task.title} - ${task.location} | Link²Ur任务平台`;
      document.title = seoTitle;
      
      // 创建任务相关的描述（使用任务描述内容）
      // 格式：任务描述内容 | 类型 | 金额 | 截至时间 | 地点
      // 包含任务描述、金额、截至时间等关键信息
      const reward = ((task.agreed_reward ?? task.base_reward ?? task.reward) || 0);
      const rewardStr = reward.toFixed(2);
      const deadlineStr = task.deadline ? TimeHandlerV2.formatUtcToLocal(task.deadline, 'MM/DD HH:mm', 'Europe/London') : (language === 'zh' ? '未设置' : 'Not set');
      
      // 构建完整的分享描述
      // 先取任务描述的前60字符（为其他信息留空间）
      const descriptionPreview = task.description ? task.description.substring(0, 60).replace(/\n/g, ' ').trim() : '';
      
      // 根据语言构建包含所有关键信息的描述
      let taskDescription = '';
      if (language === 'zh') {
        if (descriptionPreview) {
          taskDescription = `${descriptionPreview} | 类型：${task.task_type} | 金额：£${rewardStr} | 截至：${deadlineStr} | 地点：${task.location}`;
        } else {
          taskDescription = `${task.task_type}任务 | 金额：£${rewardStr} | 截至：${deadlineStr} | 地点：${task.location}`;
        }
      } else {
        // English
        if (descriptionPreview) {
          taskDescription = `${descriptionPreview} | Type: ${task.task_type} | Amount: £${rewardStr} | Deadline: ${deadlineStr} | Location: ${task.location}`;
        } else {
          taskDescription = `${task.task_type} Task | Amount: £${rewardStr} | Deadline: ${deadlineStr} | Location: ${task.location}`;
        }
      }
      
      // 限制总长度在200字符内（微信分享建议不超过200字符）
      const seoDescription = taskDescription.substring(0, 200);
      
      // 强制更新meta描述（先移除所有旧标签，再插入到head最前面，确保优先被读取）
      const allDescriptions = document.querySelectorAll('meta[name="description"]');
      allDescriptions.forEach(tag => tag.remove());
      const descTag = document.createElement('meta');
      descTag.name = 'description';
      descTag.content = seoDescription;
      document.head.insertBefore(descTag, document.head.firstChild);
      
      // 强制更新og:description（先移除所有旧标签，再插入到head最前面）
      const allOgDescriptions = document.querySelectorAll('meta[property="og:description"]');
      allOgDescriptions.forEach(tag => tag.remove());
      const ogDescTag = document.createElement('meta');
      ogDescTag.setAttribute('property', 'og:description');
      ogDescTag.content = seoDescription;
      document.head.insertBefore(ogDescTag, document.head.firstChild);
      
      // 强制更新twitter:description
      const allTwitterDescriptions = document.querySelectorAll('meta[name="twitter:description"]');
      allTwitterDescriptions.forEach(tag => tag.remove());
      const twitterDescTag = document.createElement('meta');
      twitterDescTag.name = 'twitter:description';
      twitterDescTag.content = seoDescription;
      document.head.insertBefore(twitterDescTag, document.head.firstChild);
      
      // 强制更新微信分享描述（微信优先读取weixin:description）
      const allWeixinDescriptions = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDescriptions.forEach(tag => tag.remove());
      const weixinDescTag = document.createElement('meta');
      weixinDescTag.setAttribute('name', 'weixin:description');
      weixinDescTag.content = seoDescription;
      document.head.insertBefore(weixinDescTag, document.head.firstChild);
      
      // 更新meta关键词
      const keywords = `${task.task_type},${task.location},${task.title},任务,兼职,技能服务,Link²Ur`;
      updateMetaTag('keywords', keywords);
      
      // 更新Open Graph标签（用于社交媒体分享，包括微信）
      // 注意：微信会缓存这些标签，所以必须确保每次都更新
      updateMetaTag('og:type', 'article', true);
      
      // 强制更新og:title
      const existingOgTitle = document.querySelector('meta[property="og:title"]');
      if (existingOgTitle) {
        existingOgTitle.remove();
      }
      updateMetaTag('og:title', `${task.title} - Link²Ur任务平台`, true);
      
      updateMetaTag('og:url', taskUrl, true);
      
      // 设置favicon作为og:image（微信和社交媒体分享会使用）
      // 使用public/static/favicon.png，添加版本号避免缓存问题
      const shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
      // 强制更新og:image（通过先移除再添加的方式）
      const existingOgImage = document.querySelector('meta[property="og:image"]');
      if (existingOgImage) {
        existingOgImage.remove();
      }
      updateMetaTag('og:image', shareImageUrl, true);
      updateMetaTag('og:image:width', '1200', true);
      updateMetaTag('og:image:height', '630', true);
      updateMetaTag('og:image:type', 'image/png', true);
      updateMetaTag('og:image:alt', `${task.title} - Link²Ur任务平台`, true);
      updateMetaTag('og:site_name', 'Link²Ur', true);
      updateMetaTag('og:locale', 'zh_CN', true);
      
      // 更新Twitter Card标签
      updateMetaTag('twitter:card', 'summary_large_image');
      updateMetaTag('twitter:title', `${task.title} - Link²Ur任务平台`);
      updateMetaTag('twitter:description', seoDescription);
      // 强制更新twitter:image
      const existingTwitterImage = document.querySelector('meta[name="twitter:image"]');
      if (existingTwitterImage) {
        existingTwitterImage.remove();
      }
      updateMetaTag('twitter:image', shareImageUrl);
      updateMetaTag('twitter:url', taskUrl);
      
      // 微信分享特殊处理
      // 1. 确保所有标签都在head的前面部分（微信爬虫可能只读取前几个标签）
      // 2. 添加额外的微信友好标签
      // 确保图片URL是绝对路径且可通过HTTPS访问
      // 微信分享会读取og:image, og:title, og:description等标签
      
      // 将重要的meta标签移动到head的前面（确保微信爬虫能读取到）
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
      
      // 将关键标签移到前面
      setTimeout(() => {
        moveToTop('meta[property="og:image"]');
        moveToTop('meta[property="og:title"]');
        moveToTop('meta[property="og:description"]');
      }, 0);
      
      // 添加结构化数据 - 使用JobPosting类型以便搜索引擎识别
      // reward 变量已在上面声明，直接使用
      const structuredData = {
        "@context": "https://schema.org",
        "@type": "JobPosting",
        "title": task.title,
        "description": task.description,
        "identifier": {
          "@type": "PropertyValue",
          "name": "Task ID",
          "value": task.id.toString()
        },
        "hiringOrganization": {
          "@type": "Organization",
          "name": "Link²Ur",
          "url": "https://www.link2ur.com"
        },
        "jobLocation": {
          "@type": "Place",
          "address": {
            "@type": "PostalAddress",
            "addressLocality": task.location,
            "addressCountry": "GB"
          }
        },
        "employmentType": "CONTRACTOR",
        "baseSalary": {
          "@type": "MonetaryAmount",
          "currency": "GBP",
          "value": {
            "@type": "QuantitativeValue",
            "value": reward,
            "unitText": "GBP"
          }
        },
        "datePosted": task.created_at,
        "validThrough": task.deadline,
        "url": taskUrl,
        "workHours": "FLEXIBLE"
      };
      
      // 移除旧的structured data
      const oldScript = document.querySelector('script[type="application/ld+json"]');
      if (oldScript) {
        oldScript.remove();
      }
      
      // 添加新的structured data
      const script = document.createElement('script');
      script.type = 'application/ld+json';
      script.textContent = JSON.stringify(structuredData);
      document.head.appendChild(script);
    }
  }, [task]);

  // 标记通知为已读
  const handleMarkAsRead = async (notificationId: number) => {
    try {
      await markNotificationRead(notificationId);
      setNotifications(prev => 
        prev.map(notif => 
          notif.id === notificationId 
            ? { ...notif, is_read: 1 }
            : notif
        )
      );
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch (error) {
      console.error('标记通知已读失败:', error);
      alert(t('notificationPanel.markAsReadFailed') || '标记已读失败');
    }
  };

  // 标记所有通知为已读
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setNotifications(prev => 
        prev.map(notif => ({ ...notif, is_read: 1 }))
      );
      setUnreadCount(0);
    } catch (error) {
      console.error('标记所有通知已读失败:', error);
      alert(t('notificationPanel.markAllReadFailed') || '标记全部已读失败');
    }
  };

  // 处理分享功能 - 使用useRef避免重复触发
  const shareTriggeredRef = React.useRef(false);
  
  useEffect(() => {
    const shouldShare = searchParams.get('share') === 'true';
    
    // 检查是否已经触发过分享，避免重复触发
    if (shouldShare && task && !loading && !shareTriggeredRef.current) {
      shareTriggeredRef.current = true; // 标记为已触发
      
      // 移除URL中的share参数
      const newSearchParams = new URLSearchParams(searchParams);
      newSearchParams.delete('share');
      setSearchParams(newSearchParams, { replace: true });
      
      // 延迟执行，确保页面完全渲染
      const triggerShare = () => {
        // 检查浏览器是否支持Web Share API
        if (navigator.share) {
          // 构建分享内容
          const shareUrl = window.location.origin + window.location.pathname;
          const shareTitle = `${task.title} - Link²Ur任务平台`;
          const displayReward = task.agreed_reward ?? task.base_reward ?? task.reward ?? 0;
          const shareText = `${task.title}\n\n${task.description.substring(0, 100)}${task.description.length > 100 ? '...' : ''}\n\n任务类型: ${task.task_type}\n地点: ${task.location}\n金额: £${displayReward.toFixed(2)}\n\n立即查看: ${shareUrl}`;
          
          console.log('触发原生分享:', { title: shareTitle, text: shareText, url: shareUrl });
          
          // 使用setTimeout确保在下一个事件循环中执行，这样可以保持用户交互的上下文
          setTimeout(() => {
            navigator.share({
              title: shareTitle,
              text: shareText,
              url: shareUrl
            }).catch((error) => {
              // 用户取消分享或出错时不做任何处理
              console.log('分享已取消或出错:', error);
            });
          }, 100);
        } else {
          // 如果不支持Web Share API，使用传统的复制链接方式
          const shareUrl = window.location.origin + window.location.pathname;
          console.log('不支持Web Share API，使用复制链接方式:', shareUrl);
          
          navigator.clipboard.writeText(shareUrl).then(() => {
            alert('链接已复制到剪贴板！');
          }).catch(() => {
            // 如果复制失败，使用备用方法
            const textArea = document.createElement('textarea');
            textArea.value = shareUrl;
            textArea.style.position = 'fixed';
            textArea.style.left = '-999999px';
            document.body.appendChild(textArea);
            textArea.select();
            try {
              document.execCommand('copy');
              alert('链接已复制到剪贴板！');
            } catch (err) {
              alert(`请手动复制链接：${shareUrl}`);
            }
            document.body.removeChild(textArea);
          });
        }
      };
      
      // 延迟执行，确保页面完全加载
      setTimeout(triggerShare, 500);
    }
    
    // 如果share参数被移除，重置触发器
    if (!shouldShare && shareTriggeredRef.current) {
      shareTriggeredRef.current = false;
    }
  }, [task, loading, searchParams, setSearchParams]);

  // 当用户信息加载后，如果是任务发布者，加载申请者列表
  useEffect(() => {
    if (user && task && task.poster_id === user.id) {
      loadApplications();
    }
  }, [user, task]);

  // 检查当前用户是否已经申请了此任务
  useEffect(() => {
    if (user && task) {
      checkUserApplication();
    }
  }, [user, task]);

  // 检查用户申请状态
  const checkUserApplication = async () => {
    if (!user || !task || user.id === task.poster_id) {
      return; // 不是申请者或没有登录
    }
    
    try {
      // 获取用户的所有申请记录
      const userApplications = await getUserApplications();
      const userApp = userApplications.find((app: any) => app.task_id === task.id);
      setUserApplication(userApp);
    } catch (error) {
      console.error('检查用户申请状态失败:', error);
    }
  };

  // 检查用户等级是否满足任务等级要求
  const canViewTask = (user: any, task: any) => {
    if (!task) return false;
    
    // 如果用户未登录，只能查看任务大厅中显示的普通任务
    if (!user) {
      // 未登录用户只能查看：普通任务 + 开放状态的任务
      return task.task_level === 'normal' && 
             (task.status === 'open' || task.status === 'taken');
    }
    
    // 任务发布者可以查看自己发布的所有任务，无论任务等级如何
    if (user.id === task.poster_id) {
      return true;
    }
    
    // 任务接受者可以查看自己接受的任务，无论任务等级如何
    if (user.id === task.taker_id) {
      return true;
    }
    
    // 非任务相关的人：只能查看开放状态的任务，且需要满足等级要求
    const levelHierarchy = { 'normal': 1, 'vip': 2, 'super': 3 };
    const userLevelValue = levelHierarchy[user.user_level as keyof typeof levelHierarchy] || 1;
    const taskLevelValue = levelHierarchy[task.task_level as keyof typeof levelHierarchy] || 1;
    
    return (task.status === 'open' || task.status === 'taken') && 
           userLevelValue >= taskLevelValue;
  };

  // 检查用户是否已接受任务
  const hasAcceptedTask = (user: any, task: any) => {
    return user && task && task.taker_id === user.id;
  };

  const loadTaskReviews = async () => {
    try {
      const reviewsData = await getTaskReviews(Number(id));
      setReviews(reviewsData);
    } catch (error) {
      console.error('加载评价失败:', error);
    }
  };

  const loadApplications = async () => {
    if (!user || !task || user.id !== task.poster_id) {
      return;
    }
    
    setLoadingApplications(true);
    try {
      const res = await getTaskApplications(Number(id));
      setApplications(res);
    } catch (error) {
      console.error('加载申请者列表失败:', error);
    } finally {
      setLoadingApplications(false);
    }
  };

  const handleApproveApplication = async (applicantId: string) => {
    if (!window.confirm('确定要批准这个申请者吗？批准后其他申请者将被自动拒绝。')) {
      return;
    }

    setActionLoading(true);
    try {
      await approveApplication(Number(id), applicantId);
      alert('申请者批准成功！');
      
      // 重新加载任务信息和申请者列表
      const res = await api.get(`/api/tasks/${id}`);
      setTask(res.data);
      await loadApplications();
    } catch (error: any) {
      console.error('批准申请者失败:', error);
      alert(error.response?.data?.detail || '批准申请者失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleChat = async () => {
    // 跳转到任务聊天页面，使用任务ID
    if (!id) {
      alert('无法获取任务信息，请联系客服');
      return;
    }

    // 跳转到任务聊天页面
    navigate(`/message?taskId=${id}`);
  };

  const handleAcceptTask = async () => {
    if (!user) {
      alert('请先登录');
      return;
    }
    setActionLoading(true);
    try {
      const result = await applyForTask(Number(id));
      
      alert('任务申请成功！\n\n请等待任务发布者审核您的申请，审核通过后您就可以开始执行任务了。');
      
      // 隐藏申请按钮
      setHasApplied(true);
      
      // 重新获取任务信息
      const res = await api.get(`/api/tasks/${id}`);
      setTask(res.data);
    } catch (error: any) {
      console.error('接受任务失败:', error);
      console.error('错误详情:', error.response?.data);
      
      // 即使接受任务失败，也要重新获取任务信息，因为可能任务已经被接受了
      try {
        const res = await api.get(`/api/tasks/${id}`);
        setTask(res.data);
        
        // 如果任务已经被当前用户接受，显示不同的提示
        if (res.data.status === 'taken' && res.data.taker_id === user.id) {
          alert('您已经接受过这个任务了！\n\n请等待任务发布者同意您接受此任务。');
        } else {
          alert(error.response?.data?.detail || '接受任务失败');
        }
      } catch (refreshError) {
        console.error('重新获取任务信息失败:', refreshError);
        alert(error.response?.data?.detail || '接受任务失败');
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleCompleteTask = async () => {
    if (!user) {
      alert('请先登录');
      return;
    }
    setActionLoading(true);
    try {
      await completeTask(Number(id));
      alert('任务已标记为完成，等待发布者确认！');
      // 重新获取任务信息
      const res = await api.get(`/api/tasks/${id}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleConfirmCompletion = async () => {
    if (!user) {
      alert('请先登录');
      return;
    }
    setActionLoading(true);
    try {
      await confirmTaskCompletion(Number(id));
      alert('任务已确认完成！');
      
      // 立即刷新任务信息
      const res = await api.get(`/api/tasks/${id}`);
      setTask(res.data);
      
      // 延迟再次刷新，确保状态已更新
      setTimeout(async () => {
        try {
          const res = await api.get(`/api/tasks/${id}`);
          setTask(res.data);
        } catch (error) {
          console.error('延迟刷新失败:', error);
        }
      }, 1000);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };


  const handleApproveTaker = async () => {
    if (!user) {
      alert('请先登录');
      return;
    }
    setActionLoading(true);
    try {
      await approveTaskTaker(Number(id));
      alert('已同意接受者进行任务！');
      // 重新获取任务信息
      const res = await api.get(`/api/tasks/${id}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleRejectTaker = async () => {
    if (!user) {
      alert('请先登录');
      return;
    }
    if (!window.confirm('确定要拒绝这个接受者吗？任务将重新开放给其他人。')) {
      return;
    }
    setActionLoading(true);
    try {
      await rejectTaskTaker(Number(id));
      alert('已拒绝接受者，任务重新开放！');
      // 重新获取任务信息
      const res = await api.get(`/api/tasks/${id}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleSubmitReview = async () => {
    if (!user) {
      alert('请先登录');
      return;
    }
    if (reviewRating < 1 || reviewRating > 5) {
      alert('请选择有效的评分');
      return;
    }
    setActionLoading(true);
    try {
      await createReview(Number(id), reviewRating, reviewComment, isAnonymous);
      alert('评价提交成功！');
      // 评价提交成功，重新加载评价数据
      setShowReviewModal(false);
      setReviewRating(5);
      setReviewComment('');
      setIsAnonymous(false);
      // 重新加载评价
      await loadTaskReviews();
    } catch (error: any) {
      alert(error.response?.data?.detail || '评价提交失败');
    } finally {
      setActionLoading(false);
    }
  };

  const canReview = () => {
    if (!user || !task) return false;
    // 只有任务参与者且任务已确认完成才能评价
    return (task.poster_id === user.id || task.taker_id === user.id) && task.status === 'completed';
  };

  const hasUserReviewed = () => {
    if (!user) return false;
    return reviews.some(review => review.user_id === user.id);
  };

  // 当任务加载或语言改变时,重置翻译
  useEffect(() => {
    setTranslatedTitle(null);
    setTranslatedDescription(null);
  }, [task, language]);

  if (loading) {
    return (
      <div>
        {/* 导航栏 */}
        <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
          <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
            <div 
              style={{
                fontWeight: 'bold', 
                fontSize: 24, 
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
                WebkitBackgroundClip: 'text', 
                WebkitTextFillColor: 'transparent',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                padding: '4px 8px',
                borderRadius: '8px',
                flexShrink: 0
              }}
              onClick={() => navigate('/')}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'scale(1.05)';
                e.currentTarget.style.background = 'linear-gradient(135deg, #2563eb, #7c3aed)';
                (e.currentTarget.style as any).webkitBackgroundClip = 'text';
                (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'scale(1)';
                e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #8b5cf6)';
                (e.currentTarget.style as any).webkitBackgroundClip = 'text';
                (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
              }}
            >
              Link²Ur
            </div>
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
        <div style={{height: 60}} />
        <div style={{textAlign:'center',padding:40}}>加载中...</div>
      </div>
    );
  }
  
  if (error || !task) {
    return (
      <div>
        {/* 导航栏 */}
        <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
          <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
            <div 
              style={{
                fontWeight: 'bold', 
                fontSize: 24, 
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
                WebkitBackgroundClip: 'text', 
                WebkitTextFillColor: 'transparent',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                padding: '4px 8px',
                borderRadius: '8px',
                flexShrink: 0
              }}
              onClick={() => navigate('/')}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'scale(1.05)';
                e.currentTarget.style.background = 'linear-gradient(135deg, #2563eb, #7c3aed)';
                (e.currentTarget.style as any).webkitBackgroundClip = 'text';
                (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'scale(1)';
                e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #8b5cf6)';
                (e.currentTarget.style as any).webkitBackgroundClip = 'text';
                (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
              }}
            >
              Link²Ur
            </div>
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
        <div style={{height: 60}} />
        <div style={{color:'red',textAlign:'center',padding:40}}>{error || '任务不存在'}</div>
      </div>
    );
  }

  const isTaskPoster = user && user.id === task.poster_id;
  const isTaskTaker = user && user.id === task.taker_id;
  // 是否可以显示申请按钮（包括未登录用户）
  const canShowApplyButton = (task.status === 'open' || task.status === 'taken') && 
    canViewTask(user, task) &&
    (!user || user.id !== task.poster_id) && // 未登录或不是发布者
    !userApplication && // 如果已经申请过，不能再次申请
    !hasApplied; // 如果已经申请过，隐藏按钮

  // 是否可以申请任务（需要登录）
  const canAcceptTask = user && 
    user.id !== task.poster_id && 
    (task.status === 'open' || task.status === 'taken') && 
    canViewTask(user, task) &&
    !userApplication && // 如果已经申请过，不能再次申请
    !hasApplied; // 如果已经申请过，隐藏按钮

  const getStatusText = (status: string) => {
    switch (status) {
      case 'open': return '开放中';
      case 'taken': return '开放中';  // 在任务大厅中显示为开放中
      case 'in_progress': return '进行中';
      case 'pending_confirmation': return '待确认';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return status;
    }
  };

  const getTaskLevelText = (level: string) => {
    switch (level) {
      case 'vip':
        return '⭐ VIP任务';
      case 'super':
        return '🔥 超级任务';
      default:
        return '普通任务';
    }
  };

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

  // 翻译标题
  const handleTranslateTitle = async () => {
    if (!task || !task.title) return;
    
    // 如果已有翻译，重置为原文
    if (translatedTitle) {
      setTranslatedTitle(null);
      return;
    }
    
    setIsTranslatingTitle(true);
    try {
      // 检测文本语言，然后翻译成当前界面语言
      const textLang = detectTextLanguage(task.title);
      // 如果文本语言和界面语言相同，不需要翻译（这不应该发生，因为按钮应该只在needsTranslation时显示）
      if (textLang === language) {
        console.log('翻译标题: 文本语言和界面语言相同，无需翻译');
        setTranslatedTitle(null);
        return;
      }
      // 目标语言就是当前界面语言（这样用户就能看到自己语言版本的文本）
      const targetLang = language;
      const translated = await translate(task.title, targetLang, textLang);
      setTranslatedTitle(translated);
    } catch (error) {
      console.error('翻译标题失败:', error);
      alert('翻译失败: ' + (error instanceof Error ? error.message : '未知错误'));
    } finally {
      setIsTranslatingTitle(false);
    }
  };

  // 翻译描述
  const handleTranslateDescription = async () => {
    if (!task || !task.description) return;
    
    // 如果已有翻译，重置为原文
    if (translatedDescription) {
      setTranslatedDescription(null);
      return;
    }
    
    setIsTranslatingDescription(true);
    try {
      // 检测文本语言，然后翻译成当前界面语言
      const textLang = detectTextLanguage(task.description);
      // 如果文本语言和界面语言相同，不需要翻译（这不应该发生，因为按钮应该只在needsTranslation时显示）
      if (textLang === language) {
        console.log('翻译描述: 文本语言和界面语言相同，无需翻译');
        setTranslatedDescription(null);
        return;
      }
      // 目标语言就是当前界面语言（这样用户就能看到自己语言版本的文本）
      const targetLang = language;
      const translated = await translate(task.description, targetLang, textLang);
      setTranslatedDescription(translated);
    } catch (error) {
      console.error('翻译描述失败:', error);
      alert('翻译失败: ' + (error instanceof Error ? error.message : '未知错误'));
    } finally {
      setIsTranslatingDescription(false);
    }
  };

  // 简单的语言检测：检查是否包含中文字符
  const detectTextLanguage = (text: string): 'zh' | 'en' => {
    if (!text || !text.trim()) return 'en';
    const hasChinese = /[\u4e00-\u9fff]/.test(text);
    return hasChinese ? 'zh' : 'en';
  };

  // 检查是否需要翻译（文本语言和界面语言不同时需要翻译）
  const needsTranslation = (text: string): boolean => {
    const detectedLang = detectTextLanguage(text);
    return detectedLang !== language;
  };

  // 重置翻译(显示原文)
  const handleResetTranslation = (type: 'title' | 'description') => {
    if (type === 'title') {
      setTranslatedTitle(null);
    } else {
      setTranslatedDescription(null);
    }
  };

  // 如果用户等级不满足任务等级要求，显示权限不足页面
  if (task && !canViewTask(user, task)) {
    return (
      <div style={{maxWidth: 700, margin: '40px auto', background: '#fff', borderRadius: 16, boxShadow: '0 4px 24px #e6f7ff', padding: 40, textAlign: 'center'}}>
        <div style={{fontSize: 48, marginBottom: 20}}>🔒</div>
        <h2 style={{fontSize: 24, fontWeight: 800, color: '#A67C52', marginBottom: 16}}>
          {!user ? '需要登录' : '权限不足'}
        </h2>
        <p style={{fontSize: 16, color: '#666', marginBottom: 20}}>
          {!user ? 
            (task.status === 'cancelled' ? '此任务已取消，需要登录后才能查看' :
             task.status === 'completed' ? '此任务已完成，需要登录后才能查看' :
             '此任务需要登录后才能查看') : 
            `此任务需要${task.task_level === 'vip' ? 'VIP' : '超级VIP'}用户才能查看`}
        </p>
        {user && (
          <p style={{fontSize: 14, color: '#999', marginBottom: 30}}>
            您的当前等级：{user.user_level === 'normal' ? '普通用户' : user.user_level === 'vip' ? 'VIP用户' : '超级VIP用户'}
          </p>
        )}
        <div style={{display: 'flex', gap: '12px', justifyContent: 'center'}}>
          <button
            onClick={() => navigate('/tasks')}
            style={{
              background: 'linear-gradient(135deg, #A67C52, #8B4513)',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '12px 24px',
              fontSize: 16,
              fontWeight: 600,
              cursor: 'pointer'
            }}
          >
            返回任务大厅
          </button>
          {!user && (
            <button
              onClick={() => setShowLoginModal(true)}
              style={{
                background: 'linear-gradient(135deg, #6EC1E4, #4A90E2)',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                padding: '12px 24px',
                fontSize: 16,
                fontWeight: 600,
                cursor: 'pointer'
              }}
            >
              立即登录
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* 顶部导航栏 */}
      <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          {/* Logo */}
          <div 
            style={{
              fontWeight: 'bold', 
              fontSize: 24, 
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
              WebkitBackgroundClip: 'text', 
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              padding: '4px 8px',
              borderRadius: '8px',
              flexShrink: 0
            }}
            onClick={() => navigate('/')}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'scale(1.05)';
              e.currentTarget.style.background = 'linear-gradient(135deg, #2563eb, #7c3aed)';
              (e.currentTarget.style as any).webkitBackgroundClip = 'text';
              (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'scale(1)';
              e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #8b5cf6)';
              (e.currentTarget.style as any).webkitBackgroundClip = 'text';
              (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
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

      {/* 通知面板 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />

      <div style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        padding: '20px'
      }}>
        <div style={{
          maxWidth: '900px',
          margin: '0 auto',
          background: '#fff',
          borderRadius: '24px',
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
          padding: '40px',
          position: 'relative',
          overflow: 'hidden'
        }}>
        {/* 装饰性背景 */}
        <div style={{
          position: 'absolute',
          top: '-50px',
          right: '-50px',
          width: '200px',
          height: '200px',
          background: 'linear-gradient(45deg, #667eea, #764ba2)',
          borderRadius: '50%',
          opacity: 0.1
        }} />
        <div style={{
          position: 'absolute',
          bottom: '-30px',
          left: '-30px',
          width: '150px',
          height: '150px',
          background: 'linear-gradient(45deg, #764ba2, #667eea)',
          borderRadius: '50%',
          opacity: 0.1
        }} />
        
        {/* SEO优化：H1标签，可见但样式简洁 */}
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
          任务详情
        </h1>
        
        {/* 标题区域 */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '20px',
          marginBottom: '32px',
          flexWrap: 'wrap',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px', flexWrap: 'wrap' }}>
              <h2 style={{
                fontSize: '32px',
                fontWeight: '800',
                background: 'linear-gradient(135deg, #667eea, #764ba2)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                margin: 0,
                lineHeight: 1.2,
                flex: 1,
                minWidth: '200px'
              }}>
                {translatedTitle || task.title}
              </h2>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                {translatedTitle ? (
                  <button
                    onClick={() => handleResetTranslation('title')}
                    disabled={isTranslatingTitle}
                    style={{
                      background: '#ef4444',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      padding: '8px 12px',
                      fontSize: '12px',
                      fontWeight: '600',
                      cursor: isTranslatingTitle ? 'not-allowed' : 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      opacity: isTranslatingTitle ? 0.6 : 1
                    }}
                    title={t('taskDetail.showOriginal')}
                  >
                    🔄 {t('taskDetail.showOriginal')}
                  </button>
                ) : needsTranslation(task.title) ? (
                  <button
                    onClick={handleTranslateTitle}
                    disabled={isTranslatingTitle}
                    style={{
                      background: '#3b82f6',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      padding: '8px 12px',
                      fontSize: '12px',
                      fontWeight: '600',
                      cursor: isTranslatingTitle ? 'not-allowed' : 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      opacity: isTranslatingTitle ? 0.6 : 1
                    }}
                    title={t('taskDetail.translateTitle')}
                  >
                    {isTranslatingTitle ? '⏳' : '🌐'} {t('taskDetail.translateTitle')}
                  </button>
                ) : null}
              </div>
            </div>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              flexWrap: 'wrap'
            }}>
              {/* 任务等级标签 */}
              {task.task_level && task.task_level !== 'normal' && (
                <div style={{
                  padding: '8px 16px',
                  borderRadius: '20px',
                  fontSize: '14px',
                  fontWeight: '700',
                  ...getTaskLevelStyle(task.task_level)
                }}>
                  {getTaskLevelText(task.task_level)}
                </div>
              )}
              {/* 状态标签 */}
              <div style={{
                padding: '6px 12px',
                borderRadius: '16px',
                fontSize: '12px',
                fontWeight: '600',
                background: (task.status === 'open' || task.status === 'taken') ? '#d1fae5' : 
                           task.status === 'in_progress' ? '#dbeafe' :
                           task.status === 'completed' ? '#d1fae5' : '#fee2e2',
                color: (task.status === 'open' || task.status === 'taken') ? '#065f46' : 
                       task.status === 'in_progress' ? '#1e40af' :
                       task.status === 'completed' ? '#065f46' : '#991b1b',
                border: `1px solid ${(task.status === 'open' || task.status === 'taken') ? '#a7f3d0' : 
                                   task.status === 'in_progress' ? '#93c5fd' :
                                   task.status === 'completed' ? '#a7f3d0' : '#fecaca'}`
              }}>
                {getStatusText(task.status)}
              </div>
            </div>
          </div>
        </div>
        {/* 任务信息卡片 */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '20px',
          marginBottom: '32px',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{
            background: '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>📋</div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>任务类型</div>
            <div style={{ fontSize: '16px', fontWeight: '600', color: '#1e293b' }}>{task.task_type}</div>
          </div>
          
          <div style={{
            background: task.location === 'Online' ? '#e6f3ff' : '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: task.location === 'Online' ? '2px solid #93c5fd' : '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>
              {task.location === 'Online' ? '🌐' : '📍'}
            </div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>
              {task.location === 'Online' ? '任务方式' : '所在城市'}
            </div>
            <div style={{ 
              fontSize: '16px', 
              fontWeight: '600', 
              color: task.location === 'Online' ? '#2563eb' : '#1e293b' 
            }}>
              {task.location}
            </div>
          </div>
          
          <div style={{
            background: '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>💰</div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>任务金额</div>
            <div style={{ fontSize: '20px', fontWeight: '700', color: '#059669' }}>£{((task.agreed_reward ?? task.base_reward ?? task.reward) || 0).toFixed(2)}</div>
          </div>
          
          <div style={{
            background: '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>⏰</div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>截止时间</div>
            <div style={{ fontSize: '16px', fontWeight: '600', color: '#1e293b' }}>
              {TimeHandlerV2.formatUtcToLocal(task.deadline, 'MM/DD HH:mm', 'Europe/London')} (英国时间)
            </div>
          </div>
        </div>
        
        {/* 任务描述 */}
        <div style={{
          background: '#f8fafc',
          padding: '24px',
          borderRadius: '16px',
          border: '2px solid #e2e8f0',
          marginBottom: '32px',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '12px',
            marginBottom: '16px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div style={{ fontSize: '20px' }}>📝</div>
              <h3 style={{
                fontSize: '18px',
                fontWeight: '600',
                color: '#1e293b',
                margin: 0
              }}>任务描述</h3>
            </div>
            <div>
              {translatedDescription ? (
                <button
                  onClick={() => handleResetTranslation('description')}
                  disabled={isTranslatingDescription}
                  style={{
                    background: '#ef4444',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    padding: '6px 12px',
                    fontSize: '12px',
                    fontWeight: '600',
                    cursor: isTranslatingDescription ? 'not-allowed' : 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    opacity: isTranslatingDescription ? 0.6 : 1
                  }}
                  title={t('taskDetail.showOriginal')}
                >
                  🔄 {t('taskDetail.showOriginal')}
                </button>
              ) : needsTranslation(task.description) ? (
                <button
                  onClick={handleTranslateDescription}
                  disabled={isTranslatingDescription}
                  style={{
                    background: '#3b82f6',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    padding: '6px 12px',
                    fontSize: '12px',
                    fontWeight: '600',
                    cursor: isTranslatingDescription ? 'not-allowed' : 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    opacity: isTranslatingDescription ? 0.6 : 1
                  }}
                  title={t('taskDetail.translateDescription')}
                >
                  {isTranslatingDescription ? '⏳' : '🌐'} {t('taskDetail.translateDescription')}
                </button>
              ) : null}
            </div>
          </div>
          <div style={{
            fontSize: '16px',
            lineHeight: 1.6,
            color: '#374151',
            whiteSpace: 'pre-wrap'
          }}>{translatedDescription || task.description}</div>
        </div>
        
        {/* 金额显示区域 */}
        <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '24px',
            position: 'relative',
            zIndex: 1
          }}>
            <div style={{ fontSize: '20px' }}>💰</div>
            <span style={{
              fontSize: '18px',
              fontWeight: '600',
              color: '#1e293b'
            }}>金额：</span>
            <span style={{
              fontSize: '24px',
              fontWeight: '700',
              color: '#059669'
            }}>£{((task.agreed_reward ?? task.base_reward ?? task.reward) || 0).toFixed(2)}</span>
          </div>
        
        {/* 其他任务信息 */}
        <div style={{
          background: '#f8fafc',
          padding: '20px',
          borderRadius: '16px',
          border: '2px solid #e2e8f0',
          marginBottom: '32px',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '16px'
          }}>
            <div style={{ fontSize: '20px' }}>ℹ️</div>
            <h3 style={{
              fontSize: '18px',
              fontWeight: '600',
              color: '#1e293b',
              margin: 0
            }}>任务详情</h3>
          </div>
          
          <div style={{
            display: 'grid',
            gap: '12px'
          }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>截止时间：</span>
              <span style={{ color: '#1e293b', fontWeight: '500' }}>
                {task.deadline && TimeHandlerV2.formatUtcToLocal(task.deadline, 'YYYY/MM/DD HH:mm:ss', 'Europe/London')} (英国时间)
              </span>
            </div>
            
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>任务等级：</span>
              <span style={{ color: '#1e293b', fontWeight: '500' }}>
                {getTaskLevelText(task.task_level || 'normal')}
              </span>
            </div>
            
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>可见性：</span>
              <span style={{
                color: task.is_public === 1 ? '#059669' : '#dc2626',
                fontWeight: '600',
                padding: '2px 8px',
                borderRadius: '8px',
                background: task.is_public === 1 ? '#d1fae5' : '#fee2e2',
                border: `1px solid ${task.is_public === 1 ? '#a7f3d0' : '#fecaca'}`
              }}>
                {task.is_public === 1 ? '🌍 公开显示' : '🔒 仅自己可见'}
              </span>
            </div>
            
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>发布者：</span>
              <span style={{ color: '#1e293b', fontWeight: '500' }}>
                {task.poster_id}
                {task.poster_id && (
                  <span style={{ marginLeft: '8px', fontSize: '12px', color: '#6b7280' }}>
                    (点击下方按钮进行沟通)
                  </span>
                )}
              </span>
            </div>
          </div>
        </div>
        
        {/* 操作按钮区域 */}
        <div style={{
          display: 'flex',
          gap: '16px',
          flexWrap: 'wrap',
          justifyContent: 'center',
          position: 'relative',
          zIndex: 1
        }}>
          {canShowApplyButton && (
            <button
              onClick={() => {
                if (!user) {
                  setShowLoginModal(true);
                } else {
                  handleAcceptTask();
                }
              }}
              disabled={actionLoading && user}
              style={{
                background: actionLoading 
                  ? 'linear-gradient(135deg, #cbd5e1, #94a3b8)' 
                  : 'linear-gradient(135deg, #10b981, #059669)',
                color: '#fff',
                border: 'none',
                borderRadius: '16px',
                padding: '16px 32px',
                fontWeight: '700',
                fontSize: '16px',
                cursor: actionLoading ? 'not-allowed' : 'pointer',
                transition: 'all 0.3s ease',
                boxShadow: actionLoading 
                  ? '0 4px 12px rgba(0,0,0,0.1)' 
                  : '0 8px 24px rgba(16, 185, 129, 0.3)',
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}
              onMouseEnter={(e) => {
                if (!actionLoading) {
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 12px 32px rgba(16, 185, 129, 0.4)';
                }
              }}
              onMouseLeave={(e) => {
                if (!actionLoading) {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 8px 24px rgba(16, 185, 129, 0.3)';
                }
              }}
            >
              {actionLoading ? (
                <>
                  <span>⏳</span>
                  处理中...
                </>
              ) : (
                <>
                  <span>✅</span>
                  申请任务
                </>
              )}
          </button>
        )}

          {/* 显示申请状态 */}
          {user && user.id !== task.poster_id && userApplication && (
            <div style={{
              background: userApplication.status === 'pending' 
                ? 'linear-gradient(135deg, #fef3c7, #fde68a)' 
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation' 
                    ? 'linear-gradient(135deg, #e0e7ff, #c7d2fe)'
                    : 'linear-gradient(135deg, #d1fae5, #a7f3d0)')
                : 'linear-gradient(135deg, #fee2e2, #fecaca)',
              border: userApplication.status === 'pending'
                ? '2px solid #f59e0b'
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation' 
                    ? '2px solid #6366f1'
                    : '2px solid #10b981')
                : '2px solid #ef4444',
              borderRadius: '16px',
              padding: '20px 24px',
              color: userApplication.status === 'pending'
                ? '#92400e'
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation' 
                    ? '#3730a3'
                    : '#065f46')
                : '#991b1b',
              fontSize: '16px',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              maxWidth: '600px',
              margin: '0 auto',
              boxShadow: userApplication.status === 'pending'
                ? '0 4px 12px rgba(245, 158, 11, 0.2)'
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation'
                    ? '0 4px 12px rgba(99, 102, 241, 0.2)'
                    : '0 4px 12px rgba(16, 185, 129, 0.2)')
                : '0 4px 12px rgba(239, 68, 68, 0.2)'
            }}>
              <div style={{fontSize: '32px'}}>
                {userApplication.status === 'pending' ? '⏳' : 
                 userApplication.status === 'approved' ? 
                   (task.status === 'pending_confirmation' ? '⏰' : '✅') : '❌'}
              </div>
              <div>
                <div style={{fontWeight: 'bold', marginBottom: '8px', fontSize: '18px'}}>
                  {userApplication.status === 'pending' ? '等待发布者审核' :
                   userApplication.status === 'approved' ? 
                     (task.status === 'pending_confirmation' ? '任务已完成' : '申请已通过') : 
                   '申请被拒绝'}
                </div>
                <div style={{fontSize: '14px', fontWeight: 'normal', lineHeight: 1.5}}>
                  {userApplication.status === 'pending' ? '您已成功申请此任务，请等待任务发布者审核您的申请。' :
                   userApplication.status === 'approved' ? 
                     (task.status === 'pending_confirmation' ? 
                       '恭喜！您已完成任务，请等待发布者确认任务完成。' : 
                       '恭喜！您的申请已通过，现在可以开始执行任务了。') :
                   '很抱歉，您的申请被拒绝了。'}
                </div>
                {userApplication.message && (
                  <div style={{fontSize: '12px', marginTop: '8px', fontStyle: 'italic'}}>
                    申请留言：{userApplication.message}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 兼容旧的显示逻辑 */}
          {task.status === 'taken' && isTaskTaker && !userApplication && (
            <div style={{
              background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
              border: '2px solid #f59e0b',
              borderRadius: '16px',
              padding: '20px 24px',
              color: '#92400e',
              fontSize: '16px',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              maxWidth: '600px',
              margin: '0 auto',
              boxShadow: '0 4px 12px rgba(245, 158, 11, 0.2)'
            }}>
              <div style={{fontSize: '32px'}}>⏳</div>
              <div>
                <div style={{fontWeight: 'bold', marginBottom: '8px', fontSize: '18px'}}>
                  等待发布者同意
                </div>
                <div style={{fontSize: '14px', fontWeight: 'normal', lineHeight: 1.5}}>
                  您已成功接受此任务，请等待任务发布者同意后即可开始执行。
                </div>
              </div>
            </div>
          )}

        {/* 申请者列表 - 仅任务发布者可见 */}
        {isTaskPoster && (task.status === 'taken' || task.status === 'open') && (
          <div style={{
            marginTop: '20px',
            padding: '20px',
            background: '#f8f9fa',
            borderRadius: '12px',
            border: '1px solid #e9ecef'
          }}>
            <h3 style={{ margin: '0 0 16px 0', color: '#333', fontSize: '18px' }}>
              申请者列表 ({applications.length})
            </h3>
            
            {loadingApplications ? (
              <div style={{ textAlign: 'center', padding: '20px' }}>
                加载中...
              </div>
            ) : applications.length === 0 ? (
              <div style={{ 
                textAlign: 'center', 
                padding: '20px', 
                color: '#666',
                background: '#fff',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                暂无申请者
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {applications.map((app) => (
                  <div key={app.id} style={{
                    background: '#fff',
                    padding: '16px',
                    borderRadius: '8px',
                    border: '1px solid #e9ecef',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                  }}>
                    <div>
                      <div style={{ fontWeight: '600', color: '#333', marginBottom: '4px' }}>
                        {app.applicant_name}
                      </div>
                      {app.message && (
                        <div style={{ color: '#666', fontSize: '14px', marginBottom: '4px' }}>
                          "{app.message}"
                        </div>
                      )}
                      <div style={{ color: '#999', fontSize: '12px' }}>
                        申请时间: {TimeHandlerV2.formatUtcToLocal(app.created_at)}
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => navigate(`/message?taskId=${id}`)}
                        style={{
                          background: '#007bff',
                          color: '#fff',
                          border: 'none',
                          borderRadius: '6px',
                          padding: '8px 16px',
                          fontWeight: '600',
                          cursor: 'pointer',
                          fontSize: '14px'
                        }}
                      >
                        联系
                      </button>
                      <button
                        onClick={() => handleApproveApplication(app.applicant_id)}
                        disabled={actionLoading}
                        style={{
                          background: '#28a745',
                          color: '#fff',
                          border: 'none',
                          borderRadius: '6px',
                          padding: '8px 16px',
                          fontWeight: '600',
                          cursor: actionLoading ? 'not-allowed' : 'pointer',
                          opacity: actionLoading ? 0.6 : 1,
                          fontSize: '14px'
                        }}
                      >
                        {actionLoading ? '处理中...' : '批准'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}


        {task.status === 'in_progress' && isTaskTaker && (
          <button
            onClick={handleCompleteTask}
            disabled={actionLoading}
            style={{
              background: '#28a745',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '10px 32px',
              fontWeight: 700,
              fontSize: 18,
              cursor: actionLoading ? 'not-allowed' : 'pointer',
              opacity: actionLoading ? 0.6 : 1
            }}
          >
            {actionLoading ? '处理中...' : '标记完成'}
          </button>
        )}

        {/* 任务进行中时，发布者可以联系接收者 */}
        {task.status === 'in_progress' && isTaskPoster && task.taker_id && (
          <button
            onClick={() => navigate(`/message?taskId=${id}`)}
            style={{
              background: '#007bff',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '10px 32px',
              fontWeight: 700,
              fontSize: 18,
              cursor: 'pointer',
              marginRight: '16px'
            }}
          >
            💬 联系接收者
          </button>
        )}

        {task.status === 'pending_confirmation' && isTaskPoster && (
          <button
            onClick={handleConfirmCompletion}
            disabled={actionLoading}
            style={{
              background: '#28a745',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '10px 32px',
              fontWeight: 700,
              fontSize: 18,
              cursor: actionLoading ? 'not-allowed' : 'pointer',
              opacity: actionLoading ? 0.6 : 1
            }}
          >
            {actionLoading ? '处理中...' : '确认完成'}
          </button>
        )}
        
      {user && user.id !== task.poster_id && canViewTask(user, task) && (
          <button
            onClick={handleChat}
            style={{
              background: '#A67C52',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '10px 32px',
              fontWeight: 700,
              fontSize: 18,
              cursor: 'pointer'
            }}
            title="点击联系任务发布者进行沟通"
          >
            联系发布者
          </button>
        )}


        {/* 评价按钮 */}
        {canReview() && !hasUserReviewed() && (
          <button
            onClick={() => setShowReviewModal(true)}
            style={{
              background: '#ffc107',
              color: '#000',
              border: 'none',
              borderRadius: 8,
              padding: '10px 32px',
              fontWeight: 700,
              fontSize: 18,
              cursor: 'pointer'
            }}
          >
            ⭐ 评价任务
          </button>
        )}

        {/* 评价不会显示在任务上，已移除查看评价按钮 */}
      </div>

      {/* 评价不会显示在任务上，已移除评价列表 */}
      {false && (
        <div style={{marginTop: 24, padding: 20, background: '#f8f9fa', borderRadius: 8}}>
          <h3 style={{marginBottom: 16, color: '#A67C52'}}>任务评价</h3>
          {reviews.map((review, index) => (
            <div key={index} style={{
              padding: 16,
              background: '#fff',
              borderRadius: 8,
              marginBottom: 12,
              border: '1px solid #e9ecef'
            }}>
              <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8}}>
                <div style={{fontWeight: 600, color: '#333'}}>
                  用户 {review.user_id}
                </div>
                                 <div style={{color: '#ffc107', fontSize: 16}}>
                   {Array.from({length: Math.floor(review.rating)}, (_, i) => '⭐').join('')}
                   {review.rating % 1 !== 0 && '☆'}
                   {Array.from({length: 5 - Math.ceil(review.rating)}, (_, i) => '☆').join('')}
                 </div>
              </div>
              {review.comment && (
                <div style={{color: '#666', fontSize: 14}}>
                  {review.comment}
                </div>
              )}
              <div style={{color: '#999', fontSize: 12, marginTop: 8}}>
                {TimeHandlerV2.formatUtcToLocal(review.created_at, 'YYYY/MM/DD HH:mm:ss', 'Europe/London')} (英国时间)
              </div>
            </div>
          ))}
        </div>
      )}

      {/* 评价弹窗 */}
      {showReviewModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div style={{
            background: '#fff',
            borderRadius: 16,
            padding: 32,
            maxWidth: 500,
            width: '90%',
            maxHeight: '80vh',
            overflow: 'auto'
          }}>
            <h2 style={{marginBottom: 24, color: '#A67C52', textAlign: 'center'}}>评价任务</h2>
            
            <div style={{marginBottom: 20}}>
              <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
                评分 (0.5-5星)
              </label>
              <div style={{display: 'flex', gap: 4, justifyContent: 'center', alignItems: 'center'}}>
                {[0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5].map(star => (
                  <button
                    key={star}
                    onClick={() => setReviewRating(star)}
                    onMouseEnter={() => setHoverRating(star)}
                    onMouseLeave={() => setHoverRating(0)}
                                     style={{
                   background: 'none',
                   border: 'none',
                   fontSize: star % 1 === 0 ? 24 : 18,
                   cursor: 'pointer',
                   color: star <= (hoverRating || reviewRating) ? '#ffc107' : '#ddd',
                   transition: 'all 0.3s ease',
                   padding: '2px',
                   transform: star <= (hoverRating || reviewRating) ? 'scale(1.2)' : 'scale(1)',
                   filter: star <= (hoverRating || reviewRating) ? 'drop-shadow(0 0 8px rgba(255, 193, 7, 0.6))' : 'none'
                 }}
                  >
                                         {star <= (hoverRating || reviewRating) ? '⭐' : '☆'}
                  </button>
                ))}
              </div>
                       <div style={{
           textAlign: 'center', 
           marginTop: 8, 
           color: '#666', 
           fontSize: 14,
           fontWeight: 600,
           opacity: reviewRating > 0 ? 1 : 0.7,
           transform: reviewRating > 0 ? 'scale(1.05)' : 'scale(1)',
           transition: 'all 0.3s ease'
         }}>
           当前评分: {reviewRating} 星
         </div>
            </div>

            <div style={{marginBottom: 24}}>
              <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
                评价内容 (可选)
              </label>
              <textarea
                value={reviewComment}
                onChange={(e) => setReviewComment(e.target.value)}
                placeholder="请分享您对这次任务的体验..."
                style={{
                  width: '100%',
                  minHeight: 100,
                  padding: 12,
                  border: '1px solid #ddd',
                  borderRadius: 8,
                  fontSize: 14,
                  resize: 'vertical'
                }}
              />
            </div>

            <div style={{marginBottom: 24}}>
              <label style={{display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer'}}>
                <input
                  type="checkbox"
                  checked={isAnonymous}
                  onChange={(e) => setIsAnonymous(e.target.checked)}
                  style={{transform: 'scale(1.2)'}}
                />
                <span style={{fontWeight: 600, color: '#333'}}>
                  匿名评价
                </span>
                <span style={{fontSize: 12, color: '#666'}}>
                  (选择匿名后，您的评价将不会显示您的身份信息)
                </span>
              </label>
            </div>

            <div style={{display: 'flex', gap: 12, justifyContent: 'center'}}>
              <button
                onClick={handleSubmitReview}
                disabled={actionLoading}
                style={{
                  background: '#28a745',
                  color: '#fff',
                  border: 'none',
                  borderRadius: 8,
                  padding: '12px 24px',
                  fontWeight: 600,
                  fontSize: 16,
                  cursor: actionLoading ? 'not-allowed' : 'pointer',
                  opacity: actionLoading ? 0.6 : 1
                }}
              >
                {actionLoading ? '提交中...' : '提交评价'}
              </button>
              <button
                onClick={() => {
                  setShowReviewModal(false);
                  setReviewRating(5);
                  setReviewComment('');
                }}
                style={{
                  background: '#6c757d',
                  color: '#fff',
                  border: 'none',
                  borderRadius: 8,
                  padding: '12px 24px',
                  fontWeight: 600,
                  fontSize: 16,
                  cursor: 'pointer'
                }}
              >
                取消
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
      </div>
    </div>
  );
};

export default TaskDetail; 