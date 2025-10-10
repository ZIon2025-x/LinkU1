import React, { useState } from 'react';
import { Form, Input, Button, Card, message } from 'antd';
import styled from 'styled-components';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../api';

const Wrapper = styled.div`
  min-height: 80vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f9f9f9;
`;

const StyledCard = styled(Card)`
  width: 350px;
  box-shadow: 0 2px 8px #f0f1f2;
`;

const ErrorMsg = styled.div`
  color: #ff4d4f;
  margin-bottom: 12px;
  text-align: center;
`;

const ResetPassword: React.FC = () => {
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const navigate = useNavigate();
  const { token } = useParams();

  const onFinish = async (values: any) => {
    try {
      await api.post(
        `/api/users/reset_password/${token}`,
        new URLSearchParams({ new_password: values.password }),
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
      );
      setErrorMsg('');
      setSuccessMsg('Password reset successful! Redirecting to login...');
      setTimeout(() => {
        navigate('/login');
      }, 2000);
    } catch (err: any) {
      let msg = 'Password reset failed';
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
      setErrorMsg(msg);
      setSuccessMsg('');
    }
  };

  return (
    <Wrapper>
      <StyledCard title="Reset Password">
        {errorMsg && <ErrorMsg>{errorMsg}</ErrorMsg>}
        {successMsg && <div style={{ color: '#52c41a', marginBottom: 12, textAlign: 'center' }}>{successMsg}</div>}
        <Form layout="vertical" onFinish={onFinish}>
          <Form.Item 
            label="New Password" 
            name="password" 
            rules={[
              { required: true, message: '请输入新密码' }
            ]}
          > 
            <Input.Password placeholder="Enter your new password (min 8 chars, must contain letters and numbers)" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" block>Reset Password</Button>
          </Form.Item>
        </Form>
        <div style={{ textAlign: 'center', marginTop: 8 }}>
          <Button type="link" onClick={() => navigate('/login')}>Back to Login</Button>
        </div>
      </StyledCard>
    </Wrapper>
  );
};

export default ResetPassword; 