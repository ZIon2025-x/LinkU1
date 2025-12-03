import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import api, { fetchCurrentUser, logout, getPublicSystemSettings } from '../api';
import SEOHead from '../components/SEOHead';
import Footer from '../components/Footer';
import LanguageSwitcher from '../components/LanguageSwitcher';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';
import TaskExpertApplicationModal from '../components/TaskExpertApplicationModal';
import VideoCarousel from '../components/VideoCarousel';

const TaskExpertsIntro: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  const location = useLocation();
  
  // 用户和系统设置状态
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 登录弹窗状态
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
  // 任务达人申请弹窗状态
  const [showExpertApplicationModal, setShowExpertApplicationModal] = useState(false);
  
  // 移动端检测
  const [isMobile, setIsMobile] = useState(false);
  
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth <= 768);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);
  
  // 加载用户信息和系统设置
  useEffect(() => {
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error) {
        setUser(null);
      }
    };
    
    const loadSystemSettings = async () => {
      try {
        const settings = await getPublicSystemSettings();
        setSystemSettings(settings);
      } catch (error) {
              }
    };
    
    loadUserData();
    loadSystemSettings();
  }, []);
  
  // 生成canonical URL
  const canonicalUrl = location.pathname.startsWith('/en') || location.pathname.startsWith('/zh')
    ? `https://www.link2ur.com${location.pathname}`
    : 'https://www.link2ur.com/en/task-experts/intro';

  return (
    <div style={{ minHeight: '100vh', background: '#fff' }}>
      <SEOHead 
        title={t('taskExpertsIntro.title')}
        description={t('taskExpertsIntro.description')}
        canonicalUrl={canonicalUrl}
        ogTitle={t('taskExpertsIntro.title')}
        ogDescription={t('taskExpertsIntro.description')}
        ogImage="/static/favicon.png"
        ogUrl={canonicalUrl}
      />
      
      {/* 顶部导航栏 */}
      <header style={{
        position: 'fixed', 
        top: 0, 
        left: 0, 
        width: '100%', 
        background: '#fff', 
        zIndex: 100, 
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
      }}>
        <div style={{
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'space-between', 
          height: 60, 
          maxWidth: 1200, 
          margin: '0 auto', 
          padding: '0 24px'
        }}>
          {/* Logo */}
          <div 
            onClick={() => navigate('/')}
            style={{
              fontWeight: 'bold', 
              fontSize: 24, 
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
              WebkitBackgroundClip: 'text', 
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer'
            }}
          >
            Link²Ur
          </div>
          
          {/* 语言切换器和汉堡菜单 */}
          <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
            <LanguageSwitcher />
            <HamburgerMenu
              user={user}
              onLogout={async () => {
                try {
                  await logout();
                } catch (error) {
                                  }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
              unreadCount={messageUnreadCount}
            />
          </div>
        </div>
      </header>

      {/* 主要内容 */}
      <main style={{ paddingTop: '80px' }}>
        <div style={{ 
          maxWidth: 1000, 
          margin: '0 auto', 
          padding: isMobile ? '20px 16px' : '40px 24px' 
        }}>
          {/* 标题部分 */}
          <div style={{ textAlign: 'center', marginBottom: isMobile ? '40px' : '60px' }}>
            <h1 style={{
              fontSize: isMobile ? '32px' : '48px',
              fontWeight: '700',
              color: '#1e293b',
              marginBottom: isMobile ? '16px' : '20px',
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}>
              {t('taskExpertsIntro.title')}
            </h1>
            <p style={{
              fontSize: isMobile ? '16px' : '20px',
              color: '#64748b',
              lineHeight: '1.6',
              maxWidth: '700px',
              margin: '0 auto'
            }}>
              {t('taskExpertsIntro.subtitle')}
            </p>
          </div>

          {/* 任务达人视频轮播 */}
          <section style={{ marginBottom: '60px' }}>
            <VideoCarousel
              videos={[
                {
                  src: '/static/about1.mp4',
                  title: '开发任务达人',
                  description: '专业的软件开发任务达人，拥有丰富的编程经验和项目实战能力，能够高效完成各类技术开发任务。',
                  specialties: [
                    'Web前端开发',
                    '后端API开发',
                    '移动应用开发',
                    '数据库设计',
                    '系统架构设计'
                  ],
                  achievements: [
                    '完成50+开发任务',
                    '平均评分4.5/5.0以上',
                    '通过平台严格审核',
                    '提供专业证明材料',
                    '获得用户一致好评'
                  ]
                },
                {
                  src: '/static/about2.mp4',
                  title: '设计任务达人',
                  description: '创意设计任务达人，擅长UI/UX设计、平面设计和品牌视觉设计，能够为客户提供专业的设计解决方案。',
                  specialties: [
                    'UI/UX界面设计',
                    '品牌视觉设计',
                    '平面设计',
                    '图标设计',
                    '设计规范制定'
                  ],
                  achievements: [
                    '完成50+设计任务',
                    '平均评分4.5/5.0以上',
                    '通过平台严格审核',
                    '提供专业证明材料',
                    '获得用户一致好评'
                  ]
                },
                {
                  src: '/static/about3.mp4',
                  title: '美食任务达人',
                  description: '美食制作任务达人，精通各类菜系和烘焙技巧，能够提供专业的美食制作服务和烹饪指导。',
                  specialties: [
                    '中餐制作',
                    '西餐料理',
                    '烘焙甜点',
                    '营养搭配',
                    '私厨服务'
                  ],
                  achievements: [
                    '完成50+美食任务',
                    '平均评分4.5/5.0以上',
                    '通过平台严格审核',
                    '提供专业证明材料',
                    '获得用户一致好评'
                  ]
                },
                {
                  src: '/static/about4.mp4',
                  title: '宠物任务达人',
                  description: '宠物护理任务达人，拥有丰富的宠物照护经验，能够提供专业的宠物护理、训练和陪伴服务。',
                  specialties: [
                    '宠物日常护理',
                    '宠物训练',
                    '宠物美容',
                    '宠物寄养',
                    '宠物行为咨询'
                  ],
                  achievements: [
                    '完成50+宠物任务',
                    '平均评分4.5/5.0以上',
                    '通过平台严格审核',
                    '提供专业证明材料',
                    '获得用户一致好评'
                  ]
                }
              ]}
              loop={true}
              autoplay={true}
            />
          </section>

          {/* 什么是任务达人 */}
          <section style={{ marginBottom: '60px' }}>
            <div style={{
              background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)',
              padding: '40px',
              borderRadius: '20px',
              boxShadow: '0 4px 20px rgba(0,0,0,0.05)'
            }}>
              <h2 style={{
                fontSize: '32px',
                fontWeight: '700',
                color: '#1e293b',
                marginBottom: '20px',
                display: 'flex',
                alignItems: 'center',
                gap: '12px'
              }}>
                <span style={{ fontSize: '40px' }}>👑</span>
                {t('taskExpertsIntro.whatIs.title')}
              </h2>
              <p style={{
                fontSize: '18px',
                color: '#475569',
                lineHeight: '1.8',
                marginBottom: '20px'
              }}>
                {t('taskExpertsIntro.whatIs.description')}
              </p>
              
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
                gap: '20px',
                marginTop: '30px'
              }}>
                <div style={{
                  background: '#fff',
                  padding: '24px',
                  borderRadius: '12px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}>
                  <div style={{ fontSize: '32px', marginBottom: '12px' }}>⭐</div>
                  <h3 style={{ fontSize: '18px', fontWeight: '600', marginBottom: '8px', color: '#1e293b' }}>
                    {t('taskExpertsIntro.whatIs.feature1.title')}
                  </h3>
                  <p style={{ fontSize: '14px', color: '#64748b', lineHeight: '1.6' }}>
                    {t('taskExpertsIntro.whatIs.feature1.description')}
                  </p>
                </div>
                <div style={{
                  background: '#fff',
                  padding: '24px',
                  borderRadius: '12px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}>
                  <div style={{ fontSize: '32px', marginBottom: '12px' }}>🎯</div>
                  <h3 style={{ fontSize: '18px', fontWeight: '600', marginBottom: '8px', color: '#1e293b' }}>
                    {t('taskExpertsIntro.whatIs.feature2.title')}
                  </h3>
                  <p style={{ fontSize: '14px', color: '#64748b', lineHeight: '1.6' }}>
                    {t('taskExpertsIntro.whatIs.feature2.description')}
                  </p>
                </div>
                <div style={{
                  background: '#fff',
                  padding: '24px',
                  borderRadius: '12px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}>
                  <div style={{ fontSize: '32px', marginBottom: '12px' }}>💼</div>
                  <h3 style={{ fontSize: '18px', fontWeight: '600', marginBottom: '8px', color: '#1e293b' }}>
                    {t('taskExpertsIntro.whatIs.feature3.title')}
                  </h3>
                  <p style={{ fontSize: '14px', color: '#64748b', lineHeight: '1.6' }}>
                    {t('taskExpertsIntro.whatIs.feature3.description')}
                  </p>
                </div>
              </div>
            </div>
          </section>

          {/* 如何成为任务达人 */}
          <section style={{ marginBottom: '60px' }}>
            <div style={{
              background: 'linear-gradient(135deg, #fef3c7 0%, #fde68a 100%)',
              padding: '40px',
              borderRadius: '20px',
              boxShadow: '0 4px 20px rgba(0,0,0,0.05)'
            }}>
              <h2 style={{
                fontSize: '32px',
                fontWeight: '700',
                color: '#1e293b',
                marginBottom: '30px',
                display: 'flex',
                alignItems: 'center',
                gap: '12px'
              }}>
                <span style={{ fontSize: '40px' }}>🚀</span>
                {t('taskExpertsIntro.howToBecome.title')}
              </h2>
              
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
                gap: '24px'
              }}>
                {[1, 2, 3, 4].map((step) => (
                  <div key={step} style={{
                    background: '#fff',
                    padding: '24px',
                    borderRadius: '12px',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
                    position: 'relative'
                  }}>
                    <div style={{
                      position: 'absolute',
                      top: '-12px',
                      left: '24px',
                      background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                      color: '#fff',
                      width: '36px',
                      height: '36px',
                      borderRadius: '50%',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontWeight: '700',
                      fontSize: '18px',
                      boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
                    }}>
                      {step}
                    </div>
                    <h3 style={{
                      fontSize: '20px',
                      fontWeight: '600',
                      marginTop: '12px',
                      marginBottom: '12px',
                      color: '#1e293b'
                    }}>
                      {t(`taskExpertsIntro.howToBecome.step${step}.title`)}
                    </h3>
                    <p style={{
                      fontSize: '15px',
                      color: '#64748b',
                      lineHeight: '1.7'
                    }}>
                      {t(`taskExpertsIntro.howToBecome.step${step}.description`)}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* 任务达人的优势 */}
          <section style={{ marginBottom: '60px' }}>
            <div style={{
              background: 'linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%)',
              padding: '40px',
              borderRadius: '20px',
              boxShadow: '0 4px 20px rgba(0,0,0,0.05)'
            }}>
              <h2 style={{
                fontSize: '32px',
                fontWeight: '700',
                color: '#1e293b',
                marginBottom: '30px',
                display: 'flex',
                alignItems: 'center',
                gap: '12px',
                textAlign: 'center'
              }}>
                <span style={{ fontSize: '40px' }}>✨</span>
                {t('taskExpertsIntro.advantages.title')}
              </h2>
              
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
                gap: '24px'
              }}>
                {[
                  { icon: '🎁', key: 'advantage1' },
                  { icon: '🏆', key: 'advantage2' },
                  { icon: '💰', key: 'advantage3' },
                  { icon: '📈', key: 'advantage4' },
                  { icon: '🔒', key: 'advantage5' },
                  { icon: '🌟', key: 'advantage6' }
                ].map((item, index) => (
                  <div key={item.key} style={{
                    background: '#fff',
                    padding: '28px',
                    borderRadius: '12px',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
                    transition: 'transform 0.2s ease',
                    borderLeft: '4px solid #10b981'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateY(-4px)';
                    e.currentTarget.style.boxShadow = '0 8px 20px rgba(0,0,0,0.1)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
                  }}
                  >
                    <div style={{ fontSize: '36px', marginBottom: '12px' }}>{item.icon}</div>
                    <h3 style={{
                      fontSize: '20px',
                      fontWeight: '600',
                      marginBottom: '10px',
                      color: '#1e293b'
                    }}>
                      {t(`taskExpertsIntro.advantages.${item.key}.title`)}
                    </h3>
                    <p style={{
                      fontSize: '15px',
                      color: '#64748b',
                      lineHeight: '1.7'
                    }}>
                      {t(`taskExpertsIntro.advantages.${item.key}.description`)}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* 行动按钮 */}
          <div style={{
            textAlign: 'center',
            marginTop: '60px',
            marginBottom: '40px'
          }}>
            <button
              onClick={() => navigate('/task-experts')}
              style={{
                background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                color: '#fff',
                padding: '16px 48px',
                borderRadius: '50px',
                fontSize: '18px',
                fontWeight: '700',
                border: 'none',
                cursor: 'pointer',
                boxShadow: '0 4px 20px rgba(59, 130, 246, 0.4)',
                transition: 'all 0.3s ease',
                marginRight: '16px'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 6px 25px rgba(59, 130, 246, 0.5)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 4px 20px rgba(59, 130, 246, 0.4)';
              }}
            >
              {t('taskExpertsIntro.viewExperts')}
            </button>
            <button
              onClick={() => {
                if (!user) {
                  setShowLoginModal(true);
                  return;
                }
                setShowExpertApplicationModal(true);
              }}
              style={{
                background: '#fff',
                color: '#3b82f6',
                padding: '16px 48px',
                borderRadius: '50px',
                fontSize: '18px',
                fontWeight: '700',
                border: '2px solid #3b82f6',
                cursor: 'pointer',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = '#3b82f6';
                e.currentTarget.style.color = '#fff';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = '#fff';
                e.currentTarget.style.color = '#3b82f6';
              }}
            >
              {t('taskExpertsIntro.becomeExpert')}
            </button>
          </div>
        </div>
      </main>

      {/* 登录弹窗 */}
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          // 登录成功后刷新用户状态
          window.location.reload();
        }}
        onReopen={() => {
          // 重新打开登录弹窗
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
      
      {/* 任务达人申请弹窗 */}
      <TaskExpertApplicationModal
        isOpen={showExpertApplicationModal}
        onClose={() => setShowExpertApplicationModal(false)}
        onSuccess={() => {
          setShowExpertApplicationModal(false);
          // 成功消息已在组件内部显示，这里不需要重复显示
        }}
      />

      <Footer />
    </div>
  );
};

export default TaskExpertsIntro;

