import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
  getDashboardStats, 
  getUsersForAdmin, 
  updateUserByAdmin,
  createCustomerService,
  deleteCustomerService,
  getCustomerServicesForAdmin,
  createAdminUser,
  deleteAdminUser,
  getAdminUsersForAdmin,
  sendAdminNotification,
  notifyCustomerService,
  sendStaffNotification,
  getTaskExperts,
  createTaskExpert,
  updateTaskExpert,
  deleteTaskExpert
} from '../api';
import NotificationBell, { NotificationBellRef } from '../components/NotificationBell';
import NotificationModal from '../components/NotificationModal';
import TaskManagement from '../components/TaskManagement';
import CustomerServiceManagement from '../components/CustomerServiceManagement';
import SystemSettings from '../components/SystemSettings';
import JobPositionManagement from './JobPositionManagement';
import dayjs from 'dayjs';

interface DashboardStats {
  total_users: number;
  total_tasks: number;
  total_customer_service: number;
  active_sessions: number;
  total_revenue: number;
  avg_rating: number;
}

interface User {
  id: string;  // 现在ID是字符串类型
  name: string;
  email: string;
  user_level: string;
  is_active: number;
  is_banned: number;
  is_suspended: number;
  created_at: string;
  task_count: number;
  avg_rating: number;
}

interface CustomerService {
  id: number;
  name: string;
  email: string;
  is_online: number;
  avg_rating: number;
  total_ratings: number;
  user_id: number;
}

interface AdminUser {
  id: string;
  name: string;
  username: string;
  email: string;
  is_active: number;
  is_super_admin: number;
  created_at: string;
  last_login?: string;
}

