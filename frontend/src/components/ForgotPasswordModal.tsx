import React, { useState } from 'react';
import api from '../api';

interface ForgotPasswordModalProps {
  isOpen: boolean;
  onClose: () => void;
  onBackToLogin: () => void;
}

const ForgotPasswordModal: React.FC<ForgotPasswordModalProps> = ({ isOpen, onClose, onBackToLogin }) => {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [emailError, setEmailError] = useState('');

  // 邮箱验证函数
  const validateEmail = (emailValue: string): boolean => {
    if (!emailValue.trim()) {
      setEmailError('邮箱是必填项');
      return false;
    }

    // 检查长度（RFC 5321标准：最大254字符）
    if (emailValue.length > 254) {
      setEmailError('邮箱长度不能超过254个字符');
      return false;
    }

    // 检查格式
    const emailPattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    if (!emailPattern.test(emailValue.trim())) {
      setEmailError('请输入有效的邮箱地址');
      return false;
    }

    setEmailError('');
    return true;
  };

  const handleEmailChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setEmail(value);
    // 实时验证（仅在用户输入后）
    if (value && emailError) {
      validateEmail(value);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    // 验证邮箱
    if (!validateEmail(email)) {
      setLoading(false);
      return;
    }

    try {
      await api.post(
        '/api/users/forgot_password',
        new URLSearchParams({ email: email.trim().toLowerCase() }),
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
      );
      setSuccess(true);
    } catch (err: any) {
      let msg = '发送失败，请重试';
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

  const handleClose = () => {
    setEmail('');
    setError('');
    setSuccess(false);
    onClose();
  };

  const handleBackToLogin = () => {
    setEmail('');
    setError('');
    setSuccess(false);
    onBackToLogin();
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
      zIndex: 1001,
      padding: '20px'
    }}>
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
          onClick={handleClose}
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

        {/* 返回登录按钮 */}
        <button
          onClick={handleBackToLogin}
          style={{
            position: 'absolute',
            top: '16px',
            left: '16px',
            background: 'none',
            border: 'none',
            fontSize: '20px',
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
          ←
        </button>

        {/* 标题 */}
        <h2 style={{
          fontSize: '28px',
          fontWeight: 'bold',
          color: '#333',
          marginBottom: '8px',
          textAlign: 'center',
          marginTop: '20px'
        }}>
          忘记密码
        </h2>

        {/* 说明文字 */}
        <p style={{
          fontSize: '14px',
          color: '#666',
          textAlign: 'center',
          marginBottom: '32px',
          lineHeight: '1.5'
        }}>
          请输入您的邮箱地址，我们将发送重置密码的链接到您的邮箱
        </p>

        {success ? (
          /* 成功状态 */
          <div style={{ textAlign: 'center' }}>
            <div style={{
              fontSize: '48px',
              marginBottom: '20px'
            }}>
              ✅
            </div>
            <h3 style={{
              fontSize: '20px',
              fontWeight: '600',
              color: '#10b981',
              marginBottom: '16px'
            }}>
              邮件已发送
            </h3>
            <p style={{
              fontSize: '14px',
              color: '#666',
              marginBottom: '24px',
              lineHeight: '1.5'
            }}>
              我们已向 <strong>{email}</strong> 发送了重置密码的链接，请检查您的邮箱并按照说明重置密码。
            </p>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <button
                onClick={handleBackToLogin}
                style={{
                  padding: '12px 24px',
                  backgroundColor: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'background-color 0.2s'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = '#2563eb';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = '#3b82f6';
                }}
              >
                返回登录
              </button>
              <button
                onClick={handleClose}
                style={{
                  padding: '12px 24px',
                  backgroundColor: '#f3f4f6',
                  color: '#374151',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'background-color 0.2s'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = '#e5e7eb';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = '#f3f4f6';
                }}
              >
                关闭
              </button>
            </div>
          </div>
        ) : (
          /* 表单状态 */
          <form onSubmit={handleSubmit}>
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

            {/* 邮箱输入 */}
            <div style={{ marginBottom: '24px' }}>
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
                value={email}
                onChange={handleEmailChange}
                onBlur={(e) => {
                  e.target.style.borderColor = emailError ? '#ef4444' : '#ddd';
                  validateEmail(email);
                }}
                placeholder="请输入您的邮箱地址"
                required
                maxLength={254}
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: `1px solid ${emailError ? '#ef4444' : '#ddd'}`,
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = emailError ? '#ef4444' : '#3b82f6';
                }}
              />
              {emailError && (
                <div style={{
                  color: '#ef4444',
                  fontSize: '12px',
                  marginTop: '4px',
                  marginLeft: '4px'
                }}>
                  {emailError}
                </div>
              )}
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
              {loading ? '发送中...' : '发送重置链接'}
            </button>

            {/* 返回登录 */}
            <div style={{ textAlign: 'center' }}>
              <button
                type="button"
                onClick={handleBackToLogin}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#3b82f6',
                  fontSize: '14px',
                  cursor: 'pointer',
                  textDecoration: 'underline'
                }}
              >
                返回登录页面
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default ForgotPasswordModal;
