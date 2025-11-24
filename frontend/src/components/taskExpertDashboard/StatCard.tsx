import React from 'react';
import styles from '../../pages/TaskExpertDashboard.module.css';

interface StatCardProps {
  label: string;
  value: number | string;
  subValue?: string;
  gradient: 'Purple' | 'Pink' | 'Blue' | 'Green' | 'Yellow';
}

const StatCard: React.FC<StatCardProps> = React.memo(({ label, value, subValue, gradient }) => {
  return (
    <div className={`${styles.statCard} ${styles[`statCard${gradient}`]}`}>
      <div className={styles.statLabel}>{label}</div>
      <div className={styles.statValue}>{value}</div>
      {subValue && <div className={styles.statSubValue}>{subValue}</div>}
    </div>
  );
});

StatCard.displayName = 'StatCard';

export default StatCard;

