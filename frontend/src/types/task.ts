// 任务相关类型定义

export interface User {
  id: string;
  name: string;
  email: string;
  phone?: string;
  created_at: string;
  is_active: number;
  is_verified: number;
  user_level: 'normal' | 'vip' | 'super';
  task_count: number;
  avg_rating: number;
  avatar?: string;
  is_suspended: number;
  suspend_until?: string;
  is_banned: number;
  timezone: string;
  agreed_to_terms: number;
  terms_agreed_at?: string;
}

export interface Task {
  id: number;
  title: string;
  description: string;
  deadline: string;
  reward: number;
  location: string;
  latitude?: number;  // 纬度（用于地图选点）
  longitude?: number; // 经度（用于地图选点）
  task_type: string;
  poster_id: string;
  taker_id?: string;
  status: 'open' | 'taken' | 'in_progress' | 'pending_confirmation' | 'completed' | 'cancelled';
  task_level: 'normal' | 'vip' | 'super' | 'expert';
  created_at: string;
  accepted_at?: string;
  completed_at?: string;
  is_paid: number;
  escrow_amount: number;
  is_confirmed: number;
  paid_to_user_id?: string;
  is_public: number;
  visibility: 'public' | 'private';
}

export interface Review {
  id: number;
  task_id: number;
  user_id: string;
  rating: number;
  comment?: string;
  is_anonymous: number;
  created_at: string;
}

export interface TaskApplication {
  id: number;
  task_id: number;
  applicant_id: string;
  applicant_name?: string;
  applicant_avatar?: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
  message?: string;
  negotiated_price?: number;
  currency?: string;
}

export type TaskStatus = Task['status'];
export type TaskLevel = Task['task_level'];
export type UserLevel = User['user_level'];


