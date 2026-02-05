import React from 'react';
import styles from './StatusBadge.module.css';

export type BadgeVariant =
  | 'default'
  | 'primary'
  | 'success'
  | 'warning'
  | 'danger'
  | 'info'
  | 'secondary';

export interface StatusBadgeProps {
  text: string;
  variant?: BadgeVariant;
  size?: 'small' | 'medium' | 'large';
  dot?: boolean;
  className?: string;
}

/**
 * 通用状态标签组件
 * 用于显示状态、类型等标识信息
 */
export const StatusBadge: React.FC<StatusBadgeProps> = ({
  text,
  variant = 'default',
  size = 'medium',
  dot = false,
  className = '',
}) => {
  const badgeClasses = [
    styles.badge,
    styles[variant],
    styles[size],
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <span className={badgeClasses}>
      {dot && <span className={styles.dot} />}
      {text}
    </span>
  );
};

/**
 * 预定义常用状态映射
 */
export const statusBadgeMap = {
  // 通用状态
  active: { text: '启用', variant: 'success' as BadgeVariant },
  inactive: { text: '禁用', variant: 'secondary' as BadgeVariant },
  pending: { text: '待处理', variant: 'warning' as BadgeVariant },
  approved: { text: '已批准', variant: 'success' as BadgeVariant },
  rejected: { text: '已拒绝', variant: 'danger' as BadgeVariant },

  // 用户状态
  online: { text: '在线', variant: 'success' as BadgeVariant, dot: true },
  offline: { text: '离线', variant: 'secondary' as BadgeVariant, dot: true },
  banned: { text: '已封禁', variant: 'danger' as BadgeVariant },
  suspended: { text: '已暂停', variant: 'warning' as BadgeVariant },

  // 任务/订单状态
  open: { text: '进行中', variant: 'primary' as BadgeVariant },
  completed: { text: '已完成', variant: 'success' as BadgeVariant },
  cancelled: { text: '已取消', variant: 'secondary' as BadgeVariant },

  // 支付状态
  paid: { text: '已支付', variant: 'success' as BadgeVariant },
  unpaid: { text: '未支付', variant: 'warning' as BadgeVariant },
  refunded: { text: '已退款', variant: 'info' as BadgeVariant },

  // 审核状态
  reviewing: { text: '审核中', variant: 'warning' as BadgeVariant },
  passed: { text: '已通过', variant: 'success' as BadgeVariant },
  failed: { text: '未通过', variant: 'danger' as BadgeVariant },
};

/**
 * 快捷状态标签组件
 * 自动根据状态值匹配颜色和文本
 */
export const StatusBadgeAuto: React.FC<{
  status: keyof typeof statusBadgeMap | string;
  className?: string;
  size?: 'small' | 'medium' | 'large';
}> = ({ status, className, size }) => {
  const config = statusBadgeMap[status as keyof typeof statusBadgeMap] || {
    text: status,
    variant: 'default' as BadgeVariant,
  };

  return (
    <StatusBadge
      text={config.text}
      variant={config.variant}
      dot={config.dot}
      size={size}
      className={className}
    />
  );
};

export default StatusBadge;
