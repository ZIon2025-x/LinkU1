import React, { useState, useEffect, useRef, useLayoutEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Button, Input, Space, Tag, Spin, Empty, Modal, Form, message, Checkbox, Select, Pagination, Image, Upload, QRCode, Typography, Divider } from 'antd';
import { LikeOutlined, DislikeOutlined, PlusOutlined, TrophyOutlined, PhoneOutlined, GlobalOutlined, EnvironmentOutlined, UploadOutlined, DeleteOutlined, ExclamationCircleOutlined, ShareAltOutlined, CopyOutlined } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { TimeHandlerV2 } from '../utils/timeUtils';
import {
  getCustomLeaderboardDetail,
  getLeaderboardItems,
  submitLeaderboardItem,
  voteLeaderboardItem,
  reportLeaderboard
} from '../api';
import { fetchCurrentUser, getPublicSystemSettings, logout } from '../api';
import { LOCATIONS } from '../constants/leaderboard';
import { compressImage } from '../utils/imageCompression';
import api from '../api';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
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
  const [unreadCount, setUnreadCount] = useState(0);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);

  // 用于分享的描述（直接使用榜单描述，限制长度在200字符内，微信分享建议不超过200字符）
  const shareDescription = leaderboard && leaderboard.description ? leaderboard.description.substring(0, 200) : '';
  // 修复：使用正确的路由路径 /leaderboard/custom/:leaderboardId
  const canonicalUrl = leaderboard ? `https://www.link2ur.com/${lang}/leaderboard/custom/${leaderboard.id}` : `https://www.link2ur.com/${lang}/forum/leaderboard`;

  // SEO优化：使用useLayoutEffect确保在DOM渲染前就设置meta标签，优先级最高
  // 参考任务分享的实现方式
  useLayoutEffect(() => {
    if (!leaderboard) return;
    
    // 直接使用榜单描述，限制长度在200字符内（微信分享建议不超过200字符）
    const currentShareDescription = leaderboard.description ? leaderboard.description.substring(0, 200) : '';
    
    // 图片优先使用榜单封面图片（cover_image），如果没有则使用默认logo
    // 参考任务分享的逻辑：优先使用任务图片，否则使用默认logo
    let shareImageUrl = `${window.location.origin}/static/favicon.png?v=2`;
    if (leaderboard.cover_image) {
      // 确保图片URL是绝对路径
      const coverImageUrl = leaderboard.cover_image;
      if (coverImageUrl.startsWith('http://') || coverImageUrl.startsWith('https://')) {
        shareImageUrl = coverImageUrl;
      } else if (coverImageUrl.startsWith('/')) {
        shareImageUrl = `${window.location.origin}${coverImageUrl}`;
      } else {
        shareImageUrl = `${window.location.origin}/${coverImageUrl}`;
      }
    }
    
    // 分享标题：榜单名称 + 平台名称
    const shareTitle = `${leaderboard.name} - Link²Ur榜单`;
    
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
    const allWeixinImages = document.querySelectorAll('meta[name="weixin:image"]');
    allWeixinImages.forEach(tag => tag.remove());
    const weixinImageTag = document.createElement('meta');
    weixinImageTag.setAttribute('name', 'weixin:image');
    weixinImageTag.content = shareImageUrl;
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
    
    // 使用多个setTimeout确保在DOM完全加载后多次强制更新微信标签（防止被其他脚本覆盖）
    // 微信爬虫可能在页面加载的不同阶段抓取，所以需要多次更新
    setTimeout(() => {
      // 再次检查并确保微信描述正确（特别检查是否包含默认描述）
      const weixinDesc = document.querySelector('meta[name="weixin:description"]') as HTMLMetaElement;
      if (!weixinDesc || weixinDesc.content !== currentShareDescription || 
          weixinDesc.content.includes('Professional task publishing') ||
          weixinDesc.content.includes('skill matching platform')) {
        if (weixinDesc) weixinDesc.remove();
        const finalWeixinDesc = document.createElement('meta');
        finalWeixinDesc.setAttribute('name', 'weixin:description');
        finalWeixinDesc.content = currentShareDescription;
        document.head.insertBefore(finalWeixinDesc, document.head.firstChild);
      }
      
      // 再次检查并确保微信标题正确
      const weixinTitle = document.querySelector('meta[name="weixin:title"]') as HTMLMetaElement;
      const expectedTitle = shareTitle;
      if (!weixinTitle || weixinTitle.content !== expectedTitle || weixinTitle.content === 'Link²Ur') {
        if (weixinTitle) weixinTitle.remove();
        const finalWeixinTitle = document.createElement('meta');
        finalWeixinTitle.setAttribute('name', 'weixin:title');
        finalWeixinTitle.content = expectedTitle;
        document.head.insertBefore(finalWeixinTitle, document.head.firstChild);
      }
      
      // 再次检查并确保微信图片正确
      const weixinImage = document.querySelector('meta[name="weixin:image"]') as HTMLMetaElement;
      if (!weixinImage || weixinImage.content !== shareImageUrl) {
        if (weixinImage) weixinImage.remove();
        const finalWeixinImage = document.createElement('meta');
        finalWeixinImage.setAttribute('name', 'weixin:image');
        finalWeixinImage.content = shareImageUrl;
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
      console.error('加载失败:', error);
      
      // 处理不同类型的错误
      if (error.response?.status === 404) {
        message.error('榜单不存在或已被删除');
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限访问此榜单');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.warning(`请求过于频繁，请在 ${retryAfter} 秒后重试`);
      } else if (error.response?.status >= 500) {
        message.error('服务器错误，请稍后重试');
      } else {
        message.error(error.response?.data?.detail || '加载失败，请稍后重试');
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
        message.success('投票已取消');
        loadData();
      } catch (error: any) {
        message.error(error.response?.data?.detail || '取消投票失败');
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
      message.success('投票成功');
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
      console.error('投票失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '投票失败';
      
      // 处理速率限制错误
      if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(`操作过于频繁，请在 ${retryAfter} 秒后重试`);
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限执行此操作');
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
        throw new Error('上传失败');
      }
    } catch (error: any) {
      console.error('图片上传失败:', error);
      message.error(`图片上传失败: ${error.response?.data?.detail || error.message}`);
      throw error;
    } finally {
      setUploading(false);
    }
  };

  const handleImageChange = (info: any) => {
    const { file, fileList } = info;
    
    console.log('handleImageChange 触发:', {
      fileStatus: file.status,
      hasOriginFileObj: !!file.originFileObj,
      fileUid: file.uid,
      fileListLength: fileList.length
    });
    
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
        console.log('文件已存在，跳过:', fileToUpload.name);
        return;
      }
      
      const tempId = file.uid || `temp-${Date.now()}-${Math.random()}`;
      
      // 创建临时预览 URL
      const previewUrl = URL.createObjectURL(fileToUpload);
      previewUrlsRef.current.add(previewUrl);
      
      console.log('创建新文件预览:', {
        tempId,
        fileName: fileToUpload.name,
        previewUrl: previewUrl.substring(0, 50) + '...'
      });
      
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
        console.log('更新上传列表，当前文件数:', newList.length);
        return newList;
      });
      
      // 延迟执行压缩和上传，避免阻塞 UI
      setTimeout(async () => {
        try {
          console.log('开始上传图片:', fileToUpload.name);
          const url = await handleImageUpload(fileToUpload);
          console.log('图片上传成功:', url);
          
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
          message.success('图片上传成功');
        } catch (error) {
          console.error('图片上传失败:', error);
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
      console.log('无法获取文件对象，跳过处理:', file);
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
      console.log('提交竞品数据:', submitData);
      await submitLeaderboardItem(submitData);
      message.success('竞品新增成功');
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
      console.error('新增竞品失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '新增失败';
      
      // 处理不同类型的错误
      if (error.response?.status === 400) {
        if (errorMsg.includes('已存在')) {
          message.error('该榜单中已存在相同名称的竞品');
        } else {
          message.error(errorMsg);
        }
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限执行此操作');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(`操作过于频繁，请在 ${retryAfter} 秒后重试`);
      } else {
        message.error(errorMsg);
      }
    }
  };

  const handleShare = async () => {
    if (!leaderboard) return;
    
    // 直接使用榜单描述
    const currentShareDescription = leaderboard.description ? leaderboard.description.substring(0, 200) : '';
    
    // 强制移除所有描述标签（包括默认的和SEOHead创建的）
    const allDescriptionTags = document.querySelectorAll('meta[name="description"], meta[property="og:description"], meta[name="twitter:description"], meta[name="weixin:description"]');
    allDescriptionTags.forEach(tag => tag.remove());
    
    // 立即重新设置正确的描述
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
    
    // 修复：使用正确的路由路径
    const shareUrl = `${window.location.origin}/${lang}/leaderboard/custom/${leaderboard.id}`;
    const shareTitle = `${leaderboard.name} - Link²Ur榜单`;
    const shareText = `${shareTitle}\n\n${currentShareDescription}\n\n${shareUrl}`;
    
    // 尝试使用 Web Share API
    if (navigator.share) {
      try {
        await navigator.share({
          title: shareTitle,
          text: shareText,
          url: shareUrl
        });
        message.success('分享成功');
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
      message.success('链接已复制到剪贴板');
      setShowShareModal(false);
    } catch (error) {
      message.error('复制失败');
    }
  };

  const handleShareToSocial = (platform: string) => {
    if (!leaderboard) return;
    
    // 直接使用榜单描述（限制在200字符内）
    const currentShareDescription = leaderboard.description ? leaderboard.description.substring(0, 200) : '';
    
    // 如果是微信分享（通过二维码），立即更新 meta 标签
    if (platform === 'wechat') {
      // 强制更新微信描述标签
      const allWeixinDesc = document.querySelectorAll('meta[name="weixin:description"]');
      allWeixinDesc.forEach(tag => tag.remove());
      const newWeixinDesc = document.createElement('meta');
      newWeixinDesc.setAttribute('name', 'weixin:description');
      newWeixinDesc.content = currentShareDescription;
      document.head.insertBefore(newWeixinDesc, document.head.firstChild);
    }
    
    // 修复：使用正确的路由路径
    const shareUrl = encodeURIComponent(`${window.location.origin}/${lang}/leaderboard/custom/${leaderboard.id}`);
    const shareTitle = encodeURIComponent(`${leaderboard.name} - Link²Ur榜单`);
    const shareDescription = encodeURIComponent(currentShareDescription);
    
    let shareWindowUrl = '';
    
    switch (platform) {
      case 'weibo':
        shareWindowUrl = `https://service.weibo.com/share/share.php?url=${shareUrl}&title=${shareTitle} ${shareDescription}`;
        break;
      case 'twitter':
        shareWindowUrl = `https://twitter.com/intent/tweet?url=${shareUrl}&text=${shareTitle} ${shareDescription}`;
        break;
      case 'facebook':
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

  if (loading) {
    return <Spin size="large" />;
  }

  if (!leaderboard) {
    return <Empty description="榜单不存在" />;
  }

  return (
    <div className={styles.container}>
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
                src={leaderboard.cover_image}
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
              <Tag>📦 {leaderboard.item_count} 个竞品</Tag>
              <Tag>👍 {leaderboard.vote_count} 票</Tag>
              <Tag>👁️ {leaderboard.view_count} 浏览</Tag>
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
                新增竞品
              </Button>
              <Button
                icon={<ShareAltOutlined />}
                onClick={handleShare}
              >
                分享榜单
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
                举报榜单
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
          <Option value="vote_score">综合得分</Option>
          <Option value="net_votes">净赞数</Option>
          <Option value="upvotes">点赞数</Option>
          <Option value="created_at">最新添加</Option>
        </Select>
        <span style={{ color: '#999', fontSize: 14 }}>
          共 {pagination.total} 个竞品
        </span>
      </div>

      {/* 竞品列表 */}
      <Spin spinning={loading}>
        {items.length === 0 && !loading ? (
          <Empty description="暂无竞品" />
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
                                    src={imgUrl}
                                    alt={`${item.name} - 图片 ${imgIndex + 1}`}
                                    width={100}
                                    height={100}
                                    style={{ 
                                      objectFit: 'cover', 
                                      borderRadius: 4,
                                      border: '1px solid #e8e8e8',
                                      cursor: 'pointer'
                                    }}
                                    preview
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
                          得分: {item.vote_score.toFixed(2)}
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
                              {item.user_vote === 'upvote' ? '👍 你的留言' : '👎 你的留言'}
                              {item.user_vote_is_anonymous && (
                                <Tag style={{ 
                                  padding: '2px 6px',
                                  background: '#f0f0f0',
                                  borderRadius: 4,
                                  fontSize: 11,
                                  color: '#666',
                                  border: 'none'
                                }}>
                                  匿名
                                </Tag>
                              )}
                            </>
                          ) : (
                            <>
                              {item.display_comment_info?.vote_type === 'upvote' ? '👍' : '👎'} 热门留言
                              {item.display_comment_info?.is_anonymous ? (
                                <Tag style={{ 
                                  padding: '2px 6px',
                                  background: '#f0f0f0',
                                  borderRadius: 4,
                                  fontSize: 11,
                                  color: '#666',
                                  border: 'none'
                                }}>
                                  匿名
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
                                    用户 {item.display_comment_info.user_id}
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
                  showTotal={(total) => `共 ${total} 个竞品`}
                />
              </div>
            )}
          </>
        )}
      </Spin>

      {/* 新增竞品弹窗 */}
      <Modal
        title="新增竞品"
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
            label="竞品名称"
            rules={[{ required: true, message: '请输入竞品名称' }, { max: 200, message: '名称最多200字' }]}
          >
            <Input placeholder="例如：海底捞" maxLength={200} showCount />
          </Form.Item>
          
          <Form.Item
            name="description"
            label="描述"
            rules={[{ max: 1000, message: '描述最多1000字' }]}
          >
            <Input.TextArea rows={4} placeholder="描述这个竞品的特点" maxLength={1000} showCount />
          </Form.Item>
          
          <Form.Item
            name="address"
            label="地址"
            rules={[{ max: 500, message: '地址最多500字' }]}
          >
            <Input placeholder="详细地址" maxLength={500} showCount />
          </Form.Item>
          
          <Form.Item
            name="phone"
            label="电话（可选）"
            rules={[{ max: 50, message: '电话最多50字' }]}
          >
            <Input placeholder="联系电话（可选）" maxLength={50} />
          </Form.Item>
          
          <Form.Item
            name="website"
            label="网站（可选）"
            rules={[
              { max: 500, message: '网站地址最多500字' },
              {
                type: 'url',
                message: '请输入有效的网址',
                validator: (_, value) => {
                  if (!value || value.trim() === '') {
                    return Promise.resolve(); // 允许为空
                  }
                  // 如果有值，验证URL格式
                  try {
                    new URL(value.startsWith('http') ? value : `https://${value}`);
                    return Promise.resolve();
                  } catch {
                    return Promise.reject(new Error('请输入有效的网址'));
                  }
                }
              }
            ]}
          >
            <Input placeholder="官方网站（可选，如：https://example.com）" maxLength={500} />
          </Form.Item>
          
          <Form.Item
            label="图片"
            extra="最多上传5张图片，每张不超过5MB"
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
                  <div style={{ marginTop: 8 }}>上传图片</div>
                </div>
              )}
            </Upload>
          </Form.Item>
        </Form>
      </Modal>

      {/* 举报弹窗 */}
      <Modal
        title="举报榜单"
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
              message.success('举报已提交，我们会尽快处理');
              setShowReportModal(false);
              reportForm.resetFields();
            } catch (error: any) {
              console.error('举报失败:', error);
              const errorMsg = error.response?.data?.detail || error.message || '举报失败';
              
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
            label="举报原因"
            rules={[
              { required: true, message: '请输入举报原因' },
              { max: 500, message: '举报原因不能超过500字' }
            ]}
          >
            <Input.TextArea
              rows={3}
              placeholder="请详细说明举报原因，例如：内容不当、虚假信息、恶意刷票等"
              showCount
              maxLength={500}
            />
          </Form.Item>
          <Form.Item
            name="description"
            label="详细描述（可选）"
            rules={[{ max: 2000, message: '详细描述不能超过2000字' }]}
          >
            <Input.TextArea
              rows={4}
              placeholder="可以补充更多详细信息，帮助我们更好地处理您的举报"
              showCount
              maxLength={2000}
            />
          </Form.Item>
        </Form>
      </Modal>

      {/* 投票留言弹窗 */}
      <Modal
        title={currentVoteType === 'upvote' ? '点赞并留言' : '点踩并留言'}
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
            label="留言（可选）"
            rules={[{ max: 500, message: '留言最多500字' }]}
          >
            <Input.TextArea
              rows={4}
              placeholder={currentVoteType === 'upvote'
                ? '分享你的使用体验，例如：物美价廉，服务人员很暖心'
                : '请说明原因，帮助其他用户了解'}
              showCount
              maxLength={500}
            />
          </Form.Item>
          <Form.Item
            name="is_anonymous"
            valuePropName="checked"
          >
            <Checkbox>匿名投票/留言</Checkbox>
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
        title="分享榜单"
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

