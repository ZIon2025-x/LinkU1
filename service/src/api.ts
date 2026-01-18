import axios from 'axios';
import { API_BASE_URL, API_ENDPOINTS } from './config';

const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  timeout: 10000,
  headers: {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache'
  }
});

// CSRF token管理
let csrfToken: string | null = null;

// 获取CSRF token的函数
export async function getCSRFToken(): Promise<string> {
  const cookieToken = document.cookie
    .split('; ')
    .find(row => row.startsWith('csrf_token='))
    ?.split('=')[1];
  
  if (cookieToken) {
    csrfToken = cookieToken;
    return cookieToken;
  }
  
  try {
    const response = await api.get(API_ENDPOINTS.CSRF_TOKEN);
    const newToken = response.data.csrf_token;
    if (!newToken) {
      throw new Error('CSRF token为空');
    }
    csrfToken = newToken;
    return newToken;
  } catch (error) {
    throw error;
  }
}

// 清除CSRF token的函数
export function clearCSRFToken(): void {
  csrfToken = null;
}

// 请求拦截器
api.interceptors.request.use(async config => {
  if (config.data instanceof FormData) {
    delete config.headers['Content-Type'];
  }
  
  if (config.method && ['post', 'put', 'patch', 'delete'].includes(config.method.toLowerCase())) {
    const url = config.url || '';
    const isLoginRequest = url.includes('/login') || url.includes('/register') || url.includes('/auth/login');
    
    if (!isLoginRequest) {
      try {
        const token = await getCSRFToken();
        config.headers['X-CSRF-Token'] = token;
      } catch (error) {
        // 静默处理
      }
    }
  }
  
  return config;
});

// Token刷新管理
let isRefreshing = false;
let refreshPromise: Promise<any> | null = null;

// 响应拦截器
api.interceptors.response.use(
  response => response,
  async error => {
    // 处理401错误 - token刷新
    if (error.response?.status === 401) {
      const originalRequest = error.config;
      
      // 跳过刷新token的API，避免无限循环
      const skipRefreshApis = [
        '/api/auth/service/login',
        '/api/auth/service/refresh',
        '/api/csrf/token'
      ];
      
      if (originalRequest && !skipRefreshApis.some(api => originalRequest.url?.includes(api))) {
        // 如果正在刷新，等待刷新完成
        if (isRefreshing && refreshPromise) {
          try {
            await refreshPromise;
            // 刷新成功后，重试原始请求
            return api.request(originalRequest);
          } catch (refreshError) {
            // 刷新失败，跳转到登录页
            if (window.location.pathname !== '/login') {
              window.location.href = '/login';
            }
            return Promise.reject(refreshError);
          }
        }
        
        // 开始刷新token
        isRefreshing = true;
        refreshPromise = api.post('/api/auth/service/refresh');
        
        try {
          await refreshPromise;
          // 清除CSRF token缓存
          clearCSRFToken();
          // 刷新成功后，重试原始请求
          isRefreshing = false;
          refreshPromise = null;
          return api.request(originalRequest);
        } catch (refreshError) {
          // 刷新失败，跳转到登录页
          isRefreshing = false;
          refreshPromise = null;
          if (window.location.pathname !== '/login') {
            window.location.href = '/login';
          }
          return Promise.reject(refreshError);
        }
      }
    }
    
    return Promise.reject(error);
  }
);

// 客服相关 API 函数
export const getCustomerServiceSessions = async () => {
  const response = await api.get(API_ENDPOINTS.CS_CHATS);
  return response.data;
};

export const getCustomerServiceMessages = async (chatId: string) => {
  const response = await api.get(API_ENDPOINTS.CS_MESSAGES(chatId));
  return response.data;
};

export const markCustomerServiceMessagesRead = async (chatId: string) => {
  const response = await api.post(API_ENDPOINTS.CS_MARK_READ(chatId));
  return response.data;
};

export const sendCustomerServiceMessage = async (chatId: string, content: string) => {
  const response = await api.post(API_ENDPOINTS.CS_MESSAGES(chatId), { content });
  return response.data;
};

export const setCustomerServiceOnline = async () => {
  try {
    const response = await api.post(API_ENDPOINTS.CS_ONLINE);
    return response.data;
  } catch (error: any) {
    throw error;
  }
};

export const setCustomerServiceOffline = async () => {
  try {
    const response = await api.post(API_ENDPOINTS.CS_OFFLINE);
    return response.data;
  } catch (error: any) {
    throw error;
  }
};

export const getCustomerServiceStatus = async () => {
  const response = await api.get(API_ENDPOINTS.CS_STATUS);
  return response.data;
};

