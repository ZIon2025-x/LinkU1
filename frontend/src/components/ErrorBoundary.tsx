/**
 * ErrorBoundary 组件
 * 捕获子组件的错误，防止整个应用崩溃
 */
import React, { Component, ErrorInfo, ReactNode } from 'react';
import ErrorFallback from './ErrorFallback';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
    };
  }

  static getDerivedStateFromError(error: Error): State {
    // 更新 state 使下一次渲染能够显示降级后的 UI
    return {
      hasError: true,
      error,
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // 上报错误到监控服务
    console.error('ErrorBoundary 捕获到错误:', error, errorInfo);
    
    // 调用自定义错误处理函数
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }
    
    // 可以在这里发送错误到监控服务
    // if (window.gtag) {
    //   window.gtag('event', 'exception', {
    //     description: error.toString(),
    //     fatal: false,
    //   });
    // }
  }

  render() {
    if (this.state.hasError) {
      // 自定义降级 UI
      if (this.props.fallback) {
        return this.props.fallback;
      }
      
      // 默认错误 UI - 使用统一的错误提示组件
      return <ErrorFallback />;
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
