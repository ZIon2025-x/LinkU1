/**
 * 任务达人管理后台
 * 路径: /task-experts/me/dashboard
 * 功能: 服务管理、申请管理
 */

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import {
  fetchCurrentUser,
  getTaskExpert,
  updateTaskExpertProfile,
  getMyTaskExpertServices,
  createTaskExpertService,
  updateTaskExpertService,
  deleteTaskExpertService,
  getMyTaskExpertApplications,
  approveServiceApplication,
  rejectServiceApplication,
  counterOfferServiceApplication,
  submitProfileUpdateRequest,
  getMyProfileUpdateRequest,
  getTaskParticipants,
  startMultiParticipantTask,
  approveParticipant,
  rejectParticipant,
  approveExitRequest,
  rejectExitRequest,
  completeTaskAndDistributeRewardsEqual,
  createExpertMultiParticipantTask,
  getServiceTimeSlotsPublic,
} from '../api';
import LoginModal from '../components/LoginModal';
import ServiceDetailModal from '../components/ServiceDetailModal';
import api from '../api';

interface Service {
  id: number;
  service_name: string;
  description: string;
  images?: string[];
  base_price: number;
  currency: string;
  status: string;
  display_order: number;
  view_count: number;
  application_count: number;
  created_at: string;
  // 时间段相关字段（可选）
  has_time_slots?: boolean;
  time_slot_duration_minutes?: number;
  time_slot_start_time?: string;
  time_slot_end_time?: string;
  participants_per_slot?: number;
}

interface Application {
  id: number;
  service_id: number;
  service_name: string;
  applicant_id: string;
  applicant_name: string;
  status: string;
  application_message?: string;
  negotiated_price?: number;
  expert_counter_price?: number;
  final_price?: number;
  currency?: string;
  task_id?: number;
  created_at: string;
  updated_at: string;
}

