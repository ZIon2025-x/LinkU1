import axios from 'axios';
import { API_BASE_URL } from './config';

// 创建 axios 实例
const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  timeout: 15000,
  headers: {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache'
  }
});

// CSRF token 管理
let csrfToken: string | null = null;

// 获取 CSRF token
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
    const response = await api.get('/api/csrf/token');
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

// 清除 CSRF token
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
    const isLoginRequest = url.includes('/login');
    
    if (!isLoginRequest) {
      try {
        const token = await getCSRFToken();
        config.headers['X-CSRF-Token'] = token;
      } catch (error) {
        return Promise.reject(new Error('获取 CSRF token 失败，请刷新页面重试'));
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
        '/api/auth/admin/login',
        '/api/auth/admin/refresh',
        '/api/auth/admin/verify-code',
        '/api/auth/admin/send-verification-code',
        '/api/csrf/token'
      ];
      
      if (originalRequest && !originalRequest._retried && !skipRefreshApis.some(skipApi => originalRequest.url?.includes(skipApi))) {
        originalRequest._retried = true;

        if (isRefreshing && refreshPromise) {
          try {
            await refreshPromise;
            return api.request(originalRequest);
          } catch (refreshError) {
            if (window.location.pathname !== '/login') {
              window.location.href = '/login';
            }
            return Promise.reject(refreshError);
          }
        }
        
        isRefreshing = true;
        refreshPromise = api.post('/api/auth/admin/refresh');
        
        try {
          await refreshPromise;
          clearCSRFToken();
          isRefreshing = false;
          refreshPromise = null;
          return api.request(originalRequest);
        } catch (refreshError) {
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

// ==================== 认证相关 API ====================

export const adminLogin = async (loginData: { username: string; password: string }) => {
  const res = await api.post('/api/admin/login', loginData);
  return res.data;
};

const AUTH_COOKIE_NAMES = ['session', 'admin_session', 'csrf_token', 'refresh_token'];

function clearAuthCookies() {
  const domains = [window.location.hostname, `.${window.location.hostname}`];
  for (const name of AUTH_COOKIE_NAMES) {
    document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
    for (const domain of domains) {
      document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=${domain}`;
    }
  }
}

export const adminLogout = async () => {
  try {
    const res = await api.post('/api/auth/admin/logout');
    clearAuthCookies();
    clearCSRFToken();
    return res.data;
  } catch (error) {
    clearAuthCookies();
    clearCSRFToken();
    throw error;
  }
};

export const adminRefreshToken = async () => {
  const res = await api.post('/api/auth/admin/refresh');
  return res.data;
};

export const getAdminProfile = async () => {
  const res = await api.get('/api/auth/admin/profile');
  return res.data;
};

// ==================== 仪表盘 API ====================

export const getDashboardStats = async () => {
  const res = await api.get('/api/admin/dashboard/stats');
  return res.data;
};

// ==================== 管理员通知 API ====================

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

// ==================== 用户管理 API ====================

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

// ==================== 管理员管理 API ====================

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

// ==================== 客服管理 API ====================

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

// ==================== 通知管理 API ====================

export const sendAdminNotification = async (notification: {
  title: string;
  content: string;
  user_ids: string[];
  type?: string;
}) => {
  const res = await api.post('/api/admin/notifications/send', notification);
  return res.data;
};

export const notifyCustomerService = async (csId: number, message: string) => {
  const res = await api.post(`/api/admin/customer-service/${csId}/notify`, message);
  return res.data;
};

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

// ==================== 任务管理 API ====================

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

export const getTaskParticipants = async (taskId: number) => {
  const res = await api.get(`/api/tasks/${taskId}/participants`);
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

export const updateTaskPointsReward = async (taskId: number, pointsReward: number | null) => {
  const res = await api.put(`/api/admin/tasks/${taskId}/points-reward`, { points_reward: pointsReward });
  return res.data;
};

// ==================== 系统设置 API ====================

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
  vip_to_super_task_count_threshold: number;
  vip_to_super_rating_threshold: number;
  vip_to_super_completion_rate_threshold: number;
  vip_to_super_enabled: boolean;
}) => {
  const res = await api.put('/api/admin/system-settings', settings);
  return res.data;
};

export const clearCache = async () => {
  const res = await api.post('/api/cleanup/cleanup/cache');
  return res.data;
};

export const getPointsSettings = async () => {
  const res = await api.get('/api/admin/settings/points');
  return res.data;
};

export const updatePointsSettings = async (settings: {
  points_task_complete_bonus: number;
}) => {
  const res = await api.put('/api/admin/settings/points', settings);
  return res.data;
};

export const getCheckinSettings = async () => {
  const res = await api.get('/api/admin/checkin/settings');
  return res.data;
};

export const updateCheckinSettings = async (settings: {
  daily_base_points: number;
}) => {
  const res = await api.put('/api/admin/checkin/settings', settings);
  return res.data;
};

// ==================== 任务达人管理 API ====================

export const getTaskExperts = async (params?: {
  page?: number;
  size?: number;
  category?: string;
  is_active?: number;
}) => {
  const res = await api.get('/api/admin/task-experts', { params });
  return res.data;
};

export const getTaskExpertForAdmin = async (expertId: string) => {
  const res = await api.get(`/api/admin/task-expert/${expertId}`);
  return res.data;
};

export const createTaskExpert = async (expertData: any) => {
  const res = await api.post('/api/admin/task-expert', expertData);
  return res.data;
};

export const updateTaskExpert = async (expertId: string, expertData: any) => {
  const res = await api.put(`/api/admin/task-expert/${expertId}`, expertData);
  return res.data;
};

export const deleteTaskExpert = async (expertId: string) => {
  const res = await api.delete(`/api/admin/task-expert/${expertId}`);
  return res.data;
};

export const getExpertServicesAdmin = async (expertId: string) => {
  const res = await api.get(`/api/admin/task-expert/${expertId}/services`);
  return res.data;
};

/** 获取全部达人服务列表（分页），用于专家管理-服务管理 */
export const getAllExpertServicesAdmin = async (params?: { page?: number; limit?: number; expert_id?: string }) => {
  const res = await api.get('/api/admin/task-expert-services', { params });
  return res.data;
};

/** 获取全部达人活动列表（分页），用于专家管理-活动管理 */
export const getAllExpertActivitiesAdmin = async (params?: { page?: number; limit?: number; expert_id?: string; status_filter?: string }) => {
  const res = await api.get('/api/admin/task-expert-activities', { params });
  return res.data;
};

export const updateExpertServiceAdmin = async (expertId: string, serviceId: number, serviceData: any) => {
  const res = await api.put(`/api/admin/task-expert/${expertId}/services/${serviceId}`, serviceData);
  return res.data;
};

export const deleteExpertServiceAdmin = async (expertId: string, serviceId: number) => {
  const res = await api.delete(`/api/admin/task-expert/${expertId}/services/${serviceId}`);
  return res.data;
};

export const getExpertActivitiesAdmin = async (expertId: string) => {
  const res = await api.get(`/api/admin/task-expert/${expertId}/activities`);
  return res.data;
};

export const updateExpertActivityAdmin = async (expertId: string, activityId: number, activityData: any) => {
  const res = await api.put(`/api/admin/task-expert/${expertId}/activities/${activityId}`, activityData);
  return res.data;
};

export const deleteExpertActivityAdmin = async (expertId: string, activityId: number) => {
  const res = await api.delete(`/api/admin/task-expert/${expertId}/activities/${activityId}`);
  return res.data;
};

export const getTaskExpertApplications = async (params?: { status?: string; limit?: number; offset?: number }) => {
  const res = await api.get('/api/admin/task-expert-applications', { params });
  return res.data;
};

export const reviewTaskExpertApplication = async (applicationId: number, data: { action: 'approve' | 'reject'; review_comment?: string }) => {
  const res = await api.post(`/api/admin/task-expert-applications/${applicationId}/review`, data);
  return res.data;
};

export const createExpertFromApplication = async (applicationId: number) => {
  const res = await api.post(`/api/admin/task-expert-applications/${applicationId}/create-featured-expert`);
  return res.data;
};

export const getProfileUpdateRequests = async (params?: { status?: string; limit?: number; offset?: number }) => {
  const res = await api.get('/api/admin/task-expert-profile-update-requests', { params });
  return res.data;
};

export const reviewProfileUpdateRequest = async (requestId: number, data: { action: 'approve' | 'reject'; review_comment?: string }) => {
  const res = await api.post(`/api/admin/task-expert-profile-update-requests/${requestId}/review`, data);
  return res.data;
};

// ==================== 优惠券管理 API ====================

export interface CouponData {
  code?: string;
  name: string;
  description?: string;
  type: 'fixed_amount' | 'percentage';
  discount_value: number;
  min_amount?: number;
  max_discount?: number;
  currency?: string;
  total_quantity?: number;
  per_user_limit?: number;
  per_device_limit?: number;
  per_ip_limit?: number;
  can_combine?: boolean;
  combine_limit?: number;
  apply_order?: number;
  valid_from: string;
  valid_until: string;
  usage_conditions?: {
    locations?: string[];
    task_types?: string[];
    excluded_task_types?: string[];
    min_task_amount?: number;
    max_task_amount?: number;
  };
  /** 积分兑换所需积分（0表示不支持积分兑换） */
  points_required?: number;
  /** 适用场景列表（如 task_posting, task_accepting, expert_service, all） */
  applicable_scenarios?: string[];
  eligibility_type?: string;
  eligibility_value?: string;
  per_day_limit?: number;
  /** 每用户每月限领（兼容旧逻辑，与 per_user_limit_window + per_user_per_window_limit 二选一） */
  per_user_per_month_limit?: number;
  /** 限领周期：day | week | month | year */
  per_user_limit_window?: string;
  /** 每个周期内每用户限领次数 */
  per_user_per_window_limit?: number;
}

export const createCoupon = async (data: CouponData) => {
  const res = await api.post('/api/admin/coupons', data);
  return res.data;
};

export const getCoupons = async (params?: {
  page?: number;
  limit?: number;
  status?: 'active' | 'inactive' | 'expired';
}) => {
  const res = await api.get('/api/admin/coupons', { params });
  return res.data;
};

export const getCouponDetail = async (couponId: number) => {
  const res = await api.get(`/api/admin/coupons/${couponId}`);
  return res.data;
};

export const updateCoupon = async (couponId: number, data: {
  name?: string;
  description?: string;
  valid_until?: string;
  status?: 'active' | 'inactive';
  usage_conditions?: object;
  points_required?: number;
  applicable_scenarios?: string[];
  per_user_per_month_limit?: number;
  per_user_limit_window?: string;
  per_user_per_window_limit?: number;
  per_day_limit?: number;
  eligibility_type?: string;
  eligibility_value?: string;
}) => {
  const res = await api.put(`/api/admin/coupons/${couponId}`, data);
  return res.data;
};

export const deleteCoupon = async (couponId: number, force?: boolean) => {
  const res = await api.delete(`/api/admin/coupons/${couponId}`, { params: { force } });
  return res.data;
};

// ==================== 邀请码管理 API ====================

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

export const getInvitationCodes = async (params?: {
  page?: number;
  limit?: number;
  status?: 'active' | 'inactive';
}) => {
  const res = await api.get('/api/admin/invitation-codes', { params });
  return res.data;
};

export const getInvitationCodeDetail = async (invitationId: number) => {
  const res = await api.get(`/api/admin/invitation-codes/${invitationId}`);
  return res.data;
};

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

export const deleteInvitationCode = async (invitationId: number) => {
  const res = await api.delete(`/api/admin/invitation-codes/${invitationId}`);
  return res.data;
};

export const getInvitationCodeUsers = async (invitationId: number, params?: {
  page?: number;
  limit?: number;
}) => {
  const res = await api.get(`/api/admin/invitation-codes/${invitationId}/users`, { params });
  return res.data;
};

export const getInvitationCodeStatistics = async (invitationId: number) => {
  const res = await api.get(`/api/admin/invitation-codes/${invitationId}/statistics`);
  return res.data;
};

// ==================== 岗位管理 API ====================

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

export const updateJobPosition = async (positionId: number, position: any) => {
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

// ==================== 论坛管理 API ====================

export const getForumCategories = async (includeLatestPost: boolean = false) => {
  const res = await api.get('/api/forum/admin/categories');
  return res.data;
};

export const getForumCategory = async (categoryId: number) => {
  const res = await api.get(`/api/forum/categories/${categoryId}`);
  return res.data;
};

export const createForumCategory = async (category: {
  name: string;
  name_zh?: string;
  name_en?: string;
  description?: string;
  description_zh?: string;
  description_en?: string;
  icon?: string;
  sort_order?: number;
  is_visible?: boolean;
  is_admin_only?: boolean;
  type?: 'general' | 'root' | 'university';
  country?: string;
  university_code?: string;
}) => {
  const res = await api.post('/api/forum/categories', category);
  return res.data;
};

export const updateForumCategory = async (categoryId: number, category: {
  name?: string;
  name_zh?: string;
  name_en?: string;
  description?: string;
  description_zh?: string;
  description_en?: string;
  icon?: string;
  sort_order?: number;
  is_visible?: boolean;
  is_admin_only?: boolean;
  type?: 'general' | 'root' | 'university';
  country?: string;
  university_code?: string;
}) => {
  const res = await api.put(`/api/forum/categories/${categoryId}`, category);
  return res.data;
};

export const deleteForumCategory = async (categoryId: number) => {
  const res = await api.delete(`/api/forum/categories/${categoryId}`);
  return res.data;
};

export const getCategoryRequests = async (
  status?: 'pending' | 'approved' | 'rejected',
  page: number = 1,
  pageSize: number = 20,
  search?: string,
  sortBy: string = 'created_at',
  sortOrder: 'asc' | 'desc' = 'desc'
) => {
  const params: any = { page, page_size: pageSize, sort_by: sortBy, sort_order: sortOrder };
  if (status) params.status = status;
  if (search) params.search = search;
  const res = await api.get('/api/forum/categories/requests', { params });
  return res.data;
};

export const reviewCategoryRequest = async (requestId: number, action: 'approve' | 'reject', reviewComment?: string) => {
  const params: any = { action };
  if (reviewComment) {
    params.review_comment = reviewComment;
  }
  const res = await api.put(`/api/forum/categories/requests/${requestId}/review`, null, { params });
  return res.data;
};

export const getForumPosts = async (params: {
  category_id?: number;
  page?: number;
  page_size?: number;
  sort?: 'latest' | 'last_reply' | 'hot' | 'replies' | 'likes';
  q?: string;
  /** 管理员筛选：是否已删除 */
  is_deleted?: boolean;
  /** 管理员筛选：是否可见 */
  is_visible?: boolean;
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
  const res = await api.post('/api/forum/posts', data);
  return res.data;
};

export const updateForumPost = async (postId: number, data: {
  title?: string;
  content?: string;
  category_id?: number;
}) => {
  const res = await api.put(`/api/forum/posts/${postId}`, data);
  return res.data;
};

export const deleteForumPost = async (postId: number) => {
  const res = await api.delete(`/api/forum/posts/${postId}`);
  return res.data;
};

export const pinForumPost = async (postId: number) => {
  const res = await api.post(`/api/forum/posts/${postId}/pin`);
  return res.data;
};

export const unpinForumPost = async (postId: number) => {
  const res = await api.delete(`/api/forum/posts/${postId}/pin`);
  return res.data;
};

export const featureForumPost = async (postId: number) => {
  const res = await api.post(`/api/forum/posts/${postId}/feature`);
  return res.data;
};

export const unfeatureForumPost = async (postId: number) => {
  const res = await api.delete(`/api/forum/posts/${postId}/feature`);
  return res.data;
};

export const lockForumPost = async (postId: number) => {
  const res = await api.post(`/api/forum/posts/${postId}/lock`);
  return res.data;
};

export const unlockForumPost = async (postId: number) => {
  const res = await api.delete(`/api/forum/posts/${postId}/lock`);
  return res.data;
};

export const restoreForumPost = async (postId: number) => {
  const res = await api.post(`/api/forum/posts/${postId}/restore`);
  return res.data;
};

export const hideForumPost = async (postId: number) => {
  const res = await api.post(`/api/forum/posts/${postId}/hide`);
  return res.data;
};

export const unhideForumPost = async (postId: number) => {
  const res = await api.post(`/api/forum/posts/${postId}/unhide`);
  return res.data;
};

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
  const res = await api.post(`/api/forum/posts/${postId}/replies`, data);
  return res.data;
};

export const getForumReports = async (params?: {
  status_filter?: 'pending' | 'processed' | 'rejected';
  page?: number;
  page_size?: number;
}) => {
  const res = await api.get('/api/forum/reports', { params });
  return res.data;
};

export const processForumReport = async (reportId: number, data: {
  status: 'processed' | 'rejected';
  action?: string;
}) => {
  const res = await api.put(`/api/forum/admin/reports/${reportId}/process`, data);
  return res.data;
};

// ==================== 跳蚤市场管理 API ====================

export const getFleaMarketReports = async (params?: {
  status_filter?: 'pending' | 'reviewing' | 'resolved' | 'rejected';
  page?: number;
  page_size?: number;
}) => {
  const res = await api.get('/api/flea-market/admin/reports', { params });
  return res.data;
};

export const processFleaMarketReport = async (reportId: number, data: {
  status: 'resolved' | 'rejected';
  admin_comment?: string;
}) => {
  const res = await api.put(`/api/flea-market/admin/reports/${reportId}/process`, data);
  return res.data;
};

export const getFleaMarketItemsAdmin = async (params?: {
  page?: number;
  page_size?: number;
  category?: string;
  keyword?: string;
  status_filter?: string;
  seller_id?: string;
}) => {
  const res = await api.get('/api/flea-market/admin/items', { params });
  return res.data;
};

export const updateFleaMarketItemAdmin = async (itemId: string, data: {
  title?: string;
  description?: string;
  price?: number;
  images?: string[];
  location?: string;
  category?: string;
  status?: string;
}) => {
  const res = await api.put(`/api/flea-market/admin/items/${itemId}`, data);
  return res.data;
};

export const deleteFleaMarketItemAdmin = async (itemId: string) => {
  const res = await api.delete(`/api/flea-market/admin/items/${itemId}`);
  return res.data;
};

// ==================== 排行榜管理 API ====================

export const getLeaderboardVotesAdmin = async (params?: {
  item_id?: number;
  leaderboard_id?: number;
  is_anonymous?: boolean;
  keyword?: string;
  limit?: number;
  offset?: number;
}) => {
  const res = await api.get('/api/custom-leaderboards/admin/votes', { params });
  return res.data;
};

export const getCustomLeaderboardsAdmin = async (params?: {
  location?: string;
  status?: 'all' | 'active' | 'pending' | 'rejected';
  limit?: number;
  offset?: number;
}) => {
  const res = await api.get('/api/custom-leaderboards/admin/all', { params });
  return res.data;
};

export const reviewCustomLeaderboard = async (
  leaderboardId: number,
  action: 'approve' | 'reject',
  comment?: string
) => {
  const res = await api.post(
    `/api/custom-leaderboards/${leaderboardId}/review`,
    null,
    { params: { action, comment } }
  );
  return res.data;
};

export const updateLeaderboardAdmin = async (
  leaderboardId: number,
  data: {
    name?: string;
    name_zh?: string;
    name_en?: string;
    description?: string;
    description_zh?: string;
    description_en?: string;
    cover_image?: string;
    location?: string;
    status?: 'active' | 'pending' | 'rejected';
  }
) => {
  const res = await api.put(
    `/api/custom-leaderboards/admin/leaderboards/${leaderboardId}`,
    data
  );
  return res.data;
};

export const getLeaderboardItemsAdmin = async (params?: {
  leaderboard_id?: number;
  status?: 'all' | 'approved';
  keyword?: string;
  limit?: number;
  offset?: number;
}) => {
  const res = await api.get('/api/custom-leaderboards/admin/items', { params });
  return res.data;
};

export const deleteLeaderboardItemAdmin = async (itemId: number) => {
  const res = await api.delete(`/api/custom-leaderboards/admin/items/${itemId}`);
  return res.data;
};

export const createLeaderboardItemAdmin = async (data: {
  name: string;
  description?: string;
  image_url?: string;
  leaderboard_id: number;
}) => {
  const res = await api.post('/api/custom-leaderboards/admin/items', data);
  return res.data;
};

export const updateLeaderboardItemAdmin = async (itemId: number, data: {
  name?: string;
  description?: string;
  image_url?: string;
  status?: string;
}) => {
  const res = await api.put(`/api/custom-leaderboards/admin/items/${itemId}`, data);
  return res.data;
};

// ==================== Banner 管理 API ====================

export const getBannersAdmin = async (params?: {
  page?: number;
  limit?: number;
  is_active?: boolean;
}) => {
  const res = await api.get('/api/admin/banners', { params });
  return res.data;
};

export const getBannerDetailAdmin = async (bannerId: number) => {
  const res = await api.get(`/api/admin/banners/${bannerId}`);
  return res.data;
};

export const createBanner = async (data: {
  image_url: string;
  title: string;
  subtitle?: string;
  link_url?: string;
  link_type?: 'internal' | 'external';
  order?: number;
  is_active?: boolean;
}) => {
  const res = await api.post('/api/admin/banners', data);
  return res.data;
};

export const updateBanner = async (bannerId: number, data: {
  image_url?: string;
  title?: string;
  subtitle?: string;
  link_url?: string;
  link_type?: 'internal' | 'external';
  order?: number;
  is_active?: boolean;
}) => {
  const res = await api.put(`/api/admin/banners/${bannerId}`, data);
  return res.data;
};

export const deleteBanner = async (bannerId: number) => {
  const res = await api.delete(`/api/admin/banners/${bannerId}`);
  return res.data;
};

export const toggleBannerStatus = async (bannerId: number) => {
  const res = await api.patch(`/api/admin/banners/${bannerId}/toggle-status`);
  return res.data;
};

export const batchDeleteBanners = async (bannerIds: number[]) => {
  const res = await api.post('/api/admin/banners/batch-delete', bannerIds);
  return res.data;
};

export const batchUpdateBannerOrder = async (orderUpdates: Array<{ id: number; order: number }>) => {
  const res = await api.put('/api/admin/banners/batch-update-order', orderUpdates);
  return res.data;
};

export const uploadBannerImage = async (file: File, bannerId?: number) => {
  const formData = new FormData();
  formData.append('image', file);
  const params: any = {};
  if (bannerId) {
    params.banner_id = bannerId;
  }
  const res = await api.post('/api/admin/banners/upload-image', formData, {
    params,
    headers: { 'Content-Type': 'multipart/form-data' }
  });
  return res.data;
};

// ==================== 任务争议处理 API ====================

export async function getAdminTaskDisputes(params?: {
  skip?: number;
  limit?: number;
  status?: string;
  keyword?: string;
}) {
  const res = await api.get('/api/admin/task-disputes', { params });
  return res.data;
}

export async function getAdminTaskDisputeDetail(disputeId: number) {
  const res = await api.get(`/api/admin/task-disputes/${disputeId}`);
  return res.data;
}

export async function resolveTaskDispute(disputeId: number, resolutionNote: string) {
  const res = await api.post(`/api/admin/task-disputes/${disputeId}/resolve`, {
    resolution_note: resolutionNote
  });
  return res.data;
}

export async function dismissTaskDispute(disputeId: number, resolutionNote: string) {
  const res = await api.post(`/api/admin/task-disputes/${disputeId}/dismiss`, {
    resolution_note: resolutionNote
  });
  return res.data;
}

// ==================== 退款申请管理 API ====================

export async function getAdminRefundRequests(params?: {
  skip?: number;
  limit?: number;
  status?: string;
  keyword?: string;
}) {
  const res = await api.get('/api/admin/refund-requests', { params });
  return res.data;
}

export async function approveRefundRequest(refundId: number, data?: {
  admin_comment?: string;
  refund_amount?: number;
}) {
  const res = await api.post(`/api/admin/refund-requests/${refundId}/approve`, data || {});
  return res.data;
}

export async function rejectRefundRequest(refundId: number, adminComment: string) {
  const res = await api.post(`/api/admin/refund-requests/${refundId}/reject`, {
    admin_comment: adminComment
  });
  return res.data;
}

// ==================== 多人任务管理 API ====================

export const createOfficialMultiParticipantTask = async (taskData: {
  title: string;
  description: string;
  deadline: string;
  location: string;
  task_type: string;
  max_participants: number;
  min_participants: number;
  reward_type: 'cash' | 'points' | 'both';
  reward?: number;
  points_reward?: number;
  completion_rule: 'all' | 'any';
  reward_distribution: 'equal' | 'custom';
  auto_accept: boolean;
  images?: string[];
}) => {
  const res = await api.post('/api/admin/tasks/multi-participant', taskData);
  return res.data;
};

export const startMultiParticipantTask = async (taskId: string | number) => {
  const res = await api.post(`/api/admin/tasks/${taskId}/start`);
  return res.data;
};

export const approveParticipant = async (taskId: string | number, participantId: number) => {
  const res = await api.post(`/api/admin/tasks/${taskId}/participants/${participantId}/approve`);
  return res.data;
};

export const rejectParticipant = async (taskId: string | number, participantId: number) => {
  const res = await api.post(`/api/admin/tasks/${taskId}/participants/${participantId}/reject`);
  return res.data;
};

export const approveExitRequest = async (taskId: string | number, participantId: number) => {
  const res = await api.post(`/api/admin/tasks/${taskId}/participants/${participantId}/exit/approve`);
  return res.data;
};

export const rejectExitRequest = async (taskId: string | number, participantId: number) => {
  const res = await api.post(`/api/admin/tasks/${taskId}/participants/${participantId}/exit/reject`);
  return res.data;
};

export const completeTaskAndDistributeRewardsEqual = async (
  taskId: string | number,
  data: { idempotency_key: string }
) => {
  const res = await api.post(`/api/admin/tasks/${taskId}/complete`, data);
  return res.data;
};

export const completeTaskAndDistributeRewardsCustom = async (
  taskId: string | number,
  data: {
    idempotency_key: string;
    rewards: Array<{
      participant_id: number;
      reward_amount?: number;
      points_amount?: number;
    }>;
  }
) => {
  const res = await api.post(`/api/admin/tasks/${taskId}/complete/custom`, data);
  return res.data;
};

// ==================== 客服请求管理 API ====================

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

// ==================== 争议详情 API ====================

export async function getTaskDisputeTimeline(taskId: number) {
  const res = await api.get(`/api/tasks/${taskId}/dispute-timeline`);
  return res.data;
}

export async function sendAdminCustomerServiceChatMessage(content: string) {
  const res = await api.post('/api/admin/customer-service-chat', { content });
  return res.data;
}

// ==================== 文件上传 API ====================

export const uploadImage = async (file: File) => {
  const { compressImage } = await import('./utils/imageCompression');
  const compressed = await compressImage(file, { maxSizeMB: 4, maxWidthOrHeight: 1920 });
  const formData = new FormData();
  formData.append('image', compressed);
  const res = await api.post('/api/v2/upload/image', formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  });
  return res.data;
};

// ==================== 2FA (双因素认证) API ====================

/**
 * 获取 2FA 设置信息（生成 QR 码）
 */
export async function get2FASetup(): Promise<any> {
  const response = await api.get('/api/auth/admin/2fa/setup');
  return response.data;
}

/**
 * 验证并启用 2FA
 */
export async function verify2FASetup(secret: string, code: string): Promise<any> {
  const response = await api.post('/api/auth/admin/2fa/verify-setup', {
    secret,
    code
  });
  return response.data;
}

/**
 * 获取 2FA 状态
 */
export async function get2FAStatus(): Promise<any> {
  const response = await api.get('/api/auth/admin/2fa/status');
  return response.data;
}

/**
 * 禁用 2FA
 */
export async function disable2FA(password?: string, totpCode?: string, backupCode?: string): Promise<any> {
  const response = await api.post('/api/auth/admin/2fa/disable', {
    password,
    totp_code: totpCode,
    backup_code: backupCode
  });
  return response.data;
}

/**
 * 重新生成备份代码
 */
export async function regenerate2FABackupCodes(): Promise<any> {
  const response = await api.post('/api/auth/admin/2fa/regenerate-backup-codes');
  return response.data;
}

// ==================== 支付管理 API ====================

export async function getAdminPayments(params?: { page?: number; size?: number; status?: string; payment_type?: string; user_id?: string }) {
  const res = await api.get('/api/admin/payments', { params });
  return res.data;
}

export async function getAdminPaymentStats() {
  const res = await api.get('/api/admin/payments/stats');
  return res.data;
}

export async function getAdminPaymentDetail(paymentId: string) {
  const res = await api.get(`/api/admin/payments/${paymentId}`);
  return res.data;
}

export async function getAdminDashboardRevenue() {
  const res = await api.get('/api/admin/dashboard/revenue');
  return res.data;
}

export async function getAdminDashboardPaymentMethods() {
  const res = await api.get('/api/admin/dashboard/payment-methods');
  return res.data;
}

// ==================== VIP 订阅管理 API ====================

export async function getAdminVipSubscriptions(params?: { skip?: number; limit?: number; user_id?: string; status?: string }) {
  const res = await api.get('/api/admin/vip-subscriptions', { params });
  return res.data;
}

export async function getAdminVipSubscriptionStats() {
  const res = await api.get('/api/admin/vip-subscriptions/stats');
  return res.data;
}

export async function updateAdminVipSubscription(subscriptionId: number, data: { status: string }) {
  const res = await api.patch(`/api/admin/vip-subscriptions/${subscriptionId}`, data);
  return res.data;
}

// ==================== 推荐系统 API ====================

export async function getAdminRecommendationMetrics(params?: { days?: number }) {
  const res = await api.get('/api/admin/recommendation-metrics', { params });
  return res.data;
}

export async function getAdminRecommendationAnalytics(params?: { days?: number; algorithm?: string }) {
  const res = await api.get('/api/admin/recommendation-analytics', { params });
  return res.data;
}

export async function getAdminTopRecommendedTasks(params?: { days?: number; limit?: number }) {
  const res = await api.get('/api/admin/top-recommended-tasks', { params });
  return res.data;
}

export async function getAdminRecommendationHealth() {
  const res = await api.get('/api/admin/recommendation-health');
  return res.data;
}

export async function getAdminRecommendationOptimization() {
  const res = await api.get('/api/admin/recommendation-optimization');
  return res.data;
}

// ==================== 学生认证管理 API ====================

export async function revokeStudentVerification(verificationId: number, data: { reason_type: string; reason_detail: string }) {
  const res = await api.post(`/api/admin/student-verification/${verificationId}/revoke`, data);
  return res.data;
}

export async function extendStudentVerification(verificationId: number, data: { new_expires_at: string }) {
  const res = await api.post(`/api/admin/student-verification/${verificationId}/extend`, data);
  return res.data;
}

// ==================== OAuth 客户端管理 API ====================

export async function getAdminOAuthClients(params?: { is_active?: boolean }) {
  const res = await api.get('/api/admin/oauth/clients', { params });
  return res.data;
}

export async function getAdminOAuthClient(clientId: string) {
  const res = await api.get(`/api/admin/oauth/clients/${clientId}`);
  return res.data;
}

export async function createAdminOAuthClient(data: {
  client_name: string;
  client_uri?: string;
  logo_uri?: string;
  redirect_uris?: string[];
  scope_default?: string;
  allowed_grant_types?: string[];
  is_confidential?: boolean;
}) {
  const res = await api.post('/api/admin/oauth/clients', data);
  return res.data;
}

export async function updateAdminOAuthClient(clientId: string, data: {
  client_name?: string;
  client_uri?: string;
  logo_uri?: string;
  redirect_uris?: string[];
  is_active?: boolean;
}) {
  const res = await api.patch(`/api/admin/oauth/clients/${clientId}`, data);
  return res.data;
}

export async function rotateAdminOAuthClientSecret(clientId: string) {
  const res = await api.post(`/api/admin/oauth/clients/${clientId}/rotate-secret`);
  return res.data;
}

// ==================== 任务取消申请 API ====================

export async function getAdminCancelRequests() {
  const res = await api.get('/api/admin/cancel-requests');
  return res.data;
}

export async function reviewAdminCancelRequest(
  requestId: number,
  data: { decision: 'approve' | 'reject'; admin_comment?: string }
) {
  const res = await api.post(`/api/admin/cancel-requests/${requestId}/review`, data);
  return res.data;
}

export default api;

// ===== Dashboard Stats Trends =====

export interface TrendDataPoint {
  date: string;
  count: number;
}

export interface TrendResponse {
  dates: string[];
  counts: number[];
}

export async function getUserGrowthStats(period: '7d' | '30d' | '90d'): Promise<TrendDataPoint[]> {
  const response = await api.get<TrendResponse>(`/api/admin/stats/user-growth?period=${period}`);
  const { dates, counts } = response.data;
  return dates.map((date, i) => ({ date, count: counts[i] ?? 0 }));
}

export async function getTaskGrowthStats(period: '7d' | '30d' | '90d'): Promise<TrendDataPoint[]> {
  const response = await api.get<TrendResponse>(`/api/admin/stats/task-growth?period=${period}`);
  const { dates, counts } = response.data;
  return dates.map((date, i) => ({ date, count: counts[i] ?? 0 }));
}

/** 日活趋势（当日有发任务/申请任务/发消息的去重用户数） */
export async function getDailyActiveStats(period: '7d' | '30d' | '90d'): Promise<TrendDataPoint[]> {
  const response = await api.get<TrendResponse>(`/api/admin/stats/daily-active?period=${period}`);
  const { dates, counts } = response.data;
  return dates.map((date, i) => ({ date, count: counts[i] ?? 0 }));
}
