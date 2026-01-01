import React, { useState, useEffect } from 'react';
import api from '../../api';

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
        setError(err.response?.data?.detail || err.message || '获取账户信息失败');
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
        <div>加载账户信息中...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: '20px', color: 'red' }}>
        错误: {error}
      </div>
    );
  }

  if (!accountDetails) {
    return null;
  }

  const getStatusBadge = (enabled: boolean) => {
    return (
      <span style={{
        padding: '4px 8px',
        borderRadius: '4px',
        fontSize: '12px',
        fontWeight: '600',
        backgroundColor: enabled ? '#d4edda' : '#f8d7da',
        color: enabled ? '#155724' : '#721c24'
      }}>
        {enabled ? '✓ 已启用' : '✗ 未启用'}
      </span>
    );
  };

  const getCapabilityStatus = (status?: string) => {
    if (!status) return '未知';
    const statusMap: { [key: string]: string } = {
      'active': '✓ 已激活',
      'inactive': '✗ 未激活',
      'pending': '⏳ 待处理'
    };
    return statusMap[status] || status;
  };

  return (
    <div style={{
      maxWidth: '800px',
      margin: '0 auto',
      padding: '20px',
      background: '#fff',
      borderRadius: '12px',
      boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
    }}>
      <h3 style={{ marginBottom: '20px', color: '#333', fontSize: '18px' }}>
        📊 账户信息
      </h3>

      {/* 账户基本信息 */}
      <div style={{ marginBottom: '20px' }}>
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '15px',
          marginBottom: '15px'
        }}>
          <div>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>账户 ID</div>
            <div style={{ 
              fontFamily: 'monospace', 
              fontSize: '14px', 
              color: '#333',
              wordBreak: 'break-all'
            }}>
              {accountDetails.account_id}
            </div>
          </div>
          
          {accountDetails.display_name && (
            <div>
              <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>显示名称</div>
              <div style={{ fontSize: '14px', color: '#333' }}>
                {accountDetails.display_name}
              </div>
            </div>
          )}
          
          {accountDetails.email && (
            <div>
              <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>邮箱</div>
              <div style={{ fontSize: '14px', color: '#333' }}>
                {accountDetails.email}
              </div>
            </div>
          )}
          
          <div>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>国家/地区</div>
            <div style={{ fontSize: '14px', color: '#333' }}>
              {accountDetails.country}
            </div>
          </div>
        </div>
      </div>

      {/* 账户状态 */}
      <div style={{ 
        marginBottom: '20px',
        padding: '15px',
        backgroundColor: '#f8f9fa',
        borderRadius: '8px'
      }}>
        <h4 style={{ marginBottom: '12px', fontSize: '14px', color: '#333' }}>账户状态</h4>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '15px' }}>
          <div>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>信息提交</div>
            {getStatusBadge(accountDetails.details_submitted)}
          </div>
          <div>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>收款能力</div>
            {getStatusBadge(accountDetails.charges_enabled)}
          </div>
          <div>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>提现能力</div>
            {getStatusBadge(accountDetails.payouts_enabled)}
          </div>
        </div>
      </div>

      {/* 账户能力 */}
      {accountDetails.capabilities && (
        <div style={{ 
          marginBottom: '20px',
          padding: '15px',
          backgroundColor: '#f8f9fa',
          borderRadius: '8px'
        }}>
          <h4 style={{ marginBottom: '12px', fontSize: '14px', color: '#333' }}>账户能力</h4>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '15px' }}>
            {accountDetails.capabilities.card_payments && (
              <div>
                <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>卡支付</div>
                <div style={{ fontSize: '14px', color: '#333' }}>
                  {getCapabilityStatus(accountDetails.capabilities.card_payments)}
                </div>
              </div>
            )}
            {accountDetails.capabilities.transfers && (
              <div>
                <div style={{ fontSize: '12px', color: '#666', marginBottom: '4px' }}>转账</div>
                <div style={{ fontSize: '14px', color: '#333' }}>
                  {getCapabilityStatus(accountDetails.capabilities.transfers)}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Stripe 仪表板链接 */}
      {accountDetails.dashboard_url && (
        <div style={{ marginBottom: '20px' }}>
          <a
            href={accountDetails.dashboard_url}
            target="_blank"
            rel="noopener noreferrer"
            style={{
              display: 'inline-block',
              padding: '12px 24px',
              backgroundColor: '#635BFF',
              color: 'white',
              textDecoration: 'none',
              borderRadius: '8px',
              fontSize: '14px',
              fontWeight: '600',
              transition: 'all 0.3s ease'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#4f46e5';
              e.currentTarget.style.transform = 'translateY(-2px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#635BFF';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            🔗 打开 Stripe 仪表板
          </a>
          <div style={{ 
            marginTop: '8px', 
            fontSize: '12px', 
            color: '#666' 
          }}>
            在 Stripe 仪表板中查看交易记录、提现历史等详细信息
          </div>
        </div>
      )}

      {/* 待办事项 */}
      {accountDetails.requirements && (
        (accountDetails.requirements.currently_due?.length > 0 ||
         accountDetails.requirements.past_due?.length > 0) && (
          <div style={{ 
            marginTop: '20px',
            padding: '15px',
            backgroundColor: '#fff3cd',
            borderRadius: '8px',
            border: '1px solid #ffc107'
          }}>
            <h4 style={{ marginBottom: '12px', fontSize: '14px', color: '#856404' }}>
              ⚠️ 待完成事项
            </h4>
            {accountDetails.requirements.past_due?.length > 0 && (
              <div style={{ marginBottom: '10px' }}>
                <div style={{ fontSize: '12px', color: '#721c24', marginBottom: '4px', fontWeight: '600' }}>
                  逾期事项：
                </div>
                <ul style={{ margin: 0, paddingLeft: '20px', fontSize: '12px', color: '#721c24' }}>
                  {accountDetails.requirements.past_due.map((item, index) => (
                    <li key={index}>{item}</li>
                  ))}
                </ul>
              </div>
            )}
            {accountDetails.requirements.currently_due?.length > 0 && (
              <div>
                <div style={{ fontSize: '12px', color: '#856404', marginBottom: '4px', fontWeight: '600' }}>
                  当前待办：
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

