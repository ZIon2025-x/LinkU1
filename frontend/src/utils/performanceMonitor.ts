/**
 * 性能监控工具
 * 监控页面加载时间、API响应时间等性能指标
 */

import React from 'react';

interface PerformanceMetric {
  name: string;
  value: number;
  timestamp: number;
  type: 'page_load' | 'api_call' | 'render' | 'custom';
  metadata?: Record<string, any>;
}

class PerformanceMonitor {
  private metrics: PerformanceMetric[] = [];
  private maxMetrics = 100; // 最多保存100条指标

  /**
   * 记录性能指标
   */
  recordMetric(
    name: string,
    value: number,
    type: PerformanceMetric['type'] = 'custom',
    metadata?: Record<string, any>
  ): void {
    const metric: PerformanceMetric = {
      name,
      value,
      timestamp: Date.now(),
      type,
      metadata,
    };

    this.metrics.push(metric);

    // 限制指标数量
    if (this.metrics.length > this.maxMetrics) {
      this.metrics.shift();
    }

    // 在开发环境输出日志
    if (process.env.NODE_ENV === 'development') {
      console.log(`[Performance] ${name}: ${value.toFixed(2)}ms`, metadata || '');
    }
  }

  /**
   * 测量函数执行时间
   */
  measure<T>(
    name: string,
    fn: () => T | Promise<T>,
    type: PerformanceMetric['type'] = 'custom'
  ): Promise<T> {
    const start = performance.now();
    const result = fn();

    if (result instanceof Promise) {
      return result.then(
        (value) => {
          const duration = performance.now() - start;
          this.recordMetric(name, duration, type);
          return value;
        },
        (error) => {
          const duration = performance.now() - start;
          this.recordMetric(`${name}_error`, duration, type, { error: error.message });
          throw error;
        }
      );
    } else {
      const duration = performance.now() - start;
      this.recordMetric(name, duration, type);
      return Promise.resolve(result);
    }
  }

  /**
   * 测量页面加载时间
   */
  measurePageLoad(pageName: string): void {
    if (typeof window === 'undefined') return;

    window.addEventListener('load', () => {
      const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      if (navigation) {
        const loadTime = navigation.loadEventEnd - navigation.fetchStart;
        this.recordMetric(`page_load_${pageName}`, loadTime, 'page_load', {
          domContentLoaded: navigation.domContentLoadedEventEnd - navigation.fetchStart,
          firstPaint: this.getFirstPaint(),
          firstContentfulPaint: this.getFirstContentfulPaint(),
        });
      }
    });
  }

  /**
   * 测量API调用时间
   */
  measureApiCall(apiName: string, duration: number, success: boolean = true): void {
    this.recordMetric(`api_${apiName}`, duration, 'api_call', {
      success,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * 获取首次绘制时间（First Paint）
   */
  private getFirstPaint(): number | null {
    const paintEntries = performance.getEntriesByType('paint');
    const firstPaint = paintEntries.find((entry) => entry.name === 'first-paint');
    return firstPaint ? firstPaint.startTime : null;
  }

  /**
   * 获取首次内容绘制时间（First Contentful Paint）
   */
  private getFirstContentfulPaint(): number | null {
    const paintEntries = performance.getEntriesByType('paint');
    const fcp = paintEntries.find((entry) => entry.name === 'first-contentful-paint');
    return fcp ? fcp.startTime : null;
  }

  /**
   * 获取所有指标
   */
  getMetrics(): PerformanceMetric[] {
    return [...this.metrics];
  }

  /**
   * 获取指定类型的指标
   */
  getMetricsByType(type: PerformanceMetric['type']): PerformanceMetric[] {
    return this.metrics.filter((m) => m.type === type);
  }

  /**
   * 获取平均性能指标
   */
  getAverageMetric(name: string): number | null {
    const matchingMetrics = this.metrics.filter((m) => m.name === name);
    if (matchingMetrics.length === 0) return null;

    const sum = matchingMetrics.reduce((acc, m) => acc + m.value, 0);
    return sum / matchingMetrics.length;
  }

  /**
   * 清除所有指标
   */
  clear(): void {
    this.metrics = [];
  }

  /**
   * 导出性能报告
   */
  exportReport(): string {
    const report = {
      timestamp: new Date().toISOString(),
      totalMetrics: this.metrics.length,
      metrics: this.metrics,
      averages: this.calculateAverages(),
    };

    return JSON.stringify(report, null, 2);
  }

  /**
   * 计算平均指标
   */
  private calculateAverages(): Record<string, number> {
    const averages: Record<string, number> = {};
    const grouped: Record<string, number[]> = {};

    this.metrics.forEach((metric) => {
      if (!grouped[metric.name]) {
        grouped[metric.name] = [];
      }
      grouped[metric.name].push(metric.value);
    });

    Object.keys(grouped).forEach((name) => {
      const values = grouped[name];
      const sum = values.reduce((acc, val) => acc + val, 0);
      averages[name] = sum / values.length;
    });

    return averages;
  }
}

// 创建单例实例
export const performanceMonitor = new PerformanceMonitor();

/**
 * React Hook: 测量组件渲染时间
 */
export const usePerformanceMeasure = (componentName: string) => {
  React.useEffect(() => {
    const start = performance.now();

    return () => {
      const duration = performance.now() - start;
      performanceMonitor.recordMetric(`render_${componentName}`, duration, 'render');
    };
  }, [componentName]);
};

/**
 * 装饰器：自动测量函数执行时间
 */
export function measurePerformance(name: string, type: PerformanceMetric['type'] = 'custom') {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = function (...args: any[]) {
      return performanceMonitor.measure(
        `${target.constructor.name}.${propertyKey}`,
        () => originalMethod.apply(this, args),
        type
      );
    };

    return descriptor;
  };
}
