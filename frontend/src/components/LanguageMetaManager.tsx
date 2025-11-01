import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { getLanguageFromPath } from '../utils/i18n';

/**
 * LanguageMetaManager - 全局语言meta标签管理器
 * 确保html lang属性和meta标签的语言设置与当前页面语言一致
 */
const LanguageMetaManager: React.FC = () => {
  const location = useLocation();
  const { language } = useLanguage();

  useEffect(() => {
    // 从URL路径获取语言（优先级最高）
    const urlLanguage = getLanguageFromPath(location.pathname);
    const currentLang = urlLanguage || language || 'en';

    // 设置html lang属性
    if (document.documentElement) {
      const langMap: { [key: string]: string } = {
        'en': 'en',
        'zh': 'zh-CN'
      };
      const htmlLang = langMap[currentLang] || 'en';
      
      if (document.documentElement.lang !== htmlLang) {
        document.documentElement.lang = htmlLang;
      }
    }

    // 更新og:locale
    const updateMetaTag = (name: string, content: string, property?: boolean) => {
      const selector = property ? `meta[property="${name}"]` : `meta[name="${name}"]`;
      let metaTag = document.querySelector(selector) as HTMLMetaElement;
      
      if (!metaTag) {
        metaTag = document.createElement('meta');
        if (property) {
          metaTag.setAttribute('property', name);
        } else {
          metaTag.setAttribute('name', name);
        }
        document.head.appendChild(metaTag);
      }
      
      metaTag.content = content;
    };

    // 根据语言设置og:locale
    const localeMap: { [key: string]: string } = {
      'en': 'en_US',
      'zh': 'zh_CN'
    };
    const ogLocale = localeMap[currentLang] || 'en_US';
    updateMetaTag('og:locale', ogLocale, true);

    // 如果有中文locale，也添加zh_CN
    if (currentLang === 'zh') {
      updateMetaTag('og:locale:alternate', 'en_US', true);
    } else {
      updateMetaTag('og:locale:alternate', 'zh_CN', true);
    }

  }, [location.pathname, language]);

  return null;
};

export default LanguageMetaManager;

