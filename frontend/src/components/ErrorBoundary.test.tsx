/**
 * ErrorBoundary 组件测试
 */

import React from 'react';
import { render, screen } from '@testing-library/react';
import ErrorBoundary from './ErrorBoundary';

// Mock ErrorFallback 组件
jest.mock('./ErrorFallback', () => ({
  __esModule: true,
  default: () => <div data-testid="error-fallback">默认错误页面</div>
}));

// 会抛出错误的组件
const ThrowError: React.FC<{ shouldThrow?: boolean }> = ({ shouldThrow = true }) => {
  if (shouldThrow) {
    throw new Error('测试错误');
  }
  return <div data-testid="child-content">正常内容</div>;
};

describe('ErrorBoundary 组件', () => {
  // 在测试期间禁用 console.error，因为 React 会在控制台打印错误
  let consoleSpy: jest.SpyInstance;

  beforeEach(() => {
    consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  test('正常渲染子组件', () => {
    render(
      <ErrorBoundary>
        <div data-testid="child">子组件内容</div>
      </ErrorBoundary>
    );

    expect(screen.getByTestId('child')).toBeInTheDocument();
    expect(screen.getByText('子组件内容')).toBeInTheDocument();
  });

  test('捕获错误并显示默认错误 UI', () => {
    render(
      <ErrorBoundary>
        <ThrowError />
      </ErrorBoundary>
    );

    expect(screen.getByTestId('error-fallback')).toBeInTheDocument();
    expect(screen.getByText('默认错误页面')).toBeInTheDocument();
  });

  test('使用自定义 fallback UI', () => {
    render(
      <ErrorBoundary fallback={<div data-testid="custom-fallback">自定义错误页面</div>}>
        <ThrowError />
      </ErrorBoundary>
    );

    expect(screen.getByTestId('custom-fallback')).toBeInTheDocument();
    expect(screen.getByText('自定义错误页面')).toBeInTheDocument();
  });

  test('调用 onError 回调', () => {
    const onError = jest.fn();

    render(
      <ErrorBoundary onError={onError}>
        <ThrowError />
      </ErrorBoundary>
    );

    expect(onError).toHaveBeenCalledTimes(1);
    expect(onError).toHaveBeenCalledWith(
      expect.any(Error),
      expect.objectContaining({
        componentStack: expect.any(String)
      })
    );
  });

  test('错误对象包含正确的消息', () => {
    const onError = jest.fn();

    render(
      <ErrorBoundary onError={onError}>
        <ThrowError />
      </ErrorBoundary>
    );

    const [error] = onError.mock.calls[0];
    expect(error.message).toBe('测试错误');
  });

  test('多个子组件，只有出错的会被替换', () => {
    // ErrorBoundary 会替换所有子组件
    // 这是预期行为，因为它是一个边界
    render(
      <ErrorBoundary fallback={<div data-testid="error">出错了</div>}>
        <div>正常组件1</div>
        <ThrowError />
        <div>正常组件2</div>
      </ErrorBoundary>
    );

    expect(screen.getByTestId('error')).toBeInTheDocument();
    expect(screen.queryByText('正常组件1')).not.toBeInTheDocument();
    expect(screen.queryByText('正常组件2')).not.toBeInTheDocument();
  });

  test('嵌套 ErrorBoundary，内层捕获错误', () => {
    render(
      <ErrorBoundary fallback={<div>外层错误</div>}>
        <div data-testid="outer-content">外层内容</div>
        <ErrorBoundary fallback={<div data-testid="inner-error">内层错误</div>}>
          <ThrowError />
        </ErrorBoundary>
      </ErrorBoundary>
    );

    // 外层内容应该正常显示
    expect(screen.getByTestId('outer-content')).toBeInTheDocument();
    // 内层 ErrorBoundary 捕获错误
    expect(screen.getByTestId('inner-error')).toBeInTheDocument();
    expect(screen.queryByText('外层错误')).not.toBeInTheDocument();
  });
});
