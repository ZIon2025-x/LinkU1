// API 配置
const isProduction = process.env.NODE_ENV === 'production';

// 开发环境使用测试后端
const DEV_API_URL = 'https://linktest.up.railway.app';
const DEV_WS_URL = 'wss://linktest.up.railway.app';

export const API_BASE_URL = isProduction 
  ? process.env.REACT_APP_API_URL || 'https://api.link2ur.com'
  : process.env.REACT_APP_API_URL || DEV_API_URL;

export const WS_BASE_URL = isProduction
  ? process.env.REACT_APP_WS_URL || 'wss://api.link2ur.com'
  : process.env.REACT_APP_WS_URL || DEV_WS_URL;

export const MAIN_SITE_URL = isProduction
  ? process.env.REACT_APP_MAIN_SITE_URL || 'https://www.link2ur.com'
  : 'http://localhost:3000';

// 管理员专用端点
export const API_ENDPOINTS = {
  // 认证
  ADMIN_LOGIN: '/api/admin/login',
  ADMIN_LOGOUT: '/api/admin/logout',
  ADMIN_REFRESH: '/api/admin/refresh',
  ADMIN_PROFILE: '/api/auth/admin/profile',
  CSRF_TOKEN: '/api/csrf/token',
  
  // 仪表盘
  DASHBOARD_STATS: '/api/admin/dashboard/stats',
  
  // 用户管理
  USERS: '/api/admin/users',
  
  // 管理员管理
  ADMINS: '/api/admin/admins',
  
  // 客服管理
  CUSTOMER_SERVICES: '/api/admin/customer-services',
  
  // 任务达人
  TASK_EXPERTS: '/api/task-experts/admin',
  EXPERT_APPLICATIONS: '/api/task-experts/admin/applications',
  PROFILE_UPDATE_REQUESTS: '/api/task-experts/admin/profile-update-requests',
  
  // 论坛管理
  FORUM_CATEGORIES: '/api/forum/categories',
  FORUM_POSTS: '/api/forum/posts',
  FORUM_REPORTS: '/api/forum/admin/reports',
  
  // 跳蚤市场
  FLEA_MARKET: '/api/flea-market/admin',
  FLEA_MARKET_REPORTS: '/api/flea-market/admin/reports',
  
  // Banner 管理
  BANNERS: '/api/admin/banners',
  
  // 邀请码
  INVITATION_CODES: '/api/admin/invitation-codes',
  
  // 排行榜
  LEADERBOARDS: '/api/custom-leaderboards/admin',
  
  // 争议处理
  DISPUTES: '/api/admin/disputes',
  
  // 2FA (双因素认证)
  TWO_FA_SETUP: '/api/auth/admin/2fa/setup',
  TWO_FA_VERIFY_SETUP: '/api/auth/admin/2fa/verify-setup',
  TWO_FA_STATUS: '/api/auth/admin/2fa/status',
  TWO_FA_DISABLE: '/api/auth/admin/2fa/disable',
  TWO_FA_REGENERATE_BACKUP_CODES: '/api/auth/admin/2fa/regenerate-backup-codes',
} as const;
