import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import { getPromotionCodes, createPromotionCode, updatePromotionCode, deletePromotionCode, getCoupons } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import styles from './CouponManagement.module.css';

interface PromotionCode {
  id: number;
  code: string;
  coupon_id: number;
  coupon_name?: string;
  name?: string;
  description?: string;
  max_uses?: number;
  used_count: number;
  per_user_limit: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
  target_user_type?: string;
  created_at?: string;
}

interface PromotionCodeForm {
  id?: number;
  code: string;
  coupon_id: number;
  name: string;
  description: string;
  max_uses?: number;
  per_user_limit: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
  target_user_type: string;
}

interface CouponOption {
  id: number;
  name: string;
}

const getDefaultValidFrom = () => new Date().toISOString().slice(0, 16);
const getDefaultValidUntil = () => {
  const d = new Date();
  d.setMonth(d.getMonth() + 1);
  return d.toISOString().slice(0, 16);
};

const initialForm: PromotionCodeForm = {
  code: '',
  coupon_id: 0,
  name: '',
  description: '',
  per_user_limit: 1,
  valid_from: getDefaultValidFrom(),
  valid_until: getDefaultValidUntil(),
  is_active: true,
  target_user_type: '',
};

const inputStyle: React.CSSProperties = {
  width: '100%', padding: '8px', border: '1px solid #ddd',
  borderRadius: '4px', marginTop: '5px', boxSizing: 'border-box',
};
const labelStyle: React.CSSProperties = { display: 'block', marginBottom: '5px', fontWeight: 'bold' };
const fieldStyle: React.CSSProperties = { marginBottom: '15px' };
const hintStyle: React.CSSProperties = { color: '#666', fontSize: '12px', marginTop: '5px', display: 'block' };

