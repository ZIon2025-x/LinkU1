import React, { useEffect, useRef, useState, useCallback } from 'react';
import { API_BASE_URL, WS_BASE_URL, API_ENDPOINTS } from '../config';
import api, { 
  fetchCurrentUser, 
  assignCustomerService, 
  sendMessage, 
  checkCustomerServiceAvailability, 
  markChatMessagesAsRead, 
  // 任务聊天相关API
  getTaskChatList,
  getTaskMessages,
  sendTaskMessage,
  markTaskMessagesRead,
  getTaskApplicationsWithFilter,
  acceptApplication,
  rejectApplication,
  withdrawApplication,
  negotiateApplication,
  respondNegotiation,
  applyForTask
} from '../api';
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
  
  // 任务聊天相关状态
  const [chatMode, setChatMode] = useState<'tasks'>('tasks'); // 聊天模式：任务（联系人功能已移除）
  const [tasks, setTasks] = useState<any[]>([]); // 任务列表
  const [tasksLoading, setTasksLoading] = useState(false);
  const [activeTaskId, setActiveTaskId] = useState<number | null>(null);
  const [activeTask, setActiveTask] = useState<any>(null);
  const [taskMessages, setTaskMessages] = useState<any[]>([]); // 任务消息
  const [taskMessagesLoading, setTaskMessagesLoading] = useState(false);
  const [taskNextCursor, setTaskNextCursor] = useState<string | null>(null);
  const [taskHasMore, setTaskHasMore] = useState(false);
  const [applications, setApplications] = useState<any[]>([]); // 申请列表
  const [applicationsLoading, setApplicationsLoading] = useState(false);
  const [showApplicationModal, setShowApplicationModal] = useState(false);
  const [showApplicationListModal, setShowApplicationListModal] = useState(false);
  const [applicationMessage, setApplicationMessage] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState<number | undefined>();
  
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
  
  // 无限滚动相关状态
  const [loadingMoreMessages, setLoadingMoreMessages] = useState(false);
  const [hasMoreMessages, setHasMoreMessages] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  
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
      
      // 上传图片到服务器（使用api.post自动处理CSRF token）
      const uploadResponse = await api.post('/api/upload/image', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      
      const uploadResult = uploadResponse.data;
      
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


  // 发送图片消息的通用方法（仅用于客服模式）
  const sendImageMessage = async (messageContent: string) => {
    if (ws && ws.readyState === WebSocket.OPEN) {
      if (isServiceMode && currentChat) {
        const messageData = {
          receiver_id: currentChat.service_id,
          content: messageContent,
          chat_id: currentChat.chat_id
        };
        ws.send(JSON.stringify(messageData));
        
        // 立即添加消息到本地状态
        const newMessage = {
          id: Date.now(),
          from: t('messages.me'),
          content: messageContent,
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, newMessage]);
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
          const messageData = {
            receiver_id: currentChat.service_id,
            content: messageContent,
            chat_id: currentChat.chat_id
          };
          ws.send(JSON.stringify(messageData));
          
          // 添加消息到本地状态
          const newMessage: Message = {
            from: user?.id || 'me',
            content: messageContent,
            created_at: new Date().toISOString()
          };
          setMessages(prev => [...prev, newMessage]);
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

  // 发送图片（从弹窗）- 移动端专用
  const sendImageFromModal = async () => {
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
      
      // 上传图片到服务器（使用api.post自动处理CSRF token）
      const uploadResponse = await api.post('/api/upload/image', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      
      const uploadResult = uploadResponse.data;
      
      if (!uploadResult.image_id) {
        throw new Error('服务器未返回图片ID');
      }
      
      const imageId = uploadResult.image_id;
      
      // 发送包含图片ID的消息（使用通用方法）
      const messageContent = `[图片] ${imageId}`;
      await sendImageMessage(messageContent);
      
      // 清空图片选择并关闭弹窗（移动端特有）
      setSelectedImage(null);
      setImagePreview(null);
      setShowMobileImageSendModal(false);
      setPreviewImageUrl('');
      setInput('');
    } catch (error) {
      console.error('发送图片失败:', error);
      alert(t('messages.sendImageFailed', { error: error instanceof Error ? error.message : String(error) }));
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

  // 发送任务消息
  const handleSendTaskMessage = async () => {
    if (!activeTaskId || !input.trim() || isSending) return;
    
    const messageContent = input.trim();
    setInput('');
    setIsSending(true);
    
    try {
      const response = await sendTaskMessage(
        activeTaskId,
        messageContent,
        undefined, // meta
        [] // attachments - 暂时不支持附件，后续可以扩展
      );
      
      // 重新加载消息列表
      await loadTaskMessages(activeTaskId);
      
      // 标记消息为已读
      if (response.id) {
        await markTaskMessagesRead(activeTaskId, response.id);
      }
      
      // 重新加载任务列表以更新未读计数
      await loadTasks();
      
      // 滚动到底部
      setTimeout(() => {
        if (messagesEndRef.current) {
          messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
      }, 100);
    } catch (error: any) {
      console.error('发送任务消息失败:', error);
      alert(error.response?.data?.detail || '发送消息失败，请重试');
      setInput(messageContent); // 恢复输入内容
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

  // 加载任务列表
  const loadTasks = useCallback(async () => {
    if (!user) {
      console.log('loadTasks: 用户未登录，跳过加载');
      return;
    }
    
    console.log('loadTasks: 开始加载任务列表，用户ID:', user.id);
    setTasksLoading(true);
    try {
      const data = await getTaskChatList(50, 0);
      console.log('loadTasks: 获取到任务列表数据:', data);
      setTasks(data.tasks || []);
      console.log('loadTasks: 任务列表已更新，任务数量:', data.tasks?.length || 0);
    } catch (error) {
      console.error('加载任务列表失败:', error);
      setTasks([]);
    } finally {
      setTasksLoading(false);
    }
  }, [user]);

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

  // 加载任务消息
  const loadTaskMessages = useCallback(async (taskId: number, cursor?: string | null) => {
    setTaskMessagesLoading(true);
    try {
      const data = await getTaskMessages(taskId, 20, cursor || undefined);
      
      // 后端返回的消息是按 created_at DESC 排序的（最新的在前）
      // 前端需要反转，让最新的消息在底部显示
      const reversedMessages = [...(data.messages || [])].reverse();
      
      if (cursor) {
        // 加载更多消息（更旧的消息），追加到前面
        setTaskMessages(prev => [...reversedMessages, ...prev]);
      } else {
        // 首次加载或刷新，替换消息（已反转，最新的在底部）
        setTaskMessages(reversedMessages);
      }
      
      setActiveTask(data.task);
      setTaskNextCursor(data.next_cursor || null);
      setTaskHasMore(data.has_more || false);
      
      // 标记消息为已读（后端返回的最新消息在数组第一个位置）
      if (data.messages && data.messages.length > 0) {
        const lastMessage = data.messages[0]; // 后端返回的最新消息在数组第一个位置
        markTaskMessagesRead(taskId, lastMessage.id);
      }
      
      // 首次加载时滚动到底部
      if (!cursor) {
        setTimeout(() => {
          if (messagesEndRef.current) {
            messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
          }
        }, 100);
      }
    } catch (error) {
      console.error('加载任务消息失败:', error);
    } finally {
      setTaskMessagesLoading(false);
    }
  }, []);

  // 加载申请列表
  const loadApplications = useCallback(async (taskId: number) => {
    if (!user) return;
    
    setApplicationsLoading(true);
    try {
      const data = await getTaskApplicationsWithFilter(taskId, 'pending', 50, 0);
      setApplications(data.applications || []);
    } catch (error) {
      console.error('加载申请列表失败:', error);
    } finally {
      setApplicationsLoading(false);
    }
  }, [user]);

  // 当选择任务时加载消息和申请
  useEffect(() => {
    if (chatMode === 'tasks' && activeTaskId && user) {
      setTaskMessages([]);
      setTaskNextCursor(null);
      loadTaskMessages(activeTaskId);
      loadApplications(activeTaskId);
    }
  }, [activeTaskId, chatMode, user, loadTaskMessages, loadApplications]);

  // 当切换到任务模式时加载任务列表
  useEffect(() => {
    if (chatMode === 'tasks' && user) {
      console.log('useEffect: 触发任务列表加载，chatMode:', chatMode, 'user:', user?.id);
      loadTasks();
    } else {
      console.log('useEffect: 跳过任务列表加载，chatMode:', chatMode, 'user:', user?.id);
    }
  }, [chatMode, user, loadTasks]);

  // 定期刷新任务消息和申请列表（每30秒）
  useEffect(() => {
    if (chatMode === 'tasks' && activeTaskId && user && !isServiceMode) {
      const interval = setInterval(() => {
        // 只在页面可见时刷新
        if (!document.hidden) {
          loadTaskMessages(activeTaskId);
          loadApplications(activeTaskId);
          loadTasks(); // 更新未读计数
        }
      }, 30000); // 30秒刷新一次
      
      return () => clearInterval(interval);
    }
  }, [activeTaskId, chatMode, user, isServiceMode, loadTaskMessages, loadApplications, loadTasks]);


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

  // 定期更新未读消息数量（每30秒检查一次）
  useEffect(() => {
    if (!user) return;

    const interval = setInterval(() => {
      loadUnreadCount();
    }, 30000); // 30秒检查一次

    return () => clearInterval(interval);
  }, [user, loadUnreadCount]);

  // 页面可见性变化时更新未读消息数量
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && user) {
        // 页面变为可见时，重新加载未读消息数量
        loadUnreadCount();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [user, loadUnreadCount]);

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
                
                // 如果是接收到的消息（不是自己发送的），播放提示音
                if (msg.from !== user.id && msg.from !== 'system' && msg.from !== 'customer_service' && msg.from !== 'admin') {
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

  const loadChatHistory = useCallback(async (serviceId: string, chatId: string) => {
    try {
      
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
        if (formattedMessages.length > 0) {
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
      
    } catch (error) {
      console.error('加载聊天历史失败:', error);
    }
  }, [t]);

  // 滚动到底部
  const scrollToBottom = useCallback(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
      setShowScrollToBottomButton(false);
    }
  }, []);

  // 滚动监听器 - 检测是否滚动到顶部（仅用于客服模式）
  useEffect(() => {
    const messagesContainer = messagesContainerRef.current;
    if (!messagesContainer || !isServiceMode) {
      return;
    }

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
      
      // 控制"滚动到底部"按钮的显示
      // 当用户向上滚动超过200px时显示按钮，接近底部时隐藏
      const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
      setShowScrollToBottomButton(distanceFromBottom > 200);
    };

    messagesContainer.addEventListener('scroll', handleScroll);
    return () => {
      messagesContainer.removeEventListener('scroll', handleScroll);
    };
  }, [isServiceMode]);

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
        
        {/* 左侧任务列表 */}
        <div style={{ 
          width: isMobile ? '100%' : '350px', 
          borderRight: isMobile ? 'none' : '1px solid #e2e8f0', 
          background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
          display: 'flex',
          flexDirection: 'column',
          position: isMobile ? 'absolute' : 'relative',
          zIndex: isMobile ? 1000 : 'auto',
          transition: isMobile ? 'transform 0.3s ease-in-out' : 'all 0.3s ease',
          overflow: isMobile ? 'hidden' : 'visible',
          transform: 'none',
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
                placeholder={t('messages.searchTasks') || '搜索任务...'}
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

          {/* 任务列表 */}
          <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
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
                      setActiveTaskId(null);
                      setActiveTask(null);
                      setTaskMessages([]);
                      setServiceConnected(true);
                      setCurrentChatId(chatData.chat.chat_id);
                      setCurrentChat(chatData.chat);
                      
                      // 加载该对话的聊天历史记录
                      await loadChatHistory(chatData.service.id, chatData.chat.chat_id);
                      setIsConnectingToService(false);
                      
                      return; // 直接返回，不创建新对话
                    } else {
                      // 对话已结束，清除localStorage并重置状态
                      localStorage.removeItem('currentCustomerServiceChat');
                      setServiceConnected(false);
                      setCurrentChatId(null);
                      setCurrentChat(null);
                    }
                  } catch (error) {
                    console.error('解析保存的对话失败:', error);
                    localStorage.removeItem('currentCustomerServiceChat');
                    setServiceConnected(false);
                    setCurrentChatId(null);
                    setCurrentChat(null);
                  }
                }
                
                // 如果没有未结束的对话，只显示客服聊天框
                setIsServiceMode(true);
                setActiveTaskId(null);
                setActiveTask(null);
                setTaskMessages([]);
                setMessages([]);
                setShowSystemWarning(true);
                
              }}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '16px',
                padding: '20px 24px',
                cursor: 'pointer',
                background: isServiceMode ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' : 'transparent',
                color: isServiceMode ? '#fff' : '#475569',
                fontWeight: isServiceMode ? 700 : 600,
                position: 'relative',
                transition: 'all 0.3s ease',
                borderBottom: '1px solid #e2e8f0',
                flexShrink: 0
              }}
              onMouseEnter={(e) => {
                if (!isServiceMode) {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                }
              }}
              onMouseLeave={(e) => {
                if (!isServiceMode) {
                  e.currentTarget.style.background = 'transparent';
                }
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
                  transition: 'none'
                }} 
                onError={(e) => {
                  console.error('客服头像加载失败:', e.currentTarget.src);
                  e.currentTarget.src = '/static/avatar1.png';
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

            {/* 任务列表内容 */}
            <div style={{ flex: 1, overflowY: 'auto' }}>
              {tasksLoading && tasks.length === 0 ? (
                <div style={{ padding: '20px', textAlign: 'center' }}>加载中...</div>
              ) : tasks.length === 0 ? (
                <div style={{ padding: '20px', textAlign: 'center', color: '#6b7280' }}>
                  暂无任务
                </div>
              ) : (
                tasks.map(task => (
                  <div
                    key={task.id}
                    onClick={() => {
                      setActiveTaskId(task.id);
                    }}
                    style={{
                      padding: '12px 16px',
                      borderBottom: '1px solid #e5e7eb',
                      cursor: 'pointer',
                      backgroundColor: activeTaskId === task.id ? '#eff6ff' : 'white',
                      transition: 'background-color 0.2s'
                    }}
                  >
                    <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                      {/* 任务图片 */}
                      {task.images && task.images.length > 0 ? (
                        <img
                          src={task.images[0]}
                          alt={task.title}
                          style={{
                            width: '50px',
                            height: '50px',
                            borderRadius: '8px',
                            objectFit: 'cover',
                            flexShrink: 0
                          }}
                        />
                      ) : (
                        <div style={{
                          width: '50px',
                          height: '50px',
                          borderRadius: '8px',
                          background: '#e5e7eb',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '24px',
                          flexShrink: 0
                        }}>
                          📋
                        </div>
                      )}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontWeight: 600, marginBottom: '4px' }}>{task.title}</div>
                        {task.last_message && (
                          <div style={{ fontSize: '14px', color: '#6b7280', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {task.last_message.sender_name}: {task.last_message.content}
                          </div>
                        )}
                      </div>
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '4px' }}>
                        {task.unread_count > 0 && (
                          <div style={{
                            backgroundColor: '#ef4444',
                            color: 'white',
                            borderRadius: '10px',
                            padding: '2px 8px',
                            fontSize: '12px',
                            fontWeight: 600,
                            minWidth: '20px',
                            textAlign: 'center'
                          }}>
                            {task.unread_count}
                          </div>
                        )}
                        {task.last_message && (
                          <div style={{ fontSize: '11px', color: '#9ca3af' }}>
                            {dayjs(task.last_message.created_at).format('HH:mm')}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
        
        {/* 右侧聊天区域 */}
        <div style={{ 
          flex: 1, 
          display: 'flex', 
          flexDirection: 'column',
          background: '#fff',
          position: 'relative'
        }}>
          {/* 聊天头部 */}
          {isServiceMode ? (
            <div style={{
              padding: '20px 24px',
              borderBottom: '1px solid #e2e8f0',
              background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              gap: '16px'
            }}>
              <img src={'/static/service.png'} alt={t('messages.service')} style={{ 
                width: '50px', 
                height: '50px', 
                borderRadius: '50%', 
                border: '3px solid #f59e0b', 
                background: '#fffbe6', 
                objectFit: 'cover',
                boxShadow: '0 4px 12px rgba(245, 158, 11, 0.3)'
              }} 
              onError={(e) => {
                console.error('客服头像加载失败:', e.currentTarget.src);
                e.currentTarget.src = '/static/avatar1.png';
              }}
              />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '20px', fontWeight: '700', marginBottom: '4px' }}>
                  {t('messages.customerServiceCenter')}
                </div>
                <div style={{ 
                  fontSize: '14px', 
                  opacity: 0.9,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px'
                }}>
                  <span>{t('messages.onlineService')}</span>
                  <div style={{
                    width: '8px',
                    height: '8px',
                    background: '#10b981',
                    borderRadius: '50%'
                  }}></div>
                </div>
              </div>
            </div>
          ) : activeTaskId && activeTask ? (
            <div style={{
              padding: '20px 24px',
              borderBottom: '1px solid #e2e8f0',
              background: 'white',
              display: 'flex',
              gap: '16px',
              alignItems: 'center'
            }}>
              {/* 任务图片 */}
              {activeTask.images && activeTask.images.length > 0 ? (
                <img
                  src={activeTask.images[0]}
                  alt={activeTask.title}
                  style={{
                    width: '50px',
                    height: '50px',
                    borderRadius: '8px',
                    objectFit: 'cover',
                    flexShrink: 0
                  }}
                />
              ) : (
                <div style={{
                  width: '50px',
                  height: '50px',
                  borderRadius: '8px',
                  background: '#e5e7eb',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '24px',
                  flexShrink: 0
                }}>
                  📋
                </div>
              )}
              <div style={{ flex: 1 }}>
                <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>{activeTask.title}</h3>
                <div style={{ fontSize: '14px', color: '#6b7280', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  {activeTask.status === 'open' && !activeTask.taker_id && (
                    <span style={{
                      padding: '2px 8px',
                      background: '#fef3c7',
                      color: '#92400e',
                      borderRadius: '4px',
                      fontSize: '12px',
                      fontWeight: 600
                    }}>等待接受</span>
                  )}
                  {activeTask.status === 'in_progress' && (
                    <span style={{
                      padding: '2px 8px',
                      background: '#dbeafe',
                      color: '#1e40af',
                      borderRadius: '4px',
                      fontSize: '12px',
                      fontWeight: 600
                    }}>进行中</span>
                  )}
                  {activeTask.status === 'completed' && (
                    <span style={{
                      padding: '2px 8px',
                      background: '#d1fae5',
                      color: '#065f46',
                      borderRadius: '4px',
                      fontSize: '12px',
                      fontWeight: 600
                    }}>已完成</span>
                  )}
                  {activeTask.status === 'cancelled' && (
                    <span style={{
                      padding: '2px 8px',
                      background: '#fee2e2',
                      color: '#991b1b',
                      borderRadius: '4px',
                      fontSize: '12px',
                      fontWeight: 600
                    }}>已取消</span>
                  )}
                </div>
              </div>
              {activeTask.poster_id === user?.id && activeTask.status === 'open' && !activeTask.taker_id && (
                <button
                  onClick={() => setShowApplicationListModal(true)}
                  style={{
                    padding: '8px 16px',
                    backgroundColor: '#3b82f6',
                    color: 'white',
                    border: 'none',
                    borderRadius: '6px',
                    cursor: 'pointer',
                    fontSize: '14px',
                    fontWeight: 600,
                    transition: 'all 0.2s'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = '#2563eb';
                    e.currentTarget.style.transform = 'translateY(-1px)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = '#3b82f6';
                    e.currentTarget.style.transform = 'translateY(0)';
                  }}
                >
                  查看申请
                </button>
              )}
            </div>
          ) : null}
          
          {/* 消息区域 */}
          <div style={{ 
            flex: 1, 
            overflowY: 'auto', 
            padding: '20px',
            background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)'
          }}>
            {isServiceMode && !serviceConnected ? (
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
                      const isServiceAvailable = await checkCustomerServiceAvailabilityLocal();
                        
                      if (isServiceAvailable) {
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
                          
                        setServiceConnected(true);
                        setCurrentChatId(response.chat.chat_id);
                        setCurrentChat(response.chat);
                          
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
                          
                        await loadChatHistory(response.service.id, response.chat.chat_id);
                          
                        const successMessage: Message = {
                          id: Date.now(),
                          from: t('messages.system'),
                          content: t('messages.connectedToService', { name: response.service.name }),
                          created_at: new Date().toISOString()
                        };
                        setMessages(prev => [...prev, successMessage]);
                      } else {
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
            ) : !activeTaskId && !isServiceMode ? (
              (
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
                  }}>📋</div>
                  <div style={{
                    fontSize: isMobile ? '18px' : '20px',
                    fontWeight: '600',
                    color: '#374151',
                    marginBottom: isMobile ? '6px' : '8px'
                  }}>
                    选择任务开始聊天
                  </div>
                  <div style={{
                    fontSize: isMobile ? '14px' : '16px',
                    color: '#6b7280',
                    textAlign: 'center',
                    lineHeight: '1.5',
                    maxWidth: isMobile ? '280px' : '300px'
                  }}>
                    从左侧列表中选择一个任务查看聊天记录
                  </div>
                </div>
              )
            ) : null}
            
            {/* 任务聊天消息显示 */}
            {chatMode === 'tasks' && activeTaskId && activeTask && (
              <>
                {/* 申请卡片区 - 独立于消息流 */}
                {activeTask.status === 'open' && !activeTask.taker_id && (
                  <div style={{
                    padding: '16px',
                    marginBottom: '16px',
                    background: 'white',
                    borderRadius: '12px',
                    border: '1px solid #e5e7eb',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                  }}>
                    {activeTask.poster_id === user?.id ? (
                      <div>
                        <div style={{
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          marginBottom: '12px'
                        }}>
                          <div style={{ fontWeight: 600, fontSize: '16px' }}>待处理申请</div>
                          {applications.length > 0 && (
                            <button
                              onClick={() => setShowApplicationListModal(true)}
                              style={{
                                padding: '6px 12px',
                                backgroundColor: '#3b82f6',
                                color: 'white',
                                border: 'none',
                                borderRadius: '6px',
                                cursor: 'pointer',
                                fontSize: '14px',
                                fontWeight: 600
                              }}
                            >
                              查看全部 ({applications.length})
                            </button>
                          )}
                        </div>
                        {applications.length === 0 ? (
                          <div style={{ color: '#6b7280', fontSize: '14px', textAlign: 'center', padding: '20px' }}>
                            暂无申请
                          </div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                            {applications.slice(0, 3).map((app: any) => (
                              <div
                                key={app.id}
                                style={{
                                  padding: '12px',
                                  background: '#f9fafb',
                                  borderRadius: '8px',
                                  border: '1px solid #e5e7eb'
                                }}
                              >
                                <div style={{
                                  display: 'flex',
                                  alignItems: 'center',
                                  gap: '10px',
                                  marginBottom: '8px'
                                }}>
                                  <img
                                    src={app.applicant_avatar || '/static/avatar1.png'}
                                    alt={app.applicant_name || '用户'}
                                    style={{
                                      width: '32px',
                                      height: '32px',
                                      borderRadius: '50%',
                                      objectFit: 'cover'
                                    }}
                                  />
                                  <div style={{ flex: 1 }}>
                                    <div style={{ fontWeight: 600, fontSize: '14px' }}>
                                      {app.applicant_name || '用户'}
                                    </div>
                                    <div style={{ fontSize: '12px', color: '#6b7280' }}>
                                      {dayjs(app.created_at).format('MM-DD HH:mm')}
                                    </div>
                                  </div>
                                </div>
                                {app.message && (
                                  <div style={{
                                    fontSize: '13px',
                                    color: '#374151',
                                    marginBottom: '8px',
                                    lineHeight: '1.5'
                                  }}>
                                    {app.message}
                                  </div>
                                )}
                                {app.negotiated_price && (
                                  <div style={{
                                    fontSize: '13px',
                                    fontWeight: 600,
                                    color: '#92400e',
                                    padding: '4px 8px',
                                    background: '#fef3c7',
                                    borderRadius: '4px',
                                    display: 'inline-block',
                                    marginBottom: '8px'
                                  }}>
                                    议价: {app.negotiated_price} {app.currency || 'CNY'}
                                  </div>
                                )}
                                {activeTask?.poster_id === user?.id && (
                                  <div style={{
                                    display: 'flex',
                                    gap: '8px',
                                    marginTop: '8px'
                                  }}>
                                    <button
                                      onClick={async (e) => {
                                        e.stopPropagation();
                                        try {
                                          await acceptApplication(activeTaskId, app.id);
                                          alert('已接受申请');
                                          await loadTaskMessages(activeTaskId);
                                          await loadApplications(activeTaskId);
                                          await loadTasks();
                                        } catch (error: any) {
                                          console.error('接受申请失败:', error);
                                          alert(error.response?.data?.detail || '接受申请失败，请重试');
                                        }
                                      }}
                                      style={{
                                        flex: 1,
                                        padding: '6px 12px',
                                        background: '#10b981',
                                        color: 'white',
                                        border: 'none',
                                        borderRadius: '6px',
                                        cursor: 'pointer',
                                        fontSize: '12px',
                                        fontWeight: 600
                                      }}
                                    >
                                      接受
                                    </button>
                                    <button
                                      onClick={async (e) => {
                                        e.stopPropagation();
                                        try {
                                          await rejectApplication(activeTaskId, app.id);
                                          alert('已拒绝申请');
                                          await loadApplications(activeTaskId);
                                        } catch (error: any) {
                                          console.error('拒绝申请失败:', error);
                                          alert(error.response?.data?.detail || '拒绝申请失败，请重试');
                                        }
                                      }}
                                      style={{
                                        flex: 1,
                                        padding: '6px 12px',
                                        background: '#ef4444',
                                        color: 'white',
                                        border: 'none',
                                        borderRadius: '6px',
                                        cursor: 'pointer',
                                        fontSize: '12px',
                                        fontWeight: 600
                                      }}
                                    >
                                      拒绝
                                    </button>
                                  </div>
                                )}
                              </div>
                            ))}
                            {applications.length > 3 && (
                              <div style={{ textAlign: 'center', marginTop: '8px' }}>
                                <button
                                  onClick={() => setShowApplicationListModal(true)}
                                  style={{
                                    padding: '6px 12px',
                                    background: 'transparent',
                                    color: '#3b82f6',
                                    border: '1px solid #3b82f6',
                                    borderRadius: '6px',
                                    cursor: 'pointer',
                                    fontSize: '13px'
                                  }}
                                >
                                  查看更多 ({applications.length - 3} 个)
                                </button>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    ) : (
                      <div>
                        {applications.some((app: any) => app.applicant_id === user?.id) ? (
                          <div style={{
                            padding: '12px',
                            background: '#ecfdf5',
                            borderRadius: '8px',
                            border: '1px solid #10b981',
                            textAlign: 'center',
                            color: '#059669',
                            fontWeight: 600
                          }}>
                            ✓ 您已申请此任务
                          </div>
                        ) : (
                          <button
                            onClick={() => setShowApplicationModal(true)}
                            style={{
                              width: '100%',
                              padding: '12px',
                              backgroundColor: '#3b82f6',
                              color: 'white',
                              border: 'none',
                              borderRadius: '8px',
                              cursor: 'pointer',
                              fontSize: '16px',
                              fontWeight: 600,
                              transition: 'all 0.2s ease'
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.backgroundColor = '#2563eb';
                              e.currentTarget.style.transform = 'translateY(-1px)';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.backgroundColor = '#3b82f6';
                              e.currentTarget.style.transform = 'translateY(0)';
                            }}
                          >
                            申请任务
                          </button>
                        )}
                      </div>
                    )}
                  </div>
                )}

                {/* 加载更多消息按钮 */}
                {taskHasMore && (
                  <div style={{ textAlign: 'center', marginBottom: '16px', padding: '16px' }}>
                    <button
                      onClick={() => loadTaskMessages(activeTaskId, taskNextCursor)}
                      disabled={taskMessagesLoading}
                      style={{
                        padding: '8px 16px',
                        backgroundColor: 'white',
                        border: '1px solid #e5e7eb',
                        borderRadius: '6px',
                        cursor: taskMessagesLoading ? 'not-allowed' : 'pointer',
                        fontSize: '14px'
                      }}
                    >
                      {taskMessagesLoading ? '加载中...' : '加载更多'}
                    </button>
                  </div>
                )}

                {/* 任务消息加载状态 */}
                {taskMessagesLoading && taskMessages.length === 0 && (
                  <div style={{ textAlign: 'center', padding: '40px', color: '#6b7280' }}>
                    <div style={{ fontSize: '24px', marginBottom: '12px' }}>⏳</div>
                    加载消息中...
                  </div>
                )}

                {/* 任务消息列表 */}
                {taskMessages.length === 0 && !taskMessagesLoading && (
                  <div style={{ textAlign: 'center', padding: '40px', color: '#6b7280' }}>
                    <div style={{ fontSize: '48px', marginBottom: '12px', opacity: 0.3 }}>💬</div>
                    暂无消息，开始对话吧
                  </div>
                )}

                {taskMessages.map((msg, idx) => {
                  const isOwn = msg.sender_id === user?.id;
                  // 显示头像的条件：第一条消息，或者上一条消息的发送者不同
                  const showAvatar = idx === 0 || (taskMessages[idx - 1] && taskMessages[idx - 1].sender_id !== msg.sender_id);
                  
                  return (
                    <div
                      key={msg.id}
                      style={{
                        display: 'flex',
                        marginBottom: '12px',
                        padding: '0 16px',
                        justifyContent: isOwn ? 'flex-end' : 'flex-start'
                      }}
                    >
                      {!isOwn && showAvatar && (
                        <img
                          src={msg.sender_avatar || '/default-avatar.png'}
                          alt={msg.sender_name || '用户'}
                          onClick={() => {
                            if (msg.sender_id) {
                              navigate(`/user/${msg.sender_id}`);
                            }
                          }}
                          style={{
                            width: '32px',
                            height: '32px',
                            borderRadius: '50%',
                            marginRight: '8px',
                            objectFit: 'cover',
                            cursor: 'pointer',
                            transition: 'transform 0.2s'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.transform = 'scale(1.1)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.transform = 'scale(1)';
                          }}
                        />
                      )}
                      {!isOwn && !showAvatar && <div style={{ width: '40px' }} />}
                      
                      <div style={{
                        maxWidth: '70%',
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: isOwn ? 'flex-end' : 'flex-start'
                      }}>
                        {showAvatar && (
                          <div 
                            onClick={() => {
                              if (msg.sender_id) {
                                navigate(`/user/${msg.sender_id}`);
                              }
                            }}
                            style={{ 
                              fontSize: '12px', 
                              color: '#6b7280', 
                              marginBottom: '4px',
                              cursor: 'pointer',
                              textDecoration: 'underline'
                            }}
                          >
                            {msg.sender_name}
                          </div>
                        )}
                        <div style={{
                          padding: '8px 12px',
                          borderRadius: '12px',
                          backgroundColor: isOwn ? '#3b82f6' : 'white',
                          color: isOwn ? 'white' : '#1f2937',
                          fontSize: '14px',
                          wordBreak: 'break-word',
                          boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                        }}>
                          {msg.content}
                          {msg.attachments && msg.attachments.length > 0 && (
                            <div style={{ marginTop: '8px' }}>
                              {msg.attachments.map((att: any) => (
                                <div key={att.id} style={{ marginTop: '4px' }}>
                                  {att.attachment_type === 'image' && (att.url || att.blob_id) && (
                                    <img
                                      src={att.url || `/api/blobs/${att.blob_id}`}
                                      alt="图片附件"
                                      style={{ maxWidth: '200px', borderRadius: '6px', cursor: 'pointer' }}
                                      onClick={() => {
                                        setPreviewImageUrl(att.url || `/api/blobs/${att.blob_id}`);
                                        setShowImagePreview(true);
                                      }}
                                    />
                                  )}
                                  {att.attachment_type === 'file' && (att.url || att.blob_id) && (
                                    <div style={{
                                      padding: '8px 12px',
                                      background: '#f3f4f6',
                                      borderRadius: '6px',
                                      display: 'flex',
                                      alignItems: 'center',
                                      gap: '8px'
                                    }}>
                                      <span style={{ fontSize: '20px' }}>📎</span>
                                      <a
                                        href={att.url || `/api/blobs/${att.blob_id}`}
                                        download
                                        style={{
                                          color: '#3b82f6',
                                          textDecoration: 'none',
                                          fontSize: '13px'
                                        }}
                                        onMouseEnter={(e) => {
                                          e.currentTarget.style.textDecoration = 'underline';
                                        }}
                                        onMouseLeave={(e) => {
                                          e.currentTarget.style.textDecoration = 'none';
                                        }}
                                      >
                                        {att.meta?.filename || '下载文件'}
                                      </a>
                                    </div>
                                  )}
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                        <div style={{
                          fontSize: '11px',
                          color: '#9ca3af',
                          marginTop: '4px',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px'
                        }}>
                          {dayjs(msg.created_at).format('HH:mm')}
                          {!isOwn && msg.is_read !== undefined && !msg.is_read && (
                            <span style={{
                              padding: '2px 6px',
                              background: '#fef3c7',
                              color: '#92400e',
                              borderRadius: '4px',
                              fontSize: '10px',
                              fontWeight: 600
                            }}>未读</span>
                          )}
                          {!isOwn && msg.is_read && (
                            <span style={{
                              color: '#10b981',
                              fontSize: '10px'
                            }}>✓ 已读</span>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
                <div ref={messagesEndRef} />
              </>
            )}

            {/* 客服消息显示 */}
            {isServiceMode && messages.length > 0 && messages.map((msg, idx) => {
              const systemText = t('messages.system');
              const meText = t('messages.me');
              const isSystemMessage = msg.from === systemText;
              const isImageMessage = msg.content.startsWith('[图片]');
              const isFileMessage = msg.content.startsWith('[文件]');
              
              return (
                <div
                  key={msg.id || idx}
                  style={{
                    display: 'flex',
                    justifyContent: msg.from === meText ? 'flex-end' : 'flex-start',
                    marginBottom: '16px',
                    padding: '0 16px'
                  }}
                >
                  <div style={{
                    maxWidth: '70%',
                    background: msg.from === meText ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' : '#fff',
                    color: msg.from === meText ? '#fff' : '#1f2937',
                    padding: '12px 16px',
                    borderRadius: '18px',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                    wordBreak: 'break-word'
                  }}>
                    {isSystemMessage ? (
                      <div style={{ 
                        textAlign: 'center', 
                        color: '#6b7280', 
                        fontSize: '12px',
                        fontStyle: 'italic'
                      }}>
                        {msg.content}
                      </div>
                    ) : isImageMessage ? (
                      <img 
                        src={msg.content.replace('[图片]', '')} 
                        alt="图片" 
                        style={{ maxWidth: '200px', borderRadius: '8px' }}
                      />
                    ) : isFileMessage ? (
                      <div>
                        <div style={{ marginBottom: '8px' }}>{msg.content}</div>
                        <a 
                          href={msg.content.replace('[文件]', '')} 
                          download
                          style={{ 
                            color: msg.from === meText ? '#fff' : '#3b82f6',
                            textDecoration: 'underline'
                          }}
                        >
                          下载文件
                        </a>
                      </div>
                    ) : (
                      <div style={{ fontSize: '14px', lineHeight: '1.5' }}>
                        {msg.content}
                      </div>
                    )}
                    <div style={{ 
                      fontSize: '11px', 
                      color: msg.from === meText ? 'rgba(255,255,255,0.7)' : '#9ca3af',
                      marginTop: '4px',
                      textAlign: 'right'
                    }}>
                      {TimeHandlerV2.formatLastMessageTime(msg.created_at, userTimezone, t)}
                    </div>
                  </div>
                </div>
              );
            })}
            
            {/* 消息区域结束 */}
          </div>
          
          {/* 输入框区域 */}
          {isServiceMode ? (
            <div style={{
              padding: '16px 24px',
              borderTop: '1px solid #e2e8f0',
              background: 'white',
              display: 'flex',
              alignItems: 'center',
              gap: '12px'
            }}>
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyPress={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    handleSend();
                  }
                }}
                placeholder={serviceConnected ? t('messages.typeMessage') : t('messages.connectToChat')}
                disabled={!serviceConnected || isSending}
                style={{
                  flex: 1,
                  padding: '12px 16px',
                  border: '2px solid #e5e7eb',
                  borderRadius: '24px',
                  fontSize: '14px',
                  outline: 'none',
                  transition: 'border-color 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#e5e7eb';
                }}
              />
              <button
                onClick={handleSend}
                disabled={!serviceConnected || !input.trim() || isSending}
                style={{
                  padding: '12px 24px',
                  background: serviceConnected && input.trim() && !isSending
                    ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)'
                    : '#cbd5e1',
                  color: 'white',
                  border: 'none',
                  borderRadius: '24px',
                  fontSize: '14px',
                  fontWeight: 600,
                  cursor: serviceConnected && input.trim() && !isSending ? 'pointer' : 'not-allowed',
                  transition: 'all 0.2s ease'
                }}
              >
                {isSending ? '发送中...' : '发送'}
              </button>
            </div>
          ) : chatMode === 'tasks' && activeTaskId && activeTask ? (
            <div style={{
              padding: '16px 24px',
              borderTop: '1px solid #e2e8f0',
              background: 'white',
              display: 'flex',
              flexDirection: 'column',
              gap: '12px'
            }}>
              {/* 权限提示 */}
              {activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id && (
                <div style={{
                  padding: '12px',
                  background: '#fef3c7',
                  borderRadius: '8px',
                  fontSize: '14px',
                  color: '#92400e',
                  textAlign: 'center'
                }}>
                  任务开始后才能发送消息
                </div>
              )}
              
              {/* 输入框和按钮 */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '12px'
              }}>
                <input
                  type="text"
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyPress={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      if (!isSending && input.trim()) {
                        handleSendTaskMessage();
                      }
                    }
                  }}
                  placeholder={
                    activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id
                      ? '任务开始后才能发送消息'
                      : activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id === user?.id
                      ? '可以发送说明类消息（用于需求澄清）'
                      : '输入消息...'
                  }
                  disabled={
                    (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                    isSending
                  }
                  style={{
                    flex: 1,
                    padding: '12px 16px',
                    border: '2px solid #e5e7eb',
                    borderRadius: '24px',
                    fontSize: '14px',
                    outline: 'none',
                    transition: 'border-color 0.2s ease',
                    opacity: (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ? 0.5 : 1
                  }}
                  onFocus={(e) => {
                    if (!e.target.disabled) {
                      e.target.style.borderColor = '#3b82f6';
                    }
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#e5e7eb';
                  }}
                />
                <button
                  onClick={handleSendTaskMessage}
                  disabled={
                    (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                    !input.trim() ||
                    isSending
                  }
                  style={{
                    padding: '12px 24px',
                    background: (
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      !input.trim() ||
                      isSending
                    ) ? '#cbd5e1' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                    color: 'white',
                    border: 'none',
                    borderRadius: '24px',
                    fontSize: '14px',
                    fontWeight: 600,
                    cursor: (
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      !input.trim() ||
                      isSending
                    ) ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s ease'
                  }}
                >
                  {isSending ? '发送中...' : '发送'}
                </button>
              </div>
            </div>
          ) : null}
        </div>
      </div>

      {/* 评价弹窗和其他弹窗 */}
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

      {/* 申请任务弹窗 */}
      {showApplicationModal && activeTaskId && (
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
        onClick={() => setShowApplicationModal(false)}
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
                value={applicationMessage}
                onChange={(e) => setApplicationMessage(e.target.value)}
                placeholder="请输入申请留言..."
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
                  checked={negotiatedPrice !== undefined}
                  onChange={(e) => {
                    if (!e.target.checked) {
                      setNegotiatedPrice(undefined);
                    }
                  }}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span>我想议价</span>
              </label>
              
              {negotiatedPrice !== undefined && (
                <div style={{ marginTop: '12px' }}>
                  <label style={{
                    display: 'block',
                    marginBottom: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    color: '#374151'
                  }}>
                    议价金额
                  </label>
                  <input
                    type="number"
                    value={negotiatedPrice || ''}
                    onChange={(e) => {
                      const value = e.target.value ? parseFloat(e.target.value) : undefined;
                      setNegotiatedPrice(value);
                    }}
                    placeholder="请输入议价金额"
                    min="0"
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
                  setShowApplicationModal(false);
                  setApplicationMessage('');
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
                取消
              </button>
              <button
                onClick={async () => {
                  try {
                    await applyForTask(
                      activeTaskId,
                      applicationMessage || undefined,
                      negotiatedPrice,
                      activeTask?.currency || 'CNY'
                    );
                    setShowApplicationModal(false);
                    setApplicationMessage('');
                    setNegotiatedPrice(undefined);
                    // 重新加载申请列表
                    if (activeTaskId) {
                      await loadApplications(activeTaskId);
                    }
                    alert('申请提交成功！');
                  } catch (error: any) {
                    console.error('申请失败:', error);
                    alert(error.response?.data?.detail || '申请失败，请重试');
                  }
                }}
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
                提交申请
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 申请列表弹窗 */}
      {showApplicationListModal && activeTaskId && (
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
        onClick={() => setShowApplicationListModal(false)}
        >
          <div style={{
            background: '#fff',
            borderRadius: '16px',
            padding: '24px',
            maxWidth: '600px',
            width: '100%',
            maxHeight: '90vh',
            overflowY: 'auto',
            boxShadow: '0 20px 60px rgba(0,0,0,0.3)'
          }}
          onClick={(e) => e.stopPropagation()}
          >
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '20px'
            }}>
              <h3 style={{ margin: 0, fontSize: '20px', fontWeight: 600 }}>申请列表</h3>
              <button
                onClick={() => setShowApplicationListModal(false)}
                style={{
                  background: 'none',
                  border: 'none',
                  fontSize: '24px',
                  cursor: 'pointer',
                  color: '#6b7280',
                  padding: '0',
                  width: '32px',
                  height: '32px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  borderRadius: '50%',
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
                ×
              </button>
            </div>

            {applicationsLoading ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : applications.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px', color: '#6b7280' }}>
                暂无申请
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {applications.map((app: any) => (
                  <div
                    key={app.id}
                    style={{
                      padding: '16px',
                      border: '1px solid #e5e7eb',
                      borderRadius: '12px',
                      background: '#f9fafb'
                    }}
                  >
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '12px',
                      marginBottom: '12px'
                    }}>
                      <img
                        src={app.applicant_avatar || '/static/avatar1.png'}
                        alt={app.applicant_name || '用户'}
                        style={{
                          width: '40px',
                          height: '40px',
                          borderRadius: '50%',
                          objectFit: 'cover'
                        }}
                      />
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 600, fontSize: '16px' }}>
                          {app.applicant_name || '用户'}
                        </div>
                        <div style={{ fontSize: '12px', color: '#6b7280' }}>
                          {dayjs(app.created_at).format('YYYY-MM-DD HH:mm')}
                        </div>
                      </div>
                    </div>
                    
                    {app.message && (
                      <div style={{
                        marginBottom: '12px',
                        padding: '12px',
                        background: 'white',
                        borderRadius: '8px',
                        fontSize: '14px',
                        color: '#374151',
                        lineHeight: '1.6'
                      }}>
                        {app.message}
                      </div>
                    )}

                    {app.negotiated_price && (
                      <div style={{
                        marginBottom: '12px',
                        padding: '8px 12px',
                        background: '#fef3c7',
                        borderRadius: '6px',
                        fontSize: '14px',
                        fontWeight: 600,
                        color: '#92400e'
                      }}>
                        议价金额: {app.negotiated_price} {app.currency || 'CNY'}
                      </div>
                    )}

                    {activeTask?.poster_id === user?.id && (
                      <div style={{
                        display: 'flex',
                        gap: '8px',
                        marginTop: '12px'
                      }}>
                        <button
                          onClick={async () => {
                            try {
                              await acceptApplication(activeTaskId, app.id);
                              alert('已接受申请');
                              setShowApplicationListModal(false);
                              // 重新加载任务和申请列表
                              if (activeTaskId) {
                                await loadTaskMessages(activeTaskId);
                                await loadApplications(activeTaskId);
                                await loadTasks();
                              }
                            } catch (error: any) {
                              console.error('接受申请失败:', error);
                              alert(error.response?.data?.detail || '接受申请失败，请重试');
                            }
                          }}
                          style={{
                            flex: 1,
                            padding: '8px 16px',
                            background: '#10b981',
                            color: 'white',
                            border: 'none',
                            borderRadius: '6px',
                            fontSize: '14px',
                            fontWeight: 600,
                            cursor: 'pointer',
                            transition: 'all 0.2s ease'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#059669';
                            e.currentTarget.style.transform = 'translateY(-1px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#10b981';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          接受
                        </button>
                        <button
                          onClick={async () => {
                            try {
                              await rejectApplication(activeTaskId, app.id);
                              alert('已拒绝申请');
                              // 重新加载申请列表
                              if (activeTaskId) {
                                await loadApplications(activeTaskId);
                              }
                            } catch (error: any) {
                              console.error('拒绝申请失败:', error);
                              alert(error.response?.data?.detail || '拒绝申请失败，请重试');
                            }
                          }}
                          style={{
                            flex: 1,
                            padding: '8px 16px',
                            background: '#ef4444',
                            color: 'white',
                            border: 'none',
                            borderRadius: '6px',
                            fontSize: '14px',
                            fontWeight: 600,
                            cursor: 'pointer',
                            transition: 'all 0.2s ease'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#dc2626';
                            e.currentTarget.style.transform = 'translateY(-1px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#ef4444';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          拒绝
                        </button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

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
