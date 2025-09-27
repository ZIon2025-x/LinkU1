// API配置
const isProduction = process.env.NODE_ENV === 'production';

export const API_BASE_URL = isProduction 
  ? process.env.REACT_APP_API_URL || 'https://linku1-production.up.railway.app'
  : 'http://localhost:8000';

export const WS_BASE_URL = isProduction
  ? process.env.REACT_APP_WS_URL || 'wss://linku1-production.up.railway.app'
  : 'ws://localhost:8000';

// 调试信息
console.log('API_BASE_URL:', API_BASE_URL);
console.log('WS_BASE_URL:', WS_BASE_URL);
console.log('isProduction:', isProduction);

// 导出API端点
export const API_ENDPOINTS = {
  // 认证相关
  LOGIN: '/api/auth/login',
  REGISTER: '/api/auth/register',
  REFRESH: '/api/auth/refresh',
  LOGOUT: '/api/auth/logout',
  
  // 客服认证
  CS_LOGIN: '/api/cs/login',
  CS_REFRESH: '/api/cs/refresh',
  
  // 管理员认证
  ADMIN_LOGIN: '/api/admin/login',
  ADMIN_REFRESH: '/api/admin/refresh',
  
  // 用户相关
  PROFILE: '/api/users/profile/me',
  AVATAR: '/api/users/avatar',
  
  // 任务相关
  TASKS: '/api/tasks',
  TASK_ACCEPT: (id: number) => `/api/tasks/${id}/accept`,
  TASK_COMPLETE: (id: number) => `/api/tasks/${id}/complete`,
  TASK_CANCEL: (id: number) => `/api/tasks/${id}/cancel`,
  
  // 消息相关
  MESSAGES: '/api/users/messages',
  SEND_MESSAGE: '/api/users/messages/send',
  CUSTOMER_SERVICE_MESSAGE: '/api/users/customer-service/messages/send',
  
  // 客服相关
  CS_CHATS: '/api/users/customer-service/chats',
  CS_MESSAGES: (chatId: string) => `/api/users/customer-service/messages/${chatId}`,
  CS_STATUS: '/api/users/customer-service/status',
  CS_CANCEL_REQUESTS: '/api/users/customer-service/cancel-requests',
  CS_ADMIN_REQUESTS: '/api/users/customer-service/admin-requests',
  CS_ADMIN_CHAT: '/api/users/customer-service/admin-chat',
  
  // 文件上传
  UPLOAD_IMAGE: '/api/upload/image',
  
  // WebSocket
  WS_CHAT: (userId: string) => `/ws/chat/${userId}`,
} as const;
