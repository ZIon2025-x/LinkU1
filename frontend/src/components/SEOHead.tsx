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
    if (ogImage) {
      updateMetaTag('og:image', ogImage, true);
    }
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

  }, [title, description, keywords, ogTitle, ogDescription, ogImage, ogUrl, twitterTitle, twitterDescription, twitterImage, noindex]);

  return (
    <>
      <CanonicalLink url={canonicalUrl} />
    </>
  );
};

export default SEOHead;
