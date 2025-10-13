import { useNavigate as useRouterNavigate } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { addLanguageToPath } from '../utils/i18n';

export const useLocalizedNavigation = () => {
  const navigate = useRouterNavigate();
  const { language } = useLanguage();

  const localizedNavigate = (to: string, options?: { replace?: boolean }) => {
    const localizedTo = addLanguageToPath(to, language);
    navigate(localizedTo, options);
  };

  return {
    navigate: localizedNavigate,
    goBack: () => navigate(-1),
    goForward: () => navigate(1),
  };
};
