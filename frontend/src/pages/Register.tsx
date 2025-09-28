import React, { useState } from 'react';
import { Form, Input, Button, Card, message } from 'antd';
import styled from 'styled-components';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import api from '../api';

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

const Register: React.FC = () => {
  const navigate = useNavigate();
  const [errorMsg, setErrorMsg] = useState('');

  const onFinish = async (values: any) => {
    try {
      const res = await api.post('/api/users/register', values);
      setErrorMsg(''); // 注册成功清空错误
      
      if (res.data.verification_required) {
        message.success(`注册成功！我们已向 ${res.data.email} 发送了验证邮件，请检查您的邮箱并点击验证链接完成注册。`);
      } else {
        message.success('注册成功！');
        navigate('/login');
      }
    } catch (err: any) {
      let msg = '注册失败';
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
    }
  };

  return (
    <Wrapper>
      <StyledCard title="Register for LinkU">
        {errorMsg && <ErrorMsg>{errorMsg}</ErrorMsg>}
        <Form layout="vertical" onFinish={onFinish}>
          <Form.Item label="Name" name="name" rules={[{ required: true }]}> 
            <Input placeholder="Enter your name" />
          </Form.Item>
          <Form.Item label="Email" name="email" rules={[{ required: true, type: 'email' }]}> 
            <Input placeholder="Enter your email" />
          </Form.Item>
          <Form.Item label="Phone" name="phone"> 
            <Input placeholder="Enter your phone (optional)" />
          </Form.Item>
          <Form.Item label="Password" name="password" rules={[{ required: true, min: 6 }]}> 
            <Input.Password placeholder="Enter your password (min 6 chars)" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" block>Register</Button>
          </Form.Item>
        </Form>
      </StyledCard>
    </Wrapper>
  );
};

export default Register; 