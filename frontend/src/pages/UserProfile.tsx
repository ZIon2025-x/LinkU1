import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { getUserProfile, fetchCurrentUser } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';

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
    completed_task_count: number;
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
  const { t } = useLanguage();
  const { userId } = useParams();
  const { navigate } = useLocalizedNavigation();
  const [profile, setProfile] = useState<UserProfileType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [currentUser, setCurrentUser] = useState<any>(null);

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
      case 'open': return t('userProfile.taskStatus.open');
      case 'taken': return t('userProfile.taskStatus.taken');
      case 'in_progress': return t('userProfile.taskStatus.in_progress');
      case 'pending_confirmation': return t('userProfile.taskStatus.pending_confirmation');
      case 'completed': return t('userProfile.taskStatus.completed');
      case 'cancelled': return t('userProfile.taskStatus.cancelled');
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
      case 'normal': return t('userProfile.normalUser');
      case 'vip': return t('userProfile.vipMember');
      case 'super': return t('userProfile.superMember');
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
        {t('userProfile.loading')}
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
        {error || t('userProfile.userNotExist')}
      </div>
    );
  }

  const isOwnProfile = currentUser && currentUser.id === userId;

  return (
    <div style={{ 
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '20px 0'
    }}>
      <div style={{
        maxWidth: 1200,
        margin: '0 auto',
        padding: '0 20px'
      }}>
        {/* 用户基本信息卡片 - 重新设计 */}
        <div style={{
          background: 'rgba(255, 255, 255, 0.95)',
          backdropFilter: 'blur(20px)',
          borderRadius: 24,
          padding: 40,
          marginBottom: 32,
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
          textAlign: 'center',
          position: 'relative',
          overflow: 'hidden'
        }}>
          {/* 装饰性背景 */}
          <div style={{
            position: 'absolute',
            top: -50,
            right: -50,
            width: 200,
            height: 200,
            background: 'linear-gradient(45deg, #667eea, #764ba2)',
            borderRadius: '50%',
            opacity: 0.1
          }} />
          <div style={{
            position: 'absolute',
            bottom: -30,
            left: -30,
            width: 150,
            height: 150,
            background: 'linear-gradient(45deg, #f093fb, #f5576c)',
            borderRadius: '50%',
            opacity: 0.1
          }} />

          <div style={{ position: 'relative', zIndex: 1 }}>
            <div style={{ marginBottom: 24 }}>
              <div style={{
                position: 'relative',
                display: 'inline-block'
              }}>
                <img
                  src={profile.user.avatar || '/static/avatar1.png'}
                  alt="头像"
                  style={{
                    width: 140,
                    height: 140,
                    borderRadius: '50%',
                    objectFit: 'cover',
                    border: '6px solid rgba(255, 255, 255, 0.8)',
                    boxShadow: '0 10px 30px rgba(0,0,0,0.2)'
                  }}
                />
              </div>
            </div>
            
            <h1 style={{ 
              position: 'absolute',
              top: '-100px',
              left: '-100px',
              width: '1px',
              height: '1px',
              padding: '0',
              margin: '0',
              overflow: 'hidden',
              clip: 'rect(0, 0, 0, 0)',
              whiteSpace: 'nowrap',
              border: '0',
              fontSize: '1px',
              color: 'transparent',
              background: 'transparent'
            }}>
              {profile.user.name}
            </h1>

            <div style={{ 
              display: 'flex', 
              justifyContent: 'center', 
              alignItems: 'center',
              gap: 24,
              marginBottom: 32,
              flexWrap: 'wrap'
            }}>
              <div style={{
                padding: '8px 20px',
                borderRadius: 25,
                fontSize: 14,
                fontWeight: 700,
                color: '#fff',
                background: getLevelColor(profile.user.user_level),
                boxShadow: '0 4px 15px rgba(0,0,0,0.2)',
                textTransform: 'uppercase',
                letterSpacing: '0.5px'
              }}>
                {getLevelText(profile.user.user_level)}
              </div>
              
              <div style={{ 
                display: 'flex', 
                alignItems: 'center', 
                gap: 8,
                padding: '8px 16px',
                background: 'rgba(255, 193, 7, 0.1)',
                borderRadius: 20,
                border: '1px solid rgba(255, 193, 7, 0.3)'
              }}>
                {renderStars(profile.user.avg_rating)}
                <span style={{ 
                  color: '#f57c00', 
                  fontSize: 16, 
                  fontWeight: 700,
                  marginLeft: 4
                }}>
                  {profile.user.avg_rating.toFixed(1)}
                </span>
              </div>
            </div>

            {/* 聊天功能已移除 - 用户应通过任务申请流程联系 */}
          </div>
        </div>

        {/* 详细统计信息卡片 */}
        <div style={{
          background: 'rgba(255, 255, 255, 0.95)',
          backdropFilter: 'blur(20px)',
          borderRadius: 20,
          padding: 32,
          marginBottom: 32,
          boxShadow: '0 15px 35px rgba(0,0,0,0.1)'
        }}>
          <h2 style={{
            fontSize: 24,
            fontWeight: 700,
            color: '#333',
            marginBottom: 24,
            textAlign: 'center',
            background: 'linear-gradient(45deg, #667eea, #764ba2)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent'
          }}>
            📊 {t('userProfile.detailedStats')}
          </h2>
          
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: 20
          }}>
            <div style={{
              background: 'linear-gradient(135deg, #667eea, #764ba2)',
              borderRadius: 16,
              padding: 24,
              textAlign: 'center',
              color: '#fff',
              boxShadow: '0 8px 25px rgba(102, 126, 234, 0.3)',
              position: 'relative',
              overflow: 'hidden'
            }}>
              <div style={{
                position: 'absolute',
                top: -20,
                right: -20,
                width: 80,
                height: 80,
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '50%'
              }} />
              <div style={{ position: 'relative', zIndex: 1 }}>
                <div style={{ fontSize: 32, fontWeight: 800, marginBottom: 8 }}>
                  {profile.stats.posted_tasks}
                </div>
                <div style={{ fontSize: 14, opacity: 0.9, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                  {t('userProfile.postedTasks')}
                </div>
              </div>
            </div>
            
            <div style={{
              background: 'linear-gradient(135deg, #4CAF50, #45a049)',
              borderRadius: 16,
              padding: 24,
              textAlign: 'center',
              color: '#fff',
              boxShadow: '0 8px 25px rgba(76, 175, 80, 0.3)',
              position: 'relative',
              overflow: 'hidden'
            }}>
              <div style={{
                position: 'absolute',
                top: -20,
                right: -20,
                width: 80,
                height: 80,
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '50%'
              }} />
              <div style={{ position: 'relative', zIndex: 1 }}>
                <div style={{ fontSize: 32, fontWeight: 800, marginBottom: 8 }}>
                  {profile.stats.taken_tasks}
                </div>
                <div style={{ fontSize: 14, opacity: 0.9, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                  {t('userProfile.takenTasks')}
                </div>
              </div>
            </div>
            
            <div style={{
              background: 'linear-gradient(135deg, #2196F3, #1976D2)',
              borderRadius: 16,
              padding: 24,
              textAlign: 'center',
              color: '#fff',
              boxShadow: '0 8px 25px rgba(33, 150, 243, 0.3)',
              position: 'relative',
              overflow: 'hidden'
            }}>
              <div style={{
                position: 'absolute',
                top: -20,
                right: -20,
                width: 80,
                height: 80,
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '50%'
              }} />
              <div style={{ position: 'relative', zIndex: 1 }}>
                <div style={{ fontSize: 32, fontWeight: 800, marginBottom: 8 }}>
                  {profile.user.completed_task_count}
                </div>
                <div style={{ fontSize: 14, opacity: 0.9, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                  {t('userProfile.completedTasks')}
                </div>
              </div>
            </div>
            
            <div style={{
              background: 'linear-gradient(135deg, #FF9800, #F57C00)',
              borderRadius: 16,
              padding: 24,
              textAlign: 'center',
              color: '#fff',
              boxShadow: '0 8px 25px rgba(255, 152, 0, 0.3)',
              position: 'relative',
              overflow: 'hidden'
            }}>
              <div style={{
                position: 'absolute',
                top: -20,
                right: -20,
                width: 80,
                height: 80,
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '50%'
              }} />
              <div style={{ position: 'relative', zIndex: 1 }}>
                <div style={{ fontSize: 32, fontWeight: 800, marginBottom: 8 }}>
                  {profile.stats.total_reviews}
                </div>
                <div style={{ fontSize: 14, opacity: 0.9, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                  ⭐ {t('userProfile.totalReviews')}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* 最近任务 */}
        {profile.recent_tasks.length > 0 && (
          <div style={{
            background: 'rgba(255, 255, 255, 0.95)',
            backdropFilter: 'blur(20px)',
            borderRadius: 20,
            padding: 32,
            marginBottom: 32,
            boxShadow: '0 15px 35px rgba(0,0,0,0.1)'
          }}>
            <h2 style={{ 
              fontSize: 24, 
              fontWeight: 700, 
              color: '#333',
              marginBottom: 24,
              textAlign: 'center',
              background: 'linear-gradient(45deg, #667eea, #764ba2)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}>
              📋 {t('userProfile.recentTasks')}
            </h2>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {profile.recent_tasks.map(task => (
                <div key={task.id} style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  padding: '20px 24px',
                  background: 'linear-gradient(135deg, rgba(102, 126, 234, 0.05), rgba(118, 75, 162, 0.05))',
                  borderRadius: 16,
                  border: '1px solid rgba(102, 126, 234, 0.1)',
                  transition: 'all 0.3s ease',
                  cursor: 'pointer'
                }}
                onMouseOver={(e) => {
                  const target = e.target as HTMLDivElement;
                  target.style.transform = 'translateY(-2px)';
                  target.style.boxShadow = '0 8px 25px rgba(102, 126, 234, 0.15)';
                }}
                onMouseOut={(e) => {
                  const target = e.target as HTMLDivElement;
                  target.style.transform = 'translateY(0)';
                  target.style.boxShadow = 'none';
                }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ 
                      fontSize: 18, 
                      fontWeight: 700, 
                      color: '#333',
                      marginBottom: 8,
                      lineHeight: 1.3
                    }}>
                      {task.title}
                    </div>
                    <div style={{ 
                      fontSize: 14, 
                      color: '#666',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 12
                    }}>
                      <span style={{
                        padding: '4px 8px',
                        background: 'rgba(102, 126, 234, 0.1)',
                        borderRadius: 6,
                        fontSize: 12,
                        fontWeight: 600,
                        color: '#667eea'
                      }}>
                        {task.task_type}
                      </span>
                      <span style={{ fontWeight: 600, color: '#4CAF50' }}>
                        £{task.reward}
                      </span>
                    </div>
                  </div>
                  
                  <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
                    <span style={{
                      padding: '8px 16px',
                      borderRadius: 20,
                      fontSize: 12,
                      fontWeight: 700,
                      color: '#fff',
                      background: getStatusColor(task.status),
                      textTransform: 'uppercase',
                      letterSpacing: '0.5px',
                      boxShadow: '0 4px 15px rgba(0,0,0,0.2)'
                    }}>
                      {getStatusText(task.status)}
                    </span>
                    
                    <button
                      onClick={() => handleViewTask(task.id)}
                      style={{
                        padding: '10px 20px',
                        border: '2px solid #667eea',
                        borderRadius: 20,
                        background: 'transparent',
                        color: '#667eea',
                        cursor: 'pointer',
                        fontSize: 14,
                        fontWeight: 700,
                        transition: 'all 0.3s ease',
                        textTransform: 'uppercase',
                        letterSpacing: '0.5px'
                      }}
                      onMouseOver={(e) => {
                        const target = e.target as HTMLButtonElement;
                        target.style.background = '#667eea';
                        target.style.color = '#fff';
                        target.style.transform = 'translateY(-1px)';
                      }}
                      onMouseOut={(e) => {
                        const target = e.target as HTMLButtonElement;
                        target.style.background = 'transparent';
                        target.style.color = '#667eea';
                        target.style.transform = 'translateY(0)';
                      }}
                    >
                      {t('userProfile.viewTask')}
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
            background: 'rgba(255, 255, 255, 0.95)',
            backdropFilter: 'blur(20px)',
            borderRadius: 20,
            padding: 32,
            marginBottom: 32,
            boxShadow: '0 15px 35px rgba(0,0,0,0.1)'
          }}>
            <h2 style={{ 
              fontSize: 24, 
              fontWeight: 700, 
              color: '#333',
              marginBottom: 24,
              textAlign: 'center',
              background: 'linear-gradient(45deg, #667eea, #764ba2)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}>
              ⭐ {t('userProfile.userReviews')} ({profile.reviews.length})
            </h2>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
              {profile.reviews.map(review => (
                <div key={review.id} style={{
                  padding: '24px',
                  background: 'linear-gradient(135deg, rgba(102, 126, 234, 0.05), rgba(118, 75, 162, 0.05))',
                  borderRadius: 16,
                  border: '1px solid rgba(102, 126, 234, 0.1)',
                  position: 'relative',
                  overflow: 'hidden'
                }}>
                  {/* 装饰性背景 */}
                  <div style={{
                    position: 'absolute',
                    top: -20,
                    right: -20,
                    width: 60,
                    height: 60,
                    background: 'rgba(102, 126, 234, 0.1)',
                    borderRadius: '50%'
                  }} />
                  
                  <div style={{ position: 'relative', zIndex: 1 }}>
                    <div style={{ 
                      display: 'flex', 
                      justifyContent: 'space-between', 
                      alignItems: 'flex-start',
                      marginBottom: 16
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                        <div style={{
                          width: 40,
                          height: 40,
                          borderRadius: '50%',
                          background: review.is_anonymous 
                            ? 'linear-gradient(45deg, #667eea, #764ba2)' 
                            : 'linear-gradient(45deg, #4CAF50, #45a049)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: '#fff',
                          fontSize: 16,
                          fontWeight: 'bold',
                          boxShadow: '0 4px 15px rgba(0,0,0,0.2)'
                        }}>
                          {review.is_anonymous ? '?' : review.reviewer_name.charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ 
                            fontSize: 16, 
                            fontWeight: 700, 
                            color: '#333',
                            marginBottom: 4
                          }}>
                            {review.is_anonymous ? t('userProfile.anonymousUser') : review.reviewer_name}
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            {renderStars(review.rating)}
                            <span style={{ 
                              fontSize: 18, 
                              fontWeight: 700, 
                              color: '#f57c00',
                              marginLeft: 4
                            }}>
                              {review.rating}.0
                            </span>
                          </div>
                        </div>
                      </div>
                      
                      <span style={{ 
                        fontSize: 12, 
                        color: '#999',
                        background: 'rgba(102, 126, 234, 0.1)',
                        padding: '4px 8px',
                        borderRadius: 8,
                        fontWeight: 600
                      }}>
                        {new Date(review.created_at).toLocaleDateString('zh-CN')}
                      </span>
                    </div>
                    
                    {review.comment && (
                      <div style={{ 
                        fontSize: 15, 
                        color: '#555',
                        lineHeight: 1.6,
                        background: 'rgba(255, 255, 255, 0.7)',
                        padding: '16px',
                        borderRadius: 12,
                        border: '1px solid rgba(102, 126, 234, 0.1)',
                        fontStyle: 'italic'
                      }}>
                        "{review.comment}"
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {profile.reviews.length === 0 && (
          <div style={{
            background: 'rgba(255, 255, 255, 0.95)',
            backdropFilter: 'blur(20px)',
            borderRadius: 20,
            padding: 60,
            textAlign: 'center',
            boxShadow: '0 15px 35px rgba(0,0,0,0.1)',
            marginBottom: 32
          }}>
            <div style={{
              fontSize: 48,
              marginBottom: 16,
              opacity: 0.3
            }}>
              ⭐
            </div>
            <div style={{ 
              fontSize: 18, 
              color: '#666',
              fontWeight: 600
            }}>
              {t('userProfile.noReviews')}
            </div>
            <div style={{ 
              fontSize: 14, 
              color: '#999',
              marginTop: 8
            }}>
              {t('userProfile.encourageReview')}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default UserProfile; 