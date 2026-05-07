import React, { useEffect, useState } from 'react';
import {
  Card, Input, Button, Space, message, Typography, Tag, List, Modal, Spin, Divider,
} from 'antd';
import {
  listAIPrompts, getActiveAIPrompt, saveAIPrompt, activateAIPrompt, AISystemPrompt,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

const { TextArea } = Input;
const { Title, Text, Paragraph } = Typography;

const formatTime = (iso: string | null) => {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
};

const AIPromptManagement: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [active, setActive] = useState<AISystemPrompt | null>(null);
  const [defaultTemplate, setDefaultTemplate] = useState<string>('');
  const [history, setHistory] = useState<AISystemPrompt[]>([]);
  const [draft, setDraft] = useState<string>('');
  const [previewing, setPreviewing] = useState<AISystemPrompt | null>(null);

  const reload = async () => {
    setLoading(true);
    try {
      const [activeRes, listRes] = await Promise.all([getActiveAIPrompt(), listAIPrompts()]);
      setActive(activeRes.active);
      setDefaultTemplate(activeRes.default_template);
      setHistory(listRes.prompts);
      setDraft(activeRes.active?.content ?? activeRes.default_template);
    } catch (err) {
      message.error(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    reload();
  }, []);

  const handleSave = async () => {
    if (!draft.trim() || draft.trim().length < 10) {
      message.warning('Prompt 内容至少 10 个字符');
      return;
    }
    Modal.confirm({
      title: '保存并激活新 prompt？',
      content: '当前激活的 prompt 会被自动归档（保留在历史里），新内容将立即对线上用户生效。',
      okText: '保存并激活',
      cancelText: '取消',
      onOk: async () => {
        setSaving(true);
        try {
          await saveAIPrompt({ content: draft });
          message.success('已保存并激活，AI 服务缓存已刷新');
          await reload();
        } catch (err) {
          message.error(getErrorMessage(err));
        } finally {
          setSaving(false);
        }
      },
    });
  };

  const handleActivate = (item: AISystemPrompt) => {
    Modal.confirm({
      title: `激活历史版本 #${item.id}？`,
      content: '当前激活版本会被归档，此历史版本将立即生效。',
      onOk: async () => {
        try {
          await activateAIPrompt(item.id);
          message.success(`已激活 #${item.id}`);
          await reload();
        } catch (err) {
          message.error(getErrorMessage(err));
        }
      },
    });
  };

  const handleResetToDefault = () => {
    Modal.confirm({
      title: '重置为代码内默认 prompt？',
      content: '会把代码内置的默认模板填入编辑框（不会立即保存）。',
      onOk: () => setDraft(defaultTemplate),
    });
  };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: 80 }}><Spin size="large" /></div>;
  }

  const isDirty = draft !== (active?.content ?? defaultTemplate);

  return (
    <div style={{ padding: 0 }}>
      <Title level={3} style={{ marginTop: 0 }}>AI System Prompt 管理</Title>
      <Paragraph type="secondary">
        编辑后端 AI Agent 的 system prompt 模板。保存即立即生效（自动刷新 5 分钟缓存）。
        模板里 <code>{'{user_name}'}</code> / <code>{'{user_id}'}</code> / <code>{'{lang}'}</code> /{' '}
        <code>{'{user_level}'}</code> / <code>{'{lang_instruction}'}</code> 会在调用时被替换。
        当 <code>AI_SYSTEM_PROMPT_SOURCE=db</code> 时此处编辑生效，否则只是存档。
      </Paragraph>

      <Card
        size="small"
        style={{ marginBottom: 16 }}
        title={
          <Space>
            <span>当前激活版本</span>
            {active ? (
              <Tag color="green">#{active.id}</Tag>
            ) : (
              <Tag color="orange">未设置（使用代码内默认模板）</Tag>
            )}
          </Space>
        }
        extra={
          active ? (
            <Text type="secondary">最后更新 {formatTime(active.updated_at)}</Text>
          ) : null
        }
      >
        <Space wrap>
          <Button onClick={reload}>重新加载</Button>
          <Button onClick={handleResetToDefault}>填入代码默认模板</Button>
        </Space>
      </Card>

      <Card title="编辑" size="small">
        <TextArea
          value={draft}
          onChange={e => setDraft(e.target.value)}
          rows={22}
          style={{ fontFamily: 'monospace', fontSize: 13 }}
          placeholder="输入 AI system prompt 模板..."
        />
        <div style={{ marginTop: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Text type="secondary">{draft.length} 字符 · {isDirty ? '已修改未保存' : '与当前激活一致'}</Text>
          <Space>
            <Button
              onClick={() => setDraft(active?.content ?? defaultTemplate)}
              disabled={!isDirty}
            >
              撤销修改
            </Button>
            <Button type="primary" onClick={handleSave} loading={saving} disabled={!isDirty}>
              保存并激活
            </Button>
          </Space>
        </div>
      </Card>

      <Divider />

      <Card title="历史版本" size="small">
        <List
          dataSource={history}
          renderItem={item => (
            <List.Item
              actions={[
                <Button size="small" onClick={() => setPreviewing(item)}>查看</Button>,
                item.is_active ? (
                  <Tag color="green">当前激活</Tag>
                ) : (
                  <Button size="small" type="link" onClick={() => handleActivate(item)}>激活此版本</Button>
                ),
              ]}
            >
              <List.Item.Meta
                title={
                  <Space>
                    <span>#{item.id}</span>
                    <Tag>{item.name}</Tag>
                    {item.is_active && <Tag color="green">active</Tag>}
                  </Space>
                }
                description={
                  <Space split={<span style={{ color: '#bbb' }}>·</span>} wrap>
                    <span>更新于 {formatTime(item.updated_at)}</span>
                    <span>{item.content.length} 字符</span>
                    <span style={{ color: '#999' }}>
                      {item.content.slice(0, 60).replace(/\s+/g, ' ')}…
                    </span>
                  </Space>
                }
              />
            </List.Item>
          )}
          locale={{ emptyText: '暂无历史版本' }}
        />
      </Card>

      <Modal
        open={!!previewing}
        title={previewing ? `历史版本 #${previewing.id}` : ''}
        onCancel={() => setPreviewing(null)}
        footer={
          previewing && !previewing.is_active ? (
            <Space>
              <Button onClick={() => setPreviewing(null)}>关闭</Button>
              <Button
                type="primary"
                onClick={() => {
                  if (previewing) handleActivate(previewing);
                  setPreviewing(null);
                }}
              >
                激活此版本
              </Button>
            </Space>
          ) : (
            <Button onClick={() => setPreviewing(null)}>关闭</Button>
          )
        }
        width={800}
      >
        {previewing && (
          <pre
            style={{
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
              maxHeight: '60vh',
              overflow: 'auto',
              background: '#fafafa',
              padding: 12,
              borderRadius: 4,
              fontSize: 12,
            }}
          >
            {previewing.content}
          </pre>
        )}
      </Modal>
    </div>
  );
};

export default AIPromptManagement;
