import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

interface HreflangManagerProps {
  type: 'task' | 'flea-market' | 'forum-post' | 'page';
  id?: number;
  path?: string; // 用于静态页面（可选，如果不传则从 useLocation 自动获取）
}

const HreflangManager: React.FC<HreflangManagerProps> = ({ type, id, path }) => {
  const base = 'https://www.link2ur.com';
  const location = useLocation();

  useEffect(() => {
    const getUrls = (): Record<string, string> => {
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
    const createdLinks: HTMLLinkElement[] = [];

    // Remove existing hreflang links managed by this component
    document.querySelectorAll('link[rel="alternate"][data-hreflang-manager="true"]').forEach(el => el.remove());

    // Create new hreflang links in <head>
    Object.entries(urls).forEach(([lang, url]) => {
      const link = document.createElement('link');
      link.rel = 'alternate';
      link.setAttribute('hreflang', lang);
      link.href = url;
      link.setAttribute('data-hreflang-manager', 'true');
      document.head.appendChild(link);
      createdLinks.push(link);
    });

    if (defaultUrl) {
      const link = document.createElement('link');
      link.rel = 'alternate';
      link.setAttribute('hreflang', 'x-default');
      link.href = defaultUrl;
      link.setAttribute('data-hreflang-manager', 'true');
      document.head.appendChild(link);
      createdLinks.push(link);
    }

    // Cleanup on unmount or dependency change
    return () => {
      createdLinks.forEach(link => {
        if (link.parentNode) {
          link.parentNode.removeChild(link);
        }
      });
    };
  }, [type, id, path, location.pathname, base]);

  return null;
};

export default HreflangManager;
