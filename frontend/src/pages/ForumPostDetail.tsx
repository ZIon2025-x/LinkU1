import React, { useState, useEffect, useCallback, useLayoutEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Spin, Empty, Typography, Space, Tag, Button, Input, Avatar, Divider, message, Modal, Select, Dropdown, QRCode } from 'antd';
import { 
  MessageOutlined, EyeOutlined, LikeOutlined, LikeFilled, 
  StarOutlined, StarFilled, UserOutlined, ClockCircleOutlined,
  EditOutlined, DeleteOutlined, FlagOutlined, ArrowLeftOutlined,
  ShareAltOutlined, CopyOutlined
} from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import { 
  getForumPost, getForumReplies, createForumReply, toggleForumLike, 
  toggleForumFavorite, incrementPostViewCount, deleteForumPost, deleteForumReply,
  createForumReport, fetchCurrentUser, getPublicSystemSettings, logout,
  getForumUnreadNotificationCount
} from '../api';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import SEOHead from '../components/SEOHead';
import ForumPostStructuredData from '../components/ForumPostStructuredData';
import HreflangManager from '../components/HreflangManager';
import BreadcrumbStructuredData from '../components/BreadcrumbStructuredData';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import { formatRelativeTime } from '../utils/timeUtils';
import SafeContent from '../components/SafeContent';
import styles from './ForumPostDetail.module.css';

const { Title, Text } = Typography;
const { TextArea } = Input;
const { Option } = Select;

interface ForumReply {
  id: number;
  content: string;
  author: {
    id: string;
    name: string;
    avatar?: string;
    is_admin?: boolean;
  };
  like_count: number;
  is_liked: boolean;
  created_at: string;
  updated_at: string;
  replies?: ForumReply[];
  parent_reply_id?: number;
}

interface ForumPost {
  id: number;
  title: string;
  content: string;
  category: {
    id: number;
    name: string;
  };
  author: {
    id: string;
    name: string;
    avatar?: string;
    is_admin?: boolean;
  };
  view_count: number;
  reply_count: number;
  like_count: number;
  favorite_count: number;
  is_liked: boolean;
  is_favorited: boolean;
  is_pinned: boolean;
  is_featured: boolean;
  is_locked: boolean;
  created_at: string;
  updated_at: string;
}

