import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './styles.css';

// Top-level error boundary — without this, any render-time exception leaves
// a blank page with no in-app indication. We surface the message so users
// (and we) can diagnose. Click "Reset" to clear the bad save and reload.
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error) {
    return { error };
  }
  componentDidCatch(error, info) {
    // eslint-disable-next-line no-console
    console.error('App crashed:', error, info);
  }
  render() {
    if (this.state.error) {
      return (
        <div style={{
          minHeight: '100dvh', padding: 24, color: '#f4ead8',
          fontFamily: 'ui-monospace, monospace', background: '#1a1612',
        }}>
          <h2 style={{ fontSize: 20, marginBottom: 12, color: '#c86060' }}>异乡 · 出错了</h2>
          <pre style={{ whiteSpace: 'pre-wrap', fontSize: 12, opacity: 0.85, marginBottom: 16 }}>
            {String(this.state.error?.stack || this.state.error)}
          </pre>
          <button onClick={() => {
            try { localStorage.removeItem('yixiang.save'); } catch (e) { /* ignore */ }
            window.location.reload();
          }} style={{
            padding: '8px 24px', border: '1px solid #f4ead8', background: 'transparent',
            color: '#f4ead8', cursor: 'pointer', letterSpacing: '0.2em',
          }}>清除存档并重启</button>
        </div>
      );
    }
    return this.props.children;
  }
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </React.StrictMode>,
);
