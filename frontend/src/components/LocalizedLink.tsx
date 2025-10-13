import React from 'react';
import { Link as RouterLink, LinkProps as RouterLinkProps } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { addLanguageToPath } from '../utils/i18n';

interface LocalizedLinkProps extends Omit<RouterLinkProps, 'to'> {
  to: string;
  children: React.ReactNode;
}

const LocalizedLink: React.FC<LocalizedLinkProps> = ({ to, children, ...props }) => {
  const { language } = useLanguage();
  
  // 为链接添加当前语言前缀
  const localizedTo = addLanguageToPath(to, language);
  
  return (
    <RouterLink to={localizedTo} {...props}>
      {children}
    </RouterLink>
  );
};

export default LocalizedLink;
