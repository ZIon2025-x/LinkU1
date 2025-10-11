import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { fetchCurrentUser, logout } from '../api';

const TermsOfService: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error) {
        setUser(null);
      }
    };
    loadUser();
  }, []);

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      {/* 顶部导航栏 */}
      <header style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        background: '#fff',
        zIndex: 100,
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        borderBottom: '1px solid #e9ecef'
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          height: 60,
          maxWidth: 1200,
          margin: '0 auto',
          padding: '0 24px'
        }}>
          {/* Logo */}
          <div 
            style={{
              fontWeight: 'bold',
              fontSize: 24,
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer'
            }}
            onClick={() => navigate('/')}
          >
            Link²Ur
          </div>
          
          {/* 语言切换器和汉堡菜单 */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <LanguageSwitcher />
            <HamburgerMenu
              user={user}
              onLogout={async () => {
                try {
                  await logout();
                } catch (error) {
                  console.log('登出请求失败:', error);
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={{}}
            />
          </div>
        </div>
      </header>

      {/* 主要内容 */}
      <div style={{ paddingTop: '80px', paddingBottom: '40px' }}>
        <div style={{
          maxWidth: 800,
          margin: '0 auto',
          padding: '0 24px'
        }}>
          {/* 页面标题 */}
          <div style={{
            textAlign: 'center',
            marginBottom: '40px',
            padding: '40px 0'
          }}>
            <h1 style={{
              fontSize: '2.5rem',
              fontWeight: '800',
              color: '#1e293b',
              marginBottom: '16px',
              background: 'linear-gradient(135deg, #667eea, #764ba2)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}>
              {t('termsOfService.title')}
            </h1>
            <div style={{
              fontSize: '1rem',
              color: '#64748b',
              margin: 0,
              lineHeight: '1.6'
            }}>
              <p style={{ margin: '4px 0' }}>{t('termsOfService.version')}</p>
              <p style={{ margin: '4px 0' }}>{t('termsOfService.effectiveDate')}</p>
              <p style={{ margin: '4px 0' }}>{t('termsOfService.jurisdiction')}</p>
            </div>
          </div>

          {/* 协议内容 */}
          <div style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '40px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.05)',
            lineHeight: '1.8'
          }}>
            <div style={{ color: '#374151', fontSize: '1rem' }}>
              {/* 主体信息 */}
              <div style={{
                marginBottom: '32px',
                padding: '20px',
                backgroundColor: '#f8f9fa',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                <h3 style={{ color: '#1e293b', fontSize: '1.3rem', marginBottom: '16px' }}>
                  {t('termsOfService.operatorInfo')}
                </h3>
                <p style={{ marginBottom: '8px' }}>{t('termsOfService.operator')}</p>
                <p style={{ margin: 0 }}>{t('termsOfService.contact')}</p>
              </div>

              {/* 1. 服务性质 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.serviceNature.title')}
              </h2>
              <p>{t('termsOfService.serviceNature.content')}</p>

              {/* 2. 用户类型与资格 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.userTypes.title')}
              </h2>
              <p>{t('termsOfService.userTypes.content')}</p>
              <p>{t('termsOfService.userTypes.userTypes')}</p>

              {/* 3. 平台定位与站外交易 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.platformPosition.title')}
              </h2>
              <p>{t('termsOfService.platformPosition.content')}</p>
              <p>{t('termsOfService.platformPosition.offPlatform')}</p>

              {/* 4. 费用与平台规则 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.feesAndRules.title')}
              </h2>
              <p>{t('termsOfService.feesAndRules.content')}</p>
              <p>{t('termsOfService.feesAndRules.reviews')}</p>

              {/* 5. 用户行为与禁止事项 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.userBehavior.title')}
              </h2>
              <p>{t('termsOfService.userBehavior.prohibited')}</p>
              <p>{t('termsOfService.userBehavior.consequences')}</p>

              {/* 6. 知识产权与用户内容 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.intellectualProperty.title')}
              </h2>
              <p>{t('termsOfService.intellectualProperty.platformRights')}</p>
              <p>{t('termsOfService.intellectualProperty.userContent')}</p>
              <p>{t('termsOfService.intellectualProperty.complaints')}</p>

              {/* 7. 隐私与数据 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.privacyData.title')}
              </h2>
              <p>{t('termsOfService.privacyData.controller')}</p>
              <p>{t('termsOfService.privacyData.payments')}</p>

              {/* 8. 免责声明与责任限制 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.disclaimer.title')}
              </h2>
              <p>{t('termsOfService.disclaimer.service')}</p>
              <p>{t('termsOfService.disclaimer.liability')}</p>
              <p>{t('termsOfService.disclaimer.limit')}</p>

              {/* 9. 终止与数据保留 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.termination.title')}
              </h2>
              <p>{t('termsOfService.termination.content')}</p>
              <p>{t('termsOfService.termination.effect')}</p>

              {/* 10. 争议与适用法律 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.disputes.title')}
              </h2>
              <p>{t('termsOfService.disputes.negotiation')}</p>
              <p>{t('termsOfService.disputes.law')}</p>

              {/* 消费者条款附录 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {t('termsOfService.consumerAppendix.title')}
              </h2>
              <p>{t('termsOfService.consumerAppendix.freeService')}</p>
              <p>{t('termsOfService.consumerAppendix.futureCharges')}</p>

              <div style={{
                marginTop: '40px',
                padding: '20px',
                backgroundColor: '#f8f9fa',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                <p style={{ margin: 0, fontSize: '0.9rem', color: '#6c757d' }}>
                  <strong>{t('termsOfService.importantNotice')}</strong>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => setShowForgotPasswordModal(true)}
        onHideForgotPassword={() => setShowForgotPasswordModal(false)}
      />
    </div>
  );
};

export default TermsOfService;
