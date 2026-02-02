import React, { useState, useEffect, useRef, useLayoutEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Button, Input, Space, Tag, Spin, Empty, Modal, Form, message, Checkbox, Select, Pagination, Image, Upload, QRCode, Typography, Divider } from 'antd';
import { LikeOutlined, DislikeOutlined, PlusOutlined, TrophyOutlined, UploadOutlined, ExclamationCircleOutlined, ShareAltOutlined, CopyOutlined } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { getErrorMessage } from '../utils/errorHandler';
import { validateName } from '../utils/inputValidators';
import { formatViewCount } from '../utils/formatUtils';
import {
  getCustomLeaderboardDetail,
  getLeaderboardItems,
  submitLeaderboardItem,
  voteLeaderboardItem,
  reportLeaderboard
} from '../api';
import { fetchCurrentUser, getPublicSystemSettings, logout } from '../api';
import { compressImage } from '../utils/imageCompression';
import { formatImageUrl } from '../utils/imageUtils';
import api from '../api';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import SEOHead from '../components/SEOHead';
import HreflangManager from '../components/HreflangManager';
import BreadcrumbStructuredData from '../components/BreadcrumbStructuredData';
import MemberBadge from '../components/MemberBadge';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import styles from './ForumLeaderboard.module.css';

const { Option } = Select;
const { Text } = Typography;

