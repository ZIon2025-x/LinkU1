/**
 * 任务达人申请弹窗组件
 * 用户申请成为任务达人的弹窗表单
 */

import React, { useState, useEffect } from 'react';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { applyToBeTaskExpert, getMyTaskExpertApplication, fetchCurrentUser } from '../api';
import { MODAL_OVERLAY_STYLE } from './TaskDetailModal.styles';

interface TaskExpertApplicationModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}

interface ApplicationStatus {
  id: number;
  user_id: string;
  application_message?: string;
  status: string;
  reviewed_at?: string;
  review_comment?: string;
  created_at: string;
}

const TaskExpertApplicationModal: React.FC<TaskExpertApplicationModalProps> = ({
  isOpen,
  onClose,
  onSuccess,
}) => {
  useLanguage(); // 保留以维持上下文，t 暂未使用
  const [applicationMessage, setApplicationMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [existingApplication, setExistingApplication] = useState<ApplicationStatus | null>(null);
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    if (isOpen) {
      loadCurrentUser();
      checkExistingApplication();
    } else {
      // 关闭时重置状态
      setApplicationMessage('');
      setExistingApplication(null);
    }
  }, [isOpen]);

  const loadCurrentUser = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
    } catch (err) {
      setUser(null);
    }
  };

  const checkExistingApplication = async () => {
    setLoading(true);
    try {
      const data = await getMyTaskExpertApplication();
      setExistingApplication(data);
      if (data.application_message) {
        setApplicationMessage(data.application_message);
      }
    } catch (err: any) {
      // 如果没有申请记录，忽略错误
      if (err.response?.status !== 404) {
              }
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async () => {
    if (!user) {
      message.warning('请先登录');
      return;
    }

    setSubmitting(true);
    try {
      await applyToBeTaskExpert(applicationMessage || undefined);
      message.success('申请已提交，等待管理员审核');
      setExistingApplication({
        id: 0,
        user_id: user.id,
        application_message: applicationMessage,
        status: 'pending',
        created_at: new Date().toISOString(),
      });
      
      if (onSuccess) {
        onSuccess();
      }
      
      // 延迟关闭，让用户看到成功消息
      setTimeout(() => {
        onClose();
      }, 1500);
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交申请失败');
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen) return null;

  // 如果已有申请，显示申请状态
  if (existingApplication && existingApplication.status !== 'pending') {
    const statusText: { [key: string]: { text: string; color: string; bg: string } } = {
      approved: { text: '已通过', color: '#22543d', bg: '#c6f6d5' },
      rejected: { text: '未通过', color: '#742a2a', bg: '#fed7d7' },
    };

    const status = statusText[existingApplication.status] || { text: existingApplication.status, color: '#2d3748', bg: '#edf2f7' };

    return (
      <div style={MODAL_OVERLAY_STYLE} onClick={onClose}>
        <div
          style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '24px',
            maxWidth: '500px',
            width: '100%',
            position: 'relative',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            onClick={onClose}
            style={{
              position: 'absolute',
              top: '16px',
              right: '16px',
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#666',
              width: '32px',
              height: '32px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: '50%',
              transition: 'background 0.2s',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = '#f0f0f0';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'none';
            }}
          >
            ×
          </button>

          <h2 style={{ marginBottom: '24px', color: '#1a202c', fontSize: '20px', fontWeight: 600 }}>
            申请状态
          </h2>

          <div style={{ marginBottom: '20px' }}>
            <div style={{ marginBottom: '12px', color: '#718096', fontSize: '14px' }}>申请状态</div>
            <div
              style={{
                display: 'inline-block',
                padding: '6px 12px',
                borderRadius: '6px',
                color: status.color,
                background: status.bg,
                fontWeight: 500,
              }}
            >
              {status.text}
            </div>
          </div>

          {existingApplication.application_message && (
            <div style={{ marginBottom: '20px' }}>
              <div style={{ marginBottom: '12px', color: '#718096', fontSize: '14px' }}>申请说明</div>
              <div style={{ padding: '12px', background: '#f7fafc', borderRadius: '8px', color: '#2d3748', whiteSpace: 'pre-wrap' }}>
                {existingApplication.application_message}
              </div>
            </div>
          )}

          {existingApplication.review_comment && (
            <div style={{ marginBottom: '20px' }}>
              <div style={{ marginBottom: '12px', color: '#718096', fontSize: '14px' }}>审核意见</div>
              <div style={{ padding: '12px', background: '#f7fafc', borderRadius: '8px', color: '#2d3748', whiteSpace: 'pre-wrap' }}>
                {existingApplication.review_comment}
              </div>
            </div>
          )}

          {existingApplication.reviewed_at && (
            <div style={{ marginBottom: '20px', fontSize: '14px', color: '#718096' }}>
              审核时间: {new Date(existingApplication.reviewed_at).toLocaleString('zh-CN')}
            </div>
          )}

          <button
            onClick={onClose}
            style={{
              width: '100%',
              padding: '12px',
              background: '#3b82f6',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            关闭
          </button>
        </div>
      </div>
    );
  }

  // 如果已有待审核的申请
  if (existingApplication && existingApplication.status === 'pending') {
    return (
      <div style={MODAL_OVERLAY_STYLE} onClick={onClose}>
        <div
          style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '24px',
            maxWidth: '500px',
            width: '100%',
            position: 'relative',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            onClick={onClose}
            style={{
              position: 'absolute',
              top: '16px',
              right: '16px',
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#666',
            }}
          >
            ×
          </button>

          <h2 style={{ marginBottom: '24px', color: '#1a202c', fontSize: '20px', fontWeight: 600 }}>
            申请状态
          </h2>

          <div style={{ marginBottom: '20px', padding: '16px', background: '#fef3c7', borderRadius: '8px' }}>
            <div style={{ color: '#92400e', fontWeight: 500, marginBottom: '8px' }}>待审核</div>
            <div style={{ color: '#78350f', fontSize: '14px' }}>
              您的申请已提交，正在等待管理员审核，请耐心等待。
            </div>
          </div>

          {existingApplication.application_message && (
            <div style={{ marginBottom: '20px' }}>
              <div style={{ marginBottom: '12px', color: '#718096', fontSize: '14px' }}>申请说明</div>
              <div style={{ padding: '12px', background: '#f7fafc', borderRadius: '8px', color: '#2d3748', whiteSpace: 'pre-wrap' }}>
                {existingApplication.application_message}
              </div>
            </div>
          )}

          <div style={{ marginBottom: '20px', fontSize: '14px', color: '#718096' }}>
            申请时间: {new Date(existingApplication.created_at).toLocaleString('zh-CN')}
          </div>

          <button
            onClick={onClose}
            style={{
              width: '100%',
              padding: '12px',
              background: '#3b82f6',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            关闭
          </button>
        </div>
      </div>
    );
  }

  // 申请表单
  return (
    <div style={MODAL_OVERLAY_STYLE} onClick={onClose}>
      <div
        style={{
          backgroundColor: '#fff',
          borderRadius: '16px',
          padding: '24px',
          maxWidth: '500px',
          width: '100%',
          position: 'relative',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            background: 'none',
            border: 'none',
            fontSize: '24px',
            cursor: 'pointer',
            color: '#666',
            width: '32px',
            height: '32px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '50%',
            transition: 'background 0.2s',
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = '#f0f0f0';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'none';
          }}
        >
          ×
        </button>

        <h2 style={{ marginBottom: '24px', color: '#1a202c', fontSize: '20px', fontWeight: 600 }}>
          申请成为任务达人
        </h2>

        <div style={{ marginBottom: '20px', padding: '12px', background: '#edf2f7', borderRadius: '8px', fontSize: '14px', color: '#4a5568' }}>
          成为任务达人后，您可以发布自己的服务菜单，其他用户可以向您的服务发起申请。
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
            申请说明（可选）
          </label>
          <textarea
            value={applicationMessage}
            onChange={(e) => setApplicationMessage(e.target.value)}
            placeholder="请简要说明您的技能、经验等，帮助管理员更好地了解您..."
            style={{
              width: '100%',
              minHeight: '120px',
              padding: '12px',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              fontSize: '14px',
              resize: 'vertical',
              fontFamily: 'inherit',
            }}
          />
        </div>

        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            onClick={handleSubmit}
            disabled={submitting || loading}
            style={{
              flex: 1,
              padding: '12px',
              background: submitting || loading
                ? '#cbd5e0'
                : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 600,
              cursor: submitting || loading ? 'not-allowed' : 'pointer',
              transition: 'all 0.2s',
            }}
          >
            {submitting ? '提交中...' : '提交申请'}
          </button>
          <button
            onClick={onClose}
            style={{
              padding: '12px 24px',
              background: '#f7fafc',
              color: '#2d3748',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            取消
          </button>
        </div>
      </div>
    </div>
  );
};

export default TaskExpertApplicationModal;

