import type React from 'react';
import { useLocation } from 'react-router-dom';

interface HreflangManagerProps {
  type: 'task' | 'flea-market' | 'forum-post' | 'page';
  id?: number;
  path?: string; // 用于静态页面（可选，如果不传则从 useLocation 自动获取）
}

const HreflangManager: React.FC<HreflangManagerProps> = ({ type, id, path }) => {
  const base = 'https://www.link2ur.com';
  const location = useLocation(); // 添加 useLocation 作为 fallback
  
  // 语言代码映射（支持未来扩展）
  // ⚠️ 注意：前端 i18n 代码里语言变量是 'en' 和 'zh'，这里统一映射为 hreflang 格式
  const getLanguageCode = (lang: string): string => {
    const langMap: Record<string, string> = {
      'en': 'en-GB',
      'zh': 'zh-CN',
      // 未来可扩展：'en-US': 'en-US', 'zh-HK': 'zh-HK'
    };
    return langMap[lang] || 'en-GB';
  };
  
  const getUrls = () => {
    if (type === 'task' && id) {
      return {
        'en-GB': `${base}/en/tasks/${id}`,
        'zh-CN': `${base}/zh/tasks/${id}`,
      };
    }
    if (type === 'flea-market' && id) {
      return {
        'en-GB': `${base}/en/flea-market/${id}`,
        'zh-CN': `${base}/zh/flea-market/${id}`,
      };
    }
    if (type === 'forum-post' && id) {
      return {
        'en-GB': `${base}/en/forum/post/${id}`,
        'zh-CN': `${base}/zh/forum/post/${id}`,
      };
    }
    if (type === 'page') {
      // 如果传了 path 就用 path，否则从 useLocation 获取
      // ⚠️ 重要：必须去掉查询参数，否则不同语言版本会带上不同参数，Google 认为内容不一致
      const cleanPath = path || location.pathname.replace(/^\/(en|zh)/, '').split('?')[0];
      if (cleanPath) {
        return {
          'en-GB': `${base}/en${cleanPath}`,
          'zh-CN': `${base}/zh${cleanPath}`,
        };
      }
    }
    return {};
  };

  const urls = getUrls();
  const defaultUrl = urls['en-GB'] || Object.values(urls)[0];

  return (
    <>
      {Object.entries(urls).map(([lang, url]) => (
        <link key={lang} rel="alternate" hrefLang={lang} href={url} />
      ))}
      {defaultUrl && (
        <link rel="alternate" hrefLang="x-default" href={defaultUrl} />
      )}
    </>
  );
};

export default HreflangManager;

