import axios from 'axios';
import { API_BASE_URL, API_ENDPOINTS } from './config';

const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,  // 确保发送Cookie
  timeout: 10000,  // 10秒超时
  headers: {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache'
  },
  // 添加更多HTTP/1.1相关配置
  maxRedirects: 5,
  validateStatus: function (status) {
    return status >= 200 && status < 300; // 默认
  }
});

// CSRF token管理
let csrfToken: string | null = null;

// Token刷新管理
let isRefreshing = false;
let refreshPromise: Promise<any> | null = null;

// 请求缓存和去重
const requestCache = new Map<string, { data: any; timestamp: number; ttl: number }>();
const pendingRequests = new Map<string, Promise<any>>();

// 重试计数器，防止无限重试
const retryCounters = new Map<string, number>();
const MAX_RETRY_ATTEMPTS = 2; // 减少最大重试次数
const GLOBAL_RETRY_COUNTER = new Map<string, number>(); // 全局重试计数器
const MAX_GLOBAL_RETRIES = 5; // 全局最大重试次数

// 防抖计时器
const debounceTimers = new Map<string, NodeJS.Timeout>();
const DEFAULT_DEBOUNCE_MS = 300; // 默认防抖时间300ms

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
  params?: any,
  debounceMs?: number
): Promise<T> {
  const cacheKey = getCacheKey(url, params);
  
  // 检查缓存
  const cached = requestCache.get(cacheKey);
  if (cached && isCacheValid(cached.timestamp, cached.ttl)) {
    return cached.data;
  }
  
  // 防抖处理
  if (debounceMs) {
    // 清除旧的计时器
    if (debounceTimers.has(cacheKey)) {
      clearTimeout(debounceTimers.get(cacheKey));
    }
    
    // 返回一个包装的Promise，实现防抖
    return new Promise((resolve, reject) => {
      debounceTimers.set(cacheKey, setTimeout(async () => {
        try {
          const result = await executeRequest<T>(cacheKey, requestFn, ttl);
          resolve(result);
        } catch (error) {
          reject(error);
        } finally {
          debounceTimers.delete(cacheKey);
        }
      }, debounceMs));
    });
  }
  
  // 无防抖，直接执行
  return executeRequest<T>(cacheKey, requestFn, ttl);
}

