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
      
      // 确保路径以/开头，并且移除查询参数（canonical URL不应该包含查询参数）
      const cleanPath = pathname.startsWith('/') ? pathname : `/${pathname}`;
      
      // 移除尾部斜杠（除了根路径）以统一URL格式
      let normalizedPath = cleanPath;
      if (normalizedPath !== '/en' && normalizedPath !== '/zh' && normalizedPath !== '/en/' && normalizedPath !== '/zh/') {
        normalizedPath = normalizedPath.endsWith('/') ? normalizedPath.slice(0, -1) : normalizedPath;
      } else if (normalizedPath === '/en/' || normalizedPath === '/zh/') {
        normalizedPath = normalizedPath.slice(0, -1);
      }
      
      // 构建完整的canonical URL（不包含查询参数）
      canonicalLink.href = `${baseUrl}${normalizedPath}`;
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
