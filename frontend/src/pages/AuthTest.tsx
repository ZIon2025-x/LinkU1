import React, { useState } from 'react';
import { useAuthContext, useCurrentUser, useIsAdmin, useIsService, useIsUser } from '../contexts/AuthContext';

const AuthTest: React.FC = () => {
  const { isAuthenticated, role, user, login, logout, loading } = useAuthContext();
  const currentUser = useCurrentUser();
  const isAdmin = useIsAdmin();
  const isService = useIsService();
  const isUser = useIsUser();

  const [loginData, setLoginData] = useState({
    role: 'user' as 'user' | 'service' | 'admin',
    username: '',
    email: '',
    password: ''
  });

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    
    let credentials: any = { password: loginData.password };
    
    if (loginData.role === 'admin') {
      credentials.username = loginData.username;
    } else {
      credentials.email = loginData.email;
    }

    const success = await login(loginData.role, credentials);
    if (success) {
      alert('登录成功！');
    } else {
      alert('登录失败！');
    }
  };

  const handleLogout = async () => {
    await logout();
    alert('已登出！');
  };

  if (loading) {
    return <div>检查认证状态中...</div>;
  }

  return (
    <div style={{ padding: '20px', maxWidth: '800px', margin: '0 auto' }}>
      <h1>认证系统测试页面</h1>
      
      {/* 认证状态显示 */}
      <div style={{ 
        background: '#f5f5f5', 
        padding: '20px', 
        borderRadius: '8px', 
        marginBottom: '20px' 
      }}>
        <h2>当前认证状态</h2>
        <p><strong>是否已认证:</strong> {isAuthenticated ? '是' : '否'}</p>
        <p><strong>角色:</strong> {role || '无'}</p>
        <p><strong>用户信息:</strong></p>
        <pre style={{ background: '#fff', padding: '10px', borderRadius: '4px' }}>
          {JSON.stringify(user, null, 2)}
        </pre>
        
        <h3>角色检查</h3>
        <p><strong>是管理员:</strong> {isAdmin ? '是' : '否'}</p>
        <p><strong>是客服:</strong> {isService ? '是' : '否'}</p>
        <p><strong>是用户:</strong> {isUser ? '是' : '否'}</p>
      </div>

      {/* 登录表单 */}
      {!isAuthenticated && (
        <div style={{ 
          background: '#e9f7ef', 
          padding: '20px', 
          borderRadius: '8px', 
          marginBottom: '20px' 
        }}>
          <h2>登录测试</h2>
          <form onSubmit={handleLogin}>
            <div style={{ marginBottom: '15px' }}>
              <label>
                角色:
                <select 
                  value={loginData.role} 
                  onChange={(e) => setLoginData({...loginData, role: e.target.value as any})}
                  style={{ marginLeft: '10px', padding: '5px' }}
                >
                  <option value="user">用户</option>
                  <option value="service">客服</option>
                  <option value="admin">管理员</option>
                </select>
              </label>
            </div>

            {loginData.role === 'admin' ? (
              <div style={{ marginBottom: '15px' }}>
                <label>
                  用户名:
                  <input
                    type="text"
                    value={loginData.username}
                    onChange={(e) => setLoginData({...loginData, username: e.target.value})}
                    style={{ marginLeft: '10px', padding: '5px' }}
                    required
                  />
                </label>
              </div>
            ) : (
              <div style={{ marginBottom: '15px' }}>
                <label>
                  邮箱:
                  <input
                    type="email"
                    value={loginData.email}
                    onChange={(e) => setLoginData({...loginData, email: e.target.value})}
                    style={{ marginLeft: '10px', padding: '5px' }}
                    required
                  />
                </label>
              </div>
            )}

            <div style={{ marginBottom: '15px' }}>
              <label>
                密码:
                <input
                  type="password"
                  value={loginData.password}
                  onChange={(e) => setLoginData({...loginData, password: e.target.value})}
                  style={{ marginLeft: '10px', padding: '5px' }}
                  required
                />
              </label>
            </div>

            <button type="submit" style={{ 
              background: '#007bff', 
              color: 'white', 
              border: 'none', 
              padding: '10px 20px', 
              borderRadius: '4px',
              cursor: 'pointer'
            }}>
              登录
            </button>
          </form>
        </div>
      )}

      {/* 登出按钮 */}
      {isAuthenticated && (
        <div style={{ 
          background: '#f8d7da', 
          padding: '20px', 
          borderRadius: '8px', 
          marginBottom: '20px' 
        }}>
          <h2>登出测试</h2>
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
      )}

      {/* API测试 */}
      <div style={{ 
        background: '#d1ecf1', 
        padding: '20px', 
        borderRadius: '8px' 
      }}>
        <h2>API测试</h2>
        <p>测试不同的认证端点：</p>
        <ul>
          <li><a href="/en/admin/auth" target="_blank">管理员认证页面</a></li>
          <li><a href="/en/service/login" target="_blank">客服登录页面</a></li>
          <li><a href="/en/admin-panel" target="_blank">管理员面板（需要认证）</a></li>
          <li><a href="/en/service" target="_blank">客服面板（需要认证）</a></li>
        </ul>
      </div>
    </div>
  );
};

export default AuthTest;
