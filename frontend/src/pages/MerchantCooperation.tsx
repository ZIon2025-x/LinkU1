import React, { useState } from 'react';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';

const MerchantCooperation: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const [user] = useState<any>(null);
  const [unreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [systemSettings] = useState({});

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          <div 
            style={{
              fontWeight: 'bold', 
              fontSize: 24, 
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
              WebkitBackgroundClip: 'text', 
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              padding: '4px 8px',
              borderRadius: '8px',
              flexShrink: 0
            }}
            onClick={() => navigate('/')}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'scale(1.05)';
              e.currentTarget.style.background = 'linear-gradient(135deg, #2563eb, #7c3aed)';
              (e.currentTarget.style as any).webkitBackgroundClip = 'text';
              (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'scale(1)';
              e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #8b5cf6)';
              (e.currentTarget.style as any).webkitBackgroundClip = 'text';
              (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
            }}
          >
            Link²Ur
          </div>
          <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
            <LanguageSwitcher />
            <NotificationButton
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => setShowNotifications(prev => !prev)}
            />
            <HamburgerMenu
              user={user}
              onLogout={async () => { window.location.reload(); }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>

      <div style={{height: 60}} />

      <div style={{ flex: 1 }}>
        <section style={{ background: 'linear-gradient(135deg, #052e22 0%, #059669 60%, #047857 100%)', color: '#fff', padding: '72px 16px 56px' }}>
          <div style={{ maxWidth: 900, margin: '0 auto' }}>
            <div style={{ opacity: 0.9, fontSize: 12, letterSpacing: 1 }}>{t('merchant.betaNotice')}</div>
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
            }}>{t('merchant.title')}</h1>
            <p style={{ marginTop: 14, fontSize: 18, opacity: 0.95 }}>{t('merchant.subtitle')}</p>
          </div>
        </section>

        <section style={{ maxWidth: 900, margin: '32px auto', padding: '0 16px' }}>
          <div style={{ background: '#fff', borderRadius: 16, boxShadow: '0 12px 32px rgba(0,0,0,0.08)', padding: 28 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
              <div>
                <h2 style={{ fontSize: 22, marginTop: 0 }}>{t('merchant.platform.introTitle')}</h2>
                <p style={{ marginTop: 8, color: '#374151' }}>{t('merchant.platform.intro')}</p>
              </div>
              <div>
                <h2 style={{ fontSize: 22, marginTop: 0 }}>{t('merchant.platform.missionTitle')}</h2>
                <p style={{ marginTop: 8, color: '#374151' }}>{t('merchant.platform.mission')}</p>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16, marginTop: 16 }}>
              <div style={{ background: '#f0fdf4', border: '1px solid #dcfce7', borderRadius: 12, padding: 16 }}>
                <div style={{ fontSize: 12, color: '#166534' }}>{t('merchant.platform.goalsTitle')}</div>
                <div style={{ fontWeight: 700, marginTop: 6 }}>1. {t('merchant.platform.goals.digitization')}</div>
              </div>
              <div style={{ background: '#f0fdf4', border: '1px solid #dcfce7', borderRadius: 12, padding: 16 }}>
                <div style={{ fontSize: 12, color: '#166534' }}>{t('merchant.platform.goalsTitle')}</div>
                <div style={{ fontWeight: 700, marginTop: 6 }}>2. {t('merchant.platform.goals.acquisition')}</div>
              </div>
              <div style={{ background: '#f0fdf4', border: '1px solid #dcfce7', borderRadius: 12, padding: 16 }}>
                <div style={{ fontSize: 12, color: '#166534' }}>{t('merchant.platform.goalsTitle')}</div>
                <div style={{ fontWeight: 700, marginTop: 6 }}>3. {t('merchant.platform.goals.retention')}</div>
              </div>
            </div>

            <h2 style={{ fontSize: 20, marginTop: 24 }}>{t('merchant.sections.coopModels')}</h2>
            <p style={{ marginTop: 8, color: '#374151' }}>{t('merchant.sections.coopModelsDesc')}</p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginTop: 16 }}>
              <div style={{ background: '#f9fafb', borderRadius: 10, padding: 16 }}>
                <div style={{ fontWeight: 600 }}>{t('merchant.models.marketing')}</div>
                <div style={{ marginTop: 6, color: '#4b5563' }}>{t('merchant.models.marketingDesc')}</div>
              </div>
              <div style={{ background: '#f9fafb', borderRadius: 10, padding: 16 }}>
                <div style={{ fontWeight: 600 }}>{t('merchant.models.integration')}</div>
                <div style={{ marginTop: 6, color: '#4b5563' }}>{t('merchant.models.integrationDesc')}</div>
              </div>
            </div>

            <h3 style={{ fontSize: 18, marginTop: 24 }}>{t('merchant.sections.contact')}</h3>
            <p style={{ marginTop: 8 }}>
              {t('merchant.contactLine')}
              <a href="mailto:info@link2ur.com" style={{ color: '#047857', marginLeft: 6 }}>info@link2ur.com</a>
            </p>
            <p style={{ marginTop: 6, color: '#374151' }}>
              {t('merchant.betaContact')} <a href="mailto:info@link2ur.com" style={{ color: '#047857' }}>info@link2ur.com</a>
            </p>
          </div>
        </section>
      </div>

      <NotificationPanel isOpen={showNotifications && !!user} onClose={() => setShowNotifications(false)} notifications={[]} unreadCount={unreadCount} onMarkAllRead={() => {}} onMarkAsRead={() => {}} />
      <Footer />
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
      />
    </div>
  );
};

export default MerchantCooperation;


