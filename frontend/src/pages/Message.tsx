import React, { useEffect, useRef, useState, useCallback, useMemo, memo } from 'react';
import { message } from 'antd';
import { API_BASE_URL, WS_BASE_URL } from '../config';
import api, { 
  fetchCurrentUser, 
  assignCustomerService, 
  checkCustomerServiceAvailability, 
  // 任务聊天相关API
  getTaskChatList,
  getTaskMessages,
  sendTaskMessage,
  markTaskMessagesRead,
  getTaskApplicationsWithFilter,
  acceptApplication,
  rejectApplication,
  sendApplicationMessage,
  applyForTask,
  // 任务操作相关API
  confirmTaskCompletion,
  getTaskReviews
} from '../api';
import { useLocation } from 'react-router-dom';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LazyImage from '../components/LazyImage';
import { getErrorMessage } from '../utils/errorHandler';
import { obfuscateLocation } from '../utils/formatUtils';
import { ensureAbsoluteImageUrl } from '../utils/imageUtils';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
// PaymentModal 已移除，统一使用 TaskPayment 页面进行支付
import CompleteTaskModal from '../components/CompleteTaskModal';
import { useLanguage } from '../contexts/LanguageContext';
import { useTranslation } from '../hooks/useTranslation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import TaskTitle from '../components/TaskTitle';
import SEOHead from '../components/SEOHead';
import styles from './Message.module.css';

