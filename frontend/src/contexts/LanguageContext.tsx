import React, { createContext, useContext, useState, useEffect, ReactNode, useCallback } from 'react';
import enTranslations from '../locales/en.json';
import zhTranslations from '../locales/zh.json';
import { getLanguageFromPath, detectBrowserLanguage, addLanguageToPath, DEFAULT_LANGUAGE } from '../utils/i18n';

export type Language = 'en' | 'zh';

interface LanguageContextType {
  language: Language;
  setLanguage: (lang: Language, navigate?: (path: string) => void) => void;
  t: (key: string) => string;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

const translations = {
  en: enTranslations,
  zh: zhTranslations,
};

interface LanguageProviderProps {
  children: ReactNode;
}

export const LanguageProvider: React.FC<LanguageProviderProps> = ({ children }) => {
  // 从URL路径、localStorage或用户偏好检测语言
  const [language, setLanguageState] = useState<Language>(() => {
    // 首先尝试从URL检测（如果可用）- 优先级最高
    if (typeof window !== 'undefined') {
      const urlLanguage = getLanguageFromPath(window.location.pathname);
      if (urlLanguage && ['en', 'zh'].includes(urlLanguage)) {
        return urlLanguage;
      }
    }
    
    // 然后尝试从localStorage获取
    const savedLanguage = localStorage.getItem('language') as Language;
    if (savedLanguage && ['en', 'zh'].includes(savedLanguage)) {
      return savedLanguage;
    }
    
    // 最后使用浏览器语言检测
    return detectBrowserLanguage();
  });

  // 在组件挂载后，尝试从用户资料获取语言偏好（只在初始化时执行一次）
  useEffect(() => {
    const loadUserLanguagePreference = async () => {
      try {
        // 尝试获取用户资料（如果用户已登录）
        const response = await fetch('/api/users/profile/me', {
          credentials: 'include'
        });
        
        if (response.ok) {
          const userData = await response.json();
          
          // 如果用户有语言偏好设置，且与当前语言不同，则更新语言
          if (userData.language_preference && 
              ['en', 'zh'].includes(userData.language_preference)) {
            const currentLang = localStorage.getItem('language') || language;
            
            // 只有在用户偏好与当前语言不同时才更新
            if (userData.language_preference !== currentLang) {
              localStorage.setItem('language', userData.language_preference);
              setLanguageState(userData.language_preference as Language);
              
              // 更新URL以反映新的语言设置
              const currentPath = window.location.pathname;
              const newPath = addLanguageToPath(currentPath, userData.language_preference);
              if (newPath !== currentPath) {
                window.location.href = newPath;
              }
            }
          }
        }
      } catch (error) {
        // 用户未登录或获取失败，忽略
        console.debug('无法获取用户语言偏好:', error);
      }
    };
    
    loadUserLanguagePreference();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // 只在组件挂载时执行一次，不依赖language避免循环

  // 监听路由变化，同步语言状态（浏览器前进/后退按钮）
  useEffect(() => {
    const handlePopState = () => {
      if (typeof window !== 'undefined') {
        const urlLanguage = getLanguageFromPath(window.location.pathname);
        if (urlLanguage && ['en', 'zh'].includes(urlLanguage) && urlLanguage !== language) {
          setLanguageState(urlLanguage);
          localStorage.setItem('language', urlLanguage);
        }
      }
    };

    window.addEventListener('popstate', handlePopState);
    
    return () => {
      window.removeEventListener('popstate', handlePopState);
    };
  }, [language]);

  // 保存语言设置到localStorage并更新URL
  const handleSetLanguage = useCallback((lang: Language, navigate?: (path: string) => void) => {
    // 先更新状态
    setLanguageState(lang);
    localStorage.setItem('language', lang);

    // 更新URL以反映新的语言设置
    const currentPath = window.location.pathname;
    const newPath = addLanguageToPath(currentPath, lang);

    // 如果路径发生变化，进行导航
    if (newPath !== currentPath) {
      // 优先使用客户端导航（如果可用）
      if (navigate) {
        navigate(newPath);
      } else {
        // 降级到强制刷新
        window.location.href = newPath;
      }
    }
  }, []);

  // 翻译函数
  const t = (key: string): string => {
    const keys = key.split('.');
    let value: any = translations[language];
    
    for (const k of keys) {
      if (value && typeof value === 'object' && k in value) {
        value = value[k];
      } else {
        // 如果找不到翻译，尝试使用英文作为后备
        value = translations.en;
        for (const fallbackKey of keys) {
          if (value && typeof value === 'object' && fallbackKey in value) {
            value = value[fallbackKey];
          } else {
            return key; // 如果连英文都找不到，返回原始key
          }
        }
        break;
      }
    }
    
    return typeof value === 'string' ? value : key;
  };

  const value = React.useMemo(() => ({
    language,
    setLanguage: handleSetLanguage,
    t
  }), [language, handleSetLanguage]);

  return (
    <LanguageContext.Provider value={value}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = (): LanguageContextType => {
  const context = useContext(LanguageContext);
  if (context === undefined) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
};

export default LanguageContext;
