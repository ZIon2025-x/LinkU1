import axios from 'axios';
import { API_BASE_URL, API_ENDPOINTS } from './config';

const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true  // 确保发送Cookie
});

// CSRF token管理
let csrfToken: string | null = null;

// Token刷新管理
let isRefreshing = false;
let refreshPromise: Promise<any> | null = null;

// 请求缓存和去重
const requestCache = new Map<string, { data: any; timestamp: number; ttl: number }>();
const pendingRequests = new Map<string, Promise<any>>();

// 缓存配置
const CACHE_TTL = {
  USER_INFO: 5 * 60 * 1000,    // 用户信息缓存5分钟
  TASKS: 2 * 60 * 1000,        // 任务列表缓存2分钟
  NOTIFICATIONS: 30 * 1000,    // 通知缓存30秒
  DEFAULT: 60 * 1000           // 默认缓存1分钟
};

// 缓存和去重工具函数
function getCacheKey(url: string, params?: any): string {
  const paramStr = params ? JSON.stringify(params) : '';
  return `${url}${paramStr}`;
}

function isCacheValid(timestamp: number, ttl: number): boolean {
  return Date.now() - timestamp < ttl;
}

async function cachedRequest<T>(
  url: string, 
  requestFn: () => Promise<T>, 
  ttl: number = CACHE_TTL.DEFAULT,
  params?: any
): Promise<T> {
  const cacheKey = getCacheKey(url, params);
  
  // 检查缓存
  const cached = requestCache.get(cacheKey);
  if (cached && isCacheValid(cached.timestamp, cached.ttl)) {
    console.log('使用缓存数据:', cacheKey);
    return cached.data;
  }
  
  // 检查是否有正在进行的相同请求
  if (pendingRequests.has(cacheKey)) {
    console.log('等待进行中的请求:', cacheKey);
    return pendingRequests.get(cacheKey)!;
  }
  
  // 发起新请求
  const requestPromise = requestFn().then(data => {
    // 缓存结果
    requestCache.set(cacheKey, {
      data,
      timestamp: Date.now(),
      ttl
    });
    // 移除进行中的请求
    pendingRequests.delete(cacheKey);
    return data;
  }).catch(error => {
    // 移除进行中的请求
    pendingRequests.delete(cacheKey);
    throw error;
  });
  
  // 记录进行中的请求
  pendingRequests.set(cacheKey, requestPromise);
  return requestPromise;
}

// 获取CSRF token的函数
export async function getCSRFToken(): Promise<string> {
  if (csrfToken) {
    return csrfToken;
  }
  
  try {
    const response = await api.get('/api/csrf/token');
    csrfToken = response.data.csrf_token;
    if (!csrfToken) {
      throw new Error('CSRF token为空');
    }
    return csrfToken;
  } catch (error) {
    console.error('获取CSRF token失败:', error);
    throw error;
  }
}

// 清除CSRF token的函数
export function clearCSRFToken(): void {
  csrfToken = null;
}

api.interceptors.request.use(async config => {
  // 对于写操作，添加CSRF token
  // 但跳过登录相关的请求，因为它们不需要CSRF保护
  if (config.method && ['post', 'put', 'patch', 'delete'].includes(config.method.toLowerCase())) {
    const url = config.url || '';
    const isLoginRequest = url.includes('/login') || url.includes('/register') || url.includes('/auth/login');
    
    if (!isLoginRequest) {
      try {
        const token = await getCSRFToken();
        config.headers['X-CSRF-Token'] = token;
      } catch (error) {
        console.warn('无法获取CSRF token，请求可能失败:', error);
      }
    }
  }
  
  console.log('发送请求到:', config.url);
  console.log('请求配置:', {
    method: config.method,
    url: config.url,
    headers: config.headers,
    withCredentials: config.withCredentials
  });
  return config;
});

