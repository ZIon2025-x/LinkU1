import React, { createContext, useContext, ReactNode } from 'react';
import { useAuth, AuthContextType } from '../hooks/useAuth';

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const auth = useAuth();

  return (
    <AuthContext.Provider value={auth}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuthContext = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuthContext must be used within an AuthProvider');
  }
  return context;
};

// 便捷的Hook，用于获取当前用户信息
export const useCurrentUser = () => {
  const { user, role, isAuthenticated } = useAuthContext();
  return { user, role, isAuthenticated };
};

// 便捷的Hook，用于检查是否为管理员（admin 在独立子域，本前端恒为 false）
export const useIsAdmin = () => false;

// 便捷的Hook，用于检查是否为客服（service 在独立子域，本前端恒为 false）
export const useIsService = () => false;

// 便捷的Hook，用于检查是否为用户
export const useIsUser = () => {
  const { role, isAuthenticated } = useAuthContext();
  return isAuthenticated && role === 'user';
};
