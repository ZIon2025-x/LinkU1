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
import { TimeHandlerV2 } from '../utils/timeUtils';
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
  getServiceTimeSlots,
  getServiceTimeSlotsPublic,
  batchCreateServiceTimeSlots,
  deleteTimeSlotsByDate,
  getExpertDashboardStats,
  getExpertSchedule,
  deleteServiceTimeSlot,
  createClosedDate,
  getClosedDates,
  deleteClosedDate,
  deleteClosedDateByDate,
  deleteActivity,
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
  weekly_time_slot_config?: { [key: string]: { enabled: boolean; start_time: string; end_time: string } };
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
  const [activeTab, setActiveTab] = useState<'dashboard' | 'services' | 'applications' | 'multi-tasks' | 'schedule'>('dashboard');
  
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
  
  // 多人活动管理相关
  const [multiTasks, setMultiTasks] = useState<any[]>([]);
  const [loadingMultiTasks, setLoadingMultiTasks] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);
  // 按活动ID和任务ID分组存储参与者：{activityId: {taskId: [participants]}}
  const [taskParticipants, setTaskParticipants] = useState<{[activityId: number]: {[taskId: number]: any[]}}>({});
  // 存储活动关联的任务列表：{activityId: [tasks]}
  const [activityTasks, setActivityTasks] = useState<{[activityId: number]: any[]}>({});
  
  // 创建多人活动相关
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
    // 时间段选择相关
    time_slot_selection_mode?: 'fixed' | 'recurring_daily' | 'recurring_weekly';
    selected_time_slot_ids?: number[];
    recurring_daily_time_ranges?: Array<{start: string, end: string}>;
    recurring_weekly_weekdays?: number[];
    recurring_weekly_time_ranges?: Array<{start: string, end: string}>;
    auto_add_new_slots: boolean;
    activity_end_date?: string;
    // 向后兼容的旧字段
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
    time_slot_selection_mode: undefined,
    selected_time_slot_ids: [],
    recurring_daily_time_ranges: [],
    recurring_weekly_weekdays: [],
    recurring_weekly_time_ranges: [],
    auto_add_new_slots: true,
    activity_end_date: undefined,
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
  
  // 时间段相关状态（用于创建多人活动）
  const [availableTimeSlots, setAvailableTimeSlots] = useState<any[]>([]);
  const [loadingTimeSlots, setLoadingTimeSlots] = useState(false);
  
  // 时间段管理相关状态
  const [showTimeSlotManagement, setShowTimeSlotManagement] = useState(false);
  const [selectedServiceForTimeSlot, setSelectedServiceForTimeSlot] = useState<Service | null>(null);
  const [timeSlotManagementSlots, setTimeSlotManagementSlots] = useState<any[]>([]);
  const [loadingTimeSlotManagement, setLoadingTimeSlotManagement] = useState(false);
  const [timeSlotManagementDate, setTimeSlotManagementDate] = useState<string>('');
  
  // 仪表盘相关状态
  const [dashboardStats, setDashboardStats] = useState<any>(null);
  const [loadingDashboardStats, setLoadingDashboardStats] = useState(false);
  
  // 时刻表相关状态
  const [scheduleData, setScheduleData] = useState<any>(null);
  const [loadingSchedule, setLoadingSchedule] = useState(false);
  const [scheduleStartDate, setScheduleStartDate] = useState<string>('');
  const [scheduleEndDate, setScheduleEndDate] = useState<string>('');
  const [closedDates, setClosedDates] = useState<any[]>([]);
  const [showCloseDateModal, setShowCloseDateModal] = useState(false);
  const [selectedDateForClose, setSelectedDateForClose] = useState<string>('');
  const [closeDateReason, setCloseDateReason] = useState<string>('');
  
  // 加载时间段列表（用于创建多人活动）
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
      console.log('请求时间段参数:', params); // 调试日志
      // 任务达人创建活动时，使用认证接口（需要登录）
      const slots = await getServiceTimeSlots(serviceId, params);
      console.log('加载的时间段数据:', slots); // 调试日志
      console.log('时间段数量:', Array.isArray(slots) ? slots.length : 0); // 调试日志
      const slotsArray = Array.isArray(slots) ? slots : [];
      
      // 分析时间段的日期分布
      const dateDistribution: { [key: string]: number } = {};
      slotsArray.forEach((s: any) => {
        const slotStartStr = s.slot_start_datetime || (s.slot_date + 'T' + s.start_time + 'Z');
        try {
          let slotDateUK = TimeHandlerV2.formatUtcToLocal(slotStartStr, 'YYYY-MM-DD', 'Europe/London');
          // 去掉时区后缀 (GMT) 或 (BST)
          if (slotDateUK.includes(' (GMT)') || slotDateUK.includes(' (BST)')) {
            slotDateUK = slotDateUK.replace(' (GMT)', '').replace(' (BST)', '');
          }
          dateDistribution[slotDateUK] = (dateDistribution[slotDateUK] || 0) + 1;
        } catch (e) {
          const dateKey = s.slot_date || 'unknown';
          dateDistribution[dateKey] = (dateDistribution[dateKey] || 0) + 1;
        }
      });
      
      console.log('时间段详情:', slotsArray.map((s: any) => ({
        id: s.id,
        slot_start_datetime: s.slot_start_datetime,
        slot_end_datetime: s.slot_end_datetime,
        slot_date: s.slot_date,
        start_time: s.start_time,
        end_time: s.end_time,
        converted_date_uk: (() => {
          const slotStartStr = s.slot_start_datetime || (s.slot_date + 'T' + s.start_time + 'Z');
          try {
            return TimeHandlerV2.formatUtcToLocal(slotStartStr, 'YYYY-MM-DD', 'Europe/London');
          } catch {
            return s.slot_date;
          }
        })(),
        is_available: s.is_available,
        is_expired: s.is_expired,
        current_participants: s.current_participants,
        max_participants: s.max_participants,
      }))); // 调试日志
      
      console.log('时间段日期分布:', dateDistribution);
      console.log('时间段日期范围:', {
        min_date: Object.keys(dateDistribution).sort()[0],
        max_date: Object.keys(dateDistribution).sort().slice(-1)[0],
        total_dates: Object.keys(dateDistribution).length,
        total_slots: slotsArray.length
      });
      
      setAvailableTimeSlots(slotsArray);
    } catch (err: any) {
      console.error('加载时间段失败:', err);
      console.error('错误详情:', err.response?.data); // 调试日志
      message.error('加载时间段失败');
      setAvailableTimeSlots([]);
    } finally {
      setLoadingTimeSlots(false);
    }
  };

  useEffect(() => {
    loadData();
    loadPendingRequest();
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
    } else if (activeTab === 'dashboard') {
      loadDashboardStats();
    } else if (activeTab === 'multi-tasks') {
      loadMultiTasks();
    }
    // schedule 标签页的加载由下面的 useEffect 处理，避免重复调用
  }, [activeTab, user]);

  // 时刻表页面定时刷新（每10秒刷新一次，确保参与者数量实时更新）
  useEffect(() => {
    if (activeTab === 'schedule' && user) {
      // 立即加载一次
      loadSchedule();
      
      // 每10秒刷新一次
      const interval = setInterval(() => {
        if (!document.hidden) {
          loadSchedule();
        }
      }, 10000); // 10秒
      
      return () => clearInterval(interval);
    }
  }, [activeTab, user]);

  // 当打开创建多人活动模态框时，确保服务列表已加载
  useEffect(() => {
    if (showCreateMultiTaskModal && services.length === 0 && !loadingServices) {
      console.log('打开创建多人活动模态框，但服务列表为空，开始加载服务列表...');
      loadServices();
    }
  }, [showCreateMultiTaskModal]);

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

  const loadDashboardStats = async () => {
    setLoadingDashboardStats(true);
    try {
      const stats = await getExpertDashboardStats();
      setDashboardStats(stats);
    } catch (err: any) {
      console.error('加载仪表盘数据失败:', err);
      message.error('加载仪表盘数据失败');
    } finally {
      setLoadingDashboardStats(false);
    }
  };

  const loadSchedule = async () => {
    setLoadingSchedule(true);
    try {
      const today = new Date();
      const futureDate = new Date(today);
      futureDate.setDate(today.getDate() + 30);
      
      const startDate = scheduleStartDate || today.toISOString().split('T')[0];
      const endDate = scheduleEndDate || futureDate.toISOString().split('T')[0];
      
      // 更新状态中的日期（如果还没有设置）
      if (!scheduleStartDate) {
        setScheduleStartDate(startDate);
      }
      if (!scheduleEndDate) {
        setScheduleEndDate(endDate);
      }
      
      // 分别处理两个请求，避免一个失败导致全部失败
      try {
        const scheduleDataResult = await getExpertSchedule({ start_date: startDate, end_date: endDate });
        setScheduleData(scheduleDataResult);
      } catch (err: any) {
        console.error('加载时刻表数据失败:', err);
        message.error('加载时刻表数据失败');
        setScheduleData(null);
      }
      
      try {
        const closedDatesResult = await getClosedDates({ start_date: startDate, end_date: endDate });
        setClosedDates(Array.isArray(closedDatesResult) ? closedDatesResult : []);
      } catch (err: any) {
        console.error('加载关门日期失败:', err);
        // 关门日期加载失败不影响时刻表显示，只记录错误
        setClosedDates([]);
      }
    } catch (err: any) {
      console.error('加载时刻表失败:', err);
      message.error('加载时刻表失败');
    } finally {
      setLoadingSchedule(false);
    }
  };

  const loadServices = async () => {
    setLoadingServices(true);
    try {
      // 获取所有服务（包括active和inactive），但在创建任务时只显示active的
      const data = await getMyTaskExpertServices();
      console.log('服务列表API返回数据:', data);
      // API返回的数据结构可能是 { items: [...] } 或直接是数组
      const servicesList = Array.isArray(data) ? data : (data.items || []);
      console.log('解析后的服务列表:', servicesList);
      console.log('active服务数量:', servicesList.filter((s: any) => s.status === 'active').length);
      
      // 从后端返回的服务数据中提取时间段信息
      // 后端直接返回 has_time_slots 等字段，不需要嵌套在 time_slot_config 中
      const servicesWithTimeSlots = servicesList.map((service: any) => {
        // 后端直接返回时间段相关字段
        const hasTimeSlots = service.has_time_slots || false;
        const timeSlotDuration = service.time_slot_duration_minutes || 60;
        const timeSlotStart = service.time_slot_start_time || '09:00';
        const timeSlotEnd = service.time_slot_end_time || '18:00';
        const participantsPerSlot = service.participants_per_slot || 1;
        const weeklyConfig = service.weekly_time_slot_config || null;
        
        // 如果服务有时间段配置，保存到本地状态（用于快速访问）
        if (hasTimeSlots) {
          const config = {
            has_time_slots: hasTimeSlots,
            time_slot_duration_minutes: timeSlotDuration,
            time_slot_start_time: timeSlotStart,
            time_slot_end_time: timeSlotEnd,
            participants_per_slot: participantsPerSlot,
          };
          setServiceTimeSlotConfigs(prev => ({
            ...prev,
            [service.id]: config
          }));
        }
        
        // 返回包含时间段信息的服务对象
        return {
          ...service,
          has_time_slots: hasTimeSlots,
          time_slot_duration_minutes: timeSlotDuration,
          time_slot_start_time: timeSlotStart,
          time_slot_end_time: timeSlotEnd,
          participants_per_slot: participantsPerSlot,
          weekly_time_slot_config: weeklyConfig,
        };
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

  const handleManageTimeSlots = async (service: Service) => {
    setSelectedServiceForTimeSlot(service);
    setShowTimeSlotManagement(true);
    // 加载该服务的所有时间段（未来30天）
    await loadTimeSlotManagement(service.id);
  };

  const loadTimeSlotManagement = async (serviceId: number) => {
    setLoadingTimeSlotManagement(true);
    try {
      const today = new Date();
      const futureDate = new Date(today);
      futureDate.setDate(today.getDate() + 30);
      const params = {
        start_date: today.toISOString().split('T')[0],
        end_date: futureDate.toISOString().split('T')[0],
      };
      const slots = await getServiceTimeSlotsPublic(serviceId, params);
      const slotsArray = Array.isArray(slots) ? slots : [];
      // 按日期分组
      const groupedByDate: { [date: string]: any[] } = {};
      slotsArray.forEach((slot: any) => {
        const slotStartStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
        const slotDateUK = TimeHandlerV2.formatUtcToLocal(
          slotStartStr.includes('T') ? slotStartStr : `${slotStartStr}T00:00:00Z`,
          'YYYY-MM-DD',
          'Europe/London'
        );
        if (!groupedByDate[slotDateUK]) {
          groupedByDate[slotDateUK] = [];
        }
        groupedByDate[slotDateUK].push(slot);
      });
      setTimeSlotManagementSlots(slotsArray);
    } catch (err: any) {
      console.error('加载时间段失败:', err);
      message.error('加载时间段失败');
      setTimeSlotManagementSlots([]);
    } finally {
      setLoadingTimeSlotManagement(false);
    }
  };

  const handleDeleteTimeSlotsByDate = async (serviceId: number, targetDate: string) => {
    try {
      await deleteTimeSlotsByDate(serviceId, targetDate);
      message.success(`已删除 ${targetDate} 的所有时间段`);
      // 重新加载时间段
      await loadTimeSlotManagement(serviceId);
    } catch (err: any) {
      message.error(err.response?.data?.detail || '删除失败');
    }
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


  // 加载多人任务列表
  const loadMultiTasks = async () => {
    if (!user) {
      console.log('loadMultiTasks: 用户未加载，跳过');
      return;
    }
    console.log('loadMultiTasks: 开始加载多人活动，用户ID:', user.id);
    setLoadingMultiTasks(true);
    try {
      // 获取任务达人创建的所有活动
      const response = await api.get('/api/activities', {
        params: {
          expert_id: user.id,
          limit: 100
        }
      });
      const activities = response.data || [];
      console.log('loadMultiTasks: 加载到', activities.length, '个活动', activities);
      setMultiTasks(activities);
      
      // 并行加载所有活动关联的任务的参与者列表（按任务分组）
      const participantsMap: {[activityId: number]: {[taskId: number]: any[]}} = {};
      const tasksMap: {[activityId: number]: any[]} = {};
      
        await Promise.all(
        activities.map(async (activity: any) => {
          try {
            // 查找关联的任务（获取所有状态的任务，不限制status）
            const tasksResponse = await api.get('/api/tasks', {
              params: {
                parent_activity_id: activity.id,
                limit: 100,
                status: 'all'  // 获取所有状态的任务
              }
            });
            console.log(`活动 ${activity.id} 的任务响应:`, tasksResponse.data);
            
            // 处理不同的返回格式
            let relatedTasks = [];
            if (tasksResponse.data) {
              if (Array.isArray(tasksResponse.data)) {
                relatedTasks = tasksResponse.data;
              } else if (tasksResponse.data.tasks && Array.isArray(tasksResponse.data.tasks)) {
                relatedTasks = tasksResponse.data.tasks;
              } else if (tasksResponse.data.data && Array.isArray(tasksResponse.data.data)) {
                relatedTasks = tasksResponse.data.data;
              }
            }
            
            console.log(`活动 ${activity.id} 的关联任务数量:`, relatedTasks.length, relatedTasks);
            tasksMap[activity.id] = relatedTasks;
            
            // 为每个任务加载参与者（按任务分组）
            if (!participantsMap[activity.id]) {
              participantsMap[activity.id] = {};
            }
            
            for (const task of relatedTasks) {
              try {
                const participantsData = await getTaskParticipants(task.id);
                participantsMap[activity.id][task.id] = participantsData.participants || [];
              } catch (error) {
                console.error(`加载任务 ${task.id} 的参与者失败:`, error);
                participantsMap[activity.id][task.id] = [];
              }
            }
          } catch (error) {
            console.error(`加载活动 ${activity.id} 的关联任务失败:`, error);
            participantsMap[activity.id] = {};
            tasksMap[activity.id] = [];
          }
        })
      );
      setTaskParticipants(participantsMap);
      setActivityTasks(tasksMap);
    } catch (err: any) {
                      message.error('加载多人活动列表失败');
                      console.error('加载多人活动失败:', err);
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


        {/* 标签页 */}
        <div style={{ display: 'flex', gap: '12px', marginBottom: '24px', flexWrap: 'wrap' }}>
          <button
            onClick={() => setActiveTab('dashboard')}
            style={{
              padding: '12px 24px',
              background: activeTab === 'dashboard' ? '#3b82f6' : '#fff',
              color: activeTab === 'dashboard' ? '#fff' : '#333',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: 600,
              fontSize: '14px',
            }}
          >
            📊 仪表盘
          </button>
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
            多人活动
          </button>
          <button
            onClick={() => setActiveTab('schedule')}
            style={{
              padding: '12px 24px',
              background: activeTab === 'schedule' ? '#3b82f6' : '#fff',
              color: activeTab === 'schedule' ? '#fff' : '#333',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            📅 时刻表
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

        {/* 多人活动管理 */}
        {activeTab === 'multi-tasks' && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', fontWeight: 600 }}>我的多人活动</h2>
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
                    auto_add_new_slots: true,
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
                + 创建多人活动
              </button>
            </div>

            {loadingMultiTasks ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : multiTasks.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
                暂无多人活动
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {multiTasks.map((activity: any) => {
                  const tasks = activityTasks[activity.id] || [];
                  const participantsByTask = taskParticipants[activity.id] || {};
                  const isTaskManager = activity.expert_id === user?.id;
                  
                  // 计算当前参与者数量（从所有任务的参与者中统计）
                  // 对于多人任务，统计参与者数量；对于单个任务，每个任务算1个参与者
                  // 排除已取消的任务和已退出的参与者
                  const currentParticipantsCount = tasks.reduce((total: number, task: any) => {
                    // 排除已取消的任务
                    if (task.status === 'cancelled') {
                      return total;
                    }
                    
                    const taskParticipants = participantsByTask[task.id] || [];
                    const isMultiParticipant = task.is_multi_participant === true;
                    if (isMultiParticipant) {
                      // 多人任务：只统计状态为 accepted、in_progress、completed 的参与者
                      const validParticipants = Array.isArray(taskParticipants) 
                        ? taskParticipants.filter((p: any) => 
                            p.status === 'accepted' || 
                            p.status === 'in_progress' || 
                            p.status === 'completed'
                          )
                        : [];
                      return total + validParticipants.length;
                    } else {
                      // 单个任务：只统计状态为 open、taken、in_progress 的任务（每个任务算1个参与者）
                      if (task.status === 'open' || task.status === 'taken' || task.status === 'in_progress') {
                        return total + 1;
                      }
                      return total;
                    }
                  }, 0);
                  
                  return (
                    <div
                      key={activity.id}
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
                            {activity.title}
                          </h3>
                          {/* 活动描述（简短） */}
                          {activity.description && (
                            <p style={{ 
                              margin: '0 0 8px 0', 
                              fontSize: '13px', 
                              color: '#718096',
                              lineHeight: 1.5,
                              display: '-webkit-box',
                              WebkitLineClamp: 2,
                              WebkitBoxOrient: 'vertical',
                              overflow: 'hidden',
                            }}>
                              {activity.description}
                            </p>
                          )}
                          <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', marginBottom: '8px' }}>
                            <span style={{
                              padding: '4px 8px',
                              borderRadius: '6px',
                              fontSize: '12px',
                              fontWeight: 600,
                              background: activity.status === 'open' ? '#dbeafe' :
                                         activity.status === 'in_progress' ? '#d1fae5' :
                                         activity.status === 'completed' ? '#d1fae5' :
                                         '#fee2e2',
                              color: activity.status === 'open' ? '#1e40af' :
                                     activity.status === 'in_progress' ? '#065f46' :
                                     activity.status === 'completed' ? '#065f46' :
                                     '#991b1b',
                            }}>
                              {activity.status === 'open' ? '开放中' :
                               activity.status === 'in_progress' ? '进行中' :
                               activity.status === 'completed' ? '已完成' :
                               '已取消'}
                            </span>
                            <span style={{ fontSize: '14px', color: '#4a5568' }}>
                              👥 {currentParticipantsCount} / {activity.max_participants || 1}
                            </span>
                            {/* 活动类型标识 */}
                            {activity.has_time_slots && (
                              <span style={{
                                padding: '4px 8px',
                                borderRadius: '6px',
                                fontSize: '12px',
                                fontWeight: 600,
                                background: '#e0f2fe',
                                color: '#0369a1',
                              }}>
                                ⏰ 多时间段
                              </span>
                            )}
                            {/* 价格信息 */}
                            {(() => {
                              const hasDiscount = activity.discount_percentage && activity.discount_percentage > 0;
                              const originalPrice = activity.original_price_per_participant;
                              const currentPrice = activity.discounted_price_per_participant || activity.original_price_per_participant;
                              const currency = activity.currency || 'GBP';
                              
                              if (!currentPrice || currentPrice <= 0) {
                                return (
                                  <span style={{ fontSize: '14px', color: '#059669', fontWeight: 600 }}>
                                    💰 免费
                                  </span>
                                );
                              }
                              
                              return (
                                <span style={{ fontSize: '14px', color: '#059669', fontWeight: 600 }}>
                                  💰 {hasDiscount && originalPrice && originalPrice > currentPrice ? (
                                    <>
                                      <span style={{ textDecoration: 'line-through', color: '#9ca3af', marginRight: '4px' }}>
                                        {currency}{originalPrice.toFixed(2)}
                                      </span>
                                      <span>{currency}{currentPrice.toFixed(2)}</span>
                                      <span style={{ 
                                        marginLeft: '4px', 
                                        fontSize: '11px', 
                                        background: '#fee2e2', 
                                        color: '#dc2626',
                                        padding: '2px 4px',
                                        borderRadius: '4px',
                                      }}>
                                        -{activity.discount_percentage.toFixed(0)}%
                                      </span>
                                    </>
                                  ) : (
                                    <span>{currency}{currentPrice.toFixed(2)}</span>
                                  )} / 人
                                </span>
                              );
                            })()}
                          </div>
                        </div>
                      </div>

                      {/* 参与者列表（按任务分组显示） */}
                      {tasks.length > 0 && (
                        <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #e2e8f0' }}>
                          <h4 style={{ margin: '0 0 12px 0', fontSize: '14px', fontWeight: 600, color: '#4a5568' }}>
                            参与者列表（按任务分组）
                          </h4>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                            {tasks.map((task: any) => {
                              const taskParticipants = participantsByTask[task.id] || [];
                              const isMultiParticipant = task.is_multi_participant === true;
                              
                              // 对于多人任务，必须有参与者才显示
                              // 对于单个任务，即使没有参与者也要显示（显示任务发布者）
                              if (isMultiParticipant && taskParticipants.length === 0) {
                                return null; // 多人任务但没有参与者，跳过
                              }
                              
                              return (
                                <div
                                  key={task.id}
                                  style={{
                                    border: '1px solid #e2e8f0',
                                    borderRadius: '8px',
                                    padding: '12px',
                                    background: '#f9fafb',
                                  }}
                                >
                                  <div style={{ marginBottom: '8px', fontSize: '13px', fontWeight: 600, color: '#4a5568' }}>
                                    任务 #{task.id} - {task.title || '未命名任务'}
                                    <span style={{ marginLeft: '8px', fontSize: '12px', color: '#718096', fontWeight: 400 }}>
                                      {isMultiParticipant ? `(${taskParticipants.length} 个参与者)` : '(单个任务)'}
                                    </span>
                                    {/* 显示时间段信息（如果有） */}
                                    {(task.time_slot_id || (task.time_slot_relations && task.time_slot_relations.length > 0)) && (
                                      <span style={{ marginLeft: '8px', fontSize: '11px', color: '#059669', fontWeight: 500 }}>
                                        ⏰ 时间段 {task.time_slot_id || (task.time_slot_relations?.[0]?.time_slot_id)}
                                      </span>
                                    )}
                                  </div>
                                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                                    {/* 多人任务：显示参与者列表 */}
                                    {isMultiParticipant && taskParticipants.map((participant: any) => (
                                      <div
                                        key={participant.id}
                                        style={{
                                          display: 'flex',
                                          justifyContent: 'space-between',
                                          alignItems: 'center',
                                          padding: '10px',
                                          background: '#fff',
                                          borderRadius: '6px',
                                          border: '1px solid #e2e8f0',
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
                                          {isTaskManager && participant.status === 'pending' && activity.status === 'open' && participant.task_id && (
                                            <>
                                              <button
                                                onClick={async () => {
                                                  if (!window.confirm('确定要批准这个参与者吗？')) return;
                                                  try {
                                                    await approveParticipant(participant.task_id, participant.id, false);
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
                                                    await rejectParticipant(participant.task_id, participant.id, false);
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
                                          {isTaskManager && participant.status === 'exit_requested' && participant.task_id && (
                                            <>
                                              <button
                                                onClick={async () => {
                                                  if (!window.confirm('确定要批准退出申请吗？')) return;
                                                  try {
                                                    await approveExitRequest(participant.task_id, participant.id, false);
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
                                                    await rejectExitRequest(participant.task_id, participant.id, false);
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
                                    {/* 单个任务：显示任务发布者信息 */}
                                    {!isMultiParticipant && (
                                      <div
                                        style={{
                                          display: 'flex',
                                          justifyContent: 'space-between',
                                          alignItems: 'center',
                                          padding: '10px',
                                          background: '#fff',
                                          borderRadius: '6px',
                                          border: '1px solid #e2e8f0',
                                        }}
                                      >
                                        <div style={{ flex: 1 }}>
                                          <div style={{ fontWeight: 600, color: '#1a202c', marginBottom: '4px' }}>
                                            {task.poster_name || task.poster?.name || '申请人'}
                                          </div>
                                          <div style={{ fontSize: '12px', color: '#718096' }}>
                                            任务状态: {task.status === 'open' ? '待接受' :
                                                      task.status === 'taken' ? '已接受' :
                                                      task.status === 'in_progress' ? '进行中' :
                                                      task.status === 'completed' ? '已完成' :
                                                      task.status === 'cancelled' ? '已取消' :
                                                      task.status}
                                            {(task.time_slot_id || (task.time_slot_relations && task.time_slot_relations.length > 0)) && (
                                              <span style={{ marginLeft: '8px' }}>
                                                | 时间段ID: {task.time_slot_id || (task.time_slot_relations?.[0]?.time_slot_id)}
                                              </span>
                                            )}
                                          </div>
                                        </div>
                                        <div style={{ display: 'flex', gap: '8px' }}>
                                          {/* 单个任务的操作按钮可以在这里添加 */}
                                        </div>
                                      </div>
                                    )}
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      )}

                      {/* 操作按钮 */}
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #e2e8f0' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                          <span style={{ fontSize: '14px', color: '#718096' }}>
                            活动状态: {activity.status} | 关联任务数: {tasks.length} | 总参与者数: {currentParticipantsCount}
                          </span>
                          {/* 活动时间信息 */}
                          {activity.has_time_slots ? (
                            <span style={{ fontSize: '12px', color: '#9ca3af' }}>
                              ⏰ 多时间段活动 {activity.activity_end_date ? `(截止: ${new Date(activity.activity_end_date).toLocaleDateString('zh-CN')})` : ''}
                            </span>
                          ) : activity.deadline ? (
                            <span style={{ fontSize: '12px', color: '#9ca3af' }}>
                              📅 截止时间: {new Date(activity.deadline).toLocaleString('zh-CN')}
                            </span>
                          ) : null}
                        </div>
                        {/* 删除活动按钮（只有活动创建者可以删除） */}
                        {isTaskManager && activity.status !== 'completed' && activity.status !== 'cancelled' && (
                          <button
                            onClick={async () => {
                              if (!window.confirm(`确定要删除活动"${activity.title}"吗？\n\n删除后：\n- 活动将被取消\n- 所有未开始的任务将被自动取消\n- 已开始的任务不受影响`)) {
                                return;
                              }
                              try {
                                await deleteActivity(activity.id);
                                message.success('活动已删除');
                                await loadMultiTasks();
                              } catch (err: any) {
                                console.error('删除活动失败:', err);
                                message.error(err.response?.data?.detail || '删除失败，请重试');
                              }
                            }}
                            style={{
                              padding: '8px 16px',
                              background: '#dc3545',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                              transition: 'all 0.2s',
                            }}
                            onMouseOver={(e) => {
                              e.currentTarget.style.background = '#c82333';
                              e.currentTarget.style.transform = 'translateY(-1px)';
                            }}
                            onMouseOut={(e) => {
                              e.currentTarget.style.background = '#dc3545';
                              e.currentTarget.style.transform = 'translateY(0)';
                            }}
                          >
                            🗑️ 删除活动
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* 时刻表 */}
        {activeTab === 'schedule' && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', fontWeight: 600 }}>时刻表</h2>
              <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
                <input
                  type="date"
                  value={scheduleStartDate || new Date().toISOString().split('T')[0]}
                  onChange={(e) => {
                    setScheduleStartDate(e.target.value);
                    if (e.target.value && (scheduleEndDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])) {
                      loadSchedule();
                    }
                  }}
                  style={{
                    padding: '8px 12px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '6px',
                    fontSize: '14px',
                  }}
                />
                <span style={{ color: '#718096' }}>至</span>
                <input
                  type="date"
                  value={scheduleEndDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]}
                  onChange={(e) => {
                    setScheduleEndDate(e.target.value);
                    if ((scheduleStartDate || new Date().toISOString().split('T')[0]) && e.target.value) {
                      loadSchedule();
                    }
                  }}
                  style={{
                    padding: '8px 12px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '6px',
                    fontSize: '14px',
                  }}
                />
                <button
                  onClick={loadSchedule}
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
                  刷新
                </button>
              </div>
            </div>

            {loadingSchedule ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : scheduleData && scheduleData.items && scheduleData.items.length > 0 ? (
              <div>
                {/* 按日期分组显示 */}
                {(() => {
                  const groupedByDate: { [key: string]: any[] } = {};
                  scheduleData.items.forEach((item: any) => {
                    const date = item.date;
                    if (!groupedByDate[date]) {
                      groupedByDate[date] = [];
                    }
                    groupedByDate[date].push(item);
                  });

                  const sortedDates = Object.keys(groupedByDate).sort();

                  return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                      {sortedDates.map((date) => {
                        const items = groupedByDate[date];
                        const dateObj = new Date(date);
                        const dayName = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][dateObj.getDay()];
                        
                        return (
                          <div key={date} style={{ border: '1px solid #e2e8f0', borderRadius: '12px', overflow: 'hidden' }}>
                            <div style={{
                              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                              padding: '16px 20px',
                              color: '#fff',
                              fontWeight: 600,
                              fontSize: '16px',
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                            }}>
                              <span>{date} ({dayName})</span>
                              <div style={{ display: 'flex', gap: '8px' }}>
                                {(() => {
                                  const isClosed = closedDates.some((cd: any) => cd.closed_date === date);
                                  const hasTimeSlots = items.some((i: any) => !i.is_task);
                                  return (
                                    <>
                                      {hasTimeSlots && (
                                        <button
                                          onClick={async () => {
                                            if (!window.confirm(`确定要删除 ${date} 的所有时间段吗？`)) return;
                                            
                                            // 找到该日期的所有服务ID
                                            const serviceIds = Array.from(new Set(items.filter((i: any) => !i.is_task).map((i: any) => i.service_id)));
                                            
                                            if (serviceIds.length === 0) {
                                              message.warning('没有找到可删除的时间段');
                                              return;
                                            }
                                            
                                            // 显示加载状态
                                            const hideLoading = message.loading(`正在删除 ${date} 的所有时间段...`, 0);
                                            
                                            try {
                                              // 并行删除所有服务的时间段，提高效率
                                              const deletePromises = serviceIds.map(serviceId => 
                                                deleteTimeSlotsByDate(serviceId, date).catch(err => {
                                                  console.error(`删除服务 ${serviceId} 的时间段失败:`, err);
                                                  throw err;
                                                })
                                              );
                                              
                                              const results = await Promise.all(deletePromises);
                                              const totalDeleted = results.reduce((sum, result) => sum + (result.deleted_count || 0), 0);
                                              
                                              hideLoading();
                                              
                                              if (totalDeleted > 0) {
                                                message.success(`已删除 ${date} 的 ${totalDeleted} 个时间段`);
                                              } else {
                                                message.info(`${date} 没有可删除的时间段`);
                                              }
                                              
                                              // 重新加载时刻表
                                              await loadSchedule();
                                            } catch (err: any) {
                                              hideLoading();
                                              console.error('删除时间段失败:', err);
                                              message.error(err.response?.data?.detail || err.message || '删除失败，请重试');
                                            }
                                          }}
                                          disabled={loadingSchedule}
                                          style={{
                                            padding: '6px 12px',
                                            background: loadingSchedule ? 'rgba(255,255,255,0.1)' : 'rgba(255,255,255,0.2)',
                                            color: '#fff',
                                            border: '1px solid rgba(255,255,255,0.3)',
                                            borderRadius: '6px',
                                            cursor: loadingSchedule ? 'not-allowed' : 'pointer',
                                            fontSize: '12px',
                                            fontWeight: 600,
                                            opacity: loadingSchedule ? 0.6 : 1,
                                          }}
                                        >
                                          {loadingSchedule ? '删除中...' : '删除该日期的所有时间段'}
                                        </button>
                                      )}
                                      <button
                                        onClick={async () => {
                                          if (isClosed) {
                                            // 取消关门
                                            if (!window.confirm(`确定要取消 ${date} 的关门设置吗？`)) return;
                                            try {
                                              const closedDate = closedDates.find((cd: any) => cd.closed_date === date);
                                              if (closedDate) {
                                                await deleteClosedDate(closedDate.id);
                                              } else {
                                                await deleteClosedDateByDate(date);
                                              }
                                              message.success('已取消关门设置');
                                              await loadSchedule();
                                            } catch (err: any) {
                                              message.error(err.response?.data?.detail || '操作失败');
                                            }
                                          } else {
                                            // 设置关门
                                            setSelectedDateForClose(date);
                                            setCloseDateReason('');
                                            setShowCloseDateModal(true);
                                          }
                                        }}
                                        style={{
                                          padding: '6px 12px',
                                          background: isClosed ? '#dc3545' : 'rgba(255,255,255,0.2)',
                                          color: '#fff',
                                          border: '1px solid rgba(255,255,255,0.3)',
                                          borderRadius: '6px',
                                          cursor: 'pointer',
                                          fontSize: '12px',
                                          fontWeight: 600,
                                        }}
                                      >
                                        {isClosed ? '已关门 - 点击取消' : '设置关门'}
                                      </button>
                                    </>
                                  );
                                })()}
                              </div>
                            </div>
                            <div style={{ padding: '16px' }}>
                              {items.map((item: any) => (
                                <div
                                  key={item.id}
                                  style={{
                                    border: '1px solid #e2e8f0',
                                    borderRadius: '8px',
                                    padding: '16px',
                                    marginBottom: '12px',
                                    background: item.is_task ? '#f0f9ff' : '#fff',
                                  }}
                                >
                                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '8px' }}>
                                    <div style={{ flex: 1 }}>
                                      <div style={{ fontSize: '16px', fontWeight: 600, color: '#1a202c', marginBottom: '4px' }}>
                                        {item.service_name}
                                      </div>
                                      {item.start_time && item.end_time && (
                                        <div style={{ fontSize: '14px', color: '#4a5568' }}>
                                          ⏰ {item.start_time} - {item.end_time}
                                        </div>
                                      )}
                                      {item.deadline && (
                                        <div style={{ fontSize: '14px', color: '#4a5568' }}>
                                          📅 截止: {new Date(item.deadline).toLocaleString('zh-CN')}
                                        </div>
                                      )}
                                    </div>
                                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '4px' }}>
                                      <div style={{
                                        padding: '4px 8px',
                                        borderRadius: '6px',
                                        fontSize: '12px',
                                        fontWeight: 600,
                                        background: item.is_expired ? '#fee2e2' :
                                                   item.current_participants >= item.max_participants ? '#fef3c7' :
                                                   '#d1fae5',
                                        color: item.is_expired ? '#991b1b' :
                                               item.current_participants >= item.max_participants ? '#92400e' :
                                               '#065f46',
                                      }}>
                                        {item.is_expired ? '已过期' :
                                         item.current_participants >= item.max_participants ? '已满' :
                                         '可预约'}
                                      </div>
                                      {item.task_status && (
                                        <div style={{
                                          padding: '4px 8px',
                                          borderRadius: '6px',
                                          fontSize: '12px',
                                          fontWeight: 600,
                                          background: item.task_status === 'in_progress' ? '#dbeafe' : '#f3f4f6',
                                          color: item.task_status === 'in_progress' ? '#1e40af' : '#4a5568',
                                        }}>
                                          {item.task_status === 'open' ? '开放中' :
                                           item.task_status === 'in_progress' ? '进行中' : item.task_status}
                                        </div>
                                      )}
                                    </div>
                                  </div>
                                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '8px', paddingTop: '8px', borderTop: '1px solid #e2e8f0' }}>
                                    <div style={{ fontSize: '14px', color: '#4a5568' }}>
                                      👥 参与者: {item.current_participants} / {item.max_participants}
                                    </div>
                                    <div style={{ display: 'flex', gap: '8px' }}>
                                      {!item.is_task && (
                                        <button
                                          onClick={async () => {
                                            if (!window.confirm('确定要删除这个时间段吗？')) return;
                                            try {
                                              await deleteServiceTimeSlot(item.service_id, item.id);
                                              message.success('时间段已删除');
                                              await loadSchedule();
                                            } catch (err: any) {
                                              message.error(err.response?.data?.detail || '删除失败');
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
                                          删除
                                        </button>
                                      )}
                                      {item.is_task && (
                                        <button
                                          onClick={() => navigate(`/tasks/${item.id.replace('task_', '')}`)}
                                          style={{
                                            padding: '6px 12px',
                                            background: '#3b82f6',
                                            color: '#fff',
                                            border: 'none',
                                            borderRadius: '6px',
                                            cursor: 'pointer',
                                            fontSize: '12px',
                                            fontWeight: 600,
                                          }}
                                        >
                                          查看任务
                                        </button>
                                      )}
                                    </div>
                                  </div>
                                </div>
                              ))}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  );
                })()}
              </div>
            ) : (
              <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
                暂无时间段安排
              </div>
            )}
          </div>
        )}
      </div>

      {/* 创建多人活动弹窗 */}
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
              <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>创建多人活动</h3>
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
                    const serviceId = e.target.value ? parseInt(e.target.value) : undefined;
                    const selectedService = serviceId ? services.find(s => s.id === serviceId) : undefined;
                    // 使用函数式更新确保状态一致性
                    setCreateMultiTaskForm(prev => {
                      const newServiceId = serviceId;
                      return {
                        ...prev,
                        service_id: newServiceId,
                        title: selectedService ? selectedService.service_name : prev.title,
                        description: selectedService ? selectedService.description : prev.description,
                        base_reward: selectedService ? selectedService.base_price : prev.base_reward,
                        currency: selectedService ? selectedService.currency : prev.currency,
                        discount_percentage: undefined, // 重置折扣
                        custom_discount: undefined,
                        use_custom_discount: false,
                        // 重置时间段选择
                        selected_time_slot_id: undefined,
                        selected_time_slot_date: undefined,
                        // 如果服务有时间段，限制最大参与者数
                        max_participants: selectedService?.has_time_slots && selectedService?.participants_per_slot 
                          ? Math.min(prev.max_participants, selectedService.participants_per_slot)
                          : prev.max_participants,
                      };
                    });
                    
                    // 如果服务有时间段，加载时间段列表并设置默认日期
                    if (selectedService?.has_time_slots && serviceId) {
                      console.log('服务有时间段，开始加载时间段数据:', {
                        serviceId,
                        has_time_slots: selectedService.has_time_slots,
                        service: selectedService
                      }); // 调试日志
                      // 设置默认日期为今天
                      const today = new Date().toISOString().split('T')[0];
                      // 使用函数式更新确保service_id不会丢失
                      setCreateMultiTaskForm(prev => ({
                        ...prev,
                        service_id: serviceId, // 确保service_id被保留
                        selected_time_slot_date: today,
                        selected_time_slot_id: undefined, // 重置时间段选择
                      }));
                      // 加载时间段列表
                      loadTimeSlotsForCreateTask(serviceId);
                    } else {
                      console.log('服务没有时间段:', {
                        serviceId,
                        has_time_slots: selectedService?.has_time_slots,
                        selectedService
                      }); // 调试日志
                      setAvailableTimeSlots([]);
                      // 使用函数式更新确保service_id不会丢失
                      setCreateMultiTaskForm(prev => ({
                        ...prev,
                        service_id: serviceId, // 确保service_id被保留
                        selected_time_slot_date: undefined,
                        selected_time_slot_id: undefined,
                      }));
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

              {/* 活动标题 */}
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                  活动标题 <span style={{ color: '#dc3545' }}>*</span>
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

              {/* 活动描述 */}
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                  活动描述 <span style={{ color: '#dc3545' }}>*</span>
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
                  <div style={{ 
                    marginBottom: '12px', 
                    padding: '12px', 
                    background: '#f0f9ff', 
                    border: '1px solid #bae6fd', 
                    borderRadius: '8px' 
                  }}>
                    <div style={{ fontSize: '14px', fontWeight: 500, color: '#0369a1', marginBottom: '4px' }}>
                      ⏰ 时间段服务 - 必须选择时间段
                    </div>
                    <div style={{ fontSize: '13px', color: '#075985', lineHeight: '1.5', marginBottom: '12px' }}>
                      此服务为时间段服务，必须选择时间段才能创建活动。您可以选择固定时间段或重复模式。
                    </div>
                    
                    {/* 时间段选择模式 */}
                    <div style={{ marginBottom: '12px' }}>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                        选择模式 <span style={{ color: '#dc3545' }}>*</span>
                      </label>
                      <select
                        value={createMultiTaskForm.time_slot_selection_mode || ''}
                        onChange={(e) => {
                          const mode = e.target.value as 'fixed' | 'recurring_daily' | 'recurring_weekly' | '';
                          setCreateMultiTaskForm({
                            ...createMultiTaskForm,
                            time_slot_selection_mode: mode || undefined,
                            selected_time_slot_ids: [],
                            recurring_daily_time_ranges: [],
                            recurring_weekly_weekdays: [],
                            recurring_weekly_time_ranges: [],
                          });
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
                        <option value="">请选择模式</option>
                        <option value="fixed">固定时间段（选择具体的时间段）</option>
                        <option value="recurring_daily">每天重复（每天固定时间段）</option>
                        <option value="recurring_weekly">每周重复（每周几的固定时间段）</option>
                      </select>
                    </div>
                    {(() => {
                      const selectedService = services.find(s => s.id === createMultiTaskForm.service_id);
                      if (selectedService) {
                        return (
                          <div style={{ marginTop: '8px', padding: '8px', background: '#fff', borderRadius: '4px' }}>
                            <div style={{ fontSize: '12px', color: '#64748b' }}>
                              时间段配置：{selectedService.time_slot_start_time?.substring(0, 5) || '09:00'} - {selectedService.time_slot_end_time?.substring(0, 5) || '18:00'}
                            </div>
                            <div style={{ fontSize: '12px', color: '#64748b' }}>
                              每个时间段时长：{selectedService.time_slot_duration_minutes || 60} 分钟
                            </div>
                            <div style={{ fontSize: '12px', color: '#64748b' }}>
                              每个时间段最多：{selectedService.participants_per_slot || 1} 人
                            </div>
                          </div>
                        );
                      }
                      return null;
                    })()}
                  </div>
                  
                  {/* 固定模式：多选时间段 */}
                  {createMultiTaskForm.time_slot_selection_mode === 'fixed' && (
                    <div style={{ marginBottom: '16px', padding: '16px', background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px' }}>
                      <label style={{ display: 'block', marginBottom: '12px', fontSize: '14px', fontWeight: 500 }}>
                        选择时间段 <span style={{ color: '#dc3545' }}>*</span>
                        <span style={{ fontSize: '12px', fontWeight: 400, color: '#718096', marginLeft: '8px' }}>
                          （可多选，一个时间段只能被一个活动使用）
                        </span>
                      </label>
                      
                      {/* 日期选择器 */}
                      <div style={{ marginBottom: '12px' }}>
                        <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', color: '#718096' }}>
                          选择日期范围
                        </label>
                        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                          <input
                            type="date"
                            value={createMultiTaskForm.selected_time_slot_date || ''}
                            onChange={async (e) => {
                              const date = e.target.value;
                              setCreateMultiTaskForm({ 
                                ...createMultiTaskForm, 
                                selected_time_slot_date: date,
                                selected_time_slot_ids: [],
                              });
                              if (date && createMultiTaskForm.service_id && availableTimeSlots.length === 0) {
                                await loadTimeSlotsForCreateTask(createMultiTaskForm.service_id);
                              }
                            }}
                            min={new Date().toISOString().split('T')[0]}
                            style={{
                              flex: 1,
                              padding: '10px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '6px',
                              fontSize: '14px',
                            }}
                          />
                          <span style={{ color: '#718096' }}>至</span>
                          <input
                            type="date"
                            value={(() => {
                              if (!createMultiTaskForm.selected_time_slot_date) return '';
                              const startDate = new Date(createMultiTaskForm.selected_time_slot_date);
                              const endDate = new Date(startDate);
                              endDate.setDate(startDate.getDate() + 30);
                              return endDate.toISOString().split('T')[0];
                            })()}
                            onChange={(e) => {
                              // 结束日期用于显示，实际加载未来30天的时间段
                            }}
                            min={createMultiTaskForm.selected_time_slot_date || new Date().toISOString().split('T')[0]}
                            style={{
                              flex: 1,
                              padding: '10px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '6px',
                              fontSize: '14px',
                            }}
                            disabled
                          />
                        </div>
                        <div style={{ marginTop: '4px', fontSize: '12px', color: '#718096' }}>
                          将显示未来30天内的所有可用时间段
                        </div>
                      </div>
                      
                      {/* 时间段列表（多选） */}
                      {createMultiTaskForm.service_id && (
                        <div>
                          {loadingTimeSlots ? (
                            <div style={{ padding: '20px', textAlign: 'center', color: '#718096' }}>
                              加载时间段中...
                            </div>
                          ) : (() => {
                            // 过滤可用时间段（未过期、未满、未被其他活动使用）
                            const availableSlots = availableTimeSlots.filter((slot: any) => {
                              if (slot.is_manually_deleted) return false;
                              if (slot.current_participants >= slot.max_participants) return false;
                              // 检查是否过期（时间段开始时间已过）
                              if (slot.slot_start_datetime) {
                                const slotStart = new Date(slot.slot_start_datetime);
                                if (slotStart < new Date()) return false;
                              }
                              return true;
                            });
                            
                            if (availableSlots.length === 0) {
                              return (
                                <div style={{ 
                                  padding: '20px', 
                                  textAlign: 'center', 
                                  color: '#e53e3e',
                                  background: '#fef2f2',
                                  borderRadius: '8px',
                                  border: '1px solid #fecaca',
                                }}>
                                  {availableTimeSlots.length === 0 ? (
                                    <>
                                      该服务还没有生成时间段
                                      <div style={{ marginTop: '8px', fontSize: '12px', color: '#718096' }}>
                                        提示：请先在"服务管理"页面批量创建时间段
                                      </div>
                                    </>
                                  ) : (
                                    <>
                                      暂无可用时间段
                                      <div style={{ marginTop: '8px', fontSize: '12px', color: '#718096' }}>
                                        所有时间段都已过期、已满或被其他活动使用
                                      </div>
                                    </>
                                  )}
                                </div>
                              );
                            }
                            
                            // 按日期分组
                            const slotsByDate: {[key: string]: any[]} = {};
                            availableSlots.forEach((slot: any) => {
                              const slotStartStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                              let dateStr = '';
                              try {
                                dateStr = TimeHandlerV2.formatUtcToLocal(slotStartStr, 'YYYY-MM-DD', 'Europe/London');
                                if (dateStr.includes(' (GMT)') || dateStr.includes(' (BST)')) {
                                  dateStr = dateStr.replace(' (GMT)', '').replace(' (BST)', '');
                                }
                              } catch {
                                dateStr = slot.slot_date || '';
                              }
                              
                              if (!slotsByDate[dateStr]) {
                                slotsByDate[dateStr] = [];
                              }
                              slotsByDate[dateStr].push(slot);
                            });
                            
                            return (
                              <div style={{ maxHeight: '400px', overflowY: 'auto', border: '1px solid #e2e8f0', borderRadius: '8px', padding: '12px' }}>
                                {Object.keys(slotsByDate).sort().map((dateStr) => (
                                  <div key={dateStr} style={{ marginBottom: '16px' }}>
                                    <div style={{ fontSize: '13px', fontWeight: 600, color: '#374151', marginBottom: '8px', paddingBottom: '8px', borderBottom: '1px solid #e2e8f0' }}>
                                      📅 {dateStr}
                                    </div>
                                    <div style={{ 
                                      display: 'grid', 
                                      gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', 
                                      gap: '8px',
                                    }}>
                                      {slotsByDate[dateStr].map((slot: any) => {
                                        const isSelected = createMultiTaskForm.selected_time_slot_ids?.includes(slot.id) || false;
                                        const startTimeStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                                        const endTimeStr = slot.slot_end_datetime || (slot.slot_date + 'T' + slot.end_time + 'Z');
                                        const startTimeUK = TimeHandlerV2.formatUtcToLocal(
                                          startTimeStr.includes('T') ? startTimeStr : `${startTimeStr}T00:00:00Z`,
                                          'HH:mm',
                                          'Europe/London'
                                        );
                                        const endTimeUK = TimeHandlerV2.formatUtcToLocal(
                                          endTimeStr.includes('T') ? endTimeStr : `${endTimeStr}T00:00:00Z`,
                                          'HH:mm',
                                          'Europe/London'
                                        );
                                        
                                        return (
                                          <button
                                            key={slot.id}
                                            type="button"
                                            onClick={() => {
                                              const currentIds = createMultiTaskForm.selected_time_slot_ids || [];
                                              const newIds = isSelected
                                                ? currentIds.filter(id => id !== slot.id)
                                                : [...currentIds, slot.id];
                                              setCreateMultiTaskForm({
                                                ...createMultiTaskForm,
                                                selected_time_slot_ids: newIds,
                                              });
                                            }}
                                            style={{
                                              padding: '10px',
                                              border: `2px solid ${isSelected ? '#3b82f6' : '#cbd5e0'}`,
                                              borderRadius: '6px',
                                              background: isSelected ? '#eff6ff' : '#fff',
                                              cursor: 'pointer',
                                              transition: 'all 0.2s',
                                              textAlign: 'left',
                                            }}
                                            onMouseEnter={(e) => {
                                              if (!isSelected) {
                                                e.currentTarget.style.borderColor = '#3b82f6';
                                                e.currentTarget.style.background = '#f0f9ff';
                                              }
                                            }}
                                            onMouseLeave={(e) => {
                                              if (!isSelected) {
                                                e.currentTarget.style.borderColor = '#cbd5e0';
                                                e.currentTarget.style.background = '#fff';
                                              }
                                            }}
                                          >
                                            <div style={{ fontSize: '13px', fontWeight: 600, color: '#1f2937' }}>
                                              {startTimeUK} - {endTimeUK}
                                            </div>
                                            <div style={{ fontSize: '11px', color: '#6b7280', marginTop: '4px' }}>
                                              {slot.current_participants}/{slot.max_participants} 人
                                            </div>
                                          </button>
                                        );
                                      })}
                                    </div>
                                  </div>
                                ))}
                                {createMultiTaskForm.selected_time_slot_ids && createMultiTaskForm.selected_time_slot_ids.length > 0 && (
                                  <div style={{ marginTop: '12px', padding: '12px', background: '#f0f9ff', borderRadius: '8px', border: '1px solid #bae6fd' }}>
                                    <div style={{ fontSize: '13px', fontWeight: 500, color: '#0369a1' }}>
                                      已选择 {createMultiTaskForm.selected_time_slot_ids.length} 个时间段
                                    </div>
                                  </div>
                                )}
                              </div>
                            );
                          })()}
                        </div>
                      )}
                    </div>
                  )}
                  
                  {/* 每天重复模式 */}
                  {createMultiTaskForm.time_slot_selection_mode === 'recurring_daily' && (
                    <div style={{ marginBottom: '16px', padding: '16px', background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px' }}>
                      <label style={{ display: 'block', marginBottom: '12px', fontSize: '14px', fontWeight: 500 }}>
                        每天的时间段范围 <span style={{ color: '#dc3545' }}>*</span>
                        <span style={{ fontSize: '12px', fontWeight: 400, color: '#718096', marginLeft: '8px' }}>
                          （可添加多个时间段范围）
                        </span>
                      </label>
                      
                      {(createMultiTaskForm.recurring_daily_time_ranges || []).map((range, index) => (
                        <div key={index} style={{ display: 'flex', gap: '8px', marginBottom: '8px', alignItems: 'center' }}>
                          <input
                            type="time"
                            value={range.start}
                            onChange={(e) => {
                              const newRanges = [...(createMultiTaskForm.recurring_daily_time_ranges || [])];
                              newRanges[index].start = e.target.value;
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                recurring_daily_time_ranges: newRanges,
                              });
                            }}
                            style={{
                              flex: 1,
                              padding: '10px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '6px',
                              fontSize: '14px',
                            }}
                          />
                          <span style={{ color: '#718096' }}>至</span>
                          <input
                            type="time"
                            value={range.end}
                            onChange={(e) => {
                              const newRanges = [...(createMultiTaskForm.recurring_daily_time_ranges || [])];
                              newRanges[index].end = e.target.value;
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                recurring_daily_time_ranges: newRanges,
                              });
                            }}
                            style={{
                              flex: 1,
                              padding: '10px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '6px',
                              fontSize: '14px',
                            }}
                          />
                          <button
                            type="button"
                            onClick={() => {
                              const newRanges = (createMultiTaskForm.recurring_daily_time_ranges || []).filter((_, i) => i !== index);
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                recurring_daily_time_ranges: newRanges,
                              });
                            }}
                            style={{
                              padding: '10px 16px',
                              background: '#ef4444',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                            }}
                          >
                            删除
                          </button>
                        </div>
                      ))}
                      
                      <button
                        type="button"
                        onClick={() => {
                          setCreateMultiTaskForm({
                            ...createMultiTaskForm,
                            recurring_daily_time_ranges: [
                              ...(createMultiTaskForm.recurring_daily_time_ranges || []),
                              { start: '09:00', end: '12:00' }
                            ],
                          });
                        }}
                        style={{
                          padding: '8px 16px',
                          background: '#3b82f6',
                          color: '#fff',
                          border: 'none',
                          borderRadius: '6px',
                          cursor: 'pointer',
                          fontSize: '14px',
                        }}
                      >
                        + 添加时间段范围
                      </button>
                      
                      {/* 活动截至日期（可选） */}
                      <div style={{ marginTop: '16px' }}>
                        <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                          活动截至日期（可选）
                          <span style={{ fontSize: '12px', fontWeight: 400, color: '#718096', marginLeft: '8px' }}>
                            留空则活动一直有效，直到您手动取消
                          </span>
                        </label>
                        <input
                          type="date"
                          value={createMultiTaskForm.activity_end_date || ''}
                          onChange={(e) => {
                            setCreateMultiTaskForm({
                              ...createMultiTaskForm,
                              activity_end_date: e.target.value || undefined,
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
                        />
                      </div>
                      
                      {/* 自动添加新时间段选项 */}
                      <div style={{ marginTop: '12px' }}>
                        <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                          <input
                            type="checkbox"
                            checked={createMultiTaskForm.auto_add_new_slots}
                            onChange={(e) => {
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                auto_add_new_slots: e.target.checked,
                              });
                            }}
                            style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                          />
                          <span style={{ fontSize: '13px', color: '#374151' }}>
                            自动添加新匹配的时间段（当服务生成新的时间段时，如果匹配规则，会自动添加到活动中）
                          </span>
                        </label>
                      </div>
                    </div>
                  )}
                  
                  {/* 每周重复模式 */}
                  {createMultiTaskForm.time_slot_selection_mode === 'recurring_weekly' && (
                    <div style={{ marginBottom: '16px', padding: '16px', background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px' }}>
                      <label style={{ display: 'block', marginBottom: '12px', fontSize: '14px', fontWeight: 500 }}>
                        选择星期几 <span style={{ color: '#dc3545' }}>*</span>
                      </label>
                      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '16px' }}>
                        {['周一', '周二', '周三', '周四', '周五', '周六', '周日'].map((day, index) => {
                          const isSelected = createMultiTaskForm.recurring_weekly_weekdays?.includes(index) || false;
                          return (
                            <button
                              key={index}
                              type="button"
                              onClick={() => {
                                const currentWeekdays = createMultiTaskForm.recurring_weekly_weekdays || [];
                                const newWeekdays = isSelected
                                  ? currentWeekdays.filter(w => w !== index)
                                  : [...currentWeekdays, index];
                                setCreateMultiTaskForm({
                                  ...createMultiTaskForm,
                                  recurring_weekly_weekdays: newWeekdays,
                                });
                              }}
                              style={{
                                padding: '8px 16px',
                                border: `2px solid ${isSelected ? '#3b82f6' : '#cbd5e0'}`,
                                borderRadius: '6px',
                                background: isSelected ? '#eff6ff' : '#fff',
                                color: isSelected ? '#3b82f6' : '#374151',
                                cursor: 'pointer',
                                fontSize: '14px',
                                fontWeight: isSelected ? 600 : 400,
                                transition: 'all 0.2s',
                              }}
                            >
                              {day}
                            </button>
                          );
                        })}
                      </div>
                      
                      <label style={{ display: 'block', marginBottom: '12px', fontSize: '14px', fontWeight: 500 }}>
                        时间段范围 <span style={{ color: '#dc3545' }}>*</span>
                        <span style={{ fontSize: '12px', fontWeight: 400, color: '#718096', marginLeft: '8px' }}>
                          （可添加多个时间段范围）
                        </span>
                      </label>
                      
                      {(createMultiTaskForm.recurring_weekly_time_ranges || []).map((range, index) => (
                        <div key={index} style={{ display: 'flex', gap: '8px', marginBottom: '8px', alignItems: 'center' }}>
                          <input
                            type="time"
                            value={range.start}
                            onChange={(e) => {
                              const newRanges = [...(createMultiTaskForm.recurring_weekly_time_ranges || [])];
                              newRanges[index].start = e.target.value;
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                recurring_weekly_time_ranges: newRanges,
                              });
                            }}
                            style={{
                              flex: 1,
                              padding: '10px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '6px',
                              fontSize: '14px',
                            }}
                          />
                          <span style={{ color: '#718096' }}>至</span>
                          <input
                            type="time"
                            value={range.end}
                            onChange={(e) => {
                              const newRanges = [...(createMultiTaskForm.recurring_weekly_time_ranges || [])];
                              newRanges[index].end = e.target.value;
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                recurring_weekly_time_ranges: newRanges,
                              });
                            }}
                            style={{
                              flex: 1,
                              padding: '10px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '6px',
                              fontSize: '14px',
                            }}
                          />
                          <button
                            type="button"
                            onClick={() => {
                              const newRanges = (createMultiTaskForm.recurring_weekly_time_ranges || []).filter((_, i) => i !== index);
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                recurring_weekly_time_ranges: newRanges,
                              });
                            }}
                            style={{
                              padding: '10px 16px',
                              background: '#ef4444',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                            }}
                          >
                            删除
                          </button>
                        </div>
                      ))}
                      
                      <button
                        type="button"
                        onClick={() => {
                          setCreateMultiTaskForm({
                            ...createMultiTaskForm,
                            recurring_weekly_time_ranges: [
                              ...(createMultiTaskForm.recurring_weekly_time_ranges || []),
                              { start: '09:00', end: '12:00' }
                            ],
                          });
                        }}
                        style={{
                          padding: '8px 16px',
                          background: '#3b82f6',
                          color: '#fff',
                          border: 'none',
                          borderRadius: '6px',
                          cursor: 'pointer',
                          fontSize: '14px',
                        }}
                      >
                        + 添加时间段范围
                      </button>
                      
                      {/* 活动截至日期（可选） */}
                      <div style={{ marginTop: '16px' }}>
                        <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                          活动截至日期（可选）
                          <span style={{ fontSize: '12px', fontWeight: 400, color: '#718096', marginLeft: '8px' }}>
                            留空则活动一直有效，直到您手动取消
                          </span>
                        </label>
                        <input
                          type="date"
                          value={createMultiTaskForm.activity_end_date || ''}
                          onChange={(e) => {
                            setCreateMultiTaskForm({
                              ...createMultiTaskForm,
                              activity_end_date: e.target.value || undefined,
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
                        />
                      </div>
                      
                      {/* 自动添加新时间段选项 */}
                      <div style={{ marginTop: '12px' }}>
                        <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                          <input
                            type="checkbox"
                            checked={createMultiTaskForm.auto_add_new_slots}
                            onChange={(e) => {
                              setCreateMultiTaskForm({
                                ...createMultiTaskForm,
                                auto_add_new_slots: e.target.checked,
                              });
                            }}
                            style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                          />
                          <span style={{ fontSize: '13px', color: '#374151' }}>
                            自动添加新匹配的时间段（当服务生成新的时间段时，如果匹配规则，会自动添加到活动中）
                          </span>
                        </label>
                      </div>
                    </div>
                  )}
                  
                  {/* 可选：预览时间段（不强制选择，仅用于查看） */}
                  <details style={{ marginBottom: '12px' }}>
                    <summary style={{ 
                      cursor: 'pointer', 
                      fontSize: '13px', 
                      color: '#718096',
                      padding: '8px',
                      background: '#f7fafc',
                      borderRadius: '6px',
                      border: '1px solid #e2e8f0'
                    }}>
                      预览时间段（可选，点击展开）
                    </summary>
                    <div style={{ marginTop: '8px' }}>
                  <div style={{ marginBottom: '12px' }}>
                    <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', color: '#718096' }}>
                      选择日期
                    </label>
                    <input
                      type="date"
                      value={createMultiTaskForm.selected_time_slot_date || ''}
                      onChange={async (e) => {
                        const date = e.target.value;
                        setCreateMultiTaskForm({ 
                          ...createMultiTaskForm, 
                          selected_time_slot_date: date,
                          selected_time_slot_id: undefined, // 切换日期时重置时间段选择
                        });
                        // 如果时间段列表为空，加载时间段用于预览
                        // 注意：时间段列表已经包含了所有日期，不需要重新加载
                        // 但如果列表为空，说明还没有加载过，需要加载
                        if (date && createMultiTaskForm.service_id && availableTimeSlots.length === 0) {
                          await loadTimeSlotsForCreateTask(createMultiTaskForm.service_id);
                        }
                      }}
                      min={new Date().toISOString().split('T')[0]}
                      style={{
                        width: '100%',
                        padding: '10px',
                        border: '1px solid #e2e8f0',
                        borderRadius: '6px',
                        fontSize: '14px',
                      }}
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
                      ) : (() => {
                        // 过滤匹配选中日期的时间段
                        const selectedDateStr = createMultiTaskForm.selected_time_slot_date 
                          ? createMultiTaskForm.selected_time_slot_date.split('T')[0] 
                          : '';
                        
                        console.log('开始过滤时间段:', {
                          selectedDateStr,
                          total_slots: availableTimeSlots.length,
                          availableTimeSlots_sample: availableTimeSlots.slice(0, 3).map((s: any) => ({
                            id: s.id,
                            slot_start_datetime: s.slot_start_datetime,
                            slot_date: s.slot_date,
                            start_time: s.start_time,
                          }))
                        });
                        
                        const filteredSlots = availableTimeSlots.filter((slot: any) => {
                          // 使用UTC时间转换为英国时间进行日期匹配
                          // 优先使用 slot_start_datetime（ISO格式字符串），否则使用 slot_date + start_time 组合
                          let slotStartStr: string;
                          if (slot.slot_start_datetime) {
                            // 如果已经是ISO格式字符串，直接使用
                            slotStartStr = slot.slot_start_datetime;
                            // 确保是UTC格式（以Z结尾或包含时区信息）
                            if (!slotStartStr.includes('Z') && !slotStartStr.includes('+') && !slotStartStr.includes('-', 10)) {
                              slotStartStr = slotStartStr + 'Z';
                            }
                          } else if (slot.slot_date && slot.start_time) {
                            // 组合日期和时间
                            slotStartStr = slot.slot_date + 'T' + slot.start_time;
                            if (!slotStartStr.includes('Z') && !slotStartStr.includes('+') && !slotStartStr.includes('-', 10)) {
                              slotStartStr = slotStartStr + 'Z';
                            }
                          } else {
                            // 如果都没有，跳过这个时间段
                            console.warn('时间段缺少日期信息:', slot);
                            return false;
                          }
                          
                          // 转换为英国时间的日期字符串
                          let slotDateUK: string;
                          try {
                            slotDateUK = TimeHandlerV2.formatUtcToLocal(
                              slotStartStr,
                              'YYYY-MM-DD',
                              'Europe/London'
                            );
                            // 如果返回的格式包含 " (GMT)"，需要去掉
                            if (slotDateUK.includes(' (GMT)')) {
                              slotDateUK = slotDateUK.replace(' (GMT)', '');
                            }
                          } catch (error) {
                            console.error('日期转换失败:', { slotStartStr, error, slot });
                            return false;
                          }
                          
                          const isDateMatch = slotDateUK === selectedDateStr;
                          
                          // 输出前几个和匹配的时间段的详细日志
                          if (isDateMatch || slot.id <= 5) {
                            console.log('时间段过滤（创建活动）:', {
                              slot_id: slot.id,
                              slot_start_datetime: slot.slot_start_datetime,
                              slot_date: slot.slot_date,
                              start_time: slot.start_time,
                              slotStartStr,
                              slotDateUK,
                              selectedDateStr,
                              isDateMatch,
                              is_available: slot.is_available,
                            });
                          }
                          
                          return isDateMatch;
                        });
                        
                        // 输出过滤结果和示例数据，帮助调试
                        const sampleSlotDates = availableTimeSlots.slice(0, 5).map((s: any) => {
                          const slotStartStr = s.slot_start_datetime || (s.slot_date + 'T' + s.start_time + 'Z');
                          try {
                            let dateStr = TimeHandlerV2.formatUtcToLocal(slotStartStr, 'YYYY-MM-DD', 'Europe/London');
                            // 去掉时区后缀
                            if (dateStr.includes(' (GMT)') || dateStr.includes(' (BST)')) {
                              dateStr = dateStr.replace(' (GMT)', '').replace(' (BST)', '');
                            }
                            return dateStr;
                          } catch {
                            return s.slot_date;
                          }
                        });
                        
                        console.log('时间段过滤结果:', {
                          total_slots: availableTimeSlots.length,
                          filtered_count: filteredSlots.length,
                          selected_date: createMultiTaskForm.selected_time_slot_date,
                          selectedDateStr,
                          service_id: createMultiTaskForm.service_id,
                          sample_slot_dates: sampleSlotDates,
                          first_few_slots: availableTimeSlots.slice(0, 3).map((s: any) => ({
                            id: s.id,
                            slot_start_datetime: s.slot_start_datetime,
                            slot_date: s.slot_date,
                            converted_date: (() => {
                              const slotStartStr = s.slot_start_datetime || (s.slot_date + 'T' + s.start_time + 'Z');
                              try {
                                let dateStr = TimeHandlerV2.formatUtcToLocal(slotStartStr, 'YYYY-MM-DD', 'Europe/London');
                                // 去掉时区后缀
                                if (dateStr.includes(' (GMT)') || dateStr.includes(' (BST)')) {
                                  dateStr = dateStr.replace(' (GMT)', '').replace(' (BST)', '');
                                }
                                return dateStr;
                              } catch {
                                return s.slot_date;
                              }
                            })()
                          }))
                        }); // 调试日志
                        
                        return filteredSlots.length === 0 ? (
                          <div style={{ 
                            padding: '20px', 
                            textAlign: 'center', 
                            color: '#e53e3e',
                            background: '#fef2f2',
                            borderRadius: '8px',
                            border: '1px solid #fecaca',
                          }}>
                            {availableTimeSlots.length === 0 ? (
                              <>
                                该服务还没有生成时间段
                                <div style={{ marginTop: '8px', fontSize: '12px', color: '#718096' }}>
                                  提示：请先在"服务管理"页面批量创建时间段，时间段才会显示在这里
                                </div>
                              </>
                            ) : (
                              <>
                                该日期暂无可用时间段
                                <div style={{ marginTop: '8px', fontSize: '12px', color: '#718096' }}>
                                  提示：共有 {availableTimeSlots.length} 个时间段，但当前日期没有匹配的时间段
                                </div>
                              </>
                            )}
                          </div>
                        ) : (
                        <div style={{ 
                          display: 'grid', 
                          gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', 
                          gap: '12px',
                          maxHeight: '200px',
                          overflowY: 'auto',
                        }}>
                          {filteredSlots.map((slot: any) => {
                              const isFull = slot.current_participants >= slot.max_participants;
                              const isExpired = slot.is_expired === true; // 时间段已过期
                              const isDisabled = isFull || isExpired; // 已满或已过期都不可选
                              const isSelected = createMultiTaskForm.selected_time_slot_id === slot.id;
                              const selectedService = services.find(s => s.id === createMultiTaskForm.service_id);
                              
                              // 使用UTC时间转换为英国时间显示
                              const startTimeStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                              const endTimeStr = slot.slot_end_datetime || (slot.slot_date + 'T' + slot.end_time + 'Z');
                              const startTimeUK = TimeHandlerV2.formatUtcToLocal(
                                startTimeStr.includes('T') ? startTimeStr : `${startTimeStr}T00:00:00Z`,
                                'HH:mm',
                                'Europe/London'
                              );
                              const endTimeUK = TimeHandlerV2.formatUtcToLocal(
                                endTimeStr.includes('T') ? endTimeStr : `${endTimeStr}T00:00:00Z`,
                                'HH:mm',
                                'Europe/London'
                              );
                              
                              return (
                                <button
                                  key={slot.id}
                                  type="button"
                                  onClick={() => !isDisabled && setCreateMultiTaskForm({ 
                                    ...createMultiTaskForm, 
                                    selected_time_slot_id: slot.id 
                                  })}
                                  disabled={isDisabled}
                                  style={{
                                    padding: '12px',
                                    border: `2px solid ${isSelected ? '#3b82f6' : isDisabled ? '#e2e8f0' : '#cbd5e0'}`,
                                    borderRadius: '8px',
                                    background: isSelected ? '#eff6ff' : isDisabled ? '#f7fafc' : '#fff',
                                    cursor: isDisabled ? 'not-allowed' : 'pointer',
                                    textAlign: 'left',
                                    transition: 'all 0.2s',
                                    opacity: isDisabled ? 0.6 : 1,
                                  }}
                                  onMouseEnter={(e) => {
                                    if (!isDisabled) {
                                      e.currentTarget.style.borderColor = '#3b82f6';
                                      e.currentTarget.style.background = '#eff6ff';
                                    }
                                  }}
                                  onMouseLeave={(e) => {
                                    if (!isSelected) {
                                      e.currentTarget.style.borderColor = isDisabled ? '#e2e8f0' : '#cbd5e0';
                                      e.currentTarget.style.background = isDisabled ? '#f7fafc' : '#fff';
                                    }
                                  }}
                                >
                                  <div style={{ fontWeight: 600, color: isExpired ? '#9ca3af' : '#1a202c', marginBottom: '4px', fontSize: '14px' }}>
                                    {startTimeUK} - {endTimeUK}
                                    {isExpired && <span style={{ marginLeft: '8px', fontSize: '12px', color: '#ef4444' }}>(已过期)</span>}
                                  </div>
                                  <div style={{ fontSize: '12px', color: '#718096', marginBottom: '4px' }}>
                                    {selectedService?.currency || 'GBP'} {slot.price_per_participant.toFixed(2)} / 人
                                  </div>
                                  <div style={{ fontSize: '12px', color: isExpired ? '#9ca3af' : (isFull ? '#e53e3e' : '#48bb78') }}>
                                    {isExpired ? '已过期' : (isFull ? '已满' : `${slot.current_participants}/${slot.max_participants} 人`)}
                                  </div>
                                </button>
                              );
                            })}
                        </div>
                        );
                      })()}
                    </div>
                  )}
                  </div>
                </details>
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
                    活动类型
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
                    
                    // 验证参与者数量（如果服务有时间段）
                    if (selectedService.has_time_slots) {
                      // 固定时间段服务：验证最大参与者数不能超过服务的每个时间段最大参与者数
                      // 注意：任务达人创建活动时不需要选择具体时间段，时间段由用户申请时选择
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
                      // 再次验证service_id（防止在异步操作过程中丢失）
                      if (!createMultiTaskForm.service_id || !selectedService) {
                        message.error('请选择关联服务');
                        return;
                      }
                      
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
                        expert_service_id: createMultiTaskForm.service_id, // 确保使用正确的service_id
                        max_participants: createMultiTaskForm.max_participants,
                        min_participants: createMultiTaskForm.min_participants,
                        completion_rule: 'all',
                        ...timeSlotConfig,
                      };
                      
                      // 调试日志
                      console.log('创建多人活动 - 活动数据:', {
                        expert_service_id: taskData.expert_service_id,
                        service_id: createMultiTaskForm.service_id,
                        selectedService: selectedService,
                        taskData: taskData
                      });
                      
                      // 如果服务有时间段，必须选择时间段
                      if (selectedService.has_time_slots) {
                        // 验证必须选择时间段
                        if (!createMultiTaskForm.time_slot_selection_mode) {
                          message.error('时间段服务必须选择时间段');
                          return;
                        }
                        
                        // 添加时间段选择信息
                        taskData.time_slot_selection_mode = createMultiTaskForm.time_slot_selection_mode;
                        
                        if (createMultiTaskForm.time_slot_selection_mode === 'fixed') {
                          // 固定模式：必须选择至少一个时间段
                          if (!createMultiTaskForm.selected_time_slot_ids || createMultiTaskForm.selected_time_slot_ids.length === 0) {
                            message.error('固定模式必须选择至少一个时间段');
                            return;
                          }
                          taskData.selected_time_slot_ids = createMultiTaskForm.selected_time_slot_ids;
                        } else if (createMultiTaskForm.time_slot_selection_mode === 'recurring_daily') {
                          // 每天重复模式：必须指定时间段范围
                          if (!createMultiTaskForm.recurring_daily_time_ranges || createMultiTaskForm.recurring_daily_time_ranges.length === 0) {
                            message.error('每天重复模式必须指定至少一个时间段范围');
                            return;
                          }
                          taskData.recurring_daily_time_ranges = createMultiTaskForm.recurring_daily_time_ranges;
                        } else if (createMultiTaskForm.time_slot_selection_mode === 'recurring_weekly') {
                          // 每周重复模式：必须指定星期几和时间段范围
                          if (!createMultiTaskForm.recurring_weekly_weekdays || createMultiTaskForm.recurring_weekly_weekdays.length === 0) {
                            message.error('每周重复模式必须选择至少一个星期几');
                            return;
                          }
                          if (!createMultiTaskForm.recurring_weekly_time_ranges || createMultiTaskForm.recurring_weekly_time_ranges.length === 0) {
                            message.error('每周重复模式必须指定至少一个时间段范围');
                            return;
                          }
                          taskData.recurring_weekly_weekdays = createMultiTaskForm.recurring_weekly_weekdays;
                          taskData.recurring_weekly_time_ranges = createMultiTaskForm.recurring_weekly_time_ranges;
                        }
                        
                        // 添加自动添加新时间段选项和活动截至日期
                        taskData.auto_add_new_slots = createMultiTaskForm.auto_add_new_slots;
                        if (createMultiTaskForm.activity_end_date) {
                          taskData.activity_end_date = createMultiTaskForm.activity_end_date;
                        }
                      } else {
                        // 非固定时间段服务：使用截至日期
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
                      message.success('多人活动创建成功');
                      setShowCreateMultiTaskModal(false);
                      await loadMultiTasks();
                    } catch (err: any) {
                      console.error('创建多人活动失败:', err);
                      console.error('错误详情:', {
                        response: err.response?.data,
                        service_id: createMultiTaskForm.service_id,
                        selectedService: selectedService
                      });
                      const errorMessage = err.response?.data?.detail || err.message || '创建失败';
                      message.error(errorMessage);
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

      {/* 时间段管理弹窗 */}
      {showTimeSlotManagement && selectedServiceForTimeSlot && (
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
          onClick={() => {
            setShowTimeSlotManagement(false);
            setSelectedServiceForTimeSlot(null);
            setTimeSlotManagementSlots([]);
            setTimeSlotManagementDate('');
          }}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              maxWidth: '900px',
              width: '90%',
              maxHeight: '90vh',
              overflowY: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>
                管理时间段 - {selectedServiceForTimeSlot.service_name}
              </h3>
              <button
                onClick={() => {
                  setShowTimeSlotManagement(false);
                  setSelectedServiceForTimeSlot(null);
                  setTimeSlotManagementSlots([]);
                  setTimeSlotManagementDate('');
                }}
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

            {/* 删除特定日期的时间段 */}
            <div style={{ marginBottom: '24px', padding: '16px', background: '#fef3c7', borderRadius: '8px', border: '1px solid #fde68a' }}>
              <div style={{ fontSize: '14px', fontWeight: 600, marginBottom: '12px', color: '#92400e' }}>
                🗑️ 删除特定日期的时间段
              </div>
              <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                <input
                  type="date"
                  value={timeSlotManagementDate}
                  onChange={(e) => setTimeSlotManagementDate(e.target.value)}
                  min={new Date().toISOString().split('T')[0]}
                  style={{
                    padding: '8px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '6px',
                    fontSize: '14px',
                  }}
                />
                <button
                  onClick={async () => {
                    if (!timeSlotManagementDate) {
                      message.warning('请选择要删除的日期');
                      return;
                    }
                    if (!window.confirm(`确定要删除 ${timeSlotManagementDate} 的所有时间段吗？`)) {
                      return;
                    }
                    await handleDeleteTimeSlotsByDate(selectedServiceForTimeSlot.id, timeSlotManagementDate);
                  }}
                  disabled={!timeSlotManagementDate || loadingTimeSlotManagement}
                  style={{
                    padding: '8px 16px',
                    background: timeSlotManagementDate && !loadingTimeSlotManagement ? '#ef4444' : '#cbd5e0',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '6px',
                    cursor: timeSlotManagementDate && !loadingTimeSlotManagement ? 'pointer' : 'not-allowed',
                    fontSize: '14px',
                    fontWeight: 500,
                  }}
                >
                  删除该日期所有时间段
                </button>
              </div>
              <div style={{ fontSize: '12px', color: '#92400e', marginTop: '8px' }}>
                💡 提示：删除后，该日期的时间段将不再显示。如果该日期有已申请的时间段，将无法删除。
              </div>
            </div>

            {/* 时间段列表（按日期分组） */}
            <div>
              <div style={{ fontSize: '14px', fontWeight: 600, marginBottom: '16px' }}>
                时间段列表（未来30天）
              </div>
              {loadingTimeSlotManagement ? (
                <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
              ) : timeSlotManagementSlots.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px', color: '#718096' }}>
                  暂无时间段，请先批量创建时间段
                </div>
              ) : (
                <div>
                  {(() => {
                    // 按日期分组
                    const groupedByDate: { [date: string]: any[] } = {};
                    timeSlotManagementSlots.forEach((slot: any) => {
                      const slotStartStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                      const slotDateUK = TimeHandlerV2.formatUtcToLocal(
                        slotStartStr.includes('T') ? slotStartStr : `${slotStartStr}T00:00:00Z`,
                        'YYYY-MM-DD',
                        'Europe/London'
                      );
                      if (!groupedByDate[slotDateUK]) {
                        groupedByDate[slotDateUK] = [];
                      }
                      groupedByDate[slotDateUK].push(slot);
                    });
                    
                    // 按日期排序
                    const sortedDates = Object.keys(groupedByDate).sort();
                    
                    return sortedDates.map((dateStr) => {
                      const daySlots = groupedByDate[dateStr];
                      const hasDeleted = daySlots.some((s: any) => s.is_manually_deleted);
                      const hasFull = daySlots.some((s: any) => s.current_participants >= s.max_participants);
                      
                      return (
                        <div
                          key={dateStr}
                          style={{
                            marginBottom: '16px',
                            padding: '16px',
                            border: `1px solid ${hasDeleted ? '#fecaca' : '#e2e8f0'}`,
                            borderRadius: '8px',
                            background: hasDeleted ? '#fef2f2' : '#fff',
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                            <div style={{ fontSize: '14px', fontWeight: 600, color: hasDeleted ? '#991b1b' : '#1a202c' }}>
                              {dateStr} {hasDeleted && '(已删除)'}
                            </div>
                            <div style={{ fontSize: '12px', color: '#718096' }}>
                              {daySlots.length} 个时间段
                            </div>
                          </div>
                          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: '8px' }}>
                            {daySlots.map((slot: any) => {
                              const isFull = slot.current_participants >= slot.max_participants;
                              const isExpired = slot.is_expired === true;
                              const isDeleted = slot.is_manually_deleted === true;
                              
                              const startTimeStr = slot.slot_start_datetime || (slot.slot_date + 'T' + slot.start_time + 'Z');
                              const endTimeStr = slot.slot_end_datetime || (slot.slot_date + 'T' + slot.end_time + 'Z');
                              const startTimeUK = TimeHandlerV2.formatUtcToLocal(
                                startTimeStr.includes('T') ? startTimeStr : `${startTimeStr}T00:00:00Z`,
                                'HH:mm',
                                'Europe/London'
                              );
                              const endTimeUK = TimeHandlerV2.formatUtcToLocal(
                                endTimeStr.includes('T') ? endTimeStr : `${endTimeStr}T00:00:00Z`,
                                'HH:mm',
                                'Europe/London'
                              );
                              
                              return (
                                <div
                                  key={slot.id}
                                  style={{
                                    padding: '10px',
                                    border: `1px solid ${isDeleted ? '#fecaca' : isFull || isExpired ? '#fde68a' : '#cbd5e0'}`,
                                    borderRadius: '6px',
                                    background: isDeleted ? '#fee2e2' : isFull || isExpired ? '#fef3c7' : '#f7fafc',
                                    fontSize: '12px',
                                  }}
                                >
                                  <div style={{ fontWeight: 600, marginBottom: '4px', color: isDeleted ? '#991b1b' : '#1a202c' }}>
                                    {startTimeUK} - {endTimeUK}
                                  </div>
                                  <div style={{ color: '#64748b', fontSize: '11px' }}>
                                    {slot.current_participants}/{slot.max_participants} 人
                                    {isFull && ' (已满)'}
                                    {isExpired && ' (已过期)'}
                                    {isDeleted && ' (已删除)'}
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      );
                    });
                  })()}
                </div>
              )}
            </div>
          </div>
        </div>
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

      {/* 设置关门日期弹窗 */}
      {showCloseDateModal && (
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
          onClick={() => setShowCloseDateModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              width: '90%',
              maxWidth: '500px',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '18px', fontWeight: 600 }}>设置关门日期</h3>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                日期
              </label>
              <input
                type="date"
                value={selectedDateForClose}
                disabled
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                  background: '#f3f4f6',
                }}
              />
            </div>
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                关门原因（可选）
              </label>
              <textarea
                value={closeDateReason}
                onChange={(e) => setCloseDateReason(e.target.value)}
                placeholder="例如：休息日、节假日等"
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                  minHeight: '80px',
                  resize: 'vertical',
                }}
              />
            </div>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowCloseDateModal(false);
                  setSelectedDateForClose('');
                  setCloseDateReason('');
                }}
                style={{
                  padding: '10px 20px',
                  background: '#f3f4f6',
                  color: '#333',
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
                  if (!selectedDateForClose) {
                    message.error('请选择日期');
                    return;
                  }
                  try {
                    await createClosedDate({
                      closed_date: selectedDateForClose,
                      reason: closeDateReason || undefined,
                    });
                    message.success('已设置关门日期');
                    setShowCloseDateModal(false);
                    setSelectedDateForClose('');
                    setCloseDateReason('');
                    await loadSchedule();
                  } catch (err: any) {
                    message.error(err.response?.data?.detail || '设置失败');
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
                确定
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
    // 按周几设置时间段配置
    use_weekly_config: false, // 是否使用按周几配置
    weekly_time_slot_config: {
      monday: { enabled: true, start_time: '09:00', end_time: '17:00' },
      tuesday: { enabled: true, start_time: '09:00', end_time: '17:00' },
      wednesday: { enabled: true, start_time: '09:00', end_time: '17:00' },
      thursday: { enabled: true, start_time: '09:00', end_time: '17:00' },
      friday: { enabled: true, start_time: '09:00', end_time: '17:00' },
      saturday: { enabled: false, start_time: '12:00', end_time: '17:00' },
      sunday: { enabled: false, start_time: '12:00', end_time: '17:00' },
    } as { [key: string]: { enabled: boolean; start_time: string; end_time: string } },
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
      const weeklyConfig = service.weekly_time_slot_config || null;
      const useWeeklyConfig = !!weeklyConfig;
      
      // 初始化按周几配置
      const defaultWeeklyConfig = {
        monday: { enabled: true, start_time: '09:00', end_time: '17:00' },
        tuesday: { enabled: true, start_time: '09:00', end_time: '17:00' },
        wednesday: { enabled: true, start_time: '09:00', end_time: '17:00' },
        thursday: { enabled: true, start_time: '09:00', end_time: '17:00' },
        friday: { enabled: true, start_time: '09:00', end_time: '17:00' },
        saturday: { enabled: false, start_time: '12:00', end_time: '17:00' },
        sunday: { enabled: false, start_time: '12:00', end_time: '17:00' },
      };
      
      // 如果服务有按周几配置，使用它；否则使用默认配置
      const weeklyTimeSlotConfig = useWeeklyConfig ? {
        ...defaultWeeklyConfig,
        ...Object.keys(defaultWeeklyConfig).reduce((acc, day) => {
          const dayKey = day as keyof typeof defaultWeeklyConfig;
          const dayConfig = (weeklyConfig as any)?.[day] || defaultWeeklyConfig[dayKey];
          acc[dayKey] = {
            enabled: dayConfig.enabled !== false,
            start_time: dayConfig.start_time ? dayConfig.start_time.substring(0, 5) : defaultWeeklyConfig[dayKey].start_time,
            end_time: dayConfig.end_time ? dayConfig.end_time.substring(0, 5) : defaultWeeklyConfig[dayKey].end_time,
          };
          return acc;
        }, {} as typeof defaultWeeklyConfig)
      } : defaultWeeklyConfig;
      
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
        use_weekly_config: useWeeklyConfig,
        weekly_time_slot_config: weeklyTimeSlotConfig,
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
        use_weekly_config: false,
        weekly_time_slot_config: {
          monday: { enabled: true, start_time: '09:00', end_time: '17:00' },
          tuesday: { enabled: true, start_time: '09:00', end_time: '17:00' },
          wednesday: { enabled: true, start_time: '09:00', end_time: '17:00' },
          thursday: { enabled: true, start_time: '09:00', end_time: '17:00' },
          friday: { enabled: true, start_time: '09:00', end_time: '17:00' },
          saturday: { enabled: false, start_time: '12:00', end_time: '17:00' },
          sunday: { enabled: false, start_time: '12:00', end_time: '17:00' },
        },
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
        submitData.participants_per_slot = formData.participants_per_slot;
        
        // 如果使用按周几配置
        if (formData.use_weekly_config) {
          // 构建按周几配置（将时间格式转换为 "HH:MM:SS"）
          const weeklyConfig: { [key: string]: { enabled: boolean; start_time: string; end_time: string } } = {};
          Object.keys(formData.weekly_time_slot_config).forEach(day => {
            const dayConfig = formData.weekly_time_slot_config[day];
            weeklyConfig[day] = {
              enabled: dayConfig.enabled,
              start_time: dayConfig.start_time + ':00',
              end_time: dayConfig.end_time + ':00',
            };
          });
          submitData.weekly_time_slot_config = weeklyConfig;
          // 不设置统一的开始/结束时间
          submitData.time_slot_start_time = undefined;
          submitData.time_slot_end_time = undefined;
        } else {
          // 使用统一的开始/结束时间（向后兼容）
          submitData.time_slot_start_time = formData.time_slot_start_time + ':00';
          submitData.time_slot_end_time = formData.time_slot_end_time + ':00';
          submitData.weekly_time_slot_config = null;
        }
      } else {
        submitData.has_time_slots = false;
        submitData.weekly_time_slot_config = null;
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
      
      // 如果启用了时间段，自动批量创建未来30天的时间段
      if (formData.has_time_slots && savedServiceId) {
        try {
          const today = new Date();
          const futureDate = new Date(today);
          futureDate.setDate(today.getDate() + 30);
          
          await batchCreateServiceTimeSlots(savedServiceId, {
            start_date: today.toISOString().split('T')[0],
            end_date: futureDate.toISOString().split('T')[0],
            price_per_participant: formData.base_price,
          });
          message.success('时间段已自动创建（未来30天）');
        } catch (err: any) {
          console.error('批量创建时间段失败:', err);
          // 不阻止服务保存，只提示警告
          message.warning('服务已保存，但时间段创建失败，请稍后手动创建时间段');
        }
      }
      
      // 更新本地状态中的时间段配置（用于创建多人活动时快速获取）
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
              {/* 时间段时长和参与者数量（两种模式都需要） */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '16px' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                    时间段时长（分钟）*
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
                    每个时间段最多参与者 *
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

              {/* 配置模式选择 */}
              <div style={{ marginBottom: '16px', padding: '12px', background: '#f0f9ff', borderRadius: '6px' }}>
                <div style={{ display: 'flex', alignItems: 'center', marginBottom: '8px' }}>
                  <input
                    type="radio"
                    id="time_slot_mode_unified"
                    name="time_slot_mode"
                    checked={!formData.use_weekly_config}
                    onChange={() => setFormData({ ...formData, use_weekly_config: false })}
                    style={{ width: '16px', height: '16px', cursor: 'pointer', marginRight: '8px' }}
                  />
                  <label htmlFor="time_slot_mode_unified" style={{ fontSize: '13px', fontWeight: 500, cursor: 'pointer' }}>
                    统一时间（每天相同时间）
                  </label>
                </div>
                <div style={{ display: 'flex', alignItems: 'center' }}>
                  <input
                    type="radio"
                    id="time_slot_mode_weekly"
                    name="time_slot_mode"
                    checked={formData.use_weekly_config}
                    onChange={() => setFormData({ ...formData, use_weekly_config: true })}
                    style={{ width: '16px', height: '16px', cursor: 'pointer', marginRight: '8px' }}
                  />
                  <label htmlFor="time_slot_mode_weekly" style={{ fontSize: '13px', fontWeight: 500, cursor: 'pointer' }}>
                    按周几设置（不同工作日可设置不同时间）
                  </label>
                </div>
              </div>

              {/* 统一时间模式 */}
              {!formData.use_weekly_config && (
                <div style={{ marginTop: '12px' }}>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                    <div>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                        开始时间 *
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
                        结束时间 *
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
                </div>
              )}

              {/* 按周几设置模式 */}
              {formData.use_weekly_config && (
                <div style={{ marginTop: '12px' }}>
                  <div style={{ fontSize: '13px', fontWeight: 500, marginBottom: '12px', color: '#4a5568' }}>
                    设置每周的工作时间：
                  </div>
                  {[
                    { key: 'monday', label: '周一' },
                    { key: 'tuesday', label: '周二' },
                    { key: 'wednesday', label: '周三' },
                    { key: 'thursday', label: '周四' },
                    { key: 'friday', label: '周五' },
                    { key: 'saturday', label: '周六' },
                    { key: 'sunday', label: '周日' },
                  ].map(({ key, label }) => {
                    const dayKey = key as keyof typeof formData.weekly_time_slot_config;
                    const dayConfig = formData.weekly_time_slot_config[dayKey];
                    return (
                      <div
                        key={key}
                        style={{
                          display: 'grid',
                          gridTemplateColumns: '80px 1fr 1fr 1fr',
                          gap: '8px',
                          alignItems: 'center',
                          marginBottom: '10px',
                          padding: '10px',
                          background: dayConfig.enabled ? '#f0f9ff' : '#f7fafc',
                          borderRadius: '6px',
                          border: `1px solid ${dayConfig.enabled ? '#bfdbfe' : '#e2e8f0'}`,
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center' }}>
                          <input
                            type="checkbox"
                            checked={dayConfig.enabled}
                            onChange={(e) => {
                              const newConfig = { ...formData.weekly_time_slot_config };
                              newConfig[key] = {
                                ...dayConfig,
                                enabled: e.target.checked,
                              };
                              setFormData({ ...formData, weekly_time_slot_config: newConfig });
                            }}
                            style={{ width: '18px', height: '18px', cursor: 'pointer', marginRight: '6px' }}
                          />
                          <label style={{ fontSize: '13px', fontWeight: 500, cursor: 'pointer', color: dayConfig.enabled ? '#1e40af' : '#64748b' }}>
                            {label}
                          </label>
                        </div>
                        <div>
                          <input
                            type="time"
                            value={dayConfig.start_time}
                            onChange={(e) => {
                              const newConfig = { ...formData.weekly_time_slot_config };
                              newConfig[key] = { ...dayConfig, start_time: e.target.value };
                              setFormData({ ...formData, weekly_time_slot_config: newConfig });
                            }}
                            disabled={!dayConfig.enabled}
                            style={{
                              width: '100%',
                              padding: '6px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '4px',
                              fontSize: '12px',
                              background: dayConfig.enabled ? '#fff' : '#f1f5f9',
                              cursor: dayConfig.enabled ? 'text' : 'not-allowed',
                            }}
                          />
                        </div>
                        <div style={{ textAlign: 'center', fontSize: '12px', color: '#64748b' }}>至</div>
                        <div>
                          <input
                            type="time"
                            value={dayConfig.end_time}
                            onChange={(e) => {
                              const newConfig = { ...formData.weekly_time_slot_config };
                              newConfig[key] = { ...dayConfig, end_time: e.target.value };
                              setFormData({ ...formData, weekly_time_slot_config: newConfig });
                            }}
                            disabled={!dayConfig.enabled}
                            style={{
                              width: '100%',
                              padding: '6px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '4px',
                              fontSize: '12px',
                              background: dayConfig.enabled ? '#fff' : '#f1f5f9',
                              cursor: dayConfig.enabled ? 'text' : 'not-allowed',
                            }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
              
              <div style={{ fontSize: '12px', color: '#718096', marginTop: '12px' }}>
                💡 提示：启用时间段后，用户申请此服务时需要选择具体的日期和时间段。您可以在服务创建后批量创建时间段，系统会根据您的配置自动生成。
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