// 响应拦截器 - 处理认证失败、token刷新和CSRF错误
api.interceptors.response.use(
  response => {
    console.log('收到响应:', {
      status: response.status,
      url: response.config.url,
      data: response.data
    });
    return response;
  },
  async error => {
    console.log('请求错误:', {
      status: error.response?.status,
      url: error.config?.url,
      message: error.message,
      data: error.response?.data
    });
    
    if (error.response?.status === 401) {
      // 避免重复刷新token
      if (isRefreshing) {
        // 如果正在刷新，等待刷新完成
        if (refreshPromise) {
          try {
            await refreshPromise;
            // 刷新完成后重试原始请求
            return api.request(error.config);
          } catch (refreshError) {
            console.log('等待token刷新失败');
            return Promise.reject(error);
          }
        }
      } else {
        // 开始刷新token
        isRefreshing = true;
        
        // 根据用户类型选择正确的refresh端点
        const userInfo = localStorage.getItem('userInfo');
        let refreshEndpoint = '/api/auth/refresh'; // 默认用户refresh端点
        
        if (userInfo) {
          try {
            const user = JSON.parse(userInfo);
            if (user.user_type === 'customer_service') {
              refreshEndpoint = '/api/cs/refresh';
            } else if (user.user_type === 'admin') {
              refreshEndpoint = '/api/admin/refresh';
            }
          } catch (e) {
            console.log('解析用户信息失败，使用默认refresh端点');
          }
        }
        
        refreshPromise = api.post(refreshEndpoint);
        
        try {
          const refreshResponse = await refreshPromise;
          console.log('Token刷新成功，重试原始请求');
          
          // 重试原始请求
          return api.request(error.config);
        } catch (refreshError) {
          console.log('Token刷新失败，用户需要重新登录');
          // HttpOnly Cookie会自动处理，无需手动清理
          // 让各个组件自己处理认证失败的情况
        } finally {
          // 重置刷新状态
          isRefreshing = false;
          refreshPromise = null;
        }
      }
    }
    
    // 处理CSRF token验证失败
    if (error.response?.status === 403 && 
        error.response?.data?.detail?.includes('CSRF token验证失败')) {
      console.log('CSRF token验证失败，尝试重新获取token并重试请求');
      
      try {
        // 清除旧的CSRF token
        clearCSRFToken();
        
        // 重新获取CSRF token
        const newToken = await getCSRFToken();
        
        // 重试原始请求
        const retryConfig = {
          ...error.config,
          headers: {
            ...error.config.headers,
            'X-CSRF-Token': newToken
          }
        };
        
        return api.request(retryConfig);
      } catch (retryError) {
        console.error('重试请求失败:', retryError);
        return Promise.reject(retryError);
      }
    }
    
    return Promise.reject(error);
  }
);

export async function fetchTasks({ type, city, keyword, page = 1, pageSize = 10 }: {
  type?: string;
  city?: string;
  keyword?: string;
  page?: number;
  pageSize?: number;
}) {
  const params: Record<string, any> = {};
  if (type && type !== '全部类型') params.task_type = type;
  if (city && city !== '全部城市') params.location = city;
  if (keyword) params.keyword = keyword;
  params.page = page;
  params.page_size = pageSize;
  
  console.log('fetchTasks 请求参数:', params);
  console.log('fetchTasks 请求URL:', '/api/tasks');
  
  try {
    const res = await api.get('/api/tasks', { params });
    console.log('fetchTasks 响应数据:', res.data);
    return res.data;
  } catch (error) {
    console.error('fetchTasks 请求失败:', error);
    throw error;
  }
}

export async function fetchCurrentUser() {
  const res = await api.get('/api/users/profile/me');
  return res.data;
}

export async function sendMessage(data: {
  receiver_id: string;
  content: string;
  session_id?: number;
}) {
  const res = await api.post('/api/users/messages/send', data);
  return res.data;
}

export async function updateAvatar(avatar: string) {
  const res = await api.patch('/api/users/profile/avatar', { avatar });
  return res.data;
}

export async function updateTimezone(timezone: string) {
  const res = await api.patch('/api/users/profile/timezone', timezone);
  return res.data;
}

export async function getContacts() {
  // 添加时间戳参数避免缓存
  const timestamp = Date.now();
  const res = await api.get(`/api/users/contacts?t=${timestamp}`);
  return res.data;
}

// 获取与指定用户的共同任务
export async function getSharedTasks(otherUserId: string) {
  const res = await api.get(`/api/users/shared-tasks/${otherUserId}`);
  return res.data;
}

// 获取与指定用户的聊天历史
export async function getChatHistory(userId: string, limit: number = 10, sessionId?: number, offset: number = 0) {
  const params: any = { limit, offset };
  if (sessionId) {
    params.session_id = sessionId;
  }
  const res = await api.get(`/api/users/messages/history/${userId}`, {
    params
  });
  return res.data;
}

// 获取未读消息列表
export async function getUnreadMessages() {
  const res = await api.get('/api/users/messages/unread');
  return res.data;
}

// 获取未读消息数量
export async function getUnreadCount() {
  const res = await api.get('/api/users/messages/unread/count');
  return res.data.unread_count;
}

// 标记消息为已读
export async function markMessageRead(messageId: number) {
  const res = await api.post(`/api/users/messages/${messageId}/read`);
  return res.data;
}

