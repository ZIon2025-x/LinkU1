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
      // 按优先级检查：管理员 > 客服 > 用户
      const checks = [
        { role: 'admin' as AuthRole, endpoint: '/api/auth/admin/profile' },
        { role: 'service' as AuthRole, endpoint: '/api/auth/service/profile' },
        { role: 'user' as AuthRole, endpoint: '/api/users/profile/me' }
      ];

      for (const check of checks) {
        try {
          const response = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}${check.endpoint}`, {
            credentials: 'include'
          });

          if (response.ok) {
            const userData = await response.json();
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
          endpoint = '/api/auth/service/login';
          break;
        case 'user':
          endpoint = '/api/users/login';
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
        setAuthState({
          isAuthenticated: true,
          role,
          user: data.user || data.admin || data.service,
          loading: false
        });
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
          endpoint = '/api/users/logout';
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