// 私密图片显示组件
const PrivateImageDisplay: React.FC<{
  imageId: string;
  currentUserId: string;
  style?: React.CSSProperties;
  className?: string;
  alt?: string;
  onClick?: () => void;
}> = ({ imageId, currentUserId, style, className, alt = "Private Image", onClick }) => {
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

  // 合并样式，处理 style 为 undefined 的情况
  const mergedStyle: React.CSSProperties = {
    ...(style || {}),
    width: style?.width || style?.maxWidth || '150px',
    height: style?.height || style?.maxHeight || '150px',
  };

  if (loading) {
    return (
      <div 
        className={styles.privateImageLoading}
        style={mergedStyle}
      >
        <div style={{ fontSize: '14px' }}>Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div 
        className={styles.privateImageError}
        style={mergedStyle}
      >
        <div className={styles.privateImageErrorIcon}>🔒</div>
        <div className={styles.privateImageErrorTitle}>
          Failed
        </div>
        <div className={styles.privateImageErrorText}>
          Error
        </div>
      </div>
    );
  }

  return (
    <LazyImage 
      src={imageUrl} 
      alt={alt} 
      className={className}
      style={{
        ...mergedStyle,
        objectFit: style?.objectFit || 'contain',
        display: 'block',
        flexShrink: 0
      }}
      onClick={onClick}
      onError={() => {
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
  message_type?: string; // 'text' | 'task_card' | 'image' | 'file'
  task_id?: number; // 任务卡片消息的任务ID
  image_id?: string; // 图片消息的 image_id（后端可能直接返回）
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

// 任务类型列表（用于获取emoji图标）
const TASK_TYPES = [
  "Housekeeping",
  "Campus Life",
  "Second-hand & Rental",
  "Errand Running",
  "Skill Service",
  "Social Help",
  "Transportation",
  "Pet Care",
  "Life Convenience",
  "Other"
];

// 获取任务类型的emoji图标
const getTaskTypeEmoji = (taskType: string): string => {
  const emojiList = ['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'];
  const index = TASK_TYPES.indexOf(taskType);
  return index >= 0 ? (emojiList[index] ?? '📋') : '📋';
};

// 获取任务图片URL（处理私密图片和公开图片）
const getTaskImageUrl = (imageValue: string | null | undefined, baseUrl?: string): string | null => {
  if (!imageValue) return null;
  
  const imageStr = String(imageValue);
  
  // 如果已经是完整的URL（包含 http:// 或 https://），直接返回
  if (imageStr.startsWith('http://') || imageStr.startsWith('https://')) {
    return imageStr;
  }
  
  // 如果包含 /api/private-image/，说明是私密图片URL，需要添加base URL
  if (imageStr.includes('/api/private-image/')) {
    if (imageStr.startsWith('/')) {
      // 相对路径，添加base URL
      return baseUrl ? `${baseUrl}${imageStr}` : imageStr;
    }
    return imageStr;
  }
  
  // 如果是相对路径（以 / 开头），添加base URL
  if (imageStr.startsWith('/')) {
    return baseUrl ? `${baseUrl}${imageStr}` : imageStr;
  }
  
  // 其他情况（含 CDN 无协议 URL）标准化后返回
  return ensureAbsoluteImageUrl(imageStr);
};

// 优化的任务列表项组件
interface TaskListItemProps {
  task: any;
  isActive: boolean;
  isMobile: boolean;
  onTaskClick: (taskId: number) => void;
  onRemoveTask: (taskId: number) => void;
}

const TaskListItem = memo<TaskListItemProps>(({ task, isActive, isMobile: _isMobile, onTaskClick, onRemoveTask }) => {
  void _isMobile;
  const { t, language } = useLanguage();
  
  const handleClick = useCallback(() => {
    onTaskClick(task.id);
  }, [task.id, onTaskClick]);

  const handleRemoveClick = useCallback((e: React.MouseEvent<HTMLButtonElement>) => {
    e.stopPropagation();
    if (window.confirm(t('messages.notifications.removeCompletedTask'))) {
      onRemoveTask(task.id);
    }
  }, [task.id, onRemoveTask, t]);

  const taskImageUrl = useMemo(() => {
    if (task.images && Array.isArray(task.images) && task.images.length > 0 && task.images[0]) {
      return getTaskImageUrl(task.images[0], API_BASE_URL) || task.images[0];
    }
    return null;
  }, [task.images]);

  const taskTypeEmoji = useMemo(() => getTaskTypeEmoji(task.task_type), [task.task_type]);

  const lastMessageTime = useMemo(() => {
    if (task.last_message) {
      return dayjs(task.last_message.created_at).format('HH:mm');
    }
    return null;
  }, [task.last_message]);

  const handleImageError = useCallback((e: React.SyntheticEvent<HTMLImageElement>) => {
    e.currentTarget.style.display = 'none';
    const placeholder = e.currentTarget.nextElementSibling as HTMLElement;
    if (placeholder) {
      placeholder.style.display = 'flex';
    }
  }, []);

  const handleMouseEnter = useCallback((e: React.MouseEvent<HTMLButtonElement>) => {
    e.currentTarget.style.background = '#fee2e2';
  }, []);

  const handleMouseLeave = useCallback((e: React.MouseEvent<HTMLButtonElement>) => {
    e.currentTarget.style.background = 'transparent';
  }, []);

  return (
    <div 
      onClick={handleClick} 
      className={`${styles.taskListItem} ${isActive ? styles.taskListItemActive : ''}`}
    >
      <div className={styles.taskListItemContent}>
        {/* 任务图片容器 */}
        <div className={styles.taskImageContainer}>
          {/* 任务图片 - 优先使用第一张任务图片，否则使用任务类型图片 */}
          {taskImageUrl ? (
            <LazyImage
              src={taskImageUrl}
              alt={task.title}
              className={styles.taskImage}
              width={50}
              height={50}
              onError={handleImageError}
            />
          ) : (
            <div className={styles.taskImagePlaceholder}>
              {taskTypeEmoji}
            </div>
          )}
          {/* 占位符（仅在任务图片加载失败时显示） */}
          <div 
            className={styles.taskImagePlaceholder}
            style={{
              display: 'none',
              position: 'absolute',
              top: 0,
              left: 0
            }}
          >
            {taskTypeEmoji}
          </div>
        </div>
        <div className={styles.taskInfo}>
          <div className={styles.taskTitle}>
            <TaskTitle
              title={task.title}
              language={language}
              taskId={task.id}
              task={task}
              autoTranslate={true}
            />
          </div>
          {task.last_message && (
            <div className={styles.taskDescription}>
              {task.last_message.sender_name}: {task.last_message.content}
            </div>
          )}
        </div>
        <div className={styles.taskMeta}>
          {task.status === 'completed' && (
            <button
              onClick={handleRemoveClick}
              className={styles.deleteButton}
              onMouseEnter={handleMouseEnter}
              onMouseLeave={handleMouseLeave}
              title="从列表中移除"
            >
              ❌
            </button>
          )}
          {task.unread_count > 0 && (
            <div className={styles.unreadBadge} style={{ minWidth: '20px', textAlign: 'center' }}>
              {task.unread_count}
            </div>
          )}
          {lastMessageTime && (
            <div className={styles.taskTime}>
              {lastMessageTime}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}, (prevProps, nextProps) => {
  // 自定义比较函数，只在关键属性变化时重新渲染
  // 如果返回 true，表示 props 相同，跳过重新渲染
  // 如果返回 false，表示 props 不同，需要重新渲染
  if (prevProps.task.id !== nextProps.task.id) return false;
  if (prevProps.task.title !== nextProps.task.title) return false;
  if (prevProps.task.status !== nextProps.task.status) return false;
  if (prevProps.task.unread_count !== nextProps.task.unread_count) return false;
  if (prevProps.task.task_type !== nextProps.task.task_type) return false;
  if (prevProps.isActive !== nextProps.isActive) return false;
  if (prevProps.isMobile !== nextProps.isMobile) return false;
  
  // 比较 last_message
  const prevMsg = prevProps.task.last_message;
  const nextMsg = nextProps.task.last_message;
  if (!!prevMsg !== !!nextMsg) return false; // 一个存在一个不存在
  if (prevMsg && nextMsg) {
    if (prevMsg.content !== nextMsg.content) return false;
    if (prevMsg.created_at !== nextMsg.created_at) return false;
    if (prevMsg.sender_name !== nextMsg.sender_name) return false;
  }
  
  // 比较 images（简单比较数组长度和第一个元素）
  const prevImages = prevProps.task.images;
  const nextImages = nextProps.task.images;
  if (!!prevImages !== !!nextImages) return false;
  if (Array.isArray(prevImages) && Array.isArray(nextImages)) {
    if (prevImages.length !== nextImages.length) return false;
    if (prevImages.length > 0 && prevImages[0] !== nextImages[0]) return false;
  }
  
  return true; // 所有关键属性都相同，跳过重新渲染
});

TaskListItem.displayName = 'TaskListItem';

const MessagePage: React.FC = () => {
  const { t, language } = useLanguage();
  const { unreadCount: globalUnreadCount, refreshUnreadCount } = useUnreadMessages();
  
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
      @keyframes slideDown {
        0% {
          opacity: 0;
          transform: translateX(-50%) translateY(-20px);
        }
        100% {
          opacity: 1;
          transform: translateX(-50%) translateY(0);
        }
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
  const [ratingSelectedTags, setRatingSelectedTags] = useState<string[]>([]);
  const [ratingHoverRating, setRatingHoverRating] = useState(0);
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
  const [, setServiceAvailable] = useState<boolean>(false);
  const [, setServiceStatusLoading] = useState<boolean>(true);
  void setServiceAvailable;
  void setServiceStatusLoading;
  const [isMobile, setIsMobile] = useState(false);
  const [showMobileChat, setShowMobileChat] = useState(false); // 移动端是否显示聊天框
  
  // 任务卡片相关状态
  const [userTasks, setUserTasks] = useState<any[]>([]);
  const [userTasksLoading, setUserTasksLoading] = useState(false);
  const [showTaskCardModal, setShowTaskCardModal] = useState(false);
  
  // 任务聊天相关状态
  const [chatMode, setChatMode] = useState<'tasks'>('tasks');
  void setChatMode;
  const [tasks, setTasks] = useState<any[]>([]); // 任务列表
  const [tasksLoading, setTasksLoading] = useState(false);
  const [taskSearchTerm, setTaskSearchTerm] = useState(''); // 任务搜索关键词
  const [activeTaskId, setActiveTaskId] = useState<number | null>(null);
  const [activeTask, setActiveTask] = useState<any>(null);
  const [taskMessages, setTaskMessages] = useState<any[]>([]); // 任务消息
  const [taskMessagesLoading, setTaskMessagesLoading] = useState(false);
  const [taskNextCursor, setTaskNextCursor] = useState<string | null>(null);
  const [taskHasMore, setTaskHasMore] = useState(false);
  const [applications, setApplications] = useState<any[]>([]); // 申请列表
  const [applicationsLoading, setApplicationsLoading] = useState(false);
  // 任务操作相关状态
  const [actionLoading, setActionLoading] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [hoverRating, setHoverRating] = useState(0);
  const [reviewComment, setReviewComment] = useState('');
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [taskReviews, setTaskReviews] = useState<any[]>([]); // 任务评价列表
  const [showApplicationModal, setShowApplicationModal] = useState(false);
  const [showApplicationListModal, setShowApplicationListModal] = useState(false);
  const [showTaskDetailModal, setShowTaskDetailModal] = useState(false);
  // PaymentModal 相关状态已移除，统一使用 TaskPayment 页面
  const [showCompleteTaskModal, setShowCompleteTaskModal] = useState(false);
  const [applicationMessage, setApplicationMessage] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState<number | undefined>();
  const [isNegotiateChecked, setIsNegotiateChecked] = useState(false);
  // 留言相关状态
  const [showMessageModal, setShowMessageModal] = useState(false);
  const [selectedApplication, setSelectedApplication] = useState<any>(null);
  const [messageContent, setMessageContent] = useState('');
  const [messageNegotiatedPrice, setMessageNegotiatedPrice] = useState<number | undefined>();
  const [isMessageNegotiateChecked, setIsMessageNegotiateChecked] = useState(false);
  
  // UX优化相关状态
  const [isNearBottom, setIsNearBottom] = useState(true); // 用户是否接近底部
  const [showScrollToBottom, setShowScrollToBottom] = useState(false); // 显示"滚动到底部"按钮
  const [hasNewTaskMessages, setHasNewTaskMessages] = useState(false); // 是否有新任务消息（当用户不在底部时）
  const lastTaskMessageIdRef = useRef<number | null>(null); // 最后一条任务消息的ID（使用ref避免依赖循环）
  const loadTasksRef = useRef<(() => Promise<void>) | null>(null); // 存储 loadTasks 函数引用
  const loadTaskMessagesRef = useRef<((taskId: number, cursor?: string | null) => Promise<void>) | null>(null); // 存储 loadTaskMessages 函数引用
  const [toastMessage, setToastMessage] = useState<{type: 'success' | 'error' | 'info', text: string} | null>(null); // Toast通知
  const messagesContainerRef = useRef<HTMLDivElement>(null); // 消息容器引用
  const inputAreaRef = useRef<HTMLDivElement>(null); // 输入框区域引用（客服模式）
  const taskInputAreaRef = useRef<HTMLDivElement>(null); // 任务聊天输入框区域引用
  const [scrollButtonBottom, setScrollButtonBottom] = useState(100); // 滚动按钮距离底部的位置（客服模式）
  const [taskScrollButtonBottom, setTaskScrollButtonBottom] = useState(100); // 任务聊天滚动按钮距离底部的位置
  const [taskScrollButtonLeft, setTaskScrollButtonLeft] = useState<number | null>(null); // 任务聊天滚动按钮距离左侧的位置（相对于输入框居中）
  
  // 翻译相关状态（language 已在组件顶部通过 useLanguage() 获取）
  const { translate } = useTranslation();
  // 使用消息ID或内容+时间戳作为key
  const [messageTranslations, setMessageTranslations] = useState<Map<string, string>>(new Map());
  const [translatingMessages, setTranslatingMessages] = useState<Set<string>>(new Set());
  
  // 简单的语言检测：检查是否包含中文字符
  const detectTextLanguage = (text: string): 'zh' | 'en' => {
    if (!text || !text.trim()) return 'en';
    const hasChinese = /[\u4e00-\u9fff]/.test(text);
    return hasChinese ? 'zh' : 'en';
  };
  
  // 获取消息的唯一标识（与渲染时保持一致）
  const getMessageKey = (msg: Message): string => {
    // 与渲染时的key生成逻辑保持一致
    return `msg_${msg.id || msg.content}_${msg.created_at}`;
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
  const [showDebugPanel, setShowDebugPanel] = useState(false);
  const [debugInfo, setDebugInfo] = useState<any>(null);
  const [debugLoading, setDebugLoading] = useState(false);
  
  // 无限滚动相关状态
  const [loadingMoreMessages, setLoadingMoreMessages] = useState(false);
  void setLoadingMoreMessages;
  const [, setHasMoreMessages] = useState(true);
  const [, setCurrentPage] = useState(1);
  void setHasMoreMessages;
  void setCurrentPage;
  
  // 滚动控制状态
  const [, setShouldScrollToBottom] = useState(false);
  void setShouldScrollToBottom;
  const [showScrollToBottomButton, setShowScrollToBottomButton] = useState(false);
  
  // 发送状态
  const [isSending, setIsSending] = useState(false);

  const location = useLocation();
  const { navigate } = useLocalizedNavigation();

  // 从URL参数中获取任务ID（如果存在）
  useEffect(() => {
    const searchParams = new URLSearchParams(location.search);
    const taskIdParam = searchParams.get('taskId') || searchParams.get('task_id');
    if (taskIdParam) {
      const taskId = parseInt(taskIdParam, 10);
      if (!isNaN(taskId) && taskId !== activeTaskId) {
        setActiveTaskId(taskId);
      }
    }
    // 注意：不再处理 uid 参数，因为联系人聊天功能已移除
  }, [location.search, activeTaskId]);

  // 格式化时间为用户时区（未使用）
  const _formatTime = (timeString: string) => {
    try { return TimeHandlerV2.formatDetailedTime(timeString, userTimezone, t); } catch { return timeString; }
  };
  void _formatTime;

  // 添加表情到输入框
  const addEmoji = (emoji: string) => {
    setInput(prev => prev + emoji);
    setShowEmojiPicker(false);
  };

  // 处理图片选择
  const handleImageSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // 任务完成后禁止上传图片
      if (activeTask?.status === 'completed') {
        alert(t('messages.taskCannotSendImage'));
        event.target.value = ''; // 清空文件选择
        return;
      }
      
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
      // 任务完成后禁止上传文件
      if (activeTask?.status === 'completed') {
        alert(t('messages.taskCannotSendFile'));
        event.target.value = ''; // 清空文件选择
        return;
      }
      
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

  // 发送图片（支持任务聊天和客服聊天）
  const sendImage = async () => {
    if (!selectedImage) return;
    
    // 任务完成后禁止发送图片
    if (activeTask?.status === 'completed') {
      alert('任务已完成，无法发送图片');
      return;
    }
    
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
      
      // 根据聊天类型构建上传URL
      let uploadUrl: string;
      if (activeTaskId) {
        // 任务聊天：使用通用上传接口，传递task_id
        uploadUrl = `/api/upload/image?task_id=${activeTaskId}`;
      } else if (isServiceMode && currentChat?.chat_id) {
        // 客服聊天：使用专用文件上传接口（也支持图片）
        uploadUrl = `/api/user/customer-service/chats/${currentChat.chat_id}/files`;
      } else {
        // 默认使用通用上传接口
        uploadUrl = '/api/upload/image';
      }
      
      // 上传图片到服务器（使用api.post自动处理CSRF token）
      const uploadResponse = await api.post(uploadUrl, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      
      const uploadResult = uploadResponse.data;
      
      // 处理不同的响应格式（通用接口返回image_id，专用接口返回file_id）
      let imageId: string;
      if (uploadResult.image_id) {
        // 通用接口返回格式
        imageId = uploadResult.image_id;
      } else if (uploadResult.file_id) {
        // 专用接口返回格式
        imageId = uploadResult.file_id;
      } else {
        throw new Error('服务器未返回图片ID');
      }
      
      // 如果是客服模式，使用客服的发送方法（保持旧格式兼容）
      if (isServiceMode && currentChat) {
        const messageContent = `[图片] ${imageId}`;
        await sendImageMessage(messageContent);
      } else if (activeTaskId) {
        // 如果是任务聊天模式，使用任务消息发送，并正确构建附件数组
        const messageContent = `[图片]`;
        const attachments = [{
          attachment_type: 'image',
          blob_id: imageId,
          meta: {
            filename: selectedImage.name,
            size: selectedImage.size,
            mime_type: selectedImage.type
          }
        }];
        await sendTaskMessage(activeTaskId, messageContent, undefined, attachments);
        // 重新加载任务消息
        await loadTaskMessages(activeTaskId);
      }
      
      // 清除图片选择
      setSelectedImage(null);
      setImagePreview(null);
      setInput('');
      
    } catch (error) {
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
          
        const response = await fetch(`${API_BASE_URL}/api/user/customer-service/chats/${currentChat.chat_id}/messages`, {
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

  // 取消图片选择（未使用）
  const _cancelImageSelection = () => { setSelectedImage(null); setImagePreview(null); };
  void _cancelImageSelection;

  // 发送文件
  const sendFile = async () => {
    if (!selectedFile) return;
    
    // 任务完成后禁止发送文件
    if (activeTask?.status === 'completed') {
      alert(t('messages.taskCannotSendFile'));
      return;
    }
    
    setUploadingFile(true);
    
    try {
      const formData = new FormData();
      formData.append('file', selectedFile);
      
      // 构建上传URL，根据当前聊天类型添加 task_id 或 chat_id
      let uploadUrl: string;
      if (activeTaskId) {
        // 任务聊天：使用通用上传接口，传递 task_id
        uploadUrl = `${API_BASE_URL}/api/upload/file?task_id=${activeTaskId}`;
      } else if (currentChat?.chat_id) {
        // 客服聊天：使用专用文件上传接口
        uploadUrl = `${API_BASE_URL}/api/user/customer-service/chats/${currentChat.chat_id}/files`;
      } else {
        // 默认使用通用上传接口
        uploadUrl = `${API_BASE_URL}/api/upload/file`;
      }
      
      // 上传文件到服务器
      const uploadResponse = await fetch(uploadUrl, {
        method: 'POST',
        credentials: 'include',  // 使用Cookie认证
        body: formData
      });
      
      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text();
                throw new Error(`文件上传失败: ${uploadResponse.status} - ${errorText}`);
      }
      
      const uploadResult = await uploadResponse.json();
      
      // 处理不同的响应格式
      let fileUrl: string;
      let fileId: string | undefined;
      if (uploadResult.url) {
        fileUrl = uploadResult.url;
      } else if (uploadResult.file_url) {
        fileUrl = uploadResult.file_url;
      } else if (uploadResult.file_id) {
        // 如果返回的是file_id（blob_id），需要构建访问URL
        fileId = uploadResult.file_id;
        fileUrl = `/api/blobs/${fileId}`;
      } else {
        throw new Error('服务器未返回文件URL或ID');
      }
      
      // 如果是任务聊天模式，使用任务消息发送，并正确构建附件数组
      if (activeTaskId) {
        const messageContent = `[文件] ${selectedFile.name}`;
        const attachments = [{
          attachment_type: 'file',
          url: fileUrl,
          blob_id: fileId,
          meta: {
            filename: selectedFile.name,
            size: selectedFile.size,
            mime_type: selectedFile.type
          }
        }];
        await sendTaskMessage(activeTaskId, messageContent, undefined, attachments);
        // 重新加载任务消息
        await loadTaskMessages(activeTaskId);
      } else {
        // 其他情况保持旧格式
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
        } else {
          throw new Error('WebSocket未连接');
        }
      }
      
      // 清除文件选择
      setSelectedFile(null);
      setFilePreview(null);
      
    } catch (error) {
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
      
      // 根据聊天类型构建上传URL
      let uploadUrl: string;
      if (activeTaskId) {
        // 任务聊天：使用通用上传接口，传递task_id
        uploadUrl = `/api/upload/image?task_id=${activeTaskId}`;
      } else if (isServiceMode && currentChat?.chat_id) {
        // 客服聊天：使用专用文件上传接口（也支持图片）
        uploadUrl = `/api/user/customer-service/chats/${currentChat.chat_id}/files`;
      } else {
        // 默认使用通用上传接口
        uploadUrl = '/api/upload/image';
      }
      
      // 上传图片到服务器（使用api.post自动处理CSRF token）
      const uploadResponse = await api.post(uploadUrl, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      
      const uploadResult = uploadResponse.data;
      
      // 处理不同的响应格式（通用接口返回image_id，专用接口返回file_id）
      let imageId: string;
      if (uploadResult.image_id) {
        // 通用接口返回格式
        imageId = uploadResult.image_id;
      } else if (uploadResult.file_id) {
        // 专用接口返回格式
        imageId = uploadResult.file_id;
      } else {
        throw new Error('服务器未返回图片ID');
      }
      
      // 如果是客服模式，使用客服的发送方法（保持旧格式兼容）
      if (isServiceMode && currentChat) {
        const messageContent = `[图片] ${imageId}`;
        await sendImageMessage(messageContent);
      } else if (activeTaskId) {
        // 如果是任务聊天模式，使用任务消息发送，并正确构建附件数组
        const messageContent = `[图片]`;
        const attachments = [{
          attachment_type: 'image',
          blob_id: imageId,
          meta: {
            filename: selectedImage.name,
            size: selectedImage.size,
            mime_type: selectedImage.type
          }
        }];
        await sendTaskMessage(activeTaskId, messageContent, undefined, attachments);
        // 重新加载任务消息
        await loadTaskMessages(activeTaskId);
      }
      
      // 清空图片选择并关闭弹窗（移动端特有）
      setSelectedImage(null);
      setImagePreview(null);
      setShowMobileImageSendModal(false);
      setPreviewImageUrl('');
      setInput('');
    } catch (error) {
            alert(t('messages.sendImageFailed', { error: error instanceof Error ? error.message : String(error) }));
    } finally {
      setUploadingImage(false);
    }
  };

  // 取消文件选择（未使用）
  const _cancelFileSelection = () => { setSelectedFile(null); setFilePreview(null); };
  void _cancelFileSelection;

  // 渲染消息内容（支持图片，未使用）
  const _renderMessageContent = (content: string, message: any) => {
    // 检查是否是图片消息
    if (content.startsWith('[图片] ') || message.image_id) {
      const imageId = message.image_id || content.replace('[图片] ', '');
      
      
      return (
        <div className={styles.messageImageContainer}>
          <div className={styles.messageImageLabel}>
            📷 {t('messages.privateImage')}
            <span className={styles.messageImageBadge}>
              {t('messages.chatOnly')}
            </span>
          </div>
          <div className={styles.messageImageWrapper}>
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
        <div className={styles.messageFileContainer}>
          <div className={styles.messageFileLabel}>
            📎 {t('messages.file')}
          </div>
          <div 
            className={styles.messageFileCard}
            onClick={() => {
              if (fileUrl) {
                window.open(fileUrl, '_blank');
              }
            }}
          >
            <div className={styles.messageFileIcon}>📎</div>
            <div className={styles.messageFileInfo}>
              <div className={styles.messageFileName}>
                {fileName}
              </div>
              <div className={styles.messageFileHint}>
                {t('messages.clickToDownload')}
              </div>
            </div>
            <div className={styles.messageFileSize} style={{ opacity: 0.7 }}>
              →
            </div>
          </div>
        </div>
      );
    }
    
    // 普通文本消息
    return <div style={{ fontSize: 16 }}>{content}</div>;
  };
  void _renderMessageContent;

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
            
          const response = await fetch(`${API_BASE_URL}/api/user/customer-service/chats/${currentChat.chat_id}/messages`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
            },
            credentials: 'include',  // 使用Cookie认证
            body: JSON.stringify({ content: messageContent })
          });
          
          if (!response.ok) {
            throw new Error(t('messages.sendMessageFailedError'));
          }
        }
      }
      
    } catch (error) {
            alert(t('messages.sendMessageFailed'));
      setInput(messageContent); // 恢复输入内容
      // 移除失败的消息
      setMessages(prev => prev.filter(msg => msg.id !== newMessage.id));
    } finally {
      setIsSending(false);
    }
  };

  // 获取用户任务列表（用于发送任务卡片）
  const loadUserTasks = async () => {
    if (!user?.id) return;
    
    setUserTasksLoading(true);
    try {
      const response = await fetch(`${API_BASE_URL}/api/users/${user.id}/tasks?posted_limit=50&taken_limit=50`, {
        credentials: 'include'
      });
      
      if (response.ok) {
        const data = await response.json();
        // 合并发布和接受的任务
        const allTasks = [
          ...(data.posted_tasks || []),
          ...(data.taken_tasks || [])
        ];
        // 过滤掉已取消的任务
        const activeTasks = allTasks.filter((task: any) => task.status !== 'cancelled');
        setUserTasks(activeTasks);
      } else {
              }
    } catch (error) {
          } finally {
      setUserTasksLoading(false);
    }
  };
  
  // 发送任务卡片
  const sendTaskCard = async (taskId: number) => {
    if (isSending || !serviceConnected || !currentChat) {
      return;
    }
    
    setIsSending(true);
    
    // 检查客服对话是否已结束
    if (currentChat.is_ended === 1) {
      setIsSending(false);
      alert(t('messages.chatEndedAlert'));
      return;
    }
    
    const messageId = Date.now() + Math.floor(Math.random() * 1000);
    const userTimezone = TimeHandlerV2.getUserTimezone();
    
    // 立即添加消息到本地状态
    const newMessage: Message = {
      id: messageId,
      from: '我',
      content: '任务卡片',
      created_at: new Date().toISOString(),
      message_type: 'task_card',
      task_id: taskId
    };
    setMessages(prev => [...prev, newMessage]);
    setIsNewMessage(true);
    
    try {
      if (ws && ws.readyState === WebSocket.OPEN) {
        // 通过WebSocket发送任务卡片消息
        const messageData = {
          receiver_id: currentChat.service_id,
          content: `[TASK_CARD:${taskId}]`, // 特殊格式标识任务卡片
          chat_id: currentChat.chat_id,
          message_id: messageId,
          message_type: 'task_card',
          task_id: taskId,
          timezone: userTimezone,
          local_time: new Date().toLocaleString('en-GB', { timeZone: userTimezone })
        };
        ws.send(JSON.stringify(messageData));
      } else {
        // WebSocket未连接，使用HTTP API
        const csrfToken = document.cookie
          .split('; ')
          .find(row => row.startsWith('csrf_token='))
          ?.split('=')[1];
        
        const response = await fetch(`${API_BASE_URL}/api/user/customer-service/chats/${currentChat.chat_id}/messages`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
          },
          credentials: 'include',
          body: JSON.stringify({ 
            content: `[TASK_CARD:${taskId}]`,
            message_type: 'task_card',
            task_id: taskId
          })
        });
        
        if (!response.ok) {
          throw new Error('发送任务卡片失败');
        }
      }
      
      // 关闭任务选择弹窗
      setShowTaskCardModal(false);
      
    } catch (error) {
            alert('发送任务卡片失败');
      // 移除失败的消息
      setMessages(prev => prev.filter(msg => msg.id !== newMessage.id));
    } finally {
      setIsSending(false);
    }
  };
  
  // 检查是否接近底部（用于智能滚动）
  const checkIfNearBottom = useCallback(() => {
    if (!messagesContainerRef.current) return true;
    const container = messagesContainerRef.current;
    const { scrollTop, scrollHeight, clientHeight } = container;
    const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
    const nearBottom = distanceFromBottom < 150; // 150px内视为接近底部
    setIsNearBottom(nearBottom);
    setShowScrollToBottom(distanceFromBottom > 200);
    return nearBottom;
  }, []);

  // 智能滚动到底部（只在用户接近底部时滚动）
  const smartScrollToBottom = useCallback((force = false) => {
    if (force || isNearBottom) {
      setTimeout(() => {
        if (messagesEndRef.current) {
          messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
      }, 100);
    }
  }, [isNearBottom]);

  // 统一的滚动到底部函数（立即滚动，无动画）
  const scrollToBottomImmediate = useCallback((delay: number = 100, hideButton: boolean = true) => {
    setTimeout(() => {
      const messagesContainer = messagesContainerRef.current;
      if (messagesContainer) {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }
      if (messagesEndRef.current) {
        messagesEndRef.current.scrollIntoView({ behavior: 'auto' });
      }
      // 滚动后更新按钮状态
      if (hideButton) {
        setTimeout(() => {
          const container = messagesContainerRef.current;
          if (container) {
            const { scrollTop, scrollHeight, clientHeight } = container;
            const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
            // 如果已经滚动到底部，隐藏按钮
            if (distanceFromBottom < 200) {
              setShowScrollToBottomButton(false);
            }
          }
        }, 50);
      }
    }, delay);
  }, []);

  // 统一的滚动到底部函数（带平滑动画）
  const scrollToBottomSmooth = useCallback((delay: number = 150) => {
    setTimeout(() => {
      const messagesContainer = messagesContainerRef.current;
      if (messagesContainer) {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }
      if (messagesEndRef.current) {
        messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
      }
    }, delay);
  }, []);

  // Toast通知组件
  const showToast = useCallback((type: 'success' | 'error' | 'info', text: string) => {
    setToastMessage({ type, text });
    setTimeout(() => setToastMessage(null), 3000);
  }, []);

  // 发送任务消息（乐观更新）
  const handleSendTaskMessage = async () => {
    if (!activeTaskId || !input.trim() || isSending) return;
    
    // 任务完成后禁止发送消息
    if (activeTask?.status === 'completed') {
      showToast('error', t('messages.taskCannotSendMessage'));
      return;
    }
    
    const messageContent = input.trim();
    const tempId = Date.now(); // 临时ID
    
    // 乐观更新：立即显示消息
    const optimisticMessage = {
      id: tempId,
      sender_id: user?.id,
      sender_name: user?.name || '我',
      sender_avatar: user?.avatar,
      content: messageContent,
      created_at: new Date().toISOString(),
      is_read: false,
      attachments: [],
      isPending: true // 标记为待确认
    };
    
    setTaskMessages(prev => [...prev, optimisticMessage]);
    setInput('');
    setIsSending(true);
    
    // 如果用户接近底部，立即滚动
    if (isNearBottom) {
      smartScrollToBottom(true);
      setHasNewTaskMessages(false); // 清除新消息提示
    } else {
      // 如果用户不在底部，显示新消息提示（但这是自己发送的消息，不需要提示）
      // 新消息提示只在接收消息时显示
    }
    
    try {
      const response = await sendTaskMessage(
        activeTaskId,
        messageContent,
        undefined, // meta
        [] // attachments
      );
      
      // 用服务器返回的真实消息替换临时消息
      setTaskMessages(prev => prev.map(msg => 
        msg.id === tempId ? {
          ...response,
          sender_id: response.sender_id || user?.id,
          sender_name: response.sender_name || user?.name || '我',
          sender_avatar: response.sender_avatar || user?.avatar,
          isPending: false
        } : msg
      ));
      
      // 更新最后一条消息ID
      if (response.id) {
        lastTaskMessageIdRef.current = response.id;
        try {
          await markTaskMessagesRead(activeTaskId, response.id);
          // 标记已读后立即刷新未读计数
          await loadUnreadCount();
        } catch (error) {
                  }
      }
      
      // 重新加载任务列表以更新未读计数
      await loadTasks();
      
      // 显示成功提示
      showToast('success', t('messages.notifications.messageSent'));
      
    } catch (error: any) {
            // 移除失败的消息
      setTaskMessages(prev => prev.filter(msg => msg.id !== tempId));
      setInput(messageContent); // 恢复输入内容
      
      // 显示错误提示
      showToast('error', getErrorMessage(error) || t('messages.notifications.sendMessageFailed'));
    } finally {
      setIsSending(false);
    }
  };

  // 完成任务（接收者）
  const handleCompleteTask = useCallback(() => {
    if (!activeTaskId || !user) return;
    setShowCompleteTaskModal(true);
  }, [activeTaskId, user]);

  // 完成任务成功回调
  const handleCompleteTaskSuccess = useCallback(async () => {
    if (!activeTaskId) return;
    showToast('success', t('messages.notifications.taskMarkedComplete'));
    
    // 延迟执行耗时的重新加载操作，避免阻塞UI
    setTimeout(async () => {
      try {
        // 重新加载任务信息（后台执行，不阻塞UI）
        if (loadTasksRef.current) {
          loadTasksRef.current().catch(() => {});
        }
        // 重新加载消息（包含系统消息）
        if (loadTaskMessagesRef.current && activeTaskId) {
          await loadTaskMessagesRef.current(activeTaskId);
        }
      } catch (error) {
                }
    }, 0);
  }, [activeTaskId, t]);

  // 确认完成（发布者）
  const handleConfirmCompletion = useCallback(async () => {
    if (!activeTaskId || !user) return;
    
    // 确认提示
    if (!window.confirm(t('messages.notifications.confirmTaskCompletion'))) {
      return;
    }
    
    setActionLoading(true);
    try {
      await confirmTaskCompletion(activeTaskId);
      showToast('success', t('messages.notifications.taskConfirmedComplete'));
      
      // 先更新UI状态，不阻塞
      setActionLoading(false);
      
      // 延迟执行耗时的重新加载操作，避免阻塞UI
      // 使用 setTimeout 将操作移到下一个事件循环，让UI先更新
      setTimeout(async () => {
        try {
          // 重新加载任务信息（后台执行，不阻塞UI）
          if (loadTasksRef.current) {
            loadTasksRef.current().catch(() => {});
          }
          // 重新加载消息（包含系统消息）
          if (loadTaskMessagesRef.current && activeTaskId) {
            await loadTaskMessagesRef.current(activeTaskId);
          }
        } catch (error) {
                  }
      }, 0);
    } catch (error: any) {
            const errorMsg = getErrorMessage(error);
      showToast('error', errorMsg);
      setActionLoading(false);
    }
    // 注意：不包含 loadTasks 和 loadTaskMessages 在依赖数组中，因为它们是在同一个组件中定义的稳定引用
  }, [activeTaskId, user, t]);

  // 根据角色获取标签选项
  const getReviewTags = (task: any | null) => {
    if (!task || !user) return [];
    
    const isPoster = task.poster_id === user.id;
    const isTaker = task.taker_id === user.id;
    
    // 如果是发布者（评价接收者）
    if (isPoster) {
      return [
        t('myTasks.reviewTags.taker.workQuality'),
        t('myTasks.reviewTags.taker.punctual'),
        t('myTasks.reviewTags.taker.responsible'),
        t('myTasks.reviewTags.taker.goodAttitude'),
        t('myTasks.reviewTags.taker.skilled'),
        t('myTasks.reviewTags.taker.reliable'),
        t('myTasks.reviewTags.taker.recommend'),
        t('myTasks.reviewTags.taker.excellent')
      ];
    }
    
    // 如果是接收者（评价发布者）
    if (isTaker) {
      return [
        t('myTasks.reviewTags.poster.taskClear'),
        t('myTasks.reviewTags.poster.communicationTimely'),
        t('myTasks.reviewTags.poster.paymentTimely'),
        t('myTasks.reviewTags.poster.requirementsReasonable'),
        t('myTasks.reviewTags.poster.cooperationPleasant'),
        t('myTasks.reviewTags.poster.recommend'),
        t('myTasks.reviewTags.poster.trustworthy'),
        t('myTasks.reviewTags.poster.professionalEfficient')
      ];
    }
    
    return [];
  };

  // 根据评分获取描述文本
  const getRatingText = (rating: number) => {
    return t(`myTasks.ratingText.${rating}`) || '';
  };

  // 切换标签选择
  const toggleTag = (tag: string) => {
    setSelectedTags(prev => 
      prev.includes(tag) 
        ? prev.filter(t => t !== tag)
        : [...prev, tag]
    );
  };

  // 评价任务
  const handleReviewTask = async () => {
    if (!activeTaskId || !user) {
      showToast('error', t('messages.notifications.enterReviewContent'));
      return;
    }
    
    setActionLoading(true);
    try {
      // 将选择的标签添加到评论中
      let finalComment = reviewComment;
      if (selectedTags.length > 0) {
        const tagsText = selectedTags.join('、');
        if (finalComment) {
          finalComment = `${tagsText}\n\n${finalComment}`;
        } else {
          finalComment = tagsText;
        }
      }
      
      await api.post(`/api/tasks/${activeTaskId}/review`, {
        rating: reviewRating,
        comment: finalComment
      });
      showToast('success', t('messages.notifications.reviewSubmitted'));
      setShowReviewModal(false);
      setReviewComment('');
      setReviewRating(5);
      setSelectedTags([]);
      // 重新加载任务信息和评价数据
      await loadTasks();
      if (activeTaskId) {
        await loadTaskReviews(activeTaskId);
      }
    } catch (error: any) {
            const errorMsg = getErrorMessage(error);
      showToast('error', errorMsg);
    } finally {
      setActionLoading(false);
    }
  };

  // 检查是否可以评价
  const canReview = () => {
    if (!activeTask || !user) return false;
    // 任务必须已完成
    if (activeTask.status !== 'completed') return false;
    // 必须是任务的参与者
    if (activeTask.poster_id !== user.id && activeTask.taker_id !== user.id) return false;
    return true;
  };

  // 检查是否已评价
  const hasReviewed = () => {
    if (!activeTask || !user) return false;
    // 检查用户是否已经评价过（评价会记录user_id，即使是匿名评价）
    return taskReviews.some((review: any) => review.user_id === user.id);
  };

  // 加载任务评价
  const loadTaskReviews = useCallback(async (taskId: number) => {
    if (!taskId) return;
    try {
      const reviews = await getTaskReviews(taskId);
      setTaskReviews(reviews || []);
    } catch (error) {
            setTaskReviews([]);
    }
  }, []);

  // 优化的任务点击处理函数
  const handleTaskClick = useCallback((taskId: number) => {
    // 切换到任务聊天时，清理客服模式的状态
    setIsServiceMode(false);
    setServiceConnected(false);
    setCurrentChat(null);
    setCurrentChatId(null);
    setMessages([]);
    // 清理输入框和图片预览
    setInput('');
    setImagePreview(null);
    setSelectedImage(null);
    setShowEmojiPicker(false);
    
    setActiveTaskId(taskId);
    if (isMobile) {
      setShowMobileChat(true); // 移动端显示聊天框
    }
  }, [isMobile]);

  // 优化的删除任务处理函数
  const handleRemoveTask = useCallback((taskId: number) => {
    // 从任务列表中移除
    setTasks(prevTasks => prevTasks.filter(t => t.id !== taskId));
    
    // 保存到localStorage，确保刷新后不会重新出现
    try {
      const removedTasksKey = `removedTasks_${user?.id || 'anonymous'}`;
      const removedTasks = JSON.parse(localStorage.getItem(removedTasksKey) || '[]');
      if (!removedTasks.includes(taskId)) {
        removedTasks.push(taskId);
        localStorage.setItem(removedTasksKey, JSON.stringify(removedTasks));
      }
    } catch (error) {
          }
    
    // 如果移除的是当前激活的任务，清除激活状态
    if (activeTaskId === taskId) {
      setActiveTaskId(null);
      setActiveTask(null);
      setTaskMessages([]);
    }
  }, [activeTaskId, user?.id]);

  // 当任务ID变化时，加载评价数据
  useEffect(() => {
    if (activeTaskId && activeTask?.status === 'completed') {
      loadTaskReviews(activeTaskId);
    } else {
      setTaskReviews([]);
    }
  }, [activeTaskId, activeTask?.status, loadTaskReviews]);

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
    let isMounted = true;
    let timeoutId: NodeJS.Timeout;
    
    const loadUser = async () => {
      try {
        // 设置超时，防止请求一直挂起
        const timeoutPromise = new Promise((_, reject) => {
          timeoutId = setTimeout(() => {
            reject(new Error('加载用户信息超时'));
          }, 10000); // 10秒超时
        });

        const userData = await Promise.race([
          fetchCurrentUser(),
          timeoutPromise
        ]) as any;
        
        if (isMounted) {
          setUser(userData);
          setLoading(false);
        }
      } catch (error) {
        if (!isMounted) return;
        
                setUser(null);
        setLoading(false);
        setShowLoginModal(true);
      }
    };
    
    loadUser();
    
    return () => {
      isMounted = false;
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    };
  }, [navigate]);

  // 初始化时区信息（未使用）
  const _initializeTimezone = useCallback(async () => {
    try {
      const detectedTimezone = TimeHandlerV2.getUserTimezone();
      setUserTimezone(detectedTimezone);
      
      // 获取服务器时区信息（用于后续可能的时区转换）
      await TimeHandlerV2.getTimezoneInfo();
    } catch {
    }
  }, []);
  void _initializeTimezone;

  // 加载任务列表
  const loadTasks = useCallback(async () => {
    if (!user) {
      return;
    }
    
    setTasksLoading(true);
    try {
      const data = await getTaskChatList(50, 0);
      if (data && data.tasks) {
        // 获取已移除的任务ID列表（从localStorage）
        let removedTaskIds: number[] = [];
        try {
          const removedTasksKey = `removedTasks_${user.id}`;
          const removedTasks = localStorage.getItem(removedTasksKey);
          if (removedTasks) {
            removedTaskIds = JSON.parse(removedTasks);
          }
        } catch (error) {
                  }
        
        // 过滤掉已取消的任务、以及用户手动移除的任务（不再按完成时间自动去除）
        const activeTasks = data.tasks.filter((task: any) => {
          // 过滤已取消的任务
          if (task.status === 'cancelled') {
            return false;
          }
          // 过滤用户手动移除的任务
          if (removedTaskIds.includes(task.id)) {
            return false;
          }
          return true;
        });
        setTasks(activeTasks);
      } else {
        setTasks([]);
      }
    } catch (error: any) {
      // 如果是认证错误，不显示错误，让用户重新登录
      if (error.response?.status === 401 || error.response?.status === 403) {
        // 静默处理认证错误
      }
      setTasks([]);
    } finally {
      setTasksLoading(false);
    }
  }, [user]);
  
  // 更新 ref，以便在其他地方使用
  loadTasksRef.current = loadTasks;

  // 过滤任务列表（根据搜索关键词），并按时间排序（最后消息时间或更新时间，最新的在前）
  const filteredTasks = useMemo(() => {
    let list = tasks;
    if (taskSearchTerm.trim()) {
      const searchTerm = taskSearchTerm.toLowerCase().trim();
      list = tasks.filter((task: any) => {
        if (task.title && task.title.toLowerCase().includes(searchTerm)) return true;
        if (task.task_type && task.task_type.toLowerCase().includes(searchTerm)) return true;
        if (task.location && task.location.toLowerCase().includes(searchTerm)) return true;
        if (task.last_message && task.last_message.content &&
            task.last_message.content.toLowerCase().includes(searchTerm)) return true;
        return false;
      });
    }
    return [...list].sort((a: any, b: any) => {
      const timeA = new Date(a.last_message?.created_at || a.updated_at || a.created_at || 0).getTime();
      const timeB = new Date(b.last_message?.created_at || b.updated_at || b.created_at || 0).getTime();
      return timeB - timeA; //  newest first
    });
  }, [tasks, taskSearchTerm]);

  // 恢复客服聊天状态（未使用）
  const _restoreCustomerServiceChat = useCallback(async () => {
    try {
      const savedChat = localStorage.getItem('currentCustomerServiceChat');
      if (savedChat) {
        const chatData = JSON.parse(savedChat);
        
        // 检查对话是否已结束
        if (chatData.chat && chatData.chat.is_ended === 0) {
          // 对话未结束，验证对话是否仍然有效
          try {
            const response = await fetch(`${API_BASE_URL}/api/user/customer-service/chats/${chatData.chat.chat_id}/messages`, {
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
              
              // 确保滚动到底部
              scrollToBottomImmediate(150);
            } else {
              // 对话无效，清除localStorage并重置状态
              localStorage.removeItem('currentCustomerServiceChat');
              setServiceConnected(false);
              setCurrentChatId(null);
              setCurrentChat(null);
              // setService(null); // 已移除service状态
            }
          } catch (error) {
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
            localStorage.removeItem('currentCustomerServiceChat');
      setServiceConnected(false);
      setCurrentChatId(null);
      setCurrentChat(null);
      // setService(null); // 已移除service状态
    }
  }, []);
  void _restoreCustomerServiceChat;

  // 加载任务消息
  const loadTaskMessages = useCallback(async (taskId: number, cursor?: string | null) => {
    setTaskMessagesLoading(true);
    try {
      const data = await getTaskMessages(taskId, 20, cursor || undefined);
      
      // 处理消息：格式化系统事件消息
      const processedMessages = (data.messages || []).map((msg: any) => {
        // 如果消息内容是原始 JSON 格式的系统事件，格式化为用户友好的文本
        if (msg.content && typeof msg.content === 'string' && msg.content.trim().startsWith('{')) {
          try {
            const parsed = JSON.parse(msg.content);
            if (parsed.type && (
              parsed.type.startsWith('application_') || 
              parsed.type.startsWith('negotiation_') ||
              parsed.type === 'task_completed' || 
              parsed.type === 'task_confirmed'
            )) {
              let systemMessage = '';
              
              switch (parsed.type) {
                case 'application_accepted':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.applicationAccepted', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.applicationAcceptedNoTitle');
                  break;
                case 'application_rejected':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.applicationRejected', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.applicationRejectedNoTitle');
                  break;
                case 'application_withdrawn':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.applicationWithdrawn', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.applicationWithdrawnNoTitle');
                  break;
                case 'negotiation_offer':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.negotiationOffer', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.negotiationOfferNoTitle');
                  break;
                case 'negotiation_accepted':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.negotiationAccepted', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.negotiationAcceptedNoTitle');
                  break;
                case 'negotiation_rejected':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.negotiationRejected', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.negotiationRejectedNoTitle');
                  break;
                case 'task_completed':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.taskCompleted', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.taskCompletedNoTitle');
                  break;
                case 'task_confirmed':
                  systemMessage = parsed.task_title 
                    ? t('messages.systemMessages.taskConfirmed', { taskTitle: parsed.task_title })
                    : t('messages.systemMessages.taskConfirmedNoTitle');
                  break;
                default:
                  systemMessage = t('messages.systemMessages.taskStatusUpdated');
              }
              
              return {
                ...msg,
                content: systemMessage,
                sender_id: 'system',
                sender_name: t('messages.system'),
                isSystemMessage: true
              };
            }
          } catch (e) {
            // 如果不是有效的 JSON，保持原样
          }
        }
        return msg;
      });
      
      // 后端返回的消息可能是 created_at DESC；前端统一按 created_at 升序（旧的在顶，新的在底）
      const sortedByTime = [...processedMessages].sort((a: any, b: any) => {
        const tA = new Date(a.created_at || 0).getTime();
        const tB = new Date(b.created_at || 0).getTime();
        return tA - tB;
      });
      const reversedMessages = sortedByTime;
      
      // 检测是否有新消息（非首次加载且非加载历史消息时）
      if (!cursor && lastTaskMessageIdRef.current !== null && processedMessages.length > 0) {
        const latestMessage = processedMessages[0]; // 使用处理后的消息
        
        // 如果有新消息且用户不在底部，显示提示
        if (latestMessage.id !== lastTaskMessageIdRef.current && !isNearBottom) {
          setHasNewTaskMessages(true);
        }
      }
      
      if (cursor) {
        // 加载更多消息（更旧的消息），合并后按 created_at 升序排序
        setTaskMessages(prev => {
          const merged = [...reversedMessages, ...prev];
          return merged.sort((a: any, b: any) =>
            new Date(a.created_at || 0).getTime() - new Date(b.created_at || 0).getTime()
          );
        });
      } else {
        // 首次加载或刷新，替换消息（已反转，最新的在底部）
        setTaskMessages(reversedMessages);
        
        // 更新最后一条消息ID
        if (reversedMessages.length > 0) {
          const lastMsg = reversedMessages[reversedMessages.length - 1];
          lastTaskMessageIdRef.current = lastMsg.id;
        }
      }
      
      setActiveTask(data.task);
      setTaskNextCursor(data.next_cursor || null);
      setTaskHasMore(data.has_more || false);
      
      // 标记消息为已读（后端返回的最新消息在数组第一个位置）
      if (data.messages && data.messages.length > 0) {
        const lastMessage = data.messages[0]; // 后端返回的最新消息在数组第一个位置
        try {
          await markTaskMessagesRead(taskId, lastMessage.id);
          // 标记已读后立即刷新未读计数
          await loadUnreadCount();
        } catch (error) {
                  }
      }
      
      // 首次加载时滚动到底部
      if (!cursor) {
        setTimeout(() => {
          smartScrollToBottom(true);
          checkIfNearBottom();
          setHasNewTaskMessages(false); // 清除新消息提示
        }, 100);
      } else {
        // 加载历史消息后检查位置
        checkIfNearBottom();
      }
    } catch (error) {
          } finally {
      setTaskMessagesLoading(false);
    }
  }, [isNearBottom, checkIfNearBottom, smartScrollToBottom]);
  
  // 更新 ref，以便在其他地方使用
  loadTaskMessagesRef.current = loadTaskMessages;

  // 加载申请列表
  const loadApplications = useCallback(async (taskId: number) => {
    if (!user) {
      return;
    }
    
    setApplicationsLoading(true);
    try {
      const data = await getTaskApplicationsWithFilter(taskId, 'pending', 50, 0);
      const apps = data.applications || data || [];
      setApplications(apps);
    } catch (error: any) {
                  setApplications([]);
    } finally {
      setApplicationsLoading(false);
    }
  }, [user]);

  // 跟踪最后加载的任务ID，避免重复加载
  const lastLoadedTaskIdRef = useRef<number | null>(null);
  // 跟踪最后检查消息的时间戳，用于轮询
  const lastMessageCheckTimeRef = useRef<number>(Date.now());

  // 当选择任务时加载消息和申请
  useEffect(() => {
    if (chatMode === 'tasks' && activeTaskId && user) {
      // 检查是否是新的任务ID，避免重复加载
      if (lastLoadedTaskIdRef.current === activeTaskId) {
        return; // 已经加载过这个任务，跳过
      }
      
      lastLoadedTaskIdRef.current = activeTaskId;
      lastMessageCheckTimeRef.current = Date.now();
      setTaskMessages([]);
      setTaskNextCursor(null);
      loadTaskMessages(activeTaskId);
      loadApplications(activeTaskId);
    } else if (!activeTaskId) {
      // 如果没有选中任务，重置ref
      lastLoadedTaskIdRef.current = null;
    }
  }, [activeTaskId, chatMode, user, loadTaskMessages, loadApplications]);

  // 监听跨标签页的支付成功事件（通过 localStorage）
  useEffect(() => {
    const handleStorageChange = (event: StorageEvent) => {
      // 检查是否是支付成功的标记
      if (event.key?.startsWith('payment_success_') && event.newValue === 'true') {
        const taskIdFromKey = event.key.replace('payment_success_', '');
        // 如果当前正在查看这个任务，刷新数据
        if (activeTaskId && String(activeTaskId) === taskIdFromKey) {
          message.success(t('messages.notifications.paymentSuccess') || '支付成功！');
          loadTaskMessages(activeTaskId);
          loadApplications(activeTaskId);
          loadTasks();
        } else {
          // 即使不是当前任务，也刷新任务列表
          loadTasks();
        }
        // 清除标记
        localStorage.removeItem(event.key);
      }
    };

    window.addEventListener('storage', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  }, [activeTaskId, loadTasks, loadTaskMessages, loadApplications, t]);

  // 轮询检查新任务消息（作为WebSocket的备用方案）
  useEffect(() => {
    if (chatMode === 'tasks' && activeTaskId && user) {
      const pollInterval = setInterval(async () => {
        try {
          // 只检查是否有新消息（通过获取最新消息并比较ID）
          const data = await getTaskMessages(activeTaskId, 1);
          if (data && data.messages && data.messages.length > 0) {
            let latestMessage = data.messages[0]; // 后端返回的最新消息
            
            // 检查是否是系统事件消息（原始 JSON 格式）
            const isSystemEventRaw = latestMessage.content && typeof latestMessage.content === 'string' && 
              latestMessage.content.trim().startsWith('{') && (
              latestMessage.content.includes('"application_accepted"') ||
              latestMessage.content.includes('"application_rejected"') ||
              latestMessage.content.includes('"negotiation_') ||
              latestMessage.content.includes('"task_completed"') ||
              latestMessage.content.includes('"task_confirmed"')
            );
            
            // 如果是系统事件消息，不触发通知，但需要更新消息列表
            if (isSystemEventRaw) {
              // 重新加载消息列表以获取格式化后的系统消息
              await loadTaskMessages(activeTaskId);
              if (latestMessage.id) {
                lastTaskMessageIdRef.current = latestMessage.id;
              }
              return; // 系统事件不触发通知
            }
            
            // 检查是否是新消息
            if (lastTaskMessageIdRef.current === null || 
                latestMessage.id !== lastTaskMessageIdRef.current) {
              
              // 如果最后一条消息ID不同，说明有新消息，重新加载所有消息
              if (latestMessage.id !== lastTaskMessageIdRef.current) {
                await loadTaskMessages(activeTaskId);
                lastTaskMessageIdRef.current = latestMessage.id;
                
                // 如果用户不在底部，显示新消息提示
                if (!isNearBottom) {
                  setHasNewTaskMessages(true);
                }
                
                // 如果是接收到的消息（不是自己发送的），播放提示音
                if (latestMessage.sender_id !== user.id && latestMessage.sender_id !== 'system') {
                  playMessageSound();
                  
                  // 更新未读消息数量
                  setTotalUnreadCount(prev => {
                    const newCount = prev + 1;
                    if (newCount > 0) {
                      document.title = t('notifications.pageTitleWithCount').replace('{count}', newCount.toString());
                    } else {
                      document.title = t('notifications.pageTitle');
                    }
                    return newCount;
                  });
                  
                  // 显示桌面通知（跳过系统消息，系统消息不应该显示通知）
                  if ('Notification' in window && Notification.permission === 'granted') {
                    if (document.hidden && latestMessage.sender_id !== 'system' && !latestMessage.isSystemMessage) {
                      // 检查是否是系统事件消息（通过内容判断）
                      const isSystemEvent = latestMessage.content && (
                        latestMessage.content.includes('{"type":') ||
                        latestMessage.content.includes('"application_accepted"') ||
                        latestMessage.content.includes('"application_rejected"') ||
                        latestMessage.content.includes('"negotiation_') ||
                        latestMessage.content.includes('"task_completed"') ||
                        latestMessage.content.includes('"task_confirmed"')
                      );
                      
                      if (!isSystemEvent) {
                        const notification = new Notification('新任务消息', {
                          body: `${latestMessage.sender_name || '对方'}: ${latestMessage.content.substring(0, 50)}${latestMessage.content.length > 50 ? '...' : ''}`,
                          icon: '/static/favicon.png',
                          tag: 'task-message-notification',
                          requireInteraction: false
                        });
                        
                        setTimeout(() => {
                          notification.close();
                        }, 3000);
                      }
                    }
                  }
                  
                  // 自动标记为已读
                  if (latestMessage.id) {
                    markTaskMessagesRead(activeTaskId, latestMessage.id)
                      .then(() => {
                        loadUnreadCount();
                      })
                      .catch(() => {});
                  }
                  
                  // 重新加载任务列表以更新未读计数
                  loadTasks().catch(() => {});
                }
              }
            }
          }
        } catch (error) {
                  }
      }, 3000); // 每3秒检查一次
      
      return () => {
        clearInterval(pollInterval);
      };
    }
    return;
  }, [chatMode, activeTaskId, user, isNearBottom, loadTaskMessages, loadTasks, t]);

  // 跟踪最后加载任务列表的用户ID和模式，避免重复加载
  const lastLoadedTasksRef = useRef<{ userId: number | undefined; chatMode: string } | null>(null);

  // 当切换到任务模式时加载任务列表
  useEffect(() => {
    if (chatMode === 'tasks' && user) {
      // 检查是否已经为这个用户和模式加载过任务列表
      const currentKey = { userId: user.id, chatMode };
      const lastKey = lastLoadedTasksRef.current;
      
      if (lastKey && lastKey.userId === currentKey.userId && lastKey.chatMode === currentKey.chatMode) {
        // 已经加载过，跳过
        return;
      }
      
      lastLoadedTasksRef.current = currentKey;
      loadTasks();
    } else {
      // 不在任务模式，重置ref
      lastLoadedTasksRef.current = null;
    }
  }, [chatMode, user?.id, loadTasks]);

  // 用户登录后立即加载任务列表（备用机制，确保加载）
  // 使用 ref 防止重复加载
  const hasAttemptedLoadRef = useRef(false);
  useEffect(() => {
    if (user && chatMode === 'tasks' && !hasAttemptedLoadRef.current) {
      // 如果任务列表为空且不在加载中，则加载（只尝试一次）
      if (tasks.length === 0 && !tasksLoading) {
        hasAttemptedLoadRef.current = true;
        const timer = setTimeout(() => {
          loadTasks();
        }, 300);
        return () => clearTimeout(timer);
      }
    }
    // 当用户变化时重置标志
    if (!user) {
      hasAttemptedLoadRef.current = false;
    }
    return;
  }, [user?.id, chatMode, tasks.length, tasksLoading, loadTasks]);

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
    return;
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
      // 使用全局的 refreshUnreadCount 确保数据一致性
      // refreshUnreadCount 会从服务器获取最新值并更新全局 Context
      await refreshUnreadCount();
      // 等待 refreshUnreadCount 完成后，从全局 Context 获取最新值
      // 使用 setTimeout 确保状态已更新
      setTimeout(() => {
        const newCount = globalUnreadCount;
        setTotalUnreadCount(newCount);
        
        // 更新页面标题
        if (newCount > 0) {
          document.title = t('notifications.pageTitleWithCount').replace('{count}', newCount.toString());
        } else {
          document.title = t('notifications.pageTitle');
        }
      }, 100);
    } catch (error) {
          }
  }, [user, t, refreshUnreadCount, globalUnreadCount]);
  
  // 同步全局未读数到本地状态（当全局值变化时）
  useEffect(() => {
    setTotalUnreadCount(globalUnreadCount);
    
    // 更新页面标题
    if (globalUnreadCount > 0) {
      document.title = t('notifications.pageTitleWithCount').replace('{count}', globalUnreadCount.toString());
    } else {
      document.title = t('notifications.pageTitle');
    }
  }, [globalUnreadCount, t]);

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
            
            // 处理任务相关事件（application_accepted, application_rejected 等）
            if (msg.type && (
              msg.type.startsWith('application_') || 
              msg.type.startsWith('negotiation_') ||
              msg.type === 'task_completed' || 
              msg.type === 'task_confirmed'
            )) {
              // 这些是系统事件，不应该被当作普通消息处理
              // 如果当前正在查看相关任务，显示系统消息
              if (msg.task_id && chatMode === 'tasks' && activeTaskId === msg.task_id) {
                let systemMessage = '';
                
                switch (msg.type) {
                  case 'application_accepted':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.applicationAccepted', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.applicationAcceptedNoTitle');
                    break;
                  case 'application_rejected':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.applicationRejected', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.applicationRejectedNoTitle');
                    break;
                  case 'application_withdrawn':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.applicationWithdrawn', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.applicationWithdrawnNoTitle');
                    break;
                  case 'negotiation_offer':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.negotiationOffer', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.negotiationOfferNoTitle');
                    break;
                  case 'negotiation_accepted':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.negotiationAccepted', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.negotiationAcceptedNoTitle');
                    break;
                  case 'negotiation_rejected':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.negotiationRejected', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.negotiationRejectedNoTitle');
                    break;
                  case 'task_completed':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.taskCompleted', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.taskCompletedNoTitle');
                    break;
                  case 'task_confirmed':
                    systemMessage = msg.task_title 
                      ? t('messages.systemMessages.taskConfirmed', { taskTitle: msg.task_title })
                      : t('messages.systemMessages.taskConfirmedNoTitle');
                    break;
                  default:
                    systemMessage = t('messages.systemMessages.taskStatusUpdated');
                }
                
                // 添加系统消息到任务消息列表
                setTaskMessages(prev => {
                  const systemMsg = {
                    id: Date.now(),
                    sender_id: null, // 系统消息 sender_id 为 null
                    sender_name: t('messages.system'),
                    sender_avatar: null,
                    content: systemMessage,
                    message_type: 'system', // 明确标记为系统消息
                    task_id: msg.task_id,
                    created_at: new Date().toISOString(),
                    attachments: [],
                    isSystemMessage: true
                  };
                  
                  // 检查是否已存在相同的系统消息（避免重复）
                  const exists = prev.some(m => 
                    m.content === systemMessage && 
                    (m.message_type === 'system' || !m.sender_id || m.sender_id === 'system') &&
                    Math.abs(new Date(m.created_at).getTime() - new Date(systemMsg.created_at).getTime()) < 5000
                  );
                  
                  if (exists) {
                    return prev;
                  }
                  const next = [...prev, systemMsg];
                  return next.sort((a: any, b: any) =>
                    new Date(a.created_at || 0).getTime() - new Date(b.created_at || 0).getTime()
                  );
                });
              }
              
              // 无论是否在查看该任务，都重新加载任务列表以更新状态
              loadTasks().catch(() => {});
              
              return; // 事件已处理，不再继续处理为普通消息
            }
            
            // 处理任务消息（通过 task_id 字段判断）
            if (msg.task_id && chatMode === 'tasks' && activeTaskId === msg.task_id) {
              // 使用函数式更新来访问最新的taskMessages状态
              setTaskMessages(prev => {
                // 检查是否已经存在相同的消息（避免重复显示）
                const messageExists = prev.some(m => m.id === msg.id || m.id === msg.message_id);
                
                if (messageExists || !msg.content) {
                  return prev; // 已存在或没有内容，不添加
                }
                
                // 构建任务消息对象
                const taskMessage = {
                  id: msg.id || msg.message_id || Date.now(),
                  sender_id: msg.sender_id || msg.from,
                  sender_name: msg.sender_name || '对方',
                  sender_avatar: msg.sender_avatar,
                  content: msg.content,
                  message_type: msg.message_type, // 保留 message_type 字段，用于识别系统消息
                  task_id: msg.task_id,
                  created_at: msg.created_at || new Date().toISOString(),
                  attachments: msg.attachments || []
                };
                
                // 检查是否已存在（通过ID或内容+时间判断）
                const exists = prev.some(m => 
                  m.id === taskMessage.id || 
                  (m.content === taskMessage.content && 
                   Math.abs(new Date(m.created_at).getTime() - new Date(taskMessage.created_at).getTime()) < 5000)
                );
                if (exists) {
                  return prev;
                }
                
                // 更新最后一条消息ID
                if (taskMessage.id && typeof taskMessage.id === 'number') {
                  lastTaskMessageIdRef.current = taskMessage.id;
                }
                
                // 如果用户不在底部，显示新消息提示
                if (!isNearBottom) {
                  setHasNewTaskMessages(true);
                }
                
                // 如果是接收到的消息（不是自己发送的），播放提示音
                if (msg.sender_id !== user?.id && msg.from !== user?.id) {
                  playMessageSound();
                  
                  // 更新未读消息数量
                  setTotalUnreadCount(prev => {
                    const newCount = prev + 1;
                    if (newCount > 0) {
                      document.title = t('notifications.pageTitleWithCount').replace('{count}', newCount.toString());
                    } else {
                      document.title = t('notifications.pageTitle');
                    }
                    return newCount;
                  });
                  
                  // 显示桌面通知（跳过系统消息，系统消息不应该显示通知）
                  if ('Notification' in window && Notification.permission === 'granted') {
                    if (document.hidden && taskMessage.sender_id !== 'system') {
                      // 检查是否是系统事件消息（通过内容判断）
                      const isSystemEvent = taskMessage.content && (
                        taskMessage.content.includes('{"type":') ||
                        taskMessage.content.includes('"application_accepted"') ||
                        taskMessage.content.includes('"application_rejected"') ||
                        taskMessage.content.includes('"negotiation_') ||
                        taskMessage.content.includes('"task_completed"') ||
                        taskMessage.content.includes('"task_confirmed"')
                      );
                      
                      if (!isSystemEvent) {
                        const notification = new Notification('新任务消息', {
                          body: `${taskMessage.sender_name}: ${taskMessage.content.substring(0, 50)}${taskMessage.content.length > 50 ? '...' : ''}`,
                          icon: '/static/favicon.png',
                          tag: 'task-message-notification',
                          requireInteraction: false
                        });
                        
                        setTimeout(() => {
                          notification.close();
                        }, 3000);
                      }
                    }
                  }
                  
                  // 自动标记为已读（如果用户正在查看该任务）
                  if (activeTaskId && activeTaskId === msg.task_id && taskMessage.id && typeof taskMessage.id === 'number') {
                    markTaskMessagesRead(activeTaskId, taskMessage.id)
                      .then(() => { loadUnreadCount(); })
                      .catch(() => {});
                  }
                  
                  // 重新加载任务列表以更新未读计数
                  loadTasks().catch(() => {});
                }
                
                const next = [...prev, taskMessage];
                return next.sort((a: any, b: any) =>
                  new Date(a.created_at || 0).getTime() - new Date(b.created_at || 0).getTime()
                );
              });
              
              return; // 任务消息已处理，不再处理为普通消息
            }
            
            // 处理客服对话消息（通过chat_id判断）
            if (msg.chat_id && isServiceMode && currentChatId && msg.chat_id === currentChatId) {
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
                const messageId = msg.message_id || msg.id || Date.now();
                
                // 检查是否是任务卡片消息
                const isTaskCard = msg.message_type === 'task_card' || 
                                  (msg.content && msg.content.startsWith('[TASK_CARD:') && msg.content.endsWith(']'));
                let taskId: number | undefined;
                
                if (isTaskCard) {
                  // 从消息内容或字段中提取任务ID
                  if (msg.task_id) {
                    taskId = msg.task_id;
                  } else if (msg.content && msg.content.startsWith('[TASK_CARD:')) {
                    const match = msg.content.match(/\[TASK_CARD:(\d+)\]/);
                    if (match) {
                      taskId = parseInt(match[1], 10);
                    }
                  }
                }
                
                // 检查是否已经存在相同的消息（避免重复显示）
                setMessages(prev => {
                  // 检查是否已经存在相同内容、相同发送者、时间相近的消息
                  const exists = prev.some(m => 
                    (m.id === messageId) || 
                    (m.content === (isTaskCard ? '任务卡片' : msg.content.trim()) && 
                     m.from === fromName && 
                     Math.abs(new Date(m.created_at).getTime() - new Date(msg.created_at).getTime()) < 5000) // 5秒内的消息认为是重复的
                  );
                  
                  if (exists) {
                    return prev; // 如果已存在，不添加
                  }
                  
                  return [...prev, {
                    id: messageId,
                    from: fromName,
                    content: isTaskCard ? '任务卡片' : msg.content.trim(), 
                    created_at: msg.created_at,
                    message_type: isTaskCard ? 'task_card' : (msg.message_type || 'text'),
                    task_id: taskId || msg.task_id
                  }];
                });
                
                // 标记为新消息，触发自动滚动（只对非系统消息）
                if (fromName !== t('messages.system')) {
                  setIsNewMessage(true);
                }
                
                // 如果是接收到的消息（不是自己发送的），播放提示音
                if (msg.from !== user.id && msg.sender_type !== 'system') {
                  playMessageSound();
                  
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
                
                return; // 客服消息已处理，不再处理为普通消息
              }
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
                if (fromName !== t('messages.system')) {
                  setIsNewMessage(true);
                }
                
                // 如果是接收到的消息（不是自己发送的），播放提示音
                if (msg.from !== user.id && msg.from !== 'system' && msg.from !== 'customer_service' && msg.from !== 'admin') {
                  playMessageSound();
                  
                  // 更新未读消息数量（避免重复更新，同时更新全局Context）
                  setTotalUnreadCount(prev => {
                    const newCount = prev + 1;
                    // 更新页面标题
                    if (newCount > 0) {
                      document.title = t('notifications.pageTitleWithCount').replace('{count}', newCount.toString());
                    } else {
                      document.title = t('notifications.pageTitle');
                    }
                    // 立即更新全局Context
                    setTimeout(() => {
                      refreshUnreadCount();
                    }, 300);
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
        
        socket.onerror = () => {
                  };
        
        socket.onclose = (event) => {
          if (socket) {
            setWs(null);
          }
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
    return;
  }, [user?.id]);

  // 定期检查客服对话是否已结束
  useEffect(() => {
    if (isServiceMode && currentChatId && currentChat && currentChat.is_ended === 0) {
      const checkChatStatus = async () => {
        try {
          const response = await fetch(`${API_BASE_URL}/api/user/customer-service/chats/${currentChatId}/messages`, {
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
                  }
      };
      
      // 每10秒检查一次
      const interval = setInterval(checkChatStatus, 10000);
      
      return () => clearInterval(interval);
    }
    return;
  }, [isServiceMode, currentChatId, currentChat?.is_ended]);

  const loadChatHistory = useCallback(async (_serviceId: string, chatId: string) => {
    void _serviceId;
    try {
      
      // 如果有chatId，加载特定对话的聊天记录（客服聊天）
      if (chatId) {
        const response = await fetch(`${API_BASE_URL}/api/user/customer-service/chats/${chatId}/messages`, {
          credentials: 'include'  // 使用Cookie认证
        });
        
        if (response.ok) {
          const chatData = await response.json();
          const formattedMessages = chatData.map((msg: any) => {
            // 检查是否是任务卡片消息
            const isTaskCard = msg.message_type === 'task_card' || 
                              (msg.content && msg.content.startsWith('[TASK_CARD:') && msg.content.endsWith(']'));
            let taskId: number | undefined;
            
            if (isTaskCard) {
              // 从消息内容或字段中提取任务ID
              if (msg.task_id) {
                taskId = msg.task_id;
              } else if (msg.content && msg.content.startsWith('[TASK_CARD:')) {
                const match = msg.content.match(/\[TASK_CARD:(\d+)\]/);
                if (match) {
                  taskId = parseInt(match[1], 10);
                }
              }
            }
            
            return {
              id: msg.id,
              from: msg.sender_type === 'user' ? t('messages.me') : (msg.sender_type === 'system' ? t('messages.system') : t('messages.customerService')),
              content: isTaskCard ? '任务卡片' : msg.content,
              created_at: msg.created_at,
              is_admin_msg: msg.sender_type === 'system' ? 1 : 0,
              message_type: isTaskCard ? 'task_card' : (msg.message_type || 'text'),
              task_id: taskId || msg.task_id
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
          // 使用多个延迟确保消息完全渲染后再滚动
          scrollToBottomImmediate(100);
          scrollToBottomImmediate(300); // 再次确保滚动（防止第一次延迟不够）
        }
        
        // 注意：用户端不应调用markCustomerServiceMessagesRead，这是客服专用的接口
        // 用户端通过WebSocket接收消息，消息会被自动标记为已读
        
        return;
      }
    }
      
    } catch (error) {
          }
  }, [t]);

  // 滚动到底部
  const scrollToBottom = useCallback(() => {
    const messagesContainer = messagesContainerRef.current;
    if (messagesContainer) {
      // 立即滚动到底部
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
    // 延迟检查是否到达底部，如果是则隐藏按钮
    setTimeout(() => {
      if (messagesContainer) {
        const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
        const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
        if (distanceFromBottom < 200) {
          setShowScrollToBottomButton(false);
        }
      }
    }, 300);
  }, []);

  // 滚动监听器 - 检测是否滚动到顶部（仅用于客服模式）和任务聊天的滚动位置
  useEffect(() => {
    const messagesContainer = messagesContainerRef.current;
    if (!messagesContainer) return;

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
      const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
      
      // 客服模式：控制"滚动到底部"按钮的显示
      if (isServiceMode) {
        setShowScrollToBottomButton(distanceFromBottom > 200);
      }
      
      // 任务聊天模式：检查是否接近底部，如果接近底部则清除新消息提示
      if (chatMode === 'tasks' && activeTaskId) {
        const nearBottom = distanceFromBottom < 150;
        setIsNearBottom(nearBottom);
        setShowScrollToBottom(distanceFromBottom > 200);
        
        // 如果用户滚动到底部，清除新消息提示
        if (nearBottom && hasNewTaskMessages) {
          setHasNewTaskMessages(false);
        }
      }
    };

    messagesContainer.addEventListener('scroll', handleScroll);
    return () => {
      messagesContainer.removeEventListener('scroll', handleScroll);
    };
  }, [isServiceMode, chatMode, activeTaskId, hasNewTaskMessages]);

  // 动态计算滚动按钮位置（相对于输入框区域）
  useEffect(() => {
    const updateButtonPosition = () => {
      // 客服模式：计算客服输入框上方位置
      if (inputAreaRef.current && isServiceMode) {
        const rect = inputAreaRef.current.getBoundingClientRect();
        // 计算输入框顶部距离视口底部的距离，然后加上20px作为按钮位置
        const distanceFromBottom = window.innerHeight - rect.top;
        setScrollButtonBottom(Math.max(100, distanceFromBottom + 20)); // 输入框上方20px，最小100px
      } else if (isServiceMode) {
        // 如果输入框还未渲染，使用默认值
        setScrollButtonBottom(120);
      }
      
      // 任务聊天模式：计算任务输入框上方位置和水平居中位置
      if (taskInputAreaRef.current && chatMode === 'tasks' && activeTaskId) {
        const rect = taskInputAreaRef.current.getBoundingClientRect();
        // 计算输入框顶部距离视口底部的距离，然后加上20px作为按钮位置
        const distanceFromBottom = window.innerHeight - rect.top;
        setTaskScrollButtonBottom(Math.max(100, distanceFromBottom + 20)); // 输入框上方20px，最小100px
        
        // 计算按钮的水平位置：输入框中心 - 按钮宽度的一半（24px）
        const buttonWidth = 48; // 按钮宽度
        const inputBoxCenter = rect.left + (rect.width / 2);
        const buttonLeft = inputBoxCenter - (buttonWidth / 2);
        setTaskScrollButtonLeft(buttonLeft);
      } else if (chatMode === 'tasks' && activeTaskId) {
        // 如果输入框还未渲染，使用默认值
        setTaskScrollButtonBottom(120);
        setTaskScrollButtonLeft(null);
      }
    };

    if (isServiceMode || (chatMode === 'tasks' && activeTaskId)) {
      // 立即执行一次
      updateButtonPosition();
      // 延迟执行以确保DOM已渲染
      const timeoutId = setTimeout(updateButtonPosition, 100);
      const timeoutId2 = setTimeout(updateButtonPosition, 300);
      const timeoutId3 = setTimeout(updateButtonPosition, 500);
      window.addEventListener('resize', updateButtonPosition);
      // 使用 ResizeObserver 监听输入框区域大小变化
      let resizeObserver: ResizeObserver | null = null;
      if (inputAreaRef.current && isServiceMode) {
        resizeObserver = new ResizeObserver(updateButtonPosition);
        resizeObserver.observe(inputAreaRef.current);
      }
      if (taskInputAreaRef.current && chatMode === 'tasks' && activeTaskId) {
        if (!resizeObserver) {
          resizeObserver = new ResizeObserver(updateButtonPosition);
        }
        resizeObserver.observe(taskInputAreaRef.current);
      }
      return () => {
        clearTimeout(timeoutId);
        clearTimeout(timeoutId2);
        clearTimeout(timeoutId3);
        window.removeEventListener('resize', updateButtonPosition);
        if (resizeObserver) {
          resizeObserver.disconnect();
        }
      };
    }
    return;
  }, [isServiceMode, chatMode, activeTaskId, imagePreview, filePreview, showEmojiPicker]);

  // 跟踪最后处理的消息ID，避免重复滚动
  const lastProcessedMessageIdRef = useRef<number | null>(null);

  // 客服模式下，当消息更新时自动滚动到底部（仅在真正的新消息时触发）
  useEffect(() => {
    // 只在客服模式下处理，且排除任务聊天模式
    if (!isServiceMode || chatMode === 'tasks') {
      return;
    }

    if (messages.length > 0) {
      const lastMessage = messages[messages.length - 1];
      if (!lastMessage) return;
      
      const messageId = lastMessage.id;
      if (!messageId) return;
      
      const isNewMessage = messageId !== lastProcessedMessageIdRef.current;
      
      if (isNewMessage) {
        lastProcessedMessageIdRef.current = messageId;
        
        if (lastMessage.from === t('messages.system')) {
          setTimeout(() => {
            scrollToBottomImmediate(0, true);
          }, 100);
          setTimeout(() => {
            scrollToBottomImmediate(0, true);
          }, 300);
        } else {
          // 其他消息，智能滚动（如果用户接近底部）
          smartScrollToBottom(false);
        }
        
        // 更新滚动按钮状态（延迟执行，确保DOM已更新）
        setTimeout(() => {
          const messagesContainer = messagesContainerRef.current;
          if (messagesContainer) {
            const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
            const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
            setShowScrollToBottomButton(distanceFromBottom > 200);
          }
        }, 100);
      }
    }
  }, [messages, isServiceMode, chatMode, t, scrollToBottomImmediate, smartScrollToBottom]);

  // 联系在线客服
  const handleContactCustomerService = async () => {
    // 注意：不再依赖serviceAvailable状态，直接调用API检查，确保获取最新状态

    // 先检查localStorage中是否已有活跃的客服对话
    const savedChat = localStorage.getItem('currentCustomerServiceChat');
    
    if (savedChat) {
      try {
        const chatData = JSON.parse(savedChat);
        
        // 检查对话是否已结束
        if (chatData.chat.is_ended === 0) {
          // 对话未结束，验证对话是否仍然有效
          try {
            const response = await fetch(`${API_BASE_URL}/api/user/customer-service/chats/${chatData.chat.chat_id}/messages`, {
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
              
              // 确保滚动到底部
              scrollToBottomImmediate(150);
              
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
        
        // 确保在添加成功消息后滚动到底部
        scrollToBottomSmooth(150);
      } else {
        // 客服不在线，显示系统提示
        const noServiceMessage: Message = {
          id: Date.now(),
          from: t('messages.system'),
          content: t('messages.noServiceAvailable'),
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, noServiceMessage]);
        // 确保滚动到底部显示系统消息 - 使用多次延迟确保消息渲染完成
        setTimeout(() => {
          scrollToBottomImmediate(0, true);
        }, 50);
        setTimeout(() => {
          scrollToBottomImmediate(0, true);
        }, 200);
        setTimeout(() => {
          scrollToBottomImmediate(0, true);
        }, 400);
      }
    } catch (error) {
            const errorMessage: Message = {
        id: Date.now(),
        from: t('messages.system'),
        content: t('messages.connectServiceError'),
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
      // 确保滚动到底部显示错误消息 - 使用多次延迟确保消息渲染完成
      setTimeout(() => {
        scrollToBottomImmediate(0, true);
      }, 50);
      setTimeout(() => {
        scrollToBottomImmediate(0, true);
      }, 200);
      setTimeout(() => {
        scrollToBottomImmediate(0, true);
      }, 400);
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
            // 如果API调用失败，返回false（无客服在线）
      return false;
    }
  };

  // 检查并更新客服在线状态（未使用）
  const _checkServiceAvailability = useCallback(async () => {
    setServiceStatusLoading(true);
    try {
      const isAvailable = await checkCustomerServiceAvailabilityLocal();
      setServiceAvailable(isAvailable);
    } catch (error) {
            setServiceAvailable(false);
    } finally {
      setServiceStatusLoading(false);
    }
  }, []);
  void _checkServiceAvailability;

  // 结束客服对话
  const handleEndConversation = async () => {
    if (!currentChatId) {
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
      await api.post(`/api/user/customer-service/chats/${currentChatId}/end`);
      
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

  // 获取客服评价标签
  const getCustomerServiceReviewTags = () => {
    return [
      t('messages.reviewTags.customerService.responseTimely'),
      t('messages.reviewTags.customerService.professional'),
      t('messages.reviewTags.customerService.helpful'),
      t('messages.reviewTags.customerService.patient'),
      t('messages.reviewTags.customerService.clearExplanation'),
      t('messages.reviewTags.customerService.problemSolved'),
      t('messages.reviewTags.customerService.recommend'),
      t('messages.reviewTags.customerService.excellent')
    ];
  };

  // 切换标签选择
  const toggleRatingTag = (tag: string) => {
    setRatingSelectedTags(prev => 
      prev.includes(tag) 
        ? prev.filter(t => t !== tag)
        : [...prev, tag]
    );
  };

  // 获取评分文字
  const getRatingTextForService = (rating: number) => {
    const ratingTexts: { [key: number]: string } = {
      1: t('messages.ratingVeryDissatisfied'),
      2: t('messages.ratingDissatisfied'),
      3: t('messages.ratingNeutral'),
      4: t('messages.ratingSatisfied'),
      5: t('messages.ratingVerySatisfied')
    };
    return ratingTexts[rating] || '';
  };

  // 提交评价
  const handleSubmitRating = async () => {
    if (!ratingChatId) {
            return;
    }
    
    try {
      // 将标签添加到评论中
      let finalComment = ratingComment;
      if (ratingSelectedTags.length > 0) {
        const tagsText = ratingSelectedTags.join('、');
        finalComment = finalComment 
          ? `${finalComment}\n\n标签: ${tagsText}`
          : `标签: ${tagsText}`;
      }

      // 使用 api.post 自动包含 CSRF token
      await api.post(`/api/user/customer-service/chats/${ratingChatId}/rate`, {
        rating: rating,
        comment: finalComment
      });
      
      // 关闭评价弹窗
      setShowRatingModal(false);
      setRating(5);
      setRatingComment('');
      setRatingSelectedTags([]);
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
            alert(t('messages.submitRatingFailed'));
    }
  };

  if (loading) {
    return (
      <div className={styles.loadingContainer}>
        <div className={styles.loadingCard}>
          <div className={styles.loadingIcon}>⏳</div>
          <div className={styles.loadingText}>{t('messages.loadingMessageCenter')}</div>
        </div>
      </div>
    );
  }

  if (!user) {
  return (
      <div className={styles.authContainer}>
        <div className={styles.authCard}>
          <div className={styles.authIcon}>🔒</div>
          <div className={styles.authTitle}>请先登录</div>
          <button
            onClick={() => setShowLoginModal(true)}
            className={styles.authButton}
          >
            前往登录
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.pageContainer}>
      <SEOHead noindex={true} />
      {/* SEO优化：H1标签，几乎不可见但SEO可检测 */}
      <h1 className={styles.seoH1}>
        {t('messages.messageCenter')}
      </h1>
      <div className={styles.mainContent}>
        
        {/* 左侧任务列表 */}
        <div className={`${styles.taskListSidebar} ${isMobile ? styles.taskListSidebarMobile : ''}`}
          style={{
            display: isMobile && showMobileChat ? 'none' : 'flex',
            transform: 'none'
          }}
        >
          {/* 头部标题 */}
          <div className={`${styles.taskListHeader} ${isMobile ? styles.taskListHeaderMobile : ''}`}>
            <div 
              className={`${styles.backButton} ${isMobile ? styles.backButtonMobile : ''}`}
              onClick={() => {
                navigate('/');
              }}
            >
              {isMobile ? t('messages.backToHome') : t('messages.back')}
            </div>
            💬 {t('messages.messageCenter')}
            {totalUnreadCount > 0 && (
              <span className={styles.unreadBadge}>
                {totalUnreadCount}
              </span>
            )}
            <button
              onClick={async (e) => {
                e.stopPropagation();
                const newShow = !showDebugPanel;
                setShowDebugPanel(newShow);
                if (newShow && !debugInfo) {
                  // 首次打开时加载调试信息
                  setDebugLoading(true);
                  try {
                    const res = await api.get('/api/users/messages/unread/count', { params: { debug: true } });
                    setDebugInfo(res.data.debug || null);
                  } catch (err) {
                    setDebugInfo({ error: String(err) });
                  } finally {
                    setDebugLoading(false);
                  }
                }
              }}
              style={{
                marginLeft: '8px',
                padding: '2px 8px',
                fontSize: '11px',
                background: showDebugPanel ? '#ef4444' : '#64748b',
                color: '#fff',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                opacity: 0.7
              }}
              title="Toggle debug panel"
            >
              🐛 Debug
            </button>
          </div>

          {/* 搜索框 */}
          <div className={`${styles.searchSection} ${isMobile ? styles.searchSectionMobile : ''}`}>
            <div className={styles.searchInputContainer}>
              <input
                type="text"
                value={taskSearchTerm}
                onChange={(e) => setTaskSearchTerm(e.target.value)}
                placeholder={t('messages.searchTasks') || '搜索任务...'}
                className={styles.searchInput}
              />
              <div className={styles.searchIcon}>
                🔍
              </div>
            </div>
          </div>

          {/* 调试面板 - 显示未读消息详情 */}
          {showDebugPanel && (
            <div style={{
              background: '#1e293b',
              color: '#e2e8f0',
              fontSize: '11px',
              fontFamily: 'monospace',
              padding: '10px 12px',
              maxHeight: '300px',
              overflowY: 'auto',
              borderBottom: '2px solid #ef4444'
            }}>
              <div style={{ marginBottom: '8px', color: '#f59e0b', fontWeight: 'bold', fontSize: '12px' }}>
                🐛 未读消息调试信息
              </div>
              <div style={{ marginBottom: '6px', padding: '4px 6px', background: '#334155', borderRadius: '4px' }}>
                <span style={{ color: '#94a3b8' }}>全局未读数 (Context): </span>
                <span style={{ color: '#22d3ee', fontWeight: 'bold' }}>{globalUnreadCount}</span>
                <span style={{ color: '#94a3b8' }}> | 本地未读数: </span>
                <span style={{ color: '#22d3ee', fontWeight: 'bold' }}>{totalUnreadCount}</span>
              </div>
              <div style={{ marginBottom: '6px', padding: '4px 6px', background: '#334155', borderRadius: '4px' }}>
                <span style={{ color: '#94a3b8' }}>任务总数: </span>
                <span style={{ color: '#a5f3fc' }}>{tasks.length}</span>
                <span style={{ color: '#94a3b8' }}> | 有未读的任务: </span>
                <span style={{ color: '#fbbf24', fontWeight: 'bold' }}>
                  {tasks.filter((t: any) => t.unread_count > 0).length}
                </span>
                <span style={{ color: '#94a3b8' }}> | 任务未读总和: </span>
                <span style={{ color: '#fbbf24', fontWeight: 'bold' }}>
                  {tasks.reduce((sum: number, t: any) => sum + (t.unread_count || 0), 0)}
                </span>
              </div>
              
              {/* 列出所有有未读消息的任务 */}
              {tasks.filter((t: any) => t.unread_count > 0).length > 0 ? (
                <div style={{ marginTop: '6px' }}>
                  <div style={{ color: '#fb923c', fontWeight: 'bold', marginBottom: '4px' }}>
                    📋 有未读消息的任务:
                  </div>
                  {tasks.filter((t: any) => t.unread_count > 0).map((task: any) => (
                    <div key={task.id} style={{
                      padding: '6px 8px',
                      marginBottom: '4px',
                      background: '#0f172a',
                      borderRadius: '4px',
                      borderLeft: '3px solid #f59e0b'
                    }}>
                      <div>
                        <span style={{ color: '#94a3b8' }}>任务ID: </span>
                        <span style={{ color: '#38bdf8' }}>{task.id}</span>
                        <span style={{ color: '#94a3b8' }}> | 未读: </span>
                        <span style={{ color: '#ef4444', fontWeight: 'bold' }}>{task.unread_count}</span>
                        <span style={{ color: '#94a3b8' }}> | 状态: </span>
                        <span style={{ color: '#a5f3fc' }}>{task.status}</span>
                      </div>
                      <div style={{ color: '#cbd5e1', marginTop: '2px' }}>
                        标题: {task.title?.substring(0, 40)}{task.title?.length > 40 ? '...' : ''}
                      </div>
                      {task.last_message && (
                        <div style={{ marginTop: '2px', color: '#94a3b8' }}>
                          最后消息: <span style={{ color: '#67e8f9' }}>{task.last_message.sender_name}</span>
                          : {task.last_message.content?.substring(0, 50)}{task.last_message.content?.length > 50 ? '...' : ''}
                          <br />
                          时间: {dayjs(task.last_message.created_at).format('YYYY-MM-DD HH:mm:ss')}
                          <span style={{ color: '#94a3b8' }}> | is_read: </span>
                          <span style={{ color: task.last_message.is_read ? '#22c55e' : '#ef4444' }}>
                            {String(task.last_message.is_read)}
                          </span>
                        </div>
                      )}
                      <div style={{ marginTop: '2px', color: '#64748b', fontSize: '10px' }}>
                        task_type: {task.task_type} | poster_id: {task.poster_id} | helper_id: {task.helper_id}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{ color: '#22c55e', padding: '4px 6px', background: '#334155', borderRadius: '4px' }}>
                  ✅ 任务列表中没有未读消息 (但全局未读数为 {globalUnreadCount})
                  {globalUnreadCount > 0 && (
                    <div style={{ color: '#fbbf24', marginTop: '4px' }}>
                      ⚠️ 全局显示有未读，但任务列表中所有 unread_count 均为 0。
                      可能原因: 客服消息未读 / 私聊消息未读 / API数据不同步
                    </div>
                  )}
                </div>
              )}

              {/* 显示所有任务的简要信息 */}
              <div style={{ marginTop: '8px' }}>
                <div style={{ color: '#94a3b8', fontWeight: 'bold', marginBottom: '4px' }}>
                  📜 所有任务列表 (含 unread_count):
                </div>
                {tasks.map((task: any, idx: number) => (
                  <div key={task.id} style={{
                    padding: '2px 6px',
                    fontSize: '10px',
                    color: task.unread_count > 0 ? '#fbbf24' : '#64748b',
                    borderBottom: '1px solid #1e293b'
                  }}>
                    #{idx + 1} ID:{task.id} | unread:{task.unread_count || 0} | {task.title?.substring(0, 30)} | {task.status}
                  </div>
                ))}
              </div>

              {/* 后端 API 返回的详细未读信息 */}
              <div style={{ marginTop: '10px', borderTop: '1px solid #475569', paddingTop: '8px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                  <span style={{ color: '#f59e0b', fontWeight: 'bold', fontSize: '12px' }}>
                    🔍 后端API详细未读信息
                  </span>
                  <button
                    onClick={async () => {
                      setDebugLoading(true);
                      try {
                        const res = await api.get('/api/users/messages/unread/count', { params: { debug: true } });
                        setDebugInfo(res.data.debug || null);
                      } catch (err) {
                        setDebugInfo({ error: String(err) });
                      } finally {
                        setDebugLoading(false);
                      }
                    }}
                    style={{
                      padding: '1px 6px',
                      fontSize: '10px',
                      background: '#3b82f6',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '3px',
                      cursor: 'pointer'
                    }}
                  >
                    {debugLoading ? '加载中...' : '🔄 刷新'}
                  </button>
                </div>

                {debugLoading && (
                  <div style={{ color: '#94a3b8', padding: '8px' }}>⏳ 正在从后端API加载详细未读信息...</div>
                )}

                {debugInfo && !debugLoading && (
                  <div>
                    {debugInfo.error ? (
                      <div style={{ color: '#ef4444', padding: '4px 6px', background: '#334155', borderRadius: '4px' }}>
                        ❌ API错误: {debugInfo.error}
                      </div>
                    ) : (
                      <>
                        <div style={{ padding: '4px 6px', background: '#334155', borderRadius: '4px', marginBottom: '6px' }}>
                          <span style={{ color: '#94a3b8' }}>用户ID: </span>
                          <span style={{ color: '#a5f3fc' }}>{debugInfo.user_id}</span>
                          <span style={{ color: '#94a3b8' }}> | API返回未读总数: </span>
                          <span style={{ color: '#ef4444', fontWeight: 'bold' }}>{debugInfo.total_unread}</span>
                        </div>

                        {/* 按任务分组的未读 */}
                        {debugInfo.by_task && debugInfo.by_task.length > 0 && (
                          <div style={{ marginBottom: '6px' }}>
                            <div style={{ color: '#fb923c', fontWeight: 'bold', marginBottom: '4px', fontSize: '11px' }}>
                              📊 按任务分组的未读消息:
                            </div>
                            {debugInfo.by_task.map((item: any) => (
                              <div key={item.task_id} style={{
                                padding: '6px 8px',
                                marginBottom: '4px',
                                background: '#0f172a',
                                borderRadius: '4px',
                                borderLeft: '3px solid #ef4444'
                              }}>
                                <div>
                                  <span style={{ color: '#94a3b8' }}>任务ID: </span>
                                  <span style={{ color: '#38bdf8', fontWeight: 'bold' }}>{item.task_id}</span>
                                  <span style={{ color: '#94a3b8' }}> | 未读数: </span>
                                  <span style={{ color: '#ef4444', fontWeight: 'bold' }}>{item.count}</span>
                                  {/* 检查该任务是否在前端任务列表中 */}
                                  <span style={{ color: '#94a3b8' }}> | 在列表中: </span>
                                  <span style={{ color: tasks.some((t: any) => t.id === item.task_id) ? '#22c55e' : '#ef4444', fontWeight: 'bold' }}>
                                    {tasks.some((t: any) => t.id === item.task_id) ? '✅ 是' : '❌ 否 (这就是看不到的原因!)'}
                                  </span>
                                </div>
                                {/* 任务详细信息 */}
                                {item.task_info && (
                                  <div style={{ marginTop: '4px', padding: '4px 6px', background: '#1e293b', borderRadius: '3px', fontSize: '10px' }}>
                                    {item.task_info.error ? (
                                      <span style={{ color: '#ef4444' }}>⚠️ {item.task_info.error}</span>
                                    ) : (
                                      <>
                                        <div>
                                          <span style={{ color: '#94a3b8' }}>标题: </span>
                                          <span style={{ color: '#e2e8f0' }}>{item.task_info.title}</span>
                                          <span style={{ color: '#94a3b8' }}> | 任务状态: </span>
                                          <span style={{ color: item.task_info.status === 'cancelled' ? '#ef4444' : '#22d3ee', fontWeight: 'bold' }}>
                                            {item.task_info.status}
                                          </span>
                                        </div>
                                        <div style={{ marginTop: '2px' }}>
                                          <span style={{ color: '#94a3b8' }}>poster_id: </span>
                                          <span style={{ color: '#a5f3fc' }}>{item.task_info.poster_id}</span>
                                          <span style={{ color: item.task_info.user_is_poster ? '#22c55e' : '#64748b' }}>
                                            {item.task_info.user_is_poster ? ' (是你)' : ''}
                                          </span>
                                          <span style={{ color: '#94a3b8' }}> | taker_id: </span>
                                          <span style={{ color: '#a5f3fc' }}>{item.task_info.taker_id || 'null'}</span>
                                          <span style={{ color: item.task_info.user_is_taker ? '#22c55e' : '#64748b' }}>
                                            {item.task_info.user_is_taker ? ' (是你)' : ''}
                                          </span>
                                        </div>
                                        <div style={{ marginTop: '2px' }}>
                                          <span style={{ color: '#94a3b8' }}>多人任务: </span>
                                          <span style={{ color: item.task_info.is_multi_participant ? '#fbbf24' : '#64748b' }}>
                                            {item.task_info.is_multi_participant ? '是' : '否'}
                                          </span>
                                          <span style={{ color: '#94a3b8' }}> | 参与者状态: </span>
                                          <span style={{ color: item.task_info.participant_status === 'completed' ? '#f59e0b' : '#22c55e', fontWeight: 'bold' }}>
                                            {item.task_info.participant_status || '不是参与者'}
                                          </span>
                                          {item.task_info.participant_status === 'completed' && (
                                            <span style={{ color: '#ef4444', fontWeight: 'bold' }}>
                                              {' '}← 原因: 参与者状态completed未被聊天列表查询包含!
                                            </span>
                                          )}
                                          {item.task_info.status === 'cancelled' && (
                                            <span style={{ color: '#ef4444', fontWeight: 'bold' }}>
                                              {' '}← 原因: 任务已取消，前端过滤掉了!
                                            </span>
                                          )}
                                          {!item.task_info.user_is_poster && !item.task_info.user_is_taker && !item.task_info.participant_status && (
                                            <span style={{ color: '#ef4444', fontWeight: 'bold' }}>
                                              {' '}← 原因: 用户与该任务无关联但仍计入未读!
                                            </span>
                                          )}
                                        </div>
                                      </>
                                    )}
                                  </div>
                                )}
                                {item.latest_message && (
                                  <div style={{ marginTop: '3px', fontSize: '10px', color: '#94a3b8' }}>
                                    最新未读: [{item.latest_message.sender_id}] {item.latest_message.content}
                                    <br />时间: {item.latest_message.created_at}
                                  </div>
                                )}
                              </div>
                            ))}
                          </div>
                        )}

                        {/* 所有未读消息详情 */}
                        {debugInfo.messages && debugInfo.messages.length > 0 && (
                          <div>
                            <div style={{ color: '#94a3b8', fontWeight: 'bold', marginBottom: '4px', fontSize: '11px' }}>
                              📝 所有未读消息明细 ({debugInfo.messages.length}条):
                            </div>
                            {debugInfo.messages.map((msg: any, idx: number) => (
                              <div key={msg.message_id} style={{
                                padding: '3px 6px',
                                fontSize: '10px',
                                color: '#cbd5e1',
                                borderBottom: '1px solid #1e293b'
                              }}>
                                #{idx + 1} msgID:{msg.message_id} | taskID:{msg.task_id} | from:{msg.sender_id} | type:{msg.message_type} | {msg.created_at}
                                <br />
                                <span style={{ color: '#67e8f9' }}>内容: {msg.content}</span>
                              </div>
                            ))}
                          </div>
                        )}
                      </>
                    )}
                  </div>
                )}

                {!debugInfo && !debugLoading && (
                  <div style={{ color: '#64748b', padding: '4px 6px' }}>
                    点击上方"刷新"按钮加载后端API详细未读信息
                  </div>
                )}
              </div>
            </div>
          )}

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
                      
                      // 确保滚动到底部
                      setTimeout(() => {
                        const messagesContainer = messagesContainerRef.current;
                        if (messagesContainer) {
                          messagesContainer.scrollTop = messagesContainer.scrollHeight;
                        }
                        if (messagesEndRef.current) {
                          messagesEndRef.current.scrollIntoView({ behavior: 'auto' });
                        }
                      }, 150);
                      
                      setIsConnectingToService(false);
                      
                      if (isMobile) {
                        setShowMobileChat(true); // 移动端显示聊天框
                      }
                      
                      return; // 直接返回，不创建新对话
                    } else {
                      // 对话已结束，清除localStorage并重置状态
                      localStorage.removeItem('currentCustomerServiceChat');
                      setServiceConnected(false);
                      setCurrentChatId(null);
                      setCurrentChat(null);
                    }
                  } catch (error) {
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
                
                if (isMobile) {
                  setShowMobileChat(true); // 移动端显示聊天框
                }
                
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
                borderBottom: '2px solid #cbd5e1',
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
                width: '36px',
                height: '36px'
              }}>
                <LazyImage src={'/static/service.png'} alt={t('messages.service')} style={{ 
                  width: '36px', 
                  height: '36px', 
                  borderRadius: '50%', 
                  border: '2px solid #f59e0b', 
                  background: '#fffbe6', 
                  objectFit: 'cover',
                  boxShadow: '0 2px 8px rgba(245, 158, 11, 0.3)',
                  transition: 'none'
                }} 
                onError={() => {
                  // 错误已由 LazyImage 处理
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
            <div className={styles.taskListContainer} style={{ borderTop: '1px solid #e2e8f0' }}>
              {tasksLoading && tasks.length === 0 ? (
                <div className={styles.taskListLoading}>{t('messages.taskListLoading')}</div>
              ) : filteredTasks.length === 0 ? (
                <div className={styles.taskListEmpty}>
                  {taskSearchTerm.trim() ? (t('messages.noTasksFound') || '没有找到匹配的任务') : (t('messages.noTasks') || '暂无任务')}
                </div>
              ) : (
                filteredTasks.map(task => (
                  <TaskListItem
                    key={task.id}
                    task={task}
                    isActive={activeTaskId === task.id}
                    isMobile={isMobile}
                    onTaskClick={handleTaskClick}
                    onRemoveTask={handleRemoveTask}
                  />
                ))
              )}
            </div>
          </div>
        </div>
        
        {/* 右侧聊天区域 */}
        <div 
          className={styles.chatArea}
          style={{ 
            display: isMobile && !showMobileChat ? 'none' : 'flex', 
            position: isMobile ? 'absolute' : 'relative',
            width: isMobile ? '100%' : 'auto',
            height: isMobile ? '100vh' : 'auto',
            zIndex: isMobile ? 1001 : 'auto',
            left: isMobile ? '0' : 'auto',
            top: isMobile ? '0' : 'auto'
          }}
        ref={(el) => {
          // 保存右侧聊天区域的引用，用于计算按钮位置
          if (el) {
            (window as any).chatAreaRef = el;
          }
        }}>
          {/* 聊天头部 */}
          {isServiceMode ? (
            <div className={`${styles.chatHeader} ${styles.chatHeaderService}`}>
              {isMobile && (
                <button
                  onClick={() => setShowMobileChat(false)}
                  className={styles.chatHeaderServiceBackButton}
                >
                  ←
                </button>
              )}
              <LazyImage 
                src={'/static/service.png'} 
                alt={t('messages.service')} 
                className={styles.chatHeaderServiceAvatar}
                width={36}
                height={36}
                onError={() => {
                  // 错误已由 LazyImage 处理
                }}
              />
              <div className={styles.chatHeaderServiceInfo}>
                <div className={styles.chatHeaderServiceTitle}>
                  {t('messages.customerServiceCenter')}
                </div>
                <div className={styles.chatHeaderServiceSubtitle}>
                  <span>{t('messages.onlineService')}</span>
                  <div className={styles.chatHeaderServiceStatus}></div>
                </div>
              </div>
            </div>
          ) : activeTaskId && activeTask ? (
            <div className={styles.chatHeader}>
              {isMobile && (
                <button
                  onClick={() => setShowMobileChat(false)}
                  className={styles.chatHeaderBackButton}
                  style={{ marginRight: '8px' }}
                >
                  ←
                </button>
              )}
              {/* 任务图片 - 优先使用第一张任务图片，否则使用任务类型图片 */}
              <div 
                className={styles.chatHeaderTaskImage}
                onClick={() => setShowTaskDetailModal(true)}
              >
                {(activeTask.images && Array.isArray(activeTask.images) && activeTask.images.length > 0 && activeTask.images[0]) ? (
                  <LazyImage
                    src={getTaskImageUrl(activeTask.images[0], API_BASE_URL) || activeTask.images[0]}
                    alt={activeTask.title}
                    className={styles.chatHeaderTaskImageImg}
                    width={50}
                    height={50}
                    onError={() => {
                      // 如果任务图片加载失败，显示任务类型emoji图标
                      const placeholder = document.querySelector(`.${styles.chatHeaderTaskImagePlaceholder}`) as HTMLElement;
                      if (placeholder) {
                        placeholder.style.display = 'flex';
                      }
                    }}
                  />
                ) : (
                  <div className={styles.chatHeaderTaskImagePlaceholder}>
                    {getTaskTypeEmoji(activeTask.task_type)}
                  </div>
                )}
                {/* 占位符（仅在任务图片加载失败时显示） */}
                <div 
                  className={styles.chatHeaderTaskImagePlaceholder}
                  style={{
                    display: 'none',
                    position: 'absolute',
                    top: 0,
                    left: 0
                  }}
                >
                  {getTaskTypeEmoji(activeTask.task_type)}
                </div>
              </div>
              <div className={styles.chatHeaderTaskInfo} onClick={() => setShowTaskDetailModal(true)}>
                <h3 className={styles.chatHeaderTaskTitle}>
                  <TaskTitle
                    title={activeTask.title}
                    language={language}
                    taskId={activeTask.id}
                    task={activeTask}
                    autoTranslate={true}
                  />
                </h3>
                <div className={styles.chatHeaderTaskMeta}>
                  {activeTask.status === 'open' && !activeTask.taker_id && (
                    <span className={`${styles.taskStatusBadge} ${styles.taskStatusBadgeWaiting}`}>
                      {t('messages.taskStatusWaiting')}
                    </span>
                  )}
                  {activeTask.status === 'in_progress' && (
                    <span className={`${styles.taskStatusBadge} ${styles.taskStatusBadgeInProgress}`}>
                      {t('messages.taskStatusInProgress')}
                    </span>
                  )}
                  {activeTask.status === 'completed' && (
                    <span className={`${styles.taskStatusBadge} ${styles.taskStatusBadgeCompleted}`}>
                      {t('messages.taskStatusCompleted')}
                    </span>
                  )}
                  {activeTask.status === 'cancelled' && (
                    <span className={`${styles.taskStatusBadge} ${styles.taskStatusBadgeCancelled}`}>
                      {t('messages.taskStatusCancelled')}
                    </span>
                  )}
                </div>
              </div>
              {activeTask.poster_id === user?.id && activeTask.status === 'open' && !activeTask.taker_id && (
                <button
                  onClick={() => setShowApplicationListModal(true)}
                  className={styles.chatHeaderTaskButton}
                >
                  查看申请
                </button>
              )}
            </div>
          ) : null}
          
          {/* 消息区域 */}
          <div 
            ref={messagesContainerRef}
            style={{ 
              flex: 1, 
              overflowY: 'auto', 
              padding: '20px',
              background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
              position: 'relative'
            }}>
            {/* 系统警告（任务聊天，浮空在消息区域顶部） */}
            {chatMode === 'tasks' && activeTaskId && activeTask && showSystemWarning && (
              <div style={{
                position: 'sticky',
                top: '20px',
                zIndex: 100,
                display: 'flex',
                justifyContent: 'center',
                marginBottom: '16px',
                padding: '0 20px'
              }}>
                <div style={{
                  padding: '10px 16px',
                  background: 'linear-gradient(135deg, #fef3c7 0%, #fde68a 100%)',
                  borderRadius: '20px',
                  fontSize: '13px',
                  color: '#92400e',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '8px',
                  border: '1px solid #fbbf24',
                  boxShadow: '0 2px 8px rgba(251, 191, 36, 0.2)',
                  maxWidth: '90%',
                  backdropFilter: 'blur(10px)'
                }}>
                  <span style={{ fontSize: '16px', flexShrink: 0 }}>⚠️</span>
                  <span style={{ lineHeight: '1.4', flex: 1 }}>{t('messages.tradeWarning')}</span>
                  <button
                    onClick={() => setShowSystemWarning(false)}
                    style={{
                      background: 'rgba(146, 64, 14, 0.1)',
                      border: 'none',
                      borderRadius: '50%',
                      color: '#92400e',
                      cursor: 'pointer',
                      fontSize: '16px',
                      width: '20px',
                      height: '20px',
                      padding: 0,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                      transition: 'background 0.2s',
                      lineHeight: 1
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = 'rgba(146, 64, 14, 0.2)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'rgba(146, 64, 14, 0.1)';
                    }}
                  >
                    ×
                  </button>
                </div>
              </div>
            )}
            
            
            {isServiceMode && !serviceConnected ? (
              <div className={`${styles.emptyChatState} ${isMobile ? styles.emptyChatStateMobile : ''}`}>
                <div className={`${styles.emptyChatIcon} ${isMobile ? styles.emptyChatIconMobile : ''}`}>🎧</div>
                <div className={`${styles.emptyChatTitle} ${isMobile ? styles.emptyChatTitleMobile : ''}`}>
                  {t('messages.contactCustomerService')}
                </div>
                <div className={`${styles.emptyChatText} ${isMobile ? styles.emptyChatTextMobile : ''}`}>
                  {t('messages.ourTeamReadyToHelpWithButton')}
                </div>
              </div>
            ) : !activeTaskId && !isServiceMode ? (
              (
                <div className={`${styles.emptyChatState} ${isMobile ? styles.emptyChatStateMobile : ''}`}>
                  <div className={`${styles.emptyChatIcon} ${isMobile ? styles.emptyChatIconMobile : ''}`}>📋</div>
                  <div className={`${styles.emptyChatTitle} ${isMobile ? styles.emptyChatTitleMobile : ''}`}>
                    选择任务开始聊天
                  </div>
                  <div className={`${styles.emptyChatText} ${isMobile ? styles.emptyChatTextMobile : ''} ${styles.emptyChatTextNoMargin} ${isMobile ? styles.emptyChatTextNoMarginMobile : ''}`}>
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
                  <div className={styles.applicationCard}>
                    {activeTask.poster_id === user?.id ? (
                      <div>
                        <div className={styles.applicationCardHeader}>
                          <div className={styles.applicationCardTitle}>待处理申请</div>
                          {applications.length > 0 && (
                            <button
                              onClick={() => setShowApplicationListModal(true)}
                              className={styles.applicationCardButton}
                            >
                              查看全部 ({applications.length})
                            </button>
                          )}
                        </div>
                        {applications.length === 0 ? (
                          <div className={styles.applicationCardEmpty}>
                            暂无申请
                          </div>
                        ) : (
                          <div className={styles.applicationList}>
                            {applications.slice(0, 3).map((app: any) => (
                              <div
                                key={app.id}
                                className={styles.applicationItem}
                              >
                                <div className={styles.applicationItemHeader}>
                                  <LazyImage
                                    src={app.applicant_avatar || '/static/avatar1.png'}
                                    alt={app.applicant_name || '用户'}
                                    className={styles.applicationItemAvatar}
                                    width={32}
                                    height={32}
                                  />
                                  <div className={styles.applicationItemInfo}>
                                    <div className={styles.applicationItemName}>
                                      {app.applicant_name || '用户'}
                                    </div>
                                    <div className={styles.applicationItemTime}>
                                      {dayjs(app.created_at).format('MM-DD HH:mm')}
                                    </div>
                                  </div>
                                </div>
                                {app.message && (
                                  <div className={styles.applicationItemMessage}>
                                    {app.message}
                                  </div>
                                )}
                                {/* 议价信息 - 有议价显示金额，无议价显示"无议价" */}
                                {(() => {
                                  // 确保negotiated_price是数字类型
                                  const negotiatedPrice = app.negotiated_price !== undefined && app.negotiated_price !== null 
                                    ? (typeof app.negotiated_price === 'number' ? app.negotiated_price : parseFloat(String(app.negotiated_price)))
                                    : null;
                                  const hasNegotiation = negotiatedPrice !== null && !isNaN(negotiatedPrice) && negotiatedPrice > 0;
                                  
                                  return (
                                    <div style={{
                                      fontSize: '13px',
                                      fontWeight: 600,
                                      padding: '4px 8px',
                                      borderRadius: '4px',
                                      display: 'inline-block',
                                      marginBottom: '8px',
                                      ...(hasNegotiation ? {
                                        color: '#92400e',
                                        background: '#fef3c7'
                                      } : {
                                        color: '#6b7280',
                                        background: '#f3f4f6'
                                      })
                                    }}>
                                      {hasNegotiation
                                        ? `议价: £${negotiatedPrice.toFixed(2)} ${app.currency || 'GBP'}`
                                        : '无议价'}
                                    </div>
                                  );
                                })()}
                                {activeTask?.poster_id === user?.id && (
                                  <div className={styles.applicationItemActions} style={{ flexWrap: 'wrap' }}>
                                    <button
                                      onClick={async (e) => {
                                        e.stopPropagation();
                                        try {
                                          const response = await acceptApplication(activeTaskId, app.id);
                                          const responseData = response?.data || response;
                                          
                                          // 如果返回了支付信息，直接跳转到支付页面（新页面）
                                          if (responseData && responseData.client_secret && responseData.payment_intent_id) {
                                            // 构建支付页面 URL
                                            const params = new URLSearchParams({
                                              client_secret: responseData.client_secret,
                                              payment_intent_id: responseData.payment_intent_id,
                                            });
                                            if (responseData.amount) {
                                              params.set('amount', responseData.amount.toString());
                                            }
                                            if (responseData.amount_display) {
                                              params.set('amount_display', responseData.amount_display);
                                            }
                                            params.set('return_url', window.location.href);
                                            params.set('return_type', 'message');
                                            const paymentUrl = `/${language}/tasks/${activeTaskId}/payment?${params.toString()}`;
                                            const paymentWindow = window.open(paymentUrl, '_blank');
                                            
                                            if (!paymentWindow) {
                                              alert('无法打开支付页面，请检查浏览器弹窗设置');
                                            }
                                            
                                            // 监听支付成功消息
                                            const handlePaymentSuccess = (event: MessageEvent) => {
                                              if (event.data?.type === 'payment_success' && event.data?.taskId === activeTaskId) {
                                                message.success(t('messages.notifications.applicationAccepted') || '申请已批准！');
                                                if (activeTaskId) {
                                                  loadTaskMessages(activeTaskId);
                                                  loadApplications(activeTaskId);
                                                  loadTasks();
                                                }
                                                window.removeEventListener('message', handlePaymentSuccess);
                                              }
                                            };
                                            window.addEventListener('message', handlePaymentSuccess);
                                            
                                            // 重新加载任务和申请列表（在打开支付页面后）
                                            if (activeTaskId) {
                                              setTimeout(() => {
                                                loadTaskMessages(activeTaskId);
                                                loadApplications(activeTaskId);
                                                loadTasks();
                                              }, 500);
                                            }
                                          } else {
                                            // 如果没有支付信息，说明可能已经支付成功或使用优惠券全额抵扣
                                            if (activeTaskId) {
                                          await loadTaskMessages(activeTaskId);
                                          await loadApplications(activeTaskId);
                                          await loadTasks();
                                            }
                                          }
                                        } catch (error: any) {
                                                                                    alert(getErrorMessage(error));
                                        }
                                      }}
                                      className={`${styles.applicationActionButton} ${styles.applicationActionButtonAccept}`}
                                    >
                                      接受
                                    </button>
                                    <button
                                      onClick={async (e) => {
                                        e.stopPropagation();
                                        try {
                                          await rejectApplication(activeTaskId, app.id);
                                          alert(t('messages.notifications.applicationRejected'));
                                          await loadApplications(activeTaskId);
                                        } catch (error: any) {
                                                                                    alert(getErrorMessage(error));
                                        }
                                      }}
                                      className={`${styles.applicationActionButton} ${styles.applicationActionButtonReject}`}
                                    >
                                      拒绝
                                    </button>
                                    <button
                                      onClick={(e) => {
                                        e.stopPropagation();
                                        setSelectedApplication(app);
                                        setMessageContent('');
                                        setMessageNegotiatedPrice(undefined);
                                        setIsMessageNegotiateChecked(false);
                                        setShowMessageModal(true);
                                      }}
                                      className={`${styles.applicationActionButton} ${styles.applicationActionButtonMessage}`}
                                    >
                                      留言
                                    </button>
                                  </div>
                                )}
                              </div>
                            ))}
                            {applications.length > 3 && (
                              <div className={styles.applicationMoreButton}>
                                <button
                                  onClick={() => setShowApplicationListModal(true)}
                                  className={styles.applicationMoreButtonLink}
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
                          <div className={styles.applicationStatusCard}>
                            ✓ 您已申请此任务
                          </div>
                        ) : (
                          <button
                            onClick={() => {
                              // 重置议价相关状态
                              setNegotiatedPrice(undefined);
                              setIsNegotiateChecked(false);
                              setShowApplicationModal(true);
                            }}
                            className={styles.applicationSubmitButton}
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
                      {taskMessagesLoading ? t('messages.taskListLoading') : t('messages.loadMore')}
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

                {/* 已完成任务清理提醒 - 作为系统消息显示在消息列表中 */}
                {(() => {
                  const shouldShow = chatMode === 'tasks' && activeTaskId && activeTask && activeTask.status === 'completed';
                  
                  if (!shouldShow) {
                    return null;
                  }
                  
                  try {
                    const completedAt = activeTask?.completed_at || new Date().toISOString();
                    const completedDate = new Date(completedAt);
                    const now = new Date();
                    const cleanupDate = new Date(completedDate.getTime() + 3 * 24 * 60 * 60 * 1000); // 完成时间 + 3天
                    const timeRemaining = cleanupDate.getTime() - now.getTime();
                    
                    // 任务一完成就显示提醒，无论是否已到清理时间
                    if (timeRemaining > 0) {
                      // 还没到清理时间，显示剩余时间
                      const totalHours = timeRemaining / (60 * 60 * 1000);
                      const totalDays = timeRemaining / (24 * 60 * 60 * 1000);
                      
                      // 显示文本：如果剩余时间少于1天，显示小时；否则显示天数（向下取整，更准确）
                      let timeText: string;
                      if (totalDays >= 1) {
                        const days = Math.floor(totalDays);
                        const remainingHours = Math.floor(totalHours % 24);
                        if (remainingHours > 0 && days < 3) {
                          // 如果少于3天且有剩余小时，显示"X天X小时"
                          timeText = `${days} 天 ${remainingHours} 小时`;
                        } else {
                          // 否则只显示天数
                          timeText = `${days} 天`;
                        }
                      } else {
                        // 少于1天，显示小时
                        const hours = Math.floor(totalHours);
                        timeText = `${hours} 小时`;
                      }
                      
                      return (
                        <div
                          key="cleanup-reminder-system"
                          style={{
                            display: 'flex',
                            justifyContent: 'center',
                            marginBottom: '12px',
                            padding: '0 16px'
                          }}
                        >
                          <div style={{
                            padding: '8px 14px',
                            borderRadius: '12px',
                            backgroundColor: '#dbeafe',
                            color: '#1e40af',
                            fontSize: '13px',
                            textAlign: 'center',
                            maxWidth: '80%',
                            border: '1px solid #60a5fa',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '6px'
                          }}>
                            <span style={{ fontSize: '14px', flexShrink: 0 }}>ℹ️</span>
                            <span style={{ lineHeight: '1.4' }}>
                              将在 <strong>{timeText}</strong> 后清理相关图片与文件
                            </span>
                          </div>
                        </div>
                      );
                    } else {
                      // 已经过了清理时间，显示已清理提示
                      return (
                        <div
                          key="cleanup-done-system"
                          style={{
                            display: 'flex',
                            justifyContent: 'center',
                            marginBottom: '12px',
                            padding: '0 16px'
                          }}
                        >
                          <div style={{
                            padding: '8px 14px',
                            borderRadius: '12px',
                            backgroundColor: '#f3f4f6',
                            color: '#6b7280',
                            fontSize: '13px',
                            textAlign: 'center',
                            maxWidth: '80%',
                            border: '1px solid #d1d5db',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '6px'
                          }}>
                            <span style={{ fontSize: '14px', flexShrink: 0 }}>✅</span>
                            <span style={{ lineHeight: '1.4' }}>
                              已清理相关图片与文件
                            </span>
                          </div>
                        </div>
                      );
                    }
                  } catch (error) {
                    // 即使计算失败，也显示一个基本提醒
                    return (
                      <div
                        key="cleanup-fallback-system"
                        style={{
                          display: 'flex',
                          justifyContent: 'center',
                          marginBottom: '12px',
                          padding: '0 16px'
                        }}
                      >
                        <div style={{
                          padding: '8px 14px',
                          borderRadius: '12px',
                          backgroundColor: '#dbeafe',
                          color: '#1e40af',
                          fontSize: '13px',
                          textAlign: 'center',
                          maxWidth: '80%',
                          border: '1px solid #60a5fa',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '6px'
                        }}>
                          <span style={{ fontSize: '14px', flexShrink: 0 }}>ℹ️</span>
                          <span style={{ lineHeight: '1.4' }}>
                            将在 <strong>3天</strong> 后清理相关图片与文件
                          </span>
                        </div>
                      </div>
                    );
                  }
                })()}

                {taskMessages.map((msg, idx) => {
                  const isOwn = msg.sender_id === user?.id;
                  // 系统消息判断：检查 message_type 或 sender_id 为 null/undefined
                  const isSystemMessage = msg.message_type === 'system' || !msg.sender_id || msg.sender_id === 'system' || msg.isSystemMessage;
                  // 显示头像的条件：第一条消息，或者上一条消息的发送者不同（系统消息不显示头像）
                  const showAvatar = !isSystemMessage && (idx === 0 || (taskMessages[idx - 1] && taskMessages[idx - 1].sender_id !== msg.sender_id));
                  
                  // 系统消息居中显示
                  if (isSystemMessage) {
                    // 检查是否是退款申请系统消息
                    let refundMeta = null;
                    try {
                      if (msg.meta) {
                        const meta = typeof msg.meta === 'string' ? JSON.parse(msg.meta) : msg.meta;
                        if (meta.system_action === 'refund_request_created' || meta.system_action === 'refund_completed') {
                          refundMeta = meta;
                        }
                      }
                    } catch (e) {
                      // 忽略解析错误
                    }
                    
                    // 如果是退款申请消息，使用卡片式布局
                    if (refundMeta) {
                      return (
                        <div
                          key={msg.id}
                          style={{
                            display: 'flex',
                            justifyContent: 'center',
                            marginBottom: '16px',
                            padding: '0 16px'
                          }}
                        >
                          <div style={{
                            maxWidth: '85%',
                            padding: '16px',
                            borderRadius: '12px',
                            backgroundColor: refundMeta.system_action === 'refund_completed' ? '#d4edda' : '#fff3cd',
                            border: `1px solid ${refundMeta.system_action === 'refund_completed' ? '#28a745' : '#ffc107'}`,
                            boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
                          }}>
                            <div style={{
                              display: 'flex',
                              alignItems: 'center',
                              marginBottom: '8px',
                              gap: '8px'
                            }}>
                              <span style={{
                                fontSize: '18px'
                              }}>
                                {refundMeta.system_action === 'refund_completed' ? '✅' : '💰'}
                              </span>
                              <strong style={{
                                fontSize: '14px',
                                color: refundMeta.system_action === 'refund_completed' ? '#155724' : '#856404'
                              }}>
                                {refundMeta.system_action === 'refund_completed' 
                                  ? (language === 'zh' ? '退款已完成' : 'Refund Completed')
                                  : (language === 'zh' ? '退款申请' : 'Refund Request')}
                              </strong>
                            </div>
                            <div style={{
                              fontSize: '13px',
                              color: '#666',
                              lineHeight: '1.5',
                              marginBottom: '8px'
                            }}>
                              {msg.content}
                            </div>
                            {/* 显示证据文件 */}
                            {msg.attachments && msg.attachments.length > 0 && (
                              <div style={{
                                marginTop: '12px',
                                paddingTop: '12px',
                                borderTop: '1px solid rgba(0,0,0,0.1)'
                              }}>
                                <div style={{
                                  fontSize: '12px',
                                  color: '#666',
                                  marginBottom: '8px',
                                  fontWeight: '500'
                                }}>
                                  {language === 'zh' ? '证据文件：' : 'Evidence Files: '}
                                </div>
                                <div style={{
                                  display: 'flex',
                                  flexDirection: 'column',
                                  gap: '8px'
                                }}>
                                  {msg.attachments.map((attachment: any, idx: number) => {
                                    // 检查是否是图片
                                    const isImage = attachment.attachment_type === 'image' || 
                                                   (attachment.url && /\.(jpg|jpeg|png|gif|webp)$/i.test(attachment.url)) ||
                                                   attachment.blob_id;
                                    
                                    // 检查是否是文件
                                    const isFile = attachment.attachment_type === 'file' || 
                                                  (attachment.url && !isImage);
                                    
                                    const fileUrl = attachment.url || 
                                                   (attachment.blob_id ? `/api/private-file?file=${attachment.blob_id}` : null);
                                    
                                    return (
                                      <div key={idx}>
                                        {isImage && attachment.blob_id ? (
                                          // 图片证据：使用PrivateImageDisplay显示预览
                                          <div style={{
                                            maxWidth: '200px',
                                            borderRadius: '8px',
                                            overflow: 'hidden',
                                            border: '1px solid rgba(0,0,0,0.1)'
                                          }}>
                                            <PrivateImageDisplay
                                              imageId={attachment.blob_id}
                                              currentUserId={user?.id || ''}
                                              style={{
                                                width: '100%',
                                                height: 'auto',
                                                maxHeight: '150px',
                                                objectFit: 'contain',
                                                cursor: 'pointer'
                                              }}
                                              alt={language === 'zh' ? `证据图片 ${idx + 1}` : `Evidence Image ${idx + 1}`}
                                            />
                                          </div>
                                        ) : isFile && fileUrl ? (
                                          // 文件证据：显示可点击的下载链接
                                          <a
                                            href={fileUrl}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            download
                                            style={{
                                              display: 'flex',
                                              alignItems: 'center',
                                              gap: '8px',
                                              padding: '8px 12px',
                                              backgroundColor: '#f8f9fa',
                                              borderRadius: '6px',
                                              textDecoration: 'none',
                                              color: '#3b82f6',
                                              fontSize: '12px',
                                              transition: 'background-color 0.2s',
                                              border: '1px solid #e5e7eb'
                                            }}
                                            onMouseEnter={(e) => {
                                              e.currentTarget.style.backgroundColor = '#e5e7eb';
                                            }}
                                            onMouseLeave={(e) => {
                                              e.currentTarget.style.backgroundColor = '#f8f9fa';
                                            }}
                                          >
                                            <span style={{ fontSize: '16px' }}>📎</span>
                                            <span style={{ fontWeight: '500' }}>
                                              {attachment.meta?.filename || 
                                               (attachment.meta ? (typeof attachment.meta === 'string' ? JSON.parse(attachment.meta).filename : null) : null) ||
                                               (language === 'zh' ? `证据文件 ${idx + 1}` : `Evidence File ${idx + 1}`)}
                                            </span>
                                            <span style={{ fontSize: '10px', opacity: 0.7 }}>⬇</span>
                                          </a>
                                        ) : (
                                          // 未知类型：显示基本信息
                                          <div style={{
                                            padding: '8px 12px',
                                            backgroundColor: '#f8f9fa',
                                            borderRadius: '6px',
                                            fontSize: '12px',
                                            color: '#495057'
                                          }}>
                                            {language === 'zh' ? `文件 ${idx + 1}` : `File ${idx + 1}`}
                                          </div>
                                        )}
                                      </div>
                                    );
                                  })}
                                </div>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    }
                    
                    // 普通系统消息
                    return (
                      <div
                        key={msg.id}
                        style={{
                          display: 'flex',
                          justifyContent: 'center',
                          marginBottom: '12px',
                          padding: '0 16px'
                        }}
                      >
                        <div style={{
                          padding: '6px 12px',
                          borderRadius: '12px',
                          backgroundColor: '#f3f4f6',
                          color: '#6b7280',
                          fontSize: '13px',
                          textAlign: 'center',
                          maxWidth: '80%'
                        }}>
                          {msg.content}
                        </div>
                      </div>
                    );
                  }
                  
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
                        <LazyImage
                          src={msg.sender_avatar || '/static/avatar1.png'}
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
                          onError={(e) => {
                            // 如果头像加载失败，使用默认头像
                            const img = e.currentTarget as HTMLImageElement;
                            if (img && img.src !== '/static/avatar1.png') {
                              img.src = '/static/avatar1.png';
                            }
                          }}
                          onMouseEnter={(e) => {
                            (e.currentTarget as HTMLElement).style.transform = 'scale(1.1)';
                          }}
                          onMouseLeave={(e) => {
                            (e.currentTarget as HTMLElement).style.transform = 'scale(1)';
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
                              display: 'flex',
                              alignItems: 'center',
                              gap: '6px'
                            }}
                          >
                            <span style={{ textDecoration: 'underline' }}>
                              {msg.sender_name}
                            </span>
                            {/* 多人任务：显示任务达人（房主）标识 */}
                            {activeTask && activeTask.is_multi_participant && (
                              (activeTask.expert_creator_id === msg.sender_id || activeTask.taker_id === msg.sender_id) && (
                                <span style={{
                                  fontSize: '10px',
                                  padding: '2px 6px',
                                  borderRadius: '10px',
                                  background: 'linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%)',
                                  color: '#fff',
                                  fontWeight: 600,
                                  textDecoration: 'none',
                                  boxShadow: '0 1px 3px rgba(0,0,0,0.2)'
                                }}>
                                  🏠 房主
                                </span>
                              )
                            )}
                          </div>
                        )}
                        <div 
                          onContextMenu={(e) => {
                            e.preventDefault();
                            if (navigator.clipboard) {
                              navigator.clipboard.writeText(msg.content).then(() => {
                                showToast('success', t('messages.notifications.messageCopied'));
                              }).catch(() => {
                                showToast('error', t('messages.notifications.copyFailed'));
                              });
                            }
                          }}
                          style={{
                            padding: '8px 12px',
                            borderRadius: '12px',
                            backgroundColor: isOwn ? '#3b82f6' : 'white',
                            color: isOwn ? 'white' : '#1f2937',
                            fontSize: '16px',
                            wordBreak: 'break-word',
                            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
                            cursor: 'context-menu',
                            position: 'relative',
                            opacity: msg.isPending ? 0.7 : 1,
                            transition: 'opacity 0.3s'
                          }}
                        >
                          {(() => {
                            const imageIdForMsg = msg.image_id || (msg.content.startsWith('[图片]') ? msg.content.replace(/^\[图片\]\s*/, '').trim() : '');
                            return imageIdForMsg ? (
                            <div className={styles.messageImage}>
                              <PrivateImageDisplay
                                imageId={imageIdForMsg}
                                currentUserId={user?.id || ''}
                                className={styles.messageImageContent}
                                style={{ width: 150, height: 150, maxWidth: '100%', maxHeight: 150 }}
                                alt="图片"
                                onClick={async () => {
                                  // 生成图片URL用于预览
                                  try {
                                    const response = await api.post('/api/messages/generate-image-url', {
                                      image_id: imageIdForMsg
                                    });
                                    if (response.data.success) {
                                      setPreviewImageUrl(response.data.image_url);
                                      setShowImagePreview(true);
                                    }
                                  } catch (error) {
                                                                      }
                                }}
                              />
                            </div>
                          ) : (() => {
                            const messageKey = getMessageKey(msg);
                            const hasTranslation = messageTranslations.has(messageKey);
                            const isTranslating = translatingMessages.has(messageKey);
                            const translatedText = messageTranslations.get(messageKey);
                            const textLang = detectTextLanguage(msg.content);
                            const needsTranslation = textLang !== language && !msg.content.startsWith('[图片]') && !msg.content.startsWith('[文件]');
                            
                            return (
                              <div>
                                <div style={{ marginBottom: hasTranslation ? '8px' : '0' }}>
                                  {hasTranslation ? translatedText : msg.content}
                                </div>
                                {hasTranslation && (
                                  <div style={{ 
                                    fontSize: '12px', 
                                    color: isOwn ? 'rgba(255,255,255,0.7)' : '#9ca3af',
                                    fontStyle: 'italic',
                                    marginTop: '4px',
                                    paddingTop: '4px',
                                    borderTop: `1px solid ${isOwn ? 'rgba(255,255,255,0.2)' : '#e5e7eb'}`
                                  }}>
                                    {msg.content}
                                  </div>
                                )}
                                {needsTranslation && (
                                  <button
                                    onClick={() => handleTranslateMessage({ id: msg.id, from: msg.sender_name || '', content: msg.content, created_at: msg.created_at }, msg.content)}
                                    disabled={isTranslating}
                                    style={{
                                      marginTop: '8px',
                                      padding: '4px 8px',
                                      background: isOwn ? 'rgba(255,255,255,0.2)' : '#f3f4f6',
                                      color: isOwn ? 'white' : '#3b82f6',
                                      border: 'none',
                                      borderRadius: '4px',
                                      fontSize: '11px',
                                      cursor: isTranslating ? 'not-allowed' : 'pointer',
                                      opacity: isTranslating ? 0.6 : 1,
                                      display: 'flex',
                                      alignItems: 'center',
                                      gap: '4px'
                                    }}
                                  >
                                    {isTranslating ? '⏳ 翻译中...' : hasTranslation ? '🔄 显示原文' : '🌐 翻译'}
                                  </button>
                                )}
                              </div>
                            );
                          })();
                          })()}
                          {msg.attachments && msg.attachments.length > 0 && (
                            <div style={{ marginTop: '8px' }}>
                              {msg.attachments.map((att: any) => (
                                <div key={att.id} style={{ marginTop: '4px' }}>
                                  {att.attachment_type === 'image' && (att.url || att.blob_id) && (
                                    <div>
                                      {/* 如果有blob_id（image_id），使用 PrivateImageDisplay 处理私有图片 */}
                                      {att.blob_id ? (
                                        <PrivateImageDisplay
                                          imageId={att.blob_id}
                                          currentUserId={user?.id || ''}
                                          style={{ 
                                            maxWidth: '200px', 
                                            maxHeight: '200px',
                                            borderRadius: '6px', 
                                            cursor: 'pointer',
                                            objectFit: 'cover'
                                          }}
                                          onClick={() => {
                                            // 对于私有图片，需要先获取URL再预览
                                            api.post('/api/messages/generate-image-url', {
                                              image_id: att.blob_id
                                            }).then((response: any) => {
                                              if (response.data.success) {
                                                setPreviewImageUrl(response.data.image_url);
                                                setShowImagePreview(true);
                                              }
                                            }).catch(() => {
                                              alert('无法加载图片');
                                            });
                                          }}
                                          alt="完成证据图片"
                                        />
                                      ) : att.url ? (
                                        /* 如果有完整URL，直接使用 LazyImage */
                                        <LazyImage
                                          src={att.url}
                                          alt="证据图片"
                                          style={{ maxWidth: '200px', borderRadius: '6px', cursor: 'pointer' }}
                                          onClick={() => {
                                            setPreviewImageUrl(att.url);
                                            setShowImagePreview(true);
                                          }}
                                        />
                                      ) : null}
                                    </div>
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
                                        href={att.url || (att.blob_id ? `/api/private-file?file=${att.blob_id}` : '#')}
                                        target="_blank"
                                        rel="noopener noreferrer"
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
                                        {att.meta?.filename || (att.meta ? JSON.parse(att.meta).filename : null) || '下载证据文件'}
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
              const isTaskCard = msg.message_type === 'task_card' && msg.task_id;
              
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
                    ) : isTaskCard ? (
                      <div style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 12,
                        padding: '8px'
                      }}>
                        <div style={{
                          fontSize: 24,
                          width: 40,
                          height: 40,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          background: msg.from === meText ? 'rgba(255,255,255,0.2)' : '#f0f0f0',
                          borderRadius: 8
                        }}>
                          📋
                        </div>
                        <div>
                          <div style={{ 
                            fontSize: 14, 
                            fontWeight: 600,
                            marginBottom: 4
                          }}>
                            任务卡片
                          </div>
                          <div style={{ 
                            fontSize: 12, 
                            opacity: 0.8
                          }}>
                            已发送任务信息
                          </div>
                        </div>
                      </div>
                    ) : isImageMessage ? (
                      <LazyImage 
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
                    ) : (() => {
                      const messageKey = getMessageKey(msg);
                      const hasTranslation = messageTranslations.has(messageKey);
                      const isTranslating = translatingMessages.has(messageKey);
                      const translatedText = messageTranslations.get(messageKey);
                      const textLang = detectTextLanguage(msg.content);
                      const needsTranslation = textLang !== language && !isSystemMessage && !isImageMessage && !isFileMessage;
                      
                      return (
                        <div>
                          <div style={{ fontSize: '16px', lineHeight: '1.5', marginBottom: hasTranslation ? '8px' : '0' }}>
                            {hasTranslation ? translatedText : msg.content}
                          </div>
                          {hasTranslation && (
                            <div style={{ 
                              fontSize: '12px', 
                              color: msg.from === meText ? 'rgba(255,255,255,0.7)' : '#9ca3af',
                              fontStyle: 'italic',
                              marginTop: '4px',
                              paddingTop: '4px',
                              borderTop: `1px solid ${msg.from === meText ? 'rgba(255,255,255,0.2)' : '#e5e7eb'}`
                            }}>
                              {msg.content}
                            </div>
                          )}
                          {needsTranslation && (
                            <button
                              onClick={() => handleTranslateMessage(msg, msg.content)}
                              disabled={isTranslating}
                              style={{
                                marginTop: '8px',
                                padding: '4px 8px',
                                background: msg.from === meText ? 'rgba(255,255,255,0.2)' : '#f3f4f6',
                                color: msg.from === meText ? 'white' : '#3b82f6',
                                border: 'none',
                                borderRadius: '4px',
                                fontSize: '11px',
                                cursor: isTranslating ? 'not-allowed' : 'pointer',
                                opacity: isTranslating ? 0.6 : 1,
                                display: 'flex',
                                alignItems: 'center',
                                gap: '4px'
                              }}
                            >
                              {isTranslating ? '⏳ 翻译中...' : hasTranslation ? '🔄 显示原文' : '🌐 翻译'}
                            </button>
                          )}
                        </div>
                      );
                    })()}
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
            <div 
              ref={inputAreaRef}
              className={styles.inputArea}>
              {/* 图片预览（桌面端） */}
              {imagePreview && !isMobile && (
                <div style={{
                  padding: '12px',
                  background: '#f8fafc',
                  borderRadius: '8px',
                  border: '1px solid #e5e7eb',
                  position: 'relative'
                }}>
                  <button
                    onClick={() => {
                      setImagePreview(null);
                      setSelectedImage(null);
                    }}
                    style={{
                      position: 'absolute',
                      top: '8px',
                      right: '8px',
                      background: 'rgba(0,0,0,0.5)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '50%',
                      width: '24px',
                      height: '24px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '16px',
                      lineHeight: 1
                    }}
                  >
                    ×
                  </button>
                  <LazyImage
                    src={imagePreview}
                    alt="预览"
                    style={{
                      maxWidth: '200px',
                      maxHeight: '200px',
                      borderRadius: '8px'
                    }}
                  />
                  <div style={{
                    marginTop: '8px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    fontSize: '12px',
                    color: '#6b7280'
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
                </div>
              )}
              
              {/* 文件预览 */}
              {filePreview && !isMobile && (
                <div style={{
                  padding: '12px',
                  background: '#f8fafc',
                  borderRadius: '8px',
                  border: '1px solid #e5e7eb',
                  position: 'relative'
                }}>
                  <button
                    onClick={() => {
                      setFilePreview(null);
                      setSelectedFile(null);
                    }}
                    style={{
                      position: 'absolute',
                      top: '8px',
                      right: '8px',
                      background: 'rgba(0,0,0,0.5)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '50%',
                      width: '24px',
                      height: '24px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '16px',
                      lineHeight: 1
                    }}
                  >
                    ×
                  </button>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    fontSize: '14px',
                    color: '#374151'
                  }}>
                    📎 {selectedFile?.name || '文件'}
                  </div>
                </div>
              )}
              
              {/* 功能按钮行 */}
              <div className={styles.inputActionButtons}>
                {/* 表情按钮 */}
                <button
                  data-emoji-button
                  onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                  disabled={!serviceConnected || isSending}
                  className={styles.inputActionButton}
                  title="表情"
                >
                  😊
                </button>
                
                {/* 图片上传按钮 */}
                <label
                  className={styles.inputActionButton}
                  style={{
                    cursor: (!serviceConnected || isSending || uploadingImage) ? 'not-allowed' : 'pointer',
                    opacity: (!serviceConnected || isSending || uploadingImage) ? 0.5 : 1
                  }}
                  title={t('messages.sendImage')}
                >
                  <input
                    type="file"
                    accept="image/jpeg,image/jpg,image/png,image/gif,image/webp,image/bmp,image/svg+xml"
                    onChange={handleImageSelect}
                    disabled={!serviceConnected || isSending || uploadingImage}
                    className={styles.inputActionButtonHidden}
                  />
                  {uploadingImage ? '⏳' : '📷'}
                </label>
                
                {/* 文件上传按钮 */}
                <label
                  className={styles.inputActionButton}
                  style={{
                    cursor: (!serviceConnected || isSending || uploadingFile) ? 'not-allowed' : 'pointer',
                    opacity: (!serviceConnected || isSending || uploadingFile) ? 0.5 : 1
                  }}
                  title={t('messages.sendFile')}
                >
                  <input
                    type="file"
                    onChange={handleFileSelect}
                    disabled={!serviceConnected || isSending || uploadingFile}
                    className={styles.inputActionButtonHidden}
                  />
                  {uploadingFile ? '⏳' : '📎'}
                </label>
                
                {/* 发送任务卡片按钮 */}
                <button
                  onClick={() => {
                    if (!serviceConnected) {
                      alert('请先连接客服');
                      return;
                    }
                    loadUserTasks();
                    setShowTaskCardModal(true);
                  }}
                  disabled={!serviceConnected || isSending}
                  className={styles.inputActionButton}
                  style={{
                    cursor: (!serviceConnected || isSending) ? 'not-allowed' : 'pointer',
                    opacity: (!serviceConnected || isSending) ? 0.5 : 1
                  }}
                  title="发送任务卡片"
                >
                  📋
                </button>
                
                {/* 连接客服/结束对话按钮 */}
                <button
                  onClick={serviceConnected ? handleEndConversation : handleContactCustomerService}
                  disabled={isConnectingToService}
                  className={`${styles.serviceConnectButton} ${isConnectingToService ? '' : serviceConnected ? styles.serviceConnectButtonEnd : styles.serviceConnectButtonConnect}`}
                  title={serviceConnected ? '结束对话' : '连接客服'}
                >
                  {isConnectingToService ? '连接中...' : serviceConnected ? '结束对话' : '连接客服'}
                </button>
              </div>
              
              {/* 输入框和发送按钮 */}
              <div className={styles.inputContainer}>
                <div className={styles.inputWrapper}>
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
                    className={styles.messageInput}
                  />
                </div>
                <button
                  onClick={handleSend}
                  disabled={!serviceConnected || !input.trim() || isSending}
                  className={styles.sendButton}
                  style={{
                    background: serviceConnected && input.trim() && !isSending
                      ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)'
                      : '#cbd5e1'
                  }}
                >
                  {isSending ? '发送中...' : '发送'}
                </button>
              </div>
              
              {/* 表情选择器 */}
              {showEmojiPicker && (
                <div
                  data-emoji-picker
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(8, 1fr)',
                    gap: '8px',
                    padding: '16px',
                    background: '#fff',
                    border: '1px solid #e5e7eb',
                    borderRadius: '12px',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                    maxHeight: '200px',
                    overflowY: 'auto',
                    position: 'absolute',
                    bottom: '80px',
                    left: '24px',
                    right: '24px',
                    zIndex: 1000
                  }}
                >
                  {EMOJI_LIST.map((emoji, idx) => (
                    <button
                      key={idx}
                      onClick={() => addEmoji(emoji)}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        cursor: 'pointer',
                        fontSize: '20px',
                        padding: '8px',
                        borderRadius: '4px',
                        transition: 'background 0.2s'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#f3f4f6';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'transparent';
                      }}
                    >
                      {emoji}
                    </button>
                  ))}
                </div>
              )}
              
              {/* 桌面端发送图片按钮 */}
              {imagePreview && !isMobile && (
                <button
                  onClick={sendImage}
                  disabled={uploadingImage || isSending || !serviceConnected}
                  style={{
                    padding: '10px 20px',
                    background: (uploadingImage || isSending || !serviceConnected) ? '#cbd5e1' : 'linear-gradient(135deg, #10b981, #059669)',
                    color: 'white',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    cursor: (uploadingImage || isSending || !serviceConnected) ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s ease',
                    alignSelf: 'flex-start'
                  }}
                >
                  {uploadingImage ? t('messages.uploading') : t('messages.sendingImage')}
                </button>
              )}
              
              {/* 桌面端发送文件按钮 */}
              {filePreview && !isMobile && selectedFile && (
                <button
                  onClick={sendFile}
                  disabled={uploadingFile || isSending || !serviceConnected}
                  style={{
                    padding: '10px 20px',
                    background: (uploadingFile || isSending || !serviceConnected) ? '#cbd5e1' : 'linear-gradient(135deg, #10b981, #059669)',
                    color: 'white',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    cursor: (uploadingFile || isSending || !serviceConnected) ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s ease',
                    alignSelf: 'flex-start'
                  }}
                >
                  {uploadingFile ? t('messages.uploading') : t('messages.sendingFile')}
                </button>
              )}
            </div>
          ) : chatMode === 'tasks' && activeTaskId && activeTask ? (
            <div 
              ref={taskInputAreaRef}
              style={{
                padding: '16px 24px',
                borderTop: '1px solid #e2e8f0',
                background: 'white',
                display: 'flex',
                flexDirection: 'column',
                gap: '12px',
                position: 'relative'
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
                  {t('messages.taskMustStartBeforeMessage')}
                </div>
              )}
              
              {/* 图片预览（桌面端） */}
              {imagePreview && !isMobile && (
                <div style={{
                  padding: '12px',
                  background: '#f8fafc',
                  borderRadius: '8px',
                  border: '1px solid #e5e7eb',
                  position: 'relative'
                }}>
                  <button
                    onClick={() => {
                      setImagePreview(null);
                      setSelectedImage(null);
                    }}
                    style={{
                      position: 'absolute',
                      top: '8px',
                      right: '8px',
                      background: 'rgba(0,0,0,0.5)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '50%',
                      width: '24px',
                      height: '24px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '16px',
                      lineHeight: 1
                    }}
                  >
                    ×
                  </button>
                  <LazyImage
                    src={imagePreview}
                    alt="预览"
                    style={{
                      maxWidth: '200px',
                      maxHeight: '200px',
                      borderRadius: '8px'
                    }}
                  />
                  <div style={{
                    marginTop: '8px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    fontSize: '12px',
                    color: '#6b7280'
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
                </div>
              )}
              
              {/* 功能按钮行 */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                paddingBottom: '8px',
                borderBottom: '1px solid #e5e7eb'
              }}>
                {/* 表情按钮 */}
                <button
                  data-emoji-button
                  onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                  disabled={
                    activeTask.status === 'completed' ||
                    (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                    isSending
                  }
                  style={{
                    padding: '8px 12px',
                    background: 'transparent',
                    border: '1px solid #e5e7eb',
                    cursor: (
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending
                    ) ? 'not-allowed' : 'pointer',
                    fontSize: '18px',
                    opacity: (activeTask.status === 'completed' || (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id)) ? 0.5 : 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    borderRadius: '8px',
                    transition: 'all 0.2s'
                  }}
                  onMouseEnter={(e) => {
                    if (!(
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending
                    )) {
                      e.currentTarget.style.background = '#f3f4f6';
                      e.currentTarget.style.borderColor = '#3b82f6';
                    }
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'transparent';
                    e.currentTarget.style.borderColor = '#e5e7eb';
                  }}
                  title="表情"
                >
                  😊
                </button>
                
                {/* 图片上传按钮 */}
                <label
                  style={{
                    padding: '8px 12px',
                    background: 'transparent',
                    border: '1px solid #e5e7eb',
                    cursor: (
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending ||
                      uploadingImage
                    ) ? 'not-allowed' : 'pointer',
                    fontSize: '18px',
                    opacity: (activeTask.status === 'completed' || (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id)) ? 0.5 : 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    borderRadius: '8px',
                    transition: 'all 0.2s'
                  }}
                  onMouseEnter={(e) => {
                    if (!(
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending ||
                      uploadingImage
                    )) {
                      e.currentTarget.style.background = '#f3f4f6';
                      e.currentTarget.style.borderColor = '#3b82f6';
                    }
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'transparent';
                    e.currentTarget.style.borderColor = '#e5e7eb';
                  }}
                  title={t('messages.sendImage')}
                >
                  <input
                    type="file"
                    accept="image/jpeg,image/jpg,image/png,image/gif,image/webp,image/bmp,image/svg+xml"
                    onChange={handleImageSelect}
                    disabled={
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending ||
                      uploadingImage
                    }
                    style={{ display: 'none' }}
                  />
                  {uploadingImage ? '⏳' : '📷'}
                </label>
                
                {/* 文件上传按钮 */}
                <label
                  style={{
                    padding: '8px 12px',
                    background: 'transparent',
                    border: '1px solid #e5e7eb',
                    cursor: (
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending ||
                      uploadingFile
                    ) ? 'not-allowed' : 'pointer',
                    fontSize: '18px',
                    opacity: (activeTask.status === 'completed' || (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id)) ? 0.5 : 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    borderRadius: '8px',
                    transition: 'all 0.2s'
                  }}
                  onMouseEnter={(e) => {
                    if (!(
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending ||
                      uploadingFile
                    )) {
                      e.currentTarget.style.background = '#f3f4f6';
                      e.currentTarget.style.borderColor = '#3b82f6';
                    }
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'transparent';
                    e.currentTarget.style.borderColor = '#e5e7eb';
                  }}
                  title={t('messages.sendFile')}
                >
                  <input
                    type="file"
                    onChange={handleFileSelect}
                    disabled={
                      activeTask.status === 'completed' ||
                      (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                      isSending ||
                      uploadingFile
                    }
                    style={{ display: 'none' }}
                  />
                  {uploadingFile ? '⏳' : '📎'}
                </label>
                
                {/* 完成任务按钮（接收者，任务进行中时显示） */}
                {activeTask.status === 'in_progress' && activeTask.taker_id === user?.id && (
                  <button
                    onClick={handleCompleteTask}
                    disabled={actionLoading}
                    className={`${styles.taskActionButton} ${styles.taskActionButtonComplete}`}
                    title="完成任务"
                  >
                    {actionLoading ? '处理中...' : '✅ 完成任务'}
                  </button>
                )}
                
                {/* 确认完成按钮（发布者，等待确认时显示） */}
                {activeTask.status === 'pending_confirmation' && activeTask.poster_id === user?.id && (
                  <button
                    onClick={handleConfirmCompletion}
                    disabled={actionLoading}
                    className={`${styles.taskActionButton} ${styles.taskActionButtonComplete}`}
                    title="确认完成"
                  >
                    {actionLoading ? '处理中...' : '✅ 确认完成'}
                  </button>
                )}
                
                {/* 评价按钮（双方，任务已完成时显示） */}
                {canReview() && !hasReviewed() && (
                  <button
                    onClick={() => setShowReviewModal(true)}
                    className={`${styles.taskActionButton} ${styles.taskActionButtonReview}`}
                    title="评价任务"
                  >
                    ⭐ 评价
                  </button>
                )}
                
              </div>
              
              {/* 输入框和发送按钮 */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '12px'
              }} className="message-input-container">
                <input
                  type="text"
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  readOnly={activeTask.status === 'completed'}
                  onKeyPress={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      if (!isSending && input.trim() && activeTask.status !== 'completed') {
                        handleSendTaskMessage();
                      }
                    }
                  }}
                  placeholder={
                    activeTask.status === 'completed'
                      ? t('messages.taskCannotSendMessage')
                      : activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id
                      ? t('messages.taskMustStartBeforeMessage')
                      : activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id === user?.id
                      ? t('messages.typeMessage')
                      : t('messages.typeMessage')
                  }
                  disabled={
                    activeTask.status === 'completed' ||
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
                    opacity: (activeTask.status === 'completed' || (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id)) ? 0.5 : 1
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
                    activeTask.status === 'completed' ||
                    (activeTask.status === 'open' && !activeTask.taker_id && activeTask.poster_id !== user?.id) ||
                    !input.trim() ||
                    isSending
                  }
                  style={{
                    padding: '12px 24px',
                    background: (
                      activeTask.status === 'completed' ||
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
              
              {/* 表情选择器 */}
              {showEmojiPicker && (
                <div
                  data-emoji-picker
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(8, 1fr)',
                    gap: '8px',
                    padding: '16px',
                    background: '#fff',
                    border: '1px solid #e5e7eb',
                    borderRadius: '12px',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                    maxHeight: '200px',
                    overflowY: 'auto',
                    position: 'absolute',
                    bottom: '80px',
                    left: '24px',
                    right: '24px',
                    zIndex: 1000
                  }}
                >
                  {EMOJI_LIST.map((emoji, idx) => (
                    <button
                      key={idx}
                      onClick={() => addEmoji(emoji)}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        cursor: 'pointer',
                        fontSize: '20px',
                        padding: '8px',
                        borderRadius: '4px',
                        transition: 'background 0.2s'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#f3f4f6';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'transparent';
                      }}
                    >
                      {emoji}
                    </button>
                  ))}
                </div>
              )}
              
              {/* 桌面端发送图片按钮 */}
              {imagePreview && !isMobile && (
                <button
                  onClick={sendImage}
                  disabled={uploadingImage || isSending}
                  style={{
                    padding: '10px 20px',
                    background: uploadingImage || isSending ? '#cbd5e1' : 'linear-gradient(135deg, #10b981, #059669)',
                    color: 'white',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    cursor: uploadingImage || isSending ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s ease',
                    alignSelf: 'flex-start'
                  }}
                >
                  {uploadingImage ? t('messages.uploading') : t('messages.sendingImage')}
                </button>
              )}
            </div>
          ) : null}
        </div>
      </div>

      {/* 评价弹窗和其他弹窗 */}
      {showRatingModal && (
        <div className={styles.reviewModalOverlay} onClick={() => {
          setShowRatingModal(false);
          setRating(5);
          setRatingComment('');
          setRatingSelectedTags([]);
          setRatingChatId(null);
        }}>
          <div className={styles.reviewModal} onClick={(e) => e.stopPropagation()}>
            <div className={styles.reviewModalHeader}>
              <LazyImage src="/static/logo.png" alt="Link²Ur Logo" className={styles.reviewModalLogo} width={40} height={40} />
              <h3 className={styles.reviewModalTitle}>
                {t('messages.rateService')}
              </h3>
            </div>
            
            {/* 星级评价 */}
            <div className={styles.reviewRatingSection}>
              <div className={styles.reviewStars}>
                {[1, 2, 3, 4, 5].map(star => (
                  <span
                    key={star}
                    onClick={() => setRating(star)}
                    onMouseEnter={() => setRatingHoverRating(star)}
                    onMouseLeave={() => setRatingHoverRating(0)}
                    className={styles.reviewStar}
                    style={{
                      opacity: star <= (ratingHoverRating || rating) ? 1 : 0.3
                    }}
                  >
                    ⭐
                  </span>
                ))}
              </div>
              <div className={styles.reviewRatingText}>
                {getRatingTextForService(rating)}
              </div>
            </div>

            {/* 标签选择 */}
            <div className={styles.reviewTagsSection}>
              <div className={styles.reviewTagsGrid}>
                {getCustomerServiceReviewTags().map(tag => (
                  <div
                    key={tag}
                    onClick={() => toggleRatingTag(tag)}
                    className={`${styles.reviewTag} ${ratingSelectedTags.includes(tag) ? styles.reviewTagSelected : ''}`}
                  >
                    {tag}
                  </div>
                ))}
              </div>
            </div>

            {/* 评论输入 */}
            <div className={styles.reviewCommentSection}>
              <label className={styles.reviewCommentLabel}>
                {t('messages.ratingComment')}
              </label>
              <textarea
                value={ratingComment}
                onChange={(e) => setRatingComment(e.target.value)}
                placeholder={t('messages.ratingCommentPlaceholder')}
                className={styles.reviewCommentInput}
              />
            </div>

            {/* 提交按钮 */}
            <button
              onClick={handleSubmitRating}
              className={styles.reviewSubmitButton}
            >
              {t('messages.submitRating')}
            </button>
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
                  checked={isNegotiateChecked}
                  onChange={(e) => {
                    setIsNegotiateChecked(e.target.checked);
                    if (e.target.checked) {
                      // 如果勾选，设置默认值为任务金额
                      const defaultPrice = activeTask?.agreed_reward ?? activeTask?.base_reward ?? activeTask?.reward;
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
                  setShowApplicationModal(false);
                  setApplicationMessage('');
                  setNegotiatedPrice(undefined);
                  setIsNegotiateChecked(false);
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
                onClick={async () => {
                  // 验证议价金额：如果勾选了议价，金额必须大于0
                  if (isNegotiateChecked && (negotiatedPrice === undefined || negotiatedPrice === null || negotiatedPrice <= 0)) {
                    alert(t('messages.notifications.enterNegotiationAmount'));
                    return;
                  }
                  
                  if (!activeTask) return;
                  
                  const baseReward = activeTask?.base_reward ?? activeTask?.reward ?? 0;
                  
                  // 如果没有勾选议价或输入框为空，则不发送议价金额（保持原本金额）
                  const finalNegotiatedPrice = (isNegotiateChecked && negotiatedPrice !== undefined && negotiatedPrice !== null && negotiatedPrice > 0) 
                    ? negotiatedPrice 
                    : undefined;
                  
                  // 如果议价金额小于原本金额，提示用户确认
                  if (finalNegotiatedPrice !== undefined && finalNegotiatedPrice < baseReward) {
                    const currency = activeTask?.currency || 'GBP';
                    const currencySymbol = currency === 'CNY' ? '¥' : '£';
                    const confirmed = window.confirm(
                      t('messages.notifications.negotiationAmountLower', {
                        amount: `${currencySymbol}${finalNegotiatedPrice.toFixed(2)}`,
                        baseAmount: `${currencySymbol}${baseReward.toFixed(2)}`
                      })
                    );
                    if (!confirmed) {
                      return;
                    }
                  }
                  
                  try {
                    
                    await applyForTask(
                      activeTaskId,
                      applicationMessage || undefined,
                      finalNegotiatedPrice,
                      activeTask?.currency || 'CNY'
                    );
                    setShowApplicationModal(false);
                    setApplicationMessage('');
                    setNegotiatedPrice(undefined);
                    setIsNegotiateChecked(false);
                    // 重新加载申请列表
                    if (activeTaskId) {
                      await loadApplications(activeTaskId);
                    }
                    alert(t('messages.notifications.applicationSubmitted'));
                  } catch (error: any) {
                                        alert(getErrorMessage(error));
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
                {t('tasks.apply.submitApplication')}
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
              <div style={{ textAlign: 'center', padding: '40px' }}>{t('messages.taskListLoading')}</div>
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
                      <LazyImage
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

                    {/* 议价信息 - 有议价显示金额，无议价显示"无议价" */}
                    {(() => {
                      // 确保negotiated_price是数字类型
                      const negotiatedPrice = app.negotiated_price !== undefined && app.negotiated_price !== null 
                        ? (typeof app.negotiated_price === 'number' ? app.negotiated_price : parseFloat(String(app.negotiated_price)))
                        : null;
                      const hasNegotiation = negotiatedPrice !== null && !isNaN(negotiatedPrice) && negotiatedPrice > 0;
                      
                      return (
                        <div style={{
                          marginBottom: '12px',
                          padding: '8px 12px',
                          borderRadius: '6px',
                          fontSize: '14px',
                          fontWeight: 600,
                          ...(hasNegotiation ? {
                            background: '#fef3c7',
                            color: '#92400e'
                          } : {
                            background: '#f3f4f6',
                            color: '#6b7280'
                          })
                        }}>
                          议价金额: {hasNegotiation
                            ? `£${negotiatedPrice.toFixed(2)} ${app.currency || 'GBP'}`
                            : '无议价'}
                        </div>
                      );
                    })()}

                    {activeTask?.poster_id === user?.id && (
                      <div style={{
                        display: 'flex',
                        gap: '8px',
                        marginTop: '12px',
                        flexWrap: 'wrap'
                      }}>
                        <button
                          onClick={async () => {
                            try {
                              const response = await acceptApplication(activeTaskId, app.id);
                              const responseData = response?.data || response;
                              
                              // 如果返回了支付信息，直接跳转到支付页面（新页面）
                              if (responseData && responseData.client_secret && responseData.payment_intent_id) {
                                setShowApplicationListModal(false);
                                // 构建支付页面 URL
                                const params = new URLSearchParams({
                                  client_secret: responseData.client_secret,
                                  payment_intent_id: responseData.payment_intent_id,
                                });
                                if (responseData.amount) {
                                  params.set('amount', responseData.amount.toString());
                                }
                                if (responseData.amount_display) {
                                  params.set('amount_display', responseData.amount_display);
                                }
                                params.set('return_url', window.location.href);
                                params.set('return_type', 'message');
                                const paymentUrl = `/${language}/tasks/${activeTaskId}/payment?${params.toString()}`;
                                const paymentWindow = window.open(paymentUrl, '_blank');
                                
                                if (!paymentWindow) {
                                  alert('无法打开支付页面，请检查浏览器弹窗设置');
                                }
                                
                                // 监听支付成功消息
                                const handlePaymentSuccess = (event: MessageEvent) => {
                                  if (event.data?.type === 'payment_success' && event.data?.taskId === activeTaskId) {
                                    message.success(t('messages.notifications.applicationAccepted') || '申请已批准！');
                                    if (activeTaskId) {
                                      loadTaskMessages(activeTaskId);
                                      loadApplications(activeTaskId);
                                      loadTasks();
                                    }
                                    window.removeEventListener('message', handlePaymentSuccess);
                                  }
                                };
                                window.addEventListener('message', handlePaymentSuccess);
                                
                                // 重新加载任务和申请列表（在打开支付页面后）
                                if (activeTaskId) {
                                  setTimeout(() => {
                                    loadTaskMessages(activeTaskId);
                                    loadApplications(activeTaskId);
                                    loadTasks();
                                  }, 500);
                                }
                              } else {
                                // 如果没有支付信息，说明可能已经支付成功或使用优惠券全额抵扣
                                setShowApplicationListModal(false);
                                if (activeTaskId) {
                                  await loadTaskMessages(activeTaskId);
                                  await loadApplications(activeTaskId);
                                  await loadTasks();
                                }
                              }
                            } catch (error: any) {
                              alert(getErrorMessage(error));
                            }
                          }}
                          style={{
                            flex: 1,
                            minWidth: '60px',
                            padding: '8px 16px',
                            background: '#10b981',
                            color: 'white',
                            border: 'none',
                            borderRadius: '6px',
                            fontSize: '18px',
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
                          ✓
                        </button>
                        <button
                          onClick={async () => {
                            try {
                              await rejectApplication(activeTaskId, app.id);
                              alert(t('messages.notifications.applicationRejected'));
                              // 重新加载申请列表
                              if (activeTaskId) {
                                await loadApplications(activeTaskId);
                              }
                            } catch (error: any) {
                                                            alert(getErrorMessage(error));
                            }
                          }}
                          style={{
                            flex: 1,
                            minWidth: '60px',
                            padding: '8px 16px',
                            background: '#ef4444',
                            color: 'white',
                            border: 'none',
                            borderRadius: '6px',
                            fontSize: '18px',
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
                          ✗
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedApplication(app);
                            setMessageContent('');
                            setMessageNegotiatedPrice(undefined);
                            setIsMessageNegotiateChecked(false);
                            setShowMessageModal(true);
                          }}
                          style={{
                            flex: 1,
                            minWidth: '60px',
                            padding: '8px 16px',
                            background: '#3b82f6',
                            color: 'white',
                            border: 'none',
                            borderRadius: '6px',
                            fontSize: '14px',
                            fontWeight: 600,
                            cursor: 'pointer',
                            transition: 'all 0.2s ease'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#2563eb';
                            e.currentTarget.style.transform = 'translateY(-1px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#3b82f6';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          留言
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
            <LazyImage
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
                {uploadingImage ? t('messages.sending') : t('messages.sendingImage')}
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
            <LazyImage
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
                // 错误已由 LazyImage 处理
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
                const img = e.currentTarget;
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
      
      {/* 任务聊天模式滚动到底部按钮 - 固定在输入框上方 */}
      {showScrollToBottom && chatMode === 'tasks' && activeTaskId && (
        <button
          onClick={() => {
            smartScrollToBottom(true);
            setHasNewTaskMessages(false); // 清除新消息提示
          }}
          style={{
            position: 'fixed',
            bottom: `${taskScrollButtonBottom}px`,
            left: taskScrollButtonLeft !== null ? `${taskScrollButtonLeft}px` : '50%',
            transform: taskScrollButtonLeft !== null ? 'none' : 'translateX(-50%)',
            width: '48px',
            height: '48px',
            borderRadius: '50%',
            backgroundColor: hasNewTaskMessages ? '#10b981' : '#3b82f6',
            color: 'white',
            border: 'none',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: hasNewTaskMessages 
              ? '0 4px 12px rgba(16, 185, 129, 0.4)' 
              : '0 4px 12px rgba(59, 130, 246, 0.4)',
            transition: 'all 0.3s ease',
            zIndex: 1000,
            fontSize: '20px',
            animation: hasNewTaskMessages ? 'pulse 2s infinite' : 'none'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = hasNewTaskMessages ? '#059669' : '#2563eb';
            const currentTransform = taskScrollButtonLeft !== null ? 'scale(1.1)' : 'translateX(-50%) scale(1.1)';
            e.currentTarget.style.transform = currentTransform;
            e.currentTarget.style.boxShadow = hasNewTaskMessages 
              ? '0 6px 16px rgba(16, 185, 129, 0.5)' 
              : '0 6px 16px rgba(59, 130, 246, 0.5)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = hasNewTaskMessages ? '#10b981' : '#3b82f6';
            const currentTransform = taskScrollButtonLeft !== null ? 'scale(1)' : 'translateX(-50%) scale(1)';
            e.currentTarget.style.transform = currentTransform;
            e.currentTarget.style.boxShadow = hasNewTaskMessages 
              ? '0 4px 12px rgba(16, 185, 129, 0.4)' 
              : '0 4px 12px rgba(59, 130, 246, 0.4)';
          }}
          title={hasNewTaskMessages ? '有新消息，点击滚动到底部' : '滚动到底部'}
        >
          {hasNewTaskMessages ? '🔔' : '↓'}
        </button>
      )}
      
      {/* 客服模式滚动到底部按钮 - 固定在视口右下角 */}
      {showScrollToBottomButton && isServiceMode && (
        <div
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            scrollToBottom();
          }}
          style={{
            position: 'fixed',
            bottom: `${scrollButtonBottom}px`,
            left: '50%',
            transform: 'translateX(-50%)',
            width: '48px',
            height: '48px',
            borderRadius: '50%',
            backgroundColor: '#007bff',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            boxShadow: '0 4px 12px rgba(0, 123, 255, 0.4)',
            transition: 'bottom 0.3s ease, transform 0.3s ease',
            zIndex: 1000,
            fontSize: '20px',
            fontWeight: 'bold',
            border: '2px solid white',
            userSelect: 'none'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.transform = 'translateX(-50%) scale(1.1)';
            e.currentTarget.style.backgroundColor = '#0056b3';
            e.currentTarget.style.boxShadow = '0 6px 16px rgba(0, 123, 255, 0.5)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = 'translateX(-50%) scale(1)';
            e.currentTarget.style.backgroundColor = '#007bff';
            e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 123, 255, 0.4)';
          }}
          title="滚动到底部"
        >
          ↓
        </div>
      )}
      
      {/* Toast通知 */}
      {toastMessage && (
        <div
          style={{
            position: 'fixed',
            top: '20px',
            left: '50%',
            transform: 'translateX(-50%)',
            padding: '12px 24px',
            backgroundColor: toastMessage.type === 'success' ? '#10b981' : toastMessage.type === 'error' ? '#ef4444' : '#3b82f6',
            color: 'white',
            borderRadius: '8px',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
            zIndex: 10000,
            fontSize: '14px',
            fontWeight: 500,
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            animation: 'slideDown 0.3s ease-out',
            maxWidth: '90%',
            textAlign: 'center'
          }}
        >
          <span>{toastMessage.type === 'success' ? '✓' : toastMessage.type === 'error' ? '✕' : 'ℹ'}</span>
          <span>{toastMessage.text}</span>
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
      
      {/* 评价弹窗 */}
      {showReviewModal && activeTask && (
        <div 
          className={styles.reviewModalOverlay} 
          onClick={() => {
            setShowReviewModal(false);
            setReviewRating(5);
            setReviewComment('');
            setSelectedTags([]);
            setHoverRating(0);
          }}
        >
          <div className={styles.reviewModal} onClick={(e) => e.stopPropagation()}>
            <h2 className={styles.reviewModalTitle}>
              {t('myTasks.actions.review')}
            </h2>
            
            {/* 星级评价 */}
            <div className={styles.reviewRatingSection}>
              <div className={styles.reviewStars}>
                {[1, 2, 3, 4, 5].map(star => (
                  <span
                    key={star}
                    onClick={() => setReviewRating(star)}
                    onMouseEnter={() => setHoverRating(star)}
                    onMouseLeave={() => setHoverRating(0)}
                    className={styles.reviewStar}
                    style={{
                      opacity: star <= (hoverRating || reviewRating) ? 1 : 0.3
                    }}
                  >
                    ⭐
                  </span>
                ))}
              </div>
              <div className={styles.reviewRatingText}>
                {getRatingText(reviewRating)}
              </div>
            </div>

            {/* 标签选择 */}
            <div className={styles.reviewTagsSection}>
              <div className={styles.reviewTagsGrid}>
                {getReviewTags(activeTask).map(tag => (
                  <div
                    key={tag}
                    onClick={() => toggleTag(tag)}
                    className={`${styles.reviewTag} ${selectedTags.includes(tag) ? styles.reviewTagSelected : ''}`}
                  >
                    {tag}
                  </div>
                ))}
              </div>
            </div>

            {/* 评论输入 */}
            <div className={styles.reviewCommentSection}>
              <label className={styles.reviewCommentLabel}>
                {t('myTasks.reviewPlaceholder')} ({t('myTasks.optional')})
              </label>
              <textarea
                value={reviewComment}
                onChange={(e) => setReviewComment(e.target.value)}
                placeholder={t('myTasks.reviewPlaceholder')}
                className={styles.reviewCommentInput}
              />
            </div>

            {/* 提交按钮 */}
            <button
              onClick={handleReviewTask}
              disabled={actionLoading}
              className={styles.reviewSubmitButton}
            >
              {actionLoading ? t('myTasks.actions.processing') : t('myTasks.actions.submitReview')}
            </button>
          </div>
        </div>
      )}
      
      {/* 留言弹窗 */}
      {showMessageModal && selectedApplication && activeTaskId && activeTask && (
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
          padding: '20px',
          overflow: 'hidden'
        }}
        onClick={() => setShowMessageModal(false)}
        >
          <div style={{
            background: '#fff',
            borderRadius: '16px',
            padding: '24px',
            width: '100%',
            maxWidth: 'min(500px, calc(100vw - 40px))',
            maxHeight: '90vh',
            overflowY: 'auto',
            overflowX: 'hidden',
            boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
            boxSizing: 'border-box'
          }}
          onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '20px', fontWeight: 600 }}>发送留言</h3>
            
            <div style={{ marginBottom: '16px', padding: '12px', background: '#f3f4f6', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>申请者</div>
              <div style={{ fontSize: '14px', fontWeight: 600 }}>{selectedApplication.applicant_name || '用户'}</div>
            </div>
            
            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'block',
                marginBottom: '8px',
                fontSize: '14px',
                fontWeight: 600,
                color: '#374151'
              }}>
                留言内容
              </label>
              <textarea
                value={messageContent}
                onChange={(e) => setMessageContent(e.target.value)}
                placeholder="请输入留言内容..."
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
                  checked={isMessageNegotiateChecked}
                  onChange={(e) => {
                    setIsMessageNegotiateChecked(e.target.checked);
                    if (e.target.checked) {
                      const defaultPrice = activeTask?.agreed_reward ?? activeTask?.base_reward ?? activeTask?.reward;
                      setMessageNegotiatedPrice(defaultPrice);
                    } else {
                      setMessageNegotiatedPrice(undefined);
                    }
                  }}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span>包含议价</span>
              </label>
              
              {isMessageNegotiateChecked && (
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
                    value={messageNegotiatedPrice !== undefined ? messageNegotiatedPrice : ''}
                    onChange={(e) => {
                      const value = e.target.value ? parseFloat(e.target.value) : undefined;
                      setMessageNegotiatedPrice(value);
                    }}
                    placeholder="请输入议价金额（必须大于0）"
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
                  setShowMessageModal(false);
                  setMessageContent('');
                  setMessageNegotiatedPrice(undefined);
                  setIsMessageNegotiateChecked(false);
                  setSelectedApplication(null);
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
                  if (!messageContent.trim()) {
                    alert(t('messages.notifications.enterMessageContent'));
                    return;
                  }
                  
                  // 验证议价金额：如果勾选了议价，金额必须大于0
                  if (isMessageNegotiateChecked && (messageNegotiatedPrice === undefined || messageNegotiatedPrice === null || messageNegotiatedPrice <= 0)) {
                    alert(t('messages.notifications.enterNegotiationAmount'));
                    return;
                  }
                  
                  const baseReward = activeTask?.base_reward ?? activeTask?.reward ?? 0;
                  
                  // 如果没有勾选议价或输入框为空，则不发送议价金额
                  const finalNegotiatedPrice = (isMessageNegotiateChecked && messageNegotiatedPrice !== undefined && messageNegotiatedPrice !== null && messageNegotiatedPrice > 0) 
                    ? messageNegotiatedPrice 
                    : undefined;
                  
                  // 如果议价金额小于原本金额，提示用户确认
                  if (finalNegotiatedPrice !== undefined && finalNegotiatedPrice < baseReward) {
                    const currency = activeTask?.currency || 'GBP';
                    const currencySymbol = currency === 'CNY' ? '¥' : '£';
                    const confirmed = window.confirm(
                      t('messages.notifications.negotiationAmountLower', {
                        amount: `${currencySymbol}${finalNegotiatedPrice.toFixed(2)}`,
                        baseAmount: `${currencySymbol}${baseReward.toFixed(2)}`
                      })
                    );
                    if (!confirmed) {
                      return;
                    }
                  }
                  
                  try {
                    await sendApplicationMessage(
                      activeTaskId,
                      selectedApplication.id,
                      messageContent,
                      finalNegotiatedPrice
                    );
                    setShowMessageModal(false);
                    setMessageContent('');
                    setMessageNegotiatedPrice(undefined);
                    setIsMessageNegotiateChecked(false);
                    setSelectedApplication(null);
                    showToast('success', t('messages.notifications.messageSent'));
                    // 重新加载申请列表
                    if (activeTaskId) {
                      await loadApplications(activeTaskId);
                    }
                  } catch (error: any) {
                    showToast('error', getErrorMessage(error) || t('messages.notifications.sendMessageFailed'));
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
                发送
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 任务详情弹窗 */}
      <TaskDetailModal
        isOpen={showTaskDetailModal}
        onClose={() => setShowTaskDetailModal(false)}
        taskId={activeTaskId}
      />
      
      {/* 任务卡片选择弹窗 */}
      {showTaskCardModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          zIndex: 10001,
          backdropFilter: 'blur(5px)'
        }}
        onClick={(e) => {
          if (e.target === e.currentTarget) {
            setShowTaskCardModal(false);
          }
        }}
        >
          <div style={{
            backgroundColor: '#fff',
            borderRadius: 12,
            padding: '24px',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.2)',
            maxWidth: '600px',
            width: '90%',
            maxHeight: '80vh',
            display: 'flex',
            flexDirection: 'column'
          }}
          onClick={(e) => e.stopPropagation()}
          >
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '20px',
              paddingBottom: '16px',
              borderBottom: '2px solid #f0f0f0'
            }}>
              <h3 style={{ 
                margin: 0, 
                fontSize: 20, 
                fontWeight: 600, 
                color: '#262626' 
              }}>
                📋 选择要发送的任务
              </h3>
              <button
                onClick={() => setShowTaskCardModal(false)}
                style={{
                  padding: '6px 12px',
                  border: 'none',
                  background: '#f5f5f5',
                  color: '#666',
                  borderRadius: 6,
                  cursor: 'pointer',
                  fontSize: 16,
                  fontWeight: 600,
                  transition: 'all 0.2s'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#ff4d4f';
                  e.currentTarget.style.color = '#fff';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f5f5f5';
                  e.currentTarget.style.color = '#666';
                }}
              >
                ✕
              </button>
            </div>
            
            <div style={{
              flex: 1,
              overflowY: 'auto',
              paddingRight: '8px'
            }}>
              {userTasksLoading ? (
                <div style={{ textAlign: 'center', padding: '40px' }}>
                  {t('messages.taskListLoading')}
                </div>
              ) : userTasks.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
                  {t('messages.noTasks')}
                </div>
              ) : (
                <div style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px'
                }}>
                  {userTasks.map((task) => (
                    <div
                      key={task.id}
                      onClick={() => sendTaskCard(task.id)}
                      style={{
                        border: '1px solid #e8e8e8',
                        borderRadius: 8,
                        padding: '16px',
                        background: '#fafafa',
                        cursor: 'pointer',
                        transition: 'all 0.2s'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.borderColor = '#3b82f6';
                        e.currentTarget.style.background = '#fff';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(59, 130, 246, 0.2)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.borderColor = '#e8e8e8';
                        e.currentTarget.style.background = '#fafafa';
                        e.currentTarget.style.boxShadow = 'none';
                      }}
                    >
                      <div style={{
                        fontSize: 16,
                        fontWeight: 600,
                        color: '#333',
                        marginBottom: '8px'
                      }}>
                        <TaskTitle
                          title={task.title}
                          language={language}
                          taskId={task.id}
                          task={task}
                          autoTranslate={true}
                        />
                      </div>
                      <div style={{
                        display: 'flex',
                        gap: '16px',
                        fontSize: 13,
                        color: '#666'
                      }}>
                        <span>💰 £{task.reward || task.base_reward || 0}</span>
                        <span>📋 {task.task_type}</span>
                        <span>📍 {obfuscateLocation(task.location) || '未知'}</span>
                        <span style={{
                          padding: '2px 8px',
                          borderRadius: 4,
                          background: task.status === 'open' ? '#dbeafe' :
                                     task.status === 'in_progress' ? '#fef3c7' :
                                     task.status === 'completed' ? '#d1fae5' : '#fee2e2',
                          color: task.status === 'open' ? '#1e40af' :
                                 task.status === 'in_progress' ? '#92400e' :
                                 task.status === 'completed' ? '#065f46' : '#991b1b',
                          fontSize: 12,
                          fontWeight: 600
                        }}>
                          {task.status === 'open' ? t('messages.taskStatusWaiting') :
                           task.status === 'taken' ? t('messages.taskStatusWaiting') :
                           task.status === 'in_progress' ? t('messages.taskStatusInProgress') :
                           task.status === 'completed' ? t('messages.taskStatusCompleted') : task.status}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
      
      {/* PaymentModal 已移除，统一使用 TaskPayment 页面进行支付 */}

      {/* 完成任务弹窗 */}
      {activeTaskId && (
        <CompleteTaskModal
          visible={showCompleteTaskModal}
          taskId={activeTaskId}
          onCancel={() => setShowCompleteTaskModal(false)}
          onSuccess={handleCompleteTaskSuccess}
        />
      )}
    </div>
  );
};

export default MessagePage; 
