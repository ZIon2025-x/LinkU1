/**
 * DisputeManagement 模块类型定义
 */

export interface TaskDispute {
  id: number;
  task_id: number;
  task_title?: string;
  task_description?: string;
  task_status?: string;
  task_created_at?: string;
  task_accepted_at?: string;
  task_completed_at?: string;
  poster_id: string;
  poster_name?: string;
  taker_id?: string;
  taker_name?: string;
  reason: string;
  status: DisputeStatus;
  created_at: string;
  resolved_at?: string;
  resolver_name?: string;
  resolution_note?: string;
  // 支付相关
  task_amount?: number;
  currency?: string;
  base_reward?: number;
  agreed_reward?: number;
  is_paid?: boolean;
  payment_intent_id?: string;
  escrow_amount?: number;
  is_confirmed?: boolean;
  paid_to_user_id?: string;
}

export type DisputeStatus = 'pending' | 'resolved' | 'dismissed';

export type DisputeAction = 'resolve' | 'dismiss';

export const DISPUTE_STATUS_LABELS: Record<DisputeStatus, string> = {
  pending: '待处理',
  resolved: '已解决',
  dismissed: '已驳回'
};

export const DISPUTE_STATUS_COLORS: Record<DisputeStatus, { bg: string; color: string }> = {
  pending: { bg: '#fff3cd', color: '#856404' },
  resolved: { bg: '#d4edda', color: '#155724' },
  dismissed: { bg: '#f8d7da', color: '#721c24' }
};

export const TASK_STATUS_LABELS: Record<string, string> = {
  open: '开放中',
  taken: '已接受',
  in_progress: '进行中',
  pending_confirmation: '待确认',
  completed: '已完成',
  cancelled: '已取消'
};

export const TASK_STATUS_COLORS: Record<string, { bg: string; color: string }> = {
  open: { bg: '#e3f2fd', color: '#1565c0' },
  taken: { bg: '#e8f5e9', color: '#2e7d32' },
  in_progress: { bg: '#d1ecf1', color: '#0c5460' },
  pending_confirmation: { bg: '#fff3cd', color: '#856404' },
  completed: { bg: '#d4edda', color: '#155724' },
  cancelled: { bg: '#f8d7da', color: '#721c24' }
};