const AdminDashboard: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('dashboard');
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [customerServices, setCustomerServices] = useState<CustomerService[]>([]);
  const [adminUsers, setAdminUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [searchTerm, setSearchTerm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [showJobPositionManagement, setShowJobPositionManagement] = useState(false);

  // 表单状态
  const [newCustomerService, setNewCustomerService] = useState({
    name: '',
    email: '',
    password: ''
  });
  const [newAdminUser, setNewAdminUser] = useState({
    name: '',
    username: '',
    email: '',
    password: '',
    is_super_admin: 0
  });
  const [notificationForm, setNotificationForm] = useState({
    title: '',
    content: '',
    user_ids: [] as string[]  // 现在ID是字符串类型
  });

  // 用户管理状态
  const [userActionLoading, setUserActionLoading] = useState<string | null>(null);
  const [showSuspendModal, setShowSuspendModal] = useState(false);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [suspendDuration, setSuspendDuration] = useState(1); // 默认1天
  
  // 提醒相关状态
  const [showNotificationModal, setShowNotificationModal] = useState(false);
  const [showSendNotificationModal, setShowSendNotificationModal] = useState(false);
  const notificationBellRef = useRef<NotificationBellRef>(null);
  const [staffNotificationForm, setStaffNotificationForm] = useState({
    recipientId: '',
    recipientType: '',
    title: '',
    content: ''
  });

  // 任务达人相关状态
  const [taskExperts, setTaskExperts] = useState<any[]>([]);
  const [showTaskExpertModal, setShowTaskExpertModal] = useState(false);
  const [taskExpertForm, setTaskExpertForm] = useState<any>({
    id: undefined,
    name: '',
    avatar: '',
    user_level: 'normal',
    bio: '',
    bio_en: '',
    avg_rating: 0,
    completed_tasks: 0,
    total_tasks: 0,
    completion_rate: 0,
    expertise_areas: [] as string[],
    expertise_areas_en: [] as string[],
    featured_skills: [] as string[],
    featured_skills_en: [] as string[],
    achievements: [] as string[],
    achievements_en: [] as string[],
    response_time: '',
    response_time_en: '',
    success_rate: 0,
    is_verified: 0,
    is_active: 1,
    is_featured: 1,
    display_order: 0,
    category: 'programming'
  });

  // 刷新提醒数量的函数
  const handleNotificationRead = () => {
    if (notificationBellRef.current) {
      notificationBellRef.current.refreshUnreadCount();
    }
  };

  // 任务管理相关状态
  const [showTaskManagement, setShowTaskManagement] = useState(false);
  const [showCustomerServiceManagement, setShowCustomerServiceManagement] = useState(false);
  const [showSystemSettings, setShowSystemSettings] = useState(false);

  const loadDashboardData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      if (activeTab === 'dashboard') {
        const statsData = await getDashboardStats();
        setStats(statsData);
      } else if (activeTab === 'users') {
        const usersData = await getUsersForAdmin(currentPage, 20, searchTerm);
        setUsers(usersData.users || []);
        setTotalPages(Math.ceil((usersData.total || 0) / 20));
      } else if (activeTab === 'personnel') {
        // 加载客服数据
        const csData = await getCustomerServicesForAdmin(currentPage, 20);
        setCustomerServices(csData.customer_services || []);
        
        // 加载管理员数据
        const adminData = await getAdminUsersForAdmin(currentPage, 20);
        setAdminUsers(adminData.admin_users || []);
        
        setTotalPages(Math.ceil((csData.total || 0) / 20));
      } else if (activeTab === 'task-experts') {
        // 加载任务达人数据
        const expertsData = await getTaskExperts({ page: currentPage, size: 20 });
        setTaskExperts(expertsData.task_experts || []);
        setTotalPages(Math.ceil((expertsData.total || 0) / 20));
      }
    } catch (error: any) {
      console.error('加载数据失败:', error);
      let errorMsg = '加载数据失败';
      if (error?.response?.data?.detail) {
        if (typeof error.response.data.detail === 'string') {
          errorMsg = error.response.data.detail;
        } else if (Array.isArray(error.response.data.detail)) {
          errorMsg = error.response.data.detail.map((item: any) => item.msg).join('；');
        } else if (typeof error.response.data.detail === 'object' && error.response.data.detail.msg) {
          errorMsg = error.response.data.detail.msg;
        } else {
          errorMsg = JSON.stringify(error.response.data.detail);
        }
      } else if (error?.message) {
        errorMsg = error.message;
      }
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  }, [activeTab, currentPage, searchTerm]);

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  const handleCreateCustomerService = async () => {
    if (!newCustomerService.name || !newCustomerService.email || !newCustomerService.password) {
      alert('请填写完整信息');
      return;
    }

    try {
      await createCustomerService(newCustomerService);
      alert('客服账号创建成功！');
      setNewCustomerService({ name: '', email: '', password: '' });
      loadDashboardData();
    } catch (error: any) {
      alert(error.response?.data?.detail || '创建失败');
    }
  };

  const handleCreateAdminUser = async () => {
    if (!newAdminUser.name || !newAdminUser.username || !newAdminUser.email || !newAdminUser.password) {
      alert('请填写完整信息');
      return;
    }

    try {
      await createAdminUser(newAdminUser);
      alert('管理员账号创建成功！');
      setNewAdminUser({ name: '', username: '', email: '', password: '', is_super_admin: 0 });
      loadDashboardData();
    } catch (error: any) {
      alert(error.response?.data?.detail || '创建失败');
    }
  };

  const handleDeleteCustomerService = async (csId: number) => {
    if (!window.confirm('确定要删除这个客服账号吗？')) {
      return;
    }

    try {
      await deleteCustomerService(csId);
      alert('客服账号删除成功！');
      loadDashboardData();
    } catch (error: any) {
      alert(error.response?.data?.detail || '删除失败');
    }
  };

  const handleDeleteAdminUser = async (adminId: string) => {
    if (!window.confirm('确定要删除这个管理员账号吗？')) {
      return;
    }

    try {
      await deleteAdminUser(adminId);
      alert('管理员账号删除成功！');
      loadDashboardData();
    } catch (error: any) {
      alert(error.response?.data?.detail || '删除失败');
    }
  };

  const handleSendStaffNotification = async (recipientId: string, recipientType: string, title: string, content: string) => {
    try {
      await sendStaffNotification({
        recipient_id: recipientId,
        recipient_type: recipientType,
        title: title,
        content: content,
        notification_type: 'info'
      });
      alert('提醒发送成功！');
      setShowSendNotificationModal(false);
      setStaffNotificationForm({ recipientId: '', recipientType: '', title: '', content: '' });
    } catch (error: any) {
      alert(error.response?.data?.detail || '发送失败');
    }
  };

  const openSendNotificationModal = (recipientId: string, recipientType: string) => {
    setStaffNotificationForm({
      recipientId: recipientId,
      recipientType: recipientType,
      title: '',
      content: ''
    });
    setShowSendNotificationModal(true);
  };

  const handleUpdateUserLevel = async (userId: string, newLevel: string) => {
    setUserActionLoading(userId);
    try {
      await updateUserByAdmin(userId, { user_level: newLevel });
      alert('用户等级更新成功！');
      loadDashboardData();
    } catch (error: any) {
      alert(error.response?.data?.detail || '更新失败');
    } finally {
      setUserActionLoading(null);
    }
  };

  const handleBanUser = async (userId: string, isBanned: number) => {
    setUserActionLoading(userId);
    try {
      await updateUserByAdmin(userId, { is_banned: isBanned });
      alert(isBanned ? '用户已封禁' : '用户已解封');
      loadDashboardData();
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setUserActionLoading(null);
    }
  };

  const handleSuspendUser = async (userId: string, isSuspended: number, suspendUntil?: string) => {
    setUserActionLoading(userId);
    try {
      const updateData: any = { is_suspended: isSuspended };
      if (isSuspended && suspendUntil) {
        updateData.suspend_until = suspendUntil;
      }
      await updateUserByAdmin(userId, updateData);
      alert(isSuspended ? `用户已暂停${suspendDuration}天` : '用户已恢复');
      loadDashboardData();
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setUserActionLoading(null);
    }
  };

  const handleSuspendClick = (userId: string) => {
    setSelectedUserId(userId);
    setShowSuspendModal(true);
  };

  const handleConfirmSuspend = () => {
    if (!selectedUserId) return;
    
    const suspendUntil = new Date();
    suspendUntil.setDate(suspendUntil.getDate() + suspendDuration);
    
    handleSuspendUser(selectedUserId, 1, suspendUntil.toISOString());
    setShowSuspendModal(false);
    setSelectedUserId(null);
    setSuspendDuration(1);
  };

  const handleSendNotification = async () => {
    if (!notificationForm.title || !notificationForm.content) {
      alert('请填写通知标题和内容');
      return;
    }

    try {
      await sendAdminNotification({
        ...notificationForm,
        user_ids: notificationForm.user_ids.length > 0 ? notificationForm.user_ids : []
      });
      alert('通知发送成功！');
      setNotificationForm({ title: '', content: '', user_ids: [] });
    } catch (error: any) {
      alert(error.response?.data?.detail || '发送失败');
    }
  };

  const handleNotifyCustomerService = async (csId: number, message: string) => {
    try {
      await notifyCustomerService(csId, message);
      alert('提醒发送成功！');
    } catch (error: any) {
      alert(error.response?.data?.detail || '发送失败');
    }
  };

  const renderDashboard = () => (
    <div style={{ marginTop: '20px' }}>
      <h2>数据概览</h2>
      {stats && (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '20px',
          marginTop: '20px'
        }}>
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            textAlign: 'center'
          }}>
            <h3 style={{ margin: '0 0 10px 0', color: '#666', fontSize: '14px' }}>总用户数</h3>
            <p style={{ margin: 0, fontSize: '24px', fontWeight: 'bold', color: '#007bff' }}>{stats.total_users}</p>
          </div>
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            textAlign: 'center'
          }}>
            <h3 style={{ margin: '0 0 10px 0', color: '#666', fontSize: '14px' }}>总任务数</h3>
            <p style={{ margin: 0, fontSize: '24px', fontWeight: 'bold', color: '#007bff' }}>{stats.total_tasks}</p>
          </div>
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            textAlign: 'center'
          }}>
            <h3 style={{ margin: '0 0 10px 0', color: '#666', fontSize: '14px' }}>客服数量</h3>
            <p style={{ margin: 0, fontSize: '24px', fontWeight: 'bold', color: '#007bff' }}>{stats.total_customer_service}</p>
          </div>
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            textAlign: 'center'
          }}>
            <h3 style={{ margin: '0 0 10px 0', color: '#666', fontSize: '14px' }}>活跃会话</h3>
            <p style={{ margin: 0, fontSize: '24px', fontWeight: 'bold', color: '#007bff' }}>{stats.active_sessions}</p>
          </div>
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            textAlign: 'center'
          }}>
            <h3 style={{ margin: '0 0 10px 0', color: '#666', fontSize: '14px' }}>总收入</h3>
            <p style={{ margin: 0, fontSize: '24px', fontWeight: 'bold', color: '#007bff' }}>£{stats.total_revenue.toFixed(2)}</p>
          </div>
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            textAlign: 'center'
          }}>
            <h3 style={{ margin: '0 0 10px 0', color: '#666', fontSize: '14px' }}>平均评分</h3>
            <p style={{ margin: 0, fontSize: '24px', fontWeight: 'bold', color: '#007bff' }}>{stats.avg_rating.toFixed(1)}</p>
          </div>
        </div>
      )}
    </div>
  );

  const renderUsers = () => (
    <div>
      <h2>用户管理</h2>
      <div style={{ marginBottom: '20px' }}>
        <input
          type="text"
          placeholder="搜索用户ID、用户名或邮箱..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          style={{
            width: '300px',
            padding: '8px',
            border: '1px solid #ddd',
            borderRadius: '4px'
          }}
        />
      </div>
      
      {error && (
        <div style={{
          background: '#f8d7da',
          color: '#721c24',
          padding: '10px',
          borderRadius: '4px',
          marginBottom: '20px'
        }}>
          {error}
        </div>
      )}

      <div style={{
        width: '100%',
        borderCollapse: 'collapse',
        background: 'white',
        borderRadius: '8px',
        overflow: 'hidden',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        border: '1px solid #bbdefb'
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          {/* 标签行 */}
          <thead>
            <tr>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>用户ID</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>用户名</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>邮箱地址</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>用户等级</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>账户状态</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>任务数量</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>平均评分</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>注册日期</th>
              <th style={{ padding: '8px 12px', textAlign: 'left', background: '#e3f2fd', fontWeight: 600, fontSize: '12px', color: '#1565c0', borderBottom: '1px solid #bbdefb' }}>管理操作</th>
            </tr>
          </thead>
          {/* 表头行 */}
          <thead>
            <tr>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>用户名</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>邮箱</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>等级</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>状态</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>任务数</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>评分</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>注册时间</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {users && users.length > 0 ? (
              users.map(user => (
                <tr key={user.id}>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{user.id}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{user.name}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{user.email}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    <select
                      value={user.user_level}
                      onChange={(e) => handleUpdateUserLevel(user.id, e.target.value)}
                      disabled={userActionLoading === user.id}
                      style={{
                        width: '100%',
                        padding: '8px',
                        border: '1px solid #ddd',
                        borderRadius: '4px',
                        marginTop: '5px',
                        opacity: userActionLoading === user.id ? 0.6 : 1
                      }}
                    >
                      <option value="normal">普通</option>
                      <option value="vip">VIP</option>
                      <option value="super">超级</option>
                    </select>
                  </td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      fontWeight: 'bold',
                      color: user.is_banned ? '#721c24' : user.is_suspended ? '#856404' : '#155724',
                      background: user.is_banned ? '#f8d7da' : user.is_suspended ? '#fff3cd' : '#d4edda'
                    }}>
                      {user.is_banned ? '已封禁' : 
                       user.is_suspended ? '已暂停' : 
                       user.is_active ? '正常' : '未激活'}
                    </span>
                  </td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{user.task_count}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{user.avg_rating.toFixed(1)}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{dayjs(user.created_at).format('YYYY-MM-DD')}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    <div style={{ display: 'flex', gap: '5px', flexWrap: 'wrap' }}>
                      <button 
                        onClick={() => handleBanUser(user.id, user.is_banned ? 0 : 1)}
                        disabled={userActionLoading === user.id}
                        style={{
                          padding: '6px 12px',
                          border: 'none',
                          borderRadius: '4px',
                          background: user.is_banned ? '#28a745' : '#dc3545',
                          color: 'white',
                          cursor: userActionLoading === user.id ? 'not-allowed' : 'pointer',
                          fontSize: '12px',
                          opacity: userActionLoading === user.id ? 0.6 : 1
                        }}
                      >
                        {user.is_banned ? '解封' : '封禁'}
                      </button>
                      <button 
                        onClick={() => user.is_suspended ? handleSuspendUser(user.id, 0) : handleSuspendClick(user.id)}
                        disabled={userActionLoading === user.id}
                        style={{
                          padding: '6px 12px',
                          border: 'none',
                          borderRadius: '4px',
                          background: user.is_suspended ? '#28a745' : '#ffc107',
                          color: user.is_suspended ? 'white' : 'black',
                          cursor: userActionLoading === user.id ? 'not-allowed' : 'pointer',
                          fontSize: '12px',
                          opacity: userActionLoading === user.id ? 0.6 : 1
                        }}
                      >
                        {user.is_suspended ? '恢复' : '暂停'}
                      </button>
                      <button 
                        onClick={() => handleUpdateUserLevel(user.id, 'normal')}
                        disabled={userActionLoading === user.id}
                        style={{
                          padding: '6px 12px',
                          border: 'none',
                          borderRadius: '4px',
                          background: '#007bff',
                          color: 'white',
                          cursor: userActionLoading === user.id ? 'not-allowed' : 'pointer',
                          fontSize: '12px',
                          opacity: userActionLoading === user.id ? 0.6 : 1
                        }}
                      >
                        重置等级
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={9} style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                  {loading ? '加载中...' : '暂无用户数据'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      
      {users && users.length > 0 && (
        <div style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          gap: '10px',
          marginTop: '20px'
        }}>
          <button 
            disabled={currentPage === 1 || loading} 
            onClick={() => setCurrentPage(currentPage - 1)}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: currentPage === 1 || loading ? '#ccc' : '#007bff',
              color: 'white',
              borderRadius: '4px',
              cursor: currentPage === 1 || loading ? 'not-allowed' : 'pointer'
            }}
          >
            上一页
          </button>
          <span>第 {currentPage} 页，共 {totalPages} 页</span>
          <button 
            disabled={currentPage === totalPages || loading} 
            onClick={() => setCurrentPage(currentPage + 1)}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: currentPage === totalPages || loading ? '#ccc' : '#007bff',
              color: 'white',
              borderRadius: '4px',
              cursor: currentPage === totalPages || loading ? 'not-allowed' : 'pointer'
            }}
          >
            下一页
          </button>
        </div>
      )}
    </div>
  );

  const renderPersonnelManagement = () => (
    <div>
      <h2>人员管理</h2>
      
      {/* 管理员管理 */}
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <h3 style={{ color: '#dc3545', marginBottom: '15px' }}>管理员管理</h3>
        
        {/* 创建新管理员 */}
        <div style={{ marginBottom: '20px' }}>
          <h4>创建新管理员</h4>
          <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
            <input
              type="text"
              placeholder="管理员姓名"
              value={newAdminUser.name}
              onChange={(e) => setNewAdminUser({...newAdminUser, name: e.target.value})}
              style={{
                flex: 1,
                minWidth: '120px',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
            <input
              type="text"
              placeholder="登录用户名"
              value={newAdminUser.username}
              onChange={(e) => setNewAdminUser({...newAdminUser, username: e.target.value})}
              style={{
                flex: 1,
                minWidth: '120px',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
            <input
              type="email"
              placeholder="邮箱"
              value={newAdminUser.email}
              onChange={(e) => setNewAdminUser({...newAdminUser, email: e.target.value})}
              style={{
                flex: 1,
                minWidth: '180px',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
            <input
              type="password"
              placeholder="密码"
              value={newAdminUser.password}
              onChange={(e) => setNewAdminUser({...newAdminUser, password: e.target.value})}
              style={{
                flex: 1,
                minWidth: '120px',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
            <select
              value={newAdminUser.is_super_admin}
              onChange={(e) => setNewAdminUser({...newAdminUser, is_super_admin: parseInt(e.target.value)})}
              style={{
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            >
              <option value={0}>普通管理员</option>
              <option value={1}>超级管理员</option>
            </select>
            <button
              onClick={handleCreateAdminUser}
              disabled={loading}
              style={{
                padding: '8px 16px',
                border: 'none',
                background: loading ? '#ccc' : '#dc3545',
                color: 'white',
                borderRadius: '4px',
                cursor: loading ? 'not-allowed' : 'pointer',
                opacity: loading ? 0.6 : 1
              }}
            >
              {loading ? '创建中...' : '创建管理员'}
            </button>
          </div>
        </div>

        {/* 管理员列表 */}
        <div>
          <h4>管理员列表</h4>
          <table style={{ 
            width: '100%', 
            borderCollapse: 'collapse', 
            background: 'white', 
            borderRadius: '8px', 
            overflow: 'hidden', 
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)' 
          }}>
            <thead>
              <tr>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>姓名</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>用户名</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>邮箱</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>类型</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>创建时间</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {adminUsers && adminUsers.length > 0 ? (
                adminUsers.map(admin => (
                  <tr key={admin.id}>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{admin.id}</td>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{admin.name}</td>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{admin.username}</td>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{admin.email}</td>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        fontSize: '12px',
                        fontWeight: 'bold',
                        color: admin.is_super_admin ? '#721c24' : '#155724',
                        background: admin.is_super_admin ? '#f8d7da' : '#d4edda'
                      }}>
                        {admin.is_super_admin ? '超级管理员' : '普通管理员'}
                      </span>
                    </td>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        fontSize: '12px',
                        fontWeight: 'bold',
                        color: admin.is_active ? '#155724' : '#721c24',
                        background: admin.is_active ? '#d4edda' : '#f8d7da'
                      }}>
                        {admin.is_active ? '激活' : '禁用'}
                      </span>
                    </td>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                      {dayjs(admin.created_at).format('YYYY-MM-DD HH:mm')}
                    </td>
                    <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                      <div style={{ display: 'flex', gap: '5px', flexWrap: 'wrap' }}>
                        <button
                          onClick={() => openSendNotificationModal(admin.id, 'admin')}
                          disabled={loading}
                          style={{
                            padding: '6px 12px',
                            border: 'none',
                            borderRadius: '4px',
                            background: '#28a745',
                            color: 'white',
                            cursor: loading ? 'not-allowed' : 'pointer',
                            fontSize: '12px',
                            opacity: loading ? 0.6 : 1
                          }}
                        >
                          发送提醒
                        </button>
                        <button
                          onClick={() => handleDeleteAdminUser(admin.id)}
                          disabled={loading}
                          style={{
                            padding: '6px 12px',
                            border: 'none',
                            borderRadius: '4px',
                            background: '#dc3545',
                            color: 'white',
                            cursor: loading ? 'not-allowed' : 'pointer',
                            fontSize: '12px',
                            opacity: loading ? 0.6 : 1
                          }}
                        >
                          删除
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={8} style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                    {loading ? '加载中...' : '暂无管理员数据'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* 客服管理 */}
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <h3 style={{ color: '#007bff', marginBottom: '15px' }}>客服管理</h3>
        
        {/* 创建新客服 */}
        <div style={{ marginBottom: '20px' }}>
          <h4>创建新客服</h4>
          <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
            <input
              type="text"
              placeholder="客服姓名"
              value={newCustomerService.name}
              onChange={(e) => setNewCustomerService({...newCustomerService, name: e.target.value})}
              style={{
                flex: 1,
                minWidth: '120px',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
            <input
              type="email"
              placeholder="邮箱"
              value={newCustomerService.email}
              onChange={(e) => setNewCustomerService({...newCustomerService, email: e.target.value})}
              style={{
                flex: 1,
                minWidth: '180px',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
            <input
              type="password"
              placeholder="密码"
              value={newCustomerService.password}
              onChange={(e) => setNewCustomerService({...newCustomerService, password: e.target.value})}
              style={{
                flex: 1,
                minWidth: '120px',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
            <button
              onClick={handleCreateCustomerService}
              disabled={loading}
              style={{
                padding: '8px 16px',
                border: 'none',
                background: loading ? '#ccc' : '#007bff',
                color: 'white',
                borderRadius: '4px',
                cursor: loading ? 'not-allowed' : 'pointer',
                opacity: loading ? 0.6 : 1
              }}
            >
              {loading ? '创建中...' : '创建客服'}
            </button>
          </div>
        </div>

      {/* 客服列表 */}
      <div>
        <table style={{ 
          width: '100%', 
          borderCollapse: 'collapse', 
          background: 'white', 
          borderRadius: '8px', 
          overflow: 'hidden', 
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)' 
        }}>
          <thead>
            <tr>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>姓名</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>邮箱</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>在线状态</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>平均评分</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>评分数量</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {customerServices && customerServices.length > 0 ? (
              customerServices.map(cs => (
                <tr key={cs.id}>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{cs.id}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{cs.name}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{cs.email}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      fontWeight: 'bold',
                      color: cs.is_online ? '#155724' : '#721c24',
                      background: cs.is_online ? '#d4edda' : '#f8d7da'
                    }}>
                      {cs.is_online ? '在线' : '离线'}
                    </span>
                  </td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    <span style={{ color: cs.avg_rating >= 4 ? '#28a745' : cs.avg_rating >= 3 ? '#ffc107' : '#dc3545' }}>
                      {cs.avg_rating.toFixed(1)}
                    </span>
                  </td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>{cs.total_ratings}</td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    <div style={{ display: 'flex', gap: '5px', flexWrap: 'wrap' }}>
                      <button
                        onClick={() => openSendNotificationModal(cs.id.toString(), 'customer_service')}
                        disabled={loading}
                        style={{
                          padding: '6px 12px',
                          border: 'none',
                          borderRadius: '4px',
                          background: '#28a745',
                          color: 'white',
                          cursor: loading ? 'not-allowed' : 'pointer',
                          fontSize: '12px',
                          opacity: loading ? 0.6 : 1
                        }}
                      >
                        发送提醒
                      </button>
                      <button
                        onClick={() => handleDeleteCustomerService(cs.id)}
                        disabled={loading}
                        style={{
                          padding: '6px 12px',
                          border: 'none',
                          borderRadius: '4px',
                          background: '#dc3545',
                          color: 'white',
                          cursor: loading ? 'not-allowed' : 'pointer',
                          fontSize: '12px',
                          opacity: loading ? 0.6 : 1
                        }}
                      >
                        删除
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={7} style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                  {loading ? '加载中...' : '暂无客服数据'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      </div>
    </div>
  );

  const renderTaskExperts = () => (
    <div>
      <h2>任务达人管理</h2>
      <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <button
          onClick={() => {
            setTaskExpertForm({
              id: undefined,
              name: '',
              avatar: '',
              user_level: 'normal',
              bio: '',
              bio_en: '',
              avg_rating: 0,
              completed_tasks: 0,
              total_tasks: 0,
              completion_rate: 0,
              expertise_areas: [],
              expertise_areas_en: [],
              featured_skills: [],
              featured_skills_en: [],
              achievements: [],
              achievements_en: [],
              response_time: '',
              response_time_en: '',
              success_rate: 0,
              is_verified: 0,
              is_active: 1,
              is_featured: 1,
              display_order: 0,
              category: 'programming'
            });
            setShowTaskExpertModal(true);
          }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#28a745',
            color: 'white',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px'
          }}
        >
          + 添加任务达人
        </button>
      </div>

      <div style={{ background: 'white', borderRadius: '8px', overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa', borderBottom: '2px solid #dee2e6' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>名称</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>类别</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>等级</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>评分</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>状态</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {taskExperts.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                  暂无任务达人，点击"添加任务达人"按钮创建
                </td>
              </tr>
            ) : (
              taskExperts.map((expert) => (
                <tr key={expert.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{expert.id}</td>
                  <td style={{ padding: '12px' }}>{expert.name}</td>
                  <td style={{ padding: '12px' }}>{expert.category || '-'}</td>
                  <td style={{ padding: '12px' }}>{expert.user_level}</td>
                  <td style={{ padding: '12px' }}>{expert.avg_rating?.toFixed(1) || '0.0'}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      background: expert.is_active ? '#d4edda' : '#f8d7da',
                      color: expert.is_active ? '#155724' : '#721c24'
                    }}>
                      {expert.is_active ? '已启用' : '已禁用'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <button
                      onClick={() => {
                        setTaskExpertForm(expert);
                        setShowTaskExpertModal(true);
                      }}
                      style={{
                        padding: '4px 8px',
                        marginRight: '4px',
                        border: '1px solid #007bff',
                        background: 'white',
                        color: '#007bff',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '12px'
                      }}
                    >
                      编辑
                    </button>
                    <button
                      onClick={async () => {
                        if (window.confirm('确定要删除这个任务达人吗？')) {
                          try {
                            await deleteTaskExpert(expert.id);
                            await loadDashboardData();
                          } catch (error) {
                            console.error('删除失败:', error);
                          }
                        }
                      }}
                      style={{
                        padding: '4px 8px',
                        border: '1px solid #dc3545',
                        background: 'white',
                        color: '#dc3545',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '12px'
                      }}
                    >
                      删除
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {showTaskExpertModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          zIndex: 1000
        }}>
          <div style={{
            background: 'white',
            padding: '30px',
            borderRadius: '8px',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)',
            maxWidth: '1200px',
            width: '95%',
            maxHeight: '90vh',
            overflow: 'auto'
          }}>
            <h3 style={{ margin: '0 0 20px 0' }}>任务达人表单</h3>
            
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>名称 *</label>
              <input
                type="text"
                value={taskExpertForm.name}
                onChange={(e) => setTaskExpertForm({...taskExpertForm, name: e.target.value})}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px'
                }}
              />
            </div>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>头像URL</label>
              <input
                type="text"
                value={taskExpertForm.avatar}
                onChange={(e) => setTaskExpertForm({...taskExpertForm, avatar: e.target.value})}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px'
                }}
              />
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>等级 *</label>
                <select
                  value={taskExpertForm.user_level}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, user_level: e.target.value})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                >
                  <option value="normal">普通</option>
                  <option value="vip">VIP</option>
                  <option value="super">超级</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>类别</label>
                <select
                  value={taskExpertForm.category}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, category: e.target.value})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                >
                  <option value="programming">编程开发</option>
                  <option value="design">设计创意</option>
                  <option value="marketing">营销推广</option>
                  <option value="writing">文案写作</option>
                  <option value="translation">翻译服务</option>
                </select>
              </div>
            </div>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>简介（中文）</label>
              <textarea
                value={taskExpertForm.bio}
                onChange={(e) => setTaskExpertForm({...taskExpertForm, bio: e.target.value})}
                rows={3}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  resize: 'vertical'
                }}
                placeholder="请输入任务达人简介（中文）"
              />
            </div>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>简介（英文）</label>
              <textarea
                value={taskExpertForm.bio_en}
                onChange={(e) => setTaskExpertForm({...taskExpertForm, bio_en: e.target.value})}
                rows={3}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  resize: 'vertical'
                }}
                placeholder="Task Expert Bio (English)"
              />
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>响应时间（中文）</label>
                <input
                  type="text"
                  value={taskExpertForm.response_time}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, response_time: e.target.value})}
                  placeholder="如：2小时内"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>响应时间（英文）</label>
                <input
                  type="text"
                  value={taskExpertForm.response_time_en}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, response_time_en: e.target.value})}
                  placeholder="e.g. Within 2 hours"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>平均评分</label>
                <input
                  type="number"
                  step="0.1"
                  min="0"
                  max="5"
                  value={taskExpertForm.avg_rating}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, avg_rating: parseFloat(e.target.value) || 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>成功率 (%)</label>
                <input
                  type="number"
                  step="0.1"
                  min="0"
                  max="100"
                  value={taskExpertForm.success_rate}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, success_rate: parseFloat(e.target.value) || 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>已完成任务数</label>
                <input
                  type="number"
                  min="0"
                  value={taskExpertForm.completed_tasks}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, completed_tasks: parseInt(e.target.value) || 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>总任务数</label>
                <input
                  type="number"
                  min="0"
                  value={taskExpertForm.total_tasks}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, total_tasks: parseInt(e.target.value) || 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>完成率 (%)</label>
                <input
                  type="number"
                  step="0.1"
                  min="0"
                  max="100"
                  value={taskExpertForm.completion_rate}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, completion_rate: parseFloat(e.target.value) || 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>专业领域（中文，用逗号分隔）</label>
                <input
                  type="text"
                  value={Array.isArray(taskExpertForm.expertise_areas) ? taskExpertForm.expertise_areas.join(', ') : taskExpertForm.expertise_areas}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, expertise_areas: e.target.value.split(',').map(s => s.trim())})}
                  placeholder="如：编程开发, 网站建设, 移动应用"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>专业领域（英文，用逗号分隔）</label>
                <input
                  type="text"
                  value={Array.isArray(taskExpertForm.expertise_areas_en) ? taskExpertForm.expertise_areas_en.join(', ') : taskExpertForm.expertise_areas_en}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, expertise_areas_en: e.target.value.split(',').map(s => s.trim())})}
                  placeholder="e.g. Programming, Web Development, Mobile Apps"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>特色技能（中文，用逗号分隔）</label>
                <input
                  type="text"
                  value={Array.isArray(taskExpertForm.featured_skills) ? taskExpertForm.featured_skills.join(', ') : taskExpertForm.featured_skills}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, featured_skills: e.target.value.split(',').map(s => s.trim())})}
                  placeholder="如：React, Node.js, Python, Vue.js"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>特色技能（英文，用逗号分隔）</label>
                <input
                  type="text"
                  value={Array.isArray(taskExpertForm.featured_skills_en) ? taskExpertForm.featured_skills_en.join(', ') : taskExpertForm.featured_skills_en}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, featured_skills_en: e.target.value.split(',').map(s => s.trim())})}
                  placeholder="e.g. React, Node.js, Python, Vue.js"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>成就徽章（中文，用逗号分隔）</label>
                <input
                  type="text"
                  value={Array.isArray(taskExpertForm.achievements) ? taskExpertForm.achievements.join(', ') : taskExpertForm.achievements}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, achievements: e.target.value.split(',').map(s => s.trim())})}
                  placeholder="如：技术认证, 优秀贡献者, 年度达人"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>成就徽章（英文，用逗号分隔）</label>
                <input
                  type="text"
                  value={Array.isArray(taskExpertForm.achievements_en) ? taskExpertForm.achievements_en.join(', ') : taskExpertForm.achievements_en}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, achievements_en: e.target.value.split(',').map(s => s.trim())})}
                  placeholder="e.g. Technical Certification, Top Contributor, Expert of the Year"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>显示顺序</label>
                <input
                  type="number"
                  min="0"
                  value={taskExpertForm.display_order}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, display_order: parseInt(e.target.value) || 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>状态</label>
                <select
                  value={taskExpertForm.is_active}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, is_active: e.target.value === '1' ? 1 : 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                >
                  <option value="1">已启用</option>
                  <option value="0">已禁用</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>是否精选</label>
                <select
                  value={taskExpertForm.is_featured}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, is_featured: e.target.value === '1' ? 1 : 0})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                >
                  <option value="1">是</option>
                  <option value="0">否</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '10px' }}>
              <button
                onClick={async () => {
                  try {
                    if (taskExpertForm.name) {
                      if (taskExpertForm.id) {
                        await updateTaskExpert(taskExpertForm.id, taskExpertForm);
                      } else {
                        await createTaskExpert(taskExpertForm);
                      }
                      setShowTaskExpertModal(false);
                      await loadDashboardData();
                    }
                  } catch (error) {
                    console.error('保存失败:', error);
                  }
                }}
                disabled={!taskExpertForm.name}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: !taskExpertForm.name ? '#ccc' : '#007bff',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: !taskExpertForm.name ? 'not-allowed' : 'pointer',
                  opacity: !taskExpertForm.name ? 0.6 : 1
                }}
              >
                保存
              </button>
              <button
                onClick={() => setShowTaskExpertModal(false)}
                style={{
                  padding: '10px 20px',
                  border: '1px solid #ddd',
                  background: 'white',
                  color: '#666',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );

  const renderNotifications = () => (
    <div>
      <h2>发送通知</h2>
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <div style={{ marginBottom: '15px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>通知标题：</label>
          <input
            type="text"
            placeholder="请输入通知标题"
            value={notificationForm.title}
            onChange={(e) => setNotificationForm({...notificationForm, title: e.target.value})}
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              marginTop: '5px'
            }}
          />
        </div>
        <div style={{ marginBottom: '15px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>通知内容：</label>
          <textarea
            placeholder="请输入通知内容"
            value={notificationForm.content}
            onChange={(e) => setNotificationForm({...notificationForm, content: e.target.value})}
            rows={4}
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              marginTop: '5px',
              resize: 'vertical'
            }}
          />
        </div>
        <div style={{ marginBottom: '15px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>目标用户ID（留空发送给所有用户）：</label>
          <input
            type="text"
            placeholder="用逗号分隔多个用户ID，如：1,2,3"
            onChange={(e) => {
              const ids = e.target.value.split(',').map(id => id.trim()).filter(id => id.length > 0);
              setNotificationForm({...notificationForm, user_ids: ids});
            }}
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              marginTop: '5px'
            }}
          />
          <small style={{ color: '#666', fontSize: '12px', marginTop: '5px', display: 'block' }}>
            提示：留空用户ID将发送给所有用户，填写用户ID将只发送给指定用户
          </small>
        </div>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
          <button
            onClick={handleSendNotification}
            disabled={loading || !notificationForm.title || !notificationForm.content}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: loading || !notificationForm.title || !notificationForm.content ? '#ccc' : '#007bff',
              color: 'white',
              borderRadius: '4px',
              cursor: loading || !notificationForm.title || !notificationForm.content ? 'not-allowed' : 'pointer',
              opacity: loading || !notificationForm.title || !notificationForm.content ? 0.6 : 1
            }}
          >
            {loading ? '发送中...' : '发送通知'}
          </button>
          <button
            onClick={() => setNotificationForm({ title: '', content: '', user_ids: [] })}
            style={{
              padding: '10px 20px',
              border: '1px solid #ddd',
              background: 'white',
              color: '#666',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            清空表单
          </button>
        </div>
      </div>
      
      <div style={{
        background: '#f8f9fa',
        padding: '15px',
        borderRadius: '8px',
        border: '1px solid #e9ecef'
      }}>
        <h4 style={{ margin: '0 0 10px 0', color: '#495057' }}>通知发送说明：</h4>
        <ul style={{ margin: 0, paddingLeft: '20px', color: '#666' }}>
          <li>通知标题和内容为必填项</li>
          <li>用户ID留空时，通知将发送给所有用户</li>
          <li>填写用户ID时，通知只发送给指定用户</li>
          <li>多个用户ID用逗号分隔，如：1,2,3</li>
          <li>发送后用户将在通知中心收到此消息</li>
        </ul>
      </div>
    </div>
  );

  return (
    <div style={{ padding: '20px', maxWidth: '1200px', margin: '0 auto' }}>
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: '20px',
        paddingBottom: '10px',
        borderBottom: '1px solid #eee'
      }}>
        <h1 style={{ 
          position: 'absolute',
          top: '-100px',
          left: '-100px',
          width: '1px',
          height: '1px',
          padding: '0',
          margin: '0',
          overflow: 'hidden',
          clip: 'rect(0, 0, 0, 0)',
          whiteSpace: 'nowrap',
          border: '0',
          fontSize: '1px',
          color: 'transparent',
          background: 'transparent'
        }}>管理后台</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          {/* 提醒按钮 */}
          <NotificationBell 
            ref={notificationBellRef}
            userType="admin" 
            onOpenModal={() => setShowNotificationModal(true)}
          />
          <button 
            onClick={() => navigate('/')}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: '#007bff',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            返回首页
          </button>
        </div>
      </div>

      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px', flexWrap: 'wrap' }}>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'dashboard' ? '#007bff' : '#f0f0f0',
            color: activeTab === 'dashboard' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
          onClick={() => setActiveTab('dashboard')}
        >
          数据概览
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'users' ? '#007bff' : '#f0f0f0',
            color: activeTab === 'users' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
          onClick={() => setActiveTab('users')}
        >
          用户管理
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'personnel' ? '#007bff' : '#f0f0f0',
            color: activeTab === 'personnel' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
          onClick={() => setActiveTab('personnel')}
        >
          人员管理
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#28a745',
            color: 'white',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500',
            marginRight: '10px'
          }}
          onClick={() => setShowTaskManagement(true)}
        >
          任务管理
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#17a2b8',
            color: 'white',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500',
            marginRight: '10px'
          }}
          onClick={() => setShowCustomerServiceManagement(true)}
        >
          客服管理
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#6f42c1',
            color: 'white',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500',
            marginRight: '10px'
          }}
          onClick={() => setShowSystemSettings(true)}
        >
          系统设置
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#ff6b35',
            color: 'white',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500',
            marginRight: '10px'
          }}
          onClick={() => setShowJobPositionManagement(true)}
        >
          岗位管理
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'task-experts' ? '#007bff' : '#f0f0f0',
            color: activeTab === 'task-experts' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500',
            marginRight: '10px'
          }}
          onClick={() => setActiveTab('task-experts')}
        >
          任务达人
        </button>
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'notifications' ? '#007bff' : '#f0f0f0',
            color: activeTab === 'notifications' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
          onClick={() => setActiveTab('notifications')}
        >
          发送通知
        </button>
      </div>

      <div>
        {loading && (
          <div style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            padding: '40px',
            background: 'white',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            marginBottom: '20px'
          }}>
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '10px'
            }}>
              <div style={{
                width: '40px',
                height: '40px',
                border: '4px solid #f3f3f3',
                borderTop: '4px solid #007bff',
                borderRadius: '50%',
                animation: 'spin 1s linear infinite'
              }}></div>
              <span style={{ color: '#666', fontSize: '16px' }}>加载中...</span>
            </div>
          </div>
        )}

        {error && (
          <div style={{
            background: '#f8d7da',
            color: '#721c24',
            padding: '15px',
            borderRadius: '8px',
            marginBottom: '20px',
            border: '1px solid #f5c6cb'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <span style={{ fontSize: '18px' }}>⚠️</span>
              <span>{error}</span>
            </div>
            <button
              onClick={() => setError(null)}
              style={{
                marginTop: '10px',
                padding: '5px 10px',
                border: 'none',
                background: '#721c24',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '12px'
              }}
            >
              关闭
            </button>
          </div>
        )}

        {!loading && !error && (
          <>
            {activeTab === 'dashboard' && renderDashboard()}
            {activeTab === 'users' && renderUsers()}
            {activeTab === 'personnel' && renderPersonnelManagement()}
            {activeTab === 'task-experts' && renderTaskExperts()}
            {activeTab === 'notifications' && renderNotifications()}
          </>
        )}
      </div>

      {/* 暂停时间选择模态框 */}
      {showSuspendModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          zIndex: 1000
        }}>
          <div style={{
            background: 'white',
            padding: '30px',
            borderRadius: '8px',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)',
            minWidth: '400px',
            maxWidth: '500px'
          }}>
            <h3 style={{ margin: '0 0 20px 0', color: '#333', textAlign: 'center' }}>选择暂停时间</h3>
            
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#555' }}>
                暂停天数：
              </label>
              <select
                value={suspendDuration}
                onChange={(e) => setSuspendDuration(Number(e.target.value))}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '16px'
                }}
              >
                <option value={1}>1天</option>
                <option value={3}>3天</option>
                <option value={7}>7天</option>
                <option value={15}>15天</option>
                <option value={30}>30天</option>
                <option value={90}>90天</option>
                <option value={365}>1年</option>
              </select>
            </div>

            <div style={{ 
              background: '#f8f9fa', 
              padding: '15px', 
              borderRadius: '4px', 
              marginBottom: '20px',
              border: '1px solid #e9ecef'
            }}>
              <p style={{ margin: '0 0 8px 0', fontWeight: 'bold', color: '#495057' }}>暂停说明：</p>
              <ul style={{ margin: 0, paddingLeft: '20px', color: '#6c757d', fontSize: '14px' }}>
                <li>暂停期间用户无法登录系统</li>
                <li>暂停期间用户无法发布或接受任务</li>
                <li>暂停期间用户无法发送消息</li>
                <li>暂停时间到期后自动恢复</li>
              </ul>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowSuspendModal(false);
                  setSelectedUserId(null);
                  setSuspendDuration(1);
                }}
                style={{
                  padding: '10px 20px',
                  border: '1px solid #ddd',
                  background: 'white',
                  color: '#666',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px'
                }}
              >
                取消
              </button>
              <button
                onClick={handleConfirmSuspend}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: '#ffc107',
                  color: 'black',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 'bold'
                }}
              >
                确认暂停 {suspendDuration} 天
              </button>
            </div>
          </div>
        </div>
      )}

      <style>{`
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      `}</style>
      
      {/* 提醒弹窗 */}
      <NotificationModal
        isOpen={showNotificationModal}
        onClose={() => setShowNotificationModal(false)}
        userType="admin"
        onNotificationRead={handleNotificationRead}
      />
      
      {/* 发送提醒弹窗 */}
      {showSendNotificationModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          zIndex: 1000
        }}>
          <div style={{
            backgroundColor: 'white',
            borderRadius: '8px',
            padding: '20px',
            maxWidth: '500px',
            width: '90%',
            boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
          }}>
            <h3 style={{ margin: '0 0 20px 0', color: '#333' }}>发送提醒</h3>
            
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>提醒标题：</label>
              <input
                type="text"
                value={staffNotificationForm.title}
                onChange={(e) => setStaffNotificationForm({...staffNotificationForm, title: e.target.value})}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '14px'
                }}
                placeholder="请输入提醒标题"
              />
            </div>
            
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>提醒内容：</label>
              <textarea
                value={staffNotificationForm.content}
                onChange={(e) => setStaffNotificationForm({...staffNotificationForm, content: e.target.value})}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '14px',
                  minHeight: '100px',
                  resize: 'vertical'
                }}
                placeholder="请输入提醒内容"
              />
            </div>
            
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowSendNotificationModal(false)}
                style={{
                  padding: '8px 16px',
                  border: '1px solid #ddd',
                  background: 'white',
                  color: '#666',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                取消
              </button>
              <button
                onClick={() => {
                  if (staffNotificationForm.title && staffNotificationForm.content) {
                    handleSendStaffNotification(
                      staffNotificationForm.recipientId,
                      staffNotificationForm.recipientType,
                      staffNotificationForm.title,
                      staffNotificationForm.content
                    );
                  } else {
                    alert('请填写标题和内容');
                  }
                }}
                disabled={loading}
                style={{
                  padding: '8px 16px',
                  border: 'none',
                  background: loading ? '#ccc' : '#28a745',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: loading ? 'not-allowed' : 'pointer'
                }}
              >
                {loading ? '发送中...' : '发送'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 任务管理弹窗 */}
      {showTaskManagement && (
        <TaskManagement
          onClose={() => setShowTaskManagement(false)}
        />
      )}

      {showCustomerServiceManagement && (
        <CustomerServiceManagement
          onClose={() => setShowCustomerServiceManagement(false)}
        />
      )}

      {/* 系统设置弹窗 */}
      {showSystemSettings && (
        <SystemSettings
          onClose={() => setShowSystemSettings(false)}
        />
      )}

      {/* 岗位管理弹窗 */}
      {showJobPositionManagement && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          zIndex: 1000,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          padding: '20px'
        }}>
          <div style={{
            background: 'white',
            borderRadius: '8px',
            width: '95%',
            height: '90%',
            maxWidth: '1400px',
            position: 'relative',
            overflow: 'hidden'
          }}>
            <div style={{
              position: 'absolute',
              top: '10px',
              right: '10px',
              zIndex: 1001
            }}>
              <button
                onClick={() => setShowJobPositionManagement(false)}
                style={{
                  background: '#ff4757',
                  color: 'white',
                  border: 'none',
                  borderRadius: '50%',
                  width: '30px',
                  height: '30px',
                  cursor: 'pointer',
                  fontSize: '16px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center'
                }}
              >
                ×
              </button>
            </div>
            <div style={{ height: '100%', overflow: 'auto' }}>
              <JobPositionManagement />
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminDashboard; 