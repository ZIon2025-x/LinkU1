/**
 * 「在 App 内打开」条（B 方案）
 * 仅对 iOS 用户显示（iPhone / iPad / iPod，Safari、Chrome 等均可），
 * 点击「在 App 内打开」使用当前页 URL 作为 Universal Link；另提供「下载 App」跳转 App Store。
 */
import React, { useState, useEffect } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { detectOS } from '../utils/deviceDetector';
import { APP_STORE_URL } from '../config';
import './OpenInAppBanner.css';

const STORAGE_KEY = 'open-in-app-banner-dismissed';

const OpenInAppBanner: React.FC = () => {
  const { t } = useLanguage();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const os = detectOS();
    if (os.name !== 'iOS') return;
    if (sessionStorage.getItem(STORAGE_KEY)) return;
    setVisible(true);
  }, []);

  const handleDismiss = () => {
    sessionStorage.setItem(STORAGE_KEY, '1');
    setVisible(false);
  };

  const currentUrl = typeof window !== 'undefined' ? window.location.href : '';

  if (!visible) return null;

  return (
    <div className="open-in-app-banner" role="banner">
      <button
        type="button"
        className="open-in-app-banner-close"
        onClick={handleDismiss}
        aria-label={t('common.close')}
      >
        ×
      </button>
      <div className="open-in-app-banner-content">
        <a
          href={currentUrl}
          className="open-in-app-banner-btn open-in-app-banner-btn-primary"
          rel="noopener noreferrer"
        >
          <span className="open-in-app-banner-btn-icon-wrap">
            <img src="/static/pwa.png" alt="" className="open-in-app-banner-btn-icon" aria-hidden />
          </span>
          <span className="open-in-app-banner-btn-text">{t('pwa.openInApp')}</span>
          <span className="open-in-app-banner-btn-arrow" aria-hidden>→</span>
        </a>
        <a
          href={APP_STORE_URL}
          className="open-in-app-banner-btn open-in-app-banner-btn-secondary"
          target="_blank"
          rel="noopener noreferrer"
        >
          <span className="open-in-app-banner-btn-icon-wrap">
            <img src="/static/pwa.png" alt="" className="open-in-app-banner-btn-icon" aria-hidden />
          </span>
          <span className="open-in-app-banner-btn-text">{t('pwa.downloadApp')}</span>
          <span className="open-in-app-banner-btn-arrow" aria-hidden>→</span>
        </a>
      </div>
    </div>
  );
};

export default OpenInAppBanner;
