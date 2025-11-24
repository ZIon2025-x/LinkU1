import React from 'react';
import { TaskApplication } from '../../types/task';
import { useLocalizedNavigation } from '../../hooks/useLocalizedNavigation';
import { TimeHandlerV2 } from '../../utils/timeUtils';

interface ApplicantListProps {
  applications: TaskApplication[];
  loadingApplications: boolean;
  actionLoading: boolean;
  onApproveApplication: (applicationId: number) => Promise<void>;
  onRejectApplication: (applicationId: number) => Promise<void>;
  taskId?: number; // 添加任务ID，用于跳转到任务聊天
  t: (key: string) => string;
}

const ApplicantList: React.FC<ApplicantListProps> = ({
  applications,
  loadingApplications,
  actionLoading,
  onApproveApplication,
  onRejectApplication,
  taskId,
  t
}) => {
  const { navigate } = useLocalizedNavigation();

  return (
    <div style={{
      marginTop: '20px',
      padding: '20px',
      background: '#f8f9fa',
      borderRadius: '12px',
      border: '1px solid #e9ecef'
    }}>
      <h3 style={{ margin: '0 0 16px 0', color: '#333', fontSize: '18px' }}>
        {t('taskDetail.applicantList').replace('{count}', applications.length.toString())}
      </h3>
      
      {loadingApplications ? (
        <div style={{ textAlign: 'center', padding: '20px' }}>
          {t('taskDetail.loadingApplicants')}
        </div>
      ) : applications.length === 0 ? (
        <div style={{ 
          textAlign: 'center', 
          padding: '20px', 
          color: '#666',
          background: '#fff',
          borderRadius: '8px',
          border: '1px solid #e9ecef'
        }}>
          {t('taskDetail.noApplicants')}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {applications.map((app) => (
            <div key={app.id} style={{
              background: '#fff',
              padding: '16px',
              borderRadius: '8px',
              border: '1px solid #e9ecef',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center'
            }}>
              <div>
                <div style={{ fontWeight: '600', color: '#333', marginBottom: '4px' }}>
                  {app.applicant_name}
                </div>
                {app.message && (
                  <div style={{ color: '#666', fontSize: '14px', marginBottom: '4px' }}>
                    "{app.message}"
                  </div>
                )}
                {(app.negotiated_price !== undefined && app.negotiated_price !== null) && (
                  <div style={{
                    fontSize: '13px',
                    fontWeight: 600,
                    color: '#92400e',
                    padding: '4px 8px',
                    background: '#fef3c7',
                    borderRadius: '4px',
                    display: 'inline-block',
                    marginBottom: '4px',
                    marginTop: '4px'
                  }}>
                    议价: {app.negotiated_price} {app.currency || 'GBP'}
                  </div>
                )}
                {app.created_at && (() => {
                  try {
                    const formattedDate = TimeHandlerV2.formatUtcToLocal(app.created_at);
                    // 检查是否是有效的日期字符串
                    if (formattedDate && formattedDate !== 'Invalid Date' && !formattedDate.includes('Invalid')) {
                      return (
                        <div style={{ color: '#999', fontSize: '12px' }}>
                          {t('taskDetail.applicationTime')}: {formattedDate}
                        </div>
                      );
                    }
                  } catch (e) {
                    // 日期格式化失败，不显示
                  }
                  return null;
                })()}
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button
                  onClick={() => onApproveApplication(app.id)}
                  disabled={actionLoading || app.status !== 'pending'}
                  style={{
                    background: app.status !== 'pending' ? '#6c757d' : '#28a745',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '6px',
                    padding: '8px 16px',
                    fontWeight: '600',
                    cursor: (actionLoading || app.status !== 'pending') ? 'not-allowed' : 'pointer',
                    opacity: (actionLoading || app.status !== 'pending') ? 0.6 : 1,
                    fontSize: '14px'
                  }}
                >
                  {actionLoading ? t('taskDetail.processing') : t('taskDetail.approve')}
                </button>
                <button
                  onClick={() => onRejectApplication(app.id)}
                  disabled={actionLoading || app.status !== 'pending'}
                  style={{
                    background: app.status !== 'pending' ? '#6c757d' : '#dc3545',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '6px',
                    padding: '8px 16px',
                    fontWeight: '600',
                    cursor: (actionLoading || app.status !== 'pending') ? 'not-allowed' : 'pointer',
                    opacity: (actionLoading || app.status !== 'pending') ? 0.6 : 1,
                    fontSize: '14px'
                  }}
                >
                  {actionLoading ? t('taskDetail.processing') : t('taskDetail.reject')}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default ApplicantList;


