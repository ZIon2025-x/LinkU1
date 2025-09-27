import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchCurrentUser, updateAvatar } from '../api';
import api from '../api';
import LoginModal from '../components/LoginModal';

const AVATARS = [
  '/avatar1.png',
  '/avatar2.png', 
  '/avatar3.png',
  '/avatar4.png',
  '/avatar5.png'
];

interface User {
  id: string;
  name: string;
  email: string;
  phone?: string;
  avatar?: string;
  user_level: string;
  is_verified?: number;
  created_at: string;
  avg_rating?: number;
  total_tasks?: number;
  completed_tasks?: number;
}

interface Review {
  id: string;
  reviewer_name: string;
  reviewer_avatar: string;
  rating: number;
  comment: string;
  created_at: string;
  task_title: string;
  is_anonymous: boolean;
}

const Profile: React.FC = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(null);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [showAvatars, setShowAvatars] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  useEffect(() => {
    loadUserData();
  }, []);

  const loadUserData = async () => {
    try {
      setLoading(true);
      const userInfo = await fetchCurrentUser();
      setUser(userInfo);
      
      // 加载用户评价数据
      try {
        const reviewsResponse = await api.get(`/api/users/${userInfo.id}/reviews`);
        setReviews(reviewsResponse.data || []);
      } catch (reviewError) {
        console.error('加载评价数据失败:', reviewError);
        // API调用失败时显示空评价列表
        setReviews([]);
      }
    } catch (error) {
      console.error('加载用户数据失败:', error);
      setShowLoginModal(true);
    } finally {
      setLoading(false);
    }
  };

  const handleAvatarChange = async (newAvatar: string) => {
    if (!user) return;
    
    setSaving(true);
    try {
      await updateAvatar(newAvatar);
      setUser({ ...user, avatar: newAvatar });
      setShowAvatars(false);
    } catch (error) {
      console.error('更新头像失败:', error);
      alert('更新头像失败，请重试');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div style={{ 
        minHeight: '100vh', 
        background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <div style={{ 
          background: '#fff', 
          padding: '40px', 
          borderRadius: '20px',
          textAlign: 'center',
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: '48px', marginBottom: '20px' }}>⏳</div>
          <div style={{ fontSize: '18px', color: '#64748b' }}>加载中...</div>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div style={{ 
        minHeight: '100vh', 
        background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <div style={{ 
          background: '#fff', 
          padding: '40px', 
          borderRadius: '20px',
          textAlign: 'center',
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: '48px', marginBottom: '20px' }}>❌</div>
          <div style={{ fontSize: '18px', color: '#64748b' }}>加载用户数据失败</div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
      padding: '20px'
    }}>
      <div style={{ 
        maxWidth: '1000px', 
        margin: '0 auto',
        background: '#fff',
        borderRadius: '20px',
        boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {/* 页面头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
          color: '#fff',
          padding: '40px',
          textAlign: 'center',
          position: 'relative'
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: 'absolute',
              left: '20px',
              top: '20px',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: '10px 20px',
              borderRadius: '25px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '600',
              backdropFilter: 'blur(10px)',
              transition: 'all 0.3s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.3)';
              e.currentTarget.style.transform = 'translateY(-2px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            ← 返回首页
          </button>
          
          <div style={{ fontSize: 48, marginBottom: 16, filter: 'brightness(0) invert(1)' }}>👤</div>
          <h1 style={{ 
            margin: '0 0 10px 0', 
            fontSize: '32px', 
            fontWeight: 'bold' 
          }}>
            个人主页
          </h1>
          <p style={{ 
            fontSize: '16px', 
            opacity: 0.9,
            margin: 0
          }}>
            查看和管理您的个人信息
          </p>
        </div>

        {/* 用户基本信息卡片 */}
        <div style={{
          padding: '40px',
          textAlign: 'center'
        }}>
          <div style={{ marginBottom: '30px' }}>
            <div style={{ position: 'relative', display: 'inline-block' }}>
              <img
                src={user.avatar || '/avatar1.png'}
                alt="头像"
                style={{
                  width: '120px',
                  height: '120px',
                  borderRadius: '50%',
                  border: '4px solid #3b82f6',
                  objectFit: 'cover',
                  boxShadow: '0 8px 25px rgba(59, 130, 246, 0.3)'
                }}
              />
              <button 
                onClick={() => setShowAvatars(v => !v)} 
                style={{
                  position: 'absolute', 
                  right: '-10px', 
                  bottom: '-10px', 
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)', 
                  color: '#fff', 
                  border: 'none', 
                  borderRadius: '50%', 
                  width: '36px', 
                  height: '36px', 
                  fontSize: '16px', 
                  fontWeight: '700', 
                  cursor: 'pointer',
                  boxShadow: '0 4px 12px rgba(59, 130, 246, 0.4)',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'scale(1.1)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'scale(1)';
                }}
              >
                ✏️
              </button>
            </div>
          
            {showAvatars && (
              <div style={{
                display: 'flex', 
                gap: '16px', 
                marginTop: '20px', 
                flexWrap: 'wrap', 
                justifyContent: 'center',
                padding: '20px',
                background: '#f8fafc',
                borderRadius: '16px',
                border: '1px solid #e2e8f0'
              }}>
                {AVATARS.map(src => (
                  <img 
                    key={src} 
                    src={src} 
                    alt="可选头像" 
                    onClick={() => handleAvatarChange(src)} 
                    style={{
                      width: '60px', 
                      height: '60px', 
                      borderRadius: '50%', 
                      border: src === user.avatar ? '3px solid #3b82f6' : '2px solid #e2e8f0', 
                      cursor: 'pointer', 
                      background: '#fff', 
                      objectFit: 'cover', 
                      transition: 'all 0.3s ease',
                      boxShadow: src === user.avatar ? '0 4px 12px rgba(59, 130, 246, 0.3)' : '0 2px 8px rgba(0,0,0,0.1)'
                    }}
                    onMouseEnter={(e) => {
                      if (src !== user.avatar) {
                        e.currentTarget.style.borderColor = '#3b82f6';
                        e.currentTarget.style.transform = 'scale(1.1)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (src !== user.avatar) {
                        e.currentTarget.style.borderColor = '#e2e8f0';
                        e.currentTarget.style.transform = 'scale(1)';
                      }
                    }}
                  />
                ))}
              </div>
            )}
          </div>
          
          <h1 style={{ 
            fontSize: '32px', 
            fontWeight: '800', 
            color: '#1e293b',
            marginBottom: '8px'
          }}>
            {user.name || `用户${user.id}`}
            {user.is_verified === 1 && (
              <span style={{ 
                color: '#10b981', 
                marginLeft: '12px',
                fontSize: '24px'
              }}>
                ✓
              </span>
            )}
          </h1>
          
          {/* 用户ID显示 */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px',
            marginBottom: '16px',
            padding: '8px 16px',
            background: 'rgba(59, 130, 246, 0.1)',
            borderRadius: '20px',
            border: '1px solid rgba(59, 130, 246, 0.2)'
          }}>
            <span style={{ 
              color: '#64748b', 
              fontSize: '14px',
              fontWeight: '500'
            }}>
              🆔 用户ID:
            </span>
            <span style={{ 
              color: '#3b82f6', 
              fontSize: '16px',
              fontWeight: '700',
              fontFamily: 'monospace',
              background: 'rgba(59, 130, 246, 0.1)',
              padding: '4px 8px',
              borderRadius: '8px'
            }}>
              {user.id}
            </span>
          </div>
          
          <div style={{
            display: 'flex',
            justifyContent: 'center',
            gap: '20px',
            marginBottom: '30px',
            flexWrap: 'wrap'
          }}>
            <div style={{
              background: 'linear-gradient(135deg, #f8fafc, #e2e8f0)',
              padding: '12px 24px',
              borderRadius: '25px',
              border: '1px solid #cbd5e1'
            }}>
              <span style={{ color: '#64748b', fontSize: '14px' }}>会员等级</span>
              <div style={{ 
                color: user.user_level === 'super' ? '#8b5cf6' : user.user_level === 'vip' ? '#f59e0b' : '#64748b',
                fontWeight: '700',
                fontSize: '16px'
              }}>
                {user.user_level === 'super' ? '超级VIP' : user.user_level === 'vip' ? 'VIP' : '普通用户'}
              </div>
            </div>
            
            <div style={{
              background: 'linear-gradient(135deg, #f8fafc, #e2e8f0)',
              padding: '12px 24px',
              borderRadius: '25px',
              border: '1px solid #cbd5e1'
            }}>
              <span style={{ color: '#64748b', fontSize: '14px' }}>注册时间</span>
              <div style={{ color: '#1e293b', fontWeight: '600', fontSize: '16px' }}>
                {new Date(user.created_at).toLocaleDateString()}
              </div>
            </div>
          </div>
        </div>

        {/* 统计信息卡片 */}
        <div style={{
          padding: '0 40px 40px 40px'
        }}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: '20px',
            marginBottom: '40px'
          }}>
            <div style={{
              background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
              color: '#fff',
              padding: '24px',
              borderRadius: '16px',
              textAlign: 'center',
              boxShadow: '0 8px 25px rgba(59, 130, 246, 0.3)'
            }}>
              <div style={{ fontSize: '32px', marginBottom: '8px' }}>📊</div>
              <div style={{ fontSize: '24px', fontWeight: '800', marginBottom: '4px' }}>
                {user.total_tasks || 0}
              </div>
              <div style={{ fontSize: '14px', opacity: 0.9 }}>总任务数</div>
            </div>
            
            <div style={{
              background: 'linear-gradient(135deg, #10b981, #059669)',
              color: '#fff',
              padding: '24px',
              borderRadius: '16px',
              textAlign: 'center',
              boxShadow: '0 8px 25px rgba(16, 185, 129, 0.3)'
            }}>
              <div style={{ fontSize: '32px', marginBottom: '8px' }}>✅</div>
              <div style={{ fontSize: '24px', fontWeight: '800', marginBottom: '4px' }}>
                {user.completed_tasks || 0}
              </div>
              <div style={{ fontSize: '14px', opacity: 0.9 }}>完成任务</div>
            </div>
            
            <div style={{
              background: 'linear-gradient(135deg, #f59e0b, #d97706)',
              color: '#fff',
              padding: '24px',
              borderRadius: '16px',
              textAlign: 'center',
              boxShadow: '0 8px 25px rgba(245, 158, 11, 0.3)'
            }}>
              <div style={{ fontSize: '32px', marginBottom: '8px' }}>⭐</div>
              <div style={{ fontSize: '24px', fontWeight: '800', marginBottom: '4px' }}>
                {user.avg_rating ? user.avg_rating.toFixed(1) : '0.0'}
              </div>
              <div style={{ fontSize: '14px', opacity: 0.9 }}>平均评分</div>
            </div>
          </div>

          {/* 用户评价 */}
          <div style={{
            background: '#f8fafc',
            borderRadius: '16px',
            padding: '30px',
            border: '1px solid #e2e8f0'
          }}>
            <h3 style={{
              fontSize: '20px',
              fontWeight: '700',
              color: '#1e293b',
              marginBottom: '20px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}>
              💬 用户评价
            </h3>
            
            {reviews.length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {reviews.map(review => (
                  <div key={review.id} style={{
                    background: '#fff',
                    padding: '20px',
                    borderRadius: '12px',
                    border: '1px solid #e2e8f0',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                  }}>
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '12px',
                      marginBottom: '12px'
                    }}>
                      <div style={{ flex: 1 }}>
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '8px',
                          marginBottom: '4px'
                        }}>
                          <span style={{
                            fontWeight: '600',
                            color: '#1e293b'
                          }}>
                            {review.is_anonymous ? '匿名用户' : review.reviewer_name}
                          </span>
                          <div style={{
                            display: 'flex',
                            gap: '2px'
                          }}>
                            {[...Array(5)].map((_, i) => (
                              <span
                                key={i}
                                style={{
                                  color: i < review.rating ? '#f59e0b' : '#d1d5db',
                                  fontSize: '14px'
                                }}
                              >
                                ⭐
                              </span>
                            ))}
                          </div>
                        </div>
                        <div style={{
                          fontSize: '12px',
                          color: '#64748b'
                        }}>
                          {review.task_title} • {new Date(review.created_at).toLocaleDateString()}
                        </div>
                      </div>
                    </div>
                    <p style={{
                      color: '#374151',
                      lineHeight: '1.5',
                      margin: 0
                    }}>
                      {review.comment}
                    </p>
                  </div>
                ))}
              </div>
            ) : (
              <div style={{
                textAlign: 'center',
                color: '#64748b',
                padding: '40px 20px'
              }}>
                <div style={{ fontSize: '48px', marginBottom: '16px' }}>💭</div>
                <div style={{ fontSize: '16px' }}>暂无评价</div>
              </div>
            )}
          </div>
        </div>
      </div>
      
      {/* 登录弹窗 */}
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => {
          setShowLoginModal(false);
          navigate('/');
        }}
        onSuccess={() => {
          window.location.reload();
        }}
        onReopen={() => {
          setShowLoginModal(true);
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => {
          setShowForgotPasswordModal(true);
        }}
        onHideForgotPassword={() => {
          setShowForgotPasswordModal(false);
        }}
      />
    </div>
  );
};

export default Profile;
