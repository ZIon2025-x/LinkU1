import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

/**
 * FaviconManager - 全局favicon管理器
 * 确保所有页面都使用 static/favicon 作为标签图标
 */
const FaviconManager: React.FC = () => {
  const location = useLocation();

  useEffect(() => {
    // 确保favicon始终指向 static/favicon
    const setFavicon = () => {
      // 获取或创建favicon链接
      let faviconLink = document.querySelector("link[rel*='icon']") as HTMLLinkElement;
      
      if (!faviconLink) {
        // 如果不存在，创建新的favicon链接
        faviconLink = document.createElement('link');
        faviconLink.rel = 'icon';
        document.head.appendChild(faviconLink);
      }

      // 设置favicon路径，使用绝对URL和版本号避免缓存
      const faviconUrl = `${window.location.origin}/static/favicon.png?v=3`;
      
      // 只有当href不同时才更新，避免不必要的DOM操作
      if (faviconLink.href !== faviconUrl) {
        faviconLink.href = faviconUrl;
      }

      // 确保所有尺寸的favicon都存在并指向正确路径
      const sizes = ['16x16', '32x32', '48x48', '96x96', '128x128', '192x192', '256x256', '512x512'];
      sizes.forEach(size => {
        let sizeLink = document.querySelector(`link[rel='icon'][sizes='${size}']`) as HTMLLinkElement;
        if (!sizeLink) {
          sizeLink = document.createElement('link');
          sizeLink.rel = 'icon';
          sizeLink.setAttribute('sizes', size);
          sizeLink.type = 'image/png';
          document.head.appendChild(sizeLink);
        }
        const sizeUrl = `${window.location.origin}/static/favicon.png?v=3`;
        if (sizeLink.href !== sizeUrl) {
          sizeLink.href = sizeUrl;
        }
      });

      // 确保shortcut icon也指向正确路径
      let shortcutIcon = document.querySelector("link[rel='shortcut icon']") as HTMLLinkElement;
      if (!shortcutIcon) {
        shortcutIcon = document.createElement('link');
        shortcutIcon.rel = 'shortcut icon';
        document.head.appendChild(shortcutIcon);
      }
      const shortcutUrl = `${window.location.origin}/static/favicon.ico?v=3`;
      if (shortcutIcon.href !== shortcutUrl) {
        shortcutIcon.href = shortcutUrl;
      }
    };

    // 页面加载时设置
    setFavicon();

    // 路由变化时也设置（防止某些页面修改了favicon）
    const timer = setTimeout(() => {
      setFavicon();
    }, 100);

    return () => {
      clearTimeout(timer);
    };
  }, [location.pathname]);

  return null; // 此组件不渲染任何内容
};

export default FaviconManager;

