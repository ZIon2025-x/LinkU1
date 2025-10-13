import React from 'react';
import { useParams, Navigate } from 'react-router-dom';
import { DEFAULT_LANGUAGE } from '../utils/i18n';

const UserProfileRedirect: React.FC = () => {
  const { userId } = useParams<{ userId: string }>();
  
  if (!userId) {
    // 如果没有userId参数，重定向到首页
    return <Navigate to={`/${DEFAULT_LANGUAGE}`} replace />;
  }
  
  // 重定向到带语言前缀的用户主页
  return <Navigate to={`/${DEFAULT_LANGUAGE}/user/${userId}`} replace />;
};

export default UserProfileRedirect;
