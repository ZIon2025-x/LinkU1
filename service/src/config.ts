// API 配置
const isProduction = process.env.NODE_ENV === 'production';

export const API_BASE_URL = isProduction 
  ? process.env.REACT_APP_API_URL || 'https://api.link2ur.com'
  : 'http://localhost:8000';

export const WS_BASE_URL = isProduction
  ? process.env.REACT_APP_WS_URL || 'wss://api.link2ur.com'
  : 'ws://localhost:8000';

export const MAIN_SITE_URL = isProduction
  ? process.env.REACT_APP_MAIN_SITE_URL || 'https://www.link2ur.com'
  : 'http://localhost:3000';

// 客服专用端点
export const API_ENDPOINTS = {
  // 认证
  CS_LOGIN: '/api/auth/service/login',
  CS_LOGOUT: '/api/customer-service/logout',
  CS_PROFILE: '/api/auth/service/profile',
  CSRF_TOKEN: '/api/csrf/token',
  
  // 客服会话
  CS_CHATS: '/api/customer-service/chats',
  CS_MESSAGES: (chatId: string) => `/api/customer-service/chats/${chatId}/messages`,
  CS_MARK_READ: (chatId: string) => `/api/customer-service/chats/${chatId}/mark-read`,
  CS_END_CHAT: (chatId: string) => `/api/customer-service/chats/${chatId}/end`,
  
  // 客服状态
  CS_ONLINE: '/api/customer-service/online',
  CS_OFFLINE: '/api/customer-service/offline',
  CS_STATUS: '/api/customer-service/status',
  
  // 任务相关
  CS_TASKS: '/api/customer-service/tasks',
  CS_TASK_DETAIL: (taskId: string) => `/api/customer-service/tasks/${taskId}`,
  CS_CANCEL_REQUESTS: '/api/customer-service/cancel-requests',
  
  // 通知相关（使用员工通知API）
  CS_NOTIFICATIONS: '/api/users/staff/notifications',
  CS_NOTIFICATIONS_UNREAD: '/api/users/staff/notifications/unread',
  CS_NOTIFICATIONS_READ: (notificationId: number) => `/api/users/staff/notifications/${notificationId}/read`,
  CS_NOTIFICATIONS_READ_ALL: '/api/users/staff/notifications/read-all',
  
  // 后台管理请求
  CS_ADMIN_REQUESTS: '/api/customer-service/admin-requests',
  CS_ADMIN_CHAT: '/api/customer-service/admin-chat',
  
  // 用户相关
  CS_USERS: '/api/customer-service/users',
  CS_USER_DETAIL: (userId: string) => `/api/customer-service/users/${userId}`,
} as const;
