import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';
import ForgotPasswordModal from './ForgotPasswordModal';

interface LoginModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  onReopen?: () => void; // 用于重新打开登录弹窗
  showForgotPassword?: boolean; // 忘记密码弹窗状态
  onShowForgotPassword?: () => void; // 显示忘记密码弹窗
  onHideForgotPassword?: () => void; // 隐藏忘记密码弹窗
}

const LoginModal: React.FC<LoginModalProps> = ({ 
  isOpen, 
  onClose, 
  onSuccess, 
  onReopen, 
  showForgotPassword = false, 
  onShowForgotPassword, 
  onHideForgotPassword 
}) => {
  const [isLogin, setIsLogin] = useState(true);
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    confirmPassword: '',
    username: '',
    phone: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
    setError('');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      if (isLogin) {
        // 登录逻辑 - 使用与Login.tsx相同的格式
        const res = await api.post('/api/auth/login', {
          email: formData.email,
          password: formData.password,
        });
        
        // HttpOnly Cookie已由后端自动设置，无需手动存储
        // 添加短暂延迟确保Cookie设置完成
        setTimeout(() => {
          onSuccess?.();
          onClose();
          window.location.reload(); // 刷新页面以更新用户状态
        }, 100);
      } else {
        // 注册逻辑
        if (formData.password !== formData.confirmPassword) {
          setError('密码确认不匹配');
          setLoading(false);
          return;
        }
        
        await api.post('/api/users/register', {
          email: formData.email,
          password: formData.password,
          username: formData.username,
          phone: formData.phone
        });
        
        alert('注册成功！请登录');
        setIsLogin(true);
        setFormData({
          email: '',
          password: '',
          confirmPassword: '',
          username: '',
          phone: ''
        });
      }
    } catch (err: any) {
      let msg = isLogin ? '登录失败' : '注册失败';
      if (err?.response?.data?.detail) {
        if (typeof err.response.data.detail === 'string') {
          msg = err.response.data.detail;
        } else if (Array.isArray(err.response.data.detail)) {
          msg = err.response.data.detail.map((item: any) => item.msg).join('；');
        } else if (typeof err.response.data.detail === 'object' && err.response.data.detail.msg) {
          msg = err.response.data.detail.msg;
        } else {
          msg = JSON.stringify(err.response.data.detail);
        }
      } else if (err?.message) {
        msg = err.message;
      }
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleLogin = () => {
    // Google登录逻辑（暂时显示提示）
    alert('Google登录功能暂未实现');
  };

  if (!isOpen) return null;

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
      padding: '20px'
    }}>
      {/* 登录弹窗内容 */}
      {!showForgotPassword && (
        <div style={{
          backgroundColor: '#fff',
          borderRadius: '16px',
          padding: '32px',
          width: '100%',
          maxWidth: '400px',
          maxHeight: '90vh',
          overflow: 'auto',
          boxShadow: '0 20px 40px rgba(0, 0, 0, 0.1)',
          position: 'relative'
        }}>
        {/* 关闭按钮 */}
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            background: 'none',
            border: 'none',
            fontSize: '24px',
            cursor: 'pointer',
            color: '#666',
            width: '32px',
            height: '32px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '50%',
            transition: 'background-color 0.2s'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = '#f5f5f5';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = 'transparent';
          }}
        >
          ×
        </button>

        {/* 标题 */}
        <h2 style={{
          fontSize: '28px',
          fontWeight: 'bold',
          color: '#333',
          marginBottom: '8px',
          textAlign: 'center'
        }}>
          {isLogin ? '登录' : '注册'}
        </h2>

        {/* 欢迎礼品横幅 */}
        <div style={{
          backgroundColor: '#e3f2fd',
          borderRadius: '8px',
          padding: '12px 16px',
          marginBottom: '24px',
          textAlign: 'center',
          border: '1px solid #bbdefb'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
            <span style={{ fontSize: '20px' }}>💎</span>
            <span style={{ fontSize: '14px', color: '#1976d2' }}>
              {isLogin ? '登录' : '注册'}即可获得 <strong style={{ fontSize: '16px' }}>£66</strong> 欢迎礼品
            </span>
          </div>
        </div>

        {/* 错误提示 */}
        {error && (
          <div style={{
            backgroundColor: '#ffebee',
            color: '#c62828',
            padding: '12px',
            borderRadius: '8px',
            marginBottom: '16px',
            fontSize: '14px',
            textAlign: 'center'
          }}>
            {error}
          </div>
        )}

        {/* 表单 */}
        <form onSubmit={handleSubmit}>
          {/* 邮箱输入 */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{
              display: 'block',
              fontSize: '14px',
              fontWeight: '600',
              color: '#333',
              marginBottom: '8px'
            }}>
              邮箱地址
            </label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              placeholder="请输入邮箱地址"
              required
              style={{
                width: '100%',
                padding: '12px 16px',
                border: '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                boxSizing: 'border-box',
                transition: 'border-color 0.2s'
              }}
              onFocus={(e) => {
                e.target.style.borderColor = '#3b82f6';
              }}
              onBlur={(e) => {
                e.target.style.borderColor = '#ddd';
              }}
            />
          </div>

          {/* 注册时显示用户名和手机号 */}
          {!isLogin && (
            <>
              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  fontSize: '14px',
                  fontWeight: '600',
                  color: '#333',
                  marginBottom: '8px'
                }}>
                  用户名
                </label>
                <input
                  type="text"
                  name="username"
                  value={formData.username}
                  onChange={handleInputChange}
                  placeholder="请输入用户名"
                  required
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
              </div>

              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  fontSize: '14px',
                  fontWeight: '600',
                  color: '#333',
                  marginBottom: '8px'
                }}>
                  手机号
                </label>
                <input
                  type="tel"
                  name="phone"
                  value={formData.phone}
                  onChange={handleInputChange}
                  placeholder="请输入手机号"
                  required
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
              </div>
            </>
          )}

          {/* 密码输入 */}
          <div style={{ marginBottom: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
              <label style={{
                fontSize: '14px',
                fontWeight: '600',
                color: '#333'
              }}>
                密码
              </label>
              {isLogin && (
                <button
                  type="button"
                  onClick={() => {
                    if (onShowForgotPassword) {
                      onShowForgotPassword();
                    }
                  }}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#3b82f6',
                    fontSize: '12px',
                    cursor: 'pointer',
                    textDecoration: 'underline'
                  }}
                >
                  忘记密码？
                </button>
              )}
            </div>
            <input
              type="password"
              name="password"
              value={formData.password}
              onChange={handleInputChange}
              placeholder="请输入密码"
              required
              style={{
                width: '100%',
                padding: '12px 16px',
                border: '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                boxSizing: 'border-box',
                transition: 'border-color 0.2s'
              }}
              onFocus={(e) => {
                e.target.style.borderColor = '#3b82f6';
              }}
              onBlur={(e) => {
                e.target.style.borderColor = '#ddd';
              }}
            />
          </div>

          {/* 注册时显示确认密码 */}
          {!isLogin && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                fontSize: '14px',
                fontWeight: '600',
                color: '#333',
                marginBottom: '8px'
              }}>
                确认密码
              </label>
              <input
                type="password"
                name="confirmPassword"
                value={formData.confirmPassword}
                onChange={handleInputChange}
                placeholder="请再次输入密码"
                required
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#ddd';
                }}
              />
            </div>
          )}

          {/* 用户协议 */}
          <div style={{
            fontSize: '12px',
            color: '#666',
            marginBottom: '24px',
            lineHeight: '1.4'
          }}>
            我已阅读并同意
            <a href="#" style={{ color: '#3b82f6', textDecoration: 'underline' }}>用户协议</a>、
            <a href="#" style={{ color: '#3b82f6', textDecoration: 'underline' }}>隐私政策</a>，
            并接收短信通知。标准短信费率可能适用。
          </div>

          {/* 提交按钮 */}
          <button
            type="submit"
            disabled={loading}
            style={{
              width: '100%',
              padding: '14px',
              backgroundColor: loading ? '#ccc' : '#3b82f6',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: loading ? 'not-allowed' : 'pointer',
              marginBottom: '16px',
              transition: 'background-color 0.2s'
            }}
            onMouseEnter={(e) => {
              if (!loading) {
                e.currentTarget.style.backgroundColor = '#2563eb';
              }
            }}
            onMouseLeave={(e) => {
              if (!loading) {
                e.currentTarget.style.backgroundColor = '#3b82f6';
              }
            }}
          >
            {loading ? '处理中...' : (isLogin ? '登录' : '注册')}
          </button>

          {/* 切换登录/注册 */}
          <div style={{ textAlign: 'center', marginBottom: '16px' }}>
            <button
              type="button"
              onClick={() => setIsLogin(!isLogin)}
              style={{
                background: 'none',
                border: 'none',
                color: '#3b82f6',
                fontSize: '14px',
                cursor: 'pointer',
                textDecoration: 'underline'
              }}
            >
              {isLogin ? '没有账号？立即注册' : '已有账号？立即登录'}
            </button>
          </div>

          {/* 分割线 */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            marginBottom: '16px'
          }}>
            <div style={{
              flex: 1,
              height: '1px',
              backgroundColor: '#e0e0e0'
            }}></div>
            <span style={{
              padding: '0 16px',
              fontSize: '14px',
              color: '#666'
            }}>或</span>
            <div style={{
              flex: 1,
              height: '1px',
              backgroundColor: '#e0e0e0'
            }}></div>
          </div>

          {/* Google登录按钮 */}
          <button
            type="button"
            onClick={handleGoogleLogin}
            style={{
              width: '100%',
              padding: '14px',
              backgroundColor: '#fff',
              color: '#333',
              border: '1px solid #ddd',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '12px',
              transition: 'border-color 0.2s'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.borderColor = '#3b82f6';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.borderColor = '#ddd';
            }}
          >
            <div style={{
              width: '20px',
              height: '20px',
              backgroundColor: '#4285f4',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              fontSize: '12px',
              fontWeight: 'bold'
            }}>
              G
            </div>
            使用 Google 继续
          </button>
        </form>
        </div>
      )}
      
      {/* 忘记密码弹窗 */}
      <ForgotPasswordModal
        isOpen={showForgotPassword}
        onClose={() => {
          if (onHideForgotPassword) {
            onHideForgotPassword();
          }
        }}
        onBackToLogin={() => {
          if (onHideForgotPassword) {
            onHideForgotPassword();
          }
        }}
      />
    </div>
  );
};

export default LoginModal;
