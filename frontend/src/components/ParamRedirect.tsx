import React from 'react';
import { useParams, Navigate } from 'react-router-dom';
import { DEFAULT_LANGUAGE } from '../utils/i18n';

interface ParamRedirectProps {
  basePath: string;
  fallbackPath?: string;
}

const ParamRedirect: React.FC<ParamRedirectProps> = ({ basePath, fallbackPath = `/${DEFAULT_LANGUAGE}` }) => {
  const params = useParams();
  
  // 构建重定向路径，包含所有参数
  const paramString = Object.entries(params)
    .map(([key, value]) => `${key}=${value}`)
    .join('&');
  
  if (paramString) {
    // 如果有参数，构建完整的重定向路径
    const redirectPath = `/${DEFAULT_LANGUAGE}${basePath}`.replace(/:(\w+)/g, (match, paramName) => {
      return params[paramName] || match;
    });
    return <Navigate to={redirectPath} replace />;
  }
  
  // 如果没有参数，重定向到fallback路径
  return <Navigate to={fallbackPath} replace />;
};

export default ParamRedirect;
