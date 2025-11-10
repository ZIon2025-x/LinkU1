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
      const allFavicons = document.querySelectorAll("link[rel='icon'], link[rel='shortcut icon'], link[rel='apple-touch-icon'], link[rel='mask-icon']");
      allFavicons.forEach(icon => icon.remove());
      
      // 1.5. 优先设置SVG favicon（现代浏览器优先，可缩放矢量图标）
      const svgFavicon = document.createElement('link');
      svgFavicon.rel = 'icon';
      svgFavicon.type = 'image/svg+xml';
      svgFavicon.href = `${baseUrl}/static/favicon.svg?v=${version}`;
      document.head.insertBefore(svgFavicon, document.head.firstChild);
      
      // 2. 优先设置favicon.ico（搜索引擎和浏览器默认查找的路径，Bing和Google都优先识别.ico格式）
      // 插入到head的最前面，确保优先读取
      // 使用绝对路径，确保搜索引擎能正确识别
      // 首先设置根目录的favicon.ico（搜索引擎默认查找的路径）
      const rootFavicon = document.createElement('link');
      rootFavicon.rel = 'icon';
      rootFavicon.type = 'image/x-icon';
      rootFavicon.href = `${baseUrl}/favicon.ico?v=${version}`;
      document.head.insertBefore(rootFavicon, svgFavicon.nextSibling);
      
      // 然后设置static目录的favicon.ico（作为备选）
      const staticFavicon = document.createElement('link');
      staticFavicon.rel = 'icon';
      staticFavicon.type = 'image/x-icon';
      staticFavicon.href = `${baseUrl}/static/favicon.ico?v=${version}`;
      document.head.insertBefore(staticFavicon, rootFavicon.nextSibling);

      // 3. 设置shortcut icon（旧版浏览器和搜索引擎需要）
      const shortcutIcon = document.createElement('link');
      shortcutIcon.rel = 'shortcut icon';
      shortcutIcon.type = 'image/x-icon';
      shortcutIcon.href = `${baseUrl}/favicon.ico?v=${version}`;
      document.head.insertBefore(shortcutIcon, staticFavicon.nextSibling);
      
      // 3.5. 额外设置一个无sizes的.ico favicon（某些搜索引擎需要）
      const defaultIcoIcon = document.createElement('link');
      defaultIcoIcon.rel = 'icon';
      defaultIcoIcon.type = 'image/x-icon';
      defaultIcoIcon.href = `${baseUrl}/favicon.ico?v=${version}`;
      document.head.insertBefore(defaultIcoIcon, shortcutIcon.nextSibling);

      // 4. 设置所有尺寸的PNG favicon（移动端Chrome和Google需要）
      // 关键尺寸：16x16, 32x32, 192x192, 512x512（移动端Chrome特别需要192x192和512x512）
      // 按优先级排序：先设置关键尺寸，再设置其他尺寸
      const criticalSizes = ['192x192', '512x512', '32x32', '16x16'];
      const otherSizes = ['48x48', '96x96', '128x128', '256x256'];
      
      // 先设置关键尺寸（移动端Chrome优先读取）
      criticalSizes.forEach(size => {
        const sizeLink = document.createElement('link');
        sizeLink.rel = 'icon';
        sizeLink.setAttribute('sizes', size);
        sizeLink.type = 'image/png';
        sizeLink.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(sizeLink, shortcutIcon.nextSibling);
      });
      
      // 再设置其他尺寸
      otherSizes.forEach(size => {
        const sizeLink = document.createElement('link');
        sizeLink.rel = 'icon';
        sizeLink.setAttribute('sizes', size);
        sizeLink.type = 'image/png';
        sizeLink.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.appendChild(sizeLink);
      });

      // 5. 设置Apple Touch Icon（iOS设备需要）- 移动端关键配置
      // iOS设备会优先查找apple-touch-icon，必须使用绝对路径
      const appleIcon = document.createElement('link');
      appleIcon.rel = 'apple-touch-icon';
      appleIcon.href = `${baseUrl}/static/favicon.png?v=${version}`;
      // 设置sizes属性，iOS会优先使用180x180
      appleIcon.setAttribute('sizes', '180x180');
      document.head.insertBefore(appleIcon, document.head.firstChild);
      
      // 5.1. 设置多个尺寸的Apple Touch Icon（确保iOS设备能找到合适的尺寸）
      const appleSizes = ['57x57', '60x60', '72x72', '76x76', '114x114', '120x120', '144x144', '152x152', '180x180'];
      appleSizes.forEach(size => {
        const appleSizeIcon = document.createElement('link');
        appleSizeIcon.rel = 'apple-touch-icon';
        appleSizeIcon.setAttribute('sizes', size);
        appleSizeIcon.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(appleSizeIcon, appleIcon.nextSibling);
      });
      
      // 6. 额外设置一个无sizes的PNG favicon（现代浏览器和移动端需要，作为.ico的备选）
      const defaultPngIcon = document.createElement('link');
      defaultPngIcon.rel = 'icon';
      defaultPngIcon.type = 'image/png';
      defaultPngIcon.href = `${baseUrl}/static/favicon.png?v=${version}`;
      document.head.insertBefore(defaultPngIcon, defaultIcoIcon.nextSibling);
      
      // 7. 设置Safari Mask Icon（Safari浏览器标签页图标）
      const maskIcon = document.createElement('link');
      maskIcon.rel = 'mask-icon';
      maskIcon.href = `${baseUrl}/static/favicon.svg?v=${version}`;
      maskIcon.setAttribute('color', '#1890ff');
      document.head.insertBefore(maskIcon, svgFavicon.nextSibling);
    };

    // 立即执行
    setFavicon();
  }, [location.pathname]);

  // 额外的useEffect，在页面完全加载后再次确保favicon正确
  useEffect(() => {
    const setFaviconOnLoad = () => {
      const baseUrl = window.location.origin;
      const version = Date.now();
      
      // 检查并确保SVG favicon存在（现代浏览器优先）
      let svgFavicon = document.querySelector("link[rel='icon'][type='image/svg+xml']") as HTMLLinkElement;
      if (!svgFavicon || !svgFavicon.href.includes('/static/favicon.svg')) {
        if (svgFavicon) {
          svgFavicon.remove();
        }
        svgFavicon = document.createElement('link');
        svgFavicon.rel = 'icon';
        svgFavicon.type = 'image/svg+xml';
        svgFavicon.href = `${baseUrl}/static/favicon.svg?v=${version}`;
        document.head.insertBefore(svgFavicon, document.head.firstChild);
      } else if (!svgFavicon.href.startsWith('http')) {
        svgFavicon.href = `${baseUrl}/static/favicon.svg?v=${version}`;
        document.head.insertBefore(svgFavicon, document.head.firstChild);
      }
      
      // 检查并确保Safari mask-icon存在
      let maskIcon = document.querySelector("link[rel='mask-icon']") as HTMLLinkElement;
      if (!maskIcon || !maskIcon.href.includes('/static/favicon.svg')) {
        if (maskIcon) {
          maskIcon.remove();
        }
        maskIcon = document.createElement('link');
        maskIcon.rel = 'mask-icon';
        maskIcon.href = `${baseUrl}/static/favicon.svg?v=${version}`;
        maskIcon.setAttribute('color', '#1890ff');
        document.head.insertBefore(maskIcon, svgFavicon.nextSibling);
      } else if (!maskIcon.href.startsWith('http')) {
        maskIcon.href = `${baseUrl}/static/favicon.svg?v=${version}`;
        if (!maskIcon.getAttribute('color')) {
          maskIcon.setAttribute('color', '#1890ff');
        }
      }
      
      // 检查并确保favicon.ico在最前面（优先使用根目录的favicon.ico，搜索引擎默认查找的路径）
      let rootFavicon = document.querySelector("link[rel='icon'][type='image/x-icon']") as HTMLLinkElement;
      if (!rootFavicon || (!rootFavicon.href.includes('/favicon.ico') && !rootFavicon.href.includes('/static/favicon.ico'))) {
        // 如果不存在或不正确，重新创建（优先使用根目录）
        if (rootFavicon) {
          rootFavicon.remove();
        }
        rootFavicon = document.createElement('link');
        rootFavicon.rel = 'icon';
        rootFavicon.type = 'image/x-icon';
        rootFavicon.href = `${baseUrl}/favicon.ico?v=${version}`;
        document.head.insertBefore(rootFavicon, document.head.firstChild);
      } else if (!rootFavicon.href.startsWith('http')) {
        // 如果存在但不是绝对路径，更新为绝对路径（优先使用根目录）
        if (rootFavicon.href.includes('/favicon.ico')) {
          rootFavicon.href = `${baseUrl}/favicon.ico?v=${version}`;
        } else {
          rootFavicon.href = `${baseUrl}/static/favicon.ico?v=${version}`;
        }
        document.head.insertBefore(rootFavicon, document.head.firstChild);
      }
      
      // 确保192x192和512x512存在（Google移动端关键尺寸）
      // 移动端Chrome特别需要这两个尺寸，且必须是绝对路径
      const sizes192 = document.querySelector("link[rel='icon'][sizes='192x192']") as HTMLLinkElement;
      const sizes512 = document.querySelector("link[rel='icon'][sizes='512x512']") as HTMLLinkElement;
      
      if (!sizes192 || !sizes192.href.includes('/static/favicon.png') || !sizes192.href.startsWith('http')) {
        if (sizes192) sizes192.remove();
        const icon192 = document.createElement('link');
        icon192.rel = 'icon';
        icon192.setAttribute('sizes', '192x192');
        icon192.type = 'image/png';
        icon192.href = `${baseUrl}/static/favicon.png?v=${version}`;
        // 插入到head最前面，确保移动端Chrome能优先读取
        document.head.insertBefore(icon192, document.head.firstChild);
      } else if (!sizes192.href.startsWith('http')) {
        // 如果存在但不是绝对路径，更新为绝对路径
        sizes192.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(sizes192, document.head.firstChild);
      }
      
      if (!sizes512 || !sizes512.href.includes('/static/favicon.png') || !sizes512.href.startsWith('http')) {
        if (sizes512) sizes512.remove();
        const icon512 = document.createElement('link');
        icon512.rel = 'icon';
        icon512.setAttribute('sizes', '512x512');
        icon512.type = 'image/png';
        icon512.href = `${baseUrl}/static/favicon.png?v=${version}`;
        // 插入到head最前面，确保移动端Chrome能优先读取
        document.head.insertBefore(icon512, document.head.firstChild);
      } else if (!sizes512.href.startsWith('http')) {
        // 如果存在但不是绝对路径，更新为绝对路径
        sizes512.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(sizes512, document.head.firstChild);
      }
      
      // 确保Apple Touch Icon使用绝对路径（移动端iOS关键配置）
      const appleTouchIcons = document.querySelectorAll("link[rel='apple-touch-icon']") as NodeListOf<HTMLLinkElement>;
      appleTouchIcons.forEach(icon => {
        if (!icon.href.startsWith('http')) {
          icon.href = `${baseUrl}/static/favicon.png?v=${version}`;
        } else if (!icon.href.includes('?v=')) {
          // 如果已有绝对路径但没有版本号，添加版本号避免缓存
          icon.href = `${icon.href.split('?')[0]}?v=${version}`;
        }
      });
      
      // 如果没有任何apple-touch-icon，创建一个默认的
      if (appleTouchIcons.length === 0) {
        const defaultAppleIcon = document.createElement('link');
        defaultAppleIcon.rel = 'apple-touch-icon';
        defaultAppleIcon.href = `${baseUrl}/static/favicon.png?v=${version}`;
        document.head.insertBefore(defaultAppleIcon, document.head.firstChild);
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

