import React, { useState, useEffect } from 'react';
import './CookieConsent.css';

interface CookiePreferences {
  necessary: boolean;
  analytics: boolean;
  marketing: boolean;
  functional: boolean;
}

interface CookieConsentProps {
  onAccept: (preferences: CookiePreferences) => void;
  onReject: () => void;
  onCustomize: () => void;
}

const CookieConsent: React.FC<CookieConsentProps> = ({ onAccept, onReject, onCustomize }) => {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // 检查是否已经显示过cookie同意弹窗
    const hasConsented = localStorage.getItem('cookieConsent');
    if (!hasConsented) {
      setIsVisible(true);
    }
  }, []);

  const handleAccept = () => {
    const defaultPreferences: CookiePreferences = {
      necessary: true,
      analytics: true,
      marketing: true,
      functional: true
    };
    onAccept(defaultPreferences);
    setIsVisible(false);
  };

  const handleReject = () => {
    const minimalPreferences: CookiePreferences = {
      necessary: true,
      analytics: false,
      marketing: false,
      functional: false
    };
    onReject();
    onAccept(minimalPreferences);
    setIsVisible(false);
  };

  if (!isVisible) return null;

  return (
    <div className="cookie-consent-overlay">
      <div className="cookie-consent-container">
        <div className="cookie-consent-content">
          <div className="cookie-consent-header">
            <h3>我们使用Cookie</h3>
          </div>
          <div className="cookie-consent-body">
            <p>
              点击"接受"以允许LinkU使用Cookie来个性化此网站，并在其他应用程序和网站上投放广告并衡量其效果，包括社交媒体。
              在您的Cookie设置中自定义您的偏好，或点击"拒绝"如果您不希望我们为此目的使用Cookie。
              在我们的Cookie通知中了解更多信息。
            </p>
          </div>
          <div className="cookie-consent-actions">
            <button 
              className="cookie-consent-button cookie-consent-button-secondary"
              onClick={onCustomize}
            >
              Cookie设置
            </button>
            <button 
              className="cookie-consent-button cookie-consent-button-secondary"
              onClick={handleReject}
            >
              拒绝
            </button>
            <button 
              className="cookie-consent-button cookie-consent-button-primary"
              onClick={handleAccept}
            >
              接受
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CookieConsent;
