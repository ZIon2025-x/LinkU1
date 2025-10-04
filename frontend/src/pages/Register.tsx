import React, { useState } from 'react';
import { Form, Input, Button, Card, message, Alert, Typography } from 'antd';
import styled from 'styled-components';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import api from '../api';

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
  const { t } = useLanguage();
  const [errorMsg, setErrorMsg] = useState('');
  const [password, setPassword] = useState('');

  // 密码验证函数
  const validatePassword = (pwd: string) => {
    return {
      length: pwd.length >= 8,
      hasLetter: /[A-Za-z]/.test(pwd),
      hasNumber: /\d/.test(pwd)
    };
  };

  const passwordValidation = validatePassword(password);

  const onFinish = async (values: any) => {
    try {
      const res = await api.post('/api/users/register', values);
      setErrorMsg(''); // 注册成功清空错误
      
      if (res.data.verification_required) {
        message.success(`注册成功！我们已向 ${res.data.email} 发送了验证邮件，请检查您的邮箱并点击验证链接完成注册。`);
        // 3秒后跳转到重发验证邮件页面
        setTimeout(() => {
          navigate('/resend-verification');
        }, 3000);
      } else {
        message.success(res.data.message || '注册成功！');
        // 开发环境：直接跳转到登录页面
        setTimeout(() => {
          navigate('/login');
        }, 1500);
      }
    } catch (err: any) {
      console.error('Registration error:', err);
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
      
      console.log('Displaying error message:', msg);
      setErrorMsg(msg);
    }
  };

  return (
    <Wrapper>
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
              { min: 8, message: t('register.passwordTooShort') },
              { pattern: /^(?=.*[A-Za-z])(?=.*\d).{8,}$/, message: t('register.passwordWeak') }
            ]}
          > 
            <Input.Password 
              placeholder={t('register.password')} 
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            {password && (
              <PasswordRequirements>
                <PasswordRequirementItem valid={passwordValidation.length}>
                  ✓ {t('register.passwordRequirements.length')}
                </PasswordRequirementItem>
                <PasswordRequirementItem valid={passwordValidation.hasLetter}>
                  ✓ {t('register.passwordRequirements.letter')}
                </PasswordRequirementItem>
                <PasswordRequirementItem valid={passwordValidation.hasNumber}>
                  ✓ {t('register.passwordRequirements.number')}
                </PasswordRequirementItem>
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
              <Button type="link" onClick={() => navigate('/login')} style={{ padding: 0 }}>
                {t('register.loginHere')}
              </Button>
            </Text>
          </div>
        </Form>
      </StyledCard>
    </Wrapper>
  );
};

export default Register; 