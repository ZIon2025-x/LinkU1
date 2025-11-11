/**
 * ErrorBoundary 组件
 * 捕获子组件的错误，防止整个应用崩溃
 */
import React, { Component, ErrorInfo, ReactNode } from 'react';

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
      
      // 默认错误 UI
      return (
        <div style={{
          padding: '40px',
          textAlign: 'center',
          color: '#ef4444'
        }}>
          <h2 style={{ marginBottom: '16px' }}>出错了</h2>
          <p style={{ marginBottom: '24px', color: '#6b7280' }}>
            {this.state.error?.message || '发生了未知错误'}
          </p>
          <button
            onClick={() => {
              this.setState({ hasError: false, error: null });
              window.location.reload();
            }}
            style={{
              padding: '10px 20px',
              background: '#3b82f6',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            刷新页面
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
