import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
import {
  getAdminTaskDisputes,
  getAdminTaskDisputeDetail,
  resolveTaskDispute,
  dismissTaskDispute
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import {
  TaskDispute,
  DisputeStatus,
  DisputeAction,
  DISPUTE_STATUS_LABELS,
  DISPUTE_STATUS_COLORS,
  TASK_STATUS_LABELS,
  TASK_STATUS_COLORS
} from './types';
import styles from './DisputeManagement.module.css';

/**
 * 争议管理组件
 * 提供任务争议列表查看、详情查看、解决/驳回等功能
 */
const DisputeManagement: React.FC = () => {
  // 列表状态
  const [disputes, setDisputes] = useState<TaskDispute[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const pageSize = 20;

  // 筛选状态
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [searchKeyword, setSearchKeyword] = useState<string>('');

  // 详情弹窗状态
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedDispute, setSelectedDispute] = useState<TaskDispute | null>(null);

  // 处理弹窗状态
  const [showActionModal, setShowActionModal] = useState(false);
  const [disputeAction, setDisputeAction] = useState<DisputeAction>('resolve');
  const [resolutionNote, setResolutionNote] = useState('');
  const [processing, setProcessing] = useState(false);

  // 加载争议列表
  const loadDisputes = useCallback(async () => {
    try {
      setLoading(true);
      const response = await getAdminTaskDisputes({
        skip: (page - 1) * pageSize,
        limit: pageSize,
        status: statusFilter || undefined,
        keyword: searchKeyword.trim() || undefined
      });
      setDisputes(response.disputes || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, searchKeyword]);

  // 初始加载和依赖变化时重新加载
  useEffect(() => {
    loadDisputes();
  }, [loadDisputes]);

  // 自动刷新待处理争议（每30秒）
  useEffect(() => {
    const refreshInterval = setInterval(() => {
      if (!loading && (!statusFilter || statusFilter === 'pending')) {
        loadDisputes();
      }
    }, 30000);

    return () => clearInterval(refreshInterval);
  }, [loading, statusFilter, loadDisputes]);

  // 查看争议详情
  const handleViewDetail = async (disputeId: number) => {
    try {
      const dispute = await getAdminTaskDisputeDetail(disputeId);
      setSelectedDispute(dispute);
      setShowDetailModal(true);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  // 打开处理弹窗
  const handleOpenAction = (dispute: TaskDispute, action: DisputeAction) => {
    setSelectedDispute(dispute);
    setDisputeAction(action);
    setResolutionNote('');
    setShowActionModal(true);
  };

  // 执行处理操作
  const handleAction = async () => {
    if (!selectedDispute || !resolutionNote.trim()) {
      message.error('请输入处理备注');
      return;
    }

    try {
      setProcessing(true);
      if (disputeAction === 'resolve') {
        await resolveTaskDispute(selectedDispute.id, resolutionNote.trim());
        message.success('争议已解决');
      } else {
        await dismissTaskDispute(selectedDispute.id, resolutionNote.trim());
        message.success('争议已驳回');
      }
      setShowActionModal(false);
      setResolutionNote('');
      setSelectedDispute(null);
      await loadDisputes();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setProcessing(false);
    }
  };

  // 搜索处理
  const handleSearch = () => {
    setPage(1);
    loadDisputes();
  };

  // 清除搜索
  const handleClearSearch = () => {
    setSearchKeyword('');
    setPage(1);
  };

  // 状态筛选变化
  const handleStatusFilterChange = (value: string) => {
    setStatusFilter(value);
    setPage(1);
  };

  // 获取状态样式
  const getStatusStyle = (status: DisputeStatus) => {
    const colors = DISPUTE_STATUS_COLORS[status] || DISPUTE_STATUS_COLORS.pending;
    return { background: colors.bg, color: colors.color };
  };

  // 获取任务状态样式
  const getTaskStatusStyle = (status: string) => {
    const colors = TASK_STATUS_COLORS[status] || { bg: '#e9ecef', color: '#6c757d' };
    return { background: colors.bg, color: colors.color };
  };

  const totalPages = Math.ceil(total / pageSize);

  return (
    <div className={styles.container}>
      <h2 className={styles.title}>任务争议管理</h2>

      {/* 筛选和搜索 */}
      <div className={styles.filterContainer}>
        <input
          type="text"
          placeholder="搜索任务标题、发布者姓名或争议原因..."
          value={searchKeyword}
          onChange={(e) => setSearchKeyword(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
          className={styles.searchInput}
        />
        <select
          value={statusFilter}
          onChange={(e) => handleStatusFilterChange(e.target.value)}
          className={styles.filterSelect}
        >
          <option value="">全部状态</option>
          <option value="pending">待处理</option>
          <option value="resolved">已解决</option>
          <option value="dismissed">已驳回</option>
        </select>
        <button onClick={handleSearch} className={`${styles.filterBtn} ${styles.filterBtnPrimary}`}>
          搜索
        </button>
        {searchKeyword && (
          <button onClick={handleClearSearch} className={`${styles.filterBtn} ${styles.filterBtnClear}`}>
            清除
          </button>
        )}
      </div>

      {/* 争议列表 */}
      <div className={styles.tableContainer}>
        {loading ? (
          <div className={styles.loadingState}>加载中...</div>
        ) : disputes.length === 0 ? (
          <div className={styles.emptyState}>
            {searchKeyword ? '未找到匹配的争议记录' : '暂无争议记录'}
          </div>
        ) : (
          <table className={styles.table}>
            <thead className={styles.tableHeader}>
              <tr>
                <th className={styles.tableHeaderCell}>ID</th>
                <th className={styles.tableHeaderCell}>任务</th>
                <th className={styles.tableHeaderCell}>发布者</th>
                <th className={styles.tableHeaderCell}>争议原因</th>
                <th className={styles.tableHeaderCell}>状态</th>
                <th className={styles.tableHeaderCell}>创建时间</th>
                <th className={styles.tableHeaderCell}>操作</th>
              </tr>
            </thead>
            <tbody>
              {disputes.map((dispute) => (
                <tr key={dispute.id} className={styles.tableRow}>
                  <td className={styles.tableCell}>{dispute.id}</td>
                  <td className={`${styles.tableCell} ${styles.tableCellTruncate}`}>
                    {dispute.task_title} (#{dispute.task_id})
                  </td>
                  <td className={styles.tableCell}>{dispute.poster_name}</td>
                  <td className={`${styles.tableCell} ${styles.tableCellReason}`}>
                    {dispute.reason}
                  </td>
                  <td className={styles.tableCell}>
                    <span 
                      className={styles.statusBadge} 
                      style={getStatusStyle(dispute.status)}
                    >
                      {DISPUTE_STATUS_LABELS[dispute.status]}
                    </span>
                  </td>
                  <td className={styles.tableCell}>
                    {new Date(dispute.created_at).toLocaleString('zh-CN')}
                  </td>
                  <td className={styles.tableCell}>
                    <div className={styles.actionGroup}>
                      <button
                        onClick={() => handleViewDetail(dispute.id)}
                        className={`${styles.actionBtn} ${styles.btnView}`}
                      >
                        查看
                      </button>
                      {dispute.status === 'pending' && (
                        <>
                          <button
                            onClick={() => handleOpenAction(dispute, 'resolve')}
                            className={`${styles.actionBtn} ${styles.btnResolve}`}
                          >
                            解决
                          </button>
                          <button
                            onClick={() => handleOpenAction(dispute, 'dismiss')}
                            className={`${styles.actionBtn} ${styles.btnDismiss}`}
                          >
                            驳回
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      {total > pageSize && (
        <div className={styles.pagination}>
          <button
            onClick={() => setPage((prev) => Math.max(1, prev - 1))}
            disabled={page === 1}
            className={styles.pageBtn}
          >
            上一页
          </button>
          <span className={styles.pageInfo}>
            第 {page} 页，共 {totalPages} 页
          </span>
          <button
            onClick={() => setPage((prev) => prev + 1)}
            disabled={page >= totalPages}
            className={styles.pageBtn}
          >
            下一页
          </button>
        </div>
      )}

      {/* 争议详情弹窗 */}
      <Modal
        title={`争议详情 #${selectedDispute?.id || ''}`}
        open={showDetailModal}
        onCancel={() => {
          setShowDetailModal(false);
          setSelectedDispute(null);
        }}
        footer={null}
        width={800}
      >
        {selectedDispute && (
          <div style={{ padding: '20px' }}>
            {/* 任务信息 */}
            <div className={styles.modalSection}>
              <h3 className={styles.modalSectionTitle}>任务信息</h3>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>任务标题：</span>
                <span className={styles.modalValue}>
                  {selectedDispute.task_title || `任务 #${selectedDispute.task_id}`}
                </span>
              </div>
              {selectedDispute.task_description && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>任务描述：</span>
                  <div className={styles.modalTextBlock}>
                    {selectedDispute.task_description}
                  </div>
                </div>
              )}
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>任务状态：</span>
                <span 
                  className={styles.statusBadge}
                  style={{ ...getTaskStatusStyle(selectedDispute.task_status || ''), marginLeft: '8px' }}
                >
                  {TASK_STATUS_LABELS[selectedDispute.task_status || ''] || selectedDispute.task_status || '未知'}
                </span>
              </div>
              {selectedDispute.task_created_at && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>任务创建时间：</span>
                  <span className={styles.modalValue}>
                    {new Date(selectedDispute.task_created_at).toLocaleString('zh-CN')}
                  </span>
                </div>
              )}
            </div>

            {/* 参与方信息 */}
            <div className={styles.modalSection}>
              <h3 className={styles.modalSectionTitle}>参与方信息</h3>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>发布者ID：</span>
                <span className={styles.modalValue}>{selectedDispute.poster_id}</span>
              </div>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>发布者姓名：</span>
                <span className={styles.modalValue}>{selectedDispute.poster_name || '未设置'}</span>
              </div>
              {selectedDispute.taker_id ? (
                <>
                  <div className={styles.modalField}>
                    <span className={styles.modalLabel}>接受者ID：</span>
                    <span className={styles.modalValue}>{selectedDispute.taker_id}</span>
                  </div>
                  <div className={styles.modalField}>
                    <span className={styles.modalLabel}>接受者姓名：</span>
                    <span className={styles.modalValue}>{selectedDispute.taker_name || '未设置'}</span>
                  </div>
                </>
              ) : (
                <div className={styles.modalField} style={{ color: '#999' }}>
                  暂无接受者
                </div>
              )}
            </div>

            {/* 支付信息 */}
            <div className={styles.modalSection}>
              <h3 className={styles.modalSectionTitle}>支付信息</h3>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>任务金额：</span>
                <span className={styles.modalValue}>
                  {selectedDispute.task_amount != null
                    ? `${selectedDispute.currency || 'GBP'} ${Number(selectedDispute.task_amount).toFixed(2)}`
                    : '未设置'}
                </span>
              </div>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>支付状态：</span>
                <span 
                  className={styles.statusBadge}
                  style={{ 
                    background: selectedDispute.is_paid ? '#d4edda' : '#f8d7da',
                    color: selectedDispute.is_paid ? '#155724' : '#721c24',
                    marginLeft: '8px'
                  }}
                >
                  {selectedDispute.is_paid ? '✅ 已支付' : '⏳ 未支付'}
                </span>
              </div>
              {selectedDispute.payment_intent_id && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>支付Intent ID：</span>
                  <code className={styles.codeBlock}>{selectedDispute.payment_intent_id}</code>
                </div>
              )}
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>托管金额：</span>
                <span className={styles.modalValue}>
                  {selectedDispute.currency || 'GBP'} {Number(selectedDispute.escrow_amount || 0).toFixed(2)}
                </span>
              </div>
            </div>

            {/* 争议信息 */}
            <div className={styles.modalSection}>
              <h3 className={styles.modalSectionTitle}>争议信息</h3>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>争议原因：</span>
                <div className={styles.modalTextBlock}>{selectedDispute.reason}</div>
              </div>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>状态：</span>
                <span 
                  className={styles.statusBadge} 
                  style={getStatusStyle(selectedDispute.status)}
                >
                  {DISPUTE_STATUS_LABELS[selectedDispute.status]}
                </span>
              </div>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>创建时间：</span>
                <span className={styles.modalValue}>
                  {new Date(selectedDispute.created_at).toLocaleString('zh-CN')}
                </span>
              </div>
              {selectedDispute.resolved_at && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>处理时间：</span>
                  <span className={styles.modalValue}>
                    {new Date(selectedDispute.resolved_at).toLocaleString('zh-CN')}
                  </span>
                </div>
              )}
              {selectedDispute.resolver_name && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>处理人：</span>
                  <span className={styles.modalValue}>{selectedDispute.resolver_name}</span>
                </div>
              )}
              {selectedDispute.resolution_note && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>处理备注：</span>
                  <div className={styles.modalTextBlock}>{selectedDispute.resolution_note}</div>
                </div>
              )}
            </div>
          </div>
        )}
      </Modal>

      {/* 处理争议弹窗 */}
      <Modal
        title={disputeAction === 'resolve' ? '解决争议' : '驳回争议'}
        open={showActionModal}
        onCancel={() => {
          setShowActionModal(false);
          setResolutionNote('');
          setSelectedDispute(null);
        }}
        onOk={handleAction}
        confirmLoading={processing}
        okText={disputeAction === 'resolve' ? '解决' : '驳回'}
        cancelText="取消"
        width={600}
      >
        {selectedDispute && (
          <div className={styles.actionForm}>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>任务：</span>
              <span className={styles.modalValue}>
                {selectedDispute.task_title || `任务 #${selectedDispute.task_id}`}
              </span>
            </div>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>争议原因：</span>
              <div className={styles.modalTextBlock}>{selectedDispute.reason}</div>
            </div>
            <div className={styles.actionFormField}>
              <label className={styles.actionFormLabel}>
                {disputeAction === 'resolve' ? '处理备注' : '驳回理由'}：
              </label>
              <textarea
                value={resolutionNote}
                onChange={(e) => setResolutionNote(e.target.value)}
                placeholder={disputeAction === 'resolve' ? '请输入处理备注...' : '请输入驳回理由...'}
                rows={6}
                className={styles.actionFormTextarea}
              />
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

export default DisputeManagement;
