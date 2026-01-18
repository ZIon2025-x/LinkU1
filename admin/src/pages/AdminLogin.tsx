import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Form, Input, Button, Card, message, Typography } from 'antd';
import { UserOutlined, LockOutlined, SafetyOutlined, MailOutlined } from '@ant-design/icons';
import { FormInstance } from 'antd/es/form';
import api from '../api';

const { Title, Text } = Typography;

interface AdminLoginData {
  username_or_id: string;
  password: string;
}

interface VerificationData {
  admin_id: string;
  code: string;
}

/**
 * 管理员登录页（支持验证码和ID登录）
 */
const AdminLogin: React.FC = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState<'login' | 'verification'>('login');
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();
  const [verificationForm] = Form.useForm();
  // 使用 state 跟踪验证码输入值，确保实时更新
  const [codeValue, setCodeValue] = useState<string>('');
  const [loginData, setLoginData] = useState<AdminLoginData>({
    username_or_id: '',
    password: ''
  });
  const [verificationData, setVerificationData] = useState<VerificationData>({
    admin_id: '',
    code: ''
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleLogin = async (values: AdminLoginData) => {
    setLoading(true);
    setError('');
    setSuccess('');
    setLoginData(values);

    try {
      const response = await api.post('/api/auth/admin/login', values);
      
      // 检查是否需要邮箱验证码
      if (response.status === 202) {
        // 发送验证码
        const verificationResponse = await api.post('/api/auth/admin/send-verification-code', values);
        
        // 保存管理员ID并切换到验证码输入步骤
        setVerificationData(prev => ({
          ...prev,
          admin_id: verificationResponse.data.admin_id
        }));
        setStep('verification');
        setSuccess('验证码已发送到管理员邮箱，请检查邮箱并输入验证码');
        message.success('验证码已发送到管理员邮箱');
      } else {
        // 正常登录成功（未启用邮箱验证）
        // 登录成功后获取CSRF token
        try {
          await api.get('/api/csrf/token');
        } catch (error) {
          console.error('获取CSRF token失败:', error);
        }
        
        message.success('登录成功');
        navigate('/');
      }
    } catch (error: any) {
      let errorMsg = '登录失败';
      if (error?.response?.data?.detail) {
        errorMsg = error.response.data.detail;
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
      message.error(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleVerification = async (values: { code: string }) => {
    setLoading(true);
    setError('');

    try {
      const response = await api.post('/api/auth/admin/verify-code', {
        ...verificationData,
        code: values.code
      });
      
      // 验证成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
      } catch (error) {
        console.error('获取CSRF token失败:', error);
      }
      
      message.success('验证成功，正在跳转...');
      navigate('/');
    } catch (error: any) {
      let errorMsg = '验证码验证失败';
      if (error?.response?.data?.detail) {
        errorMsg = error.response.data.detail;
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
      message.error(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleResendCode = async () => {
    setLoading(true);
    setError('');

    try {
      await api.post('/api/auth/admin/send-verification-code', loginData);
      setSuccess('验证码已重新发送到管理员邮箱');
      message.success('验证码已重新发送');
    } catch (error: any) {
      let errorMsg = '重新发送验证码失败';
      if (error?.response?.data?.detail) {
        errorMsg = error.response.data.detail;
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
      message.error(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleBackToLogin = () => {
    setStep('login');
    setError('');
    setSuccess('');
    setCodeValue(''); // 清空验证码输入
    setVerificationData({ admin_id: '', code: '' });
    verificationForm.resetFields();
  };

  return (
    <>
      {/* SEO优化：H1标签，几乎不可见但SEO可检测 */}
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
        管理员登录
      </h1>
      
      <div style={{
        minHeight: '100vh',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        padding: '20px'
      }}>
        <Card
          style={{
            width: '100%',
            maxWidth: 400,
            boxShadow: '0 10px 40px rgba(0, 0, 0, 0.2)',
            borderRadius: 12,
          }}
          bodyStyle={{ padding: '40px 32px' }}
        >
          <div style={{ textAlign: 'center', marginBottom: 32 }}>
            <div style={{
              width: 64,
              height: 64,
              margin: '0 auto 16px',
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              borderRadius: 16,
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center'
            }}>
              <SafetyOutlined style={{ fontSize: 32, color: '#fff' }} />
            </div>
            <Title level={3} style={{ margin: 0 }}>
              {step === 'login' ? 'LinkU 管理后台' : '邮箱验证码验证'}
            </Title>
            <Text type="secondary">
              {step === 'login' 
                ? '请使用管理员账号登录' 
                : '请输入发送到管理员邮箱的6位验证码'
              }
            </Text>
          </div>

          {error && (
            <div style={{
              marginBottom: 20,
              padding: '12px',
              background: '#fff1f0',
              border: '1px solid #ffccc7',
              borderRadius: 6,
              color: '#ff4d4f'
            }}>
              {error}
            </div>
          )}

          {success && (
            <div style={{
              marginBottom: 20,
              padding: '12px',
              background: '#f6ffed',
              border: '1px solid #b7eb8f',
              borderRadius: 6,
              color: '#52c41a'
            }}>
              {success}
            </div>
          )}

          {step === 'login' ? (
            <Form
              form={form}
              onFinish={handleLogin}
              size="large"
              autoComplete="off"
            >
              <Form.Item
                name="username_or_id"
                rules={[{ required: true, message: '请输入用户名或ID' }]}
              >
                <Input
                  prefix={<UserOutlined style={{ color: '#bfbfbf' }} />}
                  placeholder="用户名或管理员ID (如: A1234)"
                />
              </Form.Item>

              <Form.Item
                name="password"
                rules={[{ required: true, message: '请输入密码' }]}
              >
                <Input.Password
                  prefix={<LockOutlined style={{ color: '#bfbfbf' }} />}
                  placeholder="密码"
                />
              </Form.Item>

              <Form.Item style={{ marginBottom: 0 }}>
                <Button
                  type="primary"
                  htmlType="submit"
                  loading={loading}
                  block
                  style={{
                    height: 48,
                    fontSize: 16,
                    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    border: 'none',
                  }}
                >
                  登录
                </Button>
              </Form.Item>
            </Form>
          ) : (
            <Form
              form={verificationForm}
              onFinish={handleVerification}
              size="large"
              autoComplete="off"
            >
              <Form.Item
                name="code"
                rules={[
                  { required: true, message: '请输入验证码' },
                  { len: 6, message: '验证码必须是6位数字' },
                  { pattern: /^\d+$/, message: '验证码只能是数字' }
                ]}
              >
                <Input
                  prefix={<MailOutlined style={{ color: '#bfbfbf' }} />}
                  placeholder="000000"
                  maxLength={6}
                  value={codeValue}
                  onChange={(e) => {
                    const value = e.target.value;
                    setCodeValue(value);
                    verificationForm.setFieldsValue({ code: value });
                  }}
                  style={{
                    textAlign: 'center',
                    fontSize: 24,
                    letterSpacing: 8,
                    fontFamily: 'monospace'
                  }}
                />
              </Form.Item>

              <Form.Item style={{ marginBottom: 16 }}>
                <Button
                  type="primary"
                  htmlType="submit"
                  loading={loading}
                  block
                  disabled={codeValue.length !== 6 || !/^\d+$/.test(codeValue) || loading}
                  style={{
                    height: 48,
                    fontSize: 16,
                    background: codeValue.length === 6 && /^\d+$/.test(codeValue) && !loading
                      ? 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)' 
                      : '#d9d9d9',
                    border: 'none',
                    cursor: codeValue.length === 6 && /^\d+$/.test(codeValue) && !loading ? 'pointer' : 'not-allowed',
                  }}
                >
                  {loading ? '验证中...' : '验证'}
                </Button>
              </Form.Item>

              <div style={{ display: 'flex', gap: 12 }}>
                <Button
                  onClick={handleResendCode}
                  disabled={loading}
                  block
                  style={{
                    height: 40,
                    borderColor: '#d9d9d9'
                  }}
                >
                  重新发送
                </Button>
                <Button
                  onClick={handleBackToLogin}
                  disabled={loading}
                  block
                  style={{
                    height: 40,
                    borderColor: '#d9d9d9'
                  }}
                >
                  返回登录
                </Button>
              </div>
            </Form>
          )}

          <div style={{ 
            marginTop: 24, 
            textAlign: 'center',
            color: '#999',
            fontSize: 12
          }}>
            仅限授权管理员访问
          </div>
        </Card>
      </div>
    </>
  );
};

export default AdminLogin;
