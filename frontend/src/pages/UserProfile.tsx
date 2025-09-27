import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getUserProfile, fetchCurrentUser } from '../api';

interface UserProfileType {
  user: {
    id: string;  // 现在ID是字符串类型
    name: string;
    email: string;
    phone: string;
    created_at: string;
    is_verified: number;
    user_level: string;
    avatar: string;
    avg_rating: number;
    days_since_joined: number;
    task_count: number;
  };
  stats: {
    total_tasks: number;
    posted_tasks: number;
    taken_tasks: number;
    completed_tasks: number;
    total_reviews: number;
  };
  recent_tasks: Array<{
    id: string;  // 现在ID是字符串类型
    title: string;
    status: string;
    created_at: string;
    reward: number;
    task_type: string;
  }>;
  reviews: Array<{
    id: number;
    rating: number;
    comment: string;
    created_at: string;
    task_id: string;  // 现在ID是字符串类型
    is_anonymous: boolean;
    reviewer_name: string;
  }>;
}

const UserProfile: React.FC = () => {
  const { userId } = useParams();
  const [profile, setProfile] = useState<UserProfileType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [currentUser, setCurrentUser] = useState<any>(null);
  const navigate = useNavigate();

  useEffect(() => {
    // 直接获取用户信息，HttpOnly Cookie会自动发送
    fetchCurrentUser().then(setCurrentUser).catch(() => setCurrentUser(null));
  }, []);

  useEffect(() => {
    if (userId) {
      loadUserProfile();
    }
  }, [userId]);

  const loadUserProfile = async () => {
    if (!userId) {
      setError('用户ID不存在');
      setLoading(false);
      return;
    }
    
    setLoading(true);
    try {
      // 数据库现在直接存储格式化ID，可以直接使用
      const data = await getUserProfile(userId);
      setProfile(data);
    } catch (error: any) {
      let errorMsg = '用户不存在';
      if (error?.response?.data?.detail) {
        if (typeof error.response.data.detail === 'string') {
          errorMsg = error.response.data.detail;
        } else if (Array.isArray(error.response.data.detail)) {
          errorMsg = error.response.data.detail.map((item: any) => item.msg).join('；');
        } else if (typeof error.response.data.detail === 'object' && error.response.data.detail.msg) {
          errorMsg = error.response.data.detail.msg;
        } else {
          errorMsg = JSON.stringify(error.response.data.detail);
        }
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'open': return '开放中';
      case 'taken': return '已接受';
      case 'in_progress': return '进行中';
      case 'pending_confirmation': return '待确认';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return status;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open': return '#28a745';
      case 'taken': return '#ffc107';
      case 'in_progress': return '#007bff';
      case 'pending_confirmation': return '#ffc107';
      case 'completed': return '#6c757d';
      case 'cancelled': return '#dc3545';
      default: return '#6c757d';
    }
  };

  const getLevelText = (level: string) => {
    switch (level) {
      case 'normal': return '普通用户';
      case 'vip': return 'VIP会员';
      case 'super': return '超级会员';
      default: return level;
    }
  };

  const getLevelColor = (level: string) => {
    switch (level) {
      case 'normal': return '#6c757d';
      case 'vip': return '#ffc107';
      case 'super': return '#dc3545';
      default: return '#6c757d';
    }
  };

  const renderStars = (rating: number) => {
    const stars = [];
    for (let i = 1; i <= 5; i++) {
      stars.push(
        <span key={i} style={{ color: i <= rating ? '#ffc107' : '#e4e5e9', fontSize: 20 }}>
          ★
        </span>
      );
    }
    return stars;
  };

  const handleChat = () => {
    navigate(`/message?uid=${userId}`);
  };

  const handleViewTask = (taskId: string) => {
    navigate(`/tasks/${taskId}`);
  };

  if (loading) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh',
        fontSize: 18,
        color: '#666'
      }}>
        加载中...
      </div>
    );
  }

  if (error || !profile) {
    return (
      <div style={{ 
        textAlign: 'center', 
        padding: '60px 20px',
        color: '#dc3545',
        fontSize: 18
      }}>
        {error || '用户不存在'}
      </div>
    );
  }

  const isOwnProfile = currentUser && currentUser.id === userId;

  return (
    <div style={{ 
      maxWidth: 1000, 
      margin: '0 auto', 
      padding: '20px',
      minHeight: '100vh',
      background: '#f8f9fa'
    }}>
      {/* 用户基本信息卡片 */}
      <div style={{
        background: '#fff',
        borderRadius: 16,
        padding: 30,
        marginBottom: 24,
        boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
        textAlign: 'center'
      }}>
        <div style={{ marginBottom: 20 }}>
          <img
            src={profile.user.avatar || '/avatar1.png'}
            alt="头像"
            style={{
              width: 120,
              height: 120,
              borderRadius: '50%',
              border: '4px solid #A67C52',
              objectFit: 'cover'
            }}
          />
        </div>
        
        <h1 style={{ 
          fontSize: 28, 
          fontWeight: 800, 
          color: '#333',
          marginBottom: 10
        }}>
          {profile.user.name}
          {profile.user.is_verified === 1 && (
            <span style={{ 
              color: '#28a745', 
              marginLeft: 10,
              fontSize: 20
            }}>
              ✓
            </span>
          )}
        </h1>

        <div style={{ 
          display: 'flex', 
          justifyContent: 'center', 
          alignItems: 'center',
          gap: 20,
          marginBottom: 20,
          flexWrap: 'wrap'
        }}>
          <span style={{
            padding: '6px 12px',
            borderRadius: 20,
            fontSize: 14,
            fontWeight: 600,
            color: '#fff',
            background: getLevelColor(profile.user.user_level)
          }}>
            {getLevelText(profile.user.user_level)}
          </span>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            {renderStars(profile.user.avg_rating)}
            <span style={{ color: '#666', fontSize: 14 }}>
              ({profile.user.avg_rating.toFixed(1)})
            </span>
          </div>
        </div>

        <div style={{ 
          display: 'flex', 
          justifyContent: 'center', 
          gap: 30,
          marginBottom: 20,
          flexWrap: 'wrap'
        }}>
          <div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#A67C52' }}>
              {profile.stats.total_tasks}
            </div>
            <div style={{ fontSize: 14, color: '#666' }}>总任务数</div>
          </div>
          <div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#28a745' }}>
              {profile.stats.completed_tasks}
            </div>
            <div style={{ fontSize: 14, color: '#666' }}>完成任务</div>
          </div>
          <div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#007bff' }}>
              {profile.stats.total_reviews}
            </div>
            <div style={{ fontSize: 14, color: '#666' }}>获得评价</div>
          </div>
          <div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#ffc107' }}>
              {profile.user.days_since_joined}
            </div>
            <div style={{ fontSize: 14, color: '#666' }}>注册天数</div>
          </div>
        </div>

        {!isOwnProfile && (
          <button
            onClick={handleChat}
            style={{
              background: '#A67C52',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '12px 24px',
              fontSize: 16,
              fontWeight: 600,
              cursor: 'pointer'
            }}
          >
            发送消息
          </button>
        )}
      </div>

      {/* 统计信息 */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
        gap: 20,
        marginBottom: 24
      }}>
        <div style={{
          background: '#fff',
          borderRadius: 12,
          padding: 20,
          textAlign: 'center',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: 20, fontWeight: 700, color: '#A67C52', marginBottom: 8 }}>
            {profile.stats.posted_tasks}
          </div>
          <div style={{ fontSize: 14, color: '#666' }}>发布的任务</div>
        </div>
        
        <div style={{
          background: '#fff',
          borderRadius: 12,
          padding: 20,
          textAlign: 'center',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: 20, fontWeight: 700, color: '#28a745', marginBottom: 8 }}>
            {profile.stats.taken_tasks}
          </div>
          <div style={{ fontSize: 14, color: '#666' }}>接受的任务</div>
        </div>
        
        <div style={{
          background: '#fff',
          borderRadius: 12,
          padding: 20,
          textAlign: 'center',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: 20, fontWeight: 700, color: '#007bff', marginBottom: 8 }}>
            {profile.stats.completed_tasks}
          </div>
          <div style={{ fontSize: 14, color: '#666' }}>完成率</div>
        </div>
        
        <div style={{
          background: '#fff',
          borderRadius: 12,
          padding: 20,
          textAlign: 'center',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: 20, fontWeight: 700, color: '#ffc107', marginBottom: 8 }}>
            {profile.stats.total_reviews}
          </div>
          <div style={{ fontSize: 14, color: '#666' }}>评价数量</div>
        </div>
      </div>

      {/* 最近任务 */}
      {profile.recent_tasks.length > 0 && (
        <div style={{
          background: '#fff',
          borderRadius: 16,
          padding: 24,
          marginBottom: 24,
          boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
        }}>
          <h2 style={{ 
            fontSize: 20, 
            fontWeight: 700, 
            color: '#333',
            marginBottom: 20
          }}>
            最近任务
          </h2>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {profile.recent_tasks.map(task => (
              <div key={task.id} style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                padding: '12px 16px',
                background: '#f8f9fa',
                borderRadius: 8,
                border: '1px solid #e9ecef'
              }}>
                <div style={{ flex: 1 }}>
                  <div style={{ 
                    fontSize: 16, 
                    fontWeight: 600, 
                    color: '#333',
                    marginBottom: 4
                  }}>
                    {task.title}
                  </div>
                  <div style={{ fontSize: 14, color: '#666' }}>
                    {task.task_type} • £{task.reward}
                  </div>
                </div>
                
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <span style={{
                    padding: '4px 8px',
                    borderRadius: 4,
                    fontSize: 12,
                    fontWeight: 600,
                    color: '#fff',
                    background: getStatusColor(task.status)
                  }}>
                    {getStatusText(task.status)}
                  </span>
                  
                  <button
                    onClick={() => handleViewTask(task.id)}
                    style={{
                      padding: '6px 12px',
                      border: '1px solid #A67C52',
                      borderRadius: 4,
                      background: 'transparent',
                      color: '#A67C52',
                      cursor: 'pointer',
                      fontSize: 12,
                      fontWeight: 600
                    }}
                  >
                    查看
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 用户评价 */}
      {profile.reviews.length > 0 && (
        <div style={{
          background: '#fff',
          borderRadius: 16,
          padding: 24,
          boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
        }}>
          <h2 style={{ 
            fontSize: 20, 
            fontWeight: 700, 
            color: '#333',
            marginBottom: 20
          }}>
            用户评价 ({profile.reviews.length})
          </h2>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {profile.reviews.map(review => (
              <div key={review.id} style={{
                padding: '16px',
                background: '#f8f9fa',
                borderRadius: 8,
                border: '1px solid #e9ecef'
              }}>
                <div style={{ 
                  display: 'flex', 
                  justifyContent: 'space-between', 
                  alignItems: 'flex-start',
                  marginBottom: 8
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 14, fontWeight: 600, color: '#333' }}>
                      {review.reviewer_name}
                    </span>
                    {renderStars(review.rating)}
                    <span style={{ fontSize: 16, fontWeight: 600, color: '#333' }}>
                      {review.rating}.0
                    </span>
                  </div>
                  
                  <span style={{ fontSize: 12, color: '#666' }}>
                    {new Date(review.created_at).toLocaleDateString('zh-CN')}
                  </span>
                </div>
                
                {review.comment && (
                  <div style={{ 
                    fontSize: 14, 
                    color: '#555',
                    lineHeight: 1.5
                  }}>
                    {review.comment}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {profile.reviews.length === 0 && (
        <div style={{
          background: '#fff',
          borderRadius: 16,
          padding: 40,
          textAlign: 'center',
          boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: 16, color: '#666' }}>
            暂无评价
          </div>
        </div>
      )}
    </div>
  );
};

export default UserProfile; 