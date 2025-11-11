import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';
import { autoFixHttp2 } from './utils/http2Fix';
import { setupNetworkMonitoring } from './utils/networkDiagnostics';

// 自动应用HTTP/2修复
autoFixHttp2();

// 启动网络监控
setupNetworkMonitoring();

// 全局错误处理 - 捕获未处理的错误和 Promise rejection
window.addEventListener('error', (event) => {
  console.error('全局错误捕获:', event.error);
  // 可以在这里发送错误到监控服务
});

window.addEventListener('unhandledrejection', (event) => {
  console.error('未处理的 Promise rejection:', event.reason);
  // 可以在这里发送错误到监控服务
  // 防止默认的错误提示
  event.preventDefault();
});

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

// 添加错误处理，防止渲染失败导致白屏
try {
  root.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );
} catch (error) {
  console.error('应用渲染失败:', error);
  // 显示错误页面 - 使用简单的 HTML，因为此时 React 可能无法正常工作
  // 根据 URL 路径或浏览器语言检测语言
  const path = window.location.pathname;
  const isZh = path.startsWith('/zh') || (!path.startsWith('/en') && navigator.language.startsWith('zh'));
  const errorText = isZh ? '存在加载问题，请再次刷新' : 'There is a loading problem, please refresh again';
  
  const errorDiv = document.createElement('div');
  errorDiv.innerHTML = `
    <div style="
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
      text-align: center;
      background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
    ">
      <div style="
        background: #fff;
        padding: 40px;
        border-radius: 20px;
        box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        max-width: 500px;
      ">
        <div style="
          font-size: 48px;
          margin-bottom: 20px;
          display: flex;
          justify-content: center;
          align-items: center;
        ">
          <span style="
            font-size: 48px;
            display: inline-block;
            animation: spin 2s linear infinite;
          ">🔄</span>
        </div>
        <p style="
          margin-bottom: 0;
          color: #6b7280;
          line-height: 1.6;
          font-size: 16px;
        ">
          ${errorText}
        </p>
      </div>
      <style>
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      </style>
    </div>
  `;
  document.body.appendChild(errorDiv);
}

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
