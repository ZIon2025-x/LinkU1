import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchCurrentUser, updateAvatar, getPublicSystemSettings } from '../api';
import api from '../api';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';

const AVATARS = [
  '/static/avatar1.png',
  '/static/avatar2.png', 
  '/static/avatar3.png',
  '/static/avatar4.png',
  '/static/avatar5.png'
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
  task_count?: number;
  completed_tasks?: number;
  completed_task_count?: number;
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
  const { t } = useLanguage();
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(null);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [showAvatars, setShowAvatars] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [systemSettings, setSystemSettings] = useState({ vip_button_visible: true });
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    loadUserData();
  }, []);

  // 检测移动端
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth <= 768);
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  const loadUserData = async () => {
    try {
      setLoading(true);
      const userInfo = await fetchCurrentUser();
      console.log('Profile页面加载的用户数据:', userInfo);
      
      // 加载系统设置
      try {
        const settings = await getPublicSystemSettings();
        setSystemSettings(settings);
        console.log('系统设置加载成功:', settings);
      } catch (error) {
        console.error('加载系统设置失败:', error);
        setSystemSettings({ vip_button_visible: true }); // 默认显示
      }
      console.log('用户头像字段:', userInfo.avatar);
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
    
    console.log('开始更新头像:', newAvatar);
    setSaving(true);
    try {
      const result = await updateAvatar(newAvatar);
      console.log('头像更新API返回结果:', result);
      setUser({ ...user, avatar: newAvatar });
      console.log('前端用户状态已更新:', { ...user, avatar: newAvatar });
      setShowAvatars(false);
    } catch (error) {
      console.error('更新头像失败:', error);
      alert(t('profile.updateAvatarFailed'));
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
          <div style={{ fontSize: '18px', color: '#64748b' }}>{t('profile.loading')}</div>
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
          <div style={{ fontSize: '18px', color: '#64748b' }}>{t('profile.loadUserDataFailed')}</div>
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
            {t('profile.backToHome')}
          </button>
          
          <div style={{ fontSize: 48, marginBottom: 16, filter: 'brightness(0) invert(1)' }}>👤</div>
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
            {t('profile.personalProfile')}
          </h1>
          <p style={{ 
            fontSize: '16px', 
            opacity: 0.9,
            margin: 0
          }}>
            {t('profile.viewAndManageInfo')}
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
                src={user.avatar || '/static/avatar1.png'}
                alt={t('profile.avatar')}
                onError={(e) => {
                  console.error('头像加载失败:', e.currentTarget.src);
                  e.currentTarget.src = '/static/avatar1.png';
                }}
                onLoad={(e) => {
                  console.log('头像加载成功:', e.currentTarget.src);
                }}
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
                  right: isMobile ? '5px' : '8px', 
                  bottom: isMobile ? '5px' : '8px', 
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)', 
                  color: '#fff', 
                  border: 'none', 
                  borderRadius: '50%', 
                  width: isMobile ? '28px' : '32px', 
                  height: isMobile ? '28px' : '32px', 
                  fontSize: isMobile ? '12px' : '14px', 
                  fontWeight: '700', 
                  cursor: 'pointer',
                  boxShadow: '0 4px 12px rgba(59, 130, 246, 0.4)',
                  transition: 'all 0.3s ease',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  zIndex: 10
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
                gap: isMobile ? '12px' : '16px', 
                marginTop: '20px', 
                flexWrap: 'wrap', 
                justifyContent: 'center',
                padding: isMobile ? '16px' : '20px',
                background: '#f8fafc',
                borderRadius: '16px',
                border: '1px solid #e2e8f0'
              }}>
                {AVATARS.map(src => (
                  <img 
                    key={src} 
                    src={src} 
                    alt={t('profile.optionalAvatar')} 
                    onClick={() => handleAvatarChange(src)} 
                    style={{
                      width: isMobile ? '50px' : '60px', 
                      height: isMobile ? '50px' : '60px', 
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
            {user.name || `用户${user.id}`}
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
              {t('profile.userId')}
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
              <span style={{ color: '#64748b', fontSize: '14px' }}>{t('profile.memberLevel')}</span>
              <div style={{ 
                color: user.user_level === 'super' ? '#8b5cf6' : user.user_level === 'vip' ? '#f59e0b' : '#64748b',
                fontWeight: '700',
                fontSize: '16px'
              }}>
                {user.user_level === 'super' ? t('profile.superVip') : user.user_level === 'vip' ? t('profile.vip') : t('profile.normalUser')}
              </div>
            </div>
            
            <div style={{
              background: 'linear-gradient(135deg, #f8fafc, #e2e8f0)',
              padding: '12px 24px',
              borderRadius: '25px',
              border: '1px solid #cbd5e1'
            }}>
              <span style={{ color: '#64748b', fontSize: '14px' }}>{t('profile.registrationTime')}</span>
              <div style={{ color: '#1e293b', fontWeight: '600', fontSize: '16px' }}>
                {new Date(user.created_at).toLocaleDateString()}
              </div>
            </div>
          </div>

          {/* VIP会员按钮 - 根据系统设置控制显示 */}
          {systemSettings.vip_button_visible && (
            <div style={{
              display: 'flex',
              justifyContent: 'center',
              marginBottom: '30px'
            }}>
              <button
                onClick={() => navigate('/vip')}
                style={{
                  background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                  color: '#8B4513',
                  border: 'none',
                  padding: '16px 32px',
                  borderRadius: '25px',
                  fontSize: '18px',
                  fontWeight: '700',
                  cursor: 'pointer',
                  boxShadow: '0 4px 15px rgba(255, 215, 0, 0.4)',
                  transition: 'all 0.3s ease',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  minWidth: '200px',
                  justifyContent: 'center'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 6px 20px rgba(255, 215, 0, 0.5)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 4px 15px rgba(255, 215, 0, 0.4)';
                }}
              >
                <span style={{ fontSize: '20px' }}>👑</span>
                {t('profile.vipMember')}
              </button>
            </div>
          )}
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
                {user.task_count || user.total_tasks || 0}
              </div>
              <div style={{ fontSize: '14px', opacity: 0.9 }}>{t('profile.totalTasks')}</div>
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
                {user.completed_task_count || user.completed_tasks || 0}
              </div>
              <div style={{ fontSize: '14px', opacity: 0.9 }}>{t('profile.completedTasks')}</div>
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
              <div style={{ fontSize: '14px', opacity: 0.9 }}>{t('profile.averageRating')}</div>
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
              {t('profile.userReviews')}
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
                            {review.is_anonymous ? t('profile.anonymousUser') : review.reviewer_name}
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
                <div style={{ fontSize: '16px' }}>{t('profile.noReviews')}</div>
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
