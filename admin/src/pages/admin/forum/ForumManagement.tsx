import React, { useState, useCallback } from 'react';
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
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type SubTab = 'categories' | 'requests';

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

const ForumManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('categories');

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
    </div>
  );
};

export default ForumManagement;
