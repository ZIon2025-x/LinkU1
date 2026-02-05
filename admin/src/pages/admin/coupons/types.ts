export interface CouponForm {
  id?: number;
  code: string;
  name: string;
  description: string;
  type: 'fixed_amount' | 'percentage';
  discount_value: number;
  min_amount: number;
  max_discount?: number;
  currency: string;
  total_quantity?: number;
  per_user_limit: number;
  per_device_limit?: number;
  per_ip_limit?: number;
  can_combine: boolean;
  combine_limit: number;
  apply_order: number;
  valid_from: string;
  valid_until: string;
  points_required: number;
  eligibility_type: '' | 'first_order' | 'new_user' | 'user_type' | 'member' | 'all';
  eligibility_value: '' | 'normal' | 'vip' | 'super';
  per_day_limit?: number;
  per_user_limit_window: '' | 'day' | 'week' | 'month' | 'year';
  per_user_per_window_limit?: number;
  vat_category: '' | 'standard' | 'reduced' | 'zero' | 'exempt';
  applicable_scenarios: string[];
  task_types: string[];
  locations: string[];
  excluded_task_types: string[];
  min_task_amount?: number;
  max_task_amount?: number;
}

export interface Coupon {
  id: number;
  code: string;
  name: string;
  description?: string;
  type: 'fixed_amount' | 'percentage';
  discount_value: number;
  min_amount: number;
  max_discount?: number;
  currency: string;
  total_quantity?: number;
  used_quantity: number;
  remaining_quantity?: number;
  per_user_limit: number;
  can_combine: boolean;
  status: 'active' | 'inactive' | 'expired';
  valid_from: string;
  valid_until: string;
  points_required: number;
  applicable_scenarios?: string[];
  usage_conditions?: {
    task_types?: string[];
    locations?: string[];
    excluded_task_types?: string[];
    min_task_amount?: number;
    max_task_amount?: number;
  };
  created_at: string;
  updated_at: string;
}

export const initialCouponForm: CouponForm = {
  code: '',
  name: '',
  description: '',
  type: 'fixed_amount',
  discount_value: 0,
  min_amount: 0,
  currency: 'GBP',
  per_user_limit: 1,
  can_combine: false,
  combine_limit: 1,
  apply_order: 0,
  valid_from: '',
  valid_until: '',
  points_required: 0,
  eligibility_type: '',
  eligibility_value: '',
  per_user_limit_window: '',
  vat_category: '',
  applicable_scenarios: [],
  task_types: [],
  locations: [],
  excluded_task_types: [],
};