// 执行请求的辅助函数
async function executeRequest<T>(
  cacheKey: string,
  requestFn: () => Promise<T>,
  ttl: number
): Promise<T> {
  // 检查是否有正在进行的相同请求
  if (pendingRequests.has(cacheKey)) {
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
  // 总是优先从 cookie 中读取 CSRF token（因为后端验证时使用的是 cookie 中的 token）
  // 不使用内存缓存，确保每次都是最新的 token
  const cookieToken = document.cookie
    .split('; ')
    .find(row => row.startsWith('csrf_token='))
    ?.split('=')[1];
  
  if (cookieToken) {
    // 更新内存中的缓存（用于调试）
    csrfToken = cookieToken;
    return cookieToken;
  }
  
  // 如果 cookie 中没有 token，从 API 获取新的 token
  try {
    const response = await api.get('/api/csrf/token');
    const newToken = response.data.csrf_token;
    if (!newToken) {
      throw new Error('CSRF token为空');
    }
    // 更新内存缓存
    csrfToken = newToken;
    return newToken;
  } catch (error) {
    console.error('获取CSRF token失败:', error);
    throw error;
  }
}

// 清除CSRF token的函数
export function clearCSRFToken(): void {
  csrfToken = null;
}

// 检测是否为移动端
function isMobileDevice(): boolean {
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

api.interceptors.request.use(async config => {
  // 所有设备都使用HttpOnly Cookie认证，不再区分移动端和桌面端
  
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
  
  return config;
});

// 清理重试计数器的函数
function clearRetryCounters() {
  retryCounters.clear();
  GLOBAL_RETRY_COUNTER.clear();
}

// 响应拦截器 - 处理认证失败、token刷新和CSRF错误
api.interceptors.response.use(
  response => {
    // 成功响应后清理重试计数器
    if (response.status >= 200 && response.status < 300) {
      const globalKey = 'global_401_retry';
      if (GLOBAL_RETRY_COUNTER.has(globalKey)) {
        GLOBAL_RETRY_COUNTER.delete(globalKey);
      }
    }
    
    return response;
  },
  async error => {
    // 处理速率限制错误（429）
    if (error.response?.status === 429) {
      const retryAfter = error.response.headers['retry-after'] || error.response.headers['Retry-After'];
      const retryAfterSeconds = retryAfter ? parseInt(retryAfter, 10) : 60;
      
      console.warn(`速率限制：请在 ${retryAfterSeconds} 秒后重试`);
      
      // 可以在这里实现自动重试逻辑（可选）
      // 或者让调用方处理
      return Promise.reject({
        ...error,
        retryAfter: retryAfterSeconds,
        message: `请求过于频繁，请在 ${retryAfterSeconds} 秒后重试`
      });
    }
    
    // 首先检查是否是CSRF token验证失败
    if ((error.response?.status === 401 || error.response?.status === 403) && 
        error.response?.data?.detail?.includes('CSRF token验证失败')) {
      
      const requestKey = `${error.config?.method}_${error.config?.url}`;
      const currentRetryCount = retryCounters.get(requestKey) || 0;
      
      
      if (currentRetryCount >= MAX_RETRY_ATTEMPTS) {
        console.error('CSRF token重试次数已达上限，停止重试');
        retryCounters.delete(requestKey);
        return Promise.reject(error);
      }
      
      // 对于接收任务等关键操作，减少重试次数
      const isCriticalOperation = error.config?.url?.includes('/accept') || 
                                 error.config?.url?.includes('/complete') ||
                                 error.config?.url?.includes('/cancel');
      
      if (isCriticalOperation && currentRetryCount >= 1) {
        console.error('关键操作CSRF验证失败，减少重试次数');
        retryCounters.delete(requestKey);
        return Promise.reject(error);
      }
      
      retryCounters.set(requestKey, currentRetryCount + 1);
      
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
        
        const result = await api.request(retryConfig);
        // 成功后清除重试计数
        retryCounters.delete(requestKey);
        return result;
      } catch (retryError) {
        console.error('重试请求失败:', retryError);
        return Promise.reject(retryError);
      }
    }
    
    // 处理其他401错误（token过期等）
    if (error.response?.status === 401) {
      // 对于某些API，不尝试刷新token，直接返回错误
      const skipRefreshApis = [
        '/api/secure-auth/refresh',
        '/api/secure-auth/refresh-token',
        '/api/cs/refresh',
        '/api/admin/refresh',
        '/api/users/messages/mark-chat-read'
      ];
      
      if (skipRefreshApis.some(api => error.config?.url?.includes(api))) {
        return Promise.reject(error);
      }
      
      // 全局重试控制 - 防止无限循环
      const globalKey = 'global_401_retry';
      const globalRetryCount = GLOBAL_RETRY_COUNTER.get(globalKey) || 0;
      
      if (globalRetryCount >= MAX_GLOBAL_RETRIES) {
        console.error('全局401重试次数已达上限，停止所有重试');
        GLOBAL_RETRY_COUNTER.delete(globalKey);
        // 清理所有重试计数器
        retryCounters.clear();
        return Promise.reject(error);
      }
      
      // 检查是否是接收任务API，如果是则限制重试次数
      const isAcceptTaskApi = error.config?.url?.includes('/accept');
      const requestKey = `${error.config?.method}_${error.config?.url}`;
      const currentRetryCount = retryCounters.get(requestKey) || 0;
      
      if (isAcceptTaskApi && currentRetryCount >= 1) {
        console.error('接收任务API重试次数已达上限，停止重试');
        retryCounters.delete(requestKey);
        return Promise.reject(error);
      }
      
      // 避免重复刷新token
      if (isRefreshing) {
        // 如果正在刷新，等待刷新完成
        if (refreshPromise) {
          try {
            await refreshPromise;
            // 刷新完成后重试原始请求
            if (isAcceptTaskApi) {
              retryCounters.set(requestKey, currentRetryCount + 1);
            }
            return api.request(error.config);
          } catch (refreshError) {
            return Promise.reject(error);
          }
        } else {
          // 如果没有刷新promise，直接返回错误
          return Promise.reject(error);
        }
      } else {
        // 开始刷新token
        isRefreshing = true;
        
        // 根据当前页面确定refresh端点
        let refreshEndpoint = '/api/secure-auth/refresh'; // 默认用户refresh端点
        
        // 检查当前URL路径来确定用户类型
        if (window.location.pathname.includes('/admin')) {
          refreshEndpoint = '/api/auth/admin/refresh';
        } else if (window.location.pathname.includes('/customer-service') || window.location.pathname.includes('/service')) {
          refreshEndpoint = '/api/auth/service/refresh';
        }
        
        // 对于用户，先尝试使用refresh端点（需要session仍然有效）
        // 如果失败，再尝试使用refresh-token端点（使用refresh_token重新创建session）
        refreshPromise = api.post(refreshEndpoint);
        
        try {
          const refreshResponse = await refreshPromise;
          
          // 会话刷新成功后，清除缓存的 CSRF token
          // 下次获取时会从 cookie 中读取最新的 token
          clearCSRFToken();
          
          // 增加全局重试计数
          GLOBAL_RETRY_COUNTER.set(globalKey, globalRetryCount + 1);
          
          // 重试原始请求
          if (isAcceptTaskApi) {
            retryCounters.set(requestKey, currentRetryCount + 1);
          }
          return api.request(error.config);
        } catch (refreshError) {
          
          // 如果refresh端点失败（session已过期），尝试使用refresh-token端点
          if (!window.location.pathname.includes('/admin') && 
              !window.location.pathname.includes('/customer-service') && 
              !window.location.pathname.includes('/service')) {
            try {
              refreshPromise = api.post('/api/secure-auth/refresh-token');
              const refreshTokenResponse = await refreshPromise;
              
              // 会话刷新成功后，清除缓存的 CSRF token
              // 下次获取时会从 cookie 中读取最新的 token
              clearCSRFToken();
              
              // 增加全局重试计数
              GLOBAL_RETRY_COUNTER.set(globalKey, globalRetryCount + 1);
              
              // 重试原始请求
              if (isAcceptTaskApi) {
                retryCounters.set(requestKey, currentRetryCount + 1);
              }
              return api.request(error.config);
            } catch (refreshTokenError) {
              // 增加全局重试计数
              GLOBAL_RETRY_COUNTER.set(globalKey, globalRetryCount + 1);
              // HttpOnly Cookie会自动处理，无需手动清理
              // 让各个组件自己处理认证失败的情况
              return Promise.reject(refreshTokenError);
            } finally {
              refreshPromise = null;
            }
          } else {
            // 增加全局重试计数
            GLOBAL_RETRY_COUNTER.set(globalKey, globalRetryCount + 1);
            // HttpOnly Cookie会自动处理，无需手动清理
            // 让各个组件自己处理认证失败的情况
            return Promise.reject(refreshError);
          }
        } finally {
          // 重置刷新状态
          isRefreshing = false;
          refreshPromise = null;
        }
      }
    }
    
    return Promise.reject(error);
  }
);

// 防抖计时器映射
const fetchTasksDebounceTimers = new Map<string, NodeJS.Timeout>();

export async function fetchTasks({ type, city, keyword, page = 1, pageSize = 10, sort_by }: {
  type?: string;
  city?: string;
  keyword?: string;
  page?: number;
  pageSize?: number;
  sort_by?: string;
}) {
  const params: Record<string, any> = {};
  if (type && type !== 'all' && type !== '全部类型') params.task_type = type;
  if (city && city !== 'all' && city !== '全部城市') params.location = city;
  if (keyword) params.keyword = keyword;
  // 始终传递 sort_by 参数，即使它是 'latest'
  params.sort_by = sort_by || 'latest';
  params.page = page;
  params.page_size = pageSize;
  
  // 生成缓存键
  const cacheKey = JSON.stringify(params);
  
  // 对于搜索关键词，使用防抖（300ms）
  if (keyword) {
    return new Promise((resolve, reject) => {
      // 清除之前的计时器
      if (fetchTasksDebounceTimers.has(cacheKey)) {
        clearTimeout(fetchTasksDebounceTimers.get(cacheKey)!);
      }
      
      // 设置新的防抖计时器
      const timer = setTimeout(async () => {
        try {
          const res = await api.get('/api/tasks', { params });
          fetchTasksDebounceTimers.delete(cacheKey);
          resolve(res.data);
        } catch (error) {
          fetchTasksDebounceTimers.delete(cacheKey);
          console.error('fetchTasks 请求失败:', error);
          reject(error);
        }
      }, 300); // 300ms防抖
      
      fetchTasksDebounceTimers.set(cacheKey, timer);
    });
  }
  
  // 排序操作应该总是绕过缓存，确保排序立即生效
  // 对于非搜索请求，如果明确指定了排序参数（包括 'latest'），不使用缓存
  // 这样可以确保用户切换排序时能立即看到最新结果
  try {
    // 如果明确传入了 sort_by 参数（即使是 'latest'），也绕过缓存以确保排序立即生效
    // 只有在没有明确排序参数时才使用缓存（这种情况应该很少）
    if (sort_by !== undefined && sort_by !== null) {
      // 有排序参数时，直接请求不使用缓存，确保排序立即生效
      console.log('[api.ts] 排序请求，绕过缓存，sort_by:', sort_by);
      const res = await api.get('/api/tasks', { params });
      return res.data;
    } else {
      // 无排序参数时，使用缓存
      const res = await cachedRequest(
        '/api/tasks',
        () => api.get('/api/tasks', { params }).then(r => r.data),
        CACHE_TTL.TASKS,
        params
      );
      return res;
    }
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

// 获取所有未读通知和最近N条已读通知
export async function getNotificationsWithRecentRead(recentReadLimit: number = 10) {
  const res = await api.get('/api/users/notifications/with-recent-read', {
    params: { recent_read_limit: recentReadLimit }
  });
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

// 申请任务（支持议价价格）
export async function applyForTask(taskId: number, message?: string, negotiatedPrice?: number, currency?: string) {
  // 构建请求体，只包含有值的字段
  const requestBody: any = {};
  if (message !== undefined && message !== null && message !== '') {
    requestBody.message = message;
  }
  if (negotiatedPrice !== undefined && negotiatedPrice !== null) {
    requestBody.negotiated_price = negotiatedPrice;
  }
  if (currency !== undefined && currency !== null) {
    requestBody.currency = currency;
  }
  
  const res = await api.post(`/api/tasks/${taskId}/apply`, requestBody);
  return res.data;
}

// ========== 任务聊天相关API ==========

// 获取任务聊天列表
export async function getTaskChatList(limit: number = 20, offset: number = 0) {
  const res = await api.get('/api/messages/tasks', {
    params: { limit, offset }
  });
  return res.data;
}

// 获取任务聊天消息（游标分页）
export async function getTaskMessages(taskId: number, limit: number = 20, cursor?: string) {
  const res = await api.get(`/api/messages/task/${taskId}`, {
    params: { limit, cursor }
  });
  return res.data;
}

// 发送任务消息
export async function sendTaskMessage(
  taskId: number,
  content: string,
  meta?: any,
  attachments?: Array<{
    attachment_type: string;
    url?: string;
    blob_id?: string;
    meta?: any;
  }>
) {
  const res = await api.post(`/api/messages/task/${taskId}/send`, {
    content,
    meta,
    attachments
  });
  return res.data;
}

// 标记消息已读
export async function markTaskMessagesRead(
  taskId: number,
  uptoMessageId?: number,
  messageIds?: number[]
) {
  // 构建请求体，只包含有值的字段
  const requestBody: any = {};
  if (uptoMessageId !== undefined && uptoMessageId !== null) {
    requestBody.upto_message_id = uptoMessageId;
  }
  if (messageIds !== undefined && messageIds !== null && messageIds.length > 0) {
    requestBody.message_ids = messageIds;
  }
  
  const res = await api.post(`/api/messages/task/${taskId}/read`, requestBody);
  return res.data;
}

// 获取任务申请列表（独立接口，支持状态过滤和分页）
export async function getTaskApplicationsWithFilter(
  taskId: number, 
  status?: string, 
  limit: number = 20, 
  offset: number = 0
) {
  const res = await api.get(`/api/tasks/${taskId}/applications`, {
    params: { status, limit, offset }
  });
  return res.data;
}

// 获取任务申请列表（兼容旧接口，默认获取所有状态）
export async function getTaskApplications(taskId: number) {
  const data = await getTaskApplicationsWithFilter(taskId, undefined, 50, 0);
  // 返回格式兼容：如果返回的是 {applications: [...]}，则返回 applications 数组
  return data.applications || data;
}

// 接受申请
export async function acceptApplication(taskId: number, applicationId: number) {
  const res = await api.post(`/api/tasks/${taskId}/applications/${applicationId}/accept`);
  return res.data;
}

// 拒绝申请
export async function rejectApplication(taskId: number, applicationId: number) {
  const res = await api.post(`/api/tasks/${taskId}/applications/${applicationId}/reject`);
  return res.data;
}

// 撤回申请
export async function withdrawApplication(taskId: number, applicationId: number) {
  const res = await api.post(`/api/tasks/${taskId}/applications/${applicationId}/withdraw`);
  return res.data;
}

// 再次议价
export async function negotiateApplication(
  taskId: number,
  applicationId: number,
  negotiatedPrice: number,
  message?: string
) {
  const res = await api.post(`/api/tasks/${taskId}/applications/${applicationId}/negotiate`, {
    negotiated_price: negotiatedPrice,
    message
  });
  return res.data;
}

// 处理再次议价（同意/拒绝）
export async function respondNegotiation(
  taskId: number,
  applicationId: number,
  action: 'accept' | 'reject',
  token: string
) {
  const res = await api.post(`/api/tasks/${taskId}/applications/${applicationId}/respond-negotiation`, {
    action,
    token
  });
  return res.data;
}

// 发送申请留言（可包含议价）
export async function sendApplicationMessage(
  taskId: number,
  applicationId: number,
  message: string,
  negotiatedPrice?: number
) {
  const res = await api.post(`/api/tasks/${taskId}/applications/${applicationId}/send-message`, {
    message,
    negotiated_price: negotiatedPrice
  });
  return res.data;
}

// 回复申请留言
export async function replyApplicationMessage(
  taskId: number,
  applicationId: number,
  message: string,
  notificationId: number
) {
  const res = await api.post(`/api/tasks/${taskId}/applications/${applicationId}/reply-message`, {
    message,
    notification_id: notificationId
  });
  return res.data;
}

// 获取用户申请记录
export async function getUserApplications() {
  const res = await api.get(`/api/my-applications`);
  return res.data;
}

// 批准申请者
export async function approveApplication(taskId: number, applicantId: string) {
  const res = await api.post(`/api/tasks/${taskId}/approve/${applicantId}`);
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
  const res = await api.post(`/api/users/tasks/${taskId}/complete`);
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

// 获取用户收到的评价（包括匿名评价）
export async function getUserReceivedReviews(userId: string) {
  const res = await api.get(`/api/users/${userId}/received-reviews`);
  return res.data;
}

// 客服管理相关API
export async function getAdminUsers() {
  const res = await api.get('/api/admin/users');
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
  const res = await api.get('/api/admin/tasks', { params });
  return res.data;
}

export async function getAdminTaskDetail(taskId: number) {
  const res = await api.get(`/api/admin/tasks/${taskId}`);
  return res.data;
}

export async function updateAdminTask(taskId: number, taskUpdate: any) {
  const res = await api.put(`/api/admin/tasks/${taskId}`, taskUpdate);
  return res.data;
}

export async function deleteAdminTask(taskId: number) {
  const res = await api.delete(`/api/admin/tasks/${taskId}`);
  return res.data;
}

export async function batchUpdateAdminTasks(taskIds: number[], taskUpdate: any) {
  const res = await api.post('/api/admin/tasks/batch-update', {
    task_ids: taskIds,
    ...taskUpdate
  });
  return res.data;
}

export async function batchDeleteAdminTasks(taskIds: number[]) {
  const res = await api.post('/api/admin/tasks/batch-delete', {
    task_ids: taskIds
  });
  return res.data;
}

// 客服管理相关API
export async function getAdminCustomerServiceRequests(params?: {
  status?: string;
  priority?: string;
}) {
  const res = await api.get('/api/admin/customer-service-requests', { params });
  return res.data;
}

export async function getAdminCustomerServiceRequestDetail(requestId: number) {
  const res = await api.get(`/api/admin/customer-service-requests/${requestId}`);
  return res.data;
}

export async function updateAdminCustomerServiceRequest(requestId: number, updateData: any) {
  const res = await api.put(`/api/admin/customer-service-requests/${requestId}`, updateData);
  return res.data;
}

export async function getAdminCustomerServiceChatMessages() {
  const res = await api.get('/api/admin/customer-service-chat');
  return res.data;
}

export async function sendAdminCustomerServiceChatMessage(content: string) {
  const res = await api.post('/api/admin/customer-service-chat', { content });
  return res.data;
}

export async function getAdminMessages() {
  const res = await api.get('/api/admin/messages');
  return res.data;
}

export async function setUserLevel(userId: string, level: string) {
  const res = await api.post(`/api/admin/user/${userId}/set_level`, level);
  return res.data;
}

export async function setUserStatus(userId: string, status: {
  is_banned?: number;
  is_suspended?: number;
  suspend_until?: string;
}) {
  const res = await api.post(`/api/admin/user/${userId}/set_status`, status);
  return res.data;
}

export async function setTaskLevel(taskId: number, level: string) {
  const res = await api.post(`/api/admin/task/${taskId}/set_level`, level);
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
  const res = await api.get('/api/admin/payments');
  return res.data;
}

// 客服相关API
export const assignCustomerService = async () => {
  const response = await api.post('/api/users/assign_customer_service');
  return response.data;
};

export const getCustomerServiceSessions = async () => {
  const response = await api.get('/api/customer-service/chats');
  return response.data;
};

export const getCustomerServiceMessages = async (chatId: string) => {
  const response = await api.get(`/api/customer-service/messages/${chatId}`);
  return response.data;
};

export const markCustomerServiceMessagesRead = async (chatId: string) => {
  const response = await api.post(`/api/customer-service/mark-messages-read/${chatId}`);
  return response.data;
};

// 标记普通聊天的消息为已读
export const markChatMessagesAsRead = async (contactId: string) => {
  try {
    const response = await api.post(`/api/users/messages/mark-chat-read/${contactId}`);
    return response.data;
  } catch (error) {
    console.error('❌ 标记已读API错误:', error);
    throw error;
  }
};

// 获取每个联系人的未读消息数量
export const getContactUnreadCounts = async () => {
  const response = await api.get('/api/users/messages/unread/by-contact');
  return response.data;
};

export const sendCustomerServiceMessage = async (chatId: string, content: string) => {
  const response = await api.post(`/api/customer-service/send-message/${chatId}`, { content });
  return response.data;
};

export const setCustomerServiceOnline = async () => {
  
  try {
    const response = await api.post('/api/customer-service/online');
    return response.data;
  } catch (error: any) {
    console.error('❌ 客服在线API调用失败:', error);
    console.error('错误详情:', {
      status: error.response?.status,
      statusText: error.response?.statusText,
      data: error.response?.data,
      message: error.message
    });
    throw error;
  }
};

export const setCustomerServiceOffline = async () => {
  
  try {
    const response = await api.post('/api/customer-service/offline');
    return response.data;
  } catch (error: any) {
    console.error('❌ 客服离线API调用失败:', error);
    console.error('错误详情:', {
      status: error.response?.status,
      statusText: error.response?.statusText,
      data: error.response?.data,
      message: error.message
    });
    throw error;
  }
};

export const getCustomerServiceStatus = async () => {
  const response = await api.get('/api/customer-service/status');
  return response.data;
};

// 结束对话和评分相关API
export const endCustomerServiceSession = async (sessionId: number) => {
  const response = await api.post(`/api/customer-service/end-session/${sessionId}`);
  return response.data;
};

export const rateCustomerService = async (sessionId: number, rating: number, comment?: string) => {
  const response = await api.post(`/api/customer-service/rate/${sessionId}`, { rating, comment });
  return response.data;
};

export const getMyCustomerServiceSessions = async () => {
  const res = await api.get('/api/customer-service/my-sessions');
  return res.data;
};

// 客服改名接口
export const updateCustomerServiceName = async (name: string) => {
  const res = await api.patch('/api/customer-service/update-name', name);
  return res.data;
};

export const customerServiceLogout = async () => {
  const res = await api.post('/api/customer-service/logout');
  return res.data;
};

// 管理后台相关API
export const getDashboardStats = async () => {
  const res = await api.get('/api/admin/dashboard/stats');
  return res.data;
};

// 管理员通知相关API
export const getAdminNotifications = async () => {
  const res = await api.get('/api/auth/admin/notifications');
  return res.data;
};

export const getUnreadAdminNotifications = async () => {
  const res = await api.get('/api/auth/admin/notifications/unread');
  return res.data;
};

export const markAdminNotificationRead = async (notificationId: number) => {
  const res = await api.post(`/api/auth/admin/notifications/${notificationId}/read`);
  return res.data;
};

export const markAllAdminNotificationsRead = async () => {
  const res = await api.post('/api/auth/admin/notifications/read-all');
  return res.data;
};

// 管理员refresh token
export const adminRefreshToken = async () => {
  const res = await api.post('/api/auth/admin/refresh');
  return res.data;
};

// 管理员退出登录
export const adminLogout = async () => {
  try {
    const res = await api.post('/api/auth/admin/logout');
    // 清除所有cookie（前端也清除一次，确保完全清除）
    document.cookie.split(";").forEach((c) => {
      const eqPos = c.indexOf("=");
      const name = eqPos > -1 ? c.substr(0, eqPos).trim() : c.trim();
      // 清除所有可能的cookie
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=${window.location.hostname}`;
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=.${window.location.hostname}`;
    });
    return res.data;
  } catch (error) {
    // 即使API调用失败，也清除前端cookie
    document.cookie.split(";").forEach((c) => {
      const eqPos = c.indexOf("=");
      const name = eqPos > -1 ? c.substr(0, eqPos).trim() : c.trim();
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=${window.location.hostname}`;
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=.${window.location.hostname}`;
    });
    throw error;
  }
};

export const getUsersForAdmin = async (page: number = 1, size: number = 20, search?: string) => {
  const params = new URLSearchParams();
  params.append('page', page.toString());
  params.append('size', size.toString());
  if (search) {
    params.append('search', search);
  }
  const res = await api.get(`/api/admin/users?${params.toString()}`);
  return res.data;
};

export const updateUserByAdmin = async (userId: string, userData: any) => {
  const res = await api.patch(`/api/admin/users/${userId}`, userData);
  return res.data;
};

export const createCustomerService = async (csData: {
  name: string;
  email: string;
  password: string;
}) => {
  const res = await api.post('/api/admin/customer-service', csData);
  return res.data;
};

export const deleteCustomerService = async (csId: number) => {
  const res = await api.delete(`/api/admin/customer-service/${csId}`);
  return res.data;
};

export const getCustomerServicesForAdmin = async (page: number = 1, size: number = 20) => {
  const params = new URLSearchParams();
  params.append('page', page.toString());
  params.append('size', size.toString());
  const res = await api.get(`/api/admin/customer-service?${params.toString()}`);
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
  const res = await api.post('/api/admin/admin-user', adminData);
  return res.data;
};

export const deleteAdminUser = async (adminId: string) => {
  const res = await api.delete(`/api/admin/admin-user/${adminId}`);
  return res.data;
};

export const getAdminUsersForAdmin = async (page: number = 1, size: number = 20) => {
  const params = new URLSearchParams();
  params.append('page', page.toString());
  params.append('size', size.toString());
  const res = await api.get(`/api/admin/admin-users?${params.toString()}`);
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
  const res = await api.post('/api/admin/staff-notification', notification);
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
  const res = await api.post('/api/admin/notifications/send', notification);
  return res.data;
};

export const updateTaskByAdmin = async (taskId: number, taskData: any) => {
  const res = await api.patch(`/api/admin/tasks/${taskId}`, taskData);
  return res.data;
};

export const deleteTaskByAdmin = async (taskId: number) => {
  const res = await api.delete(`/api/admin/tasks/${taskId}`);
  return res.data;
};

export const notifyCustomerService = async (csId: number, message: string) => {
  const res = await api.post(`/api/admin/customer-service/${csId}/notify`, message);
  return res.data;
};

// 后台管理员登录
export const adminLogin = async (loginData: { username: string; password: string }) => {
  const res = await api.post('/api/admin/login', loginData);
  return res.data;
};

// 系统设置相关API
export const getSystemSettings = async () => {
  const res = await api.get('/api/admin/system-settings');
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
  const res = await api.put('/api/admin/system-settings', settings);
  return res.data;
};

export const getPublicSystemSettings = async () => {
  const res = await api.get('/api/system-settings/public');
  return res.data;
};

// 检查客服可用性
export const checkCustomerServiceAvailability = async () => {
  const res = await api.get('/api/customer-service/check-availability');
  return res.data;
};

// 用户登录
export const login = async (email: string, password: string) => {
  const res = await api.post('/api/secure-auth/login', { email, password });
  
  // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
  
  return res.data;
};

// 用户注册
export const register = async (userData: {
  email: string;
  password: string;
  name: string;  // 改为 name
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

// 用户登出
export const logout = async () => {
  try {
    await api.post('/api/secure-auth/logout');
  } catch (error) {
    console.warn('登出请求失败:', error);
  } finally {
    // 新的认证系统使用HttpOnly Cookie，不需要清理localStorage
    clearCSRFToken();
    // 清理重试计数器
    clearRetryCounters();
  }
};

// 岗位管理API
export const getJobPositions = async (params?: {
  page?: number;
  size?: number;
  is_active?: boolean;
  department?: string;
  type?: string;
}) => {
  const res = await api.get('/api/admin/job-positions', { params });
  return res.data;
};

export const getJobPosition = async (positionId: number) => {
  const res = await api.get(`/api/admin/job-positions/${positionId}`);
  return res.data;
};

export const createJobPosition = async (position: {
  title: string;
  title_en?: string;
  department: string;
  department_en?: string;
  type: string;
  type_en?: string;
  location: string;
  location_en?: string;
  experience: string;
  experience_en?: string;
  salary: string;
  salary_en?: string;
  description: string;
  description_en?: string;
  requirements: string[];
  requirements_en?: string[];
  tags?: string[];
  tags_en?: string[];
  is_active: boolean;
}) => {
  const res = await api.post('/api/admin/job-positions', position);
  return res.data;
};

export const updateJobPosition = async (positionId: number, position: {
  title?: string;
  title_en?: string;
  department?: string;
  department_en?: string;
  type?: string;
  type_en?: string;
  location?: string;
  location_en?: string;
  experience?: string;
  experience_en?: string;
  salary?: string;
  salary_en?: string;
  description?: string;
  description_en?: string;
  requirements?: string[];
  requirements_en?: string[];
  tags?: string[];
  tags_en?: string[];
  is_active?: boolean;
}) => {
  const res = await api.put(`/api/admin/job-positions/${positionId}`, position);
  return res.data;
};

export const deleteJobPosition = async (positionId: number) => {
  const res = await api.delete(`/api/admin/job-positions/${positionId}`);
  return res.data;
};

export const toggleJobPositionStatus = async (positionId: number) => {
  const res = await api.patch(`/api/admin/job-positions/${positionId}/toggle-status`);
  return res.data;
};

// 公开API - 获取启用的岗位列表（用于join页面）
export const getPublicJobPositions = async (params?: {
  page?: number;
  size?: number;
  department?: string;
  type?: string;
}) => {
  const res = await api.get('/api/job-positions', { params });
  return res.data;
};

// ==================== 任务达人管理 API ====================

// 管理员 API - 获取任务达人列表
export const getTaskExperts = async (params?: {
  page?: number;
  size?: number;
  category?: string;
  is_active?: number;
}) => {
  const res = await api.get('/api/admin/task-experts', { params });
  return res.data;
};

// 管理员 API - 创建任务达人
export const createTaskExpert = async (expertData: any) => {
  const res = await api.post('/api/admin/task-expert', expertData);
  return res.data;
};

// 管理员 API - 更新任务达人
export const updateTaskExpert = async (expertId: number, expertData: any) => {
  const res = await api.put(`/api/admin/task-expert/${expertId}`, expertData);
  return res.data;
};

// 管理员 API - 删除任务达人
export const deleteTaskExpert = async (expertId: number) => {
  const res = await api.delete(`/api/admin/task-expert/${expertId}`);
  return res.data;
};

// 公开 API - 获取任务达人列表（用于前端展示）
export const getPublicTaskExperts = async (category?: string) => {
  const params = category ? { category } : {};
  const res = await api.get('/api/task-experts', { params });
  return res.data;
};

// 翻译API - 翻译单个文本
export const translateText = async (
  text: string,
  targetLanguage: string,
  sourceLanguage?: string
) => {
  console.log('翻译API调用:', { text: text.substring(0, 50), targetLanguage, sourceLanguage });
  try {
    const res = await api.post('/api/translate', {
      text,
      target_language: targetLanguage,
      ...(sourceLanguage && { source_language: sourceLanguage })
    });
    console.log('翻译API响应:', res.data);
    return res.data;
  } catch (error: any) {
    console.error('翻译API错误:', error);
    console.error('错误详情:', error.response?.data);
    throw error;
  }
};

// 翻译API - 批量翻译
export const translateBatch = async (
  texts: string[],
  targetLanguage: string,
  sourceLanguage?: string
) => {
  const res = await api.post('/api/translate/batch', {
    texts,
    target_language: targetLanguage,
    ...(sourceLanguage && { source_language: sourceLanguage })
  });
  return res.data;
};

// ==================== 邀请码管理 API ====================

// 创建邀请码
export const createInvitationCode = async (data: {
  code: string;
  name?: string;
  description?: string;
  reward_type: 'points' | 'coupon' | 'both';
  points_reward?: number;
  coupon_id?: number;
  max_uses?: number;
  valid_from: string;
  valid_until: string;
  is_active?: boolean;
}) => {
  const res = await api.post('/api/admin/invitation-codes', data);
  return res.data;
};

// 获取邀请码列表
export const getInvitationCodes = async (params?: {
  page?: number;
  limit?: number;
  status?: 'active' | 'inactive';
}) => {
  const res = await api.get('/api/admin/invitation-codes', { params });
  return res.data;
};

// 获取邀请码详情
export const getInvitationCodeDetail = async (invitationId: number) => {
  const res = await api.get(`/api/admin/invitation-codes/${invitationId}`);
  return res.data;
};

// 更新邀请码
export const updateInvitationCode = async (invitationId: number, data: {
  name?: string;
  description?: string;
  is_active?: boolean;
  max_uses?: number;
  valid_from?: string;
  valid_until?: string;
  points_reward?: number;
  coupon_id?: number;
}) => {
  const res = await api.put(`/api/admin/invitation-codes/${invitationId}`, data);
  return res.data;
};

// 删除邀请码
export const deleteInvitationCode = async (invitationId: number) => {
  const res = await api.delete(`/api/admin/invitation-codes/${invitationId}`);
  return res.data;
};

// ==================== 积分系统 API ====================

// 获取积分账户信息
export const getPointsAccount = async () => {
  const res = await api.get('/api/points/account');
  return res.data;
};

// 获取积分交易记录
export const getPointsTransactions = async (params?: {
  page?: number;
  limit?: number;
}) => {
  const res = await api.get('/api/points/transactions', { params });
  return res.data;
};

export default api; 