import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

interface AdminLoginData {
  username: string;
  password: string;
}

interface VerificationData {
  admin_id: string;
  code: string;
}

const AdminLoginWithVerification: React.FC = () => {
  const [step, setStep] = useState<'login' | 'verification'>('login');
  const [loginData, setLoginData] = useState<AdminLoginData>({
    username: '',
    password: ''
  });
  const [verificationData, setVerificationData] = useState<VerificationData>({
    admin_id: '',
    code: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const response = await api.post('/api/auth/admin/login', loginData);
      
      // 检查是否需要邮箱验证码
      if (response.status === 202) {
        console.log('需要邮箱验证码，发送验证码...');
        
        // 发送验证码
        const verificationResponse = await api.post('/api/auth/admin/send-verification-code', loginData);
        console.log('验证码已发送:', verificationResponse.data);
        
        // 保存管理员ID并切换到验证码输入步骤
        setVerificationData(prev => ({
          ...prev,
          admin_id: verificationResponse.data.admin_id
        }));
        setStep('verification');
        setSuccess('验证码已发送到管理员邮箱，请检查邮箱并输入验证码');
      } else {
        // 正常登录成功（未启用邮箱验证）
        console.log('管理员登录成功，使用HttpOnly Cookie认证');
        
        // 登录成功后获取CSRF token
        try {
          await api.get('/api/csrf/token');
          console.log('管理员登录成功后获取CSRF token');
        } catch (error) {
          console.warn('获取CSRF token失败:', error);
        }
        
        // 跳转到管理后台
        navigate('/zh/admin');
      }
    } catch (error: any) {
      let errorMsg = '登录失败';
      if (error?.response?.data?.detail) {
        errorMsg = error.response.data.detail;
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleVerification = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await api.post('/api/auth/admin/verify-code', verificationData);
      console.log('验证码验证成功:', response.data);
      
      // 验证成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
        console.log('验证成功后获取CSRF token');
      } catch (error) {
        console.warn('获取CSRF token失败:', error);
      }
      
      // 跳转到管理后台
      navigate('/zh/admin');
    } catch (error: any) {
      let errorMsg = '验证码验证失败';
      if (error?.response?.data?.detail) {
        errorMsg = error.response.data.detail;
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleResendCode = async () => {
    setLoading(true);
    setError('');

    try {
      const response = await api.post('/api/auth/admin/send-verification-code', loginData);
      console.log('验证码重新发送:', response.data);
      setSuccess('验证码已重新发送到管理员邮箱');
    } catch (error: any) {
      let errorMsg = '重新发送验证码失败';
      if (error?.response?.data?.detail) {
        errorMsg = error.response.data.detail;
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleBackToLogin = () => {
    setStep('login');
    setError('');
    setSuccess('');
    setVerificationData({ admin_id: '', code: '' });
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            {step === 'login' ? '管理员登录' : '邮箱验证码验证'}
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            {step === 'login' 
              ? '请输入您的管理员凭据' 
              : '请输入发送到管理员邮箱的6位验证码'
            }
          </p>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded">
            {error}
          </div>
        )}

        {success && (
          <div className="bg-green-50 border border-green-200 text-green-600 px-4 py-3 rounded">
            {success}
          </div>
        )}

        {step === 'login' ? (
          <form className="mt-8 space-y-6" onSubmit={handleLogin}>
            <div className="space-y-4">
              <div>
                <label htmlFor="username" className="block text-sm font-medium text-gray-700">
                  用户名或ID
                </label>
                <input
                  id="username"
                  name="username"
                  type="text"
                  required
                  value={loginData.username}
                  onChange={(e) => setLoginData(prev => ({ ...prev, username: e.target.value }))}
                  className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                  placeholder="输入用户名或管理员ID (如: A1234)"
                />
              </div>
              <div>
                <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                  密码
                </label>
                <input
                  id="password"
                  name="password"
                  type="password"
                  required
                  value={loginData.password}
                  onChange={(e) => setLoginData(prev => ({ ...prev, password: e.target.value }))}
                  className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                  placeholder="输入密码"
                />
              </div>
            </div>

            <div>
              <button
                type="submit"
                disabled={loading}
                className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
              >
                {loading ? '登录中...' : '登录'}
              </button>
            </div>
          </form>
        ) : (
          <form className="mt-8 space-y-6" onSubmit={handleVerification}>
            <div className="space-y-4">
              <div>
                <label htmlFor="code" className="block text-sm font-medium text-gray-700">
                  验证码
                </label>
                <input
                  id="code"
                  name="code"
                  type="text"
                  required
                  maxLength={6}
                  value={verificationData.code}
                  onChange={(e) => setVerificationData(prev => ({ ...prev, code: e.target.value }))}
                  className="mt-1 appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm text-center text-2xl tracking-widest"
                  placeholder="000000"
                />
                <p className="mt-1 text-xs text-gray-500">
                  请输入6位数字验证码
                </p>
              </div>
            </div>

            <div className="space-y-3">
              <button
                type="submit"
                disabled={loading || verificationData.code.length !== 6}
                className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
              >
                {loading ? '验证中...' : '验证'}
              </button>
              
              <div className="flex space-x-3">
                <button
                  type="button"
                  onClick={handleResendCode}
                  disabled={loading}
                  className="flex-1 py-2 px-4 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
                >
                  重新发送
                </button>
                
                <button
                  type="button"
                  onClick={handleBackToLogin}
                  disabled={loading}
                  className="flex-1 py-2 px-4 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
                >
                  返回登录
                </button>
              </div>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default AdminLoginWithVerification;
