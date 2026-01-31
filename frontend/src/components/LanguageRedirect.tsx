import React, { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { detectBrowserLanguage, addLanguageToPath, hasLanguagePrefix } from '../utils/i18n';

const LanguageRedirect: React.FC = () => {
  const location = useLocation();
  
  useEffect(() => {
    // 如果当前路径没有语言前缀，重定向到带语言前缀的路径
    if (!hasLanguagePrefix(location.pathname)) {
      const browserLanguage = detectBrowserLanguage();
      const redirectPath = addLanguageToPath(location.pathname, browserLanguage);
      
      // 使用 replace 而不是 push，避免在历史记录中留下重定向
      window.location.replace(redirectPath);
    }
  }, [location.pathname]);

  // 如果路径已经有语言前缀，不需要重定向
  if (hasLanguagePrefix(location.pathname)) {
    return null;
  }

  // 临时显示加载状态，实际会被重定向
  return <div>Redirecting...</div>;
};

export default LanguageRedirect;