export const endCustomerServiceSession = async (chatId: string) => {
  const response = await api.post(API_ENDPOINTS.CS_END_CHAT(chatId));
  return response.data;
};

export const customerServiceLogout = async () => {
  const res = await api.post(API_ENDPOINTS.CS_LOGOUT);
  return res.data;
};

// 获取客服通知
export const getStaffNotifications = async () => {
  const res = await api.get(API_ENDPOINTS.CS_NOTIFICATIONS);
  return res.data;
};

export const getUnreadStaffNotifications = async () => {
  const res = await api.get(API_ENDPOINTS.CS_NOTIFICATIONS_UNREAD);
  return res.data;
};

export const markStaffNotificationRead = async (notificationId: number) => {
  const res = await api.post(API_ENDPOINTS.CS_NOTIFICATIONS_READ(notificationId));
  return res.data;
};

export const markAllStaffNotificationsRead = async () => {
  const res = await api.post(API_ENDPOINTS.CS_NOTIFICATIONS_READ_ALL);
  return res.data;
};

// 获取任务列表
export const getCustomerServiceTasks = async () => {
  const response = await api.get(API_ENDPOINTS.CS_TASKS);
  return response.data;
};

// 获取取消请求
export const getCancelRequests = async () => {
  const response = await api.get(API_ENDPOINTS.CS_CANCEL_REQUESTS);
  return response.data;
};

// 获取后台管理请求
export const getAdminRequests = async () => {
  const response = await api.get(API_ENDPOINTS.CS_ADMIN_REQUESTS);
  return response.data;
};

// 发送后台管理消息
export const sendAdminChatMessage = async (content: string) => {
  const response = await api.post(API_ENDPOINTS.CS_ADMIN_CHAT, { content });
  return response.data;
};

// 获取后台管理聊天消息
export const getAdminChatMessages = async () => {
  const response = await api.get(API_ENDPOINTS.CS_ADMIN_CHAT);
  return response.data;
};

// 获取用户列表
export const getCustomerServiceUsers = async () => {
  const response = await api.get(API_ENDPOINTS.CS_USERS);
  return response.data;
};

// 获取用户详情
export const getCustomerServiceUserDetail = async (userId: string) => {
  const response = await api.get(API_ENDPOINTS.CS_USER_DETAIL(userId));
  return response.data;
};

// 审核取消请求
export const reviewCancelRequest = async (requestId: number, status: 'approved' | 'rejected', comment: string) => {
  const response = await api.post(`/api/customer-service/cancel-requests/${requestId}/review`, {
    status,
    comment
  });
  return response.data;
};

// 提交管理请求
export const submitAdminRequest = async (requestData: {
  type: string;
  title: string;
  description: string;
  priority: string;
}) => {
  const response = await api.post(API_ENDPOINTS.CS_ADMIN_REQUESTS, requestData);
  return response.data;
};

// 获取任务详情
export const getTaskDetail = async (taskId: number) => {
  const response = await api.get(`/api/tasks/${taskId}`);
  return response.data;
};

// 检查聊天超时状态
export const checkChatTimeoutStatus = async (chatId: string) => {
  const response = await api.get(`/api/customer-service/chats/${chatId}/timeout-status`);
  return response.data;
};

// 超时结束对话
export const timeoutEndChat = async (chatId: string) => {
  const response = await api.post(`/api/customer-service/chats/${chatId}/timeout-end`);
  return response.data;
};

// 清理旧聊天记录
export const cleanupOldChats = async (serviceId: string) => {
  const response = await api.post(`/api/customer-service/cleanup-old-chats/${serviceId}`);
  return response.data;
};

// 获取客服个人信息
export const getServiceProfile = async () => {
  const response = await api.get(API_ENDPOINTS.CS_PROFILE);
  return response.data;
};

// 发送公告
export const sendAnnouncement = async (title: string, content: string) => {
  const response = await api.post('/api/users/notifications/send-announcement', {
    title,
    content
  });
  return response.data;
};

// 更新用户状态（ban/unban/suspend/unsuspend）
export const updateUserStatus = async (userId: string, status: {
  is_banned?: number;
  is_suspended?: number;
}) => {
  const response = await api.post(`/api/admin/user/${userId}/set_status`, status);
  return response.data;
};

// 设置用户等级
export const setUserLevel = async (userId: string, levelData: any) => {
  const response = await api.post(`/api/admin/user/${userId}/set_level`, levelData);
  return response.data;
};

// 删除任务
export const deleteTask = async (taskId: number) => {
  const response = await api.delete(`/api/admin/tasks/${taskId}/delete`);
  return response.data;
};

export default api;
