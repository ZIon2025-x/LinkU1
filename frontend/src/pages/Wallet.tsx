import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getPointsAccount, getPointsTransactions, getStripeAccountTransactions, getStripeAccountBalance, getPaymentHistory } from '../api';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useStripeConnect } from '../hooks/useStripeConnect';
import {
  ConnectComponentsProvider,
  ConnectPayouts,
  ConnectPayments,
} from '@stripe/react-connect-js';
import SEOHead from '../components/SEOHead';

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
  const { t, language } = useLanguage();
  const [balance, setBalance] = useState(0);  // 钱包余额（金额）
  const [transactions, setTransactions] = useState<any[]>([]);  // 钱包交易记录
  const [transactionsLoading, setTransactionsLoading] = useState(false);  // 交易记录加载状态
  const [, setTransactionsTotal] = useState(0); void setTransactionsTotal;  // 交易记录总数
  const [pointsAccount, setPointsAccount] = useState<PointsAccount | null>(null);  // 积分账户
  const [pointsTransactions, setPointsTransactions] = useState<PointsTransaction[]>([]);  // 积分交易记录
  const [activeTab, setActiveTab] = useState<'balance' | 'points'>('balance');  // 当前标签页
  const [loading, setLoading] = useState(true);
  const [pointsLoading, setPointsLoading] = useState(false);
  const [pointsPage, setPointsPage] = useState(1);
  const [pointsTotal, setPointsTotal] = useState(0);
  const [isMobile, setIsMobile] = useState(false);
  
  // Stripe 相关状态
  const [hasStripeAccount, setHasStripeAccount] = useState<boolean | null>(null);  // null 表示未检查
  const [stripeAccountId, setStripeAccountId] = useState<string | null>(null);
  // 启用 payouts 和 payments 组件（用于钱包页面显示余额、提现和支付列表）
  const stripeConnectInstance = useStripeConnect(stripeAccountId, true, false, false, true);

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
    // 检查是否有 Stripe 账户（先检查，因为其他加载依赖这个状态）
    checkStripeAccount();
  }, []);

  // 当 Stripe 账户状态确定后，加载数据
  useEffect(() => {
    if (hasStripeAccount !== null) {
      // 加载钱包数据
      loadWalletData();
      // 加载积分数据
      loadPointsData();
      // 如果当前在余额标签页，加载交易记录
      if (activeTab === 'balance') {
        loadWalletTransactions();
      }
    }
  }, [hasStripeAccount, stripeAccountId]);

  useEffect(() => {
    if (activeTab === 'points' && pointsAccount) {
      loadPointsTransactions();
    } else if (activeTab === 'balance') {
      loadWalletTransactions();
    }
  }, [activeTab, pointsPage, hasStripeAccount]);

  const loadWalletData = async () => {
    try {
      // 如果有 Stripe 账户，获取余额
      if (hasStripeAccount && stripeAccountId) {
        try {
          const balanceData = await getStripeAccountBalance();
          // Stripe 余额以分为单位，需要转换为元
          const available = balanceData.available?.reduce((sum: number, item: any) => sum + (item.amount || 0), 0) || 0;
          setBalance(available / 100);
        } catch (error) {
          console.error('Error loading Stripe balance:', error);
          setBalance(0);
        }
      } else {
        // 没有 Stripe 账户时，余额为 0
        setBalance(0);
      }
    } catch (error) {
      console.error('Error loading wallet data:', error);
      setBalance(0);
    }
  };

  // 加载钱包交易记录
  const loadWalletTransactions = async () => {
    try {
      setTransactionsLoading(true);
      
      if (hasStripeAccount && stripeAccountId) {
        // 如果有 Stripe 账户，加载 Stripe 交易记录
        try {
          const result = await getStripeAccountTransactions({ limit: 50 });
          const formattedTransactions = (result.transactions || []).map((tx: any) => ({
            id: tx.id,
            type: tx.type === 'income' ? 'income' : 'expense',
            amount: tx.amount,
            currency: tx.currency || 'GBP',
            description: tx.description || (tx.type === 'income' ? t('wallet.transactionIncome') : t('wallet.transactionExpense')),
            date: new Date(tx.created_at).toLocaleString(language === 'zh' ? 'zh-CN' : 'en-GB', {
              year: 'numeric',
              month: '2-digit',
              day: '2-digit',
              hour: '2-digit',
              minute: '2-digit'
            }),
            status: tx.status || 'completed',
            source: tx.source || 'stripe'
          }));
          setTransactions(formattedTransactions);
          setTransactionsTotal(result.total || formattedTransactions.length);
        } catch (error: any) {
          console.error('Error loading Stripe transactions:', error);
          // 如果加载失败，尝试加载支付历史记录作为备选
          try {
            const paymentHistory = await getPaymentHistory({ limit: 50 });
            const formattedPayments = (paymentHistory.payments || []).map((payment: any) => ({
              id: payment.id,
              type: 'expense',
              amount: payment.final_amount / 100,
              currency: payment.currency || 'GBP',
              description: payment.task ? (language === 'zh' ? `支付任务：${payment.task.title}` : `Payment for task: ${payment.task.title}`) : (language === 'zh' ? '支付' : 'Payment'),
              date: new Date(payment.created_at).toLocaleString(language === 'zh' ? 'zh-CN' : 'en-GB', {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
              }),
              status: payment.status,
              source: 'payment'
            }));
            setTransactions(formattedPayments);
            setTransactionsTotal(paymentHistory.total || formattedPayments.length);
          } catch (paymentError) {
            console.error('Error loading payment history:', paymentError);
            setTransactions([]);
            setTransactionsTotal(0);
          }
        }
      } else {
        // 没有 Stripe 账户时，加载支付历史记录
        try {
          const paymentHistory = await getPaymentHistory({ limit: 50 });
          const formattedPayments = (paymentHistory.payments || []).map((payment: any) => ({
            id: payment.id,
            type: 'expense',
            amount: payment.final_amount / 100,
            currency: payment.currency || 'GBP',
            description: payment.task ? `支付任务：${payment.task.title}` : '支付',
            date: new Date(payment.created_at).toLocaleString('zh-CN', {
              year: 'numeric',
              month: '2-digit',
              day: '2-digit',
              hour: '2-digit',
              minute: '2-digit'
            }),
            status: payment.status,
            source: 'payment'
          }));
          setTransactions(formattedPayments);
          setTransactionsTotal(paymentHistory.total || formattedPayments.length);
        } catch (error) {
          console.error('Error loading payment history:', error);
          setTransactions([]);
          setTransactionsTotal(0);
        }
      }
    } catch (error) {
      console.error('Error loading wallet transactions:', error);
      setTransactions([]);
      setTransactionsTotal(0);
    } finally {
      setTransactionsLoading(false);
    }
  };

  const loadPointsData = async () => {
    try {
      setPointsLoading(true);
      const accountData = await getPointsAccount();
      setPointsAccount(accountData);
    } catch (error) {
      console.error('加载积分账户失败:', error);
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
      console.error('加载积分交易记录失败:', error);
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
      } else {
        setHasStripeAccount(false);
        setStripeAccountId(null);
      }
    } catch (error: any) {
      // 404 表示没有账户，这是正常的
      if (error.response?.status === 404) {
        setHasStripeAccount(false);
        setStripeAccountId(null);
      } else {
        // 其他错误，也设置为 false，但记录错误
        console.error('Error checking Stripe account:', error);
        setHasStripeAccount(false);
        setStripeAccountId(null);
      }
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
      background: 'linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%)',
      padding: isMobile ? '16px' : '32px 24px',
      paddingTop: isMobile ? '20px' : '40px'
    }}>
      <SEOHead noindex={true} />
      <div style={{
        maxWidth: '1000px',
        margin: '0 auto',
        background: '#fff',
        borderRadius: '24px',
        boxShadow: '0 20px 60px rgba(0,0,0,0.12), 0 8px 24px rgba(0,0,0,0.08)',
        border: 'none',
        overflow: 'hidden'
      }}>
        {/* 头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: '#fff',
          padding: isMobile ? '28px 20px' : '40px 40px 36px',
          textAlign: 'center',
          position: 'relative',
          overflow: 'hidden'
        }}>
          {/* 装饰性背景元素 */}
          <div style={{
            position: 'absolute',
            top: '-50%',
            right: '-10%',
            width: '300px',
            height: '300px',
            background: 'rgba(255,255,255,0.1)',
            borderRadius: '50%',
            filter: 'blur(60px)'
          }} />
          <div style={{
            position: 'absolute',
            bottom: '-30%',
            left: '-5%',
            width: '200px',
            height: '200px',
            background: 'rgba(255,255,255,0.08)',
            borderRadius: '50%',
            filter: 'blur(50px)'
          }} />
          <button
            onClick={() => navigate('/')}
            style={{
              position: 'absolute',
              left: isMobile ? '16px' : '24px',
              top: isMobile ? '20px' : '24px',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: '0',
              borderRadius: '14px',
              cursor: 'pointer',
              fontSize: '22px',
              width: '44px',
              height: '44px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
              backdropFilter: 'blur(12px)',
              zIndex: 10,
              boxShadow: '0 4px 12px rgba(0,0,0,0.15)'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.3)';
              e.currentTarget.style.transform = 'scale(1.08) translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 6px 16px rgba(0,0,0,0.2)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
              e.currentTarget.style.transform = 'scale(1) translateY(0)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)';
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
            gap: '12px',
            justifyContent: 'center',
            marginBottom: '32px',
            flexWrap: 'wrap',
            position: 'relative',
            zIndex: 5
          }}>
            <button
              onClick={() => setActiveTab('balance')}
              style={{
                background: activeTab === 'balance' ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.12)',
                border: activeTab === 'balance' ? '2px solid rgba(255,255,255,0.5)' : '2px solid transparent',
                color: '#fff',
                padding: '12px 28px',
                borderRadius: '16px',
                cursor: 'pointer',
                fontSize: '15px',
                fontWeight: activeTab === 'balance' ? '700' : '500',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                backdropFilter: 'blur(12px)',
                boxShadow: activeTab === 'balance' ? '0 4px 16px rgba(0,0,0,0.2)' : 'none',
                transform: activeTab === 'balance' ? 'scale(1.05)' : 'scale(1)'
              }}
              onMouseEnter={(e) => {
                if (activeTab !== 'balance') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                  e.currentTarget.style.transform = 'scale(1.02)';
                }
              }}
              onMouseLeave={(e) => {
                if (activeTab !== 'balance') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.12)';
                  e.currentTarget.style.transform = 'scale(1)';
                }
              }}
            >
              💰 {t('wallet.balance')}
            </button>
            <button
              onClick={() => setActiveTab('points')}
              style={{
                background: activeTab === 'points' ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.12)',
                border: activeTab === 'points' ? '2px solid rgba(255,255,255,0.5)' : '2px solid transparent',
                color: '#fff',
                padding: '12px 28px',
                borderRadius: '16px',
                cursor: 'pointer',
                fontSize: '15px',
                fontWeight: activeTab === 'points' ? '700' : '500',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                backdropFilter: 'blur(12px)',
                boxShadow: activeTab === 'points' ? '0 4px 16px rgba(0,0,0,0.2)' : 'none',
                transform: activeTab === 'points' ? 'scale(1.05)' : 'scale(1)'
              }}
              onMouseEnter={(e) => {
                if (activeTab !== 'points') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                  e.currentTarget.style.transform = 'scale(1.02)';
                }
              }}
              onMouseLeave={(e) => {
                if (activeTab !== 'points') {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.12)';
                  e.currentTarget.style.transform = 'scale(1)';
                }
              }}
            >
              ⭐ {t('wallet.points')}
            </button>
          </div>

          {/* 余额显示 */}
          {activeTab === 'balance' && (
            <div style={{ position: 'relative', zIndex: 5 }}>
              {hasStripeAccount && stripeConnectInstance ? (
                <div style={{ 
                  fontSize: '16px', 
                  opacity: 0.95, 
                  marginBottom: '8px',
                  fontWeight: '500',
                  letterSpacing: '0.3px'
                }}>
                  Stripe 账户余额
                </div>
              ) : (
                <>
                  <div style={{ 
                    fontSize: isMobile ? '48px' : '56px', 
                    fontWeight: '800', 
                    marginBottom: '12px',
                    letterSpacing: '-1px',
                    textShadow: '0 2px 12px rgba(0,0,0,0.15)',
                    lineHeight: '1.1'
                  }}>
                    £{balance.toFixed(2)}
                  </div>
                  <div style={{ 
                    fontSize: '16px', 
                    opacity: 0.95,
                    fontWeight: '500',
                    letterSpacing: '0.2px'
                  }}>
                    {t('wallet.currentBalance')}
                  </div>
                </>
              )}
            </div>
          )}

          {/* 积分显示 */}
          {activeTab === 'points' && (
            <div style={{ position: 'relative', zIndex: 5 }}>
              {pointsLoading ? (
                <div style={{ 
                  fontSize: '16px', 
                  opacity: 0.95,
                  fontWeight: '500'
                }}>
                  {t('common.loading')}
                </div>
              ) : (
                <>
                  <div style={{ 
                    fontSize: isMobile ? '48px' : '56px', 
                    fontWeight: '800', 
                    marginBottom: '12px',
                    letterSpacing: '-1px',
                    textShadow: '0 2px 12px rgba(0,0,0,0.15)',
                    lineHeight: '1.1'
                  }}>
                    {pointsAccount?.balance.toLocaleString() || 0} <span style={{ fontSize: '32px', fontWeight: '600' }}>积分</span>
                  </div>
                  <div style={{ 
                    fontSize: '16px', 
                    opacity: 0.95, 
                    marginBottom: '6px',
                    fontWeight: '500',
                    letterSpacing: '0.2px'
                  }}>
                    {t('wallet.currentPointsBalance')}
                  </div>
                  <div style={{ 
                    fontSize: '14px', 
                    opacity: 0.85,
                    fontWeight: '400'
                  }}>
                    {t('wallet.pointsEquivalent', { amount: pointsAccount?.balance_display || '0.00' })}
                  </div>
                </>
              )}
            </div>
          )}
        </div>

        {/* Stripe Payouts 和 Payments 组件 - 仅余额标签页显示，如果有 Stripe 账户 */}
        {activeTab === 'balance' && hasStripeAccount && stripeConnectInstance && (
          <div style={{ 
            display: 'flex',
            flexDirection: 'column',
            gap: '24px',
            padding: isMobile ? '24px' : '36px 40px',
            background: 'linear-gradient(to bottom, #f8fafc, #ffffff)',
            borderTop: '1px solid rgba(226, 232, 240, 0.5)'
          }}>
            {/* 支付列表 */}
            <div style={{
              background: '#fff',
              borderRadius: '16px',
              boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
              border: '1px solid #e2e8f0',
              overflow: 'hidden'
            }}>
              <div style={{
                padding: isMobile ? '20px' : '24px',
                borderBottom: '1px solid #e2e8f0',
                background: 'linear-gradient(135deg, #f8fafc 0%, #ffffff 100%)'
              }}>
                <h3 style={{
                  margin: 0,
                  fontSize: '18px',
                  fontWeight: '700',
                  color: '#1a202c',
                  letterSpacing: '-0.3px'
                }}>
                  💳 {language === 'zh' ? '支付记录' : 'Payment History'}
                </h3>
                <p style={{
                  margin: '8px 0 0 0',
                  fontSize: '14px',
                  color: '#64748b',
                  lineHeight: '1.5'
                }}>
                  {language === 'zh' ? '查看所有支付交易，包括退款和争议管理' : 'View all payment transactions, including refunds and dispute management'}
                </p>
              </div>
              <div style={{ padding: isMobile ? '16px' : '20px' }}>
                <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
                  <ConnectPayments />
                </ConnectComponentsProvider>
              </div>
            </div>
            
            {/* 提现管理 */}
            <div style={{
              background: '#fff',
              borderRadius: '16px',
              boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
              border: '1px solid #e2e8f0',
              overflow: 'hidden'
            }}>
              <div style={{
                padding: isMobile ? '20px' : '24px',
                borderBottom: '1px solid #e2e8f0',
                background: 'linear-gradient(135deg, #f8fafc 0%, #ffffff 100%)'
              }}>
                <h3 style={{
                  margin: 0,
                  fontSize: '18px',
                  fontWeight: '700',
                  color: '#1a202c',
                  letterSpacing: '-0.3px'
                }}>
                  💰 {language === 'zh' ? '余额与提现' : 'Balance & Payouts'}
                </h3>
                <p style={{
                  margin: '8px 0 0 0',
                  fontSize: '14px',
                  color: '#64748b',
                  lineHeight: '1.5'
                }}>
                  {language === 'zh' ? '管理您的账户余额和提现设置' : 'Manage your account balance and payout settings'}
                </p>
              </div>
              <div style={{ padding: isMobile ? '16px' : '20px' }}>
                <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
                  <ConnectPayouts />
                </ConnectComponentsProvider>
              </div>
            </div>
          </div>
        )}

        {/* 积分统计信息 - 仅积分标签页显示 */}
        {activeTab === 'points' && pointsAccount && (
          <div style={{ 
            padding: isMobile ? '24px' : '28px 40px',
            display: 'grid',
            gridTemplateColumns: isMobile ? '1fr' : '1fr 1fr',
            gap: '16px',
            background: 'linear-gradient(to bottom, #f8fafc, #ffffff)',
            borderTop: '1px solid rgba(226, 232, 240, 0.5)'
          }}>
            <div style={{ 
              textAlign: 'center',
              padding: '20px',
              background: 'linear-gradient(135deg, #f0fdf4 0%, #ffffff 100%)',
              borderRadius: '16px',
              border: '1px solid #dcfce7',
              boxShadow: '0 2px 8px rgba(16, 185, 129, 0.08)',
              transition: 'all 0.3s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.12)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 8px rgba(16, 185, 129, 0.08)';
            }}
            >
              <div style={{ 
                fontSize: '28px', 
                fontWeight: '800', 
                color: '#10b981', 
                marginBottom: '8px',
                letterSpacing: '-0.5px'
              }}>
                +{(pointsAccount.total_earned / 100).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div style={{ 
                fontSize: '14px', 
                color: '#64748b',
                fontWeight: '600'
              }}>
                累计获得
              </div>
            </div>
            <div style={{ 
              textAlign: 'center',
              padding: '20px',
              background: 'linear-gradient(135deg, #fffbeb 0%, #ffffff 100%)',
              borderRadius: '16px',
              border: '1px solid #fef3c7',
              boxShadow: '0 2px 8px rgba(245, 158, 11, 0.08)',
              transition: 'all 0.3s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(245, 158, 11, 0.12)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 8px rgba(245, 158, 11, 0.08)';
            }}
            >
              <div style={{ 
                fontSize: '28px', 
                fontWeight: '800', 
                color: '#f59e0b', 
                marginBottom: '8px',
                letterSpacing: '-0.5px'
              }}>
                -{(pointsAccount.total_spent / 100).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div style={{ 
                fontSize: '14px', 
                color: '#64748b',
                fontWeight: '600'
              }}>
                累计消费
              </div>
            </div>
          </div>
        )}

        {/* 交易记录 */}
        <div style={{ padding: isMobile ? '24px 20px' : '36px 40px' }}>
          <h2 style={{ 
            color: '#1a202c', 
            marginBottom: '24px', 
            fontSize: '22px',
            fontWeight: '700',
            letterSpacing: '-0.3px',
            display: 'flex',
            alignItems: 'center',
            gap: '10px'
          }}>
            <span style={{ fontSize: '24px' }}>📊</span>
            <span>{
              activeTab === 'balance' ? (hasStripeAccount ? 'Stripe 余额与交易' : '交易记录') : 
              '积分交易记录'
            }</span>
          </h2>
          
          {/* 余额交易记录 */}
          {activeTab === 'balance' && (
            <>
              {transactionsLoading ? (
                <div style={{
                  textAlign: 'center',
                  padding: '60px 20px',
                  color: '#94a3b8',
                  fontSize: '16px'
                }}>
                  <div style={{ fontSize: '48px', marginBottom: '16px', opacity: 0.5 }}>⏳</div>
                  <div style={{ fontWeight: '500', color: '#64748b' }}>{t('wallet.transactionLoading')}</div>
                </div>
              ) : transactions.length === 0 ? (
                <div style={{
                  textAlign: 'center',
                  padding: '60px 20px',
                  color: '#94a3b8',
                  fontSize: '16px',
                  background: 'linear-gradient(135deg, #f8fafc 0%, #ffffff 100%)',
                  borderRadius: '16px',
                  border: '2px dashed #e2e8f0'
                }}>
                  <div style={{ fontSize: '48px', marginBottom: '16px', opacity: 0.5 }}>📭</div>
                  <div style={{ fontWeight: '500', color: '#64748b' }}>{t('wallet.transactionNoRecords')}</div>
                  <div style={{ fontSize: '14px', marginTop: '8px', color: '#94a3b8' }}>{t('wallet.transactionNoRecordsDesc')}</div>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {transactions.map((transaction) => (
                    <div
                      key={transaction.id}
                      style={{
                        background: '#fff',
                        padding: '18px 20px',
                        borderRadius: '16px',
                        border: '1px solid #e2e8f0',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                        cursor: 'pointer',
                        boxShadow: '0 1px 3px rgba(0,0,0,0.04)'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.borderColor = '#cbd5e1';
                        e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.08)';
                        e.currentTarget.style.transform = 'translateY(-2px)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.borderColor = '#e2e8f0';
                        e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.04)';
                        e.currentTarget.style.transform = 'translateY(0)';
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{
                          width: '48px',
                          height: '48px',
                          borderRadius: '14px',
                          background: transaction.type === 'income' 
                            ? 'linear-gradient(135deg, #10b981, #059669)' 
                            : 'linear-gradient(135deg, #f59e0b, #d97706)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          color: '#fff',
                          fontSize: '22px',
                          flexShrink: 0,
                          boxShadow: transaction.type === 'income' 
                            ? '0 4px 12px rgba(16, 185, 129, 0.3)' 
                            : '0 4px 12px rgba(245, 158, 11, 0.3)'
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
                  padding: '60px 20px',
                  color: '#94a3b8',
                  fontSize: '16px',
                  background: 'linear-gradient(135deg, #f8fafc 0%, #ffffff 100%)',
                  borderRadius: '16px',
                  border: '2px dashed #e2e8f0'
                }}>
                  <div style={{ fontSize: '48px', marginBottom: '16px', opacity: 0.5 }}>⭐</div>
                  <div style={{ fontWeight: '500', color: '#64748b' }}>暂无积分交易记录</div>
                  <div style={{ fontSize: '14px', marginTop: '8px', color: '#94a3b8' }}>您的积分交易记录将显示在这里</div>
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
                            padding: '18px 20px',
                            borderRadius: '16px',
                            border: '1px solid #e2e8f0',
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                            cursor: 'pointer',
                            boxShadow: '0 1px 3px rgba(0,0,0,0.04)'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.borderColor = '#cbd5e1';
                            e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.08)';
                            e.currentTarget.style.transform = 'translateY(-2px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.borderColor = '#e2e8f0';
                            e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.04)';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div style={{
                              width: '48px',
                              height: '48px',
                              borderRadius: '14px',
                              background: color === '#4CAF50' ? 'linear-gradient(135deg, #4CAF50, #45a049)' :
                                        color === '#FF9800' ? 'linear-gradient(135deg, #FF9800, #f57c00)' :
                                        color === '#2196F3' ? 'linear-gradient(135deg, #2196F3, #1976d2)' :
                                        'linear-gradient(135deg, #94a3b8, #64748b)',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              color: '#fff',
                              fontSize: '22px',
                              flexShrink: 0,
                              boxShadow: `0 4px 12px ${color}40`
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
          background: 'linear-gradient(to bottom, #ffffff, #f8fafc)',
          padding: isMobile ? '24px 20px' : '32px 40px',
          borderTop: '1px solid rgba(226, 232, 240, 0.5)'
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
                      {t('wallet.stripe.availableBalanceWithdraw')}
                    </li>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      {t('wallet.stripe.pendingBalanceWithdraw')}
                    </li>
                    <li style={{ marginBottom: '6px', position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      所有收入和支出记录都会在此显示
                    </li>
                    <li style={{ position: 'relative', paddingLeft: '20px' }}>
                      <span style={{ position: 'absolute', left: '0', color: '#10b981' }}>•</span>
                      {t('wallet.stripe.managePayoutsInComponent')}
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
                      {t('wallet.stripe.balanceUsage')}
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
