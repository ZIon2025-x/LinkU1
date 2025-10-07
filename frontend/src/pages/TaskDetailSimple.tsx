import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api, { fetchCurrentUser } from '../api';
import LoginModal from '../components/LoginModal';

const TaskDetailSimple: React.FC = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [task, setTask] = useState<any>(null);
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showLoginModal, setShowLoginModal] = useState(false);
  
  console.log('TaskDetailSimple: 组件渲染，任务ID:', id);
  
  // 检查用户权限
  const canViewTask = (user: any, task: any) => {
    if (!task) return false;
    
    // 如果任务等级是normal，所有用户都可以查看
    if (task.task_level === 'normal') return true;
    
    // 如果没有登录，不能查看VIP任务
    if (!user) return false;
    
    // 检查用户等级
    if (task.task_level === 'vip' && user.user_level !== 'vip' && user.user_level !== 'super') {
      return false;
    }
    
    if (task.task_level === 'super' && user.user_level !== 'super') {
      return false;
    }
    
    return true;
  };
  
  useEffect(() => {
    const loadData = async () => {
      if (!id) {
        setError('没有提供任务ID');
        setLoading(false);
        return;
      }
      
      try {
        // 加载任务数据
        const taskRes = await api.get(`/api/tasks/${id}`);
        setTask(taskRes.data);
        
        // 尝试加载用户数据
        try {
          const userRes = await fetchCurrentUser();
          setUser(userRes);
        } catch (userError) {
          console.log('用户未登录');
          setUser(null);
        }
        
      } catch (error: any) {
        console.error('加载数据失败:', error);
        setError('任务不存在或加载失败');
      } finally {
        setLoading(false);
      }
    };
    
    loadData();
  }, [id]);
  
  if (loading) {
    return (
      <div style={{ 
        padding: '40px', 
        textAlign: 'center',
        minHeight: '100vh',
        background: '#f5f5f5'
      }}>
        <h2>加载中...</h2>
        <p>任务ID: {id}</p>
      </div>
    );
  }
  
  if (error || !task) {
    return (
      <div style={{ 
        padding: '40px', 
        textAlign: 'center',
        minHeight: '100vh',
        background: '#f5f5f5'
      }}>
        <div style={{ 
          maxWidth: '600px', 
          margin: '0 auto', 
          background: '#fff', 
          borderRadius: '16px', 
          padding: '40px',
          boxShadow: '0 4px 24px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: '48px', marginBottom: '20px' }}>❌</div>
          <h2 style={{ color: '#e74c3c', marginBottom: '16px' }}>任务不存在</h2>
          <p style={{ color: '#666', marginBottom: '30px' }}>{error || '该任务可能已被删除或不存在'}</p>
          <button
            onClick={() => navigate('/tasks')}
            style={{
              background: 'linear-gradient(135deg, #3498db, #2980b9)',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              padding: '12px 24px',
              fontSize: '16px',
              cursor: 'pointer'
            }}
          >
            返回任务大厅
          </button>
        </div>
      </div>
    );
  }
  
  // 检查权限
  if (!canViewTask(user, task)) {
    return (
      <div style={{ 
        padding: '40px', 
        textAlign: 'center',
        minHeight: '100vh',
        background: '#f5f5f5'
      }}>
        <div style={{ 
          maxWidth: '600px', 
          margin: '0 auto', 
          background: '#fff', 
          borderRadius: '16px', 
          padding: '40px',
          boxShadow: '0 4px 24px rgba(0,0,0,0.1)'
        }}>
          <div style={{ fontSize: '48px', marginBottom: '20px' }}>🔒</div>
          <h2 style={{ color: '#f39c12', marginBottom: '16px' }}>
            {!user ? '需要登录' : '权限不足'}
          </h2>
          <p style={{ color: '#666', marginBottom: '20px' }}>
            {!user ? '此任务需要登录后才能查看' : `此任务需要${task.task_level === 'vip' ? 'VIP' : '超级VIP'}用户才能查看`}
          </p>
          {user && (
            <p style={{ color: '#999', marginBottom: '30px' }}>
              您的当前等级：{user.user_level === 'normal' ? '普通用户' : user.user_level === 'vip' ? 'VIP用户' : '超级VIP用户'}
            </p>
          )}
          <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
            <button
              onClick={() => navigate('/tasks')}
              style={{
                background: 'linear-gradient(135deg, #95a5a6, #7f8c8d)',
                color: 'white',
                border: 'none',
                borderRadius: '8px',
                padding: '12px 24px',
                fontSize: '16px',
                cursor: 'pointer'
              }}
            >
              返回任务大厅
            </button>
            {!user && (
              <button
                onClick={() => setShowLoginModal(true)}
                style={{
                  background: 'linear-gradient(135deg, #3498db, #2980b9)',
                  color: 'white',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '12px 24px',
                  fontSize: '16px',
                  cursor: 'pointer'
                }}
              >
                立即登录
              </button>
            )}
          </div>
        </div>
        
        <LoginModal
          isOpen={showLoginModal}
          onClose={() => setShowLoginModal(false)}
          onSuccess={() => {
            setShowLoginModal(false);
            // 重新加载用户数据
            fetchCurrentUser().then(setUser).catch(() => setUser(null));
          }}
        />
      </div>
    );
  }
  
  // 有权限查看任务，显示任务详情
  return (
    <div style={{ 
      padding: '40px', 
      textAlign: 'center',
      minHeight: '100vh',
      background: '#f5f5f5'
    }}>
      <div style={{ 
        maxWidth: '800px', 
        margin: '0 auto', 
        background: '#fff', 
        borderRadius: '16px', 
        padding: '40px',
        boxShadow: '0 4px 24px rgba(0,0,0,0.1)'
      }}>
        <h1 style={{ color: '#2c3e50', marginBottom: '20px' }}>任务详情</h1>
        <h2 style={{ color: '#34495e', marginBottom: '16px' }}>{task.title}</h2>
        <p style={{ color: '#666', marginBottom: '20px' }}>{task.description}</p>
        
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', 
          gap: '20px',
          marginTop: '30px'
        }}>
          <div style={{ padding: '15px', background: '#f8f9fa', borderRadius: '8px' }}>
            <strong>奖励:</strong> £{task.reward}
          </div>
          <div style={{ padding: '15px', background: '#f8f9fa', borderRadius: '8px' }}>
            <strong>截止时间:</strong> {new Date(task.deadline).toLocaleDateString()}
          </div>
          <div style={{ padding: '15px', background: '#f8f9fa', borderRadius: '8px' }}>
            <strong>位置:</strong> {task.location}
          </div>
          <div style={{ padding: '15px', background: '#f8f9fa', borderRadius: '8px' }}>
            <strong>任务类型:</strong> {task.task_type}
          </div>
          <div style={{ padding: '15px', background: '#f8f9fa', borderRadius: '8px' }}>
            <strong>状态:</strong> {task.status}
          </div>
          <div style={{ padding: '15px', background: '#f8f9fa', borderRadius: '8px' }}>
            <strong>任务等级:</strong> {task.task_level === 'vip' ? 'VIP任务' : task.task_level === 'super' ? '超级任务' : '普通任务'}
          </div>
        </div>
        
        <div style={{ marginTop: '30px' }}>
          <button
            onClick={() => navigate('/tasks')}
            style={{
              background: 'linear-gradient(135deg, #3498db, #2980b9)',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              padding: '12px 24px',
              fontSize: '16px',
              cursor: 'pointer',
              marginRight: '10px'
            }}
          >
            返回任务大厅
          </button>
          <button
            onClick={() => navigate(`/message?uid=${task.poster_id}`)}
            style={{
              background: 'linear-gradient(135deg, #27ae60, #229954)',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              padding: '12px 24px',
              fontSize: '16px',
              cursor: 'pointer'
            }}
          >
            联系发布者
          </button>
        </div>
      </div>
    </div>
  );
};

export default TaskDetailSimple;
