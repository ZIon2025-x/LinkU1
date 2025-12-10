import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchCurrentUser, updateAvatar, getPublicSystemSettings, getStudentVerificationStatus } from '../api';
import api from '../api';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import LazyImage from '../components/LazyImage';
import SkeletonLoader from '../components/SkeletonLoader';

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
  const [isStudentVerified, setIsStudentVerified] = useState(false);
  const [studentUniversity, setStudentUniversity] = useState<{name: string; name_cn: string} | null>(null);

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
      
      // 加载系统设置
      try {
        const settings = await getPublicSystemSettings();
        setSystemSettings(settings);
      } catch (error) {
                setSystemSettings({ vip_button_visible: true }); // 默认显示
      }
      setUser(userInfo);
      
      // 加载用户评价数据
      try {
        const reviewsResponse = await api.get(`/api/users/${userInfo.id}/reviews`);
        setReviews(reviewsResponse.data || []);
      } catch (reviewError) {
                // API调用失败时显示空评价列表
        setReviews([]);
      }
      
      // 加载学生认证状态
      try {
        const verificationResponse = await getStudentVerificationStatus();
        if (verificationResponse.code === 200 && verificationResponse.data) {
          setIsStudentVerified(verificationResponse.data.is_verified || false);
          setStudentUniversity(verificationResponse.data.university || null);
        }
      } catch (error) {
        // 静默失败，不影响主流程
        setIsStudentVerified(false);
        setStudentUniversity(null);
      }
    } catch (error) {
            setShowLoginModal(true);
    } finally {
      setLoading(false);
    }
  };

  const handleAvatarChange = async (newAvatar: string) => {
    if (!user) return;
    
    setSaving(true);
    try {
      const result = await updateAvatar(newAvatar);
      setUser({ ...user, avatar: newAvatar });
      setShowAvatars(false);
    } catch (error) {
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
        padding: '20px'
      }}>
        <SkeletonLoader type="user" count={1} />
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
              <LazyImage
                src={user.avatar || '/static/avatar1.png'}
                alt={t('profile.avatar')}
                onError={() => {}}
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
                  <div
                    key={src}
                    onClick={() => handleAvatarChange(src)}
                    style={{
                      width: isMobile ? '50px' : '60px', 
                      height: isMobile ? '50px' : '60px', 
                      borderRadius: '50%', 
                      border: src === user.avatar ? '3px solid #3b82f6' : '2px solid #e2e8f0', 
                      cursor: 'pointer', 
                      background: '#fff', 
                      overflow: 'hidden',
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
                  >
                    <LazyImage
                      src={src}
                      alt={t('profile.optionalAvatar')}
                      style={{
                        width: '100%',
                        height: '100%',
                        objectFit: 'cover'
                      }}
                    />
                  </div>
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
              borderRadius: '8px',
              cursor: 'pointer',
              transition: 'all 0.2s ease'
            }}
            onClick={() => {
              navigator.clipboard.writeText(user.id);
              // 可以添加一个简单的提示
              const button = document.querySelector('[data-copy-id]') as HTMLElement;
              if (button) {
                const originalText = button.textContent;
                button.textContent = t('profile.idCopied');
                setTimeout(() => {
                  button.textContent = originalText;
                }, 2000);
              }
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(59, 130, 246, 0.2)';
              e.currentTarget.style.transform = 'scale(1.05)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(59, 130, 246, 0.1)';
              e.currentTarget.style.transform = 'scale(1)';
            }}
            data-copy-id>
              {user.id}
            </span>
          </div>
          
          {/* 邀请提示 */}
          <div style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '8px',
            marginBottom: '20px',
            padding: '12px 16px',
            background: 'linear-gradient(135deg, rgba(34, 197, 94, 0.1) 0%, rgba(16, 185, 129, 0.1) 100%)',
            borderRadius: '12px',
            border: '1px solid rgba(34, 197, 94, 0.2)',
            position: 'relative'
          }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px',
              fontWeight: '600',
              color: '#059669'
            }}>
              <span>{t('profile.inviteTip')}</span>
            </div>
            <div style={{
              fontSize: '13px',
              color: '#047857',
              textAlign: 'center',
              lineHeight: '1.4'
            }}>
              {t('profile.inviteDescription')}
            </div>
            <button
              style={{
                background: 'linear-gradient(135deg, #22c55e 0%, #10b981 100%)',
                color: 'white',
                border: 'none',
                borderRadius: '8px',
                padding: '6px 12px',
                fontSize: '12px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                boxShadow: '0 2px 4px rgba(34, 197, 94, 0.2)'
              }}
              onClick={() => {
                navigator.clipboard.writeText(user.id);
                const button = document.querySelector('[data-copy-invite]') as HTMLElement;
                if (button) {
                  const originalText = button.textContent;
                  button.textContent = t('profile.idCopied');
                  button.style.background = 'linear-gradient(135deg, #16a34a 0%, #059669 100%)';
                  setTimeout(() => {
                    button.textContent = originalText;
                    button.style.background = 'linear-gradient(135deg, #22c55e 0%, #10b981 100%)';
                  }, 2000);
                }
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-1px)';
                e.currentTarget.style.boxShadow = '0 4px 8px rgba(34, 197, 94, 0.3)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 2px 4px rgba(34, 197, 94, 0.2)';
              }}
              data-copy-invite>
              {t('profile.copyId')}
            </button>
          </div>
          
          {/* 用户名和学生标识 */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '12px',
            marginBottom: '20px',
            flexWrap: 'wrap'
          }}>
            <h2 style={{
              fontSize: isMobile ? '24px' : '28px',
              fontWeight: '700',
              color: '#1e293b',
              margin: '0'
            }}>
              {user.name || `用户${user.id}`}
            </h2>
            {isStudentVerified && (
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                color: '#fff',
                padding: '6px 14px',
                borderRadius: '20px',
                fontSize: '14px',
                fontWeight: '600',
                boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
              }}
              title={studentUniversity ? `${studentUniversity.name} (${studentUniversity.name_cn})` : t('settings.isVerified')}
              >
                <span>🎓</span>
                <span>{t('profile.student') || '学生'}</span>
              </div>
            )}
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
                {user.task_count}
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
                {user.completed_task_count}
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
