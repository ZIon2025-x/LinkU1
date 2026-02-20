import React, { useCallback } from 'react';
import { message, Modal } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import {
  getForumCategories,
  createForumCategory,
  updateForumCategory,
  deleteForumCategory
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface Category {
  id: number;
  name: string;
  description?: string;
  sort_order: number;
  is_active: boolean;
  post_count?: number;
}

interface CategoryForm {
  id?: number;
  name: string;
  description: string;
  sort_order: number;
  is_active: boolean;
}

const initialForm: CategoryForm = {
  name: '',
  description: '',
  sort_order: 0,
  is_active: true
};

/**
 * 论坛分类管理组件
 */
const ForumManagement: React.FC = () => {
  const fetchCategories = useCallback(async () => {
    const response = await getForumCategories();
    const data = response.categories || response.items || [];
    return { data, total: data.length };
  }, []);

  const handleFetchError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const table = useAdminTable<Category>({
    fetchData: fetchCategories,
    initialPageSize: 100,
    onError: handleFetchError,
  });

  const modal = useModalForm<CategoryForm>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (!values.name) {
        message.warning('请填写分类名称');
        throw new Error('分类名称不能为空');
      }
      if (isEdit && values.id) {
        await updateForumCategory(values.id, {
          name: values.name,
          description: values.description || undefined,
          sort_order: values.sort_order,
          is_visible: values.is_active
        });
        message.success('分类更新成功！');
      } else {
        await createForumCategory({
          name: values.name,
          description: values.description || undefined,
          sort_order: values.sort_order,
          is_visible: values.is_active
        });
        message.success('分类创建成功！');
      }
      table.refresh();
    },
    onError: (error) => {
      message.error(getErrorMessage(error));
    },
  });

  const handleEdit = (category: Category) => {
    modal.open({
      id: category.id,
      name: category.name,
      description: category.description || '',
      sort_order: category.sort_order,
      is_active: category.is_active
    });
  };

  const handleDelete = (id: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个分类吗？删除后该分类下的帖子将无法访问。',
      okText: '确定',
      cancelText: '取消',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await deleteForumCategory(id);
          message.success('分类删除成功！');
          table.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const columns: Column<Category>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'name',
      title: '名称',
      dataIndex: 'name',
      width: 200,
      render: (value) => <strong>{value}</strong>,
    },
    {
      key: 'description',
      title: '描述',
      dataIndex: 'description',
      width: 250,
      render: (value) => (
        <span style={{ maxWidth: 250, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {value || '-'}
        </span>
      ),
    },
    {
      key: 'post_count',
      title: '帖子数',
      dataIndex: 'post_count',
      width: 100,
      render: (value) => value || 0,
    },
    {
      key: 'sort_order',
      title: '排序',
      dataIndex: 'sort_order',
      width: 80,
    },
    {
      key: 'is_active',
      title: '状态',
      dataIndex: 'is_active',
      width: 100,
      render: (value) => (
        <StatusBadge
          text={value ? '启用' : '禁用'}
          variant={value ? 'success' : 'danger'}
        />
      ),
    },
    {
      key: 'actions',
      title: '操作',
      width: 150,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
          <button
            onClick={() => handleEdit(record)}
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
            onClick={() => handleDelete(record.id)}
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
      ),
    },
  ];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>论坛分类管理</h2>
        <button
          onClick={() => modal.open(initialForm, true)}
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
          创建分类
        </button>
      </div>

      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
        emptyText="暂无分类"
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

      {/* 创建/编辑模态框 */}
      <Modal
        title={modal.isEdit ? '编辑分类' : '创建分类'}
        open={modal.isOpen}
        onCancel={modal.close}
        onOk={modal.handleSubmit}
        confirmLoading={modal.loading}
        okText={modal.isEdit ? '更新' : '创建'}
        cancelText="取消"
        width={500}
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              分类名称 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={modal.formData.name}
              onChange={(e) => modal.updateField('name', e.target.value)}
              placeholder="请输入分类名称"
              style={{
                width: '100%',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                boxSizing: 'border-box'
              }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>描述</label>
            <textarea
              value={modal.formData.description}
              onChange={(e) => modal.updateField('description', e.target.value)}
              placeholder="请输入分类描述（可选）"
              rows={3}
              style={{
                width: '100%',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                resize: 'vertical',
                boxSizing: 'border-box'
              }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              排序（数字越小越靠前）
            </label>
            <input
              type="number"
              value={modal.formData.sort_order}
              onChange={(e) => modal.updateField('sort_order', parseInt(e.target.value) || 0)}
              style={{
                width: '100%',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                boxSizing: 'border-box'
              }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={modal.formData.is_active}
                onChange={(e) => modal.updateField('is_active', e.target.checked)}
              />
              <span>启用状态</span>
            </label>
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default ForumManagement;
