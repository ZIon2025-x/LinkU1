import React, { useState, useCallback, useEffect } from 'react';
import { message, Modal, Tag } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import {
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
  hideForumPost,
  unhideForumPost,
  restoreForumPost,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type SubTab = 'categories' | 'requests' | 'posts';

interface Category {
  id: number;
  name: string;
  name_en?: string;
  description?: string;
  description_en?: string;
  icon?: string;
  sort_order: number;
  is_visible: boolean;
  is_admin_only?: boolean;
  type?: string;
  country?: string;
  university_code?: string;
  post_count?: number;
  created_at?: string;
  updated_at?: string;
}

interface CategoryForm {
  id?: number;
  name: string;
  description: string;
  icon: string;
  sort_order: number;
  is_visible: boolean;
  is_admin_only: boolean;
  type: 'general' | 'root' | 'university';
}

const initialForm: CategoryForm = {
  name: '',
  description: '',
  icon: '',
  sort_order: 0,
  is_visible: true,
  is_admin_only: false,
  type: 'general',
};

const TYPE_LABELS: Record<string, string> = {
  general: '通用',
  root: '地区',
  university: '学校',
};

interface ForumPostListItem {
  id: number;
  title: string;
  content_preview?: string;
  category: { id: number; name: string };
  author?: { name?: string; id?: string };
  view_count: number;
  reply_count: number;
  like_count: number;
  is_pinned: boolean;
  is_featured: boolean;
  is_locked: boolean;
  is_visible: boolean;
  is_deleted: boolean;
  created_at?: string;
  last_reply_at?: string;
}

interface PostForm {
  category_id: number | '';
  title: string;
  content: string;
}

const initialPostForm: PostForm = { category_id: '', title: '', content: '' };

const ForumManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('categories');
  const [categoryOptions, setCategoryOptions] = useState<{ id: number; name: string }[]>([]);

  // ==================== 分类列表 ====================
  const fetchCategories = useCallback(async () => {
    const response = await getForumCategories();
    const data = response.categories || response.items || [];
    return { data, total: data.length };
  }, []);

  const table = useAdminTable<Category>({
    fetchData: fetchCategories,
    initialPageSize: 100,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const modal = useModalForm<CategoryForm>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (!values.name) {
        message.warning('请填写分类名称');
        throw new Error('分类名称不能为空');
      }
      const payload: any = {
        name: values.name,
        description: values.description || undefined,
        icon: values.icon || undefined,
        sort_order: values.sort_order,
        is_visible: values.is_visible,
        is_admin_only: values.is_admin_only,
      };
      if (!isEdit) {
        payload.type = values.type;
      }
      if (isEdit && values.id) {
        await updateForumCategory(values.id, payload);
        message.success('板块更新成功');
      } else {
        await createForumCategory(payload);
        message.success('板块创建成功');
      }
      table.refresh();
    },
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const handleEdit = (category: Category) => {
    modal.open({
      id: category.id,
      name: category.name,
      description: category.description || '',
      icon: category.icon || '',
      sort_order: category.sort_order,
      is_visible: category.is_visible,
      is_admin_only: category.is_admin_only || false,
      type: (category.type as CategoryForm['type']) || 'general',
    });
  };

  const handleDelete = (id: number, name: string) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除板块「${name}」吗？删除后该板块下的帖子将无法访问。`,
      okText: '确定删除',
      cancelText: '取消',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await deleteForumCategory(id);
          message.success('板块已删除');
          table.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  // ==================== 板块申请 ====================
  const fetchRequests = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getCategoryRequests('pending', page, pageSize);
    return {
      data: response.requests || response.items || [],
      total: response.total || 0,
    };
  }, []);

  const requestsTable = useAdminTable<any>({
    fetchData: fetchRequests,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  // ==================== 帖子管理 ====================
  const fetchPosts = useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; filters?: Record<string, any> }) => {
    const f = filters || {};
    const response = await getForumPosts({
      page,
      page_size: pageSize,
      category_id: f.category_id != null && f.category_id !== '' ? Number(f.category_id) : undefined,
      q: f.q || undefined,
      sort: (f.sort as 'latest' | 'last_reply' | 'hot') || 'last_reply',
      is_deleted: f.is_deleted === true || f.is_deleted === false ? f.is_deleted : undefined,
      is_visible: f.is_visible === true || f.is_visible === false ? f.is_visible : undefined,
    });
    return {
      data: response.posts || [],
      total: response.total ?? 0,
    };
  }, []);

  const postsTable = useAdminTable<ForumPostListItem>({
    fetchData: fetchPosts,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'posts',
  });

  useEffect(() => {
    if (subTab === 'posts' && categoryOptions.length === 0) {
      getForumCategories().then((res) => {
        const list = res.categories || res.items || [];
        setCategoryOptions(list.map((c: Category) => ({ id: c.id, name: c.name })));
      }).catch(() => {});
    }
  }, [subTab]);

  const postModal = useModalForm<PostForm>({
    initialValues: initialPostForm,
    onSubmit: async (values) => {
      if (!values.title?.trim()) {
        message.warning('请填写标题');
        throw new Error('validation');
      }
      if (!values.content?.trim()) {
        message.warning('请填写内容');
        throw new Error('validation');
      }
      if (values.category_id === '' || values.category_id == null) {
        message.warning('请选择板块');
        throw new Error('validation');
      }
      await createForumPost({
        title: values.title.trim(),
        content: values.content.trim(),
        category_id: Number(values.category_id),
      });
      message.success('帖子已发布');
      postModal.close();
      postsTable.refresh();
    },
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const postEditModal = useModalForm<PostForm & { id?: number }>({
    initialValues: { ...initialPostForm, id: undefined },
    onSubmit: async (values) => {
      if (!values.id) return;
      if (!values.title?.trim()) {
        message.warning('请填写标题');
        throw new Error('validation');
      }
      if (!values.content?.trim()) {
        message.warning('请填写内容');
        throw new Error('validation');
      }
      if (values.category_id === '' || values.category_id == null) {
        message.warning('请选择板块');
        throw new Error('validation');
      }
      await updateForumPost(values.id, {
        title: values.title.trim(),
        content: values.content.trim(),
        category_id: Number(values.category_id),
      });
      message.success('帖子已更新');
      postEditModal.close();
      postsTable.refresh();
    },
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const handleEditPost = (record: ForumPostListItem) => {
    getForumPost(record.id).then((post: any) => {
      postEditModal.open({
        id: record.id,
        category_id: post.category?.id ?? record.category?.id ?? '',
        title: post.title || record.title,
        content: post.content || record.content_preview || '',
      });
    }).catch((err) => message.error(getErrorMessage(err)));
  };

  const handlePostAction = (record: ForumPostListItem, action: string) => {
    const actions: Record<string, () => Promise<void>> = {
      pin: () => pinForumPost(record.id),
      unpin: () => unpinForumPost(record.id),
      feature: () => featureForumPost(record.id),
      unfeature: () => unfeatureForumPost(record.id),
      lock: () => lockForumPost(record.id),
      unlock: () => unlockForumPost(record.id),
      hide: () => hideForumPost(record.id),
      unhide: () => unhideForumPost(record.id),
      restore: () => restoreForumPost(record.id),
      delete: () => deleteForumPost(record.id),
    };
    const fn = actions[action];
    if (!fn) return;
    const labels: Record<string, string> = {
      pin: '置顶', unpin: '取消置顶', feature: '加精', unfeature: '取消加精',
      lock: '锁定', unlock: '解锁', hide: '隐藏', unhide: '恢复显示', restore: '恢复', delete: '删除',
    };
    Modal.confirm({
      title: labels[action],
      content: `确定要${labels[action]}该帖子吗？`,
      okText: '确定',
      cancelText: '取消',
      okButtonProps: action === 'delete' ? { danger: true } : undefined,
      onOk: async () => {
        await fn();
        message.success('操作成功');
        postsTable.refresh();
      },
    }).catch(() => {});
  };

  const handleDeletePost = (record: ForumPostListItem) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除该帖子吗？删除后不可恢复。',
      okText: '确定删除',
      cancelText: '取消',
      okButtonProps: { danger: true },
      onOk: async () => {
        await deleteForumPost(record.id);
        message.success('已删除');
        postsTable.refresh();
      },
    }).catch(() => {});
  };

  const handleReviewRequest = (requestId: number, action: 'approve' | 'reject') => {
    const title = action === 'approve' ? '批准板块申请' : '拒绝板块申请';
    Modal.confirm({
      title,
      content: `确定要${action === 'approve' ? '批准' : '拒绝'}这个板块申请吗？`,
      okText: '确定',
      cancelText: '取消',
      okButtonProps: action === 'reject' ? { danger: true } : undefined,
      onOk: async () => {
        try {
          await reviewCategoryRequest(requestId, action);
          message.success(action === 'approve' ? '已批准' : '已拒绝');
          requestsTable.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      },
    });
  };

  // ==================== 分类列表列定义 ====================
  const columns: Column<Category>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 60,
    },
    {
      key: 'icon',
      title: '',
      width: 40,
      render: (_, record) => record.icon || '',
    },
    {
      key: 'name',
      title: '名称',
      width: 180,
      render: (_, record) => (
        <div>
          <strong>{record.name}</strong>
          {record.name_en && <div style={{ fontSize: '11px', color: '#999' }}>{record.name_en}</div>}
        </div>
      ),
    },
    {
      key: 'type',
      title: '类型',
      width: 80,
      render: (_, record) => {
        const t = record.type || 'general';
        const color = t === 'university' ? 'blue' : t === 'root' ? 'orange' : 'default';
        return <Tag color={color}>{TYPE_LABELS[t] || t}</Tag>;
      },
    },
    {
      key: 'description',
      title: '描述',
      width: 200,
      render: (_, record) => (
        <span style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {record.description || '-'}
        </span>
      ),
    },
    {
      key: 'post_count',
      title: '帖子数',
      dataIndex: 'post_count',
      width: 80,
      render: (value) => value || 0,
    },
    {
      key: 'sort_order',
      title: '排序',
      dataIndex: 'sort_order',
      width: 60,
    },
    {
      key: 'is_visible',
      title: '可见',
      width: 70,
      render: (_, record) => (
        <StatusBadge
          text={record.is_visible ? '可见' : '隐藏'}
          variant={record.is_visible ? 'success' : 'danger'}
        />
      ),
    },
    {
      key: 'is_admin_only',
      title: '仅管理员',
      width: 80,
      render: (_, record) => record.is_admin_only ? (
        <StatusBadge text="是" variant="warning" />
      ) : '-',
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
  const requestColumns: Column<any>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    {
      key: 'name',
      title: '申请板块名称',
      width: 180,
      render: (_, record) => <strong>{record.name || record.category_name || '-'}</strong>,
    },
    {
      key: 'reason',
      title: '申请理由',
      width: 250,
      render: (_, record) => (
        <span style={{ maxWidth: 250, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {record.reason || record.description || '-'}
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
      width: 130,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => handleReviewRequest(record.id, 'approve')}
            style={{ padding: '3px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => handleReviewRequest(record.id, 'reject')}
            style={{ padding: '3px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            拒绝
          </button>
        </div>
      ),
    },
  ];

  // 帖子列表列
  const postColumns: Column<ForumPostListItem>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    {
      key: 'category',
      title: '板块',
      width: 100,
      render: (_, r) => r.category?.name ?? '-',
    },
    {
      key: 'title',
      title: '标题',
      width: 220,
      render: (_, r) => (
        <span style={{ maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }} title={r.title}>
          {r.title || '-'}
        </span>
      ),
    },
    {
      key: 'author',
      title: '作者',
      width: 100,
      render: (_, r) => r.author?.name ?? '管理员',
    },
    { key: 'reply_count', title: '回复', dataIndex: 'reply_count', width: 60, render: (v) => v ?? 0 },
    { key: 'like_count', title: '点赞', dataIndex: 'like_count', width: 60, render: (v) => v ?? 0 },
    {
      key: 'flags',
      title: '状态',
      width: 120,
      render: (_, r) => (
        <span style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
          {r.is_pinned && <Tag color="orange">置顶</Tag>}
          {r.is_featured && <Tag color="blue">精</Tag>}
          {r.is_locked && <Tag color="default">锁</Tag>}
          {r.is_deleted ? <Tag color="red">已删</Tag> : (r.is_visible ? <Tag color="green">可见</Tag> : <Tag color="default">隐藏</Tag>)}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '发布时间',
      width: 155,
      render: (_, r) => (r.created_at ? new Date(r.created_at).toLocaleString('zh-CN') : '-'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 260,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, justifyContent: 'center' }}>
          <button type="button" onClick={() => handleEditPost(record)} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer' }}>编辑</button>
          {record.is_pinned ? (
            <button type="button" onClick={() => handlePostAction(record, 'unpin')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #6c757d', background: 'white', color: '#6c757d', borderRadius: '4px', cursor: 'pointer' }}>取消置顶</button>
          ) : (
            <button type="button" onClick={() => handlePostAction(record, 'pin')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #ffc107', background: 'white', color: '#856404', borderRadius: '4px', cursor: 'pointer' }}>置顶</button>
          )}
          {record.is_featured ? (
            <button type="button" onClick={() => handlePostAction(record, 'unfeature')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #6c757d', background: 'white', color: '#6c757d', borderRadius: '4px', cursor: 'pointer' }}>取消加精</button>
          ) : (
            <button type="button" onClick={() => handlePostAction(record, 'feature')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer' }}>加精</button>
          )}
          {record.is_locked ? (
            <button type="button" onClick={() => handlePostAction(record, 'unlock')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #28a745', background: 'white', color: '#28a745', borderRadius: '4px', cursor: 'pointer' }}>解锁</button>
          ) : (
            <button type="button" onClick={() => handlePostAction(record, 'lock')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #6c757d', background: 'white', color: '#6c757d', borderRadius: '4px', cursor: 'pointer' }}>锁定</button>
          )}
          {record.is_deleted ? (
            <button type="button" onClick={() => handlePostAction(record, 'restore')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #28a745', background: 'white', color: '#28a745', borderRadius: '4px', cursor: 'pointer' }}>恢复</button>
          ) : record.is_visible ? (
            <button type="button" onClick={() => handlePostAction(record, 'hide')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #ffc107', background: 'white', color: '#856404', borderRadius: '4px', cursor: 'pointer' }}>隐藏</button>
          ) : (
            <button type="button" onClick={() => handlePostAction(record, 'unhide')} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #28a745', background: 'white', color: '#28a745', borderRadius: '4px', cursor: 'pointer' }}>显示</button>
          )}
          <button type="button" onClick={() => handleDeletePost(record)} style={{ padding: '2px 6px', fontSize: '12px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer' }}>删除</button>
        </div>
      ),
    },
  ];

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>论坛管理</h2>

      {/* 子标签页 */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        <button
          onClick={() => setSubTab('categories')}
          style={{
            padding: '10px 20px', border: 'none', borderRadius: '5px', cursor: 'pointer', fontSize: '14px', fontWeight: '500',
            background: subTab === 'categories' ? '#007bff' : '#f0f0f0',
            color: subTab === 'categories' ? 'white' : 'black',
          }}
        >
          板块管理
        </button>
        <button
          onClick={() => setSubTab('requests')}
          style={{
            padding: '10px 20px', border: 'none', borderRadius: '5px', cursor: 'pointer', fontSize: '14px', fontWeight: '500',
            background: subTab === 'requests' ? '#007bff' : '#f0f0f0',
            color: subTab === 'requests' ? 'white' : 'black',
          }}
        >
          板块申请
        </button>
        <button
          onClick={() => setSubTab('posts')}
          style={{
            padding: '10px 20px', border: 'none', borderRadius: '5px', cursor: 'pointer', fontSize: '14px', fontWeight: '500',
            background: subTab === 'posts' ? '#007bff' : '#f0f0f0',
            color: subTab === 'posts' ? 'white' : 'black',
          }}
        >
          帖子管理
        </button>
      </div>

      {/* ==================== 板块管理 ==================== */}
      {subTab === 'categories' && (
        <>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '15px' }}>
            <button
              onClick={() => modal.open(initialForm, true)}
              style={{ padding: '8px 18px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}
            >
              创建板块
            </button>
          </div>

          <AdminTable
            columns={columns}
            data={table.data}
            loading={table.loading}
            refreshing={table.fetching}
            rowKey="id"
            emptyText="暂无板块"
          />
          {table.total > table.pageSize && (
            <AdminPagination
              currentPage={table.currentPage}
              totalPages={table.totalPages}
              total={table.total}
              pageSize={table.pageSize}
              onPageChange={table.setCurrentPage}
              onPageSizeChange={table.setPageSize}
            />
          )}
        </>
      )}

      {/* ==================== 板块申请 ==================== */}
      {subTab === 'requests' && (
        <>
          <AdminTable
            columns={requestColumns}
            data={requestsTable.data}
            loading={requestsTable.loading}
            refreshing={requestsTable.fetching}
            rowKey="id"
            emptyText="暂无待审核板块申请"
          />
          <AdminPagination
            currentPage={requestsTable.currentPage}
            totalPages={requestsTable.totalPages}
            total={requestsTable.total}
            pageSize={requestsTable.pageSize}
            onPageChange={requestsTable.setCurrentPage}
            onPageSizeChange={requestsTable.setPageSize}
          />
        </>
      )}

      {/* ==================== 帖子管理 ==================== */}
      {subTab === 'posts' && (
        <>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px', marginBottom: '16px', alignItems: 'center' }}>
            <select
              value={postsTable.filters?.category_id ?? ''}
              onChange={(e) => postsTable.setFilters({ ...postsTable.filters, category_id: e.target.value === '' ? undefined : e.target.value })}
              style={{ padding: '6px 10px', minWidth: 120, border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="">全部板块</option>
              {categoryOptions.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
            <input
              type="text"
              placeholder="搜索标题/内容"
              value={postsTable.filters?.q ?? ''}
              onChange={(e) => postsTable.setFilters({ ...postsTable.filters, q: e.target.value })}
              onKeyDown={(e) => e.key === 'Enter' && postsTable.refresh()}
              style={{ padding: '6px 10px', width: 160, border: '1px solid #ddd', borderRadius: '4px' }}
            />
            <select
              value={postsTable.filters?.sort ?? 'last_reply'}
              onChange={(e) => postsTable.setFilters({ ...postsTable.filters, sort: e.target.value })}
              style={{ padding: '6px 10px', minWidth: 100, border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="latest">最新发布</option>
              <option value="last_reply">最后回复</option>
              <option value="hot">热度</option>
            </select>
            <select
              value={postsTable.filters?.is_deleted === undefined ? '' : postsTable.filters?.is_deleted ? 'deleted' : 'active'}
              onChange={(e) => {
                const v = e.target.value;
                postsTable.setFilters({ ...postsTable.filters, is_deleted: v === '' ? undefined : v === 'deleted' });
              }}
              style={{ padding: '6px 10px', minWidth: 100, border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="">全部</option>
              <option value="active">未删除</option>
              <option value="deleted">已删除</option>
            </select>
            <select
              value={postsTable.filters?.is_visible === undefined ? '' : (postsTable.filters?.is_visible ? 'visible' : 'hidden')}
              onChange={(e) => {
                const v = e.target.value;
                postsTable.setFilters({ ...postsTable.filters, is_visible: v === '' ? undefined : v === 'visible' });
              }}
              style={{ padding: '6px 10px', minWidth: 90, border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="">全部</option>
              <option value="visible">可见</option>
              <option value="hidden">隐藏</option>
            </select>
            <button type="button" onClick={() => postsTable.refresh()} style={{ padding: '6px 14px', border: '1px solid #007bff', background: '#007bff', color: 'white', borderRadius: '4px', cursor: 'pointer' }}>搜索</button>
            <button
              type="button"
              onClick={() => { postModal.open(initialPostForm, true); }}
              style={{ padding: '8px 18px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontWeight: 500 }}
            >
              发布帖子
            </button>
          </div>
          <AdminTable
            columns={postColumns}
            data={postsTable.data}
            loading={postsTable.loading}
            refreshing={postsTable.fetching}
            rowKey="id"
            emptyText="暂无帖子"
          />
          {postsTable.total > postsTable.pageSize && (
            <AdminPagination
              currentPage={postsTable.currentPage}
              totalPages={postsTable.totalPages}
              total={postsTable.total}
              pageSize={postsTable.pageSize}
              onPageChange={postsTable.setCurrentPage}
              onPageSizeChange={postsTable.setPageSize}
            />
          )}
        </>
      )}

      {/* 创建/编辑板块 */}
      <Modal
        title={modal.isEdit ? '编辑板块' : '创建板块'}
        open={modal.isOpen}
        onCancel={modal.close}
        onOk={modal.handleSubmit}
        confirmLoading={modal.loading}
        okText={modal.isEdit ? '更新' : '创建'}
        cancelText="取消"
        width={520}
      >
        <div style={{ padding: '20px 0', display: 'flex', flexDirection: 'column', gap: '15px' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              板块名称 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={modal.formData.name}
              onChange={(e) => modal.updateField('name', e.target.value)}
              placeholder="请输入板块名称"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>描述</label>
            <textarea
              value={modal.formData.description}
              onChange={(e) => modal.updateField('description', e.target.value)}
              placeholder="板块描述（可选）"
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>图标（emoji）</label>
              <input
                type="text"
                value={modal.formData.icon}
                onChange={(e) => modal.updateField('icon', e.target.value)}
                placeholder="如 💬"
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>排序</label>
              <input
                type="number"
                value={modal.formData.sort_order}
                onChange={(e) => modal.updateField('sort_order', parseInt(e.target.value) || 0)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>
          {!modal.isEdit && (
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>类型</label>
              <select
                value={modal.formData.type}
                onChange={(e) => modal.updateField('type', e.target.value as CategoryForm['type'])}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              >
                <option value="general">通用</option>
                <option value="root">地区</option>
                <option value="university">学校</option>
              </select>
            </div>
          )}
          <div style={{ display: 'flex', gap: '20px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={modal.formData.is_visible}
                onChange={(e) => modal.updateField('is_visible', e.target.checked)}
              />
              <span>可见</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={modal.formData.is_admin_only}
                onChange={(e) => modal.updateField('is_admin_only', e.target.checked)}
              />
              <span>仅管理员可见</span>
            </label>
          </div>
        </div>
      </Modal>

      {/* 发布帖子 */}
      <Modal
        title="发布帖子"
        open={postModal.isOpen}
        onCancel={postModal.close}
        onOk={postModal.handleSubmit}
        confirmLoading={postModal.loading}
        okText="发布"
        cancelText="取消"
        width={600}
      >
        <div style={{ padding: '16px 0', display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>板块 <span style={{ color: 'red' }}>*</span></label>
            <select
              value={postModal.formData.category_id === '' ? '' : String(postModal.formData.category_id)}
              onChange={(e) => postModal.updateField('category_id', e.target.value === '' ? '' : Number(e.target.value))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            >
              <option value="">请选择板块</option>
              {categoryOptions.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>标题 <span style={{ color: 'red' }}>*</span></label>
            <input
              type="text"
              value={postModal.formData.title}
              onChange={(e) => postModal.updateField('title', e.target.value)}
              placeholder="请输入标题"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>内容 <span style={{ color: 'red' }}>*</span></label>
            <textarea
              value={postModal.formData.content}
              onChange={(e) => postModal.updateField('content', e.target.value)}
              placeholder="请输入内容"
              rows={8}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
        </div>
      </Modal>

      {/* 编辑帖子 */}
      <Modal
        title="编辑帖子"
        open={postEditModal.isOpen}
        onCancel={postEditModal.close}
        onOk={postEditModal.handleSubmit}
        confirmLoading={postEditModal.loading}
        okText="保存"
        cancelText="取消"
        width={600}
      >
        <div style={{ padding: '16px 0', display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>板块 <span style={{ color: 'red' }}>*</span></label>
            <select
              value={postEditModal.formData.category_id === '' ? '' : String(postEditModal.formData.category_id)}
              onChange={(e) => postEditModal.updateField('category_id', e.target.value === '' ? '' : Number(e.target.value))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            >
              <option value="">请选择板块</option>
              {categoryOptions.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>标题 <span style={{ color: 'red' }}>*</span></label>
            <input
              type="text"
              value={postEditModal.formData.title}
              onChange={(e) => postEditModal.updateField('title', e.target.value)}
              placeholder="请输入标题"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>内容 <span style={{ color: 'red' }}>*</span></label>
            <textarea
              value={postEditModal.formData.content}
              onChange={(e) => postEditModal.updateField('content', e.target.value)}
              placeholder="请输入内容"
              rows={8}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default ForumManagement;
