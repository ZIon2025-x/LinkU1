/**
 * Web Vitals 性能监控上报工具
 * 用于生产环境监控 Core Web Vitals 指标
 * 
 * 注意：使用 web-vitals v2.x 的 get* API（兼容旧版本）
 */

import { getCLS, getFCP, getFID, getLCP, getTTFB } from 'web-vitals';

interface WebVitalsMetric {
  name: string;
  value: number;
  id: string;
  delta?: number;
  rating?: 'good' | 'needs-improvement' | 'poor';
  navigationType?: string;
}

/**
 * 上报 Web Vitals 指标到后端
 */
function sendToAnalytics(metric: any) {
  const webVitalsMetric: WebVitalsMetric = {
    name: metric.name,
    value: metric.value,
    id: metric.id,
    delta: metric.delta,
    rating: metric.rating,
    navigationType: metric.navigationType || 'navigate',
  };

  // 使用 sendBeacon 或 fetch 上报（sendBeacon 更可靠，即使页面关闭也会发送）
  if ('sendBeacon' in navigator) {
    const blob = new Blob([JSON.stringify(webVitalsMetric)], {
      type: 'application/json',
    });
    navigator.sendBeacon('/api/analytics/web-vitals', blob);
  } else {
    // 降级到 fetch
    fetch('/api/analytics/web-vitals', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(webVitalsMetric),
      keepalive: true, // 确保请求在页面关闭后也能完成
    }).catch(() => {
      // 静默处理错误，避免影响用户体验
    });
  }

  // 开发环境输出到控制台
  if (process.env.NODE_ENV === 'development') {
      }
}

/**
 * 初始化 Web Vitals 监控
 * 在应用入口调用此函数
 * 
 * 注意：使用 get* API（兼容 web-vitals v2.x）
 * - LCP: Largest Contentful Paint
 * - CLS: Cumulative Layout Shift
 * - FID: First Input Delay（INP 的前身，v2.x 可能不支持 onINP）
 */
export function initWebVitalsMonitoring() {
  // 检查是否支持 PerformanceObserver
  if (typeof window === 'undefined' || !('PerformanceObserver' in window)) {
        return;
  }

  try {
    // 监听 LCP (Largest Contentful Paint) - Core Web Vitals
    getLCP(sendToAnalytics);

    // 监听 CLS (Cumulative Layout Shift) - Core Web Vitals
    getCLS(sendToAnalytics);

    // 监听 FID (First Input Delay) - 旧版 Core Web Vitals，INP 的前身
    // 注意：如果 web-vitals 版本支持 INP，可以尝试动态导入
    getFID(sendToAnalytics);

    // 可选：监听其他指标
    getFCP(sendToAnalytics); // First Contentful Paint
    getTTFB(sendToAnalytics); // Time to First Byte
  } catch (error) {
      }
}

/**
 * 获取当前页面的 Web Vitals 指标（用于调试）
 */
export function getWebVitalsSummary(): Promise<{
  lcp?: number;
  fid?: number;
  cls?: number;
  fcp?: number;
  ttfb?: number;
}> {
  return new Promise((resolve) => {
    const summary: {
      lcp?: number;
      fid?: number;
      cls?: number;
      fcp?: number;
      ttfb?: number;
    } = {};
    let count = 0;
    const expectedCount = 5;

    const checkComplete = () => {
      count++;
      if (count >= expectedCount) {
        resolve(summary);
      }
    };

    getLCP((metric: any) => {
      summary.lcp = metric.value;
      checkComplete();
    });

    getFID((metric: any) => {
      summary.fid = metric.value;
      checkComplete();
    });

    getCLS((metric: any) => {
      summary.cls = metric.value;
      checkComplete();
    });

    getFCP((metric: any) => {
      summary.fcp = metric.value;
      checkComplete();
    });

    getTTFB((metric: any) => {
      summary.ttfb = metric.value;
      checkComplete();
    });

    // 超时保护
    setTimeout(() => {
      resolve(summary);
    }, 5000);
  });
}

