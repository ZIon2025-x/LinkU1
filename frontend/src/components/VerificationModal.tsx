import React, { useState } from 'react';
import { Modal, Button, message, Alert } from 'antd';
import api from '../api';

interface VerificationModalProps {
  isOpen: boolean;
  onClose: () => void;
  email: string;
  onLogin?: () => void;
}

const VerificationModal: React.FC<VerificationModalProps> = ({
  isOpen,
  onClose,
  email,
  onLogin
}) => {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleResendVerification = async () => {
    setLoading(true);
    try {
      await api.post('/api/users/resend-verification', email, {
        headers: {
          'Content-Type': 'text/plain'
        }
      });
      setSuccess(true);
      message.success('验证邮件已重新发送！');
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || '发送失败，请稍后重试';
      message.error(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = () => {
    onClose();
    if (onLogin) {
      onLogin();
    }
  };

  return (
    <Modal
      title="邮箱验证"
      open={isOpen}
      onCancel={onClose}
      footer={null}
      width={480}
      centered
    >
      <div style={{ textAlign: 'center', padding: '20px 0' }}>
        {!success ? (
          <>
            <div style={{ fontSize: 48, color: '#1890ff', marginBottom: 16 }}>📧</div>
            <h3 style={{ marginBottom: 16, color: '#333' }}>请验证您的邮箱</h3>
            <p style={{ marginBottom: 24, color: '#666', fontSize: 14 }}>
              我们已向 <strong style={{ color: '#1890ff' }}>{email}</strong> 发送了验证邮件
            </p>
            <Alert
              message="请检查您的邮箱并点击验证链接完成注册"
              type="info"
              showIcon
              style={{ marginBottom: 24, textAlign: 'left' }}
            />
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <Button 
                onClick={handleResendVerification}
                loading={loading}
                type="primary"
                style={{
                  background: 'linear-gradient(135deg, #1890ff, #096dd9)',
                  border: 'none',
                  borderRadius: '6px',
                  height: '40px',
                  padding: '0 24px',
                  fontWeight: '500'
                }}
              >
                重新发送验证邮件
              </Button>
              <Button 
                onClick={handleLogin}
                style={{
                  height: '40px',
                  padding: '0 24px',
                  borderRadius: '6px'
                }}
              >
                去登录
              </Button>
            </div>
          </>
        ) : (
          <>
            <div style={{ fontSize: 48, color: '#52c41a', marginBottom: 16 }}>✅</div>
            <h3 style={{ marginBottom: 16, color: '#52c41a' }}>邮件发送成功！</h3>
            <p style={{ marginBottom: 24, color: '#666', fontSize: 14 }}>
              验证邮件已重新发送到 <strong style={{ color: '#1890ff' }}>{email}</strong>
            </p>
            <Alert
              message="请检查您的邮箱（包括垃圾邮件文件夹）并点击验证链接"
              type="success"
              showIcon
              style={{ marginBottom: 24, textAlign: 'left' }}
            />
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <Button 
                onClick={() => setSuccess(false)}
                style={{
                  height: '40px',
                  padding: '0 24px',
                  borderRadius: '6px'
                }}
              >
                再次发送
              </Button>
              <Button 
                onClick={handleLogin}
                type="primary"
                style={{
                  background: 'linear-gradient(135deg, #52c41a, #389e0d)',
                  border: 'none',
                  borderRadius: '6px',
                  height: '40px',
                  padding: '0 24px',
                  fontWeight: '500'
                }}
              >
                去登录
              </Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
};

export default VerificationModal;
