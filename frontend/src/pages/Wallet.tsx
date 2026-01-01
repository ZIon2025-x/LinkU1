import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchCurrentUser, getPointsAccount, getPointsTransactions } from '../api';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';

interface PointsAccount {
  balance: number;  // 积分数量（整数，100积分 = £1.00）
  balance_display: string;  // 显示格式（如 "5.00"）
  currency: string;
  total_earned: number;  // 累计获得积分
  total_spent: number;  // 累计消费积分
  usage_restrictions: {
    allowed: string[];
    forbidden: string[];
  };
}

interface PointsTransaction {
  id: number;
  type: string;  // earn, spend, refund, expire
  amount: number;  // 积分数量
  amount_display: string;
  balance_after: number;
  balance_after_display: string;
  currency: string;
  source?: string;
  description?: string;
  created_at: string;
}

const Wallet: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [balance, setBalance] = useState(0);  // 钱包余额（金额）
  const [transactions, setTransactions] = useState<any[]>([]);  // 钱包交易记录
  const [pointsAccount, setPointsAccount] = useState<PointsAccount | null>(null);  // 积分账户
  const [pointsTransactions, setPointsTransactions] = useState<PointsTransaction[]>([]);  // 积分交易记录
  const [activeTab, setActiveTab] = useState<'balance' | 'points' | 'stripe'>('balance');  // 当前标签页
  const [loading, setLoading] = useState(true);
  const [pointsLoading, setPointsLoading] = useState(false);
  const [pointsPage, setPointsPage] = useState(1);
  const [pointsTotal, setPointsTotal] = useState(0);
  
  // Stripe 相关状态
  const [stripeBalance, setStripeBalance] = useState<{
    available: number;
    pending: number;
    total: number;
    currency: string;
  } | null>(null);
  const [stripeTransactions, setStripeTransactions] = useState<any[]>([]);
  const [stripeLoading, setStripeLoading] = useState(false);
  const [hasStripeAccount, setHasStripeAccount] = useState(false);
  const [stripeDashboardUrl, setStripeDashboardUrl] = useState<string | null>(null);

  useEffect(() => {
    // 加载钱包数据
    loadWalletData();
    // 加载积分数据
    loadPointsData();
    // 检查是否有 Stripe 账户
    checkStripeAccount();
  }, []);

  useEffect(() => {
    if (activeTab === 'points' && pointsAccount) {
      loadPointsTransactions();
    } else if (activeTab === 'stripe' && hasStripeAccount) {
      loadStripeData();
    }
  }, [activeTab, pointsPage]);

  const loadWalletData = async () => {
    try {
      // TODO: 调用真实的钱包API
      // const walletData = await getWalletData();
      // setBalance(walletData.balance);
      // setTransactions(walletData.transactions);
      
      // 暂时显示空数据，等待后端API实现
      setBalance(0);
      setTransactions([]);
    } catch (error) {
            setBalance(0);
      setTransactions([]);
    }
  };

  const loadPointsData = async () => {
    try {
      setPointsLoading(true);
      const accountData = await getPointsAccount();
      setPointsAccount(accountData);
    } catch (error) {
          } finally {
      setPointsLoading(false);
      setLoading(false);
    }
  };

  const loadPointsTransactions = async () => {
    try {
      setPointsLoading(true);
      const result = await getPointsTransactions({
        page: pointsPage,
        limit: 20
      });
      setPointsTransactions(result.data || []);
      setPointsTotal(result.total || 0);
    } catch (error) {
          } finally {
      setPointsLoading(false);
    }
  };

  // 检查是否有 Stripe 账户
  const checkStripeAccount = async () => {
    try {
      const response = await api.get('/api/stripe/connect/account/status');
      if (response.data && response.data.account_id) {
        setHasStripeAccount(true);
        // 获取仪表板链接
        try {
          const detailsResponse = await api.get('/api/stripe/connect/account/details');
          if (detailsResponse.data && detailsResponse.data.dashboard_url) {
            setStripeDashboardUrl(detailsResponse.data.dashboard_url);
          }
        } catch (error) {
          // 获取仪表板链接失败，不影响其他功能
        }
      }
    } catch (error) {
      // 没有账户是正常的
      setHasStripeAccount(false);
    }
  };

  // 加载 Stripe 数据
  const loadStripeData = async () => {
    if (!hasStripeAccount) {
      return;
    }
    
    try {
      setStripeLoading(true);
      
      // 加载余额
      try {
        const balanceResponse = await api.get('/api/stripe/connect/account/balance');
        setStripeBalance(balanceResponse.data);
      } catch (error: any) {
        if (error.response?.status !== 404) {
          console.error('Error loading Stripe balance:', error);
        }
      }
      
      // 加载交易记录
      try {
        const transactionsResponse = await api.get('/api/stripe/connect/account/transactions', {
          params: { limit: 50 }
        });
        setStripeTransactions(transactionsResponse.data.transactions || []);
      } catch (error: any) {
        if (error.response?.status !== 404) {
          console.error('Error loading Stripe transactions:', error);
        }
      }
      
      // 获取仪表板链接（如果还没有）
      if (!stripeDashboardUrl) {
        try {
          const detailsResponse = await api.get('/api/stripe/connect/account/details');
          if (detailsResponse.data && detailsResponse.data.dashboard_url) {
            setStripeDashboardUrl(detailsResponse.data.dashboard_url);
          }
        } catch (error: any) {
          // 获取仪表板链接失败，不影响其他功能
        }
      }
    } catch (error) {
      console.error('Error loading Stripe data:', error);
    } finally {
      setStripeLoading(false);
    }
  };

  const handleWithdraw = () => {
    alert(t('wallet.withdrawComingSoon'));
  };

  const handleRecharge = () => {
    alert(t('wallet.depositComingSoon'));
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
        加载中...
      </div>
    );
  }

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '20px'
    }}>
      <div style={{ 
        maxWidth: '800px', 
        margin: '0 auto',
        background: '#fff',
        borderRadius: '16px',
        boxShadow: '0 8px 32px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {/* 头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: '#fff',
          padding: '30px',
          textAlign: 'center',
          position: 'relative'
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: 'absolute',
              left: '20px',
              top: '20px',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: '8px 12px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: '18px',
              width: '40px',
              height: '40px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            ←
          </button>
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
          }}>💰 我的钱包</h1>
          
          {/* 标签页切换 */}
          <div style={{
            display: 'flex',
            gap: '10px',
            justifyContent: 'center',
            marginBottom: '20px',
            flexWrap: 'wrap'
          }}>
            <button
              onClick={() => setActiveTab('balance')}
              style={{
                background: activeTab === 'balance' ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.1)',
                border: 'none',
                color: '#fff',
                padding: '8px 20px',
                borderRadius: '20px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: activeTab === 'balance' ? 'bold' : 'normal',
                transition: 'all 0.3s ease'
              }}
            >
              💰 {t('wallet.balance')}
            </button>
            <button
              onClick={() => setActiveTab('points')}
              style={{
                background: activeTab === 'points' ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.1)',
                border: 'none',
                color: '#fff',
                padding: '8px 20px',
                borderRadius: '20px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: activeTab === 'points' ? 'bold' : 'normal',
                transition: 'all 0.3s ease'
              }}
            >
              ⭐ {t('wallet.points')}
            </button>
            {hasStripeAccount && (
              <button
                onClick={() => setActiveTab('stripe')}
                style={{
                  background: activeTab === 'stripe' ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.1)',
                  border: 'none',
                  color: '#fff',
                  padding: '8px 20px',
                  borderRadius: '20px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: activeTab === 'stripe' ? 'bold' : 'normal',
                  transition: 'all 0.3s ease'
                }}
              >
                💳 Stripe 账户
              </button>
            )}
          </div>

          {/* 余额显示 */}
          {activeTab === 'balance' && (
            <>
              <div style={{ fontSize: '48px', fontWeight: 'bold', marginBottom: '10px' }}>
                £{balance.toFixed(2)}
              </div>
              <div style={{ fontSize: '16px', opacity: 0.9 }}>{t('wallet.currentBalance')}</div>
            </>
          )}

          {/* Stripe 余额显示 */}
          {activeTab === 'stripe' && (
            <>
              {stripeLoading ? (
                <div style={{ fontSize: '16px', opacity: 0.9 }}>加载中...</div>
              ) : stripeBalance ? (
                <>
                  <div style={{ fontSize: '48px', fontWeight: 'bold', marginBottom: '10px' }}>
                    {stripeBalance.currency === 'GBP' ? '£' : stripeBalance.currency}{stripeBalance.total.toFixed(2)}
                  </div>
                  <div style={{ fontSize: '16px', opacity: 0.9, marginBottom: '8px' }}>
                    Stripe 账户余额
                  </div>
                  <div style={{ fontSize: '14px', opacity: 0.8 }}>
                    可用: {stripeBalance.currency === 'GBP' ? '£' : stripeBalance.currency}{stripeBalance.available.toFixed(2)} | 
                    待处理: {stripeBalance.currency === 'GBP' ? '£' : stripeBalance.currency}{stripeBalance.pending.toFixed(2)}
                  </div>
                </>
              ) : (
                <div style={{ fontSize: '16px', opacity: 0.9 }}>暂无余额信息</div>
              )}
            </>
          )}

          {/* 积分显示 */}
          {activeTab === 'points' && (
            <>
              {pointsLoading ? (
                <div style={{ fontSize: '16px', opacity: 0.9 }}>{t('common.loading')}</div>
              ) : (
                <>
                  <div style={{ fontSize: '48px', fontWeight: 'bold', marginBottom: '10px' }}>
                    {pointsAccount?.balance.toLocaleString() || 0} 积分
                  </div>
                  <div style={{ fontSize: '16px', opacity: 0.9, marginBottom: '4px' }}>
                    {t('wallet.currentPointsBalance')}
                  </div>
                  <div style={{ fontSize: '14px', opacity: 0.8 }}>
                    {t('wallet.pointsEquivalent', { amount: pointsAccount?.balance_display || '0.00' })}
                  </div>
                </>
              )}
            </>
          )}
        </div>

        {/* 操作按钮 - 仅余额标签页显示 */}
        {activeTab === 'balance' && (
          <div style={{ 
            padding: '30px',
            display: 'flex',
            gap: '20px',
            justifyContent: 'center'
          }}>
            <button
              onClick={handleRecharge}
              style={{
                background: 'linear-gradient(135deg, #4CAF50, #45a049)',
                color: '#fff',
                border: 'none',
                padding: '15px 30px',
                borderRadius: '25px',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: 'pointer',
                boxShadow: '0 4px 15px rgba(76, 175, 80, 0.3)',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 6px 20px rgba(76, 175, 80, 0.4)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 4px 15px rgba(76, 175, 80, 0.3)';
              }}
            >
              💳 {t('wallet.deposit')}
            </button>
            <button
              onClick={handleWithdraw}
              style={{
                background: 'linear-gradient(135deg, #FF9800, #F57C00)',
                color: '#fff',
                border: 'none',
                padding: '15px 30px',
                borderRadius: '25px',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: 'pointer',
                boxShadow: '0 4px 15px rgba(255, 152, 0, 0.3)',
                transition: 'all 0.3s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 6px 20px rgba(255, 152, 0, 0.4)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 4px 15px rgba(255, 152, 0, 0.3)';
              }}
            >
              💸 {t('wallet.withdraw')}
            </button>
          </div>
        )}

        {/* Stripe 操作按钮 */}
        {activeTab === 'stripe' && stripeDashboardUrl && (
          <div style={{ 
            padding: '30px',
            display: 'flex',
            gap: '20px',
            justifyContent: 'center'
          }}>
            <a
              href={stripeDashboardUrl}
              target="_blank"
              rel="noopener noreferrer"
              style={{
                background: 'linear-gradient(135deg, #635BFF, #4f46e5)',
                color: '#fff',
                border: 'none',
                padding: '15px 30px',
                borderRadius: '25px',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: 'pointer',
                textDecoration: 'none',
                boxShadow: '0 4px 15px rgba(99, 91, 255, 0.3)',
                transition: 'all 0.3s ease',
                display: 'inline-block'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)';
                e.currentTarget.style.boxShadow = '0 6px 20px rgba(99, 91, 255, 0.4)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)';
                e.currentTarget.style.boxShadow = '0 4px 15px rgba(99, 91, 255, 0.3)';
              }}
            >
              🔗 打开 Stripe 仪表板
            </a>
          </div>
        )}

        {/* 积分统计信息 - 仅积分标签页显示 */}
        {activeTab === 'points' && pointsAccount && (
          <div style={{ 
            padding: '20px 30px',
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: '20px',
            background: '#f8f9fa',
            borderBottom: '1px solid #e9ecef'
          }}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#4CAF50', marginBottom: '4px' }}>
                +{(pointsAccount.total_earned / 100).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div style={{ fontSize: '14px', color: '#666' }}>累计获得</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#FF9800', marginBottom: '4px' }}>
                -{(pointsAccount.total_spent / 100).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div style={{ fontSize: '14px', color: '#666' }}>累计消费</div>
            </div>
          </div>
        )}

        {/* 交易记录 */}
        <div style={{ padding: '0 30px 30px 30px' }}>
          <h2 style={{ 
            color: '#333', 
            marginBottom: '20px', 
            fontSize: '20px',
            fontWeight: 'bold'
          }}>
            📊 {
              activeTab === 'balance' ? '交易记录' : 
              activeTab === 'points' ? '积分交易记录' : 
              'Stripe 交易记录'
            }
          </h2>
          
          {/* 余额交易记录 */}
          {activeTab === 'balance' && (
            <>
              {transactions.length === 0 ? (
                <div style={{
                  textAlign: 'center',
                  padding: '40px',
                  color: '#666',
                  fontSize: '16px'
                }}>
                  暂无交易记录
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {transactions.map((transaction) => (
                    <div
                      key={transaction.id}
                      style={{
                        background: '#f8f9fa',
                        padding: '16px',
                        borderRadius: '12px',
                        border: '1px solid #e9ecef',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{
                          width: '40px',
                          height: '40px',
                          borderRadius: '50%',
                          background: transaction.type === 'income' 
                            ? 'linear-gradient(135deg, #4CAF50, #45a049)' 
                            : 'linear-gradient(135deg, #FF9800, #F57C00)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: '#fff',
                          fontSize: '18px'
                        }}>
                          {transaction.type === 'income' ? '💰' : '💸'}
                        </div>
                        <div>
                          <div style={{ 
                            fontWeight: 'bold', 
                            color: '#333',
                            marginBottom: '4px'
                          }}>
                            {transaction.description}
                          </div>
                          <div style={{ 
                            fontSize: '14px', 
                            color: '#666' 
                          }}>
                            {transaction.date}
                          </div>
                        </div>
                      </div>
                      <div style={{
                        textAlign: 'right'
                      }}>
                        <div style={{
                          fontWeight: 'bold',
                          fontSize: '16px',
                          color: transaction.type === 'income' ? '#4CAF50' : '#FF9800'
                        }}>
                          {transaction.type === 'income' ? '+' : '-'}£{transaction.amount.toFixed(2)}
                        </div>
                        <div style={{
                          fontSize: '12px',
                          color: '#666',
                          textTransform: 'capitalize'
                        }}>
                          {transaction.status}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}

          {/* Stripe 交易记录 */}
          {activeTab === 'stripe' && (
            <>
              {stripeLoading ? (
                <div style={{
                  textAlign: 'center',
                  padding: '40px',
                  color: '#666',
                  fontSize: '16px'
                }}>
                  加载中...
                </div>
              ) : stripeTransactions.length === 0 ? (
                <div style={{
                  textAlign: 'center',
                  padding: '40px',
                  color: '#666',
                  fontSize: '16px'
                }}>
                  暂无 Stripe 交易记录
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {stripeTransactions.map((transaction) => {
                    const isIncome = transaction.type === 'income';
                    const color = isIncome ? '#4CAF50' : '#FF9800';
                    const icon = isIncome ? '💰' : '💸';
                    const statusColor = transaction.status === 'succeeded' ? '#4CAF50' : 
                                       transaction.status === 'pending' ? '#FF9800' : '#9E9E9E';
                    
                    return (
                      <div
                        key={transaction.id}
                        style={{
                          background: '#f8f9fa',
                          padding: '16px',
                          borderRadius: '12px',
                          border: '1px solid #e9ecef',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center'
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{
                            width: '40px',
                            height: '40px',
                            borderRadius: '50%',
                            background: `linear-gradient(135deg, ${color}, ${color}dd)`,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: '#fff',
                            fontSize: '18px'
                          }}>
                            {icon}
                          </div>
                          <div>
                            <div style={{ 
                              fontWeight: 'bold', 
                              color: '#333',
                              marginBottom: '4px'
                            }}>
                              {transaction.description}
                            </div>
                            <div style={{ 
                              fontSize: '14px', 
                              color: '#666',
                              display: 'flex',
                              gap: '8px',
                              alignItems: 'center'
                            }}>
                              <span>
                                {new Date(transaction.created_at).toLocaleString('zh-CN', {
                                  year: 'numeric',
                                  month: '2-digit',
                                  day: '2-digit',
                                  hour: '2-digit',
                                  minute: '2-digit'
                                })}
                              </span>
                              <span style={{
                                padding: '2px 6px',
                                borderRadius: '4px',
                                fontSize: '11px',
                                backgroundColor: statusColor + '20',
                                color: statusColor,
                                fontWeight: '600'
                              }}>
                                {transaction.status === 'succeeded' ? '成功' : 
                                 transaction.status === 'pending' ? '待处理' : 
                                 transaction.status === 'reversed' ? '已撤销' : transaction.status}
                              </span>
                            </div>
                          </div>
                        </div>
                        <div style={{
                          textAlign: 'right'
                        }}>
                          <div style={{
                            fontWeight: 'bold',
                            fontSize: '16px',
                            color: color
                          }}>
                            {isIncome ? '+' : '-'}{transaction.currency === 'GBP' ? '£' : transaction.currency}{transaction.amount.toFixed(2)}
                          </div>
                          <div style={{
                            fontSize: '12px',
                            color: '#666',
                            textTransform: 'capitalize'
                          }}>
                            {transaction.source === 'charge' ? '收款' : 
                             transaction.source === 'transfer' ? '转账' : 
                             transaction.source === 'payout' ? '提现' : transaction.source}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </>
          )}

          {/* 积分交易记录 */}
          {activeTab === 'points' && (
            <>
              {pointsLoading ? (
                <div style={{
                  textAlign: 'center',
                  padding: '40px',
                  color: '#666',
                  fontSize: '16px'
                }}>
                  加载中...
                </div>
              ) : pointsTransactions.length === 0 ? (
                <div style={{
                  textAlign: 'center',
                  padding: '40px',
                  color: '#666',
                  fontSize: '16px'
                }}>
                  暂无积分交易记录
                </div>
              ) : (
                <>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {pointsTransactions.map((transaction) => {
                      const isPositive = transaction.type === 'earn' || transaction.type === 'refund';
                      const color = transaction.type === 'earn' ? '#4CAF50' : 
                                   transaction.type === 'spend' ? '#FF9800' :
                                   transaction.type === 'refund' ? '#2196F3' : '#9E9E9E';
                      const icon = transaction.type === 'earn' ? '💰' : 
                                  transaction.type === 'spend' ? '💸' :
                                  transaction.type === 'refund' ? '↩️' : '⏰';
                      const typeText = transaction.type === 'earn' ? '获得' : 
                                      transaction.type === 'spend' ? '消费' :
                                      transaction.type === 'refund' ? '退还' : '过期';
                      
                      return (
                        <div
                          key={transaction.id}
                          style={{
                            background: '#f8f9fa',
                            padding: '16px',
                            borderRadius: '12px',
                            border: '1px solid #e9ecef',
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center'
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div style={{
                              width: '40px',
                              height: '40px',
                              borderRadius: '50%',
                              background: `linear-gradient(135deg, ${color}, ${color}dd)`,
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              color: '#fff',
                              fontSize: '18px'
                            }}>
                              {icon}
                            </div>
                            <div>
                              <div style={{ 
                                fontWeight: 'bold', 
                                color: '#333',
                                marginBottom: '4px'
                              }}>
                                {transaction.description || `${typeText}积分`}
                              </div>
                              <div style={{ 
                                fontSize: '14px', 
                                color: '#666' 
                              }}>
                                {new Date(transaction.created_at).toLocaleString('zh-CN', {
                                  year: 'numeric',
                                  month: '2-digit',
                                  day: '2-digit',
                                  hour: '2-digit',
                                  minute: '2-digit'
                                })}
                              </div>
                            </div>
                          </div>
                          <div style={{
                            textAlign: 'right'
                          }}>
                            <div style={{
                              fontWeight: 'bold',
                              fontSize: '16px',
                              color: color
                            }}>
                              {isPositive ? '+' : '-'}{Math.abs(transaction.amount).toLocaleString()} 积分
                            </div>
                            <div style={{
                              fontSize: '12px',
                              color: '#666'
                            }}>
                              余额: {transaction.balance_after.toLocaleString()} 积分
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                  
                  {/* 分页 */}
                  {pointsTotal > 20 && (
                    <div style={{
                      display: 'flex',
                      justifyContent: 'center',
                      alignItems: 'center',
                      gap: '10px',
                      marginTop: '20px'
                    }}>
                      <button
                        onClick={() => setPointsPage(prev => Math.max(1, prev - 1))}
                        disabled={pointsPage === 1}
                        style={{
                          padding: '8px 16px',
                          border: '1px solid #ddd',
                          borderRadius: '4px',
                          background: pointsPage === 1 ? '#f5f5f5' : '#fff',
                          cursor: pointsPage === 1 ? 'not-allowed' : 'pointer',
                          color: pointsPage === 1 ? '#999' : '#333'
                        }}
                      >
                        上一页
                      </button>
                      <span style={{ color: '#666' }}>
                        第 {pointsPage} 页，共 {Math.ceil(pointsTotal / 20)} 页
                      </span>
                      <button
                        onClick={() => setPointsPage(prev => prev + 1)}
                        disabled={pointsPage >= Math.ceil(pointsTotal / 20)}
                        style={{
                          padding: '8px 16px',
                          border: '1px solid #ddd',
                          borderRadius: '4px',
                          background: pointsPage >= Math.ceil(pointsTotal / 20) ? '#f5f5f5' : '#fff',
                          cursor: pointsPage >= Math.ceil(pointsTotal / 20) ? 'not-allowed' : 'pointer',
                          color: pointsPage >= Math.ceil(pointsTotal / 20) ? '#999' : '#333'
                        }}
                      >
                        下一页
                      </button>
                    </div>
                  )}
                </>
              )}
            </>
          )}
        </div>

        {/* 说明 */}
        <div style={{
          background: '#f8f9fa',
          padding: '20px 30px',
          borderTop: '1px solid #e9ecef'
        }}>
          {activeTab === 'balance' ? (
            <>
              <h3 style={{ 
                color: '#333', 
                marginBottom: '10px', 
                fontSize: '16px',
                fontWeight: 'bold'
              }}>
                💡 钱包说明
              </h3>
              <ul style={{ 
                color: '#666', 
                fontSize: '14px', 
                lineHeight: '1.6',
                margin: 0,
                paddingLeft: '20px'
              }}>
                <li>完成任务可获得相应报酬</li>
                <li>发布任务需要支付少量费用</li>
                <li>余额可用于发布任务或提现</li>
                <li>所有交易记录都会在此显示</li>
              </ul>
            </>
          ) : activeTab === 'stripe' ? (
            <>
              <h3 style={{ 
                color: '#333', 
                marginBottom: '10px', 
                fontSize: '16px',
                fontWeight: 'bold'
              }}>
                💡 Stripe 账户说明
              </h3>
              <ul style={{ 
                color: '#666', 
                fontSize: '14px', 
                lineHeight: '1.6',
                margin: 0,
                paddingLeft: '20px'
              }}>
                <li>Stripe 账户用于接收任务奖励和提现</li>
                <li>可用余额可以立即提现到银行账户</li>
                <li>待处理余额需要等待 Stripe 处理完成后才能提现</li>
                <li>所有收入和支出记录都会在此显示</li>
                <li>点击"打开 Stripe 仪表板"可查看更详细的交易信息</li>
              </ul>
            </>
          ) : (
            <>
              <h3 style={{ 
                color: '#333', 
                marginBottom: '10px', 
                fontSize: '16px',
                fontWeight: 'bold'
              }}>
                💡 积分说明
              </h3>
              <div style={{ 
                color: '#666', 
                fontSize: '14px', 
                lineHeight: '1.8',
                marginBottom: '15px'
              }}>
                <div style={{ marginBottom: '8px' }}>
                  <strong>积分规则：</strong>100积分 = £1.00（等值参考，积分不是货币）
                </div>
                <div style={{ marginBottom: '8px' }}>
                  <strong>积分用途：</strong>
                </div>
                <ul style={{ margin: '0 0 8px 20px', padding: 0 }}>
                  {pointsAccount?.usage_restrictions.allowed.map((item, index) => (
                    <li key={index}>{item}</li>
                  ))}
                </ul>
                <div style={{ marginBottom: '8px' }}>
                  <strong>积分限制：</strong>
                </div>
                <ul style={{ margin: '0 0 0 20px', padding: 0 }}>
                  {pointsAccount?.usage_restrictions.forbidden.map((item, index) => (
                    <li key={index} style={{ color: '#d32f2f' }}>{item}</li>
                  ))}
                </ul>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default Wallet;
