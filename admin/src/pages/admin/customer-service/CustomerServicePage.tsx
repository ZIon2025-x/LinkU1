import React from 'react';
import { useNavigate } from 'react-router-dom';
import CustomerServiceManagement from './CustomerServiceManagement';

/**
 * 客服管理页面
 * 包装 CustomerServiceManagement 组件，作为独立路由页面使用
 */
const CustomerServicePage: React.FC = () => {
  const navigate = useNavigate();
  return <CustomerServiceManagement onClose={() => navigate('/admin')} />;
};

export default CustomerServicePage;
