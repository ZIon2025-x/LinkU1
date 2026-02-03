import React, { useState, useEffect } from 'react';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import LocalizedLink from '../components/LocalizedLink';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';
import { API_BASE_URL } from '../config';

const LoginWithLink2ur: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const [user, setUser] = useState<unknown>(null);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [systemSettings, setSystemSettings] = useState<Record<string, unknown>>({});

  const discoveryUrl = `${API_BASE_URL.replace(/\/$/, '')}/.well-known/openid-configuration`;

  useEffect(() => {
    document.title = t('loginWithLink2ur.pageTitle');
    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) metaDesc.setAttribute('content', t('loginWithLink2ur.seoDescription'));
  }, [t]);

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <header style={{ position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px' }}>
          <div
            style={{
              fontWeight: 'bold',
              fontSize: 24,
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer',
              padding: '4px 8px',
            }}
            onClick={() => navigate('/')}
          >
            Link²Ur
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <LanguageSwitcher />
            <NotificationButton user={user} unreadCount={unreadCount} onNotificationClick={() => setShowNotifications((p) => !p)} />
            <HamburgerMenu
              user={user}
              onLogout={async () => { window.location.reload(); }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>

      <div style={{ height: 60 }} />

      <main style={{ flex: 1 }}>
        <section style={{ background: 'linear-gradient(135deg, #0f172a 0%, #1e3a8a 60%, #1e40af 100%)', color: '#fff', padding: '56px 16px 48px' }}>
          <div style={{ maxWidth: 800, margin: '0 auto' }}>
            <h1 style={{ fontSize: 28, margin: 0 }}>{t('loginWithLink2ur.title')}</h1>
            <p style={{ marginTop: 12, fontSize: 16, opacity: 0.95 }}>{t('loginWithLink2ur.subtitle')}</p>
          </div>
        </section>

        <section style={{ maxWidth: 800, margin: '32px auto', padding: '0 16px' }}>
          <div style={{ background: '#fff', borderRadius: 16, boxShadow: '0 12px 32px rgba(0,0,0,0.08)', padding: 28 }}>
            <h2 style={{ fontSize: 20, marginTop: 0 }}>{t('loginWithLink2ur.whatTitle')}</h2>
            <p style={{ color: '#374151', lineHeight: 1.7 }}>{t('loginWithLink2ur.whatDesc')}</p>

            <h2 style={{ fontSize: 20, marginTop: 24 }}>{t('loginWithLink2ur.whoTitle')}</h2>
            <p style={{ color: '#374151', lineHeight: 1.7 }}>{t('loginWithLink2ur.whoDesc')}</p>
            <ul style={{ color: '#374151', paddingLeft: 20, marginTop: 8 }}>
              <li>{t('loginWithLink2ur.whoWeb')}</li>
              <li>{t('loginWithLink2ur.whoApp')}</li>
              <li>{t('loginWithLink2ur.whoBackend')}</li>
            </ul>

            <h2 style={{ fontSize: 20, marginTop: 24 }}>{t('loginWithLink2ur.howTitle')}</h2>
            <p style={{ color: '#374151', lineHeight: 1.7 }}>{t('loginWithLink2ur.howDesc')}</p>
            <ol style={{ color: '#374151', paddingLeft: 20, marginTop: 8 }}>
              <li>{t('loginWithLink2ur.howStep1')}</li>
              <li>{t('loginWithLink2ur.howStep2')}</li>
              <li>{t('loginWithLink2ur.howStep3')}</li>
            </ol>

            <h2 style={{ fontSize: 20, marginTop: 24 }}>{t('loginWithLink2ur.techTitle')}</h2>
            <p style={{ color: '#374151', lineHeight: 1.7 }}>{t('loginWithLink2ur.techDesc')}</p>
            <p style={{ marginTop: 8 }}>
              <strong>{t('loginWithLink2ur.discoveryLabel')}</strong>
              <br />
              <a href={discoveryUrl} target="_blank" rel="noopener noreferrer" style={{ color: '#1d4ed8', wordBreak: 'break-all' }}>
                {discoveryUrl}
              </a>
            </p>

            <h2 style={{ fontSize: 20, marginTop: 24 }}>{t('loginWithLink2ur.contactTitle')}</h2>
            <p style={{ color: '#374151', lineHeight: 1.7 }}>
              {t('loginWithLink2ur.contactDesc')}{' '}
              <a href="mailto:info@link2ur.com" style={{ color: '#1d4ed8' }}>info@link2ur.com</a>
            </p>
            <p style={{ marginTop: 12 }}>
              <LocalizedLink to="/partners" style={{ color: '#1d4ed8' }}>{t('loginWithLink2ur.partnersLink')}</LocalizedLink>
            </p>
          </div>
        </section>
      </main>

      <NotificationPanel isOpen={!!showNotifications && !!user} onClose={() => setShowNotifications(false)} notifications={[]} unreadCount={unreadCount} onMarkAllRead={() => {}} onMarkAsRead={() => {}} />
      <Footer />
      <LoginModal isOpen={showLoginModal} onClose={() => setShowLoginModal(false)} onSuccess={() => { setShowLoginModal(false); window.location.reload(); }} />
    </div>
  );
};

export default LoginWithLink2ur;
