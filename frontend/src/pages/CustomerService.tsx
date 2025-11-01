import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { API_BASE_URL, WS_BASE_URL, API_ENDPOINTS } from '../config';
import { updateCustomerServiceName, getCustomerServiceSessions, getCustomerServiceMessages, getCustomerServiceStatus, setCustomerServiceOnline, setCustomerServiceOffline, markCustomerServiceMessagesRead } from '../api';
import NotificationBell, { NotificationBellRef } from '../components/NotificationBell';
import NotificationModal from '../components/NotificationModal';
import { TimeHandlerV2 } from '../utils/timeUtils';
import './CustomerService.css';

// 时区检测和转换工具函数
// 旧的时间处理函数已移除，现在使用 TimeHandlerV2 统一处理

// 英国时间格式化工具函数（回退）
// 旧的时间处理函数已移除，现在使用 TimeHandlerV2 统一处理

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
  admin_id: string | null;  // 现在ID是字符串类型
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
    const testUrl = `${process.env.REACT_APP_WS_URL || 'ws://localhost:8000'}/ws/chat/${currentUser?.id}`;
    
    const testSocket = new WebSocket(testUrl);
    
    testSocket.onopen = () => {
      alert('WebSocket连接测试成功！');
      testSocket.close();
    };
    
    testSocket.onerror = (error) => {
      alert('WebSocket连接测试失败，请检查网络设置');
    };
    
    testSocket.onclose = (event) => {
      // 测试连接关闭
    };
  };
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  // 客服改名相关状态
  const [showNameEditModal, setShowNameEditModal] = useState(false);
  const [newServiceName, setNewServiceName] = useState('');
  const [currentServiceName, setCurrentServiceName] = useState('');
  
  // 新用户连接弹窗状态
  const [showNewUserNotification, setShowNewUserNotification] = useState(false);
  const [newUserInfo, setNewUserInfo] = useState<{name: string, id: string} | null>(null);
  
  // 客服通知WebSocket连接
  const [notificationWs, setNotificationWs] = useState<WebSocket | null>(null);
  
  // 超时相关状态
  const [chatTimeoutStatus, setChatTimeoutStatus] = useState<{
    is_ended: boolean;
    is_timeout: boolean;
    timeout_available: boolean;
    time_since_last_message?: number;
  } | null>(null);
  const [timeoutCheckInterval, setTimeoutCheckInterval] = useState<ReturnType<typeof setInterval> | null>(null);
  
  // 计算总的未读消息数量
  const totalUnreadCount = sessions.reduce((total, session) => total + session.unread_count, 0);

  // 统计数据
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalTasks: 0,
    activeTasks: 0,
    completedTasks: 0,
    totalRevenue: 0,
    avgRating: 0
  });

  useEffect(() => {
    checkAdminStatus();
    loadData();
    loadCustomerServiceStatus();
    loadCurrentServiceName();
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
      console.error('初始化时区信息失败:', error);
    }
  };

  const checkAdminStatus = async () => {
    try {
      // 新的认证系统使用Cookie认证，不需要检查localStorage
      // 直接通过API检查客服认证状态
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/service/profile`, {
        credentials: 'include'
      });
      
      if (response.ok) {
        const service = await response.json();
        setCurrentUser(service);
        return;
      }
      
      // 如果认证失败，重定向到客服登录页面
      navigate('/en/customer-service/login');
    } catch (error) {
      console.error('客服认证检查失败:', error);
      navigate('/en/customer-service/login');
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
      console.error('加载数据失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const calculateStats = (usersData: User[], tasksData: Task[]) => {
    const totalUsers = usersData.length;
    const totalTasks = tasksData.length;
    const activeTasks = tasksData.filter(task => task.status === 'open' || task.status === 'taken').length;
    const completedTasks = tasksData.filter(task => task.status === 'completed').length;
    const totalRevenue = tasksData
      .filter(task => task.status === 'completed')
      .reduce((sum, task) => sum + task.reward, 0);
    const avgRating = usersData.length > 0 
      ? usersData.reduce((sum, user) => sum + user.avg_rating, 0) / usersData.length 
      : 0;

    setStats({
      totalUsers,
      totalTasks,
      activeTasks,
      completedTasks,
      totalRevenue,
      avgRating
    });
  };

  const sendAnnouncement = async () => {
    if (!announcement.trim()) {
      window.alert('请输入公告内容');
      return;
    }

    try {
      // 这里需要实现发送公告的API
      // 暂时使用通知API作为示例
      
      // 获取 CSRF token
      const csrfToken = document.cookie
        .split('; ')
        .find(row => row.startsWith('csrf_token='))
        ?.split('=')[1];
      
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/users/notifications/send-announcement`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
        },
        credentials: 'include',  // 使用Cookie认证
        body: JSON.stringify({
          title: '平台公告',
          content: announcement
        })
      });

      if (response.ok) {
        window.alert('公告发送成功');
        setAnnouncement('');
      } else {
        window.alert('公告发送失败');
      }
    } catch (error) {
      console.error('发送公告失败:', error);
      window.alert('发送公告失败');
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
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/service/logout`, {
        method: 'POST',
        credentials: 'include'
      });

      if (response.ok) {
        // 3. 清理本地状态
        setCurrentUser(null);
        setIsOnline(false);
        
        // 4. 关闭WebSocket连接
        if (ws) {
          ws.close();
          setWs(null);
        }
        
        // 5. 关闭通知WebSocket连接
        if (notificationWs) {
          notificationWs.close();
          setNotificationWs(null);
        }
        
        // 6. 清理超时检查
        if (timeoutCheckInterval) {
          clearInterval(timeoutCheckInterval);
          setTimeoutCheckInterval(null);
        }
        
        // 7. 跳转到登录页面
        navigate('/service/login');
      } else {
        console.error('客服登出失败');
        window.alert('登出失败，请重试');
      }
    } catch (error) {
      console.error('客服登出时发生错误:', error);
      window.alert('登出时发生错误，请重试');
    }
  };

  const handleUserAction = async (userId: string, action: string, value?: any) => {
    try {
      let endpoint = '';
      let body = {};

      switch (action) {
        case 'ban':
          endpoint = `/api/admin/user/${userId}/set_status`;
          body = { is_banned: 1 };
          break;
        case 'unban':
          endpoint = `/api/admin/user/${userId}/set_status`;
          body = { is_banned: 0 };
          break;
        case 'suspend':
          endpoint = `/api/admin/user/${userId}/set_status`;
          body = { is_suspended: 1 };
          break;
        case 'unsuspend':
          endpoint = `/api/admin/user/${userId}/set_status`;
          body = { is_suspended: 0 };
          break;
        case 'setLevel':
          endpoint = `/api/admin/user/${userId}/set_level`;
          body = value;
          break;
      }

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',  // 使用Cookie认证
        body: JSON.stringify(body)
      });

      if (response.ok) {
        window.alert('操作成功');
        loadData(); // 重新加载数据
      } else {
        window.alert('操作失败');
      }
    } catch (error) {
      console.error('操作失败:', error);
      window.alert('操作失败');
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
    if (!window.confirm('确定要删除这个任务吗？此操作不可撤销。')) {
      return;
    }

    try {
      // 获取 CSRF token
      const csrfToken = document.cookie
        .split('; ')
        .find(row => row.startsWith('csrf_token='))
        ?.split('=')[1];
      
      const response = await fetch(`/api/admin/tasks/${taskId}/delete`, {
        method: 'DELETE',
        headers: {
          ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
        },
        credentials: 'include'  // 使用Cookie认证
      });

      if (response.ok) {
        window.alert('任务删除成功');
        loadData(); // 重新加载数据
      } else {
        window.alert('任务删除失败');
      }
    } catch (error) {
      console.error('删除任务失败:', error);
      window.alert('删除任务失败');
    }
  };


  const filteredUsers = users.filter(user => {
    const matchesSearch = user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         user.email.toLowerCase().includes(searchTerm.toLowerCase());
    
    if (filterType === 'all') return matchesSearch;
    if (filterType === 'banned') return matchesSearch && user.is_banned === 1;
    if (filterType === 'suspended') return matchesSearch && user.is_suspended === 1;
    if (filterType === 'vip') return matchesSearch && user.user_level === 'vip';
    if (filterType === 'super') return matchesSearch && user.user_level === 'super';
    
    return matchesSearch;
  });

  useEffect(() => {
    if (currentUser?.id) {
      loadSessions();
      const interval = setInterval(loadSessions, 10000); // 每10秒刷新一次
      return () => clearInterval(interval);
    }
  }, [currentUser?.id]); // 只在用户ID改变时重新加载会话

  // 建立客服通知WebSocket连接
  useEffect(() => {
    if (!currentUser) return;
    
    // 客服使用Cookie认证，无需token
    const notificationSocket = new WebSocket(`${process.env.REACT_APP_WS_URL || 'ws://localhost:8000'}/ws/chat/${currentUser.id}`);
    
    notificationSocket.onopen = () => {
      // 通知WebSocket连接已建立
    };
    
    notificationSocket.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        
        // 处理心跳消息
        if (msg.type === 'heartbeat') {
          return;
        }
        
        // 检查是否是用户连接通知
        if (msg.type === 'user_connected' && msg.user_info) {
          setNewUserInfo({
            name: msg.user_info.name,
            id: msg.user_info.id
          });
          setShowNewUserNotification(true);
          
          // 3秒后自动关闭弹窗
          setTimeout(() => {
            setShowNewUserNotification(false);
            setNewUserInfo(null);
          }, 3000);
        }
        
        // 实时处理聊天消息
        if (msg.from && msg.receiver_id === currentUser.id && msg.from !== currentUser.id) {
          
          // 如果当前选中的会话是发送消息的用户，立即更新聊天记录
          if (selectedSession && selectedSession.user_id === msg.from) {
            const newMessage: Message = {
              id: msg.id || Date.now(),
              sender_id: msg.from,
              receiver_id: currentUser.id,
              content: msg.content,
              created_at: msg.created_at || new Date().toISOString(),
              is_read: 0,
              is_admin_msg: 0,
              sender_type: 'user'
            };
            
            setChatMessages(prev => {
              // 检查消息是否已存在，避免重复
              const exists = prev.some(m => m.id === newMessage.id);
              if (!exists) {
                return [...prev, newMessage];
              }
              return prev;
            });
            
            // 滚动到底部
            setTimeout(() => {
              if (messagesEndRef.current) {
                messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
              }
            }, 100);
          }
          
          // 更新会话列表中的未读消息数量
          setSessions(prev => prev.map(session => {
            if (session.user_id === msg.from) {
              return {
                ...session,
                unread_count: (session.unread_count || 0) + 1
              };
            }
            return session;
          }));
        }
      } catch (error) {
        console.error('客服WebSocket消息解析错误:', error);
      }
    };
    
    notificationSocket.onerror = (error) => {
      // 静默处理WebSocket错误
    };
    
    notificationSocket.onclose = () => {
      // 通知WebSocket连接已关闭
    };
    
    setNotificationWs(notificationSocket);
    
    return () => {
      notificationSocket.close();
    };
  }, [currentUser?.id]); // 只在用户ID改变时重新建立通知WebSocket连接

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
      const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.CS_CANCEL_REQUESTS}`, {
        credentials: 'include'  // 使用Cookie认证
      });
      if (response.ok) {
        const requestsData = await response.json();
        setCancelRequests(requestsData);
      } else {
        setCancelRequests([]);
      }
    } catch (error) {
      setCancelRequests([]);
    }
  };

  const loadAdminRequests = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.CS_ADMIN_REQUESTS}`, {
        credentials: 'include'  // 使用Cookie认证
      });
      if (response.ok) {
        const requestsData = await response.json();
        setAdminRequests(requestsData);
      } else {
        setAdminRequests([]);
      }
    } catch (error) {
      setAdminRequests([]);
    }
  };

  const loadAdminChatMessages = async () => {
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/customer-service/admin-chat`, {
        credentials: 'include'  // 使用Cookie认证
      });
      if (response.ok) {
        const messagesData = await response.json();
        setAdminChatMessages(messagesData);
      } else {
        console.error('加载管理聊天记录失败:', response.statusText);
        setAdminChatMessages([]);
      }
    } catch (error) {
      console.error('加载管理聊天记录失败:', error);
      setAdminChatMessages([]);
    }
  };

  const reviewCancelRequest = async (requestId: number, status: 'approved' | 'rejected') => {
    try {
      
      // 获取 CSRF token
      const csrfToken = document.cookie
        .split('; ')
        .find(row => row.startsWith('csrf_token='))
        ?.split('=')[1];
      
      // 准备请求体，确保数据格式正确
      const requestBody: { status: string; admin_comment?: string | null } = {
        status: status
      };
      
      // 只有当 adminComment 不为空时才添加该字段，或者显式设置为 null
      if (adminComment && adminComment.trim()) {
        requestBody.admin_comment = adminComment.trim();
      } else {
        requestBody.admin_comment = null; // 空字符串时显式设置为 null
      }
      
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/customer-service/cancel-requests/${requestId}/review`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
        },
        credentials: 'include',  // 使用Cookie认证
        body: JSON.stringify(requestBody)
      });

      if (response.ok) {
        setSelectedCancelRequest(null);
        setAdminComment('');
        await loadCancelRequests(); // 重新加载取消请求列表
        alert(`取消请求已${status === 'approved' ? '通过' : '拒绝'}`);
      } else {
        // 尝试解析错误响应
        let errorMessage = '审核失败';
        try {
          const errorData = await response.json();
          console.error('审核失败响应:', errorData);
          
          // 处理不同的错误格式
          if (errorData.detail) {
            if (Array.isArray(errorData.detail)) {
              // Pydantic验证错误
              errorMessage = errorData.detail.map((err: any) => {
                if (typeof err === 'string') return err;
                return `${err.loc?.join('.')}: ${err.msg}`;
              }).join('; ');
            } else if (typeof errorData.detail === 'string') {
              errorMessage = errorData.detail;
            } else {
              errorMessage = JSON.stringify(errorData.detail);
            }
          } else if (errorData.message) {
            errorMessage = errorData.message;
          }
        } catch (parseError) {
          // 如果无法解析JSON，使用状态文本
          errorMessage = `审核失败 (${response.status}): ${response.statusText}`;
        }
        alert(errorMessage);
      }
    } catch (error) {
      console.error('审核取消请求失败:', error);
      let errorMessage = '审核失败: ';
      if (error instanceof Error) {
        errorMessage += error.message;
      } else {
        errorMessage += '未知错误';
      }
      alert(errorMessage);
    }
  };

  const submitAdminRequest = async () => {
    if (!selectedRequestType || !requestTitle || !requestDescription) {
      alert('请填写完整的请求信息');
      return;
    }

    try {
      
      // 获取 CSRF token
      const csrfToken = document.cookie
        .split('; ')
        .find(row => row.startsWith('csrf_token='))
        ?.split('=')[1];
      
      const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.CS_ADMIN_REQUESTS}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
        },
        credentials: 'include',  // 使用Cookie认证
        body: JSON.stringify({
          type: selectedRequestType,
          title: requestTitle,
          description: requestDescription,
          priority: requestPriority
        })
      });

      if (response.ok) {
        setShowRequestForm(false);
        setSelectedRequestType('');
        setRequestTitle('');
        setRequestDescription('');
        setRequestPriority('medium');
        await loadAdminRequests(); // 重新加载管理请求列表
        alert('管理请求已提交成功');
      } else {
        const errorData = await response.json();
        console.error('提交失败:', errorData);
        alert('提交失败: ' + (errorData.detail || '未知错误'));
      }
    } catch (error) {
      console.error('提交管理请求失败:', error);
      alert('提交失败: ' + (error instanceof Error ? error.message : '未知错误'));
    }
  };

  const sendAdminMessage = async () => {
    if (!newAdminMessage.trim()) {
      return;
    }

    try {
      
      // 获取 CSRF token
      const csrfToken = document.cookie
        .split('; ')
        .find(row => row.startsWith('csrf_token='))
        ?.split('=')[1];
      
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/customer-service/admin-chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(csrfToken && { 'X-CSRF-Token': csrfToken }),
        },
        credentials: 'include',  // 使用Cookie认证
        body: JSON.stringify({
          content: newAdminMessage
        })
      });

      if (response.ok) {
        setNewAdminMessage('');
        await loadAdminChatMessages(); // 重新加载聊天记录
      } else {
        const errorData = await response.json();
        console.error('发送失败:', errorData);
        alert('发送失败: ' + (errorData.detail || '未知错误'));
      }
    } catch (error) {
      console.error('发送管理消息失败:', error);
      alert('发送失败: ' + (error instanceof Error ? error.message : '未知错误'));
    }
  };

  const loadChatMessages = async (chatId: string) => {
    try {
      const messagesData = await getCustomerServiceMessages(chatId);
      
      // 确保 messagesData 是数组
      if (Array.isArray(messagesData)) {
        // 直接设置服务器返回的消息，确保只显示当前chat_id的消息
        setChatMessages(messagesData);
      } else {
        console.error('聊天消息数据格式错误:', messagesData);
        setChatMessages([]);
      }
    } catch (error) {
      console.error('加载消息失败:', error);
      setChatMessages([]);
    }
  };

  // 检查对话超时状态
  const checkChatTimeoutStatus = async (chatId: string) => {
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/customer-service/chat-timeout-status/${chatId}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include'  // 使用Cookie认证
      });
      
      if (response.ok) {
        const status = await response.json();
        setChatTimeoutStatus(status);
        return status;
      } else {
        console.error('获取超时状态失败:', response.status);
        // 如果获取超时状态失败，清除当前状态
        setChatTimeoutStatus(null);
        return null;
      }
    } catch (error) {
      console.error('检查超时状态失败:', error);
      // 如果检查失败，清除当前状态
      setChatTimeoutStatus(null);
      return null;
    }
  };

  // 超时结束对话
  const timeoutEndChat = async (chatId: string) => {
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/customer-service/timeout-end-chat/${chatId}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include'  // 使用Cookie认证
      });
      
      
      if (response.ok) {
        // 先更新本地状态，避免状态不一致
        setSessions(prevSessions => 
          prevSessions.map(session => 
            session.chat_id === chatId 
              ? { ...session, is_ended: 1, ended_at: new Date().toISOString() }
              : session
          )
        );
        
        // 清除当前选中的会话
        setSelectedSession(null);
        setChatMessages([]);
        setChatTimeoutStatus(null);
        
        // 清除超时检查定时器
        if (timeoutCheckInterval) {
          clearInterval(timeoutCheckInterval);
          setTimeoutCheckInterval(null);
        }
        
        // 尝试解析响应，如果失败也不影响成功流程
        try {
          const result = await response.json();
        } catch (parseError) {
        }
        
        // 显示成功消息
        alert('对话已超时结束，用户已收到通知');
        
        // 异步重新加载会话列表以确保数据同步
        setTimeout(() => {
          loadSessions();
        }, 100);
        
        return { success: true };
      } else {
        // 尝试解析错误响应
        let errorMessage = '未知错误';
        try {
          const errorData = await response.json();
          console.error('超时结束失败:', errorData);
          errorMessage = errorData.detail || '未知错误';
        } catch (parseError) {
          console.error('无法解析错误响应:', response.statusText);
          errorMessage = response.statusText || '未知错误';
        }
        alert('超时结束失败: ' + errorMessage);
        return null;
      }
    } catch (error) {
      console.error('超时结束对话失败:', error);
      alert('超时结束失败: ' + (error instanceof Error ? error.message : '未知错误'));
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
          checkChatTimeoutStatus(selectedSession.chat_id);
        }, 1000); // 延迟1秒检查，确保后端已处理消息
      }
      
    } catch (error) {
      console.error('发送消息失败:', error);
      window.alert('发送消息失败');
    }
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
        console.error('标记消息为已读失败:', error);
      }
    }
    
    // 如果会话未结束，启动超时检查
    if (session.is_ended === 0) {
      // 立即检查一次超时状态
      await checkChatTimeoutStatus(session.chat_id);
      
      // 设置定时器，每10秒检查一次超时状态，确保及时更新
      const interval = setInterval(async () => {
        await checkChatTimeoutStatus(session.chat_id);
      }, 10000); // 10秒检查一次，提高响应速度
      
      setTimeoutCheckInterval(interval);
    }
  };

  // 保持 ref 与 state 同步
  useEffect(() => {
    selectedSessionRef.current = selectedSession;
  }, [selectedSession]);

  // WebSocket 连接 - 只在currentUser改变时重新连接
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
        // 使用Cookie认证，无需在URL中传递token
        const wsUrl = `${process.env.REACT_APP_WS_URL || 'ws://localhost:8000'}/ws/chat/${currentUser.id}`;
        socket = new WebSocket(wsUrl);
        setWsConnectionStatus('connecting');
        
        socket.onopen = (event) => {
          setWsConnectionStatus('connected');
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
            
            // 使用 ref 获取最新的 selectedSession
            const latestSelectedSession = selectedSessionRef.current;
            
            // 处理客服对话消息
            if (msg.chat_id && latestSelectedSession && msg.chat_id === latestSelectedSession.chat_id) {
              // 只处理接收到的消息，不处理自己发送的消息（避免重复显示）
              if (msg.from !== currentUser.id && msg.content && msg.content.trim()) {
                setChatMessages(prev => [...prev, {
                  id: Date.now(), // 临时ID
                  sender_id: msg.from,
                  receiver_id: msg.receiver_id,
                  content: msg.content.trim(),
                  created_at: msg.created_at || new Date().toISOString(), // 确保有有效的时间
                  is_read: 0,
                  is_admin_msg: 0,
                  sender_type: msg.sender_type || 'user'
                }]);
                
                // 滚动到底部
                setTimeout(() => {
                  if (messagesEndRef.current) {
                    messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
                  }
                }, 100);
              }
            }
            // 兼容旧的普通消息格式
            else if (latestSelectedSession && (
              (msg.from === latestSelectedSession.user_id && msg.receiver_id === currentUser.id) ||
              (msg.from === currentUser.id && msg.receiver_id === latestSelectedSession.user_id)
            )) {
              // 只处理接收到的消息，不处理自己发送的消息（避免重复显示）
              if (msg.from !== currentUser.id && msg.content && msg.content.trim()) {
                setChatMessages(prev => [...prev, {
                  id: Date.now(), // 临时ID
                  sender_id: msg.from,
                  receiver_id: msg.receiver_id,
                  content: msg.content.trim(),
                  created_at: msg.created_at || new Date().toISOString(), // 确保有有效的时间
                  is_read: 0,
                  is_admin_msg: 0,
                  sender_type: msg.sender_type || 'user'
                }]);
                
                // 滚动到底部
                setTimeout(() => {
                  if (messagesEndRef.current) {
                    messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
                  }
                }, 100);
              }
            }
          } catch (error) {
            console.error('客服WebSocket消息解析错误:', error);
          }
        };
        
        socket.onerror = (error) => {
          setWsConnectionStatus('error');
        };
        
        socket.onclose = (event) => {
          setWsConnectionStatus('disconnected');
          
          // 只在异常关闭时重连（代码1000是正常关闭）
          if (event.code !== 1000 && reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++;
            setTimeout(() => {
              connectWebSocket();
            }, reconnectDelay);
          } else if (event.code !== 1000) {
            console.error('客服WebSocket重连失败，已达到最大重连次数');
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
  }, [currentUser?.id]); // 只在用户ID改变时重新连接WebSocket

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

  // 组件卸载时清理所有WebSocket连接和定时器
  useEffect(() => {
    return () => {
      if (ws) {
        ws.close();
      }
      if (notificationWs) {
        notificationWs.close();
      }
      if (timeoutCheckInterval) {
        clearInterval(timeoutCheckInterval);
      }
    };
  }, []);

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
      console.error('加载客服状态失败:', error);
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
      window.alert(newStatus ? '已设置为在线状态' : '已设置为离线状态');
      
      // 5秒后清除手动切换标记，允许自动刷新
      setTimeout(() => {
        setJustToggledStatus(false);
      }, 5000);
    } catch (error) {
      console.error('切换状态失败:', error);
      window.alert('状态切换失败');
    }
  };

  // 客服改名功能
  const handleUpdateServiceName = async () => {
    if (!newServiceName.trim()) {
      window.alert('请输入新的客服名字');
      return;
    }
    
    try {
      await updateCustomerServiceName(newServiceName);
      setCurrentServiceName(newServiceName);
      setShowNameEditModal(false);
      setNewServiceName('');
      window.alert('客服名字更新成功！');
    } catch (error) {
      console.error('更新客服名字失败:', error);
      window.alert('更新客服名字失败，请重试');
    }
  };

  const openNameEditModal = () => {
    setNewServiceName(currentServiceName);
    setShowNameEditModal(true);
  };

  // 获取当前客服名字
  const loadCurrentServiceName = async () => {
    try {
      const data = await getCustomerServiceStatus();
      if (data.service && data.service.name) {
        setCurrentServiceName(data.service.name);
      }
    } catch (error) {
      console.error('获取客服名字失败:', error);
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
              <img 
                src="/static/service.png"
                alt="客服头像" 
                className="avatar-image"
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
            
            <div className="name-update-section">
              <div className="input-group">
                <input
                  type="text"
                  value={newServiceName}
                  onChange={(e) => setNewServiceName(e.target.value)}
                  placeholder="输入新客服姓名"
                  className="name-input"
                />
                <button
                  onClick={handleUpdateServiceName}
                  className="update-name-btn"
                >
                  <span className="btn-icon">✏️</span>
                  <span className="btn-text">更新</span>
                </button>
              </div>
            </div>
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
            placeholder="搜索任务ID、发布者ID或接受者ID..."
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
            {sessions.filter(session => session.is_ended === 1).length > 50 && (
              <button
                onClick={async () => {
                  if (window.confirm('确定要清理超过50个的旧已结束对话吗？此操作不可撤销。')) {
                    try {
                      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/customer-service/cleanup-old-chats/${currentUser.id}`, {
                        method: 'POST',
                        headers: {
                          'Content-Type': 'application/json'
                        },
                        credentials: 'include'  // 使用Cookie认证
                      });
                      
                      if (response.ok) {
                        const result = await response.json();
                        alert(result.message);
                        loadSessions(); // 重新加载会话列表
                      } else {
                        alert('清理失败');
                      }
                    } catch (error) {
                      console.error('清理旧对话失败:', error);
                      alert('清理失败');
                    }
                  }
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
              {sessions.filter(session => session.is_ended === 0).length > 0 && (
                <>
                  <div style={{
                    padding: '10px 20px',
                    background: '#f0f9ff',
                    borderBottom: '1px solid #e6f7ff',
                    fontSize: 12,
                    color: '#1890ff',
                    fontWeight: 'bold'
                  }}>
                    进行中的对话 ({sessions.filter(session => session.is_ended === 0).length})
                  </div>
                  {sessions.filter(session => session.is_ended === 0).map(session => (
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
                      <img 
                        src={session.user_avatar} 
                        alt="用户头像" 
                        style={{ 
                          width: 40, 
                          height: 40, 
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
              {sessions.filter(session => session.is_ended === 1).length > 0 && (
                <>
                  <div style={{
                    padding: '10px 20px',
                    background: '#f5f5f5',
                    borderBottom: '1px solid #e8e8e8',
                    fontSize: 12,
                    color: '#999',
                    fontWeight: 'bold'
                  }}>
                    已结束的对话 ({sessions.filter(session => session.is_ended === 1).length})
                  </div>
                  {sessions.filter(session => session.is_ended === 1).map(session => (
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
                      <img 
                        src={session.user_avatar} 
                        alt="用户头像" 
                        style={{ 
                          width: 40, 
                          height: 40, 
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
                <img 
                  src="/static/service.png"
                  alt="客服头像" 
                  style={{ 
                    width: 40, 
                    height: 40, 
                    borderRadius: '50%',
                    objectFit: 'cover'
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
                      if (window.confirm('确定要超时结束此对话吗？用户将收到超时通知。')) {
                        timeoutEndChat(selectedSession.chat_id);
                      }
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
                {chatMessages.map((msg, idx) => (
                  <div key={idx} style={{ 
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
                ))}
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
                      <div>审核人: {request.admin_id}</div>
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
              onKeyPress={(e) => e.key === 'Enter' && sendAdminMessage()}
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
                onClick={submitAdminRequest}
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
          客服管理系统
        </h1>
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
          
          {/* 客服改名按钮 */}
          <button
            onClick={openNameEditModal}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: '1px solid #1890ff',
              fontSize: 12,
              fontWeight: 600,
              cursor: 'pointer',
              background: '#fff',
              color: '#1890ff',
              transition: 'all 0.3s'
            }}
          >
            修改客服名字
          </button>
          
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
          {cancelRequests.filter(req => req.status === 'pending').length > 0 && (
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
              {cancelRequests.filter(req => req.status === 'pending').length}
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
          {adminRequests.filter(req => req.status === 'pending').length > 0 && (
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
              {adminRequests.filter(req => req.status === 'pending').length}
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
                onClick={() => reviewCancelRequest(selectedCancelRequest.id, 'approved')} 
                className="btn-success"
              >
                通过
              </button>
              <button 
                onClick={() => reviewCancelRequest(selectedCancelRequest.id, 'rejected')} 
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

      {/* 客服改名弹窗 */}
      {showNameEditModal && (
        <div className="modal-overlay">
          <div className="modal">
            <h3>修改客服名字</h3>
            <div style={{ marginBottom: 16 }}>
              <label style={{ display: 'block', marginBottom: 8, fontWeight: 600 }}>
                当前名字: {currentServiceName || '未设置'}
              </label>
              <input
                type="text"
                value={newServiceName}
                onChange={(e) => setNewServiceName(e.target.value)}
                placeholder="请输入新的客服名字"
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 6,
                  border: '1px solid #d9d9d9',
                  fontSize: 14,
                  outline: 'none',
                  transition: 'border-color 0.2s'
                }}
              />
            </div>
            <div className="modal-actions">
              <button onClick={handleUpdateServiceName} className="btn-primary">
                确认修改
              </button>
              <button onClick={() => setShowNameEditModal(false)} className="btn-secondary">
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
    </div>
  );
};

export default CustomerService; 