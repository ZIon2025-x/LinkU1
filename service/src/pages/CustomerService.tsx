import React, { useState, useEffect, useRef, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { message, Modal } from 'antd';
import { API_BASE_URL, WS_BASE_URL, API_ENDPOINTS } from '../config';
import api, { 
  getCustomerServiceSessions, 
  getCustomerServiceMessages, 
  getCustomerServiceStatus, 
  setCustomerServiceOnline, 
  setCustomerServiceOffline, 
  markCustomerServiceMessagesRead,
  getCancelRequests,
  getAdminRequests,
  getAdminChatMessages,
  sendAdminChatMessage,
  reviewCancelRequest,
  submitAdminRequest as submitAdminRequestAPI,
  getTaskDetail,
  checkChatTimeoutStatus,
  timeoutEndChat,
  cleanupOldChats,
  getServiceProfile,
  sendAnnouncement as sendAnnouncementAPI,
  updateUserStatus,
  setUserLevel,
  deleteTask as deleteTaskAPI,
  customerServiceLogout
} from '../api';
import NotificationBell, { NotificationBellRef } from '../components/NotificationBell';
import NotificationModal from '../components/NotificationModal';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LazyImage from '../components/LazyImage';
import { formatImageUrl } from '../utils/imageUtils';
import './CustomerService.css';

// 英国日期格式化工具函数
const formatUKDate = (dateString: string): string => {
  try {
    const date = new Date(dateString);
    if (isNaN(date.getTime())) {
      return '刚刚';
    }
    // 转换为英国时间 (UTC+0)
    return date.toLocaleDateString('en-GB', {
      timeZone: 'Europe/London',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    });
  } catch (error) {
    return '刚刚';
  }
};

interface User {
  id: string;  // 现在ID是字符串类型
  name: string;
  email: string;
  user_level: string;
  is_verified: number;
  is_banned: number;
  is_suspended: number;
  created_at: string;
  avg_rating: number;
  task_count: number;
}

interface Task {
  id: number;
  title: string;
  status: string;
  task_level: string;
  reward: number;
  created_at: string;
  poster_id: string;  // 现在ID是字符串类型
  taker_id?: string;  // 现在ID是字符串类型
}

interface Message {
  id: number;
  sender_id: number | string;
  receiver_id: number | string;
  content: string;
  created_at: string;
  is_read: number;
  is_admin_msg: number;
  sender_type?: string;
  message_type?: string; // 'text' | 'task_card' | 'image' | 'file'
  task_id?: number; // 任务卡片消息的任务ID
}

interface Notification {
  id: number;
  user_id: string;  // 现在ID是字符串类型
  type: string;
  title: string;
  content: string;
  is_read: number;
  created_at: string;
}

interface TaskCancelRequest {
  id: number;
  task_id: number;
  requester_id: string;  // 现在ID是字符串类型
  requester_name?: string;
  reason: string;
  status: string;
  admin_id: string | null;  // 管理员ID（格式：A0001）
  service_id: string | null;  // 客服ID（格式：CS8888）
  admin_comment: string | null;
  created_at: string;
  reviewed_at: string | null;
  task?: {
    id: number;
    title: string;
    status: string;
    poster_id: string;
    taker_id: string | null;
  };
  user_role?: string;  // "发布者" 或 "接收者"
}

interface UserSession {
  chat_id: string;
  user_id: string;  // 现在ID是字符串类型
  user_name: string;
  user_avatar: string;
  created_at: string;
  ended_at: string | null;
  is_ended: number;  // 0: 进行中, 1: 已结束
  unread_count: number;  // 未读消息数量
}

// 客服回答模板 (moved outside component to avoid recreation on every render)
const responseTemplates = [
  {
    id: 1,
    category: '问候',
    title: '欢迎语',
    content: '👋 您好！欢迎使用 Link²Ur，我是 Link²Ur 的客服，很高兴为您服务。请问有什么可以帮助您的吗？'
  },
  {
    id: 2,
    category: '问候',
    title: '感谢等待',
    content: '🙏 感谢您的耐心等待，我已经收到您的消息，正在为您处理中。'
  },
  {
    id: 3,
    category: '问题处理',
    title: '了解问题',
    content: '👍 我理解您的问题了，让我为您详细解答一下。'
  },
  {
    id: 4,
    category: '问题处理',
    title: '需要更多信息',
    content: '📋 为了更好地帮助您，我需要了解一些详细信息。请问您能提供更多相关细节吗？'
  },
  {
    id: 5,
    category: '问题处理',
    title: '转交处理',
    content: '📝 您的问题我已经记录下来了，我会转交给相关部门处理，预计会在24小时内给您回复。'
  },
  {
    id: 6,
    category: '任务相关',
    title: '任务状态查询',
    content: '🔍 关于您询问的任务状态，我来为您查询一下，请稍等。'
  },
  {
    id: 7,
    category: '任务相关',
    title: '任务取消说明',
    content: '📋 关于任务取消的申请，我已经收到。根据平台规定，取消任务需要双方同意。我会尽快为您处理。'
  },
  {
    id: 8,
    category: '账户相关',
    title: '账户问题',
    content: '🔒 关于您的账户问题，我已经了解。为了确保账户安全，我需要验证一些信息。'
  },
  {
    id: 9,
    category: '账户相关',
    title: '账户解封',
    content: '✅ 关于账户解封的申请，我已经收到。我会尽快审核您的申请，审核结果会在3个工作日内通知您。'
  },
  {
    id: 10,
    category: '结束语',
    title: '问题已解决',
    content: '🎉 很高兴能帮助您解决问题。如果还有其他需要帮助的地方，请随时联系我们。祝您使用愉快！'
  },
  {
    id: 11,
    category: '结束语',
    title: '稍后回复',
    content: '⏳ 您的问题我已经记录，我会在稍后给您详细回复。感谢您的理解与支持！'
  },
  {
    id: 15,
    category: '结束语',
    title: '继续帮助',
    content: '😊 请问还有什么可以帮助您的呢？'
  },
  {
    id: 12,
    category: '其他',
    title: '道歉',
    content: '😔 非常抱歉给您带来了不便，我们会尽快处理您的问题。'
  },
  {
    id: 13,
    category: '其他',
    title: '确认信息',
    content: '✅ 为了确保信息准确，请您确认一下：{信息内容}。'
  },
  {
    id: 14,
    category: '其他',
    title: '提供帮助',
    content: '💪 如果您在使用过程中遇到任何问题，随时可以联系我，我会尽力为您提供帮助。'
  }
];

// 按分类分组模板 (moved outside component)
const templatesByCategory = responseTemplates.reduce((acc, template) => {
  if (!acc[template.category]) {
    acc[template.category] = [];
  }
  acc[template.category].push(template);
  return acc;
}, {} as Record<string, typeof responseTemplates>);

// 解析任务卡片消息的辅助函数
const parseTaskCardMessage = (msg: any): { isTaskCard: boolean; taskId?: number } => {
  const isTaskCard = msg.message_type === 'task_card' ||
                    (msg.content && msg.content.startsWith('[TASK_CARD:') && msg.content.endsWith(']'));
  let taskId: number | undefined;

  if (isTaskCard) {
    if (msg.task_id) {
      taskId = msg.task_id;
    } else if (msg.content && msg.content.startsWith('[TASK_CARD:')) {
      const match = msg.content.match(/\[TASK_CARD:(\d+)\]/);
      if (match) {
        taskId = parseInt(match[1], 10);
      }
    }
  }

  return { isTaskCard, taskId };
};

const CustomerService: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('dashboard');
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [isOnline, setIsOnline] = useState(false);
  const [justToggledStatus, setJustToggledStatus] = useState(false);
  const [users, setUsers] = useState<User[]>([]);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [messages, setMessages] = useState<Message[]>([]);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [cancelRequests, setCancelRequests] = useState<TaskCancelRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [timezoneInfo, setTimezoneInfo] = useState<any>(null);
  const [userTimezone, setUserTimezone] = useState<string>('');

  // 后台管理请求相关状态
  const [adminRequests, setAdminRequests] = useState<any[]>([]);
  const [selectedRequestType, setSelectedRequestType] = useState('');
  const [requestTitle, setRequestTitle] = useState('');
  const [requestDescription, setRequestDescription] = useState('');
  const [requestPriority, setRequestPriority] = useState('medium');
  const [showRequestForm, setShowRequestForm] = useState(false);
  const [adminChatMessages, setAdminChatMessages] = useState<any[]>([]);
  const [newAdminMessage, setNewAdminMessage] = useState('');
  const [announcement, setAnnouncement] = useState('');
  // 移除回复相关状态
  const [searchTerm, setSearchTerm] = useState('');
  const [filterType, setFilterType] = useState('all');

  // 任务搜索相关状态
  const [taskSearchTerm, setTaskSearchTerm] = useState('');
  const [filteredTasks, setFilteredTasks] = useState<Task[]>([]);

  // 提醒相关状态
  const [showNotificationModal, setShowNotificationModal] = useState(false);
  const notificationBellRef = useRef<NotificationBellRef>(null);

  // 刷新提醒数量的函数
  const handleNotificationRead = () => {
    if (notificationBellRef.current) {
      notificationBellRef.current.refreshUnreadCount();
    }
  };
  const [selectedCancelRequest, setSelectedCancelRequest] = useState<TaskCancelRequest | null>(null);
  const [adminComment, setAdminComment] = useState('');
  const [sessions, setSessions] = useState<UserSession[]>([]);
  const [selectedSession, setSelectedSession] = useState<UserSession | null>(null);
  const selectedSessionRef = useRef<UserSession | null>(null);
  const [chatMessages, setChatMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [wsConnectionStatus, setWsConnectionStatus] = useState<'connecting' | 'connected' | 'disconnected' | 'error'>('disconnected');

  // WebSocket连接测试函数
  const testWebSocketConnection = () => {
    // 客服使用Cookie认证，无需检查token
    const testUrl = `${WS_BASE_URL}/ws/chat/${currentUser?.id}`;

    const testSocket = new WebSocket(testUrl);

    testSocket.onopen = () => {
      message.success('WebSocket连接测试成功！');
      testSocket.close();
    };

    testSocket.onerror = (error) => {
      message.error('WebSocket连接测试失败，请检查网络设置');
    };

    testSocket.onclose = (event) => {
      // 测试连接关闭
    };
  };
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // 新用户连接弹窗状态
  const [showNewUserNotification, setShowNewUserNotification] = useState(false);
  const [newUserInfo, setNewUserInfo] = useState<{name: string, id: string} | null>(null);

  // 超时相关状态
  const [chatTimeoutStatus, setChatTimeoutStatus] = useState<{
    is_ended: boolean;
    is_timeout: boolean;
    timeout_available: boolean;
    time_since_last_message?: number;
  } | null>(null);
  const [timeoutCheckInterval, setTimeoutCheckInterval] = useState<ReturnType<typeof setInterval> | null>(null);

  // 模板相关状态
  const [showTemplateModal, setShowTemplateModal] = useState(false);

  // 任务卡片相关状态
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);
  const [selectedTask, setSelectedTask] = useState<any>(null);
  const [showTaskDetailModal, setShowTaskDetailModal] = useState(false);
  const [loadingTaskDetail, setLoadingTaskDetail] = useState(false);

  // 统计数据
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalTasks: 0,
    activeTasks: 0,
    completedTasks: 0,
    totalRevenue: 0,
    avgRating: 0
  });

  // Memoized derived state
  const totalUnreadCount = useMemo(
    () => sessions.reduce((total, session) => total + session.unread_count, 0),
    [sessions]
  );
  const activeSessions = useMemo(
    () => sessions.filter(s => s.is_ended === 0),
    [sessions]
  );
  const endedSessions = useMemo(
    () => sessions.filter(s => s.is_ended === 1),
    [sessions]
  );
  const pendingCancelCount = useMemo(
    () => pendingCancelCount,
    [cancelRequests]
  );
  const pendingAdminCount = useMemo(
    () => pendingAdminCount,
    [adminRequests]
  );

  useEffect(() => {
    checkAdminStatus();
    loadData();
    loadCustomerServiceStatus();
    initializeTimezone();
  }, []);

  // 初始化时区信息
  const initializeTimezone = async () => {
    try {
      const detectedTimezone = TimeHandlerV2.getUserTimezone();
      setUserTimezone(detectedTimezone);
      
      const serverTimezoneInfo = await TimeHandlerV2.getTimezoneInfo();
      if (serverTimezoneInfo) {
        setTimezoneInfo(serverTimezoneInfo);
      }
    } catch (error) {
          }
  };

  const checkAdminStatus = async () => {
    try {
      // 新的认证系统使用Cookie认证，不需要检查localStorage
      // 直接通过API检查客服认证状态
      const service = await getServiceProfile();
      setCurrentUser(service);
    } catch (error) {
      // 如果认证失败，重定向到客服登录页面
      navigate('/login');
    }
  };

  const loadData = async () => {
    setLoading(true);
    try {
      // 客服需要加载会话数据、取消请求数据和管理请求数据
      await loadSessions();
      await loadCancelRequests();
      await loadAdminRequests();
      await loadAdminChatMessages();
      
      // 设置空的统计数据
      setStats({
        totalUsers: 0,
        totalTasks: 0,
        activeTasks: 0,
        completedTasks: 0,
        totalRevenue: 0,
        avgRating: 0
      });
    } catch (error) {
          } finally {
      setLoading(false);
    }
  };

  const sendAnnouncement = async () => {
    if (!announcement.trim()) {
      message.warning('请输入公告内容');
      return;
    }

    try {
      await sendAnnouncementAPI('平台公告', announcement);
      message.success('公告发送成功');
      setAnnouncement('');
    } catch (error: any) {
      const errorMsg = error?.response?.data?.detail || error?.message || '发送公告失败';
      message.error(errorMsg);
    }
  };

  // 客服登出处理函数
  const handleLogout = async () => {
    try {
      // 1. 先设置为离线状态
      if (isOnline) {
        await toggleOnlineStatus();
      }

      // 2. 调用客服登出API
      await customerServiceLogout();

      // 3. 清理本地状态
      setCurrentUser(null);
      setIsOnline(false);
      
      // 4. 关闭WebSocket连接
      if (ws) {
        ws.close();
        setWs(null);
      }

      // 5. 清理超时检查
      if (timeoutCheckInterval) {
        clearInterval(timeoutCheckInterval);
        setTimeoutCheckInterval(null);
      }
      
      // 7. 跳转到登录页面
      navigate('/login');
    } catch (error: any) {
      const errorMsg = error?.response?.data?.detail || error?.message || '登出时发生错误，请重试';
      message.error(errorMsg);
    }
  };

  const handleUserAction = async (userId: string, action: string, value?: any) => {
    try {
      switch (action) {
        case 'ban':
          await updateUserStatus(userId, { is_banned: 1 });
          break;
        case 'unban':
          await updateUserStatus(userId, { is_banned: 0 });
          break;
        case 'suspend':
          await updateUserStatus(userId, { is_suspended: 1 });
          break;
        case 'unsuspend':
          await updateUserStatus(userId, { is_suspended: 0 });
          break;
        case 'setLevel':
          await setUserLevel(userId, value);
          break;
        default:
          message.error('未知操作');
          return;
      }

      message.success('操作成功');
      loadData(); // 重新加载数据
    } catch (error: any) {
      const errorMsg = error?.response?.data?.detail || error?.message || '操作失败';
      message.error(errorMsg);
    }
  };

  // 移除回复功能

  // 任务搜索功能
  const filterTasks = (tasks: Task[], searchTerm: string) => {
    if (!searchTerm.trim()) {
      return tasks;
    }
    
    const searchLower = searchTerm.toLowerCase();
    return tasks.filter(task => 
      task.id.toString().includes(searchLower) ||
      task.poster_id.toString().includes(searchLower) ||
      (task.taker_id && task.taker_id.toString().includes(searchLower))
    );
  };

  // 删除任务功能
  const deleteTask = async (taskId: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个任务吗？此操作不可撤销。',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteTaskAPI(taskId);
          message.success('任务删除成功');
          loadData(); // 重新加载数据
        } catch (error: any) {
          const errorMsg = error?.response?.data?.detail || error?.message || '删除任务失败';
          message.error(errorMsg);
        }
      }
    });
  };


  const filteredUsers = useMemo(() => users.filter(user => {
    const matchesSearch = user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         user.email.toLowerCase().includes(searchTerm.toLowerCase());

    if (filterType === 'all') return matchesSearch;
    if (filterType === 'banned') return matchesSearch && user.is_banned === 1;
    if (filterType === 'suspended') return matchesSearch && user.is_suspended === 1;
    if (filterType === 'vip') return matchesSearch && user.user_level === 'vip';
    if (filterType === 'super') return matchesSearch && user.user_level === 'super';

    return matchesSearch;
  }), [users, searchTerm, filterType]);

  useEffect(() => {
    if (currentUser?.id) {
      loadSessions();
      const interval = setInterval(loadSessions, 10000); // 每10秒刷新一次
      return () => clearInterval(interval);
    }
  }, [currentUser?.id]); // 只在用户ID改变时重新加载会话

  // 定期刷新客服状态和评分数据
  useEffect(() => {
    if (currentUser) {
      // 立即加载一次
      loadCustomerServiceStatus();
      
      // 每30秒刷新一次评分数据
      const interval = setInterval(() => {
        loadCustomerServiceStatus();
      }, 30000);
      
      return () => clearInterval(interval);
    }
  }, [currentUser?.id]); // 只在用户ID改变时重新加载客服状态

  const loadSessions = async () => {
    try {
      const sessionsData = await getCustomerServiceSessions();
      // 确保 sessionsData 是数组
      if (Array.isArray(sessionsData)) {
        setSessions(sessionsData);
      } else {
        setSessions([]);
      }
    } catch (error) {
      setSessions([]);
    }
  };

  const loadCancelRequests = async () => {
    try {
      const requestsData = await getCancelRequests();
      setCancelRequests(Array.isArray(requestsData) ? requestsData : []);
    } catch (error) {
      setCancelRequests([]);
    }
  };

  const loadAdminRequests = async () => {
    try {
      const requestsData = await getAdminRequests();
      setAdminRequests(Array.isArray(requestsData) ? requestsData : []);
    } catch (error) {
      setAdminRequests([]);
    }
  };

  const loadAdminChatMessages = async () => {
    try {
      const messagesData = await getAdminChatMessages();
      setAdminChatMessages(Array.isArray(messagesData) ? messagesData : []);
    } catch (error) {
      setAdminChatMessages([]);
    }
  };

  const handleReviewCancelRequest = async (requestId: number, status: 'approved' | 'rejected') => {
    try {
      await reviewCancelRequest(requestId, status, adminComment.trim() || '');
      
      setSelectedCancelRequest(null);
      setAdminComment('');
      await loadCancelRequests(); // 重新加载取消请求列表
      message.success(`取消请求已${status === 'approved' ? '通过' : '拒绝'}`);
      
    } catch (error: any) {
            // 处理不同的错误格式
      let errorMessage = '审核失败';
      
      if (error.response) {
        // 有响应，说明是服务器返回的错误
        const errorData = error.response.data;
                if (errorData?.detail) {
          if (Array.isArray(errorData.detail)) {
            // Pydantic验证错误
            errorMessage = errorData.detail.map((err: any) => {
              if (typeof err === 'string') return err;
              const field = err.loc?.join('.') || '未知字段';
              const msg = err.msg || '验证失败';
              return `${field}: ${msg}`;
            }).join('; ');
          } else if (typeof errorData.detail === 'string') {
            errorMessage = errorData.detail;
          } else {
            errorMessage = JSON.stringify(errorData.detail);
          }
        } else if (errorData?.message) {
          errorMessage = errorData.message;
        } else {
          errorMessage = `审核失败 (${error.response.status}): ${error.response.statusText || '未知错误'}`;
        }
      } else if (error.message) {
        errorMessage = error.message;
      }
      
      message.error(errorMessage);
    }
  };

  const handleSubmitAdminRequest = async () => {
    if (!selectedRequestType || !requestTitle || !requestDescription) {
      message.warning('请填写完整的请求信息');
      return;
    }

    try {
      await submitAdminRequestAPI({
        type: selectedRequestType,
        title: requestTitle,
        description: requestDescription,
        priority: requestPriority
      });
      
      setShowRequestForm(false);
      setSelectedRequestType('');
      setRequestTitle('');
      setRequestDescription('');
      setRequestPriority('medium');
      await loadAdminRequests(); // 重新加载管理请求列表
      message.success('管理请求已提交成功');
    } catch (error: any) {
      const errorMsg = error?.response?.data?.detail || error?.message || '提交失败';
      message.error(errorMsg);
    }
  };

  const sendAdminMessage = async () => {
    if (!newAdminMessage.trim()) {
      return;
    }
    
    try {
      await sendAdminChatMessage(newAdminMessage);
      setNewAdminMessage('');
      await loadAdminChatMessages(); // 重新加载聊天记录
      message.success('消息发送成功');
    } catch (error: any) {
      const errorMsg = error?.response?.data?.detail || error?.message || '发送失败';
      message.error(errorMsg);
    }
  };

  const loadChatMessages = async (chatId: string) => {
    try {
      const messagesData = await getCustomerServiceMessages(chatId);
      
      // 确保 messagesData 是数组
      if (Array.isArray(messagesData)) {
        const processedMessages = messagesData.map((msg: any) => {
          const { isTaskCard, taskId } = parseTaskCardMessage(msg);
          return {
            ...msg,
            message_type: isTaskCard ? 'task_card' : (msg.message_type || 'text'),
            task_id: taskId || msg.task_id,
            content: isTaskCard ? '任务卡片' : msg.content
          };
        });
        
        // 直接设置服务器返回的消息，确保只显示当前chat_id的消息
        setChatMessages(processedMessages);
      } else {
                setChatMessages([]);
      }
    } catch (error) {
            setChatMessages([]);
    }
  };

  // 检查对话超时状态
  const handleCheckChatTimeoutStatus = async (chatId: string) => {
    try {
      const status = await checkChatTimeoutStatus(chatId);
      setChatTimeoutStatus(status);
      return status;
    } catch (error) {
      // 如果检查失败，清除当前状态
      setChatTimeoutStatus(null);
      return null;
    }
  };

  // 超时结束对话
  const handleTimeoutEndChat = async (chatId: string) => {
    try {
      await timeoutEndChat(chatId);
      
      // 先更新本地状态，避免状态不一致
      setSessions(prevSessions => 
        prevSessions.map(session => 
          session.chat_id === chatId 
            ? { ...session, is_ended: 1, ended_at: new Date().toISOString() }
            : session
        )
      );
      
      // 如果当前选中的会话被结束，清除选中状态
      if (selectedSession?.chat_id === chatId) {
        setSelectedSession(null);
        setChatMessages([]);
        setChatTimeoutStatus(null);
        
        // 清除超时检查定时器
        if (timeoutCheckInterval) {
          clearInterval(timeoutCheckInterval);
          setTimeoutCheckInterval(null);
        }
      }
      
      message.success('对话已超时结束，用户已收到通知');
      
      // 异步重新加载会话列表以确保数据同步
      setTimeout(() => {
        loadSessions();
      }, 100);
      
      return { success: true };
    } catch (error: any) {
      const errorMsg = error?.response?.data?.detail || error?.message || '超时结束失败';
      message.error(errorMsg);
      return null;
    }
  };

  const sendChatMessage = async () => {
    
    if (!inputMessage.trim()) {
      return;
    }
    
    if (!selectedSession) {
      return;
    }
    
    if (selectedSession.is_ended === 1) {
      alert('会话已结束，无法发送消息');
      return;
    }
    
    if (!ws) {
      return;
    }
    
    // 检查WebSocket连接状态
    if (ws.readyState !== WebSocket.OPEN) {
      return;
    }

    const messageContent = inputMessage.trim();
    const currentTime = TimeHandlerV2.formatDetailedTime(new Date().toISOString(), userTimezone);

    try {
      // 通过WebSocket发送消息
      const messageData = {
        receiver_id: selectedSession.user_id,
        content: messageContent,
        chat_id: selectedSession.chat_id
      };
      
      ws.send(JSON.stringify(messageData));
      
      // 立即添加消息到前端，提供即时反馈
      const newMessage = {
        id: Date.now(), // 临时ID
        sender_id: currentUser.id,
        receiver_id: selectedSession.user_id,
        content: messageContent,
        created_at: new Date().toISOString(), // 使用ISO格式，前端会转换为英国时间显示
        is_read: 0,
        is_admin_msg: 0,
        sender_type: 'customer_service'
      };
      
      setChatMessages(prev => [...prev, newMessage]);
      
      // 清空输入框
      setInputMessage('');
      
      // 滚动到底部
      setTimeout(() => {
        if (messagesEndRef.current) {
          messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
      }, 100);
      
      // 重新检查超时状态（因为发送了新消息）
      if (selectedSession.is_ended === 0) {
        setTimeout(() => {
          handleCheckChatTimeoutStatus(selectedSession.chat_id);
        }, 1000); // 延迟1秒检查，确保后端已处理消息
      }
      
    } catch (error) {
            message.error('发送消息失败');
    }
  };
  
  // 使用模板 - 直接发送
  const sendTemplateMessage = async (templateContent: string) => {
    if (!selectedSession || selectedSession.is_ended === 1) {
      return;
    }
    
    if (!ws || ws.readyState !== WebSocket.OPEN) {
      message.error('连接未就绪，无法发送消息');
      return;
    }
    
    // 替换模板中的占位符（如果有）
    let finalContent = templateContent;
    
    // 关闭模板弹窗
    setShowTemplateModal(false);
    
    try {
      // 通过WebSocket直接发送消息
      const messageData = {
        receiver_id: selectedSession.user_id,
        content: finalContent,
        chat_id: selectedSession.chat_id
      };
      
      ws.send(JSON.stringify(messageData));
      
      // 立即添加消息到前端，提供即时反馈
      const newMessage = {
        id: Date.now(), // 临时ID
        sender_id: currentUser.id,
        receiver_id: selectedSession.user_id,
        content: finalContent,
        created_at: new Date().toISOString(),
        is_read: 0,
        is_admin_msg: 0,
        sender_type: 'customer_service'
      };
      
      setChatMessages(prev => [...prev, newMessage]);
      
      // 滚动到底部
      setTimeout(() => {
        if (messagesEndRef.current) {
          messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
      }, 100);
      
      // 重新检查超时状态（因为发送了新消息）
      if (selectedSession.is_ended === 0) {
        setTimeout(() => {
          handleCheckChatTimeoutStatus(selectedSession.chat_id);
        }, 1000); // 延迟1秒检查，确保后端已处理消息
      }
    } catch (error) {
            message.error('发送消息失败');
    }
  };
  
  // 获取任务详情
  const fetchTaskDetail = async (taskId: number) => {
    setLoadingTaskDetail(true);
    try {
      const taskData = await getTaskDetail(taskId);
      setSelectedTask(taskData);
      setShowTaskDetailModal(true);
    } catch (error: any) {
      const errorMsg = error?.response?.data?.detail || error?.message || '获取任务详情失败';
      message.error(errorMsg);
    } finally {
      setLoadingTaskDetail(false);
    }
  };
  
  // 处理任务卡片点击
  const handleTaskCardClick = (taskId: number) => {
    setSelectedTaskId(taskId);
    fetchTaskDetail(taskId);
  };
  
  // 使用模板 - 填充到输入框
  const fillTemplateMessage = (templateContent: string) => {
    if (!selectedSession || selectedSession.is_ended === 1) {
      return;
    }
    
    // 替换模板中的占位符（如果有）
    let finalContent = templateContent;
    
    // 填充到输入框
    setInputMessage(finalContent);
    
    // 关闭模板弹窗
    setShowTemplateModal(false);
    
    // 聚焦到输入框
    setTimeout(() => {
      const input = document.querySelector('input[type="text"][placeholder*="输入消息"]') as HTMLInputElement;
      if (input) {
        input.focus();
        // 将光标移到末尾
        input.setSelectionRange(finalContent.length, finalContent.length);
      }
    }, 100);
  };

  const selectSession = async (session: UserSession) => {
    setSelectedSession(session);
    selectedSessionRef.current = session;
    
    // 清除之前的超时检查定时器
    if (timeoutCheckInterval) {
      clearInterval(timeoutCheckInterval);
      setTimeoutCheckInterval(null);
    }
    
    // 重置超时状态
    setChatTimeoutStatus(null);
    
    // 消息加载由useEffect处理，避免重复调用
    
    // 标记该会话的消息为已读
    if (session.unread_count > 0) {
      try {
        await markCustomerServiceMessagesRead(session.chat_id);
        
        // 更新会话列表中的未读消息数量
        setSessions(prevSessions => 
          prevSessions.map(s => 
            s.chat_id === session.chat_id 
              ? { ...s, unread_count: 0 }
              : s
          )
        );
      } catch (error) {
              }
    }
    
    // 如果会话未结束，启动超时检查
    if (session.is_ended === 0) {
      // 立即检查一次超时状态
      await handleCheckChatTimeoutStatus(session.chat_id);
      
      // 设置定时器，每10秒检查一次超时状态，确保及时更新
      const interval = setInterval(async () => {
        await handleCheckChatTimeoutStatus(session.chat_id);
      }, 10000); // 10秒检查一次，提高响应速度
      
      setTimeoutCheckInterval(interval);
    }
  };

  // 保持 ref 与 state 同步
  useEffect(() => {
    selectedSessionRef.current = selectedSession;
  }, [selectedSession]);

  // 单一WebSocket连接 — 合并了原通知WS和主WS
  useEffect(() => {
    if (currentUser) {
      // 清理现有连接
      if (ws) {
        ws.close();
        setWs(null);
      }

      let socket: WebSocket | null = null;
      let reconnectAttempts = 0;
      const maxReconnectAttempts = 5;
      const reconnectDelay = 3000; // 3秒

      const connectWebSocket = () => {
        const wsUrl = `${WS_BASE_URL}/ws/chat/${currentUser.id}`;
        socket = new WebSocket(wsUrl);
        setWsConnectionStatus('connecting');

        socket.onopen = () => {
          setWsConnectionStatus('connected');
          setWs(socket);
          reconnectAttempts = 0;
        };

        socket.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data);

            if (msg.error) {
              return;
            }

            // 心跳：回复 pong 防止服务端超时断连
            if (msg.type === 'heartbeat' || msg.type === 'ping') {
              if (socket && socket.readyState === WebSocket.OPEN) {
                socket.send(JSON.stringify({ type: 'pong' }));
              }
              return;
            }

            // 用户连接通知（原 notification WS 逻辑）
            if (msg.type === 'user_connected' && msg.user_info) {
              setNewUserInfo({
                name: msg.user_info.name,
                id: msg.user_info.id
              });
              setShowNewUserNotification(true);
              setTimeout(() => {
                setShowNewUserNotification(false);
                setNewUserInfo(null);
              }, 3000);
              return;
            }

            // 使用 ref 获取最新的 selectedSession（避免闭包过期）
            const latestSelectedSession = selectedSessionRef.current;

            // 跳过自己发送的消息
            if (msg.from === currentUser.id) {
              return;
            }

            // 判断消息是否属于当前选中的会话
            const belongsToCurrentSession = latestSelectedSession && (
              (msg.chat_id && msg.chat_id === latestSelectedSession.chat_id) ||
              (msg.from === latestSelectedSession.user_id && msg.receiver_id === currentUser.id)
            );

            if (belongsToCurrentSession && msg.content && msg.content.trim()) {
              const { isTaskCard, taskId } = parseTaskCardMessage(msg);

              const newMessage: Message = {
                id: msg.id || Date.now(),
                sender_id: msg.from,
                receiver_id: msg.receiver_id || currentUser.id,
                content: isTaskCard ? '任务卡片' : msg.content.trim(),
                created_at: msg.created_at || new Date().toISOString(),
                is_read: 0,
                is_admin_msg: 0,
                sender_type: msg.sender_type || 'user',
                message_type: isTaskCard ? 'task_card' : 'text',
                task_id: taskId
              };

              // 按 id 去重，防止轮询 + WS 双显
              setChatMessages(prev =>
                prev.some(m => m.id === newMessage.id) ? prev : [...prev, newMessage]
              );

              setTimeout(() => {
                messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
              }, 100);

              // 正在查看该对话时立即标记已读
              if (latestSelectedSession!.chat_id) {
                markCustomerServiceMessagesRead(latestSelectedSession!.chat_id).catch(() => {});
              }
            } else if (msg.from && msg.receiver_id === currentUser.id) {
              // 不在查看该对话，增加未读数量
              setSessions(prev => prev.map(session =>
                session.user_id === msg.from
                  ? { ...session, unread_count: (session.unread_count || 0) + 1 }
                  : session
              ));
            }
          } catch (error) {
            // 静默处理解析错误
          }
        };

        socket.onerror = () => {
          setWsConnectionStatus('error');
        };

        socket.onclose = (event) => {
          setWsConnectionStatus('disconnected');
          if (event.code !== 1000 && reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++;
            setTimeout(connectWebSocket, reconnectDelay);
          }
        };
      };

      connectWebSocket();

      return () => {
        if (socket) {
          socket.close();
        }
        setWs(null);
      };
    }
  }, [currentUser?.id]);

  // 当选择会话时，加载聊天消息
  useEffect(() => {
    if (selectedSession && selectedSession.chat_id) {
      loadChatMessages(selectedSession.chat_id);
      
      // 设置定期刷新聊天记录（作为实时消息的补充，频率更低）
      const interval = setInterval(() => {
        if (selectedSession && selectedSession.chat_id) {
          loadChatMessages(selectedSession.chat_id);
        }
      }, 30000); // 每30秒刷新一次，作为实时消息的补充
      
      return () => {
        clearInterval(interval);
      };
    }
  }, [selectedSession?.chat_id]); // 只在chat_id改变时重新加载

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages]);

  const loadCustomerServiceStatus = async () => {
    try {
      // 如果刚刚进行了手动切换，跳过自动刷新
      if (justToggledStatus) {
        return;
      }
      
      const status = await getCustomerServiceStatus();
      setIsOnline(status.is_online);
      
      // 更新当前用户的评分数据（只在数据真正改变时更新）
      if (status.service && currentUser) {
        const newAvgRating = status.service.avg_rating;
        const newTotalRatings = status.service.total_ratings;
        
        // 只在数据真正改变时才更新，避免不必要的重渲染
        if (currentUser.avg_rating !== newAvgRating || currentUser.total_ratings !== newTotalRatings) {
          setCurrentUser((prev: any) => ({
            ...prev,
            avg_rating: newAvgRating,
            total_ratings: newTotalRatings
          }));
        }
      }
      
    } catch (error) {
          }
  };

  const toggleOnlineStatus = async () => {
    try {
      const newStatus = !isOnline;
      if (isOnline) {
        await setCustomerServiceOffline();
      } else {
        await setCustomerServiceOnline();
      }
      setIsOnline(newStatus);
      setJustToggledStatus(true); // 标记刚刚进行了手动切换
      message.success(newStatus ? '已设置为在线状态' : '已设置为离线状态');
      
      // 5秒后清除手动切换标记，允许自动刷新
      setTimeout(() => {
        setJustToggledStatus(false);
      }, 5000);
    } catch (error) {
            message.error('状态切换失败');
    }
  };

  const renderDashboard = () => (
    <div className="dashboard">
      <div className="dashboard-header">
        <h2>客服状态管理</h2>
        <div className="header-decoration">
          <span className="decoration-dot"></span>
          <span className="decoration-dot"></span>
          <span className="decoration-dot"></span>
        </div>
      </div>
      
      <div className="customer-service-status">
        <div className="status-card">
          <div className="status-header">
            <div className="service-avatar">
              <LazyImage 
                src={formatImageUrl("/static/service.png")}
                alt="客服头像" 
                className="avatar-image"
                width={60}
                height={60}
              />
              <div className={`status-indicator ${isOnline ? 'online' : 'offline'}`}></div>
            </div>
            <div className="service-info">
              <h3 className="service-name">{currentUser?.name || '未知客服'}</h3>
              <p className="service-id">ID: {currentUser?.id || '未知'}</p>
            </div>
          </div>
          
          <div className="status-metrics">
            <div className="metric-item">
              <div className="metric-icon">📊</div>
              <div className="metric-content">
                <div className="metric-value">
                  {currentUser?.avg_rating ? currentUser.avg_rating.toFixed(1) : '0.0'}
                </div>
                <div className="metric-label">平均评分</div>
              </div>
            </div>
            
            <div className="metric-item">
              <div className="metric-icon">⭐</div>
              <div className="metric-content">
                <div className="metric-value">{currentUser?.total_ratings || 0}</div>
                <div className="metric-label">总评分数</div>
              </div>
            </div>
            
            <div className="metric-item">
              <div className="metric-icon">💬</div>
              <div className="metric-content">
                <div className="metric-value">{sessions.length}</div>
                <div className="metric-label">当前会话</div>
              </div>
            </div>
          </div>
          
          <div className="status-controls">
            <button
              onClick={toggleOnlineStatus}
              className={`status-toggle-btn ${isOnline ? 'offline' : 'online'}`}
            >
              <span className="btn-icon">{isOnline ? '🔴' : '🟢'}</span>
              <span className="btn-text">{isOnline ? '设为离线' : '设为在线'}</span>
            </button>
            
            <button
              onClick={testWebSocketConnection}
              style={{
                padding: '8px 16px',
                backgroundColor: '#17a2b8',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                marginLeft: '10px'
              }}
            >
              🔧 测试WebSocket连接
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  const renderUserManagement = () => (
    <div className="user-management">
      <h2>用户管理</h2>
      
      <div className="filters">
        <input
          type="text"
          placeholder="搜索用户..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="search-input"
        />
        <select
          value={filterType}
          onChange={(e) => setFilterType(e.target.value)}
          className="filter-select"
        >
          <option value="all">全部用户</option>
          <option value="banned">已封禁</option>
          <option value="suspended">已暂停</option>
          <option value="vip">VIP用户</option>
          <option value="super">超级用户</option>
        </select>
      </div>

      <div className="users-table">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>姓名</th>
              <th>邮箱</th>
              <th>等级</th>
              <th>评分</th>
              <th>任务数</th>
              <th>状态</th>
              <th>注册时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {filteredUsers.map(user => (
              <tr key={user.id}>
                <td>{user.id}</td>
                <td>{user.name}</td>
                <td>{user.email}</td>
                <td>
                  <span className={`level-badge ${user.user_level}`}>
                    {user.user_level.toUpperCase()}
                  </span>
                </td>
                <td>{user.avg_rating.toFixed(1)} ⭐</td>
                <td>{user.task_count}</td>
                <td>
                  {user.is_banned === 1 && <span className="status-badge banned">已封禁</span>}
                  {user.is_suspended === 1 && <span className="status-badge suspended">已暂停</span>}
                  {user.is_banned === 0 && user.is_suspended === 0 && 
                    <span className="status-badge active">正常</span>}
                </td>
                <td>{formatUKDate(user.created_at)}</td>
                <td>
                  <div className="action-buttons">
                    {user.is_banned === 0 ? (
                      <button
                        onClick={() => handleUserAction(user.id, 'ban')}
                        className="btn-danger"
                      >
                        封禁
                      </button>
                    ) : (
                      <button
                        onClick={() => handleUserAction(user.id, 'unban')}
                        className="btn-success"
                      >
                        解封
                      </button>
                    )}
                    
                    {user.is_suspended === 0 ? (
                      <button
                        onClick={() => handleUserAction(user.id, 'suspend')}
                        className="btn-warning"
                      >
                        暂停
                      </button>
                    ) : (
                      <button
                        onClick={() => handleUserAction(user.id, 'unsuspend')}
                        className="btn-success"
                      >
                        恢复
                      </button>
                    )}
                    
                                         {/* 移除等级修改和回复功能 */}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );

  const renderTaskManagement = () => {
    // 过滤任务
    const filteredTasks = filterTasks(tasks, taskSearchTerm);
    
    return (
      <div className="task-management">
        <h2>任务管理</h2>
        
        {/* 任务搜索 */}
        <div style={{ marginBottom: 20 }}>
          <input
            type="text"
            placeholder="搜索任务..."
            value={taskSearchTerm}
            onChange={(e) => setTaskSearchTerm(e.target.value)}
            style={{
              width: '100%',
              padding: '12px',
              borderRadius: 6,
              border: '1px solid #d9d9d9',
              fontSize: 14,
              outline: 'none',
              transition: 'border-color 0.2s'
            }}
          />
        </div>
        
        <div className="tasks-table">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>标题</th>
                <th>状态</th>
                <th>等级</th>
                <th>奖励</th>
                <th>发布者</th>
                <th>接受者</th>
                <th>创建时间</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {filteredTasks.map(task => (
                <tr key={task.id}>
                  <td>{task.id}</td>
                  <td>{task.title}</td>
                  <td>
                    <span className={`status-badge ${task.status}`}>
                      {(task.status === 'open' || task.status === 'taken') && '开放'}
                      {task.status === 'in_progress' && '进行中'}
                      {task.status === 'completed' && '已完成'}
                      {task.status === 'cancelled' && '已取消'}
                    </span>
                  </td>
                  <td>
                    <span className={`level-badge ${task.task_level}`}>
                      {task.task_level.toUpperCase()}
                    </span>
                  </td>
                  <td>£{task.reward}</td>
                  <td>{task.poster_id}</td>
                  <td>{task.taker_id || '-'}</td>
                  <td>{formatUKDate(task.created_at)}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button
                        onClick={() => navigate(`/tasks/${task.id}`)}
                        className="btn-primary"
                        style={{ fontSize: 12, padding: '4px 8px' }}
                      >
                        查看详情
                      </button>
                      <button
                        onClick={() => deleteTask(task.id)}
                        className="btn-danger"
                        style={{ fontSize: 12, padding: '4px 8px' }}
                      >
                        删除
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          
          {filteredTasks.length === 0 && (
            <div style={{ 
              textAlign: 'center', 
              padding: '40px', 
              color: '#666',
              fontSize: 16
            }}>
              {taskSearchTerm ? '没有找到匹配的任务' : '暂无任务数据'}
            </div>
          )}
        </div>
      </div>
    );
  };

  const renderMessageCenter = () => (
    <div className="customer-chat">
      <h2>客服聊天</h2>
      
      <div style={{ 
        display: 'flex', 
        gap: 20,
        height: 'calc(100vh - 300px)',
        background: '#fff',
        borderRadius: 12,
        boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        
        {/* 左侧用户会话列表 */}
        <div style={{ 
          width: 300, 
          borderRight: '1px solid #eee',
          background: '#f8fbff',
          overflowY: 'auto'
        }}>
          <div style={{ 
            padding: '20px', 
            borderBottom: '1px solid #eee',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center'
          }}>
            <div style={{
              fontWeight: 700, 
              color: '#A67C52',
              fontSize: 18
            }}>
              用户会话 ({sessions.length})
            </div>
            {endedSessions.length > 50 && (
              <button
                onClick={async () => {
                  Modal.confirm({
                    title: '确认清理',
                    content: '确定要清理超过50个的旧已结束对话吗？此操作不可撤销。',
                    okText: '确定',
                    cancelText: '取消',
                    onOk: async () => {
                      try {
                        await cleanupOldChats(currentUser.id);
                        message.success('清理成功');
                        loadSessions(); // 重新加载会话列表
                      } catch (error: any) {
                        const errorMsg = error?.response?.data?.detail || error?.message || '清理失败';
                        message.error(errorMsg);
                      }
                    }
                  });
              }}
                style={{
                  padding: '6px 12px',
                  fontSize: 12,
                  background: '#ff4d4f',
                  color: 'white',
                  border: 'none',
                  borderRadius: 4,
                  cursor: 'pointer'
                }}
              >
                清理旧对话
              </button>
            )}
          </div>
          
          {sessions.length === 0 ? (
            <div style={{ 
              textAlign: 'center', 
              padding: '40px 20px',
              color: '#666'
            }}>
              暂无用户会话
            </div>
          ) : (
            <>
              {/* 进行中的对话 */}
              {activeSessions.length > 0 && (
                <>
                  <div style={{
                    padding: '10px 20px',
                    background: '#f0f9ff',
                    borderBottom: '1px solid #e6f7ff',
                    fontSize: 12,
                    color: '#1890ff',
                    fontWeight: 'bold'
                  }}>
                    进行中的对话 ({activeSessions.length})
                  </div>
                  {activeSessions.map(session => (
                    <div
                      key={session.chat_id}
                      onClick={() => selectSession(session)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 12,
                        padding: '15px 20px',
                        cursor: 'pointer',
                        background: selectedSession?.chat_id === session.chat_id ? '#e6f7ff' : 'transparent',
                        borderBottom: '1px solid #f0f0f0',
                        position: 'relative'
                      }}
                    >
                      <LazyImage 
                        src={formatImageUrl(session.user_avatar)} 
                        alt="用户头像" 
                        width={40}
                        height={40}
                        style={{ 
                          borderRadius: '50%',
                          objectFit: 'cover'
                        }} 
                      />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ 
                          fontWeight: 'bold', 
                          fontSize: 14,
                          color: '#333',
                          marginBottom: 4
                        }}>
                          {session.user_name}
                        </div>
                        <div style={{ fontSize: 12, color: '#666' }}>
                          <span>会话开始: {TimeHandlerV2.formatDetailedTime(session.created_at, userTimezone)}</span>
                        </div>
                        {/* 会话状态标签 */}
                        <div style={{ 
                          fontSize: 10, 
                          padding: '2px 6px', 
                          borderRadius: 4,
                          marginTop: 4,
                          display: 'inline-block',
                          background: '#e6f7ff',
                          color: '#1890ff'
                        }}>
                          进行中
                        </div>
                        {/* 对话ID */}
                        <div style={{ 
                          fontSize: 9, 
                          color: '#999', 
                          marginTop: 2,
                          fontFamily: 'monospace',
                          wordBreak: 'break-all'
                        }}>
                          对话ID: {session.chat_id}
                        </div>
                      </div>
                      {/* 未读消息数量 */}
                      {session.unread_count > 0 && (
                        <div style={{
                          width: 20,
                          height: 20,
                          borderRadius: '50%',
                          background: '#ff4d4f',
                          position: 'absolute',
                          top: 12,
                          right: 12,
                          border: '2px solid #fff',
                          boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
                          animation: 'pulse 2s infinite'
                        }} />
                      )}
                    </div>
                  ))}
                </>
              )}
              
              {/* 已结束的对话 */}
              {endedSessions.length > 0 && (
                <>
                  <div style={{
                    padding: '10px 20px',
                    background: '#f5f5f5',
                    borderBottom: '1px solid #e8e8e8',
                    fontSize: 12,
                    color: '#999',
                    fontWeight: 'bold'
                  }}>
                    已结束的对话 ({endedSessions.length})
                  </div>
                  {endedSessions.map(session => (
                    <div
                      key={session.chat_id}
                      onClick={() => selectSession(session)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 12,
                        padding: '15px 20px',
                        cursor: 'pointer',
                        background: selectedSession?.chat_id === session.chat_id ? '#e6f7ff' : 'transparent',
                        borderBottom: '1px solid #f0f0f0',
                        position: 'relative',
                        opacity: 0.7
                      }}
                    >
                      <LazyImage 
                        src={formatImageUrl(session.user_avatar)} 
                        alt="用户头像" 
                        width={40}
                        height={40}
                        style={{ 
                          borderRadius: '50%',
                          objectFit: 'cover',
                          filter: 'grayscale(50%)'
                        }} 
                      />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ 
                          fontWeight: 'bold', 
                          fontSize: 14,
                          color: '#666',
                          marginBottom: 4
                        }}>
                          {session.user_name}
                        </div>
                        <div style={{ fontSize: 12, color: '#999' }}>
                          <span>会话已结束</span>
                        </div>
                        {/* 会话状态标签 */}
                        <div style={{ 
                          fontSize: 10, 
                          padding: '2px 6px', 
                          borderRadius: 4,
                          marginTop: 4,
                          display: 'inline-block',
                          background: '#f5f5f5',
                          color: '#999'
                        }}>
                          已结束
                        </div>
                        {/* 对话ID */}
                        <div style={{ 
                          fontSize: 9, 
                          color: '#999', 
                          marginTop: 2,
                          fontFamily: 'monospace',
                          wordBreak: 'break-all'
                        }}>
                          对话ID: {session.chat_id}
                        </div>
                      </div>
                    </div>
                  ))}
                </>
              )}
            </>
          )}
        </div>

        {/* 右侧聊天窗口 */}
        <div style={{ 
          flex: 1, 
          display: 'flex', 
          flexDirection: 'column'
        }}>
          {selectedSession ? (
            <>
              {/* 聊天头部 */}
              <div style={{ 
                padding: '20px', 
                borderBottom: '1px solid #eee',
                display: 'flex',
                alignItems: 'center',
                gap: 12
              }}>
                <LazyImage 
                  src={formatImageUrl(selectedSession.user_avatar)}
                  alt="用户头像" 
                  width={40}
                  height={40}
                  style={{ 
                    borderRadius: '50%',
                    objectFit: 'cover'
                  }}
                  onError={(e) => {
                    // 如果用户头像加载失败，使用默认头像
                    const img = e.currentTarget as HTMLImageElement;
                    if (img) {
                      img.src = formatImageUrl('/static/avatar1.png');
                    }
                  }}
                />
                <div style={{ flex: 1 }}>
                  <div style={{ 
                    display: 'flex', 
                    alignItems: 'center', 
                    gap: 8,
                    marginBottom: 4
                  }}>
                    <div style={{ fontWeight: 600, fontSize: 18, color: '#333' }}>
                      {selectedSession.user_name}
                    </div>
                    {/* 会话状态标签 */}
                    <div style={{ 
                      fontSize: 10, 
                      padding: '2px 6px', 
                      borderRadius: 4,
                      background: selectedSession.is_ended === 1 ? '#f5f5f5' : '#e6f7ff',
                      color: selectedSession.is_ended === 1 ? '#999' : '#1890ff'
                    }}>
                      {selectedSession.is_ended === 1 ? '已结束' : '进行中'}
                    </div>
                  </div>
                  <div style={{ fontSize: 12, color: '#666' }}>
                    用户ID: {selectedSession.user_id}
                    {selectedSession.is_ended === 1 && (
                      <span style={{ marginLeft: 12, color: '#999' }}>
                        会话已结束
                      </span>
                    )}
                    {selectedSession.is_ended === 0 && chatTimeoutStatus?.timeout_available && (
                      <span style={{ marginLeft: 12, color: '#ff4d4f', fontWeight: 'bold' }}>
                        超时 ({Math.floor((chatTimeoutStatus.time_since_last_message || 0) / 60)}分钟)
                      </span>
                    )}
                  </div>
                  <div style={{ fontSize: 10, color: '#999', marginTop: 4, fontFamily: 'monospace' }}>
                    对话ID: {selectedSession.chat_id}
                  </div>
                </div>
                
                {/* 超时结束按钮 */}
                {selectedSession.is_ended === 0 && chatTimeoutStatus?.timeout_available && (
                  <button
                    onClick={() => {
                      Modal.confirm({
                        title: '确认超时结束',
                        content: '确定要超时结束此对话吗？用户将收到超时通知。',
                        okText: '确定',
                        cancelText: '取消',
                        onOk: () => {
                          handleTimeoutEndChat(selectedSession.chat_id);
                        }
                      });
                    }}
                    style={{
                      padding: '8px 16px',
                      fontSize: 12,
                      background: '#ff4d4f',
                      color: 'white',
                      border: 'none',
                      borderRadius: 6,
                      cursor: 'pointer',
                      fontWeight: 'bold',
                      boxShadow: '0 2px 4px rgba(255, 77, 79, 0.3)'
                    }}
                  >
                    超时结束
                  </button>
                )}
                
                {/* 调试信息 - 开发环境显示 */}
                {process.env.NODE_ENV === 'development' && selectedSession.is_ended === 0 && (
                  <div style={{ fontSize: 10, color: '#999', marginTop: 4 }}>
                    调试: 超时状态 = {JSON.stringify(chatTimeoutStatus)}
                  </div>
                )}
              </div>

              {/* 消息列表 */}
              <div style={{ 
                flex: 1, 
                overflowY: 'auto', 
                padding: '20px'
              }}>
                {chatMessages.map((msg, idx) => {
                  // 如果是任务卡片消息，渲染任务卡片
                  if (msg.message_type === 'task_card' && msg.task_id) {
                    return (
                      <div key={msg.id} style={{ 
                        marginBottom: 16, 
                        textAlign: 'left',
                        display: 'flex',
                        justifyContent: 'flex-start'
                      }}>
                        <div 
                          onClick={() => handleTaskCardClick(msg.task_id!)}
                          style={{ 
                            display: 'inline-block', 
                            background: '#fff', 
                            border: '2px solid #A67C52',
                            borderRadius: 12, 
                            padding: '16px', 
                            maxWidth: '400px', 
                            cursor: 'pointer',
                            boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                            transition: 'all 0.2s'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.boxShadow = '0 4px 12px rgba(166, 124, 82, 0.3)';
                            e.currentTarget.style.transform = 'translateY(-2px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.1)';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          <div style={{ 
                            display: 'flex', 
                            alignItems: 'center', 
                            gap: 12,
                            marginBottom: 8
                          }}>
                            <div style={{
                              fontSize: 24,
                              width: 48,
                              height: 48,
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              background: '#f0f0f0',
                              borderRadius: 8
                            }}>
                              📋
                            </div>
                            <div style={{ flex: 1 }}>
                              <div style={{ 
                                fontSize: 16, 
                                fontWeight: 600, 
                                color: '#333',
                                marginBottom: 4
                              }}>
                                任务卡片
                              </div>
                              <div style={{ 
                                fontSize: 12, 
                                color: '#666',
                                marginBottom: 4
                              }}>
                                任务ID: <span style={{ fontFamily: 'monospace', fontWeight: 600, color: '#A67C52' }}>{msg.task_id}</span>
                              </div>
                              <div style={{ 
                                fontSize: 12, 
                                color: '#999'
                              }}>
                                点击查看任务详情
                              </div>
                            </div>
                          </div>
                          <div style={{ 
                            fontSize: 12, 
                            color: '#999', 
                            marginTop: 8,
                            paddingTop: 8,
                            borderTop: '1px solid #eee'
                          }}>
                            {TimeHandlerV2.formatDetailedTime(msg.created_at, userTimezone)}
                          </div>
                        </div>
                      </div>
                    );
                  }
                  
                  // 普通文本消息
                  return (
                    <div key={msg.id} style={{ 
                      marginBottom: 16, 
                      textAlign: msg.sender_type === 'customer_service' ? 'right' : 'left',
                      display: 'flex',
                      justifyContent: msg.sender_type === 'system' ? 'center' : (msg.sender_type === 'customer_service' ? 'flex-end' : 'flex-start')
                    }}>
                      <div style={{ 
                        display: 'inline-block', 
                        background: msg.sender_type === 'system' ? '#f0f0f0' : (msg.sender_type === 'customer_service' ? '#A67C52' : '#e6f7ff'), 
                        color: msg.sender_type === 'system' ? '#666' : (msg.sender_type === 'customer_service' ? '#fff' : '#333'), 
                        borderRadius: 16, 
                        padding: '8px 16px', 
                        maxWidth: '80%', 
                        wordBreak: 'break-all',
                        border: msg.sender_type === 'system' ? '1px solid #ddd' : 'none'
                      }}>
                        <div style={{ fontSize: 16 }}>{msg.content}</div>
                        <div style={{ 
                          fontSize: 12, 
                          color: msg.sender_type === 'system' ? '#999' : (msg.sender_type === 'customer_service' ? 'rgba(255,255,255,0.7)' : '#888'), 
                          marginTop: 4 
                        }}>
                          {TimeHandlerV2.formatDetailedTime(msg.created_at, userTimezone)}
                        </div>
                      </div>
                    </div>
                  );
                })}
                <div ref={messagesEndRef} />
              </div>

              {/* 输入框 */}
              <div style={{ 
                display: 'flex', 
                gap: 8, 
                padding: '20px', 
                borderTop: '1px solid #eee',
                background: '#fff'
              }}>
                {/* 模板按钮 */}
                <button
                  onClick={() => {
                    if (!selectedSession || selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected') {
                      message.warning('请先选择一个有效的会话');
                      return;
                    }
                    setShowTemplateModal(true);
                  }}
                  disabled={!selectedSession || selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected'}
                  title="选择回答模板"
                  style={{ 
                    background: (!selectedSession || selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected') ? '#f5f5f5' : '#f0f0f0', 
                    color: (!selectedSession || selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected') ? '#999' : '#A67C52', 
                    border: '1px solid #A67C52', 
                    borderRadius: 8, 
                    padding: '12px 16px', 
                    fontWeight: 600,
                    cursor: (!selectedSession || selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected') ? 'not-allowed' : 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 18,
                    transition: 'all 0.2s'
                  }}
                  onMouseEnter={(e) => {
                    if (selectedSession && selectedSession.is_ended !== 1 && wsConnectionStatus === 'connected') {
                      e.currentTarget.style.background = '#A67C52';
                      e.currentTarget.style.color = '#fff';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (selectedSession && selectedSession.is_ended !== 1 && wsConnectionStatus === 'connected') {
                      e.currentTarget.style.background = '#f0f0f0';
                      e.currentTarget.style.color = '#A67C52';
                    }
                  }}
                >
                  📝
                </button>
                <input
                  type="text"
                  value={inputMessage}
                  onChange={e => setInputMessage(e.target.value)}
                  placeholder={selectedSession.is_ended === 1 ? '会话已结束，无法发送消息' : '输入消息...'}
                  disabled={selectedSession.is_ended === 1}
                  style={{ 
                    flex: 1, 
                    padding: '12px', 
                    borderRadius: 8, 
                    border: '1px solid #A67C52',
                    fontSize: 14,
                    background: selectedSession.is_ended === 1 ? '#f5f5f5' : '#fff',
                    color: selectedSession.is_ended === 1 ? '#999' : '#333'
                  }}
                  onKeyDown={e => { 
                    if (e.key === 'Enter' && selectedSession.is_ended !== 1) {
                      sendChatMessage();
                    }
                  }}
                />
                <button
                  onClick={sendChatMessage}
                  disabled={!inputMessage.trim() || selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected'}
                  style={{ 
                    background: (selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected') ? '#f5f5f5' : '#A67C52', 
                    color: (selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected') ? '#999' : '#fff', 
                    border: 'none', 
                    borderRadius: 8, 
                    padding: '12px 24px', 
                    fontWeight: 600,
                    cursor: (selectedSession.is_ended === 1 || wsConnectionStatus !== 'connected') ? 'not-allowed' : 'pointer'
                  }}
                >
                  {selectedSession.is_ended === 1 ? '已结束' : 
                   wsConnectionStatus === 'connecting' ? '连接中...' : 
                   wsConnectionStatus === 'connected' ? '发送' :
                   wsConnectionStatus === 'error' ? '连接失败' : '未连接'}
                </button>
              </div>
            </>
          ) : (
            <div style={{ 
              flex: 1, 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'center',
              color: '#666',
              fontSize: 18
            }}>
              请选择一个用户开始聊天
            </div>
          )}
        </div>
      </div>
    </div>
  );

  const renderCancelRequests = () => (
    <div className="cancel-requests">
      <h2>取消请求审核</h2>
      
      <div className="requests-table">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>任务ID</th>
              <th>请求者ID</th>
              <th>取消原因</th>
              <th>状态</th>
              <th>请求时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {cancelRequests.map(request => (
              <tr key={request.id}>
                <td>{request.id}</td>
                <td>{request.task_id}</td>
                <td>{request.requester_id}</td>
                <td>{request.reason || '无'}</td>
                <td>
                  <span className={`status-badge ${request.status}`}>
                    {request.status === 'pending' && '待审核'}
                    {request.status === 'approved' && '已通过'}
                    {request.status === 'rejected' && '已拒绝'}
                  </span>
                </td>
                <td>{TimeHandlerV2.formatDetailedTime(request.created_at, userTimezone)}</td>
                <td>
                  {request.status === 'pending' && (
                    <div className="action-buttons">
                      <button
                        onClick={() => setSelectedCancelRequest(request)}
                        className="btn-primary"
                      >
                        审核
                      </button>
                    </div>
                  )}
                  {request.status !== 'pending' && (
                    <div>
                      <div>审核人: {request.admin_id || request.service_id || '未知'}</div>
                      <div>审核意见: {request.admin_comment || '无'}</div>
                      <div>审核时间: {request.reviewed_at ? TimeHandlerV2.formatDetailedTime(request.reviewed_at, userTimezone) : '无'}</div>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );

  const renderAdminManagement = () => (
    <div className="admin-management">
      <div className="admin-header">
        <h2>后台管理</h2>
        <button
          onClick={() => setShowRequestForm(true)}
          className="btn-primary"
          style={{ padding: '8px 16px', fontSize: 14 }}
        >
          + 提交管理请求
        </button>
      </div>

      <div className="admin-content">
        {/* 管理聊天区域 */}
        <div className="admin-chat-section">
          <h3>与后台工作人员交流</h3>
          <div className="chat-messages" style={{
            height: 300,
            border: '1px solid #e8e8e8',
            borderRadius: 8,
            padding: 16,
            overflowY: 'auto',
            marginBottom: 16,
            backgroundColor: '#fafafa'
          }}>
            {adminChatMessages.length === 0 ? (
              <div style={{ textAlign: 'center', color: '#999', padding: '40px 0' }}>
                暂无聊天记录
              </div>
            ) : (
              adminChatMessages.map((message, index) => (
                <div key={index} style={{
                  marginBottom: 12,
                  padding: 8,
                  backgroundColor: message.sender_type === 'admin' ? '#e6f7ff' : '#f6ffed',
                  borderRadius: 8,
                  border: `1px solid ${message.sender_type === 'admin' ? '#91d5ff' : '#b7eb8f'}`
                }}>
                  <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>
                    {message.sender_type === 'admin' ? '后台工作人员' : '我'} - {TimeHandlerV2.formatDetailedTime(message.created_at, userTimezone)}
                  </div>
                  <div>{message.content}</div>
                </div>
              ))
            )}
          </div>
          <div className="chat-input" style={{ display: 'flex', gap: 8 }}>
            <input
              type="text"
              value={newAdminMessage}
              onChange={(e) => setNewAdminMessage(e.target.value)}
              placeholder="输入消息..."
              style={{ flex: 1, padding: '8px 12px', border: '1px solid #d9d9d9', borderRadius: 6 }}
              onKeyDown={(e) => e.key === 'Enter' && sendAdminMessage()}
            />
            <button
              onClick={sendAdminMessage}
              className="btn-primary"
              style={{ padding: '8px 16px' }}
            >
              发送
            </button>
          </div>
        </div>

        {/* 管理请求列表 */}
        <div className="admin-requests-section">
          <h3>我的管理请求</h3>
          <div className="requests-table">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>类型</th>
                  <th>标题</th>
                  <th>优先级</th>
                  <th>状态</th>
                  <th>提交时间</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody>
                {adminRequests.length === 0 ? (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', padding: '40px' }}>暂无管理请求</td>
                  </tr>
                ) : (
                  adminRequests.map(request => (
                    <tr key={request.id}>
                      <td>{request.id}</td>
                      <td>
                        <span style={{
                          padding: '4px 8px',
                          borderRadius: 12,
                          fontSize: 12,
                          fontWeight: 600,
                          background: request.type === 'task_status' ? '#e6f7ff' : 
                                     request.type === 'user_ban' ? '#fff1f0' : 
                                     request.type === 'feedback' ? '#f6ffed' : '#f0f0f0',
                          color: request.type === 'task_status' ? '#1890ff' : 
                                 request.type === 'user_ban' ? '#f5222d' : 
                                 request.type === 'feedback' ? '#52c41a' : '#666'
                        }}>
                          {request.type === 'task_status' ? '任务状态' : 
                           request.type === 'user_ban' ? '用户封禁' : 
                           request.type === 'feedback' ? '反馈情况' : request.type}
                        </span>
                      </td>
                      <td>{request.title}</td>
                      <td>
                        <span style={{
                          padding: '4px 8px',
                          borderRadius: 12,
                          fontSize: 12,
                          fontWeight: 600,
                          background: request.priority === 'high' ? '#fff1f0' : 
                                     request.priority === 'medium' ? '#fff2e8' : '#f6ffed',
                          color: request.priority === 'high' ? '#f5222d' : 
                                 request.priority === 'medium' ? '#fa8c16' : '#52c41a'
                        }}>
                          {request.priority === 'high' ? '高' : 
                           request.priority === 'medium' ? '中' : '低'}
                        </span>
                      </td>
                      <td>
                        <span style={{
                          padding: '4px 8px',
                          borderRadius: 12,
                          fontSize: 12,
                          fontWeight: 600,
                          background: request.status === 'pending' ? '#fff2e8' : 
                                     request.status === 'processing' ? '#e6f7ff' : 
                                     request.status === 'completed' ? '#f6ffed' : '#fff1f0',
                          color: request.status === 'pending' ? '#fa8c16' : 
                                 request.status === 'processing' ? '#1890ff' : 
                                 request.status === 'completed' ? '#52c41a' : '#f5222d'
                        }}>
                          {request.status === 'pending' ? '待处理' : 
                           request.status === 'processing' ? '处理中' : 
                           request.status === 'completed' ? '已完成' : '已拒绝'}
                        </span>
                      </td>
                      <td>{TimeHandlerV2.formatDetailedTime(request.created_at, userTimezone)}</td>
                      <td>
                        <button
                          onClick={() => {
                            alert(`请求详情：\n标题：${request.title}\n描述：${request.description}\n状态：${request.status}`);
                          }}
                          className="btn-secondary"
                          style={{ fontSize: 12, padding: '4px 8px' }}
                        >
                          查看
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* 提交请求弹窗 */}
      {showRequestForm && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 10000
        }}>
          <div style={{
            backgroundColor: '#fff',
            borderRadius: 12,
            padding: '24px 32px',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.2)',
            textAlign: 'left',
            maxWidth: 600,
            width: '90%',
            animation: 'slideInDown 0.3s ease-out'
          }}>
            <h3 style={{ margin: '0 0 20px 0', fontSize: 20, fontWeight: 600, color: '#262626' }}>
              提交管理请求
            </h3>
            
            <div style={{ marginBottom: 16 }}>
              <label style={{ display: 'block', marginBottom: 8, fontWeight: 600 }}>
                请求类型:
              </label>
              <select
                value={selectedRequestType}
                onChange={(e) => setSelectedRequestType(e.target.value)}
                style={{ width: '100%', padding: '8px 12px', border: '1px solid #d9d9d9', borderRadius: 6 }}
              >
                <option value="">请选择请求类型</option>
                <option value="task_status">修改任务状态</option>
                <option value="user_ban">封禁用户</option>
                <option value="feedback">反馈情况</option>
                <option value="other">其他</option>
              </select>
            </div>

            <div style={{ marginBottom: 16 }}>
              <label style={{ display: 'block', marginBottom: 8, fontWeight: 600 }}>
                请求标题:
              </label>
              <input
                type="text"
                value={requestTitle}
                onChange={(e) => setRequestTitle(e.target.value)}
                placeholder="请输入请求标题"
                style={{ width: '100%', padding: '8px 12px', border: '1px solid #d9d9d9', borderRadius: 6 }}
              />
            </div>

            <div style={{ marginBottom: 16 }}>
              <label style={{ display: 'block', marginBottom: 8, fontWeight: 600 }}>
                请求描述:
              </label>
              <textarea
                value={requestDescription}
                onChange={(e) => setRequestDescription(e.target.value)}
                placeholder="请详细描述您的请求..."
                rows={4}
                style={{ width: '100%', padding: '8px 12px', border: '1px solid #d9d9d9', borderRadius: 6 }}
              />
            </div>

            <div style={{ marginBottom: 20 }}>
              <label style={{ display: 'block', marginBottom: 8, fontWeight: 600 }}>
                优先级:
              </label>
              <select
                value={requestPriority}
                onChange={(e) => setRequestPriority(e.target.value)}
                style={{ width: '100%', padding: '8px 12px', border: '1px solid #d9d9d9', borderRadius: 6 }}
              >
                <option value="low">低</option>
                <option value="medium">中</option>
                <option value="high">高</option>
              </select>
            </div>

            <div className="modal-actions">
              <button
                onClick={handleSubmitAdminRequest}
                className="btn-primary"
              >
                提交请求
              </button>
              <button
                onClick={() => {
                  setShowRequestForm(false);
                  setSelectedRequestType('');
                  setRequestTitle('');
                  setRequestDescription('');
                  setRequestPriority('medium');
                }}
                className="btn-secondary"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );

  return (
    <div className="customer-service">
      <div className="header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          {/* 客服在线状态控制 */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ 
              fontSize: 14, 
              color: '#666',
              fontWeight: 600
            }}>
              客服状态:
            </span>
            <span style={{ 
              padding: '4px 8px',
              borderRadius: 12,
              fontSize: 12,
              fontWeight: 600,
              background: isOnline ? '#e6f7ff' : '#fff2e8',
              color: isOnline ? '#1890ff' : '#fa8c16',
              border: `1px solid ${isOnline ? '#91d5ff' : '#ffd591'}`
            }}>
              {isOnline ? '在线' : '离线'}
            </span>
            <button
              onClick={toggleOnlineStatus}
              style={{
                padding: '6px 12px',
                borderRadius: 6,
                border: 'none',
                fontSize: 12,
                fontWeight: 600,
                cursor: 'pointer',
                background: isOnline ? '#ff4d4f' : '#52c41a',
                color: '#fff',
                transition: 'all 0.3s'
              }}
            >
              {isOnline ? '设为离线' : '设为在线'}
            </button>
          </div>
          
          {/* 提醒按钮 */}
          <NotificationBell 
            ref={notificationBellRef}
            userType="customer_service" 
            onOpenModal={() => setShowNotificationModal(true)}
          />
          
          <button
            onClick={handleLogout}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: '1px solid #ff4d4f',
              fontSize: 12,
              fontWeight: 600,
              cursor: 'pointer',
              background: '#fff',
              color: '#ff4d4f',
              transition: 'all 0.3s'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = '#ff4d4f';
              e.currentTarget.style.color = '#fff';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = '#fff';
              e.currentTarget.style.color = '#ff4d4f';
            }}
          >
            退出登录
          </button>
          
        </div>
      </div>

      <div className="tabs">
        <button
          className={activeTab === 'dashboard' ? 'active' : ''}
          onClick={() => setActiveTab('dashboard')}
        >
          客服状态
        </button>
        <button
          className={activeTab === 'messages' ? 'active' : ''}
          onClick={() => setActiveTab('messages')}
          style={{ position: 'relative' }}
        >
          用户会话
          {/* 未读消息红点提示 */}
          {totalUnreadCount > 0 && (
            <div style={{
              position: 'absolute',
              top: 5,
              right: 8,
              minWidth: 18,
              height: 18,
              borderRadius: '50%',
              background: '#ff4d4f',
              color: '#fff',
              fontSize: 12,
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid #fff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
              animation: 'pulse 2s infinite'
            }}>
              {totalUnreadCount > 99 ? '99+' : totalUnreadCount}
            </div>
          )}
        </button>
        <button
          className={activeTab === 'cancel-requests' ? 'active' : ''}
          onClick={() => setActiveTab('cancel-requests')}
          style={{ position: 'relative' }}
        >
          取消请求
          {/* 待审核取消请求红点提示 */}
          {pendingCancelCount > 0 && (
            <div style={{
              position: 'absolute',
              top: 5,
              right: 8,
              minWidth: 18,
              height: 18,
              borderRadius: '50%',
              background: '#ff4d4f',
              color: '#fff',
              fontSize: 12,
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid #fff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
              animation: 'pulse 2s infinite'
            }}>
              {pendingCancelCount}
            </div>
          )}
        </button>
        <button
          className={activeTab === 'admin-management' ? 'active' : ''}
          onClick={() => setActiveTab('admin-management')}
          style={{ position: 'relative' }}
        >
          后台管理
          {/* 待处理管理请求红点提示 */}
          {pendingAdminCount > 0 && (
            <div style={{
              position: 'absolute',
              top: 5,
              right: 8,
              minWidth: 18,
              height: 18,
              borderRadius: '50%',
              background: '#ff4d4f',
              color: '#fff',
              fontSize: 12,
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid #fff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
              animation: 'pulse 2s infinite'
            }}>
              {pendingAdminCount}
            </div>
          )}
        </button>
      </div>

      <div className="content">
        {loading ? (
          <div className="loading">加载中...</div>
        ) : (
          <>
        {activeTab === 'dashboard' && renderDashboard()}
        {activeTab === 'messages' && renderMessageCenter()}
        {activeTab === 'cancel-requests' && renderCancelRequests()}
        {activeTab === 'admin-management' && renderAdminManagement()}
          </>
        )}
      </div>

      {/* 移除回复消息弹窗 */}

      {/* 审核取消请求弹窗 */}
      {selectedCancelRequest && (
        <div className="modal-overlay">
          <div className="modal" style={{maxWidth: '600px'}}>
            <h3>审核取消请求</h3>
            <div className="request-info" style={{ 
              marginBottom: '20px',
              padding: '16px',
              background: '#f9fafb',
              borderRadius: '8px'
            }}>
              <div style={{marginBottom: '12px'}}>
                <strong>任务标题:</strong> {selectedCancelRequest.task?.title || '未知'}
              </div>
              <div style={{marginBottom: '12px'}}>
                <strong>任务状态:</strong> 
                <span style={{
                  padding: '4px 8px',
                  borderRadius: '4px',
                  marginLeft: '8px',
                  background: selectedCancelRequest.task?.status === 'in_progress' ? '#dbeafe' : 
                              selectedCancelRequest.task?.status === 'completed' ? '#dcfce7' :
                              selectedCancelRequest.task?.status === 'cancelled' ? '#fee2e2' : '#f3f4f6'
                }}>
                  {selectedCancelRequest.task?.status === 'open' ? '待接取' :
                   selectedCancelRequest.task?.status === 'taken' ? '待审核申请' :
                   selectedCancelRequest.task?.status === 'in_progress' ? '进行中' :
                   selectedCancelRequest.task?.status === 'completed' ? '已完成' :
                   selectedCancelRequest.task?.status === 'cancelled' ? '已取消' :
                   selectedCancelRequest.task?.status === 'deleted' ? '任务已删除' :
                   '未知'}
                </span>
              </div>
              <div style={{marginBottom: '12px'}}>
                <strong>请求者:</strong> {selectedCancelRequest.requester_name || selectedCancelRequest.requester_id}
              </div>
              <div style={{marginBottom: '12px'}}>
                <strong>用户身份:</strong> 
                <span style={{
                  padding: '4px 8px',
                  borderRadius: '4px',
                  marginLeft: '8px',
                  background: selectedCancelRequest.user_role === '发布者' ? '#e0f2fe' : '#fef3c7',
                  color: selectedCancelRequest.user_role === '发布者' ? '#0369a1' : '#92400e'
                }}>
                  {selectedCancelRequest.user_role || '未知'}
                </span>
              </div>
              <div style={{marginBottom: '12px'}}>
                <strong>任务ID:</strong> {selectedCancelRequest.task_id}
              </div>
              <div style={{marginBottom: '12px'}}>
                <strong>取消原因:</strong> 
                <div style={{
                  marginTop: '4px',
                  padding: '8px',
                  background: 'white',
                  borderRadius: '4px',
                  border: '1px solid #e5e7eb'
                }}>
                  {selectedCancelRequest.reason || '无'}
                </div>
              </div>
              <div>
                <strong>请求时间:</strong> {TimeHandlerV2.formatDetailedTime(selectedCancelRequest.created_at, userTimezone)}
              </div>
            </div>
            <div style={{marginBottom: '16px'}}>
              <label style={{display: 'block', marginBottom: '8px', fontWeight: '600'}}>
                审核意见:
              </label>
              <textarea
                value={adminComment}
                onChange={(e) => setAdminComment(e.target.value)}
                placeholder="输入审核意见（可选）..."
                rows={4}
                style={{
                  width: '100%',
                  padding: '12px',
                  border: '1px solid #d1d5db',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontFamily: 'inherit'
                }}
              />
            </div>
            <div className="modal-actions">
              <button 
                onClick={() => handleReviewCancelRequest(selectedCancelRequest.id, 'approved')} 
                className="btn-success"
              >
                通过
              </button>
              <button 
                onClick={() => handleReviewCancelRequest(selectedCancelRequest.id, 'rejected')} 
                className="btn-danger"
              >
                拒绝
              </button>
              <button onClick={() => setSelectedCancelRequest(null)} className="btn-secondary">
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 新用户连接弹窗 */}
      {showNewUserNotification && newUserInfo && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 10000
        }}>
          <div style={{
            backgroundColor: '#fff',
            borderRadius: 12,
            padding: '24px 32px',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.2)',
            textAlign: 'center',
            maxWidth: 400,
            width: '90%',
            animation: 'slideInDown 0.3s ease-out'
          }}>
            <div style={{
              fontSize: 48,
              marginBottom: 16,
              color: '#52c41a'
            }}>
              🎉
            </div>
            <h3 style={{
              margin: '0 0 8px 0',
              fontSize: 20,
              fontWeight: 600,
              color: '#262626'
            }}>
              用户连接！
            </h3>
            <p style={{
              margin: '0 0 16px 0',
              fontSize: 16,
              color: '#595959',
              lineHeight: 1.5
            }}>
              用户 <strong style={{ color: '#1890ff' }}>{newUserInfo.name}</strong> 已连接到客服
            </p>
            <div style={{
              fontSize: 14,
              color: '#8c8c8c',
              marginBottom: 20
            }}>
              用户ID: {newUserInfo.id}
            </div>
            <button
              onClick={() => {
                setShowNewUserNotification(false);
                setNewUserInfo(null);
              }}
              style={{
                padding: '8px 24px',
                borderRadius: 6,
                border: 'none',
                backgroundColor: '#1890ff',
                color: '#fff',
                fontSize: 14,
                fontWeight: 600,
                cursor: 'pointer',
                transition: 'background-color 0.2s'
              }}
              onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#40a9ff'}
              onMouseOut={(e) => e.currentTarget.style.backgroundColor = '#1890ff'}
            >
              知道了
            </button>
          </div>
        </div>
      )}
      
      {/* 提醒弹窗 */}
      <NotificationModal
        isOpen={showNotificationModal}
        onClose={() => setShowNotificationModal(false)}
        userType="customer_service"
        onNotificationRead={handleNotificationRead}
      />
      
      {/* 模板选择弹窗 */}
      {showTemplateModal && selectedSession && (
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
            setShowTemplateModal(false);
          }
        }}
        >
          <div style={{
            backgroundColor: '#fff',
            borderRadius: 12,
            padding: '24px',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.2)',
            maxWidth: '800px',
            width: '90%',
            maxHeight: '80vh',
            display: 'flex',
            flexDirection: 'column',
            animation: 'slideInDown 0.3s ease-out'
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
                📝 选择回答模板
              </h3>
              <button
                onClick={() => setShowTemplateModal(false)}
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
              {Object.entries(templatesByCategory).map(([category, templates]) => (
                <div key={category} style={{ marginBottom: '24px' }}>
                  <div style={{
                    fontSize: 16,
                    fontWeight: 600,
                    color: '#A67C52',
                    marginBottom: '12px',
                    paddingBottom: '8px',
                    borderBottom: '1px solid #e8e8e8'
                  }}>
                    {category}
                  </div>
                  <div style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
                    gap: '12px'
                  }}>
                    {templates.map((template) => (
                      <div
                        key={template.id}
                        style={{
                          border: '1px solid #e8e8e8',
                          borderRadius: 8,
                          padding: '16px',
                          background: '#fafafa',
                          transition: 'all 0.2s',
                          cursor: 'pointer'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.borderColor = '#A67C52';
                          e.currentTarget.style.background = '#fff';
                          e.currentTarget.style.boxShadow = '0 2px 8px rgba(166, 124, 82, 0.2)';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.borderColor = '#e8e8e8';
                          e.currentTarget.style.background = '#fafafa';
                          e.currentTarget.style.boxShadow = 'none';
                        }}
                      >
                        <div style={{
                          fontSize: 14,
                          fontWeight: 600,
                          color: '#333',
                          marginBottom: '8px'
                        }}>
                          {template.title}
                        </div>
                        <div style={{
                          fontSize: 13,
                          color: '#666',
                          lineHeight: 1.5,
                          marginBottom: '12px',
                          maxHeight: '60px',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          display: '-webkit-box',
                          WebkitLineClamp: 3,
                          WebkitBoxOrient: 'vertical'
                        }}>
                          {template.content}
                        </div>
                        <div style={{
                          display: 'flex',
                          gap: '8px'
                        }}>
                          <button
                            onClick={() => sendTemplateMessage(template.content)}
                            style={{
                              flex: 1,
                              padding: '6px 12px',
                              border: '1px solid #A67C52',
                              background: '#A67C52',
                              color: '#fff',
                              borderRadius: 6,
                              cursor: 'pointer',
                              fontSize: 12,
                              fontWeight: 600,
                              transition: 'all 0.2s'
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.background = '#8b6a47';
                              e.currentTarget.style.borderColor = '#8b6a47';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.background = '#A67C52';
                              e.currentTarget.style.borderColor = '#A67C52';
                            }}
                          >
                            直接发送
                          </button>
                          <button
                            onClick={() => fillTemplateMessage(template.content)}
                            style={{
                              flex: 1,
                              padding: '6px 12px',
                              border: '1px solid #A67C52',
                              background: '#fff',
                              color: '#A67C52',
                              borderRadius: 6,
                              cursor: 'pointer',
                              fontSize: 12,
                              fontWeight: 600,
                              transition: 'all 0.2s'
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.background = '#A67C52';
                              e.currentTarget.style.color = '#fff';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.background = '#fff';
                              e.currentTarget.style.color = '#A67C52';
                            }}
                          >
                            填充编辑
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
      
      {/* 任务详情弹窗 */}
      {showTaskDetailModal && selectedTask && (
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
          zIndex: 10002,
          backdropFilter: 'blur(5px)'
        }}
        onClick={(e) => {
          if (e.target === e.currentTarget) {
            setShowTaskDetailModal(false);
            setSelectedTask(null);
            setSelectedTaskId(null);
          }
        }}
        >
          <div style={{
            backgroundColor: '#fff',
            borderRadius: 12,
            padding: '24px',
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.2)',
            maxWidth: '800px',
            width: '90%',
            maxHeight: '90vh',
            overflowY: 'auto',
            position: 'relative'
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
                📋 任务详情
              </h3>
              <button
                onClick={() => {
                  setShowTaskDetailModal(false);
                  setSelectedTask(null);
                  setSelectedTaskId(null);
                }}
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
            
            {loadingTaskDetail ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>
                加载中...
              </div>
            ) : (
              <div>
                <div style={{ marginBottom: '20px' }}>
                  <div style={{ fontSize: 14, color: '#666', marginBottom: '8px' }}>任务标题</div>
                  <div style={{ fontSize: 18, fontWeight: 600, color: '#333' }}>{selectedTask.title}</div>
                </div>
                
                <div style={{ 
                  display: 'grid', 
                  gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                  gap: '16px',
                  marginBottom: '20px'
                }}>
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>任务类型</div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: '#333' }}>{selectedTask.task_type || '未知'}</div>
                  </div>
                  
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>任务等级</div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: '#333' }}>{selectedTask.task_level || '普通'}</div>
                  </div>
                  
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>奖励</div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: '#059669' }}>£{selectedTask.reward || selectedTask.base_reward || 0}</div>
                  </div>
                  
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>状态</div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: '#333' }}>
                      {selectedTask.status === 'open' ? '待接取' :
                       selectedTask.status === 'taken' ? '待审核申请' :
                       selectedTask.status === 'in_progress' ? '进行中' :
                       selectedTask.status === 'completed' ? '已完成' :
                       selectedTask.status === 'cancelled' ? '已取消' : selectedTask.status}
                    </div>
                  </div>
                  
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>位置</div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: '#333' }}>{selectedTask.location || '未知'}</div>
                  </div>
                  
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>任务ID</div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: '#333' }}>{selectedTask.id}</div>
                  </div>
                </div>
                
                {selectedTask.description && (
                  <div style={{ marginBottom: '20px' }}>
                    <div style={{ fontSize: 14, color: '#666', marginBottom: '8px' }}>任务描述</div>
                    <div style={{ 
                      padding: '12px', 
                      background: '#f8f9fa', 
                      borderRadius: 8,
                      fontSize: 14,
                      color: '#333',
                      lineHeight: 1.6,
                      whiteSpace: 'pre-wrap'
                    }}>
                      {selectedTask.description}
                    </div>
                  </div>
                )}
                
                <div style={{ 
                  display: 'grid', 
                  gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                  gap: '16px',
                  marginBottom: '20px'
                }}>
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>发布者ID</div>
                    <div style={{ fontSize: 14, fontWeight: 600, color: '#333' }}>{selectedTask.poster_id}</div>
                  </div>
                  
                  {selectedTask.taker_id && (
                    <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                      <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>接受者ID</div>
                      <div style={{ fontSize: 14, fontWeight: 600, color: '#333' }}>{selectedTask.taker_id}</div>
                    </div>
                  )}
                  
                  <div style={{ padding: '12px', background: '#f8f9fa', borderRadius: 8 }}>
                    <div style={{ fontSize: 12, color: '#666', marginBottom: '4px' }}>创建时间</div>
                    <div style={{ fontSize: 14, fontWeight: 600, color: '#333' }}>
                      {TimeHandlerV2.formatDetailedTime(selectedTask.created_at, userTimezone)}
                    </div>
                  </div>
                </div>
                
                <div style={{ 
                  display: 'flex', 
                  justifyContent: 'flex-end',
                  gap: '12px',
                  marginTop: '24px',
                  paddingTop: '20px',
                  borderTop: '1px solid #eee'
                }}>
                  <button
                    onClick={() => {
                      setShowTaskDetailModal(false);
                      setSelectedTask(null);
                      setSelectedTaskId(null);
                    }}
                    style={{
                      padding: '8px 16px',
                      border: '1px solid #d9d9d9',
                      background: '#fff',
                      color: '#666',
                      borderRadius: 6,
                      cursor: 'pointer',
                      fontSize: 14,
                      fontWeight: 600
                    }}
                  >
                    关闭
                  </button>
                  <button
                    onClick={() => {
                      window.open(`/tasks/${selectedTask.id}`, '_blank');
                    }}
                    style={{
                      padding: '8px 16px',
                      border: 'none',
                      background: '#A67C52',
                      color: '#fff',
                      borderRadius: 6,
                      cursor: 'pointer',
                      fontSize: 14,
                      fontWeight: 600
                    }}
                  >
                    查看完整详情
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default CustomerService; 