export const PromotionCodeManagement: React.FC = () => {
  const [couponFilter, setCouponFilter] = useState<string>('');
  const [couponOptions, setCouponOptions] = useState<CouponOption[]>([]);

  // 加载优惠券选项（用于表单下拉和筛选）
  const loadCouponOptions = useCallback(async () => {
    if (couponOptions.length > 0) return;
    try {
      const res = await getCoupons({ page: 1, limit: 100 });
      setCouponOptions((res.data || []).map((c: any) => ({ id: c.id, name: c.name })));
    } catch { /* ignore */ }
  }, [couponOptions.length]);

  const fetchPromos = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const params: any = { page, limit: pageSize };
    if (couponFilter) params.coupon_id = Number(couponFilter);
    const response = await getPromotionCodes(params);
    // 拿到数据后加载优惠券选项
    loadCouponOptions();
    return { data: response.data || [], total: response.total || 0 };
  }, [couponFilter, loadCouponOptions]);

  const handleFetchError = useCallback((error: any) => {
    message.error(`加载推广码列表失败：${getErrorMessage(error)}`);
  }, []);

  const table = useAdminTable<PromotionCode>({
    fetchData: fetchPromos,
    initialPageSize: 20,
    onError: handleFetchError,
  });

  const modal = useModalForm<PromotionCodeForm>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (!values.code?.trim()) { message.error('请填写推广码'); return; }
      if (!values.coupon_id) { message.error('请选择关联优惠券'); return; }
      if (!values.valid_from || !values.valid_until) { message.error('请填写有效期'); return; }
      if (new Date(values.valid_until) <= new Date(values.valid_from)) { message.error('失效时间必须晚于生效时间'); return; }

      if (isEdit && values.id) {
        await updatePromotionCode(values.id, {
          name: values.name || undefined,
          description: values.description || undefined,
          max_uses: values.max_uses,
          per_user_limit: values.per_user_limit,
          valid_until: values.valid_until,
          is_active: values.is_active,
          target_user_type: values.target_user_type || undefined,
        });
        message.success('推广码更新成功');
      } else {
        await createPromotionCode({
          code: values.code.trim().toUpperCase(),
          coupon_id: values.coupon_id,
          name: values.name || undefined,
          description: values.description || undefined,
          max_uses: values.max_uses,
          per_user_limit: values.per_user_limit || 1,
          valid_from: values.valid_from,
          valid_until: values.valid_until,
          is_active: values.is_active,
          target_user_type: values.target_user_type || undefined,
        });
        message.success('推广码创建成功');
      }
      table.refresh();
    },
    onError: (error) => {
      message.error(`操作失败：${error.response?.data?.detail || error.message}`);
    },
  });

  const handleDelete = async (promo: PromotionCode) => {
    if (!window.confirm(`确定要删除推广码"${promo.code}"吗？`)) return;
    try {
      await deletePromotionCode(promo.id);
      message.success('推广码删除成功');
      table.refresh();
    } catch (error: any) {
      message.error(`删除失败：${error.response?.data?.detail || error.message}`);
    }
  };

  const handleEdit = (promo: PromotionCode) => {
    const toDatetimeLocal = (v: string | undefined) => {
      if (!v) return '';
      return new Date(v).toISOString().slice(0, 16);
    };
    loadCouponOptions();
    modal.open({
      id: promo.id,
      code: promo.code,
      coupon_id: promo.coupon_id,
      name: promo.name || '',
      description: promo.description || '',
      max_uses: promo.max_uses,
      per_user_limit: promo.per_user_limit,
      valid_from: toDatetimeLocal(promo.valid_from),
      valid_until: toDatetimeLocal(promo.valid_until),
      is_active: promo.is_active,
      target_user_type: promo.target_user_type || '',
    });
  };

  const handleCreate = () => {
    loadCouponOptions();
    modal.open({
      ...initialForm,
      valid_from: getDefaultValidFrom(),
      valid_until: getDefaultValidUntil(),
    }, true);
  };

  const TARGET_TYPES = [
    { value: '', label: '不限制' },
    { value: 'all', label: '全部用户' },
    { value: 'vip', label: 'VIP' },
    { value: 'super', label: 'Super' },
    { value: 'normal', label: '普通用户' },
  ];

  const columns: Column<PromotionCode>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    {
      key: 'code', title: '推广码', dataIndex: 'code', width: 140,
      render: (value) => <code className={styles.code}>{value}</code>,
    },
    { key: 'coupon_name', title: '关联优惠券', dataIndex: 'coupon_name', width: 160 },
    {
      key: 'usage', title: '使用量', width: 100,
      render: (_, r) => `${r.used_count} / ${r.max_uses ?? '∞'}`,
    },
    {
      key: 'target', title: '目标用户', dataIndex: 'target_user_type', width: 100,
      render: (v) => v || '不限',
    },
    {
      key: 'validity', title: '有效期', width: 200,
      render: (_, r) => (
        <div className={styles.validity}>
          <div>{new Date(r.valid_from).toLocaleDateString()}</div>
          <div>至</div>
          <div>{new Date(r.valid_until).toLocaleDateString()}</div>
        </div>
      ),
    },
    {
      key: 'status', title: '状态', dataIndex: 'is_active', width: 80,
      render: (v) => <StatusBadge text={v ? '启用' : '停用'} variant={v ? 'success' : 'secondary'} />,
    },
    {
      key: 'actions', title: '操作', width: 150, align: 'center',
      render: (_, r) => (
        <div className={styles.actions}>
          <button className={styles.btnEdit} onClick={() => handleEdit(r)}>编辑</button>
          <button className={styles.btnDelete} onClick={() => handleDelete(r)}>删除</button>
        </div>
      ),
    },
  ];

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2 className={styles.title}>推广码管理</h2>
        <button className={styles.btnCreate} onClick={handleCreate}>+ 创建推广码</button>
      </div>

      <div className={styles.filters}>
        <div className={styles.filterGroup}>
          <label>优惠券筛选：</label>
          <select
            value={couponFilter}
            onChange={(e) => { setCouponFilter(e.target.value); }}
            className={styles.select}
            onFocus={loadCouponOptions}
          >
            <option value="">全部优惠券</option>
            {couponOptions.map((c) => (
              <option key={c.id} value={String(c.id)}>{c.name}</option>
            ))}
          </select>
        </div>
      </div>

      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        refreshing={table.fetching}
        rowKey="id"
        emptyText="暂无推广码数据"
        className={styles.table}
      />

      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      {/* Form Modal */}
      {modal.isOpen && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.5)', display: 'flex',
          justifyContent: 'center', alignItems: 'center', zIndex: 1000,
        }}>
          <div style={{
            background: 'white', padding: '30px', borderRadius: '8px',
            boxShadow: '0 4px 20px rgba(0,0,0,0.3)', minWidth: '480px',
            maxWidth: '580px', maxHeight: '90vh', overflowY: 'auto',
          }}>
            <h3 style={{ margin: '0 0 20px 0', color: '#333' }}>
              {modal.isEdit ? '编辑推广码' : '创建推广码'}
            </h3>

            <div style={fieldStyle}>
              <label style={labelStyle}>推广码 <span style={{ color: 'red' }}>*</span></label>
              <input
                type="text"
                value={modal.formData.code}
                onChange={(e) => modal.setFormData(prev => ({ ...prev, code: e.target.value.toUpperCase() }))}
                placeholder="例如: SUMMER2026"
                disabled={modal.isEdit}
                style={inputStyle}
              />
            </div>

            <div style={fieldStyle}>
              <label style={labelStyle}>关联优惠券 <span style={{ color: 'red' }}>*</span></label>
              <select
                value={modal.formData.coupon_id || ''}
                onChange={(e) => modal.setFormData(prev => ({ ...prev, coupon_id: Number(e.target.value) }))}
                disabled={modal.isEdit}
                style={inputStyle}
              >
                <option value="">请选择优惠券</option>
                {couponOptions.map((c) => (
                  <option key={c.id} value={c.id}>{c.name} (ID: {c.id})</option>
                ))}
              </select>
            </div>

            <div style={fieldStyle}>
              <label style={labelStyle}>名称</label>
              <input
                type="text"
                value={modal.formData.name}
                onChange={(e) => modal.setFormData(prev => ({ ...prev, name: e.target.value }))}
                placeholder="推广码名称（可选）"
                style={inputStyle}
              />
            </div>

            <div style={fieldStyle}>
              <label style={labelStyle}>描述</label>
              <textarea
                value={modal.formData.description}
                onChange={(e) => modal.setFormData(prev => ({ ...prev, description: e.target.value }))}
                placeholder="推广码描述（可选）"
                rows={2}
                style={{ ...inputStyle, resize: 'vertical' }}
              />
            </div>

            <div style={{ ...fieldStyle, display: 'flex', gap: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={labelStyle}>最大使用次数</label>
                <input
                  type="number"
                  value={modal.formData.max_uses ?? ''}
                  onChange={(e) => modal.setFormData(prev => ({ ...prev, max_uses: e.target.value ? Number(e.target.value) : undefined }))}
                  placeholder="留空不限制"
                  min="1"
                  style={inputStyle}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={labelStyle}>每用户限用</label>
                <input
                  type="number"
                  value={modal.formData.per_user_limit}
                  onChange={(e) => modal.setFormData(prev => ({ ...prev, per_user_limit: Number(e.target.value) || 1 }))}
                  min="1"
                  style={inputStyle}
                />
              </div>
            </div>

            <div style={fieldStyle}>
              <label style={labelStyle}>目标用户类型</label>
              <select
                value={modal.formData.target_user_type}
                onChange={(e) => modal.setFormData(prev => ({ ...prev, target_user_type: e.target.value }))}
                style={inputStyle}
              >
                {TARGET_TYPES.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>

            <div style={{ ...fieldStyle, display: 'flex', gap: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={labelStyle}>生效时间 <span style={{ color: 'red' }}>*</span></label>
                <input
                  type="datetime-local"
                  value={modal.formData.valid_from}
                  onChange={(e) => modal.setFormData(prev => ({ ...prev, valid_from: e.target.value }))}
                  disabled={modal.isEdit}
                  style={inputStyle}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={labelStyle}>失效时间 <span style={{ color: 'red' }}>*</span></label>
                <input
                  type="datetime-local"
                  value={modal.formData.valid_until}
                  onChange={(e) => modal.setFormData(prev => ({ ...prev, valid_until: e.target.value }))}
                  style={inputStyle}
                />
              </div>
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={modal.formData.is_active}
                  onChange={(e) => modal.setFormData(prev => ({ ...prev, is_active: e.target.checked }))}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontWeight: 'bold' }}>启用此推广码</span>
              </label>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={modal.close}
                disabled={modal.loading}
                style={{
                  padding: '10px 20px', border: '1px solid #ddd', background: 'white',
                  color: '#666', borderRadius: '4px',
                  cursor: modal.loading ? 'not-allowed' : 'pointer',
                  opacity: modal.loading ? 0.6 : 1,
                }}
              >取消</button>
              <button
                onClick={modal.handleSubmit}
                disabled={modal.loading}
                style={{
                  padding: '10px 20px', border: 'none', background: '#007bff',
                  color: 'white', borderRadius: '4px',
                  cursor: modal.loading ? 'not-allowed' : 'pointer',
                  opacity: modal.loading ? 0.6 : 1,
                }}
              >
                {modal.loading ? '提交中...' : modal.isEdit ? '更新' : '创建'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PromotionCodeManagement;
