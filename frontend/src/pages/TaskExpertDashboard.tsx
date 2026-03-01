/**
 * 任务达人管理后台
 * 路径: /task-experts/me/dashboard
 * 功能: 服务管理、申请管理
 */

import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { TimeHandlerV2 } from '../utils/timeUtils';
import {
  fetchCurrentUser,
  getTaskExpert,
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
  approveParticipant,
  rejectParticipant,
  approveExitRequest,
  rejectExitRequest,
  createExpertMultiParticipantTask,
  getServiceTimeSlots,
  getServiceTimeSlotsPublic,
  deleteTimeSlotsByDate,
  deleteServiceTimeSlot,
  getExpertDashboardStats,
  getExpertSchedule,
  createServiceTimeSlot,
  createClosedDate,
  getClosedDates,
  deleteClosedDate,
  deleteClosedDateByDate,
  deleteActivity,
} from '../api';
import LoginModal from '../components/LoginModal';
import TabButton from '../components/taskExpertDashboard/TabButton';
import StatCard from '../components/taskExpertDashboard/StatCard';
import { compressImage } from '../utils/imageCompression';
import api from '../api';
import styles from './TaskExpertDashboard.module.css';

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
  const [, setSelectedTaskId] = useState<number | null>(null); void setSelectedTaskId;
  // 按活动ID和任务ID分组存储参与者：{activityId: {taskId: [participants]}}
  const [taskParticipants, setTaskParticipants] = useState<{[activityId: number]: {[taskId: number]: any[]}}>({});
  // 存储活动关联的任务列表：{activityId: [tasks]}
  const [activityTasks, setActivityTasks] = useState<{[activityId: number]: any[]}>({});
  // 存储折叠的活动ID：Set<activityId>，已结束的活动默认折叠
  const [collapsedActivities, setCollapsedActivities] = useState<Set<number>>(new Set());
  
  // 达人积分余额
  const [expertPointsBalance, setExpertPointsBalance] = useState<number>(0);
  
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
    applicant_reward_amount?: number;  // 申请者奖励金额
    applicant_points_reward?: number;  // 申请者积分奖励
    currency: string;
    // 时间段选择相关
    time_slot_selection_mode?: 'fixed';
    selected_time_slot_ids?: number[];
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
    applicant_reward_amount: undefined as number | undefined,
    applicant_points_reward: undefined as number | undefined,
    time_slot_selection_mode: undefined,
    selected_time_slot_ids: [],
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
  // 新增时间段表单
  const [newTimeSlotForm, setNewTimeSlotForm] = useState({
    slot_date: '',
    slot_start_time: '12:00',
    slot_end_time: '14:00',
    max_participants: 1,
  });
  const [creatingTimeSlot, setCreatingTimeSlot] = useState(false);
  
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
      // 任务达人创建活动时，使用认证接口（需要登录）
      const slots = await getServiceTimeSlots(serviceId, params);
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
      
      setAvailableTimeSlots(slotsArray);
    } catch (err: any) {
      message.error('加载时间段失败');
      setAvailableTimeSlots([]);
    } finally {
      setLoadingTimeSlots(false);
    }
  };

  useEffect(() => {
    loadData();
    loadPendingRequest();
    loadExpertPointsBalance();
  }, []);
  
  // 加载达人积分余额
  const loadExpertPointsBalance = async () => {
    try {
      const response = await api.get('/api/coupon-points/points/balance');
      setExpertPointsBalance(response.data.balance || 0);
    } catch (err) {
      // 忽略积分余额获取错误，可能用户没有积分账户
    }
  };
  
  const loadPendingRequest = async () => {
    try {
      const request = await getMyProfileUpdateRequest();
        setPendingRequest(request);
      } catch (err: any) {
        // 如果没有待审核请求，忽略错误
      }
    };

  // 使用 useCallback 优化标签页切换处理函数
  const handleTabChange = useCallback((tab: 'dashboard' | 'services' | 'applications' | 'multi-tasks' | 'schedule') => {
    setActiveTab(tab);
  }, []);

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
      loadSchedule();
      const interval = setInterval(() => {
        if (!document.hidden) loadSchedule();
      }, 10000);
      return () => clearInterval(interval);
    }
    return () => {};
  }, [activeTab, user]);

  // 当打开创建多人活动模态框时，确保服务列表已加载
    useEffect(() => {
      if (showCreateMultiTaskModal && services.length === 0 && !loadingServices) {
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
      
      const startDate = scheduleStartDate ?? today.toISOString().split('T')[0] ?? '';
      const endDate = scheduleEndDate ?? futureDate.toISOString().split('T')[0] ?? '';
      if (!scheduleStartDate) setScheduleStartDate(startDate);
      if (!scheduleEndDate) setScheduleEndDate(endDate);
      
      // 分别处理两个请求，避免一个失败导致全部失败
      try {
        const scheduleDataResult = await getExpertSchedule({ start_date: startDate, end_date: endDate });
          setScheduleData(scheduleDataResult);
      } catch (err: any) {
        const errorMessage = err.response?.data?.detail || err.message || '未知错误';
        message.error(`加载时刻表数据失败: ${errorMessage}`);
      setScheduleData(null);
    }
      
      try {
          const closedDatesResult = await getClosedDates({ start_date: startDate, end_date: endDate });
          setClosedDates(Array.isArray(closedDatesResult) ? closedDatesResult : []);
        } catch (err: any) {
          // 关门日期加载失败不影响时刻表显示
          setClosedDates([]);
      }
      } catch (err: any) {
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
        // API返回的数据结构可能是 { items: [...] } 或直接是数组
        const servicesList = Array.isArray(data) ? data : (data.items || []);
      
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

  const _handleManageTimeSlots = async (service: Service) => {
    setSelectedServiceForTimeSlot(service);
    setShowTimeSlotManagement(true);
    await loadTimeSlotManagement(service.id);
  }; void _handleManageTimeSlots;

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
        groupedByDate[slotDateUK]!.push(slot);
      });
        setTimeSlotManagementSlots(slotsArray);
      } catch (err: any) {
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

  const handleDeleteSingleTimeSlot = useCallback(async (serviceId: number, timeSlotId: number) => {
    if (!window.confirm('确定要删除这个时间段吗？')) {
      return;
    }
    try {
      await deleteServiceTimeSlot(serviceId, timeSlotId);
      message.success('时间段已删除');
      // 重新加载时间段
      await loadTimeSlotManagement(serviceId);
    } catch (err: any) {
      message.error(err.response?.data?.detail || '删除失败');
    }
  }, []);

  // 优化：使用useMemo计算时间段统计
  const timeSlotStats = useMemo(() => {
    if (timeSlotManagementSlots.length === 0) {
      return null;
    }
    const total = timeSlotManagementSlots.length;
    const available = timeSlotManagementSlots.filter((s: any) => 
      !s.is_manually_deleted && 
      !s.is_expired && 
      s.current_participants < s.max_participants
    ).length;
    const full = timeSlotManagementSlots.filter((s: any) => 
      !s.is_manually_deleted && 
      !s.is_expired && 
      s.current_participants >= s.max_participants
    ).length;
    const expired = timeSlotManagementSlots.filter((s: any) => s.is_expired).length;
    const deleted = timeSlotManagementSlots.filter((s: any) => s.is_manually_deleted).length;
    return { total, available, full, expired, deleted };
  }, [timeSlotManagementSlots]);

  // 优化：使用useCallback优化关闭弹窗函数
  const handleCloseTimeSlotModal = useCallback(() => {
    setShowTimeSlotManagement(false);
    setSelectedServiceForTimeSlot(null);
    setTimeSlotManagementSlots([]);
    setTimeSlotManagementDate('');
    setNewTimeSlotForm({
      slot_date: '',
      slot_start_time: '12:00',
      slot_end_time: '14:00',
      max_participants: 1,
    });
  }, []);

  // 优化：使用useMemo优化时间段分组计算
  const groupedTimeSlots = useMemo(() => {
    if (timeSlotManagementSlots.length === 0) {
      return [];
    }
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
      groupedByDate[slotDateUK]!.push(slot);
    });
    return Object.keys(groupedByDate).sort().map((dateStr) => ({
      date: dateStr,
      slots: groupedByDate[dateStr] ?? [],
    }));
  }, [timeSlotManagementSlots]);

  // 优化：使用useCallback优化删除日期时间段函数
  const handleDeleteTimeSlotsByDateClick = useCallback(async () => {
    if (!timeSlotManagementDate) {
      message.warning('请选择要删除的日期');
      return;
    }
    if (!window.confirm(`确定要删除 ${timeSlotManagementDate} 的所有时间段吗？`)) {
      return;
    }
    if (selectedServiceForTimeSlot) {
      await handleDeleteTimeSlotsByDate(selectedServiceForTimeSlot.id, timeSlotManagementDate);
    }
  }, [timeSlotManagementDate, selectedServiceForTimeSlot]);

  const handleDeleteService = async (serviceId: number) => {
    if (!window.confirm('确定要删除这个服务吗？')) {
      return;
    }
    
    try {
      await deleteTaskExpertService(serviceId);
      message.success('服务已删除');
        loadServices();
      } catch (err: any) {
        const errorMessage = err.response?.data?.detail || err.message || '删除服务失败';
      // 显示更详细的错误信息，400错误显示更长时间
      if (err.response?.status === 400) {
        message.error(errorMessage, 5); // 显示5秒，让用户有足够时间阅读
      } else {
        message.error(errorMessage);
      }
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
        loadApplications().catch(() => {
          // 如果刷新失败，恢复原状态
          setApplications(originalApplications);
      });
    } catch (err: any) {
      setApplications(originalApplications);
      message.error(err?.response?.data?.detail || '拒绝申请失败');
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
        return;
      }
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
        setMultiTasks(activities);
      
      // 将已结束的活动默认添加到折叠集合中
      const completedActivityIds = activities
        .filter((activity: any) => activity.status === 'completed' || activity.status === 'cancelled')
        .map((activity: any) => activity.id);
      setCollapsedActivities(new Set(completedActivityIds));
      
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
            
            tasksMap[activity.id] = relatedTasks;
            
            // 为每个任务加载参与者（按任务分组）
            if (!participantsMap[activity.id]) {
              participantsMap[activity.id] = {};
            }
            
            for (const task of relatedTasks) {
              // 只加载多人任务的参与者
              if (task.is_multi_participant) {
                try {
                  const participantsData = await getTaskParticipants(task.id);
                  if (!participantsMap[activity.id]) participantsMap[activity.id] = {};
                  const actMap = participantsMap[activity.id]!;
                  actMap[task.id] = participantsData?.participants ?? [];
                } catch (_error: any) {
                  if (!participantsMap[activity.id]) participantsMap[activity.id] = {};
                  const actMap = participantsMap[activity.id]!;
                  actMap[task.id] = [];
                }
              } else {
                // 非多人任务不需要加载参与者
                if (!participantsMap[activity.id]) participantsMap[activity.id] = {};
                participantsMap[activity.id]![task.id] = [];
              }
            }
          } catch (error) {
            participantsMap[activity.id] = {};
            tasksMap[activity.id] = [];
          }
        })
      );
      setTaskParticipants(participantsMap);
      setActivityTasks(tasksMap);
    } catch (err: any) {
                      message.error('加载多人活动列表失败');
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

  const _getStatusColor = (status: string) => {
    const colorMap: { [key: string]: string } = {
      pending: '#f59e0b',
      negotiating: '#3b82f6',
      price_agreed: '#10b981',
      approved: '#10b981',
      rejected: '#ef4444',
      cancelled: '#6b7280',
    };
    return colorMap[status] || '#6b7280';
  }; void _getStatusColor;

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
      // 压缩头像图片
      const compressedFile = await compressImage(avatarFile, {
        maxSizeMB: 0.5, // 头像压缩到0.5MB
        maxWidthOrHeight: 800, // 头像最大800px
      });
      
      const formData = new FormData();
      formData.append('image', compressedFile);
      
      // 任务达人头像上传：传递expert_id（即user.id）作为resource_id
      const expertId = user?.id || expert?.id;
      const uploadUrl = expertId 
        ? `/api/v2/upload/image?category=expert_avatar&resource_id=${expertId}`
        : '/api/v2/upload/image?category=expert_avatar';
      
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
        {t('common.loading')}
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
    <div className={styles.container}>
      <div className={styles.contentWrapper}>
        {/* 头部 */}
        <div className={styles.headerCard}>
          <div className={styles.headerContent}>
            <div>
              <h1 className={styles.title}>
                任务达人管理后台
              </h1>
              <div className={styles.subtitle}>
                欢迎回来，{expert.expert_name || user?.name || '任务达人'}
              </div>
              {pendingRequest && (
                <div className={styles.pendingRequestNotice}>
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
              className={`${styles.button} ${styles.buttonPrimary}`}
            >
              编辑资料
            </button>
          </div>
        </div>


        {/* 标签页 */}
        <div className={styles.tabsContainer}>
          <TabButton
            label="仪表盘"
            isActive={activeTab === 'dashboard'}
            onClick={() => handleTabChange('dashboard')}
            icon="📊"
          />
          <TabButton
            label="服务管理"
            isActive={activeTab === 'services'}
            onClick={() => handleTabChange('services')}
          />
          <TabButton
            label="申请管理"
            isActive={activeTab === 'applications'}
            onClick={() => handleTabChange('applications')}
          />
          <TabButton
            label="多人活动"
            isActive={activeTab === 'multi-tasks'}
            onClick={() => handleTabChange('multi-tasks')}
          />
          <TabButton
            label="时刻表"
            isActive={activeTab === 'schedule'}
            onClick={() => handleTabChange('schedule')}
            icon="📅"
          />
        </div>

        {/* 仪表盘 */}
        {activeTab === 'dashboard' && (
          <div className={styles.contentCard}>
            <h2 className={styles.cardTitle}>仪表盘</h2>
            
            {loadingDashboardStats ? (
              <div className={styles.loading}>{t('common.loading')}</div>
            ) : dashboardStats ? (
              <div className={styles.statsGrid}>
                <StatCard
                  label="总服务数"
                  value={dashboardStats.total_services || 0}
                  subValue={`活跃服务: ${dashboardStats.active_services || 0}`}
                  gradient="Purple"
                />
                <StatCard
                  label="总申请数"
                  value={dashboardStats.total_applications || 0}
                  subValue={`待处理: ${dashboardStats.pending_applications || 0}`}
                  gradient="Pink"
                />
                <StatCard
                  label="多人任务"
                  value={dashboardStats.total_multi_tasks || 0}
                  subValue={`进行中: ${dashboardStats.in_progress_multi_tasks || 0}`}
                  gradient="Blue"
                />
                <StatCard
                  label="总参与者"
                  value={dashboardStats.total_participants || 0}
                  gradient="Green"
                />
                <StatCard
                  label="未来30天时间段"
                  value={dashboardStats.upcoming_time_slots || 0}
                  subValue={`有参与者: ${dashboardStats.time_slots_with_participants || 0}`}
                  gradient="Yellow"
                />
              </div>
            ) : (
              <div className={styles.empty}>
                暂无数据
              </div>
            )}
          </div>
        )}

        {/* 服务管理 */}
        {activeTab === 'services' && (
          <div className={styles.contentCard}>
            <div className={styles.flexBetween} style={{ marginBottom: '24px' }}>
              <h2 className={styles.cardTitle} style={{ margin: 0 }}>我的服务</h2>
              <button
                onClick={handleCreateService}
                className={`${styles.button} ${styles.buttonPrimary}`}
              >
                + 创建服务
              </button>
            </div>

            {loadingServices ? (
              <div className={styles.loading}>{t('common.loading')}</div>
            ) : services.length === 0 ? (
              <div className={styles.empty}>
                暂无服务，点击"创建服务"按钮添加
              </div>
            ) : (
              <div className={styles.servicesGrid}>
                {services.map((service) => (
                  <div key={service.id} className={styles.serviceCard}>
                    <div className={styles.serviceCardHeader}>
                      <h3 className={styles.serviceName}>
                        {service.service_name}
                      </h3>
                      <span className={`${styles.serviceStatus} ${service.status === 'active' ? styles.serviceStatusActive : styles.serviceStatusInactive}`}>
                        {service.status === 'active' ? '上架' : '下架'}
                      </span>
                    </div>
                    
                    <div className={styles.serviceDescription}>
                      {service.description?.substring(0, 100)}
                      {service.description && service.description.length > 100 ? '...' : ''}
                    </div>
                    
                    <div className={styles.servicePriceRow}>
                      <div className={styles.servicePrice}>
                        {service.currency} {service.base_price.toFixed(2)}
                      </div>
                      <div className={styles.serviceApplicationCount}>
                        {service.application_count} 申请
                      </div>
                    </div>
                    
                    <div className={styles.serviceActions}>
                      {service.has_time_slots && (
                        <button
                          onClick={() => {
                            setSelectedServiceForTimeSlot(service);
                            setShowTimeSlotManagement(true);
                            loadTimeSlotManagement(service.id);
                            setNewTimeSlotForm({
                              slot_date: '',
                              slot_start_time: '12:00',
                              slot_end_time: '14:00',
                              max_participants: service.participants_per_slot || 1,
                            });
                          }}
                          className={`${styles.button} ${styles.buttonPrimary} ${styles.buttonSmall}`}
                          style={{ width: '100%', marginBottom: '8px' }}
                        >
                          管理时间段
                        </button>
                      )}
                      <div className={styles.serviceCardActions}>
                        <button
                          onClick={() => handleEditService(service)}
                          className={`${styles.button} ${styles.buttonSecondary} ${styles.buttonSmall}`}
                          style={{ flex: 1 }}
                        >
                          编辑
                        </button>
                        <button
                          onClick={() => handleDeleteService(service.id)}
                          className={`${styles.button} ${styles.buttonDanger} ${styles.buttonSmall}`}
                          style={{ flex: 1 }}
                        >
                          删除
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 申请管理 */}
        {activeTab === 'applications' && (
          <div className={styles.contentCard}>
            <h2 className={styles.cardTitle} style={{ margin: '0 0 24px 0' }}>收到的申请</h2>

            {loadingApplications ? (
              <div className={styles.loading}>{t('common.loading')}</div>
            ) : applications.length === 0 ? (
              <div className={styles.empty}>
                暂无申请
              </div>
            ) : (
              <div className={styles.applicationsList}>
                {applications.map((app) => {
                  const statusClass = app.status === 'pending' ? styles.applicationStatusPending :
                                    app.status === 'approved' ? styles.applicationStatusApproved :
                                    app.status === 'rejected' ? styles.applicationStatusRejected :
                                    app.status === 'negotiating' || app.status === 'price_agreed' ? styles.applicationStatusNegotiating :
                                    styles.applicationStatusPending;
                  
                  return (
                    <div key={app.id} className={styles.applicationCard}>
                      <div className={styles.applicationHeader}>
                        <div className={styles.applicationInfo}>
                          <div className={styles.applicationTitle}>
                            {app.service_name}
                          </div>
                          <div className={styles.applicationMeta}>
                            申请用户: {app.applicant_name || app.applicant_id}
                          </div>
                        </div>
                        <span className={`${styles.applicationStatus} ${statusClass}`}>
                          {getStatusText(app.status)}
                        </span>
                      </div>

                      {app.application_message && (
                        <div className={styles.applicationMessage}>
                          {app.application_message}
                        </div>
                      )}

                      <div className={styles.applicationPriceInfo}>
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

                      <div className={styles.applicationActions}>
                        {app.status === 'pending' && (
                          <>
                            <button
                              onClick={() => handleApproveApplication(app.id)}
                              className={`${styles.button} ${styles.buttonSuccess} ${styles.buttonSmall}`}
                            >
                              同意申请
                            </button>
                            <button
                              onClick={() => handleCounterOffer(app)}
                              className={`${styles.button} ${styles.buttonPrimary} ${styles.buttonSmall}`}
                            >
                              再次议价
                            </button>
                            <button
                              onClick={() => {
                                const reason = window.prompt('请输入拒绝原因（可选）');
                                handleRejectApplication(app.id, reason || undefined);
                              }}
                              className={`${styles.button} ${styles.buttonDanger} ${styles.buttonSmall}`}
                            >
                              拒绝申请
                            </button>
                          </>
                        )}
                        {app.status === 'price_agreed' && (
                          <button
                            onClick={() => handleApproveApplication(app.id)}
                            className={`${styles.button} ${styles.buttonSuccess} ${styles.buttonSmall}`}
                          >
                            创建任务
                          </button>
                        )}
                        {app.status === 'approved' && app.task_id && (
                          <button
                            onClick={() => navigate(`/tasks/${app.task_id}`)}
                            className={`${styles.button} ${styles.buttonPrimary} ${styles.buttonSmall}`}
                          >
                            查看任务
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

        {/* 多人活动管理 */}
        {activeTab === 'multi-tasks' && (
          <div className={styles.contentCard}>
            <div className={styles.flexBetween} style={{ marginBottom: '24px' }}>
              <h2 className={styles.cardTitle} style={{ margin: 0 }}>{t('taskExperts.myMultiTasks')}</h2>
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
                    applicant_reward_amount: undefined,
                    applicant_points_reward: undefined,
                  });
                  setShowCreateMultiTaskModal(true);
                }}
                className={`${styles.button} ${styles.buttonPrimary}`}
              >
                + {t('taskExperts.createMultiTask')}
              </button>
            </div>

            {loadingMultiTasks ? (
              <div className={styles.loading}>{t('common.loading')}</div>
            ) : multiTasks.length === 0 ? (
              <div className={styles.empty}>
                暂无多人活动
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {multiTasks.map((activity: any) => {
                  const tasks = activityTasks[activity.id] || [];
                  const participantsByTask = taskParticipants[activity.id] || {};
                  // 使用字符串比较，确保类型一致（expert_id 是字符串类型）
                  const isTaskManager = String(activity.expert_id) === String(user?.id);
                  
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
                  
                  const statusTagClass = activity.status === 'open' ? styles.activityTagOpen :
                                        activity.status === 'in_progress' ? styles.activityTagInProgress :
                                        activity.status === 'completed' ? styles.activityTagCompleted :
                                        activity.status === 'pending_review' ? styles.activityTagPendingReview :
                                        activity.status === 'rejected' ? styles.activityTagRejected :
                                        styles.activityTagCancelled;
                  
                  const isCollapsed = collapsedActivities.has(activity.id);
                  const toggleCollapse = () => {
                    setCollapsedActivities(prev => {
                      const newSet = new Set(prev);
                      if (newSet.has(activity.id)) {
                        newSet.delete(activity.id);
                      } else {
                        newSet.add(activity.id);
                      }
                      return newSet;
                    });
                  };
                  
                  return (
                    <div key={activity.id} className={styles.activityCard}>
                      <div className={styles.activityHeader}>
                        <div className={styles.activityInfo} style={{ flex: 1 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }} onClick={toggleCollapse}>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                toggleCollapse();
                              }}
                              style={{
                                background: 'transparent',
                                border: 'none',
                                cursor: 'pointer',
                                fontSize: '16px',
                                padding: '4px',
                                display: 'flex',
                                alignItems: 'center',
                                color: '#4a5568',
                                transition: 'transform 0.2s'
                              }}
                              title={isCollapsed ? '展开' : '折叠'}
                            >
                              {isCollapsed ? '▶' : '▼'}
                            </button>
                            <h3 className={styles.activityTitle} style={{ margin: 0, flex: 1 }}>
                              {activity.title}
                            </h3>
                          </div>
                          {/* 活动描述（简短） */}
                          {activity.description && (
                            <p className={styles.activityDescription}>
                              {activity.description}
                            </p>
                          )}
                          <div className={styles.activityTags}>
                            <span className={`${styles.activityTag} ${statusTagClass}`}>
                              {activity.status === 'open' ? '开放中' :
                               activity.status === 'in_progress' ? '进行中' :
                               activity.status === 'completed' ? '已完成' :
                               activity.status === 'pending_review' ? '待审核' :
                               activity.status === 'rejected' ? '已拒绝' :
                               '已取消'}
                            </span>
                            <span style={{ fontSize: '14px', color: '#4a5568' }}>
                              👥 {currentParticipantsCount} / {activity.max_participants || 1}
                            </span>
                            {/* 活动类型标识 */}
                            {activity.has_time_slots && (
                              <span className={`${styles.activityTag} ${styles.activityTagTimeSlot}`}>
                                ⏰ 多时间段
                              </span>
                            )}
                            {/* 奖励申请者标识 */}
                            {(activity as any).reward_applicants && (
                              <span style={{ 
                                fontSize: '12px', 
                                background: '#dcfce7', 
                                color: '#166534', 
                                padding: '2px 8px', 
                                borderRadius: '4px',
                                fontWeight: 500,
                              }}>
                                🎁 奖励申请者
                                {(activity as any).applicant_reward_amount && (
                                  <span style={{ marginLeft: '4px' }}>
                                    ({activity.currency || 'GBP'}{(activity as any).applicant_reward_amount})
                                  </span>
                                )}
                                {(activity as any).applicant_points_reward && (
                                  <span style={{ marginLeft: '4px' }}>
                                    ({(activity as any).applicant_points_reward} 积分)
                                  </span>
                                )}
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

                      {/* 参与者列表（按任务分组显示）- 根据折叠状态显示/隐藏 */}
                      {tasks.length > 0 && !isCollapsed && (
                        <div className={styles.taskGroup}>
                          <h4 className={styles.taskGroupTitle}>
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
                                <div key={task.id} className={styles.taskItem}>
                                  <div className={styles.taskItemHeader}>
                                    任务 #{task.id} - {task.title || '未命名任务'}
                                    <span className={styles.taskItemMeta}>
                                      {isMultiParticipant ? `(${taskParticipants.length} 个参与者)` : '(单个任务)'}
                                    </span>
                                    {/* 显示时间段信息（如果有） */}
                                    {(task.time_slot_id || (task.time_slot_relations && task.time_slot_relations.length > 0)) && (
                                      <span className={styles.taskItemTimeSlot}>
                                        ⏰ 时间段 {task.time_slot_id || (task.time_slot_relations?.[0]?.time_slot_id)}
                                      </span>
                                    )}
                                  </div>
                                  <div className={styles.participantsList}>
                                    {/* 多人任务：显示参与者列表 */}
                                    {isMultiParticipant && taskParticipants.map((participant: any) => (
                                      <div key={participant.id} className={styles.participantCard}>
                                        <div className={styles.participantInfo}>
                                          <div className={styles.participantName}>
                                            {participant.user_name || 'Unknown'}
                                          </div>
                                          <div className={styles.participantStatus}>
                                            状态: {participant.status === 'pending' ? '待审核' :
                                                   participant.status === 'accepted' ? '已接受' :
                                                   participant.status === 'in_progress' ? '进行中' :
                                                   participant.status === 'completed' ? '已完成' :
                                                   participant.status === 'exit_requested' ? '退出申请中' :
                                                   '已退出'}
                                          </div>
                                        </div>
                                        <div className={styles.participantActions}>
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

                      {/* 操作按钮 - 根据折叠状态显示/隐藏 */}
                      {!isCollapsed && (
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
                        {/* 删除活动按钮（只有活动创建者可以删除，已取消的活动除外） */}
                        {isTaskManager && activity.status !== 'cancelled' && (
                          <button
                            onClick={async () => {
                              const confirmMessage = activity.status === 'completed' 
                                ? `确定要删除已完成的活动"${activity.title}"吗？\n\n删除后活动记录将被移除。`
                                : `确定要删除活动"${activity.title}"吗？\n\n删除后：\n- 活动将被取消\n- 所有未开始的任务将被自动取消\n- 已开始的任务不受影响`;
                              if (!window.confirm(confirmMessage)) {
                                return;
                              }
                              try {
                                await deleteActivity(activity.id);
                                message.success('活动已删除');
                                await loadMultiTasks();
                              } catch (err: any) {
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
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* 时刻表 */}
        {activeTab === 'schedule' && (
          <div className={styles.contentCard}>
            <div className={styles.scheduleHeader}>
              <h2 className={styles.cardTitle} style={{ margin: 0 }}>时刻表</h2>
              <div className={styles.scheduleControls}>
                <input
                  type="date"
                  value={scheduleStartDate || new Date().toISOString().split('T')[0]}
                  onChange={(e) => {
                    setScheduleStartDate(e.target.value);
                    if (e.target.value && (scheduleEndDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])) {
                      loadSchedule();
                    }
                  }}
                  className={styles.scheduleDateInput}
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
                  className={styles.scheduleDateInput}
                />
                <button
                  onClick={loadSchedule}
                  className={styles.scheduleRefreshButton}
                >
                  刷新
                </button>
              </div>
            </div>

            {loadingSchedule ? (
              <div className={styles.loading}>{t('common.loading')}</div>
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
                    groupedByDate[date]!.push(item);
                  });

                  const sortedDates = Object.keys(groupedByDate).sort();

                  return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                      {sortedDates.map((date) => {
                        const items = groupedByDate[date] ?? [];
                        const dateObj = new Date(date);
                        const dayName = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][dateObj.getDay()];
                        
                        return (
                          <div key={date} className={styles.scheduleDateGroup}>
                            <div className={styles.scheduleDateHeader}>
                              <span className={styles.scheduleDateTitle}>{date} ({dayName})</span>
                              <div className={styles.scheduleDateActions}>
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
                                              message.error(err.response?.data?.detail || err.message || '删除失败，请重试');
                                            }
                                          }}
                                          disabled={loadingSchedule}
                                          className={`${styles.scheduleDateActionButton} ${loadingSchedule ? '' : ''}`}
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
                                        className={`${styles.scheduleDateActionButton} ${isClosed ? styles.scheduleDateActionButtonDanger : ''}`}
                                      >
                                        {isClosed ? '已关门 - 点击取消' : '设置关门'}
                                      </button>
                                    </>
                                  );
                                })()}
                              </div>
                            </div>
                            <div className={styles.scheduleDateContent}>
                              {items.map((item: any) => {
                                const statusBadgeClass = item.is_expired ? styles.scheduleItemStatusExpired :
                                                       item.current_participants >= item.max_participants ? styles.scheduleItemStatusFull :
                                                       styles.scheduleItemStatusAvailable;
                                
                                return (
                                  <div
                                    key={item.id}
                                    className={`${styles.scheduleItem} ${item.is_task ? styles.scheduleItemTask : ''}`}
                                  >
                                    <div className={styles.scheduleItemHeader}>
                                      <div className={styles.scheduleItemInfo}>
                                        <div className={styles.scheduleItemTitle}>
                                          {item.service_name}
                                        </div>
                                        {item.start_time && item.end_time && (
                                          <div className={styles.scheduleItemTime}>
                                            ⏰ {item.start_time} - {item.end_time}
                                          </div>
                                        )}
                                        {item.deadline && (
                                          <div className={styles.scheduleItemTime}>
                                            📅 截止: {new Date(item.deadline).toLocaleString('zh-CN')}
                                          </div>
                                        )}
                                      </div>
                                      <div className={styles.scheduleItemStatus}>
                                        <div className={`${styles.scheduleItemStatusBadge} ${statusBadgeClass}`}>
                                          {item.is_expired ? '已过期' :
                                           item.current_participants >= item.max_participants ? '已满' :
                                           '可预约'}
                                        </div>
                                        {item.task_status && (
                                          <div className={styles.scheduleItemStatusBadge} style={{
                                            background: item.task_status === 'in_progress' ? '#dbeafe' : '#f3f4f6',
                                            color: item.task_status === 'in_progress' ? '#1e40af' : '#4a5568',
                                          }}>
                                            {item.task_status === 'open' ? '开放中' :
                                             item.task_status === 'in_progress' ? '进行中' : item.task_status}
                                          </div>
                                        )}
                                      </div>
                                    </div>
                                    <div className={styles.scheduleItemFooter}>
                                      <div className={styles.scheduleItemParticipants}>
                                        👥 参与者: {item.current_participants} / {item.max_participants}
                                      </div>
                                      <div className={styles.scheduleItemActions}>
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
                                            className={`${styles.button} ${styles.buttonDanger} ${styles.buttonSmall}`}
                                          >
                                            删除
                                          </button>
                                        )}
                                        {item.is_task && (
                                          <button
                                            onClick={() => navigate(`/tasks/${item.id.replace('task_', '')}`)}
                                            className={`${styles.button} ${styles.buttonPrimary} ${styles.buttonSmall}`}
                                          >
                                            查看任务
                                          </button>
                                        )}
                                      </div>
                                    </div>
                                  </div>
                                );
                              })}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  );
                })()}
              </div>
            ) : (
              <div className={styles.empty}>
                暂无时间段安排
              </div>
            )}
          </div>
        )}
      </div>

      {/* 创建多人活动弹窗 */}
      {showCreateMultiTaskModal && (
        <div
          className={styles.modalOverlay}
          onClick={() => setShowCreateMultiTaskModal(false)}
        >
          <div
            className={styles.modalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <div className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>{t('taskExperts.createMultiTaskTitle')}</h3>
              <button
                onClick={() => setShowCreateMultiTaskModal(false)}
                className={styles.modalClose}
              >
                ×
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {/* 选择服务（必填） */}
              <div className={styles.formGroup}>
                <label className={styles.formLabel}>
                  关联服务 <span style={{ color: '#dc3545' }}>*</span>
                </label>
                <select
                  value={createMultiTaskForm.service_id || ''}
                  className={styles.formInput}
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
              <div className={styles.formGroup}>
                <label className={styles.formLabel}>
                  活动标题 <span style={{ color: '#dc3545' }}>*</span>
                </label>
                <input
                  type="text"
                  value={createMultiTaskForm.title}
                  onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, title: e.target.value })}
                  className={styles.formInput}
                  required
                />
              </div>

              {/* 活动描述 */}
              <div className={styles.formGroup}>
                <label className={styles.formLabel}>
                  活动描述 <span style={{ color: '#dc3545' }}>*</span>
                </label>
                <textarea
                  value={createMultiTaskForm.description}
                  onChange={(e) => setCreateMultiTaskForm({ ...createMultiTaskForm, description: e.target.value })}
                  className={styles.formTextarea}
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
                      此服务为时间段服务，必须选择时间段才能创建活动。请选择具体的固定时间段。
                    </div>
                    
                    {/* 时间段选择模式 */}
                    <div style={{ marginBottom: '12px' }}>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                        选择模式 <span style={{ color: '#dc3545' }}>*</span>
                      </label>
                      <select
                        value={createMultiTaskForm.time_slot_selection_mode || ''}
                        onChange={(e) => {
                          const mode = e.target.value as 'fixed' | '';
                          setCreateMultiTaskForm({
                            ...createMultiTaskForm,
                            time_slot_selection_mode: mode || undefined,
                            selected_time_slot_ids: [],
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
                            onChange={() => {
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
                              slotsByDate[dateStr]!.push(slot);
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
                                      {(slotsByDate[dateStr] ?? []).map((slot: any) => {
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
                            return false;
                          }
                          
                          const isDateMatch = slotDateUK === selectedDateStr;
                          
                          // 输出前几个和匹配的时间段的详细日志
                          if (isDateMatch || slot.id <= 5) {
                          }
                          
                          return isDateMatch;
                        });
                        
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
                    <option value="Housekeeping">Housekeeping</option>
                    <option value="Campus Life">Campus Life</option>
                    <option value="Second-hand & Rental">Second-hand & Rental</option>
                    <option value="Errand Running">Errand Running</option>
                    <option value="Skill Service">Skill Service</option>
                    <option value="Social Help">Social Help</option>
                    <option value="Transportation">Transportation</option>
                    <option value="Pet Care">Pet Care</option>
                    <option value="Life Convenience">Life Convenience</option>
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
                <div style={{ 
                  padding: '16px', 
                  background: '#f0fdf4', 
                  borderRadius: '8px', 
                  border: '1px solid #86efac',
                  marginBottom: '16px'
                }}>
                  <div style={{ fontSize: '14px', fontWeight: 600, color: '#166534', marginBottom: '12px' }}>
                    🎁 申请者奖励设置
                  </div>
                  <p style={{ fontSize: '12px', color: '#15803d', marginBottom: '12px' }}>
                    完成任务后，申请者将获得以下奖励（由您支付）
                  </p>
                  
                  {/* 奖励类型 */}
                  <div style={{ marginBottom: '12px' }}>
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

                  {/* 现金奖励设置（当reward_type包含cash时显示） */}
                  {(createMultiTaskForm.reward_type === 'cash' || createMultiTaskForm.reward_type === 'both') && (
                    <div style={{ marginBottom: '12px' }}>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                        每人现金奖励 (GBP)
                      </label>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={createMultiTaskForm.applicant_reward_amount || ''}
                        onChange={(e) => setCreateMultiTaskForm({ 
                          ...createMultiTaskForm, 
                          applicant_reward_amount: parseFloat(e.target.value) || undefined 
                        })}
                        style={{
                          width: '100%',
                          padding: '10px',
                          border: '1px solid #e2e8f0',
                          borderRadius: '6px',
                          fontSize: '14px',
                        }}
                        placeholder="例如: 10.00"
                      />
                    </div>
                  )}

                  {/* 积分奖励设置（当reward_type包含points时显示） */}
                  {(createMultiTaskForm.reward_type === 'points' || createMultiTaskForm.reward_type === 'both') && (
                    <div style={{ marginBottom: '12px' }}>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                        每人积分奖励
                      </label>
                      <input
                        type="number"
                        min="0"
                        value={createMultiTaskForm.applicant_points_reward || ''}
                        onChange={(e) => setCreateMultiTaskForm({ 
                          ...createMultiTaskForm, 
                          applicant_points_reward: parseInt(e.target.value) || undefined 
                        })}
                        style={{
                          width: '100%',
                          padding: '10px',
                          border: '1px solid #e2e8f0',
                          borderRadius: '6px',
                          fontSize: '14px',
                        }}
                        placeholder="例如: 100"
                      />
                      {/* 显示积分余额和预扣提示 */}
                      <div style={{ 
                        marginTop: '8px', 
                        padding: '8px 12px', 
                        background: '#fffbeb', 
                        borderRadius: '6px',
                        border: '1px solid #fcd34d',
                      }}>
                        <div style={{ fontSize: '12px', color: '#92400e' }}>
                          💰 您当前的积分余额: <strong>{expertPointsBalance}</strong> 积分
                        </div>
                        {createMultiTaskForm.applicant_points_reward && createMultiTaskForm.max_participants > 0 && (
                          <>
                            <div style={{ fontSize: '12px', color: '#92400e', marginTop: '4px' }}>
                              📝 预扣积分: <strong>{createMultiTaskForm.applicant_points_reward * createMultiTaskForm.max_participants}</strong> 积分 
                              （{createMultiTaskForm.applicant_points_reward} × {createMultiTaskForm.max_participants} 人）
                            </div>
                            {(createMultiTaskForm.applicant_points_reward * createMultiTaskForm.max_participants) > expertPointsBalance && (
                              <div style={{ fontSize: '12px', color: '#dc2626', marginTop: '4px', fontWeight: 600 }}>
                                ⚠️ 积分余额不足！请减少每人积分奖励或最大参与人数。
                              </div>
                            )}
                          </>
                        )}
                        <div style={{ fontSize: '11px', color: '#78716c', marginTop: '4px' }}>
                          提示: 创建活动时会预扣积分，未使用的积分会在活动取消或完成后返还。
                        </div>
                      </div>
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
                </div>
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
                        }
                      } else {
                        // 非固定时间段服务：使用截至日期
                        taskData.deadline = new Date(createMultiTaskForm.deadline).toISOString();
                      }
                      
                      // 如果勾选了"奖励申请者"，添加奖励相关字段
                      if (createMultiTaskForm.reward_applicants) {
                        taskData.reward_applicants = true;
                        taskData.reward_type = createMultiTaskForm.reward_type;
                        taskData.reward_distribution = createMultiTaskForm.reward_distribution;
                        
                        // 添加申请者现金奖励（如果reward_type包含cash）
                        if (createMultiTaskForm.reward_type === 'cash' || createMultiTaskForm.reward_type === 'both') {
                          taskData.applicant_reward_amount = createMultiTaskForm.applicant_reward_amount || 0;
                        }
                        
                        // 添加申请者积分奖励（如果reward_type包含points）
                        if (createMultiTaskForm.reward_type === 'points' || createMultiTaskForm.reward_type === 'both') {
                          const pointsReward = createMultiTaskForm.applicant_points_reward || 0;
                          const maxParticipants = createMultiTaskForm.max_participants || 1;
                          const requiredPoints = pointsReward * maxParticipants;
                          
                          // 前端验证积分余额是否足够
                          if (pointsReward > 0 && requiredPoints > expertPointsBalance) {
                            message.error(`积分余额不足！需要预扣 ${requiredPoints} 积分（${pointsReward} × ${maxParticipants} 人），但您当前余额为 ${expertPointsBalance} 积分。`);
                            return;
                          }
                          
                          taskData.applicant_points_reward = pointsReward;
                        }
                        
                        // 奖励申请者模式下，服务可能是免费的或者申请者还需要支付一定费用
                        // 这里保留原有价格逻辑用于展示
                        taskData.original_price_per_participant = originalPrice;
                        if (discount > 0) {
                          taskData.discount_percentage = discount;
                          taskData.discounted_price_per_participant = discountedPrice;
                        }
                      } else {
                        // 如果没有勾选"奖励申请者"，使用默认值（商业服务任务，达人收钱）
                        taskData.reward_applicants = false;
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
                      // 刷新积分余额（因为可能有预扣）
                      loadExpertPointsBalance();
                      await loadMultiTasks();
                    } catch (err: any) {
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
          className={styles.timeSlotModalOverlay}
          onClick={handleCloseTimeSlotModal}
        >
          <div
            className={styles.timeSlotModalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <div className={styles.timeSlotModalHeader}>
              <div>
                <h3 className={styles.timeSlotModalTitle}>
                  管理时间段 - {selectedServiceForTimeSlot.service_name}
                </h3>
                {timeSlotStats && (
                  <div className={styles.timeSlotStats}>
                    <span className={styles.timeSlotStatItem}>总计: <strong>{timeSlotStats.total}</strong></span>
                    <span className={`${styles.timeSlotStatItem} ${styles.timeSlotStatAvailable}`}>可用: <strong>{timeSlotStats.available}</strong></span>
                    <span className={`${styles.timeSlotStatItem} ${styles.timeSlotStatFull}`}>已满: <strong>{timeSlotStats.full}</strong></span>
                    <span className={`${styles.timeSlotStatItem} ${styles.timeSlotStatExpired}`}>已过期: <strong>{timeSlotStats.expired}</strong></span>
                    {timeSlotStats.deleted > 0 && (
                      <span className={`${styles.timeSlotStatItem} ${styles.timeSlotStatDeleted}`}>已删除: <strong>{timeSlotStats.deleted}</strong></span>
                    )}
                  </div>
                )}
              </div>
              <button
                onClick={handleCloseTimeSlotModal}
                className={styles.timeSlotModalClose}
                aria-label="关闭"
              >
                ×
              </button>
            </div>

            {/* 新增时间段 */}
            <div className={styles.timeSlotFormSection}>
              <div className={styles.timeSlotFormTitle}>
                ➕ 新增时间段
              </div>
              <div className={styles.timeSlotFormGrid}>
                <div className={styles.timeSlotFormField}>
                  <label className={styles.timeSlotFormLabel}>
                    日期（英国时间） <span className={styles.timeSlotFormLabelRequired}>*</span>
                  </label>
                  <input
                    type="date"
                    value={newTimeSlotForm.slot_date}
                    onChange={(e) => setNewTimeSlotForm({ ...newTimeSlotForm, slot_date: e.target.value })}
                    min={new Date().toISOString().split('T')[0]}
                    className={styles.timeSlotFormInput}
                  />
                </div>
                <div className={styles.timeSlotFormField}>
                  <label className={styles.timeSlotFormLabel}>
                    开始时间 <span className={styles.timeSlotFormLabelRequired}>*</span>
                  </label>
                  <input
                    type="time"
                    value={newTimeSlotForm.slot_start_time}
                    onChange={(e) => setNewTimeSlotForm({ ...newTimeSlotForm, slot_start_time: e.target.value })}
                    className={styles.timeSlotFormInput}
                  />
                </div>
                <div className={styles.timeSlotFormField}>
                  <label className={styles.timeSlotFormLabel}>
                    结束时间 <span className={styles.timeSlotFormLabelRequired}>*</span>
                  </label>
                  <input
                    type="time"
                    value={newTimeSlotForm.slot_end_time}
                    onChange={(e) => setNewTimeSlotForm({ ...newTimeSlotForm, slot_end_time: e.target.value })}
                    className={styles.timeSlotFormInput}
                  />
                </div>
                <div className={styles.timeSlotFormField}>
                  <label className={styles.timeSlotFormLabel}>
                    最多参与者 <span className={styles.timeSlotFormLabelRequired}>*</span>
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={newTimeSlotForm.max_participants}
                    onChange={(e) => setNewTimeSlotForm({ ...newTimeSlotForm, max_participants: parseInt(e.target.value) || 1 })}
                    className={styles.timeSlotFormInput}
                  />
                </div>
                <button
                  onClick={async () => {
                    if (!newTimeSlotForm.slot_date) {
                      message.warning('请选择日期');
                      return;
                    }
                    if (!newTimeSlotForm.slot_start_time || !newTimeSlotForm.slot_end_time) {
                      message.warning('请设置开始时间和结束时间');
                      return;
                    }
                    if (newTimeSlotForm.max_participants <= 0) {
                      message.warning('参与者数量必须大于0');
                      return;
                    }
                    // 验证开始时间早于结束时间
                    const startTime = newTimeSlotForm.slot_start_time.split(':').map(Number);
                    const endTime = newTimeSlotForm.slot_end_time.split(':').map(Number);
                    const startMinutes = (startTime[0] ?? 0) * 60 + (startTime[1] ?? 0);
                    const endMinutes = (endTime[0] ?? 0) * 60 + (endTime[1] ?? 0);
                    if (startMinutes >= endMinutes) {
                      message.warning('开始时间必须早于结束时间');
                      return;
                    }
                    
                    setCreatingTimeSlot(true);
                    try {
                      await createServiceTimeSlot(selectedServiceForTimeSlot.id, {
                        slot_date: newTimeSlotForm.slot_date,
                        start_time: newTimeSlotForm.slot_start_time + ':00',
                        end_time: newTimeSlotForm.slot_end_time + ':00',
                        price_per_participant: selectedServiceForTimeSlot.base_price,
                        max_participants: newTimeSlotForm.max_participants,
                      });
                      message.success('时间段已创建');
                      // 重置表单
                      setNewTimeSlotForm({
                        slot_date: '',
                        slot_start_time: '12:00',
                        slot_end_time: '14:00',
                        max_participants: selectedServiceForTimeSlot.participants_per_slot || 1,
                      });
                      // 重新加载时间段列表
                      await loadTimeSlotManagement(selectedServiceForTimeSlot.id);
                    } catch (err: any) {
                      message.error(err.response?.data?.detail || '创建时间段失败');
                    } finally {
                      setCreatingTimeSlot(false);
                    }
                  }}
                  disabled={creatingTimeSlot}
                  className={styles.timeSlotFormButton}
                >
                  {creatingTimeSlot ? '创建中...' : '添加'}
                </button>
              </div>
              <div className={styles.timeSlotFormHint}>
                💡 提示：可以添加任意个特定日期的时间段。时间段配置（统一时间或按周几设置）由管理员在任务达人管理中设置。
              </div>
            </div>

            {/* 删除特定日期的时间段 */}
            <div className={styles.timeSlotDeleteSection}>
              <div className={styles.timeSlotDeleteTitle}>
                🗑️ 删除特定日期的时间段
              </div>
              <div className={styles.timeSlotDeleteControls}>
                <input
                  type="date"
                  value={timeSlotManagementDate}
                  onChange={(e) => setTimeSlotManagementDate(e.target.value)}
                  min={new Date().toISOString().split('T')[0]}
                  className={styles.timeSlotDeleteInput}
                />
                <button
                  onClick={handleDeleteTimeSlotsByDateClick}
                  disabled={!timeSlotManagementDate || loadingTimeSlotManagement}
                  className={styles.timeSlotDeleteButton}
                >
                  删除该日期所有时间段
                </button>
              </div>
              <div className={styles.timeSlotDeleteHint}>
                💡 提示：删除后，该日期的时间段将不再显示。如果该日期有已申请的时间段，将无法删除。
              </div>
            </div>

            {/* 时间段列表（按日期分组） */}
            <div>
              <div className={styles.timeSlotListHeader}>
                <span>时间段列表（未来30天）</span>
                {timeSlotManagementSlots.length > 0 && (
                  <span className={styles.timeSlotListCount}>
                    共 {timeSlotManagementSlots.length} 个时间段
                  </span>
                )}
              </div>
              {loadingTimeSlotManagement ? (
                <div className={styles.loading}>{t('common.loading')}</div>
              ) : timeSlotManagementSlots.length === 0 ? (
                <div className={styles.timeSlotListEmpty}>
                  <div className={styles.timeSlotListEmptyIcon}>📅</div>
                  <div className={styles.timeSlotListEmptyText}>暂无时间段</div>
                  <div className={styles.timeSlotListEmptyHint}>请在上方添加时间段</div>
                </div>
              ) : (
                <div>
                  {groupedTimeSlots.map(({ date, slots }) => {
                    const safeSlots = slots ?? [];
                    const hasDeleted = safeSlots.some((s: any) => s.is_manually_deleted);
                    
                    return (
                      <div
                        key={date}
                        className={`${styles.timeSlotDateGroup} ${hasDeleted ? styles.timeSlotDateGroupDeleted : ''}`}
                      >
                        <div className={styles.timeSlotDateHeader}>
                          <div className={`${styles.timeSlotDateTitle} ${hasDeleted ? styles.timeSlotDateTitleDeleted : ''}`}>
                            {date} {hasDeleted && '(已删除)'}
                          </div>
                          <div className={styles.timeSlotDateCount}>
                            {safeSlots.length} 个时间段
                          </div>
                        </div>
                        <div className={styles.timeSlotDateGrid}>
                          {safeSlots.map((slot: any) => {
                            const isFull = slot.current_participants >= slot.max_participants;
                            const isExpired = slot.is_expired === true;
                            const isDeleted = slot.is_manually_deleted === true;
                            const hasParticipants = slot.current_participants > 0;
                            
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
                            
                            let cardClassName = styles.timeSlotCard;
                            if (isDeleted) {
                              cardClassName += ` ${styles.timeSlotCardDeleted}`;
                            } else if (isFull || isExpired) {
                              cardClassName += ` ${styles.timeSlotCardFull}`;
                            }
                            
                            return (
                              <div key={slot.id} className={cardClassName}>
                                <div className={styles.timeSlotCardHeader}>
                                  <div className={`${styles.timeSlotCardTime} ${isDeleted ? styles.timeSlotCardTimeDeleted : ''}`}>
                                    {startTimeUK} - {endTimeUK}
                                  </div>
                                  {!isDeleted && !hasParticipants && (
                                    <button
                                      onClick={() => handleDeleteSingleTimeSlot(selectedServiceForTimeSlot!.id, slot.id)}
                                      className={styles.timeSlotCardDelete}
                                      title="删除此时间段"
                                      aria-label="删除此时间段"
                                    >
                                      ×
                                    </button>
                                  )}
                                </div>
                                <div className={styles.timeSlotCardInfo}>
                                  {slot.current_participants}/{slot.max_participants} 人
                                  {isFull && ' (已满)'}
                                  {isExpired && ' (已过期)'}
                                  {isDeleted && ' (已删除)'}
                                </div>
                                {slot.price_per_participant && (
                                  <div className={styles.timeSlotCardPrice}>
                                    £{slot.price_per_participant.toFixed(2)}/人
                                  </div>
                                )}
                              </div>
                            );
                          })}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* 议价弹窗 */}
      {showCounterOfferModal && selectedApplication && (
        <div
          className={styles.modalOverlay}
          onClick={() => setShowCounterOfferModal(false)}
        >
          <div
            className={styles.modalContent}
            style={{ maxWidth: '500px' }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>
                再次议价
              </h3>
              <button
                onClick={() => setShowCounterOfferModal(false)}
                className={styles.modalClose}
              >
                ×
              </button>
            </div>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>
                议价价格 ({selectedApplication.currency || 'GBP'})
              </label>
              <input
                type="number"
                value={counterPrice || ''}
                onChange={(e) => setCounterPrice(parseFloat(e.target.value) || undefined)}
                className={styles.formInput}
              />
            </div>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>
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
    participants_per_slot: 1,
    // 特定日期和时间段（英国时间）
    slot_date: '', // 日期，格式：YYYY-MM-DD
    slot_start_time: '12:00', // 开始时间（英国时间），格式：HH:MM
    slot_end_time: '14:00', // 结束时间（英国时间），格式：HH:MM
  });
  const [saving, setSaving] = useState(false);
  const [, setUploadingImages] = useState<boolean[]>([]); void setUploadingImages;
  const [currentUser, setCurrentUser] = useState<any>(null);

  useEffect(() => {
    if (service) {
      // 从服务对象中获取时间段信息
      const hasTimeSlots = service.has_time_slots || false;
      const participantsPerSlot = service.participants_per_slot || 1;
      
      setFormData({
        service_name: service.service_name,
        description: service.description || '',
        base_price: service.base_price,
        currency: service.currency,
        status: service.status,
        images: service.images || [],
        has_time_slots: hasTimeSlots,
        participants_per_slot: participantsPerSlot,
        slot_date: '',
        slot_start_time: '12:00',
        slot_end_time: '14:00',
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
        participants_per_slot: 1,
        slot_date: '',
        slot_start_time: '12:00',
        slot_end_time: '14:00',
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
      if (!formData.slot_date) {
        message.warning('请选择日期');
        return;
      }
      if (!formData.slot_start_time || !formData.slot_end_time) {
        message.warning('请设置开始时间和结束时间');
        return;
      }
      if (formData.participants_per_slot <= 0) {
        message.warning('每个时间段的参与者数量必须大于0');
        return;
      }
      // 验证开始时间早于结束时间
      const startTime = formData.slot_start_time.split(':').map(Number);
      const endTime = formData.slot_end_time.split(':').map(Number);
      const startMinutes = (startTime[0] ?? 0) * 60 + (startTime[1] ?? 0);
      const endMinutes = (endTime[0] ?? 0) * 60 + (endTime[1] ?? 0);
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
        images: formData.images ?? [],
      };
      
      // 添加时间段信息（如果启用）
      if (formData.has_time_slots) {
        submitData.has_time_slots = true;
        submitData.participants_per_slot = formData.participants_per_slot;
        // 时间段配置（统一时间或按周几设置）由管理员在任务达人管理中设置
        // 时间段时长也由管理员设置
        // 任务达人不能设置这些配置
        submitData.time_slot_duration_minutes = undefined;
        submitData.time_slot_start_time = undefined;
        submitData.time_slot_end_time = undefined;
        submitData.weekly_time_slot_config = undefined;
      } else {
        submitData.has_time_slots = false;
        submitData.time_slot_duration_minutes = undefined;
        submitData.time_slot_start_time = undefined;
        submitData.time_slot_end_time = undefined;
        submitData.weekly_time_slot_config = undefined;
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
      
      // 如果启用了时间段，创建指定的时间段
      if (formData.has_time_slots && savedServiceId) {
        try {
          await createServiceTimeSlot(savedServiceId, {
            slot_date: formData.slot_date,
            start_time: formData.slot_start_time + ':00', // 转换为HH:MM:SS格式
            end_time: formData.slot_end_time + ':00',
            price_per_participant: formData.base_price,
            max_participants: formData.participants_per_slot,
          });
          message.success('时间段已创建');
        } catch (err: any) {
          // 不阻止服务保存，只提示警告
          message.warning('服务已保存，但时间段创建失败，请稍后手动创建时间段');
        }
      }
      
      // 更新本地状态中的时间段配置（用于创建多人活动时快速获取）
      if (setServiceTimeSlotConfigs) {
        if (formData.has_time_slots && savedServiceId) {
          // 注意：time_slot_start_time和time_slot_end_time由管理员设置，这里不更新
          // 但为了类型兼容，需要从服务中获取这些值
          setServiceTimeSlotConfigs((prev: {[key: number]: {
            has_time_slots: boolean;
            time_slot_duration_minutes: number;
            time_slot_start_time: string;
            time_slot_end_time: string;
            participants_per_slot: number;
          }}) => {
            // 保留原有的时间段配置（如果存在），只更新可以修改的字段
            const existing = prev[savedServiceId];
            return {
              ...prev,
              [savedServiceId]: {
                has_time_slots: true,
                time_slot_duration_minutes: existing?.time_slot_duration_minutes || 60, // 从服务配置获取
                time_slot_start_time: existing?.time_slot_start_time || '09:00', // 由管理员设置
                time_slot_end_time: existing?.time_slot_end_time || '18:00', // 由管理员设置
                participants_per_slot: formData.participants_per_slot,
              }
            };
          });
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
                      // 压缩服务图片
                      const compressedFile = await compressImage(file, {
                        maxSizeMB: 1,
                        maxWidthOrHeight: 1920,
                      });
                      
                      const formDataUpload = new FormData();
                      formDataUpload.append('image', compressedFile);
                      
                      // 服务图片上传：传递expert_id（任务达人ID）作为resource_id
                      // 因为服务图片属于任务达人，应该按任务达人ID分类
                      // 任务达人ID等于用户ID
                      const expertId = currentUser?.id;
                      const uploadUrl = expertId 
                        ? `/api/v2/upload/image?category=service_image&resource_id=${expertId}`
                        : '/api/v2/upload/image?category=service_image';
                      
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
              {/* 特定日期和时间段（英国时间） */}
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                  日期（英国时间） <span style={{ color: '#dc3545' }}>*</span>
                </label>
                <input
                  type="date"
                  value={formData.slot_date}
                  onChange={(e) => setFormData({ ...formData, slot_date: e.target.value })}
                  min={new Date().toISOString().split('T')[0]}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #e2e8f0',
                    borderRadius: '6px',
                    fontSize: '14px',
                  }}
                />
              </div>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '16px' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                    开始时间（英国时间） <span style={{ color: '#dc3545' }}>*</span>
                  </label>
                  <input
                    type="time"
                    value={formData.slot_start_time}
                    onChange={(e) => setFormData({ ...formData, slot_start_time: e.target.value })}
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
                    结束时间（英国时间） <span style={{ color: '#dc3545' }}>*</span>
                  </label>
                  <input
                    type="time"
                    value={formData.slot_end_time}
                    onChange={(e) => setFormData({ ...formData, slot_end_time: e.target.value })}
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
              
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                  每个时间段最多参与者 <span style={{ color: '#dc3545' }}>*</span>
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

              <div style={{ fontSize: '12px', color: '#718096', marginTop: '12px' }}>
                💡 提示：启用时间段后，用户申请此服务时需要选择具体的日期和时间段。时间段配置（统一时间或按周几设置）由管理员在任务达人管理中设置。您只能创建单个固定时间段（如1月1号的12点-14点，英国时间）。
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

