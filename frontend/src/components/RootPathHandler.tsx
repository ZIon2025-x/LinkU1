import React from 'react';
import { Navigate } from 'react-router-dom';
import { detectBrowserLanguage, DEFAULT_LANGUAGE, addLanguageToPath } from '../utils/i18n';

/**
 * 根路径处理器
 * 使用服务器端重定向（Navigate 组件），而不是客户端重定向
 * 这样搜索引擎可以跟随重定向并索引目标页面
 */
const RootPathHandler: React.FC = () => {
  // 检测浏览器语言
  const browserLanguage = detectBrowserLanguage();
  const targetPath = addLanguageToPath('/', browserLanguage);
  
  // 使用 Navigate 组件进行服务器端重定向
  // 这比 window.location.replace 更有利于 SEO
  return <Navigate to={targetPath} replace />;
};

export default RootPathHandler;

