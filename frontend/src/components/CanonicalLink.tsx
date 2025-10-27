import React, { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

interface CanonicalLinkProps {
  url?: string;
}

const CanonicalLink: React.FC<CanonicalLinkProps> = ({ url }) => {
  const location = useLocation();

  useEffect(() => {
    // 移除现有的canonical链接
    const existingCanonical = document.querySelector('link[rel="canonical"]');
    if (existingCanonical) {
      existingCanonical.remove();
    }

    // 创建新的canonical链接
    const canonicalLink = document.createElement('link');
    canonicalLink.rel = 'canonical';
    
    if (url) {
      canonicalLink.href = url;
    } else {
      // 自动生成canonical URL
      const baseUrl = 'https://www.link2ur.com';
      let pathname = location.pathname;
      
      // 确保有语言前缀
      if (!pathname.startsWith('/en') && !pathname.startsWith('/zh')) {
        // 如果没有语言前缀，添加默认语言
        if (pathname === '/' || pathname === '') {
          pathname = '/en';
        } else {
          pathname = `/en${pathname}`;
        }
      }
      
      // 确保路径以/开头
      const cleanPath = pathname.startsWith('/') ? pathname : `/${pathname}`;
      
      // 构建完整的canonical URL
      canonicalLink.href = `${baseUrl}${cleanPath}`;
    }

    // 添加到head
    document.head.appendChild(canonicalLink);

    // 清理函数
    return () => {
      if (canonicalLink.parentNode) {
        canonicalLink.parentNode.removeChild(canonicalLink);
      }
    };
  }, [location.pathname, url]);

  return null; // 这个组件不渲染任何内容
};

export default CanonicalLink;
