import React from 'react';
import AdminLoginWithVerification from '../components/AdminLoginWithVerification';

const AdminLogin: React.FC = () => {
  return (
    <>
      {/* SEO优化：H1标签，几乎不可见但SEO可检测 */}
      <h1 style={{
        position: 'absolute',
        top: '-100px',
        left: '-100px',
        width: '1px',
        height: '1px',
        padding: '0',
        margin: '0',
        overflow: 'hidden',
        clip: 'rect(0, 0, 0, 0)',
        whiteSpace: 'nowrap',
        border: '0',
        fontSize: '1px',
        color: 'transparent',
        background: 'transparent'
      }}>
        管理员登录
      </h1>
      <AdminLoginWithVerification />
    </>
  );
};

export default AdminLogin;