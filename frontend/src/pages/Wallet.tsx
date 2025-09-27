import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchCurrentUser } from '../api';
import api from '../api';

const Wallet: React.FC = () => {
  const navigate = useNavigate();
  const [balance, setBalance] = useState(0);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // 加载钱包数据
    loadWalletData();
  }, []);

  const loadWalletData = async () => {
    try {
      setLoading(true);
      // TODO: 调用真实的钱包API
      // const walletData = await getWalletData();
      // setBalance(walletData.balance);
      // setTransactions(walletData.transactions);
      
      // 暂时显示空数据，等待后端API实现
      setBalance(0);
      setTransactions([]);
    } catch (error) {
      console.error('加载钱包数据失败:', error);
      setBalance(0);
      setTransactions([]);
    } finally {
      setLoading(false);
    }
  };

  const handleWithdraw = () => {
    alert('提现功能开发中...');
  };

  const handleRecharge = () => {
    alert('充值功能开发中...');
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
          textAlign: 'center'
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
              padding: '8px 16px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            ← 返回首页
          </button>
          <h1 style={{ margin: '0 0 20px 0', fontSize: '28px', fontWeight: 'bold' }}>💰 我的钱包</h1>
          <div style={{ fontSize: '48px', fontWeight: 'bold', marginBottom: '10px' }}>
            £{balance.toFixed(2)}
          </div>
          <div style={{ fontSize: '16px', opacity: 0.9 }}>当前余额</div>
        </div>

        {/* 操作按钮 */}
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
            💳 充值
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
            💸 提现
          </button>
        </div>

        {/* 交易记录 */}
        <div style={{ padding: '0 30px 30px 30px' }}>
          <h2 style={{ 
            color: '#333', 
            marginBottom: '20px', 
            fontSize: '20px',
            fontWeight: 'bold'
          }}>
            📊 交易记录
          </h2>
          
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
        </div>

        {/* 钱包说明 */}
        <div style={{
          background: '#f8f9fa',
          padding: '20px 30px',
          borderTop: '1px solid #e9ecef'
        }}>
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
        </div>
      </div>
    </div>
  );
};

export default Wallet;
