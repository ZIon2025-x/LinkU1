import React, { useState } from 'react';
import { Form, Input, Button, Card, message, Alert, Typography } from 'antd';
import styled from 'styled-components';
import axios from 'axios';
import { useNavigate, useLocation } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import LoginModal from '../components/LoginModal';
import api from '../api';
import SEOHead from '../components/SEOHead';
import HreflangManager from '../components/HreflangManager';

const { Text, Paragraph } = Typography;

const Wrapper = styled.div`
  min-height: 80vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f9f9f9;
`;

const StyledCard = styled(Card)`
  width: 400px;
  box-shadow: 0 2px 8px #f0f1f2;
`;

const ErrorMsg = styled.div`
  color: #ff4d4f;
  margin-bottom: 12px;
  text-align: center;
`;

const PasswordRequirements = styled.div`
  margin-top: 4px;
  font-size: 12px;
  color: #666;
`;

const PasswordRequirementItem = styled.div<{ valid: boolean }>`
  color: ${props => props.valid ? '#52c41a' : '#d9d9d9'};
  margin: 2px 0;
`;

const Register: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { t } = useLanguage();
  const [errorMsg, setErrorMsg] = useState('');
  const [password, setPassword] = useState('');
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [passwordValidation, setPasswordValidation] = useState<{
    is_valid: boolean;
    score: number;
    strength: string;
    bars: number;
    errors: string[];
    suggestions: string[];
    missing_requirements: string[];
  }>({
    is_valid: false,
    score: 0,
    strength: 'weak',
    bars: 1,
    errors: [],
    suggestions: [],
    missing_requirements: []
  });

  // 前端密码强度验证函数（当后端不可用时使用）
  const validatePasswordFrontend = (password: string) => {
    const errors: string[] = [];
    const missing_requirements: string[] = [];
    let score = 0;

    // 基本长度检查
    const min_length = 12;
    if (password.length < min_length) {
      errors.push(`密码长度至少需要${min_length}个字符`);
      missing_requirements.push(`至少${min_length}个字符`);
      score -= 20;
    } else if (password.length >= 16) {
      score += 10;
    }

    // 字符类型检查
    const has_upper = /[A-Z]/.test(password);
    const has_lower = /[a-z]/.test(password);
    const has_digit = /\d/.test(password);
    // 检查特殊字符（包括Unicode特殊字符，排除中文字符范围）
    const has_special = /[^\w\s\u4e00-\u9fff]/.test(password);

    // 收集缺少的要求
    if (!has_upper) {
      errors.push("密码必须包含至少一个大写字母");
      missing_requirements.push("大写字母 (例如: A, B, C)");
      score -= 15;
    }

    if (!has_lower) {
      errors.push("密码必须包含至少一个小写字母");
      missing_requirements.push("小写字母 (例如: a, b, c)");
      score -= 15;
    }

    if (!has_digit) {
      errors.push("密码必须包含至少一个数字");
      missing_requirements.push("数字 (例如: 0, 1, 2, 3)");
      score -= 15;
    }

    if (!has_special) {
      errors.push("密码必须包含至少一个特殊字符");
      missing_requirements.push("特殊字符 (例如: !@#$%^&*()_+-=...)");
      score -= 15;
    }

    // 字符类型奖励
    const char_types = [has_upper, has_lower, has_digit, has_special].filter(Boolean).length;
    score += char_types * 5;

    // 计算最终分数
    score = Math.max(0, Math.min(100, score));

    // 计算bars和strength（基于新的三条横线规则）
    const has_letter = has_upper || has_lower;

    let strength: string;
    let bars: number;

    // 三条横线：强（有大小写字母、数字和特殊字符）
    if (has_upper && has_lower && has_digit && has_special) {
      strength = "strong";
      bars = 3;
    }
    // 两条横线：中（有数字和字母，或者有数字和特殊字符）
    else if ((has_digit && has_letter) || (has_digit && has_special)) {
      strength = "medium";
      bars = 2;
    }
    // 一条横线：弱（只有数字）
    else if (has_digit && !has_letter && !has_special) {
      strength = "weak";
      bars = 1;
    }
    // 其他情况归为弱
    else {
      strength = "weak";
      bars = 1;
    }

    return {
      is_valid: errors.length === 0,
      score,
      strength,
      bars,
      errors,
      suggestions: [],
      missing_requirements
    };
  };

  // 密码验证函数
  const validatePassword = async (pwd: string) => {
    if (!pwd) {
      setPasswordValidation({
        is_valid: false,
        score: 0,
        strength: 'weak',
        bars: 1,
        errors: [],
        suggestions: [],
        missing_requirements: []
      });
      return;
    }

    try {
      const response = await api.post('/api/users/password/validate', {
        password: pwd
      });
      // 确保返回的数据格式正确，包含bars字段
      if (response.data) {
        const validationData = {
          is_valid: response.data.is_valid || false,
          score: response.data.score || 0,
          strength: response.data.strength || 'weak',
          bars: response.data.bars !== undefined ? response.data.bars : 1,  // 确保bars字段存在
          errors: response.data.errors || [],
          suggestions: response.data.suggestions || [],
          missing_requirements: response.data.missing_requirements || []
        };
                setPasswordValidation(validationData);
      }
    } catch (error: any) {
            // 如果是网络错误（后端不可用），使用前端验证作为后备
      if (error?.code === 'ERR_NETWORK' || error?.message === 'Network Error') {
                const frontendValidation = validatePasswordFrontend(pwd);
                setPasswordValidation(frontendValidation);
        return;
      }
      
      // 如果有错误响应数据，使用它
      if (error?.response?.data?.errors) {
        setPasswordValidation({
          is_valid: false,
          score: 0,
          strength: 'weak',
          bars: 1,
          errors: error.response.data.errors,
          suggestions: error.response.data.suggestions || [],
          missing_requirements: error.response.data.missing_requirements || []
        });
      } else {
        // 如果没有任何错误信息，使用前端验证
        const frontendValidation = validatePasswordFrontend(pwd);
        setPasswordValidation(frontendValidation);
      }
    }
  };

  // 实时验证密码
  React.useEffect(() => {
    const timeoutId = setTimeout(() => {
      validatePassword(password);
    }, 300);
    return () => clearTimeout(timeoutId);
  }, [password]);

  const onFinish = async (values: any) => {
    try {
      const res = await api.post('/api/users/register', values);
      setErrorMsg(''); // 注册成功清空错误
      
      if (res.data.verification_required) {
        message.success(`注册成功！我们已向 ${res.data.email} 发送了验证邮件，请检查您的邮箱并点击验证链接完成注册。`);
        // 3秒后跳转到重发验证邮件页面
        setTimeout(() => {
          setShowLoginModal(true);
        }, 3000);
      } else {
        message.success(res.data.message || '注册成功！');
        // 开发环境：直接跳转到登录页面
        setTimeout(() => {
          setShowLoginModal(true);
        }, 1500);
      }
    } catch (err: any) {
            let msg = t('register.registrationError');
      
      // 处理不同的错误格式
      if (err?.response?.data) {
        const errorData = err.response.data;
        
        // 优先使用 message 字段
        if (errorData.message) {
          msg = errorData.message;
        } 
        // 然后尝试 detail 字段
        else if (errorData.detail) {
          if (typeof errorData.detail === 'string') {
            msg = errorData.detail;
          } else if (Array.isArray(errorData.detail)) {
            msg = errorData.detail.map((item: any) => item.msg || item).join('；');
          } else if (typeof errorData.detail === 'object' && errorData.detail.msg) {
            msg = errorData.detail.msg;
          } else {
            msg = JSON.stringify(errorData.detail);
          }
        }
        // 最后尝试 error 字段
        else if (errorData.error) {
          msg = errorData.error;
        }
      } 
      // 处理网络错误或其他错误
      else if (err?.message) {
        if (err.message.includes('Network Error') || err.message.includes('timeout')) {
          msg = t('errors.networkError');
        } else {
          msg = err.message;
        }
      }
      
      setErrorMsg(msg);
    }
  };

  return (
    <Wrapper>
      <SEOHead 
        title="注册 - Link²Ur"
        description="注册Link²Ur账户，加入本地生活服务平台"
        noindex={true}
      />
      <HreflangManager type="page" path="/register" />
      {/* SEO优化：可见的H1标签 */}
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
      }}>
        用户注册 - Link²Ur
      </h1>
      <StyledCard title={t('register.title')}>
        {errorMsg && (
          <Alert
            message={errorMsg}
            type="error"
            showIcon
            style={{ marginBottom: 16 }}
            closable
            onClose={() => setErrorMsg('')}
          />
        )}
        <Form layout="vertical" onFinish={onFinish}>
          <Form.Item 
            label={t('register.username')} 
            name="name" 
            rules={[
              { required: true, message: t('register.usernameRequired') },
              { min: 2, message: t('register.usernameTooShort') },
              { max: 50, message: t('register.usernameTooLong') },
              { pattern: /^[a-zA-Z0-9_-]+$/, message: t('register.usernameInvalid') }
            ]}
          > 
            <Input placeholder={t('register.username')} />
          </Form.Item>
          
          <Form.Item 
            label={t('register.email')} 
            name="email" 
            rules={[
              { required: true, message: t('register.emailRequired') },
              { type: 'email', message: t('register.emailInvalid') }
            ]}
          > 
            <Input placeholder={t('register.email')} />
          </Form.Item>
          
          <Form.Item 
            label={t('register.phone')} 
            name="phone"
            rules={[]}
            required={false}
          > 
            <Input placeholder={t('register.phone')} />
          </Form.Item>
          
          <Form.Item 
            label={t('register.password')} 
            name="password" 
            rules={[
              { required: true, message: t('register.passwordRequired') },
              { 
                validator: (_, value) => {
                  if (!value) return Promise.resolve();
                  if (!passwordValidation.is_valid) {
                    return Promise.reject(new Error('密码不符合安全要求'));
                  }
                  return Promise.resolve();
                }
              }
            ]}
          > 
            <Input.Password 
              placeholder={t('register.password')} 
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            {password && (
              <PasswordRequirements>
                <div style={{ marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span style={{ 
                    fontSize: '13px',
                    fontWeight: '500',
                    color: '#666'
                  }}>
                    密码强度:
                  </span>
                  <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                    {/* 密码强度横线显示 */}
                    {[1, 2, 3].map((bar) => {
                      const bars = passwordValidation.bars !== undefined ? passwordValidation.bars : 1;
                      const isActive = bar <= bars;
                      let barColor = '#d9d9d9'; // 默认灰色
                      
                      if (bars === 1) {
                        barColor = isActive ? '#ff4d4f' : '#d9d9d9'; // 弱：红色
                      } else if (bars === 2) {
                        barColor = isActive ? '#faad14' : '#d9d9d9'; // 中：橙色
                      } else if (bars === 3) {
                        barColor = isActive ? '#52c41a' : '#d9d9d9'; // 强：绿色
                      }
                      
                      return (
                        <div
                          key={bar}
                          style={{
                            width: '24px',
                            height: '4px',
                            backgroundColor: barColor,
                            borderRadius: '2px',
                            transition: 'background-color 0.3s'
                          }}
                        />
                      );
                    })}
                  </div>
                </div>
                
                {/* 实时提示：缺少什么 */}
                {passwordValidation.missing_requirements && passwordValidation.missing_requirements.length > 0 && (
                  <div style={{ color: '#ff9800', marginBottom: '8px', fontSize: '12px' }}>
                    <div style={{ fontWeight: 'bold', marginBottom: '4px' }}>缺少：</div>
                    {passwordValidation.missing_requirements.map((req, index) => (
                      <div key={index} style={{ marginBottom: '2px' }}>• {req}</div>
                    ))}
                  </div>
                )}
                
              </PasswordRequirements>
            )}
          </Form.Item>
          
          <Form.Item>
            <Button type="primary" htmlType="submit" block size="large">
              {t('register.createAccount')}
            </Button>
          </Form.Item>
          
          <div style={{ textAlign: 'center', marginTop: 16 }}>
            <Text type="secondary">
              {t('register.alreadyHaveAccount')}{' '}
              <Button type="link" onClick={() => setShowLoginModal(true)} style={{ padding: 0 }}>
                {t('register.loginHere')}
              </Button>
            </Text>
          </div>
        </Form>
      </StyledCard>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => setShowForgotPasswordModal(true)}
        onHideForgotPassword={() => setShowForgotPasswordModal(false)}
      />
    </Wrapper>
  );
};

export default Register; 