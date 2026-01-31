import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import LocalizedLink from '../components/LocalizedLink';
import { useLanguage } from '../contexts/LanguageContext';
import { fetchCurrentUser, logout } from '../api';

const Support: React.FC = () => {
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
              {t('supportPage.title')}
            </h1>
            <h2 style={{
              fontSize: '2rem',
              fontWeight: 700,
              color: '#1e293b',
              margin: '0 0 12px 0'
            }}>
              {t('supportPage.title')}
            </h2>
            <p style={{
              fontSize: '1rem',
              color: '#64748b',
              margin: 0,
              lineHeight: '1.6'
            }}>
              {t('supportPage.subtitle')}
            </p>
          </div>

          <div style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '40px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.05)',
            lineHeight: '1.8'
          }}>
            {/* 联系我们 */}
            <div style={{
              marginBottom: '32px',
              padding: '24px',
              backgroundColor: '#f8f9fa',
              borderRadius: '12px',
              border: '1px solid #e9ecef'
            }}>
              <h3 style={{ color: '#1e293b', fontSize: '1.3rem', marginBottom: '12px' }}>
                {t('supportPage.contactTitle')}
              </h3>
              <p style={{ color: '#475569', marginBottom: '16px' }}>
                {t('supportPage.contactIntro')}
              </p>
              <p style={{ margin: 0 }}>
                <strong>{t('supportPage.emailLabel')}: </strong>
                <a href="mailto:support@link2ur.com" style={{ color: '#3b82f6', textDecoration: 'none' }}>
                  support@link2ur.com
                </a>
              </p>
            </div>

            {/* FAQ 链接 */}
            <div style={{
              marginBottom: '32px',
              padding: '24px',
              backgroundColor: '#f8f9fa',
              borderRadius: '12px',
              border: '1px solid #e9ecef'
            }}>
              <h3 style={{ color: '#1e293b', fontSize: '1.3rem', marginBottom: '12px' }}>
                {t('supportPage.faqTitle')}
              </h3>
              <p style={{ color: '#475569', marginBottom: '16px' }}>
                {t('supportPage.faqIntro')}
              </p>
              <LocalizedLink
                to="/faq"
                style={{
                  display: 'inline-block',
                  padding: '10px 20px',
                  backgroundColor: '#3b82f6',
                  color: '#fff',
                  borderRadius: '8px',
                  textDecoration: 'none',
                  fontWeight: 600,
                  fontSize: '0.95rem'
                }}
              >
                {t('supportPage.faqLink')}
              </LocalizedLink>
            </div>

            {/* 法律文档 */}
            <p style={{ color: '#64748b', fontSize: '0.95rem', margin: 0 }}>
              {t('supportPage.termsAndPrivacy')}{' '}
              <LocalizedLink to="/terms" style={{ color: '#3b82f6', textDecoration: 'none' }}>
                {t('footer.termsOfService')}
              </LocalizedLink>
              {' · '}
              <LocalizedLink to="/privacy" style={{ color: '#3b82f6', textDecoration: 'none' }}>
                {t('footer.privacyPolicy')}
              </LocalizedLink>
            </p>
          </div>
        </div>
      </div>

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

export default Support;
