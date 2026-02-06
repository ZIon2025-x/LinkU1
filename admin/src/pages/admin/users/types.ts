/**
 * UserManagement 模块类型定义
 */

export interface User {
  id: string;
  name: string;
  inviter_id?: string;
  invitation_code_text?: string;
  invitation_code_id?: number;
  email: string;
  user_level: 'normal' | 'vip' | 'super';
  is_active: number;
  is_banned: number;
  is_suspended: number;
  created_at: string;
  task_count: number;
  avg_rating: number;
}

export interface UserUpdateData {
  user_level?: string;
  is_banned?: number;
  is_suspended?: number;
  suspend_until?: string;
}

export type UserLevel = 'normal' | 'vip' | 'super';

export const USER_LEVEL_LABELS: Record<UserLevel, string> = {
  normal: '普通',
  vip: 'VIP',
  super: '超级'
};
