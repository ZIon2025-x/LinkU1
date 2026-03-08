import React, { useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
import {
  getSkillCategoriesAdmin,
  createSkillCategory,
  updateSkillCategory,
  deleteSkillCategory,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface SkillCategory {
  id: number;
  name_zh: string;
  name_en: string;
  icon?: string;
  display_order: number;
  created_at?: string;
}

interface CategoryForm {
  id?: number;
  name_zh: string;
  name_en: string;
  icon: string;
  display_order: number;
}

const initialForm: CategoryForm = {
  name_zh: '',
  name_en: '',
  icon: '',
  display_order: 0,
};

const SkillCategoryManagement: React.FC = () => {
  const fetchCategories = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getSkillCategoriesAdmin({ offset: (page - 1) * pageSize, limit: pageSize });
    return {
      data: response.items || response.data || [],
      total: response.total || 0,
    };
  }, []);

  const table = useAdminTable<SkillCategory>({
    fetchData: fetchCategories,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const modal = useModalForm<CategoryForm>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (!values.name_zh || !values.name_en) {
        message.warning('Please fill in both Chinese and English names');
        throw new Error('validation');
      }

      const payload = {
        name_zh: values.name_zh,
        name_en: values.name_en,
        icon: values.icon || undefined,
        display_order: values.display_order,
      };

      if (isEdit && values.id) {
        await updateSkillCategory(values.id, payload);
        message.success('Category updated');
      } else {
        await createSkillCategory(payload);
        message.success('Category created');
      }
      table.refresh();
    },
    onError: (error: any) => {
      if (error?.message !== 'validation') {
        message.error(getErrorMessage(error));
      }
    },
  });

  const handleEdit = (cat: SkillCategory) => {
    modal.open({
      id: cat.id,
      name_zh: cat.name_zh,
      name_en: cat.name_en,
      icon: cat.icon || '',
      display_order: cat.display_order,
    });
  };

  const handleDelete = (id: number) => {
    if (!window.confirm('Are you sure you want to delete this category?')) return;
    deleteSkillCategory(id)
      .then(() => {
        message.success('Category deleted');
        table.refresh();
      })
      .catch((error: any) => message.error(getErrorMessage(error)));
  };

  const columns: Column<SkillCategory>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    { key: 'name_zh', title: 'Name (ZH)', dataIndex: 'name_zh', width: 180 },
    { key: 'name_en', title: 'Name (EN)', dataIndex: 'name_en', width: 180 },
    {
      key: 'icon', title: 'Icon', dataIndex: 'icon', width: 80, align: 'center',
      render: (val: string) => val ? <span style={{ fontSize: '20px' }}>{val}</span> : '-',
    },
    { key: 'display_order', title: 'Order', dataIndex: 'display_order', width: 80, align: 'center' },
    {
      key: 'actions', title: 'Actions', width: 160, align: 'center',
      render: (_: any, record: SkillCategory) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => handleEdit(record)}
            style={{ padding: '4px 10px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            Edit
          </button>
          <button
            onClick={() => handleDelete(record.id)}
            style={{ padding: '4px 10px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            Delete
          </button>
        </div>
      ),
    },
  ];

  const modalFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={modal.close}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        Cancel
      </button>
      <button
        onClick={modal.handleSubmit}
        disabled={modal.loading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: modal.loading ? 'not-allowed' : 'pointer', opacity: modal.loading ? 0.7 : 1 }}
      >
        {modal.loading ? 'Submitting...' : modal.isEdit ? 'Update' : 'Create'}
      </button>
    </div>
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Skill Category Management</h2>
        <button
          onClick={() => modal.open()}
          style={{ padding: '10px 20px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}
        >
          Add Category
        </button>
      </div>

      <AdminTable<SkillCategory>
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
      />

      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      <AdminModal
        isOpen={modal.isOpen}
        onClose={modal.close}
        title={modal.isEdit ? 'Edit Category' : 'Add Category'}
        footer={modalFooter}
        width="500px"
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              Name (ZH) <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={modal.formData.name_zh}
              onChange={(e) => modal.updateField('name_zh', e.target.value)}
              placeholder="Chinese name"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              Name (EN) <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={modal.formData.name_en}
              onChange={(e) => modal.updateField('name_en', e.target.value)}
              placeholder="English name"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Icon (emoji or icon name)</label>
            <input
              type="text"
              value={modal.formData.icon}
              onChange={(e) => modal.updateField('icon', e.target.value)}
              placeholder="e.g. code, design, music"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Display Order</label>
            <input
              type="number"
              value={modal.formData.display_order}
              onChange={(e) => modal.updateField('display_order', parseInt(e.target.value) || 0)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
        </div>
      </AdminModal>
    </div>
  );
};

export default SkillCategoryManagement;
