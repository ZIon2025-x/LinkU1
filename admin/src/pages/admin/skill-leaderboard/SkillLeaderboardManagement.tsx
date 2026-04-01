import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { AdminTable, Column } from '../../../components/admin';
import { getSkillLeaderboard, refreshSkillLeaderboard, getSkillCategoriesAdmin } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface LeaderboardEntry {
  rank: number;
  user_id: string;
  user_name?: string;
  skill_name?: string;
  score: number;
  task_count?: number;
  rating?: number;
}

interface Category {
  id: number;
  task_type: string;
  name_zh: string;
  name_en: string;
}

const SkillLeaderboardManagement: React.FC = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState('');
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [categoriesLoaded, setCategoriesLoaded] = useState(false);

  const loadCategories = useCallback(async () => {
    try {
      const response = await getSkillCategoriesAdmin({ offset: 0, limit: 100 });
      const items = response.items || response.data || [];
      setCategories(items);
      setCategoriesLoaded(true);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, []);

  // Load categories on first render
  React.useEffect(() => {
    if (!categoriesLoaded) {
      loadCategories();
    }
  }, [categoriesLoaded, loadCategories]);

  const loadLeaderboard = useCallback(async (category: string) => {
    if (!category) return;
    setLoading(true);
    try {
      const response = await getSkillLeaderboard(category);
      const items = response.items || response.data || response.rankings || [];
      setEntries(Array.isArray(items) ? items.slice(0, 10) : []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
      setEntries([]);
    } finally {
      setLoading(false);
    }
  }, []);

  const handleCategoryChange = (category: string) => {
    setSelectedCategory(category);
    if (category) {
      loadLeaderboard(category);
    } else {
      setEntries([]);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await refreshSkillLeaderboard();
      message.success('Leaderboard refresh triggered');
      if (selectedCategory) {
        await loadLeaderboard(selectedCategory);
      }
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setRefreshing(false);
    }
  };

  const columns: Column<LeaderboardEntry>[] = [
    {
      key: 'rank', title: 'Rank', dataIndex: 'rank', width: 70, align: 'center',
      render: (val: number, _: any, index: number) => {
        const rank = val || index + 1;
        const colors: Record<number, string> = { 1: '#FFD700', 2: '#C0C0C0', 3: '#CD7F32' };
        return (
          <span style={{ fontWeight: 'bold', color: colors[rank] || '#333', fontSize: rank <= 3 ? '16px' : '14px' }}>
            #{rank}
          </span>
        );
      },
    },
    { key: 'user_id', title: 'User ID', dataIndex: 'user_id', width: 200 },
    { key: 'user_name', title: 'Name', dataIndex: 'user_name', width: 150 },
    { key: 'skill_name', title: 'Skill', dataIndex: 'skill_name', width: 150 },
    { key: 'score', title: 'Score', dataIndex: 'score', width: 100, align: 'right' },
    { key: 'task_count', title: 'Tasks', dataIndex: 'task_count', width: 80, align: 'center' },
    {
      key: 'rating', title: 'Rating', dataIndex: 'rating', width: 80, align: 'center',
      render: (val: number) => val ? val.toFixed(1) : '-',
    },
  ];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Skill Leaderboard</h2>
        <button
          onClick={handleRefresh}
          disabled={refreshing}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: refreshing ? '#6c757d' : '#007bff',
            color: 'white',
            borderRadius: '4px',
            cursor: refreshing ? 'not-allowed' : 'pointer',
            fontSize: '14px',
            fontWeight: '500',
          }}
        >
          {refreshing ? 'Refreshing...' : 'Refresh Leaderboard'}
        </button>
      </div>

      {/* Category Selector */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '16px 20px',
        marginBottom: '20px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
      }}>
        <label style={{ fontWeight: 'bold', whiteSpace: 'nowrap' }}>Category:</label>
        <select
          value={selectedCategory}
          onChange={(e) => handleCategoryChange(e.target.value)}
          style={{ padding: '8px 12px', border: '1px solid #ddd', borderRadius: '4px', minWidth: '200px' }}
        >
          <option value="">-- Select a category --</option>
          {categories.map((cat) => (
            <option key={cat.id} value={cat.task_type}>
              {cat.name_zh} / {cat.name_en}
            </option>
          ))}
        </select>
        {selectedCategory && (
          <button
            onClick={() => loadLeaderboard(selectedCategory)}
            style={{ padding: '8px 16px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '13px' }}
          >
            Reload
          </button>
        )}
      </div>

      {/* Leaderboard Table */}
      {selectedCategory ? (
        <AdminTable<LeaderboardEntry>
          columns={columns}
          data={entries}
          loading={loading}
          rowKey={(record) => record.user_id || String(record.rank)}
          emptyText="No leaderboard data for this category"
        />
      ) : (
        <div style={{
          background: 'white',
          borderRadius: '8px',
          padding: '60px 20px',
          textAlign: 'center',
          color: '#999',
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        }}>
          Select a category to view the top 10 leaderboard
        </div>
      )}
    </div>
  );
};

export default SkillLeaderboardManagement;
