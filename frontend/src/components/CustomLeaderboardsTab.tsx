import React, { useState, useEffect, useCallback } from 'react';
import { Card, Button, Select, Modal, Form, message, Empty, Tag, Input, Pagination, Spin } from 'antd';
import { PlusOutlined, TrophyOutlined, FireOutlined, ClockCircleOutlined } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import {
  applyCustomLeaderboard,
  getCustomLeaderboards
} from '../api';
import { fetchCurrentUser } from '../api';
import { LOCATIONS } from '../constants/leaderboard';

const { Option } = Select;

const CustomLeaderboardsTab: React.FC = () => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const [leaderboards, setLeaderboards] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [selectedLocation, setSelectedLocation] = useState<string>('');
  const [searchKeyword, setSearchKeyword] = useState<string>('');
  const [sortBy, setSortBy] = useState<'latest' | 'hot' | 'votes' | 'items'>('latest');
  const [user, setUser] = useState<any>(null);
  const [form] = Form.useForm();
  const [pagination, setPagination] = useState({
    current: 1,
    pageSize: 20,
    total: 0,
    hasMore: false
  });

  // 防抖搜索
  const [searchTimer, setSearchTimer] = useState<NodeJS.Timeout | null>(null);

  useEffect(() => {
    loadLeaderboards();
    fetchCurrentUser().then(setUser).catch(() => setUser(null));
  }, [selectedLocation, sortBy]);

  useEffect(() => {
    // 搜索防抖
    if (searchTimer) {
      clearTimeout(searchTimer);
    }
    const timer = setTimeout(() => {
      loadLeaderboards();
    }, 500);
    setSearchTimer(timer);
    return () => {
      if (timer) clearTimeout(timer);
    };
  }, [searchKeyword]);

  const loadLeaderboards = async (page: number = 1) => {
    try {
      setLoading(true);
      const offset = (page - 1) * pagination.pageSize;
      const response = await getCustomLeaderboards({
        location: selectedLocation || undefined,
        keyword: searchKeyword || undefined,
        status: 'active',
        sort: sortBy,
        limit: pagination.pageSize,
        offset
      });
      
      if (response && response.items) {
        setLeaderboards(response.items || []);
        setPagination(prev => ({
          ...prev,
          current: page,
          total: response.total || 0,
          hasMore: response.has_more || false
        }));
      } else {
        // 兼容旧格式
        setLeaderboards(response || []);
      }
    } catch (error: any) {
      console.error('加载排行榜失败:', error);
      
      // 处理不同类型的错误
      if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 403) {
        message.error('没有权限访问');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.warning(`请求过于频繁，请在 ${retryAfter} 秒后重试`);
      } else if (error.response?.status >= 500) {
        message.error('服务器错误，请稍后重试');
      } else {
        message.error(error.response?.data?.detail || '加载失败，请稍后重试');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleApply = async (values: any) => {
    try {
      await applyCustomLeaderboard(values);
      message.success('榜单申请已提交，等待审核');
      setShowApplyModal(false);
      form.resetFields();
      loadLeaderboards();
    } catch (error: any) {
      console.error('申请榜单失败:', error);
      const errorMsg = error.response?.data?.detail || error.message || '申请失败';
      
      // 处理不同类型的错误
      if (error.response?.status === 400) {
        if (errorMsg.includes('已存在')) {
          message.error('该地区已存在相同名称的榜单');
        } else {
          message.error(errorMsg);
        }
      } else if (error.response?.status === 401) {
        message.error('请先登录');
      } else if (error.response?.status === 429) {
        const retryAfter = error.response?.headers?.['retry-after'] || 60;
        message.error(`操作过于频繁，请在 ${retryAfter} 秒后重试`);
      } else {
        message.error(errorMsg);
      }
    }
  };

  const handlePageChange = (page: number) => {
    loadLeaderboards(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <div>
      {/* 筛选、搜索和申请按钮 */}
      <div style={{ marginBottom: 16, display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <Select
          placeholder="选择地区"
          style={{ width: 150 }}
          allowClear
          value={selectedLocation}
          onChange={setSelectedLocation}
        >
          {LOCATIONS.map(loc => (
            <Option key={loc} value={loc}>{loc}</Option>
          ))}
        </Select>
        
        <Select
          placeholder="排序方式"
          style={{ width: 150 }}
          value={sortBy}
          onChange={setSortBy}
        >
          <Option value="latest">
            <ClockCircleOutlined /> 最新
          </Option>
          <Option value="hot">
            <FireOutlined /> 热门
          </Option>
          <Option value="votes">投票数</Option>
          <Option value="items">竞品数</Option>
        </Select>
        
        <Input.Search
          placeholder="搜索榜单名称或描述"
          style={{ flex: 1, minWidth: 200, maxWidth: 400 }}
          value={searchKeyword}
          onChange={(e) => setSearchKeyword(e.target.value)}
          allowClear
        />
        
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={() => {
            if (!user) {
              message.warning('请先登录');
              return;
            }
            setShowApplyModal(true);
          }}
        >
          申请新榜单
        </Button>
      </div>

      {/* 榜单列表 */}
      <Spin spinning={loading}>
        {leaderboards.length === 0 && !loading ? (
          <Empty description="暂无榜单" />
        ) : (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))', gap: 20 }}>
              {leaderboards.map(leaderboard => (
                <div
                  key={leaderboard.id}
                  style={{
                    background: 'white',
                    borderRadius: 12,
                    overflow: 'hidden',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                    transition: 'transform 0.2s, box-shadow 0.2s',
                    cursor: 'pointer'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateY(-4px)';
                    e.currentTarget.style.boxShadow = '0 8px 20px rgba(0,0,0,0.15)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.1)';
                  }}
                  onClick={() => {
                    const lang = language || 'zh';
                    navigate(`/${lang}/leaderboard/custom/${leaderboard.id}`);
                  }}
                >
                  {/* Header Section - 渐变色背景 */}
                  <div style={{
                    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    padding: '20px',
                    color: 'white'
                  }}>
                    <div style={{
                      fontSize: 22,
                      fontWeight: 'bold',
                      marginBottom: 8
                    }}>
                      {leaderboard.name}
                    </div>
                    <div style={{
                      fontSize: 14,
                      opacity: 0.9,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 4
                    }}>
                      <span>📍</span>
                      <span>{leaderboard.location}</span>
                    </div>
                  </div>

                  {/* Content Section */}
                  <div style={{ padding: '20px' }}>
                    {leaderboard.description && (
                      <div style={{
                        fontSize: 14,
                        color: '#666',
                        lineHeight: 1.6,
                        marginBottom: 20,
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden'
                      }}>
                        {leaderboard.description}
                      </div>
                    )}

                    {/* Stats Grid */}
                    <div style={{
                      display: 'grid',
                      gridTemplateColumns: 'repeat(3, 1fr)',
                      gap: 16,
                      marginBottom: 16
                    }}>
                      <div style={{
                        textAlign: 'center',
                        padding: 12,
                        background: '#f5f5f5',
                        borderRadius: 8
                      }}>
                        <div style={{
                          fontSize: 20,
                          fontWeight: 'bold',
                          color: '#667eea',
                          marginBottom: 4
                        }}>
                          {leaderboard.item_count || 0}
                        </div>
                        <div style={{
                          fontSize: 12,
                          color: '#999'
                        }}>
                          竞品数
                        </div>
                      </div>
                      <div style={{
                        textAlign: 'center',
                        padding: 12,
                        background: '#f5f5f5',
                        borderRadius: 8
                      }}>
                        <div style={{
                          fontSize: 20,
                          fontWeight: 'bold',
                          color: '#667eea',
                          marginBottom: 4
                        }}>
                          {leaderboard.vote_count || 0}
                        </div>
                        <div style={{
                          fontSize: 12,
                          color: '#999'
                        }}>
                          投票数
                        </div>
                      </div>
                      <div style={{
                        textAlign: 'center',
                        padding: 12,
                        background: '#f5f5f5',
                        borderRadius: 8
                      }}>
                        <div style={{
                          fontSize: 20,
                          fontWeight: 'bold',
                          color: '#667eea',
                          marginBottom: 4
                        }}>
                          {leaderboard.view_count || 0}
                        </div>
                        <div style={{
                          fontSize: 12,
                          color: '#999'
                        }}>
                          浏览量
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Footer */}
                  <div style={{
                    padding: '16px 20px',
                    background: '#f9f9f9',
                    borderTop: '1px solid #eee',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                  }}>
                    {leaderboard.applicant && (
                      <div style={{
                        fontSize: 12,
                        color: '#999'
                      }}>
                        申请者：{leaderboard.applicant.name || leaderboard.applicant_id || '匿名'}
                      </div>
                    )}
                    <button
                      style={{
                        padding: '6px 16px',
                        background: '#667eea',
                        color: 'white',
                        border: 'none',
                        borderRadius: 6,
                        fontSize: 14,
                        cursor: 'pointer',
                        transition: 'background 0.2s'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#5568d3';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = '#667eea';
                      }}
                      onClick={(e) => {
                        e.stopPropagation();
                        const lang = language || 'zh';
                        navigate(`/${lang}/leaderboard/custom/${leaderboard.id}`);
                      }}
                    >
                      查看详情
                    </button>
                  </div>
                </div>
              ))}
            </div>
            
            {/* 分页 */}
            {pagination.total > 0 && (
              <div style={{ marginTop: 24, display: 'flex', justifyContent: 'center' }}>
                <Pagination
                  current={pagination.current}
                  pageSize={pagination.pageSize}
                  total={pagination.total}
                  onChange={handlePageChange}
                  showSizeChanger={false}
                  showQuickJumper
                  showTotal={(total) => `共 ${total} 个榜单`}
                />
              </div>
            )}
          </>
        )}
      </Spin>

      {/* 申请榜单弹窗 */}
      <Modal
        title="申请新榜单"
        open={showApplyModal}
        onCancel={() => {
          setShowApplyModal(false);
          form.resetFields();
        }}
        onOk={() => form.submit()}
        width={600}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleApply}
        >
          <Form.Item
            name="name"
            label="榜单名称"
            rules={[{ required: true, message: '请输入榜单名称' }]}
          >
            <Input placeholder="例如：London中餐榜" />
          </Form.Item>
          
          <Form.Item
            name="location"
            label="地区"
            rules={[{ required: true, message: '请选择地区' }]}
          >
            <Select placeholder="选择地区">
              {LOCATIONS.map(loc => (
                <Option key={loc} value={loc}>{loc}</Option>
              ))}
            </Select>
          </Form.Item>
          
          <Form.Item
            name="description"
            label="榜单描述"
          >
            <Input.TextArea rows={4} placeholder="描述这个榜单的目的和范围" />
          </Form.Item>
          
          <Form.Item
            name="application_reason"
            label="申请理由"
            rules={[{ required: true, message: '请说明申请理由' }]}
          >
            <Input.TextArea rows={3} placeholder="为什么需要创建这个榜单？" />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default CustomLeaderboardsTab;

