import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import api, { fetchCurrentUser, logout, getPublicSystemSettings } from '../api';
import SEOHead from '../components/SEOHead';
import Footer from '../components/Footer';
import LanguageSwitcher from '../components/LanguageSwitcher';
import HamburgerMenu from '../components/HamburgerMenu';
import LoginModal from '../components/LoginModal';

const TaskExpertsIntro: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const location = useLocation();
  
  // 用户和系统设置状态
  const [user, setUser] = useState<any>(null);
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 登录弹窗状态
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
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
        console.error('Failed to load system settings:', error);
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
        ogImage="/static/logo.png"
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
                  console.error('Logout failed:', error);
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>

      {/* 主要内容 */}
      <main style={{ paddingTop: '80px' }}>
        <div style={{ maxWidth: 1000, margin: '0 auto', padding: '40px 24px' }}>
          {/* 标题部分 */}
          <div style={{ textAlign: 'center', marginBottom: '60px' }}>
            <h1 style={{
              fontSize: '48px',
              fontWeight: '700',
              color: '#1e293b',
              marginBottom: '20px',
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}>
              {t('taskExpertsIntro.title')}
            </h1>
            <p style={{
              fontSize: '20px',
              color: '#64748b',
              lineHeight: '1.6',
              maxWidth: '700px',
              margin: '0 auto'
            }}>
              {t('taskExpertsIntro.subtitle')}
            </p>
          </div>

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
              onClick={() => navigate('/publish')}
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

      <Footer />
    </div>
  );
};

export default TaskExpertsIntro;

