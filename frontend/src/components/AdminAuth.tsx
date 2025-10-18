import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

interface AdminLoginData {
  username: string;
  password: string;
}

interface AdminProfile {
  id: string;
  name: string;
  username: string;
  email: string;
  is_super_admin: boolean;
  is_active: boolean;
  created_at: string;
  last_login?: string;
}

const AdminAuth: React.FC = () => {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [adminProfile, setAdminProfile] = useState<AdminProfile | null>(null);
  const [loginData, setLoginData] = useState<AdminLoginData>({
    username: '',
    password: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  // 检查管理员登录状态
  useEffect(() => {
    checkAdminAuthStatus();
  }, []);

  const checkAdminAuthStatus = async () => {
    try {
      // 首先检查是否有管理员Cookie标识
      const hasAdminCookie = document.cookie.includes('admin_authenticated=true');
      
      if (!hasAdminCookie) {
        console.log('没有检测到管理员Cookie标识，直接设置为未登录');
        setIsLoggedIn(false);
        setAdminProfile(null);
        return;
      }

      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/admin/profile`, {
        credentials: 'include'
      });
      
      if (response.ok) {
        const data = await response.json();
        setAdminProfile(data);
        setIsLoggedIn(true);
      } else {
        setIsLoggedIn(false);
        setAdminProfile(null);
      }
    } catch (error) {
      console.error('检查管理员认证状态失败:', error);
      setIsLoggedIn(false);
      setAdminProfile(null);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/admin/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify(loginData)
      });

      const data = await response.json();

      if (response.ok) {
        setAdminProfile(data.admin);
        setIsLoggedIn(true);
        setError('');
        // 可以跳转到管理员面板
        navigate('/admin/dashboard');
      } else {
        setError(data.detail || '登录失败');
      }
    } catch (error) {
      console.error('管理员登录失败:', error);
      setError('登录时发生错误，请稍后重试');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/admin/logout`, {
        method: 'POST',
        credentials: 'include'
      });

      if (response.ok) {
        setIsLoggedIn(false);
        setAdminProfile(null);
        navigate('/admin/login');
      }
    } catch (error) {
      console.error('管理员登出失败:', error);
    }
  };

  const handleChangePassword = async (oldPassword: string, newPassword: string) => {
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/auth/admin/change-password`, {
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

  if (isLoggedIn && adminProfile) {
    return (
      <div style={{ padding: '20px', maxWidth: '600px', margin: '0 auto' }}>
        <h2>管理员控制台</h2>
        <div style={{ 
          background: '#f5f5f5', 
          padding: '20px', 
          borderRadius: '8px', 
          marginBottom: '20px' 
        }}>
          <h3>管理员信息</h3>
          <p><strong>姓名:</strong> {adminProfile.name}</p>
          <p><strong>用户名:</strong> {adminProfile.username}</p>
          <p><strong>邮箱:</strong> {adminProfile.email}</p>
          <p><strong>权限:</strong> {adminProfile.is_super_admin ? '超级管理员' : '普通管理员'}</p>
          <p><strong>状态:</strong> {adminProfile.is_active ? '激活' : '禁用'}</p>
          <p><strong>创建时间:</strong> {new Date(adminProfile.created_at).toLocaleString()}</p>
          {adminProfile.last_login && (
            <p><strong>最后登录:</strong> {new Date(adminProfile.last_login).toLocaleString()}</p>
          )}
        </div>
        
        <div style={{ display: 'flex', gap: '10px' }}>
          <button 
            onClick={() => navigate('/admin/users')}
            style={{
              background: '#007bff',
              color: 'white',
              border: 'none',
              padding: '10px 20px',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            用户管理
          </button>
          <button 
            onClick={() => navigate('/admin/tasks')}
            style={{
              background: '#28a745',
              color: 'white',
              border: 'none',
              padding: '10px 20px',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            任务管理
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
          管理员登录
        </h2>
        
        <form onSubmit={handleLogin}>
          <div style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', marginBottom: '5px', color: '#555' }}>
              用户名
            </label>
            <input
              type="text"
              value={loginData.username}
              onChange={(e) => setLoginData({...loginData, username: e.target.value})}
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

export default AdminAuth;
