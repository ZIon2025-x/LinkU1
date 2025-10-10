/**
 * 网络诊断工具
 * 用于监控和诊断HTTP/2协议错误
 */

interface NetworkError {
  type: 'HTTP2_PROTOCOL_ERROR' | 'FETCH_ERROR' | 'TIMEOUT' | 'OTHER';
  message: string;
  url: string;
  timestamp: number;
  userAgent: string;
  retryCount: number;
}

class NetworkDiagnostics {
  private errors: NetworkError[] = [];
  private maxErrors = 100;

  // 记录网络错误
  recordError(error: any, url: string, retryCount = 0) {
    const networkError: NetworkError = {
      type: this.categorizeError(error),
      message: error.message || error.toString(),
      url,
      timestamp: Date.now(),
      userAgent: navigator.userAgent,
      retryCount
    };

    this.errors.push(networkError);
    
    // 保持错误列表大小
    if (this.errors.length > this.maxErrors) {
      this.errors.shift();
    }

    console.warn('网络错误已记录:', networkError);
  }

  // 分类错误类型
  private categorizeError(error: any): NetworkError['type'] {
    const message = error.message || error.toString();
    
    if (message.includes('ERR_HTTP2_PROTOCOL_ERROR') || message.includes('HTTP2_PROTOCOL_ERROR')) {
      return 'HTTP2_PROTOCOL_ERROR';
    }
    
    if (message.includes('Failed to fetch')) {
      return 'FETCH_ERROR';
    }
    
    if (message.includes('timeout') || message.includes('TIMEOUT')) {
      return 'TIMEOUT';
    }
    
    return 'OTHER';
  }

  // 获取错误统计
  getErrorStats() {
    const stats = {
      total: this.errors.length,
      http2Errors: this.errors.filter(e => e.type === 'HTTP2_PROTOCOL_ERROR').length,
      fetchErrors: this.errors.filter(e => e.type === 'FETCH_ERROR').length,
      timeoutErrors: this.errors.filter(e => e.type === 'TIMEOUT').length,
      otherErrors: this.errors.filter(e => e.type === 'OTHER').length,
      recentErrors: this.errors.filter(e => Date.now() - e.timestamp < 60000).length // 最近1分钟
    };

    return stats;
  }

  // 获取错误报告
  getErrorReport() {
    const stats = this.getErrorStats();
    const recentErrors = this.errors.filter(e => Date.now() - e.timestamp < 300000); // 最近5分钟

    return {
      summary: stats,
      recentErrors: recentErrors.slice(-10), // 最近10个错误
      recommendations: this.getRecommendations(stats)
    };
  }

  // 获取修复建议
  private getRecommendations(stats: any) {
    const recommendations = [];

    if (stats.http2Errors > 0) {
      recommendations.push({
        type: 'HTTP2_PROTOCOL_ERROR',
        message: '检测到HTTP/2协议错误，建议强制使用HTTP/1.1',
        action: '已自动应用HTTP/1.1修复'
      });
    }

    if (stats.timeoutErrors > 5) {
      recommendations.push({
        type: 'TIMEOUT',
        message: '检测到大量超时错误，建议增加超时时间',
        action: '考虑增加网络超时设置'
      });
    }

    if (stats.recentErrors > 10) {
      recommendations.push({
        type: 'HIGH_ERROR_RATE',
        message: '错误率过高，建议检查网络连接',
        action: '检查网络连接或联系技术支持'
      });
    }

    return recommendations;
  }

  // 清除错误记录
  clearErrors() {
    this.errors = [];
    console.log('网络错误记录已清除');
  }

  // 导出错误数据
  exportErrors() {
    return {
      errors: this.errors,
      stats: this.getErrorStats(),
      report: this.getErrorReport(),
      exportTime: new Date().toISOString()
    };
  }
}

// 全局诊断实例
export const networkDiagnostics = new NetworkDiagnostics();

// 网络错误监控装饰器
export const monitorNetworkError = (fn: Function) => {
  return async (...args: any[]) => {
    try {
      return await fn(...args);
    } catch (error) {
      // 尝试从参数中提取URL
      const url = args[0] || 'unknown';
      networkDiagnostics.recordError(error, url);
      throw error;
    }
  };
};

// 自动错误监控
export const setupNetworkMonitoring = () => {
  if (typeof window !== 'undefined') {
    // 监听未处理的Promise拒绝
    window.addEventListener('unhandledrejection', (event) => {
      const error = event.reason;
      if (error && typeof error === 'object') {
        networkDiagnostics.recordError(error, 'unhandled-promise-rejection');
      }
    });

    // 监听全局错误
    window.addEventListener('error', (event) => {
      if (event.error) {
        networkDiagnostics.recordError(event.error, event.filename || 'unknown');
      }
    });

    console.log('网络监控已启动');
  }
};

// 获取网络状态
export const getNetworkStatus = () => {
  if (typeof navigator !== 'undefined' && 'connection' in navigator) {
    const connection = (navigator as any).connection;
    return {
      effectiveType: connection.effectiveType,
      downlink: connection.downlink,
      rtt: connection.rtt,
      saveData: connection.saveData
    };
  }
  return null;
};
