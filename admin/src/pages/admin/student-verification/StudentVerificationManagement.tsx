import React, { useState } from 'react';
import { message, Modal } from 'antd';
import { revokeStudentVerification, extendStudentVerification } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

const REASON_TYPES = [
  { value: 'user_request', label: '用户自行申请注销' },
  { value: 'violation', label: '涉嫌违规使用' },
  { value: 'account_hacked', label: '账号被盗' },
  { value: 'other', label: '其他原因' },
];

const StudentVerificationManagement: React.FC = () => {
  const [verificationId, setVerificationId] = useState<string>('');
  const [revokeReasonType, setRevokeReasonType] = useState<string>('user_request');
  const [revokeReasonDetail, setRevokeReasonDetail] = useState<string>('');
  const [extendDate, setExtendDate] = useState<string>('');
  const [loading, setLoading] = useState(false);

  const handleRevoke = () => {
    const id = parseInt(verificationId, 10);
    if (!verificationId || isNaN(id)) {
      message.warning('请输入有效的认证记录 ID');
      return;
    }
    if (!revokeReasonDetail.trim()) {
      message.warning('请输入撤销原因详情');
      return;
    }
    if (revokeReasonType === 'other' && revokeReasonDetail.trim().length < 10) {
      message.warning('选择「其他原因」时，详情至少 10 个字符');
      return;
    }
    Modal.confirm({
      title: '确认撤销学生认证',
      content: `将撤销认证记录 #${id}，并释放该邮箱。确定继续？`,
      onOk: async () => {
        setLoading(true);
        try {
          await revokeStudentVerification(id, {
            reason_type: revokeReasonType,
            reason_detail: revokeReasonDetail.trim(),
          });
          message.success('已提交撤销，通知邮件将发送给用户');
          setVerificationId('');
          setRevokeReasonDetail('');
        } catch (e) {
          message.error(getErrorMessage(e));
        } finally {
          setLoading(false);
        }
      },
    });
  };

  const handleExtend = () => {
    const id = parseInt(verificationId, 10);
    if (!verificationId || isNaN(id)) {
      message.warning('请输入有效的认证记录 ID');
      return;
    }
    if (!extendDate) {
      message.warning('请选择新的过期时间');
      return;
    }
    setLoading(true);
    extendStudentVerification(id, { new_expires_at: extendDate })
      .then(() => {
        message.success('已延长认证有效期');
        setVerificationId('');
        setExtendDate('');
      })
      .catch((e) => message.error(getErrorMessage(e)))
      .finally(() => setLoading(false));
  };

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>学生认证管理</h2>
      <p style={{ color: '#666', marginBottom: '20px' }}>
        撤销或延长学生认证。认证记录 ID 可从用户详情或后台数据中获取。
      </p>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '500px' }}>
        <div style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.08)' }}>
          <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>撤销认证</h3>
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>认证记录 ID</label>
            <input
              type="number"
              value={verificationId}
              onChange={(e) => setVerificationId(e.target.value)}
              placeholder="例如 1"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>撤销原因类型</label>
            <select
              value={revokeReasonType}
              onChange={(e) => setRevokeReasonType(e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            >
              {REASON_TYPES.map((r) => (
                <option key={r.value} value={r.value}>{r.label}</option>
              ))}
            </select>
          </div>
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>撤销原因详情</label>
            <textarea
              value={revokeReasonDetail}
              onChange={(e) => setRevokeReasonDetail(e.target.value)}
              placeholder="必填，若选「其他原因」至少 10 字"
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <button
            type="button"
            onClick={handleRevoke}
            disabled={loading}
            style={{ padding: '8px 16px', background: '#ff4d4f', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
          >
            {loading ? '提交中...' : '撤销认证'}
          </button>
        </div>

        <div style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.08)' }}>
          <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>延长认证</h3>
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>认证记录 ID</label>
            <input
              type="number"
              value={verificationId}
              onChange={(e) => setVerificationId(e.target.value)}
              placeholder="例如 1"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', marginBottom: '4px', fontWeight: 'bold' }}>新的过期时间</label>
            <input
              type="datetime-local"
              value={extendDate}
              onChange={(e) => setExtendDate(e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <button
            type="button"
            onClick={handleExtend}
            disabled={loading}
            style={{ padding: '8px 16px', background: '#52c41a', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
          >
            {loading ? '提交中...' : '延长认证'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default StudentVerificationManagement;
