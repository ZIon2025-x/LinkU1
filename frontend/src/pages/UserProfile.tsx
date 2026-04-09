import React, { useEffect, useState, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import api, { getUserProfile, fetchCurrentUser, fetchExpertByUser, getUserHotPosts, getUserStudentVerificationStatus } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { formatViewCount } from '../utils/formatUtils';
import ServiceDetailModal from '../components/ServiceDetailModal';
import LazyImage from '../components/LazyImage';
import MemberBadge from '../components/MemberBadge';
import SEOHead from '../components/SEOHead';

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
    reviewer_avatar?: string;  // 评价者头像（可选）
  }>;
}

const UserProfile: React.FC = () => {
  const { t, language } = useLanguage();
  const { userId } = useParams();
  const { navigate } = useLocalizedNavigation();
  const [profile, setProfile] = useState<UserProfileType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [taskExpert, setTaskExpert] = useState<any>(null);
  const [expertServices, setExpertServices] = useState<any[]>([]);
  const [, setLoadingExpert] = useState(false); void setLoadingExpert;
  const [showServiceDetailModal, setShowServiceDetailModal] = useState(false);
  const [selectedServiceId, setSelectedServiceId] = useState<number | null>(null);
  const [hotPosts, setHotPosts] = useState<any[]>([]);
  const [, setLoadingHotPosts] = useState(false); void setLoadingHotPosts;
  const [isStudentVerified, setIsStudentVerified] = useState(false);
  const [studentUniversity, setStudentUniversity] = useState<{name: string; name_cn: string} | null>(null);

  useEffect(() => {
    // 直接获取用户信息，HttpOnly Cookie会自动发送
    fetchCurrentUser().then(setCurrentUser).catch(() => setCurrentUser(null));
  }, []);

  const loadStudentVerification = useCallback(async () => {
    if (!userId) return;
    try {
      const verificationResponse = await getUserStudentVerificationStatus(userId);
      if (verificationResponse.code === 200 && verificationResponse.data) {
        setIsStudentVerified(verificationResponse.data.is_verified || false);
        setStudentUniversity(verificationResponse.data.university || null);
      }
    } catch (error) {
      // 静默失败，不影响主流程
      setIsStudentVerified(false);
      setStudentUniversity(null);
    }
  }, [userId]);

  useEffect(() => {
    if (userId) {
      loadUserProfile();
      loadTaskExpertInfo();
      loadHotPosts();
      // 加载学生认证状态（所有用户都可以看到）
      loadStudentVerification();
    }
  }, [userId, loadStudentVerification]);

  // 当页面重新获得焦点时刷新学生认证状态
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && userId) {
        // 页面重新可见时刷新学生认证状态
        loadStudentVerification();
      }
    };

    const handleFocus = () => {
      if (userId) {
        // 窗口获得焦点时刷新学生认证状态
        loadStudentVerification();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('focus', handleFocus);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('focus', handleFocus);
    };
  }, [userId, loadStudentVerification]);

  // 定期刷新学生认证状态（每30秒，仅在页面可见时）
  useEffect(() => {
    if (!userId) return;

    const interval = setInterval(() => {
      if (!document.hidden) {
        loadStudentVerification();
      }
    }, 30000); // 每30秒刷新一次

    return () => clearInterval(interval);
  }, [userId, loadStudentVerification]);

  const loadUserProfile = async () => {
    if (!userId) {
      setError(t('userProfile.userIdNotExist'));
      setLoading(false);
      return;
    }
    
    setLoading(true);
    try {
      // 数据库现在直接存储格式化ID，可以直接使用
      const data = await getUserProfile(userId);
      setProfile(data);
    } catch (error: any) {
      let errorMsg = t('userProfile.userNotExist');
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

  const loadTaskExpertInfo = async () => {
    if (!userId) return;

    setLoadingExpert(true);
    try {
      // Phase B1 收口: 走新 by-user 解析端点,拿到团队后再查该团队的服务列表
      const expertData = await fetchExpertByUser(userId);
      setTaskExpert(expertData);

      // 拿到 expert.id (新 8 字符团队 ID) 后查该团队的公开服务
      const servicesRes = await api.get(`/api/experts/${expertData.id}/services`, {
        params: { status: 'active' },
      });
      setExpertServices(Array.isArray(servicesRes.data) ? servicesRes.data : []);
    } catch (err: any) {
      // 如果不是任务达人 (404),忽略错误
      setTaskExpert(null);
      setExpertServices([]);
    } finally {
      setLoadingExpert(false);
    }
  };

  const handleServiceClick = (serviceId: number) => {
    setSelectedServiceId(serviceId);
    setShowServiceDetailModal(true);
  };

  const loadHotPosts = async () => {
    if (!userId) return;
    
    setLoadingHotPosts(true);
    try {
      const data = await getUserHotPosts(userId, 3);
      setHotPosts(data.posts || []);
    } catch (err: any) {
      // 如果用户没有帖子或出错，忽略错误
      setHotPosts([]);
    } finally {
      setLoadingHotPosts(false);
    }
  };

  const handleViewPost = (postId: number) => {
    const lang = language || 'zh';
    navigate(`/${lang}/forum/post/${postId}`);
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

  const _isOwnProfile = currentUser && currentUser.id === userId; void _isOwnProfile;

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '20px 0'
    }}>
      <SEOHead noindex={true} />
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
                <LazyImage
                  src={profile.user.avatar || '/static/avatar1.png'}
                  alt={t('userProfile.avatarAlt')}
                  width={140}
                  height={140}
                  style={{
                    borderRadius: '50%',
                    objectFit: 'cover',
                    border: '6px solid rgba(255, 255, 255, 0.8)',
                    boxShadow: '0 10px 30px rgba(0,0,0,0.2)'
                  }}
                />
                <MemberBadge level={profile.user.user_level} variant="avatar-corner" />
              </div>
            </div>
            
            {/* 用户名显示 */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '12px',
              marginBottom: 16,
              flexWrap: 'wrap'
            }}>
              <h1 style={{ 
                fontSize: 32,
                fontWeight: 700,
                color: '#333',
                margin: 0,
                textAlign: 'center'
              }}>
                {profile.user.name}
              </h1>
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
              alignItems: 'center',
              gap: 24,
              marginBottom: 32,
              flexWrap: 'wrap'
            }}>
              <MemberBadge level={profile.user.user_level} variant="full" labelVip="userProfile.vipMember" labelSuper="userProfile.superMember" />
              
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

            {/* 任务达人信息 */}
            {taskExpert && (
              <div style={{ marginTop: 24 }}>
                <div style={{
                  padding: '16px 24px',
                  background: 'linear-gradient(135deg, rgba(102, 126, 234, 0.1), rgba(118, 75, 162, 0.1))',
                  borderRadius: 16,
                  border: '2px solid rgba(102, 126, 234, 0.3)',
                  marginBottom: 16
                }}>
                  <div style={{ fontSize: 16, fontWeight: 600, color: '#667eea', marginBottom: 8 }}>
                    👑 {t('userProfile.taskExpert')}
                  </div>
                  {taskExpert.bio && (
                    <div style={{ fontSize: 14, color: '#666', lineHeight: 1.6 }}>
                      {taskExpert.bio}
                    </div>
                  )}
                </div>
                
                {/* 服务列表 */}
                {expertServices.length > 0 && (
                  <div style={{ marginTop: 24 }}>
                    <h3 style={{ fontSize: 18, fontWeight: 600, color: '#333', marginBottom: 16 }}>
                      {t('userProfile.serviceMenu')}
                    </h3>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                      {expertServices.map((service) => (
                        <div
                          key={service.id}
                          onClick={() => handleServiceClick(service.id)}
                          style={{
                            padding: '16px',
                            background: '#fff',
                            borderRadius: 12,
                            border: '1px solid #e2e8f0',
                            cursor: 'pointer',
                            transition: 'all 0.2s',
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.borderColor = '#667eea';
                            e.currentTarget.style.boxShadow = '0 4px 12px rgba(102, 126, 234, 0.15)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.borderColor = '#e2e8f0';
                            e.currentTarget.style.boxShadow = 'none';
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <div style={{ flex: 1 }}>
                              <div style={{ fontSize: 16, fontWeight: 600, color: '#333', marginBottom: 4 }}>
                                {service.service_name}
                              </div>
                              <div style={{ fontSize: 14, color: '#666' }}>
                                {service.description?.substring(0, 100)}
                                {service.description && service.description.length > 100 ? '...' : ''}
                              </div>
                            </div>
                            <div style={{ marginLeft: 16, textAlign: 'right' }}>
                              <div style={{ fontSize: 18, fontWeight: 700, color: '#667eea' }}>
                                {service.currency} {service.base_price.toFixed(2)}
                              </div>
                              <div style={{ fontSize: 12, color: '#999', marginTop: 4 }}>
                                {service.application_count} {t('userProfile.applications')}
                              </div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
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
            {profile.stats.posted_tasks > 0 && (
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
            )}
            
            {profile.stats.taken_tasks > 0 && (
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
            )}
            
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
                        {/* 他人用户主页：所有评价都显示为匿名 */}
                        <LazyImage
                          src="/static/logo.png"
                          alt={t('userProfile.anonymousUser')}
                          width={40}
                          height={40}
                          style={{
                            borderRadius: '50%',
                            objectFit: 'cover',
                            boxShadow: '0 4px 15px rgba(0,0,0,0.2)'
                          }}
                        />
                        <div>
                          <div style={{ 
                            fontSize: 16, 
                            fontWeight: 700, 
                            color: '#333',
                            marginBottom: 4
                          }}>
                            {/* 他人用户主页：所有评价都显示为匿名 */}
                            {t('userProfile.anonymousUser')}
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

        {/* 最热门帖子 */}
        {hotPosts.length > 0 && (
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
              🔥 最热门帖子
            </h2>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {hotPosts.map((post, index) => (
                <div 
                  key={post.id} 
                  onClick={() => handleViewPost(post.id)}
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    padding: '20px 24px',
                    background: index === 0 
                      ? 'linear-gradient(135deg, rgba(255, 193, 7, 0.1), rgba(255, 152, 0, 0.1))'
                      : 'linear-gradient(135deg, rgba(102, 126, 234, 0.05), rgba(118, 75, 162, 0.05))',
                    borderRadius: 16,
                    border: index === 0 
                      ? '2px solid rgba(255, 193, 7, 0.3)'
                      : '1px solid rgba(102, 126, 234, 0.1)',
                    transition: 'all 0.3s ease',
                    cursor: 'pointer',
                    position: 'relative'
                  }}
                  onMouseOver={(e) => {
                    const target = e.currentTarget;
                    target.style.transform = 'translateY(-2px)';
                    target.style.boxShadow = '0 8px 25px rgba(102, 126, 234, 0.15)';
                  }}
                  onMouseOut={(e) => {
                    const target = e.currentTarget;
                    target.style.transform = 'translateY(0)';
                    target.style.boxShadow = 'none';
                  }}
                >
                  {index === 0 && (
                    <div style={{
                      position: 'absolute',
                      top: -10,
                      right: 20,
                      background: 'linear-gradient(135deg, #FFD700, #FFA500)',
                      color: '#fff',
                      padding: '4px 12px',
                      borderRadius: 12,
                      fontSize: 12,
                      fontWeight: 700,
                      boxShadow: '0 4px 15px rgba(255, 193, 7, 0.4)'
                    }}>
                      🏆 最热
                    </div>
                  )}
                  
                  <div style={{ flex: 1 }}>
                    <div style={{ 
                      fontSize: 18, 
                      fontWeight: 700, 
                      color: '#333',
                      marginBottom: 8,
                      lineHeight: 1.3
                    }}>
                      {post.title}
                    </div>
                    {post.content_preview && (
                      <div style={{ 
                        fontSize: 14, 
                        color: '#666',
                        marginBottom: 8,
                        lineHeight: 1.5,
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden'
                      }}>
                        {post.content_preview}
                      </div>
                    )}
                    <div style={{ 
                      fontSize: 12, 
                      color: '#999',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 16
                    }}>
                      <span>👁️ {formatViewCount(post.view_count)}</span>
                      <span>💬 {post.reply_count}</span>
                      <span>❤️ {post.like_count}</span>
                      {post.category && (
                        <span style={{
                          padding: '2px 8px',
                          background: 'rgba(102, 126, 234, 0.1)',
                          borderRadius: 4,
                          color: '#667eea',
                          fontWeight: 600
                        }}>
                          {post.category.name}
                        </span>
                      )}
                    </div>
                  </div>
                  
                  <div style={{ marginLeft: 16 }}>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleViewPost(post.id);
                      }}
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
                      查看
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
      
      {/* 服务详情弹窗 */}
      <ServiceDetailModal
        isOpen={showServiceDetailModal}
        onClose={() => {
          setShowServiceDetailModal(false);
          setSelectedServiceId(null);
        }}
        serviceId={selectedServiceId}
        onApplySuccess={() => {
          // 重新加载服务列表
          loadTaskExpertInfo();
        }}
      />

      {/* 移动端响应式样式 */}
      <style>
        {`
          /* 移动端适配 */
          @media (max-width: 768px) {
            /* 容器移动端优化 */
            div[style*="maxWidth: 1200"] {
              padding: 0 12px !important;
            }

            /* 用户基本信息卡片移动端优化 */
            div[style*="padding: 40"] {
              padding: 24px 16px !important;
              border-radius: 16px !important;
              margin-bottom: 20px !important;
            }

            /* 头像移动端优化 */
            img[alt="头像"] {
              width: 100px !important;
              height: 100px !important;
            }

            /* 用户名移动端优化 */
            h1[style*="fontSize: 32"] {
              font-size: 24px !important;
              margin-bottom: 12px !important;
            }

            /* 等级和评分标签移动端优化 */
            div[style*="display: flex"][style*="justifyContent: center"][style*="gap: 24"] {
              gap: 12px !important;
              flex-wrap: wrap !important;
            }

            div[style*="padding: '8px 20px'"] {
              padding: 6px 16px !important;
              font-size: 12px !important;
            }

            /* 任务达人信息移动端优化 */
            div[style*="padding: '16px 24px'"][style*="background: linear-gradient"] {
              padding: 12px 16px !important;
            }

            /* 服务菜单移动端优化 */
            h3[style*="fontSize: 18"] {
              font-size: 16px !important;
              margin-bottom: 12px !important;
            }

            div[style*="display: flex"][style*="flexDirection: column"][style*="gap: 12"] {
              gap: 8px !important;
            }

            div[style*="padding: '16px'"] {
              padding: 12px !important;
            }

            /* 详细统计信息卡片移动端优化 */
            div[style*="padding: 32"] {
              padding: 20px 16px !important;
              border-radius: 16px !important;
              margin-bottom: 20px !important;
            }

            h2[style*="fontSize: 24"] {
              font-size: 20px !important;
              margin-bottom: 16px !important;
            }

            /* 统计网格移动端优化 */
            div[style*="gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))'"] {
              grid-template-columns: repeat(2, 1fr) !important;
              gap: 12px !important;
            }

            div[style*="padding: 24"][style*="textAlign: center"] {
              padding: 16px 12px !important;
            }

            div[style*="fontSize: 32"][style*="fontWeight: 800"] {
              font-size: 24px !important;
            }

            div[style*="fontSize: 14"][style*="opacity: 0.9"] {
              font-size: 12px !important;
            }

            /* 最近任务卡片移动端优化 */
            div[style*="padding: 32"][style*="marginBottom: 32"] {
              padding: 20px 16px !important;
              margin-bottom: 20px !important;
              border-radius: 16px !important;
            }

            h2[style*="fontSize: 24"][style*="fontWeight: 700"] {
              font-size: 20px !important;
              margin-bottom: 16px !important;
            }

            /* 任务卡片移动端优化 */
            div[style*="padding: '20px'"] {
              padding: 16px 12px !important;
              border-radius: 12px !important;
            }

            div[style*="fontSize: 18"][style*="fontWeight: 600"] {
              font-size: 16px !important;
            }

            div[style*="fontSize: 14"][style*="color: '#666'"] {
              font-size: 12px !important;
            }

            /* 用户评价卡片移动端优化 */
            div[style*="padding: 32"][style*="marginBottom: 32"] {
              padding: 20px 16px !important;
              margin-bottom: 20px !important;
            }

            /* 评价项移动端优化 */
            div[style*="padding: '20px'"] {
              padding: 16px 12px !important;
            }

            div[style*="fontSize: 16"][style*="fontWeight: 600"] {
              font-size: 14px !important;
            }

            div[style*="fontSize: 14"][style*="color: '#666'"] {
              font-size: 12px !important;
              line-height: 1.5 !important;
            }
          }

          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            div[style*="maxWidth: 1200"] {
              padding: 0 8px !important;
            }

            div[style*="padding: 24px 16px"] {
              padding: 16px 12px !important;
            }

            img[alt="头像"] {
              width: 80px !important;
              height: 80px !important;
            }

            h1[style*="fontSize: 24"] {
              font-size: 20px !important;
            }

            div[style*="gridTemplateColumns: 'repeat(2, 1fr)'"] {
              grid-template-columns: 1fr !important;
              gap: 8px !important;
            }

            div[style*="padding: 16px 12px"] {
              padding: 12px 8px !important;
            }

            div[style*="fontSize: 24"] {
              font-size: 20px !important;
            }
          }

          /* 极小屏幕优化 */
          @media (max-width: 360px) {
            div[style*="maxWidth: 1200"] {
              padding: 0 6px !important;
            }

            div[style*="padding: 16px 12px"] {
              padding: 12px 8px !important;
            }

            h1[style*="fontSize: 20"] {
              font-size: 18px !important;
            }
          }
        `}
      </style>
    </div>
  );
};

export default UserProfile; 