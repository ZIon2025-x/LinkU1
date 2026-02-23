import React, { useState } from 'react';
import { message } from 'antd';
import dayjs from 'dayjs';
import { getUsersForAdmin, updateUserByAdmin } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import { User, USER_LEVEL_LABELS, UserLevel } from './types';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
import { exportToCSV, ExportColumn } from '../../../utils/exportUtils';
import styles from './UserManagement.module.css';

const USER_EXPORT_COLUMNS: ExportColumn[] = [
  { key: 'id', label: 'ID' },
  { key: 'name', label: '用户名' },
  { key: 'email', label: '邮箱' },
  { key: 'user_level', label: '等级', format: v => USER_LEVEL_LABELS[v as UserLevel] || v },
  { key: 'is_banned', label: '封禁', format: v => v ? '是' : '否' },
  { key: 'is_suspended', label: '暂停', format: v => v ? '是' : '否' },
  { key: 'task_count', label: '任务数' },
  { key: 'avg_rating', label: '评分', format: v => Number(v).toFixed(1) },
  { key: 'created_at', label: '注册时间', format: v => dayjs(v).format('YYYY-MM-DD') },
];

/**
 * 用户管理组件
 * 提供用户列表查看、搜索、等级修改、封禁/暂停等功能
 */
const UserManagement: React.FC = () => {
  const [error, setError] = useState<string | null>(null);
  const [userActionLoading, setUserActionLoading] = useState<string | null>(null);

  const table = useAdminTable<User>({
    fetchData: async ({ page, pageSize, searchTerm }) => {
      const response = await getUsersForAdmin(page, pageSize, searchTerm || undefined);
      return {
        data: response.users || [],
        total: response.total ?? 0,
      };
    },
    initialPageSize: 20,
    onError: (err) => setError(getErrorMessage(err)),
  });

  interface SuspendForm { userId: string; days: number; }
  const suspendModal = useModalForm<SuspendForm>({
    initialValues: { userId: '', days: 1 },
    onSubmit: async (values) => {
      const suspendUntil = new Date();
      suspendUntil.setDate(suspendUntil.getDate() + values.days);
      await updateUserByAdmin(values.userId, {
        is_suspended: 1,
        suspend_until: suspendUntil.toISOString(),
      });
      message.success(`用户已暂停${values.days}天`);
      table.refresh();
    },
    onError: (err) => message.error(getErrorMessage(err)),
  });

  // 更新用户等级
  const handleUpdateUserLevel = async (userId: string, newLevel: string) => {
    setUserActionLoading(userId);
    try {
      await updateUserByAdmin(userId, { user_level: newLevel });
      message.success('用户等级更新成功！');
      table.refresh();
    } catch (err: any) {
      message.error(getErrorMessage(err));
    } finally {
      setUserActionLoading(null);
    }
  };

  // 封禁/解封用户
  const handleBanUser = async (userId: string, isBanned: number) => {
    setUserActionLoading(userId);
    try {
      await updateUserByAdmin(userId, { is_banned: isBanned });
      message.success(isBanned ? '用户已封禁' : '用户已解封');
      table.refresh();
    } catch (err: any) {
      message.error(getErrorMessage(err));
    } finally {
      setUserActionLoading(null);
    }
  };

  // 暂停/恢复用户
  const handleSuspendUser = async (userId: string, isSuspended: number) => {
    setUserActionLoading(userId);
    try {
      await updateUserByAdmin(userId, { is_suspended: isSuspended });
      message.success(isSuspended ? '用户已暂停' : '用户已恢复');
      table.refresh();
    } catch (err: any) {
      message.error(getErrorMessage(err));
    } finally {
      setUserActionLoading(null);
    }
  };

  const handleExport = () => {
    exportToCSV(
      table.data as Record<string, any>[],
      `users-${dayjs().format('YYYY-MM-DD')}`,
      USER_EXPORT_COLUMNS
    );
  };

  // 获取状态样式
  const getStatusClassName = (user: User) => {
    if (user.is_banned) return styles.statusBanned;
    if (user.is_suspended) return styles.statusSuspended;
    if (user.is_active) return styles.statusActive;
    return styles.statusInactive;
  };

  // 获取状态文本
  const getStatusText = (user: User) => {
    if (user.is_banned) return '已封禁';
    if (user.is_suspended) return '已暂停';
    if (user.is_active) return '正常';
    return '未激活';
  };

  const columns: Column<User>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', fixed: 'left', width: 80 },
    { key: 'name', title: '用户名', dataIndex: 'name', fixed: 'left', width: 120 },
    { key: 'email', title: '邮箱', dataIndex: 'email', width: 200 },
    {
      key: 'user_level', title: '等级', width: 120,
      render: (_, user) => (
        <select
          value={user.user_level}
          onChange={e => handleUpdateUserLevel(user.id, e.target.value)}
          disabled={userActionLoading === user.id}
          className={styles.levelSelect}
        >
          {Object.entries(USER_LEVEL_LABELS).map(([v, l]) => (
            <option key={v} value={v}>{l}</option>
          ))}
        </select>
      ),
    },
    {
      key: 'status', title: '状态', width: 100,
      render: (_, user) => (
        <span className={`${styles.statusBadge} ${getStatusClassName(user)}`}>
          {getStatusText(user)}
        </span>
      ),
    },
    { key: 'task_count', title: '任务数', dataIndex: 'task_count', width: 80 },
    { key: 'avg_rating', title: '评分', width: 80, render: (_, u) => u.avg_rating.toFixed(1) },
    {
      key: 'invitation_code_text', title: '邀请码', width: 120,
      render: (_, u) => u.invitation_code_text
        ? <span className={styles.inviteCode}>{u.invitation_code_text}</span>
        : <span className={styles.placeholder}>-</span>,
    },
    {
      key: 'inviter_id', title: '邀请人', width: 120,
      render: (_, u) => u.inviter_id
        ? <span className={styles.inviterId} onClick={() => table.setSearchTerm(u.inviter_id!)} title="点击查看邀请人信息">{u.inviter_id}</span>
        : <span className={styles.placeholder}>-</span>,
    },
    {
      key: 'created_at', title: '注册时间', width: 120,
      render: (_, u) => dayjs(u.created_at).format('YYYY-MM-DD'),
    },
    {
      key: 'actions', title: '操作', width: 220,
      render: (_, user) => (
        <div className={styles.actionGroup}>
          <button
            onClick={() => handleBanUser(user.id, user.is_banned ? 0 : 1)}
            disabled={userActionLoading === user.id}
            className={`${styles.actionBtn} ${user.is_banned ? styles.btnSuccess : styles.btnDanger}`}
          >
            {user.is_banned ? '解封' : '封禁'}
          </button>
          <button
            onClick={() => user.is_suspended
              ? handleSuspendUser(user.id, 0)
              : suspendModal.open({ userId: user.id, days: 1 })}
            disabled={userActionLoading === user.id}
            className={`${styles.actionBtn} ${user.is_suspended ? styles.btnSuccess : styles.btnWarning}`}
          >
            {user.is_suspended ? '恢复' : '暂停'}
          </button>
          <button
            onClick={() => handleUpdateUserLevel(user.id, 'normal')}
            disabled={userActionLoading === user.id}
            className={`${styles.actionBtn} ${styles.btnPrimary}`}
          >
            重置等级
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2 className={styles.title}>用户管理</h2>
        <button
          onClick={handleExport}
          disabled={table.data.length === 0}
          style={{
            padding: '8px 16px',
            border: '1px solid #52c41a',
            background: 'white',
            color: '#52c41a',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px',
          }}
        >
          导出 CSV
        </button>
      </div>

      <div className={styles.searchContainer}>
        <input
          type="text"
          placeholder="搜索用户ID、用户名或邮箱..."
          value={table.searchTerm}
          onChange={e => table.setSearchTerm(e.target.value)}
          className={styles.searchInput}
        />
      </div>

      {error && <div className={styles.errorMessage}>{error}</div>}

      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        refreshing={table.fetching}
        rowKey="id"
        emptyText="暂无用户数据"
      />

      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
      />

      {/* Suspend modal */}
      <AdminModal
        isOpen={suspendModal.isOpen}
        onClose={suspendModal.close}
        title="暂停用户"
        footer={
          <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
            <button onClick={suspendModal.close} style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', cursor: 'pointer', background: 'white' }}>
              取消
            </button>
            <button
              onClick={suspendModal.handleSubmit}
              disabled={suspendModal.loading}
              style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', cursor: 'pointer', background: '#faad14', color: 'white' }}
            >
              {suspendModal.loading ? '处理中...' : '确认暂停'}
            </button>
          </div>
        }
      >
        <div style={{ padding: '8px 0' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>暂停天数</label>
          <input
            type="number"
            min="1"
            max="365"
            value={suspendModal.formData.days}
            onChange={e => suspendModal.updateField('days', Math.max(1, Math.min(365, parseInt(e.target.value) || 1)))}
            style={{ width: '100%', padding: '8px', border: '1px solid #d9d9d9', borderRadius: '4px', fontSize: '14px' }}
          />
        </div>
      </AdminModal>
    </div>
  );
};

export default UserManagement;
