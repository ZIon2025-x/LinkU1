import type React from 'react';
import { useLocation, Navigate } from 'react-router-dom';
import { DEFAULT_LANGUAGE } from '../utils/i18n';

interface QueryPreservingRedirectProps {
  to: string;
}

/**
 * 重定向组件，保留URL查询参数
 */
const QueryPreservingRedirect: React.FC<QueryPreservingRedirectProps> = ({ to }) => {
  const location = useLocation();
  
  // 保留查询参数
  const search = location.search;
  const redirectPath = `${to}${search}`;
  
  return <Navigate to={redirectPath} replace />;
};

export default QueryPreservingRedirect;

