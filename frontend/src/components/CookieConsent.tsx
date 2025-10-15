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
            <h3>We Use Cookies</h3>
          </div>
          <div className="cookie-consent-body">
            <p>
              Click "Accept" to allow LinkU to use cookies to personalize this website and serve ads and measure their effectiveness on other applications and websites, including social media.
              Customize your preferences in your cookie settings, or click "Reject" if you do not want us to use cookies for this purpose.
              Learn more in our cookie notice.
            </p>
          </div>
          <div className="cookie-consent-actions">
            <button 
              className="cookie-consent-button cookie-consent-button-secondary"
              onClick={onCustomize}
            >
              Cookie Settings
            </button>
            <button 
              className="cookie-consent-button cookie-consent-button-secondary"
              onClick={handleReject}
            >
              Reject
            </button>
            <button 
              className="cookie-consent-button cookie-consent-button-primary"
              onClick={handleAccept}
            >
              Accept
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CookieConsent;
