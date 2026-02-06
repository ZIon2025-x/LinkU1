/**
 * Dashboard 模块类型定义
 */

export interface DashboardStats {
  total_users: number;
  total_tasks: number;
  total_customer_service: number;
  active_sessions: number;
  total_revenue: number;
  avg_rating: number;
}

export interface CleanupResult {
  success: boolean;
  message: string;
  cleaned_count?: number;
}

export interface StatCardProps {
  label: string;
  value: string | number;
  prefix?: string;
  suffix?: string;
}
