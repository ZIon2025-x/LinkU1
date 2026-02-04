// API配置
const isProduction = process.env.NODE_ENV === 'production';

export const API_BASE_URL = isProduction 
  ? process.env.REACT_APP_API_URL || 'https://api.link2ur.com'
  : 'http://localhost:8000';

export const WS_BASE_URL = isProduction
  ? process.env.REACT_APP_WS_URL || 'wss://api.link2ur.com'
  : 'ws://localhost:8000';

/**
 * App Store 链接（用于「在 App 内打开」条中，未安装时跳转的下载页）。
 * 如何查找真实链接：
 * 1. 打开 https://appstoreconnect.apple.com → 我的 App → 选中 Link²Ur → 在「App 信息」里可看到「Apple ID」（一串数字）
 * 2. 或用 iPhone 在 App Store 搜索「Link²Ur」，打开你的 App 页面，点分享 →「拷贝链接」，即 https://apps.apple.com/app/idXXXXXXXX 或 https://apps.apple.com/app/link2ur/idXXXXXXXX
 * 配置方式：设置环境变量 REACT_APP_APP_STORE_URL，或把下面的默认值里的 id000000000 改成你的 Apple ID。
 */
export const APP_STORE_URL =
  process.env.REACT_APP_APP_STORE_URL || 'https://apps.apple.com/app/link2ur/id000000000';

// 调试信息

// 导出API端点
export const API_ENDPOINTS = {
  // 认证相关 - 使用新的安全认证系统
  LOGIN: '/api/secure-auth/login',
  REGISTER: '/api/users/register',
  REFRESH: '/api/secure-auth/refresh',
  LOGOUT: '/api/secure-auth/logout',
  
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
  CUSTOMER_SERVICE_MESSAGE: '/api/user/customer-service/chats/{chatId}/messages',
  
  // 客服相关（用户端）
  CS_CHATS: '/api/user/customer-service/chats',
  CS_MESSAGES: (chatId: string) => `/api/user/customer-service/chats/${chatId}/messages`,
  CS_ASSIGN: '/api/user/customer-service/assign',
  CS_END_CHAT: (chatId: string) => `/api/user/customer-service/chats/${chatId}/end`,
  CS_RATE: (chatId: string) => `/api/user/customer-service/chats/${chatId}/rate`,
  CS_STATUS: '/api/customer-service/status',
  CS_CANCEL_REQUESTS: '/api/customer-service/cancel-requests',
  CS_ADMIN_REQUESTS: '/api/customer-service/admin-requests',
  CS_ADMIN_CHAT: '/api/customer-service/admin-chat',
  
  // 文件上传
  UPLOAD_IMAGE: '/api/upload/image',
  UPLOAD_FILE: '/api/upload/file',
  // 客服文件上传（专用接口）
  CS_UPLOAD_FILE: (chatId: string) => `/api/user/customer-service/chats/${chatId}/files`,
  
  // WebSocket
  WS_CHAT: (userId: string) => `/ws/chat/${userId}`,
  
  // 论坛相关
  FORUM_CATEGORIES: '/api/forum/categories',
  FORUM_POSTS: '/api/forum/posts',
  FORUM_SEARCH: '/api/forum/search',
  FORUM_NOTIFICATIONS: '/api/forum/notifications',
} as const;
