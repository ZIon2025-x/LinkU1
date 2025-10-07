import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import api from '../api';

const TaskDetailTest: React.FC = () => {
  const { id } = useParams();
  const [task, setTask] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    console.log('TaskDetailTest: 任务ID:', id);
    setLoading(true);
    
    api.get(`/api/tasks/${id}`)
      .then(res => {
        console.log('TaskDetailTest: API响应:', res.data);
        setTask(res.data);
        setError('');
      })
      .catch((error) => {
        console.error('TaskDetailTest: API错误:', error);
        setError('获取任务失败: ' + (error.response?.data?.detail || error.message));
      })
      .finally(() => {
        setLoading(false);
      });
  }, [id]);

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center' }}>
        <h2>加载中...</h2>
        <p>任务ID: {id}</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: 'red' }}>
        <h2>错误</h2>
        <p>{error}</p>
        <p>任务ID: {id}</p>
      </div>
    );
  }

  if (!task) {
    return (
      <div style={{ padding: '40px', textAlign: 'center' }}>
        <h2>任务不存在</h2>
        <p>任务ID: {id}</p>
      </div>
    );
  }

  return (
    <div style={{ padding: '40px', maxWidth: '800px', margin: '0 auto' }}>
      <h1>任务详情测试页面</h1>
      <h2>{task.title}</h2>
      <p><strong>描述:</strong> {task.description}</p>
      <p><strong>奖励:</strong> £{task.reward}</p>
      <p><strong>截止时间:</strong> {task.deadline}</p>
      <p><strong>位置:</strong> {task.location}</p>
      <p><strong>任务类型:</strong> {task.task_type}</p>
      <p><strong>状态:</strong> {task.status}</p>
      <p><strong>发布者ID:</strong> {task.poster_id}</p>
      <p><strong>任务ID:</strong> {task.id}</p>
      
      <h3>完整数据:</h3>
      <pre style={{ background: '#f5f5f5', padding: '10px', overflow: 'auto' }}>
        {JSON.stringify(task, null, 2)}
      </pre>
    </div>
  );
};

export default TaskDetailTest;
