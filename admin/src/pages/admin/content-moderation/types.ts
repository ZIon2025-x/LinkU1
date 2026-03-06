export interface SensitiveWord {
  id: number;
  word: string;
  category: string;
  level: 'mask' | 'review';
  is_active: boolean;
  created_by?: string;
  created_at?: string;
}

export interface SensitiveWordForm {
  id?: number;
  word: string;
  category: string;
  level: 'mask' | 'review';
  is_active: boolean;
}

export const initialSensitiveWordForm: SensitiveWordForm = {
  word: '',
  category: 'illegal',
  level: 'review',
  is_active: true,
};

export interface HomophoneMapping {
  id: number;
  variant: string;
  standard: string;
  is_active: boolean;
}

export interface HomophoneMappingForm {
  id?: number;
  variant: string;
  standard: string;
  is_active: boolean;
}

export const initialHomophoneForm: HomophoneMappingForm = {
  variant: '',
  standard: '',
  is_active: true,
};

export interface ContentReview {
  id: number;
  content_type: string;
  content_id: number;
  user_id: string;
  original_text: string;
  matched_words: Array<{ word: string; category: string }>;
  status: 'pending' | 'approved' | 'rejected';
  reviewed_by?: string;
  reviewed_at?: string;
  created_at: string;
}

export interface FilterLog {
  id: number;
  user_id: string;
  content_type: string;
  action: 'mask' | 'review' | 'pass';
  matched_words: Array<{ word: string; category: string }>;
  created_at: string;
}

export const CATEGORIES = [
  { value: 'ad', label: '广告推广' },
  { value: 'scam', label: '诈骗' },
  { value: 'agent', label: '中介' },
  { value: 'porn', label: '色情' },
  { value: 'drugs', label: '毒品' },
  { value: 'gambling', label: '赌博' },
  { value: 'violence', label: '暴力' },
  { value: 'illegal', label: '违法' },
  { value: 'profanity', label: '脏话' },
  { value: 'contact', label: '联系方式' },
];

export const CATEGORY_MAP: Record<string, string> = Object.fromEntries(
  CATEGORIES.map(c => [c.value, c.label])
);

export const CONTENT_TYPE_MAP: Record<string, string> = {
  task: '任务',
  forum_post: '论坛帖子',
  forum_reply: '论坛回复',
  flea_market: '跳蚤市场',
  profile: '个人资料',
};

export const ACTION_MAP: Record<string, string> = {
  mask: '遮蔽',
  review: '审核',
  pass: '通过',
};
