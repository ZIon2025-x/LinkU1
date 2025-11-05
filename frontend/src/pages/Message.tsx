import React, { useEffect, useRef, useState, useCallback } from 'react';
import { API_BASE_URL, WS_BASE_URL, API_ENDPOINTS } from '../config';
import api, { fetchCurrentUser, getContacts, getChatHistory, assignCustomerService, sendMessage, checkCustomerServiceAvailability, markChatMessagesAsRead, getContactUnreadCounts, getUserProfile } from '../api';
import { useLocation, useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { useTranslation } from '../hooks/useTranslation';

// 私密图片显示组件
const PrivateImageDisplay: React.FC<{
  imageId: string;
  currentUserId: string;
  style: React.CSSProperties;
  alt?: string;
}> = ({ imageId, currentUserId, style, alt = "Private Image" }) => {
  const [imageUrl, setImageUrl] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    const loadImage = async () => {
      try {
        setLoading(true);
        setError(false);
        
        // 生成图片访问URL
        const response = await api.post('/api/messages/generate-image-url', {
          image_id: imageId
        });
        
        if (response.data.success) {
          const { image_url } = response.data;
          
          // 使用fetch加载图片
          const imgResponse = await fetch(image_url, {
            method: 'GET',
            credentials: 'include',
            headers: {
              'Accept': 'image/*',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache'
            }
          });
          
          if (imgResponse.ok) {
            const blob = await imgResponse.blob();
            const blobUrl = URL.createObjectURL(blob);
            setImageUrl(blobUrl);
          } else {
            throw new Error(`HTTP ${imgResponse.status}: ${imgResponse.statusText}`);
          }
        } else {
          throw new Error('生成图片URL失败');
        }
        
      } catch (err) {
        console.error('私密图片加载错误:', err, imageId);
        setError(true);
      } finally {
        setLoading(false);
      }
    };

    if (imageId && currentUserId) {
      loadImage();
    }
    
    // 清理blob URL
    return () => {
      if (imageUrl && imageUrl.startsWith('blob:')) {
        URL.revokeObjectURL(imageUrl);
      }
    };
  }, [imageId, currentUserId]);

  if (loading) {
    return (
      <div style={{
        ...style,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#f3f4f6',
        color: '#6b7280',
        minHeight: '100px'
      }}>
        <div style={{ fontSize: '14px' }}>Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{
        ...style,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'linear-gradient(135deg, #f3f4f6, #e5e7eb)',
        color: '#6b7280',
        border: '2px dashed #d1d5db',
        padding: '16px',
        minHeight: '100px',
        textAlign: 'center'
      }}>
        <div style={{ fontSize: '20px', marginBottom: '6px' }}>🔒</div>
        <div style={{ fontWeight: '600', marginBottom: '4px', fontSize: '12px' }}>
          Private image loading failed
        </div>
        <div style={{ fontSize: '10px', opacity: 0.7 }}>
          Insufficient permissions or network error
        </div>
      </div>
    );
  }

  return (
    <img 
      src={imageUrl} 
      alt={alt} 
      style={{
        ...style,
        maxWidth: '100%',
        maxHeight: '100%',
        objectFit: 'cover'
      }}
      onError={() => {
        console.error('图片显示失败:', imageId);
        setError(true);
      }}
    />
  );
};

// 旧的私有图片加载组件已删除 - 现在使用PrivateImageDisplay组件

// 移动端检测函数
const isMobileDevice = () => {
  // 检查屏幕宽度
  const isSmallScreen = window.innerWidth <= 768;
  // 检查User Agent
  const isMobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  // 检查触摸支持
  const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  
  return isSmallScreen || (isMobileUA && isTouchDevice);
};

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

// 旧的时间处理函数已移除，现在使用 TimeHandlerV2 统一处理

// 表情列表 - 提取到组件外部，避免每次渲染重新创建
const EMOJI_LIST = ['😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾'];

interface Message {
  id?: number;
  from: string;
  content: string;
  created_at: string;
}

interface Contact {
  id: string;
  name: string;
  avatar: string;
  unreadCount?: number;
  is_verified?: boolean;
  last_message_time?: string | null;
  email?: string;
  user_level?: number;
  task_count?: number;
  completed_task_count?: number;
  avg_rating?: number;
}


interface CustomerServiceChat {
  chat_id: string;
  user_id: string;
  service_id: string;
  is_ended: number;
  created_at: string;
  ended_at?: string;
  last_message_at: string;
  total_messages: number;
  user_rating?: number;
  user_comment?: string;
  rated_at?: string;
}

