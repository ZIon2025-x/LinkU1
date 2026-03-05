import React, { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { detectBrowserLanguage } from '../utils/i18n';

const NotFoundPage: React.FC = () => {
  const lang = detectBrowserLanguage();
  const homePath = `/${lang}`;

  useEffect(() => {
    // Set noindex to prevent search engines from indexing 404 pages
    let robotsTag = document.querySelector('meta[name="robots"]') as HTMLMetaElement;
    if (!robotsTag) {
      robotsTag = document.createElement('meta');
      robotsTag.name = 'robots';
      document.head.appendChild(robotsTag);
    }
    robotsTag.content = 'noindex, nofollow';

    document.title = '404 - Page Not Found | Link²Ur';

    return () => {
      // Restore default robots on unmount
      if (robotsTag) {
        robotsTag.content = 'index, follow';
      }
    };
  }, []);

  return (
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      background: '#f5f5f5',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    }}>
      <div style={{
        textAlign: 'center',
        padding: '60px 40px',
        background: '#fff',
        borderRadius: '16px',
        boxShadow: '0 4px 20px rgba(0,0,0,0.08)',
        maxWidth: '480px',
      }}>
        <h1 style={{ fontSize: '72px', color: '#007AFF', margin: '0 0 16px' }}>404</h1>
        <p style={{ fontSize: '18px', color: '#333', margin: '0 0 8px' }}>
          Page Not Found
        </p>
        <p style={{ fontSize: '14px', color: '#999', margin: '0 0 32px' }}>
          {lang === 'zh' ? '抱歉，您访问的页面不存在。' : 'Sorry, the page you are looking for does not exist.'}
        </p>
        <Link
          to={homePath}
          style={{
            display: 'inline-block',
            padding: '12px 32px',
            background: '#007AFF',
            color: '#fff',
            borderRadius: '8px',
            textDecoration: 'none',
            fontSize: '16px',
            fontWeight: '600',
          }}
        >
          {lang === 'zh' ? '返回首页' : 'Back to Home'}
        </Link>
      </div>
    </div>
  );
};

export default NotFoundPage;