const ForumPostDetail: React.FC = () => {
  const { lang: langParam, postId } = useParams<{ lang: string; postId: string }>();
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  
  // 确保 lang 有值，防止路由错误
  const lang = langParam || language || 'zh';
  const { user: currentUser } = useCurrentUser();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  const [post, setPost] = useState<ForumPost | null>(null);
  const [replies, setReplies] = useState<ForumReply[]>([]);
  const [loading, setLoading] = useState(true);
  const [replyLoading, setReplyLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [replyContent, setReplyContent] = useState('');
  const [parentReplyId, setParentReplyId] = useState<number | undefined>(undefined);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount, setUnreadCount] = useState(0);
  const [showReportModal, setShowReportModal] = useState(false);
  const [reportTargetType, setReportTargetType] = useState<'post' | 'reply'>('post');
  const [reportTargetId, setReportTargetId] = useState<number>(0);
  const [reportReason, setReportReason] = useState<string>('');
  const [reportDescription, setReportDescription] = useState<string>('');
  const [showShareModal, setShowShareModal] = useState(false);

  // 计算 SEO 相关数据（必须在所有 hooks 之后，但在 early return 之前）
  const seoTitle = post ? `${post.title} - Link²Ur ${t('forum.title') || 'Forum'}` : 'Link²Ur Forum';
  const seoDescription = post ? post.content.replace(/<[^>]*>/g, '').substring(0, 160) : '';
  // 用于分享的描述（使用全文，移除HTML标签，限制长度在200字符内，微信分享建议不超过200字符）
  const shareDescription = post ? post.content.replace(/<[^>]*>/g, '').trim().substring(0, 200) : '';
  const canonicalUrl = post ? `https://www.link2ur.com/${lang}/forum/post/${post.id}` : `https://www.link2ur.com/${lang}/forum`;

  // 立即移除默认的 meta 标签，避免微信爬虫抓取到默认值
  useLayoutEffect(() => {
    // 移除所有默认的描述标签（包括检查内容是否包含默认文本）
    const removeAllDefaultDescriptions = () => {
      // 移除所有包含默认平台描述的标签
      const allDescriptions = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="twitter:description"], meta[name="weixin:description"]');
      allDescriptions.forEach(tag => {
        const metaTag = tag as HTMLMetaElement;
        if (metaTag.content && (
          metaTag.content.includes('Professional task publishing') ||
          metaTag.content.includes('skill matching platform') ||
          metaTag.content.includes('linking skilled people') ||
          metaTag.content.includes('making value creation more efficient') ||
          metaTag.content === 'Link²Ur' ||
          metaTag.content.includes('Link²Ur Forum')
        )) {
          metaTag.remove();
        }
      });
      
      // 移除默认标题
      const allTitles = document.querySelectorAll('meta[property="og:title"], meta[name="weixin:title"]');
      allTitles.forEach(tag => {
        const metaTag = tag as HTMLMetaElement;
        if (metaTag.content && (metaTag.content === 'Link²Ur' || metaTag.content.includes('Link²Ur Forum'))) {
          metaTag.remove();
        }
      });
      
      // 无条件移除所有微信相关标签（确保清理干净）
      document.querySelectorAll('meta[name="weixin:title"]').forEach(tag => tag.remove());
      document.querySelectorAll('meta[name="weixin:description"]').forEach(tag => tag.remove());
      document.querySelectorAll('meta[name="weixin:image"]').forEach(tag => tag.remove());
    };
    
    // 立即移除所有默认标签
    removeAllDefaultDescriptions();
  }, []);

  // 立即设置微信分享的 meta 标签（使用 useLayoutEffect 确保在 DOM 渲染前执行）
  useLayoutEffect(() => {
    if (!post) return;

    const updateMetaTag = (name: string, content: string, property?: boolean) => {
      const selector = property ? `meta[property="${name}"]` : `meta[name="${name}"]`;
      const allTags = document.querySelectorAll(selector);
      allTags.forEach(tag => tag.remove());
      
      const metaTag = document.createElement('meta');
      if (property) {
        metaTag.setAttribute('property', name);
      } else {
        metaTag.setAttribute('name', name);
      }
      metaTag.content = content;
      document.head.insertBefore(metaTag, document.head.firstChild);
    };

    // 构建帖子详情页的URL
    const postUrl = `${window.location.origin}${window.location.pathname}`;
    
    // 强制更新meta描述（先移除所有旧标签，再插入到head最前面，确保优先被读取）
    const allDescriptions = document.querySelectorAll('meta[name="description"]');
    allDescriptions.forEach(tag => tag.remove());
    const descTag = document.createElement('meta');
    descTag.name = 'description';
    descTag.content = shareDescription;
    document.head.insertBefore(descTag, document.head.firstChild);
    
    // 强制更新og:description（先移除所有旧标签，再插入到head最前面）
    const allOgDescriptions = document.querySelectorAll('meta[property="og:description"]');
    allOgDescriptions.forEach(tag => tag.remove());
    const ogDescTag = document.createElement('meta');
    ogDescTag.setAttribute('property', 'og:description');
    ogDescTag.content = shareDescription;
    document.head.insertBefore(ogDescTag, document.head.firstChild);
    
    // 强制更新twitter:description
    const allTwitterDescriptions = document.querySelectorAll('meta[name="twitter:description"]');
    allTwitterDescriptions.forEach(tag => tag.remove());
    const twitterDescTag = document.createElement('meta');
    twitterDescTag.name = 'twitter:description';
    twitterDescTag.content = shareDescription;
    document.head.insertBefore(twitterDescTag, document.head.firstChild);
    
    // 强制更新微信分享描述（微信优先读取weixin:description）
    // 微信会缓存，所以必须确保每次都强制更新
    const allWeixinDescriptions = document.querySelectorAll('meta[name="weixin:description"]');
    allWeixinDescriptions.forEach(tag => tag.remove());
    const weixinDescTag = document.createElement('meta');
    weixinDescTag.setAttribute('name', 'weixin:description');
    weixinDescTag.content = shareDescription;
    // 插入到head最前面，确保微信爬虫优先读取
    document.head.insertBefore(weixinDescTag, document.head.firstChild);
    
    // 同时设置微信分享标题（微信也会读取）
    const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
    allWeixinTitles.forEach(tag => tag.remove());
    const weixinTitleTag = document.createElement('meta');
    weixinTitleTag.setAttribute('name', 'weixin:title');
    weixinTitleTag.content = post.title;
    document.head.insertBefore(weixinTitleTag, document.head.firstChild);

    // 设置微信分享图片
    const shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
    allWeixinImages.forEach(tag => tag.remove());
    const weixinImageTag = document.createElement('meta');
    weixinImageTag.setAttribute('name', 'weixin:image');
    weixinImageTag.content = shareImageUrl;
    document.head.insertBefore(weixinImageTag, document.head.firstChild);

    // 设置 Open Graph 标签（微信也会读取作为备选）
    const existingOgTitle = document.querySelector('meta[property="og:title"]');
    if (existingOgTitle) {
      existingOgTitle.remove();
    }
    updateMetaTag('og:title', post.title, true);
    updateMetaTag('og:description', shareDescription, true);
    updateMetaTag('og:image', shareImageUrl, true);
    updateMetaTag('og:url', canonicalUrl, true);
    updateMetaTag('og:type', 'article', true);
    updateMetaTag('og:image:width', '1200', true);
    updateMetaTag('og:image:height', '630', true);
    updateMetaTag('og:image:type', 'image/png', true);
    updateMetaTag('og:site_name', 'Link²Ur', true);
    updateMetaTag('og:locale', 'zh_CN', true);

    // 更新Twitter Card标签
    updateMetaTag('twitter:card', 'summary_large_image');
    updateMetaTag('twitter:title', post.title);
    updateMetaTag('twitter:description', shareDescription);
    const existingTwitterImage = document.querySelector('meta[name="twitter:image"]');
    if (existingTwitterImage) {
      existingTwitterImage.remove();
    }
    updateMetaTag('twitter:image', shareImageUrl);
    updateMetaTag('twitter:url', canonicalUrl);

    // 微信分享特殊处理：将重要的meta标签移动到head的前面（确保微信爬虫能读取到）
    // 微信爬虫会优先读取head前面的标签
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
    
    // 将关键标签移到前面（微信优先读取顺序：weixin:title, weixin:description, weixin:image, og:title, og:description, og:image）
    setTimeout(() => {
      // 微信专用标签优先
      moveToTop('meta[name="weixin:title"]');
      moveToTop('meta[name="weixin:description"]');
      moveToTop('meta[name="weixin:image"]');
      // Open Graph标签作为备选
      moveToTop('meta[property="og:title"]');
      moveToTop('meta[property="og:description"]');
      moveToTop('meta[property="og:image"]');
    }, 0);

    // 多次更新确保微信爬虫能读取到（微信爬虫可能在页面加载的不同阶段抓取）
    setTimeout(() => {
      // 再次强制更新微信标签
      const weixinTitle = document.querySelector('meta[name="weixin:title"]') as HTMLMetaElement;
      if (weixinTitle) {
        weixinTitle.content = post.title;
        document.head.insertBefore(weixinTitle, document.head.firstChild);
      }
      const weixinDesc = document.querySelector('meta[name="weixin:description"]') as HTMLMetaElement;
      if (weixinDesc) {
        weixinDesc.content = shareDescription;
        document.head.insertBefore(weixinDesc, document.head.firstChild);
      }
    }, 100);

    setTimeout(() => {
      // 最后一次强制更新
      const weixinTitle = document.querySelector('meta[name="weixin:title"]') as HTMLMetaElement;
      if (weixinTitle) {
        weixinTitle.content = post.title;
        document.head.insertBefore(weixinTitle, document.head.firstChild);
      }
      const weixinDesc = document.querySelector('meta[name="weixin:description"]') as HTMLMetaElement;
      if (weixinDesc) {
        weixinDesc.content = shareDescription;
        document.head.insertBefore(weixinDesc, document.head.firstChild);
      }
    }, 1000);
    
    // 再次更新（确保微信爬虫能抓取到，延迟更长时间确保在其他页面的useLayoutEffect之后执行）
    setTimeout(() => {
      // 移除所有包含默认描述的标签（包括所有类型的描述标签）
      const allDescriptionTags = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="twitter:description"], meta[name="weixin:description"]');
      allDescriptionTags.forEach(tag => {
        const metaTag = tag as HTMLMetaElement;
        if (metaTag.content && (
          metaTag.content.includes('Professional task publishing') ||
          metaTag.content.includes('skill matching platform') ||
          metaTag.content.includes('linking skilled people') ||
          metaTag.content.includes('making value creation more efficient')
        )) {
          metaTag.remove();
        }
      });
      
      // 移除默认标题
      const allTitleTags = document.querySelectorAll('meta[property="og:title"], meta[name="weixin:title"]');
      allTitleTags.forEach(tag => {
        const metaTag = tag as HTMLMetaElement;
        if (metaTag.content && metaTag.content === 'Link²Ur') {
          metaTag.remove();
        }
      });
      
      // 强制移除所有描述标签（包括SEOHead创建的）
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const allOgDesc = document.querySelectorAll('meta[property="og:description"]');
      allOgDesc.forEach(tag => tag.remove());
      const allDesc = document.querySelectorAll('meta[name="description"]');
      allDesc.forEach(tag => tag.remove());
      const allTwitterDesc = document.querySelectorAll('meta[name="twitter:description"]');
      allTwitterDesc.forEach(tag => tag.remove());
      
      // 重新插入正确的帖子描述标签（只使用帖子信息）
      const finalWeixinDesc = document.createElement('meta');
      finalWeixinDesc.setAttribute('name', 'weixin:description');
      finalWeixinDesc.content = shareDescription;
      document.head.insertBefore(finalWeixinDesc, document.head.firstChild);
      
      const finalOgDesc = document.createElement('meta');
      finalOgDesc.setAttribute('property', 'og:description');
      finalOgDesc.content = shareDescription;
      document.head.insertBefore(finalOgDesc, document.head.firstChild);
      
      const finalDesc = document.createElement('meta');
      finalDesc.name = 'description';
      finalDesc.content = shareDescription;
      document.head.insertBefore(finalDesc, document.head.firstChild);
      
      const finalTwitterDesc = document.createElement('meta');
      finalTwitterDesc.name = 'twitter:description';
      finalTwitterDesc.content = shareDescription;
      document.head.insertBefore(finalTwitterDesc, document.head.firstChild);
      
      // 确保微信标题正确
      const allWeixinTitle = document.querySelectorAll('meta[name="weixin:title"]');
      allWeixinTitle.forEach(tag => tag.remove());
      const finalWeixinTitle = document.createElement('meta');
      finalWeixinTitle.setAttribute('name', 'weixin:title');
      finalWeixinTitle.content = post.title;
      document.head.insertBefore(finalWeixinTitle, document.head.firstChild);
    }, 2000); // 延迟2秒，确保在SEOHead执行后更新
  }, [post, shareDescription, canonicalUrl]);

  // 立即更新微信分享 meta 标签的函数
  const updateWeixinMetaTags = useCallback(() => {
    if (!post) return;
    
    // 限制描述长度在200字符内（微信分享建议不超过200字符）
    const currentShareDescription = post.content.replace(/<[^>]*>/g, '').trim().substring(0, 200);
    const shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    
    // 强制移除所有描述标签（无条件移除，确保清理干净）
    const allDescriptions = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="twitter:description"], meta[name="weixin:description"]');
    allDescriptions.forEach(tag => tag.remove());
    
    // 强制更新微信分享描述（微信优先读取weixin:description）
    const weixinDescTag = document.createElement('meta');
    weixinDescTag.setAttribute('name', 'weixin:description');
    weixinDescTag.content = currentShareDescription;
    document.head.insertBefore(weixinDescTag, document.head.firstChild);
    
    // 强制更新微信分享标题
    const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
    allWeixinTitles.forEach(tag => tag.remove());
    const weixinTitleTag = document.createElement('meta');
    weixinTitleTag.setAttribute('name', 'weixin:title');
    weixinTitleTag.content = post.title;
    document.head.insertBefore(weixinTitleTag, document.head.firstChild);
    
    // 强制更新微信分享图片
    const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
    allWeixinImages.forEach(tag => tag.remove());
    const weixinImageTag = document.createElement('meta');
    weixinImageTag.setAttribute('name', 'weixin:image');
    weixinImageTag.content = shareImageUrl;
    document.head.insertBefore(weixinImageTag, document.head.firstChild);
    
    // 同时更新 Open Graph 标签
    const allOgDescriptions = document.querySelectorAll('meta[property="og:description"]');
    allOgDescriptions.forEach(tag => tag.remove());
    const ogDescTag = document.createElement('meta');
    ogDescTag.setAttribute('property', 'og:description');
    ogDescTag.content = currentShareDescription;
    document.head.insertBefore(ogDescTag, document.head.firstChild);
    
    const existingOgTitle = document.querySelector('meta[property="og:title"]');
    if (existingOgTitle) {
      existingOgTitle.remove();
    }
    const ogTitleTag = document.createElement('meta');
    ogTitleTag.setAttribute('property', 'og:title');
    ogTitleTag.content = post.title;
    document.head.insertBefore(ogTitleTag, document.head.firstChild);
    
    const existingOgImage = document.querySelector('meta[property="og:image"]');
    if (existingOgImage) {
      existingOgImage.remove();
    }
    const ogImageTag = document.createElement('meta');
    ogImageTag.setAttribute('property', 'og:image');
    ogImageTag.content = shareImageUrl;
    document.head.insertBefore(ogImageTag, document.head.firstChild);
  }, [post]);

  // 当显示分享模态框时，立即更新微信分享 meta 标签
  useEffect(() => {
    if (showShareModal && post) {
      // 立即更新 meta 标签，确保微信爬虫能读取到最新值
      updateWeixinMetaTags();
      
      // 多次更新确保微信爬虫能读取到
      setTimeout(() => {
        updateWeixinMetaTags();
      }, 100);
      
      setTimeout(() => {
        updateWeixinMetaTags();
      }, 500);
    }
  }, [showShareModal, post, updateWeixinMetaTags]);

  useEffect(() => {
    if (postId) {
      loadPost();
      loadReplies();
      // 增加浏览数
      incrementPostViewCount(Number(postId)).catch(() => {});
    }
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error: any) {
        setUser(null);
      }
    };
    loadUserData();
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
    
    // 加载未读通知数量
    const loadUnreadCount = async () => {
      try {
        const response = await getForumUnreadNotificationCount();
        setUnreadCount(response.unread_count || 0);
      } catch (error: any) {
        setUnreadCount(0);
      }
    };
    if (currentUser) {
      loadUnreadCount();
    }
  }, [postId, currentPage, currentUser]);

  const loadPost = async () => {
    try {
      setLoading(true);
      const response = await getForumPost(Number(postId));
      setPost(response);
    } catch (error: any) {
      console.error('加载帖子失败:', error);
      message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setLoading(false);
    }
  };

  const loadReplies = async () => {
    try {
      const response = await getForumReplies(Number(postId), {
        page: currentPage,
        page_size: 50
      });
      setReplies(response.replies || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      console.error('加载回复失败:', error);
    }
  };

  const handleLike = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    try {
      const response = await toggleForumLike('post', Number(postId));
      // 直接更新本地状态，避免重新加载导致页面滚动
      if (post) {
        setPost({
          ...post,
          is_liked: response.liked,
          like_count: response.like_count
        });
      }
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleFavorite = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    try {
      const response = await toggleForumFavorite(Number(postId));
      // 直接更新本地状态，避免重新加载导致页面滚动
      if (post) {
        setPost({
          ...post,
          is_favorited: response.favorited,
          favorite_count: response.favorite_count
        });
      }
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleReplyLike = async (replyId: number, e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    try {
      const response = await toggleForumLike('reply', replyId);
      // 直接更新本地状态，避免重新加载导致页面滚动
      setReplies(prevReplies => {
        const updateReply = (reply: ForumReply): ForumReply => {
          if (reply.id === replyId) {
            return {
              ...reply,
              is_liked: response.liked,
              like_count: response.like_count
            };
          }
          if (reply.replies && reply.replies.length > 0) {
            return {
              ...reply,
              replies: reply.replies.map(updateReply)
            };
          }
          return reply;
        };
        return prevReplies.map(updateReply);
      });
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleSubmitReply = async () => {
    if (!currentUser) {
      setShowLoginModal(true);
      return;
    }
    if (!replyContent.trim()) {
      message.warning(t('forum.replyPlaceholder'));
      return;
    }
    if (post?.is_locked) {
      message.warning(t('forum.postLocked'));
      return;
    }
    try {
      setReplyLoading(true);
      await createForumReply(Number(postId), {
        content: replyContent,
        parent_reply_id: parentReplyId
      });
      message.success(t('forum.createSuccess'));
      setReplyContent('');
      setParentReplyId(undefined);
      loadReplies();
      loadPost(); // 更新回复数
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    } finally {
      setReplyLoading(false);
    }
  };

  const handleDeletePost = () => {
    Modal.confirm({
      title: t('forum.confirmDelete'),
      content: t('forum.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await deleteForumPost(Number(postId));
          message.success(t('forum.deleteSuccess'));
          navigate(`/${lang}/forum/category/${post?.category.id}`);
        } catch (error: any) {
          message.error(error.response?.data?.detail || t('forum.error'));
        }
      }
    });
  };

  const handleDeleteReply = (replyId: number) => {
    Modal.confirm({
      title: t('forum.confirmDelete'),
      content: t('forum.confirmDeleteMessage'),
      onOk: async () => {
        try {
          await deleteForumReply(replyId);
          message.success(t('forum.deleteSuccess'));
          loadReplies();
          loadPost();
        } catch (error: any) {
          message.error(error.response?.data?.detail || t('forum.error'));
        }
      }
    });
  };

  const handleReport = (targetType: 'post' | 'reply', targetId: number) => {
    setReportTargetType(targetType);
    setReportTargetId(targetId);
    setReportReason('');
    setReportDescription('');
    setShowReportModal(true);
  };

  const handleSubmitReport = async () => {
    if (!reportReason) {
      message.warning(t('forum.reportReason'));
      return;
    }
    try {
      await createForumReport({
        target_type: reportTargetType,
        target_id: reportTargetId,
        reason: reportReason,
        description: reportDescription || undefined
      });
      message.success(t('forum.reportSuccess'));
      setShowReportModal(false);
      setReportReason('');
      setReportDescription('');
    } catch (error: any) {
      message.error(error.response?.data?.detail || t('forum.error'));
    }
  };

  const handleShare = async () => {
    if (!post) return;
    
    // 计算分享描述（确保与组件顶层定义一致）
    const currentShareDescription = post.content.replace(/<[^>]*>/g, '').trim().substring(0, 200);
    
    // 立即更新微信分享 meta 标签，确保微信爬虫能读取到最新值
    updateWeixinMetaTags();
    
    // 强制移除所有描述标签（包括默认的和SEOHead创建的）
    const allDescriptionTags = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="twitter:description"], meta[name="weixin:description"]');
    allDescriptionTags.forEach(tag => tag.remove());
    
    // 立即重新设置正确的描述（使用帖子内容）
    const finalWeixinDesc = document.createElement('meta');
    finalWeixinDesc.setAttribute('name', 'weixin:description');
    finalWeixinDesc.content = currentShareDescription;
    document.head.insertBefore(finalWeixinDesc, document.head.firstChild);
    
    const finalOgDesc = document.createElement('meta');
    finalOgDesc.setAttribute('property', 'og:description');
    finalOgDesc.content = currentShareDescription;
    document.head.insertBefore(finalOgDesc, document.head.firstChild);
    
    const finalDesc = document.createElement('meta');
    finalDesc.name = 'description';
    finalDesc.content = currentShareDescription;
    document.head.insertBefore(finalDesc, document.head.firstChild);
    
    const finalTwitterDesc = document.createElement('meta');
    finalTwitterDesc.name = 'twitter:description';
    finalTwitterDesc.content = currentShareDescription;
    document.head.insertBefore(finalTwitterDesc, document.head.firstChild);
    
    // 多次更新，确保微信爬虫能读取到
    setTimeout(() => {
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const newWeixinDesc = document.createElement('meta');
      newWeixinDesc.setAttribute('name', 'weixin:description');
      newWeixinDesc.content = currentShareDescription;
      document.head.insertBefore(newWeixinDesc, document.head.firstChild);
    }, 100);
    
    setTimeout(() => {
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const newWeixinDesc = document.createElement('meta');
      newWeixinDesc.setAttribute('name', 'weixin:description');
      newWeixinDesc.content = currentShareDescription;
      document.head.insertBefore(newWeixinDesc, document.head.firstChild);
    }, 500);
    
    const shareUrl = `${window.location.origin}/${lang}/forum/post/${post.id}`;
    const shareTitle = post.title;
    const shareText = `${shareTitle}\n\n${currentShareDescription}\n\n${shareUrl}`;
    
    // 尝试使用 Web Share API
    if (navigator.share) {
      try {
        await navigator.share({
          title: shareTitle,
          text: shareText,
          url: shareUrl
        });
        message.success(t('forum.shareSuccess'));
        return;
      } catch (error: any) {
        // 用户取消分享，不做任何操作
        if (error.name === 'AbortError') {
          return;
        }
        // 如果出错，继续执行复制链接逻辑
      }
    }
    
    // 如果不支持 Web Share API 或失败，显示分享模态框
    // 在显示模态框前立即更新 meta 标签，确保微信爬虫能读取到最新值
    updateWeixinMetaTags();
    setShowShareModal(true);
  };

  const handleCopyLink = async () => {
    if (!post) return;
    const shareUrl = `${window.location.origin}/${lang}/forum/post/${post.id}`;
    try {
      await navigator.clipboard.writeText(shareUrl);
      message.success(t('forum.linkCopied'));
      setShowShareModal(false);
    } catch (error) {
      message.error(t('forum.error'));
    }
  };

  const handleShareToSocial = (platform: string) => {
    if (!post) return;
    
    // 计算分享描述（限制在200字符内）
    const currentShareDescription = post.content.replace(/<[^>]*>/g, '').trim().substring(0, 200);
    
    // 如果是微信分享（通过二维码），立即更新 meta 标签
    if (platform === 'wechat') {
      updateWeixinMetaTags();
      
      // 强制更新微信描述标签
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const newWeixinDesc = document.createElement('meta');
      newWeixinDesc.setAttribute('name', 'weixin:description');
      newWeixinDesc.content = currentShareDescription;
      document.head.insertBefore(newWeixinDesc, document.head.firstChild);
    }
    
    const shareUrl = encodeURIComponent(`${window.location.origin}/${lang}/forum/post/${post.id}`);
    const shareTitle = encodeURIComponent(post.title);
    const shareDescription = encodeURIComponent(currentShareDescription);
    
    let shareWindowUrl = '';
    
    switch (platform) {
      case 'weibo':
        // 微博分享：标题和描述组合
        shareWindowUrl = `https://service.weibo.com/share/share.php?url=${shareUrl}&title=${shareTitle} ${shareDescription}`;
        break;
      case 'twitter':
        // Twitter分享：标题和描述组合
        shareWindowUrl = `https://twitter.com/intent/tweet?url=${shareUrl}&text=${shareTitle} ${shareDescription}`;
        break;
      case 'facebook':
        // Facebook分享：使用标题和描述
        shareWindowUrl = `https://www.facebook.com/sharer/sharer.php?u=${shareUrl}&quote=${shareTitle} ${shareDescription}`;
        break;
      default:
        return;
    }
    
    if (shareWindowUrl) {
      window.open(shareWindowUrl, '_blank', 'width=600,height=400');
    }
    setShowShareModal(false);
  };

  const renderReply = (reply: ForumReply, level: number = 0) => {
    if (level > 2) return null; // 最多3层嵌套
    
    return (
      <div key={reply.id} className={styles.replyItem} style={{ marginLeft: level * 24 }}>
        <div className={styles.replyHeader}>
          <Space>
            <Avatar 
              src={reply.author.avatar} 
              icon={<UserOutlined />}
              size="small"
              style={{ cursor: 'pointer' }}
              onClick={() => navigate(`/${lang}/user/${reply.author.id}`)}
            />
            <Text 
              strong
              style={{ cursor: 'pointer' }}
              onClick={() => navigate(`/${lang}/user/${reply.author.id}`)}
            >
              {reply.author.name}
            </Text>
            {reply.author.is_admin && (
              <Tag color="blue" style={{ marginLeft: 8, fontSize: 11 }}>{t('forum.official')}</Tag>
            )}
            <Text type="secondary" style={{ fontSize: 12 }}>
              <ClockCircleOutlined /> {formatRelativeTime(reply.created_at)}
            </Text>
          </Space>
          <Space>
            <Button
              htmlType="button"
              type="text"
              size="small"
              icon={reply.is_liked ? <LikeFilled /> : <LikeOutlined />}
              onClick={(e) => handleReplyLike(reply.id, e)}
              aria-label={reply.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
              title={reply.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
            >
              {reply.like_count}
            </Button>
            {currentUser && (
              <Button
                type="text"
                size="small"
                onClick={() => setParentReplyId(reply.id)}
              >
                {t('forum.reply')}
              </Button>
            )}
            {currentUser && currentUser.id === reply.author.id && (
              <Button
                type="text"
                size="small"
                danger
                onClick={() => handleDeleteReply(reply.id)}
              >
                {t('common.delete')}
              </Button>
            )}
            {currentUser && (
              <Button
                type="text"
                size="small"
                icon={<FlagOutlined />}
                onClick={() => handleReport('reply', reply.id)}
              />
            )}
          </Space>
        </div>
        <div className={styles.replyContent}>
          <SafeContent content={reply.content} />
        </div>
        {reply.replies && reply.replies.length > 0 && (
          <div className={styles.nestedReplies}>
            {reply.replies.map((nestedReply) => renderReply(nestedReply, level + 1))}
          </div>
        )}
      </div>
    );
  };

  if (loading) {
    return (
      <div className={styles.container}>
        <header className={styles.header}>
          <div className={styles.headerContainer}>
            <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
              Link²Ur
            </div>
            <div className={styles.headerActions}>
              <LanguageSwitcher />
              <NotificationButton 
                user={user}
                unreadCount={unreadCount}
                onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
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
        <div className={styles.headerSpacer} />
        <div className={styles.loadingContainer}>
          <Spin size="large" />
        </div>
      </div>
    );
  }

  if (!post) {
    return (
      <div className={styles.container}>
        <header className={styles.header}>
          <div className={styles.headerContainer}>
            <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
              Link²Ur
            </div>
            <div className={styles.headerActions}>
              <LanguageSwitcher />
              <NotificationButton 
                user={user}
                unreadCount={unreadCount}
                onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
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
        <div className={styles.headerSpacer} />
        <Empty description={t('forum.error')} />
      </div>
    );
  }

  const breadcrumbItems = post ? [
    { 
      name: language === 'zh' ? '首页' : 'Home', 
      url: `https://www.link2ur.com/${lang}` 
    },
    { 
      name: language === 'zh' ? '论坛' : 'Forum', 
      url: `https://www.link2ur.com/${lang}/forum` 
    },
    { 
      name: post.category?.name || (language === 'zh' ? '帖子' : 'Post'), 
      url: post.category ? `https://www.link2ur.com/${lang}/forum/category/${post.category.id}` : `https://www.link2ur.com/${lang}/forum`
    },
    { 
      name: post.title, 
      url: canonicalUrl 
    }
  ] : [];

  return (
    <div className={styles.container}>
      {/* SEO 组件 */}
      {post && (
        <>
          <SEOHead 
            title={seoTitle}
            description={seoDescription}
            keywords={`${post.category?.name || ''},论坛,讨论,${t('forum.title') || 'Forum'}`}
            canonicalUrl={canonicalUrl}
            ogTitle={post.title}
            ogDescription={shareDescription}
            ogImage={`https://www.link2ur.com/static/favicon.png`}
            ogUrl={canonicalUrl}
            twitterTitle={post.title}
            twitterDescription={shareDescription}
            twitterImage={`https://www.link2ur.com/static/favicon.png`}
          />
          <ForumPostStructuredData 
            post={{
              id: post.id,
              title: post.title,
              content: post.content,
              author: {
                id: post.author.id,
                name: post.author.name
              },
              created_at: post.created_at,
              updated_at: post.updated_at,
              view_count: post.view_count,
              like_count: post.like_count,
              category: post.category?.name
            }}
            language={lang}
          />
          <HreflangManager type="forum-post" id={post.id} />
          {breadcrumbItems.length > 0 && (
            <BreadcrumbStructuredData items={breadcrumbItems} />
          )}
        </>
      )}
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          <div className={styles.logo} onClick={() => navigate(`/${lang}/forum`)} style={{ cursor: 'pointer' }}>
            Link²Ur
          </div>
          <div className={styles.headerActions}>
            <LanguageSwitcher />
            <NotificationButton 
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => navigate(`/${lang}/forum/notifications`)}
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
      <div className={styles.headerSpacer} />

      <div className={styles.content}>
        <Card className={styles.postCard}>
          <div className={styles.postHeader}>
            <div className={styles.postTitleRow}>
              {post.is_pinned && <Tag color="red">{t('forum.pinned')}</Tag>}
              {post.is_featured && <Tag color="gold">{t('forum.featured')}</Tag>}
              {post.is_locked && <Tag color="orange">{t('forum.locked')}</Tag>}
              <Title level={2}>{post.title}</Title>
            </div>
            {currentUser && currentUser.id === post.author.id && (
              <Space>
                <Button
                  type="link"
                  icon={<EditOutlined />}
                  onClick={() => navigate(`/${lang}/forum/post/${postId}/edit`)}
                >
                  {t('forum.editPost')}
                </Button>
                <Button
                  type="link"
                  danger
                  icon={<DeleteOutlined />}
                  onClick={handleDeletePost}
                >
                  {t('forum.deletePost')}
                </Button>
              </Space>
            )}
          </div>

          <div className={styles.postMeta}>
            <Space split="|">
              <Space>
                <Avatar 
                  src={post.author.avatar} 
                  icon={<UserOutlined />}
                  style={{ cursor: 'pointer' }}
                  onClick={() => navigate(`/${lang}/user/${post.author.id}`)}
                />
                <Text 
                  strong 
                  style={{ cursor: 'pointer' }}
                  onClick={() => navigate(`/${lang}/user/${post.author.id}`)}
                >
                  {post.author.name}
                </Text>
                {post.author.is_admin && (
                  <Tag color="blue" style={{ marginLeft: 8 }}>{t('forum.official')}</Tag>
                )}
              </Space>
              <Text type="secondary">
                <ClockCircleOutlined /> {formatRelativeTime(post.created_at)}
              </Text>
              <Text type="secondary">
                <EyeOutlined /> {post.view_count}
              </Text>
            </Space>
          </div>

          <Divider />

          <div className={styles.postContent}>
            <SafeContent content={post.content} />
          </div>

          <Divider />

          <div className={styles.postActions}>
            <Space size="large">
              <Button
                htmlType="button"
                type={post.is_liked ? 'primary' : 'default'}
                icon={post.is_liked ? <LikeFilled /> : <LikeOutlined />}
                onClick={handleLike}
                aria-label={post.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
                title={post.is_liked ? t('forum.unlike') || '取消点赞' : t('forum.like') || '点赞'}
              >
                {post.like_count}
              </Button>
              <Button
                htmlType="button"
                type={post.is_favorited ? 'primary' : 'default'}
                icon={post.is_favorited ? <StarFilled /> : <StarOutlined />}
                onClick={handleFavorite}
                aria-label={post.is_favorited ? t('forum.unfavorite') || '取消收藏' : t('forum.favorite') || '收藏'}
                title={post.is_favorited ? t('forum.unfavorite') || '取消收藏' : t('forum.favorite') || '收藏'}
              >
                {post.favorite_count}
              </Button>
              <Text type="secondary">
                <MessageOutlined /> {post.reply_count} {t('forum.replies')}
              </Text>
              <Button
                htmlType="button"
                type="default"
                icon={<ShareAltOutlined />}
                onClick={handleShare}
                title={t('forum.share') || '分享'}
              >
                {t('forum.share')}
              </Button>
              {currentUser && (
                <Button
                  type="text"
                  icon={<FlagOutlined />}
                  onClick={() => handleReport('post', post.id)}
                >
                  {t('forum.report')}
                </Button>
              )}
            </Space>
          </div>
        </Card>

        <Card title={t('forum.replies')} className={styles.repliesCard}>
          {replies.length === 0 ? (
            <Empty description={t('forum.noReplies')} />
          ) : (
            <div className={styles.repliesList}>
              {replies.map((reply) => renderReply(reply))}
            </div>
          )}
        </Card>

        {!post.is_locked && (
          <Card title={parentReplyId ? t('forum.replyTo') : t('forum.writeReply')} className={styles.replyCard}>
            {parentReplyId && (
              <div className={styles.replyToHint}>
                <Text type="secondary">
                  {t('forum.replyingTo')} #{parentReplyId}
                  <Button
                    type="link"
                    size="small"
                    onClick={() => setParentReplyId(undefined)}
                  >
                    {t('common.cancel')}
                  </Button>
                </Text>
              </div>
            )}
            <TextArea
              id="reply-content"
              rows={4}
              placeholder={t('forum.replyPlaceholder')}
              value={replyContent}
              onChange={(e) => setReplyContent(e.target.value)}
              maxLength={10000}
              showCount
              aria-label={t('forum.replyPlaceholder')}
            />
            <div className={styles.replyActions}>
              <Button
                type="primary"
                loading={replyLoading}
                onClick={handleSubmitReply}
              >
                {t('forum.submit')}
              </Button>
            </div>
          </Card>
        )}

        {post.is_locked && (
          <Card>
            <Text type="warning">{t('forum.postLockedMessage')}</Text>
          </Card>
        )}
      </div>

      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
      />

      <Modal
        title={t('forum.report')}
        open={showReportModal}
        onOk={handleSubmitReport}
        onCancel={() => {
          setShowReportModal(false);
          setReportReason('');
          setReportDescription('');
        }}
        okText={t('common.submit')}
        cancelText={t('common.cancel')}
      >
        <div style={{ marginBottom: '16px' }}>
          <label htmlFor="report-reason" style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>
            {t('forum.reportReason')} *
          </label>
          <Select
            id="report-reason"
            value={reportReason}
            onChange={(value) => setReportReason(value)}
            style={{ width: '100%' }}
            placeholder={t('forum.reportReason')}
            aria-label={t('forum.reportReason')}
          >
            <Option value="spam">{t('forum.reasonSpam')}</Option>
            <Option value="fraud">{t('forum.reasonFraud')}</Option>
            <Option value="inappropriate">{t('forum.reasonInappropriate')}</Option>
            <Option value="other">{t('forum.reasonOther')}</Option>
          </Select>
        </div>
        <div>
          <label htmlFor="report-description" style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>
            {t('forum.reportDescription')}
          </label>
          <TextArea
            id="report-description"
            value={reportDescription}
            onChange={(e) => setReportDescription(e.target.value)}
            rows={4}
            aria-label={t('forum.reportDescription')}
            placeholder={t('forum.reportDescriptionPlaceholder')}
            maxLength={500}
            showCount
          />
        </div>
      </Modal>

      <Modal
        title={t('forum.sharePost')}
        open={showShareModal}
        onCancel={() => setShowShareModal(false)}
        footer={null}
      >
        <Space direction="vertical" style={{ width: '100%' }} size="large" align="center">
          {post && (
            <div style={{ textAlign: 'center' }}>
              <QRCode
                value={`${window.location.origin}/${lang}/forum/post/${post.id}`}
                size={200}
                style={{ marginBottom: 16 }}
              />
              <Text type="secondary" style={{ fontSize: 12 }}>
                {t('forum.shareToWeChat')}
              </Text>
            </div>
          )}
          <Divider />
          <Space direction="vertical" style={{ width: '100%' }} size="middle">
            <Button
              type="default"
              icon={<CopyOutlined />}
              onClick={handleCopyLink}
              block
            >
              {t('forum.copyLink')}
            </Button>
            <Button
              type="default"
              onClick={() => handleShareToSocial('weibo')}
              block
            >
              {t('forum.shareToWeibo')}
            </Button>
            <Button
              type="default"
              onClick={() => handleShareToSocial('twitter')}
              block
            >
              {t('forum.shareToTwitter')}
            </Button>
            <Button
              type="default"
              onClick={() => handleShareToSocial('facebook')}
              block
            >
              {t('forum.shareToFacebook')}
            </Button>
          </Space>
        </Space>
      </Modal>
    </div>
  );
};

export default ForumPostDetail;

