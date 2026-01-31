/**
 * 通知权限提示（对齐 iOS NotificationPermissionView）
 * 在用户登录后、权限未决时展示一次，引导开启浏览器通知
 */
import React, { useState, useEffect } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { useCurrentUser } from '../contexts/AuthContext';
import './NotificationPermissionPrompt.css';

const STORAGE_KEY = 'notification-prompt-dismissed';

const NotificationPermissionPrompt: React.FC = () => {
  const { t } = useLanguage();
  const { user } = useCurrentUser();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined' || !('Notification' in window)) return;
    if (!user) return;
    if (Notification.permission !== 'default') return;
    if (localStorage.getItem(STORAGE_KEY)) return;

    // 登录后延迟展示，避免与安装提示重叠
    const timer = setTimeout(() => setVisible(true), 2000);
    return () => clearTimeout(timer);
  }, [user]);

  const handleAllow = async () => {
    try {
      await Notification.requestPermission();
    } catch {
      // ignore
    }
    setVisible(false);
  };

  const handleNotNow = () => {
    localStorage.setItem(STORAGE_KEY, Date.now().toString());
    setVisible(false);
  };

  if (!visible) return null;

  return (
    <div className="notification-permission-overlay" role="dialog" aria-labelledby="notification-permission-title">
      <div className="notification-permission-backdrop" onClick={handleNotNow} aria-hidden />
      <div className="notification-permission-card">
        <div className="notification-permission-icon">🔔</div>
        <h2 id="notification-permission-title" className="notification-permission-title">
          {t('pwa.notificationPromptTitle') || '开启消息通知'}
        </h2>
        <p className="notification-permission-message">
          {t('pwa.notificationPromptMessage') || '开启后，新消息和任务动态会及时提醒您，不错过重要回复。'}
        </p>
        <div className="notification-permission-actions">
          <button
            type="button"
            className="notification-permission-btn notification-permission-btn-secondary"
            onClick={handleNotNow}
          >
            {t('pwa.notificationNotNow') || '暂不'}
          </button>
          <button
            type="button"
            className="notification-permission-btn notification-permission-btn-primary"
            onClick={handleAllow}
          >
            {t('pwa.notificationAllow') || '允许'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default NotificationPermissionPrompt;
