/**
 * 任务达人页面样式常量
 * 统一管理颜色、间距、圆角等设计令牌
 */

export const taskExpertStyles = {
  colors: {
    primary: '#3b82f6',
    primaryHover: '#2563eb',
    success: '#10b981',
    successHover: '#059669',
    danger: '#ef4444',
    dangerHover: '#dc2626',
    warning: '#f59e0b',
    warningHover: '#d97706',
    background: '#f7fafc',
    cardBackground: '#fff',
    borderColor: '#e2e8f0',
    textPrimary: '#1a202c',
    textSecondary: '#718096',
    textMuted: '#999',
  },
  spacing: {
    xs: '4px',
    sm: '8px',
    md: '12px',
    lg: '16px',
    xl: '20px',
    xxl: '24px',
  },
  borderRadius: {
    sm: '6px',
    md: '8px',
    lg: '12px',
    xl: '16px',
  },
  shadows: {
    sm: '0 2px 8px rgba(0,0,0,0.05)',
    md: '0 4px 12px rgba(0,0,0,0.1)',
    lg: '0 8px 24px rgba(0,0,0,0.15)',
  },
  gradients: {
    purple: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    pink: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
    blue: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
    green: 'linear-gradient(135deg, #43e97b 0%, #38f9d7 100%)',
    yellow: 'linear-gradient(135deg, #fa709a 0%, #fee140 100%)',
  },
  statusColors: {
    pending: {
      background: 'rgba(146, 64, 14, 0.1)',
      color: '#92400e',
    },
    approved: {
      background: 'rgba(6, 95, 70, 0.1)',
      color: '#065f46',
    },
    rejected: {
      background: 'rgba(153, 27, 27, 0.1)',
      color: '#991b1b',
    },
    negotiating: {
      background: 'rgba(30, 64, 175, 0.1)',
      color: '#1e40af',
    },
    open: {
      background: '#dbeafe',
      color: '#1e40af',
    },
    inProgress: {
      background: '#d1fae5',
      color: '#065f46',
    },
    completed: {
      background: '#d1fae5',
      color: '#065f46',
    },
    cancelled: {
      background: '#fee2e2',
      color: '#991b1b',
    },
  },
  breakpoints: {
    mobile: '768px',
    tablet: '1024px',
    desktop: '1200px',
  },
};

/**
 * 获取状态样式
 */
export const getStatusStyle = (status: string) => {
  const statusMap: { [key: string]: keyof typeof taskExpertStyles.statusColors } = {
    pending: 'pending',
    approved: 'approved',
    rejected: 'rejected',
    negotiating: 'negotiating',
    price_agreed: 'negotiating',
    open: 'open',
    in_progress: 'inProgress',
    completed: 'completed',
    cancelled: 'cancelled',
  };
  
  const statusKey = statusMap[status] || 'pending';
  return taskExpertStyles.statusColors[statusKey];
};

