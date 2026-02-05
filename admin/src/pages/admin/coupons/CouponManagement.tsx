import React, { useState, useEffect, useCallback } from 'react';
import { message } from 'antd';
import api from '../../../utils/api';
import styles from '../../AdminDashboard.module.css';

interface CouponForm {
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

const initialCouponForm: CouponForm = {
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

export const CouponManagement: React.FC = () => {
  const [coupons, setCoupons] = useState<any[]>([]);
  const [couponsPage, setCouponsPage] = useState(1);
  const [couponsTotal, setCouponsTotal] = useState(0);
  const [couponsStatusFilter, setCouponsStatusFilter] = useState<string | undefined>(undefined);
  const [showCouponModal, setShowCouponModal] = useState(false);
  const [couponForm, setCouponForm] = useState<CouponForm>(initialCouponForm);
  const [couponsLoading, setCouponsLoading] = useState(false);

  // Collapse state for form sections
  const [couponSectionsCollapsed, setCouponSectionsCollapsed] = useState({
    basic: false,
    discount: false,
    limits: false,
    eligibility: false,
    scenarios: false,
    validity: false
  });

  const loadCoupons = useCallback(async () => {
    setCouponsLoading(true);
    try {
      const params: any = { page: couponsPage, per_page: 20 };
      if (couponsStatusFilter) {
        params.status = couponsStatusFilter;
      }
      const response = await api.get('/admin/coupons', { params });
      setCoupons(response.data.data || []);
      setCouponsTotal(response.data.total || 0);
    } catch (error: any) {
      message.error(`加载优惠券失败：${error.response?.data?.detail || error.message}`);
    } finally {
      setCouponsLoading(false);
    }
  }, [couponsPage, couponsStatusFilter]);

  useEffect(() => {
    loadCoupons();
  }, [loadCoupons]);

  const handleCreateCoupon = async () => {
    if (!couponForm.name || !couponForm.valid_from || !couponForm.valid_until) {
      message.warning('请填写优惠券名称和有效期');
      return;
    }
    if (couponForm.discount_value <= 0) {
      message.warning('请填写折扣金额');
      return;
    }

    try {
      const data: any = {
        code: couponForm.code && couponForm.code.trim() ? couponForm.code.toUpperCase() : undefined,
        name: couponForm.name,
        description: couponForm.description || undefined,
        type: couponForm.type,
        discount_value: couponForm.discount_value,
        min_amount: couponForm.min_amount || 0,
        max_discount: couponForm.max_discount,
        currency: couponForm.currency,
        total_quantity: couponForm.total_quantity,
        per_user_limit: couponForm.per_user_limit || 1,
        can_combine: couponForm.can_combine,
        combine_limit: couponForm.combine_limit || 1,
        apply_order: couponForm.apply_order || 0,
        valid_from: couponForm.valid_from,
        valid_until: couponForm.valid_until,
        points_required: couponForm.points_required || 0,
        applicable_scenarios: couponForm.applicable_scenarios.length > 0 ? couponForm.applicable_scenarios : undefined,
        usage_conditions: (() => {
          const conditions: any = {};
          if (couponForm.task_types.length > 0) {
            conditions.task_types = couponForm.task_types;
          }
          if (couponForm.excluded_task_types.length > 0) {
            conditions.excluded_task_types = couponForm.excluded_task_types;
          }
          if (couponForm.locations.length > 0) {
            conditions.locations = couponForm.locations;
          }
          if (couponForm.min_task_amount) {
            conditions.min_task_amount = couponForm.min_task_amount;
          }
          if (couponForm.max_task_amount) {
            conditions.max_task_amount = couponForm.max_task_amount;
          }
          return Object.keys(conditions).length > 0 ? conditions : undefined;
        })(),
        per_device_limit: couponForm.per_device_limit,
        per_ip_limit: couponForm.per_ip_limit,
        per_day_limit: couponForm.per_day_limit,
        eligibility_type: couponForm.eligibility_type || undefined,
        eligibility_value: couponForm.eligibility_value || undefined,
        per_user_limit_window: couponForm.per_user_limit_window || undefined,
        per_user_per_window_limit: couponForm.per_user_per_window_limit ?? undefined,
        vat_category: couponForm.vat_category || undefined,
      };

      if (couponForm.id) {
        await api.put(`/admin/coupons/${couponForm.id}`, data);
        message.success('优惠券更新成功');
      } else {
        await api.post('/admin/coupons', data);
        message.success('优惠券创建成功');
      }

      setShowCouponModal(false);
      setCouponForm(initialCouponForm);
      loadCoupons();
    } catch (error: any) {
      message.error(`操作失败：${error.response?.data?.detail || error.message}`);
    }
  };

  return (
    <div style={{ padding: '24px' }}>
      <div style={{ marginBottom: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2 style={{ margin: 0 }}>优惠券管理</h2>
        <button
          onClick={() => {
            setCouponForm(initialCouponForm);
            setShowCouponModal(true);
          }}
          style={{
            padding: '8px 16px',
            backgroundColor: '#007bff',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          创建优惠券
        </button>
      </div>

      <div style={{ marginBottom: '16px' }}>
        <select
          value={couponsStatusFilter || 'all'}
          onChange={(e) => {
            setCouponsStatusFilter(e.target.value === 'all' ? undefined : e.target.value);
            setCouponsPage(1);
          }}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
        >
          <option value="all">全部状态</option>
          <option value="active">激活</option>
          <option value="inactive">停用</option>
          <option value="expired">过期</option>
        </select>
      </div>

      {couponsLoading ? (
        <div>加载中...</div>
      ) : (
        <div className={styles.tableWrapper}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>ID</th>
                <th>代码</th>
                <th>名称</th>
                <th>类型</th>
                <th>折扣值</th>
                <th>状态</th>
                <th>有效期</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {coupons.map((coupon) => (
                <tr key={coupon.id}>
                  <td>{coupon.id}</td>
                  <td>{coupon.code}</td>
                  <td>{coupon.name}</td>
                  <td>{coupon.type === 'fixed_amount' ? '满减' : '折扣'}</td>
                  <td>
                    {coupon.type === 'fixed_amount'
                      ? `£${(coupon.discount_value / 100).toFixed(2)}`
                      : `${(coupon.discount_value / 100).toFixed(2)}%`}
                  </td>
                  <td>
                    <span
                      style={{
                        padding: '2px 8px',
                        borderRadius: '4px',
                        backgroundColor:
                          coupon.status === 'active' ? '#d4edda' :
                          coupon.status === 'expired' ? '#f8d7da' : '#fff3cd',
                        color:
                          coupon.status === 'active' ? '#155724' :
                          coupon.status === 'expired' ? '#721c24' : '#856404'
                      }}
                    >
                      {coupon.status === 'active' ? '激活' :
                       coupon.status === 'expired' ? '过期' : '停用'}
                    </span>
                  </td>
                  <td>{new Date(coupon.valid_until).toLocaleDateString()}</td>
                  <td>
                    <button
                      onClick={() => {
                        setCouponForm({
                          ...coupon,
                          applicable_scenarios: coupon.applicable_scenarios || [],
                          task_types: coupon.usage_conditions?.task_types || [],
                          locations: coupon.usage_conditions?.locations || [],
                          excluded_task_types: coupon.usage_conditions?.excluded_task_types || [],
                          min_task_amount: coupon.usage_conditions?.min_task_amount,
                          max_task_amount: coupon.usage_conditions?.max_task_amount,
                        });
                        setShowCouponModal(true);
                      }}
                      style={{
                        padding: '4px 12px',
                        backgroundColor: '#ffc107',
                        color: 'white',
                        border: 'none',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        marginRight: '8px'
                      }}
                    >
                      编辑
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div style={{ marginTop: '16px', display: 'flex', justifyContent: 'center', gap: '8px' }}>
        <button
          onClick={() => setCouponsPage(Math.max(1, couponsPage - 1))}
          disabled={couponsPage === 1}
          style={{
            padding: '8px 16px',
            borderRadius: '4px',
            border: '1px solid #ddd',
            backgroundColor: couponsPage === 1 ? '#f5f5f5' : 'white',
            cursor: couponsPage === 1 ? 'not-allowed' : 'pointer'
          }}
        >
          上一页
        </button>
        <span style={{ padding: '8px 16px' }}>
          第 {couponsPage} 页 / 共 {Math.ceil(couponsTotal / 20)} 页
        </span>
        <button
          onClick={() => setCouponsPage(couponsPage + 1)}
          disabled={couponsPage >= Math.ceil(couponsTotal / 20)}
          style={{
            padding: '8px 16px',
            borderRadius: '4px',
            border: '1px solid #ddd',
            backgroundColor: couponsPage >= Math.ceil(couponsTotal / 20) ? '#f5f5f5' : 'white',
            cursor: couponsPage >= Math.ceil(couponsTotal / 20) ? 'not-allowed' : 'pointer'
          }}
        >
          下一页
        </button>
      </div>

      {/* Modal placeholder - Form component will be extracted separately */}
      {showCouponModal && (
        <div className={styles.modalOverlay} onClick={() => setShowCouponModal(false)}>
          <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
            <p>优惠券表单组件（需要从 AdminDashboard 中提取）</p>
            <button onClick={() => setShowCouponModal(false)}>关闭</button>
          </div>
        </div>
      )}
    </div>
  );
};
