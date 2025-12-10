/**
 * 骨架屏加载组件
 * 提供不同场景的骨架屏，提升用户体验
 */
import React from 'react';
import { Skeleton, Card } from 'antd';

interface SkeletonLoaderProps {
  type?: 'task' | 'post' | 'user' | 'message' | 'notification';
  count?: number;
  className?: string;
}

const SkeletonLoader: React.FC<SkeletonLoaderProps> = ({ 
  type = 'task', 
  count = 3,
  className 
}) => {
  const renderSkeleton = () => {
    switch (type) {
      case 'task':
        return (
          <Card style={{ marginBottom: '16px' }}>
            <Skeleton 
              avatar={{ size: 48 }} 
              paragraph={{ rows: 3 }} 
              active 
            />
          </Card>
        );
      
      case 'post':
        return (
          <Card style={{ marginBottom: '16px' }}>
            <Skeleton 
              title={{ width: '60%' }}
              paragraph={{ rows: 4 }} 
              active 
            />
          </Card>
        );
      
      case 'user':
        return (
          <div style={{ padding: '16px', marginBottom: '16px' }}>
            <Skeleton 
              avatar={{ size: 64, shape: 'circle' }}
              paragraph={{ rows: 2, width: ['60%', '40%'] }}
              active 
            />
          </div>
        );
      
      case 'message':
        return (
          <div style={{ padding: '12px', marginBottom: '8px' }}>
            <Skeleton 
              avatar={{ size: 40 }}
              paragraph={{ rows: 2, width: ['80%', '60%'] }}
              active 
            />
          </div>
        );
      
      case 'notification':
        return (
          <div style={{ padding: '12px', marginBottom: '8px' }}>
            <Skeleton 
              paragraph={{ rows: 2, width: ['100%', '70%'] }}
              active 
            />
          </div>
        );
      
      default:
        return (
          <Card style={{ marginBottom: '16px' }}>
            <Skeleton active />
          </Card>
        );
    }
  };

  return (
    <div className={className}>
      {Array.from({ length: count }).map((_, index) => (
        <React.Fragment key={index}>
          {renderSkeleton()}
        </React.Fragment>
      ))}
    </div>
  );
};

export default SkeletonLoader;

