import React, { useState, useEffect, useCallback } from 'react';
import { message } from 'antd';
import dayjs from 'dayjs';
import { getUsersForAdmin, updateUserByAdmin } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import { User, UserUpdateData, USER_LEVEL_LABELS, UserLevel } from './types';
import styles from './UserManagement.module.css';

/**
 * 用户管理组件
 * 提供用户列表查看、搜索、等级修改、封禁/暂停等功能
 */
const UserManagement: React.FC = () => {
  // 数据状态
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // 分页状态
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [searchTerm, setSearchTerm] = useState('');
  
  // 操作状态
  const [userActionLoading, setUserActionLoading] = useState<string | null>(null);
  
  // 暂停模态框状态
  const [showSuspendModal, setShowSuspendModal] = useState(false);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [suspendDuration, setSuspendDuration] = useState(1);

  // 加载用户列表
  const loadUsers = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await getUsersForAdmin(currentPage, 20, searchTerm || undefined);
      setUsers(response.users || []);
      setTotalPages(response.total_pages || 1);
    } catch (err: any) {
      const errorMsg = getErrorMessage(err);
      setError(errorMsg);
      console.error('Failed to load users:', err);
    } finally {
      setLoading(false);
    }
  }, [currentPage, searchTerm]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  // 搜索防抖
  useEffect(() => {
    const timer = setTimeout(() => {
      setCurrentPage(1);
    }, 300);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  // 更新用户等级
  const handleUpdateUserLevel = async (userId: string, newLevel: string) => {
    setUserActionLoading(userId);
    try {
      await updateUserByAdmin(userId, { user_level: newLevel });
      message.success('用户等级更新成功！');
      loadUsers();
    } catch (error: any) {
      message.error(getErrorMessage(error));
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
      loadUsers();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setUserActionLoading(null);
    }
  };

  // 暂停/恢复用户
  const handleSuspendUser = async (userId: string, isSuspended: number, suspendUntil?: string) => {
    setUserActionLoading(userId);
    try {
      const updateData: UserUpdateData = { is_suspended: isSuspended };
      if (isSuspended && suspendUntil) {
        updateData.suspend_until = suspendUntil;
      }
      await updateUserByAdmin(userId, updateData);
      message.success(isSuspended ? `用户已暂停${suspendDuration}天` : '用户已恢复');
      loadUsers();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setUserActionLoading(null);
    }
  };

  // 点击暂停按钮
  const handleSuspendClick = (userId: string) => {
    setSelectedUserId(userId);
    setShowSuspendModal(true);
  };

  // 确认暂停
  const handleConfirmSuspend = () => {
    if (!selectedUserId) return;
    
    const suspendUntil = new Date();
    suspendUntil.setDate(suspendUntil.getDate() + suspendDuration);
    
    handleSuspendUser(selectedUserId, 1, suspendUntil.toISOString());
    setShowSuspendModal(false);
    setSelectedUserId(null);
    setSuspendDuration(1);
  };

  // 取消暂停模态框
  const handleCancelSuspend = () => {
    setShowSuspendModal(false);
    setSelectedUserId(null);
    setSuspendDuration(1);
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

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2 className={styles.title}>用户管理</h2>
      </div>

      {/* 搜索框 */}
      <div className={styles.searchContainer}>
        <input
          type="text"
          placeholder="搜索用户ID、用户名或邮箱..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className={styles.searchInput}
        />
      </div>

      {/* 错误提示 */}
      {error && (
        <div className={styles.errorMessage}>{error}</div>
      )}

      {/* 用户表格 */}
      <div className={styles.tableContainer}>
        <table className={styles.table}>
          <thead className={styles.tableHeader}>
            <tr>
              <th className={`${styles.tableHeaderCell} ${styles.stickyCell} ${styles.stickyIdCell}`}>ID</th>
              <th className={`${styles.tableHeaderCell} ${styles.stickyCell} ${styles.stickyNameCell}`}>用户名</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '200px' }}>邮箱</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '120px' }}>等级</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '100px' }}>状态</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '80px' }}>任务数</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '80px' }}>评分</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '120px' }}>邀请码</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '120px' }}>邀请人</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '120px' }}>注册时间</th>
              <th className={styles.tableHeaderCell} style={{ minWidth: '200px' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={11} className={styles.emptyRow}>加载中...</td>
              </tr>
            ) : users && users.length > 0 ? (
              users.map(user => (
                <tr key={user.id} className={styles.tableRow}>
                  {/* ID */}
                  <td className={`${styles.tableCell} ${styles.tableCellSticky} ${styles.stickyCell} ${styles.stickyIdCell}`}>
                    {user.id}
                  </td>
                  {/* 用户名 */}
                  <td className={`${styles.tableCell} ${styles.tableCellSticky} ${styles.stickyCell} ${styles.stickyNameCell}`}>
                    {user.name}
                  </td>
                  {/* 邮箱 */}
                  <td className={styles.tableCell}>{user.email}</td>
                  {/* 等级选择 */}
                  <td className={styles.tableCell}>
                    <select
                      value={user.user_level}
                      onChange={(e) => handleUpdateUserLevel(user.id, e.target.value)}
                      disabled={userActionLoading === user.id}
                      className={styles.levelSelect}
                    >
                      {Object.entries(USER_LEVEL_LABELS).map(([value, label]) => (
                        <option key={value} value={value}>{label}</option>
                      ))}
                    </select>
                  </td>
                  {/* 状态 */}
                  <td className={styles.tableCell}>
                    <span className={`${styles.statusBadge} ${getStatusClassName(user)}`}>
                      {getStatusText(user)}
                    </span>
                  </td>
                  {/* 任务数 */}
                  <td className={styles.tableCell}>{user.task_count}</td>
                  {/* 评分 */}
                  <td className={styles.tableCell}>{user.avg_rating.toFixed(1)}</td>
                  {/* 邀请码 */}
                  <td className={styles.tableCell}>
                    {user.invitation_code_text ? (
                      <span className={styles.inviteCode}>{user.invitation_code_text}</span>
                    ) : (
                      <span className={styles.placeholder}>-</span>
                    )}
                  </td>
                  {/* 邀请人 */}
                  <td className={styles.tableCell}>
                    {user.inviter_id ? (
                      <span 
                        className={styles.inviterId}
                        onClick={() => setSearchTerm(user.inviter_id || '')}
                        title="点击查看邀请人信息"
                      >
                        {user.inviter_id}
                      </span>
                    ) : (
                      <span className={styles.placeholder}>-</span>
                    )}
                  </td>
                  {/* 注册时间 */}
                  <td className={styles.tableCell}>
                    {dayjs(user.created_at).format('YYYY-MM-DD')}
                  </td>
                  {/* 操作按钮 */}
                  <td className={styles.tableCell}>
                    <div className={styles.actionGroup}>
                      <button
                        onClick={() => handleBanUser(user.id, user.is_banned ? 0 : 1)}
                        disabled={userActionLoading === user.id}
                        className={`${styles.actionBtn} ${user.is_banned ? styles.btnSuccess : styles.btnDanger}`}
                      >
                        {user.is_banned ? '解封' : '封禁'}
                      </button>
                      <button
                        onClick={() => user.is_suspended ? handleSuspendUser(user.id, 0) : handleSuspendClick(user.id)}
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
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={11} className={styles.emptyRow}>暂无用户数据</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* 分页 */}
      {users && users.length > 0 && (
        <div className={styles.pagination}>
          <button
            disabled={currentPage === 1 || loading}
            onClick={() => setCurrentPage(currentPage - 1)}
            className={styles.pageBtn}
          >
            上一页
          </button>
          <span className={styles.pageInfo}>
            第 {currentPage} 页，共 {totalPages} 页
          </span>
          <button
            disabled={currentPage === totalPages || loading}
            onClick={() => setCurrentPage(currentPage + 1)}
            className={styles.pageBtn}
          >
            下一页
          </button>
        </div>
      )}

      {/* 暂停用户模态框 */}
      {showSuspendModal && (
        <div className={styles.modal} onClick={handleCancelSuspend}>
          <div className={styles.modalContent} onClick={e => e.stopPropagation()}>
            <h3 className={styles.modalTitle}>暂停用户</h3>
            <label className={styles.modalLabel}>暂停天数</label>
            <input
              type="number"
              min="1"
              max="365"
              value={suspendDuration}
              onChange={(e) => setSuspendDuration(parseInt(e.target.value) || 1)}
              className={styles.modalInput}
            />
            <div className={styles.modalActions}>
              <button 
                onClick={handleCancelSuspend}
                className={`${styles.modalBtn} ${styles.modalBtnCancel}`}
              >
                取消
              </button>
              <button 
                onClick={handleConfirmSuspend}
                className={`${styles.modalBtn} ${styles.modalBtnConfirm}`}
              >
                确认暂停
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default UserManagement;
