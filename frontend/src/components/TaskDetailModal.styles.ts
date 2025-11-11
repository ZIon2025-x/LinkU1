/**
 * TaskDetailModal 样式常量
 * P0 优化：提取内联样式为常量，减少对象创建
 */

// 模态框遮罩层样式
export const MODAL_OVERLAY_STYLE: React.CSSProperties = {
  position: 'fixed',
  top: 0,
  left: 0,
  right: 0,
  bottom: 0,
  backgroundColor: 'rgba(0, 0, 0, 0.5)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  zIndex: 1000,
  padding: '20px'
};

// 加载状态容器样式
export const LOADING_CONTAINER_STYLE: React.CSSProperties = {
  backgroundColor: '#fff',
  borderRadius: '16px',
  padding: '40px',
  textAlign: 'center',
  maxWidth: '400px',
  width: '100%'
};

// 错误状态容器样式
export const ERROR_CONTAINER_STYLE: React.CSSProperties = {
  backgroundColor: '#fff',
  borderRadius: '16px',
  padding: '40px',
  textAlign: 'center',
  maxWidth: '400px',
  width: '100%'
};

// 关闭按钮样式
export const CLOSE_BUTTON_STYLE: React.CSSProperties = {
  background: '#3b82f6',
  color: '#fff',
  border: 'none',
  borderRadius: '8px',
  padding: '12px 24px',
  fontSize: '16px',
  cursor: 'pointer'
};

// 主要按钮样式
export const PRIMARY_BUTTON_STYLE: React.CSSProperties = {
  padding: '12px 24px',
  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
  color: '#fff',
  border: 'none',
  borderRadius: '8px',
  fontSize: '14px',
  fontWeight: 600,
  cursor: 'pointer',
  transition: 'all 0.2s ease'
};

// 次要按钮样式
export const SECONDARY_BUTTON_STYLE: React.CSSProperties = {
  padding: '12px 24px',
  background: '#f3f4f6',
  color: '#333',
  border: 'none',
  borderRadius: '8px',
  fontSize: '14px',
  fontWeight: 600,
  cursor: 'pointer',
  transition: 'all 0.2s ease'
};

