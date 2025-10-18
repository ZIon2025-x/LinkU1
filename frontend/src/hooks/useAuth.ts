import { useState, useEffect, useCallback } from 'react';

// 认证状态类型
export type AuthRole = 'user' | 'service' | 'admin' | null;

export interface AuthState {
  isAuthenticated: boolean;
  role: AuthRole;
  user: any;
  loading: boolean;
}

export interface AuthContextType extends AuthState {
  login: (role: AuthRole, credentials: any) => Promise<boolean>;
  logout: () => Promise<void>;
  checkAuth: () => Promise<void>;
}

// 认证状态管理Hook
export const useAuth = () => {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    role: null,
    user: null,
    loading: true
  });

  // 检查认证状态
  const checkAuth = useCallback(async () => {
    setAuthState(prev => ({ ...prev, loading: true }));

    try {
      // 首先检查Cookie标识，避免不必要的请求
      const hasAdminCookie = document.cookie.includes('admin_authenticated=true');
      const hasServiceCookie = document.cookie.includes('service_authenticated=true');
      const hasUserCookie = document.cookie.includes('user_authenticated=true') || 
                           document.cookie.includes('access_token=');

      console.log('Cookie检查:', { hasAdminCookie, hasServiceCookie, hasUserCookie });
      console.log('当前Cookie:', document.cookie);
      
      // 如果检测到任何Cookie，优先使用该角色
      if (hasAdminCookie || hasServiceCookie || hasUserCookie) {
        console.log('检测到Cookie标识，跳过通用检查');
      }

      // 按优先级检查：管理员 > 客服 > 用户
      const checks = [];
      
      if (hasAdminCookie) {
        checks.push({ role: 'admin' as AuthRole, endpoint: '/api/auth/admin/profile' });
      }
      if (hasServiceCookie) {
        checks.push({ role: 'service' as AuthRole, endpoint: '/api/auth/service/profile' });
      }
      if (hasUserCookie) {
        checks.push({ role: 'user' as AuthRole, endpoint: '/api/users/profile/me' });
      }

      // 如果没有检测到任何Cookie标识，则按顺序检查所有角色
      if (checks.length === 0) {
        console.log('没有检测到Cookie标识，按顺序检查所有角色');
        checks.push(
          { role: 'admin' as AuthRole, endpoint: '/api/auth/admin/profile' },
          { role: 'service' as AuthRole, endpoint: '/api/auth/service/profile' },
          { role: 'user' as AuthRole, endpoint: '/api/users/profile/me' }
        );
      } else {
        console.log('检测到Cookie标识，只检查相关角色:', checks.map(c => c.role));
      }

      console.log('认证检查列表:', checks);

      for (const check of checks) {
        try {
          console.log(`检查${check.role}认证状态:`, check.endpoint);
          const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}${check.endpoint}`, {
            credentials: 'include'
          });

          console.log(`${check.role}认证响应:`, response.status);

          if (response.ok) {
            const userData = await response.json();
            console.log(`${check.role}认证成功:`, userData);
            setAuthState({
              isAuthenticated: true,
              role: check.role,
              user: userData,
              loading: false
            });
            return;
          }
        } catch (error) {
          console.error(`检查${check.role}认证状态失败:`, error);
        }
      }

      // 如果所有检查都失败
      console.log('所有认证检查都失败');
      setAuthState({
        isAuthenticated: false,
        role: null,
        user: null,
        loading: false
      });
    } catch (error) {
      console.error('认证状态检查失败:', error);
      setAuthState({
        isAuthenticated: false,
        role: null,
        user: null,
        loading: false
      });
    }
  }, []);

  // 登录
  const login = useCallback(async (role: AuthRole, credentials: any): Promise<boolean> => {
    if (!role) return false;

    try {
      let endpoint = '';
      switch (role) {
        case 'admin':
          endpoint = '/api/auth/admin/login';
          break;
        case 'service':
          endpoint = '/api/cs/login';
          break;
        case 'user':
          endpoint = '/api/secure-auth/login';
          break;
        default:
          return false;
      }

      const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}${endpoint}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify(credentials)
      });

      if (response.ok) {
        const data = await response.json();
        console.log('登录成功，响应数据:', data);
        
        // 根据角色获取用户数据
        let userData = null;
        if (role === 'admin' && data.admin) {
          userData = data.admin;
        } else if (role === 'service' && data.service) {
          userData = data.service;
        } else if (role === 'user' && data.user) {
          userData = data.user;
        }
        
        setAuthState({
          isAuthenticated: true,
          role,
          user: userData,
          loading: false
        });
        
        // 登录成功后直接设置认证状态，避免重新检查
        console.log('登录成功，设置认证状态:', { role, user: userData });
        
        // 登录成功后，确保Cookie已设置，然后重新检查认证状态
        setTimeout(() => {
          console.log('登录后重新检查认证状态...');
          checkAuth();
        }, 2000);
        
        return true;
      } else {
        const errorData = await response.json();
        console.error('登录失败:', errorData.detail || '未知错误');
        return false;
      }
    } catch (error) {
      console.error('登录时发生错误:', error);
      return false;
    }
  }, []);

  // 登出
  const logout = useCallback(async () => {
    try {
      let endpoint = '';
      switch (authState.role) {
        case 'admin':
          endpoint = '/api/auth/admin/logout';
          break;
        case 'service':
          endpoint = '/api/auth/service/logout';
          break;
        case 'user':
          endpoint = '/api/secure-auth/logout';
          break;
        default:
          break;
      }

      if (endpoint) {
        await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}${endpoint}`, {
          method: 'POST',
          credentials: 'include'
        });
      }
    } catch (error) {
      console.error('登出时发生错误:', error);
    } finally {
      setAuthState({
        isAuthenticated: false,
        role: null,
        user: null,
        loading: false
      });
    }
  }, [authState.role]);

  // 组件挂载时检查认证状态
  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  return {
    ...authState,
    login,
    logout,
    checkAuth
  };
};

// 角色权限检查Hook
export const useRoleAuth = (requiredRole: AuthRole) => {
  const auth = useAuth();
  
  const hasPermission = auth.isAuthenticated && auth.role === requiredRole;
  const isLoading = auth.loading;
  
  return {
    hasPermission,
    isLoading,
    user: auth.user,
    role: auth.role
  };
};

// 多角色权限检查Hook
export const useMultiRoleAuth = (allowedRoles: AuthRole[]) => {
  const auth = useAuth();
  
  const hasPermission = auth.isAuthenticated && 
    auth.role !== null && 
    allowedRoles.includes(auth.role);
  const isLoading = auth.loading;
  
  return {
    hasPermission,
    isLoading,
    user: auth.user,
    role: auth.role
  };
};
