import type React from 'react';
import { useCookie } from '../contexts/CookieContext';
import CookieConsent from './CookieConsent';
import CookieSettings from './CookieSettings';

const CookieManager: React.FC = () => {
  const {
    showConsent,
    showSettings,
    acceptCookies,
    rejectCookies,
    openSettings,
    closeSettings,
    updatePreferences,
    preferences
  } = useCookie();

  return (
    <>
      {showConsent && (
        <CookieConsent
          onAccept={acceptCookies}
          onReject={rejectCookies}
          onCustomize={openSettings}
        />
      )}
      
      {showSettings && (
        <CookieSettings
          isOpen={showSettings}
          onClose={closeSettings}
          onSave={updatePreferences}
          initialPreferences={preferences}
        />
      )}
    </>
  );
};

export default CookieManager;