const CustomLeaderboardDetail: React.FC = () => {
  const { lang: langParam, leaderboardId } = useParams<{ lang: string; leaderboardId: string }>();
  const { t, language } = useLanguage();
  const navigate = useNavigate();
  const lang = langParam || language || 'zh';
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  const [leaderboard, setLeaderboard] = useState<any>(null);
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [showSubmitModal, setShowSubmitModal] = useState(false);
  const [showVoteModal, setShowVoteModal] = useState(false);
  const [currentVoteItemId, setCurrentVoteItemId] = useState<number | null>(null);
  const [currentVoteType, setCurrentVoteType] = useState<'upvote' | 'downvote' | null>(null);
  const [user, setUser] = useState<any>(null);
  const [form] = Form.useForm();
  const [voteForm] = Form.useForm();
  const [reportForm] = Form.useForm();
  const [showReportModal, setShowReportModal] = useState(false);
  const [sortBy, setSortBy] = useState<'vote_score' | 'net_votes' | 'upvotes' | 'created_at'>('vote_score');
  const [pagination, setPagination] = useState({
    current: 1,
    pageSize: 20,
    total: 0,
    hasMore: false
  });
  const [uploadingImages, setUploadingImages] = useState<string[]>([]);
  const [uploading, setUploading] = useState(false);
  const [uploadingFileList, setUploadingFileList] = useState<any[]>([]);
  const previewUrlsRef = useRef<Set<string>>(new Set());
  const [systemSettings, setSystemSettings] = useState<any>({ vip_button_visible: false });
  const [unreadCount] = useState(0);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);

  // 生成分享描述（在榜单描述后追加提示文字）
  const getShareDescription = (description: string | null | undefined): string => {
    const appendText = "✨ 真实留学生评价，禁止刷票。欢迎在英留学生投下真实一票与真实评价，帮助新生开启更好的留学生活！";
    const maxLength = 200;
    
    if (!description) {
      return appendText.substring(0, maxLength);
    }
    
    // 计算可用长度（减去追加文字和分隔符）
    const availableLength = maxLength - appendText.length - 3; // 3个字符用于分隔符 " - "
    
    if (description.length <= availableLength) {
      return `${description} - ${appendText}`;
    } else {
      const truncated = description.substring(0, availableLength);
      return `${truncated}... - ${appendText}`;
    }
  };

  // 修复：使用正确的路由路径 /leaderboard/custom/:leaderboardId
  const canonicalUrl = leaderboard ? `https://www.link2ur.com/${lang}/leaderboard/custom/${leaderboard.id}` : `https://www.link2ur.com/${lang}/forum/leaderboard`;
  
  // SEO相关变量
  const seoTitle = leaderboard ? `${leaderboard.name} - ${leaderboard.location} | ${t('forum.leaderboardTitle')}` : t('forum.leaderboardTitle');
  const seoDescription = leaderboard && leaderboard.description 
    ? `${leaderboard.description.substring(0, 160)} | ${leaderboard.location} | ${leaderboard.item_count}${t('forum.itemsCount')}`
    : t('forum.leaderboardPlatform');
  const seoKeywords = leaderboard 
    ? `${leaderboard.name},${leaderboard.location},${t('forum.leaderboard')},${t('forum.leaderboardKeywords')}`
    : t('forum.leaderboardKeywords');
  
  // 面包屑导航数据
  const breadcrumbItems = leaderboard ? [
    { name: t('common.home'), url: `https://www.link2ur.com/${lang}` },
    { name: t('forum.leaderboard'), url: `https://www.link2ur.com/${lang}/forum/leaderboard` },
    { name: leaderboard.name, url: canonicalUrl }
  ] : [];

  // SEO优化：使用useLayoutEffect确保在DOM渲染前就设置meta标签，优先级最高
  // 参考任务分享的实现方式
  useLayoutEffect(() => {
    // 首先移除所有默认的描述标签（在设置新标签之前，确保不会被默认标签覆盖）
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
    };
    
    // 立即移除所有默认标签
    removeAllDefaultDescriptions();
    
    if (!leaderboard) return;
    
    // 使用辅助函数生成分享描述（在榜单描述后追加提示文字）
    const currentShareDescription = getShareDescription(leaderboard.description);
    
    // 图片优先使用榜单封面图片（cover_image），如果没有则使用默认logo
    // 参考任务分享的逻辑：优先使用任务图片，否则使用默认logo
    let shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    if (leaderboard.cover_image) {
      // 确保图片URL是绝对路径
      const coverImageUrl = leaderboard.cover_image;
      
      // 处理URL格式：可能是完整URL、相对路径或包含域名的路径
      if (coverImageUrl.startsWith('http://') || coverImageUrl.startsWith('https://')) {
        // 已经是完整URL，确保添加版本号避免缓存
        shareImageUrl = coverImageUrl.includes('?') ? coverImageUrl : `${coverImageUrl}?v=2`;
      } else if (coverImageUrl.startsWith('//')) {
        // 协议相对URL，需要添加https:
        shareImageUrl = `https:${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      } else if (coverImageUrl.startsWith('/')) {
        // 绝对路径，拼接域名
        shareImageUrl = `${window.location.origin}${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      } else if (coverImageUrl.includes('://')) {
        // 包含协议但格式不标准，尝试提取
        const match = coverImageUrl.match(/https?:\/\/[^\s]+/);
        if (match) {
          shareImageUrl = match[0];
          if (!shareImageUrl.includes('?')) {
            shareImageUrl = `${shareImageUrl}?v=2`;
          }
        } else {
          shareImageUrl = `${window.location.origin}/${coverImageUrl}`;
          if (!shareImageUrl.includes('?')) {
            shareImageUrl = `${shareImageUrl}?v=2`;
          }
        }
      } else {
        // 相对路径，拼接域名
        shareImageUrl = `${window.location.origin}/${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      }
    }
    
    // 分享标题：榜单名称 + 平台名称
    const shareTitle = `${leaderboard.name} - ${t('forum.leaderboardTitle')}`;
    
    // 更新页面标题
    const pageTitle = `${shareTitle} - Link²Ur`;
    document.title = pageTitle;
    
    // 辅助函数：更新meta标签
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
    
    // 强制更新meta描述（先移除所有旧标签，再插入到head最前面）
    const allDescriptions = document.querySelectorAll('meta[name="description"]');
    allDescriptions.forEach(tag => tag.remove());
    const descTag = document.createElement('meta');
    descTag.name = 'description';
    descTag.content = currentShareDescription;
    document.head.insertBefore(descTag, document.head.firstChild);
    
    // 强制更新og:description（先移除所有旧标签，再插入到head最前面）
    const allOgDescriptions = document.querySelectorAll('meta[property="og:description"]');
    allOgDescriptions.forEach(tag => tag.remove());
    const ogDescTag = document.createElement('meta');
    ogDescTag.setAttribute('property', 'og:description');
    ogDescTag.content = currentShareDescription;
    document.head.insertBefore(ogDescTag, document.head.firstChild);
    
    // 强制更新twitter:description
    const allTwitterDescriptions = document.querySelectorAll('meta[name="twitter:description"]');
    allTwitterDescriptions.forEach(tag => tag.remove());
    const twitterDescTag = document.createElement('meta');
    twitterDescTag.name = 'twitter:description';
    twitterDescTag.content = currentShareDescription;
    document.head.insertBefore(twitterDescTag, document.head.firstChild);
    
    // 强制更新微信分享描述（微信优先读取weixin:description）
    // 微信会缓存，所以必须确保每次都强制更新
    const allWeixinDescriptions = document.querySelectorAll('meta[name="weixin:description"]');
    allWeixinDescriptions.forEach(tag => tag.remove());
    const weixinDescTag = document.createElement('meta');
    weixinDescTag.setAttribute('name', 'weixin:description');
    weixinDescTag.content = currentShareDescription;
    // 插入到head最前面，确保微信爬虫优先读取
    document.head.insertBefore(weixinDescTag, document.head.firstChild);
    
    // 同时设置微信分享标题（微信也会读取）
    const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
    allWeixinTitles.forEach(tag => tag.remove());
    const weixinTitleTag = document.createElement('meta');
    weixinTitleTag.setAttribute('name', 'weixin:title');
    weixinTitleTag.content = shareTitle;
    document.head.insertBefore(weixinTitleTag, document.head.firstChild);
    
    // 更新Open Graph标签（用于社交媒体分享，包括微信）
    // 注意：微信会缓存这些标签，所以必须确保每次都更新
    updateMetaTag('og:type', 'website', true);
    
    // 强制更新og:title
    const existingOgTitle = document.querySelector('meta[property="og:title"]');
    if (existingOgTitle) {
      existingOgTitle.remove();
    }
    updateMetaTag('og:title', shareTitle, true);
    
    updateMetaTag('og:url', canonicalUrl, true);
    
    // 设置分享图片（优先使用榜单封面图片，否则使用默认logo图片）
    // 与任务详情页保持一致，直接使用 shareImageUrl，不创建 finalShareImageUrl
    
    // 强制更新og:image（通过先移除再添加的方式）
    const existingOgImage = document.querySelector('meta[property="og:image"]');
    if (existingOgImage) {
      existingOgImage.remove();
    }
    updateMetaTag('og:image', shareImageUrl, true);
    updateMetaTag('og:image:width', '1200', true);
    updateMetaTag('og:image:height', '630', true);
    updateMetaTag('og:image:type', 'image/png', true);
    updateMetaTag('og:image:alt', shareTitle, true);
    updateMetaTag('og:site_name', 'Link²Ur', true);
    updateMetaTag('og:locale', 'zh_CN', true);
    
    // 强制更新微信分享图片（微信优先读取weixin:image）
    // 与任务详情页保持一致，直接使用 shareImageUrl
    const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
    allWeixinImages.forEach(tag => tag.remove());
    const weixinImageTag = document.createElement('meta');
    weixinImageTag.setAttribute('name', 'weixin:image');
    weixinImageTag.content = shareImageUrl; // 使用榜单封面图片，与任务详情页保持一致
    document.head.insertBefore(weixinImageTag, document.head.firstChild);
    
    // 更新Twitter Card标签
    updateMetaTag('twitter:card', 'summary_large_image');
    updateMetaTag('twitter:title', shareTitle);
    updateMetaTag('twitter:description', currentShareDescription);
    // 强制更新twitter:image
    const existingTwitterImage = document.querySelector('meta[name="twitter:image"]');
    if (existingTwitterImage) {
      existingTwitterImage.remove();
    }
    updateMetaTag('twitter:image', shareImageUrl);
    updateMetaTag('twitter:url', canonicalUrl);
    
    // 微信分享特殊处理
    // 1. 确保所有标签都在head的前面部分（微信爬虫可能只读取前几个标签）
    // 2. 添加额外的微信友好标签
    // 确保图片URL是绝对路径且可通过HTTPS访问
    // 微信分享会读取og:image, og:title, og:description等标签
    
    // 将重要的meta标签移动到head的前面（确保微信爬虫能读取到）
    // 微信爬虫会优先读取head前面的标签
    const moveToTop = (selector: string) => {
      try {
        const element = document.querySelector(selector);
        if (element && element.parentNode && element.parentNode === document.head) {
          const head = document.head;
          const firstChild = head.firstChild;
          if (firstChild && element !== firstChild) {
            head.insertBefore(element, firstChild);
          }
        }
      } catch (error) {
        // 忽略DOM操作错误，避免影响页面功能
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
    
    // 使用多个setTimeout确保在DOM完全加载后多次强制更新微信标签（防止被其他脚本覆盖）
    // 微信爬虫可能在页面加载的不同阶段抓取，所以需要多次更新
    setTimeout(() => {
      // 再次检查并确保微信描述正确（特别检查是否包含默认描述）
      const weixinDesc = document.querySelector('meta[name="weixin:description"]') as HTMLMetaElement;
      if (!weixinDesc || weixinDesc.content !== currentShareDescription || 
          weixinDesc.content.includes('Professional task publishing') ||
          weixinDesc.content.includes('skill matching platform')) {
        // 移除所有现有的微信描述标签
        const allWeixinDescs = document.querySelectorAll('meta[name="weixin:description"]');
        allWeixinDescs.forEach(tag => {
          try {
            if (tag.parentNode) {
              tag.remove();
            }
          } catch (e) {
            // 忽略移除错误
          }
        });
        const finalWeixinDesc = document.createElement('meta');
        finalWeixinDesc.setAttribute('name', 'weixin:description');
        finalWeixinDesc.content = currentShareDescription;
        document.head.insertBefore(finalWeixinDesc, document.head.firstChild);
      }
      
      // 再次检查并确保微信标题正确
      const weixinTitle = document.querySelector('meta[name="weixin:title"]') as HTMLMetaElement;
      const expectedTitle = shareTitle;
      if (!weixinTitle || weixinTitle.content !== expectedTitle || weixinTitle.content === 'Link²Ur') {
        // 移除所有现有的微信标题标签
        const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
        allWeixinTitles.forEach(tag => {
          try {
            if (tag.parentNode) {
              tag.remove();
            }
          } catch (e) {
            // 忽略移除错误
          }
        });
        const finalWeixinTitle = document.createElement('meta');
        finalWeixinTitle.setAttribute('name', 'weixin:title');
        finalWeixinTitle.content = expectedTitle;
        document.head.insertBefore(finalWeixinTitle, document.head.firstChild);
      }
      
      // 再次检查并确保微信图片正确（使用榜单封面图片）
      // 与任务详情页保持一致，直接使用 shareImageUrl
      const weixinImage = document.querySelector('meta[name="weixin:image"]') as HTMLMetaElement;
      if (!weixinImage || weixinImage.content !== shareImageUrl) {
        // 移除所有现有的微信图片标签
        const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
        allWeixinImages.forEach(tag => {
          try {
            if (tag.parentNode) {
              tag.remove();
            }
          } catch (e) {
            // 忽略移除错误
          }
        });
        const finalWeixinImage = document.createElement('meta');
        finalWeixinImage.setAttribute('name', 'weixin:image');
        finalWeixinImage.content = shareImageUrl; // 使用榜单封面图片，与任务详情页保持一致
        document.head.insertBefore(finalWeixinImage, document.head.firstChild);
      }
    }, 100);
    
    setTimeout(() => {
      // 再次确保所有关键标签都在最前面
      moveToTop('meta[name="weixin:title"]');
      moveToTop('meta[name="weixin:description"]');
      moveToTop('meta[name="weixin:image"]');
      moveToTop('meta[property="og:title"]');
      moveToTop('meta[property="og:description"]');
      moveToTop('meta[property="og:image"]');
    }, 500);
    
    // 再次更新（确保微信爬虫能抓取到，延迟更长时间确保在SEOHead的useEffect之后执行）
    // 参考TaskDetail的实现，在1000ms后再次移除所有默认标签并重新插入正确的标签
    setTimeout(() => {
      // 移除所有包含默认描述的标签（包括所有类型的描述标签）
      const allDescriptionTags = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="twitter:description"], meta[name="weixin:description"]');
      allDescriptionTags.forEach(tag => {
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
      const allTitleTags = document.querySelectorAll('meta[property="og:title"], meta[name="weixin:title"]');
      allTitleTags.forEach(tag => {
        const metaTag = tag as HTMLMetaElement;
        if (metaTag.content && (metaTag.content === 'Link²Ur' || metaTag.content.includes('Link²Ur Forum'))) {
          metaTag.remove();
        }
      });
      
      // 强制移除所有微信标签（包括SEOHead创建的），确保使用正确的榜单信息
      const allWeixinDescs = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDescs.forEach(tag => tag.remove());
      const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
      allWeixinTitles.forEach(tag => tag.remove());
      const allWeixinImagesForRemoval = document.querySelectorAll('meta[name="weixin:image"]');
      allWeixinImagesForRemoval.forEach(tag => tag.remove());
      
      // 重新插入正确的榜单描述标签（只使用榜单信息）
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
      
      const finalWeixinTitle = document.createElement('meta');
      finalWeixinTitle.setAttribute('name', 'weixin:title');
      finalWeixinTitle.content = shareTitle;
      document.head.insertBefore(finalWeixinTitle, document.head.firstChild);
      
      // 与任务详情页保持一致，直接使用 shareImageUrl
      
      // 强制移除所有图片标签（包括SEOHead创建的）
      const allWeixinImagesFinal = document.querySelectorAll('meta[name="weixin:image"]');
      allWeixinImagesFinal.forEach(tag => tag.remove());
      const allOgImages = document.querySelectorAll('meta[property="og:image"]');
      allOgImages.forEach(tag => tag.remove());
      
      // 重新创建微信图片标签（使用榜单封面图片，替换默认图片）
      // 与任务详情页保持一致，直接使用 shareImageUrl
      const finalWeixinImage = document.createElement('meta');
    finalWeixinImage.setAttribute('name', 'weixin:image');
    finalWeixinImage.content = shareImageUrl; // 使用榜单封面图片
    document.head.insertBefore(finalWeixinImage, document.head.firstChild);
    
    // 同时更新 og:image 确保一致性（使用榜单封面图片）
      const finalOgImage = document.createElement('meta');
    finalOgImage.setAttribute('property', 'og:image');
    finalOgImage.content = shareImageUrl; // 使用榜单封面图片
    document.head.insertBefore(finalOgImage, document.head.firstChild);
    
    // 同时更新 og:image 相关属性
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
      
    }, 1000); // 延迟1秒，确保在SEOHead的useEffect之后执行
  }, [leaderboard, canonicalUrl]);

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


  useEffect(() => {
    if (leaderboardId) {
      loadData();
      fetchCurrentUser().then(setUser).catch(() => setUser(null));
    }
    getPublicSystemSettings().then(setSystemSettings).catch(() => {
      setSystemSettings({ vip_button_visible: false });
    });
    
    // 组件卸载时清理所有临时预览 URL
    return () => {
      previewUrlsRef.current.forEach(url => {
        if (url.startsWith('blob:')) {
          URL.revokeObjectURL(url);
        }
      });
      previewUrlsRef.current.clear();
    };
  }, [leaderboardId, sortBy]);

  const loadData = async (page: number = 1) => {
    try {
      setLoading(true);
      const offset = (page - 1) * pagination.pageSize;
      const [leaderboardData, itemsData] = await Promise.all([
        getCustomLeaderboardDetail(Number(leaderboardId)),
        getLeaderboardItems(Number(leaderboardId), { 
          sort: sortBy, 
          limit: pagination.pageSize,
          offset
        })
      ]);
      setLeaderboard(leaderboardData);
      
      if (itemsData && itemsData.items) {
        setItems(itemsData.items || []);
        setPagination(prev => ({
          ...prev,
          current: page,
          total: itemsData.total || 0,
          hasMore: itemsData.has_more || false
        }));
      } else {
        // 兼容旧格式
        setItems(itemsData || []);
      }
    } catch (error: any) {
            // 处理不同类型的错误
      if (error.response?.status === 404) {
        message.error(t('forum.leaderboardNotExistOrDeleted'));
      } else if (error.response?.status === 401) {
        message.error(t('forum.pleaseLogin'));
      } else if (error.response?.status === 403) {
        message.error(t('forum.noPermission'));
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.warning(t('forum.rateLimitExceeded', { retryAfter }));
      } else if (error.response?.status >= 500) {
        message.error(t('forum.serverError'));
      } else {
        message.error(getErrorMessage(error));
      }
    } finally {
      setLoading(false);
    }
  };

  const handleVote = async (itemId: number, voteType: 'upvote' | 'downvote') => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }

    const item = items.find(i => i.id === itemId);
    if (item && item.user_vote === voteType) {
      try {
        await voteLeaderboardItem(itemId, 'remove');
        message.success(t('forum.voteCancelled'));
        loadData();
      } catch (error: any) {
        message.error(getErrorMessage(error));
      }
    } else {
      setCurrentVoteItemId(itemId);
      setCurrentVoteType(voteType);
      setShowVoteModal(true);
      voteForm.resetFields();
    }
  };

  const handleVoteSubmit = async (values: { comment?: string; is_anonymous?: boolean }) => {
    if (!currentVoteItemId || !currentVoteType) return;

    try {
      const res = await voteLeaderboardItem(
        currentVoteItemId,
        currentVoteType,
        values.comment,
        values.is_anonymous || false
      );
      message.success(t('forum.voteSuccess'));
      setShowVoteModal(false);
      voteForm.resetFields();
      
      setItems(prev => prev.map(i =>
        i.id === currentVoteItemId ? {
          ...i,
          upvotes: res.upvotes,
          downvotes: res.downvotes,
          net_votes: res.net_votes,
          vote_score: res.vote_score,
          user_vote: currentVoteType,
          user_vote_comment: values.comment || null,
          user_vote_is_anonymous: values.is_anonymous || false,
        } : i
      ));
      
      // 重新排序（如果按vote_score排序）
      if (sortBy === 'vote_score') {
        setItems(prev => [...prev].sort((a, b) => b.vote_score - a.vote_score));
      }
    } catch (error: any) {
            const errorMsg = getErrorMessage(error);
      
      // 处理速率限制错误
      if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(t('forum.operationTooFrequent', { retryAfter }));
      } else if (error.response?.status === 401) {
        message.error(t('forum.pleaseLogin'));
      } else if (error.response?.status === 403) {
        message.error(t('forum.noPermissionOperation'));
      } else {
        message.error(errorMsg);
      }
    }
  };

  const handleImageUpload = async (file: File): Promise<string> => {
    try {
      setUploading(true);
      // 压缩图片
      const compressedFile = await compressImage(file, {
        maxSizeMB: 1,
        maxWidthOrHeight: 1920,
      });
      
      const formData = new FormData();
      formData.append('image', compressedFile);
      
      // 使用 leaderboard_item category，便于分类管理
      // 传递 resource_id 为临时标识（因为上传时 item 还未创建）
      const resourceId = user?.id ? `temp_${user.id}` : 'temp_anonymous';
      const response = await api.post(
        `/api/upload/public-image?category=leaderboard_item&resource_id=${encodeURIComponent(resourceId)}`,
        formData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        }
      );
      
      if (response.data.success && response.data.url) {
        return response.data.url;
      } else {
        throw new Error(t('forum.imageUploadFailed'));
      }
    } catch (error: any) {
            message.error(`${t('forum.imageUploadFailed')}: ${getErrorMessage(error)}`);
      throw error;
    } finally {
      setUploading(false);
    }
  };

  const handleImageChange = (info: any) => {
    const { file } = info;
    
        // 处理文件删除
    if (file.status === 'removed') {
      // 清理预览 URL
      if (file.url && file.url.startsWith('blob:') && previewUrlsRef.current.has(file.url)) {
        URL.revokeObjectURL(file.url);
        previewUrlsRef.current.delete(file.url);
      }
      if (file.thumbUrl && file.thumbUrl.startsWith('blob:') && previewUrlsRef.current.has(file.thumbUrl)) {
        URL.revokeObjectURL(file.thumbUrl);
        previewUrlsRef.current.delete(file.thumbUrl);
      }
      
      // 从上传列表中移除
      setUploadingFileList(prev => prev.filter(f => f.uid !== file.uid));
      return;
    }
    
    // 当用户选择新文件时
    // beforeUpload 返回 false 时，file 对象本身就是 File 对象，不是包装后的对象
    // 需要检查 file 是否是 File 实例，或者是否有 originFileObj
    const fileToUpload = file.originFileObj || (file instanceof File ? file : null);
    
    if (fileToUpload) {
      // 检查是否已经在列表中（避免重复添加）
      const existingFile = uploadingFileList.find(f => {
        const fFile = f.originFileObj || (f instanceof File ? f : null);
        return fFile === fileToUpload || 
               (f.name === fileToUpload.name && f.size === fileToUpload.size);
      });
      
      if (existingFile) {
                return;
      }
      
      const tempId = file.uid || `temp-${Date.now()}-${Math.random()}`;
      
      // 创建临时预览 URL
      const previewUrl = URL.createObjectURL(fileToUpload);
      previewUrlsRef.current.add(previewUrl);
      
            // 立即添加到上传列表，显示上传中状态和预览
      const newFile = {
        uid: tempId,
        name: fileToUpload.name,
        status: 'uploading' as const,
        url: previewUrl, // 临时预览 URL
        originFileObj: fileToUpload,
        thumbUrl: previewUrl // 缩略图预览
      };
      
      setUploadingFileList(prev => {
        const newList = [...prev, newFile];
                return newList;
      });
      
      // 延迟执行压缩和上传，避免阻塞 UI
      setTimeout(async () => {
        try {
          const url = await handleImageUpload(fileToUpload);
          
          // 清理临时预览 URL
          if (newFile.url && previewUrlsRef.current.has(newFile.url)) {
            URL.revokeObjectURL(newFile.url);
            previewUrlsRef.current.delete(newFile.url);
          }
          
          // 上传成功后，从上传列表中移除，只保留在已上传图片列表中
          // 这样可以避免在 fileList 中重复显示
          setUploadingFileList(prev => prev.filter(f => f.uid !== tempId));
          
          // 添加到已上传图片列表
          setUploadingImages(prev => [...prev, url]);
          message.success(t('forum.imageUploadSuccess'));
        } catch (error) {
                    // 清理临时预览 URL
          if (newFile.url && previewUrlsRef.current.has(newFile.url)) {
            URL.revokeObjectURL(newFile.url);
            previewUrlsRef.current.delete(newFile.url);
          }
          
          // 上传失败，移除该文件
          setUploadingFileList(prev => prev.filter(f => f.uid !== tempId));
          // 错误已在handleImageUpload中处理
        }
      }, 0);
    } else {
          }
  };

  const handleRemoveImage = (url: string) => {
    setUploadingImages(prev => prev.filter(img => img !== url));
  };

  const handleSubmitItem = async (values: any) => {
    try {
      // 确保images字段正确传递：如果有图片就传递数组，没有就传递空数组（而不是undefined）
      const submitData = {
        leaderboard_id: Number(leaderboardId),
        ...values,
        images: uploadingImages.length > 0 ? uploadingImages : []
      };
            await submitLeaderboardItem(submitData);
      message.success(t('forum.itemAdded'));
      setShowSubmitModal(false);
      form.resetFields();
      
      // 清理所有临时预览 URL
      uploadingFileList.forEach(file => {
        if (file.url && file.url.startsWith('blob:') && previewUrlsRef.current.has(file.url)) {
          URL.revokeObjectURL(file.url);
          previewUrlsRef.current.delete(file.url);
        }
        if (file.thumbUrl && file.thumbUrl.startsWith('blob:') && previewUrlsRef.current.has(file.thumbUrl)) {
          URL.revokeObjectURL(file.thumbUrl);
          previewUrlsRef.current.delete(file.thumbUrl);
        }
      });
      
      setUploadingImages([]);
      setUploadingFileList([]);
      // 重置到第一页并重新加载
      setPagination(prev => ({ ...prev, current: 1 }));
      loadData(1);
    } catch (error: any) {
            const errorMsg = getErrorMessage(error);
      
      // 处理不同类型的错误
      if (error.response?.status === 400) {
        if (errorMsg.includes('已存在')) {
          message.error(t('forum.itemExists'));
        } else {
          message.error(errorMsg);
        }
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限执行此操作');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(t('forum.operationTooFrequent', { retryAfter }));
      } else {
        message.error(errorMsg);
      }
    }
  };

  const handleShare = async () => {
    if (!leaderboard) return;
    
    // 使用辅助函数生成分享描述（在榜单描述后追加提示文字）
    const currentShareDescription = getShareDescription(leaderboard.description);
    
    // 图片优先使用榜单封面图片（cover_image），如果没有则使用默认logo
    // 与 useLayoutEffect 保持一致，确保图片URL包含版本号避免缓存
    let shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    if (leaderboard.cover_image) {
      const coverImageUrl = leaderboard.cover_image;
      // 处理URL格式：可能是完整URL、相对路径或包含域名的路径
      if (coverImageUrl.startsWith('http://') || coverImageUrl.startsWith('https://')) {
        // 已经是完整URL，确保添加版本号避免缓存
        shareImageUrl = coverImageUrl.includes('?') ? coverImageUrl : `${coverImageUrl}?v=2`;
      } else if (coverImageUrl.startsWith('//')) {
        // 协议相对URL，需要添加https:
        shareImageUrl = `https:${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      } else if (coverImageUrl.startsWith('/')) {
        // 绝对路径，拼接域名
        shareImageUrl = `${window.location.origin}${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      } else if (coverImageUrl.includes('://')) {
        // 包含协议但格式不标准，尝试提取
        const match = coverImageUrl.match(/https?:\/\/[^\s]+/);
        if (match) {
          shareImageUrl = match[0];
          if (!shareImageUrl.includes('?')) {
            shareImageUrl = `${shareImageUrl}?v=2`;
          }
        } else {
          shareImageUrl = `${window.location.origin}/${coverImageUrl}`;
          if (!shareImageUrl.includes('?')) {
            shareImageUrl = `${shareImageUrl}?v=2`;
          }
        }
      } else {
        // 相对路径，拼接域名
        shareImageUrl = `${window.location.origin}/${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      }
    }
    
    // 分享标题：榜单名称 + 平台名称
    const shareTitle = `${leaderboard.name} - ${t('forum.leaderboardTitle')}`;
    
    // 强制移除所有描述标签（包括默认的和SEOHead创建的）
    const allDescriptionTags = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="twitter:description"], meta[name="weixin:description"]');
    allDescriptionTags.forEach(tag => tag.remove());
    
    // 强制移除所有标题标签
    const allTitleTags = document.querySelectorAll('meta[property="og:title"], meta[name="weixin:title"]');
    allTitleTags.forEach(tag => tag.remove());
    
    // 强制移除所有图片标签
    const allImageTags = document.querySelectorAll('meta[property="og:image"], meta[name="weixin:image"], meta[name="twitter:image"]');
    allImageTags.forEach(tag => tag.remove());
    
    // 立即重新设置正确的微信标签（插入到head最前面）
    const finalWeixinDesc = document.createElement('meta');
    finalWeixinDesc.setAttribute('name', 'weixin:description');
    finalWeixinDesc.content = currentShareDescription;
    document.head.insertBefore(finalWeixinDesc, document.head.firstChild);
    
    const finalWeixinTitle = document.createElement('meta');
    finalWeixinTitle.setAttribute('name', 'weixin:title');
    finalWeixinTitle.content = shareTitle;
    document.head.insertBefore(finalWeixinTitle, document.head.firstChild);
    
    // 与 useLayoutEffect 保持一致，直接使用 shareImageUrl（已经包含 ?v=2 如果默认图片）
    
    // 强制更新微信图片标签（使用榜单封面图片）
    // 与 useLayoutEffect 保持一致，直接使用 shareImageUrl
    const finalWeixinImage = document.createElement('meta');
    finalWeixinImage.setAttribute('name', 'weixin:image');
    finalWeixinImage.content = shareImageUrl; // 使用榜单封面图片，与 useLayoutEffect 保持一致
    document.head.insertBefore(finalWeixinImage, document.head.firstChild);
    
    // 设置Open Graph标签
    const finalOgDesc = document.createElement('meta');
    finalOgDesc.setAttribute('property', 'og:description');
    finalOgDesc.content = currentShareDescription;
    document.head.insertBefore(finalOgDesc, document.head.firstChild);
    
    const finalOgTitle = document.createElement('meta');
    finalOgTitle.setAttribute('property', 'og:title');
    finalOgTitle.content = shareTitle;
    document.head.insertBefore(finalOgTitle, document.head.firstChild);
    
    // 强制更新 og:image（使用榜单封面图片）
    const finalOgImage = document.createElement('meta');
    finalOgImage.setAttribute('property', 'og:image');
    finalOgImage.content = shareImageUrl; // 使用榜单封面图片，与 useLayoutEffect 保持一致
    document.head.insertBefore(finalOgImage, document.head.firstChild);
    
    const finalDesc = document.createElement('meta');
    finalDesc.name = 'description';
    finalDesc.content = currentShareDescription;
    document.head.insertBefore(finalDesc, document.head.firstChild);
    
    // 多次更新，确保微信爬虫能读取到
    setTimeout(() => {
      // 再次强制更新微信描述
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const newWeixinDesc = document.createElement('meta');
      newWeixinDesc.setAttribute('name', 'weixin:description');
      newWeixinDesc.content = currentShareDescription;
      document.head.insertBefore(newWeixinDesc, document.head.firstChild);
      
      // 再次强制更新微信标题
      const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
      allWeixinTitles.forEach(tag => tag.remove());
      const newWeixinTitle = document.createElement('meta');
      newWeixinTitle.setAttribute('name', 'weixin:title');
      newWeixinTitle.content = shareTitle;
      document.head.insertBefore(newWeixinTitle, document.head.firstChild);
      
      // 再次强制更新微信图片（与 useLayoutEffect 保持一致，直接使用 shareImageUrl）
      const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
      allWeixinImages.forEach(tag => tag.remove());
      const newWeixinImage = document.createElement('meta');
      newWeixinImage.setAttribute('name', 'weixin:image');
      newWeixinImage.content = shareImageUrl; // 使用榜单封面图片，与 useLayoutEffect 保持一致
      document.head.insertBefore(newWeixinImage, document.head.firstChild);
      
      // 同时更新 og:image
      const allOgImages = document.querySelectorAll('meta[property="og:image"]');
      allOgImages.forEach(tag => tag.remove());
      const newOgImage = document.createElement('meta');
      newOgImage.setAttribute('property', 'og:image');
      newOgImage.content = shareImageUrl; // 使用榜单封面图片
      document.head.insertBefore(newOgImage, document.head.firstChild);
    }, 100);
    
    setTimeout(() => {
      // 最后一次强制更新（与 useLayoutEffect 保持一致，直接使用 shareImageUrl）
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const newWeixinDesc = document.createElement('meta');
      newWeixinDesc.setAttribute('name', 'weixin:description');
      newWeixinDesc.content = currentShareDescription;
      document.head.insertBefore(newWeixinDesc, document.head.firstChild);
      
      const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
      allWeixinTitles.forEach(tag => tag.remove());
      const newWeixinTitle = document.createElement('meta');
      newWeixinTitle.setAttribute('name', 'weixin:title');
      newWeixinTitle.content = shareTitle;
      document.head.insertBefore(newWeixinTitle, document.head.firstChild);
      
      // 强制移除所有图片标签
      const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
      allWeixinImages.forEach(tag => tag.remove());
      const allOgImages = document.querySelectorAll('meta[property="og:image"]');
      allOgImages.forEach(tag => tag.remove());
      
      // 重新设置图片标签
      const newWeixinImage = document.createElement('meta');
      newWeixinImage.setAttribute('name', 'weixin:image');
      newWeixinImage.content = shareImageUrl; // 使用榜单封面图片，与 useLayoutEffect 保持一致
      document.head.insertBefore(newWeixinImage, document.head.firstChild);
      
      const newOgImage = document.createElement('meta');
      newOgImage.setAttribute('property', 'og:image');
      newOgImage.content = shareImageUrl; // 使用榜单封面图片
      document.head.insertBefore(newOgImage, document.head.firstChild);
    }, 500);
    
    // 修复：使用正确的路由路径
    const shareUrl = `${window.location.origin}/${lang}/leaderboard/custom/${leaderboard.id}`;
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
    setShowShareModal(true);
  };

  const handleCopyLink = async () => {
    if (!leaderboard) return;
    // 修复：使用正确的路由路径
    const shareUrl = `${window.location.origin}/${lang}/leaderboard/custom/${leaderboard.id}`;
    try {
      await navigator.clipboard.writeText(shareUrl);
      message.success(t('forum.linkCopied'));
      setShowShareModal(false);
    } catch (error) {
      message.error(t('forum.copyFailed'));
    }
  };

  const handleShareToSocial = (platform: string) => {
    if (!leaderboard) return;
    
    // 使用辅助函数生成分享描述（在榜单描述后追加提示文字）
    const currentShareDescription = getShareDescription(leaderboard.description);
    
    // 图片优先使用榜单封面图片（cover_image），如果没有则使用默认logo
    // 与 useLayoutEffect 和 handleShare 保持一致，确保图片URL包含版本号避免缓存
    let shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    if (leaderboard.cover_image) {
      const coverImageUrl = leaderboard.cover_image;
      // 处理URL格式：可能是完整URL、相对路径或包含域名的路径
      if (coverImageUrl.startsWith('http://') || coverImageUrl.startsWith('https://')) {
        // 已经是完整URL，确保添加版本号避免缓存
        shareImageUrl = coverImageUrl.includes('?') ? coverImageUrl : `${coverImageUrl}?v=2`;
      } else if (coverImageUrl.startsWith('//')) {
        // 协议相对URL，需要添加https:
        shareImageUrl = `https:${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      } else if (coverImageUrl.startsWith('/')) {
        // 绝对路径，拼接域名
        shareImageUrl = `${window.location.origin}${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      } else if (coverImageUrl.includes('://')) {
        // 包含协议但格式不标准，尝试提取
        const match = coverImageUrl.match(/https?:\/\/[^\s]+/);
        if (match) {
          shareImageUrl = match[0];
          if (!shareImageUrl.includes('?')) {
            shareImageUrl = `${shareImageUrl}?v=2`;
          }
        } else {
          shareImageUrl = `${window.location.origin}/${coverImageUrl}`;
          if (!shareImageUrl.includes('?')) {
            shareImageUrl = `${shareImageUrl}?v=2`;
          }
        }
      } else {
        // 相对路径，拼接域名
        shareImageUrl = `${window.location.origin}/${coverImageUrl}`;
        if (!shareImageUrl.includes('?')) {
          shareImageUrl = `${shareImageUrl}?v=2`;
        }
      }
    }
    
    // 分享标题：榜单名称 + 平台名称
    const shareTitle = `${leaderboard.name} - ${t('forum.leaderboardTitle')}`;
    
    // 如果是微信分享（通过二维码），立即更新 meta 标签
    if (platform === 'wechat') {
      // 强制更新微信描述标签
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const newWeixinDesc = document.createElement('meta');
      newWeixinDesc.setAttribute('name', 'weixin:description');
      newWeixinDesc.content = currentShareDescription;
      document.head.insertBefore(newWeixinDesc, document.head.firstChild);
      
      // 强制更新微信标题标签
      const allWeixinTitles = document.querySelectorAll('meta[name="weixin:title"]');
      allWeixinTitles.forEach(tag => tag.remove());
      const newWeixinTitle = document.createElement('meta');
      newWeixinTitle.setAttribute('name', 'weixin:title');
      newWeixinTitle.content = shareTitle;
      document.head.insertBefore(newWeixinTitle, document.head.firstChild);
      
      // 与 useLayoutEffect 和 handleShare 保持一致，直接使用 shareImageUrl
      
      // 强制更新微信图片标签（使用榜单封面图片）
      const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
      allWeixinImages.forEach(tag => tag.remove());
      const newWeixinImage = document.createElement('meta');
      newWeixinImage.setAttribute('name', 'weixin:image');
      newWeixinImage.content = shareImageUrl; // 使用榜单封面图片，与 useLayoutEffect 和 handleShare 保持一致
      document.head.insertBefore(newWeixinImage, document.head.firstChild);
      
      // 同时更新 og:image 确保一致性
      const allOgImages = document.querySelectorAll('meta[property="og:image"]');
      allOgImages.forEach(tag => tag.remove());
      const newOgImage = document.createElement('meta');
      newOgImage.setAttribute('property', 'og:image');
      newOgImage.content = shareImageUrl; // 使用榜单封面图片
      document.head.insertBefore(newOgImage, document.head.firstChild);
    }
    
    // 修复：使用正确的路由路径
    const shareUrl = encodeURIComponent(`${window.location.origin}/${lang}/leaderboard/custom/${leaderboard.id}`);
    const encodedShareTitle = encodeURIComponent(shareTitle);
    const shareDescription = encodeURIComponent(currentShareDescription);
    
    let shareWindowUrl = '';
    
    switch (platform) {
      case 'weibo':
        shareWindowUrl = `https://service.weibo.com/share/share.php?url=${shareUrl}&title=${encodedShareTitle} ${shareDescription}`;
        break;
      case 'twitter':
        shareWindowUrl = `https://twitter.com/intent/tweet?url=${shareUrl}&text=${encodedShareTitle} ${shareDescription}`;
        break;
      case 'facebook':
        shareWindowUrl = `https://www.facebook.com/sharer/sharer.php?u=${shareUrl}&quote=${encodedShareTitle} ${shareDescription}`;
        break;
      default:
        return;
    }
    
    if (shareWindowUrl) {
      window.open(shareWindowUrl, '_blank', 'width=600,height=400');
    }
    setShowShareModal(false);
  };

  if (loading) {
    return <Spin size="large" />;
  }

  if (!leaderboard) {
    return <Empty description={t('forum.leaderboardNotExist')} />;
  }

  return (
    <div className={styles.container}>
      {/* SEO 组件 */}
      {leaderboard && (
        <>
          <SEOHead
            title={seoTitle}
            description={seoDescription}
            keywords={seoKeywords}
            canonicalUrl={canonicalUrl}
            ogTitle={`${leaderboard.name} - ${t('forum.leaderboardTitle')}`}
            ogDescription={getShareDescription(leaderboard.description)}
            ogImage={(() => {
              // 确保图片URL是完整的HTTPS URL
              if (!leaderboard.cover_image) {
                return `https://www.link2ur.com/static/favicon.png`;
              }
              const coverImageUrl = leaderboard.cover_image;
              if (coverImageUrl.startsWith('http://') || coverImageUrl.startsWith('https://')) {
                return coverImageUrl;
              } else if (coverImageUrl.startsWith('//')) {
                return `https:${coverImageUrl}`;
              } else if (coverImageUrl.startsWith('/')) {
                return `https://www.link2ur.com${coverImageUrl}`;
              } else {
                return `https://www.link2ur.com/${coverImageUrl}`;
              }
            })()}
            ogUrl={canonicalUrl}
            twitterTitle={leaderboard.name}
            twitterDescription={getShareDescription(leaderboard.description)}
            twitterImage={(() => {
              // 确保图片URL是完整的HTTPS URL
              if (!leaderboard.cover_image) {
                return `https://www.link2ur.com/static/favicon.png`;
              }
              const coverImageUrl = leaderboard.cover_image;
              if (coverImageUrl.startsWith('http://') || coverImageUrl.startsWith('https://')) {
                return coverImageUrl;
              } else if (coverImageUrl.startsWith('//')) {
                return `https:${coverImageUrl}`;
              } else if (coverImageUrl.startsWith('/')) {
                return `https://www.link2ur.com${coverImageUrl}`;
              } else {
                return `https://www.link2ur.com/${coverImageUrl}`;
              }
            })()}
          />
          {/* 结构化数据 - 使用ItemList类型表示榜单 */}
          <script
            type="application/ld+json"
            dangerouslySetInnerHTML={{
              __html: JSON.stringify({
                "@context": "https://schema.org",
                "@type": "ItemList",
                "name": leaderboard.name,
                "description": leaderboard.description || `${leaderboard.location}的${leaderboard.name}`,
                "url": canonicalUrl,
                "numberOfItems": leaderboard.item_count,
                "itemListElement": items.slice(0, 10).map((item: any, index: number) => ({
                  "@type": "ListItem",
                  "position": index + 1,
                  "name": item.name,
                  "description": item.description || item.name,
                  "url": `${canonicalUrl}#item-${item.id}`
                }))
              })
            }}
          />
          <HreflangManager type="page" path={`/leaderboard/custom/${leaderboard.id}`} />
          {breadcrumbItems.length > 0 && (
            <BreadcrumbStructuredData items={breadcrumbItems} />
          )}
        </>
      )}
      {/* 顶部导航栏 */}
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          <div className={styles.logo} onClick={() => navigate(`/${lang}/forum/leaderboard`)} style={{ cursor: 'pointer' }}>
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
        <div style={{ maxWidth: 1200, margin: '0 auto', padding: '20px' }}>
          {/* 榜单头部 */}
      <Card style={{ marginBottom: 24 }}>
        <div className="leaderboard-header-container" style={{ display: 'flex', alignItems: 'start', gap: 16 }}>
          {leaderboard.cover_image && (
            <div className="leaderboard-cover-image-wrapper">
              <Image
                src={formatImageUrl(leaderboard.cover_image)}
                alt={leaderboard.name}
                width={200}
                height={150}
                style={{ objectFit: 'cover', borderRadius: 8 }}
                preview
              />
            </div>
          )}
          <div className="leaderboard-header-content" style={{ flex: 1 }}>
            <h1 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: 8 }}>
              <TrophyOutlined style={{ color: '#ffc107' }} />
              {leaderboard.name}
            </h1>
            <Space style={{ marginTop: 8 }}>
              <Tag color="blue">{leaderboard.location}</Tag>
              <Tag>📦 {leaderboard.item_count} {t('forum.itemsCount')}</Tag>
              <Tag>👍 {leaderboard.vote_count} {t('forum.votesCount')}</Tag>
              <Tag>👁️ {formatViewCount(leaderboard.view_count)} {t('forum.viewsCount')}</Tag>
            </Space>
            {leaderboard.description && (
              <p style={{ marginTop: 16, color: '#666' }}>{leaderboard.description}</p>
            )}
            <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
              <Button
                type="primary"
                icon={<PlusOutlined />}
                onClick={() => {
                  if (!user) {
                    setShowLoginModal(true);
                    return;
                  }
                  setShowSubmitModal(true);
                }}
              >
                {t('forum.addItem')}
              </Button>
              <Button
                icon={<ShareAltOutlined />}
                onClick={handleShare}
              >
                {t('forum.shareLeaderboard')}
              </Button>
              <Button
                danger
                icon={<ExclamationCircleOutlined />}
                onClick={() => {
                  if (!user) {
                    setShowLoginModal(true);
                    return;
                  }
                  setShowReportModal(true);
                }}
              >
                {t('forum.reportLeaderboard')}
              </Button>
            </div>
          </div>
        </div>
      </Card>

      {/* 排序选择 */}
      <div style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Select
          value={sortBy}
          onChange={(value) => {
            setSortBy(value);
            setPagination(prev => ({ ...prev, current: 1 }));
          }}
          style={{ width: 200 }}
        >
          <Option value="vote_score">{t('forum.comprehensiveScore')}</Option>
          <Option value="net_votes">{t('forum.netVotes')}</Option>
          <Option value="upvotes">{t('forum.upvotes')}</Option>
          <Option value="created_at">{t('forum.latestAdded')}</Option>
        </Select>
        <span style={{ color: '#999', fontSize: 14 }}>
          {t('forum.totalItems', { total: pagination.total })}
        </span>
      </div>

      {/* 竞品列表 */}
      <Spin spinning={loading}>
        {items.length === 0 && !loading ? (
          <Empty description={t('forum.noItems')} />
        ) : (
          <>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {items.map((item, index) => {
                const globalIndex = (pagination.current - 1) * pagination.pageSize + index + 1;
                const isTop3 = globalIndex <= 3;
                // 处理图片数据（可能是字符串或数组）
                let images: string[] = [];
                if (item.images) {
                  if (typeof item.images === 'string') {
                    try {
                      images = JSON.parse(item.images);
                    } catch {
                      images = [];
                    }
                  } else if (Array.isArray(item.images)) {
                    images = item.images;
                  }
                }
                
                return (
                  <Card 
                    key={item.id} 
                    className="leaderboard-item-card"
                    style={{ 
                      borderRadius: 8,
                      boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                      padding: 20
                    }}
                  >
                    {/* 卡片头部：排名、信息、投票 */}
                    <div className="item-card-header" style={{ 
                      display: 'flex', 
                      justifyContent: 'space-between', 
                      alignItems: 'start',
                      marginBottom: 12
                    }}>
                      {/* 左侧：排名和信息 */}
                      <div className="item-card-content" style={{ display: 'flex', alignItems: 'start', flex: 1 }}>
                        <span className="item-rank" style={{
                          fontSize: 24,
                          fontWeight: 'bold',
                          color: isTop3 ? '#ffc107' : '#666',
                          marginRight: 12,
                          flexShrink: 0
                        }}>
                          #{globalIndex}
                        </span>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div 
                            className="item-name"
                            style={{ 
                              fontSize: 20, 
                              fontWeight: 600, 
                              marginBottom: 8,
                              cursor: 'pointer',
                              color: '#333',
                              wordBreak: 'break-word'
                            }}
                            onClick={() => {
                              const lang = language || 'zh';
                              navigate(`/${lang}/leaderboard/item/${item.id}?leaderboardId=${leaderboardId}`);
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.color = '#1890ff';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.color = '#333';
                            }}
                          >
                            {item.name}
                          </div>
                          {item.description && (
                            <div className="item-description" style={{ 
                              color: '#666', 
                              lineHeight: 1.6,
                              marginBottom: 8,
                              fontSize: 14,
                              wordBreak: 'break-word'
                            }}>
                              {item.description}
                            </div>
                          )}
                          {item.address && (
                            <div className="item-address" style={{ 
                              fontSize: 12, 
                              color: '#999',
                              marginBottom: 8,
                              wordBreak: 'break-word'
                            }}>
                              📍 {item.address}
                            </div>
                          )}
                          {item.submitter_info && (
                            <div style={{ 
                              display: 'inline-flex', 
                              alignItems: 'center', 
                              gap: 8, 
                              marginBottom: 8,
                              fontSize: 12,
                              color: '#666'
                            }}>
                              <span>{t('forum.submitter') || '提交者'}: {item.submitter_info.name}</span>
                              {item.submitter_info.user_level && (item.submitter_info.user_level === 'vip' || item.submitter_info.user_level === 'super') && (
                                <MemberBadge level={item.submitter_info.user_level} variant="compact" />
                              )}
                            </div>
                          )}
                          {/* 图片展示 */}
                          {images && images.length > 0 && (
                            <div className="item-images" style={{ 
                              display: 'flex', 
                              gap: 8, 
                              marginTop: 12,
                              flexWrap: 'wrap'
                            }}>
                              <Image.PreviewGroup>
                                {images.map((imgUrl: string, imgIndex: number) => (
                                  <Image
                                    key={imgIndex}
                                    src={formatImageUrl(imgUrl)}
                                    alt={`${item.name} - ${t('forum.image')} ${imgIndex + 1}`}
                                    width={100}
                                    height={100}
                                    style={{ 
                                      objectFit: 'cover', 
                                      borderRadius: 4,
                                      border: '1px solid #e8e8e8',
                                      cursor: 'pointer'
                                    }}
                                    preview
                                    loading="lazy"
                                  />
                                ))}
                              </Image.PreviewGroup>
                            </div>
                          )}
                        </div>
                      </div>
                      
                      {/* 右侧：投票区域 */}
                      <div className="item-vote-section" style={{ 
                        display: 'flex', 
                        flexDirection: 'column', 
                        alignItems: 'center', 
                        gap: 8,
                        minWidth: 80,
                        flexShrink: 0
                      }}>
                        <Button
                          type={item.user_vote === 'upvote' ? 'primary' : 'default'}
                          icon={<LikeOutlined />}
                          onClick={() => handleVote(item.id, 'upvote')}
                          className="vote-button vote-up"
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 6,
                            border: '1px solid #d9d9d9',
                            minWidth: 80
                          }}
                        >
                          <span style={{ fontSize: 16, fontWeight: 600 }}>{item.upvotes}</span>
                        </Button>
                        <Button
                          danger={item.user_vote === 'downvote'}
                          type={item.user_vote === 'downvote' ? 'primary' : 'default'}
                          icon={<DislikeOutlined />}
                          onClick={() => handleVote(item.id, 'downvote')}
                          className="vote-button vote-down"
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 6,
                            border: '1px solid #d9d9d9',
                            minWidth: 80
                          }}
                        >
                          <span style={{ fontSize: 16, fontWeight: 600 }}>{item.downvotes}</span>
                        </Button>
                        <div className="item-score" style={{ fontSize: 12, color: '#999', textAlign: 'center' }}>
                          {t('forum.comprehensiveScore')}: {item.vote_score.toFixed(2)}
                        </div>
                      </div>
                    </div>
                    
                    {/* 留言显示：优先显示用户自己的留言，如果没有则显示最多赞的留言 */}
                    {item.display_comment && (
                      <div className="item-comment" style={{
                        marginTop: 12,
                        padding: 12,
                        background: item.display_comment_type === 'user' ? '#f5f5f5' : '#fff7e6',
                        borderRadius: 8,
                        fontSize: 14,
                        border: item.display_comment_type === 'top' ? '1px solid #ffd591' : 'none'
                      }}>
                        <div style={{ 
                          fontWeight: 600, 
                          marginBottom: 4,
                          display: 'flex',
                          alignItems: 'center',
                          gap: 8
                        }}>
                          {item.display_comment_type === 'user' ? (
                            <>
                              {item.user_vote === 'upvote' ? `👍 ${t('forum.yourComment')}` : `👎 ${t('forum.yourComment')}`}
                              {item.user_vote_is_anonymous && (
                                <Tag style={{ 
                                  padding: '2px 6px',
                                  background: '#f0f0f0',
                                  borderRadius: 4,
                                  fontSize: 11,
                                  color: '#666',
                                  border: 'none'
                                }}>
                                  {t('forum.anonymous')}
                                </Tag>
                              )}
                            </>
                          ) : (
                            <>
                              {item.display_comment_info?.vote_type === 'upvote' ? '👍' : '👎'} {t('forum.hotComment')}
                              {item.display_comment_info?.is_anonymous ? (
                                <Tag style={{ 
                                  padding: '2px 6px',
                                  background: '#f0f0f0',
                                  borderRadius: 4,
                                  fontSize: 11,
                                  color: '#666',
                                  border: 'none'
                                }}>
                                  {t('forum.anonymous')}
                                </Tag>
                              ) : (
                                item.display_comment_info?.user_id && (
                                  <Tag style={{ 
                                    padding: '2px 6px',
                                    background: '#e6f7ff',
                                    borderRadius: 4,
                                    fontSize: 11,
                                    color: '#1890ff',
                                    border: 'none'
                                  }}>
                                    {t('forum.user')} {item.display_comment_info.user_id}
                                  </Tag>
                                )
                              )}
                              {item.display_comment_info?.like_count > 0 && (
                                <Tag style={{ 
                                  padding: '2px 6px',
                                  background: '#fff1f0',
                                  borderRadius: 4,
                                  fontSize: 11,
                                  color: '#ff4d4f',
                                  border: 'none'
                                }}>
                                  ❤️ {item.display_comment_info.like_count}
                                </Tag>
                              )}
                            </>
                          )}
                        </div>
                        <div>{item.display_comment}</div>
                      </div>
                    )}
                  </Card>
                );
              })}
            </div>
            
            {/* 分页 */}
            {pagination.total > pagination.pageSize && (
              <div style={{ marginTop: 24, display: 'flex', justifyContent: 'center' }}>
                <Pagination
                  current={pagination.current}
                  pageSize={pagination.pageSize}
                  total={pagination.total}
                  onChange={(page) => {
                    loadData(page);
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                  }}
                  showSizeChanger={false}
                  showQuickJumper
                  showTotal={(total) => t('forum.totalItems', { total })}
                />
              </div>
            )}
          </>
        )}
      </Spin>

      {/* 新增竞品弹窗 */}
      <Modal
        title={t('forum.addItem')}
        open={showSubmitModal}
        onCancel={() => {
          setShowSubmitModal(false);
          form.resetFields();
          setUploadingImages([]);
        }}
        onOk={() => form.submit()}
        width={600}
        confirmLoading={uploading}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmitItem}
        >
          <Form.Item
            name="name"
            label={t('forum.itemName')}
            rules={[
              { required: true, message: t('forum.enterItemName') }, 
              { max: 200, message: t('forum.nameMaxLength') },
              {
                validator: (_, value) => {
                  if (!value) return Promise.resolve();
                  const validation = validateName(value);
                  return validation.valid 
                    ? Promise.resolve() 
                    : Promise.reject(new Error(validation.message));
                }
              }
            ]}
          >
            <Input placeholder={t('forum.itemNamePlaceholder')} maxLength={200} showCount />
          </Form.Item>
          
          <Form.Item
            name="description"
            label={t('forum.itemDescription')}
            rules={[{ max: 1000, message: t('forum.descriptionMaxLength') }]}
          >
            <Input.TextArea rows={4} placeholder={t('forum.itemDescriptionPlaceholder')} maxLength={1000} showCount />
          </Form.Item>
          
          <Form.Item
            name="address"
            label={t('forum.itemAddress')}
            rules={[{ max: 500, message: t('forum.addressMaxLength') }]}
          >
            <Input placeholder={t('forum.itemAddressPlaceholder')} maxLength={500} showCount />
          </Form.Item>
          
          <Form.Item
            name="phone"
            label={t('forum.itemPhone')}
            rules={[{ max: 50, message: t('forum.phoneMaxLength') }]}
          >
            <Input placeholder={t('forum.itemPhonePlaceholder')} maxLength={50} />
          </Form.Item>
          
          <Form.Item
            name="website"
            label={t('forum.itemWebsite')}
            rules={[
              { max: 500, message: t('forum.websiteMaxLength') },
              {
                type: 'url',
                message: t('forum.invalidUrl'),
                validator: (_, value) => {
                  if (!value || value.trim() === '') {
                    return Promise.resolve(); // 允许为空
                  }
                  // 如果有值，验证URL格式
                  try {
                    new URL(value.startsWith('http') ? value : `https://${value}`);
                    return Promise.resolve();
                  } catch {
                    return Promise.reject(new Error(t('forum.invalidUrl')));
                  }
                }
              }
            ]}
          >
            <Input placeholder={t('forum.itemWebsitePlaceholder')} maxLength={500} />
          </Form.Item>
          
          <Form.Item
            label={t('forum.itemImages')}
            extra={t('forum.itemImagesExtra')}
          >
            <Upload
              listType="picture-card"
              fileList={[
                // 已上传完成的图片
                ...uploadingImages.map((url, index) => ({
                  uid: `done-${index}`,
                  name: `image-${index}`,
                  status: 'done' as const,
                  url,
                  thumbUrl: url // 确保有缩略图
                })),
                // 正在上传的图片
                ...uploadingFileList
              ]}
              onChange={handleImageChange}
              onRemove={(file) => {
                // 如果是已完成的图片
                if (file.uid?.startsWith('done-')) {
                  const index = parseInt(file.uid.replace('done-', ''));
                  const url = uploadingImages[index];
                  if (url) {
                    handleRemoveImage(url);
                  }
                } else {
                  // 如果是上传中的图片，从上传列表移除
                  setUploadingFileList(prev => prev.filter(f => f.uid !== file.uid));
                }
                return false;
              }}
              beforeUpload={() => false}
              accept="image/*"
              maxCount={5}
            >
              {(uploadingImages.length + uploadingFileList.length) < 5 && (
                <div>
                  <UploadOutlined />
                  <div style={{ marginTop: 8 }}>{t('forum.uploadImage')}</div>
                </div>
              )}
            </Upload>
          </Form.Item>
        </Form>
      </Modal>

      {/* 举报弹窗 */}
      <Modal
        title={t('forum.reportLeaderboard')}
        open={showReportModal}
        onCancel={() => {
          setShowReportModal(false);
          reportForm.resetFields();
        }}
        onOk={() => reportForm.submit()}
        width={500}
      >
        <Form
          form={reportForm}
          layout="vertical"
          onFinish={async (values) => {
            try {
              await reportLeaderboard(Number(leaderboardId), {
                reason: values.reason,
                description: values.description
              });
              message.success(t('forum.reportSubmitted'));
              setShowReportModal(false);
              reportForm.resetFields();
            } catch (error: any) {
                            const errorMsg = getErrorMessage(error);
              
              if (error.response?.status === 409) {
                message.warning(errorMsg);
              } else if (error.response?.status === 401) {
                message.error('请先登录');
              } else {
                message.error(errorMsg);
              }
            }
          }}
        >
          <Form.Item
            name="reason"
            label={t('forum.reportReason')}
            rules={[
              { required: true, message: t('forum.enterReportReason') },
              { max: 500, message: t('forum.reportReasonMaxLength') }
            ]}
          >
            <Input.TextArea
              rows={3}
              placeholder={t('forum.reportReasonPlaceholder')}
              showCount
              maxLength={500}
            />
          </Form.Item>
          <Form.Item
            name="description"
            label={t('forum.reportDescription')}
            rules={[{ max: 2000, message: t('forum.reportDescriptionMaxLength') }]}
          >
            <Input.TextArea
              rows={4}
              placeholder={t('forum.reportDescriptionPlaceholder')}
              showCount
              maxLength={2000}
            />
          </Form.Item>
        </Form>
      </Modal>

      {/* 投票留言弹窗 */}
      <Modal
        title={currentVoteType === 'upvote' ? t('forum.upvoteAndComment') : t('forum.downvoteAndComment')}
        open={showVoteModal}
        onCancel={() => {
          setShowVoteModal(false);
          voteForm.resetFields();
        }}
        onOk={() => voteForm.submit()}
        width={500}
      >
        <Form
          form={voteForm}
          layout="vertical"
          onFinish={handleVoteSubmit}
        >
          <Form.Item
            name="comment"
            label={t('forum.commentOptional')}
            rules={[{ max: 500, message: t('forum.commentMaxLength') }]}
          >
            <Input.TextArea
              rows={4}
              placeholder={currentVoteType === 'upvote'
                ? t('forum.upvoteCommentPlaceholder')
                : t('forum.downvoteCommentPlaceholder')}
              showCount
              maxLength={500}
            />
          </Form.Item>
          <Form.Item
            name="is_anonymous"
            valuePropName="checked"
          >
            <Checkbox>{t('forum.anonymousVoteComment')}</Checkbox>
          </Form.Item>
        </Form>
      </Modal>

      {/* 移动端响应式样式 */}
      <style>
        {`
          /* 移动端适配 */
          @media (max-width: 768px) {
            /* 外层容器移动端优化 */
            div[style*="maxWidth: 1200"] {
              padding: 12px !important;
            }

            /* 榜单头部卡片移动端优化 */
            .ant-card {
              margin-bottom: 16px !important;
            }

            /* 榜单头部布局移动端优化 */
            .leaderboard-header-container {
              flex-direction: column !important;
              gap: 12px !important;
            }

            /* 封面图片容器移动端优化 */
            .leaderboard-cover-image-wrapper {
              width: 100% !important;
              display: flex !important;
              justify-content: center !important;
              align-items: center !important;
            }

            /* 封面图片移动端优化 */
            .leaderboard-cover-image-wrapper .ant-image,
            .leaderboard-cover-image-wrapper img {
              width: 100% !important;
              max-width: 100% !important;
              height: auto !important;
              min-height: 150px !important;
              max-height: 250px !important;
              object-fit: cover !important;
              border-radius: 8px !important;
            }

            /* 榜单头部内容区域移动端优化 */
            .leaderboard-header-content {
              width: 100% !important;
            }

            /* 标题移动端优化 */
            h1[style*="margin: 0"] {
              font-size: 20px !important;
              flex-wrap: wrap !important;
            }

            /* 标签组移动端优化 */
            .ant-space {
              flex-wrap: wrap !important;
              gap: 8px !important;
            }

            /* 按钮组移动端优化 */
            div[style*="display: flex"][style*="gap: 8"] {
              flex-wrap: wrap !important;
              gap: 8px !important;
            }

            div[style*="display: flex"][style*="gap: 8"] button {
              flex: 1 1 calc(50% - 4px) !important;
              min-width: calc(50% - 4px) !important;
              font-size: 13px !important;
            }

            /* 确保按钮文字不换行 */
            div[style*="display: flex"][style*="gap: 8"] button span {
              white-space: nowrap !important;
            }

            /* 排序选择移动端优化 */
            div[style*="display: flex"][style*="justifyContent: space-between"] {
              flex-direction: column !important;
              gap: 12px !important;
            }

            /* 竞品列表移动端优化 */
            div[style*="display: flex"][style*="flexDirection: column"][style*="gap: 16"] {
              gap: 12px !important;
            }

            /* 竞品卡片移动端优化 */
            .leaderboard-item-card .ant-card-body {
              padding: 12px !important;
            }

            /* 竞品卡片头部移动端布局 */
            .item-card-header {
              flex-direction: column !important;
              gap: 16px !important;
            }

            /* 竞品内容区域移动端优化 */
            .item-card-content {
              width: 100% !important;
            }

            /* 排名数字移动端优化 */
            .item-rank {
              font-size: 20px !important;
              margin-right: 8px !important;
            }

            /* 竞品名称移动端优化 */
            .item-name {
              font-size: 18px !important;
            }

            /* 竞品描述移动端优化 */
            .item-description {
              font-size: 13px !important;
              line-height: 1.5 !important;
            }

            /* 地址移动端优化 */
            .item-address {
              font-size: 11px !important;
            }

            /* 图片展示移动端优化 */
            .item-images .ant-image {
              width: 80px !important;
              height: 80px !important;
            }

            /* 投票区域移动端优化 - 改为横向布局 */
            .item-vote-section {
              flex-direction: row !important;
              width: 100% !important;
              justify-content: space-between !important;
              align-items: center !important;
              padding-top: 12px !important;
              border-top: 1px solid #f0f0f0 !important;
              margin-top: 8px !important;
            }

            /* 投票按钮移动端优化 */
            .vote-button {
              flex: 1 !important;
              min-width: 0 !important;
              max-width: calc(50% - 8px) !important;
            }

            .vote-button span {
              font-size: 14px !important;
            }

            /* 得分移动端优化 */
            .item-score {
              display: none !important;
            }

            /* 留言区域移动端优化 */
            .item-comment {
              font-size: 13px !important;
              padding: 10px !important;
              margin-top: 12px !important;
            }

            /* 分页移动端优化 */
            .ant-pagination {
              margin-top: 16px !important;
            }
          }

          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            div[style*="maxWidth: 1200"] {
              padding: 8px !important;
            }

            /* 封面图片超小屏幕优化 */
            .leaderboard-cover-image-wrapper .ant-image,
            .leaderboard-cover-image-wrapper img {
              min-height: 120px !important;
              max-height: 200px !important;
            }

            h1[style*="margin: 0"] {
              font-size: 18px !important;
            }

            .ant-tag {
              font-size: 12px !important;
              padding: 2px 8px !important;
            }

            .leaderboard-item-card .ant-card-body {
              padding: 10px !important;
            }

            /* 排名数字超小屏幕优化 */
            .item-rank {
              font-size: 18px !important;
            }

            /* 竞品名称超小屏幕优化 */
            .item-name {
              font-size: 16px !important;
            }

            /* 竞品描述超小屏幕优化 */
            .item-description {
              font-size: 12px !important;
            }

            /* 图片展示超小屏幕优化 */
            .item-images .ant-image {
              width: 70px !important;
              height: 70px !important;
            }

            /* 投票按钮超小屏幕优化 */
            .vote-button {
              padding: 4px 8px !important;
            }

            .vote-button span {
              font-size: 13px !important;
            }

            /* 留言区域超小屏幕优化 */
            .item-comment {
              font-size: 12px !important;
              padding: 8px !important;
            }
          }

          /* 极小屏幕优化 */
          @media (max-width: 360px) {
            div[style*="maxWidth: 1200"] {
              padding: 6px !important;
            }

            /* 封面图片极小屏幕优化 */
            .leaderboard-cover-image-wrapper .ant-image,
            .leaderboard-cover-image-wrapper img {
              min-height: 100px !important;
              max-height: 180px !important;
            }

            h1[style*="margin: 0"] {
              font-size: 16px !important;
            }

            /* 排名数字极小屏幕优化 */
            .item-rank {
              font-size: 16px !important;
            }

            /* 竞品名称极小屏幕优化 */
            .item-name {
              font-size: 15px !important;
            }

            /* 图片展示极小屏幕优化 */
            .item-images .ant-image {
              width: 60px !important;
              height: 60px !important;
            }

            /* 投票按钮极小屏幕优化 */
            .vote-button {
              padding: 4px 6px !important;
              font-size: 12px !important;
            }

            .vote-button span {
              font-size: 12px !important;
            }
          }
        `}
      </style>
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

      {/* 分享模态框 */}
      <Modal
        title={t('forum.shareLeaderboard')}
        open={showShareModal}
        onCancel={() => setShowShareModal(false)}
        footer={null}
      >
        <Space direction="vertical" style={{ width: '100%' }} size="large" align="center">
          {leaderboard && (
            <div style={{ textAlign: 'center' }}>
              <QRCode
                value={`${window.location.origin}/${lang}/leaderboard/custom/${leaderboard.id}`}
                size={200}
                style={{ marginBottom: 16 }}
              />
              <Text type="secondary" style={{ fontSize: 12 }}>
                扫描二维码分享到微信
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
              复制链接
            </Button>
            <Button
              type="default"
              onClick={() => handleShareToSocial('weibo')}
              block
            >
              分享到微博
            </Button>
            <Button
              type="default"
              onClick={() => handleShareToSocial('twitter')}
              block
            >
              分享到 Twitter
            </Button>
            <Button
              type="default"
              onClick={() => handleShareToSocial('facebook')}
              block
            >
              分享到 Facebook
            </Button>
          </Space>
        </Space>
      </Modal>
    </div>
  );
};

export default CustomLeaderboardDetail;

