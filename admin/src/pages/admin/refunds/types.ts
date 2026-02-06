/**
 * RefundManagement 模块类型定义
 */

export interface RefundRequest {
  id: number;
  task_id: number;
  poster_id: string;
  reason: string;
  reason_type?: string;
  reason_type_display?: string;
  refund_type?: 'full' | 'partial';
  refund_type_display?: string;
  refund_amount?: number;
  refund_percentage?: number;
  status: RefundStatus;
  admin_comment?: string;
  reviewed_at?: string;
  created_at: string;
  evidence_files?: string[];
  task?: {
    title?: string;
    agreed_reward?: number;
    base_reward?: number;
    is_paid?: boolean;
  };
  poster?: {
    name?: string;
  };
}

export type RefundStatus = 'pending' | 'approved' | 'rejected' | 'processing' | 'completed' | 'cancelled';

export type RefundAction = 'approve' | 'reject';

export const REFUND_STATUS_LABELS: Record<RefundStatus, string> = {
  pending: '待处理',
  approved: '已批准',
  rejected: '已拒绝',
  processing: '处理中',
  completed: '已完成',
  cancelled: '已取消'
};

export const REFUND_STATUS_COLORS: Record<RefundStatus, { bg: string; color: string }> = {
  pending: { bg: '#fff3cd', color: '#856404' },
  approved: { bg: '#d1ecf1', color: '#0c5460' },
  rejected: { bg: '#f8d7da', color: '#721c24' },
  processing: { bg: '#d1ecf1', color: '#0c5460' },
  completed: { bg: '#d4edda', color: '#155724' },
  cancelled: { bg: '#e9ecef', color: '#6c757d' }
};

export interface DisputeTimeline {
  task_id: number;
  task_title: string;
  timeline: TimelineItem[];
}

export interface TimelineItem {
  type: string;
  actor: 'poster' | 'taker' | 'admin';
  reviewer_name?: string;
  resolver_name?: string;
  timestamp: string;
  content?: string;
  status?: string;
  amount?: number;
}

export const TIMELINE_ICONS: Record<string, string> = {
  task_completed: '✅',
  task_confirmed: '✓',
  refund_request: '↩️',
  rebuttal: '💬',
  dispute: '⚠️',
  dispute_resolved: '✅',
  dispute_dismissed: '❌',
  refund_approved: '✅',
  refund_rejected: '❌',
  refund_completed: '💰',
};