// 获取用户通知列表
export async function getNotifications(limit: number = 20) {
  const res = await api.get('/api/users/notifications', {
    params: { limit }
  });
  return res.data;
}

// 获取未读通知列表
export async function getUnreadNotifications() {
  const res = await api.get('/api/users/notifications/unread');
  return res.data;
}

// 获取未读通知数量
export async function getUnreadNotificationCount() {
  const res = await api.get('/api/users/notifications/unread/count');
  return res.data.unread_count;
}

// 标记通知为已读
export async function markNotificationRead(notificationId: number) {
  const res = await api.post(`/api/users/notifications/${notificationId}/read`);
  return res.data;
}

// 标记所有通知为已读
export async function markAllNotificationsRead() {
  const res = await api.post('/api/users/notifications/read-all');
  return res.data;
}

// 接受任务
export async function acceptTask(taskId: number) {
  const res = await api.post(`/api/tasks/${taskId}/accept`);
  return res.data;
}

// 更新任务价格
export async function updateTaskReward(taskId: number, newReward: number) {
  const res = await api.patch(`/api/tasks/${taskId}/reward`, {
    reward: newReward
  });
  return res.data;
}

export async function updateTaskVisibility(taskId: number, isPublic: number) {
  const res = await api.patch(`/api/tasks/${taskId}/visibility`, {
    is_public: isPublic
  });
  return res.data;
}

// 获取我的任务
export async function getMyTasks() {
  const res = await api.get('/api/users/my-tasks');
  return res.data;
}

// 完成任务
export async function completeTask(taskId: number) {
  const res = await api.post(`/api/tasks/${taskId}/complete`);
  return res.data;
}

// 取消任务
export async function cancelTask(taskId: number, reason?: string) {
  const res = await api.post(`/api/tasks/${taskId}/cancel`, {
    reason: reason
  });
  return res.data;
}

export async function deleteTask(taskId: number) {
  const res = await api.delete(`/api/tasks/${taskId}/delete`);
  return res.data;
}

// 确认任务完成
export async function confirmTaskCompletion(taskId: number) {
  const res = await api.post(`/api/tasks/${taskId}/confirm_completion`);
  return res.data;
}

// 任务发布者同意接受者
export async function approveTaskTaker(taskId: number) {
  const res = await api.post(`/api/tasks/${taskId}/approve`);
  return res.data;
}

// 任务发布者拒绝接受者
export async function rejectTaskTaker(taskId: number) {
  const res = await api.post(`/api/tasks/${taskId}/reject`);
  return res.data;
}

// 获取用户主页信息
export async function getUserProfile(userId: string | number) {
  const res = await api.get(`/api/users/profile/${userId}`);
  return res.data;
}

// 创建评价
export async function createReview(taskId: number, rating: number, comment?: string, isAnonymous: boolean = false) {
  const res = await api.post(`/api/tasks/${taskId}/review`, {
    rating,
    comment,
    is_anonymous: isAnonymous
  });
  return res.data;
}

// 获取任务评价列表
export async function getTaskReviews(taskId: number) {
  const res = await api.get(`/api/tasks/${taskId}/reviews`);
  return res.data;
}

// 客服管理相关API
export async function getAdminUsers() {
  const res = await api.get('/api/users/admin/users');
  return res.data;
}

export async function getAdminTasks(params?: {
  skip?: number;
  limit?: number;
  status?: string;
  task_type?: string;
  location?: string;
  keyword?: string;
}) {
  const res = await api.get('/api/users/admin/tasks', { params });
  return res.data;
}

export async function getAdminTaskDetail(taskId: number) {
  const res = await api.get(`/api/users/admin/tasks/${taskId}`);
  return res.data;
}

export async function updateAdminTask(taskId: number, taskUpdate: any) {
  const res = await api.put(`/api/users/admin/tasks/${taskId}`, taskUpdate);
  return res.data;
}

export async function deleteAdminTask(taskId: number) {
  const res = await api.delete(`/api/users/admin/tasks/${taskId}`);
  return res.data;
}

export async function batchUpdateAdminTasks(taskIds: number[], taskUpdate: any) {
  const res = await api.post('/api/users/admin/tasks/batch-update', {
    task_ids: taskIds,
    ...taskUpdate
  });
  return res.data;
}

export async function batchDeleteAdminTasks(taskIds: number[]) {
  const res = await api.post('/api/users/admin/tasks/batch-delete', {
    task_ids: taskIds
  });
  return res.data;
}

// 客服管理相关API
export async function getAdminCustomerServiceRequests(params?: {
  status?: string;
  priority?: string;
}) {
  const res = await api.get('/api/users/admin/customer-service-requests', { params });
  return res.data;
}

