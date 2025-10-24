import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
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
  // 从URL路径或localStorage检测语言
  const [language, setLanguage] = useState<Language>(() => {
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

  // 监听URL变化，同步语言状态
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const urlLanguage = getLanguageFromPath(window.location.pathname);
      if (urlLanguage && ['en', 'zh'].includes(urlLanguage) && urlLanguage !== language) {
        setLanguage(urlLanguage);
        localStorage.setItem('language', urlLanguage);
      }
    }
  }, [language]);

  // 保存语言设置到localStorage并更新URL
  const handleSetLanguage = (lang: Language) => {
    setLanguage(lang);
    localStorage.setItem('language', lang);

    // 更新URL以反映新的语言设置
    const currentPath = window.location.pathname;
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
