/**
 * 「在 App 内打开」单按钮条
 * 仅对 iOS 用户显示。点击后通过 link2ur:// 自定义 scheme 打开 App；
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
    // 用 link2ur:// 自定义 scheme 打开 App，App 端 DeepLinkHandler 会处理路径
    const appPath = window.location.pathname + window.location.search;
    const deepLink = `link2ur://app${appPath}`;
    sessionStorage.setItem(FALLBACK_KEY, '1');
    window.location.href = deepLink;
  };

  if (!visible) return null;

  return (
    <div className="open-in-app-banner" role="banner">
      <div className="open-in-app-banner-float">
        <a
          href="#"
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
