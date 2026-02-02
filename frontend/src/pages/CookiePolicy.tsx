import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { fetchCurrentUser, logout, getLegalDocument } from '../api';

const CookiePolicy: React.FC = () => {
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [content, setContent] = useState<Record<string, unknown> | null>(null);

  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch {
        setUser(null);
      }
    };
    loadUser();
  }, []);

  useEffect(() => {
    const load = async () => {
      const doc = await getLegalDocument('cookie', language);
      setContent(doc?.content_json && Object.keys(doc.content_json).length > 0 ? (doc.content_json as Record<string, unknown>) : null);
    };
    load();
  }, [language]);

  const getContent = (path: string) => {
    const v = path.split('.').reduce((o: unknown, k: string) => (o != null && typeof o === 'object' ? (o as Record<string, unknown>)[k] : undefined), content);
    return (typeof v === 'string' ? v : null) ?? t(`cookiePolicy.${path}`);
  };

  /** 从 API 返回的 content_json 解析为「标题 + 段落」列表，用于完整展示 */
  const getSectionsFromContent = (c: Record<string, unknown>): { title: string; paragraphs: string[] }[] => {
    const sections: { title: string; paragraphs: string[] }[] = [];
    const order = ['title', 'version', 'effectiveDate', 'jurisdiction', 'intro', 'whatAreCookies', 'typesWeUse', 'thirdParty', 'retention', 'howToManage', 'mobileTech', 'yourRights', 'contactUs', 'importantNotice', 'necessary', 'optional', 'contact'];
    for (const key of order) {
      if (!(key in c)) continue;
      const v = c[key];
      if (typeof v === 'string') {
        if (key === 'title') continue;
        sections.push({ title: key, paragraphs: [v] });
      } else if (v && typeof v === 'object' && !Array.isArray(v)) {
        const o = v as Record<string, unknown>;
        const title = (o.title as string) || '';
        const pKeys = Object.keys(o).filter(k => k !== 'title').sort((a, b) => (a.startsWith('p') && b.startsWith('p') ? (Number(a.slice(1)) - Number(b.slice(1))) : a.localeCompare(b)));
        const paras = pKeys.map(k => o[k]).filter((x): x is string => typeof x === 'string');
        if (title || paras.length) sections.push({ title, paragraphs: paras });
      }
    }
    return sections;
  };

  const sections = content ? getSectionsFromContent(content) : [];
  const hasFullContent = sections.length > 5;

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
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
                } catch {
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={{}}
            />
          </div>
        </div>
      </header>

      <div style={{ paddingTop: '80px', paddingBottom: '40px' }}>
        <div style={{ maxWidth: 800, margin: '0 auto', padding: '0 24px' }}>
          <div style={{ textAlign: 'center', marginBottom: '32px', padding: '32px 0' }}>
            <h1 style={{
              position: 'absolute',
              top: '-100px',
              left: '-100px',
              width: '1px',
              height: '1px',
              padding: 0,
              margin: 0,
              overflow: 'hidden',
              clip: 'rect(0,0,0,0)',
              whiteSpace: 'nowrap',
              border: 0,
              fontSize: '1px',
              color: 'transparent',
              background: 'transparent'
            }}>
              {getContent('title')}
            </h1>
            <h2 style={{ fontSize: '1.5rem', color: '#1e293b', margin: 0 }}>
              {getContent('title')}
            </h2>
          </div>

          <div style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '40px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.05)',
            lineHeight: '1.8'
          }}>
            <div style={{ color: '#374151', fontSize: '1rem' }}>
              {hasFullContent ? (
                sections.map((sec, i) => (
                  <div key={i} style={{ marginBottom: i < sections.length - 1 ? '28px' : 0 }}>
                    {sec.title && (
                      <h3 style={{ color: '#1e293b', fontSize: '1.2rem', marginBottom: '12px' }}>{sec.title}</h3>
                    )}
                    {sec.paragraphs.map((p, j) => (
                      <p key={j} style={{ marginBottom: '16px', whiteSpace: 'pre-line' }}>{p}</p>
                    ))}
                  </div>
                ))
              ) : (
                <>
                  <p style={{ marginBottom: '24px' }}>{getContent('intro')}</p>
                  <h3 style={{ color: '#1e293b', fontSize: '1.2rem', marginBottom: '12px' }}>
                    {t('privacyPolicy.cookies.title')}
                  </h3>
                  <p style={{ marginBottom: '16px' }}>{getContent('necessary')}</p>
                  <p style={{ marginBottom: '24px' }}>{getContent('optional')}</p>
                  <p style={{ margin: 0, fontSize: '0.95rem', color: '#64748b' }}>
                    {getContent('contact')}
                  </p>
                </>
              )}
            </div>
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
      />
    </div>
  );
};

export default CookiePolicy;
