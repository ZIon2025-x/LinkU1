import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
import {
  getBannersAdmin,
  createBanner,
  updateBanner,
  deleteBanner,
  toggleBannerStatus,
  uploadBannerImage
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import LazyImage from '../../../components/LazyImage';

interface Banner {
  id: number;
  title: string;
  subtitle?: string;
  image_url: string;
  link_url?: string;
  link_type: 'internal' | 'external';
  order: number;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

interface FormData {
  id?: number;
  title: string;
  subtitle: string;
  image_url: string;
  link_url: string;
  link_type: 'internal' | 'external';
  order: number;
  is_active: boolean;
}

const initialForm: FormData = {
  title: '',
  subtitle: '',
  image_url: '',
  link_url: '',
  link_type: 'internal',
  order: 0,
  is_active: true
};

/**
 * Banner 管理组件
 */
const BannerManagement: React.FC = () => {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<FormData>(initialForm);
  const [uploading, setUploading] = useState(false);

  const loadBanners = useCallback(async () => {
    setLoading(true);
    try {
      const response = await getBannersAdmin({ page, limit: 20 });
      setBanners(response.items || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, [page]);

  useEffect(() => {
    loadBanners();
  }, [loadBanners]);

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    try {
      const result = await uploadBannerImage(file);
      setForm({ ...form, image_url: result.url });
      message.success('图片上传成功');
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setUploading(false);
    }
  };

  const handleCreate = async () => {
    if (!form.title || !form.image_url) {
      message.warning('请填写标题和上传图片');
      return;
    }

    try {
      await createBanner({
        title: form.title,
        subtitle: form.subtitle || undefined,
        image_url: form.image_url,
        link_url: form.link_url || undefined,
        link_type: form.link_type,
        order: form.order,
        is_active: form.is_active
      });
      message.success('Banner 创建成功！');
      setShowModal(false);
      setForm(initialForm);
      loadBanners();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleUpdate = async () => {
    if (!form.id) return;

    try {
      await updateBanner(form.id, {
        title: form.title,
        subtitle: form.subtitle || undefined,
        image_url: form.image_url,
        link_url: form.link_url || undefined,
        link_type: form.link_type,
        order: form.order,
        is_active: form.is_active
      });
      message.success('Banner 更新成功！');
      setShowModal(false);
      setForm(initialForm);
      loadBanners();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleEdit = (banner: Banner) => {
    setForm({
      id: banner.id,
      title: banner.title,
      subtitle: banner.subtitle || '',
      image_url: banner.image_url,
      link_url: banner.link_url || '',
      link_type: banner.link_type,
      order: banner.order,
      is_active: banner.is_active
    });
    setShowModal(true);
  };

  const handleDelete = (id: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个 Banner 吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteBanner(id);
          message.success('Banner 删除成功！');
          loadBanners();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const handleToggleStatus = async (id: number, currentStatus: boolean) => {
    try {
      await toggleBannerStatus(id);
      message.success(currentStatus ? 'Banner 已禁用' : 'Banner 已启用');
      loadBanners();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const totalPages = Math.ceil(total / 20);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Banner 管理</h2>
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
          创建 Banner
        </button>
      </div>

      {/* Banner 列表 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))', gap: '20px' }}>
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center', gridColumn: '1 / -1' }}>加载中...</div>
        ) : banners.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999', gridColumn: '1 / -1' }}>暂无 Banner</div>
        ) : (
          banners.map((banner) => (
            <div
              key={banner.id}
              style={{
                background: 'white',
                borderRadius: '8px',
                boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
                overflow: 'hidden'
              }}
            >
              <div style={{ position: 'relative', height: '150px', overflow: 'hidden' }}>
                <LazyImage
                  src={banner.image_url}
                  alt={banner.title}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
                <span
                  style={{
                    position: 'absolute',
                    top: '10px',
                    right: '10px',
                    padding: '4px 8px',
                    borderRadius: '4px',
                    background: banner.is_active ? '#28a745' : '#dc3545',
                    color: 'white',
                    fontSize: '12px',
                    fontWeight: '500'
                  }}
                >
                  {banner.is_active ? '启用' : '禁用'}
                </span>
              </div>
              <div style={{ padding: '16px' }}>
                <h3 style={{ margin: '0 0 8px 0', fontSize: '16px' }}>{banner.title}</h3>
                <p style={{ margin: '0 0 12px 0', color: '#666', fontSize: '14px', minHeight: '20px' }}>
                  {banner.subtitle || '-'}
                </p>
                <div style={{ fontSize: '12px', color: '#999', marginBottom: '12px' }}>
                  排序: {banner.order} | 链接类型: {banner.link_type === 'external' ? '外部链接' : '内部链接'}
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button onClick={() => handleEdit(banner)} style={{ flex: 1, padding: '6px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>编辑</button>
                  <button onClick={() => handleToggleStatus(banner.id, banner.is_active)} style={{ flex: 1, padding: '6px', border: 'none', background: banner.is_active ? '#ffc107' : '#28a745', color: banner.is_active ? '#212529' : 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>{banner.is_active ? '禁用' : '启用'}</button>
                  <button onClick={() => handleDelete(banner.id)} style={{ flex: 1, padding: '6px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>删除</button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* 分页 */}
      {total > 20 && (
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
          <button onClick={() => page > 1 && setPage(page - 1)} disabled={page === 1} style={{ padding: '8px 16px', border: '1px solid #ddd', background: page === 1 ? '#f5f5f5' : 'white', borderRadius: '4px', cursor: page === 1 ? 'not-allowed' : 'pointer' }}>上一页</button>
          <span style={{ padding: '8px 16px', alignSelf: 'center' }}>第 {page} 页，共 {totalPages} 页</span>
          <button onClick={() => page < totalPages && setPage(page + 1)} disabled={page >= totalPages} style={{ padding: '8px 16px', border: '1px solid #ddd', background: page >= totalPages ? '#f5f5f5' : 'white', borderRadius: '4px', cursor: page >= totalPages ? 'not-allowed' : 'pointer' }}>下一页</button>
        </div>
      )}

      {/* 模态框 */}
      <Modal
        title={form.id ? '编辑 Banner' : '创建 Banner'}
        open={showModal}
        onCancel={() => { setShowModal(false); setForm(initialForm); }}
        onOk={form.id ? handleUpdate : handleCreate}
        okText={form.id ? '更新' : '创建'}
        cancelText="取消"
        width={600}
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>标题 <span style={{ color: 'red' }}>*</span></label>
            <input type="text" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="请输入标题" style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>副标题</label>
            <textarea value={form.subtitle} onChange={(e) => setForm({ ...form, subtitle: e.target.value })} placeholder="请输入副标题" rows={3} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>图片 <span style={{ color: 'red' }}>*</span></label>
            <input type="file" accept="image/*" onChange={handleImageUpload} disabled={uploading} />
            {uploading && <span style={{ marginLeft: '10px', color: '#666' }}>上传中...</span>}
            {form.image_url && (
              <div style={{ marginTop: '10px' }}>
                <img src={form.image_url} alt="Preview" style={{ maxWidth: '200px', maxHeight: '100px', objectFit: 'cover', borderRadius: '4px' }} />
              </div>
            )}
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>链接类型</label>
            <select value={form.link_type} onChange={(e) => setForm({ ...form, link_type: e.target.value as 'internal' | 'external' })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}>
              <option value="internal">内部链接</option>
              <option value="external">外部链接</option>
            </select>
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>链接 URL</label>
            <input type="text" value={form.link_url} onChange={(e) => setForm({ ...form, link_url: e.target.value })} placeholder={form.link_type === 'external' ? 'https://...' : '/page/...'} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>排序（数字越小越靠前）</label>
            <input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: parseInt(e.target.value) || 0 })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} />
              <span>启用状态</span>
            </label>
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default BannerManagement;
