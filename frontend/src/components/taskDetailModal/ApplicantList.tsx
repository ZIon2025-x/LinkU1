import React from 'react';
import { TaskApplication } from '../../types/task';
import { useLocalizedNavigation } from '../../hooks/useLocalizedNavigation';
import { TimeHandlerV2 } from '../../utils/timeUtils';

interface ApplicantListProps {
  applications: TaskApplication[];
  loadingApplications: boolean;
  actionLoading: boolean;
  onApproveApplication: (applicantId: string) => Promise<void>;
  taskId?: number; // 添加任务ID，用于跳转到任务聊天
  t: (key: string) => string;
}

const ApplicantList: React.FC<ApplicantListProps> = ({
  applications,
  loadingApplications,
  actionLoading,
  onApproveApplication,
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
                <div style={{ color: '#999', fontSize: '12px' }}>
                  {t('taskDetail.applicationTime')}: {TimeHandlerV2.formatUtcToLocal(app.created_at)}
                </div>
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button
                  onClick={() => taskId && navigate(`/message?taskId=${taskId}`)}
                  style={{
                    background: '#007bff',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '6px',
                    padding: '8px 16px',
                    fontWeight: '600',
                    cursor: 'pointer',
                    fontSize: '14px'
                  }}
                >
                  {t('taskDetail.contact')}
                </button>
                <button
                  onClick={() => onApproveApplication(app.applicant_id)}
                  disabled={actionLoading}
                  style={{
                    background: '#28a745',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '6px',
                    padding: '8px 16px',
                    fontWeight: '600',
                    cursor: actionLoading ? 'not-allowed' : 'pointer',
                    opacity: actionLoading ? 0.6 : 1,
                    fontSize: '14px'
                  }}
                >
                  {actionLoading ? t('taskDetail.processing') : t('taskDetail.approve')}
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


