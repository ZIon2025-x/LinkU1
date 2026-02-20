import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { message } from 'antd';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';
import api, { getDashboardStats, getUserGrowthStats, getTaskGrowthStats, TrendDataPoint } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import { DashboardStats, StatCardProps, StatPeriod } from './types';
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

const PERIOD_LABELS: Record<StatPeriod, string> = {
  '7d': '7天',
  '30d': '30天',
  '90d': '90天',
};

/**
 * Dashboard 仪表盘组件
 * 显示系统统计数据和管理功能入口
 */
const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cleanupLoading, setCleanupLoading] = useState(false);
  const [period, setPeriod] = useState<StatPeriod>('30d');
  const [userTrend, setUserTrend] = useState<TrendDataPoint[]>([]);
  const [taskTrend, setTaskTrend] = useState<TrendDataPoint[]>([]);
  const [chartLoading, setChartLoading] = useState(false);

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

  const fetchTrends = useCallback(async () => {
    setChartLoading(true);
    try {
      const [users, tasks] = await Promise.all([
        getUserGrowthStats(period),
        getTaskGrowthStats(period),
      ]);
      setUserTrend(users);
      setTaskTrend(tasks);
    } catch (err: any) {
      message.warning('趋势数据加载失败: ' + getErrorMessage(err));
    } finally {
      setChartLoading(false);
    }
  }, [period]);

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

  useEffect(() => { fetchTrends(); }, [fetchTrends]);

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
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          {(['7d', '30d', '90d'] as StatPeriod[]).map(p => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`${styles.periodBtn} ${period === p ? styles.periodBtnActive : ''}`}
            >
              {PERIOD_LABELS[p]}
            </button>
          ))}
          {/* existing cleanup button unchanged */}
          <button onClick={handleCleanupOldTasks} disabled={cleanupLoading} className={styles.cleanupBtn}>
            {cleanupLoading ? (
              <><span className={styles.spinner}></span>清理中...</>
            ) : (
              <>🗑️ 一键清理已完成和过期任务文件</>
            )}
          </button>
        </div>
      </div>
      {statsCards}
      {/* Trend charts */}
      <div className={styles.chartsGrid}>
        <div className={styles.chartCard}>
          <h3 className={styles.chartTitle}>📈 用户注册趋势</h3>
          {chartLoading ? (
            <div className={styles.chartLoading}>加载中...</div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <LineChart data={userTrend} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#1890ff" dot={false} strokeWidth={2} name="新增用户" />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
        <div className={styles.chartCard}>
          <h3 className={styles.chartTitle}>📊 任务发布趋势</h3>
          {chartLoading ? (
            <div className={styles.chartLoading}>加载中...</div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <LineChart data={taskTrend} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#52c41a" dot={false} strokeWidth={2} name="新增任务" />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
