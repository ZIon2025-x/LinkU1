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
            <h2>Cookie设置</h2>
            <button className="cookie-settings-close" onClick={onClose}>
              ×
            </button>
          </div>
          
          <div className="cookie-settings-body">
            <p className="cookie-settings-description">
              我们使用Cookie来改善您的体验。您可以选择接受或拒绝不同类型的Cookie。
              请注意，某些Cookie对于网站的正常运行是必要的。
            </p>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>必要的Cookie</h3>
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
                这些Cookie对于网站的基本功能是必需的，无法关闭。它们通常仅响应您执行的操作而设置，
                例如设置隐私偏好、登录或填写表单。
              </p>
            </div>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>分析Cookie</h3>
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
                这些Cookie帮助我们了解访问者如何与网站互动，通过匿名收集和报告信息。
                这有助于我们改善网站性能。
              </p>
            </div>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>营销Cookie</h3>
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
                这些Cookie用于跟踪访问者在网站上的活动。目的是显示相关和个性化的广告。
              </p>
            </div>

            <div className="cookie-category">
              <div className="cookie-category-header">
                <h3>功能Cookie</h3>
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
                这些Cookie使网站能够提供增强的功能和个性化设置，如语言偏好和区域设置。
              </p>
            </div>
          </div>

          <div className="cookie-settings-actions">
            <button 
              className="cookie-settings-button cookie-settings-button-secondary"
              onClick={handleRejectAll}
            >
              拒绝全部
            </button>
            <button 
              className="cookie-settings-button cookie-settings-button-secondary"
              onClick={handleAcceptAll}
            >
              接受全部
            </button>
            <button 
              className="cookie-settings-button cookie-settings-button-primary"
              onClick={handleSave}
            >
              保存设置
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CookieSettings;
