import axios, { AxiosError } from 'axios';
import { API_BASE_URL } from './config';
import { logger } from './utils/logger';

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
    return cookieToken;
  }
  
  // 如果 cookie 中没有 token，从 API 获取新的 token
  try {
    const response = await api.get('/api/csrf/token');
    const newToken = response.data.csrf_token;
    if (!newToken) {
      throw new Error('CSRF token为空');
    }
    return newToken;
  } catch (error) {
        throw error;
  }
}

// 清除CSRF token的函数
export function clearCSRFToken(): void {
  // CSRF token 存储在 HttpOnly cookie 中，由后端管理
  // 此函数保留用于向后兼容，实际清除由后端处理
}

api.interceptors.request.use(async config => {
  // 所有设备都使用HttpOnly Cookie认证，不再区分移动端和桌面端
  
  // 如果请求数据是 FormData，删除手动设置的 Content-Type
  // 让浏览器自动设置（包含 boundary）
  if (config.data instanceof FormData) {
    delete config.headers['Content-Type'];
  }
  
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
// 性能监控：记录API调用时间
api.interceptors.request.use((config) => {
  // 使用类型断言添加 metadata 属性
  (config as any).metadata = { startTime: performance.now() };
  return config;
});

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
  async (error: AxiosError) => {
    // 记录API错误性能
    const metadata = error.config ? (error.config as any).metadata : undefined;
    if (metadata?.startTime) {
      const duration = performance.now() - metadata.startTime;
      logger.warn(`API请求失败: ${error.config?.url} 耗时 ${duration.toFixed(2)}ms`, error);
    } else {
      logger.error('API请求错误:', error);
    }
    
    // 处理速率限制错误（429）
    if (error.response?.status === 429) {
      const retryAfter = error.response.headers['retry-after'] || error.response.headers['Retry-After'];
      const retryAfterSeconds = retryAfter ? parseInt(retryAfter, 10) : 60;
      
            // 可以在这里实现自动重试逻辑（可选）
      // 或者让调用方处理
      return Promise.reject({
        ...error,
        retryAfter: retryAfterSeconds,
        message: `请求过于频繁，请在 ${retryAfterSeconds} 秒后重试`
      });
    }
    
    // 首先检查是否是CSRF token验证失败
    const errorData = error.response?.data as any;
    if ((error.response?.status === 401 || error.response?.status === 403) && 
        errorData?.detail && typeof errorData.detail === 'string' && 
        errorData.detail.includes('CSRF token验证失败')) {
      
      const requestKey = `${error.config?.method}_${error.config?.url}`;
      const currentRetryCount = retryCounters.get(requestKey) || 0;
      
      
      if (currentRetryCount >= MAX_RETRY_ATTEMPTS) {
                retryCounters.delete(requestKey);
        return Promise.reject(error);
      }
      
      // 对于接收任务等关键操作，减少重试次数
      const isCriticalOperation = error.config?.url?.includes('/accept') || 
                                 error.config?.url?.includes('/complete') ||
                                 error.config?.url?.includes('/cancel');
      
      if (isCriticalOperation && currentRetryCount >= 1) {
                retryCounters.delete(requestKey);
        return Promise.reject(error);
      }
      
      retryCounters.set(requestKey, currentRetryCount + 1);
      
      try {
        // 清除旧的CSRF token
        clearCSRFToken();
        
        // 重新获取CSRF token
        const newToken = await getCSRFToken();
        
        // 检查 error.config 是否存在
        if (!error.config) {
          return Promise.reject(error);
        }
        
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
                return Promise.reject(retryError);
      }
    }
    
    // 处理其他401错误（token过期等）
    if (error.response?.status === 401) {
      // 对于某些API，不尝试刷新token，直接返回错误
      const skipRefreshApis = [
        '/api/secure-auth/refresh',
        '/api/secure-auth/refresh-token',
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
                retryCounters.delete(requestKey);
        return Promise.reject(error);
      }
      
      // 检查 error.config 是否存在
      if (!error.config) {
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
        }
        
        // 对于用户，先尝试使用refresh端点（需要session仍然有效）
        // 如果失败，再尝试使用refresh-token端点（使用refresh_token重新创建session）
        refreshPromise = api.post(refreshEndpoint);
        
        try {
          await refreshPromise;
          
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
          if (!window.location.pathname.includes('/admin')) {
            try {
              refreshPromise = api.post('/api/secure-auth/refresh-token');
              await refreshPromise;
              
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

// ==================== 任务推荐API ====================

/**
 * 获取个性化任务推荐（支持筛选条件）
 * @param limit 返回任务数量（1-50）
 * @param algorithm 推荐算法类型：content_based, collaborative, hybrid
 * @param taskType 任务类型筛选
 * @param location 地点筛选
 * @param keyword 关键词筛选
 */
export async function getTaskRecommendations(
  limit: number = 20, 
  algorithm: string = 'hybrid',
  taskType?: string,
  location?: string,
  keyword?: string
) {
  try {
    const params: any = { limit, algorithm };
    if (taskType && taskType !== 'all') params.task_type = taskType;
    if (location && location !== 'all') params.location = location;
    if (keyword) params.keyword = keyword;
    
    // 增强：如果用户允许位置权限，获取并发送GPS位置
    if (navigator.geolocation) {
      try {
        const position = await new Promise<GeolocationPosition>((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, {
            timeout: 2000, // 2秒超时，避免阻塞推荐请求
            maximumAge: 300000 // 5分钟内的位置缓存
          });
        });
        params.latitude = position.coords.latitude;
        params.longitude = position.coords.longitude;
        // GPS位置已添加到请求参数
      } catch (geoError) {
        // 位置获取失败不影响推荐请求
        // 静默处理地理位置获取错误
      }
    }
    
    const response = await api.get('/recommendations', { params });
    return response.data;
  } catch (error: any) {
    logger.error('获取推荐失败:', error);
    throw error;
  }
}

/**
 * 获取任务匹配分数
 * @param taskId 任务ID
 */
export async function getTaskMatchScore(taskId: number) {
  try {
    const response = await api.get(`/tasks/${taskId}/match-score`);
    return response.data;
  } catch (error: any) {
    logger.error('获取匹配分数失败:', error);
    throw error;
  }
}

/**
 * 记录用户任务交互行为
 * @param taskId 任务ID
 * @param interactionType 交互类型：view, click, apply, skip
 * @param durationSeconds 浏览时长（秒），仅用于view类型
 * @param deviceType 设备类型：mobile, desktop, tablet（可选，不提供则自动检测）
 * @param isRecommended 是否为推荐任务
 * @param metadata 额外元数据（可选）
 */
export async function recordTaskInteraction(
  taskId: number,
  interactionType: 'view' | 'click' | 'apply' | 'skip',
  durationSeconds?: number,
  deviceType?: string,
  isRecommended?: boolean,
  metadata?: Record<string, any>
) {
  try {
    // 如果没有提供设备类型，自动检测
    if (!deviceType) {
      const { getDeviceType } = await import('./utils/deviceDetector');
      deviceType = getDeviceType();
    }
    
    // 构建请求数据
    const requestData: any = {
      interaction_type: interactionType,
      device_type: deviceType,
      is_recommended: isRecommended || false
    };
    
    if (durationSeconds !== undefined) {
      requestData.duration_seconds = durationSeconds;
    }
    
    // 添加设备详细信息到metadata
    if (!metadata) {
      metadata = {};
    }
    
    // 获取完整设备信息
    try {
      const { getDeviceInfo } = await import('./utils/deviceDetector');
      const deviceInfo = getDeviceInfo();
      metadata.device_info = {
        os: deviceInfo.os,
        os_version: deviceInfo.osVersion,
        browser: deviceInfo.browser,
        browser_version: deviceInfo.browserVersion,
        screen_width: deviceInfo.screenWidth,
        screen_height: deviceInfo.screenHeight,
        is_touch_device: deviceInfo.isTouchDevice
      };
    } catch (e) {
      // 如果获取设备信息失败，不影响主流程
      logger.warn('获取设备信息失败:', e);
    }
    
    if (Object.keys(metadata).length > 0) {
      requestData.metadata = metadata;
    }
    
    await api.post(`/tasks/${taskId}/interaction`, requestData);
  } catch (error: any) {
    // 静默失败，不影响用户体验
    logger.warn('记录交互失败:', error);
  }
}

/**
 * 提交推荐反馈
 * @param taskId 任务ID
 * @param feedbackType 反馈类型：like, dislike, not_interested, helpful
 * @param recommendationId 推荐批次ID（可选）
 */
export async function submitRecommendationFeedback(
  taskId: number,
  feedbackType: 'like' | 'dislike' | 'not_interested' | 'helpful',
  recommendationId?: string
) {
  try {
    await api.post(`/recommendations/${taskId}/feedback`, {
      feedback_type: feedbackType,
      recommendation_id: recommendationId
    });
  } catch (error: any) {
    // 静默失败，不影响用户体验
    logger.warn('提交推荐反馈失败:', error);
  }
}

// ==================== 任务列表API ====================

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
        throw error;
  }
}

/**
 * 获取当前用户信息（带缓存）
 * 使用cachedRequest包装，减少重复请求
 */
export async function fetchCurrentUser() {
  return cachedRequest(
    '/api/users/profile/me',
    async () => {
      const res = await api.get('/api/users/profile/me');
      return res.data;
    },
    CACHE_TTL.USER_INFO, // 5分钟缓存
    undefined,
    DEFAULT_DEBOUNCE_MS // 300ms防抖
  );
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
  return res; // 返回完整响应，以便访问 data 和其他属性
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
// 通过 notification_id 获取议价 token
export async function getNegotiationTokens(notificationId: number) {
  const res = await api.get(`/api/notifications/${notificationId}/negotiation-tokens`);
  return res.data;
}

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
  // 确保返回的是数组格式
  const data = res.data;
  if (Array.isArray(data)) {
    return data;
  }
  // 如果返回的不是数组，尝试从嵌套结构中提取
  if (data && Array.isArray(data.tasks)) {
    return data.tasks;
  }
  if (data && Array.isArray(data.data)) {
    return data.data;
  }
  // 如果都不匹配，返回空数组并记录错误
    return [];
}

// 完成任务
export async function completeTask(taskId: number, evidenceImages?: string[]) {
  const res = await api.post(`/api/users/tasks/${taskId}/complete`, {
    evidence_images: evidenceImages || []
  });
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

// 提交任务争议（未正确完成）
export async function createTaskDispute(taskId: number, reason: string) {
  const res = await api.post(`/api/tasks/${taskId}/dispute`, { reason });
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




// 客服相关API
export const assignCustomerService = async () => {
  const response = await api.post('/api/user/customer-service/assign');
  return response.data;
};


// 标记普通聊天的消息为已读
export const markChatMessagesAsRead = async (contactId: string) => {
  try {
    const response = await api.post(`/api/users/messages/mark-chat-read/${contactId}`);
    return response.data;
  } catch (error) {
        throw error;
  }
};

// 获取每个联系人的未读消息数量
export const getContactUnreadCounts = async () => {
  const response = await api.get('/api/users/messages/unread/by-contact');
  return response.data;
};



export const rateCustomerService = async (chatId: string, rating: number, comment?: string) => {
  const response = await api.post(`/api/user/customer-service/chats/${chatId}/rate`, { rating, comment });
  return response.data;
};

export const getMyCustomerServiceSessions = async () => {
  const res = await api.get('/api/user/customer-service/chats');
  return res.data;
};


// 管理后台相关API
// 获取公开的平台统计数据（仅用户总数）
export const getPublicStats = async () => {
  try {
    const res = await api.get('/api/stats');
    return res.data;
  } catch (error) {
        // 如果API不存在或失败，返回默认值
    return { total_users: 0 };
  }
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

// ==================== 任务达人功能 API ====================

// 公开 API - 获取任务达人列表（用于前端展示）
export const getPublicTaskExperts = async (category?: string, location?: string) => {
  const params: any = {};
  if (category) params.category = category;
  if (location && location !== 'all') params.location = location;
  const res = await api.get('/api/task-experts', { params });
  return res.data;
};

// ==================== 任务达人功能 API ====================

// 任务达人申请相关
export const applyToBeTaskExpert = async (applicationMessage?: string) => {
  const res = await api.post('/api/task-experts/apply', { application_message: applicationMessage });
  return res.data;
};

export const getMyTaskExpertApplication = async () => {
  const res = await api.get('/api/task-experts/my-application');
  return res.data;
};

// 任务达人信息
export const getTaskExpert = async (expertId: string) => {
  const res = await api.get(`/api/task-experts/${expertId}`);
  return res.data;
};

export const updateTaskExpertProfile = async (expertData: { expert_name?: string; bio?: string; avatar?: string }) => {
  const res = await api.put('/api/task-experts/me', expertData);
  return res.data;
};

// 服务菜单管理
export const createTaskExpertService = async (serviceData: {
  service_name: string;
  description: string;
  images?: string[];
  base_price: number;
  currency?: string;
  display_order?: number;
}) => {
  const res = await api.post('/api/task-experts/me/services', serviceData);
  return res.data;
};

export const getMyTaskExpertServices = async (params?: { status?: string; limit?: number; offset?: number }) => {
  const res = await api.get('/api/task-experts/me/services', { params });
  return res.data;
};

// 获取任务达人仪表盘统计数据
export const getExpertDashboardStats = async () => {
  const res = await api.get('/api/task-experts/me/dashboard/stats');
  return res.data;
};

// 获取任务达人时刻表数据
export const getExpertSchedule = async (params?: { start_date?: string; end_date?: string }) => {
  const res = await api.get('/api/task-experts/me/schedule', { params });
  return res.data;
};

export const updateTaskExpertService = async (serviceId: number, serviceData: {
  service_name?: string;
  description?: string;
  images?: string[];
  base_price?: number;
  currency?: string;
  status?: string;
  display_order?: number;
}) => {
  const res = await api.put(`/api/task-experts/me/services/${serviceId}`, serviceData);
  return res.data;
};

export const deleteTaskExpertService = async (serviceId: number) => {
  const res = await api.delete(`/api/task-experts/me/services/${serviceId}`);
  return res.data;
};

// 服务时间段管理
export const createServiceTimeSlot = async (serviceId: number, timeSlotData: {
  slot_date: string;
  start_time: string;
  end_time: string;
  price_per_participant: number;
  max_participants: number;
}) => {
  const res = await api.post(`/api/task-experts/me/services/${serviceId}/time-slots`, timeSlotData);
  return res.data;
};

export const getServiceTimeSlots = async (serviceId: number, params?: {
  start_date?: string;
  end_date?: string;
}) => {
  const res = await api.get(`/api/task-experts/me/services/${serviceId}/time-slots`, { params });
  return res.data;
};

export const updateServiceTimeSlot = async (serviceId: number, timeSlotId: number, timeSlotData: {
  price_per_participant?: number;
  max_participants?: number;
  is_available?: boolean;
}) => {
  const res = await api.put(`/api/task-experts/me/services/${serviceId}/time-slots/${timeSlotId}`, timeSlotData);
  return res.data;
};

export const deleteServiceTimeSlot = async (serviceId: number, timeSlotId: number) => {
  const res = await api.delete(`/api/task-experts/me/services/${serviceId}/time-slots/${timeSlotId}`);
  return res.data;
};

export const batchCreateServiceTimeSlots = async (serviceId: number, params: {
  start_date: string;
  end_date: string;
  price_per_participant: number;
}) => {
  const res = await api.post(`/api/task-experts/me/services/${serviceId}/time-slots/batch-create`, null, { params });
  return res.data;
};

export const deleteTimeSlotsByDate = async (serviceId: number, targetDate: string) => {
  const res = await api.delete(`/api/task-experts/me/services/${serviceId}/time-slots/by-date`, {
    params: { target_date: targetDate }
  });
  return res.data;
};

// 关门日期管理
export const createClosedDate = async (closedDateData: { closed_date: string; reason?: string }) => {
  const res = await api.post('/api/task-experts/me/closed-dates', closedDateData);
  return res.data;
};

export const getClosedDates = async (params?: { start_date?: string; end_date?: string }) => {
  const res = await api.get('/api/task-experts/me/closed-dates', { params });
  return res.data;
};

export const deleteClosedDate = async (closedDateId: number) => {
  const res = await api.delete(`/api/task-experts/me/closed-dates/${closedDateId}`);
  return res.data;
};

export const deleteClosedDateByDate = async (targetDate: string) => {
  const res = await api.delete('/api/task-experts/me/closed-dates/by-date', {
    params: { target_date: targetDate }
  });
  return res.data;
};

export const getTaskExpertServices = async (expertId: string, status?: string) => {
  const params = status ? { status } : {};
  const res = await api.get(`/api/task-experts/${expertId}/services`, { params });
  return res.data;
};

export const getTaskExpertServiceDetail = async (serviceId: number) => {
  const res = await api.get(`/api/task-experts/services/${serviceId}`);
  return res.data;
};

// 获取服务时间段列表（公开接口）
export const getServiceTimeSlotsPublic = async (serviceId: number, params?: {
  start_date?: string;
  end_date?: string;
}) => {
  const res = await api.get(`/api/task-experts/services/${serviceId}/time-slots`, { params });
  return res.data;
};

// 服务申请相关
export const applyForService = async (serviceId: number, applicationData: {
  application_message?: string;
  negotiated_price?: number;
  currency?: string;
  deadline?: string;  // ISO 格式的日期时间字符串
  is_flexible?: number;  // 1=灵活，无截至日期；0=有截至日期
  time_slot_id?: number;  // 选择的时间段ID
}) => {
  const res = await api.post(`/api/task-experts/services/${serviceId}/apply`, applicationData);
  return res.data;
};

export const getMyServiceApplications = async (params?: { status?: string; limit?: number; offset?: number }) => {
  const res = await api.get('/api/users/me/service-applications', { params });
  return res.data;
};

export const respondToCounterOffer = async (applicationId: number, accept: boolean) => {
  const res = await api.post(`/api/users/me/service-applications/${applicationId}/respond-counter-offer`, { accept });
  return res.data;
};

export const cancelServiceApplication = async (applicationId: number) => {
  const res = await api.post(`/api/users/me/service-applications/${applicationId}/cancel`);
  return res.data;
};

// 任务达人申请管理
export const getMyTaskExpertApplications = async (params?: { status?: string; service_id?: number; limit?: number; offset?: number }) => {
  const res = await api.get('/api/task-experts/me/applications', { params });
  return res.data;
};


export const counterOfferServiceApplication = async (applicationId: number, counterData: {
  counter_price: number;
  message?: string;
}) => {
  const res = await api.post(`/api/task-experts/applications/${applicationId}/counter-offer`, counterData);
  return res.data;
};

export const approveServiceApplication = async (applicationId: number) => {
  const res = await api.post(`/api/task-experts/applications/${applicationId}/approve`);
  return res.data;
};

export const rejectServiceApplication = async (applicationId: number, rejectReason?: string) => {
  const res = await api.post(`/api/task-experts/applications/${applicationId}/reject`, { reject_reason: rejectReason });
  return res.data;
};

// 任务达人信息修改请求
export const submitProfileUpdateRequest = async (data: { expert_name?: string; bio?: string; avatar?: string }) => {
  const res = await api.post('/api/task-experts/me/profile-update-request', data);
  return res.data;
};

export const getMyProfileUpdateRequest = async () => {
  const res = await api.get('/api/task-experts/me/profile-update-request');
  return res.data;
};


// 翻译API - 翻译单个文本
export const translateText = async (
  text: string,
  targetLanguage: string,
  sourceLanguage?: string
) => {
  try {
    const res = await api.post('/api/translate', {
      text,
      target_language: targetLanguage,
      ...(sourceLanguage && { source_language: sourceLanguage })
    });
    return res.data;
  } catch (error: any) {
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

// 任务翻译API - 获取任务翻译（如果存在）
export const getTaskTranslation = async (
  taskId: number,
  fieldType: 'title' | 'description',
  targetLanguage: string
) => {
  const res = await api.get(`/api/translate/task/${taskId}`, {
    params: {
      field_type: fieldType,
      target_language: targetLanguage
    }
  });
  return res.data;
};

// 任务翻译API - 翻译并保存任务内容
export const translateAndSaveTask = async (
  taskId: number,
  fieldType: 'title' | 'description',
  targetLanguage: string,
  sourceLanguage?: string
) => {
  const res = await api.post(`/api/translate/task/${taskId}`, {
    field_type: fieldType,
    target_language: targetLanguage,
    ...(sourceLanguage && { source_language: sourceLanguage })
  });
  return res.data;
};

// 任务翻译API - 批量获取任务翻译
export const getTaskTranslationsBatch = async (
  taskIds: number[],
  fieldType: 'title' | 'description',
  targetLanguage: string
) => {
  const res = await api.post('/api/translate/tasks/batch', {
    task_ids: taskIds,
    field_type: fieldType,
    target_language: targetLanguage
  });
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

// 获取 Stripe Connect 账户交易记录
export const getStripeAccountTransactions = async (params?: {
  limit?: number;
  starting_after?: string;
}) => {
  const res = await api.get('/api/stripe/connect/account/transactions', { params });
  return res.data;
};

// 获取 Stripe Connect 账户余额
export const getStripeAccountBalance = async () => {
  const res = await api.get('/api/stripe/connect/account/balance');
  return res.data;
};

// 获取支付历史记录
export const getPaymentHistory = async (params?: {
  skip?: number;
  limit?: number;
  task_id?: number;
  status?: string;
}) => {
  const res = await api.get('/api/coupon-points/payment-history', { params });
  return res.data;
};

// ===========================================
// 多人任务相关API
// ===========================================


// 任务达人：创建活动（新API）
export const createExpertActivity = async (activityData: {
  title: string;
  description: string;
  deadline?: string;
  location: string;
  task_type: string;
  expert_service_id: number;
  max_participants: number;
  min_participants: number;
  reward_type: 'cash' | 'points' | 'both';
  original_price_per_participant?: number;
  discount_percentage?: number;
  discounted_price_per_participant?: number;
  currency?: string;
  points_reward?: number;
  completion_rule: 'all' | 'min';
  reward_distribution: 'equal' | 'custom';
  images?: string[];
  is_public?: boolean;
  // 奖励申请者相关字段
  reward_applicants?: boolean;
  applicant_reward_amount?: number;
  applicant_points_reward?: number;
  // 时间段选择相关字段
  time_slot_selection_mode?: 'fixed' | 'recurring_daily' | 'recurring_weekly';
  selected_time_slot_ids?: number[];
  recurring_daily_time_ranges?: Array<{start: string, end: string}>;
  recurring_weekly_weekdays?: number[];
  recurring_weekly_time_ranges?: Array<{start: string, end: string}>;
  auto_add_new_slots?: boolean;
  activity_end_date?: string;
}) => {
  const res = await api.post('/api/expert/activities', activityData);
  return res.data;
};

// 任务达人：创建多人任务（保留向后兼容）
export const createExpertMultiParticipantTask = async (taskData: {
  title: string;
  description: string;
  deadline?: string;
  location: string;
  task_type: string;
  expert_service_id: number;
  max_participants: number;
  min_participants: number;
  reward_type: 'cash' | 'points' | 'both';
  reward?: number;
  points_reward?: number;
  completion_rule: 'all' | 'any';
  reward_distribution: 'equal' | 'custom';
  auto_accept?: boolean;
  is_fixed_time_slot?: boolean;
  time_slot_duration_minutes?: number;
  time_slot_start_time?: string;
  time_slot_end_time?: string;
  participants_per_slot?: number;
  original_price_per_participant?: number;
  discount_percentage?: number;
  discounted_price_per_participant?: number;
  images?: string[];
  // 奖励申请者相关字段
  reward_applicants?: boolean;
  applicant_reward_amount?: number;
  applicant_points_reward?: number;
  // 时间段选择相关字段
  time_slot_selection_mode?: 'fixed' | 'recurring_daily' | 'recurring_weekly';
  selected_time_slot_ids?: number[];
  recurring_daily_time_ranges?: Array<{start: string, end: string}>;
  recurring_weekly_weekdays?: number[];
  recurring_weekly_time_ranges?: Array<{start: string, end: string}>;
  auto_add_new_slots?: boolean;
  activity_end_date?: string;
}) => {
  // 转换为新的活动API格式
  const activityData = {
    title: taskData.title,
    description: taskData.description,
    deadline: taskData.deadline,
    location: taskData.location,
    task_type: taskData.task_type,
    expert_service_id: taskData.expert_service_id,
    max_participants: taskData.max_participants,
    min_participants: taskData.min_participants,
    reward_type: taskData.reward_type,
    original_price_per_participant: taskData.original_price_per_participant,
    discount_percentage: taskData.discount_percentage,
    discounted_price_per_participant: taskData.discounted_price_per_participant || (taskData.original_price_per_participant && taskData.discount_percentage
      ? taskData.original_price_per_participant * (1 - taskData.discount_percentage / 100)
      : taskData.original_price_per_participant),
    currency: 'GBP',
    points_reward: taskData.points_reward,
    completion_rule: (taskData.completion_rule === 'any' ? 'min' : 'all') as 'all' | 'min',
    reward_distribution: taskData.reward_distribution,
    images: taskData.images,
    is_public: true,
    // 奖励申请者相关字段
    reward_applicants: taskData.reward_applicants || false,
    applicant_reward_amount: taskData.applicant_reward_amount,
    applicant_points_reward: taskData.applicant_points_reward,
    // 时间段选择相关字段
    time_slot_selection_mode: taskData.time_slot_selection_mode,
    selected_time_slot_ids: taskData.selected_time_slot_ids,
    recurring_daily_time_ranges: taskData.recurring_daily_time_ranges,
    recurring_weekly_weekdays: taskData.recurring_weekly_weekdays,
    recurring_weekly_time_ranges: taskData.recurring_weekly_time_ranges,
    auto_add_new_slots: taskData.auto_add_new_slots,
    activity_end_date: taskData.activity_end_date,
  };
  return createExpertActivity(activityData);
};

// 用户：申请参与活动（新API）
export const applyToActivity = async (
  activityId: number,
  data: {
    idempotency_key: string;
    time_slot_id?: number;
    preferred_deadline?: string;
    is_flexible_time?: boolean;
    is_multi_participant?: boolean;
    max_participants?: number;
    min_participants?: number;
  }
) => {
  const res = await api.post(`/api/activities/${activityId}/apply`, data);
  return res.data;
};

// 用户：申请参与多人任务（保留向后兼容）
export const applyToMultiParticipantTask = async (
  taskId: string | number,
  data: {
    idempotency_key: string;
    time_slot_id?: number;
    preferred_deadline?: string;
    is_flexible_time?: boolean;
  }
) => {
  const res = await api.post(`/api/tasks/${taskId}/apply`, data);
  return res.data;
};

// 获取活动列表
export const getActivities = async (params?: {
  expert_id?: string;
  status?: string;
  limit?: number;
  offset?: number;
}) => {
  const res = await api.get('/api/activities', { params });
  return res.data;
};

// 获取活动详情
export const getActivityDetail = async (activityId: number) => {
  const res = await api.get(`/api/activities/${activityId}`);
  return res.data;
};

// 删除活动（任务达人）
export const deleteActivity = async (activityId: number) => {
  const res = await api.delete(`/api/expert/activities/${activityId}`);
  return res.data;
};

// 获取任务参与者列表
export const getTaskParticipants = async (taskId: string | number) => {
  const res = await api.get(`/api/tasks/${taskId}/participants`);
  return res.data;
};

// 用户：提交任务完成
export const completeMultiParticipantTask = async (
  taskId: string | number,
  data: {
    idempotency_key: string;
    completion_proof?: string;
  }
) => {
  const res = await api.post(`/api/tasks/${taskId}/participants/me/complete`, data);
  return res.data;
};

// 用户：申请退出任务
export const requestExitFromTask = async (
  taskId: string | number,
  data: {
    idempotency_key: string;
    reason?: string;
  }
) => {
  const res = await api.post(`/api/tasks/${taskId}/participants/me/exit-request`, data);
  return res.data;
};

// 开始任务（支持任务达人和管理员，但管理员功能已移至子域名）
export const startMultiParticipantTask = async (taskId: string | number, isAdmin: boolean = false) => {
  // 注意：管理员功能已移至 admin.link2ur.com，这里只支持任务达人
  if (isAdmin) {
    logger.warn('管理员功能已移至 admin.link2ur.com，请使用管理员子域名');
    throw new Error('管理员功能已移至管理员子域名');
  }
  const res = await api.post(`/api/expert/tasks/${taskId}/start`);
  return res.data;
};

// 批准参与者申请（支持任务达人和管理员，但管理员功能已移至子域名）
export const approveParticipant = async (
  taskId: string | number,
  participantId: number,
  isAdmin: boolean = false
) => {
  // 注意：管理员功能已移至 admin.link2ur.com，这里只支持任务达人
  if (isAdmin) {
    logger.warn('管理员功能已移至 admin.link2ur.com，请使用管理员子域名');
    throw new Error('管理员功能已移至管理员子域名');
  }
  const res = await api.post(`/api/expert/tasks/${taskId}/participants/${participantId}/approve`);
  return res.data;
};

// 拒绝参与者申请（支持任务达人和管理员，但管理员功能已移至子域名）
export const rejectParticipant = async (
  taskId: string | number,
  participantId: number,
  isAdmin: boolean = false
) => {
  // 注意：管理员功能已移至 admin.link2ur.com，这里只支持任务达人
  if (isAdmin) {
    logger.warn('管理员功能已移至 admin.link2ur.com，请使用管理员子域名');
    throw new Error('管理员功能已移至管理员子域名');
  }
  const res = await api.post(`/api/expert/tasks/${taskId}/participants/${participantId}/reject`);
  return res.data;
};

// 批准退出申请（支持任务达人和管理员，但管理员功能已移至子域名）
export const approveExitRequest = async (
  taskId: string | number,
  participantId: number,
  isAdmin: boolean = false
) => {
  // 注意：管理员功能已移至 admin.link2ur.com，这里只支持任务达人
  if (isAdmin) {
    logger.warn('管理员功能已移至 admin.link2ur.com，请使用管理员子域名');
    throw new Error('管理员功能已移至管理员子域名');
  }
  const res = await api.post(`/api/expert/tasks/${taskId}/participants/${participantId}/exit/approve`);
  return res.data;
};

// 拒绝退出申请（支持任务达人和管理员，但管理员功能已移至子域名）
export const rejectExitRequest = async (
  taskId: string | number,
  participantId: number,
  isAdmin: boolean = false
) => {
  // 注意：管理员功能已移至 admin.link2ur.com，这里只支持任务达人
  if (isAdmin) {
    logger.warn('管理员功能已移至 admin.link2ur.com，请使用管理员子域名');
    throw new Error('管理员功能已移至管理员子域名');
  }
  const res = await api.post(`/api/expert/tasks/${taskId}/participants/${participantId}/exit/reject`);
  return res.data;
};

// 完成任务并分配奖励（平均分配）- 仅支持任务达人，管理员功能已移至子域名
export const completeTaskAndDistributeRewardsEqual = async (
  taskId: string | number,
  data: {
    idempotency_key: string;
  }
) => {
  // 注意：管理员功能已移至 admin.link2ur.com，这里只支持任务达人
  const res = await api.post(`/api/expert/tasks/${taskId}/complete`, data);
  return res.data;
};


// ==================== 论坛 API ====================

// 板块相关
// 注意：应使用 getVisibleForums 获取用户可见的板块列表（包含权限控制）
// getForumCategories 仅用于管理员查看全部板块
export const getVisibleForums = async (includeAll: boolean = false, viewAs?: string, includeLatestPost: boolean = true) => {
  const res = await api.get('/api/forum/forums/visible', {
    params: { 
      include_all: includeAll,
      include_latest_post: includeLatestPost,
      ...(viewAs && { view_as: viewAs })
    }
  });
  return res.data;
};

// 获取所有板块（管理员专用，已废弃，建议使用 getVisibleForums(includeAll=true)）
export const getForumCategories = async (includeLatestPost: boolean = false) => {
  const res = await api.get('/api/forum/categories', {
    params: { include_latest_post: includeLatestPost }
  });
  return res.data;
};

export const getForumCategory = async (categoryId: number) => {
  const res = await api.get(`/api/forum/categories/${categoryId}`);
  return res.data;
};


// 获取我的板块申请列表（普通用户）
export const getMyCategoryRequests = async (
  page: number = 1,
  pageSize: number = 20,
  status?: 'pending' | 'approved' | 'rejected'
) => {
  const params: any = { page, page_size: pageSize };
  if (status) params.status = status;
  const res = await api.get('/api/forum/categories/requests/my', { params });
  return res.data;
};

// 帖子相关
export const getForumPosts = async (params: {
  category_id?: number;
  page?: number;
  page_size?: number;
  sort?: 'latest' | 'last_reply' | 'hot' | 'replies' | 'likes';
  q?: string;
}) => {
  const res = await api.get('/api/forum/posts', { params });
  return res.data;
};

export const getForumPost = async (postId: number) => {
  const res = await api.get(`/api/forum/posts/${postId}`);
  return res.data;
};

export const createForumPost = async (data: {
  title: string;
  content: string;
  category_id: number;
}) => {
  const token = await getCSRFToken();
  const res = await api.post('/api/forum/posts', data, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const updateForumPost = async (postId: number, data: {
  title?: string;
  content?: string;
  category_id?: number;
}) => {
  const token = await getCSRFToken();
  const res = await api.put(`/api/forum/posts/${postId}`, data, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const deleteForumPost = async (postId: number) => {
  const token = await getCSRFToken();
  const res = await api.delete(`/api/forum/posts/${postId}`, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const incrementPostViewCount = async (postId: number) => {
  const res = await api.post(`/api/forum/posts/${postId}/view`);
  return res.data;
};

// 回复相关
export const getForumReplies = async (postId: number, params?: {
  page?: number;
  page_size?: number;
}) => {
  const res = await api.get(`/api/forum/posts/${postId}/replies`, { params });
  return res.data;
};

export const createForumReply = async (postId: number, data: {
  content: string;
  parent_reply_id?: number;
}) => {
  const token = await getCSRFToken();
  const res = await api.post(`/api/forum/posts/${postId}/replies`, data, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const updateForumReply = async (replyId: number, data: {
  content: string;
}) => {
  const token = await getCSRFToken();
  const res = await api.put(`/api/forum/replies/${replyId}`, data, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const deleteForumReply = async (replyId: number) => {
  const token = await getCSRFToken();
  const res = await api.delete(`/api/forum/replies/${replyId}`, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

// 点赞/收藏相关
export const toggleForumLike = async (targetType: 'post' | 'reply', targetId: number) => {
  const token = await getCSRFToken();
  const res = await api.post('/api/forum/likes', {
    target_type: targetType,
    target_id: targetId
  }, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const toggleForumFavorite = async (postId: number) => {
  const token = await getCSRFToken();
  const res = await api.post('/api/forum/favorites', {
    post_id: postId
  }, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const getMyForumFavorites = async (params?: {
  page?: number;
  page_size?: number;
}) => {
  const res = await api.get('/api/forum/my/favorites', { params });
  return res.data;
};

// 搜索相关
export const searchForumPosts = async (params: {
  q: string;
  category_id?: number;
  page?: number;
  page_size?: number;
}) => {
  const res = await api.get('/api/forum/search', { params });
  return res.data;
};

// 通知相关
export const getForumNotifications = async (params?: {
  page?: number;
  page_size?: number;
  is_read?: boolean;
}) => {
  const token = await getCSRFToken();
  const res = await api.get('/api/forum/notifications', {
    params,
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const markForumNotificationRead = async (notificationId: number) => {
  const token = await getCSRFToken();
  const res = await api.put(`/api/forum/notifications/${notificationId}/read`, {}, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const markAllForumNotificationsRead = async () => {
  const token = await getCSRFToken();
  const res = await api.put('/api/forum/notifications/read-all', {}, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const getForumUnreadNotificationCount = async () => {
  const token = await getCSRFToken();
  const res = await api.get('/api/forum/notifications/unread-count', {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

// 举报相关
export const createForumReport = async (data: {
  target_type: 'post' | 'reply';
  target_id: number;
  reason: string;
  description?: string;
}) => {
  const token = await getCSRFToken();
  const res = await api.post('/api/forum/reports', data, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

// 我的内容相关
export const getMyForumPosts = async (params?: {
  page?: number;
  page_size?: number;
}) => {
  const token = await getCSRFToken();
  const res = await api.get('/api/forum/my/posts', {
    params,
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const getMyForumReplies = async (params?: {
  page?: number;
  page_size?: number;
}) => {
  const token = await getCSRFToken();
  const res = await api.get('/api/forum/my/replies', {
    params,
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

// 获取用户最热门的帖子
export const getUserHotPosts = async (userId: string, limit: number = 3) => {
  const res = await api.get(`/api/forum/users/${userId}/hot-posts`, {
    params: { limit }
  });
  return res.data;
};

export const getMyForumLikes = async (params?: {
  page?: number;
  page_size?: number;
}) => {
  const token = await getCSRFToken();
  const res = await api.get('/api/forum/my/likes', {
    params,
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

// 热门帖子
export const getHotForumPosts = async (params?: {
  category_id?: number;
  limit?: number;
}) => {
  const res = await api.get('/api/forum/hot-posts', { params });
  return res.data;
};

// 排行榜
export const getForumLeaderboard = async (type: 'posts' | 'favorites' | 'likes', params?: {
  period?: 'all' | 'today' | 'week' | 'month';
  limit?: number;
}) => {
  const res = await api.get(`/api/forum/leaderboard/${type}`, { params });
  return res.data;
};

// 用户统计
export const getUserForumStats = async (userId: string) => {
  const res = await api.get(`/api/forum/users/${userId}/stats`);
  return res.data;
};

// 板块统计
export const getCategoryForumStats = async (categoryId: number) => {
  const res = await api.get(`/api/forum/categories/${categoryId}/stats`);
  return res.data;
};


// ==================== 自定义排行榜API ====================

export const applyCustomLeaderboard = async (data: {
  name: string;
  location: string;
  description?: string;
  cover_image?: string;
  application_reason?: string;
}) => {
  const token = await getCSRFToken();
  const res = await api.post('/api/custom-leaderboards/apply', data, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const getCustomLeaderboards = async (params?: {
  location?: string;
  status?: string;
  keyword?: string;
  sort?: 'latest' | 'hot' | 'votes' | 'items';
  limit?: number;
  offset?: number;
}) => {
  const res = await api.get('/api/custom-leaderboards', { params });
  return res.data;
};

// 论坛板块收藏
export const toggleForumCategoryFavorite = async (categoryId: number) => {
  const res = await api.post(`/api/forum/categories/${categoryId}/favorite`);
  return res.data;
};

export const getForumCategoryFavoriteStatus = async (categoryId: number) => {
  const res = await api.get(`/api/forum/categories/${categoryId}/favorite/status`);
  return res.data;
};

// 排行榜收藏
export const toggleCustomLeaderboardFavorite = async (leaderboardId: number) => {
  const res = await api.post(`/api/custom-leaderboards/${leaderboardId}/favorite`);
  return res.data;
};

export const getCustomLeaderboardFavoriteStatus = async (leaderboardId: number) => {
  const res = await api.get(`/api/custom-leaderboards/${leaderboardId}/favorite/status`);
  return res.data;
};

export const getCustomLeaderboardDetail = async (leaderboardId: number) => {
  const res = await api.get(`/api/custom-leaderboards/${leaderboardId}`);
  return res.data;
};

export const submitLeaderboardItem = async (data: {
  leaderboard_id: number;
  name: string;
  description?: string;
  address?: string;
  phone?: string;
  website?: string;
  images?: string[];
}) => {
  const token = await getCSRFToken();
  const res = await api.post('/api/custom-leaderboards/items', data, {
    headers: { 'X-CSRF-Token': token }
  });
  return res.data;
};

export const getLeaderboardItems = async (
  leaderboardId: number,
  params?: {
    sort?: 'vote_score' | 'net_votes' | 'upvotes' | 'created_at';
    limit?: number;
    offset?: number;
  }
) => {
  const res = await api.get(`/api/custom-leaderboards/${leaderboardId}/items`, { params });
  return res.data;
};

export const voteLeaderboardItem = async (
  itemId: number,
  voteType: 'upvote' | 'downvote' | 'remove',
  comment?: string,
  isAnonymous: boolean = false
) => {
  const token = await getCSRFToken();
  const params: any = { vote_type: voteType };
  if (comment) {
    params.comment = comment;
  }
  if (isAnonymous) {
    params.is_anonymous = true;
  }
  const res = await api.post(
    `/api/custom-leaderboards/items/${itemId}/vote`,
    null,
    {
      params,
      headers: { 'X-CSRF-Token': token }
    }
  );
  return res.data;
};

export const getLeaderboardItemDetail = async (itemId: number) => {
  const res = await api.get(`/api/custom-leaderboards/items/${itemId}`);
  return res.data;
};

export const getLeaderboardItemVotes = async (
  itemId: number,
  params?: {
    limit?: number;
    offset?: number;
  }
) => {
  const res = await api.get(`/api/custom-leaderboards/items/${itemId}/votes`, { params });
  return res.data;
};

export const likeVoteComment = async (voteId: number) => {
  const token = await getCSRFToken();
  const res = await api.post(
    `/api/custom-leaderboards/votes/${voteId}/like`,
    null,
    {
      headers: { 'X-CSRF-Token': token }
    }
  );
  return res.data;
};

export const reportLeaderboard = async (leaderboardId: number, data: { reason: string; description?: string }) => {
  const token = await getCSRFToken();
  const res = await api.post(
    `/api/custom-leaderboards/${leaderboardId}/report`,
    data,
    {
      headers: { 'X-CSRF-Token': token }
    }
  );
  return res.data;
};

export const reportLeaderboardItem = async (itemId: number, data: { reason: string; description?: string }) => {
  const token = await getCSRFToken();
  const res = await api.post(
    `/api/custom-leaderboards/items/${itemId}/report`,
    data,
    {
      headers: { 'X-CSRF-Token': token }
    }
  );
  return res.data;
};


// ==================== 学生认证 API ====================

// 查询认证状态
export const getStudentVerificationStatus = async () => {
  const res = await api.get('/api/student-verification/status');
  return res.data;
};

// 提交认证申请
export const submitStudentVerification = async (email: string) => {
  const res = await api.post('/api/student-verification/submit', null, {
    params: { email }
  });
  return res.data;
};

// 验证邮箱（通过token）
export const verifyStudentEmail = async (token: string) => {
  const res = await api.get(`/api/student-verification/verify/${token}`);
  return res.data;
};

// 申请续期
export const renewStudentVerification = async (email: string) => {
  const res = await api.post('/api/student-verification/renew', null, {
    params: { email }
  });
  return res.data;
};

// 更换邮箱
export const changeStudentEmail = async (newEmail: string) => {
  const res = await api.post('/api/student-verification/change-email', null, {
    params: { new_email: newEmail }
  });
  return res.data;
};

// 获取大学列表
export const getUniversities = async (params?: {
  search?: string;
  page?: number;
  page_size?: number;
}) => {
  const res = await api.get('/api/student-verification/universities', { params });
  return res.data;
};

export const getUserStudentVerificationStatus = async (userId: string) => {
  const res = await api.get(`/api/student-verification/user/${userId}/status`);
  return res.data;
};

// ==================== Banner 广告管理 API ====================

// 获取 Banner 列表（公开接口）
export const getBanners = async () => {
  const res = await api.get('/api/banners');
  return res.data;
};


export default api; 