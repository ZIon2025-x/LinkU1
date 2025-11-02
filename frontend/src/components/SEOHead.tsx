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

    // 更新或创建meta标签
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

    // 更新description
    if (description) {
      updateMetaTag('description', description);
    }

    // 更新keywords
    if (keywords) {
      updateMetaTag('keywords', keywords);
    }

    // 更新robots标签
    const robotsContent = noindex ? 'noindex, nofollow' : 'index, follow';
    updateMetaTag('robots', robotsContent);

    // 更新Open Graph标签
    if (ogTitle) {
      updateMetaTag('og:title', ogTitle, true);
    }
    if (ogDescription) {
      updateMetaTag('og:description', ogDescription, true);
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

    // 更新Open Graph图片标签和微信分享标签（微信会优先读取这些标签，如果没有则使用og标签）
    if (ogImage) {
      // 确保og:image是完整URL（微信需要绝对URL），添加版本号避免缓存问题
      const fullOgImage = ogImage.startsWith('http') ? ogImage : `${window.location.origin}${ogImage}${ogImage.includes('?') ? '' : '?v=2'}`;
      
      // 强制移除旧的og:image标签（确保更新）
      const existingOgImage = document.querySelector('meta[property="og:image"]');
      if (existingOgImage) {
        existingOgImage.remove();
      }
      
      // 重新创建og:image标签
      updateMetaTag('og:image', fullOgImage, true);
      updateMetaTag('og:image:width', '1200', true);
      updateMetaTag('og:image:height', '630', true);
      updateMetaTag('og:image:type', 'image/png', true);
      
      // 微信分享图片（完整URL）
      const existingWeixinImage = document.querySelector('meta[name="weixin:image"]');
      if (existingWeixinImage) {
        existingWeixinImage.remove();
      }
      updateMetaTag('weixin:image', fullOgImage);
    }
    if (ogTitle) {
      updateMetaTag('weixin:title', ogTitle);
    }
    if (ogDescription) {
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
    setTimeout(() => {
      if (ogImage) {
        moveToTop('meta[property="og:image"]');
      }
      if (ogTitle) {
        moveToTop('meta[property="og:title"]');
        moveToTop('meta[name="weixin:title"]');
      }
      if (ogDescription) {
        moveToTop('meta[property="og:description"]');
        moveToTop('meta[name="weixin:description"]');
      }
      if (ogImage) {
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
