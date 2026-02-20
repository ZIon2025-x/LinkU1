import React from 'react';
import { useNavigate } from 'react-router-dom';
import TaskManagement from '../../../components/TaskManagement';

/**
 * 任务管理页面
 * 包装 TaskManagement 组件，作为独立路由页面使用
 */
const TaskManagementPage: React.FC = () => {
  const navigate = useNavigate();
  return <TaskManagement onClose={() => navigate('/admin')} />;
};

export default TaskManagementPage;