const TaskExpertDashboard: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const [user, setUser] = useState<any>(null);
  const [expert, setExpert] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'services' | 'applications' | 'multi-tasks'>('services');
  
  // 服务管理相关
  const [services, setServices] = useState<Service[]>([]);
  const [loadingServices, setLoadingServices] = useState(false);
  const [showServiceModal, setShowServiceModal] = useState(false);
  const [editingService, setEditingService] = useState<Service | null>(null);
  
  // 申请管理相关
  const [applications, setApplications] = useState<Application[]>([]);
  const [loadingApplications, setLoadingApplications] = useState(false);
  const [selectedApplication, setSelectedApplication] = useState<Application | null>(null);
  const [showCounterOfferModal, setShowCounterOfferModal] = useState(false);
  const [counterPrice, setCounterPrice] = useState<number | undefined>();
  const [counterMessage, setCounterMessage] = useState('');
  
  // 登录弹窗
  const [showLoginModal, setShowLoginModal] = useState(false);
  
  // 信息修改相关
  const [showProfileEditModal, setShowProfileEditModal] = useState(false);
  const [profileForm, setProfileForm] = useState({ expert_name: '', bio: '', avatar: '' });
  const [pendingRequest, setPendingRequest] = useState<any>(null);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string>('');
  
  // 多人任务管理相关
  const [multiTasks, setMultiTasks] = useState<any[]>([]);
  const [loadingMultiTasks, setLoadingMultiTasks] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);
  const [taskParticipants, setTaskParticipants] = useState<{[key: number]: any[]}>({});
  const [recentActivities, setRecentActivities] = useState<any[]>([]);
  const [loadingRecentActivities, setLoadingRecentActivities] = useState(false);
  
  // 创建多人任务相关
  const [showCreateMultiTaskModal, setShowCreateMultiTaskModal] = useState(false);
  const [createMultiTaskForm, setCreateMultiTaskForm] = useState<{
    service_id?: number;
    title: string;
    description: string;
    deadline: string;
    location: string;
    task_type: string;
    max_participants: number;
    min_participants: number;
    reward_type: 'cash' | 'points' | 'both';
    base_reward: number;
    points_reward: number;
    reward_distribution: 'equal' | 'custom';
    discount_percentage?: number;
    custom_discount?: number;
    use_custom_discount: boolean;
    reward_applicants: boolean;
    currency: string;
    selected_time_slot_id?: number;
    selected_time_slot_date?: string;
  }>({
    service_id: undefined as number | undefined,
    title: '',
    description: '',
    max_participants: 1,
    min_participants: 1,
    reward_distribution: 'equal' as 'equal' | 'custom',
    deadline: '',
    location: 'Online',
    task_type: 'Skill Service',
    reward_type: 'cash' as 'cash' | 'points' | 'both',
    base_reward: 0,
    points_reward: 0,
    currency: 'GBP',
    discount_percentage: undefined as number | undefined,
    custom_discount: undefined as number | undefined,
    use_custom_discount: false,
    reward_applicants: false,
    selected_time_slot_id: undefined as number | undefined,
    selected_time_slot_date: undefined as string | undefined,
  });
  
  // 存储服务的时间段信息（临时方案，直到后端支持）
  const [serviceTimeSlotConfigs, setServiceTimeSlotConfigs] = useState<{[key: number]: {
    has_time_slots: boolean;
    time_slot_duration_minutes: number;
    time_slot_start_time: string;
    time_slot_end_time: string;
    participants_per_slot: number;
  }}>({});
  
  // 时间段相关状态（用于创建多人任务）
  const [availableTimeSlots, setAvailableTimeSlots] = useState<any[]>([]);
  const [loadingTimeSlots, setLoadingTimeSlots] = useState(false);
  
  // 加载时间段列表（用于创建多人任务）
  const loadTimeSlotsForCreateTask = async (serviceId: number) => {
    setLoadingTimeSlots(true);
    try {
      const today = new Date();
      const futureDate = new Date(today);
      futureDate.setDate(today.getDate() + 30);
      const params = {
        start_date: today.toISOString().split('T')[0],
        end_date: futureDate.toISOString().split('T')[0],
      };
      const slots = await getServiceTimeSlotsPublic(serviceId, params);
      setAvailableTimeSlots(Array.isArray(slots) ? slots : []);
    } catch (err: any) {
      console.error('加载时间段失败:', err);
      message.error('加载时间段失败');
      setAvailableTimeSlots([]);
    } finally {
      setLoadingTimeSlots(false);
    }
  };

  useEffect(() => {
    loadData();
    loadPendingRequest();
    loadRecentActivities();
  }, []);
  
  const loadPendingRequest = async () => {
    try {
      const request = await getMyProfileUpdateRequest();
      setPendingRequest(request);
    } catch (err: any) {
      // 如果没有待审核请求，忽略错误
      if (err.response?.status !== 404) {
        console.error('加载待审核请求失败:', err);
      }
    }
  };

  useEffect(() => {
    if (activeTab === 'services') {
      loadServices();
    } else if (activeTab === 'applications') {
      loadApplications();
    }
  }, [activeTab]);

  const loadData = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
      
      // 加载任务达人信息
      const expertData = await getTaskExpert(userData.id);
      setExpert(expertData);
    } catch (err: any) {
      if (err.response?.status === 401) {
        setShowLoginModal(true);
      } else if (err.response?.status === 404) {
        message.error('您还不是任务达人');
        navigate('/task-experts/intro');
      } else {
        message.error('加载数据失败');
      }
    } finally {
      setLoading(false);
    }
  };

  const loadServices = async () => {
    setLoadingServices(true);
    try {
      const data = await getMyTaskExpertServices();
      // API返回的数据结构可能是 { items: [...] } 或直接是数组
      const servicesList = Array.isArray(data) ? data : (data.items || []);
      
      // 从服务描述或扩展字段中解析时间段信息
      // 注意：目前时间段信息可能存储在前端，需要与后端同步
      const servicesWithTimeSlots = servicesList.map((service: any) => {
        // 如果服务有time_slot_config字段，解析它
        if (service.time_slot_config) {
          const config = {
            has_time_slots: service.time_slot_config.has_time_slots || false,
            time_slot_duration_minutes: service.time_slot_config.time_slot_duration_minutes || 60,
            time_slot_start_time: service.time_slot_config.time_slot_start_time || '09:00',
            time_slot_end_time: service.time_slot_config.time_slot_end_time || '18:00',
            participants_per_slot: service.time_slot_config.participants_per_slot || 1,
          };
          // 保存到本地状态
          setServiceTimeSlotConfigs(prev => ({
            ...prev,
            [service.id]: config
          }));
          return {
            ...service,
            ...config,
          };
        }
        // 如果本地状态中有时间段配置，使用它
        if (serviceTimeSlotConfigs[service.id]) {
          return {
            ...service,
            ...serviceTimeSlotConfigs[service.id],
          };
        }
        return service;
      });
      
      setServices(servicesWithTimeSlots);
    } catch (err: any) {
      message.error('加载服务列表失败');
    } finally {
      setLoadingServices(false);
    }
  };

  const loadApplications = async () => {
    setLoadingApplications(true);
    try {
      const data = await getMyTaskExpertApplications();
      // API返回的数据结构可能是 { items: [...] } 或直接是数组
      setApplications(Array.isArray(data) ? data : (data.items || []));
    } catch (err: any) {
      message.error('加载申请列表失败');
    } finally {
      setLoadingApplications(false);
    }
  };

  const handleCreateService = () => {
    setEditingService(null);
    setShowServiceModal(true);
  };

  const handleEditService = (service: Service) => {
    setEditingService(service);
    setShowServiceModal(true);
  };

  const handleDeleteService = async (serviceId: number) => {
    if (!window.confirm('确定要删除这个服务吗？')) {
      return;
    }
    
    try {
      await deleteTaskExpertService(serviceId);
      message.success('服务已删除');
      loadServices();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '删除服务失败');
    }
  };

  const handleApproveApplication = async (applicationId: number) => {
    try {
      const result = await approveServiceApplication(applicationId);
      message.success('申请已同意，任务已创建');
      if (result.task_id) {
        // 可以跳转到任务聊天页面
        navigate(`/tasks/${result.task_id}`);
      }
      loadApplications();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '同意申请失败');
    }
  };

  const handleRejectApplication = async (applicationId: number, reason?: string) => {
    // ⚠️ 性能优化：乐观更新 UI，不等待重新加载
    const originalApplications = [...applications];
    setApplications(prev => prev.map(app => 
      app.id === applicationId ? { ...app, status: 'rejected' } : app
    ));
    
    try {
      await rejectServiceApplication(applicationId, reason);
      message.success('申请已拒绝');
      // ⚠️ 后台刷新，不阻塞 UI
      loadApplications().catch(err => {
        console.error('刷新申请列表失败:', err);
        // 如果刷新失败，恢复原状态
        setApplications(originalApplications);
      });
    } catch (err: any) {
      // 如果失败，恢复原状态
      setApplications(originalApplications);
      message.error(err.response?.data?.detail || '拒绝申请失败');
    }
  };

  const handleCounterOffer = (application: Application) => {
    setSelectedApplication(application);
    setCounterPrice(application.negotiated_price ? application.negotiated_price * 1.2 : undefined);
    setCounterMessage('');
    setShowCounterOfferModal(true);
  };

  const handleSubmitCounterOffer = async () => {
    if (!selectedApplication || !counterPrice) {
      message.warning('请输入议价价格');
      return;
    }
    
    try {
      await counterOfferServiceApplication(selectedApplication.id, {
        counter_price: counterPrice,
        message: counterMessage || undefined,
      });
      message.success('议价已提交');
      setShowCounterOfferModal(false);
      loadApplications();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交议价失败');
    }
  };

  // 加载最近达人活动（最近发布的多人任务）
  const loadRecentActivities = async () => {
    if (!user) return;
    setLoadingRecentActivities(true);
    try {
      // 获取任务达人创建的最新的多人任务（最近5个）
      // 注意：后端可能不支持 order_by 参数，我们获取所有任务后在前端排序
      const response = await api.get('/api/tasks', {
        params: {
          expert_creator_id: user.id,
          is_multi_participant: true,
          limit: 20  // 获取更多任务，然后在前端排序和限制
        }
      });
      const tasks = response.data.tasks || response.data || [];
      // 按创建时间降序排序，取前5个
      const sortedTasks = tasks
        .sort((a: any, b: any) => {
          const dateA = new Date(a.created_at || 0).getTime();
          const dateB = new Date(b.created_at || 0).getTime();
          return dateB - dateA;
        })
        .slice(0, 5);
      setRecentActivities(sortedTasks);
    } catch (err: any) {
      console.error('加载最近达人活动失败:', err);
      // 不显示错误消息，因为这不是关键功能
    } finally {
      setLoadingRecentActivities(false);
    }
  };

  // 加载多人任务列表
  const loadMultiTasks = async () => {
    if (!user) return;
    setLoadingMultiTasks(true);
    try {
      // 获取任务达人创建的所有多人任务
      const response = await api.get('/api/tasks', {
        params: {
          expert_creator_id: user.id,
          is_multi_participant: true,
          limit: 100
        }
      });
      const tasks = response.data.tasks || response.data || [];
      setMultiTasks(tasks);
      
      // 并行加载所有任务的参与者列表
      const participantsMap: {[key: number]: any[]} = {};
      await Promise.all(
        tasks.map(async (task: any) => {
          try {
            const participantsData = await getTaskParticipants(task.id);
            participantsMap[task.id] = participantsData.participants || [];
          } catch (error) {
            console.error(`加载任务 ${task.id} 的参与者失败:`, error);
            participantsMap[task.id] = [];
          }
        })
      );
      setTaskParticipants(participantsMap);
    } catch (err: any) {
      message.error('加载多人任务列表失败');
      console.error('加载多人任务失败:', err);
    } finally {
      setLoadingMultiTasks(false);
    }
  };

  const getStatusText = (status: string) => {
    const statusMap: { [key: string]: string } = {
      pending: '待处理',
      negotiating: '议价中',
      price_agreed: '价格已达成',
      approved: '已同意',
      rejected: '已拒绝',
      cancelled: '已取消',
    };
    return statusMap[status] || status;
  };

  const getStatusColor = (status: string) => {
    const colorMap: { [key: string]: string } = {
      pending: '#f59e0b',
      negotiating: '#3b82f6',
      price_agreed: '#10b981',
      approved: '#10b981',
      rejected: '#ef4444',
      cancelled: '#6b7280',
    };
    return colorMap[status] || '#6b7280';
  };
  
  const handleAvatarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (file.size > 5 * 1024 * 1024) {
        message.error('头像文件大小不能超过5MB');
        return;
      }
      if (!file.type.startsWith('image/')) {
        message.error('请选择图片文件');
        return;
      }
      setAvatarFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setAvatarPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };
  
  const handleUploadAvatar = async (): Promise<string | null> => {
    if (!avatarFile) {
      return profileForm.avatar || null;
    }
    
    try {
      const formData = new FormData();
      formData.append('image', avatarFile);
      
      // 任务达人头像上传：传递expert_id（即user.id）作为resource_id
      const expertId = user?.id || expert?.id;
      const uploadUrl = expertId 
        ? `/api/upload/public-image?category=expert_avatar&resource_id=${expertId}`
        : '/api/upload/public-image?category=expert_avatar';
      
      const res = await api.post(uploadUrl, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      return res.data.url;
    } catch (err: any) {
      message.error('上传头像失败');
      return null;
    }
  };
  
  const handleSubmitProfileUpdate = async () => {
    if (!profileForm.expert_name && !profileForm.bio && !avatarFile && !profileForm.avatar) {
      message.warning('请至少修改一个字段');
      return;
    }
    
    if (pendingRequest) {
      message.warning('您已有一个待审核的修改请求，请等待审核完成后再提交新的请求');
      return;
    }
    
    try {
      let avatarUrl: string | null = profileForm.avatar || null;
      if (avatarFile) {
        avatarUrl = await handleUploadAvatar();
        if (!avatarUrl) {
          return;
        }
      }
      
      await submitProfileUpdateRequest({
        expert_name: profileForm.expert_name || undefined,
        bio: profileForm.bio || undefined,
        avatar: avatarUrl || undefined,
      });
      
      message.success('修改请求已提交，等待管理员审核');
      setShowProfileEditModal(false);
      loadPendingRequest();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交修改请求失败');
    }
  };

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '60px', fontSize: '18px' }}>
        加载中...
      </div>
    );
  }

  if (!expert) {
    return (
      <div style={{ textAlign: 'center', padding: '60px' }}>
        <div style={{ fontSize: '18px', marginBottom: '20px' }}>您还不是任务达人</div>
        <button
          onClick={() => navigate('/task-experts/intro')}
          style={{
            padding: '12px 24px',
            background: '#3b82f6',
            color: '#fff',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
          }}
        >
          申请成为任务达人
        </button>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', background: '#f7fafc', padding: '20px' }}>
      <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
        {/* 头部 */}
        <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', marginBottom: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h1 style={{ margin: 0, fontSize: '24px', fontWeight: 600, color: '#1a202c' }}>
                任务达人管理后台
              </h1>
              <div style={{ marginTop: '12px', color: '#718096' }}>
                欢迎回来，{expert.expert_name || user?.name || '任务达人'}
              </div>
              {pendingRequest && (
                <div style={{ marginTop: '12px', padding: '8px 12px', background: '#fef3c7', borderRadius: '6px', color: '#92400e', fontSize: '14px' }}>
                  您有一个待审核的信息修改请求，请等待管理员审核
                </div>
              )}
            </div>
            <button
              onClick={() => {
                setProfileForm({
                  expert_name: expert.expert_name || '',
                  bio: expert.bio || '',
                  avatar: expert.avatar || '',
                });
                setAvatarPreview(expert.avatar || '');
                setShowProfileEditModal(true);
              }}
              style={{
                padding: '10px 20px',
                background: '#3b82f6',
                color: '#fff',
                border: 'none',
                borderRadius: '8px',
                cursor: 'pointer',
                fontWeight: 500,
              }}
            >
              编辑资料
            </button>
          </div>
        </div>

        {/* 最近达人活动 */}
        {recentActivities.length > 0 && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', marginBottom: '24px' }}>
            <h2 style={{ margin: '0 0 20px 0', fontSize: '18px', fontWeight: 600, color: '#1a202c' }}>
              最近达人活动
            </h2>
            {loadingRecentActivities ? (
              <div style={{ textAlign: 'center', padding: '20px', color: '#718096' }}>加载中...</div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '16px' }}>
                {recentActivities.map((task: any) => {
                  const statusColors: { [key: string]: string } = {
                    open: '#3b82f6',
                    in_progress: '#10b981',
                    completed: '#6b7280',
                    cancelled: '#ef4444',
                  };
                  const statusTexts: { [key: string]: string } = {
                    open: '进行中',
                    in_progress: '进行中',
                    completed: '已完成',
                    cancelled: '已取消',
                  };
                  return (
                    <div
                      key={task.id}
                      onClick={() => navigate(`/tasks/${task.id}`)}
                      style={{
                        border: '1px solid #e2e8f0',
                        borderRadius: '8px',
                        padding: '16px',
                        cursor: 'pointer',
                        transition: 'all 0.2s',
                        background: '#fff',
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.borderColor = '#3b82f6';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(59, 130, 246, 0.1)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.borderColor = '#e2e8f0';
                        e.currentTarget.style.boxShadow = 'none';
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '12px' }}>
                        <h3 style={{ margin: 0, fontSize: '16px', fontWeight: 600, color: '#1a202c', flex: 1 }}>
                          {task.title}
                        </h3>
                        <span
                          style={{
                            padding: '4px 8px',
                            borderRadius: '4px',
                            fontSize: '12px',
                            fontWeight: 500,
                            background: `${statusColors[task.status] || '#6b7280'}20`,
                            color: statusColors[task.status] || '#6b7280',
                          }}
                        >
                          {statusTexts[task.status] || task.status}
                        </span>
                      </div>
                      <p
                        style={{
                          margin: '0 0 12px 0',
                          fontSize: '14px',
                          color: '#718096',
                          display: '-webkit-box',
                          WebkitLineClamp: 2,
                          WebkitBoxOrient: 'vertical',
                          overflow: 'hidden',
                        }}
                      >
                        {task.description}
                      </p>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '13px', color: '#4a5568' }}>
                        <div>
                          <span style={{ fontWeight: 500 }}>参与者: </span>
                          {task.current_participants || 0} / {task.max_participants}
                        </div>
                        {task.reward && task.reward > 0 && (
                          <div style={{ fontWeight: 600, color: '#059669' }}>
                            {task.currency || 'GBP'} {task.reward.toFixed(2)}
                          </div>
                        )}
                      </div>
                      {task.deadline && (
                        <div style={{ marginTop: '8px', fontSize: '12px', color: '#9ca3af' }}>
                          截止: {new Date(task.deadline).toLocaleDateString('zh-CN')}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
            {recentActivities.length > 0 && (
              <div style={{ marginTop: '16px', textAlign: 'right' }}>
                <button
                  onClick={() => setActiveTab('multi-tasks')}
                  style={{
                    padding: '8px 16px',
                    background: 'transparent',
                    color: '#3b82f6',
                    border: '1px solid #3b82f6',
                    borderRadius: '6px',
                    cursor: 'pointer',
                    fontSize: '14px',
                    fontWeight: 500,
                  }}
                >
                  查看全部多人任务 →
                </button>
              </div>
            )}
          </div>
        )}

        {/* 标签页 */}
        <div style={{ display: 'flex', gap: '12px', marginBottom: '24px' }}>
          <button
            onClick={() => setActiveTab('services')}
            style={{
              padding: '12px 24px',
              background: activeTab === 'services' ? '#3b82f6' : '#fff',
              color: activeTab === 'services' ? '#fff' : '#333',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            服务管理
          </button>
          <button
            onClick={() => setActiveTab('applications')}
            style={{
              padding: '12px 24px',
              background: activeTab === 'applications' ? '#3b82f6' : '#fff',
              color: activeTab === 'applications' ? '#fff' : '#333',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            申请管理
          </button>
          <button
            onClick={() => setActiveTab('multi-tasks')}
            style={{
              padding: '12px 24px',
              background: activeTab === 'multi-tasks' ? '#3b82f6' : '#fff',
              color: activeTab === 'multi-tasks' ? '#fff' : '#333',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            多人任务
          </button>
        </div>

        {/* 服务管理 */}
        {activeTab === 'services' && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', fontWeight: 600 }}>我的服务</h2>
              <button
                onClick={handleCreateService}
                style={{
                  padding: '10px 20px',
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontWeight: 600,
                }}
              >
                + 创建服务
              </button>
            </div>

            {loadingServices ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : services.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
                暂无服务，点击"创建服务"按钮添加
              </div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' }}>
                {services.map((service) => (
                  <div
                    key={service.id}
                    style={{
                      border: '1px solid #e2e8f0',
                      borderRadius: '12px',
                      padding: '20px',
                      background: '#fff',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '12px' }}>
                      <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600, color: '#1a202c' }}>
                        {service.service_name}
                      </h3>
                      <span
                        style={{
                          padding: '4px 8px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: 600,
                          background: service.status === 'active' ? '#d1fae5' : '#fee2e2',
                          color: service.status === 'active' ? '#065f46' : '#991b1b',
                        }}
                      >
                        {service.status === 'active' ? '上架' : '下架'}
                      </span>
                    </div>
                    
                    <div style={{ fontSize: '14px', color: '#4a5568', marginBottom: '12px', lineHeight: '1.5' }}>
                      {service.description?.substring(0, 100)}
                      {service.description && service.description.length > 100 ? '...' : ''}
                    </div>
                    
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                      <div style={{ fontSize: '20px', fontWeight: 700, color: '#3b82f6' }}>
                        {service.currency} {service.base_price.toFixed(2)}
                      </div>
                      <div style={{ fontSize: '12px', color: '#718096' }}>
                        {service.application_count} 申请
                      </div>
                    </div>
                    
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleEditService(service)}
                        style={{
                          flex: 1,
                          padding: '8px',
                          background: '#f3f4f6',
                          color: '#333',
                          border: 'none',
                          borderRadius: '6px',
                          cursor: 'pointer',
                          fontSize: '14px',
                        }}
                      >
                        编辑
                      </button>
                      <button
                        onClick={() => handleDeleteService(service.id)}
                        style={{
                          flex: 1,
                          padding: '8px',
                          background: '#fee2e2',
                          color: '#991b1b',
                          border: 'none',
                          borderRadius: '6px',
                          cursor: 'pointer',
                          fontSize: '14px',
                        }}
                      >
                        删除
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 申请管理 */}
        {activeTab === 'applications' && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px' }}>
            <h2 style={{ margin: '0 0 24px 0', fontSize: '20px', fontWeight: 600 }}>收到的申请</h2>

            {loadingApplications ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : applications.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
                暂无申请
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {applications.map((app) => (
                  <div
                    key={app.id}
                    style={{
                      border: '1px solid #e2e8f0',
                      borderRadius: '12px',
                      padding: '20px',
                      background: '#fff',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '12px' }}>
                      <div>
                        <div style={{ fontSize: '18px', fontWeight: 600, color: '#1a202c', marginBottom: '4px' }}>
                          {app.service_name}
                        </div>
                        <div style={{ fontSize: '14px', color: '#718096' }}>
                          申请用户: {app.applicant_name || app.applicant_id}
                        </div>
                      </div>
                      <span
                        style={{
                          padding: '6px 12px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: 600,
                          background: getStatusColor(app.status) + '20',
                          color: getStatusColor(app.status),
                        }}
                      >
                        {getStatusText(app.status)}
                      </span>
                    </div>

                    {app.application_message && (
                      <div style={{ fontSize: '14px', color: '#4a5568', marginBottom: '12px', padding: '12px', background: '#f7fafc', borderRadius: '8px' }}>
                        {app.application_message}
                      </div>
                    )}

                    <div style={{ display: 'flex', gap: '8px', marginBottom: '12px', fontSize: '14px', color: '#718096' }}>
                      {app.negotiated_price && (
                        <span>用户议价: {app.currency || 'GBP'} {app.negotiated_price.toFixed(2)}</span>
                      )}
                      {app.expert_counter_price && (
                        <span>我的议价: {app.currency || 'GBP'} {app.expert_counter_price.toFixed(2)}</span>
                      )}
                      {app.final_price && (
                        <span>最终价格: {app.currency || 'GBP'} {app.final_price.toFixed(2)}</span>
                      )}
                    </div>

                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      {app.status === 'pending' && (
                        <>
                          <button
                            onClick={() => handleApproveApplication(app.id)}
                            style={{
                              padding: '8px 16px',
                              background: '#10b981',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            同意申请
                          </button>
                          <button
                            onClick={() => handleCounterOffer(app)}
                            style={{
                              padding: '8px 16px',
                              background: '#3b82f6',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            再次议价
                          </button>
                          <button
                            onClick={() => {
                              const reason = window.prompt('请输入拒绝原因（可选）');
                              handleRejectApplication(app.id, reason || undefined);
                            }}
                            style={{
                              padding: '8px 16px',
                              background: '#ef4444',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            拒绝申请
                          </button>
                        </>
                      )}
                      {app.status === 'price_agreed' && (
                        <button
                          onClick={() => handleApproveApplication(app.id)}
                          style={{
                            padding: '8px 16px',
                            background: '#10b981',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: 600,
                          }}
                        >
                          创建任务
                        </button>
                      )}
                      {app.status === 'approved' && app.task_id && (
                        <button
                          onClick={() => navigate(`/tasks/${app.task_id}`)}
                          style={{
                            padding: '8px 16px',
                            background: '#3b82f6',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: 600,
                          }}
                        >
                          查看任务
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 多人任务管理 */}
        {activeTab === 'multi-tasks' && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', fontWeight: 600 }}>我的多人任务</h2>
              <button
                onClick={() => {
                  setCreateMultiTaskForm({
                    service_id: undefined,
                    title: '',
                    description: '',
                    max_participants: 1,
                    min_participants: 1,
                    reward_distribution: 'equal',
                    deadline: '',
                    location: 'Online',
                    task_type: 'Skill Service',
                    reward_type: 'cash',
                    base_reward: 0,
                    points_reward: 0,
                    currency: 'GBP',
                    discount_percentage: undefined,
                    custom_discount: undefined,
                    use_custom_discount: false,
                    reward_applicants: false,
                  });
                  setShowCreateMultiTaskModal(true);
                }}
                style={{
                  padding: '10px 20px',
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontWeight: 600,
                }}
              >
                + 创建多人任务
              </button>
            </div>

            {loadingMultiTasks ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : multiTasks.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
                暂无多人任务
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {multiTasks.map((task: any) => {
                  const participants = taskParticipants[task.id] || [];
                  const isTaskManager = task.created_by_expert && task.expert_creator_id === user?.id;
                  
                  return (
                    <div
                      key={task.id}
                      style={{
                        border: '1px solid #e2e8f0',
                        borderRadius: '12px',
                        padding: '20px',
                        background: '#fff',
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '12px' }}>
                        <div style={{ flex: 1 }}>
                          <h3 style={{ margin: '0 0 8px 0', fontSize: '18px', fontWeight: 600, color: '#1a202c' }}>
                            {task.title}
                          </h3>
                          <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', marginBottom: '8px' }}>
                            <span style={{
                              padding: '4px 8px',
                              borderRadius: '6px',
                              fontSize: '12px',
                              fontWeight: 600,
                              background: task.status === 'open' ? '#dbeafe' :
                                         task.status === 'in_progress' ? '#d1fae5' :
                                         task.status === 'completed' ? '#d1fae5' :
                                         '#fee2e2',
                              color: task.status === 'open' ? '#1e40af' :
                                     task.status === 'in_progress' ? '#065f46' :
                                     task.status === 'completed' ? '#065f46' :
                                     '#991b1b',
                            }}>
                              {task.status === 'open' ? '开放中' :
                               task.status === 'in_progress' ? '进行中' :
                               task.status === 'completed' ? '已完成' :
                               '已取消'}
                            </span>
                            <span style={{ fontSize: '14px', color: '#4a5568' }}>
                              👥 {task.current_participants || 0} / {task.max_participants || 1}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* 参与者列表 */}
                      {participants.length > 0 && (
                        <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #e2e8f0' }}>
                          <h4 style={{ margin: '0 0 12px 0', fontSize: '14px', fontWeight: 600, color: '#4a5568' }}>
                            参与者列表 ({participants.length})
                          </h4>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                            {participants.map((participant: any) => (
                              <div
                                key={participant.id}
                                style={{
                                  display: 'flex',
                                  justifyContent: 'space-between',
                                  alignItems: 'center',
                                  padding: '12px',
                                  background: '#f7fafc',
                                  borderRadius: '8px',
                                }}
                              >
                                <div style={{ flex: 1 }}>
                                  <div style={{ fontWeight: 600, color: '#1a202c', marginBottom: '4px' }}>
                                    {participant.user_name || 'Unknown'}
                                  </div>
                                  <div style={{ fontSize: '12px', color: '#718096' }}>
                                    状态: {participant.status === 'pending' ? '待审核' :
                                           participant.status === 'accepted' ? '已接受' :
                                           participant.status === 'in_progress' ? '进行中' :
                                           participant.status === 'completed' ? '已完成' :
                                           participant.status === 'exit_requested' ? '退出申请中' :
                                           '已退出'}
                                  </div>
                                </div>
                                <div style={{ display: 'flex', gap: '8px' }}>
                                  {/* 审核申请 */}
                                  {isTaskManager && participant.status === 'pending' && task.status === 'open' && (
                                    <>
                                      <button
                                        onClick={async () => {
                                          if (!window.confirm('确定要批准这个参与者吗？')) return;
                                          try {
                                            await approveParticipant(task.id, participant.id, false);
                                            message.success('批准成功');
                                            await loadMultiTasks();
                                          } catch (err: any) {
                                            message.error(err.response?.data?.detail || '批准失败');
                                          }
                                        }}
                                        style={{
                                          padding: '6px 12px',
                                          background: '#28a745',
                                          color: '#fff',
                                          border: 'none',
                                          borderRadius: '6px',
                                          cursor: 'pointer',
                                          fontSize: '12px',
                                          fontWeight: 600,
                                        }}
                                      >
                                        批准
                                      </button>
                                      <button
                                        onClick={async () => {
                                          if (!window.confirm('确定要拒绝这个参与者吗？')) return;
                                          try {
                                            await rejectParticipant(task.id, participant.id, false);
                                            message.success('已拒绝');
                                            await loadMultiTasks();
                                          } catch (err: any) {
                                            message.error(err.response?.data?.detail || '操作失败');
                                          }
                                        }}
                                        style={{
                                          padding: '6px 12px',
                                          background: '#dc3545',
                                          color: '#fff',
                                          border: 'none',
                                          borderRadius: '6px',
                                          cursor: 'pointer',
                                          fontSize: '12px',
                                          fontWeight: 600,
                                        }}
                                      >
                                        拒绝
                                      </button>
                                    </>
                                  )}
                                  {/* 处理退出申请 */}
                                  {isTaskManager && participant.status === 'exit_requested' && (
                                    <>
                                      <button
                                        onClick={async () => {
                                          if (!window.confirm('确定要批准退出申请吗？')) return;
                                          try {
                                            await approveExitRequest(task.id, participant.id, false);
                                            message.success('退出申请已批准');
                                            await loadMultiTasks();
                                          } catch (err: any) {
                                            message.error(err.response?.data?.detail || '操作失败');
                                          }
                                        }}
                                        style={{
                                          padding: '6px 12px',
                                          background: '#28a745',
                                          color: '#fff',
                                          border: 'none',
                                          borderRadius: '6px',
                                          cursor: 'pointer',
                                          fontSize: '12px',
                                          fontWeight: 600,
                                        }}
                                      >
                                        批准退出
                                      </button>
                                      <button
                                        onClick={async () => {
                                          if (!window.confirm('确定要拒绝退出申请吗？')) return;
                                          try {
                                            await rejectExitRequest(task.id, participant.id, false);
                                            message.success('退出申请已拒绝');
                                            await loadMultiTasks();
                                          } catch (err: any) {
                                            message.error(err.response?.data?.detail || '操作失败');
                                          }
                                        }}
                                        style={{
                                          padding: '6px 12px',
                                          background: '#dc3545',
                                          color: '#fff',
                                          border: 'none',
                                          borderRadius: '6px',
                                          cursor: 'pointer',
                                          fontSize: '12px',
                                          fontWeight: 600,
                                        }}
                                      >
                                        拒绝退出
                                      </button>
                                    </>
                                  )}
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      )}

                      {/* 操作按钮 */}
                      <div style={{ display: 'flex', gap: '8px', marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #e2e8f0' }}>
                        {isTaskManager && task.status === 'open' && (
                          <button
                            onClick={async () => {
                              if (!window.confirm('确定要开始这个任务吗？')) return;
                              try {
                                await startMultiParticipantTask(task.id, false);
                                message.success('任务已开始');
                                await loadMultiTasks();
                              } catch (err: any) {
                                message.error(err.response?.data?.detail || '开始任务失败');
                              }
                            }}
                            style={{
                              padding: '8px 16px',
                              background: '#007bff',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            🚀 开始任务
                          </button>
                        )}
                        {isTaskManager && task.status === 'completed' && (
                          <button
                            onClick={async () => {
                              if (!window.confirm('确定要分配奖励吗？')) return;
                              try {
                                const idempotencyKey = `${user.id}_${task.id}_distribute_${Date.now()}`;
                                if (task.reward_distribution === 'equal') {
                                  await completeTaskAndDistributeRewardsEqual(task.id, {
                                    idempotency_key: idempotencyKey
                                  });
                                  message.success('奖励已平均分配');
                                } else {
                                  message.info('自定义分配功能需要在管理后台完成');
                                  return;
                                }
                                await loadMultiTasks();
                              } catch (err: any) {
                                message.error(err.response?.data?.detail || '分配奖励失败');
                              }
                            }}
                            style={{
                              padding: '8px 16px',
                              background: '#28a745',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            💰 分配奖励
                          </button>
                        )}
                        <button
                          onClick={() => navigate(`/tasks/${task.id}`)}
                          style={{
                            padding: '8px 16px',
                            background: '#3b82f6',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: 600,
                          }}
                        >
                          查看详情
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </div>

      {/* 创建多人任务弹窗 */}
      {showCreateMultiTaskModal && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowCreateMultiTaskModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              maxWidth: '600px',
              width: '90%',
              maxHeight: '90vh',
              overflow: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>创建多人任务</h3>
              <button
                onClick={() => setShowCreateMultiTaskModal(false)}
                style={{
                  padding: '6px 12px',
                  border: 'none',
                  background: '#dc3545',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer',
                }}
              >
                关闭
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {/* 选择服务（必填） */}
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                  关联服务 <span style={{ color: '#dc3545' }}>*</span>
                </label>
                <select
                  value={createMultiTaskForm.service_id || ''}
                  onChange={(e) => {
                    const selectedService = services.find(s => s.id === parseInt(e.target.value));
                    setCreateMultiTaskForm({
                      ...createMultiTaskForm,
                      service_id: e.target.value ? parseInt(e.target.value) : undefined,
                      title: selectedService ? selectedService.service_name : createMultiTaskForm.title,
                      description: selectedService ? selectedService.description : createMultiTaskForm.description,
                      base_reward: selectedService ? selectedService.base_price : createMultiTaskForm.base_reward,
                      currency: selectedService ? selectedService.currency : createMultiTaskForm.currency,
                      discount_percentage: undefined, // 重置折扣
                      custom_discount: undefined,
                      use_custom_discount: false,
                      // 重置时间段选择
                      selected_time_slot_id: undefined,
                      selected_time_slot_date: undefined,
                      // 如果服务有时间段，限制最大参与者数
                      max_participants: selectedService?.has_time_slots && selectedService?.participants_per_slot 
                        ? Math.min(createMultiTaskForm.max_participants, selectedService.participants_per_slot)
                        : createMultiTaskForm.max_participants,
                    });
                    
                    // 如果服务有时间段，加载时间段列表
                    if (selectedService?.has_time_slots && e.target.value) {
                      loadTimeSlotsForCreateTask(parseInt(e.target.value));
                    } else {
                      setAvailableTimeSlots([]);
                    }
                  }}
                  style={{
                    width: '100%',
                    padding: '10px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '6px',
                    fontSize: '14px',
                  }}
                  required
                >
                  <option value="">请选择服务</option>
                  {services.filter(s => s.status === 'active').map((service) => (
                    <option key={service.id} value={service.id}>
                      {service.service_name} - £{service.base_price.toFixed(2)} {service.currency}
                    </option>
                  ))}
                </select>
                {services.filter(s => s.status === 'active').length === 0 && (
                  <div style={{ marginTop: '8px', color: '#dc3545', fontSize: '12px' }}>
                    您还没有上架的服务，请先创建并上架服务
                  </div>
                )}
              </div>

              {/* 任务标题 */}
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                  任务标题 <span style={{ color: '#dc3545' }}>*</span>
                </label>
                <input
                  type="text"
                  value={createMultiTaskForm.title}
                  onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, title: e.target.value })}
                  style={{
                    width: '100%',
                    padding: '10px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '6px',
                    fontSize: '14px',
                  }}
                  required
                />
              </div>

              {/* 任务描述 */}
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                  任务描述 <span style={{ color: '#dc3545' }}>*</span>
                </label>
                <textarea
                  value={createMultiTaskForm.description}
                  onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, description: e.target.value })}
                  style={{
                    width: '100%',
                    padding: '10px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '6px',
                    fontSize: '14px',
                    minHeight: '100px',
                  }}
                  required
                />
              </div>

              {/* 参与者数量 */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                    最少参与者 <span style={{ color: '#dc3545' }}>*</span>
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={createMultiTaskForm.min_participants}
                    onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, min_participants: parseInt(e.target.value) || 1 })}
                    style={{
                      width: '100%',
                      padding: '10px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                    required
                  />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                    最多参与者 <span style={{ color: '#dc3545' }}>*</span>
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={createMultiTaskForm.max_participants}
                    onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, max_participants: parseInt(e.target.value) || 1 })}
                    style={{
                      width: '100%',
                      padding: '10px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                    required
                  />
                </div>
              </div>

              {/* 截止时间（仅当服务没有时间段时显示） */}
              {!(() => {
                const selectedService = services.find(s => s.id === createMultiTaskForm.service_id);
                return selectedService?.has_time_slots;
              })() && (
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                    截止时间 <span style={{ color: '#dc3545' }}>*</span>
                  </label>
                  <input
                    type="datetime-local"
                    value={createMultiTaskForm.deadline}
                    onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, deadline: e.target.value })}
                    style={{
                      width: '100%',
                      padding: '10px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                    required
                  />
                </div>
              )}

              {/* 时间段选择（仅当服务有时间段时显示） */}
              {(() => {
                const selectedService = services.find(s => s.id === createMultiTaskForm.service_id);
                return selectedService?.has_time_slots;
              })() && (
                <div style={{ marginBottom: '16px' }}>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                    选择时间段 <span style={{ color: '#dc3545' }}>*</span>
                  </label>
                  <div style={{ marginBottom: '12px' }}>
                    <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', color: '#718096' }}>
                      选择日期
                    </label>
                    <input
                      type="date"
                      value={createMultiTaskForm.selected_time_slot_date || ''}
                      onChange={(e) => {
                        const date = e.target.value;
                        setCreateMultiTaskForm({ 
                          ...createMultiTaskForm, 
                          selected_time_slot_date: date,
                          selected_time_slot_id: undefined, // 切换日期时重置时间段选择
                        });
                      }}
                      min={new Date().toISOString().split('T')[0]}
                      style={{
                        width: '100%',
                        padding: '10px',
                        border: '1px solid #e2e8f0',
                        borderRadius: '6px',
                        fontSize: '14px',
                      }}
                      required
                    />
                  </div>
                  
                  {createMultiTaskForm.selected_time_slot_date && (
                    <div>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', color: '#718096' }}>
                        选择时间段
                      </label>
                      {loadingTimeSlots ? (
                        <div style={{ padding: '20px', textAlign: 'center', color: '#718096' }}>
                          加载时间段中...
                        </div>
                      ) : availableTimeSlots.filter((slot: any) => 
                        slot.slot_date === createMultiTaskForm.selected_time_slot_date && slot.is_available
                      ).length === 0 ? (
                        <div style={{ 
                          padding: '20px', 
                          textAlign: 'center', 
                          color: '#e53e3e',
                          background: '#fef2f2',
                          borderRadius: '8px',
                          border: '1px solid #fecaca',
                        }}>
                          该日期暂无可用时间段
                        </div>
                      ) : (
                        <div style={{ 
                          display: 'grid', 
                          gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', 
                          gap: '12px',
                          maxHeight: '200px',
                          overflowY: 'auto',
                        }}>
                          {availableTimeSlots
                            .filter((slot: any) => 
                              slot.slot_date === createMultiTaskForm.selected_time_slot_date && 
                              slot.is_available
                            )
                            .map((slot: any) => {
                              const isFull = slot.current_participants >= slot.max_participants;
                              const isSelected = createMultiTaskForm.selected_time_slot_id === slot.id;
                              const selectedService = services.find(s => s.id === createMultiTaskForm.service_id);
                              
                              return (
                                <button
                                  key={slot.id}
                                  type="button"
                                  onClick={() => !isFull && setCreateMultiTaskForm({ 
                                    ...createMultiTaskForm, 
                                    selected_time_slot_id: slot.id 
                                  })}
                                  disabled={isFull}
                                  style={{
                                    padding: '12px',
                                    border: `2px solid ${isSelected ? '#3b82f6' : isFull ? '#e2e8f0' : '#cbd5e0'}`,
                                    borderRadius: '8px',
                                    background: isSelected ? '#eff6ff' : isFull ? '#f7fafc' : '#fff',
                                    cursor: isFull ? 'not-allowed' : 'pointer',
                                    textAlign: 'left',
                                    transition: 'all 0.2s',
                                    opacity: isFull ? 0.6 : 1,
                                  }}
                                  onMouseEnter={(e) => {
                                    if (!isFull) {
                                      e.currentTarget.style.borderColor = '#3b82f6';
                                      e.currentTarget.style.background = '#eff6ff';
                                    }
                                  }}
                                  onMouseLeave={(e) => {
                                    if (!isSelected) {
                                      e.currentTarget.style.borderColor = isFull ? '#e2e8f0' : '#cbd5e0';
                                      e.currentTarget.style.background = isFull ? '#f7fafc' : '#fff';
                                    }
                                  }}
                                >
                                  <div style={{ fontWeight: 600, color: '#1a202c', marginBottom: '4px', fontSize: '14px' }}>
                                    {slot.start_time.substring(0, 5)} - {slot.end_time.substring(0, 5)}
                                  </div>
                                  <div style={{ fontSize: '12px', color: '#718096', marginBottom: '4px' }}>
                                    {selectedService?.currency || 'GBP'} {slot.price_per_participant.toFixed(2)} / 人
                                  </div>
                                  <div style={{ fontSize: '12px', color: isFull ? '#e53e3e' : '#48bb78' }}>
                                    {isFull ? '已满' : `${slot.current_participants}/${slot.max_participants} 人`}
                                  </div>
                                </button>
                              );
                            })}
                        </div>
                      )}
                    </div>
                  )}
                  <div style={{ 
                    marginTop: '12px', 
                    padding: '12px', 
                    background: '#e0f2fe', 
                    borderRadius: '8px',
                    fontSize: '13px',
                    color: '#0369a1',
                  }}>
                    ℹ️ 多人活动的最大参与者数不能超过所选时间段的最大参与者数
                  </div>
                </div>
              )}

              {/* 位置和类型 */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                    位置
                  </label>
                  <select
                    value={createMultiTaskForm.location}
                    onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, location: e.target.value })}
                    style={{
                      width: '100%',
                      padding: '10px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                  >
                    <option value="Online">Online</option>
                    <option value="London">London</option>
                    <option value="Edinburgh">Edinburgh</option>
                    <option value="Manchester">Manchester</option>
                    <option value="Other">Other</option>
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                    任务类型
                  </label>
                  <select
                    value={createMultiTaskForm.task_type}
                    onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, task_type: e.target.value })}
                    style={{
                      width: '100%',
                      padding: '10px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                  >
                    <option value="Skill Service">Skill Service</option>
                    <option value="Housekeeping">Housekeeping</option>
                    <option value="Campus Life">Campus Life</option>
                    <option value="Other">Other</option>
                  </select>
                </div>
              </div>

              {/* 折扣设置（仅当选择服务时显示） */}
              {createMultiTaskForm.service_id && (
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                    折扣设置（可选）
                  </label>
                  <div style={{ display: 'flex', gap: '8px', marginBottom: '10px', flexWrap: 'wrap' }}>
                    {[10, 15, 20].map((discount) => (
                      <button
                        key={discount}
                        type="button"
                        onClick={() => setCreateMultiTaskForm({
                          ...createMultiTaskForm,
                          discount_percentage: discount,
                          use_custom_discount: false,
                          custom_discount: undefined,
                        })}
                        style={{
                          padding: '8px 16px',
                          border: `1px solid ${createMultiTaskForm.discount_percentage === discount && !createMultiTaskForm.use_custom_discount ? '#3b82f6' : '#e2e8f0'}`,
                          borderRadius: '6px',
                          background: createMultiTaskForm.discount_percentage === discount && !createMultiTaskForm.use_custom_discount ? '#e0f2fe' : '#fff',
                          color: createMultiTaskForm.discount_percentage === discount && !createMultiTaskForm.use_custom_discount ? '#3b82f6' : '#374151',
                          cursor: 'pointer',
                          fontSize: '14px',
                          fontWeight: createMultiTaskForm.discount_percentage === discount && !createMultiTaskForm.use_custom_discount ? 600 : 400,
                        }}
                      >
                        {discount}%
                      </button>
                    ))}
                    <button
                      type="button"
                      onClick={() => setCreateMultiTaskForm({
                        ...createMultiTaskForm,
                        use_custom_discount: true,
                        discount_percentage: undefined,
                      })}
                      style={{
                        padding: '8px 16px',
                        border: `1px solid ${createMultiTaskForm.use_custom_discount ? '#3b82f6' : '#e2e8f0'}`,
                        borderRadius: '6px',
                        background: createMultiTaskForm.use_custom_discount ? '#e0f2fe' : '#fff',
                        color: createMultiTaskForm.use_custom_discount ? '#3b82f6' : '#374151',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: createMultiTaskForm.use_custom_discount ? 600 : 400,
                      }}
                    >
                      自定义
                    </button>
                  </div>
                  {createMultiTaskForm.use_custom_discount && (
                    <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                      <input
                        type="number"
                        min="0"
                        max="100"
                        step="0.1"
                        value={createMultiTaskForm.custom_discount || ''}
                        onChange={(e) => setCreateMultiTaskForm({
                          ...createMultiTaskForm,
                          custom_discount: e.target.value ? parseFloat(e.target.value) : undefined,
                        })}
                        placeholder="输入折扣百分比"
                        style={{
                          flex: 1,
                          padding: '10px',
                          border: '1px solid #e2e8f0',
                          borderRadius: '6px',
                          fontSize: '14px',
                        }}
                      />
                      <span style={{ fontSize: '14px', color: '#718096' }}>%</span>
                    </div>
                  )}
                  {createMultiTaskForm.service_id && (() => {
                    const selectedService = services.find(s => s.id === createMultiTaskForm.service_id);
                    const originalPrice = selectedService?.base_price || 0;
                    const discount = createMultiTaskForm.use_custom_discount 
                      ? (createMultiTaskForm.custom_discount || 0)
                      : (createMultiTaskForm.discount_percentage || 0);
                    const discountedPrice = discount > 0 ? originalPrice * (1 - discount / 100) : originalPrice;
                    return discount > 0 ? (
                      <div style={{ marginTop: '8px', padding: '10px', background: '#f0f9ff', borderRadius: '6px', fontSize: '14px' }}>
                        <div style={{ color: '#374151' }}>
                          原价: <span style={{ textDecoration: 'line-through', color: '#9ca3af' }}>{selectedService?.currency} {originalPrice.toFixed(2)}</span>
                        </div>
                        <div style={{ color: '#059669', fontWeight: 600, marginTop: '4px' }}>
                          折扣价: {selectedService?.currency} {discountedPrice.toFixed(2)} (优惠 {discount}%)
                        </div>
                      </div>
                    ) : null;
                  })()}
                </div>
              )}

              {/* 是否奖励申请者 */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
                <input
                  type="checkbox"
                  id="reward_applicants"
                  checked={createMultiTaskForm.reward_applicants}
                  onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, reward_applicants: e.target.checked })}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <label htmlFor="reward_applicants" style={{ fontSize: '14px', cursor: 'pointer', color: '#374151' }}>
                  奖励申请者（完成任务后给予申请者额外奖励）
                </label>
              </div>

              {/* 奖励设置（仅当勾选"奖励申请者"时显示） */}
              {createMultiTaskForm.reward_applicants && (
                <>
                  {/* 奖励类型 */}
                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                      奖励类型
                    </label>
                    <select
                      value={createMultiTaskForm.reward_type}
                      onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, reward_type: e.target.value as 'cash' | 'points' | 'both' })}
                      style={{
                        width: '100%',
                        padding: '10px',
                        border: '1px solid #e2e8f0',
                        borderRadius: '6px',
                        fontSize: '14px',
                      }}
                    >
                      <option value="cash">现金奖励</option>
                      <option value="points">积分奖励</option>
                      <option value="both">现金+积分</option>
                    </select>
                  </div>

                  {/* 积分奖励设置（当reward_type包含points时显示） */}
                  {(createMultiTaskForm.reward_type === 'points' || createMultiTaskForm.reward_type === 'both') && (
                    <div>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                        积分奖励数量
                      </label>
                      <input
                        type="number"
                        min="0"
                        value={createMultiTaskForm.points_reward}
                        onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, points_reward: parseInt(e.target.value) || 0 })}
                        style={{
                          width: '100%',
                          padding: '10px',
                          border: '1px solid #e2e8f0',
                          borderRadius: '6px',
                          fontSize: '14px',
                        }}
                        placeholder="输入积分数量"
                      />
                    </div>
                  )}

                  {/* 奖励分配方式 */}
                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                      奖励分配方式
                    </label>
                    <select
                      value={createMultiTaskForm.reward_distribution}
                      onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, reward_distribution: e.target.value as 'equal' | 'custom' })}
                      style={{
                        width: '100%',
                        padding: '10px',
                        border: '1px solid #e2e8f0',
                        borderRadius: '6px',
                        fontSize: '14px',
                      }}
                    >
                      <option value="equal">平均分配</option>
                      <option value="custom">自定义分配</option>
                    </select>
                  </div>
                </>
              )}

              {/* 提交按钮 */}
              <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '20px' }}>
                <button
                  onClick={() => setShowCreateMultiTaskModal(false)}
                  style={{
                    padding: '10px 20px',
                    background: '#f3f4f6',
                    color: '#374151',
                    border: 'none',
                    borderRadius: '6px',
                    cursor: 'pointer',
                    fontWeight: 600,
                  }}
                >
                  取消
                </button>
                <button
                  onClick={async () => {
                    if (!createMultiTaskForm.service_id) {
                      message.error('请选择关联服务');
                      return;
                    }
                    if (!createMultiTaskForm.title || !createMultiTaskForm.description) {
                      message.error('请填写完整信息');
                      return;
                    }
                    
                    const selectedService = services.find(s => s.id === createMultiTaskForm.service_id);
                    if (!selectedService) {
                      message.error('服务不存在');
                      return;
                    }
                    
                    // 验证时间段选择（如果服务有时间段）
                    if (selectedService.has_time_slots) {
                      if (!createMultiTaskForm.selected_time_slot_date) {
                        message.error('请选择日期');
                        return;
                      }
                      if (!createMultiTaskForm.selected_time_slot_id) {
                        message.error('请选择时间段');
                        return;
                      }
                      // 验证最大参与者数不能超过时间段的最大参与者数
                      const selectedTimeSlot = availableTimeSlots.find(slot => slot.id === createMultiTaskForm.selected_time_slot_id);
                      if (selectedTimeSlot && createMultiTaskForm.max_participants > selectedTimeSlot.max_participants) {
                        message.error(`最多参与者数不能超过时间段的最大参与者数（${selectedTimeSlot.max_participants}人）`);
                        return;
                      }
                      if (selectedService.participants_per_slot && createMultiTaskForm.max_participants > selectedService.participants_per_slot) {
                        message.error(`最多参与者数不能超过服务的每个时间段最大参与者数（${selectedService.participants_per_slot}人）`);
                        return;
                      }
                    } else {
                      // 如果服务没有时间段，需要选择截至日期
                      if (!createMultiTaskForm.deadline) {
                        message.error('请选择截至日期');
                        return;
                      }
                    }
                    
                    if (createMultiTaskForm.min_participants > createMultiTaskForm.max_participants) {
                      message.error('最少参与者不能大于最多参与者');
                      return;
                    }

                    try {
                      
                      // 检查服务是否有时间段配置（从服务对象或本地状态中获取）
                      const timeSlotConfigFromService = selectedService.has_time_slots 
                        ? {
                            has_time_slots: true,
                            time_slot_duration_minutes: selectedService.time_slot_duration_minutes || 60,
                            time_slot_start_time: selectedService.time_slot_start_time || '09:00',
                            time_slot_end_time: selectedService.time_slot_end_time || '18:00',
                            participants_per_slot: selectedService.participants_per_slot || 1,
                          }
                        : serviceTimeSlotConfigs[selectedService.id] || null;
                      
                      const serviceHasTimeSlots = timeSlotConfigFromService?.has_time_slots || false;
                      const timeSlotConfig = serviceHasTimeSlots && timeSlotConfigFromService ? {
                        is_fixed_time_slot: true,
                        time_slot_duration_minutes: timeSlotConfigFromService.time_slot_duration_minutes,
                        time_slot_start_time: timeSlotConfigFromService.time_slot_start_time + ':00',
                        time_slot_end_time: timeSlotConfigFromService.time_slot_end_time + ':00',
                        participants_per_slot: timeSlotConfigFromService.participants_per_slot,
                      } : {
                        is_fixed_time_slot: false,
                      };
                      
                      // 计算折扣
                      const discount = createMultiTaskForm.use_custom_discount 
                        ? (createMultiTaskForm.custom_discount || 0)
                        : (createMultiTaskForm.discount_percentage || 0);
                      
                      // 计算最终价格
                      const originalPrice = selectedService.base_price;
                      const discountedPrice = discount > 0 ? originalPrice * (1 - discount / 100) : originalPrice;
                      
                      // 构建任务数据
                      const taskData: any = {
                        title: createMultiTaskForm.title,
                        description: createMultiTaskForm.description,
                        location: createMultiTaskForm.location,
                        task_type: createMultiTaskForm.task_type,
                        expert_service_id: createMultiTaskForm.service_id!,
                        max_participants: createMultiTaskForm.max_participants,
                        min_participants: createMultiTaskForm.min_participants,
                        completion_rule: 'all',
                        ...timeSlotConfig,
                      };
                      
                      // 如果服务有时间段，使用时间段信息；否则使用截至日期
                      if (selectedService.has_time_slots && createMultiTaskForm.selected_time_slot_id) {
                        // 使用时间段创建任务，不需要截至日期
                        // 时间段信息已经在 timeSlotConfig 中
                      } else {
                        // 使用截至日期
                        taskData.deadline = new Date(createMultiTaskForm.deadline).toISOString();
                      }
                      
                      // 如果勾选了"奖励申请者"，添加奖励相关字段
                      if (createMultiTaskForm.reward_applicants) {
                        taskData.reward_type = createMultiTaskForm.reward_type;
                        taskData.reward_distribution = createMultiTaskForm.reward_distribution;
                        
                        // 添加价格和折扣信息（如果reward_type包含cash）
                        if (createMultiTaskForm.reward_type !== 'points') {
                          taskData.original_price_per_participant = originalPrice;
                          if (discount > 0) {
                            taskData.discount_percentage = discount;
                            taskData.discounted_price_per_participant = discountedPrice;
                          }
                          taskData.reward = discountedPrice;
                        }
                        
                        // 添加积分奖励（如果reward_type包含points）
                        if (createMultiTaskForm.reward_type === 'points' || createMultiTaskForm.reward_type === 'both') {
                          taskData.points_reward = createMultiTaskForm.points_reward || 0;
                        }
                      } else {
                        // 如果没有勾选"奖励申请者"，使用默认值（商业服务任务，达人收钱）
                        taskData.reward_type = 'cash';
                        taskData.original_price_per_participant = originalPrice;
                        if (discount > 0) {
                          taskData.discount_percentage = discount;
                          taskData.discounted_price_per_participant = discountedPrice;
                        }
                        taskData.reward = discountedPrice;
                        taskData.reward_distribution = 'equal';
                      }
                      
                      await createExpertMultiParticipantTask(taskData);
                      message.success('多人任务创建成功');
                      setShowCreateMultiTaskModal(false);
                      await loadMultiTasks();
                      await loadRecentActivities(); // 刷新最近活动
                    } catch (err: any) {
                      message.error(err.response?.data?.detail || '创建失败');
                    }
                  }}
                  style={{
                    padding: '10px 20px',
                    background: '#3b82f6',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '6px',
                    cursor: 'pointer',
                    fontWeight: 600,
                  }}
                >
                  创建
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 服务编辑弹窗 */}
      {showServiceModal && (
        <ServiceEditModal
          setServiceTimeSlotConfigs={setServiceTimeSlotConfigs}
          service={editingService}
          onClose={() => {
            setShowServiceModal(false);
            setEditingService(null);
          }}
          onSuccess={async () => {
            setShowServiceModal(false);
            setEditingService(null);
            await loadServices(); // 重新加载服务列表以获取最新的时间段信息
          }}
        />
      )}

      {/* 议价弹窗 */}
      {showCounterOfferModal && selectedApplication && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowCounterOfferModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              maxWidth: '500px',
              width: '100%',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '18px', fontWeight: 600 }}>
              再次议价
            </h3>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                议价价格 ({selectedApplication.currency || 'GBP'})
              </label>
              <input
                type="number"
                value={counterPrice || ''}
                onChange={(e) => setCounterPrice(parseFloat(e.target.value) || undefined)}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                }}
              />
            </div>
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                说明（可选）
              </label>
              <textarea
                value={counterMessage}
                onChange={(e) => setCounterMessage(e.target.value)}
                style={{
                  width: '100%',
                  minHeight: '80px',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                  resize: 'vertical',
                }}
              />
            </div>
            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={handleSubmitCounterOffer}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                提交
              </button>
              <button
                onClick={() => setShowCounterOfferModal(false)}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#f3f4f6',
                  color: '#333',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          loadData();
        }}
      />
      
      {/* 编辑资料弹窗 */}
      {showProfileEditModal && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowProfileEditModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              width: '90%',
              maxWidth: '500px',
              maxHeight: '90vh',
              overflow: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h2 style={{ margin: '0 0 20px 0', fontSize: '20px', fontWeight: 600 }}>编辑资料</h2>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                名字
              </label>
              <input
                type="text"
                value={profileForm.expert_name}
                onChange={(e) => setProfileForm({ ...profileForm, expert_name: e.target.value })}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                }}
                placeholder="请输入您的名字"
              />
            </div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                简介
              </label>
              <textarea
                value={profileForm.bio}
                onChange={(e) => setProfileForm({ ...profileForm, bio: e.target.value })}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                  minHeight: '100px',
                  resize: 'vertical',
                }}
                placeholder="请输入您的简介"
              />
            </div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                头像
              </label>
              {avatarPreview && (
                <div style={{ marginBottom: '12px' }}>
                  <img
                    src={avatarPreview}
                    alt="头像预览"
                    style={{
                      width: '100px',
                      height: '100px',
                      objectFit: 'cover',
                      borderRadius: '50%',
                      border: '1px solid #e2e8f0',
                    }}
                  />
                </div>
              )}
              <input
                type="file"
                accept="image/*"
                onChange={handleAvatarChange}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                }}
              />
              <div style={{ marginTop: '8px', fontSize: '12px', color: '#718096' }}>
                支持 JPG、PNG 格式，文件大小不超过 5MB
              </div>
            </div>
            <div style={{ marginTop: '20px', padding: '12px', background: '#fef3c7', borderRadius: '6px', fontSize: '14px', color: '#92400e' }}>
              注意：修改信息需要管理员审核，审核通过后才会生效
            </div>
            <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
              <button
                onClick={() => setShowProfileEditModal(false)}
                style={{
                  flex: 1,
                  padding: '12px',
                  background: '#f3f4f6',
                  color: '#333',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                取消
              </button>
              <button
                onClick={handleSubmitProfileUpdate}
                style={{
                  flex: 1,
                  padding: '12px',
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                提交审核
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// 服务编辑弹窗组件
interface ServiceEditModalProps {
  service: Service | null;
  onClose: () => void;
  onSuccess: () => void;
  setServiceTimeSlotConfigs?: React.Dispatch<React.SetStateAction<{[key: number]: {
    has_time_slots: boolean;
    time_slot_duration_minutes: number;
    time_slot_start_time: string;
    time_slot_end_time: string;
    participants_per_slot: number;
  }}>>;
}

const ServiceEditModal: React.FC<ServiceEditModalProps> = ({ service, onClose, onSuccess, setServiceTimeSlotConfigs }) => {
  const [formData, setFormData] = useState({
    service_name: '',
    description: '',
    base_price: 0,
    currency: 'GBP',
    status: 'active',
    images: [] as string[],
    // 时间段相关字段（可选）
    has_time_slots: false,
    time_slot_duration_minutes: 60,
    time_slot_start_time: '09:00',
    time_slot_end_time: '18:00',
    participants_per_slot: 1,
  });
  const [saving, setSaving] = useState(false);
  const [uploadingImages, setUploadingImages] = useState<boolean[]>([]);
  const [currentUser, setCurrentUser] = useState<any>(null);

  useEffect(() => {
    if (service) {
      // 从服务对象中获取时间段信息（后端已支持）
      const hasTimeSlots = service.has_time_slots || false;
      const timeSlotDuration = service.time_slot_duration_minutes || 60;
      // 后端返回的时间格式可能是 "HH:MM:SS"，需要转换为 "HH:MM" 用于 input[type="time"]
      const timeSlotStart = service.time_slot_start_time 
        ? service.time_slot_start_time.substring(0, 5) 
        : '09:00';
      const timeSlotEnd = service.time_slot_end_time 
        ? service.time_slot_end_time.substring(0, 5) 
        : '18:00';
      const participantsPerSlot = service.participants_per_slot || 1;
      
      setFormData({
        service_name: service.service_name,
        description: service.description || '',
        base_price: service.base_price,
        currency: service.currency,
        status: service.status,
        images: service.images || [],
        has_time_slots: hasTimeSlots,
        time_slot_duration_minutes: timeSlotDuration,
        time_slot_start_time: timeSlotStart,
        time_slot_end_time: timeSlotEnd,
        participants_per_slot: participantsPerSlot,
      });
    } else {
      // 新建服务时重置时间段字段
      setFormData({
        service_name: '',
        description: '',
        base_price: 0,
        currency: 'GBP',
        status: 'active',
        images: [],
        has_time_slots: false,
        time_slot_duration_minutes: 60,
        time_slot_start_time: '09:00',
        time_slot_end_time: '18:00',
        participants_per_slot: 1,
      });
    }
  }, [service]);

  // 加载当前用户信息（用于获取expert_id）
  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setCurrentUser(userData);
      } catch (err) {
        console.error('加载用户信息失败:', err);
      }
    };
    loadUser();
  }, []);

  const handleSubmit = async () => {
    if (!formData.service_name || !formData.description || formData.base_price <= 0) {
      message.warning('请填写完整信息');
      return;
    }
    
    // 验证时间段设置
    if (formData.has_time_slots) {
      if (!formData.time_slot_start_time || !formData.time_slot_end_time) {
        message.warning('请设置时间段的开始和结束时间');
        return;
      }
      if (formData.time_slot_duration_minutes <= 0) {
        message.warning('时间段时长必须大于0');
        return;
      }
      if (formData.participants_per_slot <= 0) {
        message.warning('每个时间段的参与者数量必须大于0');
        return;
      }
      
      // 验证开始时间早于结束时间
      const startTime = formData.time_slot_start_time.split(':').map(Number);
      const endTime = formData.time_slot_end_time.split(':').map(Number);
      const startMinutes = startTime[0] * 60 + startTime[1];
      const endMinutes = endTime[0] * 60 + endTime[1];
      if (startMinutes >= endMinutes) {
        message.warning('开始时间必须早于结束时间');
        return;
      }
    }

    setSaving(true);
    try {
      // 准备提交数据（后端已支持时间段字段）
      const submitData: any = {
        service_name: formData.service_name,
        description: formData.description,
        base_price: formData.base_price,
        currency: formData.currency,
        status: formData.status,
        images: formData.images,
      };
      
      // 添加时间段信息（如果启用）
      if (formData.has_time_slots) {
        submitData.has_time_slots = true;
        submitData.time_slot_duration_minutes = formData.time_slot_duration_minutes;
        // 将时间格式转换为 "HH:MM:SS"
        submitData.time_slot_start_time = formData.time_slot_start_time + ':00';
        submitData.time_slot_end_time = formData.time_slot_end_time + ':00';
        submitData.participants_per_slot = formData.participants_per_slot;
      } else {
        submitData.has_time_slots = false;
      }
      
      let savedServiceId: number;
      if (service) {
        await updateTaskExpertService(service.id, submitData);
        savedServiceId = service.id;
        message.success('服务已更新');
      } else {
        const result = await createTaskExpertService(submitData);
        savedServiceId = result.id || result.service?.id;
        message.success('服务已创建');
      }
      
      // 更新本地状态中的时间段配置（用于创建多人任务时快速获取）
      if (setServiceTimeSlotConfigs) {
        if (formData.has_time_slots && savedServiceId) {
          setServiceTimeSlotConfigs((prev: {[key: number]: {
            has_time_slots: boolean;
            time_slot_duration_minutes: number;
            time_slot_start_time: string;
            time_slot_end_time: string;
            participants_per_slot: number;
          }}) => ({
            ...prev,
            [savedServiceId]: {
              has_time_slots: true,
              time_slot_duration_minutes: formData.time_slot_duration_minutes,
              time_slot_start_time: formData.time_slot_start_time,
              time_slot_end_time: formData.time_slot_end_time,
              participants_per_slot: formData.participants_per_slot,
            }
          }));
        } else if (savedServiceId) {
          // 如果取消时间段，清除配置
          setServiceTimeSlotConfigs((prev: {[key: number]: {
            has_time_slots: boolean;
            time_slot_duration_minutes: number;
            time_slot_start_time: string;
            time_slot_end_time: string;
            participants_per_slot: number;
          }}) => {
            const newConfigs = { ...prev };
            delete newConfigs[savedServiceId];
            return newConfigs;
          });
        }
      }
      
      onSuccess();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '保存失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        background: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: '#fff',
          borderRadius: '12px',
          padding: '24px',
          maxWidth: '600px',
          width: '100%',
          maxHeight: '90vh',
          overflowY: 'auto',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
          <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>
            {service ? '编辑服务' : '创建服务'}
          </h3>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#666',
            }}
          >
            ×
          </button>
        </div>

        <div style={{ marginBottom: '16px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            服务名称 *
          </label>
          <input
            type="text"
            value={formData.service_name}
            onChange={(e) => setFormData({ ...formData, service_name: e.target.value })}
            style={{
              width: '100%',
              padding: '10px',
              border: '1px solid #e2e8f0',
              borderRadius: '6px',
              fontSize: '14px',
            }}
          />
        </div>

        <div style={{ marginBottom: '16px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            服务描述 *
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            style={{
              width: '100%',
              minHeight: '120px',
              padding: '10px',
              border: '1px solid #e2e8f0',
              borderRadius: '6px',
              fontSize: '14px',
              resize: 'vertical',
            }}
          />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
              基础价格 *
            </label>
            <input
              type="number"
              value={formData.base_price}
              onChange={(e) => setFormData({ ...formData, base_price: parseFloat(e.target.value) || 0 })}
              min="0"
              step="0.01"
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #e2e8f0',
                borderRadius: '6px',
                fontSize: '14px',
              }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
              货币
            </label>
            <select
              value={formData.currency}
              onChange={(e) => setFormData({ ...formData, currency: e.target.value })}
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #e2e8f0',
                borderRadius: '6px',
                fontSize: '14px',
              }}
            >
              <option value="GBP">GBP</option>
              <option value="USD">USD</option>
              <option value="EUR">EUR</option>
            </select>
          </div>
        </div>

        <div style={{ marginBottom: '16px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            服务图片（最多5张）
          </label>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px', marginBottom: '12px' }}>
            {formData.images.map((imageUrl, index) => (
              <div key={index} style={{ position: 'relative', width: '100px', height: '100px' }}>
                <img
                  src={imageUrl}
                  alt={`服务图片 ${index + 1}`}
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                    borderRadius: '8px',
                    border: '1px solid #e2e8f0',
                  }}
                />
                <button
                  onClick={() => {
                    const newImages = formData.images.filter((_, i) => i !== index);
                    setFormData({ ...formData, images: newImages });
                  }}
                  style={{
                    position: 'absolute',
                    top: '-8px',
                    right: '-8px',
                    background: '#ef4444',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '50%',
                    width: '24px',
                    height: '24px',
                    cursor: 'pointer',
                    fontSize: '14px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  ×
                </button>
              </div>
            ))}
            {formData.images.length < 5 && (
              <label
                style={{
                  width: '100px',
                  height: '100px',
                  border: '2px dashed #cbd5e0',
                  borderRadius: '8px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  background: '#f7fafc',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.borderColor = '#3b82f6';
                  e.currentTarget.style.background = '#eff6ff';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.borderColor = '#cbd5e0';
                  e.currentTarget.style.background = '#f7fafc';
                }}
              >
                <input
                  type="file"
                  accept="image/*"
                  style={{ display: 'none' }}
                  onChange={async (e) => {
                    const file = e.target.files?.[0];
                    if (!file) return;
                    
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
                    
                    const imageIndex = formData.images.length;
                    setUploadingImages(prev => [...prev, true]);
                    
                    try {
                      const formDataUpload = new FormData();
                      formDataUpload.append('image', file);
                      
                      // 服务图片上传：传递expert_id（任务达人ID）作为resource_id
                      // 因为服务图片属于任务达人，应该按任务达人ID分类
                      // 任务达人ID等于用户ID
                      const expertId = currentUser?.id;
                      const uploadUrl = expertId 
                        ? `/api/upload/public-image?category=service_image&resource_id=${expertId}`
                        : '/api/upload/public-image?category=service_image';
                      
                      const response = await api.post(uploadUrl, formDataUpload, {
                        headers: {
                          'Content-Type': 'multipart/form-data',
                        },
                      });
                      
                      if (response.data.success && response.data.url) {
                        setFormData({
                          ...formData,
                          images: [...formData.images, response.data.url],
                        });
                        message.success('图片上传成功');
                      } else {
                        message.error('图片上传失败，请重试');
                      }
                    } catch (error: any) {
                      console.error('图片上传失败:', error);
                      message.error(error.response?.data?.detail || '图片上传失败，请重试');
                    } finally {
                      setUploadingImages(prev => prev.filter((_, i) => i !== imageIndex));
                      e.target.value = '';
                    }
                  }}
                />
                <div style={{ textAlign: 'center', color: '#64748b' }}>
                  <div style={{ fontSize: '24px', marginBottom: '4px' }}>📷</div>
                  <div style={{ fontSize: '12px' }}>添加图片</div>
                </div>
              </label>
            )}
          </div>
          {formData.images.length > 0 && (
            <div style={{ fontSize: '12px', color: '#718096' }}>
              已上传 {formData.images.length} 张图片
            </div>
          )}
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            状态
          </label>
          <select
            value={formData.status}
            onChange={(e) => setFormData({ ...formData, status: e.target.value })}
            style={{
              width: '100%',
              padding: '10px',
              border: '1px solid #e2e8f0',
              borderRadius: '6px',
              fontSize: '14px',
            }}
          >
            <option value="active">上架</option>
            <option value="inactive">下架</option>
          </select>
        </div>

        {/* 时间段设置 */}
        <div style={{ marginBottom: '20px', padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#f9fafb' }}>
          <div style={{ display: 'flex', alignItems: 'center', marginBottom: '12px' }}>
            <input
              type="checkbox"
              id="has_time_slots"
              checked={formData.has_time_slots}
              onChange={(e) => setFormData({ ...formData, has_time_slots: e.target.checked })}
              style={{ width: '18px', height: '18px', cursor: 'pointer', marginRight: '8px' }}
            />
            <label htmlFor="has_time_slots" style={{ fontSize: '14px', fontWeight: 500, cursor: 'pointer' }}>
              启用时间段功能
            </label>
          </div>
          
          {formData.has_time_slots && (
            <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #e2e8f0' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '12px' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                    开始时间
                  </label>
                  <input
                    type="time"
                    value={formData.time_slot_start_time}
                    onChange={(e) => setFormData({ ...formData, time_slot_start_time: e.target.value })}
                    style={{
                      width: '100%',
                      padding: '8px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                    结束时间
                  </label>
                  <input
                    type="time"
                    value={formData.time_slot_end_time}
                    onChange={(e) => setFormData({ ...formData, time_slot_end_time: e.target.value })}
                    style={{
                      width: '100%',
                      padding: '8px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                  />
                </div>
              </div>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '12px' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                    时间段时长（分钟）
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={formData.time_slot_duration_minutes}
                    onChange={(e) => setFormData({ ...formData, time_slot_duration_minutes: parseInt(e.target.value) || 60 })}
                    style={{
                      width: '100%',
                      padding: '8px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                    placeholder="60"
                  />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                    每个时间段最多参与者
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={formData.participants_per_slot}
                    onChange={(e) => setFormData({ ...formData, participants_per_slot: parseInt(e.target.value) || 1 })}
                    style={{
                      width: '100%',
                      padding: '8px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                    }}
                    placeholder="1"
                  />
                </div>
              </div>
              
              <div style={{ fontSize: '12px', color: '#718096', marginTop: '8px' }}>
                💡 提示：启用时间段后，用户申请此服务时需要选择具体的日期和时间段。您可以在服务创建后批量创建时间段。
              </div>
            </div>
          )}
        </div>

        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            onClick={handleSubmit}
            disabled={saving}
            style={{
              flex: 1,
              padding: '12px',
              background: saving ? '#cbd5e0' : '#3b82f6',
              color: '#fff',
              border: 'none',
              borderRadius: '6px',
              cursor: saving ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: 600,
            }}
          >
            {saving ? '保存中...' : '保存'}
          </button>
          <button
            onClick={onClose}
            style={{
              flex: 1,
              padding: '12px',
              background: '#f3f4f6',
              color: '#333',
              border: 'none',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: 600,
            }}
          >
            取消
          </button>
        </div>
      </div>
    </div>
  );
};

export default TaskExpertDashboard;

