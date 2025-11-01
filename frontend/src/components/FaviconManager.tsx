import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

/**
 * FaviconManager - 全局favicon管理器
 * 确保所有页面都使用 static/favicon 作为标签图标
 * 特别针对移动端Chrome和搜索引擎（Bing）优化
 */
const FaviconManager: React.FC = () => {
  const location = useLocation();

  useEffect(() => {
    // 确保favicon始终指向 static/favicon
    const setFavicon = () => {
      const version = 'v=4';
      const baseUrl = window.location.origin;
      
      // 1. 设置根目录favicon.ico（搜索引擎和浏览器默认查找的路径，必须优先设置）
      let rootFavicon = document.querySelector("link[rel='icon']:not([sizes]):not([type='image/png'])") as HTMLLinkElement;
      if (!rootFavicon) {
        // 移除所有旧的favicon链接（除了有sizes的）
        const oldIcons = document.querySelectorAll("link[rel='icon']:not([sizes])");
        oldIcons.forEach(icon => icon.remove());
        
        // 创建新的根目录favicon
        rootFavicon = document.createElement('link');
        rootFavicon.rel = 'icon';
        rootFavicon.type = 'image/x-icon';
        // 插入到head的最前面
        document.head.insertBefore(rootFavicon, document.head.firstChild);
      }
      const rootFaviconUrl = `${baseUrl}/static/favicon.ico?${version}`;
      if (rootFavicon.href !== rootFaviconUrl) {
        rootFavicon.href = rootFaviconUrl;
      }

      // 2. 设置shortcut icon（旧版浏览器需要）
      let shortcutIcon = document.querySelector("link[rel='shortcut icon']") as HTMLLinkElement;
      if (!shortcutIcon) {
        shortcutIcon = document.createElement('link');
        shortcutIcon.rel = 'shortcut icon';
        shortcutIcon.type = 'image/x-icon';
        document.head.insertBefore(shortcutIcon, rootFavicon.nextSibling);
      }
      const shortcutUrl = `${baseUrl}/static/favicon.ico?${version}`;
      if (shortcutIcon.href !== shortcutUrl) {
        shortcutIcon.href = shortcutUrl;
      }

      // 3. 设置所有尺寸的PNG favicon（移动端Chrome需要）
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
        const sizeUrl = `${baseUrl}/static/favicon.png?${version}`;
        if (sizeLink.href !== sizeUrl) {
          sizeLink.href = sizeUrl;
        }
      });

      // 4. 强制更新（通过改变查询参数来触发浏览器重新加载）
      const allFavicons = document.querySelectorAll("link[rel*='icon']");
      allFavicons.forEach((link: Element) => {
        const faviconLink = link as HTMLLinkElement;
        if (faviconLink.href && !faviconLink.href.includes(version)) {
          // 更新到新版本
          const newUrl = faviconLink.href.split('?')[0] + `?${version}`;
          faviconLink.href = newUrl;
        }
      });
    };

    // 立即执行（不等待路由变化）
    setFavicon();

    // 路由变化时也立即设置（防止某些页面修改了favicon）
    const timer = setTimeout(() => {
      setFavicon();
    }, 50);

    // 再次延迟设置，确保DOM完全加载后执行
    const timer2 = setTimeout(() => {
      setFavicon();
    }, 500);

    return () => {
      clearTimeout(timer);
      clearTimeout(timer2);
    };
  }, [location.pathname]);

  // 页面加载时也执行一次
  useEffect(() => {
    const setFaviconOnLoad = () => {
      const version = 'v=4';
      const baseUrl = window.location.origin;
      
      // 确保根目录favicon.ico在最前面
      let rootFavicon = document.querySelector("link[rel='icon']:not([sizes])") as HTMLLinkElement;
      if (rootFavicon) {
        const rootFaviconUrl = `${baseUrl}/static/favicon.ico?${version}`;
        if (rootFavicon.href !== rootFaviconUrl) {
          rootFavicon.href = rootFaviconUrl;
        }
      }
    };

    // DOM加载完成后执行
    if (document.readyState === 'complete') {
      setFaviconOnLoad();
    } else {
      window.addEventListener('load', setFaviconOnLoad);
      return () => window.removeEventListener('load', setFaviconOnLoad);
    }
  }, []);

  return null; // 此组件不渲染任何内容
};

export default FaviconManager;

