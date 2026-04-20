import React, { useState, useCallback } from 'react';
import { message, Modal, Select, Tag, Spin } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import api, {
  getExperts,
  getExpertForAdmin,
  updateExpert,
  deleteExpert,
  getExpertApplications,
  reviewExpertApplication,
  createExpertTeamByAdmin,
  getProfileUpdateRequests,
  reviewProfileUpdateRequest,
  getAllExpertServicesAdmin,
  getAllExpertActivitiesAdmin,
  getExpertServicesAdmin,
  updateExpertServiceAdmin,
  deleteExpertServiceAdmin,
  updateExpertActivityAdmin,
  deleteExpertActivityAdmin,
  reviewExpertServiceAdmin,
  reviewExpertActivityAdmin,
  toggleFeaturedExpert,
  getUsersForAdmin,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type SubTab = 'list' | 'applications' | 'profile_updates' | 'services' | 'activities';

interface ReviewForm {
  action: 'approve' | 'reject';
  reviewType: 'application' | 'profile';
  reviewComment: string;
  item: any;
}

const initialReviewForm: ReviewForm = {
  action: 'approve',
  reviewType: 'application',
  reviewComment: '',
  item: null,
};

// 与新 `experts` 表 (migration 188 后) + admin_expert_routes.update_expert_admin 的
// allowed_fields 对齐。is_featured 走单独的 /api/admin/experts/{id}/feature 端点
// (FeaturedExpertV2 表), 不在 PUT 主体里;UI 上仍作为单字段呈现。
interface ExpertEditForm {
  id: string;
  name: string;
  name_en: string;
  name_zh: string;
  bio: string;
  bio_en: string;
  bio_zh: string;
  avatar: string;
  status: 'active' | 'inactive' | 'suspended' | 'dissolved';
  is_official: boolean;
  official_badge: string;
  allow_applications: boolean;
  // migration 188 — 达人画像字段
  category: string;
  location: string;
  display_order: number;
  is_verified: boolean;
  user_level: string;
  expertise_areas: string;     // 逗号/换行分隔, 提交前 parseList 转 string[]
  expertise_areas_en: string;
  featured_skills: string;
  featured_skills_en: string;
  achievements: string;
  achievements_en: string;
  response_time: string;
  response_time_en: string;
  // 通过单独端点同步, 显示在主表单里
  is_featured: boolean;
  services: any[];
}

const STATUS_OPTIONS: Array<{ value: ExpertEditForm['status']; label: string }> = [
  { value: 'active', label: '活跃 active' },
  { value: 'inactive', label: '停用 inactive' },
  { value: 'suspended', label: '暂停 suspended' },
];

const CATEGORY_OPTIONS = [
  { value: '', label: '未分类' },
  { value: 'programming', label: '编程开发 Programming' },
  { value: 'translation', label: '翻译 Translation' },
  { value: 'tutoring', label: '辅导 Tutoring' },
  { value: 'food', label: '美食 Food' },
  { value: 'beverage', label: '饮品 Beverage' },
  { value: 'cake', label: '烘焙 Cake' },
  { value: 'errand_transport', label: '跑腿代送 Errand & Transport' },
  { value: 'social_entertainment', label: '社交娱乐 Social & Entertainment' },
  { value: 'beauty_skincare', label: '美容护肤 Beauty & Skincare' },
  { value: 'handicraft', label: '手工 Handicraft' },
];

const initialEditForm: ExpertEditForm = {
  id: '',
  name: '',
  name_en: '',
  name_zh: '',
  bio: '',
  bio_en: '',
  bio_zh: '',
  avatar: '',
  status: 'active',
  is_official: false,
  official_badge: '',
  allow_applications: false,
  category: '',
  location: '',
  display_order: 0,
  is_verified: false,
  user_level: 'normal',
  expertise_areas: '',
  expertise_areas_en: '',
  featured_skills: '',
  featured_skills_en: '',
  achievements: '',
  achievements_en: '',
  response_time: '',
  response_time_en: '',
  is_featured: false,
  services: [],
};

const CATEGORY_COMPRESS_OPTIONS: Record<string, { maxSizeMB: number; maxWidthOrHeight: number }> = {
  expert_avatar: { maxSizeMB: 1.8, maxWidthOrHeight: 512 },
  service_image: { maxSizeMB: 4, maxWidthOrHeight: 1920 },
  activity: { maxSizeMB: 8, maxWidthOrHeight: 1920 },
};

const uploadImageWithCategory = async (file: File, category: string, resourceId?: string): Promise<string> => {
  const { compressImage } = await import('../../../utils/imageCompression');
  const opts = CATEGORY_COMPRESS_OPTIONS[category] || { maxSizeMB: 4, maxWidthOrHeight: 1920 };
  const compressed = await compressImage(file, opts);
  const formData = new FormData();
  formData.append('image', compressed);
  let url = `/api/v2/upload/image?category=${category}`;
  if (resourceId != null && resourceId !== '') {
    url += `&resource_id=${encodeURIComponent(resourceId)}`;
  }
  const res = await api.post(url, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return res.data.url || res.data.image_url;
};

const SERVICE_STATUS_OPTIONS = [
  { value: '', label: '全部' },
  { value: 'pending', label: '待审核' },
  { value: 'active', label: '已上架' },
  { value: 'rejected', label: '已拒绝' },
];
const ACTIVITY_STATUS_OPTIONS = [
  { value: '', label: '全部' },
  { value: 'pending_review', label: '待审核' },
  { value: 'open', label: '进行中' },
  { value: 'rejected', label: '已拒绝' },
];

const ExpertManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('list');
  const [detailExpert, setDetailExpert] = useState<any>(null);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const [serviceImageUploading, setServiceImageUploading] = useState<number | null>(null);

  // ==================== 新建达人团队 Modal ====================
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [createForm, setCreateForm] = useState({
    name: '',
    name_en: '',
    name_zh: '',
    bio: '',
    owner_user_id: '',
    is_official: false,
    official_badge: '',
    allow_applications: false,
  });
  const [createSubmitting, setCreateSubmitting] = useState(false);
  // 创建成功后保存新 expert id,用于第二步上传头像
  const [createdExpertId, setCreatedExpertId] = useState<string | null>(null);
  const [createdExpertAvatar, setCreatedExpertAvatar] = useState<string>('');
  const [createdAvatarUploading, setCreatedAvatarUploading] = useState(false);
  // Owner 用户搜索
  const [ownerOptions, setOwnerOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [ownerSearchLoading, setOwnerSearchLoading] = useState(false);
  const ownerSearchTimerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);

  const resetCreateForm = () => {
    setCreateForm({
      name: '',
      name_en: '',
      name_zh: '',
      bio: '',
      owner_user_id: '',
      is_official: false,
      official_badge: '',
      allow_applications: false,
    });
    setCreatedExpertId(null);
    setCreatedExpertAvatar('');
    setOwnerOptions([]);
  };

  const handleOwnerSearch = (query: string) => {
    if (ownerSearchTimerRef.current) {
      clearTimeout(ownerSearchTimerRef.current);
    }
    if (!query || query.length < 1) {
      setOwnerOptions([]);
      return;
    }
    ownerSearchTimerRef.current = setTimeout(async () => {
      setOwnerSearchLoading(true);
      try {
        const response = await getUsersForAdmin(1, 20, query);
        const users = (response.users || []) as Array<{ id: string; name?: string; email?: string }>;
        setOwnerOptions(
          users.map((u) => ({
            value: u.id,
            label: `${u.name || '(无昵称)'} · ${u.id}${u.email ? ` · ${u.email}` : ''}`,
          })),
        );
      } catch (err) {
        message.error(getErrorMessage(err));
      } finally {
        setOwnerSearchLoading(false);
      }
    }, 300);
  };

  const handleCreateSubmit = async () => {
    if (!createForm.name.trim()) {
      message.error('团队名称不能为空');
      return;
    }
    if (!createForm.owner_user_id.trim()) {
      message.error('必须指定 Owner 用户');
      return;
    }
    setCreateSubmitting(true);
    try {
      const result = await createExpertTeamByAdmin({
        name: createForm.name.trim(),
        owner_user_id: createForm.owner_user_id.trim(),
        name_en: createForm.name_en.trim() || undefined,
        name_zh: createForm.name_zh.trim() || undefined,
        bio: createForm.bio.trim() || undefined,
        is_official: createForm.is_official,
        official_badge: createForm.official_badge.trim() || undefined,
        allow_applications: createForm.allow_applications,
      });
      message.success(`创建成功，达人 ID: ${result.expert_id}`);
      // 进入第二步:可选上传头像
      setCreatedExpertId(result.expert_id);
      expertsTable.refresh();
    } catch (error) {
      message.error(getErrorMessage(error));
    } finally {
      setCreateSubmitting(false);
    }
  };

  const handleCreatedAvatarUpload = async (file: File) => {
    if (!createdExpertId) return;
    setCreatedAvatarUploading(true);
    try {
      const url = await uploadImageWithCategory(file, 'expert_avatar', createdExpertId);
      // 直接 PUT 到达人记录上
      await updateExpert(createdExpertId, { avatar: url });
      setCreatedExpertAvatar(url);
      message.success('头像上传成功');
      expertsTable.refresh();
    } catch (err) {
      message.error(getErrorMessage(err));
    } finally {
      setCreatedAvatarUploading(false);
    }
  };

  const closeCreateModal = () => {
    if (createSubmitting || createdAvatarUploading) return;
    setCreateModalOpen(false);
    resetCreateForm();
  };
  // Status filters use useAdminTable's built-in filters to avoid stale closure on refresh

  // ==================== 达人列表 ====================
  const fetchExperts = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getExperts({ page, size: pageSize });
    return {
      data: response.task_experts || [],
      total: response.total || 0,
    };
  }, []);

  const expertsTable = useAdminTable<any>({
    fetchData: fetchExperts,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'list',
  });

  // ==================== 申请列表 ====================
  const fetchApplications = useCallback(async () => {
    const response = await getExpertApplications({});
    return {
      data: response.items || [],
      total: response.total || (response.items || []).length,
    };
  }, []);

  const applicationsTable = useAdminTable<any>({
    fetchData: fetchApplications,
    initialPageSize: 100,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'applications',
  });

  // ==================== 资料修改请求列表 ====================
  const fetchProfileUpdates = useCallback(async () => {
    const response = await getProfileUpdateRequests({ status: 'pending' });
    return {
      data: response.items || [],
      total: response.total || (response.items || []).length,
    };
  }, []);

  const profileUpdatesTable = useAdminTable<any>({
    fetchData: fetchProfileUpdates,
    initialPageSize: 100,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'profile_updates',
  });

  // ==================== 服务管理 ====================
  const fetchServices = useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; filters?: Record<string, any> }) => {
    const res = await getAllExpertServicesAdmin({
      page,
      limit: pageSize,
      ...(filters?.status_filter ? { status_filter: filters.status_filter } : {}),
    });
    return { data: res.items || [], total: res.total || 0 };
  }, []);
  const servicesTable = useAdminTable<any>({
    fetchData: fetchServices,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'services',
  });

  // ==================== 活动管理 ====================
  const fetchActivities = useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; filters?: Record<string, any> }) => {
    const res = await getAllExpertActivitiesAdmin({
      page,
      limit: pageSize,
      ...(filters?.status_filter ? { status_filter: filters.status_filter } : {}),
    });
    return { data: res.items || [], total: res.total || 0 };
  }, []);
  const activitiesTable = useAdminTable<any>({
    fetchData: fetchActivities,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'activities',
  });

  // ==================== 审核模态框 ====================
  const reviewModal = useModalForm<ReviewForm>({
    initialValues: initialReviewForm,
    onSubmit: async (values) => {
      if (!values.item) return;
      if (values.reviewType === 'application') {
        await reviewExpertApplication(values.item.id, {
          action: values.action,
          review_comment: values.reviewComment || undefined
        });
      } else {
        await reviewProfileUpdateRequest(values.item.id, {
          action: values.action,
          review_comment: values.reviewComment || undefined
        });
      }
      message.success(values.action === 'approve' ? '已批准' : '已拒绝');
      if (values.reviewType === 'application') {
        applicationsTable.refresh();
      } else {
        profileUpdatesTable.refresh();
      }
    },
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const openReview = (item: any, type: 'application' | 'profile', action: 'approve' | 'reject') => {
    reviewModal.open({ action, reviewType: type, reviewComment: '', item });
  };

  // ==================== 编辑模态框 ====================
  // 编辑前快照: 用来对比哪些字段变了, 避免每次保存都打 feature toggle 接口。
  const featuredSnapshotRef = React.useRef<boolean>(false);

  const editModal = useModalForm<ExpertEditForm>({
    initialValues: initialEditForm,
    onSubmit: async (values) => {
      const parseList = (s: string) =>
        s.split(/[,，\n]/).map((v) => v.trim()).filter(Boolean);
      // 1. 基本字段 + 画像字段 走 PUT /api/admin/experts/{id}
      //    (allowlist 字段对齐 admin_expert_routes.update_expert_admin migration 188 后版本)
      await updateExpert(values.id, {
        name: values.name,
        name_en: values.name_en || undefined,
        name_zh: values.name_zh || undefined,
        bio: values.bio || undefined,
        bio_en: values.bio_en || undefined,
        bio_zh: values.bio_zh || undefined,
        avatar: values.avatar || undefined,
        status: values.status,
        is_official: values.is_official,
        official_badge: values.official_badge || undefined,
        allow_applications: values.allow_applications,
        // migration 188 字段
        category: values.category || null,
        location: values.location || null,
        display_order: values.display_order,
        is_verified: values.is_verified,
        user_level: values.user_level || 'normal',
        expertise_areas: parseList(values.expertise_areas),
        expertise_areas_en: parseList(values.expertise_areas_en),
        featured_skills: parseList(values.featured_skills),
        featured_skills_en: parseList(values.featured_skills_en),
        achievements: parseList(values.achievements),
        achievements_en: parseList(values.achievements_en),
        response_time: values.response_time || null,
        response_time_en: values.response_time_en || null,
      });
      // 2. is_featured 切换走单独端点 (FeaturedExpertV2 表), 仅在状态发生变化时调用
      if (values.is_featured !== featuredSnapshotRef.current) {
        try {
          await toggleFeaturedExpert(values.id);
          featuredSnapshotRef.current = values.is_featured;
        } catch (e) {
          message.warning(`基础信息已保存，但精选状态切换失败：${getErrorMessage(e)}`);
        }
      }
      message.success('达人信息已更新');
      expertsTable.refresh();
    },
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const handleEdit = async (expert: any) => {
    // 列表行 record 已包含 ExpertOut 的字段, 但缺 is_featured + 完整服务列表;
    // 这里再 fetch 一次详情 + 服务列表, 保证编辑面板看到的是最新状态。
    let detail: any = expert;
    try {
      detail = await getExpertForAdmin(expert.id);
    } catch (e) {
      // 详情拉取失败时回退用列表行的字段, 不阻塞编辑
      console.warn('getExpertForAdmin failed, falling back to row data', e);
    }
    let services: any[] = [];
    try {
      const res = await getExpertServicesAdmin(expert.id);
      services = res.items || res.services || [];
    } catch {
      // 服务列表非关键, 静默忽略
    }
    const joinList = (arr: any) =>
      Array.isArray(arr) ? arr.join(', ') : (typeof arr === 'string' ? arr : '');
    const isFeatured = !!detail.is_featured;
    featuredSnapshotRef.current = isFeatured;
    const status = (detail.status as ExpertEditForm['status']) || 'active';
    editModal.open({
      id: detail.id,
      name: detail.name || '',
      name_en: detail.name_en || '',
      name_zh: detail.name_zh || '',
      bio: detail.bio || '',
      bio_en: detail.bio_en || '',
      bio_zh: detail.bio_zh || '',
      avatar: detail.avatar || '',
      status,
      is_official: !!detail.is_official,
      official_badge: detail.official_badge || '',
      allow_applications: !!detail.allow_applications,
      category: detail.category || '',
      location: detail.location || '',
      display_order: detail.display_order ?? 0,
      is_verified: !!detail.is_verified,
      user_level: detail.user_level || 'normal',
      expertise_areas: joinList(detail.expertise_areas),
      expertise_areas_en: joinList(detail.expertise_areas_en),
      featured_skills: joinList(detail.featured_skills),
      featured_skills_en: joinList(detail.featured_skills_en),
      achievements: joinList(detail.achievements),
      achievements_en: joinList(detail.achievements_en),
      response_time: detail.response_time || '',
      response_time_en: detail.response_time_en || '',
      is_featured: isFeatured,
      services,
    });
  };

  // 服务编辑
  const serviceFormInitial = { id: 0, expert_id: '', expert_name: '', service_name: '', description: '', base_price: 0, currency: 'GBP', status: 'active', display_order: 0 };
  const serviceEditModal = useModalForm<any>({
    initialValues: serviceFormInitial,
    onSubmit: async (values) => {
      await updateExpertServiceAdmin(values.expert_id, values.id, {
        service_name: values.service_name,
        description: values.description,
        base_price: values.base_price,
        currency: values.currency,
        status: values.status,
        display_order: values.display_order,
      });
      message.success('服务已更新');
      servicesTable.refresh();
    },
    onError: (e) => message.error(getErrorMessage(e)),
  });
  const handleDeleteService = (expertId: string, serviceId: number, name: string) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除服务「${name}」吗？`,
      okText: '删除',
      okButtonProps: { danger: true },
      cancelText: '取消',
      onOk: async () => {
        await deleteExpertServiceAdmin(expertId, serviceId);
        message.success('已删除');
        servicesTable.refresh();
      },
    });
  };

  // 活动编辑
  const activityFormInitial = { id: 0, expert_id: '', expert_name: '', title: '', description: '', status: 'open', location: '', max_participants: 1 };
  const activityEditModal = useModalForm<any>({
    initialValues: activityFormInitial,
    onSubmit: async (values) => {
      await updateExpertActivityAdmin(values.expert_id, values.id, {
        title: values.title,
        description: values.description,
        status: values.status,
        location: values.location,
        max_participants: values.max_participants,
      });
      message.success('活动已更新');
      activitiesTable.refresh();
    },
    onError: (e) => message.error(getErrorMessage(e)),
  });
  const handleDeleteActivity = (expertId: string, activityId: number, title: string) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除活动「${title}」吗？关联任务可能被一并处理。`,
      okText: '删除',
      okButtonProps: { danger: true },
      cancelText: '取消',
      onOk: async () => {
        await deleteExpertActivityAdmin(expertId, activityId);
        message.success('已删除');
        activitiesTable.refresh();
      },
    });
  };

  const handleDelete = (expertId: string, expertName: string) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除达人「${expertName}」吗？此操作不可撤销。`,
      okText: '确定删除',
      cancelText: '取消',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await deleteExpert(expertId);
          message.success('达人已删除');
          expertsTable.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  // ==================== 达人列表列定义 ====================
  const expertColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      width: 100,
      render: (_, record) => (
        <span style={{ fontSize: '12px', fontFamily: 'monospace' }}>
          {record.id?.substring(0, 8)}...
        </span>
      ),
    },
    {
      key: 'name',
      title: '达人名称',
      width: 170,
      render: (_, record) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {record.avatar ? (
            <img src={record.avatar} alt="" style={{ width: 28, height: 28, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />
          ) : (
            <div style={{ width: 28, height: 28, borderRadius: '50%', background: '#e0e0e0', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', color: '#999' }}>?</div>
          )}
          <button
            onClick={() => setDetailExpert(record)}
            style={{ background: 'none', border: 'none', color: '#007bff', cursor: 'pointer', fontWeight: 500, fontSize: '13px', padding: 0, textAlign: 'left' }}
          >
            {record.name || '-'}
          </button>
        </div>
      ),
    },
    {
      key: 'expertise_areas',
      title: '擅长领域',
      width: 200,
      render: (_, record) => {
        const areas = record.expertise_areas || [];
        if (!areas.length) return <span style={{ color: '#999' }}>-</span>;
        return (
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
            {areas.slice(0, 3).map((a: string, i: number) => (
              <Tag key={i} color="blue" style={{ margin: 0 }}>{a}</Tag>
            ))}
            {areas.length > 3 && <Tag style={{ margin: 0 }}>+{areas.length - 3}</Tag>}
          </div>
        );
      },
    },
    {
      key: 'location',
      title: '城市',
      width: 90,
      render: (_, record) => record.location || '-',
    },
    {
      key: 'rating',
      title: '评分',
      width: 70,
      render: (_, record) => (record.rating != null ? Number(record.rating).toFixed(1) : '-'),
    },
    {
      key: 'completed_tasks',
      title: '完成数',
      width: 80,
      render: (_, record) => record.completed_tasks ?? 0,
    },
    {
      key: 'member_count',
      title: '成员',
      width: 60,
      render: (_, record) => record.member_count ?? 1,
    },
    {
      key: 'status',
      title: '状态',
      width: 90,
      render: (_, record) => {
        const s = (record.status as string) || 'active';
        const variantMap: Record<string, 'success' | 'danger' | 'warning' | 'default'> = {
          active: 'success',
          inactive: 'default',
          suspended: 'warning',
          dissolved: 'danger',
        };
        const labelMap: Record<string, string> = {
          active: '活跃',
          inactive: '停用',
          suspended: '暂停',
          dissolved: '已注销',
        };
        return <StatusBadge text={labelMap[s] || s} variant={variantMap[s] || 'default'} />;
      },
    },
    {
      key: 'is_official',
      title: '官方',
      width: 60,
      render: (_, record) => (record.is_official
        ? <StatusBadge text="官方" variant="info" />
        : <span style={{ color: '#bbb' }}>-</span>
      ),
    },
    {
      key: 'display_order',
      title: '排序',
      width: 60,
      render: (_, record) => record.display_order ?? 0,
    },
    {
      key: 'actions',
      title: '操作',
      width: 130,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => handleEdit(record)}
            style={{ padding: '3px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            编辑
          </button>
          <button
            onClick={() => handleDelete(record.id, record.name)}
            style={{ padding: '3px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            删除
          </button>
        </div>
      ),
    },
  ];

  // ==================== 申请列表列定义 ====================
  const applicationColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 60,
    },
    {
      key: 'user',
      title: '申请人',
      width: 130,
      render: (_, record) => record.user_name || record.user_id?.substring(0, 8),
    },
    {
      key: 'expertise',
      title: '擅长领域',
      width: 200,
      render: (_, record) => {
        const areas = record.expertise || record.expertise_areas || [];
        if (typeof areas === 'string') return areas;
        return Array.isArray(areas) ? areas.join(', ') : '-';
      },
    },
    {
      key: 'application_message',
      title: '申请说明',
      width: 220,
      render: (_, record) => (
        <span style={{ maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {record.application_message || record.bio || '-'}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '申请时间',
      width: 150,
      render: (_, record) => record.created_at ? new Date(record.created_at).toLocaleString('zh-CN') : '-',
    },
    {
      key: 'actions',
      title: '操作',
      width: 200,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => openReview(record, 'application', 'approve')}
            style={{ padding: '3px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => openReview(record, 'application', 'reject')}
            style={{ padding: '3px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            拒绝
          </button>
        </div>
      ),
    },
  ];

  // ==================== 资料修改请求列定义 ====================
  const profileUpdateColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 60,
    },
    {
      key: 'expert',
      title: '达人',
      width: 130,
      render: (_, record) => record.expert?.expert_name || record.expert_name || record.expert_id?.substring(0, 8) || '-',
    },
    {
      key: 'changes',
      title: '修改内容',
      width: 300,
      render: (_, record) => {
        const parts: string[] = [];
        if (record.new_expert_name) parts.push(`名称: ${record.new_expert_name}`);
        if (record.new_bio) parts.push(`简介: ${record.new_bio.substring(0, 30)}...`);
        if (record.new_avatar) parts.push('头像: 已更新');
        if (!parts.length) return <span style={{ color: '#999' }}>-</span>;
        return (
          <span style={{ maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
            {parts.join(' | ')}
          </span>
        );
      },
    },
    {
      key: 'created_at',
      title: '申请时间',
      width: 150,
      render: (_, record) => record.created_at ? new Date(record.created_at).toLocaleString('zh-CN') : '-',
    },
    {
      key: 'actions',
      title: '操作',
      width: 130,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => openReview(record, 'profile', 'approve')}
            style={{ padding: '3px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => openReview(record, 'profile', 'reject')}
            style={{ padding: '3px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            拒绝
          </button>
        </div>
      ),
    },
  ];

  const handleReviewService = async (serviceId: number, action: 'approve' | 'reject') => {
    try {
      await reviewExpertServiceAdmin(serviceId, { action });
      message.success(action === 'approve' ? '服务已批准' : '服务已拒绝');
      servicesTable.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleReviewActivity = async (activityId: number, action: 'approve' | 'reject') => {
    try {
      await reviewExpertActivityAdmin(activityId, { action });
      message.success(action === 'approve' ? '活动已批准' : '活动已拒绝');
      activitiesTable.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const statusColor = (s: string) => {
    switch (s) {
      case 'active': case 'open': return '#28a745';
      case 'pending': case 'pending_review': return '#f0ad4e';
      case 'rejected': return '#dc3545';
      case 'inactive': case 'closed': return '#999';
      default: return '#666';
    }
  };

  const statusLabel = (s: string) => {
    switch (s) {
      case 'active': return '已上架';
      case 'pending': return '待审核';
      case 'pending_review': return '待审核';
      case 'rejected': return '已拒绝';
      case 'inactive': return '已下架';
      case 'open': return '进行中';
      case 'closed': return '已关闭';
      default: return s;
    }
  };

  const serviceColumns: Column<any>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 70 },
    { key: 'expert_name', title: '达人', dataIndex: 'expert_name', width: 100 },
    { key: 'service_name', title: '服务名称', dataIndex: 'service_name', width: 160 },
    { key: 'base_price', title: '价格', width: 90, render: (_, r) => `${r.currency || 'GBP'} ${r.base_price ?? 0}` },
    { key: 'status', title: '状态', width: 80, render: (_, r) => <Tag color={statusColor(r.status)}>{statusLabel(r.status)}</Tag> },
    { key: 'display_order', title: '排序', dataIndex: 'display_order', width: 60 },
    {
      key: 'actions',
      title: '操作',
      width: 220,
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          {record.status === 'pending' && (
            <>
              <button
                onClick={() => handleReviewService(record.id, 'approve')}
                style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
              >
                批准
              </button>
              <button
                onClick={() => handleReviewService(record.id, 'reject')}
                style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
              >
                拒绝
              </button>
            </>
          )}
          <button
            onClick={() => serviceEditModal.open({
              id: record.id,
              expert_id: record.expert_id,
              expert_name: record.expert_name,
              service_name: record.service_name,
              description: record.description ?? '',
              base_price: record.base_price,
              currency: record.currency,
              status: record.status,
              display_order: record.display_order ?? 0,
            })}
            style={{ padding: '4px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            编辑
          </button>
          <button
            onClick={() => handleDeleteService(record.expert_id, record.id, record.service_name)}
            style={{ padding: '4px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            删除
          </button>
        </div>
      ),
    },
  ];

  const activityColumns: Column<any>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 70 },
    { key: 'expert_name', title: '达人', dataIndex: 'expert_name', width: 100 },
    { key: 'title', title: '活动标题', dataIndex: 'title', width: 180 },
    { key: 'status', title: '状态', width: 80, render: (_, r) => <Tag color={statusColor(r.status)}>{statusLabel(r.status)}</Tag> },
    { key: 'max_participants', title: '人数', dataIndex: 'max_participants', width: 60 },
    {
      key: 'actions',
      title: '操作',
      width: 220,
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          {record.status === 'pending_review' && (
            <>
              <button
                onClick={() => handleReviewActivity(record.id, 'approve')}
                style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
              >
                批准
              </button>
              <button
                onClick={() => handleReviewActivity(record.id, 'reject')}
                style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
              >
                拒绝
              </button>
            </>
          )}
          <button
            onClick={() => activityEditModal.open({
              id: record.id,
              expert_id: record.expert_id,
              expert_name: record.expert_name,
              title: record.title,
              description: record.description || '',
              status: record.status,
              location: record.location || '',
              max_participants: record.max_participants ?? 1,
            })}
            style={{ padding: '4px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            编辑
          </button>
          <button
            onClick={() => handleDeleteActivity(record.expert_id, record.id, record.title)}
            style={{ padding: '4px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            删除
          </button>
        </div>
      ),
    },
  ];

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>任务达人管理</h2>

      {/* 子标签页 */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        {(['list', 'applications', 'profile_updates', 'services', 'activities'] as SubTab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setSubTab(tab)}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: subTab === tab ? '#007bff' : '#f0f0f0',
              color: subTab === tab ? 'white' : 'black',
              cursor: 'pointer',
              borderRadius: '5px',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            {tab === 'list' ? '达人列表' : tab === 'applications' ? '申请审核' : tab === 'profile_updates' ? '资料修改审核' : tab === 'services' ? '服务管理' : '活动管理'}
          </button>
        ))}
      </div>

      {/* 达人列表 */}
      {subTab === 'list' && (
        <>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
            <button
              onClick={() => setCreateModalOpen(true)}
              style={{
                padding: '8px 16px',
                background: '#28a745',
                color: 'white',
                border: 'none',
                borderRadius: 5,
                cursor: 'pointer',
                fontSize: 14,
                fontWeight: 500,
              }}
            >
              + 新建达人团队
            </button>
          </div>
          <AdminTable
            columns={expertColumns}
            data={expertsTable.data}
            loading={expertsTable.loading}
            refreshing={expertsTable.fetching}
            rowKey="id"
            emptyText="暂无达人数据"
          />
          <AdminPagination
            currentPage={expertsTable.currentPage}
            totalPages={expertsTable.totalPages}
            total={expertsTable.total}
            pageSize={expertsTable.pageSize}
            onPageChange={expertsTable.setCurrentPage}
            onPageSizeChange={expertsTable.setPageSize}
          />
        </>
      )}

      {/* 申请列表 */}
      {subTab === 'applications' && (
        <AdminTable
          columns={applicationColumns}
          data={applicationsTable.data}
          loading={applicationsTable.loading}
          refreshing={applicationsTable.fetching}
          rowKey="id"
          emptyText="暂无待审核申请"
        />
      )}

      {/* 资料修改请求列表 */}
      {subTab === 'profile_updates' && (
        <AdminTable
          columns={profileUpdateColumns}
          data={profileUpdatesTable.data}
          loading={profileUpdatesTable.loading}
          refreshing={profileUpdatesTable.fetching}
          rowKey="id"
          emptyText="暂无待审核资料修改请求"
        />
      )}

      {/* 服务管理 */}
      {subTab === 'services' && (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
            <span>状态筛选：</span>
            <Select
              value={servicesTable.filters.status_filter || undefined}
              onChange={(v) => {
                servicesTable.setFilters({ status_filter: v ?? '' });
              }}
              options={SERVICE_STATUS_OPTIONS}
              style={{ width: 120 }}
              placeholder="全部"
              allowClear
            />
          </div>
          <AdminTable
            columns={serviceColumns}
            data={servicesTable.data}
            loading={servicesTable.loading}
            refreshing={servicesTable.fetching}
            rowKey="id"
            emptyText="暂无服务"
          />
          <AdminPagination
            currentPage={servicesTable.currentPage}
            totalPages={servicesTable.totalPages}
            total={servicesTable.total}
            pageSize={servicesTable.pageSize}
            onPageChange={servicesTable.setCurrentPage}
            onPageSizeChange={servicesTable.setPageSize}
          />
        </>
      )}

      {/* 活动管理 */}
      {subTab === 'activities' && (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
            <span>状态筛选：</span>
            <Select
              value={activitiesTable.filters.status_filter || undefined}
              onChange={(v) => {
                activitiesTable.setFilters({ status_filter: v ?? '' });
              }}
              options={ACTIVITY_STATUS_OPTIONS}
              style={{ width: 120 }}
              placeholder="全部"
              allowClear
            />
          </div>
          <AdminTable
            columns={activityColumns}
            data={activitiesTable.data}
            loading={activitiesTable.loading}
            refreshing={activitiesTable.fetching}
            rowKey="id"
            emptyText="暂无活动"
          />
          <AdminPagination
            currentPage={activitiesTable.currentPage}
            totalPages={activitiesTable.totalPages}
            total={activitiesTable.total}
            pageSize={activitiesTable.pageSize}
            onPageChange={activitiesTable.setCurrentPage}
            onPageSizeChange={activitiesTable.setPageSize}
          />
        </>
      )}

      {/* 审核模态框 */}
      <Modal
        title={reviewModal.formData.action === 'approve' ? '批准确认' : '拒绝确认'}
        open={reviewModal.isOpen}
        onCancel={reviewModal.close}
        onOk={reviewModal.handleSubmit}
        confirmLoading={reviewModal.loading}
        okText={reviewModal.formData.action === 'approve' ? '批准' : '拒绝'}
        cancelText="取消"
      >
        <div style={{ padding: '20px 0' }}>
          <p>确定要{reviewModal.formData.action === 'approve' ? '批准' : '拒绝'}这个{reviewModal.formData.reviewType === 'application' ? '申请' : '资料修改请求'}吗？</p>
          <div style={{ marginTop: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>备注（可选）</label>
            <textarea
              value={reviewModal.formData.reviewComment}
              onChange={(e) => reviewModal.updateField('reviewComment', e.target.value)}
              placeholder="请输入备注..."
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
        </div>
      </Modal>

      {/* 编辑模态框 */}
      <Modal
        title="编辑达人信息"
        open={editModal.isOpen}
        onCancel={editModal.close}
        onOk={editModal.handleSubmit}
        confirmLoading={editModal.loading}
        okText="保存"
        cancelText="取消"
        width={720}
      >
        <div style={{ padding: '12px 0', display: 'flex', flexDirection: 'column', gap: '14px', maxHeight: '65vh', overflowY: 'auto' }}>
          {/* 基本信息 */}
          <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#333', borderBottom: '1px solid #eee', paddingBottom: '6px' }}>基本信息</div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>达人名称</label>
              <input
                type="text"
                value={editModal.formData.name}
                onChange={(e) => editModal.updateField('name', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>达人头像</label>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                {editModal.formData.avatar && (
                  <img
                    src={editModal.formData.avatar}
                    alt="头像"
                    style={{ width: 48, height: 48, borderRadius: '50%', objectFit: 'cover', border: '1px solid #ddd' }}
                  />
                )}
                <div style={{ flex: 1 }}>
                  <input
                    type="file"
                    accept="image/*"
                    disabled={avatarUploading}
                    onChange={async (e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      // 必须传 resource_id=达人 user_id，否则后端会用当前登录的管理员 id 存到 expert_avatars/{管理员id}/，孤儿清理会误删（管理员不在 users 表）
                      const expertId = editModal.formData.id;
                      if (!expertId) {
                        message.error('请先保存达人基本信息后再上传头像');
                        return;
                      }
                      setAvatarUploading(true);
                      try {
                        const url = await uploadImageWithCategory(file, 'expert_avatar', expertId);
                        editModal.updateField('avatar', url);
                        message.success('头像上传成功');
                      } catch (err: any) {
                        message.error(getErrorMessage(err));
                      } finally {
                        setAvatarUploading(false);
                        e.target.value = '';
                      }
                    }}
                    style={{ fontSize: '12px', width: '100%' }}
                  />
                  {avatarUploading && <span style={{ fontSize: '12px', color: '#999' }}>上传中...</span>}
                </div>
              </div>
              {editModal.formData.avatar && (
                <input
                  type="text"
                  value={editModal.formData.avatar}
                  readOnly
                  style={{ width: '100%', padding: '4px 8px', border: '1px solid #eee', borderRadius: '4px', boxSizing: 'border-box', fontSize: '11px', color: '#999', marginTop: '4px' }}
                />
              )}
            </div>
          </div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>名称(中文)</label>
              <input
                type="text"
                maxLength={100}
                value={editModal.formData.name_zh}
                onChange={(e) => editModal.updateField('name_zh', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>名称(英文)</label>
              <input
                type="text"
                maxLength={100}
                value={editModal.formData.name_en}
                onChange={(e) => editModal.updateField('name_en', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>分类</label>
              <select
                value={editModal.formData.category}
                onChange={(e) => editModal.updateField('category', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box', background: 'white' }}
              >
                {CATEGORY_OPTIONS.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>城市</label>
              <input
                type="text"
                value={editModal.formData.location}
                onChange={(e) => editModal.updateField('location', e.target.value)}
                placeholder="如：London, Online"
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>用户等级</label>
              <select
                value={editModal.formData.user_level}
                onChange={(e) => editModal.updateField('user_level', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box', background: 'white' }}
              >
                <option value="normal">Normal</option>
                <option value="vip">VIP</option>
                <option value="super">Super</option>
              </select>
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>排序（数字越小越靠前）</label>
              <input
                type="number"
                value={editModal.formData.display_order}
                onChange={(e) => editModal.updateField('display_order', parseInt(e.target.value) || 0)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>

          {/* 简介 */}
          <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#333', borderBottom: '1px solid #eee', paddingBottom: '6px', marginTop: '4px' }}>简介</div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>中文简介</label>
            <textarea
              value={editModal.formData.bio}
              onChange={(e) => editModal.updateField('bio', e.target.value)}
              rows={2}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>英文简介</label>
            <textarea
              value={editModal.formData.bio_en}
              onChange={(e) => editModal.updateField('bio_en', e.target.value)}
              rows={2}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>简介(zh-Hant 备用)</label>
            <textarea
              value={editModal.formData.bio_zh}
              onChange={(e) => editModal.updateField('bio_zh', e.target.value)}
              rows={2}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>

          {/* 专业领域与技能 */}
          <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#333', borderBottom: '1px solid #eee', paddingBottom: '6px', marginTop: '4px' }}>专业领域与技能</div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>擅长领域（中文，逗号分隔）</label>
            <input
              type="text"
              value={editModal.formData.expertise_areas}
              onChange={(e) => editModal.updateField('expertise_areas', e.target.value)}
              placeholder="如：学术辅导, 论文指导, 数学"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>擅长领域（英文，逗号分隔）</label>
            <input
              type="text"
              value={editModal.formData.expertise_areas_en}
              onChange={(e) => editModal.updateField('expertise_areas_en', e.target.value)}
              placeholder="e.g. Academic Tutoring, Essay Guidance, Math"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>特色技能（中文，逗号分隔）</label>
            <input
              type="text"
              value={editModal.formData.featured_skills}
              onChange={(e) => editModal.updateField('featured_skills', e.target.value)}
              placeholder="如：快速响应, 耐心讲解"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>特色技能（英文，逗号分隔）</label>
            <input
              type="text"
              value={editModal.formData.featured_skills_en}
              onChange={(e) => editModal.updateField('featured_skills_en', e.target.value)}
              placeholder="e.g. Fast Response, Patient Explanation"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>

          {/* 成就与响应时间 */}
          <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#333', borderBottom: '1px solid #eee', paddingBottom: '6px', marginTop: '4px' }}>成就与响应时间</div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>成就徽章（中文，逗号分隔）</label>
            <input
              type="text"
              value={editModal.formData.achievements}
              onChange={(e) => editModal.updateField('achievements', e.target.value)}
              placeholder="如：五星好评, 百单达人"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>成就徽章（英文，逗号分隔）</label>
            <input
              type="text"
              value={editModal.formData.achievements_en}
              onChange={(e) => editModal.updateField('achievements_en', e.target.value)}
              placeholder="e.g. 5-Star Rating, 100+ Orders"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>响应时间（中文）</label>
              <input
                type="text"
                value={editModal.formData.response_time}
                onChange={(e) => editModal.updateField('response_time', e.target.value)}
                placeholder="如：通常 10 分钟内回复"
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>响应时间（英文）</label>
              <input
                type="text"
                value={editModal.formData.response_time_en}
                onChange={(e) => editModal.updateField('response_time_en', e.target.value)}
                placeholder="e.g. Usually within 10 min"
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>

          {/* 服务图片管理 */}
          {editModal.formData.services.length > 0 && (
            <>
              <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#333', borderBottom: '1px solid #eee', paddingBottom: '6px', marginTop: '4px' }}>服务图片</div>
              {editModal.formData.services.map((svc: any, svcIdx: number) => (
                <div key={svc.id} style={{ padding: '10px', background: '#fafafa', borderRadius: '6px', border: '1px solid #eee' }}>
                  <div style={{ fontWeight: '600', fontSize: '13px', marginBottom: '8px' }}>
                    {svc.service_name || `服务 #${svc.id}`}
                    <span style={{ fontWeight: 'normal', color: '#999', marginLeft: '8px', fontSize: '12px' }}>ID: {svc.id}</span>
                  </div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '8px' }}>
                    {(svc.images || []).map((imgUrl: string, imgIdx: number) => (
                      <div key={imgIdx} style={{ position: 'relative' }}>
                        <img
                          src={imgUrl}
                          alt={`服务图片 ${imgIdx + 1}`}
                          style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: '4px', border: '1px solid #ddd' }}
                        />
                        <button
                          onClick={async () => {
                            const newImages = [...(svc.images || [])];
                            newImages.splice(imgIdx, 1);
                            try {
                              await updateExpertServiceAdmin(editModal.formData.id, svc.id, { images: newImages });
                              const updatedServices = [...editModal.formData.services];
                              updatedServices[svcIdx] = { ...svc, images: newImages };
                              editModal.updateField('services', updatedServices);
                              message.success('图片已删除');
                            } catch (err: any) {
                              message.error(getErrorMessage(err));
                            }
                          }}
                          style={{
                            position: 'absolute', top: -6, right: -6,
                            width: 20, height: 20, borderRadius: '50%',
                            background: '#dc3545', color: 'white', border: 'none',
                            cursor: 'pointer', fontSize: '12px', lineHeight: '18px',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                          }}
                        >
                          ×
                        </button>
                      </div>
                    ))}
                  </div>
                  <input
                    type="file"
                    accept="image/*"
                    disabled={serviceImageUploading === svc.id}
                    onChange={async (e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      const expertId = editModal.formData.id;
                      if (!expertId) {
                        message.error('请先保存达人基本信息');
                        return;
                      }
                      setServiceImageUploading(svc.id);
                      try {
                        const url = await uploadImageWithCategory(file, 'service_image', expertId);
                        const newImages = [...(svc.images || []), url];
                        await updateExpertServiceAdmin(editModal.formData.id, svc.id, { images: newImages });
                        const updatedServices = [...editModal.formData.services];
                        updatedServices[svcIdx] = { ...svc, images: newImages };
                        editModal.updateField('services', updatedServices);
                        message.success('图片上传成功');
                      } catch (err: any) {
                        message.error(getErrorMessage(err));
                      } finally {
                        setServiceImageUploading(null);
                        e.target.value = '';
                      }
                    }}
                    style={{ fontSize: '12px' }}
                  />
                  {serviceImageUploading === svc.id && <span style={{ fontSize: '12px', color: '#999', marginLeft: '8px' }}>上传中...</span>}
                </div>
              ))}
            </>
          )}

          {/* 状态 + 团队属性 */}
          <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#333', borderBottom: '1px solid #eee', paddingBottom: '6px', marginTop: '4px' }}>状态与属性</div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>团队状态</label>
              <select
                value={editModal.formData.status}
                onChange={(e) => editModal.updateField('status', e.target.value as ExpertEditForm['status'])}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box', background: 'white' }}
              >
                {STATUS_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600', fontSize: '13px' }}>官方徽章 (badge slug)</label>
              <input
                type="text"
                value={editModal.formData.official_badge}
                onChange={(e) => editModal.updateField('official_badge', e.target.value)}
                placeholder="如 verified / partner"
                disabled={!editModal.formData.is_official}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box', background: editModal.formData.is_official ? 'white' : '#f5f5f5' }}
              />
            </div>
          </div>
          <div style={{ display: 'flex', gap: '24px', flexWrap: 'wrap' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input type="checkbox" checked={editModal.formData.is_official} onChange={(e) => editModal.updateField('is_official', e.target.checked)} />
              <span>官方团队</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input type="checkbox" checked={editModal.formData.is_featured} onChange={(e) => editModal.updateField('is_featured', e.target.checked)} />
              <span>精选 (单独 API)</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input type="checkbox" checked={editModal.formData.is_verified} onChange={(e) => editModal.updateField('is_verified', e.target.checked)} />
              <span>已认证</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input type="checkbox" checked={editModal.formData.allow_applications} onChange={(e) => editModal.updateField('allow_applications', e.target.checked)} />
              <span>允许加入申请</span>
            </label>
          </div>
        </div>
      </Modal>

      {/* 服务编辑弹窗 */}
      <Modal
        title="编辑服务"
        open={serviceEditModal.isOpen}
        onCancel={serviceEditModal.close}
        onOk={serviceEditModal.handleSubmit}
        confirmLoading={serviceEditModal.loading}
        okText="保存"
        cancelText="取消"
        width={500}
      >
        <div style={{ padding: '16px 0', display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <div><strong>达人：</strong>{serviceEditModal.formData.expert_name || serviceEditModal.formData.expert_id}</div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>服务名称</label>
            <input
              value={serviceEditModal.formData.service_name}
              onChange={(e) => serviceEditModal.updateField('service_name', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>描述</label>
            <textarea
              value={serviceEditModal.formData.description}
              onChange={(e) => serviceEditModal.updateField('description', e.target.value)}
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
          <div style={{ display: 'flex', gap: '12px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>价格</label>
              <input
                type="number"
                step="0.01"
                value={serviceEditModal.formData.base_price}
                onChange={(e) => serviceEditModal.updateField('base_price', parseFloat(e.target.value) || 0)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>币种</label>
              <select
                value={serviceEditModal.formData.currency}
                onChange={(e) => serviceEditModal.updateField('currency', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              >
                <option value="GBP">GBP</option>
                <option value="CNY">CNY</option>
                <option value="USD">USD</option>
              </select>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '12px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>状态</label>
              <select
                value={serviceEditModal.formData.status}
                onChange={(e) => serviceEditModal.updateField('status', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              >
                <option value="pending">待审核</option>
                <option value="active">已上架</option>
                <option value="rejected">已拒绝</option>
                <option value="inactive">已下架</option>
              </select>
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>排序</label>
              <input
                type="number"
                value={serviceEditModal.formData.display_order}
                onChange={(e) => serviceEditModal.updateField('display_order', parseInt(e.target.value) || 0)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>
        </div>
      </Modal>

      {/* 活动编辑弹窗 */}
      <Modal
        title="编辑活动"
        open={activityEditModal.isOpen}
        onCancel={activityEditModal.close}
        onOk={activityEditModal.handleSubmit}
        confirmLoading={activityEditModal.loading}
        okText="保存"
        cancelText="取消"
        width={500}
      >
        <div style={{ padding: '16px 0', display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <div><strong>达人：</strong>{activityEditModal.formData.expert_name || activityEditModal.formData.expert_id}</div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>活动标题</label>
            <input
              value={activityEditModal.formData.title}
              onChange={(e) => activityEditModal.updateField('title', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>描述</label>
            <textarea
              value={activityEditModal.formData.description}
              onChange={(e) => activityEditModal.updateField('description', e.target.value)}
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>地点</label>
            <input
              value={activityEditModal.formData.location}
              onChange={(e) => activityEditModal.updateField('location', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div style={{ display: 'flex', gap: '12px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>状态</label>
              <select
                value={activityEditModal.formData.status}
                onChange={(e) => activityEditModal.updateField('status', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              >
                <option value="pending_review">待审核</option>
                <option value="open">开放</option>
                <option value="rejected">已拒绝</option>
                <option value="closed">已关闭</option>
                <option value="cancelled">已取消</option>
                <option value="completed">已完成</option>
              </select>
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>最大人数</label>
              <input
                type="number"
                min={1}
                value={activityEditModal.formData.max_participants}
                onChange={(e) => activityEditModal.updateField('max_participants', parseInt(e.target.value) || 1)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>
        </div>
      </Modal>

      {/* 详情模态框 */}
      <Modal
        title="达人详情"
        open={!!detailExpert}
        onCancel={() => setDetailExpert(null)}
        footer={null}
        width={650}
      >
        {detailExpert && (
          <div style={{ padding: '10px 0' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
              {detailExpert.avatar ? (
                <img src={detailExpert.avatar} alt="头像" style={{ width: 56, height: 56, borderRadius: '50%', objectFit: 'cover', border: '1px solid #ddd' }} />
              ) : (
                <div style={{ width: 56, height: 56, borderRadius: '50%', background: '#e0e0e0', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '16px', color: '#999' }}>?</div>
              )}
              <div>
                <div style={{ fontWeight: 'bold', fontSize: '16px' }}>{detailExpert.name || '-'}</div>
                <div style={{ fontSize: '12px', color: '#999', fontFamily: 'monospace' }}>{detailExpert.id}</div>
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px 24px' }}>
              <div><strong>评分：</strong>{detailExpert.rating != null ? Number(detailExpert.rating).toFixed(1) : '-'}</div>
              <div><strong>完成任务：</strong>{detailExpert.completed_tasks ?? 0}</div>
              <div><strong>团队服务数：</strong>{detailExpert.total_services ?? 0}</div>
              <div><strong>完成率：</strong>{detailExpert.completion_rate ? `${(detailExpert.completion_rate * 100).toFixed(0)}%` : '-'}</div>
              <div><strong>成员数：</strong>{detailExpert.member_count ?? 1}</div>
              <div><strong>城市：</strong>{detailExpert.location || '-'}</div>
              <div><strong>分类：</strong>{detailExpert.category || '-'}</div>
              <div><strong>排序：</strong>{detailExpert.display_order ?? 0}</div>
              <div><strong>响应时间：</strong>{detailExpert.response_time || '-'}</div>
              <div><strong>等级：</strong>{detailExpert.user_level || '-'}</div>
            </div>
            <div style={{ marginTop: '12px' }}>
              <strong>擅长领域：</strong>
              <div style={{ marginTop: '4px', display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                {(detailExpert.expertise_areas || []).map((a: string, i: number) => (
                  <Tag key={i} color="blue">{a}</Tag>
                ))}
                {!(detailExpert.expertise_areas || []).length && <span style={{ color: '#999' }}>-</span>}
              </div>
            </div>
            <div style={{ marginTop: '12px' }}>
              <strong>技能：</strong>
              <div style={{ marginTop: '4px', display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                {(detailExpert.featured_skills || []).map((s: string, i: number) => (
                  <Tag key={i} color="green">{s}</Tag>
                ))}
                {!(detailExpert.featured_skills || []).length && <span style={{ color: '#999' }}>-</span>}
              </div>
            </div>
            <div style={{ marginTop: '12px' }}>
              <strong>简介：</strong>
              <p style={{ marginTop: '4px', color: '#555' }}>{detailExpert.bio || '-'}</p>
            </div>
            <div style={{ marginTop: '8px', display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
              <StatusBadge text={detailExpert.status === 'active' ? '活跃' : (detailExpert.status || '-')} variant={detailExpert.status === 'active' ? 'success' : 'default'} />
              <StatusBadge text={detailExpert.is_featured ? '精选' : '非精选'} variant={detailExpert.is_featured ? 'info' : 'default'} />
              <StatusBadge text={detailExpert.is_verified ? '已认证' : '未认证'} variant={detailExpert.is_verified ? 'success' : 'default'} />
              {detailExpert.is_official && <StatusBadge text="官方" variant="info" />}
            </div>
            <div style={{ marginTop: '12px', color: '#999', fontSize: '12px' }}>
              创建时间：{detailExpert.created_at ? new Date(detailExpert.created_at).toLocaleString('zh-CN') : '-'}
              {' | '}
              更新时间：{detailExpert.updated_at ? new Date(detailExpert.updated_at).toLocaleString('zh-CN') : '-'}
            </div>
          </div>
        )}
      </Modal>

      {/* 新建达人团队 Modal — 两步:1.填基本信息 2.可选上传头像 */}
      <Modal
        title={createdExpertId ? `达人团队已创建 (ID: ${createdExpertId})` : '新建达人团队'}
        open={createModalOpen}
        onCancel={closeCreateModal}
        onOk={createdExpertId ? closeCreateModal : handleCreateSubmit}
        confirmLoading={createSubmitting}
        okText={createdExpertId ? '完成' : '创建'}
        cancelText="取消"
        cancelButtonProps={{ style: { display: createdExpertId ? 'none' : undefined } }}
        width={600}
        maskClosable={false}
      >
        {!createdExpertId ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label style={{ display: 'block', marginBottom: 4, fontWeight: 600, fontSize: 13 }}>
                Owner 用户 <span style={{ color: 'red' }}>*</span>
              </label>
              <Select
                showSearch
                allowClear
                placeholder="按用户名/ID/邮箱搜索,选中后此人将成为团队 owner"
                value={createForm.owner_user_id || undefined}
                filterOption={false}
                onSearch={handleOwnerSearch}
                onChange={(val) => setCreateForm({ ...createForm, owner_user_id: val || '' })}
                onClear={() => setCreateForm({ ...createForm, owner_user_id: '' })}
                notFoundContent={ownerSearchLoading ? <Spin size="small" /> : '未找到匹配用户'}
                options={ownerOptions}
                style={{ width: '100%' }}
              />
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: 4, fontWeight: 600, fontSize: 13 }}>
                团队名称 <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="text"
                maxLength={100}
                value={createForm.name}
                onChange={(e) => setCreateForm({ ...createForm, name: e.target.value })}
                style={{ width: '100%', padding: 8, border: '1px solid #ddd', borderRadius: 4, boxSizing: 'border-box' }}
              />
            </div>

            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 600, fontSize: 13 }}>名称(中文)</label>
                <input
                  type="text"
                  maxLength={100}
                  value={createForm.name_zh}
                  onChange={(e) => setCreateForm({ ...createForm, name_zh: e.target.value })}
                  style={{ width: '100%', padding: 8, border: '1px solid #ddd', borderRadius: 4, boxSizing: 'border-box' }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 600, fontSize: 13 }}>名称(英文)</label>
                <input
                  type="text"
                  maxLength={100}
                  value={createForm.name_en}
                  onChange={(e) => setCreateForm({ ...createForm, name_en: e.target.value })}
                  style={{ width: '100%', padding: 8, border: '1px solid #ddd', borderRadius: 4, boxSizing: 'border-box' }}
                />
              </div>
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: 4, fontWeight: 600, fontSize: 13 }}>简介</label>
              <textarea
                rows={3}
                value={createForm.bio}
                onChange={(e) => setCreateForm({ ...createForm, bio: e.target.value })}
                style={{ width: '100%', padding: 8, border: '1px solid #ddd', borderRadius: 4, boxSizing: 'border-box', resize: 'vertical' }}
              />
            </div>

            <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', paddingTop: 4 }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 13 }}>
                <input
                  type="checkbox"
                  checked={createForm.is_official}
                  onChange={(e) => setCreateForm({ ...createForm, is_official: e.target.checked })}
                />
                官方团队
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 13 }}>
                <input
                  type="checkbox"
                  checked={createForm.allow_applications}
                  onChange={(e) => setCreateForm({ ...createForm, allow_applications: e.target.checked })}
                />
                允许其他用户申请加入
              </label>
            </div>

            {createForm.is_official && (
              <div>
                <label style={{ display: 'block', marginBottom: 4, fontWeight: 600, fontSize: 13 }}>官方徽章标识</label>
                <input
                  type="text"
                  maxLength={50}
                  placeholder="可选,例如 verified, partner"
                  value={createForm.official_badge}
                  onChange={(e) => setCreateForm({ ...createForm, official_badge: e.target.value })}
                  style={{ width: '100%', padding: 8, border: '1px solid #ddd', borderRadius: 4, boxSizing: 'border-box' }}
                />
              </div>
            )}
          </div>
        ) : (
          // ===== 第二步:可选上传头像 =====
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16, alignItems: 'center', padding: '8px 0' }}>
            <div style={{ fontSize: 13, color: '#666', textAlign: 'center' }}>
              团队已创建成功。可选:为团队上传一张头像(留空使用默认头像)。
            </div>
            <div
              style={{
                width: 96,
                height: 96,
                borderRadius: '50%',
                border: '2px dashed #ddd',
                background: '#fafafa',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                overflow: 'hidden',
              }}
            >
              {createdExpertAvatar ? (
                <img
                  src={createdExpertAvatar}
                  alt="头像"
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
              ) : (
                <span style={{ fontSize: 32, color: '#ccc' }}>?</span>
              )}
            </div>
            <label
              style={{
                padding: '8px 16px',
                background: createdAvatarUploading ? '#aaa' : '#007bff',
                color: 'white',
                borderRadius: 5,
                cursor: createdAvatarUploading ? 'not-allowed' : 'pointer',
                fontSize: 14,
              }}
            >
              {createdAvatarUploading ? '上传中...' : (createdExpertAvatar ? '重新上传' : '选择图片')}
              <input
                type="file"
                accept="image/*"
                disabled={createdAvatarUploading}
                style={{ display: 'none' }}
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) {
                    void handleCreatedAvatarUpload(file);
                  }
                  e.target.value = '';
                }}
              />
            </label>
            <div style={{ fontSize: 12, color: '#999' }}>
              点击"完成"关闭对话框,或继续在达人列表中编辑团队信息。
            </div>
          </div>
        )}
      </Modal>

    </div>
  );
};

export default ExpertManagement;
