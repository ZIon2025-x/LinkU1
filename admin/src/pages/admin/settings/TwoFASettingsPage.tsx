import React from 'react';
import { useNavigate } from 'react-router-dom';
import TwoFactorAuthSettings from '../../../components/TwoFactorAuthSettings';

/**
 * 2FA 设置页：包装已有 Modal 组件，通过路由 /admin/2fa 打开，关闭时返回设置页。
 */
const TwoFASettingsPage: React.FC = () => {
  const navigate = useNavigate();
  return (
    <TwoFactorAuthSettings
      visible
      onClose={() => navigate('/admin/settings')}
    />
  );
};

export default TwoFASettingsPage;