export async function getAdminCustomerServiceRequestDetail(requestId: number) {
  const res = await api.get(`/api/users/admin/customer-service-requests/${requestId}`);
  return res.data;
}

export async function updateAdminCustomerServiceRequest(requestId: number, updateData: any) {
  const res = await api.put(`/api/users/admin/customer-service-requests/${requestId}`, updateData);
  return res.data;
}

export async function getAdminCustomerServiceChatMessages() {
  const res = await api.get('/api/users/admin/customer-service-chat');
  return res.data;
}

export async function sendAdminCustomerServiceChatMessage(content: string) {
  const res = await api.post('/api/users/admin/customer-service-chat', { content });
  return res.data;
}

export async function getAdminMessages() {
  const res = await api.get('/api/users/admin/messages');
  return res.data;
}

export async function setUserLevel(userId: string, level: string) {
  const res = await api.post(`/api/users/admin/user/${userId}/set_level`, level);
  return res.data;
}

export async function setUserStatus(userId: string, status: {
  is_banned?: number;
  is_suspended?: number;
  suspend_until?: string;
}) {
  const res = await api.post(`/api/users/admin/user/${userId}/set_status`, status);
  return res.data;
}

export async function setTaskLevel(taskId: number, level: string) {
  const res = await api.post(`/api/users/admin/task/${taskId}/set_level`, level);
  return res.data;
}

export async function sendAnnouncement(title: string, content: string) {
  const res = await api.post('/api/users/notifications/send-announcement', {
    title,
    content
  });
  return res.data;
}

export async function getAdminPayments() {
  const res = await api.get('/api/users/admin/payments');
  return res.data;
}

// 客服相关API
export const assignCustomerService = async () => {
  const response = await api.post('/api/users/assign_customer_service');
  return response.data;
};

export const getCustomerServiceSessions = async () => {
  const response = await api.get('/api/users/customer-service/chats');
  return response.data;
};

export const getCustomerServiceMessages = async (chatId: string) => {
  const response = await api.get(`/api/users/customer-service/messages/${chatId}`);
  return response.data;
};

export const markCustomerServiceMessagesRead = async (chatId: string) => {
  const response = await api.post(`/api/users/customer-service/mark-messages-read/${chatId}`);
  return response.data;
};

export const sendCustomerServiceMessage = async (chatId: string, content: string) => {
  const response = await api.post(`/api/users/customer-service/send-message/${chatId}`, { content });
  return response.data;
};

export const setCustomerServiceOnline = async () => {
  const response = await api.post('/api/users/customer-service/online');
  return response.data;
};

export const setCustomerServiceOffline = async () => {
  const response = await api.post('/api/users/customer-service/offline');
  return response.data;
};

export const getCustomerServiceStatus = async () => {
  const response = await api.get('/api/users/customer-service/status');
  return response.data;
};

// 结束对话和评分相关API
export const endCustomerServiceSession = async (sessionId: number) => {
  const response = await api.post(`/api/users/customer-service/end-session/${sessionId}`);
  return response.data;
};

export const rateCustomerService = async (sessionId: number, rating: number, comment?: string) => {
  const response = await api.post(`/api/users/customer-service/rate/${sessionId}`, { rating, comment });
  return response.data;
};

export const getMyCustomerServiceSessions = async () => {
  const res = await api.get('/api/users/customer-service/my-sessions');
  return res.data;
};

// 客服改名接口
export const updateCustomerServiceName = async (name: string) => {
  const res = await api.patch('/api/users/customer-service/update-name', name);
  return res.data;
};

export const customerServiceLogout = async () => {
  const res = await api.post('/api/users/customer-service/logout');
  return res.data;
};

// 管理后台相关API
export const getDashboardStats = async () => {
  const res = await api.get('/api/users/admin/dashboard/stats');
  return res.data;
};

export const getUsersForAdmin = async (page: number = 1, size: number = 20, search?: string) => {
  const params = new URLSearchParams();
  params.append('page', page.toString());
  params.append('size', size.toString());
  if (search) {
    params.append('search', search);
  }
  const res = await api.get(`/api/users/admin/users?${params.toString()}`);
  return res.data;
};

export const updateUserByAdmin = async (userId: string, userData: any) => {
  const res = await api.patch(`/api/users/admin/users/${userId}`, userData);
  return res.data;
};

export const createCustomerService = async (csData: {
  name: string;
  email: string;
  password: string;
}) => {
  const res = await api.post('/api/users/admin/customer-service', csData);
  return res.data;
};

