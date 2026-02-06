/**
 * useDebounce Hook 测试
 */

import { renderHook, act } from '@testing-library/react';
import { useDebounce } from './useDebounce';

describe('useDebounce Hook', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('应该在延迟后调用函数', () => {
    const mockFn = jest.fn();
    const { result } = renderHook(() => useDebounce(mockFn, 300));

    act(() => {
      result.current('arg1');
    });

    // 函数不应该立即被调用
    expect(mockFn).not.toHaveBeenCalled();

    // 前进 300ms
    act(() => {
      jest.advanceTimersByTime(300);
    });

    // 现在应该被调用
    expect(mockFn).toHaveBeenCalledTimes(1);
    expect(mockFn).toHaveBeenCalledWith('arg1');
  });

  test('快速连续调用应该只执行最后一次', () => {
    const mockFn = jest.fn();
    const { result } = renderHook(() => useDebounce(mockFn, 300));

    act(() => {
      result.current('call1');
      result.current('call2');
      result.current('call3');
    });

    // 前进 300ms
    act(() => {
      jest.advanceTimersByTime(300);
    });

    // 只应该执行最后一次调用
    expect(mockFn).toHaveBeenCalledTimes(1);
    expect(mockFn).toHaveBeenCalledWith('call3');
  });

  test('间隔足够长的调用应该都执行', () => {
    const mockFn = jest.fn();
    const { result } = renderHook(() => useDebounce(mockFn, 300));

    act(() => {
      result.current('call1');
    });

    act(() => {
      jest.advanceTimersByTime(300);
    });

    expect(mockFn).toHaveBeenCalledTimes(1);
    expect(mockFn).toHaveBeenCalledWith('call1');

    act(() => {
      result.current('call2');
    });

    act(() => {
      jest.advanceTimersByTime(300);
    });

    expect(mockFn).toHaveBeenCalledTimes(2);
    expect(mockFn).toHaveBeenCalledWith('call2');
  });

  test('默认延迟应该是 300ms', () => {
    const mockFn = jest.fn();
    const { result } = renderHook(() => useDebounce(mockFn));

    act(() => {
      result.current();
    });

    // 250ms 后不应该被调用
    act(() => {
      jest.advanceTimersByTime(250);
    });
    expect(mockFn).not.toHaveBeenCalled();

    // 再过 50ms 应该被调用
    act(() => {
      jest.advanceTimersByTime(50);
    });
    expect(mockFn).toHaveBeenCalledTimes(1);
  });

  test('自定义延迟时间应该生效', () => {
    const mockFn = jest.fn();
    const { result } = renderHook(() => useDebounce(mockFn, 500));

    act(() => {
      result.current();
    });

    // 400ms 后不应该被调用
    act(() => {
      jest.advanceTimersByTime(400);
    });
    expect(mockFn).not.toHaveBeenCalled();

    // 再过 100ms 应该被调用
    act(() => {
      jest.advanceTimersByTime(100);
    });
    expect(mockFn).toHaveBeenCalledTimes(1);
  });
});
