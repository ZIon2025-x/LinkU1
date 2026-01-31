import { useState, useEffect, useCallback } from 'react';

// 认证状态类型（admin、service 在各自子域，本前端仅 user）
export type AuthRole = 'user' | null;

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
      // 简化认证检查 - 直接尝试API验证，让后端处理Cookie
      const checks = [];
      
      // 只检查用户认证，客服认证由专门的组件处理
      checks.push({ role: 'user' as AuthRole, endpoint: '/api/users/profile/me' });


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
        } catch {
          // 忽略单次检查失败
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
    if (!role || role !== 'user') return false;

    try {
      const endpoint = '/api/secure-auth/login';

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
        
        // 登录成功后获取CSRF token
        try {
          const csrfResponse = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/csrf/token`, {
            method: 'GET',
            credentials: 'include'
          });
          if (csrfResponse.ok) {
          }
        } catch {
          // 忽略 CSRF 请求失败
        }
        
        // 获取用户数据
        const userData = data.user || null;
        
        setAuthState({
          isAuthenticated: true,
          role: 'user',
          user: userData,
          loading: false
        });
        
        // 登录成功后直接设置认证状态，避免重新检查
        
        return true;
      } else {
        await response.json();
        return false;
      }
    } catch (error) {
            return false;
    }
  }, []);

  // 登出
  const logout = useCallback(async () => {
    try {
      if (authState.role === 'user') {
        await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/api/secure-auth/logout`, {
          method: 'POST',
          credentials: 'include'
        });
      }
    } catch {
      // 忽略登出请求失败
    } finally {
      setAuthState({
        isAuthenticated: false,
        role: null,
        user: null,
        loading: false
      });
    }
  }, [authState.role]);

  // 组件挂载时检查认证状态，添加延迟确保Cookie已设置
  useEffect(() => {
    const timer = setTimeout(() => {
      checkAuth();
    }, 100); // 延迟100ms确保Cookie已设置
    
    return () => clearTimeout(timer);
  }, []); // 只在组件挂载时调用一次

  // 移除Cookie变化检测，避免无限循环
  // 认证状态检查只在组件挂载时和登录/登出时进行

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