const MessagePage: React.FC = () => {
  const { t } = useLanguage();
  
  // 添加CSS动画样式
  React.useEffect(() => {
    const style = document.createElement('style');
    style.textContent = `
      @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
      }
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
    `;
    document.head.appendChild(style);
    return () => {
      if (document.head.contains(style)) {
        document.head.removeChild(style);
      }
    };
  }, []);
  const [user, setUser] = useState<any>(null);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [contactsLoading, setContactsLoading] = useState<boolean>(false);
  const [activeContact, setActiveContact] = useState<Contact | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [isNewMessage, setIsNewMessage] = useState(false);
  const [isServiceMode, setIsServiceMode] = useState(false);
  const [currentChat, setCurrentChat] = useState<CustomerServiceChat | null>(null);
  const [rating, setRating] = useState(5);
  const [ratingComment, setRatingComment] = useState('');
  const [timezoneInfo, setTimezoneInfo] = useState<any>(null);
  const [userTimezone, setUserTimezone] = useState<string>('');
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [loading, setLoading] = useState(true);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [isConnectingToService, setIsConnectingToService] = useState(false);
  const [serviceConnected, setServiceConnected] = useState(false);
  const [showSystemWarning, setShowSystemWarning] = useState(true);
  const [currentChatId, setCurrentChatId] = useState<string | null>(null);
  const [showRatingModal, setShowRatingModal] = useState(false);
  const [ratingChatId, setRatingChatId] = useState<string | null>(null);
  const [serviceAvailable, setServiceAvailable] = useState<boolean>(false);
  const [serviceStatusLoading, setServiceStatusLoading] = useState<boolean>(true);
  const [isMobile, setIsMobile] = useState(false);
  
  // 翻译相关状态
  const { translate } = useTranslation();
  const { language } = useLanguage();
  // 使用消息ID或内容+时间戳作为key
  const [messageTranslations, setMessageTranslations] = useState<Map<string, string>>(new Map());
  const [translatingMessages, setTranslatingMessages] = useState<Set<string>>(new Set());
  
  // 简单的语言检测：检查是否包含中文字符
  const detectTextLanguage = (text: string): 'zh' | 'en' => {
    if (!text || !text.trim()) return 'en';
    const hasChinese = /[\u4e00-\u9fff]/.test(text);
    return hasChinese ? 'zh' : 'en';
  };
  
  // 获取消息的唯一标识
  const getMessageKey = (msg: Message): string => {
    if (msg.id) {
      return `msg_${msg.id}`;
    }
    // 如果没有ID，使用内容和时间戳
    return `msg_${msg.content}_${msg.created_at}`;
  };
  
  // 翻译消息
  const handleTranslateMessage = async (msg: Message, content: string) => {
    // 如果是系统消息、图片消息或文件消息，不翻译
    if (content.startsWith('[图片]') || content.startsWith('[文件]')) {
      return;
    }
    
    const messageKey = getMessageKey(msg);
    
    // 如果已经有翻译，切换显示
    if (messageTranslations.has(messageKey)) {
      const newTranslations = new Map(messageTranslations);
      newTranslations.delete(messageKey);
      setMessageTranslations(newTranslations);
      return;
    }
    
    // 检测文本语言
    const textLang = detectTextLanguage(content);
    
    // 如果文本语言和界面语言相同，不需要翻译
    if (textLang === language) {
      return;
    }
    
    // 开始翻译
    setTranslatingMessages(prev => new Set(prev).add(messageKey));
    try {
      const targetLang = language;
      const translated = await translate(content, targetLang, textLang);
      setMessageTranslations(prev => {
        const newMap = new Map(prev);
        newMap.set(messageKey, translated);
        return newMap;
      });
    } catch (error) {
      console.error('翻译消息失败:', error);
    } finally {
      setTranslatingMessages(prev => {
        const newSet = new Set(prev);
        newSet.delete(messageKey);
        return newSet;
      });
    }
  };
  const [showContactsList, setShowContactsList] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [uploadingFile, setUploadingFile] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [filePreview, setFilePreview] = useState<string | null>(null);
  const [showImagePreview, setShowImagePreview] = useState(false);
  const [previewImageUrl, setPreviewImageUrl] = useState('');
  const [showMobileImageSendModal, setShowMobileImageSendModal] = useState(false);
  const [totalUnreadCount, setTotalUnreadCount] = useState(0);
  const [contactUnreadCounts, setContactUnreadCounts] = useState<{[contactId: string]: number}>({});
  
  // 无限滚动相关状态
  const [loadingMoreMessages, setLoadingMoreMessages] = useState(false);
  const [hasMoreMessages, setHasMoreMessages] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  
  // 缓存相关状态
  const [contactsLoaded, setContactsLoaded] = useState(false);
  const [lastLoadTime, setLastLoadTime] = useState(0);
  
  // 滚动控制状态
  const [shouldScrollToBottom, setShouldScrollToBottom] = useState(false);
  const [showScrollToBottomButton, setShowScrollToBottomButton] = useState(false);
  
  // 发送状态
  const [isSending, setIsSending] = useState(false);

  const location = useLocation();
  const navigate = useNavigate();

  // 格式化时间为用户时区 - 使用新的统一时间处理系统
  const formatTime = (timeString: string) => {
    try {
      return TimeHandlerV2.formatDetailedTime(timeString, userTimezone, t);
    } catch (error) {
      console.error('时间格式化错误:', error);
      return timeString;
    }
  };

  // 添加表情到输入框
  const addEmoji = (emoji: string) => {
    setInput(prev => prev + emoji);
    setShowEmojiPicker(false);
  };

  // 处理图片选择
  const handleImageSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // 检查文件大小（限制为5MB）
      if (file.size > 5 * 1024 * 1024) {
        alert(t('messages.imageTooLarge'));
        return;
      }
      
      // 检查文件类型
      if (!file.type.startsWith('image/')) {
        alert(t('messages.pleaseSelectImage'));
        return;
      }
      
      setSelectedImage(file);
      
      // 创建预览
      const reader = new FileReader();
      reader.onload = (e) => {
        const previewUrl = e.target?.result as string;
        setImagePreview(previewUrl);
        
        // 移动端显示发送弹窗，桌面端显示预览区域
        if (isMobile) {
          setShowMobileImageSendModal(true);
          setPreviewImageUrl(previewUrl);
        }
      };
      reader.readAsDataURL(file);
    }
  };

  // 处理文件选择
  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // 检查文件大小（限制为10MB）
      if (file.size > 10 * 1024 * 1024) {
        alert(t('messages.fileTooLarge'));
        return;
      }
      
      setSelectedFile(file);
      
      // 创建文件信息预览
      const fileInfo = {
        name: file.name,
        size: file.size,
        type: file.type,
        lastModified: file.lastModified
      };
      setFilePreview(JSON.stringify(fileInfo));
    }
  };

  // 发送图片
  const sendImage = async () => {
    if (!selectedImage) return;
    
    setUploadingImage(true);
    
    try {
      // 检查图片大小，如果超过5MB则拒绝上传
      const maxFileSize = 5 * 1024 * 1024; // 5MB
      if (selectedImage.size > maxFileSize) {
        alert(t('messages.imageTooLargeAlert', { size: (selectedImage.size / 1024 / 1024).toFixed(2) }));
        setUploadingImage(false);
        return;
      }
      
      const formData = new FormData();
      formData.append('image', selectedImage);
      
      // 上传图片到服务器
      const uploadResponse = await fetch(`${API_BASE_URL}/api/upload/image`, {
        method: 'POST',
        credentials: 'include',  // 使用Cookie认证
        body: formData
      });
      
      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text();
        console.error('上传失败响应:', errorText);
        throw new Error(`图片上传失败: ${uploadResponse.status} - ${errorText}`);
      }
      
      const uploadResult = await uploadResponse.json();
      
      if (!uploadResult.image_id) {
        throw new Error('服务器未返回图片ID');
      }
      
      const imageId = uploadResult.image_id;
      
      // 发送包含图片ID的消息
      const messageContent = `[图片] ${imageId}`;
      
      await sendImageMessage(messageContent);
      
      // 清除图片选择
      setSelectedImage(null);
      setImagePreview(null);
      
    } catch (error) {
      console.error('发送图片失败:', error);
      alert(t('messages.sendImageFailed', { error: error instanceof Error ? error.message : String(error) }));
    } finally {
      setUploadingImage(false);
    }
  };


  // 发送图片消息的通用方法
  const sendImageMessage = async (messageContent: string) => {
    if (ws && ws.readyState === WebSocket.OPEN) {
      if (isServiceMode && currentChat) {
        const messageData = {
          receiver_id: currentChat.service_id,
          content: messageContent,
          chat_id: currentChat.chat_id
        };
        ws.send(JSON.stringify(messageData));
      } else if (activeContact) {
        const messageData = {
          receiver_id: activeContact.id,
          content: messageContent
        };
        ws.send(JSON.stringify(messageData));
      }
      
      // 立即添加消息到本地状态
      const newMessage = {
        id: Date.now(),
        from: t('messages.me'),
        content: messageContent,
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, newMessage]);
      
      // 更新联系人排序
      if (activeContact && !isServiceMode) {
        updateContactOrder(activeContact.id, new Date().toISOString());
      }
    } else {
      // WebSocket未连接，使用HTTP API
      if (isServiceMode && currentChat) {
        // 获取 CSRF token
        const csrfToken = document.cookie
          .split('; ')
          .find(row => row.startsWith('csrf_token='))
          ?.split('=')[1];
          
        const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${currentChat.chat_id}/send-message`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
          },
          credentials: 'include',  // 使用Cookie认证
          body: JSON.stringify({ content: messageContent })
        });
        
        if (!response.ok) {
          throw new Error('发送消息失败');
        }
        
        const newMessage = {
          id: Date.now(),
          from: t('messages.me'),
          content: messageContent,
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, newMessage]);
      } else if (activeContact) {
        const response = await sendMessage({
          receiver_id: activeContact.id,
          content: messageContent
        });
        
        const newMessage = {
          id: response.id,
          from: t('messages.me'),
          content: messageContent,
          created_at: response.created_at
        };
        setMessages(prev => [...prev, newMessage]);
        
        if (activeContact) {
          updateContactOrder(activeContact.id, new Date().toISOString());
        }
      }
    }
  };

  // 取消图片选择
  const cancelImageSelection = () => {
    setSelectedImage(null);
    setImagePreview(null);
  };

  // 发送文件
  const sendFile = async () => {
    if (!selectedFile) return;
    
    setUploadingFile(true);
    
    try {
      const formData = new FormData();
      formData.append('file', selectedFile);
      
      // 上传文件到服务器
      const uploadResponse = await fetch(`${API_BASE_URL}/api/upload/file`, {
        method: 'POST',
        credentials: 'include',  // 使用Cookie认证
        body: formData
      });
      
      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text();
        console.error('上传失败响应:', errorText);
        throw new Error(`文件上传失败: ${uploadResponse.status} - ${errorText}`);
      }
      
      const uploadResult = await uploadResponse.json();
      
      if (!uploadResult.url) {
        throw new Error('服务器未返回文件URL');
      }
      
      const fileUrl = uploadResult.url;
      
      // 发送包含文件URL的消息
      const messageContent = `[文件] ${selectedFile.name} - ${fileUrl}`;
      
      if (ws && ws.readyState === WebSocket.OPEN) {
        if (isServiceMode && currentChat) {
          ws.send(JSON.stringify({
            type: 'message',
            chat_id: currentChat.chat_id,
            content: messageContent
          }));
        } else if (activeContact) {
          ws.send(JSON.stringify({
            type: 'message',
            to: activeContact.id,
            content: messageContent
          }));
        }
        
        // 添加消息到本地状态
        const newMessage: Message = {
          from: user?.id || 'me',
          content: messageContent,
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, newMessage]);
        
        // 更新联系人排序
        if (activeContact && !isServiceMode) {
          updateContactOrder(activeContact.id, new Date().toISOString());
        }
        
        // 清除文件选择
        setSelectedFile(null);
        setFilePreview(null);
      } else {
        throw new Error('WebSocket未连接');
      }
      
    } catch (error) {
      console.error('发送文件失败:', error);
      alert(t('messages.sendFileFailed', { error: error instanceof Error ? error.message : String(error) }));
    } finally {
      setUploadingFile(false);
    }
  };

  // 发送图片（从弹窗）
  const sendImageFromModal = async () => {
    if (!selectedImage || !ws) return;
    
    setUploadingImage(true);
    try {
      const formData = new FormData();
      formData.append('image', selectedImage);
      
      const response = await fetch(`${API_BASE_URL}/api/upload/image`, {
        method: 'POST',
        credentials: 'include',
        body: formData
      });
      
      if (response.ok) {
        const data = await response.json();
        const message = `[图片] ${data.url}`;
        
        // 发送消息
        ws.send(JSON.stringify({
          type: 'message',
          content: message,
          to: currentChat?.chat_id || activeContact?.id
        }));
        
        // 清空图片选择并关闭弹窗
        setSelectedImage(null);
        setImagePreview(null);
        setShowMobileImageSendModal(false);
        setPreviewImageUrl('');
        setInput('');
      } else {
        alert(t('messages.imageUploadFailed'));
      }
    } catch (error) {
      console.error('发送图片失败:', error);
      alert(t('messages.sendImageFailedShort'));
    } finally {
      setUploadingImage(false);
    }
  };

  // 取消文件选择
  const cancelFileSelection = () => {
    setSelectedFile(null);
    setFilePreview(null);
  };

  // 渲染消息内容（支持图片）
  const renderMessageContent = (content: string, message: any) => {
    // 检查是否是图片消息
    if (content.startsWith('[图片] ') || message.image_id) {
      const imageId = message.image_id || content.replace('[图片] ', '');
      
      
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <div style={{ 
            fontSize: '12px', 
            color: '#6b7280', 
            marginBottom: '4px',
            display: 'flex',
            alignItems: 'center',
            gap: '4px'
          }}>
            📷 {t('messages.privateImage')}
            <span style={{ 
              fontSize: '10px', 
              background: '#fef3c7', 
              padding: '2px 6px', 
              borderRadius: '4px',
              color: '#92400e',
              fontWeight: '600'
            }}>
              {t('messages.chatOnly')}
            </span>
          </div>
          <div style={{ 
            maxWidth: '250px', 
            maxHeight: '250px',
            borderRadius: '8px',
            overflow: 'hidden',
            boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
          }}>
            <PrivateImageDisplay
              imageId={imageId}
              currentUserId={user?.id || ''}
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'cover',
                display: 'block'
              }}
              alt={t('messages.privateImage')}
            />
          </div>
        </div>
      );
    }
    
    // 检查是否是文件消息
    if (content.startsWith('[文件] ')) {
      const fileData = content.replace('[文件] ', '');
      const parts = fileData.split(' - ');
      const fileName = parts[0];
      const fileUrl = parts[1];
      
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <div style={{ fontSize: '14px', opacity: 0.8 }}>
            📎 {t('messages.file')}
          </div>
          <div style={{
            padding: '12px',
            background: '#f0fdf4',
            borderRadius: '8px',
            border: '1px solid #bbf7d0',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            cursor: 'pointer',
            transition: 'all 0.2s ease'
          }}
          onClick={() => {
            if (fileUrl) {
              window.open(fileUrl, '_blank');
            }
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = '#dcfce7';
            e.currentTarget.style.transform = 'translateY(-1px)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = '#f0fdf4';
            e.currentTarget.style.transform = 'translateY(0)';
          }}
          >
            <div style={{ fontSize: '24px' }}>📎</div>
            <div style={{ flex: 1 }}>
              <div style={{ 
                fontSize: '14px', 
                fontWeight: '600', 
                color: '#166534',
                marginBottom: '2px'
              }}>
                {fileName}
              </div>
              <div style={{ 
                fontSize: '12px', 
                color: '#6b7280' 
              }}>
                {t('messages.clickToDownload')}
              </div>
            </div>
            <div style={{ 
              fontSize: '12px', 
              color: '#6b7280',
              opacity: 0.7
            }}>
              →
            </div>
          </div>
        </div>
      );
    }
    
    // 普通文本消息
    return <div style={{ fontSize: 16 }}>{content}</div>;
  };

  // 获取用户时区
  // 旧的时间处理函数已移除，现在使用 TimeHandlerV2 统一处理

  // 发送消息
  const handleSend = async () => {
    if (isSending) {
      return;
    }
    
    if (!input.trim()) {
      return;
    }
    
    setIsSending(true);
    
    // 检查客服对话是否已结束
    if (isServiceMode && currentChat && currentChat.is_ended === 1) {
      setIsSending(false);
      const errorMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.chatEndedMessage'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
      
      // 显示提示并引导用户重新联系
      alert(t('messages.chatEndedAlert'));
      return;
    }
    
    const messageContent = input.trim();
    setInput('');
    
    // 生成唯一消息ID防止重复发送
    const messageId = Date.now() + Math.floor(Math.random() * 1000);
    
    // 获取用户时区
    const userTimezone = TimeHandlerV2.getUserTimezone();
    
    // 立即添加消息到本地状态以提供即时反馈
    const newMessage = {
      id: messageId, // 唯一ID
      from: '我',
      content: messageContent,
      created_at: new Date().toISOString(),
    };
    setMessages(prev => [...prev, newMessage]);
    
    // 标记为新消息，触发自动滚动
    setIsNewMessage(true);
    
    try {
      if (ws && ws.readyState === WebSocket.OPEN) {
        if (isServiceMode && currentChat) {
          // 客服模式发送消息
          const messageData = {
            receiver_id: currentChat.service_id,
            content: messageContent,
            chat_id: currentChat.chat_id,
            message_id: messageId, // 添加消息ID防止重复
            timezone: userTimezone, // 添加时区信息
            local_time: new Date().toLocaleString('en-GB', { timeZone: userTimezone }) // 添加本地时间
          };
          ws.send(JSON.stringify(messageData));
        } else if (activeContact) {
          // 普通聊天模式发送消息
          const messageData = {
            receiver_id: activeContact.id,
            content: messageContent,
            message_id: messageId, // 添加消息ID防止重复
            timezone: userTimezone, // 添加时区信息
            local_time: new Date().toLocaleString('en-GB', { timeZone: userTimezone }) // 添加本地时间
          };
          ws.send(JSON.stringify(messageData));
        }
        
        // 更新联系人排序（如果是普通聊天模式）
        if (activeContact && !isServiceMode) {
          updateContactOrder(activeContact.id, newMessage.created_at);
        }
        
        // 发送成功后，使用HTTP API作为备用确认
        try {
          if (activeContact && !isServiceMode) {
            const response = await sendMessage({
              receiver_id: activeContact.id,
              content: messageContent
            });
            
            // 更新本地消息的ID为服务器返回的ID
            if (response) {
              setMessages(prev => prev.map(msg => 
                msg.id === newMessage.id ? { ...msg, id: response.id } : msg
              ));
            }
          }
        } catch (error) {
          // HTTP备用发送失败，但WebSocket已发送
        }
      } else {
        // WebSocket未连接，使用HTTP API作为备用
        if (isServiceMode && currentChat) {
          // 获取 CSRF token
          const csrfToken = document.cookie
            .split('; ')
            .find(row => row.startsWith('csrf_token='))
            ?.split('=')[1];
            
          const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${currentChat.chat_id}/send-message`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
            },
            credentials: 'include',  // 使用Cookie认证
            body: JSON.stringify({ content: messageContent })
          });
          
          if (!response.ok) {
            throw new Error('发送消息失败');
          }
        } else if (activeContact) {
          const response = await sendMessage({
            receiver_id: activeContact.id,
            content: messageContent
          });
          
          // 使用服务器返回的消息数据，避免重复
          if (response) {
            // 更新本地消息的ID为服务器返回的ID
            setMessages(prev => prev.map(msg => 
              msg.id === newMessage.id ? { ...msg, id: response.id } : msg
            ));
            
            // 更新联系人排序（如果是普通聊天模式）
            if (activeContact && !isServiceMode) {
              updateContactOrder(activeContact.id, new Date().toISOString());
            }
          }
        }
      }
      
    } catch (error) {
      console.error('发送消息失败:', error);
      alert(t('messages.sendMessageFailed'));
      setInput(messageContent); // 恢复输入内容
      // 移除失败的消息
      setMessages(prev => prev.filter(msg => msg.id !== newMessage.id));
    } finally {
      setIsSending(false);
    }
  };

  // 检测移动端设备
  useEffect(() => {
    const checkMobile = () => {
      const mobile = isMobileDevice();
      setIsMobile(mobile);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);


  // 移动端初始化时显示联系人列表
  useEffect(() => {
    if (isMobile && !activeContact) {
      // 检查URL参数，如果有uid参数，说明用户想要直接进入聊天
      const urlParams = new URLSearchParams(location.search);
      const targetUserId = urlParams.get('uid');
      
      if (!targetUserId) {
        // 只有在没有URL参数时才显示联系人列表
        setShowContactsList(true);
      }
    }
  }, [isMobile, activeContact, location.search]);

  // 获取当前用户信息
  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
        setLoading(false);
    } catch (error) {
        console.error('Failed to load user:', error);
        setUser(null);
        setLoading(false);
        setShowLoginModal(true);
    }
  };
    loadUser();
  }, [navigate]);

  // 加载联系人列表
  useEffect(() => {
    if (user) {
      loadContacts();
      restoreCustomerServiceChat();
      initializeTimezone();
      checkServiceAvailability(); // 检查客服在线状态
    }
  }, [user]);

  // 当URL参数变化时，只在必要时重新加载联系人列表
  useEffect(() => {
    if (user && location.search.includes('uid=')) {
      // 如果联系人列表为空，才重新加载
      if (contacts.length === 0) {
        loadContacts();
      }
    }
  }, [location.search, user, contacts.length]);

  // 处理URL参数，自动选择指定的联系人
  useEffect(() => {
    if (user && !contactsLoading) { // 等待联系人列表加载完成
      // 尝试从hash中解析参数
      let targetUserId: string | null = null;
      if (location.hash && location.hash.includes('?')) {
        const hashQuery = location.hash.split('?')[1];
        const urlParams = new URLSearchParams(hashQuery);
        targetUserId = urlParams.get('uid');
      }
      // 如果hash中没有，尝试从location.search中获取
      if (!targetUserId && location.search) {
        const urlParams = new URLSearchParams(location.search);
        targetUserId = urlParams.get('uid');
      }
      
      if (targetUserId) {
        
        // 检查当前activeContact是否已经是目标用户
        if (activeContact?.id === targetUserId) {
          return;
        }
        
        // 首先尝试在现有联系人中查找
        const targetContact = contacts.find(contact => contact.id === targetUserId);
        if (targetContact) {
          setActiveContact(targetContact);
          setIsServiceMode(false);
          // 清空消息列表，准备加载新的聊天记录
          setMessages([]);
          
          // 移动端从URL参数进入聊天时，确保不显示联系人列表
          if (isMobile) {
            setShowContactsList(false);
          }
        } else {
          // 如果不在现有联系人中，从后端获取用户的完整信息
          const fetchUserInfo = async () => {
            try {
              const userData = await getUserProfile(targetUserId!);
              const tempContact: Contact = {
                id: targetUserId!,
                name: userData.user?.name || `用户${targetUserId}`,
                avatar: userData.user?.avatar || "/static/avatar1.png",
                email: userData.user?.email || "",
                user_level: userData.user?.user_level || 1,
                task_count: userData.user?.task_count || 0,
                avg_rating: userData.user?.avg_rating || 0.0,
                last_message_time: null,
                is_verified: userData.user?.is_verified || false,
                completed_task_count: userData.user?.completed_task_count || 0
              };
              
              setActiveContact(tempContact);
              setIsServiceMode(false);
              // 清空消息列表，准备加载新的聊天记录
              setMessages([]);
              
              // 移动端从URL参数进入聊天时，确保不显示联系人列表
              if (isMobile) {
                setShowContactsList(false);
              }
            } catch (error) {
              console.error('获取用户信息失败:', error);
              // 如果获取失败，使用默认值
              const tempContact: Contact = {
                id: targetUserId!,
                name: `${t('messages.user')}${targetUserId}`,
                avatar: "/static/avatar1.png",
                email: "",
                user_level: 1,
                task_count: 0,
                completed_task_count: 0,
                avg_rating: 0.0,
                last_message_time: null,
                is_verified: false
              };
              
              setActiveContact(tempContact);
              setIsServiceMode(false);
              setMessages([]);
              
              if (isMobile) {
                setShowContactsList(false);
              }
            }
          };
          
          fetchUserInfo();
        }
      }
    }
  }, [user, location.hash, location.search, contacts, contactsLoading, activeContact?.id, isMobile]);

  // 定期检查客服在线状态（每30秒检查一次）
  useEffect(() => {
    if (!user) return;

    const interval = setInterval(() => {
      checkServiceAvailability();
    }, 30000); // 30秒检查一次

    return () => clearInterval(interval);
  }, [user]);

  // 初始化时区信息
  const initializeTimezone = useCallback(async () => {
    try {
      const detectedTimezone = TimeHandlerV2.getUserTimezone();
      setUserTimezone(detectedTimezone);
      
      const serverTimezoneInfo = await TimeHandlerV2.getTimezoneInfo();
      if (serverTimezoneInfo) {
        setTimezoneInfo(serverTimezoneInfo);
      }
    } catch (error) {
      console.error('初始化时区信息失败:', error);
    }
  }, []);

  // 恢复客服聊天状态
  const restoreCustomerServiceChat = useCallback(async () => {
    try {
      const savedChat = localStorage.getItem('currentCustomerServiceChat');
      if (savedChat) {
        const chatData = JSON.parse(savedChat);
        
        // 检查对话是否已结束
        if (chatData.chat && chatData.chat.is_ended === 0) {
          // 对话未结束，验证对话是否仍然有效
          try {
            const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${chatData.chat.chat_id}/messages`, {
              credentials: 'include'  // 使用Cookie认证
            });
            
            if (response.ok) {
              // 对话仍然有效，恢复现有对话
              setIsServiceMode(true);
              setServiceConnected(true);
              setCurrentChatId(chatData.chat.chat_id);
              setCurrentChat(chatData.chat);
              // setService(chatData.service); // 已移除service状态
              
              // 加载该对话的聊天历史记录
              await loadChatHistory(chatData.service.id, chatData.chat.chat_id);
            } else {
              // 对话无效，清除localStorage并重置状态
              localStorage.removeItem('currentCustomerServiceChat');
              setServiceConnected(false);
              setCurrentChatId(null);
              setCurrentChat(null);
              // setService(null); // 已移除service状态
            }
          } catch (error) {
            console.error('验证对话有效性失败:', error);
            // 验证失败，清除localStorage并重置状态
            localStorage.removeItem('currentCustomerServiceChat');
            setServiceConnected(false);
            setCurrentChatId(null);
            setCurrentChat(null);
            // setService(null); // 已移除service状态
          }
        } else {
          // 对话已结束，清除localStorage并重置状态
          localStorage.removeItem('currentCustomerServiceChat');
          setServiceConnected(false);
          setCurrentChatId(null);
          setCurrentChat(null);
          // setService(null); // 已移除service状态
        }
      }
    } catch (error) {
      console.error('恢复客服对话失败:', error);
      localStorage.removeItem('currentCustomerServiceChat');
      setServiceConnected(false);
      setCurrentChatId(null);
      setCurrentChat(null);
      // setService(null); // 已移除service状态
    }
  }, []);

  const loadContacts = async (forceReload: boolean = false) => {
    // 如果已经加载过且不是强制重新加载，且距离上次加载不到30秒，则跳过
    const now = Date.now();
    if (contactsLoaded && !forceReload && (now - lastLoadTime) < 30000) {
      return;
    }
    
    try {
      setContactsLoading(true);
      
      // 并行加载联系人列表和未读消息数量
      const [contactsData] = await Promise.allSettled([
        getContacts(),
        loadUnreadCount(),
        loadContactUnreadCounts()
      ]);
      
      if (contactsData.status === 'fulfilled') {
        setContacts(contactsData.value || []);
        setContactsLoaded(true);
        setLastLoadTime(now);
      } else {
        console.error('加载联系人失败:', contactsData.reason);
        setContacts([]);
      }
    } catch (error: any) {
      console.error('加载联系人失败:', error);
      console.error('错误详情:', error.response?.data || error.message);
      setContacts([]);
    } finally {
      setContactsLoading(false);
    }
  };

  // 更新联系人排序（当有新消息时）
  const updateContactOrder = (contactId: string, messageTime?: string) => {
    setContacts(prevContacts => {
      const contactIndex = prevContacts.findIndex(c => c.id === contactId);
      if (contactIndex === -1) return prevContacts;
      
      // 将联系人移到列表顶部
      const updatedContacts = [...prevContacts];
      const [contact] = updatedContacts.splice(contactIndex, 1);
      // 使用消息的实际时间，如果没有则使用当前时间
      contact.last_message_time = messageTime || new Date().toISOString();
      updatedContacts.unshift(contact);
      
      return updatedContacts;
    });
  };

  // 页面加载时检查localStorage但不自动恢复客服会话
  useEffect(() => {
    const checkCustomerServiceChat = async () => {
      try {
        const savedChat = localStorage.getItem('currentCustomerServiceChat');
        if (savedChat && user) {
          const chatData = JSON.parse(savedChat);
          
          // 检查对话是否已结束
          if (chatData.chat.is_ended === 1) {
            localStorage.removeItem('currentCustomerServiceChat');
            return;
          }
          
          // 只保存数据，不自动切换到客服模式
          // 用户需要主动点击"联系在线客服"才会恢复会话
        }
      } catch (error) {
        console.error('检查客服对话失败:', error);
        // 清除可能损坏的localStorage数据
        localStorage.removeItem('currentCustomerServiceChat');
      }
    };
    
    if (user) {
      checkCustomerServiceChat();
    }
  }, [user]);

  // 选择联系人时加载聊天历史
  useEffect(() => {
    const handleContactSelection = async () => {
      if (activeContact && user && !isServiceMode) {
        // 切换普通聊天模式时的清理
        if (serviceConnected) {
          setServiceConnected(false);
          setCurrentChatId(null);
          setCurrentChat(null);
        }
        
        // 先清空消息列表，避免旧联系人的消息显示在新联系人上
        setMessages([]);
        
        // 加载聊天记录
        // 使用setTimeout让UI先更新，然后异步加载聊天记录
        setTimeout(() => {
          loadChatHistory(activeContact.id);
        }, 0);
        
        // 立即清除该联系人的未读标识
        setContactUnreadCounts(prev => {
          const newCounts = { ...prev };
          delete newCounts[activeContact.id];
          return newCounts;
        });
        // 切换到新联系人时重新显示系统提示
        setShowSystemWarning(true);
      }
    };
    
    handleContactSelection();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeContact, user, isServiceMode, serviceConnected]);

  // 自动滚动到底部 - 仅针对真正的新消息（发送和接收），不包括系统消息和历史消息
  useEffect(() => {
    if (messagesEndRef.current && messages.length > 0 && !loadingMoreMessages && isNewMessage) {
        const lastMessage = messages[messages.length - 1];
      
      // 只对发送的消息或接收的消息自动滚动到底部，不包括系统消息
      // 包括：我、对方、客服、管理员
      if (lastMessage && (lastMessage.from === t('messages.me') || lastMessage.from === t('messages.other') || lastMessage.from === t('messages.customerService') || lastMessage.from === t('messages.admin'))) {
          setTimeout(() => {
            if (messagesEndRef.current) {
              messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
            }
        }, 100);
        }
      }
      
      // 重置新消息标志
      setIsNewMessage(false);
  }, [messages.length, loadingMoreMessages, isNewMessage]);

  // 点击外部区域和ESC键关闭表情框
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (showEmojiPicker) {
        const target = event.target as HTMLElement;
        // 检查点击的元素是否在表情框内部
        const emojiPicker = document.querySelector('[data-emoji-picker]');
        const emojiButton = document.querySelector('[data-emoji-button]');
        
        if (emojiPicker && !emojiPicker.contains(target) && 
            emojiButton && !emojiButton.contains(target)) {
          setShowEmojiPicker(false);
        }
      }
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        if (showEmojiPicker) {
          setShowEmojiPicker(false);
        }
        if (showImagePreview) {
          setShowImagePreview(false);
        }
        if (showMobileImageSendModal) {
          setShowMobileImageSendModal(false);
        }
      }
    };

    if (showEmojiPicker || showImagePreview || showMobileImageSendModal) {
      document.addEventListener('mousedown', handleClickOutside);
      document.addEventListener('keydown', handleKeyDown);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [showEmojiPicker, showImagePreview, showMobileImageSendModal]);

  // 请求通知权限
  useEffect(() => {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }
  }, []);

  // 播放消息提示音
  const playMessageSound = () => {
    try {
      // 创建音频上下文
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      
      // 创建简单的提示音（440Hz，持续0.2秒）
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();
      
      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);
      
      oscillator.frequency.setValueAtTime(440, audioContext.currentTime);
      oscillator.type = 'sine';
      
      gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.2);
      
      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.2);
    } catch (error) {
      // 无法播放提示音
    }
  };

  // 加载未读消息数量
  const loadUnreadCount = useCallback(async () => {
    if (!user) return;
    
    try {
      const response = await api.get('/api/users/messages/unread/count');
      const newCount = response.data.unread_count || 0;
      setTotalUnreadCount(newCount);
      
      // 更新页面标题
      if (newCount > 0) {
        document.title = t('notifications.pageTitleWithCount').replace('{count}', newCount.toString());
      } else {
        document.title = t('notifications.pageTitle');
      }
    } catch (error) {
      console.error('加载未读消息数量失败:', error);
    }
  }, [user, t]);

  // 加载每个联系人的未读消息数量
  const loadContactUnreadCounts = useCallback(async () => {
    if (!user) return;
    
    try {
      const data = await getContactUnreadCounts();
      setContactUnreadCounts(data.contact_unread_counts || {});
    } catch (error) {
      console.error('加载联系人未读消息数量失败:', error);
    }
  }, [user]);

  // 定期更新未读消息数量（每30秒检查一次）
  useEffect(() => {
    if (!user) return;

    const interval = setInterval(() => {
      loadUnreadCount();
      loadContactUnreadCounts();
    }, 30000); // 30秒检查一次

    return () => clearInterval(interval);
  }, [user, loadUnreadCount, loadContactUnreadCounts]);

  // 页面可见性变化时更新未读消息数量
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && user) {
        // 页面变为可见时，重新加载未读消息数量
        loadUnreadCount();
        loadContactUnreadCounts();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [user, loadUnreadCount, loadContactUnreadCounts]);

  // WebSocket连接 - 实时接收消息
  useEffect(() => {
    if (user) {
      let socket: WebSocket | null = null;
      let reconnectAttempts = 0;
      const maxReconnectAttempts = 5;
      const reconnectDelay = 3000; // 3秒

      const connectWebSocket = () => {
        // 使用Cookie认证，无需在URL中传递token
        const wsUrl = `${WS_BASE_URL}/ws/chat/${user.id}`;
        socket = new WebSocket(wsUrl);
        
        socket.onopen = () => {
          setWs(socket);
          reconnectAttempts = 0; // 重置重连次数
        };
        
        socket.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data);
            
            if (msg.error) {
              return;
            }
            
            // 处理心跳消息
            if (msg.type === 'heartbeat') {
              return;
            }
            
            // 处理对话结束事件
            if (msg.type === 'chat_ended' || msg.type === 'chat_timeout') {
              // 更新currentChat状态
              if (currentChat) {
                setCurrentChat({ ...currentChat, is_ended: 1 });
              }
              // 断开客服连接
              setServiceConnected(false);
              setCurrentChatId(null);
              
              // 清除localStorage中的客服对话信息
              localStorage.removeItem('currentCustomerServiceChat');
              
              // 显示系统消息，根据事件类型使用不同的内容
              const endMessage: Message = {
                id: Date.now(),
                from: t('messages.system'),
                content: msg.type === 'chat_timeout' && msg.content ? msg.content : t('messages.chatEnded'),
                created_at: new Date().toISOString(),
              };
              setMessages(prev => [...prev, endMessage]);
              return;
            }
            
            // 处理接收到的消息
            if (msg.type === 'message_sent') {
              // 这是发送确认消息，不需要显示
              return;
            }
            
            if (msg.from) {
              // 确定消息发送者显示名称
              let fromName = t('messages.other');
              if (msg.from === user.id) {
                fromName = t('messages.me');
              } else if (msg.sender_type === 'system') {
                fromName = t('messages.system');
              } else if (msg.sender_type === 'customer_service') {
                fromName = t('messages.customerService');
              } else if (msg.sender_type === 'admin') {
                fromName = t('messages.admin');
              } else if (msg.from === 'system') {
                fromName = t('messages.system');
              }
              
              // 只处理有内容的消息
              if (msg.content && msg.content.trim()) {
                const messageId = msg.message_id || Date.now();
                
                // 检查是否已经存在相同的消息（避免重复显示）
                setMessages(prev => {
                  // 检查是否已经存在相同内容、相同发送者、时间相近的消息
                  const exists = prev.some(m => 
                    m.content === msg.content.trim() && 
                    m.from === fromName && 
                    Math.abs(new Date(m.created_at).getTime() - new Date(msg.created_at).getTime()) < 5000 // 5秒内的消息认为是重复的
                  );
                  
                  if (exists) {
                    return prev; // 如果已存在，不添加
                  }
                  
                  return [...prev, {
                    id: messageId,
                    from: fromName,
                    content: msg.content.trim(), 
                    created_at: msg.created_at 
                  }];
                });
                
                // 标记为新消息，触发自动滚动（只对非系统消息）
                if (fromName !== '系统') {
                  setIsNewMessage(true);
                }
                
                // 如果是接收到的消息（不是自己发送的），更新联系人排序
                if (msg.from !== user.id && msg.from !== 'system' && msg.from !== 'customer_service' && msg.from !== 'admin') {
                  updateContactOrder(msg.from, msg.created_at);
                  
                  // 播放提示音
                  playMessageSound();
                  
                  // 更新未读消息数量（避免重复更新）
                  setTotalUnreadCount(prev => {
                    const newCount = prev + 1;
                    // 更新页面标题
                    if (newCount > 0) {
                      document.title = t('notifications.pageTitleWithCount').replace('{count}', newCount.toString());
                    } else {
                      document.title = t('notifications.pageTitle');
                    }
                    return newCount;
                  });
                  
                  // 更新该联系人的未读消息数量
                  setContactUnreadCounts(prev => ({
                    ...prev,
                    [msg.from]: (prev[msg.from] || 0) + 1
                  }));
                  
                  // 显示桌面通知
                  if ('Notification' in window && Notification.permission === 'granted') {
                    // 检查页面是否可见，如果不可见才显示通知
                    if (document.hidden) {
                      const notification = new Notification('新消息', {
                        body: `${fromName}: ${msg.content.substring(0, 50)}${msg.content.length > 50 ? '...' : ''}`,
                        icon: '/static/favicon.png',
                        tag: 'message-notification',
                        requireInteraction: false
                      });
                      
                      // 3秒后自动关闭通知
                      setTimeout(() => {
                        notification.close();
                      }, 3000);
                    }
                  }
                }
              }
            }
          } catch (error) {
            // 静默处理解析错误
          }
        };
        
        socket.onerror = (error) => {
          console.error('用户WebSocket连接错误:', error);
        };
        
        socket.onclose = (event) => {
          setWs(null);
          
          // 只在异常关闭时重连（代码1000是正常关闭）
          if (event.code !== 1000 && reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++;
            setTimeout(() => {
              connectWebSocket();
            }, reconnectDelay);
          } else if (event.code === 1000) {
            // 正常关闭，不重连
          } else {
            console.error('用户WebSocket重连失败，已达到最大重连次数');
          }
        };
      };

      // 初始连接
      connectWebSocket();
      
      return () => {
        if (socket) {
          socket.close();
        }
        setWs(null);
      };
    }
  }, [user?.id]);

  // 定期检查客服对话是否已结束
  useEffect(() => {
    if (isServiceMode && currentChatId && currentChat && currentChat.is_ended === 0) {
      const checkChatStatus = async () => {
        try {
          const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${currentChatId}`, {
            credentials: 'include'
          });
          
          if (response.ok) {
            const chatData = await response.json();
            
            // 如果对话已结束，更新状态
            if (chatData.is_ended === 1) {
              setCurrentChat(prev => prev ? { ...prev, is_ended: 1 } : null);
              
              // 断开客服连接
              setServiceConnected(false);
              setCurrentChatId(null);
              
              // 清除localStorage中的客服对话信息
              localStorage.removeItem('currentCustomerServiceChat');
              
              // 显示系统消息
              const endMessage: Message = {
                id: Date.now(),
                from: t('messages.system'),
                content: t('messages.chatEnded'),
                created_at: new Date().toISOString(),
              };
              setMessages(prev => [...prev, endMessage]);
            }
          }
        } catch (error) {
          console.error('检查客服对话状态失败:', error);
        }
      };
      
      // 每10秒检查一次
      const interval = setInterval(checkChatStatus, 10000);
      
      return () => clearInterval(interval);
    }
  }, [isServiceMode, currentChatId, currentChat?.is_ended]);

  const loadChatHistory = useCallback(async (contactId: string, chatId?: string, page: number = 1, isLoadMore: boolean = false) => {
    try {
      // 如果是加载更多，设置加载状态
      if (isLoadMore) {
        setLoadingMoreMessages(true);
      }
      
      // 如果有chatId，加载特定对话的聊天记录（客服聊天）
      if (chatId) {
        const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${chatId}/messages`, {
          credentials: 'include'  // 使用Cookie认证
        });
        
        if (response.ok) {
          const chatData = await response.json();
          const formattedMessages = chatData.map((msg: any) => {
            return {
              id: msg.id,
              from: msg.sender_type === 'user' ? t('messages.me') : (msg.sender_type === 'system' ? t('messages.system') : t('messages.customerService')),
              content: msg.content,
              created_at: msg.created_at,
              is_admin_msg: msg.sender_type === 'system' ? 1 : 0
            };
          });
          
        // 确保消息按时间排序（最新的在最后）
        formattedMessages.sort((a: any, b: any) => {
          const timeA = new Date(a.created_at).getTime();
          const timeB = new Date(b.created_at).getTime();
          return timeA - timeB; // 升序排序，最早的在前
        });
        
        // 对于客服聊天，始终确保最新的消息在最后（不需要反转，因为我们已经按时间升序排序）
        
        setMessages(formattedMessages);
        
        // 首次加载时直接设置到底部，不使用动画
        if (!isLoadMore && formattedMessages.length > 0) {
          setTimeout(() => {
            const messagesContainer = messagesContainerRef.current;
            if (messagesContainer) {
              // 直接设置到底部，不使用smooth滚动
              messagesContainer.scrollTop = messagesContainer.scrollHeight;
            }
          }, 50);
        }
        
        // 注意：用户端不应调用markCustomerServiceMessagesRead，这是客服专用的接口
        // 用户端通过WebSocket接收消息，消息会被自动标记为已读
        
        return;
      }
    }
      
      // 只有在没有chatId且非客服模式下才加载普通用户之间的聊天记录
      if (!chatId && !isServiceMode && !serviceConnected) {
        
        // 如果不是加载更多，显示加载状态
        if (!isLoadMore) {
          setMessages(prev => {
            const loadingMessage = {
              id: -1, // 使用负数ID表示加载状态
              from: t('messages.system'),
              content: t('messages.loadingHistory'),
              created_at: new Date().toISOString()
            };
            
            // 如果已经有消息，在末尾添加加载状态
            if (prev.length > 0) {
              return [...prev, loadingMessage];
            } else {
              // 如果没有消息，只显示加载状态
              return [loadingMessage];
            }
          });
        }
        
        const offset = (page - 1) * 20; // 计算偏移量，初始加载20条
        const limit = page === 1 ? 20 : 50; // 首次加载20条，后续加载50条
        const chatData = await getChatHistory(contactId, limit, undefined, offset); // 支持分页加载
        const formattedMessages = chatData.map((msg: any) => ({
          id: msg.id,
          from: String(msg.sender_id) === String(user.id) ? t('messages.me') : (msg.is_admin_msg === 1 ? t('messages.system') : t('messages.other')),
          content: msg.content, 
          created_at: msg.created_at 
        }));
        
        // 确保消息按时间排序（最新的在最后）
        formattedMessages.sort((a: any, b: any) => {
          const timeA = new Date(a.created_at).getTime();
          const timeB = new Date(b.created_at).getTime();
          return timeA - timeB; // 升序排序，最早的在前
        });
        
        // 对于普通聊天，始终确保最新的消息在最后（不需要反转，因为我们已经按时间升序排序）
        
        // 处理消息列表
        setMessages(prev => {
          // 移除加载状态消息
          const filteredPrev = prev.filter(msg => msg.id !== -1);
          
          if (isLoadMore) {
            // 加载更多：将新消息添加到现有消息前面
            const allMessages = [...formattedMessages, ...filteredPrev];
            
            // 去重：优先使用服务器ID，然后基于内容和时间
            const uniqueMessages = allMessages.filter((msg, index, self) => {
              // 如果有服务器ID，优先使用ID去重
              if (msg.id && msg.id > 0) {
                return index === self.findIndex(m => m.id === msg.id);
              }
              // 否则基于内容和时间去重
              return index === self.findIndex(m => 
                m.content === msg.content && 
                m.from === msg.from && 
                Math.abs(new Date(m.created_at).getTime() - new Date(msg.created_at).getTime()) < 1000 // 1秒内认为是重复的
              );
            });
            
            // 按时间排序
            uniqueMessages.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
            
            // 保持滚动位置：计算新增消息的高度
            setTimeout(() => {
              const messagesContainer = messagesContainerRef.current;
              if (messagesContainer) {
                const newMessageCount = uniqueMessages.length - filteredPrev.length;
                if (newMessageCount > 0) {
                  // 记录当前滚动位置
                  const currentScrollTop = messagesContainer.scrollTop;
                  const currentScrollHeight = messagesContainer.scrollHeight;
                  
                  // 估算每条消息的平均高度（可以根据实际情况调整）
                  const estimatedMessageHeight = 60; // 像素
                  const scrollAdjustment = newMessageCount * estimatedMessageHeight;
                  
                  // 调整滚动位置，保持用户当前查看的内容不变
                  messagesContainer.scrollTop = currentScrollTop + scrollAdjustment;
                }
              }
            }, 50);
            
            return uniqueMessages;
          } else {
            // 初始加载：直接替换消息列表，避免旧联系人的消息显示在新联系人上
            // 直接返回新加载的消息，不合并现有消息
            return formattedMessages;
          }
        });
        
        // 首次加载时直接设置到底部，不使用动画
        if (!isLoadMore && formattedMessages.length > 0) {
          setTimeout(() => {
            const messagesContainer = messagesContainerRef.current;
            if (messagesContainer) {
              // 直接设置到底部，不使用smooth滚动
              messagesContainer.scrollTop = messagesContainer.scrollHeight;
            }
          }, 50);
        }
        
        // 检查是否还有更多消息
        if (formattedMessages.length < limit) {
          setHasMoreMessages(false);
        } else {
          setHasMoreMessages(true);
        }
        
        // 标记普通聊天的未读消息为已读
        try {
          const result = await markChatMessagesAsRead(contactId);
          
          // 立即更新未读消息数量（减少已标记的数量）
          if (result && result.marked_count) {
            setTotalUnreadCount(prev => {
              const newCount = Math.max(0, prev - result.marked_count);
              // 更新页面标题
              if (newCount > 0) {
                document.title = t('notifications.pageTitleWithCount').replace('{count}', newCount.toString());
              } else {
                document.title = t('notifications.pageTitle');
              }
              return newCount;
            });
            
            // 更新该联系人的未读消息数量为0（从状态中删除该联系人）
            setContactUnreadCounts(prev => {
              const newCounts = { ...prev };
              delete newCounts[contactId];
              return newCounts;
            });
          } else {
            // 如果无法获取具体数量，重新加载
            await loadUnreadCount();
            await loadContactUnreadCounts();
          }
        } catch (error) {
          console.error('标记普通聊天消息为已读失败:', error);
        }
      }
    } catch (error) {
      console.error('加载聊天历史失败:', error);
      // API调用失败时不清空现有消息，只显示错误提示
      const errorMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.loadHistoryFailed'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      // 完成加载更多
      if (isLoadMore) {
        setLoadingMoreMessages(false);
      }
    }
  }, [isServiceMode, serviceConnected, user]);

  // 滚动到底部
  const scrollToBottom = useCallback(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
      setShowScrollToBottomButton(false);
    }
  }, []);

  // 加载更多历史消息
  const loadMoreMessages = useCallback(async () => {
    if (!activeContact || loadingMoreMessages || !hasMoreMessages) {
      return;
    }
    
    setCurrentPage(prev => prev + 1);
    await loadChatHistory(activeContact.id, undefined, currentPage + 1, true);
  }, [activeContact, loadingMoreMessages, hasMoreMessages, currentPage, loadChatHistory]);

  // 滚动监听器 - 检测是否滚动到顶部
  useEffect(() => {
    const messagesContainer = messagesContainerRef.current;
    if (!messagesContainer || !activeContact) {
      return;
    }

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
      
      // 当滚动到顶部附近时（距离顶部50px内），加载更多消息
      if (scrollTop <= 50 && hasMoreMessages && !loadingMoreMessages) {
        loadMoreMessages();
      }
      
      // 控制"滚动到底部"按钮的显示
      // 当用户向上滚动超过200px时显示按钮，接近底部时隐藏
      const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
      setShowScrollToBottomButton(distanceFromBottom > 200);
    };

    messagesContainer.addEventListener('scroll', handleScroll);
    return () => {
      messagesContainer.removeEventListener('scroll', handleScroll);
    };
  }, [activeContact, hasMoreMessages, loadingMoreMessages, loadMoreMessages]);

  // 重置分页状态当切换联系人时
  useEffect(() => {
    if (activeContact) {
      setCurrentPage(1);
      setHasMoreMessages(true);
      setLoadingMoreMessages(false);
    }
  }, [activeContact]);

  // 联系在线客服
  const handleContactCustomerService = async () => {
    // 首先检查客服是否在线
    if (!serviceAvailable) {
      const noServiceMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.noServiceAvailable'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, noServiceMessage]);
      return;
    }

    // 先检查localStorage中是否已有活跃的客服对话
    const savedChat = localStorage.getItem('currentCustomerServiceChat');
    
    if (savedChat) {
      try {
        const chatData = JSON.parse(savedChat);
        
        // 检查对话是否已结束
        if (chatData.chat.is_ended === 0) {
          // 对话未结束，验证对话是否仍然有效
          try {
            const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${chatData.chat.chat_id}/messages`, {
              credentials: 'include'  // 使用Cookie认证
            });
            
            if (response.ok) {
              // 对话仍然有效，恢复现有对话
              setIsConnectingToService(true);
              setIsServiceMode(true);
              setActiveContact(null);
              setServiceConnected(true);
              setCurrentChatId(chatData.chat.chat_id);
              setCurrentChat(chatData.chat);
              // setService(chatData.service); // 已移除service状态
              
              // 加载该对话的聊天历史记录
              await loadChatHistory(chatData.service.id, chatData.chat.chat_id);
              setIsConnectingToService(false);
              return; // 直接返回，不创建新对话
            } else {
              // 对话无效，清除localStorage并重置状态
              localStorage.removeItem('currentCustomerServiceChat');
              setServiceConnected(false);
              setCurrentChatId(null);
              setCurrentChat(null);
              // setService(null); // 已移除service状态
            }
          } catch (error) {
            console.error('验证对话有效性失败:', error);
            // 验证失败，清除localStorage并重置状态
            localStorage.removeItem('currentCustomerServiceChat');
            setServiceConnected(false);
            setCurrentChatId(null);
            setCurrentChat(null);
            // setService(null); // 已移除service状态
          }
        } else {
          // 对话已结束，清除localStorage并重置状态
          localStorage.removeItem('currentCustomerServiceChat');
          setServiceConnected(false);
          setCurrentChatId(null);
          setCurrentChat(null);
          // setService(null); // 已移除service状态
        }
      } catch (error) {
        console.error('解析保存的对话失败:', error);
        localStorage.removeItem('currentCustomerServiceChat');
        setServiceConnected(false);
        setCurrentChatId(null);
        setCurrentChat(null);
        // setService(null); // 已移除service状态
      }
    }
    
    // 如果没有未结束的对话，尝试连接客服
    setIsConnectingToService(true);
    
    try {
      // 检查客服在线状态
      const isServiceAvailable = await checkCustomerServiceAvailabilityLocal();
      
      if (isServiceAvailable) {
        // 客服在线，尝试分配客服
        const response = await assignCustomerService();
        
        if (response.error) {
          console.error('客服连接失败:', response.error);
          const errorMessage: Message = {
            id: Date.now(),
            from: t('messages.system'),
            content: t('messages.connectServiceFailed', { error: response.error }),
            created_at: new Date().toISOString()
          };
          setMessages(prev => [...prev, errorMessage]);
          return;
        }
        
        // 连接成功
        setServiceConnected(true);
        setCurrentChatId(response.chat.chat_id);
        setCurrentChat(response.chat);
        // setService(response.service); // 已移除service状态
        
        // 保存对话信息到localStorage（不包含敏感信息）
        const chatToSave = {
          chat: response.chat,
          service: {
            id: response.service.id,
            name: response.service.name,
            is_online: response.service.is_online
          },
          chatId: response.chat.chat_id
        };
        localStorage.setItem('currentCustomerServiceChat', JSON.stringify(chatToSave));
        
        // 加载该对话的聊天历史记录
        await loadChatHistory(response.service.id, response.chat.chat_id);
        
        const successMessage: Message = {
          id: Date.now(),
          from: t('messages.system'),
          content: t('messages.connectedToService', { name: response.service.name }),
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, successMessage]);
      } else {
        // 客服不在线，显示系统提示
        const noServiceMessage: Message = {
          id: Date.now(),
          from: t('messages.system'),
          content: '当前无可用客服，请您稍后尝试',
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, noServiceMessage]);
      }
    } catch (error) {
      console.error('连接客服失败:', error);
      const errorMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.connectServiceError'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsConnectingToService(false);
    }
  };

  // 检查客服可用性（真实API调用）
  const checkCustomerServiceAvailabilityLocal = async (): Promise<boolean> => {
    try {
      const response = await checkCustomerServiceAvailability();
      return response.available;
      } catch (error) {
      console.error('检查客服可用性失败:', error);
      // 如果API调用失败，返回false（无客服在线）
      return false;
    }
  };

  // 检查并更新客服在线状态
  const checkServiceAvailability = useCallback(async () => {
    setServiceStatusLoading(true);
    try {
      const isAvailable = await checkCustomerServiceAvailabilityLocal();
      setServiceAvailable(isAvailable);
    } catch (error) {
      console.error('检查客服状态失败:', error);
      setServiceAvailable(false);
    } finally {
      setServiceStatusLoading(false);
    }
  }, []);

  // 结束客服对话
  const handleEndConversation = async () => {
    if (!currentChatId) {
      console.error('没有活跃的客服对话');
      const errorMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.noActiveChat'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
      return;
    }
    
    try {
      const response = await api.post(`/api/users/customer-service/end-chat/${currentChatId}`);
      
      // 显示系统消息
      const endMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.chatEndedThankYou'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, endMessage]);
      
      // 保存chat_id用于评价
      setRatingChatId(currentChatId);
      
      // 重置状态
      setServiceConnected(false);
      setCurrentChatId(null);
      setCurrentChat(null);
      
      // 清除localStorage中的对话信息
      localStorage.removeItem('currentCustomerServiceChat');
      
      // 显示评价弹窗
      setShowRatingModal(true);
      
    } catch (error: any) {
      console.error('结束对话失败:', error);
      
      // 如果返回400或404，说明对话不存在或已结束，清理localStorage
      if (error.response?.status === 400 || error.response?.status === 404) {
        // 保存chat_id用于评价（如果存在）
        if (currentChatId) {
          setRatingChatId(currentChatId);
          setShowRatingModal(true);
        }
        localStorage.removeItem('currentCustomerServiceChat');
        setServiceConnected(false);
        setCurrentChatId(null);
        setCurrentChat(null);
        
        const cleanupMessage: Message = {
          id: Date.now(),
          from: t('messages.system'),
          content: t('messages.chatEndedReset'),
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, cleanupMessage]);
        return;
      }
      
      const errorMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.endChatFailed'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
    }
  };

  // 提交评价
  const handleSubmitRating = async () => {
    if (!ratingChatId) {
      console.error('没有对话ID');
      return;
    }
    
    try {
      // 使用 api.post 自动包含 CSRF token
      await api.post(`/api/users/customer-service/rate/${ratingChatId}`, {
        rating: rating,
        comment: ratingComment
      });
      
      // 关闭评价弹窗
      setShowRatingModal(false);
      setRating(5);
      setRatingComment('');
      setRatingChatId(null);
      
      // 显示感谢消息
      const thankMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.thankYouForRating'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, thankMessage]);
      
    } catch (error) {
      console.error('提交评价失败:', error);
      alert(t('messages.submitRatingFailed'));
    }
  };

  if (loading) {
    return (
      <div style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <div style={{
          background: '#fff',
          padding: '40px',
          borderRadius: '20px',
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{
            fontSize: '48px',
            marginBottom: '20px',
            animation: 'spin 1s linear infinite'
          }}>⏳</div>
          <div style={{
            fontSize: '18px',
            color: '#3b82f6',
            fontWeight: '600'
          }}>{t('messages.loadingMessageCenter')}</div>
        </div>
      </div>
    );
  }

  if (!user) {
  return (
      <div style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <div style={{
          background: '#fff',
          padding: '40px',
          borderRadius: '20px',
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{
            fontSize: '48px',
            marginBottom: '20px'
          }}>🔒</div>
          <div style={{
            fontSize: '18px',
            color: '#ef4444',
            fontWeight: '600',
            marginBottom: '20px'
          }}>请先登录</div>
          <button
            onClick={() => setShowLoginModal(true)}
            style={{
              padding: '12px 24px',
              background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
              color: '#fff',
              border: 'none',
              borderRadius: '12px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: 'pointer',
              transition: 'all 0.3s ease'
            }}
          >
            前往登录
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={{ 
      height: '100vh', 
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
      padding: '0',
      overflow: 'hidden',
      boxSizing: 'border-box'
    }}>
      {/* SEO优化：H1标签，几乎不可见但SEO可检测 */}
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
        {t('messages.messageCenter')}
      </h1>
      <div style={{ 
        width: '100%',
        height: '100vh',
        background: '#fff',
        overflow: 'hidden',
        display: 'flex',
        boxSizing: 'border-box'
      }}>
        
        {/* 左侧联系人列表 */}
        <div style={{ 
          width: isMobile ? (showContactsList ? '100%' : '0') : '350px', 
          borderRight: isMobile ? 'none' : '1px solid #e2e8f0', 
          background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
          display: 'flex',
          flexDirection: 'column',
          position: isMobile ? 'absolute' : 'relative',
          zIndex: isMobile ? 1000 : 'auto',
          transition: isMobile ? 'transform 0.3s ease-in-out' : 'all 0.3s ease',
          overflow: isMobile ? 'hidden' : 'visible',
          transform: isMobile ? (showContactsList ? 'translateX(0)' : 'translateX(-100%)') : 'none',
          left: isMobile ? '0' : 'auto',
          top: isMobile ? '0' : 'auto',
          height: isMobile ? '100vh' : 'auto'
        }}>
          {/* 头部标题 */}
          <div style={{ 
            padding: isMobile ? '20px 16px' : '30px 24px', 
            textAlign: 'center', 
            fontWeight: '800', 
            fontSize: isMobile ? '20px' : '24px',
            background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
            color: '#fff',
            position: 'relative'
          }}>
            <div style={{ 
              position: 'absolute', 
              left: isMobile ? '16px' : '20px', 
              top: '50%', 
              transform: 'translateY(-50%)',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: isMobile ? '6px 12px' : '8px 16px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: isMobile ? '12px' : '14px',
              fontWeight: '600',
              backdropFilter: 'blur(10px)',
              transition: 'all 0.3s ease'
            }}
            onClick={() => {
              navigate('/');
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.3)';
              e.currentTarget.style.transform = 'translateY(-50%) scale(1.05)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
              e.currentTarget.style.transform = 'translateY(-50%) scale(1)';
            }}
          >
            {isMobile ? t('messages.backToHome') : t('messages.back')}
        </div>
            💬 {t('messages.messageCenter')}
            {totalUnreadCount > 0 && (
              <span style={{
                background: '#ef4444',
                color: '#fff',
                borderRadius: '12px',
                padding: '2px 8px',
                fontSize: '12px',
                fontWeight: '600',
                marginLeft: '8px',
                animation: 'pulse 2s infinite'
              }}>
                {totalUnreadCount}
              </span>
            )}
          </div>

          {/* 搜索框 */}
          <div style={{ 
            padding: isMobile ? '16px' : '20px 24px',
            borderBottom: '1px solid #e2e8f0'
          }}>
            <div style={{ 
              position: 'relative',
              background: '#fff',
              borderRadius: '25px',
              border: '2px solid #e2e8f0',
              overflow: 'hidden',
              transition: 'all 0.3s ease'
            }}>
              <input
                type="text"
                placeholder={t('messages.searchContacts')}
                style={{
                  width: '100%',
                  padding: '12px 20px 12px 45px',
                  border: 'none',
                  outline: 'none',
                  fontSize: '14px',
                  background: 'transparent'
                }}
              />
              <div style={{
                position: 'absolute',
                left: '15px',
                top: '50%',
                transform: 'translateY(-50%)',
                fontSize: '16px',
                color: '#94a3b8'
              }}>
                🔍
              </div>
            </div>
          </div>

          {/* 联系人列表 */}
          <div style={{ flex: 1, overflowY: 'auto' }}>
            {/* 加载骨架屏 */}
            {contactsLoading && contacts.length === 0 && (
              <div style={{ padding: '20px' }}>
                {[...Array(5)].map((_, index) => (
                  <div key={index} style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '16px',
                    padding: '20px 24px',
                    marginBottom: '8px',
                    background: 'rgba(255,255,255,0.5)',
                    borderRadius: '12px',
                    animation: 'pulse 1.5s ease-in-out infinite'
                  }}>
                    <div style={{
                      width: '50px',
                      height: '50px',
                      borderRadius: '50%',
                      background: '#e2e8f0'
                    }}></div>
                    <div style={{ flex: 1 }}>
                      <div style={{
                        height: '16px',
                        background: '#e2e8f0',
                        borderRadius: '4px',
                        marginBottom: '8px',
                        width: '60%'
                      }}></div>
                      <div style={{
                        height: '12px',
                        background: '#e2e8f0',
                        borderRadius: '4px',
                        width: '40%'
                      }}></div>
                    </div>
                  </div>
                ))}
              </div>
            )}
            {/* 客服中心 - 固定在顶部 */}
            <div
              onClick={async () => {
                // 先检查localStorage中是否已有活跃的客服对话
                const savedChat = localStorage.getItem('currentCustomerServiceChat');
                
                if (savedChat) {
                  try {
                    const chatData = JSON.parse(savedChat);
                    
                    // 检查对话是否已结束
                    if (chatData.chat.is_ended === 0) {
                      // 对话未结束，恢复现有对话
                      setIsConnectingToService(true);
                      setIsServiceMode(true);
                      setActiveContact(null);
                      setServiceConnected(true);
                      setCurrentChatId(chatData.chat.chat_id);
                      setCurrentChat(chatData.chat);
                      // setService(chatData.service); // 已移除service状态
                      
                      // 加载该对话的聊天历史记录
                      await loadChatHistory(chatData.service.id, chatData.chat.chat_id);
                      setIsConnectingToService(false);
                      
                      // 移动端自动关闭联系人列表
                      if (isMobile) {
                        setShowContactsList(false);
                      }
                      return; // 直接返回，不创建新对话
                    } else {
                      // 对话已结束，清除localStorage并重置状态
                      localStorage.removeItem('currentCustomerServiceChat');
                      setServiceConnected(false);
                      setCurrentChatId(null);
                      setCurrentChat(null);
                      // setService(null); // 已移除service状态
                    }
                  } catch (error) {
                    console.error('解析保存的对话失败:', error);
                    localStorage.removeItem('currentCustomerServiceChat');
                    setServiceConnected(false);
                    setCurrentChatId(null);
                    setCurrentChat(null);
                    // setService(null); // 已移除service状态
                  }
                }
                
                // 如果没有未结束的对话，只显示客服聊天框
                setIsServiceMode(true);
                setActiveContact(null);
                setMessages([]);
                setShowSystemWarning(true);
                
                // 移动端自动关闭联系人列表
                if (isMobile) {
                  setShowContactsList(false);
                }
              }}
              style={{ 
                display: 'flex', 
                alignItems: 'center', 
                gap: '16px', 
                padding: '20px 24px', 
                cursor: 'pointer', 
                background: isServiceMode ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' : 'linear-gradient(135deg, #fef3c7, #fde68a)', 
                color: isServiceMode ? '#fff' : '#92400e',
                fontWeight: isServiceMode ? 700 : 600,
                transition: 'all 0.3s ease',
                borderBottom: '3px solid #f59e0b',
                position: 'relative',
                boxShadow: isServiceMode ? '0 4px 12px rgba(59, 130, 246, 0.3)' : '0 2px 8px rgba(245, 158, 11, 0.2)'
              }}
            >
              <div style={{ 
                position: 'relative',
                width: '50px',
                height: '50px'
              }}>
                <img src={'/static/service.png'} alt={t('messages.service')} style={{ 
                  width: '50px', 
                  height: '50px', 
                  borderRadius: '50%', 
                  border: '3px solid #f59e0b', 
                  background: '#fffbe6', 
                  objectFit: 'cover',
                  boxShadow: '0 4px 12px rgba(245, 158, 11, 0.3)',
                  transition: 'none' // 禁用过渡效果，防止形变
                }} 
                onLoad={(e) => {
                }}
                onError={(e) => {
                  console.error('客服头像加载失败:', e.currentTarget.src);
                  e.currentTarget.src = '/static/avatar1.png'; // 备用头像
                }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '16px', fontWeight: '700', marginBottom: '4px' }}>
                  🎧 {t('messages.customerServiceCenter')}
                </div>
                <div style={{ 
                  fontSize: '12px', 
                  opacity: 0.8,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}>
                  <span>{t('messages.onlineService')}</span>
                  <div style={{
                    width: '6px',
                    height: '6px',
                    background: '#10b981',
                    borderRadius: '50%'
                  }}></div>
                </div>
              </div>
            </div>

            {/* 分割线 */}
            <div style={{
              height: '2px',
              background: 'linear-gradient(90deg, #f59e0b, #fbbf24, #f59e0b)',
              margin: '0 24px',
              borderRadius: '1px',
              boxShadow: '0 1px 3px rgba(245, 158, 11, 0.3)'
            }}></div>

            {/* 分割线标题 */}
            <div style={{
              padding: '12px 24px 8px 24px',
              fontSize: '12px',
              fontWeight: '600',
              color: '#6b7280',
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
              background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
              borderBottom: '1px solid #e2e8f0'
            }}>
              💬 联系人
            </div>

            {/* 联系人列表 */}
            {contactsLoading ? (
              <div style={{ 
                color: '#64748b', 
                textAlign: 'center', 
                padding: '60px 24px',
                fontSize: '16px'
              }}>
                <div style={{ 
                  fontSize: '48px', 
                  marginBottom: '16px',
                  opacity: 0.5,
                  animation: 'pulse 1.5s ease-in-out infinite'
                }}>⏳</div>
                <div style={{ fontWeight: '600', marginBottom: '8px' }}>正在加载联系人...</div>
                <div style={{ fontSize: '14px', opacity: 0.7 }}>
                  请稍候
                </div>
              </div>
            ) : contacts.length === 0 ? (
              <div style={{ 
                color: '#64748b', 
                textAlign: 'center', 
                padding: '60px 24px',
                fontSize: '16px'
              }}>
                <div style={{ 
                  fontSize: '48px', 
                  marginBottom: '16px',
                  opacity: 0.5
                }}>👥</div>
                <div style={{ fontWeight: '600', marginBottom: '8px' }}>暂无联系人</div>
                <div style={{ fontSize: '14px', opacity: 0.7 }}>
                  开始与其他人聊天吧
                </div>
              </div>
            ) : (
              contacts.map(c => {
                // 格式化最新消息时间
                const formatLastMessageTime = (timeString: string | null) => {
                  if (!timeString) return t('messages.noMessage') || '暂无消息';
                  return TimeHandlerV2.formatLastMessageTime(timeString, userTimezone, t);
                };

                return (
                  <div
                    key={c.id}
                    onClick={() => { 
                      // 如果点击的是同一个联系人，不执行任何操作
                      if (activeContact?.id === c.id && !isServiceMode) {
                        return;
                      }
                      
                      setActiveContact(c); 
                      setIsServiceMode(false); 
                      // 不清空消息列表，让loadChatHistory处理消息加载
                      
                      // 移动端点击联系人后自动关闭联系人列表
                      if (isMobile) {
                        setShowContactsList(false);
                      }
                    }}
                    style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '16px', 
                      padding: '20px 24px', 
                      cursor: 'pointer', 
                      background: activeContact?.id === c.id && !isServiceMode ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' : 'transparent', 
                      color: activeContact?.id === c.id && !isServiceMode ? '#fff' : '#475569',
                      fontWeight: activeContact?.id === c.id && !isServiceMode ? 700 : 600, 
                      position: 'relative',
                      transition: 'all 0.3s ease',
                      borderBottom: '1px solid #e2e8f0'
                    }}
                    onMouseEnter={(e) => {
                      if (activeContact?.id !== c.id || isServiceMode) {
                        e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (activeContact?.id !== c.id || isServiceMode) {
                        e.currentTarget.style.background = 'transparent';
                      }
                    }}
                  >
                    <div style={{ 
                      position: 'relative',
                      width: '50px',
                      height: '50px'
                    }}>
                      <img 
                        src={c.avatar || '/static/avatar1.png'} 
                        alt={t('messages.avatar')} 
                        style={{ 
                          width: '50px', 
                          height: '50px', 
                          borderRadius: '50%', 
                          border: '3px solid #3b82f6', 
                          background: '#f8fbff', 
                          objectFit: 'cover',
                          cursor: 'pointer',
                          boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
                        }}
                        onClick={(e) => {
                          e.stopPropagation();
                          navigate(`/user/${c.id}`);
                        }}
                      />
                      {/* 未读消息红点 */}
                      {contactUnreadCounts[c.id] && contactUnreadCounts[c.id] > 0 && (
                        <div style={{
                          position: 'absolute',
                          top: '-2px',
                          right: '-2px',
                          background: 'linear-gradient(135deg, #ef4444, #dc2626)',
                          borderRadius: '50%',
                          minWidth: '20px',
                          height: '20px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '11px',
                          color: '#fff',
                          fontWeight: 'bold',
                          boxShadow: '0 2px 8px rgba(239, 68, 68, 0.4)',
                          animation: 'pulse 2s infinite',
                          border: '2px solid #fff',
                          zIndex: 10
                        }}>
                          {contactUnreadCounts[c.id] > 99 ? '99+' : contactUnreadCounts[c.id]}
                        </div>
                      )}
                    </div>
                    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
                      <div style={{ 
                        fontSize: '16px', 
                        fontWeight: '700', 
                        marginBottom: '4px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px'
                      }}>
                        {c.name || `${t('messages.user')}${c.id}`}
                      </div>
                      <div style={{ 
                        fontSize: '12px', 
                        opacity: 0.7,
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}>
                        <span>{formatLastMessageTime(c.last_message_time || null)}</span>
                        <div style={{
                          width: '6px',
                          height: '6px',
                          background: '#10b981',
                          borderRadius: '50%'
                        }}></div>
                      </div>
                    </div>
                    {contactUnreadCounts[c.id] && contactUnreadCounts[c.id] > 0 && (
                      <div style={{ 
                        background: 'linear-gradient(135deg, #ef4444, #dc2626)',
                        borderRadius: '50%',
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '11px',
                        color: '#fff',
                        fontWeight: 'bold',
                        boxShadow: '0 2px 8px rgba(239, 68, 68, 0.4)',
                        animation: 'pulse 2s infinite'
                      }}>
                        {contactUnreadCounts[c.id] > 99 ? '99+' : contactUnreadCounts[c.id]}
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
      </div>
        
        {/* 右侧聊天区域 */}
        <div style={{ 
          flex: 1, 
          display: 'flex', 
          flexDirection: 'column',
          background: isMobile ? '#fff' : 'transparent',
          width: isMobile ? '100%' : 'auto',
          position: isMobile ? 'relative' : 'static',
          height: isMobile ? '100vh' : 'auto',
          overflow: 'hidden'
        }}>
          {/* 聊天头部 */}
        <div style={{ 
            padding: isMobile ? '16px' : '24px 30px', 
            borderBottom: '1px solid #e2e8f0', 
            background: isMobile ? 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)' : 'transparent',
          display: 'flex',
          alignItems: 'center',
            gap: '16px',
            minHeight: isMobile ? '60px' : '80px',
            flexShrink: 0,
            position: isMobile ? 'sticky' : 'static',
            top: isMobile ? '0' : 'auto',
            zIndex: isMobile ? 20 : 'auto'
          }}>
            {/* 移动端菜单按钮 */}
            {isMobile && (
              <button
                onClick={() => setShowContactsList(true)}
                style={{
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  border: 'none',
                  color: '#fff',
                  padding: '8px 12px',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: '600',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}
              >
                ☰ 联系人
              </button>
            )}
            {isServiceMode ? (
              <>
                <div style={{ 
                  position: 'relative',
                  width: '60px',
                  height: '60px'
                }}>
                  <img 
                    src="/static/service.png" 
                    alt="客服头像" 
                    style={{ 
                      width: '60px', 
                      height: '60px', 
                      borderRadius: '50%', 
                      border: '3px solid #f59e0b', 
                      cursor: 'pointer',
                      objectFit: 'cover',
                      boxShadow: '0 4px 12px rgba(245, 158, 11, 0.3)',
                      transition: 'none' // 禁用过渡效果，防止形变
                    }}
                    onError={(e) => {
                      console.error('客服头像加载失败:', e.currentTarget.src);
                      e.currentTarget.src = '/static/avatar1.png'; // 备用头像
                    }}
                  />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ 
                    fontSize: '20px', 
                    fontWeight: '700', 
                    color: '#1e293b',
                    marginBottom: '6px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    {t('messages.customerServiceCenter')}
                  </div>
                  <div style={{ 
                    fontSize: '14px', 
                    color: '#64748b',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    <div style={{
                      width: '8px',
                      height: '8px',
                      background: '#10b981',
                      borderRadius: '50%'
                    }}></div>
                    <span>{t('messages.serviceTime')}</span>
                  </div>
                </div>
              </>
            ) : activeContact ? (
              <>
                <div style={{ 
                  position: 'relative',
                  width: '60px',
                  height: '60px'
                }}>
            <img 
              src={activeContact.avatar || '/static/avatar1.png'} 
              alt="头像" 
              style={{ 
                      width: '60px', 
                      height: '60px', 
                borderRadius: '50%', 
                      border: '3px solid #3b82f6', 
                cursor: 'pointer',
                      objectFit: 'cover',
                      boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
              }}
              onClick={() => navigate(`/user/${activeContact.id}`)}
            />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ 
                    fontSize: '20px', 
                    fontWeight: '700', 
                    color: '#1e293b',
                    marginBottom: '6px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    {activeContact.name || `${t('messages.user')}${activeContact.id}`}
        </div>
                  <div style={{ 
                    fontSize: '14px', 
                    color: '#64748b',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    <div style={{
                      width: '8px',
                      height: '8px',
                      background: '#10b981',
                      borderRadius: '50%'
                    }}></div>
                    <span>{t('messages.online')}</span>
                  </div>
                </div>
              </>
            ) : (
              <div style={{ 
                flex: 1, 
                textAlign: 'center',
                color: '#64748b'
              }}>
                <div style={{ 
                  fontSize: '18px', 
                  fontWeight: '600',
                  marginBottom: '4px'
                }}>
                  {t('messages.messageCenter')}
                </div>
                <div style={{ 
                  fontSize: '14px',
                  opacity: 0.7
                }}>
                  {t('messages.selectContact')}
                </div>
              </div>
            )}
          </div>


          {/* 用户聊天模式下的系统提示 */}
          {activeContact && !isServiceMode && showSystemWarning && (
            <div style={{
              background: 'rgba(254, 243, 199, 0.95)',
              border: '2px solid #f59e0b',
              borderRadius: '12px',
              padding: '16px 20px',
              margin: '0',
              boxShadow: '0 8px 32px rgba(245, 158, 11, 0.3), 0 0 0 1px rgba(255, 255, 255, 0.1)',
              position: 'fixed',
              top: isMobile ? '80px' : '120px',
              left: isMobile ? '16px' : 'calc(50% + 175px)',
              right: isMobile ? '16px' : 'auto',
              transform: isMobile ? 'none' : 'translateX(-50%)',
              width: isMobile ? 'auto' : '90%',
              maxWidth: isMobile ? 'none' : '600px',
              zIndex: 1000,
              backdropFilter: 'blur(10px)',
              WebkitBackdropFilter: 'blur(10px)'
            }}>
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '12px'
              }}>
                <div style={{
                  fontSize: '20px',
                  color: '#92400e'
                }}>
                  ⚠️
                </div>
                <div style={{
                  flex: 1,
                  color: '#92400e',
                  fontSize: '14px',
                  fontWeight: '600',
                  lineHeight: '1.4'
                }}>
                  {t('messages.tradeWarning')}
                </div>
                <button
                  onClick={() => {
                    setShowSystemWarning(false);
                  }}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#92400e',
                    fontSize: '16px',
                    cursor: 'pointer',
                    padding: '4px',
                    borderRadius: '4px',
                    transition: 'all 0.3s ease'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = 'rgba(146, 64, 14, 0.1)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'none';
                  }}
                >
                  ✕
                </button>
              </div>
            </div>
          )}

          {/* 消息显示区域 */}
          <div 
            ref={messagesContainerRef}
            style={{ 
              flex: 1, 
              overflowY: 'auto', 
              padding: isMobile ? '16px' : '30px', 
              background: 'linear-gradient(135deg, #f8fbff 0%, #f1f5f9 100%)',
              display: 'flex', 
              flexDirection: 'column',
              minHeight: 0, // 允许flex收缩
              position: 'relative',
              paddingTop: isMobile ? '20px' : '20px',
              marginTop: isMobile ? '0' : '0',
              // 移动端确保不超出视口
              ...(isMobile && {
                maxHeight: 'calc(100vh - 140px)', // 为头部和输入区域预留空间
                WebkitOverflowScrolling: 'touch' // iOS平滑滚动
              })
            }}>
          {isServiceMode ? (
              <div style={{ 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center', 
                height: '100%',
                color: '#64748b',
                fontSize: '18px',
                flexDirection: 'column',
                gap: '20px',
                padding: '40px'
              }}>
                <div style={{ 
                  fontSize: '80px', 
                  opacity: 0.3,
                  marginBottom: '10px'
                }}>🎧</div>
                <div style={{
                  fontSize: '20px',
                  fontWeight: '600',
                  color: '#374151',
                  marginBottom: '8px'
                }}>
                  {t('messages.customerServiceCenter')}
                  </div>
                <div style={{
                  fontSize: '16px',
                  color: '#6b7280',
                  textAlign: 'center',
                  lineHeight: '1.5',
                  maxWidth: '300px',
                  marginBottom: '20px'
                }}>
                  {t('messages.ourTeamReadyToHelp')}<br/>
                  {t('messages.serviceTimeDaily')}
                  </div>
                <div style={{
                  background: '#fef3c7',
                  border: '1px solid #f59e0b',
                  borderRadius: '12px',
                  padding: '16px',
                  maxWidth: '400px',
                  textAlign: 'center'
                }}>
                  <div style={{
                    fontSize: '14px',
                    color: '#92400e',
                    fontWeight: '600',
                    marginBottom: '8px'
                  }}>
                    📋 {t('messages.serviceDescription')}
                  </div>
                  <div style={{
                    fontSize: '13px',
                    color: '#b45309',
                    lineHeight: '1.4'
                  }}>
                    • {t('messages.workingHours')}<br/>
                    • {t('messages.responseTime')}<br/>
                    • {t('messages.supportedLanguages')}<br/>
                    • {t('messages.emergencyContact')}
                  </div>
                </div>
              </div>
            ) : !activeContact ? (
              isServiceMode ? (
                // 客服模式下的连接界面
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center', 
                  height: '100%',
                  color: '#64748b',
                  fontSize: '18px',
                  flexDirection: 'column',
                  gap: '20px',
                  padding: '40px'
                }}>
                  <div style={{ 
                    fontSize: '80px', 
                    opacity: 0.3,
                    marginBottom: '10px'
                  }}>🎧</div>
                  <div style={{
                    fontSize: '20px',
                    fontWeight: '600',
                    color: '#374151',
                    marginBottom: '8px'
                  }}>
                    {t('messages.contactCustomerService')}
                  </div>
                  <div style={{
                    fontSize: '16px',
                    color: '#6b7280',
                    textAlign: 'center',
                    lineHeight: '1.5',
                    maxWidth: '400px',
                    marginBottom: '20px'
                  }}>
                    {t('messages.ourTeamReadyToHelpWithButton')}
                  </div>
                  <button
                  onClick={async () => {
                    setIsConnectingToService(true);
                    try {
                      // 检查客服在线状态
                      const isServiceAvailable = await checkCustomerServiceAvailabilityLocal();
                        
                        if (isServiceAvailable) {
                          // 客服在线，尝试分配客服
                          const response = await assignCustomerService();
                          
                          if (response.error) {
                            console.error('客服连接失败:', response.error);
                            const errorMessage: Message = {
                              id: Date.now(),
                              from: t('messages.system'),
                              content: t('messages.connectServiceFailed', { error: response.error }),
                              created_at: new Date().toISOString()
                            };
                            setMessages(prev => [...prev, errorMessage]);
                            return;
                          }
                          
                          // 连接成功
                          setServiceConnected(true);
                          setCurrentChatId(response.chat.chat_id);
                          setCurrentChat(response.chat);
                          // setService(response.service); // 已移除service状态
                          
                          // 保存对话信息到localStorage（不包含敏感信息）
                          const chatToSave = {
                            chat: response.chat,
                            service: {
                              id: response.service.id,
                              name: response.service.name,
                              is_online: response.service.is_online
                            },
                            chatId: response.chat.chat_id
                          };
                          localStorage.setItem('currentCustomerServiceChat', JSON.stringify(chatToSave));
                          
                          // 加载该对话的聊天历史记录
                          await loadChatHistory(response.service.id, response.chat.chat_id);
                          
                          const successMessage: Message = {
                            id: Date.now(),
                            from: t('messages.system'),
                            content: t('messages.connectedToService', { name: response.service.name }),
                            created_at: new Date().toISOString()
                          };
                          setMessages(prev => [...prev, successMessage]);
                        } else {
                          // 客服不在线，显示系统提示
                          const noServiceMessage: Message = {
                            id: Date.now(),
                            from: t('messages.system'),
                            content: t('messages.noServiceAvailableShort'),
                            created_at: new Date().toISOString()
                          };
                          setMessages(prev => [...prev, noServiceMessage]);
                        }
                      } catch (error) {
                        console.error('连接客服失败:', error);
                        const errorMessage: Message = {
                          id: Date.now(),
                          from: t('messages.system'),
                          content: t('messages.connectServiceError'),
                          created_at: new Date().toISOString()
                        };
                        setMessages(prev => [...prev, errorMessage]);
                      } finally {
                        setIsConnectingToService(false);
                      }
                    }}
                    disabled={isConnectingToService}
                    style={{
                      background: isConnectingToService ? '#9ca3af' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '25px',
                      padding: '16px 32px',
                      fontSize: '16px',
                      fontWeight: '600',
                      cursor: isConnectingToService ? 'not-allowed' : 'pointer',
                      transition: 'all 0.3s ease',
                      boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
                    }}
                  >
                    {isConnectingToService ? '连接中...' : '开始对话'}
                  </button>
                </div>
              ) : (
                // 普通模式下的默认界面
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center', 
                  height: '100%',
                  color: '#64748b',
                  fontSize: '18px',
                  flexDirection: 'column',
                  gap: isMobile ? '12px' : '20px',
                  padding: isMobile ? '20px' : '40px'
                }}>
                  <div style={{ 
                    fontSize: isMobile ? '60px' : '80px', 
                    opacity: 0.3,
                    marginBottom: isMobile ? '8px' : '10px'
                  }}>💬</div>
                  <div style={{
                    fontSize: isMobile ? '18px' : '20px',
                    fontWeight: '600',
                    color: '#374151',
                    marginBottom: isMobile ? '6px' : '8px'
                  }}>
                    {t('messages.welcomeMessageCenter')}
                  </div>
                  <div style={{
                    fontSize: isMobile ? '14px' : '16px',
                    color: '#6b7280',
                    textAlign: 'center',
                    lineHeight: '1.5',
                    maxWidth: isMobile ? '280px' : '300px'
                  }}>
                    {t('messages.selectContactOrService')}
                    </div>
                  <div style={{
                    display: 'flex',
                    gap: isMobile ? '8px' : '12px',
                    marginTop: isMobile ? '16px' : '20px',
                    flexDirection: isMobile ? 'column' : 'row',
                    alignItems: 'center'
                  }}>
                    <div style={{
                          padding: '8px 16px',
                      background: 'linear-gradient(135deg, #f3f4f6, #e5e7eb)',
                      borderRadius: '20px',
                      fontSize: '14px',
                      color: '#6b7280',
                      border: '1px solid #d1d5db'
                    }}>
                      💬 私聊
                    </div>
                    <div style={{
                              padding: '8px 16px',
                      background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
                      borderRadius: '20px',
                      fontSize: '14px',
                      color: '#92400e',
                      border: '1px solid #f59e0b'
                    }}>
                      🎧 {t('messages.customerService')}
                    </div>
                  </div>
                </div>
              )
                    ) : null}
            
            {/* 消息加载骨架屏 */}
            {activeContact && !isServiceMode && messages.length === 0 && (
              <div style={{ padding: '20px' }}>
                {[...Array(3)].map((_, index) => (
                  <div key={index} style={{
                    display: 'flex',
                    justifyContent: index % 2 === 0 ? 'flex-end' : 'flex-start',
                    marginBottom: '16px'
                  }}>
                    <div style={{
                      maxWidth: '70%',
                      padding: '12px 16px',
                      borderRadius: '18px',
                      background: index % 2 === 0 ? '#3b82f6' : '#f1f5f9',
                      animation: 'pulse 1.5s ease-in-out infinite'
                    }}>
                      <div style={{
                        height: '16px',
                        background: index % 2 === 0 ? 'rgba(255,255,255,0.3)' : '#e2e8f0',
                        borderRadius: '4px',
                        width: index % 2 === 0 ? '120px' : '80px'
                      }}></div>
                    </div>
                  </div>
                ))}
              </div>
            )}
            
            {/* 加载更多消息的UI */}
            {activeContact && !isServiceMode && hasMoreMessages && (
              <div style={{
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                padding: '16px',
                color: '#64748b',
                fontSize: '14px'
              }}>
                {loadingMoreMessages ? (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <div style={{
                      width: '16px',
                      height: '16px',
                      border: '2px solid #e2e8f0',
                      borderTop: '2px solid #3b82f6',
                      borderRadius: '50%',
                      animation: 'spin 1s linear infinite'
                    }}></div>
                    加载历史消息中...
                  </div>
                ) : (
                  <div style={{ 
                    padding: '8px 16px',
                    background: 'rgba(59, 130, 246, 0.1)',
                    borderRadius: '20px',
                    border: '1px solid rgba(59, 130, 246, 0.2)',
                    cursor: 'pointer'
                  }}
                  onClick={loadMoreMessages}
                  >
                    向上滚动加载更多消息
                  </div>
                )}
              </div>
            )}
            
            {((activeContact && !isServiceMode) || (isServiceMode && messages.length > 0)) && messages.map((msg, idx) => {
              const systemText = t('messages.system');
              const meText = t('messages.me');
              const isSystemMessage = msg.from === systemText;
              const isImageMessage = msg.content.startsWith('[图片]');
              const isFileMessage = msg.content.startsWith('[文件]');
              const canTranslate = !isSystemMessage && !isImageMessage && !isFileMessage;
              const messageKey = getMessageKey(msg);
              const hasTranslation = messageTranslations.has(messageKey);
              const isTranslating = translatingMessages.has(messageKey);
              const translatedText = messageTranslations.get(messageKey);
              
              return (
              <div key={idx} style={{ 
                marginBottom: 16, 
                display: 'flex',
                justifyContent: msg.from === systemText ? 'center' : (msg.from === meText ? 'flex-end' : 'flex-start'),
                width: '100%'
              }}>
                <div style={{ 
                  background: msg.from === systemText 
                    ? 'linear-gradient(135deg, #f3f4f6, #e5e7eb)' 
                    : msg.from === meText 
                      ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' 
                      : '#fff', 
                  color: msg.from === systemText 
                    ? '#374151' 
                    : msg.from === meText 
                      ? '#fff' 
                      : '#333', 
                  borderRadius: 16, 
                  padding: '12px 20px', 
                  maxWidth: msg.from === systemText ? '80%' : '70%', 
                  wordBreak: 'break-word',
                  display: 'flex',
                  flexDirection: 'column',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                  border: msg.from === systemText 
                    ? '1px solid #d1d5db' 
                    : msg.from === meText 
                      ? 'none' 
                      : '1px solid #e2e8f0',
                  textAlign: msg.from === systemText ? 'center' : 'left',
                  position: 'relative'
                }}>
                  {msg.from !== systemText && (
                    <div style={{ fontSize: 14, marginBottom: 4, fontWeight: '600' }}>{msg.from}</div>
                  )}
                  {renderMessageContent(msg.content, msg)}
                  
                  {/* 翻译内容显示在原文下面 */}
                  {hasTranslation && translatedText && (
                    <div style={{
                      marginTop: '8px',
                      paddingTop: '8px',
                      borderTop: `1px solid ${msg.from === meText ? 'rgba(255,255,255,0.2)' : '#e2e8f0'}`,
                      fontSize: '14px',
                      color: msg.from === meText 
                        ? 'rgba(255,255,255,0.9)' 
                        : '#666',
                      fontStyle: 'italic',
                      opacity: 0.9
                    }}>
                      {translatedText}
                    </div>
                  )}
                  
                  <div style={{ 
                    fontSize: 12, 
                    color: msg.from === systemText 
                      ? '#6b7280' 
                      : msg.from === meText 
                        ? 'rgba(255,255,255,0.7)' 
                        : '#888', 
                    marginTop: 4,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: '8px'
                  }}>
                    <span>{formatTime(msg.created_at)}</span>
                    
                    {/* 翻译按钮 - 右下角 */}
                    {canTranslate && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          e.preventDefault();
                          handleTranslateMessage(msg, msg.content);
                        }}
                        disabled={isTranslating}
                        style={{
                          background: 'transparent',
                          border: 'none',
                          color: msg.from === meText 
                            ? 'rgba(255,255,255,0.7)' 
                            : '#888',
                          fontSize: '11px',
                          padding: '2px 6px',
                          cursor: isTranslating ? 'not-allowed' : 'pointer',
                          opacity: isTranslating ? 0.5 : 1,
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          borderRadius: '4px',
                          transition: 'all 0.2s',
                          marginLeft: 'auto'
                        }}
                        onMouseEnter={(e) => {
                          if (!isTranslating) {
                            e.currentTarget.style.background = msg.from === meText 
                              ? 'rgba(255,255,255,0.1)' 
                              : '#f3f4f6';
                            e.currentTarget.style.color = msg.from === meText 
                              ? '#fff' 
                              : '#3b82f6';
                          }
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.background = 'transparent';
                          e.currentTarget.style.color = msg.from === meText 
                            ? 'rgba(255,255,255,0.7)' 
                            : '#888';
                        }}
                        title={hasTranslation ? t('messages.hideTranslation') : t('messages.translate')}
                      >
                        {isTranslating ? '⏳' : hasTranslation ? '🌐' : '🌐'}
                        <span>{isTranslating ? t('messages.translating') : hasTranslation ? t('messages.hide') : t('messages.translate')}</span>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            )})}
            <div ref={messagesEndRef} />
                  </div>


          {/* 输入区域 */}
          <div style={{ 
            padding: isMobile ? '12px 16px' : '24px 30px', 
            borderTop: '1px solid #e2e8f0', 
            background: '#fff',
            position: 'relative',
            flexShrink: 0,
            minHeight: isMobile ? '70px' : 'auto',
            // 移动端确保输入区域始终可见
            ...(isMobile && {
              position: 'sticky',
              bottom: 0,
              zIndex: 10
            })
          }}>
            {/* 功能按钮行 */}
            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '16px', 
              marginBottom: '16px',
              flexWrap: 'wrap'
            }}>
              {/* 表情按钮 */}
                    <button
                onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                data-emoji-button
                      style={{
                  background: 'linear-gradient(135deg, #f8fafc, #f1f5f9)',
                  border: '2px solid #e2e8f0',
                  fontSize: '20px',
                  cursor: 'pointer',
                        padding: '12px',
                  borderRadius: '12px',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #1d4ed8)';
                  e.currentTarget.style.borderColor = '#3b82f6';
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                  e.currentTarget.style.borderColor = '#e2e8f0';
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
                }}
              >
                😊
                    </button>

              {/* 图片按钮 */}
                    <button
                onClick={() => {
                  const fileInput = document.getElementById('image-upload') as HTMLInputElement;
                  if (fileInput) {
                    fileInput.click();
                  }
                }}
                      style={{
                  background: 'linear-gradient(135deg, #f8fafc, #f1f5f9)',
                  border: '2px solid #e2e8f0',
                  fontSize: '18px',
                        cursor: 'pointer',
                  padding: '12px',
                  borderRadius: '12px',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #1d4ed8)';
                  e.currentTarget.style.borderColor = '#3b82f6';
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                  e.currentTarget.style.borderColor = '#e2e8f0';
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
                }}
              >
                📷
                    </button>

              {/* 文件按钮 */}
                    <button
                onClick={() => {
                  const fileInput = document.getElementById('file-upload') as HTMLInputElement;
                  if (fileInput) {
                    fileInput.click();
                  }
                }}
                      style={{
                  background: 'linear-gradient(135deg, #f8fafc, #f1f5f9)',
                  border: '2px solid #e2e8f0',
                  fontSize: '18px',
                        cursor: 'pointer',
                  padding: '12px',
                  borderRadius: '12px',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #10b981, #059669)';
                  e.currentTarget.style.borderColor = '#10b981';
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                  e.currentTarget.style.borderColor = '#e2e8f0';
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
                }}
              >
                📎
                    </button>

              {/* 客服模式专用按钮 */}
              {isServiceMode && (
                <>

                  {/* 联系在线客服按钮 / 结束对话按钮 */}
                  {!serviceConnected ? (
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                      {/* 客服在线状态指示器 */}
                      <div style={{ 
                        display: 'flex', 
                        alignItems: 'center', 
                        gap: '6px',
                        fontSize: '12px',
                        color: serviceStatusLoading ? '#6b7280' : (serviceAvailable ? '#10b981' : '#ef4444'),
                        fontWeight: '500'
                      }}>
                        <div style={{
                          width: '8px',
                          height: '8px',
                          borderRadius: '50%',
                          backgroundColor: serviceStatusLoading ? '#6b7280' : (serviceAvailable ? '#10b981' : '#ef4444'),
                          animation: serviceStatusLoading ? 'pulse 1.5s ease-in-out infinite' : 'none'
                        }}></div>
                        {serviceStatusLoading ? t('messages.checkingCustomerService') : (serviceAvailable ? t('messages.customerServiceOnline') : t('messages.customerServiceOffline'))}
                      </div>
                      
                      <button
                        onClick={handleContactCustomerService}
                        disabled={isConnectingToService || !serviceAvailable}
                        style={{
                          background: isConnectingToService || !serviceAvailable
                            ? 'linear-gradient(135deg, #9ca3af, #6b7280)' 
                            : 'linear-gradient(135deg, #10b981, #059669)',
                          border: `2px solid ${isConnectingToService || !serviceAvailable ? '#9ca3af' : '#10b981'}`,
                          fontSize: '14px',
                          cursor: isConnectingToService || !serviceAvailable ? 'not-allowed' : 'pointer',
                          padding: '12px 16px',
                          borderRadius: '12px',
                          transition: 'all 0.3s ease',
                          boxShadow: isConnectingToService || !serviceAvailable
                            ? '0 2px 8px rgba(156, 163, 175, 0.2)' 
                            : '0 2px 8px rgba(16, 185, 129, 0.2)',
                          color: '#fff',
                          fontWeight: '600',
                          opacity: isConnectingToService || !serviceAvailable ? 0.7 : 1
                        }}
                        onMouseEnter={(e) => {
                          if (!isConnectingToService && serviceAvailable) {
                            e.currentTarget.style.background = 'linear-gradient(135deg, #059669, #047857)';
                            e.currentTarget.style.borderColor = '#059669';
                            e.currentTarget.style.transform = 'translateY(-2px)';
                            e.currentTarget.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.4)';
                          }
                        }}
                        onMouseLeave={(e) => {
                          if (!isConnectingToService && serviceAvailable) {
                            e.currentTarget.style.background = 'linear-gradient(135deg, #10b981, #059669)';
                            e.currentTarget.style.borderColor = '#10b981';
                            e.currentTarget.style.transform = 'translateY(0)';
                            e.currentTarget.style.boxShadow = '0 2px 8px rgba(16, 185, 129, 0.2)';
                          }
                        }}
                      >
                        {isConnectingToService ? '⏳ 连接中...' : 
                         !serviceAvailable ? `🚫 ${t('messages.customerServiceOffline')}` : 
                         `🎧 ${t('messages.contactCustomerService')}`}
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={handleEndConversation}
                      style={{
                        background: 'linear-gradient(135deg, #ef4444, #dc2626)',
                        border: '2px solid #ef4444',
                        fontSize: '14px',
                        cursor: 'pointer',
                        padding: '12px 16px',
                        borderRadius: '12px',
                        transition: 'all 0.3s ease',
                        boxShadow: '0 2px 8px rgba(239, 68, 68, 0.2)',
                        color: '#fff',
                        fontWeight: '600'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = 'linear-gradient(135deg, #dc2626, #b91c1c)';
                        e.currentTarget.style.borderColor = '#dc2626';
                        e.currentTarget.style.transform = 'translateY(-2px)';
                        e.currentTarget.style.boxShadow = '0 4px 12px rgba(239, 68, 68, 0.4)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'linear-gradient(135deg, #ef4444, #dc2626)';
                        e.currentTarget.style.borderColor = '#ef4444';
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(239, 68, 68, 0.2)';
                      }}
                    >
                      🚪 {t('messages.endChat') || '结束对话'}
                    </button>
                  )}
                  
                </>
              )}
            </div>

            {/* 隐藏的文件输入 */}
            <input
              type="file"
              accept="image/*"
              onChange={handleImageSelect}
              style={{ display: 'none' }}
              id="image-upload"
            />

            {/* 隐藏的文件输入 */}
            <input
              type="file"
              accept=".pdf,.doc,.docx,.txt,.zip,.rar,.7z,.xlsx,.xls,.ppt,.pptx"
              onChange={handleFileSelect}
              style={{ display: 'none' }}
              id="file-upload"
            />

            {/* 图片预览区域 - 仅桌面端显示，移动端使用弹窗 */}
            {imagePreview && !isMobile && (
              <div style={{
                marginBottom: '12px',
                padding: '12px',
                background: '#f8fafc',
                borderRadius: '12px',
                border: '2px solid #e2e8f0'
              }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  marginBottom: '8px'
                }}>
                  <span style={{
                    fontSize: '14px',
                    fontWeight: '600',
                    color: '#374151'
                  }}>
                    📷 图片预览
                  </span>
                  <button
                    onClick={cancelImageSelection}
                    style={{
                      background: '#ef4444',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '6px',
                      padding: '4px 8px',
                      fontSize: '12px',
                      cursor: 'pointer',
                      transition: 'all 0.2s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = '#dc2626';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = '#ef4444';
                    }}
                  >
                    取消
                  </button>
                </div>
                <img
                  src={imagePreview}
                  alt="预览"
                  style={{
                    maxWidth: isMobile ? '100%' : '200px',
                    maxHeight: isMobile ? '300px' : '200px',
                    width: isMobile ? '100%' : 'auto',
                    borderRadius: '8px',
                    objectFit: 'cover'
                  }}
                />
                <div style={{
                  marginTop: '8px',
                  display: 'flex',
                  gap: '8px'
                }}>
                  <button
                    onClick={sendImage}
                    disabled={uploadingImage}
                    style={{
                      background: uploadingImage ? '#cbd5e1' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      padding: '8px 16px',
                      fontSize: '14px',
                      fontWeight: '600',
                      cursor: uploadingImage ? 'not-allowed' : 'pointer',
                      transition: 'all 0.3s ease'
                    }}
                  >
                    {uploadingImage ? t('messages.sending') : t('messages.sendImage')}
                  </button>
                </div>
              </div>
            )}

            {/* 文件预览区域 */}
            {filePreview && (
              <div style={{
                marginBottom: '12px',
                padding: '12px',
                background: '#f0fdf4',
                borderRadius: '12px',
                border: '2px solid #bbf7d0'
              }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  marginBottom: '8px'
                }}>
                  <span style={{
                    fontSize: '14px',
                    fontWeight: '600',
                    color: '#166534'
                  }}>
                    📎 {t('messages.filePreview')}
                  </span>
                  <button
                    onClick={cancelFileSelection}
                    style={{
                      background: '#ef4444',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '6px',
                      padding: '4px 8px',
                      fontSize: '12px',
                      cursor: 'pointer'
                    }}
                  >
                    ✕ 取消
                  </button>
                </div>
                <div style={{
                  fontSize: '14px',
                  color: '#374151',
                  marginBottom: '8px'
                }}>
                  {(() => {
                    try {
                      const fileInfo = JSON.parse(filePreview);
                      const sizeInMB = (fileInfo.size / (1024 * 1024)).toFixed(2);
                      return `${fileInfo.name} (${sizeInMB} MB)`;
                    } catch {
                      return '文件信息解析失败';
                    }
                  })()}
                </div>
                <div style={{
                  marginTop: '8px',
                  display: 'flex',
                  gap: '8px'
                }}>
                  <button
                    onClick={sendFile}
                    disabled={uploadingFile}
                    style={{
                      background: uploadingFile ? '#cbd5e1' : 'linear-gradient(135deg, #10b981, #059669)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      padding: '8px 16px',
                      fontSize: '14px',
                      fontWeight: '600',
                      cursor: uploadingFile ? 'not-allowed' : 'pointer',
                      transition: 'all 0.3s ease'
                    }}
                  >
                    {uploadingFile ? t('messages.sending') : t('messages.sendFile')}
                  </button>
                </div>
              </div>
            )}


            {/* 输入框和发送按钮 */}
            <div style={{ 
              display: 'flex', 
              gap: '12px', 
              alignItems: 'flex-end',
              position: 'relative'
            }}>
              {/* 表情选择器 */}
              {showEmojiPicker && (
                <div 
                  data-emoji-picker
                  style={{
                    position: 'absolute',
                    bottom: '100%',
                    left: 0,
                    right: 0,
                    background: '#fff',
                    border: '2px solid #e2e8f0',
                    borderRadius: '16px',
                    padding: '20px',
                    maxHeight: '250px',
                    overflowY: 'auto',
                    boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
                    zIndex: 1000,
                    display: 'grid',
                    gridTemplateColumns: 'repeat(8, 1fr)',
                    gap: '8px',
                    marginBottom: '12px',
                    width: '100%',
                    maxWidth: '100%',
                    boxSizing: 'border-box'
                  }}>
                  {/* 关闭按钮 */}
                  <div style={{
                    gridColumn: '1 / -1',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    marginBottom: '8px',
                    paddingBottom: '8px',
                    borderBottom: '1px solid #e2e8f0'
                  }}>
                    <span style={{
                      fontSize: '14px',
                      fontWeight: '600',
                      color: '#374151'
                    }}>选择表情</span>
                    <button
                      onClick={() => setShowEmojiPicker(false)}
                      style={{
                        background: 'none',
                        border: 'none',
                        fontSize: '18px',
                        cursor: 'pointer',
                        padding: '4px',
                        borderRadius: '4px',
                        color: '#6b7280',
                        transition: 'all 0.2s ease'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#f3f4f6';
                        e.currentTarget.style.color = '#374151';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'none';
                        e.currentTarget.style.color = '#6b7280';
                      }}
                    >
                      ✕
                    </button>
                  </div>
                  
                  {EMOJI_LIST.map((emoji, index) => (
                  <button
                      key={index}
                      onClick={() => addEmoji(emoji)}
                    style={{
                        background: 'none',
                      border: 'none',
                        fontSize: '20px',
                        cursor: 'pointer',
                        padding: '8px',
                        borderRadius: '8px',
                        transition: 'all 0.3s ease'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#f3f4f6';
                        e.currentTarget.style.transform = 'scale(1.1)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'none';
                        e.currentTarget.style.transform = 'scale(1)';
                      }}
                    >
                      {emoji}
                  </button>
                  ))}
        </div>
              )}
              
          <input
            type="text"
            value={input}
            onChange={e => setInput(e.target.value)}
                placeholder={
                  isServiceMode 
                    ? t('messages.inputYourQuestion')
                    : activeContact 
                      ? t('messages.inputMessage') || '输入消息...'
                      : t('messages.selectContactFirst') || '请先选择联系人'
                }
                style={{ 
                  flex: 1, 
                  padding: isMobile ? '12px 16px' : '16px 20px', 
                  borderRadius: '25px', 
                  border: '2px solid #e2e8f0',
                  background: '#fff',
                  color: '#1e293b',
                  fontSize: isMobile ? '16px' : '16px', // 移动端使用16px防止缩放
                  fontFamily: 'inherit',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
                  WebkitAppearance: 'none', // 移除iOS默认样式
                  appearance: 'none'
                }}
                disabled={!activeContact && !(isServiceMode && serviceConnected)}
              />
              
          <button
            onClick={handleSend}
                style={{ 
                  background: isSending 
                    ? 'linear-gradient(135deg, #6b7280, #4b5563)' 
                    : 'linear-gradient(135deg, #3b82f6, #1d4ed8)', 
                  color: '#fff', 
                  border: 'none', 
                  borderRadius: '25px', 
                  padding: '16px 24px', 
                  fontWeight: '700',
                  fontSize: '16px',
                  cursor: isSending ? 'not-allowed' : 'pointer',
                  transition: 'all 0.3s ease',
                  boxShadow: isSending 
                    ? '0 2px 6px rgba(107, 114, 128, 0.3)' 
                    : '0 4px 12px rgba(59, 130, 246, 0.3)',
                  opacity: isSending ? 0.7 : 1
                }}
                disabled={(() => {
                  const condition1 = !activeContact && !(isServiceMode && serviceConnected);
                  const condition2 = !input.trim();
                  const isDisabled = condition1 || condition2;
                  return isDisabled;
                })()}
              >
                {isSending ? t('messages.sending') : t('messages.send')}
              </button>
        </div>
      </div>
        </div>
      </div>

      {/* 评价弹窗 */}
      {showRatingModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div style={{
            background: '#fff',
            borderRadius: isMobile ? '16px' : '20px',
            padding: isMobile ? '20px' : '30px',
            maxWidth: isMobile ? '95%' : '500px',
            width: isMobile ? '95%' : '90%',
            boxShadow: '0 20px 40px rgba(0, 0, 0, 0.1)',
            maxHeight: isMobile ? '90vh' : 'auto',
            overflowY: isMobile ? 'auto' : 'visible'
          }}>
            <h3 style={{
              margin: '0 0 20px 0',
              fontSize: isMobile ? '18px' : '20px',
              fontWeight: '700',
              color: '#1e293b',
              textAlign: 'center'
            }}>
              💬 {t('messages.rateService')}
            </h3>
            
            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'block',
                marginBottom: '15px',
                fontSize: '16px',
                fontWeight: '600',
                color: '#374151',
                textAlign: 'center'
              }}>
                {t('messages.rateServicePrompt')}
              </label>
              
              {/* 交互式星星评分 */}
              <div style={{ 
                display: 'flex', 
                gap: isMobile ? '20px' : '30px', 
                justifyContent: 'center',
                marginBottom: '12px'
              }}>
                {[1, 2, 3, 4, 5].map((star) => (
                  <button
                    key={star}
                    onClick={() => setRating(star)}
                    style={{
                      background: 'none',
                      border: 'none',
                      fontSize: isMobile ? '28px' : '36px',
                      cursor: 'pointer',
                      padding: isMobile ? '2px' : '4px',
                      borderRadius: '4px',
                      transition: 'all 0.3s ease',
                      position: 'relative'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'scale(1.2)';
                      e.currentTarget.style.filter = 'drop-shadow(0 4px 8px rgba(251, 191, 36, 0.4))';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'scale(1)';
                      e.currentTarget.style.filter = 'none';
                    }}
                  >
                    {/* 星星轮廓 */}
                    <span style={{
                      position: 'absolute',
                      top: '50%',
                      left: '50%',
                      transform: 'translate(-50%, -50%)',
                      fontSize: isMobile ? '28px' : '36px',
                      color: '#d1d5db',
                      zIndex: 1
                    }}>
                      ⭐
                    </span>
                    
                    {/* 填充的星星 */}
                    {star <= rating && (
                      <span style={{
                        position: 'absolute',
                        top: '50%',
                        left: '50%',
                        transform: 'translate(-50%, -50%)',
                        fontSize: isMobile ? '28px' : '36px',
                        color: '#fbbf24',
                        zIndex: 2,
                        textShadow: '0 2px 4px rgba(251, 191, 36, 0.3)'
                      }}>
                        ⭐
                      </span>
                    )}
                  </button>
                ))}
              </div>
              
              {/* 评分文字说明 */}
              <div style={{
                textAlign: 'center',
                fontSize: '16px',
                fontWeight: '600',
                color: rating >= 4 ? '#059669' : rating >= 3 ? '#d97706' : '#dc2626',
                padding: '8px 16px',
                borderRadius: '20px',
                background: rating >= 4 ? '#ecfdf5' : rating >= 3 ? '#fef3c7' : '#fef2f2',
                border: `2px solid ${rating >= 4 ? '#10b981' : rating >= 3 ? '#f59e0b' : '#ef4444'}`,
                display: 'inline-block',
                margin: '0 auto',
                minWidth: '120px'
              }}>
                {rating === 1 && t('messages.ratingVeryDissatisfied')}
                {rating === 2 && t('messages.ratingDissatisfied')}
                {rating === 3 && t('messages.ratingNeutral')}
                {rating === 4 && t('messages.ratingSatisfied')}
                {rating === 5 && t('messages.ratingVerySatisfied')}
              </div>
              
              {/* 评分数字显示 */}
              <div style={{
                textAlign: 'center',
                marginTop: '8px',
                fontSize: '14px',
                color: '#6b7280'
              }}>
                {t('messages.currentRating', { rating })}
              </div>
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'block',
                marginBottom: '10px',
                fontSize: '14px',
                fontWeight: '600',
                color: '#374151'
              }}>
                {t('messages.ratingComment')}：
              </label>
              <textarea
                value={ratingComment}
                onChange={(e) => setRatingComment(e.target.value)}
                placeholder={t('messages.ratingCommentPlaceholder')}
                style={{
                  width: '100%',
                  minHeight: '80px',
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

            <div style={{
              display: 'flex',
              gap: isMobile ? '8px' : '12px',
              justifyContent: 'center',
              flexDirection: isMobile ? 'column' : 'row'
            }}>
              <button
                onClick={() => {
                  setShowRatingModal(false);
                  setRating(5);
                  setRatingComment('');
                  setRatingChatId(null);
                }}
                style={{
                  background: '#f3f4f6',
                  color: '#374151',
                  border: 'none',
                  padding: isMobile ? '14px 20px' : '12px 24px',
                  borderRadius: '8px',
                  fontSize: isMobile ? '16px' : '14px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                  width: isMobile ? '100%' : 'auto'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#e5e7eb';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f3f4f6';
                }}
              >
                {t('common.cancel')}
              </button>
              <button
                onClick={handleSubmitRating}
                style={{
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  padding: isMobile ? '14px 20px' : '12px 24px',
                  borderRadius: '8px',
                  fontSize: isMobile ? '16px' : '14px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                  width: isMobile ? '100%' : 'auto'
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
                {t('messages.submitRating')}
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

      {/* 移动端图片发送弹窗 */}
      {showMobileImageSendModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.8)',
          zIndex: 10001,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '20px'
        }}>
          {/* 弹窗内容 */}
          <div style={{
            background: '#fff',
            borderRadius: '16px',
            padding: '20px',
            maxWidth: '90vw',
            maxHeight: '90vh',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '16px',
            boxShadow: '0 20px 60px rgba(0,0,0,0.3)'
          }}>
            {/* 标题 */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '18px',
              fontWeight: '600',
              color: '#1f2937'
            }}>
              📷 {t('messages.sendImage')}
            </div>
            
            {/* 图片预览 */}
            <img
              src={previewImageUrl}
              alt="图片预览"
              style={{
                maxWidth: '100%',
                maxHeight: '50vh',
                borderRadius: '12px',
                objectFit: 'contain',
                border: '2px solid #e5e7eb'
              }}
            />
            
            {/* 按钮区域 */}
            <div style={{
              display: 'flex',
              gap: '12px',
              width: '100%'
            }}>
              <button
                onClick={() => {
                  setShowMobileImageSendModal(false);
                  setPreviewImageUrl('');
                  setSelectedImage(null);
                  setImagePreview(null);
                }}
                style={{
                  flex: 1,
                  padding: '12px 20px',
                  background: '#f1f5f9',
                  color: '#64748b',
                  border: 'none',
                  borderRadius: '12px',
                  fontSize: '16px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#e2e8f0';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f1f5f9';
                }}
              >
                取消
              </button>
              <button
                onClick={sendImageFromModal}
                disabled={uploadingImage}
                style={{
                  flex: 1,
                  padding: '12px 20px',
                  background: uploadingImage ? '#cbd5e1' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '12px',
                  fontSize: '16px',
                  fontWeight: '600',
                  cursor: uploadingImage ? 'not-allowed' : 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  if (!uploadingImage) {
                    e.currentTarget.style.transform = 'translateY(-1px)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                  }
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = 'none';
                }}
              >
                {uploadingImage ? '发送中...' : '发送图片'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 图片预览模态框 */}
      {showImagePreview && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.9)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 10000,
          padding: '20px'
        }}
        onClick={() => setShowImagePreview(false)}
        >
          <div style={{
            position: 'relative',
            maxWidth: '90vw',
            maxHeight: '90vh',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center'
          }}
          onClick={(e) => e.stopPropagation()}
          >
            {/* 关闭按钮 */}
            <button
              onClick={() => setShowImagePreview(false)}
              style={{
                position: 'absolute',
                top: '-50px',
                right: '0',
                background: 'rgba(255, 255, 255, 0.2)',
                border: 'none',
                borderRadius: '50%',
                width: '40px',
                height: '40px',
                color: 'white',
                fontSize: '20px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                zIndex: 10001
              }}
            >
              ×
            </button>
            
            {/* 图片 */}
            <img
              src={previewImageUrl}
              alt="图片预览"
              style={{
                maxWidth: '100%',
                maxHeight: '90vh',
                objectFit: 'contain',
                borderRadius: '8px',
                boxShadow: '0 10px 30px rgba(0, 0, 0, 0.5)'
              }}
              onError={(e) => {
                console.error('图片加载失败:', previewImageUrl);
                const img = e.currentTarget;
                img.style.display = 'none';
                const errorDiv = document.createElement('div');
                errorDiv.style.cssText = `
                  color: white;
                  font-size: 18px;
                  text-align: center;
                  padding: 40px;
                  background: rgba(255, 255, 255, 0.1);
                  border-radius: 8px;
                  border: 2px dashed rgba(255, 255, 255, 0.3);
                `;
                errorDiv.textContent = '图片加载失败';
                img.parentNode?.appendChild(errorDiv);
              }}
            />
            
            {/* 下载按钮 */}
            <button
              onClick={() => {
                const link = document.createElement('a');
                link.href = previewImageUrl;
                link.download = `image_${Date.now()}.jpg`;
                link.click();
              }}
              style={{
                marginTop: '20px',
                background: 'rgba(59, 130, 246, 0.8)',
                border: 'none',
                borderRadius: '8px',
                padding: '12px 24px',
                color: 'white',
                fontSize: '16px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'rgba(59, 130, 246, 1)';
                e.currentTarget.style.transform = 'translateY(-2px)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'rgba(59, 130, 246, 0.8)';
                e.currentTarget.style.transform = 'translateY(0)';
              }}
            >
              📥 下载图片
            </button>
          </div>
        </div>
      )}
      
      {/* 固定定位的滚动到底部按钮 - 相对于聊天区域居中 */}
      {showScrollToBottomButton && (
        <div
          onClick={scrollToBottom}
          style={{
            position: 'fixed',
            bottom: '160px', // 在输入框上方更高的位置
            left: isMobile ? '50%' : 'calc(50% + 175px)', // 相对于聊天区域居中（联系人列表宽度350px的一半）
            transform: 'translateX(-50%)',
            width: '56px',
            height: '56px',
            borderRadius: '50%',
            backgroundColor: '#007bff',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            boxShadow: '0 6px 20px rgba(0, 123, 255, 0.4)',
            transition: 'all 0.3s ease',
            zIndex: 10000, // 确保在所有内容之上
            fontSize: '24px',
            fontWeight: 'bold',
            border: '3px solid white' // 添加白色边框增强视觉效果
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.transform = 'translateX(-50%) scale(1.1)';
            e.currentTarget.style.backgroundColor = '#0056b3';
            e.currentTarget.style.boxShadow = '0 8px 25px rgba(0, 123, 255, 0.5)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'translateX(-50%) scale(1)';
            e.currentTarget.style.backgroundColor = '#007bff';
            e.currentTarget.style.boxShadow = '0 6px 20px rgba(0, 123, 255, 0.4)';
          }}
          title="滚动到底部"
        >
          ↓
        </div>
      )}
      
      {/* 移动端样式 */}
      <style>
        {`
          @media (max-width: 768px) {
            /* 表情选择器移动端优化 */
            [data-emoji-picker] {
              position: fixed !important;
              bottom: 80px !important;
              left: 10px !important;
              right: 10px !important;
              width: calc(100% - 20px) !important;
              max-width: calc(100% - 20px) !important;
              grid-template-columns: repeat(6, 1fr) !important;
              gap: 6px !important;
              padding: 16px !important;
              max-height: 200px !important;
              border-radius: 12px !important;
            }
            
            /* 表情按钮移动端优化 */
            [data-emoji-picker] button {
              width: 32px !important;
              height: 32px !important;
              font-size: 18px !important;
              padding: 4px !important;
            }
            
            /* 输入框区域移动端优化 */
            .message-input-container {
              padding: 12px !important;
            }
            
            .message-input-area {
              flex-direction: column !important;
              gap: 8px !important;
            }
            
            .message-input-row {
              width: 100% !important;
            }
          }
          
          @media (max-width: 480px) {
            /* 超小屏幕优化 */
            [data-emoji-picker] {
              grid-template-columns: repeat(5, 1fr) !important;
              gap: 4px !important;
              padding: 12px !important;
              max-height: 180px !important;
            }
            
            [data-emoji-picker] button {
              width: 28px !important;
              height: 28px !important;
              font-size: 16px !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default MessagePage; 
