import React, { useState } from 'react';
import { Form, Input, Button, Card } from 'antd';
import styled from 'styled-components';
import { useParams } from 'react-router-dom';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { getErrorMessage } from '../utils/errorHandler';

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

const ResetPassword: React.FC = () => {
  const { t } = useLanguage();
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [password, setPassword] = useState('');
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
  const { navigate } = useLocalizedNavigation();
  const { token } = useParams();

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
      await api.post(
        `/api/users/reset_password/${token}`,
        new URLSearchParams({ new_password: values.password }),
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
      );
      setErrorMsg('');
      setSuccessMsg(t('auth.resetPasswordSuccess'));
      setTimeout(() => {
        setShowLoginModal(true);
      }, 2000);
    } catch (err: any) {
      setErrorMsg(getErrorMessage(err));
      setSuccessMsg('');
    }
  };

  return (
    <Wrapper>
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
        {t('auth.resetPassword')} - Link²Ur
      </h1>
      <StyledCard title={t('auth.resetPassword')}>
        {errorMsg && <ErrorMsg>{errorMsg}</ErrorMsg>}
        {successMsg && <div style={{ color: '#52c41a', marginBottom: 12, textAlign: 'center' }}>{successMsg}</div>}
        <Form layout="vertical" onFinish={onFinish}>
          <Form.Item 
            label={t('auth.newPassword')} 
            name="password" 
            rules={[
              { required: true, message: t('auth.newPasswordRequired') },
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
              placeholder={t('auth.newPasswordPlaceholder')}
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
                    {t('auth.passwordStrength')}:
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
            <Button type="primary" htmlType="submit" block>{t('auth.resetPassword')}</Button>
          </Form.Item>
        </Form>
        <div style={{ textAlign: 'center', marginTop: 8 }}>
          <Button type="link" onClick={() => setShowLoginModal(true)}>{t('auth.backToLogin')}</Button>
        </div>
      </StyledCard>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          // 登录成功后跳转到个人主页
          navigate('/profile');
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => setShowForgotPasswordModal(true)}
        onHideForgotPassword={() => setShowForgotPasswordModal(false)}
      />
    </Wrapper>
  );
};

export default ResetPassword; 