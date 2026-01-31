/**
 * 推荐任务组件
 * 显示个性化推荐的任务列表
 */

import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, Spin, Empty, Tag, Tooltip } from 'antd';
import { FireOutlined, StarOutlined, ClockCircleOutlined, EnvironmentOutlined, TeamOutlined, ThunderboltOutlined } from '@ant-design/icons';
import { getTaskRecommendations, recordTaskInteraction } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import './RecommendedTasks.css';

interface RecommendedTask {
  task_id: number;
  title: string;
  description: string;
  task_type: string;
  location: string;
  reward: number;
  deadline: string | null;
  task_level: string;
  match_score: number;
  recommendation_reason: string;
  created_at: string;
}

interface RecommendedTasksProps {
  limit?: number;
  algorithm?: 'content_based' | 'collaborative' | 'hybrid';
  showTitle?: boolean;
  onTaskClick?: (taskId: number) => void;
}

const RecommendedTasks: React.FC<RecommendedTasksProps> = ({
  limit = 10,
  algorithm = 'hybrid',
  showTitle = true,
  onTaskClick
}) => {
  const [recommendations, setRecommendations] = useState<RecommendedTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { language } = useLanguage();
  const navigate = useNavigate();

  useEffect(() => {
    loadRecommendations();
  }, [limit, algorithm]);

  const loadRecommendations = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await getTaskRecommendations(limit, algorithm);
      setRecommendations(response.recommendations || []);
    } catch (err: any) {
      console.error('加载推荐失败:', err);
      setError(err.message || '加载推荐失败');
    } finally {
      setLoading(false);
    }
  };

  const handleTaskClick = async (taskId: number) => {
    // 记录点击行为
    const deviceType = /Mobile|Android|iPhone/i.test(navigator.userAgent) ? 'mobile' : 'desktop';
    await recordTaskInteraction(taskId, 'click', undefined, deviceType);
    
    if (onTaskClick) {
      onTaskClick(taskId);
    } else {
      navigate(`/tasks/${taskId}`);
    }
  };

  const getMatchScoreColor = (score: number): string => {
    if (score >= 0.8) return '#52c41a'; // 绿色 - 高匹配
    if (score >= 0.6) return '#1890ff'; // 蓝色 - 中等匹配
    if (score >= 0.4) return '#faad14'; // 橙色 - 低匹配
    return '#d9d9d9'; // 灰色 - 很低匹配
  };

  const getMatchScoreText = (score: number): string => {
    if (score >= 0.8) return language === 'zh' ? '高度匹配' : 'High Match';
    if (score >= 0.6) return language === 'zh' ? '中等匹配' : 'Medium Match';
    if (score >= 0.4) return language === 'zh' ? '低匹配' : 'Low Match';
    return language === 'zh' ? '匹配度低' : 'Low Match';
  };

  // 增强：根据推荐理由返回对应的图标
  const getRecommendationReasonIcon = (reason: string) => {
    if (reason.includes('同校') || reason.includes('学校')) return <TeamOutlined />;
    if (reason.includes('距离') || reason.includes('km')) return <EnvironmentOutlined />;
    if (reason.includes('活跃时间') || reason.includes('时间段') || reason.includes('当前活跃')) return <ClockCircleOutlined />;
    if (reason.includes('高评分') || reason.includes('评分')) return <StarOutlined />;
    if (reason.includes('新发布') || reason.includes('新任务')) return <ThunderboltOutlined />;
    if (reason.includes('即将截止') || reason.includes('截止')) return <ClockCircleOutlined />;
    return <FireOutlined />;
  };

  // 增强：根据推荐理由返回对应的颜色
  const getRecommendationReasonColor = (reason: string): string => {
    if (reason.includes('同校') || reason.includes('学校')) return '#4a90e2';
    if (reason.includes('距离') || reason.includes('km')) return '#52c41a';
    if (reason.includes('活跃时间') || reason.includes('时间段') || reason.includes('当前活跃')) return '#fa8c16';
    if (reason.includes('高评分') || reason.includes('评分')) return '#fadb14';
    if (reason.includes('新发布') || reason.includes('新任务')) return '#9254de';
    if (reason.includes('即将截止') || reason.includes('截止')) return '#ff4d4f';
    return '#ff6b6b';
  };

  if (loading) {
    return (
      <div className="recommended-tasks-container">
        {showTitle && (
          <div className="recommended-tasks-header">
            <h2>
              <FireOutlined /> {language === 'zh' ? '为您推荐' : 'Recommended for You'}
            </h2>
          </div>
        )}
        <div className="recommended-tasks-loading">
          <Spin size="large" />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="recommended-tasks-container">
        {showTitle && (
          <div className="recommended-tasks-header">
            <h2>
              <FireOutlined /> {language === 'zh' ? '为您推荐' : 'Recommended for You'}
            </h2>
          </div>
        )}
        <Empty
          description={error}
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        />
      </div>
    );
  }

  if (recommendations.length === 0) {
    return (
      <div className="recommended-tasks-container">
        {showTitle && (
          <div className="recommended-tasks-header">
            <h2>
              <FireOutlined /> {language === 'zh' ? '为您推荐' : 'Recommended for You'}
            </h2>
          </div>
        )}
        <Empty
          description={language === 'zh' ? '暂无推荐任务' : 'No recommendations available'}
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        />
      </div>
    );
  }

  return (
    <div className="recommended-tasks-container">
      {showTitle && (
        <div className="recommended-tasks-header">
          <h2>
            <FireOutlined /> {language === 'zh' ? '为您推荐' : 'Recommended for You'}
          </h2>
          <span className="recommended-tasks-count">
            {recommendations.length} {language === 'zh' ? '个推荐' : 'recommendations'}
          </span>
        </div>
      )}
      
      <div className="recommended-tasks-list">
        {recommendations.map((task) => (
          <Card
            key={task.task_id}
            className="recommended-task-card"
            hoverable
            onClick={() => handleTaskClick(task.task_id)}
            style={{ marginBottom: 16 }}
          >
            <div className="recommended-task-header">
              <div className="recommended-task-title-section">
                <h3 className="recommended-task-title">{task.title}</h3>
                <div className="recommended-task-meta">
                  <Tag color={getMatchScoreColor(task.match_score)}>
                    <StarOutlined /> {Math.round(task.match_score * 100)}% {getMatchScoreText(task.match_score)}
                  </Tag>
                  <Tag>{task.task_type}</Tag>
                  {task.task_level !== 'normal' && (
                    <Tag color="gold">{task.task_level}</Tag>
                  )}
                </div>
              </div>
              <div className="recommended-task-reward">
                <span className="reward-amount">£{task.reward.toFixed(2)}</span>
              </div>
            </div>
            
            <p className="recommended-task-description">
              {task.description.length > 150 
                ? `${task.description.substring(0, 150)}...` 
                : task.description}
            </p>
            
            <div className="recommended-task-footer">
              <div className="recommended-task-info">
                <span className="task-location">
                  <ClockCircleOutlined /> {task.location}
                </span>
                {task.deadline && (
                  <span className="task-deadline">
                    {new Date(task.deadline).toLocaleDateString()}
                  </span>
                )}
              </div>
              {task.recommendation_reason && (
                <Tooltip title={task.recommendation_reason}>
                  <span className="recommendation-reason" style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    color: getRecommendationReasonColor(task.recommendation_reason),
                    fontWeight: 500
                  }}>
                    {getRecommendationReasonIcon(task.recommendation_reason)}
                    <span>{task.recommendation_reason}</span>
                  </span>
                </Tooltip>
              )}
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
};

export default RecommendedTasks;
