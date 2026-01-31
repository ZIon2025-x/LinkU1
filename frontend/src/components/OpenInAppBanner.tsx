/**
 * 「在 App 内打开」单按钮条
 * 仅对 iOS 用户显示。点击后先尝试用当前页 URL 打开 App（Universal Link）；
 * 若未安装，页面会重新加载，此时自动跳转到 App Store 下载页。
 */
import React, { useState, useEffect } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { detectOS } from '../utils/deviceDetector';
import { APP_STORE_URL } from '../config';
import './OpenInAppBanner.css';

const FALLBACK_KEY = 'open-in-app-fallback';

const OpenInAppBanner: React.FC = () => {
  const { t } = useLanguage();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const os = detectOS();
    if (os.name !== 'iOS') return;
    setVisible(true);
  }, []);

  // 从「尝试打开 App」返回且未安装时，自动跳转 App Store
  useEffect(() => {
    if (typeof window === 'undefined' || !visible) return;
    if (sessionStorage.getItem(FALLBACK_KEY) !== '1') return;
    sessionStorage.removeItem(FALLBACK_KEY);
    window.location.href = APP_STORE_URL;
  }, [visible]);

  const handleOpenApp = (e: React.MouseEvent) => {
    e.preventDefault();
    const url = window.location.href;
    sessionStorage.setItem(FALLBACK_KEY, '1');
    window.location.href = url;
  };

  if (!visible) return null;

  return (
    <div className="open-in-app-banner" role="banner">
      <div className="open-in-app-banner-float">
        <a
          href={typeof window !== 'undefined' ? window.location.href : '#'}
          className="open-in-app-banner-btn"
          onClick={handleOpenApp}
          rel="noopener noreferrer"
        >
          <span className="open-in-app-banner-btn-icon-wrap">
            <img src="/static/pwa.png" alt="" className="open-in-app-banner-btn-icon" aria-hidden />
          </span>
          <span className="open-in-app-banner-btn-text">{t('pwa.openInApp')}</span>
          <span className="open-in-app-banner-btn-arrow" aria-hidden>→</span>
        </a>
      </div>
    </div>
  );
};

export default OpenInAppBanner;
