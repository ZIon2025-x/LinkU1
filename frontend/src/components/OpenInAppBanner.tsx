/**
 * 「在 App 内打开」单按钮条
 * 对 iOS / Android 移动端显示。点击后通过 link2ur:// 打开 App；
 * iOS：若未安装，页面重新加载后自动跳转 App Store。
 * Android：若未安装或未打开，约 2 秒后自动跳转 Google Play。
 */
import React, { useState, useEffect, useRef } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { detectOS } from '../utils/deviceDetector';
import { APP_STORE_URL, GOOGLE_PLAY_URL } from '../config';
import './OpenInAppBanner.css';

const FALLBACK_KEY = 'open-in-app-fallback';

const OpenInAppBanner: React.FC = () => {
  const { t } = useLanguage();
  const [visible, setVisible] = useState(false);
  const osRef = useRef<{ name: string } | null>(null);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const os = detectOS();
    if (os.name !== 'iOS' && os.name !== 'Android') return;
    osRef.current = os;
    setVisible(true);
  }, []);

  // 从「尝试打开 App」返回且未安装时，自动跳转对应应用商店
  useEffect(() => {
    if (typeof window === 'undefined' || !visible) return;
    const fallback = sessionStorage.getItem(FALLBACK_KEY);
    if (!fallback) return;
    sessionStorage.removeItem(FALLBACK_KEY);
    const storeUrl = fallback === 'android' ? GOOGLE_PLAY_URL : APP_STORE_URL;
    window.location.href = storeUrl;
  }, [visible]);

  const handleOpenApp = (e: React.MouseEvent) => {
    e.preventDefault();
    const os = osRef.current ?? detectOS();
    const appPath = window.location.pathname + window.location.search;
    const deepLink = `link2ur://app${appPath}`;
    const isAndroid = os.name === 'Android';
    sessionStorage.setItem(FALLBACK_KEY, isAndroid ? 'android' : 'ios');
    window.location.href = deepLink;

    // Android：若未离开页面（App 未打开），约 2 秒后跳转 Google Play
    if (isAndroid) {
      const timeoutId = window.setTimeout(() => {
        if (document.visibilityState === 'visible') {
          sessionStorage.removeItem(FALLBACK_KEY);
          window.location.href = GOOGLE_PLAY_URL;
        }
      }, 2000);
      // 页面隐藏说明可能已跳转 App，清除定时器
      const onVisibilityChange = () => {
        if (document.visibilityState === 'hidden') {
          window.clearTimeout(timeoutId);
          document.removeEventListener('visibilitychange', onVisibilityChange);
        }
      };
      document.addEventListener('visibilitychange', onVisibilityChange);
    }
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
