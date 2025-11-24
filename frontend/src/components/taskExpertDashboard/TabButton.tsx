import React from 'react';
import styles from '../../pages/TaskExpertDashboard.module.css';

interface TabButtonProps {
  label: string;
  isActive: boolean;
  onClick: () => void;
  icon?: string;
}

const TabButton: React.FC<TabButtonProps> = React.memo(({ label, isActive, onClick, icon }) => {
  return (
    <button
      onClick={onClick}
      className={`${styles.tabButton} ${isActive ? styles.tabButtonActive : ''}`}
    >
      {icon && <span style={{ marginRight: icon ? '8px' : '0' }}>{icon}</span>}
      {label}
    </button>
  );
});

TabButton.displayName = 'TabButton';

export default TabButton;

