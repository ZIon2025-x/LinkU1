/**
 * ProtectedRoute 组件测试
 */

import { render, screen, waitFor } from '@testing-library/react';
import ProtectedRoute from './ProtectedRoute';

// Mock API
jest.mock('../api', () => ({
  fetchCurrentUser: jest.fn()
}));

// Mock LoginModal
jest.mock('./LoginModal', () => ({
  __esModule: true,
  default: ({ isOpen, onClose }: { isOpen: boolean; onClose: () => void }) => 
    isOpen ? (
      <div data-testid="login-modal">
        登录弹窗
        <button onClick={onClose}>关闭</button>
      </div>
    ) : null
}));

import { fetchCurrentUser } from '../api';

const mockFetchCurrentUser = fetchCurrentUser as jest.MockedFunction<typeof fetchCurrentUser>;

describe('ProtectedRoute 组件', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('加载中显示加载状态', async () => {
    // 让 API 一直 pending
    mockFetchCurrentUser.mockImplementation(() => new Promise(() => {}));

    render(
      <ProtectedRoute>
        <div>受保护的内容</div>
      </ProtectedRoute>
    );

    // 快进初始延迟
    jest.advanceTimersByTime(50);

    expect(screen.getByText('验证登录状态中...')).toBeInTheDocument();
  });

  test('已认证用户可以看到受保护的内容', async () => {
    mockFetchCurrentUser.mockResolvedValue({
      id: '123',
      name: 'Test User',
      email: 'test@example.com'
    });

    render(
      <ProtectedRoute>
        <div data-testid="protected-content">受保护的内容</div>
      </ProtectedRoute>
    );

    // 快进初始延迟
    jest.advanceTimersByTime(50);

    await waitFor(() => {
      expect(screen.getByTestId('protected-content')).toBeInTheDocument();
    });

    expect(screen.getByText('受保护的内容')).toBeInTheDocument();
  });

  test('未认证用户看到登录弹窗', async () => {
    mockFetchCurrentUser.mockRejectedValue({
      response: { status: 401 }
    });

    render(
      <ProtectedRoute>
        <div>受保护的内容</div>
      </ProtectedRoute>
    );

    // 快进初始延迟
    jest.advanceTimersByTime(50);

    await waitFor(() => {
      expect(screen.getByTestId('login-modal')).toBeInTheDocument();
    });

    expect(screen.queryByText('受保护的内容')).not.toBeInTheDocument();
  });

  test('网络错误时显示登录弹窗', async () => {
    mockFetchCurrentUser.mockRejectedValue(new Error('Network Error'));

    render(
      <ProtectedRoute>
        <div>受保护的内容</div>
      </ProtectedRoute>
    );

    // 快进初始延迟
    jest.advanceTimersByTime(50);

    await waitFor(() => {
      expect(screen.getByTestId('login-modal')).toBeInTheDocument();
    });
  });

  test('认证超时时显示登录弹窗', async () => {
    // 模拟一个永不 resolve 的 Promise
    mockFetchCurrentUser.mockImplementation(() => new Promise(() => {}));

    render(
      <ProtectedRoute>
        <div>受保护的内容</div>
      </ProtectedRoute>
    );

    // 快进初始延迟
    jest.advanceTimersByTime(50);

    // 快进超时时间 (10秒)
    jest.advanceTimersByTime(10000);

    await waitFor(() => {
      expect(screen.getByTestId('login-modal')).toBeInTheDocument();
    });
  });
});
