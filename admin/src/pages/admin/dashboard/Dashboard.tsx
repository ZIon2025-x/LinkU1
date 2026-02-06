import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { message } from 'antd';
import api, { getDashboardStats } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import { DashboardStats, StatCardProps } from './types';
import styles from './Dashboard.module.css';

/**
 * 统计卡片组件
 */
const StatCard: React.FC<StatCardProps> = ({ label, value, prefix = '', suffix = '' }) => (
  <div className={styles.statCard}>
    <h3 className={styles.statLabel}>{label}</h3>
    <p className={styles.statValue}>
      {prefix}{typeof value === 'number' ? value.toLocaleString() : value}{suffix}
    </p>
  </div>
);

/**
 * Dashboard 仪表盘组件
 * 显示系统统计数据和管理功能入口
 */
const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cleanupLoading, setCleanupLoading] = useState(false);

  // 加载统计数据
  const fetchStats = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getDashboardStats();
      setStats(data);
    } catch (err: any) {
      const errorMsg = getErrorMessage(err);
      setError(errorMsg);
      console.error('Failed to load dashboard stats:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

  // 处理清理旧任务文件
  const handleCleanupOldTasks = useCallback(async () => {
    const confirmMessage = 
      '确定要清理所有已完成或已取消任务的所有图片和文件吗？\n\n' +
      '清理内容包括：\n' +
      '- 公开图片（任务相关图片）\n' +
      '- 私密图片（任务聊天图片）\n' +
      '- 私密文件（任务聊天文件）\n\n' +
      '注意：将清理所有已完成或已取消的任务，不检查时间限制！\n' +
      '此操作不可恢复！';

    if (!window.confirm(confirmMessage)) {
      return;
    }

    setCleanupLoading(true);
    try {
      const response = await api.post('/api/admin/cleanup/all-old-tasks');
      if (response.data.success) {
        message.success(response.data.message);
        // 刷新统计数据
        fetchStats();
      } else {
        message.error('清理失败');
      }
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setCleanupLoading(false);
    }
  }, [fetchStats]);

  // 统计卡片渲染
  const statsCards = useMemo(() => {
    if (!stats) return null;
    
    return (
      <div className={styles.statsGrid}>
        <StatCard label="总用户数" value={stats.total_users} />
        <StatCard label="总任务数" value={stats.total_tasks} />
        <StatCard label="客服数量" value={stats.total_customer_service} />
        <StatCard label="活跃会话" value={stats.active_sessions} />
        <StatCard label="总收入" value={stats.total_revenue.toFixed(2)} prefix="£" />
        <StatCard label="平均评分" value={stats.avg_rating.toFixed(1)} />
      </div>
    );
  }, [stats]);

  // 加载状态
  if (loading) {
    return (
      <div className={styles.loadingContainer}>
        <span className={styles.spinner} style={{ width: '24px', height: '24px', borderWidth: '3px' }}></span>
        <span style={{ marginLeft: '12px' }}>加载中...</span>
      </div>
    );
  }

  // 错误状态
  if (error) {
    return (
      <div className={styles.errorContainer}>
        <span className={styles.errorMessage}>加载失败: {error}</span>
        <button className={styles.retryBtn} onClick={fetchStats}>
          重试
        </button>
      </div>
    );
  }

  return (
    <div className={styles.dashboardSection}>
      <div className={styles.dashboardHeader}>
        <h2 className={styles.dashboardTitle}>数据概览</h2>
        <button
          onClick={handleCleanupOldTasks}
          disabled={cleanupLoading}
          className={styles.cleanupBtn}
        >
          {cleanupLoading ? (
            <>
              <span className={styles.spinner}></span>
              清理中...
            </>
          ) : (
            <>🗑️ 一键清理已完成和过期任务文件</>
          )}
        </button>
      </div>
      {statsCards}
    </div>
  );
};

export default Dashboard;
