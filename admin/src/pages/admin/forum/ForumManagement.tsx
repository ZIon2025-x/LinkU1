import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
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

interface FormData {
  id?: number;
  name: string;
  description: string;
  sort_order: number;
  is_active: boolean;
}

const initialForm: FormData = {
  name: '',
  description: '',
  sort_order: 0,
  is_active: true
};

/**
 * 论坛分类管理组件
 */
const ForumManagement: React.FC = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<FormData>(initialForm);

  const loadCategories = useCallback(async () => {
    setLoading(true);
    try {
      const response = await getForumCategories();
      setCategories(response.items || response || []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadCategories();
  }, [loadCategories]);

  const handleCreate = async () => {
    if (!form.name) {
      message.warning('请填写分类名称');
      return;
    }

    try {
      await createForumCategory({
        name: form.name,
        description: form.description || undefined,
        sort_order: form.sort_order,
        is_active: form.is_active
      });
      message.success('分类创建成功！');
      setShowModal(false);
      setForm(initialForm);
      loadCategories();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleUpdate = async () => {
    if (!form.id) return;

    try {
      await updateForumCategory(form.id, {
        name: form.name,
        description: form.description || undefined,
        sort_order: form.sort_order,
        is_active: form.is_active
      });
      message.success('分类更新成功！');
      setShowModal(false);
      setForm(initialForm);
      loadCategories();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleEdit = (category: Category) => {
    setForm({
      id: category.id,
      name: category.name,
      description: category.description || '',
      sort_order: category.sort_order,
      is_active: category.is_active
    });
    setShowModal(true);
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
          loadCategories();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>论坛分类管理</h2>
        <button
          onClick={() => { setForm(initialForm); setShowModal(true); }}
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

      {/* 分类列表 */}
      <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : categories.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无分类</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>名称</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>帖子数</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>排序</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {categories.map((category) => (
                <tr key={category.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '12px' }}>{category.id}</td>
                  <td style={{ padding: '12px', fontWeight: '500' }}>{category.name}</td>
                  <td style={{ padding: '12px', maxWidth: '250px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {category.description || '-'}
                  </td>
                  <td style={{ padding: '12px' }}>{category.post_count || 0}</td>
                  <td style={{ padding: '12px' }}>{category.sort_order}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: category.is_active ? '#d4edda' : '#f8d7da',
                      color: category.is_active ? '#155724' : '#721c24',
                      fontSize: '12px',
                      fontWeight: '500'
                    }}>
                      {category.is_active ? '启用' : '禁用'}
                    </span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleEdit(category)}
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
                        onClick={() => handleDelete(category.id)}
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

      {/* 模态框 */}
      <Modal
        title={form.id ? '编辑分类' : '创建分类'}
        open={showModal}
        onCancel={() => { setShowModal(false); setForm(initialForm); }}
        onOk={form.id ? handleUpdate : handleCreate}
        okText={form.id ? '更新' : '创建'}
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
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="请输入分类名称"
              style={{
                width: '100%',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>描述</label>
            <textarea
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              placeholder="请输入分类描述（可选）"
              rows={3}
              style={{
                width: '100%',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                resize: 'vertical'
              }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              排序（数字越小越靠前）
            </label>
            <input
              type="number"
              value={form.sort_order}
              onChange={(e) => setForm({ ...form, sort_order: parseInt(e.target.value) || 0 })}
              style={{
                width: '100%',
                padding: '8px',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
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
