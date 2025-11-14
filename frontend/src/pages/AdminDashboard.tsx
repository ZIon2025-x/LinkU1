import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { message, Modal } from 'antd';
import api, { 
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
  deleteTaskExpert,
  adminLogout,
  createInvitationCode,
  getInvitationCodes,
  getInvitationCodeDetail,
  updateInvitationCode,
  deleteInvitationCode
} from '../api';
import NotificationBell, { NotificationBellRef } from '../components/NotificationBell';
import NotificationModal from '../components/NotificationModal';
import TaskManagement from '../components/TaskManagement';
import CustomerServiceManagement from '../components/CustomerServiceManagement';
import SystemSettings from '../components/SystemSettings';
import JobPositionManagement from './JobPositionManagement';
import dayjs from 'dayjs';

// 城市列表 - 与任务达人页面保持一致
const CITIES = [
  "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

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
  inviter_id?: string;  // 邀请人ID
  invitation_code_text?: string;  // 邀请码文本
  invitation_code_id?: number;  // 邀请码ID
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
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
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
    category: 'programming',
    location: 'Online' // 默认城市
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

  // 邀请码管理相关状态
  const [invitationCodes, setInvitationCodes] = useState<any[]>([]);
  const [invitationCodesPage, setInvitationCodesPage] = useState(1);
  const [invitationCodesTotal, setInvitationCodesTotal] = useState(0);
  const [invitationCodesStatusFilter, setInvitationCodesStatusFilter] = useState<string | undefined>(undefined);
  const [showInvitationCodeModal, setShowInvitationCodeModal] = useState(false);
  const [invitationCodeForm, setInvitationCodeForm] = useState({
    id: undefined as number | undefined,
    code: '',
    name: '',
    description: '',
    reward_type: 'points' as 'points' | 'coupon' | 'both',
    points_reward: 0,
    coupon_id: undefined as number | undefined,
    max_uses: undefined as number | undefined,
    valid_from: '',
    valid_until: '',
    is_active: true
  });

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
      } else if (activeTab === 'invitation-codes') {
        const codesData = await getInvitationCodes({
          page: invitationCodesPage,
          limit: 20,
          status: invitationCodesStatusFilter as 'active' | 'inactive' | undefined
        });
        setInvitationCodes(codesData.data || []);
        setInvitationCodesTotal(codesData.total || 0);
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
  }, [activeTab, currentPage, searchTerm, invitationCodesPage, invitationCodesStatusFilter]);

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  const handleCreateCustomerService = async () => {
    if (!newCustomerService.name || !newCustomerService.email || !newCustomerService.password) {
      message.warning('请填写完整信息');
      return;
    }

    try {
      await createCustomerService(newCustomerService);
      message.success('客服账号创建成功！');
      setNewCustomerService({ name: '', email: '', password: '' });
      loadDashboardData();
    } catch (error: any) {
      message.error(error.response?.data?.detail || '创建失败');
    }
  };

  const handleCreateAdminUser = async () => {
    if (!newAdminUser.name || !newAdminUser.username || !newAdminUser.email || !newAdminUser.password) {
      message.warning('请填写完整信息');
      return;
    }

    try {
      await createAdminUser(newAdminUser);
      message.success('管理员账号创建成功！');
      setNewAdminUser({ name: '', username: '', email: '', password: '', is_super_admin: 0 });
      loadDashboardData();
    } catch (error: any) {
      message.error(error.response?.data?.detail || '创建失败');
    }
  };

  const handleDeleteCustomerService = async (csId: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个客服账号吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteCustomerService(csId);
          message.success('客服账号删除成功！');
          loadDashboardData();
        } catch (error: any) {
          message.error(error.response?.data?.detail || '删除失败');
        }
      }
    });
  };

  const handleDeleteAdminUser = async (adminId: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个管理员账号吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteAdminUser(adminId);
          message.success('管理员账号删除成功！');
          loadDashboardData();
        } catch (error: any) {
          message.error(error.response?.data?.detail || '删除失败');
        }
      }
    });
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
      message.success('提醒发送成功！');
      setShowSendNotificationModal(false);
      setStaffNotificationForm({ recipientId: '', recipientType: '', title: '', content: '' });
    } catch (error: any) {
      message.error(error.response?.data?.detail || '发送失败');
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
      message.success('用户等级更新成功！');
      loadDashboardData();
    } catch (error: any) {
      message.error(error.response?.data?.detail || '更新失败');
    } finally {
      setUserActionLoading(null);
    }
  };

  const handleBanUser = async (userId: string, isBanned: number) => {
    setUserActionLoading(userId);
    try {
      await updateUserByAdmin(userId, { is_banned: isBanned });
      message.success(isBanned ? '用户已封禁' : '用户已解封');
      loadDashboardData();
    } catch (error: any) {
      message.error(error.response?.data?.detail || '操作失败');
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
      message.success(isSuspended ? `用户已暂停${suspendDuration}天` : '用户已恢复');
      loadDashboardData();
    } catch (error: any) {
      message.error(error.response?.data?.detail || '操作失败');
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
      message.warning('请填写通知标题和内容');
      return;
    }

    try {
      await sendAdminNotification({
        ...notificationForm,
        user_ids: notificationForm.user_ids.length > 0 ? notificationForm.user_ids : []
      });
      message.success('通知发送成功！');
      setNotificationForm({ title: '', content: '', user_ids: [] });
    } catch (error: any) {
      message.error(error.response?.data?.detail || '发送失败');
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

  const [cleanupLoading, setCleanupLoading] = useState(false);

  const handleCleanupOldTasks = async () => {
    if (!window.confirm('确定要清理所有已完成和过期任务的图片和文件吗？此操作不可恢复！')) {
      return;
    }

    setCleanupLoading(true);
    try {
      const response = await api.post('/api/admin/cleanup/all-old-tasks');
      if (response.data.success) {
        message.success(response.data.message);
      } else {
        message.error('清理失败');
      }
    } catch (error: any) {
      console.error('清理失败:', error);
      message.error(error.response?.data?.detail || '清理失败，请稍后重试');
    } finally {
      setCleanupLoading(false);
    }
  };

  const renderDashboard = () => (
    <div style={{ marginTop: '20px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>数据概览</h2>
        <button
          onClick={handleCleanupOldTasks}
          disabled={cleanupLoading}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: cleanupLoading ? '#ccc' : '#dc3545',
            color: 'white',
            cursor: cleanupLoading ? 'not-allowed' : 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}
        >
          {cleanupLoading ? (
            <>
              <span style={{
                display: 'inline-block',
                width: '14px',
                height: '14px',
                border: '2px solid #fff',
                borderTop: '2px solid transparent',
                borderRadius: '50%',
                animation: 'spin 1s linear infinite'
              }}></span>
              清理中...
            </>
          ) : (
            <>
              🗑️ 一键清理已完成和过期任务文件
            </>
          )}
        </button>
      </div>
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
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>邀请码</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600 }}>邀请人</th>
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
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    {user.invitation_code_text ? (
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        background: '#e3f2fd',
                        color: '#1565c0',
                        fontSize: '12px',
                        fontWeight: '500',
                        fontFamily: 'monospace'
                      }}>
                        {user.invitation_code_text}
                      </span>
                    ) : (
                      <span style={{ color: '#999', fontSize: '12px' }}>-</span>
                    )}
                  </td>
                  <td style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    {user.inviter_id ? (
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        background: '#fff3e0',
                        color: '#e65100',
                        fontSize: '12px',
                        fontWeight: '500',
                        fontFamily: 'monospace',
                        cursor: 'pointer'
                      }}
                      onClick={() => {
                        setSearchTerm(user.inviter_id || '');
                        setActiveTab('users');
                      }}
                      title="点击查看邀请人信息"
                      >
                        {user.inviter_id}
                      </span>
                    ) : (
                      <span style={{ color: '#999', fontSize: '12px' }}>-</span>
                    )}
                  </td>
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
                <td colSpan={11} style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
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
              category: 'programming',
              location: 'Online'
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
                        Modal.confirm({
                          title: '确认删除',
                          content: '确定要删除这个任务达人吗？',
                          okText: '确定',
                          cancelText: '取消',
                          onOk: async () => {
                            try {
                              await deleteTaskExpert(expert.id);
                              await loadDashboardData();
                              message.success('任务达人删除成功！');
                            } catch (error: any) {
                              console.error('删除失败:', error);
                              message.error(error.response?.data?.detail || '删除失败');
                            }
                          }
                        });
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
        <div 
          style={{
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
          }}
          onClick={(e) => {
            // 点击背景遮罩层关闭弹窗
            if (e.target === e.currentTarget) {
              setShowTaskExpertModal(false);
            }
          }}
        >
          <div 
            style={{
              background: 'white',
              padding: '30px',
              borderRadius: '8px',
              boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)',
              maxWidth: '1200px',
              width: '95%',
              maxHeight: '90vh',
              overflow: 'auto',
              position: 'relative'
            }}
            onClick={(e) => {
              // 阻止点击内容区域关闭弹窗
              e.stopPropagation();
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3 style={{ margin: 0 }}>任务达人表单</h3>
              <button
                onClick={() => setShowTaskExpertModal(false)}
                style={{
                  position: 'absolute',
                  top: '15px',
                  right: '15px',
                  background: 'transparent',
                  border: 'none',
                  fontSize: '24px',
                  color: '#666',
                  cursor: 'pointer',
                  padding: '5px 10px',
                  lineHeight: '1',
                  borderRadius: '4px',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#f0f0f0';
                  e.currentTarget.style.color = '#000';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'transparent';
                  e.currentTarget.style.color = '#666';
                }}
                title="关闭"
              >
                ×
              </button>
            </div>
            
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>头像</label>
              <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
                <div style={{
                  width: '60px',
                  height: '60px',
                  borderRadius: '50%',
                  border: '2px solid #ddd',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  overflow: 'hidden',
                  backgroundColor: '#f5f5f5',
                  flexShrink: 0
                }}>
                  {taskExpertForm.avatar ? (
                    <img
                      key={taskExpertForm.avatar} // 添加key强制重新渲染
                      src={taskExpertForm.avatar}
                      alt="头像预览"
                      onError={(e) => {
                        console.error('头像加载失败:', taskExpertForm.avatar);
                        // 如果加载失败，显示占位符
                        const img = e.currentTarget;
                        const parent = img.parentElement;
                        if (parent) {
                          parent.innerHTML = '<span style="font-size: 10px; color: #ff4d4f;">加载失败</span>';
                        }
                      }}
                      onLoad={() => {
                        console.log('头像加载成功:', taskExpertForm.avatar);
                      }}
                      style={{
                        width: '100%',
                        height: '100%',
                        objectFit: 'cover',
                        display: 'block',
                        cursor: 'pointer'
                      }}
                      title={taskExpertForm.avatar}
                    />
                  ) : (
                    <span style={{ fontSize: '12px', color: '#999' }}>头像预览</span>
                  )}
                </div>
                <div style={{ flex: 1 }}>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={async (e) => {
                      const file = e.target.files?.[0];
                      if (file) {
                        // 检查文件大小（限制5MB）
                        if (file.size > 5 * 1024 * 1024) {
                          message.warning('图片文件过大，请选择小于5MB的图片');
                          e.target.value = '';
                          return;
                        }
                        
                        // 检查文件类型
                        if (!file.type.startsWith('image/')) {
                          message.warning('请选择图片文件');
                          e.target.value = '';
                          return;
                        }
                        
                        setUploadingAvatar(true);
                        try {
                          // 上传图片到服务器
                          const formData = new FormData();
                          formData.append('image', file);
                          
                          const response = await api.post('/api/upload/public-image', formData, {
                            headers: {
                              'Content-Type': 'multipart/form-data',
                            },
                          });
                          
                          if (response.data.success && response.data.url) {
                            // 使用服务器返回的URL
                            setTaskExpertForm({...taskExpertForm, avatar: response.data.url});
                          } else {
                            message.error('图片上传失败，请重试');
                          }
                        } catch (error: any) {
                          console.error('图片上传失败:', error);
                          message.error(error.response?.data?.detail || '图片上传失败，请重试');
                        } finally {
                          setUploadingAvatar(false);
                          // 重置文件输入框
                          e.target.value = '';
                        }
                      }
                    }}
                    style={{ display: 'none' }}
                    id="avatar-upload-input"
                  />
                  <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                    <button
                      type="button"
                      onClick={() => document.getElementById('avatar-upload-input')?.click()}
                      disabled={uploadingAvatar}
                      style={{
                        padding: '8px 16px',
                        background: uploadingAvatar ? '#9ca3af' : '#3b82f6',
                        color: 'white',
                        border: 'none',
                        borderRadius: '4px',
                        cursor: uploadingAvatar ? 'not-allowed' : 'pointer',
                        fontSize: '14px'
                      }}
                    >
                      {uploadingAvatar ? '上传中...' : (taskExpertForm.avatar ? '更换头像' : '上传头像')}
                    </button>
                    <input
                      type="text"
                      value={taskExpertForm.avatar}
                      onChange={(e) => setTaskExpertForm({...taskExpertForm, avatar: e.target.value})}
                      placeholder="或直接输入头像URL"
                      style={{
                        flex: 1,
                        padding: '8px',
                        border: '1px solid #ddd',
                        borderRadius: '4px'
                      }}
                    />
                    {taskExpertForm.avatar && (
                      <button
                        type="button"
                        onClick={() => setTaskExpertForm({...taskExpertForm, avatar: ''})}
                        style={{
                          padding: '8px 16px',
                          background: '#dc3545',
                          color: 'white',
                          border: 'none',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '14px'
                        }}
                      >
                        清除
                      </button>
                    )}
                  </div>
                </div>
              </div>
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
                  <option value="tutoring">学业辅导</option>
                  <option value="food">美食料理</option>
                  <option value="beverage">饮品调制</option>
                  <option value="cake">蛋糕烘焙</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '15px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>城市</label>
                <select
                  value={taskExpertForm.location || 'Online'}
                  onChange={(e) => setTaskExpertForm({...taskExpertForm, location: e.target.value})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px'
                  }}
                >
                  {CITIES.map(city => (
                    <option key={city} value={city}>
                      {city}
                    </option>
                  ))}
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

  // 邀请码管理相关函数
  const handleCreateInvitationCode = async () => {
    if (!invitationCodeForm.code || !invitationCodeForm.valid_from || !invitationCodeForm.valid_until) {
      message.warning('请填写邀请码、有效期开始时间和结束时间');
      return;
    }

    if (invitationCodeForm.reward_type === 'points' && invitationCodeForm.points_reward <= 0) {
      message.warning('积分奖励必须大于0');
      return;
    }

    if (invitationCodeForm.reward_type === 'coupon' && !invitationCodeForm.coupon_id) {
      message.warning('请选择优惠券');
      return;
    }

    if (invitationCodeForm.reward_type === 'both') {
      if (invitationCodeForm.points_reward <= 0 || !invitationCodeForm.coupon_id) {
        message.warning('积分奖励必须大于0且必须选择优惠券');
        return;
      }
    }

    try {
      // 将本地时间转换为ISO格式（带时区）
      const validFromDate = new Date(invitationCodeForm.valid_from);
      const validUntilDate = new Date(invitationCodeForm.valid_until);
      
      if (isNaN(validFromDate.getTime())) {
        message.error('有效期开始时间格式不正确');
        return;
      }
      if (isNaN(validUntilDate.getTime())) {
        message.error('有效期结束时间格式不正确');
        return;
      }
      
      const validFromISO = validFromDate.toISOString();
      const validUntilISO = validUntilDate.toISOString();
      
      await createInvitationCode({
        code: invitationCodeForm.code,
        name: invitationCodeForm.name || undefined,
        description: invitationCodeForm.description || undefined,
        reward_type: invitationCodeForm.reward_type,
        points_reward: invitationCodeForm.points_reward || undefined,
        coupon_id: invitationCodeForm.coupon_id || undefined,
        max_uses: invitationCodeForm.max_uses || undefined,
        valid_from: validFromISO,
        valid_until: validUntilISO,
        is_active: invitationCodeForm.is_active
      });
      message.success('邀请码创建成功！');
      setShowInvitationCodeModal(false);
      setInvitationCodeForm({
        id: undefined,
        code: '',
        name: '',
        description: '',
        reward_type: 'points',
        points_reward: 0,
        coupon_id: undefined,
        max_uses: undefined,
        valid_from: '',
        valid_until: '',
        is_active: true
      });
      loadDashboardData();
    } catch (error: any) {
      console.error('创建邀请码失败:', error);
      const errorDetail = error.response?.data?.detail || error.message || '创建失败';
      message.error(typeof errorDetail === 'string' ? errorDetail : JSON.stringify(errorDetail));
    }
  };

  const handleUpdateInvitationCode = async () => {
    if (!invitationCodeForm.id) return;

    try {
      // 将本地时间转换为ISO格式（带时区）
      const validFromISO = invitationCodeForm.valid_from ? new Date(invitationCodeForm.valid_from).toISOString() : undefined;
      const validUntilISO = invitationCodeForm.valid_until ? new Date(invitationCodeForm.valid_until).toISOString() : undefined;
      
      await updateInvitationCode(invitationCodeForm.id, {
        name: invitationCodeForm.name || undefined,
        description: invitationCodeForm.description || undefined,
        is_active: invitationCodeForm.is_active,
        max_uses: invitationCodeForm.max_uses || undefined,
        valid_from: validFromISO,
        valid_until: validUntilISO,
        points_reward: invitationCodeForm.points_reward || undefined,
        coupon_id: invitationCodeForm.coupon_id || undefined
      });
      message.success('邀请码更新成功！');
      setShowInvitationCodeModal(false);
      setInvitationCodeForm({
        id: undefined,
        code: '',
        name: '',
        description: '',
        reward_type: 'points',
        points_reward: 0,
        coupon_id: undefined,
        max_uses: undefined,
        valid_from: '',
        valid_until: '',
        is_active: true
      });
      loadDashboardData();
    } catch (error: any) {
      message.error(error.response?.data?.detail || '更新失败');
    }
  };

  const handleDeleteInvitationCode = async (id: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个邀请码吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteInvitationCode(id);
          message.success('邀请码删除成功！');
          loadDashboardData();
        } catch (error: any) {
          message.error(error.response?.data?.detail || '删除失败');
        }
      }
    });
  };

  const handleEditInvitationCode = async (id: number) => {
    try {
      const detail = await getInvitationCodeDetail(id);
      setInvitationCodeForm({
        id: detail.id,
        code: detail.code,
        name: detail.name || '',
        description: detail.description || '',
        reward_type: detail.reward_type as 'points' | 'coupon' | 'both',
        points_reward: detail.points_reward || 0,
        coupon_id: detail.coupon_id || undefined,
        max_uses: detail.max_uses || undefined,
        valid_from: detail.valid_from ? new Date(detail.valid_from).toISOString().slice(0, 16) : '',
        valid_until: detail.valid_until ? new Date(detail.valid_until).toISOString().slice(0, 16) : '',
        is_active: detail.is_active
      });
      setShowInvitationCodeModal(true);
    } catch (error: any) {
      message.error(error.response?.data?.detail || '获取详情失败');
    }
  };

  const renderInvitationCodes = () => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>邀请码管理</h2>
        <button
          onClick={() => {
            setInvitationCodeForm({
              id: undefined,
              code: '',
              name: '',
              description: '',
              reward_type: 'points',
              points_reward: 0,
              coupon_id: undefined,
              max_uses: undefined,
              valid_from: '',
              valid_until: '',
              is_active: true
            });
            setShowInvitationCodeModal(true);
          }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#28a745',
            color: 'white',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          创建邀请码
        </button>
      </div>

      {/* 筛选器 */}
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', alignItems: 'center' }}>
        <label style={{ fontWeight: 'bold' }}>状态筛选：</label>
        <select
          value={invitationCodesStatusFilter || ''}
          onChange={(e) => {
            setInvitationCodesStatusFilter(e.target.value || undefined);
            setInvitationCodesPage(1);
            setTimeout(() => loadDashboardData(), 100);
          }}
          style={{
            padding: '8px 12px',
            border: '1px solid #ddd',
            borderRadius: '4px',
            fontSize: '14px'
          }}
        >
          <option value="">全部</option>
          <option value="active">启用</option>
          <option value="inactive">禁用</option>
        </select>
      </div>

      {/* 邀请码列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>邀请码</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>名称</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>奖励类型</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>积分奖励</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>使用次数</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>有效期</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {invitationCodes.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
                  暂无邀请码数据
                </td>
              </tr>
            ) : (
              invitationCodes.map((code: any) => (
                <tr key={code.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{code.code}</td>
                  <td style={{ padding: '12px' }}>{code.name || '-'}</td>
                  <td style={{ padding: '12px' }}>
                    {code.reward_type === 'points' ? '积分' : 
                     code.reward_type === 'coupon' ? '优惠券' : '积分+优惠券'}
                  </td>
                  <td style={{ padding: '12px' }}>
                    {code.points_reward_display || '0.00'}
                  </td>
                  <td style={{ padding: '12px' }}>
                    {code.used_count || 0} / {code.max_uses || '∞'}
                  </td>
                  <td style={{ padding: '12px', fontSize: '12px' }}>
                    {new Date(code.valid_from).toLocaleString('zh-CN')} ~<br/>
                    {new Date(code.valid_until).toLocaleString('zh-CN')}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: code.is_active ? '#d4edda' : '#f8d7da',
                      color: code.is_active ? '#155724' : '#721c24',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {code.is_active ? '启用' : '禁用'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleEditInvitationCode(code.id)}
                        style={{
                          padding: '4px 8px',
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
                        onClick={() => handleDeleteInvitationCode(code.id)}
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
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* 分页 */}
      {invitationCodesTotal > 20 && (
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
          <button
            onClick={() => {
              if (invitationCodesPage > 1) {
                setInvitationCodesPage(invitationCodesPage - 1);
                setTimeout(() => loadDashboardData(), 100);
              }
            }}
            disabled={invitationCodesPage === 1}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: invitationCodesPage === 1 ? '#f5f5f5' : 'white',
              color: invitationCodesPage === 1 ? '#999' : '#333',
              borderRadius: '4px',
              cursor: invitationCodesPage === 1 ? 'not-allowed' : 'pointer'
            }}
          >
            上一页
          </button>
          <span style={{ padding: '8px 16px', display: 'flex', alignItems: 'center' }}>
            第 {invitationCodesPage} 页，共 {Math.ceil(invitationCodesTotal / 20)} 页
          </span>
          <button
            onClick={() => {
              if (invitationCodesPage < Math.ceil(invitationCodesTotal / 20)) {
                setInvitationCodesPage(invitationCodesPage + 1);
                setTimeout(() => loadDashboardData(), 100);
              }
            }}
            disabled={invitationCodesPage >= Math.ceil(invitationCodesTotal / 20)}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: invitationCodesPage >= Math.ceil(invitationCodesTotal / 20) ? '#f5f5f5' : 'white',
              color: invitationCodesPage >= Math.ceil(invitationCodesTotal / 20) ? '#999' : '#333',
              borderRadius: '4px',
              cursor: invitationCodesPage >= Math.ceil(invitationCodesTotal / 20) ? 'not-allowed' : 'pointer'
            }}
          >
            下一页
          </button>
        </div>
      )}

      {/* 创建/编辑邀请码模态框 */}
      {showInvitationCodeModal && (
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
            minWidth: '500px',
            maxWidth: '600px',
            maxHeight: '90vh',
            overflowY: 'auto'
          }}>
            <h3 style={{ margin: '0 0 20px 0', color: '#333' }}>
              {invitationCodeForm.id ? '编辑邀请码' : '创建邀请码'}
            </h3>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                邀请码 <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="text"
                value={invitationCodeForm.code}
                onChange={(e) => setInvitationCodeForm({...invitationCodeForm, code: e.target.value.toUpperCase()})}
                disabled={!!invitationCodeForm.id}
                placeholder="请输入邀请码（自动转为大写）"
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>名称</label>
              <input
                type="text"
                value={invitationCodeForm.name}
                onChange={(e) => setInvitationCodeForm({...invitationCodeForm, name: e.target.value})}
                placeholder="请输入邀请码名称（可选）"
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>描述</label>
              <textarea
                value={invitationCodeForm.description}
                onChange={(e) => setInvitationCodeForm({...invitationCodeForm, description: e.target.value})}
                placeholder="请输入邀请码描述（可选）"
                rows={3}
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                奖励类型 <span style={{ color: 'red' }}>*</span>
              </label>
              <select
                value={invitationCodeForm.reward_type}
                onChange={(e) => setInvitationCodeForm({...invitationCodeForm, reward_type: e.target.value as 'points' | 'coupon' | 'both'})}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  marginTop: '5px'
                }}
              >
                <option value="points">积分</option>
                <option value="coupon">优惠券</option>
                <option value="both">积分+优惠券</option>
              </select>
            </div>

            {(invitationCodeForm.reward_type === 'points' || invitationCodeForm.reward_type === 'both') && (
              <div style={{ marginBottom: '15px' }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                  积分奖励（分）<span style={{ color: 'red' }}>*</span>
                </label>
                <input
                  type="number"
                  value={invitationCodeForm.points_reward}
                  onChange={(e) => setInvitationCodeForm({...invitationCodeForm, points_reward: parseInt(e.target.value) || 0})}
                  placeholder="请输入积分奖励（以分为单位，如100表示1.00）"
                  min="0"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    marginTop: '5px'
                  }}
                />
                <small style={{ color: '#666', fontSize: '12px', marginTop: '5px', display: 'block' }}>
                  提示：100分 = 1.00，例如输入1000表示10.00
                </small>
              </div>
            )}

            {(invitationCodeForm.reward_type === 'coupon' || invitationCodeForm.reward_type === 'both') && (
              <div style={{ marginBottom: '15px' }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                  优惠券ID <span style={{ color: 'red' }}>*</span>
                </label>
                <input
                  type="number"
                  value={invitationCodeForm.coupon_id || ''}
                  onChange={(e) => setInvitationCodeForm({...invitationCodeForm, coupon_id: e.target.value ? parseInt(e.target.value) : undefined})}
                  placeholder="请输入优惠券ID"
                  min="1"
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    marginTop: '5px'
                  }}
                />
              </div>
            )}

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>最大使用次数</label>
              <input
                type="number"
                value={invitationCodeForm.max_uses || ''}
                onChange={(e) => setInvitationCodeForm({...invitationCodeForm, max_uses: e.target.value ? parseInt(e.target.value) : undefined})}
                placeholder="留空表示无限制"
                min="1"
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                有效期开始时间 <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="datetime-local"
                value={invitationCodeForm.valid_from}
                onChange={(e) => setInvitationCodeForm({...invitationCodeForm, valid_from: e.target.value})}
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                有效期结束时间 <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="datetime-local"
                value={invitationCodeForm.valid_until}
                onChange={(e) => setInvitationCodeForm({...invitationCodeForm, valid_until: e.target.value})}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  marginTop: '5px'
                }}
              />
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={invitationCodeForm.is_active}
                  onChange={(e) => setInvitationCodeForm({...invitationCodeForm, is_active: e.target.checked})}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontWeight: 'bold' }}>启用</span>
              </label>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowInvitationCodeModal(false);
                  setInvitationCodeForm({
                    id: undefined,
                    code: '',
                    name: '',
                    description: '',
                    reward_type: 'points',
                    points_reward: 0,
                    coupon_id: undefined,
                    max_uses: undefined,
                    valid_from: '',
                    valid_until: '',
                    is_active: true
                  });
                }}
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
              <button
                onClick={invitationCodeForm.id ? handleUpdateInvitationCode : handleCreateInvitationCode}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: '#007bff',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                {invitationCodeForm.id ? '更新' : '创建'}
              </button>
            </div>
          </div>
        </div>
      )}
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
          <button 
            onClick={async () => {
              try {
                await adminLogout();
                message.success('退出登录成功');
                // 跳转到登录页
                navigate('/admin/login');
              } catch (error: any) {
                console.error('退出登录失败:', error);
                // 即使API失败，也清除cookie并跳转
                document.cookie.split(";").forEach((c) => {
                  const eqPos = c.indexOf("=");
                  const name = eqPos > -1 ? c.substr(0, eqPos).trim() : c.trim();
                  document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
                });
                navigate('/admin/login');
              }
            }}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            退出登录
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
        <button 
          style={{
            padding: '10px 20px',
            border: 'none',
            background: activeTab === 'invitation-codes' ? '#007bff' : '#f0f0f0',
            color: activeTab === 'invitation-codes' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
          onClick={() => setActiveTab('invitation-codes')}
        >
          邀请码管理
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
            {activeTab === 'invitation-codes' && renderInvitationCodes()}
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
                    message.warning('请填写标题和内容');
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