export const deleteCustomerService = async (csId: number) => {
  const res = await api.delete(`/api/users/admin/customer-service/${csId}`);
  return res.data;
};

export const getCustomerServicesForAdmin = async (page: number = 1, size: number = 20) => {
  const params = new URLSearchParams();
  params.append('page', page.toString());
  params.append('size', size.toString());
  const res = await api.get(`/api/users/admin/customer-service?${params.toString()}`);
  return res.data;
};

// 管理员管理相关API
export const createAdminUser = async (adminData: {
  name: string;
  username: string;
  email: string;
  password: string;
  is_super_admin?: number;
}) => {
  const res = await api.post('/api/users/admin/admin-user', adminData);
  return res.data;
};

export const deleteAdminUser = async (adminId: string) => {
  const res = await api.delete(`/api/users/admin/admin-user/${adminId}`);
  return res.data;
};

export const getAdminUsersForAdmin = async (page: number = 1, size: number = 20) => {
  const params = new URLSearchParams();
  params.append('page', page.toString());
  params.append('size', size.toString());
  const res = await api.get(`/api/users/admin/admin-users?${params.toString()}`);
  return res.data;
};

// 员工提醒相关API
export const sendStaffNotification = async (notification: {
  recipient_id: string;
  recipient_type: string;
  title: string;
  content: string;
  notification_type?: string;
}) => {
  const res = await api.post('/api/users/admin/staff-notification', notification);
  return res.data;
};

export const getStaffNotifications = async () => {
  const res = await api.get('/api/users/staff/notifications');
  return res.data;
};

export const getUnreadStaffNotifications = async () => {
  const res = await api.get('/api/users/staff/notifications/unread');
  return res.data;
};

export const markStaffNotificationRead = async (notificationId: number) => {
  const res = await api.post(`/api/users/staff/notifications/${notificationId}/read`);
  return res.data;
};

export const markAllStaffNotificationsRead = async () => {
  const res = await api.post('/api/users/staff/notifications/read-all');
  return res.data;
};

export const sendAdminNotification = async (notification: {
  title: string;
  content: string;
  user_ids: string[];  // 现在ID是字符串类型
  type?: string;
}) => {
  const res = await api.post('/api/users/admin/notifications/send', notification);
  return res.data;
};

export const updateTaskByAdmin = async (taskId: number, taskData: any) => {
  const res = await api.patch(`/api/users/admin/tasks/${taskId}`, taskData);
  return res.data;
};

export const deleteTaskByAdmin = async (taskId: number) => {
  const res = await api.delete(`/api/users/admin/tasks/${taskId}`);
  return res.data;
};

export const notifyCustomerService = async (csId: number, message: string) => {
  const res = await api.post(`/api/users/admin/customer-service/${csId}/notify`, message);
  return res.data;
};

// 后台管理员登录
export const adminLogin = async (loginData: { username: string; password: string }) => {
  const res = await api.post('/api/admin/login', loginData);
  return res.data;
};

// 系统设置相关API
export const getSystemSettings = async () => {
  const res = await api.get('/api/users/admin/system-settings');
  return res.data;
};

export const updateSystemSettings = async (settings: {
  vip_enabled: boolean;
  super_vip_enabled: boolean;
  vip_task_threshold: number;
  super_vip_task_threshold: number;
  vip_price_threshold: number;
  super_vip_price_threshold: number;
  vip_button_visible: boolean;
  vip_auto_upgrade_enabled: boolean;
  vip_benefits_description: string;
  super_vip_benefits_description: string;
  // VIP晋升超级VIP的条件
  vip_to_super_task_count_threshold: number;
  vip_to_super_rating_threshold: number;
  vip_to_super_completion_rate_threshold: number;
  vip_to_super_enabled: boolean;
}) => {
  const res = await api.put('/api/users/admin/system-settings', settings);
  return res.data;
};

export const getPublicSystemSettings = async () => {
  const res = await api.get('/api/users/system-settings/public');
  return res.data;
};

// 检查客服可用性
export const checkCustomerServiceAvailability = async () => {
  const res = await api.get('/api/users/customer-service/check-availability');
  return res.data;
};

// 用户登录
export const login = async (email: string, password: string) => {
  const res = await api.post('/api/auth/login', { email, password });
  return res.data;
};

// 用户注册
export const register = async (userData: {
  email: string;
  password: string;
  username: string;
  phone: string;
}) => {
  const res = await api.post('/api/users/register', userData);
  return res.data;
};

// 忘记密码
export const forgotPassword = async (email: string) => {
  const res = await api.post('/api/users/forgot-password', { email });
  return res.data;
};

export default api; 