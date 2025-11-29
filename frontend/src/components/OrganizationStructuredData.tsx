import React from 'react';

/**
 * OrganizationStructuredData - 全局组织信息结构化数据
 * 应该在 App.tsx 或 Home.tsx 中使用，确保所有页面都能访问
 * 这将帮助搜索引擎识别网站的品牌信息，提升富媒体搜索结果展示
 */
const OrganizationStructuredData: React.FC = () => {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": "Link²Ur",
    "alternateName": "Link2Ur",
    "url": "https://www.link2ur.com/",
    "logo": "https://www.link2ur.com/static/favicon.png",
    "description": "Professional task publishing and skill matching platform, connecting skilled people with those who need help, making value creation more efficient.",
    "contactPoint": {
      "@type": "ContactPoint",
      "contactType": "customer service",
      "url": "https://www.link2ur.com/contact"
    },
    "sameAs": [
      "https://www.link2ur.com/"
    ],
    "foundingDate": "2024", // 可以根据实际情况调整
    "address": {
      "@type": "PostalAddress",
      "addressCountry": "GB"
    }
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData, null, 2) }}
    />
  );
};

export default OrganizationStructuredData;

