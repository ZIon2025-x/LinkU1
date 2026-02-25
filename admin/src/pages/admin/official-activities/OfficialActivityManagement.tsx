import React, { useState, useCallback, useEffect } from 'react';
import { message, Modal } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
import { getErrorMessage } from '../../../utils/errorHandler';
import { resolveImageUrl } from '../../../utils/urlUtils';
import api from '../../../api';
import { uploadImage } from '../../../api';

// ==================== Interfaces ====================

type TabKey = 'account' | 'activities';
type ActivityType = 'lottery' | 'first_come';
type PrizeType = 'points' | 'physical' | 'voucher_code' | 'in_person';
type DrawMode = 'auto' | 'manual';
type ActivityStatus = 'active' | 'completed' | 'cancelled' | 'drawn';

interface OfficialAccount {
  user_id: string;
  username?: string;
  official_badge?: string;
  is_active?: boolean;
}

interface OfficialActivity {
  id: number;
  title: string;
  title_en?: string;
  title_zh?: string;
  description: string;
  description_en?: string;
  description_zh?: string;
  location?: string;
  activity_type: ActivityType;
  prize_type: PrizeType;
  prize_description?: string;
  prize_description_en?: string;
  prize_count: number;
  voucher_codes?: string[];
  draw_mode?: DrawMode;
  draw_at?: string;
  deadline?: string;
  images?: string[];
  is_public: boolean;
  status: ActivityStatus;
  applicant_count?: number;
  created_at: string;
  updated_at?: string;
}

interface Applicant {
  id: number;
  user_id: string;
  user_name?: string;
  status: string;
  applied_at: string;
}

interface ActivityFormData {
  id?: number;
  title: string;
  title_en: string;
  title_zh: string;
  description: string;
  description_en: string;
  description_zh: string;
  location: string;
  activity_type: ActivityType;
  prize_type: PrizeType;
  prize_description: string;
  prize_description_en: string;
  prize_count: number;
  max_participants: number;
  voucher_codes_text: string;
  draw_mode: DrawMode;
  draw_at: string;
  deadline: string;
  images: string[];
  is_public: boolean;
  status?: ActivityStatus;
}

const initialFormData: ActivityFormData = {
  title: '',
  title_en: '',
  title_zh: '',
  description: '',
  description_en: '',
  description_zh: '',
  location: '',
  activity_type: 'first_come',
  prize_type: 'points',
  prize_description: '',
  prize_description_en: '',
  prize_count: 1,
  max_participants: 0,
  voucher_codes_text: '',
  draw_mode: 'auto',
  draw_at: '',
  deadline: '',
  images: [],
  is_public: true,
};

// ==================== API helpers ====================

async function setupOfficialAccount(data: { user_id: string; official_badge?: string }) {
  const res = await api.post('/api/admin/official/account/setup', data);
  return res.data;
}

async function getOfficialAccount() {
  const res = await api.get('/api/admin/official/account');
  return res.data;
}

async function createOfficialActivity(data: Record<string, any>) {
  const res = await api.post('/api/admin/official/activities', data);
  return res.data;
}

async function updateOfficialActivity(id: number, data: Record<string, any>) {
  const res = await api.put(`/api/admin/official/activities/${id}`, data);
  return res.data;
}

async function cancelOfficialActivity(id: number) {
  const res = await api.delete(`/api/admin/official/activities/${id}`);
  return res.data;
}

async function getActivityApplicants(id: number) {
  const res = await api.get(`/api/admin/official/activities/${id}/applicants`);
  return res.data;
}

async function drawActivity(id: number) {
  const res = await api.post(`/api/admin/official/activities/${id}/draw`);
  return res.data;
}

// ==================== Label maps ====================

const activityTypeLabels: Record<ActivityType, string> = {
  lottery: '抽奖',
  first_come: '先到先得',
};

const prizeTypeLabels: Record<PrizeType, string> = {
  points: '积分',
  physical: '实物',
  voucher_code: '兑换码',
  in_person: '线下领取',
};

const statusColors: Record<string, { bg: string; color: string }> = {
  active: { bg: '#d4edda', color: '#155724' },
  completed: { bg: '#cce5ff', color: '#004085' },
  cancelled: { bg: '#f8d7da', color: '#721c24' },
  drawn: { bg: '#fff3cd', color: '#856404' },
};

