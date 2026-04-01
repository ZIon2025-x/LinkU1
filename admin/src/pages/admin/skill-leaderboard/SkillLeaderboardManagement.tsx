import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { AdminTable, Column } from '../../../components/admin';
import { getSkillLeaderboard, refreshSkillLeaderboard, getSkillCategoriesAdmin, getLeaderboardCities } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface LeaderboardEntry {
  rank: number;
  user_id: string;
  user_name?: string;
  city?: string;
  score: number;
  completed_tasks?: number;
  avg_rating?: number;
}

interface Category {
  id: number;
  task_type: string;
  name_zh: string;
  name_en: string;
}

const SkillLeaderboardManagement: React.FC = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const [cities, setCities] = useState<string[]>([]);
  const [selectedCategory, setSelectedCategory] = useState('');
  const [selectedCity, setSelectedCity] = useState('');
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [initialized, setInitialized] = useState(false);

  const loadInitialData = useCallback(async () => {
    try {
      const [catResponse, cityResponse] = await Promise.all([
        getSkillCategoriesAdmin({ offset: 0, limit: 100 }),
        getLeaderboardCities(),
      ]);
      setCategories(catResponse.items || catResponse.data || []);
      setCities(cityResponse.data || []);
      setInitialized(true);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, []);

  React.useEffect(() => {
    if (!initialized) {
      loadInitialData();
    }
  }, [initialized, loadInitialData]);

  const loadLeaderboard = useCallback(async (category: string, city?: string) => {
    if (!category) return;
    setLoading(true);
    try {
      const response = await getSkillLeaderboard(category, city || undefined);
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
      loadLeaderboard(category, selectedCity);
    } else {
      setEntries([]);
    }
  };

  const handleCityChange = (city: string) => {
    setSelectedCity(city);
    if (selectedCategory) {
      loadLeaderboard(selectedCategory, city);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await refreshSkillLeaderboard();
      message.success('Leaderboard refresh triggered');
      if (selectedCategory) {
        await loadLeaderboard(selectedCategory, selectedCity);
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
    { key: 'city', title: 'City', dataIndex: 'city', width: 120 },
    { key: 'score', title: 'Score', dataIndex: 'score', width: 100, align: 'right' },
    { key: 'completed_tasks', title: 'Tasks', dataIndex: 'completed_tasks', width: 80, align: 'center' },
    {
      key: 'avg_rating', title: 'Rating', dataIndex: 'avg_rating', width: 80, align: 'center',
      render: (val: number) => val ? val.toFixed(1) : '-',
    },
  ];

  const selectStyle = { padding: '8px 12px', border: '1px solid #ddd', borderRadius: '4px', minWidth: '200px' };

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

      {/* Filters */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '16px 20px',
        marginBottom: '20px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        display: 'flex',
        alignItems: 'center',
        gap: '16px',
        flexWrap: 'wrap',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <label style={{ fontWeight: 'bold', whiteSpace: 'nowrap' }}>Category:</label>
          <select value={selectedCategory} onChange={(e) => handleCategoryChange(e.target.value)} style={selectStyle}>
            <option value="">-- Select --</option>
            {categories.map((cat) => (
              <option key={cat.id} value={cat.task_type}>
                {cat.name_zh} / {cat.name_en}
              </option>
            ))}
          </select>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <label style={{ fontWeight: 'bold', whiteSpace: 'nowrap' }}>City:</label>
          <select value={selectedCity} onChange={(e) => handleCityChange(e.target.value)} style={selectStyle}>
            <option value="">All Cities</option>
            {cities.map((city) => (
              <option key={city} value={city}>{city}</option>
            ))}
          </select>
        </div>

        {selectedCategory && (
          <button
            onClick={() => loadLeaderboard(selectedCategory, selectedCity)}
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
