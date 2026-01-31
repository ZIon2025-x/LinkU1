/**
 * 日志工具
 * 在生产环境中自动禁用 console.log，保留 console.error 和 console.warn
 */

const isProduction = process.env.NODE_ENV === 'production';

// 生产环境禁用 console.log 和 console.debug
if (isProduction && typeof window !== 'undefined') {
  // 覆盖 console.log 和 console.debug（原始方法未保存）
  console.log = () => {};
  console.debug = () => {};

  // 可选：在开发工具中显示警告
  if (window.location.search.includes('debug=true')) {
    console.warn('Console.log is disabled in production. Use console.error or console.warn for important messages.');
  }
}

// 导出安全的日志函数
export const logger = {
  log: (...args: any[]) => {
    if (!isProduction) {
      console.log(...args);
    }
  },
  debug: (...args: any[]) => {
    if (!isProduction) {
      console.debug(...args);
    }
  },
  info: (...args: any[]) => {
    if (!isProduction) {
      console.info(...args);
    }
  },
  warn: (...args: any[]) => {
    console.warn(...args);
  },
  error: (...args: any[]) => {
    console.error(...args);
  },
};
