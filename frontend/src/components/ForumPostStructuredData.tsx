import type React from 'react';

interface ForumPostStructuredDataProps {
  post: {
    id: number;
    title: string;
    content: string;
    author: {
      id: string;
      name: string;
    };
    created_at: string;
    updated_at?: string;
    view_count?: number;  // 浏览量（前端负责格式化显示）
    like_count?: number;
    category?: string;
  };
  language: string;
}

const ForumPostStructuredData: React.FC<ForumPostStructuredDataProps> = ({ post, language }) => {
  // 格式化日期为 ISO 8601
  const formatISO8601 = (dateString?: string): string | undefined => {
    if (!dateString) return undefined;
    try {
      return new Date(dateString).toISOString();
    } catch {
      return undefined;
    }
  };

  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": post.title,
    "description": post.content.replace(/<[^>]*>/g, '').slice(0, 200),
    "author": {
      "@type": "Person",
      "name": post.author.name,
      "url": `https://www.link2ur.com/${language}/user/${post.author.id}`
    },
    "publisher": {
      "@type": "Organization",
      "name": "Link²Ur",
      "logo": {
        "@type": "ImageObject",
        "url": "https://www.link2ur.com/static/logo.png"
      }
    },
    "datePublished": formatISO8601(post.created_at),
    "dateModified": formatISO8601(post.updated_at || post.created_at),
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": `https://www.link2ur.com/${language}/forum/post/${post.id}`
    },
    "url": `https://www.link2ur.com/${language}/forum/post/${post.id}`,
    "articleSection": post.category || "Forum",
    "interactionStatistic": [
      {
        "@type": "InteractionCounter",
        "interactionType": "https://schema.org/ViewAction",
        "userInteractionCount": post.view_count || 0
      },
      {
        "@type": "InteractionCounter",
        "interactionType": "https://schema.org/LikeAction",
        "userInteractionCount": post.like_count || 0
      }
    ]
  };

  // 移除 undefined 字段
  const cleanedData = JSON.parse(JSON.stringify(structuredData));

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(cleanedData, null, 2) }}
    />
  );
};

export default ForumPostStructuredData;

