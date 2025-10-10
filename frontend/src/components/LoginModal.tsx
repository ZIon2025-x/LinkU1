import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import api from '../api';
import ForgotPasswordModal from './ForgotPasswordModal';
import VerificationModal from './VerificationModal';

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
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showVerificationModal, setShowVerificationModal] = useState(false);
  const [registeredEmail, setRegisteredEmail] = useState('');
  const [passwordValidation, setPasswordValidation] = useState({
    is_valid: false,
    score: 0,
    strength: 'weak',
    errors: [],
    suggestions: []
  });
  const navigate = useNavigate();

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
    setError('');
    
    // 如果是密码字段且是注册模式，进行密码验证
    if (name === 'password' && !isLogin) {
      validatePassword(value);
    }
  };

  // 密码验证函数
  const validatePassword = async (password: string) => {
    if (!password) {
      setPasswordValidation({
        is_valid: false,
        score: 0,
        strength: 'weak',
        errors: [],
        suggestions: []
      });
      return;
    }

    try {
      const response = await api.post('/api/users/password/validate', {
        password: password,
        username: formData.username,
        email: formData.email
      });
      setPasswordValidation(response.data);
    } catch (error) {
      console.error('密码验证失败:', error);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      if (isLogin) {
        // 登录逻辑 - 使用与Login.tsx相同的格式
        const res = await api.post('/api/secure-auth/login', {
          email: formData.email,
          password: formData.password,
        });
        
        // 检测是否为移动端，如果是则保存access_token
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        if (isMobile && res.data.access_token) {
          localStorage.setItem('access_token', res.data.access_token);
          console.log('移动端登录成功，已保存access_token');
        }
        
        // 保存session_id（桌面端和移动端都需要）
        if (res.data.session_id) {
          localStorage.setItem('session_id', res.data.session_id);
          console.log('已保存session_id');
        }
        
        // 添加短暂延迟确保认证信息设置完成
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
        
        if (!agreedToTerms) {
          setError('请先同意用户协议和隐私政策');
          setLoading(false);
          return;
        }
        
        // 检查密码强度
        if (!passwordValidation.is_valid) {
          setError('密码不符合安全要求，请查看下方提示');
          setLoading(false);
          return;
        }
        
        const res = await api.post('/api/users/register', {
          email: formData.email,
          password: formData.password,
          name: formData.username,  // 改为 name
          phone: formData.phone
        });
        
        // 处理注册成功后的逻辑
        if (res.data.verification_required) {
          message.success(`注册成功！我们已向 ${res.data.email} 发送了验证邮件，请检查您的邮箱并点击验证链接完成注册。`);
          // 显示验证弹窗而不是跳转页面
          setRegisteredEmail(res.data.email);
          setShowVerificationModal(true);
        } else {
          message.success(res.data.message || '注册成功！');
          // 开发环境：直接跳转到登录页面
          setTimeout(() => {
            navigate('/login');
            onClose(); // 关闭弹窗
          }, 1500);
        }
        
        // 清空表单数据
        setFormData({
          email: '',
          password: '',
          confirmPassword: '',
          username: '',
          phone: ''
        });
      }
    } catch (err: any) {
      console.error('注册/登录错误:', err);
      console.error('错误响应:', err?.response?.data);
      
      let msg = isLogin ? '登录失败' : '注册失败';
      
      // 优先处理HTTP响应错误
      if (err?.response?.data) {
        const responseData = err.response.data;
        
        // 处理detail字段
        if (responseData.detail) {
          if (typeof responseData.detail === 'string') {
            msg = responseData.detail;
          } else if (Array.isArray(responseData.detail)) {
            msg = responseData.detail.map((item: any) => item.msg || item).join('；');
          } else if (typeof responseData.detail === 'object' && responseData.detail.msg) {
            msg = responseData.detail.msg;
          } else {
            msg = JSON.stringify(responseData.detail);
          }
        }
        // 处理message字段
        else if (responseData.message) {
          msg = responseData.message;
        }
        // 处理其他错误信息
        else if (responseData.error) {
          msg = responseData.error;
        }
      }
      // 处理网络错误或其他错误
      else if (err?.message) {
        if (err.message.includes('Request failed with status code')) {
          msg = '网络请求失败，请检查网络连接';
        } else {
          msg = err.message;
        }
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
                  placeholder="请输入手机号（可选）"
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
            <label style={{
              display: 'block',
              fontSize: '14px',
              fontWeight: '600',
              color: '#333',
              marginBottom: '8px'
            }}>
              密码
            </label>
            <input
              type="password"
              name="password"
              value={formData.password}
              onChange={handleInputChange}
              placeholder={isLogin ? "请输入密码" : "至少12位，包含大小写字母、数字和特殊字符"}
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
            
            {/* 密码强度显示 - 仅在注册模式且输入密码时显示 */}
            {!isLogin && formData.password && (
              <div style={{
                marginTop: '8px',
                padding: '8px 12px',
                backgroundColor: '#f8f9fa',
                borderRadius: '6px',
                border: '1px solid #e9ecef'
              }}>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ 
                    color: passwordValidation.score >= 80 ? '#52c41a' : 
                           passwordValidation.score >= 60 ? '#faad14' : '#ff4d4f',
                    fontWeight: 'bold',
                    fontSize: '13px'
                  }}>
                    密码强度: {passwordValidation.strength === 'weak' ? '弱' : 
                           passwordValidation.strength === 'medium' ? '中等' :
                           passwordValidation.strength === 'strong' ? '强' : '很强'} 
                    ({passwordValidation.score}/100)
                  </span>
                </div>
                
                {passwordValidation.errors.length > 0 && (
                  <div style={{ color: '#ff4d4f', marginBottom: '6px', fontSize: '12px' }}>
                    {passwordValidation.errors.map((error, index) => (
                      <div key={index}>• {error}</div>
                    ))}
                  </div>
                )}
                
                {passwordValidation.suggestions.length > 0 && (
                  <div style={{ color: '#1890ff', fontSize: '12px' }}>
                    <div style={{ fontWeight: 'bold', marginBottom: '2px' }}>建议:</div>
                    {passwordValidation.suggestions.map((suggestion, index) => (
                      <div key={index}>• {suggestion}</div>
                    ))}
                  </div>
                )}
              </div>
            )}
            
            {/* 忘记密码链接 - 放在密码输入框右下角 */}
            {isLogin && (
              <div style={{ textAlign: 'right', marginTop: '4px' }}>
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
                    textDecoration: 'underline',
                    padding: '0'
                  }}
                >
                  忘记密码？
                </button>
              </div>
            )}
            {/* 注册时显示密码要求 */}
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

          {/* 用户协议 - 只在注册时显示 */}
          {!isLogin && (
            <div style={{
              fontSize: '12px',
              color: '#666',
              marginBottom: '24px',
              lineHeight: '1.4',
              display: 'flex',
              alignItems: 'flex-start',
              gap: '8px'
            }}>
              <div style={{
                position: 'relative',
                marginTop: '2px'
              }}>
                <input
                  type="checkbox"
                  checked={agreedToTerms}
                  onChange={(e) => setAgreedToTerms(e.target.checked)}
                  style={{
                    width: '16px',
                    height: '16px',
                    accentColor: '#52c41a',
                    cursor: 'pointer'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                我已阅读并同意
                <a 
                  href="/terms" 
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: '#3b82f6', textDecoration: 'underline', cursor: 'pointer' }}
                  onClick={(e) => {
                    e.preventDefault();
                    navigate('/terms');
                  }}
                >
                  用户协议
                </a>、
                <a 
                  href="/privacy" 
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: '#3b82f6', textDecoration: 'underline', cursor: 'pointer' }}
                  onClick={(e) => {
                    e.preventDefault();
                    navigate('/privacy');
                  }}
                >
                  隐私政策
                </a>，
                并接收短信通知。标准短信费率可能适用。
              </div>
            </div>
          )}

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
              onClick={() => {
                setIsLogin(!isLogin);
                setAgreedToTerms(false); // 切换时重置同意状态
                setError(''); // 清空错误信息
              }}
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

      {/* 验证邮件弹窗 */}
      <VerificationModal
        isOpen={showVerificationModal}
        onClose={() => setShowVerificationModal(false)}
        email={registeredEmail}
        onLogin={() => {
          setShowVerificationModal(false);
          setIsLogin(true);
          if (onReopen) {
            onReopen();
          }
        }}
      />
    </div>
  );
};

export default LoginModal;
