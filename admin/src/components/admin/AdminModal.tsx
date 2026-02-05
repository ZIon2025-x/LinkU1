import React, { ReactNode, useEffect } from 'react';
import styles from './AdminModal.module.css';

export interface AdminModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  width?: string | number;
  maxWidth?: string | number;
  maxHeight?: string | number;
  closeOnOverlayClick?: boolean;
  showCloseButton?: boolean;
  className?: string;
}

/**
 * 通用管理后台模态框组件
 * 支持自定义标题、内容、底部按钮等
 */
export const AdminModal: React.FC<AdminModalProps> = ({
  isOpen,
  onClose,
  title,
  children,
  footer,
  width = '600px',
  maxWidth = '90vw',
  maxHeight = '90vh',
  closeOnOverlayClick = true,
  showCloseButton = true,
  className = '',
}) => {
  // 禁止背景滚动
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [isOpen]);

  // ESC键关闭
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const handleOverlayClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget && closeOnOverlayClick) {
      onClose();
    }
  };

  return (
    <div className={styles.overlay} onClick={handleOverlayClick}>
      <div
        className={`${styles.modal} ${className}`}
        style={{
          width,
          maxWidth,
          maxHeight,
        }}
      >
        {/* Header */}
        <div className={styles.header}>
          <h2 className={styles.title}>{title}</h2>
          {showCloseButton && (
            <button
              className={styles.closeButton}
              onClick={onClose}
              aria-label="关闭"
            >
              ×
            </button>
          )}
        </div>

        {/* Content */}
        <div className={styles.content}>{children}</div>

        {/* Footer */}
        {footer && <div className={styles.footer}>{footer}</div>}
      </div>
    </div>
  );
};

export default AdminModal;
