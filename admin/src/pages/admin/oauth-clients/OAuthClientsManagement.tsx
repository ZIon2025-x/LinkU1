import React, { useState, useCallback, useEffect } from 'react';
import { message, Modal } from 'antd';
import { useAdminTable } from '../../../hooks';
import { AdminTable, AdminPagination, Column } from '../../../components/admin';
import {
  getAdminOAuthClients,
  createAdminOAuthClient,
  updateAdminOAuthClient,
  rotateAdminOAuthClientSecret,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface OAuthClient {
  client_id: string;
  client_name: string;
  client_uri?: string;
  logo_uri?: string;
  redirect_uris: string[];
  is_active: boolean;
  created_at: string;
}

const OAuthClientsManagement: React.FC = () => {
  const [list, setList] = useState<OAuthClient[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [createModal, setCreateModal] = useState(false);
  const [createName, setCreateName] = useState('');
  const [createRedirectUris, setCreateRedirectUris] = useState('');

  const loadList = useCallback(async (page = 1, pageSize = 20) => {
    setLoading(true);
    try {
      const res = await getAdminOAuthClients({});
      const items = Array.isArray(res) ? res : (res?.items ?? res ?? []);
      setList(items);
      setTotal(items.length);
    } catch (e) {
      message.error(getErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadList();
  }, [loadList]);

  const handleCreate = async () => {
    if (!createName.trim()) {
      message.warning('请输入客户端名称');
      return;
    }
    const redirect_uris = createRedirectUris
      .split(/[\n,]/)
      .map((u) => u.trim())
      .filter(Boolean);
    try {
      await createAdminOAuthClient({
        client_name: createName.trim(),
        redirect_uris: redirect_uris.length ? redirect_uris : undefined,
      });
      message.success('创建成功，请妥善保存返回的 client_secret（仅显示一次）');
      setCreateModal(false);
      setCreateName('');
      setCreateRedirectUris('');
      loadList();
    } catch (e) {
      message.error(getErrorMessage(e));
    }
  };

  const handleRotate = (clientId: string) => {
    Modal.confirm({
      title: '轮换密钥',
      content: '轮换后旧密钥立即失效，新密钥仅显示一次。确定继续？',
      onOk: async () => {
        try {
          const res = await rotateAdminOAuthClientSecret(clientId);
          message.success(`新 client_secret 已生成（仅此次显示）: ${res?.client_secret ? res.client_secret.slice(0, 12) + '...' : '见响应'}`);
          loadList();
        } catch (e) {
          message.error(getErrorMessage(e));
        }
      },
    });
  };

  const handleToggleActive = async (client: OAuthClient) => {
    try {
      await updateAdminOAuthClient(client.client_id, { is_active: !client.is_active });
      message.success('已更新');
      loadList();
    } catch (e) {
      message.error(getErrorMessage(e));
    }
  };

  const columns: Column<OAuthClient>[] = [
    { key: 'client_id', title: 'Client ID', dataIndex: 'client_id', width: 120, render: (v) => (v ? String(v).slice(0, 16) + '...' : '-') },
    { key: 'client_name', title: '名称', dataIndex: 'client_name', width: 160 },
    {
      key: 'redirect_uris',
      title: '回调 URI',
      width: 200,
      render: (_, r) => (r.redirect_uris?.length ? r.redirect_uris.join(', ') : '-'),
    },
    {
      key: 'is_active',
      title: '状态',
      width: 80,
      render: (_, r) => (r.is_active ? '启用' : '禁用'),
    },
    {
      key: 'created_at',
      title: '创建时间',
      dataIndex: 'created_at',
      width: 160,
      render: (v) => (v ? new Date(v).toLocaleString('zh-CN') : '-'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 180,
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            type="button"
            onClick={() => handleToggleActive(record)}
            style={{ padding: '4px 8px', fontSize: '12px', border: '1px solid #1890ff', background: 'white', color: '#1890ff', borderRadius: '4px', cursor: 'pointer' }}
          >
            {record.is_active ? '禁用' : '启用'}
          </button>
          <button
            type="button"
            onClick={() => handleRotate(record.client_id)}
            style={{ padding: '4px 8px', fontSize: '12px', border: '1px solid #faad14', background: 'white', color: '#faad14', borderRadius: '4px', cursor: 'pointer' }}
          >
            轮换密钥
          </button>
        </div>
      ),
    },
  ];

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>OAuth 客户端管理</h2>

      <div style={{ marginBottom: '16px' }}>
        <button
          type="button"
          onClick={() => setCreateModal(true)}
          style={{ padding: '8px 16px', background: '#52c41a', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          创建客户端
        </button>
      </div>

      <AdminTable
        columns={columns}
        data={list}
        loading={loading}
        rowKey="client_id"
        emptyText="暂无 OAuth 客户端"
      />
      {total > 0 && (
        <div style={{ marginTop: '12px', color: '#666', fontSize: '14px' }}>共 {total} 个客户端</div>
      )}

      {createModal && (
        <Modal
          title="创建 OAuth 客户端"
          open={createModal}
          onCancel={() => setCreateModal(false)}
          onOk={handleCreate}
          okText="创建"
        >
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>客户端名称</label>
            <input
              type="text"
              value={createName}
              onChange={(e) => setCreateName(e.target.value)}
              placeholder="例如：移动端 App"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>回调 URI（每行一个或逗号分隔）</label>
            <textarea
              value={createRedirectUris}
              onChange={(e) => setCreateRedirectUris(e.target.value)}
              placeholder="https://example.com/callback"
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
        </Modal>
      )}
    </div>
  );
};

export default OAuthClientsManagement;
