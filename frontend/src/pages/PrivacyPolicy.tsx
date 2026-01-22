import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { fetchCurrentUser, logout } from '../api';

const PrivacyPolicy: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error) {
        setUser(null);
      }
    };
    loadUser();
  }, []);

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      {/* 顶部导航栏 */}
      <header style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        background: '#fff',
        zIndex: 100,
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        borderBottom: '1px solid #e9ecef'
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
            style={{
              fontWeight: 'bold',
              fontSize: 24,
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer'
            }}
            onClick={() => navigate('/')}
          >
            Link²Ur
          </div>
          
          {/* 语言切换器和汉堡菜单 */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
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
              systemSettings={{}}
            />
          </div>
        </div>
      </header>

      {/* 主要内容 */}
      <div style={{ paddingTop: '80px', paddingBottom: '40px' }}>
        <div style={{
          maxWidth: 800,
          margin: '0 auto',
          padding: '0 24px'
        }}>
          {/* 页面标题 */}
          <div style={{
            textAlign: 'center',
            marginBottom: '40px',
            padding: '40px 0'
          }}>
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
              {t('privacyPolicy.title')}
            </h1>
            <div style={{
              fontSize: '1rem',
              color: '#64748b',
              margin: 0,
              lineHeight: '1.6'
            }}>
              <p style={{ margin: '4px 0' }}>{t('privacyPolicy.version')}</p>
              <p style={{ margin: '4px 0' }}>{t('privacyPolicy.effectiveDate')}</p>
            </div>
          </div>

          {/* 政策内容 */}
          <div style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '40px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.05)',
            lineHeight: '1.8'
          }}>
            <div style={{ color: '#374151', fontSize: '1rem' }}>
              {/* 控制者信息 */}
              <div style={{
                marginBottom: '32px',
                padding: '20px',
                backgroundColor: '#f8f9fa',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                <h3 style={{ color: '#1e293b', fontSize: '1.3rem', marginBottom: '16px' }}>
                  {t('privacyPolicy.controller')}
                </h3>
                <p style={{ marginBottom: '8px' }}>{t('privacyPolicy.operator')}</p>
                <p style={{ marginBottom: '8px' }}>{t('privacyPolicy.contactEmail')}</p>
                <p style={{ marginBottom: '8px' }}>{t('privacyPolicy.address')}</p>
                <p style={{ margin: 0 }}>{t('privacyPolicy.dpoNote')}</p>
              </div>

              {/* 数据收集 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('privacyPolicy.dataCollection.title')}
              </h2>
              <p>{t('privacyPolicy.dataCollection.accountData')}</p>
              <p>{t('privacyPolicy.dataCollection.taskData')}</p>
              <p>{t('privacyPolicy.dataCollection.locationData')}</p>
              <p>{t('privacyPolicy.dataCollection.recommendationData')}</p>
              <p>{t('privacyPolicy.dataCollection.technicalData')}</p>
              <p>{t('privacyPolicy.dataCollection.analyticsData')}</p>
              <p>{t('privacyPolicy.dataCollection.paymentData')}</p>

              {/* 数据共享 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('privacyPolicy.dataSharing.title')}
              </h2>
              <p>{t('privacyPolicy.dataSharing.cloudServices')}</p>
              <p>{t('privacyPolicy.dataSharing.legalDisclosure')}</p>

              {/* 国际传输 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('privacyPolicy.internationalTransfer.title')}
              </h2>
              <p>{t('privacyPolicy.internationalTransfer.content')}</p>

              {/* 保留期限 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('privacyPolicy.retentionPeriod.title')}
              </h2>
              <p>{t('privacyPolicy.retentionPeriod.accountData')}</p>
              <p>{t('privacyPolicy.retentionPeriod.transactionData')}</p>
              <p>{t('privacyPolicy.retentionPeriod.recommendationData')}</p>
              <p>{t('privacyPolicy.retentionPeriod.securityLogs')}</p>

              {/* 您的权利 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('privacyPolicy.yourRights.title')}
              </h2>
              <p>{t('privacyPolicy.yourRights.content')}</p>
              <p>{t('privacyPolicy.yourRights.complaintProcess')}</p>

              {/* Cookies */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('privacyPolicy.cookies.title')}
              </h2>
              <p>{t('privacyPolicy.cookies.necessary')}</p>
              <p>{t('privacyPolicy.cookies.optional')}</p>

              {/* 联系我们 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('privacyPolicy.contactUs.title')}
              </h2>
              <p>{t('privacyPolicy.contactUs.content')}</p>

              <div style={{
                marginTop: '40px',
                padding: '20px',
                backgroundColor: '#f8f9fa',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                <p style={{ margin: 0, fontSize: '0.9rem', color: '#6c757d' }}>
                  <strong>{t('privacyPolicy.importantNotice')}</strong>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => setShowForgotPasswordModal(true)}
        onHideForgotPassword={() => setShowForgotPasswordModal(false)}
      />
    </div>
  );
};

export default PrivacyPolicy;
