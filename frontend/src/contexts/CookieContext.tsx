import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

export interface CookiePreferences {
  necessary: boolean;
  analytics: boolean;
  marketing: boolean;
  functional: boolean;
}

interface CookieContextType {
  preferences: CookiePreferences;
  hasConsented: boolean;
  showConsent: boolean;
  showSettings: boolean;
  acceptCookies: (preferences: CookiePreferences) => void;
  rejectCookies: () => void;
  openSettings: () => void;
  closeSettings: () => void;
  updatePreferences: (preferences: CookiePreferences) => void;
}

const CookieContext = createContext<CookieContextType | undefined>(undefined);

const COOKIE_CONSENT_KEY = 'cookieConsent';
const COOKIE_PREFERENCES_KEY = 'cookiePreferences';

const defaultPreferences: CookiePreferences = {
  necessary: true,
  analytics: false,
  marketing: false,
  functional: false
};

interface CookieProviderProps {
  children: ReactNode;
}

export const CookieProvider: React.FC<CookieProviderProps> = ({ children }) => {
  const [preferences, setPreferences] = useState<CookiePreferences>(defaultPreferences);
  const [hasConsented, setHasConsented] = useState(false);
  const [showConsent, setShowConsent] = useState(false);
  const [showSettings, setShowSettings] = useState(false);

  useEffect(() => {
    // 检查本地存储中的Cookie同意状态
    const consentStatus = localStorage.getItem(COOKIE_CONSENT_KEY);
    const savedPreferences = localStorage.getItem(COOKIE_PREFERENCES_KEY);

    if (consentStatus === 'true' && savedPreferences) {
      try {
        const parsedPreferences = JSON.parse(savedPreferences);
        setPreferences(parsedPreferences);
        setHasConsented(true);
      } catch (error) {
                setShowConsent(true);
      }
    } else {
      setShowConsent(true);
    }
  }, []);

  const acceptCookies = (newPreferences: CookiePreferences) => {
    setPreferences(newPreferences);
    setHasConsented(true);
    setShowConsent(false);
    setShowSettings(false);
    
    // 保存到本地存储
    localStorage.setItem(COOKIE_CONSENT_KEY, 'true');
    localStorage.setItem(COOKIE_PREFERENCES_KEY, JSON.stringify(newPreferences));
    
    // 根据偏好设置实际的Cookie
    setCookiesBasedOnPreferences(newPreferences);
  };

  const rejectCookies = () => {
    const minimalPreferences: CookiePreferences = {
      necessary: true,
      analytics: false,
      marketing: false,
      functional: false
    };
    
    setPreferences(minimalPreferences);
    setHasConsented(true);
    setShowConsent(false);
    setShowSettings(false);
    
    // 保存到本地存储
    localStorage.setItem(COOKIE_CONSENT_KEY, 'true');
    localStorage.setItem(COOKIE_PREFERENCES_KEY, JSON.stringify(minimalPreferences));
    
    // 清除非必要的Cookie
    clearNonEssentialCookies();
  };

  const updatePreferences = (newPreferences: CookiePreferences) => {
    setPreferences(newPreferences);
    setHasConsented(true);
    setShowSettings(false);
    
    // 更新本地存储
    localStorage.setItem(COOKIE_CONSENT_KEY, 'true');
    localStorage.setItem(COOKIE_PREFERENCES_KEY, JSON.stringify(newPreferences));
    
    // 根据新偏好更新Cookie
    setCookiesBasedOnPreferences(newPreferences);
  };

  const openSettings = () => {
    setShowSettings(true);
  };

  const closeSettings = () => {
    setShowSettings(false);
  };

  const setCookiesBasedOnPreferences = (prefs: CookiePreferences) => {
    // 这里可以根据偏好设置实际的Cookie
    // 例如，如果用户同意分析Cookie，可以设置Google Analytics等
    
    if (prefs.analytics) {
      // 启用分析Cookie
    }
    
    if (prefs.marketing) {
      // 启用营销Cookie
    }
    
    if (prefs.functional) {
      // 启用功能Cookie
    }
  };

  const clearNonEssentialCookies = () => {
    // 清除非必要的Cookie
  };

  const value: CookieContextType = {
    preferences,
    hasConsented,
    showConsent,
    showSettings,
    acceptCookies,
    rejectCookies,
    openSettings,
    closeSettings,
    updatePreferences
  };

  return (
    <CookieContext.Provider value={value}>
      {children}
    </CookieContext.Provider>
  );
};

export const useCookie = (): CookieContextType => {
  const context = useContext(CookieContext);
  if (context === undefined) {
    throw new Error('useCookie must be used within a CookieProvider');
  }
  return context;
};
