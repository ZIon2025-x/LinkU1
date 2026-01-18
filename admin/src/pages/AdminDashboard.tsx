import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { message, Modal } from 'antd';
import { compressImage } from '../utils/imageCompression';
import { getErrorMessage } from '../utils/errorHandler';
import LazyImage from '../components/LazyImage';
import styles from './AdminDashboard.module.css';
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
  getTaskExpertForAdmin,
  createTaskExpert,
  updateTaskExpert,
  deleteTaskExpert,
  getTaskExpertApplications,
  reviewTaskExpertApplication,
  createExpertFromApplication,
  getProfileUpdateRequests,
  reviewProfileUpdateRequest,
  getExpertServicesAdmin,
  updateExpertServiceAdmin,
  deleteExpertServiceAdmin,
  getExpertActivitiesAdmin,
  updateExpertActivityAdmin,
  deleteExpertActivityAdmin,
  adminLogout,
  createInvitationCode,
  getInvitationCodes,
  getInvitationCodeDetail,
  updateInvitationCode,
  deleteInvitationCode,
  getForumCategories,
  createForumCategory,
  updateForumCategory,
  deleteForumCategory,
  getCategoryRequests,
  reviewCategoryRequest,
  getForumPosts,
  getForumPost,
  createForumPost,
  updateForumPost,
  deleteForumPost,
  pinForumPost,
  unpinForumPost,
  featureForumPost,
  unfeatureForumPost,
  lockForumPost,
  unlockForumPost,
  restoreForumPost,
  hideForumPost,
  unhideForumPost,
  getForumReports,
  processForumReport,
  getForumReplies,
  createForumReply,
  getFleaMarketReports,
  processFleaMarketReport,
  getFleaMarketItemsAdmin,
  updateFleaMarketItemAdmin,
  deleteFleaMarketItemAdmin,
  getLeaderboardVotesAdmin,
  getCustomLeaderboardsAdmin,
  reviewCustomLeaderboard,
  getLeaderboardItemsAdmin,
  deleteLeaderboardItemAdmin,
  getBannersAdmin,
  getBannerDetailAdmin,
  createBanner,
  updateBanner,
  deleteBanner,
  toggleBannerStatus,
  batchDeleteBanners,
  batchUpdateBannerOrder,
  uploadBannerImage,
  getAdminTaskDisputes,
  getAdminTaskDisputeDetail,
  resolveTaskDispute,
  dismissTaskDispute
} from '../api';
import NotificationBell, { NotificationBellRef } from '../components/NotificationBell';
import NotificationModal from '../components/NotificationModal';
import TaskManagement from '../components/TaskManagement';
import CustomerServiceManagement from '../components/CustomerServiceManagement';
import SystemSettings from '../components/SystemSettings';
import TwoFactorAuthSettings from '../components/TwoFactorAuthSettings';
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
  const [showCreateExpertModal, setShowCreateExpertModal] = useState(false); // 创建任务达人弹窗（从申请中选择）
  const [approvedApplications, setApprovedApplications] = useState<any[]>([]); // 已批准的申请列表
  const [loadingApprovedApplications, setLoadingApprovedApplications] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [taskExpertSubTab, setTaskExpertSubTab] = useState<'list' | 'applications' | 'profile-updates'>('list'); // 任务达人管理内部标签切换
  const [expertModalTab, setExpertModalTab] = useState<'basic' | 'services' | 'activities'>('basic'); // 编辑弹窗内部标签切换
  const [expertServices, setExpertServices] = useState<any[]>([]);
  const [expertActivities, setExpertActivities] = useState<any[]>([]);
  const [loadingServices, setLoadingServices] = useState(false);
  const [loadingActivities, setLoadingActivities] = useState(false);
  const [editingService, setEditingService] = useState<any>(null);
  const [showServiceEditModal, setShowServiceEditModal] = useState(false);
  const [serviceTimeSlotForm, setServiceTimeSlotForm] = useState({
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
    } as { [key: string]: { enabled: boolean; start_time: string; end_time: string } },
  });
  
  // 任务达人申请审核相关状态
  const [expertApplications, setExpertApplications] = useState<any[]>([]);
  const [loadingApplications, setLoadingApplications] = useState(false);
  const [selectedApplication, setSelectedApplication] = useState<any>(null);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [reviewAction, setReviewAction] = useState<'approve' | 'reject'>('approve');
  const [reviewComment, setReviewComment] = useState('');
  
  // 任务争议管理相关状态
  const [taskDisputes, setTaskDisputes] = useState<any[]>([]);
  const [disputesLoading, setDisputesLoading] = useState(false);
  const [disputesPage, setDisputesPage] = useState(1);
  const [disputesTotal, setDisputesTotal] = useState(0);
  const [disputesStatusFilter, setDisputesStatusFilter] = useState<string>('');
  const [disputesSearchKeyword, setDisputesSearchKeyword] = useState<string>('');
  const [selectedDispute, setSelectedDispute] = useState<any>(null);
  const [showDisputeDetailModal, setShowDisputeDetailModal] = useState(false);
  const [showDisputeActionModal, setShowDisputeActionModal] = useState(false);
  const [disputeAction, setDisputeAction] = useState<'resolve' | 'dismiss'>('resolve');
  const [disputeResolutionNote, setDisputeResolutionNote] = useState('');
  const [processingDispute, setProcessingDispute] = useState(false);

  // 信息修改请求审核相关状态
  const [profileUpdateRequests, setProfileUpdateRequests] = useState<any[]>([]);
  const [loadingProfileUpdates, setLoadingProfileUpdates] = useState(false);
  const [selectedProfileUpdate, setSelectedProfileUpdate] = useState<any>(null);
  const [showProfileUpdateReviewModal, setShowProfileUpdateReviewModal] = useState(false);
  const [profileUpdateReviewAction, setProfileUpdateReviewAction] = useState<'approve' | 'reject'>('approve');
  const [profileUpdateReviewComment, setProfileUpdateReviewComment] = useState('');
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
    is_active: 0,  // 默认已禁用，需要管理员手动启用
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
  const [show2FASettings, setShow2FASettings] = useState(false);

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

  // 论坛板块管理相关状态
  const [forumCategories, setForumCategories] = useState<any[]>([]);
  const [showForumCategoryModal, setShowForumCategoryModal] = useState(false);
  
  // 板块申请管理相关状态
  const [categoryRequests, setCategoryRequests] = useState<any[]>([]);
  const [loadingCategoryRequests, setLoadingCategoryRequests] = useState(false);
  const [categoryRequestStatusFilter, setCategoryRequestStatusFilter] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');
  const [categoryRequestPage, setCategoryRequestPage] = useState(1);
  const [categoryRequestPageSize] = useState(20);
  const [categoryRequestTotal, setCategoryRequestTotal] = useState(0);
  const [categoryRequestSearch, setCategoryRequestSearch] = useState('');
  const [categoryRequestSortBy, setCategoryRequestSortBy] = useState<'created_at' | 'reviewed_at' | 'status'>('created_at');
  const [categoryRequestSortOrder, setCategoryRequestSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedCategoryRequest, setSelectedCategoryRequest] = useState<any>(null);
  const [showCategoryRequestReviewModal, setShowCategoryRequestReviewModal] = useState(false);
  const [showCategoryRequestDetailModal, setShowCategoryRequestDetailModal] = useState(false);
  const [categoryRequestReviewAction, setCategoryRequestReviewAction] = useState<'approve' | 'reject'>('approve');
  const [categoryRequestReviewComment, setCategoryRequestReviewComment] = useState('');
  const [reviewingCategoryRequest, setReviewingCategoryRequest] = useState(false);
  const [forumCategoryForm, setForumCategoryForm] = useState({
    id: undefined as number | undefined,
    name: '',
    description: '',
    icon: '',
    sort_order: 0,
    is_visible: true,
    is_admin_only: false,
    // 学校板块访问控制字段
    type: 'general' as 'general' | 'root' | 'university',
    country: '',
    university_code: ''
  });
  const [universities, setUniversities] = useState<any[]>([]);

  // 论坛内容管理相关状态
  const [forumPosts, setForumPosts] = useState<any[]>([]);
  const [forumPostsPage, setForumPostsPage] = useState(1);
  const [forumPostsTotal, setForumPostsTotal] = useState(0);
  const [forumPostsLoading, setForumPostsLoading] = useState(false);
  const [showForumPostModal, setShowForumPostModal] = useState(false);
  const [forumPostForm, setForumPostForm] = useState({
    id: undefined as number | undefined,
    title: '',
    content: '',
    category_id: undefined as number | undefined
  });
  const [forumPostFilter, setForumPostFilter] = useState({
    category_id: undefined as number | undefined,
    search: '',
    is_deleted: undefined as boolean | undefined,
    is_visible: undefined as boolean | undefined
  });
  // 帖子详情和回复相关状态
  const [showForumPostDetailModal, setShowForumPostDetailModal] = useState(false);
  const [selectedForumPost, setSelectedForumPost] = useState<any>(null);
  const [forumReplies, setForumReplies] = useState<any[]>([]);
  const [forumRepliesLoading, setForumRepliesLoading] = useState(false);
  const [replyContent, setReplyContent] = useState('');
  const [replySubmitting, setReplySubmitting] = useState(false);
  const [replyingToReplyId, setReplyingToReplyId] = useState<number | null>(null);

  // 举报管理相关状态
  const [forumReports, setForumReports] = useState<any[]>([]);
  const [forumReportsPage, setForumReportsPage] = useState(1);
  const [forumReportsTotal, setForumReportsTotal] = useState(0);
  const [forumReportsLoading, setForumReportsLoading] = useState(false);
  const [forumReportsStatusFilter, setForumReportsStatusFilter] = useState<'pending' | 'processed' | 'rejected' | undefined>(undefined);
  const [fleaMarketReports, setFleaMarketReports] = useState<any[]>([]);
  const [fleaMarketReportsPage, setFleaMarketReportsPage] = useState(1);
  const [fleaMarketReportsTotal, setFleaMarketReportsTotal] = useState(0);
  const [fleaMarketReportsLoading, setFleaMarketReportsLoading] = useState(false);
  const [fleaMarketReportsStatusFilter, setFleaMarketReportsStatusFilter] = useState<'pending' | 'reviewing' | 'resolved' | 'rejected' | undefined>(undefined);
  
  // 商品管理状态
  const [fleaMarketItems, setFleaMarketItems] = useState<any[]>([]);
  const [fleaMarketItemsPage, setFleaMarketItemsPage] = useState(1);
  const [fleaMarketItemsTotal, setFleaMarketItemsTotal] = useState(0);
  const [fleaMarketItemsLoading, setFleaMarketItemsLoading] = useState(false);
  const [fleaMarketItemsFilter, setFleaMarketItemsFilter] = useState<{
    category?: string;
    keyword?: string;
    status?: string;
    seller_id?: string;
  }>({});

  // Banner 管理状态
  const [banners, setBanners] = useState<any[]>([]);
  const [bannersPage, setBannersPage] = useState(1);
  const [bannersTotal, setBannersTotal] = useState(0);
  const [bannersLoading, setBannersLoading] = useState(false);
  const [bannersActiveFilter, setBannersActiveFilter] = useState<boolean | undefined>(undefined);
  const [showBannerModal, setShowBannerModal] = useState(false);
  const [bannerForm, setBannerForm] = useState({
    id: undefined as number | undefined,
    image_url: '',
    title: '',
    subtitle: '',
    link_url: '',
    link_type: 'internal' as 'internal' | 'external',
    order: 0,
    is_active: true
  });
  const [uploadingImage, setUploadingImage] = useState(false);
  const [showFleaMarketItemModal, setShowFleaMarketItemModal] = useState(false);
  const [fleaMarketItemForm, setFleaMarketItemForm] = useState<any>({});
  const [showReportProcessModal, setShowReportProcessModal] = useState(false);
  const [currentReport, setCurrentReport] = useState<any>(null);
  const [reportProcessForm, setReportProcessForm] = useState({
    status: 'processed' as 'processed' | 'rejected' | 'resolved' | 'rejected',
    action: '',
    admin_comment: ''
  });

  // 投票记录管理相关状态
  const [leaderboardVotes, setLeaderboardVotes] = useState<any[]>([]);
  const [leaderboardVotesPage, setLeaderboardVotesPage] = useState(1);
  const [leaderboardVotesTotal, setLeaderboardVotesTotal] = useState(0);
  const [leaderboardVotesLoading, setLeaderboardVotesLoading] = useState(false);
  const [leaderboardVotesFilter, setLeaderboardVotesFilter] = useState<{
    item_id?: number;
    leaderboard_id?: number;
    is_anonymous?: boolean;
    keyword?: string;
  }>({});

  // 榜单审核相关状态
  const [pendingLeaderboards, setPendingLeaderboards] = useState<any[]>([]);
  const [leaderboardsPage, setLeaderboardsPage] = useState(1);
  const [leaderboardsLoading, setLeaderboardsLoading] = useState(false);
  const [reviewingLeaderboard, setReviewingLeaderboard] = useState<number | null>(null);
  const [leaderboardReviewComment, setLeaderboardReviewComment] = useState('');
  const [showLeaderboardReviewModal, setShowLeaderboardReviewModal] = useState(false);
  const [selectedLeaderboardForReview, setSelectedLeaderboardForReview] = useState<any>(null);
  
  // 竞品管理相关状态
  const [leaderboardItems, setLeaderboardItems] = useState<any[]>([]);
  const [leaderboardItemsPage, setLeaderboardItemsPage] = useState(1);
  const [leaderboardItemsTotal, setLeaderboardItemsTotal] = useState(0);
  const [leaderboardItemsLoading, setLeaderboardItemsLoading] = useState(false);
  const [leaderboardItemsFilter, setLeaderboardItemsFilter] = useState<{
    leaderboard_id?: number;
    status?: 'all' | 'approved';
    keyword?: string;
  }>({});

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
        // 根据子标签加载数据
        if (taskExpertSubTab === 'list') {
          // 加载任务达人数据
          const expertsData = await getTaskExperts({ page: currentPage, size: 20 });
          setTaskExperts(expertsData.task_experts || []);
          setTotalPages(Math.ceil((expertsData.total || 0) / 20));
        } else if (taskExpertSubTab === 'applications') {
          // 加载任务达人申请数据
          loadExpertApplications();
        }
      } else if (activeTab === 'invitation-codes') {
        const codesData = await getInvitationCodes({
          page: invitationCodesPage,
          limit: 20,
          status: invitationCodesStatusFilter as 'active' | 'inactive' | undefined
        });
        setInvitationCodes(codesData.data || []);
        setInvitationCodesTotal(codesData.total || 0);
      } else if (activeTab === 'forum-categories') {
        const categoriesData = await getForumCategories(false);
        setForumCategories(categoriesData.categories || []);
      } else if (activeTab === 'forum-category-requests') {
        await loadCategoryRequests();
      } else if (activeTab === 'forum-posts') {
        // 确保板块列表已加载
        if (forumCategories.length === 0) {
          const categoriesData = await getForumCategories(false);
          setForumCategories(categoriesData.categories || []);
        }
        await loadForumPosts();
      } else if (activeTab === 'leaderboard-votes') {
        await loadLeaderboardVotes();
      } else if (activeTab === 'leaderboard-review') {
        await loadPendingLeaderboards();
      } else if (activeTab === 'leaderboard-items') {
        await loadLeaderboardItems();
      } else if (activeTab === 'banners') {
        await loadBanners();
      }
    } catch (error: any) {
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
  }, [activeTab, currentPage, searchTerm, invitationCodesPage, invitationCodesStatusFilter, taskExpertSubTab]);

  useEffect(() => {
    loadDashboardData();
    // 加载大学列表（用于创建学校板块时选择）
    const loadUniversities = async () => {
      try {
        const res = await api.get('/api/student-verification/universities', {
          params: { page: 1, page_size: 1000 }
        });
        setUniversities(res.data?.data?.items || []);
      } catch (error) {
        // 静默处理错误，不影响主流程
      }
    };
    loadUniversities();
  }, [loadDashboardData]);

  // 加载任务达人申请列表
  const loadExpertApplications = async () => {
    setLoadingApplications(true);
    try {
      const data = await getTaskExpertApplications({ limit: 50, offset: 0 });
      setExpertApplications(Array.isArray(data) ? data : (data.items || []));
    } catch (err: any) {
      message.error('加载申请列表失败');
          } finally {
      setLoadingApplications(false);
    }
  };

  // 加载信息修改请求
  const loadProfileUpdateRequests = async () => {
    setLoadingProfileUpdates(true);
    try {
      const data = await getProfileUpdateRequests({ status: 'pending', limit: 50, offset: 0 });
      setProfileUpdateRequests(Array.isArray(data) ? data : (data.items || []));
    } catch (err: any) {
      message.error('加载信息修改请求列表失败');
          } finally {
      setLoadingProfileUpdates(false);
    }
  };
  
  // 审核信息修改请求
  const handleReviewProfileUpdate = async () => {
    if (!selectedProfileUpdate) return;
    
    if (profileUpdateReviewAction === 'reject' && !profileUpdateReviewComment.trim()) {
      message.warning('拒绝请求时请填写审核意见');
      return;
    }
    
    try {
      await reviewProfileUpdateRequest(selectedProfileUpdate.id, {
        action: profileUpdateReviewAction,
        review_comment: profileUpdateReviewComment || undefined,
      });
      message.success(profileUpdateReviewAction === 'approve' ? '已批准修改请求' : '已拒绝修改请求');
      setShowProfileUpdateReviewModal(false);
      setSelectedProfileUpdate(null);
      setProfileUpdateReviewComment('');
      loadProfileUpdateRequests();
    } catch (err: any) {
      const errorMessage = err.response?.data?.detail || err.response?.data?.message || err.message || '审核失败';
      message.error(errorMessage);
    }
  };
  
  // 审核任务达人申请
  const handleReviewApplication = async () => {
    if (!selectedApplication) return;
    
    if (reviewAction === 'reject' && !reviewComment.trim()) {
      message.warning('拒绝申请时请填写审核意见');
      return;
    }

    try {
      const result = await reviewTaskExpertApplication(selectedApplication.id, {
        action: reviewAction,
        review_comment: reviewComment || undefined,
      });
            message.success(reviewAction === 'approve' ? '申请已批准' : '申请已拒绝');
      setShowReviewModal(false);
      setSelectedApplication(null);
      setReviewComment('');
      loadExpertApplications();
    } catch (err: any) {
                  const errorMessage = err.response?.data?.detail || err.response?.data?.message || err.message || '审核失败';
      message.error(errorMessage);
    }
  };

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
      message.error(getErrorMessage(error));
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
      message.error(getErrorMessage(error));
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
          message.error(getErrorMessage(error));
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
          message.error(getErrorMessage(error));
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
      message.error(getErrorMessage(error));
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
      message.error(getErrorMessage(error));
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
      message.error(getErrorMessage(error));
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
      message.error(getErrorMessage(error));
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
      message.error(getErrorMessage(error));
    }
  };

  const handleNotifyCustomerService = async (csId: number, message: string) => {
    try {
      await notifyCustomerService(csId, message);
      alert('提醒发送成功！');
    } catch (error: any) {
      alert(getErrorMessage(error));
    }
  };

  const [cleanupLoading, setCleanupLoading] = useState(false);

  const handleCleanupOldTasks = async () => {
    if (!window.confirm('确定要清理所有已完成或已取消任务的所有图片和文件吗？\n\n清理内容包括：\n- 公开图片（任务相关图片）\n- 私密图片（任务聊天图片）\n- 私密文件（任务聊天文件）\n\n注意：将清理所有已完成或已取消的任务，不检查时间限制！\n此操作不可恢复！')) {
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
            message.error(getErrorMessage(error));
    } finally {
      setCleanupLoading(false);
    }
  };

  // 使用useMemo优化统计数据渲染
  const statsCards = useMemo(() => {
    if (!stats) return null;
    return (
      <div className={styles.statsGrid}>
        <div className={styles.statCard}>
          <h3 className={styles.statLabel}>总用户数</h3>
          <p className={styles.statValue}>{stats.total_users}</p>
        </div>
        <div className={styles.statCard}>
          <h3 className={styles.statLabel}>总任务数</h3>
          <p className={styles.statValue}>{stats.total_tasks}</p>
        </div>
        <div className={styles.statCard}>
          <h3 className={styles.statLabel}>客服数量</h3>
          <p className={styles.statValue}>{stats.total_customer_service}</p>
        </div>
        <div className={styles.statCard}>
          <h3 className={styles.statLabel}>活跃会话</h3>
          <p className={styles.statValue}>{stats.active_sessions}</p>
        </div>
        <div className={styles.statCard}>
          <h3 className={styles.statLabel}>总收入</h3>
          <p className={styles.statValue}>£{stats.total_revenue.toFixed(2)}</p>
        </div>
        <div className={styles.statCard}>
          <h3 className={styles.statLabel}>平均评分</h3>
          <p className={styles.statValue}>{stats.avg_rating.toFixed(1)}</p>
        </div>
      </div>
    );
  }, [stats]);

  const renderDashboard = useCallback(() => (
    <div className={styles.dashboardSection}>
      <div className={styles.dashboardHeader}>
        <h2 className={styles.dashboardTitle}>数据概览</h2>
        <button
          onClick={handleCleanupOldTasks}
          disabled={cleanupLoading}
          className={`${styles.btn} ${styles.btnDanger}`}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            opacity: cleanupLoading ? 0.6 : 1,
            cursor: cleanupLoading ? 'not-allowed' : 'pointer'
          }}
        >
          {cleanupLoading ? (
            <>
              <span className={styles.spinner} style={{ width: '14px', height: '14px', borderWidth: '2px' }}></span>
              清理中...
            </>
          ) : (
            <>🗑️ 一键清理已完成和过期任务文件</>
          )}
        </button>
      </div>
      {statsCards}
    </div>
  ), [stats, cleanupLoading, handleCleanupOldTasks]);

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
        border: '1px solid #bbdefb',
        overflowX: 'auto'
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '1200px' }}>
          {/* 表头行 */}
          <thead>
            <tr>
              <th style={{ 
                padding: '12px', 
                textAlign: 'left', 
                borderBottom: '1px solid #eee', 
                background: '#f8f9fa', 
                fontWeight: 600,
                position: 'sticky',
                left: 0,
                zIndex: 10,
                minWidth: '100px'
              }}>ID</th>
              <th style={{ 
                padding: '12px', 
                textAlign: 'left', 
                borderBottom: '1px solid #eee', 
                background: '#f8f9fa', 
                fontWeight: 600,
                position: 'sticky',
                left: '100px',
                zIndex: 10,
                minWidth: '150px'
              }}>用户名</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '200px' }}>邮箱</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '120px' }}>等级</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '100px' }}>状态</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '80px' }}>任务数</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '80px' }}>评分</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '120px' }}>邀请码</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '120px' }}>邀请人</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '120px' }}>注册时间</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #eee', background: '#f8f9fa', fontWeight: 600, minWidth: '200px' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {users && users.length > 0 ? (
              users.map(user => (
                <tr key={user.id}>
                  <td style={{ 
                    padding: '12px', 
                    textAlign: 'left', 
                    borderBottom: '1px solid #eee',
                    background: 'white',
                    position: 'sticky',
                    left: 0,
                    zIndex: 5,
                    minWidth: '100px'
                  }}>{user.id}</td>
                  <td style={{ 
                    padding: '12px', 
                    textAlign: 'left', 
                    borderBottom: '1px solid #eee',
                    background: 'white',
                    position: 'sticky',
                    left: '100px',
                    zIndex: 5,
                    minWidth: '150px'
                  }}>{user.name}</td>
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

  const renderPersonnelManagement = useCallback(() => (
    <div>
      <h2>人员管理</h2>
      
      {/* 管理员管理 */}
      <div className={styles.card}>
        <h3 className={styles.cardTitle}>管理员管理</h3>
        
        {/* 创建新管理员 */}
        <div style={{ marginBottom: '20px' }}>
          <h4 className={styles.cardSubtitle}>创建新管理员</h4>
          <div className={styles.formGroup}>
            <input
              type="text"
              placeholder="管理员姓名"
              value={newAdminUser.name}
              onChange={(e) => setNewAdminUser({...newAdminUser, name: e.target.value})}
              className={styles.formInput}
            />
            <input
              type="text"
              placeholder="登录用户名"
              value={newAdminUser.username}
              onChange={(e) => setNewAdminUser({...newAdminUser, username: e.target.value})}
              className={styles.formInput}
            />
            <input
              type="email"
              placeholder="邮箱"
              value={newAdminUser.email}
              onChange={(e) => setNewAdminUser({...newAdminUser, email: e.target.value})}
              className={styles.formInputEmail}
            />
            <input
              type="password"
              placeholder="密码"
              value={newAdminUser.password}
              onChange={(e) => setNewAdminUser({...newAdminUser, password: e.target.value})}
              className={styles.formInput}
            />
            <select
              value={newAdminUser.is_super_admin}
              onChange={(e) => setNewAdminUser({...newAdminUser, is_super_admin: parseInt(e.target.value)})}
              className={styles.formSelect}
            >
              <option value={0}>普通管理员</option>
              <option value={1}>超级管理员</option>
            </select>
            <button
              onClick={handleCreateAdminUser}
              disabled={loading}
              className={`${styles.formButton} ${styles.formButtonDanger}`}
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
  ), [newAdminUser, newCustomerService, adminUsers, customerServices, loading, handleCreateAdminUser, handleCreateCustomerService, handleDeleteAdminUser, handleDeleteCustomerService, openSendNotificationModal]);

  const renderTaskExperts = useCallback(() => (
    <div>
      <h2>任务达人管理</h2>
      
      {/* 内部标签切换 */}
      <div style={{ display: 'flex', gap: '12px', marginBottom: '20px', borderBottom: '2px solid #e2e8f0' }}>
        <button
          onClick={() => {
            setTaskExpertSubTab('list');
            setCurrentPage(1);
          }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: 'transparent',
            color: taskExpertSubTab === 'list' ? '#007bff' : '#666',
            borderBottom: taskExpertSubTab === 'list' ? '2px solid #007bff' : '2px solid transparent',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: taskExpertSubTab === 'list' ? 600 : 400,
            marginBottom: '-2px',
            transition: 'all 0.2s'
          }}
        >
          任务达人列表
        </button>
        <button
          onClick={() => {
            setTaskExpertSubTab('applications');
            loadExpertApplications();
          }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: 'transparent',
            color: taskExpertSubTab === 'applications' ? '#007bff' : '#666',
            borderBottom: taskExpertSubTab === 'applications' ? '2px solid #007bff' : '2px solid transparent',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: taskExpertSubTab === 'applications' ? 600 : 400,
            marginBottom: '-2px',
            transition: 'all 0.2s'
          }}
        >
          申请审核
        </button>
        <button
          onClick={() => {
            setTaskExpertSubTab('profile-updates');
            loadProfileUpdateRequests();
          }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: 'transparent',
            color: taskExpertSubTab === 'profile-updates' ? '#007bff' : '#666',
            borderBottom: taskExpertSubTab === 'profile-updates' ? '2px solid #007bff' : '2px solid transparent',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: taskExpertSubTab === 'profile-updates' ? 600 : 400,
            marginBottom: '-2px',
            transition: 'all 0.2s'
          }}
        >
          信息修改审核
        </button>
      </div>

      {/* 任务达人列表 */}
      {taskExpertSubTab === 'list' && (
        <>
          <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <button
              onClick={async () => {
                // 加载已批准的申请列表
                setLoadingApprovedApplications(true);
                try {
                  const data = await getTaskExpertApplications({ status: 'approved', limit: 100, offset: 0 });
                  const apps = Array.isArray(data) ? data : (data.items || []);
                  // 过滤掉已经是特色任务达人的用户（FeaturedTaskExpert）
                  const filteredApps = [];
                  for (const app of apps) {
                    // 检查该用户是否已经是特色任务达人（检查 user_id 字段）
                    const isFeaturedExpert = taskExperts.some(expert => expert.user_id === app.user_id);
                    if (!isFeaturedExpert) {
                      filteredApps.push(app);
                    }
                  }
                  setApprovedApplications(filteredApps);
                  setShowCreateExpertModal(true);
                } catch (err: any) {
                  message.error('加载已批准申请失败');
                                  } finally {
                  setLoadingApprovedApplications(false);
                }
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
              + 创建任务达人
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
                      type="button"
                      onClick={async (e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        try {
                          // 从数据库实时加载最新的任务达人数据
                          const expertData = await getTaskExpertForAdmin(expert.id);
                          
                          // 确保数组字段正确解析（如果后端返回的是字符串，需要解析；如果已经是数组，直接使用）
                          const parseArrayField = (field: any): string[] => {
                            if (!field) return [];
                            if (Array.isArray(field)) return field;
                            if (typeof field === 'string') {
                              try {
                                const parsed = JSON.parse(field);
                                return Array.isArray(parsed) ? parsed : [];
                              } catch {
                                // 如果不是JSON，尝试按逗号分割
                                return field.split(',').map((s: string) => s.trim()).filter(Boolean);
                              }
                            }
                            return [];
                          };
                          
                          // 处理城市字段：确保值在CITIES列表中，否则使用默认值
                          const locationValue = expertData.location && 
                                                typeof expertData.location === 'string' && 
                                                expertData.location.trim() && 
                                                CITIES.includes(expertData.location.trim())
                            ? expertData.location.trim()
                            : 'Online';
                          
                          // 处理类别字段：确保值有效
                          const categoryValue = expertData.category && 
                                                typeof expertData.category === 'string' && 
                                                expertData.category.trim()
                            ? expertData.category.trim()
                            : 'programming';
                          
                          // 确保所有字段都正确设置
                          setTaskExpertForm({
                            id: expertData.id,
                            user_id: expertData.user_id,
                            name: expertData.name || '',
                            avatar: expertData.avatar || '',
                            user_level: expertData.user_level || 'normal',
                            bio: expertData.bio || '',
                            bio_en: expertData.bio_en || '',
                            avg_rating: expertData.avg_rating || 0,
                            completed_tasks: expertData.completed_tasks || 0,
                            total_tasks: expertData.total_tasks || 0,
                            completion_rate: expertData.completion_rate || 0,
                            expertise_areas: parseArrayField(expertData.expertise_areas),
                            expertise_areas_en: parseArrayField(expertData.expertise_areas_en),
                            featured_skills: parseArrayField(expertData.featured_skills),
                            featured_skills_en: parseArrayField(expertData.featured_skills_en),
                            achievements: parseArrayField(expertData.achievements),
                            achievements_en: parseArrayField(expertData.achievements_en),
                            response_time: expertData.response_time || '',
                            response_time_en: expertData.response_time_en || '',
                            success_rate: expertData.success_rate || 0,
                            is_verified: expertData.is_verified ? 1 : 0,
                            is_active: expertData.is_active !== undefined ? (expertData.is_active ? 1 : 0) : 0,
                            is_featured: expertData.is_featured !== undefined ? (expertData.is_featured ? 1 : 0) : 0,
                            display_order: expertData.display_order || 0,
                            category: categoryValue,
                            location: locationValue
                          });
                          setShowTaskExpertModal(true);
                        } catch (error) {
                                                    message.error('加载任务达人详情失败，请重试');
                        }
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
                                                            message.error(getErrorMessage(error));
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
          onClick={() => setShowTaskExpertModal(false)}
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
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setShowTaskExpertModal(false);
                }}
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
            
            {/* 编辑弹窗内部标签页导航 */}
            <div style={{ display: 'flex', gap: '12px', marginBottom: '20px', borderBottom: '2px solid #e2e8f0' }}>
              <button
                onClick={() => setExpertModalTab('basic')}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: 'transparent',
                  color: expertModalTab === 'basic' ? '#007bff' : '#666',
                  borderBottom: expertModalTab === 'basic' ? '2px solid #007bff' : '2px solid transparent',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: expertModalTab === 'basic' ? 600 : 400,
                  marginBottom: '-2px',
                  transition: 'all 0.2s'
                }}
              >
                基本信息
              </button>
              <button
                onClick={async () => {
                  setExpertModalTab('services');
                  if (taskExpertForm.id && expertServices.length === 0) {
                    setLoadingServices(true);
                    try {
                      const data = await getExpertServicesAdmin(taskExpertForm.id);
                      setExpertServices(data.services || []);
                    } catch (error: any) {
                                            message.error('加载服务列表失败');
                    } finally {
                      setLoadingServices(false);
                    }
                  }
                }}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: 'transparent',
                  color: expertModalTab === 'services' ? '#007bff' : '#666',
                  borderBottom: expertModalTab === 'services' ? '2px solid #007bff' : '2px solid transparent',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: expertModalTab === 'services' ? 600 : 400,
                  marginBottom: '-2px',
                  transition: 'all 0.2s'
                }}
              >
                服务管理
              </button>
              <button
                onClick={async () => {
                  setExpertModalTab('activities');
                  if (taskExpertForm.id && expertActivities.length === 0) {
                    setLoadingActivities(true);
                    try {
                      const data = await getExpertActivitiesAdmin(taskExpertForm.id);
                      setExpertActivities(data.activities || []);
                    } catch (error: any) {
                                            message.error('加载活动列表失败');
                    } finally {
                      setLoadingActivities(false);
                    }
                  }
                }}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: 'transparent',
                  color: expertModalTab === 'activities' ? '#007bff' : '#666',
                  borderBottom: expertModalTab === 'activities' ? '2px solid #007bff' : '2px solid transparent',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: expertModalTab === 'activities' ? 600 : 400,
                  marginBottom: '-2px',
                  transition: 'all 0.2s'
                }}
              >
                活动管理
              </button>
            </div>
            
            {/* 基本信息标签页 */}
            {expertModalTab === 'basic' && (
              <>
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
                    <LazyImage
                      key={taskExpertForm.avatar}
                      src={taskExpertForm.avatar}
                      alt="头像预览"
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
                        if (file.size > 5 * 1024 * 1024) {
                          message.warning('图片文件过大，请选择小于5MB的图片');
                          e.target.value = '';
                          return;
                        }
                        
                        if (!file.type.startsWith('image/')) {
                          message.warning('请选择图片文件');
                          e.target.value = '';
                          return;
                        }
                        
                        setUploadingAvatar(true);
                        try {
                          // 压缩头像图片
                          const compressedFile = await compressImage(file, {
                            maxSizeMB: 0.5,
                            maxWidthOrHeight: 800,
                          });
                          
                          // 确保压缩后的文件有正确的文件名
                          // 如果压缩后的文件没有name，使用原始文件名
                          const fileToUpload = compressedFile.name 
                            ? compressedFile 
                            : new File([compressedFile], file.name, { type: compressedFile.type || file.type });
                          
                          const formData = new FormData();
                          formData.append('image', fileToUpload, fileToUpload.name);
                          
                          // 任务达人头像上传：传递expert_id作为resource_id
                          const expertId = taskExpertForm.id;
                          const uploadUrl = expertId 
                            ? `/api/upload/public-image?category=expert_avatar&resource_id=${expertId}`
                            : '/api/upload/public-image?category=expert_avatar';
                          
                          // 注意：不要手动设置 Content-Type，让浏览器自动设置（包含boundary）
                          const response = await api.post(uploadUrl, formData);
                          
                          if (response.data.success && response.data.url) {
                            setTaskExpertForm({...taskExpertForm, avatar: response.data.url});
                          } else {
                            message.error('图片上传失败，请重试');
                          }
                        } catch (error: any) {
                                                    message.error(getErrorMessage(error));
                        } finally {
                          setUploadingAvatar(false);
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
                  <option value="translation">翻译服务</option>
                  <option value="tutoring">学业辅导</option>
                  <option value="food">美食料理</option>
                  <option value="beverage">饮品调制</option>
                  <option value="cake">蛋糕烘焙</option>
                  <option value="errand_transport">跑腿接送</option>
                  <option value="social_entertainment">社交娱乐</option>
                  <option value="beauty_skincare">美容护肤</option>
                  <option value="handicraft">手工制品</option>
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

            {/* 注意：以下字段由系统自动计算，不在表单中显示 */}
            {/* response_time, response_time_en, avg_rating, success_rate, completed_tasks, total_tasks, completion_rate */}

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
                  value={String(taskExpertForm.is_active ?? 0)}
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
                  value={String(taskExpertForm.is_featured ?? 0)}
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
            </>
            )}

            {/* 服务管理标签页 */}
            {expertModalTab === 'services' && (
              <div>
                {!taskExpertForm.id ? (
                  <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
                    请先保存任务达人基本信息
                  </div>
                ) : loadingServices ? (
                  <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
                ) : (
                  <>
                    <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <h4 style={{ margin: 0 }}>服务列表</h4>
                      <button
                        onClick={async () => {
                          setLoadingServices(true);
                          try {
                            const data = await getExpertServicesAdmin(taskExpertForm.id);
                            setExpertServices(data.services || []);
                            message.success('刷新成功');
                          } catch (error: any) {
                                                        message.error('加载服务列表失败');
                          } finally {
                            setLoadingServices(false);
                          }
                        }}
                        style={{
                          padding: '6px 12px',
                          border: '1px solid #007bff',
                          background: 'white',
                          color: '#007bff',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px'
                        }}
                      >
                        刷新
                      </button>
                    </div>
                    {expertServices.length === 0 ? (
                      <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
                        该任务达人暂无服务
                      </div>
                    ) : (
                      <div style={{ overflowX: 'auto' }}>
                        <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white' }}>
                          <thead>
                            <tr style={{ background: '#f8f9fa', borderBottom: '2px solid #dee2e6' }}>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>服务名称</th>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>价格</th>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>状态</th>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>操作</th>
                            </tr>
                          </thead>
                          <tbody>
                            {expertServices.map((service) => (
                              <tr key={service.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                                <td style={{ padding: '12px', fontSize: '14px' }}>{service.service_name}</td>
                                <td style={{ padding: '12px', fontSize: '14px' }}>{service.base_price} {service.currency}</td>
                                <td style={{ padding: '12px', fontSize: '14px' }}>
                                  <span style={{
                                    padding: '4px 8px',
                                    borderRadius: '4px',
                                    fontSize: '12px',
                                    background: service.status === 'active' ? '#d4edda' : '#f8d7da',
                                    color: service.status === 'active' ? '#155724' : '#721c24'
                                  }}>
                                    {service.status === 'active' ? '已启用' : '已禁用'}
                                  </span>
                                </td>
                                <td style={{ padding: '12px' }}>
                                  <button
                                    onClick={async () => {
                                      // 加载服务详情并打开编辑弹窗
                                      try {
                                        const data = await getExpertServicesAdmin(taskExpertForm.id);
                                        const serviceDetail = data.services?.find((s: any) => s.id === service.id);
                                        if (serviceDetail) {
                                          // 初始化表单数据
                                          const hasTimeSlots = serviceDetail.has_time_slots || false;
                                          const timeSlotDuration = serviceDetail.time_slot_duration_minutes || 60;
                                          const timeSlotStart = serviceDetail.time_slot_start_time 
                                            ? serviceDetail.time_slot_start_time.substring(0, 5) 
                                            : '09:00';
                                          const timeSlotEnd = serviceDetail.time_slot_end_time 
                                            ? serviceDetail.time_slot_end_time.substring(0, 5) 
                                            : '18:00';
                                          const participantsPerSlot = serviceDetail.participants_per_slot || 1;
                                          const weeklyConfig = serviceDetail.weekly_time_slot_config || null;
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
                                          
                                          setServiceTimeSlotForm({
                                            has_time_slots: hasTimeSlots,
                                            time_slot_duration_minutes: timeSlotDuration,
                                            time_slot_start_time: timeSlotStart,
                                            time_slot_end_time: timeSlotEnd,
                                            participants_per_slot: participantsPerSlot,
                                            use_weekly_config: useWeeklyConfig,
                                            weekly_time_slot_config: weeklyTimeSlotConfig,
                                          });
                                          setEditingService(serviceDetail);
                                          setShowServiceEditModal(true);
                                        }
                                      } catch (error: any) {
                                                                                message.error('加载服务详情失败');
                                      }
                                    }}
                                    style={{
                                      padding: '4px 8px',
                                      marginRight: '4px',
                                      border: '1px solid #28a745',
                                      background: 'white',
                                      color: '#28a745',
                                      borderRadius: '4px',
                                      cursor: 'pointer',
                                      fontSize: '12px'
                                    }}
                                  >
                                    编辑时间段
                                  </button>
                                  <button
                                    onClick={async () => {
                                      const newStatus = service.status === 'active' ? 'inactive' : 'active';
                                      try {
                                        await updateExpertServiceAdmin(taskExpertForm.id, service.id, { status: newStatus });
                                        message.success('服务状态更新成功');
                                        const data = await getExpertServicesAdmin(taskExpertForm.id);
                                        setExpertServices(data.services || []);
                                      } catch (error: any) {
                                                                                message.error(getErrorMessage(error));
                                      }
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
                                    {service.status === 'active' ? '禁用' : '启用'}
                                  </button>
                                  <button
                                    onClick={() => {
                                      Modal.confirm({
                                        title: '确认删除',
                                        content: '确定要删除这个服务吗？',
                                        okText: '确定',
                                        cancelText: '取消',
                                        onOk: async () => {
                                          try {
                                            await deleteExpertServiceAdmin(taskExpertForm.id, service.id);
                                            message.success('服务删除成功');
                                            const data = await getExpertServicesAdmin(taskExpertForm.id);
                                            setExpertServices(data.services || []);
                                          } catch (error: any) {
                                                                                        message.error(getErrorMessage(error));
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
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </>
                )}
                
                {/* 编辑服务时间段配置弹窗 */}
                {showServiceEditModal && editingService && (
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
                      zIndex: 1001
                    }}
                    onClick={() => setShowServiceEditModal(false)}
                  >
                    <div 
                      style={{
                        background: 'white',
                        padding: '30px',
                        borderRadius: '8px',
                        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)',
                        maxWidth: '800px',
                        width: '95%',
                        maxHeight: '90vh',
                        overflow: 'auto',
                        position: 'relative'
                      }}
                      onClick={(e) => e.stopPropagation()}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                        <h3 style={{ margin: 0 }}>编辑服务时间段配置 - {editingService.service_name}</h3>
                        <button
                          onClick={() => setShowServiceEditModal(false)}
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
                            borderRadius: '4px'
                          }}
                        >
                          ×
                        </button>
                      </div>
                      
                      {/* 时间段设置 */}
                      <div style={{ marginBottom: '20px', padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#f9fafb' }}>
                        <div style={{ display: 'flex', alignItems: 'center', marginBottom: '12px' }}>
                          <input
                            type="checkbox"
                            id="admin_has_time_slots"
                            checked={serviceTimeSlotForm.has_time_slots}
                            onChange={(e) => setServiceTimeSlotForm({ ...serviceTimeSlotForm, has_time_slots: e.target.checked })}
                            style={{ width: '18px', height: '18px', cursor: 'pointer', marginRight: '8px' }}
                          />
                          <label htmlFor="admin_has_time_slots" style={{ fontSize: '14px', fontWeight: 500, cursor: 'pointer' }}>
                            启用时间段功能
                          </label>
                        </div>
                        
                        {serviceTimeSlotForm.has_time_slots && (
                          <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #e2e8f0' }}>
                            {/* 时间段时长和参与者数量 */}
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '16px' }}>
                              <div>
                                <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                                  时间段时长（分钟）*
                                </label>
                                <input
                                  type="number"
                                  min="1"
                                  value={serviceTimeSlotForm.time_slot_duration_minutes}
                                  onChange={(e) => setServiceTimeSlotForm({ ...serviceTimeSlotForm, time_slot_duration_minutes: parseInt(e.target.value) || 60 })}
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
                                  value={serviceTimeSlotForm.participants_per_slot}
                                  onChange={(e) => setServiceTimeSlotForm({ ...serviceTimeSlotForm, participants_per_slot: parseInt(e.target.value) || 1 })}
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
                                  id="admin_time_slot_mode_unified"
                                  name="admin_time_slot_mode"
                                  checked={!serviceTimeSlotForm.use_weekly_config}
                                  onChange={() => setServiceTimeSlotForm({ ...serviceTimeSlotForm, use_weekly_config: false })}
                                  style={{ width: '16px', height: '16px', cursor: 'pointer', marginRight: '8px' }}
                                />
                                <label htmlFor="admin_time_slot_mode_unified" style={{ fontSize: '13px', fontWeight: 500, cursor: 'pointer' }}>
                                  统一时间（每天相同时间）
                                </label>
                              </div>
                              <div style={{ display: 'flex', alignItems: 'center' }}>
                                <input
                                  type="radio"
                                  id="admin_time_slot_mode_weekly"
                                  name="admin_time_slot_mode"
                                  checked={serviceTimeSlotForm.use_weekly_config}
                                  onChange={() => setServiceTimeSlotForm({ ...serviceTimeSlotForm, use_weekly_config: true })}
                                  style={{ width: '16px', height: '16px', cursor: 'pointer', marginRight: '8px' }}
                                />
                                <label htmlFor="admin_time_slot_mode_weekly" style={{ fontSize: '13px', fontWeight: 500, cursor: 'pointer' }}>
                                  按周几设置（不同工作日可设置不同时间）
                                </label>
                              </div>
                            </div>

                            {/* 统一时间模式 */}
                            {!serviceTimeSlotForm.use_weekly_config && (
                              <div style={{ marginTop: '12px' }}>
                                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                                  <div>
                                    <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', fontWeight: 500, color: '#4a5568' }}>
                                      开始时间 *
                                    </label>
                                    <input
                                      type="time"
                                      value={serviceTimeSlotForm.time_slot_start_time}
                                      onChange={(e) => setServiceTimeSlotForm({ ...serviceTimeSlotForm, time_slot_start_time: e.target.value })}
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
                                      value={serviceTimeSlotForm.time_slot_end_time}
                                      onChange={(e) => setServiceTimeSlotForm({ ...serviceTimeSlotForm, time_slot_end_time: e.target.value })}
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
                            {serviceTimeSlotForm.use_weekly_config && (
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
                                  const dayKey = key as keyof typeof serviceTimeSlotForm.weekly_time_slot_config;
                                  const dayConfig = serviceTimeSlotForm.weekly_time_slot_config[dayKey];
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
                                            const newConfig = { ...serviceTimeSlotForm.weekly_time_slot_config };
                                            newConfig[key] = {
                                              ...dayConfig,
                                              enabled: e.target.checked,
                                            };
                                            setServiceTimeSlotForm({ ...serviceTimeSlotForm, weekly_time_slot_config: newConfig });
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
                                            const newConfig = { ...serviceTimeSlotForm.weekly_time_slot_config };
                                            newConfig[key] = { ...dayConfig, start_time: e.target.value };
                                            setServiceTimeSlotForm({ ...serviceTimeSlotForm, weekly_time_slot_config: newConfig });
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
                                            const newConfig = { ...serviceTimeSlotForm.weekly_time_slot_config };
                                            newConfig[key] = { ...dayConfig, end_time: e.target.value };
                                            setServiceTimeSlotForm({ ...serviceTimeSlotForm, weekly_time_slot_config: newConfig });
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
                          </div>
                        )}
                      </div>
                      
                      <div style={{ display: 'flex', gap: '12px' }}>
                        <button
                          onClick={async () => {
                            try {
                              // 验证
                              if (serviceTimeSlotForm.has_time_slots) {
                                if (serviceTimeSlotForm.time_slot_duration_minutes <= 0) {
                                  message.warning('时间段时长必须大于0');
                                  return;
                                }
                                if (serviceTimeSlotForm.participants_per_slot <= 0) {
                                  message.warning('每个时间段最多参与者数量必须大于0');
                                  return;
                                }
                                
                                if (!serviceTimeSlotForm.use_weekly_config) {
                                  // 统一时间模式：验证开始和结束时间
                                  if (!serviceTimeSlotForm.time_slot_start_time || !serviceTimeSlotForm.time_slot_end_time) {
                                    message.warning('请设置时间段的开始和结束时间');
                                    return;
                                  }
                                  const startTime = serviceTimeSlotForm.time_slot_start_time.split(':').map(Number);
                                  const endTime = serviceTimeSlotForm.time_slot_end_time.split(':').map(Number);
                                  const startMinutes = startTime[0] * 60 + startTime[1];
                                  const endMinutes = endTime[0] * 60 + endTime[1];
                                  if (startMinutes >= endMinutes) {
                                    message.warning('开始时间必须早于结束时间');
                                    return;
                                  }
                                }
                              }
                              
                              // 构建提交数据
                              const submitData: any = {
                                has_time_slots: serviceTimeSlotForm.has_time_slots,
                                time_slot_duration_minutes: serviceTimeSlotForm.has_time_slots ? serviceTimeSlotForm.time_slot_duration_minutes : undefined,
                                participants_per_slot: serviceTimeSlotForm.has_time_slots ? serviceTimeSlotForm.participants_per_slot : undefined,
                              };
                              
                              if (serviceTimeSlotForm.has_time_slots) {
                                if (serviceTimeSlotForm.use_weekly_config) {
                                  // 构建按周几配置
                                  const weeklyConfig: { [key: string]: { enabled: boolean; start_time: string; end_time: string } } = {};
                                  Object.keys(serviceTimeSlotForm.weekly_time_slot_config).forEach(day => {
                                    const dayConfig = serviceTimeSlotForm.weekly_time_slot_config[day];
                                    weeklyConfig[day] = {
                                      enabled: dayConfig.enabled,
                                      start_time: dayConfig.start_time + ':00',
                                      end_time: dayConfig.end_time + ':00',
                                    };
                                  });
                                  submitData.weekly_time_slot_config = weeklyConfig;
                                  submitData.time_slot_start_time = undefined;
                                  submitData.time_slot_end_time = undefined;
                                } else {
                                  submitData.time_slot_start_time = serviceTimeSlotForm.time_slot_start_time + ':00';
                                  submitData.time_slot_end_time = serviceTimeSlotForm.time_slot_end_time + ':00';
                                  submitData.weekly_time_slot_config = null;
                                }
                              } else {
                                submitData.time_slot_start_time = undefined;
                                submitData.time_slot_end_time = undefined;
                                submitData.weekly_time_slot_config = undefined;
                              }
                              
                              await updateExpertServiceAdmin(taskExpertForm.id, editingService.id, submitData);
                              message.success('时间段配置更新成功');
                              setShowServiceEditModal(false);
                              const data = await getExpertServicesAdmin(taskExpertForm.id);
                              setExpertServices(data.services || []);
                            } catch (error: any) {
                                                            message.error(getErrorMessage(error));
                            }
                          }}
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
                          保存
                        </button>
                        <button
                          onClick={() => setShowServiceEditModal(false)}
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
                )}
              </div>
            )}

            {/* 活动管理标签页 */}
            {expertModalTab === 'activities' && (
              <div>
                {!taskExpertForm.id ? (
                  <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
                    请先保存任务达人基本信息
                  </div>
                ) : loadingActivities ? (
                  <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
                ) : (
                  <>
                    <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <h4 style={{ margin: 0 }}>活动列表</h4>
                      <button
                        onClick={async () => {
                          setLoadingActivities(true);
                          try {
                            const data = await getExpertActivitiesAdmin(taskExpertForm.id);
                            setExpertActivities(data.activities || []);
                            message.success('刷新成功');
                          } catch (error: any) {
                                                        message.error('加载活动列表失败');
                          } finally {
                            setLoadingActivities(false);
                          }
                        }}
                        style={{
                          padding: '6px 12px',
                          border: '1px solid #007bff',
                          background: 'white',
                          color: '#007bff',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px'
                        }}
                      >
                        刷新
                      </button>
                    </div>
                    {expertActivities.length === 0 ? (
                      <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
                        该任务达人暂无活动
                      </div>
                    ) : (
                      <div style={{ overflowX: 'auto' }}>
                        <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white' }}>
                          <thead>
                            <tr style={{ background: '#f8f9fa', borderBottom: '2px solid #dee2e6' }}>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>活动标题</th>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>状态</th>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>参与者</th>
                              <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>操作</th>
                            </tr>
                          </thead>
                          <tbody>
                            {expertActivities.map((activity) => (
                              <tr key={activity.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                                <td style={{ padding: '12px', fontSize: '14px' }}>{activity.title}</td>
                                <td style={{ padding: '12px', fontSize: '14px' }}>
                                  <span style={{
                                    padding: '4px 8px',
                                    borderRadius: '4px',
                                    fontSize: '12px',
                                    background: activity.status === 'open' ? '#d4edda' : activity.status === 'closed' ? '#fff3cd' : '#f8d7da',
                                    color: activity.status === 'open' ? '#155724' : activity.status === 'closed' ? '#856404' : '#721c24'
                                  }}>
                                    {activity.status === 'open' ? '开放' : activity.status === 'closed' ? '已关闭' : activity.status === 'cancelled' ? '已取消' : '已完成'}
                                  </span>
                                </td>
                                <td style={{ padding: '12px', fontSize: '14px' }}>
                                  {activity.min_participants} - {activity.max_participants} 人
                                </td>
                                <td style={{ padding: '12px' }}>
                                  <button
                                    onClick={async () => {
                                      const newStatus = activity.status === 'open' ? 'closed' : 'open';
                                      try {
                                        await updateExpertActivityAdmin(taskExpertForm.id, activity.id, { status: newStatus });
                                        message.success('活动状态更新成功');
                                        const data = await getExpertActivitiesAdmin(taskExpertForm.id);
                                        setExpertActivities(data.activities || []);
                                      } catch (error: any) {
                                                                                message.error(getErrorMessage(error));
                                      }
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
                                    {activity.status === 'open' ? '关闭' : '开放'}
                                  </button>
                                  <button
                                    onClick={() => {
                                      Modal.confirm({
                                        title: '确认删除',
                                        content: '确定要删除这个活动吗？',
                                        okText: '确定',
                                        cancelText: '取消',
                                        onOk: async () => {
                                          try {
                                            await deleteExpertActivityAdmin(taskExpertForm.id, activity.id);
                                            message.success('活动删除成功');
                                            const data = await getExpertActivitiesAdmin(taskExpertForm.id);
                                            setExpertActivities(data.activities || []);
                                          } catch (error: any) {
                                                                                        message.error(getErrorMessage(error));
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
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </>
                )}
              </div>
            )}

            {expertModalTab === 'basic' && (
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '30px' }}>
              <button
                onClick={async () => {
                  try {
                    if (taskExpertForm.name) {
                      // 准备要发送的数据，排除空字符串的头像字段（避免覆盖原有头像）
                      const dataToSend = { ...taskExpertForm };
                      // 如果头像为空字符串，删除该字段（后端会保留原值）
                      if (dataToSend.avatar === '') {
                        delete dataToSend.avatar;
                      }
                      
                      if (taskExpertForm.id) {
                        // 更新任务达人
                        await updateTaskExpert(taskExpertForm.id, dataToSend);
                        message.success('任务达人更新成功');
                      } else {
                        // 创建任务达人：必须提供 user_id
                        if (!dataToSend.user_id) {
                          message.error('创建任务达人时必须提供 user_id，请从已批准的申请中选择创建');
                          return;
                        }
                        await createTaskExpert(dataToSend);
                        message.success('任务达人创建成功');
                      }
                      setShowTaskExpertModal(false);
                      await loadDashboardData();
                    } else {
                      message.error('请输入任务达人名称');
                    }
                  } catch (error: any) {
                                        const errorMsg = getErrorMessage(error);
                    message.error(errorMsg);
                  }
                }}
                type="button"
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
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setShowTaskExpertModal(false);
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
            </div>
            )}
          </div>
        </div>
      )}
        </>
      )}

      {/* 申请审核 */}
      {taskExpertSubTab === 'applications' && (
        <>
          <div style={{ marginBottom: '20px' }}>
            <button
              onClick={loadExpertApplications}
              style={{
                padding: '8px 16px',
                background: '#007bff',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              刷新列表
            </button>
          </div>

          {loadingApplications ? (
        <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
      ) : expertApplications.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
          暂无待审核的申请
        </div>
      ) : (
        <div style={{ background: 'white', borderRadius: '8px', overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa', borderBottom: '2px solid #dee2e6' }}>
                <th style={{ padding: '12px', textAlign: 'left' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>用户</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>申请说明</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>申请时间</th>
                <th style={{ padding: '12px', textAlign: 'left' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {expertApplications.map((app) => (
                <tr key={app.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{app.id}</td>
                  <td style={{ padding: '12px' }}>
                    <div>
                      <div style={{ fontWeight: 600 }}>{app.user_name || app.user_id}</div>
                      <div style={{ fontSize: '12px', color: '#666' }}>ID: {app.user_id}</div>
                    </div>
                  </td>
                  <td style={{ padding: '12px', maxWidth: '300px' }}>
                    <div style={{ 
                      overflow: 'hidden', 
                      textOverflow: 'ellipsis', 
                      whiteSpace: 'nowrap',
                      fontSize: '14px'
                    }}>
                      {app.application_message || '-'}
                    </div>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      background: app.status === 'pending' ? '#fff3cd' : 
                                  app.status === 'approved' ? '#d4edda' : '#f8d7da',
                      color: app.status === 'pending' ? '#856404' :
                             app.status === 'approved' ? '#155724' : '#721c24'
                    }}>
                      {app.status === 'pending' ? '待审核' :
                       app.status === 'approved' ? '已批准' :
                       app.status === 'rejected' ? '已拒绝' : app.status}
                    </span>
                  </td>
                  <td style={{ padding: '12px', fontSize: '14px' }}>
                    {new Date(app.created_at).toLocaleString('zh-CN')}
                  </td>
                  <td style={{ padding: '12px' }}>
                    {app.status === 'pending' && (
                      <>
                        <button
                          onClick={() => {
                            setSelectedApplication(app);
                            setReviewAction('approve');
                            setReviewComment('');
                            setShowReviewModal(true);
                          }}
                          style={{
                            padding: '6px 12px',
                            marginRight: '8px',
                            border: 'none',
                            background: '#28a745',
                            color: 'white',
                            borderRadius: '4px',
                            cursor: 'pointer',
                            fontSize: '12px',
                            fontWeight: 600
                          }}
                        >
                          批准
                        </button>
                        <button
                          onClick={() => {
                            setSelectedApplication(app);
                            setReviewAction('reject');
                            setReviewComment('');
                            setShowReviewModal(true);
                          }}
                          style={{
                            padding: '6px 12px',
                            border: 'none',
                            background: '#dc3545',
                            color: 'white',
                            borderRadius: '4px',
                            cursor: 'pointer',
                            fontSize: '12px',
                            fontWeight: 600
                          }}
                        >
                          拒绝
                        </button>
                      </>
                    )}
                    {app.status === 'approved' && app.review_comment && (
                      <div style={{ fontSize: '12px', color: '#666', marginTop: '4px' }}>
                        审核意见: {app.review_comment}
                      </div>
                    )}
                    {app.status === 'rejected' && app.review_comment && (
                      <div style={{ fontSize: '12px', color: '#666', marginTop: '4px' }}>
                        拒绝原因: {app.review_comment}
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
        </>
      )}

      {/* 信息修改请求审核 */}
      {taskExpertSubTab === 'profile-updates' && (
        <>
          <div style={{ marginBottom: '20px' }}>
            <button
              onClick={loadProfileUpdateRequests}
              style={{
                padding: '8px 16px',
                background: '#007bff',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              刷新列表
            </button>
          </div>

          {loadingProfileUpdates ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
          ) : profileUpdateRequests.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
              暂无待审核的信息修改请求
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white' }}>
                <thead>
                  <tr style={{ background: '#f8f9fa', borderBottom: '2px solid #dee2e6' }}>
                    <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>任务达人ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>当前信息</th>
                    <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>修改后信息</th>
                    <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>提交时间</th>
                    <th style={{ padding: '12px', textAlign: 'left', fontSize: '14px', fontWeight: 600 }}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {profileUpdateRequests.map((request) => (
                    <tr key={request.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                      <td style={{ padding: '12px', fontSize: '14px' }}>{request.expert_id}</td>
                      <td style={{ padding: '12px', fontSize: '14px' }}>
                        <div style={{ marginBottom: '8px' }}>
                          <strong>名字:</strong> {request.expert?.expert_name || '-'}
                        </div>
                        <div style={{ marginBottom: '8px' }}>
                          <strong>简介:</strong> {request.expert?.bio ? (request.expert.bio.length > 50 ? request.expert.bio.substring(0, 50) + '...' : request.expert.bio) : '-'}
                        </div>
                        <div>
                          <strong>头像:</strong> {request.expert?.avatar ? (
                            <LazyImage src={request.expert.avatar} alt="当前头像" width={40} height={40} style={{ borderRadius: '50%', objectFit: 'cover', marginLeft: '8px' }} />
                          ) : '-'}
                        </div>
                      </td>
                      <td style={{ padding: '12px', fontSize: '14px' }}>
                        <div style={{ marginBottom: '8px' }}>
                          <strong>名字:</strong> {request.new_expert_name || '-'}
                        </div>
                        <div style={{ marginBottom: '8px' }}>
                          <strong>简介:</strong> {request.new_bio ? (request.new_bio.length > 50 ? request.new_bio.substring(0, 50) + '...' : request.new_bio) : '-'}
                        </div>
                        <div>
                          <strong>头像:</strong> {request.new_avatar ? (
                            <LazyImage src={request.new_avatar} alt="新头像" width={40} height={40} style={{ borderRadius: '50%', objectFit: 'cover', marginLeft: '8px' }} />
                          ) : '-'}
                        </div>
                      </td>
                      <td style={{ padding: '12px', fontSize: '14px' }}>
                        {new Date(request.created_at).toLocaleString('zh-CN')}
                      </td>
                      <td style={{ padding: '12px' }}>
                        {request.status === 'pending' && (
                          <>
                            <button
                              onClick={() => {
                                setSelectedProfileUpdate(request);
                                setProfileUpdateReviewAction('approve');
                                setProfileUpdateReviewComment('');
                                setShowProfileUpdateReviewModal(true);
                              }}
                              style={{
                                padding: '6px 12px',
                                marginRight: '8px',
                                border: 'none',
                                background: '#28a745',
                                color: 'white',
                                borderRadius: '4px',
                                cursor: 'pointer',
                                fontSize: '12px',
                                fontWeight: 600
                              }}
                            >
                              批准
                            </button>
                            <button
                              onClick={() => {
                                setSelectedProfileUpdate(request);
                                setProfileUpdateReviewAction('reject');
                                setProfileUpdateReviewComment('');
                                setShowProfileUpdateReviewModal(true);
                              }}
                              style={{
                                padding: '6px 12px',
                                border: 'none',
                                background: '#dc3545',
                                color: 'white',
                                borderRadius: '4px',
                                cursor: 'pointer',
                                fontSize: '12px',
                                fontWeight: 600
                              }}
                            >
                              拒绝
                            </button>
                          </>
                        )}
                        {request.status === 'approved' && (
                          <span style={{ color: '#28a745', fontSize: '12px' }}>已批准</span>
                        )}
                        {request.status === 'rejected' && (
                          <span style={{ color: '#dc3545', fontSize: '12px' }}>已拒绝</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}

      {/* 审核弹窗 - 移到任务达人管理内部 */}
      {showReviewModal && selectedApplication && (
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
          onClick={() => setShowReviewModal(false)}
        >
          <div
            style={{
              background: 'white',
              borderRadius: '12px',
              padding: '24px',
              maxWidth: '500px',
              width: '90%',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '18px', fontWeight: 600 }}>
              {reviewAction === 'approve' ? '批准申请' : '拒绝申请'}
            </h3>
            
            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '14px', color: '#666', marginBottom: '8px' }}>
                用户: {selectedApplication.user_name || selectedApplication.user_id}
              </div>
              {selectedApplication.application_message && (
                <div style={{ fontSize: '14px', color: '#666', marginBottom: '8px' }}>
                  申请说明: {selectedApplication.application_message}
                </div>
              )}
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                审核意见 {reviewAction === 'reject' && '*'}
              </label>
              <textarea
                value={reviewComment}
                onChange={(e) => setReviewComment(e.target.value)}
                placeholder={reviewAction === 'approve' ? '可选填写审核意见' : '请填写拒绝原因'}
                style={{
                  width: '100%',
                  minHeight: '100px',
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
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  handleReviewApplication();
                }}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: reviewAction === 'approve' ? '#28a745' : '#dc3545',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                确认{reviewAction === 'approve' ? '批准' : '拒绝'}
              </button>
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setShowReviewModal(false);
                  setSelectedApplication(null);
                  setReviewComment('');
                }}
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
      
      {/* 信息修改请求审核弹窗 */}
      {showProfileUpdateReviewModal && selectedProfileUpdate && (
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
          onClick={() => setShowProfileUpdateReviewModal(false)}
        >
          <div
            style={{
              background: 'white',
              borderRadius: '8px',
              padding: '24px',
              width: '90%',
              maxWidth: '500px',
              maxHeight: '90vh',
              overflow: 'auto'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '18px', fontWeight: 600 }}>
              {profileUpdateReviewAction === 'approve' ? '批准信息修改' : '拒绝信息修改'}
            </h3>
            
            <div style={{ marginBottom: '16px', padding: '12px', background: '#f8f9fa', borderRadius: '4px' }}>
              <div style={{ marginBottom: '8px' }}>
                <strong>任务达人ID:</strong> {selectedProfileUpdate.expert_id}
              </div>
              <div style={{ marginBottom: '8px' }}>
                <strong>修改内容:</strong>
                <div style={{ marginLeft: '16px', marginTop: '4px' }}>
                  {selectedProfileUpdate.new_expert_name && (
                    <div>名字: {selectedProfileUpdate.new_expert_name}</div>
                  )}
                  {selectedProfileUpdate.new_bio && (
                    <div>简介: {selectedProfileUpdate.new_bio}</div>
                  )}
                  {selectedProfileUpdate.new_avatar && (
                    <div>
                      头像: <LazyImage src={selectedProfileUpdate.new_avatar} alt="新头像" width={60} height={60} style={{ borderRadius: '50%', objectFit: 'cover', marginLeft: '8px' }} />
                    </div>
                  )}
                </div>
              </div>
            </div>
            
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                审核意见 {profileUpdateReviewAction === 'reject' && <span style={{ color: 'red' }}>*</span>}
              </label>
              <textarea
                value={profileUpdateReviewComment}
                onChange={(e) => setProfileUpdateReviewComment(e.target.value)}
                placeholder={profileUpdateReviewAction === 'approve' ? '可选：填写审核意见' : '请填写拒绝原因'}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '14px',
                  minHeight: '80px',
                  resize: 'vertical'
                }}
              />
            </div>
            
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowProfileUpdateReviewModal(false);
                  setSelectedProfileUpdate(null);
                  setProfileUpdateReviewComment('');
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
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  handleReviewProfileUpdate();
                }}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: profileUpdateReviewAction === 'approve' ? '#28a745' : '#dc3545',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600
                }}
              >
                {profileUpdateReviewAction === 'approve' ? '批准' : '拒绝'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 创建任务达人弹窗（从已批准申请中选择） */}
      {showCreateExpertModal && (
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
          onClick={() => setShowCreateExpertModal(false)}
        >
          <div
            style={{
              background: 'white',
              borderRadius: '12px',
              padding: '24px',
              maxWidth: '600px',
              width: '90%',
              maxHeight: '80vh',
              overflow: 'auto'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '18px', fontWeight: 600 }}>
              创建任务达人（从已批准申请中选择）
            </h3>
            
            {loadingApprovedApplications ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : approvedApplications.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
                暂无已批准且未创建任务达人的申请
              </div>
            ) : (
              <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ background: '#f8f9fa', borderBottom: '2px solid #dee2e6' }}>
                      <th style={{ padding: '12px', textAlign: 'left' }}>用户</th>
                      <th style={{ padding: '12px', textAlign: 'left' }}>申请说明</th>
                      <th style={{ padding: '12px', textAlign: 'left' }}>操作</th>
                    </tr>
                  </thead>
                  <tbody>
                    {approvedApplications.map((app) => (
                      <tr key={app.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                        <td style={{ padding: '12px' }}>
                          <div>
                            <div style={{ fontWeight: 600 }}>{app.user_name || app.user_id}</div>
                            <div style={{ fontSize: '12px', color: '#666' }}>ID: {app.user_id}</div>
                          </div>
                        </td>
                        <td style={{ padding: '12px', maxWidth: '200px' }}>
                          <div style={{ 
                            overflow: 'hidden', 
                            textOverflow: 'ellipsis', 
                            whiteSpace: 'nowrap',
                            fontSize: '14px'
                          }}>
                            {app.application_message || '-'}
                          </div>
                        </td>
                        <td style={{ padding: '12px' }}>
                          <button
                            onClick={async () => {
                              try {
                                await createExpertFromApplication(app.id);
                                message.success('任务达人创建成功');
                                setShowCreateExpertModal(false);
                                loadDashboardData(); // 刷新任务达人列表
                                loadExpertApplications(); // 刷新申请列表
                              } catch (err: any) {
                                const errorMsg = err.response?.data?.detail || '创建任务达人失败';
                                message.error(errorMsg);
                              }
                            }}
                            style={{
                              padding: '6px 12px',
                              border: 'none',
                              background: '#28a745',
                              color: 'white',
                              borderRadius: '4px',
                              cursor: 'pointer',
                              fontSize: '12px',
                              fontWeight: 600
                            }}
                          >
                            创建
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'flex-end' }}>
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setShowCreateExpertModal(false);
                }}
                style={{
                  padding: '10px 20px',
                  background: '#f3f4f6',
                  color: '#333',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                关闭
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  ), [taskExpertSubTab, taskExperts, currentPage, totalPages, loading, expertApplications, loadingApplications, profileUpdateRequests, loadingProfileUpdates, showTaskExpertModal, taskExpertForm, expertModalTab, expertServices, expertActivities, loadingServices, loadingActivities, editingService, showServiceEditModal, serviceTimeSlotForm, uploadingAvatar, approvedApplications, loadingApprovedApplications, showReviewModal, showProfileUpdateReviewModal, showCreateExpertModal, selectedApplication, selectedProfileUpdate, reviewAction, reviewComment, profileUpdateReviewAction, profileUpdateReviewComment, handleReviewApplication, handleReviewProfileUpdate, loadExpertApplications, loadProfileUpdateRequests]);

  // 加载任务争议列表
  const loadTaskDisputes = useCallback(async () => {
    try {
      setDisputesLoading(true);
      const response = await getAdminTaskDisputes({
        skip: (disputesPage - 1) * 20,
        limit: 20,
        status: disputesStatusFilter || undefined,
        keyword: disputesSearchKeyword.trim() || undefined
      });
      setTaskDisputes(response.disputes || []);
      setDisputesTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setDisputesLoading(false);
    }
  }, [disputesPage, disputesStatusFilter, disputesSearchKeyword]);

  useEffect(() => {
    if (activeTab === 'task-disputes') {
      loadTaskDisputes();
    }
  }, [activeTab, disputesPage, disputesStatusFilter, disputesSearchKeyword, loadTaskDisputes]);

  // 实时刷新待处理争议列表（每30秒刷新一次）
  useEffect(() => {
    if (activeTab === 'task-disputes') {
      // 只刷新待处理状态的争议
      const refreshInterval = setInterval(() => {
        if (!disputesLoading && (!disputesStatusFilter || disputesStatusFilter === 'pending')) {
          loadTaskDisputes();
        }
      }, 30000); // 30秒刷新一次

      return () => clearInterval(refreshInterval);
    }
  }, [activeTab, disputesStatusFilter, disputesLoading, loadTaskDisputes]);

  // 处理争议（解决或驳回）
  const handleDisputeAction = useCallback(async () => {
    if (!selectedDispute || !disputeResolutionNote.trim()) {
      message.error('请输入处理备注');
      return;
    }

    try {
      setProcessingDispute(true);
      if (disputeAction === 'resolve') {
        await resolveTaskDispute(selectedDispute.id, disputeResolutionNote.trim());
        message.success('争议已解决');
      } else {
        await dismissTaskDispute(selectedDispute.id, disputeResolutionNote.trim());
        message.success('争议已驳回');
      }
      setShowDisputeActionModal(false);
      setDisputeResolutionNote('');
      setSelectedDispute(null);
      await loadTaskDisputes();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setProcessingDispute(false);
    }
  }, [selectedDispute, disputeAction, disputeResolutionNote, loadTaskDisputes]);

  // 查看争议详情
  const handleViewDisputeDetail = useCallback(async (disputeId: number) => {
    try {
      const dispute = await getAdminTaskDisputeDetail(disputeId);
      setSelectedDispute(dispute);
      setShowDisputeDetailModal(true);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, []);

  // 打开处理争议弹窗
  const handleOpenDisputeAction = useCallback((dispute: any, action: 'resolve' | 'dismiss') => {
    setSelectedDispute(dispute);
    setDisputeAction(action);
    setDisputeResolutionNote('');
    setShowDisputeActionModal(true);
  }, []);

  const renderTaskDisputes = useCallback(() => (
    <div>
      <h2>任务争议管理</h2>
      
      {/* 筛选和搜索 */}
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
        <input
          type="text"
          placeholder="搜索任务标题、发布者姓名或争议原因..."
          value={disputesSearchKeyword}
          onChange={(e) => setDisputesSearchKeyword(e.target.value)}
          onKeyPress={(e) => {
            if (e.key === 'Enter') {
              setDisputesPage(1);
              loadTaskDisputes();
            }
          }}
          style={{
            padding: '8px 12px',
            border: '1px solid #ddd',
            borderRadius: '4px',
            fontSize: '14px',
            flex: '1',
            minWidth: '250px'
          }}
        />
        <select
          value={disputesStatusFilter}
          onChange={(e) => {
            setDisputesStatusFilter(e.target.value);
            setDisputesPage(1);
          }}
          style={{
            padding: '8px 12px',
            border: '1px solid #ddd',
            borderRadius: '4px',
            fontSize: '14px'
          }}
        >
          <option value="">全部状态</option>
          <option value="pending">待处理</option>
          <option value="resolved">已解决</option>
          <option value="dismissed">已驳回</option>
        </select>
        <button
          onClick={() => {
            setDisputesPage(1);
            loadTaskDisputes();
          }}
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
          搜索
        </button>
        {disputesSearchKeyword && (
          <button
            onClick={() => {
              setDisputesSearchKeyword('');
              setDisputesPage(1);
              // useEffect会自动触发loadTaskDisputes
            }}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: 'white',
              color: '#333',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            清除
          </button>
        )}
      </div>

      {/* 争议列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {disputesLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : taskDisputes.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
            {disputesSearchKeyword ? '未找到匹配的争议记录' : '暂无争议记录'}
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>任务</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>发布者</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>争议原因</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>创建时间</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {taskDisputes.map((dispute: any) => (
                <tr key={dispute.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{dispute.id}</td>
                  <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {dispute.task_title} (#{dispute.task_id})
                  </td>
                  <td style={{ padding: '12px' }}>{dispute.poster_name}</td>
                  <td style={{ padding: '12px', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {dispute.reason}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      fontWeight: '500',
                      background: dispute.status === 'pending' ? '#fff3cd' : dispute.status === 'resolved' ? '#d4edda' : '#f8d7da',
                      color: dispute.status === 'pending' ? '#856404' : dispute.status === 'resolved' ? '#155724' : '#721c24'
                    }}>
                      {dispute.status === 'pending' ? '待处理' : dispute.status === 'resolved' ? '已解决' : '已驳回'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    {new Date(dispute.created_at).toLocaleString('zh-CN')}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleViewDisputeDetail(dispute.id)}
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
                        查看
                      </button>
                      {dispute.status === 'pending' && (
                        <>
                          <button
                            onClick={() => handleOpenDisputeAction(dispute, 'resolve')}
                            style={{
                              padding: '4px 8px',
                              border: 'none',
                              background: '#28a745',
                              color: 'white',
                              borderRadius: '4px',
                              cursor: 'pointer',
                              fontSize: '12px'
                            }}
                          >
                            解决
                          </button>
                          <button
                            onClick={() => handleOpenDisputeAction(dispute, 'dismiss')}
                            style={{
                              padding: '4px 8px',
                              border: 'none',
                              background: '#dc3545',
                              color: 'white',
                              borderRadius: '4px',
                              cursor: 'pointer',
                              fontSize: '12px'
                            }}
                          >
                            驳回
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      {disputesTotal > 20 && (
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
          <button
            onClick={() => setDisputesPage(prev => Math.max(1, prev - 1))}
            disabled={disputesPage === 1}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: disputesPage === 1 ? '#f5f5f5' : 'white',
              color: disputesPage === 1 ? '#999' : '#333',
              borderRadius: '4px',
              cursor: disputesPage === 1 ? 'not-allowed' : 'pointer'
            }}
          >
            上一页
          </button>
          <span style={{ padding: '8px 16px', lineHeight: '32px' }}>
            第 {disputesPage} 页，共 {Math.ceil(disputesTotal / 20)} 页
          </span>
          <button
            onClick={() => setDisputesPage(prev => prev + 1)}
            disabled={disputesPage >= Math.ceil(disputesTotal / 20)}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: disputesPage >= Math.ceil(disputesTotal / 20) ? '#f5f5f5' : 'white',
              color: disputesPage >= Math.ceil(disputesTotal / 20) ? '#999' : '#333',
              borderRadius: '4px',
              cursor: disputesPage >= Math.ceil(disputesTotal / 20) ? 'not-allowed' : 'pointer'
            }}
          >
            下一页
          </button>
        </div>
      )}

      {/* 争议详情弹窗 */}
      {showDisputeDetailModal && selectedDispute && (
        <Modal
          title={`争议详情 #${selectedDispute.id}`}
          open={showDisputeDetailModal}
          onCancel={() => {
            setShowDisputeDetailModal(false);
            setSelectedDispute(null);
          }}
          footer={null}
          width={800}
        >
          <div style={{ padding: '20px' }}>
            <h3 style={{ marginBottom: '20px', fontSize: '18px', fontWeight: 'bold', borderBottom: '2px solid #e0e0e0', paddingBottom: '10px' }}>任务信息</h3>
            <div style={{ marginBottom: '20px' }}>
              <strong>任务标题：</strong>
              {selectedDispute.task_title || `任务 #${selectedDispute.task_id}`}
            </div>
            {selectedDispute.task_description && (
              <div style={{ marginBottom: '20px' }}>
                <strong>任务描述：</strong>
                <div style={{ marginTop: '8px', padding: '12px', background: '#f5f5f5', borderRadius: '4px', whiteSpace: 'pre-wrap', maxHeight: '150px', overflow: 'auto' }}>
                  {selectedDispute.task_description}
                </div>
              </div>
            )}
            <div style={{ marginBottom: '20px' }}>
              <strong>任务状态：</strong>
              <span style={{
                padding: '4px 8px',
                borderRadius: '4px',
                fontSize: '12px',
                fontWeight: '500',
                background: selectedDispute.task_status === 'completed' ? '#d4edda' : selectedDispute.task_status === 'in_progress' ? '#d1ecf1' : selectedDispute.task_status === 'pending_confirmation' ? '#fff3cd' : '#f8d7da',
                color: selectedDispute.task_status === 'completed' ? '#155724' : selectedDispute.task_status === 'in_progress' ? '#0c5460' : selectedDispute.task_status === 'pending_confirmation' ? '#856404' : '#721c24',
                marginLeft: '8px'
              }}>
                {selectedDispute.task_status === 'open' ? '开放中' : 
                 selectedDispute.task_status === 'taken' ? '已接受' : 
                 selectedDispute.task_status === 'in_progress' ? '进行中' : 
                 selectedDispute.task_status === 'pending_confirmation' ? '待确认' : 
                 selectedDispute.task_status === 'completed' ? '已完成' : 
                 selectedDispute.task_status === 'cancelled' ? '已取消' : 
                 selectedDispute.task_status || '未知'}
              </span>
            </div>
            {selectedDispute.task_created_at && (
              <div style={{ marginBottom: '20px' }}>
                <strong>任务创建时间：</strong>
                {new Date(selectedDispute.task_created_at).toLocaleString('zh-CN')}
              </div>
            )}
            {selectedDispute.task_accepted_at && (
              <div style={{ marginBottom: '20px' }}>
                <strong>任务接受时间：</strong>
                {new Date(selectedDispute.task_accepted_at).toLocaleString('zh-CN')}
              </div>
            )}
            {selectedDispute.task_completed_at && (
              <div style={{ marginBottom: '20px' }}>
                <strong>任务完成时间：</strong>
                {new Date(selectedDispute.task_completed_at).toLocaleString('zh-CN')}
              </div>
            )}

            <h3 style={{ marginBottom: '20px', marginTop: '30px', fontSize: '18px', fontWeight: 'bold', borderBottom: '2px solid #e0e0e0', paddingBottom: '10px' }}>参与方信息</h3>
            <div style={{ marginBottom: '20px' }}>
              <strong>发布者ID：</strong>
              {selectedDispute.poster_id}
            </div>
            <div style={{ marginBottom: '20px' }}>
              <strong>发布者姓名：</strong>
              {selectedDispute.poster_name || '未设置'}
            </div>
            {selectedDispute.taker_id && (
              <>
                <div style={{ marginBottom: '20px' }}>
                  <strong>接受者ID：</strong>
                  {selectedDispute.taker_id}
                </div>
                <div style={{ marginBottom: '20px' }}>
                  <strong>接受者姓名：</strong>
                  {selectedDispute.taker_name || '未设置'}
                </div>
              </>
            )}
            {!selectedDispute.taker_id && (
              <div style={{ marginBottom: '20px', color: '#999' }}>
                暂无接受者
              </div>
            )}

            <h3 style={{ marginBottom: '20px', marginTop: '30px', fontSize: '18px', fontWeight: 'bold', borderBottom: '2px solid #e0e0e0', paddingBottom: '10px' }}>支付信息</h3>
            <div style={{ marginBottom: '20px' }}>
              <strong>任务金额：</strong>
              {selectedDispute.task_amount !== null && selectedDispute.task_amount !== undefined ? (
                <span>
                  {selectedDispute.currency || 'GBP'} {Number(selectedDispute.task_amount).toFixed(2)}
                  {selectedDispute.agreed_reward && selectedDispute.base_reward && Number(selectedDispute.agreed_reward) !== Number(selectedDispute.base_reward) && (
                    <span style={{ marginLeft: '8px', color: '#999', textDecoration: 'line-through' }}>
                      (原价: {Number(selectedDispute.base_reward).toFixed(2)})
                    </span>
                  )}
                </span>
              ) : '未设置'}
            </div>
            {selectedDispute.base_reward && selectedDispute.agreed_reward && Number(selectedDispute.agreed_reward) !== Number(selectedDispute.base_reward) && (
              <div style={{ marginBottom: '20px' }}>
                <strong>原始标价：</strong>
                {selectedDispute.currency || 'GBP'} {Number(selectedDispute.base_reward).toFixed(2)}
              </div>
            )}
            {selectedDispute.agreed_reward && selectedDispute.base_reward && Number(selectedDispute.agreed_reward) !== Number(selectedDispute.base_reward) && (
              <div style={{ marginBottom: '20px' }}>
                <strong>最终成交价：</strong>
                {selectedDispute.currency || 'GBP'} {Number(selectedDispute.agreed_reward).toFixed(2)}
              </div>
            )}
            <div style={{ marginBottom: '20px' }}>
              <strong>支付状态：</strong>
              <span style={{
                padding: '4px 8px',
                borderRadius: '4px',
                fontSize: '12px',
                fontWeight: '500',
                background: selectedDispute.is_paid ? '#d4edda' : '#f8d7da',
                color: selectedDispute.is_paid ? '#155724' : '#721c24',
                marginLeft: '8px'
              }}>
                {selectedDispute.is_paid ? '✅ 已支付' : '⏳ 未支付'}
              </span>
            </div>
            {selectedDispute.payment_intent_id && (
              <div style={{ marginBottom: '20px' }}>
                <strong>支付Intent ID：</strong>
                <code style={{ padding: '4px 8px', background: '#f5f5f5', borderRadius: '4px', fontSize: '12px' }}>
                  {selectedDispute.payment_intent_id}
                </code>
              </div>
            )}
            <div style={{ marginBottom: '20px' }}>
              <strong>托管金额：</strong>
              {selectedDispute.currency || 'GBP'} {selectedDispute.escrow_amount !== null && selectedDispute.escrow_amount !== undefined ? Number(selectedDispute.escrow_amount).toFixed(2) : '0.00'}
            </div>
            <div style={{ marginBottom: '20px' }}>
              <strong>确认状态：</strong>
              <span style={{
                padding: '4px 8px',
                borderRadius: '4px',
                fontSize: '12px',
                fontWeight: '500',
                background: selectedDispute.is_confirmed ? '#d4edda' : '#fff3cd',
                color: selectedDispute.is_confirmed ? '#155724' : '#856404',
                marginLeft: '8px'
              }}>
                {selectedDispute.is_confirmed ? '✅ 已确认' : '⏳ 未确认'}
              </span>
            </div>
            {selectedDispute.paid_to_user_id && (
              <div style={{ marginBottom: '20px' }}>
                <strong>收款人ID：</strong>
                {selectedDispute.paid_to_user_id}
              </div>
            )}

            <h3 style={{ marginBottom: '20px', marginTop: '30px', fontSize: '18px', fontWeight: 'bold', borderBottom: '2px solid #e0e0e0', paddingBottom: '10px' }}>争议信息</h3>
            <div style={{ marginBottom: '20px' }}>
              <strong>争议原因：</strong>
              <div style={{ marginTop: '8px', padding: '12px', background: '#f5f5f5', borderRadius: '4px', whiteSpace: 'pre-wrap' }}>
                {selectedDispute.reason}
              </div>
            </div>
            <div style={{ marginBottom: '20px' }}>
              <strong>状态：</strong>
              <span style={{
                padding: '4px 8px',
                borderRadius: '4px',
                fontSize: '12px',
                fontWeight: '500',
                background: selectedDispute.status === 'pending' ? '#fff3cd' : selectedDispute.status === 'resolved' ? '#d4edda' : '#f8d7da',
                color: selectedDispute.status === 'pending' ? '#856404' : selectedDispute.status === 'resolved' ? '#155724' : '#721c24'
              }}>
                {selectedDispute.status === 'pending' ? '待处理' : selectedDispute.status === 'resolved' ? '已解决' : '已驳回'}
              </span>
            </div>
            <div style={{ marginBottom: '20px' }}>
              <strong>创建时间：</strong>
              {new Date(selectedDispute.created_at).toLocaleString('zh-CN')}
            </div>
            {selectedDispute.resolved_at && (
              <div style={{ marginBottom: '20px' }}>
                <strong>处理时间：</strong>
                {new Date(selectedDispute.resolved_at).toLocaleString('zh-CN')}
              </div>
            )}
            {selectedDispute.resolver_name && (
              <div style={{ marginBottom: '20px' }}>
                <strong>处理人：</strong>
                {selectedDispute.resolver_name}
              </div>
            )}
            {selectedDispute.resolution_note && (
              <div style={{ marginBottom: '20px' }}>
                <strong>处理备注：</strong>
                <div style={{ marginTop: '8px', padding: '12px', background: '#f5f5f5', borderRadius: '4px', whiteSpace: 'pre-wrap' }}>
                  {selectedDispute.resolution_note}
                </div>
              </div>
            )}
          </div>
        </Modal>
      )}

      {/* 处理争议弹窗 */}
      {showDisputeActionModal && selectedDispute && (
        <Modal
          title={disputeAction === 'resolve' ? '解决争议' : '驳回争议'}
          open={showDisputeActionModal}
          onCancel={() => {
            setShowDisputeActionModal(false);
            setDisputeResolutionNote('');
            setSelectedDispute(null);
          }}
          onOk={handleDisputeAction}
          confirmLoading={processingDispute}
          okText={disputeAction === 'resolve' ? '解决' : '驳回'}
          cancelText="取消"
          width={600}
        >
          <div style={{ padding: '20px 0' }}>
            <div style={{ marginBottom: '20px' }}>
              <strong>任务：</strong>
              {selectedDispute.task_title || `任务 #${selectedDispute.task_id}`}
            </div>
            <div style={{ marginBottom: '20px' }}>
              <strong>争议原因：</strong>
              <div style={{ marginTop: '8px', padding: '12px', background: '#f5f5f5', borderRadius: '4px', whiteSpace: 'pre-wrap' }}>
                {selectedDispute.reason}
              </div>
            </div>
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
                {disputeAction === 'resolve' ? '处理备注' : '驳回理由'}：
              </label>
              <textarea
                value={disputeResolutionNote}
                onChange={(e) => setDisputeResolutionNote(e.target.value)}
                placeholder={disputeAction === 'resolve' ? '请输入处理备注...' : '请输入驳回理由...'}
                rows={6}
                style={{
                  width: '100%',
                  padding: '12px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  fontSize: '14px',
                  resize: 'vertical'
                }}
              />
            </div>
          </div>
        </Modal>
      )}
    </div>
  ), [taskDisputes, disputesLoading, disputesPage, disputesTotal, disputesStatusFilter, disputesSearchKeyword, selectedDispute, showDisputeDetailModal, showDisputeActionModal, disputeAction, disputeResolutionNote, processingDispute, loadTaskDisputes, handleViewDisputeDetail, handleOpenDisputeAction, handleDisputeAction]);

  const renderNotifications = useCallback(() => (
    <div>
      <h2>发送通知</h2>
      <div className={styles.card}>
        <div className={styles.modalFormGroup}>
          <label className={styles.formLabel}>通知标题：</label>
          <input
            type="text"
            placeholder="请输入通知标题"
            value={notificationForm.title}
            onChange={(e) => setNotificationForm({...notificationForm, title: e.target.value})}
            className={styles.formInputFull}
          />
        </div>
        <div className={styles.modalFormGroup}>
          <label className={styles.formLabel}>通知内容：</label>
          <textarea
            placeholder="请输入通知内容"
            value={notificationForm.content}
            onChange={(e) => setNotificationForm({...notificationForm, content: e.target.value})}
            rows={4}
            className={styles.formTextarea}
          />
        </div>
        <div className={styles.modalFormGroup}>
          <label className={styles.formLabel}>目标用户ID（留空发送给所有用户）：</label>
          <input
            type="text"
            placeholder="用逗号分隔多个用户ID，如：1,2,3"
            onChange={(e) => {
              const ids = e.target.value.split(',').map(id => id.trim()).filter(id => id.length > 0);
              setNotificationForm({...notificationForm, user_ids: ids});
            }}
            className={styles.formInputFull}
          />
          <small className={styles.formHint}>
            提示：留空用户ID将发送给所有用户，填写用户ID将只发送给指定用户
          </small>
        </div>
        <div className={styles.formActions}>
          <button
            onClick={handleSendNotification}
            disabled={loading || !notificationForm.title || !notificationForm.content}
            className={`${styles.formButton} ${styles.formButtonPrimary}`}
            style={{ opacity: loading || !notificationForm.title || !notificationForm.content ? 0.6 : 1 }}
          >
            {loading ? '发送中...' : '发送通知'}
          </button>
          <button
            onClick={() => setNotificationForm({ title: '', content: '', user_ids: [] })}
            className={styles.formButtonClear}
          >
            清空表单
          </button>
        </div>
      </div>
      
      <div className={styles.infoBox}>
        <h4 className={styles.infoBoxTitle}>通知发送说明：</h4>
        <ul className={styles.infoBoxList}>
          <li className={styles.infoBoxItem}>通知标题和内容为必填项</li>
          <li className={styles.infoBoxItem}>用户ID留空时，通知将发送给所有用户</li>
          <li className={styles.infoBoxItem}>填写用户ID时，通知只发送给指定用户</li>
          <li className={styles.infoBoxItem}>多个用户ID用逗号分隔，如：1,2,3</li>
          <li className={styles.infoBoxItem}>发送后用户将在通知中心收到此消息</li>
        </ul>
      </div>
    </div>
  ), [notificationForm, loading, handleSendNotification]);

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
            const errorDetail = getErrorMessage(error);
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
      message.error(getErrorMessage(error));
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
          message.error(getErrorMessage(error));
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
      message.error(getErrorMessage(error));
    }
  };

  const renderInvitationCodes = useCallback(() => (
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
  ), [invitationCodes, invitationCodesPage, invitationCodesTotal, invitationCodesStatusFilter, showInvitationCodeModal, invitationCodeForm, setInvitationCodeForm, setShowInvitationCodeModal, setInvitationCodesStatusFilter, setInvitationCodesPage, loadDashboardData, handleCreateInvitationCode, handleUpdateInvitationCode, handleDeleteInvitationCode, getInvitationCodeDetail]);

  // 论坛板块管理相关函数
  const handleCreateForumCategory = async () => {
    if (!forumCategoryForm.name) {
      message.warning('请填写板块名称');
      return;
    }

    try {
      await createForumCategory({
        name: forumCategoryForm.name,
        description: forumCategoryForm.description || undefined,
        icon: forumCategoryForm.icon || undefined,
        sort_order: forumCategoryForm.sort_order || 0,
        is_visible: forumCategoryForm.is_visible,
        is_admin_only: forumCategoryForm.is_admin_only,
        // 学校板块访问控制字段
        type: forumCategoryForm.type,
        country: forumCategoryForm.country || undefined,
        university_code: forumCategoryForm.university_code || undefined
      });
      message.success('板块创建成功！');
      setShowForumCategoryModal(false);
      setForumCategoryForm({
        id: undefined,
        name: '',
        description: '',
        icon: '',
        sort_order: 0,
        is_visible: true,
        is_admin_only: false,
        // 学校板块访问控制字段
        type: 'general',
        country: '',
        university_code: ''
      });
      loadDashboardData();
    } catch (error: any) {
            const errorDetail = getErrorMessage(error);
      message.error(typeof errorDetail === 'string' ? errorDetail : JSON.stringify(errorDetail));
    }
  };

  const handleUpdateForumCategory = async () => {
    if (!forumCategoryForm.id) return;

    try {
      await updateForumCategory(forumCategoryForm.id, {
        name: forumCategoryForm.name || undefined,
        description: forumCategoryForm.description || undefined,
        icon: forumCategoryForm.icon || undefined,
        sort_order: forumCategoryForm.sort_order !== undefined ? forumCategoryForm.sort_order : undefined,
        is_visible: forumCategoryForm.is_visible,
        is_admin_only: forumCategoryForm.is_admin_only,
        // 学校板块访问控制字段
        type: forumCategoryForm.type,
        country: forumCategoryForm.country || undefined,
        university_code: forumCategoryForm.university_code || undefined
      });
      message.success('板块更新成功！');
      setShowForumCategoryModal(false);
      setForumCategoryForm({
        id: undefined,
        name: '',
        description: '',
        icon: '',
        sort_order: 0,
        is_visible: true,
        is_admin_only: false,
        // 学校板块访问控制字段
        type: 'general',
        country: '',
        university_code: ''
      });
      loadDashboardData();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleDeleteForumCategory = async (id: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个板块吗？删除后该板块下的所有帖子也将被删除！',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteForumCategory(id);
          message.success('板块删除成功！');
          loadDashboardData();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const handleEditForumCategory = (category: any) => {
    setForumCategoryForm({
      id: category.id,
      name: category.name,
      description: category.description || '',
      icon: category.icon || '',
      sort_order: category.sort_order || 0,
      is_visible: category.is_visible !== undefined ? category.is_visible : true,
      is_admin_only: category.is_admin_only !== undefined ? category.is_admin_only : false,
      // 学校板块访问控制字段
      type: category.type || 'general',
      country: category.country || '',
      university_code: category.university_code || ''
    });
    setShowForumCategoryModal(true);
  };

  // 当切换到论坛内容管理标签页时，自动加载数据
  useEffect(() => {
    if (activeTab === 'forum-posts') {
      // 确保板块列表已加载
      if (forumCategories.length === 0) {
        getForumCategories(false).then((categoriesData) => {
          setForumCategories(categoriesData.categories || []);
        });
      }
      // 延迟加载帖子，避免依赖循环
      const timer = setTimeout(() => {
        loadForumPosts();
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [activeTab, forumPostsPage, forumPostFilter.category_id, forumPostFilter.is_deleted, forumPostFilter.is_visible, forumCategories.length]);

  // 退出登录处理函数 - 使用useCallback优化
  const handleLogout = useCallback(async () => {
    try {
      await adminLogout();
      message.success('退出登录成功');
      navigate('/admin/login');
    } catch (error: any) {
            document.cookie.split(";").forEach((c) => {
        const eqPos = c.indexOf("=");
        const name = eqPos > -1 ? c.substr(0, eqPos).trim() : c.trim();
        document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
      });
      navigate('/admin/login');
    }
  }, [navigate]);

  // 标签页切换处理函数 - 使用useCallback优化
  const handleTabChange = useCallback((tab: string) => {
    setActiveTab(tab);
  }, []);

  // 加载论坛帖子 - 使用useCallback优化
  const loadForumPosts = useCallback(async () => {
    setForumPostsLoading(true);
    try {
      const params: any = {
        page: forumPostsPage,
        page_size: 20
      };
      if (forumPostFilter.category_id) {
        params.category_id = forumPostFilter.category_id;
      }
      if (forumPostFilter.search) {
        params.q = forumPostFilter.search;
      }
      if (forumPostFilter.is_deleted !== undefined) {
        params.is_deleted = forumPostFilter.is_deleted;
      }
      if (forumPostFilter.is_visible !== undefined) {
        params.is_visible = forumPostFilter.is_visible;
      }
      const response = await getForumPosts(params);
      setForumPosts(response.posts || []);
      setForumPostsTotal(response.total || 0);
    } catch (error: any) {
            message.error('加载论坛帖子失败');
    } finally {
      setForumPostsLoading(false);
    }
  }, [forumPostsPage, forumPostFilter]);

  // 创建/更新论坛帖子
  const handleCreateForumPost = async () => {
    if (!forumPostForm.title || !forumPostForm.content || !forumPostForm.category_id) {
      message.error('请填写完整信息');
      return;
    }
    try {
      if (forumPostForm.id) {
        await updateForumPost(forumPostForm.id, {
          title: forumPostForm.title,
          content: forumPostForm.content,
          category_id: forumPostForm.category_id
        });
        message.success('帖子更新成功');
      } else {
        await createForumPost({
          title: forumPostForm.title,
          content: forumPostForm.content,
          category_id: forumPostForm.category_id
        });
        message.success('帖子创建成功');
      }
      setShowForumPostModal(false);
      setForumPostForm({
        id: undefined,
        title: '',
        content: '',
        category_id: undefined
      });
      await loadForumPosts();
    } catch (error: any) {
            message.error(error?.response?.data?.detail || '操作失败');
    }
  };

  // 删除论坛帖子
  const handleDeleteForumPost = async (postId: number) => {
    if (!window.confirm('确定要删除这个帖子吗？')) {
      return;
    }
    try {
      await deleteForumPost(postId);
      message.success('帖子删除成功');
      await loadForumPosts();
    } catch (error: any) {
            message.error(error?.response?.data?.detail || '删除失败');
    }
  };

  // 编辑论坛帖子
  const handleEditForumPost = async (post: any) => {
    try {
      // 获取完整的帖子内容
      const fullPost = await getForumPost(post.id);
      setForumPostForm({
        id: fullPost.id,
        title: fullPost.title,
        content: fullPost.content,
        category_id: fullPost.category_id
      });
      setShowForumPostModal(true);
    } catch (error: any) {
            message.error('加载帖子详情失败');
    }
  };

  // 查看帖子详情
  const handleViewForumPostDetail = async (post: any) => {
    try {
      setForumRepliesLoading(true);
      const fullPost = await getForumPost(post.id);
      setSelectedForumPost(fullPost);
      setShowForumPostDetailModal(true);
      // 加载回复列表
      const repliesData = await getForumReplies(post.id, { page: 1, page_size: 50 });
      setForumReplies(repliesData.replies || []);
    } catch (error: any) {
      message.error('加载帖子详情失败');
    } finally {
      setForumRepliesLoading(false);
    }
  };

  // 提交回复
  const handleSubmitReply = async () => {
    if (!replyContent.trim()) {
      message.warning('请输入回复内容');
      return;
    }
    if (!selectedForumPost) return;
    try {
      setReplySubmitting(true);
      await createForumReply(selectedForumPost.id, {
        content: replyContent,
        parent_reply_id: replyingToReplyId || undefined
      });
      message.success('回复成功');
      setReplyContent('');
      setReplyingToReplyId(null);
      // 重新加载回复列表
      const repliesData = await getForumReplies(selectedForumPost.id, { page: 1, page_size: 50 });
      setForumReplies(repliesData.replies || []);
      // 更新帖子回复数
      const updatedPost = await getForumPost(selectedForumPost.id);
      setSelectedForumPost(updatedPost);
    } catch (error: any) {
      message.error(error?.response?.data?.detail || '回复失败');
    } finally {
      setReplySubmitting(false);
    }
  };

  const renderForumCategories = useCallback(() => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>论坛板块管理</h2>
        <button
          onClick={() => {
            setForumCategoryForm({
              id: undefined,
              name: '',
              description: '',
              icon: '',
              sort_order: 0,
              is_visible: true,
              is_admin_only: false,
              // 学校板块访问控制字段
              type: 'general',
              country: '',
              university_code: ''
            });
            setShowForumCategoryModal(true);
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
          创建板块
        </button>
      </div>

      {/* 板块列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>图标</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>名称</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>排序</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>帖子数</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>禁止用户发帖</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {forumCategories.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
                  暂无板块数据
                </td>
              </tr>
            ) : (
              forumCategories.map((category: any) => (
                <tr key={category.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{category.id}</td>
                  <td style={{ padding: '12px', fontSize: '20px' }}>{category.icon || '-'}</td>
                  <td style={{ padding: '12px', fontWeight: '500' }}>{category.name}</td>
                  <td style={{ padding: '12px', color: '#666', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {category.description || '-'}
                  </td>
                  <td style={{ padding: '12px' }}>{category.sort_order}</td>
                  <td style={{ padding: '12px' }}>{category.post_count || 0}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: category.is_visible ? '#d4edda' : '#f8d7da',
                      color: category.is_visible ? '#155724' : '#721c24',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {category.is_visible ? '显示' : '隐藏'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: category.is_admin_only ? '#fff3cd' : '#d1ecf1',
                      color: category.is_admin_only ? '#856404' : '#0c5460',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {category.is_admin_only ? '是' : '否'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleEditForumCategory(category)}
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
                        onClick={() => handleDeleteForumCategory(category.id)}
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

      {/* 创建/编辑板块模态框 */}
      {showForumCategoryModal && (
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
              {forumCategoryForm.id ? '编辑板块' : '创建板块'}
            </h3>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                板块名称 <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="text"
                value={forumCategoryForm.name}
                onChange={(e) => setForumCategoryForm({...forumCategoryForm, name: e.target.value})}
                placeholder="请输入板块名称"
                maxLength={100}
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>板块描述</label>
              <textarea
                value={forumCategoryForm.description}
                onChange={(e) => setForumCategoryForm({...forumCategoryForm, description: e.target.value})}
                placeholder="请输入板块描述（可选）"
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>图标</label>
              <input
                type="text"
                value={forumCategoryForm.icon}
                onChange={(e) => setForumCategoryForm({...forumCategoryForm, icon: e.target.value})}
                placeholder="请输入图标（emoji或图标URL，可选）"
                maxLength={200}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  marginTop: '5px'
                }}
              />
              <small style={{ color: '#666', fontSize: '12px', marginTop: '5px', display: 'block' }}>
                提示：可以使用emoji（如 📝、💻）或图标URL
              </small>
            </div>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>排序权重</label>
              <input
                type="number"
                value={forumCategoryForm.sort_order}
                onChange={(e) => setForumCategoryForm({...forumCategoryForm, sort_order: parseInt(e.target.value) || 0})}
                placeholder="数字越小越靠前，默认0"
                min="0"
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
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={forumCategoryForm.is_visible}
                  onChange={(e) => setForumCategoryForm({...forumCategoryForm, is_visible: e.target.checked})}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontWeight: 'bold' }}>显示</span>
              </label>
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={forumCategoryForm.is_admin_only}
                  onChange={(e) => setForumCategoryForm({...forumCategoryForm, is_admin_only: e.target.checked})}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontWeight: 'bold' }}>禁止用户发帖（仅管理员可发帖）</span>
              </label>
              <small style={{ color: '#666', fontSize: '12px', marginTop: '5px', display: 'block', marginLeft: '26px' }}>
                勾选后，普通用户将无法在此板块发帖，且该板块在发帖页面将被隐藏
              </small>
            </div>

            {/* 学校板块访问控制字段 */}
            <div style={{ marginBottom: '15px', padding: '15px', background: '#f5f5f5', borderRadius: '4px' }}>
              <label style={{ display: 'block', marginBottom: '10px', fontWeight: 'bold', color: '#333' }}>
                板块类型 <span style={{ color: 'red' }}>*</span>
              </label>
              <select
                value={forumCategoryForm.type}
                onChange={(e) => {
                  const newType = e.target.value as 'general' | 'root' | 'university';
                  setForumCategoryForm({
                    ...forumCategoryForm,
                    type: newType,
                    // 切换类型时清空相关字段
                    country: newType === 'root' ? forumCategoryForm.country : '',
                    university_code: newType === 'university' ? forumCategoryForm.university_code : ''
                  });
                }}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  marginTop: '5px'
                }}
              >
                <option value="general">普通板块（所有用户可见）</option>
                <option value="root">国家/地区级大板块（如"英国留学生"）</option>
                <option value="university">大学级小板块（如"布里斯托大学"）</option>
              </select>
              <small style={{ color: '#666', fontSize: '12px', marginTop: '5px', display: 'block' }}>
                选择板块类型以启用相应的访问控制
              </small>
            </div>

            {/* 国家代码字段（仅 root 类型显示） */}
            {forumCategoryForm.type === 'root' && (
              <div style={{ marginBottom: '15px' }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                  国家代码 <span style={{ color: 'red' }}>*</span>
                </label>
                <input
                  type="text"
                  value={forumCategoryForm.country}
                  onChange={(e) => setForumCategoryForm({...forumCategoryForm, country: e.target.value.toUpperCase()})}
                  placeholder="如：UK（英国）"
                  maxLength={10}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    marginTop: '5px'
                  }}
                />
                <small style={{ color: '#666', fontSize: '12px', marginTop: '5px', display: 'block' }}>
                  国家代码（如 UK），用于标识该大板块所属的国家
                </small>
              </div>
            )}

            {/* 大学编码字段（仅 university 类型显示） */}
            {forumCategoryForm.type === 'university' && (
              <div style={{ marginBottom: '15px' }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                  大学编码 <span style={{ color: 'red' }}>*</span>
                </label>
                <select
                  value={forumCategoryForm.university_code}
                  onChange={(e) => setForumCategoryForm({...forumCategoryForm, university_code: e.target.value})}
                  style={{
                    width: '100%',
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    marginTop: '5px'
                  }}
                >
                  <option value="">请选择大学</option>
                  {universities
                    .filter((u: any) => u.code) // 只显示有编码的大学
                    .map((u: any) => (
                      <option key={u.id} value={u.code}>
                        {u.name_cn || u.name} ({u.code})
                      </option>
                    ))}
                </select>
                <small style={{ color: '#666', fontSize: '12px', marginTop: '5px', display: 'block' }}>
                  选择对应的大学，该板块将仅对该大学的学生可见
                </small>
              </div>
            )}

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowForumCategoryModal(false);
                  setForumCategoryForm({
                    id: undefined,
                    name: '',
                    description: '',
                    icon: '',
                    sort_order: 0,
                    is_visible: true,
                    is_admin_only: false,
                    // 学校板块访问控制字段
                    type: 'general',
                    country: '',
                    university_code: ''
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
                onClick={forumCategoryForm.id ? handleUpdateForumCategory : handleCreateForumCategory}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: '#007bff',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                {forumCategoryForm.id ? '更新' : '创建'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  ), [forumCategories, showForumCategoryModal, forumCategoryForm, handleCreateForumCategory, handleUpdateForumCategory, handleDeleteForumCategory, handleEditForumCategory, setForumCategoryForm, setShowForumCategoryModal]);

  // 加载板块申请列表
  const loadCategoryRequests = useCallback(async () => {
    setLoadingCategoryRequests(true);
    try {
      const status = categoryRequestStatusFilter === 'all' ? undefined : categoryRequestStatusFilter;
      const requests = await getCategoryRequests(
        status,
        categoryRequestPage,
        categoryRequestPageSize,
        categoryRequestSearch || undefined,
        categoryRequestSortBy,
        categoryRequestSortOrder
      );
      setCategoryRequests(requests || []);
      // 注意：后端需要返回总数，这里暂时使用数组长度
      setCategoryRequestTotal(requests?.length || 0);
    } catch (error: any) {
      message.error('加载板块申请失败');
    } finally {
      setLoadingCategoryRequests(false);
    }
  }, [categoryRequestStatusFilter, categoryRequestPage, categoryRequestPageSize, categoryRequestSearch, categoryRequestSortBy, categoryRequestSortOrder]);

  // 审核板块申请
  const handleReviewCategoryRequest = async () => {
    if (!selectedCategoryRequest) return;
    
    if (categoryRequestReviewAction === 'reject' && !categoryRequestReviewComment.trim()) {
      message.warning('拒绝申请时请填写审核意见');
      return;
    }

    setReviewingCategoryRequest(true);
    try {
      await reviewCategoryRequest(
        selectedCategoryRequest.id,
        categoryRequestReviewAction,
        categoryRequestReviewComment.trim() || undefined
      );
      message.success(categoryRequestReviewAction === 'approve' ? '申请已批准' : '申请已拒绝');
      setShowCategoryRequestReviewModal(false);
      setCategoryRequestReviewComment('');
      await loadCategoryRequests();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setReviewingCategoryRequest(false);
    }
  };

  // 打开板块申请审核模态框
  const handleOpenCategoryRequestReviewModal = (request: any, action: 'approve' | 'reject') => {
    setSelectedCategoryRequest(request);
    setCategoryRequestReviewAction(action);
    setCategoryRequestReviewComment('');
    setShowCategoryRequestReviewModal(true);
  };

  // 渲染板块申请管理
  const renderCategoryRequests = useCallback(() => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>板块申请管理</h2>
        <button
          onClick={loadCategoryRequests}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: '#007bff',
            color: 'white',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          刷新
        </button>
      </div>

      {/* 搜索和筛选区域 */}
      <div style={{
        background: 'white',
        padding: '15px',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <div style={{ display: 'flex', gap: '15px', flexWrap: 'wrap', alignItems: 'center', marginBottom: '15px' }}>
          {/* 搜索框 */}
          <div style={{ flex: '1', minWidth: '200px' }}>
            <input
              type="text"
              placeholder="搜索板块名称或申请人..."
              value={categoryRequestSearch}
              onChange={(e) => {
                setCategoryRequestSearch(e.target.value);
                setCategoryRequestPage(1);
              }}
              onKeyPress={(e) => {
                if (e.key === 'Enter') {
                  loadCategoryRequests();
                }
              }}
              style={{
                width: '100%',
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
          </div>
          
          {/* 排序选择 */}
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <label style={{ fontSize: '14px', color: '#666' }}>排序：</label>
            <select
              value={categoryRequestSortBy}
              onChange={(e) => {
                setCategoryRequestSortBy(e.target.value as 'created_at' | 'reviewed_at' | 'status');
                setCategoryRequestPage(1);
              }}
              style={{
                padding: '6px 10px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            >
              <option value="created_at">申请时间</option>
              <option value="reviewed_at">审核时间</option>
              <option value="status">状态</option>
            </select>
            <select
              value={categoryRequestSortOrder}
              onChange={(e) => {
                setCategoryRequestSortOrder(e.target.value as 'asc' | 'desc');
                setCategoryRequestPage(1);
              }}
              style={{
                padding: '6px 10px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            >
              <option value="desc">降序</option>
              <option value="asc">升序</option>
            </select>
          </div>
        </div>
        
        {/* 状态筛选 */}
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          {(['all', 'pending', 'approved', 'rejected'] as const).map((status) => (
            <button
              key={status}
              onClick={() => {
                setCategoryRequestStatusFilter(status);
                setCategoryRequestPage(1);
              }}
              style={{
                padding: '8px 16px',
                border: 'none',
                background: categoryRequestStatusFilter === status ? '#007bff' : '#f0f0f0',
                color: categoryRequestStatusFilter === status ? 'white' : '#333',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: categoryRequestStatusFilter === status ? '600' : '400'
              }}
            >
              {status === 'all' ? '全部' : status === 'pending' ? '待审核' : status === 'approved' ? '已通过' : '已拒绝'}
            </button>
          ))}
        </div>
      </div>

      {/* 申请列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {loadingCategoryRequests ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>
            <div>加载中...</div>
          </div>
        ) : categoryRequests.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
            暂无申请数据
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>图标</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>板块名称</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>申请人</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>申请时间</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {categoryRequests.map((request: any) => (
                <tr key={request.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{request.id}</td>
                  <td style={{ padding: '12px', fontSize: '20px' }}>{request.icon || '-'}</td>
                  <td style={{ padding: '12px', fontWeight: '500' }}>{request.name}</td>
                  <td style={{ padding: '12px', color: '#666', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {request.description || '-'}
                  </td>
                  <td style={{ padding: '12px' }}>
                    {request.requester_name || request.requester_id || '-'}
                  </td>
                  <td style={{ padding: '12px' }}>
                    {dayjs(request.created_at).format('YYYY-MM-DD HH:mm')}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: request.status === 'approved' ? '#d4edda' : request.status === 'rejected' ? '#f8d7da' : '#fff3cd',
                      color: request.status === 'approved' ? '#155724' : request.status === 'rejected' ? '#721c24' : '#856404',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {request.status === 'pending' ? '待审核' : request.status === 'approved' ? '已通过' : '已拒绝'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                      {request.status === 'pending' ? (
                        <>
                        <button
                          onClick={() => handleOpenCategoryRequestReviewModal(request, 'approve')}
                            style={{
                              padding: '4px 8px',
                              border: '1px solid #28a745',
                              background: 'white',
                              color: '#28a745',
                              borderRadius: '4px',
                              cursor: 'pointer',
                              fontSize: '12px'
                            }}
                          >
                            批准
                          </button>
                        <button
                          onClick={() => handleOpenCategoryRequestReviewModal(request, 'reject')}
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
                            拒绝
                          </button>
                        </>
                      ) : (
                        <>
                          <span style={{ color: '#999', fontSize: '12px' }}>
                            {request.admin_name ? `审核人: ${request.admin_name}` : '-'}
                          </span>
                          {request.review_comment && (
                            <button
                              onClick={() => {
                                setSelectedCategoryRequest(request);
                                setShowCategoryRequestDetailModal(true);
                              }}
                              style={{
                                padding: '4px 8px',
                                border: '1px solid #007bff',
                                background: 'white',
                                color: '#007bff',
                                borderRadius: '4px',
                                cursor: 'pointer',
                                fontSize: '12px'
                              }}
                              title="查看详情"
                            >
                              详情
                            </button>
                          )}
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 审核模态框 */}
      {showCategoryRequestReviewModal && selectedCategoryRequest && (
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
              {categoryRequestReviewAction === 'approve' ? '批准申请' : '拒绝申请'}
            </h3>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>板块名称</label>
              <div style={{ padding: '8px', background: '#f5f5f5', borderRadius: '4px' }}>
                {selectedCategoryRequest.name}
              </div>
            </div>

            {selectedCategoryRequest.description && (
              <div style={{ marginBottom: '15px' }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>板块描述</label>
                <div style={{ padding: '8px', background: '#f5f5f5', borderRadius: '4px' }}>
                  {selectedCategoryRequest.description}
                </div>
              </div>
            )}

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                审核意见 {categoryRequestReviewAction === 'reject' && <span style={{ color: 'red' }}>*</span>}
              </label>
              <textarea
                value={categoryRequestReviewComment}
                onChange={(e) => setCategoryRequestReviewComment(e.target.value)}
                placeholder={categoryRequestReviewAction === 'approve' ? '请输入审核意见（可选）' : '请输入拒绝原因（必填）'}
                rows={4}
                maxLength={500}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  marginTop: '5px',
                  resize: 'vertical'
                }}
              />
              <div style={{ textAlign: 'right', marginTop: '5px', fontSize: '12px', color: '#666' }}>
                {categoryRequestReviewComment.length}/500
              </div>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '20px' }}>
              <button
                onClick={() => {
                  setShowCategoryRequestReviewModal(false);
                  setCategoryRequestReviewComment('');
                }}
                disabled={reviewingCategoryRequest}
                style={{
                  padding: '10px 20px',
                  border: '1px solid #ddd',
                  background: 'white',
                  color: '#333',
                  borderRadius: '4px',
                  cursor: reviewingCategoryRequest ? 'not-allowed' : 'pointer',
                  fontSize: '14px'
                }}
              >
                取消
              </button>
              <button
                onClick={handleReviewCategoryRequest}
                disabled={reviewingCategoryRequest || (categoryRequestReviewAction === 'reject' && !categoryRequestReviewComment.trim())}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: categoryRequestReviewAction === 'approve' ? '#28a745' : '#dc3545',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: reviewingCategoryRequest || (categoryRequestReviewAction === 'reject' && !categoryRequestReviewComment.trim()) ? 'not-allowed' : 'pointer',
                  fontSize: '14px',
                  opacity: reviewingCategoryRequest || (categoryRequestReviewAction === 'reject' && !categoryRequestReviewComment.trim()) ? 0.6 : 1
                }}
              >
                {reviewingCategoryRequest ? '处理中...' : categoryRequestReviewAction === 'approve' ? '批准' : '拒绝'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  ), [categoryRequests, loadingCategoryRequests, categoryRequestStatusFilter, categoryRequestPage, categoryRequestPageSize, categoryRequestTotal, categoryRequestSearch, categoryRequestSortBy, categoryRequestSortOrder, showCategoryRequestReviewModal, showCategoryRequestDetailModal, selectedCategoryRequest, categoryRequestReviewAction, categoryRequestReviewComment, reviewingCategoryRequest, loadCategoryRequests, handleOpenCategoryRequestReviewModal, handleReviewCategoryRequest]);

  const renderForumPosts = useCallback(() => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>论坛内容管理</h2>
        <button
          onClick={() => {
            setForumPostForm({
              id: undefined,
              title: '',
              content: '',
              category_id: undefined
            });
            setShowForumPostModal(true);
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
          快速发帖
        </button>
      </div>

      {/* 筛选区域 */}
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
          <select
            value={forumPostFilter.category_id || ''}
            onChange={(e) => {
              setForumPostFilter({...forumPostFilter, category_id: e.target.value ? Number(e.target.value) : undefined});
              setForumPostsPage(1);
            }}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
          >
            <option value="">全部板块</option>
            {forumCategories.map((cat: any) => (
              <option key={cat.id} value={cat.id}>{cat.name}</option>
            ))}
          </select>
          <input
            type="text"
            placeholder="搜索标题..."
            value={forumPostFilter.search}
            onChange={(e) => {
              setForumPostFilter({...forumPostFilter, search: e.target.value});
              setForumPostsPage(1);
            }}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', flex: 1, minWidth: '200px' }}
          />
          <select
            value={forumPostFilter.is_deleted === undefined ? '' : forumPostFilter.is_deleted ? 'deleted' : 'not_deleted'}
            onChange={(e) => {
              setForumPostFilter({
                ...forumPostFilter,
                is_deleted: e.target.value === '' ? undefined : e.target.value === 'deleted'
              });
              setForumPostsPage(1);
            }}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
          >
            <option value="">全部状态</option>
            <option value="not_deleted">未删除</option>
            <option value="deleted">已删除</option>
          </select>
          <select
            value={forumPostFilter.is_visible === undefined ? '' : forumPostFilter.is_visible ? 'visible' : 'hidden'}
            onChange={(e) => {
              setForumPostFilter({
                ...forumPostFilter,
                is_visible: e.target.value === '' ? undefined : e.target.value === 'visible'
              });
              setForumPostsPage(1);
            }}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
          >
            <option value="">全部可见性</option>
            <option value="visible">可见</option>
            <option value="hidden">隐藏</option>
          </select>
          <button
            onClick={loadForumPosts}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: '#007bff',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            搜索
          </button>
        </div>
      </div>

      {/* 帖子列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {forumPostsLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : forumPosts.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无帖子</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>标题</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>板块</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>作者</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {forumPosts.map((post: any) => (
                <tr key={post.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{post.id}</td>
                  <td style={{ padding: '12px', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {post.is_pinned && <span style={{ color: '#ff6b6b', marginRight: '4px' }}>📌</span>}
                    {post.is_featured && <span style={{ color: '#ffd93d', marginRight: '4px' }}>⭐</span>}
                    {post.is_locked && <span style={{ color: '#999', marginRight: '4px' }}>🔒</span>}
                    {post.title}
                  </td>
                  <td style={{ padding: '12px' }}>{post.category?.name || '-'}</td>
                  <td style={{ padding: '12px' }}>{post.author?.name || '-'}</td>
                  <td className={styles.tableBody}>
                    <div className={styles.statusTags}>
                      {post.is_deleted && <span className={`${styles.statusTag} ${styles.statusTagDeleted}`}>已删除</span>}
                      {!post.is_visible && <span className={`${styles.statusTag} ${styles.statusTagHidden}`}>已隐藏</span>}
                      {post.is_pinned && <span className={`${styles.statusTag} ${styles.statusTagPinned}`}>置顶</span>}
                      {post.is_featured && <span className={`${styles.statusTag} ${styles.statusTagFeatured}`}>加精</span>}
                      {post.is_locked && <span className={`${styles.statusTag} ${styles.statusTagLocked}`}>锁定</span>}
                    </div>
                  </td>
                  <td className={styles.tableBody}>
                    <div className={styles.actionButtonGroupSmall}>
                      <button
                        onClick={() => handleViewForumPostDetail(post)}
                        className={`${styles.actionButtonSmall} ${styles.actionButtonSmallPrimary}`}
                      >
                        查看详情
                      </button>
                      <button
                        onClick={() => handleEditForumPost(post)}
                        className={`${styles.actionButtonSmall} ${styles.actionButtonSmallPrimary}`}
                      >
                        编辑
                      </button>
                      {!post.is_pinned && (
                        <button
                          onClick={async () => {
                            try {
                              await pinForumPost(post.id);
                              message.success('已置顶');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          className={`${styles.actionButtonSmall} ${styles.actionButtonSmallSuccess}`}
                        >
                          置顶
                        </button>
                      )}
                      {post.is_pinned && (
                        <button
                          onClick={async () => {
                            try {
                              await unpinForumPost(post.id);
                              message.success('已取消置顶');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          className={`${styles.actionButtonSmall} ${styles.actionButtonSmallWarning}`}
                        >
                          取消置顶
                        </button>
                      )}
                      {!post.is_featured && (
                        <button
                          onClick={async () => {
                            try {
                              await featureForumPost(post.id);
                              message.success('已加精');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          className={`${styles.actionButtonSmall} ${styles.actionButtonSmallWarning}`}
                        >
                          加精
                        </button>
                      )}
                      {post.is_featured && (
                        <button
                          onClick={async () => {
                            try {
                              await unfeatureForumPost(post.id);
                              message.success('已取消加精');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          className={`${styles.actionButtonSmall} ${styles.actionButtonSmallSecondary}`}
                        >
                          取消加精
                        </button>
                      )}
                      {!post.is_locked && (
                        <button
                          onClick={async () => {
                            try {
                              await lockForumPost(post.id);
                              message.success('已锁定');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          className={`${styles.actionButtonSmall} ${styles.actionButtonSmallDanger}`}
                        >
                          锁定
                        </button>
                      )}
                      {post.is_locked && (
                        <button
                          onClick={async () => {
                            try {
                              await unlockForumPost(post.id);
                              message.success('已解锁');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          style={{ padding: '4px 8px', border: '1px solid #28a745', background: 'white', color: '#28a745', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                        >
                          解锁
                        </button>
                      )}
                      {post.is_visible && !post.is_deleted && (
                        <button
                          onClick={async () => {
                            try {
                              await hideForumPost(post.id);
                              message.success('已隐藏');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          style={{ padding: '4px 8px', border: '1px solid #ffc107', background: 'white', color: '#ffc107', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                        >
                          隐藏
                        </button>
                      )}
                      {!post.is_visible && (
                        <button
                          onClick={async () => {
                            try {
                              await unhideForumPost(post.id);
                              message.success('已取消隐藏');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          style={{ padding: '4px 8px', border: '1px solid #17a2b8', background: 'white', color: '#17a2b8', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                        >
                          取消隐藏
                        </button>
                      )}
                      {post.is_deleted && (
                        <button
                          onClick={async () => {
                            try {
                              await restoreForumPost(post.id);
                              message.success('已恢复');
                              await loadForumPosts();
                            } catch (error: any) {
                              message.error(error?.response?.data?.detail || '操作失败');
                            }
                          }}
                          style={{ padding: '4px 8px', border: '1px solid #17a2b8', background: 'white', color: '#17a2b8', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                        >
                          恢复
                        </button>
                      )}
                      {!post.is_deleted && (
                        <button
                          onClick={() => handleDeleteForumPost(post.id)}
                          style={{ padding: '4px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                        >
                          删除
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      {forumPostsTotal > 20 && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: '20px', gap: '10px' }}>
          <button
            onClick={() => {
              if (forumPostsPage > 1) {
                setForumPostsPage(forumPostsPage - 1);
              }
            }}
            disabled={forumPostsPage === 1}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: forumPostsPage === 1 ? '#f5f5f5' : 'white',
              color: forumPostsPage === 1 ? '#999' : '#333',
              borderRadius: '4px',
              cursor: forumPostsPage === 1 ? 'not-allowed' : 'pointer'
            }}
          >
            上一页
          </button>
          <span style={{ padding: '8px 16px', display: 'flex', alignItems: 'center' }}>
            第 {forumPostsPage} 页，共 {Math.ceil(forumPostsTotal / 20)} 页
          </span>
          <button
            onClick={() => {
              if (forumPostsPage < Math.ceil(forumPostsTotal / 20)) {
                setForumPostsPage(forumPostsPage + 1);
              }
            }}
            disabled={forumPostsPage >= Math.ceil(forumPostsTotal / 20)}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: forumPostsPage >= Math.ceil(forumPostsTotal / 20) ? '#f5f5f5' : 'white',
              color: forumPostsPage >= Math.ceil(forumPostsTotal / 20) ? '#999' : '#333',
              borderRadius: '4px',
              cursor: forumPostsPage >= Math.ceil(forumPostsTotal / 20) ? 'not-allowed' : 'pointer'
            }}
          >
            下一页
          </button>
        </div>
      )}

      {/* 快速发帖模态框 */}
      {showForumPostModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div 
            style={{
              background: 'white',
              borderRadius: '8px',
              padding: '24px',
              width: '90%',
              maxWidth: '800px',
              maxHeight: '90vh',
              overflow: 'auto'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ marginBottom: '20px' }}>{forumPostForm.id ? '编辑帖子' : '快速发帖'}</h3>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>板块</label>
              <select
                value={forumPostForm.category_id || ''}
                onChange={(e) => setForumPostForm({...forumPostForm, category_id: e.target.value ? Number(e.target.value) : undefined})}
                style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
              >
                <option value="">请选择板块</option>
                {forumCategories.map((cat: any) => (
                  <option key={cat.id} value={cat.id}>{cat.name}</option>
                ))}
              </select>
            </div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>标题</label>
              <input
                type="text"
                value={forumPostForm.title}
                onChange={(e) => setForumPostForm({...forumPostForm, title: e.target.value})}
                style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
                placeholder="请输入标题"
              />
            </div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>内容</label>
              <textarea
                value={forumPostForm.content}
                onChange={(e) => setForumPostForm({...forumPostForm, content: e.target.value})}
                style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #ddd', minHeight: '200px', fontFamily: 'inherit' }}
                placeholder="请输入内容"
              />
            </div>
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setShowForumPostModal(false);
                  setForumPostForm({
                    id: undefined,
                    title: '',
                    content: '',
                    category_id: undefined
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
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  handleCreateForumPost();
                }}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: '#007bff',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                {forumPostForm.id ? '更新' : '发布'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 帖子详情模态框 */}
      {showForumPostDetailModal && selectedForumPost && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1001
        }}>
          <div 
            style={{
              background: 'white',
              borderRadius: '8px',
              padding: '24px',
              width: '90%',
              maxWidth: '900px',
              maxHeight: '90vh',
              overflow: 'auto'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3 style={{ margin: 0 }}>帖子详情</h3>
              <button
                onClick={() => {
                  setShowForumPostDetailModal(false);
                  setSelectedForumPost(null);
                  setForumReplies([]);
                  setReplyContent('');
                  setReplyingToReplyId(null);
                }}
                style={{
                  padding: '4px 12px',
                  border: '1px solid #ddd',
                  background: 'white',
                  color: '#666',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                关闭
              </button>
            </div>

            {/* 帖子内容 */}
            <div style={{ marginBottom: '24px', padding: '16px', background: '#f8f9fa', borderRadius: '4px' }}>
              <div style={{ marginBottom: '12px' }}>
                <h4 style={{ margin: '0 0 8px 0' }}>{selectedForumPost.title}</h4>
                <div style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
                  <span>板块：{selectedForumPost.category?.name || '-'}</span>
                  <span style={{ marginLeft: '16px' }}>作者：{selectedForumPost.author?.name || '-'}</span>
                  {selectedForumPost.author?.is_admin && (
                    <span style={{ marginLeft: '8px', padding: '2px 6px', background: '#1890ff', color: 'white', borderRadius: '4px', fontSize: '12px' }}>官方</span>
                  )}
                  <span style={{ marginLeft: '16px' }}>回复数：{selectedForumPost.reply_count || 0}</span>
                </div>
              </div>
              <div style={{ 
                padding: '12px', 
                background: 'white', 
                borderRadius: '4px',
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-word'
              }}>
                {selectedForumPost.content}
              </div>
            </div>

            {/* 回复列表 */}
            <div style={{ marginBottom: '24px' }}>
              <h4 style={{ marginBottom: '12px' }}>回复列表</h4>
              {forumRepliesLoading ? (
                <div style={{ padding: '20px', textAlign: 'center', color: '#999' }}>加载中...</div>
              ) : forumReplies.length === 0 ? (
                <div style={{ padding: '20px', textAlign: 'center', color: '#999' }}>暂无回复</div>
              ) : (
                <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
                  {(() => {
                    // 递归渲染回复（包括嵌套回复）
                    const renderReply = (reply: any, level: number = 0) => {
                      if (level > 2) return null; // 最多3层嵌套
                      return (
                        <div key={reply.id} style={{ 
                          marginBottom: '12px', 
                          padding: '12px', 
                          background: '#f8f9fa', 
                          borderRadius: '4px',
                          borderLeft: '3px solid #007bff',
                          marginLeft: level * 24
                        }}>
                          <div style={{ marginBottom: '8px', fontSize: '14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                            <div>
                              <span style={{ fontWeight: '500' }}>{reply.author?.name || '未知用户'}</span>
                              {reply.author?.is_admin === true && (
                                <span style={{ marginLeft: '8px', padding: '2px 6px', background: '#1890ff', color: 'white', borderRadius: '4px', fontSize: '12px' }}>官方</span>
                              )}
                              <span style={{ marginLeft: '12px', color: '#999', fontSize: '12px' }}>
                                {dayjs(reply.created_at).format('YYYY-MM-DD HH:mm:ss')}
                              </span>
                            </div>
                            <button
                              onClick={() => {
                                setReplyingToReplyId(reply.id);
                                // 滚动到回复输入框
                                setTimeout(() => {
                                  const textarea = document.querySelector('textarea[placeholder="请输入回复内容..."]') as HTMLTextAreaElement;
                                  if (textarea) {
                                    textarea.focus();
                                    textarea.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                                  }
                                }, 100);
                              }}
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
                              回复
                            </button>
                          </div>
                          <div style={{ 
                            whiteSpace: 'pre-wrap',
                            wordBreak: 'break-word',
                            color: '#333'
                          }}>
                            {reply.content}
                          </div>
                          {/* 嵌套回复 */}
                          {reply.replies && reply.replies.length > 0 && (
                            <div style={{ marginTop: '12px', paddingLeft: '12px', borderLeft: '2px solid #e0e0e0' }}>
                              {reply.replies.map((childReply: any) => renderReply(childReply, level + 1))}
                            </div>
                          )}
                        </div>
                      );
                    };
                    return forumReplies.map((reply: any) => renderReply(reply));
                  })()}
                </div>
              )}
            </div>

            {/* 回复输入框 */}
            {!selectedForumPost.is_locked && (
              <div>
                <h4 style={{ marginBottom: '12px' }}>
                  管理员回复
                  {replyingToReplyId && (
                    <span style={{ marginLeft: '12px', fontSize: '14px', color: '#666', fontWeight: 'normal' }}>
                      (回复 #{replyingToReplyId})
                      <button
                        onClick={() => setReplyingToReplyId(null)}
                        style={{
                          marginLeft: '8px',
                          padding: '2px 6px',
                          border: '1px solid #ddd',
                          background: 'white',
                          color: '#666',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px'
                        }}
                      >
                        取消
                      </button>
                    </span>
                  )}
                </h4>
                <textarea
                  value={replyContent}
                  onChange={(e) => setReplyContent(e.target.value)}
                  placeholder={replyingToReplyId ? `回复 #${replyingToReplyId}...` : "请输入回复内容..."}
                  style={{
                    width: '100%',
                    padding: '12px',
                    borderRadius: '4px',
                    border: '1px solid #ddd',
                    minHeight: '120px',
                    fontFamily: 'inherit',
                    fontSize: '14px',
                    resize: 'vertical',
                    marginBottom: '12px'
                  }}
                  maxLength={10000}
                />
                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                  <button
                    onClick={() => {
                      setReplyContent('');
                      setReplyingToReplyId(null);
                    }}
                    style={{
                      padding: '8px 16px',
                      border: '1px solid #ddd',
                      background: 'white',
                      color: '#666',
                      borderRadius: '4px',
                      cursor: 'pointer'
                    }}
                  >
                    清空
                  </button>
                  <button
                    onClick={handleSubmitReply}
                    disabled={replySubmitting || !replyContent.trim()}
                    style={{
                      padding: '8px 16px',
                      border: 'none',
                      background: replySubmitting || !replyContent.trim() ? '#ccc' : '#007bff',
                      color: 'white',
                      borderRadius: '4px',
                      cursor: replySubmitting || !replyContent.trim() ? 'not-allowed' : 'pointer'
                    }}
                  >
                    {replySubmitting ? '提交中...' : '提交回复'}
                  </button>
                </div>
              </div>
            )}
            {selectedForumPost.is_locked && (
              <div style={{ padding: '12px', background: '#fff3cd', borderRadius: '4px', color: '#856404' }}>
                帖子已锁定，无法回复
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  ), [forumPostFilter, forumCategories, forumPosts, forumPostsLoading, forumPostsPage, forumPostsTotal, loadForumPosts, handleCreateForumPost, handleEditForumPost, handleViewForumPostDetail, pinForumPost, unpinForumPost, featureForumPost, unfeatureForumPost, lockForumPost, unlockForumPost, restoreForumPost, unhideForumPost, deleteForumPost, setForumPostFilter, setForumPostsPage, setShowForumPostModal, setForumPostForm, showForumPostDetailModal, selectedForumPost, forumReplies, forumRepliesLoading, replyContent, replySubmitting, handleSubmitReply]);

  // 加载论坛举报 - 使用useCallback优化
  const loadForumReports = useCallback(async () => {
    setForumReportsLoading(true);
    try {
      const response = await getForumReports({
        status_filter: forumReportsStatusFilter,
        page: forumReportsPage,
        page_size: 20
      });
      setForumReports(response.reports || []);
      setForumReportsTotal(response.total || 0);
    } catch (error: any) {
            message.error('加载论坛举报失败');
    } finally {
      setForumReportsLoading(false);
    }
  }, [forumReportsStatusFilter, forumReportsPage]);

  // 加载跳蚤市场举报 - 使用useCallback优化
  const loadFleaMarketReports = useCallback(async () => {
    setFleaMarketReportsLoading(true);
    try {
      const response = await getFleaMarketReports({
        status_filter: fleaMarketReportsStatusFilter,
        page: fleaMarketReportsPage,
        page_size: 20
      });
      setFleaMarketReports(response.reports || []);
      setFleaMarketReportsTotal(response.total || 0);
    } catch (error: any) {
            message.error('加载跳蚤市场举报失败');
    } finally {
      setFleaMarketReportsLoading(false);
    }
  }, [fleaMarketReportsStatusFilter, fleaMarketReportsPage]);

  // 处理举报
  const [targetInfo, setTargetInfo] = useState<any>(null);
  const [loadingTargetInfo, setLoadingTargetInfo] = useState(false);

  // 加载目标对象信息
  const loadTargetInfo = async (report: any) => {
    setLoadingTargetInfo(true);
    try {
      if (report.type === 'forum') {
        // 获取帖子或回复信息
        if (report.target_type === 'post') {
          const postData = await getForumPost(report.target_id);
          setTargetInfo({
            type: 'post',
            id: postData.id,
            title: postData.title,
            author_id: postData.author?.id,
            author_name: postData.author?.name,
            is_deleted: postData.is_deleted,
            is_visible: postData.is_visible,
            is_locked: postData.is_locked
          });
        } else {
          // 回复信息：需要先获取帖子，然后从回复列表中查找
          // 这里简化处理，只设置基本信息
          setTargetInfo({
            type: 'reply',
            id: report.target_id,
            author_id: null,
            author_name: null
          });
        }
      } else if (report.type === 'flea_market') {
        // 获取商品信息
        const itemData = await api.get(`/api/flea-market/items/${report.item_id}`);
        setTargetInfo({
          type: 'item',
          id: report.item_id,
          title: itemData.data.title,
          seller_id: itemData.data.seller_id,
          seller_name: itemData.data.seller?.name,
          status: itemData.data.status
        });
      }
    } catch (error: any) {
            message.error('加载目标信息失败');
    } finally {
      setLoadingTargetInfo(false);
    }
  };

  // 执行操作
  const handleQuickAction = async (action: string) => {
    if (!currentReport || !targetInfo) return;

    try {
      if (currentReport.type === 'forum') {
        if (action === 'delete_post' && targetInfo.type === 'post') {
          await deleteForumPost(targetInfo.id);
          message.success('帖子已删除');
        } else if (action === 'hide_post' && targetInfo.type === 'post') {
          await hideForumPost(targetInfo.id);
          message.success('帖子已隐藏');
        } else if (action === 'lock_post' && targetInfo.type === 'post') {
          await lockForumPost(targetInfo.id);
          message.success('帖子已锁定');
        } else if (action === 'ban_user' && targetInfo.author_id) {
          await updateUserByAdmin(targetInfo.author_id, { is_banned: 1 });
          message.success('用户已封禁');
        } else if (action === 'suspend_user' && targetInfo.author_id) {
          const suspendUntil = new Date();
          suspendUntil.setDate(suspendUntil.getDate() + 7); // 暂停7天
          await updateUserByAdmin(targetInfo.author_id, {
            is_suspended: 1,
            suspend_until: suspendUntil.toISOString()
          });
          message.success('用户已暂停7天');
        }
      } else if (currentReport.type === 'flea_market') {
        if (action === 'take_down_item') {
          await api.put(`/api/flea-market/items/${targetInfo.id}`, {
            status: 'deleted'
          });
          message.success('商品已下架');
        } else if (action === 'ban_seller' && targetInfo.seller_id) {
          await updateUserByAdmin(targetInfo.seller_id, { is_banned: 1 });
          message.success('卖家已封禁');
        } else if (action === 'suspend_seller' && targetInfo.seller_id) {
          const suspendUntil = new Date();
          suspendUntil.setDate(suspendUntil.getDate() + 7);
          await updateUserByAdmin(targetInfo.seller_id, {
            is_suspended: 1,
            suspend_until: suspendUntil.toISOString()
          });
          message.success('卖家已暂停7天');
        }
      }
      
      // 操作后自动处理举报
      await handleProcessReport();
    } catch (error: any) {
            message.error(error?.response?.data?.detail || '操作失败');
    }
  };

  const handleProcessReport = async () => {
    if (!currentReport) return;
    
    try {
      if (currentReport.type === 'forum') {
        await processForumReport(currentReport.id, {
          status: reportProcessForm.status as 'processed' | 'rejected',
          action: reportProcessForm.action
        });
        message.success('举报处理成功');
        await loadForumReports();
      } else if (currentReport.type === 'flea_market') {
        await processFleaMarketReport(currentReport.id, {
          status: reportProcessForm.status as 'resolved' | 'rejected',
          admin_comment: reportProcessForm.admin_comment
        });
        message.success('举报处理成功');
        await loadFleaMarketReports();
      }
      setShowReportProcessModal(false);
      setCurrentReport(null);
      setTargetInfo(null);
      setReportProcessForm({
        status: 'processed',
        action: '',
        admin_comment: ''
      });
    } catch (error: any) {
            message.error(error?.response?.data?.detail || '处理举报失败');
    }
  };

  const [reportSubTab, setReportSubTab] = useState<'forum' | 'flea_market'>('forum');

  // 加载商品列表 - 使用useCallback优化
  const loadFleaMarketItems = useCallback(async () => {
    setFleaMarketItemsLoading(true);
    try {
      const params: any = {
        page: fleaMarketItemsPage,
        page_size: 20
      };
      if (fleaMarketItemsFilter.category) {
        params.category = fleaMarketItemsFilter.category;
      }
      if (fleaMarketItemsFilter.keyword) {
        params.keyword = fleaMarketItemsFilter.keyword;
      }
      if (fleaMarketItemsFilter.status) {
        params.status_filter = fleaMarketItemsFilter.status;
      }
      if (fleaMarketItemsFilter.seller_id) {
        params.seller_id = fleaMarketItemsFilter.seller_id;
      }
      const response = await getFleaMarketItemsAdmin(params);
      setFleaMarketItems(response.items || []);
      setFleaMarketItemsTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setFleaMarketItemsLoading(false);
    }
  }, [fleaMarketItemsPage, fleaMarketItemsFilter]);

  // 处理商品编辑
  const handleEditFleaMarketItem = (item: any) => {
    setFleaMarketItemForm({
      id: item.id,
      title: item.title,
      description: item.description,
      price: item.price,
      images: item.images || [],
      location: item.location,
      category: item.category,
      status: item.status
    });
    setShowFleaMarketItemModal(true);
  };

  // 处理商品保存
  const handleSaveFleaMarketItem = async () => {
    try {
      if (!fleaMarketItemForm.id) {
        message.error('商品ID不存在');
        return;
      }
      await updateFleaMarketItemAdmin(fleaMarketItemForm.id, {
        title: fleaMarketItemForm.title,
        description: fleaMarketItemForm.description,
        price: fleaMarketItemForm.price,
        images: fleaMarketItemForm.images,
        location: fleaMarketItemForm.location,
        category: fleaMarketItemForm.category,
        status: fleaMarketItemForm.status
      });
      message.success('商品更新成功！');
      setShowFleaMarketItemModal(false);
      setFleaMarketItemForm({});
      loadFleaMarketItems();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  // 处理商品删除
  const handleDeleteFleaMarketItem = (itemId: string) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个商品吗？',
      onOk: async () => {
        try {
          await deleteFleaMarketItemAdmin(itemId);
          message.success('商品删除成功！');
          loadFleaMarketItems();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  // 加载投票记录
  const loadLeaderboardVotes = useCallback(async () => {
    setLeaderboardVotesLoading(true);
    try {
      const offset = (leaderboardVotesPage - 1) * 50;
      const data = await getLeaderboardVotesAdmin({
        ...leaderboardVotesFilter,
        limit: 50,
        offset
      });
      setLeaderboardVotes(Array.isArray(data) ? data : []);
      // 注意：API返回的是数组，没有total字段，这里需要根据实际情况调整
      setLeaderboardVotesTotal(Array.isArray(data) ? data.length : 0);
    } catch (error: any) {
            message.error(getErrorMessage(error));
    } finally {
      setLeaderboardVotesLoading(false);
    }
  }, [leaderboardVotesPage, leaderboardVotesFilter]);

  // 当切换到投票记录管理标签页时，自动加载数据
  useEffect(() => {
    if (activeTab === 'leaderboard-votes') {
      const timer = setTimeout(() => {
        loadLeaderboardVotes();
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [activeTab, leaderboardVotesPage, leaderboardVotesFilter, loadLeaderboardVotes]);

  // 加载待审核榜单列表
  const loadPendingLeaderboards = useCallback(async () => {
    setLeaderboardsLoading(true);
    try {
      const offset = (leaderboardsPage - 1) * 20;
      const data = await getCustomLeaderboardsAdmin({
        status: 'pending',
        limit: 20,
        offset
      });
      setPendingLeaderboards(Array.isArray(data) ? data : []);
    } catch (error: any) {
            message.error(getErrorMessage(error));
    } finally {
      setLeaderboardsLoading(false);
    }
  }, [leaderboardsPage]);

  // 当切换到榜单审核标签页时，自动加载数据
  useEffect(() => {
    if (activeTab === 'leaderboard-review') {
      const timer = setTimeout(() => {
        loadPendingLeaderboards();
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [activeTab, leaderboardsPage, loadPendingLeaderboards]);

  // 加载竞品列表
  const loadLeaderboardItems = useCallback(async () => {
    setLeaderboardItemsLoading(true);
    try {
      const offset = (leaderboardItemsPage - 1) * 50;
      // 构建请求参数，确保 undefined 值不会被包含
      const params: any = {
        limit: 50,
        offset
      };
      if (leaderboardItemsFilter.leaderboard_id !== undefined && leaderboardItemsFilter.leaderboard_id !== null && !isNaN(leaderboardItemsFilter.leaderboard_id)) {
        params.leaderboard_id = leaderboardItemsFilter.leaderboard_id;
      }
      if (leaderboardItemsFilter.status && leaderboardItemsFilter.status !== 'all') {
        params.status = leaderboardItemsFilter.status;
      }
      if (leaderboardItemsFilter.keyword) {
        params.keyword = leaderboardItemsFilter.keyword;
      }
      const data = await getLeaderboardItemsAdmin(params);
      setLeaderboardItems(data.items || []);
      setLeaderboardItemsTotal(data.total || 0);
    } catch (error: any) {
            message.error(error?.response?.data?.detail || '加载竞品列表失败');
    } finally {
      setLeaderboardItemsLoading(false);
    }
  }, [leaderboardItemsPage, leaderboardItemsFilter]);

  // 当切换到竞品管理标签页时，自动加载数据
  useEffect(() => {
    if (activeTab === 'leaderboard-items') {
      const timer = setTimeout(() => {
        loadLeaderboardItems();
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [activeTab, leaderboardItemsPage, leaderboardItemsFilter, loadLeaderboardItems]);

  // ==================== Banner 管理函数 ====================
  
  // 加载 Banner 列表
  const loadBanners = useCallback(async () => {
    setBannersLoading(true);
    try {
      const data = await getBannersAdmin({
        page: bannersPage,
        limit: 20,
        is_active: bannersActiveFilter
      });
      setBanners(data.data || []);
      setBannersTotal(data.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setBannersLoading(false);
    }
  }, [bannersPage, bannersActiveFilter]);

  // 当切换到 Banner 管理标签页时，自动加载数据
  useEffect(() => {
    if (activeTab === 'banners') {
      const timer = setTimeout(() => {
        loadBanners();
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [activeTab, bannersPage, bannersActiveFilter, loadBanners]);

  // 创建 Banner
  const handleCreateBanner = useCallback(async () => {
    if (!bannerForm.image_url || !bannerForm.title) {
      message.warning('请填写图片URL和标题');
      return;
    }
    try {
      await createBanner({
        image_url: bannerForm.image_url,
        title: bannerForm.title,
        subtitle: bannerForm.subtitle || undefined,
        link_url: bannerForm.link_url || undefined,
        link_type: bannerForm.link_type,
        order: bannerForm.order || 0,
        is_active: bannerForm.is_active
      });
      message.success('Banner 创建成功！');
      setShowBannerModal(false);
      setBannerForm({
        id: undefined,
        image_url: '',
        title: '',
        subtitle: '',
        link_url: '',
        link_type: 'internal',
        order: 0,
        is_active: true
      });
      loadBanners();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, [bannerForm, loadBanners]);

  // 更新 Banner
  const handleUpdateBanner = useCallback(async () => {
    if (!bannerForm.id) return;
    if (!bannerForm.image_url || !bannerForm.title) {
      message.warning('请填写图片URL和标题');
      return;
    }
    try {
      await updateBanner(bannerForm.id, {
        image_url: bannerForm.image_url,
        title: bannerForm.title,
        subtitle: bannerForm.subtitle || undefined,
        link_url: bannerForm.link_url || undefined,
        link_type: bannerForm.link_type,
        order: bannerForm.order,
        is_active: bannerForm.is_active
      });
      message.success('Banner 更新成功！');
      setShowBannerModal(false);
      setBannerForm({
        id: undefined,
        image_url: '',
        title: '',
        subtitle: '',
        link_url: '',
        link_type: 'internal',
        order: 0,
        is_active: true
      });
      loadBanners();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, [bannerForm, loadBanners]);

  // 删除 Banner
  const handleDeleteBanner = useCallback(async (bannerId: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个 Banner 吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteBanner(bannerId);
          message.success('Banner 删除成功！');
          loadBanners();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  }, [loadBanners]);

  // 切换 Banner 状态
  const handleToggleBannerStatus = useCallback(async (bannerId: number) => {
    try {
      await toggleBannerStatus(bannerId);
      message.success('Banner 状态已更新！');
      loadBanners();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, [loadBanners]);

  // 编辑 Banner
  const handleEditBanner = useCallback((banner: any) => {
    setBannerForm({
      id: banner.id,
      image_url: banner.image_url,
      title: banner.title,
      subtitle: banner.subtitle || '',
      link_url: banner.link_url || '',
      link_type: banner.link_type || 'internal',
      order: banner.order || 0,
      is_active: banner.is_active !== undefined ? banner.is_active : true
    });
    setShowBannerModal(true);
  }, []);

  // 上传图片
  const handleUploadImage = useCallback(async (file: File) => {
    setUploadingImage(true);
    try {
      // 压缩图片
      const compressedFile = await compressImage(file, {
        maxSizeMB: 1,
        maxWidthOrHeight: 1920,
        useWebWorker: true
      });
      
      // 上传压缩后的图片
      const result = await uploadBannerImage(compressedFile, bannerForm.id);
      setBannerForm(prev => ({...prev, image_url: result.url}));
      message.success('图片上传成功！');
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setUploadingImage(false);
    }
  }, [bannerForm.id]);

  // 删除竞品
  const handleDeleteLeaderboardItem = async (itemId: number, itemName: string) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除竞品"${itemName}"吗？此操作将级联删除该竞品的所有投票记录和图片文件，且无法恢复。`,
      okText: '确认删除',
      okType: 'danger',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteLeaderboardItemAdmin(itemId);
          message.success('竞品已删除');
          await loadLeaderboardItems();
        } catch (error: any) {
                    message.error(error?.response?.data?.detail || '删除竞品失败');
        }
      }
    });
  };

  // 打开审核弹窗
  const handleOpenReviewModal = (leaderboard: any, action: 'approve' | 'reject') => {
    setSelectedLeaderboardForReview(leaderboard);
    setLeaderboardReviewComment('');
    setReviewingLeaderboard(null); // 打开弹窗时重置，只有在提交时才设置
    setShowLeaderboardReviewModal(true);
  };

  // 提交审核
  const handleSubmitReview = async (action: 'approve' | 'reject') => {
    if (!selectedLeaderboardForReview) return;
    
    setReviewingLeaderboard(selectedLeaderboardForReview.id);
    try {
      await reviewCustomLeaderboard(
        selectedLeaderboardForReview.id,
        action,
        leaderboardReviewComment || undefined
      );
      message.success(`榜单已${action === 'approve' ? '批准' : '拒绝'}`);
      setShowLeaderboardReviewModal(false);
      setSelectedLeaderboardForReview(null);
      setLeaderboardReviewComment('');
      // 重新加载列表
      await loadPendingLeaderboards();
    } catch (error: any) {
            message.error(getErrorMessage(error));
    } finally {
      setReviewingLeaderboard(null);
    }
  };

  // 当切换到举报管理标签页时，自动加载数据
  useEffect(() => {
    if (activeTab === 'reports') {
      const timer = setTimeout(() => {
        if (reportSubTab === 'forum') {
          loadForumReports();
        } else {
          loadFleaMarketReports();
        }
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [activeTab, reportSubTab, forumReportsPage, forumReportsStatusFilter, fleaMarketReportsPage, fleaMarketReportsStatusFilter, loadForumReports, loadFleaMarketReports]);

  const renderReports = () => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>举报管理</h2>
      </div>

      {/* 子标签页 */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        <button
          onClick={() => {
            setReportSubTab('forum');
            setForumReportsPage(1);
          }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: reportSubTab === 'forum' ? '#007bff' : '#f0f0f0',
            color: reportSubTab === 'forum' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          论坛举报
        </button>
        <button
          onClick={() => {
            setReportSubTab('flea_market');
            setFleaMarketReportsPage(1);
          }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: reportSubTab === 'flea_market' ? '#007bff' : '#f0f0f0',
            color: reportSubTab === 'flea_market' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          商品举报
        </button>
      </div>

      {/* 论坛举报 */}
      {reportSubTab === 'forum' && (
        <div>
          {/* 筛选 */}
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            marginBottom: '20px'
          }}>
            <select
              value={forumReportsStatusFilter || ''}
              onChange={(e) => {
                setForumReportsStatusFilter(e.target.value ? e.target.value as any : undefined);
                setForumReportsPage(1);
              }}
              style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
            >
              <option value="">全部状态</option>
              <option value="pending">待处理</option>
              <option value="processed">已处理</option>
              <option value="rejected">已拒绝</option>
            </select>
            <button
              onClick={loadForumReports}
              style={{
                marginLeft: '10px',
                padding: '8px 16px',
                border: 'none',
                background: '#007bff',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              刷新
            </button>
          </div>

          {/* 举报列表 */}
          <div style={{
            background: 'white',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            overflow: 'hidden'
          }}>
            {forumReportsLoading ? (
              <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
            ) : forumReports.length === 0 ? (
              <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无举报</div>
            ) : (
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ background: '#f8f9fa' }}>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>类型</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>目标ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>举报原因</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {forumReports.map((report: any) => (
                    <tr key={report.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                      <td style={{ padding: '12px' }}>{report.id}</td>
                      <td style={{ padding: '12px' }}>{report.target_type === 'post' ? '帖子' : '回复'}</td>
                      <td style={{ padding: '12px' }}>{report.target_id}</td>
                      <td style={{ padding: '12px' }}>{report.reason}</td>
                      <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {report.description || '-'}
                      </td>
                      <td style={{ padding: '12px' }}>
                        <span style={{
                          padding: '4px 8px',
                          borderRadius: '4px',
                          background: report.status === 'pending' ? '#fff3cd' : report.status === 'processed' ? '#d4edda' : '#f8d7da',
                          color: report.status === 'pending' ? '#856404' : report.status === 'processed' ? '#155724' : '#721c24',
                          fontSize: '12px',
                          fontWeight: '500'
                        }}>
                          {report.status === 'pending' ? '待处理' : report.status === 'processed' ? '已处理' : '已拒绝'}
                        </span>
                      </td>
                      <td style={{ padding: '12px' }}>
                        {report.status === 'pending' && (
                          <button
                            onClick={async () => {
                              const reportData = { ...report, type: 'forum' };
                              setCurrentReport(reportData);
                              setReportProcessForm({
                                status: 'processed',
                                action: '',
                                admin_comment: ''
                              });
                              setShowReportProcessModal(true);
                              await loadTargetInfo(reportData);
                            }}
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
                            处理
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {/* 分页 */}
          {forumReportsTotal > 20 && (
            <div style={{ display: 'flex', justifyContent: 'center', marginTop: '20px', gap: '10px' }}>
              <button
                onClick={() => {
                  if (forumReportsPage > 1) {
                    setForumReportsPage(forumReportsPage - 1);
                  }
                }}
                disabled={forumReportsPage === 1}
                style={{
                  padding: '8px 16px',
                  border: '1px solid #ddd',
                  background: forumReportsPage === 1 ? '#f5f5f5' : 'white',
                  color: forumReportsPage === 1 ? '#999' : '#333',
                  borderRadius: '4px',
                  cursor: forumReportsPage === 1 ? 'not-allowed' : 'pointer'
                }}
              >
                上一页
              </button>
              <span style={{ padding: '8px 16px', display: 'flex', alignItems: 'center' }}>
                第 {forumReportsPage} 页，共 {Math.ceil(forumReportsTotal / 20)} 页
              </span>
              <button
                onClick={() => {
                  if (forumReportsPage < Math.ceil(forumReportsTotal / 20)) {
                    setForumReportsPage(forumReportsPage + 1);
                  }
                }}
                disabled={forumReportsPage >= Math.ceil(forumReportsTotal / 20)}
                style={{
                  padding: '8px 16px',
                  border: '1px solid #ddd',
                  background: forumReportsPage >= Math.ceil(forumReportsTotal / 20) ? '#f5f5f5' : 'white',
                  color: forumReportsPage >= Math.ceil(forumReportsTotal / 20) ? '#999' : '#333',
                  borderRadius: '4px',
                  cursor: forumReportsPage >= Math.ceil(forumReportsTotal / 20) ? 'not-allowed' : 'pointer'
                }}
              >
                下一页
              </button>
            </div>
          )}
        </div>
      )}

      {/* 跳蚤市场举报 */}
      {reportSubTab === 'flea_market' && (
        <div>
          {/* 筛选 */}
          <div style={{
            background: 'white',
            padding: '20px',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            marginBottom: '20px'
          }}>
            <select
              value={fleaMarketReportsStatusFilter || ''}
              onChange={(e) => {
                setFleaMarketReportsStatusFilter(e.target.value ? e.target.value as any : undefined);
                setFleaMarketReportsPage(1);
              }}
              style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
            >
              <option value="">全部状态</option>
              <option value="pending">待处理</option>
              <option value="reviewing">审核中</option>
              <option value="resolved">已解决</option>
              <option value="rejected">已拒绝</option>
            </select>
            <button
              onClick={loadFleaMarketReports}
              style={{
                marginLeft: '10px',
                padding: '8px 16px',
                border: 'none',
                background: '#007bff',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              刷新
            </button>
          </div>

          {/* 举报列表 */}
          <div style={{
            background: 'white',
            borderRadius: '8px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            overflow: 'hidden'
          }}>
            {fleaMarketReportsLoading ? (
              <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
            ) : fleaMarketReports.length === 0 ? (
              <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无举报</div>
            ) : (
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ background: '#f8f9fa' }}>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>商品ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>商品标题</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>举报人</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>举报原因</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {fleaMarketReports.map((report: any) => (
                    <tr key={report.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                      <td style={{ padding: '12px' }}>{report.id}</td>
                      <td style={{ padding: '12px' }}>{report.item_id}</td>
                      <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {report.item_title || '-'}
                      </td>
                      <td style={{ padding: '12px' }}>{report.reporter_name || '-'}</td>
                      <td style={{ padding: '12px' }}>
                        {report.reason === 'spam' ? '垃圾信息' :
                         report.reason === 'fraud' ? '欺诈' :
                         report.reason === 'inappropriate' ? '不当内容' : '其他'}
                      </td>
                      <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {report.description || '-'}
                      </td>
                      <td style={{ padding: '12px' }}>
                        <span style={{
                          padding: '4px 8px',
                          borderRadius: '4px',
                          background: report.status === 'pending' ? '#fff3cd' : report.status === 'resolved' ? '#d4edda' : report.status === 'rejected' ? '#f8d7da' : '#d1ecf1',
                          color: report.status === 'pending' ? '#856404' : report.status === 'resolved' ? '#155724' : report.status === 'rejected' ? '#721c24' : '#0c5460',
                          fontSize: '12px',
                          fontWeight: '500'
                        }}>
                          {report.status === 'pending' ? '待处理' : report.status === 'reviewing' ? '审核中' : report.status === 'resolved' ? '已解决' : '已拒绝'}
                        </span>
                      </td>
                      <td style={{ padding: '12px' }}>
                        {(report.status === 'pending' || report.status === 'reviewing') && (
                          <button
                            onClick={async () => {
                              const reportData = { ...report, type: 'flea_market' };
                              setCurrentReport(reportData);
                              setReportProcessForm({
                                status: 'resolved',
                                action: '',
                                admin_comment: ''
                              });
                              setShowReportProcessModal(true);
                              await loadTargetInfo(reportData);
                            }}
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
                            处理
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          {/* 分页 */}
          {fleaMarketReportsTotal > 20 && (
            <div style={{ display: 'flex', justifyContent: 'center', marginTop: '20px', gap: '10px' }}>
              <button
                onClick={() => {
                  if (fleaMarketReportsPage > 1) {
                    setFleaMarketReportsPage(fleaMarketReportsPage - 1);
                  }
                }}
                disabled={fleaMarketReportsPage === 1}
                style={{
                  padding: '8px 16px',
                  border: '1px solid #ddd',
                  background: fleaMarketReportsPage === 1 ? '#f5f5f5' : 'white',
                  color: fleaMarketReportsPage === 1 ? '#999' : '#333',
                  borderRadius: '4px',
                  cursor: fleaMarketReportsPage === 1 ? 'not-allowed' : 'pointer'
                }}
              >
                上一页
              </button>
              <span style={{ padding: '8px 16px', display: 'flex', alignItems: 'center' }}>
                第 {fleaMarketReportsPage} 页，共 {Math.ceil(fleaMarketReportsTotal / 20)} 页
              </span>
              <button
                onClick={() => {
                  if (fleaMarketReportsPage < Math.ceil(fleaMarketReportsTotal / 20)) {
                    setFleaMarketReportsPage(fleaMarketReportsPage + 1);
                  }
                }}
                disabled={fleaMarketReportsPage >= Math.ceil(fleaMarketReportsTotal / 20)}
                style={{
                  padding: '8px 16px',
                  border: '1px solid #ddd',
                  background: fleaMarketReportsPage >= Math.ceil(fleaMarketReportsTotal / 20) ? '#f5f5f5' : 'white',
                  color: fleaMarketReportsPage >= Math.ceil(fleaMarketReportsTotal / 20) ? '#999' : '#333',
                  borderRadius: '4px',
                  cursor: fleaMarketReportsPage >= Math.ceil(fleaMarketReportsTotal / 20) ? 'not-allowed' : 'pointer'
                }}
              >
                下一页
              </button>
            </div>
          )}
        </div>
      )}

      {/* 处理举报模态框 */}
      {showReportProcessModal && currentReport && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div style={{
            background: 'white',
            borderRadius: '8px',
            padding: '24px',
            width: '90%',
            maxWidth: '600px',
            maxHeight: '90vh',
            overflow: 'auto'
          }}>
            <h3 style={{ marginBottom: '20px' }}>处理举报</h3>
            
            {/* 目标信息显示 */}
            {loadingTargetInfo ? (
              <div style={{ padding: '20px', textAlign: 'center' }}>加载中...</div>
            ) : targetInfo && (
              <div style={{
                background: '#f8f9fa',
                padding: '16px',
                borderRadius: '8px',
                marginBottom: '20px'
              }}>
                <h4 style={{ marginBottom: '12px', fontSize: '16px', fontWeight: '600' }}>目标信息</h4>
                {currentReport.type === 'forum' && (
                  <div>
                    <p><strong>类型：</strong>{targetInfo.type === 'post' ? '帖子' : '回复'}</p>
                    {targetInfo.title && <p><strong>标题：</strong>{targetInfo.title}</p>}
                    {targetInfo.author_name && (
                      <p><strong>作者：</strong>{targetInfo.author_name} (ID: {targetInfo.author_id})</p>
                    )}
                  </div>
                )}
                {currentReport.type === 'flea_market' && (
                  <div>
                    <p><strong>商品：</strong>{targetInfo.title}</p>
                    {targetInfo.seller_name && (
                      <p><strong>卖家：</strong>{targetInfo.seller_name} (ID: {targetInfo.seller_id})</p>
                    )}
                    <p><strong>状态：</strong>{targetInfo.status}</p>
                  </div>
                )}
              </div>
            )}

            {/* 快捷操作按钮 */}
            {targetInfo && !loadingTargetInfo && (
              <div style={{ marginBottom: '20px' }}>
                <h4 style={{ marginBottom: '12px', fontSize: '16px', fontWeight: '600' }}>快捷操作</h4>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {currentReport.type === 'forum' && targetInfo.type === 'post' && (
                    <>
                      {!targetInfo.is_deleted && (
                        <button
                          onClick={() => handleQuickAction('delete_post')}
                          style={{
                            padding: '8px 16px',
                            border: '1px solid #dc3545',
                            background: 'white',
                            color: '#dc3545',
                            borderRadius: '4px',
                            cursor: 'pointer',
                            fontSize: '14px'
                          }}
                        >
                          删除帖子
                        </button>
                      )}
                      {targetInfo.is_visible && (
                        <button
                          onClick={() => handleQuickAction('hide_post')}
                          style={{
                            padding: '8px 16px',
                            border: '1px solid #ffc107',
                            background: 'white',
                            color: '#ffc107',
                            borderRadius: '4px',
                            cursor: 'pointer',
                            fontSize: '14px'
                          }}
                        >
                          隐藏帖子
                        </button>
                      )}
                      {!targetInfo.is_locked && (
                        <button
                          onClick={() => handleQuickAction('lock_post')}
                          style={{
                            padding: '8px 16px',
                            border: '1px solid #6c757d',
                            background: 'white',
                            color: '#6c757d',
                            borderRadius: '4px',
                            cursor: 'pointer',
                            fontSize: '14px'
                          }}
                        >
                          锁定帖子
                        </button>
                      )}
                    </>
                  )}
                  {targetInfo.author_id && (
                    <>
                      <button
                        onClick={() => handleQuickAction('ban_user')}
                        style={{
                          padding: '8px 16px',
                          border: '1px solid #dc3545',
                          background: 'white',
                          color: '#dc3545',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '14px'
                        }}
                      >
                        封禁用户
                      </button>
                      <button
                        onClick={() => handleQuickAction('suspend_user')}
                        style={{
                          padding: '8px 16px',
                          border: '1px solid #ffc107',
                          background: 'white',
                          color: '#ffc107',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '14px'
                        }}
                      >
                        暂停用户7天
                      </button>
                    </>
                  )}
                  {currentReport.type === 'flea_market' && (
                    <>
                      {targetInfo.status !== 'deleted' && (
                        <button
                          onClick={() => handleQuickAction('take_down_item')}
                          style={{
                            padding: '8px 16px',
                            border: '1px solid #dc3545',
                            background: 'white',
                            color: '#dc3545',
                            borderRadius: '4px',
                            cursor: 'pointer',
                            fontSize: '14px'
                          }}
                        >
                          下架商品
                        </button>
                      )}
                      {targetInfo.seller_id && (
                        <>
                          <button
                            onClick={() => handleQuickAction('ban_seller')}
                            style={{
                              padding: '8px 16px',
                              border: '1px solid #dc3545',
                              background: 'white',
                              color: '#dc3545',
                              borderRadius: '4px',
                              cursor: 'pointer',
                              fontSize: '14px'
                            }}
                          >
                            封禁卖家
                          </button>
                          <button
                            onClick={() => handleQuickAction('suspend_seller')}
                            style={{
                              padding: '8px 16px',
                              border: '1px solid #ffc107',
                              background: 'white',
                              color: '#ffc107',
                              borderRadius: '4px',
                              cursor: 'pointer',
                              fontSize: '14px'
                            }}
                          >
                            暂停卖家7天
                          </button>
                        </>
                      )}
                    </>
                  )}
                </div>
              </div>
            )}

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>处理结果</label>
              <select
                value={reportProcessForm.status}
                onChange={(e) => setReportProcessForm({...reportProcessForm, status: e.target.value as any})}
                style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
              >
                {currentReport.type === 'forum' ? (
                  <>
                    <option value="processed">已处理</option>
                    <option value="rejected">已拒绝</option>
                  </>
                ) : (
                  <>
                    <option value="resolved">已解决</option>
                    <option value="rejected">已拒绝</option>
                  </>
                )}
              </select>
            </div>
            {currentReport.type === 'forum' && (
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>处理操作（可选）</label>
                <input
                  type="text"
                  value={reportProcessForm.action}
                  onChange={(e) => setReportProcessForm({...reportProcessForm, action: e.target.value})}
                  style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
                  placeholder="例如：删除帖子、隐藏内容等"
                />
              </div>
            )}
            {currentReport.type === 'flea_market' && (
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>管理员备注（可选）</label>
                <textarea
                  value={reportProcessForm.admin_comment}
                  onChange={(e) => setReportProcessForm({...reportProcessForm, admin_comment: e.target.value})}
                  style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #ddd', minHeight: '100px', fontFamily: 'inherit' }}
                  placeholder="请输入处理备注"
                />
              </div>
            )}
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowReportProcessModal(false);
                  setCurrentReport(null);
                  setTargetInfo(null);
                  setReportProcessForm({
                    status: 'processed',
                    action: '',
                    admin_comment: ''
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
                onClick={handleProcessReport}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: '#007bff',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                确认处理
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );

  // 渲染商品列表
  const renderFleaMarketItems = () => {
    const statusColors: { [key: string]: string } = {
      active: '#52c41a',
      sold: '#1890ff',
      deleted: '#ff4d4f',
      pending: '#faad14'
    };

    return (
      <div style={{ marginTop: '20px' }}>
        <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
          <input
            type="text"
            placeholder="搜索关键词（标题/描述）"
            value={fleaMarketItemsFilter.keyword || ''}
            onChange={(e) => setFleaMarketItemsFilter({ ...fleaMarketItemsFilter, keyword: e.target.value })}
            style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px', width: '200px' }}
            onKeyPress={(e) => {
              if (e.key === 'Enter') {
                setFleaMarketItemsPage(1);
                loadFleaMarketItems();
              }
            }}
          />
          <select
            value={fleaMarketItemsFilter.status || ''}
            onChange={(e) => setFleaMarketItemsFilter({ ...fleaMarketItemsFilter, status: e.target.value || undefined })}
            style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
          >
            <option value="">全部状态</option>
            <option value="active">在售</option>
            <option value="sold">已售出</option>
            <option value="deleted">已删除</option>
            <option value="pending">待审核</option>
          </select>
          <select
            value={fleaMarketItemsFilter.category || ''}
            onChange={(e) => setFleaMarketItemsFilter({ ...fleaMarketItemsFilter, category: e.target.value || undefined })}
            style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
          >
            <option value="">全部分类</option>
            <option value="Electronics">电子产品</option>
            <option value="Furniture">家具</option>
            <option value="Clothing">服装</option>
            <option value="Books">书籍</option>
            <option value="Sports">运动用品</option>
            <option value="Other">其他</option>
          </select>
          <button
            onClick={() => {
              setFleaMarketItemsPage(1);
              loadFleaMarketItems();
            }}
            style={{ padding: '8px 16px', background: '#007bff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
          >
            搜索
          </button>
        </div>

        {fleaMarketItemsLoading ? (
          <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
        ) : (
          <>
            <div style={{ background: 'white', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ background: '#f8f9fa' }}>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>商品ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>标题</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>价格</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>分类</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>卖家</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>创建时间</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
                  </tr>
                </thead>
                <tbody>
                  {fleaMarketItems.length === 0 ? (
                    <tr>
                      <td colSpan={8} style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
                        暂无商品
                      </td>
                    </tr>
                  ) : (
                    fleaMarketItems.map((item) => (
                      <tr key={item.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                        <td style={{ padding: '12px' }}>{item.id}</td>
                        <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {item.title}
                        </td>
                        <td style={{ padding: '12px' }}>£{item.price}</td>
                        <td style={{ padding: '12px' }}>{item.category}</td>
                        <td style={{ padding: '12px' }}>{item.seller_name}</td>
                        <td style={{ padding: '12px' }}>
                          <span style={{
                            padding: '4px 8px',
                            borderRadius: '4px',
                            background: statusColors[item.status] || '#999',
                            color: 'white',
                            fontSize: '12px'
                          }}>
                            {item.status === 'active' ? '在售' : item.status === 'sold' ? '已售出' : item.status === 'deleted' ? '已删除' : item.status === 'pending' ? '待审核' : item.status}
                          </span>
                        </td>
                        <td style={{ padding: '12px', fontSize: '12px', color: '#666' }}>
                          {dayjs(item.created_at).format('YYYY-MM-DD HH:mm')}
                        </td>
                        <td style={{ padding: '12px' }}>
                          <button
                            onClick={() => handleEditFleaMarketItem(item)}
                            style={{ marginRight: '8px', padding: '4px 8px', background: '#007bff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                          >
                            编辑
                          </button>
                          {item.status !== 'deleted' && (
                            <button
                              onClick={() => handleDeleteFleaMarketItem(item.id)}
                              style={{ padding: '4px 8px', background: '#ff4d4f', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                            >
                              删除
                            </button>
                          )}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
            <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ color: '#666' }}>
                共 {fleaMarketItemsTotal} 条记录
              </span>
              <div style={{ display: 'flex', gap: '10px' }}>
                <button
                  onClick={() => {
                    if (fleaMarketItemsPage > 1) {
                      setFleaMarketItemsPage(fleaMarketItemsPage - 1);
                    }
                  }}
                  disabled={fleaMarketItemsPage === 1}
                  style={{ padding: '8px 16px', border: '1px solid #ddd', borderRadius: '4px', cursor: fleaMarketItemsPage === 1 ? 'not-allowed' : 'pointer', opacity: fleaMarketItemsPage === 1 ? 0.5 : 1 }}
                >
                  上一页
                </button>
                <span style={{ padding: '8px', color: '#666' }}>
                  第 {fleaMarketItemsPage} 页，共 {Math.ceil(fleaMarketItemsTotal / 20)} 页
                </span>
                <button
                  onClick={() => {
                    if (fleaMarketItemsPage < Math.ceil(fleaMarketItemsTotal / 20)) {
                      setFleaMarketItemsPage(fleaMarketItemsPage + 1);
                    }
                  }}
                  disabled={fleaMarketItemsPage >= Math.ceil(fleaMarketItemsTotal / 20)}
                  style={{ padding: '8px 16px', border: '1px solid #ddd', borderRadius: '4px', cursor: fleaMarketItemsPage >= Math.ceil(fleaMarketItemsTotal / 20) ? 'not-allowed' : 'pointer', opacity: fleaMarketItemsPage >= Math.ceil(fleaMarketItemsTotal / 20) ? 0.5 : 1 }}
                >
                  下一页
                </button>
              </div>
            </div>
          </>
        )}

        {/* 商品编辑模态框 */}
        {showFleaMarketItemModal && (
          <Modal
            title="编辑商品"
            open={showFleaMarketItemModal}
            onOk={handleSaveFleaMarketItem}
            onCancel={() => {
              setShowFleaMarketItemModal(false);
              setFleaMarketItemForm({});
            }}
            width={800}
          >
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>标题：</label>
                <input
                  type="text"
                  value={fleaMarketItemForm.title || ''}
                  onChange={(e) => setFleaMarketItemForm({ ...fleaMarketItemForm, title: e.target.value })}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>描述：</label>
                <textarea
                  value={fleaMarketItemForm.description || ''}
                  onChange={(e) => setFleaMarketItemForm({ ...fleaMarketItemForm, description: e.target.value })}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', minHeight: '100px' }}
                />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>价格：</label>
                <input
                  type="number"
                  value={fleaMarketItemForm.price || ''}
                  onChange={(e) => setFleaMarketItemForm({ ...fleaMarketItemForm, price: parseFloat(e.target.value) })}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>分类：</label>
                <select
                  value={fleaMarketItemForm.category || ''}
                  onChange={(e) => setFleaMarketItemForm({ ...fleaMarketItemForm, category: e.target.value })}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                >
                  <option value="Electronics">电子产品</option>
                  <option value="Furniture">家具</option>
                  <option value="Clothing">服装</option>
                  <option value="Books">书籍</option>
                  <option value="Sports">运动用品</option>
                  <option value="Other">其他</option>
                </select>
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>位置：</label>
                <input
                  type="text"
                  value={fleaMarketItemForm.location || ''}
                  onChange={(e) => setFleaMarketItemForm({ ...fleaMarketItemForm, location: e.target.value })}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>状态：</label>
                <select
                  value={fleaMarketItemForm.status || 'active'}
                  onChange={(e) => setFleaMarketItemForm({ ...fleaMarketItemForm, status: e.target.value })}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                >
                  <option value="active">在售</option>
                  <option value="sold">已售出</option>
                  <option value="deleted">已删除</option>
                  <option value="pending">待审核</option>
                </select>
              </div>
            </div>
          </Modal>
        )}
      </div>
    );
  };

  // 渲染投票记录管理
  const renderLeaderboardVotes = () => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>投票记录管理</h2>
      </div>

      {/* 筛选 */}
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginBottom: '20px',
        display: 'flex',
        flexWrap: 'wrap',
        gap: '10px',
        alignItems: 'center'
      }}>
        <input
          type="number"
          placeholder="竞品ID"
          value={leaderboardVotesFilter.item_id || ''}
          onChange={(e) => setLeaderboardVotesFilter({
            ...leaderboardVotesFilter,
            item_id: e.target.value ? parseInt(e.target.value) : undefined
          })}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', width: '120px' }}
        />
        <input
          type="number"
          placeholder="榜单ID"
          value={leaderboardVotesFilter.leaderboard_id || ''}
          onChange={(e) => setLeaderboardVotesFilter({
            ...leaderboardVotesFilter,
            leaderboard_id: e.target.value ? parseInt(e.target.value) : undefined
          })}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', width: '120px' }}
        />
        <select
          value={leaderboardVotesFilter.is_anonymous === undefined ? '' : leaderboardVotesFilter.is_anonymous ? 'true' : 'false'}
          onChange={(e) => setLeaderboardVotesFilter({
            ...leaderboardVotesFilter,
            is_anonymous: e.target.value === '' ? undefined : e.target.value === 'true'
          })}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
        >
          <option value="">全部</option>
          <option value="true">匿名</option>
          <option value="false">非匿名</option>
        </select>
        <input
          type="text"
          placeholder="搜索用户名/留言内容"
          value={leaderboardVotesFilter.keyword || ''}
          onChange={(e) => setLeaderboardVotesFilter({
            ...leaderboardVotesFilter,
            keyword: e.target.value || undefined
          })}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', flex: 1, minWidth: '200px' }}
        />
        <button
          onClick={() => {
            setLeaderboardVotesPage(1);
            loadLeaderboardVotes();
          }}
          style={{
            padding: '8px 16px',
            border: 'none',
            background: '#007bff',
            color: 'white',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          搜索
        </button>
        <button
          onClick={() => {
            setLeaderboardVotesFilter({});
            setLeaderboardVotesPage(1);
            loadLeaderboardVotes();
          }}
          style={{
            padding: '8px 16px',
            border: 'none',
            background: '#6c757d',
            color: 'white',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          重置
        </button>
      </div>

      {/* 投票记录列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'auto'
      }}>
        {leaderboardVotesLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : leaderboardVotes.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无投票记录</div>
        ) : (
          <>
            {/* 桌面端表格 */}
            <div className="desktop-votes-table" style={{ display: 'block' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '800px' }}>
                <thead>
                  <tr style={{ background: '#f8f9fa' }}>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>竞品ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>用户ID</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>投票类型</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>留言</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>匿名</th>
                    <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>创建时间</th>
                  </tr>
                </thead>
                <tbody>
                  {leaderboardVotes.map((vote) => (
                    <tr key={vote.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                      <td style={{ padding: '12px' }}>{vote.id}</td>
                      <td style={{ padding: '12px' }}>{vote.item_id}</td>
                      <td style={{ padding: '12px' }}>
                        {vote.is_anonymous ? (
                          <span style={{ color: '#999', fontStyle: 'italic' }}>匿名</span>
                        ) : (
                          vote.user_id
                        )}
                      </td>
                      <td style={{ padding: '12px' }}>
                        <span style={{
                          padding: '4px 8px',
                          borderRadius: '4px',
                          background: vote.vote_type === 'upvote' ? '#52c41a' : '#ff4d4f',
                          color: 'white',
                          fontSize: '12px'
                        }}>
                          {vote.vote_type === 'upvote' ? '👍 点赞' : '👎 点踩'}
                        </span>
                      </td>
                      <td style={{ padding: '12px', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {vote.comment || <span style={{ color: '#999', fontStyle: 'italic' }}>（无留言）</span>}
                      </td>
                      <td style={{ padding: '12px' }}>
                        {vote.is_anonymous ? (
                          <span style={{ color: '#ff4d4f', fontWeight: 'bold' }}>是</span>
                        ) : (
                          <span style={{ color: '#52c41a' }}>否</span>
                        )}
                      </td>
                      <td style={{ padding: '12px', fontSize: '12px', color: '#666' }}>
                        {new Date(vote.created_at).toLocaleString('zh-CN')}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* 移动端卡片 */}
            <div className="mobile-votes-cards" style={{ display: 'none' }}>
              {leaderboardVotes.map((vote) => (
                <div key={vote.id} style={{
                  padding: '16px',
                  borderBottom: '1px solid #f0f0f0',
                  background: 'white'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <span style={{ fontWeight: 'bold', fontSize: '16px' }}>ID: {vote.id}</span>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: vote.vote_type === 'upvote' ? '#52c41a' : '#ff4d4f',
                      color: 'white',
                      fontSize: '12px'
                    }}>
                      {vote.vote_type === 'upvote' ? '👍 点赞' : '👎 点踩'}
                    </span>
                  </div>
                  <div style={{ marginBottom: '8px', fontSize: '14px', color: '#666' }}>
                    <div>竞品ID: {vote.item_id}</div>
                    <div>用户ID: {vote.is_anonymous ? <span style={{ color: '#999', fontStyle: 'italic' }}>匿名</span> : vote.user_id}</div>
                    <div>匿名: {vote.is_anonymous ? <span style={{ color: '#ff4d4f', fontWeight: 'bold' }}>是</span> : <span style={{ color: '#52c41a' }}>否</span>}</div>
                  </div>
                  {vote.comment && (
                    <div style={{ marginBottom: '8px', padding: '8px', background: '#f5f5f5', borderRadius: '4px', fontSize: '14px' }}>
                      {vote.comment}
                    </div>
                  )}
                  <div style={{ fontSize: '12px', color: '#999' }}>
                    {new Date(vote.created_at).toLocaleString('zh-CN')}
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>

      {/* 移动端响应式样式 */}
      <style>
        {`
          @media (max-width: 768px) {
            .desktop-votes-table {
              display: none !important;
            }
            .mobile-votes-cards {
              display: block !important;
            }
            
            /* 筛选区域移动端优化 */
            div[style*="display: flex"][style*="flexWrap: wrap"] {
              flex-direction: column !important;
            }
            
            div[style*="display: flex"][style*="flexWrap: wrap"] input,
            div[style*="display: flex"][style*="flexWrap: wrap"] select {
              width: 100% !important;
              margin-bottom: 8px !important;
            }
            
            div[style*="display: flex"][style*="flexWrap: wrap"] button {
              width: 100% !important;
              margin-bottom: 8px !important;
            }
          }
          
          @media (min-width: 769px) {
            .desktop-votes-table {
              display: block !important;
            }
            .mobile-votes-cards {
              display: none !important;
            }
          }
        `}
      </style>

      {/* 分页 */}
      {leaderboardVotesTotal > 0 && (
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center' }}>
          <button
            onClick={() => {
              if (leaderboardVotesPage > 1) {
                setLeaderboardVotesPage(leaderboardVotesPage - 1);
              }
            }}
            disabled={leaderboardVotesPage === 1}
            style={{
              padding: '8px 16px',
              margin: '0 4px',
              border: '1px solid #ddd',
              background: leaderboardVotesPage === 1 ? '#f0f0f0' : 'white',
              cursor: leaderboardVotesPage === 1 ? 'not-allowed' : 'pointer',
              borderRadius: '4px'
            }}
          >
            上一页
          </button>
          <span style={{ padding: '8px 16px', display: 'inline-block' }}>
            第 {leaderboardVotesPage} 页
          </span>
          <button
            onClick={() => {
              if (leaderboardVotes.length === 50) {
                setLeaderboardVotesPage(leaderboardVotesPage + 1);
              }
            }}
            disabled={leaderboardVotes.length < 50}
            style={{
              padding: '8px 16px',
              margin: '0 4px',
              border: '1px solid #ddd',
              background: leaderboardVotes.length < 50 ? '#f0f0f0' : 'white',
              cursor: leaderboardVotes.length < 50 ? 'not-allowed' : 'pointer',
              borderRadius: '4px'
            }}
          >
            下一页
          </button>
        </div>
      )}
    </div>
  );

  // 渲染竞品管理
  const renderLeaderboardItems = () => (
    <div>
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '20px',
        marginBottom: '20px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
      }}>
        <h2 style={{ marginBottom: '20px', fontSize: '20px', fontWeight: '600' }}>竞品管理</h2>
        
        {/* 筛选条件 */}
        <div style={{
          display: 'flex',
          gap: '12px',
          marginBottom: '20px',
          flexWrap: 'wrap',
          alignItems: 'center'
        }}>
          <input
            type="number"
            placeholder="榜单ID"
            value={leaderboardItemsFilter.leaderboard_id || ''}
            onChange={(e) => {
              const value = e.target.value.trim();
              setLeaderboardItemsFilter({
                ...leaderboardItemsFilter,
                leaderboard_id: value && !isNaN(Number(value)) ? parseInt(value, 10) : undefined
              });
            }}
            style={{
              padding: '8px 12px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              fontSize: '14px',
              width: '120px'
            }}
          />
          <select
            value={leaderboardItemsFilter.status || 'all'}
            onChange={(e) => setLeaderboardItemsFilter({
              ...leaderboardItemsFilter,
              status: e.target.value as 'all' | 'approved'
            })}
            style={{
              padding: '8px 12px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              fontSize: '14px',
              width: '120px'
            }}
          >
            <option value="all">全部状态</option>
            <option value="approved">已通过</option>
          </select>
          <input
            type="text"
            placeholder="搜索竞品名称或描述"
            value={leaderboardItemsFilter.keyword || ''}
            onChange={(e) => setLeaderboardItemsFilter({
              ...leaderboardItemsFilter,
              keyword: e.target.value
            })}
            style={{
              padding: '8px 12px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              fontSize: '14px',
              flex: 1,
              minWidth: '200px'
            }}
          />
          <button
            onClick={() => {
              setLeaderboardItemsPage(1);
              loadLeaderboardItems();
            }}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: '#007bff',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            搜索
          </button>
          <button
            onClick={() => {
              setLeaderboardItemsFilter({});
              setLeaderboardItemsPage(1);
              loadLeaderboardItems();
            }}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: 'white',
              color: '#333',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            重置
          </button>
        </div>
      </div>

      {/* 竞品列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {leaderboardItemsLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : leaderboardItems.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无竞品</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>名称</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>榜单ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>点赞数</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>点踩数</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>得分</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>创建时间</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {leaderboardItems.map((item: any) => (
                <tr key={item.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{item.id}</td>
                  <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {item.name}
                  </td>
                  <td style={{ padding: '12px' }}>{item.leaderboard_id}</td>
                  <td style={{ padding: '12px', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {item.description || '-'}
                  </td>
                  <td style={{ padding: '12px' }}>{item.upvotes || 0}</td>
                  <td style={{ padding: '12px' }}>{item.downvotes || 0}</td>
                  <td style={{ padding: '12px' }}>{item.vote_score?.toFixed(2) || '0.00'}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: item.status === 'approved' ? '#d4edda' : '#f8d7da',
                      color: item.status === 'approved' ? '#155724' : '#721c24',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {item.status === 'approved' ? '已通过' : item.status}
                    </span>
                  </td>
                  <td style={{ padding: '12px', fontSize: '12px', color: '#666' }}>
                    {dayjs(item.created_at).format('YYYY-MM-DD HH:mm')}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <button
                      onClick={() => handleDeleteLeaderboardItem(item.id, item.name)}
                      style={{
                        padding: '4px 12px',
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
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      {leaderboardItemsTotal > 0 && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: '20px', gap: '10px' }}>
          <button
            onClick={() => {
              if (leaderboardItemsPage > 1) {
                setLeaderboardItemsPage(leaderboardItemsPage - 1);
              }
            }}
            disabled={leaderboardItemsPage === 1}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: leaderboardItemsPage === 1 ? '#f0f0f0' : 'white',
              color: leaderboardItemsPage === 1 ? '#999' : '#333',
              borderRadius: '4px',
              cursor: leaderboardItemsPage === 1 ? 'not-allowed' : 'pointer'
            }}
          >
            上一页
          </button>
          <span style={{ padding: '8px 16px', lineHeight: '32px' }}>
            第 {leaderboardItemsPage} 页，共 {Math.ceil(leaderboardItemsTotal / 50)} 页
          </span>
          <button
            onClick={() => {
              if (leaderboardItems.length === 50) {
                setLeaderboardItemsPage(leaderboardItemsPage + 1);
              }
            }}
            disabled={leaderboardItems.length < 50}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: leaderboardItems.length < 50 ? '#f0f0f0' : 'white',
              color: leaderboardItems.length < 50 ? '#999' : '#333',
              borderRadius: '4px',
              cursor: leaderboardItems.length < 50 ? 'not-allowed' : 'pointer'
            }}
          >
            下一页
          </button>
        </div>
      )}
    </div>
  );

  // 渲染 Banner 管理
  const renderBanners = useCallback(() => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>Banner 广告管理</h2>
        <button
          onClick={() => {
            setBannerForm({
              id: undefined,
              image_url: '',
              title: '',
              subtitle: '',
              link_url: '',
              link_type: 'internal',
              order: 0,
              is_active: true
            });
            setShowBannerModal(true);
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
          创建 Banner
        </button>
      </div>

      {/* 筛选器 */}
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', alignItems: 'center' }}>
        <label style={{ fontWeight: 'bold' }}>状态筛选：</label>
        <select
          value={bannersActiveFilter === undefined ? '' : bannersActiveFilter ? 'true' : 'false'}
          onChange={(e) => {
            const value = e.target.value;
            setBannersActiveFilter(value === '' ? undefined : value === 'true');
            setBannersPage(1);
            setTimeout(() => loadBanners(), 100);
          }}
          style={{
            padding: '8px 12px',
            border: '1px solid #ddd',
            borderRadius: '4px',
            fontSize: '14px'
          }}
        >
          <option value="">全部</option>
          <option value="true">启用</option>
          <option value="false">禁用</option>
        </select>
      </div>

      {/* Banner 列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {bannersLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : banners.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>
            暂无 Banner 数据
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>图片</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>标题</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>副标题</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>链接</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>链接类型</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>排序</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {banners.map((banner: any) => (
                <tr key={banner.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{banner.id}</td>
                  <td style={{ padding: '12px' }}>
                    <img 
                      src={banner.image_url} 
                      alt={banner.title}
                      style={{ width: '80px', height: '40px', objectFit: 'cover', borderRadius: '4px' }}
                      onError={(e) => {
                        (e.target as HTMLImageElement).src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="80" height="40"%3E%3Crect width="80" height="40" fill="%23ddd"/%3E%3Ctext x="50%25" y="50%25" text-anchor="middle" dy=".3em" fill="%23999"%3E无图片%3C/text%3E%3C/svg%3E';
                      }}
                    />
                  </td>
                  <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {banner.title}
                  </td>
                  <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {banner.subtitle || '-'}
                  </td>
                  <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {banner.link_url || '-'}
                  </td>
                  <td style={{ padding: '12px' }}>
                    {banner.link_type === 'internal' ? '内部链接' : '外部链接'}
                  </td>
                  <td style={{ padding: '12px' }}>{banner.order}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: banner.is_active ? '#d4edda' : '#f8d7da',
                      color: banner.is_active ? '#155724' : '#721c24',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {banner.is_active ? '启用' : '禁用'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleEditBanner(banner)}
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
                        onClick={() => handleToggleBannerStatus(banner.id)}
                        style={{
                          padding: '4px 8px',
                          border: '1px solid #ffc107',
                          background: 'white',
                          color: '#ffc107',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px'
                        }}
                      >
                        {banner.is_active ? '禁用' : '启用'}
                      </button>
                      <button
                        onClick={() => handleDeleteBanner(banner.id)}
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
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      {bannersTotal > 20 && (
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
          <button
            onClick={() => {
              if (bannersPage > 1) {
                setBannersPage(bannersPage - 1);
                setTimeout(() => loadBanners(), 100);
              }
            }}
            disabled={bannersPage === 1}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: bannersPage === 1 ? '#f5f5f5' : 'white',
              color: bannersPage === 1 ? '#999' : '#333',
              borderRadius: '4px',
              cursor: bannersPage === 1 ? 'not-allowed' : 'pointer'
            }}
          >
            上一页
          </button>
          <span style={{ padding: '8px 16px', display: 'flex', alignItems: 'center' }}>
            第 {bannersPage} 页，共 {Math.ceil(bannersTotal / 20)} 页
          </span>
          <button
            onClick={() => {
              if (bannersPage < Math.ceil(bannersTotal / 20)) {
                setBannersPage(bannersPage + 1);
                setTimeout(() => loadBanners(), 100);
              }
            }}
            disabled={bannersPage >= Math.ceil(bannersTotal / 20)}
            style={{
              padding: '8px 16px',
              border: '1px solid #ddd',
              background: bannersPage >= Math.ceil(bannersTotal / 20) ? '#f5f5f5' : 'white',
              color: bannersPage >= Math.ceil(bannersTotal / 20) ? '#999' : '#333',
              borderRadius: '4px',
              cursor: bannersPage >= Math.ceil(bannersTotal / 20) ? 'not-allowed' : 'pointer'
            }}
          >
            下一页
          </button>
        </div>
      )}

      {/* 创建/编辑 Banner 模态框 */}
      {showBannerModal && (
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
            maxWidth: '700px',
            maxHeight: '90vh',
            overflowY: 'auto'
          }}>
            <h3 style={{ margin: '0 0 20px 0', color: '#333' }}>
              {bannerForm.id ? '编辑 Banner' : '创建 Banner'}
            </h3>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                图片 URL <span style={{ color: 'red' }}>*</span>
              </label>
              <div style={{ display: 'flex', gap: '10px' }}>
                <input
                  type="text"
                  value={bannerForm.image_url}
                  onChange={(e) => setBannerForm({...bannerForm, image_url: e.target.value})}
                  placeholder="请输入图片 URL"
                  style={{
                    flex: 1,
                    padding: '8px',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    marginTop: '5px'
                  }}
                />
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      handleUploadImage(file);
                    }
                  }}
                  disabled={uploadingImage}
                  style={{ display: 'none' }}
                  id="banner-image-upload"
                />
                <label
                  htmlFor="banner-image-upload"
                  style={{
                    padding: '8px 16px',
                    border: '1px solid #007bff',
                    background: uploadingImage ? '#ccc' : 'white',
                    color: '#007bff',
                    borderRadius: '4px',
                    cursor: uploadingImage ? 'not-allowed' : 'pointer',
                    fontSize: '14px',
                    marginTop: '5px',
                    display: 'inline-block'
                  }}
                >
                  {uploadingImage ? '上传中...' : '上传图片'}
                </label>
              </div>
              {bannerForm.image_url && (
                <img 
                  src={bannerForm.image_url} 
                  alt="预览"
                  style={{ 
                    marginTop: '10px', 
                    maxWidth: '100%', 
                    maxHeight: '200px', 
                    borderRadius: '4px',
                    border: '1px solid #ddd'
                  }}
                  onError={(e) => {
                    (e.target as HTMLImageElement).style.display = 'none';
                  }}
                />
              )}
            </div>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                标题 <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="text"
                value={bannerForm.title}
                onChange={(e) => setBannerForm({...bannerForm, title: e.target.value})}
                placeholder="请输入广告标题"
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>副标题</label>
              <input
                type="text"
                value={bannerForm.subtitle}
                onChange={(e) => setBannerForm({...bannerForm, subtitle: e.target.value})}
                placeholder="请输入副标题（可选）"
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>跳转链接</label>
              <input
                type="text"
                value={bannerForm.link_url}
                onChange={(e) => setBannerForm({...bannerForm, link_url: e.target.value})}
                placeholder="请输入跳转链接（可选）"
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
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>链接类型</label>
              <select
                value={bannerForm.link_type}
                onChange={(e) => setBannerForm({...bannerForm, link_type: e.target.value as 'internal' | 'external'})}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  marginTop: '5px'
                }}
              >
                <option value="internal">内部链接</option>
                <option value="external">外部链接</option>
              </select>
            </div>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>排序顺序</label>
              <input
                type="number"
                value={bannerForm.order}
                onChange={(e) => setBannerForm({...bannerForm, order: parseInt(e.target.value) || 0})}
                placeholder="数字越小越靠前"
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
                  checked={bannerForm.is_active}
                  onChange={(e) => setBannerForm({...bannerForm, is_active: e.target.checked})}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontWeight: 'bold' }}>启用</span>
              </label>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowBannerModal(false);
                  setBannerForm({
                    id: undefined,
                    image_url: '',
                    title: '',
                    subtitle: '',
                    link_url: '',
                    link_type: 'internal',
                    order: 0,
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
                onClick={bannerForm.id ? handleUpdateBanner : handleCreateBanner}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  background: '#007bff',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                {bannerForm.id ? '更新' : '创建'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  ), [banners, bannersPage, bannersTotal, bannersLoading, bannersActiveFilter, showBannerModal, bannerForm, uploadingImage, handleCreateBanner, handleUpdateBanner, handleDeleteBanner, handleToggleBannerStatus, handleEditBanner, handleUploadImage, loadBanners]);

  // 渲染榜单审核管理
  const renderLeaderboardReview = () => (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>榜单审核管理</h2>
        <button
          onClick={loadPendingLeaderboards}
          style={{
            padding: '8px 16px',
            border: 'none',
            background: '#007bff',
            color: 'white',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          刷新
        </button>
      </div>

      {/* 待审核榜单列表 */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        overflow: 'auto'
      }}>
        {leaderboardsLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : pendingLeaderboards.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无待审核榜单</div>
        ) : (
          <div style={{ padding: '20px' }}>
            {pendingLeaderboards.map((leaderboard) => (
              <div
                key={leaderboard.id}
                style={{
                  padding: '20px',
                  border: '1px solid #e0e0e0',
                  borderRadius: '8px',
                  marginBottom: '16px',
                  background: '#fafafa'
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' }}>
                  <div style={{ flex: 1 }}>
                    <h3 style={{ margin: '0 0 8px 0', fontSize: '18px', fontWeight: 'bold' }}>
                      {leaderboard.name}
                    </h3>
                    <div style={{ fontSize: '14px', color: '#666', marginBottom: '8px' }}>
                      <span style={{ marginRight: '16px' }}>📍 地区：{leaderboard.location}</span>
                      <span style={{ marginRight: '16px' }}>👤 申请人ID：{leaderboard.applicant_id}</span>
                      <span>📅 申请时间：{new Date(leaderboard.created_at).toLocaleString('zh-CN')}</span>
                    </div>
                    {leaderboard.description && (
                      <div style={{ marginBottom: '12px', padding: '12px', background: 'white', borderRadius: '4px', fontSize: '14px', color: '#333' }}>
                        <strong>描述：</strong>{leaderboard.description}
                      </div>
                    )}
                    {leaderboard.application_reason && (
                      <div style={{ marginBottom: '12px', padding: '12px', background: '#fff7e6', borderRadius: '4px', fontSize: '14px', color: '#333' }}>
                        <strong>申请理由：</strong>{leaderboard.application_reason}
                      </div>
                    )}
                    {leaderboard.cover_image && (
                      <div style={{ marginBottom: '12px' }}>
                        <LazyImage
                          src={leaderboard.cover_image}
                          alt="封面"
                          style={{ maxWidth: '200px', maxHeight: '150px', borderRadius: '4px', objectFit: 'cover' }}
                        />
                      </div>
                    )}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
                  <button
                    onClick={() => handleOpenReviewModal(leaderboard, 'approve')}
                    disabled={reviewingLeaderboard === leaderboard.id}
                    style={{
                      padding: '8px 16px',
                      border: 'none',
                      background: reviewingLeaderboard === leaderboard.id ? '#ccc' : '#52c41a',
                      color: 'white',
                      borderRadius: '4px',
                      cursor: reviewingLeaderboard === leaderboard.id ? 'not-allowed' : 'pointer',
                      fontWeight: 'bold'
                    }}
                  >
                    {reviewingLeaderboard === leaderboard.id ? '处理中...' : '✓ 批准'}
                  </button>
                  <button
                    onClick={() => handleOpenReviewModal(leaderboard, 'reject')}
                    disabled={reviewingLeaderboard === leaderboard.id}
                    style={{
                      padding: '8px 16px',
                      border: 'none',
                      background: reviewingLeaderboard === leaderboard.id ? '#ccc' : '#ff4d4f',
                      color: 'white',
                      borderRadius: '4px',
                      cursor: reviewingLeaderboard === leaderboard.id ? 'not-allowed' : 'pointer',
                      fontWeight: 'bold'
                    }}
                  >
                    {reviewingLeaderboard === leaderboard.id ? '处理中...' : '✗ 拒绝'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* 审核弹窗 */}
      <Modal
        title={selectedLeaderboardForReview ? `审核榜单：${selectedLeaderboardForReview.name}` : '审核榜单'}
        open={showLeaderboardReviewModal}
        onCancel={() => {
          setShowLeaderboardReviewModal(false);
          setSelectedLeaderboardForReview(null);
          setLeaderboardReviewComment('');
        }}
        footer={null}
        width={600}
      >
        {selectedLeaderboardForReview && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div>
              <strong>榜单名称：</strong>{selectedLeaderboardForReview.name}
            </div>
            <div>
              <strong>地区：</strong>{selectedLeaderboardForReview.location}
            </div>
            {selectedLeaderboardForReview.description && (
              <div>
                <strong>描述：</strong>
                <div style={{ marginTop: '8px', padding: '8px', background: '#f5f5f5', borderRadius: '4px' }}>
                  {selectedLeaderboardForReview.description}
                </div>
              </div>
            )}
            {selectedLeaderboardForReview.application_reason && (
              <div>
                <strong>申请理由：</strong>
                <div style={{ marginTop: '8px', padding: '8px', background: '#fff7e6', borderRadius: '4px' }}>
                  {selectedLeaderboardForReview.application_reason}
                </div>
              </div>
            )}
            {selectedLeaderboardForReview.cover_image && (
              <div>
                <strong>榜单封面图片：</strong>
                <div style={{ marginTop: '8px' }}>
                  <LazyImage
                    src={selectedLeaderboardForReview.cover_image}
                    alt="榜单封面"
                    style={{
                      maxWidth: '100%',
                      maxHeight: '300px',
                      borderRadius: '8px',
                      objectFit: 'cover',
                      border: '1px solid #e0e0e0'
                    }}
                  />
                </div>
              </div>
            )}
            <div>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>
                审核意见（可选）：
              </label>
              <textarea
                value={leaderboardReviewComment}
                onChange={(e) => setLeaderboardReviewComment(e.target.value)}
                placeholder="请输入审核意见..."
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  minHeight: '100px',
                  resize: 'vertical'
                }}
                maxLength={500}
              />
              <div style={{ fontSize: '12px', color: '#999', marginTop: '4px' }}>
                {leaderboardReviewComment.length}/500
              </div>
            </div>
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <button
                onClick={() => {
                  setShowLeaderboardReviewModal(false);
                  setSelectedLeaderboardForReview(null);
                  setLeaderboardReviewComment('');
                  setReviewingLeaderboard(null); // 取消时重置状态
                }}
                style={{
                  padding: '8px 16px',
                  border: '1px solid #ddd',
                  background: 'white',
                  color: '#333',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                取消
              </button>
              <button
                onClick={() => handleSubmitReview('reject')}
                disabled={reviewingLeaderboard === selectedLeaderboardForReview.id}
                style={{
                  padding: '8px 16px',
                  border: 'none',
                  background: reviewingLeaderboard === selectedLeaderboardForReview.id ? '#ccc' : '#ff4d4f',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: reviewingLeaderboard === selectedLeaderboardForReview.id ? 'not-allowed' : 'pointer',
                  fontWeight: 'bold'
                }}
              >
                {reviewingLeaderboard === selectedLeaderboardForReview.id ? '处理中...' : '拒绝'}
              </button>
              <button
                onClick={() => handleSubmitReview('approve')}
                disabled={reviewingLeaderboard === selectedLeaderboardForReview.id}
                style={{
                  padding: '8px 16px',
                  border: 'none',
                  background: reviewingLeaderboard === selectedLeaderboardForReview.id ? '#ccc' : '#52c41a',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: reviewingLeaderboard === selectedLeaderboardForReview.id ? 'not-allowed' : 'pointer',
                  fontWeight: 'bold'
                }}
              >
                {reviewingLeaderboard === selectedLeaderboardForReview.id ? '处理中...' : '批准'}
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );

  // 标签页按钮样式函数 - 使用CSS类
  const getTabButtonClassName = (isActive: boolean, specialColor?: string) => {
    const baseClass = styles.tabButton;
    if (specialColor) {
      return `${baseClass} ${styles.tabButtonSpecial}`;
    }
    return isActive 
      ? `${baseClass} ${styles.tabButtonActive}` 
      : `${baseClass} ${styles.tabButtonInactive}`;
  };

  // 使用useMemo缓存样式对象（如果必须使用内联样式）
  const specialButtonStyles = useMemo(() => ({
    green: { background: '#28a745' },
    cyan: { background: '#17a2b8' },
    purple: { background: '#6f42c1' },
    orange: { background: '#ff6b35' }
  }), []);

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2 className={styles.headerTitle}>管理后台</h2>
        <div className={styles.headerActions}>
          {/* 提醒按钮 */}
          <NotificationBell 
            ref={notificationBellRef}
            userType="admin" 
            onOpenModal={() => setShowNotificationModal(true)}
          />
          <button 
            onClick={() => navigate('/')}
            className={`${styles.btn} ${styles.btnPrimary}`}
          >
            返回首页
          </button>
          <button 
            onClick={handleLogout}
            className={`${styles.btn} ${styles.btnDanger}`}
          >
            退出登录
          </button>
        </div>
      </div>

      {/* 标签页导航 - 分组显示 */}
      <div style={{ marginBottom: '20px' }}>
        {/* 核心管理 */}
        <div className={styles.tabGroup}>
          <div className={styles.tabGroupTitle}>核心管理</div>
          <div className={styles.tabButtons}>
            <button 
              className={getTabButtonClassName(activeTab === 'dashboard')}
              onClick={() => handleTabChange('dashboard')}
            >
              📊 数据概览
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'users')}
              onClick={() => handleTabChange('users')}
            >
              👥 用户管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'personnel')}
              onClick={() => handleTabChange('personnel')}
            >
              👨‍💼 人员管理
            </button>
          </div>
        </div>

        {/* 内容管理 */}
        <div className={styles.tabGroup}>
          <div className={styles.tabGroupTitle}>内容管理</div>
          <div className={styles.tabButtons}>
            <button 
              className={getTabButtonClassName(activeTab === 'forum-categories')}
              onClick={() => handleTabChange('forum-categories')}
            >
              📁 论坛板块管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'forum-category-requests')}
              onClick={() => handleTabChange('forum-category-requests')}
            >
              📋 板块申请管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'forum-posts')}
              onClick={() => handleTabChange('forum-posts')}
            >
              📝 论坛内容管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'flea-market-items')}
              onClick={() => handleTabChange('flea-market-items')}
            >
              🛒 商品管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'leaderboard-votes')}
              onClick={() => handleTabChange('leaderboard-votes')}
            >
              📊 投票记录
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'leaderboard-review')}
              onClick={() => handleTabChange('leaderboard-review')}
            >
              ✅ 榜单审核
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'leaderboard-items')}
              onClick={() => handleTabChange('leaderboard-items')}
            >
              🏆 竞品管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'reports')}
              onClick={() => handleTabChange('reports')}
            >
              🚨 举报管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'task-disputes')}
              onClick={() => handleTabChange('task-disputes')}
              style={{ position: 'relative' }}
            >
              ⚖️ 任务争议
              {/* 待处理争议数量提示 */}
              {taskDisputes.filter((d: any) => d.status === 'pending').length > 0 && (
                <div style={{
                  position: 'absolute',
                  top: 5,
                  right: 8,
                  minWidth: 18,
                  height: 18,
                  borderRadius: '50%',
                  background: '#ff4d4f',
                  color: '#fff',
                  fontSize: 12,
                  fontWeight: 600,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  border: '2px solid #fff',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
                  animation: 'pulse 2s infinite'
                }}>
                  {taskDisputes.filter((d: any) => d.status === 'pending').length}
                </div>
              )}
            </button>
          </div>
        </div>

        {/* 系统功能 */}
        <div className={styles.tabGroup}>
          <div className={styles.tabGroupTitle}>系统功能</div>
          <div className={styles.tabButtons}>
            <button 
              className={getTabButtonClassName(false, 'green')}
              style={specialButtonStyles.green}
              onClick={() => setShowTaskManagement(true)}
            >
              ✅ 任务管理
            </button>
            <button 
              className={getTabButtonClassName(false, 'cyan')}
              style={specialButtonStyles.cyan}
              onClick={() => setShowCustomerServiceManagement(true)}
            >
              💬 客服管理
            </button>
            <button 
              className={getTabButtonClassName(false, 'purple')}
              style={specialButtonStyles.purple}
              onClick={() => setShowSystemSettings(true)}
            >
              ⚙️ 系统设置
            </button>
            <button 
              className={getTabButtonClassName(false, 'blue')}
              style={{ ...specialButtonStyles.blue, background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)' }}
              onClick={() => setShow2FASettings(true)}
            >
              🔐 2FA 设置
            </button>
            <button 
              className={getTabButtonClassName(false, 'orange')}
              style={specialButtonStyles.orange}
              onClick={() => setShowJobPositionManagement(true)}
            >
              💼 岗位管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'task-experts')}
              onClick={() => {
                handleTabChange('task-experts');
                setTaskExpertSubTab('list');
              }}
            >
              ⭐ 任务达人
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'notifications')}
              onClick={() => handleTabChange('notifications')}
            >
              📢 发送通知
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'invitation-codes')}
              onClick={() => handleTabChange('invitation-codes')}
            >
              🎫 邀请码管理
            </button>
            <button 
              className={getTabButtonClassName(activeTab === 'banners')}
              onClick={() => handleTabChange('banners')}
            >
              🎨 Banner管理
            </button>
          </div>
        </div>
      </div>

      <div>
        {loading && (
          <div className={styles.loadingContainer}>
            <div className={styles.loadingSpinner}>
              <div className={styles.spinner}></div>
              <span className={styles.loadingText}>加载中...</span>
            </div>
          </div>
        )}

        {error && (
          <div className={styles.errorContainer}>
            <div className={styles.errorContent}>
              <span className={styles.emptyIcon}>⚠️</span>
              <span>{error}</span>
            </div>
            <button
              onClick={() => setError(null)}
              className={styles.errorCloseBtn}
            >
              关闭
            </button>
          </div>
        )}

        {!loading && !error && (
          <div className={styles.content}>
            {activeTab === 'dashboard' && renderDashboard()}
            {activeTab === 'users' && renderUsers()}
            {activeTab === 'personnel' && renderPersonnelManagement()}
            {activeTab === 'task-experts' && renderTaskExperts()}
            {activeTab === 'notifications' && renderNotifications()}
            {activeTab === 'invitation-codes' && renderInvitationCodes()}
            {activeTab === 'forum-categories' && renderForumCategories()}
            {activeTab === 'forum-category-requests' && renderCategoryRequests()}
            {activeTab === 'forum-posts' && renderForumPosts()}
            {activeTab === 'reports' && renderReports()}
            {activeTab === 'task-disputes' && renderTaskDisputes()}
            {activeTab === 'flea-market-items' && renderFleaMarketItems()}
            {activeTab === 'leaderboard-votes' && renderLeaderboardVotes()}
            {activeTab === 'leaderboard-review' && renderLeaderboardReview()}
            {activeTab === 'leaderboard-items' && renderLeaderboardItems()}
            {activeTab === 'banners' && renderBanners()}
          </div>
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

      {/* 2FA 设置弹窗 */}
      {show2FASettings && (
        <TwoFactorAuthSettings
          visible={show2FASettings}
          onClose={() => setShow2FASettings(false)}
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