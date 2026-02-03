import React, { useState, useEffect, useCallback } from 'react';
import {
  message,
  Modal,
  Table,
  Button,
  Space,
  Tag,
  Spin,
  Card,
  Typography,
  Input,
  Form,
  Checkbox,
  Tooltip,
  Popconfirm,
} from 'antd';
import { PlusOutlined, CopyOutlined, EditOutlined, StopOutlined, CheckCircleOutlined, KeyOutlined } from '@ant-design/icons';
import api from '../api';

const { TextArea } = Input;
const { Text } = Typography;

interface OAuthClient {
  client_id: string;
  client_name: string;
  client_uri?: string;
  logo_uri?: string;
  redirect_uris: string[];
  scope_default?: string;
  allowed_grant_types: string[];
  is_confidential: boolean;
  is_active: boolean;
  created_at?: string;
}

const copyToClipboard = (text: string, label: string) => {
  if (navigator.clipboard?.writeText) {
    navigator.clipboard
      .writeText(text)
      .then(() => message.success(`已复制 ${label}`))
      .catch(() => message.error('复制失败'));
  } else {
    message.warning('当前环境不支持一键复制，请手动选择复制');
  }
};

const formatDate = (iso?: string) => {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    return d.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
};

/** 解析多行或逗号分隔的回调地址 */
const parseRedirectUris = (s: string): string[] =>
  s
    .split(/[\n,]/)
    .map((u: string) => u.trim())
    .filter(Boolean);

