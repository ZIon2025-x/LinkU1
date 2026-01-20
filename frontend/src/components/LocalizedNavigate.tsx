import type { FC } from 'react';
import { Navigate as RouterNavigate, NavigateProps } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { addLanguageToPath } from '../utils/i18n';

interface LocalizedNavigateProps extends Omit<NavigateProps, 'to'> {
  to: string;
}

const LocalizedNavigate: FC<LocalizedNavigateProps> = ({ to, ...props }) => {
  const { language } = useLanguage();
  
  // 为导航路径添加当前语言前缀
  const localizedTo = addLanguageToPath(to, language);
  
  return <RouterNavigate to={localizedTo} {...props} />;
};

export default LocalizedNavigate;
