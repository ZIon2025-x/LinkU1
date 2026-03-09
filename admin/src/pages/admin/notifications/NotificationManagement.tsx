import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { sendAdminNotification } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface NotificationForm {
  title: string;
  content: string;
  user_ids_input: string;   // 原始输入文本，绑定到输入框
}

const initialForm: NotificationForm = {
  title: '',
  content: '',
  user_ids_input: '',
};

/**
 * 通知管理组件
 * 发送通知给用户
 */
const NotificationManagement: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState<NotificationForm>(initialForm);

  const handleSendNotification = useCallback(async () => {
    if (!form.title || !form.content) {
      message.warning('请填写通知标题和内容');
      return;
    }

    // 解析用户ID：逗号分隔，过滤空白
    const parsedIds = form.user_ids_input
      .split(',')
      .map(id => id.trim())
      .filter(id => id.length > 0);

    setLoading(true);
    try {
      await sendAdminNotification({
        title: form.title,
        content: form.content,
        // 有 ID 时传数组，否则不传（后端收到 null → 发给所有人）
        user_ids: parsedIds.length > 0 ? parsedIds : undefined as any,
      });
      const target = parsedIds.length > 0
        ? `已发送给 ${parsedIds.length} 个指定用户`
        : '已发送给所有用户';
      message.success(`通知发送成功！${target}`);
      setForm(initialForm);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, [form]);

  const handleReset = useCallback(() => {
    setForm(initialForm);
  }, []);

  return (
    <div style={{ padding: '0' }}>
      <h2 style={{ marginBottom: '20px' }}>发送通知</h2>

      <div style={{
        background: 'white',
        padding: '24px',
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginBottom: '20px',
      }}>
        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
            通知标题：
          </label>
          <input
            type="text"
            placeholder="请输入通知标题"
            value={form.title}
            onChange={(e) => setForm(prev => ({ ...prev, title: e.target.value }))}
            style={{
              width: '100%',
              padding: '10px 14px',
              border: '1px solid #d9d9d9',
              borderRadius: '6px',
              fontSize: '14px',
            }}
          />
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
            通知内容：
          </label>
          <textarea
            placeholder="请输入通知内容"
            value={form.content}
            onChange={(e) => setForm(prev => ({ ...prev, content: e.target.value }))}
            rows={6}
            style={{
              width: '100%',
              padding: '10px 14px',
              border: '1px solid #d9d9d9',
              borderRadius: '6px',
              fontSize: '14px',
              resize: 'vertical',
            }}
          />
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
            目标用户ID（留空发送给所有用户）：
          </label>
          <input
            type="text"
            placeholder="用逗号分隔多个用户ID，如：1,2,3"
            value={form.user_ids_input}
            onChange={(e) => setForm(prev => ({ ...prev, user_ids_input: e.target.value }))}
            style={{
              width: '100%',
              padding: '10px 14px',
              border: '1px solid #d9d9d9',
              borderRadius: '6px',
              fontSize: '14px',
            }}
          />
          <small style={{ color: '#666', fontSize: '12px', marginTop: '4px', display: 'block' }}>
            提示：留空用户ID将发送给所有用户，填写用户ID将只发送给指定用户
          </small>
        </div>

        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            onClick={handleSendNotification}
            disabled={loading || !form.title || !form.content}
            style={{
              padding: '10px 24px',
              border: 'none',
              borderRadius: '6px',
              background: '#007bff',
              color: 'white',
              fontSize: '14px',
              fontWeight: '500',
              cursor: loading || !form.title || !form.content ? 'not-allowed' : 'pointer',
              opacity: loading || !form.title || !form.content ? 0.6 : 1,
            }}
          >
            {loading ? '发送中...' : '发送通知'}
          </button>
          <button
            onClick={handleReset}
            style={{
              padding: '10px 24px',
              border: '1px solid #d9d9d9',
              borderRadius: '6px',
              background: 'white',
              color: '#333',
              fontSize: '14px',
              cursor: 'pointer',
            }}
          >
            清空表单
          </button>
        </div>
      </div>

      <div style={{
        background: '#e7f3ff',
        padding: '16px 20px',
        borderRadius: '8px',
        border: '1px solid #b3d7ff',
      }}>
        <h4 style={{ margin: '0 0 12px 0', color: '#0056b3' }}>通知发送说明：</h4>
        <ul style={{ margin: 0, paddingLeft: '20px', color: '#333' }}>
          <li>通知标题和内容为必填项</li>
          <li>用户ID留空时，通知将发送给所有用户</li>
          <li>填写用户ID时，通知只发送给指定用户</li>
          <li>多个用户ID用逗号分隔，如：1,2,3</li>
          <li>发送后用户将在通知中心收到此消息</li>
        </ul>
      </div>
    </div>
  );
};

export default NotificationManagement;
