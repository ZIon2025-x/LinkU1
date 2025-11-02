import { useEffect, useLayoutEffect } from 'react';
import { useLocation } from 'react-router-dom';

/**
 * FaviconManager - 全局favicon管理器
 * 确保所有页面都使用 static/favicon 作为标签图标
 * 特别针对移动端Chrome和搜索引擎（Bing、Google）优化
 */
const FaviconManager: React.FC = () => {
  const location = useLocation();

  // 使用useLayoutEffect确保在DOM渲染前同步执行，优先级最高
  useLayoutEffect(() => {
    const setFavicon = () => {
      const baseUrl = window.location.origin;
      const version = Date.now(); // 使用时间戳避免缓存
      
      // 1. 移除所有旧的favicon链接（包括所有格式）
      const allFavicons = document.querySelectorAll("link[rel='icon'], link[rel='shortcut icon'], link[rel='apple-touch-icon']");
      allFavicons.forEach(icon => icon.remove());
      
      // 2. 设置根目录favicon.ico（搜索引擎和浏览器默认查找的路径，必须优先设置）
      // 插入到head的最前面，确保优先读取
      const rootFavicon = document.createElement('link');
      rootFavicon.rel = 'icon';
      rootFavicon.type = 'image/x-icon';
      rootFavicon.href = `${baseUrl}/static/favicon.ico?v=${version}`;
      document.head.insertBefore(rootFavicon, document.head.firstChild);

      // 3. 设置shortcut icon（旧版浏览器需要）
      const shortcutIcon = document.createElement('link');
      shortcutIcon.rel = 'shortcut icon';
      shortcutIcon.type = 'image/x-icon';
      shortcutIcon.href = `${baseUrl}/static/favicon.ico?v=${version}`;
      document.head.insertBefore(shortcutIcon, rootFavicon.nextSibling);

      // 4. 设置所有尺寸的PNG favicon（移动端Chrome和Google需要）
      // 关键尺寸：16x16, 32x32, 192x192, 512x512
      const sizes = ['16x16', '32x32', '48x48', '96x96', '128x128', '192x192', '256x256', '512x512'];
      sizes.forEach(size => {
        const sizeLink = document.createElement('link');
        sizeLink.rel = 'icon';
        sizeLink.setAttribute('sizes', size);
        sizeLink.type = 'image/png';
        sizeLink.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(sizeLink, shortcutIcon.nextSibling);
      });

      // 5. 设置Apple Touch Icon（iOS设备需要）
      const appleIcon = document.createElement('link');
      appleIcon.rel = 'apple-touch-icon';
      appleIcon.href = `${baseUrl}/static/favicon.png?v=${version}`;
      document.head.insertBefore(appleIcon, document.head.firstChild);
    };

    // 立即执行
    setFavicon();
  }, [location.pathname]);

  // 额外的useEffect，在页面完全加载后再次确保favicon正确
  useEffect(() => {
    const setFaviconOnLoad = () => {
      const baseUrl = window.location.origin;
      const version = Date.now();
      
      // 检查并确保favicon.ico在最前面
      let rootFavicon = document.querySelector("link[rel='icon']:not([sizes])") as HTMLLinkElement;
      if (!rootFavicon || !rootFavicon.href.includes('/static/favicon.ico')) {
        // 如果不存在或不正确，重新创建
        if (rootFavicon) {
          rootFavicon.remove();
        }
        rootFavicon = document.createElement('link');
        rootFavicon.rel = 'icon';
        rootFavicon.type = 'image/x-icon';
        rootFavicon.href = `${baseUrl}/static/favicon.ico?v=${version}`;
        document.head.insertBefore(rootFavicon, document.head.firstChild);
      }
      
      // 确保192x192和512x512存在（Google移动端关键尺寸）
      const sizes192 = document.querySelector("link[rel='icon'][sizes='192x192']") as HTMLLinkElement;
      const sizes512 = document.querySelector("link[rel='icon'][sizes='512x512']") as HTMLLinkElement;
      
      if (!sizes192 || !sizes192.href.includes('/static/favicon.png')) {
        if (sizes192) sizes192.remove();
        const icon192 = document.createElement('link');
        icon192.rel = 'icon';
        icon192.setAttribute('sizes', '192x192');
        icon192.type = 'image/png';
        icon192.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(icon192, document.head.firstChild);
      }
      
      if (!sizes512 || !sizes512.href.includes('/static/favicon.png')) {
        if (sizes512) sizes512.remove();
        const icon512 = document.createElement('link');
        icon512.rel = 'icon';
        icon512.setAttribute('sizes', '512x512');
        icon512.type = 'image/png';
        icon512.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(icon512, document.head.firstChild);
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

