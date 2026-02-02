import React, { useEffect, useState } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { getFaq, type FaqSectionOut } from '../api';

const sectionStyle: React.CSSProperties = {
  background: '#fff',
  borderRadius: 12,
  boxShadow: '0 6px 20px rgba(43,108,176,0.12)',
  padding: 20,
  border: '1px solid #e6f7ff',
};

const FAQ: React.FC = () => {
  const { language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const L = (zh: string, en: string) => (language === 'zh' ? zh : en);

  const [user] = React.useState<any>(null);
  const [unreadCount] = React.useState<number>(0);
  const [showNotifications, setShowNotifications] = React.useState(false);
  const [, setShowLoginModal] = React.useState(false);
  const [systemSettings] = React.useState<any>({ vip_button_visible: false });

  const [sections, setSections] = useState<FaqSectionOut[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const lang = language === 'zh' ? 'zh' : 'en';

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    getFaq(lang)
      .then((res) => {
        if (!cancelled) {
          setSections(res.sections || []);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setError(L('加载常见问题失败，请稍后重试。', 'Failed to load FAQ. Please try again later.'));
          setSections([]);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => { cancelled = true; };
  }, [lang, L]);

  return (
    <div>
      <header style={{ position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px' }}>
          <div
            style={{ fontWeight: 'bold', fontSize: 24, background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', cursor: 'pointer' }}
            onClick={() => navigate('/')}
          >
            Link²Ur
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <LanguageSwitcher />
            <NotificationButton
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => setShowNotifications((prev) => !prev)}
            />
            <HamburgerMenu
              user={user}
              onLogout={async () => { try { /* await logout(); */ } catch (e) {} window.location.reload(); }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>
      <div style={{ height: 60 }} />

      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={[]}
        unreadCount={unreadCount}
        onMarkAsRead={() => {}}
        onMarkAllRead={() => {}}
      />

      <main style={{ maxWidth: 900, margin: '0 auto', padding: '24px' }}>
        <h1
          style={{
            position: 'absolute',
            top: '-100px',
            left: '-100px',
            width: '1px',
            height: '1px',
            padding: 0,
            margin: 0,
            overflow: 'hidden',
            clip: 'rect(0, 0, 0, 0)',
            whiteSpace: 'nowrap',
            border: 0,
            fontSize: '1px',
            color: 'transparent',
            background: 'transparent',
          }}
        >
          {L('常见问题（FAQ）', 'Frequently Asked Questions (FAQ)')}
        </h1>
        <p style={{ color: '#64748b', marginBottom: 24 }}>
          {L('我们整理了常见问题与答案，帮助你更快上手 Link²Ur（任务、跳蚤市场、论坛与支付等）。', 'We compiled common questions and answers to help you get started with Link²Ur — tasks, flea market, forum, and payments.')}
        </p>

        {loading && (
          <p style={{ color: '#64748b', textAlign: 'center', padding: 24 }}>{L('加载中…', 'Loading…')}</p>
        )}
        {error && (
          <p style={{ color: '#dc2626', marginBottom: 16 }}>{error}</p>
        )}
        {!loading && sections && sections.length > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {sections.map((sec) => (
              <section key={sec.id} style={sectionStyle}>
                <h2 style={{ fontSize: 20, fontWeight: 700, marginBottom: 12 }}>{sec.title}</h2>
                {sec.items.map((item, idx) => (
                  <details key={item.id} open={idx === 0}>
                    <summary style={{ cursor: 'pointer', fontWeight: 600 }}>{item.question}</summary>
                    <div style={{ marginTop: 8, color: '#334155', whiteSpace: 'pre-wrap' }}>{item.answer}</div>
                  </details>
                ))}
              </section>
            ))}
          </div>
        )}
        {!loading && sections && sections.length === 0 && !error && (
          <p style={{ color: '#64748b' }}>{L('暂无常见问题内容。', 'No FAQ content available.')}</p>
        )}
      </main>

      <Footer />
    </div>
  );
};

export default FAQ;
