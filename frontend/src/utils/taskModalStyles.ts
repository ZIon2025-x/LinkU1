// 任务详情弹窗样式常量

export const modalStyles = {
  overlay: {
    position: 'fixed' as const,
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
  },
  modal: {
    backgroundColor: '#fff',
    borderRadius: '24px',
    boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
    maxWidth: '900px',
    width: '100%',
    maxHeight: '90vh',
    position: 'relative' as const,
    display: 'flex',
    flexDirection: 'column' as const,
    overflow: 'hidden' as const
  },
  closeButton: {
    position: 'absolute' as const,
    top: '16px',
    right: '16px',
    background: 'none',
    border: 'none',
    fontSize: '24px',
    cursor: 'pointer',
    color: '#666',
    zIndex: 10,
    width: '32px',
    height: '32px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: '50%',
    transition: 'background-color 0.2s'
  },
  content: {
    padding: '40px',
    overflow: 'auto',
    flex: 1,
    height: 0
  }
};

export const cardStyles = {
  infoCard: {
    background: '#f8fafc',
    padding: '20px',
    borderRadius: '16px',
    border: '2px solid #e2e8f0',
    textAlign: 'center' as const
  },
  onlineCard: {
    background: '#e6f3ff',
    padding: '20px',
    borderRadius: '16px',
    border: '2px solid #93c5fd',
    textAlign: 'center' as const
  },
  descriptionCard: {
    background: '#f8fafc',
    padding: '24px',
    borderRadius: '16px',
    border: '2px solid #e2e8f0',
    marginBottom: '32px',
    position: 'relative' as const,
    zIndex: 1
  },
  detailsCard: {
    background: '#f8fafc',
    padding: '20px',
    borderRadius: '16px',
    border: '2px solid #e2e8f0',
    marginBottom: '32px',
    position: 'relative' as const,
    zIndex: 1
  },
  priceEditCard: {
    background: '#fef3c7',
    padding: '20px',
    borderRadius: '16px',
    border: '2px solid #f59e0b',
    marginBottom: '24px',
    position: 'relative' as const,
    zIndex: 1
  }
};

export const buttonStyles = {
  primary: {
    background: 'linear-gradient(135deg, #10b981, #059669)',
    color: '#fff',
    border: 'none',
    borderRadius: '16px',
    padding: '16px 32px',
    fontWeight: 700,
    fontSize: '16px',
    cursor: 'pointer',
    transition: 'all 0.3s ease',
    boxShadow: '0 8px 24px rgba(16, 185, 129, 0.3)'
  },
  secondary: {
    background: '#6b7280',
    color: '#fff',
    border: 'none',
    borderRadius: '12px',
    padding: '12px 20px',
    fontSize: '14px',
    fontWeight: 600,
    cursor: 'pointer',
    transition: 'all 0.3s ease'
  },
  disabled: {
    background: '#cbd5e1',
    color: '#64748b',
    border: 'none',
    borderRadius: '16px',
    padding: '16px 32px',
    fontWeight: 700,
    fontSize: '16px',
    cursor: 'not-allowed' as const,
    opacity: 0.6
  }
};

export const statusStyles = {
  open: {
    background: '#d1fae5',
    color: '#065f46',
    border: '1px solid #a7f3d0'
  },
  taken: {
    background: '#d1fae5',
    color: '#065f46',
    border: '1px solid #a7f3d0'
  },
  in_progress: {
    background: '#dbeafe',
    color: '#1e40af',
    border: '1px solid #93c5fd'
  },
  completed: {
    background: '#d1fae5',
    color: '#065f46',
    border: '1px solid #a7f3d0'
  },
  cancelled: {
    background: '#fee2e2',
    color: '#991b1b',
    border: '1px solid #fecaca'
  }
};

export const levelStyles = {
  normal: {
    background: '#f8f9fa',
    color: '#6c757d',
    border: '1px solid #dee2e6'
  },
  vip: {
    background: 'linear-gradient(135deg, #FFD700, #FFA500)',
    color: '#8B4513',
    border: '2px solid #FFD700',
    boxShadow: '0 2px 8px rgba(255, 215, 0, 0.3)'
  },
  super: {
    background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
    color: '#fff',
    border: '2px solid #FF4757',
    boxShadow: '0 2px 8px rgba(255, 107, 107, 0.3)'
  }
};

export const applicationStatusStyles = {
  pending: {
    background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
    border: '2px solid #f59e0b',
    color: '#92400e'
  },
  approved: {
    background: 'linear-gradient(135deg, #d1fae5, #a7f3d0)',
    border: '2px solid #10b981',
    color: '#065f46'
  },
  rejected: {
    background: 'linear-gradient(135deg, #fee2e2, #fecaca)',
    border: '2px solid #ef4444',
    color: '#991b1b'
  }
};


