import React, { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import CanonicalLink from './CanonicalLink';

interface SEOHeadProps {
  title?: string;
  description?: string;
  keywords?: string;
  canonicalUrl?: string;
  ogTitle?: string;
  ogDescription?: string;
  ogImage?: string;
  ogUrl?: string;
  twitterTitle?: string;
  twitterDescription?: string;
  twitterImage?: string;
  noindex?: boolean;
}

const SEOHead: React.FC<SEOHeadProps> = ({
  title,
  description,
  keywords,
  canonicalUrl,
  ogTitle,
  ogDescription,
  ogImage,
  ogUrl,
  twitterTitle,
  twitterDescription,
  twitterImage,
  noindex = false
}) => {
  const location = useLocation();

  useEffect(() => {
    // 更新页面标题
    if (title) {
      document.title = title;
    }

    // 更新或创建meta标签（只清理带有 data-seo-head 属性的标签）
    const updateMetaTag = (name: string, content: string, property?: boolean) => {
      const selector = property ? `meta[property="${name}"]` : `meta[name="${name}"]`;
      // 先清理所有带有 data-seo-head 属性的同名标签
      const existingTags = document.querySelectorAll(`${selector}[data-seo-head="true"]`);
      existingTags.forEach(tag => tag.remove());
      
      let metaTag = document.querySelector(selector) as HTMLMetaElement;
      
      if (!metaTag) {
        metaTag = document.createElement('meta');
        if (property) {
          metaTag.setAttribute('property', name);
        } else {
          metaTag.setAttribute('name', name);
        }
        // 添加 data-seo-head 属性，标识这是 SEOHead 组件创建的标签
        metaTag.setAttribute('data-seo-head', 'true');
        document.head.appendChild(metaTag);
      } else {
        // 如果标签已存在，确保添加 data-seo-head 属性
        metaTag.setAttribute('data-seo-head', 'true');
      }
      
      metaTag.content = content;
    };

    // 更新或创建link标签
    const updateLinkTag = (rel: string, href: string, hreflang?: string) => {
      let selector = `link[rel="${rel}"]`;
      if (hreflang) {
        selector += `[hreflang="${hreflang}"]`;
      }
      
      let linkTag = document.querySelector(selector) as HTMLLinkElement;
      
      if (!linkTag) {
        linkTag = document.createElement('link');
        linkTag.rel = rel;
        if (hreflang) {
          linkTag.setAttribute('hreflang', hreflang);
        }
        document.head.appendChild(linkTag);
      }
      
      linkTag.href = href;
    };

    // 更新description - 确保在head最前面，优先被搜索引擎读取
    if (description) {
      // 先移除所有带有 data-seo-head 属性的旧description标签
      const allDescriptions = document.querySelectorAll('meta[name="description"][data-seo-head="true"]');
      allDescriptions.forEach(tag => tag.remove());
      
      // 创建新的description标签并插入到head最前面
      const descTag = document.createElement('meta');
      descTag.name = 'description';
      descTag.content = description;
      descTag.setAttribute('data-seo-head', 'true');
      document.head.insertBefore(descTag, document.head.firstChild);
    }

    // 更新keywords
    if (keywords) {
      updateMetaTag('keywords', keywords);
    }

    // 更新robots标签
    const robotsContent = noindex ? 'noindex, nofollow' : 'index, follow';
    updateMetaTag('robots', robotsContent);

    // 更新Open Graph标签 - 确保在head最前面，优先被搜索引擎读取
    if (ogTitle) {
      // 先移除所有带有 data-seo-head 属性的旧og:title标签
      const allOgTitles = document.querySelectorAll('meta[property="og:title"][data-seo-head="true"]');
      allOgTitles.forEach(tag => tag.remove());
      
      // 创建新的og:title标签并插入到head最前面
      const ogTitleTag = document.createElement('meta');
      ogTitleTag.setAttribute('property', 'og:title');
      ogTitleTag.content = ogTitle;
      ogTitleTag.setAttribute('data-seo-head', 'true');
      document.head.insertBefore(ogTitleTag, document.head.firstChild);
    }
    if (ogDescription) {
      // 先移除所有带有 data-seo-head 属性的旧og:description标签
      const allOgDescriptions = document.querySelectorAll('meta[property="og:description"][data-seo-head="true"]');
      allOgDescriptions.forEach(tag => tag.remove());
      
      // 创建新的og:description标签并插入到head最前面
      const ogDescTag = document.createElement('meta');
      ogDescTag.setAttribute('property', 'og:description');
      ogDescTag.content = ogDescription;
      ogDescTag.setAttribute('data-seo-head', 'true');
      document.head.insertBefore(ogDescTag, document.head.firstChild);
    }
    // ogImage的处理移到后面，确保转换为完整URL并添加微信标签
    if (ogUrl) {
      updateMetaTag('og:url', ogUrl, true);
    }

    // 更新Twitter标签
    if (twitterTitle) {
      updateMetaTag('twitter:title', twitterTitle);
    }
    if (twitterDescription) {
      updateMetaTag('twitter:description', twitterDescription);
    }
    if (twitterImage) {
      updateMetaTag('twitter:image', twitterImage);
    }

    // og:image 强制校验和 fallback
    const isValidOgImage = (imageUrl: string): boolean => {
      // 简化版：检查 URL 是否包含已知的大图标识
      // 实际项目中可以异步加载图片检查尺寸
      return imageUrl.includes('og-') || imageUrl.includes('1200x630') || imageUrl.includes('og-default');
    };
    
    // 检查是否是榜单详情页（URL格式：/leaderboard/custom/数字）
    // 对于榜单详情页，useLayoutEffect 会管理微信标签，SEOHead 不覆盖
    const isLeaderboardDetailPage = /\/leaderboard\/custom\/\d+/.test(window.location.pathname);
    
    if (isLeaderboardDetailPage) {
      // 跳过图片设置，让 useLayoutEffect 管理
    }
    
    // 更新Open Graph图片标签和微信分享标签（微信会优先读取这些标签，如果没有则使用og标签）
    // 对于榜单详情页，不设置 og:image 和 weixin:image，让 useLayoutEffect 来管理
    if (ogImage && !isLeaderboardDetailPage) {
      // 确保og:image是完整URL（微信需要绝对URL）
      let fullOgImage = ogImage.startsWith('http') ? ogImage : `${window.location.origin}${ogImage}`;
      
      // 对于其他页面，如果图片尺寸太小，才 fallback 到默认大图
      if (!isValidOgImage(fullOgImage)) {
        fullOgImage = 'https://www.link2ur.com/static/og-default.jpg'; // 1200×630 的默认图
      }
      
      // 添加版本号避免缓存问题
      fullOgImage = fullOgImage.includes('?') ? fullOgImage : `${fullOgImage}?v=2`;
      
      // 强制移除旧的og:image标签（确保更新）
      const existingOgImage = document.querySelector('meta[property="og:image"][data-seo-head="true"]');
      if (existingOgImage) {
        existingOgImage.remove();
      }
      
      // 重新创建og:image标签
      updateMetaTag('og:image', fullOgImage, true);
      updateMetaTag('og:image:width', '1200', true);
      updateMetaTag('og:image:height', '630', true);
      updateMetaTag('og:image:type', 'image/png', true);
      
      // 微信分享图片（完整URL）
      const existingWeixinImage = document.querySelector('meta[name="weixin:image"][data-seo-head="true"]');
      if (existingWeixinImage) {
        existingWeixinImage.remove();
      }
      updateMetaTag('weixin:image', fullOgImage);
    }
    if (ogTitle && !isLeaderboardDetailPage) {
      // 对于榜单详情页，不设置微信标签，让 useLayoutEffect 来管理
      updateMetaTag('weixin:title', ogTitle);
    }
    if (ogDescription && !isLeaderboardDetailPage) {
      // 对于榜单详情页，不设置微信标签，让 useLayoutEffect 来管理
      updateMetaTag('weixin:description', ogDescription);
    }
    
    // 添加微信友好的Open Graph标签
    updateMetaTag('og:site_name', 'Link²Ur', true);
    updateMetaTag('og:locale', 'zh_CN', true);

    // 更新 hreflang 标签 - 基于当前路径生成不同语言版本的 URL
    const currentPath = location.pathname;
    const currentBasePath = currentPath === '/' ? '' : currentPath.replace(/^\/(en|zh)/, '');
    
    // 生成各种语言版本的 URL
    const enUrl = `https://www.link2ur.com/en${currentBasePath}`;
    const zhUrl = `https://www.link2ur.com/zh${currentBasePath}`;
    
    updateLinkTag('alternate', enUrl, 'en');
    updateLinkTag('alternate', zhUrl, 'zh');
    updateLinkTag('alternate', enUrl, 'x-default');

    // 微信分享特殊处理：将重要的meta标签移动到head的前面（确保微信爬虫能读取到）
    // 微信爬虫可能只读取head的前几个标签
    const moveToTop = (selector: string) => {
      const element = document.querySelector(selector);
      if (element && element.parentNode) {
        const head = document.head;
        const firstChild = head.firstChild;
        if (firstChild && element !== firstChild) {
          head.insertBefore(element, firstChild);
        }
      }
    };
    
    // 将关键标签移到前面（使用setTimeout确保DOM已更新）
    // 确保description和og:description在最前面，防止搜索引擎抓取页面内容
    setTimeout(() => {
      if (description) {
        moveToTop('meta[name="description"]');
      }
      if (ogDescription) {
        moveToTop('meta[property="og:description"]');
        moveToTop('meta[name="weixin:description"]');
      }
      if (ogTitle) {
        moveToTop('meta[property="og:title"]');
        moveToTop('meta[name="weixin:title"]');
      }
      if (ogImage) {
        moveToTop('meta[property="og:image"]');
        moveToTop('meta[name="weixin:image"]');
      }
    }, 0);

  }, [title, description, keywords, ogTitle, ogDescription, ogImage, ogUrl, twitterTitle, twitterDescription, twitterImage, noindex, location.pathname]);

  return (
    <>
      <CanonicalLink url={canonicalUrl} />
    </>
  );
};

export default SEOHead;
