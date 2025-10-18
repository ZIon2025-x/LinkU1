import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

interface ServiceLoginData {
  cs_id: string;
  password: string;
}

interface ServiceProfile {
  id: string;
  name: string;
  email: string;
  avg_rating: number;
  total_ratings: number;
  is_online: boolean;
  created_at: string;
}

const ServiceAuth: React.FC = () => {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [serviceProfile, setServiceProfile] = useState<ServiceProfile | null>(null);
  const [loginData, setLoginData] = useState<ServiceLoginData>({
    cs_id: '',
    password: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  // 检查客服登录状态
  useEffect(() => {
    checkServiceAuthStatus();
  }, []);

  const checkServiceAuthStatus = async () => {
    try {
      // 首先检查是否有客服Cookie标识
      const hasServiceCookie = document.cookie.includes('service_authenticated=true');
      
      if (!hasServiceCookie) {
        console.log('没有检测到客服Cookie标识，直接设置为未登录');
        setIsLoggedIn(false);
        setServiceProfile(null);
        return;
      }

      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/service/profile`, {
        credentials: 'include'
      });
      
      if (response.ok) {
        const data = await response.json();
        setServiceProfile(data);
        setIsLoggedIn(true);
      } else {
        setIsLoggedIn(false);
        setServiceProfile(null);
      }
    } catch (error) {
      console.error('检查客服认证状态失败:', error);
      setIsLoggedIn(false);
      setServiceProfile(null);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/service/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify(loginData)
      });

      const data = await response.json();

      if (response.ok) {
        setServiceProfile(data.service);
        setIsLoggedIn(true);
        setError('');
        
        // 不保存session_id到localStorage，使用HttpOnly Cookie
        console.log('客服登录成功，使用HttpOnly Cookie认证');
        
        // 跳转到客服面板
        navigate('/service/dashboard');
      } else {
        setError(data.detail || '登录失败');
      }
    } catch (error) {
      console.error('客服登录失败:', error);
      setError('登录时发生错误，请稍后重试');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/service/logout`, {
        method: 'POST',
        credentials: 'include'
      });

      if (response.ok) {
        setIsLoggedIn(false);
        setServiceProfile(null);
        navigate('/service/login');
      }
    } catch (error) {
      console.error('客服登出失败:', error);
    }
  };

  const handleChangePassword = async (oldPassword: string, newPassword: string) => {
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/service/change-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify({
          old_password: oldPassword,
          new_password: newPassword
        })
      });

      if (response.ok) {
        alert('密码修改成功');
      } else {
        const data = await response.json();
        alert(data.detail || '密码修改失败');
      }
    } catch (error) {
      console.error('密码修改失败:', error);
      alert('密码修改时发生错误');
    }
  };

  if (isLoggedIn && serviceProfile) {
    return (
      <div style={{ padding: '20px', maxWidth: '600px', margin: '0 auto' }}>
        <h2>客服控制台</h2>
        <div style={{ 
          background: '#f5f5f5', 
          padding: '20px', 
          borderRadius: '8px', 
          marginBottom: '20px' 
        }}>
          <h3>客服信息</h3>
          <p><strong>姓名:</strong> {serviceProfile.name}</p>
          <p><strong>邮箱:</strong> {serviceProfile.email}</p>
          <p><strong>客服ID:</strong> {serviceProfile.id}</p>
          <p><strong>平均评分:</strong> {serviceProfile.avg_rating.toFixed(1)} ⭐</p>
          <p><strong>总评分数量:</strong> {serviceProfile.total_ratings}</p>
          <p><strong>在线状态:</strong> {serviceProfile.is_online ? '在线' : '离线'}</p>
          <p><strong>创建时间:</strong> {new Date(serviceProfile.created_at).toLocaleString()}</p>
        </div>
        
        <div style={{ display: 'flex', gap: '10px' }}>
          <button 
            onClick={() => navigate('/service/chat')}
            style={{
              background: '#007bff',
              color: 'white',
              border: 'none',
              padding: '10px 20px',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            客服聊天
          </button>
          <button 
            onClick={() => navigate('/service/requests')}
            style={{
              background: '#28a745',
              color: 'white',
              border: 'none',
              padding: '10px 20px',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            客服请求
          </button>
          <button 
            onClick={handleLogout}
            style={{
              background: '#dc3545',
              color: 'white',
              border: 'none',
              padding: '10px 20px',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            登出
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={{ 
      display: 'flex', 
      justifyContent: 'center', 
      alignItems: 'center', 
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
    }}>
      <div style={{
        background: 'white',
        padding: '40px',
        borderRadius: '10px',
        boxShadow: '0 15px 35px rgba(0,0,0,0.1)',
        width: '100%',
        maxWidth: '400px'
      }}>
        <h2 style={{ textAlign: 'center', marginBottom: '30px', color: '#333' }}>
          客服登录
        </h2>
        
        <form onSubmit={handleLogin}>
          <div style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', marginBottom: '5px', color: '#555' }}>
              邮箱
            </label>
            <input
              type="email"
              value={loginData.cs_id}
              onChange={(e) => setLoginData({...loginData, cs_id: e.target.value})}
              required
              style={{
                width: '100%',
                padding: '12px',
                border: '1px solid #ddd',
                borderRadius: '5px',
                fontSize: '16px'
              }}
            />
          </div>
          
          <div style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', marginBottom: '5px', color: '#555' }}>
              密码
            </label>
            <input
              type="password"
              value={loginData.password}
              onChange={(e) => setLoginData({...loginData, password: e.target.value})}
              required
              style={{
                width: '100%',
                padding: '12px',
                border: '1px solid #ddd',
                borderRadius: '5px',
                fontSize: '16px'
              }}
            />
          </div>
          
          {error && (
            <div style={{
              color: '#dc3545',
              marginBottom: '20px',
              padding: '10px',
              background: '#f8d7da',
              border: '1px solid #f5c6cb',
              borderRadius: '4px'
            }}>
              {error}
            </div>
          )}
          
          <button
            type="submit"
            disabled={loading}
            style={{
              width: '100%',
              padding: '12px',
              background: loading ? '#6c757d' : '#007bff',
              color: 'white',
              border: 'none',
              borderRadius: '5px',
              fontSize: '16px',
              cursor: loading ? 'not-allowed' : 'pointer'
            }}
          >
            {loading ? '登录中...' : '登录'}
          </button>
        </form>
      </div>
    </div>
  );
};

export default ServiceAuth;
