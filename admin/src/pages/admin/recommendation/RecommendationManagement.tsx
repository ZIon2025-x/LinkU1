import React, { useState, useCallback, useEffect } from 'react';
import { message } from 'antd';
import {
  getAdminRecommendationMetrics,
  getAdminRecommendationAnalytics,
  getAdminTopRecommendedTasks,
  getAdminRecommendationHealth,
  getAdminRecommendationOptimization,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

const RecommendationManagement: React.FC = () => {
  const [days, setDays] = useState(7);
  const [metrics, setMetrics] = useState<Record<string, any> | null>(null);
  const [health, setHealth] = useState<Record<string, any> | null>(null);
  const [topTasks, setTopTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [m, h, t] = await Promise.all([
        getAdminRecommendationMetrics({ days }),
        getAdminRecommendationHealth().catch(() => null),
        getAdminTopRecommendedTasks({ days, limit: 20 }),
      ]);
      setMetrics(m);
      setHealth(h);
      setTopTasks(t?.top_tasks || []);
    } catch (e) {
      message.error(getErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [days]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>推荐系统</h2>

      <div style={{ marginBottom: '16px', display: 'flex', gap: '8px', alignItems: 'center' }}>
        <span>统计天数：</span>
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value))}
          style={{ padding: '6px 10px', borderRadius: '4px', border: '1px solid #ddd' }}
        >
          {[7, 14, 30].map((d) => (
            <option key={d} value={d}>{d} 天</option>
          ))}
        </select>
        <button
          type="button"
          onClick={loadData}
          disabled={loading}
          style={{ padding: '6px 16px', background: '#1890ff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          {loading ? '加载中...' : '刷新'}
        </button>
      </div>

      {health && (
        <div style={{ background: 'white', padding: '16px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.08)', marginBottom: '20px' }}>
          <h3 style={{ margin: '0 0 12px 0', fontSize: '16px' }}>健康状态</h3>
          <pre style={{ margin: 0, fontSize: '12px', overflow: 'auto', maxHeight: '200px' }}>
            {JSON.stringify(health, null, 2)}
          </pre>
        </div>
      )}

      {metrics && (
        <div style={{ background: 'white', padding: '16px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.08)', marginBottom: '20px' }}>
          <h3 style={{ margin: '0 0 12px 0', fontSize: '16px' }}>指标（近 {days} 天）</h3>
          <pre style={{ margin: 0, fontSize: '12px', overflow: 'auto', maxHeight: '300px' }}>
            {JSON.stringify(metrics, null, 2)}
          </pre>
        </div>
      )}

      <div style={{ background: 'white', padding: '16px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.08)' }}>
        <h3 style={{ margin: '0 0 12px 0', fontSize: '16px' }}>热门推荐任务（近 {days} 天）</h3>
        {topTasks.length === 0 && !loading && <div style={{ color: '#999' }}>暂无数据</div>}
        <ul style={{ margin: 0, paddingLeft: '20px' }}>
          {topTasks.slice(0, 15).map((t: any, i: number) => (
            <li key={i} style={{ marginBottom: '6px' }}>
              {t.task_id != null && `任务 #${t.task_id}`}
              {t.title != null && ` - ${t.title}`}
              {t.recommend_count != null && ` (推荐次数: ${t.recommend_count})`}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default RecommendationManagement;
