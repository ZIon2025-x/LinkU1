import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import {
  getStudentVerificationStatus,
  submitStudentVerification,
  renewStudentVerification,
  changeStudentEmail,
  getUniversities
} from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { formatUtcToLocal } from '../utils/timeUtils';
import SEOHead from '../components/SEOHead';

// 移动端检测函数
const isMobileDevice = () => {
  const isSmallScreen = window.innerWidth <= 768;
  const isMobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  return isSmallScreen || (isMobileUA && isTouchDevice);
};

interface VerificationStatus {
  is_verified: boolean;
  status: string | null;
  university: {
    id: number;
    name: string;
    name_cn: string;
  } | null;
  email: string | null;
  verified_at: string | null;
  expires_at: string | null;
  days_remaining: number | null;
  can_renew: boolean;
  renewable_from: string | null;
  email_locked: boolean;
  token_expired?: boolean;
}

interface University {
  id: number;
  name: string;
  name_cn: string;
  email_domain: string;
}

const StudentVerification: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [loading, setLoading] = useState(true);
  const [isMobile, setIsMobile] = useState(false);
  const [status, setStatus] = useState<VerificationStatus | null>(null);
  const [email, setEmail] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [universities, setUniversities] = useState<University[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [showUniversityList, setShowUniversityList] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [renewing, setRenewing] = useState(false);
  const [changingEmail, setChangingEmail] = useState(false);
  const [showHelp, setShowHelp] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(true);

  // 移动端检测
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(isMobileDevice());
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // 加载认证状态
  useEffect(() => {
    loadStatus();
  }, []);

  // 自动刷新功能
  useEffect(() => {
    if (!autoRefresh || !status) return;
    
    const interval = setInterval(() => {
      loadStatus();
    }, 30000); // 每30秒刷新一次

    return () => clearInterval(interval);
  }, [autoRefresh, status]);

  // 加载大学列表
  useEffect(() => {
    if (showUniversityList) {
      loadUniversities();
    }
  }, [showUniversityList, searchTerm]);

  const loadStatus = async () => {
    try {
      setLoading(true);
      const response = await getStudentVerificationStatus();
      if (response.code === 200) {
        setStatus(response.data);
        // 如果token过期，显示提示信息
        if (response.data.token_expired) {
          message.warning(t('settings.tokenExpired') || '验证链接已过期，请重新提交认证');
        }
      }
    } catch (error: any) {
      message.error(error?.response?.data?.detail?.message || t('settings.loadingStatus'));
    } finally {
      setLoading(false);
    }
  };

  const loadUniversities = async () => {
    try {
      const response = await getUniversities({
        search: searchTerm || undefined,
        page: 1,
        page_size: 50
      });
      if (response.code === 200) {
        setUniversities(response.data.items || []);
      }
    } catch (error) {
      // 静默处理错误
    }
  };

  const handleSubmit = async () => {
    if (!email.trim()) {
      message.error(t('settings.enterStudentEmail'));
      return;
    }

    if (!email.endsWith('.ac.uk')) {
      message.error(t('settings.invalidEmailFormat'));
      return;
    }

    try {
      setSubmitting(true);
      const response = await submitStudentVerification(email.trim());
      if (response.code === 200) {
        message.success({
          content: t('settings.verificationEmailSent'),
          duration: 3,
          style: {
            marginTop: '20px',
          },
        });
        setEmail('');
        setShowUniversityList(false);
        await loadStatus();
      }
    } catch (error: any) {
      let errorMsg = t('settings.verificationFailed');
      if (error?.response?.data?.detail) {
        if (typeof error.response.data.detail === 'string') {
          errorMsg = error.response.data.detail;
        } else if (error.response.data.detail.message) {
          errorMsg = error.response.data.detail.message;
        } else if (error.response.data.detail.error) {
          errorMsg = error.response.data.detail.error;
        }
      }
      message.error(errorMsg);
    } finally {
      setSubmitting(false);
    }
  };

  const handleRenew = async () => {
    if (!status?.email) {
      message.error(t('settings.enterStudentEmail'));
      return;
    }

    try {
      setRenewing(true);
      const response = await renewStudentVerification(status.email);
      if (response.code === 200) {
        message.success({
          content: t('settings.verificationEmailSent'),
          duration: 3,
        });
        await loadStatus();
      }
    } catch (error: any) {
      let errorMsg = t('settings.verificationFailed');
      if (error?.response?.data?.detail) {
        if (typeof error.response.data.detail === 'string') {
          errorMsg = error.response.data.detail;
        } else if (error.response.data.detail.message) {
          errorMsg = error.response.data.detail.message;
        } else if (error.response.data.detail.error) {
          errorMsg = error.response.data.detail.error;
        }
      }
      message.error(errorMsg);
    } finally {
      setRenewing(false);
    }
  };

  const handleChangeEmail = async () => {
    if (!newEmail.trim()) {
      message.error(t('settings.enterStudentEmail'));
      return;
    }

    if (!newEmail.endsWith('.ac.uk')) {
      message.error(t('settings.invalidEmailFormat'));
      return;
    }

    try {
      setChangingEmail(true);
      const response = await changeStudentEmail(newEmail.trim());
      if (response.code === 200) {
        message.success({
          content: t('settings.verificationEmailSent'),
          duration: 3,
        });
        setNewEmail('');
        await loadStatus();
      }
    } catch (error: any) {
      let errorMsg = t('settings.verificationFailed');
      if (error?.response?.data?.detail) {
        if (typeof error.response.data.detail === 'string') {
          errorMsg = error.response.data.detail;
        } else if (error.response.data.detail.message) {
          errorMsg = error.response.data.detail.message;
        } else if (error.response.data.detail.error) {
          errorMsg = error.response.data.detail.error;
        }
      }
      message.error(errorMsg);
    } finally {
      setChangingEmail(false);
    }
  };

  const formatDate = (dateString: string | null) => {
    if (!dateString) return '-';
    try {
      // 使用统一的日期格式化函数，根据语言环境格式化
      const lang = localStorage.getItem('language') || 'en';
      const format = lang === 'zh' ? 'YYYY年MM月DD日' : 'MMMM DD, YYYY';
      return formatUtcToLocal(dateString, format);
    } catch {
      return dateString;
    }
  };

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        fontSize: '18px',
        color: '#666'
      }}>
        {t('settings.loadingStatus')}
      </div>
    );
  }

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
      padding: isMobile ? '0' : '20px'
    }}>
      <SEOHead noindex={true} />
      <div style={{
        maxWidth: isMobile ? '100%' : '900px',
        margin: '0 auto',
        background: '#fff',
        borderRadius: isMobile ? '0' : '16px',
        boxShadow: isMobile ? 'none' : '0 8px 32px rgba(0,0,0,0.1)',
        overflow: 'hidden',
        minHeight: isMobile ? '100vh' : 'auto'
      }}>
        <style>{`
          @keyframes spin {
            to { transform: rotate(360deg); }
          }
          @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
          }
          @keyframes slideIn {
            from { opacity: 0; transform: translateX(-20px); }
            to { opacity: 1; transform: translateX(0); }
          }
          .fade-in {
            animation: fadeIn 0.3s ease-out;
          }
          .slide-in {
            animation: slideIn 0.3s ease-out;
          }
        `}</style>
        {/* 头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
          color: '#fff',
          padding: isMobile ? '16px' : '30px',
          textAlign: 'center',
          position: 'relative'
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: isMobile ? 'relative' : 'absolute',
              left: isMobile ? 'auto' : '20px',
              top: isMobile ? 'auto' : '20px',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: isMobile ? '6px 12px' : '8px 16px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: isMobile ? '12px' : '14px',
              marginBottom: isMobile ? '8px' : '0',
              display: 'inline-block'
            }}
          >
            ← {t('common.back')}
          </button>
          <h1 style={{
            margin: isMobile ? '8px 0 4px' : '0',
            fontSize: isMobile ? '20px' : '24px',
            fontWeight: 'bold'
          }}>
            🎓 {t('settings.studentVerificationTitle')}
          </h1>
          <p style={{
            margin: '4px 0 0',
            fontSize: isMobile ? '12px' : '14px',
            opacity: 0.9
          }}>
            {t('settings.studentVerificationDesc')}
          </p>
          <div style={{
            marginTop: '12px',
            display: 'flex',
            gap: '8px',
            justifyContent: 'center',
            flexWrap: 'wrap'
          }}>
            <button
              onClick={() => setShowHelp(!showHelp)}
              style={{
                background: 'rgba(255,255,255,0.2)',
                border: 'none',
                color: '#fff',
                padding: '6px 12px',
                borderRadius: '20px',
                cursor: 'pointer',
                fontSize: '12px',
                display: 'flex',
                alignItems: 'center',
                gap: '4px'
              }}
            >
              {showHelp ? '▼' : '▶'} {t('settings.help') || '帮助'}
            </button>
            <button
              onClick={() => setAutoRefresh(!autoRefresh)}
              style={{
                background: autoRefresh ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.2)',
                border: 'none',
                color: '#fff',
                padding: '6px 12px',
                borderRadius: '20px',
                cursor: 'pointer',
                fontSize: '12px',
                display: 'flex',
                alignItems: 'center',
                gap: '4px'
              }}
            >
              {autoRefresh ? '🔄' : '⏸'} {autoRefresh ? (t('settings.autoRefreshOn') || '自动刷新: 开') : (t('settings.autoRefreshOff') || '自动刷新: 关')}
            </button>
          </div>
        </div>

        {/* 内容区域 */}
        <div style={{ padding: isMobile ? '16px' : '30px' }}>
          {/* 统计信息卡片 */}
          {status && status.is_verified && (
            <div className="slide-in" style={{
              display: 'grid',
              gridTemplateColumns: isMobile ? '1fr' : 'repeat(3, 1fr)',
              gap: '16px',
              marginBottom: '20px'
            }}>
              <div style={{
                background: 'linear-gradient(135deg, #10b981, #059669)',
                borderRadius: '12px',
                padding: '20px',
                color: '#fff',
                textAlign: 'center'
              }}>
                <div style={{ fontSize: '32px', marginBottom: '8px' }}>✓</div>
                <div style={{ fontSize: '14px', opacity: 0.9, marginBottom: '4px' }}>
                  {t('settings.isVerified')}
                </div>
                <div style={{ fontSize: '20px', fontWeight: 'bold' }}>
                  {status.university?.name || '-'}
                </div>
              </div>
              
              {status.days_remaining !== null && (
                <div style={{
                  background: status.days_remaining <= 7 ? 
                    'linear-gradient(135deg, #ef4444, #dc2626)' :
                    status.days_remaining <= 30 ?
                    'linear-gradient(135deg, #f59e0b, #d97706)' :
                    'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  borderRadius: '12px',
                  padding: '20px',
                  color: '#fff',
                  textAlign: 'center'
                }}>
                  <div style={{ fontSize: '32px', marginBottom: '8px' }}>⏰</div>
                  <div style={{ fontSize: '14px', opacity: 0.9, marginBottom: '4px' }}>
                    {t('settings.daysRemaining')}
                  </div>
                  <div style={{ fontSize: '24px', fontWeight: 'bold' }}>
                    {status.days_remaining} {t('common.days')}
                  </div>
                </div>
              )}

              {status.verified_at && (
                <div style={{
                  background: 'linear-gradient(135deg, #8b5cf6, #7c3aed)',
                  borderRadius: '12px',
                  padding: '20px',
                  color: '#fff',
                  textAlign: 'center'
                }}>
                  <div style={{ fontSize: '32px', marginBottom: '8px' }}>📅</div>
                  <div style={{ fontSize: '14px', opacity: 0.9, marginBottom: '4px' }}>
                    {t('settings.verifiedAt')}
                  </div>
                  <div style={{ fontSize: '12px', fontWeight: 'bold' }}>
                    {formatDate(status.verified_at)}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* 帮助说明 */}
          {showHelp && (
            <div style={{
              background: '#e7f3ff',
              border: '1px solid #3b82f6',
              borderRadius: '12px',
              padding: isMobile ? '16px' : '20px',
              marginBottom: '20px'
            }}>
              <h3 style={{
                color: '#1e40af',
                marginBottom: '12px',
                fontSize: isMobile ? '16px' : '18px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}>
                ❓ {t('settings.help') || '帮助说明'}
              </h3>
              <div style={{
                color: '#1e40af',
                fontSize: '14px',
                lineHeight: '1.6'
              }}>
                <p style={{ marginBottom: '8px' }}>
                  <strong>1. {t('settings.helpQ1') || '如何提交认证？'}</strong><br />
                  {t('settings.helpA1') || '输入您的英国大学邮箱（.ac.uk结尾），点击提交按钮。系统会向您的邮箱发送验证链接。'}
                </p>
                <p style={{ marginBottom: '8px' }}>
                  <strong>2. {t('settings.helpQ2') || '验证邮件多久过期？'}</strong><br />
                  {t('settings.helpA2') || '验证链接有效期为15分钟。如果过期，您可以重新提交认证。'}
                </p>
                <p style={{ marginBottom: '8px' }}>
                  <strong>3. {t('settings.helpQ3') || '认证有效期是多久？'}</strong><br />
                  {t('settings.helpA3') || '认证有效期为一年，每年10月1日到期。您可以在到期前30天开始续期。'}
                </p>
                <p style={{ marginBottom: '8px' }}>
                  <strong>4. {t('settings.helpQ4') || '可以更换邮箱吗？'}</strong><br />
                  {t('settings.helpA4') || '可以。在已验证状态下，您可以更换为其他英国大学邮箱。更换后需要重新验证。'}
                </p>
                <p style={{ marginBottom: '0' }}>
                  <strong>5. {t('settings.helpQ5') || '没有收到验证邮件？'}</strong><br />
                  {t('settings.helpA5') || '请检查垃圾邮件文件夹。如果仍未收到，可以点击"重发验证邮件"按钮。'}
                </p>
              </div>
            </div>
          )}

          {/* 认证状态 */}
          {status && (
            <div className="fade-in" style={{
              background: '#f8f9fa',
              borderRadius: '12px',
              padding: isMobile ? '16px' : '20px',
              marginBottom: '20px',
              border: '1px solid #e9ecef'
            }}>
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '16px'
              }}>
                <h2 style={{
                  color: '#333',
                  margin: '0',
                  fontSize: isMobile ? '18px' : '20px'
                }}>
                  {t('settings.verificationStatus')}
                </h2>
                <button
                  onClick={loadStatus}
                  disabled={loading}
                  style={{
                    background: '#e5e7eb',
                    border: 'none',
                    color: '#111827',
                    padding: '6px 12px',
                    borderRadius: '20px',
                    cursor: loading ? 'not-allowed' : 'pointer',
                    fontSize: '12px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    opacity: loading ? 0.6 : 1
                  }}
                  title={t('settings.refresh') || '刷新'}
                >
                  🔄 {loading ? t('common.loading') : (t('settings.refresh') || '刷新')}
                </button>
              </div>

              {status.is_verified ? (
                <div>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    marginBottom: '12px'
                  }}>
                    <span style={{
                      background: '#10b981',
                      color: '#fff',
                      padding: '4px 12px',
                      borderRadius: '20px',
                      fontSize: '14px',
                      fontWeight: 'bold',
                      marginRight: '12px'
                    }}>
                      ✓ {t('settings.isVerified')}
                    </span>
                  </div>

                  {status.university && (
                    <div style={{ marginBottom: '8px' }}>
                      <strong>{t('settings.verifiedUniversity')}:</strong> {status.university.name} ({status.university.name_cn})
                    </div>
                  )}

                  {status.email && (
                    <div style={{ marginBottom: '8px' }}>
                      <strong>{t('settings.verifiedEmail')}:</strong> {status.email}
                    </div>
                  )}

                  {status.verified_at && (
                    <div style={{ marginBottom: '8px' }}>
                      <strong>{t('settings.verifiedAt')}:</strong> {formatDate(status.verified_at)}
                    </div>
                  )}

                  {status.expires_at && (
                    <div style={{ marginBottom: '8px' }}>
                      <strong>{t('settings.expiresAt')}:</strong> {formatDate(status.expires_at)}
                    </div>
                  )}

                  {status.days_remaining !== null && (
                    <div style={{ 
                      marginBottom: '8px',
                      padding: '8px 12px',
                      background: status.days_remaining <= 30 ? 
                        (status.days_remaining <= 7 ? '#fee2e2' : '#fff3cd') : '#e7f3ff',
                      borderRadius: '8px',
                      border: status.days_remaining <= 30 ? 
                        (status.days_remaining <= 7 ? '1px solid #ef4444' : '1px solid #ffc107') : '1px solid #3b82f6'
                    }}>
                      <strong>{t('settings.daysRemaining')}:</strong> 
                      <span style={{ 
                        color: status.days_remaining <= 7 ? '#dc2626' : 
                               status.days_remaining <= 30 ? '#d97706' : '#1e40af',
                        fontWeight: 'bold',
                        marginLeft: '8px'
                      }}>
                        {status.days_remaining} {t('common.days')}
                      </span>
                    </div>
                  )}

                  {status.can_renew && (
                    <div style={{
                      background: '#fff3cd',
                      border: '1px solid #ffc107',
                      borderRadius: '8px',
                      padding: '12px',
                      marginTop: '12px'
                    }}>
                      <p style={{ margin: '0 0 8px', color: '#856404' }}>
                        {t('settings.renewDesc')}
                      </p>
                      <button
                        onClick={handleRenew}
                        disabled={renewing}
                        style={{
                          background: '#ffc107',
                          color: '#000',
                          border: 'none',
                          padding: '8px 16px',
                          borderRadius: '20px',
                          cursor: renewing ? 'not-allowed' : 'pointer',
                          fontSize: '14px',
                          fontWeight: 'bold'
                        }}
                      >
                        {renewing ? t('common.loading') : t('settings.renewButton')}
                      </button>
                    </div>
                  )}

                  {!status.can_renew && status.renewable_from && (
                    <div style={{
                      background: '#e7f3ff',
                      border: '1px solid #3b82f6',
                      borderRadius: '8px',
                      padding: '12px',
                      marginTop: '12px'
                    }}>
                      <p style={{ margin: '0', color: '#1e40af', fontSize: '14px' }}>
                        {t('settings.renewalWindow')} ({t('settings.renewableFrom')}: {formatDate(status.renewable_from)})
                      </p>
                    </div>
                  )}

                  {/* 更换邮箱 */}
                  <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #e9ecef' }}>
                    <h3 style={{ fontSize: '16px', marginBottom: '12px' }}>
                      {t('settings.changeEmail')}
                    </h3>
                    <p style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
                      {t('settings.changeEmailDesc')}
                    </p>
                    <div style={{ display: 'flex', gap: '8px', marginBottom: '8px' }}>
                      <input
                        type="email"
                        value={newEmail}
                        onChange={(e) => setNewEmail(e.target.value)}
                        onKeyPress={(e) => {
                          if (e.key === 'Enter' && !changingEmail && newEmail.trim()) {
                            handleChangeEmail();
                          }
                        }}
                        placeholder={t('settings.emailPlaceholder')}
                        style={{
                          flex: 1,
                          padding: '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px'
                        }}
                      />
                      <button
                        onClick={handleChangeEmail}
                        disabled={changingEmail || !newEmail.trim()}
                        style={{
                          background: changingEmail ? '#ccc' : '#3b82f6',
                          color: '#fff',
                          border: 'none',
                          padding: '12px 20px',
                          borderRadius: '8px',
                          cursor: changingEmail || !newEmail.trim() ? 'not-allowed' : 'pointer',
                          fontSize: '14px',
                          fontWeight: 'bold',
                          whiteSpace: 'nowrap'
                        }}
                      >
                        {changingEmail ? t('common.loading') : t('settings.changeEmailButton')}
                      </button>
                    </div>
                  </div>
                </div>
              ) : status.status === 'pending' ? (
                <div>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    marginBottom: '12px'
                  }}>
                    <span style={{
                      background: '#f59e0b',
                      color: '#fff',
                      padding: '4px 12px',
                      borderRadius: '20px',
                      fontSize: '14px',
                      fontWeight: 'bold',
                      marginRight: '12px'
                    }}>
                      ⏳ {t('settings.pending')}
                    </span>
                  </div>
                  {status.email && (
                    <div style={{ marginBottom: '8px' }}>
                      <strong>{t('settings.verifiedEmail')}:</strong> {status.email}
                    </div>
                  )}
                  {status.email_locked && (
                    <div style={{
                      background: '#fff3cd',
                      border: '1px solid #ffc107',
                      borderRadius: '8px',
                      padding: '12px',
                      marginTop: '12px'
                    }}>
                      <p style={{ margin: '0 0 8px', color: '#856404', fontSize: '14px' }}>
                        {t('settings.checkEmail')}
                      </p>
                      <button
                        onClick={async () => {
                          if (status.email) {
                            setEmail(status.email);
                            await handleSubmit();
                          }
                        }}
                        disabled={submitting}
                        style={{
                          background: '#ffc107',
                          color: '#000',
                          border: 'none',
                          padding: '8px 16px',
                          borderRadius: '20px',
                          cursor: submitting ? 'not-allowed' : 'pointer',
                          fontSize: '14px',
                          fontWeight: 'bold'
                        }}
                      >
                        {submitting ? t('common.loading') : t('auth.resendVerification')}
                      </button>
                    </div>
                  )}
                </div>
              ) : (
                <div>
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    marginBottom: '12px'
                  }}>
                    <span style={{
                      background: '#e5e7eb',
                      color: '#6b7280',
                      padding: '4px 12px',
                      borderRadius: '20px',
                      fontSize: '14px',
                      fontWeight: 'bold',
                      marginRight: '12px'
                    }}>
                      ⚪ {t('settings.notVerified')}
                    </span>
                  </div>
                  <p style={{ color: '#666', marginBottom: '16px', fontSize: '14px' }}>
                    {t('settings.noVerification')}
                  </p>
                </div>
              )}
            </div>
          )}

          {/* 提交认证表单 */}
          {(!status || !status.is_verified) && status?.status !== 'pending' && (
            <div style={{
              background: '#f8f9fa',
              borderRadius: '12px',
              padding: isMobile ? '16px' : '20px',
              border: '1px solid #e9ecef'
            }}>
              <h2 style={{
                color: '#333',
                marginBottom: '16px',
                fontSize: isMobile ? '18px' : '20px'
              }}>
                {t('settings.submitVerification')}
              </h2>

              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  marginBottom: '8px',
                  fontWeight: 'bold',
                  color: '#333',
                  fontSize: '14px'
                }}>
                  {t('settings.enterStudentEmail')}
                </label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  onKeyPress={(e) => {
                    if (e.key === 'Enter' && !submitting && email.trim()) {
                      handleSubmit();
                    }
                  }}
                  placeholder={t('settings.emailPlaceholder')}
                  style={{
                    width: '100%',
                    padding: '12px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    boxSizing: 'border-box'
                  }}
                />
                <p style={{
                  marginTop: '4px',
                  fontSize: '12px',
                  color: '#999'
                }}>
                  {t('settings.emailPlaceholder')}
                </p>
                {showUniversityList && (
                  <div style={{
                    marginTop: '12px',
                    background: '#fff',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    maxHeight: '200px',
                    overflowY: 'auto',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
                  }}>
                    <input
                      type="text"
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      placeholder={t('settings.searchUniversity')}
                      style={{
                        width: '100%',
                        padding: '8px 12px',
                        border: 'none',
                        borderBottom: '1px solid #e9ecef',
                        borderRadius: '8px 8px 0 0',
                        fontSize: '14px',
                        boxSizing: 'border-box'
                      }}
                    />
                    {universities.length > 0 ? (
                      <div style={{ padding: '4px' }}>
                        {universities.map((uni) => (
                          <div
                            key={uni.id}
                            onClick={() => {
                              // 从域名提取示例邮箱格式
                              const domain = uni.email_domain;
                              setEmail(`student@${domain}`);
                              setShowUniversityList(false);
                              setSearchTerm('');
                            }}
                            style={{
                              padding: '8px 12px',
                              cursor: 'pointer',
                              borderRadius: '4px',
                              transition: 'background 0.2s'
                            }}
                            onMouseEnter={(e) => {
                              e.currentTarget.style.background = '#f0f0f0';
                            }}
                            onMouseLeave={(e) => {
                              e.currentTarget.style.background = 'transparent';
                            }}
                          >
                            <div style={{ fontWeight: 'bold', fontSize: '14px' }}>
                              {uni.name}
                            </div>
                            <div style={{ fontSize: '12px', color: '#666' }}>
                              {uni.name_cn} - {uni.email_domain}
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div style={{
                        padding: '20px',
                        textAlign: 'center',
                        color: '#999',
                        fontSize: '14px'
                      }}>
                        {t('settings.noUniversityFound') || '未找到匹配的大学'}
                      </div>
                    )}
                  </div>
                )}
                {!showUniversityList && (
                  <button
                    type="button"
                    onClick={() => setShowUniversityList(true)}
                    style={{
                      marginTop: '8px',
                      background: 'transparent',
                      border: '1px dashed #3b82f6',
                      color: '#3b82f6',
                      padding: '6px 12px',
                      borderRadius: '20px',
                      cursor: 'pointer',
                      fontSize: '12px'
                    }}
                  >
                    📚 {t('settings.selectUniversity') || '选择大学'}
                  </button>
                )}
              </div>

              <button
                onClick={handleSubmit}
                disabled={submitting || !email.trim()}
                style={{
                  width: '100%',
                  background: submitting || !email.trim() ? '#ccc' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  padding: '12px 24px',
                  borderRadius: '25px',
                  cursor: submitting || !email.trim() ? 'not-allowed' : 'pointer',
                  fontSize: '16px',
                  fontWeight: 'bold',
                  boxShadow: submitting || !email.trim() ? 'none' : '0 4px 15px rgba(59, 130, 246, 0.3)',
                  transition: 'all 0.3s ease',
                  position: 'relative',
                  overflow: 'hidden'
                }}
                onMouseEnter={(e) => {
                  if (!submitting && email.trim()) {
                    e.currentTarget.style.transform = 'translateY(-2px)';
                    e.currentTarget.style.boxShadow = '0 6px 20px rgba(59, 130, 246, 0.4)';
                  }
                }}
                onMouseLeave={(e) => {
                  if (!submitting && email.trim()) {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = '0 4px 15px rgba(59, 130, 246, 0.3)';
                  }
                }}
              >
                {submitting ? (
                  <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                    <span style={{
                      display: 'inline-block',
                      width: '16px',
                      height: '16px',
                      border: '2px solid rgba(255,255,255,0.3)',
                      borderTopColor: '#fff',
                      borderRadius: '50%',
                      animation: 'spin 0.8s linear infinite'
                    }}></span>
                    {t('common.loading')}
                  </span>
                ) : (
                  t('settings.submitButton')
                )}
              </button>
            </div>
          )}

          {/* 过期状态 */}
          {status?.status === 'expired' && (
            <div style={{
              background: '#fee2e2',
              border: '1px solid #ef4444',
              borderRadius: '12px',
              padding: isMobile ? '16px' : '20px',
              marginTop: '20px'
            }}>
              <div style={{
                display: 'flex',
                alignItems: 'center',
                marginBottom: '12px'
              }}>
                <span style={{
                  background: '#ef4444',
                  color: '#fff',
                  padding: '4px 12px',
                  borderRadius: '20px',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  marginRight: '12px'
                }}>
                  ⚠️ {t('settings.expired')}
                </span>
              </div>
              <p style={{ margin: '0 0 12px', color: '#991b1b', fontSize: '14px' }}>
                {t('settings.verificationExpired')}
              </p>
              <button
                onClick={handleRenew}
                disabled={renewing}
                style={{
                  background: '#ef4444',
                  color: '#fff',
                  border: 'none',
                  padding: '10px 20px',
                  borderRadius: '20px',
                  cursor: renewing ? 'not-allowed' : 'pointer',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  if (!renewing) {
                    e.currentTarget.style.background = '#dc2626';
                    e.currentTarget.style.transform = 'translateY(-1px)';
                  }
                }}
                onMouseLeave={(e) => {
                  if (!renewing) {
                    e.currentTarget.style.background = '#ef4444';
                    e.currentTarget.style.transform = 'translateY(0)';
                  }
                }}
              >
                {renewing ? t('common.loading') : t('settings.renewNow')}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default StudentVerification;

