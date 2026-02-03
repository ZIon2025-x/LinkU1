import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import HamburgerMenu from '../components/HamburgerMenu';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { fetchCurrentUser, logout, getLegalDocument } from '../api';

const TermsOfService: React.FC = () => {
  const navigate = useNavigate();
  const { t, language } = useLanguage();
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [content, setContent] = useState<Record<string, unknown> | null>(null);

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

  useEffect(() => {
    const load = async () => {
      const doc = await getLegalDocument('terms', language);
      setContent(doc?.content_json && Object.keys(doc.content_json).length > 0 ? (doc.content_json as Record<string, unknown>) : null);
    };
    load();
  }, [language]);

  const getContent = (path: string) => {
    const v = path.split('.').reduce((o: unknown, k: string) => (o != null && typeof o === 'object' ? (o as Record<string, unknown>)[k] : undefined), content);
    return (typeof v === 'string' ? v : null) ?? t(`termsOfService.${path}`);
  };

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
              {getContent('title')}
            </h1>
            <div style={{
              fontSize: '1rem',
              color: '#64748b',
              margin: 0,
              lineHeight: '1.6'
            }}>
              <p style={{ margin: '4px 0' }}>{getContent('version')}</p>
              <p style={{ margin: '4px 0' }}>{getContent('effectiveDate')}</p>
              <p style={{ margin: '4px 0' }}>{getContent('jurisdiction')}</p>
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
                  {getContent('operatorInfo')}
                </h3>
                <p style={{ marginBottom: '8px' }}>{getContent('operator')}</p>
                <p style={{ margin: 0 }}>{getContent('contact')}</p>
              </div>

              {/* 1. 服务性质 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('serviceNature.title')}
              </h2>
              <p>{getContent('serviceNature.content')}</p>
              <p style={{ color: '#dc2626', fontWeight: '600', backgroundColor: '#fef2f2', padding: '12px', borderRadius: '6px', border: '1px solid #fecaca' }}>
                {getContent('serviceNature.testingPhase')}
              </p>
              <p>{getContent('serviceNature.paymentSystem')}</p>
              <p>{getContent('serviceNature.recommendationSystem')}</p>

              {/* 2. 用户类型与资格 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('userTypes.title')}
              </h2>
              <p>{getContent('userTypes.content')}</p>
              <p>{getContent('userTypes.userTypes')}</p>
              <p style={{ color: '#dc2626', fontWeight: '600', backgroundColor: '#fef2f2', padding: '12px', borderRadius: '6px', border: '1px solid #fecaca', marginTop: '12px' }}>
                {getContent('userTypes.workEligibility')}
              </p>

              {/* 3. 平台定位与站外交易 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('platformPosition.title')}
              </h2>
              <p>{getContent('platformPosition.content')}</p>
              <p>{getContent('platformPosition.offPlatform')}</p>
              <p style={{ color: '#dc2626', fontWeight: '600', backgroundColor: '#fef2f2', padding: '12px', borderRadius: '6px', border: '1px solid #fecaca' }}>
                {getContent('platformPosition.employmentStatus')}
              </p>
              <p style={{ color: '#dc2626', fontWeight: '600', backgroundColor: '#fef2f2', padding: '12px', borderRadius: '6px', border: '1px solid #fecaca' }}>
                {getContent('platformPosition.offlineTransactions')}
              </p>
              <p style={{ marginTop: '16px', whiteSpace: 'pre-line' }}>{getContent('platformPosition.scopeOfServices')}</p>

              {/* 4. 费用与平台规则 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('feesAndRules.title')}
              </h2>
              <p>{getContent('feesAndRules.content')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('feesAndRules.applicationFee')}</p>
              <p>{getContent('feesAndRules.paymentProcessing')}</p>
              <p>{getContent('feesAndRules.reviews')}</p>

              {/* 4.1 积分规则 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('pointsRules.title')}
              </h2>
              <p>{getContent('pointsRules.intro')}</p>
              <p style={{ marginTop: '12px' }}>{getContent('pointsRules.earn')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('pointsRules.use')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('pointsRules.expire')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('pointsRules.value')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('pointsRules.adjust')}</p>

              {/* 4.2 优惠券规则 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('couponRules.title')}
              </h2>
              <p>{getContent('couponRules.intro')}</p>
              <p style={{ marginTop: '12px' }}>{getContent('couponRules.claim')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('couponRules.use')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('couponRules.type')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('couponRules.refund')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('couponRules.prohibit')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('couponRules.adjust')}</p>

              {/* 5. 支付与退款 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('paymentAndRefund.title')}
              </h2>
              <p>{getContent('paymentAndRefund.paymentMethod')}</p>
              <p>{getContent('paymentAndRefund.paymentProcess')}</p>
              <p>{getContent('paymentAndRefund.escrowService')}</p>
              <p style={{ fontWeight: '600', marginTop: '20px' }}>{getContent('paymentAndRefund.guaranteePayment')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('paymentAndRefund.guaranteePaymentIntro')}</p>
              <p style={{ marginTop: '8px', whiteSpace: 'pre-line' }}>{getContent('paymentAndRefund.guaranteeWhat')}</p>
              <p style={{ marginTop: '8px', whiteSpace: 'pre-line' }}>{getContent('paymentAndRefund.guaranteeWhatNot')}</p>
              <p style={{ marginTop: '8px', whiteSpace: 'pre-line' }}>{getContent('paymentAndRefund.fundReleaseConditions')}</p>
              <p style={{ fontWeight: '600', marginTop: '16px' }}>{getContent('paymentAndRefund.completionConfirmation')}</p>
              <p style={{ marginTop: '12px' }}>{getContent('paymentAndRefund.refundBeforeConfirmation')}</p>
              <p style={{ marginTop: '12px' }}>{getContent('paymentAndRefund.appealAfterConfirmation')}</p>
              <p style={{ marginTop: '12px', fontWeight: '600' }}>{getContent('paymentAndRefund.refundDispute')}</p>
              <p style={{ marginTop: '8px', whiteSpace: 'pre-line' }}>{getContent('paymentAndRefund.refundDisputeDetails')}</p>
              <p style={{ marginTop: '12px', fontWeight: '600' }}>{getContent('paymentAndRefund.refundProcessing')}</p>
              <p style={{ marginTop: '8px', whiteSpace: 'pre-line' }}>{getContent('paymentAndRefund.refundProcessingDetails')}</p>
              <p style={{ marginTop: '12px', fontWeight: '600' }}>{getContent('paymentAndRefund.chargeback')}</p>
              <p style={{ marginTop: '8px', whiteSpace: 'pre-line' }}>{getContent('paymentAndRefund.chargebackDetails')}</p>
              <p style={{ color: '#dc2626', fontWeight: '600', backgroundColor: '#fef2f2', padding: '12px', borderRadius: '6px', border: '1px solid #fecaca', marginTop: '16px' }}>
                {getContent('paymentAndRefund.refundWarning')}
              </p>
              <p style={{ marginTop: '12px' }}>{getContent('paymentAndRefund.paymentSecurity')}</p>

              {/* 6. 禁止的任务类型 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('prohibitedTasks.title')}
              </h2>
              <p>{getContent('prohibitedTasks.introduction')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('prohibitedTasks.illegalActivities')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('prohibitedTasks.illegalActivitiesList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('prohibitedTasks.harmfulContent')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('prohibitedTasks.harmfulContentList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('prohibitedTasks.fraudulentServices')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('prohibitedTasks.fraudulentServicesList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('prohibitedTasks.regulatedServices')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('prohibitedTasks.regulatedServicesList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('prohibitedTasks.platformAbuse')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('prohibitedTasks.platformAbuseList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('prohibitedTasks.otherProhibited')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('prohibitedTasks.otherProhibitedList')}</p>
              <p style={{ marginTop: '12px' }}>{getContent('prohibitedTasks.enforcement')}</p>

              {/* 7. 用户行为与禁止事项 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('userBehavior.title')}
              </h2>
              <p>{getContent('userBehavior.prohibited')}</p>
              <p>{getContent('userBehavior.consequences')}</p>
              <p style={{ color: '#dc2626', fontWeight: '600', backgroundColor: '#fef2f2', padding: '12px', borderRadius: '6px', border: '1px solid #fecaca', marginTop: '12px' }}>
                {getContent('userBehavior.accountSuspension')}
              </p>

              {/* 8. 用户责任与义务 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('userResponsibilities.title')}
              </h2>
              <p>{getContent('userResponsibilities.introduction')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('userResponsibilities.accountSecurity')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('userResponsibilities.accountSecurityList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('userResponsibilities.accurateInformation')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('userResponsibilities.accurateInformationList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('userResponsibilities.legalCompliance')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('userResponsibilities.legalComplianceList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('userResponsibilities.disputeResolution')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('userResponsibilities.disputeResolutionList')}</p>
              <p style={{ fontWeight: '600', marginTop: '8px' }}>{getContent('userResponsibilities.consequences')}</p>
              <p style={{ whiteSpace: 'pre-line' }}>{getContent('userResponsibilities.consequencesDetails')}</p>

              {/* 9. 知识产权与用户内容 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('intellectualProperty.title')}
              </h2>
              <p>{getContent('intellectualProperty.platformRights')}</p>
              <p>{getContent('intellectualProperty.userContent')}</p>
              <p>{getContent('intellectualProperty.complaints')}</p>

              {/* 10. 隐私与数据 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('privacyData.title')}
              </h2>
              <p>{getContent('privacyData.controller')}</p>
              <p>{getContent('privacyData.payments')}</p>

              {/* 11. 免责声明与责任限制 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('disclaimer.title')}
              </h2>
              <p>{getContent('disclaimer.service')}</p>
              <p>{getContent('disclaimer.liability')}</p>
              <p>{getContent('disclaimer.limit')}</p>

              {/* 12. 终止与数据保留 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('termination.title')}
              </h2>
              <p>{getContent('termination.content')}</p>
              <p>{getContent('termination.effect')}</p>

              {/* 13. 争议与适用法律 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('disputes.title')}
              </h2>
              <p>{getContent('disputes.negotiation')}</p>
              <p style={{ fontWeight: '600', marginTop: '16px' }}>{getContent('disputes.disputeArbitration')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('disputes.whoCanSubmit')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('disputes.howToSubmit')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('disputes.platformMediation')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('disputes.platformDecision')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('disputes.decisionFactors')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('disputes.decisionBinding')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('disputes.legalRemedy')}</p>
              <p style={{ marginTop: '16px' }}>{getContent('disputes.law')}</p>

              {/* 论坛服务条款 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('forumTerms.title')}
              </h2>
              <p>{getContent('forumTerms.intro')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('forumTerms.contentResponsibility')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('forumTerms.moderation')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('forumTerms.conduct')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('forumTerms.disclaimer')}</p>

              {/* 跳蚤市场服务条款 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('fleaMarketTerms.title')}
              </h2>
              <p>{getContent('fleaMarketTerms.intro')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('fleaMarketTerms.platformPosition')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('fleaMarketTerms.sellerResponsibility')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('fleaMarketTerms.riskNotice')}</p>
              <p style={{ marginTop: '8px' }}>{getContent('fleaMarketTerms.disclaimer')}</p>

              {/* 消费者条款附录 */}
              <h2 style={{ color: '#1e293b', fontSize: '1.5rem', marginBottom: '20px', marginTop: '32px' }}>
                {getContent('consumerAppendix.title')}
              </h2>
              <p>{getContent('consumerAppendix.freeService')}</p>
              <p>{getContent('consumerAppendix.futureCharges')}</p>

              <div style={{
                marginTop: '40px',
                padding: '20px',
                backgroundColor: '#f8f9fa',
                borderRadius: '8px',
                border: '1px solid #e9ecef'
              }}>
                <p style={{ margin: 0, fontSize: '0.9rem', color: '#6c757d' }}>
                  <strong>{getContent('importantNotice')}</strong>
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
