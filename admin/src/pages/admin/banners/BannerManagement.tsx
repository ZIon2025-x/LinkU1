import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminPagination, AdminModal } from '../../../components/admin';
import {
  getBannersAdmin,
  createBanner,
  updateBanner,
  deleteBanner,
  toggleBannerStatus,
  uploadBannerImage,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import { resolveImageUrl } from '../../../utils/urlUtils';
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
  is_active: true,
};

/**
 * Banner 管理组件
 */
const BannerManagement: React.FC = () => {
  const [uploading, setUploading] = useState(false);

  const fetchBanners = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getBannersAdmin({ page, limit: pageSize });
    return {
      data: response.data || response.items || [],
      total: response.total || 0,
    };
  }, []);

  const table = useAdminTable<Banner>({
    fetchData: fetchBanners,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const modal = useModalForm<FormData>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (!values.title || !values.image_url) {
        message.warning('请填写标题和上传图片');
        throw new Error('validation');
      }

      const payload = {
        title: values.title,
        subtitle: values.subtitle || undefined,
        image_url: values.image_url,
        link_url: values.link_url || undefined,
        link_type: values.link_type,
        order: values.order,
        is_active: values.is_active,
      };

      if (isEdit && values.id) {
        await updateBanner(values.id, payload);
        message.success('Banner 更新成功！');
      } else {
        await createBanner(payload);
        message.success('Banner 创建成功！');
      }

      table.refresh();
    },
    onError: (error: any) => {
      if (error?.message !== 'validation') {
        message.error(getErrorMessage(error));
      }
    },
  });

  const handleImageUpload = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    try {
      const { compressImage } = await import('../../../utils/imageCompression');
      const compressed = await compressImage(file, { maxSizeMB: 4, maxWidthOrHeight: 1920 });
      const result = await uploadBannerImage(compressed);
      modal.updateField('image_url', result.url);
      message.success('图片上传成功');
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setUploading(false);
    }
  }, [modal]);

  const handleEdit = useCallback((banner: Banner) => {
    modal.open({
      id: banner.id,
      title: banner.title,
      subtitle: banner.subtitle || '',
      image_url: banner.image_url,
      link_url: banner.link_url || '',
      link_type: banner.link_type,
      order: banner.order,
      is_active: banner.is_active,
    });
  }, [modal]);

  const handleDelete = useCallback((id: number) => {
    if (!window.confirm('确定要删除这个 Banner 吗？')) return;
    deleteBanner(id)
      .then(() => {
        message.success('Banner 删除成功！');
        table.refresh();
      })
      .catch((error: any) => message.error(getErrorMessage(error)));
  }, [table]);

  const handleToggleStatus = useCallback(async (id: number, currentStatus: boolean) => {
    try {
      await toggleBannerStatus(id);
      message.success(currentStatus ? 'Banner 已禁用' : 'Banner 已启用');
      table.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, [table]);

  const modalFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={modal.close}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        取消
      </button>
      <button
        onClick={modal.handleSubmit}
        disabled={modal.loading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: modal.loading ? 'not-allowed' : 'pointer', opacity: modal.loading ? 0.7 : 1 }}
      >
        {modal.loading ? '提交中...' : modal.isEdit ? '更新' : '创建'}
      </button>
    </div>
  );

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Banner 管理</h2>
        <button
          onClick={() => modal.open()}
          style={{ padding: '10px 20px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}
        >
          创建 Banner
        </button>
      </div>

      {/* Banner 卡片列表 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))', gap: '20px' }}>
        {table.loading ? (
          <div style={{ padding: '40px', textAlign: 'center', gridColumn: '1 / -1' }}>加载中...</div>
        ) : table.data.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999', gridColumn: '1 / -1' }}>暂无 Banner</div>
        ) : (
          table.data.map((banner) => (
            <div
              key={banner.id}
              style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}
            >
              <div style={{ position: 'relative', height: '150px', overflow: 'hidden' }}>
                <LazyImage
                  src={resolveImageUrl(banner.image_url)}
                  alt={banner.title}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
                <span style={{
                  position: 'absolute',
                  top: '10px',
                  right: '10px',
                  padding: '4px 8px',
                  borderRadius: '4px',
                  background: banner.is_active ? '#28a745' : '#dc3545',
                  color: 'white',
                  fontSize: '12px',
                  fontWeight: '500',
                }}>
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
                  <button
                    onClick={() => handleEdit(banner)}
                    style={{ flex: 1, padding: '6px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                  >
                    编辑
                  </button>
                  <button
                    onClick={() => handleToggleStatus(banner.id, banner.is_active)}
                    style={{ flex: 1, padding: '6px', border: 'none', background: banner.is_active ? '#ffc107' : '#28a745', color: banner.is_active ? '#212529' : 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                  >
                    {banner.is_active ? '禁用' : '启用'}
                  </button>
                  <button
                    onClick={() => handleDelete(banner.id)}
                    style={{ flex: 1, padding: '6px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                  >
                    删除
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* 分页 */}
      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      {/* 模态框 */}
      <AdminModal
        isOpen={modal.isOpen}
        onClose={modal.close}
        title={modal.isEdit ? '编辑 Banner' : '创建 Banner'}
        footer={modalFooter}
        width="600px"
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              标题 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={modal.formData.title}
              onChange={(e) => modal.updateField('title', e.target.value)}
              placeholder="请输入标题"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>副标题</label>
            <textarea
              value={modal.formData.subtitle}
              onChange={(e) => modal.updateField('subtitle', e.target.value)}
              placeholder="请输入副标题"
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              图片 <span style={{ color: 'red' }}>*</span>
            </label>
            <input type="file" accept="image/*" onChange={handleImageUpload} disabled={uploading} />
            {uploading && <span style={{ marginLeft: '10px', color: '#666' }}>上传中...</span>}
            {modal.formData.image_url && (
              <div style={{ marginTop: '10px' }}>
                <img
                  src={resolveImageUrl(modal.formData.image_url)}
                  alt="Preview"
                  style={{ maxWidth: '200px', maxHeight: '100px', objectFit: 'cover', borderRadius: '4px' }}
                />
              </div>
            )}
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>链接类型</label>
            <select
              value={modal.formData.link_type}
              onChange={(e) => modal.updateField('link_type', e.target.value as 'internal' | 'external')}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="internal">内部链接（跳转到 App 内页面）</option>
              <option value="external">外部链接（打开浏览器）</option>
            </select>
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>链接 URL</label>
            <input
              type="text"
              value={modal.formData.link_url}
              onChange={(e) => modal.updateField('link_url', e.target.value)}
              placeholder={modal.formData.link_type === 'external' ? 'https://example.com' : '/flea-market'}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
            <div style={{ marginTop: '6px', fontSize: '12px', color: '#888', lineHeight: '1.6' }}>
              {modal.formData.link_type === 'internal' ? (
                <>
                  填写 App 内路由路径，留空则点击无跳转。常用路径：
                  <br />
                  <code>/flea-market</code> 跳蚤市场 &nbsp;|&nbsp;
                  <code>/tasks/{'<id>'}</code> 任务详情 &nbsp;|&nbsp;
                  <code>/forum/posts/{'<id>'}</code> 论坛帖子
                  <br />
                  <code>/activities/{'<id>'}</code> 活动详情 &nbsp;|&nbsp;
                  <code>/leaderboard/{'<id>'}</code> 排行榜 &nbsp;|&nbsp;
                  <code>/student-verification</code> 学生认证
                  <br />
                  <code>/task-experts/intro</code> 成为专家 &nbsp;|&nbsp;
                  <code>/flea-market/{'<id>'}</code> 跳蚤市场商品详情
                </>
              ) : (
                <>填写完整 URL（以 https:// 开头），用户点击后将在浏览器中打开。</>
              )}
            </div>
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>排序（数字越小越靠前）</label>
            <input
              type="number"
              value={modal.formData.order}
              onChange={(e) => modal.updateField('order', parseInt(e.target.value) || 0)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
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
      </AdminModal>
    </div>
  );
};

export default BannerManagement;
