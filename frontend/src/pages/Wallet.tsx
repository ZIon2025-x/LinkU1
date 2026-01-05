import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchCurrentUser, getPointsAccount, getPointsTransactions } from '../api';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useStripeConnect } from '../hooks/useStripeConnect';
import {
  ConnectComponentsProvider,
  ConnectPayouts,
} from '@stripe/react-connect-js';

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
  const [activeTab, setActiveTab] = useState<'balance' | 'points'>('balance');  // 当前标签页
  const [loading, setLoading] = useState(true);
  const [pointsLoading, setPointsLoading] = useState(false);
  const [pointsPage, setPointsPage] = useState(1);
  const [pointsTotal, setPointsTotal] = useState(0);
  const [isMobile, setIsMobile] = useState(false);
  
  // Stripe 相关状态
  const [hasStripeAccount, setHasStripeAccount] = useState(false);
  const [stripeAccountId, setStripeAccountId] = useState<string | null>(null);
  // 启用 payouts 组件（用于钱包页面显示余额和提现功能）
  const stripeConnectInstance = useStripeConnect(stripeAccountId, true);

  // 检测移动端
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

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
        setStripeAccountId(response.data.account_id);
      }
    } catch (error) {
      // 没有账户是正常的
      setHasStripeAccount(false);
      setStripeAccountId(null);
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
        加载中...
      </div>
    );
  }

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#f8fafc',
      padding: isMobile ? '16px' : '24px'
    }}>
      <div style={{ 
        maxWidth: '900px', 
        margin: '0 auto',
        background: '#fff',
        borderRadius: '20px',
        boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
        border: '1px solid #e2e8f0',
        overflow: 'hidden'
      }}>
        {/* 头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: '#fff',
          padding: isMobile ? '24px 20px' : '32px 30px',
          textAlign: 'center',
          position: 'relative'
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: 'absolute',
              left: isMobile ? '16px' : '24px',
              top: isMobile ? '20px' : '24px',
              background: 'rgba(255,255,255,0.15)',
              border: 'none',
              color: '#fff',
              padding: '0',
              borderRadius: '12px',
              cursor: 'pointer',
              fontSize: '20px',
              width: '40px',
              height: '40px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'all 0.2s ease',
              backdropFilter: 'blur(10px)'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.25)';
              e.currentTarget.style.transform = 'scale(1.05)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.15)';
              e.currentTarget.style.transform = 'scale(1)';
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
            gap: '8px',
            justifyContent: 'center',
            marginBottom: '24px',
            flexWrap: 'wrap'
          }}>
            <button
              onClick={() => setActiveTab('balance')}
              style={{
                background: activeTab === 'balance' ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.1)',
                border: 'none',
                color: '#fff',
                padding: '10px 24px',
                borderRadius: '12px',
                cursor: 'pointer',
                fontSize: '15px',
                fontWeight: activeTab === 'balance' ? '600' : '500',
                transition: 'all 0.2s ease',
                backdropFilter: 'blur(10px)'
              }}
              onMouseEnter={(e) => {
                if (activeTab !== 'balance') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                }
              }}
              onMouseLeave={(e) => {
                if (activeTab !== 'balance') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.1)';
                }
              }}
            >
              💰 {t('wallet.balance')}
            </button>
            <button
              onClick={() => setActiveTab('points')}
              style={{
                background: activeTab === 'points' ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.1)',
                border: 'none',
                color: '#fff',
                padding: '10px 24px',
                borderRadius: '12px',
                cursor: 'pointer',
                fontSize: '15px',
                fontWeight: activeTab === 'points' ? '600' : '500',
                transition: 'all 0.2s ease',
                backdropFilter: 'blur(10px)'
              }}
              onMouseEnter={(e) => {
                if (activeTab !== 'points') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                }
              }}
              onMouseLeave={(e) => {
                if (activeTab !== 'points') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.1)';
                }
              }}
            >
              ⭐ {t('wallet.points')}
            </button>
          </div>

          {/* 余额显示 */}
          {activeTab === 'balance' && (
            <>
              {hasStripeAccount && stripeConnectInstance ? (
                <div style={{ 
                  fontSize: '15px', 
                  opacity: 0.95, 
                  marginBottom: '8px',
                  fontWeight: '500'
                }}>
                  Stripe 账户余额
                </div>
              ) : (
                <>
                  <div style={{ 
                    fontSize: isMobile ? '40px' : '48px', 
                    fontWeight: '700', 
                    marginBottom: '8px',
                    letterSpacing: '-0.5px'
                  }}>
                    £{balance.toFixed(2)}
                  </div>
                  <div style={{ 
                    fontSize: '15px', 
                    opacity: 0.9,
                    fontWeight: '400'
                  }}>
                    {t('wallet.currentBalance')}
                  </div>
                </>
              )}
            </>
          )}

          {/* 积分显示 */}
          {activeTab === 'points' && (
            <>
              {pointsLoading ? (
                <div style={{ 
                  fontSize: '15px', 
                  opacity: 0.9,
                  fontWeight: '400'
                }}>
                  {t('common.loading')}
                </div>
              ) : (
                <>
                  <div style={{ 
                    fontSize: isMobile ? '40px' : '48px', 
                    fontWeight: '700', 
                    marginBottom: '8px',
                    letterSpacing: '-0.5px'
                  }}>
                    {pointsAccount?.balance.toLocaleString() || 0} 积分
                  </div>
                  <div style={{ 
                    fontSize: '15px', 
                    opacity: 0.9, 
                    marginBottom: '4px',
                    fontWeight: '400'
                  }}>
                    {t('wallet.currentPointsBalance')}
                  </div>
                  <div style={{ 
                    fontSize: '14px', 
                    opacity: 0.8,
                    fontWeight: '400'
                  }}>
                    {t('wallet.pointsEquivalent', { amount: pointsAccount?.balance_display || '0.00' })}
                  </div>
                </>
              )}
            </>
          )}
        </div>

        {/* Stripe Payouts 组件 - 仅余额标签页显示，如果有 Stripe 账户 */}
        {activeTab === 'balance' && hasStripeAccount && stripeConnectInstance && (
          <div style={{ 
            padding: isMobile ? '20px' : '32px',
            background: '#fafbfc',
            borderTop: '1px solid #e2e8f0'
          }}>
            <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
              <ConnectPayouts />
            </ConnectComponentsProvider>
          </div>
        )}

        {/* 积分统计信息 - 仅积分标签页显示 */}
        {activeTab === 'points' && pointsAccount && (
          <div style={{ 
            padding: isMobile ? '20px' : '24px 32px',
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: '16px',
            background: '#fafbfc',
            borderTop: '1px solid #e2e8f0',
            borderBottom: '1px solid #e2e8f0'
          }}>
            <div style={{ 
              textAlign: 'center',
              padding: '16px',
              background: '#fff',
              borderRadius: '12px',
              border: '1px solid #e2e8f0'
            }}>
              <div style={{ 
                fontSize: '22px', 
                fontWeight: '700', 
                color: '#10b981', 
                marginBottom: '6px',
                letterSpacing: '-0.3px'
              }}>
                +{(pointsAccount.total_earned / 100).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div style={{ 
                fontSize: '13px', 
                color: '#64748b',
                fontWeight: '500'
              }}>
                累计获得
              </div>
            </div>
            <div style={{ 
              textAlign: 'center',
              padding: '16px',
              background: '#fff',
              borderRadius: '12px',
              border: '1px solid #e2e8f0'
            }}>
              <div style={{ 
                fontSize: '22px', 
                fontWeight: '700', 
                color: '#f59e0b', 
                marginBottom: '6px',
                letterSpacing: '-0.3px'
              }}>
                -{(pointsAccount.total_spent / 100).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div style={{ 
                fontSize: '13px', 
                color: '#64748b',
                fontWeight: '500'
              }}>
                累计消费
              </div>
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
              activeTab === 'balance' ? (hasStripeAccount ? 'Stripe 余额与交易' : '交易记录') : 
              '积分交易记录'
            }
          </h2>
          
          {/* 余额交易记录 - 如果没有 Stripe 账户，显示普通交易记录 */}
          {activeTab === 'balance' && !hasStripeAccount && (
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
                        background: '#fff',
                        padding: '16px',
                        borderRadius: '12px',
                        border: '1px solid #e2e8f0',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        transition: 'all 0.2s ease',
                        cursor: 'pointer'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.borderColor = '#cbd5e1';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.04)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.borderColor = '#e2e8f0';
                        e.currentTarget.style.boxShadow = 'none';
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{
                          width: '44px',
                          height: '44px',
                          borderRadius: '12px',
                          background: transaction.type === 'income' 
                            ? 'linear-gradient(135deg, #10b981, #059669)' 
                            : 'linear-gradient(135deg, #f59e0b, #d97706)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: '#fff',
                          fontSize: '20px',
                          flexShrink: 0
                        }}>
                          {transaction.type === 'income' ? '💰' : '💸'}
                        </div>
                        <div>
                          <div style={{ 
                            fontWeight: '600', 
                            color: '#1a202c',
                            marginBottom: '4px',
                            fontSize: '15px'
                          }}>
                            {transaction.description}
                          </div>
                          <div style={{ 
                            fontSize: '13px', 
                            color: '#64748b',
                            fontWeight: '400'
                          }}>
                            {transaction.date}
                          </div>
                        </div>
                      </div>
                      <div style={{
                        textAlign: 'right',
                        flexShrink: 0
                      }}>
                        <div style={{
                          fontWeight: '700',
                          fontSize: '16px',
                          color: transaction.type === 'income' ? '#10b981' : '#f59e0b',
                          marginBottom: '4px',
                          letterSpacing: '-0.2px'
                        }}>
                          {transaction.type === 'income' ? '+' : '-'}£{transaction.amount.toFixed(2)}
                        </div>
                        <div style={{
                          fontSize: '12px',
                          color: '#94a3b8',
                          fontWeight: '400',
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
                            background: '#fff',
                            padding: '16px',
                            borderRadius: '12px',
                            border: '1px solid #e2e8f0',
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            transition: 'all 0.2s ease',
                            cursor: 'pointer'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.borderColor = '#cbd5e1';
                            e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.04)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.borderColor = '#e2e8f0';
                            e.currentTarget.style.boxShadow = 'none';
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div style={{
                              width: '44px',
                              height: '44px',
                              borderRadius: '12px',
                              background: color === '#4CAF50' ? 'linear-gradient(135deg, #4CAF50, #45a049)' :
                                        color === '#FF9800' ? 'linear-gradient(135deg, #FF9800, #f57c00)' :
                                        color === '#2196F3' ? 'linear-gradient(135deg, #2196F3, #1976d2)' :
                                        'linear-gradient(135deg, #94a3b8, #64748b)',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              color: '#fff',
                              fontSize: '20px',
                              flexShrink: 0
                            }}>
                              {icon}
                            </div>
                            <div>
                              <div style={{ 
                                fontWeight: '600', 
                                color: '#1a202c',
                                marginBottom: '4px',
                                fontSize: '15px'
                              }}>
                                {transaction.description || `${typeText}积分`}
                              </div>
                              <div style={{ 
                                fontSize: '13px', 
                                color: '#64748b',
                                fontWeight: '400'
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
                            textAlign: 'right',
                            flexShrink: 0
                          }}>
                            <div style={{
                              fontWeight: '700',
                              fontSize: '16px',
                              color: color,
                              marginBottom: '4px',
                              letterSpacing: '-0.2px'
                            }}>
                              {isPositive ? '+' : '-'}{Math.abs(transaction.amount).toLocaleString()} 积分
                            </div>
                            <div style={{
                              fontSize: '12px',
                              color: '#94a3b8',
                              fontWeight: '400'
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
          background: '#fafbfc',
          padding: isMobile ? '20px' : '24px 30px',
          borderTop: '1px solid #e2e8f0'
        }}>
          {activeTab === 'balance' ? (
            <>
              <h3 style={{ 
                color: '#1a202c', 
                marginBottom: '12px', 
                fontSize: '15px',
                fontWeight: '600'
              }}>
                {hasStripeAccount ? 'Stripe 账户说明' : '钱包说明'}
              </h3>
              <ul style={{ 
                color: '#64748b', 
                fontSize: '14px', 
                lineHeight: '1.7',
                margin: 0,
                paddingLeft: '20px',
                listStyle: 'none'
              }}>
                {hasStripeAccount ? (
                  <>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      Stripe 账户用于接收任务奖励
                    </li>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      可用余额可以立即提现到银行账户
                    </li>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      待处理余额需要等待 Stripe 处理完成后才能提现
                    </li>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      所有收入和支出记录都会在此显示
                    </li>
                    <li style={{ position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      您可以在余额组件中直接管理提现
                    </li>
                  </>
                ) : (
                  <>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      完成任务可获得相应报酬
                    </li>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      发布任务需要支付少量费用
                    </li>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      余额可用于发布任务或提现
                    </li>
                    <li style={{ position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      所有交易记录都会在此显示
                    </li>
                  </>
                )}
              </ul>
            </>
          ) : (
            <>
              <h3 style={{ 
                color: '#1a202c', 
                marginBottom: '12px', 
                fontSize: '15px',
                fontWeight: '600'
              }}>
                积分说明
              </h3>
              <div style={{ 
                color: '#64748b', 
                fontSize: '14px', 
                lineHeight: '1.7'
              }}>
                <div style={{ marginBottom: '12px' }}>
                  <strong style={{ color: '#1a202c' }}>积分规则：</strong>
                  <span style={{ marginLeft: '4px' }}>100积分 = £1.00（等值参考，积分不是货币）</span>
                </div>
                <div style={{ marginBottom: '8px' }}>
                  <strong style={{ color: '#1a202c' }}>积分用途：</strong>
                </div>
                <ul style={{ 
                  margin: '0 0 12px 20px', 
                  padding: 0,
                  listStyle: 'none'
                }}>
                  {pointsAccount?.usage_restrictions.allowed.map((item, index) => (
                    <li key={index} style={{ 
                      marginBottom: '4px',
                      position: 'relative',
                      paddingLeft: '20px'
                    }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      {item}
                    </li>
                  ))}
                </ul>
                <div style={{ marginBottom: '8px' }}>
                  <strong style={{ color: '#1a202c' }}>积分限制：</strong>
                </div>
                <ul style={{ 
                  margin: '0 0 0 20px', 
                  padding: 0,
                  listStyle: 'none'
                }}>
                  {pointsAccount?.usage_restrictions.forbidden.map((item, index) => (
                    <li key={index} style={{ 
                      color: '#ef4444',
                      marginBottom: '4px',
                      position: 'relative',
                      paddingLeft: '20px'
                    }}>
                      <span style={{ position: 'absolute', left: '0', color: '#ef4444' }}>•</span>
                      {item}
                    </li>
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
