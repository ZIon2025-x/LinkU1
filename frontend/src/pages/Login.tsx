import React, { useState, useEffect } from 'react';
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
  width: 350px;
  box-shadow: 0 2px 8px #f0f1f2;
`;

const ErrorMsg = styled.div`
  color: #ff4d4f;
  margin-bottom: 12px;
  text-align: center;
`;

const Login: React.FC = () => {
  const navigate = useNavigate();
  const [errorMsg, setErrorMsg] = useState('');
  const [loading, setLoading] = useState(false);

  // 检查用户是否已登录
  useEffect(() => {
    // 直接检查用户是否已登录，HttpOnly Cookie会自动发送
    api.get('/api/users/profile/me')
      .then(() => {
        // 用户已登录，重定向到首页
        message.info('您已登录，正在跳转到首页...');
        navigate('/');
      })
      .catch(() => {
        // 用户未登录，继续显示登录页面
        console.log('用户未登录');
      });
  }, [navigate]);

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      const res = await api.post('/api/secure-auth/login', {
        email: values.email,
        password: values.password,
      });
      // HttpOnly Cookie已由后端自动设置，无需手动存储
      setErrorMsg(''); // 登录成功清空错误
      message.success('登录成功！');
      // 添加短暂延迟确保Cookie设置完成
      setTimeout(() => {
        navigate('/');
      }, 100);
    } catch (err: any) {
      let msg = '登录失败';
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
    } finally {
      setLoading(false);
    }
  };

  return (
    <Wrapper>
      <StyledCard title="Login to LinkU">
        {errorMsg && <ErrorMsg>{errorMsg}</ErrorMsg>}
        <Form layout="vertical" onFinish={onFinish}>
          <Form.Item label="Email" name="email" rules={[{ required: true, type: 'email' }]}> 
            <Input placeholder="Enter your email" />
          </Form.Item>
          <Form.Item label="Password" name="password" rules={[{ required: true }]}> 
            <Input.Password placeholder="Enter your password" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" block loading={loading}>Login</Button>
          </Form.Item>
        </Form>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          <Button type="link" onClick={() => navigate('/forgot-password')}>Forgot Password?</Button>
          <Button type="link" onClick={() => navigate('/register')}>Register</Button>
        </div>
      </StyledCard>
    </Wrapper>
  );
};

export default Login; 