import React, { useState, useEffect, useCallback } from 'react';
import { message } from 'antd';
import { getForumReports, processForumReport, getFleaMarketReports, processFleaMarketReport } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type ReportStatus = 'pending' | 'processed' | 'rejected' | 'reviewing' | 'resolved';
type SubTab = 'forum' | 'flea_market';

/**
 * 举报管理组件
 * 管理论坛和跳蚤市场的举报
 */
const ReportManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('forum');
  
  // 论坛举报状态
  const [forumReports, setForumReports] = useState<any[]>([]);
  const [forumLoading, setForumLoading] = useState(false);
  const [forumPage, setForumPage] = useState(1);
  const [forumTotal, setForumTotal] = useState(0);
  const [forumStatusFilter, setForumStatusFilter] = useState<string>('');

  // 跳蚤市场举报状态
  const [fleaReports, setFleaReports] = useState<any[]>([]);
  const [fleaLoading, setFleaLoading] = useState(false);
  const [fleaPage, setFleaPage] = useState(1);
  const [fleaTotal, setFleaTotal] = useState(0);
  const [fleaStatusFilter, setFleaStatusFilter] = useState<string>('');

  const loadForumReports = useCallback(async () => {
    setForumLoading(true);
    try {
      const response = await getForumReports({
        status_filter: forumStatusFilter as any || undefined,
        page: forumPage,
        page_size: 20
      });
      setForumReports(response.items || []);
      setForumTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setForumLoading(false);
    }
  }, [forumPage, forumStatusFilter]);

  const loadFleaReports = useCallback(async () => {
    setFleaLoading(true);
    try {
      const response = await getFleaMarketReports({
        status_filter: fleaStatusFilter as any || undefined,
        page: fleaPage,
        page_size: 20
      });
      setFleaReports(response.items || []);
      setFleaTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setFleaLoading(false);
    }
  }, [fleaPage, fleaStatusFilter]);

  useEffect(() => {
    if (subTab === 'forum') {
      loadForumReports();
    } else {
      loadFleaReports();
    }
  }, [subTab, loadForumReports, loadFleaReports]);

  const handleProcessForumReport = async (reportId: number, status: 'processed' | 'rejected', action?: string) => {
    try {
      await processForumReport(reportId, { status, action });
      message.success('举报处理成功');
      loadForumReports();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleProcessFleaReport = async (reportId: number, status: 'resolved' | 'rejected') => {
    try {
      await processFleaMarketReport(reportId, { status });
      message.success('举报处理成功');
      loadFleaReports();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const getStatusBadge = (status: string) => {
    const styles: Record<string, { bg: string; color: string; text: string }> = {
      pending: { bg: '#fff3cd', color: '#856404', text: '待处理' },
      processed: { bg: '#d4edda', color: '#155724', text: '已处理' },
      rejected: { bg: '#f8d7da', color: '#721c24', text: '已拒绝' },
      reviewing: { bg: '#d1ecf1', color: '#0c5460', text: '审核中' },
      resolved: { bg: '#d4edda', color: '#155724', text: '已解决' }
    };
    const s = styles[status] || styles.pending;
    return <span style={{ padding: '4px 8px', borderRadius: '4px', background: s.bg, color: s.color, fontSize: '12px', fontWeight: '500' }}>{s.text}</span>;
  };

  const renderTable = (reports: any[], loading: boolean, type: 'forum' | 'flea_market') => (
    <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
      {loading ? (
        <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
      ) : reports.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无举报</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>
                {type === 'forum' ? '类型' : '商品ID'}
              </th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>
                {type === 'forum' ? '目标ID' : '商品标题'}
              </th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>举报原因</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report: any) => (
              <tr key={report.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                <td style={{ padding: '12px' }}>{report.id}</td>
                <td style={{ padding: '12px' }}>
                  {type === 'forum' ? (report.target_type === 'post' ? '帖子' : '回复') : report.item_id}
                </td>
                <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {type === 'forum' ? report.target_id : (report.item_title || '-')}
                </td>
                <td style={{ padding: '12px' }}>{report.reason}</td>
                <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {report.description || '-'}
                </td>
                <td style={{ padding: '12px' }}>{getStatusBadge(report.status)}</td>
                <td style={{ padding: '12px' }}>
                  {report.status === 'pending' && (
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => type === 'forum' ? handleProcessForumReport(report.id, 'processed') : handleProcessFleaReport(report.id, 'resolved')}
                        style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                      >
                        处理
                      </button>
                      <button
                        onClick={() => type === 'forum' ? handleProcessForumReport(report.id, 'rejected') : handleProcessFleaReport(report.id, 'rejected')}
                        style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
                      >
                        拒绝
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );

  const renderPagination = (page: number, total: number, setPage: (p: number) => void) => {
    const totalPages = Math.ceil(total / 20);
    if (total <= 20) return null;
    return (
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: '20px', gap: '10px' }}>
        <button onClick={() => page > 1 && setPage(page - 1)} disabled={page === 1} style={{ padding: '8px 16px', border: '1px solid #ddd', background: page === 1 ? '#f5f5f5' : 'white', borderRadius: '4px', cursor: page === 1 ? 'not-allowed' : 'pointer' }}>上一页</button>
        <span style={{ padding: '8px 16px', alignSelf: 'center' }}>第 {page} 页，共 {totalPages} 页</span>
        <button onClick={() => page < totalPages && setPage(page + 1)} disabled={page >= totalPages} style={{ padding: '8px 16px', border: '1px solid #ddd', background: page >= totalPages ? '#f5f5f5' : 'white', borderRadius: '4px', cursor: page >= totalPages ? 'not-allowed' : 'pointer' }}>下一页</button>
      </div>
    );
  };

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>举报管理</h2>

      {/* 子标签页 */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        <button
          onClick={() => { setSubTab('forum'); setForumPage(1); }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: subTab === 'forum' ? '#007bff' : '#f0f0f0',
            color: subTab === 'forum' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          论坛举报
        </button>
        <button
          onClick={() => { setSubTab('flea_market'); setFleaPage(1); }}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: subTab === 'flea_market' ? '#007bff' : '#f0f0f0',
            color: subTab === 'flea_market' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          商品举报
        </button>
      </div>

      {/* 筛选 */}
      <div style={{ background: 'white', padding: '16px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', marginBottom: '20px' }}>
        <select
          value={subTab === 'forum' ? forumStatusFilter : fleaStatusFilter}
          onChange={(e) => {
            if (subTab === 'forum') {
              setForumStatusFilter(e.target.value);
              setForumPage(1);
            } else {
              setFleaStatusFilter(e.target.value);
              setFleaPage(1);
            }
          }}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
        >
          <option value="">全部状态</option>
          <option value="pending">待处理</option>
          <option value={subTab === 'forum' ? 'processed' : 'resolved'}>{subTab === 'forum' ? '已处理' : '已解决'}</option>
          <option value="rejected">已拒绝</option>
        </select>
        <button
          onClick={() => subTab === 'forum' ? loadForumReports() : loadFleaReports()}
          style={{ marginLeft: '10px', padding: '8px 16px', border: 'none', background: '#007bff', color: 'white', borderRadius: '4px', cursor: 'pointer' }}
        >
          刷新
        </button>
      </div>

      {/* 内容 */}
      {subTab === 'forum' ? (
        <>
          {renderTable(forumReports, forumLoading, 'forum')}
          {renderPagination(forumPage, forumTotal, setForumPage)}
        </>
      ) : (
        <>
          {renderTable(fleaReports, fleaLoading, 'flea_market')}
          {renderPagination(fleaPage, fleaTotal, setFleaPage)}
        </>
      )}
    </div>
  );
};

export default ReportManagement;