const OAuthClientsManagement: React.FC = () => {
  const [clients, setClients] = useState<OAuthClient[]>([]);
  const [loading, setLoading] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [createForm, setCreateForm] = useState({
    client_name: '',
    redirect_uris: '',
    client_uri: '',
    logo_uri: '',
    is_confidential: true,
  });
  const [creating, setCreating] = useState(false);
  const [newClientSecret, setNewClientSecret] = useState<{ client_id: string; client_secret: string } | null>(null);
  const [rotateModal, setRotateModal] = useState<{ client_id: string; client_name: string } | null>(null);
  const [rotating, setRotating] = useState(false);
  const [rotatedSecret, setRotatedSecret] = useState<string | null>(null);
  const [editModal, setEditModal] = useState<OAuthClient | null>(null);
  const [editForm, setEditForm] = useState({ client_name: '', redirect_uris: '', client_uri: '', logo_uri: '' });
  const [saving, setSaving] = useState(false);

  const [createFormInstance] = Form.useForm();
  const [editFormInstance] = Form.useForm();

  const fetchClients = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/api/admin/oauth/clients');
      setClients(Array.isArray(res.data) ? res.data : []);
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      message.error(err?.response?.data?.detail || '加载 OAuth 客户端失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchClients();
  }, [fetchClients]);

  const handleCreate = async () => {
    const values = await createFormInstance.validateFields().catch(() => null);
    if (!values) return;
    const redirect_uris = parseRedirectUris(values.redirect_uris || '');
    if (redirect_uris.length === 0) {
      message.warning('请至少填写一个回调地址');
      return;
    }
    setCreating(true);
    try {
      const res = await api.post('/api/admin/oauth/clients', {
        client_name: (values.client_name || '').trim(),
        redirect_uris,
        client_uri: (values.client_uri || '').trim() || undefined,
        logo_uri: (values.logo_uri || '').trim() || undefined,
        is_confidential: values.is_confidential !== false,
      });
      setNewClientSecret({
        client_id: res.data.client_id,
        client_secret: res.data.client_secret,
      });
      setCreateForm({ client_name: '', redirect_uris: '', client_uri: '', logo_uri: '', is_confidential: true });
      createFormInstance.resetFields();
      setShowCreateModal(false);
      fetchClients();
      message.success('创建成功，请妥善保存 client_secret（仅显示一次）');
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      message.error(err?.response?.data?.detail || '创建失败');
    } finally {
      setCreating(false);
    }
  };

  const handleRotate = async () => {
    if (!rotateModal) return;
    setRotating(true);
    try {
      const res = await api.post(
        `/api/admin/oauth/clients/${encodeURIComponent(rotateModal.client_id)}/rotate-secret`
      );
      setRotatedSecret(res.data.client_secret);
      message.success('轮换成功，请将新 secret 告知合作方');
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      message.error(err?.response?.data?.detail || '轮换失败');
    } finally {
      setRotating(false);
    }
  };

  const handleToggleActive = async (client: OAuthClient) => {
    try {
      await api.patch(`/api/admin/oauth/clients/${encodeURIComponent(client.client_id)}`, {
        is_active: !client.is_active,
      });
      message.success(client.is_active ? '已禁用' : '已启用');
      fetchClients();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      message.error(err?.response?.data?.detail || '操作失败');
    }
  };

  const openEdit = (client: OAuthClient) => {
    setEditModal(client);
    setEditForm({
      client_name: client.client_name,
      redirect_uris: (client.redirect_uris || []).join('\n'),
      client_uri: client.client_uri || '',
      logo_uri: client.logo_uri || '',
    });
    editFormInstance.setFieldsValue({
      client_name: client.client_name,
      redirect_uris: (client.redirect_uris || []).join('\n'),
      client_uri: client.client_uri || '',
      logo_uri: client.logo_uri || '',
    });
  };

  const handleSaveEdit = async () => {
    if (!editModal) return;
    const values = await editFormInstance.validateFields().catch(() => null);
    if (!values) return;
    const redirect_uris = parseRedirectUris(values.redirect_uris || '');
    if (redirect_uris.length === 0) {
      message.warning('请至少填写一个回调地址');
      return;
    }
    setSaving(true);
    try {
      await api.patch(`/api/admin/oauth/clients/${encodeURIComponent(editModal.client_id)}`, {
        client_name: (values.client_name || '').trim(),
        redirect_uris,
        client_uri: (values.client_uri || '').trim() || undefined,
        logo_uri: (values.logo_uri || '').trim() || undefined,
      });
      message.success('已保存');
      setEditModal(null);
      editFormInstance.resetFields();
      fetchClients();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      message.error(err?.response?.data?.detail || '保存失败');
    } finally {
      setSaving(false);
    }
  };

  const columns = [
    {
      title: '应用名称',
      dataIndex: 'client_name',
      key: 'client_name',
      width: 140,
      ellipsis: true,
      render: (name: string) => <Text ellipsis={{ tooltip: name }}>{name}</Text>,
    },
    {
      title: 'Client ID',
      dataIndex: 'client_id',
      key: 'client_id',
      width: 200,
      render: (clientId: string) => (
        <Space size="small">
          <Text code style={{ fontSize: 12 }}>{clientId}</Text>
          <Tooltip title="复制 Client ID">
            <Button
              type="text"
              size="small"
              icon={<CopyOutlined />}
              onClick={() => copyToClipboard(clientId, 'Client ID')}
            />
          </Tooltip>
        </Space>
      ),
    },
    {
      title: '回调地址',
      key: 'redirect_uris',
      ellipsis: true,
      render: (_: unknown, record: OAuthClient) => {
        const uris = record.redirect_uris || [];
        const text = uris.slice(0, 2).join(', ') + (uris.length > 2 ? ' ...' : '');
        return <Text ellipsis={{ tooltip: uris.join('\n') }} style={{ fontSize: 12 }}>{text}</Text>;
      },
    },
    {
      title: '状态',
      dataIndex: 'is_active',
      key: 'is_active',
      width: 80,
      render: (isActive: boolean) =>
        isActive ? (
          <Tag color="success" icon={<CheckCircleOutlined />}>启用</Tag>
        ) : (
          <Tag color="error" icon={<StopOutlined />}>禁用</Tag>
        ),
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      key: 'created_at',
      width: 160,
      render: (iso?: string) => <Text type="secondary" style={{ fontSize: 12 }}>{formatDate(iso)}</Text>,
    },
    {
      title: '操作',
      key: 'actions',
      width: 220,
      fixed: 'right' as const,
      render: (_: unknown, record: OAuthClient): React.ReactNode => (
        <Space size="small" wrap>
          <Button type="link" size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>
            编辑
          </Button>
          <Popconfirm
            title={record.is_active ? '确认禁用该客户端？' : '确认启用该客户端？'}
            onConfirm={() => handleToggleActive(record)}
            okText="确认"
            cancelText="取消"
          >
            <Button
              type="link"
              size="small"
              danger={record.is_active}
              icon={record.is_active ? <StopOutlined /> : <CheckCircleOutlined />}
            >
              {record.is_active ? '禁用' : '启用'}
            </Button>
          </Popconfirm>
          <Button
            type="link"
            size="small"
            icon={<KeyOutlined />}
            onClick={() => setRotateModal({ client_id: record.client_id, client_name: record.client_name })}
          >
            轮换 Secret
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <div style={{ padding: '20px' }}>
      <Card>
        <div style={{ marginBottom: 16 }}>
          <Text strong style={{ fontSize: 18 }}>OAuth 客户端管理</Text>
          <br />
          <Text type="secondary" style={{ marginTop: 4, display: 'inline-block' }}>
            第三方应用使用「Link²Ur 登录」时，需在此创建客户端并配置回调地址。创建后请将 client_id 与 client_secret 安全交付合作方。
          </Text>
        </div>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => setShowCreateModal(true)} style={{ marginBottom: 16 }}>
          新建客户端
        </Button>

        <Spin spinning={loading}>
          <Table
            rowKey="client_id"
            columns={columns}
            dataSource={clients}
            pagination={{ pageSize: 20, showSizeChanger: true, showTotal: (t: number) => `共 ${t} 条` }}
            locale={{ emptyText: '暂无客户端，点击「新建客户端」添加' }}
            scroll={{ x: 900 }}
          />
        </Spin>
      </Card>

      <Modal
        title="新建 OAuth 客户端"
        open={showCreateModal}
        onCancel={() => setShowCreateModal(false)}
        onOk={handleCreate}
        confirmLoading={creating}
        okText="创建"
        width={520}
        destroyOnClose
        afterClose={() => createFormInstance.resetFields()}
      >
        <Form
          form={createFormInstance}
          layout="vertical"
          initialValues={createForm}
          onValuesChange={(_: unknown, all: Record<string, unknown>) => setCreateForm((prev) => ({ ...prev, ...all }))}
        >
          <Form.Item name="client_name" label="应用名称" rules={[{ required: true, message: '请输入应用名称' }]}>
            <Input placeholder="例如：合作方 App" />
          </Form.Item>
          <Form.Item
            name="redirect_uris"
            label="回调地址（每行一个或逗号分隔）"
            rules={[
              { required: true, message: '请至少填写一个回调地址' },
              {
                validator: (_: unknown, value: string) => {
                  if (parseRedirectUris(value || '').length === 0) return Promise.reject(new Error('请至少填写一个有效回调地址'));
                  return Promise.resolve();
                },
              },
            ]}
          >
            <TextArea rows={3} placeholder="https://example.com/callback" />
          </Form.Item>
          <Form.Item name="client_uri" label="应用官网（选填）">
            <Input placeholder="https://example.com" />
          </Form.Item>
          <Form.Item name="logo_uri" label="Logo URL（选填）">
            <Input placeholder="https://example.com/logo.png" />
          </Form.Item>
          <Form.Item name="is_confidential" valuePropName="checked" initialValue={true}>
            <Checkbox>机密客户端（有 client_secret，如后端应用）</Checkbox>
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="编辑 OAuth 客户端"
        open={!!editModal}
        onCancel={() => { setEditModal(null); editFormInstance.resetFields(); }}
        onOk={handleSaveEdit}
        confirmLoading={saving}
        okText="保存"
        width={520}
        destroyOnClose
        afterClose={() => editFormInstance.resetFields()}
      >
        {editModal && (
          <Form
            form={editFormInstance}
            layout="vertical"
            initialValues={editForm}
            onValuesChange={(_: unknown, all: Record<string, unknown>) => setEditForm((prev) => ({ ...prev, ...all }))}
          >
            <Form.Item name="client_name" label="应用名称" rules={[{ required: true, message: '请输入应用名称' }]}>
              <Input placeholder="例如：合作方 App" />
            </Form.Item>
            <Form.Item
              name="redirect_uris"
              label="回调地址（每行一个或逗号分隔）"
              rules={[
                { required: true, message: '请至少填写一个回调地址' },
                {
                  validator: (_: unknown, value: string) => {
                    if (parseRedirectUris(value || '').length === 0) return Promise.reject(new Error('请至少填写一个有效回调地址'));
                    return Promise.resolve();
                  },
                },
              ]}
            >
              <TextArea rows={3} placeholder="https://example.com/callback" />
            </Form.Item>
            <Form.Item name="client_uri" label="应用官网（选填）">
              <Input placeholder="https://example.com" />
            </Form.Item>
            <Form.Item name="logo_uri" label="Logo URL（选填）">
              <Input placeholder="https://example.com/logo.png" />
            </Form.Item>
          </Form>
        )}
      </Modal>

      <Modal
        title="创建成功 - 请保存 Client Secret"
        open={!!newClientSecret}
        onCancel={() => setNewClientSecret(null)}
        footer={[{ text: '已保存', onClick: () => setNewClientSecret(null) }]}
        width={520}
      >
        {newClientSecret && (
          <div style={{ fontFamily: 'monospace', fontSize: 13 }}>
            <p>
              <strong>Client ID:</strong>{' '}
              <Button size="small" icon={<CopyOutlined />} onClick={() => copyToClipboard(newClientSecret.client_id, 'Client ID')}>
                复制
              </Button>
            </p>
            <p style={{ wordBreak: 'break-all', background: '#f5f5f5', padding: 8, marginTop: 4 }}>{newClientSecret.client_id}</p>
            <p style={{ marginTop: 12 }}>
              <strong>Client Secret（仅显示一次）:</strong>{' '}
              <Button size="small" icon={<CopyOutlined />} onClick={() => copyToClipboard(newClientSecret.client_secret, 'Client Secret')}>
                复制
              </Button>
            </p>
            <p style={{ wordBreak: 'break-all', background: '#fff3cd', padding: 8, marginTop: 4 }}>{newClientSecret.client_secret}</p>
          </div>
        )}
      </Modal>

      <Modal
        title={`轮换 Secret：${rotateModal?.client_name || ''}`}
        open={!!rotateModal}
        onCancel={() => { setRotateModal(null); setRotatedSecret(null); }}
        onOk={handleRotate}
        confirmLoading={rotating}
        okText="确认轮换"
        width={480}
        footer={
          rotatedSecret ? (
            <Button onClick={() => { setRotateModal(null); setRotatedSecret(null); }}>关闭</Button>
          ) : undefined
        }
      >
        {rotatedSecret ? (
          <div>
            <p>
              <strong>新 Secret</strong>（请妥善保存并告知合作方，旧 Secret 已失效）：{' '}
              <Button size="small" icon={<CopyOutlined />} onClick={() => copyToClipboard(rotatedSecret, 'Client Secret')}>
                复制
              </Button>
            </p>
            <p style={{ wordBreak: 'break-all', background: '#fff3cd', padding: 8, fontFamily: 'monospace', marginTop: 8 }}>{rotatedSecret}</p>
          </div>
        ) : (
          <p>轮换后当前 client_secret 将立即失效，请确认合作方已准备好更新配置。</p>
        )}
      </Modal>
    </div>
  );
};

export default OAuthClientsManagement;
