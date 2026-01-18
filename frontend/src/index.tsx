import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';
import { autoFixHttp2 } from './utils/http2Fix';
import { setupNetworkMonitoring } from './utils/networkDiagnostics';
import { initWebVitalsMonitoring } from './utils/webVitalsReporter';
// 初始化日志工具（禁用生产环境的 console.log）
import './utils/logger';

// 应用 HTTP/2 修复
autoFixHttp2();

// 设置网络监控
setupNetworkMonitoring();

// 初始化 Web Vitals 监控
initWebVitalsMonitoring();

// 获取根元素
const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('Failed to find the root element');
}

// 使用 createRoot API（React 18+）
const root = ReactDOM.createRoot(rootElement);

// 渲染应用
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// 报告 Web Vitals（性能指标）
reportWebVitals();
