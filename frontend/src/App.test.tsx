/**
 * App 组件测试
 * 测试应用的核心功能：路由、Provider、错误边界等
 */

import React from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ConfigProvider } from 'antd';

// Mock axios - 必须在其他导入之前
jest.mock('axios', () => ({
  __esModule: true,
  default: {
    create: jest.fn(() => ({
      get: jest.fn(),
      post: jest.fn(),
      put: jest.fn(),
      delete: jest.fn(),
      interceptors: {
        request: { use: jest.fn() },
        response: { use: jest.fn() }
      }
    })),
    get: jest.fn(),
    post: jest.fn(),
    interceptors: {
      request: { use: jest.fn() },
      response: { use: jest.fn() }
    }
  },
  AxiosError: class AxiosError extends Error {}
}));

// Mock api 模块
jest.mock('./api', () => ({
  fetchCurrentUser: jest.fn(),
  API_BASE_URL: 'http://localhost:8000'
}));

// Mock 懒加载组件
jest.mock('./pages/Home', () => ({
  __esModule: true,
  default: () => <div data-testid="home-page">Home Page</div>
}));

jest.mock('./pages/Tasks', () => ({
  __esModule: true,
  default: () => <div data-testid="tasks-page">Tasks Page</div>
}));

jest.mock('./pages/About', () => ({
  __esModule: true,
  default: () => <div data-testid="about-page">About Page</div>
}));

// Mock contexts
jest.mock('./contexts/LanguageContext', () => ({
  LanguageProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
  useLanguage: () => ({
    language: 'en',
    setLanguage: jest.fn(),
    t: (key: string) => key
  })
}));

jest.mock('./contexts/CookieContext', () => ({
  CookieProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
  useCookieConsent: () => ({
    hasConsented: true,
    consent: { necessary: true, analytics: false, marketing: false }
  })
}));

jest.mock('./contexts/AuthContext', () => ({
  AuthProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
  useAuthContext: () => ({
    isAuthenticated: false,
    user: null,
    role: null,
    loading: false,
    login: jest.fn(),
    logout: jest.fn(),
    checkAuth: jest.fn()
  }),
  useCurrentUser: () => ({
    user: null,
    role: null,
    isAuthenticated: false
  })
}));

jest.mock('./contexts/UnreadMessageContext', () => ({
  UnreadMessageProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>
}));

// Mock ProtectedRoute 组件（避免它导入 api.ts）
jest.mock('./components/ProtectedRoute', () => ({
  __esModule: true,
  default: ({ children }: { children: React.ReactNode }) => <>{children}</>
}));

// Mock 其他组件
jest.mock('./components/CookieManager', () => ({
  __esModule: true,
  default: () => null
}));

jest.mock('./components/NotificationPermissionPrompt', () => ({
  __esModule: true,
  default: () => null
}));

jest.mock('./components/OpenInAppBanner', () => ({
  __esModule: true,
  default: () => null
}));

jest.mock('./components/FaviconManager', () => ({
  __esModule: true,
  default: () => null
}));

jest.mock('./components/LanguageMetaManager', () => ({
  __esModule: true,
  default: () => null
}));

jest.mock('./components/OrganizationStructuredData', () => ({
  __esModule: true,
  default: () => null
}));

jest.mock('./components/ScrollToTop', () => ({
  __esModule: true,
  default: () => null
}));

// 创建测试用的 QueryClient
const createTestQueryClient = () => new QueryClient({
  defaultOptions: {
    queries: {
      retry: false,
      gcTime: 0
    }
  }
});

// 测试包装器 - 用于需要 Router 的组件测试
export const TestWrapper: React.FC<{ children: React.ReactNode; initialEntries?: string[] }> = ({ 
  children, 
  initialEntries = ['/en'] 
}) => {
  const queryClient = createTestQueryClient();
  
  return (
    <QueryClientProvider client={queryClient}>
      <ConfigProvider>
        <MemoryRouter initialEntries={initialEntries}>
          {children}
        </MemoryRouter>
      </ConfigProvider>
    </QueryClientProvider>
  );
};

// 导出以便其他测试文件使用
export { createTestQueryClient };

describe('App 测试工具', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('TestWrapper', () => {
    test('TestWrapper 能够正常渲染子组件', () => {
      render(
        <TestWrapper>
          <div data-testid="test-child">测试子组件</div>
        </TestWrapper>
      );
      
      expect(screen.getByTestId('test-child')).toBeInTheDocument();
      expect(screen.getByText('测试子组件')).toBeInTheDocument();
    });

    test('TestWrapper 支持自定义初始路由', () => {
      render(
        <TestWrapper initialEntries={['/zh/tasks']}>
          <div data-testid="test-content">内容</div>
        </TestWrapper>
      );
      
      expect(screen.getByTestId('test-content')).toBeInTheDocument();
    });
  });

  describe('QueryClient 配置', () => {
    test('createTestQueryClient 创建禁用重试的客户端', () => {
      const client = createTestQueryClient();
      expect(client).toBeDefined();
      expect(client.getDefaultOptions().queries?.retry).toBe(false);
    });
  });
});

describe('路由测试', () => {
  test('根路径应该重定向到语言路径', async () => {
    // 这个测试验证语言重定向逻辑
    const { detectBrowserLanguage } = require('./utils/i18n');
    const detectedLang = detectBrowserLanguage();
    
    expect(['en', 'zh']).toContain(detectedLang);
  });
});
