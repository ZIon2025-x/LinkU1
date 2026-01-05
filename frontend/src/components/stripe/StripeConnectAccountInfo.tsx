import React, { useState, useEffect } from 'react';
import api from '../../api';
import { useLanguage } from '../../contexts/LanguageContext';

interface AccountDetails {
  account_id: string;
  display_name?: string;
  email?: string;
  country: string;
  type: string;
  details_submitted: boolean;
  charges_enabled: boolean;
  payouts_enabled: boolean;
  dashboard_url?: string;
  requirements?: {
    currently_due?: string[];
    eventually_due?: string[];
    past_due?: string[];
  };
  capabilities?: {
    card_payments?: string;
    transfers?: string;
  };
}

interface StripeConnectAccountInfoProps {
  accountId: string;
}

/**
 * Stripe Connect 账户信息显示组件
 * 显示账户的详细信息和状态
 */
const StripeConnectAccountInfo: React.FC<StripeConnectAccountInfoProps> = ({ accountId }) => {
  const { t } = useLanguage();
  const [accountDetails, setAccountDetails] = useState<AccountDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchAccountDetails = async () => {
      try {
        setLoading(true);
        setError(null);
        const response = await api.get('/api/stripe/connect/account/details');
        setAccountDetails(response.data);
      } catch (err: any) {
        console.error('Error fetching account details:', err);
        setError(err.response?.data?.detail || err.message || t('wallet.stripe.failedToGetAccountInfo'));
      } finally {
        setLoading(false);
      }
    };

    if (accountId) {
      fetchAccountDetails();
    }
  }, [accountId]);

  if (loading) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div>{t('wallet.stripe.loadingAccountInfo')}</div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: '20px', color: 'red' }}>
        {t('wallet.stripe.error')}: {error}
      </div>
    );
  }

  if (!accountDetails) {
    return null;
  }

  const getStatusBadge = (enabled: boolean) => {
    return (
      <span style={{
        padding: '6px 12px',
        borderRadius: '8px',
        fontSize: '12px',
        fontWeight: '600',
        backgroundColor: enabled ? '#d1fae5' : '#fee2e2',
        color: enabled ? '#065f46' : '#991b1b',
        display: 'inline-block'
      }}>
        {enabled ? t('wallet.stripe.enabled') : t('wallet.stripe.disabled')}
      </span>
    );
  };

  const getCapabilityStatus = (status?: string) => {
    if (!status) return t('wallet.stripe.unknown');
    const statusMap: { [key: string]: string } = {
      'active': t('wallet.stripe.active'),
      'inactive': t('wallet.stripe.inactive'),
      'pending': t('wallet.stripe.pending')
    };
    return statusMap[status] || status;
  };

  return (
    <div style={{
      maxWidth: '100%',
      padding: '24px',
      background: '#fff',
      borderRadius: '16px',
      boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
      border: '1px solid #e2e8f0'
    }}>
      <h3 style={{ 
        marginBottom: '20px', 
        color: '#1a202c', 
        fontSize: '17px',
        fontWeight: '600',
        letterSpacing: '-0.2px'
      }}>
        {t('wallet.stripe.accountInfo')}
      </h3>

      {/* 账户基本信息 */}
      <div style={{ marginBottom: '24px' }}>
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '16px'
        }}>
          <div>
            <div style={{ 
              fontSize: '12px', 
              color: '#64748b', 
              marginBottom: '6px',
              fontWeight: '500'
            }}>
              {t('wallet.stripe.accountId')}
            </div>
            <div style={{ 
              fontFamily: 'monospace', 
              fontSize: '13px', 
              color: '#1a202c',
              wordBreak: 'break-all',
              fontWeight: '500'
            }}>
              {accountDetails.account_id}
            </div>
          </div>
          
          {accountDetails.display_name && (
            <div>
              <div style={{ 
                fontSize: '12px', 
                color: '#64748b', 
                marginBottom: '6px',
                fontWeight: '500'
              }}>
                {t('wallet.stripe.displayName')}
              </div>
              <div style={{ 
                fontSize: '14px', 
                color: '#1a202c',
                fontWeight: '500'
              }}>
                {accountDetails.display_name}
              </div>
            </div>
          )}
          
          {accountDetails.email && (
            <div>
              <div style={{ 
                fontSize: '12px', 
                color: '#64748b', 
                marginBottom: '6px',
                fontWeight: '500'
              }}>
                {t('wallet.stripe.email')}
              </div>
              <div style={{ 
                fontSize: '14px', 
                color: '#1a202c',
                fontWeight: '500'
              }}>
                {accountDetails.email}
              </div>
            </div>
          )}
          
          <div>
            <div style={{ 
              fontSize: '12px', 
              color: '#64748b', 
              marginBottom: '6px',
              fontWeight: '500'
            }}>
              {t('wallet.stripe.country')}
            </div>
            <div style={{ 
              fontSize: '14px', 
              color: '#1a202c',
              fontWeight: '500'
            }}>
              {accountDetails.country}
            </div>
          </div>
        </div>
      </div>

      {/* 账户状态 */}
      <div style={{ 
        marginBottom: '24px',
        padding: '20px',
        backgroundColor: '#fafbfc',
        borderRadius: '12px',
        border: '1px solid #e2e8f0'
      }}>
        <h4 style={{ 
          marginBottom: '16px', 
          fontSize: '14px', 
          color: '#1a202c',
          fontWeight: '600'
        }}>
          {t('wallet.stripe.accountStatus')}
        </h4>
        <div style={{ 
          display: 'flex', 
          flexWrap: 'wrap', 
          gap: '16px'
        }}>
          <div>
            <div style={{ 
              fontSize: '12px', 
              color: '#64748b', 
              marginBottom: '6px',
              fontWeight: '500'
            }}>
              {t('wallet.stripe.infoSubmitted')}
            </div>
            {getStatusBadge(accountDetails.details_submitted)}
          </div>
          <div>
            <div style={{ 
              fontSize: '12px', 
              color: '#64748b', 
              marginBottom: '6px',
              fontWeight: '500'
            }}>
              {t('wallet.stripe.paymentCapability')}
            </div>
            {getStatusBadge(accountDetails.charges_enabled)}
          </div>
          <div>
            <div style={{ 
              fontSize: '12px', 
              color: '#64748b', 
              marginBottom: '6px',
              fontWeight: '500'
            }}>
              {t('wallet.stripe.payoutCapability')}
            </div>
            {getStatusBadge(accountDetails.payouts_enabled)}
          </div>
        </div>
      </div>

      {/* 账户能力 */}
      {accountDetails.capabilities && (
        <div style={{ 
          marginBottom: '24px',
          padding: '20px',
          backgroundColor: '#fafbfc',
          borderRadius: '12px',
          border: '1px solid #e2e8f0'
        }}>
          <h4 style={{ 
            marginBottom: '16px', 
            fontSize: '14px', 
            color: '#1a202c',
            fontWeight: '600'
          }}>
            {t('wallet.stripe.accountCapabilities')}
          </h4>
          <div style={{ 
            display: 'flex', 
            flexWrap: 'wrap', 
            gap: '16px'
          }}>
            {accountDetails.capabilities.card_payments && (
              <div>
                <div style={{ 
                  fontSize: '12px', 
                  color: '#64748b', 
                  marginBottom: '6px',
                  fontWeight: '500'
                }}>
                  {t('wallet.stripe.cardPayments')}
                </div>
                <div style={{ 
                  fontSize: '14px', 
                  color: '#1a202c',
                  fontWeight: '500'
                }}>
                  {getCapabilityStatus(accountDetails.capabilities.card_payments)}
                </div>
              </div>
            )}
            {accountDetails.capabilities.transfers && (
              <div>
                <div style={{ 
                  fontSize: '12px', 
                  color: '#64748b', 
                  marginBottom: '6px',
                  fontWeight: '500'
                }}>
                  {t('wallet.stripe.transfers')}
                </div>
                <div style={{ 
                  fontSize: '14px', 
                  color: '#1a202c',
                  fontWeight: '500'
                }}>
                  {getCapabilityStatus(accountDetails.capabilities.transfers)}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Stripe 仪表板链接 */}
      {accountDetails.dashboard_url && (
        <div style={{ marginBottom: '24px' }}>
          <a
            href={accountDetails.dashboard_url}
            target="_blank"
            rel="noopener noreferrer"
            style={{
              display: 'inline-block',
              padding: '10px 20px',
              backgroundColor: '#667eea',
              color: 'white',
              textDecoration: 'none',
              borderRadius: '10px',
              fontSize: '14px',
              fontWeight: '600',
              transition: 'all 0.2s ease',
              boxShadow: '0 2px 4px rgba(102, 126, 234, 0.2)'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#5568d3';
              e.currentTarget.style.transform = 'translateY(-1px)';
              e.currentTarget.style.boxShadow = '0 4px 8px rgba(102, 126, 234, 0.3)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#667eea';
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 4px rgba(102, 126, 234, 0.2)';
            }}
          >
            {t('wallet.stripe.openStripeDashboard')}
          </a>
          <div style={{ 
            marginTop: '10px', 
            fontSize: '13px', 
            color: '#64748b',
            lineHeight: '1.5'
          }}>
            {t('wallet.stripe.dashboardDescription')}
          </div>
        </div>
      )}

      {/* 待办事项 */}
      {accountDetails.requirements && (
        ((accountDetails.requirements.currently_due && accountDetails.requirements.currently_due.length > 0) ||
         (accountDetails.requirements.past_due && accountDetails.requirements.past_due.length > 0)) && (
          <div style={{ 
            marginTop: '20px',
            padding: '15px',
            backgroundColor: '#fff3cd',
            borderRadius: '8px',
            border: '1px solid #ffc107'
          }}>
            <h4 style={{ marginBottom: '12px', fontSize: '14px', color: '#856404' }}>
              {t('wallet.stripe.pendingItems')}
            </h4>
            {accountDetails.requirements.past_due && accountDetails.requirements.past_due.length > 0 && (
              <div style={{ marginBottom: '10px' }}>
                <div style={{ fontSize: '12px', color: '#721c24', marginBottom: '4px', fontWeight: '600' }}>
                  {t('wallet.stripe.pastDueItems')}
                </div>
                <ul style={{ margin: 0, paddingLeft: '20px', fontSize: '12px', color: '#721c24' }}>
                  {accountDetails.requirements.past_due.map((item, index) => (
                    <li key={index}>{item}</li>
                  ))}
                </ul>
              </div>
            )}
            {accountDetails.requirements.currently_due && accountDetails.requirements.currently_due.length > 0 && (
              <div>
                <div style={{ fontSize: '12px', color: '#856404', marginBottom: '4px', fontWeight: '600' }}>
                  {t('wallet.stripe.currentlyDueItems')}
                </div>
                <ul style={{ margin: 0, paddingLeft: '20px', fontSize: '12px', color: '#856404' }}>
                  {accountDetails.requirements.currently_due.map((item, index) => (
                    <li key={index}>{item}</li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        )
      )}
    </div>
  );
};

export default StripeConnectAccountInfo;

