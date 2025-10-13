import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import enTranslations from '../locales/en.json';
import zhTranslations from '../locales/zh.json';
import { getLanguageFromPath, detectBrowserLanguage, addLanguageToPath, DEFAULT_LANGUAGE } from '../utils/i18n';

export type Language = 'en' | 'zh';

interface LanguageContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
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
  const location = useLocation();
  
  // 从URL路径检测语言，如果没有则使用默认语言
  const [language, setLanguage] = useState<Language>(() => {
    const urlLanguage = getLanguageFromPath(location.pathname);
    return urlLanguage !== DEFAULT_LANGUAGE ? urlLanguage : DEFAULT_LANGUAGE;
  });

  // 当URL路径变化时，更新语言设置
  useEffect(() => {
    const urlLanguage = getLanguageFromPath(location.pathname);
    if (urlLanguage !== language) {
      setLanguage(urlLanguage);
      // 同时更新localStorage
      localStorage.setItem('language', urlLanguage);
    }
  }, [location.pathname, language]);

  // 保存语言设置到localStorage并更新URL
  const handleSetLanguage = (lang: Language) => {
    setLanguage(lang);
    localStorage.setItem('language', lang);
    
    // 更新URL以反映新的语言设置
    const currentPath = location.pathname;
    const newPath = addLanguageToPath(currentPath, lang);
    
    // 如果路径发生变化，进行导航
    if (newPath !== currentPath) {
      window.location.href = newPath;
    }
  };

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

  return (
    <LanguageContext.Provider value={{ language, setLanguage: handleSetLanguage, t }}>
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