const statusLabels: Record<string, string> = {
  active: '进行中',
  completed: '已完成',
  cancelled: '已取消',
  drawn: '已开奖',
};

// ==================== Component ====================

const OfficialActivityManagement: React.FC = () => {
  const [activeTab, setActiveTab] = useState<TabKey>('activities');

  // --- Official Account state ---
  const [account, setAccount] = useState<OfficialAccount | null>(null);
  const [accountLoading, setAccountLoading] = useState(false);
  const [accountUserId, setAccountUserId] = useState('');
  const [accountBadge, setAccountBadge] = useState('');
  const [accountSubmitting, setAccountSubmitting] = useState(false);

  // --- Applicants modal ---
  const [applicantsVisible, setApplicantsVisible] = useState(false);
  const [applicants, setApplicants] = useState<Applicant[]>([]);
  const [applicantsLoading, setApplicantsLoading] = useState(false);
  const [applicantsActivityTitle, setApplicantsActivityTitle] = useState('');

  // ==================== Official Account ====================

  const loadAccount = useCallback(async () => {
    setAccountLoading(true);
    try {
      const data = await getOfficialAccount();
      const acct = data?.official_account;
      if (acct) {
        setAccount({
          user_id: acct.user_id,
          username: acct.name,
          official_badge: acct.badge,
          is_active: acct.status === 'active',
        });
      } else {
        setAccount(null);
      }
    } catch {
      setAccount(null);
    } finally {
      setAccountLoading(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === 'account') {
      loadAccount();
    }
  }, [activeTab, loadAccount]);

  const handleSetupAccount = useCallback(async () => {
    if (!accountUserId.trim()) {
      message.warning('请输入用户 ID');
      return;
    }
    setAccountSubmitting(true);
    try {
      await setupOfficialAccount({
        user_id: accountUserId.trim(),
        official_badge: accountBadge.trim() || undefined,
      });
      message.success('官方账号设置成功');
      setAccountUserId('');
      setAccountBadge('');
      loadAccount();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setAccountSubmitting(false);
    }
  }, [accountUserId, accountBadge, loadAccount]);

  // ==================== Activities Table ====================

  const fetchActivities = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const res = await api.get('/api/admin/official/activities', {
      params: { page, limit: pageSize },
    });
    const data = res.data;
    return {
      data: data.items || data.data || data.activities || [],
      total: data.total || 0,
    };
  }, []);

  const activitiesTable = useAdminTable<OfficialActivity>({
    fetchData: fetchActivities,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  // ==================== Activity form modal ====================

  const activityModal = useModalForm<ActivityFormData>({
    initialValues: initialFormData,
    onSubmit: async (values, isEdit) => {
      if (!values.title.trim()) {
        message.warning('请填写活动标题');
        throw new Error('validation');
      }
      if (!values.description.trim()) {
        message.warning('请填写活动描述');
        throw new Error('validation');
      }
      if (values.prize_count < 1) {
        message.warning('奖品数量至少为 1');
        throw new Error('validation');
      }
      if (values.activity_type === 'lottery' && values.draw_mode === 'auto' && !values.draw_at) {
        message.warning('自动开奖需要设置开奖时间');
        throw new Error('validation');
      }

      const voucherCodes = values.voucher_codes_text
        .split('\n')
        .map((c) => c.trim())
        .filter(Boolean);

      if (values.prize_type === 'voucher_code' && voucherCodes.length === 0 && !isEdit) {
        message.warning('兑换码类型需要填写兑换码');
        throw new Error('validation');
      }

      const payload: Record<string, any> = {
        title: values.title.trim(),
        description: values.description.trim(),
        activity_type: values.activity_type,
        prize_type: values.prize_type,
        prize_count: values.prize_count,
        is_public: values.is_public,
      };

      if (values.max_participants > 0) payload.max_participants = values.max_participants;
      if (values.title_en.trim()) payload.title_en = values.title_en.trim();
      if (values.title_zh.trim()) payload.title_zh = values.title_zh.trim();
      if (values.description_en.trim()) payload.description_en = values.description_en.trim();
      if (values.description_zh.trim()) payload.description_zh = values.description_zh.trim();
      if (values.location.trim()) payload.location = values.location.trim();
      if (values.prize_description.trim()) payload.prize_description = values.prize_description.trim();
      if (values.prize_description_en.trim()) payload.prize_description_en = values.prize_description_en.trim();
      if (values.deadline) payload.deadline = values.deadline;
      if (values.images.length > 0) payload.images = values.images;

      if (values.activity_type === 'lottery') {
        payload.draw_mode = values.draw_mode;
        if (values.draw_mode === 'auto' && values.draw_at) {
          payload.draw_at = values.draw_at;
        }
      }

      if (values.prize_type === 'voucher_code' && voucherCodes.length > 0) {
        payload.voucher_codes = voucherCodes;
      }

      if (isEdit && values.id) {
        await updateOfficialActivity(values.id, payload);
        message.success('活动更新成功');
      } else {
        await createOfficialActivity(payload);
        message.success('活动创建成功');
      }

      activitiesTable.refresh();
    },
    onError: (error: any) => {
      if (error?.message !== 'validation') {
        message.error(getErrorMessage(error));
      }
    },
  });

  // ==================== Handlers ====================

  const handleEdit = useCallback((activity: OfficialActivity) => {
    activityModal.open({
      id: activity.id,
      title: activity.title,
      title_en: activity.title_en || '',
      title_zh: activity.title_zh || '',
      description: activity.description,
      description_en: activity.description_en || '',
      description_zh: activity.description_zh || '',
      location: activity.location || '',
      activity_type: activity.activity_type,
      prize_type: activity.prize_type,
      prize_description: activity.prize_description || '',
      prize_description_en: activity.prize_description_en || '',
      prize_count: activity.prize_count,
      max_participants: 0,
      voucher_codes_text: (activity.voucher_codes || []).join('\n'),
      draw_mode: activity.draw_mode || 'auto',
      draw_at: activity.draw_at ? activity.draw_at.slice(0, 16) : '',
      deadline: activity.deadline ? activity.deadline.slice(0, 16) : '',
      images: activity.images || [],
      is_public: activity.is_public,
      status: activity.status,
    });
  }, [activityModal]);

  const handleCancel = useCallback((activity: OfficialActivity) => {
    Modal.confirm({
      title: '取消活动',
      content: `确定要取消活动「${activity.title}」吗？此操作不可撤销。`,
      okText: '确认取消',
      cancelText: '返回',
      okType: 'danger',
      onOk: async () => {
        try {
          await cancelOfficialActivity(activity.id);
          message.success('活动已取消');
          activitiesTable.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      },
    });
  }, [activitiesTable]);

  const handleViewApplicants = useCallback(async (activity: OfficialActivity) => {
    setApplicantsActivityTitle(activity.title);
    setApplicantsVisible(true);
    setApplicantsLoading(true);
    try {
      const data = await getActivityApplicants(activity.id);
      setApplicants(data.applicants || data.items || data || []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
      setApplicants([]);
    } finally {
      setApplicantsLoading(false);
    }
  }, []);

  const handleDraw = useCallback((activity: OfficialActivity) => {
    Modal.confirm({
      title: '手动开奖',
      content: `确定要对活动「${activity.title}」进行开奖吗？`,
      okText: '确认开奖',
      cancelText: '取消',
      onOk: async () => {
        try {
          await drawActivity(activity.id);
          message.success('开奖成功');
          activitiesTable.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      },
    });
  }, [activitiesTable]);

  // ==================== Table columns ====================

  const activityColumns: Column<OfficialActivity>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 60,
    },
    {
      key: 'title',
      title: '标题',
      width: 200,
      render: (_, record) => (
        <span style={{ fontWeight: 500 }}>{record.title}</span>
      ),
    },
    {
      key: 'activity_type',
      title: '类型',
      width: 90,
      render: (_, record) => (
        <span style={{
          padding: '2px 8px',
          borderRadius: '4px',
          background: record.activity_type === 'lottery' ? '#e8daef' : '#d5f5e3',
          color: record.activity_type === 'lottery' ? '#6c3483' : '#1e8449',
          fontSize: '12px',
        }}>
          {activityTypeLabels[record.activity_type]}
        </span>
      ),
    },
    {
      key: 'prize_type',
      title: '奖品类型',
      width: 90,
      render: (_, record) => prizeTypeLabels[record.prize_type] || record.prize_type,
    },
    {
      key: 'prize_count',
      title: '奖品数',
      dataIndex: 'prize_count',
      width: 70,
      align: 'center',
    },
    {
      key: 'status',
      title: '状态',
      width: 80,
      render: (_, record) => {
        const style = statusColors[record.status] || { bg: '#f0f0f0', color: '#333' };
        return (
          <span style={{
            padding: '2px 8px',
            borderRadius: '4px',
            background: style.bg,
            color: style.color,
            fontSize: '12px',
          }}>
            {statusLabels[record.status] || record.status}
          </span>
        );
      },
    },
    {
      key: 'created_at',
      title: '创建时间',
      width: 150,
      render: (_, record) => new Date(record.created_at).toLocaleString('zh-CN'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 260,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center', flexWrap: 'wrap' }}>
          <button
            onClick={() => handleEdit(record)}
            style={actionBtnStyle('#007bff', 'white')}
          >
            编辑
          </button>
          <button
            onClick={() => handleViewApplicants(record)}
            style={actionBtnStyle('#17a2b8', 'white')}
          >
            报名者
          </button>
          {record.activity_type === 'lottery' &&
            record.status === 'active' &&
            record.draw_mode === 'manual' && (
              <button
                onClick={() => handleDraw(record)}
                style={actionBtnStyle('#ffc107', '#212529')}
              >
                开奖
              </button>
            )}
          {record.status === 'active' && (
            <button
              onClick={() => handleCancel(record)}
              style={actionBtnStyle('#dc3545', 'white')}
            >
              取消
            </button>
          )}
        </div>
      ),
    },
  ];

  const applicantColumns: Column<Applicant>[] = [
    { key: 'user_name', title: '用户', width: 150, render: (_, r) => r.user_name || r.user_id },
    {
      key: 'status',
      title: '状态',
      width: 100,
      render: (_, r) => {
        const map: Record<string, { bg: string; color: string; label: string }> = {
          applied: { bg: '#cce5ff', color: '#004085', label: '已报名' },
          won: { bg: '#d4edda', color: '#155724', label: '中奖' },
          not_won: { bg: '#f8d7da', color: '#721c24', label: '未中奖' },
        };
        const s = map[r.status] || { bg: '#f0f0f0', color: '#333', label: r.status };
        return (
          <span style={{ padding: '2px 8px', borderRadius: '4px', background: s.bg, color: s.color, fontSize: '12px' }}>
            {s.label}
          </span>
        );
      },
    },
    {
      key: 'applied_at',
      title: '报名时间',
      width: 160,
      render: (_, r) => new Date(r.applied_at).toLocaleString('zh-CN'),
    },
  ];

  // ==================== Modal footer ====================

  const activityModalFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={activityModal.close}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        取消
      </button>
      <button
        onClick={activityModal.handleSubmit}
        disabled={activityModal.loading}
        style={{
          padding: '8px 16px',
          border: 'none',
          borderRadius: '4px',
          background: '#007bff',
          color: 'white',
          cursor: activityModal.loading ? 'not-allowed' : 'pointer',
          opacity: activityModal.loading ? 0.7 : 1,
        }}
      >
        {activityModal.loading ? '提交中...' : activityModal.isEdit ? '更新' : '创建'}
      </button>
    </div>
  );

  // ==================== Render ====================

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>官方活动管理</h2>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        {([
          { key: 'account' as TabKey, label: '官方账号' },
          { key: 'activities' as TabKey, label: '活动管理' },
        ]).map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: activeTab === tab.key ? '#007bff' : '#f0f0f0',
              color: activeTab === tab.key ? 'white' : 'black',
              cursor: 'pointer',
              borderRadius: '5px',
              fontSize: '14px',
              fontWeight: '500',
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* ==================== Tab: Official Account ==================== */}
      {activeTab === 'account' && (
        <div style={{ maxWidth: '600px' }}>
          {/* Current account info */}
          <div style={{ background: 'white', borderRadius: '8px', padding: '20px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', marginBottom: '24px' }}>
            <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>当前官方账号</h3>
            {accountLoading ? (
              <div style={{ color: '#999' }}>加载中...</div>
            ) : account ? (
              <div style={{ fontSize: '14px', lineHeight: '2' }}>
                <div><strong>用户 ID：</strong>{account.user_id}</div>
                {account.username && <div><strong>用户名：</strong>{account.username}</div>}
                <div>
                  <strong>徽章：</strong>
                  {account.official_badge || (
                    <span style={{ color: '#999' }}>未设置</span>
                  )}
                </div>
                <div>
                  <strong>状态：</strong>
                  <span style={{
                    padding: '2px 8px',
                    borderRadius: '4px',
                    background: account.is_active !== false ? '#d4edda' : '#f8d7da',
                    color: account.is_active !== false ? '#155724' : '#721c24',
                    fontSize: '12px',
                    marginLeft: '4px',
                  }}>
                    {account.is_active !== false ? '已启用' : '已禁用'}
                  </span>
                </div>
              </div>
            ) : (
              <div style={{ color: '#999' }}>尚未设置官方账号</div>
            )}
          </div>

          {/* Setup form */}
          <div style={{ background: 'white', borderRadius: '8px', padding: '20px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
            <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>设置官方账号</h3>
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                用户 ID <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="text"
                value={accountUserId}
                onChange={(e) => setAccountUserId(e.target.value)}
                placeholder="请输入用户 ID"
                style={inputStyle}
              />
            </div>
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>官方徽章文字</label>
              <input
                type="text"
                value={accountBadge}
                onChange={(e) => setAccountBadge(e.target.value)}
                placeholder="例如：官方、LinkU Official"
                style={inputStyle}
              />
            </div>
            <button
              onClick={handleSetupAccount}
              disabled={accountSubmitting}
              style={{
                padding: '10px 20px',
                border: 'none',
                background: accountSubmitting ? '#6c757d' : '#28a745',
                color: 'white',
                borderRadius: '4px',
                cursor: accountSubmitting ? 'not-allowed' : 'pointer',
                fontSize: '14px',
                fontWeight: '500',
              }}
            >
              {accountSubmitting ? '提交中...' : '设置账号'}
            </button>
          </div>
        </div>
      )}

      {/* ==================== Tab: Activities ==================== */}
      {activeTab === 'activities' && (
        <>
          {/* Create button */}
          <div style={{ marginBottom: '16px', textAlign: 'right' }}>
            <button
              onClick={() => activityModal.open()}
              style={{
                padding: '10px 20px',
                border: 'none',
                background: '#28a745',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: '500',
              }}
            >
              创建活动
            </button>
          </div>

          {/* Table */}
          <AdminTable
            columns={activityColumns}
            data={activitiesTable.data}
            loading={activitiesTable.loading}
            refreshing={activitiesTable.fetching}
            rowKey="id"
            emptyText="暂无活动数据"
          />

          <AdminPagination
            currentPage={activitiesTable.currentPage}
            totalPages={activitiesTable.totalPages}
            total={activitiesTable.total}
            pageSize={activitiesTable.pageSize}
            onPageChange={activitiesTable.setCurrentPage}
            onPageSizeChange={activitiesTable.setPageSize}
          />
        </>
      )}

      {/* ==================== Activity Form Modal ==================== */}
      <AdminModal
        isOpen={activityModal.isOpen}
        onClose={activityModal.close}
        title={activityModal.isEdit ? '编辑活动' : '创建活动'}
        footer={activityModalFooter}
        width="700px"
      >
        <div style={{ padding: '20px 0', maxHeight: '60vh', overflowY: 'auto' }}>
          {/* Title */}
          <FormField label="标题" required>
            <input
              type="text"
              value={activityModal.formData.title}
              onChange={(e) => activityModal.updateField('title', e.target.value)}
              placeholder="活动标题（必填）"
              style={inputStyle}
            />
          </FormField>

          {/* Title EN / ZH */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <FormField label="英文标题">
              <input
                type="text"
                value={activityModal.formData.title_en}
                onChange={(e) => activityModal.updateField('title_en', e.target.value)}
                placeholder="English title"
                style={inputStyle}
              />
            </FormField>
            <FormField label="中文标题">
              <input
                type="text"
                value={activityModal.formData.title_zh}
                onChange={(e) => activityModal.updateField('title_zh', e.target.value)}
                placeholder="中文标题"
                style={inputStyle}
              />
            </FormField>
          </div>

          {/* Description */}
          <FormField label="描述" required>
            <textarea
              value={activityModal.formData.description}
              onChange={(e) => activityModal.updateField('description', e.target.value)}
              placeholder="活动描述（必填）"
              rows={3}
              style={{ ...inputStyle, resize: 'vertical' }}
            />
          </FormField>

          {/* Description EN / ZH */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <FormField label="英文描述">
              <textarea
                value={activityModal.formData.description_en}
                onChange={(e) => activityModal.updateField('description_en', e.target.value)}
                placeholder="English description"
                rows={2}
                style={{ ...inputStyle, resize: 'vertical' }}
              />
            </FormField>
            <FormField label="中文描述">
              <textarea
                value={activityModal.formData.description_zh}
                onChange={(e) => activityModal.updateField('description_zh', e.target.value)}
                placeholder="中文描述"
                rows={2}
                style={{ ...inputStyle, resize: 'vertical' }}
              />
            </FormField>
          </div>

          {/* Location */}
          <FormField label="地点">
            <input
              type="text"
              value={activityModal.formData.location}
              onChange={(e) => activityModal.updateField('location', e.target.value)}
              placeholder="活动地点"
              style={inputStyle}
            />
          </FormField>

          {/* Activity type + Prize type */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <FormField label="活动类型" required>
              <select
                value={activityModal.formData.activity_type}
                onChange={(e) => activityModal.updateField('activity_type', e.target.value as ActivityType)}
                style={inputStyle}
              >
                <option value="first_come">先到先得</option>
                <option value="lottery">抽奖</option>
              </select>
            </FormField>
            <FormField label="奖品类型" required>
              <select
                value={activityModal.formData.prize_type}
                onChange={(e) => activityModal.updateField('prize_type', e.target.value as PrizeType)}
                style={inputStyle}
              >
                <option value="points">积分</option>
                <option value="physical">实物</option>
                <option value="voucher_code">兑换码</option>
                <option value="in_person">线下领取</option>
              </select>
            </FormField>
          </div>

          {/* Lottery-specific: draw_mode + draw_at */}
          {activityModal.formData.activity_type === 'lottery' && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <FormField label="开奖方式" required>
                <select
                  value={activityModal.formData.draw_mode}
                  onChange={(e) => activityModal.updateField('draw_mode', e.target.value as DrawMode)}
                  style={inputStyle}
                >
                  <option value="auto">自动开奖</option>
                  <option value="manual">手动开奖</option>
                </select>
              </FormField>
              {activityModal.formData.draw_mode === 'auto' && (
                <FormField label="开奖时间" required>
                  <input
                    type="datetime-local"
                    value={activityModal.formData.draw_at}
                    onChange={(e) => activityModal.updateField('draw_at', e.target.value)}
                    style={inputStyle}
                  />
                </FormField>
              )}
            </div>
          )}

          {/* Prize description + count */}
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '12px' }}>
            <FormField label="奖品描述">
              <input
                type="text"
                value={activityModal.formData.prize_description}
                onChange={(e) => activityModal.updateField('prize_description', e.target.value)}
                placeholder="奖品描述"
                style={inputStyle}
              />
            </FormField>
            <FormField label="奖品数量" required>
              <input
                type="number"
                min={1}
                value={activityModal.formData.prize_count}
                onChange={(e) => activityModal.updateField('prize_count', parseInt(e.target.value) || 1)}
                style={inputStyle}
              />
            </FormField>
          </div>

          {/* Max participants */}
          <FormField label="最大参与人数">
            <input
              type="number"
              min={0}
              value={activityModal.formData.max_participants}
              onChange={(e) => activityModal.updateField('max_participants', parseInt(e.target.value) || 0)}
              placeholder="0 = 自动（奖品数量 × 10）"
              style={inputStyle}
            />
            <div style={{ fontSize: '12px', color: '#888', marginTop: '4px' }}>
              留 0 或空则自动设为奖品数量 × 10。抽奖活动建议不设上限以吸引更多参与。
            </div>
          </FormField>

          {/* Prize description EN */}
          <FormField label="英文奖品描述">
            <input
              type="text"
              value={activityModal.formData.prize_description_en}
              onChange={(e) => activityModal.updateField('prize_description_en', e.target.value)}
              placeholder="Prize description in English"
              style={inputStyle}
            />
          </FormField>

          {/* Voucher codes (conditional) */}
          {activityModal.formData.prize_type === 'voucher_code' && (
            <FormField label="兑换码" required>
              <textarea
                value={activityModal.formData.voucher_codes_text}
                onChange={(e) => activityModal.updateField('voucher_codes_text', e.target.value)}
                placeholder="每行一个兑换码"
                rows={4}
                style={{ ...inputStyle, resize: 'vertical', fontFamily: 'monospace' }}
              />
              <div style={{ fontSize: '12px', color: '#999', marginTop: '4px' }}>
                已输入 {activityModal.formData.voucher_codes_text.split('\n').filter((c) => c.trim()).length} 个兑换码
              </div>
            </FormField>
          )}

          {/* Images upload */}
          <FormField label="活动图片">
            <input
              type="file"
              accept="image/*"
              onChange={async (e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                try {
                  const result = await uploadImage(file);
                  const url = result.url || result.image_url;
                  if (url) {
                    activityModal.updateField('images', [...activityModal.formData.images, url]);
                    message.success('图片上传成功');
                  }
                } catch (err: any) {
                  message.error(getErrorMessage(err));
                }
                e.target.value = '';
              }}
            />
            {activityModal.formData.images.length > 0 && (
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '10px' }}>
                {activityModal.formData.images.map((url, i) => (
                  <div key={i} style={{ position: 'relative' }}>
                    <img
                      src={resolveImageUrl(url)}
                      alt={`活动图片 ${i + 1}`}
                      style={{ width: '80px', height: '80px', objectFit: 'cover', borderRadius: '4px' }}
                    />
                    <button
                      type="button"
                      onClick={() => {
                        activityModal.updateField('images', activityModal.formData.images.filter((_, idx) => idx !== i));
                      }}
                      style={{
                        position: 'absolute', top: '-6px', right: '-6px',
                        width: '20px', height: '20px', borderRadius: '50%',
                        border: 'none', background: '#dc3545', color: 'white',
                        cursor: 'pointer', fontSize: '12px', lineHeight: '20px',
                        textAlign: 'center', padding: 0,
                      }}
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}
          </FormField>

          {/* Deadline */}
          <FormField label="截止时间">
            <input
              type="datetime-local"
              value={activityModal.formData.deadline}
              onChange={(e) => activityModal.updateField('deadline', e.target.value)}
              style={inputStyle}
            />
          </FormField>

          {/* Is public */}
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={activityModal.formData.is_public}
                onChange={(e) => activityModal.updateField('is_public', e.target.checked)}
              />
              <span>公开活动</span>
            </label>
          </div>
        </div>
      </AdminModal>

      {/* ==================== Applicants Modal ==================== */}
      <AdminModal
        isOpen={applicantsVisible}
        onClose={() => setApplicantsVisible(false)}
        title={`报名者 — ${applicantsActivityTitle}`}
        width="600px"
      >
        <div style={{ padding: '10px 0' }}>
          {applicantsLoading ? (
            <div style={{ textAlign: 'center', padding: '20px', color: '#999' }}>加载中...</div>
          ) : applicants.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '20px', color: '#999' }}>暂无报名者</div>
          ) : (
            <AdminTable
              columns={applicantColumns}
              data={applicants}
              rowKey="id"
              emptyText="暂无报名者"
            />
          )}
        </div>
      </AdminModal>
    </div>
  );
};

// ==================== Shared styles & helpers ====================

const inputStyle: React.CSSProperties = {
  width: '100%',
  padding: '8px',
  border: '1px solid #ddd',
  borderRadius: '4px',
  boxSizing: 'border-box',
};

function actionBtnStyle(bg: string, color: string): React.CSSProperties {
  return {
    padding: '4px 10px',
    border: 'none',
    background: bg,
    color,
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '12px',
    fontWeight: 500,
  };
}

const FormField: React.FC<{
  label: string;
  required?: boolean;
  children: React.ReactNode;
}> = ({ label, required, children }) => (
  <div style={{ marginBottom: '15px' }}>
    <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
      {label} {required && <span style={{ color: 'red' }}>*</span>}
    </label>
    {children}
  </div>
);

export default OfficialActivityManagement;
