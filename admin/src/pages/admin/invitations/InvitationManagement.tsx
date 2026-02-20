import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
import {
  getInvitationCodes,
  createInvitationCode,
  updateInvitationCode,
  deleteInvitationCode,
  getInvitationCodeDetail
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface InvitationCode {
  id: number;
  code: string;
  name?: string;
  description?: string;
  reward_type: 'points' | 'coupon' | 'both';
  points_reward?: number;
  points_reward_display?: string;
  coupon_id?: number;
  used_count: number;
  max_uses?: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
}

interface FormData {
  id?: number;
  code: string;
  name: string;
  description: string;
  reward_type: 'points' | 'coupon' | 'both';
  points_reward: number;
  coupon_id?: number;
  max_uses?: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
}

const initialForm: FormData = {
  code: '',
  name: '',
  description: '',
  reward_type: 'points',
  points_reward: 0,
  coupon_id: undefined,
  max_uses: undefined,
  valid_from: '',
  valid_until: '',
  is_active: true
};

/**
 * 邀请码管理组件
 */
const InvitationManagement: React.FC = () => {
  const [codes, setCodes] = useState<InvitationCode[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<FormData>(initialForm);

  const loadCodes = useCallback(async () => {
    setLoading(true);
    try {
      const response = await getInvitationCodes({
        page,
        limit: 20,
        status: statusFilter as 'active' | 'inactive' | undefined
      });
      setCodes(response.data || response.items || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter]);

  useEffect(() => {
    loadCodes();
  }, [loadCodes]);

  const handleCreate = async () => {
    if (!form.code || !form.valid_from || !form.valid_until) {
      message.warning('请填写邀请码、有效期开始时间和结束时间');
      return;
    }

    try {
      await createInvitationCode({
        code: form.code,
        name: form.name || undefined,
        description: form.description || undefined,
        reward_type: form.reward_type,
        points_reward: form.points_reward || undefined,
        coupon_id: form.coupon_id,
        max_uses: form.max_uses,
        valid_from: new Date(form.valid_from).toISOString(),
        valid_until: new Date(form.valid_until).toISOString(),
        is_active: form.is_active
      });
      message.success('邀请码创建成功！');
      setShowModal(false);
      setForm(initialForm);
      loadCodes();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleUpdate = async () => {
    if (!form.id) return;

    try {
      await updateInvitationCode(form.id, {
        name: form.name || undefined,
        description: form.description || undefined,
        is_active: form.is_active,
        max_uses: form.max_uses,
        valid_from: form.valid_from ? new Date(form.valid_from).toISOString() : undefined,
        valid_until: form.valid_until ? new Date(form.valid_until).toISOString() : undefined,
        points_reward: form.points_reward || undefined,
        coupon_id: form.coupon_id
      });
      message.success('邀请码更新成功！');
      setShowModal(false);
      setForm(initialForm);
      loadCodes();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleEdit = async (id: number) => {
    try {
      const detail = await getInvitationCodeDetail(id);
      setForm({
        id: detail.id,
        code: detail.code,
        name: detail.name || '',
        description: detail.description || '',
        reward_type: detail.reward_type,
        points_reward: detail.points_reward || 0,
        coupon_id: detail.coupon_id,
        max_uses: detail.max_uses,
        valid_from: detail.valid_from ? new Date(detail.valid_from).toISOString().slice(0, 16) : '',
        valid_until: detail.valid_until ? new Date(detail.valid_until).toISOString().slice(0, 16) : '',
        is_active: detail.is_active
      });
      setShowModal(true);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleDelete = (id: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个邀请码吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteInvitationCode(id);
          message.success('邀请码删除成功！');
          loadCodes();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const totalPages = Math.ceil(total / 20);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>邀请码管理</h2>
        <button
          onClick={() => { setForm(initialForm); setShowModal(true); }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#28a745',
            color: 'white',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          创建邀请码
        </button>
      </div>

      {/* 筛选器 */}
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', alignItems: 'center' }}>
        <label style={{ fontWeight: 'bold' }}>状态筛选：</label>
        <select
          value={statusFilter}
          onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
          style={{ padding: '8px 12px', border: '1px solid #ddd', borderRadius: '4px', fontSize: '14px' }}
        >
          <option value="">全部</option>
          <option value="active">启用</option>
          <option value="inactive">禁用</option>
        </select>
      </div>

      {/* 列表 */}
      <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : codes.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无邀请码数据</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>邀请码</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>名称</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>奖励类型</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>积分奖励</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>使用次数</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>有效期</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {codes.map((code) => (
                <tr key={code.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{code.code}</td>
                  <td style={{ padding: '12px' }}>{code.name || '-'}</td>
                  <td style={{ padding: '12px' }}>
                    {code.reward_type === 'points' ? '积分' : code.reward_type === 'coupon' ? '优惠券' : '积分+优惠券'}
                  </td>
                  <td style={{ padding: '12px' }}>{code.points_reward_display || '0.00'}</td>
                  <td style={{ padding: '12px' }}>{code.used_count || 0} / {code.max_uses || '∞'}</td>
                  <td style={{ padding: '12px', fontSize: '12px' }}>
                    {new Date(code.valid_from).toLocaleString('zh-CN')} ~<br/>
                    {new Date(code.valid_until).toLocaleString('zh-CN')}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: code.is_active ? '#d4edda' : '#f8d7da',
                      color: code.is_active ? '#155724' : '#721c24',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {code.is_active ? '启用' : '禁用'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button onClick={() => handleEdit(code.id)} style={{ padding: '4px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>编辑</button>
                      <button onClick={() => handleDelete(code.id)} style={{ padding: '4px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>删除</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      {total > 20 && (
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
          <button onClick={() => page > 1 && setPage(page - 1)} disabled={page === 1} style={{ padding: '8px 16px', border: '1px solid #ddd', background: page === 1 ? '#f5f5f5' : 'white', color: page === 1 ? '#999' : '#333', borderRadius: '4px', cursor: page === 1 ? 'not-allowed' : 'pointer' }}>上一页</button>
          <span style={{ padding: '8px 16px', display: 'flex', alignItems: 'center' }}>第 {page} 页，共 {totalPages} 页</span>
          <button onClick={() => page < totalPages && setPage(page + 1)} disabled={page >= totalPages} style={{ padding: '8px 16px', border: '1px solid #ddd', background: page >= totalPages ? '#f5f5f5' : 'white', color: page >= totalPages ? '#999' : '#333', borderRadius: '4px', cursor: page >= totalPages ? 'not-allowed' : 'pointer' }}>下一页</button>
        </div>
      )}

      {/* 模态框 */}
      <Modal
        title={form.id ? '编辑邀请码' : '创建邀请码'}
        open={showModal}
        onCancel={() => { setShowModal(false); setForm(initialForm); }}
        onOk={form.id ? handleUpdate : handleCreate}
        okText={form.id ? '更新' : '创建'}
        cancelText="取消"
        width={600}
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>邀请码 <span style={{ color: 'red' }}>*</span></label>
            <input type="text" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })} disabled={!!form.id} placeholder="请输入邀请码" style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>名称</label>
            <input type="text" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="请输入名称" style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>奖励类型 <span style={{ color: 'red' }}>*</span></label>
            <select value={form.reward_type} onChange={(e) => setForm({ ...form, reward_type: e.target.value as any })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}>
              <option value="points">积分</option>
              <option value="coupon">优惠券</option>
              <option value="both">积分+优惠券</option>
            </select>
          </div>
          {(form.reward_type === 'points' || form.reward_type === 'both') && (
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>积分奖励（分）</label>
              <input type="number" value={form.points_reward} onChange={(e) => setForm({ ...form, points_reward: parseInt(e.target.value) || 0 })} placeholder="100分=1.00" min="0" style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
            </div>
          )}
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>有效期开始时间 <span style={{ color: 'red' }}>*</span></label>
            <input type="datetime-local" value={form.valid_from} onChange={(e) => setForm({ ...form, valid_from: e.target.value })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>有效期结束时间 <span style={{ color: 'red' }}>*</span></label>
            <input type="datetime-local" value={form.valid_until} onChange={(e) => setForm({ ...form, valid_until: e.target.value })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} />
              <span>启用状态</span>
            </label>
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default InvitationManagement;
