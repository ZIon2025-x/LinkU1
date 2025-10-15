import React, { useState } from 'react';
import './CookieSettings.css';

interface CookiePreferences {
  necessary: boolean;
  analytics: boolean;
  marketing: boolean;
  functional: boolean;
}

interface CookieSettingsProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (preferences: CookiePreferences) => void;
  initialPreferences?: CookiePreferences;
}

const CookieSettings: React.FC<CookieSettingsProps> = ({ 
  isOpen, 
  onClose, 
  onSave, 
  initialPreferences 
}) => {
  const [preferences, setPreferences] = useState<CookiePreferences>(
    initialPreferences || {
      necessary: true,
      analytics: false,
      marketing: false,
      functional: false
    }
  );

  const handleToggle = (key: keyof CookiePreferences) => {
    if (key === 'necessary') return; // 必要的cookies不能关闭
    setPreferences(prev => ({
      ...prev,
      [key]: !prev[key]
    }));
  };

  const handleSave = () => {
    onSave(preferences);
    onClose();
  };

  const handleAcceptAll = () => {
    const allAccepted: CookiePreferences = {
      necessary: true,
      analytics: true,
      marketing: true,
      functional: true
    };
    setPreferences(allAccepted);
    onSave(allAccepted);
    onClose();
  };

  const handleRejectAll = () => {
    const minimal: CookiePreferences = {
      necessary: true,
      analytics: false,
      marketing: false,
      functional: false
    };
    setPreferences(minimal);
    onSave(minimal);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="cookie-settings-overlay">
      <div className="cookie-settings-container">
        <div className="cookie-settings-content">
          <div className="cookie-settings-header">
            <h2>Cookie Center 🍪</h2>
            <button className="cookie-settings-close" onClick={onClose}>
              ×
            </button>
          </div>
          
          <div className="cookie-settings-body">
            <p className="cookie-settings-description">
              We use cookies to improve your experience. You can choose to accept or reject different types of cookies.
              Please note that some cookies are necessary for the website to function properly.
            </p>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>Necessary Cookies</h3>
                <div className="cookie-toggle disabled">
                  <input
                    type="checkbox"
                    checked={preferences.necessary}
                    disabled
                    readOnly
                  />
                  <span className="cookie-toggle-slider"></span>
                </div>
              </div>
              <p className="cookie-category-description">
                These cookies are essential for the basic functionality of the website and cannot be disabled. They are usually only set in response to actions you take, such as setting privacy preferences, logging in, or filling out forms.
              </p>
            </div>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>Analytics Cookies</h3>
                <div className="cookie-toggle">
                  <input
                    type="checkbox"
                    checked={preferences.analytics}
                    onChange={() => handleToggle('analytics')}
                  />
                  <span className="cookie-toggle-slider"></span>
                </div>
              </div>
              <p className="cookie-category-description">
                These cookies help us understand how visitors interact with the website by collecting and reporting information anonymously. This helps us improve website performance.
              </p>
            </div>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>Marketing Cookies</h3>
                <div className="cookie-toggle">
                  <input
                    type="checkbox"
                    checked={preferences.marketing}
                    onChange={() => handleToggle('marketing')}
                  />
                  <span className="cookie-toggle-slider"></span>
                </div>
              </div>
              <p className="cookie-category-description">
                These cookies are used to track visitors' activities on the website. The purpose is to display relevant and personalized advertisements.
              </p>
            </div>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>Functional Cookies</h3>
                <div className="cookie-toggle">
                  <input
                    type="checkbox"
                    checked={preferences.functional}
                    onChange={() => handleToggle('functional')}
                  />
                  <span className="cookie-toggle-slider"></span>
                </div>
              </div>
              <p className="cookie-category-description">
                These cookies enable the website to provide enhanced functionality and personalization settings, such as language preferences and regional settings.
              </p>
            </div>
          </div>

          <div className="cookie-settings-actions">
            <button 
              className="cookie-settings-button cookie-settings-button-secondary"
              onClick={handleRejectAll}
            >
              Reject All
            </button>
            <button 
              className="cookie-settings-button cookie-settings-button-secondary"
              onClick={handleAcceptAll}
            >
              Accept All
            </button>
            <button 
              className="cookie-settings-button cookie-settings-button-primary"
              onClick={handleSave}
            >
              Save Settings
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CookieSettings;
